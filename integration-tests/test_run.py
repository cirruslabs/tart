import uuid

import pytest
from paramiko.client import SSHClient, AutoAddPolicy


@pytest.mark.parametrize("run_opts", [[], ["--no-graphics"]])
def test_run(tart, run_opts):
    vm_name = f"integration-test-run-{uuid.uuid4()}"

    # Instantiate a VM with admin:admin SSH access
    tart.run(["clone", "ghcr.io/cirruslabs/macos-sonoma-base:latest", vm_name])

    # Run the VM asynchronously
    tart_run_process = tart.run_async(["run", vm_name] + run_opts)

    # Obtain the VM's IP
    stdout, _ = tart.run(["ip", vm_name, "--wait", "120"])
    ip = stdout.strip()

    # Connect to the VM over SSH and shutdown it
    client = SSHClient()
    client.set_missing_host_key_policy(AutoAddPolicy)
    client.connect(ip, username="admin", password="admin")
    client.exec_command("sudo shutdown -h now")

    # Wait for the "tart run" to finish successfully
    tart_run_process.wait()
    assert tart_run_process.returncode == 0

    # Delete the VM
    _, _ = tart.run(["delete", vm_name])
