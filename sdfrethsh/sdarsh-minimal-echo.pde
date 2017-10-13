/*
 *  sdarsh-minimal-echo.pde
 *  Minimal shell-like environment for Arduino,
 *  that can be simulated in emulino.
 *  It simply echoes newline terminated input.
 *
 *  The code reports its results through serial
 *
 *  sdarsh-minimal-echo.pde
 *  ------------
 *  Latest update: May 07 2010
 *  ------------
 *  Copyleft: use as you like
 *  sd [] imi.aau.dk
 *
 */


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
#define LF 10 //LF
#define CR 13 //CR

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
  Serial.print("sdarsh # ");
}


void checkForInData()
{
  while(Serial.available()) // does not block if no data available
  {
    if (shellstate == 0) {
      shellstate = 1;
      //Serial.println();
      //Serial.println("checkForInData ");
    }
    rch = Serial.read();
    line[linept] = rch;
    linept++;
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
    linept--; //ignore last EOL
    line[linept] = 0; // and shorten string
    Serial.print("(");
    Serial.print(linept);
    Serial.print(")> ");
    Serial.println(line); // here we print EOL, though
    shellstate = 3;
    linept = 0;
  }
}



