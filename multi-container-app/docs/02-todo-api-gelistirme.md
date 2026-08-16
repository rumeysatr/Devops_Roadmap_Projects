# Aşama 1 — Todo API'sini Geliştirmek (Node.js + Express + Mongoose)

> **Karşıladığı gereksinim:** Projenin temeli — kimlik doğrulamasız bir Node.js todo API'si. Bu aşamada API'yi lokalde çalışır hale getiririz; Docker'a koyma bir sonraki aşamada.
>
> **Önceki aşama:** [01-yol-haritasi.md](01-yol-haritasi.md) · **Sonraki aşama:** [03-dockerizasyon-compose.md](03-dockerizasyon-compose.md)

## Amaç

Beş REST endpoint'i olan, MongoDB'ye bağlanan ve `nodemon` ile geliştirme sırasında otomatik yeniden başlanan bir API yazmak. Bu aşamanın sonunda `http://localhost:3000` üzerinden todo oluşturup listeleyebileceksin.

---

## Önemli Kavramlar

**Express** — Node.js için minimalist bir web framework. HTTP isteklerini (GET, POST, ...) route'lara yönlendirir. `app.get("/todos", ...)` gibi ifadelerle endpoint tanımlarsın.

**Mongoose** — MongoDB için bir ODM (Object Data Modeling) kütüphanesi. MongoDB'nin ham dökümanlarını JavaScript nesnelerine (şema) çevirir; böylece bir "Todo"nun hangi alanlara sahip olduğunu (`title`, `completed`) kod seviyesinde tanımlarsın.

**nodemon** — Kaynak kod değiştiğini izleyip sunucuyu otomatik yeniden başlatan bir geliştirme aracı. Her kaydetmede `node server.js`'i elle çalıştırmaktan kurtarır. Sadece **geliştirme** ortamında kullanılır; production'da gerekmez.

**Ortam değişkenleri (.env)** — Portu ve veritabanı adresini koda gömmek yerine `.env` dosyasından okuruz. Böylece aynı kod lokalde, sunucuda ve CI'da farklı `MONGO_URI` ile çalışabilir.

---

## Adım 1 — Proje ve bağımlılıklar

`package.json`'u oluşturup gerekli paketleri kur:

```bash
cd multi-container-app
npm init -y
npm install express mongoose dotenv
npm install --save-dev nodemon
```

`package.json` içindeki `scripts` kısmını şöyle düzenle:

```json
{
  "name": "todo-api",
  "version": "1.0.0",
  "private": true,
  "main": "server.js",
  "scripts": {
    "start": "node server.js",
    "dev": "nodemon server.js"
  },
  "dependencies": {
    "dotenv": "^16.4.5",
    "express": "^4.19.2",
    "mongoose": "^8.5.0"
  },
  "devDependencies": {
    "nodemon": "^3.1.0"
  }
}
```

> **Neden iki ayrı script?** `start` (production) sadece `node server.js` çalıştırır — hızlı ve gereksiz bir şey yüklemez. `dev` ise `nodemon` ile dosya değişimini izler. Docker imajı production için olduğu içinde `start` kullanılır; `dev`/nodemon imaja **girmez**.

> **Sürüm notu:** Express 5 hâlen görece yeni olduğu ve bazı middleware davranışları değiştiği için bu rehber **Express 4** kullanır. İstersen 5 de kullanabilirsin; mantık aynıdır.

---

## Adım 2 — Ortam değişkenleri

