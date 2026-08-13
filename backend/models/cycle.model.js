// models/cycle.model.js — MySQL queries for cycle profiles, logs, daily data
const pool = require('../config/database');
const { generateUUID } = require('../utils/helpers');

const CycleModel = {
  // ── Profile CRUD ──────────────────────────────────────────
  async createProfile(userId, { id, profileName, relationship, avgCycleLength, avgPeriodDuration, lutealPhaseLength, lastPeriodStart }) {
    const profileId = id || generateUUID();
    await pool.execute(
      `INSERT INTO user_cycle_profiles (id, user_id, profile_name, relationship, avg_cycle_length, avg_period_duration, luteal_phase_length, last_period_start)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
      [profileId, userId, profileName || 'Bản thân', relationship || 'self',
       avgCycleLength || 28, avgPeriodDuration || 5, lutealPhaseLength || 14, lastPeriodStart || null]
    );
    return profileId;
  },

  async findProfilesByUser(userId) {
    const [rows] = await pool.execute(
      'SELECT * FROM user_cycle_profiles WHERE user_id = ? AND is_active = TRUE ORDER BY created_at', [userId]
    );
    return rows;
  },

  async findProfileById(profileId, userId) {
    const [rows] = await pool.execute(
      'SELECT * FROM user_cycle_profiles WHERE id = ? AND user_id = ?', [profileId, userId]
    );
    return rows[0] || null;
  },

  async updateProfile(profileId, userId, data) {
    const fields = []; const params = [];
    for (const [key, val] of Object.entries(data)) {
      if (val !== undefined) {
        const col = key.replace(/([A-Z])/g, '_$1').toLowerCase();
        fields.push(`${col} = ?`); params.push(val);
      }
    }
    if (fields.length === 0) return;
    params.push(profileId, userId);
    await pool.execute(`UPDATE user_cycle_profiles SET ${fields.join(', ')} WHERE id = ? AND user_id = ?`, params);
  },

  // ── Log CRUD ──────────────────────────────────────────────
  async createLog(data) {
    const id = generateUUID();
    await pool.execute(
      `INSERT INTO menstrual_logs (id, profile_id, user_id, period_start_date, period_end_date, cycle_length, period_duration, flow_intensity, ovulation_date, fertile_window_start, fertile_window_end, symptoms, notes)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      [id, data.profileId, data.userId, data.periodStartDate, data.periodEndDate || null,
       data.cycleLength || null, data.periodDuration || null, data.flowIntensity || 'medium',
       data.ovulationDate || null, data.fertileWindowStart || null, data.fertileWindowEnd || null,
       JSON.stringify(data.symptoms || []), data.notes || null]
    );
    return id;
  },

  async findLogsByProfile(profileId, userId, limit = 20, offset = 0) {
    const [rows] = await pool.execute(
      'SELECT * FROM menstrual_logs WHERE profile_id = ? AND user_id = ? ORDER BY period_start_date DESC LIMIT ? OFFSET ?',
      [profileId, userId, String(limit), String(offset)]
    );
    return rows;
  },

  async findLogsByUser(userId, limit = 50, offset = 0) {
    const [rows] = await pool.execute(
      'SELECT * FROM menstrual_logs WHERE user_id = ? ORDER BY period_start_date DESC LIMIT ? OFFSET ?',
      [userId, String(limit), String(offset)]
    );
    return rows;
  },

  async findLatestLog(profileId, userId) {
    const [rows] = await pool.execute(
      'SELECT * FROM menstrual_logs WHERE profile_id = ? AND user_id = ? ORDER BY period_start_date DESC LIMIT 1',
      [profileId, userId]
    );
    return rows[0] || null;
  },

  async findLogById(logId, userId) {
    const [rows] = await pool.execute(
      'SELECT * FROM menstrual_logs WHERE id = ? AND user_id = ?', [logId, userId]
    );
    return rows[0] || null;
  },

  async updateLog(logId, userId, data) {
    const fields = []; const params = [];
    const mapping = {
      periodStartDate: 'period_start_date', periodEndDate: 'period_end_date',
      cycleLength: 'cycle_length', periodDuration: 'period_duration',
      flowIntensity: 'flow_intensity', ovulationDate: 'ovulation_date',
      fertileWindowStart: 'fertile_window_start', fertileWindowEnd: 'fertile_window_end',
      symptoms: 'symptoms', notes: 'notes',
    };
    for (const [key, col] of Object.entries(mapping)) {
      if (data[key] !== undefined) {
        fields.push(`${col} = ?`);
        params.push(key === 'symptoms' ? JSON.stringify(data[key]) : data[key]);
      }
    }
    if (fields.length === 0) return;
    params.push(logId, userId);
    await pool.execute(`UPDATE menstrual_logs SET ${fields.join(', ')} WHERE id = ? AND user_id = ?`, params);
  },

  async deleteLog(logId, userId) {
    await pool.execute('DELETE FROM menstrual_logs WHERE id = ? AND user_id = ?', [logId, userId]);
  },

  // ── Daily Cycle Data ──────────────────────────────────────
  async upsertDailyData(data) {
    const id = data.id || generateUUID();
    await pool.execute(
      `INSERT INTO daily_cycle_data (id, log_id, user_id, date, day_of_cycle, phase, fertility_level, conception_probability, temperature, cervical_mucus, symptoms, mood, notes)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
       ON DUPLICATE KEY UPDATE day_of_cycle=VALUES(day_of_cycle), phase=VALUES(phase), fertility_level=VALUES(fertility_level), conception_probability=VALUES(conception_probability)`,
      [id, data.logId, data.userId, data.date, data.dayOfCycle, data.phase,
       data.fertilityLevel, data.conceptionProbability || 0, data.temperature || null,
       data.cervicalMucus || null, JSON.stringify(data.symptoms || []), data.mood || null, data.notes || null]
    );
  },

  async findDailyByDateRange(userId, fromDate, toDate) {
    const [rows] = await pool.execute(
      'SELECT * FROM daily_cycle_data WHERE user_id = ? AND date >= ? AND date <= ? ORDER BY date',
      [userId, fromDate, toDate]
    );
    return rows;
  },

  async deleteProfile(profileId, userId) {
    await pool.execute('DELETE FROM user_cycle_profiles WHERE id = ? AND user_id = ?', [profileId, userId]);
  },
};

module.exports = CycleModel;
