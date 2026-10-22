# Managed by coding-standards (scripts/sync-standards.sh). Do not edit in projects; change it upstream.
# Windows PowerShell 5.1 compatibility pass. Test-PowerShellStandard.ps1 applies it, in addition to the
# main settings, to files that declare '#Requires -Version 5.1' (for example guest VM scripts).
@{
    IncludeRules = @(
        'PSUseCompatibleSyntax'
        'PSUseCompatibleCommands'
        'PSUseCompatibleTypes'
    )
    Rules        = @{
        PSUseCompatibleSyntax   = @{
            Enable         = $true
            TargetVersions = @('5.1')
        }
        # Windows Server 2019 / Windows 10 1809 with Windows PowerShell 5.1 (bundled PSSA profile).
        PSUseCompatibleCommands = @{
            Enable         = $true
            TargetProfiles = @('win-8_x64_10.0.17763.0_5.1.17763.316_x64_4.0.30319.42000_framework')
        }
        PSUseCompatibleTypes    = @{
            Enable         = $true
            TargetProfiles = @('win-8_x64_10.0.17763.0_5.1.17763.316_x64_4.0.30319.42000_framework')
        }
    }
}
