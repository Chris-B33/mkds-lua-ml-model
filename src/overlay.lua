local mem = require("mem")

local m = {}

function m.show_overlay()
    gui.text(1, -10, "Speed:" .. mem.get_current_speed())
    gui.text(1, -25, "X-Pos:" .. mem.get_current_xpos())
    gui.text(1, -40, "Y-Pos:" .. mem.get_current_ypos())
    gui.text(1, -55, "Angle:" .. mem.get_current_angle())
end

return m