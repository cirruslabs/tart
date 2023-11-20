---
hide:
  - navigation
---

Try running a Tart VM on your Apple Silicon device running macOS 13.0 (Ventura) or later (will download a 25 GB image):

```bash
brew install cirruslabs/cli/tart
tart clone ghcr.io/cirruslabs/macos-sonoma-base:latest sonoma-base
tart run sonoma-base
```

??? info "Manual installation from a release archive"
    It's also possible to manually install `tart` binary from the latest released archive:
    
    ```bash
    curl -LO https://github.com/cirruslabs/tart/releases/latest/download/tart.tar.gz
    tar -xzvf tart.tar.gz
    ./tart.app/Contents/MacOS/tart clone ghcr.io/cirruslabs/macos-sonoma-base:latest sonoma-base
    ./tart.app/Contents/MacOS/tart run sonoma-base
    ```

    Please note that `./tart.app/Contents/MacOS/tart` binary is required to be used in order to trick macOS
    to pick `tart.app/Contents/embedded.provisionprofile` for elevated privileges that Tart needs.

<p align="center">
  <img src="https://github.com/cirruslabs/tart/raw/main/Resources/TartScreenshot.png"/>
</p>

## SSH access

If the guest VM is running and configured to accept incoming SSH connections you can conveniently connect to it like so:

```bash
ssh admin@$(tart ip sonoma-base)
```

!!! tip "Running scripts inside Tart virtual machines"
    We recommend using [Cirrus CLI](integrations/cirrus-cli.md) to run scripts and/or retrieve artifacts
    from within Tart virtual machines. Alternatively, you can use plain ssh connection and `tart ip` command:

    ```bash
    brew install cirruslabs/cli/sshpass
    sshpass -p admin ssh -o "StrictHostKeyChecking no" admin@$(tart ip sonoma-base) "uname -a"
    sshpass -p admin ssh -o "StrictHostKeyChecking no" admin@$(tart ip sonoma-base) < script.sh
    ```

## Mounting directories

To mount a directory, run the VM with the `--dir` argument:

```bash
tart run --dir=project:~/src/project vm
```

Here, the `project` specifies a mount name, whereas the `~/src/project` is a path to the host's directory to expose to the VM.

It is also possible to mount directories in read-only mode by adding a third parameter, `ro`:

```bash
tart run --dir=project:~/src/project:ro vm
```

To mount multiple directories, repeat the `--dir` argument for each directory:

```bash
tart run --dir=www1:~/project1/www --dir=www2:~/project2/www
```

Note that the first parameter in each `--dir` argument must be unique, otherwise only the last `--dir` argument using that name will be used.

Note: to use the directory mounting feature, the host needs to run macOS 13.0 (Ventura) or newer.

### Accessing mounted directories in macOS guests

All shared directories are automatically mounted to `/Volumes/My Shared Files` directory.

The directory we've mounted above will be accessible from the `/Volumes/My Shared Files/project` path inside a guest VM.

Note: to use the directory mounting feature, the guest VM needs to run macOS 13.0 (Ventura) or newer.

??? tip "Changing mount location"
    It is possible to remount the directories after a virtual machine is started by running the following commands:
    
    ```bash
    sudo umount "/Volumes/My Shared Files"
    mkdir ~/workspace
    mount_virtiofs com.apple.virtio-fs.automount ~/workspace
    ```

    After running the above commands the direcory will be available at `~/workspace/project`

### Accessing mounted directories in Linux guests

To be able to access the shared directories from the Linux guest, you need to manually mount the virtual filesystem first:

```bash
mount -t virtiofs com.apple.virtio-fs.automount /mnt/shared
```

The directory we've mounted above will be accessible from the `/mnt/shared/project` path inside a guest VM.
