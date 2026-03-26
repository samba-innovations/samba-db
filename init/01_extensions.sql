-- =============================================================================
-- 01_extensions.sql — Extensões necessárias
-- =============================================================================
-- pgcrypto: usado no seed para gerar hashes bcrypt dos usuários iniciais
--           crypt('senha', gen_salt('bf', 12)) → hash compatível com
--           bcryptjs (Node.js) e passlib (Python)
-- =============================================================================

CREATE EXTENSION IF NOT EXISTS pgcrypto;
