# Home-Share 🏠

Repositório de scripts e configurações úteis para homelab e automação.

## 📁 Estrutura do Repositório

* **[docker-composes](./docker-composes)**: Ficheiros Docker Compose, exportadores, restarters e dashboards de monitorização.
* **[backup-scripts](./backup-scripts)**: Scripts de backup para Proxmox VE e Incus, com retenção automática. O script Incus local inclui snapshots e notificações por email; o script Incus remoto exporta apenas as instâncias, sem snapshots.
* **[ssh-dashboard](./ssh-dashboard)**: Scripts para instalar dashboards de monitorização via SSH em sistemas x86, ARM64 e OpenMediaVault.
