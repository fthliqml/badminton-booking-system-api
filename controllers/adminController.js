const db = require("../config/db");
const jwt = require("jsonwebtoken");
const crypto = require("crypto");

const JWT_SECRET = process.env.JWT_SECRET || "dev_secret_change_me";
const JWT_EXPIRES_IN = process.env.JWT_EXPIRES_IN || "1d"; // e.g. 1h, 1d

const buildTokenPayload = (admin) => ({
  admin_id: admin.admin_id,
  username: admin.username,
  full_name: admin.full_name,
  email: admin.email,
});

const cookieOptions = {
  httpOnly: true,
  secure: process.env.NODE_ENV === "production", // set true behind HTTPS
  sameSite: "lax",
  maxAge: 24 * 60 * 60 * 1000, // 1 day default
  path: "/",
};

const testConnection = async (req, res) => {
  try {
    const results = await db.callProcedure("sp_test_connection");
    const connectionTest = results[0][0];

    const responseStatus = connectionTest.system_status === "ready" ? 200 : 206;

    res.status(responseStatus).json({
      success: true,
      data: {
        status: connectionTest.status,
        message: connectionTest.message,
        server_time: connectionTest.server_time,
        database_info: {
          name: connectionTest.database_name,
          mysql_version: connectionTest.mysql_version,
        },
        system_health: {
          total_admins: connectionTest.total_admins,
          total_courts: connectionTest.total_courts,
          total_time_slots: connectionTest.total_time_slots,
          total_bookings: connectionTest.total_bookings,
          active_bookings_today: connectionTest.active_bookings_today,
          system_status: connectionTest.system_status,
        },
      },
      message:
        connectionTest.system_status === "ready"
          ? "Database connection and system health check passed"
          : "Database connected but system setup incomplete",
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      data: {
        status: "failed",
        message: "Database connection failed",
        error: error.message,
        server_time: new Date().toISOString(),
      },
      message: "Database connection test failed",
    });
  }
};

const login = async (req, res) => {
  try {
    const { username, password } = req.body;
    if (!username || !password) {
      return res.status(400).json({
        success: false,
        message: "Username and password are required",
      });
    }

    const hashedPassword = crypto
      .createHash("md5")
      .update(password)
      .digest("hex");
    const results = await db.callProcedure("sp_admin_login", [
      username,
      hashedPassword,
    ]);
    const loginResult = results[0][0];

    if (loginResult.status === "success") {
      const payload = buildTokenPayload(loginResult);
      const token = jwt.sign(payload, JWT_SECRET, {
        expiresIn: JWT_EXPIRES_IN,
      });

      res
        .cookie("authToken", token, cookieOptions)
        .status(200)
        .json({
          success: true,
          message: "Login successful",
          data: { ...payload },
        });
    } else {
      res
        .status(401)
        .json({ success: false, message: "Invalid username or password" });
    }
  } catch (error) {
    res
      .status(500)
      .json({ success: false, message: error.message || "Login failed" });
  }
};

const logout = async (req, res) => {
  try {
    res
      .clearCookie("authToken", { path: "/" })
      .status(200)
      .json({ success: true, message: "Logout successful" });
  } catch (error) {
    res
      .status(500)
      .json({ success: false, message: error.message || "Logout failed" });
  }
};

// Return profile from token (assumes authMiddleware validated it and set req.user)
const getProfile = async (req, res) => {
  try {
    if (!req.user) {
      return res.status(401).json({ success: false, message: "Unauthorized" });
    }
    res
      .status(200)
      .json({ success: true, data: req.user, message: "Profile fetched" });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: error.message || "Failed to fetch profile",
    });
  }
};

module.exports = { testConnection, login, logout, getProfile };
