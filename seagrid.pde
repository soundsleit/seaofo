//seaofo - Scott Smallwood, 2023.
//processing/java patch that creates a maze game, 
//interfaces with ChucK for sound

//this version runs in Processing / Java
//and will loops until quitting (ESC)
 
 
//OSC stuff
import oscP5.*;
import netP5.*;

OscP5 oscChucK;
NetAddress myBroadcastLocation;

//grid size (must be the same, and even)
int GridSize = 28;

int columns = GridSize;
int rows = GridSize;

//offset to determine location fullscreen mode
int cellColStart = 0;
int cellRowStart = 0;

//maximum cells
int cellMax = columns * rows;

//# of pixels per cell
int cellSize = 15;

//array for grid
int [][] myGrid;
int [][] myPath;
int [][] blockArea;

//global font
PFont f;

//all the chars
char[] cellSymbols = {
' ',
' ',
'^',
'o',
'/',
'\\',
'O',
'+',
'*',
'.',
'x',
'0',
'.',
' '};

//the chars' colors
color[] cellSymbolColors = {
#000000, 
#000000, 
#ED1C24, //>
#6DCFF6, //o
#EC008C, ///
#EC008C, //\
#3A4A9F, //O
#3A4A9F, //+
#FFF200, //*
#DBD5EA, //.
#DBD5EA, //x
#EC008C, //0
#6DCFF6, //.
#DBD5EA};

//cell colors
color[] cellColors = {
#000000,
#3A4A9F,
#7895A4, //>
#7895A4, //o
#7895A4, ///
#7895A4, //\
#7895A4, //O
#7895A4, //+
#7895A4, //*
#6DCFF6, //.
#6DCFF6, //x
#7895A4, //0
#3A4A9F, //.
#6DCFF6}; 

//start coords
int startCol = 0;
int startRow = 0;

//the current row/column
int myCol = 0;
int myRow = 0;

//gems (keep track throughout!)
int numStars = 0;

//slashes
int numSlashed = 0;

//number of move blocks and time blocks
int numBlocks = columns * 2;
int numTimerBlocks = columns * 2;
int numExtraBlocks = 0;

//how many steps on the path
int numPathSteps = 0;

//incrementor
int x = 0;
int gridIncX = 0;
int gridIncY = 0;

boolean setupComplete = false;
boolean ready = false;
boolean playing = false;
boolean gameOver = false;
boolean gameWin = false;
boolean resetReady = false;
boolean reset = false;
boolean isEnding = false;

int gameEndState = 0;

//time mover
int startTime = 0;
int gameTime = 0;
int gameDelay = 2000;
int timerInterval = 1000;
int now = 0;
int last = timerInterval;
int endNow = 0;
int endLast = timerInterval * 3;


///////////////////////////////////////


//set everything up
void setup()
{
  fullScreen();
  frameRate(30);

  //////OSC com setup
  if (!resetReady)
  {
    //osc instance
    oscChucK = new OscP5(this,12000);
    myBroadcastLocation = new NetAddress("127.0.0.1",32000);
  }

  //load game variables
  gameSetup();
  
}

void gameSetup()
{
  
  //send a ready message to chuck 
  OscMessage myOscMsg = new OscMessage("/ready");
  myOscMsg.add(1);
  oscChucK.send(myOscMsg, myBroadcastLocation);
  
   //////reset all variables (for repeating)
  
  //incrementor  
  x = 0;
  gridIncX = 0;
  gridIncY = 0;
  
  //start coords
  startCol = 0;
  startRow = 0;

  //the current row/column
  myCol = 0;
  myRow = 0;
  
  //slashes
  numSlashed = 0;
  
  //game variables
  numBlocks = columns * 2;
  numTimerBlocks = columns * 2;
  numExtraBlocks = 0;  
  gameEndState = 0;

  
  //timing
  startTime = 0;
  gameTime = 0;
  now = 0;
  endNow = 0;
  endLast = timerInterval * 5;
  
  setupComplete = false;
  ready = false;
  playing = false;
  gameOver = false;
  gameWin = false;
  reset = false;
  isEnding = false;
  
    //get start time
  startTime = millis();
  
  //blacken screen
  background(0);
  
  //adjust position based on screen size
  if (columns > rows) cellSize = displayWidth / columns;
  else if (columns <= rows) cellSize = displayHeight / rows;
  cellColStart = (displayWidth / 2) - ((columns / 2)*cellSize);
  cellRowStart = (displayHeight / 2) - ((rows / 2)*cellSize);
  
  //Font setup
  //printArray(PFont.list());
  f = createFont("Helvetica-Bold", cellSize/2);
  textFont(f);
  textAlign(CENTER, CENTER);
    
  //create the grid
  gridSetup();
  pathSetup();
  
  loop();
}

//the main program loop: draws the player, and keeps time
void draw()
{

  if (!gameOver)
  {
    //println("drawing");
    drawPlayer();
    
    if (playing) 
    { 
      timer();
    }
  }
  else 
  {
    endGame();
  }
  
  
}


//a timer - shown as dots on top and right side
void timer()
{
  now = millis();
  
  if (now % timerInterval < last) 
  {
  
    //send a pulse message
    OscMessage myOscMsg = new OscMessage("/pulse");
    myOscMsg.add(timerInterval);
    oscChucK.send(myOscMsg, myBroadcastLocation);
  
    timerStatusUpdate();
    numTimerBlocks--;
  }
  last = now % timerInterval;
  
  if (numTimerBlocks == 0)
  {
    playing = false;
    gameOver = true;
    gameEndState = 3;
    println("out of time!");
  }
}
  

//quit and reset
void endGame()
{
    
    if (!isEnding)
    {
      //send a quit message to chuck
      OscMessage myOscMsg = new OscMessage("/quitMe");
      myOscMsg.add(gameEndState);
      oscChucK.send(myOscMsg, myBroadcastLocation);
      println("blop");  
      isEnding = true;
    }
    
    endNow = millis() - now;
    
    //move time
    if (endNow < endLast) 
    {
      drawEndPanel();
    }
    else 
    {
      println("exiting");
      println(endNow);
      playing = false;
      
      //stop draw()
      noLoop();
      
      delay(2000);
      
      //reset the game
      //setup();
      gameSetup();
      //exit();
      
    }
    
}

//sets up a blank array for storing the path
void pathSetup()
{
  int[][] myNewPath = new int[999][2];
  
  for (int i=0; i<999; i++)
    for (int j=0; j<2; j++)
      myNewPath[i][j] = 0;
      
  myPath = myNewPath;
}

//generates the grid, creating an array and storing a random set of characters
void gridSetup()
{

  //generate grid that is blank
  myGrid = generateBlankGrid();
  
  //create the sea
  addSea();
    
  //add the nogo Os
  addBigOs();
    
  //add the slashes
  addSlashes();
  
  //bonus pen
  addBonusPen();
  
  //create start/stop doors
  addDoors();
  
  //draw the grid
  drawGrid();
  
  //send grid over OSC
  sendGrid();
  
  setupComplete = true;
}

void sendGrid()
{
  
  for (int i=1; i<columns-1; i++)
  for (int j=1; j<rows-1; j++)
  {
    //send a pulse message
    OscMessage myOscMsg = new OscMessage("/grid");
    myOscMsg.add(myGrid[i][j]);
    myOscMsg.add(i);
    myOscMsg.add(j);
    oscChucK.send(myOscMsg, myBroadcastLocation);
   }
   println("grid sent");
}

void drawPlayer()
{
  
  gameTime = millis();
  
  if (gameTime > startTime + gameDelay)
  {
    //fill in the currently moved square
    myGrid[myCol][myRow] = 9;
    fill(cellColors[10]);
    rect(cellColStart+cellSize*myCol, cellRowStart+cellSize*myRow, cellSize,cellSize);
    fill(cellSymbolColors[10]);
    text(cellSymbols[10], (cellColStart+cellSize*myCol)+(cellSize/2), (cellRowStart+cellSize*myRow)+(cellSize/2));
    
    ready = true;
    gameTime = 0;
  }
}

//this draws the grid based on data in the character array
void drawGrid()
{
  for (int i=0; i<columns; i++)
  for (int j=0; j<rows; j++)
  {
      fill(cellColors[myGrid[i][j]]);
      rect(cellColStart+cellSize*i, cellRowStart+cellSize*j, cellSize,cellSize);
      fill(cellSymbolColors[myGrid[i][j]]);
      text(cellSymbols[myGrid[i][j]], (cellColStart+cellSize*i)+(cellSize/2), (cellRowStart+cellSize*j)+(cellSize/2));
  }

}

void drawEndPanel()
{
  fill(cellColors[myGrid[0][0]]);
  int windowSize = cellSize * 6;
  rect((displayWidth / 2) - (windowSize/2), (displayHeight / 2) - (cellSize/2), 
    windowSize, cellSize);
  fill(255);
  if (gameEndState == 0) text("I Quit", displayWidth / 2, displayHeight / 2);
  else if (gameEndState == 1) text("I WON!", displayWidth / 2, displayHeight / 2);
  else if (gameEndState == 2) text("OUT OF BLOCKS!", displayWidth / 2, displayHeight / 2);
  else if (gameEndState == 3) text("OUT OF TIME!", displayWidth / 2, displayHeight / 2);
  else if (gameEndState == 4) text("BLOCKED!", displayWidth / 2, displayHeight / 2);
  
}

int[][] generateBlankGrid()
{
  //the grid cells
  int[][] grid = new int[columns][rows];
   
  //set all to 1
  for (int i=0; i<columns; i++)
    for (int j=0; j<rows; j++)
      grid[i][j] = 1;
  
  return grid;
}


void addDoors()
{
  int doorStart = int(random(1,columns-1));
  int doorEnd = int(random(1,columns-1));
  
  startCol = doorStart;
  myRow = rows-1;
  myCol = startCol;

   for (int i=0; i<columns;i++)
   {
     if (i==doorStart) 
     {
       //place the door
       myGrid[i][columns-1] = 2;
       
       //place os in front (to prevent trapping)
       
       myGrid[i][columns-2] = 3;
       myGrid[constrain(i-1,1,rows-2)][columns-2] = 3;
       myGrid[constrain(i+1,1,rows-2)][columns-2] = 3;
       myGrid[i][columns-3] = 3;
       myGrid[constrain(i-1,1,rows-2)][columns-3] = 3;
       myGrid[constrain(i+1,1,rows-2)][columns-3] = 3;

     }
     if (i==doorEnd) 
     {
       //place the door
       myGrid[i][0] = 2;
       
       myGrid[i][1] = 3;
       myGrid[constrain(i-1,1,rows-2)][1] = 3;
       myGrid[constrain(i+1,1,rows-2)][1] = 3;
       myGrid[i][2] = 3;
       myGrid[constrain(i-1,1,rows-2)][2] = 3;
       myGrid[constrain(i+1,1,rows-2)][2] = 3;
       
     }
   }
}


void addSea()
{

   for (int i=1; i<columns-1;i++)
   for (int j=1; j<rows-1;j++)
   {
     myGrid[i][j] = 3;
   }
}

void addSlashes()
{
    //random number of slashes, based on gridsize
    int _slashCount = int(random((rows-1)*(columns-1)/2,(rows-1)*(columns-1)))/(rows/3);
    
    for (int i=0; i<_slashCount; i++)
    {
      int _randCol = int(random(columns-2)+1);
      int _randRow = int(random(rows-2)+1);
      myGrid[_randCol][_randRow] = 4 + int(random(2));
    }
}

void addBigOs()
{
    //random number of big Os, based on gridsize
    int _slashCount = int(random((rows-1)*(columns-1)/3,(rows-1)*(columns-1)))/(rows/3);
    
    for (int i=0; i<_slashCount; i++)
    {
      int _randCol = int(random(columns-2)+1);
      int _randRow = int(random(rows-2)+1);
      myGrid[_randCol][_randRow] = 6;
    }
}

void addBonusPen()
{
  //randomize size
  int _width = int(random(3)+3);
  int _height = int(random(3)+3);

  //randomize location
  int _locCol = int(random(columns-12)+6);
  int _locRow = int(random(rows-12)+6);
  
  //horizontal walls
  for (int i=0; i<_width; i++)
  {
    myGrid[_locCol+i][_locRow] = 7;
    myGrid[_locCol+i][_locRow +_height] = 7;
  }
  //vertical walls
  for (int i=1; i<_height; i++)
  {
    myGrid[_locCol][_locRow+i] = 7;
    myGrid[_locCol+_width-1][_locRow+i] = 7;
  }
   
  //inside os
  for (int i=1; i<_width-1; i++)
  for (int j=1; j<_height; j++)
  {
    myGrid[_locCol+i][_locRow+j] = 3;
  }
    
  //choose gem location
  int _gemLocCol = int(random(1,_width-1))+_locCol;
  int _gemLocRow = int(random(1,_height-1))+ _locRow;
  myGrid[_gemLocCol][_gemLocRow] = 8;

  //choose door location
  int _side = int(random(4));
  int _door = 0;
  
  //sides
  if (_side==0)
  {
    _door = int(random(_height-2));
    myGrid[_locCol][_locRow+1+_door]=3;
  }
   if (_side==1)
  {
    _door = int(random(_height-2));
    myGrid[_locCol+_width-1][_locRow+1+_door]=3;
  }
  if (_side==2)
  {
    _door = int(random(_width-2));
    myGrid[_locCol+1+_door][_locRow]=3;
  }
  if (_side==3)
  {
    _door = int(random(_width-2));
    myGrid[_locCol+1+_door][_locRow+_height]=3;
  }  
}


//deals with all keyboard things, and thus player movement
//is operating on it's own thread
void keyPressed()
{
  if (ready && !gameOver)
  {
    //on first launch, send chuck some data
    if (!playing)
    {
      //trigger gridmusic in chuck (the character array)
      OscMessage myOscGridData = new OscMessage("/gridGo");
      myOscGridData.add(timerInterval);
      oscChucK.send(myOscGridData, myBroadcastLocation);
      
      //set play state
      playing = true;
    } 
    
    //allow movement inside the grid if there are more than 0 "blocks"
    //shown on left and bottom as dots
    //each new "o" that is consumed subtracts one block
    if (numBlocks > 0)
    {
      if (myRow >= 1 && myRow <= rows)
      
        if (key=='d' && (myGrid[myCol+1][myRow] == 3 || myGrid[myCol+1][myRow] == 9 
        || myGrid[myCol+1][myRow] == 2 || myGrid[myCol+1][myRow] == 8))
        {
          ++myCol;
          if (myGrid[myCol][myRow] == 8) numStars++;
          if (myGrid[myCol][myRow] == 3) numBlocks--;
          //myGrid[myCol][myRow] = 9;
        }
        
        else if (key=='a' && (myGrid[myCol-1][myRow] == 3 || myGrid[myCol-1][myRow] == 9 
        || myGrid[myCol-1][myRow] == 2 || myGrid[myCol-1][myRow] == 8))
        {
          --myCol;
          if (myGrid[myCol][myRow] == 8) numStars++;
          if (myGrid[myCol][myRow] == 3) numBlocks--;
          //myGrid[myCol][myRow] = 9;
      
        }
        
        else if (key=='w' && (myGrid[myCol][myRow-1] == 3 || myGrid[myCol][myRow-1] == 9 
        || myGrid[myCol][myRow-1] == 2 || myGrid[myCol][myRow-1] == 8))
        {
          --myRow;
          myRow = constrain(myRow,0,rows-1);
          if (myGrid[myCol][myRow] == 8) numStars++;
          if (myGrid[myCol][myRow] == 3) numBlocks--;
          //if (myGrid[myCol][myRow] != 2) myGrid[myCol][myRow] = 9;
        }
        
        else if (key=='s' && myRow < (rows - 1) && (myGrid[myCol][myRow+1] == 3 || myGrid[myCol][myRow+1] == 9 
        || myGrid[myCol][myRow+1] == 2 || myGrid[myCol][myRow+1] == 8))
        {
          ++myRow;
          myRow = constrain(myRow,0,rows-1);
          if (myGrid[myCol][myRow] == 8) numStars++;
          if (myGrid[myCol][myRow] == 3) numBlocks--;
          //myGrid[myCol][myRow] = 9;
      
        }
        else if (key=='e') 
        {
          println("i pressed e");
          gameOver=true;
          return;
          //endGame();
        }
      else return;
    }
    else 
    {
      playing = false;
      gameOver = true;
      gameEndState = 2;
      println("out of blocks!");
    }
    
    //check block limit
    blockStatusUpdate();
    
    //fill in the current square
    fill(cellColors[10]);
    rect(cellColStart+cellSize*myCol, cellRowStart+cellSize*myRow, cellSize,cellSize);
    fill(cellSymbolColors[10]);
    text(cellSymbols[10], (cellColStart+cellSize*myCol)+(cellSize/2), (cellRowStart+cellSize*myRow)+(cellSize/2));
    
    //send a move message to chuck for sound

    OscMessage myOscMsg = new OscMessage("/move");
    myOscMsg.add(myCol);
    myOscMsg.add(myRow);
    myOscMsg.add(myGrid[myCol][myRow]);
    oscChucK.send(myOscMsg, myBroadcastLocation);
    
    //mark path in grid with ., and add the coords to myPath
    if (myGrid[myCol][myRow] != 2) 
    {  
      myGrid[myCol][myRow] = 9;
      myPath[numPathSteps][0]=myCol;
      myPath[numPathSteps][1]=myRow;
      numPathSteps++;
    }
   
    if (numStars>0) 
    {
      println("yay!");
      starChimes();
      numStars=0;
    }
    
    if (myGrid[myCol][myRow] == 2) 
    {
      drawPlayer();
      playing = false;
      ready = false;
      gameOver = true;
      gameWin = true;
      gameEndState = 1;
      println("win");
    }
    
    //look for traps
    slashSearch();
    
    //refresh the grid
    drawGrid();
  }
}
  
void starChimes()
{
  
  //send a pulse message for sound reward
  OscMessage myOscMsg = new OscMessage("/star");
  myOscMsg.add(1);
  oscChucK.send(myOscMsg, myBroadcastLocation);
  
  //add extra blocks
  numBlocks = numBlocks + columns;
  blockStatusUpdate();
  
}
  

void timerStatusUpdate()
{
  //the top side
  if (numTimerBlocks > columns)
  {
    for (int i=0; i<columns; i++)
    {
      if (i < numTimerBlocks - columns) 
      {
        if (myGrid[columns-1-i][0] != 2) myGrid[columns-1-i][0] = 12;
      }
      else  
      { 
        if (myGrid[columns-1-i][0] != 2 && myGrid[columns-1-i][0] != 13) myGrid[columns-1-i][0] = 1;
        else  myGrid[columns-1-i][0] = 2;
      }
    }
  }
  
  if (numTimerBlocks == columns) numTimerBlocks--;
  
  //the right side
  if (numTimerBlocks + 1 > 0)
  {
    for (int i=0; i<columns; i++)
    {
      if (i < numTimerBlocks) myGrid[columns - 1][rows-1-i] = 12;
      else myGrid[columns - 1][rows-1-i] = 1;
    }
  }
  
  //refresh the grid
  drawGrid();
}



void blockStatusUpdate()
{
  //the left side
  if (numBlocks > columns)
  {
    for(int i=0; i<columns; i++)
    {
        if (i < numBlocks - columns) myGrid[0][rows-1-i] = 12;
        else myGrid[0][rows-1-i] = 1;
    }
  }
  if (numBlocks == columns) numBlocks--;
  
  //the bottom side
  if (numBlocks + 1 > 0)
  {
    for(int i=0; i<columns; i++)
    {
      if (i < numBlocks) 
      {
        if (myGrid[columns-1-i][rows-1] != 9) myGrid[columns-1-i][rows-1] = 12;
      }
      else 
      {
        if (myGrid[columns-1-i][rows-1] != 9 && myGrid[columns-1-i][rows-1] != 13) myGrid[columns-1-i][rows-1] = 1;
        else myGrid[columns-1-i][rows-1] = 13;
      }
    }
  }
  
  //refresh the grid
  drawGrid();
}

//trap scan and set
void slashSearch()
{
  //change to which character set
  int newChar = 11;
  boolean slashBlocked = false;
  
  if (myRow > 0 && myRow < rows-1)
  {
    if (myGrid[myCol-1][myRow-1] == 5) 
    { 
      myGrid[constrain(myCol-1,1,rows-2)][constrain(myRow-1,1,rows-2)] = newChar;
      myGrid[constrain(myCol,1,rows-2)][constrain(myRow-1,1,rows-2)] = newChar;
      myGrid[constrain(myCol+1,1,rows-2)][constrain(myRow-1,1,rows-2)] = newChar;
      myGrid[constrain(myCol-1,1,rows-2)][constrain(myRow,1,rows-2)] = newChar;
      myGrid[constrain(myCol-1,1,rows-2)][constrain(myRow+1,1,rows-2)] = newChar;
      slashBlocked = true;
      
    }
    if (myGrid[myCol+1][myRow+1] == 5) 
    { 
      myGrid[constrain(myCol+1,1,rows-2)][constrain(myRow+1,1,rows-2)] = newChar;
      myGrid[constrain(myCol+1,1,rows-2)][constrain(myRow,1,rows-2)] = newChar;
      myGrid[constrain(myCol+1,1,rows-2)][constrain(myRow-1,1,rows-2)] = newChar;
      myGrid[constrain(myCol,1,rows-2)][constrain(myRow+1,1,rows-2)] = newChar;
      myGrid[constrain(myCol-1,1,rows-2)][constrain(myRow+1,1,rows-2)] = newChar;
      slashBlocked = true;
    }
    if (myGrid[myCol+1][myRow-1] == 4) 
    { 
      myGrid[constrain(myCol+1,1,rows-2)][constrain(myRow-1,1,rows-2)] = newChar;
      myGrid[constrain(myCol+1,1,rows-2)][constrain(myRow,1,rows-2)] = newChar;
      myGrid[constrain(myCol+1,1,rows-2)][constrain(myRow+1,1,rows-2)] = newChar;
      myGrid[constrain(myCol,1,rows-2)][constrain(myRow-1,1,rows-2)] = newChar;
      myGrid[constrain(myCol-1,1,rows-2)][constrain(myRow-1,1,rows-2)] = newChar;
      slashBlocked = true;
    }
    if (myGrid[myCol-1][myRow+1] == 4) 
    { 
      myGrid[constrain(myCol-1,1,rows-2)][constrain(myRow+1,1,rows-2)] = newChar;
      myGrid[constrain(myCol-1,1,rows-2)][constrain(myRow,1,rows-2)] = newChar;
      myGrid[constrain(myCol-1,1,rows-2)][constrain(myRow-1,1,rows-2)] = newChar;
      myGrid[constrain(myCol,1,rows-2)][constrain(myRow+1,1,rows-2)] = newChar;
      myGrid[constrain(myCol+1,1,rows-2)][constrain(myRow+1,1,rows-2)] = newChar;
      slashBlocked = true;
    }
  }
      
  if (slashBlocked)
  {
    //send a pulse message
    OscMessage myOscMsg = new OscMessage("/slashed");
    myOscMsg.add(1);
    oscChucK.send(myOscMsg, myBroadcastLocation);
    
    //check to see if player is trapped
    //slashTrapCheck();
    
    //increase the count of slashes thus far
    numSlashed++;
    
    slashBlocked = false;
  }
  
  //if (recheckThresh > 0) slashTrapCheck();
  
  //check to see if player is trapped
  if (myCol > 0 && myCol < columns-1 && myRow > 0 && myRow < rows-1) slashTrapCheck();
  
}


void slashTrapCheck()
{
  
  int whichCell = 0;
  boolean blocked = true;
  
  blockArea = new int[999][999];
  
  blockArea[whichCell][0] = myCol;
  blockArea[whichCell][1] = myRow;
  
  whichCell++;
  
  for (int i=0; i<whichCell; i++)
  {
    
    if (myGrid [blockArea[i][0]] [blockArea[i][1]+1] == 3)
    {
      blocked = false;
      break;
    }
    else if (myGrid [blockArea[i][0]] [blockArea[i][1]+1] == 9)
    {
      boolean unique = true;
      for (int s=0; s<whichCell; s++)
      {
        if (blockArea[i][0] == blockArea[s][0] &&
        blockArea[i][1]+1 == blockArea[s][1]) unique = false;
      }
      if (unique && blockArea[i][1]+1 != rows-1)
      {
        blockArea[whichCell][0] = blockArea[i][0];
        blockArea[whichCell][1] = blockArea[i][1]+1;
        whichCell++;
      }

    }
    
    if (myGrid [blockArea[i][0]] [blockArea[i][1]-1] == 3)
    {
      blocked = false;
      break;
    }
    else if (myGrid [blockArea[i][0]] [blockArea[i][1]-1] == 9)
    {
      boolean unique = true;
      for (int s=0; s<whichCell; s++)
      {
        if (blockArea[i][0] == blockArea[s][0] &&
        blockArea[i][1]-1 == blockArea[s][1]) unique = false;
      }
      if (unique)
      {
        blockArea[whichCell][0] = blockArea[i][0];
        blockArea[whichCell][1] = blockArea[i][1]-1;
        whichCell++;
      }
    }
    
    if (myGrid [blockArea[i][0]+1] [blockArea[i][1]] == 3)
    {
      blocked = false;
      break;
    }
    else if (myGrid [blockArea[i][0]+1] [blockArea[i][1]] == 9)
    {
      boolean unique = true;
      for (int s=0; s<whichCell; s++)
      {
        if (blockArea[i][0]+1 == blockArea[s][0] &&
        blockArea[i][1] == blockArea[s][1]) unique = false;
      }
      if (unique)
      {
        blockArea[whichCell][0] = blockArea[i][0]+1;
        blockArea[whichCell][1] = blockArea[i][1];
        whichCell++;
      }
    }
    
    if (myGrid [blockArea[i][0]-1] [blockArea[i][1]] == 3)
    {
      blocked = false;
      break;
    }
    
    else if (myGrid [blockArea[i][0]-1] [blockArea[i][1]] == 9)
    {
      boolean unique = true;
      for (int s=0; s<whichCell; s++)
      {
        if (blockArea[i][0]-1 == blockArea[s][0] &&
        blockArea[i][1] == blockArea[s][1]) unique = false;
      }
      if (unique)
      {
        blockArea[whichCell][0] = blockArea[i][0]-1;
        blockArea[whichCell][1] = blockArea[i][1];
        whichCell++;
      }
    }
    //println(whichCell);
  }
  
  if (blocked) 
  {
    println("truly blocked");
    gameOver=true;
    gameWin=false;
    gameEndState = 4;
  }
  if (!blocked) ;//println ("not blocked");

    
}
