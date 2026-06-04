# ezQTGMC.cmd

    ezQTGMC.cmd ["/variable=value" [...]] [sourceFolder[\file] [targetFolder]]
    
    a fancy batch frontend for Hunk91's FFmpeg-QTGMC Easy 2025.01.11
    https://forum.videohelp.com/threads/405720-FFmpeg-QTGMC-Easy%21
    accepts file or folder as input and will recursively rebuild to target
    simply drag/drop/copy/paste onto the batch file or use the commandline
    control variables may be assigned directly on the commandline: "/var=val"
    
    videos may be excluded using any criteria returned by ffprobe.exe
    simply set a variable that describes the type of comparison being made
    types are EQU,GEQ,GTR,LEQ,LSS,NEQ (numerals) plus EXC,INC (strings)
    your variable will be header_VariableName; numeralOps work like so:
    ezQTGMC "/LEQ_bit_rate=2097152" excludes files at or below 2mbps
    ezQTGMC "/GTR_duration=600" excludes files longer than 10 minutes
    ezQTGMC "/NEQ_audCount=2" allows only files having exactly 2 audio tracks
    
    EXC/INC are stringOps that contain a list to match the value against:
    ezQTGMC "/EXC_codec_name=h264 h265" excludes files using h264/h265 codecs
    ezQTGMC "/EXC_codec_type=subtitle" excludes files containg any subtitles
    ezQTGMC "/INC_T_language=eng spa jpn" includes only files in these languages
    ezQTGMC "/INC_display_aspect_ratio=4:3" includes only files in 4:3 aspect
    
    use "/peruse=1" to view file details, read the batch file for information
    
    some of the less-obvious user variables
    ---------------------------------------
    iFrames=number of interlaced frames required to use QTGMC (TFF+BFF sample of 100) 0=always(default), 101=never
    logFile=filename for text record of batch activity, no logfile if undefined
    modeQTGMC=if undefined set to 'Faster' (Placebo,Very Slow,Slower,Slow,Medium,Fast,Faster,Very Fast,Super Fast,Ultra Fast,Draft)
    numOfCores=number of processor cores to devote to QTGMC, if undefined set to 50% NUM_OF_PROCESSORS
    peruse=if defined only file information is displayed on screen, no files are processed
    recursive=if defined source folder is recursively searched, if undefined source subfolders are ignored
    reverse=if defined the sort-order is reversed (z-A,9-0), useful for using 2 computers on 1 folder
    sourceDir=source folder, always set to 1st parameter (%1) if present, if undefined display help text and exit
    sourceExt=space-separated list of video file extensions to search for, if undefined set to all I could think of
    subExt=space-separated list of external subtitle file extensions to use, if undefined external subtitles are ignored
    subLang=space-separated list of allowed subtitle language extensions (.en .eng .ja .jpn)
    targetDir=target folder, always set to 2nd parameter (%2) if present, if undefined set to \_%~n0 in same folder as source
    vClip=simple way to quick preview files; -ss #secondsToSkip -t #secondsToKeep"
    
    v0.2 2026/05/26
