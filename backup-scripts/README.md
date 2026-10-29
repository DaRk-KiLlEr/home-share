# Scripts de backup — Proxmox VE e Incus

Esta pasta contém scripts Bash para automatizar cópias de segurança no Proxmox VE e no Incus.

## Scripts disponíveis

- **[pve_bck_script.sh](./pve_bck_script.sh)** — recolhe backups do Proxmox VE através de SSH e aplica retenção por tipo e ID.
- **[incus_bck_script.sh](./incus_bck_script.sh)** — exporta instâncias Incus, incluindo os respetivos snapshots, aplica retenção por instância e envia um resumo por email.

## Incus — utilização

O script Incus foi preparado para o ambiente DARKPI. Antes de o utilizares noutro sistema, confirma e adapta as variáveis na secção **CONFIGURAÇÃO**:

- `MOUNT_POINT`: ponto de montagem do disco de backup.
- `BACKUP_DIR`: pasta de destino.
- `KEEP_LXC`: número de backups a manter por instância.
- `EMAIL_TO`: destinatário local para as notificações.

Executar manualmente:

```bash
chmod +x incus_bck_script.sh
./incus_bck_script.sh
```

O script verifica se o disco está montado e se o Incus está acessível, exporta cada instância e os seus snapshots, remove os backups mais antigos acima do limite configurado e termina com um resumo. O código de saída é `0` quando a execução termina sem erros e diferente de zero quando há erros.

### Agendamento semanal

Exemplo para executar aos domingos às 03:00:

```cron
0 3 * * 0 /caminho/para/incus_bck_script.sh >> /var/log/incus-backup.log 2>&1
```

Substitui o caminho pelo local onde guardaste o script.

### Envio de email no Incus

O script não configura nem envia email diretamente para um servidor SMTP externo. Usa o comando local `/usr/sbin/sendmail`, normalmente disponibilizado pelo sistema de email instalado no host.

Por omissão, `EMAIL_TO="root"`: a mensagem é entregue ao destinatário local `root`. No OpenMediaVault, configura o encaminhamento/notificações de email para que as mensagens destinadas a `root` cheguem à caixa de correio pretendida. Assim, o script reutiliza a configuração de email existente no OMV e não guarda credenciais SMTP.

São enviados emails com o resumo da execução e com o registo recolhido pelo script. Os assuntos distinguem sucesso, erros e ausência de instâncias. Para funcionar, `/usr/sbin/sendmail` tem de existir e o serviço de email do sistema tem de estar configurado.

## Nota

Os caminhos, os destinatários, a retenção e os parâmetros dos scripts são específicos do ambiente onde foram preparados. Revê a configuração antes de executar em produção.
