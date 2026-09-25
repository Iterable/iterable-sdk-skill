// Mints an FCM-scoped access token from a service-account key, with no npm
// dependencies. Fallback for when gcloud impersonation is unavailable — which is
// also the path the real tool must use, since it cannot assume gcloud is present
// at send time.
const fs = require('fs');
const crypto = require('crypto');

const SCOPE = 'https://www.googleapis.com/auth/firebase.messaging';
const key = JSON.parse(fs.readFileSync(process.env.SA_KEY_FILE, 'utf8'));
const b64 = (o) => Buffer.from(JSON.stringify(o)).toString('base64url');

const now = Math.floor(Date.now() / 1000);
// kid is optional — Google will try every key on the account without it — but
// naming the key makes a signature failure unambiguous when more than one exists.
const claim = b64({ alg: 'RS256', typ: 'JWT', kid: key.private_key_id }) + '.' + b64({
  iss: key.client_email,
  scope: SCOPE,
  aud: key.token_uri,
  iat: now,
  exp: now + 3600,
});
const sig = crypto.createSign('RSA-SHA256').update(claim).end()
  .sign(key.private_key).toString('base64url');

fetch(key.token_uri, {
  method: 'POST',
  headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
  body: new URLSearchParams({
    grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
    assertion: `${claim}.${sig}`,
  }),
})
  .then((r) => r.json())
  .then((j) => {
    if (!j.access_token) throw new Error(j.error_description || JSON.stringify(j));
    process.stdout.write(j.access_token);
  })
  .catch((e) => {
    process.stderr.write(`error: ${e.message}`);
    process.exit(1);
  });
