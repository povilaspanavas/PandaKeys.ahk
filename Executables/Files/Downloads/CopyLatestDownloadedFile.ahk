#Requires AutoHotkey v2.0
#NoTrayIcon

dir := GetDownloadsFolder()
latest := GetNewestFile(dir)

if (latest = "") {
    MsgBox("No files found in " dir, "Latest download", "Icon!")
    ExitApp
}

if CopyFileToClipboard(latest) {
    SplitPath(latest, &name)
    ToolTip("Copied: " name)
    Sleep(1200)
} else
    MsgBox("Couldn't copy to clipboard:`n" latest, "Latest download", "Icon!")

ExitApp

; Puts the file itself on the clipboard (as Explorer's Ctrl+C does),
; so Ctrl+V pastes the file into Explorer, email, Teams, etc.
CopyFileToClipboard(path) {
    ; CF_HDROP payload: DROPFILES header (20 bytes) + UTF-16 path + double null
    size := 20 + (StrLen(path) + 2) * 2
    hDrop := DllCall("GlobalAlloc", "UInt", 0x42, "UPtr", size, "Ptr")   ; GMEM_MOVEABLE | GMEM_ZEROINIT
    p := DllCall("GlobalLock", "Ptr", hDrop, "Ptr")
    NumPut("UInt", 20, p, 0)       ; pFiles: offset of file list
    NumPut("Int", 1, p, 16)        ; fWide: paths are Unicode
    StrPut(path, p + 20, "UTF-16")
    DllCall("GlobalUnlock", "Ptr", hDrop)

    ; "Preferred DropEffect" = copy (not cut)
    hEffect := DllCall("GlobalAlloc", "UInt", 0x42, "UPtr", 4, "Ptr")
    NumPut("UInt", 1, DllCall("GlobalLock", "Ptr", hEffect, "Ptr"))
    DllCall("GlobalUnlock", "Ptr", hEffect)
    fmtEffect := DllCall("RegisterClipboardFormat", "Str", "Preferred DropEffect", "UInt")

    ; Clipboard may be briefly locked by another app - retry
    Loop 10 {
        if DllCall("OpenClipboard", "Ptr", A_ScriptHwnd) {
            DllCall("EmptyClipboard")
            ok := DllCall("SetClipboardData", "UInt", 15, "Ptr", hDrop, "Ptr")   ; CF_HDROP
            if ok
                DllCall("SetClipboardData", "UInt", fmtEffect, "Ptr", hEffect, "Ptr")
            else
                DllCall("GlobalFree", "Ptr", hEffect)
            DllCall("CloseClipboard")
            if !ok
                DllCall("GlobalFree", "Ptr", hDrop)
            return !!ok
        }
        Sleep(50)
    }
    DllCall("GlobalFree", "Ptr", hDrop)
    DllCall("GlobalFree", "Ptr", hEffect)
    return false
}

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
