const express = require('express');
const router = express.Router();
const staffController = require('../controllers/staffController');
const { verifyToken, verifyRole } = require('../middleware/authMiddleware');

router.post('/', verifyToken, verifyRole(['admin']), staffController.createStaff);
router.get('/', verifyToken, staffController.getAllStaff);

module.exports = router;
