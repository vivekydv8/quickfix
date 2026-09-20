const settingsService = require('../services/settingsService');
const { logger } = require('../config/logger');

async function submitDemand(req, res) {
  const { phone, address, latitude, longitude } = req.body;
  try {
    const demand = await settingsService.submitDemand(phone, address, latitude, longitude);
    res.json({ success: true, demand });
  } catch (e) {
    console.error('Failed to save demand:', e);
    res.status(500).json({ error: 'Failed to save demand' });
  }
}

async function getDemands(req, res) {
  try {
    const demands = await settingsService.getDemands();
    res.json(demands);
  } catch (e) {
    console.error('Failed to fetch demands:', e);
    res.status(500).json({ error: 'Failed to fetch demands' });
  }
}

async function getCategories(req, res) {
  try {
    const list = await settingsService.getCategories();
    res.json(list);
  } catch (e) {
    res.status(500).json({ error: 'Failed to load categories' });
  }
}

async function uploadCategoryImage(req, res) {
  const { base64Image } = req.body;
  try {
    const imageUrl = await settingsService.uploadCategoryImage(base64Image, req.validatedMime);
    res.json({ success: true, imageUrl });
  } catch (e) {
    console.error('Cloudinary category image upload error:', e.message || e);
    res.status(500).json({ error: `Failed to upload category image: ${e.message || e}` });
  }
}

async function createCategory(req, res) {
  const { id, name, iconUrl } = req.body;
  try {
    const category = await settingsService.createCategory(id, name, iconUrl);
    res.json({ success: true, category });
  } catch (e) {
    res.status(500).json({ error: 'Failed to create category' });
  }
}

async function updateCategory(req, res) {
  const { id, name, iconUrl } = req.body;
  try {
    const category = await settingsService.updateCategory(id, name, iconUrl);
    res.json({ success: true, category });
  } catch (e) {
    if (e.message === 'Category not found') {
      return res.status(404).json({ error: e.message });
    }
    res.status(500).json({ error: 'Failed to update category' });
  }
}

async function deleteCategory(req, res) {
  try {
    const deleted = await settingsService.deleteCategory(req.params.id);
    if (deleted) {
      res.json({ success: true });
    } else {
      res.status(404).json({ error: 'Category not found' });
    }
  } catch (e) {
    res.status(500).json({ error: 'Failed to delete category' });
  }
}

// --- SUBCATEGORY HANDLERS ---
async function getSubcategories(req, res) {
  const categoryId = req.params.categoryId || req.query.categoryId;
  const isFromAdmin = (req.originalUrl || req.url || '').includes('/admin') || (req.path || '').includes('/admin');
  const includeInactive = req.query.includeInactive === 'true' || req.query.all === 'true' || (isFromAdmin && req.query.includeInactive !== 'false');
  try {
    const list = await settingsService.getSubcategories(categoryId, includeInactive);
    res.json(list);
  } catch (e) {
    res.status(500).json({ error: 'Failed to load subcategories' });
  }
}

async function createSubcategory(req, res) {
  try {
    const subcat = await settingsService.createSubcategory(req.body);
    res.json({ success: true, subcategory: subcat });
  } catch (e) {
    res.status(500).json({ error: e.message || 'Failed to create subcategory' });
  }
}

async function updateSubcategory(req, res) {
  const id = req.params.id || req.body.id;
  try {
    const subcat = await settingsService.updateSubcategory(id, req.body);
    res.json({ success: true, subcategory: subcat });
  } catch (e) {
    if (e.message === 'Subcategory not found') {
      return res.status(404).json({ error: e.message });
    }
    res.status(500).json({ error: e.message || 'Failed to update subcategory' });
  }
}

async function deleteSubcategory(req, res) {
  const id = req.params.id || req.body.id;
  try {
    const deleted = await settingsService.deleteSubcategory(id);
    if (deleted) {
      res.json({ success: true });
    } else {
      res.status(404).json({ error: 'Subcategory not found' });
    }
  } catch (e) {
    res.status(500).json({ error: 'Failed to delete subcategory' });
  }
}

// --- CATALOG SERVICE HANDLERS ---
async function getCatalogServices(req, res) {
  const subcategoryId = req.params.subcategoryId || req.query.subcategoryId;
  const categoryId = req.params.categoryId || req.query.categoryId;
  const includeInactive = req.query.includeInactive === 'true' || req.query.all === 'true';
  try {
    const list = await settingsService.getCatalogServices(subcategoryId, categoryId, includeInactive);
    res.json(list);
  } catch (e) {
    res.status(500).json({ error: 'Failed to load services' });
  }
}