Proje köküne `.env` dosyası ekle (**.gitignore'a ekle, asla commit etme**):

```bash
# .env
PORT=3000
MONGO_URI=mongodb://localhost:27017/todos
```

Aynı değerin bir örneğini, başkalarının reponu klonladığında rehber olması için `.env.example` olarak (commitlenebilir) koy:

```bash
# .env.example
PORT=3000
MONGO_URI=mongodb://localhost:27017/todos
```

> **Lokaldeki `MONGO_URI` neden `localhost`?** Bu aşamada Mongo'yu kendi makinende çalıştırıyorsun (bkz. Adım 5). Sonraki aşamada, compose içinde API bir konteynerden Mongo'ya **`mongo`** servis adıyla ulaşacak; o zaman URI `mongodb://mongo:27017/todos` olacak. Aynı kodu, sadece ortam değişkenini değiştirerek iki senaryoda da kullanabildiğimiz için `.env` kullanıyoruz.

---

## Adım 3 — Mongoose modeli (`models/Todo.js`)

Bir todo'nun yapısını (şemasını) tanımla:

```js
// models/Todo.js
const mongoose = require("mongoose");

const todoSchema = new mongoose.Schema(
  {
    title: {
      type: String,
      required: true,
      trim: true,
    },
    completed: {
      type: Boolean,
      default: false,
    },
  },
  { timestamps: true } // createdAt ve updatedAt alanlarını otomatik ekler
);

module.exports = mongoose.model("Todo", todoSchema);
```

**Ne oluyor burada?**
- `title` zorunlu bir metin; `trim` baştaki/sondaki boşlukları kırpar.
- `completed` varsayılan `false`.
- `timestamps: true` her kayda otomatik olarak `createdAt`/`updatedAt` ekler — listelemekte ve hata ayıklamada çok işe yarar.
- `mongoose.model("Todo", ...)` bu şemayı veritabanında `todos` koleksiyonuna bağlar (Mongoose model adını otomatik küçük harfe çevirip çoğullaştırır).

---

## Adım 4 — Express uygulaması (`server.js`)

Tüm bağlantı ve route'ları tek dosyada tutuyoruz (proje küçük olduğu için). Daha büyük bir projede route'ları `routes/` altında ayırırsın.

```js
// server.js
require("dotenv").config(); // .env içindekileri process.env'e yükler
const express = require("express");
const mongoose = require("mongoose");
const Todo = require("./models/Todo");

const app = express();
const PORT = process.env.PORT || 3000;
const MONGO_URI = process.env.MONGO_URI;

// İstek gövdesindeki JSON'u parse et
app.use(express.json());

// --- Mongo bağlantısı ---
mongoose
  .connect(MONGO_URI)
  .then(() => console.log("MongoDB'ye bağlanıldı"))
  .catch((err) => {
    console.error("Mongo bağlantı hatası:", err.message);
    process.exit(1); // DB olmadan API çalışmaz; çık
  });

// --- Route'lar ---

// GET /todos — tüm todo'ları listele
app.get("/todos", async (req, res) => {
  const todos = await Todo.find().sort({ createdAt: -1 });
  res.json(todos);
});

// POST /todos — yeni todo oluştur
app.post("/todos", async (req, res) => {
  const { title } = req.body;
  if (!title) {
    return res.status(400).json({ error: "title zorunludur" });
  }
  const todo = await Todo.create({ title });
  res.status(201).json(todo);
});

// GET /todos/:id — tek bir todo getir
app.get("/todos/:id", async (req, res) => {
  const todo = await Todo.findById(req.params.id);
  if (!todo) return res.status(404).json({ error: "todo bulunamadı" });
  res.json(todo);
});

// PUT /todos/:id — todo'yu güncelle
app.put("/todos/:id", async (req, res) => {
  const { title, completed } = req.body;
  const todo = await Todo.findByIdAndUpdate(
    req.params.id,
    { title, completed },
    { new: true, runValidators: true } // güncellenmiş dokümanı döndür + şema kurallarını uygula
  );
  if (!todo) return res.status(404).json({ error: "todo bulunamadı" });
  res.json(todo);
});

// DELETE /todos/:id — todo'yu sil
app.delete("/todos/:id", async (req, res) => {
  const todo = await Todo.findByIdAndDelete(req.params.id);
  if (!todo) return res.status(404).json({ error: "todo bulunamadı" });
  res.json({ message: "silindi", todo });
});

// --- Hata yakalama (en son middleware) ---
app.use((err, req, res, next) => {
  console.error(err);
  res.status(500).json({ error: "sunucu hatası" });
});

app.listen(PORT, () => {
  console.log(`API http://localhost:${PORT} adresinde dinleniyor`);
});
```

**Dikkat edilecek noktalar:**
- `app.use(express.json())` olmadan `req.body` `undefined` olur; POST/PUT çalışmaz.
- Her handler `async` ve Mongoose çağrıları `await`'li. Bir handler'da fırlayan hata, en alttaki hata middleware'ine düşer (Express 4'te async hataların middleware'e düşmesi için 4 parametreli `err, req, res, next` imzası gerekir).
- `findByIdAndUpdate`'te `{ new: true }` güncellenmiş kaydı döndürür (varsayılan eski kaydı döndürür). `runValidators` şema kurallarını (örn. `required`) güncelleme sırasında da uygular.

---

## Adım 5 — Lokalde MongoDB çalıştır

API bir MongoDB ister. En temiz yol, Mongo'yu Docker ile tek komutla ayağa kaldırmak (bu, bir sonraki aşamanın provasıdır):

```bash
docker run -d --name local-mongo -p 27017:27017 mongo:7
```

- `-d`: arka planda (detached) çalışsın
- `--name local-mongo`: konteynere isim ver (durdurmak/silmek kolaylaşır)
- `-p 27017:27017`: makinendeki 27017 portunu konteynere bağla
- `mongo:7`: MongoDB 7 imajı

> İstersen [MongoDB Atlas](https://www.mongodb.com/atlas) (bulutta ücretsiz bir küme) da kullanabilirsin; o zaman `MONGO_URI`'yi Atlas bağlantı string'i ile değiştirirsin.

---

## Adım 6 — Çalıştır ve test et

```bash
npm run dev      # nodemon ile başlat; dosya kaydedince otomatik yeniden başlar
```

Başka bir terminalde `curl` ile uçtan uca test et:

```bash
# Yeni todo oluştur
curl -X POST http://localhost:3000/todos \
  -H "Content-Type: application/json" \
  -d '{"title":"Docker öğren"}'
