const jwt = require('jsonwebtoken');
const bcrypt = require('bcryptjs');
const { Shop, Booking, Review } = require('../models');
const cloudinary = require('../config/cloudinary');
const { deleteFromCloudinary } = require('../helpers');

const JWT_SECRET = process.env.JWT_SECRET;

async function loginProvider(shopId, password) {
  const upperShopId = shopId.toUpperCase();
  let shop = await Shop.findOne({ shopDisplayId: upperShopId });
  if (!shop) {
    shop = await Shop.findOne({ id: shopId });
  }
  if (!shop) {
    shop = await Shop.findOne({ phone: shopId });
  }

  if (!shop) {
    const err = new Error('Invalid Shop ID or password');
    err.statusCode = 401;
    throw err;
  }

  if (shop.loginDisabled) {
    const err = new Error('Login has been disabled for this account');
    err.statusCode = 403;
    throw err;
  }

  if (shop.status === 'suspended') {
    const err = new Error('This provider account has been suspended');
    err.statusCode = 403;
    throw err;
  }

  if (shop.verificationStatus !== 'approved') {
    const err = new Error('Your account is pending admin approval');
    err.statusCode = 403;
    throw err;
  }

  let isValid = false;
  try {
    isValid = bcrypt.compareSync(password, shop.password);
  } catch (e) {
    isValid = (password === shop.password);
  }

  if (!isValid) {
    const err = new Error('Invalid Shop ID or password');
    err.statusCode = 401;
    throw err;
  }

  const token = jwt.sign(
    { id: shop._id, shopId: shop.id, phone: shop.phone, role: 'partner' },
    JWT_SECRET,
    { expiresIn: '30d' }
  );

  return { token, shop };
}

async function changePassword(userId, oldPassword, newPassword) {
  const shop = await Shop.findById(userId);
  if (!shop) {
    const err = new Error('Provider account not found');
    err.statusCode = 404;
    throw err;
  }

  let isValid = false;
  try {
    isValid = bcrypt.compareSync(oldPassword, shop.password);
  } catch (e) {
    isValid = (oldPassword === shop.password);
  }

  if (!isValid) {
    const err = new Error('Incorrect old password');
    err.statusCode = 400;
    throw err;
  }

  const salt = bcrypt.genSaltSync(10);
  shop.password = bcrypt.hashSync(newPassword, salt);
  shop.isFirstLogin = false;
  if (shop.tempPassword) shop.tempPassword = '';

  await shop.save();
}

async function updateFcmToken(userId, fcmToken) {
  let shop = null;
  try { shop = await Shop.findById(userId); } catch (_) {}
  if (!shop) shop = await Shop.findOne({ id: userId });
  if (!shop) shop = await Shop.findOne({ _id: userId });
  if (!shop) shop = await Shop.findOne({ phone: userId });
  if (!shop) {
    const err = new Error('Shop not found');
    err.statusCode = 404;
    throw err;
  }
  shop.fcmToken = fcmToken || '';
  await shop.save();
}

async function getDashboardStats(shopId) {
  const shop = await Shop.findOne({ id: shopId });
  if (!shop) {
    const err = new Error('Shop not found');
    err.statusCode = 404;
    throw err;
  }

  const shopMatches = [shopId];
  if (shop.id && !shopMatches.includes(shop.id)) shopMatches.push(shop.id);
  if (shop._id) shopMatches.push(shop._id.toString());
  const bookings = await Booking.find({
    $or: [
      { shopId: { $in: shopMatches } },
      { shopId: 'ADMIN_INSTANT', status: 'pending' },
      { shopId: null, status: 'pending' },
      { shopId: '', status: 'pending' }
    ]
  });
  const today = new Date().toDateString();

  let todayOrders = 0;
  let pendingOrders = 0;
  let acceptedOrders = 0;
  let completedOrders = 0;
  let cancelledOrders = 0;
  let totalRevenue = 0.0;
  let todayRevenue = 0.0;

  for (const b of bookings) {
    const bDateStr = new Date(b.date).toDateString();
    const isToday = bDateStr === today;

    if (isToday) todayOrders++;

    if (b.status === 'pending') pendingOrders++;
    else if (b.status === 'accepted' || b.status === 'navigating' || b.status === 'arrived' || b.status === 'work_started') acceptedOrders++;
    else if (b.status === 'completed' || b.status === 'closed') {
      completedOrders++;
      totalRevenue += b.amount;
      if (isToday) todayRevenue += b.amount;
    }
    else if (b.status === 'cancelled') cancelledOrders++;
  }

  const reviews = await Review.find({ shopId: shop.id });
  const reviewsCount = reviews.length;
  const avgRating = reviewsCount > 0 
    ? parseFloat((reviews.reduce((sum, r) => sum + r.rating, 0) / reviewsCount).toFixed(1)) 
    : shop.rating || 5.0;

  return {
    todayOrders,
    pendingOrders,
    acceptedOrders,
    completedOrders,
    cancelledOrders,
    revenue: todayRevenue,
    totalRevenue,
    walletBalance: shop.walletBalance || 0.0,
    rating: avgRating,
    reviewsCount,
    isOnline: shop.isOnline !== false
  };
}

