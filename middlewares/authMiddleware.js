const jwt = require("jsonwebtoken");

function authMiddleware() {
  return async (req, res, next) => {
    try {
      const token = req.cookies?.authToken;
      if (!token) {
        return res
          .status(401)
          .json({ success: false, message: "Auth token missing" });
      }
      const decoded = jwt.verify(
        token,
        process.env.JWT_SECRET || "dev_secret_change_me"
      );
      req.user = decoded;
      next();
    } catch (err) {
      return res
        .status(401)
        .json({ success: false, message: "Invalid or expired token" });
    }
  };
}

module.exports = authMiddleware;
