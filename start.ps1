param(
    [ValidateSet("docker", "local")]
    [string]$Mode = "docker"
)

$ErrorActionPreference = "Stop"
$script:LastInstallError = ""
$script:LastInstallTarget = ""

function Test-CommandExists {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name
    )

    return $null -ne (Get-Command $Name -ErrorAction SilentlyContinue)
}

function Resolve-CommandPath {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$Candidates
    )

    foreach ($candidate in $Candidates) {
        $command = Get-Command $candidate -ErrorAction SilentlyContinue
        if ($null -ne $command) {
            return $command.Source
        }
    }

    return $null
}

function Set-LastInstallError {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Target,
        [string]$Message = ""
    )

    $script:LastInstallTarget = $Target
    $script:LastInstallError = $Message
}

function Test-WingetExists {
    return Test-CommandExists "winget"
}

function Try-InstallScoop {
    Set-LastInstallError -Target "scoop" -Message ""

    if (Test-CommandExists "scoop") {
        return $true
    }

    Write-Host "未检测到 scoop，先尝试自动安装 scoop..." -ForegroundColor Yellow

    if (Test-WingetExists) {
        try {
            $wingetOutput = & winget install --id ScoopInstaller.Scoop --source winget --accept-source-agreements --accept-package-agreements 2>&1
            $wingetExitCode = $LASTEXITCODE
            if ($wingetOutput) {
                $wingetOutput | ForEach-Object { Write-Host $_ }
            }
            if ($wingetExitCode -eq 0 -and (Test-CommandExists "scoop")) {
                return $true
            }
            Set-LastInstallError -Target "scoop" -Message (($wingetOutput | Out-String).Trim())
        } catch {
            Set-LastInstallError -Target "scoop" -Message $_.Exception.Message
        }
    }

    try {
        Write-Host "winget 安装未成功，尝试通过官方脚本安装 scoop..." -ForegroundColor Yellow
        Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
        Invoke-RestMethod -Uri "https://get.scoop.sh" | Invoke-Expression
        if (Test-CommandExists "scoop") {
            return $true
        }
        Set-LastInstallError -Target "scoop" -Message "官方脚本执行完成，但当前会话仍未检测到 scoop。"
    } catch {
        Set-LastInstallError -Target "scoop" -Message $_.Exception.Message
    }

    return $false
}

function Try-InstallWithScoop {
    param(
        [Parameter(Mandatory = $true)]
        [string]$PackageName
    )

    Set-LastInstallError -Target $PackageName -Message ""

    if (!(Try-InstallScoop)) {
        return $false
    }

    Write-Host "检测到缺少 $PackageName，尝试通过 scoop 安装..."
    try {
        $output = & scoop install $PackageName 2>&1
        $exitCode = $LASTEXITCODE
        if ($output) {
            $output | ForEach-Object { Write-Host $_ }
        }
        if ($exitCode -eq 0) {
            return $true
        }
        Set-LastInstallError -Target $PackageName -Message (($output | Out-String).Trim())
        return $false
    } catch {
        Set-LastInstallError -Target $PackageName -Message $_.Exception.Message
        return $false
    }
}

function Try-InstallWithWinget {
    param(
        [Parameter(Mandatory = $true)]
        [string]$PackageId
    )

    Set-LastInstallError -Target $PackageId -Message ""

    if (!(Test-WingetExists)) {
        Set-LastInstallError -Target $PackageId -Message "当前环境未检测到 winget。"
        return $false
    }

    Write-Host "尝试通过 winget 安装 $PackageId ..."
    try {
        $output = & winget install --id $PackageId --source winget --accept-source-agreements --accept-package-agreements 2>&1
        $exitCode = $LASTEXITCODE
        if ($output) {
            $output | ForEach-Object { Write-Host $_ }
        }
        if ($exitCode -eq 0) {
            return $true
        }
        Set-LastInstallError -Target $PackageId -Message (($output | Out-String).Trim())
        return $false
    } catch {
        Set-LastInstallError -Target $PackageId -Message $_.Exception.Message
        return $false
    }
}

