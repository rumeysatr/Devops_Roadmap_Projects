# Aşama 5 — CI/CD ile GitHub Actions (Gereksinim #3)

> **Karşıladığı gereksinim:** #3 — Kodu GitHub'a push'layıp bir CI/CD pipeline ile uygulamayı **otomatik olarak** uzak sunucuya dağıtmak; üretimde `docker-compose` kullanmak.
>
> **Önceki aşama:** [05-ansible-konfigurasyon.md](05-ansible-konfigurasyon.md) · **Sonraki aşama:** [07-nginx-reverse-proxy.md](07-nginx-reverse-proxy.md)

## Amaç

Artık her şey çalışıyor: API lokalde çalışıyor, Docker Hub'da imaj var, sunucu canlı, Ansible ile kurulum yapabiliyorsun. Şimdi bunu **elle yapmayı bırakıp otomatikleştireceğiz**. Hedef: `main` branch'ine `git push` yap → GitHub Actions otomatik olarak (1) imajı inşa edip Docker Hub'a push'lasın, (2) sunucuya SSH ile bağlanıp yeni imajı çekip `docker compose up` yapsın. Hepsi senin müdahalen olmadan.

> 💡 **Kardeş projene bak:** Repodaki `nodejs-service-deployment/.github/workflows/deploy.yml` dosyası SSH + Ansible mantığını içeriyor; onu temel alabilirsin. Fark: bu projede imajı önce **Docker Hub'a push** etmemiz gerekiyor (sunucuda `git clone` + `npm ci` yok, imaj çekiliyor).

---

## Önemli Kavramlar

**CI/CD** — Continuous Integration (Sürekli Entegrasyon) + Continuous Deployment/Delivery (Sürekli Dağıtım). Kod her değiştiğinde: otomatik test (CI) → imaj inşa et → yayınla → sunucuya kur (CD). Amaç: "benim makinemde çalışıyor" demeyi bırakıp, değişikliğin canlıya düşmesini tekrarlanabilir ve hatasız kılmak.

**GitHub Actions** — GitHub'ın yerleşik CI/CD motoru. Repo içinde `.github/workflows/*.yml` dosyalarıyla "ne zaman, ne çalışsın" tanımlarsın. GitHub bunu kendi sunucularında (runner) ücretsiz kotada çalıştırır.

