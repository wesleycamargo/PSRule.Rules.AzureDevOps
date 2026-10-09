# Assessment tool improvement backlog

Review date: 2026-10-09. Status: ADO-001 and ADO-011 are **Completed**, ADO-010 is **In progress**; other items are **Proposed**.

This backlog records improvements from a source review of the assessment tool.
It covers assessment reliability, rule correctness, authentication, API collection,
testing, CI, reporting, and documentation. The initial source review did not run tests. A follow-up
[test state report](test-state-report.md) records executed checks and confirmed
corrections. Confirmed observations and investigation needs are identified below.

The user approved the [phased test repair plan](test-repair-phases.md). Its local
first phase of local test corrections is complete; unrelated assessment improvements remain
proposed. Priorities are
provisional engineering judgments: P0 protects assessment trust, P1 improves
correctness and reliability, and P2 improves reproducibility and usability.

## Priorities and dependencies

| ID | Priority | Improvement | Dependencies | Status |
| --- | --- | --- | --- | --- |
| ADO-001 | P0 | Make assessment completeness explicit | None | Completed |
| ADO-002 | P1 | Establish deterministic assessment tests | None | Proposed |
| ADO-003 | P1 | Correct production rule applicability | ADO-002 | Proposed |
| ADO-004 | P1 | Improve secret detection precision | ADO-002 | Proposed |
| ADO-005 | P1 | Verify API collection completeness and resilience | ADO-001, ADO-002 | Proposed |
| ADO-006 | P1 | Harden authentication and permission guidance | ADO-001, ADO-002 | Proposed |
| ADO-007 | P1 | Detect undocumented API response changes | ADO-001, ADO-002 | Proposed |
| ADO-008 | P1 | Make CI validation reproducible | ADO-002 | Proposed |
| ADO-009 | P2 | Improve assessment reporting and onboarding | ADO-001, ADO-003, ADO-006, ADO-007 | Proposed |
| ADO-010 | P1 | Repair test setup and command contract drift | None | In progress |
| ADO-011 | P1 | Repair catalog and property assertions | None | Completed |
| ADO-012 | P1 | Strengthen rule outcome and boundary coverage | ADO-002 | Proposed |

### Code review follow-ups — 2026-10-08

A review of the working tree found eight issues. Three came from the test repair and
were fixed (explicit `-OrganizationId` in `Export-AzDevOpsRuleData`, bare tokens in all
organization readers, and HTML detection for raw pipeline YAML, covered by
`tests/PipelineYaml.Unit.Tests.ps1`). The others predate it and are mapped here:

| Finding | Item |
| --- | --- |
| `$failedExports` starts as `$null`, so multiple failures concatenate into one name | ADO-001 (already recorded) |
| Organization exports use the raw token and skip expired-token refresh | ADO-006 |
| A failed `Connect-AzDevOps` replaces the previous connection | ADO-006 |
| `OrganizationId` is assigned twice for bearer connections | ADO-006 |
| Repeated per-call sign-in page checks instead of a shared REST helper | ADO-005 |

## ADO-001 — Make assessment completeness explicit

**Priority:** P0. **Status:** Completed. **Dependencies:** None.

**Completed 2026-10-09:** Implemented on `fix/ado-001-assessment-completeness` with
separate `-CompletenessReportPath` output and
opt-in `-Strict` behavior for project and organization exports in an isolated
worktree. Collector status distinguishes completed, empty, partial, unavailable,
and failed collection; permission omissions and missing required data count as
incomplete. Strict exports attempt all collectors/projects and write their report
before throwing. See [assessment completeness](assessment-completeness.md).
Validation: all 61 offline Unit tests pass, including 36 completeness scenarios;
669 live tests were excluded. Pester command coverage across functions, classes,
and `.psm1` is 60.28%; the completeness helpers have 98.72% coverage and the project
export implementation has 97.20%. PowerShell parsing and `git diff --check` pass.
Standards and requirements reviews have no remaining blockers. Aggregate failure
diagnostics use safe messages; missing enrichment remains partial coverage while
legitimate empty collections, false/zero values, and nullable settings are preserved.

