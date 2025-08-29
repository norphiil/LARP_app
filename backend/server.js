const express = require('express');
const cors = require('cors');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const sqlite3 = require('sqlite3').verbose();
const bodyParser = require('body-parser');
const helmet = require('helmet');
const rateLimit = require('express-rate-limit');
const validator = require('validator');
const { v4: uuidv4 } = require('uuid');
const path = require('path');

const app = express();
const PORT = process.env.PORT || 3000;
const HOST = process.env.HOST || 'localhost';
const JWT_SECRET = process.env.JWT_SECRET || 'your-super-secret-jwt-key-change-in-production';

// Database setup
const dbPath = path.join(__dirname, 'database.db');
const db = new sqlite3.Database(dbPath);

// Middleware
app.use(helmet());
app.use(cors());
app.use(bodyParser.json());
app.use(bodyParser.urlencoded({ extended: true }));

// Rate limiting
const limiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 100, // limit each IP to 100 requests per windowMs
  message: 'Too many requests from this IP, please try again later.'
});
app.use('/api/', limiter);

// Auth middleware
const authenticateToken = (req, res, next) => {
  const authHeader = req.headers['authorization'];
  const token = authHeader && authHeader.split(' ')[1];

  if (!token) {
    return res.status(401).json({ error: 'Access token required' });
  }

  jwt.verify(token, JWT_SECRET, (err, user) => {
    if (err) {
      return res.status(403).json({ error: 'Invalid token' });
    }
    req.user = user;
    next();
  });
};

// Role-based authorization middleware
const authorizeRole = (roles) => {
  return (req, res, next) => {
    if (!roles.includes(req.user.role)) {
      return res.status(403).json({ error: 'Insufficient permissions' });
    }
    next();
  };
};

// Initialize database
const initDatabase = () => {
  // Users table
  db.serialize(() => {
    db.run(`
      CREATE TABLE IF NOT EXISTS users (
        id TEXT PRIMARY KEY,
        username TEXT UNIQUE NOT NULL,
        email TEXT UNIQUE NOT NULL,
        password TEXT NOT NULL,
        role TEXT NOT NULL DEFAULT 'user',
        firstName TEXT,
        lastName TEXT,
        phoneNumber TEXT,
        department TEXT,
        position TEXT,
        profilePicture TEXT,
        isActive BOOLEAN DEFAULT 1,
        qrCodeData TEXT,
        createdAt DATETIME DEFAULT CURRENT_TIMESTAMP,
        updatedAt DATETIME DEFAULT CURRENT_TIMESTAMP,
        lastLogin DATETIME,
        createdBy TEXT
      )
    `);

    // Roles table
    db.run(`
      CREATE TABLE IF NOT EXISTS roles (
        id TEXT PRIMARY KEY,
        name TEXT UNIQUE NOT NULL,
        description TEXT,
        permissions TEXT, -- JSON string of permissions
        createdAt DATETIME DEFAULT CURRENT_TIMESTAMP
      )
    `);

    // User modifications table for offline sync
    db.run(`
      CREATE TABLE IF NOT EXISTS user_modifications (
        id TEXT PRIMARY KEY,
        userId TEXT NOT NULL,
        modifiedBy TEXT NOT NULL,
        modifications TEXT, -- JSON string of changes
        synced BOOLEAN DEFAULT 0,
        createdAt DATETIME DEFAULT CURRENT_TIMESTAMP,
        syncedAt DATETIME,
        FOREIGN KEY (userId) REFERENCES users (id),
        FOREIGN KEY (modifiedBy) REFERENCES users (id)
      )
    `);

    // Insert default roles
    const defaultRoles = [
      { id: uuidv4(), name: 'admin', description: 'Administrator with full access', permissions: JSON.stringify(['create_user', 'edit_user', 'delete_user', 'manage_roles', 'scan_qr']) },
      { id: uuidv4(), name: 'manager', description: 'Manager with user management access', permissions: JSON.stringify(['create_user', 'edit_user', 'scan_qr']) },
      { id: uuidv4(), name: 'scanner', description: 'Can only scan QR codes and view user info', permissions: JSON.stringify(['scan_qr']) },
      { id: uuidv4(), name: 'user', description: 'Regular user with basic access', permissions: JSON.stringify(['view_profile']) }
    ];

    defaultRoles.forEach(role => {
      db.run(
        'INSERT OR IGNORE INTO roles (id, name, description, permissions) VALUES (?, ?, ?, ?)',
        [role.id, role.name, role.description, role.permissions]
      );
    });

    // Create default admin user
    const adminId = uuidv4();
    const hashedPassword = bcrypt.hashSync('admin123', 10);
    
    db.run(`
      INSERT OR IGNORE INTO users (
        id, username, email, password, role, firstName, lastName, 
        qrCodeData, isActive, createdAt
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    `, [
      adminId, 'admin', 'admin@example.com', hashedPassword, 'admin',
      'System', 'Administrator', adminId, 1, new Date().toISOString()
    ]);

    console.log('Database initialized successfully');
  });
};

