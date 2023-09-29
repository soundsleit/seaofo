//chuck patch for interface/game "Sea of o"
// Jan 2023 / Sept. 2023 by Scott Smallwood
// v.1.0
// patch responds to coms by the processing patch / app


//main vol
3 => dac.gain;

//number of output channels
dac.channels()=>int channels;

0=>int offset; //for motu


if (me.args() > 0)
{
    Std.atoi(me.arg(0)) => channels;
    Std.atoi(me.arg(1)) => offset;
}

//various notes/tuning

//fundmental key pitch
53 => int mainPitchBase;

//move notes
mainPitchBase + 18 => int movePitchBase;
[[0,4,7,9],[0,4,7,11],[0,4,7,14],[0,4,7,12]] @=> int moveNoteInts[][];

//start/win/lose notes
[0,2,4,5] @=> int startNoteInts[];
[12,16,19,21,24,26] @=> int winNoteInts[];
[24,19,16,13,10,7]  @=> int loseNoteInts[];

//drone clusters
[0,2,7,9,11] @=> int droneClusterInts[];
[24,36,38,48,50] @=> int starClusterInts[];


//pitches for the characters in the grid (for pings)
mainPitchBase + 4 => int pitch_o;
mainPitchBase => int pitch_0;
mainPitchBase + 7 => int pitch_slash;
mainPitchBase + 9 => int pitch_plus;
mainPitchBase + 26 => int pitch_star;

//for inital array sizes
99=>int maxGridData;
999=>int maxMoves;

//the grid data
int gridData[maxGridData][maxGridData];
int moveDataCol[maxMoves];
int moveDataRow[maxMoves];
0=>int gridSize;

//how many moves the player has made
0=>int numMoves;
0=>int numNewMoves;

//boolean - did we quit?
1=>int quitMe;

//have I hit a trap?
0=>int slashed;
0=>int gameWin;
0=>int numWins;
0=>int gameEndState;
0=>int numBlockLosses;
0=>int numTimeLosses;
0=>int numSlashedLosses;
0=>int numQuitLosses;
0=>int numStars;

Event beginEvent;
Event screenEvent;


//the grid patch
10=>int gridVoices;
BlitSquare tri[channels][gridVoices];
LPF filt[channels][gridVoices];
ADSR env[channels][gridVoices];
PoleZero dcBlock[channels][gridVoices];

//patch it up
for (0=>int c; c<channels; c++)
for (0=>int v; v<gridVoices; v++)
{
    tri[c][v]=>filt[c][v]=>env[c][v]=>dcBlock[c][v]=>dac.chan(c+offset);
    1.0/gridVoices => tri[c][v].gain;
    1 => filt[c][v].Q;
    .95 => dcBlock[c][v].blockZero;
}


spork ~ startupSound();

spork ~ screenPanel();

//the program loop
while (true)
{
    //ids for the shreds - for quitting    
    Shred s1, s2, s3, s4, s5, s6, s7, s8;
    
    //wait for ready message from processing
    startCheck();
    
    //launch all the shreds and hang out
    if (!quitMe)
    {  
        spork ~ netGetGridData() @=> s1;
        spork ~ netGetPulse() @=> s2;
        spork ~ netGetMove() @=> s3;
        spork ~ netGetStar() @=> s4;
        spork ~ netGetSlashed() @=> s5;
        spork ~ gridMusic() @=> s6;
        spork ~ quitCheck() @=> s7;
        
        spork ~ gameDrone(droneClusterInts,.01);
        
        while(!quitMe) 100::ms => now;
    }
    
    //remove all the shreds - clean up
    Machine.remove(s1.id());
    Machine.remove(s2.id());
    Machine.remove(s3.id());
    Machine.remove(s4.id());
    Machine.remove(s5.id());
    Machine.remove(s6.id());
    Machine.remove(s7.id());
    
    screenEvent.broadcast();
        
    //play end music
    if (gameWin) 
    {
        numWins++;
        
        3*numWins => int durSec;
        
        //play win music
        spork ~ winMusic(durSec);


        //durSec::second => now;
        1::second => now;
    }
        
    else spork ~ loseMusic(Math.random2(7,15));
    
}

