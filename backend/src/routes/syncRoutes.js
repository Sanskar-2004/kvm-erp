const express = require('express');
const router = express.Router();
const syncController = require('../controllers/syncController');
const authMiddleware = require('../middleware/authMiddleware');

// Protect both endpoints leveraging explicit JWT Bearer scopes natively
router.post('/push', authMiddleware, syncController.syncPush);
router.get('/pull', authMiddleware, syncController.syncPull);

module.exports = router;
