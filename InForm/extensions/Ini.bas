'-----------------------------------------------------------------------------------------------------------------------
' INI Manager
' Copyright (c) 2024 Samuel Gomes
' Copyright (c) 2022 Fellippe Heitor
'-----------------------------------------------------------------------------------------------------------------------

$INCLUDEONCE

'$INCLUDE:'Ini.bi'

SUB Ini_SortSection (file$, __section$)
    SHARED __ini AS __IniType

    REDIM keys(1 TO 100) AS STRING
    DIM totalKeys AS LONG, tempValue$, i AS LONG, backup$, commitBackup AS _BYTE

    IF __Ini_FormatSection$(__section$) = "[]" THEN __ini.code = 15: EXIT SUB

    DO
        tempValue$ = Ini_ReadSetting(file$, __section$, "")
        IF LEFT$(Ini_GetInfo, 7) = "ERROR: " THEN EXIT SUB
        IF __ini.code = 10 THEN EXIT DO

        totalKeys = totalKeys + 1
        IF totalKeys > UBOUND(keys) THEN
            REDIM _PRESERVE keys(1 TO UBOUND(keys) + 100) AS STRING
        END IF

        keys(totalKeys) = __ini.lastKey + "=" + tempValue$
    LOOP

    REDIM _PRESERVE keys(1 TO totalKeys) AS STRING
    IF __Ini_SortArray(keys()) = 0 THEN __ini.code = 23: EXIT SUB

    commitBackup = __ini.disableAutoCommit
    __ini.disableAutoCommit = -1 'Prevent every minor change from being written to disk
    backup$ = __ini.wholeFile$

    FOR i = 1 TO totalKeys
        Ini_DeleteKey file$, __section$, LEFT$(keys(i), INSTR(keys(i), "=") - 1)
        IF LEFT$(Ini_GetInfo, 7) = "ERROR: " THEN
            __ini.disableAutoCommit = commitBackup
            __ini.wholeFile$ = backup$
            EXIT SUB
        END IF
    NEXT

    FOR i = 1 TO totalKeys
        Ini_WriteSetting file$, __section$, LEFT$(keys(i), INSTR(keys(i), "=") - 1), MID$(keys(i), INSTR(keys(i), "=") + 1)
        IF LEFT$(Ini_GetInfo, 7) = "ERROR: " THEN
            __ini.disableAutoCommit = commitBackup
            __ini.wholeFile$ = backup$
            EXIT SUB
        END IF
    NEXT

    __ini.disableAutoCommit = commitBackup ' Restore writing to disk (or previously set state) and
    __Ini_Commit ' commit changes.

    __ini.code = 22
END SUB

SUB Ini_DeleteSection (file$, __section$)
    SHARED __ini AS __IniType

    Ini_Load file$
    IF __ini.code THEN EXIT SUB

    __ini.code = 0
    DIM a$: a$ = __Ini_GetSectionData(__section$)
    IF __ini.code THEN EXIT SUB

    __ini.newFile = LEFT$(__ini.wholeFile, INSTR(__ini.wholeFile, a$) - 1)
    __ini.newFile = __ini.newFile + MID$(__ini.wholeFile, INSTR(__ini.wholeFile, a$) + LEN(a$ + __ini.LF$))

    __Ini_Commit
    __ini.code = 13
END SUB

SUB Ini_DeleteKey (file$, __section$, __key$)
    SHARED __ini AS __IniType

    DIM tempValue$
    DIM section$, key$
    DIM foundLF AS _UNSIGNED LONG

    __ini.code = 0

    'prepare variables for the write operation
    section$ = __Ini_FormatSection(__section$)
    IF __ini.code THEN EXIT SUB

    key$ = _TRIM$(__key$)
    IF key$ = "" THEN __ini.code = 12: EXIT SUB
    __ini.lastKey = key$

    'Read the existing key to fill __ini.position
    tempValue$ = Ini_ReadSetting(file$, section$, key$)
    IF __ini.code > 0 AND __ini.code <> 2 THEN EXIT SUB 'key not found

    'map __ini.position (set in the section block) to the global file position
    __ini.position = INSTR(__ini.wholeFile, __ini.sectionData) + __ini.position - 1

    foundLF = INSTR(__ini.position, __ini.wholeFile, __ini.LF)
    IF foundLF = 0 THEN foundLF = LEN(__ini.wholeFile)

    __ini.newFile = LEFT$(__ini.wholeFile, __ini.position - 1) + MID$(__ini.wholeFile, foundLF + LEN(__ini.LF))

    __Ini_Commit
    __ini.code = 19
