#include <Arduino.h>
#include "rpcBLEDevice.h"
#include <TFT_eSPI.h>
#include <SPI.h>

TFT_eSPI tft;

#define SERVICE_UUID        "12345678-1234-5678-1234-56789abcdef0"
#define CHARACTERISTIC_UUID "abcdefab-cdef-1234-5678-1234567890ab"

BLEServer* pServer = nullptr;
BLEService* pService = nullptr;
BLECharacteristic* pCharacteristic = nullptr;

bool bluetoothEnabled = false;
bool deviceConnected = false;

String blePayload = "longitude and latitude data";

void toggleBluetooth();
void drawBluetoothScreen();

class MyServerCallbacks : public BLEServerCallbacks {
  void onConnect(BLEServer* pServer) {
    deviceConnected = true;
    Serial.println("Device Connected");
    drawBluetoothScreen();
  }

  void onDisconnect(BLEServer* pServer) {
    deviceConnected = false;
    Serial.println("Device Disconnected");
    if (bluetoothEnabled) {
      BLEDevice::getAdvertising()->start();
    }
    drawBluetoothScreen();
  }
};

// Function to update BLE payload dynamically
void updateBLEPayload(String newPayload) {
  blePayload = newPayload;
  if (pCharacteristic != nullptr) {
    pCharacteristic->setValue(blePayload.c_str());
    pCharacteristic->notify();  // Send notification to connected device
    Serial.println("BLE Payload Updated: " + blePayload);
  }
}

void setup() {
  Serial.begin(115200);

  tft.begin();
  tft.setRotation(3);
  tft.fillScreen(TFT_BLACK);

  pinMode(WIO_KEY_B, INPUT_PULLUP);  // Middle top button

  BLEDevice::init("WioTerminal");

  drawBluetoothScreen();
}

void loop() {
  static bool lastButtonState = HIGH;
  bool buttonState = digitalRead(WIO_KEY_B);
  if (lastButtonState == HIGH && buttonState == LOW) {
    delay(200);  // debounce
    toggleBluetooth();
    drawBluetoothScreen();
  }

  lastButtonState = buttonState;

  // Optional: Example to update payload periodically or based on some logic
  // Uncomment and customize if you want
  /*
  if (deviceConnected) {
    String examplePayload = "{\"temp\":25.3,\"humidity\":40}"; 
    updateBLEPayload(examplePayload);
    delay(5000);  // send every 5 seconds
  }
  */
}

void toggleBluetooth() {
  bluetoothEnabled = !bluetoothEnabled;

  if (bluetoothEnabled) {
    pServer = BLEDevice::createServer();
    pServer->setCallbacks(new MyServerCallbacks());

    pService = pServer->createService(SERVICE_UUID);

    pCharacteristic = pService->createCharacteristic(
      CHARACTERISTIC_UUID,
      BLECharacteristic::PROPERTY_READ |
      BLECharacteristic::PROPERTY_NOTIFY
    );

    pCharacteristic->setValue(blePayload.c_str());
    pService->start();

    BLEAdvertising* pAdvertising = BLEDevice::getAdvertising();
    pAdvertising->addServiceUUID(SERVICE_UUID);
    pAdvertising->start();

    Serial.println("Bluetooth ON — Advertising...");
  } else {
    BLEDevice::deinit();
    Serial.println("Bluetooth OFF.");
    deviceConnected = false;
  }
}

void drawBluetoothScreen() {
  tft.fillScreen(TFT_BLACK);

  // Draw Bluetooth symbol
  tft.setTextColor(TFT_CYAN, TFT_BLACK);
  tft.setTextSize(5);
  tft.setCursor(60, 20);
  tft.print("B");
  tft.drawLine(80, 35, 100, 15, TFT_CYAN);
  tft.drawLine(80, 35, 100, 55, TFT_CYAN);
  tft.drawLine(100, 15, 100, 55, TFT_CYAN);

  tft.setTextSize(3);
  tft.setCursor(10, 100);
  tft.setTextColor(TFT_WHITE, TFT_BLACK);
  tft.print("Bluetooth:");

  tft.setTextColor(bluetoothEnabled ? TFT_GREEN : TFT_RED, TFT_BLACK);
  tft.setCursor(200, 100);
  tft.print(bluetoothEnabled ? "ON" : "OFF");

  if (bluetoothEnabled) {
    tft.setCursor(10, 150);
    tft.setTextColor(TFT_WHITE, TFT_BLACK);
    tft.print("Status:");

    tft.setTextColor(deviceConnected ? TFT_GREEN : TFT_RED, TFT_BLACK);
    tft.setCursor(150, 150);
    tft.print(deviceConnected ? "Connected" : "Waiting");
  }

  tft.setTextSize(2);
  tft.setTextColor(TFT_YELLOW, TFT_BLACK);
  tft.setCursor(10, 220);
  tft.print("Press Top Button B");
}