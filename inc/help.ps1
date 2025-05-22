# function that displays help for a given command
function displayHelp {
	param (
        [string]$chapter
    )

    switch ($chapter) {
            "skippy" {
                Write-Host "Skippy is a tool to manage docker projects. Its goal is to simplify the setup and configuration of projects"
                Write-Host "The list of available commands are: "
                Write-Host "    - project: Manage projects, like create or restart."
                Write-Host "    - help: Displays this message."
            }
            "project" {
                Write-Host "`nProject allows you to manage your projects. Possible actions:"
                Write-Host "    - list: Lists all the projects availabled with some relevant informations."
                Write-Host "    - create: Creates a new project. The args are:"
                Write-Host "        appName: Name of said project. Acts as an identifier. The value will be normalized if needed."
                Write-Host "        platform: The platform of project. Can be: 'wordpress', 'prestashop', 'symfony-react'."
                Write-Host "        (optionnal) phpVersion: The version of PHP for the app. Defaults to 8.2."
                Write-Host "        (optionnal) db_user: The username of the database. A random string by default."
                Write-Host "        (optionnal) db_password: The password of the database. A random string by default."
                Write-Host "        (optionnal) db_name: The database name. Will be set to `$db_table_prefix`$appName by default."
                Write-Host "        (optionnal) db_table_prefix: The prefix of the tables. A random string of the form XXX_ will be generated."
                Write-Host "        (optionnal) startAfterCreation: set to false if you want a manual intervention on the container before it is loaded for the first time."
                Write-Host "    - remove: Removes a project from Docker and from the disk. The args are:"
                Write-Host "        appName: Name of target project."
                Write-Host "    - enableAutoStart: Makes the container from running at startup. The args are:"
                Write-Host "        appName: Name of target project."
                Write-Host "    - disableAutoStart: Prevent the container from running at startup. The args are:"
                Write-Host "        appName: Name of target project."
                Write-Host "    - start: Starts the app's docker containers. The args are:"
                Write-Host "        appName: Name of target project."
                Write-Host "    - stop: Stops the app's docker containers. The args are:"
                Write-Host "        appName: Name of target project."
                Write-Host "    - startMutagen: Starts file sync for project. The args are:"
                Write-Host "        appName: Name of target project."
                Write-Host "    - stopMutagen: Stops file sync for project. The args are:"
                Write-Host "        appName: Name of target project."
                Write-Host "    - help: Displays this message."
            }
            'project-create' {
                Write-Host "Creates a new project. The args are:"
                Write-Host "    - appName: Name of said project. Acts as an identifier. The value will be normalized if needed."
                Write-Host "    - platform: The platform of project. Can be: 'wordpress', 'prestashop', 'symfony-react'."
                Write-Host "    - (optionnal) phpVersion: The version of PHP for the app. Defaults to 8.2."
                Write-Host "    - (optionnal) db_user: The username of the database. A random string by default."
                Write-Host "    - (optionnal) db_password: The password of the database. A random string by default."
                Write-Host "    - (optionnal) db_name: The database name. Will be set to `$db_table_prefix`$appName by default."
                Write-Host "    - (optionnal) db_table_prefix: The prefix of the tables. A random string of the form XXX_ will be generated."
                Write-Host "    - (optionnal) startAfterCreation: set to false if you want a manual intervention on the container before it is loaded for the first time."
            }
            default {
                throwError 1 "There is no help displayable for $chapter"
            }
        }

    exit 0

}