# Aşama 6 (Bonus) — Nginx Reverse Proxy

> **Karşıladığı gereksinim:** 🌟 Bonus — docker-compose içinde bir Nginx reverse proxy kurarak uygulamaya `http://sunucu-ip` (80 port) üzerinden erişmek.
>
> **Önceki aşama:** [06-cicd-github-actions.md](06-cicd-github-actions.md) · **Başa dön:** [README.md](README.md)

## Amaç

API konteynerini doğrudan `:3000` portundan yayınlamak yerine, önüne bir **Nginx** konteyneri koymak. Böylece kullanıcı tek bir port (`80`) üzerinden girer; Nginx isteği içerideki API'ye (`api:3000`) yönlendirir. API ve MongoDB dış dünyaya hiç açılmadan yalnızca konteynerler arası dahili ağda kalır.

---

## Önemli Kavramlar

**Reverse proxy** — İstemci ile arka uç (backend) servis arasında duran bir aracı. İstekleri alır, uygun arka uca (burada API) iletir, cevabı döner. İstemci arka ucu görmez; yalnızca proxy ile konuşur.

**Neden bir reverse proxy isteyesin?**
- **Tek giriş noktas��:** Dışarıya yalnızca bir port (80) açarsın. API, veritabanı gibi servisler dahili ağda gizli kalır.
- **Port temizliği:** Kullanıcı `http://sunucu-ip` (port belirtmeden) girer; `:3000`'i hatırlamaz.
- **Gelecek için temel:** Birden fazla servis olursa (örn. başka bir API, bir statik site), hepsini Nginx tek porttan farklı yollarla (`/api`, `/blog`) yayınlar. Ayrıca TLS/HTTPS (SSL) sertifikası da genellikle Nginx seviyesinde sonlandırılır — ileride Let's Encrypt eklemek için doğru yer burasıdır.

**Compose ağı:** Docker Compose varsayılan olarak tüm servisleri aynı ağa koyar; servisler birbirlerine **servis adıyla** (`api`, `mongo`, `nginx`) ulaşır. Reverse proxy, `api` adını çözüp ona `proxy_pass` yapar.

---

## Adım 1 — Nginx ayar dosyası

`nginx/nginx.conf` oluştur:

```nginx
# nginx/nginx.conf
events {
    worker_connections 1024;
}

http {
    # API konteynerine yönlendir (servis adı: api, port: 3000)
    upstream todo_api {
        server api:3000;
    }

    server {
        listen 80;
        server_name _;   # tüm host'ları kabul et

        # Tüm istekleri API'ye proxy'le
        location / {
            proxy_pass http://todo_api;
            proxy_http_version 1.1;

            # Gerçek istemci bilgilerini API'ye ilet
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
        }
    }
}
```

**Satır satır:**
- `upstream todo_api { server api:3000; }` — `api` compose servis adıdır; Nginx bunu DNS'ten çözer. Bu blok backend'i isimlendirir.
- `listen 80` — Nginx 80 portunu dinler (dışarıya açacağımız tek port).
- `proxy_pass http://todo_api` — gelen isteği upstream'e (API'ye) iletir.
- `proxy_set_header` satırları — API, isteğin gerçekten nereden geldiğini bilsin diye asıl istemci IP'sini ve protokolü iletir. Loglama ve ileride rate-limit/güvenlik için gerekir.

---

## Adım 2 — `docker-compose.yml`'i güncelle

Nginx servisini ekle ve **API'nin dış portunu kaldır** (sadece dahili ağda kalsın):

```yaml
# docker-compose.yml (Nginx eklendi)
services:
  # --- API: artık dışarıya port açmıyor, sadece dahili ağda ---
  api:
    build: .                                  # (prod'da image: <kullanici>/todo-api:latest)
    container_name: todo-api
    restart: unless-stopped
    # ports: KALDIRILDI — dışarıdan :3000 erişimi yok
    expose:
      - "3000"                                # compose ağı içinde 3000 açık
    environment:
      - PORT=3000
      - MONGO_URI=mongodb://mongo:27017/todos
    depends_on:
      mongo:
        condition: service_healthy

  # --- MongoDB: hâlâ sadece dahili ---
  mongo:
    image: mongo:7
    container_name: todo-mongo
    restart: unless-stopped
    volumes:
      - todo-data:/data/db
    # ports: KALDIRILDI — dışarıdan :27017 yok
    healthcheck:
      test: ["CMD", "mongosh", "--eval", "db.adminCommand('ping')"]
      interval: 10s
      timeout: 5s
      retries: 5

  # --- Nginx: dış dünyaya açık tek giriş noktası ---
  nginx:
    image: nginx:alpine
    container_name: todo-nginx
    restart: unless-stopped
    ports:
      - "80:80"                               # tek dış port
    volumes:
      - ./nginx/nginx.conf:/etc/nginx/nginx.conf:ro   # config'i bağla (salt-okunur)
    depends_on:
      - api

volumes:
  todo-data:
```

