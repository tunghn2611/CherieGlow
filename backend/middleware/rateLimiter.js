// middleware/rateLimiter.js — Rate limiting for security
const rateLimit = require('express-rate-limit');

const isDev = process.env.NODE_ENV !== 'production';

// General API rate limit: 100 requests per 15 minutes (1000 in dev)
const generalLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: isDev ? 1000 : 100,
  message: { success: false, message: 'Too many requests. Please try again later.' },
  standardHeaders: true,
  legacyHeaders: false,
});

// OTP rate limit: 3 requests per minute in production, 20 in dev
const otpLimiter = rateLimit({
  windowMs: 60 * 1000,
  max: isDev ? 20 : 3,
  message: { success: false, message: 'OTP request limit exceeded. Wait 60 seconds.' },
  standardHeaders: true,
  legacyHeaders: false,
});

// Auth rate limit: 10 requests per 15 minutes per IP (100 in dev)
const authLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: isDev ? 100 : 10,
  message: { success: false, message: 'Too many login attempts. Please try again later.' },
  standardHeaders: true,
  legacyHeaders: false,
});

module.exports = { generalLimiter, otpLimiter, authLimiter };
