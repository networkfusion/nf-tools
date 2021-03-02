[CmdletBinding()]
param()

#Trace-VstsEnteringInvocation $MyInvocation

"Started VS extension install" | Write-Host

Import-Module $PSScriptRoot\ps_modules\VstsTaskSdk

"Imported VS task sdk" | Write-Host

Import-VstsLocStrings "$PSScriptRoot\Task.json"

[System.Net.WebClient]$webClient = New-Object System.Net.WebClient
$webClient.UseDefaultCredentials = $true

function DownloadVsixFile($fileUrl, $downloadFileName)
{
    Write-Host "Download VSIX file from $fileUrl to $downloadFileName"
    $webClient.DownloadFile($fileUrl,$downloadFileName)
}

"Downloaded extension" | Write-Host

$tempDir = $Env:RUNNER_TEMP

# get extension information from Open VSIX Gallery feed
$vsixFeedXml = Join-Path -Path $tempDir -ChildPath "vs-extension-feed.xml"
$webClient.DownloadFile("http://vsixgallery.com/feed/author/nanoframework", $vsixFeedXml)
[xml]$feedDetails = Get-Content $vsixFeedXml


# # find which entry corresponds to which VS version
$idVS2019 = 1
#$idVS2017 = 0

# find which VS version is installed
$VsWherePath = "${env:PROGRAMFILES(X86)}\Microsoft Visual Studio\Installer\vswhere.exe"

Write-Output "VsWherePath is: $VsWherePath"

$VsInstance = $(&$VSWherePath -latest -property displayName)

$extensionUrl = $feedDetails.feed.entry[$idVS2019].content.src
$vsixPath = Join-Path -Path $tempDir -ChildPath "nanoFramework.Tools.VS2019.Extension.zip"
$extensionVersion = $feedDetails.feed.entry[$idVS2019].Vsix.Version

# download VS extension
DownloadVsixFile $extensionUrl $vsixPath

# get path to 7zip
$sevenZip = "$PSScriptRoot\7zip\7z.exe"

# unzip extension
Write-Host "Unzip extension content"
Invoke-VstsTool -FileName $sevenZip -Arguments " x $vsixPath -bd -o$tempDir\nf-extension" > $null

# copy build files to msbuild location
$VsPath = $(&$VsWherePath -latest -property installationPath)

Write-Host "Copy build files to msbuild location"

$msbuildPath = Join-Path -Path $VsPath -ChildPath "\MSBuild"

Copy-Item -Path "$tempDir\nf-extension\`$MSBuild\nanoFramework" -Destination $msbuildPath -Recurse

Write-Host "Installed VS extension v$extensionVersion"

#Trace-VstsLeavingInvocation $MyInvocation
