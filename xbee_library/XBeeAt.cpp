#include "WProgram.h"
#include "XBeeAt.h"
#include <XBee.h>


XBeeAt::XBeeAt(XBee xbee){
  _xbee = _xbee;
  RemoteAtCommandRequest _RemoteAtRequest;
  RemoteAtCommandResponse _RemoteAtResponse = RemoteAtCommandResponse();
  AtCommandRequest _atRequest;
  AtCommandResponse atResponse = AtCommandResponse();
}

void XBeeAt::sendRemoteAtCommand() {
  Serial.println("");
  Serial.print("Sending command to ");
  Serial.println(_RemoteAtRequest.getRemoteAddress16(), HEX);
  // send the command
  _xbee.send(_RemoteAtRequest);
  Serial.println("");

  // wait up to 5 seconds for the status response
  if (_xbee.readPacket(5000)) {
    // got a response!

    // should be an AT command response
    if (_xbee.getResponse().getApiId() == REMOTE_AT_COMMAND_RESPONSE) {
      _xbee.getResponse().getRemoteAtCommandResponse(_RemoteAtResponse);

      if (_RemoteAtResponse.isOk()) {
        Serial.print("Command [AT");
        Serial.print(_RemoteAtResponse.getCommand()[0]);
        Serial.print(_RemoteAtResponse.getCommand()[1]);
        Serial.println("] was successful!");

        if (_RemoteAtResponse.getValueLength() > 0) {
          Serial.print("Command value length is ");
          Serial.println(_RemoteAtResponse.getValueLength(), DEC);

          Serial.print("Command value: ");

          for (int i = 0; i < _RemoteAtResponse.getValueLength(); i++) {
            Serial.print(_RemoteAtResponse.getValue()[i], HEX);
            Serial.print(" ");
          }
          Serial.println("");
        }
      } 
      else {
        Serial.print("Command return error code for [AT");
        Serial.print(_RemoteAtResponse.getCommand()[0]);
        Serial.print(_RemoteAtResponse.getCommand()[1]);
        Serial.print("]: ");
        Serial.println(_RemoteAtResponse.getStatus(), HEX);
        Serial.println("");
      }
    }else {
      Serial.print("Expected Remote AT response but got ");
      Serial.print(_xbee.getResponse().getApiId(), HEX);
    }    
  } 
  else {
    // remote at command failed
    if (_xbee.getResponse().isError()) {
      Serial.print("Error reading packet.  Error code: ");  
      Serial.println(_xbee.getResponse().getErrorCode());
    } 
    else {
      Serial.print("No response from radio");  
    }
  }
}

void XBeeAt::sendAtCommand() {
  Serial.println("");
  Serial.println("Sending command to Base");

  // send the command
  _xbee.send(_atRequest);

  // wait up to 5 seconds for the status response
  if (_xbee.readPacket(5000)) {
    // got a response!

    // should be an AT command response
    if (_xbee.getResponse().getApiId() == AT_COMMAND_RESPONSE) {
      _xbee.getResponse().getAtCommandResponse(_atResponse);

      if (_atResponse.isOk()) {
        Serial.print("Command [AT");
        Serial.print(_atResponse.getCommand()[0]);
        Serial.print(_atResponse.getCommand()[1]);
        Serial.println("] was successful!");

        if (_atResponse.getValueLength() > 0) {
          Serial.print("Command value length is ");
          Serial.println(_atResponse.getValueLength(), DEC);

          Serial.print("Command value: ");
          
          for (int i = 0; i < _atResponse.getValueLength(); i++) {
            Serial.print(_atResponse.getValue()[i], HEX);
            Serial.print(" ");
          }

          Serial.println("");
        }
      } 
      else {
        Serial.print("Command return error code for [AT");
        Serial.print(_atResponse.getCommand()[0]);
        Serial.print(_atResponse.getCommand()[1]);
        Serial.print("]: ");
        Serial.println(_atResponse.getStatus(), HEX);
        Serial.println("");
      }
    } else {
      Serial.print("Expected AT response but got ");
      Serial.print(_xbee.getResponse().getApiId(), HEX);
    }   
  } else {
    // at command failed
    if (_xbee.getResponse().isError()) {
      Serial.print("Error reading packet.  Error code: ");  
      Serial.println(_xbee.getResponse().getErrorCode());
    } 
    else {
      Serial.print("No response from radio");  
    }
  }
}
void XBeeAt::setPin(uint8_t addr, uint8_t pin, uint8_t value, boolean local){
  uint8_t ioCmd[] = { 'D', (char) (pin + '0') };
  uint8_t ioValue[] = { value }; 
  if(local){
    _atRequest = AtCommandRequest(ioCmd, ioValue, sizeof(ioValue));
    sendAtCommand();
    applyChanges(addr, true);
  }else{
    _RemoteAtRequest = RemoteAtCommandRequest(addr, ioCmd, ioValue, sizeof(ioValue));
    sendRemoteAtCommand();
    applyChanges(addr, false);
  }
} 

void XBeeAt::setPWM(uint8_t addr, uint8_t pin, uint8_t value, boolean local){
  uint8_t poCmd[] = { 'P', (char) (pin + '0') };
  uint8_t poValue[] = { value }; 
  if(local){
    _atRequest = AtCommandRequest(poCmd, poValue, sizeof(poValue));
    sendAtCommand();
  }else{
    _RemoteAtRequest = RemoteAtCommandRequest(addr, poCmd, poValue, sizeof(poValue));
    sendRemoteAtCommand();
  }
} 

