'-----------------------------------------------------------------------------------------------------------------------
' A simple audio analyzer library
' Copyright (c) 2024 Samuel Gomes
'-----------------------------------------------------------------------------------------------------------------------

$INCLUDEONCE

'$INCLUDE:'AudioAnalyzer.bi'

'-----------------------------------------------------------------------------------------------------------------------
' Test code for debugging the library
'-----------------------------------------------------------------------------------------------------------------------
'$RESIZE:SMOOTH
'_DEFINE A-Z AS LONG
'OPTION _EXPLICIT

'SCREEN _NEWIMAGE(800, 600, 32)
'_ALLOWFULLSCREEN _SQUAREPIXELS , _SMOOTH
'_PRINTMODE _KEEPBACKGROUND ' for progress text
'_FONT 16

'PRINT "Loading... ";
'DIM song AS LONG: song = _SNDOPEN(_OPENFILEDIALOG$)
'IF song < 1 THEN
'    PRINT "Failed to load song!"
'    END
'END IF
'PRINT "Done!"

'IF NOT AudioAnalyzer_Init(song) THEN
'    PRINT "Failed to access sound sample data."
'    END
'END IF

'_SNDPLAY song

'DIM style AS INTEGER: style = AUDIOANALYZER_STYLE_SPECTRUM
'AudioAnalyzer_SetStyle style

'DIM channels AS _UNSIGNED _BYTE: channels = AudioAnalyzer_GetChannels

'DIM AS _BYTE hideText, isVertical
'DIM k AS LONG

'DO
'    k = _KEYHIT

'    SELECT CASE k
'        CASE 27 ' exit
'            EXIT DO

'        CASE 19200 ' vis -
'            IF style > 0 THEN style = style - 1
'            AudioAnalyzer_SetStyle style

'        CASE 19712 ' vis +
'            IF style < AUDIOANALYZER_STYLE_COUNT - 1 THEN style = style + 1
'            AudioAnalyzer_SetStyle style

'        CASE 116, 84 ' text on / off
'            hideText = NOT hideText
'            AudioAnalyzer_HideProgressText hideText

'        CASE 111, 79 ' toggle orientation
'            isVertical = NOT isVertical
'    END SELECT

'    AudioAnalyzer_Update

'    CLS

'    PRINT "Frame:"; AudioAnalyzer_GetCurrentFrame; "of"; AudioAnalyzer_GetTotalFrames, "Format:"; __AudioAnalyzer.format, "Channels:"; channels;
'    LOCATE 37, 1: PRINT "ESC: Exit", "<-: Vis-", "->: Vis+", "T: Text", "O: Vert";

'    IF channels < 2 _ORELSE style = AUDIOANALYZER_STYLE_PROGRESS THEN
'        COLOR &HFFFFFFFF ' text color - bright white

'        IF isVertical THEN
'            AudioAnalyzer_Render 350, 100, 450, 500, 0
'        ELSE
'            AudioAnalyzer_Render 100, 250, 700, 350, 0
'        END IF
'    ELSE
'        IF isVertical THEN
'            AudioAnalyzer_Render 150, 100, 250, 500, 0
'            AudioAnalyzer_Render 550, 100, 650, 500, 1
'        ELSE
'            AudioAnalyzer_Render 50, 250, 350, 350, 0
'            AudioAnalyzer_Render 450, 250, 750, 350, 1
'        END IF
'    END IF

'    _DISPLAY

'    _LIMIT 60
'LOOP WHILE _SNDPLAYING(song)

'AudioAnalyzer_Done
'_SNDCLOSE song
'_AUTODISPLAY
'END
'-----------------------------------------------------------------------------------------------------------------------

