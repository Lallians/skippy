1. [Environment]::SetEnvironmentVariable("Path", $Env:Path + ";E:\docker\skippy", "User") # setup la variable d'environnement
2. Set-Alias -Name skippy -Value "E:\docker\skippy\skippy.ps1" # pouvoir écrire "skippy" dans PowerShell au lieu de "skippy.ps1"
3. Set-ExecutionPolicy Unrestricted -Scope CurrentUser -Force # Pour autoriser l'execution de scripts depuis PowerShell puis refaire étape 2