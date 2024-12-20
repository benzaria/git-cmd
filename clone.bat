@echo off
setlocal EnableDelayedExpansion
chcp 65001 >nul

:: Load tokens
call :_load-tokens_

:: Set default values
set "user=benz"
set "repo=git-cmd"
set "branches={main,dev}"

:: Parse arguments
if "%~1" equ "" ( 
   echo  [94mUsage: [93m%~n0 [95m[^<user/repo/branch^>] [92m[Options][0m
   echo   ^>^> for more info : [93m%~n0 [92m--help[0m, [96m-h[0m
   goto :_end_
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

:: Handel invalid arguments
if defined next (
    echo [91mInvalid argument: [0m!arg!
    goto :_end_
)

:: Handel help flag
if defined help call :_help_ & goto :_end_

:: Handel verbose-tokens flag
if defined verbose-tokens call :_verbose-tokens_ & goto :_end_

:: Handle output dirs if defined
if defined outdirs call :_outdirs_

:: Parse user, repo, and branches from arguments or default values
if not defined _arg_ set "_arg_=!user!/!repo!/!branches!"
for /f "tokens=1,2,* delims=/" %%i in ("!_arg_!") do (
    if "%%~i" neq "" if "%%~i" neq "." set "user=%%~i"
    if "%%~j" neq "" if "%%~j" neq "." set "repo=%%~j"
    if "%%~k" neq "" if "%%~k" neq "." set "branches=%%~k"

    set "branches=!branches:{=!"
    set "branches=!branches:}=!"

    ::echo !arg!, !_arg_!, !user!, !repo!, !branches!
    call :_clone_
)

:_end_
endlocal
goto :eof

:_clone_
    if defined save call :_save_
    if not defined token call :_token_
    if defined verbose call :_verbose_
    set /a n = 0
    for %%b in (!branches!) do (
        set "dir_=outdir[!n!]"
        call set "_dir_=%%!dir_!%%"
        if not defined _dir_ set "_dir_=!repo!-%%b"
        curl -H "Authorization: token !token!" -L https://api.github.com/repos/!user!/!repo!/zipball/%%b -o "%temp%\!_dir_!.zip" !save!
        tar -xf "%temp%\!_dir_!.zip" 2>nul
        if exist "!_dir_!" (
            choice /n /d N /t 5 /m "Folder '!_dir_!' already exists. Overwrite? (Y/N): "
            if !errorlevel! neq 1 (
                echo Skipping !_dir_!.
            ) else (
                rmdir /s /q "!_dir_!" 2>nul
                move "!user!-!repo!*" "!_dir_!" 2>nul
            )
        ) else move "!user!-!repo!*" "!_dir_!" 2>nul
        del "%temp%\!_dir_!.zip" 2>nul
        set /a n += 1
    )
    exit /b 0

:: Argument cases
    :--token-save
    :-ts
        call :--token
        call :--save
        exit /b 0

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

    :--verbose-tokens
    :-vt
        set "verbose-tokens=-vt"
        exit /b 0

    :--verbose
    :-v
        set "verbose=-v"
        exit /b 0
    
    :--help
    :-h
        set "help=-h"
        exit /b 0

:: Load token from environment variable
:_token_
    set "user-token=!user: =!-token"
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

:_verbose_
    echo [94mPath: [0m!user!/!repo!/{!branches:~,-1!}
    echo [94mToken: [0m!token!
    exit /b 0

:_verbose-tokens_
    echo [94mSaved tokens:[0m
    for /f "delims=" %%a in (%~f0) do (
        set "token_=%%a"
        if defined parse echo !token_:~5,-2!
        if "!token_!"==":_load-tokens_" set "parse=true"
    )
    if not defined parse echo [91mNo saved tokens found.[0m
    exit /b 0

:: Display help
:_help_
    set _=_help_ _token_ _save_ _outdirs_ _verbose_ _clone_ _end_
    echo [94mUsage: [93m%~n0 [95m[^<user^>/^<repo^>/^<[96mbranch[90m^|[91m{branchs,...}[95m^>] [92m[Options][0m
    echo  you can specify default values for the [96muser[0m, [96mrepo[0m, and [96mbranches[0m
    echo  by setting the [96muser[0m, [96mrepo[0m, and [96mbranches[0m variables at the top of the script.
    echo -----------------------------------------------------------------------------
    echo Options:
    echo   [92m--token[0m, [96m-t [94m^<token^>[0m
    echo       Set the token to use for authentication. If not set, the script will attempt 
    echo       to load the token from the script variables [94m^<user^>-token[0m. Hardcoded tokens
    echo   [92m--save[0m, [96m-s[0m
    echo       Save the token to the script variables. this will hardcode the token in the script
    echo   [92m--token-save, [96m-ts 
    echo       Alias for [92m--token[0m and [92m--save[0m
    echo   [92m--verbose[0m, [96m-v[0m 
    echo       Display Path and token of the current clone operation.
    echo   [92m--verbose-tokens[0m, [96m-vt[0m
    echo       Display all saved tokens in the script.
    echo   [92m--out[0m, [96m-o [90m"[94m<outDirs>[90m"[0m
    echo       Set the output directories to use for the downloaded repositories. 
    echo       If not set, the script will use the repository name and branch name.
    echo       multiple dirs can be set by separating them with a camma, e.g. [90m"[94mdir1, dir2, dir3[90m"[0m.
    echo   [92m--help[0m, [96m-h[0m
    echo       Display this help message.
    echo -----------------------------------------------------------------------------
    echo Exclude this arguments when specifying the options:
    echo  [91m!_![0m
    exit /b 0

:: Load tokens
:_load-tokens_
set "benz-token=github_pat_abcd1234" 
set "benz-token=github_pat_abbkjb34" 