END SUB

'A move operation is a copy operation + a delete operation
SUB Ini_MoveKey (file$, __section$, __key$, __newsection$)
    SHARED __ini AS __IniType

    DIM tempValue$

    tempValue$ = Ini_ReadSetting(file$, __section$, __key$)
    IF __ini.code > 0 AND __ini.code <> 2 THEN EXIT SUB

    Ini_WriteSetting file$, __newsection$, __key$, tempValue$
    IF __ini.code > 0 AND __ini.code <> 2 AND __ini.code <> 7 AND __ini.code <> 9 THEN EXIT SUB

    Ini_DeleteKey file$, __section$, __key$
    IF __ini.code = 19 THEN __ini.code = 20
END SUB

SUB __Ini_Commit
    SHARED __ini AS __IniType

    IF __ini.currentFileName = "" THEN __ini.code = 18: EXIT SUB

    __ini.wholeFile = __ini.newFile
    __ini.currentFileLOF = LEN(__ini.newFile)

    IF NOT __ini.disableAutoCommit THEN
        DIM AS LONG fileNum, findFile

        'search __ini.loadedFiles, so we use the same file handle every time
        findFile = INSTR(__ini.loadedFiles, "@" + __ini.currentFileName + "@")
        IF findFile = 0 THEN
            fileNum = FREEFILE
            __ini.loadedFiles = __ini.loadedFiles + "@" + MKI$(fileNum) + "@" + __ini.currentFileName + "@"
        ELSE
            fileNum = CVI(MID$(__ini.loadedFiles, findFile - 2, 2))
            CLOSE fileNum
        END IF

        OPEN __ini.currentFileName FOR BINARY AS #fileNum

        IF LEN(__ini.wholeFile) < LOF(fileNum) THEN
            CLOSE fileNum
            OPEN __ini.currentFileName FOR OUTPUT AS #fileNum: CLOSE #fileNum
            OPEN __ini.currentFileName FOR BINARY AS #fileNum
        END IF

        PUT #fileNum, 1, __ini.newFile
        CLOSE #fileNum 'flush
        OPEN __ini.currentFileName FOR BINARY AS #fileNum 'keep open
    END IF
END SUB

