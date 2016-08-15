#include <XBee.h>
#include <NewSoftSerial.h>
#include <QueueList.h>

const byte BUFFSIZ = 90;
const byte SETSIZE = 6;
const byte MAXSETS = 6;
const byte TAGTYPES = 5;
const byte TAGSIZE = 12;
const byte ID_OFFSET = 5;

const byte DOC_TYPE = 1;
const byte ID_TYPE = 2;
const byte PHONE_TYPE = 3;
const byte KEY_TYPE = 4;
const byte REACTIVE_TYPE = 5;

unsigned long DELETE_CYCLE = 5000;
unsigned long REGISTER_CYCLE = 10000;

// keep the button pressed for 2 secs to delete an item
unsigned long DELETE_TIMEOUT = 2000;

// empty the array of found items every minute
unsigned long FOUND_TIMEOUT = 60000;

// Create new set when registering item if no reference set is found in 2 seconds
unsigned long REGISTER_TIMEOUT = 2000;

//
//#define REACTIVE_TAG {0xE2, 0x0, 0x10, 0x66, 0x66, 0x14, 0x0, 0x76, 0x19, 0x40, 0x4C, 0xCC}
//#define ID_TAG {0xE2, 0x0, 0x10, 0x66, 0x66, 0x14, 0x0, 0x74, 0x19, 0x40, 0x4C, 0xC4}
//#define PHONE_TAG {0xE2, 0x0, 0x10, 0x66, 0x66, 0x14, 0x0, 0x75, 0x19, 0x40, 0x4C, 0xC8}
//#define DOCUMENT_TAG {0x30, 0x8, 0x33, 0xB2, 0xDD, 0xD9, 0x6, 0xC0, 0x0, 0x0, 0x0, 0x0}
//#define HOME_TAG  {0xE2, 0x0, 0x19, 0x96, 0x96, 0x2, 0x1, 0x32, 0x21, 0x50, 0x35, 0x1D}
//#define CAR_TAG {0xE2, 0x0, 0x19, 0x96, 0x96, 0x2, 0x1, 0x32, 0x10, 0x90, 0xA9, 0x17}

// Pins in host
const byte buttonPin = 8;
const byte hostRedPin = 5;
const byte hostGreenPin = 6;
const byte hostBluePin = 7;
const byte piezoPin = 11;

struct foundRecord{
  int set;
  int idx;
};

struct metaData{
  int type;
  boolean found;
};

int referenceSet = -1;

unsigned long buttonTimeTag = 0;

unsigned long foundTimeTag = 0;

unsigned long registerTimeTag = 0;

byte inventory[MAXSETS][SETSIZE][TAGSIZE];

metaData metaInventory[MAXSETS][SETSIZE];

int nSets=0; // number of sets defined
int lengths[MAXSETS]; // array storing the length for each set

boolean deleting = false;
boolean registering = false;

QueueList <int> missing;

char command_hardware[]={0x10,0x03,0x01};
char command_software[]={0x10,0x03,0x00};

char command_powerOff[]={0x18,0x03,0x00};
char command_powerOn[]={0x18,0x03,0xff};

char command_scantag[]={0x31,0x03,0x01};
  
#define TYPES 5
#define BOOKMARK 1
#define KEY 2
#define CARD 3 
#define PHONE 4
#define REACTIVE 5

const uint8_t DO_HIGH = 0x5;
const uint8_t DO_LOW = 0x4;

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

boolean enabled=false;
boolean blip=false;
boolean stopPushed=false;
boolean firstBlip=true;

RemoteAtCommandRequest RemoteAtRequest;
RemoteAtCommandResponse RemoteAtResponse;
AtCommandRequest atRequest;
AtCommandResponse atResponse;

NewSoftSerial xbeeSerial(2, 3);
NewSoftSerial rfidSerial(9, 4);

XBee xbee;

void setup() { 
  Serial.begin(115200);
  rfidSerial.begin(115200);
  xbee.setNss(xbeeSerial);
  xbee.begin(38400);
  pinMode(hostRedPin, OUTPUT);
  pinMode(hostGreenPin, OUTPUT);
  pinMode(hostBluePin, OUTPUT);
  pinMode(buttonPin, INPUT);
  Serial.println("resetting");
  reset();
  //Initialize lengths
  for (int i=0; i<MAXSETS; i++){
    lengths[i]=0;
  }
  // Wait for XBees and RFID to powerup
  delay(8000);
  Serial.println("START");
//  setupBase();
//  setupKnob();
//  setupKeyring();
}

