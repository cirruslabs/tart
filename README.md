![tart VM view app](Resources/TartScreenshot.png)

*Tart* is a virtualization toolset to build, run and manage virtual machines on Apple Silicon.
Built by CI engineers for your automation needs. Here are some highlights of Tart:

* Tart uses Apple's own `Virtualization.Framework` for near-native performance.
* Push/Pull virtual machines from any OCI-compatible container registry.
* Use Tart Packer Plugin to automate VM creation.
* Built-in CI integration.

Try running a Tart VM on your Apple Silicon device (will download a 25 GB image):

```shell
brew install cirruslabs/cli/tart
tart clone ghcr.io/cirruslabs/monterey-base:latest monterey-base
tart run monterey-base
```

## CI Integration

If you are using [Cirrus CI](https://cirrus-ci.org/) then you can already use any of [`monterey-*` packages](https://github.com/orgs/cirruslabs/packages?tab=packages&q=monterey)
provided and regularly updated by us. Here is an example of `.cirrus.yml` file:

```yaml
task:
  name: hello
  macos_instance:
    image: ghcr.io/cirruslabs/monterey-base:latest
  script: echo "Hello from within a Tart VM!"
```

**Please use [Cirrus CLI](https://github.com/cirruslabs/cirrus-cli) with any other CI.** Cirrus CLI is a
CI-agnostic tool that can run workloads inside containers via Docker or Podman and now inside macOS VMs via Tart.
Put `.cirrus.yml` from above in the root of your repository and run it locally or in CI with the following command:

```shell
brew install cirruslabs/cli/cirrus
cirrus run hello
```

## Virtual Machine Management

### Creating from scratch

Tart can create VMs from `*.ipsw` files. You can download a specific `*.ipsw` file [here](https://ipsw.me/) or you can
use `latest` instead of a path to `*.ipsw` to download the latest available version:

```shell
tart create --from-ipsw=latest monterey-vanilla
tart run monterey-vanilla
```

After the initial booting of the VM you'll need to manually go through macOS installation process. As a convention
we recommend creating an `admin` user with an `admin` password. After the regular installation please do some additional modifications in the VM:

1. Enable Auto-Login. Users & Groups -> Login Options -> Automatic login -> admin.
2. Allow SSH. Sharing -> Remote Login
3. Disable Lock Screen. Preferences -> Lock Screen -> disable "Require Password" after 5.
4. Disable Screen Saver.
5. Run `sudo visudo` in Terminal, find `%admin ALL=(ALL) ALL` add `admin ALL=(ALL) NOPASSWD: ALL` to allow sudo without a password.

### Configuring a VM

By default, a tart VM uses 2 CPUs and 4 GB of memory with a `1024x768` screen. This can be changed with `tart set` command.
Please refer to `tart set --help` for additional details.

### Building with Packer

Please refer to [Tart Packer Plugin reposiotry](https://github.com/cirruslabs/packer-plugin-tart) for setup instructions.
Here is an example of a template to build `monterey-base` local image based of a remote image:

```json
{
  "builders": [
    {
      "name": "tart",
      "type": "tart-cli",
      "vm_base_name": "ghcr.io/cirruslabs/monterey-vanilla:latest",
      "vm_name": "monterey-base",
      "cpu_count": 4,
      "memory_gb": 8,
      "disk_size_gb": 32,
      "ssh_username": "admin",
      "ssh_password": "admin",
      "ssh_timeout": "120s"
    }
  ],
  "provisioners": [
    {
      "inline": [
        "echo 'Disabling spotlight...'",
        "sudo mdutil -a -i off"
      ],
      "type": "shell"
    },
    # more provisioners
  ]
}
```

Here is a [repository with Packer templates](https://github.com/cirruslabs/macos-image-templates) used to build all the `ghcr.io/cirruslabs/monterey-*` images.

### Pushing to a registry



## FAQ
