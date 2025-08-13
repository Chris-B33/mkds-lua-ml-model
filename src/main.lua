local data = require("data")
local hud = require("hud")
local files = require("files")

while true do
	local stats = data.getRacerStats()
	local ctrls = data.getCurrentInputs()

	hud.drawHUD(stats)

	files.sendStatsAndCtrls(stats, ctrls)
	--files.receiveCtrls()

	emu.frameadvance()
end