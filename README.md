# MIDI PLAYER 64

This is a [QB64-PE](https://github.com/QB64-Phoenix-Edition/QB64pe) MIDI player and library based on [TinySoundFont](https://github.com/schellingb/TinySoundFont) (a software synthesizer using SoundFont2) and [TinyMidiLoader](https://github.com/schellingb/TinySoundFont) (a minimalistic SMF parser) C single-header libraries.

![Screenshot](screenshots/Screenshot1.png)
![Screenshot](screenshots/Screenshot2.png)

## FEATURES

- Easy plug-&-play API optimized for demos & games
- Cross-platform (works on Windows, Linux & macOS)
- Everything is statically linked (no shared library dependency)
- Demo player that shows how to use the library
- Experimental OPL3 emulation

## USAGE

- Clone the repository to a directory of your choice
- Open Terminal and change to the directory using an appropriate OS command
- Run `git submodule update --init --recursive` to initialize, fetch and checkout git submodules
- Open *MIDIPlayer64.bas* in the QB64-PE IDE and press `F5` to compile and run
- To use the library in your project add the [Toolbox64](https://github.com/a740g/Toolbox64) repositiory as a [Git submodule](https://git-scm.com/book/en/v2/Git-Tools-Submodules)

## API

```VB
Function MIDI_Initialize& (useFM As Byte)
Function MIDI_IsInitialized&
Sub MIDI_Finalize
Function MIDI_LoadTuneFromFile%% (fileName As String)
Function MIDI_LoadTuneFromMemory%% (buffer As String)
Function MIDI_IsTuneLoaded&
Sub MIDI_StartPlayer
Sub MIDI_StopPlayer
Function MIDI_IsPlaying&
Sub MIDI_SetLooping (ByVal isLooping As Long)
Function MIDI_IsLooping&
Sub MIDI_SetPause (isPaused As Byte)
Function MIDI_IsPaused%%
Sub MIDI_SetVolume (ByVal volume As Single)
Function MIDI_GetVolume!
Function MIDI_GetTotalTime#
Function MIDI_GetCurrentTime#
Function MIDI_GetActiveVoices~&
Sub MIDI_UpdatePlayer (bufferTime As Single)
```

## NOTES

- This requires the latest version of [QB64-PE](https://github.com/QB64-Phoenix-Edition/QB64pe/releases)
- Mixing this with QB64-PE's [$MIDISOUNDFONT](https://qb64phoenix.com/qb64wiki/index.php/$MIDISOUNDFONT) will not work
- When you clone a repository that contains submodules, the submodules are not automatically cloned by default
- You will need to use the `git submodule update --init --recursive` to initialize, fetch and checkout git submodules

## ASSETS

[Icon](https://iconarchive.com/artist/studiomx.html) by Maximilian Novikov
