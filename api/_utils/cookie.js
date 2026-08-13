function parseCookies(req) {
  const list = {};
  const rc = req.headers.cookie;

  if (rc) {
    rc.split(';').forEach((cookie) => {
      const parts = cookie.split('=');
      const name = parts.shift().trim();
      const value = decodeURIComponent(parts.join('='));
      if (name) list[name] = value;
    });
  }

  return list;
}

function serializeCookie(name, val, options = {}) {
  let cookie = `${encodeURIComponent(name)}=${encodeURIComponent(val)}`;

  if (options.maxAge != null) {
    cookie += `; Max-Age=${options.maxAge}`;
  }
  if (options.domain) {
    cookie += `; Domain=${options.domain}`;
  }
  if (options.path) {
    cookie += `; Path=${options.path}`;
  } else {
    cookie += `; Path=/`;
  }
  if (options.expires) {
    cookie += `; Expires=${options.expires.toUTCString()}`;
  }
  if (options.httpOnly) {
    cookie += `; HttpOnly`;
  }
  if (options.secure) {
    cookie += `; Secure`;
  }
  if (options.sameSite) {
    cookie += `; SameSite=${options.sameSite}`;
  }

  return cookie;
}

module.exports = { parseCookies, serializeCookie };