function Get-DockerDesktopExePath {
    $candidates = @(
        "C:\Program Files\Docker\Docker\Docker Desktop.exe",
        "C:\Program Files\Docker\Docker\Docker Desktop Installer.exe"
    )

    foreach ($candidate in $candidates) {
        if (Test-Path $candidate) {
            return $candidate
        }
    }

    return $null
}

function Get-RancherDesktopExePath {
    $candidates = @(
        "C:\Program Files\Rancher Desktop\Rancher Desktop.exe",
        "$env:LOCALAPPDATA\Programs\Rancher Desktop\Rancher Desktop.exe"
    )

    foreach ($candidate in $candidates) {
        if (Test-Path $candidate) {
            return $candidate
        }
    }

    return $null
}

function Get-RdctlExePath {
    $candidates = @(
        "$env:LOCALAPPDATA\Programs\Rancher Desktop\resources\resources\win32\bin\rdctl.exe",
        "C:\Program Files\Rancher Desktop\resources\resources\win32\bin\rdctl.exe"
    )

    foreach ($candidate in $candidates) {
        if (Test-Path $candidate) {
            return $candidate
        }
    }

    return $null
}

function Try-InstallDocker {
    Set-LastInstallError -Target "container_runtime" -Message ""

    Write-Host "优先尝试安装 Rancher Desktop..." -ForegroundColor Yellow
    $wingetInstalled = Try-InstallWithWinget "SUSE.RancherDesktop"
    if ($wingetInstalled) {
        return $true
    }

    Write-Host "winget 安装 Rancher Desktop 未成功，回退尝试安装 Docker Desktop..." -ForegroundColor Yellow
    $wingetInstalled = Try-InstallWithWinget "Docker.DockerDesktop"
    if ($wingetInstalled) {
        return $true
    }

    Write-Host "winget 安装 Docker Desktop 也未成功，最后回退到 scoop 安装 docker CLI..." -ForegroundColor Yellow
    return Try-InstallWithScoop "docker"
}

function Test-DockerDaemonReady {
    if (!(Test-CommandExists "docker")) {
        return $false
    }

    & docker info *> $null
    return $LASTEXITCODE -eq 0
}

function Try-StartDockerDesktop {
    $dockerDesktopExe = Get-DockerDesktopExePath
    if ([string]::IsNullOrWhiteSpace($dockerDesktopExe)) {
        return $false
    }

    Write-Host "检测到 Docker Desktop 已安装，尝试自动启动..." -ForegroundColor Yellow
    try {
        Start-Process -FilePath $dockerDesktopExe
        return $true
    } catch {
        Set-LastInstallError -Target "docker_desktop_start" -Message $_.Exception.Message
        return $false
    }
}

function Try-StartRancherDesktop {
    $rancherDesktopExe = Get-RancherDesktopExePath
    if ([string]::IsNullOrWhiteSpace($rancherDesktopExe)) {
        return $false
    }

    Write-Host "检测到 Rancher Desktop 已安装，尝试自动启动..." -ForegroundColor Yellow
    try {
        Start-Process -FilePath $rancherDesktopExe
        $rdctl = Get-RdctlExePath
        if (-not [string]::IsNullOrWhiteSpace($rdctl)) {
            Write-Host "尝试通过 rdctl 启动 Rancher Desktop..." -ForegroundColor Yellow
            & $rdctl start *> $null
        }
        return $true
    } catch {
        Set-LastInstallError -Target "rancher_desktop_start" -Message $_.Exception.Message
        return $false
    }
}

function Wait-DockerDaemonReady {
    param(
        [int]$TimeoutSeconds = 90
    )

    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    while ((Get-Date) -lt $deadline) {
        if (Test-DockerDaemonReady) {
            return $true
        }
        Start-Sleep -Seconds 3
    }

    return $false
}

function Try-InstallMissingToolchain {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$Missing
    )

    $failed = @()

    if ($Missing -contains "go") {
        if (!(Try-InstallWithScoop "go")) {
            Add-MissingItem -List ([ref]$failed) -Value "go"
        }
    }

    if ($Missing -contains "node_npm") {
        if (!(Try-InstallWithScoop "nodejs-lts")) {
            Add-MissingItem -List ([ref]$failed) -Value "node_npm"
        }
    }

    if ($Missing -contains "python_runtime" -or $Missing -contains "python_pip") {
        if (!(Try-InstallWithScoop "python")) {
            Add-MissingItem -List ([ref]$failed) -Value "python"
        }
    }

    return $failed
}

