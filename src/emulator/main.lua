local data = require("data")
local hud = require("hud")
local files = require("files")
local state = require("state")

while true do
	local stats = data.getRacerStats()
	local RLApplicableRacerStats = data.getRLApplicableRacerStats()
	
	if state.needsReset(RLApplicableRacerStats) then 
		RLApplicableRacerStats.episode_done = 1
		savestate.loadslot(1)
	else
		RLApplicableRacerStats.episode_done = 0
	end

	hud.drawHUD(stats)

	files.sendStats(RLApplicableRacerStats)
	files.receiveCtrls()

	if stats then data.prevData = stats end
	emu.frameadvance()
end