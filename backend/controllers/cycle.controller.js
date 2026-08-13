// controllers/cycle.controller.js — Menstrual cycle business logic
const CycleModel = require('../models/cycle.model');
const calc = require('../services/cycle.calculator');
const { formatResponse, generateUUID, toDateString } = require('../utils/helpers');

const CycleController = {

  // ── POST /profiles ────────────────────────────────────────
  async createProfile(req, res) {
    try {
      const { id, profileName, relationship, avgCycleLength, avgPeriodDuration, lutealPhaseLength, lastPeriodStart } = req.body;
      const newId = await CycleModel.createProfile(req.user.id, {
        id, profileName, relationship, avgCycleLength, avgPeriodDuration, lutealPhaseLength, lastPeriodStart,
      });
      res.status(201).json(formatResponse(true, 'Cycle profile created', { id: newId }));
    } catch (err) {
      console.error('❌ [CREATE-PROFILE]', err);
      res.status(500).json(formatResponse(false, 'Internal server error'));
    }
  },

  // ── PUT /profiles/:id ──────────────────────────────────────
  async updateProfile(req, res) {
    try {
      const profile = await CycleModel.findProfileById(req.params.id, req.user.id);
      if (!profile) return res.status(404).json(formatResponse(false, 'Profile not found'));
      await CycleModel.updateProfile(req.params.id, req.user.id, req.body);
      res.json(formatResponse(true, 'Profile updated'));
    } catch (err) {
      console.error('❌ [UPDATE-PROFILE]', err);
      res.status(500).json(formatResponse(false, 'Internal server error'));
    }
  },

  // ── GET /profiles ─────────────────────────────────────────
  async getProfiles(req, res) {
    try {
      const profiles = await CycleModel.findProfilesByUser(req.user.id);
      res.json(formatResponse(true, 'Profiles loaded', { profiles }));
    } catch (err) {
      console.error('❌ [GET-PROFILES]', err);
      res.status(500).json(formatResponse(false, 'Internal server error'));
    }
  },

  // ── POST /logs — Log a new period entry ───────────────────
  async logPeriod(req, res) {
    try {
      const userId = req.user.id;
      const { id, profileId, periodStartDate, periodEndDate, flowIntensity, symptoms, notes } = req.body;

      // Validate profile belongs to user
      const profile = await CycleModel.findProfileById(profileId, userId);
      if (!profile) return res.status(404).json(formatResponse(false, 'Cycle profile not found'));

      // Calculate period duration
      let periodDuration = profile.avg_period_duration;
      if (periodEndDate) {
        periodDuration = calc.daysBetween(periodStartDate, periodEndDate) + 1;
      }

      // Calculate cycle length from previous log
      let cycleLength = profile.avg_cycle_length;
      const prevLog = await CycleModel.findLatestLog(profileId, userId);
      if (prevLog && prevLog.period_start_date) {
        const prevStart = calc.toDateStr(new Date(prevLog.period_start_date));
        cycleLength = calc.daysBetween(prevStart, periodStartDate);
        if (cycleLength < 15 || cycleLength > 60) cycleLength = profile.avg_cycle_length;
      }

      // Medical calculations (WHO/ACOG)
      const ovulationDay = calc.calculateOvulationDay(cycleLength, profile.luteal_phase_length || 14);
      const fertileWindow = calc.calculateFertileWindow(ovulationDay);
      const ovulationDate = calc.toDateStr(calc.addDays(new Date(periodStartDate), ovulationDay - 1));
      const fertileStart = calc.toDateStr(calc.addDays(new Date(periodStartDate), fertileWindow.start - 1));
      const fertileEnd = calc.toDateStr(calc.addDays(new Date(periodStartDate), fertileWindow.end - 1));

      // Create log entry
      const logId = await CycleModel.createLog({
        id, profileId, userId, periodStartDate,
        periodEndDate: periodEndDate || calc.toDateStr(calc.addDays(new Date(periodStartDate), periodDuration - 1)),
        cycleLength, periodDuration, flowIntensity,
        ovulationDate, fertileWindowStart: fertileStart, fertileWindowEnd: fertileEnd,
        symptoms, notes,
      });

      // Auto-generate daily cycle data for entire cycle
      for (let day = 1; day <= cycleLength; day++) {
        const date = calc.toDateStr(calc.addDays(new Date(periodStartDate), day - 1));
        const phase = calc.determineCyclePhase(day, cycleLength, periodDuration, ovulationDay);
        const fertilityLevel = calc.determineFertilityLevel(day, ovulationDay);
        const probability = calc.calculateConceptionProbability(day - ovulationDay);
        await CycleModel.upsertDailyData({
          logId, userId, date, dayOfCycle: day, phase, fertilityLevel,
          conceptionProbability: probability,
        });
      }

      // Update profile averages
      const allLogs = await CycleModel.findLogsByProfile(profileId, userId, 12);
      const stats = calc.calculateCycleStatistics(allLogs);
      await CycleModel.updateProfile(profileId, userId, {
        avgCycleLength: Math.round(stats.avgCycleLength),
        avgPeriodDuration: Math.round(stats.avgPeriodDuration),
        lastPeriodStart: periodStartDate,
      });

      res.status(201).json(formatResponse(true, 'Period logged with medical calculations', {
        logId, cycleLength, periodDuration, ovulationDate,
        fertileWindow: { start: fertileStart, end: fertileEnd },
      }));
    } catch (err) {
      console.error('❌ [LOG-PERIOD]', err);
      res.status(500).json(formatResponse(false, 'Internal server error'));
    }
  },

  // ── GET /logs ─────────────────────────────────────────────
  async getHistory(req, res) {
    try {
      const { profileId, page = 1, limit = 10 } = req.query;
      const offset = (parseInt(page) - 1) * parseInt(limit);
      let logs;
      if (profileId) {
        logs = await CycleModel.findLogsByProfile(profileId, req.user.id, parseInt(limit), offset);
      } else {
        logs = await CycleModel.findLogsByUser(req.user.id, parseInt(limit), offset);
      }
      res.json(formatResponse(true, 'History loaded', { logs, page: parseInt(page), limit: parseInt(limit) }));
    } catch (err) {
      console.error('❌ [GET-HISTORY]', err);
      res.status(500).json(formatResponse(false, 'Internal server error'));
    }
  },

  // ── GET /dashboard — Comprehensive dashboard data ─────────
  async getDashboard(req, res) {
    try {
      const userId = req.user.id;
      const { profileId } = req.query;

      const profiles = await CycleModel.findProfilesByUser(userId);
      const activeProfile = profileId
        ? profiles.find(p => p.id === profileId)
        : profiles[0];

      if (!activeProfile) {
        return res.json(formatResponse(true, 'No cycle profile found. Create one to get started.', {
          hasProfile: false, profiles,
        }));
      }

      const latestLog = await CycleModel.findLatestLog(activeProfile.id, userId);
      const allLogs = await CycleModel.findLogsByProfile(activeProfile.id, userId, 12);
      const stats = calc.calculateCycleStatistics(allLogs);

      let dashboard = { hasProfile: true, profile: activeProfile, statistics: stats, profiles };

      const lastStartVal = activeProfile.last_period_start || (latestLog ? latestLog.period_start_date : null);

      if (lastStartVal) {
        const lastStart = new Date(lastStartVal);
        const today = new Date();
        today.setHours(0, 0, 0, 0);
        const currentDayOfCycle = calc.daysBetween(calc.toDateStr(lastStart), calc.toDateStr(today)) + 1;
        const avgCycle = activeProfile.avg_cycle_length || 28;
        const avgPeriod = activeProfile.avg_period_duration || 5;
        const luteal = activeProfile.luteal_phase_length || 14;
        const ovulationDay = calc.calculateOvulationDay(avgCycle, luteal);
        const fertileWindow = calc.calculateFertileWindow(ovulationDay);

        // Current status
        const phase = calc.determineCyclePhase(currentDayOfCycle, avgCycle, avgPeriod, ovulationDay);
        const fertilityLevel = calc.determineFertilityLevel(currentDayOfCycle, ovulationDay);
        const conceptionProb = calc.calculateConceptionProbability(currentDayOfCycle - ovulationDay);

        // Predictions
        const nextPeriodDate = calc.toDateStr(calc.addDays(lastStart, avgCycle));
        const nextOvulationDate = calc.toDateStr(calc.addDays(lastStart, ovulationDay - 1));
        const daysUntilNextPeriod = Math.max(0, avgCycle - currentDayOfCycle + 1);

        // Forecast next 3 cycles
        const forecast = calc.generateCycleForecast(
          calc.toDateStr(calc.addDays(lastStart, avgCycle)), // Start from next predicted period
          avgCycle, avgPeriod, luteal, 3
        );

        dashboard = {
          ...dashboard,
          currentDayOfCycle,
          currentPhase: phase,
          currentFertilityLevel: fertilityLevel,
          conceptionProbability: conceptionProb,
          nextPeriodDate,
          nextOvulationDate,
          daysUntilNextPeriod,
          fertileWindow: {
            start: calc.toDateStr(calc.addDays(lastStart, fertileWindow.start - 1)),
            end: calc.toDateStr(calc.addDays(lastStart, fertileWindow.end - 1)),
          },
          latestLog,
          forecast,
        };
      }

      res.json(formatResponse(true, 'Dashboard loaded', dashboard));
    } catch (err) {
      console.error('❌ [DASHBOARD]', err);
      res.status(500).json(formatResponse(false, 'Internal server error'));
    }
  },

  // ── PUT /logs/:id ─────────────────────────────────────────
  async updateLog(req, res) {
    try {
      const log = await CycleModel.findLogById(req.params.id, req.user.id);
      if (!log) return res.status(404).json(formatResponse(false, 'Log not found'));
      await CycleModel.updateLog(req.params.id, req.user.id, req.body);
      res.json(formatResponse(true, 'Log updated'));
    } catch (err) {
      console.error('❌ [UPDATE-LOG]', err);
      res.status(500).json(formatResponse(false, 'Internal server error'));
    }
  },

  // ── DELETE /logs/:id ──────────────────────────────────────
  async deleteLog(req, res) {
    try {
      await CycleModel.deleteLog(req.params.id, req.user.id);
      res.json(formatResponse(true, 'Log deleted'));
    } catch (err) {
      console.error('❌ [DELETE-LOG]', err);
      res.status(500).json(formatResponse(false, 'Internal server error'));
    }
  },

  // ── GET /daily ────────────────────────────────────────────
  async getDailyData(req, res) {
    try {
      const { from, to } = req.query;
      if (!from || !to) return res.status(400).json(formatResponse(false, 'from and to dates required'));
      const data = await CycleModel.findDailyByDateRange(req.user.id, from, to);
      res.json(formatResponse(true, 'Daily data loaded', { data }));
    } catch (err) {
      console.error('❌ [GET-DAILY]', err);
      res.status(500).json(formatResponse(false, 'Internal server error'));
    }
  },

  // ── DELETE /profiles/:id ──────────────────────────────────
  async deleteProfile(req, res) {
    try {
      await CycleModel.deleteProfile(req.params.id, req.user.id);
      res.json(formatResponse(true, 'Cycle profile deleted'));
    } catch (err) {
      console.error('❌ [DELETE-PROFILE]', err);
      res.status(500).json(formatResponse(false, 'Internal server error'));
    }
  },
};

module.exports = CycleController;
