@ECHO OFF
SETLOCAL ENABLEEXTENSIONS ENABLEDELAYEDEXPANSION
SET quiet=n
SET MYAPPDATA=%APPDATA%\TimeDicer
SET ver=1.0829
SET credit=Dominic
SET contact=dominic@timedicer.co.uk
SET homepage=http://www.timedicer.co.uk
REM set our own errorlevel indicator to 0
SET el=0

REM change current path to the location of %this% - could use PUSHD instead?
SET execpath=%~dp0
SET execpath=%execpath:~0,-1%
SET startpath=%CD%
IF /I "%execpath%" EQU "" SET execpath=%CD%
IF /I "%execpath%" NEQ "%CD%" CD /D %execpath%
IF ERRORLEVEL 1 SET el=117&&GOTO :endd

SET this=%~n0
CALL :lower_case "%this%"
IF ERRORLEVEL 1 SET el=118&&GOTO :endd
SET thislc=%lcase%

REM g for debug messages
CALL :param_check g %1 %2 %3 %4 %5 %6 %7
IF ERRORLEVEL 1 SET el=119&&GOTO :endd
IF %param% GTR 0 (SET debug=y&&SHIFT /%param%) ELSE SET debug=n
IF "%debug%" == "y" ECHO %0 %*

REM ---- Process command line options ----
REM v for version
CALL :param_check v %1 %2 %3 %4 %5 %6 %7
IF ERRORLEVEL 1 SET el=120&&GOTO :endd
IF %param% GTR 0 ECHO %ver%&&GOTO :eof
REM h or ? for help
CALL :param_check h %1 %2 %3 %4 %5 %6 %7
IF ERRORLEVEL 1 SET el=121&&GOTO :endd
IF %param% GTR 0 GOTO :help
CALL :param_check ? %1 %2 %3 %4 %5 %6 %7
IF ERRORLEVEL 1 SET el=122&&GOTO :endd
IF %param% GTR 0 GOTO :help
REM -m as %1 just creates -man.html file at specified destination %2
IF /I "%~1"=="-m" GOTO :help
IF ERRORLEVEL 1 SET el=130&&GOTO :endd
REM x for exit at end, not pause
CALL :param_check x %1 %2 %3 %4 %5 %6 %7
IF ERRORLEVEL 1 SET el=123&&GOTO :endd
IF %param% GTR 0 (SET exitnow=y&&SHIFT /%param%) ELSE SET exitnow=n
REM q for quiet
CALL :param_check q %1 %2 %3 %4 %5 %6 %7
IF ERRORLEVEL 1 SET el=124&&GOTO :endd
IF %param% GTR 0 (SET quiet=y&&SHIFT /%param%) ELSE SET quiet=n
REM r for restore
CALL :param_check r %1 %2 %3 %4 %5 %6 %7
IF ERRORLEVEL 1 SET el=125&&GOTO :endd
IF %param% GTR 0 (SET restore=y&&SHIFT /%param%)
REM o for overwrite (on restore)
CALL :param_check o %1 %2 %3 %4 %5 %6 %7
IF ERRORLEVEL 1 SET el=126&&GOTO :endd
IF %param% GTR 0 (SET overwrite=--force &&SHIFT /%param%)

IF %quiet% == n (
	ECHO.
	ECHO %this% v%ver% by %credit%
	ECHO.
)

REM f to set configuration file
CALL :param_check f %1 %2 %3 %4 %5 %6 %7
IF ERRORLEVEL 1 SET el=127&&GOTO :endd
IF %param% GTR 0 (
	SHIFT /%param%
	SET configfile=%nextparam%
	SHIFT /%param%
	REM IF "%quiet%"=="n" ECHO Using configuration file %nextparam%
) ELSE (
	SET configfile="%MYAPPDATA%\%this%.txt"
)
REM remove quotes if present
IF "%debug%"=="y" ECHO configfile identified as '%configfile%'
SET configfilelong=%configfile:"=%
IF NOT EXIST "%configfilelong%" (
	IF %quiet% == n ECHO No configuration file "%configfilelong%" found. For help run with -h option.
	SET el=10
	GOTO :endd
)
IF "%debug%"=="y" ECHO configfilelong identified as '%configfilelong%'
REM Get configfile in short form
FOR %%I IN ("%configfilelong%") DO SET configfile=%%~sI
IF ERRORLEVEL 1 SET el=103&&ECHO Failure setting configfile&&GOTO :endd
IF "%debug%"=="y" ECHO configfile reconfigured as '%configfile%'

REM ----------
REM Determine Windows version WINVER 5.0=2000, 5.1=XP, 5.2=2003, 6.0=Vista, 6.1=7/2008
FOR /F "tokens=2* delims=[]" %%A IN ('VER') DO FOR /F "tokens=2,3 delims=. " %%B IN ("%%A") DO SET WINVER=%%B.%%C
REM Determine Windows 32-bit (x86) or 64-bit (x64) WINBIT
SET WINBIT=x86&&IF "%PROCESSOR_ARCHITECTURE%" == "AMD64" (SET WINBIT=x64) ELSE IF "%PROCESSOR_ARCHITEW6432%" == "AMD64" SET WINBIT=x64
IF %WINVER% LSS 5.1 (
	IF %quiet% == n ECHO Sorry, %this% cannot run under this version of Windows %WINVER%-%WINBIT%.
	SET el=12
	GOTO :endd
)
REM Set VSHADOWVER appropriately for the vshadow-n-[bit].exe programs
IF %WINVER%==5.1 SET VSHADOWVER=xp&&SET WINBIT=x86
IF %WINVER%==5.2 SET VSHADOWVER=2003&&SET WINBIT=x86
IF %WINVER%==6.0 SET VSHADOWVER=2008
IF %WINVER%==6.1 SET VSHADOWVER=2008-r2

REM c for comparing
CALL :param_check c %1 %2 %3 %4 %5 %6 %7
IF ERRORLEVEL 1 SET el=128&&GOTO :endd
IF %param% GTR 0 (
	SET compare=--compare
	SET action=Comparing
	SHIFT /%param%
	IF %quiet% == n ECHO Comparing files...
	GOTO :done_runtype
)
REM t for testing
CALL :param_check t %1 %2 %3 %4 %5 %6 %7
IF ERRORLEVEL 1 SET el=129&&GOTO :endd
IF %param% GTR 0 (
	SHIFT /%param%
	SET test=y
	SET action=Test backing up from
	IF %quiet% == n ECHO Test run, actual backup will not be performed...
) ELSE (
	SET action=Backing up from
)
:done_runtype
REM ---- Check for presence of required external files ----
IF %quiet% == n (
	ECHO %~n0 started at %DATE% %TIME%
	REM ECHO Checking whether required external programs are available:
)
REM we use file_check for program files that must be in the current path. Although
REM not strictly necessary that all these files be in the current path, as long as
REM they can be run from the command linem it is tidier to keep them in same
REM directory as this command script.
IF ERRORLEVEL 1 SET el=104&&GOTO :endd
CALL :file_check rdiff-backup-win.exe http://www.nongnu.org/rdiff-backup/ %el%
IF ERRORLEVEL 1 SET el=5&&GOTO :endd
CALL :file_check Microsoft.VC90.CRT.manifest http://download.savannah.gnu.org/releases/rdiff-backup/Microsoft.VC90.zip %el%
IF ERRORLEVEL 1 SET el=5&&GOTO :endd
CALL :file_check ssed.exe http://sed.sourceforge.net/grabbag/ssed/sed-3.62.zip %el%
IF ERRORLEVEL 1 SET el=5&&GOTO :endd
CALL :file_check plink.exe http://www.chiark.greenend.org.uk/~sgtatham/putty/download.html %el%
IF ERRORLEVEL 1 SET el=5&&GOTO :endd
IF %el% GEQ 1 GOTO :endd
REM IF %quiet% == n ECHO All required external files were found

