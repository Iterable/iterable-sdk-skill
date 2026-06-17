/**
 * Stage 2 — Polish, Layer A.
 *
 * Deterministic markdown transforms applied to a `sources/<platform>/<slug>.md`
 * file before the LLM polish step. Each transform is small, reversible, and
 * easy to unit-test. Editorial decisions (drop Java when Kotlin sibling
 * exists, etc.) are deferred to Layer B.
 *
 * The output is "Layer A intermediate" markdown — not yet the final polish.
 */

import { createHash } from "node:crypto";
import { splitFrontmatter, joinFrontmatter, type Frontmatter } from "./frontmatter.ts";
import { extractSummary } from "./summary.ts";

// ── Public API ──────────────────────────────────────────────────────

export interface LayerAContext {
  /** Article slug (used as identity, not for I/O). */
  slug: string;
  /** Feature tag from pipeline config. */
  feature: string;
  /** Archetype tag from pipeline config. */
  archetype: "integration" | "feature" | "identity";
  /** SDK version pin (e.g. "3.7.0") from config. */
  sdkVersion: string;
  /** SDK Maven coordinate base (e.g. "iterableapi") for version banner. */
  sdkArtifact: string;
}

export interface SnippetEntry {
  index: number;
  lang: string;
  hash: string;
  line_count: number;
}

export interface LayerAResult {
  output: string;
  snippets: SnippetEntry[];
}

export function applyLayerA(raw: string, ctx: LayerAContext): LayerAResult {
  const { frontmatter, body } = splitFrontmatter(raw);

  // Manifest is computed against the source body so it captures every
  // original snippet — including fences inside containers — regardless of
  // how the structural transforms below reshape them.
  const snippets = collectSnippets(body);

  let working = body;
  working = stripTocMarker(working);
  working = stripZendeskImages(working);
  working = convertContainers(working);
  working = stripFurtherReading(working);
  working = working.replace(/​/g, ""); // VuePress sprinkles zero-width spaces
  working = collapseBlankLines(working);

  // Extract summary from the post-transform body so it reflects what
  // Context7 would actually index (no TOC marker, no Zendesk image lines,
  // callouts converted to GH style).
  const summary = extractSummary(working);

  const newFrontmatter = rewriteFrontmatter(frontmatter, ctx, snippets, summary);
  return { output: joinFrontmatter(newFrontmatter, working), snippets };
}

// ── Frontmatter rewrite ─────────────────────────────────────────────

function rewriteFrontmatter(
  fm: Frontmatter,
  ctx: LayerAContext,
  snippets: SnippetEntry[],
  summary: string | undefined,
): Frontmatter {
  const out: Frontmatter = {
    slug: ctx.slug,
    feature: ctx.feature,
    archetype: ctx.archetype,
    sdk_min_version: ctx.sdkVersion,
    sdk_artifact: ctx.sdkArtifact,
    title: fm.title,
    source_url: fm.url,
    source_repo: fm.source_repo,
    source_path: fm.source_path,
    source_ref: fm.source_ref,
    source_sha: fm.source_sha,
    fetched_at: fm.fetched_at,
    polished_at: new Date().toISOString(),
    layer: "a",
    snippets,
  };
  if (summary !== undefined) out.summary = summary;
  return out;
}

// ── Transforms ──────────────────────────────────────────────────────

function stripTocMarker(text: string): string {
  // VuePress TOC marker, often preceded by an "## In this article" header.
  return text.replace(/(^|\n)## In this article\s*\n+\[\[toc\]\]\s*\n+/g, "$1");
}

function stripZendeskImages(text: string): string {
  // Markdown image whose URL points at iterable.zendesk.com — dashboard /
  // device screenshots that don't help an agent reading the doc.
  const lines = text.split("\n");
  const kept: string[] = [];
  for (const line of lines) {
    if (/^!\[[^\]]*\]\(https:\/\/iterable\.zendesk\.com\/[^)]*\)\s*$/.test(line.trim())) continue;
    kept.push(line);
  }
  return kept.join("\n");
}

const CATEGORY_LABELS = new Set(["TIP", "NOTE", "NOTES", "INFO", "WARNING", "IMPORTANT", "CAUTION", "DANGER"]);

function calloutKindFor(type: string, label: string | undefined): {
  kind: "NOTE" | "TIP" | "WARNING" | "CAUTION";
  descriptiveLabel: string | undefined;
} {
  const trimmed = (label ?? "").trim();
  // Source authors mix two label styles in one slot:
  //   `:::warning IMPORTANT`                           → category only
  //   `:::tip Auto-retry for offline processing (...)` → descriptive only
  //   `:::warning IMPORTANT — Migration from older …`  → category + tail
  // Split on the first dash/em-dash/hyphen separator and decide per-side.
  const sep = /\s+[—–-]\s+/;
  const parts = trimmed.split(sep);
  const headRaw = (parts[0] ?? "").trim();
  const tailRaw = parts.length > 1 ? parts.slice(1).join(" — ").trim() : "";
  const head = headRaw.toUpperCase();

  let kind: "NOTE" | "TIP" | "WARNING" | "CAUTION";
  let categoryConsumed = false;
  if (CATEGORY_LABELS.has(head)) {
    categoryConsumed = true;
    if (head === "WARNING" || head === "IMPORTANT" || head === "CAUTION") kind = "WARNING";
    else if (head === "DANGER") kind = "CAUTION";
    else if (head === "TIP") kind = "TIP";
    else kind = "NOTE";
  } else if (type === "danger") kind = "CAUTION";
  else if (type === "warning") kind = "WARNING";
  else if (type === "tip") kind = "TIP";
  else kind = "NOTE";

  // What survives as the descriptive title:
  //   - If we consumed the head as a category, the tail (if any) is the title.
  //   - Otherwise the entire trimmed label is the title.
  const descriptiveLabel = categoryConsumed
    ? tailRaw || undefined
    : trimmed || undefined;
  return { kind, descriptiveLabel };
}

