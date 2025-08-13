local m = {}

local function to_number_if_boolean(val)
		if type(val) == "boolean" then
			return val and 1 or 0
		end
		return val
	end

function m.sendStatsAndCtrls(stats, ctrls)
	if not stats then return end
	local f = assert(io.open("../data/cur_stats_and_ctrls.dat", "w+"))
	local buffer = ""

	for stat, value in pairs(stats) do
		buffer = buffer .. stat .. "=" .. tostring(to_number_if_boolean(value)) .. "\n"
	end

	for ctrl, value in pairs(ctrls) do
		buffer = buffer .. ctrl .. "=" .. tostring(to_number_if_boolean(value)) .. "\n"
	end

	f:write(buffer)
	f:close()
end

function m.receiveCtrls()
	local file = assert(io.open("../data/new_ctrls.dat", "r"))

    local new_ctrls = {}
    for line in file:lines() do
        local key, val = line:match("^(%w+)%=(%d)$")
        if key and val then
            new_ctrls[key] = (val == "1")
        end
    end

    file:close()
	joypad.set(new_ctrls)
end

function m.sendCurrentFrame(frame)
	local file = io.open("../data/cur_frame.dat", "wb")
	if not file then return end

	file:write("256,192\n")
	file:write(frame)

	file:close()
end

return m