async function getCatalogServiceById(req, res) {
  try {
    const srv = await settingsService.getCatalogServiceById(req.params.id);
    res.json(srv);
  } catch (e) {
    if (e.message === 'Service not found') {
      return res.status(404).json({ error: e.message });
    }
    res.status(500).json({ error: 'Failed to fetch service details' });
  }
}

async function searchCatalogServices(req, res) {
  const query = req.query.q || req.query.query || '';
  try {
    const results = await settingsService.searchCatalogServices(query);
    res.json(results);
  } catch (e) {
    res.status(500).json({ error: 'Failed to search catalog services' });
  }
}

async function createCatalogService(req, res) {
  try {
    const srv = await settingsService.createCatalogService(req.body);
    res.json({ success: true, service: srv });
  } catch (e) {
    res.status(500).json({ error: e.message || 'Failed to create service' });
  }
}

async function updateCatalogService(req, res) {
  const id = req.params.id || req.body.id;
  try {
    const srv = await settingsService.updateCatalogService(id, req.body);
    res.json({ success: true, service: srv });
  } catch (e) {
    if (e.message === 'Catalog service not found') {
      return res.status(404).json({ error: e.message });
    }
    res.status(500).json({ error: e.message || 'Failed to update service' });
  }
}

async function deleteCatalogService(req, res) {
  const id = req.params.id || req.body.id;
  try {
    const deleted = await settingsService.deleteCatalogService(id);
    if (deleted) {
      res.json({ success: true });
    } else {
      res.status(404).json({ error: 'Service not found' });
    }
  } catch (e) {
    res.status(500).json({ error: 'Failed to delete service' });
  }
}

async function getBanners(req, res) {
  try {
    const banners = await settingsService.getBanners(false);
    res.json(banners);
  } catch (e) {
    res.status(500).json({ error: 'Failed to fetch banners' });
  }
}

async function getAdminBanners(req, res) {
  try {
    const banners = await settingsService.getAdminBanners();
    res.json(banners);
  } catch (e) {
    res.status(500).json({ error: 'Failed to fetch admin banners' });
  }
}

async function createBanner(req, res) {
  try {
    const banner = await settingsService.createBanner(req.body);
    res.json({ success: true, banner });
  } catch (e) {
    res.status(500).json({ error: 'Failed to create banner' });
  }
}

async function uploadBannerImage(req, res) {
  const { base64Image } = req.body;
  try {
    const imageUrl = await settingsService.uploadBannerImage(base64Image, req.validatedMime);
    res.json({ success: true, imageUrl });
  } catch (e) {
    console.error('Cloudinary banner image upload error:', e.message || e);
    res.status(500).json({ error: `Failed to upload banner image: ${e.message || e}` });
  }
}

async function updateBanner(req, res) {
  const { id } = req.body;
  try {
    const banner = await settingsService.updateBanner(id, req.body);
    res.json({ success: true, banner });
  } catch (e) {
    if (e.message === 'Banner not found') {
      return res.status(404).json({ error: e.message });
    }
    res.status(500).json({ error: 'Failed to update banner' });
  }
}

async function toggleBanner(req, res) {
  const { id } = req.body;
  try {
    const banner = await settingsService.toggleBanner(id);
    res.json({ success: true, banner });
  } catch (e) {
    if (e.message === 'Banner not found') {
      return res.status(404).json({ error: e.message });
    }
    res.status(500).json({ error: 'Toggle banner failed' });
  }
}

async function deleteBanner(req, res) {
  try {
    const deleted = await settingsService.deleteBanner(req.params.id);
    res.json({ success: true, banner: deleted });
  } catch (e) {
    if (e.message === 'Banner not found') {
      return res.status(404).json({ error: e.message });
    }
    res.status(500).json({ error: 'Delete banner failed' });
  }
}

async function getOffers(req, res) {
  try {
    const offers = await settingsService.getOffers(true); // Return all offers for admin/client view
    res.json(offers);
  } catch (e) {
    res.status(500).json({ error: 'Failed to fetch offers' });
  }
}

async function getAdminOffers(req, res) {
  try {
    const offers = await settingsService.getAdminOffers();
    res.json(offers);
  } catch (e) {
    res.status(500).json({ error: 'Failed to fetch admin offers' });
  }
}

async function createOffer(req, res) {
  try {
    const offer = await settingsService.createOffer(req.body);
    res.json({ success: true, offer });
  } catch (e) {
    res.status(500).json({ error: e.message || 'Failed to create offer' });
  }
}

