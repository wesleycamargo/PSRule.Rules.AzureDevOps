# Each live rule container collects only its own target family into its TestDrive.
function New-LiveRuleTestData {
    param ([string]$ExportCommand, [string]$OutputPath)

    $required = 'ADO_ORGANIZATION', 'ADO_PROJECT', 'ADO_PAT', 'ADO_PAT_READONLY', 'ADO_PAT_FINEGRAINED'
    $missing = @($required | Where-Object { -not [Environment]::GetEnvironmentVariable($_) })
    if ($missing.Count) {
        throw "Live rule tests require $($missing -join ', '). Run tests/Run-Tests.ps1 -TestType Integration or set these variables before selecting a live test file."
    }

    $tokens = [ordered]@{
        FullAccess = $env:ADO_PAT
        ReadOnly = $env:ADO_PAT_READONLY
        FineGrained = $env:ADO_PAT_FINEGRAINED
    }
    $paths = @{}
    foreach ($profile in $tokens.Keys) {
        $path = Join-Path $OutputPath $profile
        New-Item -Path $path -ItemType Directory -Force | Out-Null
        try {
            Connect-AzDevOps -Organization $env:ADO_ORGANIZATION -PAT $tokens[$profile] -TokenType $profile
            $parameters = @{ OutputPath = $path }
            if ($ExportCommand -like 'Export-AdoOrganization*') {
                $parameters.Organization = $env:ADO_ORGANIZATION
                $parameters.AccessToken = 'Basic ' + [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(":$($tokens[$profile])"))
            }
            else {
                $parameters.Project = $env:ADO_PROJECT
            }
            & $ExportCommand @parameters -ErrorAction Stop | Out-Null
            $paths[$profile] = $path
        }
        finally {
            Disconnect-AzDevOps
        }
    }
    return $paths
}
