# 06 — restore.sh: R2'den Geri Yükleme (Stretch Goal)

> Amaç: Sunucudaki veritabanı silinse/bozulsa, R2'deki **en son** yedekten tek komutla geri dönebilmek.

**Ön koşul:** [05-cron](05-cron.md) tamam, R2'de en az bir `backup_*.tar.gz` var.

---

## 1. Script — LOCAL (editör)

Repoya `restore.sh` ekle:

```bash
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
```

Commit & push, sunucuya al:

```bash
git add restore.sh
git commit -m "add restore script"
git push
```

```bash
# SERVER
cd ~/auto-db-backups && git pull && chmod +x restore.sh
```

### Mantığı kısaca

- **"En yeni yedeği bulmak"** dosya isimlendirme oyunu: `awk '{print $4}'` `aws s3 ls` çıktısındaki obje adı kolonunu alır, `grep` yalnızca arşivleri seçer (`.sha256`'ları elemede bırakır), `sort | tail -1` en büyüğünü (en yenisini) verir.
- **Checksum doğrulama** (`sha256sum -c`): yedek upload edilirken üretilen hash ile indirdiğimiz dosyanın hash'i tutuyorsa arşiv yolda bozulmamış. Uydurma/hatalı bir yedeği restore etmeye kalkmamış oluruz.
- **`--drop` uyarısı**: mongorestore normalde mevcut verinin **üstüne ekler**. `--drop` restore öncesi koleksiyonları temizler; böylece yarım/çift veri oluşmaz. Yan etkisi şu: `restore.sh` çalıştırdığın anda `school` veritabanının o anki hali **yedekten gelenle değişir**. Bilinçli kullan.

## 2. Hemen Test Et — SERVER

Şu an DB'de 10 öğrenci var ve R2'de yedeği var — ideal test koşulu:

```bash
cd ~/auto-db-backups
./restore.sh
```

Beklenen çıktı:

```
[restore] En yeni yedek: backup_20260821_140000.tar.gz
backup_20260821_140000.tar.gz: OK
...mongorestore çıktıları...
[restore] Restore tamamlandı. Kontrol için: ...
```

Son kontrol:

```bash
mongosh "mongodb://127.0.0.1:27017/school" --eval 'db.students.countDocuments()'
# 10
```

Aynı veriyi geri yazdık — bu iyi, ama gerçek kanıt 07'deki felaket simülasyonunda gelecek.

## ✅ Checkpoint

- `./restore.sh` hata vermeden bitiyor, `: OK` checksum satırı görünüyor
- `countDocuments()` makul bir sayı dönüyor
- Script ikinci kez de sorunsuz çalışıyor (idempotent)

Sonraki adım: [07-verification.md](07-verification.md)

## Sık Hatalar

| Belirti | Neden | Çözüm |
|---|---|---|
| `FAILED` checksum, script durdu | İndirme yarım kalmış / dosya bozulmuş | Tekrar çalıştır; yine olursa o yedeği at (`R2 konsolundan sil`), önceki yedele dene — script otomatik öncekine düşmez, `LATEST` onu yine seçebilir |
| `HATA: bucket'ta yedek bulunamadı` | Bucket boş veya isimler farklı | `aws s3 ls` ile bak; 04'teki isim formatına mı uyuyor |
| `connection refused` mongorestore'da | Mongo kapalı | `docker compose up -d` |
| İsim listesi karışık geldi | Farklı formatta dosya upload edilmiş | R2'de `backup_` öneki ve `.tar.gz` bitişi olmayan her şey restore'ı bozmaz (grep eler), ama düzenli kalması iyi |
