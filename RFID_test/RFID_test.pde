#include <NewSoftSerial.h>
#include <EEPROM.h>
#include <QueueList.h>

#define BUFFSIZ 90
#define SETSIZE 16
#define MAXSETS 16
#define TAGSIZE 12
#define ID_OFFSET 5

#define IN_FIRM_HARDW_ID 0x11
#define IN_INVENTORY 0x32

#define REACTIVE_TAG {0xE2, 0x0, 0x10, 0x66, 0x66, 0x14, 0x0, 0x76, 0x19, 0x40, 0x4C, 0xCC}
#define ID_TAG {0xE2, 0x0, 0x10, 0x66, 0x66, 0x14, 0x0, 0x74, 0x19, 0x40, 0x4C, 0xC4}
#define PHONE_TAG {0xE2, 0x0, 0x10, 0x66, 0x66, 0x14, 0x0, 0x75, 0x19, 0x40, 0x4C, 0xC8}
#define DOCUMENT_TAG {0x30, 0x8, 0x33, 0xB2, 0xDD, 0xD9, 0x6, 0xC0, 0x0, 0x0, 0x0, 0x0}
#define HOME_TAG {0xE2, 0x0, 0x19, 0x96, 0x96, 0x2, 0x1, 0x32, 0x21, 0x50, 0x35, 0x1D}
#define CAR_TAG {0xE2, 0x0, 0x19, 0x96, 0x96, 0x2, 0x1, 0x32, 0x10, 0x90, 0xA9, 0x17}
#define KEYS_TAG {CAR_TAG, HOME_TAG}

// Define NewSoftrfid TX/RX pins
// Connect Arduino pin 9 to TX of usb-rfid device
char ssRX = 9;
// Connect Arduino pin 10 to RX of usb-rfid device
char ssTX = 10;
// Send through NSS and receive through serial for the RFID
NewSoftSerial nss(ssRX, ssTX);

int nSets=3; // number of sets defined

byte inventory[][SETSIZE][TAGSIZE]={ {HOME_TAG, ID_TAG, PHONE_TAG  } ,{ REACTIVE_TAG  },  { CAR_TAG  }};
int lengths[]={3,1,1};//[MAXSETS] // array storing the length for each set

boolean found [MAXSETS][SETSIZE]; // array to mark the tags found in the scan
int foundLengths[MAXSETS]; // array storing the length for each set of found items

byte missing[MAXSETS*SETSIZE][TAGSIZE]; // array with the missing tags
int missingCount=0;



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
  resetFound();
  // wait for reader to powerup  
  delay(2000);
  Serial.println("START SCANNING");
}

void loop() 
{  
  nss.print(command_scantag);  
  //printCommand(command_scantag);
  checkRFID();
  delay(2000);
}

void resetFound(){
  for (int s=0; s<nSets; s++){
    for (int i=0; i<lengths[s]; i++){
      found[s][i]=false;
    }
    foundLengths[s]=0;
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

void scan(int time){
  int timetag = millis();
  boolean success=true;
  while (millis()-timetag < time){
    if(success){ //Response received, issue next command 
      nss.print(command_scantag);
      printCommand(command_scantag);
    }
    success=checkRFID();
  }
}

void buildMissing(){
  missingCount=0;
  for (int i=0; i < nSets; i++){
    for (int j=0; j < lengths[i]; j++){
      if (!found[i][j]){
        copyTag(missing[missingCount++],inventory[i][j]);
      }
    }
  }
}

void copyTag(byte dest[], byte source[]){
  for (int i=0; i<TAGSIZE; i++){
    dest[i]=source[i];
  }
}

boolean checkRFID(){
  boolean success;
  int bytecount=0;
  byte incomingByte;
  byte buffer_rfid[BUFFSIZ];
  if(Serial.available()){
    Serial.println("===========> RFID REPLY");
    success = true;
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

void findItem(byte tag[]){
  int foundIdx = -1;
  for (int s=0; s < nSets && foundIdx<0; s++){
    foundIdx = inSet(s, tag);
    if(foundIdx >= 0){
      Serial.print(" ");
      Serial.print("========> FOUND IN SET: ");
      Serial.print(s, DEC);
      Serial.print(",INDEX: ");
      Serial.println(foundIdx, DEC);
      if(!found[s][foundIdx]){ //not repeated
        foundLengths[s]++;
        found[s][foundIdx]=true;
      }
    }
  }
  if(foundIdx == -1){
    Serial.print(" ");
    Serial.println("========> NOT IN INVENTORY");
  }
}


void parseResponse(byte response[], int length){
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
      byte tag[TAGSIZE];
      Serial.print("TAG ID 1: ");      
      for (int i=ID_OFFSET+1; i < length; i++){
        if(j==TAGSIZE){ // next tag
          j=0;
          tagIdx++;
          i+=ID_OFFSET;
          Serial.println("");
          Serial.print("TAG ID ");
          Serial.print(tagIdx+1);
          Serial.print(": ");                           
        }
        else{
          tag[j] = response[i];
          Serial.print(tag[j], HEX);
          Serial.print(" ");
          if (j==TAGSIZE-1){    // End of tag ID, analize string
            findItem(tag);
          }             
          j++;
        }
      }
      Serial.println("");
    }
  }
}






