const express = require('express');
const router = express.Router();
const studentController = require('../controllers/studentController');
const authMiddleware = require('../middleware/authMiddleware');

// Admin-only: Get all pending admissions
router.get('/pending', authMiddleware, studentController.getPendingAdmissions);

// Admin-only: Approve or reject a student
router.patch('/:id/status', authMiddleware, studentController.updateStudentStatus);

module.exports = router;
