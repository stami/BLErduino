

int incomingByte = 0;   // for incoming serial data

String inString = "";    // string to hold input

int motor1 = 6;
int motor2 = 7;


void setup() {
  // put your setup code here, to run once:

  // USB Serial
  Serial.begin(9600);

  // BLE module
  Serial1.begin(9600);


  pinMode(motor1, OUTPUT);
  pinMode(motor2, OUTPUT);

  digitalWrite(motor1, LOW);
  digitalWrite(motor2, LOW);
  
}


void loop() {

/*
  digitalWrite(6, HIGH);
  delay(1000);
  digitalWrite(6, LOW);
  delay(1000);
  digitalWrite(7, HIGH);
  delay(1000);
  digitalWrite(7, LOW);
  delay(1000);
 */

  // read from Bluetooth, send to USB serial
  if (Serial1.available()) {

    // Int8 sent from iOS
    incomingByte = Serial1.read();

    
    Serial.write("BLE: ");
    //Serial.println(incomingByte);
    //Serial.println(incoming);

    int speed = (incomingByte - 63) * 4;
    Serial.println(speed);

    setSpeed(speed);


  }
  

  // read from USB, send via Bluetooth
  if (Serial.available()) {
    Serial1.write(Serial.read());
  }

}


// -252 <= speed <= 256
void setSpeed(int speed) {
  
  if (speed < 0) {
    // reverse

    analogWrite(motor2, -speed);
    digitalWrite(motor1, LOW);
    
  }
  else if (speed == 0) {
    // stop
    digitalWrite(motor1, LOW);
    digitalWrite(motor2, LOW);
    
  }
  else {
    // forward
    analogWrite(motor1, speed);
    digitalWrite(motor2, LOW);
  }
   
}





