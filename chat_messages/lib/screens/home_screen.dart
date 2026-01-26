import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_background_service/flutter_background_service.dart';
import '../constants.dart';
import 'chat_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  List<ChatUser> _users = [];
  bool _isLoading = true;
  String? _currentUserUsername;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadCurrentUser();
    _fetchUsers();
    _setupMessageListener();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      print('UI: App resumed. Refreshing background connectivity...');
      FlutterBackgroundService().invoke('refresh');
      _fetchUsers(); // Also refresh user list
    }
  }

  void _setupMessageListener() {
    FlutterBackgroundService().on('onMessage').listen((data) {
      if (data == null) return;
      final type = data['type'] ?? 'new_message';

      if (type == 'new_message') {
        final senderId = data['sender_id'];
        final String content = data['content'] ?? "";
        final String timestamp = data['timestamp'] ?? DateTime.now().toIso8601String();

        if (mounted) {
          setState(() {
            final userIndex = _users.indexWhere((u) => u.id.toString() == senderId.toString());
            if (userIndex != -1) {
              final user = _users[userIndex];
              user.lastMessage = content;
              user.unreadCount++;
              user.lastTimestamp = DateTime.parse(timestamp);
              
              // Move user to top (Messenger style reordering)
              _users.removeAt(userIndex);
              _users.insert(0, user);
            }
          });
        }
      }
    });
  }

  Future<void> _loadCurrentUser() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _currentUserUsername = prefs.getString('username') ?? 'Me';
    });
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    if (mounted) {
      Navigator.pushReplacementNamed(context, '/');
    }
  }

  Future<void> _fetchUsers() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');

    try {
      final response = await http.get(
        Uri.parse('${ApiConstants.baseUrl}/users/'),
        headers: {
          'Authorization': 'Token $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        setState(() {
          _users = data.map((json) => ChatUser.fromJson(json)).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching users: $e');
      setState(() { _isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: const Text(
            'Chats',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24),
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'logout') _logout();
                },
                offset: const Offset(0, 50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                child: CircleAvatar(
                  backgroundColor: Colors.deepPurple.shade100,
                  child: Text(
                    _currentUserUsername?[0].toUpperCase() ?? '?',
                    style: const TextStyle(color: Colors.deepPurple, fontWeight: FontWeight.bold),
                  ),
                ),
                itemBuilder: (context) => [
                  PopupMenuItem(
                    enabled: false,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Signed in as',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                        ),
                        Text(
                          _currentUserUsername ?? 'User',
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
                        ),
                        const Divider(),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'logout',
                    child: Row(
                      children: [
                        Icon(Icons.logout, color: Colors.redAccent, size: 20),
                        SizedBox(width: 12),
                        Text('Logout', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _fetchUsers,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  itemCount: _users.length,
                  separatorBuilder: (context, index) => const Divider(height: 1, indent: 80, color: Color(0xFFEEEEEE)),
                  itemBuilder: (context, index) {
                    final user = _users[index];
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      leading: Stack(
                        children: [
                          CircleAvatar(
                            radius: 28,
                            backgroundColor: Colors.grey.shade200,
                            child: Text(
                              user.username[0].toUpperCase(),
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                          ),
                          if (user.isOnline)
                            Positioned(
                              right: 0,
                              bottom: 0,
                              child: Container(
                                width: 16,
                                height: 16,
                                decoration: BoxDecoration(
                                  color: Colors.green,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 2),
                                ),
                              ),
                            ),
                        ],
                      ),
                      title: Text(
                        user.username,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      subtitle: Text(
                        user.lastMessage.isNotEmpty ? user.lastMessage : (user.isOnline ? 'Active now' : 'Yesterday'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: user.unreadCount > 0 ? Colors.black : Colors.grey.shade600,
                          fontWeight: user.unreadCount > 0 ? FontWeight.bold : FontWeight.normal,
                          fontSize: 13,
                        ),
                      ),
                      trailing: user.unreadCount > 0 
                        ? Container(
                            padding: const EdgeInsets.all(8),
                            decoration: const BoxDecoration(
                              color: Colors.deepPurple,
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              '${user.unreadCount}',
                              style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          )
                        : null,
                      onTap: () async {
                        setState(() {
                          user.unreadCount = 0; // Clear locally when entering
                        });
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ChatScreen(
                              otherUserId: user.id,
                              otherUsername: user.username,
                            ),
                          ),
                        );
                        _fetchUsers(); // Refresh on return to sync read state
                      },
                    );
                  },
                ),
              ),
      ),
    );
  }
}

class ChatUser {
  final int id;
  final String username;
  final bool isOnline;
  String lastMessage;
  int unreadCount;
  DateTime? lastTimestamp;

  ChatUser({
    required this.id, 
    required this.username, 
    required this.isOnline,
    this.lastMessage = "",
    this.unreadCount = 0,
    this.lastTimestamp,
  });

  factory ChatUser.fromJson(Map<String, dynamic> json) {
    return ChatUser(
      id: json['id'],
      username: json['username'],
      isOnline: json['profile']?['is_online'] ?? false,
      lastMessage: json['last_message']?['content'] ?? "", // Assuming backend sends this (optional)
      unreadCount: json['unread_count'] ?? 0,
      lastTimestamp: json['last_message']?['timestamp'] != null 
          ? DateTime.parse(json['last_message']['timestamp'])
          : null,
    );
  }
}
