const { Notification } = require('../models');
const { sendFcmTopicNotification } = require('../helpers');

function formatNotification(doc, customerId) {
  const obj = doc && typeof doc.toObject === 'function' ? doc.toObject() : { ...doc };
  const isBroadcast = !obj.userId || obj.userId === '';
  const isRead = isBroadcast
    ? Boolean(obj.readBy && Array.isArray(obj.readBy) && obj.readBy.includes(customerId))
    : Boolean(obj.isRead);

  return {
    id: obj.id || String(obj._id),
    _id: obj._id ? String(obj._id) : obj.id,
    title: obj.title || '',
    body: obj.body || '',
    time: obj.time || obj.createdAt || new Date().toISOString(),
    createdAt: obj.createdAt || obj.time || new Date().toISOString(),
    icon: obj.icon || 'notifications_active',
    iconColor: obj.iconColor || 'primary',
    userId: obj.userId || '',
    shopId: obj.shopId || '',
    type: obj.type || 'general',
    bookingId: obj.bookingId || '',
    deepLink: obj.deepLink || '',
    isRead: isRead,
    readAt: obj.readAt || null
  };
}

async function getNotifications(req) {
  const customerId = req.user ? String(req.user.id || req.user._id || '') : '';
  const isPartner = req.user && req.user.role === 'partner';
  const targetShopId = isPartner ? String(req.user.shopId || req.user.id || '') : '';

  const conditions = [
    { userId: '', shopId: '' },
    { userId: { $exists: false } }
  ];

  if (customerId && !isPartner) {
    conditions.push({ userId: customerId });
  }
  if (targetShopId) {
    conditions.push({ shopId: targetShopId });
  }

  const query = {
    $and: [
      { $or: conditions }
    ]
  };

  if (customerId) {
    query.$and.push({ deletedBy: { $ne: customerId } });
  }

  let results = await Notification.find(query);
  if (results && typeof results.sort === 'function') {
    results = await results.sort({ createdAt: -1 });
  }

  const list = Array.isArray(results) ? results : [];
  const formatted = list.map(doc => formatNotification(doc, customerId));

  // Sort descending by timestamp
  formatted.sort((a, b) => {
    const timeA = new Date(a.createdAt || a.time).getTime() || 0;
    const timeB = new Date(b.createdAt || b.time).getTime() || 0;
    return timeB - timeA;
  });

  return formatted;
}

async function markAsRead(req, notificationId) {
  const customerId = req.user ? String(req.user.id || req.user._id || '') : '';
  if (!customerId) {
    return { error: 'Unauthorized: Authentication required', status: 401 };
  }

  let notif = await Notification.findOne({ id: notificationId });
  if (!notif) {
    try { notif = await Notification.findById(notificationId); } catch (_) {}
  }
  if (!notif) {
    return { error: 'Notification not found', status: 404 };
  }

  const notifUserId = notif.userId ? String(notif.userId) : '';
  const isBroadcast = !notifUserId;

  // Authorization check (prevent IDOR)
  if (!isBroadcast && notifUserId !== customerId) {
    return { error: 'Forbidden: You do not own this notification', status: 403 };
  }

  // Check if previously deleted by customer
  if (notif.deletedBy && Array.isArray(notif.deletedBy) && notif.deletedBy.includes(customerId)) {
    return { error: 'Notification not found', status: 404 };
  }

  if (isBroadcast) {
    await Notification.updateOne(
      { _id: notif._id },
      { $addToSet: { readBy: customerId } }
    );
    if (!notif.readBy) notif.readBy = [];
    if (!notif.readBy.includes(customerId)) {
      notif.readBy.push(customerId);
    }
  } else {
    notif.isRead = true;
    notif.readAt = new Date();
    await notif.save();
  }

  return {
    success: true,
    notification: formatNotification(notif, customerId)
  };
}

