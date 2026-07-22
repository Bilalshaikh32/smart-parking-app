/*
  SMART PARKING SYSTEM - UPGRADED FINAL CODE
  Base: Original working Arduino code

  Existing connections kept:
    Entry IR OUT  -> D2
    Exit IR OUT   -> D3
    Servo signal  -> D9
    LCD SDA       -> A4
    LCD SCL       -> A5
    LCD address   -> 0x27
    Gate open     -> 90 degrees
    Gate closed   -> 0 degrees
    Gate open time-> 3000 ms

  New connections:
    Red LED       -> D4
    Yellow LED    -> D5
    Green LED     -> D6
    Slot 1 IR OUT -> D7
    Slot 2 IR OUT -> D8
    HC-05 TX      -> D10
    HC-05 RX      -> D11
    Slot 3 IR OUT -> D12
    Slot 4 IR OUT -> D13

  Flutter slot protocol:
    S1:0,S2:1,S3:0,S4:1
    0 = Available
    1 = Occupied

  Stable slot logic:
    - Car detected continuously for 1 second -> Occupied
    - Occupied slot clear continuously for 5 seconds -> Available
    - Short signal loss does not make the slot available
*/

#include <Wire.h>
#include <LiquidCrystal_I2C.h>
#include <Servo.h>
#include <SoftwareSerial.h>
#include <ctype.h>
#include <string.h>

// ======================================================
// OBJECTS
// ======================================================

LiquidCrystal_I2C lcd(0x27, 16, 2);
Servo gate;
SoftwareSerial bluetooth(10, 11); // Arduino RX, TX

// ======================================================
// ORIGINAL WORKING PINS
// ======================================================

#define IR_IN 2
#define IR_OUT 3
#define SERVO_PIN 9

// ======================================================
// NEW PINS
// ======================================================

#define RED_LED 4
#define YELLOW_LED 5
#define GREEN_LED 6

#define SLOT_1 7
#define SLOT_2 8
#define SLOT_3 12
#define SLOT_4 13

// ======================================================
// SETTINGS
// ======================================================

const byte TOTAL_SLOTS = 4;

const byte slotPins[TOTAL_SLOTS] = {
  SLOT_1,
  SLOT_2,
  SLOT_3,
  SLOT_4
};

/*
  Most IR obstacle sensors:
  LOW  = object/car detected
  HIGH = no object

  Change LOW to HIGH only if your sensors work in reverse.
*/
const byte SENSOR_ACTIVE_STATE = LOW;

const unsigned long OCCUPIED_CONFIRM_TIME = 1000;
const unsigned long AVAILABLE_CONFIRM_TIME = 5000;
const unsigned long BLUETOOTH_STATUS_INTERVAL = 1500;

const byte GATE_CLOSED_ANGLE = 0;
const byte GATE_OPEN_ANGLE = 90;
const unsigned long GATE_OPEN_TIME = 3000;

// ======================================================
// SYSTEM VARIABLES
// ======================================================

int available = 4;

bool inFlag = false;
bool outFlag = false;
bool gateOpen = false;
bool gateBusy = false;

// Confirmed status of each slot
bool slotOccupied[TOTAL_SLOTS] = {
  false,
  false,
  false,
  false
};

// Latest raw reading of each slot sensor
bool slotRawDetected[TOTAL_SLOTS] = {
  false,
  false,
  false,
  false
};

// Time when raw reading last changed
unsigned long slotRawChangedAt[TOTAL_SLOTS] = {
  0,
  0,
  0,
  0
};

unsigned long lastBluetoothStatus = 0;

// Bluetooth command buffer
char commandBuffer[25];
byte commandIndex = 0;

// ======================================================
// SETUP
// ======================================================

