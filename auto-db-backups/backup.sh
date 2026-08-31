#!/usr/bin/env bash
  set -euo pipefail

  # --- Kurulum: scriptin bulunduğu dizini ve ayarları belirle ---
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  set -a; source "$SCRIPT_DIR/.env"; set +a

  BACKUP_DIR="$HOME/backups"          # arşivler burada birikir
  RETENTION_DAYS=7                    # eski yerel arşivleri kaç gün tutalım
  TIMESTAMP="$(date -u +%Y%m%d_%H%M%S)"
  ARCHIVE_NAME="backup_${TIMESTAMP}.tar.gz"
  LOG_FILE="${BACKUP_DIR}/backup.log"

  mkdir -p "$BACKUP_DIR"
  log() { echo "[$(date -u '+%Y-%m-%d %H:%M:%S UTC')] $*" | tee -a "$LOG_FILE"; }

  log "Yedekleme başlıyor: ${TIMESTAMP}"

  # --- 1) mongodump ile geçici dizine döküm al ---
  DUMP_DIR="$(mktemp -d)"
  mongodump --host 127.0.0.1 --port 27017 --db school --out "$DUMP_DIR"

  # --- 2) Dökümü tek tarball'a paketle ---
  tar -czf "${BACKUP_DIR}/${ARCHIVE_NAME}" -C "$DUMP_DIR" school
  rm -rf "$DUMP_DIR"

  # --- 3) Bütünlük için checksum üret (restore ederken doğrulayacağız) ---
  (cd "$BACKUP_DIR" && sha256sum "$ARCHIVE_NAME" > "${ARCHIVE_NAME}.sha256")
  log "Arşiv hazır: ${ARCHIVE_NAME}"

  # --- 4) R2'ye yükle (arşiv + checksum birlikte) ---
  aws s3 cp "${BACKUP_DIR}/${ARCHIVE_NAME}" "s3://${R2_BUCKET}/${ARCHIVE_NAME}" --endpoint-url "$R2_ENDPOINT"
  aws s3 cp "${BACKUP_DIR}/${ARCHIVE_NAME}.sha256" "s3://${R2_BUCKET}/${ARCHIVE_NAME}.sha256" --endpoint-url "$R2_ENDPOINT"
  log "R2'ye yüklendi: s3://${R2_BUCKET}/${ARCHIVE_NAME}"

  # --- 5) Retention: RETENTION_DAYS'tan eski yerel dosyaları sil ---
  find "$BACKUP_DIR" -name "backup_*.tar.gz*" -mtime +"$RETENTION_DAYS" -delete
  log "Yedekleme tamamlandı."


