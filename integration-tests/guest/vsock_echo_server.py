#!/usr/bin/env python3
import socket


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

CID = socket.VMADDR_CID_ANY
PORT = 9999

server = socket.socket(socket.AF_VSOCK, socket.SOCK_STREAM)
server.bind((CID, PORT))
server.listen(1)

print("Waiting for incoming connection...")

conn, _ = server.accept()
print("Connected.")

message = sock_read(conn)
sock_send(conn, message)

server.close()

print("Disconnected.")
