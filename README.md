# What is this?

This is a [QB64-PE](https://github.com/QB64-Phoenix-Edition/QB64pe) compatible MIDI player library based on [TinySoundFont](https://github.com/schellingb/TinySoundFont) (a software synthesizer using SoundFont2) and [TinyMidiLoader](https://github.com/schellingb/TinySoundFont) (a minimalistic SMF parser) C single-header libraries.

![Screenshot](screenshots/Screenshot1.png)
![Screenshot](screenshots/Screenshot2.png)

## Features

- Easy plug-&-play API optimized for demos & games
- Works with the 64-bit QB64 complier
- Cross-platform (works on Windows, Linux & macOS)
- Everything is statically linked (no DLL dependency)
- Demo player that shows how to use the library

## API

```VB
Function TSFInitialize&
Function TSFIsInitialized&
Sub TSFFinalize
Function TSFLoadFile%% (sFilename As String)
Function TSFIsFileLoaded&
Sub TSFStartPlayer
Function TSFIsPlaying&
Function TSFGetIsLooping&
Sub TSFSetIsLooping (nLooping As Long)
Sub TSFStopPlayer
Function TSFGetVolume&
Sub TSFSetVolume (nVolume As Long)
Function TSFGetTotalTime#
Function TSFGetCurrentTime#
Function TSFGetActiveVoices&
Sub TSFUpdatePlayer
```

## Icon

[Icon](https://iconarchive.com/artist/studiomx.html) by Maximilian Novikov

## Important note

MIDI support will be built into [QB64-PE v3.1.0+](https://github.com/QB64-Phoenix-Edition/QB64pe). The [miniaudio](https://miniaud.io/) backend in this version of OB64-PE uses [TinySoundFont](https://github.com/schellingb/TinySoundFont) and [TinyMidiLoader](https://github.com/schellingb/TinySoundFont). So, this will not compile with version of [QB64-PE](https://github.com/QB64-Phoenix-Edition/QB64pe/releases/) >= v3.1.0 with the default miniaudio backend selected. Use this only with QB64 and QB64-PE with OpenAL backend.
