#!/usr/bin/env python3
"""
make-fixture.py — Generate a small, referentially consistent, TPC-DS-shaped dataset.
                  작고 참조 정합성이 있는 TPC-DS 형태의 데이터셋을 생성합니다.

WHY THIS EXISTS / 이 도구가 필요한 이유

Verifying that 103 queries actually run on an engine needs data. The TPC-DS data
generator is TPC EULA material and cannot be vendored here, and an empty schema is
not enough — query 90 divides by a count that is zero without rows, and a schema with
no data cannot catch a type or NULL-handling mistake.
103개 쿼리가 실제로 실행되는지 검증하려면 데이터가 필요합니다. TPC-DS 데이터 생성기는
TPC EULA 자산이라 여기에 포함할 수 없고, 빈 스키마만으로는 부족합니다. 쿼리 90 은 행이
없으면 0 이 되는 count 로 나누며, 데이터가 없는 스키마에서는 타입이나 NULL 처리 오류를
잡을 수 없습니다.

So this writes our own synthetic data in the dsdgen output format: pipe-delimited with
a trailing delimiter on every line. It is NOT TPC-DS data and produces no meaningful
answers — column domains are seeded with the literal values the queries filter on so
that joins and predicates match something, nothing more.
따라서 dsdgen 출력 형식(파이프 구분, 각 줄 끝에도 구분자)으로 자체 합성 데이터를
생성합니다. TPC-DS 데이터가 아니며 의미 있는 정답을 만들지 않습니다. 조인과 조건이
무언가와 매칭되도록 쿼리가 필터하는 리터럴 값으로 컬럼 도메인을 채운 것이 전부입니다.

Use it to answer "does this SQL run on this engine", never "is this engine fast" or
"is this answer correct".
"이 SQL 이 이 엔진에서 실행되는가" 를 확인하는 용도이며, "이 엔진이 빠른가" 나
"이 정답이 맞는가" 에는 사용할 수 없습니다.

The column list for every table is parsed from engines/oracle/ddl/schema.sql, so the
field count and declared sizes always match the schema rather than a hardcoded guess.
모든 테이블의 컬럼 목록은 engines/oracle/ddl/schema.sql 에서 파싱하므로, 하드코딩된
추측이 아니라 스키마와 항상 일치하는 필드 수·선언 크기를 사용합니다.

Usage / 사용법:
    tools/make-fixture.py --out /tmp/tpcds-fixture [--rows-scale 1.0]
"""

import argparse
import datetime as dt
import pathlib
import random
import re
import sys

EPOCH = dt.date(1900, 1, 1)
# TPC-DS date_dim surrogate keys are Julian day numbers: 1900-01-02 is 2415022.
# TPC-DS date_dim 대리키는 율리우스 일수이며 1900-01-02 는 2415022 입니다.
DATE_SK_BASE = 2415021

# The queries filter on years 1998-2002, so cover a little either side.
# 쿼리가 1998~2002 년을 필터하므로 양쪽으로 약간 넓게 생성합니다.
DATE_START = dt.date(1998, 1, 1)
DATE_END = dt.date(2003, 12, 31)

# ---------------------------------------------------------------------------
# Domains taken from the TPC-DS column definitions, chosen so that the literal
# values the queries filter on are present.
# 쿼리가 필터하는 리터럴 값이 존재하도록 TPC-DS 컬럼 정의에서 가져온 도메인.
# ---------------------------------------------------------------------------
CATEGORIES = ["Books", "Children", "Electronics", "Home", "Jewelry",
              "Men", "Music", "Shoes", "Sports", "Women"]
# 'TN' appears in many predicates (s_state = 'TN'), so weight it heavily.
# 'TN' 이 여러 조건절에 등장하므로(s_state = 'TN') 비중을 높입니다.
STATES = ["TN"] * 6 + ["SD", "CA", "TX", "GA", "MI", "OH", "NY", "WI", "MO",
                       "VA", "AL", "KY", "NE", "IN", "KS", "NC", "SC", "ND",
                       "MN", "IL", "MS", "LA", "PA", "WA", "OR", "FL", "AZ"]
EDUCATION = ["Primary", "Secondary", "College", "2 yr Degree", "4 yr Degree",
             "Advanced Degree", "Unknown"]
