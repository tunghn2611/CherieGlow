// services/otp.service.js — Twilio SMS OTP
const OTPService = {
  /**
   * Send SMS OTP via Twilio.
   * Falls back to console.log if Twilio is not configured.
   */
  async sendSMS(phoneNumber, otpCode) {
    const { TWILIO_ACCOUNT_SID, TWILIO_AUTH_TOKEN, TWILIO_PHONE_NUMBER } = process.env;

    if (!TWILIO_ACCOUNT_SID || !TWILIO_AUTH_TOKEN || !TWILIO_PHONE_NUMBER) {
      console.log(`📱 [SMS FALLBACK] OTP for ${phoneNumber}: ${otpCode}`);
      console.log('⚠️  Twilio not configured. Set TWILIO_* env vars for real SMS.');
      return { success: true, fallback: true };
    }

    try {
      const twilio = require('twilio')(TWILIO_ACCOUNT_SID, TWILIO_AUTH_TOKEN);
      const message = await twilio.messages.create({
        body: `[MenstrualCycle] Mã xác thực OTP của bạn là: ${otpCode}. Mã có hiệu lực trong 5 phút. Không chia sẻ mã này.`,
        from: TWILIO_PHONE_NUMBER,
        to: phoneNumber,
      });
      console.log(`✅ [SMS] Sent OTP to ${phoneNumber}, SID: ${message.sid}`);
      return { success: true, sid: message.sid };
    } catch (err) {
      console.error(`❌ [SMS] Failed to send to ${phoneNumber}:`, err.message);
      throw new Error('Failed to send SMS OTP');
    }
  },
};

module.exports = OTPService;
