-- =============================================================================
-- 04b_samba_paper.sql — Schema samba_paper
-- =============================================================================
-- Gerador de documentos pedagógicos: planos de aula, guias, PEI, eletivas,
-- EMA, projetos e PDI.
--
-- Depende de: 02_samba_school.sql (FK para samba_school.users)
-- =============================================================================

CREATE SCHEMA IF NOT EXISTS samba_paper;

-- ---------------------------------------------------------------------------
-- Tipos enumerados
-- ---------------------------------------------------------------------------

CREATE TYPE samba_paper.document_type AS ENUM (
    'plano_de_aula',
    'guia_de_aprendizagem',
    'pei',
    'plano_de_eletiva',
    'plano_ema',
    'projeto',
    'pdi'
);

CREATE TYPE samba_paper.document_status AS ENUM ('draft', 'final');

-- ---------------------------------------------------------------------------
-- documents — documentos pedagógicos criados pelos professores
-- ---------------------------------------------------------------------------

CREATE TABLE samba_paper.documents (
    id         SERIAL                      PRIMARY KEY,
    user_id    INTEGER                     NOT NULL REFERENCES samba_school.users(id) ON DELETE CASCADE,
    type       samba_paper.document_type   NOT NULL,
    title      VARCHAR(300)                NOT NULL,
    content    JSONB                       NOT NULL DEFAULT '{}',
    pdf_path   VARCHAR(500),
    status     samba_paper.document_status NOT NULL DEFAULT 'draft',
    created_at TIMESTAMPTZ                 NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ                 NOT NULL DEFAULT NOW()
);

CREATE INDEX ix_documents_user_id ON samba_paper.documents (user_id);
CREATE INDEX ix_documents_type    ON samba_paper.documents (type);
CREATE INDEX ix_documents_status  ON samba_paper.documents (status);

-- ---------------------------------------------------------------------------
-- aulas — currículo SEDUC (preenchido via seed_paper_aulas.sql)
-- ---------------------------------------------------------------------------

CREATE TABLE samba_paper.aulas (
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

CREATE INDEX ix_aulas_disciplina ON samba_paper.aulas (disciplina_nome);
CREATE INDEX ix_aulas_serie_bim  ON samba_paper.aulas (ciclo, serie, bimestre);

-- ---------------------------------------------------------------------------
-- instrumentos_avaliativos
-- ---------------------------------------------------------------------------

CREATE TABLE samba_paper.instrumentos_avaliativos (
    id        SERIAL       PRIMARY KEY,
    nome      VARCHAR(200) NOT NULL,
    descricao TEXT,
    categoria VARCHAR(100)
);

-- ---------------------------------------------------------------------------
-- bimestres — calendário letivo anual
-- ---------------------------------------------------------------------------

CREATE TABLE samba_paper.bimestres (
    id          SERIAL      PRIMARY KEY,
    ano         SMALLINT    NOT NULL,
    numero      SMALLINT    NOT NULL,
    label       VARCHAR(30) NOT NULL,
    data_inicio DATE        NOT NULL,
    data_fim    DATE        NOT NULL,
    UNIQUE (ano, numero)
);
