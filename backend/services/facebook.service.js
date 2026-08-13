// services/facebook.service.js — Facebook token verification via Graph API
const axios = require('axios');

const FacebookService = {
  /**
   * Verify a Facebook access token by calling the Graph API.
   * @param {string} accessToken - The access token from Facebook Login SDK
   * @returns {{ id, name, email, picture }}
   */
  async verifyToken(accessToken) {
    try {
      const response = await axios.get('https://graph.facebook.com/me', {
        params: {
          fields: 'id,name,email,picture.width(200).height(200)',
          access_token: accessToken,
        },
      });
      const { id, name, email, picture } = response.data;
      return {
        id,
        name: name || '',
        email: email || '',
        picture: picture?.data?.url || '',
      };
    } catch (err) {
      console.error('❌ [FACEBOOK] Token verification failed:', err.response?.data || err.message);
      throw new Error('Invalid Facebook access token');
    }
  },
};

module.exports = FacebookService;
