function validateGetBookingDetails(req, res, next) {
  const { bookingId } = req.params;
  if (!bookingId) {
    return res.status(400).json({ error: 'Booking ID is required' });
  }
  next();
}

function validatePlaceBooking(req, res, next) {
  const { paymentMethod, paymentDetails } = req.body;
  
  if (!req.body.title || typeof req.body.title !== 'string' || req.body.title.trim() === '') {
    req.body.title = 'Service Booking';
  }
  if (!req.body.shopId) {
    req.body.shopId = 'ADMIN_INSTANT';
  }
  if (req.body.amount === undefined || req.body.amount === null || isNaN(parseFloat(req.body.amount))) {
    return res.status(400).json({ success: false, error: 'Valid booking amount is required' });
  }

  if (paymentMethod === 'Razorpay') {
    if (!paymentDetails || !paymentDetails.paymentId || !paymentDetails.signature || !paymentDetails.orderId) {
      return res.status(400).json({ success: false, error: 'Missing Razorpay payment details' });
    }
  }
  next();
}

function validateUpdateStatus(req, res, next) {
  const { id, status } = req.body;
  if (!id || !status) {
    return res.status(400).json({ error: 'Booking ID and status are required' });
  }
  next();
}

module.exports = {
  validateGetBookingDetails,
  validatePlaceBooking,
  validateUpdateStatus
};
