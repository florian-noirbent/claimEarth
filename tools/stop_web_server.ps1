param(
    [Parameter(Mandatory = $true)]
    [int]$ProcessId
)

$ErrorActionPreference = "Stop"

$process = Get-Process -Id $ProcessId -ErrorAction SilentlyContinue
if ($null -ne $process) {
    Stop-Process -Id $ProcessId -Force
}
