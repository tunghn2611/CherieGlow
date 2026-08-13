// server.js — Express entry point for MenstrualCycle Backend
// Production-ready: auto-init schema, health check, graceful shutdown
require('dotenv').config();

const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const morgan = require('morgan');
const fs = require('fs');
const path = require('path');
const { generalLimiter } = require('./middleware/rateLimiter');
const pool = require('./config/database');

const app = express();
const PORT = process.env.PORT || 3000;
const IS_PRODUCTION = process.env.NODE_ENV === 'production';

// ── Global Middleware ───────────────────────────────────────
app.use(helmet());
app.use(cors({ origin: '*', methods: ['GET', 'POST', 'PUT', 'DELETE'] }));
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true }));
app.use(morgan(IS_PRODUCTION ? 'combined' : 'dev'));
app.use(generalLimiter);

// ── Routes ──────────────────────────────────────────────────
app.use('/api/auth', require('./routes/auth.routes'));
app.use('/api/cycles', require('./routes/cycle.routes'));
app.use('/api/nutrition', require('./routes/nutrition.routes'));

// ── Health Check ────────────────────────────────────────────
app.get('/api/health', async (req, res) => {
  try {
    await pool.execute('SELECT 1');
    res.json({
      success: true,
      message: 'Server is running',
      database: 'connected',
      environment: process.env.NODE_ENV || 'development',
      timestamp: new Date().toISOString()
    });
  } catch (err) {
    res.status(500).json({ success: false, message: 'Database connection failed' });
  }
});

// ── 404 Handler ─────────────────────────────────────────────
app.use((req, res) => {
  res.status(404).json({ success: false, message: `Route ${req.method} ${req.path} not found` });
});

// ── Error Handler ───────────────────────────────────────────
app.use((err, req, res, next) => {
  console.error('❌ [SERVER ERROR]', err.stack);
  res.status(500).json({ success: false, message: 'Internal server error' });
});

// ── Auto-Init Database Schema ───────────────────────────────
async function initDatabase() {
  try {
    // Kiểm tra bảng users đã tồn tại chưa
    const [rows] = await pool.execute(
      "SELECT COUNT(*) as cnt FROM information_schema.tables WHERE table_schema = DATABASE() AND table_name = 'users'"
    );
    
    if (rows[0].cnt === 0) {
      console.log('🔧 [DB] First run detected — initializing database schema...');
      
      // Đọc và chạy schema.sql
      const schemaPath = path.join(__dirname, 'database', 'schema.sql');
      if (fs.existsSync(schemaPath)) {
        const schema = fs.readFileSync(schemaPath, 'utf8');
        // Tách các câu lệnh SQL (bỏ qua CREATE DATABASE và USE vì Railway tự quản lý)
        const statements = schema
          .split(';')
          .map(s => s.trim())
          .filter(s => s.length > 0)
          .filter(s => !s.toUpperCase().startsWith('CREATE DATABASE'))
          .filter(s => !s.toUpperCase().startsWith('USE '));
        
        for (const stmt of statements) {
          try {
            await pool.execute(stmt);
          } catch (stmtErr) {
            // Bỏ qua lỗi "table already exists"
            if (!stmtErr.message.includes('already exists')) {
              console.warn('⚠️ [DB] Schema statement warning:', stmtErr.message.substring(0, 100));
            }
          }
        }
        console.log('✅ [DB] Database schema initialized successfully!');
      } else {
        console.warn('⚠️ [DB] schema.sql not found at', schemaPath);
      }
      
      // Chạy nutrition schema nếu có
      const nutritionSchemaPath = path.join(__dirname, 'database', 'nutrition_schema.sql');
      if (fs.existsSync(nutritionSchemaPath)) {
        const nutritionSchema = fs.readFileSync(nutritionSchemaPath, 'utf8');
        const stmts = nutritionSchema
          .split(';')
          .map(s => s.trim())
          .filter(s => s.length > 0)
          .filter(s => !s.toUpperCase().startsWith('CREATE DATABASE'))
          .filter(s => !s.toUpperCase().startsWith('USE '));
        
        for (const stmt of stmts) {
          try {
            await pool.execute(stmt);
          } catch (e) {
            if (!e.message.includes('already exists')) {
              console.warn('⚠️ [DB] Nutrition schema warning:', e.message.substring(0, 100));
            }
          }
        }
        console.log('✅ [DB] Nutrition schema initialized!');
      }
    } else {
      console.log('✅ [DB] Database schema already exists');
    }
  } catch (err) {
    console.error('❌ [DB] Schema init error:', err.message);
    // Không crash server — schema có thể đã được tạo thủ công
  }
}

// ── Start Server ────────────────────────────────────────────
async function start() {
  // Khởi tạo DB trước khi listen
  await initDatabase();
  
  app.listen(PORT, '0.0.0.0', () => {
    console.log(`🌸 Chérie Glow Backend running on port ${PORT}`);
    console.log(`📋 Health check: /api/health`);
    console.log(`🔐 Auth API:     /api/auth/`);
    console.log(`🩺 Cycle API:    /api/cycles/`);
    console.log(`🥗 Nutrition:    /api/nutrition/`);
    console.log(`🌐 Environment:  ${process.env.NODE_ENV || 'development'}`);
  });
}

start().catch(err => {
  console.error('❌ Failed to start server:', err);
  process.exit(1);
});

// ── Graceful Shutdown ───────────────────────────────────────
process.on('SIGTERM', async () => {
  console.log('🛑 SIGTERM received — shutting down gracefully...');
  await pool.end();
  process.exit(0);
});

process.on('SIGINT', async () => {
  console.log('🛑 SIGINT received — shutting down...');
  await pool.end();
  process.exit(0);
});

module.exports = app;
