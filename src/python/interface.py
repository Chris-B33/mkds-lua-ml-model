import subprocess

def open_rom(emu_path, rom_path) -> None:
    subprocess.Popen([
        emu_path,
        f'--rom="{rom_path}"'
    ])

def read_cur_stats() -> dict:
    cur_ctrls_bin = open("../../data/cur_stats.dat", "rb")

    cur_ctrls = {}
    for line in cur_ctrls_bin.readlines():
        key, value = line.strip("\n").split("=")
        cur_ctrls[key] = str(value)

    cur_ctrls_bin.close()
    return cur_ctrls


def write_new_ctrls(new_ctrls: dict) -> None:
    new_ctrls_bin = open("../../data/new_ctrls.dat", "w+")

    for key, value in new_ctrls.items():
        new_ctrls_bin.write(f"{key}={value}\n")

    new_ctrls_bin.close()