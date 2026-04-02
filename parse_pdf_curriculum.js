#!/usr/bin/env node
'use strict';

/**
 * parse_pdf_curriculum.js
 * Parses "Guia do Currículo Priorizado – Escopo-Sequência" PDFs (SP) and
 * generates SQL for samba_paper.aulas + samba_paper.aprendizagens_essenciais.
 *
 * Usage:
 *   node parse_pdf_curriculum.js                  # all PDFs → stdout
 *   node parse_pdf_curriculum.js MAT_AF_V2.pdf    # single file → stdout
 *   node parse_pdf_curriculum.js --debug MAT_AF_V2.pdf   # dump page text, no SQL
 *
 * Redirect output:
 *   node parse_pdf_curriculum.js > seed_paper_aulas_pdf.sql
 *
 * PDF table structure (per page, y increases upward):
 *   High y (~456) : "Escopo-Sequência  Xº Ano  Xº Bimestre"
 *   Mid  y (~428) : "Aula  Conteúdo  Objetivos de aprendizagem  Habilidades  Aprendizagem Essencial"
 *   Low  y (<423) : table data rows (multiple y-positions per lesson)
 *
 * Column x positions (headers are centered; data starts left of headers):
 *   Actual data x-ranges differ from header x-values.
 *   Solution: use MIDPOINTS between adjacent header x-values as column boundaries.
 *
 * Lesson row detection:
 *   Lesson numbers (pure integers) appear at x < ~55, somewhere in the MIDDLE of
 *   their multi-line row. Each lesson's items are collected by y-proximity
 *   (midpoint between adjacent lesson number y-values).
 */

// pdfjs-dist writes canvas polyfill warnings directly to process.stdout.
// Intercept and redirect to stderr so they don't pollute the SQL output.
{
  const _origWrite = process.stdout.write.bind(process.stdout);
  process.stdout.write = (data, ...rest) => {
    if (typeof data === 'string' && data.startsWith('Warning: Cannot polyfill')) {
      process.stderr.write(data);
      return true;
    }
    return _origWrite(data, ...rest);
  };
}

const pdfjsLib = require('pdfjs-dist/legacy/build/pdf.js');
const path     = require('path');
const fs       = require('fs');

// ─── Config ──────────────────────────────────────────────────────────────────

const DOCS_DIR = path.resolve(__dirname, '../samba-paper/docs');

/** Map PDF filename → { nome, ciclo } (duplicates excluded) */
const FILE_MAP = {
  'MAT_AF_V2.pdf':       { nome: 'Matemática',        ciclo: 'fundamental' },
  'MAT_EM_V2.pdf':       { nome: 'Matemática',        ciclo: 'medio'       },
  'LP_AF_V2.pdf':        { nome: 'Língua Portuguesa', ciclo: 'fundamental' },
  'LP_EM_V2.pdf':        { nome: 'Língua Portuguesa', ciclo: 'medio'       },
  'HIS_AF_V2.pdf':       { nome: 'História',          ciclo: 'fundamental' },
  'HIS_EM_V2.pdf':       { nome: 'História',          ciclo: 'medio'       },
  'GEO_EM_V2.pdf':       { nome: 'Geografia',         ciclo: 'medio'       },
  'CIE_AF_V2.pdf':       { nome: 'Ciências',          ciclo: 'fundamental' },
  'BIO_EM_V2.pdf':       { nome: 'Biologia',          ciclo: 'medio'       },
  'FIS_EM_V2.pdf':       { nome: 'Física',            ciclo: 'medio'       },
  'QUI_EM_V2.pdf':       { nome: 'Química',           ciclo: 'medio'       },
  'ARTE_AF_V2.pdf':      { nome: 'Arte',              ciclo: 'fundamental' },
  'ING_AF_V2.pdf':       { nome: 'Inglês',            ciclo: 'fundamental' },
  'L.INGLESA_EM_V2.pdf': { nome: 'Língua Inglesa',    ciclo: 'medio'       },
  'E.FISICA_EM_V2.pdf':  { nome: 'Educação Física',   ciclo: 'medio'       },
  'FILO_EM_V2.pdf':      { nome: 'Filosofia',         ciclo: 'medio'       },
  'SOCIO_EM_V2.pdf':     { nome: 'Sociologia',        ciclo: 'medio'       },
};

