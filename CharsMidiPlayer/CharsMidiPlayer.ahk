#SingleInstance, Force
SetBatchLines, -1
SetWorkingDir, %A_ScriptDir%
SendMode, Input

; === Global variables ===
global IsPlaying := false
global Notes := []  ; Array of note objects: {time_ms, key, shift}
global PlayIndex := 1
global PlayStartTime := 0
global PauseOffset := 0
global CsvFilePath := ""

; --- Roblox piano key send function ---
SendRobloxKey(key, shift, down := true) {
    if (shift) {
        if (down)
            SendInput, {Shift down}{%key% down}
        else
            SendInput, {%key% up}{Shift up}
    } else {
        if (down)
            SendInput, {%key% down}
        else
            SendInput, {%key% up}
    }
}

; === GUI Setup ===
Gui, +AlwaysOnTop +ToolWindow -Caption +Border +LastFound
Gui, Color, 111111
Gui, Add, Text, x10 y10 w260 h20 cWhite vCsvLabel, Loaded CSV: None
Gui, Add, Button, x275 y6 w20 h20 gExitApp, X
Gui, Add, Text, x10 y35 w300 h20 cWhite vStatusLabel, Status: No CSV loaded.
Gui, Add, Button, x10 y60 w100 h25 gLoadCsv, Load CSV
Gui, Add, Button, x120 y60 w100 h25 gUnloadCsv, Unload CSV
Gui, Show, w310 h100, Roblox MIDI Player
WinSet, Transparent, 128  ; 50% transparent
; Make GUI draggable
Gui +LastFound
hwnd := WinExist()
OnMessage(0x0201, "WM_LBUTTONDOWN")  ; WM_LBUTTONDOWN message

return

WM_LBUTTONDOWN(wParam, lParam) {
    global hwnd
    PostMessage, 0xA1, 2,,, ahk_id %hwnd%  ; WM_NCLBUTTONDOWN with HTCAPTION
    return 0
}

ExitApp:
GuiClose:
    ExitApp
return

; === Load CSV button ===
LoadCsv:
FileSelectFile, SelectedFile, 3,, Select MIDI CSV file, CSV Files (*.csv)
if (SelectedFile = "")
    return
if !LoadCsvFile(SelectedFile) {
    GuiControl,, StatusLabel, Status: Failed to load CSV.
    return
}
CsvFilePath := SelectedFile
GuiControl,, CsvLabel, Loaded CSV: % GetFileName(SelectedFile)
GuiControl,, StatusLabel, Status: CSV loaded successfully.
PlayIndex := 1
PauseOffset := 0
IsPlaying := false
return

; === Unload CSV button ===
UnloadCsv:
Notes := []
CsvFilePath := ""
GuiControl,, CsvLabel, Loaded CSV: None
GuiControl,, StatusLabel, Status: CSV unloaded.
IsPlaying := false
PlayIndex := 1
PauseOffset := 0
return

; === Get just filename from full path ===
GetFileName(path) {
    SplitPath, path,,, name
    return name
}

; === Load CSV parser ===
LoadCsvFile(path) {
    global Notes
    Notes := []
    FileRead, csvData, %path%
    if ErrorLevel {
        MsgBox, 16, Error, Failed to read file.`n%path%
        return false
    }
    lines := StrSplit(csvData, "`n")
    ; Expect header line time_ms,key,shift
    if (lines.MaxIndex() < 2) {
        MsgBox, 16, Error, CSV file empty or missing header.
        return false
    }
    headers := StrSplit(Trim(lines[1]), ",")
    if (headers.MaxIndex() < 3) {
        MsgBox, 16, Error, CSV header must have time_ms,key,shift
        return false
    }
    ; Find column indexes
    timeCol := 0
    keyCol := 0
    shiftCol := 0
    Loop % headers.MaxIndex() {
        h := headers[A_Index]
        if (h = "time_ms")
            timeCol := A_Index
        else if (h = "key")
            keyCol := A_Index
        else if (h = "shift")
            shiftCol := A_Index
    }
    if !(timeCol && keyCol && shiftCol) {
        MsgBox, 16, Error, CSV header must contain time_ms, key, shift columns.
        return false
    }
    Loop % lines.MaxIndex()-1 {
        line := Trim(lines[A_Index+1])
        if (line = "")
            continue
        cols := StrSplit(line, ",")
        time_ms := cols[timeCol]
        key := cols[keyCol]
        shift := cols[shiftCol]
        if (time_ms = "" || key = "" || shift = "")
            continue
        ; Validate shift
        shift := (shift = "1") ? 1 : 0
        ; Store as object
        Notes.Push({time_ms: time_ms + 0, key: key, shift: shift})
    }
    ; Sort notes by time_ms ascending
    Notes.Sort("CompareNotes")
    return true
}

CompareNotes(a, b) {
    if (a.time_ms < b.time_ms)
        return -1
    else if (a.time_ms > b.time_ms)
        return 1
    else
        return 0
}

; === Play/Pause toggle on Insert key ===
Insert::
    global IsPlaying, Notes, PlayIndex, PlayStartTime, PauseOffset
    if (Notes.MaxIndex() = 0) {
        GuiControl,, StatusLabel, Status: No CSV loaded.
        return
    }
    if (!IsPlaying) {
        ; Start or resume playing
        IsPlaying := true
        if (PlayIndex = 1)
            PlayStartTime := A_TickCount
        else
            PlayStartTime := A_TickCount - PauseOffset
        SetTimer, PlayNotes, 10
        GuiControl,, StatusLabel, Status: Playing...
    } else {
        ; Pause playing
        IsPlaying := false
        PauseOffset := A_TickCount - PlayStartTime
        SetTimer, PlayNotes, Off
        GuiControl,, StatusLabel, Status: Paused.
    }
return

; === Stop and unload CSV on Delete key ===
Delete::
    global IsPlaying, Notes, PlayIndex, PauseOffset, CsvFilePath
    IsPlaying := false
    SetTimer, PlayNotes, Off
    Notes := []
    PlayIndex := 1
    PauseOffset := 0
    CsvFilePath := ""
    GuiControl,, CsvLabel, Loaded CSV: None
    GuiControl,, StatusLabel, Status: CSV unloaded.
return

; === Timer routine to play notes ===
PlayNotes:
    global IsPlaying, Notes, PlayIndex, PlayStartTime
    if (!IsPlaying)
        return
    currentTime := A_TickCount - PlayStartTime
    ; Group notes with the same time_ms to play chords
    chordNotes := []
    if (PlayIndex > Notes.MaxIndex()) {
        ; End of song
        IsPlaying := false
        SetTimer, PlayNotes, Off
        GuiControl,, StatusLabel, Status: Finished playing.
        PlayIndex := 1
        return
    }
    firstTime := Notes[PlayIndex].time_ms
    while (PlayIndex <= Notes.MaxIndex() && Notes[PlayIndex].time_ms <= currentTime) {
        chordNotes.Push(Notes[PlayIndex])
        PlayIndex++
    }
    if (chordNotes.MaxIndex() > 0) {
        ; Press keys down
        for index, note in chordNotes {
            SendRobloxKey(note.key, note.shift, true)
        }
        Sleep, 50  ; Hold keys briefly
        ; Release keys
        for index, note in chordNotes {
            SendRobloxKey(note.key, note.shift, false)
        }
    }
return
