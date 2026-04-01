-- =============================================================================
-- 05_permissions.sql — Usuários do banco e permissões por schema
-- =============================================================================
-- Princípio do menor privilégio:
--   samba_code_user    → lê samba_school, escreve em samba_code
--   samba_edvance_user → lê samba_school, escreve em samba_edvance
--   postgres           → acesso total (admin, samba-access)
-- =============================================================================

-- ---------------------------------------------------------------------------
-- Criar usuários da aplicação
-- ---------------------------------------------------------------------------

DO $$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'samba_school_user') THEN
        CREATE USER samba_school_user WITH PASSWORD 'school2025secure';
    END IF;
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'samba_code_user') THEN
        CREATE USER samba_code_user WITH PASSWORD 'code2025';
    END IF;
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'samba_edvance_user') THEN
        CREATE USER samba_edvance_user WITH PASSWORD 'edvance2025';
    END IF;
END
$$;

-- ---------------------------------------------------------------------------
-- samba_school_user (samba-access — autenticação central)
-- ---------------------------------------------------------------------------

GRANT USAGE ON SCHEMA samba_school TO samba_school_user;

-- Leitura de todas as tabelas do schema
GRANT SELECT ON ALL TABLES IN SCHEMA samba_school TO samba_school_user;

-- Escrita nas tabelas necessárias para auth
GRANT INSERT, UPDATE, DELETE ON samba_school.refresh_tokens   TO samba_school_user;
GRANT INSERT, UPDATE, DELETE ON samba_school.sso_tokens       TO samba_school_user;
GRANT INSERT, UPDATE, DELETE ON samba_school.user_project_access TO samba_school_user;
GRANT UPDATE (password_hash, must_change_password) ON samba_school.users TO samba_school_user;

GRANT USAGE ON samba_school.refresh_tokens_id_seq TO samba_school_user;

ALTER DEFAULT PRIVILEGES IN SCHEMA samba_school
    GRANT SELECT ON TABLES TO samba_school_user;

-- ---------------------------------------------------------------------------
-- samba_code_user
-- ---------------------------------------------------------------------------

-- Acesso ao schema
GRANT USAGE ON SCHEMA samba_school TO samba_code_user;
GRANT USAGE ON SCHEMA samba_code   TO samba_code_user;

-- samba_school: somente leitura + update de senha do próprio usuário
GRANT SELECT ON ALL TABLES IN SCHEMA samba_school TO samba_code_user;
GRANT UPDATE (password_hash, must_change_password) ON samba_school.users TO samba_code_user;
GRANT INSERT, SELECT, DELETE ON samba_school.refresh_tokens TO samba_code_user;
GRANT USAGE ON samba_school.refresh_tokens_id_seq TO samba_code_user;
GRANT SELECT, INSERT, DELETE ON samba_school.user_project_access TO samba_code_user;

-- samba_code: acesso total
GRANT ALL PRIVILEGES ON ALL TABLES    IN SCHEMA samba_code TO samba_code_user;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA samba_code TO samba_code_user;

-- Novas tabelas criadas futuramente herdam as mesmas permissões
ALTER DEFAULT PRIVILEGES IN SCHEMA samba_school
    GRANT SELECT ON TABLES TO samba_code_user;

ALTER DEFAULT PRIVILEGES IN SCHEMA samba_code
    GRANT ALL ON TABLES    TO samba_code_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA samba_code
    GRANT ALL ON SEQUENCES TO samba_code_user;

-- ---------------------------------------------------------------------------
-- samba_edvance_user
-- ---------------------------------------------------------------------------

-- Acesso ao schema
GRANT USAGE ON SCHEMA samba_school  TO samba_edvance_user;
GRANT USAGE ON SCHEMA samba_edvance TO samba_edvance_user;

-- samba_school: somente leitura + update de senha + refresh tokens
GRANT SELECT ON ALL TABLES IN SCHEMA samba_school TO samba_edvance_user;
GRANT UPDATE (password_hash, must_change_password) ON samba_school.users TO samba_edvance_user;
GRANT INSERT, SELECT, DELETE ON samba_school.refresh_tokens TO samba_edvance_user;
GRANT USAGE ON samba_school.refresh_tokens_id_seq TO samba_edvance_user;
GRANT SELECT, INSERT, DELETE ON samba_school.user_project_access TO samba_edvance_user;

-- samba_edvance: acesso total
GRANT ALL PRIVILEGES ON ALL TABLES    IN SCHEMA samba_edvance TO samba_edvance_user;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA samba_edvance TO samba_edvance_user;

-- Novas tabelas criadas futuramente herdam as mesmas permissões
ALTER DEFAULT PRIVILEGES IN SCHEMA samba_school
    GRANT SELECT ON TABLES TO samba_edvance_user;

ALTER DEFAULT PRIVILEGES IN SCHEMA samba_edvance
    GRANT ALL ON TABLES    TO samba_edvance_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA samba_edvance
    GRANT ALL ON SEQUENCES TO samba_edvance_user;
