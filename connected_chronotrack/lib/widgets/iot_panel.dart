import 'package:flutter/material.dart';
import '../services/iot_service.dart';

class IoTPanel extends StatelessWidget {
  final bool isConnected;
  final SimulatedIoTService iotService;
  final bool anySelected, anyRunning;
  final VoidCallback onStart, onStop, onLapAll, onResetAll;

  const IoTPanel({
    super.key,
    required this.isConnected,
    required this.iotService,
    required this.anySelected,
    required this.anyRunning,
    required this.onStart,
    required this.onStop,
    required this.onLapAll,
    required this.onResetAll,
  });

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: const Color(0xFF051929),
      border: Border(top: BorderSide(color: Colors.white.withOpacity(0.07))),
    ),
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(children: [
          Icon(Icons.bluetooth_connected, size: 13,
              color: isConnected ? const Color(0xFF0096C7) : Colors.white24),
          const SizedBox(width: 6),
          Text(
            isConnected ? 'Boîtier IoT connecté' : 'Boîtier IoT non connecté — contrôle manuel',
            style: TextStyle(
              color: isConnected ? const Color(0xFF0096C7).withOpacity(0.7) : Colors.white24,
              fontSize: 11,
            ),
          ),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          _Btn(label: 'START', icon: Icons.play_arrow_rounded, color: const Color(0xFF00B4D8),
              enabled: anySelected && !anyRunning, onTap: onStart, flex: 3),
          const SizedBox(width: 8),
          _Btn(label: 'STOP',  icon: Icons.stop_rounded,       color: const Color(0xFFEF476F),
              enabled: anyRunning, onTap: onStop, flex: 3),
          const SizedBox(width: 8),
          _Btn(label: 'LAP',   icon: Icons.flag_rounded,       color: const Color(0xFFFFB703),
              enabled: anyRunning, onTap: onLapAll, flex: 2),
          const SizedBox(width: 8),
          _Btn(label: 'RESET', icon: Icons.refresh_rounded,    color: Colors.white38,
              enabled: true, onTap: onResetAll, flex: 2),
        ]),
      ],
    ),
  );
}

class _Btn extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool enabled;
  final VoidCallback onTap;
  final int flex;

  const _Btn({
    required this.label, required this.icon, required this.color,
    required this.enabled, required this.onTap, required this.flex,
  });

  @override
  Widget build(BuildContext context) => Expanded(
    flex: flex,
    child: GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedOpacity(
        opacity: enabled ? 1.0 : 0.28,
        duration: const Duration(milliseconds: 180),
        child: Container(
          height: 52,
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.35), width: 1.5),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(height: 2),
              Text(label, style: TextStyle(
                  color: color, fontSize: 10,
                  fontWeight: FontWeight.w700, letterSpacing: 0.8)),
            ],
          ),
        ),
      ),
    ),
  );
}
