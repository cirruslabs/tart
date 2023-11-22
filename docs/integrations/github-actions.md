# Cirrus Runners for GitHub Actions

*Cirrus Runners* is the fastest and most cost-efficient way to get your current CI workflows to benefit from Apple Silicon hardware. No need to manage infrastructure or migrate to another CI provider.
Your actions will be executed in clean macOS virtual machines with 4 Apple M2 cores.

## Testimonials from customers

Max Lapides, Senior Mobile Engineer at [Tonal](https://www.tonal.com/):

> Previously, we were using the GitHub‑hosted macOS runners and our iOS build took ~30 minutes. Now with Cirrus Runners, the iOS build only takes ~12 minutes. That’s a huge boost to our productivity, and for only $150/month per runner it is much less expensive too.

John A., Software Engineer at [GitKraken](https://www.gitkraken.com/):

> GitHub Actions MacOS-x86 runners have become increasingly unreliable, so we're moving our Mac builds over to arm64 because Cirrus Labs' M1 runners are not only ~3 times faster, they've also been far more stable.

Sebastian Jachec, Mobile Engineer at [Daybridge](https://www.daybridge.com/):

> It’s been plain-sailing with the Cirrus Runners — they’ve been great! They’re consistently 60+% faster on workflows that we previously used Github Actions’ macOS runners for.

## Pricing

Each Cirrus Runner costs $150 a month and there is no limit on the amount of minutes for your actions.
We recommend to purchase several Cirrus Runners depending on your team size, so you can run actions in
parallel. Note that you can change your subscription at any time via [this page](https://billing.stripe.com/p/login/3cs7vNbzo92p7fy3cc)
or by emailing [support@cirruslabs.org](mailto:support@cirruslabs.org).

### Discounts

We offer two mutually exclusive discounts:

- 10% "Volume Discount" for subscriptions of 10 or more Cirrus Runners.
- 15% "Annual Discount" for 12 months subscription commitment of any amount of Cirrus Runners.

Please contact [support@cirruslabs.org](mailto:support@cirruslabs.org) after activating the subscription in order to get the discount applied.

### Priority Support

Subscriptions of 20 or more Cirrus Runners include access to [Priority Support](../licensing.md#priority-support).
Please contact [sales@cirruslabs.org](mailto:sales@cirruslabs.org) in order to get all the details.

### CPU and Memory resources of Cirrus Runners

By default, a single Cirrus Runner is allocated with 4 M2 cores and 12 GB of unified memory which is enough for most of the workloads.
For workloads that require more resources it is possible to use XL Cirrus Runners which have twice the resources: a full M2 chip with 8 cores
and 24 GB of unified memory. Note that a single XL Cirrus Runner also uses twice the concurrency.

In order to use an XL Cirrus Runner for a job please append `-xl` suffix to your `runs-on` property. More on that down below.

## Installation

Once you configure [Cirrus Runners App](https://github.com/apps/cirrus-runners) for your organization, you'll be redirected
to a checkout page powered by Stripe. During the checkout process you'll be able to configure a subscription for
a desired amount of parallel Cirrus Runners and try it for free for 10 days.

Once configured, please follow instruction below. If you have any questions please contact [support@cirruslabs.org](mailto:support@cirruslabs.org).
Subscriptions with more than 10 runners also include Priority Support 

## Configuring Cirrus Runners

In order for Cirrus Runners to be used by your GitHub Actions workflow jobs, specify a desired image in the `runs-on` property.

=== "Default Cirrus Runner"

    ```yaml
    name: Tests
    jobs:
      test:
        runs-on: ghcr.io/cirruslabs/macos-sonoma-xcode:latest
    ```

=== "XL Cirrus Runner"

    ```yaml
    name: Integration Tests
    jobs:
      test:
        runs-on: ghcr.io/cirruslabs/macos-sonoma-xcode:latest-xl
    ```

List of all available images can be found in [this repository](https://github.com/cirruslabs/macos-image-templates).

Note that Tart VM images don't have the same set of pre-installed packages as the official Intel GitHub runners.
If something is missing please [create an issue within this repository](https://github.com/cirruslabs/macos-image-templates/issues/new).

When workflows are executing you'll see Cirrus on-demand runners on your organization's settings page at `https://github.com/organizations/<ORGANIZATION>/settings/actions/runners`.
Note that Cirrus Runners will get added to the default runner group.

!!! tip "Using Cirrus Runners with public repositories"

    By default, only private repositories can access runners in a default runner group, but you can override this in your organization's settings:

    ```https://github.com/organizations/<YOUR ORGANIZATION NAME>/settings/actions/runner-groups/1```

![](/assets/images/TartGHARunners.png)

### Dashboard

You can also see the status of your runners on the [Cirrus Runners Dashboard](https://cirrus-runners.app/). This dashboard
also provides insights into price performance of your Cirrus Runners. Please check out [this blog post](/blog/2023/11/03/new-dashboard-with-insights-into-performance-of-cirrus-runners/)
to learn more about what this dashboard can do for you.

![](/assets/images/RunnersDashboard.png)

## Data handling flow

By design Cirrus Runners service never sees any of your secrets or source code and acts as compute platform with the lastest
Apple Silicon hardware that can quickly allocate CPU/Memory resources for your jobs.

Here is a high-level overview of how Cirrus Runners service manages runners for your organization:

- Cirrus Runner GitHub App is subscribed to [`workflow_job`](https://docs.github.com/en/webhooks/webhook-events-and-payloads#workflow_job).
- Upon receiving a new event targeting Cirrus Runners via `runs-on` property the following steps take place:

    - Non-personal information about your job is saved to perform health checking of Cirrus Runners execution.
    - Cirrus Runners GitHub App has only one permission that allows generating temporary registration tokens for
      self-hosted GitHub Actions Runners. Note that Cirrus Runners GitHub App itself doesn't have access to contents of
      repositories in your organization.
    - Cirrus Runners Service creates a new single use Tart VM, generates a temporary registration tokens for self-hosted runners
      and passes it without storing inside the VM for the GitHub Actions Runner service to [start a ephemeral runner](https://github.blog/changelog/2021-09-20-github-actions-ephemeral-self-hosted-runners-new-webhooks-for-auto-scaling/).

- Cirrus Runners service continuously monitors health of the Tart VM executing your job to make sure it runs to completion.
- After the job finishes the ephemeral Tart VM is getting destroyed with all the information of the job run.

If you have any questions or concerns please feel free to reach out to [support@cirruslabs.org](mailto:support@cirruslabs.org).