const CALLOUT_GLYPH: Record<"NOTE" | "TIP" | "WARNING" | "CAUTION", string> = {
  NOTE: "ℹ️",
  TIP: "💡",
  WARNING: "⚠️",
  CAUTION: "🛑",
};

function convertContainers(text: string): string {
  // Match `:::<type> [optional label]\n…\n:::` (multi-line). The trailing
  // `[ \t]*$` only consumes horizontal whitespace so the blank line that
  // typically follows the closing `:::` survives the substitution.
  const re = /^:::(tip|warning|danger|info|note)[ \t]*([^\n]*)\n([\s\S]*?)\n:::[ \t]*$/gm;
  return text.replace(re, (_match, type: string, rawLabel: string, inner: string) => {
    const label = rawLabel.trim() || undefined;
    const { kind, descriptiveLabel } = calloutKindFor(type, label);
    const innerTrimmed = inner.trimEnd();

    // GitHub callouts (`> [!WARNING]`) require the entire body to be a
    // blockquote, but blockquoted code fences (`> ```kotlin`) are not
    // valid markdown — parsers render them as quoted prose. When the
    // body contains a fence we demote to a bold-header callout: the
    // category + title appear as a bold line followed by the body
    // verbatim. Visual styling is lost; faithful content survives.
    const containsFence = /^[ \t]*```/m.test(innerTrimmed);
    if (containsFence) {
      const glyph = CALLOUT_GLYPH[kind];
      const heading = descriptiveLabel
        ? `**${glyph} ${kind} — ${descriptiveLabel}**`
        : `**${glyph} ${kind}**`;
      return [heading, "", innerTrimmed].join("\n");
    }

    const innerLines = innerTrimmed.split("\n");
    const titleLine = descriptiveLabel ? [`> **${descriptiveLabel}**`, ">"] : [];
    const quoted = innerLines.map((l) => (l === "" ? ">" : `> ${l}`));
    return [`> [!${kind}]`, ...titleLine, ...quoted].join("\n");
  });
}

function stripFurtherReading(text: string): string {
  // Trailing "## Further reading" and everything after it. Customer-doc
  // navigation that doesn't add value for an agent reading the polished doc.
  const idx = text.search(/\n##\s+Further reading\s*\n/i);
  if (idx === -1) return text;
  return text.slice(0, idx).trimEnd() + "\n";
}

function collapseBlankLines(text: string): string {
  // Three or more blank lines collapse to two; transforms tend to leave
  // ragged blanks behind.
  return text.replace(/\n{3,}/g, "\n\n").replace(/^\n+/, "");
}

// ── Snippet manifest ────────────────────────────────────────────────

/**
 * Walks the markdown line by line and emits one manifest entry per code
 * fence. CommonMark allows fences to be indented by 0–3 spaces; strict
 * `^```/` matching misses indented closing fences and produces a giant
 * accidental snippet that swallows everything until the next column-0
 * fence. The patterns below stay CommonMark-compliant.
 *
 * Note: fences indented by 4+ spaces are not fences per CommonMark — they
 * are part of an indented code block — and are intentionally not matched.
 */
export function collectSnippets(text: string): SnippetEntry[] {
  const out: SnippetEntry[] = [];
  const lines = text.split("\n");
  const openRe = /^ {0,3}```([a-zA-Z0-9_+-]*)\s*$/;
  const closeRe = /^ {0,3}```\s*$/;
  let inFence = false;
  let fenceLang = "";
  let fenceLines: string[] = [];
  let index = 0;

  for (let i = 0; i < lines.length; i++) {
    const line = lines[i] ?? "";
    const open = openRe.exec(line);
    if (!inFence && open) {
      inFence = true;
      fenceLang = open[1] ?? "";
      fenceLines = [];
      continue;
    }
    if (inFence && closeRe.test(line)) {
      const content = fenceLines.join("\n");
      const hash = createHash("sha256").update(content).digest("hex").slice(0, 12);
      out.push({
        index,
        lang: fenceLang || "text",
        hash,
        line_count: fenceLines.length,
      });
      index++;
      inFence = false;
      fenceLang = "";
      fenceLines = [];
      continue;
    }
    if (inFence) fenceLines.push(line);
  }
  return out;
}