void setup()
{
  Serial.begin(9600);
  bluetooth.begin(9600);

  // Original sensors
  pinMode(IR_IN, INPUT);
  pinMode(IR_OUT, INPUT);

  // New slot sensors
  for (byte i = 0; i < TOTAL_SLOTS; i++)
  {
    pinMode(slotPins[i], INPUT);
  }

  // Traffic lights
  pinMode(RED_LED, OUTPUT);
  pinMode(YELLOW_LED, OUTPUT);
  pinMode(GREEN_LED, OUTPUT);

  // Servo - same as original working code
  gate.attach(SERVO_PIN);
  gate.write(GATE_CLOSED_ANGLE);

  // LCD - same as original working code
  lcd.init();
  lcd.backlight();

  lcd.clear();
  lcd.setCursor(0, 0);
  lcd.print("Parking System");
  lcd.setCursor(0, 1);
  lcd.print("Starting...");
  delay(2000);

  // Read actual slot condition at startup
  initializeSlotSensors();

  available = countAvailableSlots();

  updateNormalDisplay();
  sendCompleteStatus();

  lastBluetoothStatus = millis();
}

// ======================================================
// MAIN LOOP
// ======================================================

void loop()
{
  readBluetoothCommands();

  updateSlotSensors();

  handleEntrySensor();
  handleExitSensor();

  // Backup synchronization for Flutter app
  if (millis() - lastBluetoothStatus >= BLUETOOTH_STATUS_INTERVAL)
  {
    sendCompleteStatus();
    lastBluetoothStatus = millis();
  }

  delay(10);
}

// ======================================================
// SENSOR HELPER
// ======================================================

bool sensorDetected(byte pin)
{
  return digitalRead(pin) == SENSOR_ACTIVE_STATE;
}

// ======================================================
// INITIAL SLOT SENSOR READING
// ======================================================

void initializeSlotSensors()
{
  /*
    Multiple startup samples reduce false readings while
    the sensors and power supply are stabilizing.
  */

  byte detectionCount[TOTAL_SLOTS] = {0, 0, 0, 0};
  const byte samples = 20;

  for (byte sample = 0; sample < samples; sample++)
  {
    for (byte i = 0; i < TOTAL_SLOTS; i++)
    {
      if (sensorDetected(slotPins[i]))
      {
        detectionCount[i]++;
      }
    }

    delay(25);
  }

  for (byte i = 0; i < TOTAL_SLOTS; i++)
  {
    bool detected = detectionCount[i] >= 14;

    slotOccupied[i] = detected;
    slotRawDetected[i] = detected;
    slotRawChangedAt[i] = millis();
  }
}

// ======================================================
// STABLE SLOT SENSOR LOGIC
// ======================================================

void updateSlotSensors()
{
  bool anySlotChanged = false;
  unsigned long now = millis();

  for (byte i = 0; i < TOTAL_SLOTS; i++)
  {
    bool currentReading = sensorDetected(slotPins[i]);

    // Sensor reading changed: start a new confirmation timer
    if (currentReading != slotRawDetected[i])
    {
      slotRawDetected[i] = currentReading;
      slotRawChangedAt[i] = now;

      /*
        When an occupied slot temporarily loses detection,
        it stays occupied while the 5-second timer runs.
      */
      if (slotOccupied[i] && !currentReading)
      {
        sendSlotCheckingEvent(i);
      }
    }

    unsigned long requiredTime;

    if (currentReading)
    {
      requiredTime = OCCUPIED_CONFIRM_TIME;
    }
    else
    {
      requiredTime = AVAILABLE_CONFIRM_TIME;
    }

    // Confirm only after the reading stays stable
    if (
      slotOccupied[i] != currentReading &&
      now - slotRawChangedAt[i] >= requiredTime
    )
    {
      slotOccupied[i] = currentReading;
      anySlotChanged = true;

      sendSlotChangeEvent(i, currentReading);
    }
  }

  if (anySlotChanged)
  {
    available = countAvailableSlots();

    if (!gateBusy)
    {
      updateNormalDisplay();
    }

    sendCompleteStatus();
    lastBluetoothStatus = millis();
  }
}

// ======================================================
// ENTRY SENSOR - BASED ON ORIGINAL WORKING LOGIC
// ======================================================

