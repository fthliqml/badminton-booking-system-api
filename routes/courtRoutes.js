const express = require("express");
const {
  getAllCourts,
  getCourtById,
  createCourt,
  updateCourt,
  deleteCourt,
} = require("../controllers/courtController");

const router = express.Router();

router.get("/", getAllCourts);
router.get("/:id", getCourtById);
router.post("/", createCourt);
router.put("/:id", updateCourt);
router.delete("/:id", deleteCourt);

module.exports = router;
