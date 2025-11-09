const express = require("express");
const {
  createBooking,
  getBookingById,
  getBookingHistory,
  updateBookingStatus,
  updateBookingDetails,
  cancelBooking,
} = require("../controllers/bookingController.js");

const router = express.Router();

// Create booking
router.post("/", createBooking);

// Booking history with filters
router.get("/", getBookingHistory);

// Single booking operations
router.get("/:id", getBookingById);
router.patch("/:id/status", updateBookingStatus);
router.patch("/:id/details", updateBookingDetails);
router.post("/:id/cancel", cancelBooking);

module.exports = router;
