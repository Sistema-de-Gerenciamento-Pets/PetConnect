# Diagrama de Arquitetura — PetConnect (estado atual da migração)

> Substitui a visão implícita em `docs/arquitetura.md` (histórico,
> pré-migração). Este diagrama reflete o código real verificado em
> `docs/next-stage/` e `docs/migration/`.

```mermaid
flowchart TB
    subgraph Client["App Flutter"]
        UI["Telas (17)"]
        FF["Feature Flags\n(USE_API_*, default false)"]
    end

    subgraph Firebase["Firebase (só identidade)"]
        Auth["Firebase Authentication"]
    end

    subgraph Legacy["Legado (fallback até FASE 13)"]
        Firestore["Cloud Firestore\n(Rules endurecidas, FASE 11)"]
    end

    subgraph Backend["API Spring Boot (/api/v1)"]
        Sec["Filtro de auth\n(verifica ID Token)"]
        RL["Rate limiting\n(endpoints públicos: 30 leituras / 10 escritas por min)"]
        Ctrl["Controllers\n(users, pets, vaccines, appointments,\nmedical-records, locations, uploads)"]
        Pub["PublicPetController\n(sem auth, QR + avistamento)"]
    end

    subgraph Data["Dados"]
        Mongo["MongoDB\n(users, pets, vaccines, appointments,\nmedical_records, locations)"]
        Cloudinary["Cloudinary\n(upload assinado, pasta por tutor)"]
    end

    subgraph CI["CI (GitHub Actions)"]
        CIFlutter["Flutter: format + analyze + testes"]
        CIBackend["Backend: mvn test (Mongo embarcado)"]
    end

    subgraph Envs["Ambientes"]
        Dev["dev (local, Docker)"]
        Staging["staging — pendente de hospedagem"]
        Prod["produção — pendente de hospedagem"]
    end

    UI -->|login/token| Auth
    UI -->|"flag off"| Firestore
    UI -->|"flag on"| Sec
    FF -.decide.-> UI

    Sec -->|token verificado| Ctrl
    Ctrl --> Mongo
    Ctrl -->|"upload assinado"| Cloudinary
    RL --> Pub
    Pub --> Mongo

    CIFlutter -.valida cada push.-> Client
    CIBackend -.valida cada push.-> Backend

    Backend -.roda em.-> Dev
    Backend -.roda em.-> Staging
    Backend -.roda em.-> Prod

    style Legacy fill:#f5f5f5,stroke:#999,stroke-dasharray: 5 5
    style Staging fill:#fff8e1,stroke:#c9a227,stroke-dasharray: 5 5
    style Prod fill:#fff8e1,stroke:#c9a227,stroke-dasharray: 5 5
```

## Legenda

- **Legado (cinza, tracejado)**: Firestore continua ativo como rede de
  segurança para as features cuja flag ainda está desligada, e para os
  18 usuários reais que ainda não migraram pro app novo. Não será
  removido nesta etapa (FASE 13 é posterior e depende de validação real).
- **Ambientes staging/produção (amarelo, tracejado)**: hospedagem ainda
  não decidida — ver `docs/next-stage/02-infrastructure-decision.md`.
  Hoje, tudo roda em `dev` (Docker local).
- **CI**: verificado rodando de verdade no GitHub Actions nesta etapa
  (não é aspiracional) — ver `docs/next-stage/03-ci-quality-gates.md`.
- O app nunca acessa o MongoDB diretamente — só via a API, sempre.
