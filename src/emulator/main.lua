local data = require("data")
local hud = require("hud")
local sockets = require("sockets")
local state = require("state")

local function main() 
	savestate.loadslot(1)

	while true do
		local stats = data.getRacerStats()
		hud.drawHUD(stats)

		local cur_stats = data.getRLApplicableRacerStats()
		
		if cur_stats ~= nil then
			sockets.sendStats(cur_stats)

			sockets.receiveCtrls()

			emu.frameadvance()

			local next_stats = data.getRLApplicableRacerStats()
			if state.needsReset(cur_stats) then 
				next_stats.episode_done = 1
				savestate.loadslot(1)
			else
				cur_stats.episode_done = 0
			end
		else
			emu.frameadvance()
		end

		if stats then data.prevData = stats end
	end
end

main()