// Routes

// Health check
app.get('/api/health', (req, res) => {
  res.json({ status: 'OK', timestamp: new Date().toISOString() });
});

// Auth routes
app.post('/api/auth/login', (req, res) => {
  const { username, password } = req.body;

  if (!username || !password) {
    return res.status(400).json({ error: 'Username and password are required' });
  }

  db.get(
    'SELECT * FROM users WHERE (username = ? OR email = ?) AND isActive = 1',
    [username, username],
    (err, user) => {
      if (err) {
        return res.status(500).json({ error: 'Database error' });
      }

      if (!user || !bcrypt.compareSync(password, user.password)) {
        return res.status(401).json({ error: 'Invalid credentials' });
      }

      // Update last login
      db.run(
        'UPDATE users SET lastLogin = ? WHERE id = ?',
        [new Date().toISOString(), user.id]
      );

      const token = jwt.sign(
        { 
          id: user.id, 
          username: user.username, 
          role: user.role,
          email: user.email 
        },
        JWT_SECRET,
        { expiresIn: '24h' }
      );

      // Remove password from response
      const { password: _, ...userWithoutPassword } = user;

      res.json({
        token,
        user: userWithoutPassword,
        message: 'Login successful'
      });
    }
  );
});

// Get current user profile
app.get('/api/auth/profile', authenticateToken, (req, res) => {
  db.get(
    'SELECT id, username, email, role, firstName, lastName, phoneNumber, department, position, profilePicture, qrCodeData, createdAt, lastLogin FROM users WHERE id = ?',
    [req.user.id],
    (err, user) => {
      if (err) {
        return res.status(500).json({ error: 'Database error' });
      }

      if (!user) {
        return res.status(404).json({ error: 'User not found' });
      }

      res.json(user);
    }
  );
});

// User management routes
app.get('/api/users', authenticateToken, authorizeRole(['admin', 'manager']), (req, res) => {
  const { page = 1, limit = 20, search = '', role = '' } = req.query;
  const offset = (page - 1) * limit;

  let query = `
    SELECT id, username, email, role, firstName, lastName, phoneNumber, 
           department, position, isActive, createdAt, lastLogin 
    FROM users 
    WHERE 1=1
  `;
  const params = [];

  if (search) {
    query += ` AND (username LIKE ? OR email LIKE ? OR firstName LIKE ? OR lastName LIKE ?)`;
    params.push(`%${search}%`, `%${search}%`, `%${search}%`, `%${search}%`);
  }

  if (role) {
    query += ` AND role = ?`;
    params.push(role);
  }

  query += ` ORDER BY createdAt DESC LIMIT ? OFFSET ?`;
  params.push(parseInt(limit), parseInt(offset));

  db.all(query, params, (err, users) => {
    if (err) {
      return res.status(500).json({ error: 'Database error' });
    }

    // Get total count
    let countQuery = 'SELECT COUNT(*) as total FROM users WHERE 1=1';
    const countParams = [];

    if (search) {
      countQuery += ` AND (username LIKE ? OR email LIKE ? OR firstName LIKE ? OR lastName LIKE ?)`;
      countParams.push(`%${search}%`, `%${search}%`, `%${search}%`, `%${search}%`);
    }

    if (role) {
      countQuery += ` AND role = ?`;
      countParams.push(role);
    }

    db.get(countQuery, countParams, (err, result) => {
      if (err) {
        return res.status(500).json({ error: 'Database error' });
      }

      res.json({
        users,
        total: result.total,
        page: parseInt(page),
        limit: parseInt(limit)
      });
    });
  });
});

