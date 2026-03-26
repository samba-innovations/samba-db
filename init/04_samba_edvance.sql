-- =============================================================================
-- 04_samba_edvance.sql — Schema exclusivo do simulador/avaliações
-- =============================================================================
-- Disciplinas e alunos vêm de samba_school.
-- Este schema pertence somente ao samba-edvance.
-- =============================================================================

CREATE SCHEMA IF NOT EXISTS samba_edvance;

-- ---------------------------------------------------------------------------
-- Tipos enumerados
-- ---------------------------------------------------------------------------

CREATE TYPE samba_edvance.difficulty AS ENUM ('EASY', 'MEDIUM', 'HARD');
CREATE TYPE samba_edvance.item_type  AS ENUM ('MULTIPLE_CHOICE', 'DISCURSIVE', 'NUMERIC');
CREATE TYPE samba_edvance.exam_status AS ENUM ('draft', 'open', 'closed', 'graded');

-- ---------------------------------------------------------------------------
-- skills — habilidades da BNCC (base geral, sem vínculo obrigatório com disciplina)
-- ---------------------------------------------------------------------------

CREATE TABLE samba_edvance.skills (
    id          SERIAL       PRIMARY KEY,
    code        VARCHAR(20)  NOT NULL UNIQUE,
    description TEXT         NOT NULL,
    area        VARCHAR(100),   -- área de conhecimento (ex: Matemática, Arte)
    level       VARCHAR(50)     -- Ensino Fundamental / Ensino Médio
);

-- ---------------------------------------------------------------------------
-- items — banco de questões
-- ---------------------------------------------------------------------------

CREATE TABLE samba_edvance.items (
    id             SERIAL                     PRIMARY KEY,
    owner_id       INTEGER                    REFERENCES samba_school.users(id) ON DELETE SET NULL,
    discipline_id  INTEGER                    NOT NULL REFERENCES samba_school.disciplines(id) ON DELETE CASCADE,
    skill_id       INTEGER                    REFERENCES samba_edvance.skills(id) ON DELETE SET NULL,
    serie          VARCHAR(20)                NOT NULL,
    difficulty     samba_edvance.difficulty   NOT NULL,
    item_type      samba_edvance.item_type    NOT NULL,
    stem           TEXT                       NOT NULL,
    options_json   TEXT,
    numeric_answer VARCHAR(50),
    media_url      VARCHAR(255),
    latex          BOOLEAN                    NOT NULL DEFAULT FALSE,
    created_at     TIMESTAMPTZ                NOT NULL DEFAULT NOW()
);

CREATE INDEX ix_items_discipline ON samba_edvance.items (discipline_id);
CREATE INDEX ix_items_serie      ON samba_edvance.items (serie);

-- ---------------------------------------------------------------------------
-- blueprints — matrizes de referência para geração de simulados
-- ---------------------------------------------------------------------------

CREATE TABLE samba_edvance.blueprints (
    id            SERIAL       PRIMARY KEY,
    name          VARCHAR(200) NOT NULL,
    description   TEXT,
    owner_id      INTEGER      REFERENCES samba_school.users(id) ON DELETE SET NULL,
    config_json   TEXT         NOT NULL,  -- JSON com distribuição de habilidades/dificuldades
    created_at    TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

-- ---------------------------------------------------------------------------
-- exams — simulados gerados
-- ---------------------------------------------------------------------------

CREATE TABLE samba_edvance.exams (
    id           SERIAL                    PRIMARY KEY,
    title        VARCHAR(200)              NOT NULL,
    class_id     INTEGER                   REFERENCES samba_school.school_classes(id) ON DELETE SET NULL,
    blueprint_id INTEGER                   REFERENCES samba_edvance.blueprints(id)    ON DELETE SET NULL,
    status       samba_edvance.exam_status NOT NULL DEFAULT 'draft',
    created_by   INTEGER                   REFERENCES samba_school.users(id) ON DELETE SET NULL,
    opened_at    TIMESTAMPTZ,
    closed_at    TIMESTAMPTZ,
    created_at   TIMESTAMPTZ               NOT NULL DEFAULT NOW()
);

-- ---------------------------------------------------------------------------
-- exam_questions — questões incluídas em um simulado
-- ---------------------------------------------------------------------------

CREATE TABLE samba_edvance.exam_questions (
    id          SERIAL  PRIMARY KEY,
    exam_id     INTEGER NOT NULL REFERENCES samba_edvance.exams(id) ON DELETE CASCADE,
    item_id     INTEGER NOT NULL REFERENCES samba_edvance.items(id) ON DELETE CASCADE,
    position    INTEGER NOT NULL,
    answer_key  VARCHAR(10),
    UNIQUE (exam_id, position)
);

-- ---------------------------------------------------------------------------
-- student_answers — respostas dos alunos
-- ---------------------------------------------------------------------------

CREATE TABLE samba_edvance.student_answers (
    id           SERIAL      PRIMARY KEY,
    exam_id      INTEGER     NOT NULL REFERENCES samba_edvance.exams(id)            ON DELETE CASCADE,
    student_id   INTEGER     NOT NULL REFERENCES samba_school.students(id)          ON DELETE CASCADE,
    question_id  INTEGER     NOT NULL REFERENCES samba_edvance.exam_questions(id)   ON DELETE CASCADE,
    answer       VARCHAR(10),
    is_correct   BOOLEAN,
    answered_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (exam_id, student_id, question_id)
);

CREATE INDEX ix_student_answers_exam    ON samba_edvance.student_answers (exam_id);
CREATE INDEX ix_student_answers_student ON samba_edvance.student_answers (student_id);

-- ---------------------------------------------------------------------------
-- notifications — notificações internas para usuários do samba-edvance
-- ---------------------------------------------------------------------------

CREATE TABLE samba_edvance.notifications (
    id         SERIAL       PRIMARY KEY,
    user_id    INTEGER      NOT NULL REFERENCES samba_school.users(id) ON DELETE CASCADE,
    title      VARCHAR(200) NOT NULL,
    message    TEXT,
    link       VARCHAR(500),
    is_read    BOOLEAN      NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE INDEX ix_edvance_notifications_user   ON samba_edvance.notifications (user_id);
CREATE INDEX ix_edvance_notifications_unread ON samba_edvance.notifications (user_id, is_read);

-- ---------------------------------------------------------------------------
-- question_skills — habilidades vinculadas a uma questão do professor (opcional, N:N)
-- ---------------------------------------------------------------------------

CREATE TABLE samba_edvance.question_skills (
    question_id INTEGER NOT NULL REFERENCES samba_edvance.questions(id) ON DELETE CASCADE,
    skill_id    INTEGER NOT NULL REFERENCES samba_edvance.skills(id)    ON DELETE CASCADE,
    PRIMARY KEY (question_id, skill_id)
);

CREATE INDEX ix_question_skills_question ON samba_edvance.question_skills (question_id);
CREATE INDEX ix_question_skills_skill    ON samba_edvance.question_skills (skill_id);
