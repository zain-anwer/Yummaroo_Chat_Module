import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'api_service.dart';

class SocketService {
  static final SocketService _instance = SocketService._internal();
  factory SocketService() => _instance;
  SocketService._internal();

  IO.Socket? socket;
  final ApiService _apiService = ApiService();

  // Callbacks for real-time events
  Function(Map<String, dynamic>)? onMessageReceived;
  Function(String)? onUserTyping;
  Function()? onConnected;
  Function()? onDisconnected;

  // Connect to Socket.IO server
  Future<void> connect() async {
    final token = await _apiService.getToken();

    if (token == null) {
      print('❌ No auth token found');
      return;
    }

    print('🔐 Token found: ${token.substring(0, 30)}...');

    // ✅ FIX: Use extraHeaders in the correct format
    socket = IO.io(
      'http://192.168.100.16:3000',
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect() // ✅ Changed to manual connect
          .setQuery({'token': token}) 
          .build(),
    );

    // Connect manually AFTER setting up listeners
    socket?.connect();

    // Connection events
    socket?.onConnect((_) {
      print('✅ Connected to socket server');
      print('   Socket ID: ${socket?.id}');
      onConnected?.call();
    });

    socket?.onDisconnect((reason) {
      print('❌ Disconnected from socket server');
      print('   Reason: $reason');
      onDisconnected?.call();
    });

    socket?.onConnectError((error) {
      print('🔴 Connection error: $error');
    });

    // Log all events
    socket?.onAny((event, data) {
      print('📡 Socket event: $event');
      print('   Data: $data');
    });

    // Listen for new messages
    socket?.on('new_message', (data) {
      print('📨 New message received: $data');
      onMessageReceived?.call(data as Map<String, dynamic>);
    });

    socket?.on('message_delivered', (data) {
      print('✅ Message delivered: $data');
    });

    socket?.on('message_failed', (data) {
      print('❌ Message failed: $data');
    });
  }

  // Join chat with specific user
  void joinChat(String otherUserId) {
    socket?.emit('join_chat', {'otherUserId': otherUserId});
  }

  void sendMessage(String receiverId, String message, [String? tempId]) {
  print('\n📤 Sending message via socket...');
  print('   receiverId: $receiverId');
  print('   message: $message');
  print('   tempId: $tempId');
  print('   socket connected: ${socket?.connected}');

  socket?.emit('send_message', {
    'receiverId': receiverId,
    'message': message,
    'timestamp': DateTime.now().toIso8601String(),
    'tempId': tempId,  // ✅ Include tempId
  });

  print('✅ Message emitted to server');
}

  // Mark messages as read
  void markAsRead(String otherUserId) {
    socket?.emit('open_chat', {'otherUserId': otherUserId});
  }

  // Leave a chat room - FIX THE PARAMETER NAME

  void leaveChat(String otherUserId) {
    // Changed parameter name
    socket?.emit('leave_chat', {'otherUserId': otherUserId}); // ✅ Correct key
  }

  // Send typing indicator
  void sendTypingIndicator(String chatId, bool isTyping) {
    socket?.emit('typing', {'chatId': chatId, 'isTyping': isTyping});
  }

  // Disconnect socket
  void disconnect() {
    socket?.disconnect();
    socket?.dispose();
  }

  // Check if connected
  bool isConnected() {
    return socket?.connected ?? false;
  }
}
