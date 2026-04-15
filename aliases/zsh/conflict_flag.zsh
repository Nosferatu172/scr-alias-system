#!/usr/bin/env zsh
# Script Name: conflict_flag.zsh
# ID: SCR-ID-20260317130255-FP61J927SX
# Assigned with:
# Created by: Tyler Jensen
# Email: tylerjensen5@yahoo.com
# Alias Call: conflict_flag

emulate -L zsh
setopt pipefail extendedglob

# =========================================================
# conflict_flag
# Scan /c/scr for scripts that may conflict with the
# zsh-resolver execution model.
#
# Resolver model:
#   - resolver may cd into script directory before launch
#   - resolver exports SCR_CALLER_PWD
#   - scripts should not assume pwd == caller dir
#
# What this flags:
#   - plain pwd / $(pwd)
#   - os.getcwd() / Path.cwd()
#   - cd dirname(self) patterns
#   - missing SCR_CALLER_PWD usage
#   - possible relative-path assumptions
#   - likely unquoted globs in shell scripts
#
# Output:
#   - summary by severity
#   - per-file findings
#
# Usage:
#   conflict_flag
#   conflict_flag --root /mnt/c/scr
#   conflict_flag --ext sh,zsh,py,rb
#   conflict_flag --only-high
#   conflict_flag --plain
# =========================================================

TRAPINT() {
  print "\n⛔ Cancelled."
  return 130
}

ROOT="${SCR_ROOT:-/d/scr-pac}"
ONLY_HIGH=0
PLAIN=0
EXT_FILTER=""
SHOW_OK=0

typeset -i TOTAL=0
typeset -i FILES_WITH_ISSUES=0
typeset -i HIGH_COUNT=0
typeset -i MED_COUNT=0
typeset -i LOW_COUNT=0

typeset -a SCAN_EXTS
SCAN_EXTS=(sh zsh bash py rb)

trim() {
  local s="$1"
  s="${s#"${s%%[![:space:]]*}"}"
  s="${s%"${s##*[![:space:]]}"}"
  print -r -- "$s"
}

join_by() {
  local sep="$1"
  shift
  local out=""
  local x
  for x in "$@"; do
    [[ -n "$out" ]] && out+="$sep"
    out+="$x"
  done
  print -r -- "$out"
}

show_help() {
  cat <<'EOF'
Usage:
  conflict_flag [options]

Options:
  --root PATH        Root folder to scan
  --ext LIST         Comma-separated extensions to scan
                     Example: --ext sh,zsh,py,rb
  --only-high        Show only HIGH severity issues
  --plain            Plain output without emoji
  --show-ok          Also show files with no findings
  -h, --help         Show help

Examples:
  conflict_flag
  conflict_flag --root /mnt/c/scr
  conflict_flag --ext sh,zsh,py
  conflict_flag --only-high
EOF
}

while (( $# > 0 )); do
  case "$1" in
    --root)
      shift
      [[ $# -gt 0 ]] || { print "Missing value for --root" >&2; return 2; }
      ROOT="$1"
      ;;
    --ext)
      shift
      [[ $# -gt 0 ]] || { print "Missing value for --ext" >&2; return 2; }
      EXT_FILTER="$1"
      ;;
    --only-high)
      ONLY_HIGH=1
      ;;
    --plain)
      PLAIN=1
      ;;
    --show-ok)
      SHOW_OK=1
      ;;
    -h|--help)
      show_help
      exit 0
      ;;
    *)
      print "Unknown option: $1" >&2
      print "Use -h for help." >&2
      exit 2
      ;;
  esac
  shift
done

if [[ -n "$EXT_FILTER" ]]; then
  SCAN_EXTS=("${(@s:,:)EXT_FILTER}")
fi

[[ -d "$ROOT" ]] || { print "❌ Root not found: $ROOT" >&2; exit 2; }

have_rg=0
command -v rg >/dev/null 2>&1 && have_rg=1

sev_tag() {
  local sev="$1"
  if (( PLAIN )); then
    print -r -- "[$sev]"
    return
  fi
  case "$sev" in
    HIGH) print -r -- "🟥 HIGH" ;;
    MED)  print -r -- "🟨 MED " ;;
    LOW)  print -r -- "🟦 LOW " ;;
    OK)   print -r -- "🟩 OK  " ;;
    *)    print -r -- "[$sev]" ;;
  esac
}

add_count() {
  case "$1" in
    HIGH) ((HIGH_COUNT++)) ;;
    MED)  ((MED_COUNT++)) ;;
    LOW)  ((LOW_COUNT++)) ;;
  esac
}

