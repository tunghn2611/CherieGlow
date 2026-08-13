// controllers/auth.controller.js — Full authentication business logic
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const { validationResult } = require('express-validator');
const jwtConfig = require('../config/jwt');
const pool = require('../config/database');
const UserModel = require('../models/user.model');
const OTPModel = require('../models/otp.model');
const SocialModel = require('../models/social.model');
const OTPService = require('../services/otp.service');
const EmailService = require('../services/email.service');
const AppleService = require('../services/apple.service');
const FacebookService = require('../services/facebook.service');
const { generateOTP, generateUUID, formatResponse } = require('../utils/helpers');

const BCRYPT_ROUNDS = 12;
const OTP_EXPIRY_MINUTES = 5;
const OTP_MAX_ATTEMPTS = 5;

// ── Helper: Generate JWT pair ─────────────────────────────────
function generateTokens(user) {
  const payload = { id: user.id, email: user.email };
  const accessToken = jwt.sign(payload, jwtConfig.secret, { expiresIn: jwtConfig.expiresIn });
  const refreshToken = jwt.sign(payload, jwtConfig.refreshSecret, { expiresIn: jwtConfig.refreshExpiresIn });
  return { accessToken, refreshToken };
}

async function saveRefreshToken(userId, token, deviceInfo) {
  const expiresAt = new Date(Date.now() + 30 * 24 * 60 * 60 * 1000); // 30 days
  await pool.execute(
    'INSERT INTO refresh_tokens (user_id, token, device_info, expires_at) VALUES (?, ?, ?, ?)',
    [userId, token, deviceInfo || 'iOS App', expiresAt]
  );
}

function handleValidationErrors(req, res) {
  const errors = validationResult(req);
  if (!errors.isEmpty()) {
    return res.status(400).json(formatResponse(false, 'Validation failed', { errors: errors.array() }));
  }
  return null;
}

