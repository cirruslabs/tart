import hashlib
import os
import select
from threading import Thread
from time import sleep

from paramiko import AutoAddPolicy, SSHClient
from scp import SCPClient

import tart

# This script is a full example of how to communicate with the socket device from the host to the guest via a pipe.
# The option for Tart: --vsock=fd://fd_input,fd_output:9999
unix_socket_path = os.path.join(os.path.expanduser("~"), ".tart", "cache", "unix_socket.sock")
console_socket_path = os.path.join(os.path.expanduser("~"), ".tart", "cache", "console.sock")
vm_name = "integration-test-devices"
content = "Hello, world!"
curdir = os.path.abspath(os.path.dirname(__file__))

def ssh_command(ip, command):
	client = SSHClient()
	client.set_missing_host_key_policy(AutoAddPolicy)
	client.connect(ip, username="admin", password="admin", timeout=120)

	try:
		_, stdout, _ = client.exec_command(command + " 2>&1 | tee output.log")
		print(stdout.read().decode())
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

      print("Message length: {0}".format(length))

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

  print("Send message length: {0}".format(len(message)))

  os.write(fd, length)
  os.write(fd, message)

def echo_message(fd_in, fd_out, message):
  content_sha256_hash = hashlib.sha256(message).hexdigest()
  # Send message
  write_message(fd_out, message)
  # Read echo
  response = read_message(fd_in)

  response_sha256_hash = hashlib.sha256(response).hexdigest()

  if response_sha256_hash == content_sha256_hash:
    print("Data received successfully")
    return True
  else:
    print("Hashes are not equal")
    print("Expected: ", content_sha256_hash)
    print("Received: ", response_sha256_hash)
    return False

def create_vm(tart, vsock_argument, pass_fds=()):
  # Instantiate a VM with admin:admin SSH access
  stdout, _, = tart.run(["list", "--source", "local", "--quiet"])
  if vm_name in stdout:
    print(f"VM {vm_name} already exists, deleting it.")
    try:
      tart.run(["stop", vm_name])
    except Exception:
      pass
    tart.run(["delete", vm_name])

  tart.run(["clone", "ghcr.io/cirruslabs/ubuntu:latest", vm_name])
  tart.run(["set", vm_name, "--disk-size", "20"])

  # Run the VM asynchronously
  tart_run_process = tart.run_async(["run", vm_name,
                  "--no-graphics",
                  "--no-audio",
                  "--console=unix:{0}".format(console_socket_path),
                  vsock_argument], pass_fds=pass_fds)
  
  # Obtain the VM's IP
  stdout, _ = tart.run(["ip", vm_name, "--wait", "120"])
  ip = stdout.strip()

  # Repeat until the VM is reachable via SSH
  for _ in range(120):
    try:
      client = SSHClient()
      client.set_missing_host_key_policy(AutoAddPolicy)
      client.connect(ip, username="admin", password="admin", timeout=120)
      print("Connected to the VM via SSH")
      break
    except Exception:
      sleep(1)
  else:
    raise Exception("Unable to connect to the VM via SSH")

  print("vm created")

  scp_put(ip, "{0}/virtio.py".format(curdir), "/home/admin/virtio.py")
  scp_put(ip, "{0}/virtio_guest_client_echo.py".format(curdir), "/home/admin/echo.py")

  return tart_run_process, ip

def cleanup(tart, ip, tart_run_process):
  # Shutdown the VM
  if ip:
    print("Shutting down the VM")
    ssh_command(ip, "sudo shutdown -h now")
    if tart_run_process:
      tart_run_process.wait()

  # Delete the VM
  print("Deleting the VM")
  tart.run(["delete", vm_name])

def guest_echo(delay, ip):
  if delay > 0:
    sleep(delay)
  print("Run guest echo")
  ssh_command(ip, "python3 echo.py")

def virtio_pipe(tart):
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
    tart_run_process, ip = create_vm(tart, "--vsock=fd://{0},{1}:9999".format(vm_read_fd, vm_write_fd), pass_fds=(vm_read_fd, vm_write_fd))
    # Run guest_echo in a separate thread
    echo_thread = Thread(target=guest_echo, args=(5, ip))
    echo_thread.start()

    sleep(10)

    print("Connected.")

    # Send the content
    ok = echo_message(host_in_fd, host_out_fd, content.encode())

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

    cleanup(tart, ip, tart_run_process)

virtio_pipe(tart.Tart())
