import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class MyPage extends StatefulWidget {
  const MyPage({super.key});

  @override
  State<MyPage> createState() => _MyPageState();
}

class _MyPageState extends State<MyPage> {
  String? _profileUrl;

  void _selectProfile(BuildContext context, String uid) {
    final List<String> profileOptions = [
      'https://i.postimg.cc/XWRnNWY8/default-profile.png',
      'https://i.postimg.cc/kXjkPKT7/default-profile2.png',
      'https://i.postimg.cc/sX9N6hBd/monkey.png',
      'https://i.postimg.cc/bNvBgdpW/turtle.png'
    ];

    showModalBottomSheet(
      context: context,
      builder: (context) {
        return GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
          ),
          itemCount: profileOptions.length,
          itemBuilder: (context, index) {
            final url = profileOptions[index];
            return GestureDetector(
              onTap: () async {
                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(uid)
                    .update({'profileUrl': url});
                if (mounted) {
                  Navigator.pop(context);
                  setState(() {
                    _profileUrl = url;
                  });
                }
              },
              child: CircleAvatar(
                backgroundImage: NetworkImage(url),
                radius: 40,
              ),
            );
          },
        );
      },
    );
  }

  void _showNicknameChangeDialog(String currentNickname, String uid) {
    TextEditingController nicknameController = TextEditingController(text: currentNickname);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('닉네임 변경'),
          content: TextField(
            controller: nicknameController,
            decoration: const InputDecoration(hintText: '새 닉네임을 입력하세요'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () async {
                final newNickname = nicknameController.text.trim();
                if (newNickname.isNotEmpty && newNickname != currentNickname) {
                  // Check if nickname already exists
                  final querySnapshot = await FirebaseFirestore.instance
                      .collection('users')
                      .where('nickname', isEqualTo: newNickname)
                      .limit(1)
                      .get();

                  if (querySnapshot.docs.isNotEmpty) {
                    // Nickname already exists, check if it's the current user's nickname
                    if (querySnapshot.docs.first.id != uid) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('이미 사용 중인 닉네임입니다.')),
                        );
                        Navigator.pop(context);
                      }
                      return; // Stop further execution
                    }
                  }

                  await FirebaseFirestore.instance
                      .collection('users')
                      .doc(uid)
                      .update({'nickname': newNickname});
                  if (mounted) {
                    Navigator.pop(context);
                    setState(() {}); // Rebuild to show updated nickname
                  }
                } else {
                  if (mounted) {
                    Navigator.pop(context);
                  }
                }
              },
              child: const Text('변경'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('마이페이지'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: '환경 설정',
            onPressed: () {
              Navigator.pushNamed(context, '/settings');
            },
          ),
        ],
      ),
      body: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance
            .collection('users')
            .doc(user?.uid)
            .get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text('유저 정보가 없습니다.'));
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;
          final nickname = data['nickname'] ?? '닉네임 없음';
          _profileUrl ??= data['profileUrl'] ?? 'https://via.placeholder.com/150'; // 기본 이미지

          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    CircleAvatar(
                      radius: 50,
                      backgroundImage: NetworkImage(_profileUrl!),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: GestureDetector(
                        onTap: () {
                          if (user?.uid != null) {
                            _selectProfile(context, user!.uid);
                          }
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black26,
                                blurRadius: 4,
                              ),
                            ],
                          ),
                          padding: const EdgeInsets.all(4),
                          child: const Icon(Icons.edit, size: 20),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text('닉네임: $nickname', style: const TextStyle(fontSize: 20)),
                ListTile(
                  leading: const Icon(Icons.edit_note),
                  title: const Text('닉네임 변경'),
                  onTap: () {
                    if (user?.uid != null) {
                      _showNicknameChangeDialog(nickname, user!.uid);
                    }
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

