#!/usr/bin/env bash
# Print the paths listed in .standards-exclude, one per line, for CI and pre-commit callers.
#
# .standards-exclude lists files that must stay byte-for-byte unchanged, for example inputs to a
# build or image fingerprint. They are skipped by formatters and linters. Every entry needs a reason:
#
#   runtime/Dockerfile   # frozen: the runtime image ID is part of the checkpoint fingerprint
#
# Usage: list-standards-excludes.sh [--pathspec | --csv | --regex] [file]
#   (default)   plain paths or globs, one per line
#   --pathspec  git exclude pathspecs (":!:path"), one per line
#   --csv       comma-separated list (for ruff --extend-exclude)
#   --regex     one alternation regex (for pre-commit "exclude:"), or nothing if empty
set -Eeuo pipefail

die() {
  printf 'list-standards-excludes: error: %s\n' "$*" >&2
  exit 1
}

main() {
  local mode="plain" file=".standards-exclude"
  case "${1:-}" in
    --pathspec | --csv | --regex)
      mode="${1#--}"
      shift
      ;;
    -*) die "unknown option: $1" ;;
    *) ;;
  esac
  file="${1:-${file}}"
  [[ -f "${file}" ]] || return 0

  local line path reason paths=() line_no=0
  while IFS= read -r line || [[ -n "${line}" ]]; do
    line_no=$((line_no + 1))
    [[ "${line}" =~ ^[[:space:]]*(#|$) ]] && continue
    [[ "${line}" == *"#"* ]] || die "${file}:${line_no}: entry has no '# reason' comment"
    path="${line%%#*}"
    reason="${line#*#}"
    path="${path%"${path##*[![:space:]]}"}"
    path="${path#"${path%%[![:space:]]*}"}"
    [[ -n "${path}" ]] || die "${file}:${line_no}: empty path"
    [[ "${reason}" =~ [^[:space:]] ]] || die "${file}:${line_no}: reason is empty"
    paths+=("${path}")
  done <"${file}"

  ((${#paths[@]} > 0)) || return 0
  case "${mode}" in
    plain) printf '%s\n' "${paths[@]}" ;;
    pathspec) printf ':!:%s\n' "${paths[@]}" ;;
    csv)
      local IFS=,
      printf '%s\n' "${paths[*]}"
      ;;
    regex)
      local escaped=() p
      for p in "${paths[@]}"; do
        p="$(printf '%s' "${p}" | sed -e 's/[][\.^$+(){}|]/\\&/g' -e 's/\*\*/.*/g' -e 's/\([^.]\)\*/\1[^\/]*/g' -e 's/^\*/[^\/]*/')"
        escaped+=("${p}")
      done
      local IFS='|'
      printf '^(%s)$\n' "${escaped[*]}"
      ;;
    *) die "unreachable mode ${mode}" ;;
  esac
}

main "$@"
