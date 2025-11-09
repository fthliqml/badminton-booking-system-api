const express = require("express");
const {
  getAllTimeSlots,
  getAvailableTimeSlots,
  getTimeSlotById,
  createTimeSlot,
  updateTimeSlot,
  deleteTimeSlot,
} = require("../controllers/timeSlotController.js");

const router = express.Router();

// List & create
router.get("/", getAllTimeSlots);
router.post("/", createTimeSlot);

// Available for a court/date
router.get("/available", getAvailableTimeSlots);

// Single slot operations
router.get("/:id", getTimeSlotById);
router.put("/:id", updateTimeSlot);
router.delete("/:id", deleteTimeSlot);

module.exports = router;
