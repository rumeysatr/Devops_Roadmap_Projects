# Aşama 2 — Dockerize + docker-compose (Gereksinim #1)

> **Karşıladığı gereksinim:** #1 — API'yi ve MongoDB'yi konteynerleştirip `docker-compose` ile birlikte çalıştırmak ve veriyi **kalıcı** kılmak.
>
> **Önceki aşama:** [02-todo-api-gelistirme.md](02-todo-api-gelistirme.md) · **Sonraki aşama:** [04-terraform-aws-sunucu.md](04-terraform-aws-sunucu.md)

## Amaç

Aşama 1'de yazdığımız API bir konteynerde, MongoDB başka bir konteynerde çalışacak. Tek bir `docker compose up` komutuyla ikisi birden ayağa kalkacak, API Mongo'ya ulaşacak ve konteynerleri durdurup başlatsan bile todo'lar silinmeyecek.

---

## Önemli Kavramlar

**İmaj (image) vs konteyner (container)** — İmaj, bir uygulamanın değişmez, taşınabilir paketidir (tarif gibidir). Konteyner, o imajdan çalıştırılan bir örnektir (tariften pişen yemek). Bir imajdan sınırsız konteyner çalıştırabilirsin.

**Dockerfile** — Bir imajı sıfırdan nasıl inşa edeceğinin tarifi: hangi taban imajdan başlanacağı, hangi dosyaların kopyalanacağı, hangi komutların çalışacağı ve giriş noktası.

**Docker Compose** — Birden fazla konteyneri **birlikte** tanımlayıp yöneten araç. `docker-compose.yml` dosyasında servisleri, ağları ve volume'ları tek yerde bildirirsin; `docker compose up` hepsini doğru sırayla başlatır. Burada kritik olan: API konteynerinin Mongo konteynerine **servis adıyla** (`mongo`) ulaşabilmesi.

**Volume (veri kalıcıl��ğı)** — Konteyner geçicidir; silinen bir konteynerin içindeki veri de gider. MongoDB verisini konteynerin dışında, Docker'ın yönettiği bir volume'da tutarsak, konteyneri silip yeniden oluştursak bile veri korunur. Bu, gereksinimin açıkça istediği şeydir.

**Çok-aşamalı (multi-stage) build** — İmajı küçültmek için: ilk aşamada bağımlılıkları derler/çalıştırır, son aşamaya yalnızca gerekli çıktıyı kopyalarsın. Bu proje için opsiyoneldir ama iyi bir alışkanlıktır (aşağıda sade ve çok-aşamalı iki örneği de veriyoruz).

---

## Adım 1 — `Dockerfile`

Proje köküne `Dockerfile` ekle:

```dockerfile
# Node.js LTS alpine imajı — küçük ve güvenli
FROM node:20-alpine

# Uygulama dizini
WORKDIR /app

# Önce sadece bağımlılık dosyalarını kopyala (önbellekleme için)
COPY package*.json ./

# Production bağımlılıklarını kur (devDependencies değil)
RUN npm ci --omit=dev

# Uygulama kaynak kodunu kopyala
COPY . .

# API'nin dinlediği portu dışa aç
EXPOSE 3000

# Uygulamayı başlat
CMD ["node", "server.js"]
```

**Neden `package*.json` önce?** Docker, her talimat için bir katman önbelleğe alır. `package*.json`'u ayrı kopyaladığında, kaynak kodu değişse bile bağımlılık kurulumu (`npm ci`) tekrarlanmaz; sadece `server.js` değiştiğinde son katman yeniden inşa edilir. Bu, build süresini ciddi kısaltır.

**Neden `npm ci --omit=dev`?** `ci` (clean install), `package-lock.json`'a sadık kalarak tekrar üretilebilir bir kurulum yapar. `--omit=dev` ise `nodemon` gibi geliştirme araçlarını imaja sokmaz; imaj küçük ve güvenli kalır.

**İstersen çok-aşamalı sürüm (opsiyonel):**

```dockerfile
# --- Aşama 1: bağımlılıklar ---
FROM node:20-alpine AS deps
WORKDIR /app
COPY package*.json ./
RUN npm ci --omit=dev

# --- Aşama 2: çalışma zamanı ---
FROM node:20-alpine
WORKDIR /app
COPY --from=deps /app/node_modules ./node_modules
COPY . .
EXPOSE 3000
CMD ["node", "server.js"]
```

Burada final imajda derleme araçları veya gereksiz dosyalar olmaz; sadece koşmaya hazır uygulama kalır.

