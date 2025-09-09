#Requires -Version 5.1
<#
.SYNOPSIS
    Sistema de verificacao pre-commit enterprise otimizado para performance
.DESCRIPTION
    Hook pre-commit que executa verificacoes paralelas de qualidade de codigo,
    sintaxe, performance e otimizacoes com cache inteligente.
.PARAMETER TestMode
    Executa em modo de teste sem verificar git staged files
.PARAMETER Verbose
    Exibe informacoes detalhadas de debug
.PARAMETER ConfigPath
    Caminho para arquivo de configuracao personalizado
#>

param(
    [switch]$TestMode,
    [switch]$Verbose,
    [string]$ConfigPath = "pre-commit-config.json"
)

# Configuracao global
$Global:Config = @{
    MaxParallelJobs = 4
    TimeoutSeconds = 30
    CacheEnabled = $true
    CacheDirectory = ".pre-commit-cache"
    EnabledChecks = @("html", "css", "js", "images")
    Performance = @{
        MaxFileSize = 1048576  # 1MB
        MaxExecutionTime = 30
    }
    Thresholds = @{
        ErrorThreshold = 0
        WarningThreshold = 5
        OptimizationThreshold = 10
    }
}

# Funcao para output colorido
function Write-ColorOutput {
    param(
        [string]$Message,
        [string]$Color = "White"
    )
    
    $colorMap = @{
        "Success" = "Green"
        "Warning" = "Yellow"
        "Error" = "Red"
        "Info" = "Cyan"
        "Muted" = "Gray"
    }
    
    $consoleColor = if ($colorMap.ContainsKey($Color)) { $colorMap[$Color] } else { $Color }
    Write-Host $Message -ForegroundColor $consoleColor
}

# Funcao para carregar configuracao
function Initialize-Config {
    param([string]$ConfigPath)
    
    if (Test-Path $ConfigPath) {
        try {
            $customConfig = Get-Content $ConfigPath | ConvertFrom-Json
            
            # Merge configuracoes
            foreach ($key in $customConfig.PSObject.Properties.Name) {
                if ($Global:Config.ContainsKey($key)) {
                    $Global:Config[$key] = $customConfig.$key
                }
            }
            
            Write-ColorOutput "Configuracao carregada: $ConfigPath" "Success"
        } catch {
            Write-ColorOutput "Erro ao carregar config, usando padrao: $($_.Exception.Message)" "Warning"
        }
    }
}

# Funcao para verificar cache
function Get-CacheKey {
    param([string]$FilePath)
    
    $fileInfo = Get-Item $FilePath
    return "$($fileInfo.Name)_$($fileInfo.LastWriteTime.Ticks)_$($fileInfo.Length)"
}

function Get-CachedResult {
    param([string]$FilePath)
    
    if (-not $Global:Config.CacheEnabled) { return $null }
    
    $cacheDir = $Global:Config.CacheDirectory
    if (-not (Test-Path $cacheDir)) { return $null }
    
    $cacheKey = Get-CacheKey $FilePath
    $cacheFile = Join-Path $cacheDir "$cacheKey.json"
    
    if (Test-Path $cacheFile) {
        try {
            return Get-Content $cacheFile | ConvertFrom-Json
        } catch {
            Remove-Item $cacheFile -ErrorAction SilentlyContinue
        }
    }
    
    return $null
}

function Set-CachedResult {
    param(
        [string]$FilePath,
        [object]$Result
    )
    
    if (-not $Global:Config.CacheEnabled) { return }
    
    $cacheDir = $Global:Config.CacheDirectory
    if (-not (Test-Path $cacheDir)) {
        New-Item -ItemType Directory -Path $cacheDir -Force | Out-Null
    }
    
    $cacheKey = Get-CacheKey $FilePath
    $cacheFile = Join-Path $cacheDir "$cacheKey.json"
    
    try {
        $Result | ConvertTo-Json -Depth 10 | Set-Content $cacheFile
    } catch {
        Write-ColorOutput "Erro ao salvar cache: $($_.Exception.Message)" "Warning"
    }
}

