# Dummy Systemd Service

Bir dosyaya günlük (log) kaydı yapan, uzun süre çalışan bir **systemd servisi** oluşturma projesi.

Amaç, gerçek bir uygulama yazmak değil; `systemd` ile tanışmak — bir servis oluşturmak, etkinleştirmek, durumunu izlemek, loglarını incelemek, başlatıp durdurmak. Gerçek bir servise (web sunucusu, veritabanı, API, worker) ihtiyaç duymadan systemd mantığını öğretmek için bu "dummy" (örnek/işlevsiz) servis her 10 saniyede bir `Dummy service is running...` mesajını log dosyasına yazar.

> Konunun orijinal metni için [docs/tr_subject.md](docs/tr_subject.md) (Türkçe) ve [docs/en_subject.md](docs/en_subject.md) (İngilizce) dosyalarına bakabilirsin. Çalışma sürecindeki araştırma notlarım ise [docs/2026-08-26_PROJE-CONTENTS.md](docs/2026-08-26_PROJE-CONTENTS.md) içinde.

---

## "Dummy" ne demek?

"Dummy" burada özel bir Linux teknolojisi değil; İngilizcede **"sahte", "örnek", "işlevsiz prototip"** anlamına gelir. Gerçek bir servis bir web sunucusu, veritabanı, API uygulaması, dosya yedekleme aracı ya da arka planda görev işleyen bir worker olabilir. Bu projedeki servis ise gerçek bir iş yapmaz — yalnızca her 10 saniyede bir mesaj üreterek systemd'nin nasıl çalıştığını öğrenmemizi sağlar.

## Servis ve arka plan işlemi nedir?

Terminalde `./dummy.sh` çalıştırdığını düşün: script sonsuz bir döngü içerdiği için terminali meşgul eder. Terminali kapatırsan veya işlemi sonlandırırsan script de durabilir.

**Servis yaklaşımında** scripti doğrudan sen yönetmezsin, systemd'ye teslim edersin:

```
Sen → systemctl → systemd → dummy.sh
```

`systemd`, scripti arka planda başlatır, çalışıp çalışmadığını takip eder ve gerektiğinde tekrar başlatır.

## systemd nedir?

`systemd`, çoğu modern Linux dağıtımında (Ubuntu, Debian, Fedora, Rocky Linux, Arch Linux vb.) **sistem ve servis yöneticisidir**. Başlıca görevleri:

- Bilgisayar açılırken gerekli servisleri başlatmak
- Servisleri durdurmak ve yeniden başlatmak
- Servislerin durumunu takip etmek
- Çöken servisleri tekrar çalıştırmak
- Servisler arasındaki başlatma sırasını yönetmek
- Servis loglarını journal üzerinde toplamak

`systemctl`, systemd ile konuşmak için kullandığımız komuttur. Örneğin `sudo systemctl start dummy` "dummy isimli servisi şimdi başlat" anlamına gelir. Burada `sudo` komutu yönetici yetkisiyle çalıştırır, `systemctl` servisleri yönetir, `start` yapılacak işlemdir, `dummy` ise servisin adıdır.

> Not: `systemd` komutlarda `dummy.service` dosyasını arar. `.service` uzantısını çoğu komutta yazmak zorunda değilsin; `sudo systemctl start dummy` ile `sudo systemctl start dummy.service` aynı servisi ifade eder.

---

## Proje Dosyaları

| Dosya | Repo Yolu (kopya) | Gerçek Yolu (sistemde) | Görevi |
|------|-------------------|------------------------|--------|
| `dummy.sh` | `dummy.sh` | `/usr/local/bin/dummy.sh` | Her 10 saniyede bir log mesajı üreten betik |
| `dummy.service` | `dummy.service` | `/etc/systemd/system/dummy.service` | Betiğin nasıl başlatılacağını/yeniden başlatılacağını tanımlayan unit dosyası |
| log dosyası | — | `/var/log/dummy-service.log` | Betiğin kendi yazdığı log |
| systemd journal | — | — | systemd'nin servisle ilgili tuttuğu loglar |

> Repo içindeki `dummy.sh` ve `dummy.service` dosyaları, sistemdeki gerçek dosyaların **kopyasıdır**. Gerçek konumları yukarıdaki tabloda belirtilmiştir.

### `dummy.sh` — Çalışan betik

Betiğin içeriği gereksinimlerde verildiği gibidir:

```bash
#!/usr/bin/env bash

while true; do
    echo "$(date --iso-8601=seconds) Dummy service is running..." |
        tee -a /var/log/dummy-service.log
    sleep 10
done
```

Sonsuz bir döngüde, her 10 saniyede bir mesajı `/var/log/dummy-service.log` dosyasına ekler.

### `dummy.service` — systemd unit dosyası

```ini
[Unit]
Description=Dummy long-running logging service
After=local-fs.target

[Service]
Type=simple
ExecStart=/usr/local/bin/dummy.sh
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
```

**Bölümlerin ve yönergelerin anlamları:**

- **`[Unit]`** — Servisin tanımı ve diğer birimlerle ilişkisi.
  - `Description`: Servisin insan tarafından okunabilir açıklaması.
  - `After=local-fs.target`: Bu servisin, yerel dosya sistemi hazır olduktan sonra başlatılmasını söyler (log dosyasının yazılacağı dizin hazır olsun diye).
