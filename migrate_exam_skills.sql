-- Migração: tabela de habilidades por simulado (nível do exam, não da questão)
CREATE TABLE IF NOT EXISTS samba_edvance.exam_skills (
    exam_id  INTEGER NOT NULL REFERENCES samba_edvance.exams(id) ON DELETE CASCADE,
    skill_id INTEGER NOT NULL REFERENCES samba_edvance.skills(id) ON DELETE CASCADE,
    PRIMARY KEY (exam_id, skill_id)
);

CREATE INDEX IF NOT EXISTS ix_exam_skills_exam  ON samba_edvance.exam_skills (exam_id);
CREATE INDEX IF NOT EXISTS ix_exam_skills_skill ON samba_edvance.exam_skills (skill_id);
