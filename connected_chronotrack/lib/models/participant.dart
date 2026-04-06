class Lap {
  final int lapNumber;
  final Duration lapTime;
  final Duration totalTime;

  Lap({required this.lapNumber, required this.lapTime, required this.totalTime});
}

class Participant {
  final String id;
  String name;
  bool isSelected;
  bool isRunning;
  Duration elapsed;
  DateTime? startTime;
  List<Lap> laps;

  Participant({
    required this.id,
    required this.name,
    this.isSelected = false,
    this.isRunning = false,
    this.elapsed = Duration.zero,
    this.startTime,
    List<Lap>? laps,
  }) : laps = laps ?? [];

  Duration get currentTotal {
    if (isRunning && startTime != null) {
      return elapsed + DateTime.now().difference(startTime!);
    }
    return elapsed;
  }

  String get formattedTime => formatDuration(currentTotal);

  void addLap() {
    final total = currentTotal;
    final prev = laps.isEmpty ? Duration.zero : laps.last.totalTime;
    laps.add(Lap(
      lapNumber: laps.length + 1,
      lapTime: total - prev,
      totalTime: total,
    ));
  }

  static String formatDuration(Duration d) {
    final mm = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final ss = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    final cs = (d.inMilliseconds.remainder(1000) ~/ 10).toString().padLeft(2, '0');
    return '$mm:$ss.$cs';
  }
}
