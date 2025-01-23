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

@pytest.fixture(autouse=True)
def only_sequoia(request):
    if request.node.get_closest_marker('only_sequoia'):
        arg = request.node.get_closest_marker('only_sequoia').args[0]
        if not "sequoia" in arg:
            pytest.skip('skipped on image: {0}'.format(arg))   

def pytest_configure(config):
  config.addinivalue_line("markers", "only_sequoia(image): skip test for the given macos image not sequoia")