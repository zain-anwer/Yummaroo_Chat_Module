import express from 'express';
import dotenv from 'dotenv';
import {getChatList, getMessages, sendMessage} from '../controllers/message.controller.js';
import {protectRoute} from '../middleware/auth.middleware.js';
import {arcjetProtection} from '../middleware/arcjet.middleware.js';

dotenv.config();

const router = express.Router();
router.use(protectRoute);

router.get("/chats",getChatList);
router.get("/messages/:otherUserId",getMessages);
router.post("/send/:id",sendMessage);

export default router;
