const express = require('express');
const router = express.Router();
const adminController = require('../controllers/adminController');
const authMiddleware = require('../middleware/authMiddleware');

router.get('/finance-summary', authMiddleware, adminController.getFinanceSummary);
router.get('/class-ranks/:classId/:examType', authMiddleware, adminController.calculateClassRanks);
router.get('/due-fees', authMiddleware, adminController.getDueFees);
router.post('/create-student-accounts', authMiddleware, adminController.createStudentAccounts);
router.post('/nuke-database', authMiddleware, adminController.nukeDatabase);

module.exports = router;