MARITAL = ["M", "S", "D", "W", "U"]
GENDER = ["M", "F"]
CREDIT = ["Good", "High Risk", "Low Risk", "Unknown"]
BUY_POTENTIAL = [">10000", "1001-5000", "501-1000", "5001-10000", "0-500", "Unknown"]
DAY_NAMES = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
SHIP_MODES = ["LIBRARY", "EXPRESS", "TWO DAY", "NEXT DAY", "OVERNIGHT", "REGULAR"]
CARRIERS = ["UPS", "FEDEX", "DHL", "USPS", "AIRBORNE", "ZOUROS", "MSC", "ALLIANCE"]
COLORS = ["red", "blue", "green", "white", "black", "orange", "papaya",
          "chiffon", "smoke", "steel", "khaki", "cyan"]
SIZES = ["small", "medium", "large", "petite", "economy", "extra large", "N/A"]
UNITS = ["Ounce", "Oz", "Bunch", "Ton", "N/A", "Dozen", "Box", "Pallet",
         "Gram", "Unknown", "Case", "Each", "Tsp", "Lb", "Gross", "Cup",
         "Dram", "Tbl", "Pound", "Bundle", "Carton"]
CHANNELS = ["N", "Y"]
SALES_TYPES = ["Unknown", "Adult", "Teenager", "Child", "Baby"]
BRANDS = ["amalgamalg", "edu packamalg", "exportiimporto", "importoamalg",
          "scholaramalgamalg", "corpnameless", "brandbrand"]
CLASSES = ["birdal", "bracelets", "business", "camcorders", "classical",
           "consignment", "curtains", "decor", "dresses", "estate", "fiction"]
MANAGERS = ["Mr.", "Ms.", "Dr.", "Sir", "Miss"]
HOURS = ["8AM-4PM", "8AM-8AM", "8AM-12AM", "12AM-12AM", "6AM-12AM"]
STREET_TYPES = ["Street", "Avenue", "Road", "Drive", "Lane", "Way", "Blvd",
                "Court", "Circle", "Parkway", "Ct", "RD", "Pkwy", "Wy", "Dr"]
LOCATION_TYPES = ["condo", "apartment", "single family"]
COUNTRIES = ["United States"]
DIVISIONS = ["Unknown", "pri", "able", "ese", "anti"]
COMPANIES = ["Unknown", "able", "pri", "ese", "anti", "cally"]
WAREHOUSE_NAMES = ["Bad cards must make.", "Conventional childr",
                   "Doors canno", "Important issues liv", "Regular gains"]

NULL_RATE = 0.02  # exercise NULL handling without breaking joins / 조인을 깨지 않으면서 NULL 처리 검증


def parse_schema(path):
    """Return {table: [(column, base_type, size)]} from the canonical DDL.
    표준 DDL 에서 {table: [(column, base_type, size)]} 를 반환합니다."""
    text = path.read_text()
    tables = {}
    for m in re.finditer(r"create\s+table\s+(\w+)\s*\((.*?)\n\);", text,
                         re.IGNORECASE | re.DOTALL):
        name, body = m.group(1).lower(), m.group(2)
        cols = []
        for line in body.splitlines():
            line = line.strip().rstrip(",").strip()
            if not line or line.lower().startswith("primary key"):
                continue
            parts = line.split()
            if len(parts) < 2:
                continue
            col, decl = parts[0].lower(), parts[1].lower()
            size = None
            tm = re.match(r"(\w+)\((\d+)(?:,(\d+))?\)", decl)
            if tm:
                base = tm.group(1)
                size = int(tm.group(2))
            else:
                base = decl
            # NOT NULL columns must never receive an empty field, or the load
            # fails on every engine that enforces it.
            # NOT NULL 컬럼에는 빈 필드를 넣으면 안 됩니다. 이를 강제하는 모든
            # 엔진에서 적재가 실패합니다.
            nullable = "not null" not in line.lower()
            cols.append((col, base, size, nullable))
        tables[name] = cols
    return tables


