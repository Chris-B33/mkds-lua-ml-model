import os
import PIL
import time
import subprocess
import PIL.Image

DESMUME_PATH = r"./DeSmuME-VS2022-Release.exe"
LUA_SCRIPT_PATH = os.path.abspath(r"mkds-lua-ml-model/src/desmume_bridge.lua")
ROM_PATH = r"ROMs/Mario Kart DS (Europe) (En,Fr,De,Es,It).nds"

# Open game with script active
def open_rom():
    subprocess.Popen(
        [
            DESMUME_PATH, 
            #"--lua-script",
            #LUA_SCRIPT_PATH,
            ROM_PATH
        ], 
        cwd=os.getcwd()
    )

def get_cur_frame() -> PIL.Image:
    pass

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