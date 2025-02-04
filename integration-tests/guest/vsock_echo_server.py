#!/usr/bin/env python3
import socket
import platform
import os

PORT = 9999

if platform.system() == "Linux":
	FAMILY = socket.AF_VSOCK
	CID = socket.VMADDR_CID_ANY
elif platform.system() == "Darwin":
	FAMILY = 40
	CID = -1
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

server = socket.socket(FAMILY, socket.SOCK_STREAM)
server.bind((CID, PORT))
server.listen(1)

print("Waiting for incoming connection...")

with open("/tmp/vsock_echo.pid", "w") as pid_file:
	pid_file.write(str(os.getpid()))

	try:
		conn, _ = server.accept()
		print("Connected.")

		message = sock_read(conn)
		sock_send(conn, message)

		# Read end message
		message = sock_read(conn)

		print("Disconnected.")
	except Exception as e:
		raise e
	finally:
		os.remove("/tmp/vsock_echo.pid")
		server.close()
