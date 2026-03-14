# REQ-30 V2 스키마 고도화 검증 보고서

- 작성일(UTC): 2026-03-05T13:40:45Z
- 대상 프로젝트: `https://ialgqpzyysctbtqrwyqq.supabase.co`
- 대상 마이그레이션: `20260301070000_req30_v2_cardio_weight_split.sql`
- 검증 스크립트: `scripts/req30_v2_cardio_weight_test.js`

---

## 1) 배포 결과

`supabase db push`로 신규 마이그레이션 적용 완료.

- 로컬/원격 마이그레이션 일치 확인:
  - `20260301033039`
  - `20260301033216`
  - `20260301034500`
  - `20260301052000`
  - `20260301070000` (신규)

---

## 2) 스키마 변경 검증

### 2-1) `exercises` 컬럼 확장

- 추가/반영 컬럼
  - `exercise_type` (`cardio` | `weight`)
  - `muscle_size` (`large` | `small`)
- 샘플 조회 결과(HTTP 200):
  - `Assault Bike Sprint` → `exercise_type=cardio`, `muscle_size=large`
  - `Ab Wheel Rollout` → `exercise_type=weight`, `muscle_size=small`

### 2-2) `workout_logs` 컬럼 유연화

- `sets`, `reps`, `weight_kg` nullable 처리 유지/강화
- `distance_km numeric(8,3)` 추가
- `duration_minutes`/`distance_km` 양수/비음수 제약 보장

---

## 3) 비즈니스 무결성 검증 (DB Trigger)

검증 대상 Trigger: `validate_workout_log_payload_by_exercise_type`

### 3-1) 성공 케이스

1. 유산소 로그 입력 (HTTP 201)
   - payload: `duration_minutes=32`, `distance_km=5.1`, `sets/reps/weight_kg=null`
   - 결과: 저장 성공
2. 무산소 로그 입력 (HTTP 201)
   - payload: `sets=4`, `reps=10`, `weight_kg=40`, `duration_minutes=null`
   - 결과: 저장 성공

### 3-2) 실패 케이스

1. 유산소 로그에서 `duration_minutes` 누락
   - HTTP 400
   - 오류: `cardio logs require duration_minutes`
2. 무산소 로그에서 `sets` 누락
   - HTTP 400
   - 오류: `weight logs require sets and reps`

---

## 4) `search_exercises` RPC 검증

### 4-1) 응답 스키마 검증

- 호출: `POST /rest/v1/rpc/search_exercises`
- 요청 바디: `{"p_keyword":"스쿼트"}`
- HTTP 200
- 첫 결과 필드:
  - `id`
  - `name`
  - `category`
  - `exercise_type`
  - `muscle_size`

### 4-2) 실측 예시

- 키워드 `스쿼트`
  - 응답 시간: `429.74ms`
  - 결과 수: `12`
  - 첫 결과: `Back Squat / weight / large`
- 키워드 `bike`
  - 응답 시간: `96.55ms`
  - 결과 수: `1`
  - 첫 결과: `Assault Bike Sprint / cardio / large`

---

## 5) 프론트엔드 반영 지시사항

1. 운동 검색 자동완성 모델을 아래 필드로 갱신:
   - `id`, `name`, `category`, `exercise_type`, `muscle_size`
2. 기록 저장 payload 규칙 반영:
   - 유산소(`exercise_type=cardio`): `duration_minutes` 필수
   - 무산소(`exercise_type=weight`): `sets`/`reps` 필수
3. 유산소는 `distance_km`를 함께 보내도록 UI 제공(선택 입력 가능).
4. 로그 생성 시 `user_id = auth.uid()` 유지(RLS 충돌 방지).
5. DB 제약 위반(HTTP 400) 시 메시지를 그대로 사용자에게 안내:
   - `cardio logs require duration_minutes`
   - `weight logs require sets and reps`

---

## 6) 결론

요청된 V2 요구사항(유산소/무산소 분리, muscle size 메타데이터, 로그 유연화, 검색 RPC 확장, 문서 갱신)은 원격 배포 및 실제 API 호출 기준으로 검증 완료.
