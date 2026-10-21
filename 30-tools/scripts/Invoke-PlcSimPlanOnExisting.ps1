param(
    [string]$PlanPath,
    [string]$AdapterPath = "C:\Users\jose.mellid\Desktop\BIBLIOGRAFIA\00. IA-go\01.Repositorios\TIA Portal\TIA-Claude\30-tools\plcsim\bin\v7\tia-claude-plcsim-adapter.exe",
    [string]$InstanceName = "PLC_1",
    [string]$ResultPath = (Join-Path $env:LOCALAPPDATA 'Temp\opencode\plcsim\plan-existing-result.json'),
    [int]$TimeoutSeconds = 300
)

# Runs the acceptance plan against an ALREADY registered instance, attaching to it with
# CreateInterface. The instance is not registered, powered or unregisterded here: it belongs to
# whoever created it, and this process only lends it a fresh interface.
# That matters because a symbolic read resolves against the symbol table the instance loaded
# with the downloaded program; an interface created before the download reports the program as
# "not up to date" (-47).

$ErrorActionPreference = 'Stop'
$plan = Get-Content -Raw -LiteralPath $PlanPath | ConvertFrom-Json
$steps = @($plan.steps)

$psi = [Diagnostics.ProcessStartInfo]::new()
$psi.FileName = $AdapterPath
$psi.Arguments = "--plan-existing --name `"$InstanceName`""
$psi.UseShellExecute = $false
$psi.CreateNoWindow = $true
$psi.RedirectStandardInput = $true
$psi.RedirectStandardOutput = $true
$psi.RedirectStandardError = $true
$psi.StandardOutputEncoding = [Text.Encoding]::UTF8
$proc = [Diagnostics.Process]::Start($psi)

$ready = $proc.StandardOutput.ReadLineAsync()
if (-not $ready.Wait(60000)) { throw 'The adapter did not report readiness.' }
$readyText = $ready.Result
Write-Output "adapter: $readyText"

$results = @()
$failed = $null
for ($i = 0; $i -lt $steps.Count; $i++) {
    $step = $steps[$i]
    $proc.StandardInput.WriteLine([string]$step.command)
    $proc.StandardInput.Flush()
    $read = $proc.StandardOutput.ReadLineAsync()
    if (-not $read.Wait(60000)) { $failed = "timeout step $i ($($step.command))"; break }
    $text = $read.Result
    $response = $null
    try { $response = $text | ConvertFrom-Json } catch { $failed = "invalid json at step $i ($($step.command)): $text"; break }
    if ([string]$response.status -ne 'ok') { $failed = "status!=ok step $i ($($step.command)): $text"; break }
    foreach ($property in @($step.expect.PSObject.Properties)) {
        $actual = $response.PSObject.Properties[$property.Name]
        if ($null -eq $actual -or [string]$actual.Value -cne [string]$property.Value) {
            $failed = "expect mismatch at step $i ($($step.command)): $($property.Name) expected '$($property.Value)' got '$(if($actual){$actual.Value}else{'<ausente>'})'"
            break
        }
    }
    $results += [ordered]@{ index = $i; command = [string]$step.command; response = $response }
    if ($failed) { break }
    if ($step.delayMs) { Start-Sleep -Milliseconds ([int]$step.delayMs) }
}

try { $proc.StandardInput.WriteLine('stop'); $proc.StandardInput.Flush() } catch { }
try { $proc.WaitForExit(20000) | Out-Null } catch { }

[ordered]@{ ok = ($null -eq $failed); failed = $failed; steps = $results } |
    ConvertTo-Json -Depth 12 -Compress | Out-File -LiteralPath $ResultPath -Encoding UTF8
Write-Output "plan ok=$($null -eq $failed) steps=$($results.Count) failed=$failed"
