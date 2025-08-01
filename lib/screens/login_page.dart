import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:turtle_soup/theme/app_theme.dart';
import 'register_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';


class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _emailController = TextEditingController(text: 'a@naver.com');
  final TextEditingController _passwordController = TextEditingController(
    text: '111111',
  );
  bool _rememberMe = false;

  void _login() async {
    print('이메일/비밀번호 로그인 버튼 클릭됨');
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      print('로그인 성공!');

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isLoggedIn', _rememberMe);

      if (mounted) {
        Navigator.pushReplacementNamed(context, '/');
      }

    } on FirebaseAuthException catch (e) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('로그인 실패'),
          content: Text(e.message ?? '알 수 없는 오류가 발생했습니다.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('확인'),
            ),
          ],
        ),
      );
    } catch (e) {
      print('로그인 실패: $e');
    }
  }

  Future<void> _loginWithGoogle() async {
    print('Google 로그인 버튼 클릭됨');
    try {
      final GoogleSignInAccount? googleUser = await GoogleSignIn(clientId: '102119003728-b4fiegvc3rm092gvjfp9t5pkosp53idr.apps.googleusercontent.com').signIn();
      if (googleUser == null) {
        return; // 사용자가 로그인을 취소함
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential =
          await FirebaseAuth.instance.signInWithCredential(credential);
      final user = userCredential.user;

      if (user != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('isLoggedIn', _rememberMe);

        // Firestore에 사용자 정보 저장 또는 업데이트
        final userDocRef =
            FirebaseFirestore.instance.collection('users').doc(user.uid);
        final userDoc = await userDocRef.get();

        if (!userDoc.exists) {
          await userDocRef.set({
            'nickname': user.displayName,
            'profileUrl': user.photoURL,
            'uid': user.uid,
          });
        }

        if (mounted) {
          Navigator.pushReplacementNamed(context, '/');
        }
      }
    } on FirebaseAuthException catch (e) {
      print('Google 로그인 실패: ${e.message}');
    } catch (e) {
      print('Google 로그인 중 오류가 발생했습니다: $e');
    }
  }

  Future<void> _loginWithApple() async {
    print('Apple 로그인 버튼 클릭됨');
    try {
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );

      final appleCredential = OAuthProvider('apple.com').credential(
        idToken: credential.identityToken,
        accessToken: credential.authorizationCode,
      );

      final userCredential =
          await FirebaseAuth.instance.signInWithCredential(appleCredential);
      final user = userCredential.user;

      if (user != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('isLoggedIn', _rememberMe);

        // Firestore에 사용자 정보 저장 또는 업데이트
        final userDocRef =
            FirebaseFirestore.instance.collection('users').doc(user.uid);
        final userDoc = await userDocRef.get();

        if (!userDoc.exists) {
          await userDocRef.set({
            'nickname': user.displayName ?? 'Apple User',
            'profileUrl': user.photoURL,
            'uid': user.uid,
          });
        }

        if (mounted) {
          Navigator.pushReplacementNamed(context, '/');
        }
      }
    } on FirebaseAuthException catch (e) {
      print('Apple 로그인 실패: ${e.message}');
    } catch (e) {
      print('Apple 로그인 중 오류가 발생했습니다: $e');
    }
  }

  void _register() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const RegisterPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('로그인')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(labelText: '이메일'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(labelText: '비밀번호'),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Checkbox(
                        value: _rememberMe,
                        onChanged: (bool? value) {
                          setState(() {
                            _rememberMe = value ?? false;
                          });
                        },
                      ),
                      const Text('로그인 유지'),
                    ],
                  ),
                ),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _login,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(0.0),
                      ),
                    ),
                    child: const Text('로그인'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const SizedBox(height: 12), // 버튼 간 간격 추가
            GestureDetector(
              onTap: _loginWithGoogle,
              child: SizedBox(
                width: 220,
                height: 44,
                child: Image.asset(
                  'assets/login/google_login_logo.png',
                  fit: BoxFit.fill, // 이미지를 늘려서 채움
                ),
              ),
            ),
            const SizedBox(height: 12), // 버튼 간 간격 추가
            GestureDetector(
              onTap: _loginWithApple,
              child: SizedBox(
                width: 220,
                height: 44,
                child: Image.asset(
                  'assets/login/apple_login_logo.png',
                  fit: BoxFit.fill, // 이미지를 늘려서 채움
                ),
              ),
            ),
            const SizedBox(height: 12), // 버튼 간 간격 추가
            ElevatedButton(
              onPressed: _register,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50), // 너비 최대로, 높이 50
                backgroundColor: Colors.grey[300], // 회원가입 버튼 색상 변경
              ),
              child: const Text('이메일로 회원가입'),
            ),
          ],
        ),
      ),
    );
  }
}