const jwt = require('jsonwebtoken');
const bcrypt = require('bcryptjs');
const mongoose = require('mongoose');
const { 
  Settings, Category, Subcategory, CatalogService, Banner, Offer, AuditLog, Review, Professional, 
  User, Shop, Booking, Notification, CmsSection, CustomSection, Demand, AdminUser,
  Promotion, SpecialCard
} = require('../models');
const cloudinary = require('../config/cloudinary');
const { calculateDistance, deleteFromCloudinary, sendFcmNotification, paginate } = require('../helpers');
const { calculateCheckoutPriceInternal } = require('../pricingCalculator');
const { logger } = require('../config/logger');

function buildIdQuery(id) {
  if (!id) return { _id: null };
  const queries = [{ id: id }];
  if (mongoose.Types.ObjectId.isValid(id)) {
    queries.push({ _id: id });
  }
  return queries.length === 1 ? queries[0] : { $or: queries };
}

async function submitDemand(phone, address, latitude, longitude) {
  const newDemand = new Demand({
    id: `dem-${Date.now()}`,
    phone,
    address,
    latitude: parseFloat(latitude),
    longitude: parseFloat(longitude)
  });
  await newDemand.save();
  return newDemand;
}

async function getDemands() {
  return Demand.find({});
}

async function getCategories() {
  return Category.find({});
}

async function uploadCategoryImage(base64Image, validatedMime) {
  const dataUri = `data:${validatedMime};base64,${base64Image}`;
  const uploadResponse = await cloudinary.uploader.upload(dataUri, {
    folder: 'quickfix_categories',
    resource_type: 'image',
  });
  return uploadResponse.secure_url;
}

async function createCategory(id, name, iconUrl) {
  const cat = new Category({ id: id.toLowerCase(), name, iconUrl: iconUrl || '', isActive: true });
  await cat.save();
  return cat;
}

async function updateCategory(id, name, iconUrl) {
  const cat = await Category.findOne({ id: id.toLowerCase() });
  if (!cat) {
    throw new Error('Category not found');
  }
  
  const oldIconUrl = cat.iconUrl;
  
  if (name !== undefined) cat.name = name;
  if (iconUrl !== undefined) cat.iconUrl = iconUrl;
  
  await cat.save();

  if (iconUrl !== undefined && oldIconUrl && oldIconUrl !== iconUrl) {
    deleteFromCloudinary(oldIconUrl);
  }

  return cat;
}

async function deleteCategory(id) {
  const deleted = await Category.findOneAndDelete({ id });
  if (deleted && deleted.iconUrl) {
    deleteFromCloudinary(deleted.iconUrl);
  }
  return deleted;
}

// --- SUBCATEGORY SERVICES ---
async function getSubcategories(categoryId, includeInactive = false) {
  let query = {};
  if (categoryId) {
    query.categoryId = categoryId.toLowerCase();
  }
  if (!includeInactive) {
    query.isActive = true;
  }
  const list = await Subcategory.find(query);
  return list.sort((a, b) => (a.displayOrder || 0) - (b.displayOrder || 0));
}

async function createSubcategory(data) {
  const { id, categoryId, name, description, imageUrl, displayOrder, isActive } = data;
  const slug = (id || name.toLowerCase().replace(/\s+/g, '_')).trim();
  const subcat = new Subcategory({
    id: slug,
    categoryId: categoryId.toLowerCase().trim(),
    name: name.trim(),
    description: description || '',
    imageUrl: imageUrl || '',
    displayOrder: displayOrder || 0,
    isActive: isActive !== false
  });
  await subcat.save();
  return subcat;
}

async function updateSubcategory(id, data) {
  const subcat = await Subcategory.findOne(buildIdQuery(id));
  if (!subcat) throw new Error('Subcategory not found');
  if (data.name !== undefined) subcat.name = data.name;
  if (data.categoryId !== undefined) subcat.categoryId = data.categoryId.toLowerCase().trim();
  if (data.description !== undefined) subcat.description = data.description;
  if (data.imageUrl !== undefined) subcat.imageUrl = data.imageUrl;
  if (data.displayOrder !== undefined) subcat.displayOrder = data.displayOrder;
  if (data.isActive !== undefined) subcat.isActive = data.isActive;
  await subcat.save();
  return subcat;
}

async function deleteSubcategory(id) {
  return await Subcategory.findOneAndDelete(buildIdQuery(id));
}

// --- CATALOG SERVICE METHODS ---
async function getCatalogServices(subcategoryId, categoryId, includeInactive = false) {
  let query = {};
  if (subcategoryId) query.subcategoryId = subcategoryId;
  if (categoryId) query.categoryId = categoryId.toLowerCase();
  if (!includeInactive) query.isActive = true;
  const list = await CatalogService.find(query);
  return list.sort((a, b) => (a.displayOrder || 0) - (b.displayOrder || 0));
}

async function getCatalogServiceById(id) {
  const srv = await CatalogService.findOne(buildIdQuery(id));
  if (!srv) throw new Error('Service not found');
  return srv;
}

async function searchCatalogServices(searchQuery) {
  if (!searchQuery || !searchQuery.trim()) return [];
  const q = searchQuery.trim();
  return await CatalogService.find({
    isActive: true,
    $or: [
      { title: { $regex: q, $options: 'i' } },
      { description: { $regex: q, $options: 'i' } },
      { categoryId: { $regex: q, $options: 'i' } },
      { subcategoryId: { $regex: q, $options: 'i' } }
    ]
  });
}

async function createCatalogService(data) {
  const id = data.id || `srv_${Date.now()}`;
  const srv = new CatalogService({
    id,
    categoryId: (data.categoryId || '').toLowerCase().trim(),
    subcategoryId: (data.subcategoryId || '').trim(),
    title: data.title,
    description: data.description || '',
    imageUrl: data.imageUrl || '',
    price: parseFloat(data.price) || 0,
    originalPrice: parseFloat(data.originalPrice) || 0,
    pricingType: data.pricingType || 'fixed',
    minPrice: parseFloat(data.minPrice) || 0,
    maxPrice: parseFloat(data.maxPrice) || 0,
    visitingCharges: parseFloat(data.visitingCharges) || 0,
    isFreeInspection: data.isFreeInspection === true,
    durationText: data.durationText || '1 hr',
    bulletPoints: Array.isArray(data.bulletPoints) ? data.bulletPoints : [],
    rating: parseFloat(data.rating) || 4.8,
    reviewsCount: parseInt(data.reviewsCount) || 0,
    displayOrder: data.displayOrder || 0,
    isActive: data.isActive !== false
  });
  await srv.save();
  return srv;
}

