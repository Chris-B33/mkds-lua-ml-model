local mem = require("mem")
local hud = require("hud")
local files = require("files")

while true do
	local stats = mem.getRacerStats()
	local ctrls = mem.getCurrentInputs()

	hud.drawHUD(stats)

	files.sendStatsAndCtrls(stats, ctrls)
	--files.receiveCtrls()

	emu.frameadvance()
end