param(
    [string]$CondaEnvName = 'proview-ai',
    [string[]]$WindowsTargets = @('nsis', 'portable'),
    [switch]$SkipFrontend,
    [switch]$SkipBackend,
    [switch]$SkipPackage
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)
$OutputEncoding = [Console]::OutputEncoding
$env:PYTHONIOENCODING = 'utf-8'

$repoRoot = $PSScriptRoot
$desktopDir = Join-Path $repoRoot 'desktop'
$releaseDir = Join-Path $desktopDir 'release'
$sanitizedEnvPath = Join-Path $desktopDir 'build\.env'
$logDir = Join-Path $repoRoot 'logs\desktop-package'
New-Item -ItemType Directory -Path $logDir -Force | Out-Null
$timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$logFile = Join-Path $logDir "desktop-package-$timestamp.log"
$script:CondaPrefix = ''
$script:PowerShellHost = 'powershell'

$allowedEnvKeys = @(
    'LOCAL_USER_NAME',
    'ANY_MODEL_ENDPOINT',
    'DEEPSEEK_BASE_URL',
    'ERNIE_BASE_URL',
    'LOCAL_EMBEDDING_MODEL_DIR',
    'LOCAL_EMBEDDING_MAX_LENGTH',
    'EMBEDDING_BASE_URL',
    'EMBEDDING_MODEL',
    'EMBEDDING_DIMENSIONS',
    'EMBEDDING_BATCH_SIZE'
)

function Write-Log {
    param(
        [string]$Message
    )

    $line = "[{0}] {1}" -f (Get-Date -Format 'HH:mm:ss'), $Message
    Write-Host $line
    Add-Content -LiteralPath $logFile -Value $line -Encoding UTF8
}

function Write-Section {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Title
    )

    Write-Log ''
    Write-Log ('=' * 72)
    Write-Log $Title
    Write-Log ('=' * 72)
}

function Format-ArgumentList {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$Arguments
    )

    return ($Arguments | ForEach-Object {
        if ($_ -match '\s') {
            '"{0}"' -f $_
        } else {
            $_
        }
    }) -join ' '
}

function Assert-PathExists {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,
        [Parameter(Mandatory = $true)]
        [string]$Description
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "$Description 不存在: $Path"
    }
}

function Invoke-LoggedNativeCommand {
    param(
        [Parameter(Mandatory = $true)]
        [string]$FilePath,
        [Parameter(Mandatory = $true)]
        [string[]]$Arguments,
        [Parameter(Mandatory = $true)]
        [string]$Description
    )

    Write-Log "执行: $Description"
    Write-Log ("命令: {0} {1}" -f $FilePath, (Format-ArgumentList -Arguments $Arguments))

    & $FilePath @Arguments 2>&1 | Tee-Object -FilePath $logFile -Append
    $exitCode = $LASTEXITCODE
    if ($exitCode -ne 0) {
        throw "命令执行失败: $Description (exit code $exitCode)"
    }
}

function Invoke-LoggedPowerShellScript {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ScriptPath,
        [string[]]$ScriptArguments = @(),
        [Parameter(Mandatory = $true)]
        [string]$Description
    )

    Assert-PathExists -Path $ScriptPath -Description $Description
    $args = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $ScriptPath) + $ScriptArguments
    Invoke-LoggedNativeCommand -FilePath $script:PowerShellHost -Arguments $args -Description $Description
}

function Get-CondaEnvironmentPrefix {
    $condaCommand = Get-Command conda -ErrorAction Stop
    $rawOutput = & $condaCommand.Source 'env' 'list' '--json' 2>&1
    $exitCode = $LASTEXITCODE
    if ($exitCode -ne 0) {
        throw "无法读取 Conda 环境列表 (exit code $exitCode)"
    }

    $jsonText = ($rawOutput | ForEach-Object { "$_" }) -join [Environment]::NewLine
    $envInfo = $jsonText | ConvertFrom-Json
    $matched = $envInfo.envs | Where-Object { (Split-Path $_ -Leaf) -eq $CondaEnvName } | Select-Object -First 1
    if (-not $matched) {
        throw "未找到 Conda 环境: $CondaEnvName"
    }

    return [string]$matched
}

