#!/bin/sh
#
# WSL2 の Ubuntu 向けの設定。
#
#   ./install-wsl.sh                    # Windows ユーザー名は自動で拾う
#   ./install-wsl.sh <Windowsユーザー>  # 拾えないときは手で渡す
#
# やること:
#
#   1. /etc/wsl.conf に automount / interop の無効化を書く
#      (Windows 側のドライブと PATH を Linux に持ち込まない)
#   2. VS Code の WSL 拡張だけは Windows 側の拡張ディレクトリを読むので、
#      そこだけ /etc/fstab で read-only マウントして通す
#
# wsl.conf は丸ごと上書きせず、上の4つのキーだけを書き換える
# (Ubuntu 既定の [boot] systemd=true などを消さないため)。
#
# WSL でなければ何もせずに終わるので、setup.sh の all に入れっぱなしでよい。
#
set -e

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
. "$SCRIPT_DIR/lib/common.sh"

WSL_CONF=/etc/wsl.conf
FSTAB=/etc/fstab

# wsl.conf に入れる値。"セクション:キー:値" を ; で並べる。
WSL_CONF_SPEC='automount:enabled:false;automount:mountFsTab:true;interop:enabled:false;interop:appendWindowsPath:false'

# ------------------------------------------------------------------ 関数

is_wsl() {
    [ -n "${WSL_DISTRO_NAME:-}" ] && return 0
    grep -qi microsoft /proc/sys/kernel/osrelease 2>/dev/null
}

# /proc/mounts に載っているか (mountpoint コマンドに依存しない)。
is_mounted() {
    awk -v p="$1" '$2 == p { found = 1 } END { exit !found }' /proc/mounts
}

# Windows のユーザー名。interop が生きていれば cmd.exe に聞く。
win_user_from_interop() {
    command -v cmd.exe >/dev/null 2>&1 || return 0
    (
        cd /mnt/c 2>/dev/null || cd /
        cmd.exe /c 'echo %USERNAME%' 2>/dev/null
    ) | tr -d '\r' | head -n 1
}

# interop を切ったあと用。.vscode/extensions を持つユーザーが1人なら、それ。
win_user_from_users_dir() {
    [ -d /mnt/c/Users ] || return 0
    _found=
    for _dir in /mnt/c/Users/*/; do
        [ -d "$_dir.vscode/extensions" ] || continue
        _name=$(basename "$_dir")
        case "$_name" in Public|Default|"Default User"|"All Users") continue ;; esac
        [ -z "$_found" ] || return 0   # 複数いるなら決められない
        _found=$_name
    done
    echo "$_found"
}

# 標準入力の中身をファイルに置く。変わったときだけ書いて 0 を返す
# (変化なしなら 1)。既存ファイルは初回だけ .bak に退避する。
install_file() {
    _path=$1
    _new=$(mktemp)
    cat > "$_new"

    if [ -f "$_path" ] && cmp -s "$_new" "$_path"; then
        rm -f "$_new"
        return 1
    fi
    if [ -f "$_path" ] && [ ! -f "$_path.bak" ]; then
        sudo cp -p "$_path" "$_path.bak"
        log "$_path を $_path.bak に退避した。"
    fi

    sudo tee "$_path" < "$_new" >/dev/null
    rm -f "$_new"
    return 0
}

# wsl.conf の指定キーだけを差し替えた中身を出す。無いセクションは末尾に足す。
render_wsl_conf() {
    _src=$WSL_CONF
    [ -f "$_src" ] || _src=/dev/null

    awk -v SPEC="$WSL_CONF_SPEC" '
        BEGIN {
            n = split(SPEC, item, ";")
            for (i = 1; i <= n; i++) {
                split(item[i], p, ":")
                sec[i] = p[1]; key[i] = p[2]; val[i] = p[3]
            }
        }
        # セクションに足りないキーを補う。
        function flush(s,   i) {
            for (i = 1; i <= n; i++)
                if (sec[i] == s && !done[i]) { print key[i] " = " val[i]; done[i] = 1 }
        }
        # 空行は溜めておく。セクション末尾に足すキーが空行の後ろに回らないように。
        function emit_pending() {
            if (pend != "") { printf "%s", pend; pend = "" }
        }
        /^[ \t]*$/ { pend = pend $0 "\n"; next }
        /^[ \t]*\[/ {
            flush(cur)
            emit_pending()
            cur = $0
            sub(/^[ \t]*\[[ \t]*/, "", cur)
            sub(/[ \t]*\].*$/, "", cur)
            print
            next
        }
        {
            emit_pending()
            if (match($0, /^[ \t]*[A-Za-z0-9_]+[ \t]*=/)) {
                k = $0
                sub(/[ \t]*=.*$/, "", k)
                sub(/^[ \t]*/, "", k)
                for (i = 1; i <= n; i++) {
                    if (sec[i] != cur || key[i] != k) continue
                    if (!done[i]) { print key[i] " = " val[i]; done[i] = 1 }
                    next
                }
            }
            print
        }
        END {
            flush(cur)                 # 末尾の空行はここで捨てる
            blank = (NR > 0)
            for (i = 1; i <= n; i++) {
                if (done[i]) continue
                if (blank) print ""
                print "[" sec[i] "]"
                for (j = i; j <= n; j++)
                    if (sec[j] == sec[i] && !done[j]) { print key[j] " = " val[j]; done[j] = 1 }
                blank = 1
            }
        }
    ' "$_src"
}

