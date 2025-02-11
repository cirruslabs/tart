#!/bin/bash
max_loop=30

while [ ! -f /tmp/vsock_echo.pid ] && [ $max_loop -gt 0 ]; do
	sleep 1
	max_loop=$((max_loop - 1))
done

if [ $max_loop -eq 0 ]; then
	echo "Failed to find vsock_echo.pid"
	exit 1
fi