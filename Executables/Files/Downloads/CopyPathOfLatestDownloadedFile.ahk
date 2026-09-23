#Requires AutoHotkey v2.0
#NoTrayIcon

dir := GetDownloadsFolder()
latest := GetNewestFile(dir)

if (latest = "") {
    MsgBox("No files found in " dir, "Latest download", "Icon!")
    ExitApp
}

A_Clipboard := latest
if ClipWait(1) {
    ToolTip("Copied path: " latest)
    Sleep(1200)
} else
    MsgBox("Couldn't copy path to clipboard:`n" latest, "Latest download", "Icon!")

ExitApp

GetNewestFile(dir) {
    ; Skip in-progress downloads and system junk
    static skipExt := Map("crdownload", 1, "part", 1, "partial", 1, "tmp", 1, "download", 1)
    static skipName := Map("desktop.ini", 1, "thumbs.db", 1)

    newest := "", newestTime := 0
    Loop Files, dir "\*", "F" {                 ; files only, top level only
        if skipExt.Has(StrLower(A_LoopFileExt)) || skipName.Has(StrLower(A_LoopFileName))
            continue
        if InStr(A_LoopFileAttrib, "H")         ; hidden
            continue

        ; Use the later of created/modified: extracted or copied files can keep
        ; an old modified time, so creation time better reflects arrival.
        t := A_LoopFileTimeCreated
        if (A_LoopFileTimeModified > t)
            t := A_LoopFileTimeModified

        if (t > newestTime) {
            newestTime := t
            newest := A_LoopFileFullPath
        }
    }
    return newest
}

GetDownloadsFolder() {
    ; Honours a relocated Downloads folder (e.g. moved to D:\ or OneDrive)
    try {
        path := RegRead("HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders"
                      , "{374DE290-123F-4565-9164-39C4925E467B}")
        path := ExpandEnv(path)
        if DirExist(path)
            return path
    }
    return EnvGet("USERPROFILE") "\Downloads"
}

ExpandEnv(str) {
    size := DllCall("ExpandEnvironmentStrings", "Str", str, "Ptr", 0, "UInt", 0, "UInt")
    buf := Buffer(size * 2)
    DllCall("ExpandEnvironmentStrings", "Str", str, "Ptr", buf, "UInt", size, "UInt")
    return StrGet(buf)
}
