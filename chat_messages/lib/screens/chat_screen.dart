import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
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
  StreamSubscription? _mqttSubscription;
  String? _errorMessage;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _loadSessionInfo();
    
    // Notify background that we are in a chat to suppress notifications
    FlutterBackgroundService().invoke('setActiveChat', {'userId': widget.otherUserId});

    // Listen for real-time messages via MQTT
    _mqttSubscription = FlutterBackgroundService().on('onMessage').listen((data) {
      print('UI Relay: onMessage received from background! Raw Data: ${jsonEncode(data)}');
      if (mounted && data != null) {
        final type = data['type'] ?? 'new_message';

        if (type == 'new_message') {
          final senderId = data['sender_id'];
          print('UI Relay: Processing new_message from sender: $senderId. Target user: ${widget.otherUserId}');
          if (senderId != null && senderId.toString() == widget.otherUserId.toString()) {
            setState(() {
              final messageId = data['id'];
              // Deduplicate: Don't add if ID already exists
              bool exists = _messages.any((m) => m['id'].toString() == messageId.toString());
              if (!exists) {
                print('UI Relay: Adding new message to list: $messageId');
                _messages.add({
                  'id': messageId,
                  'sender': senderId,
                  'content': data['content'],
                  'timestamp': data['timestamp'] ?? DateTime.now().toIso8601String(),
                  'is_read': false,
                  'is_delivered': true,
                });
                _scrollToBottom();
              } else {
                print('UI Relay: Message $messageId already exists in list, skipping.');
              }
            });
          }
        } else if (type == 'message_deleted') {
          final deletedId = data['message_id'];
          print('UI Relay: Processing message_deleted for ID: $deletedId');
          setState(() {
            _messages.removeWhere((m) => m['id'].toString() == deletedId.toString());
          });
        } else if (type == 'message_read') {
          final readId = data['message_id'];
          print('UI Relay: Processing message_read for ID: $readId');
          setState(() {
            final index = _messages.indexWhere((m) => m['id'].toString() == readId.toString());
            if (index != -1) {
              _messages[index]['is_read'] = true;
            }
          });
        } else if (type == 'message_delivered') {
          final deliveredId = data['message_id'];
          print('UI Relay: Processing message_delivered for ID: $deliveredId');
          setState(() {
            final index = _messages.indexWhere((m) => m['id'].toString() == deliveredId.toString());
            if (index != -1) {
              _messages[index]['is_delivered'] = true;
            }
          });
        }
        print('Chat: Successfully processed MQTT $type update.');
      }
    });
  }

  @override
  void dispose() {
    // Notify background we left the chat
    FlutterBackgroundService().invoke('setActiveChat', {'userId': null});
    _mqttSubscription?.cancel();
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
            _errorMessage = null;
            // Only scroll if message count increased
            if (newMessages.length > _messages.length) {
              _messages = newMessages;
              _scrollToBottom();
            } else {
              _messages = newMessages; // Update content anyway (e.g. read receipts)
            }
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _errorMessage = 'Failed to load messages (Status: ${response.statusCode})';
          });
        }
      }
    } catch (e) {
      print('Error fetching history: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Connection error: $e';
        });
      }
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
    if (text.isEmpty || _token == null || _isSending) return;

    final tempId = DateTime.now().millisecondsSinceEpoch;
    final tempMessage = {
      'id': tempId,
      'sender': _myId,
      'content': text,
      'timestamp': DateTime.now().toIso8601String(),
      'is_read': false,
      'is_delivered': false,
      'is_optimistic': true, // Flag for temporary message
    };

    setState(() {
      _isSending = true;
      _messages.add(tempMessage);
      _scrollToBottom();
    });

    _controller.clear();

    try {
      final response = await http.post(
        Uri.parse('${ApiConstants.baseUrl}/messages/'),
        headers: {
          'Authorization': 'Token $_token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'receiver': widget.otherUserId,
          'content': text,
        }),
      );

      if (response.statusCode == 201) {
        final realMessage = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            final index = _messages.indexWhere((m) => m['id'] == tempId);
            if (index != -1) {
              _messages[index] = realMessage;
            }
          });
        }
      } else {
         throw Exception('Failed to send');
      }
    } catch (e) {
      print('Send error: $e');
      if (mounted) {
        setState(() {
          _messages.removeWhere((m) => m['id'] == tempId);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to send message'), duration: Duration(seconds: 2)),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _markAsRead(int messageId) async {
    if (_token == null) return;
    try {
      await http.patch(
        Uri.parse('${ApiConstants.baseUrl}/messages/$messageId/read/'),
        headers: {
          'Authorization': 'Token $_token',
          'Content-Type': 'application/json',
        },
      );
    } catch (e) {
      print('Error marking as read: $e');
    }
  }

  Future<void> _deleteMessage(int messageId) async {
    if (_token == null) return;
    try {
      final response = await http.delete(
        Uri.parse('${ApiConstants.baseUrl}/messages/$messageId/delete/'),
        headers: {
          'Authorization': 'Token $_token',
        },
      );

      if (response.statusCode == 204) {
        setState(() {
          _messages.removeWhere((m) => m['id'] == messageId);
        });
      }
    } catch (e) {
      print('Error deleting message: $e');
    }
  }

  void _showDeleteMenu(BuildContext context, Offset tapPosition, int messageId) {
    final RenderBox overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    
    showMenu(
      context: context,
      position: RelativeRect.fromRect(
        tapPosition & const Size(40, 40), // smaller rect, the tap position
        Offset.zero & overlay.size,   // Entire screen
      ),
      items: [
        const PopupMenuItem(
          value: 'delete',
          child: Row(
            children: [
              Icon(Icons.delete_outline, color: Colors.redAccent),
              SizedBox(width: 8),
              Text('Delete for everyone', style: TextStyle(color: Colors.redAccent)),
            ],
          ),
        ),
      ],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ).then((value) {
      if (value == 'delete') {
        _deleteMessage(messageId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        automaticallyImplyLeading: false, // Remove default back button
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            CircleAvatar(
              radius: 16,
              child: Text(widget.otherUsername[0].toUpperCase()),
            ),
            const SizedBox(width: 10),
            Text(widget.otherUsername, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        elevation: 1,
      ),
      body: Column(
        children: [
          Expanded(
            child: _isLoading 
              ? const Center(child: CircularProgressIndicator())
              : _errorMessage != null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline, size: 48, color: Colors.red[300]),
                        const SizedBox(height: 16),
                        Text(
                          _errorMessage!,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey[700]),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _fetchHistory,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                  controller: _scrollController,
                  itemCount: _messages.length,
                  itemBuilder: (context, index) {
                    final msg = _messages[index];
                    final isMe = msg['sender'].toString() == _myId.toString();
                    final isRead = msg['is_read'] ?? false;

                    // Mark as read if not me and not read
                    if (!isMe && !isRead) {
                      _markAsRead(msg['id']);
                      msg['is_read'] = true; // Local update
                    }

                    Offset? tapPosition;

                    return GestureDetector(
                      onTapDown: (details) => tapPosition = details.globalPosition,
                      onLongPress: isMe ? () {
                        if (tapPosition != null) {
                          _showDeleteMenu(context, tapPosition!, msg['id']);
                        }
                      } : null,
                      child: Align(
                        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                        child: Column(
                          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                          children: [
                            Container(
                              constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                              margin: const EdgeInsets.symmetric(vertical: 2, horizontal: 8),
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
                                msg['content'] ?? "",
                                style: TextStyle(
                                  color: isMe ? Colors.white : Colors.black87,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                            if (isMe)
                              Padding(
                                padding: const EdgeInsets.only(right: 12, bottom: 4),
                                child: Icon(
                                  isRead ? Icons.done_all : (msg['is_delivered'] == true ? Icons.done_all : Icons.check),
                                  size: 14,
                                  color: isRead ? Colors.blue : (msg['is_delivered'] == true ? Colors.grey : Colors.grey.withOpacity(0.5)),
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(24),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: TextField(
                      controller: _controller,
                      decoration: const InputDecoration(
                        hintText: "Aa",
                        border: InputBorder.none,
                      ),
                    ),
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
