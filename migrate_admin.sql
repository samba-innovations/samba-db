-- =============================================================================
-- migrate_admin.sql
-- Adiciona controle de acesso por projeto e usuários admins
-- =============================================================================

-- 1. Coluna is_admin nos usuários
ALTER TABLE samba_school.users
  ADD COLUMN IF NOT EXISTS is_admin BOOLEAN NOT NULL DEFAULT FALSE;

-- 2. Tabela de acesso por projeto
CREATE TABLE IF NOT EXISTS samba_school.user_project_access (
  user_id    INTEGER NOT NULL REFERENCES samba_school.users(id) ON DELETE CASCADE,
  project    VARCHAR(30) NOT NULL CHECK (project IN ('code', 'edvance', 'flourish')),
  granted_by INTEGER REFERENCES samba_school.users(id) ON DELETE SET NULL,
  granted_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (user_id, project)
);

CREATE INDEX IF NOT EXISTS ix_user_project_access_user ON samba_school.user_project_access(user_id);

-- 3. Permissões para os usuários de app
GRANT SELECT, INSERT, DELETE ON samba_school.user_project_access TO samba_code_user;
GRANT SELECT, INSERT, DELETE ON samba_school.user_project_access TO samba_edvance_user;

-- 4. Inserir/atualizar usuários admins
INSERT INTO samba_school.users (name, email, password_hash, is_active, must_change_password, is_admin)
VALUES
  ('M. Afonso',   'm.afonso@escolacabral.com.br',   crypt('Admin@2025', gen_salt('bf')), true, true, true),
  ('V. Bertuzzo', 'v.bertuzzo@escolacabral.com.br',  crypt('Admin@2025', gen_salt('bf')), true, true, true)
ON CONFLICT (email) DO UPDATE SET
  is_admin             = true,
  must_change_password = true,
  is_active            = true,
  password_hash        = crypt('Admin@2025', gen_salt('bf'));

-- 5. Garantir papel ADMIN para os dois admins
INSERT INTO samba_school.user_roles (user_id, role_id)
SELECT u.id, r.id
FROM samba_school.users u
CROSS JOIN samba_school.roles r
WHERE u.email IN ('m.afonso@escolacabral.com.br', 'v.bertuzzo@escolacabral.com.br')
  AND r.name = 'ADMIN'
ON CONFLICT DO NOTHING;