**Problem and evidence:** Confirmed: the [export orchestrator](../src/PSRule.Rules.AzureDevOps/PSRule.Rules.AzureDevOps.psm1)
catches collector errors and continues. Its failure accumulator starts as `$null`
and appends command names without explicitly creating a collection. Exported data
alone does not provide a machine-readable account of collection completeness.

**Intended outcome:** Consumers can distinguish complete, partial, and unavailable
coverage before interpreting assessment findings.

**Planned changes:**

- Track each collector's success, failure, or unavailable coverage separately.
- Provide machine-readable collection status without mixing status records into
  assessment targets or exposing credentials.
- Add an opt-in strict mode that attempts all collectors, then terminates with an
  error if required collection is incomplete.
- Distinguish legitimately empty collections from failed retrieval.
- Document a pipeline example that checks completeness before interpreting rules.

**Acceptance criteria:** Successful collectors remain usable after other collectors
fail. Every attempted collector has an accurate status, including multiple failed
command names. Strict mode fails for incomplete required collection. Existing
assessment target output remains unchanged by default.

**Validation:** Mock complete, empty, single-failure, and multiple-failure exports;
check default and strict behavior, target output, and absence of credentials in
collection diagnostics.

## ADO-002 — Establish deterministic assessment tests

**Priority:** P1. **Status:** Proposed. **Dependencies:** None.

**Problem and evidence:** Confirmed: [connection tests](../tests/Common.Tests.ps1)
use live Azure DevOps, and [rule tests](../tests/Rules.ServiceConnections.Tests.ps1)
depend on exported data under `tests/out*`. These dependencies limit reproducible
validation without credentials and prepared exports. The follow-up
[test review](test-state-report.md) found no Mock commands or Describe tags, and all
13 rule-test containers failed when shared export setup was unavailable.

**Intended outcome:** Contributors can validate assessment behavior from a clean
checkout without access to an Azure DevOps organization.

**Planned changes:**

- Add synthetic fixtures and mocked collectors for offline tests.
- Prepare each test file's required fixtures independently of other files and their
  execution order; make missing live prerequisites explicit.
- Support optional Azure CLI bearer authentication for generic live read checks,
  while keeping PAT, service principal, and managed identity scenarios distinct. The
  [test review](test-state-report.md) verified this path with ten passing live
  collector smoke checks against the supplied project.
- Separate offline and live integration tests with explicit Pester tags and CI
  selection; retain live tests for API and permission compatibility.
- Cover passing, failing, missing-field, and inapplicable cases for rules changed
  by this backlog.

**Acceptance criteria:** The offline suite passes without `ADO_*` environment
variables or pre-existing exports and makes no live API calls. Fixtures contain
no credentials or organization data. Live integration tests remain selectable.

**Validation:** Run the offline selection from a clean checkout with Azure
credentials unset; verify fixture setup and explicit integration-test selection.

## ADO-003 — Correct production rule applicability

**Priority:** P1. **Status:** Proposed. **Dependencies:** ADO-002.

**Problem and evidence:** Confirmed: several [service connection rules](../src/PSRule.Rules.AzureDevOps/rules/AzureDevOps.ServiceConnection.Rule.ps1)
describe production requirements without a production filter. The existing
[IsProduction selector](../src/PSRule.Rules.AzureDevOps/rules/Selectors.Rule.yaml)
uses name matching. Applicability across environments and releases needs review.

**Intended outcome:** Production-only findings apply consistently to resources
identified as production; general checks still apply to development resources.

**Planned changes:**

- Apply the existing `IsProduction` selector consistently to rules explicitly
  limited to production, including service connections, environments, and releases.
- Keep generally applicable rules active for development resources.
- Document naming assumptions and suppression examples.
- Update corresponding English and Dutch help when rule behavior changes.

