import db from "../config/db.js";

export const getAllCourts = async (req, res) => {
  try {
    const results = await db.callProcedure("sp_get_all_courts");
    res.status(200).json({
      success: true,
      data: results[0],
      message: "Courts retrieved successfully",
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: error.message || "Failed to retrieve courts",
    });
  }
};

export const getCourtById = async (req, res) => {
  try {
    const { id } = req.params;
    const results = await db.callProcedure("sp_get_court_by_id", [id]);

    if (results[0].length === 0) {
      return res.status(404).json({
        success: false,
        message: "Court not found",
      });
    }

    res.status(200).json({
      success: true,
      data: results[0][0],
      message: "Court retrieved successfully",
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: error.message || "Failed to retrieve court",
    });
  }
};

export const createCourt = async (req, res) => {
  try {
    const { court_name, description, price_per_session, status } = req.body;

    if (!court_name || !price_per_session) {
      return res.status(400).json({
        success: false,
        message: "Court name and price per session are required",
      });
    }

    const results = await db.callProcedure("sp_create_court", [
      court_name,
      description || null,
      price_per_session,
      status || "active",
    ]);

    const result = results[0][0];

    res.status(201).json({
      success: true,
      data: { court_id: result.court_id },
      message: result.message,
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: error.message || "Failed to create court",
    });
  }
};

export const updateCourt = async (req, res) => {
  try {
    const { id } = req.params;
    const { court_name, description, price_per_session, status } = req.body;

    const results = await db.callProcedure("sp_update_court", [
      id,
      court_name || null,
      description || null,
      price_per_session || null,
      status || null,
    ]);

    const result = results[0][0];

    if (result.status === "error") {
      return res.status(404).json({
        success: false,
        message: result.message,
      });
    }

    res.status(200).json({
      success: true,
      message: result.message,
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: error.message || "Failed to update court",
    });
  }
};

export const deleteCourt = async (req, res) => {
  try {
    const { id } = req.params;
    const results = await db.callProcedure("sp_delete_court", [id]);
    const result = results[0][0];

    if (result.status === "error") {
      return res.status(400).json({
        success: false,
        message: result.message,
      });
    }

    res.status(200).json({
      success: true,
      message: result.message,
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: error.message || "Failed to delete court",
    });
  }
};
