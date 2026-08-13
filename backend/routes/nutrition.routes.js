// routes/nutrition.routes.js — Nutrition API endpoints
const router = require('express').Router();
const authMiddleware = require('../middleware/auth');
const NutritionController = require('../controllers/nutrition.controller');

// Public routes — Food search (no auth needed)
router.get('/foods/categories', NutritionController.getCategories);
router.get('/foods/search',     NutritionController.searchFoods);
router.get('/foods/:id',        NutritionController.getFoodDetail);

// Protected routes — Meal logging (auth required)
router.use('/meals', authMiddleware);
router.post('/meals',            NutritionController.logMeal);
router.get('/meals',             NutritionController.getMeals);
router.get('/meals/summary',     NutritionController.getMealsSummary);
router.put('/meals/:id',         NutritionController.updateMeal);
router.delete('/meals/:id',      NutritionController.deleteMeal);

module.exports = router;
