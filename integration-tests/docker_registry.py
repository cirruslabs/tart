import requests

from testcontainers.core.waiting_utils import wait_container_is_ready
from testcontainers.core.container import DockerContainer


class DockerRegistry(DockerContainer):
    _default_exposed_port = 5000

    def __init__(self):
        super().__init__("registry:2")
        self.with_exposed_ports(self._default_exposed_port)

    @wait_container_is_ready(requests.exceptions.ConnectionError)
    def remote_name(self, for_vm: str):
        exposed_port = self.get_exposed_port(self._default_exposed_port)

        requests.get(f"http://127.0.0.1:{exposed_port}/v2/")

        return f"127.0.0.1:{exposed_port}/tart/{for_vm}:latest"
