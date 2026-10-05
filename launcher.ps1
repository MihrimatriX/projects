#Requires -Version 5.1
<#
.SYNOPSIS
    DEV Projects baslatici: projeleri listeler, calistirir, arac zincirini denetler.

.EXAMPLE
    .\launcher.ps1                  # etkilesimli menu
    .\launcher.ps1 -Run regex       # klasor/isim eslesen projeyi yeni pencerede baslat
    .\launcher.ps1 -List -Stack python
    .\launcher.ps1 -Doctor          # .NET / Flutter / Python / Node kurulu mu?
    .\launcher.ps1 -Publish all     # tum projelerin exe'sini dist\ altina uret
    .\launcher.ps1 -Run regex -Source   # exe olsa da kaynaktan calistir
    .\launcher.ps1 -Gui             # Out-GridView ile sec
    .\launcher.ps1 -Wpf             # DevProjects.exe (grafik arayuz)
#>
param(
    [string]$Run,
    [string]$Search,
    [ValidateSet('all', 'dotnet', 'flutter', 'python', 'node', 'electron')]
    [string]$Stack = 'all',
    [switch]$List,
    [switch]$Gui,
    [switch]$Wpf,
    [switch]$Doctor,
    # Exe varsa bile kaynaktan (run.ps1) calistir.
    [switch]$Source,
    # publish.ps1 ile dist\<klasor>\ altina exe uret: proje adi/parcasi ya da 'all'.
    [string]$Publish,
    # Ic kullanim: projenin run.ps1'ini bu pencerede calistirir, hata olursa pencereyi acik tutar.
    [string]$Exec
)

$ErrorActionPreference = 'Stop'
$Root = $PSScriptRoot

# --- Arac zinciri -----------------------------------------------------------

