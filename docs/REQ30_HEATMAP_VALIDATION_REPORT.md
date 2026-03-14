# REQ-30 API 검증 리포트 (배포 완료)

검증 일시: 2026-03-01 (KST 기준)

대상 환경:

- Project URL: `https://ialgqpzyysctbtqrwyqq.supabase.co`
- Publishable Key: `sb_publishable_tBWvZfUGmzEP9BJWcZCKMA_wFIXV6N1`

---

## 1) 배포 실행 결과

실행 순서:

1. `supabase link --project-ref ialgqpzyysctbtqrwyqq --password <제공 토큰>`
2. `supabase db push --include-all`로 마이그레이션 적용
3. Seed 마이그레이션 재적용(매핑 보정)

최종 마이그레이션 상태:

- `20260301033039_req30_heatmap_schema.sql` 적용 완료
- `20260301033216_req30_heatmap_seed.sql` 적용 완료

참고:

- Seed 내부 CTE 스냅샷 특성으로 최초 1회에서 `exercise_muscle_mapping`이 비어 있었고,
  동일 Seed를 재적용해 매핑(885건)을 정상 반영함.
- 이후 로컬 Seed SQL은 최초 실행에서도 매핑이 바로 채워지도록 보정함.

---

## 2) 데이터 검증 결과 (REST 실측)

`Prefer: count=exact` 기준:

- `muscles`: **27**
- `exercises`: **250**
- `exercise_muscle_mapping`: **885**
- `workout_logs`: **0** (검증 종료 후 정리 완료)

검증 예시:

```text
HTTP/2 206
content-range: 0-0/27
```

```text
HTTP/2 206
content-range: 0-0/250
```

```text
HTTP/2 206
content-range: 0-0/885
```

---

## 3) RPC 실환경 검증 결과

검증 절차(실제 수행):

1. Admin API로 테스트 유저 생성(이메일 confirm true)
2. Password grant로 사용자 JWT 발급
3. `workout_logs` 2건 삽입
   - 가슴 운동: 2시간 전 (red 유도)
   - 이두 운동: 30시간 전 (yellow 유도)
4. RPC 호출
5. 테스트 로그/유저 정리

### 3-1) Happy Path

요청: 사용자 JWT + `p_user_id=<본인 id>`

결과:

- HTTP `200`
- 반환 아이템 수: `27`
- 샘플 상태:
  - `chest`: `red`
  - `front_deltoid`: `red`
  - `triceps`: `red`
  - `biceps`: `yellow`
  - `quadriceps`: `green`

### 3-2) 권한 위반 Path

요청: 사용자 JWT + `p_user_id=<타인 uuid>`

결과:

- HTTP `403`
- 에러:
  - `code`: `42501`
  - `message`: `forbidden: you can only request your own heatmap`

### 3-3) 비정상 토큰 Path

요청: publishable key를 bearer로 전달

결과:

- HTTP `401`
- 접근 거부 응답 확인

---

## 4) 정리

- REQ-30 스키마/인덱스/RLS/RPC 배포 **완료**
- 대규모 Seed(250 운동, 27 근육, 885 매핑) 반영 **완료**
- 실제 Supabase REST/RPC 기준 동작 검증 및 정리(cleanup) **완료**

