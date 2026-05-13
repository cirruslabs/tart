from testcontainers.core.container import DockerContainer
from testcontainers.core.wait_strategies import HttpWaitStrategy


class DockerRegistry(DockerContainer):
    _default_exposed_port = 5000

    def __init__(self):
        super().__init__("registry:2")
        self.with_exposed_ports(self._default_exposed_port)
        self.waiting_for(HttpWaitStrategy(self._default_exposed_port, "/v2/").for_status_code(200))

    def remote_name(self, for_vm: str):
        exposed_port = self.get_exposed_port(self._default_exposed_port)

        return f"127.0.0.1:{exposed_port}/tart/{for_vm}:latest"
