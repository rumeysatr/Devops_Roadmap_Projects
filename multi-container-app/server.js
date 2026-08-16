require("dotenv").config();
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
    { new: true, runValidators: true }
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
