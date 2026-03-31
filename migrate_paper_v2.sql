-- =============================================================================
-- migrate_paper_v2.sql — Tabelas de currículo para samba paper
-- Executar: docker exec -i samba_db psql -U postgres -d samba_db < migrate_paper_v2.sql
-- =============================================================================

-- ---------------------------------------------------------------------------
-- 1. Tabela de aulas (currículo scope & sequence)
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS samba_paper.aulas (
  id                SERIAL PRIMARY KEY,
  ciclo             VARCHAR(30)  NOT NULL, -- 'fundamental' | 'medio'
  serie             VARCHAR(10)  NOT NULL, -- '6','7','8','9','1','2','3'
  bimestre          SMALLINT     NOT NULL CHECK (bimestre BETWEEN 1 AND 4),
  aula_num          SMALLINT     NOT NULL,
  disciplina_nome   VARCHAR(200) NOT NULL,
  eixo              VARCHAR(400),
  unidade_tematica  VARCHAR(400),
  habilidade_codigo VARCHAR(200),
  habilidade_texto  TEXT,
  objeto_conhecimento VARCHAR(400),
  titulo            VARCHAR(400) NOT NULL,
  conteudo          TEXT,
  objetivos         TEXT,
  bloco             VARCHAR(200)
);

CREATE INDEX IF NOT EXISTS ix_aulas_disciplina ON samba_paper.aulas (disciplina_nome);
CREATE INDEX IF NOT EXISTS ix_aulas_serie_bim  ON samba_paper.aulas (ciclo, serie, bimestre);

GRANT SELECT ON samba_paper.aulas TO samba_paper_user;

-- ---------------------------------------------------------------------------
-- 2. Instrumentos avaliativos
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS samba_paper.instrumentos_avaliativos (
  id          SERIAL PRIMARY KEY,
  nome        VARCHAR(200) NOT NULL,
  descricao   TEXT,
  categoria   VARCHAR(100) -- 'escrita' | 'oral' | 'pratica' | 'projeto' | 'autoavaliacao'
);

GRANT SELECT ON samba_paper.instrumentos_avaliativos TO samba_paper_user;

INSERT INTO samba_paper.instrumentos_avaliativos (nome, descricao, categoria) VALUES
  ('Prova Escrita', 'Avaliação individual por escrito com questões objetivas e/ou dissertativas.', 'escrita'),
  ('Prova Oral', 'Avaliação por exposição oral do aluno ao professor.', 'oral'),
  ('Trabalho Escrito', 'Produção textual individual ou em grupo entregue pelo aluno.', 'escrita'),
  ('Seminário', 'Apresentação oral em grupo sobre tema estudado.', 'oral'),
  ('Portfólio', 'Coleção de produções do aluno ao longo do bimestre demonstrando evolução.', 'projeto'),
  ('Projeto Interdisciplinar', 'Trabalho de pesquisa ou criação envolvendo múltiplos componentes.', 'projeto'),
  ('Autoavaliação', 'Reflexão do próprio aluno sobre seu desempenho e aprendizagem.', 'autoavaliacao'),
  ('Avaliação Diagnóstica', 'Sondagem de conhecimentos prévios ao início da unidade.', 'escrita'),
  ('Questionário', 'Conjunto de perguntas sobre o conteúdo estudado.', 'escrita'),
  ('Apresentação de Pesquisa', 'Exposição oral ou escrita de pesquisa realizada pelo aluno.', 'oral'),
  ('Debate', 'Discussão estruturada entre alunos sobre tema proposto.', 'oral'),
  ('Relatório de Atividade Prática', 'Registro escrito de experimento ou atividade de laboratório/campo.', 'pratica'),
  ('Observação e Participação', 'Avaliação contínua da participação, engajamento e postura em aula.', 'pratica'),
  ('Resolução de Problemas', 'Exercícios e problemas aplicados ao conteúdo do bimestre.', 'escrita'),
  ('Produção Artística ou Cultural', 'Criação de obra, performance ou produto cultural avaliado por rubrica.', 'pratica'),
  ('Avaliação Prática / Experimental', 'Execução de atividade prática com observação direta do professor.', 'pratica'),
  ('Ficha de Leitura', 'Registro e análise de leitura realizada pelo aluno.', 'escrita'),
  ('Mapa Conceitual', 'Organização visual de conceitos e relações entre eles.', 'escrita'),
  ('Júri Simulado', 'Encenação de julgamento sobre tema controverso para desenvolvimento argumentativo.', 'oral'),
  ('Gincana do Conhecimento', 'Atividade lúdica e competitiva de revisão de conteúdo.', 'pratica')
ON CONFLICT DO NOTHING;

-- ---------------------------------------------------------------------------
-- 3. Bimestres 2026
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS samba_paper.bimestres (
  id          SERIAL PRIMARY KEY,
  ano         SMALLINT    NOT NULL,
  numero      SMALLINT    NOT NULL CHECK (numero BETWEEN 1 AND 4),
  label       VARCHAR(30) NOT NULL,
  data_inicio DATE        NOT NULL,
  data_fim    DATE        NOT NULL,
  UNIQUE (ano, numero)
);

GRANT SELECT ON samba_paper.bimestres TO samba_paper_user;

INSERT INTO samba_paper.bimestres (ano, numero, label, data_inicio, data_fim) VALUES
  (2026, 1, '1º Bimestre', '2026-02-03', '2026-04-11'),
  (2026, 2, '2º Bimestre', '2026-04-14', '2026-06-27'),
  (2026, 3, '3º Bimestre', '2026-07-28', '2026-09-26'),
  (2026, 4, '4º Bimestre', '2026-09-28', '2026-11-28')
ON CONFLICT DO NOTHING;

-- ---------------------------------------------------------------------------
-- 4. Permissão de leitura em samba_school.teacher_assignments para samba_paper_user
--    (o vínculo professor→disciplina→turma já existe em samba_school)
-- ---------------------------------------------------------------------------

GRANT SELECT ON samba_school.teacher_assignments TO samba_paper_user;
GRANT SELECT ON samba_school.class_disciplines   TO samba_paper_user;

-- Permissões de leitura nas sequences das novas tabelas
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA samba_paper TO samba_paper_user;
