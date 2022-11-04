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

## Important notes

- MIDI support is built into [QB64-PE v3.2.0+](https://github.com/QB64-Phoenix-Edition/QB64pe/releases/) using [miniaudio](https://miniaud.io/), [TinySoundFont](https://github.com/schellingb/TinySoundFont), and [TinyMidiLoader](https://github.com/schellingb/TinySoundFont)
- This is not required with versions of [QB64-PE](https://github.com/QB64-Phoenix-Edition/QB64pe/releases/) >= v3.2.0 with the default miniaudio backend selected
- This will only compile with [QB64-PE v3.2.0+](https://github.com/QB64-Phoenix-Edition/QB64pe/releases/) if [$MIDISOUNDFONT](https://qb64phoenix.com/qb64wiki/index.php/$MIDISOUNDFONT) is not used
- This will not compile with some version of QB64 or may produce poor audio quality due to audio mixing & clipping bugs in those versions
