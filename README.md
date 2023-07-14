<img src="https://github.com/cirruslabs/tart/raw/main/Resources/TartSocial.png"/>

*Tart* is a virtualization toolset to build, run and manage macOS and Linux virtual machines (VMs) on Apple Silicon.
Built by CI engineers for your automation needs. Here are some highlights of Tart:

* Tart uses Apple's own `Virtualization.Framework` for [near-native performance](https://browser.geekbench.com/v5/cpu/compare/20382844?baseline=20382722).
* Push/Pull virtual machines from any OCI-compatible container registry.
* Use Tart Packer Plugin to automate VM creation.
* Easily integrates with any CI system.

Tart powers [Cirrus Runners](https://tart.run/integrations/github-actions/?utm_source=github&utm_medium=referral)
service — a drop-in replacement for the standard GitHub-hosted runners, offering 2-3 times better performance for a fraction of the price.

<p align="center">
  <a href="https://tart.run/integrations/github-actions/?utm_source=github&utm_medium=referral" target=_blank>
    <img src="https://github.com/cirruslabs/tart/raw/main/Resources/CirrusRunnersForGHA.png" height="65"/>
  </a>
</p>

Tart is also adopted by several other automation services:

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
  <a href="https://krisp.ai/" target=_blank>
    <img src="https://github.com/cirruslabs/tart/raw/main/Resources/Users/Krisp.png" height="65"/>
  </a>
  <a href="https://mullvad.net/" target=_blank>
    <img src="https://github.com/cirruslabs/tart/raw/main/Resources/Users/Mullvad.png" height="65"/>
  </a>
  <a href="https://suran.com/" target=_blank>
    <img src="https://github.com/cirruslabs/tart/raw/main/Resources/Users/Suran.png" height="65"/>
  </a>
  <a href="https://symflower.com/" target=_blank>
    <img src="https://github.com/cirruslabs/tart/raw/main/Resources/Users/Symflower.png" height="65"/>
  </a>
  <a href="https://transloadit.com/" target=_blank>
    <img src="https://github.com/cirruslabs/tart/raw/main/Resources/Users/Transloadit.png" height="65"/>
  </a>
  <a href="https://www.pitsdatarecovery.net/" target=_blank>
    <img src="https://github.com/cirruslabs/tart/raw/main/Resources/Users/PITSGlobalDataRecoveryServices.png" height="65"/>
  </a>
</p>

**Note:** If your company or project is using Tart please consider [adding yourself to the list above](/Resources/Users/HowToAddYourself.md).

## Usage

Try running a Tart VM on your Apple Silicon device running macOS 12.0 (Monterey) or later (will download a 25 GB image):

```bash
brew install cirruslabs/cli/tart
tart clone ghcr.io/cirruslabs/macos-ventura-base:latest ventura-base
tart run ventura-base
```

Please check the [official documentation](https://tart.run) for more information and/or feel free to use [discussions](https://github.com/cirruslabs/tart/discussions)
for remaining questions.
