'-----------------------------------------------------------------------------------------------------------------------
' QB64-PE MIDI Player
' Copyright (c) 2023 Samuel Gomes
'-----------------------------------------------------------------------------------------------------------------------

'-----------------------------------------------------------------------------------------------------------------------
' HEADER FILES
'-----------------------------------------------------------------------------------------------------------------------
'$Include:'include/FileOps.bi'
'$Include:'include/MIDIPlayer.bi'
'-----------------------------------------------------------------------------------------------------------------------

'-----------------------------------------------------------------------------------------------------------------------
' METACOMMANDS
'-----------------------------------------------------------------------------------------------------------------------
$ExeIcon:'./MIDPlayer64.ico'
$VersionInfo:CompanyName=Samuel Gomes
$VersionInfo:FileDescription=MIDI Player 64 executable
$VersionInfo:InternalName=MIDIPlayer64
$VersionInfo:LegalCopyright=Copyright (c) 2023, Samuel Gomes
$VersionInfo:LegalTrademarks=All trademarks are property of their respective owners
$VersionInfo:OriginalFilename=MIDPlayer64.exe
$VersionInfo:ProductName=MIDI Player 64
$VersionInfo:Web=https://github.com/a740g
$VersionInfo:Comments=https://github.com/a740g
$VersionInfo:FILEVERSION#=2,0,2,0
$VersionInfo:PRODUCTVERSION#=2,0,2,0
'-----------------------------------------------------------------------------------------------------------------------

'-----------------------------------------------------------------------------------------------------------------------
' CONSTANTS
'-----------------------------------------------------------------------------------------------------------------------
Const APP_NAME = "MIDI Player 64"
Const AUDIO_BUFFER_TIME = 0.2
Const FRAME_RATE_MAX = 120
' Program events
Const EVENT_NONE = 0 ' idle
Const EVENT_QUIT = 1 ' user wants to quit
Const EVENT_CMDS = 2 ' process command line
Const EVENT_LOAD = 3 ' user want to load files
Const EVENT_DROP = 4 ' user dropped files
Const EVENT_PLAY = 5 ' play next song
'-----------------------------------------------------------------------------------------------------------------------

'-----------------------------------------------------------------------------------------------------------------------
' GLOBAL VARIABLES
'-----------------------------------------------------------------------------------------------------------------------
Dim Shared useFMSynth As Byte: useFMSynth = FALSE
'-----------------------------------------------------------------------------------------------------------------------

'-----------------------------------------------------------------------------------------------------------------------
' PROGRAM ENTRY POINT
'-----------------------------------------------------------------------------------------------------------------------
Title APP_NAME + " " + OS$ ' Set the program name in the titlebar
ChDir StartDir$ ' Change to the directory specifed by the environment
AcceptFileDrop ' Enable drag and drop of files
Screen NewImage(640, 480, 256) ' Use 640x480 resolution
AllowFullScreen SquarePixels , Smooth ' All the user to press Alt+Enter to go fullscreen
PrintMode KeepBackground
Display ' Only swap display buffer when we want
RebootMIDILibrary ' kickstart the MIDI Player library with default settings

Dim event As Unsigned Byte: event = EVENT_CMDS ' default to command line event first

' Main loop
Do
    Select Case event
        Case EVENT_QUIT
            Exit Do

        Case EVENT_DROP
            event = ProcessDroppedFiles

        Case EVENT_LOAD
            event = ProcessSelectedFiles

        Case EVENT_CMDS
            event = ProcessCommandLine

        Case Else
            event = DoWelcomeScreen
    End Select
Loop Until event = EVENT_QUIT

AutoDisplay
MIDI_Finalize
System
'-----------------------------------------------------------------------------------------------------------------------

'-----------------------------------------------------------------------------------------------------------------------
' FUNCTIONS & SUBROUTINES
'-----------------------------------------------------------------------------------------------------------------------
' This closes and re-initialized the library
' This is needed if we want to toggle between FM & Sample synth
Sub RebootMIDILibrary
    MIDI_Finalize ' close the MIDI library if it was opened before

    ' (Re-)Initialize the MIDI Player library
    If Not MIDI_Initialize(useFMSynth) Then
        MessageBox APP_NAME, "Failed to initialize MIDI Player library!", "error"
        System 1
    End If
End Sub


