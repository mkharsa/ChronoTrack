import 'dart:async';

const String SERVICE_UUID      = "4fafc201-1fb5-459e-8fcc-c5c9c331914b";
const String START_CHAR_UUID   = "beb5483e-36e1-4688-b7f5-ea07361b26a8";
const String STOP_CHAR_UUID    = "beb5483e-36e1-4688-b7f5-ea07361b26a9";
const String LAP_ALL_CHAR_UUID = "beb5483e-36e1-4688-b7f5-ea07361b26aa";

enum IoTCommand { start, stop, lapAll }

abstract class IoTService {
  Stream<IoTCommand> get commandStream;
  Future<void> connect();
  Future<void> disconnect();
  bool get isConnected;
}

class SimulatedIoTService implements IoTService {
  final _controller = StreamController<IoTCommand>.broadcast();
  bool _connected = false;

  @override Stream<IoTCommand> get commandStream => _controller.stream;
  @override bool get isConnected => _connected;
  @override Future<void> connect() async {
    await Future.delayed(const Duration(milliseconds: 300));
    _connected = true;
  }
  @override Future<void> disconnect() async => _connected = false;

  void simulateCommand(IoTCommand cmd) {
    if (_connected) _controller.add(cmd);
  }
  void dispose() => _controller.close();
}
