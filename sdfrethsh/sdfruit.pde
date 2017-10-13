/*
 *  sdfruit.pde
 *  Shell-like environment for Arduino,
 *  that can be simulated in emulino.
 *  Based on minifruit (Fruit One) by Halid Ziya Yerebakan.
 *
 *  The code reports its results through serial
 *
 *  sdfruit.pde
 *  ------------
 *  Latest update: May 07 2010
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

// from minifruit shell
#define READ 1
#define WRITE 2
#define OUT 3
#define IN 4
#define DELAY 5
#define PULSE 6
#define EXIT 7


void setup()
{
  Serial.begin(115200); // initialize the serial port
}

void loop()
{
  if (shellstate == 3) {
    printPrompt();
    shellstate = 0;
  }
  //Serial.println();
  checkForInData();
  //Serial.println();
  processInData();
  //Serial.println(state);
  timestep++;
  delay(20);
}



void printPrompt()
{
  Serial.print("sdfruitsh # ");
}


void checkForInData()
{
  while(Serial.available()) // does not block if no data available
  {
    rch = Serial.read();
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
      Serial.println();
      shellstate = 3;
      linept = 0;
      return;
    }

    if (rch == ECHR){
      // switch echo mode and reset
      Serial.println();
      Serial.print("Echo: ");
      if (echomode == 0) {
        echomode = 1;
        Serial.println("ON");
      } else {
        echomode = 0;
        Serial.println("off");
      }
      shellstate = 3;
      linept = 0;
      return;
    }

    if (echomode == 1) Serial.print(rch);

    if (shellstate == 0) {
      shellstate = 1;
      //Serial.println();
      //Serial.println("checkForInData ");
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
    if (echomode == 1) Serial.println(); //add newline for echo mode
    linept--; //ignore last EOL
    line[linept] = 0; // and shorten string
    Serial.print("(");
    Serial.print(linept);
    Serial.print(")> ");
    Serial.println(line); // here we print EOL, though

    // parse'n'execute command
    execCommand();

    // add empty line
    Serial.println();

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

       Serial.print("Pin ");
       Serial.print(param1);
       Serial.print(": ");
       Serial.println(digitalRead(param1));
       break;

   case WRITE  :
     param1 = line[6] - '0'; // Digital value
     param2 = line[8] - '0'; // Line number
       if (line[9]>='0' && line[9]<='9')
         param2=10*param2+line[9]-'0';
       digitalWrite(param2,param1);
       Serial.print("Writen to Pin ");
       Serial.print(param2);
       Serial.print(": ");
       Serial.println(param1);

     break;

    case OUT:
         param1 = line[7] - '0';
         if (line[8]>='0' && line[8]<='9')
         param1=10*param1+line[8]-'0';
         pinMode(param1, OUTPUT);
         Serial.print("Output Pin ");
         Serial.println(param1);
    break;

    case IN:
         param1 = line[6] - '0';
         if (line[7]>='0' && line[7]<='9')
         param1=10*param1+line[7]-'0';
         pinMode(param1, OUTPUT);
         Serial.print("Input Pin ");
         Serial.print(param1);
         break;
     case DELAY:
         param1 = line[6] - '0'; // Digital value
         param2 = line[8] - '0';
         param3 = line[10] - '0'; // Line number
         if (line[11]>='0' && line[11]<='9')
         param3=10*param3+line[11]-'0';
         Serial.print("Active pin ");
         Serial.print(param3);
         Serial.print(" by ");
         Serial.print(param1);
         Serial.print(" seconds value:");
         Serial.println(param2);
         digitalWrite(param3,param2);
         delay(1000*param1);
         digitalWrite(param3,!param2); // Not of parameter
     break;
     case PULSE:
         param1 = line[6] - '0'; // Voltage Level
         param2 = line[8] - '0'; // Line Number
         if (line[11]>='0' && line[11]<='9')
         param2=10*param2+line[11]-'0';

         Serial.print("Wave to pin ");
         Serial.print(param2);
         Serial.print(" by ");
         Serial.print(param1);
         Serial.println(" V");
         analogWrite(param2,param1*50);

       break;
     case EXIT: if (echomode == 0) exit(0); break; // only useful for sim!!
     default: Serial.println("Unknown command"); break;
   }

}


void printUsage()
{

Serial.println("Console Usage:");
Serial.print("        ");
Serial.print(ECHR);
Serial.println("                   : Switch echo mode ");
Serial.println("        read <pin>          : Read target pin ");
Serial.println("	write <value> <pin> : Write value to desired pin ");
Serial.println("	output <pin> 	    : Configure pin as output ");
Serial.println("	input  <pin>		: Configure pin as input ");
Serial.println("	delay <second> <value> <pin> : Writes value to pin for given delay ");
Serial.println("	pulse <value> <pin>	: Arrages voltage value to given pin by PWM ");
Serial.println("        exit				: Exit");
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
}


