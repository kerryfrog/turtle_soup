import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'chat_room_page.dart';
import 'login_page.dart';
import 'create_room_page.dart';
import 'game_room_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';

class RoomListPage extends StatefulWidget {
  const RoomListPage({super.key});

  @override
  State<RoomListPage> createState() => _RoomListPageState();
}

class _RoomListPageState extends State<RoomListPage> {
  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  void _checkLoginStatus() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      Future.microtask(() => Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const LoginPage()),
          ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: SharedPreferences.getInstance(),
      builder: (context, AsyncSnapshot<SharedPreferences> prefsSnapshot) {
        if (!prefsSnapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final prefs = prefsSnapshot.data!;
        final crashedRoomId = prefs.getString('crashed_${prefs.getString("pendingRoomId")}');
        final crashedGameId = prefs.getString('crashed_gameId');

        if (crashedRoomId != null && crashedGameId != null) {
          // 재입장 유도 다이얼로그 표시
          Future.microtask(() {
            showDialog(
              context: context,
              builder: (_) => AlertDialog(
                title: const Text('재입장'),
                content: const Text('이전에 진행 중이던 게임이 있습니다. 다시 들어가시겠습니까?'),
                actions: [
                  TextButton(
                    onPressed: () {
                      prefs.remove('crashed_$crashedRoomId');
                      prefs.remove('crashed_gameId');
                      Navigator.of(context).pop();
                    },
                    child: const Text('아니요'),
                  ),
                  TextButton(
                    onPressed: () {
                      prefs.remove('crashed_$crashedRoomId');
                      prefs.remove('crashed_gameId');
                      Navigator.of(context).pop();
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => GameRoomPage(roomId: crashedRoomId, gameId: crashedGameId),
                        ),
                      );
                    },
                    child: const Text('네'),
                  ),
                ],
              ),
            );
          });
        }

        return Scaffold(
          appBar: AppBar(title: const Text('게임방 목록')),
          body: Column(
            children: [
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('rooms')
                      .where('isGameActive', isEqualTo: false)
                      .orderBy('createdAt', descending: true)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Center(child: Text('오류가 발생했습니다: ${snapshot.error}'));
                    }
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final rooms = snapshot.data!.docs;
                    if (rooms.isEmpty) {
                      return const Center(child: Text('현재 게임이 없습니다'));
                    }
                    return ListView.builder(
                      itemCount: rooms.length,
                      itemBuilder: (context, index) {
                        final room = rooms[index];
                        return ListTile(
                          title: Text(room['name']),
                          onTap: () async {
                            final currentUser = FirebaseAuth.instance.currentUser;
                            if (currentUser != null) {
                              await FirebaseFirestore.instance
                                  .collection('users')
                                  .doc(currentUser.uid)
                                  .set({'currentRoomId': room.id}, SetOptions(merge: true));
                            }
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ChatRoomPage(roomId: room.id),
                              ),
                            );
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CreateRoomPage()),
              );
            },
            child: const Icon(Icons.add),
          ),
        );
      },
    );
  }
}