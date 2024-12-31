import hashlib
import os

home_dir = os.path.expanduser("~")
unix_socket_path = os.path.join(home_dir, ".tart", "cache", "unix_socket.sock")
console_socket_path = os.path.join(home_dir, ".tart", "cache", "console.sock")
vm_name = "integration-test-devices"
curdir = os.path.abspath(os.path.dirname(__file__))

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

def sock_echo(conn, message):
	# Calculate sha256 hash
	content_sha256_hash = hashlib.sha256(message).hexdigest()
	# Send message
	sock_send(conn, message)
	# Read echo
	response = sock_read(conn)

	conn.sendall("end".encode(encoding='ascii'))

	response_sha256_hash = hashlib.sha256(response).hexdigest()

	if response_sha256_hash == content_sha256_hash:
		print("Data received successfully")
		return True
	else:
		print("Hashes are not equal")
		print("Expected: ", content_sha256_hash)
		print("Received: ", response_sha256_hash)
		return False

def readme_content():
	curdir = os.path.abspath(os.path.dirname(__file__))

	with open("{0}/../../README.md".format(curdir), 'r') as file:
		return file.read().encode()

def create_content():
	# Concat all files
	curdir = os.path.abspath(os.path.dirname(__file__))

	file_paths = [
		"{0}/../../README.md".format(curdir),
		"{0}/../../LICENSE".format(curdir),
		"{0}/../../PROFILING.md".format(curdir),
		"{0}/../../CONTRIBUTING.md".format(curdir),
	]

	content = bytearray()

	for file_path in file_paths:
		with open(file_path, 'r') as file:
			content.extend(file.read().encode())

	content.extend(content) # Double the content
	content.extend(content) # Quadruple the content
	content.extend(content) # Octuple the content

	with open("content.txt", "w") as text_file:
		text_file.write(content.decode())

	return content

