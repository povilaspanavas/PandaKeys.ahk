#Requires AutoHotkey v2.0
#SingleInstance Force

; Ctrl+Enter: take whatever's in the address bar (including any autocomplete
; ghost text), strip it down to the root domain, and navigate. This overrides
; the browser's native Ctrl+Enter (which just wraps the text in www./.com).
; #HotIf scopes this hotkey to only exist in these browsers - everywhere else
; the keystroke passes through untouched, as if this script weren't running.

#HotIf WinActive("ahk_exe chrome.exe") or WinActive("ahk_exe msedge.exe") or WinActive("ahk_exe vivaldi.exe") or WinActive("ahk_exe firefox.exe")

^Enter:: {
    ; Release Ctrl before sending Enter below - if it's still held, the
    ; browser reapplies its native www./.com wrap to our already-clean domain
    KeyWait "Ctrl"

    Send "^a"
    Sleep 50
    url := Trim(Clip())
    if (url = "")
        return

    ; Extract the domain (strip scheme, www., and everything after the first /)
    if RegExMatch(url, "i)^(?:https?://)?(?:www\.)?([^/\s]+)", &m)
        domain := m[1]
    else
        domain := url

    Send "^a"
    Sleep 50
    Clip("https://" . domain)
    Sleep 30
    Send "{Enter}"
}

#HotIf  ; close the context - hotkeys defined after this line are global again

; http://www.autohotkey.com/forum/viewtopic.php?p=467710 , modified February 19, 2013, ported to v2
; Clip() with no args: copies the current selection and returns it (clipboard restored after).
; Clip(text): pastes text in place of the current selection (clipboard restored after).
Clip(Text := "", Reselect := "")
{
    static BackUpClip := "", Stored := false, LastClip := ""

    if !Stored
    {
        Stored := true
        BackUpClip := ClipboardAll()
    }
    else
        SetTimer(ClipReset, 0)

    startTick := A_TickCount
    A_Clipboard := ""
    LongCopy := A_TickCount - startTick

    if (Text = "")
    {
        SendInput "^c"
        ClipWait(LongCopy ? 0.6 : 0.2, 1)
    }
    else
    {
        A_Clipboard := LastClip := Text
        ClipWait 10
        SendInput "^v"
    }

    SetTimer(ClipReset, -700)
    Sleep 20 ; Short sleep in case Clip() is followed by more keystrokes such as {Enter}

    if (Text = "")
        return LastClip := A_Clipboard
    else if (Reselect = true) or (Reselect and (StrLen(Text) < 3000))
    {
        Text := StrReplace(Text, "`r", "")
        SendInput "{Shift Down}{Left " StrLen(Text) "}{Shift Up}"
    }
    return

    ClipReset(*)
    {
        if (A_Clipboard == LastClip)
            A_Clipboard := BackUpClip
        BackUpClip := LastClip := ""
        Stored := false
    }
}
