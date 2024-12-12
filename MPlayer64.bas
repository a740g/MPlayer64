': QB64-PE Audio Player
': Copyright (c) 2024 Samuel Gomes
':
': This program uses
': InForm GUI engine for QB64-PE - v1.5.6
': Fellippe Heitor, (2016 - 2022) - @FellippeHeitor
': Samuel Gomes, (2023 - 2024) - @a740g
': https://github.com/a740g/InForm-PE
'-----------------------------------------------------------

_DEFINE A-Z AS LONG
OPTION _EXPLICIT
$COLOR:32
$EXEICON:'./MPlayer64.ico'
$VERSIONINFO:CompanyName='Samuel Gomes'
$VERSIONINFO:FileDescription='MPlayer64 executable'
$VERSIONINFO:InternalName='MPlayer64'
$VERSIONINFO:LegalCopyright='Copyright (c) 2024, Samuel Gomes'
$VERSIONINFO:LegalTrademarks='All trademarks are property of their respective owners'
$VERSIONINFO:OriginalFilename='MPlayer64.exe'
$VERSIONINFO:ProductName='MPlayer64'
$VERSIONINFO:Web='https://github.com/a740g'
$VERSIONINFO:Comments='https://github.com/a740g'
$VERSIONINFO:FILEVERSION#=4,0,1,0
$VERSIONINFO:PRODUCTVERSION#=4,0,1,0

CONST APP_NAME = "MPlayer64"

$IF WINDOWS THEN
    CONST MIDI_SOUNDBANK_FILE_FILTERS = "*.wopl|*.op2|*.tmb|*.ad|*.opl|*.sf2|*.sf3|*.sfo|*.dll"
    CONST AUDIO_FILE_FILTERS =  "*.wav|*.aiff|*.aifc|*.flac|*.ogg|*.mp3|*.it|*.xm|*.s3m|*.mod|*.rad|*.ahx|*.hvl|" + _
                                "*.mus|*.hmi|*.hmp|*.hmq|*.kar|*.lds|*.mds|*.mids|*.rcp|*.r36|*.g18|*.g36|*.rmi|" + _
                                "*.mid|*.midi|*.xfm|*.xmi|*.qoa"
$ELSE
    CONST MIDI_SOUNDBANK_FILE_FILTERS = "*.wopl|*.op2|*.tmb|*.ad|*.opl|*.sf2|*.sf3|*.sfo|" + _
                                        "*.WOPL|*.OP2|*.TMB|*.AD|*.OPL|*.SF2|*.SF3|*.SFO"
    CONST AUDIO_FILE_FILTERS =  "*.wav|*.aiff|*.aifc|*.flac|*.ogg|*.mp3|*.it|*.xm|*.s3m|*.mod|*.rad|*.ahx|*.hvl|" + _
                                "*.mus|*.hmi|*.hmp|*.hmq|*.kar|*.lds|*.mds|*.mids|*.rcp|*.r36|*.g18|*.g36|*.rmi|" + _
                                "*.mid|*.midi|*.xfm|*.xmi|*.qoa|*.WAV|*.AIFF|*.AIFC|*.FLAC|*.OGG|*.MP3|*.IT|*.XM|" + _
                                "*.S3M|*.MOD|*.RAD|*.AHX|*.HVL|*.MUS|*.HMI|*.HMP|*.HMQ|*.KAR|*.LDS|*.MDS|*.MIDS|" + _
                                "*.RCP|*.R36|*.G18|*.G36|*.RMI|*.MID|*.MIDI|*.XFM|*.XMI|*.QOA"
$END IF

REDIM SHARED PlaylistFiles(0) AS STRING
DIM SHARED AppTitle AS STRING
DIM SHARED Media AS LONG
DIM SHARED IsPlaying AS _BYTE
DIM SHARED AnalyzerStyle AS _UNSIGNED _BYTE

