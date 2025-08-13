import os
import threading

from src.python.interface import open_rom, read_cur_stats, write_new_ctrls

EMU_PATH = "./EmuHawk.exe"
LUA_SCRIPT_PATH = os.path.abspath(r"mkds-lua-ml-model/src/MKDS Info.lua")
ROM_PATH = "ROMs/Mario Kart DS (USA, Australia) (En,Fr,De,Es,It).nds"

new_ctrls = {
    "Start":0,
    "Microphone":0,
    "R":0,
    "Mic Volume":100,
    "Touch X":255,
    "Down":0,
    "LidOpen":0,
    "Up":0,
    "LidClose":0,
    "L":0,
    "A":1,
    "B":0,
    "Touch":0,
    "GBA Light Sensor":0,
    "Left":0,
    "X":0,
    "Y":0,
    "Touch Y":0,
    "Power":0,
    "Select":0,
    "Right":0
}

def sendAndReceive():
    open_rom(EMU_PATH, ROM_PATH)
    while True:
        stats = read_cur_stats()

        write_new_ctrls(new_ctrls)

if __name__ == "__main__":
    thread = threading.Thread(target=sendAndReceive)
    thread.start()