# Phased test repair plan

Approved scope: repair existing tests, make local validation reproducible, and
configure the existing Azure DevOps projects for synthetic integration scenarios.
GitHub remains the source of code. Other assessment improvements remain proposed
in the [assessment backlog](assessment-backlog.md).

Complete each phase's acceptance checks before starting the next. Update this plan,
the backlog, and the [test state report](test-state-report.md) with actual results.
Preserve pre-existing workspace edits and keep credentials and live exports out of
commits.

## Phase 1 — Easy local corrections

**Status:** Completed. **Dependencies:** None.
**Backlog:** ADO-010 and ADO-011; partial foundation for ADO-002.

- Resolve module paths relative to the test directory.
- Import the common module and inspect private state/functions through module scope.
- Separate catalog checks from live export setup; maintain expected counts of
  119 total rules and 24 organization pipeline settings rules.
- Add missing English help for the informational Debug policy rule.
- Replace the unsupported property assertion and correct pipeline YAML parameters.
- Give selected disconnected tests synthetic arguments and `Unit` tags.

**Acceptance:** All test files parse and discover. The selected offline tests pass
without `ADO_*`, `GITHUB_WORKSPACE`, existing exports, or live requests. Verify
required-property assertions with synthetic complete and missing-field input.
No production authentication or Azure resource changes belong to this phase.

## Phase 2 — Authentication corrections

**Status:** Completed. **Dependencies:** Phase 1. **Backlog:** ADO-010 and ADO-006.

- Repair constructor dispatch for PAT, service principal, managed identity, and
  bearer authentication; preserve organization identity for every mode.
- Restore supported token-permission selection and align test arguments with the
  intended command contract. Use the existing managed identity switch.
- Add mocked regression coverage for each mode, expiry, and incorrect credentials.
  Check that negative tests reach the intended authentication boundary.

**Acceptance:** Authentication tests pass offline for all four modes without
credential disclosure. The public bearer path continues to work.

**Result:** `Connect-AzDevOps` now dispatches each authentication mode to the
matching constructor, retains an optional organization identifier for every mode,
and supports the existing `FullAccess`, `ReadOnly`, and `FineGrained` profiles.
Five mocked tests cover PAT, service principal, managed identity, bearer, and an
invalid service-principal secret without making live requests.

## Phase 3 — Deterministic suite and test runner

**Status:** In progress. **Dependencies:** Phase 2.
**Backlog:** ADO-002, ADO-008, ADO-011, and ADO-012.

- Prepare synthetic rule fixtures independently in temporary test directories,
  including the three permission profiles; remove inter-file export dependencies.
- Verify every matched rule outcome and retain passing and failing scenarios.
- Correct standalone organization collector expectations: an explicitly supplied
  token does not require module connection state.
- Separate offline `Unit` and live `Integration` tests; pin tool versions and make
  the default local runner select `Unit` and return a nonzero exit code on failure.

**Acceptance:** The complete unit suite passes from a clean checkout without
credentials, pre-existing exports, or live requests. A deliberate failure fails
the runner. Integration tests remain explicitly selectable.

**Progress:** Existing live suites are explicitly tagged `Integration`.
`tests/Run-Tests.ps1` selects `Unit` by default, requires Pester 5.7.1, writes
NUnit XML, and exits nonzero for failures. The current Unit selection has synthetic
project and variable-group fixtures, including independent temporary directories
for FullAccess, ReadOnly, and FineGrained project profiles. It also mocks the
standalone organization pipeline settings collector and verifies that an explicit
token does not require module connection state. Remaining legacy rule suites still
consume live exports. On 2026-10-06 the user chose to keep them as live Integration
tests instead of converting them to synthetic fixtures (see Phase 4).

## Phase 4 — Synthetic Azure DevOps fixture project

**Status:** Superseded on 2026-10-06. **Dependencies:** Phase 3. **Backlog:** ADO-002 and ADO-010.

**Direction change 2026-10-06:** The user chose to keep the legacy Integration tests
as written and make them pass, instead of seeding `psrule-fixture-*` resources.
`tests/Initialize-IntegrationTestData.ps1` idempotently creates the resources under
the names the tests already use (`repository-success`, `psrule-fail-project`,
`production-success`/`production-fail`, `azurerm-success`, `variable-group-success`,
`failing-variable-group`, and so on), using dummy values and the Azure CLI login.
Test edits were limited to replacing old-organization IDs and positional lookups
with name lookups, and moving invalid-credential `Connect-AzDevOps` calls inside
`Should -Throw`. Code fixes: optional `-Organization`/`-OrganizationId` on
`Export-AzDevOpsRuleData`, optional `-OrganizationId` for bearer connections, bare
tokens accepted by `Read-AdoOrganizationPipelinesSettings`, sign-in page detection
in `Get-AzDevOpsPipelineYaml`, the standard "not connected" message in
`Export-AdoOrganizationPipelinesSettings`, and the PublicProject baseline excluding the
organization badge rule. `CHANGELOG.md` lists the same fixes. Two further test edits:
the PassThru pipeline assertions use the last item, because YAML pipelines emit their
YAML first, and the Retention wrong-organization tests expect the connection error.

