#!/usr/bin/env python3

import hashlib
import os
import socket

import virtio

# This script is a simple example of how to communicate with the socket device from the host to the guest.
# It must be running before the guest script is started.
# The option for Tart: --vsock=connect://vsock:9999${HOME}/.tart/noble-cloud-image.sock

# Connect to the VM over vsock
if os.path.exists(virtio.unix_socket_path):
	os.remove(virtio.unix_socket_path)

server = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
server.bind(virtio.unix_socket_path)
server.listen(1)

print("Waiting for incoming connection...")

while True:
	conn, _ = server.accept()
	print("Connected.")

	# echo
	virtio.sock_echo(conn, virtio.create_content())

	conn.close()

	print("Disconnected.")
