#!/usr/bin/env python3

import hashlib
import os
import socket

import virtio

# This script is a simple example of how to communicate with the socket device from the host to the guest.
# The option for Tart: --vsock=bind://vsock:9999${HOME}/.tart/noble-cloud-image.sock


# Connect to the VM over vsock
client_socket = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
client_socket.connect(virtio.unix_socket_path)
client_socket.settimeout(120) # 2 minutes for debugging

# Echo
virtio.sock_echo(client_socket, virtio.create_content())
#virtio.sock_echo(client_socket, b"Hello, world!")

client_socket.close()