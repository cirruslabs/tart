import hashlib
import http.client
import logging
import os
import select
import socket
import uuid
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

def log_info(msg):
  if "CIRRUS_WORKING_DIR" in os.environ:
    print(msg)
  else:
    log.info(msg)

def ssh_command(ip, command):
	client = SSHClient()
	client.set_missing_host_key_policy(AutoAddPolicy)
	client.connect(ip, username="admin", password="admin", timeout=120)

	try:
		_, stdout, _ = client.exec_command("source .profile ; " + command + " 2>&1 | tee output.log")
		log_info(stdout.read().decode())
	except Exception as e:
		raise e
	finally:
		client.close()

def bash(ip, command):
	client = SSHClient()
	client.set_missing_host_key_policy(AutoAddPolicy)
	client.connect(ip, username="admin", password="admin", timeout=120)

	try:
		_, stdout, _ = client.exec_command("bash -c '" + command + "' 2>&1")
		log_info(stdout.read().decode())
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


class TestVirtioDevices:
	interpreter = "python3"

	class GuestEcho(Thread):
		def __init__(self, ip, delay, echo_file, interpreter = "python3", need_sudo = False):
			super().__init__()
			self.ip = ip
			self.delay = delay
			self.interpreter = interpreter
			self.need_sudo = need_sudo

			scp_put(ip, os.path.join(os.path.dirname(echo_file), "waitpid.sh"), "waitpid.sh")

			# On Linux we use python3, on MacOS we use swift
			if interpreter == "python3":
				self.echo_file = echo_file + ".py"
				self.target = "echo.py"
				scp_put(ip, self.echo_file, self.target)
			elif interpreter == "swift":
				self.echo_file = echo_file + ".swift"
				self.target = "echo.swift"
				scp_put(ip, self.echo_file, self.target)
			else:
				self.echo_file = echo_file + ".go"
				self.target = "echo.go"
				self.interpreter = "go run"

				# Install golang on MacOS VM
				ssh_command(self.ip, "brew install golang")
				# Copy go files & prepare go mod
				scp_put(ip, self.echo_file, self.target)
				scp_put(ip, os.path.join(os.path.dirname(echo_file), "go.mod"), "go.mod")
				scp_put(ip, os.path.join(os.path.dirname(echo_file), "go.sum"), "go.sum")
				ssh_command(self.ip, "go mod tidy")

		def run(self):
			# Run the echo client
			if self.delay > 0:
				sleep(self.delay)

			log_info("{0} copied and running".format(self.target))

			if self.need_sudo:
				ssh_command(self.ip, "sudo {0} {1}".format(self.interpreter, self.target))
			else:
				ssh_command(self.ip, "{0} {1}".format(self.interpreter, self.target))
	
			log_info("{0} finished".format(self.target))

	def get_vm_name(self):
		#return vm_name + "-" + str(uuid.uuid4())
		return vm_name

	def read_message(self, fd):
		while True:
			rlist, _, _ = select.select([fd], [], [], 60)
			if fd in rlist:
				data = os.read(fd, 8)
				length = int.from_bytes(data, byteorder='big')

				log_info("Message length: {0}".format(length))

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

		log_info("Send message length: {0}".format(len(message)))

		os.write(fd, length)
		os.write(fd, message)

	def echo_message(self, fd_in, fd_out, message):
		# Send message
		self.write_message(fd_out, message)
		# Read echo
		response = self.read_message(fd_in)

		self.write_message(fd_out, "end".encode())

		return self.same_content(message, response)

	def sock_send(self, conn, message):
		length = len(message).to_bytes(8, "big")

		log_info("Send message length: {0}".format(len(message)))

		conn.sendall(length)
		conn.sendall(message)

	def sock_read(self, conn):
		data = conn.recv(8)
		length = int.from_bytes(data, byteorder='big')

		log_info("Message length: {0}".format(length))

		response = bytearray()

		log_info("Waiting for message")

		while length > 0:
			data = conn.recv(8192)
			length -= len(data)
			response.extend(data)

		return response

	def same_content(self, content, response):
		content_sha256_hash = hashlib.sha256(content).hexdigest()
		response_sha256_hash = hashlib.sha256(response).hexdigest()

		if response_sha256_hash == content_sha256_hash:
			log_info("Data received successfully")
			return True
		else:
			log_info("Hashes are not equal")
			log_info("Expected: ", content_sha256_hash)
			log_info("Received: ", response_sha256_hash)
			return False

	def sock_echo(self, conn, message):
		# Send message
		self.sock_send(conn, message)

		# Read echo
		response = self.sock_read(conn)

		self.sock_send(conn, "end".encode())

		return self.same_content(message, response)	

	def cleanup(self, tart, conn, ip, tart_run_process, vmname=vm_name):
		if conn:
			conn.close()

		# Shutdown the VM
		if ip:
			log_info("Shutting down the VM")
			ssh_command(ip, "sudo shutdown -h now")
			if tart_run_process:
				tart_run_process.wait()

		# Delete the VM
		log_info("Deleting the VM")
		tart.run(["delete", vmname])

	def create_vm(self, tart, image="ghcr.io/cirruslabs/ubuntu:latest", vsock_argument=None, console_argument=None, vmname=vm_name, diskSize=None, pass_fds=()):
		# Instantiate a VM with admin:admin SSH access
		stdout, _, = tart.run(["list", "--source", "local", "--quiet"])
		if vmname in stdout:
			log_info(f"VM {vmname} already exists, deleting it.")
			try:
				tart.run(["stop", vmname])
			except Exception:
				pass
			tart.run(["delete", vmname])


		tart.run(["clone", image, vmname])

		if diskSize:
			tart.run(["set", vmname, "--disk-size={0}".format(diskSize)])

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
				log_info("Connected to the VM via SSH")
				break
			except Exception:
				sleep(1)
		else:
			raise Exception("Unable to connect to the VM via SSH")

		log_info("vm created")

		return tart_run_process, ip

	def create_test_vm(self, tart, vsock_argument=None, console_argument=None, vmname=vm_name, pass_fds=()):
		return self.create_vm(tart, image="ghcr.io/cirruslabs/ubuntu:latest", vsock_argument=vsock_argument, console_argument=console_argument, vmname=vmname, pass_fds=pass_fds)

	def waitpidfile(self, ip):
		ssh_command(ip, "bash waitpid.sh")

	def do_test_virtio_bind(self, tart, interpreter="python3", cleanup=True):
		vmname = self.get_vm_name()
		client_socket = None
		tart_run_process = None
		ip = None

		# Create a Linux VM
		tart_run_process, ip = self.create_test_vm(tart, vsock_argument="--vsock=bind://vsock:9999{0}".format(unix_socket_path), vmname=vmname)

		try:
			# Copy test file to the VM and run the echo client in background
			echo = self.GuestEcho(ip, 0, "{0}/guest/vsock_echo_server".format(curdir), interpreter)
			echo.start()

			# Wait a bit thread OS to start
			self.waitpidfile(ip)

			log_info("Try to connected to guest.")

			client_socket = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
			client_socket.settimeout(30)
			client_socket.connect(unix_socket_path)

			log_info("Connected to socket.")

			# Echo
			ok = self.sock_echo(client_socket, content)

			echo.join()
		
			log_info("Ending.")
			assert ok
		except Exception as e:
			raise e
		finally:
			if cleanup:
				self.cleanup(tart, client_socket, ip, tart_run_process, vmname)

	def do_test_virtio_tcp(self, tart, interpreter="python3", cleanup=True):
		vmname = self.get_vm_name()
		client_socket = None
		tart_run_process = None
		ip = None

		# Create a Linux VM
		tart_run_process, ip = self.create_test_vm(tart, vsock_argument="--vsock=tcp://127.0.0.1:9999", vmname=vmname)

		try:
			# Copy test file to the VM and run the echo client in background
			echo = self.GuestEcho(ip, 0, "{0}/guest/vsock_echo_server".format(curdir), interpreter)
			echo.start()

			# Wait a bit thread OS to start
			self.waitpidfile(ip)

			client_socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
			client_socket.settimeout(30)
			client_socket.connect(("127.0.0.1", 9999))

			log_info("Connected to socket.")

			# Echo
			ok = self.sock_echo(client_socket, content)

			echo.join()
		
			log_info("Ending.")
			assert ok
		except Exception as e:
			raise e
		finally:
			if cleanup:
				self.cleanup(tart, client_socket, ip, tart_run_process, vmname)

	def do_test_virtio_http(self, tart, interpreter="python3", cleanup=True):
		vmname = self.get_vm_name()
		client_socket = None
		tart_run_process = None
		ip = None

		# Create a Linux VM
		tart_run_process, ip = self.create_test_vm(tart, vsock_argument="--vsock=tcp://127.0.0.1:9999", vmname=vmname)

		try:
			# Copy test file to the VM and run the echo client in background
			echo = self.GuestEcho(ip, 0, "{0}/guest/vsock_echo_http".format(curdir), interpreter)
			echo.start()

			# Wait thread OS to start
			sleep(5)

			log_info("Create http client")

			conn = http.client.HTTPConnection("localhost", 9999, timeout=30)

			# Echo
			conn.request("POST", "/", content)
			response = conn.getresponse()
			data = response.read()
			response.close()
		
			log_info("Ending.")
			assert self.same_content(content, data)
		except Exception as e:
			raise e
		finally:
			if cleanup:
				self.cleanup(tart, client_socket, ip, tart_run_process, vmname)

	def do_test_virtio_connect(self, tart, interpreter="python3", cleanup=True):
		vmname = self.get_vm_name()
		server = None
		tart_run_process = None
		ip = None

		try:
			if os.path.exists(unix_socket_path):
				os.remove(unix_socket_path)

			# Listen over unix socket before start VM
			server = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
			server.bind(unix_socket_path)
			server.listen(1)

			# Create a Linux VM
			tart_run_process, ip = self.create_test_vm(tart, vsock_argument="--vsock=connect://vsock:9999{0}".format(unix_socket_path), vmname=vmname)

			# Copy test file to the VM and run the echo client in background
			echo = self.GuestEcho(ip, 5, "{0}/guest/vsock_echo_client".format(curdir), interpreter)

			echo.start()

			conn, _ = server.accept()
			log_info("Connected.")

			# Send the content
			ok = self.sock_echo(conn, content)

			echo.join()

			assert ok
		except Exception as e:
			raise e
		finally:
			if cleanup:
				self.cleanup(tart, server, ip, tart_run_process, vmname)

	def do_test_virtio_pipe(self, tart, interpreter="python3", cleanup=True):
		vmname = self.get_vm_name()
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
			tart_run_process, ip = self.create_test_vm(tart, vsock_argument="--vsock=fd://{0},{1}:9999".format(vm_read_fd, vm_write_fd), pass_fds=(vm_read_fd, vm_write_fd), vmname=vmname)

			# Copy test file to the VM and run the echo client in background
			echo = self.GuestEcho(ip, 5, "{0}/guest/vsock_echo_client".format(curdir), interpreter)

			echo.start()

			sleep(10)

			log_info("Connected.")

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
			if cleanup:
				self.cleanup(tart, None, ip, tart_run_process, vmname)

	def do_test_console_socket(self, tart, interpreter="python3", cleanup=True):
		vmname = self.get_vm_name()
		client_socket = None
		tart_run_process = None
		ip = None

		# Create a Linux VM
		tart_run_process, ip = self.create_test_vm(tart, console_argument="--console=unix:{0}".format(console_socket_path), vmname=vmname)

		try:
			# Copy test file to the VM and run the echo client in background
			echo = self.GuestEcho(ip, 5, "{0}/guest/console_guest".format(curdir), interpreter, need_sudo=True)
			echo.start()

			# Wait thread OS to start
			self.waitpidfile(ip)

			client_socket = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
			client_socket.settimeout(30)
			client_socket.connect(console_socket_path)

			log_info("Connected to socket.")

			# Send the content
			ok = self.sock_echo(client_socket, content)

			echo.join()

			assert ok
		except Exception as e:
			raise e
		finally:
			if cleanup:
				self.cleanup(tart, client_socket, ip, tart_run_process, vmname)

	def do_test_console_pipe(self, tart, interpreter="python3", cleanup=True):
		vmname = self.get_vm_name()
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
			tart_run_process, ip = self.create_test_vm(tart,
											console_argument="--console=fd://{0},{1}".format(vm_read_fd, vm_write_fd),
											vmname=vmname,
											pass_fds=(vm_read_fd, vm_write_fd))

			# Copy test file to the VM and run the echo client in background
			echo = self.GuestEcho(ip, 5, "{0}/guest/console_guest".format(curdir), interpreter, need_sudo=True)
			echo.start()

			# Wait thread OS to start
			sleep(5)

			log_info("Connected.")

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
			if cleanup:
				self.cleanup(tart, None, ip, tart_run_process, vmname)
	