FUNCTION __Ini_GetSectionData$ (__section$)
    SHARED __ini AS __IniType

    IF __ini.currentFileName = "" THEN __ini.code = 18: EXIT FUNCTION
    IF __ini.currentFileLOF = 0 OR LEN(_TRIM$(__ini.wholeFile)) = 0 THEN __ini.code = 17: EXIT FUNCTION

    __ini.code = 0

    DIM section$, foundSection AS _UNSIGNED LONG, endSection AS _UNSIGNED LONG
    DIM i AS _UNSIGNED LONG, Bracket1 AS _UNSIGNED LONG, sectionStart AS _UNSIGNED LONG
    DIM inQuote AS _BYTE

    section$ = __Ini_FormatSection(__section$)
    IF __ini.code THEN EXIT FUNCTION

    IF section$ = "[]" THEN
        'fetch the "global" section, if present
        sectionStart = INSTR(__ini.wholeFile, "[")
        IF sectionStart = 0 THEN __Ini_GetSectionData = __ini.wholeFile: EXIT FUNCTION

        FOR i = sectionStart - 1 TO 1 STEP -1
            IF ASC(__ini.wholeFile, i) = 10 THEN foundSection = i + 1: EXIT FOR
            IF ASC(__ini.wholeFile, i) <> 32 THEN EXIT FOR
        NEXT

        IF i = 0 THEN foundSection = 1

        __Ini_GetSectionData = LEFT$(__ini.wholeFile, foundSection - 1)
    ELSE
        DO
            sectionStart = INSTR(sectionStart + 1, LCASE$(__ini.wholeFile), LCASE$(section$))
            IF sectionStart = 0 THEN __ini.code = 14: EXIT DO

            'make sure it's a valid section header
            foundSection = 0
            FOR i = sectionStart - 1 TO 1 STEP -1
                IF ASC(__ini.wholeFile, i) = 10 THEN foundSection = i + 1: EXIT FOR
                IF ASC(__ini.wholeFile, i) <> 32 THEN EXIT FOR
            NEXT

            IF i = 0 THEN foundSection = 1

            IF foundSection > 0 THEN
                'we found it; time to identify where this section ends
                '(either another [section] or the end of the file
                Bracket1 = sectionStart
                checkAgain:
                Bracket1 = INSTR(Bracket1 + 1, __ini.wholeFile, "[")

                IF Bracket1 > 0 THEN
                    'found a bracket; check if it's inside quotes
                    inQuote = 0
                    FOR i = 1 TO Bracket1 - 1
                        IF ASC(__ini.wholeFile, i) = 34 THEN inQuote = NOT inQuote
                    NEXT
                    IF inQuote THEN GOTO checkAgain

                    FOR i = Bracket1 - 1 TO 1 STEP -1
                        IF ASC(__ini.wholeFile, i) = 10 THEN endSection = i + 1 - LEN(__ini.LF): EXIT FOR
                        IF ASC(__ini.wholeFile, i) = 61 THEN GOTO checkAgain 'bracket is inside a key's value
                        IF i <= foundSection THEN EXIT FOR
                    NEXT
                    __Ini_GetSectionData = MID$(__ini.wholeFile, foundSection, endSection - foundSection)
                ELSE
                    __Ini_GetSectionData = MID$(__ini.wholeFile, foundSection)
                END IF
                EXIT FUNCTION
            END IF
        LOOP
    END IF
END FUNCTION

FUNCTION __Ini_FormatSection$ (__section$)
    SHARED __ini AS __IniType

    DIM section$

    section$ = _TRIM$(__section$)

    'sections are in the format [section name] - add brackets if not passed
    IF LEFT$(section$, 1) <> "[" THEN section$ = "[" + section$
    IF RIGHT$(section$, 1) <> "]" THEN section$ = section$ + "]"

    IF INSTR(MID$(section$, 2, LEN(section$) - 3), "[") OR INSTR(MID$(section$, 2, LEN(section$) - 3), "]") THEN
        __ini.code = 15
        EXIT FUNCTION
    END IF

    __Ini_FormatSection = section$
END FUNCTION

