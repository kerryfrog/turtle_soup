import 'package:flutter/material.dart';

class MessageBubble extends StatelessWidget {
  final String sender;
  final String text;
  final String profileUrl;
  final bool isMine;
  final Map<String, dynamic>? replyTo;

  const MessageBubble({
    super.key,
    required this.sender,
    required this.text,
    required this.profileUrl,
    required this.isMine,
    this.replyTo,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment:
          isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!isMine)
          CircleAvatar(
            radius: 16,
            backgroundImage: profileUrl.isNotEmpty
                ? NetworkImage(profileUrl)
                : const AssetImage('assets/default_profile.png') as ImageProvider,
          ),
        if (!isMine) const SizedBox(width: 8),
        Flexible(
          child: Column(
            crossAxisAlignment:
                isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              Text(
                sender,
                style: const TextStyle(fontSize: 12, color: Colors.black87),
              ),
              const SizedBox(height: 4),
              if (replyTo != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 4,
                    horizontal: 8,
                  ),
                  margin: const EdgeInsets.only(bottom: 4),
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    "${replyTo!['sender'] ?? ''}: ${replyTo!['text'] ?? ''}",
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.black54,
                    ),
                  ),
                ),
              Container(
                padding: const EdgeInsets.all(10),
                constraints: const BoxConstraints(maxWidth: 250),
                decoration: BoxDecoration(
                  color: isMine ? Colors.blue[100] : Colors.grey[300],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  text,
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}