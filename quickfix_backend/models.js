const mongoose = require('mongoose');
const fs = require('fs');
const path = require('path');

const dbPath = path.join(__dirname, 'database.json');
let useLocalDb = false;

function setUseLocalDb(val) {
  useLocalDb = val;
}

// Helper to read JSON database safely
function readDb() {
  try {
    if (!fs.existsSync(dbPath)) {
      fs.writeFileSync(dbPath, JSON.stringify({}));
    }
    const data = JSON.parse(fs.readFileSync(dbPath, 'utf8'));
    const collections = ['users', 'shops', 'bookings', 'categories', 'subcategories', 'catalogservices', 'reviews', 'professionals', 'banners', 'offers', 'notifications', 'demands', 'promotions', 'specialcards', 'cmssections', 'customsections', 'paymentledgers', 'settlements', 'paymentauditlogs', 'adminusers', 'helpdesktickets', 'ticketmessages', 'knowledgebases', 'helpdeskanalytics'];
    let changed = false;
    for (const col of collections) {
      if (!data[col]) {
        data[col] = [];
        changed = true;
      }
    }
    if (changed) {
      fs.writeFileSync(dbPath, JSON.stringify(data, null, 2));
    }
    return data;
  } catch (err) {
    console.error('Error reading JSON DB:', err);
    return {};
  }
}

// Helper to write JSON database safely
function writeDb(data) {
  try {
    fs.writeFileSync(dbPath, JSON.stringify(data, null, 2));
  } catch (err) {
    console.error('Error writing JSON DB:', err);
  }
}

// Matches query against local object fields (supporting basic MongoDB operators)
function matchesQuery(doc, query) {
  if (!query || Object.keys(query).length === 0) return true;
  for (const [key, val] of Object.entries(query)) {
    if (key === '$or') {
      if (!Array.isArray(val)) return false;
      const anyMatch = val.some(subQuery => matchesQuery(doc, subQuery));
      if (!anyMatch) return false;
      continue;
    }

    if (key === '$and') {
      if (!Array.isArray(val)) return false;
      const allMatch = val.every(subQuery => matchesQuery(doc, subQuery));
      if (!allMatch) return false;
      continue;
    }

    const docVal = doc[key];

    if (val && typeof val === 'object' && !Array.isArray(val)) {
      if (val instanceof RegExp) {
        if (!val.test(String(docVal))) return false;
        continue;
      }

      const operators = Object.keys(val);
      for (const op of operators) {
        if (op === '$ne') {
          if (Array.isArray(docVal)) {
            if (docVal.includes(val['$ne'])) return false;
          } else {
            if (docVal === val['$ne']) return false;
          }
        } else if (op === '$in') {
          if (!Array.isArray(val['$in'])) return false;
          if (Array.isArray(docVal)) {
            if (!docVal.some(item => val['$in'].includes(item))) return false;
          } else {
            if (!val['$in'].includes(docVal)) return false;
          }
        } else if (op === '$nin') {
          if (!Array.isArray(val['$nin'])) return false;
          if (Array.isArray(docVal)) {
            if (docVal.some(item => val['$nin'].includes(item))) return false;
          } else {
            if (val['$nin'].includes(docVal)) return false;
          }
        } else if (op === '$gt') {
          if (!(docVal > val['$gt'])) return false;
        } else if (op === '$gte') {
          if (!(docVal >= val['$gte'])) return false;
        } else if (op === '$lt') {
          if (!(docVal < val['$lt'])) return false;
        } else if (op === '$lte') {
          if (!(docVal <= val['$lte'])) return false;
        } else if (op === '$exists') {
          const exists = docVal !== undefined && docVal !== null;
          if (exists !== Boolean(val['$exists'])) return false;
        } else if (op === '$regex') {
          const opts = val['$options'] || '';
          const regex = new RegExp(val['$regex'], opts);
          if (!regex.test(String(docVal))) return false;
        } else if (op === '$options') {
          continue;
        } else {
          if (JSON.stringify(docVal) !== JSON.stringify(val)) return false;
        }
      }
    } else {
      if (docVal !== val) return false;
    }
  }
  return true;
}

// Wraps plain JS object with mongoose-like save() and toObject() methods
function wrapDoc(doc, collectionName) {
  if (!doc) return null;
  const wrapped = { ...doc };
  if (!wrapped._id && wrapped.id) {
    wrapped._id = wrapped.id;
  } else if (!wrapped._id) {
    wrapped._id = 'id_' + Math.random().toString(36).substr(2, 9);
  }

  Object.defineProperty(wrapped, 'toObject', {
    value: function() {
      return this;
    },
    writable: true,
    configurable: true
  });

  Object.defineProperty(wrapped, 'save', {
    value: async function() {
      const db = readDb();
      const list = db[collectionName] || [];
      const idx = list.findIndex(d => (d.id && d.id === this.id) || (d._id && d._id === this._id));

      const cleanDoc = {};
      for (const [k, v] of Object.entries(this)) {
        if (typeof v !== 'function') {
          cleanDoc[k] = v;
        }
      }

      if (idx !== -1) {
        cleanDoc.updatedAt = new Date().toISOString();
        list[idx] = cleanDoc;
      } else {
        cleanDoc.createdAt = new Date().toISOString();
        cleanDoc.updatedAt = new Date().toISOString();
        list.push(cleanDoc);
      }
      db[collectionName] = list;
      writeDb(db);
      return this;
    },
    writable: true,
    configurable: true
  });

  return wrapped;
}

// Custom array with mongoose-like sort() capability
function makeResultArray(arr, collectionName) {
  const result = arr.map(doc => wrapDoc(doc, collectionName));
  
  result.sort = function(sortObj) {
    const key = Object.keys(sortObj)[0];
    const dir = sortObj[key];
    const sorted = Array.prototype.sort.call(result, (a, b) => {
      let valA = a[key];
      let valB = b[key];
      if (valA instanceof Date) valA = valA.getTime();
      if (valB instanceof Date) valB = valB.getTime();
      if (typeof valA === 'string' && !isNaN(Date.parse(valA))) valA = new Date(valA).getTime();
      if (typeof valB === 'string' && !isNaN(Date.parse(valB))) valB = new Date(valB).getTime();

      if (valA < valB) return dir === -1 ? 1 : -1;
      if (valA > valB) return dir === -1 ? -1 : 1;
      return 0;
    });
    return makeResultArray(sorted, collectionName);
  };

  result.skip = function(n) {
    const sliced = result.slice(n);
    return makeResultArray(sliced, collectionName);
  };

  result.limit = function(n) {
    const sliced = result.slice(0, n);
    return makeResultArray(sliced, collectionName);
  };

  return result;
}

