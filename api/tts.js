const https = require('https');

function fetchPollyUrl(text, speaker) {
  const postData = 'msg=' + encodeURIComponent(text) + '&lang=' + encodeURIComponent(speaker) + '&source=ttsmp3';
  return new Promise((resolve, reject) => {
    const req = https.request('https://ttsmp3.com/makemp3_new.php', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
        'Content-Length': Buffer.byteLength(postData),
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)'
      },
      timeout: 5000
    }, (res) => {
      let data = '';
      res.on('data', chunk => data += chunk);
      res.on('end', () => {
        try {
          const json = JSON.parse(data);
          if (json.Error === 0 && json.URL) {
            resolve(json.URL);
          } else {
            reject(new Error(json.message || 'TTS generation failed'));
          }
        } catch (e) {
          reject(e);
        }
      });
    });

    req.on('error', reject);
    req.on('timeout', () => {
      req.destroy();
      reject(new Error('Request timeout'));
    });
    req.write(postData);
    req.end();
  });
}

module.exports = async (req, res) => {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');

  if (req.method === 'OPTIONS') {
    return res.status(200).end();
  }

  const { text, gender } = req.query;
  const clean = (text || '').trim();

  if (!clean) {
    return res.status(400).json({ error: 'Text parameter is required' });
  }

  const isMale = (gender || '').toLowerCase() === 'male';
  // 미국 네이티브 최고급 원어민 음성: 남성 Matthew, 여성 Joanna
  const speaker = isMale ? 'Matthew' : 'Joanna';

  try {
    const audioUrl = await fetchPollyUrl(clean, speaker);
    res.setHeader('Cache-Control', 'public, max-age=86400');
    return res.redirect(302, audioUrl);
  } catch (err) {
    if (!isMale) {
      const fallbackUrl = `https://translate.google.com/translate_tts?ie=UTF-8&tl=en-US&client=tw-ob&q=${encodeURIComponent(clean)}`;
      return res.redirect(302, fallbackUrl);
    } else {
      if (!clean.includes(' ')) {
        const fallbackUrl = `https://dict.youdao.com/dictvoice?audio=${encodeURIComponent(clean)}&type=1`;
        return res.redirect(302, fallbackUrl);
      }
      return res.status(502).json({ error: 'TTS provider unavailable' });
    }
  }
};
