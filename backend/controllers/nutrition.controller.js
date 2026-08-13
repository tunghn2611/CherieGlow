// controllers/nutrition.controller.js — Smart Nutrition business logic
const NutritionModel = require('../models/nutrition.model');
const { formatResponse } = require('../utils/helpers');

const NutritionController = {
  // ── GET /foods/search?q=&category=&page=&limit= ──────────
  async searchFoods(req, res) {
    try {
      const { q, category, page = 1, limit = 20 } = req.query;
      const result = await NutritionModel.searchFoods(q, category, parseInt(page), parseInt(limit));
      res.json(formatResponse(true, 'Foods found', result));
    } catch (err) {
      console.error('❌ [SEARCH-FOODS]', err);
      res.status(500).json(formatResponse(false, 'Internal server error'));
    }
  },

  // ── GET /foods/:id ────────────────────────────────────────
  async getFoodDetail(req, res) {
    try {
      const food = await NutritionModel.getFoodById(req.params.id);
      if (!food) return res.status(404).json(formatResponse(false, 'Food not found'));
      res.json(formatResponse(true, 'Food detail', { food }));
    } catch (err) {
      console.error('❌ [FOOD-DETAIL]', err);
      res.status(500).json(formatResponse(false, 'Internal server error'));
    }
  },

  // ── GET /foods/categories ─────────────────────────────────
  async getCategories(req, res) {
    try {
      const categories = await NutritionModel.getCategories();
      res.json(formatResponse(true, 'Categories loaded', { categories }));
    } catch (err) {
      console.error('❌ [CATEGORIES]', err);
      res.status(500).json(formatResponse(false, 'Internal server error'));
    }
  },

  // ── POST /meals — Log a meal ──────────────────────────────
  async logMeal(req, res) {
    try {
      const userId = req.user.id;
      const { logDate, mealType, foodId, foodName, servingSize, notes } = req.body;

      if (!logDate || !mealType || !foodName) {
        return res.status(400).json(formatResponse(false, 'logDate, mealType, and foodName are required'));
      }

      // If foodId provided, auto-fill nutrition from database
      let calories = 0, protein = 0, fat = 0, carbs = 0, fiber = 0;
      if (foodId) {
        const food = await NutritionModel.getFoodById(foodId);
        if (food) {
          const ratio = (servingSize || 100) / 100;
          calories = food.energy_kcal * ratio;
          protein = food.protein_g * ratio;
          fat = food.lipid_g * ratio;
          carbs = food.carbohydrate_g * ratio;
          fiber = food.fiber_g * ratio;
        }
      } else {
        // Use values from request body (manual entry)
        calories = req.body.calories || 0;
        protein = req.body.protein || 0;
        fat = req.body.fat || 0;
        carbs = req.body.carbs || 0;
        fiber = req.body.fiber || 0;
      }

      const id = await NutritionModel.logMeal({
        userId, logDate, mealType, foodId, foodName,
        servingSize: servingSize || 100,
        calories, protein, fat, carbs, fiber, notes,
      });

      res.status(201).json(formatResponse(true, 'Meal logged', {
        id, calories: Math.round(calories * 10) / 10,
        protein: Math.round(protein * 10) / 10,
        fat: Math.round(fat * 10) / 10,
        carbs: Math.round(carbs * 10) / 10,
      }));
    } catch (err) {
      console.error('❌ [LOG-MEAL]', err);
      res.status(500).json(formatResponse(false, 'Internal server error'));
    }
  },

  // ── GET /meals?date=YYYY-MM-DD ────────────────────────────
  async getMeals(req, res) {
    try {
      const { date } = req.query;
      if (!date) return res.status(400).json(formatResponse(false, 'date parameter required'));
      const meals = await NutritionModel.getMealsByDate(req.user.id, date);
      const summary = await NutritionModel.getDailySummary(req.user.id, date);
      res.json(formatResponse(true, 'Meals loaded', { meals, summary }));
    } catch (err) {
      console.error('❌ [GET-MEALS]', err);
      res.status(500).json(formatResponse(false, 'Internal server error'));
    }
  },

  // ── GET /meals/summary?from=&to= ─────────────────────────
  async getMealsSummary(req, res) {
    try {
      const { from, to } = req.query;
      if (!from || !to) return res.status(400).json(formatResponse(false, 'from and to dates required'));
      const data = await NutritionModel.getMealsByDateRange(req.user.id, from, to);
      res.json(formatResponse(true, 'Summary loaded', { data }));
    } catch (err) {
      console.error('❌ [MEALS-SUMMARY]', err);
      res.status(500).json(formatResponse(false, 'Internal server error'));
    }
  },

  // ── DELETE /meals/:id ─────────────────────────────────────
  async deleteMeal(req, res) {
    try {
      await NutritionModel.deleteLog(req.params.id, req.user.id);
      res.json(formatResponse(true, 'Meal deleted'));
    } catch (err) {
      console.error('❌ [DELETE-MEAL]', err);
      res.status(500).json(formatResponse(false, 'Internal server error'));
    }
  },

  // ── PUT /meals/:id ────────────────────────────────────────
  async updateMeal(req, res) {
    try {
      await NutritionModel.updateLog(req.params.id, req.user.id, req.body);
      res.json(formatResponse(true, 'Meal updated'));
    } catch (err) {
      console.error('❌ [UPDATE-MEAL]', err);
      res.status(500).json(formatResponse(false, 'Internal server error'));
    }
  },
};

module.exports = NutritionController;
