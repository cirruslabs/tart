---
title: Managing Virtual Machine
description: Use Packer to build custom VM images, configure VMs and work with remote OCI registries.
---

# Managing Virtual Machine

## Creating from scratch

Tart supports macOS and Linux virtual machines. All commands like `run` and `pull` work the same way regarding of the underlying OS a particular VM image has.
The only difference is how such VM images are created. Please check sections below for [macOS](#creating-a-macos-vm-image-from-scratch) and [Linux](#creating-a-linux-vm-image-from-scratch) instructions.

### Creating a macOS VM image from scratch

Tart can create VMs from `*.ipsw` files. You can download a specific `*.ipsw` file [here](https://ipsw.me/) or you can
use `latest` instead of a path to `*.ipsw` to download the latest available version:

```bash
tart create --from-ipsw=latest sonoma-vanilla
tart run sonoma-vanilla
```

After the initial booting of the VM, you'll need to manually go through the macOS installation process. As a convention we recommend creating an `admin` user with an `admin` password. After the regular installation please do some additional modifications in the VM:

1. Enable Auto-Login. Users & Groups -> Login Options -> Automatic login -> admin.
2. Allow SSH. Sharing -> Remote Login
3. Disable Lock Screen. Preferences -> Lock Screen -> disable "Require Password" after 5.
4. Disable Screen Saver.
5. Run `sudo visudo` in Terminal, find `%admin ALL=(ALL) ALL` add `admin ALL=(ALL) NOPASSWD: ALL` to allow sudo without a password.

### Creating a Linux VM image from scratch

Linux VMs are supported on hosts running macOS 13.0 (Ventura) or newer.

```bash
# Create a bare VM
tart create --linux ubuntu

# Install Ubuntu
tart run --disk focal-desktop-arm64.iso ubuntu

# Run VM
tart run ubuntu
```

After the initial setup please make sure your VM can be SSH-ed into by running the following commands inside your VM:

```bash
sudo apt update
sudo apt install -y openssh-server
sudo ufw allow ssh
```

## Configuring a VM

By default, a Tart VM uses 2 CPUs and 4 GB of memory with a `1024x768` display. This can be changed after VM creation with `tart set` command.
Please refer to `tart set --help` for additional details.

## Building with Packer

Please refer to [Tart Packer Plugin repository](https://github.com/cirruslabs/packer-plugin-tart) for setup instructions.
Here is an example of a template to build a local image based of a remote image:

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
  vm_base_name = "ghcr.io/cirruslabs/macos-sonoma-base:latest"
  vm_name      = "my-custom-sonoma"
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

Tart supports interacting with Open Container Initiative (OCI) registries, but only runs images created and pushed by Tart. This means images created for container engines, like Docker, can't be pulled. Instead, create a custom image as documented above.

For example, let's say you want to push/pull images to an OCI registry hosted at `https://acme.io/`.

### Registry Authorization

First, you need to login to `acme.io` with the `tart login` command:

```bash
tart login acme.io
```

If you login to your registry with OAuth, you may need to create an access token to use as the password.
Credentials are securely stored in Keychain.

In addition, Tart supports [Docker credential helpers](https://docs.docker.com/engine/reference/commandline/login/#credential-helpers)
if defined in `~/.docker/config.json`.

Finally, `TART_REGISTRY_USERNAME` and `TART_REGISTRY_PASSWORD` environment variables allow to override authorization
for all registries which might useful for integrating with your CI's secret management.

### Pushing a Local Image

Once credentials are saved for `acme.io`, run the following command to push a local images remotely with two tags:

```bash
tart push my-local-vm-name acme.io/remoteorg/name:latest acme.io/remoteorg/name:v1.0.0
```

### Pulling a Remote Image

You can either pull an image:

```bash
tart pull acme.io/remoteorg/name:latest
```

or create a VM from a remote image:

```bash
tart clone acme.io/remoteorg/name:latest my-local-vm-name
```

If the specified image is not already present, this invocation calls the `tart pull` implicitly before cloning.
