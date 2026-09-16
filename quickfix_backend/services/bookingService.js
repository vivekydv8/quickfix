const crypto = require('crypto');
const { Booking, Shop, User, PaymentLedger, PaymentAuditLog } = require('../models');
const { calculateCheckoutPriceInternal } = require('../pricingCalculator');
const { sanitizeBookingForPrivacy, sendFcmNotification, sendFcmTopicNotification, paginate } = require('../helpers');

const jwt = require('jsonwebtoken');

async function getBookingsList(req, shopId) {
  let authenticatedUser = req.user;
  if (!authenticatedUser && req.headers && req.headers.authorization) {
    const authHeader = req.headers.authorization;
    if (authHeader.startsWith('Bearer ')) {
      const token = authHeader.split(' ')[1];
      try {
        const secret = process.env.JWT_SECRET || 'super_secret_quickfix_jwt_key_2026';
        const decoded = jwt.verify(token, secret);
        if (decoded && decoded.id) {
          try { authenticatedUser = await User.findById(decoded.id); } catch (_) {}
          if (!authenticatedUser) authenticatedUser = await User.findOne({ id: decoded.id });
          if (!authenticatedUser && decoded.phone) authenticatedUser = await User.findOne({ phone: decoded.phone });
        }
      } catch (_) {}
    }
  }

  if (shopId) {
    let shop = null;
    try { shop = await Shop.findOne({ id: shopId }); } catch (_) {}
    if (!shop) {
      try { shop = await Shop.findOne({ _id: shopId }); } catch (_) {}
    }

    const shopConditions = [{ shopId: shopId }];
    if (shop && shop._id) {
      shopConditions.push({ shopId: shop._id.toString() });
    }
    // Also include open pending requests so provider app sees incoming requests
    shopConditions.push({ shopId: 'ADMIN_INSTANT', status: 'pending' });

    const providerQuery = { $or: shopConditions };
    const bookings = await Booking.find(providerQuery).sort({ createdAt: -1 });
    return bookings.map(b => sanitizeBookingForPrivacy(b));
  }

  const targetCustomerId = req.query.customerId;
  const targetPhone = req.query.customerPhone || (authenticatedUser ? authenticatedUser.phone : null);
  const targetUserId = targetCustomerId || (authenticatedUser ? (authenticatedUser._id ? authenticatedUser._id.toString() : authenticatedUser.id) : null);

  if (targetUserId || targetPhone) {
    const orConditions = [];
    if (targetUserId) orConditions.push({ customerId: targetUserId });
    if (targetPhone) orConditions.push({ customerPhone: targetPhone });
    if (authenticatedUser && authenticatedUser._id) orConditions.push({ customerId: authenticatedUser._id.toString() });
    if (authenticatedUser && authenticatedUser.id) orConditions.push({ customerId: authenticatedUser.id.toString() });
    if (authenticatedUser && authenticatedUser.phone) orConditions.push({ customerPhone: authenticatedUser.phone });

    const query = orConditions.length > 0 ? { $or: orConditions } : {};
    const bookings = await Booking.find(query).sort({ createdAt: -1 });
    return bookings;
  }

  const result = await paginate(Booking, req, ['id', 'customerName', 'customerPhone', 'title', 'providerName'], { createdAt: -1 });
  if (Array.isArray(result)) {
    return result;
  } else {
    return result;
  }
}

async function getBookingDetails(bookingId) {
  const booking = await Booking.findOne({ id: bookingId });
  if (!booking) {
    throw new Error('Booking not found');
  }
  return sanitizeBookingForPrivacy(booking);
}