async function applyOffer(req, res) {
  const { code, amount } = req.body;
  try {
    const result = await settingsService.applyOffer(code, amount);
    res.json(result);
  } catch (e) {
    if (e.message === 'Invalid or expired coupon code') {
      return res.status(400).json({ error: e.message });
    }
    res.status(500).json({ error: 'Failed to apply offer' });
  }
}

async function updateOffer(req, res) {
  const { code } = req.body;
  try {
    const offer = await settingsService.updateOffer(code, req.body);
    res.json({ success: true, offer });
  } catch (e) {
    if (e.message === 'Offer not found') {
      return res.status(404).json({ error: e.message });
    }
    res.status(500).json({ error: 'Failed to update offer' });
  }
}

async function toggleOffer(req, res) {
  const { code } = req.body;
  try {
    const offer = await settingsService.toggleOffer(code);
    res.json({ success: true, offer });
  } catch (e) {
    if (e.message === 'Offer not found') {
      return res.status(404).json({ error: e.message });
    }
    res.status(500).json({ error: 'Toggle offer failed' });
  }
}

async function deleteOffer(req, res) {
  try {
    const deleted = await settingsService.deleteOffer(req.params.code);
    res.json({ success: true, offer: deleted });
  } catch (e) {
    if (e.message === 'Offer not found') {
      return res.status(404).json({ error: e.message });
    }
    res.status(500).json({ error: 'Delete offer failed' });
  }
}

async function validateCoupon(req, res) {
  const { code, amount } = req.body;
  try {
    const discount = await settingsService.validateCoupon(code, amount);
    res.json({ success: true, code, discount });
  } catch (e) {
    if (e.message === 'Invalid or expired coupon code') {
      return res.status(404).json({ error: e.message });
    }
    res.status(500).json({ error: 'Coupon validation failed' });
  }
}

async function calculateCheckout(req, res) {
  const { shopId, items, couponCode } = req.body;
  try {
    const result = await settingsService.calculateCheckout(shopId, items, couponCode);
    res.json({ success: true, ...result });
  } catch (e) {
    if (e.message === 'Shop not found') {
      return res.status(404).json({ error: e.message });
    }
    console.error('Calculate pricing failed:', e);
    res.status(500).json({ error: 'Failed to calculate pricing' });
  }
}

async function getSettings(req, res) {
  try {
    const settings = await settingsService.getSettings();
    res.json(settings);
  } catch (e) {
    res.status(500).json({ error: 'Failed to load app settings' });
  }
}

async function updateSettings(req, res) {
  try {
    await settingsService.updateSettings(req.body);
    res.json({ success: true });
  } catch (e) {
    res.status(500).json({ error: 'Failed to update settings' });
  }
}

async function getAuditLogs(req, res) {
  try {
    const logs = await settingsService.getAuditLogs();
    res.json(logs);
  } catch (e) {
    res.status(500).json({ error: 'Failed to load audit logs' });
  }
}

async function createAuditLog(req, res) {
  const { action, target, details } = req.body;
  try {
    const log = await settingsService.createAuditLog(action, target, details, req.ip);
    res.json({ success: true, log });
  } catch (e) {
    res.status(500).json({ error: 'Failed to create audit log' });
  }
}

async function getReviews(req, res) {
  try {
    const result = await settingsService.getReviews(req);
    res.json(result);
  } catch (e) {
    res.status(500).json({ error: 'Failed to load reviews feed' });
  }
}

async function getAdminReviews(req, res) {
  try {
    const result = await settingsService.getAdminReviews(req);
    res.json(result);
  } catch (e) {
    res.status(500).json({ error: 'Failed to load admin reviews' });
  }
}

async function approveReview(req, res) {
  const { id, status } = req.body;
  try {
    const review = await settingsService.approveReview(id, status);
    res.json({ success: true, review });
  } catch (e) {
    if (e.message === 'Review not found') {
      return res.status(404).json({ error: e.message });
    }
    res.status(500).json({ error: 'Failed to update review approval status' });
  }
}

async function saveReview(req, res) {
  const { id } = req.body;
  try {
    const review = await settingsService.saveReview(id, req.body);
    res.json({ success: true, review });
  } catch (e) {
    if (e.message === 'Review not found') {
      return res.status(404).json({ error: e.message });
    }
    console.error('Error saving review:', e);
    res.status(500).json({ error: 'Failed to save review details' });
  }
}

async function deleteReview(req, res) {
  try {
    const deleted = await settingsService.deleteReview(req.params.id);
    res.json({ success: true, review: deleted });
  } catch (e) {
    if (e.message === 'Review not found') {
      return res.status(404).json({ error: e.message });
    }
    res.status(500).json({ error: 'Failed to delete review' });
  }
}

