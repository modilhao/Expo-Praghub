# Analisador de Código Avançado - Enterprise Grade
# Foco em simplificação, otimização e performance

param(
    [string]$FilePath,
    [string]$FileType,
    [hashtable]$Config
)

# Classe para análise de código
class CodeAnalyzer {
    [hashtable]$config
    [System.Collections.ArrayList]$issues
    [System.Collections.ArrayList]$suggestions
    [hashtable]$metrics

    CodeAnalyzer([hashtable]$config) {
        $this.config = $config
        $this.issues = @()
        $this.suggestions = @()
        $this.metrics = @{}
    }

    # Análise HTML
    [hashtable] AnalyzeHTML([string]$content, [string]$filePath) {
        $lines = $content -split "`n"
        $this.metrics['lines'] = $lines.Count
        $this.metrics['size_kb'] = [math]::Round(($content.Length / 1024), 2)

        # Verificar sintaxe básica
        $this.CheckHTMLSyntax($content)
        
        # Detectar oportunidades de otimização
        $this.DetectHTMLOptimizations($content)
        
        # Verificar acessibilidade
        $this.CheckAccessibility($content)
        
        # Analisar estrutura semântica
        $this.AnalyzeSemanticStructure($content)

        return $this.GenerateReport("HTML")
    }

    # Análise CSS
    [hashtable] AnalyzeCSS([string]$content, [string]$filePath) {
        $lines = $content -split "`n"
        $this.metrics['lines'] = $lines.Count
        $this.metrics['size_kb'] = [math]::Round(($content.Length / 1024), 2)

        # Contar seletores
        $selectors = [regex]::Matches($content, '[^{}]+(?=\s*\{)')
        $this.metrics['selectors'] = $selectors.Count

        # Verificar sintaxe
        $this.CheckCSSSyntax($content)
        
        # Detectar código não utilizado
        $this.DetectUnusedCSS($content)
        
        # Sugerir consolidações
        $this.SuggestCSSConsolidation($content)
        
        # Verificar performance
        $this.CheckCSSPerformance($content)

        return $this.GenerateReport("CSS")
    }

    # Análise JavaScript
    [hashtable] AnalyzeJavaScript([string]$content, [string]$filePath) {
        $lines = $content -split "`n"
        $this.metrics['lines'] = $lines.Count
        $this.metrics['size_kb'] = [math]::Round(($content.Length / 1024), 2)

        # Calcular complexidade ciclomática
        $this.CalculateComplexity($content)
        
        # Verificar sintaxe
        $this.CheckJSSyntax($content)
        
        # Detectar variáveis não utilizadas
        $this.DetectUnusedVariables($content)
        
        # Analisar padrões async
        $this.AnalyzeAsyncPatterns($content)
        
        # Sugerir otimizações
        $this.SuggestJSOptimizations($content)

        return $this.GenerateReport("JavaScript")
    }

    # Verificações HTML
    [void] CheckHTMLSyntax([string]$content) {
        # Verificar tags não fechadas
        $openTags = [regex]::Matches($content, '<(?!/)(?!!)(?!\?)([a-zA-Z][^>]*)>', 'IgnoreCase')
        $closeTags = [regex]::Matches($content, '</([a-zA-Z][^>]*?)>', 'IgnoreCase')
        
        $selfClosing = @('img', 'br', 'hr', 'input', 'meta', 'link', 'area', 'base', 'col', 'embed', 'source', 'track', 'wbr')
        
        foreach ($tag in $openTags) {
            $tagName = ($tag.Groups[1].Value -split '\s')[0].ToLower()
            if ($tagName -notin $selfClosing) {
                $closePattern = "</$tagName>"
                if ($content -notmatch [regex]::Escape($closePattern)) {
                    $this.issues.Add(@{
                        type = "syntax_error"
                        severity = "high"
                        message = "Tag '$tagName' não está fechada"
                        suggestion = "Adicione a tag de fechamento </$tagName>"
                    })
                }
            }
        }
    }

    [void] DetectHTMLOptimizations([string]$content) {
        # Detectar imagens sem lazy loading
        $images = [regex]::Matches($content, '<img[^>]*>', 'IgnoreCase')
        foreach ($img in $images) {
            if ($img.Value -notmatch 'loading=["'']lazy["'']') {
                $this.suggestions.Add(@{
                    type = "performance"
                    message = "Imagem sem lazy loading detectada"
                    suggestion = "Adicione loading='lazy' para melhor performance"
                    impact = "medium"
                })
            }
        }

        # Detectar scripts sem defer/async
        $scripts = [regex]::Matches($content, '<script[^>]*src[^>]*>', 'IgnoreCase')
        foreach ($script in $scripts) {
            if ($script.Value -notmatch '(defer|async)') {
                $this.suggestions.Add(@{
                    type = "performance"
                    message = "Script sem otimização de carregamento"
                    suggestion = "Adicione 'defer' ou 'async' para scripts externos"
                    impact = "high"
                })
            }
        }
    }