// Local mock models defaults — NO hardcoded names or fake data
const modelDefaults = {
  User: {
    name: '',
    email: '',
    membership: 'basic',
    walletBalance: 0.0,
    walletTransactions: [],
    savedAddresses: [],
    avatarUrl: '',
    gender: '',
    dob: '',
    alternatePhone: '',
    emergencyContact: '',
    preferredLanguage: 'English',
    isPhoneVerified: true,
    accountStatus: 'active',
    referralCode: '',
    referralCount: 0,
    referralRewardsEarned: 0,
    fcmToken: ''
  },
  Shop: {
    deliveryTimeMins: 20,
    estimatedServiceTime: '20 mins',
    priceRange: '₹₹',
    rating: 5.0,
    reviewsCount: 0,
    isOpen: true,
    isOnline: true,
    status: 'active',
    verificationStatus: 'approved',
    visitingCharges: 150.0,
    services: [],
    technicians: [],
    categories: ["Cleaning"],
    subcategories: []
  }
};

function applyUpdate(doc, updateData) {
  const updated = { ...doc };
  if (!updateData) return updated;

  for (const [k, v] of Object.entries(updateData)) {
    if (k === '$set' && typeof v === 'object' && v !== null) {
      Object.assign(updated, v);
    } else if (k === '$addToSet' && typeof v === 'object' && v !== null) {
      for (const [subKey, subVal] of Object.entries(v)) {
        if (!Array.isArray(updated[subKey])) {
          updated[subKey] = [];
        }
        if (typeof subVal === 'object' && subVal !== null && subVal.$each && Array.isArray(subVal.$each)) {
          for (const item of subVal.$each) {
            if (!updated[subKey].includes(item)) updated[subKey].push(item);
          }
        } else {
          if (!updated[subKey].includes(subVal)) updated[subKey].push(subVal);
        }
      }
    } else if (k === '$push' && typeof v === 'object' && v !== null) {
      for (const [subKey, subVal] of Object.entries(v)) {
        if (!Array.isArray(updated[subKey])) updated[subKey] = [];
        updated[subKey].push(subVal);
      }
    } else if (k === '$unset' && typeof v === 'object' && v !== null) {
      for (const subKey of Object.keys(v)) {
        delete updated[subKey];
      }
    } else if (!k.startsWith('$')) {
      updated[k] = v;
    }
  }
  updated.updatedAt = new Date().toISOString();
  return updated;
}

