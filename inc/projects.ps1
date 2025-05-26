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