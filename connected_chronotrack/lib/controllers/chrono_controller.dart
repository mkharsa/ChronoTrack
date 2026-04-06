import 'dart:async';
import '../models/participant.dart';
import '../services/iot_service.dart';

typedef VoidCallback = void Function();

class ChronoController {
  final List<Participant> participants;
  final SimulatedIoTService iotService;
  final VoidCallback onUpdate;
  Timer? _ticker;
  StreamSubscription? _sub;

  ChronoController({
    required this.participants,
    required this.iotService,
    required this.onUpdate,
  }) {
    _sub = iotService.commandStream.listen((cmd) {
      switch (cmd) {
        case IoTCommand.start:  startSelected(); break;
        case IoTCommand.stop:   stopSelected(); break;
        case IoTCommand.lapAll: lapAll(); break;
      }
    });
  }

  void startSelected() {
    final now = DateTime.now();
    for (final p in participants) {
      if (p.isSelected && !p.isRunning) {
        p.startTime = now;
        p.isRunning = true;
      }
    }
    _startTicker();
    onUpdate();
  }

  void stopSelected() {
    for (final p in participants) {
      if (p.isSelected && p.isRunning) {
        p.elapsed = p.currentTotal;
        p.isRunning = false;
        p.startTime = null;
      }
    }
    _checkTicker();
    onUpdate();
  }

  void lapAll() {
    for (final p in participants) {
      if (p.isRunning) p.addLap();
    }
    onUpdate();
  }

  void lapParticipant(String id) {
    final p = participants.firstWhere((p) => p.id == id);
    if (p.isRunning) p.addLap();
    onUpdate();
  }

  void resetParticipant(String id) {
    final p = participants.firstWhere((p) => p.id == id);
    p.elapsed = Duration.zero;
    p.isRunning = false;
    p.startTime = null;
    p.laps.clear();
    _checkTicker();
    onUpdate();
  }

  void resetAll() {
    for (final p in participants) {
      p.elapsed = Duration.zero;
      p.isRunning = false;
      p.startTime = null;
      p.laps.clear();
    }
    _ticker?.cancel();
    _ticker = null;
    onUpdate();
  }

  void _startTicker() => _ticker ??=
      Timer.periodic(const Duration(milliseconds: 10), (_) => onUpdate());

  void _checkTicker() {
    if (!participants.any((p) => p.isRunning)) {
      _ticker?.cancel();
      _ticker = null;
    }
  }

  void dispose() {
    _ticker?.cancel();
    _sub?.cancel();
  }
}
