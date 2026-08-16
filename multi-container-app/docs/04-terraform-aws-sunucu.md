# Aşama 3 — Terraform ile AWS EC2 Sunucusu (Gereksinim #2, 1. parça)

> **Karşıladığı gereksinim:** #2 — Uzak bir sunucuyu Terraform ile oluşturmak. Bu aşama yalnızca sunucuyu (**boş bir EC2**) ayağa kaldırır; içine Docker kurma işi bir sonraki aşamada Ansible ile yapılır.
>
> **Önceki aşama:** [03-dockerizasyon-compose.md](03-dockerizasyon-compose.md) · **Sonraki aşama:** [05-ansible-konfigurasyon.md](05-ansible-konfigurasyon.md)

## Amaç

Kodla (Infrastructure as Code) yönetilebilen, yeniden üretilebilir bir Ubuntu EC2 örneği oluşturmak: SSH ile girebileceğimiz, HTTP (80) portunun açık olduğu, public IP'si olan bir sunucu.

> 💡 **Kardeş projene bak:** Repodaki `nodejs-service-deployment/terraform/` klasörü neredeyse birebir aynı ihtiyacı karşılar. Bu aşamayı o dosyaları temel alarak yazabilirsin. Buradaki açıklamalar, o dosyaları anlaman ve yeni projeye uyarlaman (örn. isim/etiket farklılıkları) içindir.

---

## Önemli Kavramlar

**Infrastructure as Code (IaC)** — Sunucuları, ağları, güvenlik duvarlarını elle (konsoldan tıklayarak) değil, **bildirimsel kodla** tanımlamak. Avantajları: tekrar üretilebilir (aynı kod = aynı sunucu), sürüm kontrolüne girebilir, bir komutla yıkılıp yeniden kurulabilir.

**Terraform** — HashiCorp'un IaC aracı. `.tf` dosyalarında **ne** istediğini yazarsın (örn. "bir t3.micro EC2"), Terraform **nasıl** yapacağını bulur ve AWS API'sini çağırır. Önce `plan` ile ne yapacağını gösterir, onaylayınca `apply` ile uygular.