' Weird plasma effect
Sub DrawWeirdPlasma
    Dim As Long x, y, r, g, b, r2, g2, b2, right, bottom
    Static t As Long

    right = Width - 1
    bottom = Height - 1

    t = t + 1
    For x = 2 To right Step 5 ' start from 2 to make things look better
        For y = 1 To bottom Step 4 ' start from 1 to make things look better
            r = 64 + 128 * Sin(x / 16 - t / 20)
            g = 64 + 128 * Sin(y / 16 - t / 22)
            b = 64 + 128 * Sin((x + y) / 32 - t / 24)
            r2 = 64 + 128 * Sin(y / 32 + t / 26)
            g2 = 64 + 128 * Sin(x / 32 + t / 28)
            b2 = 64 + 128 * Sin((x - y) / 32 + t / 30)
            PSet (x, y), RGB((r + r2) \ 2, (g + g2) \ 2, (b + b2) \ 2)
        Next
    Next
End Sub


' Draws the screen during playback
Sub DrawInfoScreen
    Shared __MIDI_Player As __MIDI_PlayerType

    Dim As Unsigned Long nsf, x
    Dim As Single lSamp, rSamp
    Dim As String minute, second

    Cls , 0 ' clear the framebuffer to black color
    DrawWeirdPlasma

    If MIDI_IsPaused Or Not MIDI_IsPlaying Then Color 12 Else Color 15

    Locate 22, 43: Print "Buffered sound:"; SndRawLen(__MIDI_Player.soundHandle) * 1000; "ms";
    Locate 23, 43: Print "        Voices:"; MIDI_GetActiveVoices;
    Locate 24, 43: Print Using "Current volume: ###%"; MIDI_GetVolume * 100;
    minute = Right$("00" + LTrim$(Str$((MIDI_GetCurrentTime + 500) \ 60000)), 2)
    second = Right$("00" + LTrim$(Str$(((MIDI_GetCurrentTime + 500) \ 1000) Mod 60)), 2)
    Locate 25, 43: Print Using "  Elapsed time: &:& (mm:ss)"; minute; second
    minute = Right$("00" + LTrim$(Str$((MIDI_GetTotalTime + 500) \ 60000)), 2)
    second = Right$("00" + LTrim$(Str$(((MIDI_GetTotalTime + 500) \ 1000) Mod 60)), 2)
    Locate 26, 43: Print Using "    Total time: &:& (mm:ss)"; minute; second

    Color 11
    Locate 22, 7: Print "ESC - NEXT / QUIT"
    Locate 23, 7: Print "SPC - PLAY / PAUSE"
    Locate 24, 7: Print "=|+ - INCREASE VOLUME"
    Locate 25, 7: Print "-|_ - DECREASE VOLUME"
    Locate 26, 7: Print "L|l - LOOP"

    nsf = __MIDI_Player.soundBufferSize \ __MIDI_SOUND_BUFFER_FRAME_SIZE 'number of sample frames in the buffer

    Color 15: PrintString (224, 32), "Left Channel (Wave plot)"
    Color 10: PrintString (20, 32), "0 [ms]": PrintString (556, 32), Left$(Str$(nsf * 1000 \ SndRate), 6) + " [ms]"
    View (20, 48)-(620, 144), 0, 7 ' set a viewport to draw to so that even if we draw outside it gets clipped
    For x = 0 To nsf - 1
        lSamp = MemGet(__MIDI_Player.soundBuffer, __MIDI_Player.soundBuffer.OFFSET + x * __MIDI_SOUND_BUFFER_FRAME_SIZE, Single) ' get left channel sample
        Line (x * 601 \ nsf, 47)-Step(0, lSamp * 47), 10 ' plot wave
    Next
    View

    Color 15: PrintString (220, 160), "Right Channel (Wave plot)"
    Color 10: PrintString (20, 160), "0 [ms]": PrintString (556, 160), Left$(Str$(nsf * 1000 \ SndRate), 6) + " [ms]"
    View (20, 176)-(620, 272), 0, 7 ' set a viewport to draw to so that even if we draw outside it gets clipped
    For x = 0 To nsf - 1
        rSamp = MemGet(__MIDI_Player.soundBuffer, __MIDI_SOUND_BUFFER_SAMPLE_SIZE + __MIDI_Player.soundBuffer.OFFSET + x * __MIDI_SOUND_BUFFER_FRAME_SIZE, Single) ' get right channel sample
        Line (x * 601 \ nsf, 47)-Step(0, rSamp * 47), 10 ' plot wave
    Next
    View

    Display
End Sub


