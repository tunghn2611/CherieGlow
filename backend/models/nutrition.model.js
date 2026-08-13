// models/nutrition.model.js — MySQL queries for foods & nutrition logs
const pool = require('../config/database');
const { generateUUID } = require('../utils/helpers');

const NutritionModel = {
  // ── Food Search & Lookup ──────────────────────────────────
  async searchFoods(query, categoryId, page = 1, limit = 20) {
    let sql = 'SELECT id, code, name_vi, name_en, category_id, image_url, energy_kcal, protein_g, lipid_g, carbohydrate_g, fiber_g FROM foods WHERE 1=1';
    const params = [];

    if (query) {
      sql += ' AND (name_vi LIKE ? OR name_en LIKE ? OR code LIKE ?)';
      const q = `%${query}%`;
      params.push(q, q, q);
    }
    if (categoryId) {
      sql += ' AND category_id = ?';
      params.push(categoryId);
    }
    sql += ' ORDER BY name_vi LIMIT ? OFFSET ?';
    params.push(String(limit), String((page - 1) * limit));

    const [rows] = await pool.execute(sql, params);

    // Count total
    let countSql = 'SELECT COUNT(*) as total FROM foods WHERE 1=1';
    const countParams = [];
    if (query) {
      countSql += ' AND (name_vi LIKE ? OR name_en LIKE ? OR code LIKE ?)';
      const q = `%${query}%`;
      countParams.push(q, q, q);
    }
    if (categoryId) {
      countSql += ' AND category_id = ?';
      countParams.push(categoryId);
    }
    const [countRows] = await pool.execute(countSql, countParams);

    return { foods: rows, total: countRows[0].total, page, limit };
  },

  async getFoodById(id) {
    const [rows] = await pool.execute('SELECT * FROM foods WHERE id = ?', [id]);
    return rows[0] || null;
  },

  async getCategories() {
    const [rows] = await pool.execute('SELECT * FROM food_categories ORDER BY ord');
    return rows;
  },

  // ── Daily Nutrition Logs ──────────────────────────────────
  async logMeal(data) {
    const id = generateUUID();
    // Calculate nutrition based on serving size
    const ratio = (data.servingSize || 100) / 100;
    await pool.execute(
      `INSERT INTO daily_nutrition_logs (id, user_id, log_date, meal_type, food_id, food_name, serving_size_g, calories, protein, fat, carbs, fiber, notes)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      [id, data.userId, data.logDate, data.mealType, data.foodId || null,
       data.foodName, data.servingSize || 100,
       (data.calories || 0) * ratio, (data.protein || 0) * ratio,
       (data.fat || 0) * ratio, (data.carbs || 0) * ratio,
       (data.fiber || 0) * ratio, data.notes || null]
    );
    return id;
  },

  async getMealsByDate(userId, logDate) {
    const [rows] = await pool.execute(
      `SELECT dnl.*, f.image_url, f.name_en as food_name_en
       FROM daily_nutrition_logs dnl
       LEFT JOIN foods f ON dnl.food_id = f.id
       WHERE dnl.user_id = ? AND dnl.log_date = ?
       ORDER BY FIELD(dnl.meal_type, 'breakfast','lunch','dinner','snack'), dnl.created_at`,
      [userId, logDate]
    );
    return rows;
  },

  async getMealsByDateRange(userId, fromDate, toDate) {
    const [rows] = await pool.execute(
      `SELECT log_date, meal_type, SUM(calories) as total_calories,
              SUM(protein) as total_protein, SUM(fat) as total_fat,
              SUM(carbs) as total_carbs, COUNT(*) as meal_count
       FROM daily_nutrition_logs
       WHERE user_id = ? AND log_date >= ? AND log_date <= ?
       GROUP BY log_date, meal_type ORDER BY log_date, FIELD(meal_type, 'breakfast','lunch','dinner','snack')`,
      [userId, fromDate, toDate]
    );
    return rows;
  },

  async getDailySummary(userId, logDate) {
    const [rows] = await pool.execute(
      `SELECT SUM(calories) as total_calories, SUM(protein) as total_protein,
              SUM(fat) as total_fat, SUM(carbs) as total_carbs,
              SUM(fiber) as total_fiber, COUNT(*) as meal_count
       FROM daily_nutrition_logs
       WHERE user_id = ? AND log_date = ?`,
      [userId, logDate]
    );
    return rows[0] || { total_calories: 0, total_protein: 0, total_fat: 0, total_carbs: 0, total_fiber: 0, meal_count: 0 };
  },

  async deleteLog(logId, userId) {
    await pool.execute('DELETE FROM daily_nutrition_logs WHERE id = ? AND user_id = ?', [logId, userId]);
  },

  async updateLog(logId, userId, data) {
    const fields = []; const params = [];
    const mapping = {
      mealType: 'meal_type', foodId: 'food_id', foodName: 'food_name',
      servingSize: 'serving_size_g', calories: 'calories', protein: 'protein',
      fat: 'fat', carbs: 'carbs', fiber: 'fiber', notes: 'notes',
    };
    for (const [key, col] of Object.entries(mapping)) {
      if (data[key] !== undefined) { fields.push(`${col} = ?`); params.push(data[key]); }
    }
    if (fields.length === 0) return;
    params.push(logId, userId);
    await pool.execute(`UPDATE daily_nutrition_logs SET ${fields.join(', ')} WHERE id = ? AND user_id = ?`, params);
  },
};

module.exports = NutritionModel;
