// services/apple.service.js — Apple Sign-In OAuth2 token verification
const AppleService = {
  /**
   * Verify an Apple identity token.
   * Uses apple-signin-auth to validate the JWT from Apple.
   * @param {string} identityToken - The JWT identity token from ASAuthorizationController
   * @returns {{ sub: string, email: string, email_verified: boolean }}
   */
  async verifyToken(identityToken) {
    try {
      const appleSignin = require('apple-signin-auth');
      const payload = await appleSignin.verifyIdToken(identityToken, {
        audience: process.env.APPLE_CLIENT_ID || 'com.arceus.MenstrualCycle',
        ignoreExpiration: false,
      });
      return {
        sub: payload.sub,          // Apple user ID (unique, stable)
        email: payload.email || '',
        emailVerified: payload.email_verified === 'true' || payload.email_verified === true,
      };
    } catch (err) {
      console.error('❌ [APPLE] Token verification failed:', err.message);
      throw new Error('Invalid Apple identity token');
    }
  },
};

module.exports = AppleService;
