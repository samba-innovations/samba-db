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
CREATE TYPE samba_edvance.exam_status AS ENUM (
  'draft', 'collecting', 'review', 'locked',
  'generated', 'published', 'archived', 'open', 'closed', 'graded'
);

-- ---------------------------------------------------------------------------
-- skills — habilidades da BNCC
-- ---------------------------------------------------------------------------

CREATE TABLE samba_edvance.skills (
    id          SERIAL       PRIMARY KEY,
    code        VARCHAR(20)  NOT NULL UNIQUE,
    description TEXT         NOT NULL,
    area        VARCHAR(100),
    level       VARCHAR(50)
);

-- ---------------------------------------------------------------------------
-- items — banco de questões (legado)
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
-- blueprints — matrizes de referência
-- ---------------------------------------------------------------------------

CREATE TABLE samba_edvance.blueprints (
    id            SERIAL       PRIMARY KEY,
    name          VARCHAR(200) NOT NULL,
    description   TEXT,
    owner_id      INTEGER      REFERENCES samba_school.users(id) ON DELETE SET NULL,
    config_json   TEXT         NOT NULL,
    created_at    TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

-- ---------------------------------------------------------------------------
-- exams — simulados
-- ---------------------------------------------------------------------------

CREATE TABLE samba_edvance.exams (
    id            SERIAL                    PRIMARY KEY,
    title         VARCHAR(200)              NOT NULL,
    area          VARCHAR(200),
    options_count INTEGER                   NOT NULL DEFAULT 4,
    answer_source VARCHAR(50)               NOT NULL DEFAULT 'teacher',
    class_id      INTEGER                   REFERENCES samba_school.school_classes(id) ON DELETE SET NULL,
    blueprint_id  INTEGER                   REFERENCES samba_edvance.blueprints(id)    ON DELETE SET NULL,
    status        samba_edvance.exam_status NOT NULL DEFAULT 'draft',
    created_by    INTEGER                   REFERENCES samba_school.users(id) ON DELETE SET NULL,
    opened_at     TIMESTAMPTZ,
    closed_at     TIMESTAMPTZ,
    created_at    TIMESTAMPTZ               NOT NULL DEFAULT NOW()
);

-- ---------------------------------------------------------------------------
-- exam_class_assignments — turmas vinculadas ao simulado
-- ---------------------------------------------------------------------------

CREATE TABLE samba_edvance.exam_class_assignments (
    id        SERIAL  PRIMARY KEY,
    exam_id   INTEGER NOT NULL REFERENCES samba_edvance.exams(id) ON DELETE CASCADE,
    class_id  INTEGER NOT NULL REFERENCES samba_school.school_classes(id) ON DELETE CASCADE,
    UNIQUE (exam_id, class_id)
);

CREATE INDEX ix_eca_exam  ON samba_edvance.exam_class_assignments (exam_id);
CREATE INDEX ix_eca_class ON samba_edvance.exam_class_assignments (class_id);

-- ---------------------------------------------------------------------------
-- exam_discipline_quotas — cotas de questões por disciplina
-- ---------------------------------------------------------------------------

CREATE TABLE samba_edvance.exam_discipline_quotas (
    id            SERIAL  PRIMARY KEY,
    exam_id       INTEGER NOT NULL REFERENCES samba_edvance.exams(id) ON DELETE CASCADE,
    discipline_id INTEGER NOT NULL REFERENCES samba_school.disciplines(id) ON DELETE CASCADE,
    quota         INTEGER NOT NULL DEFAULT 0,
    UNIQUE (exam_id, discipline_id)
);

CREATE INDEX ix_edq_exam       ON samba_edvance.exam_discipline_quotas (exam_id);
CREATE INDEX ix_edq_discipline ON samba_edvance.exam_discipline_quotas (discipline_id);

-- ---------------------------------------------------------------------------
-- exam_teacher_assignments — professores atribuídos por disciplina/turma
-- ---------------------------------------------------------------------------

CREATE TABLE samba_edvance.exam_teacher_assignments (
    id            SERIAL  PRIMARY KEY,
    exam_id       INTEGER NOT NULL REFERENCES samba_edvance.exams(id) ON DELETE CASCADE,
    class_id      INTEGER NOT NULL REFERENCES samba_school.school_classes(id) ON DELETE CASCADE,
    discipline_id INTEGER NOT NULL REFERENCES samba_school.disciplines(id) ON DELETE CASCADE,
    teacher_id    INTEGER NOT NULL REFERENCES samba_school.users(id) ON DELETE CASCADE,
    UNIQUE (exam_id, class_id, discipline_id)
);

CREATE INDEX ix_eta_exam     ON samba_edvance.exam_teacher_assignments (exam_id);
CREATE INDEX ix_eta_teacher  ON samba_edvance.exam_teacher_assignments (teacher_id);

-- ---------------------------------------------------------------------------
-- exam_teacher_progress — progresso de envio de questões por professor
-- ---------------------------------------------------------------------------

CREATE TABLE samba_edvance.exam_teacher_progress (
    id            SERIAL      PRIMARY KEY,
    exam_id       INTEGER     NOT NULL REFERENCES samba_edvance.exams(id) ON DELETE CASCADE,
    teacher_id    INTEGER     NOT NULL REFERENCES samba_school.users(id) ON DELETE CASCADE,
    discipline_id INTEGER     NOT NULL REFERENCES samba_school.disciplines(id) ON DELETE CASCADE,
    class_id      INTEGER     NOT NULL REFERENCES samba_school.school_classes(id) ON DELETE CASCADE,
    quota         INTEGER     NOT NULL DEFAULT 0,
    submitted     INTEGER     NOT NULL DEFAULT 0,
    status        VARCHAR(20) NOT NULL DEFAULT 'pending',  -- pending, partial, complete, done
    updated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (exam_id, teacher_id, discipline_id, class_id)
);

CREATE INDEX ix_etp_exam    ON samba_edvance.exam_teacher_progress (exam_id);
CREATE INDEX ix_etp_teacher ON samba_edvance.exam_teacher_progress (teacher_id);

-- ---------------------------------------------------------------------------
-- exam_progress_log — log de eventos de envio
-- ---------------------------------------------------------------------------

CREATE TABLE samba_edvance.exam_progress_log (
    id             SERIAL      PRIMARY KEY,
    exam_id        INTEGER     NOT NULL REFERENCES samba_edvance.exams(id) ON DELETE CASCADE,
    teacher_id     INTEGER     REFERENCES samba_school.users(id) ON DELETE SET NULL,
    discipline_id  INTEGER     REFERENCES samba_school.disciplines(id) ON DELETE SET NULL,
    class_id       INTEGER     REFERENCES samba_school.school_classes(id) ON DELETE SET NULL,
    question_id    INTEGER,
    event_type     VARCHAR(50) NOT NULL,
    submitted_snap INTEGER,
    created_at     TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX ix_epl_exam ON samba_edvance.exam_progress_log (exam_id);

-- ---------------------------------------------------------------------------
-- questions — questões manuais/docx enviadas pelos professores
-- ---------------------------------------------------------------------------

CREATE TABLE samba_edvance.questions (
    id            SERIAL      PRIMARY KEY,
    exam_id       INTEGER     NOT NULL REFERENCES samba_edvance.exams(id) ON DELETE CASCADE,
    teacher_id    INTEGER     REFERENCES samba_school.users(id) ON DELETE SET NULL,
    discipline_id INTEGER     NOT NULL REFERENCES samba_school.disciplines(id) ON DELETE CASCADE,
    class_id      INTEGER     NOT NULL REFERENCES samba_school.school_classes(id) ON DELETE CASCADE,
    stem          TEXT        NOT NULL,
    state         VARCHAR(20) NOT NULL DEFAULT 'submitted',  -- submitted, approved, rejected
    source        VARCHAR(20) NOT NULL DEFAULT 'manual',     -- manual, docx
    correct_label VARCHAR(5),
    images        TEXT        NOT NULL DEFAULT '[]',         -- JSON array ou objeto estruturado
    created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX ix_questions_exam       ON samba_edvance.questions (exam_id);
CREATE INDEX ix_questions_teacher    ON samba_edvance.questions (teacher_id);
CREATE INDEX ix_questions_discipline ON samba_edvance.questions (discipline_id);

-- ---------------------------------------------------------------------------
-- question_options — alternativas das questões
-- ---------------------------------------------------------------------------

CREATE TABLE samba_edvance.question_options (
    id          SERIAL      PRIMARY KEY,
    question_id INTEGER     NOT NULL REFERENCES samba_edvance.questions(id) ON DELETE CASCADE,
    label       VARCHAR(5)  NOT NULL,
    text        TEXT        NOT NULL DEFAULT '',
    UNIQUE (question_id, label)
);

CREATE INDEX ix_qo_question ON samba_edvance.question_options (question_id);

-- ---------------------------------------------------------------------------
-- exam_questions — questões incluídas em um simulado (legado)
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
    exam_id      INTEGER     NOT NULL REFERENCES samba_edvance.exams(id)          ON DELETE CASCADE,
    student_id   INTEGER     NOT NULL REFERENCES samba_school.students(id)        ON DELETE CASCADE,
    question_id  INTEGER     NOT NULL REFERENCES samba_edvance.exam_questions(id) ON DELETE CASCADE,
    answer       VARCHAR(10),
    is_correct   BOOLEAN,
    answered_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (exam_id, student_id, question_id)
);

CREATE INDEX ix_student_answers_exam    ON samba_edvance.student_answers (exam_id);
CREATE INDEX ix_student_answers_student ON samba_edvance.student_answers (student_id);

-- ---------------------------------------------------------------------------
-- notifications
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
-- exam_skills — habilidades vinculadas a um simulado (N:N)
-- ---------------------------------------------------------------------------

CREATE TABLE samba_edvance.exam_skills (
    exam_id  INTEGER NOT NULL REFERENCES samba_edvance.exams(id)  ON DELETE CASCADE,
    skill_id INTEGER NOT NULL REFERENCES samba_edvance.skills(id) ON DELETE CASCADE,
    PRIMARY KEY (exam_id, skill_id)
);

CREATE INDEX ix_exam_skills_exam  ON samba_edvance.exam_skills (exam_id);
CREATE INDEX ix_exam_skills_skill ON samba_edvance.exam_skills (skill_id);

-- ---------------------------------------------------------------------------
-- question_skills — habilidades vinculadas a uma questão (N:N)
-- ---------------------------------------------------------------------------

CREATE TABLE samba_edvance.question_skills (
    question_id INTEGER NOT NULL REFERENCES samba_edvance.items(id) ON DELETE CASCADE,
    skill_id    INTEGER NOT NULL REFERENCES samba_edvance.skills(id) ON DELETE CASCADE,
    PRIMARY KEY (question_id, skill_id)
);

CREATE INDEX ix_question_skills_question ON samba_edvance.question_skills (question_id);
CREATE INDEX ix_question_skills_skill    ON samba_edvance.question_skills (skill_id);