**Acceptance criteria:** Production targets receive intended checks; development
targets skip production-only checks; general checks still execute. Intentional
changes to reported findings are documented.

**Validation:** Evaluate synthetic production and development targets, including
names that expose the selector's substring-matching limitations; verify rule
outcomes, skips, and help consistency.

## ADO-004 — Improve secret detection precision

**Priority:** P1. **Status:** Proposed. **Dependencies:** ADO-002.

**Problem and evidence:** Confirmed: [variable group secret rules](../src/PSRule.Rules.AzureDevOps/rules/AzureDevOps.Tasks.VariableGroups.Rule.ps1)
use regex patterns, including broad fixed-length matches. Similar checks exist in
[pipeline rules](../src/PSRule.Rules.AzureDevOps/rules/AzureDevOps.Pipelines.Core.Rule.ps1)
and [release rules](../src/PSRule.Rules.AzureDevOps/rules/AzureDevOps.Pipelines.Releases.Rule.ps1).
Actual false positives, false negatives, and duplicated patterns need investigation.

**Intended outcome:** Secret findings have better precision and documented limits,
without disclosing matched values.

**Planned changes:**

- Inventory duplicated patterns across variable groups, pipelines, and releases.
- Verify supported formats against primary vendor documentation during implementation.
- Replace demonstrably inaccurate patterns and document heuristic limitations.
- Ensure failure messages and recommendations do not reproduce matched secret values.
- Limit detection to exported configuration values.

**Acceptance criteria:** Every changed pattern has synthetic positive and negative
examples. Ordinary strings with matching lengths are covered. Null and multiline
values behave as documented. Rendered findings do not disclose synthetic secrets.

**Validation:** Run offline rule tests for changed patterns and inspect rendered
findings for disclosure. Record supporting format documentation with the change.

## ADO-005 — Verify API collection completeness and resilience

**Priority:** P1. **Status:** Proposed. **Dependencies:** ADO-001, ADO-002.

**Problem and evidence:** Confirmed: inspected list retrieval, including
[pipeline collection](../src/PSRule.Rules.AzureDevOps/Functions/DevOps.Pipelines.Core.ps1),
fetches a single response. An endpoint inventory is needed to establish where
pagination and retries are required; this observation does not prove every endpoint
currently truncates data.

**Intended outcome:** Supported multi-page collections are complete, and transient
read failures are handled predictably.

**Planned changes:**

- Record each collection endpoint, pagination mechanism, and API stability.
- Implement pagination where supported and required.
- Add bounded retries for read requests encountering throttling or transient server
  errors; honor `Retry-After`.
- Propagate exhausted retries and permission failures into collection status.
- Avoid retrying permanent authentication or authorization failures.
- Route REST calls through one shared helper that rejects HTML sign-in responses.
  More than 25 call sites repeat a hand-written `$response -is [string]` check, and a
  missed check silently passes a sign-in page on as data (code review, 2026-10-08).

**Acceptance criteria:** Required pages are collected with each object returned
once. Retry waits and attempts are bounded. Exhausted retries and 401/403 responses
produce accurate incomplete-collection status.

**Validation:** Mock multiple pages, empty final pages, throttling followed by
success, exhausted retries, and 401/403 responses. Mock waits to keep tests offline
and fast.

## ADO-006 — Harden authentication and permission guidance

**Priority:** P1. **Status:** Proposed. **Dependencies:** ADO-001, ADO-002.

**Problem and evidence:** Confirmed: the [orchestrator](../src/PSRule.Rules.AzureDevOps/PSRule.Rules.AzureDevOps.psm1)
captures a token for organization collectors, while other requests use refreshed
headers from the [connection class](../src/PSRule.Rules.AzureDevOps/Classes/AzureDevOpsConnection.ps1).
[Permission guidance](token-permissions.md) gives conflicting recommendations for
FullAccess and FineGrained tokens. Long-export refresh behavior needs validation.

**Intended outcome:** Long exports use valid authentication, and users can choose
verified permissions with explicit coverage limitations.

**Planned changes:**

