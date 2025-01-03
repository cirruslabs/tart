import hashlib
import logging
import os
import select
import socket
from threading import Thread
from time import sleep

import pytest
from paramiko import AutoAddPolicy, SSHClient
from scp import SCPClient

log = logging.getLogger()
unix_socket_path = os.path.join(os.path.expanduser("~"), ".tart", "cache", "unix_socket.sock")
console_socket_path = os.path.join(os.path.expanduser("~"), ".tart", "cache", "console.sock")
vm_name = "integration-test-devices"
curdir = os.path.abspath(os.path.dirname(__file__))
file_paths = [
	"{0}/../README.md".format(curdir),
	"{0}/../LICENSE".format(curdir),
	"{0}/../PROFILING.md".format(curdir),
	"{0}/../CONTRIBUTING.md".format(curdir),
]

# Concat all files
content = bytearray()

for file_path in file_paths:
	with open(file_path, 'r') as file:
		content.extend(file.read().encode())

content.extend(content)
content.extend(content)
content.extend(content)
content.extend(content)

def ssh_command(ip, command):
	client = SSHClient()
	client.set_missing_host_key_policy(AutoAddPolicy)
	client.connect(ip, username="admin", password="admin", timeout=120)

	try:
		_, stdout, _ = client.exec_command(command + " 2>&1 | tee output.log")
		log.info(stdout.read().decode())
	except Exception as e:
		raise e
	finally:
		client.close()

def scp_put(ip, src, dst):

	client = SSHClient()
	client.set_missing_host_key_policy(AutoAddPolicy)
	client.connect(ip, username="admin", password="admin", timeout=120)
	
	try:
		sftp_client = client.open_sftp()
		sftp_client.put(src, dst)
		sftp_client.close()
	except Exception as e:
		raise e
	finally:
		client.close()

class GuestEcho(Thread):
	def __init__(self, ip, delay, echo_file):
		super().__init__()
		self.ip = ip
		self.delay = delay
		self.echo_file = echo_file

		scp_put(ip, echo_file, "/home/admin/echo.py")

	def run(self):
		# Run the echo client
		if self.delay > 0:
			sleep(self.delay)

		log.info("echo.py copied and running")

		ssh_command(self.ip, "sudo python3 echo.py")
		log.info("echo.py finished")
		
