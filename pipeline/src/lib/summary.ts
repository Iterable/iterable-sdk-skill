/**
 * Deterministic summary extraction for polished article bodies.
 *
 * The summary is the first 1–2 prose paragraphs, joined as one line and
 * truncated to ~400 characters. "Prose" excludes:
 *   - headings (`#`)
 *   - callouts (lines starting with `>`)
 *   - fenced code blocks (between matching ``` markers)
 *   - list items (`- `, `* `, `1. `)
 *   - HTML tags as the first character
 *   - blank lines
 *
 * If a candidate paragraph is < `minLen` characters, the next prose
 * paragraph is appended (with a single space separator) until we reach
 * either `minLen` or run out of candidates. The result is then truncated
 * to `maxLen` characters, falling back to a word boundary.
 *
 * Returns `undefined` if no prose paragraph exists (e.g. file is all
 * headings + lists). Callers can supply their own fallback (e.g. the
 * article title).
 */

export interface SummaryOptions {
  /** Minimum acceptable character length. Defaults to 80. */
  minLen?: number;
  /** Maximum character length (after truncation). Defaults to 400. */
  maxLen?: number;
}

export function extractSummary(body: string, opts: SummaryOptions = {}): string | undefined {
  const minLen = opts.minLen ?? 80;
  const maxLen = opts.maxLen ?? 400;

  const paragraphs = splitProseParagraphs(body);
  if (paragraphs.length === 0) return undefined;

  let summary = paragraphs[0]!;
  let i = 1;
  while (summary.length < minLen && i < paragraphs.length) {
    summary = `${summary} ${paragraphs[i]!}`;
    i++;
  }

  return truncateOnWord(summary, maxLen);
}

function splitProseParagraphs(body: string): string[] {
  const lines = body.split(/\r?\n/);
  const out: string[] = [];
  let inFence = false;
  let buffer: string[] = [];

  const flush = () => {
    const para = buffer.join(" ").replace(/\s+/g, " ").trim();
    if (para.length > 0) out.push(para);
    buffer = [];
  };

  for (const line of lines) {
    if (/^ {0,3}```/.test(line)) {
      flush();
      inFence = !inFence;
      continue;
    }
    if (inFence) continue;

    if (line.trim() === "") {
      flush();
      continue;
    }

    const t = line.trim();
    if (
      t.startsWith("#") ||
      t.startsWith(">") ||
      t.startsWith("- ") ||
      t.startsWith("* ") ||
      /^\d+\.\s/.test(t) ||
      t.startsWith("<") ||
      t.startsWith("|")
    ) {
      flush();
      continue;
    }

    buffer.push(t);
  }
  flush();
  return out;
}

function truncateOnWord(text: string, maxLen: number): string {
  if (text.length <= maxLen) return text;
  const slice = text.slice(0, maxLen);
  const lastSpace = slice.lastIndexOf(" ");
  const boundary = lastSpace > maxLen * 0.7 ? lastSpace : maxLen;
  return slice.slice(0, boundary).replace(/[,;:.\s]+$/, "") + "…";
}
