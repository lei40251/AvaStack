<#
.SYNOPSIS
    AvaStack 数字人平台 — 统一启动与环境检查脚本

.DESCRIPTION
    本脚本负责在 Windows 环境下统一检查并启动 AvaStack 数字人平台。
    支持两种运行模式：

    - docker（默认）：通过 Docker Compose 拉取/构建镜像并启动所有服务容器。
      脚本会在 compose up 之前先执行 compose build，把"镜像拉取失败"、"容器内
      依赖下载失败"、"端口冲突"三类问题分开暴露，方便快速定位。

    - local：一次性检查本地开发所需的全部工具链（Python、Go、Node.js、npm），
      把缺失项和安装指引同时列出，避免修完一个依赖后重复运行脚本才暴露下一个缺失项。
      本地模式下脚本不会自动启动各服务，只负责输出环境报告和依赖安装指引。

    脚本内置了代理支持：当网络受限时，可通过 -Proxy 参数显式传入代理地址，
    也可复用当前 PowerShell 会话中已设置的环境变量（HTTP_PROXY / HTTPS_PROXY）。
    对于 Docker 模式，脚本会自动将 localhost/127.0.0.1 替换为 host.docker.internal，
    因为 Docker 容器内的 127.0.0.1 指向容器自身而非宿主机。

    端口管理方面，脚本默认使用 5xxxx 端口段映射到宿主机，以避开常见系统端口占用；
    容器内部则保持服务原生端口不变，避免打乱服务发现和健康检查配置。
    启动前会自动检测宿主机端口是否已被占用，提前拦截冲突。

.PARAMETER Mode
    运行模式。可选值：docker（默认）或 local。
    - docker：检查 Docker CLI / Compose / daemon 状态，然后启动所有容器。
    - local：检查 Python / Go / Node.js / npm 等本地工具链版本。

.PARAMETER Proxy
    代理地址，格式如 http://<主机>:<端口>。
    在 Docker 模式下，此代理会通过 --build-arg 注入到容器构建阶段，
    供容器内的 pip / npm / go 等包管理器使用。
    注意：基础镜像拉取（FROM 指令）走的是 Docker daemon 自身的代理设置，
    需要在 Docker Desktop 的 Settings → Proxies 里单独配置。

.EXAMPLE
    ./start.ps1
    以默认 docker 模式启动，自动检查 Docker 环境并启动所有服务。

.EXAMPLE
    ./start.ps1 -Mode local
    以本地开发模式运行，检查本地工具链是否满足版本要求。

.EXAMPLE
    ./start.ps1 -Mode docker -Proxy "http://127.0.0.1:7890"
    通过代理启动 Docker 模式，脚本会自动将 127.0.0.1 改写为 host.docker.internal。

.NOTES
    - 本脚本需要 PowerShell 5.1+ 或 PowerShell 7+。
    - Docker 模式启动前会自动从 .env.example 创建 .env（如果不存在）。
    - 所有环境变量的优先级：当前 PowerShell 会话 > .env 文件 > 默认值。
#>

param(
    # 运行模式：docker（Docker Compose 容器化运行）或 local（本地工具链检查）
    [ValidateSet("docker", "local")]
    [string]$Mode = "docker",

    # 代理地址，用于容器构建阶段下载依赖（pip/npm/go）
    [string]$Proxy = ""
)

# 遇到任何错误立即终止脚本执行，避免在异常状态下继续运行导致更难排查的副作用。
$ErrorActionPreference = "Stop"

# ════════════════════════════════════════════════════════════════════════════
# 统一维护本仓库对本地工具链的最低版本要求，避免版本要求散落在各处。
# 后续新增或调整版本要求时，只需修改此表即可，所有检查逻辑会自动跟随。
# ════════════════════════════════════════════════════════════════════════════
$script:RequiredVersionMap = @{
    Python = [Version]"3.11.0"   # ASR/TTS/Avatar/LLM 等 Python 微服务的最低版本
    Go     = [Version]"1.22.0"   # orchestrator-go 编排器的最低版本
    Node   = [Version]"20.0.0"   # admin-web 管理后台的最低 LTS 版本
}

# ════════════════════════════════════════════════════════════════════════════
# 基础工具函数
# 这些函数是后续所有检查和启动逻辑的构建块，每个函数职责单一、无副作用，
# 方便单独测试和复用。
# ════════════════════════════════════════════════════════════════════════════

<#
.SYNOPSIS
    检查某个命令是否在系统 PATH 中可用。

.DESCRIPTION
    使用 Get-Command 判断指定名称的可执行文件是否存在于 PATH 中。
    这是所有工具链检查的基石——先判断"有没有"，再判断"版本够不够"。

.PARAMETER Name
    要检查的命令名称，如 "python"、"go"、"docker"。

.OUTPUTS
    System.Boolean — 命令存在返回 $true，否则返回 $false。
#>
function Test-CommandExists {
    param([Parameter(Mandatory = $true)][string]$Name)
    return $null -ne (Get-Command $Name -ErrorAction SilentlyContinue)
}

<#
.SYNOPSIS
    从候选命令名列表中解析出第一个可用的可执行文件路径。

.DESCRIPTION
    按顺序尝试 $Candidates 中的每个命令名，返回第一个匹配的可执行文件路径。
    例如在 Python 检测中，候选顺序为 "python" → "py"，
    优先使用 python 命令，如果找不到则回退到 Python Launcher (py.exe)。

.PARAMETER Candidates
    候选命令名数组，按优先级从高到低排列。

.OUTPUTS
    System.String — 找到的可执行文件完整路径；如果都未找到则返回 $null。
#>
function Resolve-CommandPath {
    param([Parameter(Mandatory = $true)][string[]]$Candidates)

    foreach ($candidate in $Candidates) {
        $command = Get-Command $candidate -ErrorAction SilentlyContinue
        if ($null -ne $command) {
            return $command.Source
        }
    }

    return $null
}

<#
.SYNOPSIS
    比较两个版本号，判断当前版本是否 >= 最低要求版本。

.DESCRIPTION
    安全的版本比较函数：当任意参数为 $null 时返回 $false，
    避免因空值导致比较异常，简化上层调用方的空值判断逻辑。

.PARAMETER CurrentVersion
    当前安装的版本号，可能为 $null（表示无法识别版本）。

.PARAMETER MinimumVersion
    最低要求的版本号，来自 $script:RequiredVersionMap。

.OUTPUTS
    System.Boolean — 当前版本满足最低要求返回 $true。
#>
function Test-VersionAtLeast {
    param(
        [AllowNull()][Version]$CurrentVersion,
        [AllowNull()][Version]$MinimumVersion
    )

    if ($null -eq $CurrentVersion -or $null -eq $MinimumVersion) {
        return $false
    }

    return $CurrentVersion -ge $MinimumVersion
}

<#
.SYNOPSIS
    将文本转换为 System.Version 对象，用于版本比较。

.DESCRIPTION
    对 [Version] 类型转换的容错封装：当输入为空或格式非法时返回 $null，
    避免异常中断上层检查流程。这样即使工具输出了非预期的版本字符串，
    脚本也不会崩溃，而是将其归类为"无法识别版本"。

.PARAMETER Text
    待转换的版本号文本，如 "3.11.5"。

.OUTPUTS
    System.Version — 转换成功返回对应对象，失败返回 $null。
#>
function ConvertTo-Version {
    param([string]$Text)

    if ([string]::IsNullOrWhiteSpace($Text)) {
        return $null
    }

    try {
        return [Version]$Text
    }
    catch {
        return $null
    }
}

<#
.SYNOPSIS
    执行一个命令并捕获其标准输出文本（忽略标准错误）。

.DESCRIPTION
    用于获取工具版本信息等场景：执行命令，将 stderr 重定向到 $null，
    只保留 stdout 并返回去除首尾空白后的文本。
    典型用法：python --version、go version、docker compose version。

.PARAMETER FilePath
    可执行文件的路径。

.PARAMETER Arguments
    传递给可执行文件的参数数组，默认为空。

.OUTPUTS
    System.String — 命令的标准输出文本（已 trim）；如果执行失败则返回空字符串。
#>
function Get-CommandOutputText {
    param(
        [Parameter(Mandatory = $true)][string]$FilePath,
        [string[]]$Arguments = @()
    )

    try {
        $output = & $FilePath @Arguments 2>$null | Out-String
        return $output.Trim()
    }
    catch {
        return ""
    }
}

<#
.SYNOPSIS
    执行命令并将输出实时打印到控制台，同时收集所有输出行。

.DESCRIPTION
    与 Get-CommandOutputText 不同，本函数在捕获输出的同时还会实时 Write-Host
    到控制台，非常适合 docker compose build 这种耗时较长、需要用户看到进度的场景。
    它同时收集 stdout 和 stderr（通过 2>&1），确保错误信息也能被展示和记录。

.PARAMETER FilePath
    可执行文件路径。

.PARAMETER Arguments
    参数数组。

.OUTPUTS
    Hashtable，包含两个键：
    - ExitCode (int)：进程退出码。
    - Output (string[])：所有输出行组成的字符串数组。
#>
function Invoke-CommandWithLiveOutput {
    param(
        [Parameter(Mandatory = $true)][string]$FilePath,
        [string[]]$Arguments = @()
    )

    $lines = New-Object System.Collections.Generic.List[string]
    & $FilePath @Arguments 2>&1 | ForEach-Object {
        $line = $_.ToString()
        $lines.Add($line)
        Write-Host $line
    }

    return @{
        ExitCode = $LASTEXITCODE
        Output   = $lines.ToArray()
    }
}

