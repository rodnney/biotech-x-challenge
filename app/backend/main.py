from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
import os
import logging

# Configuração de logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Inicialização da aplicação
app = FastAPI(
    title="Biotech-X API",
    description="API para análise de espectrometria de massa",
    version="1.0.0",
    docs_url="/docs",
    redoc_url="/redoc",
)

# Configuração CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["http://localhost:3000", "http://frontend:3000"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


# Modelos Pydantic
class HealthResponse(BaseModel):
    status: str
    message: str
    environment: str


class AnalysisRequest(BaseModel):
    sample_name: str
    file_urls: list[str]
    analysis_type: str = "mass_spectrometry"


class AnalysisResponse(BaseModel):
    analysis_id: str
    status: str
    message: str


# Rotas
@app.get("/")
async def root():
    """Rota raiz da API"""
    return {"message": "Biotech-X API", "version": "1.0.0", "docs": "/docs"}


@app.get("/health", response_model=HealthResponse)
async def health_check():
    """Health check endpoint"""
    try:
        # Verificações básicas de saúde

        return HealthResponse(
            status="healthy",
            message="API funcionando corretamente",
            environment=os.getenv("ENVIRONMENT", "development"),
        )
    except Exception as e:
        logger.error(f"Health check failed: {e}")
        raise HTTPException(status_code=503, detail="Service unavailable")


@app.post("/api/v1/analysis", response_model=AnalysisResponse)
async def create_analysis(request: AnalysisRequest):
    """Criar nova análise de espectrometria de massa"""
    try:
        # Placeholder - implementar lógica real de análise
        analysis_id = f"analysis_{hash(request.sample_name)}"

        logger.info(f"Creating analysis for sample: {request.sample_name}")

        return AnalysisResponse(
            analysis_id=analysis_id,
            status="queued",
            message=f"Análise criada para amostra {request.sample_name}",
        )
    except Exception as e:
        logger.error(f"Failed to create analysis: {e}")
        raise HTTPException(status_code=500, detail="Failed to create analysis")


@app.get("/api/v1/analysis/{analysis_id}")
async def get_analysis(analysis_id: str):
    """Obter status de uma análise"""
    try:
        # Placeholder - implementar busca real
        return {
            "analysis_id": analysis_id,
            "status": "processing",
            "progress": 45,
            "created_at": "2024-01-19T10:00:00Z",
            "estimated_completion": "2024-01-19T11:30:00Z",
        }
    except Exception as e:
        logger.error(f"Failed to get analysis {analysis_id}: {e}")
        raise HTTPException(status_code=404, detail="Analysis not found")


if __name__ == "__main__":
    import uvicorn

    uvicorn.run(app, host="0.0.0.0", port=8000)
