param (
    [Parameter(Mandatory=$true)]
    [string]$inputPath,

    [Parameter(Mandatory=$true)]
    [string]$outputPath
)

# Get all files in the input folder
$allFiles = Get-ChildItem -Path $inputPath -Force -Recurse -File
$absoluteInputPath = (Resolve-Path $inputPath).Path.TrimEnd('\', '/')
$password = Read-Host -Prompt "enter password for the archive" -MaskInput
New-Item -ItemType Directory $outputPath -Force | Out-Null
$regexPattern = "\.7z\.\d{3}$"

foreach ($file in $allFiles) {
    if ($file.Name -match $regexPattern ){
        if (-not (($file.Extension -eq '.7z') -or ($file.Name -Like "*.7z.001"))){
            Write-Verbose "skipping '$($file.Name)"
            continue
        }
    }
    $relativePath =  Resolve-Path $file.Directory -Relative -RelativeBasePath $absoluteInputPath
    $currentOutputPath = Join-Path (Resolve-Path $outputPath) ($relativePath -replace "^\./", "")
    
    $absolutePathCurrentFileDirectory = Resolve-Path $file.Directory
    
    if ($absolutePathCurrentFileDirectory.Path -eq $absoluteInputPath){
        $currentOutputPath = Resolve-Path $outputPath
    }

    New-Item -ItemType Directory $currentOutputPath -Force | Out-Null

    if (($file.Extension -eq '.7z') -or ($file.Name -Like "*.7z.001")) {
        # For 7z files, extract them into the output folder
        & 7z x "$($file.FullName)" -bso0 -bsp1 -o"$currentOutputPath" -p"$password"
        if ($?) {
            Write-Output "'$($file.Name)' has been extracted to '$currentOutputPath'."
        } else {
            Write-Error "extraction of '$($file.Name)' failed"
        }
        continue
    }
    
    else {
        # For non-7z files, copy them to the output folder
        Copy-Item -Path $file.FullName -Destination $currentOutputPath -Force
        if ($?) {
            Write-Output "file '$($file.Name)' has been copied to '$currentOutputPath'."
        } else {
            Write-Error "copy of '$($file.Name)' failed"
        }
    }
}

Write-Output "DONE!"