<#
.SYNOPSIS
    从文本中按正则表达式提取版本号。

.DESCRIPTION
    用指定的正则模式从命令输出文本中匹配版本号（取第一个捕获组），
    并转换为 Version 对象。这是将原始命令输出转成可比较结构化数据的桥梁。
    例如：从 "Python 3.11.5" 中用模式 '(\d+\.\d+\.\d+)' 提取出 "3.11.5"。

.PARAMETER Text
    命令输出的原始文本。

.PARAMETER Pattern
    包含一个捕获组的正则表达式，用于提取版本号。

.OUTPUTS
    System.Version — 提取成功返回对应对象，失败返回 $null。
#>
function Get-VersionFromText {
    param(
        [string]$Text,
        [string]$Pattern
    )

    if ([string]::IsNullOrWhiteSpace($Text)) {
        return $null
    }

    $match = [regex]::Match($Text, $Pattern)
    if (!$match.Success) {
        return $null
    }

    return ConvertTo-Version -Text $match.Groups[1].Value
}

<#
.SYNOPSIS
    创建一条标准化的检查结果记录。

.DESCRIPTION
    将所有环境检查结果统一封装为 PSCustomObject，确保后续的表格输出和
    安装指引逻辑都能用统一的数据结构消费，减少字段拼写不一致的问题。

.PARAMETER Id
    检查项的唯一标识，如 "python"、"go"、"docker"。
    用于 switch 语句中匹配对应的安装指引函数。

.PARAMETER Component
    组件显示名称，如 "Python"、"Docker CLI"。

.PARAMETER Requirement
    版本或可用性要求描述，如 ">= 3.11"、"可用"。

.PARAMETER CurrentStatus
    当前环境的实际状态描述。

.PARAMETER Result
    检查结论：通过 / 缺少 / 版本偏低 / 未就绪 / 无法识别版本。

.PARAMETER Passed
    是否通过检查。

.PARAMETER InstallHint
    未通过时的简短安装/修复提示，用于输出安装指引。

.OUTPUTS
    PSCustomObject — 标准化检查行对象。
#>
function New-CheckRow {
    param(
        [Parameter(Mandatory = $true)][string]$Id,
        [Parameter(Mandatory = $true)][string]$Component,
        [Parameter(Mandatory = $true)][string]$Requirement,
        [Parameter(Mandatory = $true)][string]$CurrentStatus,
        [Parameter(Mandatory = $true)][string]$Result,
        [Parameter(Mandatory = $true)][bool]$Passed,
        [string]$InstallHint = ""
    )

    return [PSCustomObject]@{
        Id          = $Id
        Component   = $Component
        Requirement = $Requirement
        Current     = $CurrentStatus
        Result      = $Result
        Passed      = $Passed
        InstallHint = $InstallHint
    }
}

<#
.SYNOPSIS
    检测 Python 运行时可执行文件及其调用方式。

.DESCRIPTION
    按以下优先级查找 Python 运行时：
    1. Codex 内置 Python（路径固定在 %USERPROFILE%\.cache\codex-runtimes\...）
    2. 系统 PATH 中的 python 命令
    3. Python Launcher (py.exe)

    这一步非常关键：如果用户系统只装了 py.exe 而没有配置 python 命令，
    我们的后续调用都需要通过 py -3 来执行，不能用单纯的 python。
    所以这里返回的信息里包含了 InvokeArgs，上层统一用 FilePath + InvokeArgs 调用，
    不必关心底层到底是 python 还是 py -3。

.OUTPUTS
    Hashtable 或 $null：
    - Path (string)：可执行文件路径
    - InvokeArgs (string[])：额外参数（如 py -3 的 "-3"）
    - Display (string)：用于展示给用户的调用方式文本
    - Source (string)：运行时来源描述（Codex 内置 / 系统 PATH / Python Launcher）
#>
function Get-PythonRuntimeInfo {
    # 优先检测 Codex 内置 Python——它是 Codex 安装时自带的隔离运行时，
    # 不会与系统 Python 冲突，优先级最高。
    $bundledPython = Join-Path $env:USERPROFILE ".cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe"
    if (Test-Path $bundledPython) {
        return @{
            Path       = $bundledPython
            InvokeArgs = @()
            Display    = "python"
            Source     = "Codex 内置 Python"
        }
    }

    # 其次尝试系统 PATH 中的 python
    $pythonPath = Resolve-CommandPath -Candidates @("python")
    if ($pythonPath) {
        return @{
            Path       = $pythonPath
            InvokeArgs = @()
            Display    = "python"
            Source     = "系统 PATH"
        }
    }

    # 最后尝试 Python Launcher (py.exe)——Windows 上常见的 Python 启动器
    $pyLauncherPath = Resolve-CommandPath -Candidates @("py")
    if ($pyLauncherPath) {
        return @{
            Path       = $pyLauncherPath
            InvokeArgs = @("-3")        # -3 确保使用 Python 3.x 而非 2.x
            Display    = "py -3"
            Source     = "Python Launcher"
        }
    }

    return $null
}

# ════════════════════════════════════════════════════════════════════════════
# Docker / 桌面端路径检测
# 针对 Windows 上两种主流 Docker 桌面端（Rancher Desktop 和 Docker Desktop）
# 的安装路径检测。两者安装路径不同，需要分别探测。
# ════════════════════════════════════════════════════════════════════════════

<#
.SYNOPSIS
    检测 Rancher Desktop 的安装路径。

.DESCRIPTION
    遍历 Rancher Desktop 可能的安装位置（Program Files 和 LocalAppData），
    返回第一个存在的可执行文件路径。Rancher Desktop 是推荐的 Docker 桌面端，
    因为它开源、轻量，且不限制商业使用。

.OUTPUTS
    System.String — 找到的 .exe 路径；未找到返回 $null。
#>
function Get-RancherDesktopExePath {
    foreach ($path in @(
        "C:\Program Files\Rancher Desktop\Rancher Desktop.exe",
        "$env:LOCALAPPDATA\Programs\Rancher Desktop\Rancher Desktop.exe"
    )) {
        if (Test-Path $path) {
            return $path
        }
    }

    return $null
}

<#
.SYNOPSIS
    检测 Docker Desktop 的安装路径。

.DESCRIPTION
    遍历 Docker Desktop 可能的安装位置（Program Files 和 LocalAppData），
    返回第一个存在的可执行文件路径。

.OUTPUTS
    System.String — 找到的 .exe 路径；未找到返回 $null。
#>
function Get-DockerDesktopExePath {
    foreach ($path in @(
        "C:\Program Files\Docker\Docker\Docker Desktop.exe",
        "$env:LOCALAPPDATA\Docker\Docker\Docker Desktop.exe"
    )) {
        if (Test-Path $path) {
            return $path
        }
    }

    return $null
}

<#
.SYNOPSIS
    检查 Docker daemon 是否正在运行且可正常连接。

.DESCRIPTION
    执行 docker info 并检查退出码。
    即使 Docker CLI 已安装，daemon（dockerd）也可能未启动。
    这个检查对于区分"已安装但没启动"和"未安装"两种情况至关重要。

.OUTPUTS
    System.Boolean — daemon 可连接返回 $true。
#>
function Test-DockerDaemonReady {
    if (!(Test-CommandExists "docker")) {
        return $false
    }

    & docker info *> $null
    return $LASTEXITCODE -eq 0
}

<#
.SYNOPSIS
    检查 docker compose 子命令是否可用。

.DESCRIPTION
    执行 docker compose version 检查 Compose 插件是否已随 Docker CLI 安装。
    注意：这里检查的是 docker compose（Docker 内置插件），而非旧版独立的 docker-compose。

.OUTPUTS
    System.Boolean — Compose 可用返回 $true。
#>
function Test-DockerComposeReady {
    if (!(Test-CommandExists "docker")) {
        return $false
    }

    & docker compose version *> $null
    return $LASTEXITCODE -eq 0
}

# ════════════════════════════════════════════════════════════════════════════
# 环境检查
# 将 local 和 docker 两种模式的环境检查逻辑集中在这里。
# 设计原则：一次性检查所有依赖项，统一输出结果。
# 这样用户修完一个依赖后不需要重复运行脚本才暴露下一个缺失项。
# ════════════════════════════════════════════════════════════════════════════

<#
.SYNOPSIS
    一次性检查本地开发模式所需的整套工具链。

.DESCRIPTION
    按顺序检查 Python → pip → Go → Node.js → npm，全部扫完后再统一输出。
    每个工具的检查逻辑包括：
    1. 可执行文件是否存在（通过 PATH 查找）
    2. 能否正常执行（获取版本信息）
    3. 版本号是否满足最低要求

    特别注意 Python 与 pip 的关联：如果 Python 没检测到，pip 直接标记为
    "未检测到 Python，无法检查"，而不是独立报错。

    返回的 Hashtable 包含所有行数据、整体就绪状态，以及各工具路径信息，
    供后续输出表格和安装指引使用。

.OUTPUTS
    Hashtable：
    - Rows (PSCustomObject[])：所有检查行
    - IsReady (bool)：是否全部通过
    - PythonRuntime (Hashtable or $null)：Python 运行时信息
    - GoPath (string or $null)：Go 可执行文件路径
    - NodePath (string or $null)：Node.js 可执行文件路径
    - NpmPath (string or $null)：npm 可执行文件路径
