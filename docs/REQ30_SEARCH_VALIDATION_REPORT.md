# REQ-30 검색 RPC 검증 리포트 (한글/초성/동의어 확장)

검증 일시: 2026-03-14 (UTC 기준)

대상 환경:

- Project URL: `https://ialgqpzyysctbtqrwyqq.supabase.co`
- Publishable Key: `sb_publishable_tBWvZfUGmzEP9BJWcZCKMA_wFIXV6N1`

적용 마이그레이션:

- `20260301034500_req30_search_optimization.sql`
- `20260301052000_req30_search_korean_synonyms.sql`
- `20260301070000_req30_v2_cardio_weight_split.sql`
- `20260305142000_req30_anatomy_json_upgrade.sql`
- `20260308100000_req30_muscle_standardization.sql`

---

## 1) 배포된 SQL 구성

핵심 변경:

1. `pg_trgm` 확장 활성화
2. 한글/초성 처리 함수 추가
   - `search_normalize_text(text)`
   - `hangul_to_choseong(text)`
3. 동의어/한글 검색 테이블 추가
   - `exercise_search_aliases`
   - 별칭 데이터 업서트 결과: `117`건
4. 검색 인덱스 확장
   - `idx_exercises_name_trgm`
   - `idx_exercises_name_norm_trgm`
   - `idx_exercise_aliases_alias_trgm`
   - `idx_exercise_aliases_alias_norm_trgm`
   - `idx_exercise_aliases_alias_choseong_trgm`
5. `search_exercises` RPC 고도화
   - 영문/한글/초성/동의어 통합 검색
   - 응답 스키마: `id`, `name`, `category`, `exercise_type`, `muscle_size`, `primary_muscles`, `secondary_muscles`
   - 유사도 스코어 기반 정렬
   - 최대 20개 제한

---

## 2) 테스트 코드

검증 스크립트:

- `scripts/req30_search_exercises_rpc_test.js`

테스트 방식:

1. Admin API로 임시 사용자 생성
2. Password grant로 사용자 JWT 발급
3. REST RPC 반복 호출
4. 결과 건수/지연 시간(ms) 수집
5. 테스트 사용자 정리

---

## 3) 실측 결과 (실제 API 호출)

### 3-1) 키워드 `squat`

- HTTP 상태: 전부 `200`
- 결과 건수: `20` (5회 동일)
- 응답 시간:
  - 최소: `124.36ms`
  - 최대: `732.61ms`
  - 평균: `373.27ms`

### 3-2) 키워드 `스쿼트` (한글)

- HTTP 상태: 전부 `200`
- 결과 건수: `12` (3회 동일)
- 응답 시간:
  - 최소: `118.22ms`
  - 최대: `296.07ms`
  - 평균: `232.88ms`

### 3-3) 키워드 `ㅅㅋㅌ` (초성)

- HTTP 상태: 전부 `200`
- 결과 건수: `12` (3회 동일)
- 응답 시간:
  - 최소: `157.38ms`
  - 최대: `326.73ms`
  - 평균: `257.50ms`

### 3-4) 키워드 `벤치프레스` (한글 동의어)

- HTTP 상태: 전부 `200`
- 결과 건수: `6` (3회 동일)
- 응답 시간:
  - 최소: `120.46ms`
  - 최대: `188.17ms`
  - 평균: `152.43ms`

### 3-5) 키워드 `데드리프트` (한글 키워드)

- HTTP 상태: 전부 `200`
- 결과 건수: `4` (3회 동일)
- 응답 시간:
  - 최소: `95.57ms`
  - 최대: `251.73ms`
  - 평균: `151.02ms`

### 3-6) 키워드 `a` (LIMIT 검증)

- HTTP 상태: 전부 `200`
- 결과 건수: `20` (5회 동일)
- 응답 시간:
  - 최소: `106.68ms`
  - 최대: `175.89ms`
  - 평균: `135.80ms`
- 결론: `LIMIT 20` 제약 정상 동작

### 3-7) 빈 키워드 `""`

- HTTP 상태: `200`
- 결과 건수: `0`
- 해석: 공백/빈 문자열 필터 정상 동작

### 3-8) cURL 단건 스모크 타이밍 (service_role)

- `스쿼트`: `0.549238s`, 결과 `12`
- `ㅅㅋㅌ`: `0.082199s`, 결과 `12`
- `벤치프레스`: `0.079311s`, 결과 `6`

---

## 4) Request / Response 예시

### Request (초성 검색)

```bash
curl -sS "https://ialgqpzyysctbtqrwyqq.supabase.co/rest/v1/rpc/search_exercises" \
  --request POST \
  --header "apikey: <sb_publishable_key>" \
  --header "Authorization: Bearer <user_access_token>" \
  --header "Content-Type: application/json" \
  --data '{"p_keyword":"ㅅㅋㅌ"}'
```

### Response (예시)

```json
[
  {
    "id": "921a01bb-c59d-4f19-9190-fc4ea6e3af32",
    "name": "Back Squat",
    "category": "free_weight",
    "exercise_type": "weight",
    "muscle_size": "large",
    "primary_muscles": ["quadriceps"],
    "secondary_muscles": ["adductors", "glutes", "hamstrings", "spinal_erectors"]
  },
  {
    "id": "5fd8a1f6-12f2-479f-bb29-54c38651aabc",
    "name": "Bulgarian Split Squat",
    "category": "free_weight",
    "exercise_type": "weight",
    "muscle_size": "large",
    "primary_muscles": ["quadriceps"],
    "secondary_muscles": ["abductors", "adductors", "glutes", "hamstrings"]
  }
]
```

---

## 5) 결론

- 검색 확장 SQL(한글/초성/동의어) 배포 완료
- `search_exercises` RPC가 영문/한글/초성 검색 모두에서 정상 동작 확인
- 확장 응답 필드(`primary_muscles`, `secondary_muscles`) 정상 반환 확인
- 근육 표준화 이후에도 검색/자동완성 회귀 이상 없음 확인
- 자동완성 시나리오에서 `LIMIT 20` 및 응답 속도 안정성 검증 완료
