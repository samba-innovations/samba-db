-- =============================================================================
-- migrate_school_v1.sql — Migração incremental do schema samba_school
-- Aplica apenas alterações que ainda não existem no banco.
-- Seguro para rodar múltiplas vezes (idempotente).
-- =============================================================================

-- students: dig_ra e call_number
ALTER TABLE samba_school.students
  ADD COLUMN IF NOT EXISTS dig_ra      VARCHAR(8),
  ADD COLUMN IF NOT EXISTS call_number INTEGER;
