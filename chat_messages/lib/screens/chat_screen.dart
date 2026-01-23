import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/mqtt_service.dart';

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

  @override
  void initState() {
    super.initState();
    _loadSessionInfo();
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
        Uri.parse('http://10.0.2.2:8000/api/messages/?user_id=${widget.otherUserId}'),
        headers: {
          'Authorization': 'Token $_token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        setState(() {
          _messages = jsonDecode(response.body);
          _isLoading = false;
        });
        _scrollToBottom();
      }
    } catch (e) {
      print('Error fetching history: $e');
      setState(() => _isLoading = false);
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
        Uri.parse('http://10.0.2.2:8000/api/messages/'),
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
                    final isMe = msg['sender'] == _myId;
                    return Align(
                      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                        decoration: BoxDecoration(
                          color: isMe ? Colors.deepPurple : Colors.grey[300],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          msg['content'],
                          style: TextStyle(color: isMe ? Colors.white : Colors.black),
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