REM ---- Establish variables and configuration files ----
REM set default user value to %USERNAME%-%USERDOMAIN% but in lowercase with spaces stripped
CALL :lower_case "%USERNAME%-%USERDOMAIN%"
SET user=%lcase%
REM set default key value
SET key="%MYAPPDATA%\privatekey.ppk"
IF NOT EXIST %key% SET key="%USERPROFILE%\privatekey.ppk"
REM set default logfile
SET log=%MYAPPDATA%\%this%-log.txt
REM set default usage of Volume Shadow Services
SET vss=y
REM set default port for server
SET port=22
REM set default skipping of backup if source has not changed since last time
SET skip_on_no_change=y
IF ERRORLEVEL 1 SET el=131&&GOTO :endd
REM split config file into two, one with the variable settings, one with the folder list
IF "%debug%"=="y" ECHO about to create %this%-setup.bat
ssed -n "/^\s*SET /I{s/\s*#.*//;p}" "%configfile%">%TEMP%\%this%-setup.bat
IF ERRORLEVEL 1 SET el=132&&GOTO :endd
IF "%debug%"=="y" ECHO about to create %this%-datasets.txt
REM delayed expansion has to be turned off here so that exclamations can pass through
SETLOCAL ENABLEEXTENSIONS DISABLEDELAYEDEXPANSION
ssed -n "/^\s*SET /I!{s/\s*#.*//;/^$/!p}" "%configfile%">%TEMP%\%this%-datasets.txt
IF ERRORLEVEL 1 SET el=132&&GOTO :endd
ENDLOCAL
REM set some defaults before we pick up values from the configuration file
IF "%debug%"=="y" ECHO about to call mapdrive, mapdrive is '%mapdrive%'
CALL :mapdrive
IF ERRORLEVEL 1 SET el=133&&GOTO :endd
IF "%debug%"=="y" ECHO called mapdrive, set to '%mapdrive%'
SET primarysourcedrive=C:
REM define variables as per the list file
CALL %TEMP%\%this%-setup.bat
IF ERRORLEVEL 1 SET el=134&&GOTO :endd
IF "%debug%"=="y" ECHO Ran %TEMP%\%this%-setup.bat
REM test if we have a server defined
IF "%server%"=="" ECHO TimeDicer Server not defined ^(SET server=...^) in configuration file %configfilelong%&&SET el=15&&GOTO :endd
REM set lastchangesfilelong and thischangesfilelong - long filenames without quotes
FOR /F "usebackq delims=" %%I IN (`ECHO %configfilelong%`) DO (
	SET lastchangesfilelong=%%~dpIlastchanges-%user%-%%~nI.txt
	SET thischangesfilelong=%%~dpIthischanges-%user%-%%~nI.txt
)
IF ERRORLEVEL 1 SET el=135&&GOTO :endd
IF "%debug%"=="y" (
	ECHO lastchangesfilelong set to '%lastchangesfilelong%'
	ECHO thischangesfilelong set to '%thischangesfilelong%'
)
REM set log to short filename without quotes
IF "%debug%"=="y" ECHO log is '%log%'
SET loglong=%log%
FOR /F "usebackq delims=" %%I IN (`ECHO %log%`) DO SET log=%%~sI
IF ERRORLEVEL 1 SET el=136&&GOTO :endd
IF "%debug%"=="y" ECHO log redefined as '%log%'
REM set excludelist to short filename without quotes
IF "%excludelist%" NEQ "" FOR /F "usebackq delims=" %%I IN (`ECHO %excludelist%`) DO SET excludelist=%%~sI
IF ERRORLEVEL 1 SET el=137&&GOTO :endd
IF "%debug%"=="y" ECHO excludelist redefined as '%excludelist%'
REM change key variable to short-name form without quotes so we dont have to worry about quotes
FOR /F "usebackq delims=" %%I IN (`ECHO %key%`) DO SET key=%%~sI
IF ERRORLEVEL 1 SET el=138&&GOTO :endd
IF "%debug%"=="y" ECHO key redefined as '%key%'
REM set default basearchive if not already set
IF NOT DEFINED basearchive SET basearchive=/home/%user%/
REM add trailing slash to basearchive if required
IF "%basearchive:~-1%" NEQ "/" SET basearchive=%basearchive%/
IF ERRORLEVEL 1 SET el=139&&GOTO :endd
REM jump to restore code if appropriate
IF x%1x NEQ xx GOTO :restore-action
REM obtain today's date as variable mdy in mm-dd-yyyy format - locale independent
CALL :today_mdy
IF "%debug%" == "y" ECHO mdy is %mdy%
IF "%mdy%" == "" ECHO Error obtaining date in mm-dd-yyyy format&&SET el=16&&GOTO :endd
REM check for existence of volume shadowing services, if we might need them
IF ERRORLEVEL 1 SET el=105&&GOTO :endd
IF "%vss%" == "y" (
	IF "%debug%"=="y" ECHO About to check for vshadow-%VSHADOWVER%-%WINBIT%.exe
	CALL :file_check vshadow-%VSHADOWVER%-%WINBIT%.exe http://edgylogic.com/blog/vshadow-exe-versions %el%
	IF ERRORLEVEL 1 SET el=5&&GOTO :endd
	IF "%debug%"=="y" ECHO About to check for dosdev.exe
	CALL :file_check dosdev.exe http://www.ltr-data.se/files/dosdev.zip %el%
	IF ERRORLEVEL 1 SET el=5&&GOTO :endd
	IF %el% GEQ 1 (
		ECHO Backup will continue but with Volume Shadow Services disabled.
		SET vss=n
		SET el=0
	)
)
REM Determine primarysourcedrive by reference to backup sources, sticking with preset value if it is valid for any
IF "%debug%"=="y" SET /P dummy=Found source drives:<NUL
FOR /F "usebackq tokens=1,2,3* delims=," %%I IN (%TEMP%\%this%-datasets.txt) DO (
	FOR /F "usebackq tokens=1* delims=:" %%M IN (`ECHO %%I`) DO (
		IF "%debug%"=="y" SET /P dummy= %%M:<NUL
		IF /I x%%M:x==x%primarysourcedrive%x (SET sourceconfirmed=y) ELSE SET altsource=%%M:
	)
)
IF "%debug%"=="y" ECHO.
IF x%sourceconfirmed%x NEQ xyx (
	SET primarysourcedrive=%altsource%
	IF "%debug%"=="y" ECHO Altered primarysourcedrive to %altsource%
)
REM make sure that primarysourcedrive is a single letter and colon
SET primarysourcedrive=%primarysourcedrive:~0,1%:
IF "%debug%"=="y" ECHO Using VSS primarysourcedrive %primarysourcedrive%

IF "%debug%"=="y" ECHO About to process excludelist to adapt to Windows format
REM ---- Test whether the private key file can be found ----
REM note that the private key in plink.exe is used for authentication - the private key is not sent to the server, instead
REM a message signed with this private key is sent to the server, the server uses the public key - already stored in
REM authorized_keys - to verify that the message has come from the holder of the private key. This proves that the
REM client computer is indeed the holder of this private key and so a connection is granted. The host info is substituted
REM for %s - or %%s in a batch file - i.e. user@server
IF NOT EXIST %key% SET el=8&&ECHO Cannot find local key file '%key%'&&GOTO :endd
IF "%debug%"=="y" ECHO Found local Private Key %key%
REM ---- Test whether we can connect to the TimeDicer Server ----
SET el=9
ECHO @SET el=9 >%TEMP%\TimeDicer-testlink.bat
ECHO y|plink -P %port% -ssh -i %key% %user%@%server% "echo @SET el=0" >%TEMP%\TimeDicer-testlink.bat
CALL %TEMP%\TimeDicer-testlink.bat
IF %el% NEQ 0 ECHO Cannot make connection to %user%@%server%&&GOTO :endd
REM IF %quiet% == n ECHO Successfully connected to Server %server% as %user%
IF ERRORLEVEL 1 SET el=106&&GOTO :endd
REM ---- Test whether we can connect to a compatible rdiff-backup version ----
IF "%skip-rdiff-backup-test%"=="y" (
	IF "%debug%"=="y" ECHO Skipped testing rdiff-backup on remote server
) ELSE (
	IF "%debug%"=="y" (
		ECHO Using Private Key %key% and user %user%
		ECHO rdiff-backup-win.exe --test-server --remote-schema "plink.exe -P %port% -ssh -i %key% %%s rdiff-backup --server" C: %user%@%server%::"%basearchive%">nul
	)
	rdiff-backup-win.exe --test-server --remote-schema "plink.exe -P %port% -ssh -i %key% %%s rdiff-backup --server" C: %user%@%server%::"%basearchive%">nul
	IF ERRORLEVEL 1 (
		SET el=14
		ECHO Connected to %user%@%server% but could not make valid connection to rdiff-backup there&&GOTO :endd
	IF "%debug%"=="y" ECHO Found compatible rdiff-backup version at Server %server%
	)
)

REM ---- Change current drive ----
REM For reasons that are undocumented - but probably related to the location of
REM snapshot data - vshadow must be run with a local, or the snapshot source,
REM drive as the current drive on the command line. So we must switch to source
REM drive and ensure that all calls to external programs are mapped back to the
REM original location  - which may for instance be on a network share
SET runfrom=%CD%
REM switch to %TEMP% if on primarysourcedrive, otherwise to %primarysourcedrive%:\
CD %primarysourcedrive%\
CD %TEMP%
%primarysourcedrive%

