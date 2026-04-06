import 'package:flutter/material.dart';
import '../models/participant.dart';
import '../services/iot_service.dart';
import '../controllers/chrono_controller.dart';
import '../widgets/participant_card.dart';
import '../widgets/iot_panel.dart';
import '../widgets/add_participant_dialog.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late SimulatedIoTService _iotService;
  late ChronoController _controller;
  bool _iotConnected = false;

  final List<Participant> _participants = [
    Participant(id: '1', name: 'Participant 1'),
    Participant(id: '2', name: 'Participant 2'),
    Participant(id: '3', name: 'Participant 3'),
  ];

  @override
  void initState() {
    super.initState();
    _iotService = SimulatedIoTService();
    _controller = ChronoController(
      participants: _participants,
      iotService: _iotService,
      onUpdate: () => setState(() {}),
    );
    _iotService.connect().then((_) => setState(() => _iotConnected = true));
  }

  @override
  void dispose() {
    _controller.dispose();
    _iotService.dispose();
    super.dispose();
  }

  bool get _anySelected   => _participants.any((p) => p.isSelected);
  bool get _anyRunning    => _participants.any((p) => p.isRunning);
  int  get _selectedCount => _participants.where((p) => p.isSelected).length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF03111E),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildSelectionBar(),
            Expanded(
              child: _participants.isEmpty
                  ? _buildEmpty()
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                      itemCount: _participants.length,
                      itemBuilder: (_, i) => ParticipantCard(
                        participant: _participants[i],
                        onToggleSelect: () => setState(() =>
                            _participants[i].isSelected = !_participants[i].isSelected),
                        onLap: () => _controller.lapParticipant(_participants[i].id),
                        onReset: () => _controller.resetParticipant(_participants[i].id),
                      ),
                    ),
            ),
            IoTPanel(
              isConnected: _iotConnected,
              iotService: _iotService,
              anySelected: _anySelected,
              anyRunning: _anyRunning,
              onStart: _controller.startSelected,
              onStop: _controller.stopSelected,
              onLapAll: _controller.lapAll,
              onResetAll: _controller.resetAll,
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => showDialog(
          context: context,
          builder: (_) => AddParticipantDialog(
            onAdd: (name) => setState(() => _participants.add(
              Participant(
                id: DateTime.now().millisecondsSinceEpoch.toString(),
                name: name,
              ),
            )),
          ),
        ),
        backgroundColor: const Color(0xFF0096C7),
        child: const Icon(Icons.person_add, color: Colors.white),
      ),
    );
  }

  Widget _buildHeader() => Padding(
    padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
    child: Row(
      children: [
        const Icon(Icons.timer, color: Color(0xFF0096C7), size: 28),
        const SizedBox(width: 10),
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Connected', style: TextStyle(color: Colors.white54, fontSize: 12, letterSpacing: 2)),
            Text('ChronoTrack', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
          ],
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: (_iotConnected ? const Color(0xFF0096C7) : Colors.red).withOpacity(0.12),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _iotConnected ? const Color(0xFF0096C7) : Colors.red),
          ),
          child: Row(children: [
            Icon(Icons.bluetooth, size: 13, color: _iotConnected ? const Color(0xFF0096C7) : Colors.red),
            const SizedBox(width: 4),
            Text(
              _iotConnected ? 'Connecté' : 'Déconnecté',
              style: TextStyle(
                color: _iotConnected ? const Color(0xFF0096C7) : Colors.red,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ]),
        ),
      ],
    ),
  );

  Widget _buildSelectionBar() => Padding(
    padding: const EdgeInsets.fromLTRB(20, 0, 12, 6),
    child: Row(
      children: [
        Text('$_selectedCount/${_participants.length} sélectionné(s)',
            style: const TextStyle(color: Colors.white38, fontSize: 12)),
        const Spacer(),
        TextButton(
          onPressed: () => setState(() { for (final p in _participants) p.isSelected = true; }),
          style: TextButton.styleFrom(foregroundColor: const Color(0xFF0096C7), padding: const EdgeInsets.symmetric(horizontal: 8)),
          child: const Text('Tous', style: TextStyle(fontSize: 12)),
        ),
        TextButton(
          onPressed: () => setState(() { for (final p in _participants) p.isSelected = false; }),
          style: TextButton.styleFrom(foregroundColor: Colors.white38, padding: const EdgeInsets.symmetric(horizontal: 8)),
          child: const Text('Aucun', style: TextStyle(fontSize: 12)),
        ),
      ],
    ),
  );

  Widget _buildEmpty() => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.group_add, size: 64, color: Colors.white12),
        const SizedBox(height: 16),
        const Text('Aucun participant', style: TextStyle(color: Colors.white24, fontSize: 16)),
        const SizedBox(height: 8),
        const Text('Appuie sur + pour en ajouter', style: TextStyle(color: Colors.white12, fontSize: 13)),
      ],
    ),
  );
}
