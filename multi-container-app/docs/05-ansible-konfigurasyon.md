# Aşama 4 — Ansible ile Sunucu Yapılandırması (Gereksinim #2, 2. parça)

> **Karşıladığı gereksinim:** #2 — Terraform'un oluşturduğu sunucuyu Ansible ile **Docker kuracak, Docker Hub'dan image çekecek ve konteynerleri çalıştıracak** şekilde yapılandırmak.
>
> **Önceki aşama:** [04-terraform-aws-sunucu.md](04-terraform-aws-sunucu.md) · **Sonraki aşama:** [06-cicd-github-actions.md](06-cicd-github-actions.md)

## Amaç

Aşama 3'te boş bir Ubuntu sunucusu oluşturmuştuk. Şimdi tek bir `ansible-playbook` komutuyla o sunucuyu şunları yapar hale getireceğiz: Docker ve docker-compose kurar, `docker-compose.yml`'i ve `.env`'i sunucuya koyar, en güncel imajı Docker Hub'dan çeker ve konteynerleri başlatır.

---

## 🆚 Kardeş Projeyle Kritik Fark

Repodaki `nodejs-service-deployment/ansible` rolü **bare-metal** yaklaşım kullanıyordu: sunucuya doğrudan `nodejs`, `npm`, `nginx` kuruyor, kodu `git clone` ile çekiyor, `npm ci` çalıştırıyor ve bir **systemd servisi** olarak yönetiyordu.

Bu projede yaklaşım **tamamen farklı**: sunucuya **Docker** kuruyoruz ve uygulama bir **konteyner** olarak çalışıyor. Sunucu, yalnızca Docker'ın koşturduğu bir ev sahibi (host). Bu fark, IaC/config-management dünyasında iki temel felsefeyi temsil eder:

| | Bare-metal (nodejs-service-deployment) | Konteyner (bu proje) |
|---|---|---|
| Sunucuya kurulan | nodejs, npm, nginx | docker, docker-compose |
| Uygulama nasıl gelir | `git clone` + `npm ci` + build | `docker pull` hazır imaj |
| Çalışma birimi | systemd servisi (`node server.js`) | Docker konteyneri |
| Bağımlılık yönetimi | sunucu seviyesinde | imajın içinde mühürlü |
| Güncelleme | yeni kod push → npm ci → restart | yeni imaj → `docker compose pull` + up |

Konteyner yaklaşımının büyük avantajı: "benim makinemde çalışıyordu" problemi ortadan kalkar, çünkü uygulama tüm bağımlılıklarıyla birlikte imajın içinde gelir.

---

## Önemli Kavramlar

**Ansible** — Ajan gerektirmeyen (sunucuya hiçbir şey kurmaz), SSH üzerinden çalışan config-management ve otomasyon aracı. YAML "playbook"larla **ne** yapılacağını bildirirsin; idempotent'tir (aynı playbook'u 10 kez çalıştırırsan sonuç aynıdır; sadece değişen adımlar uygulanır).

**Inventory** — Ansible'ın hangi sunuculara (host) bağlanacağını bildiği dosya (`inventory.ini`). Burada tek bir EC2 var.

**Role** — Task'ların, değişkenlerin, template'lerin ve handler'ların düzenli klasör yapısında paketlenmiş hali. Küçük projelerde tek playbook da yeter; role kullanmak daha temizdir ve yeniden kullanılabilir.

**Idempotency** — Aynı işlemi tekrar uygulamak "değişiklik yok" demek. Örn. "Docker kurulu mu? Değilse kur." task'ı, Docker zaten varsa hiçbir şey yapmaz. Bu, playbook'u güvenle tekrar tekrar çalıştırılabilir yapar.

**`.env` yönetimi** — `MONGO_URI` gibi değerin sunucuda olması gerek ama git'e commitlenmemeli. Ansible bu dosyayı sunucuya güvenli şekilde koyar (yerel şifreli vault veya CI secret'ından).

---

## Klasör Yapısı

```
ansible/
├── ansible.cfg
├── inventory.ini
├── playbook.yml                  # hangi rolü, hangi host'a uygulayacağı
├── files/
│   └── docker-compose.yml        # sunucuya kopyalanacak compose dosyası
└── roles/
    └── docker_app/
        ├── defaults/
        │   └── main.yml          # rol değişkenleri
        └── tasks/
            └── main.yml          # asıl adımlar
```

---

## Adım 1 — `inventory.ini`

Terraform'tan aldığın public IP'yi buraya koy:

```ini
# ansible/inventory.ini
[todo_app]
3.73.48.129   ansible_user=ubuntu   ansible_ssh_private_key_file=~/.ssh/todo-app-aws
```

- `[todo_app]` bir host grubu; playbook bu gruba uygulanır.
- `ansible_user=ubuntu` — Ubuntu AMI'lerin varsayılan kullanıcısı.
- `ansible_ssh_private_key_file` — Aşama 3'te ürettiğin private key.

