# What is skippy
Skippy is a simple tool entirely written in PowerShell, designed to help the management of projects using Docker for Windows. You can manage all your projects without worrying to navigate through your projects to run commands like `docker compose`.
Note that skippy is a personnal project and it is designed for my usage. I do not intend to provide any support and i might have omitted important informations.

## Prerequisites
Skippy is designed to work with the folowing:
- Windows with PowerShell v5.1
- Docker Desktop
- Mutagen - required for speed and easier development by syncing files between the PC and Docker mounted volumes.

## Features
- Manage your dev environements with `skippy project`
  - create & remove projects
  - start, stop & restart projects
  - enable & disable project autostart at docker startup
  - includes assistant for project creation and supports automated creation passing arguments
  - each project has its own image
- Help is displayable for a breakdown of the available commands and their arguments, eg:
  - `skippy help`
  - `skippy project create help`

## Environments available
- Wordpress website with Apache, MariaDB and MySQL and PHP (supports versions 8.2 to 8.4).

## Install Skippy
Open a powershell and run the following commands making sure to replace the values for your case.
First, download skippy and place it wherever you want, for example **C:\Users\You\Documents\skippy**

Add Skippy to the environment variable
Please replace `<skippy_folder_path>` by the absolute path where you placed your skippy folder eg: `C:\Users\You\Documents\skippy`
```bash
  [Environment]::SetEnvironmentVariable("Path", $Env:Path + ";<skippy_folder_path>", "User") 
```
Then set an alias to make skippy callable without having to specify `.ps1`
```bash
Set-Alias -Name skippy -Value "E:\docker\skippy\skippy.ps1" # S
```
If the above command is not permitted because of script execution policy, run this command and retry
```bash
Set-ExecutionPolicy Unrestricted -Scope CurrentUser -Force
```

## TODO
- Allow management of project types by using yml configuration files


