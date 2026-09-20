const express = require('express');
const router = express.Router();
const notificationController = require('../controllers/notificationController');
const notificationValidator = require('../validators/notificationValidator');
const { requireAuth, optionalAuth } = require('../middleware/auth');

router.get('/', optionalAuth, notificationController.fetchNotifications);
router.get('/unread-count', requireAuth, notificationController.fetchUnreadCount);
router.patch('/read-all', requireAuth, notificationController.markAllNotificationsAsRead);
router.patch('/:id/read', requireAuth, notificationValidator.validateNotificationId, notificationController.markNotificationAsRead);
router.delete('/:id', requireAuth, notificationValidator.validateNotificationId, notificationController.deleteNotification);
router.delete('/', requireAuth, notificationController.deleteAllNotifications);
router.post('/send', notificationValidator.validateSendNotification, notificationController.triggerNotification);

module.exports = router;
