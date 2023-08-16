def test_rename(tart):
    # Create a Linux VM (because we can create it really fast)
    tart.run(["create", "--linux", "debian"])

    # Rename that VM
    tart.run(["rename", "debian", "ubuntu"])

    # Ensure that the VM is now named "ubuntu"
    stdout, _, = tart.run(["list", "--source", "local", "--quiet"])
    assert stdout == "ubuntu\n"
