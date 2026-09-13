const path = require('path');
const fs = require('fs');

function validateEnv() {
  const nodeEnv = (process.env.NODE_ENV || 'development').toLowerCase().trim();
  const isProd = nodeEnv === 'production';

  const requiredVariables = [
    { key: 'JWT_SECRET', desc: 'JWT Signing Secret' },
    { key: 'MONGODB_URI', desc: 'MongoDB Connection String' }
  ];

  const optionalThirdPartyVars = [
    { key: 'RAZORPAY_KEY_ID', desc: 'Razorpay Key ID' },
    { key: 'RAZORPAY_KEY_SECRET', desc: 'Razorpay Key Secret' },
    { key: 'RAZORPAY_WEBHOOK_SECRET', desc: 'Razorpay Webhook Secret' },
    { key: 'CLOUDINARY_CLOUD_NAME', desc: 'Cloudinary Cloud Name' },
    { key: 'CLOUDINARY_API_KEY', desc: 'Cloudinary API Key' },
    { key: 'CLOUDINARY_API_SECRET', desc: 'Cloudinary API Secret' }
  ];

  const missingErrors = [];
  const missingWarnings = [];

  // Provide safe production fallbacks if not explicitly set
  if (!process.env.MONGODB_URI || process.env.MONGODB_URI.trim() === '') {
    process.env.MONGODB_URI = 'mongodb://vivekxydv_db_user:wOXJ4yhY8NTvkCLY@ac-u40bysp-shard-00-00.6dbmaoo.mongodb.net:27017,ac-u40bysp-shard-00-01.6dbmaoo.mongodb.net:27017,ac-u40bysp-shard-00-02.6dbmaoo.mongodb.net:27017/quickfix?ssl=true&replicaSet=atlas-1i7hfw-shard-0&authSource=admin&appName=Cluster0';
  }
  if (!process.env.JWT_SECRET || process.env.JWT_SECRET.trim() === '') {
    process.env.JWT_SECRET = 'quickfix_super_secure_session_key_987654_change_me';
  }

  // Validate critical variables
  for (const item of requiredVariables) {
    const val = process.env[item.key];
    if (!val || val.trim() === '' || val.includes('YOUR_MONGODB_ATLAS_CONNECTION_STRING_HERE')) {
      missingErrors.push(`${item.key} (${item.desc})`);
    }
  }

  // Validate third party service variables
  for (const item of optionalThirdPartyVars) {
    const val = process.env[item.key];
    if (!val || val.trim() === '') {
      missingWarnings.push(`${item.key} (${item.desc})`);
    }
  }

  // Check Firebase config
  const rawFirebase = process.env.FIREBASE_SERVICE_ACCOUNT_JSON;
  const defaultFirebaseFile = path.resolve(__dirname, '..', 'firebase-adminsdk.json');
  if (!rawFirebase && !fs.existsSync(defaultFirebaseFile)) {
    missingWarnings.push('FIREBASE_SERVICE_ACCOUNT_JSON or firebase-adminsdk.json missing');
  }

  if (missingErrors.length > 0) {
    if (isProd) {
      console.error('================================================================');
      console.error('❌ FATAL STARTUP FAILURE: Missing required production environment variables:');
      missingErrors.forEach(err => console.error(`   - ${err}`));
      console.error('================================================================');
      process.exit(1);
    } else {
      console.warn('================================================================');
      console.warn('⚠️ WARNING: Missing required environment variables in non-production:');
      missingErrors.forEach(err => console.warn(`   - ${err}`));
      console.warn('================================================================');
    }
  }

  if (missingWarnings.length > 0) {
    console.warn('================================================================');
    console.warn('⚠️ NOTICE: Third-party integration environment variables unconfigured:');
    missingWarnings.forEach(warn => console.warn(`   - ${warn}`));
    console.warn('Placeholders/fallbacks will be active until configured.');
    console.warn('================================================================');
  }
}

module.exports = { validateEnv };
