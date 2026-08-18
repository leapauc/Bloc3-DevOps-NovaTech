#!/bin/bash
# Restauration Postgres — Phase 3 du plan de remédiation.
# Cause racine #5 du post-mortem incident-aout-2024.md : "Procédure de
# rollback inexistante". Usage :
#   DATABASE_URL=... ./scripts/restore-db.sh /var/backups/hrflow/hrflow-20260723T140000Z.sql.gz
#   DATABASE_URL=... ./scripts/restore-db.sh latest   # restaure le backup le plus récent
set -euo pipefail

DATABASE_URL="${DATABASE_URL:?DATABASE_URL requis}"
BACKUP_DIR="${BACKUP_DIR:-/var/backups/hrflow}"
TARGET="${1:?Chemin du fichier de backup, ou 'latest'}"

if [ "$TARGET" = "latest" ]; then
  TARGET=$(find "$BACKUP_DIR" -name 'hrflow-*.sql.gz' | sort | tail -n1)
  if [ -z "$TARGET" ]; then
    echo "Aucun backup trouvé dans $BACKUP_DIR" >&2
    exit 1
  fi
fi

echo "Restauration depuis $TARGET vers la base cible..."
gunzip -c "$TARGET" | psql "$DATABASE_URL" -v ON_ERROR_STOP=1
echo "Restauration terminée depuis $TARGET"
