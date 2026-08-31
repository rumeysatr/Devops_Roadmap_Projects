  #!/usr/bin/env bash
  set -euo pipefail

  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  set -a; source "$SCRIPT_DIR/.env"; set +a

  log() { echo "[restore] $*"; }

  # --- 1) Bucket'taki arşivleri listele, isme göre sırala, en sonuncuyu al ---
  # backup_YYYYMMDD_HHMMSS adları alfabetik sıralanınca kronolojik sıralama verir (04'te bu yüzden bu isimlendirme).
  LATEST="$(aws s3 ls "s3://${R2_BUCKET}/" --endpoint-url "$R2_ENDPOINT" \
    | awk '{print $4}' \
    | grep '^backup_.*\.tar\.gz$' \
    | sort \
    | tail -1)"

  if [ -z "$LATEST" ]; then
    echo "HATA: bucket'ta yedek bulunamadı." >&2
    exit 1
  fi
  log "En yeni yedek: ${LATEST}"

  # --- 2) Geçici dizine indir (arşiv + checksum) ---
  RESTORE_DIR="$(mktemp -d)"
  aws s3 cp "s3://${R2_BUCKET}/${LATEST}" "${RESTORE_DIR}/${LATEST}" --endpoint-url "$R2_ENDPOINT"
  aws s3 cp "s3://${R2_BUCKET}/${LATEST}.sha256" "${RESTORE_DIR}/${LATEST}.sha256" --endpoint-url "$R2_ENDPOINT"

  # --- 3) Bütünlük: indirdiğimiz arşiv, yedeklenirkenki hash ile aynı mı? ---
  (cd "$RESTORE_DIR" && sha256sum -c "${LATEST}.sha256")
  log "Checksum doğrulandı."

  # --- 4) Aç ve mongorestore ile geri yükle ---
  tar -xzf "${RESTORE_DIR}/${LATEST}" -C "$RESTORE_DIR"
  mongorestore --host 127.0.0.1 --port 27017 --db school --drop "${RESTORE_DIR}/school"

  rm -rf "$RESTORE_DIR"
  log "Restore tamamlandı. Kontrol için:"
  echo '  mongosh "mongodb://127.0.0.1:27017/school" --eval "db.students.countDocuments()"'

