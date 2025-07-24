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
      'https://file.notion.so/f/f/b940d603-de69-4a88-92da-6f46a5fdab6c/3f44e8b3-77d6-4d88-ab6a-53ad13bce94a/default_profile.png?table=block&id=23ab2ff3-c1ef-804a-be3b-cc8017c8944c&spaceId=b940d603-de69-4a88-92da-6f46a5fdab6c&expirationTimestamp=1753351200000&signature=MB6uUYslHj_TAcCCnCCqj8iTC6o_ve3-DRnsziL0MMk&downloadName=default_profile.png',
      'https://file.notion.so/f/f/b940d603-de69-4a88-92da-6f46a5fdab6c/7a6429f3-96ac-49a5-b31a-37a245fcfb32/default_profile2.png?table=block&id=23ab2ff3-c1ef-8071-8ae8-e8bc647e9724&spaceId=b940d603-de69-4a88-92da-6f46a5fdab6c&expirationTimestamp=1753351200000&signature=Upy4-1r_KeQCCutCNUJ63m6r6kglIam71W4zSnHeUKE&downloadName=default_profile2.png',
      'https://file.notion.so/f/f/b940d603-de69-4a88-92da-6f46a5fdab6c/29cb2358-898b-4a7e-8c74-675f0938ceba/monkey.png?table=block&id=23ab2ff3-c1ef-80c7-ac22-e5c9cdff9c67&spaceId=b940d603-de69-4a88-92da-6f46a5fdab6c&expirationTimestamp=1753351200000&signature=Ac7oq32GU_CmluDXhcuXG_TVN4E2opGQ5FLEDPYbTD8&downloadName=monkey.png',
      'https://file.notion.so/f/f/b940d603-de69-4a88-92da-6f46a5fdab6c/ff38f469-884a-4206-bf8a-7fff40751964/turtle.png?table=block&id=23ab2ff3-c1ef-800d-93cc-d610e2e7c258&spaceId=b940d603-de69-4a88-92da-6f46a5fdab6c&expirationTimestamp=1753351200000&signature=7MvpnqRUm13MLHdXWZTv_KBOws8nOtlcF8fZL4_2kLE&downloadName=turtle.png',
      'https://example.com/image5.png',
      'https://example.com/image6.png',
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
                          child: const Icon(Icons.settings, size: 20),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text('닉네임: $nickname', style: const TextStyle(fontSize: 20)),
              ],
            ),
          );
        },
      ),
    );
  }
}

