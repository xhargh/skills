#!/usr/bin/env bash
set -euo pipefail

ROOT="${1:-.}"

if [[ ! -d "$ROOT" ]]; then
  echo "repo-docs: root does not exist: $ROOT" >&2
  exit 2
fi

if [[ "${JAVA_TOOL_OPTIONS:-}" != *"-Djava.awt.headless="* ]]; then
  export JAVA_TOOL_OPTIONS="${JAVA_TOOL_OPTIONS:+$JAVA_TOOL_OPTIONS }-Djava.awt.headless=true"
fi

declare -a renderer=()

if command -v plantuml >/dev/null 2>&1; then
  renderer=(plantuml -tpng)
elif [[ -n "${PLANTUML_JAR:-}" ]]; then
  renderer=(java -jar "$PLANTUML_JAR" -tpng)
else
  echo "repo-docs: PlantUML PNGs not rendered: CLI unavailable" >&2
  exit 4
fi

declare -a search_dirs=()

for dir in "$ROOT/doc" "$ROOT/docs" "$ROOT/res" "$ROOT/resources"; do
  if [[ -d "$dir" ]]; then
    search_dirs+=("$dir")
  fi
done

if (( ${#search_dirs[@]} == 0 )); then
  echo "repo-docs: no documentation resource directories found"
  exit 0
fi

declare -a plantuml_files=()
declare -A seen=()

for dir in "${search_dirs[@]}"; do
  while IFS= read -r -d '' file; do
    if [[ -z "${seen[$file]:-}" ]]; then
      plantuml_files+=("$file")
      seen["$file"]=1
    fi
  done < <(find "$dir" -type f \( -name '*.puml' -o -name '*.plantuml' \) -print0)
done

if (( ${#plantuml_files[@]} == 0 )); then
  echo "repo-docs: no standalone PlantUML files found"
  exit 0
fi

echo "repo-docs: rendering ${#plantuml_files[@]} PlantUML diagram(s) to PNG"
"${renderer[@]}" "${plantuml_files[@]}"
echo "repo-docs: PlantUML PNGs rendered"