---

## Adım 2 — `.dockerignore`

`.gitignore` gibi çalışır: imaja **giren** dosyaları sınırlar. Özellikle `.env`'i hariç tutmak güvenlik için kritik (sırlar imaja, oradan Docker Hub'a gitmemeli).

```gitignore
# .dockerignore
node_modules
npm-debug.log
.env
.env.*
!.env.example
.git
.gitignore
Dockerfile
.dockerignore
docker-compose.yml
terraform/
ansible/
docs/
README.md
*.md
```

> ⚠️ `node_modules`'u imaja kopyalamak yaygın bir hatadır: makinendeki (örn. Linux/WSL) `node_modules` başka bir mimari için derlenmiş olabilir. İçinde `npm ci` ile temiz kurulmuş `node_modules` olmalı.

---

## Adım 3 — `docker-compose.yml`

Bu dosya projenin kalbidir: iki servisi, ağlarını ve volume'unu tanımlar.

```yaml
# docker-compose.yml
services:
  # --- API servisi ---
  api:
    build: .                  # mevcut dizindeki Dockerfile'dan imaj inşa et
    container_name: todo-api
    restart: unless-stopped   # çökerse otomatik yeniden başlat
    ports:
      - "3000:3000"           # host:3000 -> konteyner:3000
    environment:
      - PORT=3000
      - MONGO_URI=mongodb://mongo:27017/todos   # servis adıyla Mongo'ya bağlan
    depends_on:
      mongo:
        condition: service_healthy  # Mongo hazır olmadan API başlamasın
    # NOT: volume yok — API durum bilgisizdir (stateless), veriyi Mongo tutar

  # --- MongoDB servisi ---
  mongo:
    image: mongo:7            # hazır imajı çek
    container_name: todo-mongo
    restart: unless-stopped
    ports:
      - "27017:27017"
    volumes:
      - todo-data:/data/db    # veriyi kalıcı volume'da sakla
    healthcheck:
      test: ["CMD", "mongosh", "--eval", "db.adminCommand('ping')"]
      interval: 10s
      timeout: 5s
      retries: 5

# --- Kalıcı veri hacmi ---
volumes:
  todo-data:
```

**Satır satır önemli noktalar:**
- `build: .` — API imajı `Dockerfile`'dan inşa edilir. `mongo` ise hazır imaj kullanır (`image:`), build'e gerek yok.
- `MONGO_URI=mongodb://mongo:27017/todos` — buradaki `mongo`, compose dosyasındaki **servis adıdır**. Compose, servisler arasında otomatik bir DNS kurar; API konteyneri `mongo` adını çözüp veritabanına ulaşır. Lokaldeki `localhost` URI'sinin yerini burada servis adı alır.
- `depends_on` + `healthcheck` — sadece Mongo konteynerinin başlaması yetmez; **Mongo hazır** (ping atanabilir) olması gerekir. `healthcheck` bunu sağlar ve API, Mongo healthy olmadan başlamaz. Aksi halde API ilk başladığında Mongo henüz hazır değilse bağlantı hatası alırsın.
- `volumes: - todo-data:/data/db` — MongoDB verisini varsayılan olarak `/data/db` altında tutar. Bu yolu `todo-data` adlı volume'a bağlamak, veriyi konteynerin yaşam döngüsünden ayırır.
- API'de volume yok çünkü API **stateless**'tir; tüm durum veritabanındadır. Bu, ölçeklenebilir mimarinin temel kuralıdır.

---

## Adım 4 — İmajı inşa edip çalıştır

```bash
# İmajı inşa ve tüm servisleri başlat (-d: arka planda)
docker compose up --build -d

# Çalışan servisleri gör
docker compose ps

# Logları izle (API'nin "MongoDB'ye bağlanıldı" demesini bekle)
docker compose logs -f api
```

Çıktıyı test et:

```bash
curl http://localhost:3000/todos
curl -X POST http://localhost:3000/todos \
  -H "Content-Type: application/json" \
  -d '{"title":"compose ile çalışıyor"}'
```

---

## Adım 5 — Veri kalıcılığını doğrula (kritik test)

Gereksinim #1'in özü budur. Aşağıdaki akışın veriyi koruması gerekir:

```bash
# 1. Bir todo ekle
curl -X POST http://localhost:3000/todos -H "Content-Type: application/json" -d '{"title":"kalıcı veri testi"}'

# 2. Tüm servisleri durdur ve SİL (-v OLMADAN! volume'u korur)
docker compose down

# 3. Yeniden başlat
docker compose up -d

# 4. Tekrar listele — todo hâlâ orada olmalı
curl http://localhost:3000/todos
```