async function updateCatalogService(id, data) {
  const srv = await CatalogService.findOne(buildIdQuery(id));
  if (!srv) throw new Error('Catalog service not found');
  const fields = ['title', 'description', 'imageUrl', 'price', 'originalPrice', 'pricingType', 'minPrice', 'maxPrice', 'visitingCharges', 'isFreeInspection', 'durationText', 'bulletPoints', 'rating', 'reviewsCount', 'displayOrder', 'isActive', 'categoryId', 'subcategoryId'];
  for (const f of fields) {
    if (data[f] !== undefined) srv[f] = data[f];
  }
  await srv.save();
  return srv;
}

async function deleteCatalogService(id) {
  return await CatalogService.findOneAndDelete(buildIdQuery(id));
}

async function uploadBannerImage(base64Image, validatedMime) {
  const dataUri = `data:${validatedMime};base64,${base64Image}`;
  const uploadResponse = await cloudinary.uploader.upload(dataUri, {
    folder: 'quickfix_banners',
    resource_type: 'image',
  });
  return uploadResponse.secure_url;
}

async function getBanners(includeInactive = false) {
  let query = includeInactive ? {} : { isActive: true };
  let banners = await Banner.find(query);
  if (!banners || banners.length === 0) {
    const defaultBanners = [
      {
        id: 'banner_1',
        title: 'Flat 20% Off Home Deep Cleaning',
        code: 'CLEAN20',
        percent: '20% OFF',
        imageUrl: 'https://images.unsplash.com/photo-1581578731548-c64695cc6952?w=800',
        redirectUrl: '',
        priority: 1,
        expiryDate: '2026-12-31',
        isActive: true
      },
      {
        id: 'banner_2',
        title: 'AC Repair & Servicing Special',
        code: 'ACFREE',
        percent: '₹150 OFF',
        imageUrl: 'https://images.unsplash.com/photo-1621905251189-08b45d6a269e?w=800',
        redirectUrl: '',
        priority: 2,
        expiryDate: '2026-12-31',
        isActive: true
      }
    ];
    try {
      await Banner.insertMany(defaultBanners);
    } catch (_) {}
    return defaultBanners;
  }
  return banners;
}

async function getAdminBanners() {
  return getBanners(true);
}

async function createBanner(bannerData) {
  const { title, code, percent, imageUrl, redirectUrl, priority, expiryDate } = bannerData;
  const newBanner = new Banner({
    id: `banner_${Date.now()}`,
    title: title || '',
    code: code || '',
    percent: percent || '',
    imageUrl: imageUrl || '',
    redirectUrl: redirectUrl || '',
    priority: parseInt(priority) || 0,
    expiryDate: expiryDate || '',
    isActive: true
  });
  await newBanner.save();
  return newBanner;
}

async function updateBanner(id, updateData) {
  let banner = await Banner.findOne({ id });
  if (!banner) {
    banner = await Banner.findById(id);
  }
  if (!banner) {
    throw new Error('Banner not found');
  }
  
  const oldImageUrl = banner.imageUrl;
  const { title, code, percent, imageUrl, redirectUrl, priority, expiryDate } = updateData;

  if (title !== undefined) banner.title = title;
  if (code !== undefined) banner.code = code;
  if (percent !== undefined) banner.percent = percent;
  if (imageUrl !== undefined) banner.imageUrl = imageUrl;
  if (redirectUrl !== undefined) banner.redirectUrl = redirectUrl;
  if (priority !== undefined) banner.priority = parseInt(priority) || 0;
  if (expiryDate !== undefined) banner.expiryDate = expiryDate;

  await banner.save();

  if (imageUrl !== undefined && oldImageUrl && oldImageUrl !== imageUrl) {
    deleteFromCloudinary(oldImageUrl);
  }

  return banner;
}

async function toggleBanner(id) {
  let banner = await Banner.findOne({ id });
  if (!banner) {
    banner = await Banner.findById(id);
  }
  if (!banner) {
    throw new Error('Banner not found');
  }
  banner.isActive = !banner.isActive;
  await banner.save();
  return banner;
}

async function deleteBanner(id) {
  let deleted = await Banner.findOneAndDelete({ id });
  if (!deleted) {
    deleted = await Banner.findByIdAndDelete(id);
  }
  if (!deleted) {
    throw new Error('Banner not found');
  }
  if (deleted.imageUrl) {
    deleteFromCloudinary(deleted.imageUrl);
  }
  return deleted;
}

async function getOffers(includeInactive = false) {
  let query = includeInactive ? {} : { isActive: true };
  let offers = await Offer.find(query);
  if (!offers || offers.length === 0) {
    const defaultOffers = [
      {
        id: 'off-quick20',
        code: 'QUICK20',
        title: 'Get 20% Instant Discount',
        description: 'Save 20% on all repair and cleaning services above ₹499.',
        minOrderAmount: 499,
        maxDiscount: 200,
        isActive: true,
        expiryDate: '2026-12-31'
      },
      {
        id: 'off-first15',
        code: 'FIRST15',
        title: 'Flat 15% Welcome Offer',
        description: 'Exclusive 15% discount for your first service booking.',
        minOrderAmount: 299,
        maxDiscount: 150,
        isActive: true,
        expiryDate: '2026-12-31'
      },
      {
        id: 'off-festive100',
        code: 'FESTIVE100',
        title: 'Flat ₹100 Off',
        description: 'Get ₹100 instant cashback on orders above ₹799.',
        minOrderAmount: 799,
        maxDiscount: 100,
        isActive: true,
        expiryDate: '2026-12-31'
      }
    ];

    try {
      await Offer.insertMany(defaultOffers);
    } catch (_) {}
    return defaultOffers;
  }
  return offers;
}

