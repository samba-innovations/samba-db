-- =============================================================================
-- 06_seed.sql — Seed de produção (EE Prof. Christino Cabral)
-- =============================================================================
-- Extraído de samba-simulator/backend/app/core/seed.py
--   • 41 usuários: 1 ROOT, 5 coordenadores, 35 professores
--   • 35 disciplinas únicas (todas as matrizes PEI 2026)
--   • 22 turmas com disciplinas vinculadas por matriz
--   • Atribuições professor → disciplina → turma (horário 2026)
--
-- Idempotente: seguro para re-executar. Usa ON CONFLICT DO NOTHING.
--
-- Senhas: armazenadas como hashes bcrypt (cost=12). Plaintexts não constam neste arquivo.
-- =============================================================================

-- ---------------------------------------------------------------------------
-- Perfis de acesso
-- ---------------------------------------------------------------------------

INSERT INTO samba_school.roles (name) VALUES
    ('ADMIN'),
    ('TEACHER'),
    ('COORDINATOR'),
    ('PRINCIPAL'),
    ('VICE_PRINCIPAL'),
    ('SECRETARY')
ON CONFLICT (name) DO NOTHING;

-- ---------------------------------------------------------------------------
-- Disciplinas — todas as matrizes PEI 2026
-- ---------------------------------------------------------------------------

INSERT INTO samba_school.disciplines (name) VALUES
    -- Core (todas as matrizes)
    ('Língua Portuguesa'),
    ('Redação e Leitura'),
    ('Língua Inglesa'),
    ('Arte'),
    ('Educação Física'),
    ('Matemática'),
    ('Educação Financeira'),
    ('Biologia'),
    ('Física'),
    ('Química'),
    ('Filosofia'),
    ('Geografia'),
    ('História'),
    ('Projeto de Vida'),
    ('Práticas Experimentais'),
    ('OE Matemática'),
    ('OE Língua Portuguesa'),
    ('Eletiva'),
    ('Robótica'),
    ('EMA'),
    -- 2ª série
    ('Sociologia'),
    ('Programação'),
    ('Empreendedorismo'),
    ('Arte e Mídias Digitais'),
    ('Liderança-Oratória'),
    -- 3ª série A/B
    ('Aprofundamento em Sociologia'),
    ('Aprofundamento em Geografia'),
    ('Aprofundamento em Filosofia'),
    ('Atualidades'),
    ('Inglês'),
    -- 3ª série C/D
    ('Aprofundamento em Química'),
    ('Aprofundamento em Biologia'),
    -- Anos Finais
    ('Ensino Religioso'),
    ('Ciências'),
    ('Tecnologia e Inovação')
ON CONFLICT (name) DO NOTHING;

-- ---------------------------------------------------------------------------
-- Séries escolares
-- ---------------------------------------------------------------------------

INSERT INTO samba_school.school_grades (level, year_number, label) VALUES
    ('fundamental', 6, '6º'),
    ('fundamental', 7, '7º'),
    ('fundamental', 8, '8º'),
    ('fundamental', 9, '9º'),
    ('medio',       1, '1ª'),
    ('medio',       2, '2ª'),
    ('medio',       3, '3ª')
ON CONFLICT (level, year_number) DO UPDATE
    SET label = EXCLUDED.label;

-- ---------------------------------------------------------------------------
-- Seções (letras A–E)
-- ---------------------------------------------------------------------------

INSERT INTO samba_school.class_sections (label) VALUES
    ('A'), ('B'), ('C'), ('D'), ('E')
ON CONFLICT (label) DO NOTHING;

-- ---------------------------------------------------------------------------
-- Turmas — 22 turmas com nomes compactos (ex: 1ªA, 6ºA)
-- ---------------------------------------------------------------------------

INSERT INTO samba_school.school_classes (grade_id, section_id, name)
SELECT g.id, s.id, g.label || s.label
FROM   samba_school.school_grades  g
JOIN   samba_school.class_sections s ON s.label IN ('A','B','C','D','E')
WHERE (g.level = 'medio'       AND g.year_number = 1 AND s.label IN ('A','B','C','D','E'))
   OR (g.level = 'medio'       AND g.year_number = 2 AND s.label IN ('A','B','C'))
   OR (g.level = 'medio'       AND g.year_number = 3 AND s.label IN ('A','B','C','D'))
   OR (g.level = 'fundamental' AND g.year_number = 6 AND s.label IN ('A','B'))
   OR (g.level = 'fundamental' AND g.year_number = 7 AND s.label IN ('A','B'))
   OR (g.level = 'fundamental' AND g.year_number = 8 AND s.label IN ('A','B','C'))
   OR (g.level = 'fundamental' AND g.year_number = 9 AND s.label IN ('A','B','C'))
ON CONFLICT (grade_id, section_id) DO NOTHING;

-- ---------------------------------------------------------------------------
-- Vínculos turma ↔ disciplina (class_disciplines)
-- Cada turma tem sua matriz de disciplinas conforme PEI 2026
-- ---------------------------------------------------------------------------

