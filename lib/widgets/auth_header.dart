import 'package:flutter/material.dart';

class AuthHeader extends StatelessWidget {
  String text;
   AuthHeader({super.key,required this.text});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 96,
          height: 96,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.18),
            shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 20, offset: const Offset(0, 10))],
          ),
          child: const Icon(Icons.play_circle_outline, size: 52, color: Colors.white),
        ),
        const SizedBox(height: 20),
        const Text('Stream Sync', style: TextStyle(fontSize: 34, fontWeight: FontWeight.bold, color: Colors.white)),
        const SizedBox(height: 8),
        Text(text, textAlign: TextAlign.center, style: TextStyle(fontSize: 15, color: Colors.white.withOpacity(0.9))),
        const SizedBox(height: 32),
      ],
    );
  }
}

