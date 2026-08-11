const express = require('express');
const router = express.Router();
const studentController = require('../controllers/studentController');
const authMiddleware = require('../middleware/authMiddleware');

// Get all active students
router.get('/', authMiddleware, studentController.getAllStudents);

// Admin-only: Get all pending admissions
router.get('/pending', authMiddleware, studentController.getPendingAdmissions);

// Admin-only: Approve or reject a student
router.patch('/:id/status', authMiddleware, studentController.updateStudentStatus);

module.exports = router;
