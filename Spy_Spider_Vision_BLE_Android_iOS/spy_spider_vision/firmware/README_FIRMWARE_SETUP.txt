SPY SPIDER VISION - BLE FIRMWARE INTEGRATION
============================================

HARDWARE
--------
1) Main ESP32 DevKit V1 (original ESP32)
   - PCA9685 at I2C address 0x40
   - SDA = GPIO21, SCL = GPIO22
   - PCA9685 channels 0..7 control app servo channels S1..S8
   - BLE device name: SPY-SPIDER
   - Upload: firmware/main_esp32_spider/main_esp32_spider.ino

2) AI Thinker ESP32-CAM (OV2640)
   - Upload: firmware/esp32_cam_stream/esp32_cam_stream.ino
   - Wi-Fi AP: SPIDER-CAM
   - Password: 12345678
   - Stream URL: http://192.168.4.1:81/stream
   - Web test page: http://192.168.4.1

BLE APP CONNECTION
------------------
1. Upload the updated main ESP32 firmware below.
2. Open Spy Spider Vision and choose Connect / Scan.
3. Select SPY-SPIDER. Do not pair it from the phone's Bluetooth settings first.
4. Connect phone Wi-Fi to SPIDER-CAM (password 12345678). If asked about no internet, stay connected.
5. In Camera Settings, use http://192.168.4.1:81/stream.
6. Open the camera/control screen. BLE control and Wi-Fi video work concurrently.

UPLOAD MAIN ESP32 FIRMWARE
--------------------------
1. Install Arduino IDE and select the board "ESP32 Dev Module".
2. Install library "Adafruit PWM Servo Driver Library" from Library Manager.
3. Select the correct COM port and upload firmware/main_esp32_spider/main_esp32_spider.ino.
4. The BLEDevice/BLEServer libraries are included with the Espressif ESP32 Arduino board package.
5. If compilation says BLEDevice.h is missing, update/reinstall the Espressif ESP32 board package.

BLE UUIDs (must match the app)
------------------------------
Service:        6e400001-b5a3-f393-e0a9-e50e24dcca9e
Phone writes:   6e400002-b5a3-f393-e0a9-e50e24dcca9e
ESP32 notifies: 6e400003-b5a3-f393-e0a9-e50e24dcca9e

COMMAND PROTOCOL
----------------
F          forward
B          backward
L          turn left
R          turn right
X          stop
S1:90      set app servo channel 1 to 90 degrees (S1..S8)
SPEED:50   gait speed (0..100)
P:STAND    stand
P:SIT      crouch
P:HOME     home/stand
P:WALK     walk forward
P:RESET    clear emergency stop and stand
ESTOP      emergency stop

IMPORTANT POWER / SAFETY
------------------------
- Do NOT power 8 servos from ESP32 5V/3.3V or USB programmer pins.
- Use a separate regulated servo supply sized for your servos.
- Connect servo-supply GND, PCA9685 GND, and main ESP32 GND together.
- PCA9685 V+ goes to servo supply positive; logic VCC goes to 3.3V.
- Disconnect power before changing servo wiring.
- Test with robot lifted off the floor and legs unobstructed.
- Confirm each servo's mechanical center and direction before walking.
- Emergency stop is ESTOP; reset/re-arm is P:RESET.

NOTES
-----
- BLE is used for robot control on Android and iOS; the ESP32-CAM still uses Wi-Fi for video.
- The original ESP32 DevKit V1 supports BLE. The app scans for the advertised name SPY-SPIDER.
- The iOS app must be built and signed with Xcode on macOS (local Mac or cloud Mac).
- Servo gait geometry and pulse range must be calibrated to your actual frame before floor testing.
