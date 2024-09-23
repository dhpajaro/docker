param(
    [Parameter(Mandatory=$true)]
    [alias("c")]
    [ValidateSet("up","down","pull","restart","stop","update","upgrade")]
    [string]$command,

    [parameter(Mandatory=$true)]
    [alias("s")]
    [string]$stack
)

$stacksDir = "$env:HOME/docker/compose"
$composeExtensions = @(".yaml",".yml")
$stacks = Get-ChildItem -LiteralPath $stacksDir -Directory -Force | ForEach-Object {
    [PSCustomObject]@{
        Name = $_.Name
        ComposeFile = Get-ChildItem -Path $_ | Where-Object { $_.Extension -in $composeExtensions } | Select-Object -First 1
        Folder = $_
    }
}

$stacksToProcess = @()

if ($stack -eq "all"){
    $stacksToProcess = $stacks
}
else{
    $stacksToProcess  = $stacks | Where-Object { $_.Name -eq $stack }
}

if (-not $stacksToProcess) {
    Write-Error "stack '$stack' does not exists"
    Write-Information "stacks:"
    $stacks | Select-Object -Property Name | Format-Table -AutoSize
    exit (1)
} 

$output = & docker compose ls | Select-Object -Skip 2

$runningStacks = $output | ForEach-Object {
    $columns = $_ -split '\s{2,}'
    [PSCustomObject]@{
        Name    = $columns[0]
        Status = $columns[1]
        ConfigFile  = $columns[2]
    }
}

foreach($currentStack in $stacksToProcess){
    $running = $runningStacks | Where-Object { $_.Name -eq $currentStack.Name }
    Push-Location $currentStack.Folder
    try {
        
        switch ($command) {
            "up" { & docker compose up -d --remove-orphans}
			"restart" { & docker compose restart}
            "down" { 
                if (-not $running){ 
                    Write-Warning "$($currentStack.Name) is not running"}
                    & docker compose down --remove-orphans
                }
            "stop" { 
                if (-not $running){ 
                    Write-Warning "$($currentStack.Name) is not running"}
                    & docker compose stop
                }
            "pull" { & docker compose pull }
            default {
              & docker compose pull
                if ($running){& docker compose up -d --remove-orphans}
              & docker image prune -f
            }
        }
    }finally{
        Pop-Location
    }
}