fun void screenPanel()
{
    2::second => now;
    
    while (true) {
        
        for (0 => int i; i < 40; i++)
            <<< " ", " " >>>;
        
        <<< "    S E A   O F  o ", " " >>>;
        <<< "    ++++++++++++++++++++++++++++++++++++++++++++++++++++", " " >>>;
        <<< "                                                      ", " " >>>;
        <<< "     ", channels, " channels">>>;
        <<< "                                                      ", " " >>>;
        <<< "      Wins [", numWins, "] Losses [", 
        numQuitLosses + numSlashedLosses + numBlockLosses + numTimeLosses, "] " >>>;
        <<< "                                                      ", " " >>>;
        <<< "           Time Outs [", numTimeLosses, "]    Block Outs [", numBlockLosses,"] " >>>;
        <<< "           Slashed   [", numSlashedLosses, "]    Quits      [", numQuitLosses, "] " >>>;
        <<< "                                                      ", " " >>>;
        <<< "           Pure Paths [ 0 ]", "  Stars [", numStars, "] ">>>;
        <<< "                                                      ", " " >>>;
        <<< "     - - - - THIS GAME - - - - -                        ", " " >>>;
        <<< "                                                      ", " " >>>;
        <<< "      Active [", !quitMe, "]   Moves [", numNewMoves, "] " >>>;

        <<< "                                                      ", " " >>>;
        <<< "    ++++++++++++++++++++++++++++++++++++++++++++++++++++", " " >>>;
        
        screenEvent => now;
    }

}



//hang out until OSC ready message is received,
//indicating that the game game begin
fun void startCheck()
{
    //reset game params
    0=>numMoves => numNewMoves => gridSize => slashed;
    
    //osc setup
    OscRecv recv;
    32000 => recv.port;
    recv.listen();
    recv.event("/ready, i") @=> OscEvent gridBlob;
    
    gridBlob=>now;
    screenEvent.broadcast();
    
    while (gridBlob.nextMsg() != 0)
    {
        0 => quitMe => numMoves => numNewMoves => gridSize => slashed;
        spork ~ startMusic();
    }
    
    screenEvent.broadcast();

}

//check to see if game quit, and in what state
fun void quitCheck()
{
    //osc setup
    OscRecv recv;
    32000 => recv.port;
    recv.listen();
    recv.event("/quitMe, i") @=> OscEvent gridBlob;
    
    while(!quitMe)
    {
        gridBlob=>now;
        
        while (gridBlob.nextMsg() != 0)
        {
            gridBlob.getInt() => gameEndState;
            if (gameEndState==1) 
            {
                1=>gameWin;
            }
            else if (gameEndState==2)
            {
                0=>gameWin;
                numBlockLosses++;
            }
            else if (gameEndState==3)
            {
                0=>gameWin;
                numTimeLosses++;
            }
            else if (gameEndState==4)
            {
                0=>gameWin;
                numSlashedLosses++;
            }
            else if (gameEndState==0)
            {
                0=>gameWin;
                numQuitLosses++;
            }
            
            1 => quitMe;
            for (0=>int c; c<channels; c++)
            for (0=>int i; i<gridVoices; i++) env[c][i].keyOff(1);
        }
    }
}


fun void netGetGridData()
{
    //osc setup
    OscRecv recv;
    32000 => recv.port;
    recv.listen();
    recv.event("/grid, i i i") @=> OscEvent gridBlob;
       
    while(!quitMe)
    {
        gridBlob=>now;
        
        while (gridBlob.nextMsg() != 0)
        {
            gridBlob.getInt() => int tmp;
            gridBlob.getInt() => int _j;
            gridBlob.getInt() => int _i;
            tmp => gridData[_i-1][_j-1];
            gridSize++;
        }
    }
}

