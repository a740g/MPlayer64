'-----------------------------------------------------------------------------------------------------------------------
' QB64-PE MIDI Player
' Copyright (c) 2024 Samuel Gomes
'-----------------------------------------------------------------------------------------------------------------------

_DEFINE A-Z AS LONG
OPTION _EXPLICIT

OPTION BASE 1
'$STATIC

$RESIZE:SMOOTH

$UNSTABLE:HTTP

$EXEICON:'./MPlayer64.ico'
$VERSIONINFO:CompanyName='Samuel Gomes'
$VERSIONINFO:FileDescription='MIDI Player 64 executable'
$VERSIONINFO:InternalName='MIDIPlayer64'
$VERSIONINFO:LegalCopyright='Copyright (c) 2024, Samuel Gomes'
$VERSIONINFO:LegalTrademarks='All trademarks are property of their respective owners'
$VERSIONINFO:OriginalFilename='MIDIPlayer64.exe'
$VERSIONINFO:ProductName='MIDI Player 64'
$VERSIONINFO:Web='https://github.com/a740g'
$VERSIONINFO:Comments='https://github.com/a740g'
$VERSIONINFO:FILEVERSION#=3,2,1,0
$VERSIONINFO:PRODUCTVERSION#=3,2,1,0

$COLOR:32
'$INCLUDE:'InForm/extensions/Pathname.bi'
'$INCLUDE:'AudioAnalyzer.bi'

CONST FALSE = 0, TRUE = NOT FALSE
CONST NULL = 0
CONST QUOTE = CHR$(34)
CONST LF = CHR$(10)

CONST APP_NAME = "MIDI Player 64"
CONST SCREEN_WIDTH = 640
CONST SCREEN_HEIGHT = 360
CONST FRAME_RATE_MAX = 60
CONST EVENT_NONE = 0
CONST EVENT_QUIT = 1
CONST EVENT_PLAY = 2
CONST EVENT_CMDS = 3
CONST EVENT_LOAD = 4
CONST EVENT_DROP = 5
CONST EVENT_HTTP = 6

$IF WINDOWS THEN
    CONST MIDI_SOUNDBANK_FILE_FILTERS = "*.wopl|*.op2|*.tmb|*.ad|*.opl|*.sf2|*.sf3|*.sfo|*.dll"
    CONST MIDI_FILE_FILTERS = "*.mus|*.hmi|*.hmp|*.hmq|*.kar|*.lds|*.mds|*.mids|*.rcp|*.r36|*.g18|*.g36|*.rmi|*.mid|*.midi|*.xfm|*.xmi"
$ELSE
    CONST MIDI_SOUNDBANK_FILE_FILTERS = "*.wopl|*.op2|*.tmb|*.ad|*.opl|*.sf2|*.sf3|*.sfo|*.WOPL|*.OP2|*.TMB|*.AD|*.OPL|*.SF2|*.SF3|*.SFO"
    CONST MIDI_FILE_FILTERS = "*.mus|*.hmi|*.hmp|*.hmq|*.kar|*.lds|*.mds|*.mids|*.rcp|*.r36|*.g18|*.g36|*.rmi|*.mid|*.midi|*.xfm|*.xmi|*.MUS|*.HMI|*.HMP|*.HMQ|*.KAR|*.LDS|*.MDS|*.MIDS|*.RCP|*.R36|*.G18|*.G36|*.RMI|*.MID|*.MIDI|*.XFM|*.XMI"
$END IF

TYPE RectType
    AS LONG l, t, r, b
END TYPE

TYPE PlayerType
    song AS LONG
    volume AS SINGLE
    channels AS _UNSIGNED _BYTE
    isLooping AS _BYTE
    bankFileName AS STRING
    analyzerStyle AS INTEGER
    fftScaleX AS _UNSIGNED _BYTE
    fftScaleY AS SINGLE
    downloadBuffer AS STRING
    vLB AS RectType
    vRB AS RectType
    vChan1 AS _UNSIGNED _BYTE
    vChan2 AS _UNSIGNED _BYTE
END TYPE

DIM Player AS PlayerType

InitProgram

