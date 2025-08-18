local m = {}

comm.socketServerSetTimeout(1000)

function m.receiveCtrls()
    local data = comm.socketServerResponse()

    local controls = {}
    for pair in string.gmatch(data, "([^;]+)") do
        local key, value = string.match(pair, "([^=]+)=([^=]+)")
        if key and value then
            controls[key] = tonumber(value) or value
        end
    end

    joypad.set(controls)
end

function m.sendStats(stats)
    local parts = {}
    for k, v in pairs(stats) do
        table.insert(parts, k .. "=" .. tostring(v))
    end
    local msg = table.concat(parts, ";") .. "\n"

    comm.socketServerSend(msg)
end

return m