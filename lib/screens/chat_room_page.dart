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
  String? _roomOwnerUid; // Add this line
  bool _isOwnerTransferModalShown = false; // New state variable

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

  Future<void> _showOwnerTransferModal(String currentUserUid, Map<String, dynamic> roomData) async {
    final roomId = widget.roomId;
    final shouldBecomeOwner = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('방장 위임 요청'),
        content: const Text('이전 방장이 나갔습니다. 새로운 방장이 되시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false), // No
            child: const Text('아니요'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true), // Yes
            child: const Text('네'),
          ),
        ],
      ),
    );

    if (shouldBecomeOwner == true) {
      // User accepted to become owner
      await FirebaseFirestore.instance.collection('rooms').doc(roomId).update({
        'roomOwnerUid': currentUserUid,
        'ownerTransferPending': false,
        'previousOwnerUid': FieldValue.delete(),
        'ownerCandidates': FieldValue.delete(),
      });
      // Add system message
      final nickname = (await FirebaseFirestore.instance.collection('users').doc(currentUserUid).get()).data()?['nickname'] ?? '새로운 방장';
      await FirebaseFirestore.instance.collection('rooms').doc(roomId).collection('messages').add({
        'text': '$nickname님이 새로운 방장이 되었습니다.',
        'sender': 'System',
        'uid': 'system',
        'timestamp': FieldValue.serverTimestamp(),
      });
    } else {
      // User refused to become owner
      final updatedCandidates = List<String>.from(roomData['ownerCandidates'] ?? [])..remove(currentUserUid);
      await FirebaseFirestore.instance.collection('rooms').doc(roomId).update({
        'ownerCandidates': updatedCandidates,
      });

      if (updatedCandidates.isEmpty) {
        // All candidates refused, end game (this will be handled in a later step)
        await FirebaseFirestore.instance.collection('rooms').doc(roomId).update({
          'ownerTransferPending': false,
          'previousOwnerUid': FieldValue.delete(),
          'ownerCandidates': FieldValue.delete(),
          'isGameActive': false, // 게임 종료
        });
        await FirebaseFirestore.instance.collection('rooms').doc(roomId).collection('messages').add({
          'text': '모든 참가자가 방장 위임을 거부하여 게임이 종료됩니다.',
          'sender': 'System',
          'uid': 'system',
          'timestamp': FieldValue.serverTimestamp(),
        });
        if (mounted) {
          Navigator.pop(context); // Go back to room list
        }
      }
    }
    // Reset the flag after handling the modal, so it can be shown again if a new transfer request comes
    _isOwnerTransferModalShown = false;
  }

  Future<void> _fetchRoomName() async {
    try {
      final roomDoc = await FirebaseFirestore.instance.collection('rooms').doc(widget.roomId).get();
      if (roomDoc.exists && mounted) {
        setState(() {
          _roomName = roomDoc.data()?['name'] ?? '채팅방';
          _roomOwnerUid = roomDoc.data()?['roomOwnerUid']; // Update _roomOwnerUid here
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

          // Add a message to the chat indicating the user has left
          await FirebaseFirestore.instance
              .collection('rooms')
              .doc(widget.roomId)
              .collection('messages')
              .add({
                'text': '${(await FirebaseFirestore.instance.collection('users').doc(uid).get()).data()?['nickname'] ?? '알 수 없는 사용자'}님이 방을 나갔습니다.',
                'sender': 'System',
                'uid': 'system',
                'timestamp': FieldValue.serverTimestamp(),
              });

          await FirebaseFirestore.instance
              .collection('rooms')
              .doc(widget.roomId)
              .update({
                'participants': updatedParticipants,
              });

          // If the leaving user was the owner and there are still participants, initiate ownership transfer
          if (uid == roomOwnerUid && updatedParticipants.isNotEmpty) {
            await FirebaseFirestore.instance
                .collection('rooms')
                .doc(widget.roomId)
                .update({
                  'ownerTransferPending': true,
                  'previousOwnerUid': uid,
                  'ownerCandidates': updatedParticipants, // Store who can be the new owner
                });
            // Add a system message to the chat
            await FirebaseFirestore.instance
                .collection('rooms')
                .doc(widget.roomId)
                .collection('messages')
                .add({
                  'text': '방장이 나갔습니다. 새로운 방장을 선택해주세요.',
                  'sender': 'System',
                  'uid': 'system',
                  'timestamp': FieldValue.serverTimestamp(),
                });
            print('Owner transfer initiated for room ${widget.roomId}');
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
    final roomRef = FirebaseFirestore.instance
        .collection('rooms')
        .doc(widget.roomId);
    final roomDoc = await roomRef.get();
    final participants = List<String>.from(roomDoc.data()?['participants'] ?? []);

    if (participants.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('게임은 2명 이상부터 가능합니다.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final problemSnapshot = await FirebaseFirestore.instance
        .collection('problems')
        .get();
    final problemDocs = problemSnapshot.docs;
    problemDocs.shuffle();
    final selectedProblem = problemDocs.first.data();

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

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      await FirebaseFirestore.instance.collection('users').doc(currentUser.uid).update({
        'inActiveGame': true,
      });
    }

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
                final participants = List<String>.from(data['participants'] ?? []);
                final canStartGame = isOwner && participants.length >= 2;

                return isOwner
                    ? IconButton(
                        icon: const Icon(Icons.play_arrow),
                        tooltip: '게임 시작',
                        onPressed: canStartGame ? _startGame : null,
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
                final roomOwnerUid = roomData['roomOwnerUid']; // 방장 UID 가져오기
                final ownerTransferPending = roomData['ownerTransferPending'] ?? false;
                final ownerCandidates = List<String>.from(roomData['ownerCandidates'] ?? []);
                final currentUserUid = FirebaseAuth.instance.currentUser?.uid;

                if (ownerTransferPending && currentUserUid != null && ownerCandidates.contains(currentUserUid) && !_isOwnerTransferModalShown) {
                  _isOwnerTransferModalShown = true;
                  Future.microtask(() => _showOwnerTransferModal(currentUserUid, roomData));
                }

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
                      final isSenderRoomOwner = message['uid'] == _roomOwnerUid; // 메시지 보낸 사람이 방장인지 확인

                      return MessageBubble(
                        sender: message['sender'] ?? '',
                        text: message['text'] ?? '',
                        profileUrl: message['profileUrl'] ?? '',
                        isMine: isMine,
                        isRoomOwner: isSenderRoomOwner, // isRoomOwner 속성 전달
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