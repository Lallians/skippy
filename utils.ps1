function NormalizeAppName {
    param (
        [string]$thevalue
    )

    if ([string]::IsNullOrWhiteSpace($thevalue)) {
        Write-Error "⛔ Le paramètre 'appname' est vide ou nul."
        return ""
    }

    # flemme de faire propre, go a la mano
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

       # on spécifie le type, j'magine que PS vérifie $char avec sa valeur ascii ?
        if ($map.ContainsKey($char -as [string])) {
            $normalized += $map[$char -as [string]]
        } else {
            $normalized += $char
        }
       
    }

    # et on dégage les caracteres autres que chiffre ou lettre sauf les _ et les -
    return $normalized.ToLower() -replace '[^a-z0-9_\-]', ''
}


function Assert-InDockerRoot {
    param (
        [string]$path,
        [string]$allowedRoot
    )

    if (-not ($path -like "$allowedRoot*")) {
        echo "❌ En dehors de l'espace autorisé!. ($path)"
        exit 1
    }
}

# Génère un password classique
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

# génère un nom simple (9 caractères par défaut)
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