**Workflow / Job / Step hiyerarşisi:**
- **Workflow** — bir `.yml` dosyası; bir veya daha fazla job içerir.
- **Job** — paralel veya sıralı çalışabilen adım grupları. (Bizim pipeline'da iki job var: build+push ve deploy; deploy, build bitince başlar.)
- **Step** — job içindeki tek komut veya action.

**Secrets** — Şifre, private key, token gibi hassas değerler GitHub'a **plain-text olarak değil**, şifrelenmiş "secret" olarak konur. Workflow bunlara `${{ secrets.X }}` ifadesiyle erişir; log'larda maskelenir. Asla `.yml` içine gerçek değer yazma.

**`docker-compose` üretimde** — Gereksinim #3 bunu açıkça ister. CI/CD, sunucuda `docker compose pull && docker compose up -d` çalıştırır; böylece dağıtım, geliştirmede kullandığın aynı compose mantığıyla olur.

---

## Pipeline Akışı

```
git push (main)
   │
   ▼
┌───────────────────────────────────┐
│ Job 1: build-and-push             │
│  - checkout kod                   │
│  - docker login (Docker Hub)      │
│  - docker build                   │
│  - push :latest ve :<sha>         │
└───────────────┬───────────────────┘
                │  (job dependency: needs: build-and-push)
                ▼
┌───────────────────────────────────┐
│ Job 2: deploy                     │
│  - SSH private key'i yaz          │
│  - sunucuya ssh ile bağlan        │
│  - docker compose pull            ��
│  - docker compose up -d           │
│  - smoke test: curl /todos        │
└───────────────────────────────────┘
```

---

## Adım 1 — Gerekli GitHub Secrets

Repo → **Settings → Secrets and variables → Actions → New repository secret**. Şunları ekle:

| Secret adı | Değeri | Kullanım |
|------------|--------|----------|
| `DOCKERHUB_USERNAME` | Docker Hub kullanıcı adın | İmaj etiketleme + login |
| `DOCKERHUB_TOKEN` | Docker Hub Access Token (şifre değil!) | `docker login` |
| `EC2_SSH_PRIVATE_KEY` | `~/.ssh/todo-app-aws` içeriği (private key, **tam dosya**) | Sunucuya SSH |
| `EC2_HOST` | EC2 public IP'si | SSH hedefi |
| `EC2_USER` | `ubuntu` | SSH kullanıcısı |

> **Neden şifre yerine token?** Docker Hub şifrenle login olmak yerine, sadece push yetkisi olan bir access token üretmek daha güvenlidir; sızarsı iptali kolaydır. Docker Hub → Account Settings → Security → New Access Token.
>
> ⚠️ `EC2_SSH_PRIVATE_KEY` tüm private key dosyasının içeriğidir (`-----BEGIN OPENSSH PRIVATE KEY-----` ile başlar). Yeni satırlar dahil tam olarak kopyala.

---

## Adım 2 — Workflow dosyası

`.github/workflows/deploy.yml` oluştur:

```yaml
# .github/workflows/deploy.yml
name: Build and Deploy

on:
  push:
    branches: [main]          # main'e push → pipeline tetiklenir
  workflow_dispatch:          # Actions sekmesinden elle de çalıştırılabilir

# Aynı anda birden fazla deploy önle
concurrency:
  group: todo-app-production
  cancel-in-progress: false

jobs:
  # ─────────────────────────────────────────────
  # Job 1: İmajı inşa et ve Docker Hub'a push'la
  # ─────────────────────────────────────────────
  build-and-push:
    runs-on: ubuntu-latest
    steps:
      - name: Kodu checkout et
        uses: actions/checkout@v4

      - name: Docker Hub'a login ol
        uses: docker/login-action@v3
        with:
          username: ${{ secrets.DOCKERHUB_USERNAME }}
          password: ${{ secrets.DOCKERHUB_TOKEN }}

      - name: Metadata çıkar (tag'ler için)
        id: meta
        uses: docker/metadata-action@v5
        with:
          images: ${{ secrets.DOCKERHUB_USERNAME }}/todo-api
          tags: |
            type=raw,value=latest
            type=sha,prefix=,format=short   # git commit kısa sha

      - name: İmajı inşa et ve push'la
        uses: docker/build-push-action@v6
        with:
          context: .
          push: true
          tags: ${{ steps.meta.outputs.tags }}

  # ─────────────────────────────────────────────
  # Job 2: Sunucuda dağıt
  # ─────────────────────────────────────────────
  deploy:
    runs-on: ubuntu-latest
    needs: build-and-push            # önce imaj push'lansın
    steps:
      - name: SSH private key'i yaz
        run: |
          mkdir -p ~/.ssh
          echo "${{ secrets.EC2_SSH_PRIVATE_KEY }}" > ~/.ssh/deploy_key
          chmod 600 ~/.ssh/deploy_key

      - name: Sunucunun host key'ini bilinenler listesine ekle
        run: ssh-keyscan -H ${{ secrets.EC2_HOST }} >> ~/.ssh/known_hosts

      - name: Sunucuda imajı çek ve compose up yap
        uses: appleboy/ssh-action@v1
        with:
          host: ${{ secrets.EC2_HOST }}
          username: ${{ secrets.EC2_USER }}
          key: ${{ secrets.EC2_SSH_PRIVATE_KEY }}
          script: |
            cd /opt/todo-app
            docker compose pull
            docker compose up -d
            docker image prune -f

      - name: Smoke test
        run: |
          sleep 5
          curl --fail --retry 5 --retry-delay 3 http://${{ secrets.EC2_HOST }}:3000/todos
```

**Satır satır önemli noktalar:**
- `on: push: branches: [main]` — yalnızca `main`'e push'ta çalışır. Özellik dallarında çalışmaz, böylece her commit canlıya düşmez.
- `concurrency` — aynı branch'e hızlıca iki push gelirse ikinci deploy'u iptal etmez (`cancel-in-progress: false`) ama sıraya koyar; iki deploy'un aynı anda sunucuyu bozmasını engeller.
- **Job dependency:** `deploy` job'unda `needs: build-and-push` — imaj push'lanmadan dağıtım yapılmaz. İmaj push başarısız olursa deploy hiç tetiklenmez.
- **`docker/metadata-action`** — tag'leri otomatik üretir: hem `latest` hem de git commit'in kısa sha'sı (örn. `abc1234`). Böylece hangi commit'in canlıda olduğunu bilirsin ve geri dönüş yapabilirsin.
- **`appleboy/ssh-action`** — GitHub'a SSH ile komut çalıştıran popüler, test edilmiş bir action. Kendi `ssh` komutun yerine bunu kullanmak daha sağlamdır (timeout, key yönetimi vs. halleder).
- **`docker image prune -f`** — eski imajları temizler; disk dolar.
- **Smoke test:** `curl --fail --retry` — yeni imaj ayağa kalkana dek birkaç kez dener; başarısız olursa workflow'u kırmızı (failed) işaretler, böylece haberdar olursun.

---

## Adım 3 — Test et

```bash
git add .github/workflows/deploy.yml
git commit -m "ci: docker build & deploy pipeline"
git push origin main
```

GitHub'da repo → **Actions** sekmesinden:
1. Workflow'un "Build and Deploy" olarak çalıştığını gör
2. `build-and-push` job'ı yeşil (Docker Hub'ta yeni imaj)
3. `deploy` job'ı yeşil (sunucuda `docker compose pull` + `up`)
4. Smoke test geçti (`curl /todos` 200 döndü)

