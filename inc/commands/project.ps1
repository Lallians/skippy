# This function is responsible for the project creation.
function CreateProject {
    param(

        [Parameter(Mandatory=$true)]
        [string]$appName,

        # We allow some aliases
        [Parameter(Mandatory=$true, HelpMessage="One of: wordpress, prestashop, symfony-angular")]
        [ValidateSet(
            "wordpress", "wp", 
            "prestashop", "ps",
            "symfony-angular", "sfng"
        )]
        [string]$platform,
    
        [Parameter(Mandatory=$false)]
        [ValidateSet("8.0", "8.2")]
        [string]$phpVersion = "8.2",

        [Parameter(Mandatory=$false)]
        [ValidateSet("8.2"<#, "9.0"#>)]
        [string]$psVersion = "8.2",
    
        [Parameter(Mandatory=$false)]
        [string]$db_password = "",
    
        [Parameter(Mandatory=$false)]
        [string]$db_user = "",
    
        [Parameter(Mandatory=$false)]
        [string]$db_name = "",
    
        [Parameter(Mandatory=$false)]
        [string]$db_table_prefix = "",

        [Parameter(Mandatory=$false)]
        [bool]$startAfterCreation = $true,

        [Parameter(Mandatory=$false)]
        [bool]$noBuild = $false,

        [Parameter(Mandatory=$false)]
        [bool]$noSync = $false,

        [Parameter(Mandatory=$false)]
        [bool]$recreate = $false # CAUTION: Removes any existing container or files for the given app. useful if creation failed and need to recreate.
    
    )


    # startAfterCreation and nobuild are not compatible.
    # if nobuild is set to true, we will set startAftercreation to false and vice versa.
    if($noBuild) {
        $startAfterCreation = $false
    }
    if($startAfterCreation) {
        $noBuild = $false
    }


    # We allow some aliases
    if($platform -eq 'sfng') {
        $platform = 'symfony-angular'
    } elseif($platform -eq 'wp') {
        $platform = 'wordpress'
    } elseif($platform -eq 'ps') {
        $platform = 'prestashop'
    }

    # We normalize the app name since we will use it as identifier and we want it as simple as possible.
    # For example, remove accents and special characters.
    $appNameNormalized = NormalizeAppName $appName

    if($appNameNormalized -ne $appName) {
        log "Your project is renamed from '$appName' to '$appNameNormalized' for better usage." 2
    }


    # The goal is:
    # to copy the base structure and files into the projects directory
    # and then add dynamic files that contains the app's cstom parameters (dockerfiles...)


    # define variables
    $skippyPath = getConf 'skippyPath'

    $structPath = Join-Path $skippyPath 'struct'
    $structPath_dockercomposes = Join-Path $structPath 'docker-compose'
    $structPath_dockerfile = Join-Path $structPath 'dockerfile'
    $structPath_projectStruct = Join-Path $structPath 'project_struct'
    $structPath_conf = Join-Path $structPath 'conf'
    $structPath_gitignore = Join-Path $structPath 'gitignore'

    $projectPath = getProjectPath $appNameNormalized
    $gitignoreFile = Join-Path $structPath_gitignore '.gitignore-default'

    # Check directories jic
    assertInDirectory -path $projectPath

    # And check if the project exists or there are leftovers from old project
    # We dont check in case we want to recreate.
    if ((Test-Path $projectPath) -and (-not $recreate)) {
        throwError 1 '❗ Project already exists! Aborting...'
    }


    # First we remove the previous project if specified to do so. Ask a validation JIC
    if($recreate) {
        log 'THIS WILL REMOVE THE CURRENT PROJECT IF IT EXISTS.' 2
        $confirmation = Read-Host "Do you really want to recreate $appName ? [y]es/[n]o"
        if(($confirmation -eq 'y') -or ($confirmation -eq 'yes')) {
            RemoveProject $appName $true
        } else {
            log 'Aborting...'
            exit 0
        }
    }


    # Prepare variables that are shared amongst all templates aswell as the .env file
    # The keys of $templateVars are the placeholders in the template
    $templateVars = @{
        '{{APPNAME_NORMALIZED}}' = $appNameNormalized
        '{{PHP_VERSION}}' = $phpVersion
    }
    $envVars = @{}

    
    # We define the template we use according to the platform and the variables according to user specifications.
    # We also prepare the files we will write depending on the platform in $filesToWrite.
    # $filesToWrite must contain items in the form of: 
    # @{
    #   'type' = 'content'|'file' # 'content' for outputting content (replacing placeholders), 'file' to copy a file from here to there
    #   'target' = $path_of_target_file
    #   'value' = "$the_content_or_the_file_path"
    # }
    # TODO: make other platforms!
    $filesToWrite = @{}
    if($platform -eq 'wordpress') {

        $dockercomposeTemplate = Join-Path $structPath_dockercomposes 'docker-compose-wordpress.yml'
        $gitignoreFile = Join-Path $structPath_gitignore '.gitignore-wordpress'

        # Set up random values if user did not define any
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
    
    } elseif($platform -eq 'symfony-angular') {

        $dockercomposeTemplate = Join-Path $structPath_dockercomposes 'docker-compose-sfng.yml'

        # Set up random values if user did not define any
        if($db_user -eq "") {
            $db_user = $appNameNormalized
        }
        if($db_password -eq "") {
            $db_password = generatePassword
        }
        if($db_name -eq "") {
            $db_name =  $db_user
        }

        $envVars['APP_DB_USER'] = $db_user
        $envVars['APP_DB_PASSWORD'] = $db_password
        $envVars['APP_DB_NAME'] = $db_name

        # We will copy the dockerfiles
        $filesToWrite.Add($filesToWrite.Count, @{
            'type' = 'content'
            'target' = Join-Path $projectPath 'Dockerfile_symfony'
            'value' = assignVarsInTemplate (Join-Path $structPath_dockerfile 'Dockerfile_symfony') $templateVars
        })
        $filesToWrite.Add($filesToWrite.Count, @{
            'type' = 'content'
            'target' = Join-Path $projectPath 'Dockerfile_angular'
            'value' = assignVarsInTemplate (Join-Path $structPath_dockerfile 'Dockerfile_angular') $templateVars
        })

    } elseif($platform -eq 'prestashop') {
        $dockercomposeTemplate = Join-Path $structPath_dockercomposes 'docker-compose-prestashop.yml'

        $templateVars['{{PS_VERSION}}'] = $psVersion
        $envVars['PS_VERSION'] = $psVersion

        # Set up random values if user did not define any
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
    
        $adminPass = generatePassword
        $adminUser = "admin@$appNameNormalized.docker.localhost"
        $adminDir =  'admin' + (generateName)

        $envVars['APP_DB_USER'] = $db_user
        $envVars['APP_DB_PASSWORD'] = $db_password
        $envVars['APP_DB_NAME'] = $db_name
        $envVars['APP_DB_TABLE_PREFIX'] = $db_table_prefix
        $envVars['BO_ADMIN_USER'] = $adminUser
        $envVars['BO_ADMIN_PASSWD'] = $adminPass
        $envVars['PS_VERSION'] = $psVersion

        $templateVars['{{APP_NAME}}'] = $appNameNormalized
        $templateVars['{{APP_DOMAIN}}'] = "$appNameNormalized.docker.localhost"
        $templateVars['{{PS_VERSION}}'] = $psVersion
        $templateVars['{{APP_ADMIN_DIR}}'] = $adminDir

        # We will copy the dockerfiles
        $filesToWrite.Add($filesToWrite.Count, @{
            'type' = 'content'
            'target' = Join-Path $projectPath 'Dockerfile_prestashop'
            'value' = assignVarsInTemplate (Join-Path $structPath_dockerfile 'Dockerfile_prestashop') $templateVars
        })

    } else {
        throwError 1 "❌ Template does not exists for platform: $platform"
    }
    
    # Check if template exists jic
    if (-not (Test-Path $dockercomposeTemplate)) {
        throwError 1 "❌ Template not found: $dockercomposeTemplate"
    }
    
    # Replace placeholders with actual values
    $dockercomposeContent = assignVarsInTemplate $dockercomposeTemplate $templateVars

    # Format .env file
    # Todo: handle bool / numeric values ?
    $envFileContent = ""
    foreach ($key in $envVars.Keys) {
        $envFileContent += $key + "='" + $envVars[$key] + "'" + "`n"
    }
    

    # Prepare the common files to write
    $filesToWrite.Add($filesToWrite.Count, @{
        'type' = 'content'
        'target' = Join-Path $projectPath 'docker-compose.yml'
        'value' = $dockercomposeContent 
    })
    $filesToWrite.Add($filesToWrite.Count, @{
        'type' = 'content'
        'target' = Join-Path $projectPath '.env'
        'value' = $envFileContent
    })
    #$filesToWrite.add($filesToWrite.Count, @{
    #    'type' = 'file'
    #    'target' = Join-Path $projectPath 'mutagen.yml'
    #    'value' = Join-Path $structPath_conf 'mutagen.yml'
    #})


    # Create base project structure
    Copy-Item -Recurse (Join-Path $structPath_projectStruct $platform) $projectPath # base structure
    
    # Check if directory was created successfully
    if (-not (Test-Path $projectPath)) {
        throwError 2
    }
    
    # Write project files
    foreach ($fileToWrite in $filesToWrite.Values) {
        if($fileToWrite['type'] -eq 'content') {
            $fileToWrite['value'] | Out-File -Encoding UTF8 -FilePath $fileToWrite['target']
        } elseif($fileToWrite['type'] -eq 'file') {
            Copy-Item $fileToWrite['value'] $fileToWrite['target']
        } else {
            throwError 1 "Unkown file type operation: $($fileToWrite['type'])" 
        }
    }

    # Also write conf files that are inherent to the platform
    $inherentConfPath = Join-Path $structPath_conf $platform  
    foreach ($confFile in Get-ChildItem -Path ($inherentConfPath) -File) {
        $destpath = Join-Path $projectPath 'conf'
        if (-not (Test-Path -path $destpath) ) { New-Item $destpath -Type Directory > $null } # Create directory 'conf' if not exists
        Copy-Item (Join-Path $inherentConfPath $confFile.Name) (Join-Path $destpath $confFile.Name)
    }

    $message = "Project '$appNameNormalized' successfully created in: $projectPath"

    Push-Location $projectPath
    if($startAfterCreation) {
        docker compose up -d
        $message = "$message - Container started."
        
        switch($platform) {
            'wordpress' {
                $message = "$message`n Accessible to https://$appName.docker.localhost"
            }
            'prestashop' {
                $message = "$message`nAccessible to https://$appName.docker.localhost/$adminDir.`nAdmin: $adminUser`nPassword: $adminPass"
            }
            'symfony-angular' {
                $message = "$message`n Front is accessible at https://front-$appName.docker.localhost`nBack is accessible at https://back-$appName.docker.localhost"
            }
        }

        if($platform -eq 'symfony-angular') {
            log 'front can take a while to be up while node modules is getting set up!' 2
        }

        # Don't forget to enable Mutagen for file synchronization
        if(-not $nosync) {
            startMutagenForProject $appNameNormalized
        }

        # set autostart to true so resume work after PC reboot for example
        EnableAutoStart -appName $appName -silent $true
        
    } else {
        # We build the project but we do not start mutagen
        # because we will probably start it using skippy project start 
        if(-not $noBuild) {
            docker compose up --no-start
            $message = "$message - Container created."
        }
    }
    Pop-Location

    log $message -1

}


function DisableAutoStart {
    param(
        [Parameter(Mandatory=$true)]
        [string]$appName,
        [Parameter(Mandatory=$false)]
        [bool]$silent = $false
    )

    # get list of container IDs related to the app
    $IDs = docker ps -f name=$appName -a --format '{{.ID}}'
    
    if($IDs.Count -gt 0) {
        foreach($id in $IDs) {
            docker update --restart=no $id > $null
            if(-not $silent) {
                log '✅ Auto start DISABLED'
            }
        }
    } else {
        if(-not $silent) {
            log "No container found for app $appName" 4
        }
    }

}

function EnableAutoStart {
    param(
        [Parameter(Mandatory=$true)]
        [string]$appName,
        [Parameter(Mandatory=$false)]
        [bool]$silent = $false
    )

    # get list of container IDs related to the app
    $IDs = docker ps -f name=$appName -a --format '{{.ID}}'
    
    if($IDs.Count -gt 0) {
        foreach($id in $IDs) {
            docker update --restart=always $id > $null
            if(-not $silent) {
                log '✅ Auto start ENABLED'
            }
        }
    } else {
        if(-not $silent) {
            log "No container found for app $appName" 4
        }
    }
    
}


function RemoveProject {
    param(
        [Parameter(Mandatory=$true)]
        [string]$appName,
        [Parameter(Mandatory=$false)]
        [string]$modeAuto=$false # Just remove everything without checking. Useful for automation
    )

    # Check if folder exists. if not, just log an error because the container can not exist without the folders.
    $projectPath = getProjectPath $appName
    if(-not (Test-Path $projectPath)) {
        $msg = "There is no project named '$appName'."
        if($modeAuto) {
            log $msg
            return $null
        } else {
            throwError 1 $msg
        }
    }

    # If exists, we check if a container aleady exists for the project and delete it
    $IDs = docker ps -f name=$appName -a --format '{{.ID}}'
    if(($IDs.Count -eq 0) -and (-not $modeAuto)) {
        log "No container was found for project '$appName'. Going to remove folders only."
    } 

    # No need to remove every containers one by one since docker compose will read the docker-compose file and act accordingly
    # We go to the folder, turn the container off and remove it, then we go back to where we were

    # We just ask for confirmation jic xD
    $confirmation = ''
    if(-not $modeAuto) {
        while((($confirmation -ne 'y') -and ($confirmation -ne 'n')) -and (($confirmation -ne 'yes') -and ($confirmation -ne 'no'))) {
            $confirmation = Read-Host "Are you sure you want to delete the project $appName ? [y]es/[n]o"
        }
    } else {
        $confirmation = 'y'
    }

    if(($confirmation -eq 'y') -or ($confirmation -eq 'yes')) {
        
        # Stop mutagen file sync first
        stopMutagenForProject $appName

        # delete the docker part...
        Push-Location $projectPath
        docker compose down -v # -v to remove mounted volumes
        Pop-Location
        # then delete the files

        # Don't rm if folder does not exists
        if(Test-Path $projectPath) {
            # Just be sure to delete a valid project!
            assertInDirectory $projectPath

            rm $projectPath -r -fo

            # Last check to see if folder still exists. If so, a problem has occured and we stop here to prevent further errors.
            if(Test-Path $projectPath) {
                throwError 1 "Soemthing wednt wrong ! The directory could not be removed. Aborting"
            }

        }
        
    } else {
        # Abort no matter what the user prompted if neither 'y' or 'yes'
        log 'Aborting...'
        exit 0
    }
    
    

    if($modeAuto) {
        log "Project $appName successfully deleted !"
    } else {
        log "Project $appName successfully deleted !" -1
        exit 0
    }

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
    docker compose up -d
    Pop-Location
    
    # Start file sync silently
    startMutagenForProject $appName > $null

    # set autostart to true so resume work after PC reboot for example
    EnableAutoStart -appName $appName -silent $true

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

    # set autostart to false to prevent ressource usage
    EnableAutoStart -appName $appName -silent $true 

}

# Restarts a project.
# It will rebuild the image! Useful if env variables have changed. 
function RestartProject {
    param(
        [Parameter(Mandatory=$true)]
        [string]$appName
    )

    $projects = getAvailableProjects

    if(-not $projects.ContainsKey($appName)) {
        log "App $appName does not exists." 4
    }

    # We just ask for confirmation jic xD
    $confirmation = ''
    while((($confirmation -ne 'y') -and ($confirmation -ne 'n')) -and (($confirmation -ne 'yes') -and ($confirmation -ne 'no'))) {
        $confirmation = Read-Host "Restarting will rebuild the image of $appName. Continue ? [y]es/[n]o"
    }

    if(($confirmation -eq 'y') -or ($confirmation -eq 'yes')) {

        stopMutagenForProject $appName

        Push-Location (getProjectPath $appName)
        docker compose down -v
        docker compose up -d
        Pop-Location

        startMutagenForProject $appName

    } else {
        log 'Aborted.'
    }

}

# Creates the mutagen sync session for the given project
function startMutagenForProject {
    param (
        [Parameter(Mandatory = $true)]
        [string]$appName
    )

    $projectPath = getProjectPath $appName

    if(-not (Test-Path $projectPath)) {
        throwError 1 "App $appName does not exists"
    }

    # We read the headers in the docker compose which contains the list of pathes to sync
    $projectConf = getSkippySettingsForProject $appName

    if(-not ($projectConf.ContainsKey('mutagensync'))) {
        throwError 1 'Can not enable Mutagen for project - missing mutagensync in headers'
    }

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

    $pathes = $projectConf['mutagensync'] -split ','
    foreach($path in $pathes) {
        $split_path = $path -split ':'
        if($split_path.Count -ne 2) {
            throwError 1 'Can not enable Mutagen for project - pathes are wrongly formatted'
        }

        $local = Join-Path $projectPath $split_path[0]
        $remote = $split_path[1]
        $identifier = Split-Path $local -Leaf # we use out local folder name as identifier for mutagen sync session name (warning: folders with same name will induce conflicts!)
        
        Invoke-Expression "mutagen sync create $local docker://$remote --name=$appName-$identifier $additional_args $confFileArg"

    }

    
}

# Removes the mutagen sync session for the given project
function stopMutagenForProject {
    param (
        [Parameter(Mandatory = $true)]
        [string]$appName
    )

    $projectPath = getProjectPath $appName

    if(-not (Test-Path $projectPath)) {
        throwError 1 "App $appName does not exists"
    }

    # We read the headers in the docker compose which contains the list of pathes to sync
    $projectConf = getSkippySettingsForProject $appName

    if(-not ($projectConf.ContainsKey('mutagensync'))) {
        throwError 1 'Can not disable Mutagen for project - missing mutagensync in headers'
    }

    $pathes = $projectConf['mutagensync'] -split ','
    foreach($path in $pathes) {
        $split_path = $path -split ':'
        if($split_path.Count -ne 2) {
            throwError 1 'Can not disable Mutagen for project - pathes are wrongly formatted'
        }

        $identifier = Split-Path (Join-Path $projectPath $split_path[0]) -Leaf # we use out local folder name as identifier for mutagen sync session name

        Invoke-Expression "mutagen sync terminate $appName-$identifier"

    }

    #Invoke-Expression "mutagen sync terminate $appName-www"

}