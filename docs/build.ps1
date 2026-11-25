#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Builds the site, or serves it.

.DESCRIPTION
    Imports the documents of the repository (import.ps1), then runs Lunet, which must be installed:
    dotnet tool install -g lunet. The site is written to .lunet/build/www.

.EXAMPLE
    pwsh build.ps1
    pwsh build.ps1 -Serve
#>
[CmdletBinding()]
param(
    # Serve the site at http://localhost:4000 and rebuild when a file of this folder changes.
    # A change in an imported document needs import.ps1 to run again.
    [switch] $Serve,
    # The branch the links to files of the repository point to.
    [string] $Branch = 'main'
)

$ErrorActionPreference = 'Stop'

& (Join-Path $PSScriptRoot 'import.ps1') -Branch $Branch

Push-Location $PSScriptRoot
try {
    if ($Serve) { lunet --stacktrace serve } else { lunet --stacktrace build }
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}
finally {
    Pop-Location
}