FUNCTION Ini_ReadSetting$ (file$, __section$, __key$)
    SHARED __ini AS __IniType

    Ini_Load file$
    IF __ini.code THEN EXIT FUNCTION

    IF __ini.currentFileLOF = 0 OR LEN(_TRIM$(__ini.wholeFile)) = 0 THEN __ini.code = 17: EXIT FUNCTION

    DIM Equal AS _UNSIGNED LONG, tempValue$, key$, section$
    DIM Quote AS _UNSIGNED LONG, Comment AS _UNSIGNED LONG
    DIM i AS LONG, FoundLF AS _UNSIGNED LONG

    section$ = __Ini_FormatSection(__section$)
    IF __ini.code THEN EXIT FUNCTION

    'fetch the desired section$
    __ini.sectionData = __Ini_GetSectionData(section$)
    IF __ini.code > 0 AND __ini.code <> 17 THEN EXIT FUNCTION

    IF LEN(__ini.sectionData) = 0 AND section$ <> "[]" THEN __ini.code = 14: EXIT FUNCTION

    __ini.lastSection = section$

    __ini.position = 0

    key$ = _TRIM$(__key$)
    __ini.lastKey = ""
    IF key$ = "" THEN
        IF section$ = "[]" THEN __ini.sectionData = __ini.wholeFile
        key$ = Ini_GetNextKey
        IF __ini.code THEN EXIT FUNCTION
        IF key$ = "" THEN
            __ini.code = 10
            EXIT FUNCTION
        END IF
    END IF

    IF LEFT$(key$, 1) = ";" OR LEFT$(key$, 1) = "'" OR INSTR(key$, "[") > 0 OR INSTR(key$, "]") > 0 OR INSTR(key$, "=") > 0 THEN
        __ini.code = 12
        EXIT FUNCTION
    END IF

    __ini.lastKey = key$

    IF __ini.position > 0 THEN Equal = __ini.position: GOTO KeyFound
    CheckKey:
    __ini.position = INSTR(__ini.position + 1, LCASE$(__ini.sectionData), LCASE$(key$))

    IF __ini.position > 0 THEN
        'identify if this occurrence is actually a key and not part of a key name/value
        FOR i = __ini.position - 1 TO 1 STEP -1
            IF ASC(__ini.sectionData, i) = 10 THEN EXIT FOR
            IF ASC(__ini.sectionData, i) <> 10 AND ASC(__ini.sectionData, i) <> 32 THEN
                'not a key
                GOTO CheckKey
            END IF
        NEXT

        'check if there's nothing but an equal sign ahead
        FOR i = __ini.position + LEN(key$) TO LEN(__ini.sectionData)
            IF ASC(__ini.sectionData, i) = ASC("=") THEN EXIT FOR
            IF ASC(__ini.sectionData, i) <> ASC("=") AND ASC(__ini.sectionData, i) <> 32 THEN
                'not the key
                GOTO CheckKey
            END IF
        NEXT

        'so far so good; check if there is an assignment
        Equal = INSTR(__ini.position, __ini.sectionData, "=")
        KeyFound:
        FoundLF = INSTR(__ini.position, __ini.sectionData, __ini.LF)

        IF FoundLF > 0 THEN
            IF Equal > FoundLF THEN GOTO CheckKey
        ELSE
            FoundLF = LEN(__ini.sectionData) + 1
            IF Equal = 0 THEN GOTO CheckKey
        END IF

        tempValue$ = _TRIM$(MID$(__ini.sectionData, Equal + 1, FoundLF - Equal - 1))

        IF LEN(tempValue$) > 0 THEN
            IF LEFT$(tempValue$, 1) = CHR$(34) THEN
                tempValue$ = MID$(tempValue$, 2)
                Quote = INSTR(tempValue$, CHR$(34))
                IF Quote > 0 THEN
                    tempValue$ = LEFT$(tempValue$, Quote - 1)
                END IF
            ELSE
                Comment = INSTR(tempValue$, "#")
                IF Comment = 0 THEN Comment = INSTR(tempValue$, ";")
                IF Comment > 0 THEN
                    tempValue$ = _TRIM$(LEFT$(tempValue$, Comment - 1))
                END IF
            END IF
        ELSE
            __ini.code = 2
        END IF
    ELSE
        __ini.code = 3
        EXIT FUNCTION
    END IF

    Ini_ReadSetting = tempValue$
    __ini.lastSection = Ini_GetCurrentSection
END FUNCTION

FUNCTION Ini_GetCurrentSection$
    SHARED __ini AS __IniType

    DIM GlobalPosition AS _UNSIGNED LONG, i AS _UNSIGNED LONG
    DIM ClosingBracket AS _UNSIGNED LONG

    GlobalPosition = INSTR(__ini.wholeFile, __ini.sectionData) + __ini.position - 1

    CheckSection:
    FOR i = GlobalPosition - 1 TO 1 STEP -1
        IF ASC(__ini.wholeFile, i) = ASC("[") THEN
            GlobalPosition = i: EXIT FOR
        END IF
    NEXT

    IF i = 0 THEN Ini_GetCurrentSection = "[]": EXIT FUNCTION

    'identify if this occurrence is actually a section header and not something else
    FOR i = GlobalPosition - 1 TO 1 STEP -1
        IF ASC(__ini.wholeFile, i) = 10 THEN EXIT FOR
        IF ASC(__ini.wholeFile, i) <> 10 AND ASC(__ini.wholeFile, i) <> 32 THEN
            'not a section header
            GOTO CheckSection
        END IF
    NEXT

    ClosingBracket = INSTR(GlobalPosition, __ini.wholeFile, "]")
    IF ClosingBracket > 0 THEN
        Ini_GetCurrentSection = MID$(__ini.wholeFile, GlobalPosition, ClosingBracket - GlobalPosition + 1)
    END IF