void XBeeAt::setOutputLevel(uint8_t addr, uint8_t pin, uint8_t value, boolean local){
  uint8_t moCmd[] = { 'M', (char) (pin + '0') };
  uint8_t moValue[] = { value }; 
  if(local){
    _atRequest = AtCommandRequest(moCmd, moValue, sizeof(moValue));
    sendAtCommand();
  }else{
    _RemoteAtRequest = RemoteAtCommandRequest(addr, moCmd, moValue, sizeof(moValue));
    sendRemoteAtCommand();
  }
} 

void XBeeAt::setTimeout(uint8_t addr, uint8_t pin, uint8_t value1, uint8_t value2, boolean local){
  uint8_t toCmd[] = { 'T', (char) (pin + '0') };
  uint8_t toValue[] = { value1, value2 }; 
  if(local){
    _atRequest = AtCommandRequest(toCmd, toValue, sizeof(toValue));
    sendAtCommand();
  }else{
    _RemoteAtRequest = RemoteAtCommandRequest(addr, toCmd, toValue, sizeof(toValue));
    sendRemoteAtCommand();
  }
} 


void XBeeAt::setIA(uint8_t addr, uint8_t value, boolean local){
  uint8_t iaCmd[] = { 'I', 'A' };
  uint8_t iaValue[] = {0xff, 0xff }; 
  if(local){
    _atRequest = AtCommandRequest(iaCmd, iaValue, sizeof(iaValue));
    sendAtCommand();
  }else{
    _RemoteAtRequest = RemoteAtCommandRequest(addr, iaCmd, iaValue, sizeof(iaValue));
    sendRemoteAtCommand();
  }
} 

void XBeeAt::setIU(uint8_t addr, uint8_t value, boolean local){
  uint8_t iuCmd[] = { 'I', 'U' };
  uint8_t iuValue[] = { value }; 
  if(local){
    _atRequest = AtCommandRequest(iuCmd, iuValue, sizeof(iuValue));
    sendAtCommand();
  }else{
    _RemoteAtRequest = RemoteAtCommandRequest(addr, iuCmd, iuValue, sizeof(iuValue));
    sendRemoteAtCommand();
  }
} 

void XBeeAt::setIR(uint8_t addr, uint8_t mseconds1, uint8_t mseconds2, boolean local){
  // Turn on I/O sampling
  uint8_t irCmd[] = {'I','R'};
  uint8_t irValue[] = { mseconds1, mseconds2 };
  _RemoteAtRequest = RemoteAtCommandRequest(addr, irCmd, irValue, sizeof(irValue));
  sendRemoteAtCommand();
}

void XBeeAt::setIC(uint8_t addr, uint8_t value, boolean local){
  // Notify changes in IO
  uint8_t icCmd[] = {'I','C'};
  uint8_t icValue[] = { value };
  _RemoteAtRequest = RemoteAtCommandRequest(addr, icCmd, icValue, sizeof(icValue));
  sendRemoteAtCommand();
}

void XBeeAt::setIT(uint8_t addr, uint8_t value, boolean local){
  // Notify changes in IO
  uint8_t itCmd[] = {'I','T'};
  uint8_t itValue[] = { value };
  _RemoteAtRequest = RemoteAtCommandRequest(addr, itCmd, itValue, sizeof(itValue));
  sendRemoteAtCommand();
}

void XBeeAt::applyChanges(uint8_t addr, boolean local){
  // Notify changes in IO
  uint8_t acCmd[] = {'A','C'};
  if(local){
    _atRequest = AtCommandRequest(acCmd);
    sendAtCommand();
  }else{
    _RemoteAtRequest = RemoteAtCommandRequest(addr, acCmd);
    sendRemoteAtCommand();
  }
}

void XBeeAt::forceSample(uint8_t addr, boolean local){
  // Notify changes in IO
  uint8_t isCmd[] = {'I','S'};
  if(local){
    _atRequest = AtCommandRequest(isCmd);
    sendAtCommand();
  }else{
    _RemoteAtRequest = RemoteAtCommandRequest(addr, isCmd);
    sendRemoteAtCommand();
  }
}

void XBeeAt::updateFlash(uint8_t addr, boolean local){
  uint8_t wrCmd[] = {'W','R'};
  if(local){
    _atRequest = AtCommandRequest(wrCmd);
    sendAtCommand();
  }else{
    _RemoteAtRequest = RemoteAtCommandRequest(addr, wrCmd);
    sendRemoteAtCommand();
  }
}

void XBeeAt::softReset(uint8_t addr, boolean local){
  uint8_t frCmd[] = {'F','R'};
  if(local){
    _atRequest = AtCommandRequest(frCmd);
    sendAtCommand();
  }else{
    _RemoteAtRequest = RemoteAtCommandRequest(addr, frCmd);
    sendRemoteAtCommand();
  }
}

void XBeeAt::setDL(uint8_t addr, uint8_t dest, boolean local){
  // Set destination address for IO
  uint8_t dlCmd[] = {'D','L'};
  // Coordinator's ID
  uint8_t dlValue[] = { local };
  _RemoteAtRequest = RemoteAtCommandRequest(addr, dlCmd, dlValue, sizeof(dlValue));
  sendRemoteAtCommand();
}

void XBeeAt::checkID(uint8_t addr, boolean local){
  // Print ID
  uint8_t idCmd[] = {'M','Y'};
  if(local){
    _atRequest = AtCommandRequest(idCmd);
    sendAtCommand();
  }else{
    _RemoteAtRequest = RemoteAtCommandRequest(addr, idCmd);
    sendRemoteAtCommand();
  }
}
