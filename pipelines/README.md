Azure DevOps pipelines
======================

`azure-pipelines.yml` publishes this PowerShell module to Azure Artifacts.
`psrule-assessment.yml` is a separate, organization-wide PSRule assessment
pipeline. It runs manually or every Sunday at 02:00 UTC on `main`.

## Configure the assessment pipeline

The deployed assessment pipeline is in the
[`PSRule.Rules.AzureDevOps` Azure DevOps project](https://dev.azure.com/ai-experiments/PSRule.Rules.AzureDevOps).
It uses the protected Library variable group `ai-credentials`.

1. Configure `ai-credentials` with these service-principal values:

   | Variable | Description |
   | --- | --- |
   | `Directory (tenant) ID` | Microsoft Entra tenant ID for the service principal. |
   | `Application (client) ID` | Microsoft Entra application (client) ID. |
   | `secret` | Service-principal client secret; mark this variable secret. |

2. Grant the service principal sufficient read access to the organization and
   each project that should be assessed.
3. Authorize the `PSRule Azure DevOps Assessment` pipeline to use the
   variable group. The pipeline sets `ADO_ORGANIZATION` to `ai-experiments`
   and `ADO_ORGANIZATION_ID` to `3b022c28-683d-4d7e-87a5-bd8198332011`.

The pipeline installs PSRule 2.9.0, imports the checked-out module, and exports
the organization data to a fresh agent temporary directory for each run.
It uses strict collection completeness checks before evaluating
`Baseline.Default`. The `psrule-results` artifact contains
`collection-status.json` and, when evaluation runs, `psrule-results.sarif`;
exported Azure DevOps data is not published. Report publication runs even
when collection fails.

Rule violations are reported in the SARIF artifact and the job log but do not
fail the pipeline. Incomplete collection fails the run after writing the
completeness report and prevents rule evaluation. Authentication, export,
and execution errors also fail the run. See
[assessment completeness](../docs/assessment-completeness.md) for report details.
Open the artifact with the Azure DevOps SARIF Viewer extension if installed.

The pipeline uses the project self-hosted `AI-Pool` rather than Microsoft-hosted
capacity. At least one Linux agent in that pool must be online for scheduled or
manual runs to start.

![Sarif Viewer](../assets/media/sarif-0.0.11.png)