async function placeBookingOrder(reqBody, userObjectFromToken) {
  const {
    customerId,
    customerName,
    customerPhone,
    customerAddress,
    shopId,
    title,
    slot,
    date,
    amount,
    paymentMethod,
    paymentDetails,
    pricingType,
    items,
    couponCode,
    latitude,
    longitude,
    durationText,
    specialInstructions,
    issuePhoto,
    isInstant,
    type
  } = reqBody;

  const isInstantBooking = isInstant === true || type === 'quick_booking' || slot === 'Immediate' || shopId === 'ADMIN_INSTANT';

  let shop = null;
  if (shopId && shopId !== 'ADMIN_INSTANT') {
    try { shop = await Shop.findById(shopId); } catch (_) {}
    if (!shop) shop = await Shop.findOne({ id: shopId });
    if (!shop) shop = await Shop.findOne({ _id: shopId });
  }

  // Graceful fallback to an active shop or ADMIN_INSTANT if shop was not found
  if (!shop && !isInstantBooking) {
    try {
      shop = await Shop.findOne({ status: 'active', isOpen: true });
      if (!shop) shop = await Shop.findOne();
    } catch (_) {}
  }

  let user = userObjectFromToken;
  let parsedAmount = parseFloat(amount);
  let visitingCharges = shop ? (shop.visitingCharges || 150.0) : 150.0;
  let bookingPricingType = pricingType || 'fixed';

  if (shop && items && Array.isArray(items) && items.length > 0) {
    const calc = await calculateCheckoutPriceInternal(shop, items, couponCode);
    parsedAmount = calc.grandTotal;
    visitingCharges = calc.visitingCharge;
    bookingPricingType = calc.pricingType;
  }

  if (paymentMethod === 'Razorpay' && paymentDetails) {
    const secret = process.env.RAZORPAY_KEY_SECRET;
    if (secret && paymentDetails.orderId && paymentDetails.paymentId && paymentDetails.signature) {
      const generatedSignature = crypto
        .createHmac('sha256', secret)
        .update(paymentDetails.orderId + "|" + paymentDetails.paymentId)
        .digest('hex');
      if (generatedSignature !== paymentDetails.signature) {
        throw new Error('Razorpay cryptographic signature verification failed');
      }
    } else if (!secret) {
      console.warn("WARNING: RAZORPAY_KEY_SECRET is not configured. Signature validation was bypassed.");
    }
  }

  if (paymentMethod === 'Wallet') {
    if (!user) {
      throw new Error('Unauthorized: Authentication required for wallet payment');
    }
    if ((user.walletBalance || 0) < parsedAmount) {
      throw new Error('Insufficient wallet balance');
    }
    user.walletBalance = (user.walletBalance || 0) - parsedAmount;
    user.walletTransactions = user.walletTransactions || [];
    user.walletTransactions.push({
      id: `TX-${Date.now()}-${Math.floor(1000 + Math.random() * 9000)}`,
      title: `Paid for ${title}`,
      amount: parsedAmount,
      type: 'debit',
      date: new Date()
    });
    await user.save();
  }

  const bookingId = `QF-${Math.floor(100000 + Math.random() * 900000)}`;
  const commissionRate = shop ? (shop.commissionRate || 15.0) : 15.0;
  const providerName = isInstantBooking ? 'Admin (Pending Assignment)' : (shop ? (shop.ownerName || 'Assigning Expert...') : 'Assigning Expert...');
  const estEarnings = parseFloat((parsedAmount * (1 - commissionRate / 100)).toFixed(2));
  
  let addr = customerAddress;
  if (!addr && user && user.savedAddresses && user.savedAddresses.length > 0) {
    const firstAddr = user.savedAddresses[0];
    addr = typeof firstAddr === 'string' ? firstAddr : (firstAddr.address || firstAddr.fullAddress || '');
  }
  if (!addr || typeof addr !== 'string' || addr.trim() === '') {
    addr = '113, Swaroop Nagar, Kanpur';
  }

  const addrParts = addr.split(',');
  const approxAddress = addrParts.length > 1 
    ? `${addrParts[addrParts.length - 2].trim()}, ${addrParts[addrParts.length - 1].trim()}`
    : addr;

  let custLat = latitude;
  let custLng = longitude;
  if ((!custLat || !custLng) && user && user.savedAddresses && user.savedAddresses.length > 0) {
    const firstAddr = user.savedAddresses[0];
    if (typeof firstAddr === 'object') {
      custLat = custLat || firstAddr.latitude || firstAddr.lat;
      custLng = custLng || firstAddr.longitude || firstAddr.lng;
    }
  }
  custLat = parseFloat(custLat) || 26.4912;
  custLng = parseFloat(custLng) || 80.3156;

  const newBooking = new Booking({
    id: bookingId,
    customerId: user ? (user._id ? user._id.toString() : user.id) : (customerId || 'cust-123'),
    customerName: user ? (user.name || user.phone) : (customerName || 'John Doe'),
    customerPhone: user ? user.phone : (customerPhone || '9999888877'),
    customerAddress: addr,
    approxAddress: approxAddress,
    customerLat: custLat,
    customerLng: custLng,
    shopId: isInstantBooking ? 'ADMIN_INSTANT' : (shopId || 'ADMIN_INSTANT'),
    title,
    slot: slot || '09:00 AM - 10:00 AM',
    date: date ? new Date(date) : new Date(),
    amount: parsedAmount,
    visitingCharges,
    estEarnings,
    estDuration: durationText || '1.5 hrs',
    specialInstructions: specialInstructions || '',
    paymentMethod: paymentMethod || 'UPI',
    issuePhoto: issuePhoto || '',
    isInstant: isInstantBooking,
    status: 'pending',
    providerName: providerName,
    pricingType: bookingPricingType
  });

  await newBooking.save();

  try {
    const commRate = shop ? (shop.commissionRate || 20.0) : 20.0;
    const gross = parsedAmount;
    const commAmt = parseFloat((gross * commRate / 100).toFixed(2));
    const gatewayCharges = paymentMethod === 'Razorpay' ? parseFloat((gross * 0.02).toFixed(2)) : 0;
    const providerEarn = parseFloat((gross - commAmt - gatewayCharges).toFixed(2));
    const platformRev = parseFloat((commAmt + gatewayCharges).toFixed(2));

    let pmEnum = 'cash';
    if (paymentMethod === 'Razorpay') pmEnum = 'online';
    else if (paymentMethod === 'Wallet') pmEnum = 'wallet';
    else if (paymentMethod === 'UPI') pmEnum = 'upi';
    else if (paymentMethod === 'Card' || paymentMethod === 'Credit Card' || paymentMethod === 'Debit Card') pmEnum = 'card';
    else if (paymentMethod === 'Net Banking') pmEnum = 'netbanking';

    let pStatus = 'cash_pending';
    if (pmEnum === 'online') pStatus = 'pending';
    else if (pmEnum === 'wallet') pStatus = 'paid';

    let cStatus = 'pending';
    if (pmEnum === 'wallet') cStatus = 'paid';

    const ledgerId = `LDG-${bookingId}`;
    const ledgerEntries = [
      {
        id: `LE-${Date.now()}-1`,
        type: 'credit',
        amount: gross,
        party: 'platform',
        description: `Booking ${bookingId} received - ${paymentMethod}`,
        timestamp: new Date()
      },
      {
        id: `LE-${Date.now()}-2`,
        type: 'debit',
        amount: commAmt,
        party: 'platform',
        description: `Platform commission ${commRate}% = ₹${commAmt}`,
        timestamp: new Date()
      },
      {
        id: `LE-${Date.now()}-3`,
        type: 'credit',
        amount: providerEarn,
        party: 'provider',
        description: `Provider earnings after ${commRate}% commission`,
        timestamp: new Date()
      }
    ];

    const shopRefId = shop ? (shop.id || (shop._id ? shop._id.toString() : 'ADMIN_INSTANT')) : (shopId || 'ADMIN_INSTANT');
    const shopOwnerRef = shop ? (shop.ownerName || shop.name || 'Admin') : 'Admin (Pending Assignment)';

    const ledger = new PaymentLedger({
      id: ledgerId,
      bookingId: bookingId,
      customerId: newBooking.customerId,
      providerId: shopRefId,
      shopId: shopRefId,
      providerName: shopOwnerRef,
      customerName: newBooking.customerName,
      serviceTitle: title,
      grossAmount: gross,
      commissionRate: commRate,
      commissionAmount: commAmt,
      gatewayCharges,
      providerEarnings: providerEarn,
      platformRevenue: platformRev,
      paymentMethod: pmEnum,
      paymentStatus: pStatus,
      commissionStatus: cStatus,
      ledgerEntries,
      metadata: { slot: newBooking.slot, date: newBooking.date }
    });
    await ledger.save();

    const auditLog = new PaymentAuditLog({
      id: `PAL-${Date.now()}-BOOKING`,
      eventType: 'booking_created',
      bookingId: bookingId,
      ledgerId: ledgerId,
      shopId: shopRefId,
      customerId: newBooking.customerId,
      amount: gross,
      description: `Booking ${bookingId} created via ${paymentMethod}`,
      actor: 'customer',
      metadata: { paymentMethod, commissionRate: commRate }
    });
    await auditLog.save();

    if (pmEnum === 'wallet') {
      const walletAudit = new PaymentAuditLog({
        id: `PAL-${Date.now()}-WALLET`,
        eventType: 'payment_success',
        bookingId: bookingId,
        ledgerId: ledgerId,
        shopId: shopRefId,
        customerId: newBooking.customerId,
        amount: gross,
        description: `Wallet payment of ₹${gross} processed`,
        actor: 'system',
        metadata: { paymentMethod: 'wallet' }
      });
      await walletAudit.save();
    }
  } catch (ledgerErr) {
    console.error('Payment ledger creation failed (non-critical):', ledgerErr.message);
  }

  sendFcmNotification(
    newBooking.customerId,
    'Booking Created 🎉',
    `Your booking ${bookingId} for "${title}" has been successfully created.`,
    {
      type: 'booking',
      bookingId: bookingId,
      iconColor: 'success'
    }
  ).catch(err => console.error('FCM customer notification error:', err));

  const partnerRecipient = shop ? (shop.id || (shop._id ? shop._id.toString() : null)) : (shopId && shopId !== 'ADMIN_INSTANT' ? shopId : null);
  if (partnerRecipient) {
    sendFcmNotification(
      partnerRecipient,
      'New Booking Request 📦',
      `You have a new booking request for "${title}" on ${date || 'today'} during ${slot || 'your business hours'}.`,
      {
        type: 'booking',
        bookingId: bookingId,
        iconColor: 'info'
      },
      'partner'
    ).catch(err => console.error('FCM partner notification error:', err));
  } else {
    // Instant/Unassigned booking: broadcast to all active providers so any provider can accept it
    sendFcmTopicNotification(
      'providers',
      'New Instant Booking Request 📦',
      `New service request for "${title}" (${bookingPricingType === 'inspection_based' ? 'Inspection' : '₹' + parsedAmount}) in ${addrParts[0] || 'your area'}. Tap to view and accept!`,
      {
        type: 'booking',
        bookingId: bookingId,
        iconColor: 'info'
      }
    ).catch(err => console.error('FCM providers topic broadcast error:', err));
  }

  return {
    success: true,
    bookingId,
    booking: newBooking,
    walletBalance: user ? user.walletBalance : undefined
  };
}