DO $$
DECLARE
    -- Matrizes de disciplinas por grupo de turmas
    _m1    TEXT[] := ARRAY[
        'Língua Portuguesa','Redação e Leitura','Língua Inglesa','Arte',
        'Educação Física','Matemática','Educação Financeira','Biologia',
        'Física','Química','Filosofia','Geografia','História',
        'Projeto de Vida','Práticas Experimentais',
        'OE Matemática','OE Língua Portuguesa','Eletiva','Robótica','EMA'
    ];
    _m2ac  TEXT[] := ARRAY[
        'Língua Portuguesa','Redação e Leitura','Língua Inglesa','Sociologia',
        'Educação Física','Matemática','Educação Financeira','Biologia',
        'Física','Química','Programação','Geografia','História',
        'Projeto de Vida','Práticas Experimentais',
        'OE Matemática','OE Língua Portuguesa','Eletiva','Robótica',
        'Empreendedorismo','EMA'
    ];
    _m2b   TEXT[] := ARRAY[
        'Língua Portuguesa','Redação e Leitura','Língua Inglesa','Sociologia',
        'Educação Física','Matemática','Educação Financeira','Biologia',
        'Física','Química','Arte e Mídias Digitais','Geografia','História',
        'Projeto de Vida','Práticas Experimentais',
        'OE Matemática','OE Língua Portuguesa','Eletiva','Robótica',
        'Liderança-Oratória','EMA'
    ];
    _m3ab  TEXT[] := ARRAY[
        'Língua Portuguesa','Redação e Leitura',
        'Aprofundamento em Sociologia','Aprofundamento em Geografia',
        'Educação Física','Matemática','Aprofundamento em Filosofia',
        'Física','Atualidades','Inglês','História',
        'Projeto de Vida','Práticas Experimentais',
        'OE Matemática','OE Língua Portuguesa','Eletiva','Robótica','EMA'
    ];
    _m3cd  TEXT[] := ARRAY[
        'Língua Portuguesa','Redação e Leitura',
        'Aprofundamento em Química','Aprofundamento em Biologia',
        'Educação Física','Matemática','Empreendedorismo',
        'Física','Programação','Inglês','História',
        'Projeto de Vida','Práticas Experimentais',
        'OE Matemática','OE Língua Portuguesa','Eletiva','Robótica','EMA'
    ];
    _faf   TEXT[] := ARRAY[
        'Língua Portuguesa','Língua Inglesa','Arte','Educação Física',
        'Matemática','Ensino Religioso','Ciências','Geografia','História',
        'Projeto de Vida','OE Matemática','OE Língua Portuguesa',
        'Tecnologia e Inovação','Educação Financeira','Redação e Leitura',
        'Eletiva','Robótica','Práticas Experimentais','EMA'
    ];

    _class_name TEXT;
    _disc_name  TEXT;
    _class_id   INT;
    _disc_id    INT;
    _pairs      TEXT[][] := ARRAY[
        -- (class_name, matriz_key)
        ARRAY['1ªA','m1'], ARRAY['1ªB','m1'], ARRAY['1ªC','m1'], ARRAY['1ªD','m1'], ARRAY['1ªE','m1'],
        ARRAY['2ªA','m2ac'], ARRAY['2ªB','m2b'], ARRAY['2ªC','m2ac'],
        ARRAY['3ªA','m3ab'], ARRAY['3ªB','m3ab'], ARRAY['3ªC','m3cd'], ARRAY['3ªD','m3cd'],
        ARRAY['6ºA','faf'], ARRAY['6ºB','faf'],
        ARRAY['7ºA','faf'], ARRAY['7ºB','faf'],
        ARRAY['8ºA','faf'], ARRAY['8ºB','faf'], ARRAY['8ºC','faf'],
        ARRAY['9ºA','faf'], ARRAY['9ºB','faf'], ARRAY['9ºC','faf']
    ];
    _pair       TEXT[];
    _matriz     TEXT[];
BEGIN
    FOREACH _pair SLICE 1 IN ARRAY _pairs LOOP
        _class_name := _pair[1];
        SELECT id INTO _class_id FROM samba_school.school_classes WHERE name = _class_name;
        IF _class_id IS NULL THEN CONTINUE; END IF;

        CASE _pair[2]
            WHEN 'm1'   THEN _matriz := _m1;
            WHEN 'm2ac' THEN _matriz := _m2ac;
            WHEN 'm2b'  THEN _matriz := _m2b;
            WHEN 'm3ab' THEN _matriz := _m3ab;
            WHEN 'm3cd' THEN _matriz := _m3cd;
            ELSE             _matriz := _faf;
        END CASE;

        FOREACH _disc_name IN ARRAY _matriz LOOP
            SELECT id INTO _disc_id FROM samba_school.disciplines WHERE name = _disc_name;
            IF _disc_id IS NULL THEN CONTINUE; END IF;
            INSERT INTO samba_school.class_disciplines (class_id, discipline_id)
            VALUES (_class_id, _disc_id)
            ON CONFLICT DO NOTHING;
        END LOOP;
    END LOOP;
END;
$$;

-- ---------------------------------------------------------------------------
-- Usuários — 41 usuários de produção
-- ---------------------------------------------------------------------------

