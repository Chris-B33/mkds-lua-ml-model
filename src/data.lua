local mem = require("mem")
local checkpoint = require("checkpoints")

local m = {}

local inRace = false
local allCheckpoints = nil

local prevData = {
	speed = 0,
	acceleration = 0,
	x = 0,
	y = 0,
	z = 0,
	dx = 0,
	dy = 0,
	dz = 0,
	drift_angle = 0,
	delta_drift_angle = 0,
	framesInAir = 0,
	isGrounded = true,
	isGoingBackwards = false,
	nextCheckpointNum = 0,
	nextCheckpointP1x = 0,
	nextCheckpointP1y = 0,
	nextCheckpointP2x = 0,
	nextCheckpointP2y = 0,
	lap = 0,
	frame = 0
}

local function isRacerGoingBackwards()
	local prevDomain = memory.getcurrentmemorydomain()
    memory.usememorydomain("Main RAM")
    local val = memory.read_s32_le(0x17B854)
    memory.usememorydomain(prevDomain)
    return val > 0
end

function m.getPlayerData()
	local ptr = memory.read_u32_le(mem.addrs.ptrRacerData)
	if ptr == 0 then return nil end
	return memory.read_bytes_as_array(ptr + 1, 0x5a8 - 1)
end

function m.getRacerStats()
	local playerData = m.getPlayerData()
	if not playerData then 
		inRace = false
		allCheckpoints = nil
		return nil 
	end

	if not inRace then
		inRace = true
		allCheckpoints = checkpoint.getCheckpoints()
	end

	local curSpeed = math.floor(mem.get_s32(playerData, 0x2A8) / 256)
	local curPos = mem.get_pos(playerData, 0x80)
	local curDriftAngle = math.floor(mem.get_s16(playerData, 0x388) / 256) 
	local framesInAir = mem.get_s32(playerData, 0x380)
	
	local nextCheckpointNum = (checkpoint.getCurrentCheckpoint() + 1) % allCheckpoints.count
	local lapNum = checkpoint.getCurrentLap()

	local newData = {
		speed = curSpeed,
		acceleration = prevData.speed - curSpeed,
		x = curPos[1],
		y = curPos[2],
		z = curPos[3],
		dx = prevData.x - curPos[1],
		dy = prevData.y - curPos[2],
		dz = prevData.z - curPos[3],
		drift_angle = curDriftAngle,
		delta_drift_angle = curDriftAngle - prevData.drift_angle,
		framesInAir = framesInAir,
		isGrounded = framesInAir == 0,
		isGoingBackwards = isRacerGoingBackwards(),
		nextCheckpointNum = nextCheckpointNum,
		nextCheckpointP1x = allCheckpoints[nextCheckpointNum].p1.x,
		nextCheckpointP1y = allCheckpoints[nextCheckpointNum].p1.y,
		nextCheckpointP2x = allCheckpoints[nextCheckpointNum].p2.x,
		nextCheckpointP2y = allCheckpoints[nextCheckpointNum].p2.y,
		lap = lapNum,
		frame = emu.framecount()
	}

	prevData = newData
	return newData
end

function m.getCurrentInputs()
	return joypad.get()
end

function m.getCurrentFrame() -- TOO SLOW AND MAY NOT BE NEEDED SO NOT USING
	local buffer = {} 

	local width = 256
	local height = 192
	local size = width * height * 2

	for i = 0, size - 1 do
		buffer[i + 1] = string.char(memory.read_u8(m.addrs.frameImgData + i))
	end
	return table.concat(buffer)
end

return m