': Controls' IDs: ------------------------------------------------------------------
DIM SHARED ClearBT AS LONG
DIM SHARED PreviousBT AS LONG
DIM SHARED VMBT AS LONG
DIM SHARED VPBT AS LONG
DIM SHARED SeekTrackBar AS LONG
DIM SHARED VolumeProgressBar AS LONG
DIM SHARED PlayListBox AS LONG
DIM SHARED OpenBT AS LONG
DIM SHARED VisualBT AS LONG
DIM SHARED PlayBT AS LONG
DIM SHARED PauseBT AS LONG
DIM SHARED NextBT AS LONG
DIM SHARED SoundbankBT AS LONG
DIM SHARED AboutBT AS LONG
DIM SHARED MPlayer64 AS LONG
DIM SHARED InfoFrame AS LONG
DIM SHARED VisLPictureBox AS LONG
DIM SHARED VisRPictureBox AS LONG
DIM SHARED TimeLabel AS LONG

': External modules: ---------------------------------------------------------------
'$INCLUDE:'toolbox64/AudioAnalyzer.bi'
'$INCLUDE:'inform-pe/InForm/extensions/Pathname.bi'
'$INCLUDE:'inform-pe/InForm/InForm.bi'
'$INCLUDE:'inform-pe/InForm/xp.uitheme'
'$INCLUDE:'MPlayer64.frm'
'$INCLUDE:'inform-pe/InForm/InForm.ui'
'$INCLUDE:'inform-pe/InForm/extensions/Pathname.bas'
'$INCLUDE:'toolbox64/AudioAnalyzer.bas'

': User procedures: ----------------------------------------------------------------
SUB Playlist_AddCommandLineList
    DIM i AS _UNSIGNED LONG: FOR i = 1 TO _COMMANDCOUNT
        Playlist_AddFile COMMAND$(i)
    NEXT

    Playlist_UpdateUI
END SUB

SUB Playlist_AddOpenFileDialogList
    DIM ofdList AS STRING: ofdList = _OPENFILEDIALOG$(APP_NAME + " - Multi-select audio files...", , AUDIO_FILE_FILTERS, , True)

    IF LEN(ofdList) THEN
        DO
            DIM p AS _UNSIGNED LONG: p = INSTR(ofdList, "|")

            IF p THEN
                Playlist_AddFile LEFT$(ofdList, p - 1)
                ofdList = MID$(ofdList, p + 1)
            ELSE
                Playlist_AddFile ofdList
                EXIT DO
            END IF
        LOOP

        Playlist_UpdateUI
    END IF
END SUB

SUB Playlist_AddFile (fileName AS STRING)
    IF _FILEEXISTS(fileName) THEN
        DIM UB AS _UNSIGNED LONG: UB = UBOUND(PlaylistFiles) + 1
        REDIM _PRESERVE PlaylistFiles(1 TO UB) AS STRING
        PlaylistFiles(UB) = fileName

        Control(PlayListBox).Disabled = False
        IF Control(PlayListBox).Value = 0 THEN Control(PlayListBox).Value = 1
    END IF
END SUB

SUB Playlist_UpdateUI
    DIM selectedItem AS _UNSIGNED LONG: selectedItem = Control(PlayListBox).Value

    ResetList PlayListBox

    DIM i AS _UNSIGNED LONG: FOR i = 1 TO UBOUND(PlaylistFiles)
        AddItem PlayListBox, Pathname_GetFileName(PlaylistFiles(i))
    NEXT

    Control(PlayListBox).Value = selectedItem

    IF Control(PlayListBox).Value > 0 THEN
        Control(ClearBT).Disabled = False
        Control(PreviousBT).Disabled = False
        Control(PlayBT).Disabled = False
        Control(NextBT).Disabled = False
    ELSE
        Control(ClearBT).Disabled = True
        Control(PreviousBT).Disabled = True
        Control(PlayBT).Disabled = True
        Control(NextBT).Disabled = True
    END IF
END SUB

SUB Playlist_Clear
    Playlist_Stop
    REDIM PlaylistFiles(0) AS STRING
    Control(PlayListBox).Value = 0
    Playlist_UpdateUI
