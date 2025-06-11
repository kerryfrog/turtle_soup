import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ChatRoomPage extends StatefulWidget {
  final String roomId;
  final String roomName;
  const ChatRoomPage({super.key, required this.roomId, required this.roomName});

  @override
  State<ChatRoomPage> createState() => _ChatRoomPageState();
}

class _ChatRoomPageState extends State<ChatRoomPage> {
  final TextEditingController _controller = TextEditingController();

  void _sendMessage() {
    final text = _controller.text.trim();
    if (text.isNotEmpty) {
      FirebaseFirestore.instance
          .collection('rooms')
          .doc(widget.roomId)
          .collection('messages')
          .add({
        'text': text,
        'sender': '익명', // 나중에 사용자 이름으로 교체
        'timestamp': FieldValue.serverTimestamp(),
      });
      _controller.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.roomName)),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('rooms')
                  .doc(widget.roomId)
                  .collection('messages')
                  .orderBy('timestamp')
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData)
                  return const Center(child: CircularProgressIndicator());
                final messages = snapshot.data!.docs;
                return ListView(
                  padding: const EdgeInsets.all(8),
                  children: messages.map((doc) {
                    return ListTile(
                      title: Text(doc['text']),
                      subtitle: Text(doc['sender']),
                    );
                  }).toList(),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(hintText: '메시지 입력'),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: _sendMessage,
                ),
              ],
            ),
          )
        ],
      ),
    );
  }
}