' Initializes, loads and plays a MIDI file
' Also checks for input, shows info etc
Function PlayMIDITune~%% (fileName As String)
    PlayMIDITune = EVENT_PLAY ' default event is to play next song

    If Not MIDI_LoadTuneFromMemory(LoadFile(fileName)) Then
        MessageBox APP_NAME, "Failed to load: " + fileName, "error"
        Exit Function
    End If

    ' Set the app title to display the file name
    Title APP_NAME + " - " + GetFileNameFromPathOrURL(fileName)

    MIDI_StartPlayer

    Dim k As Long

    Do
        MIDI_UpdatePlayer AUDIO_BUFFER_TIME
        DrawInfoScreen

        k = KeyHit

        Select Case k
            Case KEY_SPACE_BAR
                MIDI_SetPause Not MIDI_IsPaused

            Case KEY_PLUS, KEY_EQUALS ' + = volume up
                MIDI_SetVolume MIDI_GetVolume + 0.01
                If MIDI_GetVolume > MIDI_VOLUME_MAX Then MIDI_SetVolume MIDI_VOLUME_MAX

            Case KEY_MINUS, KEY_UNDERSCORE ' - _ volume down
                MIDI_SetVolume MIDI_GetVolume - 0.01
                If MIDI_GetVolume < MIDI_VOLUME_MIN Then MIDI_SetVolume MIDI_VOLUME_MIN

            Case KEY_UPPER_L, KEY_LOWER_L
                MIDI_SetLooping Not MIDI_IsLooping

            Case KEY_F1
                PlayMIDITune = EVENT_LOAD
                Exit Do

            Case 21248 ' shift + delete - you know what this does :)
                If MessageBox(APP_NAME, "Are you sure you want to delete " + fileName + " permanently?", "yesno", "question", 0) = 1 Then
                    Kill fileName
                    k = KEY_ESCAPE
                End If
        End Select

        If TotalDroppedFiles > 0 Then
            PlayMIDITune = EVENT_DROP
            Exit Do
        End If

        Limit FRAME_RATE_MAX
    Loop Until Not MIDI_IsPlaying Or k = KEY_ESCAPE

    MIDI_StopPlayer

    Title APP_NAME + " " + OS$ ' Set app title to the way it was
End Function


' Welcome screen loop
Function DoWelcomeScreen~%%
    Dim k As Long
    Dim e As Unsigned Byte: e = EVENT_NONE


    Do
        Cls , 0 ' clear the framebuffer to black color

        DrawWeirdPlasma ' XD

        Locate 1, 1
        Color 12, 0
        If Timer Mod 7 = 0 Then
            Print "         ,-.   ,-.   ,-.    ,.   .   , , ,-.  ,   ;-.  .                   (+_+)"
        ElseIf Timer Mod 13 = 0 Then
            Print "         ,-.   ,-.   ,-.    ,.   .   , , ,-.  ,   ;-.  .                   (*_*)"
        Else
            Print "         ,-.   ,-.   ,-.    ,.   .   , , ,-.  ,   ;-.  .                   (�_�)"
        End If
        Print "        /   \  |  ) /      / |   |\ /| | |  \ |   |  ) |                        "
        Color 15
        Print "        |   |  |-<  |,-.  '--|   | V | | |  | |   |-'  | ,-: . . ,-. ;-.        "
        Print "        \   X  |  ) (   )    |   |   | | |  / |   |    | | | | | |-' |          "
        Color 10
        Print "_._______`-' ` `-'   `-'     '   '   ' ' `-'  '   '    ' `-` `-| `-' '________._"
        Print " |                                                           `-'              | "
        Print " |                                                                            | "
        Print " |                                                                            | "
        Color 14
        Print " |                     ";: Color 11: Print "F1";: Color 7: Print " ............ ";: Color 13: Print "MULTI-SELECT FILES";: Color 14: Print "                     | "
        Print " |                                                                            | "
        Print " |                     ";: Color 11: Print "ESC";: Color 7: Print " .................... ";: Color 13: Print "NEXT/QUIT";: Color 14: Print "                     | "
        Print " |                                                                            | "
        Print " |                     ";: Color 11: Print "SPC";: Color 7: Print " ........................ ";: Color 13: Print "PAUSE";: Color 14: Print "                     | "
        Print " |                                                                            | "
        Print " |                     ";: Color 11: Print "=|+";: Color 7: Print " .............. ";: Color 13: Print "INCREASE VOLUME";: Color 14: Print "                     | "
        Print " |                                                                            | "
        Print " |                     ";: Color 11: Print "-|_";: Color 7: Print " .............. ";: Color 13: Print "DECREASE VOLUME";: Color 14: Print "                     | "
        Print " |                                                                            | "
        Print " |                     ";: Color 11: Print "L|l";: Color 7: Print " ......................... ";: Color 13: Print "LOOP";: Color 14: Print "                     | "
        Print " |                                                                            | "
        Print " |                     ";: Color 11: Print "F|f";: Color 7: Print " ............. ";: Color 13: Print "FM SYNTHESIS ["; Chr$(78 + (-useFMSynth * 11)); "]";: Color 14: Print "                     | "
        Print " |                                                                            | "
        Print " |                                                                            | "
        Print " |   ";: Color 15: Print "DRAG AND DROP MULTIPLE FILES ON THIS WINDOW TO PLAY THEM SEQUENTIALLY.";: Color 14: Print "   | "
        Print " | ";: Color 15: Print "YOU CAN ALSO START THE PROGRAM WITH MULTIPLE FILES FROM THE COMMAND LINE.";: Color 14: Print "  | "
        Print " |    ";: Color 15: Print "THIS WAS WRITTEN IN QB64 AND THE SOURCE CODE IS AVAILABLE ON GITHUB.";: Color 14: Print "    | "
        Print " |                 ";: Color 15: Print "https://github.com/a740g/QB64-MIDI-Player";: Color 14: Print "                  | "
        Print "_|_                                                                          _|_"
        Print " `/__________________________________________________________________________\' ";

        k = KeyHit

        If k = KEY_ESCAPE Then
            e = EVENT_QUIT
        ElseIf TotalDroppedFiles > 0 Then
            e = EVENT_DROP
        ElseIf k = KEY_F1 Then
            e = EVENT_LOAD
        ElseIf k = KEY_UPPER_F Or k = KEY_LOWER_F Then
            useFMSynth = Not useFMSynth
            RebootMIDILibrary
        End If

        Display ' flip the framebuffer

        Limit FRAME_RATE_MAX
    Loop While e = EVENT_NONE

    DoWelcomeScreen = e