class TestVirtioDevicesOnLinux(TestVirtioDevices):
	def create_test_vm(self, tart, vsock_argument=None, console_argument=None, vmname=vm_name, pass_fds=()):
		return self.create_vm(tart, image="ghcr.io/cirruslabs/ubuntu:latest", vsock_argument=vsock_argument, console_argument=console_argument, vmname=vmname, diskSize=20, pass_fds=pass_fds)

	def test_virtio_bind(self, tart):
		self.do_test_virtio_bind(tart)

	def test_virtio_http(self, tart):
		self.do_test_virtio_http(tart)

	def test_virtio_tcp(self, tart):
		self.do_test_virtio_tcp(tart)

	def test_virtio_connect(self, tart):
		self.do_test_virtio_connect(tart)

	def test_virtio_pipe(self, tart):
		self.do_test_virtio_pipe(tart)

	def test_console_socket(self, tart):
		self.do_test_console_socket(tart)

	def test_console_pipe(self, tart):
		self.do_test_console_pipe(tart)

class TestVirtioDevicesOnMacOS(TestVirtioDevices):
	def create_test_vm(self, tart, vsock_argument=None, console_argument=None, vmname=vm_name, pass_fds=()):
		return self.create_vm(tart, "ghcr.io/cirruslabs/macos-sequoia-xcode:latest", vsock_argument=vsock_argument, console_argument=console_argument, vmname=vmname, pass_fds=pass_fds)

	def test_virtio_bind(self, tart):
		self.do_test_virtio_bind(tart, "swift")

	def test_virtio_http(self, tart):
		self.do_test_virtio_http(tart, "go")

	def test_virtio_tcp(self, tart):
		self.do_test_virtio_tcp(tart, "swift")

	def test_virtio_connect(self, tart):
		self.do_test_virtio_connect(tart, "swift")

	def test_virtio_pipe(self, tart):
		self.do_test_virtio_pipe(tart, "swift")

	def test_console_socket(self, tart):
		self.do_test_console_socket(tart)

	def test_console_pipe(self, tart):
		self.do_test_console_pipe(tart)

