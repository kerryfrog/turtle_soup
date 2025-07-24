import 'package:turtle_soup/widgets/message_bubble.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:turtle_soup/screens/chat_room_page.dart';
import 'package:turtle_soup/screens/room_list_page.dart';

class GameRoomPage extends StatefulWidget {
  final String roomId;
  final String gameId;
  const GameRoomPage({super.key, required this.roomId, required this.gameId});

  @override
  State<GameRoomPage> createState() => _GameRoomPageState();
}

class _GameRoomPageState extends State<GameRoomPage> {
  final TextEditingController _controller = TextEditingController();
  Map<String, dynamic>? _replyingTo;
  final ScrollController _scrollController = ScrollController();
  String? _lastProcessedMessageId;

  Future<bool> _onWillPop() async {
    final shouldLeave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('정말 나가시겠습니까?'),
        content: const Text('게임을 종료하고 채팅방 목록으로 이동합니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('아니오'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('예'),
          ),
        ],
      ),
    );
    if (shouldLeave == true) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const RoomListPage()),
      );
      return false;
    }
    return false;
  }

  void _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final gameDoc = await FirebaseFirestore.instance
        .collection('rooms')
        .doc(widget.roomId)
        .collection('games')
        .doc(widget.gameId)
        .get();
    final quizHostUid = gameDoc.data()?['quizHostUid'];

    if (user.uid == quizHostUid && text == '정답') {
      _endGame();
      return;
    }

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
          if (_replyingTo != null) 'replyTo': _replyingTo,
        });
    _controller.clear();
    setState(() {
      _replyingTo = null;
    });
  }

  Future<void> _endGame() async {
    await FirebaseFirestore.instance
        .collection('rooms')
        .doc(widget.roomId)
        .collection('games')
        .doc(widget.gameId)
        .delete();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('rooms')
            .doc(widget.roomId)
            .collection('games')
            .doc(widget.gameId)
            .snapshots(),
        builder: (context, snapshot) {
          // Handle connection state and potential errors first.
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          }
          if (snapshot.hasError) {
            return Scaffold(body: Center(child: Text("Error: ${snapshot.error}")));
          }

          // If the document doesn't exist (e.g., game ended and deleted), navigate back.
          if (!snapshot.hasData || !snapshot.data!.exists) {
            WidgetsBinding.instance.addPostFrameCallback((_) async {
              if (mounted) {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => ChatRoomPage(roomId: widget.roomId)),
                );
              }
            });
            return const Scaffold(body: Center(child: Text("Game over. Returning to chat...")));
          }

          // If we have data and the document exists, proceed to build the UI.
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
                      const Text(
                        '문제',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
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

                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (_scrollController.hasClients) {
                          _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
                        }
                      });

                      return ListView(
                        controller: _scrollController,
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
                            child: GestureDetector(
                              onLongPress: () {
                                setState(() {
                                  _replyingTo = message;
                                });
                              },
                              onSecondaryTap: () {
                                setState(() {
                                  _replyingTo = message;
                                });
                              },
                              child: MessageBubble(
                                sender: message['sender'] ?? '',
                                text: message['text'] ?? '',
                                profileUrl: message['profileUrl'] ?? '',
                                isMine: isMine,
                                replyTo: message['replyTo'],
                              ),
                            ),
                          );
                        }).toList(),
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_replyingTo != null)
                        Container(
                          padding: const EdgeInsets.all(8),
                          color: Colors.grey[300],
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  "답장 대상: ${_replyingTo?['sender'] ?? ''}: ${_replyingTo?['text'] ?? ''}",
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.close),
                                onPressed: () {
                                  setState(() {
                                    _replyingTo = null;
                                  });
                                },
                              ),
                            ],
                          ),
                        ),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _controller,
                              decoration: const InputDecoration(
                                hintText: '메시지 입력',
                              ),
                              onSubmitted: (_) => _sendMessage(),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.send),
                            onPressed: _sendMessage,
                          ),
                        ],
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
      ),
    );
  }
}