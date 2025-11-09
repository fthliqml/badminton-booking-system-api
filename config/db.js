const mysql = require("mysql2/promise");
require("dotenv").config();

const pool = mysql.createPool({
  host: process.env.DB_HOST,
  user: process.env.DB_USER,
  password: process.env.DB_PASSWORD,
  database: process.env.DB_NAME,
});

// fungsi query biasa
async function query(sql, params = []) {
  try {
    const [results] = await pool.execute(sql, params);
    return results;
  } catch (error) {
    console.error("Database query error:", error);
    throw error;
  }
}

// fungsi call procedure
async function callProcedure(procedureName, params = []) {
  try {
    const placeholders = params.map(() => "?").join(",");
    const sql = `CALL ${procedureName}(${placeholders})`;
    const [results] = await pool.execute(sql, params);
    return results;
  } catch (error) {
    console.error(`Procedure ${procedureName} error:`, error);
    throw error;
  }
}

async function callFunction(functionName, params = []) {
  try {
    const placeholders = params.map(() => "?").join(", ");
    const query = `SELECT ${functionName}(${placeholders}) as result`;
    const [results] = await this.pool.execute(query, params);
    return results[0].result;
  } catch (error) {
    console.error(`Database error in ${functionName}:`, error);
    throw error;
  }
}

// fungsi tutup pool
async function close() {
  await pool.end();
}

module.exports = { query, callProcedure, callFunction, close };
