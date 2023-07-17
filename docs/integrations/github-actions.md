# GitHub Actions

Tart already powers several CI services mentioned above including our own [Cirrus CI](https://cirrus-ci.org/guide/macOS/) which offers unlimited concurrency with per-second billing.
For services that haven't leveraged Tart yet, we offer fully managed runners via a monthly subscription.
*Cirrus Runners* is the fastest way to get your current CI workflows to benefit from Apple Silicon hardware. No need to manage infrastructure or migrate to another CI provider.

## Testimonials from customers

Sebastian Jachec, Mobile Engineer at [Daybridge](https://www.daybridge.com/).

> It’s been plain-sailing with the Cirrus Runners — they’ve been great! They’re consistently 60+% faster on workflows that we previously used Github Actions’ macOS runners for.

Max Lapides, Senior Mobile Engineer at [Tonal](https://www.tonal.com/).

> Previously, we were using the GitHub‑hosted macOS runners and our iOS build took ~30 minutes. Now with Cirrus Runners, the iOS build only takes ~12 minutes. That’s a huge boost to our productivity, and for only $150/month per runner it is much less expensive too.


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
Note that Cirrus Runners will get added to the default runner group. By default, only private repositories can access runners in a default runner group, but you can override this in your organization's settings.

![](/assets/images/TartGHARunners.png)