//start up beep
fun void startupSound()
{
    100::ms => dur beepTime;
    
    SinOsc s => ADSR e;
    (5::ms, 0::ms, 1, 20::ms) => e.set;
    .02=>s.gain;
    
    for (0=>int c; c<channels; c++)
    {

        e => dac.chan(c+offset);
        Std.mtof(mainPitchBase+(c*3)) * Math.pow(2,2) => s.freq;
        
        for (0=>int i; i<3; i++)
        {

            e.keyOn(1);
            e.attackTime() => now;
            e.keyOn(0);
            beepTime - e.attackTime() => now;
        }
    }
    
}

//music before play begins
fun void startMusic()
{
    screenEvent.broadcast();
    
    SndBuf sf[channels];
    ADSR e[channels];
    for (0=>int i; i<channels; i++)
    {
        sf[i] => e[i] => dac.chan(offset+i);
        sf[i].loop(1);
        "snd/drone/drone" + Math.random2(0,1) + ".wav" => sf[i].read;
        Math.random2(0, sf[i].samples()-1) => sf[i].pos;
        (3::second,0::second,1,10::second) => e[i].set;
        .1 => sf[i].gain;
        e[i].keyOn(1);
    }
    
    beginEvent => now;
    
    for (0=>int i; i<channels; i++)
    {
        e[i].keyOn(0);
    }
    
    e[0].releaseTime()=>now;
    
}

//plays win sounds and waits
fun void winMusic(int _durSec)
{
    
    Machine.add("sf_play.ck:" + channels + ":" + offset + ":" + _durSec + ":water");
    
    //clear this state
    0=>slashed;
    
    for (0=>int i; i<winNoteInts.cap(); i++)
    {
        winNoteInts[i]+mainPitchBase=>float _freq;
        _freq => float _filtFreq;
        1000=>int _decay;
        20=>int _harmMin;
        30=>int _harmMax;
        1=>float _filtQ;
        
        spork ~ playBlip(_freq, _filtFreq, _filtQ, _decay, i%gridVoices,_harmMin,_harmMax, i%channels);
        100::ms => now;
    }
    
    1::second=>now;

    
    _durSec::second => now;
    
    screenEvent.broadcast();
    
}

fun void loseMusic(int _durSec)
{
    
    if (gameEndState == 2) 
        Machine.add("sf_play.ck:" + channels + ":" + offset + ":" + _durSec + ":convoy");
    if (gameEndState == 3) 
        Machine.add("sf_play.ck:" + channels + ":" + offset + ":" + _durSec + ":piano");
    if (gameEndState == 4) 
        Machine.add("sf_play.ck:" + channels + ":" + offset + ":" + _durSec + ":noises");
    if (gameEndState == 1) 
        Machine.add("sf_play.ck:" + channels + ":" + offset + ":" + _durSec + ":piano");
    
    _durSec::second => now;
    
    screenEvent.broadcast();
}


fun void playGridStar()
{
    
    5000::ms => dur beepTime;
    3::ms => dur attackTime;
    2000::ms => dur releaseTime;
    
    SinOsc s => ADSR e => dac;
    (attackTime, beepTime - attackTime - releaseTime, .3, releaseTime) => e.set;
    
    .05=>s.gain;
    Std.mtof(pitch_star) => s.freq;
    
    e.keyOn(1);
    e.attackTime() => now;
    e.keyOn(0);
    beepTime - e.attackTime() => now;
    
}


fun void netGetPulse()
{
    //osc setup
    OscRecv recv;
    32000 => recv.port;
    recv.listen();
    recv.event("/pulse, i") @=> OscEvent pulseBlob;
    
    //pulse patch
    SinOsc s => ADSR e => dac;
    (5::ms, 0::ms, 1, 10::ms) => e.set;
    300 => s.freq;
    .02 => s.gain;
    
    while(!quitMe)
    {
        pulseBlob=>now;
        
        while (pulseBlob.nextMsg() != 0)
        {
            pulseBlob.getInt() => int pulseNumber;
            e.keyOn(1);
            5::ms => now;
            e.keyOff(1);
        }
    }
}

