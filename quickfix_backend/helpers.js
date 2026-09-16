const admin = require('./config/firebase');
const cloudinary = require('./config/cloudinary');
const { User, Shop, PaymentAuditLog } = require('./models');

// Haversine distance calculator
function calculateDistance(lat1, lon1, lat2, lon2) {
  if (lat1 === undefined || lon1 === undefined || lat2 === undefined || lon2 === undefined) return 0.0;
  const R = 6371; // Radius of the earth in km
  const dLat = (lat2 - lat1) * Math.PI / 180;
  const dLon = (lon2 - lon1) * Math.PI / 180;
  const a = 
    Math.sin(dLat/2) * Math.sin(dLat/2) +
    Math.cos(lat1 * Math.PI / 180) * Math.cos(lat2 * Math.PI / 180) * 
    Math.sin(dLon/2) * Math.sin(dLon/2);
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1-a));
  return parseFloat((R * c).toFixed(2));
}

// Sanitize Booking for Provider Privacy (masking customer address/details unless accepted/in_progress)
function sanitizeBookingForPrivacy(booking) {
  if (!booking) return null;
  const b = booking.toObject ? booking.toObject() : { ...booking };
  
  // Mask customer address if status is pending or quote_sent (unaccepted booking states)
  const isUnaccepted = b.status === 'pending' || b.status === 'quote_sent' || b.status === 'rejected' || b.status === 'cancelled';
  if (isUnaccepted) {
    if (b.customerAddress) {
      // Keep only general city/area info, hide precise house/street details
      const parts = b.customerAddress.split(',');
      if (parts.length > 2) {
        b.customerAddress = `General Area (Accepted state only), ${parts.slice(-2).join(',').trim()}`;
      } else {
        b.customerAddress = 'General Area (Details hidden)';
      }
    }
    // Mask phone number
    if (b.customerPhone) {
      b.customerPhone = b.customerPhone.replace(/(\d{4})\d{4}(\d{2})/, '$1XXXX$2');
    }
  }
  return b;
}

// FCM Push Notification Helper for individual User
async function sendFcmNotification(targetId, title, body, data = {}, targetType = 'user') {
  try {
    const isPartner = targetType === 'partner' || targetType === 'shop';

    // 1. ALWAYS persist notification to DB so in-app notifications screen receives it
    try {
      const { Notification } = require('./models');
      const newNotif = new Notification({
        id: `notif-${Date.now()}-${Math.floor(Math.random() * 10000)}`,
        title,
        body,
        time: new Date().toISOString(),
        icon: data.icon || (isPartner ? 'work' : 'notifications_active'),
        iconColor: data.iconColor || 'primary',
        userId: !isPartner ? String(targetId) : '',
        shopId: isPartner ? String(targetId) : '',
        type: data.type || 'general',
        bookingId: data.bookingId || '',
        deepLink: data.deepLink || ''
      });
      await newNotif.save();
    } catch (dbErr) {
      console.error('Failed to persist notification to DB:', dbErr.message);
    }

    // 2. Check if Firebase Admin is available for OS Push Notification
    if (!admin.apps || !admin.apps.length) {
      console.warn("FCM NOT SENT: Firebase Admin SDK is not initialized on server. In-app notification was saved to DB.");
      return false;
    }

    if (targetType === 'user') {
      let user = null;
      try { user = await User.findById(targetId); } catch (_) {}
      if (!user) user = await User.findOne({ id: targetId });
      if (!user) user = await User.findOne({ _id: targetId });
      if (!user) user = await User.findOne({ phone: targetId });
      token = user ? (user.fcmToken || '') : '';
    } else {
      let shop = null;
      try { shop = await Shop.findById(targetId); } catch (_) {}
      if (!shop) shop = await Shop.findOne({ id: targetId });
      if (!shop) shop = await Shop.findOne({ _id: targetId });
      if (!shop) shop = await Shop.findOne({ phone: targetId });
      token = shop ? (shop.fcmToken || '') : '';
    }

    if (!token || token.trim() === '') {
      console.log(`FCM NOT SENT: No FCM token registered for ${targetType} ${targetId}`);
      return false;
    }

    const channelId = isPartner ? 'booking_alert_channel' : 'high_importance_channel';
    const sound = isPartner ? 'alert_ring' : 'default';

    const stringifiedData = {};
    for (const [k, v] of Object.entries(data)) {
      stringifiedData[k] = String(v);
    }
    stringifiedData['click_action'] = 'FLUTTER_NOTIFICATION_CLICK';

    const message = {
      notification: { title, body },
      token: token,
      data: stringifiedData,
      android: {
        priority: 'high',
        ttl: 3600000,
        notification: {
          sound: sound,
          clickAction: 'FLUTTER_NOTIFICATION_CLICK',
          channelId: channelId,
          icon: 'ic_notification',
          priority: 'max',
          defaultSound: !isPartner,
          defaultVibrateTimings: true,
          notificationCount: 1,
        }
      },
      apns: {
        payload: {
          aps: {
            sound: sound === 'default' ? 'default' : `${sound}.wav`,
            badge: 1,
            contentAvailable: true,
          }
        }
      }
    };

    const response = await admin.messaging().send(message);
    console.log(`✅ FCM sent to ${targetType} ${targetId}: ${response}`);
    return true;
  } catch (error) {
    if (error.code === 'messaging/registration-token-not-registered' ||
        error.code === 'messaging/invalid-registration-token') {
      console.error(`⚠️ FCM: Invalid/expired token for ${targetType} ${targetId}. Token needs refresh.`);
    } else {
      console.error(`❌ FCM error for ${targetType} ${targetId}:`, error.message || error);
    }
    return false;
  }
}

