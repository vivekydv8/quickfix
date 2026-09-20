function validateSendNotification(req, res, next) {
  const { title, body } = req.body;
  if (!title || !body) {
    return res.status(400).json({ error: 'Title and body are required' });
  }
  next();
}

function validateNotificationId(req, res, next) {
  const { id } = req.params;
  if (!id || typeof id !== 'string' || id.trim().length === 0) {
    return res.status(400).json({ error: 'Notification ID is required and must be a non-empty string' });
  }
  next();
}

module.exports = {
  validateSendNotification,
  validateNotificationId
};
