# 05 — Cron: 12 Saatte Bir Otomatik Yedek

> Amaç: `backup.sh`'i 12 saatte bir otomatik tetikleyen cron işi kurmak ve gerçekten çalıştığını kanıtlamak.

**Ön koşul:** [04-backup-script](04-backup-script.md) checkpoint'i geçildi (script elle çalışıyor, R2'ye yüklüyor).

---

## 1. Cron Nedir, Crontab Nasıl Yazılır — SERVER

Cron, sunucunun arka planında dakika dakika program çalıştıran servisidir. Kurallar kullanıcının **crontab**'ında durur:

```bash
crontab -e      # ilk seferde editör sorarsa nano seç (1)
crontab -l      # mevcut kuralları listele
```

Crontab satırının anatomisi — 5 zaman alanı + komut:

```
┌───────────── dakika        (0-59)
│ ┌─────────── saat          (0-23)
│ │ ┌───────── ayın günü     (1-31)
│ │ │ ┌─────── ay            (1-12)
│ │ │ │ ┌───── haftanın günü (0-6, Pazar=0)
│ │ │ │ │
* * * * *  <çalıştırılacak komut>
```

## 2. Önce Test Modu — SERVER

12 saat bekleyip "çalıştı mı?" diye bakmak anlamsız. Önce **2 dakikada bir** çalıştır, kanıtla, sonra gerçek programa geç.

`crontab -e` ile şu satırı ekle (kendi path'ini kontrol et — `echo $HOME/auto-db-backups/backup.sh`):

```
*/2 * * * * /home/ubuntu/auto-db-backups/backup.sh >> /home/ubuntu/backups/cron.log 2>&1
```

Kaydet, çık (`Ctrl+O`, `Enter`, `Ctrl+X`).

Bu satırda üç önemli detay var:

1. **Mutlak yol** (`/home/ubuntu/...`) — cron, senin terminalinden çok daha yalın bir ortamda çalışır; `~/` veya "bulunduğun dizin" gibi kabuller geçerli değildir.
2. **`>> cron.log 2>&1`** — çıktıyı (normal + hata akışını) log dosyasına yazar. Redirect yoksa cron çıktıyı postaya yollar ve kaybolur.
3. **PATH endişesi yok** — `mongodump`, `aws`, `tar` hepsini `apt` ile `/usr/bin`'e kurduk; cron'un minimal PATH'i bu yolları içerir. (Kendi başına script yazarken bu klasik cron tuzağıdır, burada bilerek apt kurulumu tercih ettik.)

## 3. Çalıştığını Kanıtla — SERVER

```bash
# cron'un işi tetiklediğini gör (syslog / journald):
grep CRON /var/log/syslog | tail
# ya da:  journalctl -u cron --since "10 min ago"

# script'in kendi çıktısı:
tail -f ~/backups/cron.log     # Ctrl+C ile çık

# sonuç: R2'de yeni objeler
set -a; source ~/auto-db-backups/.env; set +a
aws s3 ls s3://$R2_BUCKET --endpoint-url $R2_ENDPOINT
```

2-4 dakika içinde cron.log'da yedekleme satırlarını ve R2'de yeni timestamp'li dosyaları görmelisin.

## 4. Gerçek Programa Geç — SERVER

Kanıt tamam. `crontab -e` ile test satırını şununla değiştir:

```
0 */12 * * * /home/ubuntu/auto-db-backups/backup.sh >> /home/ubuntu/backups/cron.log 2>&1
```

`*/12` = "her 12 saatte bir" değil, **"saat 12'nin katlarında"**: gün 00:00 ve 12:00'de çalışır. Toplam günde 2 kez = istediğimiz 12 saatte bir yedek.

> Sunucu saati **UTC**: 00:00 ve 12:00 UTC = Türkiye saatiyle 03:00 ve 15:00. Yedeklerin zaman damgaları da UTC'ye göre (04'te `date -u` kullandık) — hepsi tutarlı.

`crontab -l` ile son hali doğrula.

> Not: cron basit ve her yerde aynı biçimde; modern Linux'ta alternatifi **systemd timer**'dır (log entegrasyonu daha rahat). Bu projede cron yeterli — adını bilmen yeterli.

## ✅ Checkpoint

- `crontab -l` çıktısında `0 */12 * * * ...` satırı var
- Test döneminde cron.log'da otomatik tetiklenme kayıtları birikti (elle `./backup.sh` çalıştırmadan)
- R2'de otomatik oluşmuş objeler mevcut

Sonraki adım: [06-restore.md](06-restore.md)

## Sık Hatalar

| Belirti | Neden | Çözüm |
|---|---|---|
| Cron hiç tetiklemiyor | Satır yazım hatası / kaydedilmedi | `crontab -l` ile bak; dakika-alanını `*/2` yapıp tekrar test et |
| Tetikliyor ama script hata veriyor | Script elle mi çalışıyor? | Önce `./backup.sh` elle; çalışıyorsa cron.log'daki hatayı oku — en sık sebep yanlış mutlak yol |
| cron.log boş, obje yok | Redirect yazılmadı veya yanlış path'te log | Satırda `>> ... 2>&1` var mı; `ls ~/backups/` |
| `journalctl`/syslog'ta cron kaydı yok | cron servisi duruyor | `systemctl status cron` → değilse `sudo systemctl start cron` |
| Aynı dakikada iki yedek oluştu | Hem test crontab'ı hem eski satır duruyor | `crontab -e` ile eski satırı sil/sadece bir kural bırak |