**Result 2026-10-06:** With the Azure CLI token in all `ADO_PAT*` and
`ADO_ACCESS_TOKEN` variables, the Integration selection went from 177 passed / 501
failed to 645 passed / 33 failed. The Unit selection still passes 23 tests. All
remaining failures need access outside this identity: the `empty-project` project
(project creation is denied), service principal credentials (`ADO_CLIENT_ID`,
`ADO_CLIENT_SECRET`, `ADO_TENANT_ID`), managed identity (Azure-hosted agents only),
and three organization pipeline settings that the rules expect enabled: disable
classic build pipeline creation, disable classic release pipeline creation, and
limit pull requests from forks. Disable classic creation only after the classic
pipeline and release definitions exist.

**Azure DevOps changes made 2026-10-06** in `PSRule.Rules.AzureDevOps.Tests`, beyond
the resources the script creates:

- The Azure CLI identity's access level was raised from Stakeholder to Basic by an
  organization administrator; Stakeholders cannot use Azure Repos in private projects.
- Project pipeline settings: builds from forks enabled, comments required for fork pull
  requests, and secrets blocked for fork builds (the fork options are only stored
  while fork builds are enabled). The project has no GitHub-backed pipelines.
- The project-level repository ACL gained a merged Project Valid Users entry
  (Read and Contribute) so `Project.MainRepositoryAcl.ProjectValidUsers` fails as tested.
- Success resources (repository, pipeline, environment, variable group, service
  connection, release definition) do not inherit permissions and grant Project
  Administrators explicitly. Fail resources inherit and grant Project Valid Users directly.
- The first run gave Project Administrators only View and Manage (`3`) on the
  `production-success` environment, which removed the identity's ability to administer
  its permissions. The ACL is otherwise correct for the tests; a Project Collection
  Administrator can restore Administer. The script now uses `63` for new environments.
- A probe service connection used to test workload identity creation was deleted.
- The project's empty default repository `PSRule.Rules.AzureDevOps.Tests` already existed;
  it was hidden from the Stakeholder identity and was left unchanged.

Creating an `azurerm` connection with a resource-group `scope` fails with a misleading
"Creator" permission error because it requests a role assignment, so the script adds the
scope with an update after creation. The classic pipeline definition needs
`jobAuthorizationScope` on both the definition and its phase.

**Authentication split 2026-10-08:** The live `Connect-AzDevOps` contexts moved from
`tests/Common.Tests.ps1` to `tests/Authentication.Tests.ps1` with the
`Authentication` tag (25 tests), selected by `Run-Tests.ps1 -TestType Authentication`.
Integration now selects 653 tests, and its remaining failures no longer include
service principal or managed identity credentials. `Run-Tests.ps1` fills missing
`ADO_*` variables from the Azure CLI login for both live test types.

**Blocker observed 2026-10-06:** The authenticated Azure CLI identity can read
`PSRule.Rules.AzureDevOps.Tests` but Azure DevOps rejected repository creation with
`TF401027` because it lacks `Git: CreateRepository` at project scope. Grant that
identity the permission in the fixture project (or project-administrator rights
limited to this project) before fixture seeding can proceed.

**Recheck 2026-10-06:** A permission evaluation for `CreateRepository` (bit 256,
token `repoV2/<fixture project id>`) still returns `false`, and the project is
still empty. Reading the repository ACL is denied on behalf of the "Hosted
Stakeholder License Security Subject", so the identity has the Stakeholder access
level. Stakeholders cannot use Azure Repos in private projects, so project-scoped
Git permission grants have no effect. An organization user administrator must change
the identity's access level to Basic before fixture seeding can proceed.

Reuse `https://dev.azure.com/ai-experiments/PSRule.Rules.AzureDevOps.Tests`.

- Seed stable `psrule-fixture` resource names and resolve resource identifiers by
  name. Setup must be repeatable and retain unrelated project resources.
- Create populated protected/unprotected repositories and an empty repository;
  repository contents are dummy scenario data, never a source-code mirror.
- Prepare YAML preview and required-parameter fallback pipelines with CI and PR
  triggers disabled, environments with/without checks, inert generic service
  connections, and variable groups with plain and fake secret-like values.