- **`[Service]`** — Servisin nasıl çalışacağının tanımı.
  - `Type=simple`: `ExecStart` ile başlatılan sürecin ana süreç olduğunu ve hemen çalışmaya başladığını belirtir (en yaygın tür).
  - `ExecStart`: Başlatılacak komut/betik.
  - `Restart=on-failure`: Süreç bir hata ile (sıfırdan farklı çıkış koduyla) çökerse otomatik yeniden başlatılır.
  - `RestartSec=5`: Yeniden başlatma işleminden önce 5 saniye bekler.
- **`[Install]`** — `enable` edildiğinde servisin nereye bağlanacağı.
  - `WantedBy=multi-user.target`: Sistem çok kullanıcılı (multi-user, yani normal çalışma) seviyesine geçtiğinde — yani açılışta — bu servisin başlatılmasını sağlar.

---

## Baştan Sonra Kurulum Adımları

### 1. Betiği oluştur ve çalıştırılabilir yap

```bash
sudo nano /usr/local/bin/dummy.sh          # içeriği yapıştır
sudo chmod +x /usr/local/bin/dummy.sh      # çalıştırma izni ver
```

### 2. Servis (unit) dosyasını oluştur

```bash
sudo nano /etc/systemd/system/dummy.service
```

### 3. Doğrula, yeniden yükle ve başlat

```bash
sudo systemd-analyze verify /etc/systemd/system/dummy.service   # sözdizimini kontrol et
sudo systemctl daemon-reload                                    # unit dosyalarını yeniden oku
sudo systemctl enable --now dummy                               # açılışta başlat + hemen başlat
sudo systemctl status dummy                                     # durumu gör
```

### 4. Logları izle

```bash
sudo tail -f /var/log/dummy-service.log   # betiğin yazdığı log dosyası
sudo journalctl -u dummy -f               # systemd'nin servise ait günlüğü
```

### 5. Son kontrol (beklenen çıktı)

```bash
systemctl is-active dummy    # active
systemctl is-enabled dummy   # enabled
```

---

## Yaygın Komutlar

Servisle etkileşim ve log takibi için kullanılan temel komutlar:

```bash
# Servisi yönetme
sudo systemctl start dummy     # şimdi başlat
sudo systemctl stop dummy      # şimdi durdur
sudo systemctl restart dummy   # yeniden başlat
sudo systemctl status dummy    # durumu göster

# Açılışta otomatik başlatma
sudo systemctl enable dummy    # açılışa ekle
sudo systemctl disable dummy   # açılıştan çıkar

# Hızlı durum sorgusu
systemctl is-active dummy      # active / inactive
systemctl is-enabled dummy     # enabled / disabled

# Loglar
sudo journalctl -u dummy -f    # systemd günlüğünü canlı izle
sudo tail -f /var/log/dummy-service.log   # betik kendi log dosyası
```

## `start` ile `enable` Arasındaki Önemli Fark

Yeni başlayanların en çok karıştırdığı noktalardan biridir:

- `sudo systemctl start dummy` → servisi **şu anda** başlatır. Ancak yeniden açılışta otomatik başlayacağını garanti etmez.
- `sudo systemctl enable dummy` → servisin **gelecek açılışlarda** otomatik başlatılmasını ayarlar. Fakat tek başına servisi hemen başlatmayabilir.

İkisini birden yapmak için:

```bash
sudo systemctl enable --now dummy   # hem açılışa ekler hem hemen başlatır
sudo systemctl disable --now dummy  # hem açılıştan çıkarır hem durdurur
```

Özet tablo:

| Komut | Şimdi çalışan servise etkisi | Sonraki açılışa etkisi |
|------|------------------------------|------------------------|
| `start` | Başlatır | Yok |
| `stop` | Durdurur | Yok |
| `enable` | Genellikle değiştirmez | Otomatik başlatır |
| `disable` | Genellikle değiştirmez | Otomatik başlatmayı kapatır |
| `enable --now` | Başlatır | Otomatik başlatır |
| `disable --now` | Durdurur | Otomatik başlatmayı kapatır |

---

## Değişiklik Yapıldığında

Yeni bir unit dosyası oluşturduktan veya var olanı değiştirdikten sonra:

```bash
sudo systemctl daemon-reload
```

Bu komut servisleri yeniden başlatmaz; yalnızca systemd'nin unit dosyalarını **diskten tekrar okumasını** sağlar.

- **`dummy.sh` içeriğini değiştirirsen** → genellikle `daemon-reload` gerekmez, servisi yeniden başlatman yeterlidir:
  ```bash
  sudo systemctl restart dummy
  ```
- **`dummy.service` dosyasını değiştirirsen** → her ikisini de yap:
  ```bash
  sudo systemctl daemon-reload
  sudo systemctl restart dummy
  ```

---

## Proje Tamamlandığında

Bu projeyle yalnızca dummy betiğini değil; aynı mantıkla bir **Python uygulamasını, Node.js API'sini, Java programını ya da arka plan worker'ını** systemd ile çalıştırmanın temelini öğrenmiş olursun. Değişen esas olarak `ExecStart` satırı ve uygulamanın ihtiyaç duyduğu kullanıcı, çalışma dizini ve ortam ayarlarıdır.

### Kaynaklar

- [systemd ve bileşenleri (GeeksforGeeks)](https://www.geeksforgeeks.org/linux-unix/linux-systemd-and-its-components/)
...
vb.

