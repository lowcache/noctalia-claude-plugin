--!nonstrict
-- Type definitions for the Noctalia v5 plugin runtime, fed to luau-analyze via
-- `--definitions=`. Companion to noctalia.yml (selene's copy of the same surface):
-- the two tools want the same knowledge in different formats, and both are needed —
-- selene catches an undeclared global, luau-analyze catches a bad call shape.
--
-- Pinned against Noctalia 5.0.0. Each entry kind sees only its own table at runtime
-- (a bar widget has no `panel`), which a flat declaration cannot express; plugin.toml
-- stays the real contract for which entry gets what.

declare noctalia: {
	tr: (string, table?) -> string,
	readFile: (string) -> string?,
	expandPath: (string) -> string,
	getenv: (string) -> string?,
	getConfig: (string) -> any,
	isDarkMode: () -> boolean,
	formatTime: (any) -> string,
	notify: (any, any?, any?) -> (),
	notifyError: (any, any?) -> (),
	runAsync: (string) -> (),
	runInTerminal: (string) -> (),
	runStream: (string, (string) -> ()) -> (),
	setUpdateInterval: (number) -> (),
	json: { decode: (string) -> any, encode: ((any) -> string)? },
	string: { urlEncode: (string) -> string },
	state: {
		get: (string) -> any,
		set: (string, any) -> (),
		watch: (string, (any) -> ()) -> (),
	},
}

declare ui: {
	label: (table) -> any,
	row: (table, table?) -> any,
	column: (table, table?) -> any,
	button: (table) -> any,
	separator: (table) -> any,
	scroll: (table, table?) -> any,
	box: (table, table?) -> any,
	glyph: (table) -> any,
	input: (table) -> any,
}

declare panel: {
	render: (any) -> (),
	setWantsSecondTicks: (boolean) -> (),
}

declare barWidget: {
	setGlyph: (string) -> (),
	setGlyphColor: (string) -> (),
	setTooltip: (string) -> (),
}

declare desktopWidget: {
	render: (any) -> (),
	setNeedsFrameTick: (boolean) -> (),
}

declare launcher: {
	setResults: (table) -> (),
	show: (any?) -> (),
	launch: (any?) -> (),
	ask: (any?) -> (),
	continue: (any?) -> (),
}
