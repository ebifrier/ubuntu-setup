#
# 各インストールスクリプトから読み込む共通処理。
#
#   SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
#   . "$SCRIPT_DIR/lib/common.sh"
#
# 単体で実行するものではない。
#

BASHRC="${BASHRC:-$HOME/.bashrc}"

# ---------------------------------------------------------------- メッセージ

log() {
    echo "$@"
}

warn() {
    echo "$@" >&2
}

die() {
    echo "$@" >&2
    exit 1
}

# 「次のログインから有効」のような、最後にまとめて見せたい注意書きを溜める。
#
#   note "docker グループの反映は次のログインから。"
#
# setup.sh から呼ばれたときは setup.sh の最後に、
# 個別のスクリプトを直接叩いたときはそのスクリプトの最後にまとめて出る。
note() {
    if ! grep -qxF "$*" "$NOTES_FILE" 2>/dev/null; then
        echo "$*" >> "$NOTES_FILE"
    fi
}

print_notes() {
    [ -s "$NOTES_FILE" ] || return 0
    echo
    echo "=== セットアップ後のメモ ==="
    cat "$NOTES_FILE"
    : > "$NOTES_FILE"
}

# 最初に common.sh を読んだプロセス (通常は setup.sh) が note の置き場を作り、
# 終了時にまとめて出す。子プロセスは NOTES_FILE を引き継いで書き足すだけ。
if [ -z "${NOTES_FILE:-}" ]; then
    NOTES_FILE=$(mktemp)
    export NOTES_FILE
    trap 'print_notes; rm -f "$NOTES_FILE"' EXIT
fi

# ------------------------------------------------------------------ コマンド

# 必要なコマンドが無ければ止める。
require_cmd() {
    for _cmd in "$@"; do
        command -v "$_cmd" >/dev/null 2>&1 ||
            die "$_cmd が無い。先に ./install-packages.sh を実行する。"
    done
}

# apt の索引更新。1プロセスにつき1回だけ走る (force を渡すと必ず走る)。
apt_update() {
    if [ "${1:-}" = force ] || [ -z "${_APT_UPDATED:-}" ]; then
        sudo apt-get update
        _APT_UPDATED=1
    fi
}

# apt でパッケージを入れる。索引更新と noninteractive はここで面倒を見る。
apt_install() {
    [ $# -gt 0 ] || return 0
    apt_update
    sudo DEBIAN_FRONTEND=noninteractive apt-get install -y "$@"
}

# ------------------------------------------------------------------- .bashrc

# ~/.bashrc の管理ブロックを冪等に書く。中身は標準入力から渡す。
#
#   ensure_bashrc_block mise <<'BLOCK'
#   export PATH="$HOME/.local/share/mise/shims:$PATH"
#   BLOCK
#
# マーカー行で囲むので、再実行しても重複せず、内容が変われば差し替わる。
# 中身が同じときは何もしない (ブロックの順序を保つため)。
ensure_bashrc_block() {
    _name=$1
    _begin="# >>> ubuntu-setup: $_name >>>"
    _end="# <<< ubuntu-setup: $_name <<<"

    _new=$(mktemp)
    cat > "$_new"

    # マーカーを使っていなかった頃のブロックが残っていれば消す。
    remove_legacy_bashrc_block "$_name"

    if [ -f "$BASHRC" ] && grep -qF "$_begin" "$BASHRC"; then
        _cur=$(mktemp)
        awk -v b="$_begin" -v e="$_end" '
            index($0, b) == 1 { f = 1; next }
            index($0, e) == 1 { f = 0; next }
            f { print }
        ' "$BASHRC" > "$_cur"

        if cmp -s "$_cur" "$_new"; then
            rm -f "$_cur" "$_new"
            return 0
        fi
        rm -f "$_cur"

        _tmp=$(mktemp)
        awk -v b="$_begin" -v e="$_end" '
            index($0, b) == 1 { skip = 1; next }
            index($0, e) == 1 { skip = 0; next }
            skip { next }
            { print }
        ' "$BASHRC" > "$_tmp"
        cat "$_tmp" > "$BASHRC"
        rm -f "$_tmp"
        _verb="更新した"
    else
        _verb="追記した"
    fi

    _strip_trailing_blank_lines
    {
        printf '\n%s\n' "$_begin"
        cat "$_new"
        printf '%s\n' "$_end"
    } >> "$BASHRC"
    rm -f "$_new"

    log "$BASHRC の $_name ブロックを$_verb。"
}

# 末尾の空行を落とす (ブロックを足すたびに空行が増えないように)。
_strip_trailing_blank_lines() {
    [ -f "$BASHRC" ] || return 0
    _tmp=$(mktemp)
    awk '
        { line[NR] = $0; if ($0 ~ /[^[:space:]]/) last = NR }
        END { for (i = 1; i <= last; i++) print line[i] }
    ' "$BASHRC" > "$_tmp"
    cat "$_tmp" > "$BASHRC"
    rm -f "$_tmp"
}

# ~/.bashrc の管理ブロックを消す。
remove_bashrc_block() {
    _name=$1
    _begin="# >>> ubuntu-setup: $_name >>>"
    _end="# <<< ubuntu-setup: $_name <<<"

    [ -f "$BASHRC" ] || return 0
    grep -qF "$_begin" "$BASHRC" || return 0

    _tmp=$(mktemp)
    awk -v b="$_begin" -v e="$_end" '
        index($0, b) == 1 { skip = 1; next }
        index($0, e) == 1 { skip = 0; next }
        skip { next }
        { print }
    ' "$BASHRC" > "$_tmp"
    cat "$_tmp" > "$BASHRC"
    rm -f "$_tmp"

    log "$BASHRC の $_name ブロックを削除した。"
}

# 旧形式 (`# ubuntu-setup: <name>` から次の空行まで) のブロックを消す。
# 昔のスクリプトで追記したものを片付けるための移行用。
remove_legacy_bashrc_block() {
    _name=$1
    _marker="# ubuntu-setup: $_name"

    [ -f "$BASHRC" ] || return 0
    grep -qxF "$_marker" "$BASHRC" || return 0

    _tmp=$(mktemp)
    awk -v m="$_marker" '
        $0 == m { skip = 1; next }
        skip && $0 ~ /^[[:space:]]*$/ { skip = 0; next }
        skip { next }
        { print }
    ' "$BASHRC" > "$_tmp"
    cat "$_tmp" > "$BASHRC"
    rm -f "$_tmp"

    log "$BASHRC の旧 $_name ブロックを削除した。"
}

# ~/.local/bin を PATH に通す。claude / mise の両方が使う。
ensure_local_bin() {
    remove_legacy_bashrc_block claude
    ensure_bashrc_block local-bin <<'BLOCK'
case ":$PATH:" in
    *":$HOME/.local/bin:"*) ;;
    *) PATH="$HOME/.local/bin:$PATH" ;;
esac
export PATH
BLOCK
}