void loop() {
  if(!enabled){
    checkIO();
  }else{
    checkMissing();
  }

  if(!registering && !deleting){
    // Check for deleting or registering commands
    checkButton();

    // Reset found items every minute
    if (millis() - foundTimeTag > FOUND_TIMEOUT){
      Serial.println("Found Timeout");
      printMetaData();
      initializeMeta();
      foundTimeTag = millis();
    } 
    // Look for items
    rfidSerial.print(command_scantag);
    delay(200);
    checkRFID();
  }

  if (blip){
    if (firstBlip){
      firstBlip=false;
      Serial.println("Set IC to send out changes in D1");
      setIC(keyring, 0x2);
      Serial.println("");
    }  
    blipblip();
  }
}

void checkButton(){
//  Serial.println("check button");
  int buttonState = digitalRead(buttonPin);  
  if (buttonState == HIGH && buttonTimeTag==0){ // Button pressed, start timer
    Serial.println("Button pressed");
    buttonTimeTag=millis();
  }
  else if (buttonState == HIGH && buttonTimeTag >0 && millis()-buttonTimeTag >= DELETE_TIMEOUT){ // pressed over 3 seconds => remove
    Serial.println("ERASE");
    erase();    
  }
  else if (buttonState == LOW && buttonTimeTag >0 && millis()-buttonTimeTag < DELETE_TIMEOUT){ // released before 3 seconds => register
    Serial.println("REGISTER");
    registerNew();
  }
}  

void reset(){
  // set status LED to green
  statusLed(LOW, HIGH, LOW);
  initializeMeta();
  referenceSet = -1;
  deleting = false;
  registering = false;
  registerTimeTag = 0;
  buttonTimeTag = 0;
  emptyMissing();  
  foundTimeTag = millis();
}

void scan(unsigned long time){
  unsigned long timetag = millis();
  boolean success=true;
  while (millis()-timetag < time){
    rfidSerial.print(command_scantag);
    delay(200);
    checkRFID();
  }
}


void buildMissing(){
  boolean none=true;
  for (int s=0; s < nSets; s++){
    for (int m=0; m < lengths[s]; m++){
      if(!metaInventory[s][m].found){
        missing.push(metaInventory[s][m].type);
      }else if(none){
        none=false;
      }
    }
  }
  if (none){
    emptyMissing();
    missing.push(-1);
  }
}

void checkMissing(){
  if (missing.isEmpty()){
      //nothing missing display white
    displayRGB(DO_HIGH, DO_HIGH, DO_HIGH);
    delay(1000); 
  }else{
    while(!missing.isEmpty()){
      alarm(missing.pop(), missing.count());
    }
  }
  // reset LEDs
  displayRGB(DO_LOW, DO_LOW, DO_LOW);
  // reset Metadata
  printMetaData();
  initializeMeta();
  foundTimeTag = millis();
  enabled=false;
  // Re-enable Change Detection in Knob";
  setIC(knob, 0x2);
}

