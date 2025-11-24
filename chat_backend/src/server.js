import cors from 'cors';
import express from 'express';
import dotenv from 'dotenv';
import path from 'path';
import cookieParser from 'cookie-parser';
import http from 'http';
import { Server } from 'socket.io';

import authRoutes from './routes/auth.route.js';
import messageRoutes from './routes/message.route.js';

dotenv.config();

const app = express();
const PORT = process.env.PORT || 3000;
const __dirname = path.resolve();

// Create HTTP server for Socket.IO
const server = http.createServer(app);

// Initialize Socket.IO
const io = new Server(server, {
  cors: {
    origin: true, // Match your existing CORS config
    methods: ["GET", "POST"],
    credentials: true
  }
});

// Middleware
app.use(express.json());
app.use(cookieParser());
app.use(cors({
  origin: true
}));

// REST API Routes
app.use("/api/auth", authRoutes);
app.use("/api", messageRoutes);

// Socket.IO Setup
import initializeSocket from './socket/socket.js';
initializeSocket(io);

// Start server (use 'server' instead of 'app')
server.listen(PORT,"0.0.0.0",() => {
  console.log("Server is running on port number", PORT, "\n");
  console.log("Socket.IO is ready for connections");
});

// Export io for use in controllers if needed
export { io };

/*
// const express = require('express');
import cors from 'cors';
import express from 'express';
import dotenv from 'dotenv';
import path from 'path';
import cookieParser from 'cookie-parser';

import authRoutes from './routes/auth.route.js';
import messageRoutes from './routes/message.route.js';

dotenv.config();

const app = express();
const PORT = process.env.PORT || 3000;
const __dirname = path.resolve();

// some kinda middleware to parse json???
app.use(express.json());
app.use(cookieParser());


app.use(cors({
  origin: true
}));


app.use("/api/auth",authRoutes);
app.use("/api",messageRoutes);


app.listen(PORT, () => console.log("Server is running on port number",PORT, "\n"));

*/