REM ---- Test state of Volume Shadow Service Writers ----
REM for info about vshadow see http://msdn.microsoft.com/en-us/library/bb530725%28VS.85%29.aspx
IF /I "%vss%" == "y" (
	REM allowed status for shadow writers is 1 (stable) or 5 (waiting for completion) - see http://msdn.microsoft.com/en-us/library/aa384979%28VS.85%29.aspx
	"%runfrom%\vshadow-%VSHADOWVER%-%WINBIT%.exe" -ws|"%runfrom%\ssed.exe" -n -e "/Status: [^1|5]/p"|"%runfrom%\ssed.exe" -n "$=">%TEMP%\TimeDicer-vsswriters_status.txt
	FOR /F "usebackq" %%A IN ('%TEMP%\TimeDicer-vsswriters_status.txt') DO set VSSNOTREADY=%%~zA
	IF "!VSSNOTREADY!" NEQ "0" (
		ECHO Volume Shadow Writer[s] not ready, aborting...
		SET el=3
		GOTO :endd
	)
	IF ERRORLEVEL 1 SET el=107&&GOTO :endd
	REM IF %quiet% == n ECHO Volume Shadow Service is available and will be used
) ELSE (
	REM prevent any mapping if vss is off
	SET mapdrive=%primarysourcedrive%
	ECHO Volume Shadow Service will not be used
)
REM ---- Process excludelist to adapt from Windows to Linux format ----
IF "x%excludelist%" NEQ "x" (
	IF NOT EXIST "%excludelist%" SET el=4&&ECHO Cannot find excludelist file '%excludelist%'&&GOTO :endd
	REM expand env variables in excludelist
	CALL :expand "%excludelist%" "%TEMP%\timedicer-excludelist1.txt"
	REM set exclude filename/path in linuxed form, note the additional space at the end
	SET exclude=--exclude-globbing-filelist %TEMP:\=/%/timedicer-excludelist.txt 
	REM create exclude file so that it holds data in suitable linuxed form
	REM /^^#/d - delete: exclude comment lines
	REM /^^$/d - delete: exclude blank lines
	REM s/^%primarysourcedrive%/%mapdrive%/i - change refs from C: to mapped drive
	REM /^[A-Za-z]:/!s/^/**/; - prefix ** but only if it doesn't start with drive letter
	REM s/^/ignorecase:/ - prefix ignorecase:
	REM s/\\/\//g - substitute: switch any \ to / - and g means repeat action
	REM s/$/**/ - substitute: suffix **
	SETLOCAL DISABLEDELAYEDEXPANSION
	if "%debug%"=="y" ECHO "/^#/d;/^$/d;s/^%primarysourcedrive%/%mapdrive%/i;/^[A-Za-z]:/!s/^/**/;s/^/ignorecase:/;s/\\/\//g;s/$/**/"
	"%runfrom%\ssed.exe" "/^#/d;/^$/d;s/^%primarysourcedrive%/%mapdrive%/i;s/^/ignorecase:**/;s/\\/\//g;s/$/**/" "%TEMP%\timedicer-excludelist1.txt" >"%TEMP%\timedicer-excludelist.txt"
	SETLOCAL ENABLEEXTENSIONS ENABLEDELAYEDEXPANSION
)
IF ERRORLEVEL 1 SET el=114&&ECHO Error using ssed to create %TEMP%\timedicer-excludelist.txt&&GOTO :endd

IF NOT EXIST "%MYAPPDATA%" MKDIR "%MYAPPDATA%" 2>nul
IF ERRORLEVEL 1 SET el=108&&ECHO Error creating %MYAPPDATA%&&GOTO :endd
SET log1=%TEMP%\timedicer-log1.txt
SET log2=%TEMP%\timedicer-log2.txt
REM ---- %this%-action.bat script creation ----
REM This script will shortly be run by vshadow
IF "%debug%"=="y" ECHO Start creating script %TEMP%\%this%-action.bat
SETLOCAL ENABLEEXTENSIONS DISABLEDELAYEDEXPANSION
ECHO @ECHO OFF>%TEMP%\%this%-action.bat
ECHO SETLOCAL ENABLEEXTENSIONS ENABLEDELAYEDEXPANSION>>%TEMP%\%this%-action.bat
IF /I "%vss%" == "y" (
	ECHO REM map the shadow device to drive %mapdrive%>>%TEMP%\%this%-action.bat
	ECHO call %TEMP%\TimeDicer-vss-setvar.cmd>>%TEMP%\%this%-action.bat
	ECHO "%runfrom%\dosdev" %mapdrive% %%SHADOW_DEVICE_1%% 2^>nul>>%TEMP%\%this%-action.bat
)
ECHO FOR /F "usebackq tokens=1,2,3* delims=," %%%%I IN ^(%TEMP%\%this%-datasets.txt^) DO ^(>>%TEMP%\%this%-action.bat
ECHO 	REM must set non-blank extraparams here to prevent ERRORLEVEL 1 when it is set to blank>>%TEMP%\%this%-action.bat
ECHO 	SET extraparams=x>>%TEMP%\%this%-action.bat
REM 	unixify source [first field:%%I] on current line in list file, fix any drive ref and set as !source!, also unixify parameters [%%K]
ECHO 	FOR /F "usebackq tokens=1,2* delims=£" %%%%M IN ^(`ECHO %%%%I£%%%%K^^^|"%runfrom%\ssed.exe" -e s/%primarysourcedrive%/%mapdrive%/gi -e s@\\@/@g`^) DO SET source=%%%%M^&IF x%%%%Kx NEQ xx ^(SET extraparams=%%%%N^) ELSE SET extraparams=>>%TEMP%\%this%-action.bat
ECHO 	REM For xcopy, set xcopysource to expanded %%%%I>>%TEMP%\%this%-action.bat
ECHO 	FOR /F "usebackq tokens=1* delims=?" %%%%W IN (`ECHO %%%%I`) DO SET xcopysource=%%%%W>>%TEMP%\%this%-action.bat
IF /I "%vss%" == "y" (
	ECHO 	REM For xcopy, set xcopydestination to expanded %%%%I mapped to VSS drive>>%TEMP%\%this%-action.bat
	ECHO 	FOR /F "usebackq tokens=1* delims=?" %%%%W IN ^(`ECHO %%%%I^^^|"%runfrom%\ssed.exe" -e s/%primarysourcedrive%/%mapdrive%/gi`^) DO SET xcopydestination=%%%%W>>%TEMP%\%this%-action.bat
) ELSE (
	ECHO	REM Not using VSS, xcopy will fail if xcopysource is C:\,>>%TEMP%\%this%-action.bat
	ECHO	REM but we have no other drive guaranteed to exist>>%TEMP%\%this%-action.bat
	ECHO 	SET xcopydestination=C:\>>%TEMP%\%this%-action.bat
)
IF "%debug%" == "y" ECHO 	ECHO xcopysource is !xcopysource!, xcopydestination is !xcopydestination!^>CON>>%TEMP%\%this%-action.bat
ECHO 	IF NOT EXIST "!source!" ECHO Skipping %action% non-existent !source!>>%TEMP%\%this%-action.bat
ECHO 	IF EXIST "!source!" ^(>>%TEMP%\%this%-action.bat
ECHO 		ECHO %action% %%%%I to %%%%J>>%TEMP%\%this%-action.bat
IF %quiet% == n ECHO 		ECHO %action% %%%%I to %%%%J^>CON>>%TEMP%\%this%-action.bat
ECHO 		ECHO.^>^>%log2%>>%TEMP%\%this%-action.bat
ECHO 		ECHO %action% %%%%I to %%%%J:^>^>%log2%>>%TEMP%\%this%-action.bat
ECHO 		SET filecount=999>>%TEMP%\%this%-action.bat
ECHO 		REM decide whether to skip the checking of whether files have changed in this archive since last run>>%TEMP%\%this%-action.bat
ECHO 		SET DONTCHECKFORFILECHANGES=N>>%TEMP%\%this%-action.bat
ECHO 		REM skip checking if doing a compare run>>%TEMP%\%this%-action.bat
ECHO 		IF "%compare%" NEQ "" SET DONTCHECKFORFILECHANGES=Y>>%TEMP%\%this%-action.bat
ECHO 		REM skip checking if skip_on_no_change is not y>>%TEMP%\%this%-action.bat
ECHO 		IF /I "%skip_on_no_change%" NEQ "y" SET DONTCHECKFORFILECHANGES=Y>>%TEMP%\%this%-action.bat
ECHO 		REM skip checking if there are additional parameters cos xcopy cant reliably identify whether files have changed>>%TEMP%\%this%-action.bat
ECHO 		IF "%%%%K" NEQ "" SET DONTCHECKFORFILECHANGES=Y>>%TEMP%\%this%-action.bat
REM ECHO 		ECHO DONTCHECKFORFILECHANGES is ^!DONTCHECKFORFILECHANGES^!, skip_on_no_change is %skip_on_no_change%^>CON>>%TEMP%\%this%-action.bat
ECHO 		REM skip checking if no file recording last successful update>>%TEMP%\%this%-action.bat
ECHO 		IF NOT EXIST "%lastchangesfilelong%" SET DONTCHECKFORFILECHANGES=Y>>%TEMP%\%this%-action.bat
ECHO 		IF "!DONTCHECKFORFILECHANGES!"=="N" (>>%TEMP%\%this%-action.bat
REM IF %quiet% == n ECHO 			ECHO Checking to see if any files have changed since last backup...^>CON>>%TEMP%\%this%-action.bat
ECHO 			REM now examine %lastchangesfilelong%>>%TEMP%\%this%-action.bat
ECHO 			FOR /F "usebackq tokens=1,2* delims=," %%%%R IN ^("%lastchangesfilelong%"^) DO ^(>>%TEMP%\%this%-action.bat
ECHO 				IF "%%%%R,%%%%S"=="!xcopysource!,%%%%J" ^(>>%TEMP%\%this%-action.bat
ECHO 					REM if found matching entry in %lastchangesfilelong% use xcopy to check for changes to it on or after the last backup date>>%TEMP%\%this%-action.bat
ECHO 					FOR /F "tokens=1" %%%%U IN ^('xcopy ^^^"!xcopysource!\*^^^" ^^^"!xcopydestination!^^^" /d:%%%%T /leqhry /exclude:%excludelist%'^) DO SET filecount=%%%%U>>%TEMP%\%this%-action.bat
ECHO 					IF ERRORLEVEL 1 SET filecount=999>>%TEMP%\%this%-action.bat
ECHO 					REM this records the previous copy date in the current this_success_date file because there will be no update>>%TEMP%\%this%-action.bat
ECHO 					IF !filecount!==0 ECHO !xcopysource!,%%%%J,%%%%T^>^>"%thischangesfilelong%">>%TEMP%\%this%-action.bat
ECHO 					ECHO !filecount! new or changed files since %%%%T 00:00^>^>%log2% ^2^>^>^&^1>>%TEMP%\%this%-action.bat
ECHO 				^)>>%TEMP%\%this%-action.bat
ECHO 			^)>>%TEMP%\%this%-action.bat
REM ECHO 			IF !filecount! EQU 999 ECHO No entry found in %lastchangesfilelong% - so backup will proceed^>^>%log2%>>%TEMP%\%this%-action.bat
ECHO 		^)>>%TEMP%\%this%-action.bat
ECHO 		IF !filecount! GTR 0 ^(>>%TEMP%\%this%-action.bat
IF %quiet% == n ECHO 			IF !filecount! NEQ 999 ECHO !filecount! new or changed files, so backup is proceeding...^>CON>>%TEMP%\%this%-action.bat
IF %quiet% == n ECHO 			IF !filecount! EQU 999 ECHO Unable to confirm that no files have changed, so backup is proceeding...^>CON>>%TEMP%\%this%-action.bat
ECHO 			IF !filecount! EQU 999 ECHO Unable to confirm that no files have changed, so backup is proceeding...^>^>%log2%>>%TEMP%\%this%-action.bat
ECHO 			SET rdiff_command_line="%runfrom%\rdiff-backup-win.exe" %compare% --create-full-path --no-hard-links --print-statistics --remote-schema "plink.exe -P %port% -ssh -i %key% %%%%%%%%s rdiff-backup --server" !extraparams! %options% %exclude%"!source!" %user%@%server%::"%basearchive%%%%%J"^^^>^^^>%log2% 2^^^>^^^>^^^&^^^1>>%TEMP%\%this%-action.bat
ECHO 			REM create and the call -action2.bat file>>%TEMP%\%this%-action.bat
REM note this line will start creation of new %TEMP%\%this%-action2.bat
ECHO 			ECHO ECHO %action% source: !rdiff_command_line!^>%TEMP%\%this%-action2.bat>>%TEMP%\%this%-action.bat
IF "%test%" NEQ "y" ECHO 			ECHO !rdiff_command_line!^>^>%TEMP%\%this%-action2.bat>>%TEMP%\%this%-action.bat
ECHO 			ECHO IF NOT ERRORLEVEL 1 ^^(ECHO %%%%I,%%%%J,%mdy%^^^>^^^>"%thischangesfilelong%" ^^^2^^^>^^^>^^^&^^^1^^) ELSE EXIT /B %%%%ERRORLEVEL%%%%^>^>%TEMP%\%this%-action2.bat>>%TEMP%\%this%-action.bat
ECHO 			CALL %TEMP%\%this%-action2.bat^>^>%TEMP%\%this%-action2-out1.txt 2^>^>%TEMP%\%this%-action2-out2.txt>>%TEMP%\%this%-action.bat
ECHO 			SET ACTIONERR=!ERRORLEVEL!>>%TEMP%\%this%-action.bat
IF "%test%" NEQ "y" (
	ECHO 			REM Pause for n milliseconds, so we can write to log file without error>>%TEMP%\%this%-action.bat
	IF "%debug%" == "y" ECHO 			ECHO About to call     PING^>CON>>%TEMP%\%this%-action.bat
	ECHO 			PING 10.255.255.254 -n 1 -w 8000 ^>NUL ^2^>^&^1>>%TEMP%\%this%-action.bat
	IF "%debug%" == "y" ECHO 			ECHO Completed call to PING^>CON>>%TEMP%\%this%-action.bat
	ECHO 			REM Clear ERRORLEVEL that will be set by the PING^>NUL>>%TEMP%\%this%-action.bat
	ECHO 			VERIFY^>NUL>>%TEMP%\%this%-action.bat
	IF "%debug%" == "y" ECHO 			ECHO Cleared ERRORLEVEL^>CON>>%TEMP%\%this%-action.bat
)
ECHO 			IF !ACTIONERR! GTR 0 ^(>>%TEMP%\%this%-action.bat
ECHO 				ECHO SET ACTIONERR=30^>%TEMP%\%this%-action-err.bat^&^&ECHO Error 30 occurred with %action% %%%%I to %%%%J^>^>%log2%>>%TEMP%\%this%-action.bat
IF /I "%vss%" EQU "y" (
ECHO 				ECHO Error 30 occurred with %action% %%%%I to %%%%J^>CON>>%TEMP%\%this%-action.bat
)
ECHO 			^)>>%TEMP%\%this%-action.bat
IF "%debug%" == "y" ECHO 			ECHO Completed         %TEMP%\%this%-action2.bat^>CON>>%TEMP%\%this%-action.bat
ECHO 		^) ELSE ^(>>%TEMP%\%this%-action.bat
ECHO 			ECHO Skipped because no source files have changed^>^>%log2%>>%TEMP%\%this%-action.bat
IF %quiet% == n ECHO 			ECHO Skipped because no source files have changed^>CON>>%TEMP%\%this%-action.bat
ECHO 		^)>>%TEMP%\%this%-action.bat
IF "%debug%" == "y" ECHO 		ECHO About to write to %log2%^>CON>>%TEMP%\%this%-action.bat
ECHO 		ECHO Completed %action% %%%%I to %%%%J !DATE! !TIME!^>^>%log2% 2^>^>NUL>>%TEMP%\%this%-action.bat
IF %quiet% == n ECHO 		ECHO.^>CON>>%TEMP%\%this%-action.bat
ECHO 	^)>>%TEMP%\%this%-action.bat
ECHO ^)>>%TEMP%\%this%-action.bat
IF /I "%vss%" == "y" (
	ECHO REM delete shadow device drive mapping>>%TEMP%\%this%-action.bat
	ECHO "%runfrom%\dosdev" -r -d %mapdrive% 2^>nul>>%TEMP%\%this%-action.bat
)
ENDLOCAL
IF "%debug%"=="y" ECHO End creating script %TEMP%\%this%-action.bat
REM ---- Tidy up before starting the volume shadowing and backup ----
REM delete any existing shadow copies  - there should not normally be any, but can be if a previous backup failed
IF /I "%vss%" == "y" (
	IF ERRORLEVEL 1 SET el=109&&GOTO :endd
	IF "%debug%"=="y" ECHO About to delete any existing shadow copies
	ECHO y|"%runfrom%\vshadow-%VSHADOWVER%-%WINBIT%.exe" -da>nul
	IF ERRORLEVEL 1 (
		IF "%debug%"=="y" ECHO Error occurred: testing for administrator permissions
		MKDIR "%windir%\system32\test" 2>nul
		IF ERRORLEVEL 1 (
			REM not running as administrator, this is cause of failure
			IF "%debug%"=="y" ECHO No administrator permissions
			SET /A el=11
		) ELSE (
			REM running as administrator, there is a problem with vshadow
			RMDIR "%windir%\system32\test"
			SET /A el=7
		)
		GOTO :endd
	)
	IF "%debug%"=="y" ECHO Deleted any existing shadow copies
)