// FCM Push Notification Helper for Topic Subscribers
async function sendFcmTopicNotification(topic, title, body, data = {}) {
  try {
    const isPartner = topic === 'providers';

    // Persist broadcast alert to DB
    try {
      const { Notification } = require('./models');
      const newAlert = new Notification({
        id: `topic-${Date.now()}-${Math.floor(Math.random() * 10000)}`,
        title,
        body,
        time: new Date().toISOString(),
        icon: data.icon || (isPartner ? 'work' : 'campaign'),
        iconColor: data.iconColor || 'primary',
        userId: !isPartner ? '' : '',
        shopId: isPartner ? '' : '',
        type: 'broadcast',
        bookingId: data.bookingId || ''
      });
      await newAlert.save();
    } catch (dbErr) {
      console.error('Failed to persist topic notification to DB:', dbErr.message);
    }

    if (!admin.apps || !admin.apps.length) {
      console.warn("FCM TOPIC NOT SENT: Firebase Admin SDK is not initialized on server. Broadcast saved to DB.");
      return false;
    }

    const isPartner = topic === 'providers';
    const channelId = isPartner ? 'booking_alert_channel' : 'high_importance_channel';
    const sound = isPartner ? 'alert_ring' : 'default';

    const stringifiedData = {};
    for (const [k, v] of Object.entries(data)) {
      stringifiedData[k] = String(v);
    }
    stringifiedData['click_action'] = 'FLUTTER_NOTIFICATION_CLICK';

    const message = {
      notification: { title, body },
      topic: topic,
      data: stringifiedData,
      android: {
        priority: 'high',
        ttl: 3600000,
        notification: {
          sound: sound,
          clickAction: 'FLUTTER_NOTIFICATION_CLICK',
          channelId: channelId,
          icon: 'ic_notification',
          priority: 'max',
          defaultVibrateTimings: true,
        }
      },
      apns: {
        payload: {
          aps: {
            sound: sound === 'default' ? 'default' : `${sound}.wav`,
            badge: 1,
            contentAvailable: true,
          }
        }
      }
    };

    const response = await admin.messaging().send(message);
    console.log(`✅ FCM topic sent to '${topic}': ${response}`);
    return true;
  } catch (error) {
    console.error(`❌ FCM topic error for '${topic}':`, error.message || error);
    return false;
  }
}

