local mem = require("mem")
print(memory.getcurrentmemorydomain())
local function drawHUD(stats)
	if not stats then
		gui.text(5, 595, "No racer data")
		return
	end
	
	gui.text(5, 565, "Speed: " .. stats.speed)
	gui.text(5, 580, string.format("Pos: x=%d y=%d z=%d", stats.x, stats.y, stats.z))
	gui.text(5, 595, "Angle: " .. stats.drift_angle)

	gui.text(5, 550, string.format("Grounded: %s, framesInAir=%d", stats.isGrounded, stats.framesInAir))
	gui.text(5, 535, string.format("Going Backwards: %s", stats.isGoingBackwards))
end

local function writeStatsAndCtrls(stats, ctrls)
	if not stats then return end

	local buffer = ""
	for stat, value in pairs(stats) do
		buffer = buffer .. stat .. "=" .. tostring(value) .. "\n"
	end
	for ctrl, value in pairs(ctrls) do
		buffer = buffer .. ctrl .. "=" .. tostring(value) .. "\n"
	end

	local file = io.open("../data/cur_stats_and_ctrls.bin", "w")
	file:write(buffer)
	file:close()
end

while true do
	local data = mem.getAllData()
	local stats = mem.getRacerStats(data)
	local ctrls = mem.getCurrentInputs()

	drawHUD(stats)
	writeStatsAndCtrls(stats, ctrls)

	emu.frameadvance()
end
