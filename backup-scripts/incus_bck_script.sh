#!/bin/bash

# ============================================================
# Incus Backup
# ============================================================

set -u

# ------------------------------------------------------------
# CONFIGURAÇÃO
# ------------------------------------------------------------

MOUNT_POINT="/srv/dev-disk-by-uuid-855d825e-344a-47f8-8886-98c4db45f990"
BACKUP_DIR="$MOUNT_POINT/proxmox_backup/darkpi_incus"
KEEP_LXC=4

# Envia para root; o sistema de email do OMV encaminha para a
# caixa de correio configurada nas notificações.
EMAIL_TO="root"

# ------------------------------------------------------------
# CONTADORES
# ------------------------------------------------------------

CHECKED=0
COPIED=0
SKIPPED=0
REMOVED=0
ERRORS=0

START_TIME=$(date +%s)
LOG_BUFFER=""

# ------------------------------------------------------------
# FUNÇÕES
# ------------------------------------------------------------

log() {
    local MSG="[$(date '+%H:%M:%S')] $*"
    echo "$MSG"
    LOG_BUFFER+="$MSG"$'\n'
}

send_email() {
    local SUBJECT="$1"
    local BODY="$2"

    if [ ! -x /usr/sbin/sendmail ]; then
        echo "ERRO: /usr/sbin/sendmail não está disponível." >&2
        return 1
    fi

    /usr/sbin/sendmail -t <<EOF
To: ${EMAIL_TO}
Subject: ${SUBJECT}
Content-Type: text/plain; charset=UTF-8

${BODY}
EOF
}

abort_backup() {
    local REASON="$1"
    local DATE_NOW
    DATE_NOW=$(date '+%d/%m/%Y %H:%M:%S')

    log "ERRO: $REASON"
    local BODY="Backup Incus - DARKPI

Data: $DATE_NOW
Destino: $BACKUP_DIR
Estado: ERRO

Motivo:
$REASON

Registo da execução:
$LOG_BUFFER"

    send_email "[DARKPI] Incus Backup - ERRO" "$BODY" || true
    exit 1
}

# ------------------------------------------------------------
# CABEÇALHO
# ------------------------------------------------------------

echo
echo "════════════════════════════════════════════════════════════"
echo " Incus Backup (DARKPI)"
echo "════════════════════════════════════════════════════════════"
echo " Host        : $(hostname)"
echo " Destino     : $BACKUP_DIR"
echo " Retenção    : $KEEP_LXC backups por instância"
echo " Início      : $(date '+%d/%m/%Y %H:%M:%S')"
echo "════════════════════════════════════════════════════════════"
echo

# ------------------------------------------------------------
# VERIFICAÇÕES
# ------------------------------------------------------------

log "A verificar se o HDD está montado..."

if ! mountpoint -q "$MOUNT_POINT"; then
    abort_backup "O disco de backup não está montado em $MOUNT_POINT"
fi

log "HDD montado"

log "A verificar o Incus..."

if ! command -v incus >/dev/null 2>&1 || ! incus list >/dev/null 2>&1; then
    abort_backup "Incus não está instalado ou não está acessível"
fi

log "Incus acessível"

log "A verificar o espaço disponível..."

if ! df -h "$MOUNT_POINT"; then
    abort_backup "Não foi possível verificar o espaço disponível no destino"
fi

if ! mkdir -p "$BACKUP_DIR"; then
    abort_backup "Não foi possível criar/aceder ao destino $BACKUP_DIR"
fi

log "A procurar instâncias Incus..."

INSTANCE_LIST=$(incus list --format csv -c n 2>/dev/null) || abort_backup "Não foi possível listar as instâncias Incus"

if [ -z "$INSTANCE_LIST" ]; then
    log "Nenhuma instância Incus encontrada."
    END_TIME=$(date +%s)
    DURATION=$((END_TIME - START_TIME))
    printf -v DURATION_FMT '%02d:%02d:%02d' $((DURATION / 3600)) $(((DURATION % 3600) / 60)) $((DURATION % 60))

    BODY="Backup Incus - DARKPI

Data: $(date '+%d/%m/%Y %H:%M:%S')
Destino: $BACKUP_DIR
Retenção: $KEEP_LXC backups por instância

Instâncias verificadas: 0
Backups concluídos: 0
Backups removidos: 0
Erros: 0

Duração: $DURATION_FMT
Estado: SEM INSTÂNCIAS