#>
function Test-LocalPrerequisites {
    $rows = @()
    $pythonRuntime = Get-PythonRuntimeInfo

    # ── Python 与 pip ────────────────────────────────────────────────
    # Python 和 pip 需要共用同一套调用方式（FilePath + InvokeArgs），
    # 否则在 py.exe 场景下容易误判——用 python 命令检查成功但实际
    # 依赖安装时需要 py -3，导致后续步骤失败。
    if ($null -eq $pythonRuntime) {
        # Python 未检测到 → 同时标记 Python 和 pip 为缺少
        $rows += New-CheckRow `
            -Id "python" `
            -Component "Python" `
            -Requirement ">= 3.11" `
            -CurrentStatus "未检测到" `
            -Result "缺少" `
            -Passed $false `
            -InstallHint "先安装 Python 3.11+，建议使用官网安装包或 winget。"

        $rows += New-CheckRow `
            -Id "pip" `
            -Component "pip" `
            -Requirement "可用" `
            -CurrentStatus "未检测到 Python，无法检查" `
            -Result "缺少" `
            -Passed $false `
            -InstallHint "安装 Python 时勾选 pip 组件；如已安装 Python，可执行 python -m ensurepip --upgrade。"
    }
    else {
        # 检查 Python 版本
        $pythonVersionText = Get-CommandOutputText -FilePath $pythonRuntime.Path -Arguments ($pythonRuntime.InvokeArgs + @("--version"))
        $pythonVersion = Get-VersionFromText -Text $pythonVersionText -Pattern '(\d+\.\d+\.\d+)'
        $pythonPassed = Test-VersionAtLeast -CurrentVersion $pythonVersion -MinimumVersion $script:RequiredVersionMap.Python
        $pythonResult = if ($pythonPassed) { "通过" } elseif ($null -eq $pythonVersion) { "无法识别版本" } else { "版本偏低" }
        $pythonCurrent = if ($pythonVersionText) {
            "$pythonVersionText（$($pythonRuntime.Source)）"
        }
        else {
            "已检测到可执行文件：$($pythonRuntime.Path)"
        }

        $rows += New-CheckRow `
            -Id "python" `
            -Component "Python" `
            -Requirement ">= 3.11" `
            -CurrentStatus $pythonCurrent `
            -Result $pythonResult `
            -Passed $pythonPassed `
            -InstallHint "升级到 Python 3.11+；安装时勾选 Add Python to PATH。"

        # 通过 Python 运行时检查 pip（确保使用同一个 Python 的 pip）
        $pipVersionText = Get-CommandOutputText -FilePath $pythonRuntime.Path -Arguments ($pythonRuntime.InvokeArgs + @("-m", "pip", "--version"))
        $pipVersion = Get-VersionFromText -Text $pipVersionText -Pattern 'pip\s+(\d+\.\d+(?:\.\d+)?)'
        $pipPassed = -not [string]::IsNullOrWhiteSpace($pipVersionText)
        $pipCurrent = if ($pipVersionText) { $pipVersionText } else { "不可用" }
        $pipResult = if ($pipPassed) { "通过" } else { "缺少" }

        $rows += New-CheckRow `
            -Id "pip" `
            -Component "pip" `
            -Requirement "可用" `
            -CurrentStatus $pipCurrent `
            -Result $pipResult `
            -Passed $pipPassed `
            -InstallHint "执行 python -m ensurepip --upgrade；如果失败，重新安装 Python 并勾选 pip。"
    }

    # ── Go ────────────────────────────────────────────────────────────
    $goPath = Resolve-CommandPath -Candidates @("go")
    if ($goPath) {
        $goVersionText = Get-CommandOutputText -FilePath $goPath -Arguments @("version")
        # Go 的版本输出格式如 "go version go1.22.5 windows/amd64"
        $goVersion = Get-VersionFromText -Text $goVersionText -Pattern 'go(\d+\.\d+(?:\.\d+)?)'
        $goPassed = Test-VersionAtLeast -CurrentVersion $goVersion -MinimumVersion $script:RequiredVersionMap.Go
        $goResult = if ($goPassed) { "通过" } elseif ($null -eq $goVersion) { "无法识别版本" } else { "版本偏低" }

        $rows += New-CheckRow `
            -Id "go" `
            -Component "Go" `
            -Requirement ">= 1.22" `
            -CurrentStatus $(if ($goVersionText) { $goVersionText } else { "已检测到可执行文件：$goPath" }) `
            -Result $goResult `
            -Passed $goPassed `
            -InstallHint "升级到 Go 1.22+。"
    }
    else {
        $rows += New-CheckRow `
            -Id "go" `
            -Component "Go" `
            -Requirement ">= 1.22" `
            -CurrentStatus "未检测到" `
            -Result "缺少" `
            -Passed $false `
            -InstallHint "安装 Go 1.22+。"
    }

    # ── Node.js ───────────────────────────────────────────────────────
    $nodePath = Resolve-CommandPath -Candidates @("node")
    if ($nodePath) {
        $nodeVersionText = Get-CommandOutputText -FilePath $nodePath -Arguments @("--version")
        # Node.js 版本输出格式如 "v20.11.0"
        $nodeVersion = Get-VersionFromText -Text $nodeVersionText -Pattern 'v(\d+\.\d+\.\d+)'
        $nodePassed = Test-VersionAtLeast -CurrentVersion $nodeVersion -MinimumVersion $script:RequiredVersionMap.Node
        $nodeResult = if ($nodePassed) { "通过" } elseif ($null -eq $nodeVersion) { "无法识别版本" } else { "版本偏低" }

        $rows += New-CheckRow `
            -Id "nodejs" `
            -Component "Node.js" `
            -Requirement ">= 20" `
            -CurrentStatus $(if ($nodeVersionText) { $nodeVersionText } else { "已检测到可执行文件：$nodePath" }) `
            -Result $nodeResult `
            -Passed $nodePassed `
            -InstallHint "升级到 Node.js 20+ LTS。"
    }
    else {
        $rows += New-CheckRow `
            -Id "nodejs" `
            -Component "Node.js" `
            -Requirement ">= 20" `
            -CurrentStatus "未检测到" `
            -Result "缺少" `
            -Passed $false `
            -InstallHint "安装 Node.js 20+ LTS。"
    }

    # ── npm ───────────────────────────────────────────────────────────
    # npm 通常随 Node.js 一起安装，但这里做独立检查以防极端情况
    $npmPath = Resolve-CommandPath -Candidates @("npm.cmd", "npm")
    if ($npmPath) {
        $npmVersionText = Get-CommandOutputText -FilePath $npmPath -Arguments @("--version")
        $npmPassed = -not [string]::IsNullOrWhiteSpace($npmVersionText)
        $npmResult = if ($npmPassed) { "通过" } else { "不可用" }

        $rows += New-CheckRow `
            -Id "npm" `
            -Component "npm" `
            -Requirement "可用" `
            -CurrentStatus $(if ($npmVersionText) { "npm $npmVersionText" } else { "已检测到可执行文件但无法执行：$npmPath" }) `
            -Result $npmResult `
            -Passed $npmPassed `
            -InstallHint "通常随 Node.js 一起安装；如不可用，请重新安装 Node.js LTS。"
    }
    else {
        $rows += New-CheckRow `
            -Id "npm" `
            -Component "npm" `
            -Requirement "可用" `
            -CurrentStatus "未检测到" `
            -Result "缺少" `
            -Passed $false `
            -InstallHint "安装 Node.js 后会自动带上 npm。"
    }

    return @{
        Rows          = $rows
        IsReady       = (($rows | Where-Object { -not $_.Passed }).Count -eq 0)
        PythonRuntime = $pythonRuntime
        GoPath        = $goPath
        NodePath      = $nodePath
        NpmPath       = $npmPath
    }
}

<#
.SYNOPSIS
    一次性检查 Docker 运行模式所需的完整 Docker 环境。

.DESCRIPTION
    区分三层状态分别检查：
    1. Docker CLI 是否存在（docker 命令）
    2. Docker Compose 是否可用（docker compose 子命令）
    3. Docker daemon 是否正在运行且可连接（docker info）

    分层检查的好处是能把"未安装 Docker 桌面端"和
    "已安装但桌面端没启动"分开提示，排障更直接。

    同时会探测已安装的桌面端类型（Rancher Desktop / Docker Desktop），
    用于后续生成更有针对性的启动提示。

.OUTPUTS
    Hashtable：
    - Rows (PSCustomObject[])：所有检查行
    - DockerReady (bool)：是否全部通过
    - HasRancher (bool)：是否安装了 Rancher Desktop
    - HasDockerDesktop (bool)：是否安装了 Docker Desktop
