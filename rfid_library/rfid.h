/*
  RFID.h - Library for controlling UHF RFID reader 
  for "Doh" project.
  Created by David Montero G., November 8, 2011.
*/

#ifndef RFID_h
#define RFID_h

#include "WProgram.h"
#include <QueueList.h>
#include <NewSoftSerial.h>

// empty the array of found items every minute
#define BUFFSIZ 90
#define SETSIZE 6
#define MAXSETS 6
#define TAGTYPES 5
#define TAGSIZE 12
#define ID_OFFSET 5

#define DOC_TYPE = 1
#define ID_TYPE = 2
#define PHONE_TYPE = 3
#define KEY_TYPE = 4
#define REACTIVE_TYPE  5

#define DELETE_CYCLE 5000
#define REGISTER_CYCLE 10000

// keep the button pressed for 2 secs to delete an item
#define DELETE_TIMEOUT 2000

// Create new set when registering item if no reference set is found in 2 seconds
#define REGISTER_TIMEOUT 2000

class RFID
{
public:
  unsigned long foundTimeTag;

  boolean deleting;
  boolean registering;

  NewSoftSerial* nss;

  char command_scantag[];
  
  RFID(byte redPin, byte greenPin, byte bluePin, byte buttonPin, byte piezoPin, uint8_t RX, uint8_t TX);
  void statusLed(int r, int g, int b);
  void checkButton();
  void printCommand(char cmd[]);
  void printMetaData();
  void printInventory();
  void printQueue(QueueList <int> q);
  void printBoolean(boolean b);
  void reset();
  void emptyMissing();
  void initializeMeta();
  void scan(unsigned long time);
  void registerNew();
  void registerItem(byte newTag[]);
  void erase();
  void deleteItem(int set, int idx);
  void removeSet(int setID);
  void playCompleted();
  void playDeleted();
  void playRegistered();
  void buildMissing();
  int inSet(int setId, byte tag[]);
  boolean sameTag(byte tag1[], byte tag2[]);
  void findItem(byte tag[]);
  void checkRFID();
  void parseResponse(byte response[], int length);
private:
  //#define REACTIVE_TAG {0xE2, 0x0, 0x10, 0x66, 0x66, 0x14, 0x0, 0x76, 0x19, 0x40, 0x4C, 0xCC}
  //#define ID_TAG {0xE2, 0x0, 0x10, 0x66, 0x66, 0x14, 0x0, 0x74, 0x19, 0x40, 0x4C, 0xC4}
  //#define PHONE_TAG {0xE2, 0x0, 0x10, 0x66, 0x66, 0x14, 0x0, 0x75, 0x19, 0x40, 0x4C, 0xC8}
  //#define DOCUMENT_TAG {0x30, 0x8, 0x33, 0xB2, 0xDD, 0xD9, 0x6, 0xC0, 0x0, 0x0, 0x0, 0x0}
  //#define HOME_TAG  {0xE2, 0x0, 0x19, 0x96, 0x96, 0x2, 0x1, 0x32, 0x21, 0x50, 0x35, 0x1D}
  //#define CAR_TAG {0xE2, 0x0, 0x19, 0x96, 0x96, 0x2, 0x1, 0x32, 0x10, 0x90, 0xA9, 0x17}

  byte buttonPin;
  byte redPin;
  byte greenPin;
  byte bluePin;
  byte piezoPin;
  
  struct foundRecord{
    int set;
    int idx;
  };

  struct metaData{
    int type;
    boolean found;
  };

  int referenceSet;

  unsigned long buttonTimeTag;

  unsigned long registerTimeTag;

  byte inventory[MAXSETS][SETSIZE][TAGSIZE];

  metaData metaInventory[MAXSETS][SETSIZE];

  int nSets; // number of sets defined
  int lengths[MAXSETS]; // array storing the length for each set

  QueueList <int> missing;
};

#endif