class Generator:
    def __init__(self, seed, scale):
        self.rnd = random.Random(seed)
        self.scale = scale
        self.dates = []          # list of (d_date_sk, date)
        self.n = {}              # per-table row counts / 테이블별 행 수

    def sized(self, n):
        return max(1, int(n * self.scale))

    # -- primitive value generators / 기본 값 생성기 -------------------------
    def maybe_null(self, value, allow=True):
        if allow and self.rnd.random() < NULL_RATE:
            return ""
        return value

    def business_key(self, i, width=16):
        """A stable alphabetic id, like the AAAAAAAA... ids dsdgen emits.
        dsdgen 이 출력하는 AAAAAAAA... 형태의 안정적인 영문 id."""
        s = ""
        v = i + 1
        while v > 0:
            s = chr(ord("A") + (v - 1) % 26) + s
            v = (v - 1) // 26
        return s.rjust(width, "A")[:width]

    def money(self, lo, hi):
        return f"{self.rnd.uniform(lo, hi):.2f}"

    def fit(self, text, size):
        """Never emit more characters than the column declares — a char(2) column
        rejects a 3-character value on PostgreSQL and Oracle.
        컬럼 선언보다 긴 값을 내보내지 않습니다. char(2) 컬럼은 PostgreSQL·Oracle
        에서 3자 값을 거부합니다."""
        if size is not None and isinstance(text, str) and len(text) > size:
            return text[:size]
        return text

    # -- semantic column values / 의미 기반 컬럼 값 --------------------------
    def value(self, table, col, base, size, row, nullable=True):
        r = self.rnd

        # Surrogate and business keys, and the foreign keys that reference them.
        # 대리키·비즈니스키 및 이를 참조하는 외래키.
        if col.endswith("_sk") or col in ("ss_ticket_number", "sr_ticket_number",
                                          "cs_order_number", "cr_order_number",
                                          "ws_order_number", "wr_order_number"):
            return self.key_value(table, col, row, nullable)
        if col.endswith("_id") and base in ("char", "varchar"):
            return self.fit(self.business_key(row), size)

        # The engine schemas disagree on customer.c_last_review_date: this repo's
        # Oracle schema (and the sets derived from it) declare char(10), following an
        # older TPC-DS revision, while the upstream ClickHouse schema declares
        # c_last_review_date_sk UInt32. A date surrogate key satisfies both, since the
        # digits fit in char(10) and parse as UInt32. Run tools/compare-schemas.py to
        # see the full list of divergences.
        # 엔진 스키마가 customer.c_last_review_date 에서 불일치합니다. 이 리포의 Oracle
        # 스키마(및 파생 세트)는 구 TPC-DS 리비전을 따라 char(10) 으로 선언하고, 상류
        # ClickHouse 스키마는 c_last_review_date_sk UInt32 로 선언합니다. 날짜 대리키는
        # 자릿수가 char(10) 에 들어가고 UInt32 로도 파싱되므로 양쪽을 모두 만족합니다.
        # 전체 불일치 목록은 tools/compare-schemas.py 로 확인하십시오.
        if col in ("c_last_review_date", "c_last_review_date_sk"):
            return str(r.choice(self.dates)[0])

        # Columns whose exact values the queries filter on.
        # 쿼리가 값 자체를 필터하는 컬럼.
        exact = {
            "i_category": lambda: r.choice(CATEGORIES),
            "i_class": lambda: r.choice(CLASSES),
            "i_brand": lambda: r.choice(BRANDS),
            "i_color": lambda: r.choice(COLORS),
            "i_size": lambda: r.choice(SIZES),
            "i_units": lambda: r.choice(UNITS),
            "i_manufact": lambda: f"manuf{r.randint(1, 50)}",
            "cd_gender": lambda: r.choice(GENDER),
            "cd_marital_status": lambda: r.choice(MARITAL),
            "cd_education_status": lambda: r.choice(EDUCATION),
            "cd_credit_rating": lambda: r.choice(CREDIT),
            "hd_buy_potential": lambda: r.choice(BUY_POTENTIAL),
            "c_birth_country": lambda: r.choice(COUNTRIES + ["CANADA", "MEXICO", "JAPAN"]),
            "c_preferred_cust_flag": lambda: r.choice(["Y", "N"]),
            "ca_state": lambda: r.choice(STATES),
            "s_state": lambda: r.choice(STATES),
            "cc_state": lambda: r.choice(STATES),
            "w_state": lambda: r.choice(STATES),
            "ca_country": lambda: r.choice(COUNTRIES),
            "s_country": lambda: r.choice(COUNTRIES),
            "cc_country": lambda: r.choice(COUNTRIES),
            "w_country": lambda: r.choice(COUNTRIES),
            "ca_location_type": lambda: r.choice(LOCATION_TYPES),
            "ca_street_type": lambda: r.choice(STREET_TYPES),
            "s_street_type": lambda: r.choice(STREET_TYPES),
            "cc_street_type": lambda: r.choice(STREET_TYPES),
            "w_street_type": lambda: r.choice(STREET_TYPES),
            "sm_type": lambda: r.choice(SHIP_MODES[:4]),
            "sm_carrier": lambda: r.choice(CARRIERS),
            "sm_code": lambda: r.choice(["Regular", "Express", "Library", "Overnight"]),
            "sm_ship_mode_id": lambda: self.fit(self.business_key(row), size),
            "cc_class": lambda: r.choice(["large", "medium", "small"]),
            "cc_hours": lambda: r.choice(HOURS),
            "s_hours": lambda: r.choice(HOURS),
            "cc_manager": lambda: f"{r.choice(MANAGERS)} Manager{row}",
            "s_manager": lambda: f"{r.choice(MANAGERS)} Manager{row}",
            "cc_division_name": lambda: r.choice(DIVISIONS),
            "cc_company_name": lambda: r.choice(COMPANIES),
            "w_warehouse_name": lambda: r.choice(WAREHOUSE_NAMES),
            "d_day_name": lambda: DAY_NAMES[0],  # overwritten by date_dim / date_dim 에서 덮어씀
        }
        if col in exact:
            return self.fit(exact[col](), size)

        # Promotion channel flags are all 'N'/'Y' and several queries filter them.
        # 프로모션 채널 플래그는 모두 'N'/'Y' 이며 여러 쿼리가 이를 필터합니다.
        if col.startswith("p_channel_"):
            return r.choice(CHANNELS)
        if col in ("p_discount_active",):
            return r.choice(CHANNELS)

        # web_page char counts: query 90 filters wp_char_count between 5000 and 5200.
        # web_page 문자 수: 쿼리 90 이 wp_char_count 를 5000~5200 으로 필터합니다.
        if col == "wp_char_count":
            return str(r.randint(4900, 5300))

        # Fall back on the declared type. / 선언된 타입으로 대체.
        if base == "integer":
            return self.integer_fallback(col, row)
        if base == "decimal":
            return self.money(0, 200)
        if base == "date":
            return self.rnd.choice(self.dates)[1].isoformat() if self.dates else "2000-01-01"
        if base == "time":
            return f"{r.randint(0,23):02d}:{r.randint(0,59):02d}:{r.randint(0,59):02d}"
        # char / varchar
        return self.fit(f"{col[:3]}{row}", size)

    def integer_fallback(self, col, row):
        r = self.rnd
        if "count" in col:
            return str(r.randint(0, 9))
        if "quantity" in col:
            return str(r.randint(1, 100))
        if col.endswith("_year"):
            return str(r.randint(1998, 2002))
        if "manager" in col or "mkt_id" in col or "division" in col or "company" in col:
            return str(r.randint(1, 6))
        if "manufact_id" in col or "brand_id" in col or "class_id" in col or "category_id" in col:
            return str(r.randint(1, 20))
        return str(r.randint(1, 1000))

    # The fact tables declare composite primary keys, so their key columns cannot be
    # random: (ss_item_sk, ss_ticket_number) drawn independently collides within a few
    # thousand rows and the load fails on any engine that enforces the constraint.
    # These are therefore derived from the row index so they are unique by construction.
    # 팩트 테이블은 복합 기본키를 선언하므로 키 컬럼을 무작위로 생성할 수 없습니다.
    # (ss_item_sk, ss_ticket_number) 를 독립적으로 뽑으면 수천 행 안에 충돌하고, 제약을
    # 강제하는 엔진에서 적재가 실패합니다. 따라서 행 인덱스에서 유도해 구조적으로
    # 유일하게 만듭니다.
    LINES_PER_ORDER = 4

    FACT_PK = {
        "store_sales":     ("ss_item_sk", "ss_ticket_number"),
        "store_returns":   ("sr_item_sk", "sr_ticket_number"),
        "catalog_sales":   ("cs_item_sk", "cs_order_number"),
        "catalog_returns": ("cr_item_sk", "cr_order_number"),
        "web_sales":       ("ws_item_sk", "ws_order_number"),
        "web_returns":     ("wr_item_sk", "wr_order_number"),
    }

    def fact_pk(self, table, col, row):
        """Return the value for a fact-table primary-key column, or None.
        팩트 테이블 기본키 컬럼의 값을 반환하거나, 해당하지 않으면 None."""
        pk = self.FACT_PK.get(table)
        if pk is not None:
            item_col, order_col = pk
            idx = row - 1
            n_items = self.n["item"]
            if col == order_col:
                return str(idx // self.LINES_PER_ORDER + 1)
            if col == item_col:
                # Consecutive rows share an order and take consecutive items, so the
                # items within one order are always distinct.
                # 연속된 행이 같은 주문을 공유하고 연속된 아이템을 사용하므로 한 주문
                # 안의 아이템은 항상 서로 다릅니다.
                return str(idx % n_items + 1)
            return None

        if table == "inventory":
            # PK is (inv_date_sk, inv_item_sk, inv_warehouse_sk): walk the product
            # of warehouse x item x date so every combination appears once.
            # PK 가 (inv_date_sk, inv_item_sk, inv_warehouse_sk) 이므로 창고 x 아이템 x
            # 날짜의 곱집합을 순회해 각 조합이 한 번만 나타나게 합니다.
            idx = row - 1
            n_wh, n_items = self.n["warehouse"], self.n["item"]
            if col == "inv_warehouse_sk":
                return str(idx % n_wh + 1)
            if col == "inv_item_sk":
                return str((idx // n_wh) % n_items + 1)
            if col == "inv_date_sk":
                # Inventory is reported weekly in TPC-DS.
                # TPC-DS 에서 재고는 주 단위로 보고됩니다.
                week = idx // (n_wh * n_items)
                return str(self.dates[min(week * 7, len(self.dates) - 1)][0])
            return None
        return None

    def key_value(self, table, col, row, nullable=True):
        """Foreign keys reference a key that exists, so joins match rows.
        외래키가 실제 존재하는 키를 참조하므로 조인이 행과 매칭됩니다."""
        r = self.rnd

        forced = self.fact_pk(table, col, row)
        if forced is not None:
            return forced
        # The table's own surrogate key is the sequential row number.
        # 테이블 자신의 대리키는 순차 행 번호입니다.
        own = {
            "call_center": "cc_call_center_sk", "catalog_page": "cp_catalog_page_sk",
            "customer": "c_customer_sk", "customer_address": "ca_address_sk",
            "customer_demographics": "cd_demo_sk", "date_dim": "d_date_sk",
            "household_demographics": "hd_demo_sk", "income_band": "ib_income_band_sk",
            "item": "i_item_sk", "promotion": "p_promo_sk", "reason": "r_reason_sk",
            "ship_mode": "sm_ship_mode_sk", "store": "s_store_sk",
            "time_dim": "t_time_sk", "warehouse": "w_warehouse_sk",
            "web_page": "wp_web_page_sk", "web_site": "web_site_sk",
        }
        if own.get(table) == col:
            return str(row)

        # Order / ticket numbers group several line items together.
        # 주문·티켓 번호는 여러 라인 아이템을 묶습니다.
        if col.endswith("ticket_number") or col.endswith("order_number"):
            return str((row - 1) // self.LINES_PER_ORDER + 1)

        # date_sk and time_sk must land inside the generated dimensions.
        # date_sk 와 time_sk 는 생성된 차원 범위 안이어야 합니다.
        if col.endswith("date_sk"):
            return self.maybe_null(str(r.choice(self.dates)[0]), nullable)
        if col.endswith("time_sk"):
            return self.maybe_null(str(r.randrange(0, self.n["time_dim"])), nullable)

        # Everything else references a dimension by name.
        # 그 외는 이름으로 차원을 참조합니다.
        target = {
            "item_sk": "item", "customer_sk": "customer", "cdemo_sk": "customer_demographics",
            "demo_sk": "customer_demographics", "hdemo_sk": "household_demographics",
            "addr_sk": "customer_address", "store_sk": "store", "promo_sk": "promotion",
            "reason_sk": "reason", "call_center_sk": "call_center",
            "catalog_page_sk": "catalog_page", "warehouse_sk": "warehouse",
            "ship_mode_sk": "ship_mode", "web_page_sk": "web_page",
            "web_site_sk": "web_site", "site_sk": "web_site",
        }
        for suffix, tbl in target.items():
            if col.endswith(suffix):
                count = self.n.get(tbl, 1)
                return self.maybe_null(str(r.randrange(1, count + 1)), nullable)
        # Unknown *_sk: a small integer is safe. / 알 수 없는 *_sk 는 작은 정수로.
        return str(r.randint(1, 10))

    # -- date_dim and time_dim need real internal consistency ---------------
    # date_dim 과 time_dim 은 내부 정합성이 실제로 필요합니다.
    def date_dim_row(self, cols, sk, d):
        # d_month_seq counts months from 1900-01, so 1200 is 2000-01. Several
        # queries filter "d_month_seq between 1200 and 1200+11" to mean year 2000.
        # d_month_seq 는 1900-01 부터의 월 수이므로 1200 이 2000-01 입니다. 여러 쿼리가
        # 2000년을 의미하려고 "d_month_seq between 1200 and 1200+11" 을 사용합니다.
        month_seq = (d.year - 1900) * 12 + (d.month - 1)
        week_seq = (d - EPOCH).days // 7 + 1
        quarter_seq = (d.year - 1900) * 4 + (d.month - 1) // 3 + 1
        qoy = (d.month - 1) // 3 + 1
        first_dom = DATE_SK_BASE + (dt.date(d.year, d.month, 1) - EPOCH).days
        if d.month == 12:
            last = dt.date(d.year, 12, 31)
        else:
            last = dt.date(d.year, d.month + 1, 1) - dt.timedelta(days=1)
        vals = {
            "d_date_sk": sk,
            "d_date_id": self.business_key(sk - DATE_SK_BASE),
            "d_date": d.isoformat(),
            "d_month_seq": month_seq,
            "d_week_seq": week_seq,
            "d_quarter_seq": quarter_seq,
            "d_year": d.year,
            "d_dow": (d.weekday() + 1) % 7,
            "d_moy": d.month,
            "d_dom": d.day,
            "d_qoy": qoy,
            "d_fy_year": d.year,
            "d_fy_quarter_seq": quarter_seq,
            "d_fy_week_seq": week_seq,
            "d_day_name": DAY_NAMES[(d.weekday() + 1) % 7],
            "d_quarter_name": f"{d.year}Q{qoy}",
            "d_holiday": "N",
            "d_weekend": "Y" if d.weekday() >= 5 else "N",
            "d_following_holiday": "N",
            "d_first_dom": first_dom,
            "d_last_dom": DATE_SK_BASE + (last - EPOCH).days,
            "d_same_day_ly": sk - 365,
            "d_same_day_lq": sk - 91,
            "d_current_day": "N",
            "d_current_week": "N",
            "d_current_month": "N",
            "d_current_quarter": "N",
            "d_current_year": "N",
        }
        return [str(vals[c]) for c, _, _, _ in cols]

    def time_dim_row(self, cols, sk):
        hour, minute, second = sk // 3600, (sk // 60) % 60, sk % 60
        if hour < 8:
            shift = "third"
        elif hour < 16:
            shift = "first"
        else:
            shift = "second"
        vals = {
            "t_time_sk": sk,
            "t_time_id": self.business_key(sk),
            "t_time": sk,
            "t_hour": hour,
            "t_minute": minute,
            "t_second": second,
            "t_am_pm": "AM" if hour < 12 else "PM",
            "t_shift": shift,
            "t_sub_shift": "morning" if hour < 12 else "evening",
            "t_meal_time": "breakfast" if 6 <= hour < 9 else ("dinner" if 17 <= hour < 20 else ""),
        }
        return [str(vals[c]) for c, _, _, _ in cols]


# Row counts: small enough to load in seconds on every engine, large enough that
# joins and aggregates return rows.
# 행 수: 모든 엔진에서 수초 내에 적재될 만큼 작고, 조인·집계가 행을 반환할 만큼 큽니다.
ROWS = {
    "call_center": 6, "catalog_page": 200, "customer_address": 1000,
    "customer_demographics": 2000, "household_demographics": 200,
    "income_band": 20, "item": 800, "promotion": 60, "reason": 20,
    "ship_mode": 20, "store": 12, "warehouse": 5, "web_page": 60,
    "web_site": 6, "customer": 1500,
    "inventory": 12000, "store_sales": 12000, "store_returns": 1500,
    "catalog_sales": 9000, "catalog_returns": 1200,
    "web_sales": 9000, "web_returns": 1200,
}


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--out", required=True, help="output directory / 출력 디렉터리")
    ap.add_argument("--rows-scale", type=float, default=1.0,
                    help="multiply the row counts / 행 수 배수")
    ap.add_argument("--seed", type=int, default=20260811, help="RNG seed / 난수 시드")
    ap.add_argument("--schema", default=None,
                    help="DDL to read column lists from / 컬럼 목록을 읽을 DDL")
    args = ap.parse_args()

    repo = pathlib.Path(__file__).resolve().parent.parent
    schema_path = pathlib.Path(args.schema) if args.schema \
        else repo / "engines" / "oracle" / "ddl" / "schema.sql"
    if not schema_path.is_file():
        sys.exit(f"no schema at {schema_path}")

    tables = parse_schema(schema_path)
    out = pathlib.Path(args.out)
    out.mkdir(parents=True, exist_ok=True)

    g = Generator(args.seed, args.rows_scale)

    # date_dim first: every fact table's date_sk is drawn from it.
    # date_dim 을 먼저 생성합니다. 모든 팩트 테이블의 date_sk 를 여기서 뽑습니다.
    d = DATE_START
    while d <= DATE_END:
        g.dates.append((DATE_SK_BASE + (d - EPOCH).days, d))
        d += dt.timedelta(days=1)
    g.n["date_dim"] = len(g.dates)
    g.n["time_dim"] = 86400
    for t, count in ROWS.items():
        g.n[t] = g.sized(count)

    written = []

    # date_dim / 날짜 차원
    cols = tables["date_dim"]
    with (out / "date_dim.dat").open("w") as fh:
        for sk, day in g.dates:
            fh.write("|".join(g.date_dim_row(cols, sk, day)) + "|\n")
    written.append(("date_dim", len(g.dates)))

    # time_dim — all 86400 seconds, so any t_time_sk reference resolves.
    # time_dim — 86400초 전체를 생성해 어떤 t_time_sk 참조도 해석됩니다.
    cols = tables["time_dim"]
    with (out / "time_dim.dat").open("w") as fh:
        for sk in range(86400):
            fh.write("|".join(g.time_dim_row(cols, sk)) + "|\n")
    written.append(("time_dim", 86400))

    # Everything else, dimensions before facts so the key ranges exist.
    # 나머지는 키 범위가 존재하도록 차원을 팩트보다 먼저 생성합니다.
    order = ["call_center", "catalog_page", "customer_address",
             "customer_demographics", "household_demographics", "income_band",
             "item", "promotion", "reason", "ship_mode", "store", "warehouse",
             "web_page", "web_site", "customer",
             "inventory", "store_sales", "store_returns", "catalog_sales",
             "catalog_returns", "web_sales", "web_returns"]
    for table in order:
        cols = tables[table]
        count = g.n[table]
        with (out / f"{table}.dat").open("w") as fh:
            for row in range(1, count + 1):
                fields = [g.value(table, c, b, s, row, n) for c, b, s, n in cols]
                fh.write("|".join(fields) + "|\n")
        written.append((table, count))

    total = sum(n for _, n in written)
    size_mb = sum(f.stat().st_size for f in out.glob("*.dat")) / 1e6
    print(f"wrote {len(written)} tables, {total:,} rows, {size_mb:.1f} MB → {out}")
    for name, n in written:
        print(f"  {name:<26} {n:>8,}")
    print("\nThis is synthetic data, NOT TPC-DS data. It validates that queries run;")
    print("it does not validate answers or measure performance.")
    print("합성 데이터이며 TPC-DS 데이터가 아닙니다. 쿼리 실행 가능성만 검증하며")
    print("정답 검증이나 성능 측정에는 사용할 수 없습니다.")


if __name__ == "__main__":
    main()
