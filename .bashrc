# ~/.bashrc — Git Bash (MSYS2/MINGW) startup

# 緑: "Git Bash on " / マゼンタ: $MSYSTEM (例: MINGW64)
greet_git_bash() {
  printf '\033[32mGit Bash on \033[35m%s\033[0m\n' "$MSYSTEM"
}


clear() {
  command clear
  greet_git_bash
}

# 起動時に fastfetch を実行
if [ -z "$FASTFETCH_RAN" ] && command -v fastfetch >/dev/null 2>&1; then
  greet_git_bash
  export FASTFETCH_RAN=1
  LC_ALL=C fastfetch -c ~/.config/fastfetch/config.jsonc
fi

# gcc 切り替え用エイリアス
alias Wgcc='/c/w64devkit/bin/gcc.exe'
alias Cgcc='/c/cygwin/bin/gcc.exe'
alias Mgcc='/c/MinGW/bin/gcc.exe'

# プロンプトにブランチ名を表示し、未コミットの変更があれば * を付ける。
_git_prompt_suffix() {
    local git_status line branch='' commit='' marker=''
    git_status=$(command git --no-optional-locks status --porcelain=v2 --branch \
        --untracked-files=normal 2>/dev/null) || return 0

    while IFS= read -r line; do
        case $line in
            '# branch.head '*) branch=${line#'# branch.head '} ;;
            '# branch.oid '*) commit=${line#'# branch.oid '} ;;
            '1 '*|'2 '*|'u '*|'? '*) marker='*' ;;
        esac
    done <<< "$git_status"

    [[ -n $branch ]] || return 0
    [[ $branch != '(detached)' ]] || branch=${commit:0:7}
    printf ' (%s%s)' "$branch" "$marker"
}

PS1='\[\033[32m\]$(builtin pwd -W)$(_git_prompt_suffix) > \[\033[0m\]'

# ls: PowerShell と同様に Windows の Hidden / System 属性ファイルを既定で隠す
# -a / -A を付けたときは ls 本来の挙動どおり全て表示される
unalias ls 2>/dev/null
ls() {
  local -a paths=()
  local arg
  for arg in "$@"; do
    [[ "$arg" != -* ]] && paths+=("$arg")
  done
  [ ${#paths[@]} -eq 0 ] && paths=(".")

  local -a hides=()
  local -A seen=()
  local p line
  for p in "${paths[@]}"; do
    [ -d "$p" ] || continue
    while IFS= read -r line; do
      line="${line%$'\r'}"
      [ -z "$line" ] && continue
      if [ -z "${seen[$line]}" ]; then
        hides+=("--hide=$line")
        seen[$line]=1
      fi
    done < <(cd "$p" 2>/dev/null && MSYS_NO_PATHCONV=1 cmd /c "chcp 65001 >nul 2>&1 & dir /a:h /b & dir /a:s /b" 2>/dev/null)
  done

  command ls --color=auto "${hides[@]}" "$@"
}

open() {
  local target="${1:-.}"
  # ローカルに存在するパスは Windows 形式に変換（cmd が解釈できるように）
  if [ -e "$target" ]; then
    target=$(cygpath -w "$target")
  fi
  MSYS_NO_PATHCONV=1 cmd /c start "" "$target"
}

hisclear(){
    command clear
    command history -c
    unset FASTFETCH_RAN
    if [ -z "$FASTFETCH_RAN" ] && command -v fastfetch >/dev/null 2>&1; then
        greet_git_bash
        export FASTFETCH_RAN=1
        LC_ALL=C fastfetch -c ~/.config/fastfetch/config.jsonc
    fi
}

pwd(){
    command pwd -LPW
}

# Node.js (winget OpenJS.NodeJS.LTS) + npm global packages (pnpm, etc.)
# 既に PATH にあれば追加しない (idempotent)
_adddev_path_prepend() {
  case ":$PATH:" in
    *":$1:"*) ;;
    *) PATH="$1:$PATH" ;;
  esac
}
_adddev_path_prepend "/c/Users/hiraken0427/AppData/Roaming/npm"
_adddev_path_prepend "/c/Program Files/nodejs"
export PATH
unset -f _adddev_path_prepend

