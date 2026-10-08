# Test state report

Review date: 2026-10-06. Scope: the current workspace, including pre-existing
changes; this is not a report of the latest hosted CI run.

Implementation phases and acceptance checks are recorded in the
[phased test repair plan](test-repair-phases.md). The measurements below describe
the initial baseline; completed Phase 1 results are recorded separately below.

## Initial assessment

Test discovery is healthy, but the suite is not currently a reliable local
validation gate. All 24 test files parse and Pester discovers 680 tests. A full
credential-free attempt reports 11 passed and 669 failed, with 14 failed containers
and 70 failed setup blocks. These totals include tests marked failed because their
setup failed; they do not demonstrate 669 application regressions.

Five selected disconnected-operation tests pass with synthetic project/output
values. Ten separate live module smoke checks also pass against the supplied
Azure DevOps project using the Azure CLI bearer token. Independent offline probes
confirm stale catalog expectations, missing rule help, and an unsupported assertion
operator. CI also needs explicit test
failure propagation. Corrections are recorded in the
[assessment backlog](assessment-backlog.md).

## Phase 1 results — 2026-10-06

Phase 1 local corrections are complete. Module imports resolve from each test
file's directory. Common tests import the module and use module scope for private
connection state and project ACL retrieval. Catalog checks no longer trigger live
exports; they assert 119 total rules, 24 organization pipeline settings rules,
and English help for every discovered rule. The Debug rule now has English help.
Pipeline YAML calls use `-Project`; property checks use Pester-supported assertions.

| Check | Result |
| --- | --- |
| Parse all 24 test files | Zero errors |
| Discover all repository tests | 681 tests; zero failed containers |
| Selected `Unit` tests | 12 passed, zero failed, zero skipped; 669 excluded |
| Credential-free execution | `ADO_*` and `GITHUB_WORKSPACE` unset; run from `/tmp` |
| HTTP guards | Zero `Invoke-RestMethod` or `Invoke-WebRequest` calls |
| Existing property assertion with synthetic complete input | Pass, including false-valued properties |
| Existing property assertion with a required field removed | Correctly throws for the missing property |
| Git whitespace check | Pass |

The Unit selection ran in 23.03 seconds. The two property probes ran separately
against the actual assertion block extracted from the repository test; they are
not included in the 681 repository tests. Discovery increased by one because the
retained live export setup now has an explicit integration test that checks for
exported records in all three permission profiles. Its authentication prerequisites
remain pending and it was excluded from the offline run.

This does not establish a passing full suite. Authentication contract and
constructor defects remain for Phase 2; the remaining tests still need independent
fixtures and tags in Phase 3. The retained informational Debug rule and its existing
GA tag were unchanged; broader catalog and baseline review remains in ADO-011.
No live Azure operations or source pushes were performed for Phase 1. NUnit output
was written only to `/tmp/assessment-phase1-testresults.xml`.

Reproduce the current offline selection from the repository root:

```powershell
Import-Module /tmp/assessment-test-modules/Pester/5.7.1/Pester.psd1 -Force
Invoke-Pester -Path ./tests -Tag Unit -Output Detailed -CI
```

The import path is specific to this workspace; elsewhere import an installed
Pester 5.7.1 module. `GITHUB_WORKSPACE` is no longer required. For the validation
above, a separate noninteractive process removed Azure environment variables and
installed throwing HTTP guards before invoking this selection.

## Phase 2 and Phase 3 progress — 2026-10-06

Phase 2 is complete. `Connect-AzDevOps` now uses the matching constructor shape
for PAT, service principal, managed identity, and bearer authentication. It accepts
the supported token profiles and retains a supplied organization identifier for all
modes. Five mocked tests cover the modes and a failed service-principal token
request; they make no live requests or use credentials.

Phase 3 is in progress. All 27 test files parse and Pester discovers 692 tests.
The new `tests/Run-Tests.ps1` defaults to tagged Unit tests, requires Pester
5.7.1, emits NUnit XML, and sets Pester's failure exit behavior. The current Unit
selection passes 23 tests in 22.19 seconds. It covers synthetic project visibility
and variable-group outcomes, writes the three project permission profiles to
temporary test directories, and validates explicit-token organization pipeline
settings retrieval through a mocked request. The 669 remaining tests are explicitly
tagged Integration because their legacy setups still require live exports. They are
excluded from the Unit command and are not yet deterministic. An isolated
intentional Pester failure with the same `Run.Exit` setting returned exit code 1.

