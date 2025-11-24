import { pool } from '../lib/db.js';

const messageHandlers = (io, socket) => {
  
  // Wrap the entire handler registration in try-catch
  try {
    
  // Send a message
  socket.on('send_message', async (data) => {
    console.log(`\n📨 ===== SEND_MESSAGE START =====`);
    console.log(`   From user: ${socket.userId}`);
    console.log(`   Data received:`, data);
    
    let client;
    
    try {
      client = await pool.connect();
      console.log('✅ Database connection acquired');
      
      const { receiverId, message, timestamp } = data;
      
      // Validate data
      if (!receiverId) {
        throw new Error('receiverId is missing');
      }
      if (!message) {
        throw new Error('message is empty');
      }
      if (!socket.userId) {
        throw new Error('socket.userId is undefined');
      }
      
      // Convert to integers
      const receiverIdInt = parseInt(receiverId, 10);
      const senderIdInt = parseInt(socket.userId, 10);
      
      console.log(`   Sender ID: ${senderIdInt} (type: ${typeof senderIdInt})`);
      console.log(`   Receiver ID: ${receiverIdInt} (type: ${typeof receiverIdInt})`);
      
      if (isNaN(receiverIdInt)) {
        throw new Error(`receiverId "${receiverId}" is not a valid number`);
      }
      if (isNaN(senderIdInt)) {
        throw new Error(`socket.userId "${socket.userId}" is not a valid number`);
      }
      
      // Insert message
      console.log('💾 Inserting message into database...');
      const insertMessageQuery = `
        INSERT INTO chatmessage (sender_id, receiver_id, message, sent_at, status)
        VALUES ($1, $2, $3, $4, $5)
        RETURNING chat_id, sender_id, receiver_id, message, sent_at, status
      `;
      
      const messageResult = await client.query(insertMessageQuery, [
        senderIdInt,
        receiverIdInt,
        message,
        timestamp || new Date(),
        'sent'
      ]);
      
      const newMessage = messageResult.rows[0];
      console.log('✅ Message inserted:', newMessage.chat_id);
      
      // Create room ID
      const roomId = [senderIdInt.toString(), receiverIdInt.toString()].sort().join('-');
      console.log(`🚪 Room ID: ${roomId}`);
      
      // Check if receiver is online
      console.log('👥 Checking if receiver is online...');
      const sockets = await io.fetchSockets();
      console.log(`   Total connected sockets: ${sockets.length}`);
      console.log(`   Socket user IDs:`, sockets.map(s => s.userId));
      
      const receiverOnline = sockets.some(s => parseInt(s.userId) === receiverIdInt);
      console.log(`   Receiver ${receiverIdInt} online: ${receiverOnline}`);
      
      if (receiverOnline) {
        console.log('📝 Updating status to delivered...');
        await client.query(
          `UPDATE chatmessage SET status = 'delivered' WHERE chat_id = $1`,
          [newMessage.chat_id]
        );
        newMessage.status = 'delivered';
        console.log('✅ Status updated to delivered');
      }
      
      // Broadcast
      console.log(`📡 Broadcasting to room: ${roomId}`);
      const messagePayload = {
        id: newMessage.chat_id,
        message: newMessage.message,
        senderId: newMessage.sender_id,
        receiverId: newMessage.receiver_id,
        timestamp: newMessage.sent_at,
        status: newMessage.status
      };
      
      console.log('   Payload:', messagePayload);
      io.to(roomId).emit('new_message', messagePayload);
      console.log('✅ Broadcast complete');
      
      // Confirm to sender
      console.log('📤 Confirming delivery to sender...');
      socket.emit('message_delivered', {
        tempId: data.tempId,
        messageId: newMessage.chat_id,
        status: newMessage.status
      });
      console.log('✅ Confirmation sent');
      
      console.log(`✅ ===== SEND_MESSAGE COMPLETE =====\n`);
      
    } catch (error) {
      console.error(`\n❌ ===== SEND_MESSAGE ERROR =====`);
      console.error('   Error type:', error.constructor.name);
      console.error('   Error message:', error.message);
      console.error('   Error stack:', error.stack);
      console.error('   socket.userId:', socket.userId, typeof socket.userId);
      console.error('   Received data:', JSON.stringify(data, null, 2));
      console.error(`============================\n`);
      
      socket.emit('message_failed', {
        error: 'Failed to send message: ' + error.message,
        tempId: data?.tempId
      });
    } finally {
      if (client) {
        client.release();
        console.log('🔌 Database connection released');
      }
    }
  });
  
  // Keep your other handlers (open_chat, delete_message) as they are
  
  } catch (error) {
    console.error('\n🔴 ===== CRITICAL ERROR IN MESSAGE HANDLERS =====');
    console.error('   Error registering message handlers:', error);
    console.error('============================\n');
  }
};

export default messageHandlers;