//gets the move data, triggers sound
//also stores the location data (the player's path)
fun void netGetMove()
{
    //osc setup
    OscRecv recv;
    32000 => recv.port;
    recv.listen();
    recv.event("/move, i i i") @=> OscEvent moveBlob;
    
    //direction
    0=>int dir;
    0=>int moveLast;
    0=>int moveItem;
    
    while(!quitMe)
    {
        moveBlob=>now;
        
        beginEvent.broadcast();
        
        while (moveBlob.nextMsg() != 0)
        {
            //store
            moveBlob.getInt() => moveDataCol[numMoves];
            moveBlob.getInt() => moveDataRow[numMoves];
            moveBlob.getInt() => moveItem;
            
            if (numMoves>0)
            {
                if (moveDataCol[numMoves-1] > moveDataCol[numMoves]) 0=>dir;
                else if (moveDataCol[numMoves-1] < moveDataCol[numMoves]) 1=>dir;
                else if (moveDataRow[numMoves-1] > moveDataRow[numMoves]) 2=>dir;
                else if (moveDataRow[numMoves-1] < moveDataRow[numMoves]) 3=>dir;
            }
            
            numMoves++;
            
            screenEvent.broadcast();
            
            //trigger move sound
            if (moveItem == 3)
            {
                spork ~ netMoveSeq(dir);
                numNewMoves++;
            }
            //breath
            100::ms=>now;
        }

    }
}


//plays a short sequence on move
fun void netMoveSeq(int _which)
{
    
    //move patch
    4 =>int _voices;
    
    StifKarp s[_voices];
    JCRev r[_voices];
                
    for (0=>int i; i<_voices; i++)
    {
        .1=>r[i].mix;
        moveDataCol[numMoves-1] => int _movCol;
        moveDataRow[numMoves-1] => int _movRow;
        (Math.pow(gridSize,.5)-_movCol) / Math.pow(gridSize,.5) => float _sideFactor;
        (Math.pow(gridSize,.5)-_movRow) / Math.pow(gridSize,.5) => float _riseFactor;
        
        s[i]=>r[i]=>dac.chan(Math.random2(0,channels-1)+offset);
        (_riseFactor * .05)+.05 => s[i].gain;
        Std.mtof(movePitchBase+moveNoteInts[_which][i]) => s[i].freq;
        s[i].noteOn(1);
        Math.random2f(.2,(.5 * _riseFactor)) => float p;
        if (p>1) .99=>p;
        if (p<0) .01=>p;
        s[i].pluck(p);
        s[i].pickupPosition(Math.random2f(.8,.9));
        Math.fabs(_sideFactor-.1) => float sus;
        if (sus>1) .99=>sus;
        if (sus<0) .01=>sus;
        s[i].sustain(sus);
        80::ms=>now;
    }
    
}


//the star!
fun void netGetStar()
{
    //osc setup
    OscRecv recv;
    32000 => recv.port;
    recv.listen();
    recv.event("/star, i") @=> OscEvent starBlob;

    while(!quitMe)
    {
        starBlob=>now;
        
        while (starBlob.nextMsg() != 0)
        {
            //trigger move sound
            spork ~ starChimes();
            spork ~ gameDrone(starClusterInts,.001);
            //breath
            100::ms=>now;
            numStars++;
        }
        
    }
}

fun void starChimes()
{
    //move patch
    8=>int _voices;
       
    StifKarp s[_voices];
    Echo r[_voices];
    SndBuf sf => dac;
    "snd/stars/stars_" + Math.random2(0,4) + ".wav" => sf.read;
    .2=>sf.gain;
        
    for (0=>int i; i<_voices; i++)
    {
        s[i]=>r[i]=>dac;
        (.4/_voices) => s[i].gain;
        Std.mtof((mainPitchBase - Math.random2(0,9)) + (i * (4))) * Math.random2f(.99,1.01) => s[i].freq;
        Math.random2f(400,800)::ms=>r[i].delay;
        .3 => r[i].mix;
        s[i].pluck(Math.random2f(.7,.8));
        100::ms=>now;
    }
    5::second=>now;

}

