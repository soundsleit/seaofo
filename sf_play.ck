//plays back soundfiles from given category/directory

2=>int chan;
0=>int offset;
5 => int lenSeconds;

0=> int numTypes;
0=> int numTypeFiles;

"noises" => string whichCategory;

if (me.args() > 0)
{
    Std.atoi(me.arg(0)) => chan;
    Std.atoi(me.arg(1)) => offset;
    Std.atoi(me.arg(2)) => lenSeconds;
    me.arg(3) => whichCategory;
}

5::second => dur release;

//root directory of sound files
"snd/" + whichCategory + "/" => string rootDir;

//maximum number of files in use
99=>int maxFiles;

//an array for all the filenames
string filenames[maxFiles];
string filenamesThis[maxFiles][maxFiles];

//number of sounds overal
0=> int numSoundsAll;

//scan the sound directory and store filenames
ScanSounds(rootDir, ".wav") => int sndType;

//launch the water players per channel
for (0=>int i; i<chan; i++)
{
    spork ~ playSnd(filenamesThis[sndType][i%numTypeFiles], lenSeconds, i);
}

lenSeconds::second + release => now;

//********************************************************************
//scan the sound directory and put soundfile names into various arrays
fun int ScanSounds(string r, string k)
{
    //load filenames into an array
    FileIO file;
    file.open(r);
    file.dirList() @=> string fn[];
    
    //filter out the junk and store all
    for (0=>int i; i<fn.cap(); i++)
    {
        if (fn[i].find(k) > -1)
        {
            r + fn[i] => filenames[numSoundsAll];
            numSoundsAll++;
        }
    }
    
    for (0=>int n; n<maxFiles; n++)
    {
        0=>int hits;
        
        for (0=>int i; i<filenames.cap(); i++)
        {
            if (filenames[i].find(whichCategory + n) > -1) 
            {
                filenames[i] => filenamesThis[numTypes][hits];
                hits++;
            }
        }
        if (filenamesThis[numTypes][0] != "") numTypes++;
    }
    
    Math.random2(0,numTypes-1) => int whichType;
    
    for (0=>int i; i<filenamesThis[whichType].cap(); i++)
    {
        if (filenamesThis[whichType][i] != "") numTypeFiles++;
    }
    
    //<<<"...files scanned and names stored">>>;
    //<<<whichType>>>;
        
    return whichType;
    
}


//play water layer per channel
fun void playSnd(string _fname, int _len, int _chan)
{
    .1 => float initGain;
    1::second => dur attack;
    _len::second => dur length;
    
    //the patch
    SndBuf snd => ADSR env => dac.chan(_chan+offset);
    
    1=>snd.loop;
    initGain => snd.gain;
    (attack, 0::ms, 1, release)=> env.set;
    _fname => snd.read;
    Math.random2(0, snd.samples()-1) => snd.pos;
    
    //trigger it
    env.keyOn(1);
    attack => now;
    
    //sustain
    length - (attack) => now;
    
    //release
    env.keyOn(0);
    release => now;
    
}