# コマンド入力中に \ を押すと / を挿入する。
if [[ $- == *i* ]]; then
    bind '"\\":"/"'
fi

exist() {
    if [[ $# -lt 1 || $# -gt 2 || -z $1 || $1 == -* ||
          ( $# -eq 2 && $2 != -v && $2 != --verbose ) ]]; then
        printf '%s\n' 'Usage: exist <path> [-v|--verbose]' \
            'Show the Windows path and whether it exists as a file or directory.'
        return 1
    fi

    local path=${1//\\//}
    local windows_path

    if ! windows_path=$(cygpath -aw -- "$path" 2>/dev/null); then
        windows_path=${path//\//\\}
    fi

    if [[ -d $path ]]; then
        printf 'Yes, "%s" exists as a directory.\n' "$windows_path"
    elif [[ -f $path ]]; then
        printf 'Yes, "%s" exists as a file.\n' "$windows_path"
    elif [[ -e $path ]]; then
        printf 'Yes, "%s" exists.\n' "$windows_path"
    else
        printf 'No, "%s" does not exist.\n' "$windows_path"
    fi
}

cpwd() {
    if [[ $# -gt 1 || ( $# -eq 1 && ( -z $1 || $1 == -* ) ) ]]; then
        printf '%s\n' 'Usage: cpwd [path]' >&2
        return 1
    fi

    local path=${1-.}
    local windows_path
    path=${path//\\//}
    if [[ ! -e $path ]]; then
        printf 'cpwd: "%s" does not exist.\n' "$path" >&2
        return 1
    fi

    windows_path=$(cygpath -aw -- "$path") || return
    CPWD_WINDOWS_PATH=$windows_path powershell.exe -NoLogo -NoProfile -NonInteractive \
        -Command 'Set-Clipboard -Value $env:CPWD_WINDOWS_PATH -ErrorAction Stop' || return
    printf '%s\n' "$windows_path"
}

_uvenv_find_global_python_dir() {
    local python_path python_dir
    python_path=$(command uv python find --system --no-project --no-python-downloads -- "$1") || return
    python_path=$(cygpath -u -- "${python_path%$'\r'}") || return
    python_dir=${python_path%/*}
    if [[ ! -x $python_dir/python.exe ]]; then
        printf 'uvenv: "%s" has no python.exe to put on PATH.\n' "$1" >&2
        return 1
    fi
    printf '%s\n' "$python_dir"
}

# 切り替え時に前の追加分を取り除き、仮想環境の Python を優先する。
_uvenv_apply_global_python_path() {
    local python_dir=$1 previous_dir=${_UVENV_GLOBAL_PYTHON_DIR-}
    local venv_bin='' path_name path_value
    if [[ -n ${VIRTUAL_ENV-} ]] && venv_bin=$(cygpath -u -- "$VIRTUAL_ENV" 2>/dev/null); then
        venv_bin=${venv_bin%/}/Scripts
    fi

    # deactivate 後も新しい既定値になるよう、退避された PATH にも適用する。
    for path_name in PATH _OLD_VIRTUAL_PATH; do
        [[ -v $path_name ]] || continue
        path_value=:${!path_name}:
        if [[ -n $previous_dir ]]; then
            path_value=${path_value/":$previous_dir:"/:}
        fi
        if [[ -n $python_dir ]]; then
            if [[ $path_name == PATH && -n $venv_bin && $path_value == *":$venv_bin:"* ]]; then
                path_value=${path_value/":$venv_bin:"/":$venv_bin:$python_dir:"}
            else
                path_value=:$python_dir$path_value
            fi
        fi
        path_value=${path_value#:}
        printf -v "$path_name" '%s' "${path_value%:}"
    done
    export PATH _UVENV_GLOBAL_PYTHON_DIR=$python_dir
    hash -r
}

_uvenv_sync_global_python_path() {
    local request python_dir=''
    if request=$(command uv python pin --global 2>/dev/null) && [[ -n $request ]]; then
        python_dir=$(_uvenv_find_global_python_dir "${request%$'\r'}") || return
    fi
    _uvenv_apply_global_python_path "$python_dir"
}

# pyenv に近いコマンドで uv の Python 管理を呼び出す。
uvenv() {
    local subcommand=${1:-help}
    if (($#)); then shift; fi

    case $subcommand in
        help|-h|--help)
            printf '%s\n' \
                'Usage: uvenv <command> [args]' \
                '' \
                '  install --list [VERSION]  ダウンロードできる Python を一覧表示 (-l も可)' \
                '  install VERSION          指定した Python をインストール' \
                '  uninstall VERSION        指定した Python をアンインストール' \
                '  versions [VERSION]       インストール済みの Python を一覧表示' \
                '  version                  uv が選ぶ Python のバージョンを表示' \
                '  local [VERSION]          このフォルダの Python バージョンを表示・設定' \
                '  global [VERSION]         uv と Git Bash の既定 Python を表示・設定' \
                '  which python             uv が選ぶ Python の実行ファイルを表示' \
                '  exec COMMAND [ARGS...]   uv の環境でコマンドを実行' \
                '  --version                uv 本体のバージョンを表示'
            ;;
        --version) command uv --version "$@" ;;
        install)
            case ${1-} in
                --list|-l)
                    shift
                    command uv python list --only-downloads --all-versions "$@"
                    ;;
                '')
                    printf '%s\n' 'Usage: uvenv install VERSION | uvenv install --list [VERSION]' >&2
                    return 1
                    ;;
                *) command uv python install "$@" ;;
            esac
            ;;
        uninstall) command uv python uninstall "$@" ;;
        versions) command uv python list --only-installed "$@" ;;
        local) command uv python pin "$@" ;;
        global)
            if [[ $# -eq 1 && $1 != -* ]]; then
                local python_dir
                python_dir=$(_uvenv_find_global_python_dir "$1") || return
                command uv python pin --global "$1" || return
                _uvenv_apply_global_python_path "$python_dir"
            else
                command uv python pin --global "$@" || return
                if (($#)); then _uvenv_sync_global_python_path; fi
            fi
            ;;
        version)
            if (($#)); then
                printf '%s\n' 'Usage: uvenv version' >&2
                return 1
            fi
            local python_path
            python_path=$(command uv python find --no-python-downloads) || return
            python_path=$(cygpath -u -- "${python_path%$'\r'}") || return
            "$python_path" --version
            ;;
        which)
            if [[ $# -ne 1 || $1 != python ]]; then
                printf '%s\n' 'Usage: uvenv which python' >&2
                return 1
            fi
            command uv python find --no-python-downloads
            ;;
        exec)
            if (($# == 0)); then
                printf '%s\n' 'Usage: uvenv exec COMMAND [ARGS...]' >&2
                return 1
            fi
            command uv run "$@"
            ;;
        *)
            printf 'uvenv: unknown command "%s". Run "uvenv --help".\n' "$subcommand" >&2
            return 1
            ;;
    esac
}

if command -v uv >/dev/null 2>&1; then
    _uvenv_sync_global_python_path 2>/dev/null || :
fi

if [[ $- == *i* ]] && command -v zoxide >/dev/null 2>&1; then
    if _zoxide_init=$(zoxide init bash); then
        # Windows 版 0.10.0 が生成する cygpath 呼び出しにコマンド置換を補う。
        _zoxide_init=${_zoxide_init/'cygpath -w "\builtin pwd -L"'/'cygpath -w "$(\builtin pwd -L)"'}
        _zoxide_init=${_zoxide_init/'cygpath -w "\builtin pwd -P"'/'cygpath -w "$(\builtin pwd -P)"'}
        eval "$_zoxide_init"
    fi
    unset _zoxide_init
fi
