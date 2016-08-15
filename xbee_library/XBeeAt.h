/*
  XBeeAt.h - Library for controlling XBees in API mode 
  to use with "Doh" project.
  Created by David Montero G., November 8, 2011.
*/
#ifndef XBeeAt_h
#define XBeeAt_h

#include "WProgram.h"
#include <XBee.h>

class XBeeAt
{
  public:
    XBeeAt(XBee xbee);
    void sendRemoteAtCommand();
    void sendAtCommand();
    void setPin(uint8_t addr, uint8_t pin, uint8_t value, boolean local);
    void setPWM(uint8_t addr, uint8_t pin, uint8_t value, boolean local);
    void setOutputLevel(uint8_t addr, uint8_t pin, uint8_t value, boolean local);
    void setTimeout(uint8_t addr, uint8_t pin, uint8_t value1, uint8_t value2, boolean local);
    void setIA(uint8_t addr, uint8_t value, boolean local);
    void setIU(uint8_t addr, uint8_t value, boolean local);
    void setIR(uint8_t addr, uint8_t mseconds1, uint8_t mseconds2, boolean local);
    void setIC(uint8_t addr, uint8_t value, boolean local);
    void setIT(uint8_t addr, uint8_t value, boolean local);
    void applyChanges(uint8_t addr, boolean local);
    void forceSample(uint8_t addr, boolean local);
    void updateFlash(uint8_t addr, boolean local);
    void softReset(uint8_t addr, boolean local);  
    void setDL(uint8_t addr, uint8_t dest, boolean local);
    void checkID(uint8_t addr, boolean local);
  private:
    XBee _xbee;
    RemoteAtCommandRequest _RemoteAtRequest;
    RemoteAtCommandResponse _RemoteAtResponse;
    AtCommandRequest _atRequest;
    AtCommandResponse _atResponse;

};

#endif
