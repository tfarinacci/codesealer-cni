# Codesealer CNI plugin

For Ingress Controllers or application pods on a Kubernetes Cluster this CNI will pre-route all traffic to/from the pods to go through the
Codesealer reverse proxies (codesealer-proxy containers).  This `codesealer-cni` Container Network Interface (CNI) plugin will
set up the pods' networking to fulfill this requirement in place of the current Codesealer injected pod `initContainers`
`codesealer-init-networking` approach.

This is currently accomplished via configuring the iptables rules in the netns for the pods.

The CNI handling the netns setup replaces the current Codesealer approach using a `NET_ADMIN` privileged
`initContainers` container, `codesealer-init-networking`, injected in the pods along with `codesealer-proxy` sidecars.  This
removes the need for a privileged, `NET_ADMIN` container in the Codesealer users' application pods.

## Usage

A complete set of instructions on how to use and install the Codesealer CNI is available on the Codesealer documentation site under [Install Codesealer with the Codesealer CNI plugin](https://codesealer.com/latest/docs/setup/cni/).

## Troubleshooting

### Validate the iptables are modified

1. Collect your pod's container id using kubectl.

    ```console
    $ ns=test-codesealer
    $ podnm=reviews-v1-6b7f6db5c5-59jhf
    $ container_id=$(kubectl get pod -n ${ns} ${podnm} -o jsonpath="{.status.containerStatuses[?(@.name=='codesealer-proxy')].containerID}" | sed -n 's/docker:\/\/\(.*\)/\1/p')
    ```

1. SSH into the Kubernetes worker node that runs your pod.

1. Use `nsenter` (or `ip netns exec`) to view the iptables.

    ```console
    $ cpid=$(docker inspect --format '{{ .State.Pid }}' $container_id)
    $ nsenter -t $cpid -n iptables -L -t nat -n -v --line-numbers -x
    ```

### Collecting Logs

#### From a specific node syslog

The CNI plugins are executed by threads in the `kubelet` process.  The CNI plugins logs end up the syslog
under the `kubelet` process. On systems with `journalctl` the following is an example command line
to view the last 1000 `kubelet` logs via the `less` utility to allow for `vi`-style searching:

```console
$ journalctl -t kubelet -n 1000 | less
```

#### GKE via Stackdriver Log Viewer

Each GKE cluster's will have many categories of logs collected by Stackdriver.  Logs can be monitored via
the project's [log viewer](https://cloud.google.com/logging/docs/view/overview) and/or the `gcloud logging read`
capability.

The following example grabs the last 10 `kubelet` logs containing the string "cmdAdd" in the log message.

```console
$ gcloud logging read "resource.type=k8s_node AND jsonPayload.SYSLOG_IDENTIFIER=kubelet AND jsonPayload.MESSAGE:cmdAdd" --limit 10 --format json
```

## API

Codesealer CNI injection is currently based on the same Pod annotations used in init-container/inject mode.


### Selection API

- plugin config "exclude namespaces" applies first
- sidecar interception is enabled if:
    - "init-networking" container is not present in the pod.
    - codesealer-core container exists and
        - has a namespace label "codesealer.com/webhook" which is enabled
        - has a pod annotation "codesealer.com/injection" which is enabled
        - has a pod annotation "codesealer.com/dport" which specifies the port to pre-route

## Implementation Details

### Overview

- [codesealer-cni Helm chart](../manifests/charts/codesealer-cni/templates)
    - `codesealer-install-cni` daemonset - main function is to install and help the node CNI, but it is also a proper server and interacts with K8S, watching Pods for recovery.
    - `codesealer-cni-config` configmap with CNI plugin config to add to CNI plugin chained config
    - creates service-account `codesealer-cni` with `ClusterRoleBinding` to allow gets on pods' info and delete/modifications for recovery.

- `codesealer-install-cni` container
    - copies `codesealer-cni` and `codesealer-iptables` to `/opt/cni/bin`
    - creates kubeconfig for the service account the pod runs under
    - periodically copy the K8S JWT token for codesealer-cni on the host to connect to K8S.
    - injects the CNI plugin config to the CNI config file
        - CNI installer will try to look for the config file under the mounted CNI net dir based on file name extensions (`.conf`, `.conflist`)
        - the file name can be explicitly set by `CNI_CONF_NAME` env var
        - the program inserts `CNI_NETWORK_CONFIG` into the `plugins` list in `/etc/cni/net.d/${CNI_CONF_NAME}`
    - the actual code is in pkg/install - including a readiness probe, monitoring.
    - it also sets up a UDS socket for codesealer-cni to send logs to this container.
    - based on config, it may run the 'repair' controller that detects pods where codesealer setup fails and restarts them, or created in corner cases.

- `codesealer-cni`
    - CNI plugin executable copied to `/opt/cni/bin`
    - currently implemented for k8s only
    - on pod add, determines whether pod should have netns setup to redirect to Codesealer proxy. See [cmdAdd](#cmdadd-workflow) for detailed logic.
        - it connects to K8S using the kubeconfig and JWT token copied from codesealer-install-cni to get Pod and Namespace. Since this is a short-running command, each invocation creates a new connection.
        - If so, calls `codesealer-iptables` with params to setup pod netns

- `codesealer-iptables`
    - sets up iptables to redirect a list of ports to the port envoy will listen
    - shared code with codesealer-init container
    - it will generate an iptables-save config, based on annotations/labels and other settings, and apply it.

### CmdAdd Workflow

`CmdAdd` is triggered when there is a new pod created. This runs on the node, in a chain of CNI plugins - Codesealer is
run after the main CNI sets up the pod IP and networking.

1. Check k8s pod namespace against exclusion list (plugin config)
    - Config must exclude namespace that Codesealer control-plane is installed in (TODO: this may change, exclude at pod level is sufficient and we may want 
    - If excluded, ignore the pod and return prevResult
1. Setup redirect rules for the pods:
    - Get the port list from pods definition, as well as annotations.
    - Setup iptables with required port list: `nsenter --net=<k8s pod netns> /opt/cni/bin/codesealer-iptables ...`. Following conditions will prevent the redirect rules to be setup in the pods:
        - Pods have annotation `codesealer.com/injection` set to `false` or has no key `sidecar.codesealer.com/status` in annotations
        - Pod has `codesealer-init-networking` initContainer - this indicates a pod running its own injection setup.
1. Return prevResult

## Reference

The framework for this implementation of the CNI plugin is based on the
[containernetworking sample plugin](https://github.com/containernetworking/plugins/tree/main/plugins/sample)

The details for the deployment & installation of this plugin were pretty much lifted directly from the
[Calico CNI plugin](https://github.com/projectcalico/cni-plugin).

Specifically:

- The CNI installation script is containerized and deployed as a daemonset in k8s.  The relevant calico k8s manifests were used as the model for the codesealer-cni plugin's manifest:
    - [daemonset and configmap](https://docs.projectcalico.org/v3.2/getting-started/kubernetes/installation/hosted/calico.yaml) - search for the `calico-node` Daemonset and its `codesealer-install-cni` container deployment
    - [RBAC](https://docs.projectcalico.org/v3.2/getting-started/kubernetes/installation/rbac.yaml) - this creates the service account the CNI plugin is configured to use to access the kube-api-server

The installation program `codesealer-install-cni` injects the `codesealer-cni` plugin config at the end of the CNI plugin chain
config.  It creates or modifies the file from the configmap created by the Kubernetes manifest.

## TODO

- Watch configmaps or CRDs and update the `codesealer-cni` plugin's config with these options.