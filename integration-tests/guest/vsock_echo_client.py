#!/usr/bin/env python3
import socket
import platform

PORT = 9999

if platform.system() == "Linux":
    FAMILY = socket.AF_VSOCK
    CID = socket.VMADDR_CID_HOST
elif platform.system() == "Darwin":
    FAMILY = 40
    CID = 2
else:
	raise Exception("Unsupported platform: {0}".format(platform.system()))

def sock_send(conn, message):
    length = len(message).to_bytes(8, "big")

    print("Send message length: {0}".format(len(message)))

    conn.sendall(length)
    conn.sendall(message)

def sock_read(conn):
    data = conn.recv(8)
    length = int.from_bytes(data, byteorder='big')

    print("Expected message length: {0}".format(length))

    response = bytearray()

    while length > 0:
        data = conn.recv(8192)
        length -= len(data)
        response.extend(data)

    with open("received.txt", "w") as text_file:
        text_file.write(response.decode())

    return response

conn = socket.socket(FAMILY, socket.SOCK_STREAM)
conn.settimeout(120) # 2 minutes for debugging
conn.connect((CID, PORT))

print("Connected.")

message = sock_read(conn)
sock_send(conn, message)

# Read end message
message = sock_read(conn)

conn.close()
print("Disconnected.")
