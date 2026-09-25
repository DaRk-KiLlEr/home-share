#!/bin/bash

# ============================================================
# Proxmox Backup Pull
# ============================================================

set -u

# ------------------------------------------------------------
# CONFIGURAÇÃO
# ------------------------------------------------------------

# ------------------------------------------------------------
# ORIGEM
# ------------------------------------------------------------

BACKUP_HOST="hostname/ip"
BACKUP_USER="user"
BACKUP_PASS="password"

BACKUP_DIR="/mnt/pve/local-SSD/dump"

# ------------------------------------------------------------
# DESTINO
# ------------------------------------------------------------

DEST_HOST="hostname/ip"
DEST_USER="user"
DEST_PASS="passoword"

DEST_DIR="/srv/proxmox_backup/"

KEEP_LXC=2
KEEP_VM=2
SSH_PORT=22

# ------------------------------------------------------------
# CONTADORES
# ------------------------------------------------------------

CHECKED=0
COPIED=0
SKIPPED=0
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
        ssh -p "$SSH_PORT" \
        -o StrictHostKeyChecking=accept-new \
        -o ConnectTimeout=10 \
        "$BACKUP_USER@$BACKUP_HOST" "$@"
}

ssh_dest() {
    SSHPASS="$DEST_PASS" sshpass -e \
        ssh -p "$SSH_PORT" \
        -o StrictHostKeyChecking=accept-new \
        -o ConnectTimeout=10 \
        "$DEST_USER@$DEST_HOST" "$@"
}

# ------------------------------------------------------------
# CABEÇALHO
# ------------------------------------------------------------

echo
echo "════════════════════════════════════════════════════════════"
echo " Proxmox Backup Pull (BLUEPI)"
echo "════════════════════════════════════════════════════════════"
echo " Host origem : $BACKUP_HOST"
echo " Directório  : $BACKUP_DIR"
echo " Host destino: $DEST_HOST"
echo " Directório  : $DEST_DIR"
echo " Retenção    : LXC=$KEEP_LXC | VM=$KEEP_VM"
echo " Início      : $(date '+%d/%m/%Y %H:%M:%S')"
echo "════════════════════════════════════════════════════════════"
echo

# ------------------------------------------------------------
# VERIFICAÇÕES
# ------------------------------------------------------------

log "🔎 A verificar ligação ao host de origem..."

if ssh_source "true" >/dev/null 2>&1; then
    log "✓ Origem acessível"
else
    log "✗ Origem inacessível"
    exit 1
fi

log "🔎 A verificar ligação ao host de destino..."

if ssh_dest "true" >/dev/null 2>&1; then
    log "✓ Destino acessível"
else
    log "✗ Destino inacessível"
    exit 1
fi

log "🔎 A verificar se o destino possui sshpass..."

if ssh_dest "command -v sshpass >/dev/null 2>&1"; then
    log "✓ sshpass disponível no destino"
else
    log "✗ sshpass não está instalado no destino"
    exit 1
fi

# ------------------------------------------------------------
# LISTAGEM DA ORIGEM
# ------------------------------------------------------------

log "🔎 A procurar backups disponíveis..."

SOURCE_FILES=$(
    ssh_source "
        find '$BACKUP_DIR' \
            -maxdepth 1 \
            -type f \
            -printf '%f\n' \
            2>/dev/null
    "
)

if [ -z "$SOURCE_FILES" ]; then
    log "⚠ Nenhum ficheiro encontrado na origem"
    exit 0
fi

# ------------------------------------------------------------
# LISTAGEM DO DESTINO
# ------------------------------------------------------------

DEST_FILES=$(
    ssh_dest "
        find '$DEST_DIR' \
            -maxdepth 1 \
            -type f \
            -printf '%f\n' \
            2>/dev/null
    "
)

declare -A SOURCE_EXISTS
declare -A DEST_EXISTS

while IFS= read -r FILE; do
    [ -n "$FILE" ] && SOURCE_EXISTS["$FILE"]=1
done <<< "$SOURCE_FILES"

while IFS= read -r FILE; do
    [ -n "$FILE" ] && DEST_EXISTS["$FILE"]=1
done <<< "$DEST_FILES"

# ------------------------------------------------------------
# BACKUPS PRINCIPAIS
# ------------------------------------------------------------

