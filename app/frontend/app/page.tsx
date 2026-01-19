"use client";

import { useState, useEffect } from "react";

export default function Home() {
  const [apiStatus, setApiStatus] = useState<string>("Verificando...");

  useEffect(() => {
    const checkAPI = async () => {
      try {
        const apiUrl =
          process.env.NEXT_PUBLIC_API_URL || "http://localhost:8000";
        const response = await fetch(`${apiUrl}/health`);

        if (response.ok) {
          const data = await response.json();
          setApiStatus(`✅ API Online - ${data.message}`);
        } else {
          setApiStatus("❌ API com problemas");
        }
      } catch (error) {
        setApiStatus("❌ API não disponível");
      }
    };

    checkAPI();
  }, []);

  return (
    <main style={{ padding: "2rem", fontFamily: "Arial, sans-serif" }}>
      <h1>🧬 Biotech-X Platform</h1>
      <p>
        Plataforma de análise de espectrometria de massa para caracterização de
        proteínas
      </p>

      <div
        style={{
          background: "#f5f5f5",
          padding: "1rem",
          borderRadius: "8px",
          margin: "2rem 0",
        }}
      >
        <h2>Status do Sistema</h2>
        <p>
          <strong>API Backend:</strong> {apiStatus}
        </p>
        <p>
          <strong>Frontend:</strong> ✅ Online
        </p>
        <p>
          <strong>Ambiente:</strong> {process.env.NODE_ENV || "development"}
        </p>
      </div>

      <div
        style={{
          background: "#e8f4fd",
          padding: "1rem",
          borderRadius: "8px",
          border: "1px solid #b3d9ff",
        }}
      >
        <h3>🚀 Funcionalidades Planejadas</h3>
        <ul>
          <li>Upload de arquivos de espectrometria de massa</li>
          <li>Processamento automatizado com AWS Batch</li>
          <li>Análise e classificação de proteínas</li>
          <li>Dashboard de resultados</li>
          <li>Gestão de usuários e amostras</li>
        </ul>
      </div>

      <div style={{ marginTop: "2rem" }}>
        <h3>🔗 Links Úteis</h3>
        <ul>
          <li>
            <a href="/api/health" target="_blank">
              Health Check API
            </a>
          </li>
          <li>
            <a href="http://localhost:8000/docs" target="_blank">
              Documentação da API
            </a>
          </li>
          <li>
            <a
              href="https://github.com/rodnney/biotech-x-challenge"
              target="_blank"
            >
              Repositório GitHub
            </a>
          </li>
        </ul>
      </div>
    </main>
  );
}
