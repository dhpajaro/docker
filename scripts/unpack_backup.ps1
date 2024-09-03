param (
    [Parameter(Mandatory=$true)]
    [Alias('i')]
    [string]$inputPath,

    [Parameter(Mandatory=$true)]
    [Alias('o')]
    [string]$outputPath
)

$scriptConfig = [PSCustomObject]@{
    InputFolder = Get-Item -LP $inputPath -Force
    OutputFolder = New-Item -Type Directory -Force $outputPath
}

$scriptConfig | Format-List

$allFiles = Get-ChildItem -LP $inputPath -Force -Recurse -File
$password = Read-Host -Prompt "enter password for the archive" -MaskInput
$regexPattern = "\.7z\.\d{3}$"

foreach ($file in $allFiles) {
    if ($file.Name -match $regexPattern ){
        if (-not (($file.Extension -eq '.7z') -or ($file.Name -Like "*.7z.001"))){
            Write-Verbose "skipping '$($file.Name)"
            continue
        }
    }
    $relativePath =  Resolve-Path $file.Directory -Relative -RelativeBasePath $scriptConfig.InputFolder
    $currentOutputPath = Join-Path $scriptConfig.OutputFolder ($relativePath -replace "^\./", "")
        
    if ($file.Directory.Path -eq $scriptConfig.InputFolder){
        $currentOutputPath = $scriptConfig.OutputFolder
    }

    New-Item -ItemType Directory $currentOutputPath -Force | Out-Null

    if (($file.Extension -eq '.7z') -or ($file.Name -Like "*.7z.001")) {
        # For 7z files, extract them into the output folder
        & 7z x $file -bso0 -bsp1 -o"$currentOutputPath" -p"$password"
        if ($?) {
            Write-Output "'$($file.Name)' has been extracted to '$currentOutputPath'."
        } else {
            Write-Error "extraction of '$($file.Name)' failed"
        }
        continue
    }
    
    else {
        # For non-7z files, copy them to the output folder
        Copy-Item -Path $file -Destination $currentOutputPath -Force
        if ($?) {
            Write-Output "file '$($file.Name)' has been copied to '$currentOutputPath'."
        } else {
            Write-Error "copy of '$($file.Name)' failed"
        }
    }
}

Write-Output "DONE!"