BACKUP_LIST=$(
    printf '%s\n' "$SOURCE_FILES" |
    grep -E '^vzdump-(lxc|qemu)-[0-9]+-[0-9]{4}_[0-9]{2}_[0-9]{2}-[0-9]{2}_[0-9]{2}_[0-9]{2}\.(tar\.(zst|lzo|gz|xz)|vma\.(zst|lzo|gz|xz))$' |
    sort -r
)

if [ -z "$BACKUP_LIST" ]; then
    log "⚠ Nenhum backup válido encontrado"
    exit 0
fi

# ------------------------------------------------------------
# AGRUPAR POR TIPO + ID
# ------------------------------------------------------------

declare -A BACKUP_GROUPS

while IFS= read -r MAIN_FILE; do
    [ -z "$MAIN_FILE" ] && continue

    if [[ "$MAIN_FILE" =~ ^vzdump-lxc-([0-9]+)- ]]; then
        TYPE="lxc"
        ID="${BASH_REMATCH[1]}"
    elif [[ "$MAIN_FILE" =~ ^vzdump-qemu-([0-9]+)- ]]; then
        TYPE="qemu"
        ID="${BASH_REMATCH[1]}"
    else
        continue
    fi

    KEY="$TYPE-$ID"

    if [ -z "${BACKUP_GROUPS[$KEY]+x}" ]; then
        BACKUP_GROUPS["$KEY"]="$MAIN_FILE"
    else
        BACKUP_GROUPS["$KEY"]+=$'\n'"$MAIN_FILE"
    fi

done <<< "$BACKUP_LIST"

# ------------------------------------------------------------
# PROCESSAR CADA BACKUP
# ------------------------------------------------------------

