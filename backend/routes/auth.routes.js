// routes/auth.routes.js — Auth endpoint definitions
const router = require('express').Router();
const AuthController = require('../controllers/auth.controller');
const authMiddleware = require('../middleware/auth');
const { otpLimiter, authLimiter } = require('../middleware/rateLimiter');
const { validateRegister, validateLogin, validateSendOTP, validateVerifyOTP, validateResetPassword, validateProfile } = require('../utils/validators');

// Public routes
router.post('/register',        authLimiter, validateRegister,      AuthController.register);
router.post('/login',           authLimiter, validateLogin,          AuthController.login);
router.post('/send-otp',        otpLimiter,  validateSendOTP,        AuthController.sendOTP);
router.post('/verify-otp',      authLimiter, validateVerifyOTP,      AuthController.verifyOTP);
router.post('/forgot-password', otpLimiter,                          AuthController.forgotPassword);
router.post('/reset-password',  authLimiter, validateResetPassword,  AuthController.resetPassword);
router.post('/apple',           authLimiter,                          AuthController.loginWithApple);
router.post('/google',          authLimiter,                          AuthController.loginWithGoogle);
router.post('/facebook',        authLimiter,                          AuthController.loginWithFacebook);
router.post('/refresh-token',                                         AuthController.refreshToken);

// Protected routes (require JWT)
router.get('/profile',          authMiddleware,                       AuthController.getProfile);
router.put('/profile',          authMiddleware, validateProfile,      AuthController.updateProfile);
router.post('/logout',          authMiddleware,                       AuthController.logout);

module.exports = router;
