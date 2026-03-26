-- Migração: adiciona colunas area e level na tabela skills
-- e cria tabelas question_skills e notifications se não existirem

-- 1. Adicionar colunas à tabela skills existente
ALTER TABLE samba_edvance.skills
  ADD COLUMN IF NOT EXISTS area  VARCHAR(100),
  ADD COLUMN IF NOT EXISTS level VARCHAR(50);

-- 2. Criar tabela notifications se não existir
CREATE TABLE IF NOT EXISTS samba_edvance.notifications (
    id         SERIAL       PRIMARY KEY,
    user_id    INTEGER      NOT NULL REFERENCES samba_school.users(id) ON DELETE CASCADE,
    title      VARCHAR(200) NOT NULL,
    message    TEXT,
    link       VARCHAR(500),
    is_read    BOOLEAN      NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS ix_edvance_notifications_user   ON samba_edvance.notifications (user_id);
CREATE INDEX IF NOT EXISTS ix_edvance_notifications_unread ON samba_edvance.notifications (user_id, is_read);

-- 3. Criar tabela question_skills se não existir
CREATE TABLE IF NOT EXISTS samba_edvance.question_skills (
    question_id INTEGER NOT NULL REFERENCES samba_edvance.questions(id) ON DELETE CASCADE,
    skill_id    INTEGER NOT NULL REFERENCES samba_edvance.skills(id)    ON DELETE CASCADE,
    PRIMARY KEY (question_id, skill_id)
);

CREATE INDEX IF NOT EXISTS ix_question_skills_question ON samba_edvance.question_skills (question_id);
CREATE INDEX IF NOT EXISTS ix_question_skills_skill    ON samba_edvance.question_skills (skill_id);
