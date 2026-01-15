# Estágio 1: Builder (Compilação de dependências)
FROM python:3.11-slim as builder

WORKDIR /app

# Variáveis para evitar cache do pip e bytecode
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

COPY requirements.txt .
# Instala dependências em um diretório local
RUN pip install --user --no-cache-dir -r requirements.txt

# Estágio 2: Runner (Imagem final leve)
FROM python:3.11-slim

WORKDIR /app

# Criação de usuário não-root (Segurança)
RUN addgroup --system appgroup && adduser --system --group appuser

# Copia apenas as bibliotecas instaladas do estágio anterior
COPY --from=builder /root/.local /root/.local
COPY . .

# Garante que scripts Python estejam no PATH
ENV PATH=/root/.local/bin:$PATH

# Muda para o usuário restrito
USER appuser

# Exposição da porta (documental)
EXPOSE 8000

# Comando de inicialização
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
