---
hide:
  - navigation
---

Try running a Tart VM on your Apple Silicon device running macOS 12.0 (Monterey) or later (will download a 25 GB image):

```bash
brew install cirruslabs/cli/tart
tart clone ghcr.io/cirruslabs/macos-ventura-base:latest ventura-base
tart run ventura-base
```

<p align="center">
  <img src="https://github.com/cirruslabs/tart/raw/main/Resources/TartScreenshot.png"/>
</p>

## SSH access

If the guest VM is running and configured to accept incoming SSH connections you can conveniently connect to it like so:

```bash
ssh admin@$(tart ip macos-ventura-base)
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

### Accessing mounted directories in Linux guests

To be able to access the shared directories from the Linux guest, you need to manually mount the virtual filesystem first:

```bash
mount -t virtiofs com.apple.virtio-fs.automount /mnt/shared
```

The directory we've mounted above will be accessible from the `/mnt/shared/project` path inside a guest VM.

