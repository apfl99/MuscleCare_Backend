# REQ30 근육 표준화/정합성 복구 검증 리포트

- 작성일(UTC): 2026-03-14
- 대상 프로젝트: `https://ialgqpzyysctbtqrwyqq.supabase.co`
- 대상 마이그레이션: `20260308100000_req30_muscle_standardization.sql`

---

## 1) 배포 및 데이터 정리 결과

### 1-1) 마이그레이션 적용

- `supabase db push`로 `20260308100000` 적용 완료
- 주요 반영:
  - `muscles` 표준 메타컬럼 추가 (`display_name_ko`, `display_name_latin`, `anatomy_id`, `parent_muscle_code`, `side`)
  - placeholder 차단 CHECK 제약 추가
  - `muscle_code_aliases` 테이블 신설
  - `resolve_muscle_code` 함수 신설
  - `get_muscle_heatmap_status` 응답 계약 강화

### 1-2) JSON 재업서트

실행 스크립트: `scripts/req30_anatomy_json_upsert.js`

- source total: `873`
- existing before: `1073`
- updated existing: `873`
- inserted new: `0`
- skipped: `0`

의미:

- 과거 적재된 해부학 배열을 canonical code 체계로 재정렬 완료
- 중복 신규 삽입 없이 기존 운동 데이터만 정제

---

## 2) 표준 계약 검증 (실제 API 호출)

실행 스크립트: `scripts/req30_anatomy_rpc_test.js`

### 2-1) `get_muscle_heatmap_status` 결과

- HTTP: `200`
- total muscles: `34`
- `invalidContractCount`: `0`

검증 조건:

- `muscle_code`가 `^[a-z0-9_]+$`를 만족
- `display_name_ko`가 placeholder 집합(`근육부위`, `근육 부위`, `기타 근육`, `Unknown`, `Other`, 공백)에 해당하지 않음

샘플:

- `quadriceps` / `대퇴사두근`
- `calves` / `종아리`

### 2-2) `muscles` 마스터 직접 검증

- total rows: `34`
- invalid rows: `0`

즉, 마스터 기준으로도 placeholder/비표준 코드 없음.

### 2-3) 가중치 계산 검증

동일 운동 로그 2건 삽입 후:

- 주동근(`quadriceps`) `fatigue_score=2.0`
- 협응근(`calves`) `fatigue_score=1.0`
- `primary > secondary` 검증 결과: `true`

---

## 3) 검색 회귀 검증

실행 스크립트: `scripts/req30_search_exercises_rpc_test.js`

- 영문/한글/초성 검색 정상 (모두 HTTP `200`)
- `LIMIT 20` 유지 확인
- 응답 필드 유지 확인:
  - `id`, `name`, `category`, `exercise_type`, `muscle_size`
  - `primary_muscles`, `secondary_muscles`

---

## 4) 프론트 fallback 0건 완료 기준 대응

완료 정의 대비 결과:

1. placeholder 미노출: 충족 (`invalidContractCount=0`)
2. `muscle_code` 누락/빈값 0건: 충족
3. 프론트 fallback 문자열 노출 원인 제거: 충족
   - 백엔드에서 `display_name_ko`를 표준값으로 강제 제공
   - 비표준/placeholder를 DB 제약 + 마스터 정제로 차단

---

## 5) 결론

요청사항에 따라 표준 근육 ID 체계 도입, placeholder 정리/차단, heatmap API 계약 강화, 데이터 재정렬, 실콜 검증까지 완료.
