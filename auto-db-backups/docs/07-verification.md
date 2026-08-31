# 07 — Uçtan Uca Test: Felaket Simülasyonu + Teslim

> Amaç: Sistemin gerçekten çalıştığını kanıtlamak. Veritabanını **bile bile silip** yedekten geri döneceğiz — yedekleme sistemlerinin var olma sebebi budur.

**Ön koşul:** [06-restore](06-restore.md) tamam.

---

## Felaket Simülasyonu — SERVER

Adımları sırayla; her adımda ne beklediğini yazıyor.

### 1. Yeni veri ekle (backup'ta olmayan)

```bash
mongosh "mongodb://127.0.0.1:27017/school" --eval 'db.students.insertOne({ name: "Test Kullanici", department: "CSE", gpa: 3.0 })'
mongosh "mongodb://127.0.0.1:27017/school" --eval 'db.students.countDocuments()'
# 11
```

### 2. Yedeği al

```bash
~/auto-db-backups/backup.sh
```

R2'de yeni timestamp'li arşiv oluştuğunu doğrula (`aws s3 ls ...`).

### 3. FELAKET: veritabanını sil

```bash
mongosh "mongodb://127.0.0.1:27017/school" --eval 'db.dropDatabase()'
mongosh "mongodb://127.0.0.1:27017/school" --eval 'db.students.countDocuments()'
# 0  (ya da koleksiyon yok hatası)
```

Veri gitti. Sığınak: R2.

### 4. Kurtar

```bash
~/auto-db-backups/restore.sh
```

### 5. Kanıtla

```bash
mongosh "mongodb://127.0.0.1:27017/school" --eval 'db.students.countDocuments()'
# 11   ← Test Kullanici dahil herkes geri geldi
```

**11 görüyorsan proje uçtan uca kanıtlanmış demektir**: cron → mongodump → tarball → R2 → mongorestore zincirinin her halkası çalışıyor.

## Teslim Checklist (konu gereksinimleri)

- [ ] Sunucu + hazır veritabanı (EC2 + Docker MongoDB + seed)
- [ ] Yedekler tarball halinde (`backup.sh`)
- [ ] Yedekler Cloudflare R2'de (`aws s3 cp` + `--endpoint-url`)
- [ ] 12 saatte bir otomatik (`crontab -l` ile gösterilebilir)
- [ ] Restore scripti (stretch goal)
- [ ] Felaket simülasyonu geçildi (bu sayfa)

## README'ye Ne Yazmalı

Repoya kısa bir README ekleyip bu checklist'i anlat:

- Ne yapıyor (1-2 cümle) + 00'daki mimari şeması
- Kurulum özeti: doküman sırası linkleriyle (`docs/`)
- Kullanım: `./backup.sh`, `./restore.sh`, cron satırı
- Ekran görüntüleri: R2 bucket içeriği, cron.log, felaket simülasyonundaki `11 → 0 → 11` anları — portfolyo için en ikna edici kısım burası

## Bonus Fikirler (isteyen için)

- **R2 Lifecycle Rule**: bucket ayarlarından "X günden eski objeleri sil" kuralı → R2 tarafında da retention. Sunucudaki retention (04) ile çift başa çıkmış olursun.
- **Başarısızlık bildirimi**: `backup.sh` sonuna başarısızlık durumunda e-posta/Telegram mesajı atan bir blok (`set -e` ile `trap ... ERR` kombinasyonu). Yedekleme sistemlerinin en sık hatası: sessizce çalışmamaları.
- **systemd timer** ile cron'un alternatifini denemek.

## Tebrikler 🎉

Kurduğun şey gerçek dünyadaki yedekleme stratejilerinin özü: **otomatik tetikleme → tutarlı döküm → bütünlük checksum'ı → dış depolama → doğrulanmış restore**.
