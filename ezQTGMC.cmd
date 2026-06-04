:: ezQTGMC.cmd ["/variable=value" [...]] [sourceFolder[\file] [targetFolder]]
:: 
:: a fancy batch frontend for Hunk91's FFmpeg-QTGMC Easy 2025.01.11
:: https://forum.videohelp.com/threads/405720-FFmpeg-QTGMC-Easy%21
:: accepts file or folder as input and will recursively rebuild to target
:: simply drag/drop/copy/paste onto the batch file or use the commandline
:: control variables may be assigned directly on the commandline: "/var=val"
:: 
:: videos may be excluded using any criteria returned by ffprobe.exe
:: simply set a variable that describes the type of comparison being made
:: types are EQU,GEQ,GTR,LEQ,LSS,NEQ (numerals) plus EXC,INC (strings)
:: your variable will be header_VariableName; numeralOps work like so:
:: ezQTGMC "/LEQ_bit_rate=2097152" excludes files at or below 2mbps
:: ezQTGMC "/GTR_duration=600" excludes files longer than 10 minutes
:: ezQTGMC "/NEQ_audCount=2" allows only files having exactly 2 audio tracks
:: 
:: EXC/INC are stringOps that contain a list to match the value against:
:: ezQTGMC "/EXC_codec_name=h264 h265" excludes files using h264/h265 codecs
:: ezQTGMC "/EXC_codec_type=subtitle" excludes files containg any subtitles
:: ezQTGMC "/INC_T_language=eng spa jpn" includes only files in these languages
:: ezQTGMC "/INC_display_aspect_ratio=4:3" includes only files in 4:3 aspect
:: 
:: use "/peruse=1" to view file details, read the batch file for information
::
:::::::::::::::::::::::::::::::::::::::::::::
:: some of the less-obvious user variables ::
:::::::::::::::::::::::::::::::::::::::::::::
:: 
:: iFrames=number of interlaced frames required to use QTGMC (TFF+BFF sample of 100) 0=always(default), 101=never
:: logFile=filename for text record of batch activity, no logfile if undefined
:: modeQTGMC=if undefined set to 'Faster' (Placebo,Very Slow,Slower,Slow,Medium,Fast,Faster,Very Fast,Super Fast,Ultra Fast,Draft)
:: numOfCores=number of processor cores to devote to QTGMC, if undefined set to 50% NUM_OF_PROCESSORS
:: peruse=if defined only file information is displayed on screen, no files are processed
:: recursive=if defined source folder is recursively searched, if undefined source subfolders are ignored
:: reverse=if defined the sort-order is reversed (z-A,9-0), useful for using 2 computers on 1 folder
:: sourceDir=source folder, always set to 1st parameter (%1) if present, if undefined display help text and exit
:: sourceExt=space-separated list of video file extensions to search for, if undefined set to all I could think of
:: subExt=space-separated list of external subtitle file extensions to use, if undefined external subtitles are ignored
:: subLang=space-separated list of allowed subtitle language extensions (.en .eng .ja .jpn)
:: targetDir=target folder, always set to 2nd parameter (%2) if present, if undefined set to \_%~n0 in same folder as source
:: vClip=simple way to quick preview files; -ss #secondsToSkip -t #secondsToKeep"
:: 
:::::::::::::::::::::::::::::::::::::::::::::
:: v0.2 2026/05/26             CirothUngol ::
:::::::::::::::::::::::::::::::::::::::::::::

@SETLOCAL EnableExtensions DisableDelayedExpansion
@CALL :init

:::::::::::::::::::::::::::::::::::::::::::::::::
:: user variables - choose your settings below ::
:::::::::::::::::::::::::::::::::::::::::::::::::
::
SET "exitPause=1"
SET "iFrames="
SET "logFile=%dpn0%.log"
SET "modeQTGMC=slower"
SET "numOfCores="
SET "peruse="
SET "recursive=1"
SET "reverse="
::SET "sourceDir=%CD%"
SET "sourceExt=avi mkv mp4"
SET "subExt=ass srt"
SET "subLang=.en .eng"
SET "targetDir="
::SET "vClip=-ss 60 -t 30"
::
:: variables to make the command line more managable
SET "aCodec=-c:a copy"
SET "vCodec=-c:v libx264"
SET "aFilter="
::SET "vfilter=-vf crop=704:480:0:0"
::SET "vfilter=-vf scale=-2:'min(ih,1080)'"
SET "preset=-preset veryslow"
SET "crf=-crf 19"
SET "vbrMax=-maxrate:v 1920K"
SET "bufSize=-bufsize 4M"
SET "aspect=-aspect 4:3"
SET "pixFmt=-pix_fmt yuv420p"
:: crop and add borders
::-vf "pad=width=iw:height=trunc(iw/4)*3:x=(ow-iw)/2:y=(oh-ih)/2:color=black"
::-vf "pad=height=ih:width=trunc(ih/3)*4:x=(ow-iw)/2:y=(oh-ih)/2:color=black"
::-vf "scale=1920:1080:force_original_aspect_ratio=decrease,pad=1920:1080:(ow-iw)/2:(oh-ih)/2,setsar=1"
::SET vFilter=-vf "crop=704:352:2:64,pad=720:360:8:4"
:: x265 HEVC
::SET "vcodec=-c:v libx265"
::SET "preset=-preset medium"
::SET "crf=-crf 21"
::
:: want a unique logfile for each run?
::FOR /F "tokens=1-8 delims=:/. " %%S IN ("%DATE% %TIME: =0%") DO SET "logFile=%dpn0%.%%V%%T%%U.%%W%%X%%Y.log"
::
:::::::::::::::::::::::::::::::::::::::::::::::::
:: user variables - choose your settings above ::
:::::::::::::::::::::::::::::::::::::::::::::::::