function Add-MissingItem {
    param(
        [Parameter(Mandatory = $true)]
        [ref]$List,
        [Parameter(Mandatory = $true)]
        [string]$Value
    )

    if ($List.Value -notcontains $Value) {
        $List.Value += $Value
    }
}

function Set-ProxyEnv {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ProxyUrl
    )

    $env:HTTP_PROXY = $ProxyUrl
    $env:HTTPS_PROXY = $ProxyUrl
    $env:http_proxy = $ProxyUrl
    $env:https_proxy = $ProxyUrl
}

function Prompt-ProxyIfNeeded {
    Write-Host ""
    Write-Host "如果当前失败与网络/代理有关，可以现在输入代理地址后重试。" -ForegroundColor Yellow
    Write-Host "代理格式示例：" -ForegroundColor Yellow
    Write-Host "   http://127.0.0.1:7890" -ForegroundColor Cyan
    Write-Host "   http://user:pass@host:port" -ForegroundColor Cyan
    $proxy = Read-Host "请输入代理地址（直接回车表示不设置）"
    if (![string]::IsNullOrWhiteSpace($proxy)) {
        Set-ProxyEnv -ProxyUrl $proxy
        Write-Host "已设置当前进程代理环境变量，准备重试..." -ForegroundColor Green
        return $true
    }
    return $false
}

function Show-DockerInstallGuide {
    Write-Host ""
    Write-Host "未检测到可用的容器运行时，当前不能进入正式骨架模式。" -ForegroundColor Yellow
    Write-Host "请按下面顺序安装：" -ForegroundColor Yellow
    Write-Host "1. 优先安装 Rancher Desktop：" -ForegroundColor Yellow
    Write-Host "   winget install --id SUSE.RancherDesktop --source winget" -ForegroundColor Cyan
    Write-Host "   安装后请在设置里确认容器引擎使用 Moby/dockerd，确保 'docker' / 'docker compose' 可用" -ForegroundColor Yellow
    Write-Host "2. 如果你仍想用 Docker Desktop：" -ForegroundColor Yellow
    Write-Host "   winget install --id Docker.DockerDesktop --source winget" -ForegroundColor Cyan
    Write-Host "3. 如果你只想先装 CLI，可选用 scoop：" -ForegroundColor Yellow
    Write-Host "   scoop install docker" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "安装完成后重新运行：" -ForegroundColor Yellow
    Write-Host "   ./start.ps1" -ForegroundColor Cyan
}

function Show-RancherDesktopStartGuide {
    Write-Host ""
    Write-Host "检测到你更可能在使用 Rancher Desktop，但当前 docker daemon 没有就绪。" -ForegroundColor Yellow
    Write-Host "请先启动 Rancher Desktop，并确认设置正确：" -ForegroundColor Yellow
    Write-Host "1. 打开 Rancher Desktop" -ForegroundColor Yellow
    Write-Host "2. 在设置里确认容器引擎选择 Moby/dockerd" -ForegroundColor Yellow
    Write-Host "3. 等待状态稳定后先验证：" -ForegroundColor Yellow
    Write-Host "   docker info" -ForegroundColor Cyan
    Write-Host "4. 然后重新运行：" -ForegroundColor Yellow
    Write-Host "   ./start.ps1" -ForegroundColor Cyan
}

function Show-DockerDesktopStartGuide {
    Write-Host ""
    Write-Host "检测到 docker 客户端已存在，但当前 Docker daemon 没有运行。" -ForegroundColor Yellow
    Write-Host "请先启动 Docker Desktop，并等待状态变成 Running：" -ForegroundColor Yellow
    Write-Host "1. 从开始菜单打开 Docker Desktop" -ForegroundColor Yellow
    Write-Host "2. 等托盘里的 Docker 图标完成启动" -ForegroundColor Yellow
    Write-Host "3. 先确认下面命令成功：" -ForegroundColor Yellow
    Write-Host "   docker info" -ForegroundColor Cyan
    Write-Host "4. 然后重新运行：" -ForegroundColor Yellow
    Write-Host "   ./start.ps1" -ForegroundColor Cyan
}