DIM event AS _BYTE: event = EVENT_CMDS

DO
    SELECT CASE event
        CASE EVENT_QUIT
            EXIT DO

        CASE EVENT_CMDS
            event = OnCommandLine

        CASE EVENT_LOAD
            event = OnSelectedFiles

        CASE EVENT_DROP
            event = OnDroppedFiles

        CASE EVENT_HTTP
            event = OnBitMidiFiles

        CASE ELSE
            event = OnWelcomeScreen
    END SELECT
LOOP

_AUTODISPLAY
SYSTEM


SUB InitProgram
    SHARED Player AS PlayerType

    CHDIR _STARTDIR$
    SCREEN _NEWIMAGE(SCREEN_WIDTH, SCREEN_HEIGHT, 32)
    _TITLE APP_NAME + " " + _OS$
    _ACCEPTFILEDROP
    _ALLOWFULLSCREEN _SQUAREPIXELS , _SMOOTH
    _DISPLAYORDER _HARDWARE , _HARDWARE1 , _GLRENDER , _SOFTWARE
    _PRINTMODE _KEEPBACKGROUND
    _CONTROLCHR OFF
    RANDOMIZE TIMER
    _DISPLAY

    Player.volume = 1!
    Player.analyzerStyle = AUDIOANALYZER_STYLE_CIRCULAR_WAVEFORM
    Player.fftScaleX = 8
    Player.fftScaleY = 3!

    CONST VIS_SPACE = 8

    DIM vBW AS LONG: vBW = _WIDTH \ 2 - VIS_SPACE * 2
    DIM vBH AS LONG: vBH = (vBW * 3) \ 4

    Player.vLB.l = VIS_SPACE
    Player.vLB.t = VIS_SPACE
    Player.vLB.r = VIS_SPACE + vBW - 1
    Player.vLB.b = VIS_SPACE + vBH - 1
    Player.vRB.l = _WIDTH \ 2 + VIS_SPACE
    Player.vRB.t = Player.vLB.t
    Player.vRB.r = _WIDTH \ 2 + VIS_SPACE + vBW - 1
    Player.vRB.b = Player.vLB.b
END SUB


FUNCTION DownloadFile$ (url AS STRING)
    DIM h AS LONG: h = _OPENCLIENT("HTTP:" + url)

    IF h <> 0 THEN
        DIM AS STRING content, buffer

        WHILE NOT EOF(h)
            _LIMIT FRAME_RATE_MAX
            GET h, , buffer
            content = content + buffer
        WEND

        CLOSE h

        DownloadFile = content
    END IF
END FUNCTION


FUNCTION LoadTune& (PathOrURL AS STRING)
    SHARED Player AS PlayerType

    IF LEN(Pathname_GetDriveOrScheme(PathOrURL)) > 2 THEN
        Player.downloadBuffer = DownloadFile(PathOrURL)
        LoadTune = _SNDOPEN(Player.downloadBuffer, "memory")
    ELSE
        Player.downloadBuffer = ""
        LoadTune = _SNDOPEN(PathOrURL)
    END IF
END FUNCTION


SUB PlayTune
    SHARED Player AS PlayerType

    IF Player.isLooping THEN
        _SNDLOOP Player.song
    ELSE
        _SNDPLAY Player.song
    END IF
END SUB


FUNCTION BoolToString$ (expression AS LONG, style AS _UNSIGNED _BYTE)
    $CHECKING:OFF
    SELECT CASE style
        CASE 1
            IF expression THEN BoolToString = "On" ELSE BoolToString = "Off"
        CASE 2
            IF expression THEN BoolToString = "Enabled" ELSE BoolToString = "Disabled"
        CASE 3
            IF expression THEN BoolToString = "1" ELSE BoolToString = "0"
        CASE ELSE
            IF expression THEN BoolToString = "True" ELSE BoolToString = "False"
    END SELECT
    $CHECKING:ON
END FUNCTION


