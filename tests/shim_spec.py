#!/usr/bin/env python3
"""Unit tests for the shim's compositor abstraction (shim/noctalia-mcp.py).

These cover the pure, I/O-free seam — detection, the (compositor, op) -> argv
mapping, and the client-side focus filters — so the niri/Hyprland/Sway command
shapes are pinned without a live session. Run: python3 tests/shim_spec.py

Fixtures mirror the documented JSON shapes: Hyprland from HyprCtl.cpp serializers
(getMonitorData/getWindowData), Sway from sway-ipc(7) GET_TREE/GET_OUTPUTS/
GET_WORKSPACES. They are the contract; a live nested-compositor run confirms them.
"""
import importlib.util
import os
import unittest

_HERE = os.path.dirname(os.path.abspath(__file__))
_SHIM = os.path.join(_HERE, "..", "shim", "noctalia-mcp.py")
_spec = importlib.util.spec_from_file_location("noctalia_mcp", _SHIM)
mcp = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(mcp)


class DetectCompositor(unittest.TestCase):
    def test_socket_env_wins(self):
        self.assertEqual(mcp.detect_compositor({"NIRI_SOCKET": "/x"}), "niri")
        self.assertEqual(
            mcp.detect_compositor({"HYPRLAND_INSTANCE_SIGNATURE": "abc"}), "hyprland")
        self.assertEqual(mcp.detect_compositor({"SWAYSOCK": "/run/x"}), "sway")

    def test_socket_precedence_over_xdg(self):
        # An explicit niri socket beats a mismatched XDG hint.
        env = {"NIRI_SOCKET": "/x", "XDG_CURRENT_DESKTOP": "sway"}
        self.assertEqual(mcp.detect_compositor(env), "niri")

    def test_xdg_fallback(self):
        self.assertEqual(
            mcp.detect_compositor({"XDG_CURRENT_DESKTOP": "Hyprland"}), "hyprland")
        self.assertEqual(
            mcp.detect_compositor({"XDG_CURRENT_DESKTOP": "sway"}), "sway")

    def test_none_when_undetectable(self):
        self.assertIsNone(mcp.detect_compositor({}))
        self.assertIsNone(mcp.detect_compositor({"XDG_CURRENT_DESKTOP": "gnome"}))


class Argv(unittest.TestCase):
    def test_niri(self):
        a = mcp.compositor_argv
        self.assertEqual(a("niri", "focused_output"), ["niri", "msg", "-j", "focused-output"])
        self.assertEqual(a("niri", "focused_window"), ["niri", "msg", "-j", "focused-window"])
        self.assertEqual(a("niri", "focus_window", wid="42"),
                         ["niri", "msg", "action", "focus-window", "--id", "42"])
        self.assertEqual(a("niri", "focus_workspace", ref="3"),
                         ["niri", "msg", "action", "focus-workspace", "3"])
        self.assertEqual(a("niri", "move_to_workspace", ref="web"),
                         ["niri", "msg", "action", "move-column-to-workspace", "web"])

    def test_hyprland(self):
        a = mcp.compositor_argv
        self.assertEqual(a("hyprland", "focused_output"), ["hyprctl", "-j", "monitors"])
        self.assertEqual(a("hyprland", "focused_window"), ["hyprctl", "-j", "activewindow"])
        # address: prefix is mandatory (bare selector is a class regex otherwise).
        self.assertEqual(a("hyprland", "focus_window", wid="0x5641f2a3b8c0"),
                         ["hyprctl", "dispatch", "focuswindow", "address:0x5641f2a3b8c0"])
        # numeric ws: bare; named ws: name: prefix.
        self.assertEqual(a("hyprland", "focus_workspace", ref="3"),
                         ["hyprctl", "dispatch", "workspace", "3"])
        self.assertEqual(a("hyprland", "focus_workspace", ref="work"),
                         ["hyprctl", "dispatch", "workspace", "name:work"])
        self.assertEqual(a("hyprland", "move_to_workspace", ref="3"),
                         ["hyprctl", "dispatch", "movetoworkspace", "3"])
        self.assertEqual(a("hyprland", "move_to_workspace", ref="work"),
                         ["hyprctl", "dispatch", "movetoworkspace", "name:work"])

    def test_sway(self):
        a = mcp.compositor_argv
        self.assertEqual(a("sway", "focused_output"), ["swaymsg", "-t", "get_outputs"])
        self.assertEqual(a("sway", "focused_window"), ["swaymsg", "-t", "get_tree"])
        self.assertEqual(a("sway", "focus_window", wid="94"),
                         ["swaymsg", "[con_id=94]", "focus"])
        # numeric ws uses the `number` keyword; named ws is passed literally.
        self.assertEqual(a("sway", "focus_workspace", ref="3"),
                         ["swaymsg", "workspace", "number", "3"])
        self.assertEqual(a("sway", "focus_workspace", ref="web"),
                         ["swaymsg", "workspace", "web"])
        self.assertEqual(a("sway", "move_to_workspace", ref="3"),
                         ["swaymsg", "move", "container", "to", "workspace", "number", "3"])
        self.assertEqual(a("sway", "move_to_workspace", ref="web"),
                         ["swaymsg", "move", "container", "to", "workspace", "web"])

    def test_unknown_raises(self):
        with self.assertRaises(KeyError):
            mcp.compositor_argv("river", "focus_window", wid="1")