REM delete any this_success_date file - should not be one unless a previous run ended prematurely
IF EXIST "%thischangesfilelong%" (
	DEL "%thischangesfilelong%">nul 2>nul
	IF ERRORLEVEL 1 SET el=101&&ECHO Error deleting old success date file&&GOTO :endd
)

IF "%debug%" == "y" (
	ECHO About to do backup run
	IF "%exitnow%" NEQ "y" PAUSE
)
REM delete any existing log files
IF EXIST "%log2%" DEL "%log2%" 2>nul
IF ERRORLEVEL 1 SET el=110&&ECHO Error deleting old log file %log2%&&GOTO :endd
REM ---- Do the backup ----
IF EXIST %TEMP%\%this%-action-err.bat DEL %TEMP%\%this%-action-err.bat>NUL
SET ACTIONERR=0
IF %quiet% == n (ECHO %action% selected locations is now commencing&ECHO.)
IF /I "%vss%" EQU "y" (
	ECHO %action% %primarysourcedrive% ^(as %mapdrive%^) started %DATE% %TIME%>%log1%
	ECHO.>>%log1%
	ECHO Summary ^(details follow further below^):>>%log1%
) ELSE (
	ECHO %action% %primarysourcedrive% ^(without VSS^) started %DATE% %TIME%>%log1%
)
IF /I "%vss%" == "y" (
	IF ERRORLEVEL 1 SET el=111&&GOTO :endd
	REM ---- Run vshadow, which will create shadow copy, run %this%-action.bat, then delete shadow copy ----
	IF "%debug%" == "y" ECHO About to run '%this%-action.bat' in VSS mode
	"%runfrom%\vshadow-%VSHADOWVER%-%WINBIT%.exe" -script=%TEMP%\TimeDicer-vss-setvar.cmd -exec=%TEMP%\%this%-action.bat %primarysourcedrive%>>"%log1%"
	IF ERRORLEVEL 1 SET /A el=%ERRORLEVEL%+20
	IF "%debug%" == "y" ECHO Returned from running '%this%-action.bat' in VSS mode
) ELSE (
	IF ERRORLEVEL 1 SET el=112&&GOTO :endd
	IF "%debug%" == "y" ECHO About to run '%this%-action.bat' in non-VSS mode
	CALL %TEMP%\%this%-action.bat
	IF ERRORLEVEL 1 SET el=%ERRORLEVEL%
	IF "%debug%" == "y" ECHO Returned from running '%this%-action.bat' in non-VSS mode
)
IF EXIST %TEMP%\%this%-action-err.bat (CALL %TEMP%\%this%-action-err.bat) ELSE SET /A el=13
IF "%debug%" == "y" ECHO ACTIONERR is '%ACTIONERR%'
SET /A el=%ERRORLEVEL%+%ACTIONERR%
REM Clear the ERRORLEVEL
VERIFY>NUL
IF %quiet% == n ECHO %action% selected locations completed

