BeforeAll {
    Import-Module "$PSScriptRoot/../src/PSRule.Rules.AzureDevOps/PSRule.Rules.AzureDevOps.psd1" -Force
}

Describe 'Read-AdoOrganizationPipelinesSettings with an explicit token' -Tag 'Unit' {
    BeforeEach {
        InModuleScope PSRule.Rules.AzureDevOps {
            Disconnect-AzDevOps
        }
    }

    It 'retrieves settings without module connection state' {
        InModuleScope PSRule.Rules.AzureDevOps {
            $payload = @{ dataProviders = @{ 'ms.vss-build-web.pipelines-org-settings-data-provider' = @{ statusBadgesArePrivate = $true; enableShellTasksArgsSanitizing = $true } } } | ConvertTo-Json -Depth 10
            Mock Invoke-WebRequest { [pscustomobject]@{ Content = $payload; RawContent = $payload } }

            $settings = Read-AdoOrganizationPipelinesSettings -Organization fixture-org -AccessToken 'Bearer fixture-token'

            $settings.statusBadgesArePrivate | Should -BeTrue
            $settings.enableShellTasksArgsSanitizing | Should -BeTrue
            Assert-MockCalled Invoke-WebRequest -Times 1 -Exactly
        }
    }

    It 'reports an authentication response as a retrieval failure' {
        InModuleScope PSRule.Rules.AzureDevOps {
            Mock Invoke-WebRequest { [pscustomobject]@{ Content = '<html>Sign In</html>'; RawContent = 'Sign In' } }

            { Read-AdoOrganizationPipelinesSettings -Organization fixture-org -AccessToken 'Bearer expired-token' } | Should -Throw '*Failed to retrieve pipeline settings*'
            Assert-MockCalled Invoke-WebRequest -Times 1 -Exactly
        }
    }
}

AfterAll {
    Remove-Module PSRule.Rules.AzureDevOps -Force
}