SUB DrawWeirdPlasma
    $CHECKING:OFF
    CONST __WP_DIV = 8

    STATIC AS LONG w, h, t, imgHandle
    STATIC imgMem AS _MEM

    DIM rW AS LONG: rW = _WIDTH \ __WP_DIV
    DIM rH AS LONG: rH = _HEIGHT \ __WP_DIV

    IF w <> rW _ORELSE h <> rH _ORELSE imgHandle >= -1 THEN
        IF imgHandle < -1 THEN
            _FREEIMAGE imgHandle
            _MEMFREE imgMem
        END IF

        imgHandle = _NEWIMAGE(rW, rH, 32)
        imgMem = _MEMIMAGE(imgHandle)
        w = rW
        h = rH
    END IF

    DIM AS LONG x, y
    DIM AS SINGLE r1, g1, b1, r2, g2, b2

    WHILE y < h
        x = 0
        g1 = 32! * SIN(y / 16! - t / 22!)
        r2 = 32! * SIN(y / 32! + t / 26!)

        WHILE x < w
            r1 = 32! * SIN(x / 16! - t / 20!)
            b1 = 32! * SIN((x + y) / 32! - t / 24!)
            g2 = 32! * SIN(x / 32! + t / 28!)
            b2 = 32! * SIN((x - y) / 32! + t / 30!)

            _MEMPUT imgMem, imgMem.OFFSET + (4 * w * y) + x * 4, _RGB32((r1 + r2) / 2!, (g1 + g2) / 2!, (b1 + b2) / 2!) AS _UNSIGNED LONG

            x = x + 1
        WEND

        y = y + 1
    WEND

    DIM imgGPUHandle AS LONG: imgGPUHandle = _COPYIMAGE(imgHandle, 33)
    _PUTIMAGE , imgGPUHandle
    _FREEIMAGE imgGPUHandle

    t = t + 1
    $CHECKING:ON
END SUB


SUB DrawVisualization
    CONST HELP_LINE1 = "ESC NEXT " + CHR$(179) + " q/Q MAIN " + CHR$(179) + " SPC PAUS " + CHR$(179) + " _/- VOL- " + CHR$(179) + " +/= VOL+ " + CHR$(179) + " l/L LOOP " + CHR$(179) + " F1  LOAD"
    CONST HELP_LINE2 = "F6  SAVE " + CHR$(179) + " </, VIS- " + CHR$(179) + " >/. VIS+ " + CHR$(179) + " LT  SPX- " + CHR$(179) + " RT  SPX+ " + CHR$(179) + " UP  SPY- " + CHR$(179) + " DN  SPY+"
    CONST STAT_LINE1 = CHR$(179) + " \\ : \      \ / \      \ " + CHR$(179) + " VOLUME: ###% " + CHR$(179) + " CHANNELS: ## " + CHR$(179)
    CONST STAT_LINE2 = CHR$(179) + " LOOP:  \ \ " + CHR$(179) + " VISUAL: ### " + CHR$(179) + " FFT X: ##### " + CHR$(179) + " FFT Y: ###.# " + CHR$(179)
    CONST PLAY_PAUSE_TEXT = ">>||"

    STATIC AS STRING statDeco1, statDeco2, statDeco3

    IF LEN(statDeco1) = NULL THEN
        statDeco1 = CHR$(218) + STRING$(26, 196) + CHR$(194) + STRING$(14, 196) + CHR$(194) + STRING$(14, 196) + CHR$(191)
        statDeco2 = CHR$(195) + STRING$(12, 196) + CHR$(194) + STRING$(13, 196) + CHR$(197) + STRING$(14, 196) + CHR$(197) + STRING$(14, 196) + CHR$(180)
        statDeco3 = CHR$(192) + STRING$(12, 196) + CHR$(193) + STRING$(13, 196) + CHR$(193) + STRING$(14, 196) + CHR$(193) + STRING$(14, 196) + CHR$(217)
    END IF

    SHARED Player AS PlayerType

    IF _SNDPAUSED(Player.song) _ORELSE NOT _SNDPLAYING(Player.song) THEN COLOR OrangeRed ELSE COLOR Cyan

    LINE (91, 247)-(548, 311), Black, BF

    LOCATE 16, 12: PRINT statDeco1;
    LOCATE 17, 12: PRINT USING STAT_LINE1; MID$(PLAY_PAUSE_TEXT, 1 + (_SNDPAUSED(Player.song) * -2), 2); AudioAnalyzer_GetCurrentTimeText; AudioAnalyzer_GetTotalTimeText; Player.volume * 100; Player.channels;
    LOCATE 18, 12: PRINT statDeco2;
    LOCATE 19, 12: PRINT USING STAT_LINE2; BoolToString(Player.isLooping, 1); Player.analyzerStyle; Player.fftScaleX; Player.fftScaleY;
    LOCATE 20, 12: PRINT statDeco3;

    COLOR White
    IF Player.vChan1 = Player.vChan2 THEN
        AudioAnalyzer_Render Player.vLB.l, Player.vLB.t, Player.vRB.r, Player.vRB.b, Player.vChan1, Yellow
    ELSE
        AudioAnalyzer_Render Player.vLB.l, Player.vLB.t, Player.vLB.r, Player.vLB.b, Player.vChan1, Yellow
        AudioAnalyzer_Render Player.vRB.l, Player.vRB.t, Player.vRB.r, Player.vRB.b, Player.vChan2, Yellow
    END IF

    COLOR Gray
    LOCATE 21, 4: PRINT HELP_LINE1;
    LOCATE 22, 4: PRINT HELP_LINE2;

    DrawWeirdPlasma

    _DISPLAY