// ─── Regexes ─────────────────────────────────────────────────────────────────

// Allow spaces between digit and degree sign (PDF splits "6º" → "6", "º")
const SERIE_RE  = /(\d)\s*[ºª°]\s*(?:ano|s[eé]rie)/i;
const BIM_RE    = /(\d)\s*[ºª°]\s*bimestre/i;
const BNCC_RE   = /(?:EF|EM)\d{2}[A-Z]{2}\d{2}/g;
const AE_CODE_RE = /\bAE(\d+)\b/g;

// ─── SQL helpers ─────────────────────────────────────────────────────────────

function sqlStr(val) {
  if (val === null || val === undefined) return 'NULL';
  const s = String(val).trim();
  if (s === '') return 'NULL';
  return `'${s.replace(/'/g, "''")}'`;
}

// ─── Text item grouping ───────────────────────────────────────────────────────

/** Build a sorted array of {x, y, text} from pdfjs content items */
function extractItems(contentItems) {
  return contentItems
    .filter(it => it.str && it.str.trim())
    .map(it => ({
      x: it.transform[4],
      y: it.transform[5],
      text: it.str.trim(),
    }))
    .sort((a, b) => b.y - a.y || a.x - b.x); // top-to-bottom, left-to-right
}

// ─── Column detection ─────────────────────────────────────────────────────────

/**
 * Detect column x-positions from table header items.
 * Returns { aula?, conteudo?, objetivos?, habilidades?, ae?,
 *           titulo?, eixo?, objeto?, unidade? } — raw header x.
 */
function detectRawCols(items) {
  const cols = {};
  for (const it of items) {
    const t = it.text.toLowerCase().replace(/\s+/g, ' ').trim();
    if (/^aula$|^n[oº°]?\s*aula/.test(t))              cols.aula        = it.x;
    else if (/t[íi]tulo/.test(t))                       cols.titulo      = it.x;
    else if (/conte[úu]do/.test(t))                     cols.conteudo    = it.x;
    else if (/objetivo/.test(t))                        cols.objetivos   = it.x;
    else if (/habilidade/.test(t))                      cols.habilidades = it.x;
    else if (/aprendizagem\s+essencial|^ae\b/.test(t))  cols.ae          = it.x;
    else if (/^eixo/.test(t))                           cols.eixo        = it.x;
    else if (/objeto.*conhecimento/.test(t))             cols.objeto      = it.x;
    else if (/unidade.*tem[aá]tica/.test(t))             cols.unidade     = it.x;
  }
  return cols;
}

/**
 * Convert raw header x-positions to column LEFT BOUNDARIES using midpoints.
 * The first column always starts at x=0.
 * Returns { colName: leftBoundaryX, ... }
 */
function toMidpointBounds(rawCols) {
  const sorted = Object.entries(rawCols).sort((a, b) => a[1] - b[1]);
  const bounds = {};
  for (let i = 0; i < sorted.length; i++) {
    const [name, x] = sorted[i];
    bounds[name] = i === 0 ? 0 : Math.floor((sorted[i - 1][1] + x) / 2);
  }
  return bounds;
}

/**
 * Given an item x and midpoint boundaries, return the column name.
 */
function getCol(x, bounds) {
  // bounds = { colName: leftBoundaryX, ... } sorted ascending
  const sorted = Object.entries(bounds).sort((a, b) => a[1] - b[1]);
  let col = sorted[0]?.[0] ?? 'aula';
  for (const [name, bx] of sorted) {
    if (x >= bx) col = name;
    else break;
  }
  return col;
}

// ─── Page parser ──────────────────────────────────────────────────────────────

