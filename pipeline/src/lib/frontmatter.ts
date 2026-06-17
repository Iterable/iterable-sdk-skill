import { parse as parseYaml, stringify as stringifyYaml } from "yaml";

const FENCE = "---";

export type Frontmatter = Record<string, unknown>;

export function splitFrontmatter(raw: string): {
  frontmatter: Frontmatter;
  body: string;
} {
  if (!raw.startsWith(`${FENCE}\n`) && !raw.startsWith(`${FENCE}\r\n`)) {
    return { frontmatter: {}, body: raw };
  }
  const lines = raw.split(/\r?\n/);
  let end = -1;
  for (let i = 1; i < lines.length; i++) {
    if (lines[i] === FENCE) {
      end = i;
      break;
    }
  }
  if (end === -1) return { frontmatter: {}, body: raw };

  const yamlText = lines.slice(1, end).join("\n");
  const body = lines.slice(end + 1).join("\n");
  const parsed = (parseYaml(yamlText) ?? {}) as Frontmatter;
  return { frontmatter: parsed, body };
}

export function joinFrontmatter(frontmatter: Frontmatter, body: string): string {
  const yamlText = stringifyYaml(frontmatter).trimEnd();
  const bodyClean = body.startsWith("\n") ? body.slice(1) : body;
  return `${FENCE}\n${yamlText}\n${FENCE}\n${bodyClean}`;
}
