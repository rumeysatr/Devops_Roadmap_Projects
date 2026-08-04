# Basic Dockerfile

roadmap.sh [Basic Dockerfile](https://roadmap.sh/projects/basic-dockerfile) projesi. Bu proje, `alpine:latest` taban imajını kullanarak konsola karşılama mesajı yazdıran basit bir Docker imajı oluşturur.

Çalıştırıldığında varsayılan olarak `Hello, Captain!` yazdırır. Projenin gelişmiş sürümü uygulandığı için, bir isim arg��manı verildiğinde `Hello, <isim>!` çıktısı üretir.

## Gereksinimler

- Dosyanın adı `Dockerfile` olmalı ve proje kök dizininde bulunmalıdır.
- Temel imaj `alpine:latest` olmalıdır.
- Konteyner, çıkıştan önce konsola karşılama mesajını yazdırmalıdır.

## Dockerfile

```dockerfile
FROM alpine:latest

ENTRYPOINT ["sh", "-c", "echo \"Hello, ${1:-Captain}!\"", "--"]
```

Komutun parçaları:

- `FROM alpine:latest` — İmajın temel alacağı küçük ve hafif Linux dağıtımı.
- `ENTRYPOINT` — Konteyner her çalıştığında yürütülecek ana komut.
- `sh -c` — Bir shell ifadesi çalıştırmayı sağlar.
- `${1:-Captain}` — İlk argüman verildiyse onu, verilmediyse `Captain` değerini kullanır.
- Sondaki `--` — Shell içinde argümanların doğru konumlandırılmasını sağlar (`$0` konumunu tutar, böylece ilk argüman `$1` olur).

## Kullanım

### İmajı derle

```bash
docker build -t hello-captain .
```

### Çalıştır

Varsayılan davranış (argüman verilmezse):

```bash
docker run --rm hello-captain
# Çıktı: Hello, Captain!
```

İsim argümanı verilirse:

```bash
docker run --rm hello-captain Rümeysa
# Çıktı: Hello, Rümeysa!
```

## Proje Yapısı

```
.
├── Dockerfile                # İmaj tanımı
├── README.md                 # Bu dosya
└── docs/
    ├── 2026-08-04_PROJECT-DETAILS.md   # Dockerfile komutlarının açıklaması
    ├── en_subject.md                   # Proje konusu (İngilizce)
    └── tr_subject.md                   # Proje konusu (Türkçe)
```

## Ek Kaynaklar

- [Dockerfile referansı](https://docs.docker.com/engine/reference/builder/)
- [roadmap.sh projesi](https://roadmap.sh/projects/basic-dockerfile)
