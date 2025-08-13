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
	ptrMapData = 0x02175600 + ptrOffset,
	ptrRaceStatus = 0x021755FC + ptrOffset
}

function m.get_s16(data, offset)
	local u = data[offset] | (data[offset + 1] << 8)
	return u - ((data[offset + 1] & 0x80) << 9)
end

function m.get_u16(data, offset)
	return data[offset] | (data[offset + 1] << 8)
end

function m.get_s32(data, offset)
	local u = data[offset] | (data[offset + 1] << 8) | (data[offset + 2] << 16) | (data[offset + 3] << 24)
	return u - ((data[offset + 3] & 0x80) << 25)
end

function m.get_pos(data, offset)
	return {
		math.floor(m.get_s32(data, offset + 0)  / 4096),
		math.floor(m.get_s32(data, offset + 4)  / 4096),
		math.floor(m.get_s32(data, offset + 8)  / 4096),
	}
end

return m