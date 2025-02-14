import pytest

from tart import Tart
from docker_registry import DockerRegistry


@pytest.fixture(scope="class")
def tart():
    with Tart() as tart:
        yield tart


@pytest.fixture(scope="class")
def docker_registry():
    with DockerRegistry() as docker_registry:
        yield docker_registry

@pytest.fixture(scope="function")
def docker_registry_authenticated(request):
    """
    Provides an authenticated Docker registry where username/password
    can be passed dynamically via the test case.
    
    Usage:
      - Add `docker_registry_authenticated` as a test argument.
      - Pass `request.param = (username, password)` from the test.
    """
    credentials = request.param if hasattr(request, "param") else ("testuser", "testpassword")

    with DockerRegistry(credentials=credentials) as docker_registry:
        yield docker_registry