async function getAdminOffers() {
  return getOffers(true);
}

async function createOffer(offerData) {
  const { code, title, description, minOrderAmount, maxDiscount, expiryDate, usageLimit } = offerData;
  if (!code || !title) {
    throw new Error('Offer code and title are required');
  }
  const cleanCode = code.toUpperCase();
  let existing = await Offer.findOne({ code: cleanCode });
  if (existing) {
    existing.title = title;
    existing.description = description || existing.description;
    existing.minOrderAmount = parseFloat(minOrderAmount) || 0;
    existing.maxDiscount = parseFloat(maxDiscount) || 0;
    existing.expiryDate = expiryDate || existing.expiryDate;
    existing.usageLimit = parseInt(usageLimit) || 0;
    await existing.save();
    return existing;
  }
  const newOffer = new Offer({
    code: cleanCode,
    title,
    description: description || '',
    minOrderAmount: parseFloat(minOrderAmount) || 0,
    maxDiscount: parseFloat(maxDiscount) || 0,
    expiryDate: expiryDate || '',
    usageLimit: parseInt(usageLimit) || 1,
    isActive: true
  });
  await newOffer.save();
  return newOffer;
}

async function applyOffer(code, amount = 0) {
  if (!code) throw new Error('Invalid or expired coupon code');
  const offer = await Offer.findOne({ code: code.toUpperCase(), isActive: true });
  
  if (!offer) {
    const cleanCode = code.toUpperCase();
    if (cleanCode === 'QUICK20' || cleanCode === 'FIRST15' || cleanCode === 'FESTIVE100') {
      let discount = 50.0;
      if (cleanCode === 'QUICK20') discount = amount ? (amount * 0.20) : 100.0;
      if (cleanCode === 'FIRST15') discount = amount ? (amount * 0.15) : 75.0;
      if (cleanCode === 'FESTIVE100') discount = 100.0;
      return {
        success: true,
        code: cleanCode,
        discount: parseFloat(discount.toFixed(2)),
        message: 'Coupon applied successfully!'
      };
    }
    throw new Error('Invalid or expired coupon code');
  }

  let discount = 0.0;
  if (offer.maxDiscount > 0) {
    discount = offer.maxDiscount;
  } else {
    discount = amount ? (amount * 0.15) : 50.0;
  }

  return {
    success: true,
    code: offer.code,
    discount: parseFloat(discount.toFixed(2)),
    message: 'Coupon applied successfully!'
  };
}

async function updateOffer(code, updateData) {
  const { title, description, minOrderAmount, maxDiscount, expiryDate, usageLimit } = updateData;
  const offer = await Offer.findOneAndUpdate(
    { code: code.toUpperCase() },
    { 
      title, 
      description, 
      minOrderAmount: parseFloat(minOrderAmount) || 0, 
      maxDiscount: parseFloat(maxDiscount) || 0, 
      expiryDate, 
      usageLimit: parseInt(usageLimit) || 0 
    },
    { new: true }
  );
  if (!offer) {
    throw new Error('Offer not found');
  }
  return offer;
}

async function toggleOffer(code) {
  const offer = await Offer.findOne({ code: code.toUpperCase() });
  if (!offer) {
    throw new Error('Offer not found');
  }
  offer.isActive = !offer.isActive;
  await offer.save();
  return offer;
}

async function deleteOffer(code) {
  const deleted = await Offer.findOneAndDelete({ code: code.toUpperCase() });
  if (!deleted) {
    throw new Error('Offer not found');
  }
  return deleted;
}

async function validateCoupon(code, amount) {
  const offer = await Offer.findOne({ code: code.toUpperCase(), isActive: true });
  if (!offer) {
    throw new Error('Invalid or expired coupon code');
  }
  
  let discount = 0.0;
  if (code.toUpperCase() === 'QUICK20') {
    discount = amount * 0.20;
  } else if (code.toUpperCase() === 'FIRST15') {
    discount = amount * 0.15;
  } else {
    discount = 10.0;
  }
  return discount.toFixed(2);
}

async function calculateCheckout(shopId, items, couponCode) {
  const shop = await Shop.findOne({ id: shopId });
  if (!shop) {
    throw new Error('Shop not found');
  }
  return calculateCheckoutPriceInternal(shop, items, couponCode);
}

async function getSettings() {
  const settingsList = await Settings.find({});
  const settingsObj = {};
  settingsList.forEach(s => {
    settingsObj[s.key] = s.value;
  });
  return {
    taxRate: settingsObj.taxRate !== undefined ? settingsObj.taxRate : 5.0,
    commission: settingsObj.commission !== undefined ? settingsObj.commission : 10.0,
    visitingCharges: settingsObj.visitingCharges !== undefined ? settingsObj.visitingCharges : 150.0,
    supportNumber: (settingsObj.supportNumber !== undefined && settingsObj.supportNumber !== '9876543210') ? settingsObj.supportNumber : '9453626549',
    terms: settingsObj.terms !== undefined ? settingsObj.terms : 'Standard Terms & Conditions apply.',
    privacy: settingsObj.privacy !== undefined ? settingsObj.privacy : 'Standard Privacy Policy applies.',
    emergencyContact: settingsObj.emergencyContact !== undefined ? settingsObj.emergencyContact : '100',
    appVersion: settingsObj.appVersion !== undefined ? settingsObj.appVersion : '1.0.0',
    maintenanceMode: settingsObj.maintenanceMode !== undefined ? settingsObj.maintenanceMode : false
  };
}

async function updateSettings(body) {
  const updatePromises = Object.entries(body).map(async ([key, value]) => {
    return Settings.findOneAndUpdate(
      { key },
      { key, value },
      { upsert: true, new: true }
    );
  });
  await Promise.all(updatePromises);
}

async function getAuditLogs() {
  return AuditLog.find({}).sort({ createdAt: -1 });
}

async function createAuditLog(action, target, details, ip) {
  const log = new AuditLog({
    id: `log-${Date.now()}`,
    action,
    target,
    details,
    ip: ip || '127.0.0.1'
  });
  await log.save();
  return log;
}