END FUNCTION

SUB Ini_WriteSetting (file$, __section$, __key$, __value$)
    SHARED __ini AS __IniType

    DIM tempValue$, section$, key$, value$

    __ini.code = 0

    'prepare variables for the write operation
    section$ = __Ini_FormatSection(__section$)
    IF __ini.code THEN EXIT SUB

    key$ = _TRIM$(__key$)
    IF key$ = "" THEN __ini.code = 12: EXIT SUB
    __ini.lastKey = key$

    value$ = _TRIM$(__value$)
    IF LTRIM$(STR$(VAL(value$))) <> value$ THEN
        'if not a numeric value and value contains spaces, add quotation marks
        IF INSTR(value$, CHR$(32)) THEN value$ = CHR$(34) + value$ + CHR$(34)
    END IF

    'Read the existing key to fill __ini.position
    tempValue$ = Ini_ReadSetting$(file$, section$, key$)

    'map __ini.position (set in the section block) to the global file position
    __ini.position = INSTR(__ini.wholeFile, __ini.sectionData) + __ini.position - 1

    IF __ini.code = 1 OR __ini.code = 17 THEN
        'file not found or empty; create a new one
        IF file$ = "" THEN file$ = __ini.currentFileName
        IF file$ = "" THEN __ini.code = 21: EXIT SUB

        __ini.currentFileName = file$

        IF section$ <> "[]" THEN
            __ini.newFile = section$ + __ini.LF
        END IF

        __ini.newFile = __ini.newFile + key$ + "=" + value$

        __ini.code = 0
        __Ini_Commit
        Ini_Load file$
        IF __ini.code = 0 THEN __ini.code = 11
        __ini.lastSection = section$
        EXIT SUB
    END IF

    IF __ini.code = 0 OR __ini.code = 2 THEN 'key found and read back; write new value$
        IF LCASE$(__ini.lastSection) = LCASE$(section$) THEN
            IF _TRIM$(__value$) = tempValue$ AND LEN(_TRIM$(__value$)) > 0 THEN
                'identical values skip the writing routine
                __ini.code = 8
                EXIT SUB
            END IF

            DIM nextLine AS _UNSIGNED LONG
            nextLine = INSTR(__ini.position + 1, __ini.wholeFile, __ini.LF)

            'create new file contents
            __ini.newFile = LEFT$(__ini.wholeFile, __ini.position - 1)
            __ini.newFile = __ini.newFile + key$ + "=" + value$

            IF nextLine > 0 THEN
                __ini.newFile = __ini.newFile + MID$(__ini.wholeFile, nextLine)
            END IF

            __Ini_Commit

            __ini.code = 4
        END IF
    ELSEIF __ini.code = 3 OR __ini.code = 14 THEN 'Key not found, Section not found
        __ini.code = 0
        IF LCASE$(__ini.lastSection) = LCASE$(section$) THEN
            'find this section$ in the current ini file;
            DIM Bracket1 AS _UNSIGNED LONG
            DIM beginSection AS _UNSIGNED LONG, endSection AS _UNSIGNED LONG
            DIM i AS _UNSIGNED LONG

            beginSection = 0
            endSection = 0

            CheckSection:
            beginSection = INSTR(beginSection + 1, LCASE$(__ini.wholeFile), LCASE$(section$))
            IF beginSection = 0 THEN GOTO CreateSection

            'identify if this occurrence is actually the section header and not something else
            FOR i = beginSection - 1 TO 1 STEP -1
                IF ASC(__ini.wholeFile, i) = 10 THEN EXIT FOR
                IF ASC(__ini.wholeFile, i) <> 10 AND ASC(__ini.wholeFile, i) <> 32 THEN
                    'not the section header
                    GOTO CheckSection
                END IF
            NEXT

            'we found it; time to identify where this section ends
            '(either another [section], a blank line or the end of the file
            Bracket1 = INSTR(beginSection + 1, __ini.wholeFile, "[")
            IF Bracket1 > 0 THEN
                FOR i = Bracket1 - 1 TO 1 STEP -1
                    IF ASC(__ini.wholeFile, i) = 10 THEN endSection = i + 1 - LEN(__ini.LF): EXIT FOR
                    IF i <= beginSection THEN EXIT FOR
                NEXT
            END IF

            IF endSection > 0 THEN
                'add values to the end of the specified section$
                __ini.newFile = LEFT$(__ini.wholeFile, endSection - 1)
                __ini.newFile = __ini.newFile + key$ + "=" + value$ + __ini.LF
                IF MID$(__ini.wholeFile, endSection, LEN(__ini.LF)) <> __ini.LF THEN __ini.newFile = __ini.newFile + __ini.LF
                __ini.newFile = __ini.newFile + MID$(__ini.wholeFile, endSection)
            ELSE
                'add values to the end of the file
                __ini.newFile = __ini.wholeFile
                IF RIGHT$(__ini.newFile, LEN(__ini.LF)) = __ini.LF THEN
                    __ini.newFile = __ini.newFile + key$ + "=" + value$
                ELSE
                    __ini.newFile = __ini.newFile + __ini.LF + key$ + "=" + value$
                END IF
            END IF

            __Ini_Commit

            IF __ini.code = 0 THEN __ini.code = 7
            EXIT SUB
        ELSE
            CreateSection:
            __ini.newFile = __ini.wholeFile
            IF section$ = "[]" THEN GOTO WriteAtTop

            IF RIGHT$(__ini.newFile, LEN(__ini.LF) * 2) = __ini.LF + __ini.LF THEN
                __ini.newFile = __ini.newFile + section$ + __ini.LF + key$ + "=" + value$ + __ini.LF
            ELSEIF RIGHT$(__ini.newFile, LEN(__ini.LF)) = __ini.LF THEN
                __ini.newFile = __ini.newFile + __ini.LF + section$ + __ini.LF + key$ + "=" + value$ + __ini.LF
            ELSE
                __ini.newFile = __ini.newFile + __ini.LF + __ini.LF + section$ + __ini.LF + key$ + "=" + value$ + __ini.LF
            END IF

            __Ini_Commit

            IF __ini.code = 0 THEN __ini.code = 9 ELSE __ini.code = 16
            EXIT SUB
        END IF

        'if not found, key$=value$ is written to the beginning of the file
        WriteAtTop:
        __ini.newFile = key$ + "=" + value$ + __ini.LF
        IF LEFT$(LTRIM$(__ini.wholeFile), 1) = "[" THEN __ini.newFile = __ini.newFile + __ini.LF
        __ini.newFile = __ini.newFile + __ini.wholeFile

        __Ini_Commit

        __ini.code = 5
    END IF
