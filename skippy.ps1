param(
    [string]$Command,
    [string]$Subcommand,
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$RemainingArgs
)


# Load Skippy configuration by reading the conf file
$skippyConfFile = Join-Path -Path $PSScriptRoot skippy.conf
if (-Not (Test-Path $skippyConfFile)) {
    Write-Warning "File '$skippyConfFile' does not exist. Please review your Skippy install."
    exit 1;
}
Get-Content $skippyConfFile | foreach-object -begin {$skippyConf=@{}} -process { $k = [regex]::split($_,'='); if(($k[0].CompareTo("") -ne 0) -and ($k[0].StartsWith("[") -ne $True)) { $skippyConf.Add($k[0], $k[1]) } }

# Load dependencies
$incPath = Join-Path -Path $PSScriptRoot -ChildPath "inc"
if (-Not (Test-Path $incPath)) {
    log "Directory '$incPath' does not exist. Please review your Skippy install." 2
    exit 1;
}
foreach ($script in Get-ChildItem -Path $incPath -Filter "*.ps1" -File -Recurse) {
    . $script.FullName
}

# Run docker ps to list containers which will throw an error if docker is not running.
# We capture the error output
$docker_ps_output = docker ps 2>&1
if ($docker_ps_output -match "error during connect") {
    throwError 1 "Docker is not running."
}


# Parse remaining named args
$parsedArgs = parseArguments $RemainingArgs

# Dispatch command
switch ($Command) {

    # PROJECT Section
    "project" {

        # If a string is passed and is different to 'help', we assume this is the name of the project
        if($parsedArgs.ContainsKey(0)) {
            if($parsedArgs[0] -ne 'help') {
                $parsedArgs['appName'] = $parsedArgs[0]
            }
        }

        switch ($Subcommand) {
            'list' {
                showAvailableProjects
            }
            'create' {

                # Allows help display if "help" is only argument passed
                if($parsedArgs.ContainsKey(0)) {
                    if($parsedArgs[0] -eq 'help') {
                        displayHelp('project-create')
                    }
                }

                # We will call the command depending of what the user provided
                $fnArgs = @{
                    'appName' = ''
                    'platform' = ''
                    'phpVersion' = ''
                    'psVersion' = ''
                    'db_user' = ''
                    'db_password' = ''
                    'db_name' = ''
                    'db_table_prefix' = ''
                    'startAfterCreation' = $true
                    'nobuild' = $false
                    'nosync' = $false
                    'recreate' = $false
                }
                $argString = getArgsFormatted $fnArgs $parsedArgs

                Invoke-Expression "CreateProject $argString"

            }
            'disableAutoStart' {
                if($parsedArgs['appName']) {
                    DisableAutoStart -appName $parsedArgs['appName']
                } else {
                    DisableAutoStart
                }
            }
            'enableAutoStart' {
                if($parsedArgs['appName']) {
                    EnableAutoStart -appName $parsedArgs['appName']
                } else {
                    EnableAutoStart
                }
            }
            'remove' {
                if($parsedArgs['appName']) {
                    RemoveProject -appName $parsedArgs['appName']
                } else {
                    RemoveProject
                }
            }
            'start' {
                if($parsedArgs['appName']) {
                    StartProject -appName $parsedArgs['appName']
                } else {
                    StartProject
                }
            }
            'stop' {
                if($parsedArgs['appName']) {
                    StopProject -appName $parsedArgs['appName']
                } else {
                    StopProject
                }
            }
            'restart' {
                if($parsedArgs['appName']) {
                    RestartProject -appName $parsedArgs['appName']
                } else {
                    RestartProject
                }
            }
            'startMutagen' {
                if($parsedArgs['appName']) {
                    startMutagenForProject -appName $parsedArgs['appName']
                } else {
                    startMutagenForProject
                }
            }
            'stopMutagen' {
                if($parsedArgs['appName']) {
                    stopMutagenForProject -appName $parsedArgs['appName']
                } else {
                    stopMutagenForProject
                }
            }
            'help' {
                displayHelp 'project'
            }
            default {
                displayHelp 'project'
            }
        }
    }
    # END PROJECT Section =====================================

    "help" {
        displayHelp 'skippy'
    }
    default {
        if($command -eq "") {
            displayHelp 'skippy'
        } else {
            throwError 1 "Unknown command '$Command'"
        }
    }
}

