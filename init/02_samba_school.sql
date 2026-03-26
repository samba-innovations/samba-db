-- =============================================================================
-- 02_samba_school.sql — Schema mestre compartilhado
-- =============================================================================
-- Contém todos os dados que pertencem à escola em si:
--   users, roles, students, classes, disciplines, teacher_assignments
--
-- TODOS os outros schemas fazem FK para cá.
-- Nunca apague este schema sem migrar os projetos dependentes.
-- =============================================================================

CREATE SCHEMA IF NOT EXISTS samba_school;

-- ---------------------------------------------------------------------------
-- Tipos enumerados
-- ---------------------------------------------------------------------------

CREATE TYPE samba_school.education_level AS ENUM ('fundamental', 'medio');

-- ---------------------------------------------------------------------------
-- roles — perfis de acesso do sistema
-- ---------------------------------------------------------------------------
-- ADMIN          → acesso total, gerencia usuários e sistema
-- TEACHER        → professor, cria ocorrências, entra no simulado
-- COORDINATOR    → coordenador pedagógico
-- PRINCIPAL      → diretor, resolve ocorrências, visão geral
-- VICE_PRINCIPAL → vice-diretor, mesmas permissões do diretor
-- SECRETARY      → secretaria, suporte administrativo

CREATE TABLE samba_school.roles (
    id   SERIAL      PRIMARY KEY,
    name VARCHAR(50) UNIQUE NOT NULL
);

-- ---------------------------------------------------------------------------
-- users — todos os usuários do sistema (auth centralizado)
-- ---------------------------------------------------------------------------

CREATE TABLE samba_school.users (
    id                   SERIAL       PRIMARY KEY,
    name                 VARCHAR(100) NOT NULL,
    email                VARCHAR(150) UNIQUE NOT NULL,
    password_hash        VARCHAR(255) NOT NULL,
    is_active            BOOLEAN      NOT NULL DEFAULT TRUE,
    must_change_password BOOLEAN      NOT NULL DEFAULT FALSE,
    is_admin             BOOLEAN      NOT NULL DEFAULT FALSE,
    created_at           TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE INDEX ix_users_email ON samba_school.users (email);

-- ---------------------------------------------------------------------------
-- user_roles — N:N usuário ↔ perfil
-- ---------------------------------------------------------------------------

CREATE TABLE samba_school.user_roles (
    user_id INTEGER NOT NULL REFERENCES samba_school.users(id) ON DELETE CASCADE,
    role_id INTEGER NOT NULL REFERENCES samba_school.roles(id) ON DELETE CASCADE,
    PRIMARY KEY (user_id, role_id)
);

-- ---------------------------------------------------------------------------
-- user_project_access — controle de acesso por projeto
-- ---------------------------------------------------------------------------

CREATE TABLE samba_school.user_project_access (
    user_id    INTEGER     NOT NULL REFERENCES samba_school.users(id) ON DELETE CASCADE,
    project    VARCHAR(30) NOT NULL CHECK (project IN ('code', 'edvance', 'flourish')),
    granted_by INTEGER     REFERENCES samba_school.users(id) ON DELETE SET NULL,
    granted_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (user_id, project)
);

CREATE INDEX ix_user_project_access_user ON samba_school.user_project_access (user_id);

-- ---------------------------------------------------------------------------
-- refresh_tokens — tokens de renovação JWT (compartilhado entre apps)
-- ---------------------------------------------------------------------------

CREATE TABLE samba_school.refresh_tokens (
    id         SERIAL      PRIMARY KEY,
    user_id    INTEGER     NOT NULL REFERENCES samba_school.users(id) ON DELETE CASCADE,
    token      TEXT        UNIQUE NOT NULL,
    expires_at TIMESTAMPTZ NOT NULL,
    revoked    BOOLEAN     NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX ix_refresh_tokens_user ON samba_school.refresh_tokens (user_id);

-- ---------------------------------------------------------------------------
-- disciplines — disciplinas curriculares (BNCC)
-- ---------------------------------------------------------------------------

CREATE TABLE samba_school.disciplines (
    id   SERIAL       PRIMARY KEY,
    name VARCHAR(150) UNIQUE NOT NULL
);

-- ---------------------------------------------------------------------------
-- school_grades — séries/anos escolares
-- ---------------------------------------------------------------------------

CREATE TABLE samba_school.school_grades (
    id          SERIAL                       PRIMARY KEY,
    level       samba_school.education_level NOT NULL,
    year_number INTEGER                      NOT NULL,
    label       VARCHAR(16)                  NOT NULL,
    UNIQUE (level, year_number)
);

-- ---------------------------------------------------------------------------
-- class_sections — letras das turmas (A, B, C, D...)
-- ---------------------------------------------------------------------------

CREATE TABLE samba_school.class_sections (
    id    SERIAL     PRIMARY KEY,
    label VARCHAR(8) UNIQUE NOT NULL
);

-- ---------------------------------------------------------------------------
-- school_classes — turma = série + seção  (ex: 3ªA)
-- ---------------------------------------------------------------------------

CREATE TABLE samba_school.school_classes (
    id         SERIAL       PRIMARY KEY,
    grade_id   INTEGER      NOT NULL REFERENCES samba_school.school_grades(id),
    section_id INTEGER      NOT NULL REFERENCES samba_school.class_sections(id),
    name       VARCHAR(32)  NOT NULL,
    UNIQUE (grade_id, section_id)
);

CREATE INDEX ix_school_classes_name ON samba_school.school_classes (name);

-- ---------------------------------------------------------------------------
-- class_disciplines — N:N turma ↔ disciplina
-- ---------------------------------------------------------------------------

CREATE TABLE samba_school.class_disciplines (
    class_id      INTEGER NOT NULL REFERENCES samba_school.school_classes(id) ON DELETE CASCADE,
    discipline_id INTEGER NOT NULL REFERENCES samba_school.disciplines(id)    ON DELETE CASCADE,
    PRIMARY KEY (class_id, discipline_id)
);

-- ---------------------------------------------------------------------------
-- students — alunos vinculados a uma turma
-- ---------------------------------------------------------------------------

CREATE TABLE samba_school.students (
    id             SERIAL       PRIMARY KEY,
    ra             VARCHAR(32)  UNIQUE NOT NULL,
    name           VARCHAR(160) NOT NULL,
    class_id       INTEGER      REFERENCES samba_school.school_classes(id),
    birth_date     DATE,
    guardian_name  VARCHAR(160),
    guardian_phone VARCHAR(20),
    is_active      BOOLEAN      NOT NULL DEFAULT TRUE,
    created_at     TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE INDEX ix_students_ra       ON samba_school.students (ra);
CREATE INDEX ix_students_class_id ON samba_school.students (class_id);

-- ---------------------------------------------------------------------------
-- teacher_assignments — professor leciona disciplina em turma
-- ---------------------------------------------------------------------------

CREATE TABLE samba_school.teacher_assignments (
    id            SERIAL  PRIMARY KEY,
    user_id       INTEGER NOT NULL REFERENCES samba_school.users(id)          ON DELETE CASCADE,
    class_id      INTEGER NOT NULL REFERENCES samba_school.school_classes(id) ON DELETE CASCADE,
    discipline_id INTEGER NOT NULL REFERENCES samba_school.disciplines(id)    ON DELETE CASCADE,
    UNIQUE (user_id, class_id, discipline_id)
);
