# Docker Auto-Restarters & Exporter Watchdogs 🐳🔄

Esta pasta contém configurações de Docker Compose focadas na resiliência do ecossistema do Homelab, garantindo que os contentores e exportadores de métricas críticas reiniciam automaticamente em caso de quebra ou falha.

## 🚀 Restarters de Sistema Geral
* **exited_container_restarter.yaml**: Monitoriza o socket do Docker e força o reinício imediato de qualquer contentor que pare inesperadamente (estado *Exited*).
* **unhealthy_container_restarter.yaml**: Monitoriza os *Healthchecks* do Docker. Se um contentor ficar bloqueado ou perder conectividade (estado *Unhealthy*), força um reinício limpo do serviço.

## 📊 Watchdogs de Exporters (Monitorização)
* **adguard-exporter_restarter.yaml**: Garante a disponibilidade do exportador de métricas do AdGuard Home.
* **nut-exporter_restarter.yaml**: Monitoriza o exportador do Network UPS Tools (NUT), crítico para garantir que os dados da UPS/Bateria não falham na recolha.
* **redis-unbound-exporter_restarter.yaml**: Assegura a estabilidade dos exportadores do Redis e do servidor DNS Unbound.

## 🛠️ Como Utilizar
1. Garante que os caminhos para o socket do Docker (`/var/run/docker.sock`) estão corretamente mapeados no ficheiro, caso a automação precise de interagir com o motor do Docker.
2. Inicie a stack pretendida com o comando:
   ```bash
   docker compose -f nome_do_ficheiro.yaml up -d
   ```