// Generates a mock model class
function createMockModel(modelName, collectionName) {
  class MockModel {
    constructor(data) {
      const defaults = modelDefaults[modelName] || {};
      Object.assign(this, defaults, data);
      if (!this.id && !this._id) {
        this._id = 'id_' + Math.random().toString(36).substr(2, 9);
      }
      return wrapDoc(this, collectionName);
    }

    static async find(query) {
      const db = readDb();
      const list = db[collectionName] || [];
      const filtered = list.filter(doc => matchesQuery(doc, query));
      return makeResultArray(filtered, collectionName);
    }

    static async findOne(query) {
      const db = readDb();
      const list = db[collectionName] || [];
      const found = list.find(doc => matchesQuery(doc, query));
      return found ? wrapDoc(found, collectionName) : null;
    }

    static async findById(id) {
      const db = readDb();
      const list = db[collectionName] || [];
      const found = list.find(doc => doc._id === id || doc.id === id);
      return found ? wrapDoc(found, collectionName) : null;
    }

    static async aggregate(pipeline) {
      const db = readDb();
      let current = db[collectionName] || [];
      current = JSON.parse(JSON.stringify(current));
      
      for (const stage of pipeline) {
        if (stage.$match) {
          current = current.filter(doc => matchesQuery(doc, stage.$match));
        } else if (stage.$unwind) {
          let path = stage.$unwind;
          let preserveNull = false;
          if (typeof path === 'object') {
            preserveNull = !!path.preserveNullAndEmptyArrays;
            path = path.path;
          }
          const field = path.replace(/^\$/, '');
          const nextList = [];
          for (const doc of current) {
            const val = doc[field];
            if (Array.isArray(val)) {
              if (val.length === 0) {
                if (preserveNull) {
                  const copy = { ...doc };
                  copy[field] = null;
                  nextList.push(copy);
                }
              } else {
                for (const item of val) {
                  const copy = { ...doc };
                  copy[field] = item;
                  nextList.push(copy);
                }
              }
            } else if (val === undefined || val === null) {
              if (preserveNull) {
                const copy = { ...doc };
                copy[field] = null;
                nextList.push(copy);
              }
            } else {
              nextList.push(doc);
            }
          }
          current = nextList;
        } else if (stage.$lookup) {
          const { from, localField, foreignField, as } = stage.$lookup;
          const foreignDocs = db[from] || [];
          for (const doc of current) {
            const val = doc[localField];
            const matches = foreignDocs.filter(fd => fd[foreignField] === val);
            doc[as] = matches;
          }
        } else if (stage.$project) {
          current = current.map(doc => {
            const projected = {};
            for (const [k, v] of Object.entries(stage.$project)) {
              if (v === 1) {
                projected[k] = doc[k];
              } else if (typeof v === 'object' && v.$cond) {
                const isArray = Array.isArray(doc.services);
                projected[k] = isArray ? doc.services.length : 0;
              } else if (typeof v === 'object' && v.$ifNull) {
                const [target, fallback] = v.$ifNull;
                const path = target.replace(/^\$/, '');
                projected[k] = doc[path] !== undefined && doc[path] !== null ? doc[path] : fallback;
              }
            }
            if (doc._id) projected._id = doc._id;
            if (doc.id) projected.id = doc.id;
            return projected;
          });
        } else if (stage.$group) {
          const { _id, ...aggregators } = stage.$group;
          const groups = {};
          for (const doc of current) {
            let key = 'null';
            if (typeof _id === 'string' && _id.startsWith('$')) {
              key = String(doc[_id.replace(/^\$/, '')]);
            } else if (typeof _id === 'object' && _id.$dateToString) {
              const { date } = _id.$dateToString;
              const dateVal = doc[date.replace(/^\$/, '')];
              if (dateVal) {
                const d = new Date(dateVal);
                key = d.toLocaleDateString('en-IN', { day: '2-digit', month: 'short' });
              }
            }
            if (!groups[key]) groups[key] = [];
            groups[key].push(doc);
          }
          
          const result = [];
          for (const [key, groupDocs] of Object.entries(groups)) {
            const entry = { _id: key === 'null' ? null : key };
            for (const [aggKey, aggVal] of Object.entries(aggregators)) {
              if (aggVal.$sum) {
                let sum = 0;
                if (typeof aggVal.$sum === 'number') {
                  sum = groupDocs.length * aggVal.$sum;
                } else if (typeof aggVal.$sum === 'string' && aggVal.$sum.startsWith('$')) {
                  const fieldName = aggVal.$sum.replace(/^\$/, '');
                  sum = groupDocs.reduce((acc, d) => acc + (parseFloat(d[fieldName]) || 0), 0);
                } else if (typeof aggVal.$sum === 'object' && aggVal.$sum.$cond) {
                  const [cond, trueVal, falseVal] = aggVal.$sum.$cond;
                  if (cond.$eq) {
                    const [fieldExp, targetVal] = cond.$eq;
                    const fieldName = fieldExp.replace(/^\$/, '');
                    sum = groupDocs.reduce((acc, d) => {
                      const matches = d[fieldName] === targetVal;
                      const val = matches ? (typeof trueVal === 'string' && trueVal.startsWith('$') ? parseFloat(d[trueVal.replace(/^\$/, '')]) || 0 : trueVal) : falseVal;
                      return acc + val;
                    }, 0);
                  }
                }
                entry[aggKey] = sum;
              }
            }
            result.push(entry);
          }
          current = result;
        }
      }
      return current;
    }

    static async countDocuments(query) {
      const db = readDb();
      const list = db[collectionName] || [];
      return list.filter(doc => matchesQuery(doc, query)).length;
    }

    static async create(data) {
      const doc = new MockModel(data);
      await doc.save();
      return doc;
    }

    static async insertMany(arr) {
      const db = readDb();
      const list = db[collectionName] || [];
      const inserted = [];
      for (const item of arr) {
        const doc = {
          ...item,
          _id: item._id || item.id || 'id_' + Math.random().toString(36).substr(2, 9),
          createdAt: new Date().toISOString(),
          updatedAt: new Date().toISOString()
        };
        list.push(doc);
        inserted.push(wrapDoc(doc, collectionName));
      }
      db[collectionName] = list;
      writeDb(db);
      return inserted;
    }

    static async findOneAndUpdate(query, updateData, options) {
      const db = readDb();
      const list = db[collectionName] || [];
      const idx = list.findIndex(doc => matchesQuery(doc, query));
      if (idx === -1) return null;

      const updated = applyUpdate(list[idx], updateData);
      list[idx] = updated;
      db[collectionName] = list;
      writeDb(db);
      return wrapDoc(updated, collectionName);
    }

    static async findByIdAndUpdate(id, updateData, options) {
      return this.findOneAndUpdate({ _id: id }, updateData, options);
    }

    static async findOneAndDelete(query) {
      const db = readDb();
      const list = db[collectionName] || [];
      const idx = list.findIndex(doc => matchesQuery(doc, query));
      if (idx === -1) return null;
      const deleted = list.splice(idx, 1)[0];
      db[collectionName] = list;
      writeDb(db);
      return wrapDoc(deleted, collectionName);
    }

    static async findByIdAndDelete(id) {
      return this.findOneAndDelete({ _id: id });
    }

    static async deleteOne(query) {
      const db = readDb();
      const list = db[collectionName] || [];
      const idx = list.findIndex(doc => matchesQuery(doc, query));
      if (idx === -1) {
        return { acknowledged: true, deletedCount: 0 };
      }
      list.splice(idx, 1);
      db[collectionName] = list;
      writeDb(db);
      return { acknowledged: true, deletedCount: 1 };
    }

    static async deleteMany(query) {
      const db = readDb();
      const list = db[collectionName] || [];
      const remaining = [];
      let deletedCount = 0;
      for (const doc of list) {
        if (matchesQuery(doc, query)) {
          deletedCount++;
        } else {
          remaining.push(doc);
        }
      }
      db[collectionName] = remaining;
      writeDb(db);
      return { acknowledged: true, deletedCount };
    }

    static async updateOne(query, updateData) {
      const db = readDb();
      const list = db[collectionName] || [];
      const idx = list.findIndex(doc => matchesQuery(doc, query));
      if (idx === -1) {
        return { acknowledged: true, matchedCount: 0, modifiedCount: 0 };
      }
      list[idx] = applyUpdate(list[idx], updateData);
      db[collectionName] = list;
      writeDb(db);
      return { acknowledged: true, matchedCount: 1, modifiedCount: 1 };
    }

    static async updateMany(query, updateData) {
      const db = readDb();
      const list = db[collectionName] || [];
      let matchedCount = 0;
      let modifiedCount = 0;
      for (let i = 0; i < list.length; i++) {
        if (matchesQuery(list[i], query)) {
          matchedCount++;
          list[i] = applyUpdate(list[i], updateData);
          modifiedCount++;
        }
      }
      if (modifiedCount > 0) {
        db[collectionName] = list;
        writeDb(db);
      }
      return { acknowledged: true, matchedCount, modifiedCount };
    }
  }

  return MockModel;
}

// 1. User Schema (Customer profiles)
const UserSchema = new mongoose.Schema({
  phone: { type: String, required: true, unique: true, index: true },
  name: { type: String, default: '' },
  email: { type: String, default: '' },
  membership: { type: String, default: 'basic' },
  walletBalance: { type: Number, default: 0.0 },
  walletTransactions: [{
    id: String,
    title: String,
    amount: Number,
    type: { type: String, enum: ['credit', 'debit'] },
    date: { type: Date, default: Date.now }
  }],
  savedAddresses: {
    type: [{
      id: String,
      label: String,
      address: String,
      latitude: Number,
      longitude: Number,
      isDefault: Boolean
    }],
    default: []
  },
  avatarUrl: { type: String, default: '' },
  gender: { type: String, default: '' },
  dob: { type: String, default: '' },
  alternatePhone: { type: String, default: '' },
  emergencyContact: { type: String, default: '' },
  preferredLanguage: { type: String, default: 'English' },
  isPhoneVerified: { type: Boolean, default: true },
  accountStatus: { type: String, enum: ['active', 'inactive', 'deleted'], default: 'active' },
  referralCode: { type: String, default: '' },
  referralCount: { type: Number, default: 0 },
  referralRewardsEarned: { type: Number, default: 0 },
  memberSince: { type: Date, default: Date.now },
  fcmToken: { type: String, default: '' }
}, { timestamps: true });

