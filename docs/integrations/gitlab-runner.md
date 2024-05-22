---
title: GitLab Runner Executor
description: Run jobs in isolated ephemeral Tart Virtual Machines.
---

# GitLab Runner Executor

It is possible to run GitLab jobs in isolated ephemeral Tart Virtual Machines via [Tart Executor](https://github.com/cirruslabs/gitlab-tart-executor).
Tart Executor utilizes [custom executor](https://docs.gitlab.com/runner/executors/custom.html) feature of GitLab Runner.

# Basic Configuration

Configuring Tart Executor for GitLab Runner is as simple as installing `gitlab-tart-executor` binary from Homebrew:

```bash
brew install cirruslabs/cli/gitlab-tart-executor
```

And updating configuration of your self-hosted GitLab Runner to use `gitlab-tart-executor` binary:

```toml
concurrent = 2

[[runners]]
  # ...
  executor = "custom"
  builds_dir = "/Users/admin/builds" # directory inside the VM
  cache_dir = "/Users/admin/cache"
  [runners.feature_flags]
    FF_RESOLVE_FULL_TLS_CHAIN = false
  [runners.custom]
    prepare_exec = "gitlab-tart-executor"
    prepare_args = ["prepare"]
    run_exec = "gitlab-tart-executor"
    run_args = ["run"]
    cleanup_exec = "gitlab-tart-executor"
    cleanup_args = ["cleanup"]
```

Now you can use Tart Images in your `.gitlab-ci.yml`:

```yaml
# You can use any remote Tart Image.
# Tart Executor will pull it from the registry and use it for creating ephemeral VMs.
image: ghcr.io/cirruslabs/macos-sonoma-base:latest

test:
  tags:
    - tart-installed # in case you tagged runners with Tart Executor installed
  script:
    - uname -a
```

For more advanced configuration please refer to [GitLab Tart Executor repository](https://github.com/cirruslabs/gitlab-tart-executor).
