const express = require("express");
const {
  testConnection,
  login,
  logout,
  getProfile,
} = require("../controllers/adminController");
const auth = require("../middlewares/authMiddleware");

const router = express.Router();

// Health / system test
router.get("/", testConnection);

// Auth
router.post("/login", login);
router.post("/logout", logout);
router.get("/me", auth(), getProfile);

module.exports = router;
