const { encrypt, decrypt } = require('../_utils/crypto');
const { parseCookies, serializeCookie } = require('../_utils/cookie');

const CLIENT_ID = process.env.GOOGLE_CLIENT_ID || '1002909356316-llhqdfguevm9je83uhtdqblgm5621ra1.apps.googleusercontent.com';
const CLIENT_SECRET = process.env.GOOGLE_CLIENT_SECRET || '';

// ALLOWED_ORIGINS 환경변수(쉼표 구분)가 설정되면 해당 origin만 허용하고,
// 없으면 기존처럼 요청 origin을 반사한다 (credentials 사용을 위해 '*' 대신 반사).
const ALLOWED_ORIGINS = (process.env.ALLOWED_ORIGINS || '')
  .split(',')
  .map((s) => s.trim())
  .filter(Boolean);

module.exports = async (req, res) => {
  const origin = req.headers.origin || '';
  if (ALLOWED_ORIGINS.length > 0 && origin && !ALLOWED_ORIGINS.includes(origin)) {
    return res.status(403).json({ error: 'forbidden', error_description: 'Origin not allowed' });
  }
  res.setHeader('Access-Control-Allow-Origin', origin || '*');
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
    const cookies = parseCookies(req);
    const { encrypted_refresh_token: bodyToken } = typeof req.body === 'string' ? JSON.parse(req.body) : (req.body || {});

    // 1차: Request Body (PWA/iOS Safari ITP에 가장 안전), 2차: HttpOnly Cookie
    const encryptedToken = bodyToken || cookies.voca_session;

    if (!encryptedToken) {
      return res.status(401).json({ error: 'unauthorized', error_description: 'No session cookie or token provided' });
    }

    const refreshToken = decrypt(encryptedToken);
    if (!refreshToken) {
      return res.status(401).json({ error: 'invalid_grant', error_description: 'Failed to decrypt refresh token' });
    }

    const params = new URLSearchParams({
      refresh_token: refreshToken,
      client_id: CLIENT_ID,
      client_secret: CLIENT_SECRET,
      grant_type: 'refresh_token',
    });

    const tokenRes = await fetch('https://oauth2.googleapis.com/token', {
      method: 'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      body: params.toString(),
    });

    const tokenData = await tokenRes.json();

    if (!tokenRes.ok || tokenData.error) {
      console.error('Google token refresh error:', tokenData);
      return res.status(401).json({
        error: tokenData.error || 'invalid_grant',
        error_description: tokenData.error_description || 'Failed to refresh token',
      });
    }

    const { access_token, refresh_token: newRawRefreshToken, expires_in } = tokenData;

    let responseEncryptedToken = encryptedToken;
    if (newRawRefreshToken) {
      const newlyEncrypted = encrypt(newRawRefreshToken);
      if (newlyEncrypted) {
        responseEncryptedToken = newlyEncrypted;
        const isProduction = process.env.NODE_ENV === 'production' || process.env.VERCEL === '1';
        const cookieStr = serializeCookie('voca_session', newlyEncrypted, {
          httpOnly: true,
          secure: isProduction,
          sameSite: 'Lax',
          path: '/',
          maxAge: 365 * 24 * 60 * 60, // 1년
        });
        res.setHeader('Set-Cookie', cookieStr);
      }
    }

    return res.status(200).json({
      access_token,
      expires_in: expires_in || 3600,
      encrypted_refresh_token: responseEncryptedToken,
    });
  } catch (err) {
    console.error('API /token error:', err);
    return res.status(500).json({ error: 'Internal server error', details: err.message });
  }
};
