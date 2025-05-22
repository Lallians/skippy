function CreateProject {
    param(

        [Parameter(Mandatory=$true)]
        [string]$appName,

        [Parameter(Mandatory=$true)]
        [ValidateSet("wordpress", "prestashop", "symfony-react")]
        [string]$platform,
    
        [Parameter(Mandatory=$false)]
        [ValidateSet("8.2", "8.3", "8.4")]
        [string]$phpVersion = "8.2",
    
        [Parameter(Mandatory=$false)]
        [string]$db_password = "",
    
        [Parameter(Mandatory=$false)]
        [string]$db_user = "",
    
        [Parameter(Mandatory=$false)]
        [string]$db_name = "",
    
        [Parameter(Mandatory=$false)]
        [string]$db_table_prefix = "",

        [Parameter(Mandatory=$false)]
        [bool]$startAfterCreation = $true
    
    )

    $appNameNormalized = NormalizeAppName $appName

    if($appNameNormalized -ne $appName) {
        log "Your project is renamed from '$appName' to '$appNameNormalized' for better usage." 2
    }

    # define variables
    $skippyPath = getConf 'skippyPath'
    $templatePath = Join-Path $skippyPath 'templates'
    $projectPath = getProjectPath $appNameNormalized
    $wwwPath     = Join-Path $projectPath 'www'
    $dbPath      = Join-Path $projectPath 'db'
    $gitignoreFile = Join-Path $skippyPath 'gitignores\.gitignore-default'

    # Check directories jic
    assertInDirectory -path $projectPath -allowedRoot $allowedRoot
    assertInDirectory -path $dbPath -allowedRoot $allowedRoot

    # Prepare variables that are shared amongst all templates aswell as the .env file
    # The keys of $templateVars are the placeholders in the template
    $templateVars = @{
        '{{APPNAME_NORMALIZED}}' = $appNameNormalized
        '{{PHP_VERSION}}' = $phpVersion
    }
    $envVars = @{}

    
    # We define the template we use according to the platform
    # TODO: make other platforms!
    if($platform -eq 'wordpress') {
        $templateFile = Join-Path $templatePath 'docker-compose-wordpress.yml'
        $gitignoreFile = Join-Path $skippyPath 'gitignores\.gitignore-wordpress'

        # on met en place des valeurs générées si non définies pas l'utilisateur
        if($db_user -eq "") {
            $db_user = $appNameNormalized
        }
        if($db_password -eq "") {
            $db_password = generatePassword
        }
        if($db_name -eq "") {
            $db_name =  $db_user
        }
        if($db_table_prefix -eq "") {
            $db_table_prefix =  (generateName -theLength 3) + "_"
        }
    
        $envVars['APP_DB_USER'] = $db_user
        $envVars['APP_DB_PASSWORD'] = $db_password
        $envVars['APP_DB_NAME'] = $db_name
        $envVars['APP_DB_TABLE_PREFIX'] = $db_table_prefix
    
    #} elseif($platform -eq 'prestashop') {
    #    $templateFile = "$templatePath\docker-compose-template-prestashop.yml"
    #} elseif($platform -eq 'symfony-react') {
    #    $templateFile = "$templatePath\docker-compose-template-sf-react.yml"
    } else {
        echo $exits[4] $platform
        exit 4
    }
    
    # Check if template exists jic
    if (-not (Test-Path $templateFile)) {
        throwError 3 "$($exits[3]) $templateFile"
    }
    
    # Replace placeholders with actual values
    $templateContent = Get-Content $templateFile -Raw
    foreach ($key in $templateVars.Keys) {
        $templateContent = $templateContent -replace $key, $templateVars[$key]
    }
    
    # Don't forget the mutagen conf file and replace placeholders
    $mutagenTemplateFile   = Join-Path $templatePath "mutagen.yml"
    $mutagenFileContent = Get-Content $mutagenTemplateFile -Raw
    foreach ($key in $templateVars.Keys) {
        $mutagenFileContent = $mutagenFileContent -replace $key, $templateVars[$key]
    }

    # Format .env file
    $envFileContent = ""
    foreach ($key in $envVars.Keys) {
        $envFileContent += $key + "='" + $envVars[$key] + "'" + "`n"
    }
    
    # Last check to abort if the project exists or there are leftovers from old project
    if (Test-Path $wwwPath) {
        throwError 5
    } elseif(Test-Path $dbPath) {
        throwError 5
    }
    
    # Create folders
    New-Item -ItemType Directory -Force -Path $wwwPath | Out-Null
    New-Item -ItemType Directory -Force -Path $dbPath | Out-Null
    
    # Check if folders was created successfully
    if (-not (Test-Path $wwwPath) -or -not (Test-Path $dbPath)) {
        throwError 2
    }
    
    # Write files docker-compose.yml and .env
    $templateContent | Out-File -Encoding UTF8 -FilePath (Join-Path $projectPath "docker-compose.yml")
    $mutagenFileContent | Out-File -Encoding UTF8 -FilePath (Join-Path $projectPath "mutagen.yml")
    $envFileContent | Out-File -Encoding UTF8 -FilePath (Join-Path $projectPath '.env')
    cat $gitignoreFile | Out-File -Encoding UTF8 -FilePath (Join-Path $projectPath '.gitignore')
    
    $message = "Project '$appNameNormalized' successfully created in: $projectPath"

    Push-Location $projectPath
    if($startAfterCreation) {
        docker compose up -d
        $message = "$message - Container started."
        $message = "$message`n Accessible to https://$appName.docker.localhost"

        # Don't forget to enable Mutagen for file synchronization
        startMutagenForProject $appNameNormalized
    } else {
        docker compose create
        $message = "$message - Container created."
    }
    Pop-Location

    log $message -1

}