async function updateBookingStatus(id, status, providerName, providerShopId) {
  const booking = await Booking.findOne({ id });
  if (!booking) {
    throw new Error('Booking not found');
  }

  const oldStatus = booking.status;
  booking.status = status;
  if (providerName) booking.providerName = providerName;
  if (providerShopId && (booking.shopId === 'ADMIN_INSTANT' || !booking.shopId || booking.shopId === '')) {
    booking.shopId = providerShopId;
  }
  await booking.save();

  try {
    const ledger = await PaymentLedger.findOne({ bookingId: id });
    if (ledger) {
      if (providerShopId && (ledger.shopId === 'ADMIN_INSTANT' || !ledger.shopId)) {
        ledger.shopId = providerShopId;
        ledger.providerId = providerShopId;
        if (providerName) ledger.providerName = providerName;
      }
      if (status === 'completed' || status === 'closed') {
        if (ledger.paymentMethod === 'cash') {
          ledger.paymentStatus = 'paid';
        }
        if (ledger.commissionStatus === 'pending') {
          const shop = await Shop.findOne({ id: booking.shopId });
          if (shop) {
            if (ledger.paymentMethod === 'cash') {
              shop.walletBalance = (shop.walletBalance || 0) - ledger.commissionAmount;
              ledger.commissionStatus = 'paid';
              ledger.ledgerEntries.push({
                id: `LE-${Date.now()}-COMM-DEDUCT`,
                type: 'debit',
                amount: ledger.commissionAmount,
                party: 'provider',
                description: `Commission ₹${ledger.commissionAmount} deducted from shop wallet for booking ${id}`,
                timestamp: new Date()
              });
              await shop.save();
            } else if (ledger.paymentMethod === 'online') {
              shop.walletBalance = (shop.walletBalance || 0) + ledger.providerEarnings;
              ledger.paymentStatus = 'paid';
              ledger.commissionStatus = 'paid';
              ledger.ledgerEntries.push({
                id: `LE-${Date.now()}-EARN-CREDIT`,
                type: 'credit',
                amount: ledger.providerEarnings,
                party: 'provider',
                description: `Earnings ₹${ledger.providerEarnings} credited to shop wallet for online booking ${id}`,
                timestamp: new Date()
              });
              await shop.save();
            }
          }
        }
        await ledger.save();

        const audit = new PaymentAuditLog({
          id: `PAL-${Date.now()}-SUCCESS`,
          eventType: 'payment_success',
          bookingId: id,
          ledgerId: ledger.id,
          shopId: booking.shopId,
          customerId: booking.customerId,
          amount: booking.amount,
          description: `Payment for booking ${id} marked successful on completion`,
          actor: 'system',
          metadata: { oldStatus, newStatus: status }
        });
        await audit.save();
      }
    }
  } catch (ledgerErr) {
    console.error('Ledger state update failed:', ledgerErr.message);
  }

  let name = providerName || booking.providerName;
  if (!name || name === 'Assigning Expert...') {
    try {
      const shop = await Shop.findOne({ id: booking.shopId });
      if (shop && shop.name) name = shop.name;
    } catch (_) {}
  }
  if (!name || name === 'Assigning Expert...') name = 'Service provider';

  const titleMap = {
    accepted: 'Booking Accepted 🎉',
    rejected: 'Booking Declined ⚠️',
    cancelled: 'Booking Cancelled ❌',
    navigating: 'Provider on the Way 🚀',
    arrived: 'Provider Arrived 📍',
    work_started: 'Work in Progress 🛠️',
    completed: 'Booking Completed 🎉',
    closed: 'Booking Completed 🎉'
  };

  const bodyMap = {
    accepted: `${name} has accepted your booking QF-${id} for "${booking.title}".`,
    rejected: `Your booking QF-${id} for "${booking.title}" was declined by ${name}.`,
    cancelled: `Your booking QF-${id} for "${booking.title}" has been cancelled.`,
    navigating: `${name} has started navigating to your location for QF-${id}.`,
    arrived: `${name} has arrived at your address.`,
    work_started: `${name} has started the job.`,
    completed: `Your booking QF-${id} for "${booking.title}" has been completed.`,
    closed: `Your booking QF-${id} for "${booking.title}" has been completed.`
  };

  if (titleMap[status]) {
    const iconColor = (status === 'completed' || status === 'accepted' || status === 'closed') 
      ? 'success' 
      : (status === 'rejected' || status === 'cancelled') ? 'error' : 'info';

    sendFcmNotification(
      booking.customerId,
      titleMap[status],
      bodyMap[status],
      {
        type: 'booking_status',
        bookingId: id,
        iconColor: iconColor
      }
    );
  }

  return booking;
}