Registo da execução:
$LOG_BUFFER"

    send_email "[DARKPI] Incus Backup - Sem instâncias" "$BODY" || true
    exit 0
fi

# ------------------------------------------------------------
# EXPORTAR INSTÂNCIAS E APLICAR RETENÇÃO
# ------------------------------------------------------------

while IFS= read -r INSTANCE; do
    [ -z "$INSTANCE" ] && continue

    CHECKED=$((CHECKED + 1))
    log "Instância: $INSTANCE"
    log "A exportar instância e snapshots..."

    TIMESTAMP=$(date '+%Y_%m_%d-%H_%M_%S')
    BACKUP_FILE="incus-${INSTANCE}-${TIMESTAMP}.tar.gz"
    FINAL_FILE="$BACKUP_DIR/$BACKUP_FILE"
    TEMP_FILE="$BACKUP_DIR/.${BACKUP_FILE}.tmp"

    if incus export "$INSTANCE" "$TEMP_FILE"; then
        if mv "$TEMP_FILE" "$FINAL_FILE"; then
            COPIED=$((COPIED + 1))
            log "Backup concluído: $BACKUP_FILE"
        else
            rm -f "$TEMP_FILE"
            ERRORS=$((ERRORS + 1))
            log "ERRO: Não foi possível finalizar o ficheiro de backup de $INSTANCE"
            continue
        fi
    else
        rm -f "$TEMP_FILE"
        ERRORS=$((ERRORS + 1))
        log "ERRO: Falha ao exportar a instância $INSTANCE"
        continue
    fi

    log "A verificar retenção..."

    mapfile -t INSTANCE_BACKUPS < <(
        find "$BACKUP_DIR" -maxdepth 1 -type f -name "incus-${INSTANCE}-*.tar.gz" -printf '%f\n' |
        sort -r
    )

    if [ "${#INSTANCE_BACKUPS[@]}" -le "$KEEP_LXC" ]; then
        log "Retenção dentro do limite"
        continue
    fi

    for ((i=KEEP_LXC; i<${#INSTANCE_BACKUPS[@]}; i++)); do
        OLD_FILE="${INSTANCE_BACKUPS[$i]}"
        log "A remover backup antigo: $OLD_FILE"

        if rm -f -- "$BACKUP_DIR/$OLD_FILE"; then
            REMOVED=$((REMOVED + 1))
            log "Backup antigo removido: $OLD_FILE"
        else
            ERRORS=$((ERRORS + 1))
            log "ERRO: Não foi possível remover $OLD_FILE"
        fi
    done
done <<< "$INSTANCE_LIST"

# ------------------------------------------------------------
# RESUMO E NOTIFICAÇÃO
# ------------------------------------------------------------

END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))
printf -v DURATION_FMT '%02d:%02d:%02d' \
    $((DURATION / 3600)) \
    $(((DURATION % 3600) / 60)) \
    $((DURATION % 60))

echo
echo "════════════════════════════════════════════════════════════"
echo " RESUMO"
echo "════════════════════════════════════════════════════════════"
echo " Verificadas : $CHECKED"
echo " Concluídos  : $COPIED"
echo " Removidos   : $REMOVED"
echo " Erros       : $ERRORS"
echo " Duração     : $DURATION_FMT"

if [ "$ERRORS" -eq 0 ]; then
    STATUS="CONCLUÍDO COM SUCESSO"
    SUBJECT="[DARKPI] Incus Backup - Sucesso"
else
    STATUS="CONCLUÍDO COM ERROS"
    SUBJECT="[DARKPI] Incus Backup - ERROS"
fi

echo " Estado      : $STATUS"
echo "════════════════════════════════════════════════════════════"
echo

BODY="Backup Incus - DARKPI

Data: $(date '+%d/%m/%Y %H:%M:%S')
Destino: $BACKUP_DIR
Retenção: $KEEP_LXC backups por instância

Instâncias verificadas: $CHECKED
Backups concluídos: $COPIED
Backups removidos: $REMOVED
Erros: $ERRORS

Duração: $DURATION_FMT
Estado: $STATUS

Registo da execução:
$LOG_BUFFER"

if ! send_email "$SUBJECT" "$BODY"; then
    echo "ERRO: Não foi possível submeter o email através de /usr/sbin/sendmail." >&2
    ERRORS=$((ERRORS + 1))
fi

exit "$ERRORS"
