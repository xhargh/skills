#!/usr/bin/env bash
set -euo pipefail

ROOT="${1:-.}"

if [[ ! -d "$ROOT" ]]; then
  echo "repo-docs: root does not exist: $ROOT" >&2
  exit 2
fi

tmpdir="$(mktemp -d "${TMPDIR:-/tmp}/repo-docs-plantuml.XXXXXX")"
cleanup() {
  rm -rf "$tmpdir"
}
trap cleanup EXIT

declare -a markdown_files=()
declare -a search_dirs=()

if [[ -f "$ROOT/README.md" ]]; then
  markdown_files+=("$ROOT/README.md")
fi

if [[ -d "$ROOT/doc" ]]; then
  search_dirs+=("$ROOT/doc")
  while IFS= read -r -d '' file; do
    markdown_files+=("$file")
  done < <(find "$ROOT/doc" -type f -name '*.md' -print0)
fi

if [[ -d "$ROOT/docs" ]]; then
  search_dirs+=("$ROOT/docs")
  while IFS= read -r -d '' file; do
    markdown_files+=("$file")
  done < <(find "$ROOT/docs" -type f -name '*.md' -print0)
fi

if [[ -d "$ROOT/res" ]]; then
  search_dirs+=("$ROOT/res")
fi

if [[ -d "$ROOT/resources" ]]; then
  search_dirs+=("$ROOT/resources")
fi

mapping="$tmpdir/mapping.tsv"
: > "$mapping"

inline_count=0

for file in "${markdown_files[@]}"; do
  awk -v outdir="$tmpdir" -v source="$file" -v mapping="$mapping" '
    function sanitize(value) {
      gsub(/[^A-Za-z0-9_.-]/, "_", value)
      return value
    }

    !in_block && $0 ~ /^```[ \t]*plantuml[ \t]*$/ {
      in_block = 1
      start_line = NR
      block_count += 1
      output = outdir "/" sanitize(source) "__line_" start_line "__block_" block_count ".puml"
      print "'\'' source: " source ":" start_line > output
      print output "\t" source ":" start_line >> mapping
      next
    }

    in_block && $0 ~ /^```[ \t]*$/ {
      close(output)
      in_block = 0
      next
    }

    in_block {
      print $0 >> output
    }

    END {
      if (in_block) {
        print "repo-docs: unclosed plantuml fence in " source ":" start_line > "/dev/stderr"
        exit 3
      }
    }
  ' "$file"
done

declare -a puml_files=()
while IFS= read -r -d '' file; do
  puml_files+=("$file")
done < <(find "$tmpdir" -type f -name '*.puml' -print0)

inline_count=${#puml_files[@]}

declare -a standalone_files=()
declare -a png_files=()
declare -A seen_standalone=()
for dir in "${search_dirs[@]}"; do
  while IFS= read -r -d '' file; do
    if [[ -z "${seen_standalone[$file]:-}" ]]; then
      standalone_files+=("$file")
      seen_standalone["$file"]=1
    fi
  done < <(find "$dir" -type f \( -name '*.puml' -o -name '*.plantuml' \) -print0)
  while IFS= read -r -d '' file; do
    png_files+=("$file")
  done < <(find "$dir" -type f -name '*.png' -print0)
done

if (( ${#standalone_files[@]} > 0 && ${#png_files[@]} > 0 && inline_count > 0 )); then
  echo "repo-docs: inline PlantUML is not allowed because this repo already uses standalone PlantUML files with generated PNGs" >&2
  echo "repo-docs: convert inline plantuml fences to standalone .puml/.plantuml sources and link generated PNGs from Markdown" >&2
  sed 's/^/  /' "$mapping" >&2
  exit 5
fi

for file in "${standalone_files[@]}"; do
  puml_files+=("$file")
  printf '%s\t%s\n' "$file" "$file" >> "$mapping"
done

if (( ${#puml_files[@]} == 0 )); then
  echo "repo-docs: no PlantUML diagrams found"
  exit 0
fi

echo "repo-docs: checking ${#puml_files[@]} PlantUML diagram(s)"
echo "repo-docs: source map:"
sed 's/^/  /' "$mapping"

if [[ "${JAVA_TOOL_OPTIONS:-}" != *"-Djava.awt.headless="* ]]; then
  export JAVA_TOOL_OPTIONS="${JAVA_TOOL_OPTIONS:+$JAVA_TOOL_OPTIONS }-Djava.awt.headless=true"
fi

declare -a checker=()

if command -v plantuml >/dev/null 2>&1; then
  if plantuml --help 2>&1 | grep -q -- '--check-syntax'; then
    checker=(plantuml --check-syntax --stop-on-error)
  else
    checker=(plantuml -checkonly -failfast2)
  fi
elif [[ -n "${PLANTUML_JAR:-}" ]]; then
  checker=(java -jar "$PLANTUML_JAR" --check-syntax --stop-on-error)
else
  echo "repo-docs: PlantUML syntax not verified: CLI unavailable" >&2
  exit 4
fi

declare -A source_by_puml=()
while IFS=$'\t' read -r puml source_location; do
  source_by_puml["$puml"]="$source_location"
done < "$mapping"

status=0
for file in "${puml_files[@]}"; do
  if ! "${checker[@]}" "$file"; then
    echo "repo-docs: PlantUML syntax error in ${source_by_puml[$file]}" >&2
    status=1
  fi
done

if (( status != 0 )); then
  exit "$status"
fi

echo "repo-docs: PlantUML syntax verified"
