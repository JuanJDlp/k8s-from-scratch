# Ansible: clúster kubeadm (cluster.md Fases 1 a 4)

Terraform crea la infraestructura y escribe `inventories/aws/hosts.yml` con la IP
pública del bastión. Este proyecto configura los nodos, levanta el clúster y lo valida.

## Uso

```bash
make up        # terraform apply + ansible-playbook playbooks/site.yml (~10-15 min)
make down      # terraform destroy
```

O paso a paso:

```bash
terraform -chdir=terraform/infra apply
cd ansible
ansible-galaxy collection install -r requirements.yml
ansible-playbook playbooks/site.yml
```

Requisitos en tu PC: Ansible core 2.15+, la llave `~/.ssh/id_ed25519` (la misma
que `ssh_public_key_path` en Terraform).

## Estructura

```text
ansible/
├── ansible.cfg                  # inventario por defecto, SSH con ControlPersist
├── requirements.yml             # colecciones (ansible.posix, community.general)
├── inventories/aws/
│   ├── hosts.yml                # GENERADO por Terraform (no se versiona)
│   └── group_vars/
│       ├── all.yml              # versión de Kubernetes, CIDRs de Pods/Services
│       ├── bastions.yml         # solo kubectl
│       ├── k8s_cluster.yml      # firewalld común a master y workers
│       ├── control_plane.yml    # puertos del master
│       └── workers.yml          # puertos de los workers
├── playbooks/
│   ├── site.yml                 # todo, en orden
│   ├── bootstrap.yml            # espera SSH/cloud-init + rol common
│   ├── nodes.yml                # Fase 2 (+ kubectl en el bastión)
│   ├── control_plane.yml        # 3.1 kubeadm init
│   ├── bastion.yml              # 3.2-3.4 kubeconfig y Flannel
│   ├── workers.yml              # 3.5 kubeadm join
│   └── validate.yml             # Fase 4 nginx NodePort + CoreDNS
└── roles/
    ├── common                   # hostname, /etc/hosts, dnf update
    ├── k8s_prereqs              # swap, SELinux, módulos, sysctl
    ├── firewalld                # zonas trusted, masquerade, puertos
    ├── containerd               # containerd 2.x + SystemdCgroup
    ├── kubernetes_packages      # repo pkgs.k8s.io + kubeadm/kubelet/kubectl
    ├── kubeadm_control_plane    # kubeadm init con archivo de configuración
    ├── kubeadm_worker           # join con token de 15 min, etiqueta worker
    ├── kubectl_client           # admin.conf -> ~/.kube/config en el bastión
    ├── cni_flannel              # Flannel con la red de Pods de group_vars
    └── smoke_test               # validaciones de la Fase 4
```

| Grupo | Hosts | Acceso |
| --- | --- | --- |
| `bastions` | `bastion` | IP pública |
| `k8s_cluster` → `control_plane` | `master` | ProxyCommand por el bastión |
| `k8s_cluster` → `workers` | `worker` (o `worker01..N`) | ProxyCommand por el bastión |

Todo es idempotente: volver a ejecutar `site.yml` sobre un clúster existente no
repite `kubeadm init` ni `join` (se detectan por `admin.conf` y `kubelet.conf`).

## Ejecuciones parciales

```bash
ansible-playbook playbooks/site.yml --tags validate     # solo la Fase 4
ansible-playbook playbooks/nodes.yml --limit worker     # preparar un nodo
make ping                                               # probar conectividad
```

## Variables que normalmente cambiarías

| Variable | Dónde | Por defecto |
| --- | --- | --- |
| `k8s_version` | `group_vars/all.yml` | `1.37` |
| `k8s_pod_cidr` / `k8s_service_cidr` | `group_vars/all.yml` | `10.244.0.0/16` / `10.96.0.0/12` |
| `cni_flannel_version` | `roles/cni_flannel/defaults` | `latest` (fíjala en producción) |
| `common_upgrade_packages` | `roles/common/defaults` | `true` |
| `firewalld_trusted_interfaces` | `group_vars/k8s_cluster.yml` | `[]` (ver Solución de problemas en cluster.md) |

Nombres de hosts, dominio e IPs salen de Terraform (`worker_ips`, `dns_domain`...):
para agregar un worker, agrega su IP a `worker_ips` y repite `make up`.
