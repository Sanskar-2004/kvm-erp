const express = require('express');
const router = express.Router();
const feeController = require('../controllers/feeController');
const authMiddleware = require('../middleware/authMiddleware');

// Get 12-month fee ledger for a student
router.get('/:studentId/:year', authMiddleware, feeController.getStudentFees);

// Update a fee record (accountant records payment)
router.put('/:id', authMiddleware, feeController.updateFee);

// Generate 12-month fee records for a student
router.post('/generate/:studentId', authMiddleware, feeController.generateFees);

// Alerts
router.post('/alerts', authMiddleware, feeController.createAlert);
router.get('/alerts/:userId', authMiddleware, feeController.getAlerts);

module.exports = router;
