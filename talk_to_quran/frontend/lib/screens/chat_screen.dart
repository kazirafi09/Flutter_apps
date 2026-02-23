import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class ChatMessage {
  final String text;
  final bool isUser;
  ChatMessage({required this.text, required this.isUser});
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  final List<ChatMessage> _messages = [];
  bool _isLoading = false;
  bool _showScrollToBottomBtn = false;

  final String _apiUrl = 'http://192.168.0.107:8000/chat';

  final Map<String, String> _systemPrompt = {
    "role": "system",
    "content":
        "You are an expert Quranic assistant. Always ground your answer in the provided Quranic context. Cite Surah and Ayah clearly.",
  };

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      if (_scrollController.offset > 200 && !_showScrollToBottomBtn) {
        setState(() => _showScrollToBottomBtn = true);
      } else if (_scrollController.offset <= 200 && _showScrollToBottomBtn) {
        setState(() => _showScrollToBottomBtn = false);
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    _scrollController.animateTo(
      0.0,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  Future<void> _animateBotResponse(String fullText) async {
    String currentText = "";

    setState(() {
      _messages.insert(0, ChatMessage(text: "", isUser: false));
    });

    final words = fullText.split(" ");

    for (int i = 0; i < words.length; i++) {
      await Future.delayed(const Duration(milliseconds: 40));
      currentText += "${words[i]} ";
      setState(() {
        _messages[0] = ChatMessage(text: currentText, isUser: false);
      });
    }
  }

  Future<void> _sendMessage() async {
    if (_controller.text.trim().isEmpty) return;

    final userText = _controller.text.trim();
    _controller.clear();

    if (_showScrollToBottomBtn) {
      _scrollToBottom();
    }

    setState(() {
      _messages.insert(0, ChatMessage(text: userText, isUser: true));
      _isLoading = true;
    });

    List<Map<String, String>> historyForApi = [_systemPrompt];

    for (var msg in _messages.reversed.skip(1)) {
      historyForApi.add({
        "role": msg.isUser ? "user" : "assistant",
        "content": msg.text,
      });
    }

    try {
      final response = await http.post(
        Uri.parse(_apiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'question': userText,
          'history': historyForApi,
        }),
      );

      setState(() => _isLoading = false);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        await _animateBotResponse(data['answer']);
      } else {
        setState(() {
          _messages.insert(
              0,
              ChatMessage(
                  text: "Server Error (${response.statusCode}). Check backend logs.",
                  isUser: false));
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
      setState(() {
        _messages.insert(
            0,
            ChatMessage(
                text: "Network Error. Make sure backend is running and IP is correct.",
                isUser: false));
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: 0.8), // Updated
                Colors.transparent,
              ],
            ),
          ),
        ),
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.menu_book_rounded, color: Color(0xFFD4AF37)),
            SizedBox(width: 8),
            Text(
              'Quran AI',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF0F2027),
              Color(0xFF203A43),
              Color(0xFF132A20),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: Stack(
                  children: [
                    _messages.isEmpty
                        ? _buildEmptyState()
                        : ListView.builder(
                            controller: _scrollController,
                            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
                            reverse: true,
                            itemCount: _messages.length,
                            itemBuilder: (context, index) {
                              return _buildChatBubble(_messages[index]);
                            },
                          ),
                    Positioned(
                      bottom: 16.0,
                      right: 16.0,
                      child: AnimatedScale(
                        scale: _showScrollToBottomBtn ? 1.0 : 0.0,
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeOutBack,
                        child: FloatingActionButton(
                          mini: true,
                          backgroundColor: const Color(0xFF132A20),
                          foregroundColor: const Color(0xFFD4AF37),
                          elevation: 4,
                          onPressed: _scrollToBottom,
                          child: const Icon(Icons.keyboard_arrow_down_rounded, size: 28),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (_isLoading) _buildLoadingIndicator(),
              _buildMessageInput(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.mosque_rounded, size: 80, color: Colors.white.withValues(alpha: 0.2)), // Updated
          const SizedBox(height: 16),
          Text(
            "Peace be upon you",
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w600,
              color: Colors.white.withValues(alpha: 0.7), // Updated
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Ask me any question about the Quran.",
            style: TextStyle(
              fontSize: 16,
              color: Colors.white.withValues(alpha: 0.5), // Updated
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatBubble(ChatMessage message) {
    return Align(
      alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12.0),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.8,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 14.0),
        decoration: BoxDecoration(
          color: message.isUser ? const Color(0xFFD4AF37) : const Color(0xFF1E3C31),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(20),
            topRight: const Radius.circular(20),
            bottomLeft: Radius.circular(message.isUser ? 20 : 0),
            bottomRight: Radius.circular(message.isUser ? 0 : 20),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2), // Updated
              blurRadius: 5,
              offset: const Offset(0, 3),
            )
          ],
        ),
        child: Text(
          message.text,
          style: TextStyle(
            color: message.isUser ? Colors.black87 : Colors.white,
            fontSize: 16,
            height: 1.4,
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(left: 16.0, bottom: 12.0),
        padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 14.0),
        decoration: const BoxDecoration(
          color: Color(0xFF1E3C31),
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
            bottomLeft: Radius.circular(0),
            bottomRight: Radius.circular(20),
          ),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 15,
              height: 15,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Color(0xFFD4AF37),
              ),
            ),
            SizedBox(width: 12),
            Text(
              "Reflecting...",
              style: TextStyle(color: Colors.white70, fontSize: 14),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.2), // Updated
        border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.1))), // Updated
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              style: const TextStyle(color: Colors.white),
              textCapitalization: TextCapitalization.sentences,
              enabled: !_isLoading,
              minLines: 1,
              maxLines: 3,
              keyboardType: TextInputType.multiline,
              decoration: InputDecoration(
                hintText: 'Ask about the Quran...',
                hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5)), // Updated
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.05), // Updated
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24.0),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: _isLoading ? null : _sendMessage,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(bottom: 2),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _isLoading ? Colors.grey[700] : const Color(0xFFD4AF37),
                shape: BoxShape.circle,
                boxShadow: _isLoading
                    ? []
                    : [
                        BoxShadow(
                          color: const Color(0xFFD4AF37).withValues(alpha: 0.4), // Updated
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        )
                      ],
              ),
              child: const Icon(
                Icons.send_rounded,
                color: Colors.black87,
                size: 24,
              ),
            ),
          ),
        ],
      ),
    );
  }
}