function Update-SessionPath {
    $env:Path = [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' +
                [Environment]::GetEnvironmentVariable('Path', 'User')
}

function Find-Python {
    foreach ($v in '314', '313', '312', '311') {
        $p = Join-Path $env:LOCALAPPDATA "Programs\Python\Python$v\python.exe"
        if (Test-Path $p) { return $p }
    }
    if (Get-Command py -ErrorAction SilentlyContinue) { return 'py' }
    foreach ($n in 'python3', 'python') {
        $c = Get-Command $n -ErrorAction SilentlyContinue
        # WindowsApps altindaki python, Microsoft Store yonlendirmesidir; gercek Python degil.
        if ($c -and $c.Source -notmatch 'WindowsApps') { return $c.Source }
    }
    return $null
}

$Toolchains = [ordered]@{
    dotnet  = @{
        Name   = '.NET 10 SDK'
        Winget = 'Microsoft.DotNet.SDK.10'
        Test   = { (Get-Command dotnet -ErrorAction SilentlyContinue) -and (@(& dotnet --list-sdks 2>$null) -match '^1\d\.') }
    }
    flutter = @{
        Name = 'Flutter SDK'
        Url  = 'https://docs.flutter.dev/get-started/install/windows'
        Test = { (Get-Command flutter -ErrorAction SilentlyContinue) -or (Test-Path 'C:\flutter\bin\flutter.bat') -or
                 (Test-Path (Join-Path $env:LOCALAPPDATA 'flutter\bin\flutter.bat')) }
    }
    python  = @{
        Name   = 'Python 3.11+'
        Winget = 'Python.Python.3.13'
        Test   = { [bool](Find-Python) }
    }
    node    = @{
        Name   = 'Node.js'
        Winget = 'OpenJS.NodeJS.LTS'
        Test   = { [bool](Get-Command node -ErrorAction SilentlyContinue) }
    }
}

function Get-ToolchainKey([string]$ProjectStack) {
    if ($ProjectStack -eq 'electron') { return 'node' }
    return $ProjectStack
}

# Eksikse winget ile kurmayi teklif eder. $true = arac hazir.
function Assert-Toolchain([string]$ProjectStack) {
    $key = Get-ToolchainKey $ProjectStack
    $tc = $Toolchains[$key]
    if (-not $tc -or (& $tc.Test)) { return $true }

    Write-Host "Gerekli arac bulunamadi: $($tc.Name)" -ForegroundColor Red
    if (-not $tc.Winget -or -not (Get-Command winget -ErrorAction SilentlyContinue)) {
        if ($tc.Url) { Write-Host "Kurulum: $($tc.Url)" -ForegroundColor Yellow }
        return $false
    }
    if ((Read-Host "winget ile simdi kurulsun mu? (e/h)") -notmatch '^[eEyY]') { return $false }

    & winget install --id $tc.Winget --scope user --silent --accept-package-agreements --accept-source-agreements | Out-Host
    if ($LASTEXITCODE -ne 0) {
        # Bazi paketler (orn. .NET SDK) kullanici kapsamini desteklemez; makine kapsamiyla tekrar dene.
        & winget install --id $tc.Winget --silent --accept-package-agreements --accept-source-agreements | Out-Host
    }
    Update-SessionPath
    return [bool](& $tc.Test)
}

function Show-Doctor {
    Write-Host ''
    foreach ($key in $Toolchains.Keys) {
        $tc = $Toolchains[$key]
        if (& $tc.Test) {
            Write-Host ("  [OK]    {0}" -f $tc.Name) -ForegroundColor Green
        } else {
            $hint = if ($tc.Winget) { "winget install $($tc.Winget)" } else { $tc.Url }
            Write-Host ("  [YOK]   {0,-14} -> {1}" -f $tc.Name, $hint) -ForegroundColor Red
        }
    }
    Write-Host ''
}

# --- Proje katalogu ---------------------------------------------------------

function Get-ReadmeTitle([string]$ReadmePath) {
    if (-not (Test-Path $ReadmePath)) { return $null }
    foreach ($line in Get-Content $ReadmePath -Encoding UTF8 -TotalCount 5) {
        if ($line -match '^\#\s+(.+)') { return $Matches[1].Trim() }
    }
    return $null
}

function Get-ProjectStack([string]$Dir) {
    $pkg = Join-Path $Dir 'package.json'
    # package.json olan klasorde .csproj aranmaz: node_modules taramasi acilisi saniyelerce yavaslatir.
    if (-not (Test-Path $pkg) -and
        (Get-ChildItem -Path $Dir -Filter '*.csproj' -Recurse -Depth 2 -ErrorAction SilentlyContinue | Select-Object -First 1)) {
        return 'dotnet'
    }
    if (Test-Path (Join-Path $Dir 'pubspec.yaml')) { return 'flutter' }
    if (Test-Path (Join-Path $Dir 'main.py')) { return 'python' }
    if (Test-Path $pkg) {
        $raw = Get-Content $pkg -Raw -Encoding UTF8
        # Next.js projeleri masaustu kabugu icin electron'u da tasiyabilir; next onceliklidir.
        if ($raw -match '"electron"\s*:' -and $raw -notmatch '"next"\s*:') { return 'electron' }
        return 'node'
    }
    return 'other'
}

function Get-StackLabel([string]$ProjectStack) {
    switch ($ProjectStack) {
        'dotnet'   { 'C# / .NET' }
        'flutter'  { 'Flutter' }
        'python'   { 'Python' }
        'node'     { 'Next.js / Web' }
        'electron' { 'Electron' }
        default    { 'Diger' }
    }
}

function Get-AllProjects {
    Get-ChildItem $Root -Directory |
        Where-Object { $_.Name -notmatch '^\.' -and $_.Name -ne 'proje-launcher' } |
        ForEach-Object {
            $dir = $_.FullName
            $name = $null; $desc = $null; $tags = @()

            $manifestPath = Join-Path $dir 'assets\manifest.json'
            if (Test-Path $manifestPath) {
                try {
                    $m = Get-Content $manifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
                    if ($m.name) { $name = [string]$m.name }
                    if ($m.description) { $desc = [string]$m.description }
                    if ($m.tags) { $tags = @($m.tags) }
                } catch { }
            }
            if (-not $name) { $name = Get-ReadmeTitle (Join-Path $dir 'README.md') }
            if (-not $name) { $name = $_.Name }

            $stack = Get-ProjectStack $dir
            $runPs1 = Join-Path $dir 'run.ps1'
            # Sozlesme: dist\<klasor>\ en ust duzeyinde tek bir exe.
            $exes = @(Get-ChildItem (Join-Path $Root "dist\$($_.Name)") -Filter '*.exe' -File -ErrorAction SilentlyContinue)
            [pscustomobject]@{
                Folder      = $_.Name
                Name        = $name
                Stack       = $stack
                StackLabel  = Get-StackLabel $stack
                Description = $desc
                Tags        = $tags -join ', '
                RunScript   = if (Test-Path $runPs1) { $runPs1 } else { $null }
                HasRun      = Test-Path $runPs1
                Exe         = if ($exes.Count -eq 1) { $exes[0].FullName } else { $null }
                Publish     = if (Test-Path (Join-Path $dir 'publish.ps1')) { Join-Path $dir 'publish.ps1' } else { $null }
                Readme      = Join-Path $dir 'README.md'
                Path        = $dir
            }
        } |
        Sort-Object Name
}

function Find-Project($Projects, [string]$Key) {
    $exact = @($Projects | Where-Object { $_.Folder -eq $Key -or $_.Name -eq $Key })
    if ($exact.Count) { return $exact[0] }
    $partial = @($Projects | Where-Object { $_.Folder -like "*$Key*" -or $_.Name -like "*$Key*" })
    if ($partial.Count -eq 1) { return $partial[0] }
    if ($partial.Count -gt 1) {
        Write-Host "Birden fazla eslesme: $($partial.Folder -join ', ')" -ForegroundColor Yellow
    }
    return $null
}

# --- Calistirma -------------------------------------------------------------

# Yeni pencere acar; o pencere bu betigi -Exec ile cagirir (arac denetimi + hata goruntuleme).
function Start-Project($Project, [switch]$FromSource) {
    if ($Project.Exe -and -not $FromSource) {
        Write-Host ">> $($Project.Name) (exe)" -ForegroundColor Cyan
        Start-Process -FilePath $Project.Exe -WorkingDirectory (Split-Path $Project.Exe -Parent)
        return
    }
    if (-not $Project.HasRun) {
        Write-Host "Bu projede run.ps1 yok: $($Project.Folder) (README: $($Project.Readme))" -ForegroundColor Yellow
        return
    }
    Write-Host ">> $($Project.Name)" -ForegroundColor Cyan
    Start-Process powershell.exe -WorkingDirectory $Project.Path -ArgumentList @(
        '-NoProfile', '-ExecutionPolicy', 'Bypass',
        '-File', "`"$PSCommandPath`"", '-Exec', "`"$($Project.Folder)`""
    )
}

function Invoke-ProjectExec($Project) {
    $Host.UI.RawUI.WindowTitle = "$($Project.Name) - DEV Projects"
    if ($PSVersionTable.PSEdition -eq 'Desktop') {
        # pwsh 7'den baslatildiysa miras kalan PS7 modul yollari 5.1'de Get-FileHash vb. komutlari bozar.
        $env:PSModulePath = (($env:PSModulePath -split ';') | Where-Object { $_ -and $_ -notmatch '\\PowerShell\\' }) -join ';'
    }
    $ok = Assert-Toolchain $Project.Stack
    if ($ok) {
        $global:LASTEXITCODE = 0
        try {
            & $Project.RunScript
            if ($LASTEXITCODE) {
                $ok = $false
                Write-Host "run.ps1 hata koduyla bitti: $LASTEXITCODE" -ForegroundColor Red
            }
        } catch {
            $ok = $false
            Write-Host "HATA: $($_.Exception.Message)" -ForegroundColor Red
            Write-Host $_.InvocationInfo.PositionMessage -ForegroundColor DarkGray
        }
    }
    if (-not $ok) {
        Write-Host ''
        Read-Host 'Pencereyi kapatmak icin Enter'
        exit 1
    }
}

# Her projenin publish.ps1'ini sirayla bu pencerede calistirir, sonunda ozet verir.
function Invoke-Publish($Targets) {
    $results = foreach ($p in $Targets) {
        if (-not $p.Publish) { [pscustomobject]@{ Proje = $p.Folder; Sonuc = 'publish.ps1 yok'; Sure = '' }; continue }
        Write-Host "`n===== $($p.Name) =====" -ForegroundColor Cyan
        $sw = [Diagnostics.Stopwatch]::StartNew()
        $global:LASTEXITCODE = 0
        $res = 'OK'
        if (-not (Assert-Toolchain $p.Stack)) { $res = 'arac eksik' }
        else {
            # Ayri surec: bir projenin Set-Location/hata ayari digerini etkilemesin.
            & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $p.Publish | Out-Host
            if ($LASTEXITCODE) { $res = "HATA ($LASTEXITCODE)" }
        }
        [pscustomobject]@{ Proje = $p.Folder; Sonuc = $res; Sure = '{0:n0} sn' -f $sw.Elapsed.TotalSeconds }
    }
    $results | Format-Table -AutoSize | Out-Host
    if (@($results | Where-Object Sonuc -ne 'OK').Count) { return 1 }
    return 0
}

# --- Giris ------------------------------------------------------------------

if ($Doctor) { Show-Doctor; exit 0 }

$projects = @(Get-AllProjects)

if ($Exec) {
    $target = $projects | Where-Object Folder -eq $Exec | Select-Object -First 1
    if (-not $target -or -not $target.HasRun) {
        Write-Host "Proje ya da run.ps1 bulunamadi: $Exec" -ForegroundColor Red
        Read-Host 'Enter'
        exit 1
    }
    Invoke-ProjectExec $target
    exit 0
}

if ($Stack -ne 'all') { $projects = @($projects | Where-Object Stack -eq $Stack) }
if ($Search) {
    $projects = @($projects | Where-Object {
        $_.Folder -like "*$Search*" -or $_.Name -like "*$Search*" -or $_.Tags -like "*$Search*"
    })
}

if ($Publish) {
    $targets = if ($Publish -eq 'all') { $projects } else { @(Find-Project $projects $Publish) }
    if (-not $targets -or -not $targets[0]) { Write-Host "Proje bulunamadi: $Publish" -ForegroundColor Red; exit 1 }
    exit (Invoke-Publish $targets)
}

if ($Run) {
    $target = Find-Project $projects $Run
    if (-not $target) { Write-Host "Proje bulunamadi: $Run" -ForegroundColor Red; exit 1 }
    Start-Project $target -FromSource:$Source
    exit 0
}

if ($List) {
    $projects | Format-Table Folder, Name, StackLabel, @{ n = 'Exe'; e = { if ($_.Exe) { 'evet' } else { '-' } } } -AutoSize
    exit 0
}

if ($Wpf) {
    $rootExe = Join-Path $Root 'DevProjects.exe'
    if (Test-Path $rootExe) { Start-Process -FilePath $rootExe -WorkingDirectory $Root; exit 0 }
    & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Root 'proje-launcher\run.ps1')
    exit $LASTEXITCODE
}

