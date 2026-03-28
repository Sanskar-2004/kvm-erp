const express = require('express');
const router = express.Router();
const timetableController = require('../controllers/timetableController');
const authMiddleware = require('../middleware/authMiddleware');

router.post('/', authMiddleware, timetableController.createTimetableEntry);
router.get('/class/:classId', authMiddleware, timetableController.getClassTimetable);
router.get('/teacher/:teacherId', authMiddleware, timetableController.getTeacherTimetable);

module.exports = router;