// ═══════════════════════════════════════════════════════════════
const AuthController = {

  // ── POST /register ────────────────────────────────────────
  async register(req, res) {
    try {
      const valErr = handleValidationErrors(req, res);
      if (valErr) return;

      const { email, password, phone, countryCode, name } = req.body;

      // Check uniqueness
      if (email) {
        const existingEmail = await UserModel.findByEmail(email);
        if (existingEmail) return res.status(409).json(formatResponse(false, 'Email already registered'));
      }
      if (phone) {
        const existingPhone = await UserModel.findByPhone(countryCode || '+84', phone);
        if (existingPhone) return res.status(409).json(formatResponse(false, 'Phone number already registered'));
      }

      // Hash password with bcrypt (12 salt rounds)
      const passwordHash = await bcrypt.hash(password, BCRYPT_ROUNDS);

      // Create user
      const userId = await UserModel.create({
        email, phone, countryCode,
        passwordHash, name: name || '',
        authProvider: phone ? 'phone' : 'email',
      });

      // Generate and send OTP for verification
      const otpCode = generateOTP();
      const expiresAt = new Date(Date.now() + OTP_EXPIRY_MINUTES * 60 * 1000);
      await OTPModel.create({ userId, target: email || phone, otpCode, type: email ? 'email' : 'sms', purpose: 'register', expiresAt });

      if (email) {
        await EmailService.sendOTPEmail(email, otpCode);
      } else if (phone) {
        const fullPhone = `${countryCode || '+84'}${phone}`;
        await OTPService.sendSMS(fullPhone, otpCode);
      }

      res.status(201).json(formatResponse(true, 'Registration successful. Please verify OTP.', { userId }));
    } catch (err) {
      console.error('❌ [REGISTER]', err);
      res.status(500).json(formatResponse(false, 'Internal server error'));
    }
  },

  // ── POST /login ───────────────────────────────────────────
  async login(req, res) {
    try {
      const valErr = handleValidationErrors(req, res);
      if (valErr) return;

      const { email, password } = req.body;
      const user = await UserModel.findByEmail(email);
      if (!user) return res.status(401).json(formatResponse(false, 'Invalid email or password'));
      if (!user.password_hash) return res.status(401).json(formatResponse(false, 'Account uses social login. Use Apple or Facebook.'));

      const isMatch = await bcrypt.compare(password, user.password_hash);
      if (!isMatch) return res.status(401).json(formatResponse(false, 'Invalid email or password'));

      if (!user.is_verified) return res.status(403).json(formatResponse(false, 'Account not verified. Please verify OTP first.', { userId: user.id }));

      const tokens = generateTokens(user);
      await saveRefreshToken(user.id, tokens.refreshToken, req.headers['user-agent']);

      res.json(formatResponse(true, 'Login successful', {
        ...tokens,
        user: { id: user.id, email: user.email, name: user.name, avatarUrl: user.avatar_url, profileCompleted: !!user.profile_completed },
      }));
    } catch (err) {
      console.error('❌ [LOGIN]', err);
      res.status(500).json(formatResponse(false, 'Internal server error'));
    }
  },

  // ── POST /send-otp ────────────────────────────────────────
  async sendOTP(req, res) {
    try {
      const valErr = handleValidationErrors(req, res);
      if (valErr) return;

      const { target, type, purpose } = req.body;
      const otpCode = generateOTP();
      const expiresAt = new Date(Date.now() + OTP_EXPIRY_MINUTES * 60 * 1000);

      // Find user if exists or auto-create for phone
      let userId = null;
      if (type === 'email') {
        const user = await UserModel.findByEmail(target);
        if (user) userId = user.id;
      } else if (type === 'sms') {
        let countryCode = '+84';
        let phone = target;
        if (target.startsWith('+')) {
          // Tách country code từ đầu chuỗi
          if (target.startsWith('+1') && target.length <= 12) {
            countryCode = '+1';
            phone = target.substring(2);
          } else {
            countryCode = target.substring(0, 3);
            phone = target.substring(3);
          }
        }
        // QUAN TRỌNG: Chuẩn hóa - luôn loại bỏ số 0 đầu để tránh duplicate user
        phone = phone.replace(/[\s\-().]/g, '');
        if (phone.startsWith('0')) {
          phone = phone.substring(1);
        }
        
        let user = await UserModel.findByPhone(countryCode, phone);
        if (!user) {
          const newId = await UserModel.create({
            phone,
            countryCode,
            authProvider: 'phone',
          });
          user = await UserModel.findById(newId);
        }
        userId = user.id;
      }

      await OTPModel.create({ userId, target, otpCode, type, purpose, expiresAt });

      if (type === 'sms') {
        await OTPService.sendSMS(target, otpCode);
      } else {
        await EmailService.sendOTPEmail(target, otpCode);
      }

      res.json(formatResponse(true, `OTP sent via ${type}`, {
        expiresIn: OTP_EXPIRY_MINUTES * 60,
        otpCode: process.env.NODE_ENV === 'development' ? otpCode : undefined
      }));
    } catch (err) {
      console.error('❌ [SEND-OTP]', err);
      res.status(500).json(formatResponse(false, 'Failed to send OTP'));
    }
  },

  // ── POST /verify-otp ──────────────────────────────────────
  async verifyOTP(req, res) {
    try {
      const valErr = handleValidationErrors(req, res);
      if (valErr) return;

      const { target, otpCode, purpose } = req.body;
      const otp = await OTPModel.findLatest(target, purpose);
      if (!otp) return res.status(400).json(formatResponse(false, 'No valid OTP found. Please request a new one.'));
      if (otp.attempts >= OTP_MAX_ATTEMPTS) return res.status(429).json(formatResponse(false, 'Too many failed attempts. Request a new OTP.'));

      if (otp.otp_code !== otpCode) {
        await OTPModel.incrementAttempts(otp.id);
        return res.status(400).json(formatResponse(false, `Invalid OTP. ${OTP_MAX_ATTEMPTS - otp.attempts - 1} attempts remaining.`));
      }

      await OTPModel.markUsed(otp.id);

      // If purpose is register or login, verify user and return tokens
      if ((purpose === 'register' || purpose === 'login') && otp.user_id) {
        await UserModel.markVerified(otp.user_id);
        const user = await UserModel.findById(otp.user_id);
        const tokens = generateTokens(user);
        await saveRefreshToken(user.id, tokens.refreshToken, req.headers['user-agent']);
        return res.json(formatResponse(true, 'Account verified', {
          ...tokens,
          user: { id: user.id, email: user.email, phone: user.phone, name: user.name, avatarUrl: user.avatar_url, profileCompleted: !!user.profile_completed },
        }));
      }

      res.json(formatResponse(true, 'OTP verified'));
    } catch (err) {
      console.error('❌ [VERIFY-OTP]', err);
      res.status(500).json(formatResponse(false, 'Internal server error'));
    }
  },

  // ── POST /forgot-password ─────────────────────────────────
  async forgotPassword(req, res) {
    try {
      const { email } = req.body;
      if (!email) return res.status(400).json(formatResponse(false, 'Email required'));

      const user = await UserModel.findByEmail(email);
      if (!user) return res.status(404).json(formatResponse(false, 'No account found with this email'));

      const otpCode = generateOTP();
      const expiresAt = new Date(Date.now() + OTP_EXPIRY_MINUTES * 60 * 1000);
      await pool.execute(
        'INSERT INTO password_resets (user_id, email, otp_code, expires_at) VALUES (?, ?, ?, ?)',
        [user.id, email, otpCode, expiresAt]
      );
      await EmailService.sendPasswordResetEmail(email, otpCode);

      res.json(formatResponse(true, 'Password reset OTP sent to your email'));
    } catch (err) {
      console.error('❌ [FORGOT-PASSWORD]', err);
      res.status(500).json(formatResponse(false, 'Internal server error'));
    }
  },

  // ── POST /reset-password ──────────────────────────────────
  async resetPassword(req, res) {
    try {
      const valErr = handleValidationErrors(req, res);
      if (valErr) return;

      const { email, otpCode, newPassword } = req.body;

      const [rows] = await pool.execute(
        'SELECT * FROM password_resets WHERE email = ? AND is_used = FALSE AND expires_at > NOW() ORDER BY created_at DESC LIMIT 1',
        [email]
      );
      const reset = rows[0];
      if (!reset) return res.status(400).json(formatResponse(false, 'No valid reset request. Please request again.'));
      if (reset.otp_code !== otpCode) return res.status(400).json(formatResponse(false, 'Invalid OTP'));

      const passwordHash = await bcrypt.hash(newPassword, BCRYPT_ROUNDS);
      await UserModel.updatePassword(reset.user_id, passwordHash);
      await pool.execute('UPDATE password_resets SET is_used = TRUE WHERE id = ?', [reset.id]);

      res.json(formatResponse(true, 'Password reset successful. You can now login.'));
    } catch (err) {
      console.error('❌ [RESET-PASSWORD]', err);
      res.status(500).json(formatResponse(false, 'Internal server error'));
    }
  },

  // ── POST /apple ───────────────────────────────────────────
  async loginWithApple(req, res) {
    try {
      const { identityToken, fullName } = req.body;
      if (!identityToken) return res.status(400).json(formatResponse(false, 'Identity token required'));

      const appleData = await AppleService.verifyToken(identityToken);
      let socialAccount = await SocialModel.findByProviderUid('apple', appleData.sub);
      let user;

      if (socialAccount) {
        user = await UserModel.findById(socialAccount.user_id);
      } else {
        // Create new user for Apple login
        const userId = await UserModel.create({
          email: appleData.email || null,
          name: fullName || '',
          authProvider: 'apple',
        });
        await SocialModel.linkAccount(userId, 'apple', {
          providerUid: appleData.sub,
          providerEmail: appleData.email,
          providerName: fullName,
        });
        await UserModel.markVerified(userId);
        user = await UserModel.findById(userId);
      }

      const tokens = generateTokens(user);
      await saveRefreshToken(user.id, tokens.refreshToken, req.headers['user-agent']);

      res.json(formatResponse(true, 'Apple login successful', {
        ...tokens,
        user: { id: user.id, email: user.email, name: user.name, avatarUrl: user.avatar_url, profileCompleted: !!user.profile_completed },
      }));
    } catch (err) {
      console.error('❌ [APPLE-LOGIN]', err);
      res.status(500).json(formatResponse(false, err.message || 'Apple login failed'));
    }
  },

  // ── POST /google ───────────────────────────────────────────
  async loginWithGoogle(req, res) {
    try {
      const { idToken } = req.body;
      if (!idToken) return res.status(400).json(formatResponse(false, 'ID token required'));

      // Verify Google ID token via Google's tokeninfo endpoint
      const axios = require('axios');
      const googleResponse = await axios.get(`https://oauth2.googleapis.com/tokeninfo?id_token=${idToken}`);
      const googleData = googleResponse.data;

      if (!googleData || !googleData.sub) {
        return res.status(401).json(formatResponse(false, 'Invalid Google token'));
      }

      let socialAccount = await SocialModel.findByProviderUid('google', googleData.sub);
      let user;

      if (socialAccount) {
        user = await UserModel.findById(socialAccount.user_id);
      } else {
        // Create new user for Google login
        const userId = await UserModel.create({
          email: googleData.email || null,
          name: googleData.name || '',
          authProvider: 'google',
        });
        await SocialModel.linkAccount(userId, 'google', {
          providerUid: googleData.sub,
          providerEmail: googleData.email,
          providerName: googleData.name,
          accessToken: idToken,
        });
        await UserModel.markVerified(userId);
        user = await UserModel.findById(userId);
      }

      const tokens = generateTokens(user);
      await saveRefreshToken(user.id, tokens.refreshToken, req.headers['user-agent']);

      res.json(formatResponse(true, 'Google login successful', {
        ...tokens,
        user: { id: user.id, email: user.email, name: user.name, avatarUrl: googleData.picture || user.avatar_url, profileCompleted: !!user.profile_completed },
      }));
    } catch (err) {
      console.error('❌ [GOOGLE-LOGIN]', err.response?.data || err.message);
      res.status(500).json(formatResponse(false, err.message || 'Google login failed'));
    }
  },

  // ── POST /facebook ────────────────────────────────────────
  async loginWithFacebook(req, res) {
    try {
      const { accessToken } = req.body;
      if (!accessToken) return res.status(400).json(formatResponse(false, 'Access token required'));

      const fbData = await FacebookService.verifyToken(accessToken);
      let socialAccount = await SocialModel.findByProviderUid('facebook', fbData.id);
      let user;

      if (socialAccount) {
        user = await UserModel.findById(socialAccount.user_id);
      } else {
        const userId = await UserModel.create({
          email: fbData.email || null,
          name: fbData.name || '',
          authProvider: 'facebook',
        });
        await SocialModel.linkAccount(userId, 'facebook', {
          providerUid: fbData.id,
          providerEmail: fbData.email,
          providerName: fbData.name,
          accessToken,
        });
        await UserModel.markVerified(userId);
        user = await UserModel.findById(userId);
      }

      const tokens = generateTokens(user);
      await saveRefreshToken(user.id, tokens.refreshToken, req.headers['user-agent']);

      res.json(formatResponse(true, 'Facebook login successful', {
        ...tokens,
        user: { id: user.id, email: user.email, name: user.name, avatarUrl: fbData.picture || user.avatar_url, profileCompleted: !!user.profile_completed },
      }));
    } catch (err) {
      console.error('❌ [FACEBOOK-LOGIN]', err);
      res.status(500).json(formatResponse(false, err.message || 'Facebook login failed'));
    }
  },

  // ── GET /profile ──────────────────────────────────────────
  async getProfile(req, res) {
    try {
      const user = await UserModel.findById(req.user.id);
      if (!user) return res.status(404).json(formatResponse(false, 'User not found'));

      res.json(formatResponse(true, 'Profile loaded', {
        id: user.id, email: user.email, phone: user.phone, countryCode: user.country_code,
        name: user.name, gender: user.gender, dateOfBirth: user.date_of_birth,
        avatarUrl: user.avatar_url, authProvider: user.auth_provider,
        isVerified: !!user.is_verified, profileCompleted: !!user.profile_completed,
      }));
    } catch (err) {
      console.error('❌ [GET-PROFILE]', err);
      res.status(500).json(formatResponse(false, 'Internal server error'));
    }
  },

  // ── PUT /profile ──────────────────────────────────────────
  async updateProfile(req, res) {
    try {
      const { name, gender, dateOfBirth, avatarUrl } = req.body;
      await UserModel.updateProfile(req.user.id, { name, gender, dateOfBirth, avatarUrl });
      const user = await UserModel.findById(req.user.id);
      res.json(formatResponse(true, 'Profile updated', {
        id: user.id, name: user.name, gender: user.gender,
        dateOfBirth: user.date_of_birth, avatarUrl: user.avatar_url, profileCompleted: !!user.profile_completed,
      }));
    } catch (err) {
      console.error('❌ [UPDATE-PROFILE]', err);
      res.status(500).json(formatResponse(false, 'Internal server error'));
    }
  },

  // ── POST /refresh-token ───────────────────────────────────
  async refreshToken(req, res) {
    try {
      const { refreshToken } = req.body;
      if (!refreshToken) return res.status(400).json(formatResponse(false, 'Refresh token required'));

      const [rows] = await pool.execute(
        'SELECT * FROM refresh_tokens WHERE token = ? AND expires_at > NOW()',
        [refreshToken]
      );
      if (!rows[0]) return res.status(401).json(formatResponse(false, 'Invalid or expired refresh token'));

      let decoded;
      try {
        decoded = jwt.verify(refreshToken, jwtConfig.refreshSecret);
      } catch { return res.status(401).json(formatResponse(false, 'Invalid refresh token')); }

      const user = await UserModel.findById(decoded.id);
      if (!user) return res.status(401).json(formatResponse(false, 'User not found'));

      // Rotate: delete old, issue new
      await pool.execute('DELETE FROM refresh_tokens WHERE token = ?', [refreshToken]);
      const tokens = generateTokens(user);
      await saveRefreshToken(user.id, tokens.refreshToken, req.headers['user-agent']);

      res.json(formatResponse(true, 'Token refreshed', tokens));
    } catch (err) {
      console.error('❌ [REFRESH-TOKEN]', err);
      res.status(500).json(formatResponse(false, 'Internal server error'));
    }
  },

  // ── POST /logout ──────────────────────────────────────────
  async logout(req, res) {
    try {
      const { refreshToken } = req.body;
      if (refreshToken) {
        await pool.execute('DELETE FROM refresh_tokens WHERE token = ?', [refreshToken]);
      }
      // Also delete all tokens for this user if requested
      // await pool.execute('DELETE FROM refresh_tokens WHERE user_id = ?', [req.user.id]);
      res.json(formatResponse(true, 'Logged out successfully'));
    } catch (err) {
      console.error('❌ [LOGOUT]', err);
      res.status(500).json(formatResponse(false, 'Internal server error'));
    }
  },
};

module.exports = AuthController;
