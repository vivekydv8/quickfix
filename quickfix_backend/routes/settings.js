const express = require('express');
const router = express.Router();
const { requireAuth, requireAdmin } = require('../middleware/auth');
const settingsController = require('../controllers/settingsController');
const settingsValidator = require('../validators/settingsValidator');
const { adminLoginLimiter, publicLimiter } = require('../middleware/rateLimiter');

// --- DEMAND ENDPOINTS ---
router.post('/demand/submit', settingsValidator.validateDemandSubmit, settingsController.submitDemand);
router.get('/demand', settingsController.getDemands);

// --- CATEGORY ENDPOINTS ---
router.get('/categories', publicLimiter, settingsController.getCategories);
router.post('/categories/upload-image', requireAdmin, settingsValidator.validateCategoryUploadImage, settingsController.uploadCategoryImage);
router.post('/categories/create', requireAdmin, settingsValidator.validateCategoryCreate, settingsController.createCategory);
router.post('/categories/update', requireAdmin, settingsValidator.validateCategoryUpdate, settingsController.updateCategory);
router.delete('/categories/:id', requireAdmin, settingsController.deleteCategory);

// --- SUBCATEGORY ENDPOINTS ---
router.get('/categories/:categoryId/subcategories', publicLimiter, settingsController.getSubcategories);
router.get('/subcategories', publicLimiter, settingsController.getSubcategories);
router.get('/admin/subcategories', requireAdmin, settingsController.getSubcategories);
router.post('/admin/subcategories', requireAdmin, settingsController.createSubcategory);
router.post('/admin/subcategories/create', requireAdmin, settingsController.createSubcategory);
router.put('/admin/subcategories/:id', requireAdmin, settingsController.updateSubcategory);
router.patch('/admin/subcategories/:id', requireAdmin, settingsController.updateSubcategory);
router.post('/admin/subcategories/update', requireAdmin, settingsController.updateSubcategory);
router.delete('/admin/subcategories/:id', requireAdmin, settingsController.deleteSubcategory);

// --- CATALOG SERVICE ENDPOINTS ---
router.get('/subcategories/:subcategoryId/services', publicLimiter, settingsController.getCatalogServices);
router.get('/categories/:categoryId/services', publicLimiter, settingsController.getCatalogServices);
router.get('/services', publicLimiter, settingsController.getCatalogServices);
router.get('/services/search', publicLimiter, settingsController.searchCatalogServices);
router.get('/services/:id', publicLimiter, settingsController.getCatalogServiceById);
router.get('/admin/catalog-services', requireAdmin, settingsController.getCatalogServices);
router.post('/admin/catalog-services/create', requireAdmin, settingsController.createCatalogService);
router.post('/admin/catalog-services/update', requireAdmin, settingsController.updateCatalogService);
router.delete('/admin/catalog-services/:id', requireAdmin, settingsController.deleteCatalogService);

// --- BANNERS ENDPOINTS ---
router.get('/banners', publicLimiter, settingsController.getBanners);
router.get('/admin/banners', requireAdmin, settingsController.getAdminBanners);
router.post('/banners', requireAdmin, settingsController.createBanner);
router.post('/banners/upload-image', requireAdmin, settingsValidator.validateBannerUploadImage, settingsController.uploadBannerImage);
router.post('/banners/update', requireAdmin, settingsController.updateBanner);
router.post('/banners/toggle', requireAdmin, settingsController.toggleBanner);
router.delete('/banners/:id', requireAdmin, settingsController.deleteBanner);

// --- OFFERS & COUPONS ENDPOINTS ---
router.get('/offers', publicLimiter, settingsController.getOffers);
router.get('/admin/offers', requireAdmin, settingsController.getAdminOffers);
router.post('/offers', requireAdmin, settingsController.createOffer);
router.post('/offers/apply', settingsController.applyOffer);
router.post('/offers/update', requireAdmin, settingsController.updateOffer);
router.post('/offers/toggle', requireAdmin, settingsController.toggleOffer);
router.delete('/offers/:code', requireAdmin, settingsController.deleteOffer);
router.post('/coupons/validate', settingsValidator.validateCouponValidate, settingsController.validateCoupon);