    [void] CheckAccessibility([string]$content) {
        # Verificar alt em imagens
        $imagesWithoutAlt = [regex]::Matches($content, '<img(?![^>]*alt=)[^>]*>', 'IgnoreCase')
        if ($imagesWithoutAlt.Count -gt 0) {
            $this.issues.Add(@{
                type = "accessibility"
                severity = "medium"
                message = "$($imagesWithoutAlt.Count) imagem(ns) sem atributo alt"
                suggestion = "Adicione descrições alt para acessibilidade"
            })
        }

        # Verificar contraste de cores (básico)
        if ($content -match 'color:\s*#([a-fA-F0-9]{3,6})') {
            $this.suggestions.Add(@{
                type = "accessibility"
                message = "Verificar contraste de cores manualmente"
                suggestion = "Garanta contraste mínimo de 4.5:1 para texto normal"
                impact = "medium"
            })
        }
    }

    [void] AnalyzeSemanticStructure([string]$content) {
        # Verificar hierarquia de headings
        $headings = [regex]::Matches($content, '<h([1-6])[^>]*>', 'IgnoreCase')
        $levels = @()
        foreach ($h in $headings) {
            $levels += [int]$h.Groups[1].Value
        }
        
        for ($i = 1; $i -lt $levels.Count; $i++) {
            if ($levels[$i] - $levels[$i-1] -gt 1) {
                $this.issues.Add(@{
                    type = "semantic"
                    severity = "low"
                    message = "Hierarquia de headings quebrada (h$($levels[$i-1]) para h$($levels[$i]))"
                    suggestion = "Mantenha hierarquia sequencial de headings"
                })
            }
        }
    }

    # Verificações CSS
    [void] CheckCSSSyntax([string]$content) {
        # Verificar chaves não fechadas
        $openBraces = ($content.ToCharArray() | Where-Object { $_ -eq '{' }).Count
        $closeBraces = ($content.ToCharArray() | Where-Object { $_ -eq '}' }).Count
        
        if ($openBraces -ne $closeBraces) {
            $this.issues.Add(@{
                type = "syntax_error"
                severity = "high"
                message = "Chaves CSS não balanceadas ($openBraces abrir, $closeBraces fechar)"
                suggestion = "Verifique e corrija as chaves CSS"
            })
        }
    }

    [void] DetectUnusedCSS([string]$content) {
        # Detectar seletores potencialmente não utilizados (análise básica)
        $selectors = [regex]::Matches($content, '([.#][a-zA-Z][a-zA-Z0-9_-]*)')
        $uniqueSelectors = $selectors | ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique
        
        if ($uniqueSelectors.Count -gt $this.config.thresholds.max_css_selectors) {
            $this.suggestions.Add(@{
                type = "optimization"
                message = "Muitos seletores CSS ($($uniqueSelectors.Count))"
                suggestion = "Considere refatorar e remover seletores não utilizados"
                impact = "medium"
            })
        }
    }

    [void] SuggestCSSConsolidation([string]$content) {
        # Detectar propriedades duplicadas
        $properties = [regex]::Matches($content, '([a-zA-Z-]+)\s*:')
        $propertyGroups = $properties | Group-Object { $_.Groups[1].Value }
        
        foreach ($group in $propertyGroups) {
            if ($group.Count -gt 5) {
                $this.suggestions.Add(@{
                    type = "consolidation"
                    message = "Propriedade '$($group.Name)' repetida $($group.Count) vezes"
                    suggestion = "Considere consolidar em classes reutilizáveis"
                    impact = "low"
                })
            }
        }
    }

    [void] CheckCSSPerformance([string]$content) {
        # Detectar seletores complexos
        $complexSelectors = [regex]::Matches($content, '[^{]+\s+[^{]+\s+[^{]+\s+[^{]+\s*{')
        if ($complexSelectors.Count -gt 0) {
            $this.suggestions.Add(@{
                type = "performance"
                message = "$($complexSelectors.Count) seletor(es) muito específico(s) detectado(s)"
                suggestion = "Simplifique seletores para melhor performance"
                impact = "medium"
            })
        }
    }

    # Verificações JavaScript
    [void] CheckJSSyntax([string]$content) {
        # Verificar parênteses balanceados
        $openParens = ($content.ToCharArray() | Where-Object { $_ -eq '(' }).Count
        $closeParens = ($content.ToCharArray() | Where-Object { $_ -eq ')' }).Count
        
        if ($openParens -ne $closeParens) {
            $this.issues.Add(@{
                type = "syntax_error"
                severity = "high"
                message = "Parênteses não balanceados"
                suggestion = "Verifique e corrija os parênteses"
            })
        }
    }

