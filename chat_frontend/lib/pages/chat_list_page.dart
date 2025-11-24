import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../services/socket_service.dart';
import 'chat_detail_page.dart';
import 'login_page.dart';

class ChatListPage extends StatefulWidget {
  const ChatListPage({super.key});

  @override
  State<ChatListPage> createState() => _ChatListPageState();
}

class _ChatListPageState extends State<ChatListPage> {
  final ApiService _apiService = ApiService();
  final SocketService _socketService = SocketService();
  
  List<Map<String, dynamic>> _chats = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initializeChat();
  }

  Future<void> _initializeChat() async {
    // Connect to socket
    await _socketService.connect();
    
    // Set up socket listeners
    _socketService.onMessageReceived = (message) {
      // Update chat list when new message arrives
      _loadChats();
    };
    
    // Load chats
    await _loadChats();
  }

  Future<void> _loadChats() async {
    setState(() => _isLoading = true);
    
    final result = await _apiService.getChatList();
    
    if (result['success']) {
      setState(() {
        _chats = List<Map<String, dynamic>>.from(result['data']['chats'] ?? []);
        _isLoading = false;
      });
    } else {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['error'] ?? 'Failed to load chats')),
        );
      }
    }
  }

  Future<void> _handleLogout() async {
    _socketService.disconnect();
    await _apiService.clearToken();
    
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginPage()),
      );
    }
  }

  String _formatTimestamp(String? timestamp) {
    if (timestamp == null) return '';
    
    try {
      final date = DateTime.parse(timestamp);
      final now = DateTime.now();
      final difference = now.difference(date);
      
      if (difference.inDays == 0) {
        return DateFormat.jm().format(date); // e.g., "2:30 PM"
      } else if (difference.inDays == 1) {
        return 'Yesterday';
      } else if (difference.inDays < 7) {
        return DateFormat.E().format(date); // e.g., "Mon"
      } else {
        return DateFormat.MMMd().format(date); // e.g., "Jan 15"
      }
    } catch (e) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chats'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _handleLogout,
            tooltip: 'Logout',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _chats.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.chat_bubble_outline,
                        size: 80,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No chats yet',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Start sharing food to begin chatting!',
                        style: TextStyle(
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadChats,
                  child: ListView.builder(
                    itemCount: _chats.length,
                    itemBuilder: (context, index) {
                      final chat = _chats[index];
                      return ChatListTile(
                        chat: chat,
                        onTap: () async {
                          // Navigate and reload chats when returning
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ChatDetailPage(
                                otherUserId: chat['id'] ?? chat['_id'],  // Changed to otherUserId
                                recipientName: chat['recipientName'] ?? 'User',
                                recipientAvatar: chat['recipientAvatar'],
                              ),
                            ),
                          );
                          // Reload chats when returning from chat detail
                          _loadChats();
                        },
                        formatTimestamp: _formatTimestamp,
                      );
                    },
                  ),
                ),
    );
  }

  @override
  void dispose() {
    _socketService.disconnect();
    super.dispose();
  }
}

class ChatListTile extends StatelessWidget {
  final Map<String, dynamic> chat;
  final VoidCallback onTap;
  final String Function(String?) formatTimestamp;

  const ChatListTile({
    super.key,
    required this.chat,
    required this.onTap,
    required this.formatTimestamp,
  });

  @override
  Widget build(BuildContext context) {
    final unreadCount = chat['unreadCount'] ?? 0;
    final lastMessage = chat['lastMessage'] ?? 'No messages yet';
    final recipientName = chat['recipientName'] ?? 'User';
    final recipientAvatar = chat['recipientAvatar'];
    final timestamp = chat['lastMessageTime'];

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: Colors.grey[200]!),
          ),
        ),
        child: Row(
          children: [
            // Avatar
            CircleAvatar(
              radius: 28,
              backgroundColor: Colors.grey[300],
              backgroundImage: recipientAvatar != null
                  ? NetworkImage(recipientAvatar)
                  : null,
              child: recipientAvatar == null
                  ? Text(
                      recipientName[0].toUpperCase(),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            
            // Chat info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        recipientName,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: unreadCount > 0
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                      Text(
                        formatTimestamp(timestamp),
                        style: TextStyle(
                          fontSize: 12,
                          color: unreadCount > 0
                              ? Theme.of(context).primaryColor
                              : Colors.grey[600],
                          fontWeight: unreadCount > 0
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          lastMessage,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            color: unreadCount > 0
                                ? Colors.black87
                                : Colors.grey[600],
                            fontWeight: unreadCount > 0
                                ? FontWeight.w500
                                : FontWeight.normal,
                          ),
                        ),
                      ),
                      if (unreadCount > 0)
                        Container(
                          margin: const EdgeInsets.only(left: 8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Theme.of(context).primaryColor,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            unreadCount.toString(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}