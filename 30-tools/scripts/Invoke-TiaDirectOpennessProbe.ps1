<#
.SYNOPSIS
    Ejecuta un probe independiente y de solo lectura de Siemens.Engineering/Openness V20.

.DESCRIPTION
    Compila y ejecuta la pequeña aplicación .NET Framework de 30-tools/openness.
    Solo inicializa el resolver Openness, comprueba la pertenencia al grupo y enumera
    procesos TIA mediante TiaPortal.GetProcesses(). No llama a Attach, OpenProject,
    new TiaPortal, SaveProject ni a ninguna operación mutante.

    El probe no sustituye la identificación gráfica de una ventana TIA cuando una tarea
    posterior vaya a adjuntarse a un proyecto. Sirve para demostrar que la capa directa
    Siemens.Engineering V20 está cargable desde una aplicación independiente del MCP.
#>
[CmdletBinding()]
param(
    [string]$OutputPath = (Join-Path (Join-Path $PSScriptRoot '..\..') ('70-runs\environment\direct-openness-{0}.json' -f (Get-Date -Format 'yyyyMMdd-HHmmss'))),
    [int]$TimeoutSeconds = 120
)

$ErrorActionPreference = 'Stop'
$workspaceRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$projectPath = (Resolve-Path (Join-Path $PSScriptRoot '..\openness\TiaClaude.DirectOpennessProbe.csproj')).Path
$projectDirectory = Split-Path -Parent $projectPath
$assemblyPath = 'C:\Program Files\Siemens\Automation\Portal V20\PublicAPI\V20\Siemens.Engineering.dll'

function Get-PortalSnapshot {
    @(
        Get-Process -Name 'Siemens.Automation.Portal' -ErrorAction SilentlyContinue |
            ForEach-Object {
                [ordered]@{
                    pid = [int]$_.Id
                    mainWindowHandle = [int64]$_.MainWindowHandle
                    mainWindowTitle = $_.MainWindowTitle
                    startTimeUtc = $_.StartTime.ToUniversalTime().ToString('O')
                    path = $_.Path
                }
            }
    )
}

function Invoke-CheckedProcess {
    param(
        [string]$FilePath,
        [string[]]$Arguments,
        [string]$WorkingDirectory,
        [int]$Timeout
    )

    $stdoutPath = Join-Path $env:TEMP ('tia-direct-openness-' + [Guid]::NewGuid().ToString('N') + '.stdout')
    $stderrPath = Join-Path $env:TEMP ('tia-direct-openness-' + [Guid]::NewGuid().ToString('N') + '.stderr')
    try {
        $process = Start-Process -FilePath $FilePath -ArgumentList $Arguments -WorkingDirectory $WorkingDirectory -WindowStyle Hidden -RedirectStandardOutput $stdoutPath -RedirectStandardError $stderrPath -PassThru
        if (-not $process.WaitForExit($Timeout * 1000)) {
            Stop-Process -Id $process.Id -Force -ErrorAction SilentlyContinue
            throw "Process timed out after $Timeout seconds: $FilePath"
        }

        [pscustomobject]@{
            exitCode = $process.ExitCode
            stdout = if (Test-Path $stdoutPath) { Get-Content -Raw $stdoutPath } else { '' }
            stderr = if (Test-Path $stderrPath) { Get-Content -Raw $stderrPath } else { '' }
        }
    }
    finally {
        Remove-Item $stdoutPath,$stderrPath -Force -ErrorAction SilentlyContinue
    }
}

$doctorPath = Join-Path $workspaceRoot '30-tools\mcp\tia-inspect\bin\v20\TiaMcpServer.exe'
$doctor = Invoke-CheckedProcess -FilePath $doctorPath -Arguments @('--tia-major-version','20','--doctor') -WorkingDirectory $workspaceRoot -Timeout $TimeoutSeconds
if ($doctor.exitCode -ne 0) {
    throw "Doctor failed before direct Openness probe: $($doctor.stderr)$($doctor.stdout)"
}

$build = Invoke-CheckedProcess -FilePath 'dotnet' -Arguments @('build',$projectPath,'--configuration','Release','--nologo','-v:q') -WorkingDirectory $workspaceRoot -Timeout $TimeoutSeconds
if ($build.exitCode -ne 0) {
    throw "Direct Openness probe build failed: $($build.stderr)$($build.stdout)"
}

$before = Get-PortalSnapshot
$probeExe = Join-Path $projectDirectory 'bin\Release\net48\TiaClaude.DirectOpennessProbe.exe'
$run = Invoke-CheckedProcess -FilePath $probeExe -Arguments @() -WorkingDirectory $projectDirectory -Timeout $TimeoutSeconds
$after = Get-PortalSnapshot

$newPids = @($after | Where-Object { $before.pid -notcontains $_.pid })
$report = [ordered]@{
    schemaVersion = 1
    status = if ($run.exitCode -eq 0) { 'verified' } else { 'blocked' }
    generatedAtUtc = (Get-Date).ToUniversalTime().ToString('O')
    purpose = 'Independent direct Siemens.Engineering/Openness V20 read-only probe'
    doctor = [ordered]@{ exitCode = $doctor.exitCode; output = $doctor.stdout }
    build = [ordered]@{ project = $projectPath; exitCode = $build.exitCode; output = $build.stdout }
    method = [ordered]@{
        mcpServerUsed = $false
        actions = @('Api.Global.Openness().Initialize(tiaMajorVersion:20)','Api.Global.Openness().IsUserInGroup()','TiaPortal.GetProcesses()')
        prohibitedActions = @('Attach','OpenProject','new TiaPortal','write','compile project','save','download')
    }
    result = [ordered]@{
        exitCode = $run.exitCode
        stdout = $run.stdout
        stderr = $run.stderr
        beforeProcesses = $before
        afterProcesses = $after
        noNewPortalProcess = ($newPids.Count -eq 0)
        noWrites = $true
        noAttach = $true
        noOpenProject = $true
        sourceAssembly = [ordered]@{
            path = $assemblyPath
            version = [Reflection.AssemblyName]::GetAssemblyName($assemblyPath).Version.ToString()
            sha256 = (Get-FileHash -Algorithm SHA256 $assemblyPath).Hash
        }
    }
    interpretation = [ordered]@{
        directOpennessV20 = if ($run.exitCode -eq 0) { 'verified' } else { 'blocked' }
        liveProcessEnumeration = if ($run.stdout -match 'process id=') { 'verified' } else { 'not verified' }
        projectMutation = 'not attempted'
        limitation = 'This proves package initialization, V20 assembly loading, group check, and read-only process enumeration. It does not prove project CRUD, compilation, HMI, PLCSIM runtime, or hardware operations.'
    }
}

$parent = Split-Path -Parent $OutputPath
New-Item -ItemType Directory -Force -Path $parent | Out-Null
$report | ConvertTo-Json -Depth 12 | Set-Content -Encoding UTF8 $OutputPath
Get-Content -Raw $OutputPath
