const { encrypt } = require('../_utils/crypto');
const { serializeCookie } = require('../_utils/cookie');

const CLIENT_ID = process.env.GOOGLE_CLIENT_ID || '1002909356316-llhqdfguevm9je83uhtdqblgm5621ra1.apps.googleusercontent.com';
const CLIENT_SECRET = process.env.GOOGLE_CLIENT_SECRET || '';

module.exports = async (req, res) => {
  res.setHeader('Access-Control-Allow-Origin', req.headers.origin || '*');
  res.setHeader('Access-Control-Allow-Credentials', 'true');
  res.setHeader('Access-Control-Allow-Methods', 'POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');

  if (req.method === 'OPTIONS') {
    return res.status(200).end();
  }

  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

  try {
    const { code } = typeof req.body === 'string' ? JSON.parse(req.body) : (req.body || {});
    if (!code) {
      return res.status(400).json({ error: 'Authorization code is required' });
    }

    const params = new URLSearchParams({
      code,
      client_id: CLIENT_ID,
      client_secret: CLIENT_SECRET,
      redirect_uri: 'postmessage', // GIS Popup mode 필수
      grant_type: 'authorization_code',
    });

    const tokenRes = await fetch('https://oauth2.googleapis.com/token', {
      method: 'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      body: params.toString(),
    });

    const tokenData = await tokenRes.json();

    if (!tokenRes.ok || tokenData.error) {
      console.error('Google token exchange error:', tokenData);
      return res.status(tokenRes.status || 400).json({
        error: tokenData.error || 'Failed to exchange authorization code',
        error_description: tokenData.error_description,
      });
    }

    const { access_token, refresh_token, expires_in } = tokenData;

    // 사용자 정보 가져오기
    let userInfo = null;
    try {
      const userRes = await fetch('https://www.googleapis.com/oauth2/v2/userinfo', {
        headers: { Authorization: `Bearer ${access_token}` },
      });
      if (userRes.ok) {
        userInfo = await userRes.json();
      }
    } catch (userErr) {
      console.error('Failed to fetch user info:', userErr);
    }

    // refresh_token이 수신되었는지 확인
    const encryptedRefreshToken = encrypt(refresh_token);

    if (encryptedRefreshToken) {
      // 1년 유효 HttpOnly Cookie 심기 (SameSite=Lax, Secure)
      const isProduction = process.env.NODE_ENV === 'production' || process.env.VERCEL === '1';
      const cookieStr = serializeCookie('voca_session', encryptedRefreshToken, {
        httpOnly: true,
        secure: isProduction,
        sameSite: 'Lax',
        path: '/',
        maxAge: 365 * 24 * 60 * 60, // 1년
      });
      res.setHeader('Set-Cookie', cookieStr);
    }

    return res.status(200).json({
      access_token,
      expires_in: expires_in || 3600,
      encrypted_refresh_token: encryptedRefreshToken,
      user: userInfo ? {
        id: userInfo.id,
        email: userInfo.email,
        name: userInfo.name,
        picture: userInfo.picture,
      } : null,
    });
  } catch (err) {
    console.error('API /connect error:', err);
    return res.status(500).json({ error: 'Internal server error', details: err.message });
  }
};