INSERT INTO samba_school.users (name, email, password_hash, is_active, must_change_password, is_admin) VALUES
    -- ROOT
    ('ROOT',                                    'root@escolacabral.com.br',              '$2b$12$xJzODz7qsG.mKbbmohP.0u2SGYpg2XVhoy7jQkBgBUot9/24QccTC', TRUE, FALSE, TRUE),
    -- Diretor / Vice-Diretor
    ('DIRETOR',                                 'diretor@escolacabral.com.br',           '$2b$12$jYatesDTrsrYUElp8jqqfumZ4S1fWNZG2kMH2ZRVEadduJuS.eYDW',   TRUE, TRUE),
    ('VICE-DIRETOR',                            'vice@escolacabral.com.br',              '$2b$12$jYatesDTrsrYUElp8jqqfumZ4S1fWNZG2kMH2ZRVEadduJuS.eYDW',   TRUE, TRUE),
    -- Coordenadores
    ('ALINE CRISTIANE ZORZI',                   'aline_zorzi@escolacabral.com.br',       '$2b$12$jYatesDTrsrYUElp8jqqfumZ4S1fWNZG2kMH2ZRVEadduJuS.eYDW',   TRUE, TRUE),
    ('CARLA REGINA SPARAPAM DA SILVA',          'carla_silva@escolacabral.com.br',       '$2b$12$jYatesDTrsrYUElp8jqqfumZ4S1fWNZG2kMH2ZRVEadduJuS.eYDW',   TRUE, TRUE),
    ('FABIO ANGELO AGUIAR',                     'fabio_aguiar@escolacabral.com.br',      '$2b$12$jYatesDTrsrYUElp8jqqfumZ4S1fWNZG2kMH2ZRVEadduJuS.eYDW',   TRUE, TRUE),
    ('GILCELENE JANAINA RODRIGUES CARDOSO',     'gilcelene_cardoso@escolacabral.com.br', '$2b$12$jYatesDTrsrYUElp8jqqfumZ4S1fWNZG2kMH2ZRVEadduJuS.eYDW',   TRUE, TRUE),
    ('RAUL DE SOUZA HOFFMANN',                  'raul_hoffmann@escolacabral.com.br',     '$2b$12$jYatesDTrsrYUElp8jqqfumZ4S1fWNZG2kMH2ZRVEadduJuS.eYDW',   TRUE, TRUE),
    -- Professores
    ('ADAIANE RODRIGUES MARTINS',               'adaiane_martins@escolacabral.com.br',   '$2b$12$jYatesDTrsrYUElp8jqqfumZ4S1fWNZG2kMH2ZRVEadduJuS.eYDW',   TRUE, TRUE),
    ('ANA CAROLINA DE FREITAS NUNES HARTEN',    'ana_harten@escolacabral.com.br',        '$2b$12$jYatesDTrsrYUElp8jqqfumZ4S1fWNZG2kMH2ZRVEadduJuS.eYDW',   TRUE, TRUE),
    ('ANA LÚCIA MARIANO DOS SANTOS',            'ana_santos@escolacabral.com.br',        '$2b$12$jYatesDTrsrYUElp8jqqfumZ4S1fWNZG2kMH2ZRVEadduJuS.eYDW',   TRUE, TRUE),
    ('ANGÉLICA LONGO DE CAMPOS',                'angelica_campos@escolacabral.com.br',   '$2b$12$jYatesDTrsrYUElp8jqqfumZ4S1fWNZG2kMH2ZRVEadduJuS.eYDW',   TRUE, TRUE),
    ('CAMILA CHIQUITO PALHARES',                'camila_palhares@escolacabral.com.br',   '$2b$12$jYatesDTrsrYUElp8jqqfumZ4S1fWNZG2kMH2ZRVEadduJuS.eYDW',   TRUE, TRUE),
    ('CÉSAR AUGUSTO GABURI',                    'cesar_gaburi@escolacabral.com.br',      '$2b$12$jYatesDTrsrYUElp8jqqfumZ4S1fWNZG2kMH2ZRVEadduJuS.eYDW',   TRUE, TRUE),
    ('CINTHIA SANCHES BOTELHO TOJEIRO',         'cinthia_tojeiro@escolacabral.com.br',   '$2b$12$jYatesDTrsrYUElp8jqqfumZ4S1fWNZG2kMH2ZRVEadduJuS.eYDW',   TRUE, TRUE),
    ('EVANDRO HENRIQUE DA SILVA FERREIRA',      'evandro_ferreira@escolacabral.com.br',  '$2b$12$jYatesDTrsrYUElp8jqqfumZ4S1fWNZG2kMH2ZRVEadduJuS.eYDW',   TRUE, TRUE),
    ('FERNANDO PEREIRA GODOI',                  'fernando_godoi@escolacabral.com.br',    '$2b$12$jYatesDTrsrYUElp8jqqfumZ4S1fWNZG2kMH2ZRVEadduJuS.eYDW',   TRUE, TRUE),
    ('GABRIEL GUIMARÃES FERREIRA RAMOS',        'gabriel_ramos@escolacabral.com.br',     '$2b$12$jYatesDTrsrYUElp8jqqfumZ4S1fWNZG2kMH2ZRVEadduJuS.eYDW',   TRUE, TRUE),
    ('JEAN MARTINS',                            'jean_martins@escolacabral.com.br',      '$2b$12$jYatesDTrsrYUElp8jqqfumZ4S1fWNZG2kMH2ZRVEadduJuS.eYDW',   TRUE, TRUE),
    ('LAHYR MORATO KRAHENBUHL NETO',            'lahyr_neto@escolacabral.com.br',        '$2b$12$jYatesDTrsrYUElp8jqqfumZ4S1fWNZG2kMH2ZRVEadduJuS.eYDW',   TRUE, TRUE),
    ('LEANDRO JOSÉ GUARNETTI',                  'leandro_guarnetti@escolacabral.com.br', '$2b$12$jYatesDTrsrYUElp8jqqfumZ4S1fWNZG2kMH2ZRVEadduJuS.eYDW',   TRUE, TRUE),
    ('LETÍCIA ZAFRED PAIVA',                    'leticia_paiva@escolacabral.com.br',     '$2b$12$jYatesDTrsrYUElp8jqqfumZ4S1fWNZG2kMH2ZRVEadduJuS.eYDW',   TRUE, TRUE),
    ('LILIAN CRISTIANE PISANO',                 'lilian_pisano@escolacabral.com.br',     '$2b$12$jYatesDTrsrYUElp8jqqfumZ4S1fWNZG2kMH2ZRVEadduJuS.eYDW',   TRUE, TRUE),
    ('LUCIANE DUARTE PEROTTA',                  'luciane_perotta@escolacabral.com.br',   '$2b$12$jYatesDTrsrYUElp8jqqfumZ4S1fWNZG2kMH2ZRVEadduJuS.eYDW',   TRUE, TRUE),
    ('LUÍS GUSTAVO DE SOUZA ZECA',              'luis_zeca@escolacabral.com.br',         '$2b$12$jYatesDTrsrYUElp8jqqfumZ4S1fWNZG2kMH2ZRVEadduJuS.eYDW',   TRUE, TRUE),
    ('MÁRCIA AP. CORRÊA RODRIGUES',             'marcia_rodrigues@escolacabral.com.br',  '$2b$12$jYatesDTrsrYUElp8jqqfumZ4S1fWNZG2kMH2ZRVEadduJuS.eYDW',   TRUE, TRUE),
    ('MARIA BENEDITA MOREIRA',                  'maria_moreira@escolacabral.com.br',     '$2b$12$jYatesDTrsrYUElp8jqqfumZ4S1fWNZG2kMH2ZRVEadduJuS.eYDW',   TRUE, TRUE),
    ('MARIA FERNANDA BRIGUETI LOURENÇO',        'maria_lourenco@escolacabral.com.br',    '$2b$12$jYatesDTrsrYUElp8jqqfumZ4S1fWNZG2kMH2ZRVEadduJuS.eYDW',   TRUE, TRUE),
    ('MARISA ALVES DA SILVA',                   'marisa_silva@escolacabral.com.br',      '$2b$12$jYatesDTrsrYUElp8jqqfumZ4S1fWNZG2kMH2ZRVEadduJuS.eYDW',   TRUE, TRUE),
    ('MATHEUS LUIS DE CAMPOS MIELI',            'matheus_mieli@escolacabral.com.br',     '$2b$12$jYatesDTrsrYUElp8jqqfumZ4S1fWNZG2kMH2ZRVEadduJuS.eYDW',   TRUE, TRUE),
    ('MICHAEL JORDÃO MILIANO DOS SANTOS',       'michael_santos@escolacabral.com.br',    '$2b$12$jYatesDTrsrYUElp8jqqfumZ4S1fWNZG2kMH2ZRVEadduJuS.eYDW',   TRUE, TRUE),
    ('PÂMELA CAROLINE EVARISTO',                'pamela_evaristo@escolacabral.com.br',   '$2b$12$jYatesDTrsrYUElp8jqqfumZ4S1fWNZG2kMH2ZRVEadduJuS.eYDW',   TRUE, TRUE),
    ('PATRÍCIA STEVANATO DE OLIVEIRA',          'patricia_oliveira@escolacabral.com.br', '$2b$12$jYatesDTrsrYUElp8jqqfumZ4S1fWNZG2kMH2ZRVEadduJuS.eYDW',   TRUE, TRUE),
    ('REGINA GENESINI IAYAR',                   'regina_iayar@escolacabral.com.br',      '$2b$12$jYatesDTrsrYUElp8jqqfumZ4S1fWNZG2kMH2ZRVEadduJuS.eYDW',   TRUE, TRUE),
    ('ROSANGELA TEREZINHA TICIANELLI PIRES',    'rosangela_pires@escolacabral.com.br',   '$2b$12$jYatesDTrsrYUElp8jqqfumZ4S1fWNZG2kMH2ZRVEadduJuS.eYDW',   TRUE, TRUE),
    ('SANDRA APARECIDA BARONI FONSECA',         'sandra_fonseca@escolacabral.com.br',    '$2b$12$jYatesDTrsrYUElp8jqqfumZ4S1fWNZG2kMH2ZRVEadduJuS.eYDW',   TRUE, TRUE),
    ('SÉRGIA MARIA MOREIRA MACHADO',            'sergia_machado@escolacabral.com.br',    '$2b$12$jYatesDTrsrYUElp8jqqfumZ4S1fWNZG2kMH2ZRVEadduJuS.eYDW',   TRUE, TRUE),
    ('TERESA CRISTINA',                         'teresa_cristina@escolacabral.com.br',   '$2b$12$jYatesDTrsrYUElp8jqqfumZ4S1fWNZG2kMH2ZRVEadduJuS.eYDW',   TRUE, TRUE),
    ('THIAGO STEFANIN',                         'thiago_stefanin@escolacabral.com.br',   '$2b$12$jYatesDTrsrYUElp8jqqfumZ4S1fWNZG2kMH2ZRVEadduJuS.eYDW',   TRUE, TRUE),
    ('VALÉRIA R. C. BOSCO',                     'valeria_bosco@escolacabral.com.br',     '$2b$12$jYatesDTrsrYUElp8jqqfumZ4S1fWNZG2kMH2ZRVEadduJuS.eYDW',   TRUE, TRUE),
    ('VÂNIA MARIA THEODORO PINHEIRO',           'vania_pinheiro@escolacabral.com.br',    '$2b$12$jYatesDTrsrYUElp8jqqfumZ4S1fWNZG2kMH2ZRVEadduJuS.eYDW',   TRUE, TRUE),
    ('VINÍCIUS BERTUZZO LIMA',                  'vinicius_lima@escolacabral.com.br',     '$2b$12$jYatesDTrsrYUElp8jqqfumZ4S1fWNZG2kMH2ZRVEadduJuS.eYDW',   TRUE, TRUE),
    ('VITOR BONJORNO CHAGAS',                   'vitor_chagas@escolacabral.com.br',      '$2b$12$jYatesDTrsrYUElp8jqqfumZ4S1fWNZG2kMH2ZRVEadduJuS.eYDW',   TRUE, TRUE)
