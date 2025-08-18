import subprocess

def open_rom(emu_path, rom_path, socket_host, socket_port) -> None:
    print(f"Opening EmuHawk:\nPath: {emu_path}'\nROM: {rom_path}\nHost: {socket_host}\nPort: {socket_port}")

    subprocess.Popen([
        emu_path,
        #f"--rom='{rom_path}'",
        f"--socket_ip={socket_host}",
        f"--socket_port={socket_port}"
    ])

def read_stats(file) -> dict:
    cur_stats_file = open(file, "r")

    cur_stats = {}
    try:
        for line in cur_stats_file.readlines():
            key, value = line.strip("\n").split("=")
            cur_stats[key] = float(value)
    except:
        cur_stats = None

    cur_stats_file.close()
    return cur_stats


def write_ctrls(file, new_ctrls: dict) -> None:
    new_ctrls_file = open(file, "w+")

    for key, value in new_ctrls.items():
        new_ctrls_file.write(f"{key}={value}\n")

    new_ctrls_file.close()