:parse the command line for variables
IF "%~1"=="" GOTO :start
SET "t1=%~1"
IF NOT "%t1:~0,1%"=="/" GOTO :start
SET "%t1:~1%"
%LOG%%t1:~1%
SHIFT

GOTO :parse

:start the command file
::::::::::::::::::::
:: initialize values
IF %errlvl% GTR 0 ENDLOCAL & (SET RUN_%n0%=1) & EXIT /B %errlvl%
IF NOT "%~1"==""          SET "sourceDir=%~1"
IF NOT DEFINED sourceDir  FOR /F "usebackq tokens=* delims=:" %%A IN ("%~f0") DO IF "%%A" NEQ "" (ECHO.%%A) ELSE GOTO :end
IF NOT "%~2"==""          SET "targetDir=%~2"
IF NOT DEFINED targetDir  SET "targetDir=%sourceDir%"
IF NOT DEFINED mapStream  SET "mapStream=%vClip% -i %%1 -map 0:0 -map 1:1"
IF NOT DEFINED ffmpegSet  SET "ffmpegSet=-v error -stats -threads 0 -ignore_unknown"
IF NOT DEFINED modeQTGMC  SET "modeQTGMC=faster"
IF NOT DEFINED iFrames    SET "iFrames=0"
IF NOT DEFINED sourceExt  SET "sourceExt=3g2 3gp asf avchd avi cam divx f4v fla flv m1v m2ts m2v m4v mkv mng mov mp4 mpg mpeg mts mxf nsv ogm ogv qt rm rmvb svi ts vob webm wmv"
IF NOT DEFINED numOfCores IF DEFINED NoP ( SET /A numOfCores=NoP/2) ELSE (SET "numOfCores=1")
IF NOT DEFINED subExt     SET "subLang="
IF DEFINED recursive      SET "recursive=/S"
IF DEFINED reverse        SET "reverse=/R"
IF NOT EXIST "%dpn0%.avs" CALL :makeAVS

:: no vbrMax limit
::SET "videoSet=%preset% %crf% %aspect% %pixfmt%"
:: with vbrMax limit
SET "videoSet=%vcodec% %preset% %crf% %vbrMax% %bufsize% %aspect% %pixfmt% %vfilter%"
SET "audioSet=%acodec% %afilter%"

:checkDir to remove the trailing '\'
IF NOT DEFINED sourceDir ECHO sourceDir not defined & GOTO :end
IF NOT DEFINED targetDir ECHO targetDir not defined & GOTO :end
IF "%sourceDir:~-1%"=="\" SET "sourceDir=%sourceDir:~0,-1%" & GOTO :checkDir
IF "%targetDir:~-1%"=="\" SET "targetDir=%targetDir:~0,-1%" & GOTO :checkDir

:: is source a file or folder?
IF NOT EXIST "%sourceDir%\" ( REM It's not a folder
	IF EXIST "%sourceDir%"  ( REM It's a file
		SET totalCnt=1
		SET "t1=%sourceDir%"
		FOR %%A IN ("%sourceDir%") DO SET "sourceDir=%%~dpA"
		CALL SET "sourceDir=%%sourceDir:~0,-1%%"
		IF "%targetDir%"=="%sourceDir%" CALL SET "targetDir=%%sourceDir%%"
	) ELSE (%LOG%"%sourceDir%" could not be found ) & GOTO :end
)
IF "%targetDir%"=="%sourceDir%" FOR %%A IN ("%sourceDir%") DO SET "targetDir=%%~dpA_%n0%"

:: display start info
%BAR%
%LOG%%n0% started at %TIME: =0% on %DATE%
FOR %%A IN (sourceDir targetDir logFile subExt subLang modeQTGMC iFrames numOfCores recursive reverse vClip sourceExt) DO (
	IF DEFINED %%A CALL ECHO.%%A=%%%%A%%)
