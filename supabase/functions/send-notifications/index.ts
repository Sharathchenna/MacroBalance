// supabase/functions/send-notifications/index.ts
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { encode as encodeBase64Url } from 'https://deno.land/std@0.177.0/encoding/base64url.ts'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

// Custom function to create JWT token for Firebase
async function createFirebaseJWT(serviceAccountEmail: string, privateKey: string) {
  const now = Math.floor(Date.now() / 1000);
  const expiry = now + 3600; // 1 hour expiry
  
  const header = {
    alg: 'RS256',
    typ: 'JWT',
  };
  
  const payload = {
    iss: serviceAccountEmail,
    sub: serviceAccountEmail,
    aud: 'https://fcm.googleapis.com/',
    iat: now,
    exp: expiry,
    scope: 'https://www.googleapis.com/auth/firebase.messaging',
  };
  
  // Encode header and payload
  const headerBase64 = encodeBase64Url(new TextEncoder().encode(JSON.stringify(header)));
  const payloadBase64 = encodeBase64Url(new TextEncoder().encode(JSON.stringify(payload)));
  
  // Create signature base
  const signatureBase = `${headerBase64}.${payloadBase64}`;
  
  // Create signature using the private key
  const key = await crypto.subtle.importKey(
    'pkcs8',
    pemToArrayBuffer(privateKey),
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false,
    ['sign']
  );
  
  const signature = await crypto.subtle.sign(
    { name: 'RSASSA-PKCS1-v1_5' },
    key,
    new TextEncoder().encode(signatureBase)
  );
  
  // Encode signature to base64url
  const signatureBase64 = encodeBase64Url(new Uint8Array(signature));
  
  // Return complete JWT
  return `${signatureBase}.${signatureBase64}`;
}

// Helper function to convert PEM to ArrayBuffer
function pemToArrayBuffer(pem: string): ArrayBuffer {
  // Remove header, footer, and newlines
  const pemContents = pem
    .replace(/-----BEGIN PRIVATE KEY-----/, '')
    .replace(/-----END PRIVATE KEY-----/, '')
    .replace(/\n/g, '');
  
  // Decode base64 to binary
  const binaryString = atob(pemContents);
  const bytes = new Uint8Array(binaryString.length);
  
  for (let i = 0; i < binaryString.length; i++) {
    bytes[i] = binaryString.charCodeAt(i);
  }
  
  return bytes.buffer;
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const supabaseAdmin = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
      { global: { headers: { Authorization: req.headers.get('Authorization')! } } }
    )

    const { type, userId } = await req.json()
    
    // Get user's notification preferences
    const { data: preferences } = await supabaseAdmin
      .from('user_notification_preferences')
      .select('*')
      .eq('user_id', userId)
      .single()
    
    if (!preferences || 
        (type === 'meal_reminder' && !preferences.meal_reminders) || 
        (type === 'weekly_report' && !preferences.weekly_reports)) {
      return new Response(
        JSON.stringify({ success: false, message: 'Notifications disabled' }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }
    
    // Get user's FCM tokens
    const { data: tokens } = await supabaseAdmin
      .from('user_notification_tokens')
      .select('fcm_token')
      .eq('user_id', userId)
    
    if (!tokens || tokens.length === 0) {
      return new Response(
        JSON.stringify({ success: false, message: 'No tokens found' }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }
    
    // Prepare notification message
    let title, body
    if (type === 'meal_reminder') {
      title = 'Time to Log Your Meal'
      body = 'Don\'t forget to record what you\'ve eaten in MacroBalance!'
    } else if (type === 'weekly_report') {
      title = 'Weekly Nutrition Report'
      body = 'Check out your progress this week in meeting your nutrition goals!'
    } else {
      throw new Error('Invalid notification type')
    }
    
    // Get Firebase credentials from environment variables
    const serviceAccount = JSON.parse(Deno.env.get('FIREBASE_SERVICE_ACCOUNT') ?? '{}')
    
    // Generate access token for FCM API using our custom function
    const accessToken = await createFirebaseJWT(
      serviceAccount.client_email,
      serviceAccount.private_key
    )
    
    const successfulTokens = []
    const failedTokens = []
    
    // FCM v1 API endpoint
    const fcmEndpoint = `https://fcm.googleapis.com/v1/projects/${serviceAccount.project_id}/messages:send`
    
    for (const { fcm_token } of tokens) {
      const fcmPayload = {
        message: {
          token: fcm_token,
          notification: {
            title,
            body,
          },
          android: {
            notification: {
              sound: 'default',
              priority: 'HIGH',
              channel_id: 'meal_reminders',
            },
          },
          apns: {
            payload: {
              aps: {
                sound: 'default',
                badge: 1,
                content_available: true,
              },
            },
          },
          data: {
            type,
            click_action: 'FLUTTER_NOTIFICATION_CLICK',
          },
        },
      }
      
      try {
        const fcmResponse = await fetch(fcmEndpoint, {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            'Authorization': `Bearer ${accessToken}`,
          },
          body: JSON.stringify(fcmPayload),
        })
        
        if (fcmResponse.ok) {
          successfulTokens.push(fcm_token)
        } else {
          const errorData = await fcmResponse.json()
          failedTokens.push({ token: fcm_token, error: errorData })
          
          // If token is invalid, remove it
          if (errorData.error?.status === 'INVALID_ARGUMENT' || 
              errorData.error?.status === 'NOT_FOUND') {
            await supabaseAdmin
              .from('user_notification_tokens')
              .delete()
              .eq('fcm_token', fcm_token)
          }
        }
      } catch (error) {
        failedTokens.push({ token: fcm_token, error: error.message })
      }
    }
    
    return new Response(
      JSON.stringify({ 
        success: true, 
        sent: successfulTokens.length,
        failed: failedTokens.length
      }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
    
  } catch (error) {
    return new Response(
      JSON.stringify({ success: false, error: error.message }),
      { 
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
      }
    )
  }
})