fun void netGetSlashed()
{
    //osc setup
    OscRecv recv;
    32000 => recv.port;
    recv.listen();
    recv.event("/slashed, i") @=> OscEvent slashBlob;
    
    
    while(!quitMe)
    {
        slashBlob=>now;
        
        while (slashBlob.nextMsg() != 0)
        {
            1=>slashed;
            500::ms => now;
            0=>slashed;
        }
    }
}

fun void gameDrone(int _ints[], float _baseAmp)
{
    12 => int _voices;
    0 => float amp_sq;
    0 => float amp_lin;
    
    //the patch
    SinOsc s[_voices];
    ADSR e[_voices];
    
    for (0=>int i; i<_voices; i++)
    {
        s[i]=>e[i]=>dac.chan((i%channels)+offset);
        0 => s[i].gain;
        (10::second, 0::ms, 1, 5::second) => e[i].set;
        Std.mtof(_ints[Math.random2(0,_ints.cap()-1)]+mainPitchBase) * Math.random2f(.995,1.005) => s[i].freq;
        e[i].keyOn(1);
    }
    
    while(!quitMe)
    {
        if (numMoves > 0 && gridSize > 0)
        {
            //grab current move data and use it to change the volume of this later
            //(bottom to top of grid)
            1.0 - (moveDataRow[numMoves-1]/Math.pow(gridSize, .5)) => amp_lin;
            Math.pow(amp_lin,2)*_baseAmp => amp_sq;
            
            //top up (or down) until new value readed (line)
            while (s[0].gain() < amp_sq)
            {
                for (0=>int i; i<_voices; i++)
                {
                    amp_sq + .0001 => s[i].gain;
                }
                1::samp => now;
            }
            while (s[0].gain() > amp_sq)
            {
                for (0=>int i; i<_voices; i++)
                {
                    amp_sq - .0001 => s[i].gain;
                }
                1::samp => now;
            }
        }
        10::ms => now;
    }
    
    for (0=>int i; i<_voices; i++)
    {
        e[i].keyOff(1);
    }
    
    e[0].releaseTime() + 100::ms => now;

    
}