# Funcao para verificar HTML
function Test-HTMLFile {
    param([string]$FilePath)
    
    $result = @{
        file = $FilePath
        type = "HTML"
        syntax = @{ valid = $true; errors = @(); warnings = @(); optimizations = @() }
        performance = @{ score = 100; issues = @() }
        timestamp = Get-Date
    }
    
    try {
        $content = Get-Content $FilePath -Raw -Encoding UTF8 -ErrorAction SilentlyContinue
        
        if (-not $content) {
            $result.syntax.errors += "Arquivo vazio ou não encontrado"
            $result.syntax.valid = $false
            $result.performance.score = 0
            return $result
        }
        
        # Verificacoes basicas de sintaxe
        if ($content -notmatch '<!DOCTYPE html>') {
            $result.syntax.warnings += "DOCTYPE HTML5 recomendado"
            $result.performance.score -= 5
        }
        
        if ($content -notmatch '<html[^>]*lang=') {
            $result.syntax.warnings += "Atributo lang ausente no elemento html"
            $result.performance.score -= 5
        }
        
        # Verificacoes de performance
        if ($content -match 'style="[^"]*"') {
            $result.syntax.optimizations += "Considere mover estilos inline para CSS externo"
            $result.performance.score -= 3
        }
        
        if ($content -match '<img[^>]*(?!alt=)') {
            $result.syntax.warnings += "Imagens sem atributo alt encontradas"
            $result.performance.score -= 10
        }
        
        # Verificacoes de otimizacao
        try {
            $scriptTags = [regex]::Matches($content, '<script[^>]*src="[^"]*"[^>]*></script>')
            if ($scriptTags.Count -gt 5) {
                $result.syntax.optimizations += "Considere concatenar scripts ($($scriptTags.Count) encontrados)"
                $result.performance.score -= 5
            }
        } catch {
            $result.syntax.warnings += "Erro na análise de scripts: $($_.Exception.Message)"
        }
        
    } catch {
        $result.syntax.valid = $false
        $result.syntax.errors += $_.Exception.Message
        $result.performance.score = 0
    }
    
    return $result
}

# Funcao para verificar CSS
function Test-CSSFile {
    param([string]$FilePath)
    
    $result = @{
        file = $FilePath
        type = "CSS"
        syntax = @{ valid = $true; errors = @(); warnings = @(); optimizations = @() }
        performance = @{ score = 100; issues = @() }
        timestamp = Get-Date
    }
    
    try {
        $content = Get-Content $FilePath -Raw -Encoding UTF8 -ErrorAction SilentlyContinue
        
        if (-not $content) {
            $result.syntax.errors += "Arquivo vazio ou não encontrado"
            $result.syntax.valid = $false
            $result.performance.score = 0
            return $result
        }
        
        # Verificacoes de otimizacao
        if ($content -match ':\s*0px') {
            $result.syntax.optimizations += "Remova px de valores zero (0px -> 0)"
            $result.performance.score -= 2
        }
        
        if ($content -match '#[0-9a-fA-F]{6}') {
            $result.syntax.optimizations += "Use notacao hex curta quando possivel"
            $result.performance.score -= 1
        }
        
        # Verificacoes de performance
        try {
            $universalSelectors = [regex]::Matches($content, '\*\s*{')
            if ($universalSelectors.Count -gt 2) {
                $result.syntax.warnings += "Muitos seletores universais (*) podem impactar performance"
                $result.performance.score -= 10
            }
        } catch {
            $result.syntax.warnings += "Erro na análise de seletores: $($_.Exception.Message)"
        }
        
        # Verificacoes de sintaxe
        try {
            $openBraces = [regex]::Matches($content, '{')
            $closeBraces = [regex]::Matches($content, '}')
            if ($openBraces.Count -ne $closeBraces.Count) {
                $result.syntax.errors += "Chaves desbalanceadas detectadas"
                $result.syntax.valid = $false
                $result.performance.score -= 20
            }
        } catch {
            $result.syntax.errors += "Erro na análise de sintaxe: $($_.Exception.Message)"
            $result.syntax.valid = $false
        }
        
    } catch {
        $result.syntax.valid = $false
        $result.syntax.errors += $_.Exception.Message
        $result.performance.score = 0
    }
    
    return $result
}

# Funcao para verificar JavaScript
function Test-JSFile {
    param([string]$FilePath)
    
    $result = @{
        file = $FilePath
        type = "JavaScript"
        syntax = @{ valid = $true; errors = @(); warnings = @(); optimizations = @() }
        performance = @{ score = 100; issues = @() }
        timestamp = Get-Date
    }
    
    try {
        $content = Get-Content $FilePath -Raw -Encoding UTF8 -ErrorAction SilentlyContinue
        
        if (-not $content) {
            $result.syntax.errors += "Arquivo vazio ou não encontrado"
            $result.syntax.valid = $false
            $result.performance.score = 0
            return $result
        }
        
        # Verificacoes de otimizacao
        if ($content -match 'console\.(log|debug|info)') {
            $result.syntax.optimizations += "Remova console.log() antes do deploy"
            $result.performance.score -= 5
        }
        
        if ($content -match '\bvar\s+') {
            $result.syntax.optimizations += "Use let ou const ao inves de var"
            $result.performance.score -= 3
        }
        
        # Verificacoes de performance
        if ($content -match 'document\.getElementById') {
            $result.syntax.optimizations += "Considere usar querySelector() para consistencia"
            $result.performance.score -= 2
        }
        
        # Verificacoes basicas de sintaxe
        try {
            $openParens = [regex]::Matches($content, '\(')
            $closeParens = [regex]::Matches($content, '\)')
            if ($openParens.Count -ne $closeParens.Count) {
                $result.syntax.warnings += "Parenteses possivelmente desbalanceados"
                $result.performance.score -= 10
            }
            
            $openBraces = [regex]::Matches($content, '{')
            $closeBraces = [regex]::Matches($content, '}')
            if ($openBraces.Count -ne $closeBraces.Count) {
                $result.syntax.errors += "Chaves desbalanceadas detectadas"
                $result.syntax.valid = $false
                $result.performance.score -= 20
            }
        } catch {
            $result.syntax.errors += "Erro na análise de sintaxe: $($_.Exception.Message)"
            $result.syntax.valid = $false
        }
        
    } catch {
        $result.syntax.valid = $false
        $result.syntax.errors += $_.Exception.Message
        $result.performance.score = 0
    }
    
    return $result
}

