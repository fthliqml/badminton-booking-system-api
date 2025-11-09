const express = require("express");
const bodyParser = require("body-parser");
const cookieParser = require("cookie-parser");
const courtRoutes = require("./routes/courtRoutes");
const adminRoutes = require("./routes/adminRoutes");
const timeSlotRoutes = require("./routes/timeSlotRoutes");
const bookingRoutes = require("./routes/bookingRoutes");
const auth = require("./middlewares/authMiddleware");

const app = express();

app.use(bodyParser.json());
app.use(cookieParser());

// Public routes (test connection + login/logout)
app.use("/", adminRoutes);

// Protect following route groups with auth middleware
app.use("/courts", auth(), courtRoutes);
app.use("/time-slots", auth(), timeSlotRoutes);
app.use("/bookings", auth(), bookingRoutes);

const port = 3000;
app.listen(port, () => {
  console.log(`Server running on port ${port}`);
});
