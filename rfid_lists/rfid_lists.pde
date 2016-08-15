#include <NewSoftSerial.h>
#include <QueueList.h>

const int BUFFSIZ = 90;
const int SETSIZE = 16;
const int MAXSETS = 16;
const int TAGTYPES = 5;
const int TAGSIZE = 12;
const int ID_OFFSET = 5;

const byte IN_FIRM_HARDW_ID = 0x11;
const byte IN_INVENTORY = 0x32;

const int DOC_TYPE = 1;
const int ID_TYPE = 2;
const int PHONE_TYPE = 3;
const int KEY_TYPE = 1;
const int REACTIVE_TYPE = 5;

const int SCAN_TIME = 5000; //scanning time in ms

#define REACTIVE_TAG {0xE2, 0x0, 0x10, 0x66, 0x66, 0x14, 0x0, 0x76, 0x19, 0x40, 0x4C, 0xCC}
#define ID_TAG {0xE2, 0x0, 0x10, 0x66, 0x66, 0x14, 0x0, 0x74, 0x19, 0x40, 0x4C, 0xC4}
#define PHONE_TAG {0xE2, 0x0, 0x10, 0x66, 0x66, 0x14, 0x0, 0x75, 0x19, 0x40, 0x4C, 0xC8}
#define DOCUMENT_TAG {0x30, 0x8, 0x33, 0xB2, 0xDD, 0xD9, 0x6, 0xC0, 0x0, 0x0, 0x0, 0x0}
#define HOME_TAG  {0xE2, 0x0, 0x19, 0x96, 0x96, 0x2, 0x1, 0x32, 0x21, 0x50, 0x35, 0x1D}
#define CAR_TAG {0xE2, 0x0, 0x19, 0x96, 0x96, 0x2, 0x1, 0x32, 0x10, 0x90, 0xA9, 0x17}

// Define NewSoftSerial TX/RX pins
// Connect Arduino pin 9 to TX of usb-rfid device
const int ssRX = 9;
// Connect Arduino pin 10 to RX of usb-rfid device
const int ssTX = 10;
// Send through NSS and receive through serial for the RFID
NewSoftSerial nss(ssRX, ssTX);

struct foundRecord{
  int set;
  int idx;
};

struct metaData{
  int type;
  boolean found;
};

byte incomingTag[TAGSIZE];
int referenceSet = -1;

byte inventory[][SETSIZE][TAGSIZE]={{HOME_TAG, ID_TAG, PHONE_TAG}, 
                                    {REACTIVE_TAG}, 
                                    {CAR_TAG}};
   
metaData metaInventory[][SETSIZE]={{{KEY_TYPE, false}, {ID_TYPE, false}, {PHONE_TYPE, false}},
                                   {{REACTIVE_TYPE, false}},  
                                   {{KEY_TYPE, false}}};

int nSets=3; // number of sets defined
int lengths[]={3,1,1};//[MAXSETS] // array storing the length for each set

boolean searching;
boolean deleting;
boolean registering;

QueueList <int> searchCandidates;
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
  Serial.begin(115200);
  nss.begin(115200);  
  reset();
  // wait for reader to powerup  
  delay(2000);
  Serial.println("START SCANNING");
}

