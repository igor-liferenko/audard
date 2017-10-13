/*
 *  ArduinoWaker.pde
 *  Shell-like environment for Arduino,
 *  with wake-on-lan facility.
 *  Based on sdfrethsh (http://www.arduino.cc/playground/Main/Sdfrethsh)
 *
 *
 *  For sim, build in serial mode, and:
 *  stty -icanon 115200 ; ./emulino /path/to/sdfruiteth.cpp.hex
 *  in order to get sim of tab, del and echo keypresses
 *
 *  ArduinoWaker.pde
 *  ------------
 *  Latest update: May 16 2010
 *  ------------
 *  Copyleft: use as you like
 *  sd [] imi.aau.dk
 *
 * Note: ping the device before you telnet to it, so the
 * Ethernet chip can wake up.
 *
 * Also, once in shell, do at least wip, wmac, wport once,
 * before executing wolex (to make sure packet gets sent,
 * it can be missed sometimes; repetitions should work though)
 *
 * an RC delayed reset may be necesarry for
 * Duemilanove + Ethernet Shield (W5100) , in order to guarantee
 * shield will be inited at power up
 */


// Commands

byte shellstate = 3; //start from show prompt state
/*
state = 0 : prompt has been shown, no in data yet
state = 1 : first incoming character came in,  data still incoming
state = 2 : EOL has been reach, incoming data completed
state = 3 : data has been processed, ready to show prompt.
*/
int timestep=0;
#define MAXCHARS 100
char line[MAXCHARS];
int linept=0;
char rch;
#define LF 10 //LineFeed
#define CR 13 //CarrRet
#define TAB 9
#define DEL 127
#define ECHR '^' //echo char
byte echomode=0;

// from minifruit shell - commands
#define READ 1
#define WRITE 2
#define OUT 3
#define IN 4
#define DELAY 5
#define PULSE 6
#define EXIT 7
#define VERSION 8
#define IFCFG 9
#define WMAC 10
#define WIP 11
#define WPORT 12
#define WOLEX 13

#define _MYNAME "Arduino"
#define _PROMPT "ardwakesh"
#define _HOSTNAME ""_MYNAME"-"_PROMPT //concatenate via defines..
static const char* PROMPT=&_PROMPT[0];
static const char* HOSTNAME=&_HOSTNAME[0];

static const char* CHGOK="change OK";

/*
* COMM FUNCTIONS  ****************************************************************
*/

// keep ETHERNET commented (undefined) for USB/serial mode build
#define ETHERNET

/*
* in ETHERNET case, the shell should be
* Server class - listening for
* incoming connections
*/

/*
* Note for ethernet:
* calling as:
*
*   stty -icanon ; telnet 192.168.1.77 23
*
* once connected, escape the telnet with ^] (Ctrl+]) and to into character mode:
*
*   ^]
*   telnet> mode character
*
* press enter - no message will be printed, but one is now in character mode.
* Then press Tab to show the help screen of the shell.
* No characters will be echoed, so you may want activate echo mode;
*   unfortunately '^' may get garbled by telnet, but you can copypaste it from
*   gnome-terminal from the help text shown on tab...
*
*/


// network configuration.  gateway and subnet are optional.
// Ethernet shield should be pingable at the address specified below,
//   its leds should blink at ping too
// start setting to static IP's - will be overwritten by DHCP
// these are settings related to "this" Arduino:
byte mac_ard[] = { 0xDE, 0xAD, 0xBE, 0xEF, 0xFE, 0xED };
byte ip_ard[] = { 192, 168, 1, 123 };
byte gateway_ard[] = { 192, 168, 1, 1 };
byte subnet_ard[] = { 255, 255, 255, 0 };
byte ip_dhcp_srv[] = { 0, 0, 0, 0 };
byte ip_dns_srv[] = { 0, 0, 0, 0 };

