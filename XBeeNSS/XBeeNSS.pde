#include <XBee.h>
#include <NewSoftSerial.h>

#define TYPES 5
#define BOOKMARK 1
#define KEY 2
#define CARD 3 
#define PHONE 4
#define REACTIVE 5

const uint8_t DO_HIGH = 0x5;
const uint8_t DO_LOW = 0x4;

XBee xbee;

uint8_t base = 0x1;
uint8_t keyring = 0x2;
uint8_t knob = 0x3;

// pins in keyring
uint8_t blipPin = 0x0;
uint8_t stopPin = 0x1;

// pins in knob
uint8_t motorPin = 0x0;
uint8_t touchPin = 0x1;
uint8_t bluePin = 0x2;
uint8_t greenPin = 0x3;
uint8_t redPin = 0x6;

// SH + SL of remote radios
//XBeeAddress64 host = XBeeAddress64(0x0013a200, 0x406637bf);
//XBeeAddress64 keyring = XBeeAddress64(0x0013a200, 0x405d7563);
//XBeeAddress64 knob = XBeeAddress64(0x0013a200, 0x404925d4);

int missing[TYPES];
int missingCount=0;
int level;

boolean enabled=false;
boolean blip=false;
boolean stopPushed=false;
boolean firstBlip=true;

RemoteAtCommandRequest RemoteAtRequest;
RemoteAtCommandResponse RemoteAtResponse;
AtCommandRequest atRequest;
AtCommandResponse atResponse;

NewSoftSerial xbeeSerial(2,3);

void setup() { 
  xbee.setNss(xbeeSerial);
  xbee.begin(9600);
  // start serial for debugging
  Serial.begin(9600);
  // When powered on, XBee radios require a few seconds to start up
  // and join the network.
  // During this time, any packets sent to the radio are ignored.

  delay(8000);

  setupBase();
  setupKnob();
//  setupKeyring();
}

void setupBase(){
  Serial.println("BASE ID:");
  checkID(base);

  Serial.println("Disable PWM in for DA1");
  setPWM(base, touchPin, 0x0);

  Serial.println("Set IA to listen to knob");
  setIA(base, knob);

  Serial.println("Enable UART in base");
  setIU(base, 0x1);
  
  Serial.println("Apply changes in base");
  applyChanges(base);
  
//  Serial.println("Writing changes in base");
//  updateFlash(base);
}

void setupKnob(){
  Serial.println("KNOB ID:");
  checkID(knob);

  Serial.println("Enable Change Detection in Knob");
  setIC(knob, 0x2);

  Serial.println("Set touchPin in Knob to Digital Input");
  setPin(knob, touchPin, 0x3);

  Serial.println("Set motorPin to digital Output Low");
  setPin(knob, motorPin, DO_LOW);

  Serial.println("Set IR in Knob to 1s");
  setIR(knob, 0x03, 0xe8);

  Serial.println("Set transfer size");
  setIT(knob, 0x1);
  
  Serial.println("Set Destination to Base");
  setDL(knob, base);

  Serial.println("Enable Change Detection in Knob");
  setIC(knob, 0x2);

  setPR(knob,0xff);
  
  Serial.println("Disable UART in knob");
  setIU(knob, 0x0);

  Serial.println("Apply changes in knob");
  applyChanges(knob);

//  Serial.println("Writing changes in knob");
//  updateFlash(knob);
}

void setupKeyring(){
  Serial.println("KEYRING ID:");
  checkID(keyring);

  Serial.println("Set blipPin to digital Output Low");
  setPin(keyring, blipPin, DO_LOW);

  Serial.println("Disable Change detection");
  setIC(keyring, 0x0);

  Serial.println("Set pin 19 in keyring to Digital Input");
  setPin(keyring, stopPin, 0x3);
 
  Serial.println("Set Destination to Base");
  setDL(keyring, base);
  
  Serial.println("Set transfer size");
  setIT(keyring, 0x1);

  Serial.println("Set IR in keyring to 1s");
  setIR(keyring, 0x03, 0xe8);

  Serial.println("Disable UART in keyring");
  setIU(keyring, 0x0);

  Serial.println("Apply changes in keyring");
  applyChanges(keyring);

//  Serial.println("Writing changes in keyring");
//  updateFlash(keyring);
}
  
void loop() {
  if(!enabled){
    checkIO();
  }else{
    scanTags();
  }
  
  if (blip){
    if (firstBlip){
      firstBlip=false;
      Serial.println("Set IA to listen to keyring");
      setIA(base, keyring);
      Serial.println("Set IC to send out changes in D1");
      setIC(keyring, 0x2);
      Serial.println("");
    }  
    blipblip();
  }
}

