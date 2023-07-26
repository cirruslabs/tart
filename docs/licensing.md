---
hide:
  - navigation
---

Both [Tart Virtualization](https://github.com/cirruslabs/tart) and [Orchard Orchestration](https://github.com/cirruslabs/orchard)
are licensed under [Fair Source License](https://fair.io/). Usage on personal computers including personal workstations is royalty-free,
but organizations that exceed a certain number of server installations (100 CPU cores for Tart and/or 4 hosts for Orchard)
will be required to obtain a paid license.

??? note "Performance and Efficiency Cores"
    The virtual CPU cores in Tart VMs do not differentiate between the high-performance and high-efficient cores
    of the host CPU. Instead, Tart VMs automatically alternate between these types of cores depending on the workload
    being executed within the virtual machines. As a result, both performance and energy-efficient cores of the host CPU
    are treated equally in terms of licensing.

# License Tiers

## Free Tier

By default, when no [license is purchased](#get-the-license), it is assumed that an organization is using a Free Tier license.
You can find the Free Tier license text in [Tart](https://github.com/cirruslabs/tart/blob/main/LICENSE) and [Orchard](https://github.com/cirruslabs/orchard/blob/main/LICENSE) repositories.

Free Tier license has a 100 CPU core limit for Tart and 4 Orchard Workers limit for Orchard.

??? info "Usage Scenarios Examples"

    Here are a few examples that fit into the free tier:

      - Using Tart on 12 Mac Minis with 8 CPUs each running up to 24 VMs in parallel.
      - Creating an Orchard cluster of 4 Mac Studio workers with 24 CPUs each.

    Here are a few examples that do not fit into the free tier:

      - Using Tart on 13 Mac Minis with 8 CPUs each.
      - Creating an Orchard cluster of 5 Mac Minis workers with 8 CPUs each.

## Gold Tier

If an organization wishes to exceed the limits of the Free Tier license, a purchase of the [Gold Tier License](#get-the-license) is required, which costs \$1000 per month.

Gold Tier license has a 500 CPU core limit for Tart and 20 Orchard Workers limit for Orchard.

## Platinum Tier

If an organization wishes to exceed the limits of the Gold Tier license, a purchase of the [Platinum Tier License](#get-the-license) is required, which costs \$5000 per month.

Platinum Tier license has a 5,000 CPU core limit for Tart and 200 Orchard Workers limit for Orchard.

## Diamond Tier

For organizations that wish to exceed the limits of the Platinum Tier license, a purchase of a [custom Diamond Tier License](#get-the-license) is required, which costs \$1 per CPU core per month and gives the ability to run unlimited Orchard Workers.

# Get the license

If your organization is interested in purchasing one of the license tiers, please email [licensing@cirruslabs.org](mailto:licensing@cirruslabs.org).

You can see a template of a license subscription agreement [here](assets/TartLicenseSubscription.pdf).

# General Support

The best way to ask general questions about particular use cases is to email our support team at [support@cirruslabs.org](mailto:support@cirruslabs.org).
Our support team is trying our best to respond ASAP, but there is no guarantee on a response time unless your organization
has a paid license subscription which includes [Priority Support](#priority-support).

If you have a feature request or noticed lack of some documentation please feel free to [create a GitHub issue](https://github.com/cirruslabs/tart/issues/new).
Our support team will answer it by replying to the issue or by updating the documentation.

# Priority Support

In addition to the general support we provide a *Priority Support* with guaranteed response times included in all the paid license tiers.

| Severity | Support Impact                                                                                | First Response Time SLA | Hours | How to Submit                                                                                    |
|----------|-----------------------------------------------------------------------------------------------|-------------------------|-------|--------------------------------------------------------------------------------------------------|
| 1        | Emergency (service is unavailable or completely unusable).                                    | 30 minutes              | 24x7  | Please use urgent email address.                                                                 |
| 2        | Highly Degraded (Important features unavailable or extremely slow; No acceptable workaround). | 4 hours                 | 24x5  | Please use priority email address.                                                               |
| 3        | Medium Impact.                                                                                | 8 hours                 | 24x5  | Please use priority email address.                                                               |
| 4        | Low Impact.                                                                                   | 24 hours                | 24x5  | Please use regular support email address. Make sure to send the email from your corporate email. |

`24x5` means period of time from 9AM on Monday till 5PM on Friday in EST timezone.

<!-- markdownlint-disable MD037 -->
??? note "Support Impact Definitions"
    * **Severity 1** - Your installation of Orchard is unavailable or completely unusable. An urgent issue can be filed and
      our On-Call Support Engineer will respond within 30 minutes. Example: Orchard Controller is showing 502 errors for all users.
    * **Severity 2** - Orchard installation is Highly Degraded. Significant Business Impact. Important features are unavailable
      or extremely slowed, with no acceptable workaround.
    * **Severity 3** - Something is preventing normal service operation. Some Business Impact. Important features of Tart or Orchard
      are unavailable or somewhat slowed, but a workaround is available.
    * **Severity 4** - Questions or Clarifications around features or documentation. Minimal or no Business Impact.
      Information, an enhancement, or documentation clarification is requested, but there is no impact on the operation of Tart and/or Orchard.

!!! info "How to submit a priority or an urgent issue"
    Once your organization [obtains a license](#license-tiers), members of your organization
    will get access to separate support emails specified in your subscription contract.
