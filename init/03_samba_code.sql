-- =============================================================================
-- 03_samba_code.sql — Schema exclusivo do sistema de ocorrências
-- =============================================================================
-- Todas as FKs para usuários/alunos apontam para samba_school.
-- Este schema pertence somente ao samba-code.
-- =============================================================================

CREATE SCHEMA IF NOT EXISTS samba_code;

-- ---------------------------------------------------------------------------
-- Tipos enumerados
-- ---------------------------------------------------------------------------

CREATE TYPE samba_code.occurrence_status AS ENUM (
    'pending',      -- aguardando análise
    'in_progress',  -- sendo analisada pela direção
    'resolved',     -- resolvida
    'archived'      -- arquivada
);

CREATE TYPE samba_code.occurrence_severity AS ENUM (
    'low',      -- leve
    'medium',   -- moderada
    'high',     -- grave
    'critical'  -- gravíssima
);

-- ---------------------------------------------------------------------------
-- occurrences — ocorrências interdisciplinares
-- ---------------------------------------------------------------------------

CREATE TABLE samba_code.occurrences (
    id               SERIAL                         PRIMARY KEY,
    title            VARCHAR(200)                   NOT NULL,
    description      TEXT,
    category         VARCHAR(100),
    severity         samba_code.occurrence_severity NOT NULL DEFAULT 'medium',
    status           samba_code.occurrence_status   NOT NULL DEFAULT 'pending',

    -- quem criou (professor/secretaria)
    creator_id       INTEGER REFERENCES samba_school.users(id) ON DELETE SET NULL,

    -- quem resolveu (diretor)
    resolver_id      INTEGER REFERENCES samba_school.users(id) ON DELETE SET NULL,
    resolution_notes TEXT,
    resolved_at      TIMESTAMPTZ,

    -- arquivamento
    is_archived      BOOLEAN     NOT NULL DEFAULT FALSE,
    archived_at      TIMESTAMPTZ,
    archived_by      INTEGER     REFERENCES samba_school.users(id) ON DELETE SET NULL,

    created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at       TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX ix_occurrences_creator  ON samba_code.occurrences (creator_id);
CREATE INDEX ix_occurrences_status   ON samba_code.occurrences (status);
CREATE INDEX ix_occurrences_archived ON samba_code.occurrences (is_archived);

-- ---------------------------------------------------------------------------
-- occurrence_students — N:N ocorrência ↔ aluno
-- ---------------------------------------------------------------------------

CREATE TABLE samba_code.occurrence_students (
    occurrence_id INTEGER NOT NULL REFERENCES samba_code.occurrences(id)  ON DELETE CASCADE,
    student_id    INTEGER NOT NULL REFERENCES samba_school.students(id)   ON DELETE CASCADE,
    PRIMARY KEY (occurrence_id, student_id)
);

-- ---------------------------------------------------------------------------
-- notifications — notificações internas para usuários
-- ---------------------------------------------------------------------------

CREATE TABLE samba_code.notifications (
    id         SERIAL       PRIMARY KEY,
    user_id    INTEGER      NOT NULL REFERENCES samba_school.users(id) ON DELETE CASCADE,
    title      VARCHAR(200) NOT NULL,
    message    TEXT,
    link       VARCHAR(500),
    is_read    BOOLEAN      NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE INDEX ix_notifications_user   ON samba_code.notifications (user_id);
CREATE INDEX ix_notifications_unread ON samba_code.notifications (user_id, is_read);
