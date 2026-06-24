<#
.SYNOPSIS
    Re-export Cycle Four to standalone Windows .exe(s) from the current source.

.DESCRIPTION
    The exported .exe never updates on its own -- it must be rebuilt from source after
    code changes. This script is that routine. By default it builds BOTH:

      Release : "Cycle Four.exe"         OS.is_debug_build()=false. Ship/play build.
                                          Dev keys F1-F4 OFF. Must play the full Academy.
      Debug   : "Cycle Four (DEBUG).exe" OS.is_debug_build()=true. Quick-playtest build.
                                          F1/F2/F3 skip Academy -> faction; F4 = +1h offline.
                                          Debug prints go to the godot user log folder.

    A clean export also compiles every script into the PCK, so a successful run doubles
    as a whole-project GDScript compile check.

    WORKFLOW: run this AFTER a change is verified + committed, so the Release .exe always
    tracks the latest confirmed-working build. Rebuild the Debug .exe freely while iterating.

.EXAMPLE
    .\tools\export.ps1             # both release + debug
    .\tools\export.ps1 -OnlyDebug  # debug only (fast iteration)
#>
param(
    [switch]$OnlyRelease,
    [switch]$OnlyDebug,
    [string]$Godot   = "D:\01 - game development software\godot_v4.6.1-stable_win64\godot_v4.6.1-stable_win64.exe",
    [string]$Project = "D:\AI\Cycle Four",
    [string]$Preset  = "Windows Desktop",
    [string]$OutDir  = "C:\Users\Brand\OneDrive\Desktop"
)

$ErrorActionPreference = 'Stop'

$buildRelease = -not $OnlyDebug
$buildDebug   = -not $OnlyRelease

$relOut = Join-Path $OutDir "Cycle Four.exe"
$dbgOut = Join-Path $OutDir "Cycle Four (DEBUG).exe"

if (-not (Test-Path $Godot))   { Write-Host "Godot binary not found: $Godot" -ForegroundColor Red; exit 1 }
if (-not (Test-Path $Project)) { Write-Host "Project not found: $Project"     -ForegroundColor Red; exit 1 }

# Build one .exe. Returns $true on success. Retries once on a cold no-file export
# (documented Godot quirk: a first cold export can write nothing; a warm re-run succeeds).
function Export-Build {
    param([string]$Mode, [string]$Out)

    $flag = '--export-debug'
    if ($Mode -eq 'release') { $flag = '--export-release' }

    $logOut = Join-Path $env:TEMP "c4_export_$Mode.out.log"
    $logErr = Join-Path $env:TEMP "c4_export_$Mode.err.log"

    # -ArgumentList MUST be ONE string -- the array form splits "Cycle Four" at its space.
    $cliArgs = '--headless --path "{0}" {1} "{2}" "{3}"' -f $Project, $flag, $Preset, $Out

    foreach ($attempt in 1..2) {
        Write-Host "[$Mode] exporting -> $Out (attempt $attempt)" -ForegroundColor Cyan
        $proc = Start-Process -FilePath $Godot -ArgumentList $cliArgs -NoNewWindow -Wait -PassThru -RedirectStandardOutput $logOut -RedirectStandardError $logErr
        $scriptErrors = Select-String -Path $logErr, $logOut -Pattern 'SCRIPT ERROR', 'Parse Error' -SimpleMatch -ErrorAction SilentlyContinue

        if ($proc.ExitCode -eq 0 -and (Test-Path $Out) -and -not $scriptErrors) {
            $info = Get-Item $Out
            $mb = [math]::Round($info.Length / 1MB, 1)
            Write-Host "[$Mode] OK  $($info.Name)  $mb MB  $($info.LastWriteTime)" -ForegroundColor Green
            return $true
        }

        if (-not (Test-Path $Out) -and $proc.ExitCode -eq 0 -and $attempt -eq 1) {
            Write-Host "[$Mode] cold export wrote no file -- retrying once..." -ForegroundColor Yellow
            continue
        }

        Write-Host "[$Mode] FAILED (exit $($proc.ExitCode))" -ForegroundColor Red
        if ($scriptErrors) { $scriptErrors | ForEach-Object { Write-Host "  $($_.Line)" -ForegroundColor Red } }
        if (-not $scriptErrors -and (Test-Path $Out)) { Write-Host "  (no script errors -- the output file may be LOCKED; is the .exe still running?)" -ForegroundColor Yellow }
        Write-Host "--- stderr tail ---"
        ## Route the tail through Write-Host so it does NOT leak into the function's return value
        ## (a bare Get-Content would make the caller see a truthy result and wrongly report success).
        if (Test-Path $logErr) { Get-Content $logErr -Tail 12 | ForEach-Object { Write-Host $_ } }
        return $false
    }
    return $false
}

$ok = $true
if ($buildRelease) { $ok = (Export-Build -Mode 'release' -Out $relOut) -and $ok }
if ($buildDebug)   { $ok = (Export-Build -Mode 'debug'   -Out $dbgOut) -and $ok }

if (-not $ok) { Write-Host "Export FAILED -- see errors above." -ForegroundColor Red; exit 1 }
Write-Host "Export complete." -ForegroundColor Green
