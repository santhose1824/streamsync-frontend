import 'package:flutter/material.dart';

class LinkTextButton extends StatelessWidget {
  final String text;
  final VoidCallback onTap;
  final TextStyle? style;

  const LinkTextButton({
    super.key,
    required this.text,
    required this.onTap,
    this.style,
  });

  @override
  Widget build(BuildContext context) {
    final defaultStyle = TextStyle(
      color: Theme.of(context).colorScheme.primary,
      fontWeight: FontWeight.w600,
    );
    return GestureDetector(
      onTap: onTap,
      child: Text(text, style: style ?? defaultStyle),
    );
  }
}
