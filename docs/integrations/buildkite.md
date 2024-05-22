---
title: Buildkite Integration
description: Run pipeline steps in isolated ephemeral Tart Virtual Machines.
---

# Buildkite

It is possible to run [Buildkite](https://buildkite.com/) pipeline steps in isolated ephemeral Tart Virtual Machines with the help of [Tart Buildkite Plugin](https://github.com/cirruslabs/tart-buildkite-plugin):

![](/assets/images/BuildkiteTartPlugin.png)

## Configuration

The most basic configuration looks like this:

```yaml
steps:
- command: uname -a
  plugins:
  - cirruslabs/tart#main:
    image: ghcr.io/cirruslabs/macos-sonoma-base:latest
```

This will run `uname -r` in a macOS Tart VM cloned from `ghcr.io/cirruslabs/macos-sonoma-base:latest`.

See plugin's [Configuration section](https://github.com/cirruslabs/tart-buildkite-plugin#configuration) for the full list of available options.