void scanTags(){
  missingCount=0;  
//  missing[missingCount++]=REACTIVE;
  missing[missingCount++]=BOOKMARK;
  missing[missingCount++]=KEY;
  missing[missingCount++]=CARD;
  missing[missingCount++]=PHONE;

  if (missingCount > 0){
    alarm();
  }else{  //nothing missing display white
    displayRGB(DO_HIGH, DO_HIGH, DO_HIGH);
    delay(1000); 
  }
  displayRGB(DO_LOW, DO_LOW, DO_LOW);
  enabled=false;
  // Re-enable Change Detection in Knob";
  setIC(knob, 0x2);
}

void blipblip(){
  setPin(keyring, blipPin, DO_HIGH);
  applyChanges(keyring);
  checkIO();
  delay(300);
  setPin(keyring, blipPin, DO_LOW);
  applyChanges(keyring);
  checkIO();
  delay(300);
}

void alarm(){
  uint8_t r,g,b;
  int lapse, times;  
  switch (missingCount){
    case 1: // 1 item missing
      lapse=500;
      times=5;
      break;
    case 2: // 2 items missing
      lapse=500;
      times=3;
      break;
    default: // more than 2 items missing
      lapse=500;
      times=2;
      break;
  }  
  
  for(int i=0; i<times;i++){
    for (int i=0; i<missingCount; i++){
    switch (missing[i]){
      case BOOKMARK: 
          r = DO_HIGH;
          g = DO_LOW;
          b = DO_LOW;    
          break;
        case KEY: 
          r = DO_HIGH;
          g = DO_HIGH;
          b = DO_LOW;    
          break;
        case CARD:
          r = DO_LOW;
          g = DO_HIGH;
          b = DO_LOW;    
          break;
        case PHONE: 
          r = DO_HIGH;
          g = DO_LOW;
          b = DO_HIGH;    
          break;
        case REACTIVE:
          r = DO_LOW;
          g = DO_LOW;
          b = DO_HIGH;    
          blip=true;
        break;
      }//switch
      displayRGB(r, g, b);
      setPin(knob, motorPin, DO_HIGH);  
      delay(lapse);
      displayRGB(DO_LOW, DO_LOW, DO_LOW);
      setPin(knob, motorPin, DO_LOW);
      delay(lapse);
    }
  }
}

void displayRGB(uint8_t r, uint8_t g, uint8_t b){
    setPin(knob, redPin, r);    
    setPin(knob, greenPin, g);  
    setPin(knob, bluePin, b);
    applyChanges(knob);
}

void checkIO(){
  Rx16IoSampleResponse ioSample = Rx16IoSampleResponse();
  //attempt to read a packet    
  xbee.readPacket();
  if (xbee.getResponse().isAvailable() && xbee.getResponse().getApiId() == RX_16_IO_RESPONSE) {      
    xbee.getResponse().getRx16IoSampleResponse(ioSample);    
      if (enabled && blip && ioSample.getRemoteAddress16()==keyring && ioSample.isDigitalOn(stopPin, 1)){
        Serial.println("==============> STOP PRESSED <=============");
          Serial.println("Blip disabled");
          blip=false;
          Serial.println("Set IA to listen to knob");
          setIA(base, knob);
          Serial.println("Disable Change Detection in Keyring");
          setIC(keyring, 0x0);
          Serial.println("");
          firstBlip=true;
      }else 
      if (!enabled && !blip && ioSample.getRemoteAddress16()==knob && ioSample.isDigitalOn(touchPin, 1)){
        Serial.println("==============> KNOB TOUCHED <=============");
          enabled=true;
          Serial.println("ENABLED");    
          Serial.println("Disable Change Detection in Knob");
          setIC(knob, 0x0);
          Serial.println("");               
    }
  }
}

void sendRemoteAtCommand(){
  Serial.println("");
  Serial.print("Sending command to ");
  Serial.println(RemoteAtRequest.getRemoteAddress16(), HEX);
  // send the command
  xbee.send(RemoteAtRequest);
  Serial.println("");

  // wait up to 5 seconds for the status response
  if (xbee.readPacket(5000)) {
    // got a response!

    // should be an AT command response from addr
    if (xbee.getResponse().getApiId() == REMOTE_AT_COMMAND_RESPONSE) {
      xbee.getResponse().getRemoteAtCommandResponse(RemoteAtResponse);

      if (RemoteAtResponse.isOk()) {
        Serial.print("Command [AT");
        Serial.print(RemoteAtResponse.getCommand()[0]);
        Serial.print(RemoteAtResponse.getCommand()[1]);
        Serial.println("] was successful!");

        if (RemoteAtResponse.getValueLength() > 0) {
          Serial.print("Command value length is ");
          Serial.println(RemoteAtResponse.getValueLength(), DEC);

          Serial.print("Command value: ");

          for (int i = 0; i < RemoteAtResponse.getValueLength(); i++) {
            Serial.print(RemoteAtResponse.getValue()[i], HEX);
            Serial.print(" ");
          }
          Serial.println("");
        }
      } 
      else {
        Serial.print("Command return error code for [AT");
        Serial.print(RemoteAtResponse.getCommand()[0]);
        Serial.print(RemoteAtResponse.getCommand()[1]);
        Serial.print("]: ");
        Serial.println(RemoteAtResponse.getStatus(), HEX);
        Serial.println("");
      }
//    }else {
//      Serial.print("Expected Remote AT response but got ");
//      Serial.print(xbee.getResponse().getApiId(), HEX);
    }    
  } 
  else {
    // remote at command failed
    if (xbee.getResponse().isError()) {
      Serial.print("Error reading packet.  Error code: ");  
      Serial.println(xbee.getResponse().getErrorCode(), HEX);
    } 
    else {
      Serial.print("No response from radio");  
    }
  }
          Serial.println("");
}

