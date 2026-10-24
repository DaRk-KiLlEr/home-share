# Docker Auto-Restarters & Exporter Watchdogs 🐳🔄

Esta pasta contém configurações de Docker Compose focadas na resiliência do ecossistema do Homelab, garantindo que os contentores e exportadores de métricas críticas reiniciam ou atualizam automaticamente em caso de quebra ou falha.

## 🚀 Restarters de Sistema Geral
* **exited_container_restarter.yaml**: Verifica a cada 10 minutos os contentores no estado *Exited* e tenta iniciá-los. Não reinicia o próprio watchdog.
* **unhealthy_container_restarter.yaml**: Verifica a cada 10 minutos os *Healthchecks* do Docker e reinicia os contentores no estado *Unhealthy*.
* **nickfedor.watchtower.yaml**: Monitoriza e atualiza automaticamente os contentores Docker para as versões mais recentes das imagens, conforme a configuração do Watchtower.

## 📊 Exporters (Monitorização)
* **adguard-exporter.yaml**: Exporta métricas de três instâncias AdGuard Home na porta 9617 para recolha pelo Prometheus. Consulta **[adguard-exporter.txt](./adguard-exporter.txt)** para os passos de configuração.
* **adguard-home-dashboard.json**: Dashboard Grafana personalizada **AdGuard Home Monitoring**, exportada da configuração em uso. As instruções de importação estão no ficheiro TXT do AdGuard.

## 🔄 Watchdogs de Exporters (Monitorização)
* **adguard-exporter_restarter.yaml**: Procura erros específicos nos logs do exportador AdGuard Home e reinicia-o quando o limite configurado é atingido.
* **fail2ban-prometheus-exporter_restarter.yaml**: Procura as mensagens `no such file or directory` e `connection refused` nos logs do `fail2ban-prometheus-exporter`; consulta **[fail2ban-prometheus-exporter_restarter.txt](./fail2ban-prometheus-exporter_restarter.txt)**.
* **nut-exporter_restarter.yaml**: Monitoriza o exportador do Network UPS Tools (NUT) e reinicia-o quando encontra o erro configurado.
* **redis-unbound-exporter_restarter.yaml**: Monitoriza os logs do exportador Redis/Unbound e reinicia-o quando encontra o erro configurado.

## ⚙️ Correção comum dos watchdogs Docker CLI
Os Compose dos watchdogs que usam `image: docker:cli` definem `entrypoint: []`. Isto limpa o ENTRYPOINT predefinido da imagem e permite que o `command` execute `/bin/sh -c`, em vez de passar o shell como argumento ao comando `docker`.

## 🛠️ Como Utilizar
1. Confirma que o nome do contentor alvo no script corresponde ao nome real no Docker.
2. Garante que o socket do Docker (`/var/run/docker.sock`) está corretamente mapeado quando o watchdog precisa de controlar outros contentores.
3. Inicia a stack pretendida:
   ```bash
   docker compose -f nome_do_ficheiro.yaml up -d
   ```
4. Consulta os logs do watchdog para verificar deteções e reinícios:
   ```bash
   docker logs --tail 100 nome_do_watchdog
   ```

**Nota:** os restarters são automações baseadas em condições específicas. Um contentor parado manualmente também pode ser iniciado pelo `exited_container_restarter`; um contentor `unhealthy` pode ser reiniciado mesmo que esteja temporariamente a recuperar.
