-- ============================================================
-- MenstrualCycle Application — MySQL Database Schema
-- MODULE 1: Authentication + MODULE 2: Menstrual Cycle Tracker
-- ============================================================

-- Create database
CREATE DATABASE IF NOT EXISTS menstrual_cycle_db
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_unicode_ci;

USE menstrual_cycle_db;

-- ============================================================
-- MODULE 1: AUTHENTICATION TABLES
-- ============================================================

-- 1. Users table — Core user accounts
CREATE TABLE IF NOT EXISTS users (
    id              CHAR(36) PRIMARY KEY,
    email           VARCHAR(255) UNIQUE,
    phone           VARCHAR(20) UNIQUE,
    country_code    VARCHAR(5) DEFAULT '+84',
    password_hash   VARCHAR(255),                    -- bcrypt hash (NULL for social login)
    name            VARCHAR(100) NOT NULL DEFAULT '',
    gender          ENUM('Nữ', 'Nam', 'Khác', '') DEFAULT '',
    date_of_birth   DATE,
    avatar_url      VARCHAR(500) DEFAULT '',
    auth_provider   ENUM('phone', 'email', 'apple', 'facebook', 'google') NOT NULL DEFAULT 'email',
    is_verified     BOOLEAN DEFAULT FALSE,
    profile_completed BOOLEAN DEFAULT FALSE,
    created_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_email (email),
    INDEX idx_phone (phone)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 2. OTP Verifications — SMS & Email OTP tracking
CREATE TABLE IF NOT EXISTS otp_verifications (
    id          INT AUTO_INCREMENT PRIMARY KEY,
    user_id     CHAR(36),
    target      VARCHAR(255) NOT NULL,               -- Phone number or email
    otp_code    VARCHAR(6) NOT NULL,
    type        ENUM('sms', 'email') NOT NULL,
    purpose     ENUM('register', 'login', 'reset_password') NOT NULL,
    expires_at  TIMESTAMP NOT NULL,
    is_used     BOOLEAN DEFAULT FALSE,
    attempts    INT DEFAULT 0,                        -- Failed attempt counter (max 5)
    created_at  TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    INDEX idx_target (target),
    INDEX idx_expires (expires_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 3. Social Accounts — Apple, Facebook linked accounts
CREATE TABLE IF NOT EXISTS social_accounts (
    id              INT AUTO_INCREMENT PRIMARY KEY,
    user_id         CHAR(36) NOT NULL,
    provider        ENUM('apple', 'facebook') NOT NULL,
    provider_uid    VARCHAR(255) NOT NULL,
    provider_email  VARCHAR(255),
    provider_name   VARCHAR(255),
    access_token    TEXT,
    created_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    UNIQUE KEY unique_provider (provider, provider_uid)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 4. Password Resets — Email OTP for forgot password
CREATE TABLE IF NOT EXISTS password_resets (
    id          INT AUTO_INCREMENT PRIMARY KEY,
    user_id     CHAR(36) NOT NULL,
    email       VARCHAR(255) NOT NULL,
    otp_code    VARCHAR(6) NOT NULL,
    expires_at  TIMESTAMP NOT NULL,
    is_used     BOOLEAN DEFAULT FALSE,
    created_at  TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    INDEX idx_email (email)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 5. Refresh Tokens — JWT refresh token rotation
CREATE TABLE IF NOT EXISTS refresh_tokens (
    id          INT AUTO_INCREMENT PRIMARY KEY,
    user_id     CHAR(36) NOT NULL,
    token       VARCHAR(500) NOT NULL UNIQUE,
    device_info VARCHAR(255),
    expires_at  TIMESTAMP NOT NULL,
    created_at  TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    INDEX idx_token (token),
    INDEX idx_user (user_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================
-- MODULE 2: MENSTRUAL CYCLE TRACKER TABLES
-- ============================================================

-- 6. User Cycle Profiles — Personalized cycle settings per user
--    One-to-Many: One user can have multiple profiles (self, partner, etc.)
CREATE TABLE IF NOT EXISTS user_cycle_profiles (
    id                  CHAR(36) PRIMARY KEY,
    user_id             CHAR(36) NOT NULL,
    profile_name        VARCHAR(100) DEFAULT 'Bản thân',
    relationship        ENUM('self', 'partner', 'daughter', 'other') DEFAULT 'self',
    avg_cycle_length    INT DEFAULT 28,              -- Average cycle length (days)
    avg_period_duration INT DEFAULT 5,               -- Average period duration (days)
    luteal_phase_length INT DEFAULT 14,              -- WHO standard: 14 days
    last_period_start   DATE,
    is_active           BOOLEAN DEFAULT TRUE,
    created_at          TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at          TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    INDEX idx_user_profile (user_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 7. Menstrual Logs — Historical cycle entries
--    One-to-Many: One cycle profile has many log entries
CREATE TABLE IF NOT EXISTS menstrual_logs (
    id                  CHAR(36) PRIMARY KEY,
    profile_id          CHAR(36) NOT NULL,
    user_id             CHAR(36) NOT NULL,           -- Denormalized for faster queries
    period_start_date   DATE NOT NULL,
    period_end_date     DATE,
    cycle_length        INT,                          -- Actual cycle length (calculated)
    period_duration     INT,                          -- Actual period duration (calculated)
    flow_intensity      ENUM('light', 'medium', 'heavy', 'spotting') DEFAULT 'medium',
    -- Calculated fields (populated by backend algorithm)
    ovulation_date      DATE,                         -- E = cycle_length - luteal_phase
    fertile_window_start DATE,                        -- ovulation_date - 5
    fertile_window_end  DATE,                         -- ovulation_date
    -- Symptoms & Notes
    symptoms            JSON,                         -- ["cramps", "headache", "mood_swings"]
    notes               TEXT,
    created_at          TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at          TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (profile_id) REFERENCES user_cycle_profiles(id) ON DELETE CASCADE,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    INDEX idx_profile_date (profile_id, period_start_date),
    INDEX idx_user_date (user_id, period_start_date)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 8. Daily Cycle Data — Per-day tracking (optional fine-grained tracking)
CREATE TABLE IF NOT EXISTS daily_cycle_data (
    id              CHAR(36) PRIMARY KEY,
    log_id          CHAR(36) NOT NULL,
    user_id         CHAR(36) NOT NULL,
    date            DATE NOT NULL,
    day_of_cycle    INT,                              -- Day 1 = first day of period
    phase           ENUM('menstrual', 'follicular', 'ovulation', 'luteal') NOT NULL,
    fertility_level ENUM('none', 'low', 'medium', 'high', 'peak') DEFAULT 'none',
    -- Probability of conception (%) based on WHO/Wilcox et al.
    conception_probability DECIMAL(5,2) DEFAULT 0.00,
    temperature     DECIMAL(4,2),                     -- BBT (Basal Body Temperature)
    cervical_mucus  ENUM('dry', 'sticky', 'creamy', 'watery', 'eggwhite'),
    symptoms        JSON,
    mood            ENUM('happy', 'sad', 'anxious', 'irritable', 'calm', 'energetic'),
    notes           TEXT,
    created_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (log_id) REFERENCES menstrual_logs(id) ON DELETE CASCADE,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    UNIQUE KEY unique_user_date (user_id, date),
    INDEX idx_log_date (log_id, date)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