FUNCTION AudioAnalyzer_Init%% (handle AS LONG)
    SHARED __AudioAnalyzer AS __AudioAnalyzerType
    SHARED AS SINGLE __AudioAnalyzer_ClipBuffer(), __AudioAnalyzer_FFTBuffer(), __AudioAnalyzer_IntensityBuffer(), __AudioAnalyzer_PeakBuffer()

    IF __AudioAnalyzer.handle = 0 THEN
        __AudioAnalyzer.handle = handle
        __AudioAnalyzer.buffer = _MEMSOUND(handle)
        __AudioAnalyzer.format = __AUDIOANALYZER_FORMAT_UNKNOWN
        __AudioAnalyzer.channels = 0

        IF __AudioAnalyzer.buffer.SIZE THEN
            ' Figure out the sound format based on https://qb64phoenix.com/qb64wiki/index.php/MEM
            ' Note: We do not support 24-bit audio yet
            IF __AudioAnalyzer.buffer.TYPE = 1153 THEN
                __AudioAnalyzer.format = __AUDIOANALYZER_FORMAT_U8
                __AudioAnalyzer.channels = __AudioAnalyzer_CLngPtr(__AudioAnalyzer.buffer.ELEMENTSIZE) \ __AUDIOANALYZER_SIZEOF_BYTE
            ELSEIF __AudioAnalyzer.buffer.TYPE = 130 THEN
                __AudioAnalyzer.format = __AUDIOANALYZER_FORMAT_S16
                __AudioAnalyzer.channels = __AudioAnalyzer_CLngPtr(__AudioAnalyzer.buffer.ELEMENTSIZE) \ __AUDIOANALYZER_SIZEOF_INTEGER
            ELSEIF __AudioAnalyzer.buffer.TYPE = 132 THEN
                __AudioAnalyzer.format = __AUDIOANALYZER_FORMAT_S32
                __AudioAnalyzer.channels = __AudioAnalyzer_CLngPtr(__AudioAnalyzer.buffer.ELEMENTSIZE) \ __AUDIOANALYZER_SIZEOF_LONG
            ELSEIF __AudioAnalyzer.buffer.TYPE = 260 THEN
                __AudioAnalyzer.format = __AUDIOANALYZER_FORMAT_F32
                __AudioAnalyzer.channels = __AudioAnalyzer_CLngPtr(__AudioAnalyzer.buffer.ELEMENTSIZE) \ __AUDIOANALYZER_SIZEOF_SINGLE
            END IF
        END IF

        __AudioAnalyzer.totalTime = _SNDLEN(handle)
        __AudioAnalyzer.totalFrames = __AudioAnalyzer.totalTime * _SNDRATE
        __AudioAnalyzer.isLengthQueryPending = __AUDIOANALYZER_TRUE
        __AudioAnalyzer.clipBufferFrames = AudioAnalyzer_RDPOT(__AUDIOANALYZER_CLIP_BUFFER_TIME * _SNDRATE) ' save the clip buffer frames
        __AudioAnalyzer.clipBufferSamples = __AudioAnalyzer.clipBufferFrames * __AudioAnalyzer.channels
        __AudioAnalyzer.fftBufferSamples = __AudioAnalyzer.clipBufferFrames \ 2
        __AudioAnalyzer.style = AUDIOANALYZER_STYLE_OSCILLOSCOPE1

        AudioAnalyzer_SetFFTScale __AUDIOANALYZER_FFT_SCALE_X, __AUDIOANALYZER_FFT_SCALE_Y
        AudioAnalyzer_SetVUPeakFallSpeed __AUDIOANALYZER_VU_PEAK_FALL_SPEED
        AudioAnalyzer_HideProgressText __AUDIOANALYZER_FALSE
        AudioAnalyzer_SetColors _RGB32(0, 255, 0), _RGB32(255, 0, 0), _RGB32(0, 0, 255)

        __AudioAnalyzer.currentTimeText = "00:00:00"
        __AudioAnalyzer.totalTimeText = __AudioAnalyzer.currentTimeText

        IF __AudioAnalyzer.clipBufferSamples THEN
            REDIM __AudioAnalyzer_ClipBuffer(0 TO __AudioAnalyzer.clipBufferSamples - 1) AS SINGLE
        END IF

        IF __AudioAnalyzer.channels THEN
            IF __AudioAnalyzer.fftBufferSamples THEN
                REDIM __AudioAnalyzer_FFTBuffer(0 TO __AudioAnalyzer.channels - 1, 0 TO __AudioAnalyzer.fftBufferSamples - 1) AS SINGLE
            END IF

            REDIM __AudioAnalyzer_IntensityBuffer(0 TO __AudioAnalyzer.channels - 1) AS SINGLE
            REDIM __AudioAnalyzer_PeakBuffer(0 TO __AudioAnalyzer.channels - 1) AS SINGLE

            AudioAnalyzer_SetStarCount __AUDIOANALYZER_STAR_COUNT
            AudioAnalyzer_SetCircleWaveCount __AUDIOANALYZER_CIRCLE_WAVE_COUNT
        END IF

        AudioAnalyzer_SetStarProperties __AUDIOANALYZER_STAR_SPEED_MUL
        AudioAnalyzer_SetCircleWaveProperties __AUDIOANALYZER_CIRCLE_WAVE_RADIUS_MUL

        ' Note: We'll return success even if we failed to acquire the sound buffer
        ' That's because some formats simply do not allow accessing sample data (i.e. .ogg; due to the way stb_vorbis works :()
        ' In these cases we'll force fallback to the "progress" style
        AudioAnalyzer_Init = __AUDIOANALYZER_TRUE
    END IF
END FUNCTION


SUB AudioAnalyzer_Done
    SHARED __AudioAnalyzer AS __AudioAnalyzerType

    IF __AudioAnalyzer.handle THEN
        __AudioAnalyzer.handle = 0
        IF __AudioAnalyzer.buffer.SIZE THEN _MEMFREE __AudioAnalyzer.buffer
        __AudioAnalyzer.format = __AUDIOANALYZER_FORMAT_UNKNOWN
        __AudioAnalyzer.channels = 0
        __AudioAnalyzer.currentTime = 0#
        __AudioAnalyzer.totalTime = 0#
        __AudioAnalyzer.currentFrame = 0
        __AudioAnalyzer.totalFrames = 0
        __AudioAnalyzer.clipBufferFrames = 0
        __AudioAnalyzer.clipBufferSamples = 0
        __AudioAnalyzer.fftBufferSamples = 0
        __AudioAnalyzer.currentTimeText = ""
        __AudioAnalyzer.totalTimeText = ""
    END IF
END SUB


FUNCTION AudioAnalyzer_GetChannels~%%
    $CHECKING:OFF
    SHARED __AudioAnalyzer AS __AudioAnalyzerType
    IF __AudioAnalyzer.handle THEN
        AudioAnalyzer_GetChannels = __AudioAnalyzer.channels + (__AudioAnalyzer.channels = 0) * -1 ' at least 1 channel if handle is valid
    END IF
    $CHECKING:ON
END FUNCTION


FUNCTION AudioAnalyzer_GetCurrentTime#
    $CHECKING:OFF
    SHARED __AudioAnalyzer AS __AudioAnalyzerType
    AudioAnalyzer_GetCurrentTime = __AudioAnalyzer.currentTime
    $CHECKING:ON
END FUNCTION


FUNCTION AudioAnalyzer_GetTotalTime#
    $CHECKING:OFF
    SHARED __AudioAnalyzer AS __AudioAnalyzerType
    AudioAnalyzer_GetTotalTime = __AudioAnalyzer.totalTime
    $CHECKING:ON
END FUNCTION


FUNCTION AudioAnalyzer_GetCurrentFrame~&&
    $CHECKING:OFF
    SHARED __AudioAnalyzer AS __AudioAnalyzerType
    AudioAnalyzer_GetCurrentFrame = __AudioAnalyzer.currentFrame
    $CHECKING:ON
END FUNCTION


FUNCTION AudioAnalyzer_GetTotalFrames~&&
    $CHECKING:OFF
    SHARED __AudioAnalyzer AS __AudioAnalyzerType
    AudioAnalyzer_GetTotalFrames = __AudioAnalyzer.totalFrames
    $CHECKING:ON
END FUNCTION


FUNCTION AudioAnalyzer_GetIntensity! (channel AS _UNSIGNED _BYTE)
    $CHECKING:OFF
    SHARED __AudioAnalyzer AS __AudioAnalyzerType
    SHARED __AudioAnalyzer_IntensityBuffer() AS SINGLE
    IF __AudioAnalyzer.handle THEN
        AudioAnalyzer_GetIntensity = __AudioAnalyzer_IntensityBuffer(channel)
    END IF
    $CHECKING:ON
END FUNCTION


FUNCTION AudioAnalyzer_GetPeak! (channel AS _UNSIGNED _BYTE)
    $CHECKING:OFF
    SHARED __AudioAnalyzer AS __AudioAnalyzerType
    SHARED __AudioAnalyzer_PeakBuffer() AS SINGLE
    IF __AudioAnalyzer.handle THEN
        AudioAnalyzer_GetPeak = __AudioAnalyzer_PeakBuffer(channel)
    END IF
    $CHECKING:ON
END FUNCTION


FUNCTION AudioAnalyzer_GetCurrentTimeText$
    $CHECKING:OFF
    SHARED __AudioAnalyzer AS __AudioAnalyzerType
    AudioAnalyzer_GetCurrentTimeText = __AudioAnalyzer.currentTimeText
    $CHECKING:ON
END FUNCTION


FUNCTION AudioAnalyzer_GetTotalTimeText$
    $CHECKING:OFF
    SHARED __AudioAnalyzer AS __AudioAnalyzerType
    AudioAnalyzer_GetTotalTimeText = __AudioAnalyzer.totalTimeText
    $CHECKING:ON
END FUNCTION


SUB AudioAnalyzer_SetStyle (style AS _UNSIGNED _BYTE)
    SHARED __AudioAnalyzer AS __AudioAnalyzerType
    IF __AudioAnalyzer.handle THEN
        IF __AudioAnalyzer.buffer.SIZE THEN
            __AudioAnalyzer.style = style
        ELSE
            __AudioAnalyzer.style = AUDIOANALYZER_STYLE_PROGRESS
        END IF
    END IF
END SUB


SUB AudioAnalyzer_SetColors (color1 AS _UNSIGNED LONG, color2 AS _UNSIGNED LONG, color3 AS _UNSIGNED LONG)
    SHARED __AudioAnalyzer AS __AudioAnalyzerType
    __AudioAnalyzer.color1 = color1
    __AudioAnalyzer.color2 = color2
    __AudioAnalyzer.color3 = color3
END SUB


SUB AudioAnalyzer_SetFFTScale (x AS _UNSIGNED _BYTE, y AS SINGLE)
    SHARED __AudioAnalyzer AS __AudioAnalyzerType
    __AudioAnalyzer.fftScaleX = 2 * x + (x = 0) * -2
    IF y > 0! THEN __AudioAnalyzer.fftScaleY = y
END SUB


SUB AudioAnalyzer_SetVUPeakFallSpeed (speed AS SINGLE)
    SHARED __AudioAnalyzer AS __AudioAnalyzerType
    IF speed > 0! THEN __AudioAnalyzer.vuPeakFallSpeed = speed
END SUB


SUB AudioAnalyzer_HideProgressText (state AS _BYTE)
    SHARED __AudioAnalyzer AS __AudioAnalyzerType
    __AudioAnalyzer.progressHideText = state
END SUB


SUB AudioAnalyzer_SetStarCount (count AS _UNSIGNED INTEGER)
    SHARED __AudioAnalyzer AS __AudioAnalyzerType
    SHARED __AudioAnalyzer_Stars() AS __AudioAnalyzer_StarType

    __AudioAnalyzer.starCount = count
    REDIM __AudioAnalyzer_Stars(0 TO __AudioAnalyzer.channels - 1, 0 TO __AudioAnalyzer.starCount - 1) AS __AudioAnalyzer_StarType

    DIM AS _UNSIGNED LONG i, c
    WHILE i < __AudioAnalyzer.starCount
        c = 0
        WHILE c < __AudioAnalyzer.channels
            __AudioAnalyzer_Stars(c, i).p.x = -1!
            __AudioAnalyzer_Stars(c, i).p.y = -1!
            __AudioAnalyzer_Stars(c, i).p.z = __AUDIOANALYZER_STAR_Z_DIVIDER
            c = c + 1
        WEND
        i = i + 1
    WEND
END SUB


SUB AudioAnalyzer_SetCircleWaveCount (count AS _UNSIGNED INTEGER)
    SHARED __AudioAnalyzer AS __AudioAnalyzerType
    SHARED __AudioAnalyzer_CircleWaves() AS __AudioAnalyzer_CircleWaveType

    __AudioAnalyzer.circleWaveCount = count
    REDIM __AudioAnalyzer_CircleWaves(0 TO __AudioAnalyzer.channels - 1, 0 TO __AudioAnalyzer.circleWaveCount - 1) AS __AudioAnalyzer_CircleWaveType

    DIM AS _UNSIGNED LONG i, c
    WHILE i < __AudioAnalyzer.circleWaveCount
        c = 0
        WHILE c < __AudioAnalyzer.channels
            __AudioAnalyzer_CircleWaves(c, i).a = 0!
            c = c + 1
        WEND
        i = i + 1
    WEND
END SUB


SUB AudioAnalyzer_SetStarProperties (mul AS SINGLE)
    SHARED __AudioAnalyzer AS __AudioAnalyzerType
    __AudioAnalyzer.starSpeedMultiplier = mul
END SUB


SUB AudioAnalyzer_SetCircleWaveProperties (mul AS SINGLE)
    SHARED __AudioAnalyzer AS __AudioAnalyzerType
    __AudioAnalyzer.circleWaveRadiusMultiplier = mul
END SUB


SUB AudioAnalyzer_StretchBubbleUniverse (state AS _BYTE)
    SHARED __AudioAnalyzer AS __AudioAnalyzerType
    __AudioAnalyzer.bubbleUniverseNoStretch = _NEGATE state
END SUB


' @brief This function calculates the FFT for use in audio analyzers. All arrays passed must be zero based and power of 2 size.
' This was simplified and adapted from Vince's FFT code at https://qb64phoenix.com/forum/showthread.php?tid=270&pid=2005#pid2005
' @param realInput 32-bit multi-channel floating-point interleaved audio sample array.
' @param channel The index in realInput where we should begin (0 for the first channel, 1 for the second, etc.).
' @param channels The number of samples we should skip in realInput (1 for mono data, 2 for stereo, etc.).
' @param fftOutput [out] The output FFT array for positive frequencies only. First dimension is channel, and second is the FFT data.
' @return Audio intensity for the given channel.
FUNCTION AudioAnalyzer_FFT! (realInput() AS SINGLE, channel AS LONG, channels AS LONG, fftOutput( ,) AS SINGLE)
    $CHECKING:OFF
    STATIC AS SINGLE fft_real(0 TO 0), fft_imag(0 TO 0)
    STATIC rev_lookup(0 TO 0) AS LONG
    STATIC AS LONG half_n, log2n

    DIM AS SINGLE wr, wi, wmr, wmi, ur, ui, vr, vi, pi_m, intensity
    DIM AS LONG rev, i, j, k, m, p, q, n, half_m

    n = (UBOUND(realInput) + 1) \ channels
    IF n <> UBOUND(fft_real) + 1 THEN
        REDIM AS SINGLE fft_real(0 TO n - 1), fft_imag(0 TO n - 1)

        half_n = n \ 2

        REDIM rev_lookup(0 TO half_n - 1) AS LONG

        log2n = 30~& - __AudioAnalyzer_CLZ(n)

        i = 0
        DO WHILE i < half_n
            j = 0
            DO WHILE j < log2n
                IF i AND _SHL(1, j) THEN rev_lookup(i) = rev_lookup(i) + _SHL(1, (log2n - 1 - j))
                j = j + 1
            LOOP
            i = i + 1
        LOOP
    END IF

    i = 0
    DO WHILE i < half_n
        rev = rev_lookup(i)
        fft_real(i) = realInput(channel + rev * channels)
        fft_imag(i) = 0!
        intensity = intensity + fft_real(i) * fft_real(i)
        i = i + 1
    LOOP
    AudioAnalyzer_FFT = intensity / half_n

    FOR i = 1 TO log2n
        m = _SHL(1, i)
        half_m = m \ 2
        pi_m = _PI(-2! / m)
        wmr = COS(pi_m)
        wmi = SIN(pi_m)

        j = 0
        DO WHILE j < half_n
            wr = 1!
            wi = 0!

            k = 0
            DO WHILE k < half_m
                p = j + k
                q = p + half_m

                ur = wr * fft_real(q) - wi * fft_imag(q)
                ui = wr * fft_imag(q) + wi * fft_real(q)
                vr = fft_real(p)
                vi = fft_imag(p)

                fft_real(p) = vr + ur
                fft_imag(p) = vi + ui
                fft_real(q) = vr - ur
                fft_imag(q) = vi - ui

                ur = wr
                wr = ur * wmr - wi * wmi
                wi = ur * wmi + wi * wmr

                k = k + 1
            LOOP
            j = j + m
        LOOP
    NEXT i

    i = 0
    DO WHILE i < half_n
        fftOutput(channel, i) = SQR(fft_real(i) * fft_real(i) + fft_imag(i) * fft_imag(i))

        i = i + 1
    LOOP
    $CHECKING:ON
END FUNCTION


' @brief Rounds a number down to a power of 2.
' @param i The number to round down.
' @return The number i rounded down to a power of 2.
FUNCTION AudioAnalyzer_RDPOT~& (i AS _UNSIGNED LONG)
    $CHECKING:OFF
    DIM j AS _UNSIGNED LONG: j = i
    j = j OR (j \ 2~&)
    j = j OR (j \ 4~&)
    j = j OR (j \ 16~&)
    j = j OR (j \ 256~&)
    j = j OR (j \ 65536~&)
    AudioAnalyzer_RDPOT = j - (j \ 2~&)
    $CHECKING:ON
END FUNCTION


FUNCTION AudioAnalyzer_GetRandomBetween& (lo AS LONG, hi AS LONG)
    $CHECKING:OFF
    AudioAnalyzer_GetRandomBetween = lo + RND * (hi - lo)
    $CHECKING:ON
END FUNCTION


FUNCTION AudioAnalyzer_GetMin& (x AS LONG, y AS LONG)
    $CHECKING:OFF
    IF x < y THEN AudioAnalyzer_GetMin = x ELSE AudioAnalyzer_GetMin = y
    $CHECKING:ON
END FUNCTION


FUNCTION AudioAnalyzer_GetMax& (x AS LONG, y AS LONG)
    $CHECKING:OFF
    IF x > y THEN AudioAnalyzer_GetMax = x ELSE AudioAnalyzer_GetMax = y
    $CHECKING:ON
END FUNCTION


FUNCTION AudioAnalyzer_InterpolateColor~& (colorA AS _UNSIGNED LONG, colorB AS _UNSIGNED LONG, factor AS SINGLE)
    $CHECKING:OFF
    DIM a AS LONG: a = _ALPHA32(colorA)
    DIM r AS LONG: r = _RED32(colorA)
    DIM g AS LONG: g = _GREEN32(colorA)
    DIM b AS LONG: b = _BLUE32(colorA)

    a = a + ((_ALPHA32(colorB) - a) * factor)
    r = r + ((_RED32(colorB) - r) * factor)
    g = g + ((_GREEN32(colorB) - g) * factor)
    b = b + ((_BLUE32(colorB) - b) * factor)

    AudioAnalyzer_InterpolateColor = _RGBA32(r, g, b, a)
    $CHECKING:ON
END FUNCTION


SUB AudioAnalyzer_DrawFilledCircle (cx AS LONG, cy AS LONG, r AS LONG, c AS _UNSIGNED LONG)
    $CHECKING:OFF
    DIM AS LONG radius, radiusError, x, y

    radius = ABS(r)
    radiusError = -radius
    x = radius

    IF radius = 0 THEN
        PSET (cx, cy), c
        EXIT SUB
    END IF

    LINE (cx - x, cy)-(cx + x, cy), c, BF

    DO WHILE x > y
        radiusError = radiusError + y * 2 + 1

        IF radiusError >= 0 THEN
            IF x <> y + 1 THEN
                LINE (cx - y, cy - x)-(cx + y, cy - x), c, BF
                LINE (cx - y, cy + x)-(cx + y, cy + x), c, BF
            END IF
            x = x - 1
            radiusError = radiusError - x * 2
        END IF

        y = y + 1

        LINE (cx - x, cy - y)-(cx + x, cy - y), c, BF
        LINE (cx - x, cy + y)-(cx + x, cy + y), c, BF
    LOOP
    $CHECKING:ON
END SUB


SUB AudioAnalyzer_RenderSpectrum (l AS LONG, t AS LONG, r AS LONG, b AS LONG, channel AS _UNSIGNED _BYTE)
    SHARED __AudioAnalyzer AS __AudioAnalyzerType
    SHARED __AudioAnalyzer_FFTBuffer() AS SINGLE

    DIM w AS LONG: w = 1 + r - l
    DIM h AS LONG: h = 1 + b - t
    DIM freqMax AS _UNSIGNED LONG: freqMax = __AudioAnalyzer.fftBufferSamples \ __AudioAnalyzer.fftScaleX

    DIM AS LONG i, j, x, y

    IF h > w THEN
        IF channel AND 1 THEN
            WHILE i < h
                j = __AudioAnalyzer_FFTBuffer(channel, (i * freqMax) \ h) * __AudioAnalyzer.fftScaleY
                IF j >= w THEN j = w - 1

                x = l + j
                y = t + i

                LINE (l, y)-(x, y), AudioAnalyzer_InterpolateColor(__AudioAnalyzer.color1, __AudioAnalyzer.color2, j / w)

                i = i + 1
            WEND
        ELSE
            WHILE i < h
                j = __AudioAnalyzer_FFTBuffer(channel, (i * freqMax) \ h) * __AudioAnalyzer.fftScaleY
                IF j >= w THEN j = w - 1

                x = r - j
                y = t + i

                LINE (x, y)-(r, y), AudioAnalyzer_InterpolateColor(__AudioAnalyzer.color1, __AudioAnalyzer.color2, j / w)

                i = i + 1
            WEND
        END IF
    ELSE
        WHILE i < w
            j = __AudioAnalyzer_FFTBuffer(channel, (i * freqMax) \ w) * __AudioAnalyzer.fftScaleY
            IF j >= h THEN j = h - 1

            x = l + i
            y = b - j

            LINE (x, y)-(x, b), AudioAnalyzer_InterpolateColor(__AudioAnalyzer.color1, __AudioAnalyzer.color2, j / h)

            i = i + 1
        WEND
    END IF
END SUB


SUB AudioAnalyzer_RenderOscilloscope1 (l AS LONG, t AS LONG, r AS LONG, b AS LONG, channel AS _UNSIGNED _BYTE)
    SHARED __AudioAnalyzer AS __AudioAnalyzerType
    SHARED __AudioAnalyzer_ClipBuffer() AS SINGLE

    DIM w AS LONG: w = 1 + r - l
    DIM h AS LONG: h = 1 + b - t

    DIM i AS _UNSIGNED LONG, sample AS SINGLE

    IF h > w THEN
        DIM halfWidth AS LONG: halfWidth = w \ 2
        DIM midX AS LONG: midX = l + halfWidth

        WHILE i < h
            sample = __AudioAnalyzer_ClipBuffer(((i * __AudioAnalyzer.clipBufferFrames) \ h) * __AudioAnalyzer.channels + channel)
            DIM x AS LONG: x = midX + sample * halfWidth

            IF i > 0 THEN
                LINE -(x, t + i), AudioAnalyzer_InterpolateColor(__AudioAnalyzer.color1, __AudioAnalyzer.color2, ABS(sample))
            ELSE
                PSET (x, t + i), AudioAnalyzer_InterpolateColor(__AudioAnalyzer.color1, __AudioAnalyzer.color2, ABS(sample))
            END IF

            i = i + 1
        WEND
    ELSE
        DIM halfHeight AS LONG: halfHeight = h \ 2
        DIM midY AS LONG: midY = t + halfHeight

        WHILE i < w
            sample = __AudioAnalyzer_ClipBuffer(((i * __AudioAnalyzer.clipBufferFrames) \ w) * __AudioAnalyzer.channels + channel)
            DIM y AS LONG: y = midY - sample * halfHeight

            IF i > 0 THEN
                LINE -(l + i, y), AudioAnalyzer_InterpolateColor(__AudioAnalyzer.color1, __AudioAnalyzer.color2, ABS(sample))
            ELSE
                PSET (l + i, y), AudioAnalyzer_InterpolateColor(__AudioAnalyzer.color1, __AudioAnalyzer.color2, ABS(sample))
            END IF

            i = i + 1
        WEND
    END IF
END SUB


SUB AudioAnalyzer_RenderOscilloscope2 (l AS LONG, t AS LONG, r AS LONG, b AS LONG, channel AS _UNSIGNED _BYTE)
    SHARED __AudioAnalyzer AS __AudioAnalyzerType
    SHARED __AudioAnalyzer_ClipBuffer() AS SINGLE

    DIM w AS LONG: w = 1 + r - l
    DIM h AS LONG: h = 1 + b - t

    DIM i AS _UNSIGNED LONG, sample AS SINGLE

    IF h > w THEN
        DIM halfWidth AS LONG: halfWidth = w \ 2
        DIM midX AS LONG: midX = l + halfWidth

        WHILE i < h
            DIM y AS LONG: y = t + i
            sample = __AudioAnalyzer_ClipBuffer(((i * __AudioAnalyzer.clipBufferFrames) \ h) * __AudioAnalyzer.channels + channel)

            LINE (midX, y)-(midX + sample * halfWidth, y), AudioAnalyzer_InterpolateColor(__AudioAnalyzer.color1, __AudioAnalyzer.color2, ABS(sample))

            i = i + 1
        WEND
    ELSE
        DIM halfHeight AS LONG: halfHeight = h \ 2
        DIM midY AS LONG: midY = t + halfHeight

        WHILE i < w
            DIM x AS LONG: x = l + i
            sample = __AudioAnalyzer_ClipBuffer(((i * __AudioAnalyzer.clipBufferFrames) \ w) * __AudioAnalyzer.channels + channel)

            LINE (x, midY)-(x, midY - sample * halfHeight), AudioAnalyzer_InterpolateColor(__AudioAnalyzer.color1, __AudioAnalyzer.color2, ABS(sample))

            i = i + 1
        WEND
    END IF
END SUB


SUB AudioAnalyzer_RenderVU (l AS LONG, t AS LONG, r AS LONG, b AS LONG, channel AS _UNSIGNED _BYTE)
    SHARED __AudioAnalyzer AS __AudioAnalyzerType
    SHARED AS SINGLE __AudioAnalyzer_IntensityBuffer(), __AudioAnalyzer_PeakBuffer()

    DIM w AS LONG: w = 1 + r - l
    DIM h AS LONG: h = 1 + b - t

    DIM AS LONG size, peak, x, y, xp, yp

    IF h > w THEN
        size = __AudioAnalyzer_IntensityBuffer(channel) * h * 2!
        IF size >= h THEN size = h - 1

        peak = __AudioAnalyzer_PeakBuffer(channel) * h * 2!
        IF peak >= h THEN peak = h - 1

        yp = b - peak
        LINE (l, yp)-(r, yp), __AudioAnalyzer.color2

        y = b - size
        LINE (l, y)-(r, b), AudioAnalyzer_InterpolateColor(__AudioAnalyzer.color1, __AudioAnalyzer.color3, size / h), BF
    ELSE
        size = __AudioAnalyzer_IntensityBuffer(channel) * w * 2!
        IF size >= w THEN size = w - 1

        peak = __AudioAnalyzer_PeakBuffer(channel) * w * 2!
        IF peak >= w THEN peak = w - 1

        IF channel AND 1 THEN
            xp = l + peak
            LINE (xp, t)-(xp, b), __AudioAnalyzer.color2

            x = l + size
            LINE (l, t)-(x, b), AudioAnalyzer_InterpolateColor(__AudioAnalyzer.color1, __AudioAnalyzer.color3, size / w), BF
        ELSE
            xp = r - peak
            LINE (xp, t)-(xp, b), __AudioAnalyzer.color2

            x = r - size
            LINE (x, t)-(r, b), AudioAnalyzer_InterpolateColor(__AudioAnalyzer.color1, __AudioAnalyzer.color3, size / w), BF
        END IF
    END IF
END SUB


SUB AudioAnalyzer_RenderProgress (l AS LONG, t AS LONG, r AS LONG, b AS LONG)
    SHARED __AudioAnalyzer AS __AudioAnalyzerType

    DIM w AS LONG: w = 1 + r - l
    DIM h AS LONG: h = 1 + b - t

    DIM size AS LONG, cf AS SINGLE

    IF h > w THEN
        size = (__AudioAnalyzer.currentTime / __AudioAnalyzer.totalTime) * h
        DIM y AS LONG: y = b - size + 1
        cf = size / h
        LINE (l, t)-(r, y - 1), AudioAnalyzer_InterpolateColor(__AudioAnalyzer.color3, __AudioAnalyzer.color2, cf), BF
        LINE (l, y)-(r, b), AudioAnalyzer_InterpolateColor(__AudioAnalyzer.color1, __AudioAnalyzer.color3, cf), BF
    ELSE
        size = (__AudioAnalyzer.currentTime / __AudioAnalyzer.totalTime) * w
        DIM x AS LONG: x = l + size - 1
        cf = size / w
        LINE (x + 1, t)-(r, b), AudioAnalyzer_InterpolateColor(__AudioAnalyzer.color3, __AudioAnalyzer.color2, cf), BF
        LINE (l, t)-(x, b), AudioAnalyzer_InterpolateColor(__AudioAnalyzer.color1, __AudioAnalyzer.color3, cf), BF

        IF _NEGATE __AudioAnalyzer.progressHideText THEN
            DIM text AS STRING: text = __AudioAnalyzer.currentTimeText + " / " + __AudioAnalyzer.totalTimeText
            DIM textX AS LONG: textX = l + w \ 2 - _UPRINTWIDTH(text) \ 2
            DIM textY AS LONG: textY = t + h \ 2 - _UFONTHEIGHT \ 2
            _UPRINTSTRING (textX, textY), text
        END IF
    END IF
END SUB


SUB AudioAnalyzer_RenderStars (l AS LONG, t AS LONG, r AS LONG, b AS LONG, channel AS _UNSIGNED _BYTE)
    SHARED __AudioAnalyzer AS __AudioAnalyzerType
    SHARED __AudioAnalyzer_Stars() AS __AudioAnalyzer_StarType
    SHARED __AudioAnalyzer_IntensityBuffer() AS SINGLE

    DIM w AS LONG: w = 1 + r - l
    DIM h AS LONG: h = 1 + b - t
    DIM halfW AS LONG: halfW = w \ 2
    DIM halfH AS LONG: halfH = h \ 2
    DIM aX AS SINGLE: aX = h / w
    DIM aY AS SINGLE: aY = w / h

    DIM i AS _UNSIGNED LONG
    WHILE i < __AudioAnalyzer.starCount
        IF __AudioAnalyzer_Stars(channel, i).p.x < 0 _ORELSE __AudioAnalyzer_Stars(channel, i).p.x >= w _ORELSE __AudioAnalyzer_Stars(channel, i).p.y < 0 _ORELSE __AudioAnalyzer_Stars(channel, i).p.y >= h THEN
            __AudioAnalyzer_Stars(channel, i).p.x = AudioAnalyzer_GetRandomBetween(0, w - 1)
            __AudioAnalyzer_Stars(channel, i).p.y = AudioAnalyzer_GetRandomBetween(0, h - 1)
            __AudioAnalyzer_Stars(channel, i).p.z = __AUDIOANALYZER_STAR_Z_DIVIDER
            __AudioAnalyzer_Stars(channel, i).c = _RGB32(AudioAnalyzer_GetRandomBetween(64, 255), AudioAnalyzer_GetRandomBetween(64, 255), AudioAnalyzer_GetRandomBetween(64, 255))
        END IF

        PSET (l + __AudioAnalyzer_Stars(channel, i).p.x, t + __AudioAnalyzer_Stars(channel, i).p.y), __AudioAnalyzer_Stars(channel, i).c

        __AudioAnalyzer_Stars(channel, i).p.z = __AudioAnalyzer_Stars(channel, i).p.z + __AudioAnalyzer_IntensityBuffer(channel) * __AudioAnalyzer.starSpeedMultiplier
        __AudioAnalyzer_Stars(channel, i).a = __AudioAnalyzer_Stars(channel, i).a + __AUDIOANALYZER_STAR_ANGLE_INC
        DIM zd AS SINGLE: zd = __AudioAnalyzer_Stars(channel, i).p.z / __AUDIOANALYZER_STAR_Z_DIVIDER
        __AudioAnalyzer_Stars(channel, i).p.x = ((__AudioAnalyzer_Stars(channel, i).p.x - halfW) * zd) + halfW + COS(__AudioAnalyzer_Stars(channel, i).a * aX)
        __AudioAnalyzer_Stars(channel, i).p.y = ((__AudioAnalyzer_Stars(channel, i).p.y - halfH) * zd) + halfH + SIN(__AudioAnalyzer_Stars(channel, i).a * aY)

        i = i + 1
    WEND
END SUB


SUB AudioAnalyzer_RenderCircleWaves (l AS LONG, t AS LONG, r AS LONG, b AS LONG, channel AS _UNSIGNED _BYTE)
    SHARED __AudioAnalyzer AS __AudioAnalyzerType
    SHARED __AudioAnalyzer_CircleWaves() AS __AudioAnalyzer_CircleWaveType
    SHARED AS SINGLE __AudioAnalyzer_IntensityBuffer()

    DIM w AS LONG: w = 1 + r - l
    DIM h AS LONG: h = 1 + b - t
    DIM radMax AS LONG: radMax = AudioAnalyzer_GetMin(w, h) \ 4
    DIM radMin AS LONG: radMin = radMax \ 8

    VIEW (l, t)-(r, b)

    DIM i AS _UNSIGNED LONG
    FOR i = __AudioAnalyzer.circleWaveCount - 1 TO 0 STEP -1
        __AudioAnalyzer_CircleWaves(channel, i).a = __AudioAnalyzer_CircleWaves(channel, i).a + __AudioAnalyzer_CircleWaves(channel, i).s
        __AudioAnalyzer_CircleWaves(channel, i).r = __AudioAnalyzer_CircleWaves(channel, i).r + __AudioAnalyzer_CircleWaves(channel, i).s * 10!
        __AudioAnalyzer_CircleWaves(channel, i).p.x = __AudioAnalyzer_CircleWaves(channel, i).p.x + __AudioAnalyzer_CircleWaves(channel, i).v.x
        __AudioAnalyzer_CircleWaves(channel, i).p.y = __AudioAnalyzer_CircleWaves(channel, i).p.y + __AudioAnalyzer_CircleWaves(channel, i).v.y

        IF __AudioAnalyzer_CircleWaves(channel, i).a >= 1! THEN
            __AudioAnalyzer_CircleWaves(channel, i).s = __AudioAnalyzer_CircleWaves(channel, i).s * -1!
            __AudioAnalyzer_CircleWaves(channel, i).a = 1!
        ELSEIF __AudioAnalyzer_CircleWaves(channel, i).a <= 0! THEN
            __AudioAnalyzer_CircleWaves(channel, i).a = 0!
            __AudioAnalyzer_CircleWaves(channel, i).r = AudioAnalyzer_GetRandomBetween(radMin, radMax)
            __AudioAnalyzer_CircleWaves(channel, i).p.x = AudioAnalyzer_GetRandomBetween(__AudioAnalyzer_CircleWaves(channel, i).r, w - __AudioAnalyzer_CircleWaves(channel, i).r)
            __AudioAnalyzer_CircleWaves(channel, i).p.y = AudioAnalyzer_GetRandomBetween(__AudioAnalyzer_CircleWaves(channel, i).r, h - __AudioAnalyzer_CircleWaves(channel, i).r)
            __AudioAnalyzer_CircleWaves(channel, i).v.x = (RND - RND) / 3!
            __AudioAnalyzer_CircleWaves(channel, i).v.y = (RND - RND) / 3!
            __AudioAnalyzer_CircleWaves(channel, i).s = AudioAnalyzer_GetRandomBetween(1, 100) / 4000!
            __AudioAnalyzer_CircleWaves(channel, i).c.r = AudioAnalyzer_GetRandomBetween(0, 128)
            __AudioAnalyzer_CircleWaves(channel, i).c.g = AudioAnalyzer_GetRandomBetween(0, 128)
            __AudioAnalyzer_CircleWaves(channel, i).c.b = AudioAnalyzer_GetRandomBetween(0, 128)
        END IF

        AudioAnalyzer_DrawFilledCircle __AudioAnalyzer_CircleWaves(channel, i).p.x, __AudioAnalyzer_CircleWaves(channel, i).p.y, __AudioAnalyzer_CircleWaves(channel, i).r + __AudioAnalyzer_CircleWaves(channel, i).r * __AudioAnalyzer_IntensityBuffer(channel) * __AudioAnalyzer.circleWaveRadiusMultiplier, _RGB32(__AudioAnalyzer_CircleWaves(channel, i).c.r, __AudioAnalyzer_CircleWaves(channel, i).c.g, __AudioAnalyzer_CircleWaves(channel, i).c.b, 255! * __AudioAnalyzer_CircleWaves(channel, i).a)
    NEXT i

    VIEW
END SUB


SUB AudioAnalyzer_RenderRadialSparks (l AS LONG, t AS LONG, r AS LONG, b AS LONG, channel AS _UNSIGNED _BYTE)
    SHARED __AudioAnalyzer AS __AudioAnalyzerType
    SHARED AS SINGLE __AudioAnalyzer_ClipBuffer()

    DIM w AS LONG: w = 1 + r - l
    DIM h AS LONG: h = 1 + b - t
    DIM cx AS LONG: cx = w \ 2
    DIM cy AS LONG: cy = h \ 2
    DIM maxLength AS LONG: maxLength = AudioAnalyzer_GetMax(w, h)

    VIEW (l, t)-(r, b)

    DIM AS LONG angle, x2, y2
    DIM length AS SINGLE

    FOR angle = 0 TO 359 STEP 6
        DIM sample AS SINGLE: sample = __AudioAnalyzer_ClipBuffer(((angle * __AudioAnalyzer.clipBufferFrames) \ 360) * __AudioAnalyzer.channels + channel)

        length = maxLength * sample

        x2 = cx + COS(angle) * length
        y2 = cy + SIN(angle) * length

        LINE (cx, cy)-(x2, y2), AudioAnalyzer_InterpolateColor(__AudioAnalyzer.color1, __AudioAnalyzer.color2, sample)
    NEXT angle

    VIEW
END SUB


SUB AudioAnalyzer_RenderTeslaCoil (l AS LONG, t AS LONG, r AS LONG, b AS LONG, channel AS _UNSIGNED _BYTE)
    SHARED __AudioAnalyzer AS __AudioAnalyzerType
    SHARED __AudioAnalyzer_IntensityBuffer() AS SINGLE

    DIM w AS LONG: w = 1 + r - l
    DIM h AS LONG: h = 1 + b - t
    DIM cx AS LONG: cx = w \ 2
    DIM cy AS LONG: cy = h \ 2
    DIM maxLength AS LONG: maxLength = AudioAnalyzer_GetMax(w, h)
    DIM intensity AS SINGLE: intensity = __AudioAnalyzer_IntensityBuffer(channel) * 2!

    DIM AS LONG i, j, x2, y2
    DIM AS SINGLE angle, branchAngle, length, branchLength

    VIEW (l, t)-(r, b)

    FOR i = 1 TO 12
        angle = RND * _PI(2!)
        length = RND * maxLength * intensity

        x2 = cx + COS(angle) * length
        y2 = cy + SIN(angle) * length

        LINE (cx, cy)-(x2, y2), AudioAnalyzer_InterpolateColor(__AudioAnalyzer.color1, __AudioAnalyzer.color3, intensity)

        FOR j = 1 TO 6
            branchAngle = angle + _PI(RND - 0.5!) / 2!
            branchLength = RND * length / 2!

            LINE (x2, y2)-(x2 + COS(branchAngle) * branchLength, y2 + SIN(branchAngle) * branchLength), AudioAnalyzer_InterpolateColor(__AudioAnalyzer.color3, __AudioAnalyzer.color2, intensity)
        NEXT j
    NEXT i

    VIEW
END SUB


' Adapted from Bubble Universe by Paul Dunn (ZXDunny)
SUB AudioAnalyzer_RenderBubbleUniverse (l AS LONG, t AS LONG, r AS LONG, b AS LONG, channel AS _UNSIGNED _BYTE)
    SHARED __AudioAnalyzer AS __AudioAnalyzerType
    SHARED AS SINGLE __AudioAnalyzer_IntensityBuffer(), __AudioAnalyzer_PeakBuffer()

    STATIC sT AS SINGLE

    DIM w AS LONG: w = 1 + r - l
    DIM h AS LONG: h = 1 + b - t
    DIM cx AS LONG: cx = w \ 2
    DIM cy AS LONG: cy = h \ 2

    DIM AS LONG ax, ay

    IF __AudioAnalyzer.bubbleUniverseNoStretch THEN
        ax = AudioAnalyzer_GetMin(cx, cy)
        ay = ax
    ELSE
        ax = cx
        ay = cy
    END IF

    DIM AS LONG i, j
    DIM AS SINGLE x, u, v

    FOR i = 0 TO 200
        FOR j = 0 TO 200
            u = SIN(i + v) + SIN(_PI(2! / 235!) * i + x)
            v = COS(i + v) + COS(_PI(2! / 235!) * i + x)
            x = u + sT

            PSET (l + cx + u * ax * 0.5!, t + cy + v * ay * 0.5!), _RGB32(i, j, 255! * __AudioAnalyzer_PeakBuffer(channel))
        NEXT
    NEXT

    sT = sT + __AudioAnalyzer_IntensityBuffer(channel)
END SUB


SUB AudioAnalyzer_RenderCircularWaveform (l AS LONG, t AS LONG, r AS LONG, b AS LONG, channel AS _UNSIGNED _BYTE)
    SHARED __AudioAnalyzer AS __AudioAnalyzerType
    SHARED __AudioAnalyzer_ClipBuffer() AS SINGLE

    DIM w AS LONG: w = 1 + r - l
    DIM h AS LONG: h = 1 + b - t
    DIM cx AS LONG: cx = w \ 2
    DIM cy AS LONG: cy = h \ 2
    DIM radius AS LONG: radius = AudioAnalyzer_GetMin(w, h) \ 3
    DIM angleStep AS SINGLE: angleStep = _PI(2!) / __AudioAnalyzer.clipBufferFrames

    VIEW (l, t)-(r, b)

    DIM AS LONG i

    WHILE i < __AudioAnalyzer.clipBufferFrames
        DIM amplitude AS SINGLE: amplitude = __AudioAnalyzer_ClipBuffer(i * __AudioAnalyzer.channels + channel)
        DIM angle AS SINGLE: angle = i * angleStep
        DIM x AS LONG: x = cx + COS(angle) * (radius + amplitude * radius)
        DIM y AS LONG: y = cy + SIN(angle) * (radius + amplitude * radius)

        IF i > 0 THEN
            LINE -(x, y), AudioAnalyzer_InterpolateColor(__AudioAnalyzer.color1, __AudioAnalyzer.color2, ABS(amplitude))
        ELSE
            PSET (x, y), AudioAnalyzer_InterpolateColor(__AudioAnalyzer.color1, __AudioAnalyzer.color2, ABS(amplitude))
        END IF

        i = i + 1
    WEND

    VIEW
END SUB


SUB AudioAnalyzer_Update
    SHARED __AudioAnalyzer AS __AudioAnalyzerType
    SHARED AS SINGLE __AudioAnalyzer_ClipBuffer(), __AudioAnalyzer_FFTBuffer(), __AudioAnalyzer_IntensityBuffer(), __AudioAnalyzer_PeakBuffer()

    DIM AS LONG hours, minutes, seconds

    IF __AudioAnalyzer.handle THEN
        __AudioAnalyzer.currentTime = _SNDGETPOS(__AudioAnalyzer.handle)
        __AudioAnalyzer.currentFrame = __AudioAnalyzer_CLngPtr(__AudioAnalyzer.currentTime * _SNDRATE)

        hours = __AudioAnalyzer.currentTime \ 3600
        minutes = (__AudioAnalyzer.currentTime - hours * 3600) \ 60
        seconds = __AudioAnalyzer.currentTime - hours * 3600 - minutes * 60
        __AudioAnalyzer.currentTimeText = RIGHT$("0" + LTRIM$(STR$(hours)), 2) + ":" + RIGHT$("0" + LTRIM$(STR$(minutes)), 2) + ":" + RIGHT$("0" + LTRIM$(STR$(seconds)), 2)

        IF __AudioAnalyzer.isLengthQueryPending _ORELSE __AudioAnalyzer.currentFrame > __AudioAnalyzer.totalFrames THEN
            DIM totalTime AS DOUBLE: totalTime = _SNDLEN(__AudioAnalyzer.handle)
            __AudioAnalyzer.isLengthQueryPending = (totalTime <> __AudioAnalyzer.totalTime _ORELSE totalTime = 0#)
            __AudioAnalyzer.totalTime = totalTime
            __AudioAnalyzer.totalFrames = __AudioAnalyzer_CLngPtr(__AudioAnalyzer.totalTime * _SNDRATE)

            hours = __AudioAnalyzer.totalTime \ 3600
            minutes = (__AudioAnalyzer.totalTime - hours * 3600) \ 60
            seconds = __AudioAnalyzer.totalTime - hours * 3600 - minutes * 60
            __AudioAnalyzer.totalTimeText = RIGHT$("0" + LTRIM$(STR$(hours)), 2) + ":" + RIGHT$("0" + LTRIM$(STR$(minutes)), 2) + ":" + RIGHT$("0" + LTRIM$(STR$(seconds)), 2)
        END IF

        DIM i AS _UNSIGNED LONG
        DIM byteOffset AS _UNSIGNED _OFFSET: byteOffset = __AudioAnalyzer.buffer.OFFSET + __AudioAnalyzer.currentFrame * __AudioAnalyzer.buffer.ELEMENTSIZE

        IF byteOffset <= __AudioAnalyzer.buffer.OFFSET + __AudioAnalyzer.buffer.SIZE - __AudioAnalyzer.clipBufferSamples * __AudioAnalyzer.buffer.ELEMENTSIZE THEN
            SELECT CASE __AudioAnalyzer.format
                CASE __AUDIOANALYZER_FORMAT_U8
                    WHILE i < __AudioAnalyzer.clipBufferSamples
                        __AudioAnalyzer_ClipBuffer(i) = __AudioAnalyzer_CByte(_MEMGET(__AudioAnalyzer.buffer, byteOffset, _UNSIGNED _BYTE) XOR &H80) * __AUDIOANALYZER_S8_TO_F32
                        byteOffset = byteOffset + __AUDIOANALYZER_SIZEOF_BYTE
                        i = i + 1
                    WEND

                CASE __AUDIOANALYZER_FORMAT_S16
                    WHILE i < __AudioAnalyzer.clipBufferSamples
                        __AudioAnalyzer_ClipBuffer(i) = _MEMGET(__AudioAnalyzer.buffer, byteOffset, INTEGER) * __AUDIOANALYZER_S16_TO_F32
                        byteOffset = byteOffset + __AUDIOANALYZER_SIZEOF_INTEGER
                        i = i + 1
                    WEND

                CASE __AUDIOANALYZER_FORMAT_S32
                    WHILE i < __AudioAnalyzer.clipBufferSamples
                        __AudioAnalyzer_ClipBuffer(i) = _MEMGET(__AudioAnalyzer.buffer, byteOffset, LONG) * __AUDIOANALYZER_S32_TO_F32
                        byteOffset = byteOffset + __AUDIOANALYZER_SIZEOF_LONG
                        i = i + 1
                    WEND

                CASE __AUDIOANALYZER_FORMAT_F32
                    __AudioAnalyzer_MemCpy _OFFSET(__AudioAnalyzer_ClipBuffer(0)), byteOffset, __AudioAnalyzer.clipBufferSamples * __AUDIOANALYZER_SIZEOF_SINGLE
            END SELECT

            i = 0
            WHILE i < __AudioAnalyzer.channels
                __AudioAnalyzer_IntensityBuffer(i) = AudioAnalyzer_FFT(__AudioAnalyzer_ClipBuffer(), i, __AudioAnalyzer.channels, __AudioAnalyzer_FFTBuffer())
                IF __AudioAnalyzer_IntensityBuffer(i) > __AudioAnalyzer_PeakBuffer(i) THEN __AudioAnalyzer_PeakBuffer(i) = __AudioAnalyzer_IntensityBuffer(i)
                __AudioAnalyzer_PeakBuffer(i) = __AudioAnalyzer_PeakBuffer(i) - __AudioAnalyzer.vuPeakFallSpeed
                IF __AudioAnalyzer_PeakBuffer(i) <= 0! THEN __AudioAnalyzer_PeakBuffer(i) = 0!
                i = i + 1
            WEND
        END IF
    END IF
END SUB


SUB AudioAnalyzer_Render (l AS LONG, t AS LONG, r AS LONG, b AS LONG, channel AS _UNSIGNED _BYTE)
    SHARED __AudioAnalyzer AS __AudioAnalyzerType

    LINE (l - 1, t - 1)-(r + 1, b + 1), , B

    IF __AudioAnalyzer.handle THEN
        IF __AudioAnalyzer.format = __AUDIOANALYZER_FORMAT_UNKNOWN THEN
            AudioAnalyzer_RenderProgress l, t, r, b
        ELSE
            SELECT CASE __AudioAnalyzer.style
                CASE AUDIOANALYZER_STYLE_OSCILLOSCOPE1
                    AudioAnalyzer_RenderOscilloscope1 l, t, r, b, channel

                CASE AUDIOANALYZER_STYLE_OSCILLOSCOPE2
                    AudioAnalyzer_RenderOscilloscope2 l, t, r, b, channel

                CASE AUDIOANALYZER_STYLE_VU
                    AudioAnalyzer_RenderVU l, t, r, b, channel

                CASE AUDIOANALYZER_STYLE_SPECTRUM
                    AudioAnalyzer_RenderSpectrum l, t, r, b, channel

                CASE AUDIOANALYZER_STYLE_CIRCULAR_WAVEFORM
                    AudioAnalyzer_RenderCircularWaveform l, t, r, b, channel

                CASE AUDIOANALYZER_STYLE_RADIAL_SPARKS
                    AudioAnalyzer_RenderRadialSparks l, t, r, b, channel

                CASE AUDIOANALYZER_STYLE_TESLA_COIL
                    AudioAnalyzer_RenderTeslaCoil l, t, r, b, channel

                CASE AUDIOANALYZER_STYLE_CIRCLE_WAVES
                    AudioAnalyzer_RenderCircleWaves l, t, r, b, channel

                CASE AUDIOANALYZER_STYLE_STARS
                    AudioAnalyzer_RenderStars l, t, r, b, channel

                CASE AUDIOANALYZER_STYLE_BUBBLE_UNIVERSE
                    AudioAnalyzer_RenderBubbleUniverse l, t, r, b, channel

                CASE ELSE
                    AudioAnalyzer_RenderProgress l, t, r, b
            END SELECT
        END IF
    END IF
END SUB
