param(
    [Parameter(Mandatory = $true)][string]$Godot,
    [string[]]$Suites = @('sound', 'model', 'scene'),
    [switch]$Framework,
    [switch]$Window,
    [int]$TimeoutSeconds = 180
)

$ErrorActionPreference = 'Stop'
$frameworkRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..\..')).Path
$runId = [Guid]::NewGuid().ToString('N')
$workspace = Join-Path ([IO.Path]::GetTempPath()) "tifo_beato_validation_$runId"
New-Item -ItemType Directory -Path $workspace | Out-Null
$logs = Join-Path $workspace 'logs'
New-Item -ItemType Directory -Path $logs | Out-Null

# A separate project/user directory prevents suites from touching a player's saves.
foreach ($folder in @('assets', 'autoload', 'games', 'scenes', 'scripts', 'tests',
        'third_party', 'tools', 'ui')) {
    New-Item -ItemType Junction -Path (Join-Path $workspace $folder) `
        -Target (Join-Path $frameworkRoot $folder) | Out-Null
}
foreach ($file in @('default_bus_layout.tres', 'icon.svg', 'export_presets.cfg')) {
    Copy-Item -LiteralPath (Join-Path $frameworkRoot $file) -Destination $workspace
}
$project = [IO.File]::ReadAllText((Join-Path $frameworkRoot 'project.godot'))
$project = $project.Replace(
    'config/custom_user_dir_name="DeskCanSaw Games/DCS Base Game"',
    "config/custom_user_dir_name=`"DeskCanSaw Games/Tifo Validation $runId`"")
$projectPath = Join-Path $workspace 'project.godot'
$bootstrapProject = $project.Replace(
    'theme/custom="res://ui/theme/dcs_theme.tres"', 'theme/custom=""')
[IO.File]::WriteAllText($projectPath, $bootstrapProject)
$results = [Collections.Generic.List[object]]::new()

function Invoke-GodotCheck {
    param([string]$Name, [string[]]$Arguments)
    $stdout = Join-Path $logs "$Name.stdout.log"
    $stderr = Join-Path $logs "$Name.stderr.log"
    $process = Start-Process -FilePath $Godot -ArgumentList $Arguments `
        -NoNewWindow -PassThru -RedirectStandardOutput $stdout -RedirectStandardError $stderr
    if (-not $process.WaitForExit($TimeoutSeconds * 1000)) {
        Stop-Process -Id $process.Id
        throw "$Name exceeded $TimeoutSeconds seconds. Logs: $logs"
    }
    $process.Refresh()
    $output = ([IO.File]::ReadAllText($stdout) + [IO.File]::ReadAllText($stderr))
    $diagnostics = $output
    if ($Name -eq 'saves_test') {
        # This negative case deliberately asks ConfigFile to reject malformed bytes.
        $diagnostics = $diagnostics -replace (
            '(?m)^ERROR: ConfigFile parse error at user://saves_test_backups_\d+/' +
            '[a-z0-9_]+/unreadable\.cfg:0: Unexpected EOF while parsing simple tag\.\r?$'), ''
    }
    $passed = $process.ExitCode -eq 0 -and $diagnostics -notmatch '(?m)^(SCRIPT ERROR|ERROR):'
    $results.Add([pscustomobject]@{ Name = $Name; ExitCode = $process.ExitCode; Passed = $passed })
    Write-Output ("{0}: {1}" -f $Name, $(if ($passed) { 'PASS' } else { 'FAIL' }))
    if (-not $passed) {
        $output -split '[\r\n]+' | Where-Object { $_ -notmatch '^\[\s*\d+%' } | Write-Output
    }
}

$pathArguments = @('--path', ('"' + $workspace + '"'))
Invoke-GodotCheck 'import' (@('--headless', '--editor', '--import', '--quit') + $pathArguments)
if (-not $results[0].Passed) {
    throw "Import failed. Logs: $logs"
}
[IO.File]::WriteAllText($projectPath, $project)
foreach ($suite in $Suites) {
    Invoke-GodotCheck "tifo_$suite" (@('--headless', '--audio-driver', 'Dummy') + $pathArguments + @(
        '--script', "res://games/tifo_beato/tests/${suite}_test.gd", '--', '--game=all'))
}
if ($Framework) {
    foreach ($test in (Get-ChildItem -LiteralPath (Join-Path $frameworkRoot 'tests') `
            -Filter '*_test.gd' | Sort-Object Name)) {
        Invoke-GodotCheck $test.BaseName (@('--headless', '--audio-driver', 'Dummy') + $pathArguments + @(
            '--script', ('res://tests/' + $test.Name), '--', '--game=all'))
    }
}
if ($Window) {
    Invoke-GodotCheck 'curva_view' ($pathArguments + @('--audio-driver', 'Dummy',
        '--script', 'res://games/tifo_beato/tests/curva_view_test.gd', '--', '--game=all'))
}
$report = Join-Path $logs 'results.json'
$results | ConvertTo-Json | Set-Content -LiteralPath $report
Write-Output "Validation artifacts: $workspace"
if ($results.Where({ -not $_.Passed }).Count -gt 0) {
    exit 1
}
