# 00 — Yol Haritası: Automated DB Backups

> Amaç: 12 saatte bir MongoDB veritabanının yedeğini alıp `tar.gz` arşivi halinde Cloudflare R2'ye yükleyen otomatik bir sistem kurmak; bonus olarak da bu yedekten geri dönüş (restore) yapabilmek.

## Mimari

```
┌──────────────── EC2 (Ubuntu 24.04) ────────────────┐
│                                                    │
│   cron (12 saatte bir tetikler)                    │
│     └── backup.sh                                  │
│           ├── mongodump ──► 127.0.0.1:27017 ──► mongo (Docker, school DB)
│           ├── tar.gz arşivi + sha256 checksum      │
│           └── aws s3 cp ────────► Cloudflare R2 (db-backups bucket)
│                                                    │
│   restore.sh (elle, gerektiğinde): R2 → indir →    │
│        doğrula → mongorestore                      │
└────────────────────────────────────────────────────┘
```

## En önemli soru: Ne localde, ne sunucuda?

Bu projede iki makine var: **local** (senin bilgisayarın) ve **server** (AWS EC2, ssh ile girilen). Kural basit:

- **LOCAL**: Tarayıcıyla konsol işleri (AWS, Cloudflare) + editörle dosya yazma + git push
- **SERVER**: ssh ile girilir; kurulum, çalıştırma, cron, test

| Adım | Nerede | Nasıl |
|------|--------|-------|
| EC2 açma, key pair, Security Group | LOCAL | AWS konsolu (tarayıcı) |
| Cloudflare hesabı, bucket, API token | LOCAL | Cloudflare konsolu (tarayıcı) |
| `docker-compose.yml`, `seed.js`, `backup.sh`, `restore.sh` yazımı | LOCAL | editör + git push |
| Docker + MongoDB + aws cli kurulumu | SERVER | ssh + komutlar |
| `.env` (gizli anahtarlar) — **asla git'e girmez** | SERVER | nano ile elle |
| Scriptleri çalıştırma, cron ayarı, restore testi | SERVER | ssh + komutlar |

Geliştirme döngüsü hep aynı: **localde yaz → commit & push → sunucuda `git pull` → sunucuda çalıştır.**

## Doküman Sırası

Her doküman bir öncekinin sonundaki checkpoint ile başlar. Sırayla git.

1. [01-aws-ec2.md](01-aws-ec2.md) — EC2 sunucusunu açma, ssh kurulumu
2. [02-mongodb-docker.md](02-mongodb-docker.md) — Docker + MongoDB + örnek veri (seed)
3. [03-cloudflare-r2.md](03-cloudflare-r2.md) — R2 bucket, API token, sunucuda aws cli
4. [04-backup-script.md](04-backup-script.md) — `backup.sh`: dump → tar → R2
5. [05-cron.md](05-cron.md) — 12 saatte bir otomatik çalıştırma
6. [06-restore.md](06-restore.md) — `restore.sh`: R2'den geri yükleme (stretch goal)
7. [07-verification.md](07-verification.md) — Uçtan uca felaket simülasyonu + teslim checklist

## Örnek isimlendirme (tüm dokümanlarda tutarlı)

- Sunucuya ssh takma adı: `backup-server`
- Key pair dosyası: `~/.ssh/backup-server-key.pem`
- Sunucudaki proje dizini: `~/auto-db-backups`
- MongoDB veritabanı: `school`, koleksiyon: `students`
- R2 bucket adı: `db-backups`

## Teslim edilecekler (konu gereksinimleri)

- [ ] Çalışan bir EC2 üzerinde MongoDB, içinde veri var
- [ ] `backup.sh`: mongodump → tarball → R2 yüklemesi yapıyor
- [ ] Cron işi 12 saatte bir çalışıyor, kanıtıyla doğrulanmış
- [ ] (Stretch) `restore.sh`: en son yedeği indirip DB'yi geri yükleyebiliyor
- [ ] Felaket simülasyonu ile uçtan uca test edilmiş (07. doküman)