REM ---- Tidy up after backup run ----
REM IF %quiet% == n ECHO Details follow below:>>%log1%
REM remove all the VSHADOW stuff which we are not interested in
IF "%debug%" == "y" ECHO el is '%el%'
IF EXIST %log1% (
	IF "%el%" EQU "0" (
		IF ERRORLEVEL 1 SET el=113&&GOTO :endd	
		IF "%debug%" == "y" ECHO About to modify '%log1%'
		COPY /Y /A %log1% %log1%x>NUL 2>&1
		"%runfrom%\ssed.exe" "4,6d;/^VSHADOW.EXE/,/Snapshot creation done/d" %log1%x>%log1%
		IF "%debug%" == "y" ECHO Modified '%log1%'
		IF ERRORLEVEL 1 SET el=102&&GOTO :endd
	)
)
IF "%debug%" == "y" ECHO About to combine logs
REM COPY %log1% + %log2% %log%>nul
COPY %log1% %log%>nul
TYPE %log2%>>%log%
SET logbuilt=y
IF "%debug%" NEQ "y" (
	IF "%el%" EQU "0" (
		REM undocumented option 'SET retaintempfiles=Y' retains temporary files
		IF "%retaintempfiles%" EQU "" (
			IF EXIST "%TEMP%\TimeDicer*.*" DEL /Q "%TEMP%\TimeDicer*.*" 1>nul 2>&1
		)
	)
)


REM run archfs.sh on remote server, which will load/update/delete archfs virtual filesystem
REM this requires bash to be the default shell on the server, and will fail silently if /opt/archfs.sh is not found

REM IF "%debug%" == "y" ECHO Consider archfs mount: compare is %compare%, view is %view%, archfs is %archfs%...
REM IF "%compare%" EQU "" (
REM 	IF "%archfs%" NEQ "n" (
REM 		ECHO Mounting of remote views at ~/timediced started %DATE% %TIME%>>%log%
REM 		ECHO Mounting of remote views at ~/timediced started %DATE% %TIME%
REM 		%runfrom%\plink -ssh -i %key% %user%@%server% "if [ -f /opt/archfs.sh ]; then /opt/archfs.sh -d %archfs% %basearchive%; fi">>%log%
REM 		IF ERRORLEVEL 1 SET el=6
REM 	)
REM )
REM IF "%compare%" EQU "" (
REM 	IF "%archfs%" NEQ "n" (
REM 		ECHO Mounting of remote views at ~/timediced completed %DATE% %TIME%>>%log%
REM 		ECHO Mounting of remote views at ~/timediced completed %DATE% %TIME%
REM 	)
REM )

REM ---- Ending ----
REM if doing a compare run then show the result
IF "%compare%" NEQ "" TYPE %log%
:endd
IF "%debug%" == "y" ECHO Reached endd stage
IF "%debug%" == "y" ECHO "%%compare%%1%%test%%2%%restore%%" is "%compare%1%test%2%restore%"
IF "%compare%1%test%2%restore%" == "12" (
	IF EXIST "%thischangesfilelong%" (
		IF "%debug%" == "y" ECHO Found %thischangesfilelong%
		REM any datasets missing from this (e.g. temporarily edited out) but found in last are added back to this
		IF EXIST "%lastchangesfilelong%" (
			IF "%debug%" == "y" ECHO About to add back missing datasets in %thischangesfilelong%
			FOR /F "usebackq tokens=1-3* delims=," %%I IN ("%lastchangesfilelong%") DO (
				SET FOUND=N
				FOR /F "usebackq tokens=1-3* delims=," %%L IN ("%thischangesfilelong%") DO IF %%I%%J==%%L%%M SET FOUND=Y
				IF ERRORLEVEL 1 SET el=115&&GOTO :endd
				REM ECHO %%J !FOUND! FOUND
				IF !FOUND!==N ECHO %%I,%%J,%%K>>"%thischangesfilelong%"
			)
			IF "%debug%" == "y" ECHO About to delete %lastchangesfilelong%
			DEL "%lastchangesfilelong%">nul 2>&1
			IF ERRORLEVEL 1 SET el=116&&GOTO :endd
		)
		REM rename the new success_date file as the last one
		FOR %%I IN ("%lastchangesfilelong%") DO SET lastchangesfilename=%%~nxI
		IF "%debug%" == "y" ECHO About to rename %thischangesfilelong% as !lastchangesfilename!
		REN "%thischangesfilelong%" "!lastchangesfilename!"
		IF ERRORLEVEL 1 SET el=117&&GOTO :endd
		IF "%debug%" == "y" ECHO Renamed %thischangesfilelong%
	)
)
:end1
IF %quiet% == n (
	IF %el% GEQ 1 (
		IF "%ACTIONERR%" EQU "30" (
			ECHO %~n0 v%ver% failed with error %el% relating to dataset^(s^):
			"%runfrom%\ssed.exe" -n "/Error 30/s/.*to /    /p" %log%
		) ELSE (
			CALL :errortext %el%
			ECHO %~n0 v%ver% failed with error %el%: !ERRORTEXT!
		)
		REM ECHO For more info run %~n0 /h, or visit %homepage%/timedicer-man.html
	) ELSE (
		IF ERRORLEVEL 1 (
			ECHO %~n0 v%ver% failed with Errorlevel %ERRORLEVEL%
			SET el=%ERRORLEVEL%
			IF %el% == 2 ECHO Check if drive %primarysourcedrive% is formatted with FAT32. If so, convert it to NTFS or add&&ECHO SET vss=n to your configuration file
			ECHO For more info run %~n0 /h, or visit %homepage%/timedicer-man.html
		) ELSE (
			ECHO %~n0 completed without errors at %DATE% %TIME%
			REM save the current date so it can be picked up next time
			REM ECHO %mdy%>"%this%-%user%-last_success_date.txt"
		)
	)
)
IF %quiet% == n (IF x%logbuilt%x NEQ xx ECHO Log at %loglong%)
REM Restore the original command line path
:end2
IF /I "%startpath%" NEQ "" CD /D %startpath%
IF NOT "%exitnow%" == "y" PAUSE
EXIT /B %el%
REM ---- Ended ----

