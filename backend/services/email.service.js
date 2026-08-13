// services/email.service.js — Nodemailer SMTP for Email OTP
const nodemailer = require('nodemailer');

let transporter = null;

function getTransporter() {
  if (transporter) return transporter;
  const { SMTP_HOST, SMTP_PORT, SMTP_USER, SMTP_PASS } = process.env;
  if (!SMTP_USER || !SMTP_PASS) return null;

  transporter = nodemailer.createTransport({
    host: SMTP_HOST || 'smtp.gmail.com',
    port: parseInt(SMTP_PORT || '587'),
    secure: false,
    auth: { user: SMTP_USER, pass: SMTP_PASS },
  });
  return transporter;
}

const otpEmailTemplate = (otpCode) => `
<!DOCTYPE html>
<html>
<head><meta charset="utf-8"></head>
<body style="font-family:'Segoe UI',sans-serif;background:#fdf2f8;padding:40px;">
  <div style="max-width:480px;margin:0 auto;background:#fff;border-radius:16px;padding:40px;box-shadow:0 4px 20px rgba(0,0,0,0.08);">
    <div style="text-align:center;margin-bottom:24px;">
      <span style="font-size:48px;">🌸</span>
      <h2 style="color:#d4507a;margin:12px 0 4px;">MenstrualCycle</h2>
      <p style="color:#888;font-size:14px;">Mã xác thực tài khoản</p>
    </div>
    <div style="text-align:center;background:linear-gradient(135deg,#fce4ec,#f8bbd0);border-radius:12px;padding:24px;margin:20px 0;">
      <p style="color:#555;margin:0 0 8px;font-size:14px;">Mã OTP của bạn là:</p>
      <h1 style="letter-spacing:12px;font-size:36px;color:#c2185b;margin:0;">${otpCode}</h1>
    </div>
    <p style="color:#666;font-size:13px;text-align:center;">Mã có hiệu lực trong <strong>5 phút</strong>. Không chia sẻ mã này với bất kỳ ai.</p>
    <hr style="border:none;border-top:1px solid #f0e0e8;margin:24px 0;">
    <p style="color:#aaa;font-size:11px;text-align:center;">© 2026 MenstrualCycle App</p>
  </div>
</body>
</html>`;

const EmailService = {
  async sendOTPEmail(email, otpCode) {
    const t = getTransporter();
    if (!t) {
      console.log(`📧 [EMAIL FALLBACK] OTP for ${email}: ${otpCode}`);
      console.log('⚠️  SMTP not configured. Set SMTP_* env vars for real email.');
      return { success: true, fallback: true };
    }
    try {
      const info = await t.sendMail({
        from: process.env.SMTP_FROM || process.env.SMTP_USER,
        to: email,
        subject: '🌸 MenstrualCycle — Mã xác thực OTP',
        html: otpEmailTemplate(otpCode),
      });
      console.log(`✅ [EMAIL] Sent OTP to ${email}, ID: ${info.messageId}`);
      return { success: true, messageId: info.messageId };
    } catch (err) {
      console.error(`❌ [EMAIL] Failed to send to ${email}:`, err.message);
      throw new Error('Failed to send email OTP');
    }
  },

  async sendPasswordResetEmail(email, otpCode) {
    return this.sendOTPEmail(email, otpCode); // Same template
  },
};

module.exports = EmailService;
