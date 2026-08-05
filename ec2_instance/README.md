# EC2 Instance Projesi

Bu proje, [roadmap.sh](https://roadmap.sh) DevOps yol haritasının başlangıç seviyesi projelerinden biridir. Amaç, AWS üzerinde bir Linux sunucusu (EC2) kurmak, SSH ile güvenli bir şekilde bağlanmak ve basit bir statik web sitesini yayına almaktır.

Proje tamamlandı: AWS hesabı oluşturuldu, EC2 örneği kuruldu, Nginx ile statik site yayına alındı ve public IP üzerinden erişilebildiği test edildi.

---

## Projenin Amacı

Bulut bilişim ve AWS konusunda pratik deneyim kazanmak. Özellikle temel AWS kaynaklarını oluşturmak, EC2 örneği başlatıp yapılandırmak, SSH ile Linux sunucusuna bağlanmak ve statik bir web sitesini bulut altyapısına dağıtmak hedefleniyor.

---

## İstenen Görevler (Gereksinimler)

Aşağıdaki görevler roadmap.sh proje tanımında zorunlu olarak istenmiştir:

1. Bir AWS hesabı oluşturmak (veya mevcut hesabı kullanmak).
2. AWS Yönetim Konsolu'nu (Management Console) tanımak.
3. Şu özelliklere sahip bir EC2 örneği başlatmak:
   - Ubuntu Server AMI kullanmak.
   - `t2.micro` örnek türü seçmek (AWS Free Tier kapsamında).
   - Bölge için varsayılan (default) VPC ve alt ağ (subnet) kullanmak.
   - Güvenlik grubunu (security group) **22 (SSH)** ve **80 (HTTP)** portlarında gelen trafiğe izin verecek şekilde yapılandırmak.
   - SSH erişimi için yeni bir anahtar çifti (key pair) oluşturmak veya mevcut olanı kullanmak.
   - Örneğe bir genel (public) IP adresi atamak.
4. SSH ve özel anahtar (private key) kullanarak EC2 örneğine bağlanmak.
5. Sistem paketlerini güncellemek ve bir web sunucusu (Nginx) kurmak.
6. Statik web sitesi için basit bir HTML dosyası oluşturmak.
7. Statik web sitesini EC2 örneğine dağıtmak (deploy).
8. EC2 örneğinin public IP adresini kullanarak web sitesine erişmek.

---

## Yapılanlar

Projenin tüm zorunlu görevleri eksiksiz şekilde tamamlandı ve doğrulandı:

- **AWS hesabı** oluşturuldu ve Management Console üzerinden kaynaklar yönetildi.
- **Ubuntu Server AMI** ile bir EC2 örneği başlatıldı.
- **Örnek türü olarak `t3.micro` kullanıldı.** (Proje dokümanında `t2.micro` önerilmiş olsa da güncel Free Tier kapsamında `t3.micro` tercih edildi. Bu, dokümanın eski kalmış olabileceğini gösterir.)
- **Default VPC ve subnet** kullanılarak ağ yapılandırması yapıldı.
- **Public IP** atandı, böylece örnek internetten erişilebilir hale geldi.
- **Security Group** kuralı eklendi: SSH için port **22**, HTTP için port **80**.
- **SSH key pair** oluşturuldu ve özel anahtarla sunucuya bağlanıldı.
- Sunucuda paketler güncellendi (`sudo apt update`) ve **Nginx** kuruldu.
- Proje özetini anlatan, tasarlanmış tek sayfalık bir **HTML dosyası** (`index.html`) oluşturuldu.
- HTML dosyası EC2 örneğine **deploy edildi** ve Nginx üzerinden sunulmaya başlandı.

---

## Kullanılan Teknolojiler

- **AWS EC2** — Linux sanal sunucu
- **Ubuntu Server** — işletim sistemi (AMI)
- **Nginx** — statik web sunucusu
- **SSH / Key Pair** — güvenli bağlantı
- **Security Groups** — ağ erişim kontrolü
- **HTML/CSS** — statik web sayfası

---

## Proje Yapısı

```
ec2_instance/
├── README.md            # Bu dosya — proje açıklaması
├── index.html           # EC2'ye dağıtılan statik web sitesi
└── docs/
    ├── tr_subject.md    # Proje konusu (Türkçe)
    ├── eng_subject.md   # Proje konusu (İngilizce)
    └── to-do.md         # Yapılanlar ve doğrulama notları
```

`index.html`, sunucunun `/var/www/html/` dizininde Nginx tarafından sunulan dosyadır. Sayfa; proje genel bakışını, dağıtım akışını (provision → secure → configure → publish), gereksinimleri ve öğrenim çıktılarını görsel olarak anlatan, modern ve responsive tasarımlı tek bir sayfadır.

---

## Doğrulama / Test

Dağıtımın çalıştığı şu komutla doğrulandı:

```bash
curl http://PUBLIC_IP_ADRESIN
```

Ayrıca tarayıcıdan `http://PUBLIC_IP_ADRESIN` adresine gidildiğinde kendi oluşturulan HTML sayfasının döndüğü görüldü. Site beklendiği gibi çalışıyor.

---

## Temel Komutlar

Sunucuya bağlanma ve dağıtım için kullanılan temel komutlar:

```bash
# Sunucuya SSH ile bağlanma
ssh -i my-key.pem ubuntu@your-ec2-public-ip

# Paketleri güncelleme ve Nginx kurma
sudo apt update
sudo apt install -y nginx

# Statik siteyi web root'a kopyalama
sudo cp index.html /var/www/html/index.html

# Erişim
curl http://your-ec2-public-ip
```

---

## Gelişmiş Hedefler (Stretch Goals)

Bu hedefler zorunlu değil, kendini daha da zorlamak isteyenler içindir. Bu projede uygulanmadı:

- **Özel alan adı:** Amazon Route 53 ile web sitesi için özel domain ayarlamak.
- **HTTPS:** Let's Encrypt'ten ücretsiz SSL/TLS sertifikası alarak güvenli bağlantı sağlamak.
- **CI/CD:** AWS CodePipeline ile site değişikliklerini otomatik dağıtan basit bir boru hattı oluşturmak.

---

## Öğrenim Çıktıları

Bu proje tamamlandıktan sonra şu konularda pratik deneyim kazanılmış oldu:

- Temel AWS kaynaklarının oluşturulması
- AWS örnekleri (instance), türleri ve aralarındaki farklar
- EC2 örneklerinin başlatılması ve yapılandırılması
- SSH ile Linux sunucularına bağlanma
- Temel sunucu yönetimi ve web sunucusu kurulumu
- Statik web sitelerini bulut altyapısına dağıtma
