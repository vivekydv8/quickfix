const jwt = require('jsonwebtoken');
const { User } = require('../models');
const bookingService = require('../services/bookingService');

const JWT_SECRET = process.env.JWT_SECRET;

async function getBookings(req, res) {
  const { shopId } = req.query;
  try {
    const list = await bookingService.getBookingsList(req, shopId);
    res.json(list);
  } catch (e) {
    res.status(500).json({ error: 'Failed to fetch bookings' });
  }
}

async function getBookingDetails(req, res) {
  const { bookingId } = req.params;
  try {
    const sanitized = await bookingService.getBookingDetails(bookingId);
    res.json(sanitized);
  } catch (e) {
    if (e.message === 'Booking not found') {
      return res.status(404).json({ error: e.message });
    }
    res.status(500).json({ error: 'Failed to fetch booking details' });
  }
}

async function placeBooking(req, res) {
  try {
    let user = null;
    const authHeader = req.headers.authorization;
    if (authHeader && authHeader.startsWith('Bearer ')) {
      const token = authHeader.split(' ')[1];
      try {
        const secret = process.env.JWT_SECRET || JWT_SECRET;
        const decoded = jwt.verify(token, secret);
        if (decoded && decoded.id) {
          try { user = await User.findById(decoded.id); } catch (_) {}
          if (!user) user = await User.findOne({ id: decoded.id });
          if (!user) user = await User.findOne({ _id: decoded.id });
          if (!user && decoded.phone) user = await User.findOne({ phone: decoded.phone });
        }
      } catch (err) {}
    }

    const result = await bookingService.placeBookingOrder(req.body, user);
    res.json({
      success: true,
      ...result
    });
  } catch (e) {
    if (e.message === 'Shop not found') {
      return res.status(404).json({ success: false, error: e.message });
    }
    if (e.message === 'Razorpay cryptographic signature verification failed' || e.message === 'Insufficient wallet balance' || e.message === 'Missing Razorpay payment details') {
      return res.status(400).json({ success: false, error: e.message });
    }
    if (e.message === 'Unauthorized: Authentication required for wallet payment') {
      return res.status(401).json({ success: false, error: e.message });
    }
    console.error('Booking placement failed:', e);
    res.status(500).json({ success: false, error: e.message || 'Failed to save booking order' });
  }
}

async function updateStatus(req, res) {
  const { id, status, providerName, shopId } = req.body;
  const effectiveShopId = shopId || (req.user && (req.user.shopId || req.user.id));
  try {
    const booking = await bookingService.updateBookingStatus(id, status, providerName, effectiveShopId);
    res.json({ success: true, booking });
  } catch (e) {
    if (e.message === 'Booking not found') {
      return res.status(404).json({ error: e.message });
    }
    console.error('Update booking status error:', e);
    res.status(500).json({ error: 'Failed to update status' });
  }
}

async function cancelBooking(req, res) {
  const { id } = req.body;
  try {
    const booking = await bookingService.cancelBooking(id);
    res.json({ success: true, booking });
  } catch (e) {
    if (e.message === 'Booking not found') {
      return res.status(404).json({ error: e.message });
    }
    if (e.message.startsWith('Cannot cancel order once provider')) {
      return res.status(400).json({ error: e.message });
    }
    res.status(500).json({ error: 'Failed to cancel booking' });
  }
}

async function uploadQuotation(req, res) {
  const { bookingId } = req.params;
  try {
    const booking = await bookingService.uploadQuotation(bookingId, req.body);
    res.json({ success: true, booking });
  } catch (e) {
    if (e.message === 'Booking not found') {
      return res.status(404).json({ error: e.message });
    }
    console.error('Quotation upload failed:', e);
    res.status(500).json({ error: 'Failed to upload quotation' });
  }
}

async function respondToQuotation(req, res) {
  const { bookingId } = req.params;
  const { response, comment } = req.body;
  try {
    const booking = await bookingService.respondToQuotation(bookingId, response, comment);
    res.json({ success: true, booking });
  } catch (e) {
    if (e.message === 'Booking not found') {
      return res.status(404).json({ error: e.message });
    }
    if (e.message === 'No quotation found to respond to') {
      return res.status(400).json({ error: e.message });
    }
    console.error('Quotation response failed:', e);
    res.status(500).json({ error: 'Failed to respond to quotation' });
  }
}

async function assignProvider(req, res) {
  const { bookingId, shopId, providerName } = req.body;
  try {
    const booking = await bookingService.assignProviderToBooking(bookingId, shopId, providerName);
    res.json({ success: true, booking });
  } catch (e) {
    if (e.message === 'Booking not found' || e.message === 'Provider shop not found') {
      return res.status(404).json({ success: false, error: e.message });
    }
    console.error('Assign provider failed:', e);
    res.status(500).json({ success: false, error: e.message || 'Failed to assign provider' });
  }
}

module.exports = {
  getBookings,
  getBookingDetails,
  placeBooking,
  updateStatus,
  cancelBooking,
  uploadQuotation,
  respondToQuotation,
  assignProvider
};
