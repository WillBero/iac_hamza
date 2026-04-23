# Kubernetes on Azure — IaC & Automation

Déploiement automatisé d'un cluster Kubernetes sur Azure via **Terraform** (infrastructure) et **Ansible** (configuration), orchestré par un pipeline **GitHub Actions**.

---

## Architecture

```
GitHub Actions
    ├── Terraform → Azure VMs (1 control plane + N workers)
    └── Ansible  → Hardening + Installation Kubernetes
```

### Infrastructure (Terraform)

| Ressource | Détail |
|---|---|
| Resource Group | `rg-wber-euw` — West Europe |
| Virtual Network | `wber-vnet` — `10.0.0.0/16` |
| Subnet | `wber-subnet` — `10.0.1.0/24` |
| VMs | Ubuntu 22.04 LTS, `Standard_D2s_v3`, disque 30 Go |
| IPs publiques | Statiques (Standard SKU), une par VM |
| NSG | SSH (22), Kubernetes API (6443), trafic interne VNet |

Par défaut : **3 VMs** — 1 control plane (`k8s-control-plane`) + 2 workers (`k8s-worker-1`, `k8s-worker-2`).

### Configuration (Ansible)

Deux rôles appliqués dans l'ordre :

1. **`hardening`** — sécurisation OS (SSH, UFW)
2. **`kubernetes_install`** — prérequis, control plane, workers

---

## Prérequis

- Un **Service Principal Azure** avec les droits `Contributor` sur la subscription
- Un **Storage Account Azure** pour le backend Terraform (state distant)
- Les secrets GitHub Actions suivants configurés dans le repo :

| Secret | Description |
|---|---|
| `ARM_SUBSCRIPTION_ID` | ID de la subscription Azure |
| `ARM_CLIENT_ID` | `appId` du Service Principal |
| `ARM_CLIENT_SECRET` | Secret du Service Principal |
| `ARM_TENANT_ID` | Tenant ID Azure |
| `SSH_PUBLIC_KEY` | Clé publique SSH injectée dans les VMs |
| `SSH_PRIVATE_KEY` | Clé privée SSH utilisée par Ansible |

---

## Déploiement

Le pipeline se déclenche **manuellement** via `workflow_dispatch` dans GitHub Actions.

### Déployer

1. Aller dans **Actions → Terraform + Ansible**
2. Cliquer **Run workflow**
3. Sélectionner `deploy`

Le pipeline exécute :
- `terraform init / plan / apply`
- Génération dynamique de l'inventaire Ansible
- Attente SSH sur toutes les VMs
- `ansible-playbook playbook.yaml`

### Détruire

Même procédure, sélectionner `destroy` — exécute `terraform destroy`.

---

## Structure du projet

```
.
├── terraform/
│   ├── main.tf            # Provider Azure + Resource Group
│   ├── network.tf         # VNet, Subnet, NSG, IPs, NICs
│   ├── compute.tf         # VMs Linux
│   ├── variables.tf       # Variables d'entrée
│   ├── outputs.tf         # IPs exportées
│   ├── backend.tf         # Backend Azure Blob Storage
│   └── terraform.tfvars   # Valeurs (⚠️ ne pas committer en prod)
├── ansible/
│   ├── ansible.cfg
│   ├── playbook.yaml
│   └── roles/
│       ├── hardening/
│       │   ├── tasks/main.yaml
│       │   └── handlers/main.yml
│       └── kubernetes_install/
│           └── tasks/
│               ├── main.yaml
│               ├── prerequesites.yaml
│               ├── control_plane.yaml
│               ├── workers.yaml
│               └── test.yaml
└── .github/workflows/
    └── deploy.yml
```

---

## Détail des rôles Ansible

### `hardening`

- Mise à jour des paquets APT
- Désactivation du login SSH root (`PermitRootLogin no`)
- Désactivation de l'authentification par mot de passe
- Installation et configuration de **UFW** :
  - Port 22 (SSH)
  - Port 6443 (Kubernetes API)
  - Port 10250 (kubelet)
  - Ports 30000–32767 (NodePort)
  - Politique par défaut : `deny`

### `kubernetes_install`

**`prerequesites.yaml`** (tous les nœuds) :
- Désactivation du swap
- Installation de `containerd`, `kubelet`, `kubeadm`, `kubectl` (v1.29)
- Activation du forwarding IP et des modules kernel (`br_netfilter`, `overlay`)
- Configuration sysctl pour Kubernetes

**`control_plane.yaml`** (si non initialisé) :
- `kubeadm init --pod-network-cidr=10.244.0.0/16`
- Configuration du kubeconfig pour `azureuser`

**`workers.yaml`** (si non joint) :
- Récupération du token `kubeadm join` depuis le control plane
- Jonction au cluster

**`test.yaml`** — vérification idempotente avant init/join pour éviter de reconfigurer un cluster existant.

---

## Variables Terraform

| Variable | Défaut | Description |
|---|---|---|
| `location` | `West Europe` | Région Azure |
| `vm_count` | `3` | Nombre total de VMs |
| `vm_size` | `Standard_D2s_v3` | Taille des VMs |
| `admin_username` | `azureuser` | Utilisateur admin SSH |
| `ssh_public_key` | — | Clé publique SSH (obligatoire) |

---

## Sécurité

> ⚠️ Le fichier `terraform.tfvars` contient des credentials en clair. **Ne jamais le committer dans un repo public.** Ajouter `terraform.tfvars` au `.gitignore` et utiliser exclusivement les secrets GitHub Actions en environnement CI/CD.
