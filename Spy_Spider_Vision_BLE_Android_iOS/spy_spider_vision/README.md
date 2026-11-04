# Spy Spider Vision — Android + iPhone BLE + ESP32-CAM build

This Flutter project is configured for the two-board Spy Spider setup:

- **Main ESP32 DevKit (original ESP32):** Bluetooth Low Energy (BLE) device named `SPY-SPIDER`; controls the PCA9685 and eight servos.
- **AI Thinker ESP32-CAM:** creates the `SPIDER-CAM` Wi-Fi access point and serves an MJPEG stream.
- **Flutter app:** sends movement/servo commands over BLE on Android and iPhone, and receives the camera stream over Wi-Fi. Both connections can be active at once.

The existing app screens and theme are retained. Firmware sources and setup notes are in `firmware/`.

## 1. Build the Android app

Install Flutter (Dart 3.3 or newer) and Android SDK tools, then from this folder run:

```bash
flutter pub get
flutter doctor
flutter build apk --debug
```

The APK is created at `build/app/outputs/flutter-apk/app-debug.apk`. For a release APK use `flutter build apk --release`.

The included `codemagic.yaml` workflow also builds a **debug APK** and emails the configured notification address. It restores `gradle-wrapper.jar` if that file is absent. For a distributable release build, configure your own signing key in Codemagic and change the workflow to `flutter build apk --release`.

## 2. Upload the main ESP32 firmware

Open `firmware/main_esp32_spider/main_esp32_spider.ino` in Arduino IDE.

- Board: **DOIT ESP32 DEVKIT V1** or **ESP32 Dev Module** (original ESP32 with BLE; the firmware uses the ESP32 Arduino BLE libraries).
- Install libraries: **Adafruit PWM Servo Driver Library** and its dependencies.
- PCA9685 address: `0x40`; SDA GPIO 21; SCL GPIO 22.
- App servo channels `S1`–`S8` map to PCA9685 outputs `0`–`7`.
- Bluetooth device name: `SPY-SPIDER`.

## 3. Upload the ESP32-CAM firmware

Open `firmware/esp32_cam_stream/esp32_cam_stream.ino` in Arduino IDE.

- Board: **AI Thinker ESP32-CAM**.
- Camera: OV2640 using the AI Thinker pin map.
- Wi-Fi SSID: `SPIDER-CAM`; password: `12345678`.
- Stream URL: `http://192.168.4.1:81/stream`.
- Test page: `http://192.168.4.1`.

In the app's Camera Settings, use the stream URL above. The default is already set to this address.

## 4. Connect the phone

1. Open Spy Spider Vision, scan for BLE devices, select `SPY-SPIDER`, and connect. Do not pair it from the phone Bluetooth settings first.
2. Connect the phone's Wi-Fi to `SPIDER-CAM` using password `12345678`. If Android warns that the network has no internet, choose **Stay connected**.
4. Open the camera/control screen. If needed, set Camera Settings to `http://192.168.4.1:81/stream`.

The phone uses BLE for robot control and Wi-Fi for video simultaneously. The main ESP32 does not need to create a Wi-Fi network.

## 5. Command protocol

Commands are newline-terminated by the app's BLE service and parsed by the main ESP32 firmware.

| Command | Action |
|---|---|
| `F` / `B` | Forward / backward |
| `L` / `R` | Turn left / right |
| `X` | Stop movement and return to stand |
| `P:STAND` / `P:HOME` | Stand / home pose |
| `P:SIT` | Crouch pose |
| `P:WALK` | Walk forward |
| `P:RESET` | Clear the emergency-stop latch and stand |
| `ESTOP` | Emergency stop; movement remains locked until reset |
| `S1:90` … `S8:90` | Set an individual servo angle (0–180 degrees) |
| `SPEED:50` | Set gait speed (0–100) |
| `MODE:MANUAL` / `MODE:AUTO` | Mode marker; current firmware keeps direct commands enabled in either mode |

The AI Detection screen performs object detection **on the phone** using Google ML Kit and actual frames from the ESP32-CAM. It does not currently send autonomous navigation or obstacle-avoidance commands to the robot. Those behaviors require a separately designed control algorithm and safety testing.

## 6. Power and first test

- Never power the eight servos from the ESP32 3.3V pin or USB programmer.
- Use a separate regulated 5V servo supply with enough current for the servos.
- Connect servo-supply GND, PCA9685 GND, and main ESP32 GND together.
- Connect PCA9685 V+ to the servo supply positive and PCA9685 logic VCC to 3.3V.
- Power the ESP32-CAM from a stable 5V supply.
- Disconnect power before changing wiring.
- First test with the robot lifted off the floor. Verify each servo's center and direction before attempting to walk. Gait angles are starting values and may need mechanical calibration for your frame.

## Notes

- This firmware uses BLE GATT with Nordic-UART-compatible UUIDs, supported by Android and iOS. Upload this updated firmware; the previous Bluetooth Classic firmware will not work with this app.
- The app requests BLE and network permissions. It does not use the phone's camera; video comes from the separate ESP32-CAM.
- Android cleartext HTTP is enabled for the local ESP32-CAM MJPEG stream.
- `android/gradle/wrapper/gradle-wrapper.jar` and machine-specific `local.properties` are not included. The Codemagic workflow restores the wrapper JAR when needed; local Flutter/Android Studio setup generates machine-specific properties.


## iPhone build
The iOS project is included. To create and sign an iPhone app, open `ios/Runner.xcworkspace` in Xcode on macOS, configure your Apple developer signing team, then archive or distribute through TestFlight. Windows alone cannot create the final signed iOS IPA.