ON CONFLICT (email) DO NOTHING;

-- ---------------------------------------------------------------------------
-- Atribuição de roles
-- ---------------------------------------------------------------------------

-- ROOT → ADMIN
INSERT INTO samba_school.user_roles (user_id, role_id)
SELECT u.id, r.id FROM samba_school.users u, samba_school.roles r
WHERE u.email = 'root@escolacabral.com.br' AND r.name = 'ADMIN'
ON CONFLICT DO NOTHING;

-- Diretor → PRINCIPAL
INSERT INTO samba_school.user_roles (user_id, role_id)
SELECT u.id, r.id FROM samba_school.users u, samba_school.roles r
WHERE u.email = 'diretor@escolacabral.com.br' AND r.name = 'PRINCIPAL'
ON CONFLICT DO NOTHING;

-- Vice-Diretor → VICE_PRINCIPAL
INSERT INTO samba_school.user_roles (user_id, role_id)
SELECT u.id, r.id FROM samba_school.users u, samba_school.roles r
WHERE u.email = 'vice@escolacabral.com.br' AND r.name = 'VICE_PRINCIPAL'
ON CONFLICT DO NOTHING;

-- Coordenadores → COORDINATOR
INSERT INTO samba_school.user_roles (user_id, role_id)
SELECT u.id, r.id
FROM samba_school.users u
JOIN samba_school.roles r ON r.name = 'COORDINATOR'
WHERE u.email IN (
    'aline_zorzi@escolacabral.com.br',
    'carla_silva@escolacabral.com.br',
    'fabio_aguiar@escolacabral.com.br',
    'gilcelene_cardoso@escolacabral.com.br',
    'raul_hoffmann@escolacabral.com.br'
)
ON CONFLICT DO NOTHING;

