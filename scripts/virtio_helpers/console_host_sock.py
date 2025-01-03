#!/usr/bin/env python3

import hashlib
import os
import socket

import virtio

# This script is a simple example of how to communicate with the console device from the host to the guest with an unix socket.

# Connect to the VM over vsock
client_socket = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
client_socket.connect(virtio.tart_agent_path)
client_socket.settimeout(120) # 2 minutes for debugging

# Echo
virtio.sock_echo(client_socket, virtio.create_content())

client_socket.close()
