import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'register_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';

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

  void _login() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      print('로그인 성공!');
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
            const SizedBox(height: 24),
            ElevatedButton(onPressed: _login, child: const Text('로그인')),
            ElevatedButton.icon(
              onPressed: _loginWithGoogle,
              icon: const Icon(Icons.login),
              label: const Text('Google로 로그인'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.black),
            ),
            TextButton(onPressed: _register, child: const Text('회원가입')),
          ],
        ),
      ),
    );
  }
}