async function getReviews(req) {
  if (req.query.status === undefined) {
    req.query.status = 'approved';
  }
  if (req.query.isActive === undefined) {
    req.query.isActive = { $ne: false };
  }
  return paginate(Review, req, ['userName', 'comment', 'serviceName', 'locationName', 'providerName'], { priority: 1 });
}

async function getAdminReviews(req) {
  return paginate(Review, req, ['userName', 'comment', 'serviceName', 'locationName', 'providerName'], { priority: 1 });
}

async function approveReview(id, status) {
  const review = await Review.findOneAndUpdate({ id }, { status }, { new: true });
  if (!review) {
    throw new Error('Review not found');
  }
  return review;
}

async function saveReview(id, body) {
  const { userName, userAvatar, rating, comment, serviceName, locationName, shopId, reply, providerName, date, verifiedBadge, priority, status, isActive, isFeatured } = body;
  let review;
  if (id) {
    review = await Review.findOneAndUpdate(
      { id },
      { 
        userName, 
        userAvatar, 
        rating: parseFloat(rating) || 5.0, 
        comment, 
        serviceName, 
        locationName, 
        shopId, 
        reply, 
        providerName, 
        date, 
        verifiedBadge: verifiedBadge !== false, 
        priority: parseInt(priority) || 0, 
        status: status || 'approved', 
        isActive: isActive !== false, 
        isFeatured: isFeatured === true 
      },
      { new: true }
    );
    if (!review) {
      throw new Error('Review not found');
    }
  } else {
    review = new Review({
      id: `rev-${Date.now()}`,
      userName,
      userAvatar: userAvatar || 'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=150',
      rating: parseFloat(rating) || 5.0,
      comment,
      serviceName: serviceName || 'General Service',
      locationName: locationName || 'Kanpur',
      shopId: shopId || '',
      reply: reply || '',
      providerName: providerName || '',
      date: date || new Date().toISOString().split('T')[0],
      verifiedBadge: verifiedBadge !== false,
      priority: parseInt(priority) || 0,
      status: status || 'approved',
      isActive: isActive !== false,
      isFeatured: isFeatured === true
    });
    await review.save();
  }
  return review;
}

async function deleteReview(id) {
  const deleted = await Review.findOneAndDelete({ id });
  if (!deleted) {
    throw new Error('Review not found');
  }
  return deleted;
}

async function getProfessionals(sort, lat, lng) {
  let list = await Professional.find({ isActive: { $ne: false } });

  const userLat = parseFloat(lat);
  const userLng = parseFloat(lng);
  const hasUserCoords = !isNaN(userLat) && !isNaN(userLng) && userLat !== 0 && userLng !== 0;

  const syncedList = await Promise.all(list.map(async (prof) => {
    const p = prof.toObject ? prof.toObject() : { ...prof };
    if (p.shopId) {
      let shop = null;
      try { shop = await Shop.findById(p.shopId); } catch (_) {}
      if (!shop) shop = await Shop.findOne({ id: p.shopId });
      if (!shop) shop = await Shop.findOne({ _id: p.shopId });

      if (shop) {
        p.shopStatus = shop.status;
        p.verificationStatus = shop.verificationStatus;
        p.isOnline = shop.isOnline;
        p.name = shop.ownerName || shop.name || p.name;
        p.imageUrl = shop.ownerPhotoUrl || shop.imagePath || p.imageUrl;
        p.specialty = (shop.categories && shop.categories.length > 0) ? shop.categories[0] : p.specialty;
        p.rating = shop.rating !== undefined ? shop.rating : p.rating;
        p.availability = shop.isOnline !== undefined ? shop.isOnline : p.availability;
        p.verifiedBadge = shop.verificationStatus === 'approved';
        p.lat = shop.latitude;
        p.lng = shop.longitude;
        p.serviceRadius = parseFloat(shop.serviceRadius || shop.maxDistanceKm) || 15.0;
        p.reviewsCount = shop.services ? shop.services.reduce((acc, s) => acc + (s.reviewsCount || 0), 0) : p.reviewsCount;
      }
    }

    if (hasUserCoords && p.lat !== undefined && p.lng !== undefined) {
      p.distanceKm = calculateDistance(userLat, userLng, p.lat, p.lng);
    } else {
      p.distanceKm = 0;
    }

    return p;
  }));

  const filteredList = syncedList.filter(p => {
    if (p.shopStatus && p.shopStatus !== 'active') return false;
    if (p.verificationStatus && p.verificationStatus !== 'approved') return false;
    if (p.isOnline === false) return false;

    if (hasUserCoords && p.lat !== undefined && p.lng !== undefined) {
      const radius = parseFloat(p.serviceRadius) || 15.0;
      if (p.distanceKm > radius) {
        return false;
      }
    }
    return true;
  });

  if (sort === 'rating') {
    filteredList.sort((a, b) => (b.rating || 0) - (a.rating || 0));
  } else if (sort === 'bookings') {
    filteredList.sort((a, b) => (b.completedJobs || b.reviewsCount || 0) - (a.completedJobs || a.reviewsCount || 0));
  } else if (sort === 'nearest' && hasUserCoords) {
    filteredList.sort((a, b) => (a.distanceKm || 0) - (b.distanceKm || 0));
  } else if (hasUserCoords) {
    filteredList.sort((a, b) => (a.distanceKm || 0) - (b.distanceKm || 0));
  } else {
    filteredList.sort((a, b) => (b.rating || 0) - (a.rating || 0));
  }

  return filteredList;
}


