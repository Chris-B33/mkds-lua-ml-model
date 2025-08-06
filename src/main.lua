local mem = require("mem")
local hud = require("hud")
local files = require("files")

while true do
	local data = mem.getPlayerData()
	local stats = mem.getRacerStats(data)
	local ctrls = mem.getCurrentInputs()
	local frame = mem.getCurrentFrame()

	hud.drawHUD(stats)

	files.sendStatsAndCtrls(stats, ctrls)
	files.sendCurrentFrame(frame)
	files.receiveCtrls()

	emu.frameadvance()
end