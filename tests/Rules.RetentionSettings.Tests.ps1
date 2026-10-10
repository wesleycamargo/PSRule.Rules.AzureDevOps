BeforeAll {
    # Setup error handling
    $ErrorActionPreference = 'Stop';
    Set-StrictMode -Version latest;

    if ($Env:SYSTEM_DEBUG -eq 'true') {
        $VerbosePreference = 'Continue';
    }

    # Setup tests paths
    # $rootPath = $PWD;
    $rootPath = Split-Path -Path $PSScriptRoot -Parent
    $ourModule = (Join-Path -Path $rootPath -ChildPath 'src/PSRule.Rules.AzureDevOps')

    Import-Module -Name $ourModule -Force
    . "$PSScriptRoot/helpers/LiveRuleTestData.ps1"
    $paths = New-LiveRuleTestData -ExportCommand Export-AzDevOpsRetentionSettings -OutputPath (Join-Path $TestDrive 'exports')
    $outPath = $paths.FullAccess
    $outPathReadOnly = $paths.ReadOnly
    $outPathFineGrained = $paths.FineGrained

    
    # Run rules with default token type
    $ruleResult = Invoke-PSRule -InputPath "$($outPath)/" -Module PSRule.Rules.AzureDevOps -Format Detect -Culture en


    # Run rules with ReadOnly token type
    $ruleResultReadOnly = Invoke-PSRule -InputPath "$($outPathReadOnly)/" -Module PSRule.Rules.AzureDevOps -Format Detect -Culture en


    # Run rules with FineGrained token type
    $ruleResultFineGrained = Invoke-PSRule -InputPath "$($outPathFineGrained)/" -Module PSRule.Rules.AzureDevOps -Format Detect -Culture en
}

Describe "Azure.DevOps.RetentionSettings rules" -Tag 'Integration' {
    Context ' Azure.DevOps.RetentionSettings.ArtifactMinimumRetentionDays' {
        It ' should pass once' {
            $ruleHits = @($ruleResult | Where-Object { $_.RuleName -eq 'Azure.DevOps.RetentionSettings.ArtifactMinimumRetentionDays' })
            $ruleHits[0].Outcome | Should -Be 'Pass';
            $ruleHits.Count | Should -Be 1;
        }

        It ' should pass once for ReadOnly token type' {
            $ruleHits = @($ruleResultReadOnly | Where-Object { $_.RuleName -eq 'Azure.DevOps.RetentionSettings.ArtifactMinimumRetentionDays' })
            $ruleHits[0].Outcome | Should -Be 'Pass';
            $ruleHits.Count | Should -Be 1;
        }

        It ' should pass once for FineGrained token type' {
            $ruleHits = @($ruleResultFineGrained | Where-Object { $_.RuleName -eq 'Azure.DevOps.RetentionSettings.ArtifactMinimumRetentionDays' })
            $ruleHits[0].Outcome | Should -Be 'Pass';
            $ruleHits.Count | Should -Be 1;
        }
    }

    Context ' Azure.DevOps.RetentionSettings.PullRequestRunsMinimumRetentionDays' {
        It ' should pass once' {
            $ruleHits = @($ruleResult | Where-Object { $_.RuleName -eq 'Azure.DevOps.RetentionSettings.PullRequestRunsMinimumRetentionDays' })
            $ruleHits[0].Outcome | Should -Be 'Pass';
            $ruleHits.Count | Should -Be 1;
        }

        It ' should pass once for ReadOnly token type' {
            $ruleHits = @($ruleResultReadOnly | Where-Object { $_.RuleName -eq 'Azure.DevOps.RetentionSettings.PullRequestRunsMinimumRetentionDays' })
            $ruleHits[0].Outcome | Should -Be 'Pass';
            $ruleHits.Count | Should -Be 1;
        }

        It ' should pass once for FineGrained token type' {
            $ruleHits = @($ruleResultFineGrained | Where-Object { $_.RuleName -eq 'Azure.DevOps.RetentionSettings.PullRequestRunsMinimumRetentionDays' })
            $ruleHits[0].Outcome | Should -Be 'Pass';
            $ruleHits.Count | Should -Be 1;
        }
    }
}

AfterAll {
    # Remove Module
    Remove-Module -Name PSRule.Rules.AzureDevOps -Force
}
