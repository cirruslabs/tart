<img src="https://github.com/cirruslabs/tart/raw/main/Resources/TartSocial.png"/>

*Tart* is a virtualization toolset to build, run and manage macOS and Linux virtual machines (VMs) on Apple Silicon.
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

Try running a Tart VM on your Apple Silicon device running macOS 12.0 (Monterey) or later (will download a 25 GB image):

```shell
brew install cirruslabs/cli/tart
tart clone ghcr.io/cirruslabs/macos-ventura-base:latest ventura-base
tart run ventura-base
```

<img src="https://github.com/cirruslabs/tart/raw/main/Resources/TartScreenshot.png"/>

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
  Remote images are pulled into `~/.tart/cache/OCIs/`.
</details>

<details>
  <summary>Nested virtualization support?</summary>

  Tart is limited by functionality of Apple's `Virtualization.Framework`. At the moment `Virtualization.Framework`
  doesn't support nested virtualization.
</details>

<details>
  <summary>Changing the default NAT subnet</summary>

  To change the default network to `192.168.77.1`:

  ```shell
  sudo defaults write /Library/Preferences/SystemConfiguration/com.apple.vmnet.plist Shared_Net_Address -string 192.168.77.1
  ```

  Note that even through a network would normally be specified as `192.168.77.0`, the [vmnet framework](https://developer.apple.com/documentation/vmnet) seems to treat this as a starting address too and refuses to pick up such network-like values.

  The default subnet mask `255.255.255.0` should suffice for most use-cases, however, you can also change it to `255.255.0.0`, for example:

  ```shell
  sudo defaults write /Library/Preferences/SystemConfiguration/com.apple.vmnet.plist Shared_Net_Mask -string 255.255.0.0
  ```
</details>

<details>
  <summary>How to connect to a VM over SSH?</summary>

  If the guest VM is running and configured to accept incoming SSH connections you can conveniently connect to it like so:
  
  ```shell
  ssh admin@$(tart ip macos-monterey-base)
  ```
</details>