-- Professores → TEACHER
INSERT INTO samba_school.user_roles (user_id, role_id)
SELECT u.id, r.id
FROM samba_school.users u
JOIN samba_school.roles r ON r.name = 'TEACHER'
WHERE u.email IN (
    'adaiane_martins@escolacabral.com.br',
    'ana_harten@escolacabral.com.br',
    'ana_santos@escolacabral.com.br',
    'angelica_campos@escolacabral.com.br',
    'camila_palhares@escolacabral.com.br',
    'cesar_gaburi@escolacabral.com.br',
    'cinthia_tojeiro@escolacabral.com.br',
    'evandro_ferreira@escolacabral.com.br',
    'fernando_godoi@escolacabral.com.br',
    'gabriel_ramos@escolacabral.com.br',
    'jean_martins@escolacabral.com.br',
    'lahyr_neto@escolacabral.com.br',
    'leandro_guarnetti@escolacabral.com.br',
    'leticia_paiva@escolacabral.com.br',
    'lilian_pisano@escolacabral.com.br',
    'luciane_perotta@escolacabral.com.br',
    'luis_zeca@escolacabral.com.br',
    'marcia_rodrigues@escolacabral.com.br',
    'maria_moreira@escolacabral.com.br',
    'maria_lourenco@escolacabral.com.br',
    'marisa_silva@escolacabral.com.br',
    'matheus_mieli@escolacabral.com.br',
    'michael_santos@escolacabral.com.br',
    'pamela_evaristo@escolacabral.com.br',
    'patricia_oliveira@escolacabral.com.br',
    'regina_iayar@escolacabral.com.br',
    'rosangela_pires@escolacabral.com.br',
    'sandra_fonseca@escolacabral.com.br',
    'sergia_machado@escolacabral.com.br',
    'teresa_cristina@escolacabral.com.br',
    'thiago_stefanin@escolacabral.com.br',
    'valeria_bosco@escolacabral.com.br',
    'vania_pinheiro@escolacabral.com.br',
    'vinicius_lima@escolacabral.com.br',
    'vitor_chagas@escolacabral.com.br'
)
ON CONFLICT DO NOTHING;

-- Coordenadores que também lecionam → TEACHER adicional
INSERT INTO samba_school.user_roles (user_id, role_id)
SELECT u.id, r.id
FROM samba_school.users u
JOIN samba_school.roles r ON r.name = 'TEACHER'
WHERE u.email IN (
    'carla_silva@escolacabral.com.br',
    'gilcelene_cardoso@escolacabral.com.br',
    'raul_hoffmann@escolacabral.com.br'
)
ON CONFLICT DO NOTHING;

-- ---------------------------------------------------------------------------
-- Atribuições professor → disciplina → turma  (teacher_assignments)
-- Extraído do horário 2026 — 71 grupos de atribuição
-- ---------------------------------------------------------------------------

