'---------------------------------------------------------------------------------------------------------
' QB64 MIDI Player Library
' Copyright (c) 2022 Samuel Gomes
'
' This uses TinySoundFont + TinyMidiLoader libraries from https://github.com/schellingb/TinySoundFont
'---------------------------------------------------------------------------------------------------------

'---------------------------------------------------------------------------------------------------------
' HEADER FILES
'---------------------------------------------------------------------------------------------------------
'$Include:'./MIDIPlayer.bi'
'---------------------------------------------------------------------------------------------------------

$If MIDIPLAYER_BAS = UNDEFINED Then
    $Let MIDIPLAYER_BAS = TRUE
    '-----------------------------------------------------------------------------------------------------
    ' Small test code for debugging the library
    '-----------------------------------------------------------------------------------------------------
    '$Debug
    'If TSFInitialize Then
    '    If TSFLoadFile("C:\Users\samue\OneDrive\repos\QB64-MIDI-Player\midis\COLDWAVE.mid") Then
    '        TSFStartPlayer
    '        TSFSetIsLooping TRUE
    '        Do
    '            TSFUpdatePlayer
    '            Select Case KeyHit
    '                Case 27
    '                    Exit Do
    '                Case 32
    '                    TSFPlayer.isPaused = Not TSFPlayer.isPaused
    '            End Select
    '            Locate 1, 1: Print Using "Time: ########.## / ########.##   Voices: ####"; TSFGetCurrentTime; TSFGetTotalTime; TSFGetActiveVoices;
    '            Limit 60
    '        Loop While TSFIsPlaying
    '        TSFStopPlayer
    '    End If
    '    TSFFinalize
    'End If
    'End
    '-----------------------------------------------------------------------------------------------------

    '-----------------------------------------------------------------------------------------------------
    ' FUNCTIONS & SUBROUTINES
    '-----------------------------------------------------------------------------------------------------
    ' This checks and initializes the underlying C library
    Function TSFInitialize&
        ' Exit if we are already initialized
        If TSFIsInitialized Then
            TSFInitialize = TRUE
            Exit Function
        End If

        ' Assume failure
        TSFInitialize = FALSE

        If __TSFInitialize(SndRate) Then
            ' Allocate the mixer buffer
            TSFPlayer.soundBufferSize = (SndRate \ 40) * TSF_SOUND_BUFFER_FRAME_SIZE
            TSFPlayer.soundBuffer = MemNew(TSFPlayer.soundBufferSize)

            ' Exit if memory was not allocated
            If TSFPlayer.soundBuffer.SIZE = 0 Then
                TSFFinalize
                Exit Function
            End If

            ' Allocate a sound pipe
            TSFPlayer.soundHandle = SndOpenRaw

            TSFInitialize = TRUE
        End If
    End Function


    ' The closes the library and frees all resources
    Sub TSFFinalize
        If TSFIsInitialized Then
            ' Free the sound pipe
            SndRawDone TSFPlayer.soundHandle ' Sumbit whatever is remaining in the raw buffer for playback
            SndClose TSFPlayer.soundHandle ' Close QB64 sound pipe

            ' Free the mixer buffer
            MemFree TSFPlayer.soundBuffer

            ' Call the C side finalizer
            __TSFFinalize
        End If
    End Sub


    ' Loads a file for playback
    Function TSFLoadFile%% (midi_filename As String)
        TSFLoadFile = __TSFLoadFile(midi_filename + Chr$(NULL))
    End Function


    ' This handles playback and keeping track of the render buffer
    ' You can call this as frequenctly as you want. The routine will simply exit if nothing is to be done
    Sub TSFUpdatePlayer
        ' Only render more samples if song is playing, not paused and we do not have enough samples with the sound device
        If TSFIsPlaying And Not TSFPlayer.isPaused And SndRawLen(TSFPlayer.soundHandle) < TSF_SOUND_TIME_MIN Then

            ' Clear the render buffer
            MemFill TSFPlayer.soundBuffer, TSFPlayer.soundBuffer.OFFSET, TSFPlayer.soundBufferSize, NULL As BYTE

            ' Render some samples to the buffer
            __TSFRender TSFPlayer.soundBuffer.OFFSET, TSFPlayer.soundBufferSize

            ' Push the samples to the sound pipe
            Dim i As Long
            For i = 0 To TSFPlayer.soundBufferSize - TSF_SOUND_BUFFER_SAMPLE_SIZE Step TSF_SOUND_BUFFER_FRAME_SIZE
                SndRaw MemGet(TSFPlayer.soundBuffer, TSFPlayer.soundBuffer.OFFSET + i, Integer) / 32768!, MemGet(TSFPlayer.soundBuffer, TSFPlayer.soundBuffer.OFFSET + i + TSF_SOUND_BUFFER_SAMPLE_SIZE, Integer) / 32768!, TSFPlayer.soundHandle
            Next
        End If
    End Sub
    '-----------------------------------------------------------------------------------------------------
$End If
'---------------------------------------------------------------------------------------------------------