async function getHomepageLayout() {
  let list = await CmsSection.find({ isActive: true });
  if (list.length === 0) {
    const defaultSections = [
      { id: 'app_bar', title: 'Top Header Navigation Bar', type: 'app_bar', priority: 0, isActive: true },
      { id: 'search_bar', title: 'Global Search bar & Filters', type: 'search_bar', priority: 1, isActive: true },
      { id: 'banners', title: 'Offer Ad Banners Slider', type: 'banners', priority: 2, isActive: true },
      { id: 'categories', title: 'Categories Quick Grid', type: 'categories', priority: 3, isActive: true },
      { id: 'special_card', title: 'Special Promo Card Panel', type: 'special_card', priority: 4, isActive: true },
      { id: 'active_bookings', title: 'User Live Booking Tracker Card', type: 'active_bookings', priority: 5, isActive: true },
      { id: 'nearby_shops', title: 'Nearby Service Shops Feed', type: 'nearby_shops', priority: 6, isActive: true },
      { id: 'services_grid', title: 'Top Services Catalog List', type: 'services_grid', priority: 7, isActive: true },
      { id: 'quick_book_banner', title: 'Quick Booking Express Banner', type: 'quick_book_banner', priority: 8, isActive: true },
      { id: 'professionals', title: 'Verified Experts Catalog', type: 'professionals', priority: 9, isActive: true },
      { id: 'customer_reviews', title: 'What Our Customers Say', type: 'customer_reviews', priority: 10, isActive: true },
      { id: 'brand_logos', title: 'Brand Marquee Logos', type: 'brand_logos', priority: 11, isActive: true },
      { id: 'support_card', title: 'Need Help Support Card', type: 'support_card', priority: 12, isActive: true }
    ];
    await CmsSection.insertMany(defaultSections);
    list = await CmsSection.find({ isActive: true });
  }
  list.sort((a, b) => (a.priority || 0) - (b.priority || 0));
  return list;
}

async function getAdminHomepageLayout() {
  let list = await CmsSection.find({});
  if (list.length === 0) {
    const defaultSections = [
      { id: 'app_bar', title: 'Top Header Navigation Bar', type: 'app_bar', priority: 0, isActive: true },
      { id: 'search_bar', title: 'Global Search bar & Filters', type: 'search_bar', priority: 1, isActive: true },
      { id: 'banners', title: 'Offer Ad Banners Slider', type: 'banners', priority: 2, isActive: true },
      { id: 'categories', title: 'Categories Quick Grid', type: 'categories', priority: 3, isActive: true },
      { id: 'special_card', title: 'Special Promo Card Panel', type: 'special_card', priority: 4, isActive: true },
      { id: 'active_bookings', title: 'User Live Booking Tracker Card', type: 'active_bookings', priority: 5, isActive: true },
      { id: 'nearby_shops', title: 'Nearby Service Shops Feed', type: 'nearby_shops', priority: 6, isActive: true },
      { id: 'services_grid', title: 'Top Services Catalog List', type: 'services_grid', priority: 7, isActive: true },
      { id: 'quick_book_banner', title: 'Quick Booking Express Banner', type: 'quick_book_banner', priority: 8, isActive: true },
      { id: 'professionals', title: 'Verified Experts Catalog', type: 'professionals', priority: 9, isActive: true },
      { id: 'customer_reviews', title: 'What Our Customers Say', type: 'customer_reviews', priority: 10, isActive: true },
      { id: 'brand_logos', title: 'Brand Marquee Logos', type: 'brand_logos', priority: 11, isActive: true },
      { id: 'support_card', title: 'Need Help Support Card', type: 'support_card', priority: 12, isActive: true }
    ];
    await CmsSection.insertMany(defaultSections);
    list = await CmsSection.find({});
  }
  list.sort((a, b) => (a.priority || 0) - (b.priority || 0));
  return list;
}

async function updateHomepageLayout(id, title, isActive, priority, settings) {
  const updateFields = {};
  if (title !== undefined) updateFields.title = title;
  if (isActive !== undefined) updateFields.isActive = isActive;
  if (priority !== undefined) updateFields.priority = parseInt(priority);
  if (settings !== undefined) updateFields.settings = settings;

  let section = await CmsSection.findOneAndUpdate(buildIdQuery(id), updateFields, { new: true });
  if (!section && id) {
    section = new CmsSection({
      id,
      title: title || id,
      type: id.startsWith('custom-section-') ? 'custom_section' : id,
      priority: priority !== undefined ? parseInt(priority) : 0,
      isActive: isActive !== false
    });
    await section.save();
  }
  if (id && id.startsWith('custom-section-')) {
    const customUpdate = {};
    if (title !== undefined) customUpdate.title = title;
    if (isActive !== undefined) customUpdate.isActive = isActive;
    if (priority !== undefined) customUpdate.priority = parseInt(priority);
    await CustomSection.findOneAndUpdate(buildIdQuery(id), customUpdate);
  }
  return section;
}

async function reorderHomepageLayout(orderList) {
  const promises = orderList.map(item => {
    if (item.id && item.id.startsWith('custom-section-')) {
      CustomSection.findOneAndUpdate(buildIdQuery(item.id), { priority: item.priority }).catch(() => {});
    }
    return CmsSection.findOneAndUpdate(buildIdQuery(item.id), { priority: item.priority });
  });
  await Promise.all(promises);
}

async function getCustomSections() {
  let list = await CustomSection.find({ isActive: true });
  list.sort((a, b) => (a.priority || 0) - (b.priority || 0));
  return list;
}

async function getAdminCustomSections() {
  let list = await CustomSection.find({});
  list.sort((a, b) => (a.priority || 0) - (b.priority || 0));
  return list;
}

async function getCustomSectionById(id) {
  const section = await CustomSection.findOne(buildIdQuery(id));
  if (!section) {
    throw new Error('Custom section not found');
  }
  return section;
}

