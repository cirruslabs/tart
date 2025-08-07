## Architecture

Orchard cluster consists of three components:

* Controller — responsible for managing the cluster and scheduling of resources 
* Worker — responsible for executing the VMs
* Client — responsible for creating, modifying and removing the resources on the Controller, can either be an [Orchard CLI](/orchard/using-orchard-cli) or [an API consumer](/orchard/integration-guide)

At the moment, only one Controller instance is currently supported, while you can deploy one or more Workers and run any number of Clients.

In terms of networking requirements, only Controller needs to be directly accessible from Workers and Clients, while Workers and Clients can be deployed and run anywhere (e.g. behind a NAT).

## Security

When an Orchard Client or a Worker connects to the Controller, they need to establish trust and verify that they're talking to the right Controller, so that no [man-in-the-middle attack](https://en.wikipedia.org/wiki/Man-in-the-middle_attack) is possible.

Similarly to web-browsers (that rely on the [public key infrastructure](https://en.wikipedia.org/wiki/Public_key_infrastructure)) and SSH (which relies on semi-automated fingerprint verification), Orchard combines these two traits in a hybrid approach by defaulting to automatic PKI verification (can be disabled by [`--no-pki`](#--no-pki-override)) and falling-back to a manual verification for self-signed certificates.

This hybrid approach is needed because the Controller can be configured in two ways:

* *Controller with a publicly valid certificate*
    * can be configured manually by passing `--controller-cert` and `--controller-key` command-line arguments to `orchard controller run`
* *Controller with a self-signed certificate*
    * configured automatically on first Controller start-up when no `--controller-cert` and `--controller-key` command-line arguments are passed

Below we'll explain how Orchard client and Worker secure the connection when accessing these two Controller types.

### Client

Client is associated with the Controller using a `orchard context create` command, which works as follows:

* Client attempts to connect to the Controller and validate its certificate using host's root CA set (can be disabled with [`--no-pki`](#--no-pki-override))
* if the Client encounters a  *Controller with a publicly valid certificate*, that would be the last step and the association would succeed
* if the Client is dealing with *Controller with a self-signed certificate*, the Client will do another connection attempt to probe the Controller's certificate
* the probed Controller's certificate fingerprint is then presented to the user, and if the user agrees to trust it, the Client then considers that certificate to be trusted for a given context
* Client finally connects to the Controller again with a trusted CA set containing only that certificate, executes the final API sanity checks, and if everything is OK then the association succeeds

Afterward, each interaction with the Controller  (e.g. `orchard create vm` command) will stick to the chosen verification method and will re-verify the presented Controller's certificate against:

* *Controller with a self-signed certificate*: a trusted certificate stored in the Orchard's configuration file
* *Controller with a publicly valid certificate*: host's root CA set

### Worker

To make the Worker connect to the Controller, a Bootstrap Token needs to be obtained using the `orchard get bootstrap-token` command.

While this approach provides a less ad-hoc experience than that you'd have with `orchard context create`, it allows one to mass-deploy workers non-interactively, using tools such as Ansible.

This resulting Bootstrap Token will either include the Controller's certificate (when the current context is with a *Controller with a self-signed certificate*) or omit it (when the current context is with a *Controller with a publicly valid certificate*).

The way Worker connects to the Controller using the `orchard worker run` command is as follows:

* when the Bootstrap Token contains the Controller's certificate:
    * the Orchard Worker will try to connect to the Controller with a trusted CA set containing only that certificate
* when the Bootstrap Token has no Controller's certificate:
    * the Orchard Worker will try the PKI approach (can be disabled with [`--no-pki`](#--no-pki-override) to effectively prevent the Worker from connecting) and fail if certificate verification using PKI is not possible

### `--no-pki` override

If you only intend to access the *Controller with a self-signed certificate* and want to additionally guard yourself against [CA compromises](https://en.wikipedia.org/wiki/Certificate_authority#CA_compromise) and other PKI-specific attacks, pass a `--no-pki` command-line argument to the following commands:

* `orchard context create --no-pki`
    * this will prevent the Client from using PKI and will let you interactively verify the Controller's certificate fingerprint before connecting, thus creating a non-PKI association
* `orchard worker run --no-pki`
    * this will prevent the Worker from trying to use PKI when connecting to the Controller using a Bootstrap Token that has no certificate included in it, thus failing fast and letting you know that you need to create a proper Bootstrap Token

We've deliberately chosen not to use environment variables (e.g. `ORCHARD_NO_PKI`) because they fail silently (e.g. due to a typo), compared to command-line arguments, which will result in an error that is much easier to detect.
