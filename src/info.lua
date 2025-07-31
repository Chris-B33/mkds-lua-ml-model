-- A Lua script that aims to be helpful for creating tool-assisted speedruns.
-- Authors: Suuper; some checkpoint and pointer stuffs from MKDasher
-- Also a thanks to the HaroohiePals team for figuring out some data structure things

-- Script options ---------------------
-- These are the default values. If you have a MKDS_Info-Config.txt file then config settings will be read from that file.
-- If you don't have this file, it will be created for you.
local config = {
	-- display options
	defaultScale = 0.8, -- big = zoom out
	drawOnLeftSide = true, -- if the window is wide, keep on-screend stuff on the left edge
	useIntegerScale = false, -- Is EmuHawk configured to only scale the game by integer scale factors? (Pulling this info automatically is too hard. False is EmuHawk default.)
	increaseRenderDistance = false, -- true to draw triangels far away (laggy)
	renderAllTriangles = false,
	objectRenderDistance = 600,
	showExactMovement = true, -- true: dispaly fixed-point values as integers (0-4096 for 0.0-1.0)
	showAnglesAsDegrees = false,
	showBottomScreenInfo = true, -- item roullete thing too
	showWasbThings = false,
	showRawObjectPositionDelta = false,
	backfaceCulling = true, -- Do not show triangles that are facing away from the camera
	renderHitboxesWhenFakeGhost = false, -- Render your hitbox and that of the fake ghost, when a fake ghost exists, on the main screen, when the main camera is off.
	-- behavior
	alertOnRewindAfterBranch = true, -- BizHawk simply does not support nice seeking behavior, so we can't do it for you.
	showBizHawkDumbnessWarning = true,

	-- hacks: use these with caution as they can desync a movie or mess up state hisotry
	enableCameraFocusHack = false,
	giveGhostShrooms = false, -- for testing
}

local optionsFromFile = {}
local function writeConfig(exclude)
	configFile = io.open("MKDS_Info_Config.txt", "a")
	if configFile == nil then error("could not write config") end
	for k, v in pairs(config) do
		if exclude[k] == nil then
			configFile:write(k .. " ")
			if type(v) == "number" then
				configFile:write(v)
			elseif type(v) == "boolean" then
				if v == true then configFile:write("true") else configFile:write("false") end
			else
				io.close(configFile)
				error("invalid value in config for " .. k)
			end
			configFile:write("\n")
		end
	end
	io.close(configFile)

end
local function readConfig()
	local configFile = io.open("MKDS_Info_Config.txt", "r")
	local valuesRead = {}
	if configFile == nil then
		writeConfig({})
		valuesRead = config -- the default config
	else
		local keysRead = {}
		for line in configFile:lines() do
			local index = string.find(line, " ")
			local name = string.sub(line, 0, index - 1)
			local value = string.sub(line, index + 1)
			if value == "true" then value = true
			elseif value == "false" then value = false
			else value = tonumber(value)
			end
			valuesRead[name] = value
			keysRead[name] = true
		end
		io.close(configFile)
		writeConfig(keysRead)
	end

	valuesRead.defaultScale = 0x1000 * valuesRead.defaultScale / client.getwindowsize() -- "windowsize" is the scale factor
	valuesRead.objectRenderDistance = valuesRead.objectRenderDistance + 0.0 -- Lua, please. Use floats for this.
	valuesRead.objectRenderDistance = valuesRead.objectRenderDistance * 0x1000
	return valuesRead
end
config = readConfig()
-- Make a global copy for other files
mkdsiConfig = config

local bizhawkVersion = client.getversion()
if string.sub(bizhawkVersion, 0, 3) == "2.9" then
	bizhawkVersion = 9
elseif string.sub(bizhawkVersion, 0, 4) == "2.10" then
	bizhawkVersion = 10
else
	bizhawkVersion = 0
	print("You're using an unspported version of BizHawk.")
end

-- I've split this file into multiple files to keep it more organized.
-- Unfortunately, BizHawk doesn't give each Lua script it's own environment and using require does not work nicely or reliably.
-- I am using dofile instead.
-- However, I also would like to keep distribution simple by keeping the distributed version as a single file.
-- So, I will create a Python script that "builds" it into one script. Each file that is to be run with dofile will be
--     placed into a function (so that it has its own scope, mimcing dofile). The files will "export" an object by
--     setting the global _export. This script will then "import" it by assigning that object to a local.
_imports = {} -- Some files may require things from us.
local function _()
local function zero()
	return { 0, 0, 0 }
end
local function getMagnitude(vector)
	local x = vector[1] / 4096
	local y = vector[2] / 4096
	local z = vector[3] / 4096
	return math.sqrt(x * x + z * z + y * y)
end
local function get2dMagnitude(vector)
	local x = vector[1] / 4096
	local z = vector[3] / 4096
	return x * x + z * z
end
local function distanceSqBetween(p1, p2)
	local x = p2[1] - p1[1]
	local y = p2[2] - p1[2]
	local z = p2[3] - p1[3]
	return x * x + y * y + z * z
end


-- Functions may come in up to three variants:
-- _r: The output is rounded to the nearest subunit.
-- _t: The output is truncated.
-- _float: No rouding; may return values that MKDS cannot represent.
local function normalize_float(v)
	--if v == nil or type(v) == "number" or v[1] == nil then print(debug.traceback()) end
	local m = math.sqrt(v[1] * v[1] + v[2] * v[2] + v[3] * v[3]) / 0x1000
	return {
		v[1] / m,
		v[2] / m,
		v[3] / m,
	}
end

local function dotProduct_float(v1, v2)
	-- truncate, fixed point 20.12
	local a = v1[1] * v2[1] + v1[2] * v2[2] + v1[3] * v2[3]
	return a / 0x1000
end
local function dotProduct_t(v1, v2)
	-- truncate, fixed point 20.12
	local a = v1[1] * v2[1] + v1[2] * v2[2] + v1[3] * v2[3]
	return a // 0x1000 -- bitwise shifts are logical
end
local function dotProduct_r(v1, v2)
	-- round, fixed point 20.12
	local a = v1[1] * v2[1] + v1[2] * v2[2] + v1[3] * v2[3] + 0x800
	return a // 0x1000 -- bitwise shifts are logical
end

local function crossProduct_float(v1, v2)
	return {
		(v1[2] * v2[3] - v1[3] * v2[2]) / 0x1000,
		(v1[3] * v2[1] - v1[1] * v2[3]) / 0x1000,
		(v1[1] * v2[2] - v1[2] * v2[1]) / 0x1000,
	}
end
-- This one is special? It doesn't handle values as fixed-point like other ones do.
local function multiply(v, s)
	--if v == nil or v[1] == nil then print(debug.traceback()) end
	return {
		v[1] * s,
		v[2] * s,
		v[3] * s,
	}
end
local function multiply_r(v, s)
	return {
		math.floor(v[1] * s / 0x1000 + 0.5),
		math.floor(v[2] * s / 0x1000 + 0.5),
		math.floor(v[3] * s / 0x1000 + 0.5),
	}
end
local function multiply_t(v, s)
	return {
		v[1] * s // 0x1000,
		v[2] * s // 0x1000,
		v[3] * s // 0x1000,
	}
end

local function add(v1, v2)
	return {
		v1[1] + v2[1],
		v1[2] + v2[2],
		v1[3] + v2[3],
	}
end
local function subtract(v1, v2)
	--if v1 == nil or v1[1] == nil or v2[1] == nil then print(debug.traceback()) end
	return {
		v1[1] - v2[1],
		v1[2] - v2[2],
		v1[3] - v2[3],
	}
end
local function truncate(v)
	return {
		math.floor(v[1]),
		math.floor(v[2]),
		math.floor(v[3]),
	}
end

local function equals(v1, v2)
	--if v1 == nil or v2 == nil or v1[1] == nil or v2[1] == nil then print(debug.traceback()) end
	if v1[1] == v2[1] and v1[2] == v2[2] and v1[3] == v2[3] then
		return true
	end
end
local function equals_ignoreSign(v1, v2)
	if v1[1] == v2[1] and v1[2] == v2[2] and v1[3] == v2[3] then
		return true
	end
	v1 = multiply(v1, -1)
	return v1[1] == v2[1] and v1[2] == v2[2] and v1[3] == v2[3]
end
local function copy(v)
	return { v[1], v[2], v[3] }
end

local function interpolate(v1, v2, perc)
	return {
		v1[1] + perc * (v2[1] - v1[1]),
		v1[2] + perc * (v2[2] - v1[2]),
		v1[3] + perc * (v2[3] - v1[3]),
	}
end

_export = {
	zero = zero,
	getMagnitude = getMagnitude,
	get2dMagnitude = get2dMagnitude,
	distanceSqBetween = distanceSqBetween,
	normalize_float = normalize_float,
	dotProduct_float = dotProduct_float,
	dotProduct_t = dotProduct_t,
	dotProduct_r = dotProduct_r,
	crossProduct_float = crossProduct_float,
	multiply = multiply,
	multiply_r = multiply_r,
	multiply_t = multiply_t,
	add = add,
	subtract = subtract,
	truncate = truncate,
	equals = equals,
	equals_ignoreSign = equals_ignoreSign,
	copy = copy,
	interpolate = interpolate,
}
end
local Vector = _export
_imports.Vector = Vector

-- Pointer internationalization -------
-- This is intended to make the script compatible with most ROM regions and ROM hacks.
-- This is not well-tested. There are some known exceptions, such as Korean version has different locations for checkpoint stuff.
local somePointerWithRegionAgnosticAddress = memory.read_u32_le(0x2000B54)
local valueForUSVersion = 0x0216F320
local ptrOffset = somePointerWithRegionAgnosticAddress - valueForUSVersion
-- Base addresses are valid for the US Version
local addrs = {
	ptrRacerData = 0x0217ACF8 + ptrOffset,
	ptrPlayerInputs = 0x02175630 + ptrOffset,
	ptrGhostInputs = 0x0217568C + ptrOffset,
	ptrRaceTimers = 0x0217AA34 + ptrOffset,
	ptrMissionInfo = 0x021A9B70 + ptrOffset,
	ptrObjStuff = 0x0217B588 + ptrOffset,
	racerCount = 0x0217ACF4 + ptrOffset,
	ptrSomeRaceData = 0x021759A0 + ptrOffset,
	ptrCheckNum = 0x021755FC + ptrOffset,
	ptrCheckData = 0x02175600 + ptrOffset,
	ptrScoreCounters = 0x0217ACFC + ptrOffset,
	collisionData = 0x0217b5f4 + ptrOffset,
	ptrCurrentCourse = 0x23cdcd8 + ptrOffset,
	ptrCamera = 0x217AA4C + ptrOffset,
	ptrVisibilityStuff = 0x217AE90 + ptrOffset,
	cameraThing = 0x207AA24 + ptrOffset,
	ptrBattleController = 0x0217b1dc + ptrOffset,
	ptrItemSets = 0x27e00cc, -- versions?
	ptrItemInfo = memory.read_u32_le(0x020FA8A4 + ptrOffset), -- needs version testing
}
---------------------------------------
-- These have the same address in E and U versions.
-- Not sure about other versions. K +0x5224 for car at least.
local hitboxFuncs = {
	car = memory.read_u32_le(0x2158ad4),
	bumper = memory.read_u32_le(0x209c190),
	clockHand = memory.read_u32_le(0x2159158),
	pendulum = memory.read_u32_le(0x21592e8),
	rockyWrench = memory.read_u32_le(0x2095fe8),
	-- This one is in an overlay so it might not be loaded at whatever time we'd be reading.
	bully = 0x21860ad,
}
---------------------------------------

-- get_thing: Read thing from a byte array.
-- We do this because it is more performant than making many BizHawk API calls.
local function get_u32(data, offset)
	return data[offset] | (data[offset + 1] << 8) | (data[offset + 2] << 16) | (data[offset + 3] << 24)
end
local function get_s32(data, offset)
	local u = data[offset] | (data[offset + 1] << 8) | (data[offset + 2] << 16) | (data[offset + 3] << 24)
	return u - ((data[offset + 3] & 0x80) << 25)
end
local function get_u16(data, offset)
	return data[offset] | (data[offset + 1] << 8)
end
local function get_s16(data, offset)
	local u = data[offset] | (data[offset + 1] << 8)
	return u - ((data[offset + 1] & 0x80) << 9)
end

local function get_pos(data, offset)
	return {
		get_s32(data, offset),
		get_s32(data, offset + 4),
		get_s32(data, offset + 8),
	}
end
local function get_pos_16(data, offset)
	return {
		get_s16(data, offset),
		get_s16(data, offset + 2),
		get_s16(data, offset + 4),
	}
end
local function get_quaternion(data, offset)
	return {
		k = get_s32(data, offset),
		j = get_s32(data, offset + 4),
		i = get_s32(data, offset + 8),
		r = get_s32(data, offset + 12),
	}
end

-- Read structures
local function read_pos_16(addr)
	local d = memory.read_bytes_as_array(addr, 6)
	return {
		get_s16(d, 1),
		get_s16(d, 3),
		get_s16(d, 5),
	}
end

local function read_pos(addr)
	local data = memory.read_bytes_as_array(addr, 12)
	return get_pos(data, 1)
end
local function read_quaternion(addr)
	return {
		k = memory.read_s32_le(addr),
		j = memory.read_s32_le(addr + 4),
		i = memory.read_s32_le(addr + 8),
		r = memory.read_s32_le(addr + 12),
	}
end

_export = {
	addrs = addrs,
	hitboxFuncs = hitboxFuncs,
	get_u32 = get_u32,
	get_s32 = get_s32,
	get_u16 = get_u16,
	get_s16 = get_s16,
	get_pos = get_pos,
	get_pos_16 = get_pos_16,
	get_quaternion = get_quaternion,
	read_pos = read_pos,
	read_pos_16 = read_pos_16,
	read_quaternion = read_quaternion,
}

_()
local Memory = _export
_imports.Memory = Memory
local get_u32 = Memory.get_u32
local get_s32 = Memory.get_s32
local get_s16 = Memory.get_s16
local get_pos = Memory.get_pos
local get_quaternion = Memory.get_quaternion
local read_pos = Memory.read_pos

local function _()
local Memory = _imports.Memory
local Vector = _imports.Vector
local get_pos = Memory.get_pos
local get_u32 = Memory.get_u32
local get_s32 = Memory.get_s32
local get_u16 = Memory.get_u16
local get_s16 = Memory.get_s16
local get_pos_16 = Memory.get_pos_16

local someCourseData = nil

local function mul_fx(a, b)
	return a * b // 0x1000
end

local SOUND_TRIGGER = 4
local FLOOR_NO_RACERS = 13
local WALL_NO_RACERS = 14
local EDGE_WALL = 16
local RECALCULATE_ROUTE = 22

local skippableTypes = (1 << SOUND_TRIGGER) | (1 << FLOOR_NO_RACERS) | (1 << WALL_NO_RACERS) | (1 << RECALCULATE_ROUTE)

