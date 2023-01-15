---
hide:
  - navigation
---

# Managing Virtual Machine

## Creating from scratch

Tart supports macOS and Linux virtual machines. All commands like `run` and `pull` work the same way regarding of the underlying OS a particular VM image has.
The only difference is how such VM images are created. Please check sections below for [macOS](#creating-a-macos-vm-image-from-scratch) and [Linux](#creating-a-linux-vm-image-from-scratch) instructions.

### Creating a macOS VM image from scratch

Tart can create VMs from `*.ipsw` files. You can download a specific `*.ipsw` file [here](https://ipsw.me/) or you can
use `latest` instead of a path to `*.ipsw` to download the latest available version:

```shell
tart create --from-ipsw=latest monterey-vanilla
tart run monterey-vanilla
```

After the initial booting of the VM you'll need to manually go through the macOS installation process. As a convention we recommend creating an `admin` user with an `admin` password. After the regular installation please do some additional modifications in the VM:

1. Enable Auto-Login. Users & Groups -> Login Options -> Automatic login -> admin.
2. Allow SSH. Sharing -> Remote Login
3. Disable Lock Screen. Preferences -> Lock Screen -> disable "Require Password" after 5.
4. Disable Screen Saver.
5. Run `sudo visudo` in Terminal, find `%admin ALL=(ALL) ALL` add `admin ALL=(ALL) NOPASSWD: ALL` to allow sudo without a password.

### Creating a Linux VM image from scratch

Linux VMs are supported on hosts running macOS 13.0 (Ventura) or newer.

```shell
# Create a bare VM
tart create --linux ubuntu

# Install Ubuntu
tart run --disk focal-desktop-arm64.iso ubuntu

# Run VM
tart run ubuntu
```

After the initial setup please make sure your VM can be SSH-ed into by running the following commands inside your VM:

```shell
sudo apt update
sudo apt install -y openssh-server
sudo ufw allow ssh
```

## Configuring a VM

By default, a tart VM uses 2 CPUs and 4 GB of memory with a `1024x768` display. This can be changed with `tart set` command.
Please refer to `tart set --help` for additional details.

## Building with Packer

Please refer to [Tart Packer Plugin repository](https://github.com/cirruslabs/packer-plugin-tart) for setup instructions.
Here is an example of a template to build `monterey-base` local image based of a remote image:

```hcl
packer {
  required_plugins {
    tart = {
      version = ">= 0.5.3"
      source  = "github.com/cirruslabs/tart"
    }
  }
}

source "tart-cli" "tart" {
  vm_base_name = "ghcr.io/cirruslabs/macos-ventura-base:latest"
  vm_name      = "my-custom-ventura"
  cpu_count    = 4
  memory_gb    = 8
  disk_size_gb = 70
  ssh_password = "admin"
  ssh_timeout  = "120s"
  ssh_username = "admin"
}

build {
  sources = ["source.tart-cli.tart"]

  provisioner "shell" {
    inline = ["echo 'Disabling spotlight indexing...'", "sudo mdutil -a -i off"]
  }

  # more provisioners
}
```

Here is a [repository with Packer templates](https://github.com/cirruslabs/macos-image-templates) used to build [all the images managed by us](https://github.com/orgs/cirruslabs/packages?tab=packages&q=macos).

## Working with a Remote OCI Container Registry

For example, let's say you want to push/pull images to a registry hosted at https://acme.io/.

### Registry Authorization

First, you need to log in and save credential for `acme.io` host via `tart login` command:

```shell
tart login acme.io
```

Credentials are securely stored in Keychain.

In addition, Tart supports [Docker credential helpers](https://docs.docker.com/engine/reference/commandline/login/#credential-helpers)
if defined in `~/.docker/config.json`.

Finally, `TART_REGISTRY_USERNAME` and `TART_REGISTRY_PASSWORD` environment variables allow to override authorization
for all registries which might useful for integrating with your CI's secret management.

### Pushing a Local Image

Once credentials are saved for `acme.io`, run the following command to push a local images remotely with two tags:

```shell
tart push my-local-vm-name acme.io/remoteorg/name:latest acme.io/remoteorg/name:v1.0.0
```

### Pulling a Remote Image

You can either pull an image:

```shell
tart pull acme.io/remoteorg/name:latest
```

...or instantiate a VM from a remote image:

```shell
tart clone acme.io/remoteorg/name:latest my-local-vm-name
```

This invocation calls the `tart pull` implicitly (if the image is not being present) before doing the actual cloning.

## Mounting directories

To mount a directory, run the VM with the `--dir` argument:

```shell
tart run --dir=project:~/src/project vm
```

Here, the `project` specifies a mount name, whereas the `~/src/project` is a path to the host's directory to expose to the VM.

It is also possible to mount directories in read-only mode by adding a third parameter, `ro`:

```shell
tart run --dir=project:~/src/project:ro vm
```

To mount multiple directories, repeat the `--dir` argument for each directory:

```shell
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

```shell
mount -t virtiofs com.apple.virtio-fs.automount /mnt/shared
```

The directory we've mounted above will be accessible from the `/mnt/shared/project` path inside a guest VM.
