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

const byte buttonPin = 8;
const byte redPin = 5;
const byte greenPin = 6;
const byte bluePin = 7;
const byte piezoPin = 11;
// Define NewSoftSerial TX/RX pins
// Connect Arduino pin 9 to TX of usb-rfid device
const byte ssRX = 9;
// Connect Arduino pin 10 to RX of usb-rfid device
const byte ssTX = 4;
// Send through NSS and receive through serial for the RFID
NewSoftSerial rfid(ssRX, ssTX);

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

char command_hardware[]={
  0x10,0x03,0x01};
char command_software[]={
  0x10,0x03,0x00};

char command_powerOff[]={
  0x18,0x03,0x00};
char command_powerOn[]={
  0x18,0x03,0xff};

char command_scantag[]={
  0x31,0x03,0x01};

void setup(){
  pinMode(redPin, OUTPUT);
  pinMode(greenPin, OUTPUT);
  pinMode(bluePin, OUTPUT);
  pinMode(buttonPin, INPUT);

  Serial.begin(115200);
  rfid.begin(115200);  
  reset();
  //Initialize lengths
  for (int i=0; i<MAXSETS; i++){
    lengths[i]=0;
  }
  // wait for reader to powerup  
  delay(2000);
  Serial.println("READY");
}

void loop() 
{  
  // Reader should be always scanning and updating the found array
  // found should have a vailidy of about 60 seconds
  // after knob is touched build Missing give feedback and reset
  if(!registering && !deleting){
    checkButton();

    if (millis() - foundTimeTag > FOUND_TIMEOUT){
      Serial.println("Found Timeout");
      printMetaData();
      initializeMeta();
      foundTimeTag = millis();
    } 
    rfid.print(command_scantag);
    delay(200);
    checkRFID();
  }
}

void statusLed(int r, int g, int b){
  digitalWrite(redPin, r);
  digitalWrite(greenPin, g);
  digitalWrite(bluePin, b);
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

void reset(){
  // set status LED to green
  statusLed(LOW, HIGH, LOW);
  initializeMeta();
  referenceSet = -1;
  deleting = false;
  Serial.print("Deleting is ");
  printBoolean(deleting);
  registering = false;
  registerTimeTag = 0;
  Serial.print("Registering is ");
  printBoolean(registering);
  buttonTimeTag = 0;
  emptyMissing();  
  foundTimeTag = millis();
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

void scan(unsigned long time){
  unsigned long timetag = millis();
  boolean success=true;
  while (millis()-timetag < time){
    rfid.print(command_scantag);
    delay(200);
    checkRFID();
  }
}


void registerNew(){
  // set status LED to blue
  statusLed(LOW,LOW,HIGH);
  registering = true;
  Serial.print("Registering is ");
  printBoolean(registering);
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
  Serial.print("Deleting is ");
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

void playCompleted(){
  tone(piezoPin, 200);
  delay(100);
  tone(piezoPin, 300);
  delay(100);
  tone(piezoPin, 400);
  delay(100);
  noTone(piezoPin);
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

void buildMissing(){
  for (int s=0; s < nSets; s++){
    for (int m=0; m < lengths[s]; m++){
      if(!metaInventory[s][m].found){
        missing.push(metaInventory[s][m].type);
      }
    }
  }
}

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



int memoryTest() {
  int byteCounter = 0; // initialize a counter
  byte *byteArray; // create a pointer to a byte array
  // More on pointers here: http://en.wikipedia.org/wiki/Pointer#C_pointers

  // use the malloc function to repeatedly attempt allocating a certain number of bytes to memory
  // More on malloc here: http://en.wikipedia.org/wiki/Malloc
  while ( (byteArray = (byte*) malloc (byteCounter * sizeof(byte))) != NULL ) {
    byteCounter++; // if allocation was successful, then up the count for the next try
    free(byteArray); // free memory after allocating it
  }

  free(byteArray); // also free memory after the function finishes
  return byteCounter; // send back the highest number of bytes successfully allocated
}







