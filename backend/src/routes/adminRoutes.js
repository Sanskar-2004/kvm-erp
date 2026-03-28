const express = require('express');
const router = express.Router();
const adminController = require('../controllers/adminController');
const authMiddleware = require('../middleware/authMiddleware');

router.get('/finance-summary', authMiddleware, adminController.getFinanceSummary);
router.get('/class-ranks/:classId/:examType', authMiddleware, adminController.calculateClassRanks);
router.get('/due-fees', authMiddleware, adminController.getDueFees);

module.exports = router;