function Show-GoInstallGuide {
    Write-Host ""
    Write-Host "未检测到 Go，当前不能进入正式本地开发模式。" -ForegroundColor Yellow
    Write-Host "请安装 Go 1.22 或更高版本：" -ForegroundColor Yellow
    Write-Host "1. 官方安装包安装后，确认下面命令可执行：" -ForegroundColor Yellow
    Write-Host "   go version" -ForegroundColor Cyan
    Write-Host "2. 如果你机器允许用 scoop：" -ForegroundColor Yellow
    Write-Host "   scoop install go" -ForegroundColor Cyan
}

function Show-NodeInstallGuide {
    Write-Host ""
    Write-Host "未检测到 Node.js/npm，当前不能启动管理台。" -ForegroundColor Yellow
    Write-Host "请安装 Node.js 20 或更高版本，并确认下面命令可执行：" -ForegroundColor Yellow
    Write-Host "   node --version" -ForegroundColor Cyan
    Write-Host "   npm --version" -ForegroundColor Cyan
}

function Show-PythonInstallGuide {
    Write-Host ""
    Write-Host "当前 Python 依赖安装失败，不能进入正式本地开发模式。" -ForegroundColor Yellow
    Write-Host "建议安装官方 Python 3.11 或 3.12（带 pip），不要优先依赖商店版 Python。" -ForegroundColor Yellow
    Write-Host "安装后请确认：" -ForegroundColor Yellow
    Write-Host "   python --version" -ForegroundColor Cyan
    Write-Host "   python -m pip --version" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "然后执行下面命令安装依赖：" -ForegroundColor Yellow
    Write-Host "   python -m pip install -r services/model-asr-python/requirements.txt" -ForegroundColor Cyan
    Write-Host "   python -m pip install -r services/model-tts-python/requirements.txt" -ForegroundColor Cyan
    Write-Host "   python -m pip install -r services/model-avatar-python/requirements.txt" -ForegroundColor Cyan
    Write-Host "   python -m pip install -r services/model-llm-python/requirements.txt" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "如果 pip 仍然报 HTTPS / OpenSSL / 证书 / 代理错误，请优先检查：" -ForegroundColor Yellow
    Write-Host "1. 网络是否可访问你的 PyPI 镜像" -ForegroundColor Yellow
    Write-Host "2. 系统环境变量中是否设置了异常的 SSL/OpenSSL 相关变量" -ForegroundColor Yellow
    Write-Host "3. 公司代理、证书或杀软是否拦截了 Python HTTPS 请求" -ForegroundColor Yellow
}

function Try-InstallPythonDeps {
    param(
        [Parameter(Mandatory = $true)]
        [string]$PythonExe
    )

    $requirements = @(
        "services/model-asr-python/requirements.txt",
        "services/model-tts-python/requirements.txt",
        "services/model-avatar-python/requirements.txt",
        "services/model-llm-python/requirements.txt"
    )

    foreach ($item in $requirements) {
        Write-Host "尝试安装依赖: $item"
        & $PythonExe -m pip install -r $item
        if ($LASTEXITCODE -ne 0) {
            return $false
        }
    }
    return $true
}

function Try-InstallNodeDeps {
    param(
        [Parameter(Mandatory = $true)]
        [string]$NpmExe
    )

    Write-Host "尝试安装依赖: services/admin-web/package.json"
    & $NpmExe install --prefix "services/admin-web"
    return $LASTEXITCODE -eq 0
}

function Try-InstallGoDeps {
    param(
        [Parameter(Mandatory = $true)]
        [string]$GoExe
    )

    Write-Host "尝试安装依赖: services/orchestrator-go/go.mod"
    Push-Location "services/orchestrator-go"
    try {
        & $GoExe mod download
        return $LASTEXITCODE -eq 0
    } finally {
        Pop-Location
    }
}

