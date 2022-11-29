<img src="https://github.com/cirruslabs/tart/raw/main/Resources/TartSocial.png"/>

*Tart* is a virtualization toolset to build, run and manage macOS and Linux virtual machines on Apple Silicon.
Built by CI engineers for your automation needs. Here are some highlights of Tart:

* Tart uses Apple's own `Virtualization.Framework` for [near-native performance](https://browser.geekbench.com/v5/cpu/compare/14966395?baseline=14966339).
* Push/Pull virtual machines from any OCI-compatible container registry.
* Use Tart Packer Plugin to automate VM creation.
* Built-in CI integration.

*Tart* is already adopted by several automation services:

<p align="center">
  <a href="https://cirrus-ci.org/guide/macOS/" target=_blank>
    <img src="https://github.com/cirruslabs/tart/raw/main/Resources/Users/CirrusCI.png" height="65"/>
  </a>
  <a href="https://codemagic.io/" target=_blank>
    <img src="https://github.com/cirruslabs/tart/raw/main/Resources/Users/Codemagic.png" height="65"/>
  </a>
  <a href="https://testingbot.com/" target=_blank>
    <img src="https://github.com/cirruslabs/tart/raw/main/Resources/Users/TestingBot.png" height="65"/>
  </a>
</p>

Many more companies are using Tart in their internal setups. Here are a few of them:

<p align="center">
  <a href="https://ahrefs.com/" target=_blank>
    <img src="https://github.com/cirruslabs/tart/raw/main/Resources/Users/ahrefs.png" height="65"/>
  </a>
  <a href="https://suran.com/" target=_blank>
    <img src="https://github.com/cirruslabs/tart/raw/main/Resources/Users/Suran.png" height="65"/>
  </a>
  <a href="https://symflower.com/" target=_blank>
    <img src="https://github.com/cirruslabs/tart/raw/main/Resources/Users/Symflower.png" height="65"/>
  </a>
</p>

**Note:** If your company or project is using Tart please consider [adding yourself to the list above](/Resources/Users/HowToAddYourself.md).

## Usage

Try running a Tart VM on your Apple Silicon device running macOS Monterey or later (will download a 25 GB image):

```shell
brew install cirruslabs/cli/tart
tart clone ghcr.io/cirruslabs/macos-ventura-base:latest ventura-base
tart run ventura-base
```

<img src="https://github.com/cirruslabs/tart/raw/main/Resources/TartScreenshot.png"/>

## CI Integration