// these are settings related to the target PC to be woken up:
byte mac_wol[] = { 0x00, 0x01, 0x02, 0x03, 0x04, 0x05 };
byte ip_wol[] = { 255, 255, 255, 255 };
int port_wol = 7;
//local port to "listen" on - to initialize udp, else we dont use it
// shows as udp src port in wireshark
int port_udploc_wol = 8888;

byte wol_magic_packet[102] = { 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF };

boolean ipAcquired = false;

// cannot just include these - must be extern
extern "C" {
   #include "../Ethernet/utility/types.h" //uint8...
   #include "../Ethernet/utility/socket.h" //socket
   #include "../Ethernet/utility/w5100.h" //Sn_MR_UDP
}

// powerpins - those digital outs designated to
// be connected to a power rail.
// we must ensure powerpins will be high voltage at boot!
// "Arduino uses digital pins 10, 11, 12, and 13 (SPI)
// to communicate with the W5100 on the ethernet shield.
// These pins cannot be used for general i/o. "
// we better leave 1 and 2 as well, since those could
// be used for usb serial.
byte powerpins[] = { 3 };
byte powerpinssize = sizeof(powerpins) / sizeof(byte);
// LED connected to digital pin 13 on Duemilanove
int ledPin = 13;


#ifdef ETHERNET
  static byte commmode = 1; // ethernet
  /*
  choice of dhcp library - for more info on install etc, see:
  http://sdaaubckp.svn.sourceforge.net/viewvc/sdaaubckp/sdfrethsh/ardtestdhcp.pde
  choose only one define - comment the rest :)
  if none are chosen, we should revert to static IP setup!!
  */
  //#define DHCP_JT // jordanterrell - Arduino-DHCPv0.4
  //#define DHCP_KG // kegger - (A)Ethernet
#define DHCP_GK // gkaindl - ArduinoEthernet/EthernetDHCP
  // but also must comment the includes too -
#if defined(DHCP_JT)
  //static char* dhcplib="DHCP_JT";
  //#include <Ethernet.h> //jt-WebClientWithDHCP
  //#include <jt_Dhcp.h> //jt-WebClientWithDHCP
#elif defined(DHCP_KG) //DHCP_JT
  //static char* dhcplib="DHCP_KG";
  //#include <AEthernet.h> //kegger-WebClientWithDHCP
  //#include "Dhcp.h"  //kegger-WebClientWithDHCP - this now specifically should refer to kegger version
#elif defined(DHCP_GK) //DHCP_KG
  static char* dhcplib="DHCP_GK";
  #include <Ethernet.h> //gkeindl: PollingDHCP.pde
  #include <EthernetDHCP.h> //gkeindl: PollingDHCP.pde
#elif // no DHCP, so static..
  static char* dhcplib="NO DHCP";
  ipAcquired = true;
#endif //DHCP_...JT
#else // #if(n)def ETHERNET
  #include <Ethernet.h> // including it here, so it don't crash on 'Server server'
  static char* dhcplib="NO ETH";
  static byte commmode = 0; // serial
#endif // ETHERNET


// telnet defaults to port 23
Server server = Server(23);


void commBegin()
{
#ifdef ETHERNET
  delay(1000); //does it help? .. yes, for registering first DHCP request
  setupDHCP(); // init of Ethernet and DHCP
  // start listening for clients
  server.begin();
#else
  Serial.begin(115200);
#endif
}


int commAvailable()
{
#ifdef ETHERNET
  return server.available();
#else
  return Serial.available();
#endif
}



byte commRead()
{
#ifdef ETHERNET
  //the client read seems to block until enter is received
  // use telnet's character mode to get char by char response
  Client tclient = server.available();
  return tclient.read();
#else
  // serial will block in emulation until enter is received, unless
  // stty -icanon is ran before emulating..
  return Serial.read();
#endif
}

// Variadic macros are C99-only
#ifdef ETHERNET
#define commPrint(...)  do { server.print(__VA_ARGS__); } while (0)
#define commPrintln(...)  do { server.println(__VA_ARGS__); } while (0)
#else
#define commPrint(...)  do { Serial.print(__VA_ARGS__); } while (0)
#define commPrintln(...)  do { Serial.println(__VA_ARGS__); } while (0)
#endif