// Cloudinary Asset Deletion Cleanup Helper
async function deleteFromCloudinary(url) {
  if (!url || typeof url !== 'string' || !url.includes('cloudinary.com')) return;
  try {
    const parts = url.split('/');
    const uploadIndex = parts.indexOf('upload');
    if (uploadIndex === -1) return;
    
    let remainingParts = parts.slice(uploadIndex + 1);
    if (remainingParts[0] && /^v\d+$/.test(remainingParts[0])) {
      remainingParts.shift();
    }
    
    const pathWithExtension = remainingParts.join('/');
    const lastDotIndex = pathWithExtension.lastIndexOf('.');
    const publicId = lastDotIndex !== -1 ? pathWithExtension.substring(0, lastDotIndex) : pathWithExtension;
    
    const result = await cloudinary.uploader.destroy(publicId);
    console.log(`[Cloudinary Cleanup] Attempted to delete URL: ${url}. Public ID: ${publicId}. Result:`, result);
    return result;
  } catch (error) {
    console.error(`[Cloudinary Cleanup] Error deleting URL: ${url}`, error.message || error);
  }
}

// Log a payment audit trace event
async function logPaymentEvent(eventType, payload) {
  try {
    const log = new PaymentAuditLog({
      id: `PAY-LOG-${Date.now()}-${Math.floor(Math.random()*1000)}`,
      eventType,
      bookingId: payload.bookingId,
      ledgerId: payload.ledgerId,
      shopId: payload.shopId,
      amount: payload.amount,
      description: payload.description,
      actor: payload.actor || 'system',
      metadata: payload.metadata
    });
    await log.save();
    console.log(`[Payment Audit] Event logged: ${eventType}. Actor: ${payload.actor || 'system'}`);
    return log;
  } catch (err) {
    console.error('[Payment Audit] Log event failed:', err.message || err);
  }
}

// Sanitizes and restricts uploadable image mime types
function validateImageMimeType(mimeType) {
  const allowedTypes = ['image/jpeg', 'image/jpg', 'image/png', 'image/webp', 'image/gif'];
  if (!mimeType) return 'image/jpeg';
  const cleanMime = mimeType.toLowerCase().trim();
  if (!allowedTypes.includes(cleanMime)) {
    throw new Error('Invalid image MIME type: Only JPEG, PNG, WEBP, and GIF are allowed.');
  }
  return cleanMime;
}

// Database Pagination Helper
async function paginate(model, req, searchFields = [], defaultSort = { createdAt: -1 }) {
  const { page, limit, sort, search, ...filters } = req.query;

  // Build query
  const query = {};

  // Apply filters
  for (const [key, val] of Object.entries(filters)) {
    if (val !== undefined && val !== '') {
      query[key] = val;
    }
  }

  // Apply search
  if (search && searchFields.length > 0) {
    const searchConditions = searchFields.map(field => ({ [field]: { $regex: search, $options: 'i' } }));
    if (searchConditions.length === 1) {
      Object.assign(query, searchConditions[0]);
    } else {
      query.$or = searchConditions;
    }
  }

  // Parse page and limit
  const pageNum = parseInt(page, 10);
  const limitNum = parseInt(limit, 10);

  // Parse sort
  let sortObj = defaultSort;
  if (sort) {
    sortObj = {};
    if (sort.startsWith('-')) {
      sortObj[sort.substring(1)] = -1;
    } else if (sort.includes(':')) {
      const parts = sort.split(':');
      sortObj[parts[0]] = parts[1] === 'desc' ? -1 : 1;
    } else {
      sortObj[sort] = 1;
    }
  }

  // If page and limit are not specified, return the database query directly (preserving list array for old clients)
  if (isNaN(pageNum) && isNaN(limitNum)) {
    return await model.find(query).sort(sortObj);
  }

  // Paginated request
  const activePage = pageNum > 0 ? pageNum : 1;
  const activeLimit = limitNum > 0 ? limitNum : 10;
  const skip = (activePage - 1) * activeLimit;

  // Get total count
  const total = await model.countDocuments(query);

  const data = await model.find(query).sort(sortObj).skip(skip).limit(activeLimit);

  return {
    success: true,
    data,
    pagination: {
      total,
      page: activePage,
      limit: activeLimit,
      pages: Math.ceil(total / activeLimit)
    }
  };
}

module.exports = {
  calculateDistance,
  sanitizeBookingForPrivacy,
  sendFcmNotification,
  sendFcmTopicNotification,
  deleteFromCloudinary,
  logPaymentEvent,
  validateImageMimeType,
  paginate
};
