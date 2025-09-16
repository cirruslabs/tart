import base64
import json
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
        
    @pytest.mark.dependency()
    @pytest.mark.parametrize("docker_registry_authenticated", [("user1", "pass1")], indirect=True)
    def test_authenticated_push_from_env_config(self, tart, vm_with_random_disk, docker_registry_authenticated):
        with tempfile.NamedTemporaryFile(delete=False) as tf:
            tf.write(_docker_credentials_store(docker_registry_authenticated.remote_host(), "user1", "pass1"))
            tf.close()
        tart.run(["push", "--insecure", vm_with_random_disk, docker_registry_authenticated.remote_name(vm_with_random_disk)], env = { "TART_DOCKER_CONFIG": tf.name })

    @pytest.mark.dependency()
    @pytest.mark.parametrize("docker_registry_authenticated", [("user1", "pass1")], indirect=True)
    def test_authenticated_push_from_docker_config(self, tart, vm_with_random_disk, docker_registry_authenticated):
        with tempfile.NamedTemporaryFile(delete=False) as tf:
            tf.write(_docker_credentials_store(docker_registry_authenticated.remote_host(), "user1", "pass1"))
            tf.close()
            if not os.path.exists(os.path.expanduser("~/.docker")):
                os.mkdir(os.path.expanduser("~/.docker"))
            os.rename(tf.name, os.path.expanduser("~/.docker/config.json"))

        tart.run(["push", "--insecure", vm_with_random_disk, docker_registry_authenticated.remote_name(vm_with_random_disk)])

    @pytest.mark.dependency()
    @pytest.mark.parametrize("docker_registry_authenticated", [("user1", "pass1")], indirect=True)
    def test_authenticated_push_env_path_precedence(self, tart, vm_with_random_disk, docker_registry_authenticated):
        with tempfile.NamedTemporaryFile(delete=False) as tf:
            tf.write(_docker_credentials_store(docker_registry_authenticated.remote_host(), "user1", "pass1"))
            tf.close()

        with tempfile.NamedTemporaryFile(delete=False) as tf2:
            tf2.write(_docker_credentials_store(docker_registry_authenticated.remote_host(), "notuser", "notpassword"))
            tf2.close()
            if not os.path.exists(os.path.expanduser("~/.docker")):
                os.mkdir(os.path.expanduser("~/.docker"))
            os.rename(tf2.name, os.path.expanduser("~/.docker/config.json"))
            
        tart.run(["push", "--insecure", vm_with_random_disk, docker_registry_authenticated.remote_name(vm_with_random_disk)], env = { "TART_DOCKER_CONFIG": tf.name })

    @pytest.mark.dependency()
    @pytest.mark.parametrize("docker_registry_authenticated", [("user1", "pass1")], indirect=True)
    def test_authenticated_push_env_credentials_precedence(self, tart, vm_with_random_disk, docker_registry_authenticated):
        with tempfile.NamedTemporaryFile(delete=False) as tf:
            tf.write(_docker_credentials_store(docker_registry_authenticated.remote_host(), "notuser", "notpassword"))
            tf.close()

        env = {
            "TART_REGISTRY_USERNAME": "user1",
            "TART_REGISTRY_PASSWORD": "pass1",
            "TART_DOCKER_CONFIG": tf.name
        }
        tart.run(["push", "--insecure", vm_with_random_disk, docker_registry_authenticated.remote_name(vm_with_random_disk)], env)

    @pytest.mark.dependency()
    @pytest.mark.parametrize("docker_registry_authenticated", [("user1", "pass1")], indirect=True)
    def test_authenticated_push_invalid_env_path_error(self, tart, vm_with_random_disk, docker_registry_authenticated):
        env = { "TART_DOCKER_CONFIG": "/temp/this-file-does-not-exist" }

        _, stderr, returncode = tart.run(
            ["push", "--insecure", vm_with_random_disk, docker_registry_authenticated.remote_name(vm_with_random_disk)],
            env,
            raise_on_nonzero_returncode=False
        )

        expected_error = f"Registry authentication failed. Could not find docker configuration at '/temp/this-file-does-not-exist'."

        assert returncode == 1, f"Tart should fail with exit code 1 but failed with {returncode}."
        assert expected_error in stderr, f"Expected error '{expected_error}' not found in stderr: {stderr}"

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

def _docker_credentials_store(host, user, password):
    # Encode "username:password" in Base64
    auth_string = f"{user}:{password}"
    auth_b64 = base64.b64encode(auth_string.encode()).decode()

    # Create JSON structure
    docker_auth = {
        "auths": {
            host: {
                "auth": auth_b64
            }
        }
    }

    # Convert dictionary to JSON
    return json.dumps(docker_auth).encode()
