const db = require("../config/db");

// Helper to standardize error responses
function sendError(res, statusCode, message) {
  return res.status(statusCode).json({ success: false, message });
}

// Create booking
// Body: { court_id, slot_id, booking_date (YYYY-MM-DD), customer_name, customer_phone, payment_status, notes, created_by }
async function createBooking(req, res) {
  try {
    const {
      court_id,
      slot_id,
      booking_date,
      customer_name,
      customer_phone,
      payment_status = "unpaid",
      notes = null,
      created_by = 1, // default admin id (adjust if using auth)
    } = req.body;

    if (
      !court_id ||
      !slot_id ||
      !booking_date ||
      !customer_name ||
      !customer_phone
    ) {
      return sendError(
        res,
        400,
        "court_id, slot_id, booking_date, customer_name, customer_phone wajib diisi"
      );
    }

    const params = [
      parseInt(court_id),
      parseInt(slot_id),
      booking_date,
      customer_name,
      customer_phone,
      payment_status,
      notes,
      parseInt(created_by),
    ];

    const results = await db.callProcedure("sp_create_booking", params);
    const row = results[0] && results[0][0];
    if (row) {
      if (row.status === "success") {
        return res.status(201).json({
          success: true,
          data: { booking_id: row.booking_id },
          message: row.message || "Booking berhasil dibuat",
        });
      }
    }
    return res.status(201).json({ success: true, message: "Booking created" });
  } catch (error) {
    // Business rule violations triggered by SIGNAL -> map to 400
    const lower = (error.message || "").toLowerCase();
    if (lower.includes("slot") || lower.includes("lapangan")) {
      return sendError(res, 400, error.message);
    }
    sendError(res, 500, error.message || "Gagal membuat booking");
  }
}

// Get booking by ID
async function getBookingById(req, res) {
  try {
    const { id } = req.params;
    if (!id || isNaN(parseInt(id)))
      return sendError(res, 400, "ID tidak valid");
    const results = await db.callProcedure("sp_get_booking_by_id", [
      parseInt(id),
    ]);
    const rows = results[0];
    if (!rows || rows.length === 0)
      return sendError(res, 404, "Booking tidak ditemukan");
    res
      .status(200)
      .json({ success: true, data: rows[0], message: "Booking ditemukan" });
  } catch (error) {
    sendError(res, 500, error.message || "Gagal mengambil booking");
  }
}

// Get booking history with optional filters & pagination
// Query: court_id, start_date, end_date, limit, offset
async function getBookingHistory(req, res) {
  try {
    const { court_id = null, start_date = null, end_date = null } = req.query;
    const limit = req.query.limit ? parseInt(req.query.limit) : 50;
    const offset = req.query.offset ? parseInt(req.query.offset) : 0;

    const params = [
      court_id ? parseInt(court_id) : null,
      start_date || null,
      end_date || null,
      limit,
      offset,
    ];
    const results = await db.callProcedure("sp_get_booking_history", params);
    const rows = results[0];
    res.status(200).json({
      success: true,
      data: rows,
      meta: { limit, offset, count: rows.length },
      message: "Riwayat booking diambil",
    });
  } catch (error) {
    sendError(res, 500, error.message || "Gagal mengambil riwayat booking");
  }
}

// Update booking status (payment_status / booking_status)
// Body: { payment_status, booking_status, updated_by }
async function updateBookingStatus(req, res) {
  try {
    const { id } = req.params;
    if (!id || isNaN(parseInt(id)))
      return sendError(res, 400, "ID tidak valid");
    const {
      payment_status = null,
      booking_status = null,
      updated_by = 1,
    } = req.body;
    if (!payment_status && !booking_status) {
      return sendError(
        res,
        400,
        "payment_status atau booking_status harus diisi"
      );
    }
    const params = [
      parseInt(id),
      payment_status,
      booking_status,
      parseInt(updated_by),
    ];
    const results = await db.callProcedure("sp_update_booking_status", params);
    const row = results[0] && results[0][0];
    if (row) {
      if (row.status === "error") return sendError(res, 400, row.message);
      return res.status(200).json({
        success: true,
        message: row.message || "Status booking diperbarui",
      });
    }
    res
      .status(200)
      .json({ success: true, message: "Status booking diperbarui" });
  } catch (error) {
    sendError(res, 500, error.message || "Gagal update status booking");
  }
}

// Update booking details (customer_name, customer_phone, notes)
async function updateBookingDetails(req, res) {
  try {
    const { id } = req.params;
    if (!id || isNaN(parseInt(id)))
      return sendError(res, 400, "ID tidak valid");
    const {
      customer_name = null,
      customer_phone = null,
      notes = null,
    } = req.body;
    if (!customer_name && !customer_phone && !notes) {
      return sendError(res, 400, "Minimal satu field diisi");
    }
    const params = [parseInt(id), customer_name, customer_phone, notes];
    const results = await db.callProcedure("sp_update_booking_details", params);
    const row = results[0] && results[0][0];
    if (row) {
      if (row.status === "error") return sendError(res, 400, row.message);
      return res.status(200).json({
        success: true,
        message: row.message || "Detail booking diperbarui",
      });
    }
    res
      .status(200)
      .json({ success: true, message: "Detail booking diperbarui" });
  } catch (error) {
    sendError(res, 500, error.message || "Gagal update detail booking");
  }
}

// Cancel booking
async function cancelBooking(req, res) {
  try {
    const { id } = req.params;
    if (!id || isNaN(parseInt(id)))
      return sendError(res, 400, "ID tidak valid");
    const results = await db.callProcedure("sp_cancel_booking", [parseInt(id)]);
    const row = results[0] && results[0][0];
    if (row) {
      if (row.status === "error") return sendError(res, 400, row.message);
      return res
        .status(200)
        .json({ success: true, message: row.message || "Booking dibatalkan" });
    }
    res.status(200).json({ success: true, message: "Booking dibatalkan" });
  } catch (error) {
    sendError(res, 500, error.message || "Gagal membatalkan booking");
  }
}

module.exports = {
  createBooking,
  getBookingById,
  getBookingHistory,
  updateBookingStatus,
  updateBookingDetails,
  cancelBooking,
};
