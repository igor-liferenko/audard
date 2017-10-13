
/*
 *  ardtestdhcp.pde
 *  Test several DHCP libraries..
 *
 *  The code reports its results through serial 
 *
 *  ardtestdhcp.pde
 *  ------------
 *  Latest update: May 15 2010
 *  ------------
 *  Copyleft: use as you like
 *  sd [] imi.aau.dk
 *
 */

/*

# here, the needed libraries will be installed in the 
#  Arduino sketch library
# (the following commands could be executed as a batch script)  

cd /home/USERNAME/sketchbook
mkdir libraries
cd libraries


# it seems that Arduino libraries are searched in each subdir of 
#  libraries folder; and the headers found there are entered
#  without a path
# That is why here we rename the class (and according files) 
#  of jt 'vanilla' Dhcp.h

wget http://blog.jordanterrell.com/public/Arduino-DHCPv0.4.zip
unzip Arduino-DHCPv0.4.zip -d jt_Arduino_DHCPv0_4
mv jt_Arduino_DHCPv0_4/Dhcp.h jt_Arduino_DHCPv0_4/jt_Dhcp.h
sed -i "s/Dhcp.h/jt_Dhcp.h/" jt_Arduino_DHCPv0_4/Dhcp.cpp
# the below refer to files in built-in Ethernet library
#  must be changed so we can compile!
sed -i "s/types.h/utility\/types.h/" jt_Arduino_DHCPv0_4/Dhcp.cpp
sed -i "s/w5100.h/utility\/w5100.h/" jt_Arduino_DHCPv0_4/Dhcp.cpp
sed -i "s/socket.h/utility\/socket.h/" jt_Arduino_DHCPv0_4/Dhcp.cpp
sed -i "s/spi.h/utility\/spi.h/" jt_Arduino_DHCPv0_4/Dhcp.cpp
sed -i "s/types.h/utility\/types.h/" jt_Arduino_DHCPv0_4/utility/sockutil.c
sed -i "s/types.h/utility\/types.h/" jt_Arduino_DHCPv0_4/utility/util.c
# also this hack, else DHCP doesn't work for me:
sed -i "s/result = 1;/result = 1; break; \/\/added/" jt_Arduino_DHCPv0_4/Dhcp.cpp
# and also "re-class" to avoid conflicts
mv jt_Arduino_DHCPv0_4/Dhcp.cpp jt_Arduino_DHCPv0_4/jt_Dhcp.cpp
sed -i "s/DhcpClass/jt_DhcpClass/g" jt_Arduino_DHCPv0_4/jt_Dhcp.cpp
sed -i "s/DhcpClass/jt_DhcpClass/g" jt_Arduino_DHCPv0_4/jt_Dhcp.h

# ...
# then, Dhcp.h will refer to file in kegger 
#  (even though it is also version of jt's Dhcp.h)
# the zip is a packaged svn folder:
# wget http://kegger.googlecode.com/files/Ethernet.zip
# so direct with svn for kegger:
svn checkout http://kegger.googlecode.com/svn/trunk/Ethernet kegger_Ethernet

# ...
# finally, gkaindl_ArduinoEthernet
wget http://gkaindl.com/downloads/stuff/arduino-ethernet/ArduinoEthernet.zip
unzip ArduinoEthernet.zip
# actually, must have subdirs of ArduinoEthernet unpacked,
# so don't rename the whole thing
# mv ArduinoEthernet gkaindl_ArduinoEthernet
mv ArduinoEthernet/EthernetBonjour gkaindl_EthernetBonjour
mv ArduinoEthernet/EthernetDHCP gkaindl_EthernetDHCP
mv ArduinoEthernet/EthernetDNS gkaindl_EthernetDNS
rm -rf ArduinoEthernet

rm *.zip

 */

// choice of dhcp library
// choose only one define - comment the rest :) 
// but also must comment the oncludes too - 
//  else libs get copied to /tmp/build*, and conflict! 
// Just to be sure, when changing defines, also 
//  rm -rf /tmp/build* - and restart Arduino IDE...
//  (/tmp/build gets cleaned on save of .pde with changes, though)
//#define DHCP_JT // jordanterrell - Arduino-DHCPv0.4
//#define DHCP_KG // kegger - (A)Ethernet
#define DHCP_GK // gkaindl - ArduinoEthernet/EthernetDHCP

