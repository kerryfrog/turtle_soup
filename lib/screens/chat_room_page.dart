import 'package:turtle_soup/widgets/message_composer.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:turtle_soup/widgets/message_bubble.dart';

class ChatRoomPage extends StatefulWidget {
  final String roomId;
  const ChatRoomPage({super.key, required this.roomId});

  @override
  State<ChatRoomPage> createState() => _ChatRoomPageState();
}

class _ChatRoomPageState extends State<ChatRoomPage> {
  final TextEditingController _controller = TextEditingController();
  String _roomName = '채팅방'; // Default room name

  @override
  void initState() {
    super.initState();
    _fetchRoomName();
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

  Future<void> _fetchRoomName() async {
    try {
      final roomDoc = await FirebaseFirestore.instance.collection('rooms').doc(widget.roomId).get();
      if (roomDoc.exists && mounted) {
        setState(() {
          _roomName = roomDoc.data()?['name'] ?? '채팅방';
        });
      }
    } catch (e) {
      // Handle potential errors, e.g., logging
      print("Error fetching room name: $e");
    }
  }

  @override
  void dispose() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      FirebaseFirestore.instance
          .collection('rooms')
          .doc(widget.roomId)
          .get()
          .then((roomDocSnapshot) async {
        if (roomDocSnapshot.exists) {
          final roomData = roomDocSnapshot.data() as Map<String, dynamic>;
          final currentParticipants = List<String>.from(roomData['participants'] ?? []);
          final roomOwnerUid = roomData['roomOwnerUid'];

          // Remove current user from participants
          final updatedParticipants = List<String>.from(currentParticipants)..remove(uid);

          await FirebaseFirestore.instance
              .collection('rooms')
              .doc(widget.roomId)
              .update({
                'participants': updatedParticipants,
              });

          // If the leaving user was the owner and there are still participants, transfer ownership
          if (uid == roomOwnerUid && updatedParticipants.isNotEmpty) {
            final newOwnerUid = updatedParticipants.first;
            await FirebaseFirestore.instance
                .collection('rooms')
                .doc(widget.roomId)
                .update({
                  'roomOwnerUid': newOwnerUid,
                });
            print('Room ownership transferred to $newOwnerUid');
          }

          // If no participants left, delete the room
          if (updatedParticipants.isEmpty) {
            await roomDocSnapshot.reference.delete();
            print('Room ${widget.roomId} deleted as all participants left.');
          }
        }
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
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (didPop) return;
        Navigator.pop(context);
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_roomName),
          actions: [
            StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('rooms')
                  .doc(widget.roomId)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const SizedBox.shrink();
                final data = snapshot.data!.data() as Map<String, dynamic>;
                final isOwner =
                    data['roomOwnerUid'] == FirebaseAuth.instance.currentUser?.uid;
                return isOwner
                    ? IconButton(
                        icon: const Icon(Icons.play_arrow),
                        tooltip: '게임 시작',
                        onPressed: _startGame,
                      )
                    : const SizedBox.shrink();
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
                if (!snapshot.hasData) return const SizedBox.shrink();

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


                final participants = List<String>.from(roomData['participants'] ?? []);
                return Container(
                  width: double.infinity,
                  color: Colors.blueGrey.shade50,
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: participants.map((uid) {
                        return FutureBuilder<DocumentSnapshot>(
                          future: FirebaseFirestore.instance.collection('users').doc(uid).get(),
                          builder: (context, userSnapshot) {
                            if (!userSnapshot.hasData) return const SizedBox.shrink();
                            final userData = userSnapshot.data!.data() as Map<String, dynamic>?;
                            final nickname = userData?['nickname'] ?? '알 수 없음';
                            final isOwner = uid == roomData['roomOwnerUid'];
                            return Chip(
                              label: Text(nickname, style: const TextStyle(color: Colors.white)),
                              backgroundColor: isOwner ? Colors.orange : Colors.lightBlueAccent,
                              side: BorderSide.none,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
                            );
                          },
                        );
                      }).toList(),
                    ),
                  ),
                );
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
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final messages = snapshot.data!.docs;
                  return ListView(
                    padding: const EdgeInsets.all(8),
                    children: messages.map((doc) {
                      final message = doc.data() as Map<String, dynamic>;
                      final currentUserId =
                          FirebaseAuth.instance.currentUser?.uid;
                      final isMine = message['uid'] == currentUserId;

                      return MessageBubble(
                        sender: message['sender'] ?? '',
                        text: message['text'] ?? '',
                        profileUrl: message['profileUrl'] ?? '',
                        isMine: isMine,
                      );
                    }).toList(),
                  );
                },
              ),
            ),
            MessageComposer(
              controller: _controller,
              onSend: _sendMessage,
            )
          ],
        ),
      ),
    );
  }
}