void sendAtCommand() {
  Serial.println("");
  Serial.println("Sending command to Base");

  // send the command
  xbee.send(atRequest);

  // wait up to 5 seconds for the status response
  if (xbee.readPacket(5000)) {
    // got a response!

    // should be an AT command response
    if (xbee.getResponse().getApiId() == AT_COMMAND_RESPONSE) {
      xbee.getResponse().getAtCommandResponse(atResponse);

      if (atResponse.isOk()) {
        Serial.print("Command [AT");
        Serial.print(atResponse.getCommand()[0]);
        Serial.print(atResponse.getCommand()[1]);
        Serial.println("] was successful!");

        if (atResponse.getValueLength() > 0) {
          Serial.print("Command value length is ");
          Serial.println(atResponse.getValueLength(), DEC);

          Serial.print("Command value: ");
          
          for (int i = 0; i < atResponse.getValueLength(); i++) {
            Serial.print(atResponse.getValue()[i], HEX);
            Serial.print(" ");
          }

          Serial.println("");
        }
      } 
      else {
        Serial.print("Command return error code for [AT");
        Serial.print(atResponse.getCommand()[0]);
        Serial.print(atResponse.getCommand()[1]);
        Serial.print("]: ");
        Serial.println(atResponse.getStatus(), HEX);
        Serial.println("");
      }
//    } else {
//      Serial.print("Expected AT response but got ");
//      Serial.print(xbee.getResponse().getApiId(), HEX);
    }   
  } else {
    // at command failed
    if (xbee.getResponse().isError()) {
      Serial.print("Error reading packet.  Error code: ");  
      Serial.println(xbee.getResponse().getErrorCode());
    } 
    else {
      Serial.print("No response from radio");  
    }
  }
          Serial.println("");
}

///////////////////////////
// AT COMMANDS
///////////////////////////
void setPin(uint8_t addr, uint8_t pin, uint8_t value){
  uint8_t ioCmd[] = { 'D', (char) (pin + '0') };
  uint8_t ioValue[] = { value }; 
  if(addr == base){
    atRequest = AtCommandRequest(ioCmd, ioValue, sizeof(ioValue));
    sendAtCommand();
  }else{
    RemoteAtRequest = RemoteAtCommandRequest(addr, ioCmd, ioValue, sizeof(ioValue));
    sendRemoteAtCommand();
  }
} 

void setPWM(uint8_t addr, uint8_t pin, uint8_t value){
  uint8_t poCmd[] = { 'P', (char) (pin + '0') };
  uint8_t poValue[] = { value }; 
  if(addr == base){
    atRequest = AtCommandRequest(poCmd, poValue, sizeof(poValue));
    sendAtCommand();
  }else{
    RemoteAtRequest = RemoteAtCommandRequest(addr, poCmd, poValue, sizeof(poValue));
    sendRemoteAtCommand();
  }
} 

void setOutputLevel(uint8_t addr, uint8_t pin, uint8_t value){
  uint8_t moCmd[] = { 'M', (char) (pin + '0') };
  uint8_t moValue[] = { value }; 
  if(addr == base){
    atRequest = AtCommandRequest(moCmd, moValue, sizeof(moValue));
    sendAtCommand();
  }else{
    RemoteAtRequest = RemoteAtCommandRequest(addr, moCmd, moValue, sizeof(moValue));
    sendRemoteAtCommand();
  }
} 

void setTimeout(uint8_t addr, uint8_t pin, uint8_t value1, uint8_t value2){
  uint8_t toCmd[] = { 'T', (char) (pin + '0') };
  uint8_t toValue[] = { value1, value2 }; 
  if(addr == base){
    atRequest = AtCommandRequest(toCmd, toValue, sizeof(toValue));
    sendAtCommand();
  }else{
    RemoteAtRequest = RemoteAtCommandRequest(addr, toCmd, toValue, sizeof(toValue));
    sendRemoteAtCommand();
  }
} 


