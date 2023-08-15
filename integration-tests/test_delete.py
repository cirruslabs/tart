def test_delete(tart):
    # Create a Linux VM (because we can create it really fast)
    tart.run(["create", "--linux", "debian"])

    # Ensure that the VM exists
    stdout, _, = tart.run(["list", "--source", "local", "--quiet"])
    assert stdout == "debian\n"

    # Delete the VM
    tart.run(["delete", "debian"])

    # Ensure that the VM was removed
    stdout, _, = tart.run(["list", "--source", "local", "--quiet"])
    assert stdout == ""
