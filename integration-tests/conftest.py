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
