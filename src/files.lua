local m = {}

function m.file_exists(file)
  local f = io.open(file, "rb")
  if f then f:close() end
  return f ~= nil
end

function m.write_cur_frame()
    local top_screen_bounds = {0, -192, 256, 0};
    local buffer = {}

    for y = top_screen_bounds[2], top_screen_bounds[4] do
        for x = top_screen_bounds[1], top_screen_bounds[3] do
            local px = gui.getpixel(x, y)
            buffer[#buffer+1] = string.format("%d,%d,%d,%d\n", px.r, px.g, px.b, px.a)
        end
    end
    local frame_file = assert(io.open("../data/cur_frame.bin", "wb"))
    frame_file:write(table.concat(buffer))
    frame_file:close()
end

function m.write_cur_ctrls()
    local cur_ctrls = joypad.read();

    local file = assert(io.open("../data/cur_ctrls.bin", "w"))
    for key, value in pairs(cur_ctrls) do
        file:write(string.format("%s=%d\n", key, value and 1 or 0))
    end

    file:close()
end

function m.get_new_ctrls()
    local file = assert(io.open("../data/new_ctrls.bin", "r"))

    local new_ctrls = {}
    for line in file:lines() do
        local key, val = line:match("^(%w+)%=(%d)$")
        if key and val then
            new_ctrls[key] = (val == "1")
        end
    end

    file:close()

    return new_ctrls
end

return m