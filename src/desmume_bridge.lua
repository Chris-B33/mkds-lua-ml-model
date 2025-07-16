local files = require("files")
local overlay = require("overlay")

gui.register(overlay.show_overlay)

while true do
    emu.frameadvance();

    -- Expose cur ctrls and frame
    files.write_cur_ctrls()
    files.write_cur_frame()

    -- Wait for new_ctrls.bin
    --[[local framecount = emu.framecount()
    while (file_exists("../data/new_ctrls.bin") == false) do
        emu.frameadvance()
        framecount = framecount + 1
        if framecount % 100 == 0 then
            print("Waiting for new ctrls...")
        end
    end

    -- Set new ctrls
    joypad.set(get_new_ctrls())
    os.remove("data/new_ctrls.bin")]]
end