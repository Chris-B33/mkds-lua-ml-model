local m = {}

-- Base pointer used to offset region-specific addresses
local basePtr = memory.read_u32_le(0x0200B54)
local valueForUSVersion = 0x0216F320

local ptrOffset = 0
if basePtr ~= 0 and basePtr > 0x02000000 and basePtr < 0x02300000 then
	ptrOffset = basePtr - valueForUSVersion
end

m.addrs = {
	ptrRacerData = 0x0217ACF8 + ptrOffset,
	frameImgData = 0x06000000
}

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
	frame = 0
}

local function get_s16(data, offset)
	local u = data[offset] | (data[offset + 1] << 8)
	return u - ((data[offset + 1] & 0x80) << 9)
end

local function get_s32(data, offset)
	local u = data[offset] | (data[offset + 1] << 8) | (data[offset + 2] << 16) | (data[offset + 3] << 24)
	return u - ((data[offset + 3] & 0x80) << 25)
end

local function get_pos(data, offset)
	return {
		math.floor(get_s32(data, offset + 0)  / 4096),
		math.floor(get_s32(data, offset + 4)  / 4096),
		math.floor(get_s32(data, offset + 8)  / 4096),
	}
end

local function isRacerGoingBackwards()
	local prevDomain = memory.getcurrentmemorydomain()
    memory.usememorydomain("Main RAM")
    local val = memory.read_s32_le(0x17B854)
    memory.usememorydomain(prevDomain)
    return val > 0
end

function m.getPlayerData()
	local ptr = memory.read_u32_le(m.addrs.ptrRacerData)
	if ptr == 0 then return nil end
	return memory.read_bytes_as_array(ptr + 1, 0x5a8 - 1)
end

function m.getRacerStats(data)
	if not data then return nil end

	local curSpeed = math.floor(get_s32(data, 0x2A8) / 256)
	local curPos = get_pos(data, 0x80)
	local curDriftAngle = math.floor(get_s16(data, 0x388) / 256) 
	local framesInAir = get_s32(data, 0x380)

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
		frame = emu.framecount()
	}

	prevData = newData
	return newData
end

function m.getCurrentInputs()
	return joypad.get()
end

function m.getCurrentFrame()
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