END SUB

SUB Ini_SetForceReload (state AS _BYTE)
    SHARED __ini AS __IniType

    __ini.forceReload = (state <> 0)
END SUB

SUB Ini_Close
    SHARED __ini AS __IniType

    DIM AS LONG findFile, fileNum

    IF __ini.currentFileName = "" THEN EXIT SUB

    'search __ini.loadedFiles, so we use the same file handle every time
    findFile = INSTR(__ini.loadedFiles, "@" + __ini.currentFileName + "@")
    IF findFile = 0 THEN
        'not open; nothing to close
        EXIT SUB
    ELSE
        fileNum = CVI(MID$(__ini.loadedFiles, findFile - 2, 2))
        CLOSE fileNum
    END IF

    __ini.disableAutoCommit = 0
    __Ini_Commit

    __ini.currentFileName = ""
END SUB

SUB Ini_Load (file$)
    SHARED __ini AS __IniType

    DIM AS LONG fileNum, findFile

    'Error messages are returned with __ini.code
    'Error descriptions can be fetched with function IniINFO$
    __ini.code = 0

    IF file$ <> "" AND __ini.currentFileName <> file$ THEN __ini.currentFileName = ""

    IF __ini.forceReload AND LEN(__ini.currentFileName) > 0 THEN
        file$ = __ini.currentFileName
        __ini.currentFileName = ""
    END IF

    'Passing an empty file$ is allowed if user already
    'passed a valid file in this session.
    IF __ini.currentFileName = "" THEN
        'initialization
        IF _FILEEXISTS(file$) THEN
            __ini.currentFileName = file$

            'add to __ini.loadedFiles, so we use the same file handle every time
            findFile = INSTR(__ini.loadedFiles, "@" + file$ + "@")
            IF findFile = 0 THEN
                fileNum = FREEFILE
                __ini.loadedFiles = __ini.loadedFiles + "@" + MKI$(fileNum) + "@" + file$ + "@"
            ELSE
                fileNum = CVI(MID$(__ini.loadedFiles, findFile - 2, 2))
            END IF

            'Load file into memory
            CLOSE fileNum
            OPEN __ini.currentFileName FOR BINARY AS #fileNum
            __ini.currentFileLOF = LOF(fileNum)
            __ini.wholeFile = SPACE$(__ini.currentFileLOF)
            GET #fileNum, 1, __ini.wholeFile

            'Check if this ini file uses CRLF or LF
            IF INSTR(__ini.wholeFile, CHR$(13)) THEN __ini.LF = CHR$(13) + CHR$(10) ELSE __ini.LF = CHR$(10)
        ELSE
            IniFileNotFound:
            __ini.code = 1

            $IF WIN THEN
                __ini.LF = CHR$(13) + CHR$(10)
            $ELSE
                __ini.LF = CHR$(10)
            $END IF
            EXIT SUB
        END IF
    ELSEIF NOT _FILEEXISTS(__ini.currentFileName) THEN
        __ini.currentFileName = ""
        GOTO IniFileNotFound
    END IF
