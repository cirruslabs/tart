def test_create_macos(tart):
    # Create a macOS VM
    tart.run(["create", "--from-ipsw", "latest", "macos-vm"])

    # Ensure that the VM was created
    stdout, _ = tart.run(["list", "--source", "local", "--quiet"])
    assert stdout == "macos-vm\n"


def test_create_linux(tart):
    # Create a Linux VM
    tart.run(["create", "--linux", "linux-vm"])

    # Ensure that the VM was created
    stdout, _ = tart.run(["list", "--source", "local", "--quiet"])
    assert stdout == "linux-vm\n"
