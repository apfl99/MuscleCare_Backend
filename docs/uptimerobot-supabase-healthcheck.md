# UptimeRobot 모니터링용 Supabase Edge Function 구축 가이드

## 1) 목적
- UptimeRobot Solo 플랜은 `apikey` 커스텀 헤더 추가가 불가하여 Supabase REST API 직접 호출 시 `401 Unauthorized`가 발생할 수 있습니다.
- 이를 우회하기 위해 JWT 인증이 필요 없는 전용 헬스체크 Edge Function(`health-check`)을 사용합니다.

## 2) 구현 위치
- 함수 파일: `supabase/functions/health-check/index.ts`
- 마이그레이션 파일: `supabase/migrations/20260419113000_create_health_check_probe.sql`
- 동작: 헬스체크 전용 테이블 `health_check_probe`에 경량 조회(`select('id').limit(1)`)를 수행해 DB 연결 상태를 확인하고 JSON 응답을 반환합니다.

## 3) 배포 전 DB 마이그레이션 적용
Edge Function이 참조하는 헬스체크 테이블을 먼저 생성합니다.

```bash
supabase db push
```

## 4) 배포 명령어 (필수)
아래 명령으로 배포해야 하며, `--no-verify-jwt` 플래그가 반드시 포함되어야 합니다.

```bash
supabase functions deploy health-check --no-verify-jwt
```

## 5) 최종 검수 체크리스트
1. **인증 비활성화 확인**
   - Supabase Dashboard > Edge Functions > `health-check`
   - `Enforce JWT`가 `Disabled`인지 확인
2. **UptimeRobot 모니터 설정**
   - URL: `https://[PROJECT_ID].functions.supabase.co/health-check`
   - Monitor Type: `HTTP(s)`
   - Authentication Type: `None`
   - HTTP Method: `GET`
3. **응답 확인**
   - 브라우저 또는 `curl`로 URL 호출 시 `{"status":"ok",...}` 응답 확인

```bash
curl -i "https://[PROJECT_ID].functions.supabase.co/health-check"
```

정상 예시:

```json
{"status":"ok","service":"supabase-db"}
```

## 6) 보안 유의사항
- 본 엔드포인트는 인증 없이 접근 가능하므로 헬스체크 목적 외 민감 로직/데이터를 포함하지 않습니다.
- `PROJECT_ID`는 Supabase 프로젝트의 `Reference ID`를 사용합니다.