// but also must comment the includes too - 
#ifdef DHCP_JT
//static char* dhcplib="DHCP_JT";
//#include <Ethernet.h> //jt-WebClientWithDHCP
//#include <jt_Dhcp.h> //jt-WebClientWithDHCP
#endif
#ifdef DHCP_KG
//static char* dhcplib="DHCP_KG";
//#include <AEthernet.h> //kegger-WebClientWithDHCP
//#include "Dhcp.h"  //kegger-WebClientWithDHCP - this now specifically should refer to kegger version
#endif
#ifdef DHCP_GK
static char* dhcplib="DHCP_GK";
#include <Ethernet.h> //gkeindl: PollingDHCP.pde
#include <EthernetDHCP.h> //gkeindl: PollingDHCP.pde
#endif

#include <string.h> //jt-WebClientWithDHCP

// setting to static IP's - will be overwritten by DHCP
byte mac_ard[] = { 0xDE, 0xAD, 0xBE, 0xEF, 0xFE, 0xED };
byte ip_ard[] = { 192, 168, 1, 123 };
byte gateway_ard[] = { 192, 168, 1, 1 };
byte subnet_ard[] = { 255, 255, 255, 0 };

byte ip_dhcp_srv[] = { 0, 0, 0, 0 };
byte ip_dns_srv[] = { 0, 0, 0, 0 };

boolean ipAcquired = false;


/*
* MAIN FUNCTIONS  ****************************************************************
*/

void setup()
{
  Serial.begin(115200); // initialize the communication
  delay(1000); //does it help? .. yes, for registering first DHCP request
  setupDHCP();
}

void loop()
{
  Serial.println(dhcplib);
  if(ipAcquired)
  {
    Serial.println("ip Acquired ");
    ifconfig();
  }
  else
  {
    Serial.print("ip NOT Acquired: ");
#ifdef DHCP_GK //cannot call setupDHCP for poll
// here we're making it block by using the 'while ...', 
//  but that is just for this example to render messages 'realtime'..
  while (!ipAcquired)
  {
    gk_poll_loop_dhcp();
    delay(20);
  }
#else    
    setupDHCP();
#endif
  }
#ifdef DHCP_GK   
  EthernetDHCP.maintain(); //poll is called only during setup!
#endif
  delay(2000);
}


/*
* SUPPORT FUNCTIONS  ****************************************************************
*/

void setupDHCP()
{
#ifdef DHCP_JT
  jt_dhcp_setup();
#endif
#ifdef DHCP_KG
  kg_dhcp_setup();
#endif
#ifdef DHCP_GK
  gk_dhcp_setup();
#endif
}

#ifdef DHCP_JT
// from jt-Arduino-DHCPv0.4/examples/WebClientWithDHCP/WebClientWithDHCP.pde
void jt_dhcp_setup()
{

  Serial.println("getting ip...");
  //int result = Dhcp.beginWithDHCP(mac_ard);
  // 10 s wait time for DHCP offer - else it don't work for me
  int result = Dhcp.beginWithDHCP(mac_ard, 60000, 10000); 

  if(result == 1)
  {
    ipAcquired = true;

    Serial.println("ip acquired...");
    
    // get data, write 
    Dhcp.getLocalIp(ip_ard);
    Dhcp.getSubnetMask(subnet_ard);
    Dhcp.getGatewayIp(gateway_ard);
    Dhcp.getDhcpServerIp(ip_dhcp_srv);
    Dhcp.getDnsServerIp(ip_dns_srv);
    
    ifconfig();
    
    delay(3000);

    /*
    Serial.println("connecting...");

    if (client.connect()) {
      Serial.println("connected");
      client.println("GET /search?q=arduino HTTP/1.0");
      client.println();
    } else {
      Serial.println("connection failed");
    }
    */
  }
  else
    Serial.println("unable to acquire ip address...");
}
#endif //DHCP_JT

#ifdef DHCP_KG
// from kegger_Ethernet/examples/WebClientWithDHCP/WebClientWithDHCP.pde
void kg_dhcp_setup()
{
  Serial.println("getting ip...");
  int result = Dhcp.beginWithDHCP(mac_ard);

  if(result == 1)
  {
    ipAcquired = true;

    Serial.println("ip acquired...");
    
    // get data, write 
    Dhcp.getLocalIp(ip_ard);
    Dhcp.getSubnetMask(subnet_ard);
    Dhcp.getGatewayIp(gateway_ard);
    Dhcp.getDhcpServerIp(ip_dhcp_srv);
    Dhcp.getDnsServerIp(ip_dns_srv);
    
    ifconfig();
    
    delay(3000);
  }
  else
    Serial.println("unable to acquire ip address...");  
}
#endif //DHCP_KG