%LOG%

:: scan for media files and call :ezQTGMC for each
IF totalCnt EQU 1 ( CALL :ezQTGMC "%t1%" ) & GOTO :stop
TITLE %n0% is scanning for files...
FOR %%A IN (%sourceExt%) DO FOR /F "delims=" %%B IN ('DIR /A-D /B %recursive% "%sourceDir%\*.%%A" 2^>NUL') DO ( SET /A totalCnt+=1
	%ADD% totalBytes=!totalBytes!+%%~zB)
FOR %%A IN (%sourceExt%) DO FOR /F "delims=" %%B IN ('DIR /A-D /B %recursive% "%sourceDir%\*.%%A" 2^>NUL ^| SORT %reverse%') DO (
	CALL :ezQTGMC "%%~fB"
	IF ERRORLEVEL 255 GOTO :stop)
IF %totalCnt% LSS 1 %LOG%no files found...

:stop
%LOG%
%LOG%%pct%%% %doneCnt% of %totalCnt% at %TIME: =0% on %DATE%
TITLE %pct%%% %doneCnt% of %totalCnt% at %TIME: =0% on %DATE%
:end
IF DEFINED exitPause %POZ% press any key to exit %n0%...
ENDLOCAL & SET RUN_%n0%=1

EXIT /B 0

:ezQTGMC
SET /A doneCnt+=1
TITLE %n0% %pct%%% #%doneCnt% of %totalCnt%: %1
SET /A pct=doneCnt*100/totalCnt

SETLOCAL
SET "fileTime=%TIME: =0% %DATE%"
IF NOT EXIST %1 GOTO :ezOut
IF DEFINED peruse ( CALL :getInfo %1
	GOTO :ezOut)

:: generate target path and exit if target exists
SET "tDir=%~dp1"
CALL SET "tDir=%targetDir%%%tDir:%sourceDir%=%%"
IF EXIST "%tDir%%~n1.mkv" GOTO :ezOut

:: get file info then exit on exclusions or begin processing
CALL :getInfo %1
IF ERRORLEVEL 1 GOTO :ezOut

%BAR% %DATE% %TIME: =0%
%LOG%%n0% @ %pct%%% #%doneCnt% of %totalCnt%: %1
FOR %%X IN ("%vidInfo:$=" "%") DO %LOG%%%~X
ECHO.

:: check for matching subtitles
FOR %%Y IN (%subExt%) DO FOR %%Z IN ("" %subLang%) DO IF EXIST "%~dpn1%%~Z.%%~Y" (
	SET mapStream=%vClip% -i %%1 %vClip% -i "%%~dpn1%%~Z.%%~Y" -map 0:0 -map 1:1 -map 2:0)

:: use QTGMC or not?
IF %tffbff% GEQ %iFrames% (SET "srcFile=%dpn0%.avs"
	REM create the import.avis file containing settings for ezQTGMC.avs
	ECHO mode = "%modeQTGMC%">"%dp0%setQTGMC.avsi"
	ECHO cores = %numOfCores% >>"%dp0%setQTGMC.avsi"
	ECHO filename = %1>>"%dp0%setQTGMC.avsi"
) ELSE SET "srcFile=%~1"

:: call ffmpeg for encoding
MD "%tDir%" >NUL 2>&1
%LOG%ffmpeg.exe %ffmpegSet% %vClip% -i "%srcFile%" %mapStream% %audioSet% %videoSet% -metadata title="%~n1" -y "%tDir%%~n1.mkv"
ECHO.
CALL ffmpeg.exe %ffmpegSet% %vClip% -i "%srcFile%" %mapStream% %audioSet% %videoSet% -metadata title="%~n1" -y "%tDir%%~n1.mkv"
SET "errlvl=%ERRORLEVEL%
DEL /Q "%~1.ffindex" >NUL 2>&1
RD "%tDir%" >NUL 2>&1
ECHO.
IF %errlvl% EQU 255 %LOG%user interrupt: removed "%tDir%%~n1.mkv"
IF %errlvl% EQU 255 DEL /Q "%tDir%%~n1.mkv" >NUL 2>&1
IF %errlvl% EQU 255 GOTO :ezOut
IF %errlvl% GEQ 1 %LOG%ErrorLevel is %ERRORLEVEL%

:: add times to logfile and exit
::SET /A part=doneCnt-skipCnt,whole=totalCnt-skipCnt
%ADD% doneBytes=!doneBytes!+%~z1
%SUB% whole=!totalBytes!-!skipBytes!

CALL :timeSince %fileTime%

%LOG%file completed in %TS_% on %DATE% at %TIME: =0%
CALL :timeSince %startTime% %doneBytes% %whole%
%LOG%%pct%%% #%doneCnt% of %totalCnt% completed in %TS_%
%LOG%there may be %TR_% remaining to completion
%LOG%

