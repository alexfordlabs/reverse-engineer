// users route — list + create. Foreign/brownfield fixture material so the
// reverse-engineer inventory + requirements-extractor agents have a real handler.
const express = require("express");
const { User, validateUser } = require("../models/user");

const router = express.Router();

// In-memory store — this is a fixture, not a real persistence layer.
const store = [];

router.get("/", (req, res) => {
  res.json(store.map((u) => u.toPublicJSON()));
});

router.post("/", (req, res) => {
  const errors = validateUser(req.body);
  if (errors.length > 0) {
    return res.status(400).json({ errors });
  }
  const user = new User(req.body);
  store.push(user);
  return res.status(201).json(user.toPublicJSON());
});

module.exports = router;
