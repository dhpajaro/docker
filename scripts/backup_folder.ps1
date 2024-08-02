param(
    [Parameter(Mandatory=$true)]
    [alias("i")]
    [string]$inputPath,

    [parameter(Mandatory=$false)]
    [alias("o")]
    [string]$outputPath,

    [parameter(Mandatory=$false)]
    [alias("x")]
    [string[]]$exclude
)

$TimeStamp = Get-Date -Format "yyyyMMdd_HHmmss"
if (-not ($PSBoundParameters.ContainsKey('outputPath'))){
    $outputPath = Split-Path -Path (Resolve-Path -Path $inputPath ) -Parent
    Write-Warning "Using default outputPath (parent folder of input)"
}

$OutputFolderName = "docker_backup_$TimeStamp"
$outputPath = Join-Path (Get-Item $outputPath).FullName $OutputFolderName

Write-Output "output = $outputPath"
Write-Output "exclude = $exclude"

$password = Read-Host -Prompt "enter password for the archive" -MaskInput
$password2 = Read-Host -Prompt "enter password for the archive (again)" -MaskInput
if ($password -ne $password2) {
    Throw "passwords do not match"
}

$start = Get-Date
$rootSubFolders = Get-ChildItem -Path $inputPath -Directory -Force | Where-Object { $_.Name -ne 'data' }
$dataSubFolders = Get-ChildItem -Path (Join-Path $inputPath "data") -Directory -Force | Where-Object { $_.Name -ne 'media_server' }
$mediaServerSubFolders = Get-ChildItem -Path (Join-Path $inputPath "data" "media_server") -Directory -Force

function Remove-001IfSinglePart {
    param ([string]$baseName,[string]$folderPath)

    $otherParts = Get-ChildItem -Path $folderPath -Filter "$baseName.*" -Force | Where-Object { $_.Extension -ne ".001" }
    
    if ($otherParts.Count -eq 0) {
        $newName = $baseName
        $newPath = Join-Path $folderPath $newName
        Rename-Item -Path $file.FullName -NewName $newPath -Force
        Write-Host "Renamed $($file.Name) to $newName"
    }
    
}
function Compress-SubFolders {
    param(
        [Parameter(Mandatory = $true)]
        [array]$subFolders, 
        [Parameter(Mandatory = $true)]
        [string]$outputFolderPath
    )

    $excludeAllways = @("data",'media_server')
    New-Item -ItemType Directory -Path $outputFolderPath -Force | Out-Null
    foreach ($subFolder in $subFolders) {
        $subFolderName = $subFolder.Name
        if ($subFolderName -eq "scripts") {
            Write-Output "Copying '$($subFolderName)'..."
            Copy-Item -Path $subFolder.FullName -Destination $outputFolderPath -Force -Recurse
            continue
        } 
        if ($subFolderName -in $excludeAllways) {
            Write-Warning "skipping $($subFolder.Fullname)"
            continue
        } 
        if ($subFolderName -in $exclude){
            Write-Warning "skipping $($subFolder.Fullname)"
            continue
        }
        $outputFilePath = Join-Path $outputFolderPath ($subFolderName + ".7z")
        Write-Output "Compressing '$($subFolder.Name)'..."
        & 7z a -bso0 -bsp1 -mmt -m0=lzma2 -mx=5 -p"$password" -v2g -mhe $outputFilePath $subFolder '-xr!*Cache*' '-xr!*cache*' '-xr!*.log' '-xr!*.mkv' '-xr!*.mp4' '-xr!*Codecs*' '-xr!*Logs*' '-xr!*logs*' '-xr!*tmp/*' '-xr!*Updates/*' '-xr!*update/*' '-xr!*Crash*Reports/*' 
        Remove-001IfSinglePart ($subFolderName + ".7z")
    } 
}

try{
    $outputDataFolder = Join-Path $outputPath 'data'
    $outputMediaServerFolder = Join-Path $outputDataFolder 'media_server'
    
    Write-Output "`nCompressing root folders, excluding 'data'"
    Compress-SubFolders $rootSubFolders $outputPath

    Write-Output "`nCompressing 'data' folders, excluding 'media_server'"
    Compress-SubFolders $dataSubFolders $outputDataFolder 

    Write-Output "`nCompressing 'media_server' folders"
    Compress-SubFolders $mediaServerSubFolders $outputMediaServerFolder

    $LooseFiles = Get-ChildItem -Path $inputPath -File -Force
    Write-Output "Compressing loose files..."
    foreach ($File in $LooseFiles) {
        $outputLooseFilesPath = Join-Path $outputPath "_loose_files.7z"
        if ($File.Extension -eq ".ps1" -or $File.Extension -eq ".sh") {
            Write-Output "Copying '$($File.Name)'..."
            Copy-Item -Path $File.FullName -Destination $outputPath -Force
        } else {
            & 7z a -bso0 -bsp1 -mmt -m0=lzma2 -mx=1 -p"$password" -mhe $outputLooseFilesPath $File.FullName
        }
    }

    $elapsed = (Get-Date) - $start
    Write-Output "Backup completed. Files are stored in: $outputPath "
    Write-Output "Elapsed time: ($elapsed)"
}
finally{
    if ($isLinux){
        Write-Output "Changing ownership of outputFolder..."
        sudo chown usuario -R $outputPath 
    }
}
