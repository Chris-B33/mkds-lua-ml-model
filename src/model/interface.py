import subprocess

def open_rom(emu_path, rom_path) -> None:
    subprocess.Popen([
        emu_path,
        f'--rom="{rom_path}"'
    ])

def read_stats(file) -> dict:
    cur_stats_file = open(file, "r")

    cur_stats = {}
    for line in cur_stats_file.readlines():
        key, value = line.strip("\n").split("=")
        cur_stats[key] = float(value)

    cur_stats_file.close()
    return cur_stats


def write_ctrls(file, new_ctrls: dict) -> None:
    new_ctrls_file = open(file, "w+")

    for key, value in new_ctrls.items():
        new_ctrls_file.write(f"{key}={value}\n")

    new_ctrls_file.close()