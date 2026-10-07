#!/usr/bin/env bash
# Reader and validator for the constrained Markdown in copy/screens/.
#
# Deliberately dependency-free: the opening question has to explain that node is missing,
# so reading its words cannot itself require node. The format is Markdown for the person
# editing it, but only four level-two sections and Label/Description under stable option
# ids are structural. Everything else is prose.

SCREEN_COPY_ROOT="${SCREEN_COPY_ROOT:-${TOOL_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}/copy/screens}"

screen_copy_file() { printf '%s/%s.md' "$SCREEN_COPY_ROOT" "$1"; }

# screen_copy_validate <screen> <required-option-ids> <allowed-placeholders>
#
# Errors name the file and line a writer should fix. Option ids are behavior keys: their
# labels and order may change, but deleting or renaming an id would otherwise detach the
# words from the command it is meant to describe.
screen_copy_validate() {
  local screen="$1" expected="${2:-}" placeholders="${3:-}" file
  file="$(screen_copy_file "$screen")"
  [[ -f "$file" ]] || { printf '%s: missing screen copy\n' "$file" >&2; return 1; }

  awk -v file="$file" -v expected="$expected" -v allowed="$placeholders" '
    function error(line, message) {
      printf "%s:%s: %s\n", file, line, message > "/dev/stderr"
      failed = 1
    }
    function known_option(id,    i) {
      for (i in wanted) if (i == id) return 1
      return 0
    }
    BEGIN {
      split(expected, a, " "); for (i in a) if (a[i] != "") wanted[a[i]] = 1
      split(allowed, a, " "); for (i in a) if (a[i] != "") allowed_placeholder[a[i]] = 1
      required["Header"] = required["Prompt"] = required["Context"] = required["Requirements"] = 1
    }
    {
      text = $0
      rest = text
      while (match(rest, /\{\{[^{}]+\}\}/)) {
        token = substr(rest, RSTART + 2, RLENGTH - 4)
        if (!(token in allowed_placeholder)) error(NR, "unknown placeholder {{" token "}}")
        rest = substr(rest, RSTART + RLENGTH)
      }

      if (text ~ /^# /) {
        h1++
        if (h1 > 1) error(NR, "only one screen title is allowed")
        next
      }
      if (text ~ /^## /) {
        section = substr(text, 4)
        option = field = ""
        if (section in required) {
          seen_section[section]++
          current = section
          if (seen_section[section] > 1) error(NR, "duplicate \"" section "\" section")
        } else if (section ~ /^Option: /) {
          option = substr(section, 9)
          current = ""
          if (option !~ /^[a-z][a-z0-9_-]*$/) error(NR, "invalid option id \"" option "\"")
          else if (!known_option(option)) error(NR, "unknown option id \"" option "\"")
          seen_option[option]++
          if (seen_option[option] > 1) error(NR, "duplicate option \"" option "\"")
        } else {
          error(NR, "unknown section \"" section "\"")
          current = ""
        }
        next
      }
      if (text ~ /^### /) {
        field = substr(text, 5)
        if (option == "") {
          error(NR, "\"" field "\" belongs under an Option section")
        } else if (field != "Label" && field != "Description") {
          error(NR, "unknown option field \"" field "\"")
        } else {
          seen_field[option, field]++
          if (seen_field[option, field] > 1)
            error(NR, "duplicate \"" field "\" for option \"" option "\"")
        }
        next
      }
      if (text !~ /^[[:space:]]*$/) {
        if (option != "" && field != "") content_field[option, field]++
        else if (current != "") content_section[current]++
        else error(NR, "text is outside a recognised section")
      }
    }
    END {
      if (h1 == 0) error(1, "missing screen title (# ...)")
      for (s in required) {
        if (seen_section[s] != 1) error(1, "missing \"" s "\" section")
        else if (content_section[s] == 0) error(1, "\"" s "\" section is empty")
      }
      for (id in wanted) {
        if (seen_option[id] != 1) {
          error(1, "missing option \"" id "\"")
          continue
        }
        for (i = 1; i <= 2; i++) {
          f = i == 1 ? "Label" : "Description"
          if (seen_field[id, f] != 1) error(1, "option \"" id "\" is missing \"" f "\"")
          else if (content_field[id, f] == 0) error(1, "\"" f "\" for option \"" id "\" is empty")
        }
      }
      exit failed ? 1 : 0
    }
  ' "$file"
}

# Raw Markdown between one `## Name` heading and the next level-two heading.
screen_copy_section_raw() {
  local screen="$1" section="$2" file
  file="$(screen_copy_file "$screen")"
  awk -v target="## $section" '
    $0 == target { active = 1; next }
    active && /^## / { exit }
    active { print }
  ' "$file"
}

# Raw Markdown under `### Field` in one stable `## Option: id`.
screen_copy_option_raw() {
  local screen="$1" option="$2" field="$3" file
  file="$(screen_copy_file "$screen")"
  awk -v wanted_option="## Option: $option" -v wanted_field="### $field" '
    $0 == wanted_option { in_option = 1; next }
    in_option && /^## / { exit }
    in_option && $0 == wanted_field { active = 1; next }
    active && /^### / { exit }
    active { print }
  ' "$file"
}

# Markdown paragraph rules: physical line wrapping is ignored, while a blank line remains
# a paragraph break. This lets a writer wrap prose in their editor without changing what
# either front end receives.
screen_copy_paragraphs() {
  awk '
    function flush() {
      if (paragraph != "") {
        if (pending && wrote) print ""
        print paragraph
        paragraph = ""
        pending = 0
        wrote = 1
      }
    }
    /^[[:space:]]*$/ { flush(); if (wrote) pending = 1; next }
    /^[[:space:]]*\{\{[^{}]+\}\}[[:space:]]*$/ {
      flush()
      if (pending && wrote) print ""
      gsub(/^[[:space:]]+|[[:space:]]+$/, "")
      print
      pending = 0
      wrote = 1
      next
    }
    {
      line = $0
      sub(/^[[:space:]]+/, "", line)
      sub(/[[:space:]]+$/, "", line)
      paragraph = paragraph == "" ? line : paragraph " " line
    }
    END { flush() }
  '
}

screen_copy_section() {
  screen_copy_section_raw "$1" "$2" | screen_copy_paragraphs
}

screen_copy_scalar() {
  screen_copy_section "$1" "$2" | awk '
    NF { value = value == "" ? $0 : value " " $0 }
    END { printf "%s", value }
  '
}

screen_copy_option_scalar() {
  screen_copy_option_raw "$1" "$2" "$3" | screen_copy_paragraphs | awk '
    NF { value = value == "" ? $0 : value " " $0 }
    END { printf "%s", value }
  '
}

screen_copy_option_ids() {
  local file; file="$(screen_copy_file "$1")"
  sed -n 's/^## Option: \([a-z][a-z0-9_-]*\)$/\1/p' "$file"
}
