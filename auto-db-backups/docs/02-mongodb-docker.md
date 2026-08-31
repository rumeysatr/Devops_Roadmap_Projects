# 02 — Docker ile MongoDB + Örnek Veri

> Amaç: Sunucuda Docker üzerinden MongoDB ayağa kaldırmak ve yedekleyeceğimiz `school` veritabanını örnek veriyle doldurmak. Ayrıca yedekleme araçlarını (mongodump/mongorestore) kuracağız.

**Ön koşul:** [01-aws-ec2](01-aws-ec2.md) checkpoint'i geçildi (`ssh backup-server` çalışıyor).

---

Bu dokümanda ilk kez proje döngüsünü kullanıyoruz: **localde yaz → push → sunucuda pull → çalıştır.**

## 1. Proje Dosyaları — LOCAL (editör)

Repoya üç dosya ekle:

**`.gitignore`** (repo köküne):

```gitignore
.env
backups/
```

> `.env` gizli anahtarları, `backups/` ise yedek arşivlerini içerecek — ikisi de git'e **girmemeli**. (Dosyaları şimdilik sunucuda oluşturacağız; kuralı şimdi kuralım.)

**`docker-compose.yml`** (repo köküne):

```yaml
services:
  mongo:
    image: mongo:8
    container_name: mongo
    restart: unless-stopped
    ports:
      - "127.0.0.1:27017:27017"   # SADECE sunucunun kendisine açık
    volumes:
      - mongo_data:/data/db

volumes:
  mongo_data:
```

> **Neden `127.0.0.1:27017:27017` ve neden `-p 27017:27017` değil?**
> İlk hali portu yalnızca sunucunun **localhost**'una bağlar: sunucuya ssh ile giren sen ve sunucuda çalışan script'ler erişebilir, dış dünya erişemez. İkinci hali tüm arayüzlere bağlar ve MongoDB'yi internete açardı. Security Group'ta 27017 açmadığımız için çift koruma var: port kuralı olmasa bile SG trafiği düşürür. İyi pratik: her katmanda kısıtla.

**`seed.js`** (repo köküne):

```javascript
db = db.getSiblingDB("school");

db.students.deleteMany({});

db.students.insertMany([
  { name: "Ayşe Yılmaz",    department: "CSE",  gpa: 3.4 },
  { name: "Mehmet Demir",   department: "EEE",  gpa: 2.9 },
  { name: "Zeynep Kaya",    department: "CSE",  gpa: 3.8 },
  { name: "Can Öztürk",     department: "ME",   gpa: 2.6 },
  { name: "Elif Şahin",     department: "CSE",  gpa: 3.1 },
  { name: "Burak Aydın",    department: "IE",   gpa: 3.0 },
  { name: "Deniz Koç",      department: "EEE",  gpa: 2.8 },
  { name: "Merve Arslan",   department: "CSE",  gpa: 3.6 },
  { name: "Emre Çelik",     department: "ME",   gpa: 2.7 },
  { name: "Selin Yıldız",   department: "IE",   gpa: 3.3 },
]);

print("Seed tamam. Öğrenci sayısı: " + db.students.countDocuments({}));
```

> `getSiblingDB`, script içinde veritabanı seçmenin yoludur (interaktif `use school` yerine).

Commit ve push et (GitHub'da repo'n yoksa önce boş repo aç, `git remote add origin ...` yap):

```bash
git add .
git commit -m "add docker-compose, seed script and gitignore"
git push
```

## 2. Repoyu Sunucuya Alma — SERVER

```bash
ssh backup-server
git clone https://github.com/<kullanici-adi>/auto-db-backups.git ~/auto-db-backups
```

> Repo **private** ise: en kolay yol GitHub'da Personal Access Token'la https clone (şifre yerine token yapıştır) ya da sunucuda bir ssh key'i GitHub'a ekleyip `git@github.com:...` ile clone. Public ise hiç sorun yok.

## 3. Docker Kurulumu — SERVER

```bash
curl -fsSL https://get.docker.com | sudo sh
sudo usermod -aG docker ubuntu
exit   # docker grubunun etkili olması için çıkış
```

Tekrar gir ve test et:

```bash
ssh backup-server
docker --version && docker compose version
docker run --rm hello-world   # "Hello from Docker!" görmelisin
```

> `usermod -aG docker` olmazsa her docker komutuna `sudo` yazmak zorunda kalırsın — gruba ekledik, o yüzden bir kere çıkıp girmek gerekiyor.

## 4. MongoDB'yi Başlatma — SERVER

```bash
cd ~/auto-db-backups
docker compose up -d
docker compose ps        # STATUS: Up olmalı
docker logs mongo --tail 5
```

Bağlantı testi — `mongosh` henüz kurulu değil, onu hemen aşağıda kuracağız.

## 5. Yedekleme Araçları — SERVER

`mongodump`/`mongorestore` sunucu paketinde yok; MongoDB'nin resmi apt deposundan kurulur:

```bash
sudo apt-get install -y gnupg curl
curl -fsSL https://www.mongodb.org/static/pgp/server-8.0.asc \
  | sudo gpg -o /usr/share/keyrings/mongodb-server-8.0.gpg --dearmor
echo "deb [signed-by=/usr/share/keyrings/mongodb-server-8.0.gpg] https://repo.mongodb.org/apt/ubuntu noble/mongodb-org/8.0 multiverse" \
  | sudo tee /etc/apt/sources.list.d/mongodb-org-8.0.list
sudo apt-get update
sudo apt-get install -y mongodb-mongosh mongodb-database-tools
```

Doğrula:

```bash
mongosh --version
mongodump --version
```

## 6. Seed Çalıştırma — SERVER

```bash
cd ~/auto-db-backups
mongosh "mongodb://127.0.0.1:27017/school" seed.js
```

## ✅ Checkpoint

```bash
mongosh "mongodb://127.0.0.1:27017/school" --eval 'db.students.countDocuments()'
# 10 görmelisin
```

MongoDB artık: Docker içinde çalışıyor, verisi `mongo_data` volume'unda kalıcı, sadece localhost'tan erişilebilir, içinde 10 öğrenci var.

## Sık Hatalar

| Belirti | Neden | Çözüm |
|---|---|---|
| `permission denied while trying to connect to the Docker daemon` | docker grubuna eklenip çıkış yapılmamış | `exit` → tekrar `ssh backup-server` |
| `port is already allocated` | 27017'yi başka süreç kullanıyor | `sudo ss -ltnp | grep 27017` ile bak; genelde eski bir container → `docker compose down` sonra tekrar `up -d` |
| `connection refused` mongosh'ta | Mongo container çalışmıyor | `docker compose ps`, gerekirse `docker compose up -d` |
| apt'te `mongodb-database-tools bulunamadı` | Mongo deposu eklenmemiş/güncellenmemiş | 5. adımdaki `apt-get update` çalıştı mı kontrol et |
| Sunucu reboot sonrası mongo yok | unutulmuşsa | compose dosyasında `restart: unless-stopped` var, `docker` servisi açılır açılmaz container geri gelir — `docker compose ps` ile doğrula |

Sonraki adım: [03-cloudflare-r2.md](03-cloudflare-r2.md)
