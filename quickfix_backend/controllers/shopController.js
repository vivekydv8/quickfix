const shopService = require('../services/shopService');

async function register(req, res) {
  try {
    const shop = await shopService.registerShop(req.body);
    res.json({ success: true, shop });
  } catch (e) {
    if (e.statusCode === 400) {
      return res.status(400).json({ error: e.message });
    }
    console.error('Register shop error:', e);
    res.status(500).json({ error: 'Failed to register shop partner' });
  }
}

async function login(req, res) {
  const { phone, password, shopId } = req.body;
  try {
    const result = await shopService.loginShop(phone, password, shopId);
    res.json({ success: true, ...result });
  } catch (e) {
    if (e.statusCode === 401 || e.statusCode === 403) {
      return res.status(e.statusCode).json({ error: e.message });
    }
    console.error('Login process failed:', e);
    res.status(500).json({ error: 'Login process failed' });
  }
}

async function update(req, res) {
  const { id } = req.body;
  try {
    const updated = await shopService.updateShop(id, req.body);
    res.json({ success: true, shop: updated });
  } catch (e) {
    if (e.message === 'Shop not found') {
      return res.status(404).json({ error: e.message });
    }
    res.status(500).json({ error: 'Failed to update shop details' });
  }
}

async function deleteShop(req, res) {
  const shopId = req.params.id;
  try {
    const deleted = await shopService.deleteShop(shopId);
    if (deleted) {
      res.json({ success: true, shop: deleted });
    } else {
      res.status(404).json({ error: 'Shop not found' });
    }
  } catch (e) {
    res.status(500).json({ error: 'Failed to delete shop' });
  }
}

async function getNearby(req, res) {
  const userLat = parseFloat(req.query.lat);
  const userLng = parseFloat(req.query.lng);
  const { page, limit } = req.query;
  try {
    const result = await shopService.getNearbyShops(userLat, userLng, page, limit);
    if (result.success) {
      res.json(result);
    } else {
      res.json(result);
    }
  } catch (e) {
    console.error('Failed to fetch shops:', e);
    res.status(500).json({ error: 'Failed to fetch shops' });
  }
}

async function search(req, res) {
  const { q, lat, lng, page, limit, category, subcategory } = req.query;
  const userLat = parseFloat(lat);
  const userLng = parseFloat(lng);
  try {
    const result = await shopService.searchShops(q, userLat, userLng, page, limit, category, subcategory);
    res.json(result);
  } catch (e) {
    console.error('Failed to search shops:', e);
    res.status(500).json({ error: 'Search process failed' });
  }
}

async function getAll(req, res) {
  try {
    const result = await shopService.getAllShops(req);
    res.json(result);
  } catch (e) {
    res.status(500).json({ error: 'Failed to fetch all shops' });
  }
}

async function approve(req, res) {
  const { id, verificationStatus } = req.body;
  try {
    const shop = await shopService.approveShop(id, verificationStatus);
    res.json({ success: true, shop });
  } catch (e) {
    if (e.message === 'Shop not found') {
      return res.status(404).json({ error: e.message });
    }
    res.status(500).json({ error: 'Failed to verify shop' });
  }
}

async function suspend(req, res) {
  const { id, suspend } = req.body;
  try {
    const shop = await shopService.suspendShop(id, suspend);
    res.json({ success: true, shop });
  } catch (e) {
    if (e.message === 'Shop not found') {
      return res.status(404).json({ error: e.message });
    }
    res.status(500).json({ error: 'Failed to update shop suspend state' });
  }
}

async function toggleLogin(req, res) {
  const { id, loginDisabled } = req.body;
  try {
    const shop = await shopService.toggleLogin(id, loginDisabled);
    res.json({ success: true, shop });
  } catch (e) {
    if (e.message === 'Shop not found') {
      return res.status(404).json({ error: e.message });
    }
    res.status(500).json({ error: 'Failed to update login status' });
  }
}

async function resetPassword(req, res) {
  const { id } = req.body;
  try {
    const result = await shopService.resetPassword(id);
    res.json({ success: true, ...result });
  } catch (e) {
    if (e.message === 'Shop not found') {
      return res.status(404).json({ error: e.message });
    }
    res.status(500).json({ error: 'Failed to reset password' });
  }
}

module.exports = {
  register,
  login,
  update,
  deleteShop,
  getNearby,
  search,
  getAll,
  approve,
  suspend,
  toggleLogin,
  resetPassword
};