> IP'yi elle yazmak yerine Terraform output'undan dinamik inventory de üretebilirsin; küçük proje için statik dosya yeterli.

---

## Adım 2 — `ansible.cfg`

```ini
# ansible/ansible.cfg
[defaults]
inventory = inventory.ini
host_key_checking = False        # İLK bağlantıda bilinmeyen host key'ini otomatik kabul et
roles_path = roles
retry_files_enabled = False
```

> `host_key_checking = False` geliştirme kolaylığıdır. Üretimde "True" yapıp `ssh-keyscan` ile key'i önceden bilinen bir listede tutmak daha güvenlidir (CI/CD aşamasında bunu yapacağız).

---

## Adım 3 — `playbook.yml`

```yaml
# ansible/playbook.yml
- name: Todo uygulamasını sunucuda kur
  hosts: todo_app
  become: true                   # sudo ile çalış (Docker kurulumu root ister)
  roles:
    - role: docker_app
```

---

## Adım 4 — Rol değişkenleri (`roles/docker_app/defaults/main.yml`)

```yaml
# ansible/roles/docker_app/defaults/main.yml
app_name: todo-app
app_user: ubuntu
app_directory: /opt/todo-app
docker_image: "<dockerhub-kullanici-adi>/todo-api:latest"   # kendi image adın
```

> Bu değerleri override edebilirsin; playbook aynı kalır, sadece değişken değişir.

---

## Adım 5 — Rol task'ları (`roles/docker_app/tasks/main.yml`)

İşte asıl iş. Docker kur → kullanıcıyı docker grubuna ekle → compose ve env'i koy → imaj çek ve çalıştır.

```yaml
# ansible/roles/docker_app/tasks/main.yml

# 1) Docker engine'i resmi script ile kur (idempotent: zaten varsa atlar)
- name: Docker kurulum script'ini indir ve çalıştır
  ansible.builtin.shell: |
    curl -fsSL https://get.docker.com | sh
  args:
    creates: /usr/bin/docker           # docker binary varsa bu task atlanır

# 2) docker-compose plugin'i kontrol et (get.docker.com artık içerir, yedek olarak)
- name: docker compose plugin mevcut mu kontrol et
  ansible.builtin.command: docker compose version
  register: compose_check
  changed_when: false
  failed_when: false

# 3) ubuntu kullanıcısını docker grubuna ekle (sudo olmadan docker komutu çalıştırabilsin)
- name: Kullanıcıyı docker grubuna ekle
  ansible.builtin.user:
    name: "{{ app_user }}"
    groups: docker
    append: true

# 4) Uygulama dizinini oluştur
- name: Uygulama dizinini oluştur
  ansible.builtin.file:
    path: "{{ app_directory }}"
    state: directory
    owner: "{{ app_user }}"
    mode: "0755"

# 5) docker-compose.yml'i sunucuya kopyala
- name: docker-compose.yml'i kopyala
  ansible.builtin.copy:
    src: files/docker-compose.yml
    dest: "{{ app_directory }}/docker-compose.yml"
    mode: "0644"

# 6) .env dosyasını sunucuda oluştur (MONGO_URI burada)
#    template kullanarak güvenli şekilde değer enjekte ediyoruz
- name: .env dosyasını oluştur
  ansible.builtin.copy:
    dest: "{{ app_directory }}/.env"
    mode: "0600"
    content: |
      PORT=3000
      MONGO_URI={{ mongo_uri }}

# 7) En güncel imajı çek
- name: Docker imajını çek
  ansible.builtin.command: docker compose pull
  args:
    chdir: "{{ app_directory }}"

# 8) Konteynerleri başlat/restart (yen imaj çekildiyse günceller)
- name: Konteynerleri çalıştır
  ansible.builtin.command: docker compose up -d
  args:
    chdir: "{{ app_directory }}"
```

**Önemli detaylar:**
- `become: true` (playbook seviyesinde) task'ları sudo ile çalıştırır — Docker kurulumu root yetkisi ister.
- `creates: /usr/bin/docker` ile ilk task idempotent olur: Docker bir kez kurulduktan sonra bu task bir daha çalışmaz.
- `groups: docker` + `append: true` kullanıcıyı docker grubuna ekler ama diğer gruplarını korur. Bundan sonra `ubuntu` kullanıcısı `sudo docker ...` yerine doğrudan `docker ...` çalıştırabilir (SSH oturumu yenilenince).
- `docker compose pull` her zaman en güncel imajı çeker — CI/CD yeni imaj push'ladığında, playbook'u tekrar çalıştırarak güncellersin.
- `docker compose up -d` imaj değişmişse konteyneri yeniden oluşturur, yoksa dokunmaz. (Strict idempotency için `changed_when` ile ince ayar yapılabilir; bu proje için yeterli.)

---

## Adım 6 — Sunucu için `files/docker-compose.yml`

