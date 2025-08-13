local data = require("data")
local hud = require("hud")
local files = require("files")

while true do
	local stats = data.getRacerStats()
	local RLApplicableRacerStats = data.getRLApplicableRacerStats()
	local ctrls = data.getCurrentInputs()

	hud.drawHUD(stats)

	files.sendStatsAndCtrls(RLApplicableRacerStats, ctrls)
	--files.receiveCtrls()

	if stats then data.prevData = stats end
	emu.frameadvance()
end