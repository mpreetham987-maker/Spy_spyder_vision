/*
  SPY SPIDER - MAIN ESP32 FIRMWARE
  Hardware: classic ESP32 DevKit + PCA9685 at 0x40 + 8 servos
  App protocol: F, B, L, R, X, S1:90 ... S8:90, P:STAND, etc.
  Bluetooth Low Energy device name: SPY-SPIDER (Nordic UART service)
*/

#include <Arduino.h>
#include <Wire.h>
#include <Adafruit_PWMServoDriver.h>
#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h>

// Nordic UART-style BLE service. The Flutter app uses these same UUIDs.
#define SPIDER_SERVICE_UUID "6e400001-b5a3-f393-e0a9-e50e24dcca9e"
#define SPIDER_RX_UUID      "6e400002-b5a3-f393-e0a9-e50e24dcca9e" // phone writes here
#define SPIDER_TX_UUID      "6e400003-b5a3-f393-e0a9-e50e24dcca9e" // ESP32 notifies here

BLECharacteristic *txCharacteristic = nullptr;
String rxLine;
void handleCommand(String cmd);

void sendStatus(const String &message) {
  if (!txCharacteristic) return;
  txCharacteristic->setValue(message.c_str());
  txCharacteristic->notify();
}

class SpiderRxCallbacks : public BLECharacteristicCallbacks {
  void onWrite(BLECharacteristic *characteristic) override {
    std::string value = characteristic->getValue();
    for (char c : value) {
      if (c == '\n' || c == '\r') {
        if (rxLine.length()) handleCommand(rxLine);
        rxLine = "";
      } else if (rxLine.length() < 48) {
        rxLine += c;
      } else {
        rxLine = "";
      }
    }
  }
};
Adafruit_PWMServoDriver pca(0x40);

const int SERVO_MIN_PULSE = 110;
const int SERVO_MAX_PULSE = 510;

// App channels S1..S8 map to PCA9685 channels 0..7.
const uint8_t servoChannel[8] = {0, 1, 2, 3, 4, 5, 6, 7};

int hipCenter[4] = {90, 90, 90, 90};
int legCenter[4] = {90, 90, 90, 90};
int hipDir[4] = {1, -1, 1, -1};
int legDir[4] = {1, -1, 1, -1};

const int STRIDE = 25;
const int LIFT_ANGLE = 30;

enum Movement { STOPPED, FORWARD, REVERSE, TURN_LEFT, TURN_RIGHT };
Movement movement = STOPPED;

int gaitStep = 0;
int gaitPhase = 0;
unsigned long lastGait = 0;
int phaseTime = 140;
bool emergencyLatched = false;

void setServo(uint8_t appChannel, int angle) {
  if (appChannel < 1 || appChannel > 8) return;
  angle = constrain(angle, 0, 180);
  int pulse = map(angle, 0, 180, SERVO_MIN_PULSE, SERVO_MAX_PULSE);
  pca.setPWM(servoChannel[appChannel - 1], 0, pulse);
}

void setHip(int leg, int relative) {
  int angle = constrain(hipCenter[leg] + relative * hipDir[leg], 0, 180);
  setServo(leg * 2 + 1, angle);
}

void setLeg(int leg, int relative) {
  int angle = constrain(legCenter[leg] + relative * legDir[leg], 0, 180);
  setServo(leg * 2 + 2, angle);
}

void standPose() {
  for (int leg = 0; leg < 4; leg++) {
    setHip(leg, 0);
    setLeg(leg, 0);
  }
}

void sitPose() {
  // Conservative crouch. Adjust after testing your linkage.
  for (int leg = 0; leg < 4; leg++) {
    setHip(leg, 0);
    setLeg(leg, -20);
  }
}

void liftPairA() { setLeg(0, -LIFT_ANGLE); setLeg(3, -LIFT_ANGLE); }
void lowerPairA() { setLeg(0, 0); setLeg(3, 0); }
void liftPairB() { setLeg(1, -LIFT_ANGLE); setLeg(2, -LIFT_ANGLE); }
void lowerPairB() { setLeg(1, 0); setLeg(2, 0); }

void forwardPairA() {
  setHip(0, STRIDE); setHip(3, STRIDE);
  setHip(1, -STRIDE); setHip(2, -STRIDE);
}
void forwardPairB() {
  setHip(1, STRIDE); setHip(2, STRIDE);
  setHip(0, -STRIDE); setHip(3, -STRIDE);
}
void reversePairA() {
  setHip(0, -STRIDE); setHip(3, -STRIDE);
  setHip(1, STRIDE); setHip(2, STRIDE);
}
void reversePairB() {
  setHip(1, -STRIDE); setHip(2, -STRIDE);
  setHip(0, STRIDE); setHip(3, STRIDE);
}
void leftPairA() {
  setHip(0, -STRIDE); setHip(3, STRIDE);
  setHip(1, STRIDE); setHip(2, -STRIDE);
}
void leftPairB() {
  setHip(1, -STRIDE); setHip(2, STRIDE);
  setHip(0, STRIDE); setHip(3, -STRIDE);
}
void rightPairA() {
  setHip(0, STRIDE); setHip(3, -STRIDE);
  setHip(1, -STRIDE); setHip(2, STRIDE);
}
void rightPairB() {
  setHip(1, -STRIDE); setHip(2, -STRIDE);
  setHip(0, -STRIDE); setHip(3, STRIDE);
}

