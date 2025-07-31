import os
import PIL
import subprocess
import PIL.Image

EMU_PATH = "./EmuHawk.exe"
LUA_SCRIPT_PATH = os.path.abspath(r"mkds-lua-ml-model/src/MKDS Info.lua")
ROM_PATH = "ROMs/Mario Kart DS (USA, Australia) (En,Fr,De,Es,It).nds"

# Open game with script active
def open_rom():
    subprocess.Popen(
        [
            EMU_PATH,
            f'--rom="{ROM_PATH}"'
        ]
    )

def get_cur_frame() -> PIL.Image:
    cur_frame_bin = open("mkds-lua-ml-model/data/cur_frame.bin", "r")

    cur_frame_matx = []
    

    return 

def get_cur_ctrls() -> dict:
    cur_ctrls_bin = open("mkds-lua-ml-model/data/cur_ctrls.bin", "r")

    cur_ctrls = {}
    for line in cur_ctrls_bin.readlines():
        key, value = line.strip("\n").split("=")
        cur_ctrls[key] = int(value)

    cur_ctrls_bin.close()

    return cur_ctrls

def write_new_ctrls(new_ctrls: dict) -> None:
    new_ctrls_bin = open("mkds-lua-ml-model/data/new_ctrls.bin", "w+")

    for key, value in new_ctrls.items():
        new_ctrls_bin.write(f"{key}={value}\n")

    new_ctrls_bin.close()

open_rom()