DO $$
DECLARE
    -- Função auxiliar inline: resolve class_id pelo nome compacto (ex: '1ªA', '6ºA')
    _atr RECORD;
    _uid INT;
    _did INT;
    _cid INT;

    -- (email, disciplina, ARRAY de nomes de turma)
    _atribuicoes JSONB := '[
        ["adaiane_martins@escolacabral.com.br",   "Língua Portuguesa",            ["3ªA","3ªB","3ªC","3ªD"]],
        ["adaiane_martins@escolacabral.com.br",   "Redação e Leitura",            ["1ªA","1ªB","2ªA","2ªB","2ªC"]],
        ["ana_santos@escolacabral.com.br",        "Educação Física",              ["1ªA","1ªB","1ªC","1ªD","1ªE","2ªA","2ªB","2ªC","3ªA","3ªB","3ªC","3ªD"]],
        ["ana_santos@escolacabral.com.br",        "Projeto de Vida",              ["1ªA","1ªB","1ªC","1ªD","1ªE"]],
        ["ana_santos@escolacabral.com.br",        "EMA",                          ["2ªB","2ªC"]],
        ["angelica_campos@escolacabral.com.br",   "Geografia",                    ["6ºA","6ºB","7ºA","7ºB","8ºA","8ºB","9ºA","9ºB","9ºC"]],
        ["camila_palhares@escolacabral.com.br",   "Matemática",                   ["6ºA","6ºB"]],
        ["camila_palhares@escolacabral.com.br",   "Química",                      ["1ªA"]],
        ["camila_palhares@escolacabral.com.br",   "OE Matemática",                ["8ºA","8ºB","9ºA","9ºB","9ºC"]],
        ["camila_palhares@escolacabral.com.br",   "Práticas Experimentais",       ["6ºA","6ºB","1ªA"]],
        ["camila_palhares@escolacabral.com.br",   "Robótica",                     ["8ºA","8ºB"]],
        ["carla_silva@escolacabral.com.br",       "OE Língua Portuguesa",         ["3ªA","3ªB","3ªC","3ªD"]],
        ["ana_harten@escolacabral.com.br",        "Ciências",                     ["6ºA","6ºB","9ºA","9ºB","9ºC"]],
        ["ana_harten@escolacabral.com.br",        "Biologia",                     ["1ªA","1ªB"]],
        ["ana_harten@escolacabral.com.br",        "Práticas Experimentais",       ["6ºA","6ºB","9ºA","9ºB","9ºC","1ªA","1ªB"]],
        ["cesar_gaburi@escolacabral.com.br",      "Ciências",                     ["7ºA","7ºB"]],
        ["cesar_gaburi@escolacabral.com.br",      "Práticas Experimentais",       ["7ºA","7ºB"]],
        ["cesar_gaburi@escolacabral.com.br",      "Robótica",                     ["6ºA","6ºB","7ºA","7ºB","9ºA","9ºB","1ªD","1ªE"]],
        ["cesar_gaburi@escolacabral.com.br",      "Tecnologia e Inovação",        ["8ºA","8ºB"]],
        ["cinthia_tojeiro@escolacabral.com.br",   "Língua Portuguesa",            ["1ªA","1ªB","1ªC","1ªD","1ªE"]],
        ["cinthia_tojeiro@escolacabral.com.br",   "OE Língua Portuguesa",         ["1ªA","1ªB","1ªC","1ªD","1ªE"]],
        ["evandro_ferreira@escolacabral.com.br",  "Matemática",                   ["3ªA","3ªB","3ªC","3ªD"]],
        ["evandro_ferreira@escolacabral.com.br",  "Física",                       ["2ªA","2ªB","2ªC"]],
        ["evandro_ferreira@escolacabral.com.br",  "OE Matemática",                ["7ºA","7ºB"]],
        ["evandro_ferreira@escolacabral.com.br",  "Práticas Experimentais",       ["2ªA","2ªB","2ªC"]],
        ["maria_lourenco@escolacabral.com.br",    "Língua Portuguesa",            ["9ºA","9ºB","9ºC"]],
        ["maria_lourenco@escolacabral.com.br",    "OE Língua Portuguesa",         ["9ºA","9ºB","9ºC"]],
        ["maria_lourenco@escolacabral.com.br",    "Redação e Leitura",            ["6ºA","6ºB","7ºA","7ºB"]],
        ["fernando_godoi@escolacabral.com.br",    "Ciências",                     ["8ºA","8ºB"]],
        ["fernando_godoi@escolacabral.com.br",    "Educação Financeira",          ["7ºA","7ºB","8ºA","8ºB"]],
        ["fernando_godoi@escolacabral.com.br",    "Práticas Experimentais",       ["8ºA","8ºB"]],
        ["fernando_godoi@escolacabral.com.br",    "Robótica",                     ["9ºC"]],
        ["fernando_godoi@escolacabral.com.br",    "Tecnologia e Inovação",        ["6ºA","6ºB","7ºA","7ºB"]],
        ["gabriel_ramos@escolacabral.com.br",     "Física",                       ["1ªA"]],
        ["gabriel_ramos@escolacabral.com.br",     "Matemática",                   ["1ªE"]],
        ["gabriel_ramos@escolacabral.com.br",     "Educação Financeira",          ["2ªA","2ªB","2ªC"]],
        ["gabriel_ramos@escolacabral.com.br",     "OE Matemática",                ["1ªE"]],
        ["gabriel_ramos@escolacabral.com.br",     "Robótica",                     ["1ªC","2ªA","2ªB","2ªC"]],
        ["gabriel_ramos@escolacabral.com.br",     "Tecnologia e Inovação",        ["9ºA","9ºB","9ºC"]],
        ["gilcelene_cardoso@escolacabral.com.br", "OE Matemática",                ["3ªA","3ªB","3ªC","3ªD"]],
        ["jean_martins@escolacabral.com.br",      "Língua Inglesa",               ["1ªA","1ªB","1ªC","1ªD","1ªE","2ªA","2ªB","2ªC"]],
        ["jean_martins@escolacabral.com.br",      "OE Língua Portuguesa",         ["2ªA","2ªB","2ªC"]],
        ["jean_martins@escolacabral.com.br",      "Projeto de Vida",              ["2ªA","2ªB","2ªC","3ªA","3ªB","3ªC","3ªD"]],
        ["lahyr_neto@escolacabral.com.br",        "História",                     ["1ªA","1ªB","1ªC","1ªD","1ªE","2ªA","2ªB","2ªC","3ªA","3ªB","3ªC","3ªD"]],
        ["lahyr_neto@escolacabral.com.br",        "Atualidades",                  ["3ªA","3ªB"]],
        ["leandro_guarnetti@escolacabral.com.br", "Matemática",                   ["2ªA","2ªB","2ªC"]],
        ["leandro_guarnetti@escolacabral.com.br", "OE Matemática",                ["2ªA","2ªB","2ªC"]],
        ["leandro_guarnetti@escolacabral.com.br", "Robótica",                     ["1ªA","1ªB","3ªA","3ªB","3ªC","3ªD"]],
        ["leticia_paiva@escolacabral.com.br",     "Língua Inglesa",               ["6ºA","6ºB","7ºA","7ºB","8ºA","8ºB","9ºA","9ºB","9ºC"]],
        ["leticia_paiva@escolacabral.com.br",     "Inglês",                       ["3ªA","3ªB","3ªC","3ªD"]],
        ["lilian_pisano@escolacabral.com.br",     "Biologia",                     ["1ªC","1ªD","1ªE","2ªA","2ªB","2ªC"]],
        ["lilian_pisano@escolacabral.com.br",     "Aprofundamento em Biologia",   ["3ªC","3ªD"]],
        ["lilian_pisano@escolacabral.com.br",     "Práticas Experimentais",       ["1ªC","1ªD","1ªE","3ªA","3ªB","3ªC","3ªD"]],
        ["luciane_perotta@escolacabral.com.br",   "Língua Portuguesa",            ["6ºA","6ºB"]],
        ["luciane_perotta@escolacabral.com.br",   "OE Língua Portuguesa",         ["6ºA","6ºB"]],
        ["luciane_perotta@escolacabral.com.br",   "Redação e Leitura",            ["8ºA","8ºB"]],
        ["luciane_perotta@escolacabral.com.br",   "Projeto de Vida",              ["6ºA","6ºB","7ºA","7ºB","8ºA","8ºB","9ºA","9ºB","9ºC"]],
        ["matheus_mieli@escolacabral.com.br",     "Matemática",                   ["1ªA","1ªB","9ºA","9ºB","9ºC"]],
        ["matheus_mieli@escolacabral.com.br",     "OE Matemática",                ["1ªA","1ªB"]],
        ["matheus_mieli@escolacabral.com.br",     "Práticas Experimentais",       ["9ºA","9ºB","9ºC"]],
        ["michael_santos@escolacabral.com.br",    "Educação Física",              ["6ºA","6ºB","7ºA","7ºB","8ºA","8ºB","9ºA","9ºB","9ºC"]],
        ["michael_santos@escolacabral.com.br",    "EMA",                          ["2ªA","9ºA","9ºB","9ºC"]],
        ["patricia_oliveira@escolacabral.com.br", "Língua Portuguesa",            ["7ºA","7ºB","8ºA","8ºB"]],
        ["patricia_oliveira@escolacabral.com.br", "OE Língua Portuguesa",         ["7ºA","7ºB","8ºA","8ºB"]],
        ["patricia_oliveira@escolacabral.com.br", "Redação e Leitura",            ["9ºA","9ºB","9ºC"]],
        ["raul_hoffmann@escolacabral.com.br",     "Filosofia",                    ["1ªA","1ªB","1ªC","1ªD","1ªE"]],
        ["raul_hoffmann@escolacabral.com.br",     "Aprofundamento em Filosofia",  ["3ªA","3ªB"]],
        ["rosangela_pires@escolacabral.com.br",   "Geografia",                    ["1ªA","1ªB","1ªC","1ªD","1ªE","2ªA","2ªB","2ªC"]],
        ["rosangela_pires@escolacabral.com.br",   "Sociologia",                   ["2ªA","2ªB","2ªC"]],
        ["rosangela_pires@escolacabral.com.br",   "Aprofundamento em Sociologia", ["3ªA","3ªB"]],
        ["rosangela_pires@escolacabral.com.br",   "Aprofundamento em Geografia",  ["3ªA","3ªB"]],
        ["sergia_machado@escolacabral.com.br",    "Matemática",                   ["1ªC","1ªD"]],
        ["sergia_machado@escolacabral.com.br",    "OE Matemática",                ["1ªC","1ªD"]],
        ["sergia_machado@escolacabral.com.br",    "Educação Financeira",          ["1ªA","1ªB","1ªC","1ªD","1ªE"]],
        ["sergia_machado@escolacabral.com.br",    "Empreendedorismo",             ["2ªA","2ªC","3ªC","3ªD"]],
        ["sergia_machado@escolacabral.com.br",    "Liderança-Oratória",           ["2ªB"]],
        ["teresa_cristina@escolacabral.com.br",   "Química",                      ["1ªB","1ªC","1ªD","1ªE","2ªA","2ªB","2ªC"]],
        ["teresa_cristina@escolacabral.com.br",   "Práticas Experimentais",       ["1ªB","1ªC","1ªD","1ªE","2ªA","2ªB","2ªC","3ªA","3ªB","3ªC","3ªD"]],
        ["thiago_stefanin@escolacabral.com.br",   "Arte",                         ["1ªA","1ªB","1ªC","1ªD","1ªE"]],
        ["thiago_stefanin@escolacabral.com.br",   "EMA",                          ["1ªA","1ªB","1ªC","1ªD","3ªA","3ªB","3ªC","3ªD"]],
        ["thiago_stefanin@escolacabral.com.br",   "Arte e Mídias Digitais",       ["2ªB"]],
        ["valeria_bosco@escolacabral.com.br",     "Matemática",                   ["7ºA","7ºB","8ºA","8ºB"]],
        ["valeria_bosco@escolacabral.com.br",     "OE Matemática",                ["6ºA","6ºB"]],
        ["valeria_bosco@escolacabral.com.br",     "Práticas Experimentais",       ["7ºA","7ºB","8ºA","8ºB"]],
        ["vinicius_lima@escolacabral.com.br",     "Física",                       ["1ªB","1ªC","1ªD","1ªE","3ªA","3ªB","3ªC","3ªD"]],
        ["vinicius_lima@escolacabral.com.br",     "Aprofundamento em Química",    ["3ªC","3ªD"]],
        ["vinicius_lima@escolacabral.com.br",     "Programação",                  ["2ªA","2ªC","3ªC","3ªD"]],
        ["vitor_chagas@escolacabral.com.br",      "História",                     ["6ºA","6ºB","7ºA","7ºB","8ºA","8ºB","9ºA","9ºB","9ºC"]],
        ["vania_pinheiro@escolacabral.com.br",    "Arte",                         ["6ºA","6ºB","7ºA","7ºB","8ºA","8ºB","9ºA","9ºB","9ºC"]],
        ["vania_pinheiro@escolacabral.com.br",    "EMA",                          ["1ªE","6ºA","6ºB","7ºA","7ºB","8ºA","8ºB"]],
        ["luis_zeca@escolacabral.com.br",         "Língua Portuguesa",            ["2ªA","2ªB","2ªC"]],
        ["luis_zeca@escolacabral.com.br",         "Redação e Leitura",            ["1ªC","1ªD","1ªE","3ªA","3ªB","3ªC","3ªD"]]
    ]'::JSONB;

    _entry JSONB;
    _turma TEXT;
