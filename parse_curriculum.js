#!/usr/bin/env node
/**
 * parse_curriculum.js
 * Parses AF and EM escopo-sequência HTML files and generates SQL for samba_paper.aulas
 *
 * Usage: node parse_curriculum.js > seed_paper_aulas.sql
 */

const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

// ─── Config ──────────────────────────────────────────────────────────────────
const BASE_DIR = 'C:/Users/Vinicius-SambaCode/Documents/projetos/samba.generator/novos';
const AF_DIR   = path.join(BASE_DIR, 'AF Escopo-sequência 2026_arquivos');
const EM_DIR   = path.join(BASE_DIR, 'EM Escopo-sequência 2026_arquivos');

// ─── Helpers ─────────────────────────────────────────────────────────────────

/** Read file as UTF-8, converting from windows-1252 */
function readHtml(filePath) {
  const buf = fs.readFileSync(filePath);
  // Decode windows-1252 manually using Buffer latin1 → decode table
  return decodeWindows1252(buf);
}

/** Simple windows-1252 → utf-8 decoder */
function decodeWindows1252(buf) {
  // windows-1252 extra chars in 0x80-0x9F range
  const w1252 = {
    0x80: '\u20AC', 0x82: '\u201A', 0x83: '\u0192', 0x84: '\u201E',
    0x85: '\u2026', 0x86: '\u2020', 0x87: '\u2021', 0x88: '\u02C6',
    0x89: '\u2030', 0x8A: '\u0160', 0x8B: '\u2039', 0x8C: '\u0152',
    0x8E: '\u017D', 0x91: '\u2018', 0x92: '\u2019', 0x93: '\u201C',
    0x94: '\u201D', 0x95: '\u2022', 0x96: '\u2013', 0x97: '\u2014',
    0x98: '\u02DC', 0x99: '\u2122', 0x9A: '\u0161', 0x9B: '\u203A',
    0x9C: '\u0153', 0x9E: '\u017E', 0x9F: '\u0178',
  };
  let out = '';
  for (let i = 0; i < buf.length; i++) {
    const b = buf[i];
    if (b < 0x80) {
      out += String.fromCharCode(b);
    } else if (w1252[b] !== undefined) {
      out += w1252[b];
    } else {
      out += String.fromCharCode(b); // latin-1 passthrough
    }
  }
  return out;
}