END SUB


SUB SaveTune (fileName AS STRING)
    SHARED Player AS PlayerType

    STATIC savePath AS STRING, alwaysUseSamePath AS _BYTE, stopNagging AS _BYTE

    IF LEN(Pathname_GetDriveOrScheme(fileName)) > 2 THEN
        IF NOT _DIREXISTS(savePath) _ORELSE NOT alwaysUseSamePath THEN
            savePath = _SELECTFOLDERDIALOG$("Select a folder to save the file:", savePath)
            IF LEN(savePath) = NULL THEN EXIT SUB

            savePath = Pathname_FixDirectoryName(savePath)
        END IF

        DIM saveFileName AS STRING: saveFileName = savePath + Pathname_MakeLegalFileName(Pathname_GetFileName(fileName))

        IF _FILEEXISTS(saveFileName) THEN
            IF _MESSAGEBOX(APP_NAME, "Overwrite " + saveFileName + "?", "yesno", "warning", 0) = 0 THEN EXIT SUB
        END IF

        _WRITEFILE saveFileName, Player.downloadBuffer

        IF NOT stopNagging THEN
            SELECT CASE _MESSAGEBOX(APP_NAME, "Do you want to use " + savePath + " for future saves?", "yesnocancel", "question", 1)
                CASE 0
                    stopNagging = TRUE
                CASE 1
                    alwaysUseSamePath = TRUE
                CASE 2
                    alwaysUseSamePath = FALSE
            END SELECT
        END IF
    ELSE
        _MESSAGEBOX APP_NAME, "You cannot save local file " + fileName + "!", "error"
    END IF
END SUB


