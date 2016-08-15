#include <NewSoftSerial.h>
#include <QueueList.h>
#include "RFID.h"

#define FOUND_TIMEOUT 60000
char command_hardware[] = {0x10,0x03,0x01};
char command_software[] = {0x10,0x03,0x00};

char command_powerOff[] = {0x18,0x03,0x00};
char command_powerOn[] = {0x18,0x03,0xff};


byte buttonPin = 8;
byte redPin = 5;
byte greenPin = 6;
byte bluePin = 7;
byte piezoPin = 11;

// Define NewSoftSerial TX/RX pins
// Connect Arduino pin 9 to TX of usb-rfid device
uint8_t ssRX = 9;
// Connect Arduino pin 10 to RX of usb-rfid device
uint8_t ssTX = 10;
// Send through NSS and receive through serial for the RFID
NewSoftSerial rfidNss(ssRX, ssTX);

RFID Rfid(redPin, greenPin, bluePin, buttonPin, piezoPin, ssRX, ssTX);

void setup(){
  Serial.begin(115200);  
  rfidNss.begin(115200);
  
  Rfid.nss->begin(115200);
  // wait for reader to powerup  
  delay(2000);
  Serial.println("READY");
}

void loop() 
{  
  // Reader should be always scanning and updating the found array
  // found should have a vailidy of about 60 seconds
  // after knob is touched build Missing give feedback and reset
  if(!Rfid.registering && !Rfid.deleting){
    Rfid.checkButton();

    if (millis() - Rfid.foundTimeTag > FOUND_TIMEOUT){
      Serial.println("Found Timeout");
      Rfid.printMetaData();
      Rfid.initializeMeta();
      Rfid.foundTimeTag = millis();
    } 
    Rfid.nss->print(Rfid.command_scantag);
    delay(200);
    Rfid.checkRFID();
  }
}
