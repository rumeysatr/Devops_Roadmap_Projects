# Yol Haritası — Projeyi Adım Adım Tamamlama

> Bu doküman, projeyi **hangi sırayla** ve **nasıl** tamamlayacağını yüksek seviyeden anlatır. Her aşamanın detayı ilgili dokümandadır; burası bir bakış ve pusula sayfasıdır.

## Temel İlke: İçeriden Dışarıya Doğru

Projeyi şu akış mantığıyla ilerlet: **lokalde çalışsın → konteynerleşsin → uzak sunucuya taşısın → otomatikleşsin → süsle.** Her aşama bir öncekinin çalıştığını doğrulamadan bir sonrakine geçme. Aksi halde (örneğin API lokalde çalışmadan Docker'a geçersen) hatanın kaynağını bulmak çok zorlaşır.

```
[0] Hazırlık
   │
   ▼
[1] API'yi lokalde geliştir ve çalıştır ──────▶ http://localhost:3000 çalışıyor mu?
   │                                            ✅ curl ile todo ekle/sil
   ▼
[2] Dockerize et + docker-compose (Mongo+API) ▶ docker compose up → hâlâ çalışıyor mu?
   │                                            ✅ veri konteyner silinince de duruyor mu?
   ▼
[3] AWS EC2 sunucusunu Terraform ile oluştur ▶ ssh ubuntu@<ip> ile girebiliyor musun?
   │                                            ✅ terraform output → public ip
   ▼
[4] Sunucuyu Ansible ile yapılandır (Docker)  ▶ sunucuda docker compose up çalışıyor mu?
   │                                            ✅ http://<ip>:3000/todos cevap veriyor mu?
   ▼
[5] GitHub Actions ile CI/CD kur            ──▶ git push → otomatik mi deploy oluyor?
   │                                            ✅ yeni commit sunucuya düşüyor mu?
   ▼
[6] (Bonus) Nginx reverse proxy ekle        ──▶ http://<ip> tek porttan mı servis ediliyor?
```

---

## Aşamalar ve Çıktıları

### Aşama 0 — Hazırlık (≈ 15 dk)
- [*] Önkoşulları kur (Node, Docker, Terraform, Ansible, AWS CLI) — bkz. [README](README.md#önkoşullar)
- [*] AWS CLI'yı `aws configure` ile yapılandır
- [ ] Bir SSH anahtar çifti üret (`ssh-keygen`) — public key'i Terraform kullanacak
- [ ] Docker Hub'da bir **Access Token** oluştur (CI/CD push'ları için)
- [ ] GitHub'da repo aç ve proje klasörünü init et

### Aşama 1 — API Geliştirme → [02-todo-api-gelistirme.md](02-todo-api-gelistirme.md)
- [ ] `package.json` + bağımlılıklar (`express`, `mongoose`, `dotenv`; dev: `nodemon`)
- [ ] `models/Todo.js` Mongoose şeması (`title`, `completed`, `createdAt`)
- [ ] `server.js`: Mongo bağlantısı + 5 endpoint (`GET/POST/GET:id/PUT:id/DELETE:id`)
- [ ] `.env` ile `MONGO_URI` ve `PORT` yönetimi
- [ ] **Doğrulama:** `npm run dev` → `curl` ile CRUD testi. Mongo'yu lokalde çalıştır (örn. `docker run -p 27017:27017 mongo:7`) ya da MongoDB Atlas kullan.

> 💡 Bu aşamada Mongo'yu ayrı bir konteyner olarak `docker run` ile başlatmak, Aşama 2'nin mantığına ısınmak için harika bir alıştırmadır.

### Aşama 2 — Dockerize + Compose (Gereksinim #1) → [03-dockerizasyon-compose.md](03-dockerizasyon-compose.md)
- [ ] `Dockerfile` yaz (Node imajı, `npm ci --omit=dev`, `CMD ["node", "server.js"]`)
- [ ] `.dockerignore` ekle (`node_modules`, `.env`, `.git`)
- [ ] `docker-compose.yml`: `api` (build) + `mongo` (image) servisleri
- [ ] **Named volume** ile veri kalıcılığı (`todo-data` → `/data/db`)
- [ ] `MONGO_URI`'yi compose içinden `mongodb://mongo:27017/todos` olarak ver
- [ ] **Doğrulama:** `docker compose up` → `http://localhost:3000`. Konteynerleri silip yeniden açınca todo'lar duruyor mu kontrol et.
- [ ] Docker Hub'a image push'la (`<kullanici>/todo-api:latest`)

> ⚠️ En sık hata: volume eklemeden `docker compose down -v` yapmak veriyi siler. Kalıcılığı test ederken `-v` kullanma.

### Aşama 3 — AWS EC2 ile Terraform (Gereksinim #2, 1. parça) → [04-terraform-aws-sunucu.md](04-terraform-aws-sunucu.md)
- [ ] `terraform/` klasörü: `providers.tf`, `variables.tf`, `main.tf`, `outputs.tf`
- [ ] Ubuntu 24.04 AMI, `t3.micro`, SSH key pair, Security Group (SSH 22 + HTTP 80)
- [ ] `terraform.tfvars` (kendi değerlerinle)
- [ ] `terraform init && terraform apply`
- [ ] **Doğrulama:** `terraform output` → public ip. `ssh -i <key> ubuntu@<ip>` ile giriş.

### Aşama 4 — Ansible ile Yapılandırma (Gereksinim #2, 2. parça) → [05-ansible-konfigurasyon.md](05-ansible-konfigurasyon.md)
- [ ] `ansible/inventory.ini` (EC2 ip + `ansible_user=ubuntu` + key)
- [ ] `ansible.cfg` (host_key_checking, roles_path)
- [ ] Playbook + role: **Docker engine + compose plugin** kur, `ubuntu`'yi `docker` grubuna ekle, `docker-compose.yml` + `.env`'i sunucuya kopyala, `docker compose pull && docker compose up -d`
- [ ] **Doğrulama:** `ansible-playbook` çalıştır → `http://<ip>:3000/todos` cevap vermeli.

> 💡 Kardeş `nodejs-service-deployment/ansible` projesinde rol, sunucuya Node + Nginx kuruyordu (bare-metal). Burada rol tamamen farklı: **Docker** kuruyoruz ve uygulama bir konteyner olarak çalışıyor. Farkı vurgulamak öğrenmeyi pekiştirir.

### Aşama 5 — CI/CD ile GitHub Actions (Gereksinim #3) → [06-cicd-github-actions.md](06-cicd-github-actions.md)
- [ ] `.github/workflows/deploy.yml`: `push: main` + `workflow_dispatch` trigger
- [ ] Job 1: `docker build` → Docker Hub'a push (`latest` + git sha tag)
- [ ] Job 2: SSH ile sunucuya git → `docker compose pull && docker compose up -d` (VEYA Ansible çağır)
- [ ] GitHub **secrets**'ları tanımla (`DOCKERHUB_USERNAME`, `DOCKERHUB_TOKEN`, `EC2_SSH_PRIVATE_KEY`, `EC2_HOST`, `EC2_USER`)
- [ ] **Doğrulama:** `git push` → Actions tab'inden pipeline'ı izle → sunucudaki `/todos` güncellenmiş mi?

### Aşama 6 — Bonus: Nginx Reverse Proxy → [07-nginx-reverse-proxy.md](07-nginx-reverse-proxy.md)
- [ ] `nginx/nginx.conf`: `/` → `proxy_pass http://api:3000`
- [ ] `docker-compose.yml`'e `nginx` servisi ekle, `:80`'i dışa aç
- [ ] API ve Mongo'yu yalnız dahili ağda bırak
- [ ] **Doğrulama:** `http://<ip>` (80 port) API'ye ulaşır; doğrudan `:3000` artık dışa kapalı.

---

## Tahmini Süre ve Bağımlılıklar

| Aşama | Tahmini süre | Önceki aşama | Hata yaparsan dönülecek yer |
|-------|-------------|--------------|------------------------------|
| 0 Hazırlık | 15 dk | — | Önkoşul kurulumu |
| 1 API | 1–2 sa | 0 | API kodu / Mongo bağlantısı |
| 2 Docker | 1–2 sa | 1 | Dockerfile / compose / volume |
| 3 Terraform | 30–60 dk | 0 (paralel olabilir) | AWS yetkileri / SG / key |
| 4 Ansible | 1–2 sa | 2 + 3 | Docker kurulumu / env / idempotency |
| 5 CI/CD | 1 sa | 2 + 3 + 4 | Secrets / SSH / image push |
| 6 Nginx | 30 dk | 2 | nginx.conf / network |

> **Not:** Aşama 3 (Terraform) ile Aşama 1–2 (API + Docker) birbirinden bağımsızdır; paralel ilerleyebilirsin. Ama Aşama 4 (Ansible), hem çalışır bir image (Aşama 2 sonucu Docker Hub'a push'lanmış) hem de canlı bir sunucu (A��ama 3) ister.

---

## Tek Bakışta Karar Defteri

Bu kararlar tüm dokümanlarda tutarlıdır; kafan karışırsa buraya dön:

| Karar | Değer |
|-------|-------|
| API servisi adı (compose) | `api` |
| Mongo servisi adı (compose) | `mongo` |
| API portu | `3000` |
| Mongo portu | `27017` |
| Nginx portu (bonus) | `80` |
| Mongo bağlantı URI (compose içi) | `mongodb://mongo:27017/todos` |
| Volume adı | `todo-data` |
| Docker image | `<dockerhub-kullanici-adi>/todo-api` |
| AWS region | `eu-central-1` |
| EC2 instance | `t3.micro` (Ubuntu 24.04) |
| EC2 kullanıcı | `ubuntu` |

Sıradaki adım: [02-todo-api-gelistirme.md](02-todo-api-gelistirme.md) ile API'yi yazmaya başla.