# Funcao para executar verificacoes em paralelo
function Invoke-ParallelChecks {
    param([array]$Files)
    
    $results = @{}
    $jobs = @()
    
    Write-ColorOutput "Executando verificacoes em paralelo..." "Info"
    
    foreach ($file in $Files) {
        # Verificar cache primeiro
        $cachedResult = Get-CachedResult $file
        if ($cachedResult) {
            $results[$file] = $cachedResult
            Write-ColorOutput "$(Split-Path $file -Leaf) (cache)" "Muted"
            continue
        }
        
        $extension = [System.IO.Path]::GetExtension($file).ToLower()
        
        $job = switch ($extension) {
            ".html" { Start-Job -ScriptBlock { param($f) . $using:PSCommandPath; Test-HTMLFile -FilePath $f } -ArgumentList $file }
            ".css" { Start-Job -ScriptBlock { param($f) . $using:PSCommandPath; Test-CSSFile -FilePath $f } -ArgumentList $file }
            ".js" { Start-Job -ScriptBlock { param($f) . $using:PSCommandPath; Test-JSFile -FilePath $f } -ArgumentList $file }
            default { $null }
        }
        
        if ($job) {
            $jobs += @{ Job = $job; File = $file }
        }
    }
    
    # Aguardar conclusao dos jobs
    $completed = 0
    $startTime = Get-Date
    
    while ($completed -lt $jobs.Count -and ((Get-Date) - $startTime).TotalSeconds -lt $Global:Config.TimeoutSeconds) {
        foreach ($jobInfo in $jobs) {
            if ($jobInfo.Job.State -eq "Completed" -and -not $results.ContainsKey($jobInfo.File)) {
                try {
                    $result = Receive-Job $jobInfo.Job
                    $results[$jobInfo.File] = $result
                    $completed++
                    
                    # Salvar no cache
                    Set-CachedResult $jobInfo.File $result
                    
                    Write-ColorOutput "$(Split-Path $jobInfo.File -Leaf)" "Success"
                } catch {
                    Write-ColorOutput "Erro em $(Split-Path $jobInfo.File -Leaf): $($_.Exception.Message)" "Error"
                }
                
                Remove-Job $jobInfo.Job
            }
        }
        
        Start-Sleep -Milliseconds 100
    }
    
    # Limpar jobs restantes
    foreach ($jobInfo in $jobs) {
        if ($jobInfo.Job.State -ne "Completed") {
            Stop-Job $jobInfo.Job
            Remove-Job $jobInfo.Job
        }
    }
    
    return $results
}

