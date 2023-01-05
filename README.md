# WePower gemns Demo iOS App  

Demo iOS application showcasing WePower's gemns device  

This demo requires CryptoSwift pod.  

This is a sample application that works alongside the WePower BLE Demo Application Firmware.   

This demo app receives the BLE beacon, decrypts the payload and parses it, extracting counters and sensor data. It also validates that the ID sent in the clear matches the encrypted ID.  
  
What is important to note, is that the data that a user puts in the manufacturing data is completely up to the user. WePower does not require a particular payload structure.   

The AES key is default and assumes that a user would generate this in a cryptographically secure method. It's also possible to support unique AES keys per device, in fact this is suggested. 
