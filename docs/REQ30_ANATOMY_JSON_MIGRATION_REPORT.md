# REQ30 해부학 JSON 마이그레이션 검증 보고서

- 작성일(UTC): 2026-03-08
- 대상 프로젝트: `https://ialgqpzyysctbtqrwyqq.supabase.co`
- 적용 마이그레이션: `20260305142000_req30_anatomy_json_upgrade.sql`
- 데이터 소스: `exercises.json` (873건)

---

## 1) 배포 결과

`supabase db push` 기준 신규 마이그레이션 적용 완료.

- `primary_muscles text[]`
- `secondary_muscles text[]`
- `biomechanics_note text`
- `search_exercises` 반환 필드 확장
- `get_muscle_heatmap_status` 가중치 기반 계산 전환

---

## 2) JSON 업서트 실행 결과

실행 스크립트: `scripts/req30_anatomy_json_upsert.js`

실행 결과:

- source total: `873`
- existing before: `250`
- updated existing: `50`
- inserted new: `823`
- skipped: `0`

반영 후 데이터 스냅샷(REST count):

- `exercises` 총 건수: `1073`
- `primary_muscles <> '{}'` 건수: `873`
- `secondary_muscles <> '{}'` 건수: `601`

매핑 규칙:

- 기존 행 매칭: `exercise_name_ko`/`exercise_name_en`/`name` → `exercises.name` (대소문자 무시)
- 기존 운동: 신규 해부학 컬럼(`primary_muscles`, `secondary_muscles`, `biomechanics_note`)만 업데이트
- 신규 운동: `slug`, `name`, `category`, `equipment`, `exercise_type`, `muscle_size` 기본값을 채워 삽입

---

## 3) RPC 검증 결과

검증 스크립트: `scripts/req30_anatomy_rpc_test.js`

### 3-1) `search_exercises`

- HTTP: `200`
- 반환 키 확인:
  - `id`, `name`, `category`, `exercise_type`, `muscle_size`
  - `primary_muscles`, `secondary_muscles`
- 샘플:
  - `Squat Jerk`
  - `primary_muscles=["quadriceps"]`
  - `secondary_muscles=["calves","glutes","hamstrings","shoulders","triceps"]`

### 3-2) `get_muscle_heatmap_status`

테스트 조건:

- 동일 운동 로그 2건 삽입
- 주동근 가중치 1.0, 협응근 0.5 기준으로 점수 비교

결과:

- 주동근(`quadriceps`): `fatigue_score=2.0`, `status=red`
- 협응근(`calves`): `fatigue_score=1.0`, `status=yellow`
- 검증: `primary score > secondary score` = `true`

---

## 4) 회귀 테스트 결과

검증 스크립트: `scripts/req30_search_exercises_rpc_test.js`

- 한글/초성/영문 검색 정상 (`HTTP 200`)
- `LIMIT 20` 유지
- 응답 필드 확장 후에도 기존 검색 흐름 유지

---

## 5) 결론

요청사항 기준으로 무중단 방식의 해부학 JSON 마이그레이션, 스키마 확장, RPC 고도화, 문서 업데이트, 실 API 테스트까지 완료.