async function cancelBooking(id) {
  const booking = await Booking.findOne({ id });
  if (!booking) {
    throw new Error('Booking not found');
  }

  if (['on_the_way', 'navigating', 'arrived', 'work_started', 'work_completed', 'payment_completed', 'completed', 'closed'].includes(booking.status)) {
    throw new Error('Cannot cancel order once provider has started travel or work is in progress!');
  }

  booking.status = 'cancelled';
  await booking.save();

  sendFcmNotification(
    booking.customerId,
    'Booking Cancelled ❌',
    `Your booking QF-${id} for "${booking.title}" has been cancelled.`,
    {
      type: 'booking_status',
      bookingId: id,
      iconColor: 'error'
    }
  );

  sendFcmNotification(
    booking.shopId,
    'Booking Cancelled ❌',
    `The booking QF-${id} for "${booking.title}" has been cancelled by the customer.`,
    {
      type: 'booking',
      bookingId: id,
      iconColor: 'error'
    },
    'partner'
  );

  return booking;
}

async function uploadQuotation(bookingId, reqBody) {
  const { labourCharge, spareParts, additionalMaterials, visitingCharges, discount, gst } = reqBody;
  const booking = await Booking.findOne({ id: bookingId });
  if (!booking) {
    throw new Error('Booking not found');
  }

  const lC = parseFloat(labourCharge) || 0.0;
  const sP = parseFloat(spareParts) || 0.0;
  const aM = parseFloat(additionalMaterials) || 0.0;
  const vC = parseFloat(visitingCharges) || 0.0;
  const disc = parseFloat(discount) || 0.0;
  const gstPct = parseFloat(gst) || 0.0;

  const subtotal = lC + sP + aM + vC - disc;
  const gstAmt = parseFloat((subtotal * (gstPct / 100)).toFixed(2));
  const totalAmount = subtotal + gstAmt;

  booking.quotation = {
    labourCharge: lC,
    spareParts: sP,
    additionalMaterials: aM,
    visitingCharges: vC,
    discount: disc,
    gst: gstAmt,
    totalAmount: parseFloat(totalAmount.toFixed(2)),
    status: 'pending',
    updatedAt: new Date(),
    createdAt: booking.quotation && booking.quotation.createdAt ? booking.quotation.createdAt : new Date()
  };

  booking.status = 'quote_sent';
  
  if (!booking.quotationHistory) {
    booking.quotationHistory = [];
  }
  booking.quotationHistory.push({
    ...booking.quotation,
    date: new Date()
  });

  await booking.save();

  sendFcmNotification(
    booking.customerId,
    'New Quotation Received 📋',
    `A new quotation of ₹${totalAmount.toFixed(2)} has been sent for "${booking.title}".`,
    {
      type: 'booking_status',
      bookingId: bookingId,
      iconColor: 'info'
    }
  );

  return booking;
}

