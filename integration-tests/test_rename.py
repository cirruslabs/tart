import uuid

def test_rename(tart):
    debian = f"debian-{uuid.uuid4()}"
    ubuntu = f"ubuntu-{uuid.uuid4()}"

    # Create a Linux VM (because we can create it really fast)
    tart.run(["create", "--linux", debian])

    # Rename that VM
    tart.run(["rename", debian, ubuntu])

    # Ensure that the VM is now named ubuntu
    stdout, _, = tart.run(["list", "--source", "local", "--quiet"])

    tart.run(["delete", ubuntu])

    assert ubuntu in stdout
