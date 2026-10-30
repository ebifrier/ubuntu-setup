"""Codex の管理対象キーをマージし、検証後にアトミックに保存する。"""

import os
from pathlib import Path
import shutil
import sys
import tempfile

import tomlkit


def configure(codex_dir: Path, user_home: Path) -> None:
    config_path = codex_dir / "config.toml"
    original = config_path.read_text() if config_path.exists() else ""
    config = tomlkit.parse(original)
    config["sandbox_mode"] = "workspace-write"
    config["approval_policy"] = "on-request"
    config["approvals_reviewer"] = "auto_review"

    if "sandbox_workspace_write" not in config:
        config["sandbox_workspace_write"] = tomlkit.table()
    sandbox = config["sandbox_workspace_write"]
    sandbox["network_access"] = True

    if "writable_roots" not in sandbox:
        sandbox["writable_roots"] = tomlkit.array()
    roots = sandbox["writable_roots"]
    if not isinstance(roots, (list, tomlkit.items.Array)) or any(
        not isinstance(root, str) for root in roots
    ):
        raise ValueError("sandbox_workspace_write.writable_roots は文字列の配列が必要")
    for path in (user_home / ".local", user_home / ".cache"):
        if str(path) not in roots:
            roots.append(str(path))

    # context7 MCP。env など利用者が足したキーは残し、起動方法だけ揃える。
    if "mcp_servers" not in config:
        config["mcp_servers"] = tomlkit.table(is_super_table=True)
    servers = config["mcp_servers"]
    if "context7" not in servers:
        servers["context7"] = tomlkit.table()
    context7 = servers["context7"]
    context7["command"] = "npx"
    context7["args"] = ["-y", "@upstash/context7-mcp"]

    updated = tomlkit.dumps(config)
    tomlkit.parse(updated)
    if updated == original:
        return

    codex_dir.mkdir(parents=True, exist_ok=True)
    # 初回の既存設定を残す。再実行してもバックアップを上書きしない。
    backup = config_path.with_name("config.toml.bak")
    if config_path.exists() and not backup.exists():
        shutil.copy2(config_path, backup)

    fd, temporary = tempfile.mkstemp(prefix=".config-", suffix=".toml", dir=codex_dir)
    try:
        with os.fdopen(fd, "w") as output:
            output.write(updated)
        os.replace(temporary, config_path)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)


if __name__ == "__main__":
    try:
        configure(Path(sys.argv[1]), Path(sys.argv[2]))
    except (OSError, ValueError, TypeError, KeyError) as error:
        sys.exit(f"Codex 設定を更新できなかった: {error}")
