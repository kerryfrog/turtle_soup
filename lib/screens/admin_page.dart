import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminPage extends StatefulWidget {
  const AdminPage({super.key});

  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  bool _isAuthenticated = false;
  final _passwordController = TextEditingController();
  final String _adminPassword = 'admin1234'; // In a real app, use a more secure method.

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  void _login() {
    if (_passwordController.text == _adminPassword) {
      setState(() {
        _isAuthenticated = true;
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('비밀번호가 일치하지 않습니다.')),
      );
    }
  }

  Future<void> _approveProblem(DocumentSnapshot report) async {
    final reportData = report.data() as Map<String, dynamic>;
    await _firestore.collection('problems').add({
      'title': reportData['title'],
      'question': reportData['question'],
      'answer': reportData['answer'],
      'createdAt': FieldValue.serverTimestamp(),
    });
    await report.reference.delete();
  }

  Future<void> _rejectProblem(DocumentSnapshot report) async {
    await report.reference.delete();
  }

  Widget _buildLoginPage() {
    return Scaffold(
      appBar: AppBar(title: const Text('관리자 인증')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(labelText: '비밀번호'),
                onSubmitted: (_) => _login(),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _login,
                child: const Text('접속'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAdminPanel() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('관리자 패널 - 문제 제보 목록'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore.collection('problem_reports').orderBy('reportedAt', descending: true).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('오류: ${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final reports = snapshot.data!.docs;

          if (reports.isEmpty) {
            return const Center(child: Text('제보된 문제가 없습니다.'));
          }

          return ListView.builder(
            itemCount: reports.length,
            itemBuilder: (context, index) {
              final report = reports[index];
              final data = report.data() as Map<String, dynamic>;

              return Card(
                margin: const EdgeInsets.all(8.0),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('제목: ${data['title']}', style: const TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text('문제: ${data['question']}'),
                      const SizedBox(height: 8),
                      Text('정답: ${data['answer']}'),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => _approveProblem(report),
                            child: const Text('승인', style: TextStyle(color: Colors.green)),
                          ),
                          const SizedBox(width: 8),
                          TextButton(
                            onPressed: () => _rejectProblem(report),
                            child: const Text('거부', style: TextStyle(color: Colors.red)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _isAuthenticated ? _buildAdminPanel() : _buildLoginPage();
  }
}
