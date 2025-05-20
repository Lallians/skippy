# skippy
Skippy is installed in E:/docker.
Please adapt and replace this hard coded value if needed inside Skippy's files.

# Install Skippy
Open a powershell and run the following:
- [Environment]::SetEnvironmentVariable("Path", $Env:Path + ";E:\docker\skippy", "User") # Adds Skippy to the environment variable
- Set-Alias -Name skippy -Value "E:\docker\skippy\skippy.ps1" # Set an alias to make skippy callable without specifying 
- Set-ExecutionPolicy Unrestricted -Scope CurrentUser -Force # If the above command is not permitted because of script execution policy, run this command and retry