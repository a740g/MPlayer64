'-----------------------------------------------------------------------------------------------------
' QB64 MIDI Player
' Copyright (c) 2023 Samuel Gomes
'-----------------------------------------------------------------------------------------------------

'-----------------------------------------------------------------------------------------------------
' HEADER FILES
'-----------------------------------------------------------------------------------------------------
'$Include:'include/MIDIPlayer.bi'
'-----------------------------------------------------------------------------------------------------

'-----------------------------------------------------------------------------------------------------
' METACOMMANDS
'-----------------------------------------------------------------------------------------------------
$ExeIcon:'./QB64MIDPlayer.ico'
$VersionInfo:CompanyName=Samuel Gomes
$VersionInfo:FileDescription=MIDI Player executable
$VersionInfo:InternalName=QB64MIDIPlayer'
$VersionInfo:LegalCopyright=Copyright (c) 2023, Samuel Gomes
$VersionInfo:LegalTrademarks=All trademarks are property of their respective owners
$VersionInfo:OriginalFilename=QB64MIDPlayer.exe
$VersionInfo:ProductName=QB64 MIDI Player
$VersionInfo:Web=https://github.com/a740g
$VersionInfo:Comments=https://github.com/a740g
$VersionInfo:FILEVERSION#=2,0,0,0
$VersionInfo:PRODUCTVERSION#=2,0,0,0
'-----------------------------------------------------------------------------------------------------

'-----------------------------------------------------------------------------------------------------
' CONSTANTS
'-----------------------------------------------------------------------------------------------------
Const APP_NAME = "QB64 MIDI Player"
Const FRAME_RATE_MAX = 120
'-----------------------------------------------------------------------------------------------------

'-----------------------------------------------------------------------------------------------------
' PROGRAM ENTRY POINT
'-----------------------------------------------------------------------------------------------------
Title APP_NAME + " " + OS$ ' Set the program name in the titlebar
ChDir StartDir$ ' Change to the directory specifed by the environment
AcceptFileDrop ' Enable drag and drop of files
Screen 12 ' Use 640x480 resolution
AllowFullScreen SquarePixels , Smooth ' All the user to press Alt+Enter to go fullscreen
Display ' Only swap buffer when we want

' Initialize TSF
If Not MIDI_Initialize(FALSE) Then
    Print
    Print "Error: Failed to initialize the TSF library!"
    Display
    End
End If

ProcessCommandLine ' Check if any files were specified in the command line

Dim k As Long

' Main loop
Do
    ProcessDroppedFiles
    PrintWelcomeScreen
    k = KeyHit
    Display
    Limit FRAME_RATE_MAX
Loop Until k = KEY_ESCAPE

' Shutdown TSF
MIDI_Finalize

System
'-----------------------------------------------------------------------------------------------------

'-----------------------------------------------------------------------------------------------------
' FUNCTIONS & SUBROUTINES
'-----------------------------------------------------------------------------------------------------
' Initializes, loads and plays a MIDI file
' Also checks for input, shows info etc
Sub PlaySong (fileName As String)
    If Not MIDI_LoadTuneFromFile(fileName) Then
        Color 12
        Print: Print "Failed to load "; fileName; "!"
        Display
        Sleep 5
        Exit Sub
    End If

    ' Set the app title to display the file name
    Title APP_NAME + " - " + GetFileNameFromPath(fileName)

    Cls

    MIDI_StartPlayer

    Dim k As Long

    Do
        MIDI_UpdatePlayer

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

            Case 21248 ' shift + delete - you know what this does :)
                If MessageBox(APP_NAME, "Are you sure you want to delete " + fileName + " permanently?", "yesno", "question", 0) = 1 Then
                    Kill fileName
                    k = KEY_ESCAPE
                End If
        End Select

        DrawInfoScreen

        Display

        Limit FRAME_RATE_MAX
    Loop Until Not MIDI_IsPlaying Or k = KEY_ESCAPE Or TotalDroppedFiles > 0

    MIDI_StopPlayer

    Title APP_NAME + " " + OS$ ' Set app title to the way it was
End Sub