class TestVirtioDevices:
	def read_message(self, fd):
		while True:
			rlist, _, _ = select.select([fd], [], [], 60)
			if fd in rlist:
				data = os.read(fd, 8)
				length = int.from_bytes(data, byteorder='big')

				log.info("Message length: {0}".format(length))

				response = bytearray()

				while length > 0:
					data = os.read(fd, 8192)
					length -= len(data)
					response.extend(data)

				return response
			else:
				raise Exception("Timeout while waiting for message")

	def write_message(self, fd, message):
		length = len(message).to_bytes(8, "big")

		log.info("Send message length: {0}".format(len(message)))

		os.write(fd, length)
		os.write(fd, message)

	def echo_message(self, fd_in, fd_out, message):
		content_sha256_hash = hashlib.sha256(message).hexdigest()
		# Send message
		self.write_message(fd_out, message)
		# Read echo
		response = self.read_message(fd_in)

		os.write(fd_out, "end".encode(encoding='ascii'))

		response_sha256_hash = hashlib.sha256(response).hexdigest()

		if response_sha256_hash == content_sha256_hash:
			log.info("Data received successfully")
			result = True
		else:
			log.info("Hashes are not equal")
			log.info("Expected: ", content_sha256_hash)
			log.info("Received: ", response_sha256_hash)
			result = False

		return result

	def sock_send(self, conn, message):
		length = len(message).to_bytes(8, "big")

		log.info("Send message length: {0}".format(len(message)))

		conn.sendall(length)
		conn.sendall(message)

	def sock_read(self, conn):
		data = conn.recv(8)
		length = int.from_bytes(data, byteorder='big')

		log.info("Message length: {0}".format(length))

		response = bytearray()

		log.info("Waiting for message")

		while length > 0:
			data = conn.recv(8192)
			length -= len(data)
			response.extend(data)

		return response

	def sock_echo(self, conn, message):
		content_sha256_hash = hashlib.sha256(message).hexdigest()
		# Send message
		self.sock_send(conn, message)

		# Read echo
		response = self.sock_read(conn)

		conn.sendall("end".encode(encoding='ascii'))

		response_sha256_hash = hashlib.sha256(response).hexdigest()

		if response_sha256_hash == content_sha256_hash:
			log.info("Data received successfully")
			return True
		else:
			log.info("Hashes are not equal")
			log.info("Expected: ", content_sha256_hash)
			log.info("Received: ", response_sha256_hash)
			return False

	def cleanup(self, tart, conn, ip, tart_run_process, vmname=vm_name):
		if conn:
			conn.close()

		# Shutdown the VM
		if ip:
			log.info("Shutting down the VM")
			ssh_command(ip, "sudo shutdown -h now")
			if tart_run_process:
				tart_run_process.wait()

		# Delete the VM
		log.info("Deleting the VM")
		tart.run(["delete", vmname])

	def create_vm(self, tart, vsock_argument=None, console_argument=None, vmname=vm_name, pass_fds=()):
		# Instantiate a VM with admin:admin SSH access
		stdout, _, = tart.run(["list", "--source", "local", "--quiet"])
		if vmname in stdout:
			log.info(f"VM {vmname} already exists, deleting it.")
			try:
				tart.run(["stop", vmname])
			except Exception:
				pass
			tart.run(["delete", vmname])


		tart.run(["clone", "ghcr.io/cirruslabs/ubuntu:latest", vmname])
		tart.run(["set", vmname, "--disk-size", "20"])

		args = ["run", vmname, "--no-graphics", "--no-audio"]

		if vsock_argument:
			args.append(vsock_argument)

		if console_argument:
			args.append(console_argument)

		# Run the VM asynchronously
		tart_run_process = tart.run_async(args, pass_fds=pass_fds)

		# Obtain the VM's IP
		stdout, _ = tart.run(["ip", vmname, "--wait", "120"])
		ip = stdout.strip()

		# Repeat until the VM is reachable via SSH
		for _ in range(120):
			try:
				client = SSHClient()
				client.set_missing_host_key_policy(AutoAddPolicy)
				client.connect(ip, username="admin", password="admin", timeout=120)
				log.info("Connected to the VM via SSH")
				break
			except Exception:
				sleep(1)
		else:
			raise Exception("Unable to connect to the VM via SSH")

		log.info("vm created")

		return tart_run_process, ip

	@pytest.mark.dependency()
	def test_virtio_bind(self, tart):
		client_socket = None
		tart_run_process = None
		ip = None

		# Create a Linux VM
		tart_run_process, ip = self.create_vm(tart, vsock_argument="--vsock=bind://vsock:9999{0}".format(unix_socket_path))

		try:
			# Copy test file to the VM and run the echo client in background
			echo = GuestEcho(ip, 0, "{0}/guest/vsock_echo_server.py".format(curdir))
			echo.start()

			# Wait thread OS to start
			sleep(5)

			# Connect to the VM over vsock
			client_socket = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
			client_socket.settimeout(30)
			client_socket.connect(unix_socket_path)

			log.info("Connected to socket.")

			# Echo
			ok = self.sock_echo(client_socket, content)

			echo.join()
		
			log.info("Ending.")
			assert ok
		except Exception as e:
			raise e
		finally:
			self.cleanup(tart, client_socket, ip, tart_run_process)

	@pytest.mark.dependency()
	def test_virtio_connect(self, tart):
		server = None
		tart_run_process = None
		ip = None

		try:
			# Listen over unix socket before start VM
			os.remove(unix_socket_path)

			server = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
			server.bind(unix_socket_path)
			server.listen(1)

			# Create a Linux VM
			tart_run_process, ip = self.create_vm(tart, vsock_argument="--vsock=connect://vsock:9999{0}".format(unix_socket_path))

			# Copy test file to the VM and run the echo client in background
			echo = GuestEcho(ip, 5, "{0}/guest/vsock_echo_client.py".format(curdir))

			echo.start()

			conn, _ = server.accept()
			log.info("Connected.")

			# Send the content
			ok = self.sock_echo(conn, content)

			echo.join()

			assert ok
		except Exception as e:
			raise e
		finally:
			self.cleanup(tart, server, ip, tart_run_process)

	@pytest.mark.dependency()
	def test_virtio_pipe(self, tart):
		vm_read_fd = None
		host_out_fd = None
		host_in_fd = None
		vm_write_fd = None
		tart_run_process = None
		ip = None
		
		try:
			# Create named pipe for input
			vm_read_fd, host_out_fd = os.pipe()
			host_in_fd, vm_write_fd = os.pipe()
			
			# Create a Linux VM
			tart_run_process, ip = self.create_vm(tart, vsock_argument="--vsock=fd://{0},{1}:9999".format(vm_read_fd, vm_write_fd), pass_fds=(vm_read_fd, vm_write_fd))

			# Copy test file to the VM and run the echo client in background
			echo = GuestEcho(ip, 5, "{0}/guest/vsock_echo_client.py".format(curdir))

			echo.start()

			sleep(10)

			log.info("Connected.")

			# Send the content
			ok = self.echo_message(host_in_fd, host_out_fd, content)

			echo.join()

			assert ok
		except Exception as e:
			raise e
		finally:
			if host_out_fd:
				os.close(host_out_fd)
			if host_in_fd:
				os.close(host_in_fd)
			if vm_read_fd:
				os.close(vm_read_fd)
			if vm_write_fd:
				os.close(vm_write_fd)

			self.cleanup(tart, None, ip, tart_run_process)

	@pytest.mark.dependency()
	def test_console_socket(self, tart):
		client_socket = None
		tart_run_process = None
		ip = None

		# Create a Linux VM
		tart_run_process, ip = self.create_vm(tart, console_argument="--console=unix:{0}".format(console_socket_path))

		try:
			# Copy test file to the VM and run the echo client in background
			echo = GuestEcho(ip, 5, "{0}/guest/console_guest.py".format(curdir))
			echo.start()

			# Wait thread OS to start
			sleep(5)

			client_socket = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
			client_socket.settimeout(30)
			client_socket.connect(console_socket_path)

			log.info("Connected to socket.")

			# Send the content
			ok = self.sock_echo(client_socket, content)

			echo.join()

			assert ok
		except Exception as e:
			raise e
		finally:
			self.cleanup(tart, client_socket, ip, tart_run_process)

	@pytest.mark.dependency()
	def test_console_pipe(self, tart):
		vm_read_fd = None
		host_out_fd = None
		host_in_fd = None
		vm_write_fd = None
		tart_run_process = None
		ip = None

		try:
			# Create named pipe for input
			vm_read_fd, host_out_fd = os.pipe()
			host_in_fd, vm_write_fd = os.pipe()

			# Create a Linux VM
			tart_run_process, ip = self.create_vm(tart,
											console_argument="--console=fd://{0},{1}".format(vm_read_fd, vm_write_fd),
											pass_fds=(vm_read_fd, vm_write_fd))

			# Copy test file to the VM and run the echo client in background
			echo = GuestEcho(ip, 5, "{0}/guest/console_guest.py".format(curdir))
			echo.start()

			# Wait thread OS to start
			sleep(5)

			log.info("Connected.")

			# Send the content
			ok = self.echo_message(host_in_fd, host_out_fd, content)

			echo.join()

			assert ok
		except Exception as e:
			raise e
		finally:
			if host_out_fd:
				os.close(host_out_fd)
			if host_in_fd:
				os.close(host_in_fd)
			if vm_read_fd:
				os.close(vm_read_fd)
			if vm_write_fd:
				os.close(vm_write_fd)

			self.cleanup(tart, None, ip, tart_run_process)

