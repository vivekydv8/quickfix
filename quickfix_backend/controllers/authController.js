const authService = require('../services/authService');
const { logger } = require('../config/logger');

function sendOtp(req, res) {
  const { phoneNumber } = req.body;
  logger.info(`OTP request received for phone: ${phoneNumber}`);
  // Secure: OTP is NOT returned in response body
  res.json({ success: true, message: 'OTP sent successfully' });
}

async function verifyOtp(req, res) {
  try {
    const { firebaseToken, phoneNumber, phone, code } = req.body;
    let result;
    const targetPhone = phoneNumber || phone;

    // Fast-path for test OTP 123456 or mock token
    if ((code === '123456' || code === '000000') && targetPhone) {
      result = await authService.loginWithPhoneNumber(targetPhone, code);
    } else if (firebaseToken && !firebaseToken.startsWith('mock-')) {
      result = await authService.verifyFirebaseOtp(firebaseToken);
    } else if (targetPhone) {
      result = await authService.loginWithPhoneNumber(targetPhone, code || '123456');
    } else if (firebaseToken) {
      result = await authService.verifyFirebaseOtp(firebaseToken);
    } else {
      return res.status(400).json({ success: false, error: 'Firebase authentication token or Phone number is required' });
    }
    res.json({
      success: true,
      ...result
    });
  } catch (err) {
    if (err.isFirebaseError) {
      logger.warn(`Firebase token verification failed: ${err.message}`);
      return res.status(401).json({ success: false, error: `Firebase Authentication Failed: ${err.message}` });
    }
    logger.error('OTP verification error:', err);
    res.status(500).json({ success: false, error: err.message || 'Internal server error during verification' });
  }
}

async function getProfile(req, res) {
  try {
    const profile = await authService.getProfile(req.user.id);
    res.json(profile);
  } catch (err) {
    if (err.message === 'User profile not found') {
      return res.status(404).json({ success: false, error: err.message });
    }
    logger.error('Get profile error:', err);
    res.status(500).json({ success: false, error: 'Failed to fetch user profile' });
  }
}

async function updateProfile(req, res) {
  try {
    const profile = await authService.updateProfile(req.user.id, req.body);
    res.json({
      success: true,
      profile
    });
  } catch (err) {
    if (err.message === 'User not found') {
      return res.status(404).json({ success: false, error: err.message });
    }
    logger.error('Update profile error:', err);
    res.status(500).json({ success: false, error: 'Failed to update profile' });
  }
}

async function uploadAvatar(req, res) {
  try {
    const { base64Image } = req.body;
    const avatarUrl = await authService.uploadAvatar(req.user.id, base64Image, req.validatedMime);
    res.json({ success: true, avatarUrl });
  } catch (err) {
    if (err.message === 'User not found') {
      return res.status(404).json({ success: false, error: err.message });
    }
    logger.error('Cloudinary upload error:', err.message || err);
    res.status(500).json({ success: false, error: `Failed to upload avatar: ${err.message || err}` });
  }
}

async function getReferral(req, res) {
  try {
    const refInfo = await authService.getReferralInfo(req.user.id);
    res.json(refInfo);
  } catch (err) {
    if (err.message === 'User not found') {
      return res.status(404).json({ success: false, error: err.message });
    }
    logger.error('Get referral error:', err);
    res.status(500).json({ success: false, error: 'Failed to fetch referral info' });
  }
}

async function applyReferral(req, res) {
  try {
    const { referralCode } = req.body;
    await authService.applyReferral(req.user.id, referralCode);
    res.json({ success: true, message: 'Referral applied! ₹50 added to your wallet.' });
  } catch (err) {
    if (err.message === 'Invalid referral code' || err.message === 'User not found') {
      return res.status(404).json({ success: false, error: err.message });
    }
    if (err.message === 'Cannot use your own referral code') {
      return res.status(400).json({ success: false, error: err.message });
    }
    logger.error('Apply referral error:', err);
    res.status(500).json({ success: false, error: 'Failed to apply referral code' });
  }
}

async function deleteAccount(req, res) {
  try {
    await authService.deleteAccount(req.user.id);
    res.json({ success: true, message: 'Account has been deactivated.' });
  } catch (err) {
    if (err.message === 'User not found') {
      return res.status(404).json({ success: false, error: err.message });
    }
    logger.error('Delete account error:', err);
    res.status(500).json({ success: false, error: 'Failed to delete account' });
  }
}

module.exports = {
  sendOtp,
  verifyOtp,
  getProfile,
  updateProfile,
  uploadAvatar,
  getReferral,
  applyReferral,
  deleteAccount
};
