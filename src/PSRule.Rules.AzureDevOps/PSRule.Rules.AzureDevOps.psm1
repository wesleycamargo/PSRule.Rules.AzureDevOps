# PSRule.Rules.AzureDevOps.psm1
# PSRule module for Azure DevOps

# Azure DevOps Rest API connection object
$script:connection = $null
$script:collectionStatus = $null

# Add all classes from src/Classes
Get-ChildItem -Path "$PSScriptRoot/Classes/*.ps1" | ForEach-Object {
    . $_.FullName
}

# Dot source all function scripts from src/Functions
Get-ChildItem -Path "$PSScriptRoot/Functions/*.ps1" | ForEach-Object {
    . $_.FullName
}

# Dot source all rule scripts
Get-ChildItem -Path "$PSScriptRoot/*.Rule.ps1" | ForEach-Object {
    Write-Verbose "Loading rule file: $_.FullName"
    . $_.FullName
}

<#
    .SYNOPSIS
    Run all JSON export functions for Azure DevOps for analysis by PSRule

    .DESCRIPTION
    Run all JSON export functions for Azure DevOps using Azure DevOps Rest API and this modules functions for analysis by PSRule

    .PARAMETER Organization
    Optional. The connected organization is always used; a different value only produces a warning.

    .PARAMETER OrganizationId
    Optional. Defaults to the organization ID of the connection (Connect-AzDevOps -OrganizationId).

    .PARAMETER Project
    Project name for Azure DevOps

    .PARAMETER OutputPath
    Output path for JSON files

    .PARAMETER PassThru
    Return the exported project as objects to the pipeline instead of writing to a file

    .PARAMETER CompletenessReportPath
    Write collection status to a JSON file outside OutputPath.

    .PARAMETER Strict
    Attempt every collector, then fail if any required coverage is incomplete.

    .EXAMPLE
    Export-AzDevOpsRuleData -Project $Project -OutputPath $OutputPath
#>
function Export-AzDevOpsRuleData {
    [CmdletBinding()]
    param (
        [Parameter()]
        [string]
        $Organization,

        [Parameter()]
        [string]
        $OrganizationId,

        [Parameter(Mandatory)]
        [string]
        $Project,

        [Parameter(Mandatory)]
        [string]
        $OutputPath,

        [Parameter(ParameterSetName = 'PassThru')]
        [switch]
        $PassThru,

        [Parameter()]
        [string]$CompletenessReportPath,

        [Parameter()]
        [switch]$Strict
    )

    Assert-AzDevOpsCompletenessReportPath -OutputPath $OutputPath -CompletenessReportPath $CompletenessReportPath
    $report = [ordered]@{ SchemaVersion = 1; Organization = $script:connection.Organization; Status = 'Complete'; Projects = @() }
    Invoke-AzDevOpsProjectExport -Organization $Organization -OrganizationId $OrganizationId -Project $Project -OutputPath $OutputPath -PassThru:$PassThru -Report $report
    Complete-AzDevOpsAssessmentExport -Report $report -CompletenessReportPath $CompletenessReportPath -Strict:$Strict
}