END SUB

FUNCTION Ini_GetNextKey$
    SHARED __ini AS __IniType

    STATIC lastDataBlock$, position AS _UNSIGNED LONG, tempLF$

    IF __ini.currentFileName = "" THEN __ini.code = 18: EXIT FUNCTION

    IF __ini.sectionData <> lastDataBlock$ THEN
        position = 0
        lastDataBlock$ = __ini.sectionData

        'data blocks must end with a line feed for parsing purposes
        IF RIGHT$(__ini.sectionData, LEN(__ini.LF)) <> __ini.LF THEN tempLF$ = __ini.LF ELSE tempLF$ = ""
    END IF

    DIM Equal AS _UNSIGNED LONG, tempKey$

    FindKey:
    Equal = INSTR(position, __ini.sectionData + tempLF$, "=")
    IF Equal = 0 THEN position = 0: EXIT FUNCTION

    tempKey$ = _TRIM$(MID$(__ini.sectionData + tempLF$, position + 1, Equal - position - 1))

    IF INSTR(tempKey$, CHR$(10)) > 0 THEN
        position = position + INSTR(tempKey$, CHR$(10)) + 1
        tempKey$ = MID$(tempKey$, INSTR(tempKey$, CHR$(10)) + 1)
    END IF

    DO WHILE LEFT$(tempKey$, LEN(__ini.LF)) = __ini.LF
        tempKey$ = MID$(tempKey$, LEN(__ini.LF) + 1)
        position = position + LEN(__ini.LF)
    LOOP

    position = INSTR(position + 1, __ini.sectionData + tempLF$, __ini.LF)

    IF LEFT$(tempKey$, 1) = ";" OR LEFT$(tempKey$, 1) = "'" OR INSTR(tempKey$, "[") > 0 OR INSTR(tempKey$, "]") > 0 OR INSTR(tempKey$, "=") > 0 THEN
        GOTO FindKey
    END IF

    Ini_GetNextKey = tempKey$
    __ini.position = Equal
END FUNCTION