void alarm(byte type, byte missingCount){
  uint8_t r, g, b;
  int lapse, times;  
  switch (missingCount){
    case 1: // 1 item missing
      lapse=1000;
      times=5;
      break;
    case 2: // 2 items missing
      lapse=1000;
      times=3;
      break;
    default: // more than 2 items missing
      lapse=1000;
      times=2;
      break;
  }  
  
  if (type == -1){
    for(int i=0; i<5;i++){ 
      // All forgotten ==> Flashing red
      displayRGB(DO_HIGH, DO_LOW, DO_LOW);
      setPin(knob, motorPin, DO_HIGH);  
      delay(500);
      displayRGB(DO_LOW, DO_LOW, DO_LOW);
      setPin(knob, motorPin, DO_LOW);
      delay(500);
    }
  }else{
    for(int i=0; i<times;i++){
      switch (type){
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
    }//for
  }//if
}


////////////////////////
// REGISTER & DELETE
////////////////////////
void registerNew(){
  // set status LED to blue
  statusLed(LOW,LOW,HIGH);
  registering = true;
  registerTimeTag=millis();
  scan(REGISTER_CYCLE);
  playCompleted();
  Serial.println("Print Inventory");
  printInventory();
  Serial.println("Done"); 
  reset();
}

void registerItem(byte newTag[]){
  Serial.print("Registering item in set ");
  Serial.println(referenceSet);
  if(referenceSet==-1){
    for (int i=0; i<TAGSIZE; i++){ // creates set with single item
      inventory[nSets][0][i]=newTag[i];
    }
    lengths[nSets++]=1;
  }
  else if(referenceSet >= 0) {
    for (int i=0; i<TAGSIZE; i++){
      inventory[referenceSet][lengths[referenceSet]][i]=newTag[i];
    }    
    lengths[referenceSet]++;
    printInventory();
  }
  referenceSet = -1;
  playRegistered();
}

void erase(){
  // set status LED to red
  statusLed(HIGH,LOW,LOW);
  deleting = true;
  printBoolean(deleting);
  scan(DELETE_CYCLE);
  playCompleted();
  Serial.println("Print Inventory");
  printInventory();
  Serial.println("Done"); 
  reset();
}

void deleteItem(int set, int idx){
  Serial.print("Deleting item ");
  Serial.print(idx);
  Serial.print(" in set ");
  Serial.println(set);
  if (lengths[set] == 1){ // set has only one item, remove set and sort inventory
    removeSet(set);   
    Serial.println("Removing set");   
  }
  else{// remove item and sort
    for(int i=idx; i < lengths[set-1]; i++){ 
      for(int b=0; b < TAGSIZE; b++){  // shift all remaning sets with its tags
        inventory[set][i][b]=inventory[set][i+1][b];
      }
    }
    lengths[set]--;
  }
  playDeleted();
}

void removeSet(int setID){
  for(int s=setID; s < nSets-1 ; s++){
    for(int i=0; i < lengths[setID+1]; i++){ 
      for(int b=0; b < TAGSIZE; b++){  
        inventory[s][i][b]=inventory[s+1][i][b];              
      }
    }
    lengths[s]=lengths[s+1];    
  }
  nSets--;
}

////////////////////////////
// FINDING ITEMS
///////////////////////////
int inSet(int setId, byte tag[]){
  for(int i=0; i<lengths[setId]; i++){
    if (sameTag(tag, inventory[setId][i])){
      return i; // break the loop if found in set and return the index
    }
  }
  return -1; // not in set
}

boolean sameTag(byte tag1[], byte tag2[]){
  for(int i=0; i<TAGSIZE; i++){
    if(tag1[i] != tag2[i]){
      return false; // break loop if one byte is different
    }
  }  
  return true; // all bytes are the same
} 

foundRecord& findItem(byte tag[]){
  foundRecord found = {
    -1, -1                };
  int foundIdx = -1;
  for (int s=0; s < nSets && foundIdx<0; s++){
    foundIdx = inSet(s, tag);
    if(foundIdx >= 0){
      found.set = s;
      found.idx = foundIdx;
    }
  }
  return found;
}

/////////////////////////////
// RFID READING
/////////////////////////////
void checkRFID(){
  Serial.println("===========> RFID REPLY");
  int bytecount=0;
  byte incomingByte;
  byte buffer_rfid[BUFFSIZ];
  while(Serial.available())  
  {
    incomingByte = Serial.read();
    buffer_rfid[bytecount++] = incomingByte;   
    Serial.print(incomingByte, HEX);
    Serial.print(" ");
  }
  Serial.println("");  
  if(buffer_rfid[0]== 0x32){ // tag scan response
    parseResponse(buffer_rfid, bytecount);  
  }
}

void parseResponse(byte response[], int length){
  foundRecord record;
  int nTags= (int)response[2];
  int tagIdx=0;    
  int j=0;    
  byte incomingTag[TAGSIZE];

  Serial.print("Tags found: ");
  Serial.println(nTags);  
  if(nTags > 0){ // read all tags
    Serial.print("TAG ID 0: ");      
    for (int i=ID_OFFSET+1; i < length; i++){
      if(j==TAGSIZE){ // next tag
        j=0;
        tagIdx++;
        i+=ID_OFFSET;
        Serial.println("");
        Serial.print("TAG ID ");
        Serial.print(tagIdx);
        Serial.print(": ");                           
      }
      else{
        incomingTag[j] = response[i];
        Serial.print(incomingTag[j], HEX);
        Serial.print(" ");
        if (j==TAGSIZE-1){    // End of tag ID, analize string
          record = findItem(incomingTag);
          if (record.set >= 0){
            Serial.print("ITEM FOUND IN SET_");
            Serial.print(record.set);
            Serial.print("[");
            Serial.print(record.idx);
            Serial.println("]");
            if(registering && referenceSet == -1){
              referenceSet = record.set;
            }
            else if(deleting){
              deleteItem(record.set, record.idx);
            }
            else{
              metaInventory[record.set][record.idx].found=true;
            }
          }
          else if (record.set==-1){
            Serial.println("ITEM NOT FOUND");
            if(registering && referenceSet!= -1) {
              registerItem(incomingTag);
            }
            else if (registering && millis() - registerTimeTag > REGISTER_TIMEOUT){
              registerItem(incomingTag);
              registerTimeTag = millis();
            }
          }
        } 
        j++;
      }
    }
    Serial.println("");
  }
}

///////////////////////
// AUXILIAR METHODS
///////////////////////

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


void emptyMissing(){
  while (!missing.isEmpty()){
    missing.pop();
  }
}

void initializeMeta(){
  for(int s=0; s < nSets; s++){
    for(int m=0; m < lengths[s]; m++){
      metaInventory[s][m].found=false;
    }
  }
}

void displayRGB(uint8_t r, uint8_t g, uint8_t b){
    setPin(knob, redPin, r);    
    setPin(knob, greenPin, g);  
    setPin(knob, bluePin, b);
    applyChanges(knob);
}

void statusLed(int r, int g, int b){
  digitalWrite(hostRedPin, r);
  digitalWrite(hostGreenPin, g);
  digitalWrite(hostBluePin, b);
}

void playCompleted(){
  tone(piezoPin, 200);
  delay(100);
  tone(piezoPin, 300);
  delay(100);
  tone(piezoPin, 400);
  delay(100);
  noTone(piezoPin);
}

//////////////////////////////////
// PRINTING METHODS FOR DEBUGGING
//////////////////////////////////
void printCommand(char cmd[]){
  Serial.println("");
  Serial.print("{");
  for (int i=0; i<3;i++){
    Serial.print("0x");
    Serial.print(cmd[i],HEX);
    if(i<2)
      Serial.print(",");      
  }
  Serial.println("}");
}


void printMetaData(){
  Serial.println("");
  Serial.print("{");
  for(int s=0; s < nSets; s++){
    Serial.print("{");
    for(int idx = 0; idx < lengths[s]; idx++){
      Serial.print("(");
      Serial.print(metaInventory[s][idx].type, DEC);
      Serial.print(", ");
      if (metaInventory[s][idx].found)
        Serial.print("found");
      else
        Serial.print("not found");
      Serial.print("), ");
    }
    Serial.print("}, ");
  }
  Serial.println("}");
}

void printInventory(){
  Serial.println("");
  Serial.print("{");
  for(int s=0; s < nSets; s++){
    Serial.print("{");
    for(int idx = 0; idx < lengths[s]; idx++){
      Serial.print("{");
      for(int b=0; b < TAGSIZE; b++){
        Serial.print(inventory[s][idx][b], HEX);
        Serial.print(", ");
      }      
      Serial.print("}, ");
    }
    Serial.print("}, ");
  }
  Serial.println("}");
}

void printQueue(QueueList <int> q){
  Serial.println("");
  Serial.print("{");
  while(!q.isEmpty()){
    Serial.print(q.pop());
    if(!q.isEmpty()){ //not the last one
      Serial.print(", ");
    }
  }
  Serial.println("}");
}

void printBoolean(boolean b){
  if (b){
    Serial.print("TRUE");
  }else{
    Serial.print("FALSE");
  }
  Serial.println("");
}

void playDeleted(){
  tone(piezoPin, 400);
  delay(100);
  tone(piezoPin, 200);
  delay(100);
  noTone(piezoPin);
}


void playRegistered(){
  tone(piezoPin, 200);
  delay(100);
  tone(piezoPin, 400);
  delay(100);
  noTone(piezoPin);
}


/////////////////////////
// XBEE
/////////////////////////

/////////////////////////
// SETUP XBEE NODES
////////////////////////
void setupBase(){
  Serial.println("BASE ID:");
  checkID(base);

  Serial.println("Disable PWM in for DA1");
  setPWM(base, touchPin, 0x0);

  Serial.println("Set IA to listen to any address");
  setIA(base, 0xff);

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

  Serial.println("Set Red, Blue and Green Pins in Knob to Digital Output Low");
  displayRGB(DO_LOW, DO_LOW, DO_LOW);
    
  Serial.println("Set IR in Knob to 1s");
  setIR(knob, 0x03, 0xe8);

  Serial.println("Set transfer size");
  setIT(knob, 0x1);
  
  Serial.println("Set Destination to Base");
  setDL(knob, base);

  Serial.println("Enable Change Detection in Knob");
  setIC(knob, 0x2);

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

  Serial.println("Set IR in keyring to 20ms");
  setIR(keyring, 0x00, 0x14);

  Serial.println("Apply changes in keyring");
  applyChanges(keyring);

//  Serial.println("Writing changes in keyring");
//  updateFlash(keyring);
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

void sendRemoteAtCommand() {
  Serial.println("");
  Serial.print("Sending command to ");
  Serial.println(RemoteAtRequest.getRemoteAddress16(), HEX);
  // send the command
  xbee.send(RemoteAtRequest);
  Serial.println("");

  // wait up to 5 seconds for the status response
  if (xbee.readPacket(5000)) {
    // got a response!

    // should be an AT command response
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
      Serial.println(xbee.getResponse().getErrorCode());
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