:restore-action
REM this is used for listing versions of a file and for restoring a file
REM %2 and %3 only used for restoring a file
IF "%debug%"=="y" ECHO Running restore code: params 1:%1: 2:%2: 3:%3:
SET exitnow=y
IF "%2" NEQ "" (SET when=%2) ELSE SET when=0D
IF "%3" NEQ "" (FOR %%I in (%~3) DO SET destfolder=%%~sI\) ELSE SET destfolder=%TEMP%
SET file=%1
FOR %%I in (%1) DO SET filepath=%%~dpI&& SET file=%%~nxI
SET filepath=%filepath:~0,-1%
REM we have to expand env variables inside configuration file
REM this is a kludge so that %USERPROFILE% at least is expanded
COPY /A /Y %TEMP%\%this%-datasets.txt %TEMP%\%this%-datasets2.txt>NUL 2>&1
SET escapeduserprofile=%USERPROFILE%
CALL :escaped escapeduserprofile
ssed "s/%%USERPROFILE%%/%escapeduserprofile%/g" %TEMP%\%this%-datasets2.txt>%TEMP%\%this%-datasets.txt
IF "%debug%"=="y" ECHO Reached point p
FOR /F "tokens=1-9* delims=\" %%A IN ("%filepath%") DO (
	IF "%%A" NEQ "" SET filepatha=%%A&&SET SUBF=1
	IF "%%B" NEQ "" SET filepathb=%%A\%%B&&SET SUBF=2
	IF "%%C" NEQ "" SET filepathc=%%A\%%B\%%C&&SET SUBF=3
	IF "%%D" NEQ "" SET filepathd=%%A\%%B\%%C\%%D&&SET SUBF=4
	IF "%%E" NEQ "" SET filepathe=%%A\%%B\%%C\%%D\%%E&&SET SUBF=5
	IF "%%F" NEQ "" SET filepathf=%%A\%%B\%%C\%%D\%%E\%%F&&SET SUBF=6
	IF "%%G" NEQ "" SET filepathg=%%A\%%B\%%C\%%D\%%E\%%F\%%G&&SET SUBF=7
	IF "%%H" NEQ "" SET filepathh=%%A\%%B\%%C\%%D\%%E\%%F\%%G\%%H&&SET SUBF=8
	IF "%%I" NEQ "" SET filepathi=%%A\%%B\%%C\%%D\%%E\%%F\%%G\%%H\%%I&&SET SUBF=9
)
SET RepoLevel=%SUBF%
:loopback
IF "%debug%"=="y" ECHO Reached point q, RepoLevel %RepoLevel%
IF %RepoLevel%==0 SET el=17&GOTO :end1
IF %RepoLevel%==9 CALL :P   "%filepathi%"
IF %RepoLevel%==8 CALL :P   "%filepathh%"
IF %RepoLevel%==7 CALL :P   "%filepathg%"
IF %RepoLevel%==6 CALL :P   "%filepathf%"
IF %RepoLevel%==5 CALL :P   "%filepathe%"
IF %RepoLevel%==4 CALL :P   "%filepathd%"
IF %RepoLevel%==3 CALL :P   "%filepathc%"
IF %RepoLevel%==2 CALL :P   "%filepathb%"
IF %RepoLevel%==1 CALL :P   "%filepatha%"
IF "%repo%" EQU "" SET /A RepoLevel=RepoLevel-1&&GOTO :loopback
FOR /F "tokens=%RepoLevel%* delims=\" %%A IN ("%filepath%") DO SET SubFolders=%%B
IF "%debug%"=="y" ECHO Reached point r
REM unixify directory separators in SubFolders, if any
IF "x%SubFolders%x" NEQ "xx" SET SubFolders=%SubFolders:\=/%
REM ECHO repo is %repo%, RepoLevel is %RepoLevel%, SubFolders is %SubFolders%, file is %file%
REM ECHO ON
REM (use GOTOs because nesting in an IF screws it up)
IF "%debug%"=="y" ECHO Reached point x, repo is '%repo%', SubFolders is '%SubFolders%'
IF "%restore%" NEQ "" (
	REM restore file
	if "%debug%"=="y" ECHO rdiff-backup %overwrite% --no-eas --no-acls --no-hard-links -r %when% --remote-schema "plink.exe -P %port% -ssh -i %key% %%s rdiff-backup --server" "%user%@%server%::%basearchive%%repo%/%SubFolders%/%file%" "%destfolder%\%file%"
	rdiff-backup %overwrite% --no-eas --no-acls --no-hard-links -r %when% --remote-schema "plink.exe -P %port% -ssh -i %key% %%s rdiff-backup --server" "%user%@%server%::%basearchive%%repo%/%SubFolders%/%file%" "%destfolder%\%file%"
) ELSE (
	REM retrieve list from server
	IF "%debug%"=="y" (
		ECHO Retrieving list by doing:
		ECHO plink -P %port% -ssh -i %key%  "%user%@%server%" "find /home/%user%/%basearchive%%repo%/\"%SubFolders%\" -maxdepth 1 -mindepth 1 -name \"%file%\" -printf %%T+Z\\n|sed 's/+/ /;s/\.0*//'>~/%repo%.txt;find /home/%user%/%basearchive%%repo%/rdiff-backup-data/increments/\"%SubFolders%\" -name \"%file%.*.diff.gz\"|sed 's/.*\.\([1-2][0-9]\{3\}-[0-1][0-9]-[0-5][0-9]T.*\)\.diff\.gz/\1/;s/T/ /'|sort -r|cat ~/%repo%.txt -"
	)
	plink -P %port% -ssh -i %key%  "%user%@%server%" "find /home/%user%/%basearchive%%repo%/\"%SubFolders%\" -maxdepth 1 -mindepth 1 -name \"%file%\" -printf %%T+Z\\n|sed 's/+/ /;s/\.0*//'>~/%repo%.txt;find /home/%user%/%basearchive%%repo%/rdiff-backup-data/increments/\"%SubFolders%\" -name \"%file%.*.diff.gz\"|sed 's/.*\.\([1-2][0-9]\{3\}-[0-1][0-9]-[0-5][0-9]T.*\)\.diff\.gz/\1/;s/T/ /'|sort -r|cat ~/%repo%.txt -"
REM	plink -P %port% -ssh -i %key%  "%user%@%server%" "find /home/%user%/%basearchive%%repo%/\"%SubFolders%\" -maxdepth 1 -mindepth 1 -name \"%file%\" -printf %%T+Z\\n|sed 's/+/ /;s/\.0*//'>~/%repo%.txt;find /home/%user%/%basearchive%%repo%/rdiff-backup-data/increments/\"%SubFolders%\" -regex /home/%user%/%basearchive%%repo%/rdiff-backup-data/increments/\"%SubFolders%\"\"%file%\.[^.]*\.di\(ff.gz\|r\)\"|sed 's/.*\.\([1-2][0-9]\{3\}-[0-1][0-9]-[0-5][0-9][T ].*\)\./\1/;s/T/ /;s/dir$//;s/diff.gz//'|sort -r|cat ~/%repo%.txt -"
REM find /home/dominic-pcchips2/archives/mydocs/rdiff-backup-data/increments -regex "/home/dominic-pcchips2/archives/mydocs/rdiff-backup-data/increments/G-Docs\.[^.]*\.di\(ff.gz\|r\)"|sed 's/.*\.\([1-2][0-9]\{3\}-[0-1][0-9]-[0-5][0-9][T ].*\)\./\1/;s/T/ /;s/dir$//;s/diff.gz//'

)
IF ERRORLEVEL 1 SET el=18
GOTO :end1
:P  
REM see if the path exists as a source in the configuration file, if so return the repo
SET escapedfilepath=%~1
IF "%debug%"=="y" ECHO Escaping: %escapedfilepath%
CALL :escaped escapedfilepath
IF "%debug%"=="y" ECHO Result  : %escapedfilepath%
FOR /F "usebackq tokens=2 delims=," %%Z IN (
  `ssed.exe -n "/^%escapedfilepath%,/Ip" %TEMP%\%this%-datasets.txt`
) DO SET repo=%%Z
GOTO :EOF