FUNCTION Ini_GetNextSection$ (file$)
    SHARED __ini AS __IniType

    STATIC sectionStart AS _UNSIGNED LONG

    Ini_Load file$
    IF LEFT$(Ini_GetInfo, 6) = "ERROR:" THEN EXIT FUNCTION

    __ini.code = 0

    DIM foundSection AS _UNSIGNED LONG, endSection AS _UNSIGNED LONG
    DIM i AS _UNSIGNED LONG, Bracket1 AS _UNSIGNED LONG, Bracket2 AS _UNSIGNED LONG

    FindNext:
    sectionStart = INSTR(sectionStart + 1, __ini.wholeFile, "[")
    IF sectionStart = 0 THEN __ini.code = 24: EXIT FUNCTION

    'make sure it's a valid section header
    foundSection = 0
    FOR i = sectionStart - 1 TO 1 STEP -1
        IF ASC(__ini.wholeFile, i) = 10 THEN foundSection = i + 1: EXIT FOR
        IF ASC(__ini.wholeFile, i) <> 32 THEN GOTO FindNext
    NEXT

    IF i = 0 THEN foundSection = 1

    IF foundSection > 0 THEN
        'we found it; time to identify where this section ends
        '(either another [section] or the end of the file
        Bracket2 = INSTR(sectionStart + 1, __ini.wholeFile, "]")
        IF Bracket2 = 0 THEN __ini.code = 24: EXIT FUNCTION
        Bracket1 = INSTR(sectionStart + 1, __ini.wholeFile, "[")
        IF Bracket1 > 0 THEN
            FOR i = Bracket1 - 1 TO 1 STEP -1
                IF ASC(__ini.wholeFile, i) = 10 THEN endSection = i + 1 - LEN(__ini.LF): EXIT FOR
                IF i <= foundSection THEN EXIT FOR
            NEXT
            Ini_GetNextSection = MID$(__ini.wholeFile, foundSection, Bracket2 - foundSection + 1)
        ELSE
            Ini_GetNextSection = MID$(__ini.wholeFile, foundSection, Bracket2 - foundSection + 1)
            __ini.code = 24
            sectionStart = 0
        END IF
    ELSE
        __ini.code = 24
    END IF
END FUNCTION

FUNCTION Ini_GetInfo$
    SHARED __ini AS __IniType

    SELECT CASE __ini.code
        CASE 0: Ini_GetInfo = "Operation successful"
        CASE 1: Ini_GetInfo = "ERROR: File not found"
        CASE 2: Ini_GetInfo = "Empty value"
        CASE 3: Ini_GetInfo = "ERROR: Key not found"
        CASE 4: Ini_GetInfo = "Key updated"
        CASE 5: Ini_GetInfo = "Global key created"
        CASE 7: Ini_GetInfo = "Key created in existing section"
        CASE 8: Ini_GetInfo = "No changes applied (same value)"
        CASE 9: Ini_GetInfo = "New section created; key created"
        CASE 10: Ini_GetInfo = "No more keys"
        CASE 11: Ini_GetInfo = "File created; new key added"
        CASE 12: Ini_GetInfo = "ERROR: Invalid key"
        CASE 13: Ini_GetInfo = "Section deleted"
        CASE 14: Ini_GetInfo = "ERROR: Section not found"
        CASE 15: Ini_GetInfo = "ERROR: Invalid section"
        CASE 16: Ini_GetInfo = "New section created; existing key moved"
        CASE 17: Ini_GetInfo = "ERROR: Empty file"
        CASE 18: Ini_GetInfo = "ERROR: No file open"
        CASE 19: Ini_GetInfo = "Key deleted"
        CASE 20: Ini_GetInfo = "Key moved"
        CASE 21: Ini_GetInfo = "ERROR: Invalid file name/path"
        CASE 22: Ini_GetInfo = "Section sorted"
        CASE 23: Ini_GetInfo = "No changes applied; section already sorted"
        CASE 24: Ini_GetInfo = "No more sections"
        CASE ELSE: Ini_GetInfo = "ERROR: <invalid error code>"
    END SELECT
END FUNCTION

' Written in BASIC by Luke Ceddia for ide_methods.bas (QB64)
' After Cormen, Leiserson, Rivest & Stein "Introduction To Algoritms" via Wikipedia
' Adapted for use in .INI Manager
FUNCTION __Ini_SortArray%% (arr() AS STRING)
    DIM i&, x$, j&, moves&

    FOR i& = LBOUND(arr) + 1 TO UBOUND(arr)
        x$ = arr(i&)
        j& = i& - 1
        WHILE j& >= LBOUND(arr)
            IF arr(j&) <= x$ THEN EXIT WHILE
            moves& = moves& + 1
            arr$(j& + 1) = arr$(j&)
            j& = j& - 1
        WEND
        arr$(j& + 1) = x$
    NEXT i&

    ' Returns -1 (true) if any changes were made
    __Ini_SortArray = (moves& > 0)
END FUNCTION
