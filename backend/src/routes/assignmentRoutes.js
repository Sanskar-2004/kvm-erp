const express = require('express');
const router = express.Router();
const assignmentController = require('../controllers/assignmentController');
const authMiddleware = require('../middleware/authMiddleware');

router.post('/', authMiddleware, assignmentController.createAssignment);
router.get('/', authMiddleware, assignmentController.getAssignments);
router.delete('/:id', authMiddleware, assignmentController.deleteAssignment);

module.exports = router;