local function _getNearbyTriangles(pos)
	if someCourseData == nil or triangles == nil then error("nil course data") end
	-- Read map of position -> nearby triangle IDs
	local boundary = get_pos(someCourseData, 0x14)
	if pos[1] < boundary[1] or pos[2] < boundary[2] or pos[3] < boundary[3] then
		return {}
	end
	local shift = someCourseData[0x2C]
	local fb = {
		(pos[1] - boundary[1]) >> 12,
		(pos[2] - boundary[2]) >> 12,
		(pos[3] - boundary[3]) >> 12,
	}
	local base = get_u32(someCourseData, 0xC)
	local a = base
	local b = a + 4 * (
		((fb[1] >> shift)) |
		((fb[2] >> shift) << someCourseData[0x30]) |
		((fb[3] >> shift) << someCourseData[0x34])
	)
	if b >= 0x02800000 then
		-- This may happen during course loads: the data we're trying to read isn't initialized yet. ... but we shouldn't ever use this function at that time
		error("Attempted to get triangles before course loaded.")
	end
	b = get_u32(collisionMap, b - base)
	local safety = 0
	while b < 0x80000000 do
		safety = safety + 1
		if safety > 1000 then error("infinite loop: reading nearby triangle map") end
		a = a + b
		shift = shift - 1
		b = a + 4 * (
			(((fb[1] >> shift) & 1)) |
			(((fb[2] >> shift) & 1) << 1) |
			(((fb[3] >> shift) & 1) << 2)
		)
		b = get_u32(collisionMap, b - base)
	end
	a = a + (b - 0x80000000) + 2

	-- a now points to first triangle ID
	local nearby = {}
	local index = get_u16(collisionMap, a - base)
	safety = 0
	while index ~= 0 do
		nearby[#nearby + 1] = triangles[index]
		index = get_u16(collisionMap, a + 2 * #nearby - base)
		safety = safety + 1
		if safety > 1000 then
			error("infinite loop: reading nearby triangle list")
		end
	end
	return nearby
end
local _mergeSet = {}
local function merge(l1, l2)
	for i = 1, #l2 do
		local v = l2[i]
		if _mergeSet[v] == nil then
			l1[#l1 + 1] = v
			_mergeSet[v] = true
		end
	end
end
local function getNearbyTriangles(pos, extraRenderDistance)
	if extraRenderDistance == nil then
		return _getNearbyTriangles(pos)
	end

	_mergeSet = {}
	local nearby = {}
	-- How many units should we move at a time?
	local step = 100 * 0x1000
	for iX = -extraRenderDistance, extraRenderDistance do
		for iY = -extraRenderDistance, extraRenderDistance do
			for iZ = -extraRenderDistance, extraRenderDistance do
				local p = {
					pos[1] + iX * step,
					pos[2] + iY * step,
					pos[3] + iZ * step,
				}
				merge(nearby, _getNearbyTriangles(p))
			end
		end
	end
	
	return nearby
end
local function updateMinMax(current, new)
	current.min[1] = math.min(current.min[1], new[1])
	current.min[2] = math.min(current.min[2], new[2])
	current.min[3] = math.min(current.min[3], new[3])
	current.max[1] = math.max(current.max[1], new[1])
	current.max[2] = math.max(current.max[2], new[2])
	current.max[3] = math.max(current.max[3], new[3])
end
local function someKindOfTransformation(a, d2, d1, v2, v1)
	-- FUN_01fff434
	local m = 0
	if a ~= 0x1000 and a ~= -0x1000 then
		m = math.floor((mul_fx(a, d1) - d2) / (mul_fx(a, a) - 0x1000) * 0x1000 + 0.5)
	else
		-- Divide by zero. NDS returns either 1 or -1.
		-- MKDS will then round + bit shift (for fx32 precision reasons) and give 0.
	end
	local n = d1 - mul_fx(m, a)
	
	local out = Vector.add(
		Vector.multiply_t(v2, m),
		Vector.multiply_t(v1, n)
	)
	
	return out
end
local function getSurfaceDistanceData(toucher, surface)
	local data = {}
	local radius = toucher.radius

	local relativePos = Vector.subtract(toucher.pos, surface.vertex[1])
	local previousPos = toucher.previousPos and Vector.subtract(toucher.previousPos, surface.vertex[1])
	local upDistance = Vector.dotProduct_t(relativePos, surface.surfaceNormal)
	local inDistance = Vector.dotProduct_t(relativePos, surface.inVector)
	local planeDistances = {
		{
			d = Vector.dotProduct_t(relativePos, surface.outVector[1]),
			v = surface.outVector[1],
		}, {
			d = Vector.dotProduct_t(relativePos, surface.outVector[2]),
			v = surface.outVector[2],
		}, {
			d = inDistance - surface.triangleSize,
			v = surface.outVector[3],
		}
	}
	table.sort(planeDistances, function(a, b) return a.d > b.d end )

	data.isBehind = upDistance < 0
	if previousPos ~= nil and Vector.dotProduct_t(previousPos, surface.surfaceNormal) < 0 then
		data.wasBehind = true
		if Vector.dotProduct_t(previousPos, surface.outVector[1]) <= 0 and Vector.dotProduct_t(previousPos, surface.outVector[2]) <= 0 and Vector.dotProduct_t(previousPos, surface.inVector) <= surface.triangleSize then
			data.wasInside = true
		end
	end
	
	data.distanceVector = Vector.multiply_t(surface.surfaceNormal, -upDistance)
	local edgeDistSq
	local distanceOffset = nil
	if planeDistances[1].d <= 0 then
		-- fully inside
		edgeDistSq = 0
		data.dist2d = 0
		data.inside = true
		data.nearestPointIsVertex = false
		data.distance = math.max(0, math.abs(upDistance) - radius)
	else
		data.inside = false
		-- Is the nearest point a vertex?
		local lmdp = Vector.dotProduct_t(planeDistances[1].v, planeDistances[2].v)
		data.nearestPointIsVertex = mul_fx(lmdp, planeDistances[1].d) <= planeDistances[2].d
		if data.nearestPointIsVertex then
			-- order matters
			local b = planeDistances[1].v
			local m = planeDistances[2].v
			local t = nil
			if
			  (m == surface.outVector[1] and b == surface.inVector) or
			  (m == surface.outVector[2] and b == surface.outVector[1]) or
			  (m == surface.inVector and b == surface.outVector[2])
			  then
				t = someKindOfTransformation(lmdp, planeDistances[1].d, planeDistances[2].d, b, m)
			else
				t = someKindOfTransformation(lmdp, planeDistances[2].d, planeDistances[1].d, m, b)
			end
			edgeDistSq = t[1] * t[1] + t[2] * t[2] + t[3] * t[3]
			data.dist2d = math.sqrt(edgeDistSq)
			if edgeDistSq > 0 then
				distanceOffset = t
			end
		else
			edgeDistSq = planeDistances[1].d
			data.dist2d = edgeDistSq
			edgeDistSq = edgeDistSq * edgeDistSq
			distanceOffset = Vector.multiply_t(planeDistances[1].v, -planeDistances[1].d)
		end
		
		data.distance = math.max(0, math.sqrt(edgeDistSq + upDistance * upDistance) - radius)
	end
	if data.distance == nil then error("nil distance to triangle!") end
	
	if distanceOffset ~= nil then
		data.distanceVector = Vector.add(data.distanceVector, distanceOffset)
	end
	if data.dist2d > radius or planeDistances[1].d >= radius or inDistance < -radius then
		data.pushOutBy = -1
	else
		data.pushOutBy = math.sqrt(radius * radius - edgeDistSq) - upDistance
	end
	
	data.interacting = true -- NOT the same thing as getting pushed
	if data.pushOutBy < 0 or radius - upDistance >= 0x1e001 then
		data.interacting = false
	elseif data.isBehind then
		if previousPos == nil then
			data.interacting = false
		elseif data.inside then
			if data.wasBehind == true and data.wasInside ~= true then
				data.interacting = false
			end
		else
			local o = 0
			if planeDistances[1].v == surface.inVector then
				o = surface.triangleSize
			end
			if Vector.dotProduct_t(previousPos, planeDistances[1].v) > o then
				data.interacting = false
			end	
		end
	end
	
	if data.wasBehind and previousPos ~= nil and Vector.dotProduct_t(previousPos, surface.surfaceNormal) < -0xa000 then
		data.wasFarBehind = true
	end
	
	if data.interacting then
		data.touchSlopedEdge = false
		if not data.inside and not data.nearestPointIsVertex and 0x424 >= planeDistances[1].v[2] and planeDistances[1].v[2] >= -0x424 then
			data.touchSlopedEdge = true
		end
	
		-- Will it push?
		data.push = true
		if toucher.previousPos ~= nil then
			local posDelta = Vector.subtract(toucher.pos, toucher.previousPos)
			local outwardMovement = Vector.dotProduct_t(posDelta, surface.surfaceNormal)
			-- 820 rule
			if outwardMovement > 819 then
				data.push = false
				data.outwardMovement = outwardMovement
			end
			
			-- Starting behind
			if data.wasBehind and (toucher.flags & 0x3b ~= 0 or data.wasFarBehind) then
				data.push = false
			end
		end
	end
	
	return data
end
local function getTouchDataForSurface(toucher, surface)
	local data = {}
	-- 1) Can we interact with this surface?
	-- Idk what these all represent.
	local st = surface.surfaceType
	if toucher.flags & 0x10 ~= 0 and st & 0xa000 ~= 0 then
		return { canTouch = false }
	end
	local unknown1 = st & 0x2010 == 0
	local unknown2 = toucher.flags & 4 == 0 or st & 0x2000 == 0
	local unknown3 = toucher.flags & 1 == 0 or st & 0x10 == 0
	if not (unknown1 or (unknown2 and unknown3)) then
		return { canTouch = false }
	end
	data.canTouch = true
	-- 2) How far away from the surface are we?
	local dd = getSurfaceDistanceData(toucher, surface)
	data.touching = dd.interacting
	data.pushOutDistance = dd.pushOutBy
	data.distance = dd.distance
	data.behind = dd.isBehind
	data.centerToTriangle = dd.distanceVector
	data.wasBehind = dd.wasBehind
	data.isInside = dd.inside
	data.push = dd.push
	data.outwardMovement = dd.outwardMovement
	data.dist2d = dd.dist2d
	-- wasInside

	if data.distance == nil then error("nil distance to triangle!") end
	return data
end
local function getCollisionDataForRacer(toucher)
	local nearby = getNearbyTriangles(toucher.pos, (mkdsiConfig.increaseRenderDistance and 3) or nil)
	if #nearby == 0 then
		return { all = {}, touched = {} }
	end

	local data = {}
	local touchList = {}
	local nearestWall = nil
	local nearestFloor = nil
	local maxPushOut = nil
	local lowestTriangle = nil
	local touchedEdgeWall = false
	local touchedFloor = false
	local skipEdgeWalls = false
	local skipFloorVerticals = false
	for i = 1, #nearby do
		local touch = getTouchDataForSurface(toucher, nearby[i])
		if touch.canTouch == true then
			local triangle = nearby[i]
			local thisData  = {
				triangle = triangle,
				touch = touch,
			}
			data[#data + 1] = thisData
			if touch.touching then
				touchList[#touchList + 1] = thisData
			end

			if touch.push then
				if triangle.isFloor and (maxPushOut == nil or touch.pushOutDistance > data[maxPushOut].touch.pushOutDistance) then
					maxPushOut = #data
				end
				if lowestTriangle == nil or touch.centerToTriangle[2] < lowestTriangle.touch.centerToTriangle[2] then
					lowestTriangle = thisData
				end
				touchedEdgeWall = touchedEdgeWall or triangle.collisionType == EDGE_WALL
				touchedFloor = touchedFloor or triangle.isFloor
			end
			
			-- find nearest wall/floor
			if triangle.isWall and not touch.push and (nearestWall == nil or touch.distance < data[nearestWall].touch.distance) then
				nearestWall = #data
			end
			if triangle.isFloor and not touch.push and (nearestFloor == nil or touch.distance < data[nearestFloor].touch.distance) then
				nearestFloor = #data
			end
		end
	end
	
	if touchedEdgeWall and touchedFloor then
		local v = lowestTriangle.touch.centerToTriangle
		v = { bit.arshift(v[1], 4), bit.arshift(v[2], 4), bit.arshift(v[3], 4) }
		if v[1] * v[1] + v[3] * v[3] <= v[2] * v[2] then
			-- Not allowed to touch edge walls.
			skipEdgeWalls = true
			for i = 1, #touchList do
				if touchList[i].triangle.collisionType == EDGE_WALL then
					touchList[i].touch.skipByEdge = true
				end
			end
		else
			-- Not allowed to fully touch floors.
			skipFloorVerticals = true
			for i = 1, #touchList do
				if touchList[i].triangle.isFloor then
					touchList[i].touch.skipByEdge = true
				end
			end
		end
	end
	if maxPushOut ~= nil and skipFloorVerticals == false then
		data[maxPushOut].controlsSlope = true
	end
	
	return {
		all = data,
		touched = touchList,
		nearestFloor = nearestFloor,
		nearestWall = nearestWall,
	}
end


local function getCourseCollisionData()
	someCourseData = memory.read_bytes_as_array(Memory.addrs.collisionData + 1, 0x38 - 1)
	someCourseData[0] = memory.read_u8(Memory.addrs.collisionData)

	local dataPtr = get_u32(someCourseData, 8)
	local endData = get_u32(someCourseData, 12)
	local triangleData = memory.read_bytes_as_array(dataPtr + 1, endData - dataPtr)
	triangleData[0] = memory.read_u8(dataPtr)
	
	triangles = {}
	local triCount = (endData - dataPtr) / 0x10 - 1
	for i = 1, triCount do -- there is no triangle ID 0
		local offs = i * 0x10
		triangles[i] = {
			id = i,
			triangleSize = get_s32(triangleData, offs + 0),
			vertexId = get_s16(triangleData, offs + 4),
			surfaceNormalId = get_s16(triangleData, offs + 6),
			outVector1Id = get_s16(triangleData, offs + 8),
			outVector2Id = get_s16(triangleData, offs + 10),
			inVectorId = get_s16(triangleData, offs + 12),
			surfaceType = get_u16(triangleData, offs + 14),
		}
		triangles[i].collisionType = (triangles[i].surfaceType >> 8) & 0x1f
		triangles[i].unkType = (triangles[i].surfaceType >> 2) & 3
		triangles[i].props = (1 << triangles[i].collisionType) | (1 << (triangles[i].unkType + 0x1a))
		triangles[i].isWall = triangles[i].props & 0x214300 ~= 0
		triangles[i].isFloor = triangles[i].props & 0x1e34ef ~= 0
		triangles[i].isOob = triangles[i].props & 0xC00 ~= 0

		triangles[i].skip = triangles[i].isActuallyLine or (1 << triangles[i].collisionType) & skippableTypes ~= 0
	end
		
	local vectorsPtr = get_u32(someCourseData, 4)
	local vectorData = memory.read_bytes_as_array(vectorsPtr + 1, dataPtr - vectorsPtr + 0x10)
	vectorData[0] = memory.read_u8(vectorsPtr)
	local vectors = {}
	local vecCount = (dataPtr - vectorsPtr + 0x10) // 6
	for i = 0, vecCount - 1 do
		local offs = i * 6
		vectors[i] = get_pos_16(vectorData, offs)
	end
	
	local vertexesPtr = get_u32(someCourseData, 0)
	local vertexData = memory.read_bytes_as_array(vertexesPtr + 1, vectorsPtr - vertexesPtr) -- guess about length
	vertexData[0] = memory.read_u8(vertexesPtr)
	local vertexes = {}
	local vertCount = (vectorsPtr - vertexesPtr) / 12
	for i = 0, vertCount - 1 do
		local offs = i * 12
		vertexes[i] = get_pos(vertexData, offs)
	end
	
	for i = 1, #triangles do
		local tri = triangles[i]
		tri.surfaceNormal = vectors[tri.surfaceNormalId]
		tri.inVector = vectors[tri.inVectorId]
		tri.vertex = {{}, {}, {}}
		tri.slope = {}
		tri.vertex[1] = vertexes[tri.vertexId]
		tri.outVector = {}
		tri.outVector[1] = vectors[tri.outVector1Id]
		tri.outVector[2] = vectors[tri.outVector2Id]
		tri.outVector[3] = vectors[tri.inVectorId]
		tri.slope[1] = Vector.crossProduct_float(tri.surfaceNormal, tri.outVector[1])
		tri.slope[2] = Vector.crossProduct_float(tri.surfaceNormal, tri.outVector[2])
		tri.slope[3] = Vector.crossProduct_float(tri.surfaceNormal, tri.outVector[3])
		-- Both slope vectors should be unit vectors, since surfaceNormal and outVectors are.
		tri.slope[1] = Vector.normalize_float(tri.slope[1])
		tri.slope[2] = Vector.normalize_float(tri.slope[2])
		tri.slope[3] = Vector.normalize_float(tri.slope[3])
		-- But one of them is pointed the wrong way
		tri.slope[1] = Vector.multiply(tri.slope[1], -1)

		local function computeVertex(slope)
			local a = Vector.dotProduct_float(vectors[tri.inVectorId], slope)
			local b = tri.triangleSize / a
			if a == 0 then
				-- This happens in rKB2.
				b = 0x1000 * 1000
				tri.ignore = true
			end
			local c = Vector.multiply(slope, b)
			return Vector.add(tri.vertex[1], c)
		end
		tri.vertex[3] = computeVertex(tri.slope[1])
		tri.vertex[2] = computeVertex(tri.slope[2])
	end
	
	local cmPtr = get_u32(someCourseData, 0xC)
	local cmSize = 0x28000 -- ???
	collisionMap = memory.read_bytes_as_array(cmPtr + 1, cmSize - 1)
	collisionMap[0] = memory.read_u8(cmPtr)

	return {
		triangles = triangles,
	}
end

_export = {
	getCourseCollisionData = getCourseCollisionData,
	getCollisionDataForRacer = getCollisionDataForRacer,
	getNearbyTriangles = getNearbyTriangles,
}
end
_()
local KCL = _export
_imports.KCL = KCL

local function _()
local Vector = _imports.Vector
local Memory = _imports.Memory
local read_pos = Memory.read_pos
local get_u32 = Memory.get_u32
local get_s32 = Memory.get_s32
local get_u16 = Memory.get_u16

local function mul_fx(a, b)
	return a * b // 0x1000
end

local ptrObjArray = nil
local function loadCourseData()
	ptrObjArray = memory.read_s32_le(Memory.addrs.ptrObjStuff + 0x10)
end


local function getBoxyPolygons(center, directions, sizes, sizes2)
	if sizes2 == nil then sizes2 = sizes end
	local offsets = {
		x1 = Vector.multiply(directions[1], sizes[1] / 0x1000),
		y1 = Vector.multiply(directions[2], sizes[2] / 0x1000),
		z1 = Vector.multiply(directions[3], sizes[3] / 0x1000),
		x2 = Vector.multiply(directions[1], sizes2[1] / 0x1000),
		y2 = Vector.multiply(directions[2], sizes2[2] / 0x1000),
		z2 = Vector.multiply(directions[3], sizes2[3] / 0x1000),
	}
	
	local s = Vector.subtract
	local a = Vector.add
	local verts = {
		s(s(s(center, offsets.x2), offsets.y2), offsets.z2),
		a(s(s(center, offsets.x2), offsets.y2), offsets.z1),
		s(a(s(center, offsets.x2), offsets.y1), offsets.z2),
		a(a(s(center, offsets.x2), offsets.y1), offsets.z1),
		s(s(a(center, offsets.x1), offsets.y2), offsets.z2),
		a(s(a(center, offsets.x1), offsets.y2), offsets.z1),
		s(a(a(center, offsets.x1), offsets.y1), offsets.z2),
		a(a(a(center, offsets.x1), offsets.y1), offsets.z1),
	}
	return {
		{ verts[1], verts[5], verts[7], verts[3] },
		{ verts[1], verts[5], verts[6], verts[2] },
		{ verts[1], verts[3], verts[4], verts[2] },
		{ verts[8], verts[4], verts[2], verts[6] },
		{ verts[8], verts[4], verts[3], verts[7] },
		{ verts[8], verts[6], verts[5], verts[7] },
	}
end
local function getCylinderPolygons(center, directions, radius, h1, h2)
	local offsets = {
		Vector.multiply(directions[1], radius / 0x1000),
		Vector.multiply(directions[2], h1 / 0x1000),
		Vector.multiply(directions[3], radius / 0x1000),
		Vector.multiply(directions[2], -h2 / 0x1000),
	}
	
	local a = Vector.add
	local m = Vector.multiply
	local norm = Vector.normalize_float
	radius = radius / 0x1000
	local around = {
		offsets[1],
		m(norm(a(m(offsets[1], 2), offsets[3])), radius),
		m(norm(a(offsets[1], offsets[3])), radius),
		m(norm(a(offsets[1], m(offsets[3], 2))), radius),
		offsets[3],
		m(norm(a(m(offsets[1], -1), m(offsets[3], 2))), radius),
		m(norm(a(m(offsets[1], -1), offsets[3])), radius),
		m(norm(a(m(offsets[1], -2), offsets[3])), radius),
	}
	local count = #around
	for i = 1, count do
		around[#around + 1] = m(around[i], -1)
	end
	
	local tc = Vector.add(center, offsets[2])
	local bc = Vector.add(center, offsets[4])
	local vertsT = {}
	local vertsB = {}
	for i = 1, #around do
		vertsT[i] = a(tc, around[i])
		vertsB[i] = a(bc, around[i])
	end
	
	local polys = {}
	for i = 1, #around - 1 do
		polys[i] = { vertsT[i], vertsT[i + 1], vertsB[i + 1], vertsB[i] }
	end
	polys[#polys + 1] = vertsT
	polys[#polys + 1] = vertsB
	return polys
end

local mapObjTypes = {}
local t = mapObjTypes
if true then -- I just want to collapse this block in my editor.
	t[0] = "follows player"
	t[11] = "STOP! signage"; t[14] = "puddle";
	t[101] = "item box"; t[102] = "post"; t[103] = "wooden crate";
	t[104] = "coin"; t[106] = "shine";
	t[110] = "gate trigger";
	t[201] = "moving item box"; t[202] = "moving block";
	t[203] = "gear"; t[204] = "bridge";
	t[205] = "clock hand"; t[206] = "gear";
	t[207] = "pendulum"; t[208] = "rotating floor";
	t[209] = "rotating bridge"; t[210] = "roulette";
	t[0x12e] = "coconut tree"; t[0x12f] = "pipe";
	t[0x130] = "wumpa-fruit tree";
	t[0x138] = "striped tree";
	t[0x145] = "autumn tree"; t[0x146] = "winter tree";
	t[0x148] = "palm tree";
	t[0x14f] = "pinecone tree"; t[0x150] = "beanstalk";
	t[0x156] = "N64 winter tree";
	t[401] = "goomba"; t[402] = "giant snowball"; t[403] = "thwomp";
	t[405] = "bus"; t[406] = "chain chomp";
	t[407] = "chain chomp post"; t[408] = "leaping fireball"; t[409] = "mole";
	t[410] = "car"; t[411] = "cheep cheep"; t[412] = "truck";
	t[413] = "snowman"; t[414] = "coffin"; t[415] = "bats";
	t[418] = "bullet bill";
	t[419] = "walking tree"; t[420] = "flamethrower"; t[421] = "stray chain chomp";
	t[422] = "piranha plant"; t[423] = "rocky wrench"; t[424] = "bumper"; 
	t[425] = "flipper"; t[427] = "fireball";
	t[428] = "crab";
	t[431] = "fireballs"; t[432] = "pinball"; t[433] = "boulder";
	t[434] = "pokey"; t[436] = "strawberry bumper";
	t[437] = "Strawberry Bumper";
	t[501] = "bully"; t[502] = "Chief Chilly";
	t[0x1f8] = "King Bomb-omb";
	t[0x1fb] = "Eyerok"; t[0x1fd] = "King Boo";
	t[0x1fe] = "Wiggler";
end

local FLAG_DYNAMIC = 0x1000
local FLAG_MAPOBJ  = 0x2000
local FLAG_ITEM    = 0x4000
local FLAG_RACER   = 0x8000

local function getBoxyDistances(obj, pos, radius)
	local posDelta = Vector.subtract(pos, obj.dynPos)
	
	local dir = obj.orientation
	local sizes = obj.sizes
	local orientedPosDelta = {
		Vector.dotProduct_t(posDelta, dir[1]),
		Vector.dotProduct_t(posDelta, dir[2]),
		Vector.dotProduct_t(posDelta, dir[3]),
	}
	local orientedDistanceTo = {
		math.abs(orientedPosDelta[1]) - radius - sizes[1],
		math.abs(orientedPosDelta[2]) - radius - sizes[2],
		math.abs(orientedPosDelta[3]) - radius - sizes[3],
	}
	local outsideTheBox = 0
	for i = 1, 3 do
		if orientedDistanceTo[i] > 0 then
			outsideTheBox = outsideTheBox + orientedDistanceTo[i] * orientedDistanceTo[i]
		end
	end
	local totalDistance = nil
	if outsideTheBox ~= 0 then
		totalDistance = math.sqrt(outsideTheBox)
	else
		totalDistance = math.max(orientedDistanceTo[1], orientedDistanceTo[2], orientedDistanceTo[3])
	end
	return {
		orientedDistanceTo[1],
		orientedDistanceTo[2],
		orientedDistanceTo[3],
		totalDistance,
	}
end
local function getCylinderDistances(obj, pos, radius)
	local posDelta = Vector.subtract(pos, obj.dynPos)
	
	local dir = obj.orientation
	local orientedPosDelta = {
		Vector.dotProduct_t(posDelta, dir[1]),
		Vector.dotProduct_t(posDelta, dir[2]),
		Vector.dotProduct_t(posDelta, dir[3]),
	}
	orientedPosDelta = {
		h = math.sqrt(orientedPosDelta[1] * orientedPosDelta[1] + orientedPosDelta[3] * orientedPosDelta[3]),
		v = orientedPosDelta[2]
	}
	local bHeight = obj.bHeight
	if bHeight == nil then bHeight = obj.height end
	local orientedDistanceTo = {
		math.abs(orientedPosDelta.h) - radius - obj.objRadius,
		math.max(
			orientedPosDelta.v - radius - obj.height,
			-(orientedPosDelta.v + radius + bHeight)
		),
	}
	local outside = 0
	for i = 1, 2 do
		if orientedDistanceTo[i] > 0 then
			outside = outside + orientedDistanceTo[i] * orientedDistanceTo[i]
		end
	end
	local totalDistance = nil
	if outside ~= 0 then
		totalDistance = math.sqrt(outside)
	else
		totalDistance = math.max(orientedDistanceTo[1], orientedDistanceTo[2])
	end
	return {
		h = math.floor(orientedDistanceTo[1]),
		v = math.floor(orientedDistanceTo[2]),
		d = totalDistance,
	}
end

local function getDetailsForBoxyObject(obj)
	obj.boxy = true
	if obj.hitboxFunc == Memory.hitboxFuncs.car then
		obj.sizes = read_pos(obj.ptr + 0x114)
		obj.backSizes = {
			obj.sizes[1],
			0,
			memory.read_s32_le(obj.ptr + 0x120),
		}
	elseif obj.hitboxFunc == Memory.hitboxFuncs.clockHand then
		obj.sizes = read_pos(obj.ptr + 0x58)
		obj.backSizes = Vector.copy(obj.sizes)
		obj.backSizes[3] = 0
	elseif obj.hitboxFunc == Memory.hitboxFuncs.pendulum then
		obj.sizes = {
			obj.objRadius,
			obj.objRadius,
			memory.read_s32_le(obj.ptr + 0x108),
		}
	elseif obj.hitboxFunc == Memory.hitboxFuncs.rockyWrench then
		obj.sizes = {
			obj.objRadius,
			memory.read_s32_le(obj.ptr + 0xa0),
			obj.objRadius,
		}
	elseif obj.hitboxFunc == Memory.hitboxFuncs.bully then
		obj.sizes = read_pos(obj.ptr + 0x25c)
	else
		obj.sizes = read_pos(obj.ptr + 0x58)
	end
	obj.dynPos = obj.objPos
	obj.polygons = function() return getBoxyPolygons(obj.objPos, obj.orientation, obj.sizes, obj.backSizes) end
end
local function getDetailsForCylinder2Object(obj, isBumper)
	obj.cylinder2 = true
	obj.dynPos = obj.objPos -- It may not be dynamic, but getCylinderDistances expexts this
	
	if isBumper then
		obj.bHeight = 0
		if memory.read_u16_le(obj.ptr + 2) & 0x800 == 0 and memory.read_u32_le(obj.ptr + 0x11c) == 1 then
			obj.objRadius = mul_fx(obj.objRadius, memory.read_u32_le(obj.ptr + 0xbc))
		end
	else
		obj.bHeight = obj.height
	end
	
	obj.polygons = function() return getCylinderPolygons(obj.objPos, obj.orientation, obj.objRadius, obj.height, obj.bHeight) end
end
local function getDetailsForDynamicBoxyObject(obj)
	obj.sizes = read_pos(obj.ptr + 0x100)
	obj.dynPos = read_pos(obj.ptr + 0xf4)
	obj.backSizes = Vector.copy(obj.sizes)
	obj.backSizes[3] = memory.read_s32_le(obj.ptr + 0x10c)
	obj.polygons = getBoxyPolygons(obj.dynPos, obj.orientation, obj.sizes, obj.backSizes)
end
local function getDetailsForDynamicCylinderObject(obj)
	obj.objRadius = memory.read_s32_le(obj.ptr + 0x100)
	obj.height = memory.read_s32_le(obj.ptr + 0x104)
	obj.dynPos = read_pos(obj.ptr + 0xf4)
	obj.polygons = getCylinderPolygons(obj.dynPos, obj.orientation, obj.objRadius, obj.height, obj.height)
end
local function getMapObjDetails(obj)
	local objPtr = obj.ptr
	local typeId = memory.read_u16_le(objPtr)
	obj.typeId = typeId
	obj.type = mapObjTypes[typeId] or ("unknown " .. typeId)
	obj.boxy = false
	obj.cylinder = false
	
	obj.objRadius = memory.read_s32_le(objPtr + 0x58)
	obj.height = memory.read_s32_le(objPtr + 0x5C)
	obj.orientation = {
		read_pos(obj.ptr + 0x28),
		read_pos(obj.ptr + 0x34),
		read_pos(obj.ptr + 0x40),
	}

	-- Is this right?
	obj.itemPos = obj.objPos
	obj.itemRadius = obj.objRadius

	-- Hitbox
	local hitboxType = ""
	if memory.read_u16_le(objPtr + 2) & 1 == 0 then
		local maybePtr = memory.read_s32_le(objPtr + 0x98)
		local hbType = 0
		if maybePtr > 0 then
			-- The game has no null check, but I don't want to keep seeing the "attempted read outside memory" warning
			hbType = memory.read_s32_le(maybePtr + 8)
		end
		if hbType == 0 or hbType > 5 or hbType < 0 then
			hitboxType = ""
		elseif hbType == 1 then
			hitboxType = "spherical"
		elseif hbType == 2 then
			hitboxType = "cylindrical"
			obj.polygons = function() return getCylinderPolygons(obj.objPos, obj.orientation, obj.objRadius, obj.height, obj.height) end
		elseif hbType == 3 then
			hitboxType = "cylinder2" -- I can't find an object in game that directly uses this.
			getDetailsForCylinder2Object(obj, false)
		elseif hbType == 4 then
			hitboxType = "boxy"
			getDetailsForBoxyObject(obj)
		elseif hbType == 5 then
			hitboxType = "custom" -- Object defines its own collision check function
			obj.chb = memory.read_u32_le(objPtr + 0x98)
			obj.hitboxFunc = memory.read_u32_le(obj.chb + 0x18)
			if obj.hitboxFunc == Memory.hitboxFuncs.car then
				hitboxType = "boxy"
				getDetailsForBoxyObject(obj)
			elseif obj.hitboxFunc == Memory.hitboxFuncs.bumper then
				hitboxType = "cylinder2"
				getDetailsForCylinder2Object(obj, true)
			elseif obj.hitboxFunc == Memory.hitboxFuncs.clockHand then
				hitboxType = "boxy"
				getDetailsForBoxyObject(obj)
			elseif obj.hitboxFunc == Memory.hitboxFuncs.pendulum then
				hitboxType = "spherical"
				obj.objRadius = memory.read_s32_le(obj.ptr + 0x104)
				getDetailsForBoxyObject(obj)
				obj.multiBox = true
			elseif obj.hitboxFunc == Memory.hitboxFuncs.rockyWrench then
				if memory.read_u8(obj.ptr + 0xb0) == 1 then
					hitboxType = "no hitbox"
				else
					hitboxType = "spherical"
					obj.multiBox = true
					getDetailsForBoxyObject(obj)
				end
			elseif obj.hitboxFunc == Memory.hitboxFuncs.bully then
				obj.objPos = read_pos(objPtr + 0x238)
				obj.objRadius = memory.read_u32_le(objPtr + 0x25c)
				obj.height = memory.read_u32_le(objPtr + 0x260)
		
				local hitboxMode = memory.read_u8(objPtr + 0x234)
				-- non-spherical is not tested at all, Idk what uses them
				if hitboxMode == 0 then
					hitboxType = "spherical"
				elseif hitboxMode == 1 then
					hitboxType = "boxy"
					getDetailsForBoxyObject(obj)
				elseif hitboxMode == 2 then
					hitboxType = "cylinder" -- 2?
					obj.polygons = function() return getCylinderPolygons(obj.objPos, obj.orientation, obj.objRadius, obj.height, obj.height) end
				end
			else
				hitboxType = hitboxType .. " " .. string.format("%x", obj.hitboxFunc)
			end
		end
	end
	if hitboxType == "" then hitboxType = "no hitbox" end
	obj.hitboxType = hitboxType
end
local itemNames = { -- IDs according to list of itemsets
	"red shell", "banana", "mushroom",
	"star", "blue shell", "lightning",
	"fake item box", "itembox?", "bomb",
	"blooper", "boo", "gold mushroom",
	"bullet bill",
}
itemNames[0] = "green shell"
local function getItemDetails(obj)
	local ptr = obj.ptr
	obj.itemRadius = memory.read_s32_le(ptr + 0xE0)
	obj.objRadius  = memory.read_s32_le(ptr + 0xDC)
	obj.itemTypeId = memory.read_s32_le(ptr + 0x44)
	obj.itemName = itemNames[obj.itemTypeId]
	obj.itemPos = obj.objPos
	obj.velocity = read_pos(ptr + 0x5C)
	obj.hitboxType = "item"
end
local function getRacerObjDetails(obj)
	obj.objRadius = memory.read_s32_le(obj.ptr + 0x1d0)
	obj.itemRadius = obj.objRadius
	obj.itemPos = read_pos(obj.ptr + 0x1d8)
	obj.type = "racer"
	obj.hitboxType = "item"
end
local function isCoinCollected(objPtr)
	return memory.read_u16_le(objPtr + 2) & 0x01 ~= 0
end
local function isGhost(objPtr)
	local flags7c = memory.read_u8(objPtr + 0x7C)
	return flags7c & 0x04 ~= 0
end
local function getObjectDetails(obj)
	-- isRacer is used to identify the racer Lua tables
	-- Those already have racer's details and should not also get object's details.
	if obj.gotDetails == true or obj.isRacer == true then return end
	obj.gotDetails = true
	obj.basePos = obj.objPos
	local flags = obj.flags
	if flags & FLAG_MAPOBJ ~= 0 then
		obj.isMapObject = true
		getMapObjDetails(obj)
	elseif flags & FLAG_ITEM ~= 0 then
		obj.isItem = true
		getItemDetails(obj)
	elseif flags & FLAG_RACER ~= 0 then
		getRacerObjDetails(obj)
	else
		return
	end

	if flags & 0x1000 ~= 0 then
		obj.dynamic = true
		local aCodePtr = memory.read_u8(obj.ptr + 0x134)
		if aCodePtr == 0 then
			obj.dynamicType = "boxy"
			obj.boxy = true
			getDetailsForDynamicBoxyObject(obj)
		elseif aCodePtr == 1 then
			obj.dynamicType = "cylinder"
			getDetailsForDynamicCylinderObject(obj)
		end
		if obj.dynamicType ~= nil then
			if obj.hitboxType == "no hitbox" then
				obj.hitboxType = "dynamic " .. obj.dynamicType
			else
				obj.hitboxType = obj.hitboxType .. " + " .. obj.dynamicType
			end
		end
	else
		obj.dynamic = false
	end
end

local allObjects = {}
local function readObjects()
	local maxCount = memory.read_u16_le(Memory.addrs.ptrObjStuff + 0x08)
	local count = 0
	local itemsThatAreObjs = {}

	-- get basic info
	local newObjectsTable = {}
	local list = {}
	local objData = memory.read_bytes_as_array(ptrObjArray + 1, 0x1c * 255 - 1)
	--objData[0] = memory.read_u8(ptrObjArray)
	local id = 0
	while id < 255 and count ~= maxCount do -- 255? What is max max?
		local current = id * 0x1c
		local objPtr = get_u32(objData, current + 0x18)
		local flags = get_u16(objData, current + 0x14)
		-- local declarations must be made before all gotos
		local posPtr
		local obj

		if objPtr == 0 then
			goto continue
		end

		count = count + 1
		-- flag 0x0200: deactivated or something
		if flags & 0x200 ~= 0 then
			goto continue
		end
		posPtr = get_s32(objData, current + 0xC)
		if posPtr == 0 then
			-- Apparently this is a way that the game "removes" an object from the list.
			goto continue
		end

		obj = {
			id = id,
			objPos = read_pos(posPtr),
			flags = flags,
			ptr = objPtr,
			skip = false,
		}
		if flags & FLAG_MAPOBJ ~= 0 then
			obj.typeId = memory.read_s16_le(obj.ptr)
			if obj.typeId == 0x68 and isCoinCollected(objPtr) then
				obj.skip = true
			end
		elseif flags & FLAG_RACER ~= 0 then
			if isGhost(objPtr) then
				obj.skip = true
			end
		elseif flags & FLAG_ITEM ~= 0 then
			itemsThatAreObjs[objPtr] = true
		elseif flags & FLAG_DYNAMIC == 0 then
			obj.skip = true
		end
		newObjectsTable[objPtr] = obj
		list[#list + 1] = obj

		::continue::
		id = id + 1
	end

	-- items
	local setsPtr = memory.read_u32_le(Memory.addrs.ptrItemSets)
	for iSet = 0, 13 do
		local sp = setsPtr + iSet*0x44
		local setPtr = memory.read_u32_le(sp + 4)
		local setCount = memory.read_u16_le(sp + 0x10)
		for i = 0, setCount - 1 do
			local itemPtr = memory.read_u32_le(setPtr + i*4)
			if itemsThatAreObjs[itemPtr] == nil then
				local itemFlags = memory.read_u32_le(itemPtr + 0x74)
				newObjectsTable[itemPtr] = {
					ptr = itemPtr,
					flags = FLAG_ITEM,
					skip = itemFlags & 0x0080000 ~= 0, -- Idk what these flags mean
					itemFlags = itemFlags,
					-- others set were 0x0020080
					objPos = read_pos(itemPtr + 0x50)
				}
				list[#list + 1] = newObjectsTable[itemPtr]
			else
				local itemFlags = memory.read_u32_le(itemPtr + 0x74)
				local obj = newObjectsTable[itemPtr]
				obj.skip = obj.skip or (itemFlags & 0x0080000 ~= 0)
				obj.itemFlags = itemFlags
				itemsThatAreObjs[itemPtr] = nil
			end
		end
	end

	for k, v in pairs(itemsThatAreObjs) do
		print("orphaned item", k, v)
	end

	allObjects = newObjectsTable
	allObjects.list = list
	return allObjects
end
local function getNearbyObjects(thing, dist)
	local distdist = dist * dist

	local nearbyObjects = {}
	for _, obj in pairs(allObjects.list) do
		if obj.skip == false and obj.ptr ~= thing.ptr then
			local flags = obj.flags

			local racerPos = thing.objPos
			if flags & (FLAG_ITEM | FLAG_RACER) ~= 0 then
				racerPos = thing.itemPos
			end
			local dx = racerPos[1] - obj.objPos[1]
			local dz = racerPos[3] - obj.objPos[3]
			local d = dx * dx + dz * dz
			if d <= distdist then
				nearbyObjects[#nearbyObjects + 1] = obj
			else
				if (obj.typeId == 209 and d <= 9e13) or (obj.typeId == 11 and d < 1.2e13) or (obj.typeId == 205 and d < 1e13) then
					-- obj 209: rotating bridge in Bowser's Castle: it's huge
					-- obj 205: TTC clock hands
					-- obj 11: stop signage, they are huge boxes
					nearbyObjects[#nearbyObjects + 1] = obj
				end
			end
		end -- if skip
	end -- for

	for i = 1, #nearbyObjects do
		local obj = nearbyObjects[i]

		getObjectDetails(obj)

		if obj.hitboxType == "cylindrical" then
			local relative = Vector.subtract(thing.objPos, obj.objPos)
			local distance = math.sqrt(relative[1] * relative[1] + relative[3] * relative[3])
			obj.distance = distance - thing.objRadius - obj.objRadius
			-- TODO: Check vertical distance?
		elseif obj.hitboxType == "spherical" then
			local relative = Vector.subtract(thing.objPos, obj.objPos)
			local distance = math.sqrt(relative[1] * relative[1] + relative[2] * relative[2] + relative[3] * relative[3])
			obj.distance = distance - thing.objRadius - obj.objRadius
			-- Special object: pendulum
			if obj.hitboxFunc == Memory.hitboxFuncs.pendulum then
				relative = Vector.subtract(thing.objPos, obj.objPos)
				obj.distanceComponents = {
					h = math.floor(obj.distance),
					v = Vector.dotProduct_t(relative, obj.orientation[3]) - thing.objRadius - obj.sizes[3],
				}
				obj.distance = math.max(obj.distanceComponents.h, obj.distanceComponents.v)
			end
		elseif obj.hitboxType == "item" then
			local relative = Vector.subtract(thing.itemPos, obj.itemPos)
			local distance = math.sqrt(relative[1] * relative[1] + relative[2] * relative[2] + relative[3] * relative[3])
			obj.distance = distance - thing.itemRadius - obj.itemRadius
		elseif obj.boxy then
			obj.distanceComponents = getBoxyDistances(obj, thing.objPos, thing.objRadius)
			-- TODO: Do all dynamic boxy objects have racer-spherical hitboxes?
			-- Also TODO: Find a nicer way to display this maybe?
			obj.innerDistComps = getBoxyDistances(obj, thing.objPos, 0)
			obj.distance = obj.distanceComponents[4]
		elseif obj.dynamicType == "cylinder" or obj.hitboxType == "cylinder2" then
			obj.distanceComponents = getCylinderDistances(obj, thing.objPos, thing.objRadius)
			obj.distance = obj.distanceComponents.d
		else
			local relative = Vector.subtract(thing.objPos, obj.objPos)
			obj.distance = math.sqrt(relative[1] * relative[1] + relative[2] * relative[2] + relative[3] * relative[3])
		end
	end

	local realNearby = {}
	local nearest = nil
	for i = 1, #nearbyObjects do
		local obj = nearbyObjects[i]
		if obj.distance <= dist then
			realNearby[#realNearby+1] = obj
			if nearest == nil or obj.distance < nearest.distance then
				nearest = obj
			end
		end
	end

	return { realNearby, nearest }
end

_export = {
	loadCourseData = loadCourseData,
	getNearbyObjects = getNearbyObjects,
	isGhost = isGhost,
	getBoxyPolygons = getBoxyPolygons,
	mapObjTypes = mapObjTypes,
	readObjects = readObjects,
	getObjectDetails = getObjectDetails,
}
end
_()
local Objects = _export
_imports.Objects = Objects

local function _()
local Vector = _imports.Vector
local Objects = _imports.Objects
local KCL = _imports.KCL

local function fixLine(x1, y1, x2, y2)
	-- Avoid drawing over the bottom screen
	if y1 > 1 and y2 > 1 then
		return nil
	elseif y1 > 1 then
		local cut = (y1 - 1) / (y1 - y2)
		y1 = 1
		x1 = x2 + ((x1 - x2) * (1 - cut))
		if y2 < -1 then
			-- very high zooms get weird
			cut = (-1 - y2) / (y1 - y2)
			y2 = -1
			x2 = x1 + ((x2 - x1) * (1 - cut))
		end
	elseif y2 > 1 then
		local cut = (y2 - 1) / (y2 - y1)
		y2 = 1
		x2 = x1 + ((x2 - x1) * (1 - cut))
		if y1 < -1 then
			-- very high zooms get weird
			cut = (-1 - y1) / (y2 - y1)
			y1 = -1
			x1 = x2 + ((x1 - x2) * (1 - cut))
		end
	end
	-- If we cut out the other sides, that would lead to polygons not drawing correctly.
	-- Because if we zoom in, all lines would be fully outside the bounds and so get cut out.
	return { x1, y1, x2, y2 }
end

local function scaleAtDistance(point, size, camera)
	if camera.orthographic then
		size = size / camera.scale
		return size - 0.5 -- BizHawk dumb?
	else
		local v = Vector.subtract(point, camera.location)
		size = size / Vector.getMagnitude(v)
		return size / camera.fovW * camera.w
	end
end
local function point3Dto2D(vector, camera)
	local v = Vector.subtract(vector, camera.location)
	local mat = camera.rotationMatrix
	local rotated = {
		(v[1] * mat[1][1] + v[2] * mat[1][2] + v[3] * mat[1][3]) / 0x1000,
		(v[1] * mat[2][1] + v[2] * mat[2][2] + v[3] * mat[2][3]) / 0x1000,
		(v[1] * mat[3][1] + v[2] * mat[3][2] + v[3] * mat[3][3]) / 0x1000,
	}
	if camera.orthographic then
		return {
			rotated[1] / camera.scale / camera.w,
			-rotated[2] / camera.scale / camera.h,
		}
	else
		-- Perspective
		if rotated[3] < 0x1000 then
			return { 0xffffff, 0xffffff } -- ?
		end
		local scaledByDistance = Vector.multiply(rotated, 0x1000 / rotated[3])
		return {
			scaledByDistance[1] / camera.fovW,
			-scaledByDistance[2] / camera.fovH,
		}
	end
end
local function line3Dto2D(v1, v2, camera)
	-- Must have a line transformation, because:
	-- Assume you have a triangle where two vertexes are in front of camera, one to the left and one to the right.
	-- The other vertex is far behind the camera, directly behind.
	-- This triangle should appear, in 2D to have four points. The line from v1 to vBehind should diverge from the line from v2 to vBehind.
	v1 = Vector.subtract(v1, camera.location)
	v2 = Vector.subtract(v2, camera.location)
	local mat = camera.rotationMatrix
	v1 = {
		(v1[1] * mat[1][1] + v1[2] * mat[1][2] + v1[3] * mat[1][3]) / 0x1000,
		(v1[1] * mat[2][1] + v1[2] * mat[2][2] + v1[3] * mat[2][3]) / 0x1000,
		(v1[1] * mat[3][1] + v1[2] * mat[3][2] + v1[3] * mat[3][3]) / 0x1000,
	}
	v2 = {
		(v2[1] * mat[1][1] + v2[2] * mat[1][2] + v2[3] * mat[1][3]) / 0x1000,
		(v2[1] * mat[2][1] + v2[2] * mat[2][2] + v2[3] * mat[2][3]) / 0x1000,
		(v2[1] * mat[3][1] + v2[2] * mat[3][2] + v2[3] * mat[3][3]) / 0x1000,
	}
	if camera.orthographic then
		-- Orthographic
		return {
			{
				v1[1] / camera.scale / camera.w,
				-v1[2] / camera.scale / camera.h,
			},
			{
				v2[1] / camera.scale / camera.w,
				-v2[2] / camera.scale / camera.h,
			},
		}
	else		
		-- Perspective
		if v1[3] < 0x1000 and v2[3] < 0x1000 then
			return nil
		end
		local flip = false
		if v1[3] < 0x1000 then
			flip = true
			local temp = v1
			v1 = v2
			v2 = temp
		end
		local changed = nil
		if v2[3] < 0x1000 then
			local diff = Vector.subtract(v1, v2)
			local percent = (v1[3] - 0x1000) / diff[3]
			if percent > 1 then error("invalid math") end
			v2 = Vector.subtract(v1, Vector.multiply(diff, percent))
			if v2[3] > 0x1001 or v2[3] < 0xfff then
				print(v2)
				error("invalid math")
			end
			changed = 2
			if flip then changed = 1 end
		end
		if flip then
			local temp = v1
			v1 = v2
			v2 = temp
		end
		local s1 = Vector.multiply(v1, 0x1000 / v1[3])
		local s2 = Vector.multiply(v2, 0x1000 / v2[3])
		local p1 = {
			s1[1] / camera.fovW,
			-s1[2] / camera.fovH,
		}
		local p2 = {
			s2[1] / camera.fovW,
			-s2[2] / camera.fovH,
		}
		
		return { p1, p2, changed }
	end
end

local function solve(m, v)
	-- Solve the system of linear equations to find which 3D directions to move in
	-- horizontal is 1, 0, 0; vertical is 0, 1, 0
	local m1 = { m[1][1], m[1][2], m[1][3], v[1] }
	local m2 = { m[2][1], m[2][2], m[2][3], v[2] }
	local m3 = { m[3][1], m[3][2], m[3][3], v[3] }
	local t = nil
	if m1[1] == 0 then
		if m2[1] ~= 0 then t = m1; m1 = m2; m2 = t;
		else t = m1; m1 = m3; m3 = t; end
	end
	if m2[2] == 0 then
		t = m2; m2 = m3; m3 = t;
	end
	local elim = m2[1] / m1[1]
	m2 = { 0, m2[2] - m1[2]*elim, m2[3] - m1[3]*elim, m2[4] - m1[4]*elim }
	elim = m3[1] / m1[1]
	m3 = { 0, m3[2] - m1[2]*elim, m3[3] - m1[3]*elim, m3[4] - m1[4]*elim }
	elim = m3[2] / m2[2]
	m3 = { m3[1] - m2[1]*elim, 0, m3[3] - m2[3]*elim, m3[4] - m2[4]*elim }
	local z = m3[4] / m3[3]
	local y = (m2[4] - z*m2[3]) / m2[2]
	local x = (m1[4] - z*m1[3] - y*m1[2]) / m1[1]
	return { x, y, z }
end
local function getDirectionsFrom2d(camera)
	return {
		solve(camera.rotationMatrix, {0x1000, 0, 0}),
		solve(camera.rotationMatrix, {0, 0x1000, 0}),
	}
end

local PIXEL = 1 -- pixel, point, color
local CIRCLE = 2 -- circle, center, radius (2D), line, fill
local LINE = 3 -- line, point1, point2, color
local POLYGON = 4 -- polygon, verts, line, fill
local TEXT = 5 -- text, point, string

local HITBOX = 6 -- hitbox, object, hitboxType, color
local HITBOX_PAIR = 7 -- hitbox_pair, object, racer

local que = {}

local function addToDrawingQue(priority, data)
	priority = priority or 0
	if que[priority] == nil then
		que[priority] = {}
	end
	local pQue = que[priority]
	pQue[#pQue + 1] = data
end

local function lineFromVector(base, vector, scale, color, priority)
	local scaledVector = Vector.multiply(vector, scale / 0x1000)
	addToDrawingQue(priority, { LINE, base, Vector.add(base, scaledVector), color })
end

local function processQue(camera)
	-- Order of keys given by pairs is not guaranteed.
	-- We cannot use ipairs because we may not have a continuous range of priorities.
	local priorities = {}
	for k, _ in pairs(que) do
		priorities[#priorities + 1] = k
	end
	table.sort(priorities)
	
	local cw = camera.w
	local ch = camera.h
	local cx = camera.x
	local cy = camera.y
	local ops = {}
	local opid = 1

	local function makeCircle(point2D, radius2D, line, fill)
		if radius2D < cw * 3 then -- We skip drawing circles that are significantly larger than the screen...?
			-- Skip drawing cirlces if they are entirely outside the viewport.
			if point2D[2] * ch + radius2D >= -ch and point2D[2] * ch - radius2D <= ch then
				if point2D[1] * cw + radius2D >= -cw and point2D[1] * cw - radius2D <= cw then
					ops[opid] = {
						CIRCLE,
						point2D[1] * cw + cx - radius2D, point2D[2] * ch + cy - radius2D,
						radius2D * 2,
						line, fill,
					}
					opid = opid + 1
				end
			end
		end
	end

	local function makePolygon(verts, lineColor, fill)
		local edges = {}
		for j = 1, #verts do
			local e = nil
			if j ~= #verts then
				e = line3Dto2D(verts[j], verts[j + 1], camera)
			else
				e = line3Dto2D(verts[j], verts[1], camera)
			end
			if e ~= nil then
				edges[#edges + 1] = e
			end
		end
		if #edges ~= 0 then
			local points = {}
			for j = 1, #edges do
				points[#points + 1] = edges[j][1]
				if edges[j][3] ~= nil then
					points[#points + 1] = edges[j][2]
				end
			end
			local fp = {}
			for j = 1, #points do
				local nextId = (j % #points) + 1
				local line = fixLine(points[j][1], points[j][2], points[nextId][1], points[nextId][2])
				if line ~= nil then
					if #fp == 0 or line[1] ~= fp[#fp][1] or line[2] ~= fp[#fp][2] then
						fp[#fp + 1] = { line[1], line[2] }
					end
					if line[3] ~= fp[1][1] or line[4] ~= fp[1][2] then
						fp[#fp + 1] = { line[3], line[4] }
					end
				end
			end
			-- Transform points to screen pixels
			for i = 1, #fp do
				fp[i] = { math.floor(fp[i][1] * cw + cx + 0.5), math.floor(fp[i][2] * ch + cy + 0.5) }
			end
			
			if #fp ~= 0 then
				if #fp == 1 then
					ops[opid] = { PIXEL, fp[1][1], fp[1][2], lineColor }
				else
					ops[opid] = { POLYGON, fp, lineColor, fill }
				end
				opid = opid + 1
			end
		end
	end

	for i = 1, #priorities do
		for _, v in ipairs(que[priorities[i]]) do
			if v[1] == POLYGON then
				makePolygon(v[2], v[3], v[4])
			elseif v[1] == CIRCLE then
				local point = point3Dto2D(v[2], camera)
				makeCircle(point, v[3], v[4], v[5])
			elseif v[1] == HITBOX then
				local object = v[2]
				local hitboxType = v[3]
				local color = v[4]
				
				if camera.overlay == true and (color & 0xff000000) == 0xff000000 then
					color = color & 0x50ffffff
				end			
				local skipPolys = false
				if hitboxType == "spherical" or (hitboxType == "cylindrical" and Vector.equals(camera.rotationVector, {0,-0x1000,0})) then
					skipPolys = hitboxType == "cylindrical"
					local point2D = point3Dto2D(object.objPos, camera)
					local radius = scaleAtDistance(object.objPos, object.objRadius, camera)
					if radius > cw then
						makeCircle(point2D, radius, color, (((color >> 24) & 0xff ~= 0xff) and color) or nil)
						-- Small circles, so we can zoom in on racers to see the center
						local smallsize = 300
						radius = scaleAtDistance(object.objPos, smallsize, camera)
						makeCircle(point2D, radius, color, color & 0x3fffffff)
						radius = scaleAtDistance(object.objPos, 1, camera)
						makeCircle(point2D, radius, color, color)
						if object.preMovementObjPos ~= nil then
							point2D = point3Dto2D(object.preMovementObjPos, camera)
							color = 0xff4060a0
							if camera.overlay == true then
								color = (color & 0xffffff) | 0x50000000
							end
							radius = scaleAtDistance(object.objPos, smallsize, camera)
							makeCircle(point2D, radius, color, color & 0x3fffffff)
							radius = scaleAtDistance(object.objPos, 1, camera)
							makeCircle(point2D, radius, color, color)
						end
					else
						makeCircle(point2D, radius, color, color)
					end
				elseif hitboxType == "item" then
					local radius = scaleAtDistance(object.itemPos, object.itemRadius, camera)
					makeCircle(point3Dto2D(object.itemPos, camera), radius, color, color)
				-- elseif hitboxType == "cylindrical" then
					-- Drawn as either a circle (spherical above), or as polygons below
				end
				if not skipPolys and object.polygons ~= nil then
					if type(object.polygons) == "function" then
						object.polygons = object.polygons()
						if #object.polygons == 0 then error("Got no polygons.") end
					end
					local fill = color
					if object.cylinder2 == true or hitboxType == "cylindrical" then
						fill = nil
					end
					if hitboxType == "boxy" or object.typeId == 207 then
						color = 0xffffffff
					end
					-- We separate fill and outline draws because BizHawk's draw system has issues.
					if fill ~= nil then
						for j = 1, #object.polygons do
							makePolygon(object.polygons[j], nil, fill)
						end
					end
					for j = 1, #object.polygons do
						makePolygon(object.polygons[j], color, nil)
					end
				end
			elseif v[1] == LINE then
				local p = line3Dto2D(v[2], v[3], camera)
				if p ~= nil then
					-- Avoid drawing lines over the bottom screen
					local points = fixLine(p[1][1], p[1][2], p[2][1], p[2][2])
					if points ~= nil then
						ops[opid] = {
							LINE,
							points[1] * cw + cx, points[2] * ch + cy,
							points[3] * cw + cx, points[4] * ch + cy,
							v[4],
						}
						opid = opid + 1
					end
				end
			elseif v[1] == HITBOX_PAIR then
				local object = v[2]
				local racer = v[3]
				local oPos = object.objPos
				local rPos = racer.objPos
				if object.hitboxType == "item" then
					oPos = object.itemPos
					rPos = racer.itemPos
				end
				if camera.orthographic == true and object.hitboxType == "spherical" or object.hitboxType == "item" then
					local relative = Vector.subtract(oPos, rPos)
					local vDist = math.abs(Vector.dotProduct_float(relative, camera.rotationVector))
					local oradius = object.objRadius
					local rradius = racer.objRadius
					if object.hitboxType == "item" then
						oradius = object.itemRadius
						rradius =racer.itemRadius
					end
					local totalRadius = oradius + rradius
					if totalRadius > vDist then
						local touchHorizDist = math.sqrt(totalRadius * totalRadius - vDist * vDist)
						makeCircle(point3Dto2D(rPos, camera), scaleAtDistance(rPos, touchHorizDist * rradius / totalRadius, camera), 0xffffffff, nil)
						makeCircle(point3Dto2D(oPos, camera), scaleAtDistance(oPos, touchHorizDist * oradius / totalRadius, camera), 0xffffffff, nil)
					end
				elseif object.hitboxType == "boxy" then
					local racerPolys = Objects.getBoxyPolygons(
						racer.objPos,
						object.orientation,
						{ racer.objRadius, racer.objRadius, racer.objRadius }
					)
					for j = 1, #racerPolys do
						makePolygon(racerPolys[j], 0xffffffff, nil)
					end
			
				end
			elseif v[1] == PIXEL then
				local point = point3Dto2D(v[2], camera)
				if point[2] >= -1 and point[2] < 1 then
					if point[1] >= -1 and point[1] < 1 then
						ops[opid] = { PIXEL, point[1] * cw + cx, point[2] * ch + cy, v[3] }
						opid = opid + 1
					end
				end
			elseif v[1] == TEXT then
				-- Coordinates for TEXT are in pixels.
				if v[2][2] >= 0 and v[2][2] < ch+cy then
					if v[2][1] >= 0 and v[2][1] < cw+cx then
						ops[opid] = { TEXT, v[2][1], v[2][2], v[3] }
						opid = opid + 1
					end
				end
			end
		end
	end

	return ops
end

local function makeRacerHitboxes(allRacers, focusedRacer)
	local count = #allRacers
	local isTT = count <= 2
	-- Not the best TT detection. But, if we are in TT mode we want to only show for-triangle hitboxes!
	-- Outside of TT, non-player hitboxes will be drawn as objects instead.
	if not isTT then count = 0 end

	-- Primary hitbox circle is blue
	local color = 0xff0000ff
	local movementColor = 0xffffffff
	local p = -3
	for i = 0, count do
		local racer = allRacers[i]
		local pos = racer.itemPos
		local radius = racer.itemRadius
		local type = "item"
		if racer == focusedRacer or isTT then
			pos = racer.objPos
			radius = racer.objRadius
			type = "spherical"
		end
		addToDrawingQue(p, { HITBOX, racer, type, color })
		lineFromVector(pos, allRacers[i].movementDirection, radius, movementColor, 5)
		-- Others are a translucent red
		color = 0x48ff5080
		movementColor = 0xcccccccc
		p = -1
	end

	if not isTT and focusedRacer ~= allRacers[0] and focusedRacer ~= nil and focusedRacer.isRacer then
		local racer = focusedRacer
		addToDrawingQue(p, { HITBOX, racer, "spherical", color })
		lineFromVector(racer.objPos, racer.movementDirection, racer.objRadius, movementColor, 5)
	end
end	

local function drawTriangle(tri, d, racer, dotSize, viewport)
	if tri.skip then return end
	if viewport ~= nil and viewport.backfaceCulling == true then
		if viewport.orthographic then
			if Vector.dotProduct_float(tri.surfaceNormal, viewport.rotationVector) > 0 then return end
		else
			if Vector.dotProduct_float(
				tri.surfaceNormal,
				Vector.subtract(tri.vertex[1], viewport.location)
			) > 0 then return end
		end
	end 

	-- fill
	local touchData = d and d.touch
	if touchData == nil then
		touchData = { touching = false }
	end
	if touchData.touching then
		local color = 0x30ff8888
		if touchData.push then
			if d.controlsSlope then
				color = 0x4088ff88
				lineFromVector(racer.objPos, tri.surfaceNormal, racer.objRadius, 0xff00ff00, 5)
			elseif d.isWall then
				color = 0x20ffff22
			elseif touchData.skipByEdge then
				color = 0x30ffcc88
			else
				color = 0x50ffffff
			end
		else
			lineFromVector(racer.objPos, tri.surfaceNormal, racer.objRadius, 0xffff0000, 5)
		end
		addToDrawingQue(-5, { POLYGON, tri.vertex, 0, color })
	end

	-- lines and dots
	local color, priority = "white", 0
	if tri.isWall then
		if touchData.touching and touchData.push and not touchData.skipByEdge then
			color, priority = "yellow", 2
		else
			color, priority = "orange", 1
		end
	elseif tri.isOob then
		color = "red"
	end
	addToDrawingQue(priority, { POLYGON, tri.vertex, color, nil })
	if dotSize ~= nil then
		if dotSize == 1 then
			addToDrawingQue(9, { PIXEL, tri.vertex[1], 0xffff0000 })
			addToDrawingQue(9, { PIXEL, tri.vertex[2], 0xffff0000 })
			addToDrawingQue(9, { PIXEL, tri.vertex[3], 0xffff0000 })
		else
			addToDrawingQue(9, { CIRCLE, tri.vertex[1], dotSize, 0xffff0000, 0xffff0000 })
			addToDrawingQue(9, { CIRCLE, tri.vertex[2], dotSize, 0xffff0000, 0xffff0000 })
			addToDrawingQue(9, { CIRCLE, tri.vertex[3], dotSize, 0xffff0000, 0xffff0000 })
		end
	end

	-- surface normal vector, kinda bad visually
	--if and tri.surfaceNormal[2] ~= 0 and tri.surfaceNormal[2] ~= 4096 then
		--local center = Vector.add(Vector.add(tri.vertex[1], tri.vertex[2]), tri.vertex[3])
		--center = Vector.multiply(center, 1 / 3)
		--lineFromVector(center, tri.surfaceNormal, racer.objRadius, color, 4)
	--end
end
local function makeKclQue(viewport, focusObject, allTriangles, textonly)
	if allTriangles ~= nil and textonly ~= true then
		for i = 1, #allTriangles do
			drawTriangle(allTriangles[i], nil, focusObject, nil, viewport)
		end
	end

	local touchData = KCL.getCollisionDataForRacer({
		pos = focusObject.objPos,
		previousPos = focusObject.preMovementObjPos,
		radius = focusObject.objRadius,
		flags = 1, -- TODO: assume for now it is a racer
	})

	if textonly ~= true then
		local dotSize = 1
		if viewport.w > 128 then dotSize = 1.5 end
		for i = 1, #touchData.all do
			local d = touchData.all[i]
			if d.touch.canTouch then
				drawTriangle(d.triangle, d, focusObject, dotSize, viewport)
			end
		end
	end

	local y = 19
	if touchData.nearestWall ~= nil then
		local t = touchData.all[touchData.nearestWall].touch
		if t.isInside then
			addToDrawingQue(99, { TEXT, { 2, y }, string.format("closest wall: %i", t.distance) })
		else
			addToDrawingQue(99, { TEXT, { 2, y }, string.format("closest wall: %.2f", t.distance) })
		end
		y = y + 18
	end
	if touchData.nearestFloor ~= nil then
		local t = touchData.all[touchData.nearestFloor].touch
		if t.isInside then
			addToDrawingQue(99, { TEXT, { 2, y }, string.format("closest floor: %i", t.distance) })
		else
			addToDrawingQue(99, { TEXT, { 2, y }, string.format("closest floor: %.2f", t.distance) })
		end
		y = y + 18
	end
	
	y = y + 3
	for i = 1, #touchData.touched do
		local d = touchData.touched[i]
		local tri = d.triangle
		local stype = ""
		if tri.isWall then stype = stype .. "w" end
		if tri.isFloor then stype = stype .. "f" end
		if stype == "" then stype = tri.collisionType end
		local ps = ""
		if d.touch.push == false then
			if d.touch.wasBehind then
				ps = "n (behind)"
			else
				ps = string.format("n %.2f", d.touch.outwardMovement)
			end
		else
			local p = "p"
			if d.touch.skipByEdge then
				p = "edge"
			end
			if d.touch.isInside then
				ps = string.format("%s %i", p, d.touch.pushOutDistance)
			else
				ps = string.format("%s %.2f", p, d.touch.pushOutDistance)
			end
		end
		local str = string.format("%i: %s, %s", tri.id, stype, ps)
		addToDrawingQue(99, { TEXT, { 2, y }, str })
		
		y = y + 18
	end
end

local function _drawObjectCollision(racer, obj)
	if obj.skip == true then return end

	local objColor = 0xff40c0e0
	if obj.typeId == 106 then objColor = 0xffffff11 end
	addToDrawingQue(-4, { HITBOX, obj, obj.hitboxType, objColor })
	if obj.hitboxType == "spherical" or obj.hitboxType == "item" then
		-- White circles to indicate size of hitbox cross-section at the current elevation.
		if racer ~= nil then
			addToDrawingQue(-1, { HITBOX_PAIR, obj, racer })
		end
	elseif obj.hitboxType == "boxy" and racer ~= nil then
		addToDrawingQue(-2, { HITBOX_PAIR, obj, racer })
	end
end
local function makeObjectsQue(focusObject)
	if focusObject == nil then error("Attempted to draw objects with no focus.") end
	local nearby = Objects.getNearbyObjects(focusObject, mkdsiConfig.objectRenderDistance)
	local objects = nearby[1]
	local nearest = nearby[2]
	for i = 1, #objects do
		if objects[i] == nearest then
			_drawObjectCollision(focusObject, objects[i])
		else
			_drawObjectCollision(nil, objects[i])
		end
	end
	-- A focused racer will have a KCL hitbox drawn. Other things won't.
	if not focusObject.isRacer then
		_drawObjectCollision(nil, focusObject)
	end
end

local function makeCheckpointsQue(checkpoints, racer, package)
	local pos = racer and racer.basePos
	if pos == nil then pos = { 0, 0x100000, 0 } end
	local function elevate(p)
		return { p[1], pos[2], p[2] }
	end
	local function checkpointLine(c)
		local color = 0xff11ff11
		if c.isKey then color = 0xff1199ff end
		if c.isFinish then color = 0xffff2222 end
		addToDrawingQue(1, { LINE, elevate(c.point1), elevate(c.point2), color })
	end
	local function checkpointConnections(c1, c2)
		addToDrawingQue(1, { LINE, elevate(c1.point1), elevate(c2.point1), 0xff808080 })
		addToDrawingQue(1, { LINE, elevate(c1.point2), elevate(c2.point2), 0xff808080 })
	end


	for i = 0, checkpoints.count - 1 do
		checkpointLine(checkpoints[i])
		for j = 1, #checkpoints[i].nextChecks do
			checkpointConnections(checkpoints[checkpoints[i].nextChecks[j]], checkpoints[i])
		end
	end

	-- the racer position
	addToDrawingQue(1, { CIRCLE, pos, 10, 0xffffffff, nil })
	-- can we do crosshairs?
end

local function makePathsQue(paths, endFrame)
	for j = 1, #paths do
		local path = paths[j].path
		local color = paths[j].color
		local last = nil
		for i = endFrame - 750, endFrame do
			if path[i] ~= nil and last ~= nil then
				addToDrawingQue(3, { LINE, last, path[i], color })
			end
			last = path[i]
		end
	end
end

local function processPackage(camera, package)
	que = {}
	local thing
	if camera.racerId ~= -1 then
		thing = package.allRacers[camera.racerId]
	else
		thing = camera.obj
	end
	if thing ~= nil then
		Objects.getObjectDetails(thing)
	end
	if camera.active then
		if camera.drawKcl == true then
			if camera.racerId == nil then error("no racer id") end
			makeKclQue(camera, thing, (camera.renderAllTriangles and package.allTriangles) or nil)
		end
		if camera.drawObjects == true then
			makeObjectsQue(thing)
		end
		if camera.drawKcl == true or camera.drawObjects == true then
			makeRacerHitboxes(package.allRacers, thing)
		end
		if camera.drawCheckpoints == true then
			makeCheckpointsQue(package.checkpoints, thing, package)
		end
		if camera.drawPaths == true then
			makePathsQue(package.paths, package.frame)
		end
	elseif camera.isPrimary then
		-- We always show the text for nearest+touched triangles.
		makeKclQue(camera, thing, (camera.renderAllTriangles and package.allTriangles) or nil, true)
		if camera.drawRacers == true then
			makeRacerHitboxes(package.allRacers, thing)
		end
	end

	-- Hacky: Player hitbox is transparent on the main screen when in 3D view (.overlay == true)
	-- But if we are using renderHitboxesWhenFakeGhost, .overlay may be false.
	if camera.drawRacers == true then -- .drawRacers means renderHitboxesWhenFakeGhost is on and fake ghost exists.
		local temp = camera.overlay
		camera.overlay = true
		local que = processQue(camera)
		camera.overlay = temp
		return que
	else
		return processQue(camera)
	end
end
local function drawClient(camera, package)
	local operations = processPackage(camera, package)

	if (camera.overlay == false and camera.active == true) or (camera.isPrimary ~= true) then
		gui.drawRectangle(camera.x - camera.w, camera.y - camera.h, camera.w * 2, camera.h * 2, "black", "black")
	end
	for i = 1, #operations do
		local op = operations[i]
		if op[1] == POLYGON then
			gui.drawPolygon(op[2], 0, 0, op[3], op[4])
		elseif op[1] == CIRCLE then
			gui.drawEllipse(op[2], op[3], op[4], op[4], op[5], op[6])
		elseif op[1] == LINE then
			gui.drawLine(op[2], op[3], op[4], op[5], op[6])
		elseif op[1] == PIXEL then
			gui.drawPixel(op[2], op[3], op[4])
		elseif op[1] == TEXT then
			camera.drawText(op[2], op[3], op[4])
		end
	end
end
local function drawForms(camera, package)
	local operations = processPackage(camera, package)

	local b = camera.box
	if camera.overlay == false then
		forms.clear(b, 0xff000000)
	end
	for i = 1, #operations do
		local op = operations[i]
		if op[1] == POLYGON then
			forms.drawPolygon(b, op[2], 0, 0, op[3], op[4])
		elseif op[1] == CIRCLE then
			forms.drawEllipse(b, op[2], op[3], op[4], op[4], op[5], op[6])
		elseif op[1] == LINE then
			forms.drawLine(b, op[2], op[3], op[4], op[5], op[6])
		elseif op[1] == PIXEL then
			forms.drawPixel(b, op[2], op[3], op[4])
		elseif op[1] == TEXT then
			camera.drawText(op[2], op[3], op[4], 0xffffffff)
		end
	end
	forms.refresh(b)
end

local function setPerspective(camera, surfaceNormal)
	-- We will look in the direction opposite the surface normal.
	local p = Vector.multiply(surfaceNormal, -1)
	camera.rotationVector = p
	-- The Z co-ordinate is simply the distance in that direction.
	local mZ = { p[1], p[2], p[3] }
	-- The X co-ordinate should be independent of Y. So this vector is orthogonal to 0,1,0 and mZ.
	local mX = nil
	if surfaceNormal[1] ~= 0 or surfaceNormal[3] ~= 0 then
		mX = Vector.crossProduct_float(mZ, { 0, 0x1000, 0 })
		-- Might not be normalized. Normalize it.
		
		mX = Vector.multiply(mX, 1 / Vector.getMagnitude(mX))
	else
		mX = { 0x1000, 0, 0 }
	end
	mX = { mX[1], mX[2], mX[3] }
	local mY = Vector.crossProduct_float(mX, mZ)
	mY = { mY[1], mY[2], mY[3] }
	camera.rotationMatrix = { mX, mY, mZ }
end

_export = {
	drawClient = drawClient,
	drawForms = drawForms,
	setPerspective = setPerspective,
	getDirectionsFrom2d = getDirectionsFrom2d,
}
end
_()
local Graphics = _export

local function _()
local Memory = _imports.Memory

local checkpointSize = 0x24;

local function getCheckpoints()
	local ptrCheckData = memory.read_s32_le(Memory.addrs.ptrCheckData)
	local totalcheckpoints = memory.read_u16_le(ptrCheckData + 0x48)
	if totalcheckpoints == 0 then return { count = 0 } end
	local chkAddr = memory.read_u32_le(ptrCheckData + 0x44)

	local checkpointData = memory.read_bytes_as_array(chkAddr + 1, totalcheckpoints * checkpointSize)
	checkpointData[0] = memory.read_u8(chkAddr)

	local checkpoints = {}
	local testing = {}
	for i = 0, totalcheckpoints - 1 do
		-- CheckPoint X, Y for both end
		checkpoints[i] = {
			point1 = {
				Memory.get_s32(checkpointData, i * checkpointSize + 0x0),
				Memory.get_s32(checkpointData, i * checkpointSize + 0x4),
			},
			point2 = {
				Memory.get_s32(checkpointData, i * checkpointSize + 0x8),
				Memory.get_s32(checkpointData, i * checkpointSize + 0xC),
			},
			isFinish = false,
			isKey = Memory.get_s16(checkpointData, i * checkpointSize + 0x20) >= 0,
			nextChecks = { i + 1 },
		}
	end
	checkpoints[0].isFinish = true
	checkpoints.count = totalcheckpoints

	local pathsAddr = memory.read_u32_le(ptrCheckData + 0x4c)
	local pathsCount = memory.read_u32_le(ptrCheckData + 0x50)
	local pathSize = 0xC
	local pathsData = memory.read_bytes_as_array(pathsAddr + 1, pathsCount * pathSize - 1)
	pathsData[0] = memory.read_u8(pathsAddr)
	local paths = {}
	for i = 0, pathsCount - 1 do
		local p = i*pathSize
		paths[i] = {
			beginCheckId = Memory.get_u16(pathsData, p + 0),
			length = Memory.get_u16(pathsData, p + 2),
			nextPaths = { pathsData[p + 4], pathsData[p + 5], pathsData[p + 6] },
		}
	end
	for i = 0, pathsCount - 1 do
		local nextCpIds = {}
		for j = 1, #paths[i].nextPaths do
			local pid = paths[i].nextPaths[j]
			if pid ~= 0xff then
				nextCpIds[j] = paths[pid].beginCheckId
			end
		end
		checkpoints[paths[i].beginCheckId + paths[i].length - 1].nextChecks = nextCpIds
	end

	return checkpoints
end

_export = {
	getCheckpoints = getCheckpoints,
}
end
_()
local Checkpoints = _export

-- BizHawk shenanigans
if script_id == nil then
	script_id = 1
else
	script_id = script_id + 1
end
local frame = emu.framecount()
local lastFrame = 0
local my_script_id = script_id
local shouldExit = false
local redrawSeek = nil

-- Some stuff
local focusedRacer = nil

local fakeGhostData = {}
local fakeGhostExists = false

local recordedPaths = {}

local form = {}
local watchingId = 0
local drawWhileUnpaused = true

-- General stuffs -------------------------------
local satr = 2 * math.pi / 0x10000

local function contains(list, x)
	for _, v in ipairs(list) do
		if v == x then return true end
	end
	return false
end
local function deepMatch(t1, t2, maxDepth)
	if type(t1) ~= "table" or type(t2) ~= "table" then return t1 == t2 end
	if maxDepth == 0 then return true end
	local pairsChecked = {}
	for k, v in pairs(t1) do
		if not deepMatch(t2[k], v, maxDepth - 1) then return false end
		pairsChecked[k] = true
	end
	for k, _ in pairs(t2) do
		if pairsChecked[k] == nil then return false end
	end
	return true
end
local function copyTableShallow(table)
	local new = {}
	for k, v in pairs(table) do
		new[k] = v
	end
	return new
end
local function removeItem(_table, item)
	for i, v in ipairs(_table) do
		if v == item then
			table.remove(_table, i)
			return true
		end
	end
	return false
end

local function normalizeQuaternion_float(v)
	local m = math.sqrt(v.i * v.i + v.j * v.j + v.k * v.k + v.r * v.r) / 0x1000
	return {
		i = v.i / m,
		j = v.j / m,
		k = v.k / m,
		r = v.r / m,
	}
end
local function quaternionAngle(q)
	q = normalizeQuaternion_float(q)
	return math.floor(math.acos(q.r / 4096) * 0x10000 / math.pi)
end

-- String formattings. https://cplusplus.com/reference/cstdio/printf/
local sem = config.showExactMovement
local smf = not sem
local function format01(value)
	-- Format a value expected to be between 0 and 1 (4096) based on script settings.
	if smf then
		return string.format("%6.3f", value)
	else
		return value
	end
end
local function posVecToStr(vector, prefix)
	return string.format("%s%9i, %9i, %8i", prefix, vector[1], vector[3], vector[2])
end
local function normalVectorToStr(vector, prefix)
	if sem then
		return string.format("%s%5i, %5i, %5i", prefix, vector[1], vector[3], vector[2])
	else
		return string.format("%s%6.3f, %6.3f, %6.3f", prefix, vector[1] / 0x1000, vector[3] / 0x1000, vector[2] / 0x1000)
	end
end
local function rawQuaternion(q, prefix)
	return string.format("%s%4i %4i %4i %4i", prefix, q.k, q.j, q.i, q.r)
end
-------------------------------------------------

-- MKDS -----------------------------------------
local allRacers = {}
local racerCount = 0

local raceData = {}
local course = {}

local triangles = nil

local allObjects = nil

local checkpoints = {}

local ptrRacerData = nil
local ptrCheckNum = nil
local ptrRaceTimers = nil
local ptrMissionInfo = nil

local gameCameraHisotry = {{},{},{}}
local drawingPackages = {}

local function gerRacerRawData(ptr)
	if ptr == 0 then
		return nil
	else
		return memory.read_bytes_as_array(ptr + 1, 0x5a8 - 1)
	end
end
local function getRacerBasicData(ptr)
	if ptr == 0 then
		error("Attempted to get racer details for null racer.")
	end

	local newData = { isRacer = true }
	newData.ptr = ptr
	newData.basePos = read_pos(ptr + 0x80)
	newData.objPos = read_pos(ptr + 0x1b8)
	newData.preMovementObjPos = read_pos(ptr + 0x1C4)
	newData.itemPos = read_pos(ptr + 0x1d8)
	newData.objRadius = memory.read_s32_le(ptr + 0x1d0)
	newData.itemRadius = newData.objRadius
	newData.movementDirection = read_pos(ptr + 0x68)

	return newData
end
local function getRacerBasicData2(raw)
	local newData = { isRacer = true }
	newData.basePos = get_pos(raw, 0x80)
	newData.objPos = get_pos(raw, 0x1b8)
	newData.preMovementObjPos = get_pos(raw, 0x1C4)
	newData.itemPos = get_pos(raw, 0x1d8)
	newData.objRadius = get_s32(raw, 0x1d0)
	newData.itemRadius = newData.objRadius
	newData.movementDirection = get_pos(raw, 0x68)

	return newData
end
local function getRacerDetails(allData, previousData, isSameFrame)
	if allData == nil then
		error("Attempted to get racer details for null racer.")
	end

	local newData = {}
	newData.isRacer = true
	-- Read positions and speed
	newData.basePos = get_pos(allData, 0x80)
	newData.objPos = get_pos(allData, 0x1B8) -- also used for collision
	newData.preMovementObjPos = get_pos(allData, 0x1C4) -- this too is used for collision
	newData.itemPos = get_pos(allData, 0x1D8) -- also for racer-racer collision
	newData.speed = get_s32(allData, 0x2A8)
	newData.basePosDelta = get_pos(allData, 0xA4)
	newData.boostAll = allData[0x238]
	newData.boostMt = allData[0x23C]
	newData.verticalVelocity = get_s32(allData, 0x260)
	newData.mtTime = get_s32(allData, 0x30C)
	newData.maxSpeed = get_s32(allData, 0xD0)
	newData.turnLoss = get_s32(allData, 0x2D4)
	newData.offroadSpeed = get_s32(allData, 0xDC)
	newData.wallSpeedMult = get_s32(allData, 0x38C)
	newData.airSpeed = get_s32(allData, 0x3F8)
	newData.effectSpeed = get_s32(allData, 0x394)
	
	-- angles
	newData.facingAngle = get_s16(allData, 0x236)
	newData.pitch = get_s16(allData, 0x234)
	newData.driftAngle = get_s16(allData, 0x388)
	--newData.wideDrift = get_s16(allData, 0x38A) -- Controls tightness of drift when pressing outside direction, and rate of drift air spin.
	newData.movementDirection = get_pos(allData, 0x68)
	newData.movementTarget = get_pos(allData, 0x50)
	--newData.targetMovementVectorSigned = get_pos(allData, 0x5c)
	newData.snQuaternion = get_quaternion(allData, 0xf0)
	newData.snqTarget = get_quaternion(allData, 0x100)
	--newData.faQuaternion = get_quaternion(allData, 0xe0)
	--newData.facingQuatenion = get_quaternion(allData, 0x110)

	-- Real speed
	if isSameFrame then
		newData.real2dSpeed = previousData.real2dSpeed
		newData.actualPosDelta = previousData.actualPosDelta
		newData.facingDelta = previousData.facingDelta
		newData.driftDelta = previousData.driftDelta
	else
		newData.real2dSpeed = math.sqrt((previousData.basePos[3] - newData.basePos[3]) ^ 2 + (previousData.basePos[1] - newData.basePos[1]) ^ 2)
		newData.actualPosDelta = Vector.subtract(newData.basePos, previousData.basePos)
		newData.facingDelta = newData.facingAngle - previousData.facingAngle
		newData.driftDelta = newData.driftAngle - previousData.driftAngle
	end
	newData.collisionPush = Vector.subtract(newData.actualPosDelta, newData.basePosDelta)

	-- surface/collision stuffs
	newData.surfaceNormalVector = get_pos(allData, 0x244)
	newData.grip = get_s32(allData, 0x240)
	newData.objRadius = get_s32(allData, 0x1d0)
	--newData.radiusMult = get_s32(allData, 0x4c8)
	newData.statsPtr = get_u32(allData, 0x2cc)
	newData.itemRadius = newData.objRadius

	-- status things
	newData.framesInAir = get_s32(allData, 0x380)
	if allData[0x3DD] == 0 then
		newData.air = "Ground"
	else
		newData.air = "Air"
	end
	newData.spawnPoint = get_s32(allData, 0x3C4)
	newData.flags44 = get_u32(allData, 0x44)
	
	-- extra movement
	newData.movementAdd1fc = get_pos(allData, 0x1fc)
	newData.movementAdd2f0 = get_pos(allData, 0x2f0)
	newData.movementAdd374 = get_pos(allData, 0x374)
	--newData.tb = get_pos(allData, 0x2d8)
	newData.waterfallPush = get_pos(allData, 0x268)
	newData.waterfallStrength = get_s32(allData, 0x274)

	-- Rank/score
	--local ptrScoreCounters = memory.read_s32_le(Memory.addrs.ptrScoreCounters)
	--newData.wallHitCount = memory.read_s32_le(ptrScoreCounters + 0x10)
	
	-- ?	
	--newData.smsm = get_s32(allData, 0x39c)
	newData.maxSpeedFraction = get_s32(allData, 0x2a0)
	newData.snqcr = get_s32(allData, 0x3a8)
	--newData.ffms = get_s32(allData, 0xd4)
	--newData.slipstream = get_s32(allData, 0xd8)
	--newData.test = get_s32(allData, 0x1d4)
	--newData.scale = get_s32(allData, 0xc4)
	--newData.f230 = get_u32(allData, 0x230)

	-- Item
	local itemDataPtr = memory.read_s32_le(Memory.addrs.ptrItemInfo + 0x210 * allData[0x74])
	if itemDataPtr ~= 0 then
		newData.roulleteItem = memory.read_u8(itemDataPtr + 0x10)
		newData.itemId = memory.read_u8(itemDataPtr + 0x30)
		newData.itemCount = memory.read_u8(itemDataPtr + 0x38)
		newData.draggingType = memory.read_u8(itemDataPtr + 0x58)
		newData.draggingId = memory.read_u8(itemDataPtr + 0x5c)
		newData.roulleteTimer = memory.read_u8(itemDataPtr + 0x04)
		newData.roulleteState = memory.read_u8(itemDataPtr + 0)
	end
	
	return newData
end
local function BlankRacerData()
	local n = {}
	n.basePos = Vector.zero()
	n.facingAngle = 0
	n.driftAngle = 0
	local z = {}
	for i = 1, 0x5a8 do z[i] = 0 end
	return getRacerDetails(z, n, false)
end
focusedRacer = BlankRacerData()

local function getCheckpointData(dataObj)
	if ptrCheckNum == 0 then
		return
	end
	
	-- Read checkpoint values
	dataObj.checkpoint = memory.read_u8(ptrCheckNum + 0x46)
	dataObj.keyCheckpoint = memory.read_s8(ptrCheckNum + 0x48)
	dataObj.checkpointGhost = memory.read_s8(ptrCheckNum + 0xD2)
	dataObj.keyCheckpointGhost = memory.read_s8(ptrCheckNum + 0xD4)
	dataObj.lap = memory.read_s8(ptrCheckNum + 0x38)
	
	-- Lap time
	dataObj.lap_f = memory.read_s32_le(ptrCheckNum + 0x18) * 1.0 / 60 - 0.05
	if (dataObj.lap_f < 0) then dataObj.lap_f = 0 end
end

local function setGhostInputs(form)
	local ptr = memory.read_s32_le(Memory.addrs.ptrGhostInputs)
	if ptr == 0 then error("How are you here?") end
	
	local currentInputs = memory.read_bytes_as_array(ptr, 0xdce)
	memory.write_bytes_as_array(ptr, form.ghostInputs)
	memory.write_s32_le(ptr, 1765) -- max input count for ghost
	-- lap times
	ptr = memory.read_s32_le(Memory.addrs.ptrSomeRaceData)
	memory.write_bytes_as_array(ptr + 0x3ec, form.ghostLapTimes)
	
	-- This frame's state won't have it, but any future state will.
	form.firstStateWithGhost = frame + 1
	
	-- Find the first frame where inputs differ.
	local frames = 0
	-- 5, not 4: Lua table is 1-based
	for i = 5, #currentInputs, 2 do
		if form.ghostInputs[i] ~= currentInputs[i] then
			break
		elseif form.ghostInputs[i + 1] ~= currentInputs[i + 1] then
			frames = frames + math.min(form.ghostInputs[i + 1], currentInputs[i + 1])
			break
		else
			frames = frames + currentInputs[i + 1]
			if currentInputs[i + 1] == 0 then
				return -- All ghost inputs match!
			end
		end
	end
	-- Rewind, clear state history
	local targetFrame = frames + form.firstGhostInputFrame
	-- I'm not sure why, but ghosts have been desyncing. So let's just go back a little more.
	targetFrame = targetFrame - 1
	if frame > targetFrame then
		local inputs = movie.getinput(targetFrame)
		local isOn = inputs["A"]
		tastudio.submitinputchange(targetFrame, "A", not isOn)
		tastudio.applyinputchanges()
		tastudio.submitinputchange(targetFrame, "A", isOn)
		tastudio.applyinputchanges()
	end
end
local function ensureGhostInputs(form)
	-- This function's job is to re-apply the hacked ghost data when the user re-winds far enough back that the hacked ghost isn't in the savestate.

	-- Ensure we're still in the same race
	local firstInputFrame = frame - memory.read_s32_le(memory.read_s32_le(Memory.addrs.ptrRaceTimers) + 4) + 121
	if firstInputFrame ~= form.firstGhostInputFrame then
		return
	end

	-- We don't want to be constantly re-applying every frame advance.
	if frame < lastFrame or form.firstStateWithGhost > frame then
		-- At this point, we should be in a state where the ghost inputs
		-- are only different from what they should be AFTER the current
		-- frame. Because the initial setting of inputs (at user click or
		-- at branch load) will have invalidated all states where the
		-- inputs don't match up to the frame of the state.
		-- However, BizHawk has a bug: It will sometimes return from
		-- emu.frameadvance() BEFORE triggering the branch load handler.
		-- In that case, we'd update ghost inputs here first and then the
		-- branch load handler would have no way of knowing where to
		-- rewind to/invalidate states. The easiest fix for this is to just
		-- always check for incorrect ghost inputs.
		setGhostInputs(form)
	end
end

local function getCourseData()
	-- Read pointer values
	ptrRacerData = memory.read_s32_le(Memory.addrs.ptrRacerData)
	ptrCheckNum = memory.read_s32_le(Memory.addrs.ptrCheckNum)
	ptrRaceTimers = memory.read_s32_le(Memory.addrs.ptrRaceTimers)
	ptrMissionInfo = memory.read_s32_le(Memory.addrs.ptrMissionInfo)

	triangles = KCL.getCourseCollisionData().triangles
	Objects.loadCourseData()
	checkpoints = Checkpoints.getCheckpoints()

	allRacers = {}
end

local function clearDataOutsideRace()
	raceData = {
		coinsBeingCollected = 0,
	}
	allRacers = {}
	form.ghostInputs = nil
	forms.settext(form.ghostInputHackButton, "Copy from player")
	course = {}
end

local function inRace()
	-- Check if racer exists.
	local currentRacersPtr = memory.read_s32_le(Memory.addrs.ptrRacerData)
	if currentRacersPtr == 0 then
		clearDataOutsideRace()
		return false
	end
	
	-- Check if race has begun. (This static pointer points to junk on the main menu, which is why we checked racer data first.)
	local timer = memory.read_s32_le(memory.read_s32_le(Memory.addrs.ptrRaceTimers) + 8)
	if timer == 0 then
		clearDataOutsideRace()
		return false
	end
	local currentCourseId = memory.read_u8(Memory.addrs.ptrCurrentCourse)
	if currentCourseId ~= course.id or currentRacersPtr ~= course.racersPtr or math.abs(frame - timer - course.frame) > 1 then
		-- The timer update is on the boundary of frames (so we check +/- > 1)
		course.id = currentCourseId
		course.racersPtr = currentRacersPtr
		course.frame = frame - timer
		getCourseData()

		racerCount = memory.read_s32_le(Memory.addrs.racerCount)
		recordedPaths = {}
		for i = 1, racerCount + 1 do -- Yes, +1 of racerCount. For fake ghost.
			recordedPaths[i] = { path = {}, color = 0xffff0000 }
		end
		recordedPaths[1].color = 0xff0088ff
	end
	
	return true
end

local function getInGameCameraData()
	local cameraPtr = memory.read_u32_le(Memory.addrs.ptrCamera)
	local camPos = read_pos(cameraPtr + 0x24)
	-- CCB water!
	local elevation = memory.read_s32_le(cameraPtr + 0x178)
	camPos[2] = camPos[2] + elevation

	local camTargetPos = read_pos(cameraPtr + 0x18)
	local direction = Vector.subtract(camPos, camTargetPos)
	direction = Vector.normalize_float(direction)
	local cameraFoVV = memory.read_u16_le(cameraPtr + 0x60) * satr
	local camAspectRatio = memory.read_s32_le(cameraPtr + 0x6C) / 0x1000
	return {
		location = camPos,
		direction = direction,
		fovW = math.tan(cameraFoVV * camAspectRatio) * 0xec0, -- Idk why not 0x1000, but this gives better results. /shrug
		fovH = math.tan(cameraFoVV) * 0x1000,
	}
end
local function getFakeCameraData(target, camera)
	local focusPoint = target.basePos or target.objPos
	local direction = target.movementDirection or target.velocity
	if direction == nil or Vector.equals(direction, {0,0,0}) then
		direction = { 0x1000, 0, 0 }
	end
	direction = Vector.normalize_float(direction)
	if direction[2] > -0x380 then
		direction[2] = -0x380
		direction = Vector.normalize_float(direction)
	end
	local moveTo = Vector.add(focusPoint, Vector.multiply(direction, -70))
	local newLocation = Vector.interpolate(camera.location, moveTo, 1) -- interp values < 1 are behaving very strange Idk, maybe my brain isn't working rn.
	direction = Vector.subtract(newLocation, focusPoint)
	direction = Vector.normalize_float(direction)
	return {
		location = newLocation,
		direction = direction,
		fovW = 3200,
		fovH = 2385,
	}
end

-- Main info function
local function _mkdsinfo_run_data(isSameFrame)
	racerCount = memory.read_s32_le(Memory.addrs.racerCount)
	local raceFrame = memory.read_s32_le(ptrRaceTimers + 4)
	local watchingFakeGhost = watchingId == racerCount
	if watchingFakeGhost then
		if fakeGhostData[raceFrame] == nil then
			focusedRacer = BlankRacerData()
		else
			focusedRacer = getRacerDetails(fakeGhostData[raceFrame], focusedRacer, isSameFrame)
			focusedRacer.rawData = fakeGhostData[raceFrame]
		end
	else
		local raw = gerRacerRawData(ptrRacerData + watchingId * 0x5a8)
		focusedRacer = getRacerDetails(raw, focusedRacer, isSameFrame)
		focusedRacer.ptr = ptrRacerData + watchingId * 0x5a8
		focusedRacer.rawData = raw
	end

	local newRacers = {} -- needs new object so drawPackages can have multiple frames
	for i = 0, racerCount - 1 do
		if i ~= watchingId then
			newRacers[i] = getRacerBasicData(ptrRacerData + i * 0x5a8)
		else
			newRacers[i] = focusedRacer
		end
		recordedPaths[i + 1].path[raceFrame] = newRacers[i].objPos
	end
	
	if watchingId == 0 then
		getCheckpointData(focusedRacer) -- This function only supports player.

		local ghostExists = racerCount >= 2 and Objects.isGhost(ptrRacerData + 0x5a8)
		if ghostExists then
			focusedRacer.ghost = newRacers[1]
		end
	end

	allObjects = Objects.readObjects()
	focusedRacer.nearestObject = Objects.getNearbyObjects(focusedRacer, config.objectRenderDistance)[2]

	-- Ghost handling
	if form.ghostInputs ~= nil then
		ensureGhostInputs(form)
	end
	if config.giveGhostShrooms then
		local itemPtr = memory.read_s32_le(Memory.addrs.ptrItemInfo)
		itemPtr = itemPtr + 0x210 -- ghost
		memory.write_u8(itemPtr + 0x30, 5) -- mushroom
		memory.write_u8(itemPtr + 0x38, 3) -- count
	end
	
	if config.enableCameraFocusHack then
		local raceThing = memory.read_u32_le(Memory.addrs.ptrSomeRaceData)
		memory.write_u8(raceThing + 0x62, watchingId)
		memory.write_u8(raceThing + 0x63, watchingId)
		local somethingPtr = memory.read_u32_le(Memory.addrs.ptrCheckNum)
		memory.write_u32_le(somethingPtr + 0x4f0, 0)
		-- Visibility
		local racer = ptrRacerData + 0x5a8 * watchingId
		local ptr = memory.read_u32_le(racer + 0x590)
		memory.write_u8(ptr + 0x58, 0)
		memory.write_u8(ptr + 0x5c, 0)
		local shadowPtr = memory.read_u32_le(ptr + 0x1C)
		memory.write_u8(shadowPtr + 0x70, 1)
		local flags4e = memory.read_u8(racer + 0x4e)
		memory.write_u8(racer + 0x4e, flags4e & 0x7f)
		-- Wheels: Only way I know how is code hack.
		local value = 0
		if watchingId == 0 then value = 1 end
		memory.write_u8(Memory.addrs.cameraThing, value)
	end

	-- FAKE ghost
	if fakeGhostData[raceFrame] ~= nil then
		newRacers[racerCount] = getRacerBasicData2(fakeGhostData[raceFrame])
		recordedPaths[racerCount + 1].path[raceFrame] = newRacers[racerCount].objPos
	end
	fakeGhostExists = false
	if not watchingFakeGhost then
		if form.recordingFakeGhost then
			fakeGhostData[raceFrame] = focusedRacer.rawData
		end
		if newRacers[racerCount] ~= nil then
			focusedRacer.ghost = newRacers[racerCount]
			fakeGhostExists = true
		end
	else
		fakeGhostExists = true
	end
	allRacers = newRacers

	-- Data not tied to a racer
	raceData.framesMod8 = memory.read_s32_le(ptrRaceTimers + 0xC)
	raceData.coinsBeingCollected = memory.read_s16_le(ptrMissionInfo + 0x8)
	lastFrame = frame

	local drawingPackage = {
		allRacers = allRacers,
		allTriangles = triangles,
		checkpoints = checkpoints,
		paths = recordedPaths,
		frame = raceFrame,
	}
	if not isSameFrame then
		drawingPackages[3] = drawingPackages[2]
		drawingPackages[2] = drawingPackages[1]
		drawingPackages[1] = drawingPackage
		gameCameraHisotry[1] = gameCameraHisotry[2]
		gameCameraHisotry[2] = gameCameraHisotry[3]
		gameCameraHisotry[3] = getInGameCameraData()
	else
		drawingPackages[1] = drawingPackage
	end
end
---------------------------------------

-- Drawing --------------------------------------
local iView = {}

local function drawText(x, y, str, color)
	gui.text(x + iView.x, y + iView.y, str, color)
end

local function drawInfoBottomScreen(data)
	gui.use_surface("client")
	if data == nil then
		drawText(5, 5, "No data.")
		return
	end
	
	local lineHeight = 15 -- there's no font size option!?
	local sectionMargin = 8
	local y = 4
	local x = 4
	local b = true
	local function dt(s)
		if s == nil then
			print("drawing nil at y " .. y)
		end
		gui.text(x + iView.x, y + iView.y, s)
		y = y + lineHeight
		b = false
	end
	local sectionIsDark = false
	local lastSectionBegin = 0
	local function endSection()
		if b then return end
		b = true
		y = y + sectionMargin / 2 + 1
		if sectionIsDark then
			gui.drawBox(iView.x, lastSectionBegin + iView.y, iView.x + iView.w, y + iView.y, 0xff000000, 0xff000000)
		else
			gui.drawBox(iView.x, lastSectionBegin + iView.y, iView.x + iView.w, y + iView.y, 0x60000000, 0x60000000)
		end
		gui.drawLine(iView.x, y + iView.y, iView.x + iView.w, y + iView.y, "red")
		sectionIsDark = not sectionIsDark
		lastSectionBegin = y + 1
		y = y + sectionMargin / 2 - 1
	end

	local f = string.format
	
	-- Display speed, boost stuff
	dt(f("Boost: %2i, MT: %2i, %i", data.boostAll, data.boostMt, data.mtTime))
	dt(f("Speed: %i, real: %.1f", data.speed, data.real2dSpeed))
	dt(f("Y Sp : %i, Max Sp: %i", data.verticalVelocity, data.maxSpeed))
	local wallClip = data.wallSpeedMult
	local losses = "turnLoss: " .. format01(data.turnLoss)
	if wallClip ~= 4096 or data.flags44 & 0xc0 ~= 0 then
		losses = losses .. ", wall: " .. format01(data.wallSpeedMult)
	end
	if data.airSpeed ~= 4096 then
		losses = losses .. ", air: " .. format01(data.airSpeed)
	end
	if data.effectSpeed ~= 4096 then
		losses = losses .. ", small: " .. format01(data.effectSpeed)
	end
	dt(losses)
	endSection()

	-- Display position
	dt(data.air .. " (" .. data.framesInAir .. ")")
	dt(posVecToStr(data.basePos, "X, Z, Y  : "))
	dt(posVecToStr(data.actualPosDelta, "Delta    : "))
	local bm = Vector.add(Vector.subtract(data.basePos, data.actualPosDelta), data.basePosDelta)
	local pod = Vector.subtract(data.objPos, bm)
	dt(posVecToStr(data.collisionPush, "Collision: "))
	dt(posVecToStr(pod, "Hitbox   : "))
	endSection()
	-- Display angles
	if config.showAnglesAsDegrees then
		-- People like this
		local function atd(a)
			return (((a / 0x10000) * 360) + 360) % 360
		end
		local function ttd(v)
			local radians = math.atan(v[1], v[3])
			return radians * 360 / (2 * math.pi)
		end
		dt(f("Facing angle: %.3f", atd(data.facingAngle)))
		local da = atd(data.driftAngle)
		if da > 180 then da = da - 360 end
		dt(f("Drift angle: %.3f",  da))
		dt(f("Movement angle: %.3f (%.3f)", ttd(data.movementDirection), ttd(data.movementTarget)))
	else
		-- Suuper likes this
		dt(f("Angle: %6i + %6i = %6i", data.facingAngle, data.driftAngle, data.facingAngle + data.driftAngle))
		dt(f("Delta: %6i + %6i = %6i", data.facingDelta, data.driftDelta, data.facingDelta + data.driftDelta))
		local function tta(v)
			return f(" (%5.3f)", Vector.get2dMagnitude(v))
		end
		dt(normalVectorToStr(data.movementDirection, "Movement: ") .. tta(data.movementDirection))
		dt(normalVectorToStr(data.movementTarget, "Target  : ") .. tta(data.movementTarget))
	end
	dt(f("Pitch: %i (%i, %i)", data.pitch, quaternionAngle(data.snQuaternion), quaternionAngle(data.snqTarget)))
	endSection()
	-- surface stuff
	local n = data.surfaceNormalVector
	if config.showExactMovement then
		dt(f("Surface grip: %4i, sp: %4i,", data.grip, data.offroadSpeed))
	else
		dt(f("Surface grip: %6.3f, sp: %6.3f,", data.grip, data.offroadSpeed))
	end
	local steepness = Vector.get2dMagnitude(n) / (n[2] / 0x1000)
	steepness = f(", steep: %#.2f", steepness)
	dt(normalVectorToStr(n, "normal: ") .. steepness)
	endSection()
	
	-- Wall assist
	if config.showWasbThings then
		dt(rawQuaternion(data.snQuaternion, "Real:   "))
		dt(rawQuaternion(data.snqTarget,    "Target: "))
		endSection()
	end

	-- Ghost comparison
	if data.ghost then
		local distX = data.basePos[1] - data.ghost.basePos[1]
		local distZ = data.basePos[3] - data.ghost.basePos[3]
		local dist = math.sqrt(distX * distX + distZ * distZ)
		dt(f("Distance from ghost (2D): %.0f", dist))
		endSection()
	end
	
	-- Point comparison
	if form.comparisonPoint ~= nil then
		local delta = {
			data.basePos[1] - form.comparisonPoint[1],
			data.basePos[3] - form.comparisonPoint[3]
		}
		local dist = math.floor(math.sqrt(delta[1] * delta[1] + delta[2] * delta[2]))
		local angleRad = math.atan(delta[1], delta[2])
		dt("Distance travelled: " .. dist)
		dt("Angle: " .. math.floor(angleRad * 0x10000 / (2 * math.pi)))
		endSection()
	end

	-- Nearest object
	if data.nearestObject ~= nil then
		local obj = data.nearestObject
		dt(f("Object distance: %.0f (%s, %s)", obj.distance, obj.hitboxType, obj.type or obj.itemName))
		if config.showRawObjectPositionDelta then
			dt(posVecToStr(Vector.subtract(obj.objPos, data.objPos), "raw: "))
		end
		if obj.distanceComponents ~= nil then
			if obj.innerDistComps ~= nil then
				dt(posVecToStr(obj.distanceComponents, "outer: "))
				dt(posVecToStr(obj.innerDistComps, "inner: "))
			elseif obj.distanceComponents.v == nil then
				dt(posVecToStr(obj.distanceComponents))
			else
				dt(string.format("%9i, %8i", obj.distanceComponents.h, obj.distanceComponents.v))
			end
		end
		endSection()
	end
	
	-- bouncy stuff
	if Vector.getMagnitude(data.movementAdd1fc) ~= 0 then
		dt(normalVectorToStr(data.movementAdd1fc, "bounce 1: "))
	end
	if Vector.getMagnitude(data.movementAdd2f0) ~= 0 then
		dt(normalVectorToStr(data.movementAdd2f0, "bounce 2: "))
	end
	if Vector.getMagnitude(data.movementAdd374) ~= 0 then
		dt(normalVectorToStr(data.movementAdd374, "bounce 3: "))
	end
	if data.waterfallStrength ~= 0 then
		dt(normalVectorToStr(Vector.multiply_r(data.waterfallPush, data.waterfallStrength), "waterfall: "))
	end
	endSection()
	
	-- Display checkpoints
	if data.checkpoint ~= nil then
		if (data.spawnPoint > -1) then dt("Spawn Point: " .. data.spawnPoint) end
		dt(f("Checkpoint number (player) = %i (%i)", data.checkpoint, data.keyCheckpoint))
		dt("Lap: " .. data.lap)
		endSection()
	end
	
	-- Coins
	if raceData.coinsBeingCollected ~= nil and raceData.coinsBeingCollected > 0 then
		local coinCheckIn = nil
		if raceData.framesMod8 == 0 then
			dt("Coin increment this frame")
		else
			dt(f("Coin increment in %i frames", 8 - raceData.framesMod8))
		end
		endSection()
	end
	
	--y = 37
	--x = 350
	-- Display lap time
	--if data.lap_f then
	--	dt("Lap: " .. time(data.lap_f))
	--end
end
local roulleteItemNames = { -- The IDs according to the item roullete.
	"red shell", "banana", "fake item box",
	"mushroom", "triple mushroom", "bomb",
	"blue shell", "lightning", "triple greens",
	"triple banana", "triple reds", "star",
	"gold mushroom", "bullet bill", "blooper",
	"boo", "invalid17", "invalid18",
	"none",
}
roulleteItemNames[0] = "green shell"
local function drawItemInfo(data)
	if data == nil or data.roulleteItem == nil then return end

	if data.roulleteItem ~= 19 then
		gui.text(6, 84, roulleteItemNames[data.roulleteItem])
		if data.roulleteState == 1 then
			local ttpi = 60 - data.roulleteTimer
			if ttpi <= 0 then
				gui.text(6, 100, "stop roullete now")
			else
				gui.text(6, 100, string.format("stop in %i frames", ttpi))
			end
		elseif data.roulleteState == 2 then
			local ttpi = 33 - data.roulleteTimer
			gui.text(6, 100, string.format("use in %i frames", ttpi))
		end
	end
end

-- Collision drawing ----------------------------
local function makeDefaultViewport()
	return {
		orthographic = true,
		scale = config.defaultScale,
		w = 200,
		h = 150,
		x = 200,
		y = 150,
		perspectiveId = -5, -- top down
		overlay = false,
		drawCheckpoints = false,
		racerId = 0,
		drawKcl = true,
		drawObjects = true,
		active = true,
		renderAllTriangles = config.renderAllTriangles,
		backfaceCulling = config.backfaceCulling,
		focusPreMovement = false,
	}
end
local mainCamera = makeDefaultViewport()
mainCamera.drawText = function(x, y, s, c) gui.text(x + iView.x, iView.y - y, s, c) end
mainCamera.isPrimary = true
mainCamera.useDelay = true
mainCamera.active = false
mainCamera.renderHitboxesWhenFakeGhost = config.renderHitboxesWhenFakeGhost
mainCamera.drawRacers = false

local viewports = {}

local originalPadding = nil

local function updateDrawingRegions(camera)
	local clientWidth = client.screenwidth()
	local clientHeight = client.screenheight()
	local layout = nds.getscreenlayout()
	local gap = nds.getscreengap()
	--local invert = nds.getscreeninvert()
	local gameBaseWidth = nil
	local gameBaseHeight = nil
	if layout == "Natural" then
		-- We do not support rotated screens. Assume vertical.
		layout = "Vertical"
	end
	if layout == "Vertical" then
		gameBaseWidth = 256
		gameBaseHeight = 192 * 2 + gap
	elseif layout == "Horizontal" then
		gameBaseWidth = 256 * 2
		gameBaseHeight = 192
	else
		gameBaseWidth = 256
		gameBaseHeight = 192
	end
	local gameScale = math.min(clientWidth / gameBaseWidth, clientHeight / gameBaseHeight)
	if config.useIntegerScale then gameScale = math.floor(gameScale) end
	local colView = {
		w = 0.5 * 256 * gameScale,
		h = 0.5 * 192 * gameScale,
	}
	colView.x = (clientWidth - gameBaseWidth * gameScale) * 0.5 + colView.w
	colView.y = (clientHeight - gameBaseHeight * gameScale) * 0.5 + colView.h
	iView = {
		x = (clientWidth - (gameBaseWidth * gameScale)) * 0.5,
		y = (clientHeight - (gameBaseHeight * gameScale)) * 0.5,
		w = 256 * gameScale,
		h = 192 * gameScale,
	}
	if layout ~= "Horizontal" then
		if config.drawOnLeftSide == true then
			-- People who use wide window (black space to the side of game screen) tell me they prefer info to be displayed on the left rather than over the bottom screen.
			iView.x = 0
			if mainCamera.overlay == false then
				colView.x = colView.w
			end
		end
		iView.y = iView.y + (192 + gap) * gameScale
	else
		iView.x = iView.x + 256 * gameScale
	end

	camera.x = colView.x
	camera.y = colView.y
	camera.w = colView.w
	camera.h = colView.h
end
updateDrawingRegions(mainCamera)

Graphics.setPerspective(mainCamera, { 0, 0x1000, 0 })

local function updateViewportBasic(viewport)
	if viewport.racerId ~= -1 then
		if viewport.frozen ~= true then
			local racer = allRacers[viewport.racerId]
			-- will be nil if we are watching the fake ghost but moved to a frame with no fake ghost data
			if racer ~= nil then
				if viewport.focusPreMovement then
					viewport.location = racer.preMovementObjPos
				else
					viewport.location = racer.objPos
				end
			end
		end
		viewport.obj = nil
	elseif viewport.objFocus ~= nil and allObjects ~= nil then
		for _, obj in pairs(allObjects.list) do
			if obj.skip == false and obj.ptr == viewport.objFocus then
				if viewport.frozen ~= true then viewport.location = obj.objPos end
				viewport.obj = obj
				return
			end
		end
		-- If the object disappears, can we just keep the old object?
		--viewport.obj = nil
		if viewport.obj ~= nil then
			viewport.obj.ptr = 0
			viewport.obj.skip = true
		end
	end
end
local function updateViewport(viewport)
	updateViewportBasic(viewport)
	if viewport == mainCamera then
		-- Camera view overrides other viewpoint settings
		mainCamera.drawRacers = mainCamera.active == false and mainCamera.renderHitboxesWhenFakeGhost == true and fakeGhostExists == true
		if mainCamera.overlay == true or mainCamera.drawRacers then
			local ch = gameCameraHisotry[1]
			if ch.location == nil then ch = gameCameraHisotry[3] end
			mainCamera.location = ch.location
			mainCamera.fovW = ch.fovW
			mainCamera.fovH = ch.fovH
			Graphics.setPerspective(mainCamera, ch.direction)
			mainCamera.orthographic = false
		elseif mainCamera.frozen == true then
			mainCamera.location = mainCamera.freezePoint
		end
	elseif viewport.frozen ~= true then	
		if viewport.perspectiveId == -6 then
			local ch = nil
			if viewport.racerId == 0 then
				ch = gameCameraHisotry[3]
			elseif viewport.obj ~= nil then
				ch = getFakeCameraData(viewport.obj, viewport)
			elseif viewport.racerId ~= -1 then
				ch = getFakeCameraData(allRacers[viewport.racerId], viewport)
			end
			if ch ~= nil then -- Will be nil if focused on object that got destroyed
				viewport.location = ch.location
				viewport.fovW = ch.fovW
				viewport.fovH = ch.fovH
				Graphics.setPerspective(viewport, ch.direction)
			end
		end
	end
end
local function drawViewport(viewport)
	if viewport == mainCamera then
		local id = 1
		if (not mainCamera.orthographic) and (mainCamera.useDelay and mainCamera.active) then
			id = 3
			if drawingPackages[id] == nil then
				id = 2
				if drawingPackages[id] == nil then id = 1 end
			end
		end
		if drawingPackages[id] == nil then error("nil package") end

		gui.use_surface("client")
		Graphics.drawClient(mainCamera, drawingPackages[id])
	else
		Graphics.drawForms(viewport, drawingPackages[1])
	end
end

-- Main drawing function
local function _mkdsinfo_run_draw(isInRace)
	-- BizHawk is slow. Let's tell it to not worry about waiting for this.
	if not client.ispaused() and not drawWhileUnpaused then
		if client.isseeking() then
			-- We need special logic here. BizHawk will not set paused = true at end of seek before this script runs!
			emu.yield()
			if not client.ispaused() then
				return
			end
		else
			-- I would just yield, then check if we're still on the same frame and draw then.
			-- However, BizHawk will not display anything we draw after a yield, while not paused.
			return
		end
	end
	
	gui.clearGraphics("client")
	gui.clearGraphics("emucore")
	gui.cleartext()
	if isInRace then
		if config.showBottomScreenInfo then
			drawInfoBottomScreen(focusedRacer)
			drawItemInfo(focusedRacer)
		end

		-- If the main KCL view is not turned on, we want to show the 
		-- nearby triangles data for the bottom-screen focused racer.
		local temp = mainCamera.racerId
		if mainCamera.active == false then mainCamera.racerId = watchingId end
		updateViewport(mainCamera)
		drawViewport(mainCamera)
		if mainCamera.active == false then mainCamera.racerId = temp end
		for i = 1, #viewports do
			updateViewport(viewports[i])
			drawViewport(viewports[i])
		end
	else
		if config.showBottomScreenInfo then
			drawText(10, 10, "Not in a race.")
		end
	end
end
-------------------------------------------------

-- UI --------------------------------
local function redraw(farRewind)
	-- BizHawk won't clear it for us on the next frame, if we don't actually draw anything on the next frame.
	gui.clearGraphics("client")
	gui.clearGraphics("emucore")
	gui.cleartext()

	-- If we are not paused, there's no point in redrawing. The next frame will be here soon enough.
	if not client.ispaused() then
		return
	end
	-- BizHawk does not let us re-draw while paused. So the only way to redraw is to rewind and come back to this frame.
	-- Update: BizHawk 2.10 does let us re-draw!
	if bizhawkVersion < 10 and not tastudio.engaged() then
		return
	elseif bizhawkVersion >= 10 and not farRewind then
		if inRace() then
			_mkdsinfo_run_data(true)
			_mkdsinfo_run_draw(true)
		else
			_mkdsinfo_run_draw(false)
		end
		return
	end

	-- emu.yield() -- this throws an Exception in BizHawk's code
	-- We ALSO cannot use tastudio.setplayback for the frame we want. Because BizHawk freezes the UI and won't run Lua while such a seek is happening so 
	-- (1) we won't have the right data when it's done and (2) we have no way of knowing when it is done.
	-- So we must actually tell TAStudio to rewind to 3 frames earlier.
	-- Then we can have Lua run over the next two frames, collecting data for the frame we want and the frames prior (for camera data + position delta).
	-- But we also must tell TAStudio to seek to a frame that is preceeded by a state; else it will rewind+emulate with a non-responsive UI.
	local f = frame - 3
	if farRewind then f = f - 3 end
	while not tastudio.hasstate(f - 1) and f >= 0 do
		f = f - 1
	end
	tastudio.setplayback(f)
	redrawSeek = frame
	client.unpause()
end

local function useInputsClick()
	if not inRace() then
		print("You aren't in a race.")
		return
	end
	if not tastudio.engaged() then
		return
	end
	
	if form.ghostInputs == nil then
		form.ghostInputs = memory.read_bytes_as_array(memory.read_s32_le(Memory.addrs.ptrPlayerInputs), 0xdce) -- 0x8ace)
		form.firstGhostInputFrame = frame - memory.read_s32_le(memory.read_s32_le(Memory.addrs.ptrRaceTimers) + 4) + 121
		form.ghostLapTimes = memory.read_bytes_as_array(memory.read_s32_le(Memory.addrs.ptrCheckNum) + 0x20, 0x4 * 5)
		setGhostInputs(form)
		forms.settext(form.ghostInputHackButton, "input hack active")
	else
		form.ghostInputs = nil
		forms.settext(form.ghostInputHackButton, "Copy from player")
	end
end
local function _watchUpdate()
	local s
	if watchingId == 0 then
		s = "player"
	elseif watchingId == racerCount then
		s = "fake ghost"
	elseif Objects.isGhost(allRacers[watchingId].ptr) then
		s = "ghost"
	else
		s = "cpu " .. watchingId
	end
	forms.settext(form.watchLabel, s)

	redraw(config.enableCameraFocusHack) -- Will rewind and so grab data for newly watched racer.
end
local function watchLeftClick()
	watchingId = watchingId - 1
	if watchingId == -1 then
		watchingId = #allRacers
	end
	_watchUpdate()
end
local function watchRightClick()
	watchingId = watchingId + 1
	if watchingId > #allRacers then
		watchingId = 0
	end
	_watchUpdate()
end

local function shouldFocusOnObject(obj)
	if obj.skip == true then
		return false
	elseif obj.isMapObject then
		return obj.hitboxType ~= "no hitbox"
	elseif obj.isItem then
		-- TODO: What type of item is it?
		return true
	end
end
local function nextObj(beginId, direction)
	if allObjects == nil then error("no objects list") end
	local endId = #allObjects.list
	if direction == -1 then endId = 1 end
	for i = beginId, endId, direction do
		local obj = allObjects.list[i]
		if shouldFocusOnObject(obj) then
			return obj
		end
	end
	return nil
end
local function focusClick(viewport, plusminus)
	if allObjects == nil then error("no objects list") end
	if viewport.racerId ~= -1 then
		if viewport.racerId == 0 and ((viewport.focusPreMovement == false) == (plusminus == 1)) and viewport.scale < 250 then
			viewport.focusPreMovement = not viewport.focusPreMovement
		else
			viewport.focusPreMovement = false
			viewport.racerId = viewport.racerId + plusminus
			if viewport.racerId == -1 or viewport.racerId == #allRacers + 1 then
				local b = 1
				if plusminus == -1 then b = #allObjects.list end
				local obj = nextObj(b, plusminus)
				viewport.racerId = -1
				if obj ~= nil then
					viewport.objFocus = obj.ptr
					forms.settext(viewport.focusLabel, obj.itemName or Objects.mapObjTypes[obj.typeId] or string.format("unk (%i)", obj.typeId))
					redraw()
					return
				else
					viewport.racerId = #allRacers - 1
				end
			elseif viewport.racerId == 0 then
				viewport.focusPreMovement = plusminus == -1 and viewport.scale < 250
			end
		end
	else
		local obj = nil
		if #allObjects.list ~= 0 then
			-- Does our current focus object exist?
			local currentId = nil
			for i = 1, #allObjects.list do
				if allObjects.list[i].ptr == viewport.objFocus then
					if allObjects.list[i].skip == false then					
						currentId = i
					end
					break
				end
			end
			if currentId == nil then
				-- No.
				currentId = 0
				if plusminus < 0 then currentId = #allObjects.list + 1 end
			end
			obj = nextObj(currentId + plusminus, plusminus)
		end
		if obj ~= nil then
			viewport.objFocus = obj.ptr
			forms.settext(viewport.focusLabel, obj.itemName or Objects.mapObjTypes[obj.typeId] or string.format("unk (%i)", obj.typeId))
			redraw()
			return
		else
			viewport.objFocus = nil
			viewport.racerId = 0
			if plusminus < 0 then viewport.racerId = #allRacers end
		end
	end
	forms.settext(viewport.focusLabel, string.format("racer %i%s", viewport.racerId, (viewport.focusPreMovement and " (pre)") or ""))
	redraw()
end

local function setComparisonPointClick()
	if form.comparisonPoint == nil then
		local pos = focusedRacer.basePos
		form.comparisonPoint = { pos[1], pos[2], pos[3] }
		forms.settext(form.setComparisonPoint, "Clear comparison point")
	else
		form.comparisonPoint = nil
		forms.settext(form.setComparisonPoint, "Set comparison point")
	end
end
local function loadGhostClick()
	local fileName = forms.openfile(nil,nil,"TAStudio Macros (*.bk2m)|*.bk2m|All Files (*.*)|*.*")
	local inputFile = assert(io.open(fileName, "rb"))
	local inputHeader = inputFile:read("*line")
	-- Parse the header
	local names = {}
	local index = 0
	local nextIndex = string.find(inputHeader, "|", index)
	while nextIndex ~= nil do
		names[#names + 1] = string.sub(inputHeader, index, nextIndex - 1)
		index = nextIndex + 1
		nextIndex = string.find(inputHeader, "|", index)
		if #names > 100 then
			error("unable to parse header")
		end
	end
	nextIndex = string.len(inputHeader)
	names[#names + 1] = string.sub(inputHeader, index, nextIndex - 1)
	-- ignore next 3 lines
	local line = inputFile:read("*line")
	while string.sub(line, 1, 1) ~= "|" do
		line = inputFile:read("*line")
	end
	-- parse inputs
	local inputs = {}
	while line ~= nil and string.sub(line, 1, 1) == "|" do
		-- |  128,   96,    0,    0,.......A...r....|
		-- Assuming all non-button inputs are first.
		local id = 1
		index = 0
		local nextComma = string.find(line, ",", index)
		while nextComma ~= nil do
			id = id + 1
			index = nextComma + 1
			nextComma = string.find(line, ",", index)
			if id > 100 then
				error("unable to parse input")
			end
		end
		-- now buttons
		local buttons = 0
		while id <= #names do
			if string.sub(line, index, index) ~= "." then
				if names[id] == "A" then buttons = buttons | 0x01
				elseif names[id] == "B" then buttons = buttons | 0x02
				elseif names[id] == "R" then buttons = buttons | 0x04
				elseif names[id] == "X" or names[id] == "L" then buttons = buttons | 0x08
				elseif names[id] == "Right" then buttons = buttons | 0x10
				elseif names[id] == "Left" then buttons = buttons | 0x20
				elseif names[id] == "Up" then buttons = buttons | 0x40
				elseif names[id] == "Down" then buttons = buttons | 0x80
				end
			end
			id = id + 1
			index = index + 1
		end
		inputs[#inputs + 1] = buttons
		line = inputFile:read("*line")
	end
	inputFile:close()
	-- turn inputs into MKDS recording format (buttons, count)
	local bytes = { 0, 0, 0, 0 }
	local count = 1
	local lastInput = inputs[1]
	for i = 2, #inputs do
		if inputs[i] ~= lastInput or count == 255 then
			bytes[#bytes + 1] = lastInput
			bytes[#bytes + 1] = count
			lastInput = inputs[i]
			count = 1
			if #bytes == 0xdcc then
				print("Maximum ghost recording length reached.")
				break
			end
		else
			count = count + 1
		end
	end
	while #bytes < 0xdcc do bytes[#bytes + 1] = 0 end
	-- write
	form.ghostInputs = bytes
	form.firstGhostInputFrame = frame - memory.read_s32_le(memory.read_s32_le(Memory.addrs.ptrRaceTimers) + 4) + 121
	form.ghostLapTimes = {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0}
	setGhostInputs(form)
	forms.settext(form.ghostInputHackButton, "input hack active")

end
local function saveCurrentInputsClick()
	-- BizHawk doesn't expose a file open function (Lua can still write to files, we just don't have a nice way to let the user choose a save location.)
	-- So instead, we just tell the user which frames to save.
	local firstInputFrame = frame - memory.read_s32_le(memory.read_s32_le(Memory.addrs.ptrRaceTimers) + 4) + 121
	print("BizHawk doesn't give Lua a save file dialog.")
	print("You can manually save your current inputs as a .bk2m:")
	print("1) Select frames " .. firstInputFrame .. " to " .. frame .. " (or however many frames you want to include).")
	print("2) File -> Save Selection to Macro")
end

local function branchLoadHandler(branchId)
	if shouldExit or form == nil then
		-- BizHawk bug: Registered events continue to run after a script has stopped.
		tastudio.onbranchload(function() end)
		return
	end
	if form.firstStateWithGhost ~= 0 then
		form.firstStateWithGhost = 0
	end
	if form.ghostInputs ~= nil and inRace() then
		-- Must call emu.framecount instead of using our frame variable, since we've just loaded a branch. And then potentially had TAStudio rewind.
		local currentFrame = emu.framecount()
		setGhostInputs(form)
		if emu.framecount() ~= currentFrame and config.alertOnRewindAfterBranch then
			print("Movie rewind: ghost inputs changed after branch load.")
			print("Stop ghost input hacker to load branch without rewind.")
		end
	end
end

local function drawUnpausedClick()
	drawWhileUnpaused = not drawWhileUnpaused
	if drawWhileUnpaused then
		forms.settext(form.drawUnpausedButton, "Draw while unpaused: ON")
	else
		forms.settext(form.drawUnpausedButton, "Draw while unpaused: OFF")
	end
end

local function zoomInClick(camera)
	camera = camera or mainCamera
	camera.scale = camera.scale * 0.8
	drawViewport(camera)
end
local function zoomOutClick(camera)
	camera = camera or mainCamera
	camera.scale = camera.scale / 0.8
	drawViewport(camera)
end

local function _changePerspective(cam)
	if cam == mainCamera then
		forms.setproperty(form.delayCheckbox, "Visible", false)
	end

	local id = cam.perspectiveId
	if id < 0 then
		local presets = {
			{ "camera", nil },
			{ "top down", { 0, 0x1000, 0 }},
			{ "north-south", { 0, 0, -0x1000 }},
			{ "south-north", { 0, 0, 0x1000 }},
			{ "east-west", { 0x1000, 0, 0 }},
			{ "west-east", { -0x1000, 0, 0 }},
		}
		if id == -6 then
			-- camera
			local cameraPtr = memory.read_u32_le(Memory.addrs.ptrCamera)
			local direction = read_pos(cameraPtr + 0x15c)
			Graphics.setPerspective(cam, Vector.multiply(direction, -1))
			cam.orthographic = false
			cam.overlay = cam == mainCamera
			if cam == mainCamera then
				forms.setproperty(form.delayCheckbox, "Visible", true)
			end
		else
			Graphics.setPerspective(cam, presets[id + 7][2])
			cam.orthographic = true
			cam.overlay = false
		end
		forms.settext(cam.perspectiveLabel, presets[id + 7][1])
	else
		if triangles == nil or triangles[id] == nil then error("no such triangle") end
		Graphics.setPerspective(cam, triangles[id].surfaceNormal)
		cam.orthographic = true
		cam.overlay = false
		forms.settext(cam.perspectiveLabel, "triangle " .. id)
	end

	if cam.box == nil then
		redraw()
	else
		if cam.perspectiveId == -6 then
			local camData = getInGameCameraData()
			cam.location = camData.location
			cam.fovW = camData.fovW
			cam.fovH = camData.fovH
			Graphics.setPerspective(cam, camData.direction)
		elseif cam.frozen ~= true then
			cam.location = focusedRacer.objPos
		end
		redraw()
	end
end
local function changePerspectiveLeft(cam)
	cam = cam or mainCamera

	local id = cam.perspectiveId
	id = id - 1
	if id < -6 then
		id = 9999
	end
	if id >= 0 then
		-- find next nearby triangle ID
		local racer = allRacers[cam.racerId]
		local tris = KCL.getNearbyTriangles(racer.objPos)
		local nextId = 0
		for i = 1, #tris do
			local ti = tris[i].id
			if ti < id and ti > nextId then
				if not Vector.equals(cam.rotationVector, tris[i].surfaceNormal) then
					nextId = ti
				end
			end
		end
		if nextId == 0 then
			id = -1
		else
			id = nextId
		end
	end
	cam.perspectiveId = id
	_changePerspective(cam)
end
local function changePerspectiveRight(cam)
	cam = cam or mainCamera

	local id = cam.perspectiveId
	id = id + 1
	if id >= 0 then
		-- find next nearby triangle ID
		local racer = allRacers[cam.racerId]
		local tris = KCL.getNearbyTriangles(racer.objPos)
		local nextId = 9999
		for i = 1, #tris do
			local ti = tris[i].id
			if ti >= id and ti < nextId then
				if not Vector.equals(cam.rotationVector, tris[i].surfaceNormal) then
					nextId = ti
				end
			end
		end
		if nextId == 9999 then
			id = -6
		else
			id = nextId
		end
	end
	cam.perspectiveId = id
	_changePerspective(cam)
end

local function makeCollisionControls(kclForm, viewport, x, y)
	local labelMargin = 2
	local baseY = y

	-- where is the camera+focus
	local temp = forms.label(kclForm, "Zoom", x, y + 4)
	forms.setproperty(temp, "AutoSize", true)
	temp = forms.button(
		kclForm, "+", function() zoomInClick(viewport) end,
		forms.getproperty(temp, "Right") + labelMargin, y,
		23, 23
	)
	temp = forms.button(
		kclForm, "-", function() zoomOutClick(viewport) end,
		forms.getproperty(temp, "Right") + labelMargin, y,
		23, 23
	)
	temp = forms.checkbox(kclForm, "freeze location", forms.getproperty(temp, "Right") + labelMargin, y + 4)
	forms.setproperty(temp, "AutoSize", true)
	forms.addclick(temp, function()
		viewport.frozen = not viewport.frozen
		viewport.freezePoint = viewport.location
		if not viewport.frozen then
			redraw()
		end
	end)

	y = y + 26
	temp = forms.label(
		kclForm, "Perspective:",
		x, y + 4
	)
	forms.setproperty(temp, "AutoSize", true)
	temp = forms.button(
		kclForm, "<", function() changePerspectiveLeft(viewport) end,
		forms.getproperty(temp, "Right") + labelMargin*2, y,
		18, 23
	)
	viewport.perspectiveLabel = forms.label(
		kclForm, "top down",
		forms.getproperty(temp, "Right") + labelMargin*2, y + 4
	)
	forms.setproperty(viewport.perspectiveLabel, "AutoSize", true)
	temp = forms.button(
		kclForm, ">", function() changePerspectiveRight(viewport) end,
		forms.getproperty(viewport.perspectiveLabel, "Right") + 38, y,
		18, 23
	)
	local rightmost = forms.getproperty(temp, "Right") + 0
	y = y + 26
	temp = forms.label(
		kclForm, "Focus on:",
		x, y + 4
	)
	forms.setproperty(temp, "AutoSize", true)
	temp = forms.button(
		kclForm, "<", function() focusClick(viewport, -1) end,
		forms.getproperty(temp, "Right") + labelMargin*2, y,
		18, 23
	)
	viewport.focusLabel = forms.label(
		kclForm, "racer 0",
		forms.getproperty(temp, "Right") + labelMargin*2, y + 4
	)
	forms.setproperty(viewport.focusLabel, "AutoSize", true)
	temp = forms.button(
		kclForm, ">", function() focusClick(viewport, 1) end,
		forms.getproperty(viewport.focusLabel, "Left") + 102, y,
		18, 23
	)

	-- what is drawn
	y = baseY + 3
	x = rightmost - 10
	temp = forms.label(kclForm, "Draw:", x, y)
	forms.setproperty(temp, "AutoSize", true)
	x = forms.getproperty(temp, "Right") + labelMargin
	temp = forms.checkbox(kclForm, "kcl", x, y)
	forms.setproperty(temp, "AutoSize", true)
	forms.setproperty(temp, "Checked", true)
	forms.addclick(temp, function() viewport.drawKcl = not viewport.drawKcl; redraw(); end)
	y = y + 21
	temp = forms.checkbox(kclForm, "objects", x, y)
	forms.setproperty(temp, "AutoSize", true)
	forms.setproperty(temp, "Checked", true)
	forms.addclick(temp, function() viewport.drawObjects = not viewport.drawObjects; redraw(); end)
	y = y + 21
	temp = forms.checkbox(kclForm, "checkpoints", x, y)
	forms.setproperty(temp, "AutoSize", true)
	forms.addclick(temp, function() viewport.drawCheckpoints = not viewport.drawCheckpoints; redraw(); end)
	y = y + 21
	temp = forms.checkbox(kclForm, "paths", x, y)
	forms.setproperty(temp, "AutoSize", true)
	forms.addclick(temp, function() viewport.drawPaths = not viewport.drawPaths; redraw(); end)

	y = y + 21
	y = y + 4 -- bottom padding
	return y - baseY
end

local function makeNewKclView()
	local viewport = makeDefaultViewport()
	Graphics.setPerspective(viewport, {0, 0x1000, 0})

	local hiddenHeight = 27 -- Y pos of box when controls are hidden
	viewport.window = forms.newform(viewport.w * 2, viewport.h * 2, "KCL View", function ()
		MKDS_INFO_FORM_HANDLES[viewport.window] = nil
		removeItem(viewports, viewport)
	end)
	MKDS_INFO_FORM_HANDLES[viewport.window] = true
	local theBox = forms.pictureBox(viewport.window, 0, 0, viewport.w * 2, viewport.h * 2)
	viewport.box = theBox
	forms.setproperty(viewport.window, "FormBorderStyle", "Sizable")
	forms.setproperty(viewport.window, "MaximizeBox", "True")
	forms.setDefaultTextBackground(theBox, 0xff222222)
	viewport.drawText = function(x, y, t, c) forms.drawText(theBox, x, viewport.h + viewport.h - y, t, c, nil, 14, "verdana", "bold") end

	viewport.boxWidthDelta = forms.getproperty(viewport.window, "Width") - forms.getproperty(theBox, "Width")
	viewport.boxHeightDelta = forms.getproperty(viewport.window, "Height") - forms.getproperty(theBox, "Height")

	local hieghtOfControls = makeCollisionControls(viewport.window, viewport, 5, 3)
	forms.setproperty(viewport.box, "Top", hieghtOfControls)
	forms.setsize(viewport.window, viewport.w * 2, viewport.h * 2 + hieghtOfControls)

	-- No resize events. Make a resize/refresh button? Click the box? Box is easy but would be a kinda hidden feature.
	local temp = forms.label(viewport.window, "Click the box to resize it!", 15, viewport.h * 2 + hieghtOfControls)
	forms.setproperty(temp, "AutoSize", true)
	forms.addclick(theBox, function()
		local width = forms.getproperty(theBox, "Width")
		local height = forms.getproperty(theBox, "Height")
		-- Is this a resize?
		local boxHeightDelta = viewport.boxHeightDelta + tonumber(forms.getproperty(theBox, "Top"))
		local fw = forms.getproperty(viewport.window, "Width")
		local fh = forms.getproperty(viewport.window, "Height")
		if fw - width ~= viewport.boxWidthDelta or fh - height ~= boxHeightDelta then
			forms.setsize(theBox, fw - viewport.boxWidthDelta, fh - boxHeightDelta)
			viewport.w = (fw - viewport.boxWidthDelta) / 2
			viewport.h = (fh - boxHeightDelta) / 2
			viewport.x = viewport.w
			viewport.y = viewport.h
			redraw()
			return
		end

		width = width / 2
		height = height / 2
		local x = viewport.scale * (forms.getMouseX(theBox) - width)
		local y = viewport.scale * (forms.getMouseY(theBox) - height)
		y = -y
		-- Solve the system of linear equations to find which 3D directions to move in
		local directions = Graphics.getDirectionsFrom2d(viewport)
		viewport.location = Vector.add(viewport.location, Vector.multiply(directions[1], x))
		viewport.location = Vector.add(viewport.location, Vector.multiply(directions[2], y))
		local wasFrozen = viewport.frozen
		viewport.frozen = true
		redraw()
		viewport.frozen = wasFrozen
	end)

	-- I was going to put this on top of the box, but BizHawk appears to force picture boxes on top.
	viewport.showControlsButton = forms.button(viewport.window, "^", function()
		local current = forms.getproperty(viewport.box, "Top")
		if current == hiddenHeight .. "" then -- getproperty returns string
			forms.setproperty(viewport.box, "Top", hieghtOfControls)
			forms.setsize(viewport.window, viewport.w * 2, viewport.h * 2 + hieghtOfControls)
			forms.settext(viewport.showControlsButton, "^")
		else
			forms.setproperty(viewport.box, "Top", hiddenHeight)
			forms.setsize(viewport.window, viewport.w * 2, viewport.h * 2 + hiddenHeight)
			forms.settext(viewport.showControlsButton, "v")
		end
	end, 300, 3, 23, 23)

	viewports[#viewports + 1] = viewport
	updateViewport(viewport)
	drawViewport(viewport)
end

local function recordPosition()
	form.recordingFakeGhost = not form.recordingFakeGhost
	if form.recordingFakeGhost then
		-- If we have an exact match, don't delete the whole thing.
		local fakeGhostFrame = memory.read_s32_le(ptrRaceTimers + 4)
		local ghost = fakeGhostData[fakeGhostFrame]
		if ghost ~= nil and deepMatch(ghost, focusedRacer.rawData, 1) then
			local count = #fakeGhostData
			for i = fakeGhostFrame + 1, count do
				fakeGhostData[i] = nil
				recordedPaths[racerCount + 1].path[i] = nil
			end
		else
			fakeGhostData = {}
			recordedPaths[racerCount + 1].path = {}
		end
		forms.settext(form.recordPositionButton, "Stop recording")
	else
		forms.settext(form.recordPositionButton, "Record fake ghost")
	end
end

local bizHawkEventIds = {}
if MKDS_INFO_FORM_HANDLES == nil then MKDS_INFO_FORM_HANDLES = {} end
local function _mkdsinfo_close()
	if config.drawOnLeftSide == true and originalPadding ~= nil then
		client.SetClientExtraPadding(originalPadding.left, originalPadding.top, originalPadding.right, originalPadding.bottom)
	end
	for k, _ in pairs(MKDS_INFO_FORM_HANDLES) do
		forms.destroy(k)
	end
	MKDS_INFO_FORM_HANDLES = {}
	
	for i = 1, #bizHawkEventIds do
		event.unregisterbyid(bizHawkEventIds[i])
	end
	
	-- Undo camera hack
	if watchingId ~= 0 and inRace() then
		local raceThing = memory.read_u32_le(Memory.addrs.ptrSomeRaceData)
		memory.write_u8(raceThing + 0x62, 0)
		memory.write_u8(raceThing + 0x63, 0)
	end

	gui.clearGraphics("client")
	gui.clearGraphics("emucore")
	gui.cleartext()
	hasClosed = true
end
local function _mkdsinfo_setup()
	if emu.framecount() < 400 then
		-- <400: rough detection of if stuff we need is loaded
		-- Specifically, we find addresses of hitbox functions.
		print("Looks like some data might not be loaded yet. Re-start this Lua script at a later frame.")
		shouldExit = true
		return
	elseif config.showBizHawkDumbnessWarning then
		print("BizHawk's Lua API is horrible. In order to work around bugs and other limitations, do not stop this script through BizHawk. Instead, close the window it creates and it will stop itself.")
	end

	for k, _ in pairs(MKDS_INFO_FORM_HANDLES) do
		forms.destroy(k)
	end
	MKDS_INFO_FORM_HANDLES = {}
	
	local noKclHeight = 142
	local yesKclHeight = 222

	form = {}
	form.firstStateWithGhost = 0
	form.comparisonPoint = nil
	form.handle = forms.newform(322, noKclHeight, "MKDS Info Thingy", function()
		MKDS_INFO_FORM_HANDLES[form.handle] = nil
		if my_script_id == script_id then
			shouldExit = true
			if bizhawkVersion == 9 then
				redraw()
			else
				_mkdsinfo_close()
			end
		end
	end)
	MKDS_INFO_FORM_HANDLES[form.handle] = true
	local borderHeight = forms.getproperty(form.handle, "Height") + 0 - noKclHeight
	
	local buttonMargin = 5
	local labelMargin = 2
	local y = 10

	local temp = forms.label(form.handle, "Watching: ", 10, y + 4)
	forms.setproperty(temp, "AutoSize", true)
	form.watchLeft = forms.button(
		form.handle, "<", watchLeftClick,
		forms.getproperty(temp, "Right") + labelMargin, y,
		18, 23
	)
	form.watchLabel = forms.label(form.handle, "player", forms.getproperty(form.watchLeft, "Right") + labelMargin, y + 4)
	forms.setproperty(form.watchLabel, "AutoSize", true)
	form.watchRight = forms.button(
		form.handle, ">", watchRightClick,
		forms.getproperty(form.watchLabel, "Right") + labelMargin, y,
		18, 23
	)
	
	form.setComparisonPoint = forms.button(
		form.handle, "Set comparison point", setComparisonPointClick,
		forms.getproperty(form.watchRight, "Right") + buttonMargin, y,
		100, 23
	)
	
	y = y + 28
	temp = forms.label(form.handle, "Ghost: ", 10, y + 4)
	forms.setproperty(temp, "AutoSize", true)
	temp = forms.button(
		form.handle, "Copy from player", useInputsClick,
		forms.getproperty(temp, "Right") + buttonMargin, y,
		100, 23
	)
	form.ghostInputHackButton = temp
	
	if false then
		-- Removing these from the UI, they don't see much use.
		temp = forms.button(
			form.handle, "Load bk2m", loadGhostClick,
			forms.getproperty(temp, "Right") + labelMargin, y,
			70, 23
		)
		temp = forms.button(
			form.handle, "Save bk2m", saveCurrentInputsClick,
			forms.getproperty(temp, "Right") + labelMargin, y,
			70, 23
		)
		-- I also want a save-to-bk2m at some point. Although BizHawk doesn't expose a file open function (Lua can still write to files, we just don't have a nice way to let the user choose a save location.) so we might instead copy input to the current movie and let the user save as bk2m manually.
	end
	-- Fake ghost
	form.recordPositionButton = forms.button(
		form.handle, "Record fake ghost", recordPosition,
		forms.getproperty(temp, "Right") + labelMargin*2, y,
		110, 23
	)

	y = y + 28
	form.drawUnpausedButton = forms.button(
		form.handle, "Draw while unpaused: ON", drawUnpausedClick,
		10, y, 150, 23
	)

	-- Collision view
	y = y + 28
	temp = forms.label(form.handle, "3D viewing", 10, y + 3)
	forms.setproperty(temp, "AutoSize", true)
	y = y + 19
	temp = forms.checkbox(form.handle, "draw over screen", 10, y + 3)
	forms.setproperty(temp, "AutoSize", true)
	forms.addclick(temp, function()
		mainCamera.active = not mainCamera.active
		if mainCamera.active then
			forms.setproperty(form.handle, "Height", yesKclHeight + borderHeight)
		else
			forms.setproperty(form.handle, "Height", noKclHeight + borderHeight)
		end
		redraw()
	end)
	form.delayCheckbox = forms.checkbox(form.handle, "delay", forms.getproperty(temp, "Right") + labelMargin, y + 3)
	forms.setproperty(form.delayCheckbox, "AutoSize", true)
	forms.addclick(form.delayCheckbox, function() mainCamera.useDelay = not mainCamera.useDelay; redraw() end)
	forms.setproperty(form.delayCheckbox, "Checked", true)
	forms.setproperty(form.delayCheckbox, "Visible", false)
	if bizhawkVersion > 9 then
		-- Bug in BizHawk 2.9: We cannot draw on any picturebox if more than one form is open.
		temp = forms.button(
			form.handle, "new window", makeNewKclView,
			forms.getproperty(form.delayCheckbox, "Right") + labelMargin, y, 86, 23
		)
	end

	y = y + 28
	makeCollisionControls(form.handle, mainCamera, 10, y)
end
local hasClosed = false

-- BizHawk ----------------------------
memory.usememorydomain("ARM9 System Bus")

local function main()
	_mkdsinfo_setup()
	while (not shouldExit) or (redrawSeek ~= nil) do
		frame = emu.framecount()
		
		if not shouldExit then
			if inRace() then
				local racer = getRacerDetails(memory.read_bytes_as_array(memory.read_u32_le(0x0217ACF8 + ptrOffset), 0x400))  -- assuming this is where you already call it

				if racer then
					local f = io.open("mkds_data.csv", "a")  -- append mode

					-- flatten and write the values; adjust fields as needed
					f:write(string.format(
						"%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d\n",
						racer.basePos[1], racer.basePos[2], racer.basePos[3],
						racer.speed, racer.verticalVelocity,
						racer.facingAngle, racer.driftAngle, racer.pitch,
						racer.air == "Air" and 1 or 0,
						racer.itemId or -1,
						racer.roulleteItem or -1,
						racer.itemCount or -1,
						racer.effectSpeed or 0,
						racer.framesInAir or 0,
						racer.grip or 0,
						racer.offroadSpeed or 0,
						racer.wallSpeedMult or 0,
						racer.mtTime or 0,
						racer.turnLoss or 0
					))

					f:close()
				end

				_mkdsinfo_run_data()
				_mkdsinfo_run_draw(true)
			else
				_mkdsinfo_run_draw(false)
			end
		end
		
		-- BizHawk shenanigans
		local stopSeeking = false
		if redrawSeek ~= nil and redrawSeek == frame then
			stopSeeking = true
		elseif client.ispaused() then
			-- User has interrupted the rewind seek.
			stopSeeking = true
		end
		if stopSeeking then
			client.pause()
			redrawSeek = nil
			if not shouldExit then
				emu.frameadvance()
			else
				-- The while loop will exit!
			end
		else
			emu.frameadvance()
		end
	end
	if not hasClosed then _mkdsinfo_close() end	
end

gui.clearGraphics("client")
gui.clearGraphics("emucore")
gui.use_surface("emucore")
gui.cleartext()

if tastudio.engaged() then
	bizHawkEventIds[#bizHawkEventIds + 1] = tastudio.onbranchload(branchLoadHandler)
end

-- GLOBAL
function mkdsireload()
	config = readConfig()
	mkdsiConfig = config

	mainCamera.renderAllTriangles = config.renderAllTriangles
	mainCamera.backfaceCulling = config.backfaceCulling
	mainCamera.renderHitboxesWhenFakeGhost = config.renderHitboxesWhenFakeGhost
	for i = 1, #viewports do
		viewports[i].renderAllTriangles = config.renderAllTriangles
		viewports[i].backfaceCulling = config.backfaceCulling
	end

	updateDrawingRegions(mainCamera)
	redraw()
end

main()