if ($Gui) {
    $picked = $projects |
        Select-Object @{ n = 'Proje'; e = { $_.Name } }, @{ n = 'Klasor'; e = { $_.Folder } }, @{ n = 'Stack'; e = { $_.StackLabel } } |
        Out-GridView -Title 'DEV Projects - bir proje secin' -PassThru
    if ($picked) { Start-Project ($projects | Where-Object Folder -eq $picked.Klasor | Select-Object -First 1) }
    exit 0
}

Write-Host ''
Write-Host '  ======================================' -ForegroundColor Cyan
Write-Host '       DEV Projects - Proje Launcher    ' -ForegroundColor Cyan
Write-Host '  ======================================' -ForegroundColor Cyan
Write-Host ("  {0} proje" -f $projects.Count) -ForegroundColor DarkGray
Write-Host ''

while ($true) {
    Write-Host '--- Filtre ---' -ForegroundColor DarkCyan
    Write-Host '  [1] Tumu  [2] .NET  [3] Flutter  [4] Python  [5] Web  [6] Electron  [d] Arac denetimi  [0] Cik'
    $filterChoice = Read-Host 'Filtre'
    if ($filterChoice -eq '0' -or $filterChoice -eq 'q') { break }
    if ($filterChoice -eq 'd') { Show-Doctor; continue }

    # @(...): PS 5.1'de tek sonuclu pscustomobject'in .Count'u yoktur
    $filtered = @(switch ($filterChoice) {
        '2' { $projects | Where-Object Stack -eq 'dotnet' }
        '3' { $projects | Where-Object Stack -eq 'flutter' }
        '4' { $projects | Where-Object Stack -eq 'python' }
        '5' { $projects | Where-Object Stack -eq 'node' }
        '6' { $projects | Where-Object Stack -eq 'electron' }
        default { $projects }
    })

    $searchTerm = Read-Host 'Ara (bos = tumu)'
    if ($searchTerm) {
        $filtered = @($filtered | Where-Object { $_.Folder -like "*$searchTerm*" -or $_.Name -like "*$searchTerm*" })
    }
    if (-not $filtered.Count) { Write-Host 'Sonuc yok.' -ForegroundColor Yellow; continue }

    Write-Host ''
    for ($i = 0; $i -lt $filtered.Count; $i++) {
        $p = $filtered[$i]
        $tag = if ($p.Exe) { ' [exe]' } else { '' }
        Write-Host ("{0,3}. {1}{2}" -f ($i + 1), $p.Name, $tag) -ForegroundColor White
        Write-Host ('     {0} - {1}' -f $p.StackLabel, $p.Folder) -ForegroundColor DarkGray
    }
    Write-Host ''
    Write-Host '--- Islem ---' -ForegroundColor DarkCyan
    Write-Host '  <no>: calistir (exe varsa exe) | s<no>: kaynaktan | p<no>: exe uret | f<no>: klasor | r<no>: README | q: cik'
    $action = Read-Host 'Secim'
    if ($action -eq 'q') { break }

    if ($action -match '^([fprs]?)(\d+)$') {
        $idx = [int]$Matches[2] - 1
        if ($idx -lt 0 -or $idx -ge $filtered.Count) { Write-Host 'Gecersiz numara.' -ForegroundColor Yellow; continue }
        $p = $filtered[$idx]
        switch ($Matches[1]) {
            'f' { Start-Process explorer.exe -ArgumentList "`"$($p.Path)`"" }
            'r' { if (Test-Path $p.Readme) { Start-Process $p.Readme } }
            's' { Start-Project $p -FromSource }
            'p' { Invoke-Publish @($p) | Out-Null }
            default { Start-Project $p }
        }
    }
}
