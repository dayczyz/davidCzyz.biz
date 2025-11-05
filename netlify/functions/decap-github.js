// netlify/functions/decap-github.js
// Minimal GitHub OAuth bridge for Decap CMS.
// Requires env vars: OAUTH_CLIENT_ID, OAUTH_CLIENT_SECRET
// Routes:
//   /.netlify/functions/decap-github/auth       -> redirect to GitHub
//   /.netlify/functions/decap-github/callback   -> exchange code for token

const querystring = require("querystring");

const GH_AUTHORIZE_URL = "https://github.com/login/oauth/authorize";
const GH_TOKEN_URL = "https://github.com/login/oauth/access_token";

exports.handler = async (event) => {
  const { path, queryStringParameters } = event;
  const host = event.headers["x-forwarded-host"] || event.headers.host;
  const proto = (event.headers["x-forwarded-proto"] || "https");
  const base = `${proto}://${host}/.netlify/functions/decap-github`;

  const clientId = process.env.OAUTH_CLIENT_ID;
  const clientSecret = process.env.OAUTH_CLIENT_SECRET;

  if (path.endsWith("/auth")) {
    // Start OAuth: redirect to GitHub
    const qs = querystring.stringify({
      client_id: clientId,
      scope: "repo",
      redirect_uri: `${base}/callback`,
      allow_signup: "false",
    });
    return {
      statusCode: 302,
      headers: { Location: `${GH_AUTHORIZE_URL}?${qs}` },
      body: "",
    };
  }

  if (path.endsWith("/callback")) {
    const code = queryStringParameters.code;
    if (!code) {
      return { statusCode: 400, body: "Missing code" };
    }

    // Exchange code for token
    const resp = await fetch(GH_TOKEN_URL, {
      method: "POST",
      headers: { "Content-Type": "application/json", "Accept": "application/json" },
      body: JSON.stringify({
        client_id: clientId,
        client_secret: clientSecret,
        code,
      }),
    });
    const json = await resp.json();
    if (!json.access_token) {
      return { statusCode: 400, body: JSON.stringify(json) };
    }

    // Return token as JSON for Decap
    return {
      statusCode: 200,
      headers: { "Content-Type": "application/json", "Cache-Control": "no-store" },
      body: JSON.stringify({ token: json.access_token }),
    };
  }

  return { statusCode: 404, body: "Not found" };
};
