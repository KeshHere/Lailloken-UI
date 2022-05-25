﻿#NoEnv
#SingleInstance, Force
#InstallKeybdHook
#InstallMouseHook
;#Hotstring EndChars `n
#Hotstring NoMouse
DllCall("SetThreadDpiAwarenessContext", "ptr", -3, "ptr")
OnMessage(0x0204, "LLK_Rightclick")
SetKeyDelay, 100
CoordMode, Mouse, Screen
CoordMode, Pixel, Screen
CoordMode, ToolTip, Screen
SendMode, Input
SetWorkingDir %A_ScriptDir%
SetBatchLines, -1
OnExit, Exit
Menu, Tray, Tip, Lailloken UI
#Include Class_CustomFont.ahk
font1 := New CustomFont("Fontin-SmallCaps.ttf")
timeout := 1

If !pToken := Gdip_Startup()
{
	MsgBox, 48, gdiplus error!, Gdiplus failed to start. Please ensure you have gdiplus on your system
	ExitApp
}

GroupAdd, poe_window, ahk_exe GeForceNOW.exe
GroupAdd, poe_window, ahk_class POEWindowClass

IniRead, clone_frames_failcheck, ini\clone frames.ini
Loop, Parse, clone_frames_failcheck, `n, `n
{
	If InStr(A_LoopField, " ")
		IniDelete, ini\clone frames.ini, %A_LoopField%
}
If FileExist("Resolutions.ini")
	FileDelete, Resolutions.ini
If !FileExist("data\Resolutions.ini") || !FileExist("data\Map mods.ini") || !FileExist("data\Map search.ini") || !FileExist("data\Betrayal.ini") || !FileExist("data\Atlas.ini")
	LLK_Error("Critical files are missing. Make sure you have installed the script correctly.")
