import { createClient } from 'jsr:@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};
const jsonHeaders = { ...corsHeaders, 'Content-Type': 'application/json' };
const reply = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: jsonHeaders });

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });
  try {
    const { staff_id, new_password } = await req.json();

    const authHeader = req.headers.get('Authorization') ?? '';
    const callerClient = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_ANON_KEY')!,
      { global: { headers: { Authorization: authHeader } } }
    );

    const { data: { user } } = await callerClient.auth.getUser();
    if (!user) return reply({ error: 'Not authenticated' }, 401);

    const { data: callerStaff } = await callerClient
      .from('staff').select('role').eq('id', user.id).single();
    if (callerStaff?.role !== 'admin') {
      return reply({ error: 'Only admins can reset passwords' }, 403);
    }

    if (!staff_id) return reply({ error: 'staff_id missing' }, 400);
    if (!new_password || String(new_password).length < 6) {
      return reply({ error: 'Password must be at least 6 characters' }, 400);
    }

    const adminClient = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    );

    // Target must be one of our staff
    const { data: target } = await adminClient
      .from('staff').select('id').eq('id', staff_id).single();
    if (!target) return reply({ error: 'Staff member not found' }, 404);

    const { error } = await adminClient.auth.admin.updateUserById(staff_id, {
      password: String(new_password),
    });
    if (error) return reply({ error: error.message }, 400);

    return reply({ success: true });
  } catch (err) {
    console.error('Uncaught error:', err);
    return reply({ error: String(err) }, 500);
  }
});
