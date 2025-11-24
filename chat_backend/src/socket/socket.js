import jwt from 'jsonwebtoken';
import chatHandlers from './chat_handlers.js';
import messageHandlers from './message_handlers.js';

const initializeSocket = (io) => {
  // Middleware: Authenticate socket connections
  io.use(async (socket, next) => {
    try {
      console.log('🔐 Authenticating socket connection...');
      console.log('   Headers:', socket.handshake.headers.authorization);
      
      const token = socket.handshake.query.token;          
      
      if (!token) {
        console.log('❌ No token provided');
        return next(new Error('Authentication error'));
      }
      
      const decoded = jwt.verify(token, process.env.JWT_SECRET);
      socket.userId = decoded.userId;
      socket.userEmail = decoded.email;
      
      console.log('✅ Socket authenticated successfully');
      console.log('   userId:', socket.userId, typeof socket.userId);
      console.log('   email:', socket.userEmail);
      
      next();
    } catch (error) {
      console.error('❌ Socket authentication error:', error.message);
      next(new Error('Authentication error'));
    }
  });

  // Handle connections
  io.on('connection', (socket) => {
    console.log(`\n✅ ===== NEW CONNECTION =====`);
    console.log(`   User ID: ${socket.userId}`);
    console.log(`   Socket ID: ${socket.id}`);
    console.log(`============================\n`);
    
    // Log all events
    socket.onAny((eventName, ...args) => {
      console.log(`\n📡 Event received: "${eventName}"`);
      console.log(`   From user: ${socket.userId}`);
      console.log(`   Data:`, JSON.stringify(args, null, 2));
    });
    
    // Register chat handlers
    try {
      chatHandlers(io, socket);
      console.log('✅ Chat handlers registered');
    } catch (error) {
      console.error('❌ Error registering chat handlers:', error);
    }
    
    // Register message handlers
    try {
      messageHandlers(io, socket);
      console.log('✅ Message handlers registered');
    } catch (error) {
      console.error('❌ Error registering message handlers:', error);
    }
    
    // Handle disconnection
    socket.on('disconnect', (reason) => {
      console.log(`\n❌ ===== DISCONNECTION =====`);
      console.log(`   User ID: ${socket.userId}`);
      console.log(`   Socket ID: ${socket.id}`);
      console.log(`   Reason: ${reason}`);
      console.log(`============================\n`);
    });
    
    // Handle errors
    socket.on('error', (error) => {
      console.error(`\n🔴 ===== SOCKET ERROR =====`);
      console.error(`   User ID: ${socket.userId}`);
      console.error(`   Error:`, error);
      console.error(`============================\n`);
    });
    
    // Handle connect_error
    socket.on('connect_error', (error) => {
      console.error(`\n🔴 ===== CONNECTION ERROR =====`);
      console.error(`   User ID: ${socket.userId}`);
      console.error(`   Error:`, error);
      console.error(`============================\n`);
    });
  });
  
  // Global error handler
  io.engine.on("connection_error", (err) => {
    console.error('\n🔴 ===== ENGINE ERROR =====');
    console.error('   Code:', err.code);
    console.error('   Message:', err.message);
    console.error('   Context:', err.context);
    console.error('============================\n');
  });
};

export default initializeSocket;