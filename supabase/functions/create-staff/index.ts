import { createClient } from 'jsr:@supabase/supabase-js@2';

const jsonHeaders = { 'Content-Type': 'application/json' };

Deno.serve(async (req) => {
  try {
    const { name, email, password, role, branch_id, salary } = await req.json();
    console.log('Received request:', { name, email, role, branch_id, salary });

    const authHeader = req.headers.get('Authorization')!;
    const callerClient = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_ANON_KEY')!,
      { global: { headers: { Authorization: authHeader } } }
    );

    const { data: { user }, error: userError } = await callerClient.auth.getUser();
    if (userError) console.error('getUser error:', userError.message);
    if (!user) {
      console.error('No user found from auth header');
      return new Response(JSON.stringify({ error: 'Not authenticated' }), { status: 401, headers: jsonHeaders });
    }

    const { data: callerStaff, error: staffLookupError } = await callerClient
      .from('staff')
      .select('role')
      .eq('id', user.id)
      .single();

    if (staffLookupError) console.error('Staff lookup error:', staffLookupError.message);
    console.log('Caller staff row:', callerStaff);

    if (callerStaff?.role !== 'admin') {
      console.error('Caller is not admin, role was:', callerStaff?.role);
      return new Response(JSON.stringify({ error: 'Only admins can create staff' }), { status: 403, headers: jsonHeaders });
    }

    const adminClient = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    );

    const { data: newUser, error: createError } = await adminClient.auth.admin.createUser({
      email,
      password,
      email_confirm: true,
    });

    if (createError) {
      console.error('createUser error:', createError.message);
      return new Response(JSON.stringify({ error: createError.message }), { status: 400, headers: jsonHeaders });
    }

    console.log('Created auth user:', newUser.user.id);

    const { error: staffError } = await adminClient.from('staff').insert({
      id: newUser.user.id,
      name,
      role,
      branch_id,
      salary,
      status: 'active',
    });

    if (staffError) {
      console.error('Staff insert error:', staffError.message);
      await adminClient.auth.admin.deleteUser(newUser.user.id);
      return new Response(JSON.stringify({ error: staffError.message }), { status: 400, headers: jsonHeaders });
    }

    console.log('Staff created successfully:', newUser.user.id);
    return new Response(JSON.stringify({ success: true, user_id: newUser.user.id }), { status: 200, headers: jsonHeaders });
  } catch (err) {
    console.error('Uncaught error:', err);
    return new Response(JSON.stringify({ error: String(err) }), { status: 500, headers: jsonHeaders });
  }
});
