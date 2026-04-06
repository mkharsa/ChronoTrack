/*
 * Connected ChronoTrack — Firmware ESP32
 * 3 boutons BLE : START (GPIO 12) / STOP (GPIO 14) / LAP (GPIO 27)
 * Arduino IDE → Board : "ESP32 Dev Module"
 */
#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h>

#define SERVICE_UUID    "4fafc201-1fb5-459e-8fcc-c5c9c331914b"
#define START_CHAR_UUID "beb5483e-36e1-4688-b7f5-ea07361b26a8"
#define STOP_CHAR_UUID  "beb5483e-36e1-4688-b7f5-ea07361b26a9"
#define LAP_CHAR_UUID   "beb5483e-36e1-4688-b7f5-ea07361b26aa"

#define PIN_START 12
#define PIN_STOP  14
#define PIN_LAP   27

BLECharacteristic *cStart, *cStop, *cLap;
bool connected = false;
unsigned long tStart=0, tStop=0, tLap=0;
const unsigned long DB = 200;

struct ServerCB : BLEServerCallbacks {
  void onConnect(BLEServer*)    { connected = true;  Serial.println("Connecte"); }
  void onDisconnect(BLEServer*) { connected = false; BLEDevice::startAdvertising(); }
};

void setup() {
  Serial.begin(115200);
  pinMode(PIN_START, INPUT_PULLUP);
  pinMode(PIN_STOP,  INPUT_PULLUP);
  pinMode(PIN_LAP,   INPUT_PULLUP);
  BLEDevice::init("ChronoTrack");
  auto* srv = BLEDevice::createServer();
  srv->setCallbacks(new ServerCB());
  auto* svc = srv->createService(SERVICE_UUID);
  auto mk = [&](const char* u) {
    auto* c = svc->createCharacteristic(u, BLECharacteristic::PROPERTY_NOTIFY);
    c->addDescriptor(new BLE2902());
    return c;
  };
  cStart = mk(START_CHAR_UUID);
  cStop  = mk(STOP_CHAR_UUID);
  cLap   = mk(LAP_CHAR_UUID);
  svc->start();
  BLEDevice::getAdvertising()->addServiceUUID(SERVICE_UUID);
  BLEDevice::startAdvertising();
  Serial.println("ChronoTrack BLE pret !");
}

void tryBtn(int pin, BLECharacteristic* c, uint8_t v, unsigned long& t) {
  if (digitalRead(pin) == LOW && (millis() - t) > DB) {
    t = millis();
    c->setValue(&v, 1);
    c->notify();
  }
}

void loop() {
  if (!connected) return;
  tryBtn(PIN_START, cStart, 0x01, tStart);
  tryBtn(PIN_STOP,  cStop,  0x02, tStop);
  tryBtn(PIN_LAP,   cLap,   0x03, tLap);
  delay(10);
}