FUNCTION OnPlayTune%% (fileName AS STRING)
    SHARED Player AS PlayerType

    OnPlayTune = EVENT_PLAY

    Player.song = LoadTune(fileName)

    IF _NEGATE (Player.song OR AudioAnalyzer_Init(Player.song)) THEN
        _MESSAGEBOX APP_NAME, "Failed to load: " + fileName + LF + LF + "The MIDI file or the MIDI instrument bank may be corrupt.", "error"
        EXIT FUNCTION
    END IF

    Player.channels = AudioAnalyzer_GetChannels
    IF Player.channels > 1 THEN
        Player.vChan1 = 0
        Player.vChan2 = 1
    ELSE
        Player.vChan1 = 0
        Player.vChan2 = 0
    END IF

    ' Reapply analyzer settings
    AudioAnalyzer_SetStyle Player.analyzerStyle
    AudioAnalyzer_SetFFTScale Player.fftScaleX, Player.fftScaleY

    DIM tuneTitle AS STRING: tuneTitle = Pathname_GetFileName(fileName)
    _TITLE tuneTitle + " - " + APP_NAME

    PlayTune
    _SNDVOL Player.song, Player.volume

    CLS , 0

    DIM k AS LONG

    DO
        AudioAnalyzer_Update

        DrawVisualization

        k = _KEYHIT

        SELECT CASE k
            CASE 27 ' esc
                EXIT DO

            CASE 113, 81 ' q / Q
                OnPlayTune = EVENT_NONE
                EXIT DO

            CASE 32 ' space
                IF _SNDPAUSED(Player.song) THEN
                    PlayTune
                ELSE
                    _SNDPAUSE Player.song
                END IF

            CASE 43, 61 ' + / =
                IF Player.volume < 1.0! THEN
                    Player.volume = Player.volume + 0.01!
                    IF Player.volume > 1! THEN Player.volume = 1!

                    _SNDVOL Player.song, Player.volume
                END IF

            CASE 95, 45 ' _ / -
                IF Player.volume > 0! THEN
                    Player.volume = Player.volume - 0.01!
                    IF Player.volume < 0! THEN Player.volume = 0!

                    _SNDVOL Player.song, Player.volume
                END IF

            CASE 108, 76 ' l / L
                Player.isLooping = NOT Player.isLooping
                PlayTune

            CASE 60, 44 ' < / ,
                Player.analyzerStyle = Player.analyzerStyle - 1
                IF Player.analyzerStyle < 0 THEN Player.analyzerStyle = AUDIOANALYZER_STYLE_COUNT - 1
                AudioAnalyzer_SetStyle Player.analyzerStyle

            CASE 62, 46 ' > / .
                Player.analyzerStyle = Player.analyzerStyle + 1
                IF Player.analyzerStyle >= AUDIOANALYZER_STYLE_COUNT THEN Player.analyzerStyle = 0
                AudioAnalyzer_SetStyle Player.analyzerStyle

            CASE 19200 ' left arrow
                IF Player.fftScaleX > 1 THEN Player.fftScaleX = Player.fftScaleX - 1
                AudioAnalyzer_SetFFTScale Player.fftScaleX, Player.fftScaleY

            CASE 19712 ' right arrow
                IF Player.fftScaleX < 8 THEN Player.fftScaleX = Player.fftScaleX + 1
                AudioAnalyzer_SetFFTScale Player.fftScaleX, Player.fftScaleY

            CASE 18432 ' up arrow
                IF Player.fftScaleY < 5! THEN Player.fftScaleY = Player.fftScaleY + 0.25!
                AudioAnalyzer_SetFFTScale Player.fftScaleX, Player.fftScaleY

            CASE 20480 ' down arrow
                IF Player.fftScaleY > 0.5! THEN Player.fftScaleY = Player.fftScaleY - 0.25!
                AudioAnalyzer_SetFFTScale Player.fftScaleX, Player.fftScaleY

            CASE 15104 ' F1
                OnPlayTune = EVENT_LOAD
                EXIT DO

            CASE 16384 ' F6
                SaveTune fileName
        END SELECT

        IF _TOTALDROPPEDFILES > NULL THEN
            OnPlayTune = EVENT_DROP
            EXIT DO
        END IF

        _LIMIT FRAME_RATE_MAX
    LOOP WHILE _SNDPLAYING(Player.song) _ORELSE _SNDPAUSED(Player.song)

    AudioAnalyzer_Done
    _SNDSTOP Player.song
    _SNDCLOSE Player.song
    Player.song = NULL

    _TITLE APP_NAME + " " + _OS$
END FUNCTION


FUNCTION OnCommandLine%%
    DIM e AS _BYTE: e = EVENT_NONE

    IF COMMAND$(1) = "/?" _ORELSE COMMAND$(1) = "-?" _ORELSE COMMAND$(1) = "/h" _ORELSE COMMAND$(1) = "-h" _ORELSE COMMAND$(1) = "--help" THEN
        _MESSAGEBOX APP_NAME, APP_NAME + LF + LF + "Syntax: MIDIPlayer64 [-?] [midifile1.mid] [midifile2.mid] ..." + LF + "    -?: Shows this message" + LF + LF + "Copyright (c) 2024, Samuel Gomes" + LF + LF + "https://github.com/a740g/", "info"

        e = EVENT_QUIT
    ELSE
        DIM i AS LONG: FOR i = 1 TO _COMMANDCOUNT
            e = OnPlayTune(COMMAND$(i))
            IF e <> EVENT_PLAY THEN EXIT FOR
        NEXT
    END IF

    OnCommandLine = e