' Draws the screen during playback
Sub DrawInfoScreen
    Shared __MIDI_Player As __MIDI_PlayerType

    Dim As Unsigned Long nsf, x
    Dim As Single lSamp, rSamp
    Dim As String minute, second

    If MIDI_IsPaused Or Not MIDI_IsPlaying Then Color 12 Else Color 7

    Locate 22, 43: Print "Buffered sound:"; SndRawLen(__MIDI_Player.soundHandle) * 1000; "ms";
    Locate 23, 43: Print "        Voices:"; MIDI_GetActiveVoices;
    Locate 24, 43: Print Using "Current volume: ###%"; MIDI_GetVolume * 100;
    minute = Right$("00" + LTrim$(Str$((MIDI_GetCurrentTime + 500) \ 60000)), 2)
    second = Right$("00" + LTrim$(Str$(((MIDI_GetCurrentTime + 500) \ 1000) Mod 60)), 2)
    Locate 25, 43: Print Using "  Elapsed time: &:& (mm:ss)"; minute; second
    minute = Right$("00" + LTrim$(Str$((MIDI_GetTotalTime + 500) \ 60000)), 2)
    second = Right$("00" + LTrim$(Str$(((MIDI_GetTotalTime + 500) \ 1000) Mod 60)), 2)
    Locate 26, 43: Print Using "    Total time: &:& (mm:ss)"; minute; second

    Color 9
    Locate 22, 7: Print "ESC - NEXT / QUIT"
    Locate 23, 7: Print "SPC - PLAY / PAUSE"
    Locate 24, 7: Print "=|+ - INCREASE VOLUME"
    Locate 25, 7: Print "-|_ - DECREASE VOLUME"
    Locate 26, 7: Print "L|l - LOOP"

    ' Animate wave form oscillators
    ' As the oscillators width is probably <> number of samples, we need to scale the x-position, same is with the amplitude (y-position)

    nsf = __MIDI_Player.soundBufferSize \ __MIDI_SOUND_BUFFER_FRAME_SIZE 'number of sample frames in the buffer

    Color 7: PrintString (224, 32), "Left Channel (Wave plot)"
    Color 2: PrintString (20, 32), "0 [ms]"
    Color 2: PrintString (556, 32), Left$(Str$(nsf * 1000 \ SndRate), 6) + " [ms]"
    View (20, 48)-(620, 144), 0, 7 ' set a viewport to draw to so that even if we draw outside it gets clipped

    For x = 0 To nsf - 1
        lSamp = MemGet(__MIDI_Player.soundBuffer, __MIDI_Player.soundBuffer.OFFSET + x * __MIDI_SOUND_BUFFER_FRAME_SIZE, Single) ' get left channel sample
        Line (x * 601 \ nsf, 47)-Step(0, lSamp * 47), 10 ' plot wave
    Next

    View

    Color 7: PrintString (220, 160), "Right Channel (Wave plot)"
    Color 2: PrintString (20, 160), "0 [ms]"
    Color 2: PrintString (556, 160), Left$(Str$(nsf * 1000 \ SndRate), 6) + " [ms]"
    View (20, 176)-(620, 272), 0, 7 ' set a viewport to draw to so that even if we draw outside it gets clipped

    For x = 0 To nsf - 1
        rSamp = MemGet(__MIDI_Player.soundBuffer, __MIDI_SOUND_BUFFER_SAMPLE_SIZE + __MIDI_Player.soundBuffer.OFFSET + x * __MIDI_SOUND_BUFFER_FRAME_SIZE, Single) ' get right channel sample
        Line (x * 601 \ nsf, 47)-Step(0, rSamp * 47), 10 ' plot wave
    Next

    View
End Sub