# => {"_id":"65f...","title":"Docker öğren","completed":false,"createdAt":"...","updatedAt":"..."}

# ID'yi kopyala, hepsini listele
curl http://localhost:3000/todos

# Tek bir todo getir (ID'yi yapıştır)
curl http://localhost:3000/todos/<ID>

# Tamamlandı olarak işaretle
curl -X PUT http://localhost:3000/todos/<ID> \
  -H "Content-Type: application/json" \
  -d '{"completed": true}'

# Sil
curl -X DELETE http://localhost:3000/todos/<ID>
```

---

## Doğrulama

Aşama 1 başarılıysa:
- ✅ `npm run dev` çalışır ve "MongoDB'ye bağlanıldı" log'unu görürsün
- ✅ `POST /todos` bir todo oluşturur ve `201` döner
- ✅ `GET /todos` listeyi döner ve oluşturduğun kayıt oradadır
- ✅ `PUT /todos/:id` ile `completed` güncellenebilir
- ✅ `DELETE /todos/:id` kaydı siler
- ✅ Geçersiz ID ile istek `404` döner
- ✅ `title` olmadan POST `400` döner

---

## Sık Karşılaşılan Hatalar

| Belirti | Olası neden | Çözüm |
|---------|-------------|-------|
| `MongoServerError: connect ECONNREFUSED` | Mongo çalışmıyor | `docker run ... mongo:7` çalıştı mı? `docker ps` ile kontrol et |
| `req.body` undefined | `express.json()` eksik | `app.use(express.json())` route'lardan **önce** tanımlı olmalı |
| `ValidationError: Path title is required` | POST'ta `title` yok veya boş | JSON gövdede `{"title": "..."}` olduğundan emin ol; `Content-Type: application/json` header'ını ekle |
| `Cast to ObjectId failed` | geçersiz ID formatı | `/:id` route'larına gerçek bir Mongo ID ver |
| Kod değişince sunucu güncellenmiyor | `nodemon` yok / `dev` script'i yanlış | `npm install --save-dev nodemon` ve `scripts.dev` = `"nodemon server.js"` |
| `.env` okunmuyor | `dotenv` yüklenmemiş | Dosyanın **en üstünde** `require("dotenv").config()` olmalı, başka hiçbir şeyden önce |

Bu aşama sağlamsa bir sonraki adımda bu API'yi ve Mongo'yu konteynerleştirip `docker-compose` ile birlikte çalıştıracağız: [03-dockerizasyon-compose.md](03-dockerizasyon-compose.md).