void handleEntrySensor()
{
  if (digitalRead(IR_IN) == LOW && !inFlag && !gateBusy)
  {
    inFlag = true;

    available = countAvailableSlots();

    if (available > 0)
    {
      gateBusy = true;

      showMessage("Car Entering", "Please Wait");
      setYellowLight();

      openGateForVehicle();

      /*
        No available-- here.
        The exact parking slot sensor will update the count
        after the car parks.
      */

      updateNormalDisplay();
      sendCompleteStatus();

      gateBusy = false;
    }
    else
    {
      showMessage("Parking FULL", "Gate Closed");
      setRedLight();
      sendEvent("ENTRY_DENIED");

      delay(2000);

      updateNormalDisplay();
    }
  }

  if (digitalRead(IR_IN) == HIGH)
  {
    inFlag = false;
  }
}

// ======================================================
// EXIT SENSOR - BASED ON ORIGINAL WORKING LOGIC
// ======================================================

void handleExitSensor()
{
  if (digitalRead(IR_OUT) == LOW && !outFlag && !gateBusy)
  {
    outFlag = true;
    gateBusy = true;

    showMessage("Car Exiting", "Please Wait");
    setYellowLight();

    /*
      Exit gate always opens.
      The car may already have left its slot, so all four
      slot sensors might already show available.
    */
    openGateForVehicle();

    /*
      No available++ here.
      The slot sensor itself confirms that the slot is free.
    */

    available = countAvailableSlots();

    updateNormalDisplay();
    sendCompleteStatus();

    gateBusy = false;
  }

  if (digitalRead(IR_OUT) == HIGH)
  {
    outFlag = false;
  }
}

// ======================================================
// SERVO CONTROL - SAME 0 / 90 / 3000 ms BEHAVIOUR
// ======================================================

void openGateForVehicle()
{
  gate.write(GATE_OPEN_ANGLE);
  gateOpen = true;
  sendGateState();

  delay(GATE_OPEN_TIME);

  gate.write(GATE_CLOSED_ANGLE);
  gateOpen = false;
  sendGateState();

  // Give the servo some time to move toward closed position
  delay(500);
}

// ======================================================
// AVAILABLE SLOT COUNT
// ======================================================

int countAvailableSlots()
{
  int freeSlots = 0;

  for (byte i = 0; i < TOTAL_SLOTS; i++)
  {
    if (!slotOccupied[i])
    {
      freeSlots++;
    }
  }

  return freeSlots;
}

// ======================================================
// LCD
// ======================================================

void updateNormalDisplay()
{
  available = countAvailableSlots();

  lcd.clear();
  lcd.setCursor(0, 0);

  if (available == 0)
  {
    lcd.print("Parking FULL");
  }
  else
  {
    lcd.print("Available:");
    lcd.print(available);
  }

  lcd.setCursor(0, 1);
  lcd.print("Free:");
  lcd.print(available);
  lcd.print("/");
  lcd.print(TOTAL_SLOTS);

  updateTrafficLights();
}

void showMessage(const char *line1, const char *line2)
{
  lcd.clear();

  lcd.setCursor(0, 0);
  lcd.print(line1);

  lcd.setCursor(0, 1);
  lcd.print(line2);
}

// ======================================================
// TRAFFIC LIGHTS
// ======================================================

void setRedLight()
{
  digitalWrite(RED_LED, HIGH);
  digitalWrite(YELLOW_LED, LOW);
  digitalWrite(GREEN_LED, LOW);
}

void setYellowLight()
{
  digitalWrite(RED_LED, LOW);
  digitalWrite(YELLOW_LED, HIGH);
  digitalWrite(GREEN_LED, LOW);
}

void setGreenLight()
{
  digitalWrite(RED_LED, LOW);
  digitalWrite(YELLOW_LED, LOW);
  digitalWrite(GREEN_LED, HIGH);
}

void updateTrafficLights()
{
  if (available == 0)
  {
    setRedLight();
  }
  else
  {
    setGreenLight();
  }
}

// ======================================================
// BLUETOOTH STATUS FOR FLUTTER APP
// ======================================================