async function toggleOnline(userId, isOnline) {
  const shop = await Shop.findById(userId);
  if (!shop) {
    const err = new Error('Shop not found');
    err.statusCode = 404;
    throw err;
  }

  shop.isOnline = isOnline;
  await shop.save();
  return shop.isOnline;
}

async function updateServices(userId, services, customService) {
  const shop = await Shop.findById(userId);
  if (!shop) {
    const err = new Error('Shop not found');
    err.statusCode = 404;
    throw err;
  }

  const oldServiceImages = (shop.services || []).map(s => s.imageUrl).filter(Boolean);

  if (services) {
    shop.services = services;
  }

  if (customService) {
    const newService = {
      id: `srv-custom-${Date.now()}`,
      title: customService.title,
      price: parseFloat(customService.price) || 0,
      originalPrice: customService.originalPrice ? parseFloat(customService.originalPrice) : undefined,
      rating: 5.0,
      reviewsCount: 0,
      durationText: customService.durationText || '1 hr',
      bulletPoints: customService.bulletPoints || [],
      imageUrl: customService.imageUrl || 'https://images.unsplash.com/photo-1581578731548-c64695cc6952?w=300',
      pricingType: customService.pricingType || 'fixed',
      minPrice: parseFloat(customService.minPrice) || 0,
      maxPrice: parseFloat(customService.maxPrice) || 0,
      visitingCharges: parseFloat(customService.visitingCharges) || 0,
      isFreeInspection: customService.isFreeInspection === true,
      gst: parseFloat(customService.gst) || 0,
      extraCharges: parseFloat(customService.extraCharges) || 0,
      extraChargesLabel: customService.extraChargesLabel || '',
      isAvailable: customService.isAvailable !== false,
      isEnabled: customService.isEnabled !== false
    };
    shop.services.push(newService);
  }

  await shop.save();

  const currentImages = new Set((shop.services || []).map(s => s.imageUrl).filter(Boolean));
  const imagesToDelete = oldServiceImages.filter(img => !currentImages.has(img));
  imagesToDelete.forEach(img => {
    deleteFromCloudinary(img);
  });

  return shop.services;
}

async function updateHoursAndDetails(userId, updateData) {
  const shop = await Shop.findById(userId);
  if (!shop) {
    const err = new Error('Shop not found');
    err.statusCode = 404;
    throw err;
  }

  const { 
    workingHours, holidays, serviceRadius, visitingCharges, 
    emergencyAvailable, estimatedServiceTime, priceRange,
    gst, pan, aadhaar, bankAccountNumber, ifscCode, upiId,
    isFirstLogin, ownerPhone, ownerEmail, walletBalance, walletTransactions
  } = updateData;

  if (workingHours) shop.workingHours = workingHours;
  if (holidays) shop.holidays = holidays;
  if (serviceRadius !== undefined) shop.serviceRadius = parseFloat(serviceRadius);
  if (visitingCharges !== undefined) shop.visitingCharges = parseFloat(visitingCharges);
  if (emergencyAvailable !== undefined) shop.emergencyAvailable = emergencyAvailable;
  if (estimatedServiceTime !== undefined) shop.estimatedServiceTime = estimatedServiceTime;
  if (priceRange !== undefined) shop.priceRange = priceRange;

  if (gst !== undefined) shop.gst = gst;
  if (pan !== undefined) shop.pan = pan;
  if (aadhaar !== undefined) shop.aadhaar = aadhaar;
  if (bankAccountNumber !== undefined) shop.bankAccountNumber = bankAccountNumber;
  if (ifscCode !== undefined) shop.ifscCode = ifscCode;
  if (upiId !== undefined) shop.upiId = upiId;
  
  if (isFirstLogin !== undefined) shop.isFirstLogin = isFirstLogin;
  if (ownerPhone !== undefined) shop.ownerPhone = ownerPhone;
  if (ownerEmail !== undefined) shop.ownerEmail = ownerEmail;
  
  if (walletBalance !== undefined) shop.walletBalance = parseFloat(walletBalance);
  if (walletTransactions !== undefined) shop.walletTransactions = walletTransactions;

  await shop.save();
  return shop;
}

