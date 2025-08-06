import os
import struct
import subprocess
import threading
import numpy as np

EMU_PATH = "./EmuHawk.exe"
LUA_SCRIPT_PATH = os.path.abspath(r"mkds-lua-ml-model/src/MKDS Info.lua")
ROM_PATH = "ROMs/Mario Kart DS (USA, Australia) (En,Fr,De,Es,It).nds"

def open_rom():
    subprocess.Popen(
        [
            EMU_PATH,
            f'--rom="{ROM_PATH}"'
        ]
    )

def get_cur_frame():
    f = open("mkds-lua-ml-model/data/cur_frame.dat", "r")
    width, height = struct.unpack('<HH', f.read(4))
    pixel_data = np.frombuffer(f.read(width * height * 4), dtype=np.uint8).reshape((height, width, 4))
    return pixel_data

def get_cur_stats_and_ctrls() -> dict:
    cur_ctrls_bin = open("mkds-lua-ml-model/data/cur_stats_and_ctrls.dat", "rb")

    cur_ctrls = {}
    for line in cur_ctrls_bin.readlines():
        key, value = line.strip("\n").split("=")
        cur_ctrls[key] = str(value)

    cur_ctrls_bin.close()
    return cur_ctrls

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

def write_new_ctrls(new_ctrls: dict) -> None:
    new_ctrls_bin = open("mkds-lua-ml-model/data/new_ctrls.dat", "w+")

    for key, value in new_ctrls.items():
        new_ctrls_bin.write(f"{key}={value}\n")

    new_ctrls_bin.close()

def sendAndReceive():
    while True:
        get_cur_stats_and_ctrls()
        get_cur_frame()
        write_new_ctrls(new_ctrls)

if __name__ == "__main__":
    thread = threading.Thread(target=sendAndReceive)
    thread.start()