:mapdrive
REM A or B can give 'drive not ready' messages, and we ignore C because it is never available, right?
REM on some systems 'drive not ready' messages occur with other drive letters D-G, prob empty DVD drives etc.
REM the strategy here is first to try W->P, then X->Z, then mid-letters O->I. Surely one will be available?
PUSHD & FOR %%i IN (W V U T S R Q P Z Y X O N M L K J I) DO ( %%i 2>nul || ( SET mapdrive=%%i:&POPD&EXIT /B 0 ) )
REM if we got here then X: shouldn't work, but let's try it anyway
SET mapdrive=X:
GOTO :EOF
:escaped
:: Subroutine to double-escape a string so C:\Folder becomes C:\\Folder etc
IF "%1" EQU "" GOTO :EOF
FOR %%i IN ("\=\\") DO CALL SET "%1=%%%1:%%~i%%"
GOTO :EOF
:expand
:: Subroutine to expand environment variables in a file
::  2 params: 1st is source file, 2nd is dest file
IF EXIST "%~2" DEL "%~2"
FOR /F "delims=" %%i IN (%~1) DO CALL :expand1 "%%i" "%~2"
GOTO :EOF
:expand1
ECHO %~1>>"%~2"
GOTO :EOF
:file_check
IF NOT EXIST "%~1" (
	SET /A el=%3+1
	ECHO  	%1 could not be found: get it from %~2
)
GOTO :eof
:param_check
REM call as e.g. CALL :param2check q %1 %2 %3 %4 where /q or -q is the param looked for
REM (not case sensitive). If param is found then on return param holds the parameter position, o/wise 0
REM the next parameter is put into nextparam (useful for /c [text])
REM Note that VERIFY>NUL is used to ensure that no errors are returned. SHIFT
REM can result in unpredictable errors which may (or may not) occur later in
REM the routine when referencing non-existent parameters.
IF "%debug%" == "y" ECHO %0 %*
SET parloop=1
SET param=0
:param_loop
IF {%2}=={} VERIFY>NUL&GOTO :eof
IF /I {%2}=={/%1} SET /A param=parloop
IF /I {%2}=={-%1} SET /A param=parloop
SHIFT /2
IF NOT %param%==0 SET nextparam=%2&VERIFY>NUL&GOTO :eof
SET /A parloop=parloop+1
GOTO :param_loop
:lower_case
REM converts variable passed to it on command line to lower case, also strips
REM any quotes and any spaces. The returned value is in variable lcase
IF "%debug%" == "y" ECHO %0 %*
SET lcase=%1
SET lcase=%lcase:"=%
SET lcase=%lcase:A=a%
SET lcase=%lcase:B=b%
SET lcase=%lcase:C=c%
SET lcase=%lcase:D=d%
SET lcase=%lcase:E=e%
SET lcase=%lcase:F=f%
SET lcase=%lcase:G=g%
SET lcase=%lcase:H=h%
SET lcase=%lcase:I=i%
SET lcase=%lcase:J=j%
SET lcase=%lcase:K=k%
SET lcase=%lcase:L=l%
SET lcase=%lcase:M=m%
SET lcase=%lcase:N=n%
SET lcase=%lcase:O=o%
SET lcase=%lcase:P=p%
SET lcase=%lcase:Q=q%
SET lcase=%lcase:R=r%
SET lcase=%lcase:S=s%
SET lcase=%lcase:T=t%
SET lcase=%lcase:U=u%
SET lcase=%lcase:V=v%
SET lcase=%lcase:W=w%
SET lcase=%lcase:X=x%
SET lcase=%lcase:Y=y%
SET lcase=%lcase:Z=z%
SET lcase=%lcase: =%
GOTO :eof
:today_mdy
REM by REMS from http://www.petri.co.il/forums/showthread.php?t=19445
REM Should work with all normal short date formats that use numeric values only and do not begin with the year.
REM Will also work with formats that precede the date with dayofweek
ECHO. | date | FIND "(mm" > NUL
IF ERRORLEVEL 1 (CALL :Parsedate DD MM) ELSE (CALL :Parsedate MM DD)
VERIFY>NUL
GOTO :EOF
:Parsedate
FOR /F "tokens=1-4 delims=/.- " %%A IN ('date /t') DO IF %%D!==! (
	     SET %1=%%A&SET %2=%%B&SET YYYY=%%C
	) else (
	     SET DOW=%%A&SET %1=%%B&SET %2=%%C&SET YYYY=%%D
	)
)
REM ECHO %MM%-%DD%-%YYYY%
SET mdy=%MM%-%DD%-%YYYY%
GOTO :EOF
:errortext
SET ERRORTEXT=
IF e%1==e1 SET ERRORTEXT=failure at second call of vshadow
IF e%1==e2 SET ERRORTEXT=unable to access mapped drive - ensure source drive is formatted with NTFS or use vss=n
IF e%1==e3 SET ERRORTEXT=Windows Volume Shadow Services not operating correctly - if it has worked on this machine before, try rebooting, otherwise do Start/Run services.msc and check for Volume Shadow Copy which should be started, then retry. If you still have problems, check this thread: http://forums.seagate.com/stx/board/message?board.id=onetouch^&message.id=1727
IF e%1==e4 SET ERRORTEXT=cannot find excludelist file on local machine - check SET excludelist= setting
IF e%1==e5 SET ERRORTEXT=missing dependency file
IF e%1==e7 SET ERRORTEXT=vshadow -da was unable to delete existing shadow copies - reboot to fix
IF e%1==e8 SET ERRORTEXT=cannot find private key file on local machine - check SET key= setting and/or .ppk file location
IF e%1==e9 SET ERRORTEXT=cannot connect to Server
IF e%1==e10 SET ERRORTEXT=cannot find configuration file
IF e%1==e11 SET ERRORTEXT=needs to be run with administrative privileges
IF e%1==e12 SET ERRORTEXT=cannot run under this version of Windows
IF e%1==e13 SET ERRORTEXT=cannot complete
IF e%1==e14 SET ERRORTEXT=cannot connect to rdiff-backup on Server
IF e%1==e15 SET ERRORTEXT=server undefined, or invalid configuration file
IF e%1==e16 SET ERRORTEXT=cannot decode short date format
IF e%1==e17 SET ERRORTEXT=recovering - cannot identify source directory as one used by TimeDicer
IF e%1==e18 SET ERRORTEXT=recovering/listing - an error occurred when recovering, or listing versions of, the specified file
IF e%1==e20 SET ERRORTEXT=error at second invocation of vshadow%
IF e%1==e30 SET ERRORTEXT=error performing rdiff-backup
IF e%1==e50 SET ERRORTEXT=error performing rdiff-backup + error with vshadow
IF %1 GTR 100 SET ERRORTEXT=internal error - please report
GOTO :EOF
:help
SET li=
IF /I "%~1" NEQ "-m" (
	CALL :help2
	SET dest=%TEMP%\
) ELSE (
	SET dest=%2\
	IF "%2" EQU "" SET dest=
)
IF %quiet% == y GOTO :eof
REM generic html tags
SET h2=^^^<h2 style="font-family:Cambria,HandelGot,Candara,Palatino Linotype Bold,Palatino Linotype,Garamond Bold,Garamond,Times New Roman Bold,Times New Roman,Verdana,Tahoma,Arial Rounded MT Bold,Arial,Helvetica; font-weight: bold; color: rgb(51,153,255); margin-top: 0.3em; margin-bottom: 0.3em;"^^^>
SET h2x=^^^</h2^^^>
SET p=^^^<p^^^>
SET px=^^^</p^^^>
SET ul=^^^<ul^^^>
SET ulx=^^^</ul^^^>
SET li=^^^<li^^^>
SET lix=^^^</li^^^>
SET pre=^^^<pre^^^>
SET prex=^^^</pre^^^>
SET htmlend=^^^</body^^^>^^^</html^^^>
SET ax=^^^</a^^^>
REM specific html tags
SET htmlstart=^^^<html^^^>^^^<title^^^>%this% man page^^^</title^^^>^^^<body bgcolor="#FFFBD8" style="font-family:Sawasdee,Calibri,Franklin Gothic Book,Verdana,Lucida Sans Unicode,Lucida Sans,Arial,Helvetica,sans-serif"^^^>^^^<h1 style="font-family:Cambria,HandelGot,Candara,Palatino Linotype Bold,Palatino Linotype,Garamond Bold,Garamond,Times New Roman Bold,Times New Roman,Verdana,Tahoma,Arial Rounded MT Bold,Arial,Helvetica; font-weight: bold; color: rgb(51,153,255); margin-top: 0.3em; margin-bottom: 0.3em;"^^^>%this% v%ver% by %credit%^^^</h1^^^>
SET homepage=^^^<a href="%homepage%" target="_blank"^^^>the TimeDicer website^^^</a^^^>
SET href_rdiffbackup=^^^<a href=http://www.nongnu.org/rdiff-backup/^^^>
SET href_openssh=^^^<a href=http://www.openssh.com/^^^>
REM SET href_grep=^^^<a href=http://gnuwin32.sourceforge.net/packages/grep.htm^^^>
SET href_sed=^^^<a href=http://sed.sourceforge.net/grabbag/ssed/^^^>
SET href_plink=^^^<a href=http://www.chiark.greenend.org.uk/~sgtatham/putty/download.html^^^>
SET href_vshadow=^^^<a href=http://edgylogic.com/blog/vshadow-exe-versions/^^^>
SET href_dosdev=^^^<a href=http://www.ltr-data.se/files/dosdev.zip^^^>
SET href_vc90=^^^<a href=http://download.savannah.gnu.org/releases/rdiff-backup/Microsoft.VC90.zip^^^>
REM SET href_nlsinfo=^^^<a href=http://www.microsoft.com/downloads/details.aspx?FamilyID=9d467a69-57ff-4ae7-96ee-b18c4790cffd^^^&DisplayLang=en^^^>
REM create the html help file
CALL :help2>"%dest%%thislc%-man.html"
REM show the help file in browser
IF /I "%~1" NEQ "-m" "%dest%%thislc%-man.html"
GOTO :eof
:help2
IF %quiet% == y (
	ECHO.
	ECHO %this% v%ver% by %credit%
	ECHO.
	ECHO ^(for fuller instructions run with -h but without -q or /q^)
	ECHO.
)
ECHO %htmlstart%%p%%this% Client is a Windows command-line program which can 
ECHO perform [un]attended push backups to a TimeDicer Server, using Windows Volume
ECHO Shadow Services if specified; it can also show and recover previous versions
ECHO of files from the TimeDicer Server. It is essentially a Windows wrapper for
ECHO %href_rdiffbackup%rdiff-backup%ax%. For more information
ECHO visit %homepage%.%px%
ECHO.
ECHO %p%Usage: %thislc% [Options] [recover_file]%px%
ECHO.
ECHO.
ECHO %h2%ConfigFile%h2x%
ECHO %this% requires a ConfigFile ^(see example TimeDicer.txt below^) which should hold
ECHO %ul%%li%variable definitions and %lix%%li%a comma-separated list of source-directories
ECHO and destination-directories.%lix%%ulx%%px%
REM ECHO %ul%%li%certain key variable definitions and %lix%%li%a
REM ECHO comma-separated list of source-directories and destination-directories.%lix%%ulx%%px%
ECHO.
ECHO %p%If ConfigFile is not supplied on the command line ^(see option /f^)
ECHO %this% uses %%APPDATA%%\TimeDicer\TimeDicer.txt as ConfigFile.
ECHO Example settings for ConfigFile are below.%px%
ECHO.
ECHO %p%A log file is created at %%APPDATA%%\TimeDicer\%this%-log.txt ^(or as set
ECHO by %%log%% - see below^). With the compare option, the log is also sent to
ECHO the console.%px%
ECHO.
ECHO %h2%Options%h2x%
ECHO %p%Options are case insensitive, and dash can be used instead of slash:%px%
ECHO %ul%%li%   /c       : compare rather than backup ^(--compare^)%lix%
ECHO %li%   /f conf  : use ConfigFile 'conf'%lix%
ECHO %li%   /g       : run with debug messages%lix%
ECHO %li%   /h /?    : see these instructions ^(console and html^)%lix%
ECHO %li%   /q       : reduce output messages ^(quiet^)%lix%
ECHO %li%   /t       : do everything except call rdiff-backup ^(test^)%lix%
ECHO %li%   /v       : show version of %this%%lix%
ECHO %li%   /x       : exit at end of run instead of pausing%lix%
ECHO %li% List Versions: [recover_path\file] on command line will list timediced versions of file%lix%
ECHO %li% Recover Options: [/r] [/o] [recover_path\file] [when] [recover_to]%ul%
	ECHO %li%   /r       : recover a file%lix%
	ECHO %li%   /o       : with /r, allow overwrite of existing local file%lix%
	ECHO %li%   recover_path\file : the original-path\file to recover%lix%
	ECHO %li%   when     : optionally, if recovering, specify datetime of version to recover - after recover_file%lix%
	ECHO %li%   recover_to   : optionally, if recovering, specify where to recover to - default %%TEMP%%%lix%%ulx%