class HyprlandFilter(unittest.TestCase):
    MONS = [
        {"name": "DP-1", "focused": False, "activeWorkspace": {"id": 1, "name": "1"}},
        {"name": "eDP-1", "focused": True, "activeWorkspace": {"id": 2, "name": "2"}},
    ]

    def test_pick_focused(self):
        self.assertEqual(mcp.pick_focused_monitor(self.MONS)["name"], "eDP-1")

    def test_pick_focused_none(self):
        self.assertIsNone(mcp.pick_focused_monitor(
            [{"name": "DP-1", "focused": False}]))


class SwayTreeFilter(unittest.TestCase):
    # A minimal get_tree: root -> output -> workspace -> two views, one focused,
    # plus a floating view. Mirrors sway-ipc(7) node fields.
    TREE = {
        "type": "root", "focused": False, "nodes": [
            {"type": "output", "name": "eDP-1", "focused": False, "nodes": [
                {"type": "workspace", "name": "1", "focused": False,
                 "nodes": [
                     {"type": "con", "id": 10, "name": "kitty",
                      "app_id": "kitty", "focused": False,
                      "nodes": [], "floating_nodes": []},
                     {"type": "con", "id": 11, "name": "Firefox",
                      "app_id": None,
                      "window_properties": {"class": "firefox"},
                      "focused": True,
                      "nodes": [], "floating_nodes": []},
                 ],
                 "floating_nodes": []},
            ], "floating_nodes": []},
        ], "floating_nodes": [],
    }

    def test_finds_focused_leaf(self):
        view = mcp.find_focused_view(self.TREE)
        self.assertEqual(view["id"], 11)
        self.assertEqual(view["name"], "Firefox")

    def test_xwayland_class_available_for_fallback(self):
        # app_id is null for XWayland; the class lives under window_properties.
        view = mcp.find_focused_view(self.TREE)
        self.assertIsNone(view["app_id"])
        self.assertEqual(view["window_properties"]["class"], "firefox")

    def test_finds_focused_in_floating(self):
        tree = {"type": "root", "focused": False, "nodes": [], "floating_nodes": [
            {"type": "floating_con", "id": 20, "name": "mpv",
             "app_id": "mpv", "focused": True, "nodes": [], "floating_nodes": []},
        ]}
        self.assertEqual(mcp.find_focused_view(tree)["id"], 20)

    def test_no_focus_returns_none(self):
        tree = {"type": "root", "focused": False, "nodes": [], "floating_nodes": []}
        self.assertIsNone(mcp.find_focused_view(tree))


class SwayFocusedOutput(unittest.TestCase):
    OUTPUTS = [
        {"name": "DP-1", "active": True, "current_workspace": "2"},
        {"name": "eDP-1", "active": True, "current_workspace": "1"},
    ]
    WORKSPACES = [
        {"num": 1, "name": "1", "focused": True, "output": "eDP-1"},
        {"num": 2, "name": "2", "focused": False, "output": "DP-1"},
    ]

    def test_derives_output_from_focused_workspace(self):
        out = mcp.sway_focused_output(self.OUTPUTS, self.WORKSPACES)
        self.assertEqual(out["name"], "eDP-1")

    def test_none_when_no_focused_workspace(self):
        wss = [dict(w, focused=False) for w in self.WORKSPACES]
        self.assertIsNone(mcp.sway_focused_output(self.OUTPUTS, wss))


if __name__ == "__main__":
    unittest.main(verbosity=2)
