param(
    [Parameter(Mandatory=$true)]
    [ValidateSet("wordpress", "prestashop", "symfony-react")]
    [string]$platform,

    [Parameter(Mandatory=$false)]
    [ValidateSet("8.2", "8.3", "8.4")]
    [string]$phpVersion = "8.2",

    [Parameter(Mandatory=$true)]
    [string]$appName,

    [Parameter(Mandatory=$false)]
    [string]$db_password = "",

    [Parameter(Mandatory=$false)]
    [string]$db_user = "",

    [Parameter(Mandatory=$false)]
    [string]$db_name = "",

    [Parameter(Mandatory=$false)]
    [string]$db_table_prefix = ""

)

# Importer les fonctions utilitaires
. "$PSScriptRoot\exits.ps1"
. "$PSScriptRoot\utils.ps1"

# Définir la racine autorisée
$allowedRoot = "E:\docker"
$skippyPath = "$allowedRoot\skippy"
$templatePath = "$skippyPath\templates"

# Normalisation du nom
$appNameNormalized = NormalizeAppName $appName


# Définir les chemins
$projectPath = Join-Path "$allowedRoot\projects" $appNameNormalized
$wwwPath     = Join-Path $projectPath "www"
$dbPath      = Join-Path $projectPath "db"
$outputDockerComposeFile   = Join-Path $projectPath "docker-compose.yml"
$outputEnvFile   = Join-Path $projectPath ".env"
$gitignoreFile = "$skippyPath\gitignores\.gitignore-default"

# Vérification des chemins okazoo
Assert-InDockerRoot -path $projectPath -allowedRoot $allowedRoot
Assert-InDockerRoot -path $dbPath -allowedRoot $allowedRoot

# on prépare les variables communes à tous les templates et on prépare le fichier .env
# les keys de $templateVars sont les placeholders du template, d'ou les brackets
$templateVars = @{
    '{{APPNAME_NORMALIZED}}' = $appNameNormalized
    '{{PHP_VERSION}}' = $phpVersion
}
$envVars = @{}

# on indique le template du docker-compose à utiliser selon la plateforme et on assigne les variables
# il faudra mettre a jour quand les autres plateformes seront prêtes
if($platform -eq 'wordpress') {
    $templateFile = "$templatePath\docker-compose-template-wordpress.yml"
    $gitignoreFile = "$skippyPath\gitignores\.gitignore-wordpress"

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


# Vérification du template
Assert-InDockerRoot -path $templateFile -allowedRoot $allowedRoot
if (-not (Test-Path $templateFile)) {
    echo $exits[3] $templateFile
    exit 3
}

# Traitement du template dans lequel on remplace les placeholders des variables
$templateContent = Get-Content $templateFile -Raw
foreach ($key in $templateVars.Keys) {
    $templateContent = $templateContent -replace $key, $templateVars[$key]
}

# on formatte également le fichier .env
$envFileContent = ""
foreach ($key in $envVars.Keys) {
    $envFileContent += $key + "='" + $envVars[$key] + "'" + "`n"
}

# On check si les dossiers existent déjà pour pas tout péter
if (Test-Path $wwwPath) {
    echo $exits[5]
    exit 5
} elseif(Test-Path $dbPath) {
    echo $exits[5]
    exit 5
}

# Création des dossiers
New-Item -ItemType Directory -Force -Path $wwwPath | Out-Null
New-Item -ItemType Directory -Force -Path $dbPath | Out-Null

# On check si les dossiers ont bien été créés
if (-not (Test-Path $wwwPath) -or -not (Test-Path $dbPath)) {
    echo $exits[2]
    exit 2
}

# Écriture du docker-compose.yml et du .env
$templateContent | Out-File -Encoding UTF8 -FilePath $outputDockerComposeFile
$envFileContent | Out-File -Encoding UTF8 -FilePath $outputEnvFile
cat $gitignoreFile | Out-File -Encoding UTF8 -FilePath "$projectPath\.gitignore"

Write-Host "`✅ Projet '$appNameNormalized' créé à:`n  -> $projectPath`n"
