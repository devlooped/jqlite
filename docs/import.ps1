#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Imports the documents of the repository that the site shows but does not own.

.DESCRIPTION
    The spec, the porting guide, the README of each port and a few others are written for the
    repository, where their links are relative to their own folder. The site shows them as pages
    without keeping a second copy in git: this script writes each one, with a front matter and with
    its links rewritten, into .lunet/extends/repo (ignored by git), the local Lunet extension that
    config.scriban loads with `extend "repo"`. Lunet lays that folder under the site, so
    language/spec.md there is the page /language/spec/ as if it were in docs/language/.

    Run it before `lunet build` or `lunet serve`, and again after changing an imported document.
    build.ps1 does both.
#>
[CmdletBinding()]
param(
    # The branch the links to files of the repository point to.
    [string] $Branch = 'main'
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$repo = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$layer = Join-Path $PSScriptRoot '.lunet/extends/repo'
$github = 'https://github.com/devlooped/jqlite'

# The imported documents: where each one is in the repository, the page it becomes, and its title.
# Note is Markdown put under the first heading.
$pages = @(
    @{ Source = 'spec/jqlite.md'; Target = 'language/spec.md'; Title = 'Specification' }
    @{ Source = 'docs/manual.md'; Target = 'language/manual.md'; Title = 'jq 1.8 manual'
       Note = @'
> [!NOTE]
> This is the manual of [jq 1.8](https://jqlang.org/manual/v1.8/), by the jq authors, licensed under [CC BY 3.0](https://creativecommons.org/licenses/by/3.0/). jqlite runs the language it describes, as a library: "Invoking jq" and the builtins that read jq's command line or its stream of inputs do not apply, and the other differences are listed in [§13 of the specification](spec.md#13-differences-from-jq-18).
'@ }
    @{ Source = 'docs/porting.md'; Target = 'project/porting.md'; Title = 'Porting guide' }
    @{ Source = 'spec/tests/README.md'; Target = 'project/corpus.md'; Title = 'Conformance corpus' }
    @{ Source = 'bench/README.md'; Target = 'project/benchmarks.md'; Title = 'Benchmarks' }
    @{ Source = 'go/README.md'; Target = 'go/port.md'; Title = 'Port notes' }
    @{ Source = 'java/README.md'; Target = 'java/port.md'; Title = 'Port notes' }
    @{ Source = 'python/README.md'; Target = 'python/port.md'; Title = 'Port notes' }
    @{ Source = 'rust/README.md'; Target = 'rust/port.md'; Title = 'Port notes' }
    @{ Source = 'typescript/README.md'; Target = 'typescript/port.md'; Title = 'Port notes' }
)

# Documents that are not imported because the site has a page of its own for them: a link to one
# goes to that page.
$aliases = @{
    'readme.md' = 'dotnet/readme.md'
}

# Files copied as they are.
$assets = @{
    'assets/img/logo.svg' = 'img/logo.svg'
    'assets/img/icon.svg' = 'img/icon.svg'
}

$targets = @{}
foreach ($page in $pages) { $targets[$page.Source] = $page.Target }
foreach ($alias in $aliases.GetEnumerator()) { $targets[$alias.Key] = $alias.Value }

# Repository paths are compared without case: Windows and macOS find README.md under any spelling.
function Get-RepoPath([string] $directory, [string] $link) {
    $segments = [System.Collections.Generic.List[string]]::new()
    foreach ($segment in "$directory/$link".Split('/')) {
        if ($segment -eq '..') {
            if ($segments.Count -eq 0) { return $null }
            $segments.RemoveAt($segments.Count - 1)
        }
        elseif ($segment -ne '' -and $segment -ne '.') { $segments.Add($segment) }
    }
    $segments -join '/'
}

function Get-RelativeLink([string] $from, [string] $to) {
    $fromDirectory = @($from.Split('/') | Select-Object -SkipLast 1)
    $toSegments = @($to.Split('/'))
    $common = 0
    while ($common -lt $fromDirectory.Count -and $common -lt $toSegments.Count - 1 -and
        $fromDirectory[$common] -eq $toSegments[$common]) { $common++ }
    (@('..') * ($fromDirectory.Count - $common) + @($toSegments | Select-Object -Skip $common)) -join '/'
}

# The target of a link of the document $source, for the page $target.
function Convert-Link([string] $link, [string] $source, [string] $target) {
    if ($link -match '^(#|[a-zA-Z][a-zA-Z0-9+.-]*:|//)') { return $link }
    $path, $fragment = $link -split '#', 2
    $fragment = if ($fragment) { "#$fragment" } else { '' }
    $resolved = Get-RepoPath (Split-Path $source -Parent).Replace('\', '/') $path
    if ($null -eq $resolved) { throw "$source links outside the repository: $link" }
    $imported = $targets.Keys | Where-Object { $_ -ieq $resolved } | Select-Object -First 1
    if ($imported) { return (Get-RelativeLink $target $targets[$imported]) + $fragment }
    $full = Join-Path $repo $resolved
    if (-not (Test-Path $full)) { throw "$source links to a file that does not exist: $link" }
    $kind = if (Test-Path $full -PathType Container) { 'tree' } else { 'blob' }
    "$github/$kind/$Branch/$resolved$fragment"
}

# Rewrites the inline links of one line, outside its code spans.
function Convert-Line([string] $line, [string] $source, [string] $target) {
    $parts = $line -split '(`+[^`]*`+)'
    for ($i = 0; $i -lt $parts.Count; $i += 2) {
        $parts[$i] = [regex]::Replace($parts[$i], '(?<=\]\()([^()\s]+)(?=(\s+"[^"]*")?\))', {
                param($match) Convert-Link $match.Value $source $target
            })
    }
    $parts -join ''
}

function Convert-Document([hashtable] $page) {
    $lines = [System.IO.File]::ReadAllLines((Join-Path $repo $page.Source))
    $output = [System.Collections.Generic.List[string]]::new()
    $output.Add('---')
    $output.Add("title: `"$($page.Title)`"")
    $output.Add('---')
    $output.Add('')
    $fence = $null
    $noted = -not $page.ContainsKey('Note')
    foreach ($line in $lines) {
        if ($fence) {
            if ($line.TrimStart().StartsWith($fence)) { $fence = $null }
        }
        elseif ($line -match '^\s*(```+|~~~+)') { $fence = $Matches[1] }
        else { $line = Convert-Line $line $page.Source $page.Target }
        # A page is a Scriban template: braces that would open or close a code block are written as text.
        $output.Add([regex]::Replace($line, '\{\{|\}\}', { param($match) '{{ "' + $match.Value + '" }}' }))
        if (-not $noted -and -not $fence -and $line -match '^# ') {
            $output.Add('')
            $output.AddRange([string[]] ($page.Note.Trim() -split "\r?\n"))
            $noted = $true
        }
    }
    $file = Join-Path $layer $page.Target
    New-Item -ItemType Directory -Force (Split-Path $file -Parent) | Out-Null
    [System.IO.File]::WriteAllText($file, ($output -join "`n") + "`n")
}

if (Test-Path $layer) { Remove-Item $layer -Recurse -Force }
New-Item -ItemType Directory -Force $layer | Out-Null
foreach ($page in $pages) { Convert-Document $page }
foreach ($asset in $assets.GetEnumerator()) {
    $file = Join-Path $layer $asset.Value
    New-Item -ItemType Directory -Force (Split-Path $file -Parent) | Out-Null
    Copy-Item (Join-Path $repo $asset.Key) $file
}
Write-Host "Imported $($pages.Count) documents and $($assets.Count) files into $layer"
