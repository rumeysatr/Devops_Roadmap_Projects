# Node.js Service Deployment

GitHub Actions, Terraform ve Ansible kullanarak bir Node.js servisini uzak sunucuya **CI/CD pipeline** ile deploy eden DevOps projesi. Bu proje [roadmap.sh](https://roadmap.sh/) "Node.js Service Deployment" çalışmasını temel alır; orijinal gereksinimde DigitalOcean önerilse de bu implementasyon **AWS** üzerine kurulmuştur.

Amaç, altyapı sağlamadan (IaC) yapılandırma yönetimine (Configuration Management) ve otomatik dağıtıma (CI/CD) kadar uçtan uca bir dağıtım sürecini pratik yapmaktır.

---

## Mimari

Node.js uygulaması yalnızca `127.0.0.1:3000` adresini dinler. Dışarıdan gelen istekler Nginx tarafından 80 portundan karşılanıp uygulamaya reverse proxy olarak iletilir. systemd, Node.js sürecini canlı tutar ve çökme durumunda yeniden başlatır.

```
 ┌─────────────────────────────────────────────┐
 │              AWS · eu-central-1             │
 │         EC2 (t3.micro · Ubuntu 24.04)       │
 │                                             │
 │   HTTP :80 ──▶  Nginx (reverse proxy)       │
 │                        │                    │
 │                        ▼                    │
 │                 Node.js (systemd)           │
 │                 Express · 127.0.0.1:3000    │
 └─────────────────────────────────────────────┘
```

Dağıtım akışı:

```
 push (main) ──▶  GitHub Actions
                     ├─ checkout
                     ├─ Ansible kurulumu
                     ├─ SSH key (GitHub Secret) konfigürasyonu
                     ├─ geçici inventory üretimi
                     ├─ ansible-playbook node_service.yml --tags app
                     └─ curl http://$EC2_HOST/   (sağlık kontrolü)
                                          │
                                          ▼
                                EC2 sunucusu güncellenir
```

---

## Teknoloji Yığını

- **Node.js + Express 5** — sunulacak örnek HTTP servisi
- **Terraform** — AWS altyapısının kod olarak tanımlanması (IaC)
- **Ansible** — sunucu yapılandırması ve uygulama dağıtımı
- **systemd + Nginx** — süreç yönetimi ve reverse proxy
- **GitHub Actions** — otomatik dağıtım (CI/CD)

---

## Proje Yapısı

```
nodejs-service-deployment/
├── server.js                      # Express uygulaması ("/" → Hello, world!)
├── package.json
├── docs/
│   └── en_subject.md              # Orijinal proje gereksinimleri
├── terraform/                     # AWS altyapısı (IaC)
│   ├── providers.tf
│   ├── main.tf                    # EC2, Security Group, Key Pair, AMI
│   ├── variables.tf
│   ├── outputs.tf
│   └── terraform.tfvars.example   # kendi değerlerin için şablon
├── ansible/                       # Sunucu yapılandırması
│   ├── ansible.cfg
│   ├── inventory.ini
│   ├── node_service.yml           # playbook
│   └── roles/
│       ├── app/                   # uygulama kurulumu + deploy (aktif rol)
│       │   ├── defaults/main.yml
│       │   ├── tasks/main.yml
│       │   ├── handlers/main.yml
│       │   └── templates/
│       │       ├── node-service.service.j2      # systemd unit
│       │       └── nginx-node-service.conf.j2   # Nginx reverse proxy
│       └── common/                # ayrılmış / şimdilik boş rol
└── .github/workflows/deploy.yml   # CI/CD pipeline
```

---

## Ön Koşullar

- AWS hesabı ve yapılandırılmış AWS CLI kimlik bilgileri
- Yerel makinede bir SSH anahtar çifti (public key yolu `terraform.tfvars`'da referans verilir)
- Terraform `>= 1.5.0`
- Ansible
- (Yerel test için) Node.js

---

## Kullanım

### 1. Altyapıyı Terraform ile ayağa kaldırma

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
# terraform.tfvars içindeki değerleri kendine göre düzenle:
#   public_key_path  → ~/.ssh/id_rsa.pub gibi SSH public key yolu
#   ssh_allowed_cidr → yalnızca kendi IP'n (ör. 203.0.113.10/32)

terraform init
terraform plan
terraform apply
```

`apply` sonrası `outputs.tf` üzerinden `server_public_ip` değerini al:

```bash
terraform output server_public_ip
```

### 2. Ansible ile manuel dağıtım (Task #1)

`ansible/inventory.ini` içindeki IP adresini Terraform çıktısıyla eşleşecek şekilde güncelle, ardından playbook'u çalıştır:

```bash
cd ansible
# inventory.ini →  <server_public_ip> ansible_user=ubuntu ansible_ssh_private_key_file=~/.ssh/node-service-aws
ansible-playbook node_service.yml --tags app
```

Dağıtım tamamlandığında uygulama 80 portundan erişilebilir olur:

```bash
curl http://<server_public_ip>/
# Hello, world!
```

`app` rolü sırasıyla şunları yapar:

1. `git`, `nodejs`, `npm`, `nginx` paketlerini kurar
2. `/opt/node-service` dizinini oluşturur
3. GitHub deposunu klonlar
4. `npm ci --omit=dev` ile bağımlılıkları kurar
5. `npm run build` çalıştırır
6. systemd servis dosyasını oluşturup uygulamayı başlatır
7. Nginx'i reverse proxy (80 → 3000) olarak yapılandırır ve varsayılan siteyi kaldırır

### 3. GitHub Actions ile otomatik dağıtım (Task #2)

`.github/workflows/deploy.yml`, `main` dalına yapılan her `push`'ta (ya da manuel `workflow_dispatch` ile) otomatik olarak çalışır. Pipeline Ansible'ı kurar, SSH anahtarını GitHub Secret'tan alır, geçici bir inventory üretir ve playbook'u çalıştırır.

Gerekli **GitHub Secrets**:

| Secret | Açıklama |
| --- | --- |
| `EC2_SSH_PRIVATE_KEY` | EC2'ya bağlanmak için kullanılan SSH private key |
| `EC2_HOST` | Sunucunun public IP adresi |
| `EC2_USER` | SSH kullanıcısı (Ubuntu AMI için `ubuntu`) |
| `EC2_SSH_PORT` | SSH portu (opsiyonel; belirtilmezse `22` kullanılır) |

---

## Uç Noktalar

| Metot | Yol | Yanıt |
| --- | --- | --- |
| `GET` | `/` | `Hello, world!` |

---

## Yapılandırma

### Terraform değişkenleri (`terraform/variables.tf`)

| Değişken | Açıklama | Varsayılan |
| --- | --- | --- |
| `aws_region` | AWS bölgesi | `eu-central-1` |
| `instance_type` | EC2 örnek tipi | `t3.micro` |
| `public_key_path` | SSH public key yolu | — (zorunlu) |
| `ssh_allowed_cidr` | SSH için izin verilen CIDR | — (zorunlu) |

### Ansible varsayılanları (`ansible/roles/app/defaults/main.yml`)

| Değişken | Varsayılan |
| --- | --- |
| `app_name` | `node-service` |
| `app_user` / `app_group` | `ubuntu` |
| `app_directory` | `/opt/node-service` |
| `app_repository` | uygulamanın GitHub deposu |
| `app_branch` | `main` |
| `app_port` | `3000` |

---

## Güvenlik Notları

- `terraform.tfvars`, `.env`, `*.pem`, `*.tfstate*` ve `.terraform/` `.gitignore` ile repodan çıkarılmıştır; kimlik bilgileri commit edilmez.
- Security Group'ta SSH yalnızca `ssh_allowed_cidr` ile belirtilen IP'ye, HTTP ise herkese (`80`) açıktır. Üretim için SSH CIDR'ını kendi IP'nle kısıtla.
- CI/CD'de kullanılan private key asla repoya yazılmaz; yalnızca GitHub Secret olarak workflow'a enjekte edilir.

---

## Öğrenilen / Pratik Yapılan Konular

- Terraform ile AWS kaynaklarının (EC2, Security Group, Key Pair) kod olarak yönetimi
- Ansible role yapısı, template'ler (Jinja2), handler'lar ve `--tags` ile seçici çalıştırma
- systemd ile süreç yönetimi ve Nginx reverse proxy kurulumu
- GitHub Actions ile SSH tabanlı dağıtım, secret yönetimi ve concurrency kontrolü
- Uçtan uca IaC → Configuration Management → CI/CD akışının birleştirilmesi
