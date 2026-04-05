const express = require('express');
const router = express.Router();
const assignmentController = require('../controllers/assignmentController');
const { verifyToken, verifyRole } = require('../middleware/authMiddleware');

router.post('/', verifyToken, verifyRole(['admin']), assignmentController.createAssignment);
router.get('/', verifyToken, assignmentController.getAssignments);
router.delete('/:id', verifyToken, verifyRole(['admin']), assignmentController.deleteAssignment);

module.exports = router;
