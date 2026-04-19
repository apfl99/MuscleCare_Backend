import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

Deno.serve(async (_req) => {
  try {
    const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? ''
    const supabaseAnonKey = Deno.env.get('SUPABASE_ANON_KEY') ?? ''
    const supabase = createClient(supabaseUrl, supabaseAnonKey)

    // DB 연결 확인을 위한 경량 쿼리 (헬스체크 전용 테이블)
    const { error } = await supabase.from('health_check_probe').select('id').limit(1)
    if (error) {
      throw new Error(error.message)
    }

    return new Response(
      JSON.stringify({ status: 'ok', service: 'supabase-db' }),
      {
        status: 200,
        headers: { 'Content-Type': 'application/json' },
      },
    )
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err)

    return new Response(
      JSON.stringify({ status: 'error', message }),
      {
        status: 500,
        headers: { 'Content-Type': 'application/json' },
      },
    )
  }
})
