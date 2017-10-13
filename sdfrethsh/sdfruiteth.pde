/*
 *  sdfruiteth.pde
 *  Shell-like environment for Arduino,
 *  that can be simulated in emulino.
 *  Based on minifruit (Fruit One) by Halid Ziya Yerebakan.
 *  This one should be working with Ethernet.
 *
 *  The code reports its results through serial or ethernet
 *
 *  For sim, build in serial mode, and:
 *  stty -icanon 115200 ; ./emulino /path/to/sdfruiteth.cpp.hex
 *  in order to get sim of tab, del and echo keypresses
 *
 *  sdfruiteth.pde
 *  ------------
 *  Latest update: May 15 2010
 *  ------------
 *  Copyleft: use as you like
 *  sd [] imi.aau.dk
 *
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

#define _MYNAME "Arduino"
#define _PROMPT "sdfrethsh"
#define _HOSTNAME ""_MYNAME"-"_PROMPT //concatenate via defines..
static const char* PROMPT=&_PROMPT[0];
static const char* HOSTNAME=&_HOSTNAME[0];

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

boolean ipAcquired = false;

// commmode
#ifdef ETHERNET
  static byte commmode = 1; // ethernet
  // choice of dhcp library - for more info on install etc, see: 
  //  http://sdaaubckp.svn.sourceforge.net/viewvc/sdaaubckp/sdfrethsh/ardtestdhcp.pde
  // choose only one define - comment the rest :) 
  // if none are chosen, we should revert to static IP setup!!
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
  // initialize the ethernet device
  //Ethernet.begin(mac, ip, gateway, subnet); // in setupDHCP now..
  delay(1000); //does it help? .. yes, for registering first DHCP request
  setupDHCP();  
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
        // print out some information.
        //mac_ard ip_ard gateway_ard subnet_ard ip_dns_srv ip_dhcp_srv
        //byte* ipAddr = EthernetDHCP.ipAddress(); // was const
        memcpy(&ip_ard, EthernetDHCP.ipAddress(), 4);
        //byte* gatewayAddr = EthernetDHCP.gatewayIpAddress();
        memcpy(&gateway_ard, EthernetDHCP.gatewayIpAddress(), 4);
        //byte* dnsAddr = EthernetDHCP.dnsIpAddress();
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
  commBegin(); // initialize the communication
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
  // this called maybe each 2s? 
  if (timestep%10 == 0) EthernetDHCP.maintain(); //poll is called only during setup!; 
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
    // printout command, timestep and number of chars in command
    commPrint("> ");
    commPrint(line); 
    commPrint("\t\t/");
    commPrint(timestep);
    commPrint("\t ("); 
    commPrint(linept);
    commPrintln(")");     

    // parse'n'execute command
    execCommand();

    // add empty line
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
     case VERSION: commPrintln("Version 1.1.0"); break;
     case IFCFG: ifconfig(); break;
     case EXIT: if ((echomode == 0) && (commmode ==0)) exit(0); break; // only useful for sim!!
     default: commPrintln("Unknown command"); break;
   }

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

  commPrintln(); //output->println();
}

// ifconfig - print out address info, lol :) .. (//jt-WebClientWithDHCP)
void ifconfig()
{
  byte buffer[6];
  
  commPrintln(dhcplib);
  
  //Dhcp.getMacAddress(buffer);
  commPrint("mac address: ");
  //printArray(&Serial, ":", mac_ard, 6, 16); //was buffer
  printArray(":", mac_ard, 6, 16);
    
  //Dhcp.getLocalIp(buffer);
  commPrint("ip address: ");
  printArray(".", ip_ard, 4, 10); //was buffer
  
  //Dhcp.getSubnetMask(buffer);
  commPrint("subnet mask: ");
  printArray(".", subnet_ard, 4, 10); //was buffer
  
  //Dhcp.getGatewayIp(buffer);
  commPrint("gateway ip: ");
  printArray(".", gateway_ard, 4, 10); //was buffer
  
  //Dhcp.getDhcpServerIp(buffer);
  commPrint("dhcp server ip: ");
  printArray(".", ip_dhcp_srv, 4, 10); //was buffer
  
  //Dhcp.getDnsServerIp(buffer);
  commPrint("dns server ip: ");
  printArray(".", ip_dns_srv, 4, 10); //was buffer
  
  commPrintln();
}

