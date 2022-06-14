MCRC := "ED7771E7"
MVersion := "1.0.7"

; Action: Can be get (get's the drive letter associated to the chosen drive type), mount (mount a disc), unmount (unmount a disc)
; File: Full path to file you want to mount (only need to provide this when using action type "mount"
; Type: Leave blank to use auto mode or what the user has chosen in RLUI for that system. To force a specific drive type, send "dt" or "scsi" in the module
; Drive: A drive number for DT can be sent in the scenario a user has multiple dt or scsi drives and prefers to not use the first one (0). This is not used in any module to date.

VirtualDrive(action,file:="",type:="",drive:=0){
	Global vdFullPath,vdUseSCSI,vdAddDrive,vdDriveLetter,sevenZFormatsNoP,DTAllowGDIQuotes
	Static vdExe,vdPath,vdFileInfo,vdFileProductName,vdFileProductVersion,vdMode,supportedExtensions,dtSubVersion,unmountType
	RLLog.Info("VirtualDrive - Started - action is " . action)
	vdMap := Object(0,"A",1,"B",2,"C",3,"D",4,"E",5,"F",6,"G",7,"H",8,"I",9,"J",10,"K",11,"L",12,"M",13,"N",14,"O",15,"P",16,"Q",17,"R",18,"S",19,"T",20,"U",21,"V",22,"W",23,"X",24,"Y",25,"Z")
	If file	; only log file when one is used
		RLLog.Debug("VirtualDrive - Received file: " . file)
	SplitPath, file,,,ext

	; First run only checks and determine user's chosen VD application
	If !vdFileInfo {
		SplitPath, vdFullPath,vdExe,vdPath
		CheckFile(vdFullPath, "Could not find " . vdFullPath . "`nPlease fix the Virtual Drive Path key in RocketLauncherUI to point to your preferred Virtual Drive application executable or turn off Virtual Drive support.")
		vdFileInfo := FileGetVersionInfo_AW(vdFullPath, "ProductName|ProductVersion", "|")
		Loop, Parse, vdFileInfo, |
		{	If (A_Index = 1)
				vdFileProductName := RegExReplace(A_Loopfield,"ProductName\s*")
			Else
				vdFileProductVersion := RegExReplace(A_Loopfield,"ProductVersion\s*")
		}
		RLLog.Debug("VirtualDrive - Using " . vdFileProductName . " version " . vdFileProductVersion . " found at: " . vdFullPath)
		
		If InStr(vdFileProductName,"Daemon")
		{
			If SubStr(vdFileProductVersion,1,1) = 4
			{	vdMode := "DT4"
				supportedExtensions := "ape|b5t|b6t|bin|bwt|ccd|cdi|cue|flac|iso|isz|mds|mdx|nrg"
				If InStr(vdFileProductName,"Ultra") {
					vdMode := "DT5"
					RLLog.Debug("VirtualDrive - Detected Ultra version of Daemon Tools: """ . vdFileProductName . """. Switching to DT5 mode as Ultra uses the same commands as DT5.")
				}
			} Else If SubStr(vdFileProductVersion,1,1) = 5
			{	vdMode := "DT5"
				driveLetterCheck := 1
				supportedExtensions := "ape|b5t|b6t|bin|bwt|ccd|cdi|cue|flac|iso|isz|mds|mdx|nrg"
			} Else If SubStr(vdFileProductVersion,1,1) = 6		; so far v6 is the Pro version of DT10 lite
			{	vdMode := "DT6"
				driveLetterCheck := 1
				supportedExtensions := "ape|b5t|b6t|bwt|ccd|cdi|cue|flac|iscsi|iso|isz|mds|mdx|nrg|tc|vdh|vdi|vmdk|wav|zip"
				If (InStr(vdFileProductName,"Pro") && vdExe != "DTAgent.exe")
					ScriptError(vdFileProductName . " v" . vdFileProductVersion . " requires you to set your Virtual Drive Path to DTAgent.exe, not " . vdExe)
			} Else If SubStr(vdFileProductVersion,1,2) = 10
			{	vdMode := "DT10"
				supportedExtensions := "ape|b5t|b6t|bwt|ccd|cdi|cue|flac|iscsi|iso|isz|mds|mdx|nrg|tc|vdh|vdi|vmdk|wav|zip"
				dtSubVersion := SubStr(vdFileProductVersion,1,4)
				If (vdExe != "DTAgent.exe")
					ScriptError(vdFileProductName . " v" . vdFileProductVersion . " requires you to set your Virtual Drive Path to DTAgent.exe, not " . vdExe)
			} Else If SubStr(vdFileProductVersion,1,2) = 11
			{	vdMode := "DT11"
				supportedExtensions := "ape|b5t|b6t|bwt|ccd|cdi|cue|flac|iscsi|iso|isz|mds|mdx|nrg|tc|vdh|vdi|vmdk|wav|zip"
				dtSubVersion := SubStr(vdFileProductVersion,1,4)
				If (vdExe != "DTCommandLine.exe")
					ScriptError(vdFileProductName . " v" . vdFileProductVersion . " requires you to set your Virtual Drive Path to DTCommandLine.exe, not " . vdExe)
			} Else If SubStr(vdFileProductVersion,1,3) = 1.0
				ScriptError(vdFileProductName . " v" . vdFileProductVersion . " is a Virtual CloneDrive application. Please set RocketLauncherUI to use VCDMount.exe instead.")
			Else
				ScriptError("VirtualDrive - This version of " . vdFileProductName . " is untested and may not be supported correctly, please report this to the RocketLauncher Devs",3)
		}
		Else If InStr(vdFileProductName,"Alcohol")
		{
			vdMode := "Alcohol"
			driveLetterCheck := 1
			supportedExtensions := "b5t|b6t|bin|bwt|ccd|cdi|cue|iso|isz|mds|mdx|nrg|pdi"
			If (vdExe != "AxCmd.exe")
				ScriptError(vdMode . " only works when using ""AxCmd.exe"" as the executable. """ . vdExe . """ will not work. Please set your Virtual Drive Path to point to AxCmd.exe instead.")
			deviceCount := RegRead("HKEY_CURRENT_USER", "Software\Alcohol Soft\Alcohol 120%\Basic", "Virtual Device Count")	; first check registered version 120% key
			If !deviceCount
				deviceCount := RegRead("HKEY_CURRENT_USER", "Software\Alcohol Soft\Alcohol 52%\Basic", "Virtual Device Count")	; check trial 52% key
			If (deviceCount >= 1)
				RLLog.Debug("VirtualDrive - " . vdMode . " has " . deviceCount . " virtual drives on your system. Virtual_Drive_Drive_Letter general setting in RocketLauncherUI must match the letter you want to use.")
			Else
				ScriptError(vdMode . " has " . deviceCount . " virtual drives on your system. Please setup a virtual drive first in " . vdMode . " before using Virtual Drive support.")
		}
		Else If InStr(vdFileProductName,"VCDMount")	; Virtual CloneDrive settings stored in HKEY_CURRENT_USER\Software\Elaborate Bytes\VirtualCloneDrive
		{
			If SubStr(vdFileProductVersion,1,1) = "5"
			{	vdMode := "CloneDrive"
				supportedExtensions := "bin|ccd|cdi|dvd|img|iso|udf"	; cue is not supported!
				deviceCount := RegRead("HKEY_CURRENT_USER", "Software\Elaborate Bytes\VirtualCloneDrive", "NumberOfDrives")
				If !deviceCount {
					RLLog.Warning("VirtualDrive - Could not find a device count in the registry for " . vdMode . " which means it was not manually ran first. Running it automatically so it is generated.")
					Run("VCDPrefs.exe", vdPath)
					WinWait("Virtual CloneDrive ahk_class TMainForm")
					WinWaitActive("Virtual CloneDrive ahk_class TMainForm")
					ControlSend,TButton1, {Enter}, Virtual CloneDrive ahk_class TMainForm	; Ok button
					deviceCount := RegRead("HKEY_CURRENT_USER", "Software\Elaborate Bytes\VirtualCloneDrive", "NumberOfDrives")
				}
				If (deviceCount > 1)
					RLLog.Warning("VirtualDrive - " . vdMode . " has " . deviceCount . " virtual drives on your system. RocketLauncher will only use the first drive.")
				Else If (deviceCount = 0)
				{	deviceCount := 1
					RegWrite("REG_DWORD", "HKEY_CURRENT_USER", "Software\Elaborate Bytes\VirtualCloneDrive", "NumberOfDrives", deviceCount)
					RLLog.Warning("VirtualDrive - " . vdMode . " had its device count changed from 0 to 1. You may now use it with RocketLauncher")
				} Else If !deviceCount
					ScriptError("There was a problem finding the device count for " . vdFileProductVersion . ". Make sure a virtual drive exists first.")
			}
		}
		Else If InStr(vdFileProductName,"Virtual CD")
		{
			If SubStr(vdFileProductVersion,1,2) = 10
			{	vdMode := "VirtualCD"
				driveLetterCheck := 1
				supportedExtensions := "b5i|bin|bwi|c2d|img|iso|mdf|nrg|vc4|xmf"
			}
		}
		Else If (InStr(vdFileProductName,"PowerISO") || foundPIso := (vdFileProductName = "" && vdExe = "piso.exe"))
		{
			If foundPIso	; must set this because piso contains no info on details and this code will run again on the next VD call
				vdFileInfo := 1
			If (SubStr(vdFileProductVersion,1,1) = 6 || foundPIso)
			{	vdMode := "PowerISO"
				vdFileProductName := "PowerISO"		; forcing this because piso.exe has no info on it
				driveLetterCheck := 1
				supportedExtensions := "ashdisc|b5i|bin|bwi|c2d|cdi|cif|cue|daa|fcd|gi|img|iso|lcd|mdf|mds|ncd|nrg|p01|pdi|pxi|vcd"
				vdExe := "piso.exe"		; remapping to this exe as this is the CLI exe
				CheckFile(vdPath . "\" . vdExe, "You have PowerISO.exe as your VD application but the CLI utility piso.exe could not be found: " . vdPath . "\" . vdExe)
				deviceCount := RegRead("HKEY_CURRENT_USER", "Software\PowerISO\SCDEmu", "DiskCount")
				driveLetters := RegRead("HKEY_CURRENT_USER", "Software\PowerISO\SCDEmu", "DriveLetter")
				If !driveLetters
					ScriptError("Could not find your PowerISO DriveLetters. It appears you have not rebooted since installing PowerISO, so please do that first.")
				If (deviceCount = 1) {
					vdDriveLetter := SubStr(driveLetters,1,1)	; forcing drive letter set in PowerISO's setting
					RLLog.Debug("VirtualDrive - Changing your VD Drive Letter to " . vdDriveLetter . " because you only have one drive active in " . vdMode . ".")
				} Else If deviceCount > 1
					RLLog.Warning("VirtualDrive - " . vdMode . " has " . deviceCount . " virtual drives on your system. Please make sure RocketLauncherUI is set to use the correct drive.")
				If !InStr(driveLetters,vdDriveLetter)
					ScriptError("Please set RocketLauncherUI to use the same drive letter that " . vdMode . " is set to. You can find this in General Settings, Third Party tabs, and under Virtual Drive.")
			}
		}
		Else If InStr(vdFileProductName,"MagicISO")
		{
			If SubStr(vdFileProductVersion,1,1) = 3
			{	vdMode := "MagicDisc"
				driveLetterCheck := 1
				supportedExtensions := "000|bin|bwi|bwt|c2d|ccd|cdi|cif|dao|ima|img|iso|md1|mdf|mds|nrg|p01|pdi|tao|uif|vaporcd|vc4|vcd|vdi|xa"
			} Else If SubStr(vdFileProductVersion,1,1) = 5
				ScriptError(vdFileProductName . " is the Maker application for MagicDisc. Point your Virtual Drive Path in RocketLauncherUI to ""miso.exe"" which is the command line utility.")
			Else
				ScriptError(vdFileProductName . " is an unknown and unsupported version of MagicISO. Only v3.x of miso.exe is supported.")
		}
		Else If InStr(vdFileProductName,"UltraISO")	; no apparent way to mount an image just through CLI on UltraISO...
		{
			; If SubStr(vdFileProductVersion,1,2) = "V9"
			; {	
				vdMode := "UltraISO"
				supportedExtensions := "000|ashdisc|b5i|b5t|b6i|b6t|bif|bin|bwi|bwt|c2d|ccd|cdi|cif|cue|daa|dao|dmg|dvd|fcd|flp|gcd|gi|hfs|ima|img|iso|isz|ixa|lcd|md1|mdf|mds|ncd|nrg|p01|p2i|pdi|pxi|rdf|rif|tao|timg|uif|vaporcd|vc4|vcd|vdi|xa|xmd|xmf"
				ScriptError(vdFileProductName . " is an unsupported virtual drive application as it doesn't support simple mounting via CLI. Please choose another application.")
			; }
		}
		Else
			ScriptError(vdFileProductName . " is a Virtual Drive application not supported by RocketLauncher at this time")
		If (driveLetterCheck && !vdDriveLetter && vdDriveLetter !=0)
			ScriptError(vdFileProductName . " requires that you set the Virtual Drive Drive Letter setting in RocketLauncherUI to the letter or number of the virtual drive you want to use.")
		If vdMode
			RLLog.Debug("VirtualDrive - All VirtualDrive calls will use mode " . vdMode)
		Else
			RLLog.Error("VirtualDrive - There was an error starting VirtualDrive support")
	}
	If !RegExMatch(action,"i)get|mount|unmount")
		ScriptError(action . " is an unsupported use of VirtualDrive. Only get, mount, and unmount actions are supported.")

	; Global VD checks
	If (action = "mount")
	{	If RegExMatch(ext,"i)" . sevenZFormatsNoP)
			ScriptError("VirtualDrive was sent an archive extension """ . ext . """ which is not a mountable file type. Turn on 7z support or uncompress this game in order to mount it.")
		Else If !RegExMatch(ext,"i)" . supportedExtensions)
			ScriptError("VirtualDrive was sent the extension """ . ext . """ which is not a supported file type for " . vdFileProductName . ".")
		If RegExMatch(ext,"cue|gdi")
		{	cueHasMp3s := RLObject.findCUETracksByExtension(file, "mp3")	; 0 = no mp3s, 1 = found mp3s, 2 = cant find cue, 3 = cue invalid. Multiple extensions can be | serparated
			If !cueHasMp3s {
				RLLog.Debug("VirtualDrive - This " . ext . " does not contain any mp3s.")
				If (ext = "cue") {
					validateCUE := RLObject.validateCUE(file)	; 0 = cue is invalid, 1 = cue is valid, 2 = cant find cue
					If (validateCUE = 1)
						RLLog.Debug("VirtualDrive - This " . ext . " was found valid.")
					Else If !validateCUE
						RLLog.Error("VirtualDrive - validateCUE returned an invalid error code. Please check the RocketLauncher.DLL.log for additional info.")
					Else {	; 2
						RLLog.Error("VirtualDrive - validateCUE returned an error code of """ . validateCUE . """. Please check the RocketLauncher.DLL.log for additional info.")
						ScriptError("You have an invalid " . ext . " file. Please check it for errors. Please check the RocketLauncher.DLL.log for additional info.")
					}
				} Else If (ext = "gdi") {
					If !DTAllowGDIQuotes	; by default, gdi files can contain double quotes. If a module contains "DTAllowGDIQuotes = false" it will be sent to the dll to error if they exist anywhere in the gdi.
						DTAllowGDIQuotes := "true"
					Else If !RegExMatch(DTAllowGDIQuotes,"i)true|false")
						ScriptError(DTAllowGDIQuotes . " is an invalid option for DTAllowGDIQuotes. It must either be true or false.")
					validateGDI := RLObject.validateGDI(file, DTAllowGDIQuotes)	; 0 = gdi is invalid, 1 = gsi is valid, 2 = cant find gdi, 3 = invalid double quotes were found. DTAllowGDIQuotes when true tells the dll that the GDI can have double quotes. False it cannot have quotes.
					If (validateGDI = 1)
						RLLog.Debug("VirtualDrive - This " . ext . " was found valid.")
					Else If !(validateGDI) {
						RLLog.Error("VirtualDrive - validateGDI returned an error code of " . validateGDI)
						ScriptError("You have an invalid " . ext . " file. Please check it for errors.")
					} Else If (validateGDI = 3) {
						RLLog.Error("VirtualDrive - validateGDI returned an error code of " . validateGDI)
						ScriptError("Invalid double quotes were found in " . ext . " file.")
					} Else
						ScriptError("Can't find GDI """ . file . """")
				}
			} Else If (cueHasMp3s = 1)
				ScriptError("Your " . ext . " file contains links to mp3 files which is not supported by Virtual Drives. Please download another version of this game without MP3s or turn off Virtual Drive support to use the emulator's built-in image handler if supported.")
			Else If (cueHasMp3s = 2)
				ScriptError("There was a problem finding your " . ext . " file. Please check it exists at: " . file)
			Else If (cueHasMp3s = 3)
				ScriptError("You have an invalid " . ext . " file. Please check it for errors.")
		}
	}
	
	; Application-specific commands
	option := ""
	If (vdMode = "DT4")
	{
		vdFile := If file ? "`, """ . file . """" : ""
		type := If type ? type : (If vdUseSCSI = "true" ? "scsi" : "dt")
		If !RegExMatch(type,"i)dt|scsi")
			ScriptError(type . " is an unsupported use of VirtualDrive. Only dt and scsi drives are supported.")
		If !RegExMatch(drive,"i)0|1|2|3|4")
			ScriptError(drive . " is an invalid virtual device number. Only 0 through 4 are supported.")
		If (action != "unmount")
		{	curErr := RunWait(vdExe . " -get_count " . type, vdPath)	; DT4 only. DT5 removes the drive when unmounted, so this will usually return 0
			If (curErr = 0 && vdAddDrive = "true"){
				RLLog.Debug("VirtualDrive - Did not find a " . type . " drive, creating one now. Please stand by as this can take a bit.")
				RunWait(vdFullPath . " -add " . type, vdPath)	; DT4 only. Not supported in DT5
				Sleep, 500
			} Else If (curErr = 0)
				ScriptError("You are trying to mount to a " . type . " virtual drive, yet one does not exist. Add a SCSI drive manually or Enable the General Setting ""Add Drive"" in RocketLauncherUI.")
			If (action = "get")
			{	curErr := RunWait(vdExe . " -get_letter " . type . "`, " . drive, vdPath)
				vdDriveLetter := vdMap[curErr]	; we do not use the user's defined drive letter as it's done internally in the DT4 application
				If !curErr
					ScriptError("A error occured finding the drive letter associated to your " . type . " drive. Please make sure you are using the latest Daemon Tools Lite v4.")
				RLLog.Debug("VirtualDrive ended - Retrieved your " . type . " drive letter: " . vdDriveLetter)
				Return
			}
		}
		RLLog.Info("VirtualDrive - Running your " . vdMode . " Virtual Drive with: " . vdFullPath . " -" . action . " " . type . ", " .  drive . vdFile)
		vdCommand := "-" . action . " " . type . "`, " . drive . vdFile
	}
	Else If RegExMatch(vdMode,"i)DT5|DT10")
	{
		type := If type ? type : (If vdUseSCSI = "true" ? "scsi" : "dt")
		If (action = "mount")
		{	If !RegExMatch(type,"i)dt|scsi")
				ScriptError(type . " is an unsupported use of VirtualDrive. Only dt and scsi drives are supported.")
			If (dtSubVersion = "10.4") {
				vdCommand := "-mount " . type . ", 0, """ . file . """"
			}Else {
				vdCommand := "-mount " . type . ", " . vdDriveLetter . ", """ . file . """"
			}
		} Else If (action = "unmount") {
			If (dtSubVersion = "10.4") {
				vdCommand := "-unmount " . type . ", 0"	; CLI differs in 10.4 version so it must be differentiated
			} Else {
				vdCommand := "-unmount " . vdDriveLetter
			}
		} Else If (action = "get")
			If (dtSubVersion = "10.4") {
				curErr := RunWait(vdExe . " -get_letter " . type . ", " . drive, vdPath)
				vdDriveLetter := vdMap[curErr]	; we do not use the user's defined drive letter as it's done internally in the DT4 application
				If !curErr
					ScriptError("A error occured finding the drive letter associated to your " . type . " drive. Please make sure you are using the latest Daemon Tools Lite v4.")
				RLLog.Debug("VirtualDrive ended - Retrieved your " . type . " drive letter: " . vdDriveLetter)
			} 
				RLLog.Info("VirtualDrive - " . vdMode . " does not require the ""get"" action")
	}
	Else If (vdMode = "DT11")
	{
		type := If type ? type : (If vdUseSCSI = "true" ? "scsi" : "dt")		
		If (action = "mount")
		{	If (dtSubVersion = "11.0") {
				vdCommand := "--mount_to --letter " . vdDriveLetter . " --path """ . file . """"
			} 
		} Else If (action = "unmount") {
			If (dtSubVersion = "11.0") {
				vdCommand := "--unmount --letter " . vdDriveLetter ; CLI differs in 11.0 version so it must be differentiated
			} 
		} Else If (action = "get")
		{	If (dtSubVersion = "11.0") {
				vdDriveLetter := (If vdUseSCSI = "true" ? "E" : "D")			
			}			
		}
	}
	Else If (vdMode = "DT6")
	{
		type := If type ? type : (If vdUseSCSI = "true" ? "scsi" : "dt")
		If !RegExMatch(type,"i)dt|scsi")
			ScriptError(type . " is an unsupported use of VirtualDrive. Only dt and scsi drives are supported.")
		If (action = "mount")
			vdCommand := "-mount " . type . ", " . vdDriveLetter . ", """ . file . """"
		Else If (action = "unmount")
			vdCommand := "-unmount " . type . ", " . vdDriveLetter		; DT6 Pro requires a number, not a drive letter that designates what drive to use
		Else If (action = "get")
			RLLog.Info("VirtualDrive - " . vdMode . " does not require the ""get"" action")
	}
	Else If (vdMode = "CloneDrive")
	{
		If (action = "mount")
			vdCommand := "/d=0 """ . file . """"
		Else If (action = "unmount")
			vdCommand := "/u"
		Else If (action = "get")
			RLLog.Info("VirtualDrive - " . vdMode . " does not require the ""get"" action")
	}
	Else If (vdMode = "VirtualCD")
	{
		If (action = "mount")
			vdCommand := "/i """ . file . """ " . vdDriveLetter . ":"
		Else If (action = "unmount")
			vdCommand := "/e " . vdDriveLetter . ":"
		Else If (action = "get")
			RLLog.Info("VirtualDrive - " . vdMode . " does not require the ""get"" action")
	}
	Else If (vdMode = "PowerISO")
	{
		option := "Hide"
		If (action = "mount")
			vdCommand := "mount """ . file . """ " . vdDriveLetter . ":"	; PowerISO pops up a console window if not hidden
		Else If (action = "unmount")
			vdCommand := "unmount " . vdDriveLetter . ":"
		Else If (action = "get")
			RLLog.Info("VirtualDrive - " . vdMode . " does not require the ""get"" action")
	}
	Else If (vdMode = "MagicISO")
	{
		If (action = "mount")
			vdCommand := "NULL -mnt 1 """ . file . """"
		Else If (action = "unmount")
			vdCommand := "NULL -umnt 1 " . vdDriveLetter
		Else If (action = "get")
			RLLog.Info("VirtualDrive - " . vdMode . " does not require the ""get"" action")
	}
	Else If (vdMode = "Alcohol")
	{
		If (action = "mount")
			vdCommand := vdDriveLetter . ": /M:""" . file . """"	; mounts to drive 0 which is the first configured drive in Alcohol
		Else If (action = "unmount")
			vdCommand := vdDriveLetter . ": /U"
		Else If (action = "get")
			RLLog.Info("VirtualDrive - " . vdMode . " does not require the ""get"" action")
	}
	Else
		ScriptError(vdFileProductName . " v" . vdFileProductVersion . " is not currently supported, please request this application to be supported or stick with Daemon Tools Lite 4 or 5, or Alcohol.")
	
	If RegExMatch(action,"i)mount|unmount")
	{	curErr := RunWait(vdExe . " " . vdCommand, vdPath, option)
		If curErr
			RLLog.Warning("VirtualDrive - Error reported by " . vdFileProductName . " during a " . action . " operation: " . curErr)
	}
	RLLog.Info("VirtualDrive - Ended")
}