END FUNCTION


FUNCTION ParseOpenFileDialogList& (ofdList AS STRING, ofdArray() AS STRING)
    DIM AS LONG p, c
    DIM ts AS STRING

    REDIM ofdArray(0 TO 0) AS STRING
    ts = ofdList

    DO
        p = INSTR(ts, "|")

        IF p = NULL THEN
            ofdArray(c) = ts

            ParseOpenFileDialogList& = c + 1
            EXIT FUNCTION
        END IF

        ofdArray(c) = LEFT$(ts, p - 1)
        ts = MID$(ts, p + 1)

        c = c + 1
        REDIM _PRESERVE ofdArray(0 TO c) AS STRING
    LOOP
END FUNCTION


FUNCTION OnSelectedFiles%%
    DIM ofdList AS STRING
    DIM e AS _BYTE: e = EVENT_NONE

    ofdList = _OPENFILEDIALOG$(APP_NAME, , MIDI_FILE_FILTERS, , TRUE)

    IF LEN(ofdList) = NULL THEN EXIT FUNCTION

    REDIM fileNames(0 TO 0) AS STRING

    DIM j AS LONG: j = ParseOpenFileDialogList(ofdList, fileNames())

    DIM i AS LONG: WHILE i < j
        e = OnPlayTune(fileNames(i))
        IF e <> EVENT_PLAY THEN EXIT WHILE
        i = i + 1
    WEND

    OnSelectedFiles = e
END FUNCTION


FUNCTION OnDroppedFiles%%
    REDIM fileNames(1 TO _TOTALDROPPEDFILES) AS STRING

    DIM e AS _BYTE: e = EVENT_NONE

    DIM i AS LONG: FOR i = 1 TO _TOTALDROPPEDFILES
        fileNames(i) = _DROPPEDFILE(i)
    NEXT
    _FINISHDROP

    FOR i = LBOUND(fileNames) TO UBOUND(fileNames)
        e = OnPlayTune(fileNames(i))
        IF e <> EVENT_PLAY THEN EXIT FOR
    NEXT

    OnDroppedFiles = e
END FUNCTION


FUNCTION GetRandomBitMidiFileURL$
    DIM buffer AS STRING: buffer = DownloadFile("https://bitmidi.com/random")
    DIM bufPos AS LONG: bufPos = INSTR(buffer, QUOTE + "downloadUrl" + QUOTE)

    IF bufPos > 0 THEN
        bufPos = bufPos + 13
        bufPos = INSTR(bufPos, buffer, QUOTE)
        IF bufPos > 0 THEN
            bufPos = bufPos + 1
            GetRandomBitMidiFileURL = "https://bitmidi.com" + MID$(buffer, bufPos, INSTR(bufPos, buffer, QUOTE) - bufPos)
        END IF
    END IF
END FUNCTION


FUNCTION OnBitMidiFiles%%
    DIM e AS _BYTE: e = EVENT_NONE
    DIM modArchiveFileName AS STRING

    DO
        modArchiveFileName = GetRandomBitMidiFileURL

        _TITLE "Downloading: " + Pathname_GetFileName(modArchiveFileName) + " - " + APP_NAME

        e = OnPlayTune(modArchiveFileName)
    LOOP WHILE e = EVENT_PLAY

    OnBitMidiFiles = e
END FUNCTION


FUNCTION GetSoundbankType$ (fileName AS STRING)
    DIM ext AS STRING: ext = LCASE$(Pathname_GetFileExtension(fileName))

    SELECT CASE ext
        CASE ".sf2", ".sf3", ".sfo"
            GetSoundbankType = "PRIMESYNTH / TSF"

        CASE ".dll"
            GetSoundbankType = "VSTI"

        CASE ELSE
            GetSoundbankType = "OPAL + YMFMIDI"
    END SELECT
