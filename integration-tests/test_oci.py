import os
import tempfile
import timeit
import uuid

import bitmath
import pytest

amount_to_transfer = bitmath.GB(1)
minimal_speed_per_second = bitmath.Mb(100)


class TestOCI:
    @pytest.mark.dependency()
    def test_push_speed(self, tart, vm_with_random_disk, docker_registry):
        start = timeit.default_timer()
        tart.run(["push", "--insecure", vm_with_random_disk, docker_registry.remote_name(vm_with_random_disk)])
        stop = timeit.default_timer()

        actual_speed_per_second = self._calculate_speed_per_second(amount_to_transfer, stop - start)
        assert actual_speed_per_second > minimal_speed_per_second

    @pytest.mark.dependency(depends=["TestOCI::test_push_speed"])
    def test_pull_speed(self, tart, vm_with_random_disk, docker_registry):
        start = timeit.default_timer()
        tart.run(["pull", "--insecure", docker_registry.remote_name(vm_with_random_disk)])
        stop = timeit.default_timer()

        actual_speed_per_second = self._calculate_speed_per_second(amount_to_transfer, stop - start)
        assert actual_speed_per_second > minimal_speed_per_second

    @staticmethod
    def _calculate_speed_per_second(amount_transferred, time_taken):
        return (amount_transferred / time_taken).best_prefix(bitmath.SI)


@pytest.fixture(scope="class")
def vm_with_random_disk(tart):
    vm_name = str(uuid.uuid4())

    # Create a VM (Linux for speed's sake)
    tart.run(["create", "--linux", vm_name])

    # Populate VM's disk with "amount_to_transfer" of random bytes
    # to effectively disable Tart's OCI blob compression
    disk_path = os.path.join(tart.home(), "vms", vm_name, "disk.img")

    with tempfile.NamedTemporaryFile(delete=False) as tf:
        tf.write(os.urandom(amount_to_transfer.bytes))
        tf.close()
        os.rename(tf.name, disk_path)

    yield vm_name

    tart.run(["delete", vm_name])
