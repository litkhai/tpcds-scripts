#!/usr/bin/env python3
"""
compare-schemas.py — Report where the five engine schemas disagree.
                     다섯 개 엔진 스키마가 불일치하는 지점을 보고합니다.

WHY / 이유

Three of the schemas come from different places: Oracle is repo-native, PostgreSQL and
Vertica are derived from it, and ClickHouse and StarRocks are imported verbatim from
upstream projects. Those upstreams do not all follow the same TPC-DS revision, so a
column can have a different name or a different type depending on the engine.
스키마 세 종류는 서로 다른 출처를 가집니다. Oracle 은 리포 고유 자산, PostgreSQL 과
Vertica 는 이를 파생한 것, ClickHouse 와 StarRocks 는 상류 프로젝트에서 그대로 가져온
것입니다. 상류들이 동일한 TPC-DS 리비전을 따르지 않으므로 컬럼 이름이나 타입이 엔진에
따라 다를 수 있습니다.

That matters in two concrete ways: a single fixture cannot load into every engine if the
column lists differ, and query results are not comparable across engines whose columns
mean different things.
이는 두 가지 구체적 문제를 낳습니다. 컬럼 목록이 다르면 하나의 픽스처를 모든 엔진에
적재할 수 없고, 컬럼의 의미가 다른 엔진 사이에서는 쿼리 결과를 비교할 수 없습니다.

Usage / 사용법:
    tools/compare-schemas.py
    tools/compare-schemas.py --markdown        # emit a table for the docs / 문서용 표 출력
"""

import argparse
import pathlib
import re
import sys

ENGINES = ["oracle", "postgres", "vertica", "clickhouse", "starrocks"]

# Normalise the engine-specific spellings of the same logical type so the report shows
# real disagreements rather than dialect noise.
# 같은 논리 타입의 엔진별 표기를 정규화해, 방언 차이가 아니라 실제 불일치만 보고합니다.
TYPE_CLASSES = [
    ("int",     {"integer", "int", "int64", "int32", "bigint", "uint32", "smallint",
                 "largeint", "tinyint"}),
    ("decimal", {"decimal", "numeric", "double", "float", "float64", "decimal64"}),
    ("date",    {"date"}),
    ("time",    {"time", "datetime", "timestamp"}),
    ("string",  {"char", "varchar", "text", "string", "fixedstring", "lowcardinality"}),
]


def type_class(decl):
    base = re.split(r"[(\s]", decl.strip().lower(), maxsplit=1)[0]
    base = base.replace("nullable", "").strip("()")
    for name, members in TYPE_CLASSES:
        if base in members:
            return name
    return base or "?"


def parse(path):
    """Return {table: {column: type_class}} from any of the engine DDL dialects.
    엔진 DDL 방언 어디서든 {table: {column: type_class}} 를 반환합니다."""
    if not path.is_file():
        return {}
    text = path.read_text()
    tables = {}
    # Stop at a line that is just ")" plus any engine-specific trailing clauses.
    # 단독 ")" 와 엔진별 후행 절에서 파싱을 멈춥니다.
    for m in re.finditer(r"create\s+table\s+(?:if\s+not\s+exists\s+)?[`\"]?(\w+)[`\"]?\s*\((.*?)^\s*\)",
                         text, re.IGNORECASE | re.DOTALL | re.MULTILINE):
        name, body = m.group(1).lower(), m.group(2)
        cols = {}
        for line in body.splitlines():
            line = line.strip().rstrip(",").strip()
            low = line.lower()
            if not line or low.startswith(("primary key", "duplicate key", "distributed by",
                                           "properties", "order by", "engine", "--", "index",
                                           "unique key", "aggregate key", "partition by")):
                continue
            parts = line.split(None, 1)
            if len(parts) < 2:
                continue
            col = parts[0].strip('`"').lower()
            if col in ("primary", "key", "constraint"):
                continue
            cols[col] = type_class(parts[1])
        if cols:
            tables[name] = cols
    return tables


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--markdown", action="store_true", help="emit a markdown table / 마크다운 표 출력")
    args = ap.parse_args()

    repo = pathlib.Path(__file__).resolve().parent.parent
    schemas = {e: parse(repo / "engines" / e / "ddl" / "schema.sql") for e in ENGINES}

    present = [e for e in ENGINES if schemas[e]]
    if len(present) < 2:
        sys.exit("need at least two engine schemas to compare")

    all_tables = sorted({t for s in schemas.values() for t in s})

    missing_tables = []
    name_diffs = []
    type_diffs = []

    for table in all_tables:
        absent = [e for e in present if table not in schemas[e]]
        if absent:
            missing_tables.append((table, absent))
            continue
        cols = {e: schemas[e][table] for e in present}
        every = sorted({c for m in cols.values() for c in m})
        for col in every:
            has = [e for e in present if col in cols[e]]
            if len(has) != len(present):
                name_diffs.append((table, col, has, [e for e in present if e not in has]))
                continue
            classes = {cols[e][col] for e in present}
            if len(classes) > 1:
                type_diffs.append((table, col, {e: cols[e][col] for e in present}))

    if args.markdown:
        print("| Table / 테이블 | Column / 컬럼 | Divergence / 불일치 |")
        print("| --- | --- | --- |")
        for table, absent in missing_tables:
            print(f"| `{table}` | *(whole table)* | absent from: {', '.join(absent)} |")
        for table, col, has, lacks in name_diffs:
            print(f"| `{table}` | `{col}` | present in {', '.join(has)}; absent from {', '.join(lacks)} |")
        for table, col, per in type_diffs:
            desc = ", ".join(f"{e}={t}" for e, t in per.items())
            print(f"| `{table}` | `{col}` | {desc} |")
        if not (missing_tables or name_diffs or type_diffs):
            print("| — | — | no divergence / 불일치 없음 |")
        return

    print(f"Comparing {len(present)} schemas: {', '.join(present)}")
    print(f"Tables seen: {len(all_tables)}\n")

    if missing_tables:
        print(f"── Tables missing from some engines / 일부 엔진에 없는 테이블 ({len(missing_tables)})")
        for table, absent in missing_tables:
            print(f"   {table:<24} absent from: {', '.join(absent)}")
        print()

    if name_diffs:
        print(f"── Column name divergence / 컬럼명 불일치 ({len(name_diffs)})")
        for table, col, has, lacks in name_diffs:
            print(f"   {table}.{col}")
            print(f"      in:  {', '.join(has)}")
            print(f"      not: {', '.join(lacks)}")
        print()

    if type_diffs:
        print(f"── Column type divergence / 컬럼 타입 불일치 ({len(type_diffs)})")
        for table, col, per in type_diffs:
            print(f"   {table}.{col}")
            for e, t in per.items():
                print(f"      {e:<12} {t}")
        print()

    total = len(missing_tables) + len(name_diffs) + len(type_diffs)
    if total == 0:
        print("No divergence. / 불일치 없음.")
    else:
        print(f"{total} divergence(s). A single fixture cannot satisfy all engines where")
        print("column names or type classes differ, and results are not comparable there.")
        print(f"{total} 건의 불일치. 컬럼명이나 타입 분류가 다른 지점에서는 하나의 픽스처로")
        print("모든 엔진을 만족시킬 수 없고, 결과도 비교할 수 없습니다.")
    sys.exit(0)


if __name__ == "__main__":
    main()
