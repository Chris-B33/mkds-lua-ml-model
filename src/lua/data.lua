local mem = require("mem")
local checkpoint = require("checkpoints")

local m = {}

local MAX_SPEED = 150
local MAX_ACCEL = 16
local MAX_ANGLE = 45
local MAX_DELTA_ANGLE = 45
local MAX_DC = 20
local MAX_LAP = 3
local MAX_FRAMES_IN_AIR = 60
local MAX_POS_DELTA = 4000

local inRace = false
local allCheckpoints = nil

m.prevData = {
	speed = 0,
	acceleration = 0,
	pos = {x=0,y=0,z=0},
	dpos = {dx=0,dy=0,dz=0},
	drift_angle = 0,
	delta_drift_angle = 0,
	framesInAir = 0,
	isGrounded = 1,
	isGoingBackwards = 0,
	nextCheckpointNum = 0,
	nextCheckpointP1={x=0, y=0},
	nextCheckpointP2={x=0, y=0},
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
		acceleration = curSpeed - m.prevData.speed,

		pos = curPos,
		dpos = {
			dx = math.abs(m.prevData.pos.x - curPos.x),
			dy = math.abs(m.prevData.pos.y - curPos.y),
			dz = math.abs(m.prevData.pos.z - curPos.z)
		},

		drift_angle = curDriftAngle,
		delta_drift_angle = curDriftAngle - m.prevData.drift_angle,

		framesInAir = framesInAir,
		isGrounded = framesInAir == 0 and 1 or 0,
		isGoingBackwards = isRacerGoingBackwards() and 1 or 0,

		nextCheckpointNum = nextCheckpointNum,
		nextCheckpointP1 = allCheckpoints[nextCheckpointNum].p1,
		nextCheckpointP2 = allCheckpoints[nextCheckpointNum].p2,
		lap = lapNum,

		frame = emu.framecount()
	}

	return newData
end

function m.getRLApplicableRacerStats()
	local data = m.getRacerStats()
	if not data then return end

	local normData = {
        speed = data.speed / MAX_SPEED,
        acceleration = data.acceleration / MAX_ACCEL,

		dx = data.dpos.dx / MAX_DC,
		dy = data.dpos.dy / MAX_DC,
		dz = data.dpos.dz / MAX_DC,

        drift_angle = data.drift_angle / MAX_ANGLE,
        delta_drift_angle = data.delta_drift_angle / MAX_DELTA_ANGLE,

        framesInAir = data.framesInAir / MAX_FRAMES_IN_AIR,
        isGrounded = data.isGrounded,
        isGoingBackwards = data.isGoingBackwards,

        nextCheckpointNum = data.nextCheckpointNum / allCheckpoints.count,
        nextCheckpointP1x = (data.nextCheckpointP1.x - data.pos.x) / MAX_POS_DELTA,
        nextCheckpointP1y = (data.nextCheckpointP1.y - data.pos.y) / MAX_POS_DELTA,
        nextCheckpointP2x = (data.nextCheckpointP2.x - data.pos.x) / MAX_POS_DELTA,
        nextCheckpointP2y = (data.nextCheckpointP2.y - data.pos.y) / MAX_POS_DELTA,

        lap = data.lap / MAX_LAP,
    }

    return normData
end

function m.getCurrentInputs()
	return joypad.get()
end

return m
