import 'package:turtle_soup/widgets/message_composer.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:turtle_soup/widgets/message_bubble.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  bool _isGameActive = false;
  bool _isReturningFromGame = false;

  @override
  void initState() {
    super.initState();
    _joinRoom();
    _fetchRoomName();
  }

  Future<void> _joinRoom() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final roomRef = FirebaseFirestore.instance.collection('rooms').doc(widget.roomId);
    final roomDoc = await roomRef.get();

    if (!roomDoc.exists) {
      // Handle room not found
      return;
    }

    final roomData = roomDoc.data() as Map<String, dynamic>;
    final participants = List<String>.from(roomData['participants'] ?? []);
    final maxParticipants = roomData.containsKey('maxParticipants') ? roomData['maxParticipants'] : 10;

    if (participants.length >= maxParticipants) {
      // Room is full
      if (mounted) {
        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('입장 불가'),
            content: const Text('채팅방 인원이 가득 찼습니다.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('확인'),
              ),
            ],
          ),
        );
        Navigator.of(context).pop();
      }
      return;
    }

    await roomRef.update({
      'participants': FieldValue.arrayUnion([uid]),
    });

    final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    final nickname = userDoc.data()?['nickname'] ?? '알 수 없는 사용자';
    await FirebaseFirestore.instance
        .collection('rooms')
        .doc(widget.roomId)
        .collection('messages')
        .add({
      'text': '$nickname님이 입장하셨습니다.',
      'sender': 'System',
      'uid': 'system',
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _fetchRoomName() async {
    try {
      final roomDoc = await FirebaseFirestore.instance
          .collection('rooms')
          .doc(widget.roomId)
          .get();
      if (roomDoc.exists && mounted) {
        setState(() {
          _roomName = roomDoc.data()?['name'] ?? '채팅방';
          _roomOwnerUid =
              roomDoc.data()?['roomOwnerUid']; // Update _roomOwnerUid here
        });
      }
    } catch (e) {
      // Handle potential errors, e.g., logging
      print("Error fetching room name: $e");
    }
  }

  @override
  void dispose() {
    print('[ChatRoomPage] dispose() called.');
    super.dispose();
  }

  Future<void> _performRoomExitLogic() async {
    print('[ChatRoomPage] _performRoomExitLogic() called.');
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final roomDocSnapshot = await FirebaseFirestore.instance
        .collection('rooms')
        .doc(widget.roomId)
        .get();

    if (roomDocSnapshot.exists) {
      final roomData = roomDocSnapshot.data() as Map<String, dynamic>;
      final currentParticipants =
          List<String>.from(roomData['participants'] ?? []);
      final roomOwnerUid = roomData['roomOwnerUid'];

      // Remove current user from participants
      final updatedParticipants = List<String>.from(currentParticipants)
        ..remove(uid);

      // Add a message to the chat indicating the user has left
      final userNickname = (await FirebaseFirestore.instance.collection('users').doc(uid).get()).data()?['nickname'] ?? '알 수 없는 사용자';
      await FirebaseFirestore.instance
          .collection('rooms')
          .doc(widget.roomId)
          .collection('messages')
          .add({
        'text': '$userNickname님이 방을 나갔습니다.',
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
        final newOwnerUid = (updatedParticipants..shuffle()).first;
        await FirebaseFirestore.instance
            .collection('rooms')
            .doc(widget.roomId)
            .update({
          'roomOwnerUid': newOwnerUid,
        });
        final newOwnerNickname = (await FirebaseFirestore.instance
                    .collection('users')
                    .doc(newOwnerUid)
                    .get())
                .data()?['nickname'] ??
            '새로운 방장';
        // Add a system message to the chat
        await FirebaseFirestore.instance
            .collection('rooms')
            .doc(widget.roomId)
            .collection('messages')
            .add({
          'text': '방장이 나가서 $newOwnerNickname님이 새로운 방장이 되었습니다.',
          'sender': 'System',
          'uid': 'system',
          'timestamp': FieldValue.serverTimestamp(),
        });
        print('Owner transfer initiated for room ${widget.roomId}');
      }
    }
  }

  Future<void> _startGame() async {
    final roomRef =
        FirebaseFirestore.instance.collection('rooms').doc(widget.roomId);
    final roomDoc = await roomRef.get();
    final participants =
        List<String>.from(roomDoc.data()?['participants'] ?? []);

    if (participants.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('게임은 2명 이상부터 가능합니다.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final problemSnapshot =
        await FirebaseFirestore.instance.collection('problems').get();
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
      'isGameActive': true,
    });

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .update({
        'inActiveGame': true,
      });
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('crashed_${widget.roomId}', true);
    await prefs.setString('crashed_gameId', newGameId);

    setState(() {
      _isGameActive = true;
      _isReturningFromGame = true; // Set to true before navigating
    });
    print('[ChatRoomPage] _startGame: Navigating to game_room. _isGameActive: $_isGameActive, _isReturningFromGame: $_isReturningFromGame');

    Navigator.pushNamed(
      context,
      '/game_room',
      arguments: {
        'roomId': widget.roomId,
        'gameId': newGameId,
      },
    ).then((_) {
      setState(() {
        _isGameActive = false;
        _isReturningFromGame = false; // Reset to false after returning
      });
      print('[ChatRoomPage] _startGame: Returned from game_room. _isGameActive: $_isGameActive, _isReturningFromGame: $_isReturningFromGame');
    });
  }

  void _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final userDoc =
        await FirebaseFirestore.instance.collection('users').doc(user.uid).get();

    final nickname = userDoc.data()?['nickname'] ?? '익명';
    final profileUrl =
        userDoc.data()?['profileUrl'] ?? 'https://via.placeholder.com/150';

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
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        print('[ChatRoomPage] onPopInvoked: didPop: $didPop, _isReturningFromGame: $_isReturningFromGame');
        if (didPop) {
          print('[ChatRoomPage] onPopInvoked: System is popping, returning.');
          return; // If the system is trying to pop, let it.
        }

        if (_isReturningFromGame) {
          // If returning from game, prevent popping and reset the flag.
          print('[ChatRoomPage] onPopInvoked: Returning from game, preventing pop.');
          setState(() {
            _isReturningFromGame = false;
          });
          return;
        }

        // If not returning from game, perform exit logic and then pop.
        print('[ChatRoomPage] onPopInvoked: Not returning from game, performing exit logic.');
        await _performRoomExitLogic();
        if (mounted) {
          print('[ChatRoomPage] onPopInvoked: Navigating back to previous screen.');
          Navigator.pop(context);
        }
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
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const SizedBox.shrink();
                }
                if (!snapshot.hasData || !snapshot.data!.exists) {
                  // Room document does not exist or has no data, handle gracefully
                  return const SizedBox
                      .shrink(); // Or show an error message/navigate away
                }
                final data = snapshot.data!.data() as Map<String, dynamic>;
                final isOwner = data['roomOwnerUid'] ==
                    FirebaseAuth.instance.currentUser?.uid;
                final participants =
                    List<String>.from(data['participants'] ?? []);
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
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const SizedBox.shrink();
                }
                if (!snapshot.hasData || !snapshot.data!.exists) {
                  // Room document does not exist or has no data, handle gracefully
                  return const Center(
                      child:
                          Text('방 정보를 불러올 수 없습니다.')); // Or navigate away
                }

                final roomData = snapshot.data!.data() as Map<String, dynamic>;
                final gameId = roomData['currentGameId'];
                final roomOwnerUid = roomData['roomOwnerUid']; // 방장 UID 가져오기

                if (gameId != null) {
                  Future.microtask(() {
                    Navigator.pushNamed(
                      context,
                      '/game_room',
                      arguments: {
                        'roomId': widget.roomId,
                        'gameId': gameId,
                      },
                    );
                  });
                }

                final participants =
                    List<String>.from(roomData['participants'] ?? []);
                return Container(
                  width: double.infinity,
                  color: Colors.blueGrey.shade50,
                  padding:
                      const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: participants.map((uid) {
                        return FutureBuilder<DocumentSnapshot>(
                          future: FirebaseFirestore.instance
                              .collection('users')
                              .doc(uid)
                              .get(),
                          builder: (context, userSnapshot) {
                            if (!userSnapshot.hasData)
                              return const SizedBox.shrink();
                            final userData =
                                userSnapshot.data!.data() as Map<String, dynamic>?;
                            final nickname = userData?['nickname'] ?? '알 수 없음';
                            final isOwner = uid == roomData['roomOwnerUid'];
                            return Chip(
                              label: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (isOwner)
                                    const Padding(
                                      padding: EdgeInsets.only(right: 4.0),
                                      child: Text('👑',
                                          style: TextStyle(fontSize: 16)),
                                    ),
                                  Text(nickname,
                                      style:
                                          const TextStyle(color: Colors.white)),
                                ],
                              ),
                              backgroundColor: isOwner
                                  ? Colors.orange
                                  : Colors.lightBlueAccent,
                              side: BorderSide.none,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(5)),
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
                      final isSenderRoomOwner =
                          message['uid'] == _roomOwnerUid; // 메시지 보낸 사람이 방장인지 확인

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
              onSend: (text) async {
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
                }
              },
            )
          ],
        ),
      ),
    );
  }
}