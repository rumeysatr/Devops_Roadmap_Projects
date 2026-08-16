# Multi-Container Application — Proje Rehberi

Bu doküman serisi, [roadmap.sh](https://roadmap.sh/projects/multi-container-app) üzerindeki **Multi-Container Application** projesini sıfırdan nasıl kuracağını adım adım anlatır. Amacımız: bir Node.js todo API'sini ve bir MongoDB veritabanını **ayrı iki konteyner** olarak `docker-compose` ile çalıştırmak, ardından bunu bir uzak sunucuya **Terraform + Ansible** ile kurmak ve son olarak **GitHub Actions** ile otomatik dağıtım (CI/CD) hattını kurmak.

> 📌 **Kaynak spec:** Projenin resmi gereksinimleri [docs/en_subject.md](en_subject.md) dosyasındadır. Bu rehber, o gereksinimleri karşılamak için izlenecek yolu Türkçe ve örnek kodlarla açıklar.

---

## Neler yapacağız? (Gereksinimler)

| # | Gereksinim | Karşılayan doküman |
|---|-----------|--------------------|
| — | Node.js + Express + Mongoose ile todo API'si geliştirmek | [02-todo-api-gelistirme.md](02-todo-api-gelistirme.md) |
| **#1** | API'yi ve MongoDB'yi Dockerize edip `docker-compose` ile çalıştırmak + **veri kalıcılığı** | [03-dockerizasyon-compose.md](03-dockerizasyon-compose.md) |
| **#2** | Terraform ile AWS EC2 sunucusu kurmak, Ansible ile Docker kurup image çekip çalıştırmak | [04-terraform-aws-sunucu.md](04-terraform-aws-sunucu.md) + [05-ansible-konfigurasyon.md](05-ansible-konfigurasyon.md) |
| **#3** | GitHub Actions ile CI/CD pipeline kurmak (prod'da docker-compose) | [06-cicd-github-actions.md](06-cicd-github-actions.md) |
| 🌟 | **Bonus:** docker-compose içinde Nginx reverse proxy | [07-nginx-reverse-proxy.md](07-nginx-reverse-proxy.md) |

İlk okuma için [01-yol-haritasi.md](01-yol-haritasi.md) ile başlaman önerilir; tüm aşamaların sırasını ve birbiriyle ilişkisini tek bakışta görürsün.

---

## Mimari (Hedef)

Projenin son hali aşağıdaki gibi bir mimariye sahip olacak. İstek, tarayıcıdan girer, (varsa) Nginx üzerinden API konteynerine yönlendirilir; API de verileri MongoDB konteynerinde saklar. Hepsi tek bir EC2 sunucusu üzerinde `docker-compose` ile çalışır.

```
                         ┌─────────────────────────────────────────────┐
                         │              AWS EC2 (Ubuntu 24.04)         │
   ┌──────────┐          │          docker-compose ile yönetilen       │
   │Kullanıcı │          │                                             │
   │/ tarayıcı│ ──:80──▶│  ┌──────────┐         ┌──────────────────┐   │
   └──────────┘          │  │  Nginx   │─:3000─▶│   API (Node.js)     │
   http://sunucu-ip      │  │ (reverse │         │  Express+Mongoose │ │
                         │  │  proxy)  │         └─────────┬──────────┘│
                         │  └──────────┘                   │           │
                         │                          ┌──────▼───────┐   │
                         │                          │   MongoDB    │   │
                         │                          │  (mongo:7)   │   │
                         │                          └──────┬───────┘   │
                         │                                 │           │
                         │                       ┌─────────▼──────────┐│
                         │                       │  Volume: todo-data ││  ← veri kalıcılığı
                         │                       │  (/data/db)        ││
                         │                       └────────────────────┘│
                         └─────────────────────────────────────────────┘
```

> Not: Bonus (Nginx) adımını yapmazsan API konteyneri doğrudan `:3000` portundan yayın yapar. Nginx eklediğinde dışarıya açılan port `:80` olur; API ve Mongo yalnızca konteynerler arası dahili ağda konuşur.

---

## Teknoloji Yığını

| Katman | Teknoloji | Kullanım amacı |
|--------|-----------|----------------|
| API | **Node.js + Express** | HTTP endpoint'leri |
| Veritabanı | **MongoDB + Mongoose** | Todo kayıtlarını sakla |
| Geliştirme | **nodemon** | Kod değişince sunucuyu otomatik yeniden başlat |
| Konteyner | **Docker + Docker Compose** | API ve Mongo'yu izole, birlikte çalıştır |
| Altyapı | **Terraform** (AWS provider) | EC2 sunucusunu kod ile oluştur |
| Yapılandırma | **Ansible** | Sunucuya Docker kur, image çek, çalıştır |
| CI/CD | **GitHub Actions** | Push → build → image push → deploy |
| Reverse proxy | **Nginx** (bonus) | Tek giriş noktası, port yönetimi |

---

## Önkoşullar

Başlamadan önce şu araçların makinende kurulu ve hazır olması gerekir:

- **Node.js** (v20+ önerilir) ve **npm** — API'yi lokal geliştirmek için
- **Docker** + **Docker Compose** (v2) — `docker --version` ve `docker compose version` komutları çalışsın
- **Terraform** (>= 1.5) — altyapıyı oluşturmak için
- **Ansible** — sunucuyu yapılandırmak için (`pip install ansible` veya paket yöneticisi)
- **AWS CLI** + yapılandırılmış credentials (`aws configure`) — Terraform'un AWS API'sini çağırması için
- Bir **AWS hesabı** ve bir **SSH anahtar çifti** (public key, Terraform'a verilecek)
- **Docker Hub hesabı** — image'leri push'layıp sunucudan çekebilmek için
- **GitHub** reposu — CI/CD pipeline'ını burada kuracağız

> 💡 Bu repoda, daha önce tamamladığın **`nodejs-service-deployment/`** projesi var (AWS EC2 + Terraform + Ansible + GitHub Actions ile bir "hello world" Node servisi). O projedeki `terraform/` ve `.github/workflows/deploy.yml` dosyaları bu rehberin AWS ve CI/CD adımları için harika bir başlangıç şablonudur. Yeni projenin asıl öğrenme odağı **Docker / docker-compose / MongoDB** olacaktır; AWS ve CI/CD kısımlarını o projeden referans alıp Docker'a uyarlayacağız.

---

## Önerilen Proje Klasör Yapısı

Tüm dokümanlar bu ortak yapıyı referans alır. Klasör ve dosya adları dokümanlar arasında tutarlıdır.

```
multi-container-app/
├── server.js                  # Express uygulaması + Mongo bağlantısı
├── models/
│   └── Todo.js                # Mongoose şeması
├── package.json               # bağımlılıklar (express, mongoose, ...)
├── .env.example               # örnek ortam değişkenleri (MONGO_URI, PORT)
├── Dockerfile                 # API imajını oluştur
├── .dockerignore              # imaja alınmayacak dosyalar
├── docker-compose.yml         # api + mongo (+ nginx) servisleri
├── nginx/
│   └── nginx.conf             # bonus: reverse proxy ayarı
├── terraform/                 # AWS EC2 altyapısı (main.tf, variables.tf, ...)
├── ansible/                   # sunucu yapılandırması (inventory, playbook, role)
├── .github/
│   └── workflows/
│       └── deploy.yml         # CI/CD pipeline
└── docs/                      # bu rehber dokümanları
    └── en_subject.md          # resmi proje gereksinimleri
```

---

## Dokümanlar İçindekiler

1. [01-yol-haritasi.md](01-yol-haritasi.md) — Tüm projenin adım adım yol haritası
2. [02-todo-api-gelistirme.md](02-todo-api-gelistirme.md) — Node.js todo API'sini geliştirmek
3. [03-dockerizasyon-compose.md](03-dockerizasyon-compose.md) — Dockerize + docker-compose (Gereksinim #1)
4. [04-terraform-aws-sunucu.md](04-terraform-aws-sunucu.md) — Terraform ile AWS EC2 (Gereksinim #2)
5. [05-ansible-konfigurasyon.md](05-ansible-konfigurasyon.md) — Ansible ile sunucu yapılandırması (Gereksinim #2)
6. [06-cicd-github-actions.md](06-cicd-github-actions.md) — CI/CD pipeline (Gereksinim #3)
7. [07-nginx-reverse-proxy.md](07-nginx-reverse-proxy.md) — Nginx reverse proxy (Bonus)

---

## Kullanım Kuralları (dokümanlar için)

- Kod blokları **örnek ve eğiticidir**; her satırı nedeniyle birlikte açıklanır. Sadece kopyalamak yerine ne yaptığını anlaman hedeflenir.
- `<...>` ile gösterilen yerler (örn. `<dockerhub-kullanici-adi>`) kendi değerlerinle değiştirilecek yerlerdir.
- Her dokümanın sonunda bir **Doğrulama** bölümü ve **Sık karşılaşılan hatalar** bölümü bulunur.
- Tüm dokümanlar ortak port/servis isimleri kullanır: API `3000`, Mongo `27017`, Nginx `80`.