/** Decode HTML entities */
function decodeEntities(str) {
  if (!str) return '';
  return str
    .replace(/&amp;/g,  '&')
    .replace(/&lt;/g,   '<')
    .replace(/&gt;/g,   '>')
    .replace(/&quot;/g, '"')
    .replace(/&#8210;/g, '–')  // figure dash
    .replace(/&#(\d+);/g, (_, n) => String.fromCharCode(Number(n)))
    .replace(/&nbsp;/g, ' ')
    .replace(/&aacute;/g, 'á').replace(/&eacute;/g, 'é')
    .replace(/&iacute;/g, 'í').replace(/&oacute;/g, 'ó')
    .replace(/&uacute;/g, 'ú').replace(/&Aacute;/g, 'Á')
    .replace(/&Eacute;/g, 'É').replace(/&Iacute;/g, 'Í')
    .replace(/&Oacute;/g, 'Ó').replace(/&Uacute;/g, 'Ú')
    .replace(/&atilde;/g, 'ã').replace(/&otilde;/g, 'õ')
    .replace(/&Atilde;/g, 'Ã').replace(/&Otilde;/g, 'Õ')
    .replace(/&ccedil;/g, 'ç').replace(/&Ccedil;/g, 'Ç')
    .replace(/&acirc;/g, 'â').replace(/&ecirc;/g, 'ê')
    .replace(/&ocirc;/g, 'ô').replace(/&Acirc;/g, 'Â')
    .replace(/&Ecirc;/g, 'Ê').replace(/&Ocirc;/g, 'Ô')
    .replace(/&agrave;/g, 'à').replace(/&Agrave;/g, 'À')
    .replace(/&uuml;/g, 'ü').replace(/&euml;/g, 'ë')
    .replace(/&ntilde;/g, 'ñ');
}

/** Strip HTML tags and normalize whitespace */
function stripHtml(html) {
  if (!html) return '';
  // Replace <br>, <br />, <p> with newline
  let t = html
    .replace(/<br\s*\/?>/gi, '\n')
    .replace(/<\/p>/gi, '\n')
    .replace(/<[^>]+>/g, '')
    .replace(/\r\n/g, '\n')
    .replace(/\r/g, '\n');
  t = decodeEntities(t);
  // Trim each line, remove empty lines at start/end, collapse 3+ newlines
  t = t.split('\n').map(l => l.trim()).join('\n').trim();
  t = t.replace(/\n{3,}/g, '\n\n');
  return t;
}

/** Escape SQL string */
function sqlStr(val) {
  if (!val || val.trim() === '' || val.trim() === '&nbsp;') return 'NULL';
  const s = val.trim().replace(/'/g, "''");
  return `'${s}'`;
}

/** Parse tab names from tabstrip.htm */
function parseTabNames(dir) {
  const tabFile = path.join(dir, 'tabstrip.htm');
  const html = readHtml(tabFile);
  const tabs = [];
  const re = /href="(sheet\d+\.htm)"[^>]*>.*?<font[^>]*>([^<]+)<\/font>/g;
  let m;
  while ((m = re.exec(html)) !== null) {
    tabs.push({ file: m[1], name: stripHtml(m[2]).trim() });
  }
  return tabs;
}

/** Parse all <tr> rows from a sheet, return array of arrays of cell text */
function parseRows(html) {
  const rows = [];
  // Extract all <tr>...</tr>
  const trRe = /<tr[^>]*>([\s\S]*?)<\/tr>/gi;
  let trMatch;
  while ((trMatch = trRe.exec(html)) !== null) {
    const trHtml = trMatch[1];
    // Extract all <td>...</td>
    const tdRe = /<td[^>]*>([\s\S]*?)<\/td>/gi;
    const cells = [];
    let tdMatch;
    while ((tdMatch = tdRe.exec(trHtml)) !== null) {
      cells.push(stripHtml(tdMatch[1]));
    }
    if (cells.length > 0) rows.push(cells);
  }
  return rows;
}

/** Normalize ciclo value */
function normCiclo(raw) {
  if (!raw) return null;
  const s = raw.toLowerCase();
  if (s.includes('anos finais') || s.includes('fundamental')) return 'fundamental';
  if (s.includes('ensino médio') || s.includes('medio') || s.includes('médio')) return 'medio';
  if (s.includes('medio')) return 'medio';
  return raw.trim().substring(0, 30) || null;
}

/** Normalize serie: "7º" → "7", "1ª série" → "1", etc. */
function normSerie(raw) {
  if (!raw) return null;
  const m = raw.match(/(\d+)/);
  return m ? m[1] : raw.trim().substring(0, 10);
}

/** Normalize bimestre number */
function normBimestre(raw) {
  if (!raw) return null;
  const m = raw.match(/(\d+)/);
  if (!m) return null;
  const n = parseInt(m[1]);
  return (n >= 1 && n <= 4) ? n : null;
}

/** Normalize aula number */
function normAula(raw) {
  if (!raw) return null;
  const m = raw.match(/(\d+)/);
  return m ? parseInt(m[1]) : null;
}

// ─── Header detection ─────────────────────────────────────────────────────────

// Primary patterns (exact/strict matches — tried first)
const COL_PATTERNS_PRIMARY = {
  aula_num:         /^aulas?$|^n[oº°]?\s*aulas?$/i,
  habilidade_codigo:/^habilidade\s*[-–]\s*c[oó]d/i,
  habilidade_texto: /^habilidade\s*[-–]\s*text/i,
  titulo:           /^t[íi]tulo\s+(da\s+)?aula$/i,
};

// Fallback patterns (broader — tried if primary not matched)
const COL_PATTERNS = {
  ciclo:            /ciclo/i,
  serie:            /^(ano|s[eé]rie|série|s[eé]ire)/i,
  bimestre:         /bimestre/i,
  aula_num:         /\baula\b/i,
  habilidade_codigo:/habilidade.*c[oó]d|habilidades?\s+bncc.*c[oó]d|habilidades?\s+bncc\s*[-–]/i,
  habilidade_texto: /habilidade.*text|^habilidade\s+bncc\s*$/i,
  eixo:             /^eixo/i,
  unidade_tematica: /unidade\s+tem[áa]tica/i,
  objeto_conhecimento: /objeto.*conhecimento/i,
  titulo:           /t[íi]tulo/i,
  conteudo:         /conte[úu]do|^conteúdos?$/i,
  objetivos:        /objetivo/i,
  bloco:            /^bloco/i,
  disciplina_nome:  /disciplina|componente/i,
};

/** Detect column mapping from header row */
function detectColumns(headerRow) {
  const map = {};

  // Pass 1: strict/primary patterns
  headerRow.forEach((cell, i) => {
    const text = cell.replace(/\n/g, ' ').trim();
    for (const [key, pattern] of Object.entries(COL_PATTERNS_PRIMARY)) {
      if (pattern.test(text) && !(key in map)) {
        map[key] = i;
      }
    }
  });

  // Pass 2: fallback patterns (skip if already found)
  headerRow.forEach((cell, i) => {
    const text = cell.replace(/\n/g, ' ').trim();
    for (const [key, pattern] of Object.entries(COL_PATTERNS)) {
      if (!(key in map) && pattern.test(text)) {
        // For aula_num: skip cells that also contain "complementar" or "semana"
        if (key === 'aula_num' && /complementar|semana/i.test(text)) continue;
        map[key] = i;
      }
    }
  });

  return map;
}

/** Check if a row looks like a header row */
function isHeaderRow(row) {
  const joined = row.join(' ').toLowerCase();
  return joined.includes('bimestre') || joined.includes('aula') || joined.includes('ciclo');
}

/** Check if a row is empty or near-empty */
function isEmptyRow(row) {
  return row.every(c => !c || c.trim() === '' || c.trim() === '&nbsp;');
}

// ─── Main parse per sheet ─────────────────────────────────────────────────────

/**
 * Parse one discipline sheet.
 * Returns array of row objects ready for SQL.
 */
function parseSheet(filePath, sheetName, cicloOverride) {
  const html = readHtml(filePath);
  const rows = parseRows(html);

  if (rows.length === 0) return [];

  // Find header row (first row that contains 'bimestre' or 'aula')
  let headerIdx = -1;
  for (let i = 0; i < Math.min(5, rows.length); i++) {
    if (isHeaderRow(rows[i])) { headerIdx = i; break; }
  }

  let colMap = {};
  if (headerIdx >= 0) {
    colMap = detectColumns(rows[headerIdx]);
  }

  const results = [];

  for (let i = (headerIdx >= 0 ? headerIdx + 1 : 1); i < rows.length; i++) {
    const row = rows[i];
    if (isEmptyRow(row)) continue;

    const get = (key) => {
      if (colMap[key] !== undefined && colMap[key] < row.length) {
        return row[colMap[key]] || '';
      }
      return '';
    };

    // Try to extract bimestre and aula_num to verify it's a real data row
    let bimestre = normBimestre(get('bimestre'));
    let aulaNum  = normAula(get('aula_num'));

    // Some sheets have no explicit bimestre column — skip those rows
    if (!bimestre || !aulaNum) continue;

    // Ciclo: prefer column, then override, then sheet-level
    let cicloRaw = get('ciclo');
    let ciclo = normCiclo(cicloRaw) || cicloOverride || 'fundamental';

    // Serie
    let serie = normSerie(get('serie'));
    if (!serie) continue; // skip rows without series

    // titulo is NOT NULL — fallback to unidade_tematica or generic label
    const tituloRaw = get('titulo') || get('unidade_tematica') || `${sheetName} — Aula ${aulaNum}`;

    const record = {
      ciclo,
      serie,
      bimestre,
      aula_num:            aulaNum,
      disciplina_nome:     sheetName.substring(0, 200),
      eixo:                get('eixo'),
      unidade_tematica:    get('unidade_tematica'),
      habilidade_codigo:   get('habilidade_codigo'),  // TEXT in DB now
      habilidade_texto:    get('habilidade_texto'),
      objeto_conhecimento: get('objeto_conhecimento'),
      titulo:              tituloRaw.substring(0, 400),
      conteudo:            get('conteudo'),
      objetivos:           get('objetivos'),
      bloco:               get('bloco'),
    };
    results.push(record);
  }

  return results;
}

// ─── Generate SQL ─────────────────────────────────────────────────────────────

function toInsertRow(r) {
  return `  (${sqlStr(r.ciclo)}, ${sqlStr(r.serie)}, ${r.bimestre}, ${r.aula_num}, ` +
    `${sqlStr(r.disciplina_nome)}, ${sqlStr(r.eixo)}, ${sqlStr(r.unidade_tematica)}, ` +
    `${sqlStr(r.habilidade_codigo)}, ${sqlStr(r.habilidade_texto)}, ` +
    `${sqlStr(r.objeto_conhecimento)}, ${sqlStr(r.titulo)}, ` +
    `${sqlStr(r.conteudo)}, ${sqlStr(r.objetivos)}, ${sqlStr(r.bloco)})`;
}

// ─── Entry point ─────────────────────────────────────────────────────────────

function main() {
  const allRows = [];
  const errors = [];

  // Process both dirs
  const sources = [
    { dir: AF_DIR, cicloOverride: 'fundamental' },
    { dir: EM_DIR, cicloOverride: 'medio' },
  ];

  for (const { dir, cicloOverride } of sources) {
    const tabs = parseTabNames(dir);
    // Skip index sheet (first tab, usually "ÍNDICE")
    const disciplineTabs = tabs.filter(t => !t.name.match(/[íi]ndice/i));

    for (const tab of disciplineTabs) {
      const filePath = path.join(dir, tab.file);
      if (!fs.existsSync(filePath)) {
        errors.push(`Missing file: ${filePath}`);
        continue;
      }
      try {
        const rows = parseSheet(filePath, tab.name, cicloOverride);
        allRows.push(...rows);
        process.stderr.write(`  [OK] ${tab.name}: ${rows.length} aulas\n`);
      } catch (e) {
        errors.push(`Error parsing ${tab.file} (${tab.name}): ${e.message}`);
        process.stderr.write(`  [ERR] ${tab.name}: ${e.message}\n`);
      }
    }
  }

  if (errors.length > 0) {
    process.stderr.write('\nWarnings/Errors:\n');
    errors.forEach(e => process.stderr.write(`  ! ${e}\n`));
  }

  process.stderr.write(`\nTotal aulas: ${allRows.length}\n`);

  if (allRows.length === 0) {
    process.stderr.write('ERROR: No rows extracted!\n');
    process.exit(1);
  }

  // Output SQL
  const header = `-- =============================================================================
-- seed_paper_aulas.sql — Currículo escopo-sequência 2026 → samba_paper.aulas
-- Gerado automaticamente por parse_curriculum.js em ${new Date().toISOString().slice(0,10)}
-- Total: ${allRows.length} aulas
-- =============================================================================

TRUNCATE TABLE samba_paper.aulas RESTART IDENTITY CASCADE;

INSERT INTO samba_paper.aulas
  (ciclo, serie, bimestre, aula_num, disciplina_nome, eixo, unidade_tematica,
   habilidade_codigo, habilidade_texto, objeto_conhecimento, titulo,
   conteudo, objetivos, bloco)
VALUES\n`;

  const chunks = [];
  // Output in batches of 200 to avoid giant single statements
  const BATCH = 200;
  for (let start = 0; start < allRows.length; start += BATCH) {
    const batch = allRows.slice(start, start + BATCH);
    chunks.push(batch.map(toInsertRow).join(',\n'));
  }

  console.log(header + chunks.join(';\n\nINSERT INTO samba_paper.aulas\n  (ciclo, serie, bimestre, aula_num, disciplina_nome, eixo, unidade_tematica,\n   habilidade_codigo, habilidade_texto, objeto_conhecimento, titulo,\n   conteudo, objetivos, bloco)\nVALUES\n') + ';');
}

main();
