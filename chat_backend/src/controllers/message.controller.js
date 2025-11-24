import {pool} from '../lib/db.js';

export const getMessages = async (req, res) => {
  const client = await pool.connect();
  
  try {
    const { otherUserId } = req.params;
    const currentUserId = req.userId; // Changed from req.user.id to req.userId
    
    const query = `
      SELECT chat_id, sender_id, receiver_id, message, sent_at, status
      FROM chatmessage
      WHERE (sender_id = $1 AND receiver_id = $2)
         OR (sender_id = $2 AND receiver_id = $1)
      ORDER BY sent_at ASC
      LIMIT 100
    `;
    
    const result = await client.query(query, [currentUserId, otherUserId]);
    
    const messages = result.rows.map(row => ({
      id: row.chat_id,
      message: row.message,
      senderId: row.sender_id,
      receiverId: row.receiver_id,
      timestamp: row.sent_at,
      status: row.status,
    }));
    
    res.status(200).json({
      messages,
      currentUserId
    });
    
  } catch (error) {
    console.error('Error loading messages:', error);
    res.status(500).json({ message: 'Failed to load messages' });
  } finally {
    client.release();
  }
};

export const getChatList = async (req, res) => {
  const client = await pool.connect();
  
  try {
    const currentUserId = req.userId; // Changed from req.user.id to req.userId
    
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
    
    const result = await client.query(query, [currentUserId]);
    
    const chats = result.rows.map(row => ({
      id: row.other_user_id.toString(),
      recipientName: row.recipient_name || 'User',
      recipientAvatar: row.recipient_avatar || null,
      lastMessage: row.last_message,
      lastMessageTime: row.last_message_time,
      unreadCount: parseInt(row.unread_count)
    }));
    
    res.status(200).json({ chats });
    
  } catch (error) {
    console.error('Error loading chat list:', error);
    res.status(500).json({ message: 'Failed to load chats' });
  } finally {
    client.release();
  }
};

export const sendMessage = async (req,res) => 
{
    try
    {
        const {message:text} = req.body;
        const {id:receiver_id} = req.params;
        const sender_id = req.userId;
        
        const message = await pool.query(
        `INSERT INTO ChatMessage(sender_id,receiver_id,message) VALUES($1,$2,$3) 
        RETURNING 
          chat_id AS id,
          sender_id AS senderId,
          receiver_id AS receiverId,
          message,
          sent_at AS timestamp,
          status;`
          ,[sender_id,receiver_id,text]);
        res.status(201).send(
        {
          "success" : true,
          "data" : message.rows[0],
        });
    }

    catch(error)
    {
        console.log("Error in message controller: ",error.message);
        res.status(500).json({error: "Internal Server Error"});
    } 

}
