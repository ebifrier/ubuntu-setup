---
name: docker-compose-ops
description: Docker Compose の運用パターン。compose ファイルの構成、healthcheck、環境変数、デプロイ・更新手順、PostgreSQL のバックアップ、ログ調査、トラブルシュート。compose 設定を書く・直す・本番反映するときに使う。
---

# Docker Compose 運用パターン

Web アプリ + PostgreSQL 構成を Docker Compose で運用するためのパターン集。

## 基本方針

- compose ファイル・Dockerfile を変更したら、ローカル起動だけで済ませず
  `docker compose build` が通ることまで確認する。
- **データを消すコマンドは実行前に必ず確認する**: `docker compose down -v`（volume 削除）、
  `docker volume rm / prune` は DB のデータを消す。ユーザーの明示的な指示なしに実行しない。
- 環境変数の定義箇所（`.env` / `environment:` / `env_file:`）と実際に参照される値を
  混同しない。`docker compose config` で解決後の値を確認できる。

## compose ファイルの型

```yaml
services:
  app:
    build: .
    restart: unless-stopped
    ports:
      - "3000:3000"
    environment:
      DATABASE_URL: postgres://app:${POSTGRES_PASSWORD}@db:5432/app
    depends_on:
      db:
        condition: service_healthy # 起動順だけでなく「準備完了」を待つ

  db:
    image: postgres:16
    restart: unless-stopped
    environment:
      POSTGRES_USER: app
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
      POSTGRES_DB: app
    volumes:
      - db-data:/var/lib/postgresql/data # 名前付き volume で永続化
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U app -d app"]
      interval: 5s
      timeout: 5s
      retries: 10

volumes:
  db-data:
```

ポイント:

- `depends_on` は素の指定だと「コンテナ起動順」しか保証しない。DB を待つには
  `condition: service_healthy` + healthcheck が必要。
- アプリからは `localhost` ではなく**サービス名**（`db`）で接続する。
- ホスト側からコンテナ内 DB へは公開ポート経由、コンテナからホストへは
  `host.docker.internal`（Linux では `extra_hosts` の追加が必要な場合あり）。

## 日常操作

```bash
docker compose up -d              # 起動（デタッチ）
docker compose ps                 # 状態と healthcheck 確認
docker compose logs -f app        # ログ追跡（サービス指定）
docker compose logs --tail=100 app
docker compose exec app sh        # コンテナ内でシェル
docker compose exec db psql -U app -d app
docker compose config             # 変数解決後の最終的な設定を表示
```

## 更新・デプロイ手順

```bash
git pull
docker compose build app          # 変更があったサービスだけビルド
docker compose up -d app          # 該当サービスだけ再作成（DB は触らない）
docker compose ps                 # healthy になることを確認
docker compose logs --tail=50 app # 起動エラーがないか確認
```

- イメージ更新が反映されない場合: `docker compose up -d --force-recreate app`、
  それでも怪しければ `docker compose build --no-cache app`。
- DB マイグレーションがある場合は、アプリ更新の前後どちらで実行するかを
  プロジェクトの手順（README / CLAUDE.md）に従って明示的に行う。

## PostgreSQL のバックアップ・リストア

```bash
# バックアップ（ホスト側にファイルを残す）
docker compose exec -T db pg_dump -U app -d app > backup_$(date +%Y%m%d).sql

# リストア（既存データに上書きされることを確認してから）
docker compose exec -T db psql -U app -d app < backup_20260101.sql
```

- volume 削除やイメージのメジャーバージョン更新（例: postgres:15 → 16）の前には
  必ずバックアップを取る。メジャー更新はデータディレクトリ互換がないため
  dump & restore が必要。

## トラブルシュート

| 症状                     | 確認すること                                                                 |
| ------------------------ | ---------------------------------------------------------------------------- |
| ポート衝突で起動しない   | `ss -tlnp` / 既存コンテナ (`docker ps`) と `ports:` の重複                   |
| アプリが DB に繋がらない | 接続先がサービス名か、healthcheck が通っているか、認証情報の env 不一致      |
| 環境変数が反映されない   | `docker compose config` で解決値を見る。`.env` の置き場所は compose と同階層 |
| コード変更が反映されない | ビルド済みイメージが古い。`build` し直し、`--force-recreate`                 |
| volume の権限エラー      | コンテナ内 UID とホスト側所有者の不一致。`user:` 指定や chown を検討         |
| ディスク逼迫             | `docker system df`。削除は影響を確認してから（`prune` は要注意）             |

## ローカルと本番の差分

- ローカルで動いても本番 compose で動く保証はない。環境変数・マイグレーション・
  ネットワーク（サービス名解決）・ビルド成果物の有無が典型的な差分。
- 差分は override で管理する: `docker-compose.yml`（共通）+
  `docker-compose.override.yml`（ローカル、自動読込）+ `-f` 指定で本番用を明示。