- Route organization requests through refreshed connection headers while preserving
  directly callable functions. `Export-AzDevOpsRuleData` currently passes the raw
  `$script:connection.Token` to the organization exports, which run last, so an
  expired service principal or managed identity token fails only those exports.
- Keep the previous connection when `Connect-AzDevOps` fails verification; it
  currently replaces `$script:connection` before verifying, so a failed connect leaves
  the bad credentials in place.
- Set `OrganizationId` in one place; bearer connections currently set it in the
  constructor and again in `Connect-AzDevOps`.
- Test token refresh during longer exports and document caller-supplied bearer-token
  expiry behavior.
- Publish a collector-to-permission matrix with limitations for each token type.
- Align README and permission guidance around the least privileges verified to
  provide required coverage.

**Acceptance criteria:** Service principal and managed identity requests use
refreshed tokens when needed. Refresh failures and expired bearer tokens have clear
outcomes. Restricted permissions produce explicit coverage limitations. Credentials
are absent from diagnostics.

**Validation:** Mock expiry, refresh success and failure, expired bearer tokens,
PAT authentication, and restricted permissions. Verify the permission matrix with
selected live integration tests in the configured test organization.

## ADO-007 — Detect undocumented API response changes

**Priority:** P1. **Status:** Proposed. **Dependencies:** ADO-001, ADO-002.

**Problem and evidence:** Confirmed: the [organization security policy collector](../src/PSRule.Rules.AzureDevOps/Functions/DevOps.Organization.SecurityPolicies.ps1)
explicitly uses an undocumented endpoint and warns when expected policies are
missing. All organization collectors need an inventory of similar dependencies.

**Intended outcome:** Response changes produce explicit unavailable or incomplete
coverage rather than apparent successful assessment.

**Planned changes:**

- Identify all collectors using undocumented organization endpoints.
- Validate required response structures and fields.
- Report missing required data as incomplete coverage instead of treating it as a
  setting value.
- Document endpoint limitations and manual verification steps.

**Acceptance criteria:** Missing required providers or settings cannot silently
produce an apparently complete assessment. Valid responses continue to export.
Diagnostics identify the affected collector without exposing authentication data.

**Validation:** Test synthetic responses with valid data, missing providers,
missing policies, malformed JSON, and sign-in HTML; check collection status and
rule behavior when required data is unavailable.

## ADO-008 — Make CI validation reproducible

**Priority:** P1. **Status:** Proposed. **Dependencies:** ADO-002.

**Problem and evidence:** Confirmed: [module CI](../.github/workflows/module-ci.yml)
installs unpinned test dependencies, disables ScriptAnalyzer, and targets functions
and classes for code coverage. Rule behavior requires separate test evidence. The follow-up
[test review](test-state-report.md) reproduced a failed Pester test returning process
exit code 0 under the workflow defaults, and exit code 1 with `Run.Exit` enabled.
The [module manifest](../src/PSRule.Rules.AzureDevOps/PSRule.Rules.AzureDevOps.psd1)
claims PowerShell Core and Desktop support with a minimum version of 5.1.

**Intended outcome:** Ordinary pull requests receive reproducible validation
without Azure credentials, including evidence for supported runtimes and rules.

**Planned changes:**

- Pin tested dependency and action versions.
- Run offline tests on ordinary pull requests; separate credential-dependent
  integration tests.
- Set `Run.Exit = $true` (or an explicit equivalent failure check) so failed tests
  produce a failing job; run test-result and coverage uploads even when tests fail.
- Restore ScriptAnalyzer with repository settings and narrowly justified exclusions.
- Publish rule test coverage separately from function/class code coverage.
- Exercise the PowerShell editions claimed by the manifest.

**Acceptance criteria:** A deliberate test failure fails CI; offline jobs require
no Azure credentials; supported runtime jobs import and test the module. Analyzer
results and both forms of coverage are visible.

**Validation:** Run the workflow's offline commands locally, verify failure exit
behavior, and validate the supported runtime matrix and artifact publication in CI.

