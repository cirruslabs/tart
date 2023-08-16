def test_clone(tart):
    # Create a Linux VM (because we can create it really fast)
    tart.run(["create", "--linux", "debian"])

    # Clone the VM
    tart.run(["clone", "debian", "ubuntu"])

    # Ensure that we have now 2 VMs
    stdout, _, = tart.run(["list", "--source", "local", "--quiet"])
    assert stdout == "debian\nubuntu\n"
