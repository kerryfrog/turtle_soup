import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'chat_room_page.dart';

class RoomListPage extends StatelessWidget {
  const RoomListPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('채팅방 목록')),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('rooms')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData)
            return const Center(child: CircularProgressIndicator());
          final rooms = snapshot.data!.docs;
          return ListView.builder(
            itemCount: rooms.length,
            itemBuilder: (context, index) {
              final room = rooms[index];
              return ListTile(
                title: Text(room['name']),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          ChatRoomPage(roomId: room.id, roomName: room['name']),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final controller = TextEditingController();
          await showDialog(
            context: context,
            builder: (_) => AlertDialog(
              title: const Text('새 채팅방'),
              content: TextField(controller: controller),
              actions: [
                TextButton(
                  onPressed: () {
                    FirebaseFirestore.instance.collection('rooms').add({
                      'name': controller.text,
                      'createdAt': FieldValue.serverTimestamp(),
                    });
                    Navigator.pop(context);
                  },
                  child: const Text('생성'),
                ),
              ],
            ),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}