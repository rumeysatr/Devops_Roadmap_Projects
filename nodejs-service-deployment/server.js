const express = require("express");

const app = express();
const port = process.env.PORT || 3000;

app.get("/", (req, res) => {
  res.send("Hello, world!");
});

app.listen(port, "127.0.0.1", () => {
  console.log(`Application is listening on port ${port}`);
});
