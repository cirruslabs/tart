import uuid

def test_create_macos(tart):
    macos = f"macos-{uuid.uuid4()}"
    # Create a macOS VM
    tart.run(["create", "--from-ipsw", "latest", macos])

    # Ensure that the VM was created
    stdout, _ = tart.run(["list", "--source", "local", "--quiet"])

    # Clean up the VM
    tart.run(["delete", macos])

    assert macos in stdout


def test_create_linux(tart):
    linux = f"linux-{uuid.uuid4()}"

    # Create a Linux VM
    tart.run(["create", "--linux", linux])

    # Ensure that the VM was created
    stdout, _ = tart.run(["list", "--source", "local", "--quiet"])
    # Clean up the VM
    tart.run(["delete", linux])

    assert linux in stdout