## Integration fixture setup blocker — 2026-10-06

The authenticated Azure CLI identity can read both the control and fixture
projects, but Azure DevOps rejected creation of the planned `psrule-fixture-*`
repositories in `PSRule.Rules.AzureDevOps.Tests` with `TF401027`: the identity
lacks the project-scoped `Git: CreateRepository` permission. The fixture project
currently has no repositories, pipelines, environments, service connections, or
variable groups. Grant the CLI identity that repository permission, or project
administrator rights limited to the fixture project, before creating fake
integration resources.

## Live Integration tests repaired — 2026-10-06 to 2026-10-08

The blocker above was the Stakeholder access level, not the Git permission; it was
resolved by raising the identity to Basic. The user then chose to keep the legacy
tests as written. `tests/Initialize-IntegrationTestData.ps1` seeds the resources they
name, and `tests/Run-Tests.ps1` fills missing `ADO_*` variables from the Azure CLI login.
Details, Azure DevOps changes, and code fixes are in
[test-repair-phases.md](test-repair-phases.md#phase-4--synthetic-azure-devops-fixture-project).

| Selection | Before | After |
| --- | --- | --- |
| Integration (with CLI token) | 177 passed, 501 failed | 645 passed, 33 failed (before the authentication split) |
| Unit | 23 passed | 23 passed |
| Authentication (new, 25 tests) | — | 6 passed, 19 failed without SP credentials or Azure-hosted MSI |

Remaining Integration failures are external: the `empty-project` project and three
organization pipeline settings. The runner's exit code equals the failure count.

## Baseline environment and methods

| Component or prerequisite | Observed state |
| --- | --- |
| PowerShell | 7.6.6, Core, Debian GNU/Linux 12 |
| PSRule | 2.9.0 installed |
| Pester | Initially absent; 5.7.1 downloaded only into `/tmp/assessment-test-modules` |
| PSScriptAnalyzer | Not installed; analyzer checks not executed |
| Azure DevOps environment | No `ADO_*` variables configured |
| Export fixtures | No `tests/out`, `tests/outReadOnly`, or `tests/outFineGrained` directories before the run |
| Azure CLI authentication | Authenticated; Azure DevOps resource token acquisition succeeded |
| Azure CLI test target | User supplied `https://dev.azure.com/ai-experiments/PSRule.Rules.AzureDevOps`; organization and project access verified |

The full-suite attempt ran in a separate noninteractive PowerShell process, with
`GITHUB_WORKSPACE` set to the repository, `ADO_*` variables absent, and guards
against live `Invoke-RestMethod` and `Invoke-WebRequest` requests. No request reached
those guards: setup and parameter validation failed first. Empty output directories
created during the attempt were removed. No credentials, tokens, or organization
exports were persisted in the repository.

Azure CLI token acquisition used resource `499b84ac-1321-427f-aa17-267ca6975798`.
Only authentication status and expiry metadata were displayed. The supplied organization
and project were verified through authenticated read requests, then used for ten
separate live smoke checks. CLI bearer authentication cannot replace PAT-,
service-principal-, or managed-identity-specific test coverage.

## Executed checks

| Check | Result | Interpretation |
| --- | --- | --- |
| PowerShell parser, 24 test files | 0 parse errors | Test source syntax is valid |
| Pester discovery | 680 tests; 0 discovery errors | Definitions load; setup and assertions are not validated by discovery |
| Local module import and PSRule discovery | Import succeeded; 119 rules discovered | Local catalog is readable |
| Full credential-free suite attempt | 11 passed, 669 failed, 0 skipped, 0 not run; 113.08 seconds | Setup/environment failures dominate; not a live correctness result |
| Selected existing disconnected tests | 5 passed, 0 failed; 103 other tests in those files filtered out | Disconnected guards work with valid synthetic inputs |
| Azure CLI bearer-authenticated live module smoke checks | 10 passed, 0 failed | Read access and selected collectors work against the supplied project |
| Four temporary expectation probes | 4 failed as expected | Independently reproduces confirmed test defects |
| Deliberately failing Pester probe with CI defaults | Process exit code 0 | Failed tests alone do not fail that invocation |
| Same probe with `Run.Exit = $true` | Process exit code 1 | Explicit failure propagation works |

The five passing selected tests cover disconnected repository retrieval, pipeline
retrieval, pipeline ACL retrieval, retention retrieval, and retention export. They
are a separate run and must not be added to the full-suite totals. Temporary probes
are also separate from the repository's 680 tests.

## Azure CLI authenticated live checks

Target: `https://dev.azure.com/ai-experiments/PSRule.Rules.AzureDevOps`.
The module connected using `-AccessToken` and the organization identifier retrieved
from the connection-data endpoint. The token stayed in process memory.

| Live check | Result |
| --- | --- |
| Retrieve project and verify its identifier/name | Pass |
| Retrieve repositories and validate returned identifiers/names | Pass |
| Retrieve pipeline definitions without running pipelines | Pass |
| Retrieve environments | Pass |
| Retrieve service connections | Pass |
| Retrieve variable groups | Pass |
| Retrieve project groups | Pass |
| Retrieve retention settings and policy | Pass |
| Retrieve organization pipeline settings | Pass |
| Retrieve organization security policies | Pass |

These were ten temporary Pester smoke tests, with zero failed containers or setup
blocks. Collection tests validate returned record identifiers; legitimately empty
collections are permitted. They establish selected collector accessibility and
basic returned shape, not complete rule coverage, pagination correctness, or the
availability of the original suite's named pass/fail fixtures.

No pipelines were triggered, no settings were changed, and no exported organization
data was added to the repository. Read-only organization settings queries use their
existing portal retrieval endpoints. The original 680-test suite was not rerun by
substituting bearer credentials for its PAT/service-principal/managed-identity
scenarios: doing so would change the meaning of those tests while leaving setup
and binding defects unresolved.

To reproduce the authenticated connection without displaying the token:

```powershell
Import-Module ./src/PSRule.Rules.AzureDevOps/PSRule.Rules.AzureDevOps.psd1 -Force
$auth = az account get-access-token `
    --resource 499b84ac-1321-427f-aa17-267ca6975798 --output json | ConvertFrom-Json
if ($LASTEXITCODE -ne 0 -or -not $auth.accessToken) {
    throw 'Azure CLI token acquisition failed.'
}
$organization = 'ai-experiments'
$project = 'PSRule.Rules.AzureDevOps'
$headers = @{ Authorization = 'Bearer ' + $auth.accessToken }
$connectionData = Invoke-RestMethod `
    -Uri "https://dev.azure.com/$organization/_apis/connectionData" -Headers $headers
Connect-AzDevOps -Organization $organization `
    -OrganizationId $connectionData.instanceId -AccessToken $auth.accessToken
Get-AzDevOpsProject -Project $project
Disconnect-AzDevOps
$headers = $null
$auth = $null
```

## Confirmed corrections

### 1. Common test setup executes module-only code outside a module

The full run fails [Common.Tests.ps1](../tests/Common.Tests.ps1) with:

> The Export-ModuleMember cmdlet can only be called from inside a module.

Its `BeforeAll` dot-sources [Common.ps1](../src/PSRule.Rules.AzureDevOps/Functions/Common.ps1),
which invokes `Export-ModuleMember`. Discovery succeeds because `BeforeAll` runs
later. Import the module and access private state through Pester module scope
instead of executing the function file in test scope. **Backlog: ADO-010.**

### 2. Test calls and current command interfaces have drifted

A comparison of named test parameters with actual exported command metadata finds
17 unsupported uses:

| Command and unsupported parameter | Occurrences | Example evidence |
| --- | --- | --- |
| `Connect-AzDevOps -AuthType` | 6 | [Common.Tests.ps1](../tests/Common.Tests.ps1), line 38 |
| `Connect-AzDevOps -TokenType` | 9 | [Rules.Common.Tests.ps1](../tests/Rules.Common.Tests.ps1), line 31 |
| `Get-AzDevOpsPipelineYaml -ProjectId` | 2 | [DevOps.Pipelines.Core.Tests.ps1](../tests/DevOps.Pipelines.Core.Tests.ps1), line 191 |

`AccessToken` is a supported connection parameter. However, the current connection
function requires `OrganizationId`, and its test calls omit that value. The three
aggregate exports in `Rules.Common.Tests.ps1` also omit mandatory `Organization`
and `OrganizationId`. These problems remain even after credentials are supplied.

The YAML negative tests use a generic `Should -Throw`, so a parameter-binding
failure can satisfy the assertion without exercising the intended API failure.
Align tests, supported authentication modes, and documented interfaces; verify
negative tests reach the intended API boundary. **Backlog: ADO-010.**

### 3. Catalog assertions are stale and one rule lacks English help

Independent probes reproduce these exact expectation failures:

- Global catalog: expected 77, observed 119.
- Organization pipeline settings: expected 10, observed 24.
- English help is missing for `Azure.DevOps.Organization.Security.Policies.Debug`.

The stale counts are in [Rules.Common.Tests.ps1](../tests/Rules.Common.Tests.ps1)
and [Rules.Organization.Pipelines.Settings.Tests.ps1](../tests/Rules.Organization.Pipelines.Settings.Tests.ps1).
The [debug rule](../src/PSRule.Rules.AzureDevOps/rules/AzureDevOps.Organization.Security.Policies.Rule.ps1)
is tagged `release = GA`. Use an intentional maintained catalog expectation and
resolve whether the diagnostic rule belongs in the assessed catalog; document any
rule retained there. **Backlog: ADO-011.**

### 4. An assertion uses an unregistered Pester operator

`Rules.Organization.Pipelines.Settings.Tests.ps1`, line 84, uses
`Should -HaveProperty`. No `HaveProperty` operator is registered in Pester 5.7.1,
and no registration exists in the tests. A temporary invocation reproduces a
parameter-set resolution failure. Replace it with supported assertions that check
every required property explicitly. **Backlog: ADO-011.**

### 5. CI does not explicitly propagate Pester failure

[Module CI](../.github/workflows/module-ci.yml) invokes Pester without configuring
`Run.Exit`, `Run.Throw`, or checking returned failures. Pester 5.7.1 defaults both
options to false. A deliberately failing temporary test returns process exit code
0 under those defaults and 1 when `Run.Exit` is true.

Configure explicit failure propagation and retain test/coverage uploads when the
test step fails. The workflow currently installs unpinned Pester, so the tested
version must also be pinned. **Backlog: ADO-008, raised to P1.**

## Test design and coverage gaps

The AST inventory contains 334 function test declarations and 346 rule test
declarations. It finds no `Mock` commands or tags on `Describe` blocks. Function
tests generally depend on live access; rule tests depend on exports produced by
another file's setup. There is no explicit offline/integration separation.

All 13 rule-test containers fail in the full attempt: export setup fails in
`Rules.Common.Tests.ps1`, and the other 12 cannot obtain the required fixture
directories. Fixture preparation should be independent of file ordering, with
clear behavior when live prerequisites are missing. **Backlog: ADO-002, expanded.**

The tests also assume specific external resources: repository names, project
names such as `empty-project`, pipeline IDs such as 7 and 10, and fixed result
counts. A newly selected organization/project may authenticate successfully
without satisfying those fixture assumptions. Generic bearer smoke checks and
fixture-dependent integration tests must be identified separately.

A literal-name audit finds 36 of the 119 discovered rules without their full name
referenced in the tests:

| Rule area | Rules without a literal test reference |
| --- | --- |
| Organization billing | 3 |
| Organization overview | 4 |
| Organization pipeline settings | 14 |
| Organization security policies, including debug | 11 |
| Pipeline YAML | 2 |
| Service connection production checks/approval | 2 |

This is a static diagnostic, not measured execution coverage. The names are listed
below so that semantic coverage can be checked before adding tests.

The rule tests contain 320 uses of `$ruleHits[0].Outcome`. Some assert several hits
but only verify the first outcome. Retention tests check passing results without
failing boundary cases; group minimum/maximum member tests similarly check only
passing results. Validate every matched result and add paired pass/fail cases.
**Backlog: ADO-012.**

No meaningful code coverage percentage was produced. The run failed extensively
in setup, and coverage collection was disabled for this review. PowerShell 5.1
and hosted CI behavior were not exercised.

## Reproduce the discovery and passing subset

From the repository root in PowerShell, obtain the same temporary Pester version:

```powershell
Save-Module -Name Pester -RequiredVersion 5.7.1 `
    -Path /tmp/assessment-test-modules -Repository PSGallery
Import-Module /tmp/assessment-test-modules/Pester/5.7.1/Pester.psd1 -Force
$env:GITHUB_WORKSPACE = $PWD.Path

$config = New-PesterConfiguration
$config.Run.Path = './tests'
$config.Run.SkipRun = $true
$config.Run.PassThru = $true
Invoke-Pester -Configuration $config
```

For the five existing disconnected tests, use synthetic values in a disposable
PowerShell process:

```powershell
$env:ADO_PROJECT = 'test-state-project'
$env:ADO_EXPORT_DIR = '/tmp/assessment-test-output'
$config = New-PesterConfiguration
$config.Run.Path = @(
    './tests/DevOps.Repos.Tests.ps1'
    './tests/DevOps.Pipelines.Core.Tests.ps1'
    './tests/DevOps.RetentionSettings.Tests.ps1'
)
$config.Filter.FullName = @(
    '*Get-AzDevOpsRepos without a connection*'
    '*Get-AzDevOpsPipelines without a connection*'
    '*Get-AzDevOpsPipelineAcls without a connection*'
    '*Get-AzDevOpsRetentionSettings without a connection*'
    '*Export-AzDevOpsRetentionSettings without a connection*'
)
$config.Run.PassThru = $true
Invoke-Pester -Configuration $config
```

The full-suite attempt used the same installed Pester with `Run.Path = './tests'`
and `Run.PassThru = $true` in a noninteractive process, removed all `ADO_*`
environment variables for that process, and defined global guards for the two HTTP
cmdlets before invocation. Running the ordinary live suite requires fixture setup
and the contract corrections above; adding a CLI token alone is insufficient.

## Test-file inventory

Counts are `It` declarations confirmed by Pester discovery, not passing tests.

| Test file | Tests |
| --- | --- |
| [Common.Tests.ps1](../tests/Common.Tests.ps1) | 51 |
| [DevOps.Groups.Tests.ps1](../tests/DevOps.Groups.Tests.ps1) | 38 |
| [DevOps.Organization.Pipelines.Settings.Tests.ps1](../tests/DevOps.Organization.Pipelines.Settings.Tests.ps1) | 15 |
| [DevOps.Pipelines.Core.Tests.ps1](../tests/DevOps.Pipelines.Core.Tests.ps1) | 33 |
| [DevOps.Pipelines.Environments.Tests.ps1](../tests/DevOps.Pipelines.Environments.Tests.ps1) | 34 |
| [DevOps.Pipelines.Releases.Tests.ps1](../tests/DevOps.Pipelines.Releases.Tests.ps1) | 24 |
| [DevOps.Pipelines.Settings.Tests.ps1](../tests/DevOps.Pipelines.Settings.Tests.ps1) | 15 |
| [DevOps.Repos.Tests.ps1](../tests/DevOps.Repos.Tests.ps1) | 52 |
| [DevOps.RetentionSettings.Tests.ps1](../tests/DevOps.RetentionSettings.Tests.ps1) | 23 |
| [DevOps.ServiceConnections.Tests.ps1](../tests/DevOps.ServiceConnections.Tests.ps1) | 27 |
| [DevOps.Tasks.VariableGroups.Tests.ps1](../tests/DevOps.Tasks.VariableGroups.Tests.ps1) | 22 |
| [Rules.Common.Tests.ps1](../tests/Rules.Common.Tests.ps1) | 2 |
| [Rules.Groups.Tests.ps1](../tests/Rules.Groups.Tests.ps1) | 9 |
| [Rules.Organization.Pipelines.Settings.Tests.ps1](../tests/Rules.Organization.Pipelines.Settings.Tests.ps1) | 43 |
| [Rules.Pipelines.Core.Tests.ps1](../tests/Rules.Pipelines.Core.Tests.ps1) | 19 |
| [Rules.Pipelines.Environments.Tests.ps1](../tests/Rules.Pipelines.Environments.Tests.ps1) | 30 |
| [Rules.Pipelines.Releases.Tests.ps1](../tests/Rules.Pipelines.Releases.Tests.ps1) | 25 |
| [Rules.Pipelines.Settings.Tests.ps1](../tests/Rules.Pipelines.Settings.Tests.ps1) | 33 |
| [Rules.Projects.Tests.ps1](../tests/Rules.Projects.Tests.ps1) | 22 |
| [Rules.Repos.Branches.Tests.ps1](../tests/Rules.Repos.Branches.Tests.ps1) | 20 |
| [Rules.Repos.Tests.ps1](../tests/Rules.Repos.Tests.ps1) | 77 |
| [Rules.RetentionSettings.Tests.ps1](../tests/Rules.RetentionSettings.Tests.ps1) | 6 |
| [Rules.ServiceConnections.Tests.ps1](../tests/Rules.ServiceConnections.Tests.ps1) | 38 |
| [Rules.Tasks.VariableGroups.Tests.ps1](../tests/Rules.Tasks.VariableGroups.Tests.ps1) | 22 |

## Rules requiring coverage review

- `Azure.DevOps.Organization.GeneralBillingSettings.SubscriptionActive`
- `Azure.DevOps.Organization.GeneralBillingSettings.EnterpriseBillingConfigured`
- `Azure.DevOps.Organization.GeneralBillingSettings.AssignmentBillingEnabled`
- `Azure.DevOps.Organization.GeneralOverview.DescriptionSet`
- `Azure.DevOps.Organization.GeneralOverview.TimeZoneSet`
- `Azure.DevOps.Organization.GeneralOverview.GeographySet`
- `Azure.DevOps.Organization.GeneralOverview.OwnerSet`
- `Azure.DevOps.Organization.Pipelines.Settings.DisableStageChooser`
- `Azure.DevOps.Organization.Pipelines.Settings.DisableInBoxTasksVar`
- `Azure.DevOps.Organization.Pipelines.Settings.DisableMarketplaceTasksVar`
- `Azure.DevOps.Organization.Pipelines.Settings.DisableNode6TasksVar`
- `Azure.DevOps.Organization.Pipelines.Settings.LimitJobAuthScopeForForks`
- `Azure.DevOps.Organization.Pipelines.Settings.DisableSecretsFromForks`
- `Azure.DevOps.Organization.Pipelines.Settings.DisableImpliedYAMLCiTrigger`
- `Azure.DevOps.Organization.Pipelines.Settings.EnableAuditSettableVar`
- `Azure.DevOps.Organization.Pipelines.Settings.EnableTaskLockdown`
- `Azure.DevOps.Organization.Pipelines.Settings.RestrictPipelinePoliciesPermission`
- `Azure.DevOps.Organization.Pipelines.Settings.RequireCommentsForPullRequest`
- `Azure.DevOps.Organization.Pipelines.Settings.RequireCommentsForNonTeamMembers`
- `Azure.DevOps.Organization.Pipelines.Settings.RequireCommentsForNonTeamAndNonContributors`
- `Azure.DevOps.Organization.Pipelines.Settings.EnableShellTasksArgsSanitizingAudit`
- `Azure.DevOps.Organization.Security.Policies.Debug`
- `Azure.DevOps.Organization.Security.Policies.DisallowSecureShell`
- `Azure.DevOps.Organization.Security.Policies.DisallowRequestAccessToken`
- `Azure.DevOps.Organization.Security.Policies.DisallowTeamAdminsInvitations`
- `Azure.DevOps.Organization.Security.Policies.DisallowFeedbackCollection`
- `Azure.DevOps.Organization.Security.Policies.EnforceAADConditionalAccess`
- `Azure.DevOps.Organization.Security.Policies.DisallowOAuthAuthentication`
- `Azure.DevOps.Organization.Security.Policies.EnableLogAuditEvents`
- `Azure.DevOps.Organization.Security.Policies.EnableArtifactsProtection`
- `Azure.DevOps.Organization.Security.Policies.DisallowAnonymousAccess`
- `Azure.DevOps.Organization.Security.Policies.DisallowAadGuestUserAccess`
- `Azure.DevOps.Pipelines.PipelineYaml.AgentPoolVersionNotLatest`
- `Azure.DevOps.Pipelines.PipelineYaml.StepDisplayName`
- `Azure.DevOps.ServiceConnections.ProductionCheckProtection`
- `Azure.DevOps.ServiceConnections.ProductionHumanApproval`