#>
function Test-DockerPrerequisites {
    $rows = @()
    $dockerPath = Resolve-CommandPath -Candidates @("docker")
    $hasRancher = $null -ne (Get-RancherDesktopExePath)
    $hasDockerDesktop = $null -ne (Get-DockerDesktopExePath)

    if ($dockerPath) {
        # ── Docker CLI 存在时的检查路径 ──
        $dockerVersionText = Get-CommandOutputText -FilePath $dockerPath -Arguments @("--version")
        $rows += New-CheckRow `
            -Id "docker" `
            -Component "Docker CLI" `
            -Requirement "可用" `
            -CurrentStatus $(if ($dockerVersionText) { $dockerVersionText } else { "已检测到可执行文件：$dockerPath" }) `
            -Result "通过" `
            -Passed $true `
            -InstallHint "推荐安装 Rancher Desktop 或 Docker Desktop。"

        # Docker Compose 检查
        $composeReady = Test-DockerComposeReady
        $composeVersionText = if ($composeReady) { Get-CommandOutputText -FilePath $dockerPath -Arguments @("compose", "version") } else { "不可用" }
        $rows += New-CheckRow `
            -Id "docker_compose" `
            -Component "Docker Compose" `
            -Requirement "docker compose 可用" `
            -CurrentStatus $composeVersionText `
            -Result $(if ($composeReady) { "通过" } else { "缺少" }) `
            -Passed $composeReady `
            -InstallHint "优先安装 Rancher Desktop 或 Docker Desktop，它们会一起提供 docker compose。"

        # Docker daemon 检查——这是"能不能真正用"的最后一道关卡
        $daemonReady = Test-DockerDaemonReady
        # 根据已安装的桌面端类型生成更准确的当前状态描述
        $daemonCurrent = if ($daemonReady) {
            "可连接"
        }
        elseif ($hasRancher) {
            "已安装 Rancher Desktop，但 daemon 未就绪"
        }
        elseif ($hasDockerDesktop) {
            "已安装 Docker Desktop，但 daemon 未就绪"
        }
        else {
            "docker 命令存在，但 daemon 未就绪"
        }

        $rows += New-CheckRow `
            -Id "docker_daemon" `
            -Component "Docker daemon" `
            -Requirement "docker info 可连接" `
            -CurrentStatus $daemonCurrent `
            -Result $(if ($daemonReady) { "通过" } else { "未就绪" }) `
            -Passed $daemonReady `
            -InstallHint "启动 Rancher Desktop / Docker Desktop，并确认容器引擎已经 Running。"
    }
    else {
        # ── Docker CLI 未检测到——三项全部标记为缺少 ──
        $rows += New-CheckRow `
            -Id "docker" `
            -Component "Docker CLI" `
            -Requirement "可用" `
            -CurrentStatus "未检测到" `
            -Result "缺少" `
            -Passed $false `
            -InstallHint "安装 Rancher Desktop 或 Docker Desktop。"

        $rows += New-CheckRow `
            -Id "docker_compose" `
            -Component "Docker Compose" `
            -Requirement "docker compose 可用" `
            -CurrentStatus "未检测到 Docker CLI，无法检查" `
            -Result "缺少" `
            -Passed $false `
            -InstallHint "安装 Rancher Desktop 或 Docker Desktop 后会一起提供。"

        $rows += New-CheckRow `
            -Id "docker_daemon" `
            -Component "Docker daemon" `
            -Requirement "docker info 可连接" `
            -CurrentStatus "未检测到 Docker CLI，无法检查" `
            -Result "缺少" `
            -Passed $false `
            -InstallHint "安装并启动 Rancher Desktop 或 Docker Desktop。"
    }

    return @{
        Rows             = $rows
        DockerReady      = (($rows | Where-Object { -not $_.Passed }).Count -eq 0)
        HasRancher       = $hasRancher
        HasDockerDesktop = $hasDockerDesktop
    }
}

# ════════════════════════════════════════════════════════════════════════════
# 输出辅助
# 统一管理所有控制台输出格式，包括区段标题、检查结果表格、代理提醒等。
# 确保不同场景下的输出风格一致，便于用户快速阅读。
# ════════════════════════════════════════════════════════════════════════════

<#
.SYNOPSIS
    输出带装饰的分节标题。

.DESCRIPTION
    用固定风格的装饰线（━━━）和颜色（Cyan/DarkCyan）输出标题，
    保持脚本所有输出的一致性。

.PARAMETER Title
    要显示的标题文本。
#>
function Write-SectionHeader {
    param([Parameter(Mandatory = $true)][string]$Title)

    Write-Host ""
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkCyan
    Write-Host "  $Title" -ForegroundColor Cyan
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkCyan
}

<#
.SYNOPSIS
    以对齐表格形式输出环境检查结果。

.DESCRIPTION
    将 New-CheckRow 生成的检查行数组格式化为四列表格：
    组件 | 要求 | 结果 | 当前状态
    列宽分别为 14、18、10、自适应，确保中文内容也能大致对齐。

.PARAMETER Rows
    检查行对象数组。
#>
function Write-CheckTable {
    param([Parameter(Mandatory = $true)][object[]]$Rows)

    # 各列宽度（字符数），经过实测调整以适配中英文混合内容
    $componentWidth = 14
    $requirementWidth = 18
    $resultWidth = 10

    # 表头和分隔线
    $header = "{0,-$componentWidth} {1,-$requirementWidth} {2,-$resultWidth} {3}" -f "组件", "要求", "结果", "当前状态"
    $separator = "{0,-$componentWidth} {1,-$requirementWidth} {2,-$resultWidth} {3}" -f ("-" * 4), ("-" * 4), ("-" * 4), ("-" * 4)

    Write-Host $header
    Write-Host $separator

    foreach ($row in $Rows) {
        $line = "{0,-$componentWidth} {1,-$requirementWidth} {2,-$resultWidth} {3}" -f `
            $row.Component, `
            $row.Requirement, `
            $row.Result, `
            $row.Current
        Write-Host $line
    }
}

<#
.SYNOPSIS
    获取用于示例展示的代理地址。

.DESCRIPTION
    按优先级返回一个有意义的代理地址示例：
    1. 如果用户已通过 -Proxy 传入代理，返回该地址
    2. 如果当前会话已有代理环境变量，返回检测到的地址
    3. 否则返回占位符模板 "http://<代理主机>:<端口>"

    这样生成的示例地址是用户当前环境上下文的，比硬编码示例更有参考价值。

.OUTPUTS
    System.String — 代理地址示例文本。
#>
function Get-ProxyExampleValue {
    if (![string]::IsNullOrWhiteSpace($Proxy)) {
        return $Proxy
    }

    $currentProxy = Get-CurrentProxyUrl
    if (![string]::IsNullOrWhiteSpace($currentProxy)) {
        return $currentProxy
    }

    return "http://<代理主机>:<端口>"
}

<#
.SYNOPSIS
    输出代理配置提醒。

.DESCRIPTION
    在执行需要下载的操作之前，提醒用户配置代理。
    根据不同场景（docker / local）提供不同的提示信息：
    - docker 模式：提示可通过 -Proxy 参数传入，以及 Docker Desktop 需单独配置
    - local 模式：提示设置环境变量即可

    注意：这里特别区分了"容器内依赖下载代理"和"Docker daemon 基础镜像拉取代理"——
    这是两个不同层面的代理需求，很多用户会混淆。

.PARAMETER Scenario
    场景标识："docker" 或 "local"。
