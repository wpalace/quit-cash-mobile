#Requires -Version 7.4
<#
.SYNOPSIS
    Checks PowerShell files against the house formatter and analyzer rules.

.DESCRIPTION
    Fails when a file differs from Invoke-Formatter output or has PSScriptAnalyzer findings.
    Files that declare '#Requires -Version 5.1' (or any 5.x) also get a Windows PowerShell 5.1
    compatibility pass using PSScriptAnalyzerSettings.Compat51.psd1 from the settings directory.
    Paths listed in .standards-exclude are skipped (frozen files; see the PowerShell skill).

    Each file is analyzed on its own. PSScriptAnalyzer 1.25 intermittently crashes in
    UseCorrectCasing (sometimes followed by "Get-Command is not recognized"); such runs are
    retried up to -MaxAttempts times and never accepted. If a file still crashes after the
    last attempt, the script fails. Findings are never dropped.

.PARAMETER Path
    Files to check (position 0). Defaults to all tracked *.ps1, *.psm1 and *.psd1 files.
    When passing several files from a shell, name -SettingsPath and append the files.

.PARAMETER SettingsPath
    PSScriptAnalyzer settings file (position 1). Defaults to ./PSScriptAnalyzerSettings.psd1.

.EXAMPLE
    ./.standards/scripts/Test-PowerShellStandard.ps1

.EXAMPLE
    ./.standards/scripts/Test-PowerShellStandard.ps1 ./build.ps1 ./PSScriptAnalyzerSettings.psd1

.EXAMPLE
    pwsh -File ./.standards/scripts/Test-PowerShellStandard.ps1 `
        -SettingsPath ./PSScriptAnalyzerSettings.psd1 a.ps1 b.psm1
#>
[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [string[]]$Path,

    [Parameter(Position = 1)]
    [ValidatePattern('\.psd1$')]
    [ValidateScript({ Test-Path -LiteralPath $_ -PathType Leaf })]
    [string]$SettingsPath = (Join-Path -Path $PWD -ChildPath 'PSScriptAnalyzerSettings.psd1'),

    [ValidateRange(1, 50)]
    [int]$MaxAttempts = 10,

    # Collects extra file names appended by pre-commit after the named parameters.
    [Parameter(ValueFromRemainingArguments, DontShow)]
    [string[]]$AdditionalPath
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

# Matches the known transient PSSA 1.25 failures. Any other error is a real failure.
$transientPattern = 'UseCorrectCasing|''Get-Command'' is not recognized'

function Invoke-PssaWithRetry {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [scriptblock]$Operation,

        [Parameter(Mandatory)]
        [string]$Description,

        [Parameter(Mandatory)]
        [int]$Attempts
    )

    for ($attempt = 1; $attempt -le $Attempts; $attempt++) {
        $global:LASTEXITCODE = 0
        try {
            return (& $Operation)
        } catch {
            if ($_.Exception.Message -notmatch $transientPattern) {
                throw
            }
            $message = $_.Exception.Message
            Write-Warning -Message "PSSA crash on $Description (attempt $attempt of $Attempts): $message"
        }
    }
    throw "PSScriptAnalyzer crashed on $Description in all $Attempts attempts. Crashed runs are never accepted."
}

function Get-ExcludedPath {
    [CmdletBinding()]
    [OutputType([string])]
    param()

    $excludeFile = Join-Path -Path $PWD -ChildPath '.standards-exclude'
    if (-not (Test-Path -LiteralPath $excludeFile)) {
        return
    }
    foreach ($line in Get-Content -LiteralPath $excludeFile) {
        $entry = $line.Trim()
        if (-not $entry -or $entry.StartsWith('#')) {
            continue
        }
        $entry.Split('#', 2)[0].Trim()
    }
}

$files = @($Path) + @($AdditionalPath) | Where-Object { $_ }
if (-not $files) {
    $files = @(git ls-files -- '*.ps1' '*.psm1' '*.psd1' ':!:.standards/**')
}

$excluded = @(Get-ExcludedPath)
$settingsDirectory = Split-Path -Path $SettingsPath -Parent
$compatSettings = Join-Path -Path $settingsDirectory -ChildPath 'PSScriptAnalyzerSettings.Compat51.psd1'

$failed = $false
foreach ($file in $files) {
    $relative = [IO.Path]::GetRelativePath($PWD, (Resolve-Path -LiteralPath $file).Path).Replace('\', '/')
    if ($excluded | Where-Object { $relative -like $_ }) {
        Write-Verbose -Message "Skipping excluded file: $relative"
        continue
    }

    $raw = Get-Content -LiteralPath $file -Raw
    if ([string]::IsNullOrEmpty($raw)) {
        continue
    }

    $retry = @{ Attempts = $MaxAttempts }

    $formatted = Invoke-PssaWithRetry @retry -Description "Invoke-Formatter $file" -Operation {
        Invoke-Formatter -ScriptDefinition $raw -Settings $SettingsPath
    }
    if ($formatted -cne $raw) {
        Write-Warning -Message "Not formatted: $file (run Invoke-Formatter with $SettingsPath)"
        $failed = $true
    }

    $findings = @(Invoke-PssaWithRetry @retry -Description "Invoke-ScriptAnalyzer $file" -Operation {
            Invoke-ScriptAnalyzer -Path $file -Settings $SettingsPath
        })

    if ($raw -match '(?im)^#Requires\s+-Version\s+5(\.\d+)?\b') {
        if (-not (Test-Path -LiteralPath $compatSettings -PathType Leaf)) {
            throw "$file targets Windows PowerShell 5.1 but $compatSettings is missing."
        }
        $findings += @(Invoke-PssaWithRetry @retry -Description "5.1 compatibility $file" -Operation {
                Invoke-ScriptAnalyzer -Path $file -Settings $compatSettings
            })
    }

    $findings = @($findings | Where-Object { $_ })
    if ($findings.Count -gt 0) {
        $findings | Select-Object -Property ScriptName, Line, Severity, RuleName, Message
        $failed = $true
    }
}

if ($failed) {
    exit 1
}
