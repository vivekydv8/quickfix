const jwt = require('jsonwebtoken');
const { User } = require('../models');
const admin = require('../config/firebase');
const cloudinary = require('../config/cloudinary');
const { deleteFromCloudinary } = require('../helpers');
const { logger } = require('../config/logger');

const JWT_SECRET = process.env.JWT_SECRET;

function buildProfileResponse(user) {
  return {
    id: user._id,
    name: user.name || '',
    email: user.email || '',
    phone: user.phone,
    membership: user.membership || 'basic',
    walletBalance: user.walletBalance || 0,
    avatarUrl: user.avatarUrl || '',
    savedAddresses: user.savedAddresses || [],
    walletTransactions: user.walletTransactions || [],
    gender: user.gender || '',
    dob: user.dob || '',
    alternatePhone: user.alternatePhone || '',
    emergencyContact: user.emergencyContact || '',
    preferredLanguage: user.preferredLanguage || 'English',
    isPhoneVerified: user.isPhoneVerified !== false,
    accountStatus: user.accountStatus || 'active',
    referralCode: user.referralCode || '',
    referralCount: user.referralCount || 0,
    referralRewardsEarned: user.referralRewardsEarned || 0,
    memberSince: user.memberSince || user.createdAt || new Date().toISOString(),
    fcmToken: user.fcmToken || ''
  };
}

async function verifyFirebaseOtp(firebaseToken) {
  if (!firebaseToken || typeof firebaseToken !== 'string') {
    const err = new Error("Firebase authentication token is required");
    err.isFirebaseError = true;
    throw err;
  }

  if (!admin.apps || admin.apps.length === 0) {
    const err = new Error("Firebase Admin SDK is not initialized on the server");
    err.isFirebaseError = true;
    throw err;
  }

  let decodedToken;
  try {
    decodedToken = await admin.auth().verifyIdToken(firebaseToken);
    if (!decodedToken || !decodedToken.phone_number) {
      const err = new Error("Decoded Firebase token does not contain a verified phone number.");
      err.isFirebaseError = true;
      throw err;
    }
  } catch (err) {
    err.isFirebaseError = true;
    throw err;
  }

  const phone = decodedToken.phone_number.replace('+91', '').replace(/\s+/g, '');
  
  let user = await User.findOne({ phone: phone });
  if (!user) {
    const refCode = 'QFIX' + Math.random().toString(36).substring(2, 8).toUpperCase();
    user = new User({
      phone: phone,
      name: '',
      email: '',
      membership: 'basic',
      walletBalance: 0,
      referralCode: refCode,
      isPhoneVerified: true,
      accountStatus: 'active',
      memberSince: new Date()
    });
    await user.save();
  } else if (!user.referralCode) {
    user.referralCode = 'QFIX' + Math.random().toString(36).substring(2, 8).toUpperCase();
    await user.save();
  }

  const secret = process.env.JWT_SECRET || JWT_SECRET;
  const token = jwt.sign(
    { id: user._id, phone: user.phone, role: 'customer' },
    secret,
    { expiresIn: '30d' }
  );

  return {
    token,
    profile: buildProfileResponse(user)
  };
}

async function getProfile(userId) {
  let user = null;
  try { user = await User.findById(userId); } catch (_) {}
  if (!user) user = await User.findOne({ id: userId });
  if (!user) user = await User.findOne({ _id: userId });
  if (!user) user = await User.findOne({ phone: userId });
  if (!user) {
    throw new Error('User profile not found');
  }
  return buildProfileResponse(user);
}

async function updateProfile(userId, bodyData) {
  const allowedFields = [
    'name', 'email', 'phone', 'avatarUrl', 'gender', 'dob',
    'alternatePhone', 'emergencyContact', 'preferredLanguage',
    'savedAddresses', 'fcmToken'
  ];
  const updateData = {};
  for (const field of allowedFields) {
    if (bodyData[field] !== undefined) {
      updateData[field] = bodyData[field];
    }
  }

  let user = null;
  try { user = await User.findByIdAndUpdate(userId, updateData, { new: true }); } catch (_) {}
  if (!user) {
    user = await User.findOneAndUpdate({ id: userId }, updateData, { new: true });
  }
  if (!user) {
    user = await User.findOneAndUpdate({ _id: userId }, updateData, { new: true });
  }
  if (!user) {
    user = await User.findOneAndUpdate({ phone: userId }, updateData, { new: true });
  }
  if (!user) {
    throw new Error('User not found');
  }
  return buildProfileResponse(user);
}

async function uploadAvatar(userId, base64Image, validatedMime) {
  const dataUri = `data:${validatedMime};base64,${base64Image}`;
  
  const userToUpdate = await User.findById(userId);
  if (!userToUpdate) {
    throw new Error('User not found');
  }
  const oldAvatarUrl = userToUpdate.avatarUrl;

  const uploadResponse = await cloudinary.uploader.upload(dataUri, {
    folder: 'quickfix_avatars',
    resource_type: 'image',
  });

  const avatarUrl = uploadResponse.secure_url;
  userToUpdate.avatarUrl = avatarUrl;
  await userToUpdate.save();

  if (oldAvatarUrl) {
    deleteFromCloudinary(oldAvatarUrl);
  }

  return userToUpdate.avatarUrl;
}

async function getReferralInfo(userId) {
  const user = await User.findById(userId);
  if (!user) {
    throw new Error('User not found');
  }
  if (!user.referralCode) {
    user.referralCode = 'QFIX' + Math.random().toString(36).substring(2, 8).toUpperCase();
    await user.save();
  }
  return {
    referralCode: user.referralCode,
    referralCount: user.referralCount || 0,
    referralRewardsEarned: user.referralRewardsEarned || 0,
    referralLink: `https://quickfix.app/invite/${user.referralCode}`
  };
}

async function applyReferral(userId, referralCode) {
  const referrer = await User.findOne({ referralCode: referralCode.toUpperCase() });
  if (!referrer) {
    throw new Error('Invalid referral code');
  }
  const currentUser = await User.findById(userId);
  if (!currentUser) {
    throw new Error('User not found');
  }
  if (referrer._id.toString() === currentUser._id.toString()) {
    throw new Error('Cannot use your own referral code');
  }
  
  referrer.walletBalance = (referrer.walletBalance || 0) + 100;
  referrer.referralCount = (referrer.referralCount || 0) + 1;
  referrer.referralRewardsEarned = (referrer.referralRewardsEarned || 0) + 100;
  referrer.walletTransactions = referrer.walletTransactions || [];
  referrer.walletTransactions.push({
    id: `TX-REF-${Date.now()}`,
    title: `Referral Reward from ${currentUser.phone}`,
    amount: 100,
    type: 'credit',
    date: new Date()
  });
  await referrer.save();

  currentUser.walletBalance = (currentUser.walletBalance || 0) + 50;
  currentUser.walletTransactions = currentUser.walletTransactions || [];
  currentUser.walletTransactions.push({
    id: `TX-REF-${Date.now() + 1}`,
    title: 'Referral Signup Bonus',
    amount: 50,
    type: 'credit',
    date: new Date()
  });
  await currentUser.save();
}

async function deleteAccount(userId) {
  const user = await User.findByIdAndUpdate(
    userId,
    { accountStatus: 'deleted' },
    { new: true }
  );
  if (!user) {
    throw new Error('User not found');
  }
}

module.exports = {
  buildProfileResponse,
  verifyFirebaseOtp,
  getProfile,
  updateProfile,
  uploadAvatar,
  getReferralInfo,
  applyReferral,
  deleteAccount
};