/**
 * Parse one PDF page. Updates context.serie / context.bimestre in place.
 * @returns Array of lesson (aula) objects for this page, or []
 */
function parsePage(allItems, context, disciplinaNome, ciclo, debugMode) {
  // Find table header: line where text matches "Aula" + "Conteúdo|objetivo|habilidade"
  // Group items by y (within Y_TOL=3pt) to find header line y
  const Y_TOL = 3;

  // Build y-groups (lines)
  const lineMap = new Map(); // y → items[]
  for (const it of allItems) {
    let foundY = null;
    for (const [ly] of lineMap) {
      if (Math.abs(it.y - ly) <= Y_TOL) { foundY = ly; break; }
    }
    if (foundY === null) lineMap.set(it.y, [it]);
    else lineMap.get(foundY).push(it);
  }

  // Sort line y-values descending (top to bottom)
  const lineYs = [...lineMap.keys()].sort((a, b) => b - a);

  if (debugMode) {
    process.stderr.write(`  --- page lines ---\n`);
    for (const y of lineYs) {
      const text = lineMap.get(y).map(it => `[x=${Math.round(it.x)} "${it.text}"]`).join(' ');
      process.stderr.write(`  y=${Math.round(y)}: ${text}\n`);
    }
  }

  // Find table header y
  let tableHeaderY = null;
  let rawCols = {};
  for (const y of lineYs) {
    const items = lineMap.get(y);
    const text = items.map(i => i.text).join(' ');
    if (/\baula\b/i.test(text) && /conte[úu]do|objetivo|habilidade|aprendizagem/i.test(text)) {
      tableHeaderY = y;
      rawCols = detectRawCols(items);
      break;
    }
  }

  if (tableHeaderY === null || Object.keys(rawCols).length < 2) {
    if (debugMode) process.stderr.write('  [skip] no table header found on page\n');
    return [];
  }

  if (debugMode) {
    process.stderr.write(`  tableHeaderY=${Math.round(tableHeaderY)}, rawCols=${JSON.stringify(rawCols)}\n`);
  }

  // Extract serie/bimestre from items ABOVE the table header
  const headerText = allItems
    .filter(it => it.y > tableHeaderY + Y_TOL)
    .map(it => it.text)
    .join(' ');

  const sm = headerText.match(SERIE_RE);
  if (sm) context.serie = sm[1];
  const bm = headerText.match(BIM_RE);
  if (bm) context.bimestre = parseInt(bm[1], 10);

  if (debugMode) {
    process.stderr.write(`  serie=${context.serie}, bimestre=${context.bimestre}\n`);
  }

  if (!context.serie || !context.bimestre) return [];

  // Column boundaries (midpoints)
  const colBounds = toMidpointBounds(rawCols);
  const conteudoBound = colBounds.conteudo ?? colBounds.titulo ?? 100;

  // Data items: below the table header
  const dataItems = allItems.filter(it => it.y < tableHeaderY - Y_TOL);

  // Find lesson number anchors: x < conteudoBound/2, pure integer 1-999
  const xNumMax = conteudoBound / 2; // threshold to distinguish number from title
  const anchors = dataItems
    .filter(it => it.x < xNumMax && /^\d+$/.test(it.text) && parseInt(it.text, 10) > 0)
    .sort((a, b) => b.y - a.y); // top-to-bottom order

  if (debugMode) {
    process.stderr.write(`  colBounds=${JSON.stringify(colBounds)}, xNumMax=${xNumMax}\n`);
    process.stderr.write(`  anchors: ${anchors.map(a => `${a.text}@y=${Math.round(a.y)}`).join(', ')}\n`);
  }

  if (anchors.length === 0) return [];

  // For each anchor, define y-range [yLow, yHigh)
  const lessons = [];
  for (let i = 0; i < anchors.length; i++) {
    const anchor = anchors[i];
    const aulaNum = parseInt(anchor.text, 10);
    const yHigh = i === 0
      ? tableHeaderY - Y_TOL             // first lesson: up to table header
      : Math.floor((anchors[i - 1].y + anchor.y) / 2);
    const yLow = i === anchors.length - 1
      ? 0                                // last lesson: down to page bottom
      : Math.floor((anchor.y + anchors[i + 1].y) / 2);

    // Collect items in this y-range and assign to columns
    const cells = {};
    for (const it of dataItems) {
      if (it.y < yLow || it.y > yHigh) continue;
      const col = getCol(it.x, colBounds);
      cells[col] = cells[col] ? cells[col] + ' ' + it.text : it.text;
    }

    // Build aula record
    const aulaColText = cells.aula || '';

    // Extract title: aula column text minus the lesson number
    const titulo = aulaColText
      .replace(/\b\d+\b/, '')  // remove the first standalone number (lesson num)
      .replace(/\s+/g, ' ')
      .trim()
      .substring(0, 400);

    // Conteúdo: remove bullet characters
    const conteudo = (cells.conteudo || '')
      .replace(/•\s*/g, '\n• ')
      .replace(/^\s*\n/, '')
      .replace(/\s+/g, ' ')
      .trim();

    const objetivos = (cells.objetivos || '')
      .replace(/•\s*/g, '\n• ')
      .replace(/^\s*\n/, '')
      .replace(/\s+/g, ' ')
      .trim();

    // Habilidades: extract BNCC codes
    const rawHab = (cells.habilidades || '').replace(/\s+/g, ' ').trim();
    const bnccCodes = [...new Set(rawHab.match(BNCC_RE) || [])];
    const habilidadeCodigo = bnccCodes.join(', ');
    // Remaining text after removing codes = description
    const habilidadeTexto = rawHab.replace(BNCC_RE, '').replace(/\s+/g, ' ').trim();

    const unidadeTematica = (cells.ae || cells.unidade || '')
      .replace(/\s+/g, ' ')
      .trim();

    // titulo fallback
    const finalTitulo = titulo ||
      (conteudo ? conteudo.split(/[\n.;]/)[0].trim().substring(0, 400) : `Aula ${aulaNum}`);

    lessons.push({
      ciclo,
      serie:               context.serie,
      bimestre:            context.bimestre,
      aula_num:            aulaNum,
      disciplina_nome:     disciplinaNome,
      titulo:              finalTitulo,
      conteudo,
      objetivos,
      habilidade_codigo:   habilidadeCodigo,
      habilidade_texto:    habilidadeTexto,
      unidade_tematica:    unidadeTematica,
      eixo:                (cells.eixo  || '').replace(/\s+/g, ' ').trim(),
      objeto_conhecimento: (cells.objeto || '').replace(/\s+/g, ' ').trim(),
      bloco:               '',
    });
  }

  return lessons;
}