END SUB

SUB Playlist_Play
    Media = _SNDOPEN(PlaylistFiles(Control(PlayListBox).Value))
    IF Media THEN
        IF AudioAnalyzer_Init(Media) THEN
            AudioAnalyzer_SetStyle AnalyzerStyle
            _SNDPLAY Media
            IsPlaying = True
            SetCaption PlayBT, "&Stop"
            Control(PauseBT).Disabled = False
            Control(VisualBT).Disabled = False
            Control(VMBT).Disabled = False
            Control(VPBT).Disabled = False
            Control(SeekTrackBar).Disabled = False
            UpdateAppTitle
        ELSE
            _SNDCLOSE Media
            Media = 0
        END IF
    END IF
END SUB

SUB Playlist_Stop
    IF Media THEN
        AudioAnalyzer_Done
        _SNDSTOP Media
        _SNDCLOSE Media
        Media = 0
        IsPlaying = False
        SetCaption PlayBT, "&Play"
        Control(PauseBT).Disabled = True
        Control(VisualBT).Disabled = True
        Control(VMBT).Disabled = True
        Control(VPBT).Disabled = True
        Control(SeekTrackBar).Disabled = True
        SetCaption TimeLabel, "00:00:00 / 00:00:00"

        BeginDraw VisLPictureBox
        CLS , Black
        EndDraw VisLPictureBox

        BeginDraw VisRPictureBox
        CLS , Black
        EndDraw VisRPictureBox

        UpdateAppTitle
    END IF
END SUB

FUNCTION GetSoundbankType$ (fileName AS STRING)
    DIM ext AS STRING: ext = LCASE$(Pathname_GetFileExtension(fileName))

    SELECT CASE ext
        CASE ".wopl", ".op2", ".tmb", ".ad", ".opl"
            GetSoundbankType = "FM Bank"

        CASE ".sf2", ".sf3", ".sfo"
            GetSoundbankType = "SoundFont"

        CASE ".dll"
            GetSoundbankType = "VSTi"

        CASE ELSE
            GetSoundbankType = "Unknown"
    END SELECT
END FUNCTION

SUB SetNextAnalyzer
    AnalyzerStyle = AnalyzerStyle + 1
    IF AnalyzerStyle >= AUDIOANALYZER_STYLE_COUNT THEN AnalyzerStyle = 0
    AudioAnalyzer_SetStyle AnalyzerStyle
END SUB

SUB UpdateAppTitle
    IF IsPlaying THEN
        SetCaption MPlayer64, GetItem(PlayListBox, Control(PlayListBox).Value) + " - " + AppTitle
    ELSE
        SetCaption MPlayer64, AppTitle
    END IF
END SUB

SUB LoadSoundbank
    DIM bankFileName AS STRING: bankFileName = _OPENFILEDIALOG$(APP_NAME + " - Select MIDI soundbank...", , MIDI_SOUNDBANK_FILE_FILTERS)
    IF LEN(bankFileName) THEN
        _MIDISOUNDBANK bankFileName
        AppTitle = APP_NAME + " [" + GetSoundbankType(bankFileName) + "]"
        UpdateAppTitle
    END IF
END SUB

': Event procedures: ---------------------------------------------------------------
SUB __UI_BeforeInit
    AppTitle = APP_NAME

    CHDIR _STARTDIR$
    _ACCEPTFILEDROP
    RANDOMIZE TIMER

    IF (COMMAND$(1) = "/?" _ORELSE COMMAND$(1) = "-?" _ORELSE COMMAND$(1) = "/h" _ORELSE COMMAND$(1) = "-h" _ORELSE COMMAND$(1) = "--help") THEN
        MessageBox APP_NAME + "\n\nSyntax: " + APP_NAME + " [filespec]\n    /?: Shows this message\n\nNote: Wildcards are supported\n\nCopyright (c) 2024, Samuel Gomes\n\nhttps://github.com/a740g/", APP_NAME, MsgBox_OkOnly OR MsgBox_Information OR MsgBox_AppModal OR MsgBox_SetForeground
    END IF

    AnalyzerStyle = AUDIOANALYZER_STYLE_OSCILLOSCOPE1
