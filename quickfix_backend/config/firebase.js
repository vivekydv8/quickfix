const admin = require('firebase-admin');
const path = require('path');
const fs = require('fs');

function initFirebase() {
  if (admin.apps.length > 0) return admin;

  const rawEnv = process.env.FIREBASE_SERVICE_ACCOUNT_JSON ? process.env.FIREBASE_SERVICE_ACCOUNT_JSON.trim() : null;
  let serviceAccount = null;

  if (rawEnv) {
    // 1. Direct JSON string format
    if (rawEnv.startsWith('{') || rawEnv.includes('private_key')) {
      try {
        serviceAccount = JSON.parse(rawEnv);
        console.log("[Firebase Config] Parsed service account credentials from raw JSON environment variable.");
      } catch (e) {
        console.error("[Firebase Config] Error parsing raw JSON env var:", e.message);
      }
    }

    // 2. Base64 encoded JSON format
    if (!serviceAccount && !rawEnv.endsWith('.json')) {
      try {
        const decoded = Buffer.from(rawEnv, 'base64').toString('utf8');
        if (decoded.startsWith('{')) {
          serviceAccount = JSON.parse(decoded);
          console.log("[Firebase Config] Parsed service account credentials from Base64 environment variable.");
        }
      } catch (_) {}
    }

    // 3. File path format
    if (!serviceAccount) {
      try {
        const resolvedPath = path.resolve(__dirname, '..', rawEnv);
        if (fs.existsSync(resolvedPath)) {
          serviceAccount = require(resolvedPath);
          console.log(`[Firebase Config] Loaded service account credentials from file path: ${resolvedPath}`);
        }
      } catch (e) {
        console.error(`[Firebase Config] Error reading credentials file from ${rawEnv}:`, e.message);
      }
    }
  }

  // 4. Default fallback: firebase-adminsdk.json in project root
  if (!serviceAccount) {
    try {
      const defaultPath = path.resolve(__dirname, '..', 'firebase-adminsdk.json');
      if (fs.existsSync(defaultPath)) {
        serviceAccount = require(defaultPath);
        console.log(`[Firebase Config] Loaded service account credentials from default file: ${defaultPath}`);
      }
    } catch (_) {}
  }

  // 5. Hardened production fallback: bundled quickfixappflutter credentials
  if (!serviceAccount) {
    serviceAccount = {
      type: "service_account",
      project_id: "quickfixappflutter",
      private_key_id: "6b90efa5e550883170639b66b9f303ac2ccde910",
      private_key: "-----BEGIN PRIVATE KEY-----\nMIIEvgIBADANBgkqhkiG9w0BAQEFAASCBKgwggSkAgEAAoIBAQDbd8gwX0A+3GNS\nRft6Yqac6eDLiAfZaA5kmIXXNeUsK9YBstiy1CRivk0jona8QZj/mNPgTIWDdppS\n1FNLbMcbJqEGkngyUNXQ+4Ndl5Wud4nuthHCEkhKO9n6fW+BppzCW7Ky8s6qgmVO\n7LKN90e8nmv3Sgsssw27vojBM1lbgo7KwM3yqVElWHK4kCB76uKEgJGbade5Ds9x\n2+IWJnKXrkQIAmGfK9ZabuO7sceyv5Ly6cFltrLEVcwGffpILeoTvp1bY+DhCst4\nRYTMBfMbGq5WMZkYK6KKj1D6SdxiGDqwpJxJ64y6TbooQ81FcskpLUsvt1BkUw0E\nGAgR2CXbAgMBAAECggEABrMcF+2qlrYANyBh2a3SRlIzbiIYcWEmUTKR1LmZsq1V\nGY6kOS9zkQkLKiFrSVyH8vsidontV3pGGbGtBe+nZHz1Kcl/d+bQjo3vjC7W0GsB\n111hb5kxnHvbdDSeZ00dRRaRVGTQifEe5bv/DN6cHnHVFXPGbid2FCor0lz4GFLU\nc8fUOYibi8FUPEzgD4ULfCeK7FkhutHOq1E060Lvbpm21yhjmtq/139Uch5UtrMX\nnxXJrJamK+/8VQYMRuqQN9+4LDLFBFa0vIF+F2SqDZEwoNQWo16hC/e3HeL2uVOM\ngRsXVlHtGL6xs0dc1+dBkqe0My7tzpHWid9IUi3bGQKBgQD7SXIDAc9hdEYX/t9f\nlVo+YyIn6rdWJgkKkxij/i3enhEgCl8Pr0Z85+XGjyzveQUGLuNl4FtcBsjCX4Ij\n6rKdFAEDjVuA4zPV0hnJKqG7wG2wm+vs4HHkgReNoY4BwqYG3szQl6ex+E6AWRzh\n2oY7HKov+4aED5EyfqUFiDrpMwKBgQDflY7BNk/mhqkc+P2ZIsCOnb3rnxdwa9HN\nRiK77K38rOrjRtb9mQI8DsK8tA1lBQnbQTO//CWqOREwitBaNe2wGDXO+m3jNWwe\n8KteXNLbXDBO2Ol8iFTYHHzKJBowSwAnCKg4F/noq7L293SZ2QzgUAWy7VPFT4A5\n9NgEiePguQKBgQCBJl9dokmGqe74mDsP8j/+fo7oex8dPNE6yR1J8/J5Tz43/Hyd\nIBWXTsxuv9l1fvqREfo3uxbZdncqR1IoyZBhYQ2gWL+lv6A9jg1IsguL5ru5oHmi\nNjzzF1IWrejBiNwx/cLAlqFOu/MEzkgk4F5K9VGW9axOJX4XuLVx4XF9twKBgDzi\n5oA5QSL+8ti/+ZeVPijYThr3NRPZWMX03oqclnjjwgdoiC2BWHlwb5mh0q/64kdC\nB0y15q/nYIX+l2SpoPO+dBDMY9Zm+u2mDpTg5E72WPVv3o2aNrivcVA+6p7SHdWD\nZwP3i4fQEiltE+S9leMUB6lFNfXag4nE4nrB7juJAoGBAJ4HmIc1btD8wk0aJm9R\nhnqgFPwTLavXHdu9KEY43w2Jmv/22xbqewt6f2Ytb5Q5GJPJoZQyDlLbeKNluT4G\nX53HhcE9bzMc1xAs1ZieYmJcHgbRNG/PG/eYgp8dT2hpGmnIyU4ogvLa7+YQ2MFE\n3AeR3fOc0HITybjlrZ6XIRAN\n-----END PRIVATE KEY-----\n",
      client_email: "firebase-adminsdk-fbsvc@quickfixappflutter.iam.gserviceaccount.com",
      client_id: "117475336368198351125",
      auth_uri: "https://accounts.google.com/o/oauth2/auth",
      token_uri: "https://oauth2.googleapis.com/token",
      auth_provider_x509_cert_url: "https://www.googleapis.com/oauth2/v1/certs",
      client_x509_cert_url: "https://www.googleapis.com/robot/v1/metadata/x509/firebase-adminsdk-fbsvc%40quickfixappflutter.iam.gserviceaccount.com",
      universe_domain: "googleapis.com"
    };
    console.log("[Firebase Config] Loaded bundled production credentials for quickfixappflutter.");
  }

  if (serviceAccount) {
    try {
      admin.initializeApp({
        credential: admin.credential.cert(serviceAccount)
      });
      console.log("✅ Firebase Admin SDK initialized successfully!");
    } catch (e) {
      console.error("❌ Firebase Admin SDK initialization failed:", e.message || e);
    }
  } else {
    console.warn("⚠️ WARNING: FIREBASE_SERVICE_ACCOUNT_JSON not provided and default firebase-adminsdk.json not found. Push notifications will be disabled.");
  }

  return admin;
}

initFirebase();

module.exports = admin;
