--
-- Oracle — gather optimiser statistics. Run this after loading, before querying.
-- Oracle — 옵티마이저 통계 수집. 적재 후 쿼리 전에 실행하십시오.
--
-- Unlike the index file, this is not optional: without statistics the optimiser
-- has no cardinality estimates for the fact tables and will pick nested loops for
-- joins that need hash joins, making several queries effectively non-terminating.
-- 인덱스 파일과 달리 이 단계는 선택이 아닙니다. 통계가 없으면 옵티마이저가 팩트
-- 테이블의 카디널리티를 추정할 수 없어 해시 조인이 필요한 곳에 중첩 루프를
-- 선택하며, 일부 쿼리는 사실상 종료되지 않습니다.
--
-- AUTO_SAMPLE_SIZE lets Oracle choose the sample; it uses a hash-based algorithm
-- that reaches full-scan accuracy for far less work.
-- AUTO_SAMPLE_SIZE 는 Oracle 이 표본을 정하게 합니다. 해시 기반 알고리즘으로 전체
-- 스캔에 준하는 정확도를 훨씬 적은 비용으로 얻습니다.
--
-- METHOD_OPT gathers histograms only on columns that appear in predicates, which
-- is what the TPC-DS filters need.
-- METHOD_OPT 는 조건절에 등장하는 컬럼에만 히스토그램을 만들며, TPC-DS 필터에
-- 필요한 것이 바로 이것입니다.
--

begin
  dbms_stats.gather_schema_stats(
    ownname          => sys_context('userenv', 'current_schema'),
    estimate_percent => dbms_stats.auto_sample_size,
    method_opt       => 'for all columns size auto',
    cascade          => true,
    degree           => dbms_stats.auto_degree,
    no_invalidate    => false
  );
end;
/

-- Confirm every table now has statistics; a NULL num_rows means the gather missed it.
-- 모든 테이블에 통계가 생겼는지 확인합니다. num_rows 가 NULL 이면 누락된 것입니다.
select table_name, num_rows, last_analyzed
from   user_tables
where  num_rows is null
order  by table_name;
