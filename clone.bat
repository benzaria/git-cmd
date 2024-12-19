@echo off
setlocal EnableDelayedExpansion

:: Load tokens
call :load-tokens

:: Set default values
set "user=benzaria"
set "repo=git-cmd"
set "branches={main,dev}"

:: Parse arguments
if "%~1" equ "" ( 
   echo  [94mUsage: [93m%~n0 [95m[^<user/repo/branch^>] [92m[Options][0m
   echo   ^>^> for more info : [93m%~n0 [0m--help
   exit /b 1
)
set "arg=%*" && set "_arg_="
for %%i in (!arg!) do (
    set "arg=%%~i"
    call :!arg! 2>nul
    if !ErrorLevel! neq 0 (
        if defined next (
            set "!next!=!arg!"
            set "next="
        ) else set "_arg_=!_arg_!!arg! "
    ) 
)

:: Handle output dirs if defined
if defined outdirs call :_outdirs_

:: Parse user, repo, and branches from arguments
for /f "tokens=1,2,* delims=/" %%i in ("!_arg_!") do (
    if "%%~i" neq "" set "user=%%~i"
    if "%%~j" neq "" set "repo=%%~j"
    if "%%~k" neq "" set "branches=%%~k"
    set "branches=!branches:{=! "
    set "branches=!branches:}=! "
    if defined save call :_save_
    if not defined token call :_token_
    set /a n = 0
    for %%b in (!branches!) do (
        set "dir_=outdir[!n!]"
        call set "dir=%%!dir_!%%"
        if not defined dir set "dir=!repo!-%%b"
        curl -H "Authorization: token !token!" -L https://api.github.com/repos/!user!/!repo!/zipball/%%b -o "%temp%\!dir!.zip" !save!
        tar -xf "%temp%\!dir!.zip"
        if exist "!dir!" (
            choice /n /d N /t 5 /m "Folder '!dir!' already exists. Overwrite? (Y/N): "
            if !errorlevel! neq 1 (
                echo Skipping !dir!.
            ) else (
                rmdir /s /q "!dir!"
                move "!user!-!repo!*" "!dir!"
            )
        ) else move "!user!-!repo!*" "!dir!"
        del "%temp%\!dir!.zip"
        set /a n += 1
    )
)

endlocal
goto :eof

:: Argument cases
    :--token
    :-t
        set "next=token"
        exit /b 0
    
    :--save
    :-s
        set "save=-s"
        exit /b 0
    
    :--out
    :-o
        set "next=outdirs"
        exit /b 0
    
    :--help
    :-h
    :-?
        call :_help_
        exit /b 0

:: Load token from environment variable
:_token_
    set "user-token=!user!-token"
    call set "token=%%%user-token%%%"
    exit /b 0

:: Save token to script
:_save_
    echo save: !user: =!-token=!token!
    echo set "!user: =!-token=!token!" >> "%~f0"
    exit /b 0

:: Handle output dirs
:_outdirs_
    set /a n = 0
    for %%i in (!outdirs!) do (
        set "outdir[!n!]=%%i"
        set /a n += 1
    )
    exit /b 0

:: Display help
:_help_
    echo [94mUsage: [93m%~n0 [95m[^<user^>/^<repo^>/^<[96mbranch[90m^|[91m{branchs,...}[95m^>] [92m[Options][0m
    echo  you can specify default values for the [96muser[0m, [96mrepo[0m, and [96mbranches[0m
    echo  by setting the [96muser[0m, [96mrepo[0m, and [96mbranches[0m variables at the top of the script.
    echo.
    echo Options:
    echo   [92m--token[0m, [96m-t [94m^<token^>[0m
    echo       Set the token to use for authentication. If not set, the script will attempt 
    echo       to load the token from the script variables [94m^<user^>-token[0m.
    echo   [92m--save[0m, [96m-s[0m
    echo       Save the token to the script variables. this will hardcode the token in the script.
    echo   [92m--out[0m, [96m-o [90m"[94m<outDirs>[90m"[0m
    echo       Set the output directories to use for the downloaded repositories. 
    echo       If not set, the script will use the repository name and branch name.
    echo       multiple dirs can be set by separating them with a camma, e.g. [90m"[94mdir1, dir2, dir3[90m"[0m.
    echo   [92m--help[0m, [96m-h[0m
    echo       Display this help message.
    exit /b 0

:: Load tokens
:load-tokens
