local mem = require("mem")

local m = {}

local checkpointSize = 0x24;

function m.getCurrentCheckpoint()
    local val = memory.read_u32_le(0x021755FC)
    return memory.read_u8(val + 0x46)
end

function m.getCheckpoints()
	local ptrMapData = memory.read_s32_le(mem.addrs.ptrMapData)
	local totalcheckpoints = memory.read_u16_le(ptrMapData + 0x48)
	if totalcheckpoints == 0 then return { count = 0 } end
	if totalcheckpoints > 0xFF then return nil end

	local chkAddr = memory.read_u32_le(ptrMapData + 0x44)
	local checkpointData = memory.read_bytes_as_array(chkAddr + 1, totalcheckpoints * checkpointSize)
	checkpointData[0] = memory.read_u8(chkAddr)

	local checkpoints = {}
	for i = 0, totalcheckpoints - 1 do
		checkpoints[i] = {
			p1 = {
				x=math.floor(mem.get_s32(checkpointData, i * checkpointSize + 0x0) / 4096),
				y=math.floor(mem.get_s32(checkpointData, i * checkpointSize + 0x4) / 4096),
			},
			p2 = {
				x=math.floor(mem.get_s32(checkpointData, i * checkpointSize + 0x8) / 4096),
				y=math.floor(mem.get_s32(checkpointData, i * checkpointSize + 0xC) / 4096),
			},
			isFinish = false,
			isKey = mem.get_s16(checkpointData, i * checkpointSize + 0x20) >= 0
		}
	end
	checkpoints[0].isFinish = true
	checkpoints.count = totalcheckpoints

	return checkpoints
end

function m.getCurrentLap()
    local prevDomain = memory.getcurrentmemorydomain()
    memory.usememorydomain("Main RAM")
    local lapNum = memory.read_u8(0x2C8AA0) + 1
    memory.usememorydomain(prevDomain)
    return lapNum
end

return m