param(
    [Parameter(Mandatory=$true)]
    [alias("i")]
    [string]$inputPath,

    [parameter(Mandatory=$false)]
    [alias("o")]
    [string]$outputPath,

    [parameter(Mandatory=$false)]
    [alias("x")]
    [array]$excludeFolders
)

function Test-RunningEnviroment {
    if (-not ($isLinux)){
        Throw "script only runs on Linux"
    }
    $uid = whoami        
    Write-Output "running as: $uid"
    if (-not ($uid -eq 'root')){
        Throw "script must be run as root"
    }
}

Test-RunningEnviroment

$timeNow = Get-Date -Format "yyyyMMdd_HHmmss"
$outputRoot = Split-Path $inputPath -Parent

if ($outputPath){$outputRoot = $outputPath}
else {Write-Warning "Using default outputPath (parent folder of input)"}

$backupName = (Split-Path $inputPath -Leaf) + "_backup_$timeNow"

$excludeFoldersArray = $excludeFolders
if ($excludeFolders.Count -eq 1) {
    $excludeFoldersArray = $excludeFolders[0] -split ','
}

$scriptConfig = [PSCustomObject]@{
    InputFolder = Get-Item -LP $inputPath -Force
    OutputFolder = New-Item -Type Directory -Force (Join-Path $outputRoot $backupName)
    Exclude = $excludeFoldersArray
}

$scriptConfig | Format-List

$password = Read-Host -Prompt "enter password for the archive" -MaskInput
$password2 = Read-Host -Prompt "enter password for the archive (again)" -MaskInput
if ($password -ne $password2) {
    Throw "password does not match"
}

function Rename-IfSinglePart {
    param ([string]$filePath)
    $firstPart = Get-Item -LP "$filePath.001" -Force
    $otherParts = Get-ChildItem -LP $firstPart.Directory -Filter "$(Split-Path $filePath -Leaf).*" -Force | Where-Object { $_.Extension -ne ".001" }
    
    if ($otherParts.Count -eq 0) {
        $newPath = Join-Path $firstPart.Directory $firstPart.BaseName
        Rename-Item -Path $firstPart -NewName $newPath -Force
        Write-Verbose "Renamed $oldPath to $newPath"
    } 
}

function Compress-SubFolders {
    param(
        [Parameter(Mandatory = $true)]
        [string]$inputFolderPath, 
        [Parameter(Mandatory = $true)]
        [string]$outputFolderPath
    )

    $excludeAllways = @("data",'media_server')
    $subFolders = Get-ChildItem -LP $inputFolderPath -Directory -Force 
    foreach ($subFolder in $subFolders) {

        if ($subFolder.Name -eq "scripts") {
            Write-Output "copying '$($subFolder.Name)'..."
            Copy-Item -LP $subFolder -Destination $outputFolderPath -Force -Recurse
            continue
        } 
        if ($subFolder.Name -in $excludeAllways) {
            Write-Verbose "skipping $subFolder"
            continue
        } 

        if ($subFolder.Name -in $scriptConfig.Exclude){
            Write-Warning "skipping $subFolder"
            continue
        }
        $outputFilePath = Join-Path $outputFolderPath ($subFolder.Name + ".7z")
        Write-Output "compressing '$($subFolder.Name)'..."
        & 7z a -bso0 -bsp1 -m0=LZMA2:d64k:fb32 -mmt=2 -mhe -mx=1 -v2g -p"$password" $outputFilePath $subFolder '-xr!*Backups*' '-xr!*Cache*' '-xr!*cache*' '-xr!*.log' '-xr!*.mkv' '-xr!*.mp4' '-xr!*Codecs*' '-xr!*Logs*' '-xr!Log' '-xr!log' '-xr!*logs*' '-xr!*tmp/*' '-xr!*Updates/*' '-xr!*update/*' '-xr!*Crash*Reports/*' 
        Rename-IfSinglePart $outputFilePath
    } 
}

function Compress-LooseFiles {
    $looseFiles = Get-ChildItem -LP $scriptConfig.InputFolder -File -Force
    $scriptExtensions = @('.ps1','.sh')
    Write-Output "`n--- Compressing loose files ---"
    foreach ($file in $looseFiles) {
        $outputPath = Join-Path $scriptConfig.OutputFolder "loose_files.7z"
        if ($file.Extension -in $scriptExtensions) {
            Write-Output "copying '$($file.Name)'..."
            Copy-Item -Path $file -Destination $outputPath -Force
        } else {
             & 7z a -bso0 -bsp1 -m0=LZMA2:d64k:fb32 -mmt=2 -mhe -mx=1 -p"$password" $outputPath $file
        }
    }
}

function main{
    $start = Get-Date
    try{
        Compress-LooseFiles
        
        $inputDataFolder = Join-Path $scriptConfig.InputFolder 'data'
        $inputMediaServerFolder = Join-Path $inputDataFolder 'media_server'
        $outputDataFolder = New-Item -ItemType Directory -Path (Join-Path $scriptConfig.OutputFolder 'data') -Force  
        $outputMediaServerFolder = New-Item -ItemType Directory -Path (Join-Path $outputDataFolder 'media_server') -Force  
        
        Write-Output "`n--- Compressing root folders, excluding 'data' ---"
        Compress-SubFolders $scriptConfig.InputFolder $scriptConfig.OutputFolder 

        Write-Output "`n--- Compressing 'data' folders, excluding 'media_server' ---"
        Compress-SubFolders $inputDataFolder $outputDataFolder 

        Write-Output "`n--- Compressing 'media_server' folders ---"
        Compress-SubFolders $inputMediaServerFolder $outputMediaServerFolder

        
		Write-Output "`n--- ---------------------------------- ---"
        Write-Host "Backup completed!" -Foreground green
        
    }
    catch{
        Write-Host "Backup Failed!" -Foreground red
        Write-Error $_ | Out-Host
    }
    finally{
        $elapsed = (Get-Date) - $start
        Write-Output "Elapsed time: ($elapsed)"
        Write-Output "Changing ownership of '$($scriptConfig.OutputFolder)'..." | Out-Host
        chown $env:USER -R $scriptConfig.OutputFolder
    }
}

main