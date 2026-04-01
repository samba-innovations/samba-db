-- =============================================================================
-- 07_sso_tokens.sql — Tokens de handoff SSO entre sistemas
-- =============================================================================
-- Fluxo:
--   1. samba-access cria um token (TTL 30s) ao redirecionar para um sistema
--   2. O sistema destino valida o token, marca como usado e cria a sessão JWT
--
-- Isso permite SSO em dev (sem domínio compartilhado) e em produção.
-- =============================================================================

CREATE EXTENSION IF NOT EXISTS "pgcrypto";  -- para gen_random_uuid()

CREATE TABLE samba_school.sso_tokens (
    id         UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id    INTEGER     NOT NULL REFERENCES samba_school.users(id) ON DELETE CASCADE,
    target     VARCHAR(50) NOT NULL,   -- sistema destino: 'code', 'edvance', 'flourish'
    used       BOOLEAN     NOT NULL DEFAULT FALSE,
    expires_at TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX ix_sso_tokens_user ON samba_school.sso_tokens (user_id);

-- Permissão para todos os app users
GRANT SELECT, INSERT, UPDATE ON samba_school.sso_tokens TO samba_code_user, samba_edvance_user;
GRANT INSERT, UPDATE, DELETE ON samba_school.sso_tokens TO samba_school_user;