function Enable-CondaEnvironmentForCurrentProcess {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Prefix
    )

    $pathEntries = @(
        $Prefix,
        (Join-Path $Prefix 'Scripts'),
        (Join-Path $Prefix 'Library\bin'),
        (Join-Path $Prefix 'Library\usr\bin'),
        (Join-Path $Prefix 'DLLs')
    )

    $merged = New-Object System.Collections.Generic.List[string]
    $seen = @{}

    foreach ($entry in $pathEntries + ($env:Path -split ';')) {
        $text = [string]$entry
        if ([string]::IsNullOrWhiteSpace($text)) {
            continue
        }

        $normalized = $text.Trim()
        if ($seen.ContainsKey($normalized.ToLowerInvariant())) {
            continue
        }

        $seen[$normalized.ToLowerInvariant()] = $true
        $merged.Add($normalized)
    }

    $env:Path = $merged -join ';'
    $env:CONDA_DEFAULT_ENV = $CondaEnvName
    $env:CONDA_PREFIX = $Prefix
    $env:CONDA_PROMPT_MODIFIER = "($CondaEnvName) "
}

function Format-Duration {
    param(
        [Parameter(Mandatory = $true)]
        [TimeSpan]$Duration
    )

    return "{0:D2}:{1:D2}:{2:D2}" -f [int]$Duration.TotalHours, $Duration.Minutes, $Duration.Seconds
}

function Get-StepDefinitions {
    $steps = @(
        @{
            Name = '环境检查'
            Action = {
                Assert-PathExists -Path $desktopDir -Description 'desktop 目录'
                Assert-PathExists -Path (Join-Path $desktopDir 'scripts\build-frontend.ps1') -Description '前端构建脚本'
                Assert-PathExists -Path (Join-Path $desktopDir 'scripts\build-backend.ps1') -Description '后端构建脚本'
                Assert-PathExists -Path (Join-Path $desktopDir 'scripts\package-app.ps1') -Description '桌面端打包脚本'

                $null = Get-Command conda -ErrorAction Stop
                $null = Get-Command node -ErrorAction Stop
                $null = Get-Command npm -ErrorAction Stop
                $pwshCommand = Get-Command pwsh -ErrorAction SilentlyContinue
                if ($pwshCommand) {
                    $script:PowerShellHost = $pwshCommand.Source
                } else {
                    $script:PowerShellHost = (Get-Command powershell -ErrorAction Stop).Source
                }

                $script:CondaPrefix = Get-CondaEnvironmentPrefix
                Enable-CondaEnvironmentForCurrentProcess -Prefix $script:CondaPrefix

                $nodeVersion = (& node -v).Trim()
                if ($LASTEXITCODE -ne 0) {
                    throw '无法获取 Node.js 版本。'
                }

                $npmVersion = (& npm -v).Trim()
                if ($LASTEXITCODE -ne 0) {
                    throw '无法获取 npm 版本。'
                }

                Write-Log "仓库目录: $repoRoot"
                Write-Log "桌面目录: $desktopDir"
                Write-Log "输出目录: $releaseDir"
                Write-Log "日志文件: $logFile"
                Write-Log "Conda 环境: $CondaEnvName"
                Write-Log "Conda 前缀: $script:CondaPrefix"
                Write-Log "PowerShell 主机: $script:PowerShellHost"
                Write-Log "Windows 打包目标: $($WindowsTargets -join ', ')"
                Write-Log "Node.js 版本: $nodeVersion"
                Write-Log "npm 版本: $npmVersion"

                Invoke-LoggedNativeCommand `
                    -FilePath 'python' `
                    -Arguments @(
                        '-c',
                        'import sys; print(sys.executable); print(sys.version.split()[0])'
                    ) `
                    -Description '检查 Conda 环境中的 Python'
            }
        }
    )

    if (-not $SkipFrontend) {
        $steps += @{
            Name = '构建前端'
            Action = {
                Invoke-LoggedPowerShellScript `
                    -ScriptPath (Join-Path $desktopDir 'scripts\build-frontend.ps1') `
                    -Description '构建桌面版前端资源'
            }
        }
    }

    if (-not $SkipBackend) {
        $steps += @{
            Name = '构建后端'
            Action = {
                Invoke-LoggedPowerShellScript `
                    -ScriptPath (Join-Path $desktopDir 'scripts\build-backend.ps1') `
                    -Description '构建桌面版后端可分发资源'

                Assert-PathExists -Path $sanitizedEnvPath -Description '脱敏 .env'
                $sanitizedKeys = @()
                foreach ($line in Get-Content -LiteralPath $sanitizedEnvPath) {
                    if ($line -match '^\s*#' -or [string]::IsNullOrWhiteSpace($line)) {
                        continue
                    }

                    $separatorIndex = $line.IndexOf('=')
                    if ($separatorIndex -lt 1) {
                        continue
                    }

                    $key = $line.Substring(0, $separatorIndex).Trim()
                    $sanitizedKeys += $key
                    if ($allowedEnvKeys -notcontains $key) {
                        throw "脱敏 .env 中出现了未允许的键: $key"
                    }
                }

                Write-Log "脱敏 .env 已生成: $sanitizedEnvPath"
                if ($sanitizedKeys.Count -gt 0) {
                    Write-Log "保留的初始化键: $($sanitizedKeys -join ', ')"
                } else {
                    Write-Log '脱敏 .env 为空，仅使用脚本内默认值。'
                }
            }
        }
    }

    if (-not $SkipPackage) {
        $steps += @{
            Name = '打包桌面版'
            Action = {
                Invoke-LoggedPowerShellScript `
                    -ScriptPath (Join-Path $desktopDir 'scripts\package-app.ps1') `
                    -ScriptArguments (@('--win') + $WindowsTargets) `
                    -Description '生成安装包、便携版和解压目录'
            }
        }
    }

    $steps += @{
        Name = '检查产物'
        Action = {
            Assert-PathExists -Path $releaseDir -Description 'release 输出目录'

            $entries = Get-ChildItem -LiteralPath $releaseDir -Force | Sort-Object Name
            if (-not $entries) {
                throw "未在 $releaseDir 找到任何产物。"
            }

            $topLevelEntries = $entries | ForEach-Object {
                if ($_.PSIsContainer) {
                    "[目录] $($_.Name)"
                } else {
                    "{0} ({1:N2} MB)" -f $_.Name, ($_.Length / 1MB)
                }
            }

            Write-Log 'release 目录产物如下:'
            foreach ($entry in $topLevelEntries) {
                Write-Log "  - $entry"
            }

            $winUnpackedExe = Join-Path $releaseDir 'win-unpacked\ProView AI Interviewer.exe'
            if (Test-Path -LiteralPath $winUnpackedExe) {
                Write-Log "解压目录可执行文件: $winUnpackedExe"
            } else {
                Write-Log '未发现 win-unpacked 主程序，请检查 electron-builder 输出。'
            }
        }
    }

    return $steps
}

