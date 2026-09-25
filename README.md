# Kubernetes from Scratch on AWS

A vanilla Kubernetes cluster built with **kubeadm** on AWS, fully automated with
**Terraform** (infrastructure) and **Ansible** (node configuration and cluster setup).
No managed services (EKS): every piece — container runtime, control plane, CNI,
DNS, firewall — is installed and wired up by hand, just automated.

One command builds everything:

```bash
make up     # ~10-15 min: AWS infrastructure + working Kubernetes cluster
make down   # destroy everything
```

## Architecture

```text
                        Internet
                           │
                  ┌────────┴────────┐
                  │ Internet Gateway│
                  └────────┬────────┘
 VPC 10.0.0.0/16           │
 ┌─────────────────────────┼──────────────────────────────────────┐
 │  Public subnet 10.0.1.0/24                                     │
 │   ┌──────────────────────┐        ┌─────────────┐              │
 │   │ bastion  10.0.1.10   │        │ NAT Gateway │              │
 │   │ (kubectl, SSH entry) │        └──────┬──────┘              │
 │   └──────────┬───────────┘               │ egress              │
 │              │ SSH / 6443 / NodePorts    │                     │
 │  Private subnet 10.0.2.0/24              │                     │
 │   ┌──────────┴───────────┐        ┌──────┴──────────────┐      │
 │   │ master   10.0.2.10   │◄──────►│ worker   10.0.2.20  │      │
 │   │ control plane + etcd │ Flannel│ kubelet, kube-proxy │      │
 │   └──────────────────────┘  VXLAN └─────────────────────┘      │
 │                                                                │
 │  Route 53 private zones: k8s.lab (A) + 0.10.in-addr.arpa (PTR) │
 └────────────────────────────────────────────────────────────────┘
```

| Component | Choice |
| --- | --- |
| OS | Rocky Linux 9 (official AMI) |
| Container runtime | containerd 2.x (systemd cgroup driver) |
| Kubernetes | kubeadm / kubelet / kubectl `1.37` from `pkgs.k8s.io` |
| CNI | Flannel (VXLAN), Pod CIDR `10.244.0.0/16` |
| Service CIDR | `10.96.0.0/12` |
| DNS | Route 53 private hosted zones (`bastion.k8s.lab`, `master.k8s.lab`, `worker.k8s.lab`) |
| Firewall | AWS security groups per role + firewalld on every node |
| Terraform state | S3 bucket with native lockfile (no DynamoDB) |

Only the bastion has a public IP, and SSH to it is restricted to your own IP.
The master and workers live in the private subnet and are reached through the bastion.

## Repository layout

```text
.
├── Makefile                  # make up / make down / make ping
├── terraform/
│   ├── bootstrap/            # one-time: S3 bucket for the remote Terraform state
│   ├── infra/                # VPC, security groups, EC2, Route 53, Ansible inventory
│   └── modules/
│       ├── networking/       # VPC, public/private subnets, IGW, NAT Gateway
│       ├── compute/          # EC2 instances (Rocky 9, IMDSv2, encrypted gp3, SSM role)
│       └── route53/          # private hosted zone + records
├── ansible/                  # roles and playbooks that build the cluster (see ansible/README.md)
└── test-deploy/              # sample app (podinfo) to try the cluster (see test-deploy/README.md)
```

## Prerequisites

On your machine:

