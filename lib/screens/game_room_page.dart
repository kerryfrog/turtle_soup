import 'package:turtle_soup/widgets/message_bubble.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:turtle_soup/screens/chat_room_page.dart';
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
  bool _initialModalShown = false;
  bool _isQuizHostTransferModalShown = false;
  bool _isPopping = false;

  Future<void> _onWillPop() async {
    final prefs = await SharedPreferences.getInstance();

    final shouldLeave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('게임 나가기'),
        content: const Text('게임을 나가면 다시 참여할 수 없습니다. 정말 나가시겠습니까?'),
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

    if (shouldLeave != true) return;

    await prefs.remove('crashed_${widget.roomId}');
    await prefs.remove('crashed_gameId');

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
        if (mounted) Navigator.of(context).pop();
        return;
    }

    final gameRef = FirebaseFirestore.instance
        .collection('rooms')
        .doc(widget.roomId)
        .collection('games')
        .doc(widget.gameId);

    final roomRef = FirebaseFirestore.instance.collection('rooms').doc(widget.roomId);
    final userRef = FirebaseFirestore.instance.collection('users').doc(user.uid);

    try {
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final gameDoc = await transaction.get(gameRef);
        final roomDoc = await transaction.get(roomRef);
        final userDoc = await transaction.get(userRef);

        if (!gameDoc.exists || !roomDoc.exists || !userDoc.exists) return;

        final gameData = gameDoc.data()!;
        final roomData = roomDoc.data()!;
        final quizHostUid = gameData['quizHostUid'];
        final isCurrentUserQuizHost = user.uid == quizHostUid;

        final updatedGameParticipants = List<String>.from(gameData['participants'] ?? [])..remove(user.uid);
        final updatedRoomParticipants = List<String>.from(roomData['participants'] ?? [])..remove(user.uid);

        if (isCurrentUserQuizHost) {
          final previousHostNickname = userDoc.data()?['nickname'] ?? '이전 출제자';
          if (updatedGameParticipants.isNotEmpty) {
            final shuffledCandidates = updatedGameParticipants..shuffle();
            
            transaction.update(gameRef, {
              'quizHostUid': null,
              'previousQuizHostUid': user.uid,
              'quizHostTransferPending': true,
              'quizHostCandidates': shuffledCandidates,
              'currentCandidateIndex': 0,
              'participants': updatedGameParticipants
            });

            final systemMessage = '$previousHostNickname(출제자)님이 나갔습니다. 새로운 출제자를 정합니다.';
            transaction.set(gameRef.collection('messages').doc(), {
              'text': systemMessage,
              'sender': '운영자',
              'uid': 'system',
              'timestamp': FieldValue.serverTimestamp(),
            });

          } else {
            await _endGame(transaction: transaction, shouldRevealAnswer: false, participants: updatedRoomParticipants);
          }
        } else {
           if (updatedGameParticipants.length < 2) {
              await _endGame(transaction: transaction, shouldRevealAnswer: true, participants: updatedRoomParticipants);
           } else {
             transaction.update(gameRef, {'participants': updatedGameParticipants});
           }
        }

        transaction.update(roomRef, {'participants': updatedRoomParticipants});
        transaction.update(userRef, {'currentRoomId': FieldValue.delete(), 'inActiveGame': false});
      });
    } catch (e, s) {
      print("--- TRANSACTION FAILED ---");
      print("Error: $e");
      print("Stack Trace: $s");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('오류가 발생하여 방을 나갈 수 없습니다.')),
        );
      }
      return;
    }

    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => ChatRoomPage(roomId: widget.roomId)),
        (Route<dynamic> route) => route.isFirst,
      );
    }
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

    final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    final nickname = userDoc.data()?['nickname'] ?? '익명';
    final profileUrl = userDoc.data()?['profileUrl'] ?? 'https://via.placeholder.com/150';

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
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('아니오')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('예')),
        ],
      ),
    );

    if (shouldProceed == true) {
      _showWinnerSelectionModal();
    }
  }

  Future<void> _showWinnerSelectionModal() async {
    final roomRef = FirebaseFirestore.instance.collection('rooms').doc(widget.roomId);
    final roomDoc = await roomRef.get();
    final participants = List<String>.from(roomDoc.data()?['participants'] ?? []);

    final gameRef = roomRef.collection('games').doc(widget.gameId);
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
            children: participantData.map((data) => ListTile(
                title: Text(data['nickname']!),
                onTap: () => Navigator.pop(context, data['uid']),
              )).toList(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, null), child: const Text('취소')),
        ],
      ),
    );
    if (!mounted) return;
    String? winnerNickname;
    if (selectedWinnerUid != null) {
      final winnerDoc = await FirebaseFirestore.instance.collection('users').doc(selectedWinnerUid).get();
      winnerNickname = winnerDoc.data()?['nickname'] ?? '알 수 없는 사용자';
    }

    await _endGame(winnerUid: selectedWinnerUid, winnerNickname: winnerNickname, shouldRevealAnswer: true, participants: participants);
  }

  Future<void> _endGame({String? winnerUid, String? winnerNickname, bool shouldRevealAnswer = true, required List<String> participants, Transaction? transaction}) async {
    final db = FirebaseFirestore.instance;
    final roomRef = db.collection('rooms').doc(widget.roomId);
    final gameRef = roomRef.collection('games').doc(widget.gameId);

    final gameDoc = transaction != null ? await transaction.get(gameRef) : await gameRef.get();
    if (!gameDoc.exists) return;
    final answer = gameDoc.data()?['problemAnswer'] ?? '정답 없음';

    final messagesCol = gameRef.collection('messages');

    if (shouldRevealAnswer && winnerUid != null && winnerNickname != null) {
        final winMessage = {
          'text': '축하드립니다. ${winnerNickname}님이 정답을 맞췄습니다!',
          'sender': '운영자', 'uid': 'system', 'timestamp': FieldValue.serverTimestamp(),
        };
        transaction != null ? transaction.set(messagesCol.doc(), winMessage) : await messagesCol.add(winMessage);

        final answerMessage = {
          'text': '정답 공개: $answer',
          'sender': '운영자', 'uid': 'system', 'timestamp': FieldValue.serverTimestamp(),
        };
        transaction != null ? transaction.set(messagesCol.doc(), answerMessage) : await messagesCol.add(answerMessage);
    }

    final roomUpdate = {'currentGameId': FieldValue.delete(), 'isGameActive': false};
    transaction != null ? transaction.update(roomRef, roomUpdate) : await roomRef.update(roomUpdate);

    for (final participantId in participants) {
      final userRef = db.collection('users').doc(participantId);
      final userUpdate = {'inActiveGame': false};
      transaction != null ? transaction.update(userRef, userUpdate) : await userRef.update(userUpdate);
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('crashed_${widget.roomId}');
    await prefs.remove('crashed_gameId');

    Future.delayed(const Duration(seconds: 20), () {
      if (!mounted) return;
      messagesCol.add({
        'text': '10초뒤 대기실로 돌아갑니다',
        'sender': '운영자', 'uid': 'system', 'timestamp': FieldValue.serverTimestamp(),
      });
    });

    Future.delayed(const Duration(seconds: 30), () {
      if (!mounted) return;
      gameRef.delete();
    });
  }

  void _showHostModal(BuildContext context, String problem, String answer) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) => AlertDialog(
          title: const Text('당신은 출제자입니다'),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                const Text('문제', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8), Text(problem),
                const SizedBox(height: 16),
                const Text('정답', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8), Text(answer),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(child: const Text('확인'), onPressed: () => Navigator.of(context).pop()),
          ],
        ),
      );
    });
  }

  void _showParticipantModal(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) => AlertDialog(
          title: const Text('당신은 참가자입니다'),
          content: const Text('출제자가 문제를 확인하는 동안 잠시만 기다려주세요.'),
          actions: <Widget>[
            TextButton(child: const Text('확인'), onPressed: () => Navigator.of(context).pop()),
          ],
        ),
      );
    });
  }

  Future<void> _showQuizHostTransferModal(BuildContext context, String previousHostNickname) async {
    if (!mounted) return;
    final shouldBecomeHost = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('출제자 위임 요청'),
        content: Text('$previousHostNickname(이)가 게임을 나갔습니다. 새로운 출제자가 되시겠습니까?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('아니오')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('예')),
        ],
      ),
    );

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null || !mounted) return;

    final gameRef = FirebaseFirestore.instance.collection('rooms').doc(widget.roomId).collection('games').doc(widget.gameId);

    if (shouldBecomeHost == true) {
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final userDoc = await transaction.get(FirebaseFirestore.instance.collection('users').doc(currentUser.uid));
        final nickname = userDoc.data()?['nickname'] ?? '새로운 출제자';
        
        transaction.update(gameRef, {
          'quizHostUid': currentUser.uid,
          'quizHostTransferPending': false,
          'quizHostCandidates': FieldValue.delete(),
          'currentCandidateIndex': FieldValue.delete(),
          'previousQuizHostUid': FieldValue.delete(),
        });
        
        transaction.set(gameRef.collection('messages').doc(), {
          'text': '$nickname(이)가 새로운 출제자가 되었습니다.',
          'sender': '운영자', 'uid': 'system', 'timestamp': FieldValue.serverTimestamp(),
        });
      });
    } else {
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final gameDoc = await transaction.get(gameRef);
        if (!gameDoc.exists) return;

        final candidates = List<String>.from(gameDoc.data()?['quizHostCandidates'] ?? []);
        final currentIndex = gameDoc.data()?['currentCandidateIndex'] ?? 0;

        if (currentIndex + 1 < candidates.length) {
          transaction.update(gameRef, {'currentCandidateIndex': FieldValue.increment(1)});
        } else {
          transaction.set(gameRef.collection('messages').doc(), {
            'text': '출제자가 나가 게임을 종료합니다.',
            'sender': '운영자', 'uid': 'system', 'timestamp': FieldValue.serverTimestamp(),
          });
          await _endGame(transaction: transaction, shouldRevealAnswer: false, participants: candidates..remove(currentUser.uid));
        }
      });
    }
    if (mounted) {
      setState(() { _isQuizHostTransferModalShown = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        await _onWillPop();
      },
      child: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('rooms').doc(widget.roomId).collection('games').doc(widget.gameId).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          }
          if (snapshot.hasError) {
            return Scaffold(body: Center(child: Text("Error: ${snapshot.error}")));
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && !_isPopping) {
                _isPopping = true;
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (context) => ChatRoomPage(roomId: widget.roomId)),
                  (Route<dynamic> route) => route.isFirst,
                );
              }
            });
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;
          final problemTitle = data['problemTitle'] ?? '게임 방';
          final problem = data['problemQuestion'] ?? '문제가 없습니다';
          final answer = data['problemAnswer'] ?? '정답이 없습니다';
          final hostUid = data['quizHostUid'];
          final currentUid = FirebaseAuth.instance.currentUser?.uid;
          final isHost = currentUid != null && hostUid == currentUid;

          if (!_initialModalShown) {
            _initialModalShown = true;
            if (isHost) {
              _showHostModal(context, problem, answer);
            } else {
              _showParticipantModal(context);
            }
          }

          final quizHostTransferPending = data['quizHostTransferPending'] ?? false;
          if (quizHostTransferPending && currentUid != null && !_isQuizHostTransferModalShown) {
            final candidates = List<String>.from(data['quizHostCandidates'] ?? []);
            final currentIndex = data['currentCandidateIndex'] ?? 0;

            if (candidates.isNotEmpty && currentIndex < candidates.length && candidates[currentIndex] == currentUid) {
              _isQuizHostTransferModalShown = true;
              final previousQuizHostUid = data['previousQuizHostUid'];
              FirebaseFirestore.instance.collection('users').doc(previousQuizHostUid).get().then((doc) {
                final previousHostNickname = doc.data()?['nickname'] ?? '이전 출제자';
                if (mounted) {
                  _showQuizHostTransferModal(context, previousHostNickname);
                }
              });
            }
          }

          return Scaffold(
            appBar: AppBar(
              title: Text(problemTitle),
              actions: [
                if (isHost)
                  IconButton(
                    icon: const Icon(Icons.security),
                    tooltip: '정답 확인',
                    onPressed: () => showModalBottomSheet(
                      context: context,
                      builder: (context) => Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('정답', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            Text(answer),
                          ],
                        ),
                      ),
                    ),
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
                      const Text('문제', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 4),
                      Text(problem),
                    ],
                  ),
                ),
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance.collection('rooms').doc(widget.roomId).collection('games').doc(widget.gameId).collection('messages').orderBy('timestamp').snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
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
                          final currentUserId = FirebaseAuth.instance.currentUser?.uid;
                          final isMine = message['uid'] == currentUserId;

                          return Align(
                            alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
                            child: GestureDetector(
                              onLongPress: () => setState(() { _replyingTo = message; }),
                              onSecondaryTap: () => setState(() { _replyingTo = message; }),
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
                                  style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.close),
                                onPressed: () => setState(() { _replyingTo = null; }),
                              ),
                            ],
                          ),
                        ),
                      MessageComposer(onSend: _sendMessage),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}