async function respondToQuotation(bookingId, response, comment) {
  const booking = await Booking.findOne({ id: bookingId });
  if (!booking) {
    throw new Error('Booking not found');
  }

  if (!booking.quotation) {
    throw new Error('No quotation found to respond to');
  }

  booking.quotation.status = response;
  booking.quotation.updatedAt = new Date();

  if (!booking.quotationHistory) {
    booking.quotationHistory = [];
  }
  booking.quotationHistory.push({
    action: `respond_${response}`,
    comment: comment || '',
    date: new Date()
  });

  if (response === 'accepted') {
    booking.status = 'work_started';
    booking.amount = booking.quotation.totalAmount;
    
    const shop = await Shop.findOne({ id: booking.shopId });
    const commissionRate = shop ? (shop.commissionRate || 15.0) : 15.0;
    booking.estEarnings = parseFloat((booking.amount * (1 - commissionRate / 100)).toFixed(2));
  } else if (response === 'rejected') {
    booking.status = 'cancelled';
  } else if (response === 'modify') {
    booking.status = 'arrived';
    booking.quotation.status = 'modified';
  }

  await booking.save();
  return booking;
}

async function assignProviderToBooking(bookingId, shopId, customProviderName) {
  const booking = await Booking.findOne({ id: bookingId });
  if (!booking) {
    throw new Error('Booking not found');
  }

  let shop = null;
  try { shop = await Shop.findById(shopId); } catch (_) {}
  if (!shop) shop = await Shop.findOne({ id: shopId });
  if (!shop) shop = await Shop.findOne({ _id: shopId });

  if (!shop) {
    throw new Error('Provider shop not found');
  }

  const assignedShopId = shop.id || shop._id.toString();
  const pName = customProviderName || shop.ownerName || shop.name || 'Assigned Provider';

  booking.shopId = assignedShopId;
  booking.providerName = pName;
  if (shop.phone) booking.providerPhone = shop.phone;
  await booking.save();

  try {
    const ledger = await PaymentLedger.findOne({ bookingId });
    if (ledger) {
      ledger.shopId = assignedShopId;
      ledger.providerId = assignedShopId;
      ledger.providerName = pName;
      await ledger.save();
    }
  } catch (ledgerErr) {
    console.error('Ledger update error during provider assignment:', ledgerErr.message);
  }

  sendFcmNotification(
    assignedShopId,
    'New Instant Booking Request ⚡',
    `You have been assigned instant booking ${bookingId} for "${booking.title}". Tap to view & respond.`,
    {
      type: 'booking',
      bookingId: bookingId,
      iconColor: 'info',
      isInstant: 'true'
    },
    'partner'
  ).catch(err => console.error('FCM partner assignment notification error:', err));

  sendFcmNotification(
    booking.customerId,
    'Provider Assigned 🎉',
    `${pName} has been assigned to your instant booking ${bookingId}.`,
    {
      type: 'booking_status',
      bookingId: bookingId,
      iconColor: 'success'
    }
  ).catch(err => console.error('FCM customer notification error:', err));

  return booking;
}

module.exports = {
  getBookingsList,
  getBookingDetails,
  placeBookingOrder,
  updateBookingStatus,
  cancelBooking,
  uploadQuotation,
  respondToQuotation,
  assignProviderToBooking
};

