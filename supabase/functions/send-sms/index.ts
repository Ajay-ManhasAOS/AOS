import { createClient } from 'jsr:@supabase/supabase-js@2';

const jsonHeaders = { 'Content-Type': 'application/json' };

Deno.serve(async (req) => {
  try {
    const { to } = await req.json();
    console.log('Received SMS request for:', to);

    const authHeader = req.headers.get('Authorization')!;
    const callerClient = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_ANON_KEY')!,
      { global: { headers: { Authorization: authHeader } } }
    );

    const { data: { user } } = await callerClient.auth.getUser();
    if (!user) {
      return new Response(JSON.stringify({ error: 'Not authenticated' }), { status: 401, headers: jsonHeaders });
    }

    const { data: callerStaff } = await callerClient
      .from('staff')
      .select('role')
      .eq('id', user.id)
      .single();

    if (!callerStaff) {
      return new Response(JSON.stringify({ error: 'Staff record not found' }), { status: 403, headers: jsonHeaders });
    }

    if (!to) {
      return new Response(JSON.stringify({ error: 'Missing "to" phone number' }), { status: 400, headers: jsonHeaders });
    }

    const apiKey = Deno.env.get('SPRINGEDGE_API_KEY')!;
    const sender = Deno.env.get('SPRINGEDGE_SENDER_ID')!;
    // Trial tier only allows this exact fixed message text.
    const message = 'Hello, this is a test message from spring edge';

    const url = `https://instantalerts.co/api/web/send?apikey=${apiKey}&sender=${sender}&to=${to}&message=${encodeURIComponent(message)}`;
    const smsResponse = await fetch(url);
    const resultText = await smsResponse.text();

    console.log('SpringEdge response:', resultText);

    return new Response(JSON.stringify({ success: true, providerResponse: resultText }), { status: 200, headers: jsonHeaders });
  } catch (err) {
    console.error('Uncaught error:', err);
    return new Response(JSON.stringify({ error: String(err) }), { status: 500, headers: jsonHeaders });
  }
});
