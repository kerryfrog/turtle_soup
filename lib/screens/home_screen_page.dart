import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'room_list_page.dart';
import 'my_page.dart';
import 'chat_room_page.dart';

class HomeScreenPage extends StatefulWidget {
  const HomeScreenPage({super.key});

  @override
  State<HomeScreenPage> createState() => _HomeScreenPageState();
}

class _HomeScreenPageState extends State<HomeScreenPage> {
  int _selectedIndex = 0;

  final List<Widget> _screens = [const RoomListPage(), const MyPage()];

  @override
  void initState() {
    super.initState();
    _checkAndPromptForRejoin();
  }

  Future<void> _checkAndPromptForRejoin() async {
    print('[_checkAndPromptForRejoin] function called.');
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      print('[_checkAndPromptForRejoin] User is null. Exiting.');
      return;
    }

    print('[_checkAndPromptForRejoin] Current user UID: ${user.uid}');
    final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    final currentRoomId = userDoc.data()?['currentRoomId'];
    final inActiveGame = userDoc.data()?['inActiveGame'] ?? false;

    print('[_checkAndPromptForRejoin] currentRoomId: $currentRoomId, inActiveGame: $inActiveGame');

    if (currentRoomId != null) {
      print('[_checkAndPromptForRejoin] Condition: currentRoomId is not null.');
      final roomDoc = await FirebaseFirestore.instance.collection('rooms').doc(currentRoomId).get();
      print('[_checkAndPromptForRejoin] Room exists: ${roomDoc.exists}');
      if (roomDoc.exists) {
        if (mounted) {
          print('[_checkAndPromptForRejoin] Showing rejoin dialog.');
          showDialog(
            context: context,
            barrierDismissible: false, // Prevent dismissing by tapping outside
            builder: (context) => AlertDialog(
              title: const Text('재접속'),
              content: Text('이전에 참여했던 ${inActiveGame ? '게임방' : '채팅방'}이 있습니다. 다시 참여하시겠습니까?'),
              actions: [
                TextButton(
                  onPressed: () async {
                    print('[_checkAndPromptForRejoin] User chose NO. Clearing currentRoomId and inActiveGame.');
                    await FirebaseFirestore.instance.collection('users').doc(user.uid).update({'currentRoomId': FieldValue.delete(), 'inActiveGame': false});
                    Navigator.of(context).pop();
                  },
                  child: const Text('아니요'),
                ),
                TextButton(
                  onPressed: () {
                    print('[_checkAndPromptForRejoin] User chose YES. Navigating to ChatRoomPage.');
                    Navigator.of(context).pop();
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ChatRoomPage(roomId: currentRoomId),
                      ),
                    );
                  },
                  child: const Text('네'),
                ),
              ],
            ),
          );
        }
      } else {
        print('[_checkAndPromptForRejoin] Room does not exist. Clearing currentRoomId and inActiveGame.');
        // Room no longer exists, clear currentRoomId and inActiveGame
        await FirebaseFirestore.instance.collection('users').doc(user.uid).update({'currentRoomId': FieldValue.delete(), 'inActiveGame': false});
      }
    } else {
      print('[_checkAndPromptForRejoin] Condition: currentRoomId is null. No action needed.');
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.chat), label: '채팅방'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: '마이페이지'),
        ],
      ),
    );
  }
}
