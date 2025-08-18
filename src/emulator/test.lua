comm.socketServerSetTimeout(1000)

while true do
    local msg = "ORANGE"
    comm.socketServerSend(msg)
        
    local data = comm.socketServerResponse()
    emu.frameadvance()
end