void sendSlotStatus()
{
  /*
    Example:
    S1:0,S2:1,S3:0,S4:1

    0 = Available
    1 = Occupied
  */

  for (byte i = 0; i < TOTAL_SLOTS; i++)
  {
    bluetooth.print("S");
    bluetooth.print(i + 1);
    bluetooth.print(":");
    bluetooth.print(slotOccupied[i] ? 1 : 0);

    Serial.print("S");
    Serial.print(i + 1);
    Serial.print(":");
    Serial.print(slotOccupied[i] ? 1 : 0);

    if (i < TOTAL_SLOTS - 1)
    {
      bluetooth.print(",");
      Serial.print(",");
    }
  }

  bluetooth.println();
  Serial.println();
}

void sendGateState()
{
  bluetooth.print("G:");
  bluetooth.println(gateOpen ? 1 : 0);

  Serial.print("G:");
  Serial.println(gateOpen ? 1 : 0);
}

void sendLcdStatus()
{
  available = countAvailableSlots();

  bluetooth.print("L1:");

  if (available == 0)
  {
    bluetooth.println("Parking FULL");
  }
  else
  {
    bluetooth.print("Available:");
    bluetooth.println(available);
  }

  bluetooth.print("L2:Free:");
  bluetooth.print(available);
  bluetooth.print("/");
  bluetooth.println(TOTAL_SLOTS);
}

void sendCompleteStatus()
{
  sendSlotStatus();
  sendGateState();
  sendLcdStatus();
}

// ======================================================
// OPTIONAL EVENTS
// ======================================================

void sendEvent(const char *eventName)
{
  bluetooth.print("E:");
  bluetooth.println(eventName);

  Serial.print("E:");
  Serial.println(eventName);
}

void sendSlotChangeEvent(byte index, bool occupied)
{
  bluetooth.print("E:SLOT");
  bluetooth.print(index + 1);
  bluetooth.print("_");
  bluetooth.println(occupied ? "OCCUPIED" : "AVAILABLE");

  Serial.print("E:SLOT");
  Serial.print(index + 1);
  Serial.print("_");
  Serial.println(occupied ? "OCCUPIED" : "AVAILABLE");
}

void sendSlotCheckingEvent(byte index)
{
  bluetooth.print("E:SLOT");
  bluetooth.print(index + 1);
  bluetooth.println("_CHECKING");

  Serial.print("E:SLOT");
  Serial.print(index + 1);
  Serial.println("_CHECKING");
}

// ======================================================
// BLUETOOTH COMMAND READER
// ======================================================

void readBluetoothCommands()
{
  while (bluetooth.available() > 0)
  {
    char incoming = bluetooth.read();

    if (incoming == '\n' || incoming == '\r')
    {
      if (commandIndex > 0)
      {
        commandBuffer[commandIndex] = '\0';
        processBluetoothCommand(commandBuffer);
        commandIndex = 0;
      }
    }
    else
    {
      if (commandIndex < sizeof(commandBuffer) - 1)
      {
        commandBuffer[commandIndex] =
          (char)toupper((unsigned char)incoming);

        commandIndex++;
      }
      else
      {
        commandIndex = 0;
      }
    }
  }
}

// ======================================================
// COMMANDS FROM FLUTTER / BLUETOOTH TERMINAL
// ======================================================

void processBluetoothCommand(const char *command)
{
  if (strcmp(command, "STATUS") == 0)
  {
    sendCompleteStatus();
  }

  else if (strcmp(command, "PING") == 0)
  {
    bluetooth.println("PONG");
    Serial.println("PONG");
  }

  /*
    OPEN command opens the gate for the same three seconds
    as the original entry/exit logic, then closes it.
  */
  else if (strcmp(command, "OPEN") == 0 && !gateBusy)
  {
    gateBusy = true;

    showMessage("Manual Control", "Gate Opening");
    setYellowLight();
    sendEvent("MANUAL_OPEN");

    openGateForVehicle();

    updateNormalDisplay();
    sendCompleteStatus();

    gateBusy = false;
  }

  else if (strcmp(command, "CLOSE") == 0)
  {
    gate.write(GATE_CLOSED_ANGLE);
    gateOpen = false;

    sendEvent("MANUAL_CLOSE");
    sendGateState();

    updateNormalDisplay();
  }
}