async function saveCustomSection(id, body) {
  const { title, subtitle, bannerImageUrl, bannerBadgeText, bannerButtonText, bannerActionType, bannerActionValue, seeAllActionType, seeAllActionValue, serviceItems, priority, isActive } = body;
  const sectionTitle = title || '';
  const btnText = bannerButtonText !== undefined ? bannerButtonText : 'Explore now';
  let section;
  if (id) {
    section = await CustomSection.findOneAndUpdate(
      buildIdQuery(id),
      { title: sectionTitle, subtitle, bannerImageUrl, bannerBadgeText, bannerButtonText: btnText, bannerActionType: bannerActionType || 'No Action', bannerActionValue, seeAllActionType: seeAllActionType || 'No Action', seeAllActionValue, serviceItems: serviceItems || [], priority: parseInt(priority) || 0, isActive: isActive !== false },
      { new: true }
    );
    if (!section) {
      section = new CustomSection({
        id,
        title: sectionTitle, subtitle, bannerImageUrl, bannerBadgeText, bannerButtonText: btnText,
        bannerActionType: bannerActionType || 'No Action',
        bannerActionValue,
        seeAllActionType: seeAllActionType || 'No Action',
        seeAllActionValue,
        serviceItems: serviceItems || [],
        priority: parseInt(priority) || 0,
        isActive: isActive !== false
      });
      await section.save();
    }
    await CmsSection.findOneAndUpdate(buildIdQuery(id), { title: sectionTitle || 'Custom Section', isActive: isActive !== false, priority: parseInt(priority) || 0 });
  } else {
    const newId = `custom-section-${Date.now()}`;
    const allSections = await CmsSection.find({});
    const newPriority = parseInt(priority) || allSections.length;
    const layoutSection = new CmsSection({
      id: newId,
      title: sectionTitle || 'Custom Section',
      type: 'custom_section',
      priority: newPriority,
      isActive: isActive !== false
    });
    await layoutSection.save();
    section = new CustomSection({
      id: newId,
      title: sectionTitle, subtitle, bannerImageUrl, bannerBadgeText, bannerButtonText: btnText,
      bannerActionType: bannerActionType || 'No Action',
      bannerActionValue,
      seeAllActionType: seeAllActionType || 'No Action',
      seeAllActionValue,
      serviceItems: serviceItems || [],
      priority: newPriority,
      isActive: isActive !== false
    });
    await section.save();
  }
  return section;
}

async function deleteCustomSection(id) {
  const deleted = await CustomSection.findOneAndDelete(buildIdQuery(id));
  await CmsSection.findOneAndDelete(buildIdQuery(id));
  return deleted;
}

async function adminLogin(password) {
  const nodeEnv = (process.env.NODE_ENV || 'development').toLowerCase().trim();
  if (!process.env.ADMIN_PASSWORD && nodeEnv === 'production') {
    const err = new Error('System Configuration Error: Security settings are incomplete.');
    err.statusCode = 500;
    throw err;
  }

  const adminPassword = process.env.ADMIN_PASSWORD || 'quickfix_admin_secret_9988_dev_fallback';
  const MAX_FAILED_ATTEMPTS = 5;
  const LOCK_TIME_MS = 30 * 60 * 1000; // 30 minutes lockout

  let adminUser = await AdminUser.findOne({ username: 'admin' });
  if (!adminUser) {
    const passwordHash = await bcrypt.hash(adminPassword, 10);
    adminUser = new AdminUser({
      username: 'admin',
      passwordHash: passwordHash,
      role: 'admin',
      failedAttempts: 0,
      lockUntil: null
    });
    await adminUser.save();
  }

  if (adminUser.lockUntil && adminUser.lockUntil > new Date()) {
    const remainingMins = Math.ceil((adminUser.lockUntil.getTime() - Date.now()) / (60 * 1000));
    const err = new Error(`Admin account is temporarily locked due to repeated failed login attempts. Try again in ${remainingMins} minute(s).`);
    err.statusCode = 429;
    throw err;
  }

  let isMatch = await bcrypt.compare(password, adminUser.passwordHash);
  if (!isMatch && password === adminPassword) {
    adminUser.passwordHash = await bcrypt.hash(adminPassword, 10);
    isMatch = true;
  }

  if (!isMatch) {
    adminUser.failedAttempts = (adminUser.failedAttempts || 0) + 1;
    if (adminUser.failedAttempts >= MAX_FAILED_ATTEMPTS) {
      adminUser.lockUntil = new Date(Date.now() + LOCK_TIME_MS);
      await adminUser.save();
      logger.warn(`Admin account locked due to ${MAX_FAILED_ATTEMPTS} failed attempts.`);
      const err = new Error('Too many failed login attempts. Admin account locked for 30 minutes.');
      err.statusCode = 429;
      throw err;
    }
    await adminUser.save();
    const err = new Error('Invalid admin credentials');
    err.statusCode = 401;
    throw err;
  }

  adminUser.failedAttempts = 0;
  adminUser.lockUntil = null;
  await adminUser.save();

  try {
    const audit = new AuditLog({
      id: `AUDIT-LOGIN-${Date.now()}`,
      action: 'ADMIN_LOGIN',
      details: 'Super admin authenticated into admin panel',
      adminUser: 'admin',
      timestamp: new Date().toISOString()
    });
    await audit.save();
  } catch (auditErr) {
    logger.error('Failed to log admin login audit event:', auditErr);
  }

  const secret = process.env.JWT_SECRET;
  if (!secret) {
    const err = new Error('Server configuration error: JWT_SECRET missing.');
    err.statusCode = 500;
    throw err;
  }

  const token = jwt.sign(
    { id: 'super-admin', role: 'admin' },
    secret,
    { expiresIn: '24h' }
  );
  return token;
}

async function getAdminStats() {
  const totalCustomers = await User.countDocuments({ accountStatus: { $ne: 'deleted' } });
  const totalShops = await Shop.countDocuments({});
  const totalProviders = await Shop.countDocuments({ verificationStatus: 'approved' });

  const pendingBookings = await Booking.countDocuments({ status: 'pending' });
  const activeBookings = await Booking.countDocuments({ status: { $in: ['accepted', 'on_the_way', 'navigating', 'arrived', 'quote_sent', 'work_started'] } });
  const completedBookings = await Booking.countDocuments({ status: 'completed' });
  const cancelledBookings = await Booking.countDocuments({ status: 'cancelled' });

  const revenueResult = await Booking.aggregate([
    { $match: { status: 'completed' } },
    { $group: { _id: null, total: { $sum: '$amount' } } }
  ]);
  const revenue = revenueResult.length > 0 ? revenueResult[0].total : 0;

  const walletResult = await User.aggregate([
    { $match: { accountStatus: { $ne: 'deleted' } } },
    { $group: { _id: null, total: { $sum: '$walletBalance' } } }
  ]);
  const walletBalance = walletResult.length > 0 ? walletResult[0].total : 0;

  const onlineShops = await Shop.countDocuments({ isOnline: true, verificationStatus: 'approved', status: 'active' });
  const offlineShops = totalShops - onlineShops;

  const servicesResult = await Shop.aggregate([
    { $project: { numberOfServices: { $cond: { if: { $isArray: "$services" }, then: { $size: "$services" }, else: 0 } } } },
    { $group: { _id: null, total: { $sum: "$numberOfServices" } } }
  ]);
  const totalServices = servicesResult.length > 0 ? servicesResult[0].total : 0;

  const activeCoupons = await Offer.countDocuments({ isActive: true });
  const notificationsSent = await Notification.countDocuments({});

  const today = new Date();
  today.setHours(0,0,0,0);
  const todaysOrders = await Booking.countDocuments({ createdAt: { $gte: today } });

  return {
    totalCustomers,
    totalShops,
    totalProviders,
    activeBookings,
    pendingBookings,
    completedBookings,
    cancelledBookings,
    revenue: parseFloat(revenue.toFixed(2)),
    walletBalance: parseFloat(walletBalance.toFixed(2)),
    onlineShops,
    offlineShops,
    totalServices,
    activeCoupons,
    notificationsSent,
    todaysOrders
  };
}