End Function


' Processes the command line one file at a time
Function ProcessCommandLine~%%
    Dim i As Unsigned Long
    Dim e As Unsigned Byte: e = EVENT_NONE

    If GetProgramArgumentIndex(KEY_QUESTION_MARK) > 0 Then
        MessageBox APP_NAME, APP_NAME + String$(2, KEY_ENTER) + _
        "Syntax: MIDIPlayer64 [-?] [midifile1.mid] [midifile2.mid] ..." + Chr$(KEY_ENTER) + _
        "    -?: Shows this message" + String$(2, KEY_ENTER) + _
        "Copyright (c) 2023, Samuel Gomes" + String$(2, KEY_ENTER) + _
        "https://github.com/a740g/", "info"

        e = EVENT_QUIT
    Else
        For i = 1 To CommandCount
            e = PlayMIDITune(Command$(i))
            If e <> EVENT_PLAY Then Exit For
        Next
    End If

    ProcessCommandLine = e
End Function


' Processes dropped files one file at a time
Function ProcessDroppedFiles~%%
    ' Make a copy of the dropped file and clear the list
    ReDim fileNames(1 To TotalDroppedFiles) As String
    Dim i As Unsigned Long
    Dim e As Unsigned Byte: e = EVENT_NONE

    For i = 1 To TotalDroppedFiles
        fileNames(i) = DroppedFile(i)
    Next
    FinishDrop ' This is critical

    ' Now play the dropped file one at a time
    For i = LBound(fileNames) To UBound(fileNames)
        e = PlayMIDITune(fileNames(i))
        If e <> EVENT_PLAY Then Exit For
    Next

    ProcessDroppedFiles = e
End Function


' Processes a list of files selected by the user
Function ProcessSelectedFiles~%%
    Dim ofdList As String
    Dim e As Unsigned Byte: e = EVENT_NONE

    ofdList = OpenFileDialog$(APP_NAME, , "*.mid|*.MID|*.Mid|*.midi|*.MIDI|*.Midi", "Standard MIDI Files", TRUE)

    If ofdList = NULLSTRING Then Exit Function

    ReDim fileNames(0 To 0) As String
    Dim As Long i, j

    j = ParseOpenFileDialogList(ofdList, fileNames())

    For i = 0 To j - 1
        e = PlayMIDITune(fileNames(i))
        If e <> EVENT_PLAY Then Exit For
    Next

    ProcessSelectedFiles = e
End Function
'-----------------------------------------------------------------------------------------------------------------------

'-----------------------------------------------------------------------------------------------------------------------
' MODULE FILES
'-----------------------------------------------------------------------------------------------------------------------
'$Include:'include/ProgramArgs.bas'
'$Include:'include/FileOps.bas'
'$Include:'include/MIDIPlayer.bas'
'-----------------------------------------------------------------------------------------------------------------------
'-----------------------------------------------------------------------------------------------------------------------

