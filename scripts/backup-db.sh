#!/bin/bash
# Sauvegarde Postgres — Phase 3 du plan de remédiation.
# Cause racine #3 du post-mortem incident-aout-2024.md : "Pas de backup récent".
# À exécuter chaque heure via cron sur l'hôte de prod :
#   0 * * * * DATABASE_URL=... BACKUP_DIR=/var/backups/hrflow /var/www/hrflow/scripts/backup-db.sh
set -euo pipefail

DATABASE_URL="${DATABASE_URL:?DATABASE_URL requis}"
BACKUP_DIR="${BACKUP_DIR:-/var/backups/hrflow}"
RETENTION_DAYS="${RETENTION_DAYS:-7}"

mkdir -p "$BACKUP_DIR"
timestamp=$(date -u +%Y%m%dT%H%M%SZ)
out_file="$BACKUP_DIR/hrflow-$timestamp.sql.gz"

pg_dump "$DATABASE_URL" | gzip > "$out_file"
echo "Backup créé : $out_file ($(du -h "$out_file" | cut -f1))"

find "$BACKUP_DIR" -name 'hrflow-*.sql.gz' -mtime "+$RETENTION_DAYS" -delete
echo "Rétention : backups de plus de ${RETENTION_DAYS}j purgés."