' Prints the welcome screen
Sub PrintWelcomeScreen
    Cls
    Locate 1, 1
    Color 12, 0
    If Timer Mod 7 = 0 Then
        Print "         ,-.   ,-.   ,-.    ,.   .   , , ,-.  ,   ;-.  .                   (+_+)"
    ElseIf Timer Mod 13 = 0 Then
        Print "         ,-.   ,-.   ,-.    ,.   .   , , ,-.  ,   ;-.  .                   (*_*)"
    Else
        Print "         ,-.   ,-.   ,-.    ,.   .   , , ,-.  ,   ;-.  .                   (ù_ù)"
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
    Print " |                                                                            | "
    Print " |                     ";: Color 11: Print "ESC";: Color 8: Print " .................... ";: Color 13: Print "NEXT/QUIT";: Color 14: Print "                     | "
    Print " |                                                                            | "
    Print " |                     ";: Color 11: Print "SPC";: Color 8: Print " ........................ ";: Color 13: Print "PAUSE";: Color 14: Print "                     | "
    Print " |                                                                            | "
    Print " |                     ";: Color 11: Print "=|+";: Color 8: Print " .............. ";: Color 13: Print "INCREASE VOLUME";: Color 14: Print "                     | "
    Print " |                                                                            | "
    Print " |                     ";: Color 11: Print "-|_";: Color 8: Print " .............. ";: Color 13: Print "DECREASE VOLUME";: Color 14: Print "                     | "
    Print " |                                                                            | "
    Print " |                     ";: Color 11: Print "L|l";: Color 8: Print " ......................... ";: Color 13: Print "LOOP";: Color 14: Print "                     | "
    Print " |                                                                            | "
    Print " |                                                                            | "
    Print " |   ";: Color 9: Print "DRAG AND DROP MULTIPLE FILES ON THIS WINDOW TO PLAY THEM SEQUENTIALLY.";: Color 14: Print "   | "
    Print " |                                                                            | "
    Print " | ";: Color 9: Print "YOU CAN ALSO START THE PROGRAM WITH MULTIPLE FILES FROM THE COMMAND LINE.";: Color 14: Print "  | "
    Print " |                                                                            | "
    Print " |    ";: Color 9: Print "THIS WAS WRITTEN IN QB64 AND THE SOURCE CODE IS AVAILABLE ON GITHUB.";: Color 14: Print "    | "
    Print " |                                                                            | "
    Print " |                 ";: Color 9: Print "https://github.com/a740g/QB64-MIDI-Player";: Color 14: Print "                  | "
    Print "_|_                                                                          _|_"
    Print " `/__________________________________________________________________________\' ";
End Sub


' Processes the command line one file at a time
Sub ProcessCommandLine
    Dim i As Unsigned Long

    For i = 1 To CommandCount
        PlaySong Command$(i)
        If TotalDroppedFiles > 0 Then Exit For ' Exit the loop if we have dropped files
    Next
End Sub


' Processes dropped files one file at a time
Sub ProcessDroppedFiles
    If TotalDroppedFiles > 0 Then
        ' Make a copy of the dropped file and clear the list
        ReDim fileNames(1 To TotalDroppedFiles) As String
        Dim i As Unsigned Long

        For i = 1 To TotalDroppedFiles
            fileNames(i) = DroppedFile(i)
        Next
        FinishDrop ' This is critical

        ' Now play the dropped file one at a time
        For i = LBound(fileNames) To UBound(fileNames)
            PlaySong fileNames(i)
            If TotalDroppedFiles > 0 Then Exit For ' Exit the loop if we have dropped files
        Next
    End If
End Sub


' Gets the filename portion from a file path
Function GetFileNameFromPath$ (pathName As String)
    Dim i As Unsigned Long

    ' Retrieve the position of the first / or \ in the parameter from the
    For i = Len(pathName) To 1 Step -1
        If Asc(pathName, i) = 47 Or Asc(pathName, i) = 92 Then Exit For
    Next

    ' Return the full string if pathsep was not found
    If i = 0 Then
        GetFileNameFromPath = pathName
    Else
        GetFileNameFromPath = Right$(pathName, Len(pathName) - i)
    End If
End Function
'-----------------------------------------------------------------------------------------------------

'-----------------------------------------------------------------------------------------------------
' MODULE FILES
'-----------------------------------------------------------------------------------------------------
'$Include:'include/MIDIPlayer.bas'
'-----------------------------------------------------------------------------------------------------
'-----------------------------------------------------------------------------------------------------