If !FileExist("ini\")
	FileCreateDir, ini\

IniWrite, 12400, ini\config.ini, Versions, ini-version ;1.24.1 = 12401, 1.24.10 = 12410
IniRead, kill_timeout, ini\config.ini, Settings, kill-timeout, 1
IniRead, kill_script, ini\config.ini, Settings, kill script, 1

startup := A_TickCount
While !WinExist("ahk_group poe_window")
{
	If (A_TickCount >= startup + kill_timeout*60000) && (kill_script = 1)
		ExitApp
	sleep, 5000
}

hwnd_poe_client := WinExist("ahk_group poe_window")
last_check := A_TickCount
WinGetPos, xScreenOffset, yScreenOffset, poe_width, poe_height, ahk_group poe_window

;determine native resolution of the active monitor
Gui, Test: New, -DPIScale +LastFound +AlwaysOnTop +ToolWindow -Caption
WinSet, Trans, 0
Gui, Test: Show, x%xScreenOffset% y%yScreenOffset% Maximize
WinGetPos,,, width_native, height_native
Gui, Test: Destroy

IniRead, supported_resolutions, data\Resolutions.ini

IniRead, fSize_config0, data\Resolutions.ini, %poe_height%p, font-size0, 16
IniRead, fSize_config1, data\Resolutions.ini, %poe_height%p, font-size1, 14
fSize0 := fSize_config0
fSize1 := fSize_config1

IniRead, custom_resolution_setting, ini\config.ini, Settings, enable custom-resolution
If (custom_resolution_setting != 0) && (custom_resolution_setting != 1)
{
	IniWrite, 0, ini\config.ini, Settings, enable custom-resolution
	custom_resolution_setting := 0
}

If (custom_resolution_setting = 1)
{
	IniRead, custom_resolution, ini\config.ini, Settings, custom-resolution
	If custom_resolution is not number
	{
		MsgBox, Incorrect config.ini settings detected: custom resolution enabled but none selected.`nThe setting will be reset and the script restarted.
		IniWrite, 0, ini\config.ini, Settings, enable custom-resolution
		Reload
		ExitApp
	}

	If (custom_resolution > height_native) ;check resolution in case of manual .ini edit
	{
		MsgBox, Incorrect config.ini settings detected: custom height > monitor height`nThe script will now exit.
		IniWrite, 0, ini\config.ini, Settings, enable custom-resolution
		IniWrite, %height_native%, ini\config.ini, Settings, custom-resolution
		ExitApp
	}
	WinMove, ahk_group poe_window,, %xScreenOffset%, %yScreenOffset%, %poe_width%, %custom_resolution%
	poe_height := custom_resolution
}

If !FileExist("img\Recognition (" poe_height "p\GUI\")
	FileCreateDir, img\Recognition (%poe_height%p)\GUI\
If !FileExist("img\Recognition (" poe_height "p\Betrayal\")
	FileCreateDir, img\Recognition (%poe_height%p)\Betrayal\

trans := 220
imagesearch_variation := 25
pixelsearch_variation := 0

IniRead, panel_position0, ini\config.ini, UI, panel-position0, bottom
IniRead, panel_position1, ini\config.ini, UI, panel-position1, left
IniRead, hide_panel, ini\config.ini, UI, hide panel, 0

IniRead, enable_notepad, ini\config.ini, Features, enable notepad, 0
IniRead, enable_alarm, ini\config.ini, Features, enable alarm, 0
IniRead, enable_pixelchecks, ini\config.ini, Settings, background pixel-checks, 1

IniRead, game_version, ini\config.ini, Versions, game-version, 31800 ;3.17.4 = 31704, 3.17.10 = 31710
IniRead, fSize_offset, ini\config.ini, UI, font-offset, 0
fSize0 := fSize_config0 + fSize_offset
fSize1 := fSize_config1 + fSize_offset

IniRead, alarm_xpos, ini\alarm.ini, UI, xcoord, % xScreenOffset+poe_width//2
alarm_xpos := (alarm_xpos = "") ? xScreenOffset+poe_width//2 : alarm_xpos
IniRead, alarm_ypos, ini\alarm.ini, UI, ycoord, % yScreenOffset+poe_height//2
alarm_ypos := (alarm_ypos = "") ? yScreenOffset+poe_height//2 : alarm_ypos
IniRead, fSize_offset_alarm, ini\alarm.ini, Settings, font-offset
If fSize_offset_alarm is not number
	fSize_offset_alarm := 0
IniRead, alarm_fontcolor, ini\alarm.ini, Settings, font-color, %A_Space%
alarm_fontcolor := (alarm_fontcolor = "") ? "White" : alarm_fontcolor
IniRead, alarm_trans, ini\alarm.ini, Settings, transparency
If alarm_trans is not number
	alarm_trans := 255
IniRead, alarm_timestamp, ini\alarm.ini, Settings, alarm-timestamp, %A_Space%
alarm_timestamp := (alarm_timestamp < A_Now) ? "" : alarm_timestamp
If (alarm_timestamp != "")
	continue_alarm := 1

betrayal_divisions := "transportation,fortification,research,intervention"
IniRead, betrayal_list, data\Betrayal.ini
betrayal_list := StrReplace(betrayal_list, "version`n")
Sort, betrayal_list, D`n
IniRead, betrayal_ini_version_data, data\Betrayal.ini, Version, version, 1
IniRead, betrayal_ini_version_user, ini\betrayal info.ini, Version, version, 0
If !FileExist("ini\betrayal info.ini") || (betrayal_ini_version_user < betrayal_ini_version_data)
{
	betrayal_info_exists := FileExist("ini\betrayal info.ini") ? 1 : 0
	IniWrite, %betrayal_ini_version_data%, ini\betrayal info.ini, Version, version
	If (betrayal_info_exists = 0)
	{
		IniWrite, 0, ini\betrayal info.ini, Settings, font-offset
		IniWrite, 220, ini\betrayal info.ini, Settings, transparency
	}
	Loop, Parse, betrayal_list, `n, `n
	{
		check := A_Loopfield
		If (A_LoopField = "settings") || (A_Loopfield = "version")
			continue
		If (betrayal_info_exists = 0)
			Loop, Parse, betrayal_divisions, `,, `,
				IniWrite, 1, ini\betrayal info.ini, %check%, %A_Loopfield%
	}
}
IniRead, fSize_offset_betrayal, ini\betrayal info.ini, Settings, font-offset, 0
IniRead, betrayal_trans, ini\betrayal info.ini, Settings, transparency, 220
IniRead, betrayal_enable_recognition, ini\betrayal info.ini, Settings, enable image recognition, 0

If !FileExist("ini\clone frames.ini")
	IniWrite, 0, ini\clone frames.ini, Settings, enable pixel-check
IniRead, clone_frames_list, ini\clone frames.ini
IniRead, clone_frames_pixelcheck_enable, ini\clone frames.ini, Settings, enable pixel-check, 1
Loop, Parse, clone_frames_list, `n, `n
{
	If (A_LoopField = "Settings")
		continue
	IniRead, clone_frame_%A_LoopField%_enable, ini\clone frames.ini, %A_LoopField%, enable, 0
	If (clone_frame_%A_LoopField%_enable = 1)
		clone_frames_enabled := (clone_frames_enabled = "") ? A_LoopField "," : A_LoopField "," clone_frames_enabled
	IniRead, clone_frame_%A_LoopField%_topleft_x, ini\clone frames.ini, %A_LoopField%, source x-coordinate, 0
	IniRead, clone_frame_%A_LoopField%_topleft_y, ini\clone frames.ini, %A_LoopField%, source y-coordinate, 0
	IniRead, clone_frame_%A_LoopField%_width, ini\clone frames.ini, %A_LoopField%, frame-width, 200
	IniRead, clone_frame_%A_LoopField%_height, ini\clone frames.ini, %A_LoopField%, frame-height, 200
	IniRead, clone_frame_%A_LoopField%_target_x, ini\clone frames.ini, %A_LoopField%, target x-coordinate, % xScreenOffset + poe_width//2
	IniRead, clone_frame_%A_LoopField%_target_y, ini\clone frames.ini, %A_LoopField%, target y-coordinate, % yScreenOffset + poe_height//2
	IniRead, clone_frame_%A_LoopField%_scale_x, ini\clone frames.ini, %A_LoopField%, scaling x-axis, 100
	IniRead, clone_frame_%A_LoopField%_scale_y, ini\clone frames.ini, %A_LoopField%, scaling y-axis, 100
	IniRead, clone_frame_%A_LoopField%_opacity, ini\clone frames.ini, %A_LoopField%, opacity, 5
}

IniRead, gwennen_regex, ini\gwennen.ini, regex, regex

Loop 16
{
	IniRead, maps_tier%A_Index%, data\Atlas.ini, Maps, tier%A_Index%
	maps_list := (maps_list = "") ? StrReplace(maps_tier%A_Index%, ",", " (" A_Index "),") : maps_list StrReplace(maps_tier%A_Index%, ",", " (" A_Index "),")
	Sort, maps_tier%A_Index%, D`,
	maps_tier%A_Index% := SubStr(maps_tier%A_Index%, 1, -1)
	maps_tier%A_Index% := StrReplace(maps_tier%A_Index%, ",", "`n")
}
Sort, maps_list, D`,
Loop, Parse, maps_list, `,, `,
{
	If (A_Loopfield = "")
		break
	letter := SubStr(A_Loopfield, 1, 1)
	maps_%letter% := (maps_%letter% = "") ? A_Loopfield : maps_%letter% "`n" A_Loopfield
}

IniRead, map_info_y, data\Resolutions.ini, %poe_height%p, map info y-coordinate, 0
IniRead, map_toggle_x, data\Resolutions.ini, %poe_height%p, map toggle x-coordinate, 0
IniRead, map_toggle_y, data\Resolutions.ini, %poe_height%p, map toggle y-coordinate, 0
IniRead, map_info_pixelcheck_enable, ini\map info.ini, Settings, enable pixel-check, 1
If (map_info_pixelcheck_enable = 1)
	pixelchecks_enabled := InStr(pixelchecks_enabled, "gamescreen") ? pixelchecks_enabled : pixelchecks_enabled "gamescreen,"
IniRead, fSize_offset_map_info, ini\map info.ini, Settings, font-offset, 0
IniRead, map_info_trans, ini\map info.ini, Settings, transparency, 220
If fSize_offset_map_info is not number
	fSize_offset_map_info := 0
IniRead, map_info_side, ini\map info.ini, Settings, side, right
IniRead, map_mod_ini_version_data, data\Map mods.ini, Version, version, 1
IniRead, map_mod_ini_version_user, ini\map info.ini, Version, version, 0
If !FileExist("ini\map info.ini") || (map_mod_ini_version_data > map_mod_ini_version_user)
{
	map_info_exists := FileExist("ini\map info.ini") ? 1 : 0
	IniWrite, %map_mod_ini_version_data%, ini\map info.ini, Version, version
	If (map_info_exists = 0)
	{
		IniWrite, 0, ini\map info.ini, Settings, enable pixel-check
		IniWrite, 0, ini\map info.ini, Settings, font-offset
		IniWrite, 220, ini\map info.ini, Settings, transparency
	}
	IniRead, map_info_parse, data\Map mods.ini
	Loop, Parse, map_info_parse, `n, `n
	{
		If (A_LoopField = "sample map") || (A_LoopField = "version")
			continue
		IniRead, parse_ID, data\Map mods.ini, %A_LoopField%, ID
		IniRead, parse_text, data\Map mods.ini, %A_LoopField%, text
		IniRead, parse_type, data\Map mods.ini, %A_LoopField%, type
		IniRead, parse_rank, data\map info.ini, %parse_ID%, rank
		IniWrite, %parse_text%, ini\map info.ini, %parse_ID%, text
		IniWrite, %parse_type%, ini\map info.ini, %parse_ID%, type
		If (map_info_exists = 0) || (parse_rank = "") || (parse_rank = "ERROR")
			IniWrite, 1, ini\map info.ini, %parse_ID%, rank
	}
}

IniRead, notepad_xpos, ini\notepad.ini, UI, xcoord, % xScreenOffset + poe_width//2
notepad_xpos := (notepad_xpos = "") ? xScreenOffset+poe_width//2 : notepad_xpos
IniRead, notepad_ypos, ini\notepad.ini, UI, ycoord, % yScreenOffset + poe_height//2
notepad_ypos := (notepad_ypos = "") ? yScreenOffset+poe_height//2 : notepad_ypos
IniRead, notepad_width, ini\notepad.ini, UI, width, 400
IniRead, notepad_height, ini\notepad.ini, UI, height, 400
IniRead, notepad_text, ini\notepad.ini, Text, text, %A_Space%
If (notepad_text != "")
	notepad_text := StrReplace(notepad_text, ",,", "`n")
IniRead, fSize_offset_notepad, ini\notepad.ini, Settings, font-offset, 0
If fSize_offset_notepad is not number
	fSize_offset_notepad := 0
IniRead, notepad_fontcolor, ini\notepad.ini, Settings, font-color, %A_Space%
notepad_fontcolor := (notepad_fontcolor = "") ? "White" : notepad_fontcolor
IniRead, notepad_trans, ini\notepad.ini, Settings, transparency
If notepad_trans is not number
	notepad_trans := 255

IniRead, omnikey_hotkey, ini\config.ini, Settings, omni-hotkey, %A_Space%
If (omnikey_hotkey != "")
{
	Hotkey, IfWinActive, ahk_group poe_window
	Hotkey, *~%omnikey_hotkey%, Omnikey, On
	Hotkey, *~MButton, Omnikey, Off
}
Else
{
	Hotkey, IfWinActive, ahk_group poe_window
	Hotkey, *~MButton, Omnikey, On
}

IniRead, pixel_gamescreen_x1, data\Resolutions.ini, %poe_height%p, gamescreen x-coordinate 1
IniRead, pixel_gamescreen_y1, data\Resolutions.ini, %poe_height%p, gamescreen y-coordinate 1
IniRead, pixel_gamescreen_color1, ini\pixel checks (%poe_height%p).ini, gamescreen, color 1

If WinExist("ahk_exe GeForceNOW.exe")
{
	IniRead, pixelsearch_variation, ini\geforce now.ini, Settings, pixel-check variation, 0
	IniRead, imagesearch_variation, ini\geforce now.ini, Settings, image-check variation, 25
}

pixelchecks_list := "gamescreen"
Sort, pixelchecks_list, D`,
imagechecks_list := "betrayal,bestiary,gwennen"
Sort, imagechecks_list, D`,

If (pixel_gamescreen_color1 = "ERROR") || (pixel_gamescreen_color1 = "")
{
	clone_frames_pixelcheck_enable := 0
	map_info_pixelcheck_enable := 0
	pixelchecks_enabled := StrReplace(pixelchecks_enabled, "gamescreen,")
}

SetTimer, Loop, 1000

guilist := "LLK_panel|notepad|notepad_sample|settings_menu|alarm|alarm_sample|clone_frames_window|map_mods_window|map_mods_toggle|betrayal_info_1|betrayal_info_2|betrayal_info_3|betrayal_info_4|lab_layout|lab_marker|betrayal_search|gwennen_setup|"
buggy_resolutions := "768,1024,1050"

timeout := 0
If (custom_resolution_setting = 1)
	WinActivate, ahk_group poe_window
WinWaitActive, ahk_group poe_window
If InStr(buggy_resolutions, poe_height) || !InStr(supported_resolutions, poe_height)
{
	If InStr(buggy_resolutions, poe_height)
	{
text =
(
Unsupported resolution detected!

The script has detected a vertical screen-resolution of %poe_height% pixels which has caused issues with the game-client and the script in the past.

I have decided to end support for this resolution.
You have to run the client with a custom resolution, which you can do in the following window, to use this script.

You also have to enable "confine mouse to window" in the game's UI options.
)
	}
	Else If !InStr(supported_resolutions, poe_height)
	{
text =
(
Unsupported resolution detected!

The script has detected a vertical screen-resolution of %poe_height% pixels which is not supported.

You have to run the client with a custom resolution, which you can do in the following window, to use this script.

You also have to enable "confine mouse to window" in the game's UI options.
)
	}
	MsgBox, % text
	GoSub, settings_menu
	sleep, 2000
	Loop
	{
		If !WinExist("ahk_id " hwnd_settings_menu)
		{
			MsgBox, The script will now shut down.
			ExitApp
		}
	}
	Return
}
SoundBeep, 100
GoSub, GUI
If (clone_frames_enabled != "")
	GoSub, GUI_clone_frames
GoSub, Screenchecks_gamescreen
SetTimer, MainLoop, 100
Return

#IfWinActive ahk_group poe_window

:*:.lab::
LLK_HotstringClip(A_ThisHotkey, 1)
Return

:*?:.llk::
LLK_HotstringClip(A_ThisHotkey, 1)
Return

Enter::
If LLK_ImageSearch("bestiary")
	LLK_HotstringClip("best")
Else SendInput, {Enter}
Return

Tab::
If (lab_mode = 1)
{
	start := A_TickCount
	While GetKeyState("Tab", "P")
	{
		If (A_TickCount >= start + 200)
		{
			GoSub, Lab_info
			KeyWait, Tab
			Return
		}
	}
}
SendInput, {Tab}
Return

#If WinExist("ahk_id " hwnd_clone_frames_menu)

F1::
MouseGetPos, mouseXpos, mouseYpos
clone_frame_new_topleft_x := mouseXpos
clone_frame_new_topleft_y := mouseYpos
GuiControl, clone_frames_menu: Text, clone_frame_new_topleft_x, % clone_frame_new_topleft_x
GuiControl, clone_frames_menu: Text, clone_frame_new_topleft_y, % clone_frame_new_topleft_y
GoSub, Clone_frames_dimensions
Return

F2::
MouseGetPos, mouseXpos, mouseYpos
clone_frame_new_width := mouseXpos - clone_frame_new_topleft_x
clone_frame_new_height := mouseYpos - clone_frame_new_topleft_y
GuiControl, clone_frames_menu: Text, clone_frame_new_width, % clone_frame_new_width
GuiControl, clone_frames_menu: Text, clone_frame_new_height, % clone_frame_new_height
GoSub, Clone_frames_dimensions
Return

F3::
MouseGetPos, mouseXpos, mouseYpos
clone_frame_new_target_x := (mouseXpos + clone_frame_new_width * clone_frame_new_scale_x//100 > xScreenOffset + poe_width) ? xScreenOffSet + poe_width - clone_frame_new_width * clone_frame_new_scale_x//100 : mouseXpos
clone_frame_new_target_y := (mouseYpos + clone_frame_new_height * clone_frame_new_scale_y//100 > yScreenOffset + poe_height) ? yScreenOffSet + poe_height - clone_frame_new_height * clone_frame_new_scale_y//100 : mouseYpos
GuiControl, clone_frames_menu: Text, clone_frame_new_target_x, % clone_frame_new_target_x
GuiControl, clone_frames_menu: Text, clone_frame_new_target_y, % clone_frame_new_target_y
GoSub, Clone_frames_dimensions
Return

#If WinExist("ahk_id " hwnd_betrayal_info_1) || WinActive("ahk_id " hwnd_betrayal_search)

ESC::
WinActivate, ahk_group poe_window
Loop 4
	LLK_Overlay("betrayal_info_" A_Index, "hide")
If (betrayal_enable_recognition = 1)
{
	Gui, betrayal_search: Destroy
	hwnd_betrayal_search := ""
}
If LLK_ImageSearch("betrayal")
	SendInput, {ESC}
Return

#If WinExist("ahk_id " hwnd_gwennen_setup)

ESC::
Gui, gwennen_setup: Destroy
hwnd_gwennen_setup := ""
Return

#If (horizon_toggle = 1)
	
a::
b::
c::
d::
e::
f::
g::
h::
i::
j::
k::
l::
m::
n::
o::
p::
q::
r::
s::
t::
u::
v::
w::
x::
y::
z::LLK_Omnikey_ToolTip(maps_%A_ThisHotkey%)

#If

Alarm:
alarm_fontcolor := (alarm_fontcolor = "") ? "White" : alarm_fontcolor
fSize_alarm := fSize0 + fSize_offset_alarm
If (alarm_timestamp != "") && (alarm_timestamp < A_Now)
{
	Gui, alarm: Destroy
	hwnd_alarm := ""
	alarm_timestamp := ""
	WinActivate, ahk_group poe_window
	Return
}
If (A_Gui = "settings_menu")
{
	LLK_Overlay("alarm", "hide")
	Gui, alarm_sample: New, -DPIScale +LastFound +AlwaysOnTop +ToolWindow +Border HWNDhwnd_alarm_sample, Preview: timer
	Gui, alarm_sample: Margin, 12, 4
	Gui, alarm_sample: Color, Black
	WinSet, Transparent, %alarm_trans%
	Gui, alarm_sample: Font, c%alarm_fontcolor% s%fSize_alarm%, Fontin SmallCaps
	Gui, alarm_sample: Add, Text, BackgroundTrans, % "  00:00  "
	If (alarm_sample_xpos != "") && (alarm_sample_ypos != "")
		Gui, alarm_sample: Show, Hide x%alarm_sample_xpos% y%alarm_sample_ypos% AutoSize
	Else
	{
		Gui, alarm_sample: Show, Hide AutoSize
		WinGetPos,,, win_width, win_height
		Gui, alarm_sample: Show, % "Hide AutoSize x"xScreenOffSet + poe_width//2 - win_width//2 " y"yScreenOffSet
	}
	LLK_Overlay("alarm_sample", "show", 0)
	Return
}

If (A_GuiControl = "alarm_start") || (continue_alarm = 1)
{
	If (continue_alarm != 1)
	{
		Gui, alarm: Submit, NoHide
		alarm_minutes := (alarm_minutes > 60) ? 60 : alarm_minutes
		alarm_minutes *= 60
		WinGetPos, alarm_xpos, alarm_ypos,,, ahk_id %hwnd_alarm%
		alarm_timestamp := A_Now
		EnvAdd, alarm_timestamp, %alarm_minutes%, S
	}
	Gui, alarm: New, -DPIScale +E0x20 +LastFound +AlwaysOnTop +ToolWindow -Caption +Border HWNDhwnd_alarm,
	Gui, alarm: Color, Black
	Gui, alarm: Margin, 12, 4
	WinSet, Transparent, %alarm_trans%
	Gui, alarm: Font, s%fSize_alarm% c%alarm_fontcolor%, Fontin SmallCaps
	Gui, alarm: Add, Text, xp BackgroundTrans Center valarm_countdown, XX:XX
	GuiControl, Text, alarm_countdown,
	Gui, alarm: Show, Hide x%alarm_xpos% y%alarm_ypos% AutoSize
	LLK_Overlay("alarm", "show")
	WinActivate, ahk_group poe_window
	continue_alarm := 0
	Return
}

If (click = 2) || (hwnd_alarm = "")
{
	If !WinExist("ahk_id " hwnd_alarm) && (click = 2)
	{
		WinActivate, ahk_group poe_window
		Return
	}
	If WinExist("ahk_id " hwnd_alarm) || (hwnd_alarm = "")
	{
		alarm_timestamp := ""
		If (hwnd_alarm != "")
		{
			Gui, alarm: Destroy
			hwnd_alarm := ""
			WinActivate, ahk_group poe_window
			Return
		}
		Gui, alarm: New, -DPIScale +LastFound +AlwaysOnTop +ToolWindow +Border HWNDhwnd_alarm, Lailloken UI: alarm-timer
		Gui, alarm: Color, Black
		Gui, alarm: Margin, 12, 4
		WinSet, Transparent, %trans%
		Gui, alarm: Font, s%fSize0% cWhite, Fontin SmallCaps
		Gui, alarm: Add, Text, Section BackgroundTrans Center, set timer to
		Gui, alarm: Font, % "s"fSize0-4
		Gui, alarm: Add, Edit, % "ys hp x+6 cBlack BackgroundTrans Center valarm_minutes Limit2 Number w"fSize0*1.8, 0
		Gui, alarm: Font, s%fSize0%
		Gui, alarm: Add, Text, ys x+6 BackgroundTrans Center, minute(s)
		Gui, alarm: Add, Button, xp hp BackgroundTrans Hidden Default valarm_start gAlarm, OK
		If (alarm_xpos = "") || (alarm_ypos = "")
			Gui, alarm: Show, Hide Center
		Else Gui, alarm: Show, Hide x%alarm_xpos% y%alarm_ypos%
		LLK_Overlay("alarm", "show", 0)
		Return
	}
}

If !WinExist("ahk_id " hwnd_alarm)
	LLK_Overlay("alarm", "show", 1)
Else
{
	WinGetPos, alarm_xpos, alarm_ypos,,, ahk_id %hwnd_alarm%
	LLK_Overlay("alarm", "hide")
	WinActivate, ahk_group poe_window
}
Return

AlarmGuiClose:
If !WinExist("ahk_group poe_window") || (alarm_timestamp < A_Now)
{
	alarm_timestamp := ""
	hwnd_alarm := ""
}
LLK_Overlay("alarm", "hide")
Return

Apply_resolution:
Gui, settings_menu: Submit, NoHide
WinMove, ahk_group poe_window,, %xScreenOffset%, %yScreenOffset%, %poe_width%, %custom_resolution%
poe_height := custom_resolution
IniWrite, %custom_resolution_setting%, ini\config.ini, Settings, enable custom-resolution
IniWrite, %custom_resolution%, ini\config.ini, Settings, custom-resolution
Reload
ExitApp
Return

Apply_settings_alarm:
If (A_GuiControl = "enable_alarm")
{
	Gui, settings_menu: Submit, NoHide
	If WinExist("ahk_id " hwnd_alarm_sample) && (enable_alarm = 0)
	{
		Gui, alarm_sample: Destroy
		hwnd_alarm_sample := ""
	}
	If WinExist("ahk_id " hwnd_alarm) && (enable_alarm = 0)
	{
		Gui, alarm: Destroy
		hwnd_alarm := ""
	}
	IniWrite, %enable_alarm%, ini\config.ini, Features, enable alarm
	GoSub, GUI
	GoSub, Settings_menu
	Return
}
If (A_GuiControl = "fSize_alarm_minus")
{
	fSize_offset_alarm -= 1
	IniWrite, %fSize_offset_alarm%, ini\alarm.ini, Settings, font-offset
}
If (A_GuiControl = "fSize_alarm_plus")
{
	fSize_offset_alarm += 1
	IniWrite, %fSize_offset_alarm%, ini\alarm.ini, Settings, font-offset
}
If (A_GuiControl = "fSize_alarm_reset")
{
	fSize_offset_alarm := 0
	IniWrite, %fSize_offset_alarm%, ini\alarm.ini, Settings, font-offset
}
If (A_GuiControl = "alarm_opac_minus")
{
	alarm_trans -= (alarm_trans > 100) ? 30 : 0
	IniWrite, %alarm_trans%, ini\alarm.ini, Settings, transparency
}
If (A_GuiControl = "alarm_opac_plus")
{
	alarm_trans += (alarm_trans < 250) ? 30 : 0
	IniWrite, %alarm_trans%, ini\alarm.ini, Settings, transparency
}
WinGetPos, alarm_sample_xpos, alarm_sample_ypos,,, ahk_id %hwnd_alarm_sample%
If InStr(A_GuiControl, "fontcolor_")
{
	alarm_fontcolor := StrReplace(A_GuiControl, "fontcolor_", "")
	IniWrite, %alarm_fontcolor%, ini\alarm.ini, Settings, font-color
}
GoSub, Alarm
Return

Apply_settings_general:
If (A_GuiControl = "interface_size_minus")
{
	fSize_offset -= 1
	IniWrite, %fSize_offset%, ini\config.ini, UI, font-offset
}
If (A_GuiControl = "interface_size_plus")
{
	fSize_offset += 1
	IniWrite, %fSize_offset%, ini\config.ini, UI, font-offset
}
If (A_GuiControl = "interface_size_reset")
{
	fSize_offset := 0
	IniWrite, %fSize_offset%, ini\config.ini, UI, font-offset
}
fSize0 := fSize_config0 + fSize_offset
fSize1 := fSize_config1 + fSize_offset
Gui, settings_menu: Submit, NoHide
If (A_GuiControl = "kill_script")
	IniWrite, %kill_script%, ini\config.ini, Settings, kill script
If (A_GuiControl = "kill_timeout")
{
	kill_timeout := (kill_timeout = "") ? 0 : kill_timeout
	IniWrite, %kill_timeout%, ini\config.ini, Settings, kill-timeout
}
If (A_GuiControl = "panel_position0")
	IniWrite, %panel_position0%, ini\config.ini, UI, panel-position0
If (A_GuiControl = "panel_position1")
	IniWrite, %panel_position1%, ini\config.ini, UI, panel-position1
If (A_GuiControl = "hide_panel")
	IniWrite, %hide_panel%, ini\config.ini, UI, hide panel
SetTimer, Settings_menu, 10
GoSub, GUI
WinActivate, ahk_group poe_window
Return

Apply_settings_notepad:
If (A_GuiControl = "enable_notepad")
{
	Gui, settings_menu: Submit, NoHide
	If WinExist("ahk_id " hwnd_notepad_sample) && (enable_notepad = 0)
	{
		Gui, notepad_sample: Destroy
		hwnd_notepad_sample := ""
	}
	If WinExist("ahk_id " hwnd_notepad) && (enable_notepad = 0)
	{
		Gui, Notepad: Submit, NoHide
		Gui, notepad: Destroy
		hwnd_notepad := ""
	}
	IniWrite, %enable_notepad%, ini\config.ini, Features, enable notepad
	GoSub, GUI
	GoSub, Settings_menu
	Return
}
If (A_GuiControl = "fSize_notepad_minus")
{
	fSize_offset_notepad -= 1
	IniWrite, %fSize_offset_notepad%, ini\notepad.ini, Settings, font-offset
}
If (A_GuiControl = "fSize_notepad_plus")
{
	fSize_offset_notepad += 1
	IniWrite, %fSize_offset_notepad%, ini\notepad.ini, Settings, font-offset
}
If (A_GuiControl = "fSize_notepad_reset")
{
	fSize_offset_notepad := 0
	IniWrite, %fSize_offset_notepad%, ini\notepad.ini, Settings, font-offset
}
If (A_GuiControl = "notepad_opac_minus")
{
	notepad_trans -= (notepad_trans > 100) ? 30 : 0
	IniWrite, %notepad_trans%, ini\notepad.ini, Settings, transparency
}
If (A_GuiControl = "notepad_opac_plus")
{
	notepad_trans += (notepad_trans < 250) ? 30 : 0
	IniWrite, %notepad_trans%, ini\notepad.ini, Settings, transparency
}
WinGetPos, notepad_sample_xpos, notepad_sample_ypos,,, ahk_id %hwnd_notepad_sample%
If InStr(A_GuiControl, "fontcolor_")
{
	notepad_fontcolor := StrReplace(A_GuiControl, "fontcolor_", "")
	IniWrite, %notepad_fontcolor%, ini\notepad.ini, Settings, font-color
}
GoSub, Notepad
Return

Apply_settings_omnikey:
Gui, settings_menu: Submit, NoHide
If (A_GuiControl = "omnikey_hotkey") && (omnikey_hotkey != "")
{
	If (omnikey_hotkey_old != omnikey_hotkey) && (omnikey_hotkey_old != "")
	{
		Hotkey, IfWinActive, ahk_group poe_window
		Hotkey, *~%omnikey_hotkey_old%,, Off
	}
	omnikey_hotkey_old := omnikey_hotkey
	Hotkey, IfWinActive, ahk_group poe_window
	Hotkey, *~%omnikey_hotkey%, Omnikey, On
	IniWrite, %omnikey_hotkey%, ini\config.ini, Settings, omni-hotkey
}
GoSub, Settings_menu
Return

Betrayal_apply:
Gui, settings_menu: Submit, NoHide
If (A_GuiControl = "image_folder")
{
	Run, explore img\Recognition (%poe_height%p)\Betrayal\
	Return
}
If (A_GuiControl = "fSize_betrayal_minus")
{
	fSize_offset_betrayal -= 1
	IniWrite, %fSize_offset_betrayal%, ini\betrayal info.ini, Settings, font-offset
	GoSub, Betrayal_info
	Return
}
If (A_GuiControl = "fSize_betrayal_plus")
{
	fSize_offset_betrayal += 1
	IniWrite, %fSize_offset_betrayal%, ini\betrayal info.ini, Settings, font-offset
	GoSub, Betrayal_info
	Return
}
If (A_GuiControl = "fSize_betrayal_reset")
{
	fSize_offset_betrayal := 0
	IniWrite, %fSize_offset_betrayal%, ini\betrayal info.ini, Settings, font-offset
	GoSub, Betrayal_info
	Return
}
If (A_GuiControl = "betrayal_opac_minus")
{
	betrayal_trans -= (betrayal_trans > 100) ? 30 : 0
	IniWrite, %betrayal_trans%, ini\betrayal info.ini, Settings, transparency
	GoSub, Betrayal_info
	Return
}
If (A_GuiControl = "betrayal_opac_plus")
{
	betrayal_trans += (betrayal_trans < 250) ? 30 : 0
	IniWrite, %betrayal_trans%, ini\betrayal info.ini, Settings, transparency
	GoSub, Betrayal_info
	Return
}
If (A_GuiControl = "betrayal_enable_recognition")
{
	IniWrite, %betrayal_enable_recognition%, ini\betrayal info.ini, Settings, enable image recognition
	Return
}
If (A_GuiControl = "betrayal_ddl")
{
	Gui, betrayal_setup: Submit
	Gui, betrayal_setup: Destroy
	FileDelete, img\Recognition (%poe_height%p)\Betrayal\%betrayal_ddl%.bmp
	test := Gdip_SaveBitmapToFile(pBetrayal_screencap, "img\Recognition (" poe_height "p)\Betrayal\" betrayal_ddl ".bmp", 100)
	Gdip_DisposeImage(test)
	Return
}
parse_member := SubStr(A_GuiControl, InStr(A_GuiControl, "_",,, 3) + 1)
parse_member := SubStr(parse_member, 1, InStr(parse_member, "_",,, 1) - 1)
parse_division := SubStr(A_GuiControl, InStr(A_GuiControl, "_",,, 4) + 1)
parse_gui := SubStr(A_GuiControl, 1, InStr(A_GuiControl, "_",,, 3) - 1)
betrayal_%parse_member%_%parse_division% := (betrayal_%parse_member%_%parse_division% = "") ? 1 : betrayal_%parse_member%_%parse_division%
If (click != 2)
	betrayal_%parse_member%_%parse_division% -= (betrayal_%parse_member%_%parse_division% < 4) ? -1 : 2
Else betrayal_%parse_member%_%parse_division% := (betrayal_%parse_member%_%parse_division% = 1) ? 5 : 1
color := "white"
color := (betrayal_%parse_member%_%parse_division% = 2) ? "Lime" : color
color := (betrayal_%parse_member%_%parse_division% = 3) ? "Yellow" : color
color := (betrayal_%parse_member%_%parse_division% = 4) ? "Red" : color
color := (betrayal_%parse_member%_%parse_division% = 5) ? "Aqua" : color
IniWrite, % betrayal_%parse_member%_%parse_division%, ini\betrayal info.ini, %parse_member%, %parse_division%
Gui, %parse_gui%: Font, c%color%
GuiControl, Font, %A_GuiControl%
WinSet, Redraw,, % "ahk_id " hwnd_%parse_gui%
WinActivate, ahk_group poe_window
Return

Betrayal_info:
Loop, Parse, betrayal_divisions, `,, `,
{
	Gui, betrayal_info_%A_Index%: New, -DPIScale -Caption +LastFound +AlwaysOnTop +ToolWindow +Border HWNDhwnd_betrayal_info_%A_Index%
	Gui, betrayal_info_%A_Index%: Margin, 0, 0
	Gui, betrayal_info_%A_Index%: Color, Black
	WinSet, Transparent, %betrayal_trans%
	Gui, betrayal_info_%A_Index%: Font, % "cWhite s"fSize0 + fSize_offset_betrayal, Fontin SmallCaps
	If (betrayal_layout = 1)
	{
		IniRead, betrayal_%betrayal_member%_%A_Loopfield%, ini\betrayal info.ini, %betrayal_member%, %A_Loopfield%, 1
		color := "white"
		color := (betrayal_%betrayal_member%_%A_Loopfield% = 2) ? "Lime" : color
		color := (betrayal_%betrayal_member%_%A_Loopfield% = 3) ? "Yellow" : color
		color := (betrayal_%betrayal_member%_%A_Loopfield% = 4) ? "Red" : color
		color := (betrayal_%betrayal_member%_%A_Loopfield% = 5) ? "Aqua" : color
		Gui, betrayal_info_%A_Index%: Add, Text, % "BackgroundTrans Center vbetrayal_info_"A_Index "_" betrayal_member "_" A_Loopfield " gBetrayal_apply w"poe_width//5 " c"color, % %A_Loopfield%_text
	}
	Else
	{
		If (A_Index < 3)
		{
			betrayal_member := parse_member1
			betrayal_division := (A_Index = 1) ? parse_division2 : parse_division1
		}
		Else
		{
			betrayal_member := parse_member2
			betrayal_division := (A_Index = 3) ? parse_division1 : parse_division2
		}
		IniRead, betrayal_%betrayal_member%_%betrayal_division%, ini\betrayal info.ini, %betrayal_member%, %betrayal_division%, 1
		color := "white"
		color := (betrayal_%betrayal_member%_%betrayal_division% = 2) ? "Lime" : color
		color := (betrayal_%betrayal_member%_%betrayal_division% = 3) ? "Yellow" : color
		color := (betrayal_%betrayal_member%_%betrayal_division% = 4) ? "Red" : color
		color := (betrayal_%betrayal_member%_%betrayal_division% = 5) ? "Aqua" : color
		Gui, betrayal_info_%A_Index%: Add, Text, % "BackgroundTrans Center vbetrayal_info_"A_Index "_" betrayal_member "_" betrayal_division " gBetrayal_apply w"poe_width//5 " c"color, % panel%A_Index%_text
	}
	Gui, betrayal_info_%A_Index%: Show, % "Hide y0 x"xScreenOffSet + A_Index * poe_width//25 + (A_Index - 1) * poe_width//5
	LLK_Overlay("betrayal_info_" A_Index, "show")
}
Return

Bestiary_search:
If (hotstringboard = "")
{
	SoundBeep
	Return
}
If InStr(hotstringboard, "curse")
	clipboard := "warding"
Else If InStr(hotstringboard, "bleed")
	clipboard := "sealing|lizard"
Else If InStr(hotstringboard, "shock")
	clipboard := "earthing|conger"
Else If InStr(hotstringboard, "freeze") || InStr(Clipboard, "chill")
	clipboard := "convection|deer"
Else If InStr(hotstringboard, "ignite")
	clipboard := "damping|urchin"
Else If InStr(hotstringboard, "poison")
	clipboard := "antitoxin|skunk"
Else clipboard := ""
SendInput, ^{v}
Return

Betrayal_search:
start := A_TickCount
While GetKeyState(ThisHotkey_copy, "P")
{
	If (A_TickCount >= start + 300)
	{
		Clipboard := ""
		SoundBeep
		KeyWait, %ThisHotkey_copy%
		SendInput, +#{s}
		Sleep, 1000
		WinWaitActive, ahk_group poe_window
		If (Gdip_CreateBitmapFromClipboard() < 0)
		{
			LLK_ToolTip("screen-cap failed")
			Return
		}
		Else
		{
			pBetrayal_screencap := Gdip_CreateBitmapFromClipboard()
			Gdip_GetImageDimensions(pBetrayal_screencap, wBetrayal_screencap, hBetrayal_screencap)
			hbmBetrayal_screencap := CreateDIBSection(wBetrayal_screencap, hBetrayal_screencap)
			hdcBetrayal_screencap := CreateCompatibleDC()
			obmBetrayal_screencap := SelectObject(hdcBetrayal_screencap, hbmBetrayal_screencap)
			gBetrayal_screencap := Gdip_GraphicsFromHDC(hdcBetrayal_screencap)
			Gdip_SetInterpolationMode(gBetrayal_screencap, 0)
			Gdip_DrawImage(gBetrayal_screencap, pBetrayal_screencap, 0, 0, wBetrayal_screencap, hBetrayal_screencap, 0, 0, wBetrayal_screencap, hBetrayal_screencap, 1)
		}
		Gui, betrayal_setup: New, -DPIScale -Caption +LastFound +AlwaysOnTop +ToolWindow +Border HWNDhwnd_betrayal_setup, Lailloken UI: Betrayal screen-cap
		Gui, betrayal_setup: Margin, 12, 4
		Gui, betrayal_setup: Color, Black
		WinSet, Transparent, %trans%
		Gui, betrayal_setup: Font, % "s"fSize0 " cWhite", Fontin SmallCaps
		Gui, betrayal_setup: Add, Picture, % "Section BackgroundTrans", HBitmap:*%hbmBetrayal_screencap%
		Gui, betrayal_setup: Add, DDL, ys BackgroundTrans cBlack vBetrayal_ddl Choose1 gBetrayal_apply HWNDmain_text, % StrReplace(betrayal_list, "`n", "|")
		LLK_Overlay("betrayal_setup", "show", 0)
		WinWaitActive, ahk_group poe_window
		SelectObject(hdcBetrayal_screencap, obmBetrayal_screencap)
		DeleteObject(hbmBetrayal_screencap)
		DeleteDC(hdcBetrayal_screencap)
		Gdip_DeleteGraphics(gBetrayal_screencap)
		Gdip_DisposeImage(pBetrayal_screencap)
		DllCall("DeleteObject", "ptr", hbmBetrayal_screencap)
		Return
	}
}

If ((A_Gui = "") && !WinExist("ahk_id " hwnd_betrayal_search) && (betrayal_enable_recognition = 0)) || ((betrayal_enable_recognition = 1) && GetKeyState("LShift", "P") && !WinExist("ahk_id " hwnd_betrayal_search))
{
	Gui, settings_menu: Destroy
	hwnd_settings_menu := ""
	;pixelchecks_enabled := InStr(pixelchecks_enabled, "betrayal") ? pixelchecks_enabled : pixelchecks_enabled "betrayal,"
	Gui, betrayal_search: New, -DPIScale +LastFound +AlwaysOnTop +ToolWindow +Border HWNDhwnd_betrayal_search, LLK UI: Betrayal search
	Gui, betrayal_search: Margin, 12, 4
	Gui, betrayal_search: Color, Black
	WinSet, Transparent, %trans%
	Gui, betrayal_search: Font, cWhite s%fSize0%, Fontin SmallCaps
	Gui, betrayal_search: Add, Edit, BackgroundTrans cBlack vBetrayal_searchbox HWNDmain_text, betrayal search
	Gui, betrayal_search: Add, Button, BackgroundTrans Default Hidden gBetrayal_search, OK
	ControlGetPos,,,, hEdit,, ahk_id %main_text%
	Gui, betrayal_search: Show, % "h"hEdit*1.3
	LLK_Overlay("betrayal_search", "show", 0)
	Return
}
Else If (A_Gui = "") && WinExist("ahk_id " hwnd_betrayal_search)
{
	WinActivate, ahk_id %hwnd_betrayal_search%
	Return
}

If (A_Gui = "betrayal_search")
{
	Gui, betrayal_search: Submit, NoHide
	GuiControl, Text, betrayal_searchbox,
}

If (A_Gui = "betrayal_search") && (betrayal_searchbox = "betrayal search" || StrLen(betrayal_searchbox) < 2)
{
	LLK_ToolTip("incorrect input")
	Return
}

If (A_Gui = "settings_menu")
{
	Gui, settings_menu: Submit, NoHide
	If (A_GuiControl != "betrayal_search_button")
		betrayal_searchbox := "aisling"
	GuiControl, Text, betrayal_searchbox,
}

betrayal_member := ""
parse_member1 := ""
parse_member2 := ""
parse_division1 := ""
parse_division2 := ""

If (A_Gui = "betrayal_search") || (A_Gui = "settings_menu")
{
	Loop, Parse, betrayal_searchbox, %A_Space%, %A_Space%
	{
		check := A_Loopfield
		loop := A_Index
		If (A_Index = 1 || A_Index = 3)
		{
			Loop, Parse, betrayal_list, `n, `n
			{
				If (SubStr(A_Loopfield, 1, StrLen(check)) = check)
				{
					If (loop = 1)
						parse_member1 := A_LoopField
					Else parse_member2 := A_LoopField
					Break
				}
			}
		}
		If (A_Index = 2 || A_Index = 4)
		{
			Loop, Parse, betrayal_divisions, `,, `,
			{
				If (SubStr(A_LoopField, 1, StrLen(check)) = check)
				{
					If (loop = 2)
						parse_division1 := A_LoopField
					Else parse_division2 := A_LoopField
					Break
				}
			}
		}
	}
	If ((parse_member1 != "") && (parse_division1 != "") && (parse_member2 = "")) || ((parse_member1 != "") && (parse_division1 != "") && (parse_member2 != "") && (parse_division2 = "")) || (parse_member1 = "")
	{
		LLK_ToolTip("incorrect input")
		Return
	}
	If (betrayal_enable_recognition = 1)
	{
		Gui, betrayal_search: Destroy
		hwnd_betrayal_search := ""
	}
}
Else If (betrayal_enable_recognition = 1) && (A_Gui = "")
{
	If FileExist("img\Recognition (" poe_height "p)\Betrayal\.bmp")
		FileDelete, img\Recognition (%poe_height%p)\Betrayal\.bmp
	pHaystack_betrayal := Gdip_BitmapFromHWND(hwnd_poe_client)
	Loop, Files, img\Recognition (%poe_height%p)\Betrayal\*.bmp
	{
		pNeedle_betrayal := Gdip_CreateBitmapFromFile(A_LoopFilePath)
		pSearch_betrayal := Gdip_ImageSearch(pHaystack_betrayal, pNeedle_betrayal,, 0, 0, poe_width, poe_height, imagesearch_variation,, 1, 1)
		Gdip_DisposeImage(pNeedle_betrayal)
		Gdip_DisposeImage(pSearch_betrayal)
		If (pSearch_betrayal > 0)
		{
			parse_member1 := StrReplace(A_LoopFileName, ".bmp")
			parse_member1 := StrReplace(parse_member1, "1")
			Break
		}
	}
	Gdip_DisposeImage(pHaystack_betrayal)
	If (parse_member1 != "")
		LLK_ToolTip("match found", 0.5)
	Else LLK_ToolTip("no match", 0.5)
}

If (parse_member1 = "")
	Return

If ((parse_member1 != "") && (parse_division1 = ""))
	betrayal_layout := 1
Else betrayal_layout := 2

If (betrayal_layout = 1)
{
	betrayal_member := parse_member1
	IniRead, transportation_text, data\Betrayal.ini, %betrayal_member%, transportation
	transportation_text := betrayal_member " transportation:`n" transportation_text
	IniRead, fortification_text, data\Betrayal.ini, %betrayal_member%, fortification
	fortification_text := betrayal_member " fortification:`n" fortification_text
	IniRead, research_text, data\Betrayal.ini, %betrayal_member%, research
	research_text := betrayal_member " research:`n" research_text
	IniRead, intervention_text, data\Betrayal.ini, %betrayal_member%, intervention
	intervention_text := betrayal_member " intervention:`n" intervention_text
	GoSub, Betrayal_info
}
Else
{
	IniRead, panel1_text, data\Betrayal.ini, %parse_member1%, %parse_division2%
	IniRead, panel2_text, data\Betrayal.ini, %parse_member1%, %parse_division1%
	IniRead, panel3_text, data\Betrayal.ini, %parse_member2%, %parse_division1%
	IniRead, panel4_text, data\Betrayal.ini, %parse_member2%, %parse_division2%
	If (panel1_text = "ERROR") || (panel2_text = "ERROR") || (panel3_text = "ERROR") || (panel4_text = "ERROR")
	{
		SoundBeep
		Return
	}
	panel1_text := parse_member1 " " parse_division2 " (current):`n" panel1_text
	panel2_text := parse_member1 " " parse_division1 " (target):`n" panel2_text
	panel3_text := parse_member2 " " parse_division1 " (current):`n" panel3_text
	panel4_text := parse_member2 " " parse_division2 " (target):`n" panel4_text
	GoSub, Betrayal_info
}
Return

Betrayal_searchGuiClose:
LLK_Overlay("betrayal_search", "hide")
Return

Clone_frames_apply:
Gui, Settings_menu: Submit, NoHide
If InStr(A_GuiControl, "pixel")
{
	If (pixel_gamescreen_color1 = "ERROR") || (pixel_gamescreen_color1 = "")
	{
		LLK_ToolTip("pixel-check setup required")
		clone_frames_pixelcheck_enable := 0
		GuiControl, settings_menu: , clone_frames_pixelcheck_enable, 0
		Return
	}
	If (clone_frames_pixelcheck_enable = 0)
		IniWrite, 0, ini\clone frames.ini, Settings, enable pixel-check
	Else IniWrite, 1, ini\clone frames.ini, Settings, enable pixel-check
	GoSub, Screenchecks_gamescreen
	Return
}
clone_frames_enabled := ""
Loop, Parse, clone_frames_list, `n, `n
{
	Gui, clone_frames_%A_Loopfield%: Hide
	If (clone_frame_%A_LoopField%_enable = 1)
		clone_frames_enabled := (clone_frames_enabled = "") ? A_LoopField "," : A_LoopField "," clone_frames_enabled
	Else guilist := StrReplace(guilist, "clone_frames_" A_Loopfield "|")
}
GoSub, GUI_clone_frames
Return

Clone_frames_dimensions:
Gui, clone_frames_menu: Submit, NoHide
GuiControl, clone_frames_menu: Text, clone_frame_new_dimensions, % clone_frame_new_width " x " clone_frame_new_height " pixels"
Gui, clone_frame_preview: New, -Caption +E0x80000 +E0x20 +LastFound +AlwaysOnTop +ToolWindow +OwnDialogs HWNDhwnd_clone_frame_preview
Gui, clone_frame_preview: Show, NA
Gui, clone_frame_preview_frame: New, -Caption +E0x20 +LastFound +AlwaysOnTop +ToolWindow +Border +OwnDialogs HWNDhwnd_clone_frame_preview_frame
Gui, clone_frame_preview_frame: Color, Black
WinSet, TransColor, Black
If ((clone_frame_new_width > 1) && (clone_frame_new_height > 1))
	Gui, clone_frame_preview_frame: Show, % "NA x"clone_frame_new_topleft_x - 1 " y"clone_frame_new_topleft_y - 1 " w"clone_frame_new_width " h"clone_frame_new_height
Else Gui, clone_frame_preview_frame: Hide
SetTimer, Clone_frames_preview, 100
Return

Clone_frames_delete:
delete_string := StrReplace(A_GuiControl, "delete_", "")
IniDelete, ini\clone frames.ini, %delete_string%
Gui, clone_frames_%delete_string%: Destroy
guilist := StrReplace(guilist, "clone_frames_" delete_string "|")
new_clone_menu_closed := 1
GoSub, Settings_menu
Return

Clone_frames_new:
Gui, settings_menu: Submit
LLK_Overlay("settings_menu", "hide")
If (clone_frames_edit_mode = 1)
{
	edit_string := StrReplace(A_GuiControl, "edit_", "")
	clone_frames_enabled := StrReplace(clone_frames_enabled, edit_string ",")
	Gui, clone_frames_%edit_string%: Hide
	IniRead, clone_frame_edit_topleft_x, ini\clone frames.ini, %edit_string%, source x-coordinate
	IniRead, clone_frame_edit_topleft_y, ini\clone frames.ini, %edit_string%, source y-coordinate
	IniRead, clone_frame_edit_width, ini\clone frames.ini, %edit_string%, frame-width
	IniRead, clone_frame_edit_height, ini\clone frames.ini, %edit_string%, frame-height
	IniRead, clone_frame_edit_target_x, ini\clone frames.ini, %edit_string%, target x-coordinate
	IniRead, clone_frame_edit_target_y, ini\clone frames.ini, %edit_string%, target y-coordinate
	IniRead, clone_frame_edit_scale_x, ini\clone frames.ini, %edit_string%, scaling x-axis, 100
	IniRead, clone_frame_edit_scale_y, ini\clone frames.ini, %edit_string%, scaling y-axis, 100
	IniRead, clone_frame_edit_opacity, ini\clone frames.ini, %edit_string%, opacity, 5
	clone_frames_edit_mode := 0
}
Else
{
	edit_string := ""
	clone_frame_edit_topleft_x := 0
	clone_frame_edit_topleft_y := 0
	clone_frame_edit_width := 0
	clone_frame_edit_height := 0
	clone_frame_edit_target_x := xScreenOffSet
	clone_frame_edit_target_y := yScreenOffSet
	clone_frame_edit_scale_x := 100
	clone_frame_edit_scale_y := 100
	clone_frame_edit_opacity := 5
}
Gui, clone_frames_menu: New, -DPIScale +LastFound +AlwaysOnTop +ToolWindow +Border HWNDhwnd_clone_frames_menu, Lailloken UI: clone-frame configuration
Gui, clone_frames_menu: Color, Black
Gui, clone_frames_menu: Margin, 12, 4
WinSet, Transparent, %trans%
Gui, clone_frames_menu: Font, s%fSize0% cWhite, Fontin SmallCaps

Gui, clone_frames_menu: Add, Text, Section BackgroundTrans HWNDmain_text, % "unique frame name: "
ControlGetPos,,, width,,, ahk_id %main_text%

Gui, clone_frames_menu: Font, % "s"fSize0-4 "norm"
Gui, clone_frames_menu: Add, Edit, % "ys x+0 hp BackgroundTrans cBlack limit lowercase vClone_frame_new_name w"width, % edit_string
Gui, clone_frames_menu: Add, Edit, % "xs Section BackgroundTrans cWhite Number ReadOnly right Limit4 vClone_frame_new_topleft_x gClone_frames_dimensions y+"fSize0*1.2, % xScreenOffSet + poe_width
Gui, clone_frames_menu: Add, UpDown, % "ys BackgroundTrans cBlack 0x80 gClone_frames_dimensions range0-"xScreenOffSet + poe_width, % xScreenOffSet + poe_width
Gui, clone_frames_menu: Add, Edit, % "ys BackgroundTrans cWhite Number ReadOnly right Limit4 gClone_frames_dimensions vClone_frame_new_topleft_y x+"fSize0//3, % yScreenOffSet + poe_height
Gui, clone_frames_menu: Add, UpDown, % "ys BackgroundTrans cBlack 0x80 gClone_frames_dimensions range0-"yScreenOffSet + poe_height, % yScreenOffSet + poe_height
Gui, clone_frames_menu: Font, % "s"fSize0
Gui, clone_frames_menu: Add, Text, ys x+0 BackgroundTrans, % " source top-left corner (f1: snap to cursor)"

Gui, clone_frames_menu: Font, % "s"fSize0-4 "norm"
Gui, clone_frames_menu: Add, Edit, % "xs Section BackgroundTrans cWhite Number ReadOnly Limit4 gClone_frames_dimensions right vClone_frame_new_width", % xScreenOffSet + poe_width
Gui, clone_frames_menu: Add, UpDown, % "ys BackgroundTrans cBlack 0x80 gClone_frames_dimensions range0-"xScreenOffSet + poe_width, 0
Gui, clone_frames_menu: Add, Edit, % "ys hp BackgroundTrans cWhite Number ReadOnly Limit4 gClone_frames_dimensions right vClone_frame_new_height x+"fSize0//3, % yScreenOffSet + poe_height
Gui, clone_frames_menu: Add, UpDown, % "ys BackgroundTrans cBlack 0x80 gClone_frames_dimensions range0-"yScreenOffSet + poe_height, 0
Gui, clone_frames_menu: Font, % "s"fSize0
Gui, clone_frames_menu: Add, Text, % "ys x+0 BackgroundTrans", % " frame width && height (f2: snap to cursor)"

Gui, clone_frames_menu: Font, % "s"fSize0-4 "norm"
Gui, clone_frames_menu: Add, Edit, % "xs Section BackgroundTrans cWhite Number ReadOnly right Limit4 vClone_frame_new_target_x gClone_frames_dimensions", % xScreenOffSet + poe_width
Gui, clone_frames_menu: Add, UpDown, % "ys BackgroundTrans cBlack 0x80 gClone_frames_dimensions range0-"xScreenOffSet + poe_width, % xScreenOffSet + poe_width
Gui, clone_frames_menu: Add, Edit, % "ys BackgroundTrans cWhite Number ReadOnly right Limit4 vClone_frame_new_target_y gClone_frames_dimensions x+"fSize0//3, % yScreenOffSet + poe_height
Gui, clone_frames_menu: Add, UpDown, % "ys BackgroundTrans cBlack 0x80 gClone_frames_dimensions range0-"yScreenOffSet + poe_height, % yScreenOffSet + poe_height
Gui, clone_frames_menu: Font, % "s"fSize0
Gui, clone_frames_menu: Add, Text, % "ys x+0 BackgroundTrans", % " target top-left corner (f3: snap to cursor)"

GuiControl, clone_frames_menu: Text, clone_frame_new_topleft_x, % clone_frame_edit_topleft_x
GuiControl, clone_frames_menu: Text, clone_frame_new_topleft_y, % clone_frame_edit_topleft_y
GuiControl, clone_frames_menu: Text, clone_frame_new_width, % clone_frame_edit_width
GuiControl, clone_frames_menu: Text, clone_frame_new_height, % clone_frame_edit_height
GuiControl, clone_frames_menu: Text, clone_frame_new_target_x, % clone_frame_edit_target_x
GuiControl, clone_frames_menu: Text, clone_frame_new_target_y, % clone_frame_edit_target_y

Gui, clone_frames_menu: Font, % "s"fSize0-4 "norm"
Gui, clone_frames_menu: Add, Edit, % "xs Section BackgroundTrans cBlack Number Limit4 gClone_frames_dimensions right vClone_frame_new_scale_x", 1000
Gui, clone_frames_menu: Add, UpDown, % "ys BackgroundTrans cBlack 0x80 gClone_frames_dimensions range10-1000", % clone_frame_edit_scale_x
Gui, clone_frames_menu: Add, Edit, % "ys hp BackgroundTrans cBlack Number Limit4 gClone_frames_dimensions right vClone_frame_new_scale_y x+"fSize0//3, 1000
Gui, clone_frames_menu: Add, UpDown, % "ys BackgroundTrans cBlack 0x80 gClone_frames_dimensions range10-1000", % clone_frame_edit_scale_y
Gui, clone_frames_menu: Font, % "s"fSize0
Gui, clone_frames_menu: Add, Text, % "ys x+0 BackgroundTrans", % " x/y-axis scaling (%)"

Gui, clone_frames_menu: Font, % "s"fSize0-4 "norm"
Gui, clone_frames_menu: Add, Edit, % "ys BackgroundTrans cWhite Number ReadOnly Limit3 ReadOnly gClone_frames_dimensions right vClone_frame_new_opacity", 10
Gui, clone_frames_menu: Add, UpDown, % "ys BackgroundTrans cBlack 0x80 gClone_frames_dimensions range0-5", % clone_frame_edit_opacity
Gui, clone_frames_menu: Font, % "s"fSize0
Gui, clone_frames_menu: Add, Text, % "ys x+0 BackgroundTrans", % " opacity (0-5)"

Gui, clone_frames_menu: Add, Text, % "xs BackgroundTrans HWNDmain_text Border vSave_clone_frame gClone_frames_save y+"fSize0*1.2, % " save && close "
Gui, clone_frames_menu: Show, % "Hide"
WinGetPos,,, win_width, win_height
Gui, clone_frames_menu: Show, % "Hide x"xScreenOffSet + poe_width//2 - win_width//2 " y"yScreenOffSet + poe_height//2 - win_height//2
edit_string := ""
LLK_Overlay("clone_frames_menu", "show", 0)
Gui, clone_frames_menu: Submit, NoHide
Return

Clone_frames_menuGuiClose:
SetTimer, Clone_frames_preview, Delete
new_clone_menu_closed := 1
GoSub, Settings_menu
Gui, clone_frame_preview: Destroy
Gui, clone_frame_preview_frame: Destroy
Gui, clone_frames_menu: Destroy
Return

Clone_frames_preview:
pPreview := Gdip_BitmapFromScreen(clone_frame_new_topleft_x "|" clone_frame_new_topleft_y "|" clone_frame_new_width "|" clone_frame_new_height)
wPreview := clone_frame_new_width
hPreview := clone_frame_new_height
wPreview_dest := clone_frame_new_width * clone_frame_new_scale_x//100
hPreview_dest := clone_frame_new_height * clone_frame_new_scale_y//100
hbmPreview := CreateDIBSection(wPreview_dest, hPreview_dest)
hdcPreview := CreateCompatibleDC()
obmPreview := SelectObject(hdcPreview, hbmPreview)
gPreview := Gdip_GraphicsFromHDC(hdcPreview)
Gdip_SetInterpolationMode(gPreview, 0)
Gdip_DrawImage(gPreview, pPreview, 0, 0, wPreview_dest, hPreview_dest, 0, 0, wPreview, hPreview, 0.2 + 0.16 * clone_frame_new_opacity)
UpdateLayeredWindow(hwnd_clone_frame_preview, hdcPreview, clone_frame_new_target_x, clone_frame_new_target_y, wPreview_dest, hPreview_dest)
SelectObject(hdcPreview, obmPreview)
DeleteObject(hbmPreview)
DeleteDC(hdcPreview)
Gdip_DeleteGraphics(gPreview)
Gdip_DisposeImage(pPreview)
Return

Clone_frames_preview_list:
MouseGetPos, mouseXpos, mouseYpos
If (click = 2)
{
	Gui, clone_frame_context_menu: New, -Caption +Border +LastFound +AlwaysOnTop +ToolWindow +OwnDialogs HWNDhwnd_clone_frame_context_menu
	Gui, clone_frame_context_menu: Margin, % fSize0//2, fSize0//2
	Gui, clone_frame_context_menu: Color, Black
	WinSet, Transparent, %trans%
	Gui, clone_frame_context_menu: Font, cWhite s%fSize0%, Fontin SmallCaps
	clone_frames_edit_mode := 1
	Gui, clone_frame_context_menu: Add, Text, Section BackgroundTrans vEdit_%A_GuiControl% gClone_frames_new, edit
	Gui, clone_frame_context_menu: Add, Text, % "xs BackgroundTrans vDelete_" A_GuiControl " gClone_frames_delete y+"fSize0//2, delete
	Gui, clone_frame_context_menu: Show, % "AutoSize x"mouseXpos + fSize0 " y"mouseYpos + fSize0
	WinWaitNotActive, ahk_id %hwnd_clone_frame_context_menu%
	clone_frames_edit_mode := 0
	Gui, clone_frame_context_menu: Destroy
	Return
}
Gui, clone_frame_preview_list: New, -Caption +E0x80000 +E0x20 +LastFound +AlwaysOnTop +ToolWindow +OwnDialogs HWNDhwnd_clone_frame_preview_list
Gui, clone_frame_preview_list: Show, NA
Gui, clone_frame_preview_list_frame: New, -Caption +E0x20 +LastFound +AlwaysOnTop +ToolWindow +OwnDialogs HWNDhwnd_clone_frame_preview_list_frame
Gui, clone_frame_preview_list_frame: Color, Red
bmpPreview_list := Gdip_BitmapFromScreen(clone_frame_%A_GuiControl%_topleft_x "|" clone_frame_%A_GuiControl%_topleft_y "|" clone_frame_%A_GuiControl%_width "|" clone_frame_%A_GuiControl%_height)
Gdip_GetImageDimensions(bmpPreview_list, WidthPreview_list, HeightPreview_list)
hbmPreview_list := CreateDIBSection(WidthPreview_list, HeightPreview_list)
hdcPreview_list := CreateCompatibleDC()
obmPreview_list := SelectObject(hdcPreview_list, hbmPreview_list)
GPreview_list := Gdip_GraphicsFromHDC(hdcPreview_list)
Gdip_SetInterpolationMode(GPreview_list, 0)
Gdip_DrawImage(GPreview_list, bmpPreview_list, 0, 0, WidthPreview_list, HeightPreview_list, 0, 0, WidthPreview_list, HeightPreview_list, 1)
UpdateLayeredWindow(hwnd_clone_frame_Preview_list, hdcPreview_list, mouseXpos, mouseYpos, WidthPreview_list, HeightPreview_list)
Gui, clone_frame_preview_list_frame: Show, % "NA x"mouseXpos - fSize0//6 " y"mouseYpos - fSize0//6 " w"WidthPreview_list + 2*(fSize0//6) " h"HeightPreview_list + 2*(fSize0//6)
Gui, clone_frame_preview_list: Show, NA
KeyWait, LButton
Gui, clone_frame_preview_list: Destroy
Gui, clone_frame_preview_list_frame: Destroy
SelectObject(hdcPreview_list, obmPreview_list)
DeleteObject(hbmPreview_list)
DeleteDC(hdcPreview_list)
Gdip_DeleteGraphics(GPreview_list)
Gdip_DisposeImage(bmpPreview_list)
Return

Clone_frames_save:
Gui, clone_frames_menu: Submit, NoHide
clone_frame_new_name_first_letter := SubStr(clone_frame_new_name, 1, 1)
If (clone_frame_new_name = "")
{
	LLK_ToolTip("enter name")
	Return
}
If (clone_frame_new_name = "settings")
{
	LLK_ToolTip("The selected name is not allowed.`nPlease choose a different name.", 3)
	GuiControl, clone_frames_menu: Text, clone_frame_new_name,
	Return
}
If clone_frame_new_name_first_letter is not alnum
{
	LLK_ToolTip("Unsupported first character in frame-name detected.`nPlease choose a different name.", 3)
	GuiControl, clone_frames_menu: Text, clone_frame_new_name,
	Return
}
If (clone_frame_new_width < 1) || (clone_frame_new_height < 1)
{
	LLK_ToolTip("Incorrect dimensions detected.`nPlease make sure to set the source corners properly.", 3)
	Return
}
clone_frame_new_name_save := ""
Loop, Parse, clone_frame_new_name
{
	If (A_LoopField = A_Space)
		add_character := "_"
	Else If A_LoopField is not alnum
		add_character := "_"
	Else add_character := A_LoopField
	clone_frame_new_name_save := (clone_frame_new_name_save = "") ? add_character : clone_frame_new_name_save add_character
}
IniWrite, %clone_frame_new_topleft_x%, ini\clone frames.ini, %clone_frame_new_name_save%, source x-coordinate
IniWrite, %clone_frame_new_topleft_y%, ini\clone frames.ini, %clone_frame_new_name_save%, source y-coordinate
IniWrite, %clone_frame_new_target_x%, ini\clone frames.ini, %clone_frame_new_name_save%, target x-coordinate
IniWrite, %clone_frame_new_target_y%, ini\clone frames.ini, %clone_frame_new_name_save%, target y-coordinate
IniWrite, %clone_frame_new_width%, ini\clone frames.ini, %clone_frame_new_name_save%, frame-width
IniWrite, %clone_frame_new_height%, ini\clone frames.ini, %clone_frame_new_name_save%, frame-height
IniWrite, %clone_frame_new_scale_x%, ini\clone frames.ini, %clone_frame_new_name_save%, scaling x-axis
IniWrite, %clone_frame_new_scale_y%, ini\clone frames.ini, %clone_frame_new_name_save%, scaling y-axis
IniWrite, %clone_frame_new_opacity%, ini\clone frames.ini, %clone_frame_new_name_save%, opacity
clone_frame_%clone_frame_new_name_save%_topleft_x := clone_frame_new_topleft_x
clone_frame_%clone_frame_new_name_save%_topleft_y := clone_frame_new_topleft_y
clone_frame_%clone_frame_new_name_save%_target_x := clone_frame_new_target_x
clone_frame_%clone_frame_new_name_save%_target_y := clone_frame_new_target_y
clone_frame_%clone_frame_new_name_save%_width := clone_frame_new_width
clone_frame_%clone_frame_new_name_save%_height := clone_frame_new_height
clone_frame_%clone_frame_new_name_save%_scale_x := clone_frame_new_scale_x
clone_frame_%clone_frame_new_name_save%_scale_y := clone_frame_new_scale_y
clone_frame_%clone_frame_new_name_save%_opacity := clone_frame_new_opacity
guilist := InStr(guilist, clone_frame_new_name_save) ? guilist : guilist "clone_frames_" clone_frame_new_name_save "|"
GoSub, Clone_frames_menuGuiClose
Return

Exit:
Gdip_Shutdown(pToken)
If (timeout != 1)
{
	IniWrite, %alarm_xpos%, ini\alarm.ini, UI, xcoord
	IniWrite, %alarm_ypos%, ini\alarm.ini, UI, ycoord
	alarm_timestamp := (alarm_timestamp < A_Now) ? "" : alarm_timestamp
	IniWrite, %alarm_timestamp%, ini\alarm.ini, Settings, alarm-timestamp
	
	IniWrite, %notepad_xpos%, ini\notepad.ini, UI, xcoord
	IniWrite, %notepad_ypos%, ini\notepad.ini, UI, ycoord
	IniWrite, %notepad_width%, ini\notepad.ini, UI, width
	IniWrite, %notepad_height%, ini\notepad.ini, UI, height
	notepad_text := StrReplace(notepad_text, "`n", ",,")
	IniWrite, %notepad_text%, ini\notepad.ini, Text, text
	
	Loop, Parse, clone_frames_list, `n, `n
	{
		If (A_LoopField = "Settings")
			continue
		IniWrite, % clone_frame_%A_LoopField%_enable, ini\clone frames.ini, %A_LoopField%, enable
	}
}
ExitApp
Return

Geforce_now_apply:
Gui, settings_menu: Submit, NoHide
pixelsearch_variation := (pixelsearch_variation = "") ? 0 : pixelsearch_variation
pixelsearch_variation := (pixelsearch_variation > 255) ? 255 : pixelsearch_variation
imagesearch_variation := (imagesearch_variation = "") ? 0 : imagesearch_variation
imagesearch_variation := (imagesearch_variation > 255) ? 255 : imagesearch_variation
If (A_GuiControl = "pixelsearch_variation")
	IniWrite, % pixelsearch_variation, ini\geforce now.ini, Settings, pixel-check variation
If (A_GuiControl = "imagesearch_variation")
	IniWrite, % imagesearch_variation, ini\geforce now.ini, Settings, image-check variation
Return

GUI:
Gui, LLK_panel: New, -DPIScale -Caption +LastFound +AlwaysOnTop +ToolWindow +Border HWNDhwnd_LLK_panel
Gui, LLK_panel: Margin, 2, 2
Gui, LLK_panel: Color, Black
WinSet, Transparent, %trans%
Gui, LLK_panel: Font, % "s"fSize1 " cWhite underline", Fontin SmallCaps
If (enable_notepad = 1) || (enable_alarm = 1)
	Gui, LLK_panel: Add, Text, Section Center BackgroundTrans HWNDmain_text gSettings_menu, % "LLK:"
Else Gui, LLK_panel: Add, Text, Section Center BackgroundTrans HWNDmain_text gSettings_menu, % "LLK"
ControlGetPos,, ypos,, height,, ahk_id %main_text%
If (enable_notepad = 1)
	Gui, LLK_panel: Add, Picture, % "ys x+6 Center BackgroundTrans hp w-1 gNotepad", img\GUI\notepad.jpg
If (enable_alarm = 1)
	Gui, LLK_panel: Add, Picture, % "ys x+6 Center BackgroundTrans hp w-1 gAlarm", img\GUI\alarm.jpg
Gui, LLK_panel: Show, Hide
WinGetPos,,, panel_width, panel_height
panel_style := (hide_panel = 1) ? "hide" : "show"
panel_xpos := (panel_position1 = "left") ? xScreenOffset : xScreenOffset + poe_width - panel_width
panel_ypos := (panel_position0 = "bottom") ? yScreenOffset + poe_height - panel_height : yScreenOffset
Gui, LLK_panel: Show, % "Hide x"panel_xpos " y"panel_ypos
LLK_Overlay("LLK_panel", panel_style)
If (continue_alarm = 1)
	GoSub, Alarm
Return

GUI_clone_frames:
Loop, Parse, clone_frames_enabled, `,, `,
{
	If (A_Loopfield = "")
		Break
	Gui, clone_frames_%A_Loopfield%: New, -Caption +E0x80000 +E0x20 +LastFound +AlwaysOnTop +ToolWindow +OwnDialogs HWNDhwnd_%A_Loopfield%
	guilist := InStr(guilist, A_Loopfield) ? guilist : guilist "clone_frames_" A_Loopfield "|"
}
Return

Gwennen_search:
If (A_GuiControl = "gwennen_regex_edit")
{
	Gui, gwennen_setup: Submit
	IniWrite, %gwennen_regex_edit%, ini\gwennen.ini, regex, regex
	Gui, gwennen_setup: Destroy
	hwnd_gwennen_setup := ""
	Return
}
start := A_TickCount
While GetKeyState(ThisHotkey_copy, "P")
{
	If (A_TickCount >= start + 300)
	{
		Gui, gwennen_setup: New, -DPIScale -Caption +LastFound +AlwaysOnTop +ToolWindow +Border HWNDhwnd_gwennen_setup
		Gui, gwennen_setup: Margin, 12, 4
		Gui, gwennen_setup: Color, Black
		WinSet, Transparent, %trans%
		Gui, gwennen_setup: Font, % "s"fSize0 " cWhite", Fontin SmallCaps
		Gui, gwennen_setup: Add, Link, % "Section HWNDlink_text", <a href="https://xanthics.github.io/poe_gen_gwennen/">regex-string generator by xanthics</a>
		Gui, gwennen_setup: Font, % "s"fSize0 - 4
		Gui, gwennen_setup: Add, Edit, xs wp Section vgwennen_regex_edit gGwennen_search HWNDmain_text BackgroundTrans center cBlack,
		Gui, gwennen_setup: Font, % "s"fSize0
		Gui, gwennen_setup: Show
		LLK_Overlay("gwennen_setup", "show", 0)
		ControlFocus,, ahk_id %main_text%
		KeyWait, %ThisHotkey_copy%
		Return
	}
}
IniRead, gwennen_check, ini\gwennen.ini, regex, regex
If (hotstringboard = "") && (gwennen_check = "ERROR" || gwennen_check = "")
{
	LLK_ToolTip("no regex string saved")
	Return
}
IniRead, gwennen_regex, ini\gwennen.ini, regex, regex
gwennen_regex = "%gwennen_regex%"
If (hotstringboard = "") && (gwennen_regex != "ERROR" && gwennen_regex != "")
{
	Clipboard := gwennen_regex
	ClipWait
	SendInput, ^{v}
}
Return

Lab_info:
If (A_Gui = "context_menu") || InStr(A_ThisHotkey, ":")
{
	lab_mode := 1
	Run, https://www.poelab.com
	Return
}
If (A_GuiControl = "Lab_marker")
{
	Gui, lab_marker: New, -DPIScale -Caption +E0x20 +LastFound +AlwaysOnTop +ToolWindow +Border HWNDhwnd_lab_marker
	Gui, lab_marker: Color, White
	WinSet, Transparent, 100
	MouseGetPos, mouseXpos, mouseYpos
	Gui, lab_marker: Show, % "NA w"poe_width * 3//160 * 212//235 " h"poe_width * 3//160 * 212//235 " x"mouseXpos - (poe_width * 3//160 * 212//235)//2 " y"mouseYpos - (poe_width * 3//160 * 212//235)//2
	LLK_Overlay("lab_marker", "show")
	WinActivate, ahk_group poe_window
	Return
}
If (A_ThisHotkey = "Tab")
{
	If (hwnd_lab_layout = "")
	{
		If (Gdip_CreateBitmapFromClipboard() < 0)
		{
			LLK_ToolTip("no image-data in clipboard", 1.5, xScreenOffSet + poe_width//2, yScreenOffSet + poe_height//2)
			KeyWait, Tab
			Return
		}
		pLab_source := Gdip_CloneBitmapArea(Gdip_CreateBitmapFromClipboard(), 257, 42, 1175, 521)
		wLab_source := 1175
		hLab_source := 521
		hbmLab_source := CreateDIBSection(wLab_source, hLab_source)
		hdcLab_source := CreateCompatibleDC()
		obmLab_source := SelectObject(hdcLab_source, hbmLab_source)
		gLab_source := Gdip_GraphicsFromHDC(hdcLab_source)
		Gdip_SetInterpolationMode(gLab_source, 0)
		Gdip_DrawImage(gLab_source, pLab_source, 0, 0, wLab_source, hLab_source, 0, 0, wLab_source, hLab_source, 1)
		Gui, lab_layout: New, -DPIScale -Caption +E0x20 +LastFound +AlwaysOnTop +ToolWindow +Border HWNDhwnd_lab_layout, Lailloken UI: lab-info
		Gui, lab_layout: Color, Black
		Gui, lab_layout: Margin, 0, 0
		Gui, lab_layout: Font, s%fSize0% cWhite, Fontin SmallCaps
		Gui, lab_layout: Add, Picture, % "BackgroundTrans vLab_marker gLab_info w" poe_width * 53//128 " h-1", HBitmap:*%hbmLab_source%
		Gui, lab_layout: Show, Hide
		WinGetPos,,,, hWin
		Gui, lab_layout: Show, % "NA x"xScreenOffSet + poe_width * 75//256 " y"yScreenOffSet + poe_height - hWin
		LLK_Overlay("lab_layout", "show")
		SelectObject(hdcLab_source, obmLab_source)
		DeleteObject(hbmLab_source)
		DeleteDC(hdcLab_source)
		Gdip_DeleteGraphics(gLab_source)
		Gdip_DisposeImage(pLab_source)
	}
	Else
	{
		LLK_Overlay("lab_layout", "toggle")
		LLK_Overlay("lab_marker", "toggle")
	}
	KeyWait, Tab
}
Return

Loop:
If !WinExist("ahk_group poe_window")
{
	poe_window_closed := 1
	hwnd_poe_client := ""
}
If !WinExist("ahk_group poe_window") && (A_TickCount >= last_check + kill_timeout*60000) && (kill_script = 1) && (alarm_timestamp = "")
	ExitApp
If WinExist("ahk_group poe_window")
{
	last_check := A_TickCount
	If (hwnd_poe_client = "")
		hwnd_poe_client := WinExist("ahk_group poe_window")
	If (poe_window_closed = 1) && (custom_resolution_setting = 1)
	{
		If !WinActive("ahk_class POEWindowClass")
			Return
		WinMove, ahk_group poe_window,, %xScreenOffset%, %yScreenOffset%, %poe_width%, %custom_resolution%
		poe_height := custom_resolution
		hwnd_poe_client := WinExist("ahk_group poe_window")
		poe_window_closed := 0
	}
}

If (enable_alarm != 0) && (alarm_timestamp != "")
{
	alarm_timestamp0 := alarm_timestamp
	EnvSub, alarm_timestamp0, %A_Now%, S
	If (alarm_timestamp0 > 0)
	{
		countdown_min := (StrLen(Floor(alarm_timestamp0//60)) = 1) ? 0 Floor(alarm_timestamp0//60) : Floor(alarm_timestamp0//60)
		countdown_sec := (StrLen(Mod(alarm_timestamp0, 60)) = 1) ? 0 Mod(alarm_timestamp0, 60) : Mod(alarm_timestamp0, 60)
		GuiControl, alarm: Text, alarm_countdown, % countdown_min ":" countdown_sec
	}
	Else
	{
		alarm_fontcolor0 := (alarm_fontcolor0 = "Blue") ? alarm_fontcolor : "Blue"
		Gui, alarm: Font, c%alarm_fontcolor0%
		GuiControl, alarm: Font, alarm_countdown
		countdown_min := (StrLen(Floor(alarm_timestamp0//-60)) = 1) ? 0 Floor(alarm_timestamp0//-60) : Floor(alarm_timestamp0//-60)
		countdown_sec := (StrLen(Mod(alarm_timestamp0, -60)) < 3) ? 0 Mod(alarm_timestamp0, -60) * -1 : Mod(alarm_timestamp0, -60) * -1
		GuiControl, alarm: Text, alarm_countdown, % countdown_min ":" countdown_sec
		If !WinActive("ahk_group poe_window")
		{
			WinSet, Style, +0xC00000, ahk_id %hwnd_alarm%
			WinSet, ExStyle, -0x20, ahk_id %hwnd_alarm%
			Gui, alarm: Show, % "NA AutoSize"
		}
		If !WinExist("ahk_id " hwnd_alarm) && WinExist("ahk_group poe_window")
			LLK_Overlay("alarm", "show")
	}
}
Return

MainLoop:
If !WinActive("ahk_group poe_window") && !WinActive("ahk_class AutoHotkeyGUI")
{
	inactive_counter += 1
	If (inactive_counter = 3)
	{
		Gui, context_menu: Destroy
		LLK_Overlay("hide")
	}
}
If WinActive("ahk_group poe_window") || WinActive("ahk_class AutoHotkeyGUI")
{
	If (inactive_counter != 0)
	{
		inactive_counter := 0
		LLK_Overlay("show")
	}
	If (pixelchecks_enabled != "") && (enable_pixelchecks = 1)
	{
		Loop, Parse, pixelchecks_enabled, `,, `,
		{
			If (A_LoopField = "")
				break
			LLK_PixelSearch(A_LoopField)
		}
		/*
		If (betrayal = 0)
		{
			Gui, betrayal_search: Destroy
			hwnd_betrayal_search := ""
			Loop 4
				LLK_Overlay("betrayal_info_" A_Index, "hide")
			pixelchecks_enabled := StrReplace(pixelchecks_enabled, "betrayal,")
			betrayal := ""
			Return
		}
		*/
		If (map_info_pixelcheck_enable = 1)
		{
			If (gamescreen = 1)
			{
				If !WinExist("ahk_id " hwnd_map_mods_window) && (toggle_map_mods_panel = 1) && (hwnd_map_mods_window != "") || (map_mods_panel_fresh = 1)
				{
					LLK_Overlay("map_mods_window", "show")
					map_mods_panel_fresh := 0
				}
				If !WinExist("ahk_id " hwnd_map_mods_toggle) && (hwnd_map_mods_toggle != "") || (map_mods_panel_fresh = 1)
				{
					LLK_Overlay("map_mods_toggle", "show")
					map_mods_panel_fresh := 0
				}
			}
			Else
			{
				If WinExist("ahk_id " hwnd_map_mods_window) && (map_mods_panel_fresh != 1) && (hwnd_map_mods_window != "")
					LLK_Overlay("map_mods_window", "hide")
				If WinExist("ahk_id " hwnd_map_mods_toggle) && (map_mods_panel_fresh != 1) && (hwnd_map_mods_window != "")
					LLK_Overlay("map_mods_toggle", "hide")
			}
		}
	}
	If ((clone_frames_enabled != "") && (clone_frames_pixelcheck_enable = 0)) || ((clone_frames_enabled != "") && (clone_frames_pixelcheck_enable = 1) && (gamescreen = 1))
	{
		Loop, Parse, clone_frames_enabled, `,, `,
		{
			If (A_LoopField = "")
				Break
			If !WinExist("ahk_id " hwnd_%A_Loopfield%)
				Gui, clone_frames_%A_Loopfield%: Show, NA
			p%A_LoopField% := Gdip_BitmapFromScreen(clone_frame_%A_LoopField%_topleft_x "|" clone_frame_%A_LoopField%_topleft_y "|" clone_frame_%A_LoopField%_width "|" clone_frame_%A_LoopField%_height)
			w%A_LoopField% := clone_frame_%A_LoopField%_width
			h%A_LoopField% := clone_frame_%A_LoopField%_height
			w%A_LoopField%_dest := clone_frame_%A_LoopField%_width * clone_frame_%A_LoopField%_scale_x//100
			h%A_LoopField%_dest := clone_frame_%A_LoopField%_height * clone_frame_%A_LoopField%_scale_y//100
			hbm%A_LoopField% := CreateDIBSection(w%A_LoopField%_dest, h%A_LoopField%_dest)
			hdc%A_LoopField% := CreateCompatibleDC()
			omb%A_LoopField% := SelectObject(hdc%A_LoopField%, hbm%A_LoopField%)
			g%A_LoopField% := Gdip_GraphicsFromHDC(hdc%A_LoopField%)
			Gdip_SetInterpolationMode(g%A_LoopField%, 0)
			Gdip_DrawImage(g%A_LoopField%, p%A_LoopField%, 0, 0, w%A_LoopField%_dest, h%A_LoopField%_dest, 0, 0, w%A_LoopField%, h%A_LoopField%, 0.2 + 0.16 * clone_frame_%A_LoopField%_opacity)
			Gdip_DisposeImage(p%A_LoopField%)
			UpdateLayeredWindow(hwnd_%A_LoopField%, hdc%A_LoopField%, clone_frame_%A_LoopField%_target_x, clone_frame_%A_LoopField%_target_y, w%A_LoopField%_dest, h%A_LoopField%_dest)
			SelectObject(hdc%A_Loopfield%, obm%A_Loopfield%)
			DeleteObject(hbm%A_Loopfield%)
			DeleteDC(hdc%A_Loopfield%)
			Gdip_DeleteGraphics(g%A_Loopfield%)
		}
		
		/*
		hbmClone_frames := CreateDIBSection(poe_width, poe_height)
		hdcClone_frames := CreateCompatibleDC()
		obmClone_frames := SelectObject(hdcClone_frames, hbmClone_frames)
		GClone_frames := Gdip_GraphicsFromHDC(hdcClone_frames)
		Gdip_SetInterpolationMode(GClone_frames, 0)
		
		Loop, Parse, clone_frames_enabled, `,, `,
		{
			If (A_LoopField = "")
				Break
			bmpClone_frames := Gdip_BitmapFromScreen(clone_frame_%A_LoopField%_topleft_x "|" clone_frame_%A_LoopField%_topleft_y "|" clone_frame_%A_LoopField%_width "|" clone_frame_%A_LoopField%_height)
			Gdip_GetImageDimensions(bmpClone_frames, WidthClone_frames, HeightClone_frames)
			Gdip_DrawImage(GClone_frames, bmpClone_frames, clone_frame_%A_LoopField%_target_x - xScreenOffSet, clone_frame_%A_LoopField%_target_y - yScreenOffSet, clone_frame_%A_LoopField%_width * clone_frame_%A_LoopField%_scale_x//100, clone_frame_%A_LoopField%_height * clone_frame_%A_LoopField%_scale_y//100, 0, 0, WidthClone_frames, HeightClone_frames, 0.2 + 0.16 * clone_frame_%A_LoopField%_opacity)
			Gdip_DisposeImage(bmpClone_frames)
		}
		UpdateLayeredWindow(hwnd_clone_frames_window, hdcClone_frames, xScreenOffSet, yScreenOffSet, poe_width, poe_height)
		SelectObject(hdcClone_frames, obmClone_frames)
		DeleteObject(hbmClone_frames)
		DeleteDC(hdcClone_frames)
		Gdip_DeleteGraphics(GClone_frames)
		*/
	}
	Else
	{
		Loop, Parse, clone_frames_enabled, `,, `,
		{
			If WinExist("ahk_id " hwnd_%A_Loopfield%)
				Gui, clone_frames_%A_Loopfield%: Hide
		}
	}
}
Return

Map_info:
If (A_Gui = "")
{
	map_mods_clipped := Clipboard
	map_mods_sample := 0
}
monsters := ""
player := ""
bosses := ""
area := ""
map_mods_panel_player := ""
map_mods_panel_monsters := ""
map_mods_panel_bosses := ""
map_mods_panel_area := ""
If (map_mods_clipped = "")
{
	IniRead, parseboard, data\Map mods.ini, sample map
	parseboard := SubStr(parseboard, InStr(parseboard, "Item Level:"))
	map_mods_sample := 1
}
Else parseboard := SubStr(map_mods_clipped, InStr(map_mods_clipped, "Item Level:"))
IniRead, map_mods_list, data\Map mods.ini
Loop, Parse, parseboard, `n, `n
{
	If (A_LoopField = "")
		continue
	check := A_LoopField
	check_characters := "-0123456789%"
	map_mod_pretext := ""
	Loop, Parse, check
	{
		If InStr(check_characters, A_LoopField)
			map_mod_pretext := (map_mod_pretext = "") ? A_LoopField : map_mod_pretext A_LoopField
	}
	While (SubStr(map_mod_pretext, 0) = "-")
		map_mod_pretext := SubStr(map_mod_pretext, 1, -1)
	Loop, Parse, map_mods_list, `n, `n
	{
		If (A_LoopField = "sample map") || (A_LoopField = "version")
			continue
		If InStr(check, A_LoopField)
		{
			loopfield_copy := A_LoopField
			IniRead, map_mod_type, data\Map mods.ini, %A_LoopField%, type
			IniRead, map_mod_modifier, data\Map mods.ini, %A_LoopField%, mod
			If (A_LoopField = "increased area") && InStr(check, "monster")
				map_mod_type := "monsters"
			Else If (A_LoopField = "increased area") && InStr(check, "boss")
			{
				map_mod_type := "bosses"
				loopfield_copy := "increased area of"
			}
			IniRead, map_mod_ID, data\Map mods.ini, %loopfield_copy%, ID
			IniRead, map_mod_text, data\Map mods.ini, %loopfield_copy%, text
			IniRead, map_mod_mod, data\Map mods.ini, %loopfield_copy%, mod
			
			If (map_mod_type = "player")
				map_mods_panel_player := (map_mods_panel_player = "") ? map_mod_text : map_mods_panel_player "`n" map_mod_text
			Else If (map_mod_type = "monsters")
				map_mods_panel_monsters := (map_mods_panel_monsters = "") ? map_mod_text : map_mods_panel_monsters "`n" map_mod_text
			Else If (map_mod_type = "bosses")
				map_mods_panel_bosses := (map_mods_panel_bosses = "") ? map_mod_text : map_mods_panel_bosses "`n" map_mod_text
			Else If (map_mod_type = "area")
				map_mods_panel_area := (map_mods_panel_area = "") ? map_mod_text : map_mods_panel_area "`n" map_mod_text
			
			map_mod_pretext := (map_mod_mod = "?") ? "" : map_mod_pretext
			map_mod_text := (map_mod_pretext != "") ? map_mod_pretext "," map_mod_ID map_mod_text : "," map_mod_ID map_mod_text
			If (map_mod_modifier = "+")
				map_mod_text := "+" map_mod_text
			If (map_mod_modifier = "-")
				map_mod_text := "-" map_mod_text
			IniRead, map_mod_rank, ini\map info.ini, %map_mod_ID%, rank
			If (map_mod_type = "player") && (map_mod_rank > 0)
				player := (player = "") ? map_mod_text : player "`n" map_mod_text
			Else If (map_mod_type = "monsters") && (map_mod_rank > 0)
				monsters := (monsters = "") ? map_mod_text : monsters "`n" map_mod_text
			Else If (map_mod_type = "bosses") && (map_mod_rank > 0)
				bosses := (bosses = "") ? map_mod_text : bosses "`n" map_mod_text
			Else If (map_mod_type = "area") && (map_mod_rank > 0)
				area := (area = "") ? map_mod_text : area "`n" map_mod_text
			break
		}
	}
}

map_mods_panel_text := map_mods_panel_player "`n" map_mods_panel_monsters "`n" map_mods_panel_bosses "`n" map_mods_panel_area
width := ""
Loop 2
{
	Gui, map_mods_window: New, -DPIScale -Caption +E0x20 +LastFound +AlwaysOnTop +ToolWindow +Border HWNDhwnd_map_mods_window
	If (A_Index = 1)
		Gui, map_mods_window: Margin, 0, 0
	Else Gui, map_mods_window: Margin, 8, 2
	Gui, map_mods_window: Color, Black
	WinSet, Transparent, %map_info_trans%
	style_map_mods := (width = "") ? "" : " w"width
	Gui, map_mods_window: Font, % "s"fSize0 + fSize_offset_map_info " cWhite underline", Fontin SmallCaps
	If (player != "")
	{
		Gui, map_mods_window: Add, Text, BackgroundTrans %map_info_side% %style_map_mods%, player:
		Gui, map_mods_window: Font, norm
		Loop, Parse, player, `n, `n
		{
			window_ID := SubStr(A_LoopField, InStr(A_LoopField, ",") + 1, 3)
			IniRead, window_rank, ini\map info.ini, %window_ID%, rank, 1
			window_color := "white"
			window_color := (window_rank > 1) ? "yellow" : window_color
			window_color := (window_rank > 2) ? "red" : window_color
			window_color := (window_rank > 3) ? "fuchsia" : window_color
			window_text := StrReplace(A_LoopField, "," window_ID, " ")
			window_text := StrReplace(window_text, "?", "`n")
			Gui, map_mods_window: Add, Text, BackgroundTrans c%window_color% %map_info_side% %style_map_mods% y+0, %window_text%
		}
		Gui, map_mods_window: Font, underline
	}
	If (monsters != "")
	{
		Gui, map_mods_window: Add, Text, BackgroundTrans %map_info_side% %style_map_mods%, monsters:
		Gui, map_mods_window: Font, norm
		Loop, Parse, monsters, `n, `n
		{
			window_ID := SubStr(A_LoopField, InStr(A_LoopField, ",") + 1, 3)
			IniRead, window_rank, ini\map info.ini, %window_ID%, rank, 1
			window_color := "white"
			window_color := (window_rank > 1) ? "yellow" : window_color
			window_color := (window_rank > 2) ? "red" : window_color
			window_color := (window_rank > 3) ? "fuchsia" : window_color
			window_text := (SubStr(A_Loopfield, 1, 1) = ",") ? StrReplace(A_LoopField, "," window_ID) : StrReplace(A_LoopField, "," window_ID, " ")
			window_text := StrReplace(window_text, "?", "`n")
			window_text := StrReplace(window_text, "$")
			Gui, map_mods_window: Add, Text, BackgroundTrans c%window_color% %map_info_side% %style_map_mods% y+0, %window_text%
		}
		Gui, map_mods_window: Font, underline
	}
	If (bosses != "")
	{
		Gui, map_mods_window: Add, Text, BackgroundTrans %map_info_side% %style_map_mods%, boss:
		Gui, map_mods_window: Font, norm
		Loop, Parse, bosses, `n, `n
		{
			window_ID := SubStr(A_LoopField, InStr(A_LoopField, ",") + 1, 3)
			IniRead, window_rank, ini\map info.ini, %window_ID%, rank, 1
			window_color := "white"
			window_color := (window_rank > 1) ? "yellow" : window_color
			window_color := (window_rank > 2) ? "red" : window_color
			window_color := (window_rank > 3) ? "fuchsia" : window_color
			window_text := (SubStr(A_Loopfield, 1, 1) = ",") ? StrReplace(A_LoopField, "," window_ID) : StrReplace(A_LoopField, "," window_ID, " ")
			window_text := StrReplace(window_text, "a0e", "aoe")
			Gui, map_mods_window: Add, Text, BackgroundTrans c%window_color% %map_info_side% %style_map_mods% y+0, %window_text%
		}
		Gui, map_mods_window: Font, underline
	}
	If (area != "")
	{
		Gui, map_mods_window: Add, Text, BackgroundTrans %map_info_side% %style_map_mods%, area:
		Gui, map_mods_window: Font, norm
		Loop, Parse, area, `n, `n
		{
			window_ID := SubStr(A_LoopField, InStr(A_LoopField, ",") + 1, 3)
			IniRead, window_rank, ini\map info.ini, %window_ID%, rank, 1
			window_color := "white"
			window_color := (window_rank > 1) ? "yellow" : window_color
			window_color := (window_rank > 2) ? "red" : window_color
			window_color := (window_rank > 3) ? "fuchsia" : window_color
			window_text := (SubStr(A_Loopfield, 1, 1) = ",") ? StrReplace(A_LoopField, "," window_ID) : StrReplace(A_LoopField, "," window_ID, " ")
			Gui, map_mods_window: Add, Text, BackgroundTrans c%window_color% %map_info_side% %style_map_mods% y+0, %window_text%
		}
		Gui, map_mods_window: Font, underline
	}
	If (A_Index = 1)
	{
		Gui, map_mods_window: Show, Hide
		WinGetPos,,, width
	}
	Else
	{
		Gui, map_mods_toggle: New, -DPIScale -Caption +LastFound +AlwaysOnTop +ToolWindow +Border HWNDhwnd_map_mods_toggle
		Gui, map_mods_toggle: Margin, 4, 2
		Gui, map_mods_toggle: Color, Black
		WinSet, Transparent, %trans%
		pic_style := ""
		pic_style := (poe_height = "2160") ? "h26 w-1" : pic_style
		pic_style := (poe_height = "1800") ? "h23 w-1" : pic_style
		pic_style := (poe_height = "1600") ? "h20 w-1" : pic_style
		pic_style := (poe_height = "1200") ? "h15 w-1" : pic_style
		pic_style := (poe_height = "1080") ? "h12 w-1" : pic_style
		pic_style := (poe_height = "900") ? "h9 w-1" : pic_style
		pic_style := (poe_height = "720") ? "h6 w-1" : pic_style
		Gui, map_mods_toggle: Add, Picture, vMap_mods_toggle_pic BackgroundTrans gMap_mods_toggle %pic_style%, img\GUI\map_mod_button_hide.png
		If (map_info_side = "right")
			Gui, map_mods_toggle: Show, % "Hide x"xScreenOffSet + poe_width - map_toggle_x " y"yScreenOffSet + map_toggle_y
		Else Gui, map_mods_toggle: Show, % "Hide x"xScreenOffSet " y"yScreenOffSet + map_toggle_y
		LLK_Overlay("map_mods_toggle", "show")
		If (map_info_side = "left")
			WinGetPos,, yToggle,, hToggle, ahk_id %hwnd_map_mods_toggle%
		Gui, map_mods_window: Show, NA
		WinGetPos,,, width,, ahk_id %hwnd_map_mods_window%
		If (map_info_side = "right")
			Gui, map_mods_window: Show, % "Hide x"xScreenOffSet + poe_width - width " y"yScreenOffSet + map_info_y
		Else Gui, map_mods_window: Show, % "Hide x"xScreenOffSet " y"yToggle + hToggle*1.1
		LLK_Overlay("map_mods_window", "show")
		toggle_map_mods_panel := 1
		map_mods_panel_fresh := 1
	}
	If ((player != "") || (monsters != "") || (bosses != "") || (area != "")) && (A_Gui = "")
		LLK_ToolTip("success", 0.5)
	Else If (player = "") && (monsters = "") && (bosses = "") && (area = "") && (map_info_search = "")
	{
		LLK_ToolTip("failed:`nno mods", 0.5)
		Gui, map_mods_window: Destroy
		Gui, map_mods_toggle: Destroy
		hwnd_map_mods_toggle := ""
		hwnd_map_mods_window := ""
		map_mods_panel_fresh := 0
	}
}
Return

Map_info_customization:
GuiControl_copy := A_GuiControl
Gui, map_info_menu: destroy
Gui, map_info_menu: New, -DPIScale +LastFound +AlwaysOnTop +ToolWindow +Border HWNDhwnd_map_info_menu, Lailloken UI: map mod customization
Gui, map_info_menu: Color, Black
Gui, map_info_menu: Margin, 12, 4
WinSet, Transparent, %trans%
Gui, map_info_menu: Font, s%fSize0% cWhite, Fontin SmallCaps

If (GuiControl_copy = "Map_info_search")
{
	map_info_hits := ""
	Gui, settings_menu: Submit, NoHide
	If (StrLen(map_info_search) < 3)
		Return
	IniRead, map_mods_search_db, data\Map search.ini
	Loop, Parse, map_mods_search_db, `n, `n
	{
		If InStr(A_LoopField, map_info_search)
		{
			IniRead, map_info_ID, data\Map search.ini, %A_LoopField%, ID
			map_info_hits := (map_info_hits = "") ? map_info_ID : map_info_hits "," map_info_ID
		}
	}
	Loop, Parse, map_info_hits, `,, `,
	{
		IniRead, map_mod_%A_LoopField%_rank, ini\map info.ini, %A_LoopField%, rank, 1
		IniRead, map_mod_%A_LoopField%_type, ini\map info.ini, %A_LoopField%, type
		IniRead, map_mod_%A_LoopField%_text, ini\map info.ini, %A_LoopField%, text
		If (A_Index = 1)
		{
			Gui, map_info_menu: Add, Text, Section BackgroundTrans, set mod difficulty (0-4):
			Gui, map_info_menu: Add, Picture, ys BackgroundTrans vMap_info gSettings_menu_help hp w-1, img\GUI\help.png
		}
		Gui, map_info_menu: Font, % "s"fSize0 - 4
		Gui, map_info_menu: Add, Edit, xs hp Section BackgroundTrans center vMap_mod_edit_%A_LoopField% gMap_mods_save number limit1 cBlack, % map_mod_%A_LoopField%_rank
		Gui, map_info_menu: Font, % "s"fSize0
		map_info_cfg_text := StrReplace(map_mod_%A_LoopField%_text, "?", " ")
		map_info_cfg_text := StrReplace(map_info_cfg_text, "a0e", "aoe")
		map_info_cfg_text := StrReplace(map_info_cfg_text, "$")
		Gui, map_info_menu: Add, Text, ys BackgroundTrans, % map_info_cfg_text " (" map_mod_%A_LoopField%_type ")"
	}

	If (map_info_hits != "")
	{
		WinGetPos, winXpos, winYpos, winwidth, winheight, ahk_id %hwnd_settings_menu%
		show_search_x := winXpos + winwidth//2
		show_search_y := winYpos + winheight
		Gui, map_info_menu: Show, NA x%show_search_x% y%show_search_y%
	}
	Return
}

IniRead, map_info_parse, data\Map mods.ini
map_info_parse := StrReplace(map_info_parse, "-")
loop := ""
IDs_hit := ""
Loop, Parse, map_mods_panel_text, `n, `n
{
	If (A_LoopField = "")
		continue
	loop += 1
	check := A_LoopField
	Loop, Parse, map_info_parse, `n, `n
	{
		IniRead, map_info_text, data\Map mods.ini, %A_LoopField%, text
		If (map_info_text = check)
		{
			IniRead, map_info_ID, data\Map mods.ini, %A_LoopField%, ID
			break
		}
	}
	IniRead, map_mod_%map_info_ID%_rank, ini\map info.ini, %map_info_ID%, rank, 1
	IniRead, map_mod_%map_info_ID%_type, ini\map info.ini, %map_info_ID%, type
	If (loop = 1)
	{
		Gui, map_info_menu: Add, Text, Section BackgroundTrans, set mod difficulty (0-4):
		Gui, map_info_menu: Add, Picture, ys BackgroundTrans vMap_info gSettings_menu_help hp w-1, img\GUI\help.png
	}
	Gui, map_info_menu: Font, % "s"fSize0 - 4
	Gui, map_info_menu: Add, Edit, xs hp Section BackgroundTrans center vMap_mod_edit_%map_info_ID% gMap_mods_save number limit1 cBlack, % map_mod_%map_info_ID%_rank
	Gui, map_info_menu: Font, % "s"fSize0
	map_info_cfg_text := StrReplace(A_LoopField, "?", " ")
	map_info_cfg_text := StrReplace(map_info_cfg_text, "a0e", "aoe")
	map_info_cfg_text := StrReplace(map_info_cfg_text, "$")
	Gui, map_info_menu: Add, Text, ys BackgroundTrans, % map_info_cfg_text
}
Gui, map_info_menu: Show, NA
WinGetPos,,, widthedit
WinGetPos, winx, winy, winw,, ahk_id %hwnd_map_mods_window%
If (map_info_side = "right")
	Gui, map_info_menu: Show, % "x"winx - widthedit " y"winy
Else Gui, map_info_menu: Show, % "x"winx + winw " y"winy
Return

Map_info_menuGuiClose:
Gui, map_info_menu: Destroy
WinActivate, ahk_group poe_window
Return

Map_info_settings_apply:
Gui, settings_menu: Submit, NoHide
If (A_GuiControl = "map_info_side")
{
	IniWrite, % map_info_side, ini\map info.ini, Settings, side
	GoSub, Map_info
	Return
}
If (A_GuiControl = "Map_info_pixelcheck_enable")
{
	If (pixel_gamescreen_color1 = "") || (pixel_gamescreen_color1 = "ERROR")
	{
		LLK_ToolTip("pixel-check setup required")
		map_info_pixelcheck_enable := 0
		GuiControl, settings_menu: , Map_info_pixelcheck_enable, 0
		Return
	}
	IniWrite, %map_info_pixelcheck_enable%, ini\map info.ini, Settings, enable pixel-check
	GoSub, Screenchecks_gamescreen
	Return
}
If (A_GuiControl = "fSize_map_info_minus")
{
	fSize_offset_map_info -= 1
	IniWrite, %fSize_offset_map_info%, ini\map info.ini, Settings, font-offset
}
If (A_GuiControl = "fSize_map_info_plus")
{
	fSize_offset_map_info += 1
	IniWrite, %fSize_offset_map_info%, ini\map info.ini, Settings, font-offset
}
If (A_GuiControl = "fSize_map_info_reset")
{
	fSize_offset_map_info := 0
	IniWrite, %fSize_offset_map_info%, ini\map info.ini, Settings, font-offset
}
If (A_GuiControl = "map_info_opac_minus")
{
	map_info_trans -= (map_info_trans > 100) ? 30 : 0
	IniWrite, %map_info_trans%, ini\map info.ini, Settings, transparency
}
If (A_GuiControl = "map_info_opac_plus")
{
	map_info_trans += (map_info_trans < 250) ? 30 : 0
	IniWrite, %map_info_trans%, ini\map info.ini, Settings, transparency
}
GoSub, Map_info
Return

Map_mods_save:
Gui, map_info_menu: Submit, NoHide
SendInput, ^{a}
map_mod_ID := StrReplace(A_GuiControl, "map_mod_edit_")
map_mod_difficulty := %A_GuiControl%
map_mod_difficulty := (map_mod_difficulty = "") ? 0 : map_mod_difficulty
map_mod_difficulty := (map_mod_difficulty > 4) ? 4 : map_mod_difficulty
IniWrite, %map_mod_difficulty%, ini\map info.ini, %map_mod_ID%, rank
GoSub, Map_info
Return

Map_mods_toggle:
If (click = 2)
{
	GoSub, Map_info_customization
	Return
}
If WinExist("ahk_id " hwnd_map_mods_window)
{
	LLK_Overlay("map_mods_window", "hide")
	toggle_map_mods_panel := 0
	GuiControl, map_mods_toggle: , map_mods_toggle_pic, img\GUI\map_mod_button_show.png
}
Else
{
	LLK_Overlay("map_mods_window", "Show")
	toggle_map_mods_panel := 1
	GuiControl, map_mods_toggle: , map_mods_toggle_pic, img\GUI\map_mod_button_hide.png
}
WinActivate, ahk_group poe_window
Return

Notepad:
notepad_fontcolor := (notepad_fontcolor = "") ? "White" : notepad_fontcolor
fSize_notepad := fSize0 + fSize_offset_notepad
If (A_Gui = "settings_menu")
{
	Gui, notepad: Submit, NoHide
	Gui, notepad: Destroy
	hwnd_notepad := ""
	Gui, notepad_sample: New, -DPIScale +LastFound +AlwaysOnTop +ToolWindow +Border HWNDhwnd_notepad_sample, Lailloken UI: overlay-text preview
	Gui, notepad_sample: Margin, 12, 4
	Gui, notepad_sample: Color, Black
	WinSet, Transparent, %notepad_trans%
	Gui, notepad_sample: Font, c%notepad_fontcolor% s%fSize_notepad%, Fontin SmallCaps
	Gui, notepad_sample: Add, Text, BackgroundTrans, this is what the`nnotepad-overlay looks`nlike with the current`nsettings
	If (notepad_sample_xpos != "") && (notepad_sample_ypos != "")
		Gui, notepad_sample: Show, Hide x%notepad_sample_xpos% y%notepad_sample_ypos% AutoSize
	Else
	{
		Gui, notepad_sample: Show, % "Hide AutoSize"
		WinGetPos,,, win_width, win_height
		Gui, notepad_sample: Show, % "Hide AutoSize x"xScreenOffSet + poe_width//2 - win_width//2 " y"yScreenOffSet
	}
	LLK_Overlay("notepad_sample", "show")
	Return
}
If (click = 2) || (hwnd_notepad = "")
{
	If !WinExist("ahk_id " hwnd_notepad) && (click = 2)
	{
		WinActivate, ahk_group poe_window
		Return
	}
	If WinExist("ahk_id " hwnd_notepad)
		Gui, notepad: Submit, NoHide
	If (notepad_text != "") || (hwnd_notepad = "")
	{
		If (notepad_edit = 1) || (hwnd_notepad = "")
		{
			Gui, notepad: New, -DPIScale +Resize +LastFound +AlwaysOnTop +ToolWindow HWNDhwnd_notepad, Lailloken-UI: notepad
			Gui, notepad: Margin, 12, 4
			Gui, notepad: Color, Black
			WinSet, Transparent, 220
			Gui, notepad: Font, cBlack s%fSize_notepad%, Fontin SmallCaps
			Gui, notepad: Add, Edit, x0 y0 w1000 h1000 vnotepad_text Lowercase, %notepad_text%
			Gui, notepad: Show, x%notepad_xpos% y%notepad_ypos% w%notepad_width% h%notepad_height%
			SendInput, {Right}
			notepad_edit := 0
		}
		Else
		{
			WinGetPos, notepad_xpos, notepad_ypos,,, ahk_id %hwnd_notepad%
			Gui, notepad: New, -DPIScale +E0x20 +LastFound +AlwaysOnTop +ToolWindow -Caption +Border HWNDhwnd_notepad
			Gui, notepad: Margin, 12, 4
			Gui, notepad: Color, Black
			WinSet, Transparent, %notepad_trans%
			Gui, notepad: Font, c%notepad_fontcolor% s%fSize_notepad%, Fontin SmallCaps
			Gui, notepad: Add, Text, BackgroundTrans, %notepad_text%
			Gui, notepad: Show, NA x%notepad_xpos% y%notepad_ypos% AutoSize
			notepad_edit := 1
			WinActivate, ahk_group poe_window
		}
	}
	Return
}

If WinExist("ahk_id " hwnd_notepad)
{
	If (notepad_edit != 1)
		WinGetPos, notepad_xpos, notepad_ypos, notepad_width, notepad_height, ahk_id %hwnd_notepad%
	Gui, notepad: Submit, NoHide
	If notepad_edit = 0
	{
		Gui, notepad: Destroy
		hwnd_notepad := ""
	}
	Else LLK_Overlay("notepad", "hide")
	WinActivate, ahk_group poe_window
}
Else LLK_Overlay("notepad", "show", 1)
Return

NotepadGuiClose:
If WinExist("ahk_id " hwnd_notepad)
{
	If (notepad_edit != 1)
		WinGetPos, notepad_xpos, notepad_ypos, notepad_width, notepad_height, ahk_id %hwnd_notepad%
	Gui, notepad: Submit, NoHide
	LLK_Overlay("notepad", "hide")
}
Return

Omnikey:
clipboard := ""
SendInput ^{c}
ClipWait, 0.1
ThisHotkey_copy := StrReplace(A_ThisHotkey, "~")
ThisHotkey_copy := StrReplace(ThisHotkey_copy, "*")
If (clipboard != "")
{
	start := A_TickCount
	If InStr(clipboard, "Attacks per Second:")
	{
		While GetKeyState(ThisHotkey_copy, "P")
		{
			If (A_TickCount >= start + 200)
			{
				GoSub, Omnikey_dps
				KeyWait, %ThisHotkey_copy%
				Return
			}
		}
	}
	If !InStr(clipboard, "Rarity: Currency") && !InStr(clipboard, "Item Class: Map") && !InStr(clipboard, "Unidentified") && !InStr(clipboard, "Heist") && !InStr(clipboard, "Item Class: Expedition") && !InStr(clipboard, "Item Class: Stackable Currency") || InStr(clipboard, "to the goddess") || InStr(clipboard, "other oils")
	{
		GoSub, Omnikey_context_menu
		Return
	}
	If InStr(clipboard, "Orb of Horizons")
	{
		While GetKeyState(ThisHotkey_copy, "P")
		{
			If (A_TickCount >= start + 200)
			{
				horizon_toggle := 1
				LLK_Omnikey_ToolTip(maps_a)
				KeyWait, %ThisHotkey_copy%
				horizon_toggle := 0
				LLK_Omnikey_ToolTip()
				Return
			}
		}
	}
	If InStr(clipboard, "Item Class: Map") && !InStr(clipboard, "Fragment")
	{
		
		start := A_TickCount
		While GetKeyState(ThisHotkey_copy, "P")
		{
			If (A_TickCount >= start + 200)
			{
				Loop, Parse, Clipboard, `r`n, `r`n
				{
					If InStr(A_Loopfield, "Map Tier: ")
					{
						parse_tier := StrReplace(A_Loopfield, "Map Tier: ")
						Break
					}
				}
				If InStr(clipboard, "maze of the minotaur") || InStr(clipboard, "forge of the phoenix") || InStr(clipboard, "lair of the hydra") || InStr(clipboard, "pit of the chimera")
					LLK_Omnikey_ToolTip("horizons:maze of the minotaur`nforge of the phoenix`nlair of the hydra`npit of the chimera" )
				Else LLK_Omnikey_ToolTip("horizons:" maps_tier%parse_tier%)
				KeyWait, %ThisHotkey_copy%
				LLK_Omnikey_ToolTip()
				Return
			}
		}
		If InStr(clipboard, "Unidentified") || InStr(clipboard, "Rarity: Normal") || InStr(clipboard, "Rarity: Unique")
		{
			LLK_ToolTip("not supported:`nnormal, unique, un-ID")
			Return
		}
		If (pixel_gamescreen_color1 = "ERROR") || (pixel_gamescreen_color1 = "")
		{
			LLK_ToolTip("pixel-check setup required")
			Return
		}
		GoSub, Map_info
		Return
	}
}
Else
{
	If LLK_ImageSearch("betrayal")
		GoSub, Betrayal_search
	If LLK_ImageSearch("gwennen")
		GoSub, Gwennen_search
}
Return

Omnikey_context_menu:
Gui, context_menu: New, -Caption +LastFound +AlwaysOnTop +ToolWindow +Border HWNDhwnd_context_menu
Gui, context_menu: Margin, 4, 2
Gui, context_menu: Color, Black
WinSet, Transparent, %trans%
Gui, context_menu: Font, s%fSize0% cWhite, Fontin SmallCaps
If InStr(clipboard, "Rarity: Unique") || InStr(clipboard, "Rarity: Gem") || InStr(clipboard, "Class: Quest") || InStr(clipboard, "Rarity: Divination Card")
	Gui, context_menu: Add, Text, vwiki_exact gOmnikey_menu_selection BackgroundTrans Center, wiki (exact item)
Else If InStr(clipboard, "to the goddess")
{
	Gui, context_menu: Add, Text, vwiki_exact gOmnikey_menu_selection BackgroundTrans Center, wiki (exact item)
	Gui, context_menu: Add, Text, vlab_layout gOmnikey_menu_selection BackgroundTrans Center, lab info
}
Else If InStr(clipboard, "other oils")
{
	Gui, context_menu: Add, Text, vOil_wiki gOmnikey_menu_selection BackgroundTrans Center, wiki (item class)
	Gui, context_menu: Add, Text, vOil_table gOmnikey_menu_selection BackgroundTrans Center, anoint table
}
Else
{
	Gui, context_menu: Add, Text, vcrafting_table gOmnikey_menu_selection BackgroundTrans Center, crafting table
	Gui, context_menu: Add, Text, vwiki_class gOmnikey_menu_selection BackgroundTrans Center, wiki (item class)
}
If InStr(clipboard, "Sockets: ") && !InStr(clipboard, "Class: Ring") && !InStr(clipboard, "Class: Amulet") && !InStr(clipboard, "Class: Belt")
	Gui, context_menu: Add, Text, vchrome_calc gOmnikey_menu_selection BackgroundTrans Center, chromatics
MouseGetPos, mouseX, mouseY
Gui, context_menu: Show, % "Hide x"mouseX " y"mouseY
WinGetPos, x_context,, w_context
If (x_context < xScreenOffset)
	Gui, context_menu: Show, x%xScreenOffset% y%mouseY%
Else Gui, context_menu: Show, % "x"mouseX - w_context " y"mouseY
WinWaitActive, ahk_group poe_window,,, Lailloken
If WinExist("ahk_id " hwnd_context_menu)
	Gui, context_menu: destroy
Return

Omnikey_craft_chrome:
attribute0 := ""
attribute := ""
strength := ""
dexterity := ""
intelligence := ""
wiki_level := ""
Loop, Parse, clipboard, `r`n, `r`n
{
	If (A_Index=1)
	{
		wiki_term := StrReplace(A_LoopField, "Item Class: ")
		class := wiki_term
		wiki_term := StrReplace(wiki_term, A_Space, "_")
	}
	If InStr(A_LoopField, "Str: ")
	{
		strength := StrReplace(A_LoopField, "Str: ")
		strength := StrReplace(strength, " (augmented)")
		strength := StrReplace(strength, " (unmet)")
	}
	Else strength := (strength="") ? 0 : strength
	If InStr(A_LoopField, "Dex: ")
	{
		dexterity := StrReplace(A_LoopField, "Dex: ")
		dexterity := StrReplace(dexterity, " (augmented)")
		dexterity := StrReplace(dexterity, " (unmet)")
	}
	Else dexterity := (dexterity="") ? 0 : dexterity
	If InStr(A_LoopField, "Int: ")
	{
		intelligence := StrReplace(A_LoopField, "Int: ")
		intelligence := StrReplace(intelligence, " (augmented)")
		intelligence := StrReplace(intelligence, " (unmet)")
	}
	Else	intelligence := (intelligence="") ? 0 : intelligence
	If InStr(A_LoopField, "Item Level: ")
	{
		wiki_level := SubStr(A_LoopField, InStr(A_LoopField, ":")+1)
		wiki_level := StrReplace(wiki_level, " ")
	}
	If InStr(A_LoopField, "Added Small Passive Skills grant: ")
		wiki_cluster := SubStr(A_LoopField, 35)
}
If (class="Gloves") || (class="Boots") || (class="Body Armours") || (class="Helmets") || (class="Shields")
{
	attribute0 := Max(strength, dexterity, intelligence)
	If (attribute0=strength)
		attribute := "_str"
	If (attribute0=dexterity)
		attribute := (attribute="") ? "_dex" : attribute "_dex"
	If (attribute0=intelligence)
		attribute := (attribute="") ? "_int" : attribute "_int"
}
If (A_GuiControl = "crafting_table")
{
	If InStr(clipboard, "Cluster Jewel")
	{
		Run, https://poedb.tw/us/Cluster_Jewel#EnchantmentModifiers
		wiki_cluster := SubStr(wiki_cluster, 1, InStr(wiki_cluster, "(")-2)
		ToolTip, Press F3 to search for modifiers, % xScreenOffset + poe_width//2 - 100, yScreenOffset + poe_height//2, 15
		KeyWait, F3, D
		KeyWait, F3
		ToolTip,,,, 15
		SendInput, %wiki_cluster%
	}
	Else Run, https://poedb.tw/us/%wiki_term%%attribute%#ModifiersCalc
	clipboard := wiki_level
}
If (A_GuiControl = "chrome_calc")
{
	ToolTip, Press CTRL-V to paste stat requirements, % xScreenOffset + poe_width//2 - 100, yScreenOffset + poe_height//2, 15
	Run, https://siveran.github.io/calc.html
	clipboard := ""
	KeyWait, v, D
	SendInput, %strength%{tab}%dexterity%{tab}%intelligence%
	ToolTip,,,, 15
}
Return

Omnikey_dps:
phys_dmg := 0
ele_dmg := 0
ele_dmg3 := 0
ele_dmg4 := 0
ele_dmg5 := 0
edps0 := 0
chaos_dmg := 0
cdps := 0
speed := 0
Loop, Parse, clipboard, `r`n, `r`n
{
	If InStr(A_LoopField,"Physical Damage: ")
	{
		phys_dmg := A_LoopField
		Loop, Parse, phys_dmg, " "
			If (A_Index=3)
				phys_dmg := A_LoopField
	}
	If InStr(A_LoopField,"Elemental Damage: ")
	{
		ele_dmg := StrReplace(A_LoopField, "`r`n")
		ele_dmg := StrReplace(ele_dmg, " (augmented)")
		ele_dmg := StrReplace(ele_dmg, ",")
		Loop, Parse, ele_dmg, " "
			If A_Index between 3 and 5
				ele_dmg%A_Index% := A_LoopField
	}
	If InStr(A_LoopField, "Chaos Damage: ")
	{
		chaos_dmg := StrReplace(A_LoopField, "`r`n")
		chaos_dmg := StrReplace(chaos_dmg, " (augmented)")
		Loop, Parse, chaos_dmg, " "
			If (A_Index=3)
				chaos_dmg := A_LoopField
	}
	If InStr(A_LoopField, "Attacks per Second: ")
	{
		speed := A_LoopField
		Loop, Parse, speed, " "
			If (A_Index=4)
				speed := SubStr(A_LoopField,1,4)
		break
	}
}
If (phys_dmg!=0)
{
	Loop, Parse, phys_dmg, "-"
		phys%A_Index% := A_LoopField
	pdps := ((phys1+phys2)/2)*speed
	pdps := Format("{:0.2f}", pdps)
}
If (ele_dmg!=0)
{
	edps2 := 0
	edps3 := 0
	Loop, Parse, ele_dmg3, "-"
		ele_dmg3_%A_Index% := A_LoopField
	edps1 := ((ele_dmg3_1+ele_dmg3_2)/2)*speed
	If (ele_dmg4!=0)
	{
		Loop, Parse, ele_dmg4, "-"
			ele_dmg4_%A_Index% := A_LoopField
		edps2 := ((ele_dmg4_1+ele_dmg4_2)/2)*speed
	}
	If (ele_dmg5!=0)
	{
		Loop, Parse, ele_dmg5, "-"
			ele_dmg5_%A_Index% := A_LoopField
		edps3 := ((ele_dmg5_1+ele_dmg5_2)/2)*speed
	}
	edps0 := edps1+edps2+edps3
	edps0 := Format("{:0.2f}", edps0)
}
If (chaos_dmg!=0)
{
	Loop, Parse, chaos_dmg, "-"
		chaos_dmg%A_Index% := A_LoopField
	cdps := ((chaos_dmg1+chaos_dmg2)/2)*speed
	cdps := Format("{:0.2f}", cdps)
}
tdps := pdps+edps0+cdps
tdps := Format("{:0.2f}", tdps)
MouseGetPos, mousex, mousey
ToolTip, % "pDPS: " pdps "`neDPS: " edps0 "`ncDPS: " cdps "`n-----------`ntDPS: " tdps, % mousex-80, mouseY-20, 1
KeyWait, %ThisHotkey_copy%
ToolTip,,,,1
Return

Omnikey_menu_selection:
If (A_GuiControl = "chrome_calc") || (A_GuiControl = "crafting_table")
	GoSub, Omnikey_craft_chrome
Else If (A_GuiControl = "oil_wiki")
	Run, https://www.poewiki.net/wiki/Oil
Else If (A_GuiControl = "oil_table")
	Run, https://blight.raelys.com/
Else If InStr(A_GuiControl, "wiki")
	GoSub, Omnikey_wiki
Else If InStr(A_GuiControl, "layout")
	GoSub, Lab_info
Gui, context_menu: destroy
Return

Omnikey_wiki:
If (A_GuiControl = "wiki_exact")
	wiki_index := 3
If (A_GuiControl = "wiki_class")
	wiki_index := 1
Loop, Parse, clipboard, `n, `n 
{
	If (A_Index=wiki_index)
	{
		wiki_term := StrReplace(A_LoopField, "Item Class: ")
		wiki_term := (InStr(wiki_term, "Body")) ? "Body armour" : wiki_term
		wiki_term := StrReplace(wiki_term, A_Space, "_")
		wiki_term := StrReplace(wiki_term, "'", "%27")
		break
	}
}
If InStr(clipboard, "Cluster Jewel")
	wiki_term := "Cluster_Jewel"
Run, https://poewiki.net/wiki/%wiki_term%
Return

Screenchecks:
If (click = 2)
{
	If InStr(A_GuiControl, "_pixel")
		LLK_PixelRecalibrate(StrReplace(A_GuiControl, "_pixel"))
	Else
	{
		Clipboard := ""
		SendInput, #+{s}
		Sleep, 1000
		WinWaitActive, ahk_group poe_window
		If (Gdip_CreateBitmapFromClipboard() < 0)
		{
			LLK_ToolTip("screen-cap not successful")
		}
		Else Gdip_SaveBitmapToFile(Gdip_CreateBitmapFromClipboard(), "img\Recognition (" poe_height "p)\GUI\" StrReplace(A_GuiControl, "_image") ".bmp", 100)
	}
	GoSub, Settings_menu
	Return
}
Else
{
	If InStr(A_GuiControl, "_pixel")
	{
		If LLK_PixelSearch(StrReplace(A_GuiControl, "_pixel"))
			LLK_ToolTip("check positive")
		Else LLK_ToolTip("check negative")
	}
	Else
	{
		If (LLK_ImageSearch(StrReplace(A_GuiControl, "_image")) > 0)
			LLK_ToolTip("check positive")
		Else LLK_ToolTip("check negative")
	}
}
Return

Screenchecks_gamescreen:
total_pixelcheck_enable := clone_frames_pixelcheck_enable + map_info_pixelcheck_enable
If (total_pixelcheck_enable = 0)
	pixelchecks_enabled := StrReplace(pixelchecks_enabled, "gamescreen,")
Else pixelchecks_enabled := InStr(pixelchecks_enabled, "gamescreen") ? pixelchecks_enabled : pixelchecks_enabled "gamescreen,"
Return

Screenchecks_settings_apply:
Gui, settings_menu: Submit, NoHide
If (A_GuiControl = "image_folder")
{
	Run, explore img\Recognition (%poe_height%p)\GUI\
	Return
}
If (A_GuiControl = "enable_pixelchecks")
	IniWrite, %enable_pixelchecks%, ini\config.ini, Settings, background pixel-checks
If (enable_pixelchecks = 0)
{
	gamescreen := 0
	clone_frames_pixelcheck_enable := 0
	IniWrite, 0, ini\clone frames.ini, Settings, enable pixel-check
	map_info_pixelcheck_enable := 0
	IniWrite, 0, ini\map info.ini, Settings, enable pixel-check
}
Else
{
	clone_frames_pixelcheck_enable := 1
	IniWrite, 1, ini\clone frames.ini, Settings, enable pixel-check
	map_info_pixelcheck_enable := 1
	IniWrite, 1, ini\map info.ini, Settings, enable pixel-check
}
Return

Settings_menu:
SetTimer, Settings_menu, Delete
If WinExist("ahk_id " hwnd_settings_menu)
	WinGetPos, xsettings_menu, ysettings_menu,,, ahk_id %hwnd_settings_menu%
If WinExist("ahk_id " hwnd_settings_menu) && (A_Gui = "LLK_panel")
{
	GoSub, Settings_menuGuiClose
	WinActivate, ahk_group poe_window
	Return
}
settings_style := InStr(A_GuiControl, "general") || (A_Gui = "LLK_panel") || (A_Gui = "") ? "border" : ""
alarm_style := InStr(A_GuiControl, "alarm") ? "border" : ""
betrayal_style := (InStr(A_GuiControl, "betrayal") && !InStr(A_GuiControl, "image")) ? "border" : ""
clone_frames_style := InStr(A_GuiControl, "clone") || (new_clone_menu_closed = 1) ? "border" : ""
flask_style := InStr(A_GuiControl, "flask") ? "border" : ""
map_mods_style := InStr(A_GuiControl, "map") ? "border" : ""
notepad_style := InStr(A_GuiControl, "notepad") ? "border" : ""
omnikey_style := InStr(A_GuiControl, "omni-key") ? "border" : ""
pixelcheck_style := (InStr(A_GuiControl, "check") || InStr(A_GuiControl, "image") || InStr(A_GuiControl, "pixel")) ? "border" : ""
geforce_style := InStr(A_GuiControl, "geforce") ? "border" : ""
GuiControl_copy := A_GuiControl
If (A_Gui = "settings_menu")
{
	Gui, settings_menu: Submit
	kill_timeout := (kill_timeout = "") ? 0 : kill_timeout
}
Gui, settings_menu: New, -DPIScale +LastFound +AlwaysOnTop +ToolWindow +Border HWNDhwnd_settings_menu, Lailloken UI: settings
Gui, settings_menu: Color, Black
Gui, settings_menu: Margin, 12, 4
WinSet, Transparent, %trans%
Gui, settings_menu: Font, s%fSize0% cWhite underline, Fontin SmallCaps

Gui, settings_menu: Add, Text, % "Section BackgroundTrans " settings_style " gSettings_menu HWNDhwnd_settings_general", % "general"
ControlGetPos,,, width_settings,,, ahk_id %hwnd_settings_general%
spacing_settings := width_settings

screenchecks_gamescreen_valid := 1
screenchecks_bestiary_valid := 1
screenchecks_betrayal_valid := 1
screenchecks_gwennen_valid := 1

If (pixel_gamescreen_color1 = "ERROR") || (pixel_gamescreen_color1 = "")
	screenchecks_gamescreen_valid := 0
If !FileExist("img\Recognition (" poe_height "p)\GUI\bestiary.bmp")
	screenchecks_bestiary_valid := 0
If !FileExist("img\Recognition (" poe_height "p)\GUI\betrayal.bmp")
	screenchecks_betrayal_valid := 0
If !FileExist("img\Recognition (" poe_height "p)\GUI\gwennen.bmp")
	screenchecks_gwennen_valid := 0
screenchecks_all_valid := screenchecks_gamescreen_valid * screenchecks_bestiary_valid * screenchecks_betrayal_valid * screenchecks_gwennen_valid

If !InStr(buggy_resolutions, poe_height)
{
	Gui, settings_menu: Add, Text, xs BackgroundTrans %alarm_style% gSettings_menu HWNDhwnd_settings_alarm, % "alarm-timer"
	ControlGetPos,,, width_settings,,, ahk_id %hwnd_settings_alarm%
	spacing_settings := (width_settings > spacing_settings) ? width_settings : spacing_settings
	
	Gui, settings_menu: Add, Text, xs BackgroundTrans %betrayal_style% gSettings_menu HWNDhwnd_settings_betrayal, % "betrayal-info"
	ControlGetPos,,, width_settings,,, ahk_id %hwnd_settings_betrayal%
	spacing_settings := (width_settings > spacing_settings) ? width_settings : spacing_settings

	Gui, settings_menu: Add, Text, xs BackgroundTrans %clone_frames_style% gSettings_menu HWNDhwnd_settings_clone_frames, % "clone-frames"
	ControlGetPos,,, width_settings,,, ahk_id %hwnd_settings_clone_frames%
	spacing_settings := (width_settings > spacing_settings) ? width_settings : spacing_settings

	Gui, settings_menu: Add, Text, xs BackgroundTrans %map_mods_style% gSettings_menu HWNDhwnd_settings_map_mods, % "map-info"
	ControlGetPos,,, width_settings,,, ahk_id %hwnd_settings_map_mods%
	spacing_settings := (width_settings > spacing_settings) ? width_settings : spacing_settings

	Gui, settings_menu: Add, Text, xs BackgroundTrans %notepad_style% gSettings_menu HWNDhwnd_settings_notepad, % "notepad"
	ControlGetPos,,, width_settings,,, ahk_id %hwnd_settings_notepad%
	spacing_settings := (width_settings > spacing_settings) ? width_settings : spacing_settings

	Gui, settings_menu: Add, Text, xs BackgroundTrans %omnikey_style% gSettings_menu HWNDhwnd_settings_omnikey, % "omni-key"
	ControlGetPos,,, width_settings,,, ahk_id %hwnd_settings_omnikey%
	spacing_settings := (width_settings > spacing_settings) ? width_settings : spacing_settings

	If pixel_gamescreen_x1 is number
	{
		If (screenchecks_all_valid = 0)
			Gui, settings_menu: Font, cRed
		Gui, settings_menu: Add, Text, xs BackgroundTrans %pixelcheck_style% gSettings_menu HWNDhwnd_settings_pixelcheck, % "screen-checks"
		ControlGetPos,,, width_settings,,, ahk_id %hwnd_settings_pixelcheck%
		spacing_settings := (width_settings > spacing_settings) ? width_settings : spacing_settings
		Gui, settings_menu: Font, cWhite
	}
	
	If WinExist("ahk_exe GeForceNOW.exe")
	{
		Gui, settings_menu: Font, cLime
		Gui, settings_menu: Add, Text, xs BackgroundTrans %geforce_style% gSettings_menu HWNDhwnd_settings_geforce, % "geforce now"
		ControlGetPos,,, width_settings,,, ahk_id %hwnd_settings_geforce%
		spacing_settings := (width_settings > spacing_settings) ? width_settings : spacing_settings
		Gui, settings_menu: Font, cWhite
	}
}
Gui, settings_menu: Font, norm

If !InStr(GuiControl_copy, "notepad") && WinExist("ahk_id " hwnd_notepad_sample)
{
	Gui, notepad_sample: Destroy
	hwnd_notepad_sample := ""
}

If !InStr(GuiControl_copy, "alarm") && WinExist("ahk_id " hwnd_alarm_sample)
{
	Gui, alarm_sample: Destroy
	hwnd_alarm_sample := ""
}

If InStr(GuiControl_copy, "general") || (A_Gui = "LLK_panel") || (A_Gui = "")
	GoSub, Settings_menu_general
Else If InStr(GuiControl_copy, "alarm")
	GoSub, Settings_menu_alarm
Else If InStr(GuiControl_copy, "betrayal") && !InStr(GuiControl_copy, "image")
	GoSub, Settings_menu_betrayal
Else If InStr(GuiControl_copy, "clone") || (new_clone_menu_closed = 1)
	GoSub, Settings_menu_clone_frames
Else If InStr(GuiControl_copy, "map")
	GoSub, Settings_menu_map_info
Else If InStr(GuiControl_copy, "notepad")
	GoSub, Settings_menu_notepad
Else If InStr(GuiControl_copy, "omni")
	GoSub, Settings_menu_omnikey
Else If InStr(GuiControl_copy, "image") || InStr(GuiControl_copy, "pixel") || InStr(GuiControl_copy, "screen")
	GoSub, Settings_menu_screenchecks
Else If InStr(GuiControl_copy, "geforce")
	GoSub, Settings_menu_geforce_now

If !InStr(GuiControl_copy, "betrayal")
{
	ControlFocus,, ahk_id %hwnd_settings_general%
	Loop 4
		LLK_Overlay("betrayal_info_" A_Index, "hide")
}
Else ControlFocus,, ahk_id %hwnd_betrayal_edit%

If ((xsettings_menu != "") && (ysettings_menu != ""))
	Gui, settings_menu: Show, Hide x%xsettings_menu% y%ysettings_menu%
Else
{
	Gui, settings_menu: Show, Hide
	;WinGetPos,,, wsettings_menu
	;Gui, settings_menu: Show, % "Hide x"xScreenOffset + poe_width//2 - wsettings_menu//2 " y"yScreenOffset
}
LLK_Overlay("settings_menu", "show", 1)
Return

Settings_menu_alarm:
Gui, settings_menu: Add, Checkbox, % "ys Section BackgroundTrans venable_alarm gApply_settings_alarm checked"enable_alarm " xp+"spacing_settings*1.2, enable alarm-timer
If (enable_alarm = 1)
{
	GoSub, Alarm
	Gui, settings_menu: Add, Text, % "xs Section Center BackgroundTrans y+"fSize0*1.2, text color:
	Gui, settings_menu: Add, Text, % "xs Section Center BackgroundTrans vfontcolor_white cWhite gApply_settings_alarm Border", % " white "
	Gui, settings_menu: Add, Text, % "ys BackgroundTrans Center vfontcolor_red cRed gApply_settings_alarm Border x+"fSize0//4, % " red "
	Gui, settings_menu: Add, Text, % "ys BackgroundTrans Center vfontcolor_aqua cAqua gApply_settings_alarm Border x+"fSize0//4, % " cyan "
	Gui, settings_menu: Add, Text, % "ys BackgroundTrans Center vfontcolor_yellow cYellow gApply_settings_alarm Border x+"fSize0//4, % " yellow "
	Gui, settings_menu: Add, Text, % "ys BackgroundTrans Center vfontcolor_lime cLime gApply_settings_alarm Border x+"fSize0//4, % " lime "
	Gui, settings_menu: Add, Text, % "ys BackgroundTrans Center vfontcolor_fuchsia cFuchsia gApply_settings_alarm Border x+"fSize0//4, % " purple "
	
	Gui, settings_menu: Add, Text, % "xs Section Center BackgroundTrans y+"fSize0*1.2, text-size offset:
	Gui, settings_menu: Add, Text, % "ys BackgroundTrans Center vfSize_alarm_minus gApply_settings_alarm Border", % " – "
	Gui, settings_menu: Add, Text, % "ys BackgroundTrans Center vfSize_alarm_reset gApply_settings_alarm Border x+2 wp", % "0"
	Gui, settings_menu: Add, Text, % "ys BackgroundTrans Center vfSize_alarm_plus gApply_settings_alarm Border x+2 wp", % "+"
	
	Gui, settings_menu: Add, Text, % "ys Center BackgroundTrans", opacity:
	Gui, settings_menu: Add, Text, % "ys BackgroundTrans Center valarm_opac_minus gApply_settings_alarm Border", % " – "
	Gui, settings_menu: Add, Text, % "ys BackgroundTrans Center valarm_opac_plus gApply_settings_alarm Border x+2 wp", % "+"
}
Return

Settings_menu_betrayal:
Gui, betrayal_search: Destroy
Gui, settings_menu: Add, Checkbox, % "ys Section Center gBetrayal_apply vBetrayal_enable_recognition BackgroundTrans xp+"spacing_settings*1.2 " Checked"betrayal_enable_recognition, use image recognition instead of text-search`n(requires additional setup)
Gui, settings_menu: Add, Text, % "xs Section Center BackgroundTrans y+"fSize0*1.2, text-size offset:
Gui, settings_menu: Add, Text, % "ys BackgroundTrans Center vfSize_betrayal_minus gBetrayal_apply Border", % " – "
Gui, settings_menu: Add, Text, % "ys BackgroundTrans Center vfSize_betrayal_reset gBetrayal_apply Border x+2 wp", % "0"
Gui, settings_menu: Add, Text, % "ys BackgroundTrans Center vfSize_betrayal_plus gBetrayal_apply Border x+2 wp", % "+"

Gui, settings_menu: Add, Text, % "ys Center BackgroundTrans", opacity:
Gui, settings_menu: Add, Text, % "ys BackgroundTrans Center vbetrayal_opac_minus gBetrayal_apply Border", % " – "
Gui, settings_menu: Add, Text, % "ys BackgroundTrans Center vbetrayal_opac_plus gBetrayal_apply Border x+2 wp", % "+"

Gui, settings_menu: Add, Text, % "xs Section Center BackgroundTrans y+"fSize0*1.2, % "member search: "
Gui, settings_menu: Font, % "s"fSize0 - 4
Gui, settings_menu: Add, Edit, % "ys x+0 hp wp BackgroundTrans cBlack vBetrayal_searchbox HWNDhwnd_betrayal_edit",
Gui, settings_menu: Font, % "s"fSize0
Gui, settings_menu: Add, Text, % "xs Section BackgroundTrans Border gBetrayal_apply vImage_folder HWNDmain_text y+"fSize0*1.2, % " open img folder "
Gui, settings_menu: Add, Button, xs BackgroundTrans Default Hidden vBetrayal_search_button gBetrayal_search, OK
GoSub, Betrayal_search
Return

Settings_menu_clone_frames:
new_clone_menu_closed := 0
clone_frames_enabled := ""
IniRead, clone_frames_list, ini\clone frames.ini
Sort, clone_frames_list, D`n
If (pixel_gamescreen_x1 != "") && (pixel_gamescreen_x1 != "ERROR") && (enable_pixelchecks = 1)
{
	Gui, settings_menu: Add, Checkbox, % "ys Section BackgroundTrans gClone_frames_apply vClone_frames_pixelcheck_enable Checked" clone_frames_pixelcheck_enable " xp+"spacing_settings*1.2, toggle overlay automatically
	Gui, settings_menu: Add, Picture, % "ys x+0 BackgroundTrans gSettings_menu_help vpixelcheck_auto_trigger hp w-1", img\GUI\help.png
	Gui, settings_menu: Add, Text, % "xs Section BackgroundTrans y+"fSize0*1.2, list of clone-frames currently set up:
}
Else Gui, settings_menu: Add, Text, % "ys Section BackgroundTrans xp+"spacing_settings*1.2, list of clone-frames currently set up:
Loop, Parse, clone_frames_list, `n, `n
{
	If (A_LoopField = "Settings")
		continue
	If clone_frame_%A_LoopField%_enable is not number
		IniRead, clone_frame_%A_LoopField%_enable, ini\clone frames.ini, %A_LoopField%, enable, 1
	If (clone_frame_%A_LoopField%_enable = 1)
	{
		clone_frames_enabled := (clone_frames_enabled = "") ? A_LoopField "," : A_LoopField "," clone_frames_enabled
		Gui, clone_frames_%A_Loopfield%: New, -Caption +E0x80000 +E0x20 +LastFound +AlwaysOnTop +ToolWindow +OwnDialogs HWNDhwnd_%A_Loopfield%
	}
	Gui, settings_menu: Add, Checkbox, % "xs Section BackgroundTrans gClone_frames_apply Checked" clone_frame_%A_LoopField%_enable " vClone_frame_" A_LoopField "_enable", % "enable: "
	Gui, settings_menu: Font, underline
	Gui, settings_menu: Add, Text, % "ys x+0 BackgroundTrans gClone_frames_preview_list", % A_LoopField
	Gui, settings_menu: Font, norm
}
Gui, settings_menu: Add, Text, % "xs Section Border gClone_frames_new vClone_frames_add BackgroundTrans y+"fSize0*1.2, % " add frame "
Return

Settings_menu_geforce_now:
Gui, settings_menu: Add, Text, % "ys Section BackgroundTrans HWNDmain_text xp+"spacing_settings*1.2, % "pixel-check allowed variation: "
ControlGetPos,,,, controlheight,, ahk_id %main_text%
Gui, settings_menu: Font, % "s"fSize0-4 "norm"
Gui, settings_menu: Add, Edit, % "ys x+0 hp BackgroundTrans cBlack Number gGeforce_now_apply Center Limit3 vPixelsearch_variation w"controlheight*1.6, %pixelsearch_variation%
Gui, settings_menu: Font, s%fSize0%
Gui, settings_menu: Add, Text, % "xs y+0 BackgroundTrans", % "(range: 0–255, default: 0)"

Gui, settings_menu: Add, Text, % "xs Section BackgroundTrans HWNDmain_text y+"fSize0*1.2, % "image-check allowed variation: "
ControlGetPos,,,, controlheight,, ahk_id %main_text%
Gui, settings_menu: Font, % "s"fSize0-4 "norm"
Gui, settings_menu: Add, Edit, % "ys x+0 hp BackgroundTrans cBlack Number gGeforce_now_apply Center Limit3 vImagesearch_variation w"controlheight*1.6, %imagesearch_variation%
Gui, settings_menu: Font, s%fSize0%
Gui, settings_menu: Add, Text, % "xs BackgroundTrans", % "(range: 0–255, default: 25)"
Return

Settings_menu_general:
Gui, settings_menu: Add, Checkbox, % "ys Section BackgroundTrans gApply_settings_general HWNDmain_text Checked" kill_script " vkill_script xp+"spacing_settings*1.2, % "kill script after"
ControlGetPos,,,, controlheight,, ahk_id %main_text%

Gui, settings_menu: Font, % "s"fSize0-4 "norm"
Gui, settings_menu: Add, Edit, % "ys x+0 hp BackgroundTrans cBlack Number gApply_settings_general right Limit2 vkill_timeout w"controlheight*1.2, %kill_timeout%
Gui, settings_menu: Font, % "s"fSize0
Gui, settings_menu: Add, Text, % "ys BackgroundTrans x+"fSize0//2, % "minute(s) w/o poe-client"

Gui, settings_menu: Add, Link, % "xs hp Section HWNDlink_text y+"fSize0*1.2, <a href="https://github.com/Lailloken/Lailloken-UI/discussions/49">custom resolution:</a>
Gui, settings_menu: Add, Text, % "ys BackgroundTrans HWNDmain_text x+"fSize0//2, % poe_width " x "
ControlGetPos,,,, height,, ahk_id %main_text%
ControlGetPos,,, width,,, ahk_id %link_text%
resolutionsDDL := ""
IniRead, resolutions_all, data\Resolutions.ini
choice := 0
Loop, Parse, resolutions_all, `n,`n
	If !(InStr(A_LoopField, "768") || InStr(A_LoopField, "1024") || InStr(A_LoopField, "1050")) && !(StrReplace(A_LoopField, "p", "") > height_native)
		resolutionsDDL := (resolutionsDDL = "") ? StrReplace(A_LoopField, "p", "") : StrReplace(A_LoopField, "p", "") "|" resolutionsDDL
Loop, Parse, resolutionsDDL, |, |
	If (A_LoopField = poe_height)
		choice := A_Index
Gui, settings_menu: Font, % "s"fSize0-4
Gui, settings_menu: Add, DDL, % "ys x+0 BackgroundTrans HWNDmain_text vcustom_resolution r10 wp Choose" choice, % resolutionsDDL
Gui, settings_menu: Font, % "s"fSize0
Gui, settings_menu: Add, Text, % "xs Section BackgroundTrans Border gApply_resolution", % " apply && restart "
Gui, settings_menu: Add, Checkbox, % "ys BackgroundTrans HWNDmain_text Checked" custom_resolution_setting " vcustom_resolution_setting ", % "apply on startup "
Gui, settings_menu: Add, Text, % "xs Section BackgroundTrans Center HWNDmain_text y+"fSize0*1.2, % "panel position:"
ControlGetPos,,, width,,, ahk_id %main_text%
Gui, settings_menu: Font, % "s"fSize0-4
If (panel_position0 = "top")
	Gui, settings_menu: Add, DDL, % "hp x+6 ys BackgroundTrans Border Center vpanel_position0 gApply_settings_general r2 w"width*0.6, % "top||bottom"
Else Gui, settings_menu: Add, DDL, % "hp x+6 ys BackgroundTrans Border Center vpanel_position0 gApply_settings_general r2 w"width*0.6, % "top|bottom||"
If (panel_position1 = "left") || (panel_position1 = "")
	Gui, settings_menu: Add, DDL, % "hp x+2 ys BackgroundTrans Border Center vpanel_position1 gApply_settings_general r2 w"width*0.6, % "left||right"
Else Gui, settings_menu: Add, DDL, % "hp x+2 ys BackgroundTrans Border Center vpanel_position1 gApply_settings_general r2 w"width*0.6, % "left|right||"
	Gui, settings_menu: Font, % "s"fSize0
Gui, settings_menu: Add, Checkbox, % "ys BackgroundTrans Checked" hide_panel " vhide_panel gApply_settings_general", % "hide panel"
Gui, settings_menu: Add, Text, % "xs Section BackgroundTrans y+"fSize0*1.2, % "interface size:"
Gui, settings_menu: Add, Text, ys x+6 BackgroundTrans gApply_settings_general vinterface_size_minus Border Center, % " – "
Gui, settings_menu: Add, Text, wp x+2 ys BackgroundTrans gApply_settings_general vinterface_size_reset Border Center, % "0"
Gui, settings_menu: Add, Text, wp x+2 ys BackgroundTrans gApply_settings_general vinterface_size_plus Border Center, % "+"
Return

Settings_menu_help:
MouseGetPos, mouseXpos, mouseYpos
Gui, settings_menu_help: New, -Caption -DPIScale +LastFound +AlwaysOnTop +ToolWindow +Border HWNDhwnd_settings_menu_help
Gui, settings_menu_help: Color, Black
Gui, settings_menu_help: Margin, 12, 4
;WinSet, Transparent, %trans%
Gui, settings_menu_help: Font, s%fSize1% cWhite, Fontin SmallCaps

If (A_GuiControl = "map_info")
{
text =
(
explanation
0 hides the mod from now on, and higher values have distinct text-colors.

it's up to you how to tier the mods and whether to use all tiers.
)
	Gui, settings_menu_help: Add, Text, % "BackgroundTrans w"fSize0*20, % text
	Gui, settings_menu_help: Show, % "NA x"mouseXpos " y"mouseYpos " AutoSize"
}

If (A_GuiControl = "pixelcheck_auto_trigger")
{
text =
(
explanation
allows the script to automatically hide/show its overlays by adapting to what's happening on screen.

requires 'gamescreen' pixel-check to be set up correctly and playing with the mini-map in the center of the screen.
)
	Gui, settings_menu_help: Add, Text, % "BackgroundTrans w"fSize0*20, % text
	Gui, settings_menu_help: Show, % "NA x"mouseXpos " y"mouseYpos " AutoSize"
}

If (A_GuiControl = "pixelcheck_help")
{
text =
(
explanation
left-click the button to test the pixel-check, right-click the button to calibrate.

ui textures in PoE sometimes get updated in patches, which leads to screen-checks failing. this is where you recalibrate the checks in order to continue using the script.

disclaimer
these screen-checks merely trigger actions within the script itself and will -NEVER- result in any interaction with the client.

they are used to let the script toggle its ui elements in order to adapt to what's happening on screen, emulating the use of an addon-api.
)
	Gui, settings_menu_help: Add, Text, % "BackgroundTrans w"fSize0*20, % text
	Gui, settings_menu_help: Show, % "NA x"mouseXpos " y"mouseYpos " AutoSize"
}
If InStr(A_GuiControl, "gamescreen")
{
text =
(
instructions
to recalibrate, close the inventory and every menu until you're on the main screen (where you control your character). then, set the mini-map to overlay-mode on the center of the screen.

explanation
this check helps the script identify whether the user is in a menu or on the regular 'gamescreen', which enables it to hide overlays automatically in order to prevent obstructing full-screen menus.
)
	Gui, settings_menu_help: Add, Picture, % "BackgroundTrans w"fSize0*20 " w-1", img\GUI\game_screen.jpg
	Gui, settings_menu_help: Add, Text, BackgroundTrans wp, % text
	Gui, settings_menu_help: Show, % "NA x"mouseXpos " y"mouseYpos " AutoSize"
}
If (A_GuiControl = "pixelcheck_enable_help")
{
text =
(
explanation
this should only be disabled when experiencing severe performance drops while running the script.

when disabled, overlays will not show/hide automatically (if the user navigates through in-game menus) and they have to be toggled manually.
)
	Gui, settings_menu_help: Add, Text, % "BackgroundTrans w"fSize0*20, % text
	Gui, settings_menu_help: Show, % "NA x"mouseXpos " y"mouseYpos " AutoSize"
}


If (A_GuiControl = "imagecheck_help")
{
text =
(
explanation
left-click the button to test the image-check, right-click the button to screen-cap.

same concept as pixel-checks (see top of this section) but with images instead of pixels. image-checks are used when pixel-checks are unreliable due to movement on screen.
)
	Gui, settings_menu_help: Add, Text, % "BackgroundTrans w"fSize0*20, % text
	Gui, settings_menu_help: Show, % "NA x"mouseXpos " y"mouseYpos " AutoSize"
}
If InStr(A_GuiControl, "bestiary")
{
text =
(
instructions
to recalibrate, open the beastcrafting window and screen-cap the plate displayed above.

explanation
this check helps the script identify whether the beastcrafting window is open or not, which enables search-field inputs to be replaced on the fly.
)
	Gui, settings_menu_help: Add, Picture, % "BackgroundTrans w"fSize0*20 " w-1", img\GUI\bestiary.jpg
	Gui, settings_menu_help: Add, Text, % "BackgroundTrans w"fSize0*20, % text
	Gui, settings_menu_help: Show, % "NA x"mouseXpos " y"mouseYpos " AutoSize"
}
If InStr(A_GuiControl, "betrayal")
{
text =
(
instructions
to recalibrate, open the syndicate board, do not zoom into or move it, and screen-cap an area above the health globe.

explanation
this check helps the script identify whether the syndicate board is up or not, which enables the omni-key to trigger the info-sheet.
)
	Gui, settings_menu_help: Add, Picture, % "BackgroundTrans w"fSize0*20 " w-1", img\GUI\betrayal.jpg
	Gui, settings_menu_help: Add, Text, % "BackgroundTrans w"fSize0*20, % text
	Gui, settings_menu_help: Show, % "NA x"mouseXpos " y"mouseYpos " AutoSize"
}
If InStr(A_GuiControl, "gwennen")
{
text =
(
instructions
to recalibrate, open Gwennen's gamble window and screen-cap the plate displayed above.

explanation
this check helps the script identify whether Gwennen's gamble window is open or not, which enables the omni-key to trigger the regex-string features.
)
	Gui, settings_menu_help: Add, Picture, % "BackgroundTrans w"fSize0*20 " w-1", img\GUI\gwennen.jpg
	Gui, settings_menu_help: Add, Text, % "BackgroundTrans w"fSize0*20, % text
	Gui, settings_menu_help: Show, % "NA x"mouseXpos " y"mouseYpos " AutoSize"
}


If InStr(A_GuiControl, "omnikey")
{
text =
(
explanation
this hotkey is context-sensitive and used to access the majority of this script's features. it's meant to be the only hotkey you have to use while playing.

this feature does not block the key-press from being sent to the client. if you still want/need to rebind it, bind it to a key that's not used for chatting.

used to access
- context-menu for items
- map mods panel
- map horizons info
- orb of horizons search
- betrayal info-sheet
- Gwennen regex-string
)
	Gui, settings_menu_help: Add, Text, % "BackgroundTrans w"fSize0*20, % text
	Gui, settings_menu_help: Show, % "NA x"mouseXpos " y"mouseYpos " AutoSize"
}
WinGetPos, winx, winy, width, height, ahk_id %hwnd_settings_menu_help%
newxpos := (winx + width > xScreenOffSet + poe_width) ? xScreenOffSet + poe_width - width : winx
newypos := (winy + height > yScreenOffSet + poe_height) ? yScreenOffSet + poe_height - height : winy
Gui, Settings_menu_help: Show, NA x%newxpos% y%newypos%
KeyWait, LButton
Gui, settings_menu_help: Destroy
Return

Settings_menu_map_info:
map_info_primary := 0
If (enable_pixelchecks = 1) && (pixel_gamescreen_x1 != "") && (pixel_gamescreen_x1 != "ERROR")
{
	Gui, settings_menu: Add, Checkbox, % "ys Section BackgroundTrans gMap_info_settings_apply xp+"spacing_settings*1.2 " vMap_info_pixelcheck_enable Checked"Map_info_pixelcheck_enable, toggle overlay automatically
	Gui, settings_menu: Add, Picture, % "ys x+0 BackgroundTrans gSettings_menu_help vPixelcheck_auto_trigger hp w-1", img\GUI\help.png
	map_info_primary := 1
}
If (map_info_primary = 0)
	Gui, settings_menu: Add, Text, % "ys Section Center BackgroundTrans xp+"spacing_settings*1.2, text-size offset:
Else Gui, settings_menu: Add, Text, % "xs Section Center BackgroundTrans y+"fSize0*1.2, text-size offset:
	
Gui, settings_menu: Add, Text, % "ys BackgroundTrans Center vfSize_map_info_minus gMap_info_settings_apply Border", % " – "
Gui, settings_menu: Add, Text, % "ys BackgroundTrans Center vfSize_map_info_reset gMap_info_settings_apply Border x+2 wp", % "0"
Gui, settings_menu: Add, Text, % "ys BackgroundTrans Center vfSize_map_info_plus gMap_info_settings_apply Border x+2 wp", % "+"

Gui, settings_menu: Add, Text, % "ys Center BackgroundTrans", opacity:
Gui, settings_menu: Add, Text, % "ys BackgroundTrans Center vmap_info_opac_minus gMap_info_settings_apply Border", % " – "
Gui, settings_menu: Add, Text, % "ys BackgroundTrans Center vmap_info_opac_plus gMap_info_settings_apply Border x+2 wp", % "+"

Gui, settings_menu: Add, Text, % "xs Section Center BackgroundTrans HWNDmain_text y+"fSize0*1.2, % "panel position: "
map_info_choice := (map_info_side = "right") ? 1 : 2
ControlGetPos,,, width,,, ahk_id %main_text%
Gui, settings_menu: Font, % "s"fSize0 - 4
Gui, settings_menu: Add, DDL, % "ys hp cBlack Center BackgroundTrans r2 vMap_info_side gMap_info_settings_apply Choose"map_info_choice " w"width//2 , % "right||left"
Gui, settings_menu: Font, % "s"fSize0


Gui, settings_menu: Add, Text, % "xs Section BackgroundTrans y+"fSize0*1.2, % "search for mods: "
Gui, settings_menu: Font, % "s"fSize0 - 4
Gui, settings_menu: Add, Edit, % "ys x+0 cBlack BackgroundTrans Limit gMap_info_customization vMap_info_search wp"
GoSub, Map_info
Return

Settings_menu_notepad:
Gui, settings_menu: Add, Checkbox, % "ys Section BackgroundTrans gApply_settings_notepad xp+"spacing_settings*1.2 " venable_notepad Checked"enable_notepad, enable notepad
If (enable_notepad = 1)
{
	GoSub, Notepad
	Gui, settings_menu: Add, Text, % "xs Section Center BackgroundTrans y+"fSize0*1.2, text color (overlay):
	Gui, settings_menu: Add, Text, % "xs Section Center BackgroundTrans vfontcolor_white cWhite gApply_settings_notepad Border", % " white "
	Gui, settings_menu: Add, Text, % "ys BackgroundTrans Center vfontcolor_red cRed gApply_settings_notepad Border x+"fSize0//4, % " red "
	Gui, settings_menu: Add, Text, % "ys BackgroundTrans Center vfontcolor_aqua cAqua gApply_settings_notepad Border x+"fSize0//4, % " cyan "
	Gui, settings_menu: Add, Text, % "ys BackgroundTrans Center vfontcolor_yellow cYellow gApply_settings_notepad Border x+"fSize0//4, % " yellow "
	Gui, settings_menu: Add, Text, % "ys BackgroundTrans Center vfontcolor_lime cLime gApply_settings_notepad Border x+"fSize0//4, % " lime "
	Gui, settings_menu: Add, Text, % "ys BackgroundTrans Center vfontcolor_fuchsia cFuchsia gApply_settings_notepad Border x+"fSize0//4, % " purple "
	
	Gui, settings_menu: Add, Text, % "xs Section Center BackgroundTrans y+"fSize0*1.2, text-size offset:
	Gui, settings_menu: Add, Text, % "ys BackgroundTrans Center vfSize_notepad_minus gApply_settings_notepad Border", % " – "
	Gui, settings_menu: Add, Text, % "ys BackgroundTrans Center vfSize_notepad_reset gApply_settings_notepad Border x+2 wp", % "0"
	Gui, settings_menu: Add, Text, % "ys BackgroundTrans Center vfSize_notepad_plus gApply_settings_notepad Border x+2 wp", % "+"
	
	Gui, settings_menu: Add, Text, % "ys Center BackgroundTrans", opacity:
	Gui, settings_menu: Add, Text, % "ys BackgroundTrans Center vnotepad_opac_minus gApply_settings_notepad Border", % " – "
	Gui, settings_menu: Add, Text, % "ys BackgroundTrans Center vnotepad_opac_plus gApply_settings_notepad Border x+2 wp", % "+"
}
Return

Settings_menu_omnikey:
If (GuiControl_copy = "reset_omnikey_hotkey") && (omnikey_hotkey != "")
{
	Hotkey, IfWinActive, ahk_group poe_window
	Hotkey, *~%omnikey_hotkey%,, Off
	omnikey_hotkey := ""
	Hotkey, *~MButton, Omnikey, On
	IniWrite, %A_Space%, ini\config.ini, Settings, omni-hotkey
}

Gui, settings_menu: Add, Text, % "ys Section BackgroundTrans HWNDmain_text xp+"spacing_settings*1.2, replace mbutton with:
Gui, settings_menu: Add, Picture, % "ys BackgroundTrans vOmnikey_help gSettings_menu_help hp w-1", img\GUI\help.png
ControlGetPos,,, width,,, ahk_id %main_text%
Gui, settings_menu: Font, % "s"fSize0-4
Gui, settings_menu: Add, Hotkey, % "xs Section hp BackgroundTrans vomnikey_hotkey gApply_settings_omnikey w"width//3, %omnikey_hotkey%
Gui, settings_menu: Font, % "s"fSize0
Gui, settings_menu: Add, Text, % "ys BackgroundTrans Border vreset_omnikey_hotkey gSettings_menu", % " clear "
Return

Settings_menu_screenchecks:
Gui, settings_menu: Add, Text, % "ys Section BackgroundTrans HWNDmain_text xp+"spacing_settings*1.2, % "list of integrated pixel-checks: "
ControlGetPos,,,, height,, ahk_id %main_text%
Gui, settings_menu: Add, Picture, % "ys x+0 BackgroundTrans gSettings_menu_help vPixelcheck_help hp w-1", img\GUI\help.png
Loop, Parse, pixelchecks_list, `,, `,
{
	
	Gui, settings_menu: Add, Text, % "xs Section BackgroundTrans HWNDmain_text border gScreenchecks v" A_Loopfield "_pixel y+"fSize0*0.6, % " check | calibrate "
	If (screenchecks_%A_Loopfield%_valid = 0)
		Gui, settings_menu: Font, cRed underline
	Else Gui, settings_menu: Font, cWhite underline
	Gui, settings_menu: Add, Text, % "ys BackgroundTrans gSettings_menu_help v" A_Loopfield "_help HWNDmain_text", % A_Loopfield
	Gui, settings_menu: Font, norm cWhite
}
Gui, settings_menu: Font, norm
Gui, settings_menu: Add, Checkbox, % "hp xs Section BackgroundTrans gScreenchecks_settings_apply vEnable_pixelchecks Center Checked"enable_pixelchecks, % "enable background pixel-checks"
Gui, settings_menu: Add, Picture, % "ys x+0 BackgroundTrans gSettings_menu_help vPixelcheck_enable_help hp w-1", img\GUI\help.png

Gui, settings_menu: Add, Text, % "xs Section BackgroundTrans HWNDmain_text y+"fSize0*1.5, % "list of integrated image-checks: "
Gui, settings_menu: Add, Picture, % "ys x+0 BackgroundTrans gSettings_menu_help vImagecheck_help hp w-1", img\GUI\help.png
Loop, Parse, imagechecks_list, `,, `,
{
	Gui, settings_menu: Font, norm	
	Gui, settings_menu: Add, Text, % "xs Section BackgroundTrans HWNDmain_text border gScreenchecks v" A_Loopfield "_image y+"fSize0*0.6, % " check | calibrate "
	If (screenchecks_%A_Loopfield%_valid = 0)
		Gui, settings_menu: Font, cRed underline
	Else Gui, settings_menu: Font, cWhite underline
	ControlGetPos,,, width,,, ahk_id %main_text%
	Gui, settings_menu: Add, Text, % "ys BackgroundTrans gSettings_menu_help v" A_Loopfield "_help HWNDmain_text", % A_Loopfield
	Gui, settings_menu: Font, norm cWhite
}
Gui, settings_menu: Font, norm
Gui, settings_menu: Add, Text, % "xs Section BackgroundTrans Border gScreenchecks_settings_apply vImage_folder HWNDmain_text y+"fSize0*0.6 " w"width, % " open img folder "
Return

Settings_menuGuiClose:
WinGetPos, xsettings_menu, ysettings_menu,,, ahk_id %hwnd_settings_menu%
Gui, settings_menu: Submit
kill_timeout := (kill_timeout = "") ? 0 : kill_timeout
Gui, settings_menu: Destroy
hwnd_settings_menu := ""

If WinExist("ahk_id " hwnd_betrayal_info_1)
{
	Loop 4
		LLK_Overlay("betrayal_info_" A_Index, "hide")
}
If WinExist("ahk_id " hwnd_notepad_sample)
{
	Gui, notepad_sample: Destroy
	hwnd_notepad_sample := ""
}

If WinExist("ahk_id " hwnd_alarm_sample)
{
	Gui, alarm_sample: Destroy
	hwnd_alarm_sample := ""
}
WinActivate, ahk_group poe_window
Return

ToolTip_clear:
SetTimer, ToolTip_clear, delete
ToolTip,,,, 17
Return

LLK_ImageSearch(name)
{
	global
	pHaystack_ImageSearch := Gdip_BitmapFromHWND(hwnd_poe_client)
	pNeedle_ImageSearch := Gdip_CreateBitmapFromFile("img\Recognition (" poe_height "p)\GUI\" name ".bmp")
	imagesearch_x1 := 0
	imagesearch_y1 := 0
	imagesearch_x2 := 0
	imagesearch_y2 := 0
	If (name = "gwennen" || name = "bestiary")
	{
		imagesearch_x1 := 0
		imagesearch_y1 := 0
		imagesearch_x2 := 0
		imagesearch_y2 := poe_height//2
	}
	Else If (name = "betrayal")
	{
		imagesearch_x1 := 0
		imagesearch_y1 := poe_height//2
		imagesearch_x2 := 0
		imagesearch_y2 := 0
	}
	%name% := Gdip_ImageSearch(pHaystack_ImageSearch, pNeedle_ImageSearch, LIST, imagesearch_x1, imagesearch_y1, imagesearch_x2, imagesearch_y2, imagesearch_variation,, 1, 1)
	Gdip_DisposeImage(pHaystack_ImageSearch)
	Gdip_DisposeImage(pNeedle_ImageSearch)
	Gdip_DisposeImage(%name%)
	If (%name% > 0)
		Return 1
	Else Return 0
}

LLK_InStrCount(var, string)
{
	count := 0
	Loop, Parse, var
	{
		If (A_Loopfield = character)
			count += 1
	}
	Return count
}

LLK_Error(ErrorMessage)
{
	global
	MsgBox, % ErrorMessage
	ExitApp
}

LLK_HotstringClip(hotstring, mode := 0)
{
	global
	hotstring := StrReplace(hotstring, ":")
	hotstring := StrReplace(hotstring, "?")
	hotstring := StrReplace(hotstring, ".")
	hotstring := StrReplace(hotstring, "*")
	If (hotstring = "gwen")
		gwennen_regex := clipboard
	clipboard := ""
	SendInput, ^{a}^{c}
	If (mode = 1)
		SendInput, {ESC}
	;Else SendInput, ^{a}^{x}
	ClipWait, 0.1
	hotstringboard := InStr(clipboard, "@") ? SubStr(clipboard, InStr(clipboard, " ") + 1) : clipboard
	hotstringboard := (SubStr(hotstringboard, 0) = " ") ? SubStr(hotstringboard, 1, -1) : hotstringboard
	If (hotstring = "best")
		GoSub, Bestiary_search
	If (hotstring = "gwen")
		GoSub, Gwennen_search
	If (hotstring = "synd")
		GoSub, Betrayal_search
	If (hotstring = "llk")
	{
		If (hotstringboard != "")
			settings_menu_section := clipboard
		GoSub, Settings_menu
	}
	If (hotstring = "lab")
	{
		If (lab_mode != 1)
			GoSub, Lab_info
		Else
		{
			lab_mode := 0
			Gui, lab_layout: Destroy
			Gui, lab_marker: Destroy
			DllCall("DeleteObject", "ptr", hbmLab_source)
			hwnd_lab_layout := ""
			hwnd_lab_marker := ""
		}
	}
}

LLK_Omnikey_ToolTip(text:=0)
{
	global
	If (text = 0)
	{
		Gui, omnikey_tooltip: Destroy
		Return
	}
	If (text = "")
	{
		SoundBeep
		Return
	}
	Gui, omnikey_tooltip: New, -DPIScale +E0x20 +LastFound +AlwaysOnTop +ToolWindow -Caption +Border HWNDhwnd_omnikey_tooltip,
	Gui, omnikey_tooltip: Color, Black
	Gui, omnikey_tooltip: Margin, 12, 4
	WinSet, Transparent, %trans%
	Gui, omnikey_tooltip: Font, s%fSize0% cWhite, Fontin SmallCaps
	If InStr(text, "horizons:")
	{
		text := StrReplace(text, "horizons:")
		Gui, omnikey_tooltip: Font, underline
		Gui, omnikey_tooltip: Add, Text, Section BackgroundTrans, % "horizons:"
		Gui, omnikey_tooltip: Font, norm
		Gui, omnikey_tooltip: Add, Text, xs BackgroundTrans, % text
	}
	Else Gui, omnikey_tooltip: Add, Text, BackgroundTrans, % text
	Gui, omnikey_tooltip: Show, Hide AutoSize
	MouseGetPos, mouseXpos, mouseYpos
	WinGetPos, winX, winY, winW, winH, ;ahk_id %hwnd_omnikey_tooltip%
	tooltip_posX := (mouseXpos - winW < xScreenOffSet) ? xScreenOffSet : mouseXpos - winW
	tooltip_posy := (mouseYpos - winH < yScreenOffSet) ? yScreenOffSet : mouseYpos - winH
	Gui, omnikey_tooltip: Show, % "NA AutoSize x"tooltip_posX " y"tooltip_posy
}

LLK_Overlay(gui, toggleshowhide:="toggle", NA:=1)
{
	global
	If (gui="hide")
	{
		Loop, Parse, guilist, |, |
		{
			If (A_Loopfield = "")
				Break
			Gui, %A_LoopField%: Hide
		}
		Return
	}
	If (gui="show")
	{
		Loop, Parse, guilist, |, |
		{
			If (A_Loopfield = "")
				Break
			If (state_%A_LoopField%=1) && (hwnd_%A_LoopField% != "")
				Gui, %A_LoopField%: Show, NA
		}
		Return
	}
	If (toggleshowhide="toggle")
	{
		If !WinExist("ahk_id " hwnd_%gui%) && (hwnd_%gui% != "")
		{
			Gui, %gui%: Show, NA
			state_%gui% := 1
			Return
		}
		If WinExist("ahk_id " hwnd_%gui%)
		{
			Gui, %gui%: Hide
			state_%gui% := 0
			Return
		}
	}
	If (toggleshowhide="show") && (hwnd_%gui% != "")
	{
		If (NA = 1)
			Gui, %gui%: Show, NA
		Else Gui, %gui%: Show
		state_%gui% := 1
	}
	If (toggleshowhide="hide")
	{
		Gui, %gui%: Hide
		state_%gui% := 0
	}
}

LLK_PixelRecalibrate(name)
{
	global
	loopcount := InStr(name, "gamescreen") ? 1 : 2
	Loop %loopcount%
	{
		If InStr(name, "gamescreen")
			PixelGetColor, pixel_%name%_color%A_Index%, % xScreenOffset + poe_width - pixel_%name%_x%A_Index%, % yScreenOffset + pixel_%name%_y%A_Index%, RGB
		Else PixelGetColor, pixel_%name%_color%A_Index%, % xScreenOffset + pixel_%name%_x%A_Index%, % yScreenoffset + pixel_%name%_y%A_Index%, RGB
		IniWrite, % pixel_%name%_color%A_Index%, ini\pixel checks (%poe_height%p).ini, %name%, color %A_Index%
	}
}

LLK_PixelSearch(name)
{
	global
	If InStr(name, "gamescreen")
		PixelSearch, OutputVarX, OutputVarY, xScreenOffSet + poe_width - pixel_%name%_x1, yScreenOffSet + pixel_%name%_y1, xScreenOffSet + poe_width - pixel_%name%_x1, yScreenOffSet + pixel_%name%_y1, pixel_%name%_color1, %pixelsearch_variation%, Fast RGB
	Else PixelSearch, OutputVarX, OutputVarY, xScreenOffSet + pixel_%name%_x1, yScreenOffSet + pixel_%name%_y1, xScreenOffSet + pixel_%name%_x1, yScreenOffSet + pixel_%name%_y1, pixel_%name%_color1, %pixelsearch_variation%, Fast RGB
	If (ErrorLevel = 0) && !InStr(name, "gamescreen")
		PixelSearch, OutputVarX, OutputVarY, xScreenOffSet + pixel_%name%_x2, yScreenOffSet + pixel_%name%_y2, xScreenOffSet + pixel_%name%_x2, yScreenOffSet + pixel_%name%_y2, pixel_%name%_color2, %pixelsearch_variation%, Fast RGB
	%name% := (ErrorLevel=0) ? 1 : 0
	value := %name%
	Return value
}

LLK_Rightclick()
{
	global
	click := 2
	SendInput, {LButton}
	KeyWait, RButton
	click := 1
}

LLK_ToolTip(message, duration := 1, x := "", y := "")
{
	global
	mouseYpos := ""
	MouseGetPos,, mouseYpos
	mouseYpos -= fSize0
	If (y = "")
		ToolTip, % message, %x%, %mouseYpos%, 17
	Else ToolTip, % message, %x%, %y%, 17
	SetTimer, ToolTip_clear, % 1000 * duration
}

#include External Functions.ahk