async function markAllAsRead(req) {
  const customerId = req.user ? String(req.user.id || req.user._id || '') : '';
  if (!customerId) {
    return { error: 'Unauthorized: Authentication required', status: 401 };
  }

  // 1. Mark customer-specific notifications
  await Notification.updateMany(
    { userId: customerId, isRead: { $ne: true } },
    { $set: { isRead: true, readAt: new Date() } }
  );

  // 2. Mark broadcast notifications as read for this customer
  await Notification.updateMany(
    {
      $and: [
        { $or: [{ userId: '' }, { userId: { $exists: false } }] },
        { deletedBy: { $ne: customerId } }
      ]
    },
    { $addToSet: { readBy: customerId } }
  );

  return { success: true, message: 'All notifications marked as read' };
}

async function deleteNotification(req, notificationId) {
  const customerId = req.user ? String(req.user.id || req.user._id || '') : '';
  if (!customerId) {
    return { error: 'Unauthorized: Authentication required', status: 401 };
  }

  let notif = await Notification.findOne({ id: notificationId });
  if (!notif) {
    try { notif = await Notification.findById(notificationId); } catch (_) {}
  }
  if (!notif) {
    return { error: 'Notification not found', status: 404 };
  }

  const notifUserId = notif.userId ? String(notif.userId) : '';
  const isBroadcast = !notifUserId;

  // Authorization check (prevent IDOR)
  if (!isBroadcast && notifUserId !== customerId) {
    return { error: 'Forbidden: You cannot delete another customer\'s notification', status: 403 };
  }

  if (!isBroadcast) {
    // Permanent physical removal from database
    await Notification.deleteOne({ _id: notif._id });
  } else {
    // Broadcast notification: permanently excluded from this customer's feed
    await Notification.updateOne(
      { _id: notif._id },
      { $addToSet: { deletedBy: customerId } }
    );
  }

  return {
    success: true,
    message: 'Notification permanently deleted',
    id: notificationId
  };
}

async function deleteAllNotifications(req) {
  const customerId = req.user ? String(req.user.id || req.user._id || '') : '';
  if (!customerId) {
    return { error: 'Unauthorized: Authentication required', status: 401 };
  }

  // 1. Permanently delete all customer-specific notifications
  await Notification.deleteMany({ userId: customerId });

  // 2. Exclude all broadcast notifications for this customer
  await Notification.updateMany(
    { $or: [{ userId: '' }, { userId: { $exists: false } }] },
    { $addToSet: { deletedBy: customerId } }
  );

  return {
    success: true,
    message: 'All notifications permanently deleted'
  };
}

async function getUnreadCount(req) {
  const notifications = await getNotifications(req);
  const count = notifications.filter(n => !n.isRead).length;
  return { success: true, count };
}

async function sendNotification(data) {
  const { title, body, icon, iconColor, audience } = data;
  const newAlert = new Notification({
    id: `alert-${Date.now()}`,
    title,
    body,
    time: new Date().toISOString(),
    icon: icon || 'notifications_active',
    iconColor: iconColor || 'primary',
    type: 'broadcast',
    isRead: false,
    readBy: [],
    deletedBy: []
  });
  await newAlert.save();

  const payload = {
    type: 'broadcast',
    title: title || 'QuickFix Update',
    body: body || '',
    icon: icon || 'notifications_active',
    iconColor: iconColor || 'primary',
    notificationId: newAlert.id,
    id: newAlert.id
  };

  const targetAudience = (audience || 'customers').toLowerCase();

  if (targetAudience === 'shops' || targetAudience === 'providers' || targetAudience === 'partners') {
    sendFcmTopicNotification('providers', title, body, payload);
  } else if (targetAudience === 'all') {
    sendFcmTopicNotification('customers', title, body, payload);
    sendFcmTopicNotification('providers', title, body, payload);
  } else {
    sendFcmTopicNotification('customers', title, body, payload);
  }

  return newAlert;
}

module.exports = {
  getNotifications,
  markAsRead,
  markAllAsRead,
  deleteNotification,
  deleteAllNotifications,
  getUnreadCount,
  sendNotification
};