Tart already powers several CI services mentioned above including our own [Cirrus CI](https://cirrus-ci.org/guide/macOS/) which offers unlimited concurrency with per-second billing.
For services that haven't leveraged Tart yet, we offer fully managed runners via a monthly subscription.
*Cirrus Runners* is the fastest way to get your current CI workflows to benefit from Apple Silicon hardware. No need to manage infrastructure or migrate to another CI provider.
Please read down below about currently supported services.

### Managed runners for your CI-as-a-service

At the moment Cirrus Runners only supports GitHub Actions, but we are actively working on adding more options.
Please [email us](mailto:hello@cirruslabs.org) if you are interested in a particular one.

#### GitHub Actions

Configuring Cirrus Runners for GitHub Actions is as simple as installing [Cirrus Runners App](https://github.com/apps/cirrus-runners).
After successful installation and subscription configuration, use any of [Ventura images managed by us](https://github.com/cirruslabs/macos-image-templates) in `runs-on`:

```yaml
name: Test Suite
jobs:
  test:
    runs-on: ghcr.io/cirruslabs/macos-ventura-xcode:latest
```

When workflows are executing you'll see Cirrus on-demand runners on your organization's settings page at `https://github.com/organizations/<ORGANIZATION>/settings/actions/runners`.

<img src="https://github.com/cirruslabs/tart/raw/main/Resources/TartGHARunners.png"/>

### Self-hosted CI

Tart itself is only responsible for managing virtual machines, but we've built Tart support into a tool called Cirrus CLI
also developed by Cirrus Labs. [Cirrus CLI](https://github.com/cirruslabs/cirrus-cli) is a command line tool with
one configuration format to execute common CI steps (run a script, cache a folder, etc.) locally or in any CI system.
We built Cirrus CLI to solve "But it works on my machine!" problem.

Here is an example of a `.cirrus.yml` configuration file which will start a Tart VM, will copy over working directory and
will run scripts and [other instructions](https://cirrus-ci.org/guide/writing-tasks/#supported-instructions) inside the virtual machine:

```yaml
task:
  name: hello
  macos_instance:
    # can be a remote or a local virtual machine
    image: ghcr.io/cirruslabs/macos-monterey-base:latest
  hello_script:
    - echo "Hello from within a Tart VM!"
    - echo "Here is my CPU info:"
    - sysctl -n machdep.cpu.brand_string
    - sleep 15
```

Put the above `.cirrus.yml` file in the root of your repository and run it with the following command:

```shell
brew install cirruslabs/cli/cirrus
cirrus run
```

<img src="https://github.com/cirruslabs/tart/raw/main/Resources/TartCirrusCLI.gif"/>

[Cirrus CI](https://cirrus-ci.org/) already leverages Tart to power its macOS cloud infrastructure. The `.cirrus.yml`
config from above will just work in Cirrus CI and your tasks will be executed inside Tart VMs in our cloud.

**Note:** Cirrus CI only allows [images managed and regularly updated by us](https://github.com/orgs/cirruslabs/packages?tab=packages&q=macos).

#### Retrieving artifacts from within Tart VMs

In many cases there is a need to retrieve particular files or a folder from within a Tart virtual machine.
For example, the below `.cirrus.yml` configuration defines a single task that builds a `tart` binary and
exposes it via [`artifacts` instruction](https://cirrus-ci.org/guide/writing-tasks/#artifacts-instruction):

```yaml
task:
  name: Build
  macos_instance:
    image: ghcr.io/cirruslabs/macos-monterey-xcode:latest
  build_script: swift build --product tart
  binary_artifacts:
    path: .build/debug/tart
```

Running Cirrus CLI with `--artifacts-dir` will write defined `artifacts` to the provided local directory on the host:

```bash
cirrus run --artifacts-dir artifacts
```

Note that all retrieved artifacts will be prefixed with the associated task name and `artifacts` instruction name.
For the example above, `tart` binary will be saved to `$PWD/artifacts/Build/binary/.build/debug/tart`.

## Virtual Machine Management

### Creating from scratch

Tart supports macOS and Linux virtual machines. All commands like `run` and `pull` work the same way regarding of the underlying OS a particular VM image has.
The only difference is how such VM images are created. Please check sections below for [macOS](#creating-a-macos-vm-image-from-scratch) and [Linux](#creating-a-linux-vm-image-from-scratch) instructions.

#### Creating a macOS VM image from scratch

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

#### Creating a Linux VM image from scratch

```bash
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

### Configuring a VM

By default, a tart VM uses 2 CPUs and 4 GB of memory with a `1024x768` display. This can be changed with `tart set` command.
Please refer to `tart set --help` for additional details.

### Building with Packer

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

### Working with a Remote OCI Container Registry

For example, let's say you want to push/pull images to a registry hosted at https://acme.io/.

#### Registry Authorization

First, you need to log in and save credential for `acme.io` host via `tart login` command:

```shell
tart login acme.io
```

Credentials are securely stored in Keychain.

In addition, Tart supports [Docker credential helpers](https://docs.docker.com/engine/reference/commandline/login/#credential-helpers)
if defined in `~/.docker/config.json`.

Finally, `TART_REGISTRY_USERNAME` and `TART_REGISTRY_PASSWORD` environment variables allow to override authorization
for all registries which might useful for integrating with your CI's secret management.

#### Pushing a Local Image

Once credentials are saved for `acme.io`, run the following command to push a local images remotely with two tags:

```shell
tart push my-local-vm-name acme.io/remoteorg/name:latest acme.io/remoteorg/name:v1.0.0
```

#### Pulling a Remote Image

You can either pull an image:

```shell
tart pull acme.io/remoteorg/name:latest
```

...or instantiate a VM from a remote image:

```shell
tart clone acme.io/remoteorg/name:latest my-local-vm-name
```

This invocation calls the `tart pull` implicitly (if the image is not being present) before doing the actual cloning.

### Mounting directories

To mount a directory, run the VM with the `--dir` argument:

```
tart run --dir=project:~/src/project vm
```

Here, the `project` specifies a mount name, whereas the `~/src/project` is a path to the host's directory to expose to the VM.

It is also possible to mount directories in read-only mode by adding a third parameter, `ro`:

```
tart run --dir=project:~/src/project:ro vm
```

Note: to use the directory mounting feature, the host needs to run macOS 13.0 (Ventura) or newer.

#### Accessing mounted directories in macOS guests

All shared directories are automatically mounted to `/Volumes/My Shared Files` directory.

The directory we've mounted above will be accessible from the `/Volumes/My Shared Files/project` path inside a guest VM.

Note: to use the directory mounting feature, the guest VM needs to run macOS 13.0 (Ventura) or newer.

#### Accessing mounted directories in Linux guests

To be able to access the shared directories from the Linux guest, you need to manually mount the virtual filesystem first:

```
mount -t virtiofs com.apple.virtio-fs.automount /mnt/shared
```

The directory we've mounted above will be accessible from the `/mnt/shared/project` path inside a guest VM.

## FAQ

<details>
  <summary>How Tart is different from Anka</summary>

  Under the hood Tart is using the same technology as Anka 3.0 so there should be no real difference in performance
  or features supported. If there is some feature missing please don't hesitate to [create a feature request](https://github.com/cirruslabs/tart/issues).

  Instead of Anka Registry, Tart can work with any OCI-compatible container registry.

  Tart doesn't yet have an analogue of Anka Controller for managing long living VMs. Please take a look at [CI integration](#ci-integration)
  section for an option to run ephemeral VMs for your needs.
</details>

<details>
  <summary>Why Tart is free and open sourced?</summary>

  Apple did all the heavy lifting with their `Virtualization.Framework` and it just felt right to develop Tart in the open.
  Please consider [becoming a sponsor](https://github.com/sponsors/cirruslabs) if you find Tart saving a substantial amount of money on licensing and engineering hours for your company.
</details>

<details>
  <summary>How to change VM's disk size?</summary>

  You can choose disk size upon creation of a virtual machine:

  ```shell
  tart create --from-ipsw=latest --disk-size=25 monterey-vanilla
  ```

  For an existing VM please use [Packer Plugin](https://github.com/cirruslabs/packer-plugin-tart) which can increase
  disk size for new virtual machines. Here is an example of [how to change disk size in a Packer template](https://github.com/cirruslabs/macos-image-templates/blob/fb0bcf68e0b093129136875c050205a66729b596/templates/base.pkr.hcl#L15).
</details>

<details>
  <summary>VM location on disk</summary>

  Tart stores all it's files in `~/.tart/` directory. Local images that you can run are stored in `~/.tart/vms/`.
  Remote images are pulled into `~/.tart/vms/cache/OCIs/`.
</details>

<details>
  <summary>Nested virtualization support?</summary>

  Tart is limited by functionality of Apple's `Virtualization.Framework`. At the moment `Virtualization.Framework`
  doesn't support nested virtualization.
</details>

<details>
  <summary>Changing the default NAT subnet</summary>

  To change the default network to `192.168.77.1`:

  ```
  sudo defaults write /Library/Preferences/SystemConfiguration/com.apple.vmnet.plist Shared_Net_Address -string 192.168.77.1
  ```

  Note that even through a network would normally be specified as `192.168.77.0`, the [vmnet framework](https://developer.apple.com/documentation/vmnet) seems to treat this as a starting address too and refuses to pick up such network-like values.

  The default subnet mask `255.255.255.0` should suffice for most use-cases, however, you can also change it to `255.255.0.0`, for example:

  ```
  sudo defaults write /Library/Preferences/SystemConfiguration/com.apple.vmnet.plist Shared_Net_Mask -string 255.255.0.0
  ```
</details>