async function getReportsSummary() {
  const sevenDaysAgo = new Date();
  sevenDaysAgo.setDate(sevenDaysAgo.getDate() - 6);
  sevenDaysAgo.setHours(0,0,0,0);

  const dailyStats = await Booking.aggregate([
    { $match: { createdAt: { $gte: sevenDaysAgo } } },
    {
      $group: {
        _id: { $dateToString: { format: "%Y-%m-%d", date: "$createdAt", timezone: "Asia/Kolkata" } },
        count: { $sum: 1 },
        revenue: { $sum: { $cond: [{ $eq: ["$status", "completed"] }, "$amount", 0] } }
      }
    }
  ]);

  const dailyMap = {};
  dailyStats.forEach(stat => {
    if (stat._id) {
      const d = new Date(stat._id);
      const label = d.toLocaleDateString('en-IN', { day: '2-digit', month: 'short' });
      dailyMap[label] = { revenue: stat.revenue, count: stat.count };
    }
  });

  const dailyData = [];
  for (let i = 6; i >= 0; i--) {
    const d = new Date();
    d.setDate(d.getDate() - i);
    const dateStr = d.toLocaleDateString('en-IN', { day: '2-digit', month: 'short' });
    
    const val = dailyMap[dateStr] || { revenue: 0, count: 0 };
    dailyData.push({
      date: dateStr,
      revenue: parseFloat(val.revenue.toFixed(2)),
      bookings: val.count
    });
  }

  const categoryStats = await Booking.aggregate([
    {
      $lookup: {
        from: "shops",
        localField: "shopId",
        foreignField: "id",
        as: "shopInfo"
      }
    },
    { $unwind: { path: "$shopInfo", preserveNullAndEmptyArrays: true } },
    {
      $project: {
        amount: 1,
        status: 1,
        categories: { $ifNull: ["$shopInfo.categories", ["General"]] }
      }
    },
    { $unwind: "$categories" },
    {
      $group: {
        _id: "$categories",
        count: { $sum: 1 },
        revenue: { $sum: { $cond: [{ $eq: ["$status", "completed"] }, "$amount", 0] } }
      }
    }
  ]);

  return {
    daily: dailyData,
    categories: categoryStats.map(stat => ({
      name: stat._id || 'General',
      revenue: parseFloat(stat.revenue.toFixed(2)),
      bookings: stat.count
    }))
  };
}

async function getUsers(req) {
  if (req.query.accountStatus === undefined) {
    req.query.accountStatus = { $ne: 'deleted' };
  }
  return paginate(User, req, ['name', 'phone', 'email'], { createdAt: -1 });
}

async function adjustUserWallet(userId, amount, type, title) {
  const user = await User.findById(userId);
  if (!user) {
    throw new Error('User not found');
  }
  const val = parseFloat(amount);
  if (type === 'credit') {
    user.walletBalance = (user.walletBalance || 0) + val;
  } else {
    user.walletBalance = Math.max(0, (user.walletBalance || 0) - val);
  }
  user.walletTransactions = user.walletTransactions || [];
  user.walletTransactions.push({
    id: `TX-ADJ-${Date.now()}`,
    title: title || `Adjusted by Admin`,
    amount: val,
    type: type || 'credit',
    date: new Date()
  });
  await user.save();

  sendFcmNotification(
    user._id,
    type === 'credit' ? 'Wallet Credited 💰' : 'Wallet Debited 💸',
    type === 'credit' 
      ? `Your wallet has been credited with ₹${val.toFixed(2)}: ${title || 'Adjusted by Admin'}.`
      : `Your wallet has been debited by ₹${val.toFixed(2)}: ${title || 'Adjusted by Admin'}.`,
    {
      type: 'wallet_update',
      iconColor: type === 'credit' ? 'success' : 'warning'
    }
  );

  return user.walletBalance;
}

async function toggleUserStatus(userId) {
  const user = await User.findById(userId);
  if (!user) {
    throw new Error('User not found');
  }
  user.accountStatus = user.accountStatus === 'active' ? 'inactive' : 'active';
  await user.save();
  return user.accountStatus;
}

// --- CMS HELPER FUNCTIONS ---

async function getPromotions(includeInactive = false) {
  let query = includeInactive ? {} : { isActive: true };
  let list = await Promotion.find(query);
  if (!list || list.length === 0) {
    const defaultPromotions = [
      {
        id: 'promo-festive-summer',
        title: 'Summer Care Carnival',
        subtitle: 'Beat the heat with heavy discounts',
        description: 'Get up to 40% off on all AC servicing, plumbing, and deep home cleaning.',
        offerPercentage: '40% OFF',
        couponCode: 'SUMMER40',
        ctaButtonText: 'Grab Now',
        ctaButtonAction: 'Category',
        ctaButtonActionValue: 'AC Repair',
        bannerImage: 'https://images.unsplash.com/photo-1621905251189-08b45d6a269e?w=800',
        backgroundColor: '#FFF1F0',
        textColor: '#000000',
        buttonColor: '#FF4D4F',
        buttonTextColor: '#FFFFFF',
        priority: 1,
        isActive: true
      }
    ];
    try {
      await Promotion.insertMany(defaultPromotions);
    } catch (_) {}
    return defaultPromotions;
  }
  return list;
}

