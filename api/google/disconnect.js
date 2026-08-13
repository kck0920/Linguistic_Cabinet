const { serializeCookie } = require('../_utils/cookie');

module.exports = async (req, res) => {
  res.setHeader('Access-Control-Allow-Origin', req.headers.origin || '*');
  res.setHeader('Access-Control-Allow-Credentials', 'true');
  res.setHeader('Access-Control-Allow-Methods', 'POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');

  if (req.method === 'OPTIONS') {
    return res.status(200).end();
  }

  const isProduction = process.env.NODE_ENV === 'production' || process.env.VERCEL === '1';
  const clearCookieStr = serializeCookie('voca_session', '', {
    httpOnly: true,
    secure: isProduction,
    sameSite: 'Lax',
    path: '/',
    maxAge: 0,
  });

  res.setHeader('Set-Cookie', clearCookieStr);
  return res.status(200).json({ success: true, message: 'Disconnected' });
};