// 2. Service Item Schema (sub-document for Shop services)
const ServiceSchema = new mongoose.Schema({
  id: { type: String, required: true },
  title: { type: String, required: true },
  price: { type: Number, required: true },
  originalPrice: { type: Number },
  rating: { type: Number, default: 5.0 },
  reviewsCount: { type: Number, default: 0 },
  durationText: { type: String, default: '1 hr' },
  bulletPoints: [String],
  imageUrl: String,
  pricingType: { type: String, enum: ['fixed', 'starting', 'inspection', 'range'], default: 'fixed' },
  minPrice: { type: Number, default: 0 },
  maxPrice: { type: Number, default: 0 },
  visitingCharges: { type: Number, default: 0 },
  isFreeInspection: { type: Boolean, default: false },
  gst: { type: Number, default: 0 },
  extraCharges: { type: Number, default: 0 },
  extraChargesLabel: { type: String, default: '' },
  allowPriceEdit: { type: Boolean, default: true },
  allowVisitingEdit: { type: Boolean, default: true },
  isAvailable: { type: Boolean, default: true },
  isEnabled: { type: Boolean, default: true }
});

// 3. Shop Schema (Service Provider shop profile)
const ShopSchema = new mongoose.Schema({
  id: { type: String, required: true, unique: true, index: true },
  shopDisplayId: { type: String, default: '', index: true },
  name: { type: String, required: true },
  ownerName: { type: String, required: true },
  password: { type: String, required: true }, // will be hashed using bcrypt
  tempPassword: { type: String, default: '' },
  phone: { type: String, required: true, unique: true, index: true },
  email: { type: String, default: '' },
  latitude: { type: Number, default: 26.4912 },
  longitude: { type: Number, default: 80.3156 },
  address: { type: String, default: '' },
  serviceRadius: { type: Number, default: 5.0 },
  logoPath: { type: String, default: '' },
  logoUrl: { type: String, default: '' },
  categories: { type: [String], default: ["Cleaning"] },
  subcategories: { type: [String], default: [] },
  imagePath: { type: String, default: 'https://images.unsplash.com/photo-1581578731548-c64695cc6952?w=300' },
  rating: { type: Number, default: 5.0 },
  reviewsCount: { type: Number, default: 0 },
  deliveryTimeMins: { type: Number, default: 20 },
  estimatedServiceTime: { type: String, default: '20 mins' },
  priceRange: { type: String, default: "₹₹" },
  isOnline: { type: Boolean, default: true },
  timings: { type: String, default: "09:00 AM - 09:00 PM" },
  portfolioImages: [String],
  services: [ServiceSchema],
  status: { type: String, enum: ['active', 'inactive', 'suspended'], default: 'active' },
  isOpen: { type: Boolean, default: true },
  verificationStatus: { type: String, enum: ['pending', 'approved', 'rejected'], default: 'approved' },
  visitingCharges: { type: Number, default: 150.0 },
  technicians: { type: [String], default: [] },
  gst: { type: String, default: '' },
  pan: { type: String, default: '' },
  aadhaar: { type: String, default: '' },
  verificationDocs: { type: [String], default: [] },
  loginDisabled: { type: Boolean, default: false },
  // Customization fields for Shop Details UI (Urban Company style)
  offerBannerText: { type: String, default: 'Flat ₹100 OFF on First Booking' },
  offerBannerCode: { type: String, default: 'QUICK100' },
  offerBannerSubtext: { type: String, default: 'Use code QUICK100 at checkout • Free inspection included' },
  customCategories: { type: [String], default: [] },
  // Provider App extensions
  isFirstLogin: { type: Boolean, default: true },
  ownerPhone: { type: String, default: '' },
  ownerEmail: { type: String, default: '' },
  ownerPhotoUrl: { type: String, default: '' },
  bankAccountNumber: { type: String, default: '' },
  ifscCode: { type: String, default: '' },
  upiId: { type: String, default: '' },
  walletBalance: { type: Number, default: 0.0 },
  walletTransactions: { type: Array, default: [] },
  commissionRate: { type: Number, default: 15.0 }, // 15% commission default
  workingHours: {
    type: Map,
    of: {
      isClosed: { type: Boolean, default: false },
      openTime: { type: String, default: '09:00 AM' },
      closeTime: { type: String, default: '09:00 PM' }
    },
    default: {
      'Monday': { isClosed: false, openTime: '09:00 AM', closeTime: '09:00 PM' },
      'Tuesday': { isClosed: false, openTime: '09:00 AM', closeTime: '09:00 PM' },
      'Wednesday': { isClosed: false, openTime: '09:00 AM', closeTime: '09:00 PM' },
      'Thursday': { isClosed: false, openTime: '09:00 AM', closeTime: '09:00 PM' },
      'Friday': { isClosed: false, openTime: '09:00 AM', closeTime: '09:00 PM' },
      'Saturday': { isClosed: false, openTime: '09:00 AM', closeTime: '09:00 PM' },
      'Sunday': { isClosed: false, openTime: '09:00 AM', closeTime: '09:00 PM' }
    }
  },
  holidays: { type: [String], default: [] },
  emergencyAvailable: { type: Boolean, default: false },
  reviewReplies: { type: Map, of: String, default: {} },
  providerLat: { type: Number },
  providerLng: { type: Number },
  fcmToken: { type: String, default: '' }
}, { timestamps: true });

