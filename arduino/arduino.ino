

byte incomingByte = 0;   // for incoming serial data

// Motor pins
int motor1 = 6;
int motor2 = 7;

// Servo
#include <Servo.h>
Servo servo;
int servoPin = 3;


void setup() {

  // USB Serial (for debugging)
  Serial.begin(9600);

  // BLE module
  Serial1.begin(9600);

  pinMode(motor1, OUTPUT);
  pinMode(motor2, OUTPUT);

  // Initialize motor pins to zero
  digitalWrite(motor1, LOW);
  digitalWrite(motor2, LOW);

  // Tell servo library to use this pin
  servo.attach(servoPin);
}


void loop() {

  // read from Bluetooth serial
  if (Serial1.available()) {

    // Int8 received from iOS app
    incomingByte = Serial1.read();

    // Dump to USB serial
    Serial.write("BLE: ");
    Serial.println(incomingByte);

    // The range 0...127 is divided between steering and throttling
    if (incomingByte < 64) {
      // 0...63
      setSteering(incomingByte);
    } else {
      // 64...127
      setThrottle(incomingByte);
    }

  }

  // read from USB, send via Bluetooth (for testing)
  if (Serial.available()) {
    Serial1.write(Serial.read());
  }

}



/**
 * Set Steering
 * 0 <= incoming <= 63
 * Map the incoming value to the servo angle
 */
void setSteering(byte incoming) {

  // Map the value
  // 30 - 150 to prevent my steering assembly from breaking
  int angle = map(incoming, 0, 63, 30, 150);

  servo.write(angle);

}


/**
 * Set Throttle
 * 64 <= incoming <= 127
 *
 * Lower:   < 95 => Reverse
 * Middle: == 95 => Stop
 * Upper:   > 95 => Forward
 */
void setThrottle(byte incoming) {

  int speed; // mapped value

  // Reverse
  if (incoming < 95) {
    // Map the value 64...94 to 0...255
    speed = map(incoming, 64, 94, 255, 0);

    analogWrite(motor2, speed);
    digitalWrite(motor1, LOW);
  }

  // Stop
  else if (incoming == 95) {
    digitalWrite(motor1, LOW);
    digitalWrite(motor2, LOW);
  }

  // Forward
  else {
    // Map the value 96...127 to 0...255
    speed = map(incoming, 95, 127, 0, 255);

    analogWrite(motor1, speed);
    digitalWrite(motor2, LOW);
  }

}