void loop() 
{  
  search();
  //nss.print(command_scantag);  
  //printCommand(command_scantag);
  checkRFID();
  //delay(2000);
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

void reset(){
  initializeCandidates();
  initializeMeta();
  searching = false;
  deleting = false;
  registering = false;
}

void initializeMeta(){
  for(int s=0; s < nSets; s++){
    for(int m=0; m < lengths[s]; m++){
      metaInventory[s][m].found=false;
    }
  }
}

void initializeCandidates(){
// data structure: |-1|set0ID|set0Indexes|...|-1|setNID|setNIndexes|
  for(int s=0; s < nSets; s++){
    searchCandidates.push(-1);
    searchCandidates.push(s);
    for(int i=0; i<lengths[s]; i++){
      searchCandidates.push(i);
    }
  }
}

void scan(){
  int timetag = millis();
  boolean success=true;
  while (millis()-timetag < SCAN_TIME){
    if(success){ //Response received, issue next command 
      nss.print(command_scantag);
      printCommand(command_scantag);
    }
    success=checkRFID();
  }
}

void search(){
  searching = true;
  scan();
  buildMissing();
  reset();
}


void doRegister(){
  registering = true;
  scan();
  registerItem(incomingTag, referenceSet);
  reset();
}

void doDelete(){
  deleting = true;
  scan();
  reset();
}

void deleteItem(int setID, int idx){
//    if (lengths[setID] == 1){ // set has only one item, remove set and sort inventory
//      byte newInventory[nSets-1][SETSIZE][TAGSIZE];
//      for(int s=0; s < setID ; s++){
//          newInventory[s]=inventory[s];
//      }    
//      for(int s=setID+1; s < nSets ; s++){
//          newInventory[s-1]=inventory[s];
//      }
//      inventory = newInventory;
//      nSets--;
//    }else{// remove item and sort
//      byte newSet[lengths[setID-1]][TAGSIZE];
//      for(int i=0; i < idx; i++){ 
//          newSet[i]=inventory[setID][i];
//      }
//      for(int i=idx+1; i < lengths[setID]; i++){ 
//          newSet[i-1]=inventory[setID][i];
//      }
//      inventory[setID] = newSet;
//      lengths[setID]--;
//    }
}

void registerItem(byte newTag[], int set){
  if(set==-1){
    for (int i=0; i<TAGSIZE; i++){ // creates set with single item
      inventory[nSets+1][0][i]=newTag[i];
    }
    nSets++;
  }else{
    for (int i=0; i<TAGSIZE; i++){
      inventory[set][lengths[set+1]][i]=newTag[i];
    }
    lengths[set]++;
  }
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
  

boolean checkRFID(){
  boolean success;
  int bytecount=0;
  byte incomingByte;
  byte buffer_rfid[BUFFSIZ];
  if(Serial.available()){
    success = true;
    Serial.println("===========> RFID REPLY");
    while(Serial.available())  
    {
      incomingByte = Serial.read();
      buffer_rfid[bytecount++] = incomingByte;      
      Serial.print(incomingByte, HEX);
      Serial.print(" ");
    }
    Serial.println("");  
    parseResponse(buffer_rfid, bytecount);  
  }
  else{
    success = false;
  }
  return success;
}

foundRecord& findItem(byte readByte, int byteIdx){
  //printQueue(searchCandidates);
  QueueList <int> tmpList;
  int queueLength = searchCandidates.count();
  Serial.println(queueLength);
  foundRecord found = {-2, -2}; 
  int setID = -2;
  int itemIdx = -2;
  for(int i=0; i < queueLength; i++){
//  while(!searchCandidates.isEmpty()){
    itemIdx = searchCandidates.pop();
//    Serial.println(itemIdx);
    if (itemIdx == -1){ //setID marker
      setID = searchCandidates.pop(); // next element in list will be a set ID
//      Serial.println(setID);
    }else if (readByte == inventory[setID][itemIdx][byteIdx] && !metaInventory[setID][itemIdx].found){ // byte matches and has not been marked as found 
      if(setID != -1){ //first time set matches
        tmpList.push(-1); // push marker at the end of the queue
        tmpList.push(setID); // push setID after marker 
        setID = -1;
      }
      tmpList.push(itemIdx); // push matching indexes 
    }
  }
  if (tmpList.count()==3){ //found item
    Serial.println("FOUND?");
    tmpList.pop(); //skip marker
    found.set = tmpList.pop(); // pop set ID
    found.idx = tmpList.pop(); // pop index
  }else if (tmpList.isEmpty()){ // item not found
    Serial.println("NOT FOUND?");
    found.set = -1;
    found.idx = -1;
  }else{
    searchCandidates=tmpList;
  }
  return found;
}

void parseResponse(byte response[], int length){
  foundRecord record;
  boolean ready = true;
  Serial.println("RESPONSE");
  for(int i=0 ;i < length; i++){
    Serial.print(response[i], HEX);
    Serial.print(" ");
  }
  Serial.println("");

  if (response[0] == 0x32){ // tag scan response
    int nTags= (int)response[2];
    int tagIdx=0;    
    int j=0;    
    Serial.print("Tags found: ");
    Serial.println(nTags);  
    if(nTags > 0){ // read all tags
      Serial.print("TAG ID 0: ");      
      for (int i=ID_OFFSET+1; i < length; i++){
        if(j==TAGSIZE){ // next tag
          j=0;
          tagIdx++;
          i+=ID_OFFSET;
          ready=true;
          initializeCandidates();
          Serial.println("");
          Serial.print("TAG ID ");
          Serial.print(tagIdx);
          Serial.print(": ");                           
        }
        else{
          incomingTag[j] = response[i];
          if(ready){
            record = findItem(incomingTag[j], j);
            if (record.set >= 0){
              Serial.print("ITEM FOUND IN SET_");
              Serial.print(record.set);
              Serial.print("[");
              Serial.print(record.idx);
              Serial.println("]");
              if(searching){
                metaInventory[record.set][record.idx].found=true;
              }
              if(registering){
                referenceSet=record.set;
              }
              if(deleting){
                deleteItem(record.set, record.idx);
              }
              ready=false; //stop searching until next tag
            }else if (record.set==-1){
              Serial.println("ITEM NOT FOUND");
              if(registering){
                referenceSet=record.set;
              }
              ready=false;              
            }
          }
          //Serial.print(incomingTag[j], HEX);
          //Serial.print(" ");
          j++;
        }
      }
      Serial.println("");
    }
  }
}
