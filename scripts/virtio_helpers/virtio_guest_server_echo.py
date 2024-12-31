#!/usr/bin/env python3
import socket

import virtio

# This script is a simple example of how to communicate with the socket device from the guest when the guest is the server.
# The option for Tart: --vsock=bind://vsock:9999${env:HOME}/.tart/noble-cloud-image.sock
CID = socket.VMADDR_CID_ANY
PORT = 9999

server = socket.socket(socket.AF_VSOCK, socket.SOCK_STREAM)
server.bind((CID, PORT))
server.listen(1)

print("Waiting for incoming connection...")

conn, _ = server.accept()

print("Connected.")

message = virtio.sock_read(conn)
virtio.sock_send(conn, message)

conn.recv(3)
conn.close()
server.close()

print("Disconnected.")