END FUNCTION


FUNCTION OnWelcomeScreen%%
    SHARED Player AS PlayerType

    DIM k AS LONG
    DIM e AS _BYTE: e = EVENT_NONE
    DIM bank AS STRING: bank = GetSoundbankType(Player.bankFileName)

    DO
        CLS , 0
        COLOR OrangeRed, 0

        IF TIMER MOD 7 = 0 THEN
            PRINT "         ,-.   ,-.   ,-.    ,.   .   , , ,-.  ,   ;-.  .                   (+_+)"
        ELSEIF TIMER MOD 13 = 0 THEN
            PRINT "         ,-.   ,-.   ,-.    ,.   .   , , ,-.  ,   ;-.  .                   (*_*)"
        ELSE
            PRINT "         ,-.   ,-.   ,-.    ,.   .   , , ,-.  ,   ;-.  .                   (-_-)"
        END IF

        PRINT "        /   \  |  ) /      / |   |\ /| | |  \ |   |  ) |"
        COLOR White
        PRINT "        |   |  |-<  |,-.  '--|   | V | | |  | |   |-'  | ,-: . . ,-. ;-."
        PRINT "        \   X  |  ) (   )    |   |   | | |  / |   |    | | | | | |-' |"
        COLOR Lime
        PRINT "         `-' ` `-'   `-'     '   '   ' ' `-'  '   '    ' `-` `-| `-' '"
        PRINT "                                                             `-'"
        PRINT
        PRINT
        PRINT "                       ";: COLOR Cyan: PRINT "F1";: COLOR Gray: PRINT " ............ ";: COLOR Magenta: PRINT "MULTI-SELECT FILES"
        PRINT
        PRINT "                       ";: COLOR Cyan: PRINT "F2";: COLOR Gray: PRINT " ............. ";: COLOR Magenta: PRINT "PLAY FROM BITMIDI"
        PRINT
        PRINT "                       ";: COLOR Cyan: PRINT "F9";: COLOR Gray: PRINT " ..... ";: COLOR Magenta: PRINT USING "SYNTH: [\              \]"; bank
        PRINT
        PRINT "                       ";: COLOR Cyan: PRINT "ESC";: COLOR Gray: PRINT " ......................... ";: COLOR Magenta: PRINT "QUIT"
        PRINT
        PRINT

        $IF WINDOWS THEN
            PRINT "     ";: COLOR White: PRINT "DRAG AND DROP MULTIPLE FILES ON THIS WINDOW TO PLAY THEM SEQUENTIALLY."
        $ELSE
            PRINT
        $END IF

        PRINT "   ";: COLOR White: PRINT "YOU CAN ALSO START THE PROGRAM WITH MULTIPLE FILES FROM THE COMMAND LINE."
        PRINT
        PRINT "           ";: COLOR White: PRINT "THIS WAS WRITTEN IN QB64-PE (";: COLOR Blue: PRINT "https://www.qb64phoenix.com";: COLOR White: PRINT ").";

        k = _KEYHIT

        IF k = 27 THEN ' ESC
            e = EVENT_QUIT
        ELSEIF _TOTALDROPPEDFILES > NULL THEN
            e = EVENT_DROP
        ELSEIF k = 15104 THEN ' F1
            e = EVENT_LOAD
        ELSEIF k = 15360 THEN ' F2
            e = EVENT_HTTP
        ELSEIF k = 17152 THEN ' F9
            bank = _OPENFILEDIALOG$(APP_NAME + ": Select MIDI Instrument Bank", , MIDI_SOUNDBANK_FILE_FILTERS)
            IF LEN(bank) THEN
                Player.bankFileName = bank
                _MIDISOUNDBANK Player.bankFileName
            END IF

            bank = GetSoundbankType(Player.bankFileName)
        END IF

        DrawWeirdPlasma

        _DISPLAY

        _LIMIT FRAME_RATE_MAX
    LOOP WHILE e = EVENT_NONE

    OnWelcomeScreen = e
END FUNCTION


'$INCLUDE:'InForm/extensions/Pathname.bas'
'$INCLUDE:'AudioAnalyzer.bas'
