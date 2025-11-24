import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../services/socket_service.dart';

class ChatDetailPage extends StatefulWidget {
  final String otherUserId; // Keep as String for widget parameter
  final String recipientName;
  final String? recipientAvatar;

  const ChatDetailPage({
    super.key,
    required this.otherUserId,
    required this.recipientName,
    this.recipientAvatar,
  });

  @override
  State<ChatDetailPage> createState() => _ChatDetailPageState();
}

class _ChatDetailPageState extends State<ChatDetailPage> {
  final ApiService _apiService = ApiService();
  final SocketService _socketService = SocketService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<Map<String, dynamic>> _messages = [];
  bool _isLoading = true;
  bool _isSending = false;
  int? _currentUserId; // Changed from String? to int?

  @override
  void initState() {
    super.initState();
    _initializeChat();
  }

 Future<void> _initializeChat() async {
  // Join this specific chat room with the other user
  if (!_socketService.isConnected()) {
    await _socketService.connect();
  }

  _socketService.joinChat(widget.otherUserId);

  // Mark messages as read when opening chat
  _socketService.markAsRead(widget.otherUserId);

  // Set up message listener
  _socketService.onMessageReceived = (message) {
    print('📨 Received new_message event: $message');
    
    // Check if message is from/to this conversation
    final otherUserIdInt = int.tryParse(widget.otherUserId);
    final messageSenderId = message['senderId'];
    final messageReceiverId = message['receiverId'];
    
    print('   otherUserId: $otherUserIdInt');
    print('   senderId: $messageSenderId');
    print('   receiverId: $messageReceiverId');
    
    if (messageSenderId == otherUserIdInt || messageReceiverId == otherUserIdInt) {
      setState(() {
        // ✅ FIX: Check if message already exists (from optimistic UI)
        final existingIndex = _messages.indexWhere((m) {
          // Check if this is our optimistic message by comparing content and sender
          return m['message'] == message['message'] && 
                 m['senderId'] == _currentUserId &&
                 m['status'] == 'sending';
        });
        
        if (existingIndex != -1) {
          // Update the existing optimistic message with real data
          print('   ✅ Updating existing optimistic message');
          _messages[existingIndex] = {
            'id': message['id'],
            'message': message['message'],
            'senderId': message['senderId'],
            'receiverId': message['receiverId'],
            'timestamp': message['timestamp'],
            'status': message['status'],
          };
        } else {
          // This is a new message from the other user
          print('   ✅ Adding new message from other user');
          _messages.add(message);
        }
      });
      _scrollToBottom();

      // Auto-mark as read if from other user
      if (messageSenderId == otherUserIdInt) {
        _socketService.markAsRead(widget.otherUserId);
      }
    }
  };

  // ✅ FIX: Listen for message_delivered event
  _socketService.socket?.on('message_delivered', (data) {
    print('✅ Received message_delivered event: $data');
    
    setState(() {
      final tempId = data['tempId']?.toString();
      if (tempId != null) {
        final index = _messages.indexWhere((m) => m['id'] == tempId);
        if (index != -1) {
          print('   Updating message $tempId with real ID ${data['messageId']}');
          _messages[index]['id'] = data['messageId'];
          _messages[index]['status'] = data['status'] ?? 'sent';
        }
      }
    });
  });

  // Listen for message status updates
  _socketService.socket?.on('message_status_updated', (data) {
    print('📊 Received message_status_updated event: $data');
    
    setState(() {
      final index = _messages.indexWhere((m) => m['id'] == data['messageId']);
      if (index != -1) {
        _messages[index]['status'] = data['status'];
      }
    });
  });

  // ✅ FIX: Listen for messages_read event
  _socketService.socket?.on('messages_read', (data) {
    print('👀 Received messages_read event: $data');
    
    setState(() {
      // Mark all MY messages as read
      for (var message in _messages) {
        if (message['senderId'] == _currentUserId) {
          print('   Marking message ${message['id']} as read');
          message['status'] = 'read';
        }
      }
    });
  });

  // Load existing messages
  await _loadMessages();
}

