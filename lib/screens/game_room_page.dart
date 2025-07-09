import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class GameRoomPage extends StatefulWidget {
  final String roomId;
  final String gameId;
  const GameRoomPage({super.key, required this.roomId, required this.gameId});

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
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('rooms')
          .doc(widget.roomId)
          .collection('games')
          .doc(widget.gameId)
          .snapshots(),
      builder: (context, snapshot) {
        print('GameRoomPage: ${widget.roomId}, ${widget.gameId}');
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final data = snapshot.data!.data() as Map<String, dynamic>;
        final problemTitle = data['problemTitle'] ?? '게임 방';
        final problem = data['problemQuestion'] ?? '문제가 없습니다';
        final answer = data['problemAnswer'] ?? '정답이 없습니다';
        final hostUid = data['quizHostUid'];

        final currentUid = FirebaseAuth.instance.currentUser?.uid;
        final isHost = currentUid != null && hostUid == currentUid;

        return Scaffold(
          appBar: AppBar(title: Text(problemTitle)),
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('문제', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 4),
                    Text(problem),
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

                        // profileUrl 안전 처리
                        final profileUrl = message['profileUrl'];
                        final isValidProfileUrl = profileUrl is String && profileUrl.isNotEmpty;
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
                                  backgroundImage: isValidProfileUrl
                                      ? NetworkImage(profileUrl)
                                      : const AssetImage('default_profile.png'),
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
                        onSubmitted: (_) => _sendMessage(),
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
          floatingActionButton: isHost
              ? FloatingActionButton(
                  onPressed: () {
                    showModalBottomSheet(
                      context: context,
                      builder: (context) {
                        return Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                '정답',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(answer),
                            ],
                          ),
                        );
                      },
                    );
                  },
                  child: const Icon(Icons.security),
                )
              : null,
        );
      },
    );
  }
}
