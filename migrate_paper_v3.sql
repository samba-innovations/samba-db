-- =============================================================================
-- migrate_paper_v3.sql — Aprendizagens Essenciais (SP Currículo Priorizado)
-- Executar: docker exec -i samba_db psql -U postgres -d samba_db < migrate_paper_v3.sql
-- =============================================================================

-- ---------------------------------------------------------------------------
-- 1. Tabela aprendizagens_essenciais
--    Normaliza os códigos AE (AE1, AE2...) com suas descrições completas,
--    organizados por disciplina / ciclo / série / bimestre.
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS samba_paper.aprendizagens_essenciais (
  id              SERIAL       PRIMARY KEY,
  codigo          VARCHAR(20)  NOT NULL,         -- 'AE1', 'AE2', ...
  descricao       TEXT         NOT NULL,
  disciplina_nome VARCHAR(200) NOT NULL,
  ciclo           VARCHAR(30)  NOT NULL,          -- 'fundamental' | 'medio'
  serie           VARCHAR(10)  NOT NULL,           -- '6','7','8','9','1','2','3'
  bimestre        SMALLINT     NOT NULL CHECK (bimestre BETWEEN 1 AND 4),
  UNIQUE (codigo, disciplina_nome, ciclo, serie, bimestre)
);

CREATE INDEX IF NOT EXISTS ix_ae_disciplina_serie
  ON samba_paper.aprendizagens_essenciais (disciplina_nome, ciclo, serie, bimestre);

GRANT SELECT ON samba_paper.aprendizagens_essenciais TO samba_paper_user;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA samba_paper TO samba_paper_user;

-- ---------------------------------------------------------------------------
-- 2. Alargar habilidade_codigo em aulas para TEXT
--    (já feito em v2, mas garantir idempotência)
-- ---------------------------------------------------------------------------

ALTER TABLE samba_paper.aulas
  ALTER COLUMN habilidade_codigo TYPE TEXT;

-- ---------------------------------------------------------------------------
-- 3. Coluna habilidade_texto em aulas (descrição completa das habilidades BNCC)
--    Pode já existir se migrate_paper_v2 foi aplicado em versão anterior.
-- ---------------------------------------------------------------------------

ALTER TABLE samba_paper.aulas
  ADD COLUMN IF NOT EXISTS habilidade_texto TEXT;