END SUB

SUB __UI_OnLoad
    Playlist_AddCommandLineList

    BeginDraw VisLPictureBox
    _PRINTMODE _KEEPBACKGROUND
    COLOR White
    EndDraw VisLPictureBox

    BeginDraw VisRPictureBox
    _PRINTMODE _KEEPBACKGROUND
    COLOR White
    EndDraw VisRPictureBox

    UpdateAppTitle

    SetFrameRate 60
END SUB

SUB __UI_BeforeUpdateDisplay
    'This event occurs at approximately 60 frames per second.
    'You can change the update frequency by calling SetFrameRate DesiredRate%
    IF Media _ANDALSO IsPlaying THEN
        IF _NEGATE _SNDPLAYING(Media) _ANDALSO _NEGATE _SNDPAUSED(Media) THEN
            Playlist_Stop
        ELSE
            AudioAnalyzer_Update

            DIM channels AS _UNSIGNED _BYTE: channels = AudioAnalyzer_GetChannels
            DIM AS _UNSIGNED _BYTE leftChannel, rightChannel
            IF channels > 1 THEN
                leftChannel = 0
                rightChannel = 1
            ELSE
                leftChannel = 0
                rightChannel = 0
            END IF

            BeginDraw VisLPictureBox
            CLS
            AudioAnalyzer_RenderDirect _WIDTH, _HEIGHT, leftChannel
            EndDraw VisLPictureBox

            BeginDraw VisRPictureBox
            CLS
            AudioAnalyzer_RenderDirect _WIDTH, _HEIGHT, rightChannel
            EndDraw VisRPictureBox

            Caption(TimeLabel) = AudioAnalyzer_GetCurrentTimeText + " / " + AudioAnalyzer_GetTotalTimeText
            Control(SeekTrackBar).Value = (AudioAnalyzer_GetCurrentTime / AudioAnalyzer_GetTotalTime) * Control(SeekTrackBar).Max
        END IF
    END IF
END SUB

SUB __UI_BeforeUnload
    'If you set __UI_UnloadSignal = False here you can
    'cancel the user's request to close.

END SUB

SUB __UI_Click (id AS LONG)
    SELECT CASE id
        CASE ClearBT
            Playlist_Clear

        CASE PreviousBT

        CASE VMBT

        CASE VPBT

        CASE SeekTrackBar

        CASE VolumeProgressBar

        CASE PlayListBox

        CASE OpenBT
            Playlist_AddOpenFileDialogList

        CASE VisualBT
            SetNextAnalyzer

        CASE PlayBT
            IF IsPlaying THEN
                Playlist_Stop
            ELSE
                Playlist_Play
            END IF

        CASE PauseBT

        CASE NextBT

        CASE SoundbankBT
            LoadSoundbank

        CASE AboutBT
            MessageBox APP_NAME + "\n\nCopyright (c) 2024, Samuel Gomes\n\nThis was written in QB64-PE and the souce code is available on GitHub.\n\nhttps://github.com/a740g/", APP_NAME, MsgBox_OkOnly OR MsgBox_Information OR MsgBox_AppModal OR MsgBox_SetForeground

        CASE MPlayer64

        CASE InfoFrame

        CASE VisLPictureBox
            SetNextAnalyzer

        CASE VisRPictureBox
            SetNextAnalyzer

        CASE TimeLabel

    END SELECT
END SUB

SUB __UI_MouseEnter (id AS LONG)
    SELECT CASE id
        CASE ClearBT

        CASE PreviousBT

        CASE VMBT

        CASE VPBT

        CASE SeekTrackBar

        CASE VolumeProgressBar

        CASE PlayListBox

        CASE OpenBT

        CASE VisualBT

        CASE PlayBT

        CASE PauseBT

        CASE NextBT

        CASE SoundbankBT

        CASE AboutBT

        CASE MPlayer64

        CASE InfoFrame

        CASE VisLPictureBox

        CASE VisRPictureBox

        CASE TimeLabel

    END SELECT
