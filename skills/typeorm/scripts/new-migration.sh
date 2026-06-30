#!/usr/bin/env bash
set -euo pipefail

# Scaffold a timestamped TypeORM migration at src/migrations/<ts>-<MigrationName>.ts
# Usage: scripts/new-migration.sh <MigrationName>

if [ "$#" -ne 1 ] || [ -z "${1:-}" ]; then
  echo "Usage: $0 <MigrationName>" >&2
  echo "  e.g. $0 CreateUsers" >&2
  exit 1
fi

# Normalize to a valid PascalCase class identifier (add-users / add_users -> AddUsers),
# so the generated migration class always compiles.
migration_name="$(printf '%s' "$1" \
  | sed -E 's/([a-z0-9])([A-Z])/\1 \2/g' \
  | tr '_-' '  ' \
  | awk '{ out=""; for (i=1; i<=NF; i++) out = out toupper(substr($i,1,1)) substr($i,2); print out }')"

case "$migration_name" in
  [A-Za-z]*) : ;;
  *)
    echo "Error: <MigrationName> must start with a letter (got '$1')." >&2
    exit 1
    ;;
esac

# Millisecond timestamp, consistent magnitude on every platform so TypeORM orders
# migrations correctly across a mixed (macOS/Linux) team. Prefer Node's Date.now()
# (always present in a TypeORM project); fall back to seconds*1000 — still a 13-digit
# millisecond-magnitude value, unlike a bare `date +%s` (10 digits) which would sort
# before any ms value.
timestamp="$(node -e 'process.stdout.write(String(Date.now()))' 2>/dev/null || true)"
case "$timestamp" in
  ''|*[!0-9]*) timestamp="$(date +%s)000" ;;
esac

target_dir="src/migrations"
target_file="${target_dir}/${timestamp}-${migration_name}.ts"

if [ -e "$target_file" ]; then
  echo "Skipping: $target_file already exists (not overwriting)." >&2
  exit 0
fi

mkdir -p "$target_dir"

cat > "$target_file" <<EOF
import { MigrationInterface, QueryRunner } from 'typeorm';

export class ${migration_name}${timestamp} implements MigrationInterface {
  public async up(_queryRunner: QueryRunner): Promise<void> {
    // TODO: implement forward migration (rename _queryRunner -> queryRunner when used)
  }

  public async down(_queryRunner: QueryRunner): Promise<void> {
    // TODO: implement rollback (rename _queryRunner -> queryRunner when used)
  }
}
EOF

echo "Created $target_file"