// 4. Booking Schema (Service Orders)
const BookingSchema = new mongoose.Schema({
  id: { type: String, required: true, unique: true, index: true }, // QF-XXXXXX format
  customerId: { type: String, required: true, index: true },
  customerName: { type: String, required: true },
  customerPhone: { type: String, required: true },
  customerAddress: { type: String, required: true }, // complete full address
  approxAddress: { type: String, default: '' }, // e.g. "Swaroop Nagar, Kanpur"
  customerLat: { type: Number, default: 26.4912 },
  customerLng: { type: Number, default: 80.3156 },
  providerLat: { type: Number },
  providerLng: { type: Number },
  shopId: { type: String, required: true, index: true },
  title: { type: String, required: true }, // Description of items ordered
  slot: { type: String, required: true },
  date: { type: Date, required: true },
  amount: { type: Number, required: true },
  visitingCharges: { type: Number, default: 150.0 },
  estEarnings: { type: Number, default: 0.0 },
  estDuration: { type: String, default: '1.5 hrs' },
  specialInstructions: { type: String, default: '' },
  customerRating: { type: Number, default: 4.8 },
  pricingType: { type: String, enum: ['fixed', 'starting', 'inspection', 'range'], default: 'fixed' },
  paymentMethod: { type: String, default: 'UPI' },
  issuePhoto: { type: String, default: '' },
  isInstant: { type: Boolean, default: false, index: true },
  status: { 
    type: String, 
    enum: ['pending', 'accepted', 'navigating', 'arrived', 'quote_sent', 'work_started', 'work_completed', 'payment_completed', 'cancelled', 'closed'], 
    default: 'pending',
    index: true
  },
  providerName: { type: String, default: 'Assigning Expert...' },
  quotation: {
    labourCharge: { type: Number, default: 0 },
    spareParts: { type: Number, default: 0 },
    additionalMaterials: { type: Number, default: 0 },
    visitingCharges: { type: Number, default: 0 },
    discount: { type: Number, default: 0 },
    gst: { type: Number, default: 0 },
    totalAmount: { type: Number, default: 0 },
    status: { type: String, enum: ['pending', 'accepted', 'rejected', 'modified'], default: 'pending' },
    createdAt: { type: Date },
    updatedAt: { type: Date }
  },
  quotationHistory: { type: Array, default: [] }
}, { timestamps: true });

// 5. Category Schema
const CategorySchema = new mongoose.Schema({
  id: { type: String, required: true, unique: true, index: true },
  name: { type: String, required: true },
  iconUrl: { type: String, default: '' },
  isActive: { type: Boolean, default: true }
});

// 5a. Subcategory Schema (Dynamic Admin-Managed Subcategories)
const SubcategorySchema = new mongoose.Schema({
  id: { type: String, required: true, unique: true, index: true },
  categoryId: { type: String, required: true, index: true },
  name: { type: String, required: true },
  description: { type: String, default: '' },
  imageUrl: { type: String, default: '' },
  displayOrder: { type: Number, default: 0 },
  isActive: { type: Boolean, default: true }
}, { timestamps: true });

// 5b. Catalog Service Schema (Admin-Managed Service Offerings under Subcategory)
const CatalogServiceSchema = new mongoose.Schema({
  id: { type: String, required: true, unique: true, index: true },
  categoryId: { type: String, required: true, index: true },
  subcategoryId: { type: String, required: true, index: true },
  title: { type: String, required: true },
  description: { type: String, default: '' },
  imageUrl: { type: String, default: '' },
  price: { type: Number, required: true, default: 0 },
  originalPrice: { type: Number, default: 0 },
  pricingType: { type: String, enum: ['fixed', 'starting', 'inspection', 'range'], default: 'fixed' },
  minPrice: { type: Number, default: 0 },
  maxPrice: { type: Number, default: 0 },
  visitingCharges: { type: Number, default: 0 },
  isFreeInspection: { type: Boolean, default: false },
  durationText: { type: String, default: '1 hr' },
  bulletPoints: { type: [String], default: [] },
  rating: { type: Number, default: 4.8 },
  reviewsCount: { type: Number, default: 0 },
  displayOrder: { type: Number, default: 0 },
  isActive: { type: Boolean, default: true }
}, { timestamps: true });

// 6. Review Schema (Customer Feedbacks feed)
const ReviewSchema = new mongoose.Schema({
  id: { type: String, required: true, unique: true, index: true },
  userName: { type: String, required: true },
  userAvatar: { type: String },
  rating: { type: Number, required: true },
  comment: { type: String, required: true },
  serviceName: { type: String },
  locationName: { type: String },
  shopId: { type: String, default: '', index: true },
  reply: { type: String, default: '' },
  providerName: { type: String, default: '' },
  date: { type: String, default: '' },
  verifiedBadge: { type: Boolean, default: true },
  priority: { type: Number, default: 0 },
  status: { type: String, enum: ['approved', 'pending', 'rejected'], default: 'approved' },
  isActive: { type: Boolean, default: true },
  isFeatured: { type: Boolean, default: false }
});

// 7. Professional Schema (Top service experts cards)
const ProfessionalSchema = new mongoose.Schema({
  id: { type: String, required: true, unique: true },
  name: { type: String, required: true },
  specialty: { type: String, required: true },
  rating: { type: Number, default: 5.0 },
  reviewsCount: { type: Number, default: 0 },
  imageUrl: { type: String },
  shopId: { type: String, default: '' },
  experience: { type: String, default: '' },
  completedJobs: { type: Number, default: 0 },
  location: { type: String, default: '' },
  verifiedBadge: { type: Boolean, default: false },
  availability: { type: Boolean, default: true },
  featuredStatus: { type: String, default: 'Featured' },
  priority: { type: Number, default: 0 },
  isActive: { type: Boolean, default: true }
});

// 8. Promo Banner Schema (Carousel Banners)
const BannerSchema = new mongoose.Schema({
  id: { type: String, required: true, unique: true },
  title: { type: String, default: '' },
  code: { type: String, default: '' },
  percent: { type: String, default: '' },
  imageUrl: { type: String },
  isActive: { type: Boolean, default: true },
  redirectUrl: { type: String, default: '' },
  priority: { type: Number, default: 0 },
  expiryDate: { type: String, default: '' }
});

// 9. Promo Offer Coupon Schema
const OfferSchema = new mongoose.Schema({
  code: { type: String, required: true, unique: true },
  title: { type: String, required: true },
  description: { type: String, required: true },
  isActive: { type: Boolean, default: true },
  minOrderAmount: { type: Number, default: 0 },
  maxDiscount: { type: Number, default: 0 },
  expiryDate: { type: String, default: '' },
  usageLimit: { type: Number, default: 0 },
  usedCount: { type: Number, default: 0 }
});

