import { serve } from 'https://deno.land/std@0.177.0/http/server.ts';

// Define CORS headers directly
const corsHeaders = {
  'Access-Control-Allow-Origin': '*', // Or restrict to your app's domain e.g. 'https://yourapp.com'
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

// Get the Resend API key from environment variables (Supabase secrets)
const RESEND_API_KEY = Deno.env.get('RESEND_API_KEY');
const TO_EMAIL = 'trixoft@icloud.com'; // Your destination email

serve(async (req) => {
  // Handle CORS preflight request
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    // Ensure API key is available
    if (!RESEND_API_KEY) {
      throw new Error('Resend API key is not configured.');
    }

    // Parse request body
    const { email, message } = await req.json();

    // Basic validation
    if (!email || !message) {
      return new Response(JSON.stringify({ error: 'Email and message are required.' }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    // Construct email payload for Resend API
    const payload = {
      from: 'MacroTracker Support <support@macrobalance.trixoft.com>', // Replace with a verified sender domain in Resend
      to: [TO_EMAIL],
      subject: `Support Request from ${email}`,
      html: `<p><strong>From:</strong> ${email}</p><p><strong>Message:</strong></p><p>${message.replace(/\n/g, '<br>')}</p>`,
      reply_to: email, // Set the reply-to field to the user's email
    };

    // Call Resend API
    const resendResponse = await fetch('https://api.resend.com/emails', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${RESEND_API_KEY}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(payload),
    });

    // Check Resend response
    if (!resendResponse.ok) {
      const errorData = await resendResponse.json();
      console.error('Resend API Error:', errorData);
      throw new Error(`Failed to send email: ${errorData.message || resendResponse.statusText}`);
    }

    // Return success response
    return new Response(JSON.stringify({ message: 'Email sent successfully!' }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 200,
    });

  } catch (error) {
    console.error('Function Error:', error);
    return new Response(JSON.stringify({ error: error.message }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 500,
    });
  }
});

/*
Note on `from` address:
- You MUST replace 'support@yourdomain.com' with an email address from a domain you have verified with Resend.
- Sending emails from unverified domains will likely fail or go to spam.
- Check your Resend dashboard under "Domains" to add and verify your sending domain.
*/

/*
Note on CORS:
- The `../_shared/cors.ts` import assumes you have a standard CORS setup for your Supabase functions.
- If you don't, you can replace `corsHeaders` with a basic set like:
  const corsHeaders = {
    'Access-Control-Allow-Origin': '*', // Or restrict to your app's domain
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  };
- Make sure your `supabase/config.toml` also allows the function to be called publicly if needed, or configure appropriate auth.
*/