( ENDLOCAL
  SET doneBytes=%doneBytes%
  EXIT /B %errlvl%)

::::::
:ezOut
%ADD% skipBytes=!skipBytes!+%~z1
( ENDLOCAL
  SET skipBytes=%skipBytes%
  SET /A skipCnt+=1
  EXIT /B %errlvl%)

:: import file details into environment
:getInfo FileToProbe
FOR /F "tokens=*" %%W IN ('ffProbe.exe -v quiet -show_streams -show_format "%~f1" 2^>NUL') DO (
	IF /I "%%W"=="[/FORMAT]" SET strFlag=
	IF /I "%%W"=="[/STREAM]" SET /A strCnt+=1 & SET strFlag=
	IF DEFINED strFlag FOR /F "tokens=1-2* delims=:=" %%X IN ("%%W") DO (
		IF /I "%%X"=="DISPOSITION" ( CALL SET "D_%%Y%%strSuf%%=%%Z"
		) ELSE IF /I "%%X"=="TAG" ( CALL SET "T_%%Y%%strSuf%%=%%Z"
		) ELSE IF "%%Z"=="" ( CALL SET "%%X%%strSuf%%=%%Y"
		) ELSE CALL SET "%%X%%strSuf%%=%%Y:%%Z"
	)
	IF /I "%%W"=="[STREAM]" SET strFlag=1 & CALL SET strSuf=%%strCnt%%
	IF /I "%%W"=="[FORMAT]" SET strFlag=1 & SET strSuf=
)
IF %strCnt% LSS 1 EXIT /B 1

:: convert file duration to 00h00m00s
SET /A dur=duration=%duration% 2>NUL
SET /A hrs=dur/3600, min=dur %% 3600/60, sec=dur %% 60, strIdx=strCnt-1, kbps=bit_rate/1024
::IF %sec% LEQ 9 SET sec=0%sec%
::IF %min% LEQ 9 SET min=0%min%
IF %hrs% EQU 0 ( IF %min% EQU 0 ( SET dur=%sec%sec
) ELSE SET dur=%min%min %sec%sec
) ELSE SET dur=%hrs%hrs %min%min %sec%sec

SETLOCAL EnableDelayedExpansion
:: iterate through streams and build file description
FOR /L %%X IN (0,1,%strIdx%) DO (
	IF DEFINED channels%%X             SET chnls=, !channels%%X!ch
	IF DEFINED T_language%%X           SET lang=, !T_language%%X!
	IF DEFINED codec_name%%X           SET codec=, !codec_name%%X!
	IF DEFINED sample_rate%%X          SET smprt=, !sample_rate%%X!hz
	IF DEFINED channel_layout%%X       SET lyout= !channel_layout%%X!
	IF DEFINED display_aspect_ratio%%X SET dar=, !display_aspect_ratio%%X!
	IF /I !codec_type%%X!==video (
		SET fps=!r_frame_rate%%X!
		SET /A fps=!fps:/=00/!
		SET fps=, !fps:~0,-2!.!fps:~-2! fps
		SET vidInfo=!vidInfo!$  Str%%X: vid!vidCount!!codec!!fps!!dar!, !width%%X!x!height%%X!!lang!
		SET /A vidCount+=1
	) ELSE IF /I !codec_type%%X!==audio (
		SET vidInfo=!vidInfo!$  Str%%X: aud!audCount!!codec!!chnls!!lyout!!smprt!!lang!
		SET /A audCount+=1
	) ELSE IF /I !codec_type%%X!==subtitle (
		SET vidInfo=!vidInfo!$  Str%%X: sub!subCount!!codec!!lang!
		SET /A subCount+=1
	) ELSE IF /I !codec_type%%X!==data (
		SET vidInfo=!vidInfo!$  Str%%X: dat!datCount!!codec!!lang!
		SET /A datCount+=1
	) ELSE (
		SET vidInfo=!vidInfo!$  Str%%X: oth!othCount!!codec!!lang!
		SET /A othCount+=1
	)
	FOR %%Y IN (lang lyout smprt chnls codec fps dar) DO SET %%Y=
)

FOR /F "tokens=*" %%W IN ('ffmpeg.exe -hide_banner -ignore_unknown -i %1 -frames:v 100 -an -vf idet -f null -y - 2^>^&1 ^| find "Multi frame detection:"') DO SET "t1=%%W"
FOR /F "tokens=8,10,12,14" %%W IN ("%t1%") DO (
	SET vidInfo=$Frames: TFF %%W, BFF %%X, Prg %%Y, Und %%Z!vidInfo!
	SET /A tffbff=%%W+%%X)

SET t1=%~x1
%PWSH%Mb=[math]::Round(%~z1/1048576,2)
SET vidInfo=Source: %t1:~1%, %dur%, %kbps% kbit/s, %Mb% Mbytes!vidInfo!