function Test-LocalModePrerequisites {
    $bundledPython = "C:\Users\Lei\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe"
    $python = $null
    if (Test-Path $bundledPython) {
        $python = $bundledPython
    } else {
        $python = Resolve-CommandPath -Candidates @("python", "py")
    }

    $go = Resolve-CommandPath -Candidates @("go")
    $npm = Resolve-CommandPath -Candidates @("npm.cmd", "npm")
    $missing = @()

    if ([string]::IsNullOrWhiteSpace($python)) {
        Add-MissingItem -List ([ref]$missing) -Value "python_runtime"
    }
    if ([string]::IsNullOrWhiteSpace($go)) {
        Add-MissingItem -List ([ref]$missing) -Value "go"
    }
    if ([string]::IsNullOrWhiteSpace($npm)) {
        Add-MissingItem -List ([ref]$missing) -Value "node_npm"
    }
    if (-not [string]::IsNullOrWhiteSpace($python)) {
        & $python -m pip --version *> $null
        if ($LASTEXITCODE -ne 0) {
            Add-MissingItem -List ([ref]$missing) -Value "python_pip"
        }
    }

    return @{
        python = $python
        go = $go
        npm = $npm
        missing = $missing
    }
}

function Test-DockerModePrerequisites {
    $missing = @()
    $rancherInstalled = $null -ne (Get-RancherDesktopExePath)
    $dockerDesktopInstalled = $null -ne (Get-DockerDesktopExePath)

    if (!(Test-CommandExists "docker")) {
        Add-MissingItem -List ([ref]$missing) -Value "docker"
        return @{
            missing = $missing
            dockerReady = $false
            rancherDesktopInstalled = $rancherInstalled
            dockerDesktopInstalled = $dockerDesktopInstalled
        }
    }

    if (Test-DockerDaemonReady) {
        return @{
            missing = $missing
            dockerReady = $true
            rancherDesktopInstalled = $rancherInstalled
            dockerDesktopInstalled = $dockerDesktopInstalled
        }
    }

    Add-MissingItem -List ([ref]$missing) -Value "docker_runtime"
    return @{
        missing = $missing
        dockerReady = $false
        rancherDesktopInstalled = $rancherInstalled
        dockerDesktopInstalled = $dockerDesktopInstalled
    }
}

function Show-LocalMissingSummary {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$Missing
    )

    Write-Host ""
    Write-Host "正式本地开发模式缺少以下依赖：" -ForegroundColor Yellow
    foreach ($item in $Missing) {
        Write-Host " - $item" -ForegroundColor Yellow
    }
}

function Show-DockerMissingSummary {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$Missing
    )

    Write-Host ""
    Write-Host "正式骨架模式缺少以下依赖：" -ForegroundColor Yellow
    foreach ($item in $Missing) {
        Write-Host " - $item" -ForegroundColor Yellow
    }
}

if (!(Test-Path ".env")) {
    Copy-Item ".env.example" ".env"
    Write-Host "已根据 .env.example 创建 .env"
}

if ($Mode -eq "local") {
    Write-Host "检测正式本地开发模式依赖..."
    $result = Test-LocalModePrerequisites
    $missing = $result.missing

    if ($missing.Count -gt 0) {
        Show-LocalMissingSummary -Missing $missing
        Write-Host "开始统一安装缺少的本地工具链..." -ForegroundColor Yellow
        $toolchainFailed = Try-InstallMissingToolchain -Missing $missing

        if ($toolchainFailed.Count -gt 0) {
            $retryWithProxy = Prompt-ProxyIfNeeded
            if ($retryWithProxy) {
                Write-Host "代理已设置，重新统一安装缺少的本地工具链..." -ForegroundColor Green
                $toolchainFailed = Try-InstallMissingToolchain -Missing $missing
            }
        }

        $result = Test-LocalModePrerequisites
        $missing = $result.missing
        if ($missing.Count -gt 0) {
            Show-LocalMissingSummary -Missing $missing
            if ($missing -contains "go") {
                Show-GoInstallGuide
            }
            if ($missing -contains "node_npm") {
                Show-NodeInstallGuide
            }
            if ($missing -contains "python_runtime" -or $missing -contains "python_pip") {
                Show-PythonInstallGuide
            }
            exit 1
        }
    }

    $python = $result.python
    $go = $result.go
    $npm = $result.npm

    Write-Host "依赖检测通过，开始统一安装代码依赖..."
    $pythonInstalled = Try-InstallPythonDeps -PythonExe $python
    $nodeInstalled = Try-InstallNodeDeps -NpmExe $npm
    $goInstalled = Try-InstallGoDeps -GoExe $go

    if (-not ($pythonInstalled -and $nodeInstalled -and $goInstalled)) {
        $retryWithProxy = Prompt-ProxyIfNeeded
        if ($retryWithProxy) {
            Write-Host "代理已设置，重新统一安装代码依赖..." -ForegroundColor Green
            $pythonInstalled = Try-InstallPythonDeps -PythonExe $python
            $nodeInstalled = Try-InstallNodeDeps -NpmExe $npm
            $goInstalled = Try-InstallGoDeps -GoExe $go
        }
    }

    if (-not $pythonInstalled) {
        Show-PythonInstallGuide
        exit 1
    }

    if (-not $nodeInstalled) {
        Show-NodeInstallGuide
        exit 1
    }

    if (-not $goInstalled) {
        Show-GoInstallGuide
        exit 1
    }

    Write-Host "本地工具链和代码依赖安装已完成。" -ForegroundColor Green
    Write-Host "当前仓库的正式本地开发模式尚未完全接通自动启动链。" -ForegroundColor Yellow
    Write-Host "现阶段已完成如下准备：" -ForegroundColor Yellow
    Write-Host "1. Go 工具链已检测/安装并执行 go mod download" -ForegroundColor Cyan
    Write-Host "2. Admin Web 已执行 npm install" -ForegroundColor Cyan
    Write-Host "3. Python 服务已统一执行 requirements 安装" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "后续将把正式本地开发模式补成自动启动 Go + Python + Node 服务。" -ForegroundColor Yellow
    exit 0
}