// 10. Broadcast Alert Notification Schema
const NotificationSchema = new mongoose.Schema({
  id: { type: String, required: true, unique: true },
  title: { type: String, required: true },
  body: { type: String, required: true },
  time: { type: String, default: 'Just now' },
  icon: { type: String, default: 'notifications_active' },
  iconColor: { type: String, default: 'primary' },
  userId: { type: String, default: '' },
  shopId: { type: String, default: '' },
  type: { type: String, default: 'general' },
  bookingId: { type: String, default: '' },
  deepLink: { type: String, default: '' },
  isRead: { type: Boolean, default: false },
  readAt: { type: Date, default: null },
  readBy: { type: [String], default: [] },
  deletedBy: { type: [String], default: [] }
}, { timestamps: true });

// 11. Customer Demand Schema
const DemandSchema = new mongoose.Schema({
  id: { type: String, required: true, unique: true },
  phone: { type: String, required: true },
  address: { type: String, required: true },
  latitude: { type: Number, required: true },
  longitude: { type: Number, required: true }
}, { timestamps: true });

// 12. Settings Schema
const SettingsSchema = new mongoose.Schema({
  key: { type: String, required: true, unique: true },
  value: { type: mongoose.Schema.Types.Mixed }
});

// 13. Audit Log Schema
const AuditLogSchema = new mongoose.Schema({
  id: { type: String, required: true, unique: true },
  adminId: { type: String, default: 'super-admin' },
  action: { type: String, required: true },
  target: { type: String, default: '' },
  details: { type: String, default: '' },
  ip: { type: String, default: '127.0.0.1' }
}, { timestamps: true });

// 14. Promotion Schema (Home Promotions / Festive Ribbon)
const PromotionSchema = new mongoose.Schema({
  id: { type: String, required: true, unique: true },
  title: { type: String, required: true },
  subtitle: { type: String, default: '' },
  description: { type: String, default: '' },
  offerPercentage: { type: String, default: '' },
  couponCode: { type: String, default: '' },
  ctaButtonText: { type: String, default: 'Grab Now' },
  ctaButtonAction: { type: String, default: 'No Action' },
  ctaButtonActionValue: { type: String, default: '' },
  bannerImage: { type: String, default: '' },
  backgroundColor: { type: String, default: '#FFF1F0' },
  textColor: { type: String, default: '#000000' },
  buttonColor: { type: String, default: '#FF4D4F' },
  buttonTextColor: { type: String, default: '#FFFFFF' },
  priority: { type: Number, default: 0 },
  startDate: { type: String, default: '' },
  endDate: { type: String, default: '' },
  isActive: { type: Boolean, default: true }
}, { timestamps: true });

// 15. Special For You Card Schema
const SpecialCardSchema = new mongoose.Schema({
  id: { type: String, required: true, unique: true },
  icon: { type: String, default: 'star' },
  imageUrl: { type: String, default: '' },
  title: { type: String, required: true },
  subtitle: { type: String, default: '' },
  description: { type: String, default: '' },
  backgroundColor: { type: String, default: '#FFFFFF' },
  buttonText: { type: String, default: 'View' },
  ctaAction: { type: String, default: 'No Action' },
  ctaActionValue: { type: String, default: '' },
  priority: { type: Number, default: 0 },
  isActive: { type: Boolean, default: true },
  startDate: { type: String, default: '' },
  endDate: { type: String, default: '' }
}, { timestamps: true });

// 16. CMS Dynamic Layout Section Schema
const CmsSectionSchema = new mongoose.Schema({
  id: { type: String, required: true, unique: true },
  title: { type: String, default: '' },
  type: { type: String, required: true },
  priority: { type: Number, default: 0 },
  isActive: { type: Boolean, default: true },
  settings: { type: mongoose.Schema.Types.Mixed, default: {} }
}, { timestamps: true });

// 17. Custom Homepage Section Service Item Schema (sub-document)
const CustomSectionServiceItemSchema = new mongoose.Schema({
  id: { type: String, required: true },
  title: { type: String, required: true },
  imageUrl: { type: String, default: '' },
  rating: { type: Number, default: 4.5 },
  reviewsCount: { type: String, default: '' },
  startingPrice: { type: String, default: '' },
  actionType: { type: String, default: 'Open Shop' },
  actionValue: { type: String, default: '' }
});

// 17. Custom Homepage Section Schema (banner + service card list)
const CustomSectionSchema = new mongoose.Schema({
  id: { type: String, required: true, unique: true },
  title: { type: String, default: '' },
  subtitle: { type: String, default: '' },
  bannerImageUrl: { type: String, default: '' },
  bannerBadgeText: { type: String, default: '' },
  bannerButtonText: { type: String, default: 'Explore now' },
  bannerActionType: { type: String, default: 'Open Category' },
  bannerActionValue: { type: String, default: '' },
  seeAllActionType: { type: String, default: 'Open Category' },
  seeAllActionValue: { type: String, default: '' },
  serviceItems: { type: [CustomSectionServiceItemSchema], default: [] },
  priority: { type: Number, default: 0 },
  isActive: { type: Boolean, default: true }
}, { timestamps: true });

// 18. Payment Ledger Schema (one record per booking - central accounting document)
const PaymentLedgerSchema = new mongoose.Schema({
  id: { type: String, required: true, unique: true },
  bookingId: { type: String, required: true, unique: true },
  customerId: { type: String, required: true },
  providerId: { type: String, required: true }, // shopId
  shopId: { type: String, required: true },
  providerName: { type: String, default: '' },
  customerName: { type: String, default: '' },
  serviceTitle: { type: String, default: '' },
  grossAmount: { type: Number, required: true, default: 0 },
  commissionRate: { type: Number, default: 20.0 },
  commissionAmount: { type: Number, default: 0 },
  gatewayCharges: { type: Number, default: 0 },
  providerEarnings: { type: Number, default: 0 },
  platformRevenue: { type: Number, default: 0 },
  paymentMethod: { type: String, enum: ['cash', 'online', 'wallet', 'upi', 'card', 'netbanking'], default: 'cash' },
  paymentStatus: {
    type: String,
    enum: ['pending', 'authorized', 'paid', 'failed', 'refunded', 'cancelled', 'cash_pending', 'cash_collected', 'settlement_pending', 'settled', 'commission_pending', 'commission_paid'],
    default: 'pending'
  },
  commissionStatus: { type: String, enum: ['pending', 'paid', 'waived', 'na'], default: 'pending' },
  settlementId: { type: String, default: '' },
  transactionId: { type: String, default: '' },
  gatewayOrderId: { type: String, default: '' },
  gatewaySignature: { type: String, default: '' },
  refundAmount: { type: Number, default: 0 },
  refundStatus: { type: String, enum: ['none', 'initiated', 'completed', 'failed'], default: 'none' },
  ledgerEntries: [{
    id: String,
    type: { type: String, enum: ['credit', 'debit', 'hold', 'release'] },
    amount: Number,
    party: { type: String, enum: ['customer', 'provider', 'platform'] },
    description: String,
    timestamp: { type: Date, default: Date.now }
  }],
  metadata: { type: mongoose.Schema.Types.Mixed, default: {} }
}, { timestamps: true });

