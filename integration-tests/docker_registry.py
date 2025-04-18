import requests
import tempfile
import subprocess
import bcrypt

from testcontainers.core.waiting_utils import wait_container_is_ready
from testcontainers.core.container import DockerContainer


class DockerRegistry(DockerContainer):
    _default_exposed_port = 5000

    def __init__(self, credentials: tuple[str, str] = None):
        """
        Initializes the DockerRegistry container.

        :param credentials: A tuple (username, password). If None, starts the registry without authentication.
        """
        super().__init__("registry:2")
        self.with_exposed_ports(self._default_exposed_port)
        self.credentials = credentials

        if credentials:
            self._configure_basic_auth(credentials)

    def _configure_basic_auth(self, credentials: tuple[str, str]):
        username, password = credentials

        # Set required environment variables for basic auth
        self.with_env("REGISTRY_AUTH", "htpasswd")
        self.with_env("REGISTRY_AUTH_HTPASSWD_PATH", "/auth/htpasswd")
        self.with_env("REGISTRY_AUTH_HTPASSWD_REALM", "Registry Realm")

        # Generate and mount the htpasswd file
        htpasswd_path = self._generate_htpasswd(username, password)
        self.with_volume_mapping(htpasswd_path, "/auth/htpasswd")

    def _generate_htpasswd(self, username: str, password: str) -> str:
        temp_file = tempfile.NamedTemporaryFile(delete=False)
        hashed = bcrypt.hashpw(password.encode('utf-8'), bcrypt.gensalt()).decode('utf-8')
        htpasswd_entry = f"{username}:{hashed}"
        temp_file.write(htpasswd_entry.encode('utf-8'))
        temp_file.close()
        return temp_file.name

    @wait_container_is_ready(requests.exceptions.ConnectionError)
    def remote_name(self, for_vm: str):
        exposed_port = self.get_exposed_port(self._default_exposed_port)

        requests.get(f"http://127.0.0.1:{exposed_port}/v2/")

        return f"127.0.0.1:{exposed_port}/tart/{for_vm}:latest"
    
    @wait_container_is_ready(requests.exceptions.ConnectionError)
    def remote_host(self):
        exposed_port = self.get_exposed_port(self._default_exposed_port)

        requests.get(f"http://127.0.0.1:{exposed_port}/v2/")

        return f"127.0.0.1:{exposed_port}"
