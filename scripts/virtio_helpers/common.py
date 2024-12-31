import hashlib
import logging
import os
import select
from time import sleep

import virtio
from paramiko import AutoAddPolicy, SSHClient
from scp import SCPClient

import tart

FORMAT = "{asctime} - {levelname} - {name}:{message}"
logging.basicConfig(filename='/dev/stdout', format=FORMAT, datefmt="%Y-%m-%d %H:%M", style="{", level=logging.INFO)

log = logging.getLogger(__name__)

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

def read_message(fd):
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

def write_message(fd, message):
	length = len(message).to_bytes(8, "big")

	log.info("Send message length: {0}".format(len(message)))

	os.write(fd, length)
	os.write(fd, message)

def echo_message(fd_in, fd_out, message):
	content_sha256_hash = hashlib.sha256(message).hexdigest()
	# Send message
	write_message(fd_out, message)
	# Read echo
	response = read_message(fd_in)

	os.write(fd_out, "end".encode(encoding='ascii'))
	
	response_sha256_hash = hashlib.sha256(response).hexdigest()

	if response_sha256_hash == content_sha256_hash:
		log.info("Data received successfully")
		return True
	else:
		log.info("Hashes are not equal")
		log.info("Expected: ", content_sha256_hash)
		log.info("Received: ", response_sha256_hash)
		return False

def create_vm(tart, vsock_argument=None, console_argument=None, vmname=virtio.vm_name, pass_fds=()):
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

def cleanup(tart, ip=None, tart_run_process=None, vmname=virtio.vm_name):
	# Shutdown the VM
	if ip:
		log.info("Shutting down the VM")
		ssh_command(ip, "sudo shutdown -h now")
		if tart_run_process:
			tart_run_process.wait()

	# Delete the VM
	log.info("Deleting the VM")
	tart.run(["delete", vmname])

def guest_echo(delay, ip):
	if delay > 0:
		sleep(delay)
	log.info("Run guest echo")
	ssh_command(ip, "sudo python3 echo.py")