## ADO-009 — Improve assessment reporting and onboarding

**Priority:** P2. **Status:** Proposed. **Dependencies:** ADO-001, ADO-003, ADO-006, ADO-007.

**Problem and evidence:** Confirmed: the [README quick start](../README.md) does not
supply all currently mandatory parameters of `Export-AzDevOpsRuleData` in the
[orchestrator](../src/PSRule.Rules.AzureDevOps/PSRule.Rules.AzureDevOps.psm1).
The [monitor workflow](../.github/workflows/psrule-monitor.yml) evaluates exports
without an explicit machine-readable completeness gate. Existing
[suppression guidance](branch-strategy-suppression.md) provides a starting point
for documenting assessment tailoring.

**Intended outcome:** Users can run a valid example and interpret findings together
with collection completeness and coverage limits.

**Planned changes:**

- Add a copyable quick-start example matching current mandatory parameters.
- Show collection completeness alongside findings grouped by severity.
- Explain skipped, unavailable, and failed checks.
- Document baseline customization, production naming, suppression, export
  sensitivity, and assessment limitations.
- Use existing PSRule output formats and examples; defer a new dashboard.

**Acceptance criteria:** Quick-start examples bind correctly and execute against
mocked collectors. Complete, partial, and restricted-permission assessments are
clearly distinguishable. Examples and reports expose no credentials or secrets.

**Validation:** Check parameter binding and mocked execution; review sample reports
for each completeness state and permission mode; verify documentation links.

## ADO-010 — Repair test setup and command contract drift

**Priority:** P1. **Status:** In progress. **Dependencies:** None.

**Progress 2026-10-08:** Live Integration tests now run against seeded data in
`PSRule.Rules.AzureDevOps.Tests` (645 of 678 passing before the authentication split),
after contract fixes to `Export-AzDevOpsRuleData`, `Connect-AzDevOps`,
`Read-AdoOrganizationPipelinesSettings`, and `Get-AzDevOpsPipelineYaml`. Live
authentication tests are a separate `Authentication` set. See
[test-repair-phases.md](test-repair-phases.md) for remaining external blockers.

**Progress:** Module-relative test paths, module import/private scope, selected
disconnected tests, and pipeline YAML parameter corrections are implemented.
`Connect-AzDevOps` now dispatches PAT, service principal, managed identity, and
bearer constructors correctly and supports the existing token profiles. Mocked
tests cover every mode and failed service-principal token acquisition. A default
Unit runner now exits nonzero for failures. Legacy live-export tests still need
synthetic fixtures and remain tagged Integration.

**Problem and evidence at baseline:** The [test state report](test-state-report.md) confirms
`Common.Tests.ps1` fails because it dot-sources a file invoking `Export-ModuleMember`
outside a module. Tests contain 17 unsupported named-parameter uses: six `AuthType`,
nine `TokenType`, and two pipeline YAML `ProjectId` uses. Connection calls omit
mandatory `OrganizationId`; aggregate rule-data exports omit mandatory organization
parameters. Supplying credentials alone cannot resolve these defects.

**Intended outcome:** Test setup uses the module correctly, and calls exercise the
intended supported command contract rather than failing during parameter binding.

**Planned changes:**

- Import the module in common tests; use Pester module scope to inspect private
  connection state instead of dot-sourcing module-only code.
- Reconcile connection/export tests with the documented API while preserving
  intended authentication and token-permission coverage; do not delete scenarios
  merely to obtain a passing suite.
- Supply required organization identifiers in shared integration setup.
- Correct pipeline YAML calls to use supported project parameters.
- Make negative tests identify the intended error and verify they reach the API
  boundary so unrelated binding failures cannot satisfy a generic `Should -Throw`.

**Acceptance criteria:** Common test setup completes independently. All test calls
bind to the intended parameter set. Authentication-mode scenarios remain covered.
Wrong-credential and wrong-project tests cannot pass solely on parameter-binding
errors. Generic CLI bearer checks run separately from auth-mode-specific tests.