// 19. Settlement Schema (one record per provider payout event)
const SettlementSchema = new mongoose.Schema({
  id: { type: String, required: true, unique: true },
  shopId: { type: String, required: true },
  providerId: { type: String, required: true },
  providerName: { type: String, default: '' },
  settlementType: { type: String, enum: ['daily', 'weekly', 'manual', 'auto'], default: 'manual' },
  amount: { type: Number, required: true },
  bookingIds: { type: [String], default: [] },
  ledgerIds: { type: [String], default: [] },
  status: { type: String, enum: ['pending', 'approved', 'processing', 'completed', 'failed', 'rejected'], default: 'pending' },
  bankAccount: { type: String, default: '' },
  ifscCode: { type: String, default: '' },
  upiId: { type: String, default: '' },
  transactionId: { type: String, default: '' },
  adminNote: { type: String, default: '' },
  requestedAt: { type: Date, default: Date.now },
  approvedAt: { type: Date },
  completedAt: { type: Date },
  rejectedAt: { type: Date }
}, { timestamps: true });

// 20. Payment Audit Log Schema (immutable event log for every payment event)
const PaymentAuditLogSchema = new mongoose.Schema({
  id: { type: String, required: true, unique: true },
  eventType: {
    type: String,
    enum: [
      'booking_created', 'payment_initiated', 'payment_success', 'payment_failed',
      'commission_calculated', 'wallet_updated', 'settlement_created', 'settlement_approved',
      'settlement_completed', 'settlement_failed', 'refund_processed', 'commission_collected',
      'cash_confirmed', 'ledger_created', 'ledger_updated'
    ],
    required: true
  },
  bookingId: { type: String, default: '' },
  ledgerId: { type: String, default: '' },
  shopId: { type: String, default: '' },
  customerId: { type: String, default: '' },
  settlementId: { type: String, default: '' },
  amount: { type: Number, default: 0 },
  description: { type: String, default: '' },
  actor: { type: String, default: 'system' }, // 'system', 'admin', 'provider', 'customer'
  metadata: { type: mongoose.Schema.Types.Mixed, default: {} }
}, { timestamps: true });

// 21. Admin User Schema (secure admin auth and brute-force protection)
const AdminUserSchema = new mongoose.Schema({
  username: { type: String, required: true, unique: true, default: 'admin' },
  passwordHash: { type: String, required: true },
  role: { type: String, default: 'admin' },
  failedAttempts: { type: Number, default: 0 },
  lockUntil: { type: Date, default: null }
}, { timestamps: true });

// 22. Helpdesk Ticket Schema
const HelpdeskTicketSchema = new mongoose.Schema({
  id: { type: String, required: true, unique: true, index: true }, // TK-XXXXXX format
  ticketId: { type: String, default: '', index: true },
  customerId: { type: String, required: true, index: true },
  customerName: { type: String, default: '' },
  customerPhone: { type: String, default: '' },
  customerEmail: { type: String, default: '' },
  providerId: { type: String, default: '' },
  providerName: { type: String, default: '' },
  bookingId: { type: String, default: '', index: true },
  category: { type: String, default: 'General Question', index: true },
  priority: { type: String, enum: ['low', 'medium', 'high', 'urgent'], default: 'medium', index: true },
  issueSummary: { type: String, default: '' },
  fullConversation: { type: Array, default: [] },
  aiSummary: { type: String, default: '' },
  aiSuggestedResolution: { type: String, default: '' },
  deviceInfo: { type: mongoose.Schema.Types.Mixed, default: {} },
  platform: { type: String, default: 'mobile' },
  appVersion: { type: String, default: '1.0.0' },
  attachments: { type: Array, default: [] },
  status: { 
    type: String, 
    enum: ['open', 'pending_admin', 'admin_reply', 'in_progress', 'resolved', 'closed'], 
    default: 'open',
    index: true
  },
  assignedAdmin: { type: String, default: 'Unassigned' },
  userSentiment: { type: String, enum: ['neutral', 'calm', 'confused', 'angry', 'furious', 'emergency'], default: 'neutral' },
  refundAmountRequested: { type: Number, default: 0 },
  refundStatus: { type: String, enum: ['none', 'pending', 'approved', 'rejected'], default: 'none' },
  complaintSeverity: { type: String, default: 'normal' },
  resolvedAt: { type: Date }
}, { timestamps: true });

// 23. Ticket Message Schema
const TicketMessageSchema = new mongoose.Schema({
  id: { type: String, required: true, unique: true, index: true },
  ticketId: { type: String, required: true, index: true },
  sender: { type: String, enum: ['user', 'admin', 'ai', 'system'], default: 'user' },
  senderName: { type: String, default: '' },
  text: { type: String, required: true },
  attachments: { type: Array, default: [] },
  timestamp: { type: Date, default: Date.now },
  isRead: { type: Boolean, default: false }
}, { timestamps: true });

// 24. Knowledge Base Article Schema
const KnowledgeBaseSchema = new mongoose.Schema({
  id: { type: String, required: true, unique: true, index: true },
  category: { type: String, required: true, index: true },
  title: { type: String, required: true },
  keywords: { type: [String], default: [] },
  content: { type: String, required: true },
  actionType: { type: String, default: '' },
  priority: { type: Number, default: 0 },
  isActive: { type: Boolean, default: true }
}, { timestamps: true });

// 25. Helpdesk Analytics Daily Metric Schema
const HelpdeskAnalyticsSchema = new mongoose.Schema({
  id: { type: String, required: true, unique: true, index: true },
  date: { type: String, required: true, index: true },
  totalTickets: { type: Number, default: 0 },
  aiResolvedCount: { type: Number, default: 0 },
  humanResolvedCount: { type: Number, default: 0 },
  openTickets: { type: Number, default: 0 },
  refundCount: { type: Number, default: 0 },
  avgResponseTimeMins: { type: Number, default: 0 }
}, { timestamps: true });

