// models/social.model.js — MySQL queries for social_accounts table
const pool = require('../config/database');

const SocialModel = {
  async findByProviderUid(provider, providerUid) {
    const [rows] = await pool.execute(
      'SELECT * FROM social_accounts WHERE provider = ? AND provider_uid = ?',
      [provider, providerUid]
    );
    return rows[0] || null;
  },

  async linkAccount(userId, provider, { providerUid, providerEmail, providerName, accessToken }) {
    await pool.execute(
      `INSERT INTO social_accounts (user_id, provider, provider_uid, provider_email, provider_name, access_token)
       VALUES (?, ?, ?, ?, ?, ?)
       ON DUPLICATE KEY UPDATE provider_email = VALUES(provider_email), provider_name = VALUES(provider_name), access_token = VALUES(access_token)`,
      [userId, provider, providerUid, providerEmail || null, providerName || null, accessToken || null]
    );
  },

  async findByUserId(userId) {
    const [rows] = await pool.execute('SELECT * FROM social_accounts WHERE user_id = ?', [userId]);
    return rows;
  },
};

module.exports = SocialModel;
