-- =============================================================================
-- seed_paper_aulas.sql — Seed do currículo samba_paper
-- =============================================================================
-- Arquivo reservado para o currículo SEDUC-SP (aulas por série/bimestre).
-- Atualmente vazio — execute quando os dados do currículo estiverem disponíveis.
-- Idempotente: usa INSERT ... ON CONFLICT DO NOTHING.
-- =============================================================================

-- Exemplo de inserção (descomentar e adaptar com os dados reais):
--
-- INSERT INTO samba_paper.aulas
--   (ciclo, serie, bimestre, aula_num, disciplina_nome, titulo)
-- VALUES
--   ('fundamental', '6', 1, 1, 'Matemática', 'Números naturais e operações')
-- ON CONFLICT DO NOTHING;

SELECT 'seed_paper_aulas: nenhuma aula inserida — currículo pendente.' AS status;
