import db from "../config/db.js";

export const getAllTimeSlots = async (req, res) => {
  try {
    const results = await db.callProcedure("sp_get_all_time_slots");
    res.status(200).json({
      success: true,
      data: results[0],
      message: "Time slots retrieved successfully",
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: error.message || "Failed to retrieve time slots",
    });
  }
};

// khusus 1 court dan 1 tanggal
export const getAvailableTimeSlots = async (req, res) => {
  try {
    const { court_id, booking_date } = req.query;

    if (!court_id) {
      return res.status(400).json({
        success: false,
        message: "court_id is required",
      });
    }

    const results = await db.callProcedure("sp_get_available_time_slots", [
      court_id,
      booking_date || new Date().toISOString().split("T")[0],
    ]);

    // Convert is_available to boolean
    const slots = results[0].map((slot) => ({
      ...slot,
      is_available: Boolean(slot.is_available),
    }));

    res.status(200).json({
      success: true,
      data: {
        court_id: parseInt(court_id),
        booking_date: booking_date || new Date().toISOString().split("T")[0],
        slots: slots,
      },
      message: "Available time slots retrieved successfully",
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: error.message || "Failed to retrieve available time slots",
    });
  }
};

// Get single time slot by ID
export const getTimeSlotById = async (req, res) => {
  try {
    const { id } = req.params;
    if (!id || isNaN(parseInt(id))) {
      return res
        .status(400)
        .json({ success: false, message: "Valid id param is required" });
    }

    const results = await db.callProcedure("sp_get_time_slot_by_id", [
      parseInt(id),
    ]);
    const rows = results[0];
    if (!rows || rows.length === 0) {
      return res
        .status(404)
        .json({ success: false, message: "Time slot not found" });
    }
    res.status(200).json({
      success: true,
      data: rows[0],
      message: "Time slot retrieved successfully",
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: error.message || "Failed to retrieve time slot",
    });
  }
};

// Create new time slot
export const createTimeSlot = async (req, res) => {
  try {
    const { start_time, end_time, slot_name, status } = req.body;

    if (!start_time || !end_time || !slot_name) {
      return res.status(400).json({
        success: false,
        message: "start_time, end_time and slot_name are required",
      });
    }

    // Basic validation: times should have HH:MM or HH:MM:SS and start < end
    if (start_time >= end_time) {
      return res.status(400).json({
        success: false,
        message: "start_time must be before end_time",
      });
    }

    const results = await db.callProcedure("sp_create_time_slot", [
      start_time,
      end_time,
      slot_name,
      status || null,
    ]);
    const row = results[0] && results[0][0];
    if (row && row.status === "success") {
      return res.status(201).json({
        success: true,
        data: { slot_id: row.slot_id },
        message: row.message || "Time slot created successfully",
      });
    }

    // Fallback if procedure didn't return expected format
    res.status(201).json({ success: true, message: "Time slot created" });
  } catch (error) {
    // Known business rule violations from SIGNAL are surfaced as 500 normally; map to 400
    const businessErrors = ["overlaps", "Start time must be before end time"]; // substrings
    const isBusiness = businessErrors.some((s) =>
      (error.message || "").toLowerCase().includes(s.toLowerCase())
    );
    res.status(isBusiness ? 400 : 500).json({
      success: false,
      message: error.message || "Failed to create time slot",
    });
  }
};

// Update time slot (partial)
export const updateTimeSlot = async (req, res) => {
  try {
    const { id } = req.params;
    if (!id || isNaN(parseInt(id))) {
      return res
        .status(400)
        .json({ success: false, message: "Valid id param is required" });
    }
    const { start_time, end_time, slot_name, status } = req.body;

    // If both provided, validate ordering
    if (start_time && end_time && start_time >= end_time) {
      return res.status(400).json({
        success: false,
        message: "start_time must be before end_time",
      });
    }

    const params = [
      parseInt(id),
      start_time || null,
      end_time || null,
      slot_name || null,
      status || null,
    ];
    const results = await db.callProcedure("sp_update_time_slot", params);
    const row = results[0] && results[0][0];
    if (row) {
      if (row.status === "error") {
        return res.status(400).json({ success: false, message: row.message });
      }
      if (row.status === "success") {
        return res.status(200).json({
          success: true,
          message: row.message || "Time slot updated successfully",
        });
      }
    }
    res.status(200).json({ success: true, message: "Time slot updated" });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: error.message || "Failed to update time slot",
    });
  }
};

// Delete time slot
export const deleteTimeSlot = async (req, res) => {
  try {
    const { id } = req.params;
    if (!id || isNaN(parseInt(id))) {
      return res
        .status(400)
        .json({ success: false, message: "Valid id param is required" });
    }
    const results = await db.callProcedure("sp_delete_time_slot", [
      parseInt(id),
    ]);
    const row = results[0] && results[0][0];
    if (row) {
      if (row.status === "error") {
        return res.status(400).json({ success: false, message: row.message });
      }
      if (row.status === "success") {
        return res.status(200).json({
          success: true,
          message: row.message || "Time slot deleted successfully",
        });
      }
    }
    res.status(200).json({ success: true, message: "Time slot deleted" });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: error.message || "Failed to delete time slot",
    });
  }
};
