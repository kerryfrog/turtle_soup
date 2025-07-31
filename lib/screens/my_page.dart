import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:turtle_soup/screens/report_problem_page.dart';

class MyPage extends StatefulWidget {
  const MyPage({super.key});

  @override
  State<MyPage> createState() => _MyPageState();
}

class _MyPageState extends State<MyPage> {
  String? _profileUrl;
  bool _isEditingNickname = false;
  late TextEditingController _nicknameController;

  @override
  void initState() {
    super.initState();
    _nicknameController = TextEditingController();
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    super.dispose();
  }

  Future<void> _updateNickname(String uid, String currentNickname) async {
    final newNickname = _nicknameController.text.trim();
    if (newNickname.isEmpty || newNickname == currentNickname) {
      setState(() {
        _isEditingNickname = false;
      });
      return;
    }

    // Check if nickname already exists
    final querySnapshot = await FirebaseFirestore.instance
        .collection('users')
        .where('nickname', isEqualTo: newNickname)
        .limit(1)
        .get();

    if (querySnapshot.docs.isNotEmpty) {
      if (querySnapshot.docs.first.id != uid) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('이미 사용 중인 닉네임입니다.')),
          );
        }
        return;
      }
    }

    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .update({'nickname': newNickname});
    if (mounted) {
      setState(() {
        _isEditingNickname = false;
      });
    }
  }

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
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(user?.uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text('유저 정보가 없습니다.'));
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;
          final nickname = data['nickname'] ?? '닉네임 없음';
          final profileUrl = data['profileUrl'] as String?;

          final providerId = user?.providerData.first.providerId ?? '';
          String providerName;
          switch (providerId) {
            case 'google.com':
              providerName = 'Google';
              break;
            case 'apple.com':
              providerName = 'Apple';
              break;
            case 'password':
              providerName = '이메일/비밀번호';
              break;
            default:
              providerName = '알 수 없음';
          }

          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    CircleAvatar(
                      radius: 50,
                      backgroundImage: (profileUrl != null && profileUrl.isNotEmpty)
                          ? NetworkImage(profileUrl)
                          : const AssetImage('assets/default_profile.png') as ImageProvider,
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
                ListTile(
                  leading: const Icon(Icons.person),
                  title: _isEditingNickname
                      ? TextField(
                          controller: _nicknameController,
                          decoration: const InputDecoration(
                            labelText: '새 닉네임',
                            border: OutlineInputBorder(),
                          ),
                        )
                      : Text('닉네임: $nickname',
                          style: const TextStyle(fontSize: 20)),
                  trailing: _isEditingNickname
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.check, size: 20),
                              onPressed: () =>
                                  _updateNickname(user!.uid, nickname),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close, size: 20),
                              onPressed: () {
                                setState(() {
                                  _isEditingNickname = false;
                                });
                              },
                            ),
                          ],
                        )
                      : IconButton(
                          icon: const Icon(Icons.edit, size: 20),
                          onPressed: () {
                            setState(() {
                              _isEditingNickname = true;
                              _nicknameController.text =
                                  nickname; // Set initial value
                            });
                          },
                        ),
                ),
                ListTile(
                  leading: const Icon(Icons.email),
                  title: Row(
                    children: [
                      Text('이메일: ${user?.email ?? '이메일 없음'}',
                          style: const TextStyle(fontSize: 20)),
                      if (providerId == 'google.com')
                        Padding(
                          padding: const EdgeInsets.only(left: 8.0),
                          child: Image.asset('assets/login/google_small_logo.png',
                              width: 20, height: 20),
                        ),
                      if (providerId == 'apple.com')
                        const Padding(
                          padding: EdgeInsets.only(left: 8.0),
                          child: Icon(Icons.apple, size: 20),
                        ),
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

