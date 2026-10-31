# Scripts de backup — Proxmox VE e Incus

Esta pasta contém scripts Bash para executar cópias de segurança no Proxmox VE e no Incus.

## Scripts disponíveis

- **[pve_bck_script.sh](./pve_bck_script.sh)** — recolhe backups do Proxmox VE através de SSH e aplica retenção por tipo e ID.
- **[incus_bck_script.sh](./incus_bck_script.sh)** — exporta instâncias Incus, incluindo os respetivos snapshots, aplica retenção por instância e envia um resumo por email.
- **[incus_bck_script_remote.sh](./incus_bck_script_remote.sh)** — executa a partir de outra máquina, liga-se ao servidor Incus por SSH e guarda os exports no próprio servidor Incus. **Exporta apenas as instâncias, sem incluir snapshots.**

## Incus — script local

Antes de utilizar o script local noutro sistema, confirma e adapta as variáveis na secção CONFIGURAÇÃO, incluindo destino, retenção e destinatário das notificações.

Executar manualmente:

```bash
chmod +x incus_bck_script.sh
./incus_bck_script.sh
```

O script exporta cada instância e os respetivos snapshots, aplica a retenção configurada e termina com um resumo. O código de saída é 0 quando termina sem erros e diferente de zero quando há erros.

### Envio de email no script local

O envio utiliza o comando local /usr/sbin/sendmail, normalmente disponibilizado pelo sistema de email instalado no host. Por omissão, EMAIL_TO="root": a mensagem é entregue ao destinatário local root. Configura o encaminhamento de email no sistema para que as mensagens cheguem à caixa pretendida.

O script não configura SMTP externo nem guarda credenciais SMTP. Para funcionar, /usr/sbin/sendmail tem de existir e o serviço de email do sistema tem de estar configurado.

## Incus — script remoto

O script remoto é executado na máquina que inicia o backup. Liga-se ao servidor Incus por SSH, executa os exports no servidor e guarda os ficheiros no caminho definido em BACKUP_DIR.

**Importante:** o script remoto utiliza a opção `--instance-only` do Incus. Os backups incluem apenas o estado da instância no momento da exportação; **não incluem os snapshots**. Os snapshots existentes permanecem no servidor Incus e não são apagados nem alterados pelo backup.

Antes da primeira execução, adapta estas variáveis na secção CONFIGURAÇÃO:

- BACKUP_HOST: hostname ou endereço IP do servidor Incus.
- BACKUP_USER e BACKUP_PASS: utilizador e palavra-passe SSH.
- SSH_PORT: porta SSH do servidor.
- BACKUP_DIR: diretório de destino no servidor Incus.
- KEEP_LXC: número de backups a manter por instância.

Requisitos na máquina que executa o script: Bash, ssh e sshpass. No servidor remoto: SSH funcional, Incus acessível pelo utilizador configurado e disco de destino montado.

Executar manualmente:

```bash
chmod +x incus_bck_script_remote.sh
./incus_bck_script_remote.sh
```

O script verifica a ligação SSH, o acesso ao Incus e se o destino pertence a um sistema de ficheiros montado diferente da raiz. Exporta cada instância **sem os respetivos snapshots**, mantém os backups mais recentes por instância de acordo com KEEP_LXC e apresenta um resumo no final.

O script não depende de um agendador específico. Pode ser executado manualmente ou integrado no mecanismo de agendamento que preferires.

## Proxmox VE

Consulta os comentários e a secção de configuração de pve_bck_script.sh antes de o executar. Confirma os caminhos, os acessos SSH e as políticas de retenção adequadas ao teu ambiente.

## Nota

Os caminhos, credenciais, destinatários, parâmetros e políticas de retenção são específicos do ambiente onde os scripts foram preparados. Revê a configuração antes de executar em produção.