async function getProfessionals(req, res) {
  const { sort, lat, lng } = req.query;
  try {
    const syncedList = await settingsService.getProfessionals(sort, lat, lng);
    res.json(syncedList);
  } catch (e) {
    res.status(500).json({ error: 'Failed to fetch professionals' });
  }
}

async function getHomepageLayout(req, res) {
  try {
    const list = await settingsService.getHomepageLayout();
    res.json(list);
  } catch (e) {
    res.status(500).json({ error: 'Failed to load layout layout' });
  }
}

async function getAdminHomepageLayout(req, res) {
  try {
    const list = await settingsService.getAdminHomepageLayout();
    res.json(list);
  } catch (e) {
    res.status(500).json({ error: 'Failed to load layout admin view' });
  }
}

async function updateHomepageLayout(req, res) {
  const { id, title, isActive, priority, settings } = req.body;
  try {
    const section = await settingsService.updateHomepageLayout(id, title, isActive, priority, settings);
    res.json({ success: true, section });
  } catch (e) {
    if (e.message === 'Layout section not found') {
      return res.status(404).json({ error: e.message });
    }
    res.status(500).json({ error: 'Failed to update layout section' });
  }
}

async function reorderHomepageLayout(req, res) {
  const { orderList } = req.body;
  try {
    await settingsService.reorderHomepageLayout(orderList);
    res.json({ success: true });
  } catch (e) {
    res.status(500).json({ error: 'Failed to reorder layout' });
  }
}

async function getCustomSections(req, res) {
  try {
    const list = await settingsService.getCustomSections();
    res.json(list);
  } catch (e) {
    res.status(500).json({ error: 'Failed to load custom sections' });
  }
}

async function getAdminCustomSections(req, res) {
  try {
    const list = await settingsService.getAdminCustomSections();
    res.json(list);
  } catch (e) {
    res.status(500).json({ error: 'Failed to load all custom sections' });
  }
}

async function getCustomSectionById(req, res) {
  try {
    const section = await settingsService.getCustomSectionById(req.params.id);
    res.json(section);
  } catch (e) {
    if (e.message === 'Custom section not found') {
      return res.status(404).json({ error: e.message });
    }
    res.status(500).json({ error: 'Failed to fetch custom section' });
  }
}

async function saveCustomSection(req, res) {
  const { id } = req.body;
  try {
    const section = await settingsService.saveCustomSection(id, req.body);
    res.json({ success: true, section });
  } catch (e) {
    if (e.message === 'Custom section not found') {
      return res.status(404).json({ error: e.message });
    }
    console.error('Failed to update custom section:', e);
    res.status(500).json({ error: 'Failed to save custom section details' });
  }
}

async function deleteCustomSection(req, res) {
  try {
    await settingsService.deleteCustomSection(req.params.id);
    res.json({ success: true });
  } catch (e) {
    if (e.message === 'Custom section not found') {
      return res.status(404).json({ error: e.message });
    }
    res.status(500).json({ error: 'Failed to delete custom section' });
  }
}

async function adminLogin(req, res) {
  const { password } = req.body;
  try {
    const token = await settingsService.adminLogin(password);
    res.json({ success: true, token });
  } catch (e) {
    logger.error('Admin login error:', e);
    res.status(e.statusCode || 500).json({ success: false, error: e.message || 'Admin login failed' });
  }
}

async function getAdminStats(req, res) {
  try {
    const stats = await settingsService.getAdminStats();
    res.json(stats);
  } catch (e) {
    console.error('Stats error:', e);
    res.status(500).json({ error: 'Failed to load system stats' });
  }
}

async function getReportsSummary(req, res) {
  try {
    const reports = await settingsService.getReportsSummary();
    res.json(reports);
  } catch (e) {
    console.error('Reports summary error:', e);
    res.status(500).json({ error: 'Failed to load report data' });
  }
}

async function getUsers(req, res) {
  try {
    const result = await settingsService.getUsers(req);
    res.json(result);
  } catch (e) {
    res.status(500).json({ error: 'Failed to fetch users' });
  }
}

async function adjustUserWallet(req, res) {
  const { userId, amount, type, title } = req.body;
  try {
    const walletBalance = await settingsService.adjustUserWallet(userId, amount, type, title);
    res.json({ success: true, walletBalance });
  } catch (e) {
    if (e.message === 'User not found') {
      return res.status(404).json({ error: e.message });
    }
    res.status(500).json({ error: 'Failed to adjust wallet' });
  }
}