async function getEarnings(shopId) {
  const shop = await Shop.findOne({ id: shopId });
  if (!shop) {
    const err = new Error('Shop not found');
    err.statusCode = 404;
    throw err;
  }
  return {
    walletBalance: shop.walletBalance || 0.0,
    commissionRate: shop.commissionRate || 15.0,
    walletTransactions: shop.walletTransactions || []
  };
}

async function replyToReview(userId, reviewId, replyText) {
  const review = await Review.findOne({ id: reviewId });
  if (!review) {
    const err = new Error('Review not found');
    err.statusCode = 404;
    throw err;
  }

  const shop = await Shop.findById(userId);
  if (!shop || (review.shopId !== shop.id && review.shopId !== String(shop._id))) {
    const err = new Error('Forbidden: You cannot reply to a review belonging to another shop');
    err.statusCode = 403;
    throw err;
  }

  review.reply = replyText;
  await review.save();

  if (shop) {
    if (!shop.reviewReplies) shop.reviewReplies = {};
    shop.reviewReplies.set(reviewId, replyText);
    await shop.save();
  }

  return review;
}

async function updateLocation(userId, latitude, longitude) {
  const shop = await Shop.findById(userId);
  if (!shop) {
    const err = new Error('Shop not found');
    err.statusCode = 404;
    throw err;
  }

  shop.providerLat = parseFloat(latitude);
  shop.providerLng = parseFloat(longitude);
  await shop.save();

  await Booking.findOneAndUpdate(
    { shopId: shop.id, status: 'navigating' },
    { providerLat: parseFloat(latitude), providerLng: parseFloat(longitude) }
  );

  return { providerLat: shop.providerLat, providerLng: shop.providerLng };
}

async function getProfile(userId) {
  const shop = await Shop.findById(userId);
  if (!shop) {
    const err = new Error('Provider account not found');
    err.statusCode = 404;
    throw err;
  }
  return shop;
}

async function uploadBanner(userId, base64Image, validatedMime) {
  const dataUri = `data:${validatedMime};base64,${base64Image}`;
  const shop = await Shop.findById(userId);
  if (!shop) {
    const err = new Error('Shop not found');
    err.statusCode = 404;
    throw err;
  }
  const oldImagePath = shop.imagePath;

  const uploadResponse = await cloudinary.uploader.upload(dataUri, {
    folder: 'quickfix_banners',
    resource_type: 'image',
  });

  const imageUrl = uploadResponse.secure_url;
  shop.imagePath = imageUrl;
  await shop.save();

  if (oldImagePath) {
    deleteFromCloudinary(oldImagePath);
  }

  return shop.imagePath;
}

async function uploadPortfolio(userId, base64Image, validatedMime) {
  const dataUri = `data:${validatedMime};base64,${base64Image}`;
  
  const uploadResponse = await cloudinary.uploader.upload(dataUri, {
    folder: 'quickfix_portfolios',
    resource_type: 'image',
  });

  const imageUrl = uploadResponse.secure_url;
  const shop = await Shop.findById(userId);
  if (!shop) {
    const err = new Error('Shop not found');
    err.statusCode = 404;
    throw err;
  }
  
  if (!shop.portfolioImages) {
    shop.portfolioImages = [];
  }
  shop.portfolioImages.push(imageUrl);
  await shop.save();

  return shop.portfolioImages;
}

async function deletePortfolio(userId, imageUrl) {
  const shop = await Shop.findById(userId);
  if (!shop) {
    const err = new Error('Shop not found');
    err.statusCode = 404;
    throw err;
  }
  
  if (shop.portfolioImages) {
    const exists = shop.portfolioImages.includes(imageUrl);
    if (exists) {
      shop.portfolioImages = shop.portfolioImages.filter(img => img !== imageUrl);
      await shop.save();
      deleteFromCloudinary(imageUrl);
    }
  }

  return shop.portfolioImages;
}

async function uploadServiceImage(base64Image, validatedMime) {
  const dataUri = `data:${validatedMime};base64,${base64Image}`;
  
  const uploadResponse = await cloudinary.uploader.upload(dataUri, {
    folder: 'quickfix_services',
    resource_type: 'image',
  });

  return uploadResponse.secure_url;
}

module.exports = {
  loginProvider,
  changePassword,
  updateFcmToken,
  getDashboardStats,
  toggleOnline,
  updateServices,
  updateHoursAndDetails,
  getEarnings,
  replyToReview,
  updateLocation,
  getProfile,
  uploadBanner,
  uploadPortfolio,
  deletePortfolio,
  uploadServiceImage
};