**Kritik değişiklikler:**
- API'nin `ports: "3000:3000"` satırını **sildik** ve yerine `expose: "3000"` koyduk. Farkı: `ports` portu **host'a** (dış dünyaya) açar; `expose` yalnızca compose ağı içinde görünür kılar. Artık `http://sunucu-ip:3000` çalışmaz — ama Nginx içeriden `api:3000`'e hâlâ ulaşır.
- Mongo'nun `ports`'unu da kald��rdık; veritabanı tamamen dahili.
- Nginx `ports: "80:80"` ile tek dış port olur.
- `volumes: ./nginx/nginx.conf:/etc/nginx/nginx.conf:ro` — yerel config dosyasını konteynere bağlar. `:ro` (read-only) ile Nginx config'i değiştiremez; güvenlik ve netlik için.
- `depends_on: api` — Nginx, API'den önce başlamaya çalışırsa `proxy_pass` geçici olarak hata verir; bu bağımlılık sırayı düzeltir.

> **Prod compose'u için:** Sunucudaki `ansible/.../files/docker-compose.yml` dosyasını da aynı şekilde güncelle (Nginx servisi ekle, API/Mongo portlarını kapat). Ansible'ın `copy` adımına `nginx/nginx.conf`'u da eklemeyi unutma.

---

## Adım 3 — Çalıştır ve test et

```bash
# Lokalde
docker compose up --build -d
docker compose ps          # api, mongo, nginx üçü de running

# 80 portundan eriş (port belirtmeden!)
curl http://localhost/todos
curl -X POST http://localhost/todos -H "Content-Type: application/json" -d '{"title":"nginx üzerinden"}'
```

Dışarıdan doğrudan 3000'in kapandığını doğrula:

```bash
curl http://localhost:3000/todos   # bağlanamamalı (port dışa kapalı)
```

---

## Adım 4 — (Opsiyonel) Gerçek domain

Bir domain'in varsa, DNS A kaydını EC2 public IP'ne yönlendir. Sonra `nginx.conf` içindeki `server_name _;` yerine domain'ini yaz:

```nginx
server_name todolar.seninalanin.com;
```

Böylece `http://todolar.seninalanin.com` çalışır. HTTPS için bir sonraki adımda Let's Encrypt + Certbot ekleyebilirsin (bonus'un bonusu) — bu genellikle bir `certbot` konteyneri ve Nginx config'inde TLS bloğu ile yapılır.

---

## Doğrulama

Bonus başarılıysa:
- ✅ `docker compose ps` `api`, `mongo`, `nginx` üçünü de gösterir
- ✅ `http://<ip>` (port belirtmeden, 80) `/todos` cevap verir
- ✅ `http://<ip>:3000` dışarıdan **erişilemez** (port kapalı)
- ✅ `http://<ip>:27017` dışarıdan erişilemez
- ✅ Nginx log'ları (`docker compose logs nginx`) istekleri gösterir ve doğru backend'e ilettiğini doğrular
- ✅ AWS Security Group'ta yalnızca 22 ve 80 açık; 3000/27017'e gerek yok

---

## Sık Karşılaşılan Hatalar

| Belirti | Olası neden | Çözüm |
|---------|-------------|-------|
| `502 Bad Gateway` | Nginx ayağa kalktı ama API henüz hazır / yanlış upstream | `upstream`'te `api:3000` mi? `depends_on` var mı? `docker compose logs api` ile API'nin hazır olduğunu gör |
| `host not found in upstream "api"` | servis adı uyuşmuyor veya aynı ağda değiller | compose servis adının `api` olduğundan emin ol; hepsi default ağda |
| `http://<ip>` çalışıyor ama `:3000` de çalışıyor | API `ports` hâlâ açık | `ports`→`expose` değişikliğini yaptığından emin ol |
| Config değişikliği etkili değil | Nginx eski config'i yükledi | `docker compose restart nginx` veya config'i `:ro` volume ile bağladığını kontrol et |
| `bind: address already in use` (80) | başka bir süreç 80'i kullanıyor | sunucuda `sudo ss -ltnp | grep :80` ile bul; ya da Nginx'i farklı host portuna al ama amaç tek porttur |
| AWS'ten dışarı erişilemiyor | SG'de 80 açık değil | Aşama 3'teki security group'ta 80 ingress `0.0.0.0/0` olmalı |

---

## Tebrikler 🎉

Eğer tüm aşamaları tamamladıysan, elinde şu yetenek seti var:
- **Node.js + Express + Mongoose** ile bir CRUD API
- **Docker + docker-compose** ile çok-konteyner, kalıcı verili bir uygulama
- **Terraform** ile IaC tabanlı bulut sunucusu
- **Ansible** ile Docker tabanlı otomatik sunucu yapılandırması
- **GitHub Actions** ile uçtan uca CI/CD
- **Nginx** ile reverse proxy

Bu, gerçek dünyadaki container tabanlı dağıtım akışlarının özünü oluşturur. Bundan sonraki doğal adımlar: TLS/HTTPS (Let's Encrypt), monitoring (Prometheus/Grafana), log toplama, ve çoklu sunucu/orchestration (Kubernetes).

Başa dönmek için: [README.md](README.md)
