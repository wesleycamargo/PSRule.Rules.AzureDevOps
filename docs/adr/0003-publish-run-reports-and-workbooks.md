# ADR-003: Publish run reports and historical workbooks

## Status

Recorded from the companion dashboard implementation on 10 October 2026. Historical approval is unknown.

## Context

Operators need evidence for a specific pipeline run and a view across assessment runs.
Workbook ingestion can fail after rule evaluation succeeds.

## Decision

The manual dashboard pipeline generates SARIF, standalone HTML, and a Markdown summary before Azure ingestion.
It publishes available reports as a build artifact and attaches HTML when `PSRuleReportReady` is true.
It also sends detailed results to `PSRule_CL` through an Azure Monitor data collection rule.
Workbooks query that table. The assessment script checks ingestion counts before it reports success.

## Alternatives considered

Workbook-only output would make run evidence depend on ingestion and query access.
Artifact-only output would omit the existing historical query view.
A dedicated report server would add deployment and operation work.
These are analytical alternatives. The repository does not record a historical selection process.

## Consequences

Run evidence can survive a later ingestion failure.
The HTML Reports extension provides the pipeline report page. Artifact publication alone does not create that page.
Artifact retention and workspace retention remain separate controls.
The system maintains two presentation formats and their shared result contract.
Ingestion count checks detect duplicate records but do not make repeated publication idempotent.

## References

- [Repository and pipeline architecture](../architecture.md).
- [Dashboard architecture](../../../PSRule.Dashboards.AzureDevOps_/docs/architecture.md).
