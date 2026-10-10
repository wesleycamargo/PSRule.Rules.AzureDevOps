# Assessment test selections

Install the versions listed in `tests/requirements.psd1`, then run from the repository root:

```powershell
./tests/Run-Tests.ps1 -TestType Unit
```

The default `Unit` selection runs offline. It needs no `ADO_*` variables, Azure CLI login, or previously exported organization data. Ordinary module CI selects this same tag and supplies no Azure DevOps credentials.

`tests/fixtures/rules/` contains synthetic targets for 13 rule families. Each fixture records literal expected outcomes for a passing target, a failing target, a target missing required data, and an unrelated target type. `Rules.AssessmentFixtures.Tests.ps1` evaluates these through `Invoke-PSRule` and checks every result. API requests are blocked in these fixture tests. The fixtures are a testing foundation; comprehensive coverage of all 119 rules remains ADO-012.

Collector and completeness tests mock Azure DevOps calls or the public aggregate collector boundary. No real tokens or organization exports belong in offline fixtures.

## Live compatibility tests

```powershell
./tests/Run-Tests.ps1 -TestType Integration
./tests/Run-Tests.ps1 -TestType Authentication
```

These selections use a live organization. Integration expects the resources created by `tests/Initialize-IntegrationTestData.ps1`. Authentication tests remain separate because PAT, service principal, and managed identity require different prerequisites. The runner can obtain a bearer token from Azure CLI for generic live read checks. Supply distinct PAT values to verify actual differences in permissions; reusing one CLI identity does not establish a least-privilege matrix.

Each live rule-test file creates its own exports under Pester's `TestDrive` through `tests/helpers/LiveRuleTestData.ps1`. It collects only the target family used by that file for `FullAccess`, `ReadOnly`, and `FineGrained`; `Rules.Common.Tests.ps1` independently tests aggregate exports. Tests no longer depend on shared `tests/out*` directories or another file running first.

To select one live rule file directly, set `ADO_ORGANIZATION`, `ADO_PROJECT`, `ADO_PAT`, `ADO_PAT_READONLY`, and `ADO_PAT_FINEGRAINED`, then run:

```powershell
Invoke-Pester -Path ./tests/Rules.Groups.Tests.ps1 -Tag Integration
```

Missing live prerequisites produce an error naming the required variables before connecting. Live exports are temporary and are not committed.