#>
function Write-ProxyReminder {
    param([Parameter(Mandatory = $true)][string]$Scenario)

    $proxyExample = Get-ProxyExampleValue

    Write-Host ""
    Write-Host "下载前代理提醒：" -ForegroundColor Yellow
    Write-Host "  如果你当前网络访问外网较慢或受限，建议先在当前 PowerShell 会话里设置代理，再执行下面需要下载的步骤。" -ForegroundColor DarkYellow
    Write-Host "  `\$env:HTTP_PROXY  = `"$proxyExample`"" -ForegroundColor Cyan
    Write-Host "  `\$env:HTTPS_PROXY = `"$proxyExample`"" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  配置完代理后，直接继续执行下面的命令即可，不需要额外改脚本。" -ForegroundColor DarkGray
    Write-Host "  注意：这个代理主要用于 docker compose build 阶段容器内的 pip / npm / go 下载。" -ForegroundColor DarkGray
    Write-Host "  如果报错发生在 FROM 基础镜像拉取阶段，还需要在 Docker Desktop 里单独配置代理。" -ForegroundColor DarkGray

    if ($Scenario -eq "docker") {
        Write-Host "  Docker 模式也支持直接这样传入代理：" -ForegroundColor DarkGray
        Write-Host "  ./start.ps1 -Mode docker -Proxy `"$proxyExample`"" -ForegroundColor Cyan
    }
}

<#
.SYNOPSIS
    输出"安装完成后重新运行"的提示。

.DESCRIPTION
    在安装指引末尾输出的温馨提示，告诉用户修完依赖后用什么命令重新运行脚本，
    减少用户需要记忆的内容。

.PARAMETER CommandText
    重新运行的命令文本，如 "./start.ps1 -Mode docker"。
#>
function Write-ReRunHint {
    param([Parameter(Mandatory = $true)][string]$CommandText)

    Write-Host ""
    Write-Host "安装完成后可重新执行：" -ForegroundColor Yellow
    Write-Host "  $CommandText" -ForegroundColor Cyan
}

# ════════════════════════════════════════════════════════════════════════════
# 安装指引
# 针对每种可能缺失的工具/组件提供清晰的安装或修复步骤。
# 每个函数对应一种组件，包含官网链接、winget 命令和注意事项。
# ════════════════════════════════════════════════════════════════════════════

<#
.SYNOPSIS
    输出 Python 安装指引。
#>
function Write-InstallGuide-Python {
    Write-Host ""
    Write-Host "Python 安装方式：" -ForegroundColor Green
    Write-Host "  官网： https://www.python.org/downloads/" -ForegroundColor Cyan
    Write-Host "  winget： winget install --id Python.Python.3.11 --source winget" -ForegroundColor Cyan
    Write-Host "  安装时请勾选 Add Python to PATH。" -ForegroundColor DarkGray
}

<#
.SYNOPSIS
    输出 pip 修复指引（Python 已安装但 pip 不可用的情况）。
#>
function Write-InstallGuide-Pip {
    Write-Host ""
    Write-Host "pip 修复方式：" -ForegroundColor Green
    Write-Host "  python -m ensurepip --upgrade" -ForegroundColor Cyan
    Write-Host "  如果仍失败，请重装 Python 并确保包含 pip 组件。" -ForegroundColor DarkGray
}

<#
.SYNOPSIS
    输出 Go 安装指引。
#>
function Write-InstallGuide-Go {
    Write-Host ""
    Write-Host "Go 安装方式：" -ForegroundColor Green
    Write-Host "  官网： https://go.dev/dl/" -ForegroundColor Cyan
    Write-Host "  winget： winget install --id GoLang.Go --source winget" -ForegroundColor Cyan
}

<#
.SYNOPSIS
    输出 Node.js 安装指引（同时覆盖 npm，因为 npm 随 Node.js 安装）。
#>
function Write-InstallGuide-Node {
    Write-Host ""
    Write-Host "Node.js 安装方式：" -ForegroundColor Green
    Write-Host "  官网： https://nodejs.org/" -ForegroundColor Cyan
    Write-Host "  winget： winget install --id OpenJS.NodeJS.LTS --source winget" -ForegroundColor Cyan
}

<#
.SYNOPSIS
    输出 Docker 桌面端安装指引（包含 Rancher Desktop 和 Docker Desktop 两种选择）。

.DESCRIPTION
    推荐 Rancher Desktop 作为首选，因为它开源、轻量且无商业使用限制。
    同时提供 Docker Desktop 作为备选方案。
#>
function Write-InstallGuide-Docker {
    Write-Host ""
    Write-Host "Docker 安装方式（推荐二选一）：" -ForegroundColor Green
    Write-Host "  Rancher Desktop： winget install --id SUSE.RancherDesktop --source winget" -ForegroundColor Cyan
    Write-Host "  Docker Desktop：  winget install --id Docker.DockerDesktop --source winget" -ForegroundColor Cyan
    Write-Host "  Rancher Desktop 安装后请确认容器引擎选择 moby/dockerd。" -ForegroundColor DarkGray
}

<#
.SYNOPSIS
    输出 Docker Compose 修复指引（通常建议重装桌面端）。
#>
function Write-InstallGuide-DockerCompose {
    Write-Host ""
    Write-Host "Docker Compose 处理方式：" -ForegroundColor Green
    Write-Host "  推荐直接安装或重装 Rancher Desktop / Docker Desktop，它们会一起提供 docker compose。" -ForegroundColor DarkGray
}

<#
.SYNOPSIS
    输出 Docker daemon 启动指引。

.DESCRIPTION
    根据不同桌面端类型输出针对性提示：
    - 已安装 Rancher Desktop → 提示打开并等待 Running
    - 已安装 Docker Desktop → 提示打开并等待托盘 Running
    - 都未安装 → 提示先安装

.PARAMETER HasRancher
    是否安装了 Rancher Desktop。

.PARAMETER HasDockerDesktop
    是否安装了 Docker Desktop。
#>
function Write-InstallGuide-DockerDaemon {
    param(
        [Parameter(Mandatory = $true)][bool]$HasRancher,
        [Parameter(Mandatory = $true)][bool]$HasDockerDesktop
    )

    Write-Host ""
    Write-Host "Docker daemon 处理方式：" -ForegroundColor Green

    if ($HasRancher) {
        Write-Host "  已检测到 Rancher Desktop，请打开它并等待状态变为 Running。" -ForegroundColor DarkGray
        Write-Host "  同时确认设置里的容器引擎为 moby/dockerd。" -ForegroundColor DarkGray
    }
    elseif ($HasDockerDesktop) {
        Write-Host "  已检测到 Docker Desktop，请打开它并等待托盘状态显示 Running。" -ForegroundColor DarkGray
    }
    else {
        Write-Host "  当前未检测到可用桌面端，请先安装 Rancher Desktop 或 Docker Desktop。" -ForegroundColor DarkGray
    }

    # 提供统一的验证命令，方便用户自行确认 daemon 已就绪
    Write-Host "  验证命令： docker info" -ForegroundColor Cyan
}

<#
.SYNOPSIS
    输出 Docker Desktop 中配置代理的详细步骤。

.DESCRIPTION
    当基础镜像拉取失败时，用户需要在 Docker Desktop 的 Settings → Proxies 中
    配置代理。本函数输出完整的 GUI 操作步骤。
#>
function Write-DockerDesktopProxyGuide {
    $proxyExample = Get-ProxyExampleValue

    Write-Host ""
    Write-Host "Docker Desktop 代理配置方式：" -ForegroundColor Green
    Write-Host "  1. 打开 Docker Desktop" -ForegroundColor DarkGray
    Write-Host "  2. 进入 Settings" -ForegroundColor DarkGray
    Write-Host "  3. 找到 Proxies（部分版本在 Resources 下）" -ForegroundColor DarkGray
    Write-Host "  4. 在 HTTP Proxy / HTTPS Proxy 中填入你的代理地址，例如 $proxyExample" -ForegroundColor DarkGray
    Write-Host "  5. 点击 Apply & Restart" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "  配完后先验证：" -ForegroundColor Yellow
    Write-Host "    docker info" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  然后重新启动项目：" -ForegroundColor Yellow
    Write-Host "    ./start.ps1 -Mode docker -Proxy `"$proxyExample`"" -ForegroundColor Cyan
}

<#
.SYNOPSIS
    输出项目依赖安装指引（本地开发模式下使用）。

.DESCRIPTION
    列出本地开发模式下各服务的依赖安装命令：
    - Go：go mod download（orchestrator-go）
    - Node.js：npm install（admin-web）
    - Python：pip install -r requirements.txt（各模型微服务）

.PARAMETER PythonCommand
    Python 调用命令文本，如 "python" 或 "py -3"。
#>
function Write-ProjectDependencyGuide {
    param([Parameter(Mandatory = $true)][string]$PythonCommand)

    Write-Host ""
    Write-Host "环境工具就绪后，按下面步骤安装项目依赖：" -ForegroundColor Yellow
    Write-Host "  Go：" -ForegroundColor Green
    Write-Host "    Set-Location services/orchestrator-go" -ForegroundColor Cyan
    Write-Host "    go mod download" -ForegroundColor Cyan
    Write-Host "    Set-Location ../.." -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  Node.js：" -ForegroundColor Green
    Write-Host "    Set-Location services/admin-web" -ForegroundColor Cyan
    Write-Host "    npm install" -ForegroundColor Cyan
    Write-Host "    Set-Location ../.." -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  Python：" -ForegroundColor Green
    Write-Host "    $PythonCommand -m pip install -r services/model-asr-python/requirements.txt" -ForegroundColor Cyan
    Write-Host "    $PythonCommand -m pip install -r services/model-tts-python/requirements.txt" -ForegroundColor Cyan
    Write-Host "    $PythonCommand -m pip install -r services/model-avatar-python/requirements.txt" -ForegroundColor Cyan
    Write-Host "    $PythonCommand -m pip install -r services/model-llm-python/requirements.txt" -ForegroundColor Cyan
}

<#
.SYNOPSIS
    根据检查结果行数组自动输出对应的安装指引。

.DESCRIPTION
    遍历检查行中未通过的项，根据其 Id 字段匹配对应的安装指引函数。
    这样调用方不需要关心具体哪些项未通过——传进来即可自动生成完整指引。

.PARAMETER Rows
    检查行对象数组。

.PARAMETER HasRancher
    是否安装了 Rancher Desktop（用于 Docker daemon 指引的分支逻辑）。

.PARAMETER HasDockerDesktop
    是否安装了 Docker Desktop。
#>
function Write-InstallGuidesFromRows {
    param(
        [Parameter(Mandatory = $true)][object[]]$Rows,
        [bool]$HasRancher = $false,
        [bool]$HasDockerDesktop = $false
    )

    foreach ($row in $Rows | Where-Object { -not $_.Passed }) {
        switch ($row.Id) {
            "python" { Write-InstallGuide-Python }
            "pip" { Write-InstallGuide-Pip }
            "go" { Write-InstallGuide-Go }
            "nodejs" { Write-InstallGuide-Node }
            "npm" { Write-InstallGuide-Node }    # npm 问题统一用 Node.js 重装解决
            "docker" { Write-InstallGuide-Docker }
            "docker_compose" { Write-InstallGuide-DockerCompose }
            "docker_daemon" { Write-InstallGuide-DockerDaemon -HasRancher $HasRancher -HasDockerDesktop $HasDockerDesktop }
        }
    }
}

# ════════════════════════════════════════════════════════════════════════════
# 代理与 Docker 启动
# 管理代理检测、端口检查、宿主机端口冲突预检、Docker build 及 compose up 全流程。
# 这是脚本的核心执行区。
# ════════════════════════════════════════════════════════════════════════════

<#
.SYNOPSIS
    检测当前 PowerShell 会话中已配置的代理 URL。

.DESCRIPTION
    按优先级依次检查 HTTPS_PROXY、HTTP_PROXY、ALL_PROXY（包括大小写变体），
    返回第一个非空值。这是自动发现用户已有代理配置的核心逻辑，
    避免用户在命令行传入 -Proxy 后还要重复设置环境变量。

.OUTPUTS
    System.String — 代理 URL，未配置则返回 $null。
#>
function Get-CurrentProxyUrl {
    foreach ($name in @(
        "HTTPS_PROXY", "HTTP_PROXY", "ALL_PROXY",
        "https_proxy", "http_proxy", "all_proxy"
    )) {
        $value = [Environment]::GetEnvironmentVariable($name)
        if (![string]::IsNullOrWhiteSpace($value)) {
            return $value
        }
    }

    return $null
}

<#
.SYNOPSIS
    从 .env 文件中读取指定键的值。

.DESCRIPTION
    解析仓库根目录的 .env 文件，返回指定键的值。
    自动跳过空行和 # 开头的注释行，支持引号包裹的值。

    注意：.env 文件中的值为最低优先级，当前会话环境变量和脚本默认值优先。

.PARAMETER Name
    要读取的环境变量名。

.OUTPUTS
    System.String — 找到的值，未找到返回 $null。
#>
function Get-DotEnvValue {
    param([Parameter(Mandatory = $true)][string]$Name)

    if (!(Test-Path ".env")) {
        return $null
    }

    foreach ($line in Get-Content -Path ".env") {
        $trimmed = $line.Trim()
        # 跳过空行和注释行
        if ([string]::IsNullOrWhiteSpace($trimmed) -or $trimmed.StartsWith("#")) {
            continue
        }

        if ($trimmed -match "^" + [regex]::Escape($Name) + "=(.*)$") {
            return $matches[1].Trim().Trim("'`"")
        }
    }

    return $null
}

<#
.SYNOPSIS
    获取端口或配置的有效值（多来源优先级合并）。

.DESCRIPTION
    按以下优先级获取配置值：
    1. 当前 PowerShell 会话环境变量（最高优先级）
    2. .env 文件中的值
    3. 脚本内置默认值（最低优先级）

    这样设计是为了让用户可以临时覆盖端口做验证（通过 $env:XXX），
    而不必修改 .env 文件提交到仓库。

.PARAMETER Name
    环境变量名。

.PARAMETER DefaultValue
    默认值（当会话变量和 .env 都未设置时使用）。

.OUTPUTS
    System.String — 最终生效的配置值。
#>
function Get-EffectiveEnvValue {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][string]$DefaultValue
    )

    # 会话环境变量优先级最高
    $processValue = [Environment]::GetEnvironmentVariable($Name)
    if (![string]::IsNullOrWhiteSpace($processValue)) {
        return $processValue
    }

    # 其次检查 .env 文件
    $dotEnvValue = Get-DotEnvValue -Name $Name
    if (![string]::IsNullOrWhiteSpace($dotEnvValue)) {
        return $dotEnvValue
    }

    return $DefaultValue
}

