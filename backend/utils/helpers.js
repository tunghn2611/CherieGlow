// utils/helpers.js — Shared utility functions
const { v4: uuidv4 } = require('uuid');

/** Generate a random 6-digit OTP code */
const generateOTP = () => {
  return String(Math.floor(100000 + Math.random() * 900000));
};

/** Generate a UUID v4 */
const generateUUID = () => uuidv4();

/** Standard API response format */
const formatResponse = (success, message, data = null) => {
  const response = { success, message };
  if (data !== null) response.data = data;
  return response;
};

/** Parse a MySQL DATE to YYYY-MM-DD string */
const toDateString = (date) => {
  if (!date) return null;
  if (date instanceof Date) return date.toISOString().split('T')[0];
  return String(date).split('T')[0];
};

module.exports = { generateOTP, generateUUID, formatResponse, toDateString };
