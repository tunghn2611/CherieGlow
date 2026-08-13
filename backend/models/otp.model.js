// models/otp.model.js — MySQL queries for otp_verifications table
const pool = require('../config/database');

const OTPModel = {
  async create({ userId, target, otpCode, type, purpose, expiresAt }) {
    await pool.execute(
      `INSERT INTO otp_verifications (user_id, target, otp_code, type, purpose, expires_at)
       VALUES (?, ?, ?, ?, ?, ?)`,
      [userId || null, target, otpCode, type, purpose, expiresAt]
    );
  },

  /** Find latest unused, non-expired OTP for a target and purpose */
  async findLatest(target, purpose) {
    const [rows] = await pool.execute(
      `SELECT * FROM otp_verifications
       WHERE target = ? AND purpose = ? AND is_used = FALSE AND expires_at > NOW()
       ORDER BY created_at DESC LIMIT 1`,
      [target, purpose]
    );
    return rows[0] || null;
  },

  async markUsed(id) {
    await pool.execute('UPDATE otp_verifications SET is_used = TRUE WHERE id = ?', [id]);
  },

  async incrementAttempts(id) {
    await pool.execute('UPDATE otp_verifications SET attempts = attempts + 1 WHERE id = ?', [id]);
  },

  async deleteExpired() {
    await pool.execute('DELETE FROM otp_verifications WHERE expires_at < NOW()');
  },
};

module.exports = OTPModel;