<#
.SYNOPSIS
    在当前 PowerShell 会话中设置代理环境变量。

.DESCRIPTION
    设置 HTTP_PROXY / HTTPS_PROXY / ALL_PROXY 及其小写变体，
    确保各种工具（pip、npm、go）都能正确识别代理配置。
    之所以同时设置大小写变体，是因为不同工具检查的环境变量名称不一致。

.PARAMETER Url
    代理 URL。
#>
function Set-ProxyForSession {
    param([Parameter(Mandatory = $true)][string]$Url)

    $env:HTTP_PROXY = $Url
    $env:HTTPS_PROXY = $Url
    $env:ALL_PROXY = $Url
    $env:http_proxy = $Url
    $env:https_proxy = $Url
    $env:all_proxy = $Url
}

<#
.SYNOPSIS
    检查指定 TCP 端口在宿主机上是否可用。

.DESCRIPTION
    尝试在指定端口上创建 TCP 监听器，成功则立即关闭并返回 $true，
    失败则说明端口已被占用。这是一个非破坏性检查——监听器会立即释放。

.PARAMETER Port
    要检查的端口号。

.OUTPUTS
    System.Boolean — 端口可用返回 $true。
#>
function Test-TcpPortAvailable {
    param([Parameter(Mandatory = $true)][int]$Port)

    $listener = $null
    try {
        $listener = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Any, $Port)
        $listener.Start()
        return $true
    }
    catch {
        return $false
    }
    finally {
        # 无论成功或失败，确保监听器被释放
        if ($null -ne $listener) {
            $listener.Stop()
        }
    }
}

<#
.SYNOPSIS
    检查指定 UDP 端口在宿主机上是否可用。

.DESCRIPTION
    尝试在指定端口上创建 UDP 客户端，成功则立即释放并返回 $true。
    UDP 端口检查用于 LiveKit 等需要 UDP 传输的实时通信服务。

.PARAMETER Port
    要检查的端口号。

.OUTPUTS
    System.Boolean — 端口可用返回 $true。
#>
function Test-UdpPortAvailable {
    param([Parameter(Mandatory = $true)][int]$Port)

    $udpClient = $null
    try {
        $udpClient = [System.Net.Sockets.UdpClient]::new($Port)
        return $true
    }
    catch {
        return $false
    }
    finally {
        if ($null -ne $udpClient) {
            $udpClient.Dispose()
        }
    }
}

<#
.SYNOPSIS
    返回 Docker 模式下所有需要检查的宿主机端口列表。

.DESCRIPTION
    集中定义所有服务的端口映射配置，每个条目包含：
    - Service：服务名称
    - EnvName：对应的环境变量名（用于从 .env 或会话中读取自定义端口）
    - Default：默认端口号
    - Protocol：协议类型（tcp 或 udp）

    这里只维护宿主机暴露端口，不改容器内部监听端口。
    默认使用 5xxxx 端口段以避开常见系统端口占用；
    容器内部仍保持服务原生端口，避免打乱服务发现、健康检查和镜像配置。

.OUTPUTS
    Array of Hashtable — 端口检查配置列表。
#>
function Get-DockerHostPortChecks {
    return @(
        @{ Service = "orchestrator";  EnvName = "ORCHESTRATOR_PORT";   Default = "58080"; Protocol = "tcp" },
        @{ Service = "asr";           EnvName = "ASR_PORT";            Default = "58101"; Protocol = "tcp" },
        @{ Service = "tts";           EnvName = "TTS_PORT";            Default = "58102"; Protocol = "tcp" },
        @{ Service = "avatar";        EnvName = "AVATAR_PORT";         Default = "58103"; Protocol = "tcp" },
        @{ Service = "llm";           EnvName = "LLM_PORT";            Default = "58104"; Protocol = "tcp" },
        @{ Service = "admin";         EnvName = "ADMIN_PORT";          Default = "54173"; Protocol = "tcp" },
        @{ Service = "livekit-http";  EnvName = "LIVEKIT_PORT";        Default = "57880"; Protocol = "tcp" },
        @{ Service = "livekit-tcp";   EnvName = "LIVEKIT_TCP_PORT";    Default = "57881"; Protocol = "tcp" },
        @{ Service = "livekit-udp";   EnvName = "LIVEKIT_UDP_PORT";    Default = "57882"; Protocol = "udp" },
        @{ Service = "srs-rtmp";      EnvName = "SRS_RTMP_PORT";       Default = "51935"; Protocol = "tcp" },
        @{ Service = "srs-api";       EnvName = "SRS_API_PORT";        Default = "51985"; Protocol = "tcp" },
        @{ Service = "srs-http";      EnvName = "SRS_HTTP_PORT";       Default = "58081"; Protocol = "tcp" }
    )
}

<#
.SYNOPSIS
    检测所有 Docker 宿主机端口中被占用的情况。

.DESCRIPTION
    遍历 Get-DockerHostPortChecks 定义的端口列表，对每个端口：
    1. 从环境变量/.env/默认值获取端口号
    2. 验证端口号为有效整数
    3. 根据协议类型（TCP/UDP）测试端口是否可用
    4. 收集所有不可用的端口

    返回的阻塞列表中每个条目包含服务名、环境变量名、端口号、协议和原因。

.OUTPUTS
    PSCustomObject[] — 被阻塞的端口列表，为空表示所有端口可用。
#>
function Get-BlockedDockerHostPorts {
    $blocked = @()

    foreach ($item in Get-DockerHostPortChecks) {
        $rawValue = Get-EffectiveEnvValue -Name $item.EnvName -DefaultValue $item.Default
        $port = 0
        if (-not [int]::TryParse($rawValue, [ref]$port)) {
            $blocked += [PSCustomObject]@{
                Service  = $item.Service
                EnvName  = $item.EnvName
                Port     = $rawValue
                Protocol = $item.Protocol
                Reason   = "端口值不是有效整数"
            }
            continue
        }

        $available = if ($item.Protocol -eq "udp") {
            Test-UdpPortAvailable -Port $port
        }
        else {
            Test-TcpPortAvailable -Port $port
        }

        if (-not $available) {
            $blocked += [PSCustomObject]@{
                Service  = $item.Service
                EnvName  = $item.EnvName
                Port     = $port
                Protocol = $item.Protocol
                Reason   = "宿主机端口不可用"
            }
        }
    }

    return $blocked
}

