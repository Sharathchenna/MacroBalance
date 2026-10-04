// Creates an already-confirmed account for an @mbtest.ai address, so test
// sign-ups don't need (or send) a confirmation email. Only that domain is
// accepted. The free test subscription is granted in the app, and only in
// test builds, so accounts made here get no paid access in the App Store app.
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import { corsHeaders } from '../_shared/cors.ts';

const TEST_DOMAIN = '@mbtest.ai';

function json(body: Record<string, unknown>, status: number) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }
  if (req.method !== 'POST') {
    return json({ error: 'Method not allowed' }, 405);
  }

  let email: string, password: string, username: string;
  try {
    const body = await req.json();
    email = String(body.email ?? '').trim().toLowerCase();
    password = String(body.password ?? '');
    username = String(body.username ?? '').trim();
  } catch {
    return json({ error: 'Invalid JSON body' }, 400);
  }

  if (!email.endsWith(TEST_DOMAIN) || email.length <= TEST_DOMAIN.length) {
    return json({ error: `Only ${TEST_DOMAIN} addresses can use this` }, 403);
  }
  if (password.length < 6) {
    return json({ error: 'Password must be at least 6 characters' }, 400);
  }

  const supabaseAdmin = createClient(
    Deno.env.get('SUPABASE_URL') ?? '',
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
    { auth: { autoRefreshToken: false, persistSession: false } },
  );

  const { data, error } = await supabaseAdmin.auth.admin.createUser({
    email,
    password,
    email_confirm: true,
    user_metadata: { username, test_account: true },
  });

  if (error) {
    const exists = /already|registered|exists/i.test(error.message);
    return json(
      { error: exists ? 'This test email is already registered. Sign in instead.' : error.message },
      exists ? 409 : 400,
    );
  }

  console.log('Created test account', data.user?.id);
  return json({ user_id: data.user?.id }, 200);
});