async function toggleUserStatus(req, res) {
  const { userId } = req.body;
  try {
    const status = await settingsService.toggleUserStatus(userId);
    res.json({ success: true, status });
  } catch (e) {
    if (e.message === 'User not found') {
      return res.status(404).json({ error: e.message });
    }
    res.status(500).json({ error: 'Failed to update user status' });
  }
}

// --- PROMOTIONS ---
async function getPromotions(req, res) {
  try {
    const list = await settingsService.getPromotions(false);
    res.json(list);
  } catch (e) {
    res.status(500).json({ error: 'Failed to load promotions' });
  }
}

async function getAdminPromotions(req, res) {
  try {
    const list = await settingsService.getAdminPromotions();
    res.json(list);
  } catch (e) {
    res.status(500).json({ error: 'Failed to load admin promotions' });
  }
}

async function savePromotion(req, res) {
  try {
    const promotion = await settingsService.savePromotion(req.body.id, req.body);
    res.json({ success: true, promotion });
  } catch (e) {
    res.status(500).json({ error: 'Failed to save promotion' });
  }
}

async function togglePromotion(req, res) {
  try {
    await settingsService.togglePromotion(req.body.id);
    res.json({ success: true });
  } catch (e) {
    res.status(500).json({ error: 'Failed to toggle promotion' });
  }
}

async function deletePromotion(req, res) {
  try {
    await settingsService.deletePromotion(req.params.id);
    res.json({ success: true });
  } catch (e) {
    res.status(500).json({ error: 'Failed to delete promotion' });
  }
}

// --- SPECIAL CARDS ---
async function getSpecialCards(req, res) {
  try {
    const list = await settingsService.getSpecialCards(false);
    res.json(list);
  } catch (e) {
    res.status(500).json({ error: 'Failed to load special cards' });
  }
}

async function getAdminSpecialCards(req, res) {
  try {
    const list = await settingsService.getAdminSpecialCards();
    res.json(list);
  } catch (e) {
    res.status(500).json({ error: 'Failed to load admin special cards' });
  }
}

async function saveSpecialCard(req, res) {
  try {
    const card = await settingsService.saveSpecialCard(req.body.id, req.body);
    res.json({ success: true, card });
  } catch (e) {
    res.status(500).json({ error: 'Failed to save special card' });
  }
}

async function toggleSpecialCard(req, res) {
  try {
    await settingsService.toggleSpecialCard(req.body.id);
    res.json({ success: true });
  } catch (e) {
    res.status(500).json({ error: 'Failed to toggle special card' });
  }
}

async function deleteSpecialCard(req, res) {
  try {
    await settingsService.deleteSpecialCard(req.params.id);
    res.json({ success: true });
  } catch (e) {
    res.status(500).json({ error: 'Failed to delete special card' });
  }
}

// --- PROFESSIONALS / FEATURED EXPERTS ---
async function getAdminProfessionals(req, res) {
  try {
    const list = await settingsService.getAdminProfessionals();
    res.json(list);
  } catch (e) {
    res.status(500).json({ error: 'Failed to load admin professionals' });
  }
}

async function saveProfessional(req, res) {
  try {
    const professional = await settingsService.saveProfessional(req.body.id, req.body);
    res.json({ success: true, professional });
  } catch (e) {
    res.status(500).json({ error: 'Failed to save professional profile' });
  }
}

async function toggleProfessional(req, res) {
  try {
    await settingsService.toggleProfessional(req.body.id);
    res.json({ success: true });
  } catch (e) {
    res.status(500).json({ error: 'Failed to toggle professional' });
  }
}

async function deleteProfessional(req, res) {
  try {
    await settingsService.deleteProfessional(req.params.id);
    res.json({ success: true });
  } catch (e) {
    res.status(500).json({ error: 'Failed to delete professional' });
  }
}

// --- REVIEWS EXTENSIONS ---
async function toggleReviewFeatured(req, res) {
  try {
    await settingsService.toggleReviewFeatured(req.body.id);
    res.json({ success: true });
  } catch (e) {
    res.status(500).json({ error: 'Failed to toggle review featured status' });
  }
}

async function updateReviewStatus(req, res) {
  try {
    await settingsService.updateReviewStatus(req.body.id, req.body.status);
    res.json({ success: true });
  } catch (e) {
    res.status(500).json({ error: 'Failed to update review status' });
  }
}

// --- CUSTOM SECTIONS EXTENSIONS ---
async function toggleCustomSection(req, res) {
  try {
    await settingsService.toggleCustomSection(req.body.id);
    res.json({ success: true });
  } catch (e) {
    res.status(500).json({ error: 'Failed to toggle custom section' });
  }
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