/*
* COM FUNCTIONS - DHCP  **********************************************************
*/

#ifdef ETHERNET
void setupDHCP()
{
#if defined(DHCP_JT)
  jt_dhcp_setup();
#elif defined(DHCP_KG)
  kg_dhcp_setup();
#elif defined(DHCP_GK)
  gk_dhcp_setup();
#elif // no DHCP defines - so, static IP setup:
  Ethernet.begin(mac_ard, ip_ard, gateway_ard, subnet_ard);
#endif
}

#ifdef DHCP_JT
// from jt-Arduino-DHCPv0.4/examples/WebClientWithDHCP/WebClientWithDHCP.pde
void jt_dhcp_setup()
{

  commPrintln("getting ip...");
  //int result = Dhcp.beginWithDHCP(mac_ard);
  // 10 s wait time for DHCP offer - else it don't work for me
  int result = Dhcp.beginWithDHCP(mac_ard, 60000, 10000);

  if(result == 1)
  {
    ipAcquired = true;

    commPrintln("ip acquired...");

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
    commPrintln("unable to acquire ip address...");
}
#endif //DHCP_JT

#ifdef DHCP_KG
// from kegger_Ethernet/examples/WebClientWithDHCP/WebClientWithDHCP.pde
void kg_dhcp_setup()
{
  commPrintln("getting ip...");
  int result = Dhcp.beginWithDHCP(mac_ard);

  if(result == 1)
  {
    ipAcquired = true;

    commPrintln("ip acquired...");

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
    commPrintln("unable to acquire ip address...");
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
  EthernetDHCP.setHostName(_HOSTNAME);
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
    commPrintln();

    switch (state) {
      case DhcpStateDiscovering:
        commPrint("Discovering servers.");
        break;
      case DhcpStateRequesting:
        commPrint("Requesting lease.");
        break;
      case DhcpStateRenewing:
        commPrint("Renewing lease.");
        break;
      case DhcpStateLeased: {
        commPrintln("Obtained lease!");

        // added:
        ipAcquired = true;

        // Since we're here, it means that we now have a DHCP lease, so we
        // save some information.
        memcpy(&ip_ard, EthernetDHCP.ipAddress(), 4);
        memcpy(&gateway_ard, EthernetDHCP.gatewayIpAddress(), 4);
        memcpy(&ip_dns_srv, EthernetDHCP.dnsIpAddress(), 4);

        commPrintln();

        break;
      }
    }
  } else if (state != DhcpStateLeased && millis() - prevTime > 300) {
     prevTime = millis();
     commPrint('.');
  }

  prevState = state;

}
#endif //DHCP_GK
#endif //ETHERNET


/*
* MAIN FUNCTIONS  ****************************************************************
*/

void setup()
{
  // initialize powerpins to high voltage level immediately!
  for (int ix=0; ix<powerpinssize; ix++)
  {
    pinMode(powerpins[ix], OUTPUT);
    digitalWrite(powerpins[ix], HIGH);
  }

  commBegin(); // initialize the communication
  // the below call causes total freeze in setup!
  //socket(UDPSOCK,Sn_MR_UDP,port_udploc_wol,0);
}

void loop()
{
#ifdef ETHERNET
if (!ipAcquired) { // ok for static, should be true..
#if defined(DHCP_GK) //cannot call setupDHCP for poll, so:
     gk_poll_loop_dhcp();
#else //not DHCP_GK
    setupDHCP();
#endif //DHCP_GK
  } // end if
#endif //ETHERNET
  if (shellstate == 3) {
    printPrompt();
    shellstate = 0;
  }
  checkForInData();
  processInData();
  //commPrintln(shellstate);
  timestep++;
#ifdef DHCP_GK
  // this called maybe each cca 20s?
  if (timestep%100 == 0) EthernetDHCP.maintain(); //poll is called only during setup!;
#endif
  delay(20);
}






/*
* SHELL FUNCTIONS  ****************************************************************
*/

void printPrompt()
{
  commPrint(PROMPT);
  commPrint(" # ");
}

void printPowerpins()
{
  commPrint("Powerpins: ");
  for (int ix=0; ix<powerpinssize; ix++)
  {
    commPrint("[");
    commPrint(powerpins[ix], DEC);
    commPrint("]= ");
    commPrint(digitalRead(powerpins[ix]), DEC);
    commPrint("; ");
  }
}

void checkForInData()
{
  while(commAvailable()) // does not block if no data available
  {
    rch = commRead();
    line[linept] = rch;
    linept++;

    if (rch == TAB){
      // usage and reset - for tab
      printUsage();
      shellstate = 3;
      linept = 0;
      return;
    }

    if (rch == DEL){
      // immediate reset - for delete
      commPrintln();
      shellstate = 3;
      linept = 0;
      return;
    }

    if (rch == ECHR){
      // switch echo mode and reset
      commPrintln();
      commPrint("Echo: ");
      if (echomode == 0) {
        echomode = 1;
        commPrintln("ON");
      } else {
        echomode = 0;
        commPrintln("off");
      }
      shellstate = 3;
      linept = 0;
      return;
    }

    if (echomode == 1) commPrint(rch);

    if (shellstate == 0) {
      shellstate = 1;
      //commPrintln();
      //commPrintln("checkForInData ");
    }

    line[linept] = 0;
    if ((rch == CR) || (rch == LF))
    {
      shellstate = 2;
    }
  }
}


void processInData()
{
  if (shellstate == 2)
  {
    if (echomode == 1) commPrintln(); //add newline for echo mode
    linept--; //ignore last EOL
    line[linept] = 0; // and shorten string
    // printout command
    commPrint("> ");
    commPrint(line);


    // parse'n'execute command
    execCommand();

    // add empty line
    commPrintln();

    // printout state of powerpins
    commPrint("\t\t");
    printPowerpins();
    commPrintln();

    shellstate = 3;
    linept = 0;
  }
}




// orig: showConsole() in minifruit shell
void execCommand()
{
   //Do command
   int command=parseLine(line);
   int param1,param2,param3;
   int ret;

   switch(command)
   {
   case READ :
       // Parse param as pin number
       param1 = line[5] - '0';
       if (line[6]>='0' && line[6]<='9')
         param1=10*param1+line[6]-'0';

       commPrint("Pin ");
       commPrint(param1);
       commPrint(": ");
       commPrintln(digitalRead(param1));
       break;

   case WRITE  :
     param1 = line[6] - '0'; // Digital value
     param2 = line[8] - '0'; // Line number
       if (line[9]>='0' && line[9]<='9')
         param2=10*param2+line[9]-'0';
       digitalWrite(param2,param1);
       commPrint("Writen to Pin ");
       commPrint(param2);
       commPrint(": ");
       commPrintln(param1);

     break;

    case OUT:
         param1 = line[7] - '0';
         if (line[8]>='0' && line[8]<='9')
         param1=10*param1+line[8]-'0';
         pinMode(param1, OUTPUT);
         commPrint("Output Pin ");
         commPrintln(param1);
    break;

    case IN:
         param1 = line[6] - '0';
         if (line[7]>='0' && line[7]<='9')
         param1=10*param1+line[7]-'0';
         pinMode(param1, OUTPUT);
         commPrint("Input Pin ");
         commPrint(param1);
         break;
     case DELAY:
         param1 = line[6] - '0'; // Digital value
         param2 = line[8] - '0';
         param3 = line[10] - '0'; // Line number
         if (line[11]>='0' && line[11]<='9')
         param3=10*param3+line[11]-'0';
         commPrint("Active pin ");
         commPrint(param3);
         commPrint(" by ");
         commPrint(param1);
         commPrint(" seconds value:");
         commPrintln(param2);
         digitalWrite(param3,param2);
         delay(1000*param1);
         digitalWrite(param3,!param2); // Not of parameter
     break;
     case PULSE:
         param1 = line[6] - '0'; // Voltage Level
         param2 = line[8] - '0'; // Line Number
         if (line[11]>='0' && line[11]<='9')
         param2=10*param2+line[11]-'0';

         commPrint("Wave to pin ");
         commPrint(param2);
         commPrint(" by ");
         commPrint(param1);
         commPrintln(" V");
         analogWrite(param2,param1*50);

       break;
     case VERSION: commPrintln("Version 1.0.0"); break;
     case IFCFG: ifconfig(); break;
     case WMAC:
         commPrint(" mac_wol/");
         // %hhx - read and store hex as byte!
         // else corruption of next variable (ip_wol)!
         ret = sscanf (&line[5], "%hhx:%hhx:%hhx:%hhx:%hhx:%hhx",
           &mac_wol[0], &mac_wol[1], &mac_wol[2],
           &mac_wol[3], &mac_wol[4], &mac_wol[5] );
         commPrint(ret, DEC); commPrint(": ");
         if (ret>0) commPrintln(CHGOK);
         printArrayln(":", mac_wol, 6, 16);
         break;
     case WIP:
         commPrint(" ip_wol/");
         // %hhd - read and store decimal as byte!
         // else corruption of next variable (port_wol)!
         ret = sscanf (&line[4], "%hhd.%hhd.%hhd.%hhd",
           &ip_wol[0], &ip_wol[1], &ip_wol[2],
           &ip_wol[3] );
         commPrint(ret, DEC); commPrint(": ");
         if (ret>0) commPrintln(CHGOK);
         printArrayln(".", ip_wol, 4, 10);
         break;
     case WPORT: commPrint(" port_wol/");
         ret = sscanf (&line[6], "%d",
           &port_wol);
         commPrint(ret, DEC); commPrint(": ");
         if (ret>0) commPrintln(CHGOK);
         commPrintln(port_wol);
         break;
     case WOLEX:
         wakeonlan();
         break;
     case EXIT: if ((echomode == 0) && (commmode ==0)) exit(0); break; // only useful for sim!!
     default: commPrintln("Unknown command"); break;
   }

}

void wakeonlan()
{
  int ret;
  //sprintf(cmd, "wakeonlan -i %d.%d.%d.%d -p %d %0x:%0x:%0x:%0x:%0x:%0x");
  commPrint("wakeonlan -i ");
  printArray(".", ip_wol, 4, 10);
  commPrint(" -p ");
  commPrint(port_wol);
  commPrint(" ");
  printArrayln(":", mac_wol, 6, 16);

  // compose packet wol_magic_packet
  for (int ix=6; ix<102; ix++)
  {
    wol_magic_packet[ix]=mac_wol[ix%6];
  }

  commPrintln();


#ifdef ETHERNET
  commPrintln("Execute wakeonlan: ");
  ret = UDP_RawSendto(wol_magic_packet, 102, ip_wol, port_wol);

  commPrint("written: ");
  commPrint(ret, DEC);
  commPrint(" ; ");
  if (ret == 102) commPrint(" all sent. ");
  commPrintln();

#else // if(n)def ETHERNET
  printArrayln(":", wol_magic_packet, 102, 16);
  commPrintln(dhcplib);
#endif
}


int UDP_RawSendto(byte* in_packet, int in_len, byte* in_ip, int in_port)
{
  int ret;
  int _socket;

  // we must obtain a free socket (one not taken by the server,
  //  which should be socket 0)
  // and then we must close it at end!

  for (int i = 3; i>=0; i--) {
  //commPrintln(i, DEC);
  if (SOCK_CLOSED == IINCHIP_READ(Sn_SR(i))) {
     //commPrintln("sock_closed");
     if (socket(i, Sn_MR_UDP, port_udploc_wol, 0) > 0) {
        commPrint("got socket ");
        commPrintln(i, DEC);
        _socket = i; //this->_socket = i;
        break;
     }
  }
  }

  ret = sendto(_socket,(uint8*)in_packet,in_len,(uint8*)in_ip,in_port);

  close(_socket);

  return ret;
}


void printUsage()
{

commPrintln("Console Usage:");
commPrint("        ");
commPrint(ECHR);
commPrintln("                   : Switch echo mode ");
commPrintln("        read <pin>          : Read target pin ");
commPrintln("	write <value> <pin> : Write value to desired pin ");
commPrintln("	output <pin> 	    : Configure pin as output ");
commPrintln("	input  <pin>		: Configure pin as input ");
commPrintln("	delay <second> <value> <pin> : Writes value to pin for given delay ");
commPrintln("	pulse <value> <pin>	: Arrages voltage value to given pin by PWM ");
commPrintln("        exit				: Exit");
commPrintln("        hello				: Version");
commPrintln("        ifconfig				: show IP setup ");
commPrintln("        wmac			: show/edit WOL MAC addr ");
commPrintln("        wip			: show/edit WOL IP addr ");
commPrintln("        wport			: show/edit WOL port ");
commPrintln("        wolex			: execute WOL ");
}


int stringCompare(char* line1,char* line2,int length)
/*Returns 1 when they are equal*/
{
  int i=0;
  int result=1;
  for(i=0;i<length;i++)
     result = result && (line1[i]==line2[i]);
  return result;
}

int stringLength(char* line)
{
  int i;
  for(i=0;line[i]!=0;i++);
  return i;
}


int parseLine(char* line)
{
  //if (stringCompare(line,"exit",4) || (stringLength(line) < 4 )) return EXIT;
  if (stringCompare(line,"exit",4)) return EXIT;
  if (stringCompare(line,"read",4)) return READ;
  if (stringCompare(line,"write",5)) return WRITE;
  if (stringCompare(line,"output",5)) return OUT;
  if (stringCompare(line,"input",5)) return IN;
  if (stringCompare(line,"delay",5)) return DELAY;
  if (stringCompare(line,"pulse",5)) return PULSE;
  if (stringCompare(line,"hello",5)) return VERSION;
  if (stringCompare(line,"ifconfig",8)) return IFCFG;
  if (stringCompare(line,"wmac",4)) return WMAC;
  if (stringCompare(line,"wip",3)) return WIP;
  if (stringCompare(line,"wport",5)) return WPORT;
  if (stringCompare(line,"wolex",3)) return WOLEX;
}


//jt-WebClientWithDHCP
//void printArray(Print *output, char* delimeter, byte* data, int len, int base)
void printArray(char* delimeter, byte* data, int len, int base)
{
  char buf[10] = {0, 0, 0, 0, 0, 0, 0, 0, 0, 0};

  for(int i = 0; i < len; i++)
  {
    if(i != 0)
      commPrint(delimeter); //output->print(delimeter);

    commPrint(itoa(data[i], buf, base)); //output->print(itoa(data[i], buf, base));
  }

}

void printArrayln(char* delimeter, byte* data, int len, int base)
{
  printArray(delimeter, data, len, base);
  commPrintln(); //output->println();
}

// ifconfig - print out address info, lol :) .. (//jt-WebClientWithDHCP)
void ifconfig()
{
  byte buffer[6];

  commPrintln(dhcplib);
  commPrintln(ipAcquired, DEC);

  commPrint("mac address: ");
  printArrayln(":", mac_ard, 6, 16);

  commPrint("ip address: ");
  printArrayln(".", ip_ard, 4, 10);

  commPrint("subnet mask: ");
  printArrayln(".", subnet_ard, 4, 10);

  commPrint("gateway ip: ");
  printArrayln(".", gateway_ard, 4, 10);

  commPrint("dhcp server ip: ");
  printArrayln(".", ip_dhcp_srv, 4, 10);

  commPrint("dns server ip: ");
  printArrayln(".", ip_dns_srv, 4, 10);

  commPrintln();
}

