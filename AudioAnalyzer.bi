'-----------------------------------------------------------------------------------------------------------------------
' A simple audio analyzer library
' Copyright (c) 2024 Samuel Gomes
'-----------------------------------------------------------------------------------------------------------------------

$INCLUDEONCE

CONST __AUDIOANALYZER_FALSE%% = 0%%, __AUDIOANALYZER_TRUE%% = NOT __AUDIOANALYZER_FALSE
CONST __AUDIOANALYZER_SIZEOF_BYTE~%% = 1~%%
CONST __AUDIOANALYZER_SIZEOF_INTEGER~%% = 2~%%
CONST __AUDIOANALYZER_SIZEOF_LONG~%% = 4~%%
CONST __AUDIOANALYZER_SIZEOF_SINGLE~%% = 4~%%
CONST __AUDIOANALYZER_SIZEOF_DOUBLE~%% = 8~%%
CONST __AUDIOANALYZER_FORMAT_UNKNOWN~%% = 0~%%
CONST __AUDIOANALYZER_FORMAT_U8~%% = 1~%%
CONST __AUDIOANALYZER_FORMAT_S16~%% = 2~%%
CONST __AUDIOANALYZER_FORMAT_S32~%% = 3~%%
CONST __AUDIOANALYZER_FORMAT_F32~%% = 4~%%
CONST __AUDIOANALYZER_S8_TO_F32! = 1! / 128!
CONST __AUDIOANALYZER_S16_TO_F32! = 1! / 32768!
CONST __AUDIOANALYZER_S32_TO_F32! = 1! / 2147483648!
CONST __AUDIOANALYZER_CLIP_BUFFER_TIME! = 0.05!
CONST __AUDIOANALYZER_FFT_SCALE_X~& = 1~&
CONST __AUDIOANALYZER_FFT_SCALE_Y! = 3!
CONST __AUDIOANALYZER_VU_PEAK_FALL_SPEED! = 0.001!
CONST __AUDIOANALYZER_STAR_COUNT~& = 256~&
CONST __AUDIOANALYZER_STAR_Z_DIVIDER! = 4096!
CONST __AUDIOANALYZER_STAR_SPEED_MUL! = 64!
CONST __AUDIOANALYZER_STAR_ANGLE_INC! = 0.001!
CONST __AUDIOANALYZER_CIRCLE_WAVE_COUNT~& = 16~&
CONST __AUDIOANALYZER_CIRCLE_WAVE_RADIUS_MUL! = 4!
CONST AUDIOANALYZER_STYLE_PROGRESS~%% = 0~%%
CONST AUDIOANALYZER_STYLE_OSCILLOSCOPE1~%% = 1~%%
CONST AUDIOANALYZER_STYLE_OSCILLOSCOPE2~%% = 2~%%
CONST AUDIOANALYZER_STYLE_VU~%% = 3~%%
CONST AUDIOANALYZER_STYLE_SPECTRUM~%% = 4~%%
CONST AUDIOANALYZER_STYLE_CIRCULAR_WAVEFORM~%% = 5~%%
CONST AUDIOANALYZER_STYLE_RADIAL_SPARKS~%% = 6~%%
CONST AUDIOANALYZER_STYLE_TESLA_COIL~%% = 7~%%
CONST AUDIOANALYZER_STYLE_CIRCLE_WAVES~%% = 8~%%
CONST AUDIOANALYZER_STYLE_STARS~%% = 9~%%
CONST AUDIOANALYZER_STYLE_BUBBLE_UNIVERSE~%% = 10~%%
CONST AUDIOANALYZER_STYLE_COUNT~%% = 11~%% ' add new stuff before this and adjust values

TYPE __AudioAnalyzer_Vec2Type
    x AS SINGLE
    y AS SINGLE
END TYPE

TYPE __AudioAnalyzer_Vec3Type
    x AS SINGLE
    y AS SINGLE
    z AS SINGLE
END TYPE

TYPE __AudioAnalyzer_RGBType
    r AS _UNSIGNED _BYTE
    g AS _UNSIGNED _BYTE
    b AS _UNSIGNED _BYTE
END TYPE

TYPE __AudioAnalyzer_StarType
    p AS __AudioAnalyzer_Vec3Type ' position
    a AS SINGLE ' angle
    c AS _UNSIGNED LONG ' color
END TYPE

TYPE __AudioAnalyzer_CircleWaveType
    p AS __AudioAnalyzer_Vec2Type ' position
    v AS __AudioAnalyzer_Vec2Type ' velocity
    r AS SINGLE ' radius
    c AS __AudioAnalyzer_RGBType ' color
    a AS SINGLE ' alpha (0.0 - 1.0)
    s AS SINGLE ' fade speed
END TYPE

TYPE __AudioAnalyzerType
    handle AS LONG
    buffer AS _MEM
    format AS _UNSIGNED _BYTE
    channels AS _UNSIGNED _BYTE
    currentTime AS DOUBLE
    totalTime AS DOUBLE
    currentFrame AS _UNSIGNED _INTEGER64
    totalFrames AS _UNSIGNED _INTEGER64
    isLengthQueryPending AS _BYTE
    clipBufferFrames AS _UNSIGNED LONG
    clipBufferSamples AS _UNSIGNED LONG
    fftBufferSamples AS _UNSIGNED LONG
    fftScaleX AS _UNSIGNED LONG
    fftScaleY AS SINGLE
    vuPeakFallSpeed AS SINGLE
    progressHideText AS _BYTE
    style AS _UNSIGNED _BYTE
    color1 AS _UNSIGNED LONG
    color2 AS _UNSIGNED LONG
    color3 AS _UNSIGNED LONG
    currentTimeText AS STRING
    totalTimeText AS STRING
    starCount AS _UNSIGNED LONG
    starSpeedMultiplier AS SINGLE
    circleWaveCount AS _UNSIGNED LONG
    circleWaveRadiusMultiplier AS SINGLE
    bubbleUniverseNoStretch AS _BYTE
END TYPE

DECLARE LIBRARY
    $IF 64BIT THEN
        FUNCTION __AudioAnalyzer_CLngPtr~&& ALIAS "uintptr_t" (BYVAL p AS _UNSIGNED _OFFSET)
    $ELSE
        FUNCTION __AudioAnalyzer_CLngPtr~& ALIAS "uintptr_t" (BYVAL p AS _UNSIGNED _OFFSET)
    $END IF
    FUNCTION __AudioAnalyzer_CByte%% ALIAS "int8_t" (BYVAL v AS _UNSIGNED _BYTE)
    FUNCTION __AudioAnalyzer_CLZ& ALIAS "__builtin_clz" (BYVAL x AS _UNSIGNED LONG)
END DECLARE

DECLARE CUSTOMTYPE LIBRARY
    SUB __AudioAnalyzer_MemCpy ALIAS "memcpy" (BYVAL dst AS _UNSIGNED _OFFSET, BYVAL src AS _UNSIGNED _OFFSET, BYVAL count AS _UNSIGNED _OFFSET)
END DECLARE

DIM __AudioAnalyzer AS __AudioAnalyzerType
REDIM AS SINGLE __AudioAnalyzer_ClipBuffer(0), __AudioAnalyzer_FFTBuffer(0, 0), __AudioAnalyzer_IntensityBuffer(0), __AudioAnalyzer_PeakBuffer(0)
REDIM __AudioAnalyzer_Stars(0, 0) AS __AudioAnalyzer_StarType, __AudioAnalyzer_CircleWaves(0, 0) AS __AudioAnalyzer_CircleWaveType
