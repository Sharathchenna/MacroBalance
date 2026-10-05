import { serve } from 'https://deno.land/std@0.177.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

// Define CORS headers
const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

// Get the Resend API key from environment variables (Supabase secrets)
const RESEND_API_KEY = Deno.env.get('RESEND_API_KEY');
const FROM_EMAIL = 'verify@transactions.macrobalance.app'; // Replace with your verified domain

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

    // Initialize Supabase client with Admin privileges to access auth API
    const supabaseAdmin = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
    );

    // Parse request body
    const { email, confirmation_url } = await req.json();

    // Basic validation
    if (!email) {
      return new Response(JSON.stringify({ error: 'Email is required.' }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    // Generate verification URL for deep linking to the app
    // Make sure to use the proper deep link format
    const verificationUrl = confirmation_url || 
      `io.supabase.macrotracker://verify-email?email=${encodeURIComponent(email)}`;

    // Construct email payload for Resend API with improved HTML
    const payload = {
      from: FROM_EMAIL,
      to: [email],
      subject: 'Verify your MacroBalance account',
      html: `
        <!DOCTYPE html>
        <html>
        <head>
          <meta charset="utf-8">
          <meta name="viewport" content="width=device-width, initial-scale=1">
          <title>Verify your MacroBalance account</title>
          <style>
            body { 
              font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif;
              line-height: 1.6;
              color: #333;
              max-width: 600px;
              margin: 0 auto;
              padding: 20px;
            }
            .button {
              background-color: #4CAF50;
              color: white !important;
              padding: 12px 30px;
              text-decoration: none;
              border-radius: 4px;
              font-weight: 600;
              display: inline-block;
              margin: 20px 0;
            }
            .container {
              background-color: #ffffff;
              border-radius: 8px;
              box-shadow: 0 2px 4px rgba(0, 0, 0, 0.1);
              padding: 30px;
              margin-top: 20px;
            }
            .footer {
              font-size: 12px;
              color: #666;
              margin-top: 30px;
              text-align: center;
            }
          </style>
        </head>
        <body>
          <div class="container">
            <h2>Verify Your Email Address</h2>
            <p>Thank you for creating a MacroBalance account. To complete your registration, please verify your email address by clicking the button below:</p>
            
            <div style="text-align: center;">
              <a href="${verificationUrl}" class="button">Verify Email Address</a>
            </div>
            
            <p>If the button above doesn't work, you can copy and paste the following link into your browser:</p>
            <p><a href="${verificationUrl}">${verificationUrl}</a></p>
            
            <p>If you didn't create an account with us, you can safely ignore this email.</p>
            
            <p>Best regards,<br>The MacroBalance Team</p>
          </div>
          
          <div class="footer">
            <p>This email was sent by MacroBalance. Please do not reply to this message.</p>
          </div>
        </body>
        </html>
      `,
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
      throw new Error(`Failed to send verification email: ${errorData.message || resendResponse.statusText}`);
    }

    // Return success response
    return new Response(JSON.stringify({ message: 'Verification email sent successfully!' }), {
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