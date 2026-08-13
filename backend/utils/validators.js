// utils/validators.js — Express-validator chains for input validation
const { body } = require('express-validator');

const validateRegister = [
  body('email').isEmail().normalizeEmail().withMessage('Valid email required'),
  body('password')
    .isLength({ min: 8 }).withMessage('Password must be at least 8 characters')
    .matches(/[A-Z]/).withMessage('Password must contain an uppercase letter')
    .matches(/[0-9]/).withMessage('Password must contain a number'),
  body('phone').optional().isMobilePhone().withMessage('Invalid phone number'),
  body('countryCode').optional().isString(),
];

const validateLogin = [
  body('email').isEmail().normalizeEmail().withMessage('Valid email required'),
  body('password').notEmpty().withMessage('Password required'),
];

const validateSendOTP = [
  body('target').notEmpty().withMessage('Phone number or email required'),
  body('type').isIn(['sms', 'email']).withMessage('Type must be sms or email'),
  body('purpose').isIn(['register', 'login', 'reset_password']).withMessage('Invalid purpose'),
];

const validateVerifyOTP = [
  body('target').notEmpty().withMessage('Phone number or email required'),
  body('otpCode').isLength({ min: 6, max: 6 }).isNumeric().withMessage('OTP must be 6 digits'),
  body('purpose').isIn(['register', 'login', 'reset_password']).withMessage('Invalid purpose'),
];

const validateResetPassword = [
  body('email').isEmail().normalizeEmail().withMessage('Valid email required'),
  body('otpCode').isLength({ min: 6, max: 6 }).isNumeric().withMessage('OTP must be 6 digits'),
  body('newPassword')
    .isLength({ min: 8 }).withMessage('Password must be at least 8 characters')
    .matches(/[A-Z]/).withMessage('Password must contain an uppercase letter')
    .matches(/[0-9]/).withMessage('Password must contain a number'),
];

const validateProfile = [
  body('name').optional().isString().isLength({ max: 100 }),
  body('gender').optional().isIn(['Nữ', 'Nam', 'Khác', '']),
  body('dateOfBirth').optional().isISO8601().toDate(),
];

module.exports = {
  validateRegister, validateLogin, validateSendOTP,
  validateVerifyOTP, validateResetPassword, validateProfile,
};
