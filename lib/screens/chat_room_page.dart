import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ChatRoomPage extends StatefulWidget {
  final String roomId;
  final String roomName;
  const ChatRoomPage({super.key, required this.roomId, required this.roomName});

  @override
  State<ChatRoomPage> createState() => _ChatRoomPageState();
}

class _ChatRoomPageState extends State<ChatRoomPage> {
  final TextEditingController _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      FirebaseFirestore.instance
          .collection('rooms')
          .doc(widget.roomId)
          .update({
            'participants': FieldValue.arrayUnion([uid]),
          });
    }
  }

  @override
  void dispose() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      FirebaseFirestore.instance
          .collection('rooms')
          .doc(widget.roomId)
          .update({
            'participants': FieldValue.arrayRemove([uid]),
          });
    }
    super.dispose();
  }

  Future<void> _startGame() async {
    final problemSnapshot = await FirebaseFirestore.instance
        .collection('problems')
        .get();
    final problemDocs = problemSnapshot.docs;
    problemDocs.shuffle();
    final selectedProblem = problemDocs.first.data();

    final roomRef = FirebaseFirestore.instance
        .collection('rooms')
        .doc(widget.roomId);
    final roomDoc = await roomRef.get();
    final participants = List<String>.from(roomDoc.data()?['participants'] ?? []);
    participants.shuffle();
    final quizHostUid = participants.isNotEmpty ? participants.first : null;

    final newGameDoc = roomRef.collection('games').doc();
    await newGameDoc.set({
      'createdAt': FieldValue.serverTimestamp(),
      'problemTitle': selectedProblem['title'],
      'problemQuestion': selectedProblem['question'],
      'problemAnswer': selectedProblem['answer'],
      'quizHostUid': quizHostUid,
    });

    final newGameId = newGameDoc.id;

    await roomRef.update({
      'currentGameId': newGameId,
      'isGameActive' : true,
    });

    Navigator.pushNamed(
      context,
      '/game_room',
      arguments: {
        'roomId': widget.roomId,
        'gameId': newGameId,
      },
    );
  }

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
    final profileUrl = userDoc.data()?['profileUrl'] ??
        'https://via.placeholder.com/150';

    final roomDoc = await FirebaseFirestore.instance
        .collection('rooms')
        .doc(widget.roomId)
        .get();
    final currentGameId = roomDoc.data()?['currentGameId'];
    if (currentGameId == null) {
      await FirebaseFirestore.instance
          .collection('rooms')
          .doc(widget.roomId)
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
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.roomName),
        actions: [
          FutureBuilder<DocumentSnapshot>(
            future: FirebaseFirestore.instance
                .collection('rooms')
                .doc(widget.roomId)
                .get(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return SizedBox.shrink();
              final data = snapshot.data!.data() as Map<String, dynamic>;
              final isOwner = data['roomOwnerUid'] == FirebaseAuth.instance.currentUser?.uid;
              return isOwner
                  ? IconButton(
                      icon: const Icon(Icons.play_arrow),
                      tooltip: '게임 시작',
                      onPressed: _startGame,
                    )
                  : SizedBox.shrink();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance
                .collection('rooms')
                .doc(widget.roomId)
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return SizedBox.shrink();

              final roomData = snapshot.data!.data() as Map<String, dynamic>;
              final gameId = roomData['currentGameId'];

              if (gameId != null) {
                Future.microtask(() {
                  Navigator.pushReplacementNamed(
                    context,
                    '/game_room',
                    arguments: {
                      'roomId': widget.roomId,
                      'gameId': gameId,
                    },
                  );
                });
              }

              return SizedBox.shrink();
            },
          ),
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
                    final message = doc.data() as Map<String, dynamic>;
                    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
                    final isMine = message['uid'] == currentUserId;

                    return Align(
                      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
                      child: Row(
                        mainAxisAlignment:
                            isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (!isMine)
                            CircleAvatar(
                              radius: 16,
                              backgroundImage: message['profileUrl'] != null
                                  ? NetworkImage(message['profileUrl'])
                                  : const AssetImage('default_profile.png')
                                      as ImageProvider,
                            ),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment:
                                isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                            children: [
                              Text(
                                message['sender'] ?? '',
                                style: const TextStyle(fontSize: 12, color: Colors.black87),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.all(10),
                                constraints: const BoxConstraints(maxWidth: 250),
                                decoration: BoxDecoration(
                                  color: isMine ? Colors.blue[100] : Colors.grey[300],
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
          )
        ],
      ),
    );
  }
}