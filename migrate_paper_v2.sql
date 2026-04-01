-- =============================================================================
-- migrate_paper_v2.sql — Migração samba_paper para bancos existentes
-- =============================================================================
-- Idempotente: seguro rodar múltiplas vezes (IF NOT EXISTS em tudo).
-- Para installs do zero, o init/04b_samba_paper.sql já cobre tudo.
-- =============================================================================

CREATE SCHEMA IF NOT EXISTS samba_paper;

-- ---------------------------------------------------------------------------
-- Tipos enumerados
-- ---------------------------------------------------------------------------

DO $$ BEGIN
    CREATE TYPE samba_paper."DocumentType" AS ENUM (
        'plano_de_aula',
        'guia_de_aprendizagem',
        'pei',
        'plano_de_eletiva',
        'plano_ema',
        'projeto',
        'pdi'
    );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
    CREATE TYPE samba_paper."DocumentStatus" AS ENUM ('draft', 'final');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- ---------------------------------------------------------------------------
-- documents
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS samba_paper.documents (
    id         SERIAL                      PRIMARY KEY,
    user_id    INTEGER                     NOT NULL REFERENCES samba_school.users(id) ON DELETE CASCADE,
    type       samba_paper."DocumentType"   NOT NULL,
    title      VARCHAR(300)                NOT NULL,
    content    JSONB                       NOT NULL DEFAULT '{}',
    pdf_path   VARCHAR(500),
    status     samba_paper."DocumentStatus" NOT NULL DEFAULT 'draft',
    created_at TIMESTAMPTZ                 NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ                 NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS ix_documents_user_id ON samba_paper.documents (user_id);
CREATE INDEX IF NOT EXISTS ix_documents_type    ON samba_paper.documents (type);
CREATE INDEX IF NOT EXISTS ix_documents_status  ON samba_paper.documents (status);

-- ---------------------------------------------------------------------------
-- aulas — currículo SEDUC (populado pelo seed_paper_aulas.sql)
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS samba_paper.aulas (
    id                  SERIAL       PRIMARY KEY,
    ciclo               VARCHAR(30)  NOT NULL,
    serie               VARCHAR(10)  NOT NULL,
    bimestre            SMALLINT     NOT NULL,
    aula_num            SMALLINT     NOT NULL,
    disciplina_nome     VARCHAR(200) NOT NULL,
    eixo                VARCHAR(400),
    unidade_tematica    VARCHAR(400),
    habilidade_codigo   VARCHAR(200),
    habilidade_texto    TEXT,
    objeto_conhecimento VARCHAR(400),
    titulo              VARCHAR(400) NOT NULL,
    conteudo            TEXT,
    objetivos           TEXT,
    bloco               VARCHAR(200)
);

CREATE INDEX IF NOT EXISTS ix_aulas_disciplina ON samba_paper.aulas (disciplina_nome);
CREATE INDEX IF NOT EXISTS ix_aulas_serie_bim  ON samba_paper.aulas (ciclo, serie, bimestre);

-- ---------------------------------------------------------------------------
-- instrumentos_avaliativos
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS samba_paper.instrumentos_avaliativos (
    id        SERIAL       PRIMARY KEY,
    nome      VARCHAR(200) NOT NULL,
    descricao TEXT,
    categoria VARCHAR(100)
);

-- ---------------------------------------------------------------------------
-- bimestres
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS samba_paper.bimestres (
    id          SERIAL      PRIMARY KEY,
    ano         SMALLINT    NOT NULL,
    numero      SMALLINT    NOT NULL,
    label       VARCHAR(30) NOT NULL,
    data_inicio DATE        NOT NULL,
    data_fim    DATE        NOT NULL,
    UNIQUE (ano, numero)
);

-- ---------------------------------------------------------------------------
-- Permissões para samba_paper_user
-- ---------------------------------------------------------------------------

DO $$ BEGIN
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'samba_paper_user') THEN
        CREATE USER samba_paper_user WITH PASSWORD 'paper2025';
    END IF;
END $$;

GRANT USAGE ON SCHEMA samba_school TO samba_paper_user;
GRANT USAGE ON SCHEMA samba_paper  TO samba_paper_user;
GRANT SELECT ON ALL TABLES IN SCHEMA samba_school TO samba_paper_user;
GRANT ALL PRIVILEGES ON ALL TABLES    IN SCHEMA samba_paper TO samba_paper_user;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA samba_paper TO samba_paper_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA samba_paper GRANT ALL ON TABLES    TO samba_paper_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA samba_paper GRANT ALL ON SEQUENCES TO samba_paper_user;
