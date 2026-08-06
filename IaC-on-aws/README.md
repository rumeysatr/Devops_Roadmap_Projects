# IaC on AWS

Terraform kullanarak AWS üzerinde temel bir bulut altyapısı (VPC + EC2) kurup, ardından Ansible ile sunucuyu (Nginx) yapılandıran DevOps uygulama projesi.

Bu proje [roadmap.sh](https://roadmap.sh/projects) üzerindeki **IaC** projelerinden biridir. Orijinal görev bir DigitalOcean Droplet oluşturmayı öngörüyordu; mevcut AWS hesabı kullanıldığı için aynı hedef AWS üzerinde gerçekleştirildi (özel VPC, public subnet, güvenlik grubu ve SSH erişimli EC2 sunucusu). Orijinal görev metni [`docs/en_subject.md`](docs/en_subject.md) dosyasında saklanmaktadır.

---

## Neler Yapıldı?

Tek bir `terraform apply` komutuyla AWS üzerinde tamamen yönetilebilir, izole bir ağ üzerinde çalışan bir sanal sunucu ayağa kaldırılır; ardından Ansible bu sunucuya bağlanıp Nginx'i kurar ve servis olarak açılışta başlayacak şekilde etkinleştirir.

Oluşturulan AWS kaynakları (`main.tf`):

- **VPC** — `10.0.0.0/16` adres bloğu, DNS desteği açık.
- **Internet Gateway** — VPC'yi internete bağlar.
- **Public Subnet** — `10.0.1.0/24`, örneklerde public IP dağıtımı açık.
- **Route Table + Association** — `0.0.0.0/0` trafiğini Internet Gateway'e yönlendirir.
- **Security Group** — SSH (22) yalnızca izinli IP'den, HTTP (80) her yerden, tüm çıkış trafiği serbest.
- **Key Pair** — yerel SSH public key'den oluşturulur.
- **EC2 Instance** — Ubuntu 24.04 LTS (Noble), `t3.micro`, şifreli `gp3` root diski (10 GB).

İşletim sistemi, Canonical'in resmi Ubuntu AMI'leri arasından canlı olarak seçilir (`data "aws_ami"`).

Ansible tarafı (`ansible/`):

- `playbook.yml` — apt önbelleğini günceller, Nginx kurar, servisi başlatır ve açılışta etkin kılar.
- `group_vars/all.yml` — bağlantı bilgilerini `.env` üzerinden `lookup('env', ...)` ile okur; hiçbir IP veya anahtar yolu içermez.

---

## Mimari

```
                   Internet
                      │
        ┌─────────────▼─────────────┐
        │   Internet Gateway (IGW)  │
        └─────────────┬─────────────┘
                      │
        ┌─────────────▼─────────────┐
        │            VPC            │
        │        10.0.0.0/16        │
        │                           │
        │   ┌─────────────────────┐ │
        │   │   Public Subnet     │ │
        │   │    10.0.1.0/24      │ │
        │   │                     │ │
        │   │  ┌───────────────┐  │ │
        │   │  │  EC2 (Ubuntu) │  │ │
        │   │  │   t3.micro    │  │ │
        │   │  └───────────────┘  │ │
        │   └─────────────────────┘ │
        └───────────────────────────┘

  Security Group:  SSH(22) → izinli IP  |  HTTP(80) → 0.0.0.0/0
```

---

## Ön Koşullar

- [Terraform](https://developer.hashicorp.com/terraform/downloads) `>= 1.5.0`
- [Ansible](https://docs.ansible.com/ansible/latest/installation_guide/intro_installation.html)
- AWS CLI ile yapılandırılmış kimlik bilgileri (`aws configure`)
- Sunucuya SSH ile bağlanmak için bir anahtar çifti:

```bash
ssh-keygen -t ed25519 -f ~/.ssh/aws-terraform
```

Bu komut `~/.ssh/aws-terraform` (private) ve `~/.ssh/aws-terraform.pub` (public) anahtarlarını üretir.

---

## Yapılandırma: `.env`

Tüm ortam ve sensitif değerler (IP adresleri, anahtar yolları, kişisel bilgiler) proje kökündeki `.env` dosyasında tutulur ve **git'e gönderilmez**. `run.sh` bu dosyayı otomatik olarak yükleyip ilgili araca aktarır:

- **Terraform** değerleri `TF_VAR_` önekiyle yazılır; Terraform bunları ortam değişkeni olarak doğal olarak okur.
- **Ansible** değerleri (`SERVER_IP`, `SSH_USER`, `SSH_KEY_PATH`) `ansible/group_vars/all.yml` içinde `lookup('env', ...)` ile okunur.

Başlangıçta şablonu kopyala:

```bash
cp .env.example .env
```

Ardından `.env` içini kendi değerlerinle doldur:

```bash
# --- Terraform (TF_VAR_ önekiyle otomatik okunur) ---
TF_VAR_aws_region=eu-central-1
TF_VAR_instance_type=t3.micro
TF_VAR_public_key_path=/home/kullanici/.ssh/aws-terraform.pub
TF_VAR_allowed_ssh_cidr=203.0.113.10/32        # kendi IP'n: curl ifconfig.me

# --- Ansible (lookup('env') ile okunur) ---
SERVER_IP=                                      # terraform apply sonrası: terraform output public_ip
SSH_USER=ubuntu
SSH_KEY_PATH=/home/kullanici/.ssh/aws-terraform
```

> SSH erişimini yalnızca kendi IP'nizle sınırlandırmak en sağlam yöntemdir; `allowed_ssh_cidr` değerini `curl ifconfig.me` çıktınızla doldurun. Her argümanın adı `.env.example` içinde belgelenmiştir.

---

## Kullanım

Tüm komutlar `run.sh` üzerinden çalıştırılır; komut `.env`'i yükledikten sonra ilgili aracı çağırır.

### 1. Altyapıyı kur

```bash
./run.sh tf init     # provider'ları indir
./run.sh tf plan     # oluşturulacak kaynakları önizle
./run.sh tf apply    # kaynakları oluştur
```

`apply` sonrası EC2 instance ID'si, public IP ve hazır SSH komutu çıktı olarak alınır. `.env` içindeki `SERVER_IP` değerini `terraform output public_ip` çıktısıyla güncelleyin.

### 2. Sunucuyu Ansible ile yapılandır

```bash
./run.sh ansible
```

Kurulum tamamlandığında tarayıcıdan `http://SERVER_IP` adresini açtığınızda Nginx karşılama sayfasını görmelisiniz.

### 3. Kaynakları temizle

Ücret oluşmaması için işiniz bitince her şeyi kaldırın:

```bash
./run.sh tf destroy
```

> `run.sh` kullanmadan çalıştırmak isterseniz `.env`'i elle kaynaklayın: `set -a; source .env; set +a` — bundan sonra `terraform` ve `ansible-playbook` komutlarını doğrudan verebilirsiniz.

---

## Proje Yapısı

```
IaC-on-aws/
├── main.tf                # AWS kaynaklarının tamamı
├── variables.tf           # Girdi değişkenleri (TF_VAR_* ile beslenir)
├── outputs.tf             # instance_id, public_ip, ssh_command
├── .env                   # Yerel ortam değerleri (git'e gönderilmez)
├── .env.example           # .env şablonu (commit edilir)
├── run.sh                 # .env'i yükleyip tf/ansible komutlarını çalıştırır
├── .gitignore
├── ansible/
│   ├── playbook.yml       # Nginx kurulumu + servis etkinleştirme
│   ├── inventory.ini      # [web] grubu tanımı
│   ├── group_vars/all.yml # Bağlantı bilgileri (.env'ten lookup ile)
│   └── ansible.cfg
└── docs/
    └── en_subject.md      # Orijinal roadmap.sh görev metni
```

---

## Güvenlik Notları

- Tüm IP adresleri, anahtar yolları ve ortam değerleri `.env` dosyasındadır; `.gitignore` ile `.env`, `terraform.tfstate`, `*.tfplan`, `*.pem` gibi dosyalar repository dışında tutulur. State dosyası hassas bilgi içerebilir.
- `.env` dışında `.env*` dosyaları asla commit edilmez; yalnızca argüman isimlerini belgeleyen `.env.example` commit edilir.
- SSH trafiği varsayılan olarak tek bir IP'ye (`allowed_ssh_cidr`) kısıtlanmıştır, tüm internete açık değildir.
- EC2 root diski şifreli (`encrypted = true`) ve `gp3` tipindedir.

---

## Kullanılan Teknolojiler

**Terraform** (AWS Provider `~> 6.0`) · **Ansible** · **AWS EC2 / VPC** · **Ubuntu 24.04 LTS** · **Nginx**