# fstab の管理ブロックを差し替えた中身を出す。中身は標準入力から渡す。
render_fstab() {
    _begin="# >>> ubuntu-setup: $1 >>>"
    _end="# <<< ubuntu-setup: $1 <<<"
    _body=$(mktemp)
    cat > "$_body"

    if [ -f "$FSTAB" ]; then
        awk -v b="$_begin" -v e="$_end" '
            index($0, b) == 1 { skip = 1; next }
            index($0, e) == 1 { skip = 0; next }
            skip { next }
            { print }
        ' "$FSTAB"
    fi
    printf '%s\n' "$_begin"
    cat "$_body"
    printf '%s\n' "$_end"
    rm -f "$_body"
}

# fstab はフィールドを空白で区切るので、パスの空白は \040 に逃がす。
fstab_escape() {
    printf '%s' "$1" | sed 's/ /\\040/g'
}

# マウント先のディレクトリを Linux 側に作る。
#
# automount がまだ生きていると /mnt/c には drvfs が被っていて、その下に
# mkdir しても Windows 側に作られるだけで、automount を切ったあとの
# マウント先にはならない。再帰しない bind mount で下地の /mnt を覗いて作る。
ensure_mount_point() {
    if ! is_mounted /mnt/c; then
        sudo mkdir -p "$MOUNT_POINT"
        return 0
    fi

    _tmp=$(mktemp -d)
    if sudo mount --bind /mnt "$_tmp" 2>/dev/null; then
        sudo mkdir -p "$_tmp/c/Users/$WIN_USER/.vscode/extensions"
        sudo umount "$_tmp"
        rmdir "$_tmp"
    else
        rmdir "$_tmp"
        warn "$MOUNT_POINT を作れなかった (/mnt/c に drvfs が被っている)。"
        note "wsl --shutdown で入り直したあと、もう一度 ./install-wsl.sh を実行する。"
    fi
}

# ------------------------------------------------------------------ 本体

if ! is_wsl; then
    log "WSL ではないので何もしない。"
    exit 0
fi

WIN_USER=${1:-${WIN_USER:-}}
[ -n "$WIN_USER" ] || WIN_USER=$(win_user_from_interop)
[ -n "$WIN_USER" ] || WIN_USER=$(win_user_from_users_dir)
[ -n "$WIN_USER" ] ||
    die "Windows のユーザー名が分からない。./install-wsl.sh <Windowsユーザー> で渡す。"

WIN_PATH="C:\\Users\\$WIN_USER\\.vscode\\extensions"
MOUNT_POINT="/mnt/c/Users/$WIN_USER/.vscode/extensions"

log "Windows ユーザー: $WIN_USER"

# 1. wsl.conf
if render_wsl_conf | install_file "$WSL_CONF"; then
    log "$WSL_CONF を更新した。"
    note "wsl.conf の変更は PowerShell で wsl --shutdown してから入り直すと効く。"
else
    log "$WSL_CONF は変更なし。"
fi

# 2. VS Code の拡張ディレクトリ (バージョン付きの ms-vscode-remote.remote-wsl-<ver>
#    ではなく親の extensions を指すので、拡張が更新されても直さなくてよい)
ensure_mount_point

FSTAB_LINE="$(fstab_escape "$WIN_PATH") $(fstab_escape "$MOUNT_POINT") drvfs ro,uid=$(id -u),gid=$(id -g) 0 0"

if render_fstab vscode-extensions <<EOF | install_file "$FSTAB"
$FSTAB_LINE
EOF
then
    log "$FSTAB に VS Code 拡張のマウントを書いた。"
else
    log "$FSTAB は変更なし。"
fi

# automount が生きている間は Windows 側がそのまま見えているので何もしない。
if ! is_mounted /mnt/c && ! is_mounted "$MOUNT_POINT"; then
    sudo mount "$MOUNT_POINT" || warn "$MOUNT_POINT をマウントできなかった。"
fi

log "$MOUNT_POINT <- $WIN_PATH (ro)"
