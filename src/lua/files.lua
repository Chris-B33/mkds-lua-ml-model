local m = {}

function m.sendStats(stats)
	if not stats then return end
	local f = assert(io.open("../../data/cur_stats.dat", "w+"))
	local buffer = ""

	for stat, value in pairs(stats) do
		buffer = buffer .. stat .. "=" .. tostring(value) .. "\n"
	end

	f:write(buffer)
	f:close()
end

function m.receiveCtrls()
	local file = assert(io.open("../../data/new_ctrls.dat", "r"))

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

return m