function Invoke-AzDevOpsProjectExport {
    [CmdletBinding()]
    param (
        [string]$Organization,
        [string]$OrganizationId,
        [string]$Project,
        [string]$OutputPath,
        [switch]$PassThru,
        [System.Collections.IDictionary]$Report
    )

    if ($null -eq $script:connection) {
        throw 'Not connected to Azure DevOps. Run Connect-AzDevOps first.'
    }

    if ($Organization -and $Organization -ne $script:connection.Organization) {
        Write-Warning "Provided Organization ($Organization) differs from connected organization ($($script:connection.Organization)). Using connected organization."
    }

    $Organization = $script:connection.Organization
    $AccessToken = $script:connection.Token
    if (-not $OrganizationId) {
        $OrganizationId = $script:connection.OrganizationId
    }

    Write-Host "Exporting rule data for project [$Project] to [$OutputPath]" -ForegroundColor Green


    $exportCommands = @(
        @{ Name = 'Export-AzDevOpsProject'; Params = @{ Project = $Project }; Message = "[$Project] Exporting project" },
        @{ Name = 'Export-AzDevOpsReposAndBranchPolicies'; Params = @{ Project = $Project }; Message = "[$Project] Exporting repos and branch policies" },
        @{ Name = 'Export-AzDevOpsEnvironmentChecks'; Params = @{ Project = $Project }; Message = "[$Project] Exporting environment checks" },
        @{ Name = 'Export-AzDevOpsServiceConnections'; Params = @{ Project = $Project }; Message = "[$Project] Exporting service connections" },
        @{ Name = 'Export-AzDevOpsPipelines'; Params = @{ Project = $Project }; Message = "[$Project] Exporting pipelines" },
        @{ Name = 'Export-AzDevOpsPipelinesSettings'; Params = @{ Project = $Project }; Message = "[$Project] Exporting pipelines settings" },
        @{ Name = 'Export-AzDevOpsVariableGroups'; Params = @{ Project = $Project }; Message = "[$Project] Exporting variable groups" },
        @{ Name = 'Export-AzDevOpsReleaseDefinitions'; Params = @{ Project = $Project }; Message = "[$Project] Exporting release definitions" },
        @{ Name = 'Export-AzDevOpsGroups'; Params = @{ Project = $Project }; Message = "[$Project] Exporting groups" },
        @{ Name = 'Export-AzDevOpsRetentionSettings'; Params = @{ Project = $Project }; Message = "[$Project] Exporting retention settings" },
        @{ Name = 'Export-AdoOrganizationPipelinesSettings'; Params = @{ Organization = $Organization; AccessToken = $AccessToken }; Message = "[$Project] Exporting organization pipelines settings" },
        @{ Name = 'Export-AdoOrganizationGeneralOverview'; Params = @{ Organization = $Organization; AccessToken = $AccessToken }; Message = "[$Project] Exporting organization general overview" },
        @{ Name = 'Export-AdoOrganizationGeneralBillingSettings'; Params = @{ Organization = $Organization; OrganizationId = $OrganizationId; AccessToken = $AccessToken }; Message = "[$Project] Exporting organization billing settings" },
        @{ Name = 'Export-AdoOrganizationSecurityPolicies'; Params = @{ Organization = $Organization; AccessToken = $AccessToken }; Message = "[$Project] Exporting organization security policies" }
    )

    $commonParams = if ($PassThru) {
        @{ PassThru = $true }
    }
    else {
        @{ OutputPath = $OutputPath }
    }

    $failedExports = @()
    $projectReport = [ordered]@{ Project = $Project; Status = 'Complete'; Collectors = @() }
    $Report.Projects += $projectReport

    foreach ($export in $exportCommands) {
        Write-Host $export.Message -ForegroundColor Blue

        # assemble splat from Params + commonParams
        $splat = @{}
        $splat += $export.Params
        $splat += $commonParams

        # attempt the export; on error, log and continue
        $previousStatus = $script:collectionStatus
        $script:collectionStatus = [ordered]@{ Command = $export.Name; Status = 'Completed'; ReasonCodes = @() }
        $projectReport.Collectors += $script:collectionStatus
        try {
            & $export.Name @splat -ErrorAction Stop
        }
        catch {
            $failedExports += $export.Name
            Set-AzDevOpsCollectionStatus -Status Failed -ReasonCode CollectorFailed
            Write-Error "[$($export.Name)]: Collection failed." -ErrorAction Continue
        }
        finally {
            $script:collectionStatus = $previousStatus
        }
    }

    if ($failedExports.Count) {
        Write-Warning "The following exported commands could not be executed:"
        foreach ($failedExport in $failedExports) {
            Write-Warning $failedExport
        }
    }
    else {
        Write-Host "[$($export.Name)] All commands where exported successfully!" -ForegroundColor Green
    }
}

Export-ModuleMember -Function Export-AzDevOpsRuleData -Alias Export-AzDevOpsProjectRuleData
# End of Function Export-AzDevOpsRuleData

<#
    .SYNOPSIS
    Export rule data for all projects in the DevOps organization

    .DESCRIPTION
    Export rule data for all projects in the DevOps organization using Azure DevOps Rest API and this modules functions for analysis by PSRule

    .PARAMETER OutputPath
    Output path for JSON files

    .PARAMETER Organization
    Azure DevOps Organization Name. URL Format is not required.

    .PARAMETER OrganizationId
    Azure DevOps Organization ID, in guid format.

    .PARAMETER CompletenessReportPath
    Write collection status for every project to a JSON file outside OutputPath.

    .PARAMETER Strict
    Attempt every project and collector, then fail if coverage is incomplete.

    .EXAMPLE
    Export-AzDevOpsOrganizationRuleData -Organization "MyOrg" -OrganizationId "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx" -OutputPath $OutputPath
