const express = require('express');
const router = express.Router();
const parentController = require('../controllers/parentController');
const authMiddleware = require('../middleware/authMiddleware');

router.get('/children/:parentId', authMiddleware, parentController.getChildren);
router.post('/link', authMiddleware, parentController.linkParentStudent);
router.get('/student-summary/:studentId', authMiddleware, parentController.getStudentSummary);

module.exports = router;
