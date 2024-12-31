#!/usr/bin/env python3

import os
import socket
from time import sleep


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

CID = socket.VMADDR_CID_HOST
PORT = 9999

conn = socket.socket(socket.AF_VSOCK, socket.SOCK_STREAM)
conn.settimeout(120) # 2 minutes for debugging
conn.connect((CID, PORT))

print("Connected.")

message = sock_read(conn)
sock_send(conn, message)

conn.recv(3)

conn.close()
print("Disconnected.")
