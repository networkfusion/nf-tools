# Copyright (c) .NET Foundation and Contributors
# See LICENSE file in the project root for full license information.

# This PS restores the .NET nanoFramework nugets on the repo where it's running

# check if this is running in Azure Pipelines or GitHub actions

######################################
# this is building from github actions

# get repository name from the repo path
Set-Location ".." | Out-Null
$library = Split-Path $(Get-Location) -Leaf

"Repository: '$library'" | Write-Host

# need this to move to the 
"Moving to 'main' folder" | Write-Host

Set-Location "main" | Out-Null


# init/reset these
$workingPath = '.\'

# need this to remove definition of redirect stdErr (only on Azure Pipelines image fo VS2019)
$env:GIT_REDIRECT_STDERR = '2>&1'


# temporarily rename csproj files to projcs-temp so they are not affected.
Get-ChildItem -Path $workingPath -Include "*.csproj" -Recurse |
    Foreach-object {
        $OldName = $_.name; 
        $NewName = $_.name -replace '.csproj','.projcs-temp'; 
        Rename-Item  -Path $_.fullname -Newname $NewName; 
    }

# temporarily rename nfproj files to csproj
Get-ChildItem -Path $workingPath -Include "*.nfproj" -Recurse |
    Foreach-object {
        $OldName = $_.name; 
        $NewName = $_.name -replace '.nfproj','.csproj'; 
        Rename-Item  -Path $_.fullname -Newname $NewName; 
    }

# find every solution file in repository
$solutionFiles = (Get-ChildItem -Path ".\" -Include "*.sln" -Recurse)

# loop through solution files and replace content containing:
# 1) .csproj to .projcs-temp (to prevent NuGet from touching these)
# 2) and .nfproj to .csproj so nuget can handle them
foreach ($solutionFile in $solutionFiles)
{
    $content = Get-Content $solutionFile -Encoding utf8
    $content = $content -replace '.csproj', '.projcs-temp'
    $content = $content -replace '.nfproj', '.csproj'
    $content | Set-Content -Path $solutionFile -Encoding utf8 -Force
}
    
# find NuGet.Config
$nugetConfig = (Get-ChildItem -Path ".\" -Include "NuGet.Config" -Recurse) | Select-Object -First 1

foreach ($solutionFile in $solutionFiles)
{
    # check if there are any csproj here
    $hascsproj = Get-Content $solutionFile -Encoding utf8 | Where-Object {$_ -like '*.csproj*'}
    if($hascsproj -eq $null)
    {
        continue
    }

    $solutionPath = Split-Path -Path $solutionFile

    # find packages.config
    $packagesConfigs = (Get-ChildItem -Path "$solutionPath" -Include "packages.config" -Recurse)

    foreach ($packagesConfig in $packagesConfigs)
    {
        # load packages.config as XML doc
        [xml]$packagesDoc = Get-Content $packagesConfig -Encoding utf8

        $nodes = $packagesDoc.SelectNodes("*").SelectNodes("*")

        $packageList = @(,@())

        "Building package list to update" | Write-Host

        foreach ($node in $nodes)
        {
            # filter out Nerdbank.GitVersioning package
            if($node.id -notlike "Nerdbank.GitVersioning*")
            {
                "Adding {0} {1}" -f [string]$node.id,[string]$node.version | Write-Host
                if($packageList)
                {
                    $packageList += , ($node.id,  $node.version)
                }
                else
                {
                    $packageList = , ($node.id,  $node.version)
                }
            }
        }

        if ($packageList.length -gt 0)
        {
            "NuGet packages to update:" | Write-Host
            $packageList | Write-Host

            if (![string]::IsNullOrEmpty($nugetConfig))
            {
                nuget restore $solutionFile -ConfigFile $nugetConfig
            }
            else
            {
                nuget restore $solutionFile
            }
        }
    }
}

# rename csproj files back to nfproj
Get-ChildItem -Path $workingPath -Include "*.csproj" -Recurse |
Foreach-object {
    $OldName = $_.name; 
    $NewName = $_.name -replace '.csproj','.nfproj'; 
    Rename-Item  -Path $_.fullname -Newname $NewName; 
    }

# rename projcs-temp files back to csproj
Get-ChildItem -Path $workingPath -Include "*.projcs-temp" -Recurse |
Foreach-object {
    $OldName = $_.name; 
    $NewName = $_.name -replace '.projcs-temp','.csproj'; 
    Rename-Item  -Path $_.fullname -Newname $NewName; 
    }

# loop through solution files and revert names to default.
foreach ($solutionFile in $solutionFiles)
{
    $content = Get-Content $solutionFile -Encoding utf8
    $content = $content -replace '.csproj', '.nfproj'
    $content = $content -replace '.projcs-temp', '.csproj'
    $content | Set-Content -Path $solutionFile -Encoding utf8 -Force
}
