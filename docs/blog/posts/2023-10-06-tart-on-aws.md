---
draft: false
date: 2023-10-06
search:
  exclude: true
authors:
  - fkorotkov
categories:
  - announcement
---

# Tart is now available on AWS Marketplace

Announcing [official AMIs for EC2 Mac Instances](https://aws.amazon.com/marketplace/pp/prodview-qczco34wlkdws)
with preconfigured Tart installation that is optimized to work within AWS infrastructure.

EC2 Mac Instances is a gem of engineering powered by AWS Nitro devices. Just imagine there is a physical Mac Mini with
a plugged in Nitro device that can push the physical power button!

![EC2 M2 Pro](/blog/images/ec2-mac2-m2pro.png)

This clever synergy between Apple Hardware and Nitro System allows seamless integration with VPC networking and booting macOS from an EBS volume.

In this blog post we’ll see how a virtualization solution like Tart can compliment and elevate experience with EC2 Mac Instances.

<!-- more -->

Let’s start from the basics, what EC2 Mac Instances allow to do compared to physical Mac Minis seating in offices of
many companies around the world?

First and foremost, EC2 Mac Instances sit inside AWS data centers and can leverage all the goodies of VPC networking
within your company's existing infrastructure. No need to connect your Macs in the office through a VPN and deal
with networking and security.

Additionally, EC2 Mac Instances are booting from EBS volumes which means it is possible to always have reproducible instances
and apply all the best practices of Infrastructure-as-Code. Managing a fleet of physical Macs is a pain and it's very hard
to make them configured in a reproducible and stable way. With booting from identical EBS volumes your team is always sure
about the identical initial state of the fleet.

## Compromises of EC2 Mac Instances

The flexibility of EBS volumes for macOS comes with some compromises that virtualization solutions like Tart can help with.
The initial boot from an EBS volume takes some time and not instant. macOS itself is pretty heavy and a Nitro device needs
to download tens of gigabytes that macOS requires in order to boot. This means that **resetting a EC2 Mac Instance to a clean state
is not instant and usually takes a couple of minutes** when you can’t utilize the precious resources for your workloads.

It is much easier to tailor such EBS volumes with tools like Packer but there is still a **friction to test newly created EBS volumes**
since one needs to start and run a EC2 Mac Instance and it’s not possible to test things locally. Similarly it is even harder
to test beta versions of macOS that require manual interaction with a running instance.

## Solution

Tart can help with all the compromises! Tart virtual machines (VMs) have nearly native performance thanks to utilizing
native `Virtualization.Framework` that was developed along the first Apple Silicon chip. **Tart VMs can be copied/disposed
instantly and booting a fresh Tart VM takes only several seconds**. It is also possible to run two different Tart VMs in parallel
that can have completely different versions of macOS and packages. For example, it is possible to have the latest stable macOS
with the release version of Xcode along with the next version of macOS with the latest beta of Xcode.

Creation of Tart VMs can be automated with [a Packer plugin](https://github.com/cirruslabs/packer-plugin-tart) the same way as
creation of EC2 AMIs with one caveat that **Tart Packer Plugin works locally so you can test the same virtual machine locally
as you would run it in the cloud**.

Lightweight nature of Tart VMs with a focus on an easy-to-integrate Tart CLI compliments any macOS automation and helps to reduce
the feedback cycle and improves reproducibility of macOS environments even further.

## Conclusion

We are excited to bring [official AMIs that include Tart installation optimized to work within AWS](https://aws.amazon.com/marketplace/pp/prodview-qczco34wlkdws).
In the coming weeks when macOS Sonoma will become available on AWS we’ll release another update specifically targeting EC2 Mac Instances. 
This update will simplify access to local SSDs of Mac Instances that are slightly faster than EBS volumes. Stay tuned and don’t hesitate
to ask any [questions](https://tart.run/licensing/).