ECHO %ulx%%px%
REM Undocumented options:
REM -m    : create %this%-man.html file at the following (or current) directory (no trailing slash)
IF %quiet% == y GOTO :eof
ECHO.
ECHO %h2%Error Codes%h2x%%ul%
SET PLUS=
FOR /L %%E IN (1,1,51) DO (
	SET ERRORNO=%%E
	IF %%E==51 (SET ERRORNO=101&&SET PLUS=+)
	CALL :errortext !ERRORNO!
	IF NOT X!ERRORTEXT!==X ECHO %li%!ERRORNO!!PLUS!: !ERRORTEXT!%lix%
)
ECHO.
ECHO %ulx%%h2%TimeDicer.txt file%h2x%
ECHO %pre%#TimeDicer.txt file - example/template config file
ECHO.
ECHO #Lines that are blank or any text after # on a line are ignored, lines
ECHO #beginning with SET are processed, all other lines are assumed to be part
ECHO #of the list of sources and destinations. The file must terminate with
ECHO #an end-of-line.
ECHO.
ECHO #The only required lines are one beginning SET server= ^(specifying the address
ECHO #of the TimeDicer Server^), and at least one comma-separated line specifying a
ECHO #source folder and destination archive.
ECHO.
ECHO #'server' is the DNS name or IP address of the TimeDicer Server, and
ECHO #must be supplied here.
ECHO SET server=192.168.100.125
ECHO.
ECHO #'excludelist' optionally identifies a file which lists ^(in Windows format,
ECHO #case insensitive^) files/paths to be excluded from backup e.g. thumbs.db.
ECHO #Each file/path should appear on a separate line in the file. Do not begin
ECHO #or end an entry in the list with * as this is prefixed/suffixed
ECHO #anyway, and do not use quotes. So a line:
ECHO #"C:\Documents And Settings\Fred\My Documents\thumbs.*"
ECHO #should instead be written as:
ECHO #C:\Documents And Settings\Fred\My Documents\thumbs.
ECHO #or even:
ECHO #thumbs.
ECHO #(which will exclude all files or paths which contain the text 'thumbs.')
ECHO #SET excludelist=c:\exclfolders.txt
ECHO.
ECHO #Backups:a comma-separated list of source directories and their
ECHO #destination archives, with an optional third parameter holding extra
ECHO #parameters to be added to the rdiff-backup command line (these appear before
ECHO #any 'excludelist' and 'options' parameters and thus are
ECHO #processed after them). Environment variables can be embedded as shown.
ECHO #Directories should not have surrounding quotes, and there should not
ECHO #be any terminating backslash (\).
ECHO %%USERPROFILE%%\My Documents,mydocs,--exclude **/*.accd? --exclude **/*.md?
ECHO %%USERPROFILE%%\Desktop,desktop
ECHO c:\Utils,utils
ECHO c:\Bas,bas%prex%
ECHO.
ECHO %ulx%%h2%TimeDicer.txt file - Advanced Options%h2x%
ECHO %p%You will not normally need to use these more advanced options:%px%
ECHO %pre%#Advanced Options:
ECHO #
ECHO #'user' is the login name of the user on the TimeDicer Server, it is
ECHO #optional and defaults to lower-case %%USERNAME%%-%%USERDOMAIN%% with 
ECHO #any spaces stripped. 'user' must not contain spaces!
ECHO #SET user=fred
ECHO.
ECHO #'key' is ppk file ^(created with Puttygen and containing private key, the
ECHO #corresponding public key must be saved on the TimeDicer Server in
ECHO # ~/.ssh/authorized_keys^). For TimeDicer to run unattended, the public key
ECHO #must be saved without passphrase. 'key' is optional; if not supplied it
ECHO #defaults to %%APPDATA%%\TimeDicer\privatekey.ppk.
ECHO #SET key=C:\Documents and Settings\Fred\privatekey.ppk
ECHO.
ECHO #'port' is the ssh port on or to the TimeDicer Server, default 22.
ECHO #SET port=22
ECHO.
ECHO #'basearchive' is optional, all archive destinations will have this prefix.
ECHO #Unless 'basearchive' starts with / it will be defined in relation to the home
ECHO #directory of the user on the TimeDicer Server; if it is undefined, archives
ECHO #will be directly located in that home directory. If using ecryptfs under
ECHO #Ubuntu then 'basearchive=Private' should provide good protection against data
ECHO #theft resulting from physical theft of the TimeDicer Server, but does not
ECHO #prevent the administrator of the TimeDicer Server ^(superuser^) getting access
ECHO #to your data. Note that 'basearchive' is case sensitive.
ECHO SET basearchive=archives/
ECHO.
ECHO #'options' is optional and contains additional options per 'man rdiff-backup',
ECHO #it appears before 'excludelist' and thus is processed after it.
ECHO #SET options=-v5
ECHO.
REM ECHO #'primarysourcedrive' is optional and defaults to C:, it should be a local drive
REM ECHO #on which are located all the backed up directories. This drive will
REM ECHO #be mapped to a volume shadow copy unless vss=n (see below).
REM ECHO #SET primarysourcedrive=C:
REM ECHO.
ECHO #'vss' is optionally y or n (default: y) -  set to n to disable Volume Shadow
ECHO #Services. You need to do this is if the source drive is formatted with FAT32
ECHO #(or FAT) or if you are backing up from a non-local drive.
ECHO #SET vss=y
ECHO.
ECHO #'skip_on_no_change' is optionally y or n ^(default: y^) - set to n to disable
ECHO #skipping of backup if the source data has not changed since last time. After
ECHO #each run %this% records the date of each successful backup and if 
ECHO #'skip_on_no_change' is 'y' then it looks for changes in the source data
ECHO #^(using xcopy^) since ^[and including^] that date. Backup is skipped if there
ECHO #are no changes. This can avoid bloating of backups on the TimeDicer Server
ECHO #especially with sources that rarely change.
ECHO #SET skip_on_no_change=n
ECHO.
ECHO #'skip-rdiff-backup-test' is optionally y ^(default: n^) - in rare situations,
ECHO #e.g. restricted access rights to the server, this forces TimeDicer to skip
ECHO #an initial test on presence and version of rdiff-backup on the server.
ECHO.
ECHO #'log' is optional location for log file and it defaults to 
ECHO #%%APPDATA%%\TimeDicer\%this%-log.txt. If you do not want a log set it to NUL.
ECHO #SET log=%%APPDATA%%\TimeDicer\%this%-log.txt%prex%
ECHO.
REM ECHO #'mapdrive' is optional and defaults to X:, it should be a drive letter
REM ECHO #that is not already in use:
REM ECHO #SET mapdrive=X:
REM ECHO.
REM ECHO #'view' is optionally 'none' ^(the default^), 'file', 'date' or 'unload',
REM ECHO #and creates, updates or unloads a read-only archfs-based view of the
REM ECHO #repositories to be accessed with WinSCP at ~/timediced. This is currently a
REM ECHO #BETA feature because of issues with archfs, the underlying technology.
REM ECHO #'file' gives a view with each file as a directory, inside which
REM ECHO #are files named as dates which are the versions of this file at such date.
REM ECHO #Using 'date' each backup is a date-named directory, and all the files in
REM ECHO #that backup are inside it. Note that for a large backup set with many past
REM ECHO #updates, using 'view' can be slow at the time of running %this%, but it
REM ECHO #makes checking and retrieving past versions of files very easy.
REM ECHO #SET view=date
REM ECHO.
REM ECHO #'logv' is optional location for log file with Timedicer-verify.cmd
REM ECHO #and it defaults to %%TEMP%%\%this%-verify-log.txt
REM ECHO #SET logv=%%TEMP%%\%thislc%-verify-log.txt%prex%%htmlend%
ECHO %h2%Dependencies ^(all free^) software%h2x%
ECHO %ul%%li% On Linux server:%lix%
ECHO %ul%%li%	%href_rdiffbackup%rdiff-backup%ax%%lix%
ECHO %li%	%href_openssh%openssh%ax% ^(normally installed by default^)%lix%%ulx%
ECHO %li% On Windows client ^(in same folder as %this%^):%lix%
ECHO %ul%%li%	%href_rdiffbackup%rdiff-backup-win.exe%ax% ^(Windows port^)%lix%
ECHO %li%	%href_vc90%Microsoft Visual 2008 Redistributables%ax%%lix%
ECHO %li%	%href_sed%ssed.exe%ax% ^(Windows port^)%lix%
REM ECHO %li%	%href_nlsinfo%nlsinfo.exe%ax%%lix%
ECHO %li%	%href_plink%plink.exe%ax%%lix%%ulx%
ECHO %li% and if you wish to use Volume Shadowing with NTFS ^(recommended^) you also need:%lix%
ECHO %ul%%li%	%href_vshadow%vshadow%ax%%lix%
ECHO %li%	%href_dosdev%dosdev.exe%ax%%lix%%ulx%%ulx%
ECHO.
ECHO If the instructions at %homepage% are followed, all of these dependencies are
ECHO met automatically. In any case, %this% Client performs checks for its
ECHO dependencies before starting backup.%px%
ECHO.
ECHO %p%Questions? Send an email to %credit% %contact%%px%
ECHO.
GOTO :eof