#>
Function Export-AzDevOpsOrganizationRuleData {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string] $Organization,
        [Parameter(Mandatory)]
        [string] $OrganizationId,
        [Parameter(Mandatory)]
        [string]
        $OutputPath,
        [Parameter()]
        [string]$CompletenessReportPath,
        [Parameter()]
        [switch]$Strict
    )
    if ($null -eq $script:connection) {
        throw 'Not connected to Azure DevOps. Run Connect-AzDevOps first.'
    }
    Assert-AzDevOpsCompletenessReportPath -OutputPath $OutputPath -CompletenessReportPath $CompletenessReportPath
    $report = [ordered]@{
        SchemaVersion = 1
        Organization = $script:connection.Organization
        Status = 'Complete'
        ProjectDiscovery = [ordered]@{ Command = 'Get-AzDevOpsProject'; Status = 'Completed'; ReasonCodes = @() }
        Projects = @()
    }
    $projects = @()
    $previousStatus = $script:collectionStatus
    $script:collectionStatus = $report.ProjectDiscovery
    try {
        $projects = @(Get-AzDevOpsProject -ErrorAction Stop)
        if ($projects.Count -eq 0 -and $report.ProjectDiscovery.Status -eq 'Completed') {
            $report.ProjectDiscovery.Status = 'Empty'
            $report.ProjectDiscovery.ReasonCodes = @('EmptyCollection')
        }
    }
    catch {
        $report.ProjectDiscovery.Status = 'Failed'
        $report.ProjectDiscovery.ReasonCodes = @('ProjectDiscoveryFailed')
        Write-Error '[Get-AzDevOpsProject]: Project discovery failed.' -ErrorAction Continue
    }
    finally {
        $script:collectionStatus = $previousStatus
    }
    foreach ($project in $projects) {
        if ([string]::IsNullOrWhiteSpace($project.name)) {
            $report.ProjectDiscovery.Status = 'Partial'
            $report.ProjectDiscovery.ReasonCodes = @('MissingRequiredData')
            continue
        }
        # Create a subfolder for each project
        $subPath = Join-Path -Path $OutputPath -ChildPath $project.name
        try {
            if (-not(Test-Path -LiteralPath $subPath)) {
                New-Item -Path $subPath -ItemType Directory -ErrorAction Stop | Out-Null
            }
            Invoke-AzDevOpsProjectExport -Organization $Organization -OrganizationId $OrganizationId -Project $project.name -OutputPath $subPath -Report $report
        }
        catch {
            $report.Projects += [ordered]@{
                Project = $project.name
                Status = 'Unavailable'
                Collectors = @([ordered]@{ Command = 'Export-AzDevOpsRuleData'; Status = 'Failed'; ReasonCodes = @('ProjectExportFailed') })
            }
            Write-Error '[Export-AzDevOpsRuleData]: Project export failed.' -ErrorAction Continue
        }
    }
    Complete-AzDevOpsAssessmentExport -Report $report -CompletenessReportPath $CompletenessReportPath -Strict:$Strict
}
Export-ModuleMember -Function Export-AzDevOpsOrganizationRuleData
# End of Function Export-AzDevOpsOrganizationRuleData

Export-ModuleMember -Function Get-AzDevOpsProject
Export-ModuleMember -Function Export-AzDevOpsProject
Export-ModuleMember -Function Connect-AzDevOps
Export-ModuleMember -Function Disconnect-AzDevOps

# Define the types to export with type accelerators.
$ExportableTypes = @(
    [AzureDevOpsConnection]
)
# Get the internal TypeAccelerators class to use its static methods.
$TypeAcceleratorsClass = [psobject].Assembly.GetType(
    'System.Management.Automation.TypeAccelerators'
)
# Ensure none of the types would clobber an existing type accelerator.
# If a type accelerator with the same name exists, throw an exception.
$ExistingTypeAccelerators = $TypeAcceleratorsClass::Get
foreach ($Type in $ExportableTypes) {
    if ($Type.FullName -in $ExistingTypeAccelerators.Keys) {
        $Message = @(
            "Unable to register type accelerator '$($Type.FullName)'"
            'Accelerator already exists.'
        ) -join ' - '

        throw [System.Management.Automation.ErrorRecord]::new(
            [System.InvalidOperationException]::new($Message),
            'TypeAcceleratorAlreadyExists',
            [System.Management.Automation.ErrorCategory]::InvalidOperation,
            $Type.FullName
        )
    }
}
# Add type accelerators for every exportable type.
foreach ($Type in $ExportableTypes) {
    $TypeAcceleratorsClass::Add($Type.FullName, $Type) | Out-Null
}
# Remove type accelerators when the module is removed.
$MyInvocation.MyCommand.ScriptBlock.Module.OnRemove = {
    foreach ($Type in $ExportableTypes) {
        $TypeAcceleratorsClass::Remove($Type.FullName) | Out-Null
    }
}.GetNewClosure()