// Get user by ID or QR code
app.get('/api/users/:identifier', authenticateToken, (req, res) => {
  const { identifier } = req.params;
  
  // Check if user has permission to view other users
  if (req.user.id !== identifier && !['admin', 'manager', 'scanner'].includes(req.user.role)) {
    return res.status(403).json({ error: 'Insufficient permissions' });
  }

  db.get(
    `SELECT id, username, email, role, firstName, lastName, phoneNumber, 
            department, position, profilePicture, qrCodeData, isActive, 
            createdAt, lastLogin 
     FROM users 
     WHERE id = ? OR qrCodeData = ?`,
    [identifier, identifier],
    (err, user) => {
      if (err) {
        return res.status(500).json({ error: 'Database error' });
      }

      if (!user) {
        return res.status(404).json({ error: 'User not found' });
      }

      res.json(user);
    }
  );
});

// Create new user
app.post('/api/users', authenticateToken, authorizeRole(['admin', 'manager']), (req, res) => {
  const {
    username, email, password, role, firstName, lastName,
    phoneNumber, department, position
  } = req.body;

  // Validation
  if (!username || !email || !password || !role) {
    return res.status(400).json({ error: 'Missing required fields' });
  }

  if (!validator.isEmail(email)) {
    return res.status(400).json({ error: 'Invalid email format' });
  }

  if (password.length < 6) {
    return res.status(400).json({ error: 'Password must be at least 6 characters' });
  }

  const userId = uuidv4();
  const hashedPassword = bcrypt.hashSync(password, 10);

  db.run(`
    INSERT INTO users (
      id, username, email, password, role, firstName, lastName,
      phoneNumber, department, position, qrCodeData, isActive,
      createdAt, createdBy
    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
  `, [
    userId, username, email, hashedPassword, role, firstName, lastName,
    phoneNumber, department, position, userId, 1,
    new Date().toISOString(), req.user.id
  ], function(err) {
    if (err) {
      if (err.message.includes('UNIQUE constraint failed')) {
        return res.status(409).json({ error: 'Username or email already exists' });
      }
      return res.status(500).json({ error: 'Database error' });
    }

    res.status(201).json({
      message: 'User created successfully',
      userId: userId
    });
  });
});

