![Tart – open source virtualization for your automation needs](Resources/TartSocial.png)

*Tart* is a virtualization toolset to build, run and manage virtual machines on Apple Silicon.
Built by CI engineers for your automation needs. Here are some highlights of Tart:

* Tart uses Apple's own `Virtualization.Framework` for near-native performance.
* Push/Pull virtual machines from any OCI-compatible container registry.
* Use Tart Packer Plugin to automate VM creation.
* Built-in CI integration.

Try running a Tart VM on your Apple Silicon device (will download a 25 GB image):

```shell
brew install cirruslabs/cli/tart
tart clone ghcr.io/cirruslabs/macos-monterey-base:latest monterey-base
tart run monterey-base
```

![tart VM view app](Resources/TartScreenshot.png)

## CI Integration

[Cirrus CLI](https://github.com/cirruslabs/cirrus-cli) is an open-sourced CI-agnostic tool that can run workloads
inside containers via Docker or Podman and now inside macOS VMs via Tart. Put the following `.cirrus.yml` file
in the root of your repository:

```yaml
task:
  name: hello
  macos_instance:
    # can be a remote or a local virtual machine
    image: ghcr.io/cirruslabs/macos-monterey-base:latest
  script: echo "Hello from within a Tart VM!"
```

Run it locally or in CI with the following command:

```shell
brew install cirruslabs/cli/cirrus
cirrus run
```

[Cirrus CI](https://cirrus-ci.org/) already leverages Tart to power its macOS cloud infrastructure. The `.cirrus.yml`
config from above will just work in Cirrus CI and your tasks will be executed inside Tart VMs in our cloud.

**Note:** Cirrus CI only allows [images managed and regularly updated by us](https://github.com/orgs/cirruslabs/packages?tab=packages&q=macos).

## Virtual Machine Management

### Creating from scratch

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

### Configuring a VM

By default, a tart VM uses 2 CPUs and 4 GB of memory with a `1024x768` display. This can be changed with `tart set` command.
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
      "vm_base_name": "tartvm/vanilla:latest",
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
        "echo 'Disabling spotlight indexing...'",
        "sudo mdutil -a -i off"
      ],
      "type": "shell"
    },
    # more provisioners
  ]
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

#### Pushing a Local Image

Once credentials are saved for `acme.io`, run the following command to push a local images remotely with two tags:

```shell
tart push my-local-vm-name acme.io/remoteorg/name:latest acme.io/remoteorg/name:v1.0.0
```

#### Pulling a Remote Image

```shell
tart pull acme.io/remoteorg/name:latest my-local-vm-name
```

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

  Tart is a relatively small project, and it didn't feel right to try to monetize it.
  Apple did all the heavy lifting with their `Virtualization.Framework`.
</details>
