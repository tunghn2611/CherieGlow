// models/user.model.js — MySQL queries for users table
const pool = require('../config/database');
const { generateUUID } = require('../utils/helpers');

// Chuẩn hóa số điện thoại: loại bỏ khoảng trắng, dấu gạch, và số 0 đầu
function normalizePhone(phone) {
  if (!phone) return '';
  let p = phone.replace(/[\s\-().]/g, '');
  // Loại bỏ số 0 đầu tiên (ví dụ: 0912345678 → 912345678)
  if (p.startsWith('0')) p = p.substring(1);
  return p;
}

const UserModel = {
  async findById(id) {
    const [rows] = await pool.execute('SELECT * FROM users WHERE id = ?', [id]);
    return rows[0] || null;
  },

  async findByEmail(email) {
    const [rows] = await pool.execute('SELECT * FROM users WHERE email = ?', [email]);
    return rows[0] || null;
  },

  async findByPhone(countryCode, phone) {
    const normalized = normalizePhone(phone);
    // Tìm theo cả số gốc VÀ số đã chuẩn hóa để xử lý trường hợp
    // trước đây đã lưu 0912345678 hoặc 912345678
    const [rows] = await pool.execute(
      'SELECT * FROM users WHERE country_code = ? AND (phone = ? OR phone = ? OR phone = ?)',
      [countryCode, phone, normalized, '0' + normalized]
    );
    return rows[0] || null;
  },

  async create({ email, phone, countryCode, passwordHash, name, authProvider }) {
    const id = generateUUID();
    // Luôn lưu số điện thoại đã chuẩn hóa (không có 0 đầu)
    const normalizedPhone = phone ? normalizePhone(phone) : null;
    await pool.execute(
      `INSERT INTO users (id, email, phone, country_code, password_hash, name, auth_provider)
       VALUES (?, ?, ?, ?, ?, ?, ?)`,
      [id, email || null, normalizedPhone, countryCode || '+84', passwordHash || null, name || '', authProvider || 'email']
    );
    return id;
  },

  async updateProfile(id, { name, gender, dateOfBirth, avatarUrl }) {
    const fields = [];
    const params = [];
    if (name !== undefined) { fields.push('name = ?'); params.push(name); }
    if (gender !== undefined) { fields.push('gender = ?'); params.push(gender); }
    if (dateOfBirth !== undefined) { fields.push('date_of_birth = ?'); params.push(dateOfBirth); }
    if (avatarUrl !== undefined) { fields.push('avatar_url = ?'); params.push(avatarUrl); }
    fields.push('profile_completed = TRUE');
    params.push(id);
    await pool.execute(`UPDATE users SET ${fields.join(', ')} WHERE id = ?`, params);
  },

  async updatePassword(id, passwordHash) {
    await pool.execute('UPDATE users SET password_hash = ? WHERE id = ?', [passwordHash, id]);
  },

  async markVerified(id) {
    await pool.execute('UPDATE users SET is_verified = TRUE WHERE id = ?', [id]);
  },

  async markProfileCompleted(id) {
    await pool.execute('UPDATE users SET profile_completed = TRUE WHERE id = ?', [id]);
  },
};

module.exports = UserModel;