  Future<void> _loadMessages() async {
    setState(() => _isLoading = true);

    final result = await _apiService.getMessages(widget.otherUserId);

    if (result['success']) {
      setState(() {
        _messages = List<Map<String, dynamic>>.from(
          result['data']['messages'] ?? [],
        );
        // Handle both int and String types from backend
        final userId = result['data']['currentUserId'];
        _currentUserId = userId is int
            ? userId
            : int.tryParse(userId?.toString() ?? '');
        _isLoading = false;
      });

      // Scroll to bottom after loading
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToBottom();
      });
    } else {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['error'] ?? 'Failed to load messages')),
        );
      }
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

 Future<void> _sendMessage() async {
  final message = _messageController.text.trim();
  if (message.isEmpty) return;

  setState(() {
    _isSending = true;
    _messageController.clear();
  });

  final tempId = DateTime.now().millisecondsSinceEpoch.toString();

  print('\n📤 Sending message...');
  print('   tempId: $tempId');
  print('   message: $message');
  print('   receiverId: ${widget.otherUserId}');

  // Optimistically add message to UI
  setState(() {
    _messages.add({
      'id': tempId,
      'message': message,
      'senderId': _currentUserId,
      'receiverId': int.tryParse(widget.otherUserId),
      'timestamp': DateTime.now().toIso8601String(),
      'status': 'sending',
    });
    _isSending = false;
  });

  _scrollToBottom();

  // Try to send via Socket.IO first
  if (_socketService.isConnected()) {
    print('   ✅ Socket connected, sending via Socket.IO');
    // ✅ FIX: Pass tempId to socket service
    _socketService.sendMessage(widget.otherUserId, message, tempId);
  } else {
    print('   ❌ Socket disconnected, using REST API fallback');
    // Fallback to REST API if socket is disconnected
    final result = await _apiService.sendMessage(widget.otherUserId, message);

    if (result['success']) {
      // Update message with real ID from server
      setState(() {
        final index = _messages.indexWhere((m) => m['id'] == tempId);
        if (index != -1) {
          _messages[index]['id'] = result['data']['id'];
          _messages[index]['status'] = 'sent';
        }
      });
    } else {
      // Mark message as failed
      setState(() {
        final index = _messages.indexWhere((m) => m['id'] == tempId);
        if (index != -1) {
          _messages[index]['status'] = 'failed';
        }
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['error'] ?? 'Failed to send message'),
            backgroundColor: Colors.red,
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: () {
                _retryMessage(tempId, message);
              },
            ),
          ),
        );
      }
    }
  }
}

Future<void> _retryMessage(String messageId, String message) async {
  print('🔄 Retrying message: $messageId');
  
  setState(() {
    final index = _messages.indexWhere((m) => m['id'] == messageId);
    if (index != -1) {
      _messages[index]['status'] = 'sending';
    }
  });

  if (_socketService.isConnected()) {
    _socketService.sendMessage(widget.otherUserId, message, messageId);
  } else {
    final result = await _apiService.sendMessage(widget.otherUserId, message);

    if (result['success']) {
      setState(() {
        final index = _messages.indexWhere((m) => m['id'] == messageId);
        if (index != -1) {
          _messages[index]['id'] = result['data']['id'];
          _messages[index]['status'] = 'sent';
        }
      });
    } else {
      setState(() {
        final index = _messages.indexWhere((m) => m['id'] == messageId);
        if (index != -1) {
          _messages[index]['status'] = 'failed';
        }
      });
    }
  }
}

  String _formatMessageTime(String? timestamp) {
    if (timestamp == null) return '';

    try {
      final date = DateTime.parse(timestamp);
      return DateFormat.jm().format(date);
    } catch (e) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: Colors.grey[300],
              backgroundImage: widget.recipientAvatar != null
                  ? NetworkImage(widget.recipientAvatar!)
                  : null,
              child: widget.recipientAvatar == null
                  ? Text(
                      widget.recipientName[0].toUpperCase(),
                      style: const TextStyle(fontSize: 16),
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                widget.recipientName,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Messages list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.chat_outlined,
                          size: 60,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No messages yet',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Say hi to start the conversation!',
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final message = _messages[index];
                      final isMe = message['senderId'] == _currentUserId;

                      return MessageBubble(
                        message: message['message'] ?? '',
                        isMe: isMe,
                        timestamp: _formatMessageTime(message['timestamp']),
                        status: message['status'],
                      );
                    },
                  ),
          ),

          // Message input
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 5,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      decoration: InputDecoration(
                        hintText: 'Type a message...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                      ),
                      maxLines: null,
                      textCapitalization: TextCapitalization.sentences,
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  CircleAvatar(
                    backgroundColor: Theme.of(context).primaryColor,
                    child: IconButton(
                      icon: _isSending
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.send, color: Colors.white),
                      onPressed: _isSending ? null : _sendMessage,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _socketService.leaveChat(widget.otherUserId);
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}

class MessageBubble extends StatelessWidget {
  final String message;
  final bool isMe;
  final String timestamp;
  final String? status;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isMe,
    required this.timestamp,
    this.status,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: isMe
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) const SizedBox(width: 40),
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isMe ? Theme.of(context).primaryColor : Colors.grey[200],
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isMe ? 16 : 4),
                  bottomRight: Radius.circular(isMe ? 4 : 16),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    message,
                    style: TextStyle(
                      color: isMe ? Colors.white : Colors.black87,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        timestamp,
                        style: TextStyle(
                          color: isMe ? Colors.white70 : Colors.grey[600],
                          fontSize: 11,
                        ),
                      ),
                      if (isMe && status == 'sending') ...[
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.access_time,
                          size: 12,
                          color: Colors.white70,
                        ),
                      ],
                      if (isMe && status == 'sent') ...[
                        const SizedBox(width: 4),
                        const Icon(Icons.done, size: 14, color: Colors.white70),
                      ],
                      if (isMe && status == 'delivered') ...[
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.done_all,
                          size: 14,
                          color: Colors.white70,
                        ),
                      ],
                      if (isMe && status == 'read') ...[
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.done_all,
                          size: 14,
                          color: Colors.lightBlueAccent,
                        ),
                      ],
                      if (isMe && status == 'failed') ...[
                        const SizedBox(width: 4),
                        Icon(
                          Icons.error_outline,
                          size: 14,
                          color: Colors.red[300],
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (isMe) const SizedBox(width: 40),
        ],
      ),
    );
  }
}