// --- PROMOTIONS ENDPOINTS ---
router.get('/promotions', publicLimiter, settingsController.getPromotions);
router.get('/admin/promotions', requireAdmin, settingsController.getAdminPromotions);
router.post('/promotions', requireAdmin, settingsController.savePromotion);
router.post('/promotions/toggle', requireAdmin, settingsController.togglePromotion);
router.delete('/promotions/:id', requireAdmin, settingsController.deletePromotion);

// --- SPECIAL CARDS ENDPOINTS ---
router.get('/special-cards', publicLimiter, settingsController.getSpecialCards);
router.get('/admin/special-cards', requireAdmin, settingsController.getAdminSpecialCards);
router.post('/special-cards', requireAdmin, settingsController.saveSpecialCard);
router.post('/special-cards/toggle', requireAdmin, settingsController.toggleSpecialCard);
router.delete('/special-cards/:id', requireAdmin, settingsController.deleteSpecialCard);

// --- PRICING CHECKOUT ENDPOINT ---
router.post('/checkout/calculate', settingsValidator.validateCheckoutCalculate, settingsController.calculateCheckout);

// --- GLOBAL SETTINGS ENDPOINTS ---
router.get('/settings', publicLimiter, settingsController.getSettings);
router.post('/settings', requireAdmin, settingsController.updateSettings);

// --- AUDIT LOGS ENDPOINTS ---
router.get('/audit-logs', requireAdmin, settingsController.getAuditLogs);
router.post('/audit-logs', requireAdmin, settingsController.createAuditLog);

// --- REVIEWS FEED ENDPOINTS ---
router.get('/reviews', publicLimiter, settingsController.getReviews);
router.get('/admin/reviews', requireAdmin, settingsController.getAdminReviews);
router.post('/reviews/approve', requireAdmin, settingsController.approveReview);
router.post('/reviews', requireAuth, settingsController.saveReview);
router.post('/reviews/toggle-featured', requireAdmin, settingsController.toggleReviewFeatured);
router.post('/reviews/status', requireAdmin, settingsController.updateReviewStatus);
router.delete('/reviews/:id', requireAdmin, settingsController.deleteReview);

// --- PROFESSIONALS ENDPOINTS ---
router.get('/professionals', publicLimiter, settingsController.getProfessionals);
router.get('/admin/professionals', requireAdmin, settingsController.getAdminProfessionals);
router.post('/professionals', requireAdmin, settingsController.saveProfessional);
router.post('/professionals/toggle', requireAdmin, settingsController.toggleProfessional);
router.delete('/professionals/:id', requireAdmin, settingsController.deleteProfessional);

// --- HOMEPAGE LAYOUTS ENDPOINTS ---
router.get('/homepage/layout', publicLimiter, settingsController.getHomepageLayout);
router.get('/homepage/layout/admin', requireAdmin, settingsController.getAdminHomepageLayout);
router.get('/admin/homepage/layout', requireAdmin, settingsController.getAdminHomepageLayout);
router.post('/homepage/layout/update', requireAdmin, settingsController.updateHomepageLayout);
router.post('/homepage/layout/reorder', requireAdmin, settingsController.reorderHomepageLayout);

// --- CUSTOM SECTIONS ENDPOINTS ---
router.get('/custom-sections', publicLimiter, settingsController.getCustomSections);
router.get('/admin/custom-sections', requireAdmin, settingsController.getAdminCustomSections);
router.get('/custom-sections/:id', publicLimiter, settingsController.getCustomSectionById);
router.post('/custom-sections', requireAdmin, settingsController.saveCustomSection);
router.post('/custom-sections/toggle', requireAdmin, settingsController.toggleCustomSection);
router.delete('/custom-sections/:id', requireAdmin, settingsController.deleteCustomSection);

// --- ADMIN MANAGEMENT ENDPOINTS ---
router.post('/admin/login', adminLoginLimiter, settingsController.adminLogin);
router.get('/admin/stats', requireAdmin, settingsController.getAdminStats);
router.get('/reports/summary', requireAdmin, settingsController.getReportsSummary);

// --- CUSTOMER MANAGEMENT ---
router.get('/users', requireAdmin, settingsController.getUsers);
router.post('/users/wallet-adjust', requireAdmin, settingsValidator.validateWalletAdjust, settingsController.adjustUserWallet);
router.post('/users/toggle-status', requireAdmin, settingsController.toggleUserStatus);

module.exports = router;
