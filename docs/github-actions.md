---
hide:
  - navigation
---

# GitHub Actions

Tart already powers several CI services mentioned above including our own [Cirrus CI](https://cirrus-ci.org/guide/macOS/) which offers unlimited concurrency with per-second billing.
For services that haven't leveraged Tart yet, we offer fully managed runners via a monthly subscription.
*Cirrus Runners* is the fastest way to get your current CI workflows to benefit from Apple Silicon hardware. No need to manage infrastructure or migrate to another CI provider.

## Configuring Cirrus Runners

Configuring Cirrus Runners for GitHub Actions is as simple as installing [Cirrus Runners App](https://github.com/apps/cirrus-runners).
After successful installation and subscription configuration, use any of [Ventura images managed by us](https://github.com/cirruslabs/macos-image-templates) in `runs-on`:

```yaml
name: Test Suite
jobs:
  test:
    runs-on: ghcr.io/cirruslabs/macos-ventura-xcode:latest
```

When workflows are executing you'll see Cirrus on-demand runners on your organization's settings page at `https://github.com/organizations/<ORGANIZATION>/settings/actions/runners`.

![](/assets/images/TartGHARunners.png)
