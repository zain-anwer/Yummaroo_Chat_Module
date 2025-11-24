import { pool } from '../lib/db.js';

const chatHandlers = (io, socket) => {

  // --- Join a conversation room ---
  socket.on('join_chat', async (data) => {
    const otherUserId = data.otherUserId?.toString();
    if (!otherUserId) return;

    const roomId = [socket.userId.toString(), otherUserId].sort().join('-');

    socket.join(roomId);
    console.log(`👥 User ${socket.userId} joined room: ${roomId}`);

    await pool.query("UPDATE ChatMessage SET status = 'read' where status != 'read' AND receiver_id = $1 and sender_id = $2;",[socket.userId,otherUserId]);

    socket.to(roomId).emit('user_joined', { userId: socket.userId.toString() });
  });

  // --- Leave a conversation room ---
  socket.on('leave_chat', (data) => {
    const otherUserId = data.otherUserId?.toString();
    if (!otherUserId) return;

    const roomId = [socket.userId.toString(), otherUserId].sort().join('-');

    socket.leave(roomId);
    console.log(`👋 User ${socket.userId} left room: ${roomId}`);
  });

  // --- Typing indicator ---
  socket.on('typing', (data) => {
    const otherUserId = data.otherUserId?.toString();
    const isTyping = data.isTyping;
    if (!otherUserId) return;

    const roomId = [socket.userId.toString(), otherUserId].sort().join('-');

    socket.to(roomId).emit('user_typing', {
      userId: socket.userId.toString(),
      isTyping
    });
  });

  // --- Get chat list ---
  socket.on('get_chat_list', async () => {
    const client = await pool.connect();
    try {
      const query = `
       WITH ranked_messages AS (
        SELECT 
          chat_id,
          sender_id,
          receiver_id,
          message,
          sent_at,
          status,
          CASE 
            WHEN sender_id = $1 THEN receiver_id 
            ELSE sender_id 
          END as other_user_id,
          ROW_NUMBER() OVER (
            PARTITION BY CASE 
              WHEN sender_id = $1 THEN receiver_id 
              ELSE sender_id 
            END 
            ORDER BY sent_at DESC
          ) as rn
        FROM chatmessage
        WHERE sender_id = $1 OR receiver_id = $1
      ),
      unread_counts AS (
        SELECT 
          sender_id as other_user_id,
          COUNT(*) as unread_count
        FROM chatmessage
        WHERE receiver_id = $1 AND status != 'read'
        GROUP BY sender_id
      )
      SELECT 
        rm.other_user_id,
        rm.message as last_message,
        rm.sent_at as last_message_time,
        COALESCE(uc.unread_count, 0) as unread_count,
        u.name as recipient_name,
        u.profile_picture as recipient_avatar
      FROM ranked_messages rm
      LEFT JOIN unread_counts uc ON rm.other_user_id = uc.other_user_id
      LEFT JOIN users u ON rm.other_user_id = u.user_id
      WHERE rm.rn = 1
      ORDER BY rm.sent_at DESC
    `; 

      const result = await client.query(query, [socket.userId]);

      const chats = result.rows.map(row => ({
        id: row.other_user_id.toString(),
        recipientName: row.recipient_name || 'User',
        recipientAvatar: row.recipient_avatar || null,
        lastMessage: row.last_message,
        lastMessageTime: row.last_message_time,
        unreadCount: parseInt(row.unread_count)
      }));

      socket.emit('chat_list', {
        chats,
        currentUserId: socket.userId.toString()
      });

      console.log(`📋 Loaded ${chats.length} chats for user ${socket.userId}`);
    } catch (error) {
      console.error('❌ Error getting chat list:', error);
      socket.emit('error', { message: 'Failed to load chat list' });
    } finally {
      client.release();
    }
  });

  // --- Get unread count for a specific user ---
  socket.on('get_unread_count', async (data) => {
    const otherUserId = data.otherUserId?.toString();
    if (!otherUserId) return;

    const client = await pool.connect();
    try {
      const query = `
        SELECT COUNT(*) as unread_count
        FROM chatmessage
        WHERE sender_id = $1 AND receiver_id = $2 AND status != 'read';
      `;

      const result = await client.query(query, [otherUserId, socket.userId]);
      const unreadCount = parseInt(result.rows[0].unread_count);

      socket.emit('unread_count', {
        otherUserId,
        count: unreadCount
      });
    } catch (error) {
      console.error('❌ Error getting unread count:', error);
    } finally {
      client.release();
    }
  });

};

