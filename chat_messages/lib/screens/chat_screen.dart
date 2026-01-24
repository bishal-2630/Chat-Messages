import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/mqtt_service.dart';
import '../constants.dart';

class ChatScreen extends StatefulWidget {
  final int otherUserId;
  final String otherUsername;

  const ChatScreen({super.key, required this.otherUserId, required this.otherUsername});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  List<dynamic> _messages = [];
  bool _isLoading = true;
  int? _myId;
  String? _token;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _loadSessionInfo();
    // Poll for new messages every 3 seconds
    _timer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (!_isLoading) {
        _fetchHistory();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadSessionInfo() async {
    final prefs = await SharedPreferences.getInstance();

    setState(() {
      _myId = prefs.getInt('user_id');
      _token = prefs.getString('auth_token');
    });
    _fetchHistory();
  }

  Future<void> _fetchHistory() async {
    if (_token == null) return;
    try {
      final response = await http.get(
        Uri.parse('${ApiConstants.baseUrl}/messages/?user_id=${widget.otherUserId}'),
        headers: {
          'Authorization': 'Token $_token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final newMessages = jsonDecode(response.body);
        if (mounted) {
           setState(() {
            _isLoading = false;
            // Only scroll if message count increased
            if (newMessages.length > _messages.length) {
              _messages = newMessages;
              _scrollToBottom();
            } else {
              _messages = newMessages; // Update content anyway (e.g. read receipts)
            }
          });
        }
      }
    } catch (e) {
      print('Error fetching history: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _token == null) return;

    final messageData = {
      'receiver': widget.otherUserId,
      'content': text,
    };

    _controller.clear();

    try {
      // 1. Save to Backend
      final response = await http.post(
        Uri.parse('${ApiConstants.baseUrl}/messages/'),
        headers: {
          'Authorization': 'Token $_token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(messageData),
      );

      if (response.statusCode == 201) {
        // 2. Local Update
        _fetchHistory();
        
        // 3. Optional: Send via MQTT for instant delivery if receiver is listening
        // This usually happens server-side with Django Channels, 
        // but for your MQTT setup, you can publish here.
      }
    } catch (e) {
      print('Send error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.otherUsername)),
      body: Column(
        children: [
          Expanded(
            child: _isLoading 
              ? const Center(child: CircularProgressIndicator())
              : ListView.builder(
                  controller: _scrollController,
                  itemCount: _messages.length,
                  itemBuilder: (context, index) {
                    final msg = _messages[index];
                    final isMe = msg['sender'].toString() == _myId.toString();
                    
                    // DEBUG: Check why alignment might be wrong
                    if (index == 0) { // Print only once per render to avoid spam
                       print('DEBUG: My ID: $_myId'); 
                       print('DEBUG: Msg Sender: ${msg['sender']} (isMe: $isMe)');
                    }

                    return Align(
                      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                        decoration: BoxDecoration(
                          color: isMe ? Colors.deepPurple : Colors.grey[200],
                          borderRadius: BorderRadius.only(
                            topLeft: const Radius.circular(16),
                            topRight: const Radius.circular(16),
                            bottomLeft: isMe ? const Radius.circular(16) : Radius.zero,
                            bottomRight: isMe ? Radius.zero : const Radius.circular(16),
                          ),
                        ),
                        child: Text(
                          msg['content'],
                          style: TextStyle(
                            color: isMe ? Colors.white : Colors.black87,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    );
                  },
                ),
          ),
          Container(
            padding: const EdgeInsets.all(8.0),
            decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)]),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(hintText: "Type a message...", border: InputBorder.none),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send, color: Colors.deepPurple),
                  onPressed: _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}