scan_file() {
  local file="$1"
  local ext="${file:e:l}"
  local content
  local -a findings
  local found_issue=0
  local uses_resolver=0
  local uses_script_dir=0
  local uses_pwd=0
  local uses_getcwd=0
  local uses_pathcwd=0
  local uses_dirname_self=0
  local uses_relative_open=0
  local uses_cd_relative=0
  local uses_unquoted_glob=0

  content="$(<"$file" 2>/dev/null)" || return 0
  ((TOTAL++))

  [[ "$content" == *"SCR_CALLER_PWD"* ]] && uses_resolver=1

  case "$ext" in
    sh|zsh|bash)
      [[ "$content" == *'$PWD'* || "$content" == *'$(pwd)'* || "$content" == *'`pwd`'* ]] && uses_pwd=1
      [[ "$content" == *'dirname "$0"'* || "$content" == *'dirname "${BASH_SOURCE[0]}"'* || "$content" == *'readlink -f "${BASH_SOURCE[0]}"'* ]] && uses_dirname_self=1
      [[ "$content" == *'SCRIPT_DIR'* || "$content" == *'BASH_SOURCE[0]'* ]] && uses_script_dir=1
      [[ "$content" == *'cd "$dir"'* || "$content" == *'cd "$(dirname'* || "$content" == *'cd ${'* ]] && uses_cd_relative=1

      if print -r -- "$content" | grep -Eq 'mput [^"].*\*|rm [^"].*\*|cp [^"].*\*|mv [^"].*\*'; then
        uses_unquoted_glob=1
      fi

      if (( uses_pwd )) && (( ! uses_resolver )); then
        findings+=("HIGH|shell script uses pwd/PWD but does not reference SCR_CALLER_PWD")
      elif (( uses_pwd )) && (( uses_resolver )); then
        findings+=("LOW|shell script uses pwd/PWD; verify it is intentional and not caller-dir sensitive")
      fi

      if (( uses_dirname_self )) && (( ! uses_resolver )); then
        findings+=("MED|shell script derives script directory; may confuse script-dir vs caller-dir logic")
      fi

      if (( uses_cd_relative )) && (( ! uses_resolver )); then
        findings+=("MED|shell script changes directory and does not reference SCR_CALLER_PWD")
      fi

      if (( uses_unquoted_glob )); then
        findings+=("MED|possible unquoted glob command; shell expansion may depend on runtime directory")
      fi
      ;;
    py)
      [[ "$content" == *'os.getcwd()'* ]] && uses_getcwd=1
      [[ "$content" == *'Path.cwd()'* ]] && uses_pathcwd=1
      [[ "$content" == *'__file__'* || "$content" == *'Path(__file__)'* ]] && uses_script_dir=1
      [[ "$content" == *'SCR_CALLER_PWD'* ]] && uses_resolver=1

      if (( uses_getcwd || uses_pathcwd )) && (( ! uses_resolver )); then
        findings+=("HIGH|python script uses cwd but does not reference SCR_CALLER_PWD")
      elif (( uses_getcwd || uses_pathcwd )) && (( uses_resolver )); then
        findings+=("LOW|python script uses cwd; verify fallback/selection logic is correct")
      fi

      if (( uses_script_dir )) && (( ! uses_resolver )) && (( uses_getcwd || uses_pathcwd )); then
        findings+=("MED|python script mixes script-dir and cwd logic without resolver-awareness")
      fi

      if print -r -- "$content" | grep -Eq 'open\(["'\'']\./|Path\(["'\'']\./'; then
        findings+=("MED|python script opens relative paths; runtime cwd may matter")
      fi
      ;;
    rb)
      [[ "$content" == *'Dir.pwd'* ]] && uses_pwd=1
      [[ "$content" == *'__dir__'* || "$content" == *'__FILE__'* ]] && uses_script_dir=1
      [[ "$content" == *'SCR_CALLER_PWD'* ]] && uses_resolver=1

      if (( uses_pwd )) && (( ! uses_resolver )); then
        findings+=("HIGH|ruby script uses Dir.pwd but does not reference SCR_CALLER_PWD")
      elif (( uses_pwd )) && (( uses_resolver )); then
        findings+=("LOW|ruby script uses Dir.pwd; verify it is intentional")
      fi

      if (( uses_script_dir )) && (( ! uses_resolver )) && (( uses_pwd )); then
        findings+=("MED|ruby script mixes script-dir and pwd logic without resolver-awareness")
      fi
      ;;
    *)
      return 0
      ;;
  esac

  if (( ${#findings[@]} == 0 )); then
    if (( SHOW_OK )); then
      print -- "$(sev_tag OK) $file"
    fi
    return 0
  fi

  ((FILES_WITH_ISSUES++))
  print ""
  print -- "$file"

  local entry sev msg
  for entry in "${findings[@]}"; do
    sev="${entry%%|*}"
    msg="${entry#*|}"
    add_count "$sev"
    found_issue=1

    if (( ONLY_HIGH )) && [[ "$sev" != "HIGH" ]]; then
      continue
    fi

    print -- "  $(sev_tag "$sev")  $msg"
  done

  if (( ONLY_HIGH )); then
    local has_high=0
    for entry in "${findings[@]}"; do
      [[ "${entry%%|*}" == "HIGH" ]] && has_high=1 && break
    done
    (( has_high == 0 )) && return 0
  fi
}

typeset -a files
files=()

local_ext_glob=()
for e in "${SCAN_EXTS[@]}"; do
  local_ext_glob+=("*.$e")
done

while IFS= read -r f; do
  files+=("$f")
done < <(
  find "$ROOT" -type f \( \
    -name "*.sh" -o -name "*.zsh" -o -name "*.bash" -o -name "*.py" -o -name "*.rb" \
  \) 2>/dev/null | sort
)

if (( ${#files[@]} == 0 )); then
  print "No matching script files found under: $ROOT"
  exit 0
fi

print "Resolver conflict scan"
print "Root:       $ROOT"
print "Extensions: $(join_by ', ' "${SCAN_EXTS[@]}")"
print ""

for f in "${files[@]}"; do
  case "${f:e:l}" in
    sh|zsh|bash|py|rb)
      scan_file "$f"
      ;;
  esac
done

print ""
print "Summary"
print "-------"
print "Files scanned:      $TOTAL"
print "Files with issues:  $FILES_WITH_ISSUES"
print "HIGH findings:      $HIGH_COUNT"
print "MED findings:       $MED_COUNT"
print "LOW findings:       $LOW_COUNT"