#ifdef DHCP_GK
// from gkaindl_EthernetDHCP/examples/PollingDHCP/PollingDHCP.pde
void gk_dhcp_setup()
{
  // Initiate a DHCP session. The argument is the MAC (hardware) address that
  // you want your Ethernet shield to use. The second argument enables polling
  // mode, which means that this call will not block like in the
  // SynchronousDHCP example, but will return immediately.
  // Within your loop(), you can then poll the DHCP library for its status,
  // finding out its state, so that you can tell when a lease has been
  // obtained. You can even find out when the library is in the process of
  // renewing your lease.
  EthernetDHCP.setHostName("ArdTestDhcp");
  EthernetDHCP.begin(mac_ard, 1);  
}  

void gk_poll_loop_dhcp()
{
  static DhcpState prevState = DhcpStateNone;
  static unsigned long prevTime = 0;
  
  // poll() queries the DHCP library for its current state (all possible values
  // are shown in the switch statement below). This way, you can find out if a
  // lease has been obtained or is in the process of being renewed, without
  // blocking your sketch. Therefore, you could display an error message or
  // something if a lease cannot be obtained within reasonable time.
  // Also, poll() will actually run the DHCP module, just like maintain(), so
  // you should call either of these two methods at least once within your
  // loop() section, or you risk losing your DHCP lease when it expires!
  DhcpState state = EthernetDHCP.poll();

  if (prevState != state) {
    Serial.println();

    switch (state) {
      case DhcpStateDiscovering:
        Serial.print("Discovering servers.");
        break;
      case DhcpStateRequesting:
        Serial.print("Requesting lease.");
        break;
      case DhcpStateRenewing:
        Serial.print("Renewing lease.");
        break;
      case DhcpStateLeased: {
        Serial.println("Obtained lease!");

        // added:
        ipAcquired = true;
        
        // Since we're here, it means that we now have a DHCP lease, so we
        // print out some information.
        //mac_ard ip_ard gateway_ard subnet_ard ip_dns_srv ip_dhcp_srv
        //byte* ipAddr = EthernetDHCP.ipAddress(); // was const
        memcpy(&ip_ard, EthernetDHCP.ipAddress(), 4);
        //byte* gatewayAddr = EthernetDHCP.gatewayIpAddress();
        memcpy(&gateway_ard, EthernetDHCP.gatewayIpAddress(), 4);
        //byte* dnsAddr = EthernetDHCP.dnsIpAddress();
        memcpy(&ip_dns_srv, EthernetDHCP.dnsIpAddress(), 4);

        /*
        Serial.print("My IP address is ");
        Serial.println(ip_to_str(ipAddr));

        Serial.print("Gateway IP address is ");
        Serial.println(ip_to_str(gatewayAddr));

        Serial.print("DNS IP address is ");
        Serial.println(ip_to_str(dnsAddr));
        */
        
        
        Serial.println();
        
        break;
      }
    }
  } else if (state != DhcpStateLeased && millis() - prevTime > 300) {
     prevTime = millis();
     Serial.print('.'); 
  }

  prevState = state;

}
#endif //DHCP_GK



// ifconfig - print out address info, lol :) .. (//jt-WebClientWithDHCP)
void ifconfig()
{
  byte buffer[6];
  
  //Dhcp.getMacAddress(buffer);
  Serial.print("mac address: ");
  printArray(&Serial, ":", mac_ard, 6, 16); //was buffer
    
  //Dhcp.getLocalIp(buffer);
  Serial.print("ip address: ");
  printArray(&Serial, ".", ip_ard, 4, 10); //was buffer
  
  //Dhcp.getSubnetMask(buffer);
  Serial.print("subnet mask: ");
  printArray(&Serial, ".", subnet_ard, 4, 10); //was buffer
  
  //Dhcp.getGatewayIp(buffer);
  Serial.print("gateway ip: ");
  printArray(&Serial, ".", gateway_ard, 4, 10); //was buffer
  
  //Dhcp.getDhcpServerIp(buffer);
  Serial.print("dhcp server ip: ");
  printArray(&Serial, ".", ip_dhcp_srv, 4, 10); //was buffer
  
  //Dhcp.getDnsServerIp(buffer);
  Serial.print("dns server ip: ");
  printArray(&Serial, ".", ip_dns_srv, 4, 10); //was buffer
  
  Serial.println();
}

//jt-WebClientWithDHCP
void printArray(Print *output, char* delimeter, byte* data, int len, int base)
{
  char buf[10] = {0, 0, 0, 0, 0, 0, 0, 0, 0, 0};

  for(int i = 0; i < len; i++)
  {
    if(i != 0)
      output->print(delimeter);

    output->print(itoa(data[i], buf, base));
  }

  output->println();
}

//jt-WebClientWithDHCP
void spinForever()
{
  for(;;)
      ;
}