> Bu, Aşama 2'deki `docker-compose.yml`'in **üretim** sürümüdür. Fark: `build: .` yerine **Docker Hub'dan çekilen hazır imaj** kullanır (sunucuda kaynak kod yok).

```yaml
# ansible/roles/docker_app/files/docker-compose.yml
services:
  api:
    image: <dockerhub-kullanici-adi>/todo-api:latest   # build değil, hazır imaj
    container_name: todo-api
    restart: unless-stopped
    ports:
      - "3000:3000"
    env_file:
      - .env                       # .env dosyasından MONGO_URI ve PORT okunur
    depends_on:
      mongo:
        condition: service_healthy

  mongo:
    image: mongo:7
    container_name: todo-mongo
    restart: unless-stopped
    volumes:
      - todo-data:/data/db
    healthcheck:
      test: ["CMD", "mongosh", "--eval", "db.adminCommand('ping')"]
      interval: 10s
      timeout: 5s
      retries: 5

volumes:
  todo-data:
```

> **İki compose neden ayrı?** Lokalde geliştirirken `build: .` ile imajı kendi makinende inşa edersin. Sunucuda ise kaynak kod olmadığı için Docker Hub'dan **çekilmiş** imaj kullanırsın. Bu ayrımı net tutmak için `files/docker-compose.yml` üretim için özelleştirilmiştir. İstersen tek dosyada `profiles` ile de yönetebilirsin ama iki ayrı dosya daha anlaşılırdır.

---

## Adım 7 — Çalıştır

`mongo_uri` değişkenini komut satırından ver (böylece git'e girmez):

```bash
cd ansible

# İlk bağlantıda SSH key sorulursa "yes" de
ansible-playbook playbook.yml -e mongo_uri="mongodb://mongo:27017/todos"
```

> Üretimde Mongo parolası olsaydı, `mongo_uri` hassas olurdu; o zaman [Ansible Vault](https://docs.ansible.com/ansible/latest/vault_guide/index.html) ile şifrelemek veya CI secret'ından enjekte etmek gerekirdi. Bu projede Mongo konteyneri dahili ağda, parolasız; yine de `.env` dosyasını `mode: 0600` ile sınırladık.

---

## Adım 8 — Doğrula

Sunucuda:

```bash
ssh -i ~/.ssh/todo-app-aws ubuntu@<ip>
cd /opt/todo-app
docker compose ps              # iki konteyner de healthy/running olmalı
docker compose logs api        # "MongoDB'ye bağlanıldı" log'u
exit
```

Kendi makinenden (HTTP 80 yerine şu an 3000 açık — Nginx bonus'una kadar):

```bash
curl http://<ip>:3000/todos
```

---

## Doğrulama

Aşama 4 başarılıysa:
- ✅ `ansible-playbook` hatasız tamamlanır; tekrar çalıştırınca "changed" sayısı düşer (idempotency)
- ✅ Sunucuda `docker --version` ve `docker compose version` çalışır
- ✅ `ubuntu` kullanıcısı `docker ps`'i sudo'suz çalıştırabilir
- ✅ `/opt/todo-app` altında `docker-compose.yml` ve `.env` var
- ✅ `docker compose ps` `api` ve `mongo`'yu gösterir
- ✅ `http://<ip>:3000/todos` dışarıdan cevap verir

---

## Sık Karşılaşılan Hatalar

| Belirti | Olas�� neden | Çözüm |
|---------|-------------|-------|
| `UNREACHABLE! SSH` | yanlış IP / key / kullanıcı | inventory'deki IP Terraform output'la aynı mı? key doğru mu? kullanıcı `ubuntu` mi? |
| `sudo: a password is required` | `become: true` ama şifre istiyor | Ubuntu AMI varsayılan parolasız sudo verir; aksi halde `become_method`/`--ask-become-pass` kullan |
| `docker: command not found` (playbook sonrası) | kurulum task'ı atlandı veya başarısız | task log'unu incele; sunucuda `curl get.docker.com` erişimi var mı (egress)? |
| `permission denied while trying to connect to the Docker daemon` | kullanıcı docker grubunda değil / oturum yenilenmemiş | `newgrp docker` veya SSH'ten çıkıp tekrar gir |
| `docker compose pull` → `not found` | imaj ad alanı yanlış / private imaj | `docker_image` değişkeni `<kullanici>/todo-api:latest` ve Docker Hub'da public/login ol |
| Playbook her seferinde "changed" | idempotency kırıldı | `creates:`/`changed_when:`/`copy` ile uygun kılıçlar kullan |
| `http://<ip>:3000` dışarıdan erişilemiyor | SG'de 3000 açık değil | Üretimde sadece 80 açık (Nginx bonus). Test için geçici olarak SG'ye 3000 ekle veya bonus adımı yap |

Uygulama sunucuda çalışıyorsa, sıra bunu her `git push`'ta otomatik yapan CI/CD hattında: [06-cicd-github-actions.md](06-cicd-github-actions.md).
