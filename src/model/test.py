import socket
import time

HOST = "127.0.0.1"
PORT = 9999

with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
    s.bind((HOST, PORT))
    s.listen(1)
    print("Waiting for Lua...")
    conn, addr = s.accept()
    with conn:
        print("Connected by", addr)
        msg = "DAKCJEJFHSJ.MCOAF.R,SJEA]DX'F[ CGDKVR;SEOXDZCFJVBUNHDXRSOEIA\;LKSIDK8XZUR9KE\W0LDPFA'.SCGX,DJVITLEORCE\XA[W/AEZPCS.K;XODJTOIHVEYS9PLA0RD-;X]D[/F\KSDJLSCPFOEA\XWDDWAFSDZXGCHVJBKLN;KJKHGFDSAFKHJL[]]]"
        msg = f"{len(msg)} {msg}"
        conn.sendall(msg.encode("utf-8"))
        while True:
            data = conn.recv(1024)
            if data:
                print("Python received:", data.decode().strip())

            # send a number to Lua
            conn.sendall(msg.encode("utf-8"))
            print("Python sent:", msg.strip())