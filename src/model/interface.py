import subprocess

def open_rom(emu_path, socket_host, socket_port) -> None:
    print(f"Opening EmuHawk:\nPath: {emu_path}'\nHost: {socket_host}\nPort: {socket_port}")

    subprocess.Popen([
        emu_path,
        f"--socket_ip={socket_host}",
        f"--socket_port={socket_port}"
    ])