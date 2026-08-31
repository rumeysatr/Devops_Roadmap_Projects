# 03 — Cloudflare R2 Bucket + Sunucuda aws cli

> Amaç: Yedeklerin yükleneceği R2 bucket'ını açmak, S3 uyumlu API anahtarlarını almak ve sunucudan `aws` komutuyla bağlantıyı test etmek.

**Ön koşul:** [02-mongodb-docker](02-mongodb-docker.md) checkpoint'i geçildi (MongoDB çalışıyor, 10 öğrenci var).

---

## 1. R2 Hesabı ve Bucket — LOCAL (tarayıcı)

1. [dash.cloudflare.com](https://dash.cloudflare.com) → ücretsiz hesap aç / gir.
2. Sol menüden **R2 Object Storage** → ilk kullanımda aktive etmeni ister. **Kart bilgisi istenebilir**; free tier içinde kaldıkça ücret alınmaz: **ayda 10 GB depolama, 1M yazma, 10M okuma ücretsiz** (bu projede aylarca aşman imkânsız — yedekler KB/MB boyutunda). Egress (indirme) ücreti R2'de sıfırdır, restore denemeleri de bedava.
3. **Create bucket** → adı: `db-backups` → Location: *Automatic*.

## 2. API Token — LOCAL (tarayıcı)

R2 sayfasında sağ üst **Manage R2 API Tokens → Create API Token**:

- Name: `db-backup-uploader`
- Permissions: **Object Read & Write**
- Specify bucket(s): **Apply to specific buckets only** → `db-backups`
  → sadece bu bucket'a yazabilen kısıtlı bir anahtar (least privilege; tüm hesabı değil).
- Create → sana **Access Key ID** ve **Secret Access Key** verir.

> ⚠️ **Secret Access Key yalnızca bu kez gösterilir.** Kopyala ve güvenli bir yere kaydet. Sayfayı kapatıp kaybedersen token'ı silip yenisini yaratırsın.

Ayrıca **Account ID**'yi not et (R2 sayfasında sağda ya da dashboard'da görünüyor). Endpoint adresin bu ID'den oluşur:

```
https://<ACCOUNT_ID>.r2.cloudflarestorage.com
```

## 3. aws cli Kurulumu — SERVER

```bash
ssh backup-server
sudo apt-get install -y awscli
aws --version
```

> Neden `aws`? R2, AWS S3'ün API'siyle **uyumlu** çalışır; `aws s3` komutları `--endpoint-url` verildiğinde S3 yerine R2'ye gider. Ayrı bir "r2 cli" yok, S3 aracı kullanılır.

## 4. `.env` Dosyası — SERVER

Sunucudaki proje dizinine **elle** oluştur (git'e girmeyecek — `.gitignore`'da zaten var):

```bash
cd ~/auto-db-backups
nano .env
```

İçeriği (kendi değerlerinle):

```bash
AWS_ACCESS_KEY_ID=<Access Key ID>
AWS_SECRET_ACCESS_KEY=<Secret Access Key>
AWS_DEFAULT_REGION=auto
R2_ENDPOINT=https://<ACCOUNT_ID>.r2.cloudflarestorage.com
R2_BUCKET=db-backups
```

```bash
chmod 600 .env    # sadece sen okuyabilirsin — anahtar dosyası çünkü
```

> `AWS_DEFAULT_REGION=auto`: R2 bölge kavramını böyle ister; `aws` komutunun "region belirt" hatasını da önler.
> `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` isimleri tesadüf değil — `aws` cli bu isimleri otomatik tanır.

### Bu dosya nasıl kullanılacak? (04'te script bunu yapacak)

Scriptler `.env`'i şöyle yükleyecek:

```bash
set -a          # source ile gelen değişkenler otomatik EXPORT edilir
source .env
set +a          # modu kapat
```

Bunu bir kez elle deneyip bağlantıyı test et:

```bash
cd ~/auto-db-backups
set -a; source .env; set +a
aws s3 ls --endpoint-url "$R2_ENDPOINT"
```

> `set -a` olmadan da `source` çalışır ama değişkenler **export edilmez**; `aws` ayrı bir süreç olduğu için onları göremezdi. Bu üç satır bash'te standart dotenv kalıbıdır.

## ✅ Checkpoint

- `aws s3 ls --endpoint-url "$R2_ENDPOINT"` → hata yok, **boş çıktı** (bucket'ta henüz obje yok; boşluk = bucket görünüyor demek)
- Cloudflare dashboard → R2 → `db-backups` bucket'ı konsolda görünüyor

## Sık Hatalar

| Belirti | Neden | Çözüm |
|---|---|---|
| `InvalidAccessKeyId` | Key yanlış kopyalandı veya token silindi | Token'ı sil, yenisini yarat, `.env`'i güncelle |
| `Unable to locate credentials` | `.env` source edilmedi veya `set -a` atlandı | 4. adımdaki üç satırı sırayla çalıştır |
| `Could not connect to the endpoint URL` | Account ID / endpoint yanlış yazılmış | R2 sayfasındaki S3 API endpoint'iyle birebir karşılaştır |
| `NoSuchBucket` | Bucket adı `.env`'te farklı | `R2_BUCKET=db-backups` ile eşleşmeli |
| R2 aktive edilemiyor | Kart eklenmemiş | Billing'e kart ekle; free tier aşılırsa değil, sadece kullanım üzerinden ücret doğar |

Sonraki adım: [04-backup-script.md](04-backup-script.md)
