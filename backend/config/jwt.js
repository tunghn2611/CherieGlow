// config/jwt.js — JWT configuration
module.exports = {
  secret: process.env.JWT_SECRET || 'fallback_secret_key',
  refreshSecret: process.env.JWT_REFRESH_SECRET || 'fallback_refresh_secret_key',
  expiresIn: process.env.JWT_EXPIRES_IN || '15m',
  refreshExpiresIn: process.env.JWT_REFRESH_EXPIRES_IN || '30d',
};
