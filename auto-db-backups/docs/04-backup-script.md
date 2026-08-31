# 04 — backup.sh: mongodump → tar.gz → R2

> Amaç: Tek komutla veritabanı dökümünü alıp zaman damgalı tarball yapıp R2'ye yükleyen scripti yazmak ve elle test etmek.

**Ön koşul:** [03-cloudflare-r2](03-cloudflare-r2.md) checkpoint'i geçildi (`aws s3 ls` çalışıyor).

---

## 1. Script — LOCAL (editör)

Repoya `backup.sh` ekle:

```bash
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
```

Commit & push:

```bash
git add backup.sh
git commit -m "add backup script"
git push
```

### Scriptte ne var, kısaca

- `set -euo pipefail` — herhangi bir komut hata verirse script anında dursun. Yarım yamalak yedek yüklemesini önler; scriptlerde standarttır.
- `BASH_SOURCE` — script **nereden çağrılırsa çağrılsın** kendi dizinini bulur. Cron 05'te başka bir dizinden tetikleyecek; `.env`'e giden yol bu sayede hep doğru.
- `mktemp -d` — her çalıştırmada benzersiz geçici dizin; `/tmp` altında, iş bitince siliyoruz.
- `tar -C "$DUMP_DIR" school` — arşivin içine `school/` klasörü koyar (mongodump `--out` dizini altında bu isimle üretir). Restore bunun sayesinde nereyi açacağını bilir.
- `date -u` — **UTC** zaman damgası. Sunucu saati zaten UTC; R2 listelerinde sıralama tutarlı olur.
- Dosya adı `backup_YYYYMMDD_HHMMSS.tar.gz` — isme göre alfabetik sıralama **kronolojik sıralama** verir. `restore.sh` "en son yedeği" tamamen bu mantıkla bulacak.
- Retention — R2'dekiler durur, sadece **sunucudaki** eski kopyaları siler; disk dolmasın.

## 2. Sunucuya Al ve Çalıştır — SERVER

```bash
ssh backup-server
cd ~/auto-db-backups
git pull
chmod +x backup.sh
./backup.sh
```

Beklenen çıktı, satır satır şu üç log + mongodump'ın kendi çıktıları:

```
[2026-08-21 14:00:00 UTC] Yedekleme başlıyor: 20260821_140000
[2026-08-21 14:00:01 UTC] Arşiv hazır: backup_20260821_140000.tar.gz
[2026-08-21 14:00:02 UTC] R2'ye yüklendi: s3://db-backups/backup_20260821_140000.tar.gz
[2026-08-21 14:00:02 UTC] Yedekleme tamamlandı.
```

## 3. Üç Yerden Doğrula — SERVER

```bash
ls -lh ~/backups/                       # 1) yerel arşiv var mı
cat ~/backups/backup_*.sha256           # 2) checksum üremiş mi
aws s3 ls s3://$R2_BUCKET --endpoint-url $R2_ENDPOINT   # .env yükleyerek ya da elle
```

> 3. komut için ya `set -a; source .env; set +a` yapıp `$R2_BUCKET`'ı kullan, ya da doğrudan yaz: `aws s3 ls s3://db-backups --endpoint-url https://<ACCOUNT_ID>.r2.cloudflarestorage.com`

4. doğrulama tarayıcıdan: **Cloudflare → R2 → db-backups** — `backup_....tar.gz` ve `.sha256` objelerini görmelisin.

## ✅ Checkpoint

- `./backup.sh` hatasız bitiyor
- R2 konsolunda (veya `aws s3 ls` ile) en az 1 arşiv + 1 checksum dosyası görünüyor
- Scripti tekrar çalıştırırsan **yeni bir timestamp'li dosya** oluşuyor

Otomatiğe bağlamaya hazırız → [05-cron.md](05-cron.md)

## Sık Hatalar

| Belirti | Neden | Çözüm |
|---|---|---|
| `Unable to locate credentials` / 403 | `.env` yok, eksik veya `source` edilemedi | `ls -la ~/auto-db-backups/.env`; içerik 03'teki gibi mi |
| mongodump: `connection refused` | Mongo container kapalı | `docker compose up -d` (02'den) |
| `Permission denied: ./backup.sh` | +x izni yok | `chmod +x backup.sh` |
| Script bir satırda durdu, devam etmedi | Bilerek: `set -e` sayesinde. Hata mesajına bak, o adımı düzelt | Üstteki satırlarla eşleştir |
| R2'de obje yok ama "upload: ..." yazdı | Yanlış bucket'a baktın | `s3://db-backups` — `.env`'teki adla aynı bucket'ın konsolundasın mı |

Sonraki adım: [05-cron.md](05-cron.md)
