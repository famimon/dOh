const byte signalPin = 9;
const byte piezoPin = 11;

void setup(){
  pinMode(signalPin, INPUT);
  pinMode(piezoPin, OUTPUT);
}

void loop(){
  int input = digitalRead(signalPin);
  if (input == HIGH){    
    tone(piezoPin, 400);
    delay(100);
    tone(piezoPin, 800);
    delay(300);
  }else{
    noTone(piezoPin);
  }
}
