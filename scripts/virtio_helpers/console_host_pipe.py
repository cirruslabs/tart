#!/usr/bin/env python3

import logging
import os
from threading import Thread
from time import sleep

import common
import virtio

import tart

# This script is a full example of how to communicate with the socket device from the host to the guest via a pipe.
# The option for Tart: --vsock=fd://fd_input,fd_output:9999
curdir = os.path.abspath(os.path.dirname(__file__))

def console_pipe(tart):
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
		tart_run_process, ip = common.create_vm(tart,
																		 console_argument="--console=fd://{0},{1}".format(vm_read_fd, vm_write_fd),
																		 pass_fds=(vm_read_fd, vm_write_fd))

		common.scp_put(ip, "{0}/../../integration-tests/guest/console_guest.py".format(virtio.curdir), "/home/admin/echo.py")
		
		# Run guest_echo in a separate thread
		echo_thread = Thread(target=common.guest_echo, args=(5, ip))
		echo_thread.start()

		sleep(10)

		# Send the content
		ok = common.echo_message(host_in_fd, host_out_fd, virtio.create_content())

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

		common.cleanup(tart, ip, tart_run_process)

console_pipe(tart.Tart())
