import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class GameRoomPage extends StatefulWidget {
  final String roomId;
  final String roomName;
  final String gameId;
  const GameRoomPage({super.key, required this.roomId, required this.roomName, required this.gameId});

  @override
  State<GameRoomPage> createState() => _GameRoomPageState();
}

class _GameRoomPageState extends State<GameRoomPage> {
  final TextEditingController _controller = TextEditingController();

  void _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    final nickname = userDoc.data()?['nickname'] ?? '익명';
    final profileUrl =
        userDoc.data()?['profileUrl'] ?? 'https://via.placeholder.com/150';

      await FirebaseFirestore.instance
        .collection('rooms')
        .doc(widget.roomId)
        .collection('games')
        .doc(widget.gameId)
        .collection('messages')
        .add({
          'text': text,
          'sender': nickname,
          'uid': user.uid,
          'profileUrl': profileUrl,
          'timestamp': FieldValue.serverTimestamp(),
        });

    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final question = args?['question'] ?? '문제가 없습니다';
    final answer = args?['answer'] ?? '정답이 없습니다';
    return Scaffold(
      appBar: AppBar(title: Text(widget.roomName)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('문제', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 4),
                Text(question),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('rooms')
                  .doc(widget.roomId)
                  .collection('games')
                  .doc(widget.gameId)
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
                    final message = doc.data() as Map<String, dynamic>;
                    final currentUserId =
                        FirebaseAuth.instance.currentUser?.uid;
                    final isMine = message['uid'] == currentUserId;

                    return Align(
                      alignment: isMine
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Row(
                        mainAxisAlignment: isMine
                            ? MainAxisAlignment.end
                            : MainAxisAlignment.start,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (!isMine)
                            CircleAvatar(
                              radius: 16,
                              backgroundImage: message['profileUrl'] != null
                                  ? NetworkImage(message['profileUrl'])
                                  : const AssetImage(
                                          'default_profile.png',
                                        )
                                        as ImageProvider,
                            ),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: isMine
                                ? CrossAxisAlignment.end
                                : CrossAxisAlignment.start,
                            children: [
                              Text(
                                message['sender'] ?? '',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.all(10),
                                constraints: const BoxConstraints(
                                  maxWidth: 250,
                                ),
                                decoration: BoxDecoration(
                                  color: isMine
                                      ? Colors.blue[100]
                                      : Colors.grey[300],
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  message['text'] ?? '',
                                  style: const TextStyle(fontSize: 16),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
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
          ),
        ],
      ),
    );
  }
}