const MongooseModels = {
  User: mongoose.model('User', UserSchema),
  Shop: mongoose.model('Shop', ShopSchema),
  Booking: mongoose.model('Booking', BookingSchema),
  Category: mongoose.model('Category', CategorySchema),
  Subcategory: mongoose.model('Subcategory', SubcategorySchema),
  CatalogService: mongoose.model('CatalogService', CatalogServiceSchema),
  Review: mongoose.model('Review', ReviewSchema),
  Professional: mongoose.model('Professional', ProfessionalSchema),
  Banner: mongoose.model('Banner', BannerSchema),
  Offer: mongoose.model('Offer', OfferSchema),
  Notification: mongoose.model('Notification', NotificationSchema),
  Demand: mongoose.model('Demand', DemandSchema),
  Settings: mongoose.model('Settings', SettingsSchema),
  AuditLog: mongoose.model('AuditLog', AuditLogSchema),
  Promotion: mongoose.model('Promotion', PromotionSchema),
  SpecialCard: mongoose.model('SpecialCard', SpecialCardSchema),
  CmsSection: mongoose.model('CmsSection', CmsSectionSchema),
  CustomSection: mongoose.model('CustomSection', CustomSectionSchema),
  PaymentLedger: mongoose.model('PaymentLedger', PaymentLedgerSchema),
  Settlement: mongoose.model('Settlement', SettlementSchema),
  PaymentAuditLog: mongoose.model('PaymentAuditLog', PaymentAuditLogSchema),
  AdminUser: mongoose.model('AdminUser', AdminUserSchema),
  HelpdeskTicket: mongoose.model('HelpdeskTicket', HelpdeskTicketSchema),
  TicketMessage: mongoose.model('TicketMessage', TicketMessageSchema),
  KnowledgeBase: mongoose.model('KnowledgeBase', KnowledgeBaseSchema),
  HelpdeskAnalytics: mongoose.model('HelpdeskAnalytics', HelpdeskAnalyticsSchema)
};

const LocalModels = {
  User: createMockModel('User', 'users'),
  Shop: createMockModel('Shop', 'shops'),
  Booking: createMockModel('Booking', 'bookings'),
  Category: createMockModel('Category', 'categories'),
  Subcategory: createMockModel('Subcategory', 'subcategories'),
  CatalogService: createMockModel('CatalogService', 'catalogservices'),
  Review: createMockModel('Review', 'reviews'),
  Professional: createMockModel('Professional', 'professionals'),
  Banner: createMockModel('Banner', 'banners'),
  Offer: createMockModel('Offer', 'offers'),
  Notification: createMockModel('Notification', 'notifications'),
  Demand: createMockModel('Demand', 'demands'),
  Settings: createMockModel('Settings', 'settings'),
  AuditLog: createMockModel('AuditLog', 'auditlogs'),
  Promotion: createMockModel('Promotion', 'promotions'),
  SpecialCard: createMockModel('SpecialCard', 'specialcards'),
  CmsSection: createMockModel('CmsSection', 'cmssections'),
  CustomSection: createMockModel('CustomSection', 'customsections'),
  PaymentLedger: createMockModel('PaymentLedger', 'paymentledgers'),
  Settlement: createMockModel('Settlement', 'settlements'),
  PaymentAuditLog: createMockModel('PaymentAuditLog', 'paymentauditlogs'),
  AdminUser: createMockModel('AdminUser', 'adminusers'),
  HelpdeskTicket: createMockModel('HelpdeskTicket', 'helpdesktickets'),
  TicketMessage: createMockModel('TicketMessage', 'ticketmessages'),
  KnowledgeBase: createMockModel('KnowledgeBase', 'knowledgebases'),
  HelpdeskAnalytics: createMockModel('HelpdeskAnalytics', 'helpdeskanalytics')
};

function makeModelProxy(modelName) {
  const ProxyClass = function(data) {
    if (useLocalDb) {
      return new LocalModels[modelName](data);
    } else {
      return new MongooseModels[modelName](data);
    }
  };

  const staticMethods = [
    'find', 'findOne', 'findById', 'countDocuments', 'create', 'insertMany',
    'findOneAndUpdate', 'findByIdAndUpdate', 'findOneAndDelete', 'findByIdAndDelete',
    'aggregate', 'deleteOne', 'deleteMany', 'updateOne', 'updateMany'
  ];

  for (const method of staticMethods) {
    ProxyClass[method] = function(...args) {
      if (useLocalDb) {
        return LocalModels[modelName][method](...args);
      } else {
        return MongooseModels[modelName][method](...args);
      }
    };
  }

  return ProxyClass;
}

module.exports = {
  setUseLocalDb,
  User: makeModelProxy('User'),
  Shop: makeModelProxy('Shop'),
  Booking: makeModelProxy('Booking'),
  Category: makeModelProxy('Category'),
  Subcategory: makeModelProxy('Subcategory'),
  CatalogService: makeModelProxy('CatalogService'),
  Review: makeModelProxy('Review'),
  Professional: makeModelProxy('Professional'),
  Banner: makeModelProxy('Banner'),
  Offer: makeModelProxy('Offer'),
  Notification: makeModelProxy('Notification'),
  Demand: makeModelProxy('Demand'),
  Settings: makeModelProxy('Settings'),
  AuditLog: makeModelProxy('AuditLog'),
  Promotion: makeModelProxy('Promotion'),
  SpecialCard: makeModelProxy('SpecialCard'),
  CmsSection: makeModelProxy('CmsSection'),
  CustomSection: makeModelProxy('CustomSection'),
  PaymentLedger: makeModelProxy('PaymentLedger'),
  Settlement: makeModelProxy('Settlement'),
  PaymentAuditLog: makeModelProxy('PaymentAuditLog'),
  AdminUser: makeModelProxy('AdminUser'),
  HelpdeskTicket: makeModelProxy('HelpdeskTicket'),
  TicketMessage: makeModelProxy('TicketMessage'),
  KnowledgeBase: makeModelProxy('KnowledgeBase'),
  HelpdeskAnalytics: makeModelProxy('HelpdeskAnalytics')
};