<#
.SYNOPSIS
    在 Docker 启动前断言所有宿主机端口可用，如有冲突则报错退出。

.DESCRIPTION
    在真正启动 docker compose 之前，先把宿主机端口冲突拦下来。
    否则容器镜像可能都构建完了，最后才因为端口绑定失败而退出，
    排障成本会高很多——构建镜像可能花几分钟到几十分钟不等。

    当检测到端口冲突时，输出详细的冲突列表和解决方案（修改 .env 或
    当前会话环境变量），然后以 exit code 1 退出。
#>
function Assert-DockerHostPortsAvailable {
    $blocked = Get-BlockedDockerHostPorts
    if ($blocked.Count -eq 0) {
        return
    }

    Write-SectionHeader -Title "宿主机端口检查未通过"
    Write-Host "组件             环境变量             协议       端口       原因"
    Write-Host "----             ----                 ----       ----       ----"
    foreach ($item in $blocked) {
        $line = "{0,-16} {1,-20} {2,-10} {3,-10} {4}" -f `
            $item.Service, `
            $item.EnvName, `
            $item.Protocol, `
            $item.Port, `
            $item.Reason
        Write-Host $line
    }

    Write-Host ""
    Write-Host "请先在当前 PowerShell 会话或 .env 中改掉冲突端口，再重新启动。" -ForegroundColor Yellow
    Write-Host "本仓库默认已经优先使用 5xxxx 端口；如果仍有冲突，再继续手动覆盖。" -ForegroundColor DarkGray
    Write-Host "如果你还想临时覆盖默认端口，可先执行：" -ForegroundColor Yellow
    Write-Host '  $env:SRS_RTMP_PORT = "61935"' -ForegroundColor Cyan
    Write-Host '  $env:SRS_API_PORT = "61985"' -ForegroundColor Cyan
    Write-Host '  $env:SRS_HTTP_PORT = "68081"' -ForegroundColor Cyan
    Write-Host ""
    Write-Host "然后重新运行：" -ForegroundColor Yellow
    Write-Host '  ./start.ps1 -Mode docker' -ForegroundColor Cyan
    exit 1
}

<#
.SYNOPSIS
    将代理 URL 中的 localhost/127.0.0.1 转换为 Docker 容器可访问的地址。

.DESCRIPTION
    Docker Desktop / BuildKit 中的容器与宿主机不在同一个网络命名空间。
    如果用户把代理写成 localhost 或 127.0.0.1，这个地址在容器里只会指向
    容器自身，并不能访问 Windows 宿主机上的代理服务。

    因此这里自动将 localhost/127.0.0.1 替换为 host.docker.internal——
    这是 Docker Desktop 为容器访问宿主机提供的特殊 DNS 名称。

    如果代理地址不是回环地址（比如是局域网中另一台机器上的代理），
    则原样返回，不做替换。

.PARAMETER ProxyUrl
    原始代理 URL。

.OUTPUTS
    System.String — 转换后的代理 URL。
#>
function Convert-ProxyUrlForDockerBuild {
    param([string]$ProxyUrl)

    if ([string]::IsNullOrWhiteSpace($ProxyUrl)) {
        return $ProxyUrl
    }

    try {
        $uri = [System.Uri]$ProxyUrl
        if ($uri.Host -in @("127.0.0.1", "localhost")) {
            $builder = New-Object System.UriBuilder($uri)
            # Docker Desktop / BuildKit 中的 127.0.0.1 指向容器自身，不是宿主机。
            # 使用 host.docker.internal 可以让容器访问宿主机的代理服务。
            $builder.Host = "host.docker.internal"
            return $builder.Uri.AbsoluteUri.TrimEnd("/")
        }
    }
    catch {
        # URI 解析失败时原样返回，后续步骤会自然报错并给出提示
        return $ProxyUrl
    }

    return $ProxyUrl
}

<#
.SYNOPSIS
    从 Docker 构建输出中判断是否为"基础镜像拉取失败"。

.DESCRIPTION
    基础镜像拉取（FROM 指令）走的是 Docker daemon 层的网络，
    这是 Docker Desktop 的代理设置管理范围，而非容器内代理。
    识别出这种失败类型后，可以给出更有针对性的排障提示。

.PARAMETER Lines
    Docker build 的输出行数组。

.OUTPUTS
    System.Boolean — 疑似基础镜像拉取失败返回 $true。
#>
function Test-DockerBaseImageProxyFailure {
    param([string[]]$Lines)

    if ($null -eq $Lines -or $Lines.Count -eq 0) {
        return $false
    }

    $content = ($Lines -join "`n")
    # 匹配多种基础镜像拉取失败的典型错误信息：
    # - "failed to resolve source metadata" + registry-1.docker.io → Docker Hub 元数据获取失败
    # - "Docker Desktop has no HTTPS proxy" → Docker Desktop 缺少 HTTPS 代理配置
    # - "load metadata for docker.io" + "failed to do request" → BuildKit 拉取元数据超时/失败
    # - 单独出现 registry-1.docker.io → 通常是连接 Docker Hub 注册表失败
    return (
        ($content -match 'failed to resolve source metadata' -and $content -match 'registry-1\.docker\.io') -or
        $content -match 'Docker Desktop has no HTTPS proxy' -or
        ($content -match 'load metadata for docker\.io' -and $content -match 'failed to do request') -or
        $content -match 'registry-1\.docker\.io'
    )
}

<#
.SYNOPSIS
    从 Docker 构建输出中判断是否为"容器内代理连接失败"。

.DESCRIPTION
    容器内代理连接失败（如 pip install 时报 ProxyError）通常是代理地址、
    监听方式或局域网放行没有配置正确导致的，不是 Docker daemon 的问题。
    识别出这种失败类型后，可以给出更有针对性的排障提示。

.PARAMETER Lines
    Docker build 的输出行数组。

.OUTPUTS
    System.Boolean — 疑似容器内代理连接失败返回 $true。
#>
function Test-DockerProxyConnectionFailure {
    param([string[]]$Lines)

    if ($null -eq $Lines -or $Lines.Count -eq 0) {
        return $false
    }

    $content = ($Lines -join "`n")
    # 匹配两种典型的容器内代理连接失败：
    # - ProxyError('Cannot connect to proxy.') → Python requests 库的代理连接错误
    # - "Failed to establish a new connection: [Errno 111] Connection refused" → TCP 连接被拒
    return (
        $content -match "ProxyError\('Cannot connect to proxy\." -or
        $content -match "Failed to establish a new connection: \[Errno 111\] Connection refused"
    )
}

<#
.SYNOPSIS
    根据 Docker 构建失败类型输出有针对性的排障提示。

.DESCRIPTION
    Docker 构建失败时，优先把错误归类成两大类：
    1. 基础镜像拉取失败：通常要去 Docker Desktop 里配 daemon 代理
    2. 容器内代理不可达：通常是代理地址、监听方式或局域网放行没配对

    这样分类后用户可以快速定位到正确的修复方向，而不是面对一长串错误日志无从下手。

.PARAMETER OutputLines
    Docker build 的完整输出行数组。

.PARAMETER OriginalProxyUrl
    用户原始传入的代理 URL（转换前）。

.PARAMETER DockerProxyUrl
    经过 Convert-ProxyUrlForDockerBuild 转换后的代理 URL。
#>
function Write-DockerBuildFailureHint {
    param(
        [string[]]$OutputLines,
        [string]$OriginalProxyUrl = "",
        [string]$DockerProxyUrl = ""
    )

    # 情况一：基础镜像拉取失败 → 需要配置 Docker Desktop 自身的代理
    if (Test-DockerBaseImageProxyFailure -Lines $OutputLines) {
        Write-Host ""
        Write-Host "检测到构建失败发生在基础镜像拉取阶段。" -ForegroundColor Yellow
        Write-Host "这一步发生在 Docker daemon 侧，单纯传入 -Proxy 或 PowerShell 环境变量还不够。" -ForegroundColor Yellow
        Write-Host "需要先在 Docker Desktop 的代理设置里配置 HTTP / HTTPS 代理，然后 Apply & Restart。" -ForegroundColor Yellow
        Write-DockerDesktopProxyGuide
        return
    }

    # 情况二：容器内代理不可达 → 检查代理是否可达、是否允许局域网连接
    if (Test-DockerProxyConnectionFailure -Lines $OutputLines) {
        Write-Host ""
        Write-Host "检测到构建失败发生在容器内依赖下载阶段，而且当前代理地址无法从容器里连通。" -ForegroundColor Yellow

        if ($OriginalProxyUrl -match "127\.0\.0\.1|localhost") {
            Write-Host "你传入的是本机回环地址（127.0.0.1 / localhost）。" -ForegroundColor Yellow
            Write-Host "对 Docker build 里的 Linux 容器来说，这个地址指向容器自己，不是 Windows 宿主机。" -ForegroundColor Yellow
            Write-Host "脚本现在会自动改写成 Docker 可访问的地址，但如果宿主机代理本身没监听或拒绝连接，仍会失败。" -ForegroundColor Yellow
        }

        if (![string]::IsNullOrWhiteSpace($DockerProxyUrl)) {
            Write-Host ""
            Write-Host "当前用于 Docker build 的代理地址：" -ForegroundColor Yellow
            Write-Host "  $DockerProxyUrl" -ForegroundColor Cyan
        }

        Write-Host ""
        Write-Host "建议先确认你的代理软件确实允许 Docker 访问：" -ForegroundColor Yellow
        Write-Host "  1. 代理软件已启动" -ForegroundColor DarkGray
        Write-Host "  2. 监听端口与当前代理地址中的端口一致" -ForegroundColor DarkGray
        Write-Host "  3. 允许局域网 / 来自外部连接（不同代理软件名称可能不同）" -ForegroundColor DarkGray
        Write-Host ""
        Write-Host "更稳妥的重试方式：" -ForegroundColor Yellow
        if (![string]::IsNullOrWhiteSpace($DockerProxyUrl)) {
            Write-Host "  ./start.ps1 -Mode docker -Proxy `"$DockerProxyUrl`"" -ForegroundColor Cyan
        }
        else {
            Write-Host '  ./start.ps1 -Mode docker -Proxy "http://host.docker.internal:<端口>"' -ForegroundColor Cyan
        }
    }
}

<#
.SYNOPSIS
    执行 docker compose build + up 的完整启动流程。

.DESCRIPTION
    这是 Docker 模式的核心执行函数。流程设计为"先 build 再 up"，原因：

    1. 镜像拉取（FROM 指令）：走 Docker daemon 网络层
    2. 容器内依赖下载（pip/npm/go）：走代理注入的容器网络层
    3. 容器启动及端口绑定：走 Docker 网络驱动

    三类问题在不同阶段暴露，后续排障提示可以更精准地指向正确方向。
    如果一步到位 docker compose up --build，所有错误混在一起，很难分辨。

    当检测到代理配置时，会通过 --build-arg 将代理注入到容器构建阶段，
    供 Dockerfile 中的 pip/npm/go 等包管理器使用。

.PARAMETER ProxyUrl
    代理 URL（可选），为空则直连。
#>
function Invoke-DockerComposeUp {
    param([string]$ProxyUrl)

    # ── 第一步：构建镜像（build） ──
    # 统一先 build，让镜像拉取和依赖下载的失败先暴露出来。
    $buildArgs = @("compose", "build")
    $dockerProxyUrl = Convert-ProxyUrlForDockerBuild -ProxyUrl $ProxyUrl
    if (![string]::IsNullOrWhiteSpace($ProxyUrl)) {
        # 有代理时：将代理环境变量注入到当前 PowerShell 会话，
        # 再通过 --build-arg 传给 Docker build 上下文。
        Set-ProxyForSession -Url $dockerProxyUrl
        Write-Host ""
        Write-Host "检测到代理配置，先执行 docker compose build ..." -ForegroundColor DarkGray
        if ($dockerProxyUrl -ne $ProxyUrl) {
            Write-Host "已将本机代理地址转换为 Docker 可访问地址：$dockerProxyUrl" -ForegroundColor DarkGray
        }
        $buildArgs += @("--build-arg", "HTTP_PROXY=$dockerProxyUrl", "--build-arg", "HTTPS_PROXY=$dockerProxyUrl")
    }
    else {
        Write-Host ""
        Write-Host "先执行 docker compose build 检查镜像构建..." -ForegroundColor DarkGray
    }

    # 执行 build 并实时输出（使用 Invoke-CommandWithLiveOutput 而非静默执行）
    $buildResult = Invoke-CommandWithLiveOutput -FilePath "docker" -Arguments $buildArgs
    if ($buildResult.ExitCode -ne 0) {
        # build 失败时输出分类排障提示
        Write-DockerBuildFailureHint `
            -OutputLines $buildResult.Output `
            -OriginalProxyUrl $ProxyUrl `
            -DockerProxyUrl $dockerProxyUrl
        exit $buildResult.ExitCode
    }

    # ── 第二步：启动容器（up） ──
    # build 成功后直接执行 docker compose up，
    # 此时所有镜像已就绪，up 只会涉及容器创建和端口绑定。
    & docker compose up
    exit $LASTEXITCODE
}

<#
.SYNOPSIS
    Docker 模式的主入口函数。

.DESCRIPTION
    协调整个 Docker 启动流程：
    1. 先做宿主机端口预检（Assert-DockerHostPortsAvailable）
    2. 决定本次启动要使用的代理来源，优先级从高到低：
       a. 命令行显式传入的 -Proxy 参数
       b. 当前 PowerShell 会话中已设置好的代理环境变量
       c. 如果都没有，按直连方式继续
    3. 调用 Invoke-DockerComposeUp 执行构建和启动
#>
function Start-DockerMode {
    $activeProxy = $null

    # 第一步：在真正执行 compose 之前先检查宿主机端口，
    # 避免容器镜像都构建完了才因端口冲突失败。
    Assert-DockerHostPortsAvailable

    # 第二步：确定代理来源
    if (![string]::IsNullOrWhiteSpace($Proxy)) {
        # 优先使用命令行显式传入的代理
        $activeProxy = $Proxy
        Write-Host ""
        Write-Host "使用命令行传入的代理：$activeProxy" -ForegroundColor DarkGray
    }
    else {
        # 其次检测当前会话中已有的代理环境变量
        $activeProxy = Get-CurrentProxyUrl
        if (![string]::IsNullOrWhiteSpace($activeProxy)) {
            Write-Host ""
            Write-Host "检测到当前会话已配置代理：$activeProxy" -ForegroundColor DarkGray
        }
        else {
            Write-Host ""
            Write-Host "当前未检测到代理配置。" -ForegroundColor DarkGray
            Write-Host "如果你需要代理，请先 Ctrl+C 终止脚本，设置代理后重新运行；如果不需要，可直接继续。" -ForegroundColor DarkGray
        }
    }

    # 第三步：执行构建和启动
    Invoke-DockerComposeUp -ProxyUrl $activeProxy
}

# ════════════════════════════════════════════════════════════════════════════
# 主流程
# 脚本执行的唯一入口点。根据 $Mode 参数决定走 local 检查流程
# 还是 docker 启动流程。两种模式互斥，不会同时执行。
# ════════════════════════════════════════════════════════════════════════════

Write-Host ""
Write-Host "  ╔════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "  ║     AvaStack 启动与环境检查脚本     ║" -ForegroundColor Cyan
Write-Host "  ╚════════════════════════════════════╝" -ForegroundColor Cyan

# ── 自动准备 .env 文件 ─────────────────────────────────────────────────
# 首次进入仓库时，如果 .env 不存在，自动从 .env.example 复制一份。
# 这降低了新贡献者或首次部署时的启动门槛——不需要手动创建 .env。
if (!(Test-Path ".env")) {
    Copy-Item ".env.example" ".env"
    Write-Host "已根据 .env.example 创建 .env" -ForegroundColor Green
}

# ════════════════════════════════════════════════════════════════════════
# 本地开发模式
# 一次性检查所有本地工具链，输出完整的通过/失败报告和安装指引，
# 然后退出（不自动启动服务）。本地模式以手动启动各服务为主，
# 脚本先负责一次性把环境和依赖指引给全。
# ════════════════════════════════════════════════════════════════════════
if ($Mode -eq "local") {
    Write-SectionHeader -Title "本地开发模式检查结果"

    $localResult = Test-LocalPrerequisites
    Write-CheckTable -Rows $localResult.Rows

    if ($localResult.IsReady) {
        # 所有工具链检查通过——输出代理提醒和依赖安装指引
        Write-Host ""
        Write-Host "本地工具链已就绪。" -ForegroundColor Green
        Write-ProxyReminder -Scenario "local"
        Write-ProjectDependencyGuide -PythonCommand $localResult.PythonRuntime.Display
        Write-Host ""
        Write-Host "当前仓库的本地模式仍以手动启动各服务为主，脚本先负责一次性把环境和依赖指引给全。" -ForegroundColor Yellow
        exit 0
    }

    # 有未通过的检查项——输出代理提醒、所有失败项的安装指引和依赖安装路径
    Write-ProxyReminder -Scenario "local"
    Write-InstallGuidesFromRows -Rows $localResult.Rows

    $pythonCommandForGuide = if ($localResult.PythonRuntime) { $localResult.PythonRuntime.Display } else { "python" }
    Write-ProjectDependencyGuide -PythonCommand $pythonCommandForGuide
    Write-ReRunHint -CommandText "./start.ps1 -Mode local"
    exit 1
}

# ════════════════════════════════════════════════════════════════════════
# Docker 模式（也是默认模式）
# 检查 Docker CLI / Compose / daemon 三层状态，
# 全部通过后执行 compose build → compose up。
# ════════════════════════════════════════════════════════════════════════
Write-SectionHeader -Title "Docker 模式检查结果"

$dockerResult = Test-DockerPrerequisites
Write-CheckTable -Rows $dockerResult.Rows

if (-not $dockerResult.DockerReady) {
    # Docker 环境未就绪——输出代理提醒和所有失败项的安装指引
    Write-ProxyReminder -Scenario "docker"
    Write-InstallGuidesFromRows `
        -Rows $dockerResult.Rows `
        -HasRancher $dockerResult.HasRancher `
        -HasDockerDesktop $dockerResult.HasDockerDesktop
    Write-ReRunHint -CommandText "./start.ps1 -Mode docker"
    exit 1
}

# Docker 环境已全部就绪——检查端口、配置代理、构建并启动所有服务
Write-ProxyReminder -Scenario "docker"
Write-Host ""
Write-Host "Docker 环境已就绪，开始启动 compose 服务..." -ForegroundColor Green
Start-DockerMode