fun void gridMusic()
{
    <<<"grid launched">>>;
    //osc setup
    OscRecv recv;
    32000 => recv.port;
    recv.listen();
    recv.event("/gridGo, i") @=> OscEvent gridBlob;
    
    //incrementor
    0=>int inc;
    //for storing tempo (gotten from OSC)
    0=>int tempo;
    while(!quitMe)
    {
       1::ms => now;
       
       //wait for the first move
       if (numMoves>0)
       {
           //wait for the go message
           gridBlob => now;
           while (gridBlob.nextMsg() != 0) gridBlob.getInt() => tempo;
           
           //loop through the data and play blips, until end or quit
           for (0=>int i; i<Math.pow(gridSize,.5); i++)
           {
               //play a note at beginning of line
               spork ~ playBlip(mainPitchBase + 12, mainPitchBase + 6, 5, 800, inc++%gridVoices,5,8, i%channels);
                              
               for (0=>int j; j<Math.pow(gridSize,.5); j++)
               {
                   //the grid character data
                   gridData[i][j] => int _cell;
                   moveDataCol[numMoves-1] => int _movCol;
                   moveDataRow[numMoves-1] => int _movRow;
                   (Math.pow(gridSize,.5)-_movCol) / Math.pow(gridSize,.5) => float _sideFactor;
                   (Math.pow(gridSize,.5)-_movRow) / Math.pow(gridSize,.5) => float _riseFactor;
                   
                   float _freq;
                   float _filtFreq;
                   1 => float _filtQ;
                   int _decay;
                   ((5.0*_riseFactor)+3) $ int=>int _harmMin;
                   ((10.0*_riseFactor)+3) $ int=>int _harmMax;
                   
                   if (_cell == 3) // o
                   {
                       pitch_o * Math.random2f(.999,1.001) => _freq;
                       //Math.random2f(1,1+(3*_sideFactor)) => _filtQ;
                       Math.random2f(pitch_o,pitch_o+(18*_riseFactor)) => _filtFreq;
                       Math.random2(200,300) => _decay;
                   }
                   else if (_cell == 6) // 0
                   {
                       pitch_0 * Math.random2f(.999,1.001) => _freq;
                       //Math.random2f(1,1+(3*_sideFactor)) => _filtQ;
                       Math.random2f(pitch_0,pitch_0+(18*_riseFactor)) => _filtFreq;
                       Math.random2(400,700) => _decay;
                   }
                   else if (_cell == 4 || _cell == 5) // / \
                   {
                       
                       pitch_slash * Math.random2f(.999,1.001) => _freq;
                       //Math.random2f(1,1+(3*_sideFactor)) => _filtQ;
                       Math.random2f(pitch_slash,pitch_slash+(18*_riseFactor)) => _filtFreq;
                       Math.random2(400,700) => _decay;
                   }
                   else if (_cell == 7) // +
                   {
                       pitch_plus * Math.random2f(.999,1.001) => _freq;
                       //Math.random2f(1,1+(3*_sideFactor)) => _filtQ;
                       Math.random2f(pitch_plus,pitch_plus+(18*_riseFactor)) => _filtFreq;
                       Math.random2(200,400) => _decay;
                   }
                   else if (_cell == 8) // *
                   {
                       pitch_o * Math.random2f(.999,1.001) => _freq;
                       //Math.random2f(1,1+(3*_sideFactor)) => _filtQ;
                       Math.random2f(pitch_o,pitch_o+(18*_riseFactor)) => _filtFreq;
                       Math.random2(200,300) => _decay;
                       
                       spork ~ playGridStar();
                   }
                   
                   //play the note
                   spork ~ playBlip(_freq, _filtFreq, _filtQ, _decay, inc++%gridVoices,_harmMin,_harmMax, j%channels);
                   
                   //set the tempo based on pulse and number of pulses total
                   (tempo*Math.pow(gridSize+2,.5)*2/gridSize+2)::ms => now;
                   
                   
                   //in case of quit
                   if (quitMe) return;
               }
           }
       }
    }
}


//plays a "blip" for each character reading through the grid data, from top to bottom
fun void playBlip(float _freq, float _filtFreq, float _filtQ, float _relMS, int _voice, int _harmMin, int _harmMax, int _chan)
{

    //set initial gain
    1.0/gridVoices => tri[_chan][_voice].gain;
    
    _filtQ => filt[_chan][_voice].Q;
    //osc freq
    Std.mtof(_freq) => tri[_chan][_voice].freq;
    //set filter freq
    Std.mtof(_filtFreq)*Math.random2f(.9,1.1) => filt[_chan][_voice].freq;
    //envelopes
    Math.random2f(10.0, 20.0) => float _attMS;
    (_attMS::ms, 0::ms, 1, _relMS::ms) => env[_chan][_voice].set;
    //timbre
    if (slashed) 
    {
        125=>tri[_chan][_voice].harmonics;
        Math.random2f(1000,2000)=>_relMS;
        Math.random2f(1000,1200) => filt[_chan][_voice].freq;
        tri[_chan][_voice].gain() / 2 => tri[_chan][_voice].gain;
    }
    else Math.random2(_harmMin,_harmMax)=>tri[_chan][_voice].harmonics; 

    
    env[_chan][_voice].keyOn(1);
    50::ms => now;
    env[_chan][_voice].keyOff(1);
    env[_chan][_voice].releaseTime() => now;
}