// ─── AE extraction ────────────────────────────────────────────────────────────

/**
 * Extract AprendizagemEssencial records from populated aulas.
 * Parses AE codes from unidade_tematica field.
 */
function extractAEs(aulas) {
  const map = new Map();
  for (const a of aulas) {
    const text = a.unidade_tematica;
    if (!text) continue;

    // Find all "AE1 - description..." patterns
    const re = /AE(\d+)\s*[-–]\s*([^A-Z(]*(?:AE\d+|$)?)/g;
    let m;
    while ((m = re.exec(text)) !== null) {
      const codigo = `AE${m[1]}`;
      const key    = `${codigo}|${a.disciplina_nome}|${a.ciclo}|${a.serie}|${a.bimestre}`;
      if (!map.has(key)) {
        // Extract full description: from "AEn -" to the next "AEm" or end
        const fullRe = new RegExp(`${codigo}\\s*[-–]\\s*([\\s\\S]*?)(?=\\bAE\\d+\\b|$)`);
        const fm     = text.match(fullRe);
        const desc   = fm ? fm[1].replace(/\s+/g, ' ').trim() : '';
        if (desc) {
          map.set(key, {
            codigo,
            descricao:       desc,
            disciplina_nome: a.disciplina_nome,
            ciclo:           a.ciclo,
            serie:           a.serie,
            bimestre:        a.bimestre,
          });
        }
      }
    }
  }
  return [...map.values()];
}

// ─── Main PDF parser ──────────────────────────────────────────────────────────

async function parsePdf(filePath, disciplinaNome, ciclo, debugMode) {
  const data = new Uint8Array(fs.readFileSync(filePath));
  const pdf  = await pdfjsLib.getDocument({
    data,
    useWorkerFetch:  false,
    isEvalSupported: false,
    useSystemFonts:  true,
  }).promise;

  const allAulas = [];
  const context  = { serie: null, bimestre: null };

  for (let p = 1; p <= pdf.numPages; p++) {
    const page    = await pdf.getPage(p);
    const content = await page.getTextContent({ normalizeWhitespace: true });
    const items   = extractItems(content.items);

    if (debugMode) process.stderr.write(`\n[PAGE ${p}]\n`);

    const lessons = parsePage(items, context, disciplinaNome, ciclo, debugMode);
    allAulas.push(...lessons);

    if (debugMode) {
      process.stderr.write(`  => ${lessons.length} lessons: ${lessons.map(l => l.aula_num).join(',')}\n`);
    }
  }

  return { aulas: allAulas, aes: extractAEs(allAulas) };
}

// ─── SQL generation ───────────────────────────────────────────────────────────

const AULAS_COLS = `(ciclo, serie, bimestre, aula_num, disciplina_nome,
   titulo, conteudo, objetivos,
   habilidade_codigo, habilidade_texto,
   unidade_tematica, eixo, objeto_conhecimento, bloco)`;

function aulaToRow(a) {
  return (
    `  (${sqlStr(a.ciclo)}, ${sqlStr(a.serie)}, ${a.bimestre}, ${a.aula_num}, ${sqlStr(a.disciplina_nome)},\n` +
    `   ${sqlStr(a.titulo.substring(0, 400))}, ${sqlStr(a.conteudo)}, ${sqlStr(a.objetivos)},\n` +
    `   ${sqlStr(a.habilidade_codigo)}, ${sqlStr(a.habilidade_texto)},\n` +
    `   ${sqlStr(a.unidade_tematica)}, ${sqlStr(a.eixo)}, ${sqlStr(a.objeto_conhecimento)}, NULL)`
  );
}

const AE_COLS = `(codigo, descricao, disciplina_nome, ciclo, serie, bimestre)`;

function aeToRow(ae) {
  return (
    `  (${sqlStr(ae.codigo)}, ${sqlStr(ae.descricao)}, ${sqlStr(ae.disciplina_nome)},\n` +
    `   ${sqlStr(ae.ciclo)}, ${sqlStr(ae.serie)}, ${ae.bimestre})`
  );
}

function batchInsert(table, cols, rows, batchSize = 100) {
  const parts = [];
  for (let i = 0; i < rows.length; i += batchSize) {
    const batch = rows.slice(i, i + batchSize);
    parts.push(`INSERT INTO ${table}\n  ${cols}\nVALUES\n${batch.join(',\n')};`);
  }
  return parts.join('\n\n');
}

// ─── Entry point ──────────────────────────────────────────────────────────────

async function main() {
  const rawArgs  = process.argv.slice(2);
  const debugMode = rawArgs.includes('--debug');
  const args = rawArgs.filter(a => a !== '--debug');

  let filesToProcess;
  if (args.length > 0) {
    filesToProcess = args.map(f => {
      const filename = path.basename(f);
      const filePath = path.isAbsolute(f) ? f : path.join(DOCS_DIR, filename);
      return { filename, filePath };
    }).filter(({ filename }) => {
      if (!FILE_MAP[filename]) {
        process.stderr.write(`[SKIP] ${filename}: not in FILE_MAP\n`);
        return false;
      }
      return true;
    });
  } else {
    filesToProcess = Object.keys(FILE_MAP).map(filename => ({
      filename,
      filePath: path.join(DOCS_DIR, filename),
    }));
  }

  const allAulas = [];
  const allAes   = [];
  const errors   = [];

  for (const { filename, filePath } of filesToProcess) {
    if (!fs.existsSync(filePath)) {
      errors.push(`Arquivo não encontrado: ${filePath}`);
      process.stderr.write(`[SKIP] ${filename}: não encontrado\n`);
      continue;
    }
    const { nome, ciclo } = FILE_MAP[filename];
    try {
      const { aulas, aes } = await parsePdf(filePath, nome, ciclo, debugMode);
      allAulas.push(...aulas);
      allAes.push(...aes);
      process.stderr.write(`[OK]  ${filename}: ${aulas.length} aulas, ${aes.length} AEs\n`);
    } catch (e) {
      errors.push(`${filename}: ${e.message}`);
      process.stderr.write(`[ERR] ${filename}: ${e.message}\n${e.stack}\n`);
    }
  }

  process.stderr.write(`\nTotal: ${allAulas.length} aulas, ${allAes.length} aprendizagens_essenciais\n`);

  if (errors.length) {
    process.stderr.write('\nErros:\n' + errors.map(e => '  ! ' + e).join('\n') + '\n');
  }

  if (debugMode) {
    process.stderr.write('\n[DEBUG] Sample aulas:\n');
    for (const a of allAulas.slice(0, 5)) {
      process.stderr.write(JSON.stringify(a, null, 2) + '\n');
    }
    return;
  }

  if (allAulas.length === 0) {
    process.stderr.write(
      '\nATENÇÃO: Nenhuma aula extraída.\n' +
      'Use --debug para inspecionar a estrutura do PDF:\n' +
      '  node parse_pdf_curriculum.js --debug MAT_AF_V2.pdf 2>&1 | head -100\n'
    );
    process.exit(1);
  }

  // ── Header ────────────────────────────────────────────────────────────────
  const disciplines = [...new Set(allAulas.map(a => `${a.disciplina_nome} (${a.ciclo})`))].join(', ');
  console.log(
`-- =============================================================================
-- seed_paper_aulas_pdf.sql
-- Currículo Escopo-Sequência SP 2026 → samba_paper.aulas + aprendizagens_essenciais
-- Gerado por parse_pdf_curriculum.js em ${new Date().toISOString().slice(0, 10)}
-- Disciplinas: ${disciplines}
-- Total: ${allAulas.length} aulas | ${allAes.length} aprendizagens_essenciais
--
-- Pré-requisito: migrate_paper_v3.sql já aplicado.
-- Aplicar: docker exec -i samba_db psql -U postgres -d samba_db < seed_paper_aulas_pdf.sql
-- =============================================================================
`);

  // ── Delete existing records for these disciplines ─────────────────────────
  const disciplineNames = [...new Set(allAulas.map(a => a.disciplina_nome))];
  console.log(
    '-- Remove registros anteriores das mesmas disciplinas\n' +
    `DELETE FROM samba_paper.aprendizagens_essenciais\n` +
    `  WHERE disciplina_nome IN (${disciplineNames.map(sqlStr).join(', ')});\n\n` +
    `DELETE FROM samba_paper.aulas\n` +
    `  WHERE disciplina_nome IN (${disciplineNames.map(sqlStr).join(', ')});\n`
  );

  // ── Insert aulas ──────────────────────────────────────────────────────────
  console.log('-- Aulas\n');
  console.log(batchInsert('samba_paper.aulas', AULAS_COLS, allAulas.map(aulaToRow)));

  // ── Insert aprendizagens_essenciais ──────────────────────────────────────
  if (allAes.length > 0) {
    console.log('\n\n-- Aprendizagens Essenciais\n');
    console.log(batchInsert(
      'samba_paper.aprendizagens_essenciais',
      AE_COLS,
      allAes.map(aeToRow)
    ));
  }

  console.log('\n-- FIM');
}

main().catch(err => {
  process.stderr.write(`Erro fatal: ${err.message}\n${err.stack}\n`);
  process.exit(1);
});