> ⚠️ `docker compose down -v`'deki `-v` bayrağı **volume'u da siler**. Bu komutu yalnızca veriyi bilerek yok etmek istediğinde kullan. Kalıcılık testinde asla `-v` kullanma.

**Hızlı kontrol:** `docker volume ls` komutu `todo-data` adında bir volume görmelidir.

---

## Adım 6 — İmajı Docker Hub'a push'la

Sunucu (Aşama 3–4) ve CI/CD (Aşama 5) bu imajı Docker Hub'dan çekecek. Önce imajı doğru etiketle push'la:

```bash
# Docker Hub'a giriş yap (kullanıcı adın ve access token)
docker login

# İmajı inşa et ve Docker Hub ad alanınla etiketle
docker build -t <dockerhub-kullanici-adi>/todo-api:latest .

# Push'la
docker push <dockerhub-kullanici-adi>/todo-api:latest
```

**Etiketleme (tag) stratejisi:** Üretimde sadece `latest` yeterli değildir — hangi sürümün çalıştığını bilmek istersin. Yaygın yöntem: hem `latest` hem de `git commit sha` ile etiketlemek.

```bash
SHA=$(git rev-parse --short HEAD)
docker tag <dockerhub-kullanici-adi>/todo-api:latest <dockerhub-kullanici-adi>/todo-api:$SHA
docker push <dockerhub-kullanici-adi>/todo-api:$SHA
```

Böylece geri dönüş (rollback) yapmak istersen belirli bir sha'ya çekim yapabilirsin. Bu yöntem CI/CD aşamasında otomatikleşecek (bkz. [06-cicd-github-actions.md](06-cicd-github-actions.md)).

> **Üretim compose'unu düşün:** Sunucuda `build: .` çalışmaz (kaynak kodu orada yok). Bunun yerine imaj adı verirsin: `image: <dockerhub-kullanici-adi>/todo-api:latest`. CI/CD aşamasında sunucu için ayrı bir compose (örn. `docker-compose.prod.yml`) kullanmak yaygındır. Detay için [05-ansible-konfigurasyon.md](05-ansible-konfigurasyon.md) ve [06-cicd-github-actions.md](06-cicd-github-actions.md).

---

## Doğrulama

Aşama 2 başarılıysa:
- ✅ `docker compose up --build -d` iki konteyneri de başlatır
- ✅ `docker compose ps` `api` ve `mongo`'yu "healthy"/"running" gösterir
- ✅ `http://localhost:3000/todos` cevap verir
- ✅ `docker compose down` → `docker compose up` sonrası todo'lar duruyorsa kalıcılık sağlanmış demektir
- ✅ `docker volume ls` `todo-data`'yı listeler
- ✅ İmaj Docker Hub'a push'landı ve `docker pull <kullanici>/todo-api:latest` başkası tarafından çekilebilir

---

## Sık Karşılaşılan Hatalar

| Belirti | Olası neden | Çözüm |
|---------|-------------|-------|
| API "ECONNREFUSED mongo:27017" | API Mongo'dan önce başladı | `depends_on` + `healthcheck` ekle; Mongo hazır olana dek bekle |
| `MONGO_URI` hâlâ `localhost` | compose env override olmadı | URI'da servis adı `mongo` kullan; lokal `.env` compose'a sızmasın |
| `docker compose down` sonrası veri silindi | `-v` kullandın | Kalıcılık testinde `-v` kullanma |
| İmaj çok büyük / yavaş | `node_modules` imajda veya dev deps var | `.dockerignore`'a `node_modules` ekle; `npm ci --omit=dev` kullan |
| Build farklı davranıyor | önbellek eski `node_modules` kopyaladı | `docker compose build --no-cache` ile temiz inşa et |
| Mongo healthcheck "mongosh not found" | eski mongo imajı (`mongo:5`- ve `mongo` yerine `mongo` shell) | `mongo:7` kullan; `mongo:4`'te `mongo --eval` gerekir |
| `pull access denied` (push sonrası) | imaj ad alanın yanlış | Etiket `<dockerhub-kullanici-adi>/todo-api` olmalı; repoyu Docker Hub'da public yap veya login ol |

Sonraki aşamada bu imajı çalıştıracak bir AWS sunucusunu Terraform ile oluşturacağız: [04-terraform-aws-sunucu.md](04-terraform-aws-sunucu.md).
