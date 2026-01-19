biotech-x-challenge/
│
├── .github/                   # Workflows do GitHub Actions
│   └── workflows/
├── app/                       # Código da Aplicação
│   ├── backend/               # FastAPI (Python)
│   └── frontend/              # Next.js (JavaScript/TS)
│
├── infra/                     # Infraestrutura como Código
│   ├── main.tf                # O arquivo único solicitado
│   ├── variables.tf
│   └── outputs.tf             # (para outputs do Terraform)
│
├── docs/                      # Documentação para o GitHub Pages
│   └── index.md
│
├── .gitignore
├── .pre-commit-config.yaml    # Configuração dos Hooks
├── README.md
└── docker-compose.yml         # (Para rodar localmente)