:: here is where limits and exclusions should be made
FOR /F "tokens=1,2 delims== " %%X IN ('SET 2^>NUL') DO IF /I "%%Y"=="N/A" SET "%%X="
IF DEFINED peruse ( SET
	%BAR% %DATE% %TIME: =0%
	FOR %%X IN ("%vidInfo:$=" "%") DO ECHO.%%~X
	%POZ%press any key to peruse next file...
	ENDLOCAL & EXIT /B 1)
:: numeral exclusions are indiscriminate, exit if any are true
:: SET "GEQ_height=1080" to only process files with height less than 1080 (exclude if greater or equal)
:: SET "LSS_bit_rate=2097152" to only process files with bitrate at or above 2mbps (exclude if less)
:: SET "LEQ_duration=600" to only process files longer than 10 minutes (exclude if 600 seconds or less)
FOR %%V IN (EQU GEQ GTR LEQ LSS NEQ) DO (
	FOR /F "tokens=1* delims=_" %%W IN ('SET %%V_ 2^>NUL') DO (
		FOR /F "tokens=1 delims==" %%Y IN ("%%X") DO (
			IF DEFINED %%Y (
				IF %%V==EQU IF !%%Y! EQU !%%W_%%Y! ENDLOCAL & EXIT /B 1
				IF %%V==GEQ IF !%%Y! GEQ !%%W_%%Y! ENDLOCAL & EXIT /B 1
				IF %%V==GTR IF !%%Y! GTR !%%W_%%Y! ENDLOCAL & EXIT /B 1
				IF %%V==LEQ IF !%%Y! LEQ !%%W_%%Y! ENDLOCAL & EXIT /B 1
				IF %%V==LSS IF !%%Y! LSS !%%W_%%Y! ENDLOCAL & EXIT /B 1
				IF %%V==NEQ IF !%%Y! NEQ !%%W_%%Y! ENDLOCAL & EXIT /B 1
			) ELSE FOR /L %%Z IN (0,1,%strIdx%) DO (
				IF DEFINED %%Y%%Z (
					IF %%V==EQU IF !%%Y%%Z! EQU !%%W_%%Y! ENDLOCAL & EXIT /B 1
					IF %%V==GEQ IF !%%Y%%Z! GEQ !%%W_%%Y! ENDLOCAL & EXIT /B 1
					IF %%V==GTR IF !%%Y%%Z! GTR !%%W_%%Y! ENDLOCAL & EXIT /B 1
					IF %%V==LEQ IF !%%Y%%Z! LEQ !%%W_%%Y! ENDLOCAL & EXIT /B 1
					IF %%V==LSS IF !%%Y%%Z! LSS !%%W_%%Y! ENDLOCAL & EXIT /B 1
					IF %%V==NEQ IF !%%Y%%Z! NEQ !%%W_%%Y! ENDLOCAL & EXIT /B 1
				)))))
:: exclude lists are indiscriminate, exit if any match is found
:: SET "EXC_codec_name=h264 h265" to skip files with either 'h264' or 'h265' as codec_name in any track
:: SET "EXC_codec_type=subtitle"  to skip any files that have at least 1 subtitle track
:: SET "EXC_height=320 480 540 720 960 1080" to skip any files with those exact heights
FOR /F "tokens=1* delims=_" %%V IN ('SET EXC_ 2^>NUL') DO (
	FOR /F "tokens=1 delims==" %%X IN ("%%W") DO (
		IF DEFINED %%X ( FOR %%Z IN (!%%V_%%X!) DO IF /I "!%%X!"=="%%~Z" ENDLOCAL & EXIT /B 1
		) ELSE FOR /L %%Y IN (0,1,%strIdx%) DO (
			IF DEFINED %%X%%Y FOR %%Z IN (!%%V_%%X!) DO IF /I "!%%X%%Y!"=="%%~Z" ENDLOCAL & EXIT /B 1
		)))
:: include lists are cumulative, exit unless a match is found for every list
:: SET "INC_codec_name=ac3 dts eac3" to only process files with a track matching one of these codec_names
:: SET "INC_display_aspect_ratio=4:3" to only process files with that one value in display_aspect_ratio
:: SET "INC_T_language1=eng spa jpn" to only process files with one of those languages as the second track
FOR /F "tokens=1* delims=_" %%V IN ('SET INC_ 2^>NUL') DO ( SET xflg=1
	FOR /F "tokens=1 delims==" %%X IN ("%%W") DO (
		FOR %%Z IN (!%%V_%%X!) DO IF /I "!%%X!"=="%%~Z" SET xflg=
		FOR /L %%Y IN (0,1,%strIdx%) DO (
			FOR %%Z IN (!%%V_%%X!) DO IF /I "!%%X%%Y!"=="%%~Z" SET xflg=
		)
	)
	IF DEFINED xflg ENDLOCAL & EXIT /B 1)

