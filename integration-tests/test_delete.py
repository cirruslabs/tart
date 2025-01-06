import uuid

def test_delete(tart):
    debian = f"debian-{uuid.uuid4()}"

    # Create a Linux VM (because we can create it really fast)
    tart.run(["create", "--linux", debian])

    # Ensure that the VM exists
    stdout, _, = tart.run(["list", "--source", "local", "--quiet"])
    assert debian in stdout

    # Delete the VM
    tart.run(["delete", debian])

    # Ensure that the VM was removed
    stdout, _, = tart.run(["list", "--source", "local", "--quiet"])

    assert debian not in stdout
