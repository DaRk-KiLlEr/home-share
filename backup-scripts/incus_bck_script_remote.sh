#!/bin/bash

# ============================================================
# Incus Backup Pull (remoto)
# ============================================================

set -u

# ------------------------------------------------------------
# CONFIGURAÇÃO
# ------------------------------------------------------------

BACKUP_HOST="hostname/ip"
BACKUP_USER="user"
BACKUP_PASS="password"
SSH_PORT=22

# Destino dos backups no servidor Incus
BACKUP_DIR="/srv/dev-disk-by-uuid-855d825e-344a-47f8-8886-98c4db45f990/proxmox_backup/darkpi_incus"

KEEP_LXC=4

# ------------------------------------------------------------
# CONTADORES
# ------------------------------------------------------------

CHECKED=0
COPIED=0
REMOVED=0
ERRORS=0
START_TIME=$(date +%s)

# ------------------------------------------------------------
# FUNÇÕES
# ------------------------------------------------------------

log() {
    echo "[$(date '+%H:%M:%S')] $*"
}

ssh_source() {
    SSHPASS="$BACKUP_PASS" sshpass -e \
        ssh -n -p "$SSH_PORT" \
        -o StrictHostKeyChecking=accept-new \
        -o ConnectTimeout=10 \
        "$BACKUP_USER@$BACKUP_HOST" "$@"
}

# ------------------------------------------------------------
# CABEÇALHO
# ------------------------------------------------------------

echo
echo "════════════════════════════════════════════════════════════"
echo " Incus Backup Pull"
echo "════════════════════════════════════════════════════════════"
echo " Host origem : $BACKUP_HOST"
echo " Destino     : $BACKUP_DIR"
echo " Retenção    : $KEEP_LXC backups por instância"
echo " Início      : $(date '+%d/%m/%Y %H:%M:%S')"
echo "════════════════════════════════════════════════════════════"
echo

# ------------------------------------------------------------
# VERIFICAÇÕES
# ------------------------------------------------------------

log "A verificar dependências locais..."

if ! command -v sshpass >/dev/null 2>&1; then
    log "ERRO: sshpass não está instalado"
    exit 1
fi

log "A verificar ligação ao servidor Incus..."

if ! ssh_source "true" >/dev/null 2>&1; then
    log "ERRO: Não foi possível ligar ao servidor Incus"
    exit 1
fi

log "A verificar o Incus no servidor remoto..."

if ! ssh_source "command -v incus >/dev/null 2>&1 && incus list >/dev/null 2>&1"; then
    log "ERRO: Incus não está instalado ou não está acessível"
    exit 1
fi

log "A preparar o destino de backup..."

if ! ssh_source "mkdir -p '$BACKUP_DIR'"; then
    log "ERRO: Não foi possível criar/aceder ao destino $BACKUP_DIR"
    exit 1
fi

MOUNT_TARGET=$(ssh_source "findmnt -T '$BACKUP_DIR' -n -o TARGET") || {
    log "ERRO: Não foi possível identificar o sistema de ficheiros do destino"
    exit 1
}

if [ "$MOUNT_TARGET" = "/" ]; then
    log "ERRO: O destino está no sistema de ficheiros raiz; backup cancelado"
    exit 1
fi

log "Disco de backup montado em: $MOUNT_TARGET"

if ! ssh_source "df -h '$BACKUP_DIR'"; then
    log "ERRO: Não foi possível verificar o espaço disponível"
    exit 1
fi

# ------------------------------------------------------------
# LISTAGEM DAS INSTÂNCIAS
# ------------------------------------------------------------

log "A procurar instâncias Incus..."

INSTANCE_LIST=$(ssh_source "incus list --format csv -c n") || {
    log "ERRO: Não foi possível listar as instâncias Incus"
    exit 1
}

if [ -z "$INSTANCE_LIST" ]; then
    log "Nenhuma instância Incus encontrada"
    exit 0
fi

# ------------------------------------------------------------
# EXPORTAR INSTÂNCIAS E APLICAR RETENÇÃO
# ------------------------------------------------------------

while IFS= read -r INSTANCE; do
    [ -z "$INSTANCE" ] && continue

    if [[ ! "$INSTANCE" =~ ^[A-Za-z0-9._-]+$ ]]; then
        ERRORS=$((ERRORS + 1))
        log "ERRO: Nome de instância não suportado: $INSTANCE"
        continue
    fi

    CHECKED=$((CHECKED + 1))
    log "Instância: $INSTANCE"

    TIMESTAMP=$(date '+%Y_%m_%d-%H_%M_%S')
    BACKUP_FILE="incus-${INSTANCE}-${TIMESTAMP}.tar.gz"
    TEMP_FILE="$BACKUP_DIR/.${BACKUP_FILE}.tmp"
    FINAL_FILE="$BACKUP_DIR/$BACKUP_FILE"

    log "A exportar apenas a instância, sem snapshots (Gzip)..."

    if ssh_source "incus export '$INSTANCE' '$TEMP_FILE' --instance-only"; then
        if ssh_source "test -s '$TEMP_FILE' && mv '$TEMP_FILE' '$FINAL_FILE'"; then
            COPIED=$((COPIED + 1))
            log "Backup concluído: $BACKUP_FILE"
        else
            ssh_source "rm -f '$TEMP_FILE'" >/dev/null 2>&1 || true
            ERRORS=$((ERRORS + 1))
            log "ERRO: Não foi possível finalizar o backup de $INSTANCE"
            continue
        fi
    else
        ssh_source "rm -f '$TEMP_FILE'" >/dev/null 2>&1 || true
        ERRORS=$((ERRORS + 1))
        log "ERRO: Falha ao exportar a instância $INSTANCE"
        continue
    fi

    log "A verificar retenção..."

    INSTANCE_BACKUPS=$(ssh_source "find '$BACKUP_DIR' -maxdepth 1 -type f -name 'incus-${INSTANCE}-*.tar.gz' -printf '%f\\n' | sort -r") || {
        ERRORS=$((ERRORS + 1))
        log "ERRO: Não foi possível consultar os backups de $INSTANCE"
        continue
    }

    mapfile -t BACKUP_FILES <<< "$INSTANCE_BACKUPS"

    if [ "${#BACKUP_FILES[@]}" -le "$KEEP_LXC" ]; then
        log "Retenção dentro do limite"
        continue
    fi

    for ((i=KEEP_LXC; i<${#BACKUP_FILES[@]}; i++)); do
        OLD_FILE="${BACKUP_FILES[$i]}"
        [ -z "$OLD_FILE" ] && continue

        log "A remover backup antigo: $OLD_FILE"

        if ssh_source "rm -f '$BACKUP_DIR/$OLD_FILE'"; then
            REMOVED=$((REMOVED + 1))
            log "Backup antigo removido"
        else
            ERRORS=$((ERRORS + 1))
            log "ERRO: Não foi possível remover $OLD_FILE"
        fi
    done

done <<< "$INSTANCE_LIST"

# ------------------------------------------------------------
# RESUMO
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
echo " Fim         : $(date '+%d/%m/%Y %H:%M:%S')"
echo " Duração     : $DURATION_FMT"

if [ "$ERRORS" -eq 0 ]; then
    echo " Estado      : CONCLUÍDO COM SUCESSO"
else
    echo " Estado      : CONCLUÍDO COM ERROS"
fi

echo "════════════════════════════════════════════════════════════"
echo

exit "$ERRORS"
