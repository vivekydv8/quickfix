const dotenv = require('dotenv');
const path = require('path');
const fs = require('fs');

// 1. Select and load environment config profile
const nodeEnv = process.env.NODE_ENV ? process.env.NODE_ENV.toLowerCase().trim() : 'development';
let envFile = '.env.dev';
if (nodeEnv === 'production') envFile = '.env.production';
else if (nodeEnv === 'staging') envFile = '.env.staging';

const envPath = path.resolve(__dirname, envFile);
if (fs.existsSync(envPath)) {
  dotenv.config({ path: envPath });
  console.log(`[Config] Loaded environment configuration profile: ${envFile}`);
} else {
  dotenv.config(); // fallback to standard .env
}

// 2. Validate Environment Variables before Boot
const { validateEnv } = require('./config/envValidator');
validateEnv();

// 3. Logger & Request ID setup
const { logger } = require('./config/logger');
const { requestIdMiddleware, httpAccessLogger } = require('./middleware/requestLogger');

// 4. Security middleware setup
const { helmetMiddleware, corsMiddleware, sanitizeMongo, sanitizeHpp } = require('./middleware/security');

const express = require('express');
const mongoose = require('mongoose');

// Initialize Firebase Admin SDK
require('./config/firebase');

const app = express();
const PORT = process.env.PORT || 3000;

// Trust reverse proxy (Railway, Render, Nginx, Cloudflare)
app.set('trust proxy', 1);

// Attach Request ID & Access Logger
app.use(requestIdMiddleware);
app.use(httpAccessLogger);

// Apply Security HTTP Headers & CORS Whitelist
app.use(helmetMiddleware);
app.use(corsMiddleware);

// Request payload limits (10MB max for JSON and URL-encoded for image uploads)
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ limit: '10mb', extended: true }));

// Express JSON payload error handler (catches 413 / bad JSON)
app.use((err, req, res, next) => {
  if (err && (err.type === 'entity.too.large' || err.status === 413)) {
    return res.status(413).json({ success: false, error: 'Payload too large. Maximum allowed size is 10MB.' });
  }
  if (err && err instanceof SyntaxError && err.status === 400 && 'body' in err) {
    return res.status(400).json({ success: false, error: 'Invalid JSON payload structure' });
  }
  next(err);
});

// Apply NoSQL Injection & HPP parameter sanitization
app.use(sanitizeMongo);
app.use(sanitizeHpp);

// --- HEALTH & READINESS ENDPOINTS ---
const pkg = require('./package.json');
const getHealthStatus = () => {
  const dbStateMap = { 0: 'disconnected', 1: 'connected', 2: 'connecting', 3: 'disconnecting' };
  const dbState = mongoose.connection ? mongoose.connection.readyState : 0;
  return {
    status: dbState === 1 ? 'ok' : 'degraded',
    version: pkg.version || '1.0.0',
    environment: process.env.NODE_ENV || 'development',
    uptime: `${Math.floor(process.uptime())}s`,
    timestamp: new Date().toISOString(),
    database: {
      status: dbStateMap[dbState] || 'unknown',
      connected: dbState === 1
    },
    memory: {
      rss: `${Math.round(process.memoryUsage().rss / 1024 / 1024)} MB`,
      heapUsed: `${Math.round(process.memoryUsage().heapUsed / 1024 / 1024)} MB`
    }
  };
};

app.get(['/health', '/api/health'], (req, res) => res.json(getHealthStatus()));
app.get(['/live', '/api/live'], (req, res) => res.json({ status: 'live', timestamp: new Date().toISOString() }));
app.get(['/ready', '/api/ready'], (req, res) => {
  const dbState = mongoose.connection ? mongoose.connection.readyState : 0;
  if (dbState === 1 || nodeEnv !== 'production') {
    return res.json({ status: 'ready', database: dbState === 1 ? 'connected' : 'local_json_dev' });
  }
  return res.status(503).json({ status: 'not_ready', error: 'Database disconnected' });
});

// --- DATABASE CONNECTION ---
const isProd = nodeEnv === 'production';
const isMongoConfigured = process.env.MONGODB_URI && !process.env.MONGODB_URI.includes('YOUR_MONGODB_ATLAS_CONNECTION_STRING_HERE');
const { setUseLocalDb } = require('./models');

const dbUri = isMongoConfigured ? process.env.MONGODB_URI : 'mongodb://localhost:27017/quickfix';