Sunucuda doğrula:

```bash
ssh -i ~/.ssh/todo-app-aws ubuntu@<ip>
docker compose -f /opt/todo-app/docker-compose.yml ps
docker compose -f /opt/todo-app/docker-compose.yml images   # yeni sha'yı görmelisin
```

---

## Alternatif: Deploy'u Ansible ile yapmak

Yukarıdaki deploy job'u doğrudan SSH + compose kullanır. İstersen bunu **Ansible'ı CI'dan çağırarak** da yapabilirsin (kardeş projenin `deploy.yml` böyle yapıyor). Avantajı: yapılandırma mantığı tek yerde (Ansible) toplanır; dezavantajı: CI'a Ansible kurulumu ekler.

Özet akış (alternatif deploy job):

```yaml
  deploy:
    needs: build-and-push
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Ansible kur
        run: pip install ansible
      - name: CI inventory oluştur
        run: |
          echo "[todo_app]" > ansible/inventory.ci.ini
          echo "${{ secrets.EC2_HOST }} ansible_user=${{ secrets.EC2_USER }} ansible_ssh_private_key_file=~/.ssh/deploy_key" >> ansible/inventory.ci.ini
      - name: SSH key'i yaz
        run: |
          mkdir -p ~/.ssh
          echo "${{ secrets.EC2_SSH_PRIVATE_KEY }}" > ~/.ssh/deploy_key
          chmod 600 ~/.ssh/deploy_key
          ssh-keyscan -H ${{ secrets.EC2_HOST }} >> ~/.ssh/known_hosts
      - name: Playbook'u çalıştır
        run: ansible-playbook ansible/playbook.yml -i ansible/inventory.ci.ini -e mongo_uri="mongodb://mongo:27017/todos"
      - name: Smoke test
        run: curl --fail --retry 5 http://${{ secrets.EC2_HOST }}:3000/todos
```

İki yaklaşım da geçerli. Proje küçük olduğundan doğrudan SSH+compose daha az hareket parçasıdır; Ansible yaklaşımı ise yapılandırma mantığını tekilleştirir. Birini seç ve tutarlı kullan.

---

## Doğrulama

Aşama 5 başarılıysa:
- ✅ `main`'e push yapınca Actions otomatik tetiklenir
- ✅ `build-and-push` job'ı Docker Hub'a `latest` + `<sha>` tag'leriyle imaj push'lar
- ✅ `deploy` job'ı yalnızca build başarılı olursa çalışır
- ✅ Sunucuda `docker compose images` yeni sha'yı gösterir
- ✅ Smoke test (`curl /todos`) geçer
- ✅ Bir pipeline adımı başarısız olursa Actions kırmızı işaretler ve seni uyarır
- ✅ Elle `workflow_dispatch` ile de tetiklenebilir

---

## Sık Karşılaşılan Hatalar

| Belirti | Olası neden | Çözüm |
|---------|-------------|-------|
| `build-and-push`: `denied: requested access to the resource is denied` | yanlış Docker Hub adı/token | `DOCKERHUB_USERNAME` ve `DOCKERHUB_TOKEN` doğru mu; image adı `<kullanici>/todo-api` mi |
| Tag'lerde `<kullanici>/todo-api` değil de `todo-api` | username secrets'te yok | `images: ${{ secrets.DOCKERHUB_USERNAME }}/todo-api` |
| `deploy`: `Permission denied (publickey)` | yanlış private key / key formatı | `EC2_SSH_PRIVATE_KEY` tam dosya içeriği mi; sonu newline var mı |
| `deploy`: `Host key verification failed` | known_hosts eksik | `ssh-keyscan` adımının çalıştığından emin ol; veya `StrictHostKeyChecking` geçici kapat |
| Sunucu güncellenmiyor (eski imaj) | `:latest` cache veya compose pull atlandı | `docker compose pull` her zaman en günceli çeker; `up -d` yeni imaj varsa yeniden oluşturur. `docker image prune` eskiyi temizler |
| Smoke test fail (502/timeout) | konteyner henüz hazır değil | `sleep` ve `--retry` artır; `depends_on` healthcheck olduğundan emin ol |
| Pipeline her push'ta tetiklenmiyor | branch adı farklı | `branches: [main]` — senin branch'in `main` mi? (varsayılan branch'i kontrol et) |
| Eşzamanlı iki deploy sunucuyu bozuyor | concurrency yok | `concurrency` bloğunu ekle |

Son adım (bonus) olarak önüne bir Nginx reverse proxy koyalım: [07-nginx-reverse-proxy.md](07-nginx-reverse-proxy.md).
