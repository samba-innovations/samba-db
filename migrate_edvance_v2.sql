-- =============================================================================
-- migrate_edvance_v2.sql — Migração incremental do schema samba_edvance
-- Aplica apenas alterações que ainda não existem no banco.
-- Seguro para rodar múltiplas vezes (idempotente).
-- =============================================================================

-- Novos valores no enum exam_status
DO $$ BEGIN
  ALTER TYPE samba_edvance.exam_status ADD VALUE IF NOT EXISTS 'collecting';
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN
  ALTER TYPE samba_edvance.exam_status ADD VALUE IF NOT EXISTS 'review';
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN
  ALTER TYPE samba_edvance.exam_status ADD VALUE IF NOT EXISTS 'locked';
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN
  ALTER TYPE samba_edvance.exam_status ADD VALUE IF NOT EXISTS 'generated';
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN
  ALTER TYPE samba_edvance.exam_status ADD VALUE IF NOT EXISTS 'archived';
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- Novas colunas em exams
ALTER TABLE samba_edvance.exams
  ADD COLUMN IF NOT EXISTS area          VARCHAR(200),
  ADD COLUMN IF NOT EXISTS options_count INTEGER NOT NULL DEFAULT 4,
  ADD COLUMN IF NOT EXISTS answer_source VARCHAR(50) NOT NULL DEFAULT 'teacher';

-- exam_class_assignments
CREATE TABLE IF NOT EXISTS samba_edvance.exam_class_assignments (
    id        SERIAL  PRIMARY KEY,
    exam_id   INTEGER NOT NULL REFERENCES samba_edvance.exams(id) ON DELETE CASCADE,
    class_id  INTEGER NOT NULL REFERENCES samba_school.school_classes(id) ON DELETE CASCADE,
    UNIQUE (exam_id, class_id)
);
CREATE INDEX IF NOT EXISTS ix_eca_exam  ON samba_edvance.exam_class_assignments (exam_id);
CREATE INDEX IF NOT EXISTS ix_eca_class ON samba_edvance.exam_class_assignments (class_id);

-- exam_discipline_quotas
CREATE TABLE IF NOT EXISTS samba_edvance.exam_discipline_quotas (
    id            SERIAL  PRIMARY KEY,
    exam_id       INTEGER NOT NULL REFERENCES samba_edvance.exams(id) ON DELETE CASCADE,
    discipline_id INTEGER NOT NULL REFERENCES samba_school.disciplines(id) ON DELETE CASCADE,
    quota         INTEGER NOT NULL DEFAULT 0,
    UNIQUE (exam_id, discipline_id)
);
CREATE INDEX IF NOT EXISTS ix_edq_exam       ON samba_edvance.exam_discipline_quotas (exam_id);
CREATE INDEX IF NOT EXISTS ix_edq_discipline ON samba_edvance.exam_discipline_quotas (discipline_id);

-- exam_teacher_assignments
CREATE TABLE IF NOT EXISTS samba_edvance.exam_teacher_assignments (
    id            SERIAL  PRIMARY KEY,
    exam_id       INTEGER NOT NULL REFERENCES samba_edvance.exams(id) ON DELETE CASCADE,
    class_id      INTEGER NOT NULL REFERENCES samba_school.school_classes(id) ON DELETE CASCADE,
    discipline_id INTEGER NOT NULL REFERENCES samba_school.disciplines(id) ON DELETE CASCADE,
    teacher_id    INTEGER NOT NULL REFERENCES samba_school.users(id) ON DELETE CASCADE,
    UNIQUE (exam_id, class_id, discipline_id)
);
CREATE INDEX IF NOT EXISTS ix_eta_exam    ON samba_edvance.exam_teacher_assignments (exam_id);
CREATE INDEX IF NOT EXISTS ix_eta_teacher ON samba_edvance.exam_teacher_assignments (teacher_id);

-- exam_teacher_progress
CREATE TABLE IF NOT EXISTS samba_edvance.exam_teacher_progress (
    id            SERIAL      PRIMARY KEY,
    exam_id       INTEGER     NOT NULL REFERENCES samba_edvance.exams(id) ON DELETE CASCADE,
    teacher_id    INTEGER     NOT NULL REFERENCES samba_school.users(id) ON DELETE CASCADE,
    discipline_id INTEGER     NOT NULL REFERENCES samba_school.disciplines(id) ON DELETE CASCADE,
    class_id      INTEGER     NOT NULL REFERENCES samba_school.school_classes(id) ON DELETE CASCADE,
    quota         INTEGER     NOT NULL DEFAULT 0,
    submitted     INTEGER     NOT NULL DEFAULT 0,
    status        VARCHAR(20) NOT NULL DEFAULT 'pending',
    updated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (exam_id, teacher_id, discipline_id, class_id)
);
CREATE INDEX IF NOT EXISTS ix_etp_exam    ON samba_edvance.exam_teacher_progress (exam_id);
CREATE INDEX IF NOT EXISTS ix_etp_teacher ON samba_edvance.exam_teacher_progress (teacher_id);

-- exam_progress_log
CREATE TABLE IF NOT EXISTS samba_edvance.exam_progress_log (
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
CREATE INDEX IF NOT EXISTS ix_epl_exam ON samba_edvance.exam_progress_log (exam_id);

-- questions
CREATE TABLE IF NOT EXISTS samba_edvance.questions (
    id            SERIAL      PRIMARY KEY,
    exam_id       INTEGER     NOT NULL REFERENCES samba_edvance.exams(id) ON DELETE CASCADE,
    teacher_id    INTEGER     REFERENCES samba_school.users(id) ON DELETE SET NULL,
    discipline_id INTEGER     NOT NULL REFERENCES samba_school.disciplines(id) ON DELETE CASCADE,
    class_id      INTEGER     NOT NULL REFERENCES samba_school.school_classes(id) ON DELETE CASCADE,
    stem          TEXT        NOT NULL,
    state         VARCHAR(20) NOT NULL DEFAULT 'submitted',
    source        VARCHAR(20) NOT NULL DEFAULT 'manual',
    correct_label VARCHAR(5),
    images        TEXT        NOT NULL DEFAULT '[]',
    created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS ix_questions_exam       ON samba_edvance.questions (exam_id);
CREATE INDEX IF NOT EXISTS ix_questions_teacher    ON samba_edvance.questions (teacher_id);
CREATE INDEX IF NOT EXISTS ix_questions_discipline ON samba_edvance.questions (discipline_id);

-- question_options
CREATE TABLE IF NOT EXISTS samba_edvance.question_options (
    id          SERIAL     PRIMARY KEY,
    question_id INTEGER    NOT NULL REFERENCES samba_edvance.questions(id) ON DELETE CASCADE,
    label       VARCHAR(5) NOT NULL,
    text        TEXT       NOT NULL DEFAULT '',
    UNIQUE (question_id, label)
);
CREATE INDEX IF NOT EXISTS ix_qo_question ON samba_edvance.question_options (question_id);
