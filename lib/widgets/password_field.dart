import 'package:flutter/material.dart';

class PasswordField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final String? Function(String?)? validator;
  final String? hint;
  final bool showStrength; // if true, optionally show a simple strength indicator
  final bool enabled;

  const PasswordField({
    super.key,
    required this.controller,
    this.label = 'Password',
    this.validator,
    this.hint,
    this.showStrength = false,
    this.enabled = true,
  });

  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  bool _obscure = true;
  String? _strengthLabel;

  void _toggle() => setState(() => _obscure = !_obscure);

  // Minimal strength calculation (for demo)
  void _updateStrength(String value) {
    if (!widget.showStrength) return;
    if (value.isEmpty) {
      _strengthLabel = null;
    } else if (value.length < 6) {
      _strengthLabel = 'Too short';
    } else if (value.length < 9) {
      _strengthLabel = 'Weak';
    } else if (value.length < 12) {
      _strengthLabel = 'Good';
    } else {
      _strengthLabel = 'Strong';
    }
    setState(() {});
  }

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(() => _updateStrength(widget.controller.text));
  }

  @override
  void dispose() {
    widget.controller.removeListener(() => _updateStrength(widget.controller.text));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: widget.controller,
          validator: widget.validator,
          enabled: widget.enabled,
          obscureText: _obscure,
          decoration: InputDecoration(
            labelText: widget.label,
            hintText: widget.hint,
            prefixIcon: const Icon(Icons.lock_outline),
            suffixIcon: IconButton(
              icon: Icon(_obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined),
              onPressed: _toggle,
            ),
            filled: true,
            fillColor: theme.cardColor,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: theme.colorScheme.primary, width: 2),
            ),
          ),
        ),
        if (widget.showStrength && _strengthLabel != null) ...[
          const SizedBox(height: 8),
          Text(
            _strengthLabel!,
            style: TextStyle(
              color: _strengthLabel == 'Strong'
                  ? Colors.green
                  : (_strengthLabel == 'Good' ? Colors.orange : Colors.red),
              fontSize: 12,
            ),
          ),
        ],
      ],
    );
  }
}