    [void] CalculateComplexity([string]$content) {
        # Calcular complexidade ciclomática básica
        $complexityKeywords = @('if', 'else', 'for', 'while', 'switch', 'case', 'catch', '&&', '||', '?')
        $complexity = 1
        
        foreach ($keyword in $complexityKeywords) {
            $matches = [regex]::Matches($content, "\b$keyword\b", 'IgnoreCase')
            $complexity += $matches.Count
        }
        
        $this.metrics['complexity'] = $complexity
        
        if ($complexity -gt $this.config.thresholds.max_js_complexity) {
            $this.suggestions.Add(@{
                type = "complexity"
                message = "Complexidade alta detectada ($complexity)"
                suggestion = "Refatore em funções menores para reduzir complexidade"
                impact = "high"
            })
        }
    }

    [void] DetectUnusedVariables([string]$content) {
        # Detectar variáveis declaradas mas não utilizadas (análise básica)
        $declarations = [regex]::Matches($content, '(?:var|let|const)\s+([a-zA-Z_$][a-zA-Z0-9_$]*)')
        
        foreach ($decl in $declarations) {
            $varName = $decl.Groups[1].Value
            $usage = [regex]::Matches($content, "\b$varName\b")
            
            if ($usage.Count -eq 1) { # Apenas a declaração
                $this.suggestions.Add(@{
                    type = "cleanup"
                    message = "Variável '$varName' declarada mas não utilizada"
                    suggestion = "Remova variáveis não utilizadas"
                    impact = "low"
                })
            }
        }
    }

    [void] AnalyzeAsyncPatterns([string]$content) {
        # Verificar uso de async/await vs Promises
        $promises = [regex]::Matches($content, '\.then\(')
        $asyncAwait = [regex]::Matches($content, '\basync\b|\bawait\b')
        
        if ($promises.Count -gt 3 -and $asyncAwait.Count -eq 0) {
            $this.suggestions.Add(@{
                type = "modernization"
                message = "Múltiplas Promises detectadas sem async/await"
                suggestion = "Considere usar async/await para melhor legibilidade"
                impact = "medium"
            })
        }
    }

    [void] SuggestJSOptimizations([string]$content) {
        # Detectar loops que podem ser otimizados
        $forLoops = [regex]::Matches($content, 'for\s*\([^)]*\)')
        if ($forLoops.Count -gt 0) {
            $this.suggestions.Add(@{
                type = "optimization"
                message = "$($forLoops.Count) loop(s) tradicional(is) detectado(s)"
                suggestion = "Considere usar forEach, map, filter para melhor performance"
                impact = "medium"
            })
        }

        # Detectar concatenação de strings em loops
        if ($content -match 'for.*\+.*=.*\+') {
            $this.suggestions.Add(@{
                type = "performance"
                message = "Concatenação de string em loop detectada"
                suggestion = "Use array.join() ou template literals para melhor performance"
                impact = "high"
            })
        }
    }

    # Gerar relatório final
    [hashtable] GenerateReport([string]$fileType) {
        $score = $this.CalculateScore()
        
        return @{
            file_type = $fileType
            metrics = $this.metrics
            issues = $this.issues.ToArray()
            suggestions = $this.suggestions.ToArray()
            score = $score
            status = if ($score -ge $this.config.thresholds.min_performance_score) { "PASS" } else { "REVIEW" }
        }
    }

    [int] CalculateScore() {
        $baseScore = 100
        $deductions = 0
        
        foreach ($issue in $this.issues) {
            switch ($issue.severity) {
                "high" { $deductions += 15 }
                "medium" { $deductions += 8 }
                "low" { $deductions += 3 }
            }
        }
        
        foreach ($suggestion in $this.suggestions) {
            switch ($suggestion.impact) {
                "high" { $deductions += 5 }
                "medium" { $deductions += 2 }
                "low" { $deductions += 1 }
            }
        }
        
        return [math]::Max(0, $baseScore - $deductions)
    }
}

# Função principal de análise
function Invoke-CodeAnalysis {
    param(
        [string]$FilePath,
        [string]$FileType,
        [hashtable]$Config
    )
    
    try {
        $content = Get-Content -Path $FilePath -Raw -Encoding UTF8
        $analyzer = [CodeAnalyzer]::new($Config)
        
        $result = switch ($FileType.ToLower()) {
            "html" { $analyzer.AnalyzeHTML($content, $FilePath) }
            "css" { $analyzer.AnalyzeCSS($content, $FilePath) }
            "js" { $analyzer.AnalyzeJavaScript($content, $FilePath) }
            "javascript" { $analyzer.AnalyzeJavaScript($content, $FilePath) }
            default { 
                @{
                    file_type = $FileType
                    status = "SKIP"
                    message = "Tipo de arquivo não suportado"
                }
            }
        }
        
        return $result
    }
    catch {
        return @{
            file_type = $FileType
            status = "ERROR"
            message = $_.Exception.Message
        }
    }
}

# Executar análise se chamado diretamente
if ($FilePath -and $FileType -and $Config) {
    $result = Invoke-CodeAnalysis -FilePath $FilePath -FileType $FileType -Config $Config
    return $result
}