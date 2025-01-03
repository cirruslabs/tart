#!/usr/bin/env python3
import os
import select


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

print("Reading pipe")

with open("/dev/virtio-ports/tart-agent", "rb") as pipe:
	message = readmessage(pipe)
	pipe.close()

print("Writing pipe")

with open("/dev/virtio-ports/tart-agent", "wb") as pipe:
	writemessage(pipe, message)
	pipe.close()

print("Acking pipe")

with open("/dev/virtio-ports/tart-agent", "rb") as pipe:
	data = pipe.read(3)
	if data:
		print("Received data: {0}".format(data.decode()))
		pipe.close()