export default chatHandlers;



/*

import {pool} from '../lib/db.js'; // Adjust path to your pool

const chatHandlers = (io, socket) => {
  
  // Join a conversation room
  socket.on('join_chat', (data) => {
    const { otherUserId } = data;
    
    // Create consistent room ID (sorted user IDs)
    const roomId = [socket.userId, otherUserId].sort().join('-');
    
    socket.join(roomId);
    console.log(`👥 User ${socket.userId} joined room: ${roomId}`);
    
    // Notify other user if online
    socket.to(roomId).emit('user_joined', {
      userId: socket.userId
    });
  });
  
  // Leave a conversation room
  socket.on('leave_chat', (data) => {
    const { otherUserId } = data;
    const roomId = [socket.userId, otherUserId].sort().join('-');
    
    socket.leave(roomId);
    console.log(`👋 User ${socket.userId} left room: ${roomId}`);
  });
  
  // Typing indicator
  socket.on('typing', (data) => {
    const { otherUserId, isTyping } = data;
    const roomId = [socket.userId, otherUserId].sort().join('-');
    
    socket.to(roomId).emit('user_typing', {
      userId: socket.userId,
      isTyping: isTyping
    });
  });
  
  // Get chat list - all conversations for this user
  socket.on('get_chat_list', async () => {
    const client = await pool.connect();
    
    try {
      // Get latest message from each conversation
      const query = `
        WITH ranked_messages AS (
          SELECT 
            chat_id,
            sender_id,
            receiver_id,
            message,
            sent_at,
            status,
            CASE 
              WHEN sender_id = $1 THEN receiver_id 
              ELSE sender_id 
            END as other_user_id,
            ROW_NUMBER() OVER (
              PARTITION BY CASE 
                WHEN sender_id = $1 THEN receiver_id 
                ELSE sender_id 
              END 
              ORDER BY sent_at DESC
            ) as rn
          FROM chatmessage
          WHERE sender_id = $1 OR receiver_id = $1
        ),
        unread_counts AS (
          SELECT 
            sender_id as other_user_id,
            COUNT(*) as unread_count
          FROM chatmessage
          WHERE receiver_id = $1 AND status != 'read'
          GROUP BY sender_id
        )
        SELECT 
          rm.other_user_id,
          rm.message as last_message,
          rm.sent_at as last_message_time,
          COALESCE(uc.unread_count, 0) as unread_count,
          u.username as recipient_name,
          u.profile_picture as recipient_avatar
        FROM ranked_messages rm
        LEFT JOIN unread_counts uc ON rm.other_user_id = uc.other_user_id
        LEFT JOIN users u ON rm.other_user_id = u.user_id
        WHERE rm.rn = 1
        ORDER BY rm.sent_at DESC;
      `;
      
      const result = await client.query(query, [socket.userId]);
      
      const chats = result.rows.map(row => ({
        id: row.other_user_id.toString(),
        recipientName: row.recipient_name || 'User',
        recipientAvatar: row.recipient_avatar || null,
        lastMessage: row.last_message,
        lastMessageTime: row.last_message_time,
        unreadCount: parseInt(row.unread_count)
      }));
      
      socket.emit('chat_list', { 
        chats,
        currentUserId: socket.userId
      });
      
      console.log(`📋 Loaded ${chats.length} chats for user ${socket.userId}`);
      
    } catch (error) {
      console.error('❌ Error getting chat list:', error);
      socket.emit('error', { message: 'Failed to load chat list' });
    } finally {
      client.release();
    }
  });
  
  // Get unread count from specific user
  socket.on('get_unread_count', async (data) => {
    const { otherUserId } = data;
    const client = await pool.connect();
    
    try {
      const query = `
        SELECT COUNT(*) as unread_count 
        FROM chatmessage 
        WHERE sender_id = $1 
        AND receiver_id = $2 
        AND status != 'read';
      `;
      
      const result = await client.query(query, [otherUserId, socket.userId]);
      const unreadCount = parseInt(result.rows[0].unread_count);
      
      socket.emit('unread_count', { 
        otherUserId: otherUserId, 
        count: unreadCount 
      });
      
    } catch (error) {
      console.error('❌ Error getting unread count:', error);
    } finally {
      client.release();
    }
  });
};

export default chatHandlers;
*/