Write-Host "检测正式骨架模式依赖..."
$dockerResult = Test-DockerModePrerequisites
$dockerMissing = $dockerResult.missing

if ($dockerMissing.Count -gt 0) {
    Show-DockerMissingSummary -Missing $dockerMissing
    if ($dockerMissing -contains "docker") {
        Write-Host "开始统一安装缺少的 docker..." -ForegroundColor Yellow
        $installed = Try-InstallDocker
        if (-not $installed) {
            $retryWithProxy = Prompt-ProxyIfNeeded
            if ($retryWithProxy) {
                Write-Host "代理已设置，重新安装 docker..." -ForegroundColor Green
                $installed = Try-InstallDocker
            }
        }
        if (-not $installed) {
            Show-DockerInstallGuide
            exit 1
        }
    }
}

$dockerResult = Test-DockerModePrerequisites
if (-not $dockerResult.dockerReady) {
    if ($dockerResult.missing -contains "docker_runtime") {
        $started = $false
        if ($dockerResult.rancherDesktopInstalled) {
            $started = Try-StartRancherDesktop
            if ($started) {
                Write-Host "等待 Rancher Desktop 初始化..." -ForegroundColor Yellow
                if (Wait-DockerDaemonReady -TimeoutSeconds 90) {
                    $dockerResult = Test-DockerModePrerequisites
                }
            }
        }

        if ((-not $dockerResult.dockerReady) -and $dockerResult.dockerDesktopInstalled) {
            $started = Try-StartDockerDesktop
            if ($started) {
                Write-Host "等待 Docker Desktop 初始化..." -ForegroundColor Yellow
                if (Wait-DockerDaemonReady -TimeoutSeconds 90) {
                    $dockerResult = Test-DockerModePrerequisites
                }
            }
        }

        if (-not $dockerResult.dockerReady) {
            Write-Host "docker 命令存在，但当前 daemon 不可用。" -ForegroundColor Yellow
            if ($dockerResult.rancherDesktopInstalled) {
                Show-RancherDesktopStartGuide
            } elseif ($dockerResult.dockerDesktopInstalled) {
                Show-DockerDesktopStartGuide
            } else {
                Show-DockerInstallGuide
            }
            if (-not [string]::IsNullOrWhiteSpace($script:LastInstallError)) {
                Write-Host ""
                Write-Host "最近一次自动启动容器运行时的错误：" -ForegroundColor Yellow
                Write-Host $script:LastInstallError -ForegroundColor DarkYellow
            }
            exit 1
        }
    }

    if (-not $dockerResult.dockerReady) {
        Show-DockerInstallGuide
        exit 1
    }
}

Write-Host "检测到可用的 docker，进入正式骨架模式..."
docker compose up --build
