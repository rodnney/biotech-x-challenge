# Script de Setup Local para Biotech-X Challenge (PowerShell)
# Configura ambiente de desenvolvimento com LocalStack e serviços locais

param(
    [switch]$SkipHealthCheck = $false
)

# Função para log colorido
function Write-Info {
    param([string]$Message)
    Write-Host "[INFO] $Message" -ForegroundColor Green
}

function Write-Warn {
    param([string]$Message)
    Write-Host "[WARN] $Message" -ForegroundColor Yellow
}

function Write-Error {
    param([string]$Message)
    Write-Host "[ERROR] $Message" -ForegroundColor Red
}

# Verificar dependências
function Test-Dependencies {
    Write-Info "Verificando dependências..."

    if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
        Write-Error "Docker não encontrado. Instale Docker Desktop."
        exit 1
    }

    if (-not (Get-Command docker-compose -ErrorAction SilentlyContinue)) {
        Write-Error "Docker Compose não encontrado."
        exit 1
    }

    Write-Info "✅ Dependências OK"
}

# Configurar arquivo .env
function Set-Environment {
    Write-Info "Configurando arquivo .env..."

    if (-not (Test-Path .env)) {
        Copy-Item .env.example .env
        Write-Info "✅ Arquivo .env criado a partir do .env.example"
    } else {
        Write-Warn "Arquivo .env já existe, mantendo configuração atual"
    }
}

# Inicializar serviços
function Start-Services {
    Write-Info "Iniciando serviços com Docker Compose..."

    # Parar serviços existentes
    docker-compose down --remove-orphans

    # Construir e iniciar
    docker-compose up --build -d

    Write-Info "⏳ Aguardando serviços ficarem prontos..."
    Start-Sleep -Seconds 30
}

# Verificar saúde dos serviços
function Test-ServiceHealth {
    if ($SkipHealthCheck) {
        Write-Warn "Verificação de saúde pulada"
        return
    }

    Write-Info "Verificando saúde dos serviços..."

    # PostgreSQL
    try {
        $pgResult = docker-compose exec -T postgres pg_isready -U admin_user -d biotech_db 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-Info "✅ PostgreSQL: OK"
        } else {
            Write-Error "❌ PostgreSQL: Falha"
        }
    } catch {
        Write-Error "❌ PostgreSQL: Erro na verificação"
    }

    # LocalStack
    try {
        $response = Invoke-WebRequest -Uri "http://localhost:4566/_localstack/health" -TimeoutSec 5 -ErrorAction Stop
        Write-Info "✅ LocalStack: OK"
    } catch {
        Write-Error "❌ LocalStack: Falha"
    }

    # Backend
    try {
        $response = Invoke-WebRequest -Uri "http://localhost:8000/health" -TimeoutSec 5 -ErrorAction Stop
        Write-Info "✅ Backend API: OK"
    } catch {
        Write-Error "❌ Backend API: Falha"
    }

    # Frontend
    try {
        $response = Invoke-WebRequest -Uri "http://localhost:3000" -TimeoutSec 5 -ErrorAction Stop
        Write-Info "✅ Frontend: OK"
    } catch {
        Write-Error "❌ Frontend: Falha"
    }
}

# Configurar recursos AWS no LocalStack
function Set-AWSResources {
    Write-Info "Configurando recursos AWS no LocalStack..."

    # Aguardar LocalStack estar pronto
    Start-Sleep -Seconds 10

    # Configurar variáveis de ambiente AWS
    $env:AWS_ACCESS_KEY_ID = "demo-access-key"
    $env:AWS_SECRET_ACCESS_KEY = "demo-secret-key"
    $env:AWS_DEFAULT_REGION = "us-east-1"
    $env:AWS_ENDPOINT_URL = "http://localhost:4566"

    # Criar buckets S3
    try {
        if (Get-Command aws -ErrorAction SilentlyContinue) {
            aws --endpoint-url=http://localhost:4566 s3 mb s3://biotech-input-local 2>$null
            aws --endpoint-url=http://localhost:4566 s3 mb s3://biotech-output-local 2>$null
            Write-Info "✅ Recursos AWS configurados no LocalStack"
        } else {
            Write-Warn "AWS CLI não disponível - buckets S3 não criados"
        }
    } catch {
        Write-Warn "Recursos AWS podem já existir ou AWS CLI não disponível"
    }
}

# Mostrar informações de acesso
function Show-AccessInfo {
    Write-Info "🎉 Ambiente configurado com sucesso!"
    Write-Host ""
    Write-Host "📋 Informações de Acesso:" -ForegroundColor Cyan
    Write-Host "  Frontend:     http://localhost:3000"
    Write-Host "  Backend API:  http://localhost:8000"
    Write-Host "  API Docs:     http://localhost:8000/docs"
    Write-Host "  PostgreSQL:   localhost:5432 (admin_user/ChangeMeInProduction123!)"
    Write-Host "  LocalStack:   http://localhost:4566"
    Write-Host "  MinIO:        http://localhost:9001 (minioadmin/minioadmin123)"
    Write-Host "  Redis:        localhost:6379"
    Write-Host ""
    Write-Host "🔧 Comandos úteis:" -ForegroundColor Cyan
    Write-Host "  Ver logs:     docker-compose logs -f"
    Write-Host "  Parar:        docker-compose down"
    Write-Host "  Rebuild:      docker-compose up --build"
    Write-Host ""
}

# Função principal
function Main {
    Write-Info "🚀 Configurando ambiente local Biotech-X..."

    Test-Dependencies
    Set-Environment
    Start-Services
    Set-AWSResources
    Test-ServiceHealth
    Show-AccessInfo
}

# Executar
Main
