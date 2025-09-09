#Requires -Version 5.1
<#
.SYNOPSIS
    Script de instalacao do sistema de verificacao pre-commit enterprise
.DESCRIPTION
    Instala e configura o hook pre-commit otimizado para performance
    com verificacoes automatizadas de qualidade de codigo.
#>

param(
    [switch]$Force,
    [switch]$Verbose
)

# Funcao para output colorido
function Write-Status {
    param(
        [string]$Message,
        [string]$Type = "Info"
    )
    
    $colors = @{
        "Success" = "Green"
        "Warning" = "Yellow"
        "Error" = "Red"
        "Info" = "Cyan"
    }
    
    $color = if ($colors.ContainsKey($Type)) { $colors[$Type] } else { "White" }
    Write-Host $Message -ForegroundColor $color
}

# Funcao principal de instalacao
function Install-PreCommitHook {
    Write-Status "INSTALADOR PRE-COMMIT ENTERPRISE" "Info"
    Write-Status ("=" * 40) "Info"
    
    # Verificar se e um repositorio Git
    if (-not (Test-Path ".git")) {
        Write-Status "Erro: Nao e um repositorio Git" "Error"
        Write-Status "Execute 'git init' primeiro" "Info"
        exit 1
    }
    
    # Verificar arquivos necessarios
    $requiredFiles = @(
        "pre-commit-hook.ps1",
        "README-precommit.md"
    )
    
    foreach ($file in $requiredFiles) {
        if (-not (Test-Path $file)) {
            Write-Status "Erro: Arquivo $file nao encontrado" "Error"
            exit 1
        }
    }
    
    Write-Status "Arquivos necessarios encontrados" "Success"
    
    # Criar diretorio de hooks se nao existir
    $hooksDir = ".git\hooks"
    if (-not (Test-Path $hooksDir)) {
        New-Item -ItemType Directory -Path $hooksDir -Force | Out-Null
        Write-Status "Diretorio de hooks criado" "Success"
    }
    
    # Caminho do hook
    $hookPath = Join-Path $hooksDir "pre-commit"
    
    # Verificar se hook ja existe
    if ((Test-Path $hookPath) -and -not $Force) {
        Write-Status "Hook pre-commit ja existe" "Warning"
        $response = Read-Host "Deseja sobrescrever? (s/N)"
        if ($response -notmatch '^[sS]') {
            Write-Status "Instalacao cancelada" "Info"
            exit 0
        }
    }
    
    # Criar o hook
    $hookContent = @'
#!/bin/sh
# Pre-commit hook enterprise
# Executa verificacoes de qualidade de codigo

# Detectar se estamos no Windows
if [ "$OS" = "Windows_NT" ] || command -v powershell.exe >/dev/null 2>&1; then
    # Windows - usar PowerShell
    if command -v powershell.exe >/dev/null 2>&1; then
        powershell.exe -ExecutionPolicy Bypass -File "pre-commit-hook.ps1"
    else
        pwsh -ExecutionPolicy Bypass -File "pre-commit-hook.ps1"
    fi
    exit_code=$?
else
    # Unix/Linux - tentar PowerShell Core primeiro
    if command -v pwsh >/dev/null 2>&1; then
        pwsh -ExecutionPolicy Bypass -File "pre-commit-hook.ps1"
        exit_code=$?
    else
        echo "Erro: PowerShell nao encontrado"
        echo "Instale PowerShell Core ou execute no Windows"
        exit 1
    fi
fi

if [ $exit_code -ne 0 ]; then
    echo "Pre-commit verificacao falhou"
    exit 1
fi

exit 0
'@
    
    try {
        # Escrever o hook
        $hookContent | Set-Content -Path $hookPath -Encoding UTF8
        
        # Tornar executavel (no Windows isso e automatico)
        if ($IsLinux -or $IsMacOS) {
            chmod +x $hookPath
        }
        
        Write-Status "Hook pre-commit instalado com sucesso" "Success"
        
        # Testar o sistema
        Write-Status "Testando o sistema..." "Info"
        
        $testResult = & powershell.exe -ExecutionPolicy Bypass -File "pre-commit-hook.ps1" -TestMode
        
        if ($LASTEXITCODE -eq 0) {
            Write-Status "Teste concluido com sucesso" "Success"
        } else {
            Write-Status "Teste falhou - verifique a configuracao" "Warning"
        }
        
        # Criar configuracao padrao se nao existir
        $configFile = "pre-commit-config.json"
        if (-not (Test-Path $configFile)) {
            $defaultConfig = @{
                MaxParallelJobs = 4
                TimeoutSeconds = 30
                CacheEnabled = $true
                CacheDirectory = ".pre-commit-cache"
                EnabledChecks = @("html", "css", "js", "images")
                Performance = @{
                    MaxFileSize = 1048576
                    MaxExecutionTime = 30
                }
                Thresholds = @{
                    ErrorThreshold = 0
                    WarningThreshold = 5
                    OptimizationThreshold = 10
                }
            }
            
            $defaultConfig | ConvertTo-Json -Depth 10 | Set-Content $configFile
            Write-Status "Configuracao padrao criada: $configFile" "Success"
        }
        
        # Mostrar informacoes de uso
        Write-Status "`nCONFIGURACAO CONCLUIDA" "Success"
        Write-Status ("=" * 25) "Info"
        Write-Status "O hook pre-commit foi instalado e configurado" "Info"
        Write-Status "Sera executado automaticamente a cada commit" "Info"
        Write-Status "`nComandos uteis:" "Info"
        Write-Status "- Teste manual: powershell -File pre-commit-hook.ps1 -TestMode" "Info"
        Write-Status "- Configuracao: edite pre-commit-config.json" "Info"
        Write-Status "- Documentacao: README-precommit.md" "Info"
        Write-Status "`nProximo commit sera verificado automaticamente!" "Success"
        
    } catch {
        Write-Status "Erro durante a instalacao: $($_.Exception.Message)" "Error"
        exit 1
    }
}

# Funcao para desinstalar
function Uninstall-PreCommitHook {
    $hookPath = ".git\hooks\pre-commit"
    
    if (Test-Path $hookPath) {
        Remove-Item $hookPath -Force
        Write-Status "Hook pre-commit removido" "Success"
    } else {
        Write-Status "Hook pre-commit nao encontrado" "Info"
    }
    
    # Remover cache se existir
    if (Test-Path ".pre-commit-cache") {
        Remove-Item ".pre-commit-cache" -Recurse -Force
        Write-Status "Cache removido" "Success"
    }
}

# Executar instalacao
try {
    if ($args -contains "-Uninstall") {
        Uninstall-PreCommitHook
    } else {
        Install-PreCommitHook
    }
} catch {
    Write-Status "Erro critico: $($_.Exception.Message)" "Error"
    Write-Status "Verifique os pre-requisitos e tente novamente" "Info"
    exit 1
}