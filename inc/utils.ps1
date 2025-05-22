# allows skippy to parse CLI arguments
# returns an array of $arg => $value
function parseArguments {
    param(
        [string[]]$RemainingArgs
    )

    $parsed = @{}
    for ($i = 0; $i -lt $RemainingArgs.Count; $i++) {

        # If the tested string starts with '-', we know we want to assign a value with a key named after the stirng.
        if ($RemainingArgs[$i] -like "-*") {
            $key = $RemainingArgs[$i].TrimStart("-")

            # We check if the following string does not start with '-', which mean the user provided a value
            # if no value is provided, we assume the parameter is a flag, ie a boolean set to true
            if ($i + 1 -lt $RemainingArgs.Count) {
                # there is indeed a following string

                # we check whether it is a value for our parameter or a flag
                if($RemainingArgs[$i + 1] -notlike "-*") {
                    $i++; # increment so that we check the next parameter
                    $value = $RemainingArgs[$i]
                } else {
                    $value = $true
                }

            }
            
            $parsed[$key] = $value
        } else {

            # the argument was not named, so we just fill with whatever value was passed
            $parsed[$i] = $RemainingArgs[$i]

        }

    }

    return $parsed
}

# Returns a normalized string that removes special characters etc for a proper app name.
function normalizeAppName {
    param (
        [string]$thevalue
    )

    if ([string]::IsNullOrWhiteSpace($thevalue)) {
        throwError 1 "⛔ Parameter 'appname' is empty."
    }

    # Take care of french special characters, jic
    $map = @{
        'à' = 'a'; 'â' = 'a'; 'ä' = 'a';
        'á' = 'a'; 'ã' = 'a'; 'å' = 'a';
        'é' = 'e'; 'è' = 'e'; 'ê' = 'e'; 'ë' = 'e';
        'í' = 'i'; 'ì' = 'i'; 'î' = 'i'; 'ï' = 'i';
        'ó' = 'o'; 'ò' = 'o'; 'ô' = 'o'; 'ö' = 'o'; 'õ' = 'o';
        'ú' = 'u'; 'ù' = 'u'; 'û' = 'u'; 'ü' = 'u';
        'ç' = 'c'; 'ñ' = 'n';
        'æ' = 'ae'; 'œ' = 'oe'
    }

    $normalized = ""
    foreach ($char in $thevalue.ToCharArray()) {
        if ($map.ContainsKey($char -as [string])) {
            $normalized += $map[$char -as [string]]
        } else {
            $normalized += $char
        } 
    }

    # Remove characters that are not letters nor numbers but _ and -
    return $normalized.ToLower() -replace '[^a-z0-9_\-]', ''
}

# Used to check if a path we want to work on is in the allowed wordking directory.
function assertInDirectory {
    param (
        [string]$path,
        [string]$allowedRoot
    )

    if (-not ($path -like "$allowedRoot*")) {
        throwError 1 "❌ Outside working dir! ($path)"
    }
}

# Generates a password.
function generatePassword { 
    do { 
        $userPassword = -join (
            ((35..38) + 33 + 42 + 43 + (48..57) + 61 + (63..90) + (97..122)) |
            Get-Random -Count 12 |
            ForEach-Object { [char]$_ }
        ) 
    } until ( $userPassword -cmatch '(?=.*\d)(?=.*[a-z])(?=.*[A-Z])(?=.*[@#$%]).{12,40}' )

    return $userPassword
}

# Generates a simple string og $theLength characters long. Usefull for random username or prefix.
function generateName { 
    param (
        [Parameter(Mandatory = $false)]
        [int]$theLength = 9
    )

    do {
        $name = -join (
            (97..122 | Get-Random -Count $theLength) |
            ForEach-Object { [char]$_ }
        )
    } until ($name.Length -ge $theLength)

    return $name
}

# Throws an error and terminate the script
# Can display custom message by providing a string as second argument
function throwError { 
    param (
        [Parameter(Mandatory = $true)]
        [int]$exitCode,

        [Parameter(Mandatory = $false)]
        [string]$errorMessage = ""
    )
    
    # write specified error message if provided
    if($errorMessage -eq "") {
        $message = $Script:exits[$exitCode]
    } else {
        $message = $errorMessage
    }

    Write-Host -ForegroundColor Black -BackgroundColor Red "[ERROR] - $message"

    exit $exitCode
}

# Returns the value of the specified key in skippy.conf
function getConf {
        param (
        [Parameter(Mandatory = $true)]
        [string]$key
    )

    return $Script:skippyConf[$key]
}

