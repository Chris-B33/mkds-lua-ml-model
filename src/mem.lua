local m = {}

function m.get_current_speed()
    speedAddr = 0x0217AD30
    return memory.readwordsigned(speedAddr)
end

function m.get_current_xpos()
    xposAddr = 0x0236284A
    return memory.readwordsigned(xposAddr)
end

function m.get_current_ypos()
    yposAddr = 0x0217B502
    return memory.readwordsigned(yposAddr)
end

function m.get_current_angle()
    angleAddr = 0x021704F0
    return memory.readwordsigned(angleAddr)
end

return m