const connectWithRetry = (retries = 5, delay = 5000) => {
  logger.info(`Attempting to connect to MongoDB... (${retries} retries left)`);
  mongoose.connect(dbUri, { 
    serverSelectionTimeoutMS: 15000,
    connectTimeoutMS: 15000
  })
    .then(() => {
      logger.info("Connected to MongoDB database successfully!");
    })
    .catch(err => {
      logger.error(`MongoDB connection error: ${err.message}`);
      if (retries > 1) {
        logger.warn(`Retrying MongoDB connection in ${delay / 1000} seconds...`);
        setTimeout(() => connectWithRetry(retries - 1, delay), delay);
      } else {
        if (isProd) {
          logger.error("FATAL ERROR: Production server cannot start without a valid MongoDB connection after multiple attempts.");
          process.exit(1);
        } else {
          logger.warn("Falling back to local JSON database storage (database.json) in development mode...");
          setUseLocalDb(true);
        }
      }
    });
};

mongoose.connection.on('disconnected', () => {
  logger.warn('MongoDB disconnected. Driver will attempt to reconnect automatically.');
});

mongoose.connection.on('reconnected', () => {
  logger.info('MongoDB reconnected successfully!');
});

connectWithRetry();

// --- REGISTER MODULAR ROUTES ---
const authRoutes = require('./routes/auth');
const walletRoutes = require('./routes/wallet');
const providerRoutes = require('./routes/provider');
const shopsRoutes = require('./routes/shops');
const bookingsRoutes = require('./routes/bookings');
const notificationsRoutes = require('./routes/notifications');
const paymentsRoutes = require('./routes/payments');
const helpdeskRoutes = require('./routes/helpdesk');
const settingsRoutes = require('./routes/settings');

app.use('/api/auth', authRoutes);
app.use('/auth', authRoutes);

app.use('/api/wallet', walletRoutes);
app.use('/wallet', walletRoutes);

app.use('/api/provider', providerRoutes);
app.use('/provider', providerRoutes);

app.use('/api/shops', shopsRoutes);
app.use('/shops', shopsRoutes);

app.use('/api/bookings', bookingsRoutes);
app.use('/bookings', bookingsRoutes);

app.use('/api/notifications', notificationsRoutes);
app.use('/notifications', notificationsRoutes);

app.use('/api/payments', paymentsRoutes);
app.use('/payments', paymentsRoutes);

app.use('/api/helpdesk', helpdeskRoutes);
app.use('/helpdesk', helpdeskRoutes);

app.use('/api', settingsRoutes);
app.use('/', settingsRoutes);

// 404 Route Handler
app.use((req, res) => {
  res.status(404).json({ success: false, error: `Route '${req.originalUrl}' not found` });
});

// Global Error Handling Middleware
app.use((err, req, res, next) => {
  logger.error(`Unhandled error on ${req.method} ${req.originalUrl}:`, err);
  res.status(err.statusCode || 500).json({
    success: false,
    error: isProd ? 'Internal server error' : (err.message || 'Internal server error')
  });
});

// Start HTTP Server
const server = app.listen(PORT, '0.0.0.0', () => {
  logger.info(`QuickFix Enterprise Backend listening on 0.0.0.0:${PORT} [Mode: ${nodeEnv}]`);
});

// --- GRACEFUL SHUTDOWN HANDLER ---
let isShuttingDown = false;
const shutdown = (signal) => {
  if (isShuttingDown) return;
  isShuttingDown = true;
  logger.info(`Received ${signal}. Initiating graceful shutdown...`);

  // Stop accepting new requests
  server.close(async () => {
    logger.info("HTTP server closed.");
    try {
      if (mongoose.connection && mongoose.connection.readyState !== 0) {
        await mongoose.connection.close();
        logger.info("MongoDB connection closed.");
      }
      logger.info("Graceful shutdown completed successfully.");
      process.exit(0);
    } catch (err) {
      logger.error("Error during graceful shutdown:", err);
      process.exit(1);
    }
  });

  // Force shutdown after 10s if connections do not drain
  setTimeout(() => {
    logger.error("Could not close connections in time. Forcing shutdown.");
    process.exit(1);
  }, 10000);
};

process.on('SIGTERM', () => shutdown('SIGTERM'));
process.on('SIGINT', () => shutdown('SIGINT'));

process.on('unhandledRejection', (reason, promise) => {
  logger.error('Unhandled Promise Rejection:', reason);
});

process.on('uncaughtException', (err) => {
  logger.error('Uncaught Exception thrown:', err);
});

