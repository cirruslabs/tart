#!/usr/bin/env python3
import socket

import virtio

# This script is a simple example of how to communicate with the socket device from the guest when the guest is the client.
# The option for Tart: --vsock=connect://vsock:9999${env:HOME}/.tart/noble-cloud-image.sock or --vsock=fd://fd_input,fd_output:9999
CID = socket.VMADDR_CID_HOST
PORT = 9999

conn = socket.socket(socket.AF_VSOCK, socket.SOCK_STREAM)
conn.settimeout(120) # 2 minutes for debugging
conn.connect((CID, PORT))

print("Connected.")

message = virtio.sock_read(conn)
virtio.sock_send(conn, message)

conn.close()

print("Disconnected.")
