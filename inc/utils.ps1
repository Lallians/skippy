

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