- Mock unavailable paid features, classic pipeline creation, and organization
  settings scenarios. Leave organization settings unchanged.

**Acceptance:** Repeated setup creates no duplicates, and live tests exercise the
intended empty, populated, protected, and unprotected scenarios without running
fixture pipelines or using real secret values as fixture data.

## Phase 5 — GitHub-backed Azure test pipeline

**Status:** Pending. **Dependencies:** Phase 4. **Backlog:** ADO-008 and ADO-010.

Use the control project
`https://dev.azure.com/ai-experiments/PSRule.Rules.AzureDevOps`.

- Add separate test pipeline YAML to the GitHub repository
  `wesleycamargo/PSRule.Rules.AzureDevOps` and register it using the existing
  `github.com_wesleycamargo` connection. Do not push source code to Azure Repos or
  repurpose the publishing pipeline.
- Start with manual triggers and `ubuntu-latest`. Run unit tests before integration
  tests against the fixture project; publish NUnit results even when tests fail.
- Authorize `ai-credentials` and the GitHub connection only for the test pipeline.
  Map `Application (client) ID` to `ADO_CLIENT_ID`, `Directory (tenant) ID` to
  `ADO_TENANT_ID`, and `secret` to `ADO_CLIENT_SECRET` explicitly in the integration
  task environment. Require service principal authentication without fallback.
- Enroll the service principal in Azure DevOps with the access needed for the
  fixture project. Project administrator rights, if required for fixture setup,
  are limited to that project; collection administrator rights are unnecessary.
- Keep ordinary GitHub unit CI independent of legacy Azure credentials.

**Acceptance:** Manual runs check out GitHub, pass unit and service-principal
integration stages, publish results on failures, and return accurate job status.
Verify repository access and hosted-agent capacity before the first run; an
existing service connection or queue alone does not prove these prerequisites.

## Validation record and handover

Phase 1 completed on 2026-10-06 with Pester 5.7.1 and PSRule 2.9.0:
24 test files parsed without errors; 681 tests discovered without container errors;
12 selected unit tests passed with zero HTTP calls; two temporary probes verified
complete and missing-field property assertions. The other 669 tests were excluded,
not validated. The additional discovered test checks actual integration exports.

Phase 2 completed on 2026-10-06. Phase 3 is in progress: 27 test files parse and
692 tests discover; the current Unit selection has 23 passing tests and 669
excluded Integration tests. An isolated intentional Pester failure exited with
code 1 under the runner configuration. No Azure resources were changed or source
code pushed.

On 2026-10-08 a full Integration run started from an empty environment (no `ADO_*`
variables) let the runner fill everything from the Azure CLI login: 678 tests, 645
passed, 33 failed, all external blockers, and the process exit code was 43 (the failure
count). An earlier user run without `ADO_*` variables and without the bootstrap failed
307 tests with empty `Organization` and project parameters; the bootstrap prevents that.

Next: resolve the external blockers listed under Phase 4, then Phase 5. Converting rule
suites to synthetic fixtures is no longer planned; the live tests are kept as written.

Run the tests from the repository root:

```powershell
./tests/Run-Tests.ps1 -TestType Unit            # offline
./tests/Run-Tests.ps1 -TestType Integration     # needs az login and the seeded test data
./tests/Run-Tests.ps1 -TestType Authentication  # SP tests need ADO_CLIENT_ID/SECRET/TENANT_ID
./tests/Initialize-IntegrationTestData.ps1 -Organization ai-experiments -Project PSRule.Rules.AzureDevOps.Tests
```

Pester 5.7.1 and PSRule 2.9.0 are pinned in `tests/requirements.psd1`. The dev
container Dockerfile installs the same versions, but `docker-compose.yml` pulls the
prebuilt `ai-devbox-image`, so that only applies after the image is rebuilt and its tag
bumped. Until then, install them with `Install-Module` as shown in `AGENTS.md`.
`.vscode/launch.json` has one launch entry per test type.

## Microsoft Learn references

These setup choices were checked using the Microsoft Learn MCP search and fetch
services.

- [Build GitHub repositories](https://learn.microsoft.com/en-us/azure/devops/pipelines/repos/github?view=azure-devops)
- [Variable groups and pipeline authorization](https://learn.microsoft.com/en-us/azure/devops/pipelines/library/variable-groups?view=azure-devops)
- [Map secret variables into task environments](https://learn.microsoft.com/en-us/azure/devops/pipelines/process/set-secret-variables?view=azure-devops)
- [Service principal access to Azure DevOps](https://learn.microsoft.com/en-us/azure/devops/integrate/get-started/authentication/service-principal-managed-identity?view=azure-devops)
