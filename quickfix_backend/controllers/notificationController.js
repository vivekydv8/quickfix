const notificationService = require('../services/notificationService');

async function fetchNotifications(req, res) {
  try {
    const result = await notificationService.getNotifications(req);
    res.json(result);
  } catch (e) {
    res.status(500).json({ success: false, error: 'Failed to fetch notifications' });
  }
}

async function markNotificationAsRead(req, res) {
  try {
    const result = await notificationService.markAsRead(req, req.params.id);
    if (result.error) {
      return res.status(result.status || 400).json({ success: false, error: result.error });
    }
    res.json(result);
  } catch (e) {
    res.status(500).json({ success: false, error: 'Failed to mark notification as read' });
  }
}

async function markAllNotificationsAsRead(req, res) {
  try {
    const result = await notificationService.markAllAsRead(req);
    if (result.error) {
      return res.status(result.status || 400).json({ success: false, error: result.error });
    }
    res.json(result);
  } catch (e) {
    res.status(500).json({ success: false, error: 'Failed to mark all notifications as read' });
  }
}

async function deleteNotification(req, res) {
  try {
    const result = await notificationService.deleteNotification(req, req.params.id);
    if (result.error) {
      return res.status(result.status || 400).json({ success: false, error: result.error });
    }
    res.json(result);
  } catch (e) {
    res.status(500).json({ success: false, error: 'Failed to delete notification' });
  }
}

async function deleteAllNotifications(req, res) {
  try {
    const result = await notificationService.deleteAllNotifications(req);
    if (result.error) {
      return res.status(result.status || 400).json({ success: false, error: result.error });
    }
    res.json(result);
  } catch (e) {
    res.status(500).json({ success: false, error: 'Failed to delete all notifications' });
  }
}

async function fetchUnreadCount(req, res) {
  try {
    const result = await notificationService.getUnreadCount(req);
    res.json(result);
  } catch (e) {
    res.status(500).json({ success: false, error: 'Failed to fetch unread notification count' });
  }
}

async function triggerNotification(req, res) {
  try {
    const newAlert = await notificationService.sendNotification(req.body);
    res.json({ success: true, alert: newAlert });
  } catch (e) {
    res.status(500).json({ success: false, error: 'Failed to send alert notification' });
  }
}

module.exports = {
  fetchNotifications,
  markNotificationAsRead,
  markAllNotificationsAsRead,
  deleteNotification,
  deleteAllNotifications,
  fetchUnreadCount,
  triggerNotification
};
