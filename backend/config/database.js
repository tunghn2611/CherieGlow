// config/database.js — MySQL2 connection pool
// Hỗ trợ cả local MySQL và cloud (TiDB Cloud, Railway, Aiven)
const mysql = require('mysql2/promise');

const IS_PRODUCTION = process.env.NODE_ENV === 'production';

const poolConfig = {
  host: process.env.DB_HOST || 'localhost',
  port: parseInt(process.env.DB_PORT || '3306'),
  user: process.env.DB_USER || 'root',
  password: process.env.DB_PASSWORD || '',
  database: process.env.DB_NAME || 'menstrual_cycle_db',
  waitForConnections: true,
  connectionLimit: IS_PRODUCTION ? 5 : 10, // Cloud free tier giới hạn connections
  queueLimit: 0,
  charset: 'utf8mb4',
  timezone: '+07:00',
  connectTimeout: 30000, // 30s timeout cho cloud cold start
};

// TiDB Cloud & các cloud MySQL service yêu cầu SSL
if (IS_PRODUCTION) {
  poolConfig.ssl = {
    minVersion: 'TLSv1.2',
    rejectUnauthorized: true,
  };
}

const pool = mysql.createPool(poolConfig);

module.exports = pool;
