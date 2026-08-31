# 01 — AWS EC2 Sunucusu

> Amaç: Projeye temel oluşturan Ubuntu sunucusunu EC2'de açmak ve localden `ssh backup-server` yazarak rahatça bağlanabilmek.
>
> ⚠️ Elinde **zaten çalışan bir EC2'n varsa** bu dokümanı atla, 02'den devam et.

**Ön koşul:** [00-roadmap](00-roadmap.md) okundu.

---## 1. EC2 Instance Açma — LOCAL (tarayıcı)

AWS konsoluna gir → sağ üstten bölge seç (Türkiye'ye yakın: `eu-central-1` Frankfurt mantıklı) → **EC2 → Launch instance**.

Sihirbazda sırayla:

1. **Name**: `backup-server`
2. **OS**: *Ubuntu Server 24.04 LTS (amd64)*
3. **Instance type**: `t3.micro` yeterli (test veritabanı için).
   > Free tier notu: 15 Temmuz 2025 sonrası açılan hesaplarda eski "12 ay ücretsiz 750 saat" modeli yok; yeni hesaplarda kredi bazlı bir Free plan var. **Billing konsolundan kendi hesabının durumunu kontrol et** ve bir billing alarm kur — bu her AWS projesinde iyi alışkanlıktır.
4. **Key pair**: *Create new key pair* → adı `backup-server-key` → `.pem` → indir. Bu dosya sunucunun anahtarı, **kaybetme/kaydetme**.
5. **Security Group** (Network settings → Edit):
   - Inbound kural **yalnızca**: `SSH`, source: **My IP**
   - Başka hiçbir port açma. 27017 (MongoDB) özellikle **açık olmayacak** — sebep 02'de.
6. Storage: varsayılan (8 GB) bu proje için yeterli.

→ **Launch instance**.

### Elastic IP (önerilir, opsiyonel)

EC2 her durdurulup başlatıldığında **public IP'si değişir**. Sunucuyu uzun süre kullanacaksan:
**EC2 → Elastic IPs → Allocate** → oluşan IP'yi instance'ına **Associate** et.

> Not: Elastic IP, instance çalışırken ve bağlıyken ücretsizdir; boşta veya durdurulmuş instance'a bağlıyken saatlik küçük ücret keser. Kararsızsan atla — IP değişirse ssh config'teki adresi güncellersin.

Public IP'yi bir yere not et (instance sayfasında görünüyor).

## 2. Anahtar ve Kolay Bağlantı — LOCAL (terminal)

İnen `.pem` dosyasını ssh klasörüne taşı ve izinlerini düzelt (ssh, dünyaya açık anahtarı reddeder):

```bash
mv ~/Downloads/backup-server-key.pem ~/.ssh/
chmod 400 ~/.ssh/backup-server-key.pem
```

Her seferinde `ssh -i ~/.ssh/... ubuntu@3.12.45.67` yazmamak için `~/.ssh/config` dosyana ekle:

```
Host backup-server
  HostName <PUBLIC_IP>        # Elastic IP veya instance public IP'n
  User ubuntu
  IdentityFile ~/.ssh/backup-server-key.pem
```

Artık bağlantı: `ssh backup-server`

> EC2 Ubuntu görüntülerinde kullanıcı adı `ubuntu`'dur (root değil). `sudo` komutu şifresiz çalışır.

## 3. İlk Kurulum — SERVER (ssh ile)

```bash
ssh backup-server
sudo apt update && sudo apt -y upgrade
```

Sunucunun saat dilimini kontrol et:

```bash
timedatectl
```

**UTC görmen normal** — cron programlaması bu saatle yapılacak (05. dokümanda önemli).

## ✅ Checkpoint

Hepsi çalışıyorsa bu adım tamam:

```bash
ssh backup-server 'hostname && date'
# çıktı: ip-10-0-x-x  ... UTC tarihi
```

## Sık Hatalar

| Belirti | Neden | Çözüm |
|---|---|---|
| `Permission denied (publickey)` | `.pem` izinleri geniş veya yanlış dosya | `chmod 400`, doğru `-i`/config yolu |
| `Connection timed out` | Security Group kendi IP'ne izin vermiyor | SG kuralını güncelle. **Ev IP'n değişebilir** — "My IP" kuralı eskir, kuralı yeniden kaydet |
| `Connection refused` (port 22) | Instance durmuş ya da yanlış IP | AWS konsoldan instance **running** mı, IP doğru mu bak |
| `uname` yerine farklı OS çıktısı | Farklı AMI seçilmiş | 02'deki kurulumlar Ubuntu varsayar; Debian'da da benzer |

Sonraki adım: [02-mongodb-docker.md](02-mongodb-docker.md)
