// routes/cycle.routes.js — Cycle tracker API endpoints
const router = require('express').Router();
const authMiddleware = require('../middleware/auth');
const CycleController = require('../controllers/cycle.controller');

// All routes require authentication
router.use(authMiddleware);

router.post('/profiles',       CycleController.createProfile);
router.put('/profiles/:id',    CycleController.updateProfile);
router.delete('/profiles/:id', CycleController.deleteProfile);
router.get('/profiles',        CycleController.getProfiles);
router.post('/logs',           CycleController.logPeriod);
router.get('/logs',            CycleController.getHistory);
router.get('/dashboard',       CycleController.getDashboard);
router.put('/logs/:id',        CycleController.updateLog);
router.delete('/logs/:id',     CycleController.deleteLog);
router.get('/daily',           CycleController.getDailyData);

module.exports = router;
