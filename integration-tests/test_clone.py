import uuid

def test_clone(tart):
    debian = f"debian-{uuid.uuid4()}"
    ubuntu = f"ubuntu-{uuid.uuid4()}"

    # Create a Linux VM (because we can create it really fast)
    tart.run(["create", "--linux", debian])

    # Clone the VM
    tart.run(["clone", debian, ubuntu])

    # Ensure that we have now 2 VMs
    stdout, _, = tart.run(["list", "--source", "local", "--quiet"])

    # Clean up the VM to free disk space
    tart.run(["delete", debian])
    tart.run(["delete", ubuntu])

    # Check that the list contains both VMs
    assert debian in stdout
    assert ubuntu in stdout
