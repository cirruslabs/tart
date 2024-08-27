## Introduction

Compared to Worker, which needs to be deployed on a macOS machine, Controller can be deployed on Linux too.

In fact, we've made a [container image](https://github.com/cirruslabs/orchard/pkgs/container/orchard) to ease deploying the Controller in container-native environments such as Kubernetes.

Orchard API is secured by default: all requests must be authenticated with credentials of a service account.
When you first run Orchard Controller, you can specify `ORCHARD_BOOTSTRAP_ADMIN_TOKEN` which will automatically
create a service account named `bootstrap-admin` with all privileges. Let's first generate `ORCHARD_BOOTSTRAP_ADMIN_TOKEN`:

```bash
export ORCHARD_BOOTSTRAP_ADMIN_TOKEN=$(openssl rand -hex 32)
```

## Deployment Methods

While you can always run `orchard controller run` manually with the required arguments, this method of deploying the Controller is not recommended.

Instead, we've listed a more persistent methods of a Controller deployment below.

Now you can run Orchard Controller on a server of your choice. In the following sections you'll find several examples of
how to run Orchard Controller in various environments. Feel free to submit PRs with more examples.

### Google Compute Engine

An example below will deploy a single instance of Orchard Controller in Google Cloud Compute Engine in `us-central1` region.

First, let's create a static IP address for our instance:

```bash
gcloud compute addresses create orchard-ip --region=us-central1
export ORCHARD_IP=$(gcloud compute addresses describe orchard-ip --format='value(address)' --region=us-central1)
```

Once we have the IP address, we can create a new instance with Orchard Controller running inside a container:

```bash
gcloud compute instances create-with-container orchard-controller \
  --machine-type=e2-micro \
  --zone=us-central1-a \
  --image-family cos-stable \
  --image-project cos-cloud \
  --tags=https-server \
  --address=$ORCHARD_IP \
  --container-image=ghcr.io/cirruslabs/orchard:latest \
  --container-env=PORT=443 \
  --container-env=ORCHARD_BOOTSTRAP_ADMIN_TOKEN=$ORCHARD_BOOTSTRAP_ADMIN_TOKEN \
  --container-mount-host-path=host-path=/home/orchard-data,mode=rw,mount-path=/data
```

Now you can create a new context for your local client:

```bash
orchard context create --name production \
  --service-account-name bootstrap-admin \
  --service-account-token $ORCHARD_BOOTSTRAP_ADMIN_TOKEN \
  https://$ORCHARD_IP:443
```

And select it as the default context:

```bash
orchard context default production
```