# Funcao para mostrar resultados
function Show-Results {
    param([hashtable]$Results)
    
    $totalFiles = $Results.Count
    $totalErrors = 0
    $totalWarnings = 0
    $totalOptimizations = 0
    $totalScore = 0
    
    Write-ColorOutput "`nRELATORIO DE VERIFICACAO PRE-COMMIT" "Info"
    Write-ColorOutput ("=" * 50) "Muted"
    
    foreach ($file in $Results.Keys) {
        $result = $Results[$file]
        $fileName = Split-Path $file -Leaf
        
        $totalErrors += $result.syntax.errors.Count
        $totalWarnings += $result.syntax.warnings.Count
        $totalOptimizations += $result.syntax.optimizations.Count
        $totalScore += $result.performance.score
        
        $status = if ($result.syntax.errors.Count -gt 0) { "ERROR" } 
                 elseif ($result.syntax.warnings.Count -gt 0) { "WARNING" } 
                 else { "PASS" }
        
        $statusColor = switch ($status) {
            "PASS" { "Success" }
            "WARNING" { "Warning" }
            "ERROR" { "Error" }
        }
        
        Write-ColorOutput "`n$fileName [$($result.type)]" "Info"
        Write-ColorOutput "   Status: $status (Score: $($result.performance.score)/100)" $statusColor
        
        if ($result.syntax.errors.Count -gt 0) {
            Write-ColorOutput "   Erros:" "Error"
            foreach ($error in $result.syntax.errors) {
                Write-ColorOutput "   - $error" "Error"
            }
        }
        
        if ($result.syntax.warnings.Count -gt 0) {
            Write-ColorOutput "   Avisos:" "Warning"
            foreach ($warning in $result.syntax.warnings) {
                Write-ColorOutput "   - $warning" "Warning"
            }
        }
        
        if ($result.syntax.optimizations.Count -gt 0) {
            Write-ColorOutput "   Otimizacoes:" "Info"
            foreach ($optimization in $result.syntax.optimizations) {
                Write-ColorOutput "   - $optimization" "Info"
            }
        }
    }
    
    # Resumo final
    $averageScore = if ($totalFiles -gt 0) { [math]::Round($totalScore / $totalFiles, 1) } else { 0 }
    
    Write-ColorOutput "`nRESUMO EXECUTIVO" "Info"
    Write-ColorOutput ("=" * 30) "Muted"
    Write-ColorOutput "Arquivos verificados: $totalFiles" "Info"
    Write-ColorOutput "Score medio: $averageScore/100" $(if ($averageScore -ge 85) { "Success" } elseif ($averageScore -ge 70) { "Warning" } else { "Error" })
    Write-ColorOutput "Erros criticos: $totalErrors" $(if ($totalErrors -eq 0) { "Success" } else { "Error" })
    Write-ColorOutput "Avisos: $totalWarnings" $(if ($totalWarnings -eq 0) { "Success" } else { "Warning" })
    Write-ColorOutput "Otimizacoes sugeridas: $totalOptimizations" "Info"
    
    # Status final
    $overallStatus = if ($totalErrors -eq 0 -and $averageScore -ge 85) { 
        "PRODUCTION READY" 
    } elseif ($totalErrors -eq 0) { 
        "APROVADO COM SUGESTOES" 
    } else { 
        "REQUER CORRECOES" 
    }
    
    Write-ColorOutput "`n$overallStatus" $(if ($totalErrors -eq 0 -and $averageScore -ge 85) { "Success" } elseif ($totalErrors -eq 0) { "Warning" } else { "Error" })
    Write-ColorOutput ("=" * 50) "Muted"
    
    return @{
        success = ($totalErrors -eq 0)
        errors = $totalErrors
        warnings = $totalWarnings
        optimizations = $totalOptimizations
        averageScore = $averageScore
    }
}

# Funcao principal
function Main {
    $startTime = Get-Date
    
    try {
        Write-ColorOutput "SISTEMA DE VERIFICACAO PRE-COMMIT ENTERPRISE" "Info"
        Write-ColorOutput ("=" * 55) "Muted"
        
        # Inicializar configuracao
        Initialize-Config $ConfigPath
        
        # Obter arquivos para verificar
        if ($TestMode) {
            Write-ColorOutput "Modo de teste ativado" "Warning"
            $stagedFiles = @(Get-ChildItem -Path "." -Include "*.html", "*.css", "*.js" -Recurse | Select-Object -ExpandProperty FullName)
        } else {
            # Verificar se estamos em um repositorio git
            if (-not (Test-Path ".git")) {
                Write-ColorOutput "Nao e um repositorio Git" "Error"
                exit 1
            }
            
            # Obter arquivos staged
            $gitOutput = git diff --cached --name-only --diff-filter=ACM
            $stagedFiles = @($gitOutput | Where-Object { $_ -match '\.(html|css|js)$' } | ForEach-Object { Join-Path (Get-Location) $_ })
        }
        
        if ($stagedFiles.Count -eq 0) {
            Write-ColorOutput "Nenhum arquivo para verificar" "Success"
            exit 0
        }
        
        Write-ColorOutput "Arquivos a verificar: $($stagedFiles.Count)" "Info"
        
        # Executar verificacoes em paralelo
        $results = Invoke-ParallelChecks $stagedFiles
        
        # Mostrar resultados
        $summary = Show-Results $results
        
        $duration = ((Get-Date) - $startTime).TotalSeconds
        Write-ColorOutput "`nTempo total: $([math]::Round($duration, 2))s" "Muted"
        
        # Determinar codigo de saida
        if (-not $summary.success) {
            Write-ColorOutput "`nVerificacao falhou. Corrija os erros antes do commit." "Error"
            exit 1
        } else {
            Write-ColorOutput "`nVerificacao concluida com sucesso!" "Success"
            exit 0
        }
        
    } catch {
        Write-ColorOutput "Erro critico na verificacao: $($_.Exception.Message)" "Error"
        if ($Verbose) {
            Write-ColorOutput $_.ScriptStackTrace "Error"
        }
        exit 1
    }
}

# Executar apenas se chamado diretamente
if ($MyInvocation.InvocationName -ne '.') {
    Main
}