void runGait() {
  if (gaitStep == 0) {
    if (gaitPhase == 0) liftPairA();
    else if (gaitPhase == 1) {
      if (movement == FORWARD) forwardPairA();
      else if (movement == REVERSE) reversePairA();
      else if (movement == TURN_LEFT) leftPairA();
      else if (movement == TURN_RIGHT) rightPairA();
    } else lowerPairA();

    if (++gaitPhase > 2) { gaitPhase = 0; gaitStep = 1; }
  } else {
    if (gaitPhase == 0) liftPairB();
    else if (gaitPhase == 1) {
      if (movement == FORWARD) forwardPairB();
      else if (movement == REVERSE) reversePairB();
      else if (movement == TURN_LEFT) leftPairB();
      else if (movement == TURN_RIGHT) rightPairB();
    } else lowerPairB();

    if (++gaitPhase > 2) { gaitPhase = 0; gaitStep = 0; }
  }
}

void startMovement(Movement next) {
  if (emergencyLatched) return;
  movement = next;
  gaitStep = 0;
  gaitPhase = 0;
  lastGait = millis();
}

void handleCommand(String cmd) {
  cmd.trim();
  if (!cmd.length()) return;

  if (cmd == "ESTOP") {
    emergencyLatched = true;
    movement = STOPPED;
    standPose();
    sendStatus("STATUS:MODE=EMERGENCY_STOP\n");
    return;
  }

  if (cmd == "P:RESET") {
    emergencyLatched = false;
    movement = STOPPED;
    standPose();
    sendStatus("STATUS:MODE=MANUAL\n");
    return;
  }

  if (emergencyLatched) return;

  if (cmd == "F") startMovement(FORWARD);
  else if (cmd == "B") startMovement(REVERSE);
  else if (cmd == "L") startMovement(TURN_LEFT);
  else if (cmd == "R") startMovement(TURN_RIGHT);
  else if (cmd == "X") { movement = STOPPED; standPose(); }
  else if (cmd == "P:STAND" || cmd == "P:HOME") {
    movement = STOPPED; standPose();
  }
  else if (cmd == "P:SIT") {
    movement = STOPPED; sitPose();
  }
  else if (cmd == "P:WALK") startMovement(FORWARD);
  else if (cmd.startsWith("SPEED:")) {
    int percent = constrain(cmd.substring(6).toInt(), 0, 100);
    // Higher percentage means faster gait; keep a safe minimum interval.
    phaseTime = map(percent, 0, 100, 260, 70);
  }
  else if (cmd.startsWith("S") && cmd.indexOf(':') > 1) {
    int colon = cmd.indexOf(':');
    int channel = cmd.substring(1, colon).toInt();
    int angle = cmd.substring(colon + 1).toInt();
    if (channel >= 1 && channel <= 8) setServo(channel, angle);
  }
  else if (cmd == "MODE:MANUAL" || cmd == "MODE:AUTO") {
    // Both modes currently accept manual movement commands.
  }
}

void setup() {
  Serial.begin(115200);
  Wire.begin(21, 22);
  pca.begin();
  pca.setPWMFreq(50);
  delay(300);
  standPose();

  BLEDevice::init("SPY-SPIDER");
  BLEDevice::setMTU(100);
  BLEServer *server = BLEDevice::createServer();
  BLEService *service = server->createService(SPIDER_SERVICE_UUID);

  BLECharacteristic *rxCharacteristic = service->createCharacteristic(
    SPIDER_RX_UUID,
    BLECharacteristic::PROPERTY_WRITE | BLECharacteristic::PROPERTY_WRITE_NR
  );
  rxCharacteristic->setCallbacks(new SpiderRxCallbacks());

  txCharacteristic = service->createCharacteristic(
    SPIDER_TX_UUID,
    BLECharacteristic::PROPERTY_NOTIFY
  );
  txCharacteristic->addDescriptor(new BLE2902());

  service->start();
  BLEAdvertising *advertising = BLEDevice::getAdvertising();
  advertising->addServiceUUID(SPIDER_SERVICE_UUID);
  advertising->setScanResponse(true);
  advertising->start();

  Serial.println("SPY-SPIDER BLE ready; connect using Spy Spider Vision");
  sendStatus("STATUS:MODE=MANUAL\n");
}

void loop() {
  if (!emergencyLatched && movement != STOPPED &&
      millis() - lastGait >= (unsigned long)phaseTime) {
    lastGait = millis();
    runGait();
  }
}
