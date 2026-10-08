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

    Import-Module -Name $ourModule -Force;
}

Describe "PSRule.Rules.AzureDevOps Rules" -Tag 'Unit' {
    Context ' Base rules' {
        It ' should contain 119 rules' {
            $rules = Get-PSRule -Module PSRule.Rules.AzureDevOps
            $rules.Count | Should -Be 119
        }

        It ' should contain a markdown help file for each rule' {
            $rules = Get-PSRule -Module PSRule.Rules.AzureDevOps
            $rules | ForEach-Object {
                $helpFile = Join-Path -Path "$ourModule/en" -ChildPath "$($_.Name).md"
                Test-Path -Path $helpFile | Should -Be $true
            }
        }
    }

    Context 'Rule Loading' {
        It ' should load all 24 organization pipeline settings rules' {
            $rules = Get-PSRule -Module PSRule.Rules.AzureDevOps
            $orgRules = $rules | Where-Object { $_.Name -like 'Azure.DevOps.Organization.Pipelines.Settings.*' }
            $orgRules.Count | Should -Be 24
            $orgRules | ForEach-Object { Write-Verbose "Loaded rule: $($_.Name)" }
        }
    }
}

Describe "Azure DevOps rule data exports" -Tag 'Integration' {
    BeforeAll {
        $here = (Resolve-Path $PSScriptRoot).Path;

         # Create tempory test output folder and store path
        $outPath = New-Item -Path (Join-Path -Path $here -ChildPath 'out') -ItemType Directory -Force;
        $outPath = $outPath.FullName;

        # Export all Azure DevOps rule data for project 'psrule-fail-project' to output folder
        Connect-AzDevOps -Organization $env:ADO_ORGANIZATION -PAT $env:ADO_PAT
        Export-AzDevOpsRuleData -Project $env:ADO_PROJECT -OutputPath $outPath

        # Create a temporary test output folder for tests with the ReadOnly TokenType
        $outPathReadOnly = New-Item -Path (Join-Path -Path $here -ChildPath 'outReadOnly') -ItemType Directory -Force;
        $outPathReadOnly = $outPathReadOnly.FullName;

        # Export all Azure DevOps rule data for project 'psrule-fail-project' to ReadOnly output folder
        Connect-AzDevOps -Organization $env:ADO_ORGANIZATION -PAT $env:ADO_PAT_READONLY -TokenType ReadOnly
        Export-AzDevOpsRuleData -Project $env:ADO_PROJECT -OutputPath $outPathReadOnly

        # Create a temporary test output folder for tests with the FineGrained TokenType
        $outPathFineGrained = New-Item -Path (Join-Path -Path $here -ChildPath 'outFineGrained') -ItemType Directory -Force;
        $outPathFineGrained = $outPathFineGrained.FullName;

        # Export all Azure DevOps rule data for project 'psrule-fail-project' to FineGrained output folder
        Connect-AzDevOps -Organization $env:ADO_ORGANIZATION -PAT $env:ADO_PAT_FINEGRAINED -TokenType FineGrained
        Export-AzDevOpsRuleData -Project $env:ADO_PROJECT -OutputPath $outPathFineGrained
    }

    It 'should export rule data for all three permission profiles' {
        foreach ($path in @($outPath, $outPathReadOnly, $outPathFineGrained)) {
            @(Get-ChildItem -Path $path -Filter '*.ado.json' -File).Count | Should -BeGreaterThan 0
        }
    }

    AfterAll {
        Disconnect-AzDevOps
    }
}

AfterAll {
    # Remove Module
    Disconnect-AzDevOps
    Remove-Module -Name PSRule.Rules.AzureDevOps -Force;
}