BEGIN
    FOR _entry IN SELECT * FROM jsonb_array_elements(_atribuicoes) LOOP
        -- Resolve user
        SELECT id INTO _uid
        FROM samba_school.users
        WHERE email = _entry->>0;
        CONTINUE WHEN _uid IS NULL;

        -- Resolve discipline
        SELECT id INTO _did
        FROM samba_school.disciplines
        WHERE name = _entry->>1;
        CONTINUE WHEN _did IS NULL;

        -- Loop over each class name in the array
        FOR _turma IN SELECT jsonb_array_elements_text(_entry->2) LOOP
            SELECT id INTO _cid
            FROM samba_school.school_classes
            WHERE name = _turma;
            CONTINUE WHEN _cid IS NULL;

            INSERT INTO samba_school.teacher_assignments (user_id, class_id, discipline_id)
            VALUES (_uid, _cid, _did)
            ON CONFLICT DO NOTHING;
        END LOOP;
    END LOOP;
END;
$$;

-- ---------------------------------------------------------------------------
-- Usuários administradores do sistema
-- ---------------------------------------------------------------------------

INSERT INTO samba_school.users (name, email, password_hash, is_active, must_change_password, is_admin)
VALUES
    ('M. Afonso',   'm.afonso@escolacabral.com.br',  '$2b$12$lxblnsLMJQW2yM.ZqVop.ON0Zki.TX1nTAugihXwFWwwbV8QqcMN.', true, true, true),
    ('V. Bertuzzo', 'v.bertuzzo@escolacabral.com.br', '$2b$12$lxblnsLMJQW2yM.ZqVop.ON0Zki.TX1nTAugihXwFWwwbV8QqcMN.', true, true, true)
ON CONFLICT (email) DO UPDATE SET
    is_admin             = true,
    must_change_password = true,
    is_active            = true,
    password_hash        = '$2b$12$lxblnsLMJQW2yM.ZqVop.ON0Zki.TX1nTAugihXwFWwwbV8QqcMN.';

INSERT INTO samba_school.user_roles (user_id, role_id)
SELECT u.id, r.id
FROM samba_school.users u
CROSS JOIN samba_school.roles r
WHERE u.email IN ('m.afonso@escolacabral.com.br', 'v.bertuzzo@escolacabral.com.br')
  AND r.name = 'ADMIN'
ON CONFLICT DO NOTHING;