function log {
    # -1 = success
    # 0 = debug 
    # 1 = info
    # 2 = warning
    # 3 = important
    # 4 = error
    param (
        [Parameter(Mandatory = $true)]
        [string]$message,

        [Parameter(Mandatory = $false)]
        [ValidateSet(-1, 0, 1, 2, 3, 4)] 
        [int]$severity = 1
    )

    if( $severity -eq 0 -1 ) {
        Write-Host -ForegroundColor Black -BackgroundColor Green "✅ Success - $message"
    } elseif( $severity -eq 0 ) {
        if((getConf 'debug') -eq 1) {
            # Log debug level only in debug mode
            Write-Host -ForegroundColor DarkGray -BackgroundColor Black "Debug - $message"
        }
    } elseif($severity -eq 1) {
        Write-Host "Info - $message"
    } elseif($severity -eq 2) {
        Write-Warning $message
    } elseif($severity -eq 3) {
        Write-Host -ForegroundColor Red -BackgroundColor Black "IMPORTANT - $message"
    } elseif($severity -eq 4) {
        throwError 1 $message
    } else {
        # default
        Write-Host "Log - $message"
    }


}

# Function that returns a string of argument to use in a dynamically generated function call
# Takes an array or argument names and a set of value. the set of values must be a map with the same keys as the argument name list.
function getArgsFormatted {
    param (
        [Parameter(Mandatory = $true)]
        [hashtable]$fnArgs,

        [Parameter(Mandatory = $true)]
        [hashtable]$parsedArgs
    )

    # Use what the user provided
    $paramsFormatted = @{}
    foreach($theKey in $fnArgs.Keys) {
        if($parsedArgs.ContainsKey($theKey)) {
            $paramsFormatted[$theKey] = $parsedArgs[$theKey]
        }
    }
    
    # Join the parameters into a string: -param1 'value1' -param2 'value2'
    $argString = ($paramsFormatted.GetEnumerator() | ForEach-Object {
        # no quotes for bool values
        if( ($_.Value -eq 0) -or ($_.Value -eq $false) ) {
            "-$($_.Key) `$false"
        } elseif( ($_.Value -eq 1) -or ($_.Value -eq $true) ) {
            "-$($_.Key) `$true"
        } else {
            "-$($_.Key) '$($_.Value)'"
        }
    }) -join ' '

    return $argString

}

function getProjectsPath {
    return Join-Path (getConf 'dockerPath') 'projects'
}

# Returns the path of a given project
function getProjectPath {
    param (
        [Parameter(Mandatory = $true)]
        [string]$appName
    )

    return Join-Path (getProjectsPath) $appName 

}

# Returns an array of the available projects with relevant infos.
function getAvailableProjects {

    $availableProjects = @{}
    $projectsPath = getProjectsPath

    $folders = Get-ChildItem $projectsPath
    if($folders.Count -ile 0) {
        return $availableProjects
    }

    foreach ($folder in $folders) {
        $folderName = $folder.Name
    
        # Check if a Docker container with that name exists (running or stopped)
        # We must go to the Docker directory to be able to do that

        $containers = docker ps -a --filter "name=$folderName$" --format "{{.Names}}"
        if ($containers.Count -gt 0) {
            # We found at least one container so we know a project exists in docker
            # Let's gather some stats
            # TODO: Gather more stats :)

            # Check if all services are running
            $running_containers = 0
            foreach($container in $containers) {
                $status = (docker inspect -f '{{.State.Status}}' $container)
                if($status -eq 'running') {
                    $running_containers++
                }
            }
            # Add some quick visuals
            if($running_containers -eq 0) {
                $emoji = '❌'
                $status_message = 'Not running'
            } elseif($running_containers -eq $containers.Count) {
                $emoji = '✅'
                $status_message = 'OK'
            } else {
                # some containers are running but not all
                $emoji = '⚠️'
                $status_message = 'Need attention'
            }

            $availableProjects[$folder.Name] = @{
                'status' = "$emoji $status_message"
                'services_running' = ($running_containers -as [string]) + '/' + ($containers.Count -as [string]) + ' running'
                'integrity' = 'OK'
                'running' = ($running_containers -eq $containers.Count)
            }
        } else {
            $availableProjects[$folder.Name] = @{
                'status' = '⚠️ Need attention'
                'services_running' = '0/0'
                'integrity' = 'Files found on disk but there is no container assigned.'
                'running' = $false
            }
        }
    }

    return $availableProjects

}