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
try {
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
        # Un paso sin 'expect' no tiene nada que comparar. Sin esta guarda, el
        # indexado con un nombre nulo revienta con 'el indice de la matriz esta
        # elevado a NULL'.
        $expectProperties = if ($null -eq $step.expect) { @() } else { @($step.expect.PSObject.Properties) }
        foreach ($property in $expectProperties) {
            # 'tolerance' es una instruccion para el comparador, no una propiedad de la respuesta.
            if ($property.Name -eq 'tolerance') { continue }
            $actual = $response.PSObject.Properties[$property.Name]
            if ($null -eq $actual -or [string]$actual.Value -cne [string]$property.Value) {
                # Los valores numericos se comparan con tolerancia: el adaptador serializa los
                # REAL con 6 digitos significativos, asi que la igualdad textual no es fiable.
                $expectedIsNumeric = $property.Value -is [double] -or $property.Value -is [int] -or $property.Value -is [long] -or $property.Value -is [decimal]
                $actualIsNumeric = $null -ne $actual -and ($actual.Value -is [double] -or $actual.Value -is [int] -or $actual.Value -is [long] -or $actual.Value -is [decimal])
                if (-not ($expectedIsNumeric -and $actualIsNumeric)) {
                    $failed = "expect mismatch at step $i ($($step.command)): $($property.Name) expected '$($property.Value)' got '$(if($actual){$actual.Value}else{'<ausente>'})'"
                    break
                }
                $tolerance = 0.0001
                $toleranceProperty = $step.expect.PSObject.Properties['tolerance']
                if ($toleranceProperty) { $tolerance = [double]$toleranceProperty.Value }
                $difference = [Math]::Abs([double]$actual.Value - [double]$property.Value)
                if ($difference -gt $tolerance) {
                    $failed = "expect mismatch at step $i ($($step.command)): $($property.Name) expected '$($property.Value)' +/- $tolerance got '$($actual.Value)' (diff $difference)"
                    break
                }
            }
        }
        $results += [ordered]@{ index = $i; command = [string]$step.command; response = $response }
        if ($failed) { break }
        if ($step.delayMs) { Start-Sleep -Milliseconds ([int]$step.delayMs) }
    }
}
catch {
    $failed = "exception: " + $_.Exception.Message
    Write-Output ("plan aborted: " + $failed)
}

try { $proc.StandardInput.WriteLine('stop'); $proc.StandardInput.Flush() } catch { }
try { $proc.WaitForExit(20000) | Out-Null } catch { }

[ordered]@{ ok = ($null -eq $failed); failed = $failed; steps = $results } |
    ConvertTo-Json -Depth 12 -Compress | Out-File -LiteralPath $ResultPath -Encoding UTF8
Write-Output "plan ok=$($null -eq $failed) steps=$($results.Count) failed=$failed"