async function getAdminPromotions() {
  return getPromotions(true);
}

async function savePromotion(id, data) {
  let promo;
  if (id) {
    promo = await Promotion.findOne(buildIdQuery(id));
  }
  if (promo) {
    Object.assign(promo, data);
    await promo.save();
    return promo;
  } else {
    const newPromo = new Promotion({
      ...data,
      id: id || `promo-${Date.now()}`
    });
    await newPromo.save();
    return newPromo;
  }
}

async function togglePromotion(id) {
  let promo = await Promotion.findOne(buildIdQuery(id));
  if (!promo) throw new Error('Promotion not found');
  promo.isActive = !promo.isActive;
  await promo.save();
  return promo;
}

async function deletePromotion(id) {
  let deleted = await Promotion.findOneAndDelete(buildIdQuery(id));
  if (!deleted) throw new Error('Promotion not found');
  return deleted;
}

async function getSpecialCards(includeInactive = false) {
  let query = includeInactive ? {} : { isActive: true };
  let list = await SpecialCard.find(query);
  if (!list || list.length === 0) {
    const defaultCards = [
      {
        id: 'special-1',
        title: 'Emergency Plumbing',
        subtitle: '24/7 Fast Arrival',
        description: 'Pipe leaks, tap fixes, & drain unclogging in 30 mins',
        icon: 'faucet',
        backgroundColor: '#E6F7FF',
        buttonText: 'Book Now',
        ctaAction: 'Category',
        ctaActionValue: 'Plumbing',
        priority: 1,
        isActive: true
      }
    ];
    try {
      await SpecialCard.insertMany(defaultCards);
    } catch (_) {}
    return defaultCards;
  }
  return list;
}

async function getAdminSpecialCards() {
  return getSpecialCards(true);
}

async function saveSpecialCard(id, data) {
  let card;
  if (id) {
    card = await SpecialCard.findOne(buildIdQuery(id));
  }
  if (card) {
    Object.assign(card, data);
    await card.save();
    return card;
  } else {
    const newCard = new SpecialCard({
      ...data,
      id: id || `special-${Date.now()}`
    });
    await newCard.save();
    return newCard;
  }
}

async function toggleSpecialCard(id) {
  let card = await SpecialCard.findOne(buildIdQuery(id));
  if (!card) throw new Error('Special card not found');
  card.isActive = !card.isActive;
  await card.save();
  return card;
}

async function deleteSpecialCard(id) {
  let deleted = await SpecialCard.findOneAndDelete(buildIdQuery(id));
  if (!deleted) throw new Error('Special card not found');
  return deleted;
}

async function getAdminProfessionals() {
  return Professional.find({});
}

async function saveProfessional(id, data) {
  let prof;
  if (id) {
    prof = await Professional.findOne(buildIdQuery(id));
  }
  if (prof) {
    Object.assign(prof, data);
    await prof.save();
    return prof;
  } else {
    const newProf = new Professional({
      ...data,
      id: id || `prof-${Date.now()}`
    });
    await newProf.save();
    return newProf;
  }
}

async function toggleProfessional(id) {
  let prof = await Professional.findOne({ id });
  if (!prof) prof = await Professional.findById(id);
  if (!prof) throw new Error('Professional not found');
  prof.isActive = !prof.isActive;
  await prof.save();
  return prof;
}

async function deleteProfessional(id) {
  let deleted = await Professional.findOneAndDelete({ id });
  if (!deleted) deleted = await Professional.findByIdAndDelete(id);
  if (!deleted) throw new Error('Professional not found');
  return deleted;
}

async function toggleReviewFeatured(id) {
  let rev = await Review.findOne({ id });
  if (!rev) rev = await Review.findById(id);
  if (!rev) throw new Error('Review not found');
  rev.isFeatured = !rev.isFeatured;
  await rev.save();
  return rev;
}

async function updateReviewStatus(id, status) {
  let rev = await Review.findOne({ id });
  if (!rev) rev = await Review.findById(id);
  if (!rev) throw new Error('Review not found');
  rev.status = status;
  await rev.save();
  return rev;
}

async function toggleCustomSection(id) {
  let sec = await CustomSection.findOne({ id });
  if (!sec) sec = await CustomSection.findById(id);
  if (!sec) throw new Error('Custom section not found');
  sec.isActive = !sec.isActive;
  await sec.save();
  return sec;
}

module.exports = {
  submitDemand,
  getDemands,
  getCategories,
  uploadCategoryImage,
  createCategory,
  updateCategory,
  deleteCategory,
  getSubcategories,
  createSubcategory,
  updateSubcategory,
  deleteSubcategory,
  getCatalogServices,
  getCatalogServiceById,
  searchCatalogServices,
  createCatalogService,
  updateCatalogService,
  deleteCatalogService,
  getBanners,
  getAdminBanners,
  createBanner,
  uploadBannerImage,
  updateBanner,
  toggleBanner,
  deleteBanner,
  getOffers,
  getAdminOffers,
  createOffer,
  applyOffer,
  updateOffer,
  toggleOffer,
  deleteOffer,
  validateCoupon,
  calculateCheckout,
  getSettings,
  updateSettings,
  getAuditLogs,
  createAuditLog,
  getReviews,
  getAdminReviews,
  approveReview,
  saveReview,
  deleteReview,
  toggleReviewFeatured,
  updateReviewStatus,
  getProfessionals,
  getAdminProfessionals,
  saveProfessional,
  toggleProfessional,
  deleteProfessional,
  getHomepageLayout,
  getAdminHomepageLayout,
  updateHomepageLayout,
  reorderHomepageLayout,
  getPromotions,
  getAdminPromotions,
  savePromotion,
  togglePromotion,
  deletePromotion,
  getSpecialCards,
  getAdminSpecialCards,
  saveSpecialCard,
  toggleSpecialCard,
  deleteSpecialCard,
  getCustomSections,
  getAdminCustomSections,
  getCustomSectionById,
  saveCustomSection,
  deleteCustomSection,
  toggleCustomSection,
  adminLogin,
  getAdminStats,
  getReportsSummary,
  getUsers,
  adjustUserWallet,
  toggleUserStatus
};