void setIA(uint8_t addr, uint8_t value){
  uint8_t iaCmd[] = { 'I', 'A' };
  uint8_t iaValue[] = {0xff, 0xff }; 
  if(addr == base){
    atRequest = AtCommandRequest(iaCmd, iaValue, sizeof(iaValue));
    sendAtCommand();
  }else{
    RemoteAtRequest = RemoteAtCommandRequest(addr, iaCmd, iaValue, sizeof(iaValue));
    sendRemoteAtCommand();
  }
} 

void setPR(uint8_t addr, uint8_t value){
  uint8_t prCmd[] = { 'P', 'R' };
  uint8_t prValue[] = { value }; 
  if(addr == base){
    atRequest = AtCommandRequest(prCmd, prValue, sizeof(prValue));
    sendAtCommand();
  }else{
    RemoteAtRequest = RemoteAtCommandRequest(addr, prCmd, prValue, sizeof(prValue));
    sendRemoteAtCommand();
  }
} 

void setIU(uint8_t addr, uint8_t value){
  uint8_t iuCmd[] = { 'I', 'U' };
  uint8_t iuValue[] = { value }; 
  if(addr == base){
    atRequest = AtCommandRequest(iuCmd, iuValue, sizeof(iuValue));
    sendAtCommand();
  }else{
    RemoteAtRequest = RemoteAtCommandRequest(addr, iuCmd, iuValue, sizeof(iuValue));
    sendRemoteAtCommand();
  }
} 

void setIR(uint8_t addr, uint8_t mseconds1, uint8_t mseconds2){
  // Turn on I/O sampling
  uint8_t irCmd[] = {'I','R'};
  uint8_t irValue[] = { mseconds1, mseconds2 };
  RemoteAtRequest = RemoteAtCommandRequest(addr, irCmd, irValue, sizeof(irValue));
  sendRemoteAtCommand();
}

void setIC(uint8_t addr, uint8_t value){
  // Notify changes in IO
  uint8_t icCmd[] = {'I','C'};
  uint8_t icValue[] = { value };
  RemoteAtRequest = RemoteAtCommandRequest(addr, icCmd, icValue, sizeof(icValue));
  sendRemoteAtCommand();
}

void setIT(uint8_t addr, uint8_t value){
  // Notify changes in IO
  uint8_t itCmd[] = {'I','T'};
  uint8_t itValue[] = { value };
  RemoteAtRequest = RemoteAtCommandRequest(addr, itCmd, itValue, sizeof(itValue));
  sendRemoteAtCommand();
}

void applyChanges(uint8_t addr){
  // Notify changes in IO
  uint8_t acCmd[] = {'A','C'};
  if(addr == base){
    atRequest = AtCommandRequest(acCmd);
    sendAtCommand();
  }else{
    RemoteAtRequest = RemoteAtCommandRequest(addr, acCmd);
    sendRemoteAtCommand();
  }
}

void forceSample(uint8_t addr){
  // Notify changes in IO
  uint8_t isCmd[] = {'I','S'};
  if(addr == base){
    atRequest = AtCommandRequest(isCmd);
    sendAtCommand();
  }else{
    RemoteAtRequest = RemoteAtCommandRequest(addr, isCmd);
    sendRemoteAtCommand();
  }
}

void updateFlash(uint8_t addr){
  uint8_t wrCmd[] = {'W','R'};
  if(addr == base){
    atRequest = AtCommandRequest(wrCmd);
    sendAtCommand();
  }else{
    RemoteAtRequest = RemoteAtCommandRequest(addr, wrCmd);
    sendRemoteAtCommand();
  }
}

void softReset(uint8_t addr){
  uint8_t frCmd[] = {'F','R'};
  if(addr == base){
    atRequest = AtCommandRequest(frCmd);
    sendAtCommand();
  }else{
    RemoteAtRequest = RemoteAtCommandRequest(addr, frCmd);
    sendRemoteAtCommand();
  }
}

void setDL(uint8_t addr, uint8_t dest){
  // Set destination address for IO
  uint8_t dlCmd[] = {'D','L'};
  // Coordinator's ID
  uint8_t dlValue[] = { base };
  RemoteAtRequest = RemoteAtCommandRequest(addr, dlCmd, dlValue, sizeof(dlValue));
  sendRemoteAtCommand();
}

void checkID(uint8_t addr){
  // Print ID
  uint8_t idCmd[] = {'M','Y'};
  if(addr == base){
    atRequest = AtCommandRequest(idCmd);
    sendAtCommand();
  }else{
    RemoteAtRequest = RemoteAtCommandRequest(addr, idCmd);
    sendRemoteAtCommand();
  }
}
