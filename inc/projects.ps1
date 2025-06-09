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

# Function that reads the header config in project's docker-compose.yml
function getSkippySettingsForProject {
    param (
        [Parameter(Mandatory = $true)]
        [string]$appName
    )

    $projectPath = getProjectPath $appName
    $filePath = Join-Path $projectPath 'docker-compose.yml'

    # Check if file exists
    if (-not (Test-Path $filePath)) {
        throwError 1 "❌ Docker compose not found : $filePath"
    }

    # Reads the file
    $lines = Get-Content $filePath

    # Look for start and stop tags
    $startIndex = $lines | Select-String -Pattern '#skippy-start-conf' | Select-Object -First 1
    $endIndex = $lines | Select-String -Pattern '#skippy-end-conf' | Select-Object -First 1

    if (-not $startIndex -or -not $endIndex) {
        log "❌ Skippy conf headers are missing or incomplete." 2
        return $null
    }

    # Get lines between start and stop tags
    $configLines = $lines[($startIndex.LineNumber)..($endIndex.LineNumber - 1)]

    # Initialise the hashtable
    $config = @{}

    # Read the configuration lines ont by one
    foreach ($line in $configLines) {
        # Ignore lines without "="
        if ($line -match '^#(\w+)\s*=\s*(.+)$') {
            $key = $matches[1].Trim()
            $value = $matches[2].Trim()
            $config[$key] = $value
        }
    }

    return $config
}

# Fucntion that returns true if a project exists, false otherwise.
function projectExists {
    param (
        [Parameter(Mandatory = $true)]
        [string]$appName
    )
    
    $projects = getAvailableProjects
    return $projects.ContainsKey($appName)
}

# returns an array of the mutagen sync sessions name for a given project
function getMutagenSessionsForApp {
    param (
        [string]$appName
    )

    $projectPath = getProjectPath $appName

    if(-not (Test-Path $projectPath)) {
        throwError 1 "App $appName does not exists"
    }

    # We read the headers in the docker compose which contains the list of pathes to sync
    $projectConf = getSkippySettingsForProject $appName

    # File is stored in project's dir
    # If it does not exists, we just start the session without it
    $mutagenConfFile = Join-Path $projectPath "conf/mutagen.yml"
    $confFileArg = ''
    if(Test-Path $mutagenConfFile) {
        $confFileArg = "--configuration-file=$mutagenConfFile"
    }

    # We prepare the additional arguments for the mutagen session such as default user, default group...
    $additional_args = ''
    if($projectConf.ContainsKey('mutagenargs')) {
        $adtl_args = $projectConf['mutagenargs']-split ','
        if($adtl_args.Count -gt 0) {
            foreach($adtl_arg in $adtl_args) {
                $split_arg = $adtl_arg -split ':'
                if($split_arg.Count -ne 2) {
                    log "Argument $adtl_arg is wrongly formatted and thus it has been ignored" 2
                    continue
                }
                $adtl_arg_key = $split_arg[0]
                $adtl_arg_val = $split_arg[1]
    
                $additional_args = "$additional_args --$adtl_arg_key=$adtl_arg_val "
    
            }
        }
        
    }

    # get data about opened sessions
    $sessions = @()
    $output = mutagen sync list

    $pathes = $projectConf['mutagensync'] -split ','
    foreach($path in $pathes) {
        $split_path = $path -split ':'
        if($split_path.Count -ne 2) {
            throwError 1 'Can not enable Mutagen for project - pathes are wrongly formatted'
        }

        $local = Join-Path $projectPath $split_path[0]
        $remote = $split_path[1]
        $identifier = Split-Path $local -Leaf # we use out local folder name as identifier for mutagen sync session name (warning: folders with same name will induce conflicts!)
        
        $sessionName = "$appName-$identifier"
        $session = @{
            localPath = $local
            remotePath = "docker://$remote"
            name = $sessionName
            args = $additional_args
            confFileArg = $confFileArg
            status = 'inactive'
        }

        
        if ($output) {
            # We read the output of mutagen sync list
            # the goal is to check if a session exists for the pathes in the app configuration
            $currentSession = ''
            foreach ($line in $output) {

                #If we are reading a session name line while the flag is true, we know we are checking an other sync session.
                if($line -match "Name:\s+$sessionName\S*" -and ($currentSession -eq $sessionName)) {
                    $currentSession = ''
                }

                # The session belongs to the app, we add it to the list
                if($line -match "Name:\s+$sessionName\S*") {
                    $session.status = 'active'
                    $currentSession = $sessionName
                }

                # We also read the status if the app
                if(($currentSession -eq $sessionName) -and ($line -match "Status:\s+\[Paused\]\S*")) {
                    $session.status = 'paused'
                }

            }
        }

        $sessions += $session

    }
    
    return $sessions
}