function DisableAutoStart {
    param(
        [Parameter(Mandatory=$true)]
        [string]$appName
    )

    # get list of container IDs related to the app
    $IDs = docker ps -f name=$appName -a --format '{{.ID}}'
    
    if($IDs.Count -gt 0) {
        foreach($id in $IDs) {
            docker update --restart=no $id > $null
            log '✅ Auto start DISABLED'
        }
    } else {
        log "No container found for app $appName" 4
    }

}

function EnableAutoStart {
    param(
        [Parameter(Mandatory=$true)]
        [string]$appName
    )

    # get list of container IDs related to the app
    $IDs = docker ps -f name=$appName -a --format '{{.ID}}'
    
    if($IDs.Count -gt 0) {
        foreach($id in $IDs) {
            docker update --restart=always $id > $null
            log '✅ Auto start ENABLED'
        }
    } else {
        log "No container found for app $appName" 4
    }
    
}


function RemoveProject {
    param(
        [Parameter(Mandatory=$true)]
        [string]$appName
    )

    # Check if folder exists. if not, just log an error because the container can not exist without the folders.
    $projectPath = getProjectPath $appName
    $wwwPath     = Join-Path $projectPath 'www'
    $dbPath      = Join-Path $projectPath 'db'
    if(-not (Test-Path $wwwPath) -and -not (Test-Path $dbPath)) {
        log "There is no project named '$appName'" 4
    }

    # If exists, we check if a container aleady exists for the project and delete it
    $IDs = docker ps -f name=$appName -a --format '{{.ID}}'
    if($IDs.Count -eq 0) {
        log "No container was found for project '$appName'. Going to remove folders only."
    } 

    # No need to remove every containers one by one since docker compose will read the docker-compose file and act accordingly
    # We go to the folder, turn the container off and remove it, then we go back to where we were

    # We just ask for confirmation jic xD
    $confirmation = ''
    while((($confirmation -ne 'y') -and ($confirmation -ne 'n')) -and (($confirmation -ne 'yes') -and ($confirmation -ne 'no'))) {
        $confirmation = Read-Host "Are you sure you want to delete the project $appName ? [y]es/[n]o"
    }

    if(($confirmation -eq 'y') -or ($confirmation -eq 'yes')) {
        # delete the docker part...
        Push-Location $projectPath
        docker compose down
        Pop-Location
        # then delete the files

        # Just be sure to delete a valid project!
        assertInDirectory $projectPath
        rm $projectPath -r -fo

    } else {
        # Abort no matter what the user prompted if neither 'y' or 'yes'
        log 'Aborting...'
        exit 0
    }
    
    log "Project $appName successfully deleted !" -1

    exit 0

}

# Function that shows the available projects and terminate the script
function showAvailableProjects {

    $availableProjects = getAvailableProjects

    if($availableProjects.Count -eq 0) {
        log 'No project have been found.' 1
        exit 0
    }

    $availableProjects.GetEnumerator() | ForEach-Object {
        Write-Host "$($_.Key):"
        foreach ($kv in $_.Value.GetEnumerator()) {
            Write-Host "  $($kv.Key): $($kv.Value)"
        }
    }

    exit 0

}


# Essentially performs a docker compose start on the project.
function StartProject {
    param(
        [Parameter(Mandatory=$true)]
        [string]$appName
    )

    $projects = getAvailableProjects

    if(-not $projects.ContainsKey($appName)) {
        log "App $appName does not exists." 4
    }

    if($projects[$appName].running) {
        log "App $appName is already running." 4
    }

    Push-Location (getProjectPath $appName)
    docker compose start
    Pop-Location
    
    # Start file sync silently
    startMutagenForProject $appName > $null

}

# Essentially performs a docker compose stop on the project.
# Also removes file sync to save resources.
function StopProject {
    param(
        [Parameter(Mandatory=$true)]
        [string]$appName
    )

    $projects = getAvailableProjects

    if(-not $projects.ContainsKey($appName)) {
        log "App $appName does not exists." 4
    }

    if(-not $projects[$appName].running) {
        log "App $appName is not running." 4
    }

    Push-Location (getProjectPath $appName)
    docker compose stop
    Pop-Location

    # Stop file sync silently
    stopMutagenForProject $appName > $null

}

# Creates the mutagen sync session for the given project
function startMutagenForProject {
    param (
        [Parameter(Mandatory = $true)]
        [string]$appName
    )

    $projectPath = getProjectPath $appName
    $wwwPath = Join-Path $projectPath 'www'

    # File is stored in project's dir
    $mutagenConfFile = Join-Path $projectPath mutagen.yml

    # If it does not exists, we just start the session without it
    $confFileArg = ''
    if(Test-Path $mutagenConfFile) {
        $confFileArg = "--configuration-file=$mutagenConfFile"
    }

    # We need to specify the default owneship because mutagen sets it to root otherwise which breaks the app
    Invoke-Expression "mutagen sync create $wwwPath docker://container-$appName/var/www/html --name=$appName-www --default-file-mode-beta=0644 --default-directory-mode-beta=0755 --default-owner-beta=www-data --default-group-beta=www-data $confFileArg"
    exit 0

}

# Removes the mutagen sync session for the given project
function stopMutagenForProject {
    param (
        [Parameter(Mandatory = $true)]
        [string]$appName
    )

    Invoke-Expression "mutagen sync terminate $appName-www"

}