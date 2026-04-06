import 'package:flutter/material.dart';
import '../models/participant.dart';

class ParticipantCard extends StatelessWidget {
  final Participant participant;
  final VoidCallback onToggleSelect;
  final VoidCallback onLap;
  final VoidCallback onReset;

  const ParticipantCard({
    super.key,
    required this.participant,
    required this.onToggleSelect,
    required this.onLap,
    required this.onReset,
  });

  Color get _accent => participant.isRunning
      ? const Color(0xFF00B4D8)
      : participant.elapsed > Duration.zero
          ? const Color(0xFF48CAE4)
          : Colors.white24;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onToggleSelect,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: participant.isSelected ? const Color(0xFF0A2A3E) : const Color(0xFF051929),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: participant.isSelected ? const Color(0xFF0096C7) : Colors.white.withOpacity(0.07),
            width: participant.isSelected ? 1.5 : 1,
          ),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: 20, height: 20,
                    decoration: BoxDecoration(
                      color: participant.isSelected ? const Color(0xFF0096C7) : Colors.transparent,
                      borderRadius: BorderRadius.circular(5),
                      border: Border.all(
                        color: participant.isSelected ? const Color(0xFF0096C7) : Colors.white30,
                        width: 1.5,
                      ),
                    ),
                    child: participant.isSelected
                        ? const Icon(Icons.check, size: 13, color: Colors.white)
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      color: _accent.withOpacity(0.12),
                      shape: BoxShape.circle,
                      border: Border.all(color: _accent, width: 1.5),
                    ),
                    child: Center(
                      child: Text(
                        participant.name.substring(0, 1).toUpperCase(),
                        style: TextStyle(color: _accent, fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(participant.name,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15)),
                        const SizedBox(height: 2),
                        if (participant.isRunning)
                          Row(children: [
                            Container(width: 6, height: 6,
                                decoration: const BoxDecoration(color: Color(0xFF00B4D8), shape: BoxShape.circle)),
                            const SizedBox(width: 4),
                            const Text('En cours', style: TextStyle(color: Color(0xFF00B4D8), fontSize: 11)),
                          ])
                        else if (participant.laps.isNotEmpty)
                          Text('${participant.laps.length} lap(s)',
                              style: const TextStyle(color: Colors.white38, fontSize: 11))
                        else
                          const Text('En attente',
                              style: TextStyle(color: Colors.white24, fontSize: 11)),
                      ],
                    ),
                  ),
                  Text(
                    participant.formattedTime,
                    style: TextStyle(
                      color: participant.isRunning ? const Color(0xFF00B4D8) : Colors.white70,
                      fontSize: 21, fontWeight: FontWeight.w700, letterSpacing: 1,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ),
            if (participant.isRunning || participant.elapsed > Duration.zero)
              Container(
                decoration: BoxDecoration(
                    border: Border(top: BorderSide(color: Colors.white.withOpacity(0.05)))),
                padding: const EdgeInsets.fromLTRB(14, 7, 14, 9),
                child: Row(children: [
                  if (participant.isRunning)
                    _Btn(icon: Icons.flag_outlined, label: 'Lap',
                        color: const Color(0xFF0096C7), onTap: onLap),
                  const Spacer(),
                  _Btn(icon: Icons.refresh, label: 'Reset',
                      color: Colors.white38, onTap: onReset),
                ]),
              ),
            if (participant.laps.isNotEmpty)
              Container(
                decoration: BoxDecoration(
                    border: Border(top: BorderSide(color: Colors.white.withOpacity(0.05)))),
                padding: const EdgeInsets.fromLTRB(14, 7, 14, 9),
                child: Column(
                  children: participant.laps.map((lap) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(children: [
                      Text('Lap ${lap.lapNumber}',
                          style: const TextStyle(color: Colors.white38, fontSize: 12, fontWeight: FontWeight.w500)),
                      const SizedBox(width: 10),
                      Text(Participant.formatDuration(lap.lapTime),
                          style: const TextStyle(color: Color(0xFF48CAE4), fontSize: 13, fontWeight: FontWeight.w600)),
                      const Spacer(),
                      Text('Total : ${Participant.formatDuration(lap.totalTime)}',
                          style: const TextStyle(color: Colors.white24, fontSize: 11)),
                    ]),
                  )).toList(),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Btn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _Btn({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Row(children: [
      Icon(icon, color: color, size: 15),
      const SizedBox(width: 4),
      Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w500)),
    ]),
  );
}