**Validation:** Run common setup and contract checks offline with mocked API calls;
verify module-scope connection inspection, each intended parameter set, and API-call
assertions for negative tests. Run selected live tests after test targets and
required authentication modes are configured.

## ADO-011 — Repair catalog and property assertions

**Priority:** P1. **Status:** Completed. **Dependencies:** None.

**Completed:** Catalog checks now run offline with maintained counts of
119 total and 24 organization pipeline settings rules. The retained Debug rule
has English help, and property checks use supported Pester assertions. The unit
selection passes, and temporary probes confirm missing properties are rejected. Full
fixture independence and broader catalog/baseline review remain follow-up work.

**Problem and evidence at baseline:** The [test state report](test-state-report.md) reproduces
catalog assertions expecting 77 total rules and 10 organization pipeline rules
against actual counts of 119 and 24. English help is missing for the GA-tagged
organization security Debug rule. Organization pipeline tests use `Should
-HaveProperty`, which is unregistered in Pester 5.7.1 and fails parameter resolution.

**Intended outcome:** Catalog checks detect intentional changes accurately, and
property validation uses assertions supported by the pinned Pester version.

**Planned changes:**

- Replace stale numeric expectations with a maintained expected rule inventory.
- Review the Debug rule's GA inclusion; ensure every rule in the assessed catalog
  has matching English help and intended baseline membership.
- Replace `HaveProperty` with supported assertions on each required property.
- Keep catalog/help/property tests independent of Azure credentials and exports.

**Acceptance criteria:** Catalog tests pass against the intended inventory and fail
for unexpected additions or removals. Required help files resolve. Removing a
required property makes its assertion fail. These checks execute offline.

**Validation:** Re-run the four independently reproduced expectations using the
corrected catalog and assertions; test missing properties and inventory drift with
synthetic inputs. Verify baseline membership and help for any retained debug rule.

## ADO-012 — Strengthen rule outcome and boundary coverage

**Priority:** P1. **Status:** Proposed. **Dependencies:** ADO-002.

**Problem and evidence:** The [test state report](test-state-report.md) identifies
36 discovered rules without literal full-name test references, 320 first-result
outcome assertions, and pass-only tests for retention and group member thresholds.
Literal references are a coverage diagnostic, not proof of execution coverage.
Several tests count multiple hits but assert only the first result's outcome.

**Intended outcome:** Tests detect mixed outcomes, missing results, and boundary
errors for all assessment rules.

**Planned changes:**

- Review the listed rules for semantic coverage and add missing passing/failing
  cases, including production approval/check rules and pipeline YAML rules.
- Assert result cardinality before indexing and validate every matched outcome.
- Add below/at/above threshold cases for retention and group membership rules.
- Cover missing fields and inapplicable targets with explicit expected behavior.

**Acceptance criteria:** Every assessed rule has passing and failing coverage, or a
recorded justification when one outcome is impossible by design. A wrong outcome
in any matched result fails its test. Threshold boundaries and missing results are
caught by deterministic tests.

**Validation:** Run offline synthetic rule cases and deliberately vary non-first
results and boundary inputs to prove the assertions detect errors. Publish a rule
coverage inventory separately from function/class code coverage under ADO-008.

## Delivery order and completion

ADO-001 and ADO-011 are complete. Continue ADO-002 and remaining test setup/contracts
(ADO-010), and prioritize ADO-008's confirmed CI failure propagation gap.
Then address rule correctness, rule coverage, and collection reliability.
Complete CI and user guidance after their dependencies. Implement each item in a
focused change with the relevant tests and any required localized help updates.

Keep this file current as work progresses. Move an item from Proposed to In progress
only when implementation begins, and to Done only when its acceptance criteria
and validation are satisfied. Record the implementation reference and validation
result when completing an item.

For this backlog's publication, verify that every item has the required fields,
dependencies refer to valid IDs, evidence links resolve, and the README link works.
No live scans or implementation tests are required for this documentation change.