$steps = Get-StepDefinitions
$totalSteps = $steps.Count
$overallStart = Get-Date

Write-Section 'ProView Desktop 一键打包开始'
Write-Log '说明: 后端打包会自动生成脱敏 .env，敏感密钥不会进入桌面版。'

for ($index = 0; $index -lt $totalSteps; $index++) {
    $step = $steps[$index]
    $stepNumber = $index + 1
    $startPercent = [int](($index / $totalSteps) * 100)
    $endPercent = [int](($stepNumber / $totalSteps) * 100)

    Write-Progress `
        -Activity 'ProView Desktop 打包进度' `
        -Status ("步骤 {0}/{1}: {2}" -f $stepNumber, $totalSteps, $step.Name) `
        -PercentComplete $startPercent

    Write-Section ("步骤 {0}/{1}: {2}" -f $stepNumber, $totalSteps, $step.Name)
    $stepStart = Get-Date
    & $step.Action
    $duration = (Get-Date) - $stepStart

    Write-Log ("步骤完成: {0}，耗时 {1}" -f $step.Name, (Format-Duration -Duration $duration))
    Write-Progress `
        -Activity 'ProView Desktop 打包进度' `
        -Status ("步骤 {0}/{1}: {2} 已完成" -f $stepNumber, $totalSteps, $step.Name) `
        -PercentComplete $endPercent
}

$totalDuration = (Get-Date) - $overallStart
Write-Progress -Activity 'ProView Desktop 打包进度' -Completed
Write-Section '打包完成'
Write-Log ("总耗时: {0}" -f (Format-Duration -Duration $totalDuration))
Write-Log "详细日志: $logFile"
Write-Log "桌面端产物目录: $releaseDir"