for KEY in "${!BACKUP_GROUPS[@]}"; do

    if [[ "$KEY" =~ ^lxc- ]]; then
        SELECT_COUNT=$KEEP_LXC
    else
        SELECT_COUNT=$KEEP_VM
    fi

    mapfile -t BACKUPS <<< "${BACKUP_GROUPS[$KEY]}"

    for ((i=0; i<SELECT_COUNT && i<${#BACKUPS[@]}; i++)); do

        MAIN_FILE="${BACKUPS[$i]}"
        CHECKED=$((CHECKED + 1))

        log "✓ Backup: $MAIN_FILE"

        # ----------------------------------------------------
        # FICHEIROS ASSOCIADOS
        # ----------------------------------------------------

        ASSOCIATED=()
        ASSOCIATED+=("$MAIN_FILE")

        NOTES_FILE="$MAIN_FILE.notes"

        if [ "${SOURCE_EXISTS[$NOTES_FILE]+_}" ]; then
            ASSOCIATED+=("$NOTES_FILE")
        fi

        LOG_FILE="${MAIN_FILE%.*}"
        LOG_FILE="${LOG_FILE%.*}.log"

        if [ "${SOURCE_EXISTS[$LOG_FILE]+_}" ]; then
            ASSOCIATED+=("$LOG_FILE")
        fi

        # ----------------------------------------------------
        # VERIFICAR FICHEIROS EM FALTA
        # ----------------------------------------------------

        MISSING=()

        for FILE in "${ASSOCIATED[@]}"; do
            if [ -z "${DEST_EXISTS[$FILE]+x}" ]; then
                MISSING+=("$FILE")
            fi
        done

        if [ ${#MISSING[@]} -eq 0 ]; then
            log "  ↳ Backup e ficheiros associados já existem — ignorado"
            SKIPPED=$((SKIPPED + 1))
            continue
        fi

        log "  + Ficheiros em falta: ${#MISSING[@]}"

        # ----------------------------------------------------
        # COPIAR CADA FICHEIRO INDIVIDUALMENTE
        # ----------------------------------------------------

        COPY_OK=true

        for FILE in "${MISSING[@]}"; do

            log "  → A copiar $FILE"

            if ssh_dest \
                "SSHPASS='$BACKUP_PASS' sshpass -e scp \
                -P '$SSH_PORT' \
                -o StrictHostKeyChecking=accept-new \
                '$BACKUP_USER@$BACKUP_HOST:$BACKUP_DIR/$FILE' \
                '$DEST_DIR/'"
            then
                log "  ✓ Copiado $FILE"
                DEST_EXISTS["$FILE"]=1
            else
                log "  ✗ Erro ao copiar $FILE"
                COPY_OK=false
            fi

        done

        # ----------------------------------------------------
        # RESULTADO DO BACKUP
        # ----------------------------------------------------

        if [ "$COPY_OK" = true ]; then
            log "  ✓ Transferência concluída"
            COPIED=$((COPIED + 1))
        else
            log "  ⚠ Transferência incompleta — backup anterior mantido"
            ERRORS=$((ERRORS + 1))
        fi

    done

done

# ------------------------------------------------------------
# LIMPEZA / RETENÇÃO
# ------------------------------------------------------------

echo
echo "────────────────────────────────────────────────────────────"
echo " LIMPEZA / RETENÇÃO"
echo "────────────────────────────────────────────────────────────"

# Reobter lista actual do destino depois das cópias
DEST_FILES=$(
    ssh_dest "
        find '$DEST_DIR' \
            -maxdepth 1 \
            -type f \
            -printf '%f\n' \
            2>/dev/null
    "
)

declare -A CURRENT_BACKUPS

while IFS= read -r FILE; do
    [ -z "$FILE" ] && continue

    if [[ "$FILE" =~ ^vzdump-(lxc|qemu)-([0-9]+)-([0-9]{4}_[0-9]{2}_[0-9]{2}-[0-9]{2}_[0-9]{2}_[0-9]{2})\.(tar\.(zst|lzo|gz|xz)|vma\.(zst|lzo|gz|xz))$ ]]; then

        TYPE="${BASH_REMATCH[1]}"
        ID="${BASH_REMATCH[2]}"
        KEY="$TYPE-$ID"

        CURRENT_BACKUPS["$KEY"]+=$'\n'"$FILE"
    fi

done <<< "$DEST_FILES"

for KEY in "${!CURRENT_BACKUPS[@]}"; do

    if [[ "$KEY" =~ ^lxc- ]]; then
        KEEP=$KEEP_LXC
    else
        KEEP=$KEEP_VM
    fi

    mapfile -t FILES <<< "$(printf '%s\n' "${CURRENT_BACKUPS[$KEY]}" | sed '/^$/d' | sort -r)"

    if [ ${#FILES[@]} -le "$KEEP" ]; then
        continue
    fi

    for ((i=KEEP; i<${#FILES[@]}; i++)); do

        OLD_FILE="${FILES[$i]}"

        log "🗑 A remover backup antigo: $OLD_FILE"

        DELETE_FILES=()
        DELETE_FILES+=("$OLD_FILE")

        NOTES_FILE="$OLD_FILE.notes"

        if ssh_dest "[ -f '$DEST_DIR/$NOTES_FILE' ]"; then
            DELETE_FILES+=("$NOTES_FILE")
        fi

        LOG_FILE="${OLD_FILE%.*}"
        LOG_FILE="${LOG_FILE%.*}.log"

        if ssh_dest "[ -f '$DEST_DIR/$LOG_FILE' ]"; then
            DELETE_FILES+=("$LOG_FILE")
        fi

        DELETE_OK=true

        for FILE in "${DELETE_FILES[@]}"; do
            if ssh_dest "rm -f '$DEST_DIR/$FILE'"; then
                :
            else
                DELETE_OK=false
            fi
        done

        if [ "$DELETE_OK" = true ]; then
            REMOVED=$((REMOVED + 1))
            log "  ✓ Backup removido"
        else
            ERRORS=$((ERRORS + 1))
            log "  ✗ Erro ao remover backup"
        fi

    done

done

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
echo " Verificados : $CHECKED"
echo " Copiados    : $COPIED"
echo " Ignorados   : $SKIPPED"
echo " Removidos   : $REMOVED"
echo " Erros       : $ERRORS"
echo " Fim         : $(date '+%d/%m/%Y %H:%M:%S')"
echo " Duração     : $DURATION_FMT"

if [ "$ERRORS" -eq 0 ]; then
    echo " Status      : ✓ CONCLUÍDO COM SUCESSO"
else
    echo " Status      : ⚠ CONCLUÍDO COM ERROS"
fi

echo "════════════════════════════════════════════════════════════"
echo

exit "$ERRORS"