END SUB

SUB __UI_MouseLeave (id AS LONG)
    SELECT CASE id
        CASE ClearBT

        CASE PreviousBT

        CASE VMBT

        CASE VPBT

        CASE SeekTrackBar

        CASE VolumeProgressBar

        CASE PlayListBox

        CASE OpenBT

        CASE VisualBT

        CASE PlayBT

        CASE PauseBT

        CASE NextBT

        CASE SoundbankBT

        CASE AboutBT

        CASE MPlayer64

        CASE InfoFrame

        CASE VisLPictureBox

        CASE VisRPictureBox

        CASE TimeLabel

    END SELECT
END SUB

SUB __UI_FocusIn (id AS LONG)
    SELECT CASE id
        CASE ClearBT

        CASE PreviousBT

        CASE VMBT

        CASE VPBT

        CASE SeekTrackBar

        CASE PlayListBox

        CASE OpenBT

        CASE VisualBT

        CASE PlayBT

        CASE PauseBT

        CASE NextBT

        CASE SoundbankBT

        CASE AboutBT

    END SELECT
END SUB

SUB __UI_FocusOut (id AS LONG)
    'This event occurs right before a control loses focus.
    'To prevent a control from losing focus, set __UI_KeepFocus = True below.
    SELECT CASE id
        CASE ClearBT

        CASE PreviousBT

        CASE VMBT

        CASE VPBT

        CASE SeekTrackBar

        CASE PlayListBox

        CASE OpenBT

        CASE VisualBT

        CASE PlayBT

        CASE PauseBT

        CASE NextBT

        CASE SoundbankBT

        CASE AboutBT

    END SELECT
END SUB

SUB __UI_MouseDown (id AS LONG)
    SELECT CASE id
        CASE ClearBT

        CASE PreviousBT

        CASE VMBT

        CASE VPBT

        CASE SeekTrackBar

        CASE VolumeProgressBar

        CASE PlayListBox

        CASE OpenBT

        CASE VisualBT

        CASE PlayBT

        CASE PauseBT

        CASE NextBT

        CASE SoundbankBT

        CASE AboutBT

        CASE MPlayer64

        CASE InfoFrame

        CASE VisLPictureBox

        CASE VisRPictureBox

        CASE TimeLabel

    END SELECT
END SUB

SUB __UI_MouseUp (id AS LONG)
    SELECT CASE id
        CASE ClearBT

        CASE PreviousBT

        CASE VMBT

        CASE VPBT

        CASE SeekTrackBar

        CASE VolumeProgressBar

        CASE PlayListBox

        CASE OpenBT

        CASE VisualBT

        CASE PlayBT

        CASE PauseBT

        CASE NextBT

        CASE SoundbankBT

        CASE AboutBT

        CASE MPlayer64

        CASE InfoFrame

        CASE VisLPictureBox

        CASE VisRPictureBox

        CASE TimeLabel

    END SELECT
END SUB

SUB __UI_KeyPress (id AS LONG)
    'When this event is fired, __UI_KeyHit will contain the code of the key hit.
    'You can change it and even cancel it by making it = 0
    SELECT CASE id
        CASE ClearBT

        CASE PreviousBT

        CASE VMBT

        CASE VPBT

        CASE SeekTrackBar

        CASE PlayListBox

        CASE OpenBT

        CASE VisualBT

        CASE PlayBT

        CASE PauseBT

        CASE NextBT

        CASE SoundbankBT

        CASE AboutBT

    END SELECT
END SUB

SUB __UI_TextChanged (id AS LONG)
    SELECT CASE id
        CASE ELSE
    END SELECT
END SUB

SUB __UI_ValueChanged (id AS LONG)
    SELECT CASE id
        CASE SeekTrackBar

        CASE PlayListBox

    END SELECT
END SUB

SUB __UI_FormResized

END SUB