**AWS bileşenleri bu projede:**
- **EC2 instance** — sanal sunucunun kendisi
- **AMI (Amazon Machine Image)** — işletim sistemi kalıbı (biz Ubuntu 24.04 kullanacağız)
- **Security Group** — sunucunun ağ güvenlik duvarı (hangi portlara kim erişebilir)
- **Key Pair** — SSH ile güvenli giriş için anahtar çifti (public key AWS'te, private key sende)

**State (`terraform.tfstate`)** — Terraform'ın oluşturduğu kaynakların "kayıt defteri". Ne var, kim sahibi, ne durumda — hepsi bu dosyada. Bu yüzden `apply`'dan önce/sonra değişiklik tespit edebilir. **Asla commit etme** (içinde bazen hassas veri olur) ve **asla elden silme** (Terraform neyi yönettiğini kaybeder).

---

## Adım 1 — Klasör ve `providers.tf`

`terraform/` klasörü oluştur ve sağlayıcıyı tanımla:

```hcl
# terraform/providers.tf
terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}
```

**Ne oluyor?** `required_providers` AWS sağlayıcısının sürümünü kilitler. `provider "aws"` bloğu hangi bölgeyi kullanacağını söyler. `var.aws_region` bir değişken (Adım 4'te tanımlıyoruz).

---

## Adım 2 — `variables.tf`

Dışarıdan verilebilir (override edilebilir) değerleri değişken olarak tanımla — böylece aynı kodu farklı bölgelerde/anahtarlarla kullanabilirsin:

```hcl
# terraform/variables.tf
variable "aws_region" {
  description = "AWS bölgesi"
  type        = string
  default     = "eu-central-1"
}

variable "instance_type" {
  description = "EC2 örnek tipi"
  type        = string
  default     = "t3.micro"
}

variable "public_key_path" {
  description = "AWS'e yüklenecek SSH public key'in yolu"
  type        = string
}

variable "ssh_allowed_cidr" {
  description = "SSH erişimine izin verilen IP aralığı (CIDR). Güvenlik için kendi IP'ni kullan."
  type        = string
}
```

> ⚠️ `ssh_allowed_cidr`'i `0.0.0.0/0` yapma — bu SSH'yu tüm dünyaya açar. `curl ifconfig.me` ile kendi public IP'ni bul ve `<ip>/32` olarak ver (örn. `84.12.34.56/32`). HTTP (80) aç��k kalacak çünkü API'ye herkes erişmeli; ama SSH sadece senden.

---

## Adım 3 — `main.tf` (kaynaklar)

Asıl işin yapıldığı dosya: AMI, key pair, security group ve instance.

```hcl
# terraform/main.tf

# En son resmi Ubuntu 24.04 (Noble) AMI'sını dinamik olarak bul
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical'ın AWS hesap ID'si (resmi Ubuntu)

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# SSH key pair (public key'ini AWS'e yükle)
resource "aws_key_pair" "deployer" {
  key_name   = "todo-app-key"
  public_key = file(var.public_key_path)
}

# Güvenlik grubu: SSH (22) sadece senden, HTTP (80) herkese açık
resource "aws_security_group" "todo_app" {
  name        = "todo-app-sg"
  description = "Todo app: SSH sınırlı, HTTP açık"

  # SSH
  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.ssh_allowed_cidr]
  }

  # HTTP (API / Nginx)
  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Giden trafiğe izin ver (image pull, güncellemeler vb.)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# EC2 instance
resource "aws_instance" "todo_app" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  key_name               = aws_key_pair.deployer.key_name
  vpc_security_group_ids = [aws_security_group.todo_app.id]

  tags = {
    Name = "todo-app"
  }
}
```

**Önemli detaylar:**
- `data "aws_ami"` sabit bir AMI ID kullanmak yerine **en son resmi Ubuntu 24.04**'ü bulur. AMI ID'leri bölgeden bölgeye değiştiği için sabit kodlamak kırılgandır; `data` bloğu bunu çözer.
- `owners = ["099720109477"]` Canonical'ın resmi hesabı; böylece resmi olmayan kurcalanmış imaj çekme riskini ortadan kaldırır.
- `aws_key_pair.public_key = file(var.public_key_path)` yerel `.pub` dosyanı okuyup AWS'e yükler. **Private key asla Terraform'a girmez** — o sende kalır.
- Security group'ta **sadece 22 ve 80** açık. Mongo'nun `27017`'sini **dışa açma** — veritabanı yalnızca konteynerler arası dahili ağda konuşmalı. (Nginx bonus'unu yaparsan dışarıya yalnızca 80 açık kalır, çok daha temiz.)
- `egress` tüm giden trafiğe açık — böylece sunucu Docker Hub'dan image çekebilir ve paket güncelleyebilir.

---

## Adım 4 — `outputs.tf`

`apply` sonrası bize lazım olacak değeri (public IP) yazdır:

```hcl
# terraform/outputs.tf
output "server_public_ip" {
  description = "EC2 örneğinin public IP'si"
  value       = aws_instance.todo_app.public_ip
}
```

Bu IP'yi bir sonraki aşamada Ansible inventory'sine koyacağız.

---

## Adım 5 — `terraform.tfvars` (kendi değerlerin)

Gerçek değerleri içeren dosya — **`.gitignore`'a ekle**:

```hcl
# terraform/terraform.tfvars
aws_region       = "eu-central-1"
instance_type    = "t3.micro"
public_key_path  = "~/.ssh/todo-app-aws.pub"
ssh_allowed_cidr = "84.12.34.56/32"   # KENDİ IP'Nİ yaz
```

Bir `.tfvars.example` dosyasını (örnek değerlerle) commit edebilirsin, böylece başkaları reponu klonladığında hangi değişkenler gerektiğini görür.

> 💡 SSH anahtarın yoksa üret:
> ```bash
> ssh-keygen -t ed25519 -f ~/.ssh/todo-app-aws -C "todo-app"
> ```
> Bu `todo-app-aws` (private) ve `todo-app-aws.pub` (public) üretir. Public'i Terraform'a ver, private ile sunucuya gireceksin.

---

## Adım 6 — Uygula

```bash
cd terraform

# 1. Sağlayıcıyı indir
terraform init

# 2. Ne yapacağını önceden gör (hiçbir şey oluşturmaz)
terraform plan

# 3. Onayla ve uygula
terraform apply

# 4. Public IP'yi al
terraform output server_public_ip
```

Artık sunucun canlı. SSH ile gir:

```bash
ssh -i ~/.ssh/todo-app-aws ubuntu@$(terraform output -raw server_public_ip)
```

İçeride `docker --version` **henüz çalışmayacak** — kurulumu Ansible yapacak. Sunucunun boş bir Ubuntu olduğunu teyit et, sonra çık.

---

## Maliyet ve Temizlik

- `t3.micro` AWS Free Tier kapsamındadır (belirli saatler için). Yine de **işin bitince mutlaka kapat**: `terraform destroy`.
- Geliştirme sırasında kullanmadığında EC2'yi durdurmak yerine `destroy` etmek daha güvenlidir (state karmaşası olmaz). Unutulan açık sunucular fatura sürprizi yaratır.

---

## Doğrulama

Aşama 3 başarılıysa:
- ✅ `terraform plan` hatasız çalışır ve "1 to add" gösterir
- ✅ `terraform apply` EC2'yu oluşturur
- ✅ `terraform output` geçerli bir public IP döner
- ✅ `ssh -i <key> ubuntu@<ip>` ile giriş yapabilirsin
- ✅ AWS konsolunda instance "running" görünür ve doğru security group'a bağlıdır

---

## Sık Karşılaşılan Hatalar

| Belirti | Olası neden | Çözüm |
|---------|-------------|-------|
| `Error: validating AWS Credentials` | `aws configure` yapılmamış | `aws configure` ile access key/secret/region gir; `aws sts get-caller-identity` ile test et |
| `PermissionError` / `UnauthorizedOperation` | IAM yetkisi yok | AWS kullanıcının EC2 tam erişim yetkisi olmalı |
| `aws_key_pair: invalid public key` | `.pub` dosyası yanlış/bozuk | doğru public key yolunu ver; `cat ~/.ssh/todo-app-aws.pub` düzgün mü kontrol et |
| SSH "Connection refused/timeout" | SG'de 22 açık değil veya yanlış CIDR | `ssh_allowed_cidr`'in kendi IP'ni kapsadığından emin ol (`curl ifconfig.me`) |
| SSH "Permission denied (publickey)" | yanlış private key / yanlış kullanıcı | Ubuntu AMI → kullanıcı `ubuntu`; doğru `-i` key'i ver |
| AMI bulunamadı | bölgede o isim filtresi eşleşmiyor | `data.aws_ami` filtresini kontrol et; bölgeyle AMI adının uyumlu olduğundan emin ol |
| `terraform.tfstate` çakışması | state bozuldu/elden silindi | `terraform refresh` dene; ciddi durumda kaynakları manuel temizleyip yeniden `apply` |
| Farklı bölgede kayıp kaynak | region değişti, kaynak başka bölgede kaldı | `terraform destroy` yapmadan region değiştirme |

Sunucu hazırsa, içine Docker kurup uygulamamızı çalıştırma sırası: [05-ansible-konfigurasyon.md](05-ansible-konfigurasyon.md).
