const express = require('express');
const router = express.Router();
const staffController = require('../controllers/staffController');
const authMiddleware = require('../middleware/authMiddleware');

router.post('/', authMiddleware, staffController.createStaff);
router.get('/', authMiddleware, staffController.getAllStaff);

module.exports = router;
