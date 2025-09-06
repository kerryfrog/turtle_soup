import 'package:turtle_soup/widgets/message_bubble.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:turtle_soup/screens/chat_room_page.dart';
import 'package:turtle_soup/screens/room_list_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:turtle_soup/widgets/message_composer.dart';

class GameRoomPage extends StatefulWidget {
  final String roomId;
  final String gameId;
  const GameRoomPage({super.key, required this.roomId, required this.gameId});

  @override
  State<GameRoomPage> createState() => _GameRoomPageState();
}

class _GameRoomPageState extends State<GameRoomPage> {
  @override
  void initState() {
    super.initState();
  }

  final TextEditingController _controller = TextEditingController();
  Map<String, dynamic>? _replyingTo;
  final ScrollController _scrollController = ScrollController();
  String? _lastProcessedMessageId;
  bool _initialModalShown = false;
  bool _isQuizHostTransferModalShown = false;
  bool _isPopping = false;

  Future<bool> _onWillPop() async {
    print('[_onWillPop] function called.');
    final prefs = await SharedPreferences.getInstance();

    print('[_onWillPop] Showing exit confirmation dialog.');
    final shouldLeave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('게임 나가기'),
        content: const Text('게임을 나가면 다시 참여할 수 없습니다. 정말 나가시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () {
              print('[_onWillPop] Dialog: 아니오 pressed.');
              Navigator.pop(context, false);
            },
            child: const Text('아니오'),
          ),
          TextButton(
            onPressed: () {
              print('[_onWillPop] Dialog: 예 pressed.');
              Navigator.pop(context, true);
            },
            child: const Text('예'),
          ),
        ],
      ),
    );

    if (shouldLeave == true) {
      print('[_onWillPop] shouldLeave is true. Performing exit actions.');
      await prefs.remove('crashed_${widget.roomId}');
      await prefs.remove('crashed_gameId');

      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final gameRef = FirebaseFirestore.instance
            .collection('rooms')
            .doc(widget.roomId)
            .collection('games')
            .doc(widget.gameId);

        await gameRef.update({
          'participants': FieldValue.arrayRemove([user.uid])
        });

        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({'currentRoomId': FieldValue.delete(), 'inActiveGame': false});

        final gameDoc = await gameRef.get();
        if (!gameDoc.exists) {
          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const RoomListPage()),
            );
          }
          return false;
        }

        final data = gameDoc.data()!;
        final participants = List<String>.from(data['participants'] ?? []);
        final quizHostUid = data['quizHostUid'];

        if (participants.length <= 1) {
          await _endGame();
          return false;
        }

        if (user.uid == quizHostUid) {
          await gameRef.update({
            'quizHostTransferPending': true,
            'previousQuizHostUid': user.uid,
            'quizHostCandidates': participants,
          });
          final previousHostNickname = (await FirebaseFirestore.instance.collection('users').doc(user.uid).get()).data()?['nickname'] ?? '이전 출제자';
          await gameRef.collection('messages').add({
            'text': '$previousHostNickname님이 게임을 나갔습니다. 새로운 출제자를 선출합니다.',
            'sender': 'System',
            'uid': 'system',
            'timestamp': FieldValue.serverTimestamp(),
          });
        }
      }

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const RoomListPage()),
        );
      }
      return true;
    }
    print('[_onWillPop] shouldLeave is false or dialog dismissed. Preventing pop.');
    return false;
  }

  void _sendMessage(String text) async {
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
      _showEndGameConfirmationDialog();
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
  }

  Future<void> _showEndGameConfirmationDialog() async {
    final shouldProceed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('정답 확인'),
        content: const Text('참가자가 정답을 맞췄습니까? 확인을 누르면 정답을 맞춘 사람을 선택할 수 있습니다.'),
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

    if (shouldProceed == true) {
      _showWinnerSelectionModal();
    }
  }

  Future<void> _showWinnerSelectionModal() async { // Added a comment to force re-parsing
    final roomRef = FirebaseFirestore.instance.collection('rooms').doc(widget.roomId);
    final roomDoc = await roomRef.get();
    final participants = List<String>.from(roomDoc.data()?['participants'] ?? []);

    final gameRef = FirebaseFirestore.instance
        .collection('rooms')
        .doc(widget.roomId)
        .collection('games')
        .doc(widget.gameId);
    final gameDoc = await gameRef.get();
    final quizHostUid = gameDoc.data()?['quizHostUid'];

    final List<Map<String, String>> participantData = [];
    for (final uid in participants) {
      if (uid == quizHostUid) continue;
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      participantData.add({'uid': uid, 'nickname': userDoc.data()?['nickname'] ?? '알 수 없음'});
    }

    final String? selectedWinnerUid = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('정답자 선택'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ...participantData.map((data) => ListTile(
                title: Text(data['nickname']!),
                onTap: () => Navigator.pop(context, data['uid']),
              )),
              ListTile(
                title: const Text('정답 없음'),
                onTap: () => Navigator.pop(context, null),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null), // 취소 버튼
            child: const Text('취소'),
          ),
        ],
      ),
    );

    await _endGame(winnerUid: selectedWinnerUid);
  }

  Future<void> _endGame({String? winnerUid}) async {
    final roomRef = FirebaseFirestore.instance.collection('rooms').doc(widget.roomId);
    final gameRef = roomRef.collection('games').doc(widget.gameId);

    final gameDoc = await gameRef.get();
    if (!gameDoc.exists) return;
    final answer = gameDoc.data()?['problemAnswer'] ?? '정답 없음';

    if (winnerUid != null) {
      final winnerDoc = await FirebaseFirestore.instance.collection('users').doc(winnerUid).get();
      final winnerNickname = winnerDoc.data()?['nickname'] ?? '알 수 없는 사용자';
      await gameRef.collection('messages').add({
        'text': '${winnerNickname}님이 정답을 맞췄습니다! 축하드려요!',
        'sender': 'System',
        'uid': 'system',
        'timestamp': FieldValue.serverTimestamp(),
      });
      await gameRef.collection('messages').add({
        'text': '정답 공개: $answer',
        'sender': 'System',
        'uid': 'system',
        'timestamp': FieldValue.serverTimestamp(),
      });
    } else {
      await gameRef.collection('messages').add({
        'text': '정답은 $answer입니다!',
        'sender': 'System',
        'uid': 'system',
        'timestamp': FieldValue.serverTimestamp(),
      });
    }

    await roomRef.update({
      'currentGameId': FieldValue.delete(),
      'isGameActive': false,
    });

    final roomDoc = await roomRef.get();
    if (roomDoc.exists) {
      final participants = List<String>.from(roomDoc.data()?['participants'] ?? []);
      for (final participantId in participants) {
        await FirebaseFirestore.instance.collection('users').doc(participantId).update({
          'inActiveGame': false,
        });
      }
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('crashed_${widget.roomId}');
    await prefs.remove('crashed_gameId');

    Future.delayed(const Duration(seconds: 20), () {
      gameRef.collection('messages').add({
        'text': '10초뒤 대기실로 돌아갑니다',
        'sender': 'System',
        'uid': 'system',
        'timestamp': FieldValue.serverTimestamp(),
      });
    });

    Future.delayed(const Duration(seconds: 30), () {
      print('[GameRoomPage] _endGame: Deleting game document.');
      gameRef.delete();
    });
  }

  void _showHostModal(BuildContext context, String problem, String answer) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('당신은 출제자입니다'),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                const Text('문제', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(problem),
                const SizedBox(height: 16),
                const Text('정답', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(answer),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('확인'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  void _showParticipantModal(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('당신은 참가자입니다'),
          content: const Text('출제자가 문제를 확인하는 동안 잠시만 기다려주세요.'),
          actions: <Widget>[
            TextButton(
              child: const Text('확인'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _showQuizHostTransferModal(BuildContext context, String previousHostNickname) async {
    final shouldBecomeHost = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('출제자 위임 요청'),
        content: Text('$previousHostNickname님이 게임을 나갔습니다. 새로운 출제자가 되시겠습니까?'),
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

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    if (shouldBecomeHost == true) {
      await FirebaseFirestore.instance
          .collection('rooms')
          .doc(widget.roomId)
          .collection('games')
          .doc(widget.gameId)
          .update({
            'quizHostUid': currentUser.uid,
            'quizHostTransferPending': false,
            'quizHostCandidates': FieldValue.delete(),
          });
      // Add system message
      final nickname = (await FirebaseFirestore.instance.collection('users').doc(currentUser.uid).get()).data()?['nickname'] ?? '새로운 출제자';
      await FirebaseFirestore.instance
          .collection('rooms')
          .doc(widget.roomId)
          .collection('games')
          .doc(widget.gameId)
          .collection('messages')
          .add({
            'text': '$nickname님이 새로운 출제자가 되었습니다.',
            'sender': 'System',
            'uid': 'system',
            'timestamp': FieldValue.serverTimestamp(),
          });
    } else {
      final gameRef = FirebaseFirestore.instance
          .collection('rooms')
          .doc(widget.roomId)
          .collection('games')
          .doc(widget.gameId);
      final gameDoc = await gameRef.get();
      final currentCandidates = List<String>.from(gameDoc.data()?['quizHostCandidates'] ?? []);
      final updatedCandidates = currentCandidates..remove(currentUser.uid);

      if (updatedCandidates.isEmpty) {
        // All candidates refused, end game
        await gameRef.update({
          'quizHostTransferPending': false,
          'quizHostCandidates': FieldValue.delete(),
        });
        await gameRef.collection('messages').add({
          'text': '모든 참가자가 출제자 위임을 거부하여 게임이 종료됩니다.',
          'sender': 'System',
          'uid': 'system',
          'timestamp': FieldValue.serverTimestamp(),
        });
        await _endGame(); // End the game if no one accepts
      } else {
        await gameRef.update({
          'quizHostCandidates': updatedCandidates,
        });
      }
    }
    _isQuizHostTransferModalShown = false; // Reset flag
  }

  @override
  Widget build(BuildContext context) {
    
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        final shouldLeave = await _onWillPop();
        if (shouldLeave) {
          if (mounted) {
            Navigator.of(context).pop();
          }
        }
      },
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
            print('[GameRoomPage] StreamBuilder: Game document does not exist. Popping to previous route.');
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && !_isPopping) {
                _isPopping = true; // Set the flag to true
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (context) => ChatRoomPage(roomId: widget.roomId)),
                  (Route<dynamic> route) => route.isFirst,
                );
                print('[GameRoomPage] StreamBuilder: Navigated to ChatRoomPage.');
              }
            });
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          }

          // If we have data and the document exists, proceed to build the UI.
          final data = snapshot.data!.data() as Map<String, dynamic>;
          final problemTitle = data['problemTitle'] ?? '게임 방';
          final problem = data['problemQuestion'] ?? '문제가 없습니다';
          final answer = data['problemAnswer'] ?? '정답이 없습니다';
          final hostUid = data['quizHostUid'];

          final currentUid = FirebaseAuth.instance.currentUser?.uid;
          final isHost = currentUid != null && hostUid == currentUid;

          if (!_initialModalShown) {
            _initialModalShown = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                if (isHost) {
                  _showHostModal(context, problem, answer);
                } else {
                  _showParticipantModal(context);
                }
              }
            });
          }

          final quizHostTransferPending = data['quizHostTransferPending'] ?? false;
          final quizHostCandidates = List<String>.from(data['quizHostCandidates'] ?? []);

          if (quizHostTransferPending && currentUid != null && quizHostCandidates.contains(currentUid) && !_isQuizHostTransferModalShown) {
            _isQuizHostTransferModalShown = true;
            final previousQuizHostUid = data['previousQuizHostUid'];
            FirebaseFirestore.instance.collection('users').doc(previousQuizHostUid).get().then((doc) {
              final previousHostNickname = doc.data()?['nickname'] ?? '이전 출제자';
              if (mounted) {
                _showQuizHostTransferModal(context, previousHostNickname);
              }
            });
          }

          return Scaffold(
            appBar: AppBar(
              title: Text(problemTitle),
              actions: [
                if (isHost)
                  IconButton(
                    icon: const Icon(Icons.security), // 정답 아이콘
                    tooltip: '정답 확인',
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
                  ),
              ],
            ),
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
                      if (!snapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }
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
                      MessageComposer(
                        onSend: _sendMessage,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            floatingActionButton: null,
          );
        },
      ),
    );
  }
}