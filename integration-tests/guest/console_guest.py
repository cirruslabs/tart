#!/usr/bin/env python3
import platform
import select
import os

# This script is a simple example of how to communicate with the console device in the guest.
def readmessage(fd):
	while True:
		rlist, _, _ = select.select([fd], [], [], 60)
		if fd in rlist:
			data = fd.read(8)
			if data:
				length = int.from_bytes(data, byteorder='big')

				print("Echo read message length: {0}".format(length))

				response = bytearray()

				while length > 0:
					data = fd.read(min(8192, length))
					if data:
						length -= len(data)
						response.extend(data)

				with open("received.txt", "w") as text_file:
					text_file.write(response.decode())

				return response
		else:
			raise Exception("Timeout while waiting for message")

def writemessage(fd, message):
	length = len(message).to_bytes(8, "big")

	print("Echo send message length: {0}".format(len(message)))

	fd.write(length)
	fd.write(message)

def echo_linux():
	console_path = "/dev/virtio-ports/tart-agent"
	with open("/tmp/vsock_echo.pid", "w") as pid_file:
		try:
			pid_file.write(str(os.getpid()))
			print("Reading pipe")

			with open(console_path, "rb") as pipe:
				message = readmessage(pipe)

			print("Writing pipe")

			with open(console_path, "wb") as pipe:
				writemessage(pipe, message)

			print("Acking pipe")

			with open(console_path, "rb") as pipe:
				# Read end message
				response = readmessage(pipe)
				print("Received data: {0}".format(response.decode()))
		except Exception as e:
			raise e
		finally:
			os.remove("/tmp/vsock_echo.pid")

def echo_darwin():
	console_path = "/dev/tty.tart-agent"
	with open("/tmp/vsock_echo.pid", "w") as pid_file:
		try:
			pid_file.write(str(os.getpid()))

			with open(console_path, "ab+") as pipe:
				print("Reading pipe")
				message = readmessage(pipe)

				print("Writing pipe")
				writemessage(pipe, message)
		
				print("Acking pipe")
				response = readmessage(pipe)

				print("Received data: {0}".format(response.decode()))
		except Exception as e:
			raise e
		finally:
			os.remove("/tmp/vsock_echo.pid")

if platform.system() == "Linux":
	echo_linux()
elif platform.system() == "Darwin":
	echo_darwin()
else:
	raise Exception("Unsupported platform: {0}".format(platform.system()))


