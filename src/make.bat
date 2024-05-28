::----------------------------------------------------------------------------------------------
:: This script is used to build and deploy the docker image for the application
::----------------------------------------------------------------------------------------------

::----------------------------------------------------------------------------------------------
:: Basic setup
::----------------------------------------------------------------------------------------------

 :: disable echo
@echo off
:: enable delayed expansion within local
setlocal enabledelayedexpansion

::----------------------------------------------------------------------------------------------
:: Script Start
::----------------------------------------------------------------------------------------------

:: try to load the .env file
call :EnvLoadFile .env

:: if no .env file was found then abort
if not !RESULT! == true (
    echo ".env file not found"
    exit /b
)

:: we will need docker to build the image so check if it is installed and running
call :DockerCheckIfInstalled DOCKER_INSTALLED

:: if docker is not installed or running then abort
if not !DOCKER_INSTALLED! == true (
    echo "Docker is not installed or running"
    exit /b
)

if !REGISTRY! == "" (
    echo "no docker registry defined"
    exit /b
)

if !IMAGE! == "" (
    echo "no docker image defined"
    exit /b
)

:: Get the current git hash and use it as the docker image tag
:: Note if TAG is defined in the .env this function will use that instead
call :SetImageTag

:: define the build and push image references
set IMAGE_REF=!REGISTRY!/!IMAGE!:!TAG!
:: to make life easy for local docker testing we will also tag the image as local
set IMAGE_REF_LOCAL=!REGISTRY!/!IMAGE!:local


ECHO "Docker image reference: !IMAGE_REF!"

:: check input args for action
if /i "%1%"=="build" (
    echo "Building the project... for !IMAGE_REF!"
    if /i "%2%"=="full" (
        set DOCKER_BUILDKIT=1
        docker build --progress=plain --no-cache -t !IMAGE_REF! --ssh default .
        docker tag !IMAGE_REF! !IMAGE_REF_LOCAL!
    ) else (
        set DOCKER_BUILDKIT=1
        docker build --progress=plain -t !IMAGE_REF! --ssh default .
        docker tag !IMAGE_REF! !IMAGE_REF_LOCAL!
    )
) else if /i "%1%"=="push" (
    echo "Push the project... for !IMAGE_REF!"
    docker push !IMAGE_REF!
    if /i "%2%"=="latest" (
        set IMAGE_REF_LATEST=!REGISTRY!/!IMAGE!:latest
        docker tag !IMAGE_REF! !IMAGE_REF_LATEST!
        docker push !IMAGE_REF_LATEST!
    )
) else (
    echo "Script Help..."
    echo "Usage: build.sh [build] [full|None]"
    echo "Usage: build.sh [push] [None]"
)


:: exit the script and cleanup the environment
exit /b

::----------------------------------------------------------------------------------------------

:: --------------------------------------------------------------------------------
:: a function to load a .env (passed via parameter 1) into the current environment must use Var=Value format
:: if the successful then set RESULT to true/false if no second parameter is passed
:: otherwise set the second parameter to true/false
:: --------------------------------------------------------------------------------
:EnvLoadFile
IF EXIST %~1 (
    for /F "tokens=1* delims==" %%a in (%~1) do (
        IF "%%b"=="" (
            set %%a=""
        ) ELSE (
            set %%a=%%b
        )
    )
    if "%~2"=="" (
        set RESULT=true
    ) else (
        set %~2=true
    )
) ELSE (
    if "%~2"=="" (
        set RESULT=false
    ) else (
        set %~2=false
    )
)
goto :eof

:: --------------------------------------------------------------------------------
:: a function to check if Docker is installed
:: if docker was installed then set RESULT to true/false if no parameter is passed
:: otherwise set the parameter to true/false
:: --------------------------------------------------------------------------------
:DockerCheckIfInstalled
docker --version >nul 2>&1
if "%~1"=="" (
    if errorlevel 1 (
        set RESULT=false
    ) else (
        set RESULT=true
    )
) else (
    if errorlevel 1 (
        set %~1=false
    ) else (
        set %~1=true
    )
)
goto :eof

:: --------------------------------------------------------------------------------
:: a function to check if a Docker image exists (passed via the first parameter)
:: if the image exists then set RESULT to true/false if no second parameter is passed
:: otherwise set the second parameter to true/false
:: --------------------------------------------------------------------------------
:DockerCheckIfImageExists
docker images %~1  | findstr /i /c:"%~1" >nul
if "%~2"=="" (
    if errorlevel 1 (
        set RESULT=false
    ) else (
        set RESULT=true
    )
) else (
    if errorlevel 1 (
        set %~2=false
    ) else (
        set %~2=true
    )
)
goto :eof

:: Set the image tag based on the TAG environmental variable or the git commit hash otherwise
:SetImageTag
IF DEFINED TAG (
    set "HASH=!TAG!"
    echo "TAG environmental variable found. Setting docker image tag to: !HASH!"
) ELSE (
    where /q git
    IF ERRORLEVEL 1 (
        set TAG=latest
        echo "Git is not installed, setting docker image tag to: !TAG!"
    ) ELSE (
        for /f "delims=" %%i in ('git rev-parse --short HEAD') do set "TAG=%%i"
        echo "Git is installed, setting docker image tag to: !TAG!"
    )
)
goto :eof