( ENDLOCAL
  SET "tffbff=%tffbff%"
  SET "vidInfo=%vidInfo%"
  EXIT /B 0)

:timeSince Time [Date [part whole]]
:: input  - hh:mm:ss.cc [Day MM/DD/YYYY [intPart intWhole]]
:: output - [[[[#wks, ]#day, ]#hrs, ]#min, ]#.#sec
:: Returns time lapsed from %TIME% [%DATE%] to present in %TS_% and if given
:: part+whole will return estimate of time remaining to completion in %TR_%.
:: Raw time and day info for given(1) and current(2) are also available.
:: TM1,TM2=# of centiseconds since last midnight.
:: DY1,DY2=# of days since noon on January 1, 4713 BCE (Julian calendar).
:: usage:
:: SET "startTime=%TIME%" or "startTime=%TIME% %DATE%" before event then:
:: CALL :timeSince %startTime%                      - for current elapsed time.
:: CALL :timeSince %startTime% %partCnt% %wholeCnt% - to estimate by count.
:: CALL :timeSince %startTime% %partKb%  %wholeKb%  - to estimate by size.
:: v0.3 2020/07/29
::
SETLOCAL EnableDelayedExpansion
SET inp=%*
SET/A p=t=t1=tm1=t2=tm2=d=d1=dy1=d2=dy2=x=y=z=0
IF "!inp:~1,1!"==":" SET inp=0!inp!
FOR %%@ IN ("!inp!" "!TIME: =0! !DATE!") DO (SET/A p+=1
	FOR /F "tokens=1-10 delims=:./ " %%A IN ("%%~@")DO IF "%%D" NEQ "" (
		SET/A"tm!p!=t!p!=(((1%%A*60)+1%%B)*60+1%%C)*100+1%%D-36610100"
		IF "%%H" NEQ "" (SET/A mm=100%%F%%100,dd=100%%G%%100,yy=10000%%H%%10000
			SET/A"dy!p!=d!p!=!dd!-32075+1461*(!yy!+4800+(!mm!-14)/12)/4+367*(!mm!-2-(!mm!-14)/12*12)/12-3*((!yy!+4900+(!mm!-14)/12)/100)/4"
			IF "%%J" NEQ "" (SET y=%%I)&(SET z=%%J))))
IF !t1! GEQ !t2! SET/A t2+=8640000,d2-=1
IF !d2! LSS !d1! SET/A d2=d1
IF !d1! EQU 0 SET d2=0
SET/A t1=t2-t1,d1=d2-d1,d2=t2=0
IF !z! NEQ 0 (
	SET xx=0000000009999999
	SET yy=000000000000000!y!
	SET zz=000000000000000!z!
	IF "!yy:~-16!" GTR "!zz:~-16!" SET y=!z!
	FOR /L %%A IN (1,1,8) DO IF "!zz:~-16!" GTR "!xx:~-16!" SET "xx=!xx!9" & SET x=%%A
	IF !x! NEQ 0 FOR %%A IN (!x!) DO SET "y=!y:~0,-%%A!" & SET "z=!z:~0,-%%A!"
	IF "!y!"=="" SET y=1
	IF !y! LSS 1 SET y=1
	SET/A"t2=(z-y)*100/y*((d1*8640000+t1)/100),d2=t2/8640000,t2=t2%%8640000")
FOR %%A IN (1 2) DO ( SET res=
	SET/A"d=d%%A,t=t%%A,w=d/7,d=d%%7,h=t%%8640000/360000,m=t%%360000/6000,s=t%%6000/100,c=t%%100"
	IF !c! LEQ 9 SET c=0!c!
	IF !w! GTR 0 SET "res=!w!wks, "
	IF !d! GTR 0 SET "res=!res!!d!day, "
	IF !h! GTR 0 SET "res=!res!!h!hrs, "
	IF !m! GTR 0 SET "res=!res!!m!min, "
	SET r%%A=!res!!s!.!c!sec)
(	ENDLOCAL
	SET "TS_=%r1%"
	SET "TR_=%r2%"
	REM SET "tm1=%tm1%"
	REM SET "tm2=%tm2%"
	REM SET "dy1=%dy1%"
	REM SET "dy2=%dy2%"
)
EXIT /B 0

 
:init
@ECHO OFF
SET t1=
IF DEFINED RUN_%~n0 SET t1=1
:: clear all variables except those selected
( FOR /F "delims==" %%A IN ('SET 2^>NUL') DO SET "%%A="
  SET "TEMP=%TEMP%"
  SET "PATH=%~dp0;%PATH%"
  SET "SystemRoot=%SystemRoot%"
  SET "NoP=%NUMBER_OF_PROCESSORS%"
  SET "RUN_%~n0=%t1%"
)
SET "startTime=%TIME: =0% %DATE%"
SET /A doneCnt=pct=skipCnt=strCnt=totalCnt=doneBytes=skipBytes=totalBytes=errlvl=vidCount=audCount=subCount=datCount=othCount=0
FOR %%# IN (d p n x dp dpn f) DO CALL SET "%%#0=%%~%%#0"

:: check for required executables
ffMpeg.exe >NUL 2>&1
IF %ERRORLEVEL% EQU 9009 (ECHO ffMpeg.exe could not be found) & (SET errlvl=1) & EXIT /B 0
ffProbe.exe >NUL 2>&1
IF %ERRORLEVEL% EQU 9009 (ECHO ffProbe.exe could not be found) & (SET errlvl=1) & EXIT /B 0

IF NOT DEFINED RUN_%n0% ( MODE 105,10000
	CHCP 65001 >NUL )
COLOR 0F

:: small macros
(SET \n=^^^
%= This defines an escaped Line Feed - DO NOT ALTER =%
)

:: pause with custom (or no) message and no carriage return
:: %POZ% [displayText]
SET POZ=FOR %%# IN (1 2)DO IF %%#==2 (PAUSE^>NUL^&ECHO.)ELSE ^<NUL SET/P=

:: echo logText to both console and filepath in %logFile% if defined
:: %LOG% [logText]
SET LOG=FOR %%# IN (1 2)DO IF %%#==2 (%\n%
IF DEFINED logFile CALL ECHO.!##!^>^>"!logFile!"%\n%
CALL ECHO.!##!%\n%
ENDLOCAL%\n%
)ELSE SETLOCAL EnableDelayedExpansion^&SET ##=

:: display a bar the width of the console window
:: %BAR% [DisplayMessage]
SET BAR=FOR %%# IN (1 2)DO IF %%#==2 (%\n%
FOR /L %%# IN (1,1,8)DO SET b=!b!!b!~~%\n%
SET b=!b!!##! %\n%
FOR /F tokens^^^=2 %%# IN ('MODE CON ^^^| FIND "Columns"')DO ^<NUL SET/P=!b:~-%%#!%\n%
ENDLOCAL%\n%
)ELSE SETLOCAL EnableDelayedExpansion^&SET ##=

:: use powershell for decimals, large integers, complex math. Slow, use others for simple stuff
:: %PWSH% Variable=Expression
SET PWSH=FOR %%# IN (1 2)DO IF %%#==2 (%\n%
FOR /F "tokens=1* delims==" %%A IN ("!##!")DO (%\n%
FOR /F %%C IN ('powershell.exe -command "& {%%B;}"')DO (%\n%
ENDLOCAL^&SET "%%A=%%C"))%\n%
)ELSE SETLOCAL EnableDelayedExpansion^&SET ##=

:: addition - group values by 8 digits, add values, collect carry, assemble answer
:: %ADD% Sum=Integer1+Integer2
SET ADD=FOR %%# IN (1 2)DO IF %%#==2 (%\n%
SET N=%\n%
SET W=0%\n%
FOR /F "tokens=1-3 delims==+ " %%A IN ("!##!")DO (%\n%
SET V=%%A%\n%
SET #1=000000000000000%%B%\n%
SET #2=000000000000000%%C)%\n%
FOR /L %%A IN (8,8,16)DO (%\n%
SET/A T=W+1!#1:~-%%A,8!+1!#2:~-%%A,8!,W=T/300000000%\n%
SET N=!T:~1!!N!)%\n%
FOR /F "tokens=1* delims=0" %%A IN ("!V!0!W!!N!")DO (%\n%
ENDLOCAL%\n%
SET %%A=%%B)%\n%
)ELSE SETLOCAL EnableDelayedExpansion^&SET ##=

:: subtraction - only subtract lesser from greater, all non-positive results are zero.
:: %SUB% Sum=Integer1-Integer2
SET SUB=FOR %%# IN (1 2)DO IF %%#==2 (%\n%
SET N=%\n%
SET W=0%\n%
FOR /F "tokens=1-3 delims==- " %%A IN ("!##!")DO (%\n%
SET V=%%A%\n%
SET #1=000000000000000%%B%\n%
SET #2=000000000000000%%C)%\n%
FOR /L %%A IN (8,8,16)DO (%\n%
SET/A T=3!#1:~-%%A,8!-1!#2:~-%%A,8!+W,W=T/200000000-1%\n%
SET N=!T:~1!!N!)%\n%
FOR /F "tokens=1* delims=0" %%A IN ("!V!0!N!")DO (%\n%
ENDLOCAL%\n%
SET %%A=%%B)%\n%
)ELSE SETLOCAL EnableDelayedExpansion^&SET ##=

EXIT /B 0

:: %CMP% Integer1 Integer2
:: returns result in both ERRORLEVEL and return variable CMP_
:: 0 if int1<int2, 1 if int1=int2, >1 if int1>int2
SET CMP=FOR %%# IN (1 2)DO IF %%#==2 (%\n%
FOR /F "tokens=1-2" %%A IN ("!##!")DO (%\n%
SET #1=000000000000000%%A%\n%
SET #2=000000000000000%%B)%\n%
FOR /F "tokens=1-2" %%A IN ("!#1:~-16! !#2:~-16!")DO (ENDLOCAL%\n%
IF "%%A" LSS "%%B" SET CMP_=0^&COLOR%\n%
IF "%%A" EQU "%%B" SET CMP_=1^&COLOR 00%\n%
IF "%%A" GTR "%%B" SET CMP_=2^&SET/A=2^>NUL)%\n%
)ELSE SETLOCAL EnableDelayedExpansion^&SET ##=

:makeAVS
FOR /F "delims=[]" %%A IN ('FIND /N "#####" "%f0%"') DO SET "sl=%%A"
FOR /F "usebackq skip=%sl% delims=" %%A IN ("%f0%") DO ECHO(%%A>>"%dpn0%.avs"

EXIT /B 0

#####
# QTGMC portable script for ezQTGMC.cmd v0.1 batch frontend
# blatently stolen from Hunk91's fantastic FFmpeg-QTGMC Easy 2025.01.11 package
# https://forum.videohelp.com/threads/405720-FFmpeg-QTGMC-Easy%21
#
# Tested with Avisynth+ 3.7.3(r4003) 64 bits and FFMPEG 7.1-full_build-www.gyan.dev 2024-09-30 
# To know more about AviSynth go to : http://avisynth.nl/
# To know more about FFmpeg go to : https://ffmpeg.org/
#
# Import filename AVSI
Import("setQTGMC.avsi")
#
# Multi-threading requires 'SetFilterMTMode' and 'prefetch' command at the bottom of qtgmc.avs
SetFilterMTMode("DEFAULT_MT_MODE", MT_MULTI_INSTANCE)
#
# FFmpegSource v5.00 plugin : http://avisynth.nl/index.php/FFMS2
# To know more bout loading video files in Avisynth : http://avisynth.nl/index.php/FAQ_loading_clips
LoadPlugin("ffms2.dll")
#
# MaskTools2 v2.2.30 plugin : http://avisynth.nl/index.php/Masktools2
LoadPlugin("masktools2.dll")
# Rgtools v1.2 plugin : http://avisynth.nl/index.php/RgTools
LoadPlugin("Rgtools.dll")
# MVTools v2.7.46 with depans v20240503 plugin : http://avisynth.nl/index.php/MVTools
LoadPlugin("mvtools2.dll")
# Nnedi3 v0.9.4.63 Plugin : http://avisynth.nl/index.php/Nnedi3
LoadPlugin("nnedi3.dll")
#
# Yadifmod2 v0.2.8 Plugin (ONLY for Ultra Fast setting mode in QTGMC) : http://avisynth.nl/index.php/Yadifmod2
#LoadPlugin("yadifmod2.dll")
# FFT3DFilter v2.10 Plugin (ONLY for Very Slow and Placebo modes) : http://avisynth.nl/index.php/FFT3DFilter
#LoadPlugin("fft3dfilter.dll")
# LoadDLL v1.0 Plugin (ONLY for Very Slow and Placebo modes) : http://avisynth.nl/index.php/LoadDLL
#LoadPlugin("LoadDLL64.dll")
# Loading libfftw3f-3.dll from FFTW v3.3.5(ONLY for Very Slow and Placebo modes) : https://www.fftw.org/
#LoadDLL("libfftw3f-3.dll")
#
# Zs_RF_Shared v1.159 script : http://avisynth.nl/index.php/Zs_RF_Shared
Import("Zs_RF_Shared.avsi")
# QTGMC v3.384s script : http://avisynth.nl/index.php/QTGMC
Import("QTGMC.avsi")
#
# Open video file without audio
FFMpegSource2(filename)
# Open video file with audio track
#FFMpegSource2(filename,atrack=1)
#
# FFMpegSource2 audio and video combined
#A = FFAudioSource(filename)
#V = FFVideoSource(filename)
#AudioDub(V, A)
#
# Converion to YV12 color format: http://avisynth.nl/index.php/ConvertToYV12
ConvertToYV12(interlaced=true)
#ConvertToYV12()
#
# QTGMC mode (Placebo,Very Slow,Slower,Slow,Medium,Fast,Faster,Very Fast,Super Fast,Ultra Fast,Draft)
#QTGMC(preset=mode,Sharpness=0.8)
QTGMC(preset=mode)
#
# Multi-threading requires 'prefetch' and 'SetFilterMTMode' command at the top of qtgmc.avs
#Prefetch(#cores)
Prefetch(cores)
