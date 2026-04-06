import 'package:flutter/material.dart';

class AddParticipantDialog extends StatefulWidget {
  final void Function(String name) onAdd;
  const AddParticipantDialog({super.key, required this.onAdd});
  @override
  State<AddParticipantDialog> createState() => _State();
}

class _State extends State<AddParticipantDialog> {
  final _ctrl = TextEditingController();

  @override
  Widget build(BuildContext context) => AlertDialog(
    backgroundColor: const Color(0xFF0A2A3E),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    title: const Text('Ajouter un participant',
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
    content: TextField(
      controller: _ctrl,
      autofocus: true,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: 'Nom du participant',
        hintStyle: const TextStyle(color: Colors.white38),
        filled: true,
        fillColor: Colors.white.withOpacity(0.05),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.white.withOpacity(0.1))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.white.withOpacity(0.1))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFF0096C7))),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Annuler', style: TextStyle(color: Colors.white38)),
      ),
      ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF0096C7),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        onPressed: () {
          final n = _ctrl.text.trim();
          if (n.isNotEmpty) { widget.onAdd(n); Navigator.pop(context); }
        },
        child: const Text('Ajouter'),
      ),
    ],
  );
}
