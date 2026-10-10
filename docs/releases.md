# GitHub module releases

Download the module ZIP and its `.sha256` file from
[GitHub Releases](https://github.com/wesleycamargo/PSRule.Rules.AzureDevOps/releases).
The ZIP contains only the module, rule help, and license under
`PSRule.Rules.AzureDevOps/<version>/`.

For version 0.5.12, run these commands from the download directory in PowerShell 7:

```powershell
$archive = './PSRule.Rules.AzureDevOps.0.5.12.zip'
$expectedHash = (Get-Content "$archive.sha256").Split(' ')[0]
if ((Get-FileHash $archive -Algorithm SHA256).Hash -ne $expectedHash) {
    throw 'Module archive checksum does not match.'
}
Install-Module PSRule -RequiredVersion 2.9.0 -Scope CurrentUser
$moduleDirectory = ($env:PSModulePath -split [IO.Path]::PathSeparator)[0]
New-Item -Path $moduleDirectory -ItemType Directory -Force | Out-Null
Expand-Archive -Path $archive -DestinationPath $moduleDirectory -Force
Import-Module PSRule.Rules.AzureDevOps -RequiredVersion 0.5.12 -Force
```

To build the same package from a checkout, run `./scripts/Build-Module.ps1`.
The ZIP and SHA-256 file are written to `.local/releases/` by default. Verify the
archive by extracting it and importing its manifest before uploading both files to
a release whose tag matches the manifest version.

GitHub releases do not automatically publish to PowerShell Gallery. The existing
Gallery workflow is available only through its separate manual trigger.
