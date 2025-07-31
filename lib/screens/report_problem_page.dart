import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ReportProblemPage extends StatefulWidget {
  const ReportProblemPage({super.key});

  @override
  State<ReportProblemPage> createState() => _ReportProblemPageState();
}

class _ReportProblemPageState extends State<ReportProblemPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _questionController = TextEditingController();
  final _answerController = TextEditingController();

  @override
  void dispose() {
    _titleController.dispose();
    _questionController.dispose();
    _answerController.dispose();
    super.dispose();
  }

  Future<void> _submitReport() async {
    if (_formKey.currentState!.validate()) {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('로그인이 필요합니다.')),
        );
        return;
      }

      await FirebaseFirestore.instance.collection('problem_reports').add({
        'title': _titleController.text,
        'question': _questionController.text,
        'answer': _answerController.text,
        'reporterUid': user.uid,
        'reportedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('문제 제보가 완료되었습니다.')),
        );
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('문제 제보하기'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: '문제 제목'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '문제 제목을 입력해주세요.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _questionController,
                decoration: const InputDecoration(labelText: '문제 내용'),
                maxLines: 5,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '문제 내용을 입력해주세요.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _answerController,
                decoration: const InputDecoration(labelText: '정답'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '정답을 입력해주세요.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _submitReport,
                child: const Text('제보하기'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