// Update user
app.put('/api/users/:id', authenticateToken, (req, res) => {
  const { id } = req.params;
  const updates = req.body;

  // Check permissions
  if (req.user.id !== id && !['admin', 'manager'].includes(req.user.role)) {
    return res.status(403).json({ error: 'Insufficient permissions' });
  }

  // Don't allow regular users to change role
  if (req.user.id === id && req.user.role === 'user' && updates.role) {
    delete updates.role;
  }

  const allowedFields = [
    'firstName', 'lastName', 'phoneNumber', 'department', 
    'position', 'email'
  ];

  if (['admin', 'manager'].includes(req.user.role)) {
    allowedFields.push('role', 'isActive');
  }

  const updateFields = [];
  const params = [];

  for (const [key, value] of Object.entries(updates)) {
    if (allowedFields.includes(key) && value !== undefined) {
      updateFields.push(`${key} = ?`);
      params.push(value);
    }
  }

  if (updateFields.length === 0) {
    return res.status(400).json({ error: 'No valid fields to update' });
  }

  updateFields.push('updatedAt = ?');
  params.push(new Date().toISOString());
  params.push(id);

  // Record modification for offline sync
  const modificationId = uuidv4();
  const modificationData = {
    fields: updateFields.slice(0, -1), // Remove updatedAt
    timestamp: new Date().toISOString()
  };

  db.serialize(() => {
    db.run(`
      UPDATE users SET ${updateFields.join(', ')} WHERE id = ?
    `, params, function(err) {
      if (err) {
        return res.status(500).json({ error: 'Database error' });
      }

      if (this.changes === 0) {
        return res.status(404).json({ error: 'User not found' });
      }

      // Record modification
      db.run(`
        INSERT INTO user_modifications (id, userId, modifiedBy, modifications, synced, createdAt)
        VALUES (?, ?, ?, ?, ?, ?)
      `, [
        modificationId, id, req.user.id, JSON.stringify(modificationData),
        1, new Date().toISOString() // Mark as synced since we're the server
      ]);

      res.json({ message: 'User updated successfully' });
    });
  });
});

// Delete user
app.delete('/api/users/:id', authenticateToken, authorizeRole(['admin']), (req, res) => {
  const { id } = req.params;

  if (req.user.id === id) {
    return res.status(400).json({ error: 'Cannot delete your own account' });
  }

  db.run('DELETE FROM users WHERE id = ?', [id], function(err) {
    if (err) {
      return res.status(500).json({ error: 'Database error' });
    }

    if (this.changes === 0) {
      return res.status(404).json({ error: 'User not found' });
    }

    res.json({ message: 'User deleted successfully' });
  });
});

// Get roles
app.get('/api/roles', authenticateToken, authorizeRole(['admin', 'manager']), (req, res) => {
  db.all('SELECT * FROM roles ORDER BY name', (err, roles) => {
    if (err) {
      return res.status(500).json({ error: 'Database error' });
    }

    res.json(roles.map(role => ({
      ...role,
      permissions: JSON.parse(role.permissions)
    })));
  });
});

// Get unsynced modifications (for offline sync)
app.get('/api/sync/modifications', authenticateToken, authorizeRole(['admin', 'manager']), (req, res) => {
  db.all(`
    SELECT um.*, u.username as modifiedByUsername
    FROM user_modifications um
    JOIN users u ON um.modifiedBy = u.id
    WHERE um.synced = 0
    ORDER BY um.createdAt ASC
  `, (err, modifications) => {
    if (err) {
      return res.status(500).json({ error: 'Database error' });
    }

    res.json(modifications.map(mod => ({
      ...mod,
      modifications: JSON.parse(mod.modifications)
    })));
  });
});

// Mark modifications as synced
app.post('/api/sync/modifications/:id/sync', authenticateToken, authorizeRole(['admin', 'manager']), (req, res) => {
  const { id } = req.params;

  db.run(
    'UPDATE user_modifications SET synced = 1, syncedAt = ? WHERE id = ?',
    [new Date().toISOString(), id],
    function(err) {
      if (err) {
        return res.status(500).json({ error: 'Database error' });
      }

      if (this.changes === 0) {
        return res.status(404).json({ error: 'Modification not found' });
      }

      res.json({ message: 'Modification marked as synced' });
    }
  );
});

// Health check endpoint
app.get('/health', (req, res) => {
  res.status(200).json({ 
    status: 'healthy', 
    timestamp: new Date().toISOString(),
    uptime: process.uptime()
  });
});

// Initialize database and start server
initDatabase();

app.listen(PORT, HOST, () => {
  console.log(`Server is running on http://${HOST}:${PORT}`);
  console.log(`API endpoints available at http://${HOST}:${PORT}/api`);
  console.log('Default admin credentials: username: admin, password: admin123');
});

module.exports = app;
