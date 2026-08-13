const crypto = require('crypto');

// 환경변수 ENCRYPTION_KEY가 지정되어 있지 않으면 fallback secret 사용
const SECRET = process.env.ENCRYPTION_KEY || process.env.GOOGLE_CLIENT_SECRET || 'vocatree_google_oauth_secret_key_2026';

function getDerivedKey() {
  return crypto.createHash('sha256').update(SECRET).digest();
}

function encrypt(text) {
  if (!text) return null;
  const iv = crypto.randomBytes(12);
  const key = getDerivedKey();
  const cipher = crypto.createCipheriv('aes-256-gcm', key, iv);
  let encrypted = cipher.update(text, 'utf8', 'base64');
  encrypted += cipher.final('base64');
  const authTag = cipher.getAuthTag().toString('base64');
  return `${iv.toString('base64')}:${authTag}:${encrypted}`;
}

function decrypt(encryptedText) {
  if (!encryptedText) return null;
  try {
    const parts = encryptedText.split(':');
    if (parts.length !== 3) return null;
    const iv = Buffer.from(parts[0], 'base64');
    const authTag = Buffer.from(parts[1], 'base64');
    const encrypted = parts[2];
    const key = getDerivedKey();
    const decipher = crypto.createDecipheriv('aes-256-gcm', key, iv);
    decipher.setAuthTag(authTag);
    let decrypted = decipher.update(encrypted, 'base64', 'utf8');
    decrypted += decipher.final('utf8');
    return decrypted;
  } catch (err) {
    console.error('Decryption error:', err);
    return null;
  }
}

module.exports = { encrypt, decrypt };