| Tool | Version |
| --- | --- |
| [Terraform](https://developer.hashicorp.com/terraform/install) | `>= 1.10` |
| [Ansible](https://docs.ansible.com/ansible/latest/installation_guide/) | ansible-core `>= 2.15` |
| [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html) | v2 (for credentials) |
| `make`, `curl`, `ssh` | any |

You also need:

- **An AWS account** with credentials configured (`aws configure`, `AWS_PROFILE`, or
  environment variables) and permissions for EC2, VPC, Route 53, IAM and S3.
- **An SSH key pair** at `~/.ssh/id_ed25519` / `~/.ssh/id_ed25519.pub`. If you don't have one:

  ```bash
  ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519
  ```

> **Cost warning:** this creates billable resources (3 EC2 instances, a NAT Gateway,
> an Elastic IP and Route 53 zones). Run `make down` when you are done.

## Getting started

### 1. Clone the repository

```bash
git clone <repo-url> k8s-from-scratch
cd k8s-from-scratch
```

### 2. Create the Terraform state bucket (once per AWS account)

The `infra` stack stores its state in S3. The `bootstrap` stack creates that bucket
(named `k8s-from-scratch-tfstate-<your-account-id>`) and keeps its own state locally.

```bash
terraform -chdir=terraform/bootstrap init
terraform -chdir=terraform/bootstrap apply
terraform -chdir=terraform/bootstrap output -raw state_bucket
```

### 3. Point the backend to your bucket

`terraform/infra/backend.tf` contains the bucket name of the original author's account.
Replace it with the output of the previous step:

```hcl
terraform {
  backend "s3" {
    bucket       = "k8s-from-scratch-tfstate-<your-account-id>"
    key          = "infra/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }
}
```

### 4. (Optional) Configure variables

Everything has sensible defaults. The only required variable, `admin_cidr` (the IP
allowed to SSH into the bastion), is filled in automatically by the Makefile with your
current public IP. To override anything, create `terraform/infra/terraform.tfvars`:

```bash
cp terraform/infra/terraform.tfvars.example terraform/infra/terraform.tfvars
```

```hcl
admin_cidr          = "203.0.113.25/32"          # your public IP
ssh_public_key_path = "~/.ssh/id_ed25519.pub"
worker_ips          = ["10.0.2.20", "10.0.2.21"] # two workers -> worker01, worker02
```

Useful variables (see `terraform/infra/variables.tf` for all of them):

| Variable | Default | Description |
| --- | --- | --- |
| `region` | `us-east-1` | AWS region |
| `admin_cidr` | your IP (via Makefile) | CIDR allowed to SSH into the bastion |
| `ssh_public_key_path` / `ssh_private_key_path` | `~/.ssh/id_ed25519(.pub)` | Key installed on the VMs / used by Ansible |
| `worker_ips` | `["10.0.2.20"]` | One private IP per worker; the list length is the worker count |
| `dns_domain` | `k8s.lab` | Private Route 53 domain |
| `master_instance_type` / `worker_instance_type` | `c7i-flex.large` | 2 vCPU / 4 GiB |
| `bastion_instance_type` | `t3.micro` | |

Cluster-level settings (Kubernetes version, Pod/Service CIDRs) live in
`ansible/inventories/aws/group_vars/all.yml`.

### 5. Bring everything up

```bash
make up
```

This runs, in order:

1. `terraform init` + `terraform apply` in `terraform/infra` — creates the network,
   security groups, instances and DNS, and writes the Ansible inventory to
   `ansible/inventories/aws/hosts.yml`.
2. `ansible-galaxy collection install` — installs `ansible.posix` and `community.general`.
3. `ansible-playbook playbooks/site.yml` — configures the nodes and builds the cluster:

   | Step | Playbook | What it does |
   | --- | --- | --- |
   | Bootstrap | `bootstrap.yml` | Waits for SSH and cloud-init, sets FQDN hostnames, `/etc/hosts`, updates packages |
   | Node prep | `nodes.yml` | Disables swap, SELinux permissive, kernel modules and sysctl, firewalld, containerd, kubeadm/kubelet/kubectl |
   | Control plane | `control_plane.yml` | `kubeadm init` from a config file |
   | Bastion + CNI | `bastion.yml` | Copies `admin.conf` to the bastion's `~/.kube/config`, installs Flannel |
   | Workers | `workers.yml` | `kubeadm join` with a short-lived (15 min) token, labels nodes as `worker` |
   | Validation | `validate.yml` | Checks nodes are Ready, deploys nginx on a NodePort, tests CoreDNS |

   At the end, Ansible prints a summary of all nodes and Pods.

You can also run the two stages separately:

```bash
make infra     # only Terraform
make cluster   # only Ansible (infra must already exist)
make ping      # check Ansible can reach every host
```

The playbooks are idempotent: re-running `make up` on an existing cluster does not
re-run `kubeadm init` or `join`.

### 6. Use the cluster

All administration happens from the bastion, which already has `kubectl` configured.

```bash
BASTION=$(terraform -chdir=terraform/infra output -raw bastion_public_ip)
ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null rocky@$BASTION

kubectl get nodes -o wide
kubectl get pods -A
curl http://worker.k8s.lab:30080     # nginx deployed by the validation step
```

> The SSH options avoid *host key changed* errors: every time the infrastructure is
> recreated, the instances get new host keys behind the same IPs.

To SSH directly into any node, add the generated config to `~/.ssh/config`:

```bash
terraform -chdir=terraform/infra output -raw ssh_config >> ~/.ssh/config
ssh bastion    # or: ssh master / ssh worker (jumps through the bastion)
```

To try a real application (podinfo, with a web UI reachable from your browser through
an SSH tunnel), follow [`test-deploy/README.md`](test-deploy/README.md).

### 7. Tear it down

```bash
make down
```

This destroys everything created by `terraform/infra`. The state bucket from step 2 is
kept on purpose (`prevent_destroy`) so it can be reused; delete it manually if you no
longer need it.

## Common tasks

| Task | How |
| --- | --- |
| Add a worker | Add an IP to `worker_ips` and run `make up` again |
| Re-run only the validation | `cd ansible && ansible-playbook playbooks/site.yml --tags validate` |
| Re-prepare a single node | `cd ansible && ansible-playbook playbooks/nodes.yml --limit worker` |
| Change the Kubernetes version | `k8s_version` in `ansible/inventories/aws/group_vars/all.yml` (before creating the cluster) |
| Pin the Flannel version | `cni_flannel_version` in `ansible/roles/cni_flannel/defaults/main.yml` |
| Emergency access without SSH | Every instance has an SSM role: `aws ssm start-session --target <instance-id>` |

## Troubleshooting

- **SSH to the bastion times out:** your public IP changed. Run `make infra` again
  (the Makefile picks up the new IP) or update `admin_cidr` in `terraform.tfvars`.
- **`Error acquiring the state lock` / bucket not found:** check that `backend.tf` points
  to the bucket created in step 2 and that you are using the same AWS account/region.
- **Pods on different nodes can't talk to each other:** set
  `firewalld_trusted_interfaces: [cni0, flannel.1]` in
  `ansible/inventories/aws/group_vars/k8s_cluster.yml` and run `make cluster`.
- **A step failed halfway:** just run `make up` (or `make cluster`) again; it is safe to repeat.

More details on the Ansible side are in [`ansible/README.md`](ansible/README.md).
