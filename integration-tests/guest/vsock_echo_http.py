#!/usr/bin/env python3
import http.server
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

class VSockHttpServer(http.server.HTTPServer):
	def server_bind(self):
		self.socket = socket.socket(FAMILY, socket.SOCK_STREAM)
		self.socket.bind((CID, PORT))
		self.server_address = self.socket.getsockname()

class VSockHttpHandler(http.server.BaseHTTPRequestHandler):
	def do_POST(self):
		content_length = int(self.headers['Content-Length'])
		post_data = self.rfile.read(content_length)
		self.send_response(200)
		self.send_header('Content-type', 'text/plain')
		self.end_headers()
		self.wfile.write(post_data)

def run_http_server():
	httpd = VSockHttpServer(("", PORT), VSockHttpHandler)
	print("Serving HTTP on vsock port {0}".format(PORT))
	httpd.serve_forever()


with open("/tmp/vsock_echo.pid", "w") as pid_file:
	try:
		pid_file.write(str(os.getpid()))
		run_http_server()
	except Exception as e:
		raise e
	finally:
		os.remove("/tmp/vsock_echo.pid")