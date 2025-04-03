import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

interface RequestBody {
  user_id: string;
}

serve(async (req) => {
  try {
    // Create a Supabase client with the auth admin role
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!
    const supabaseAnonKey = Deno.env.get('SUPABASE_ANON_KEY')!
    const supabaseServiceRole = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    
    // Create a client with admin privileges
    const supabaseAdmin = createClient(supabaseUrl, supabaseServiceRole)
    
    // Create a standard client for the authorized user
    const supabase = createClient(supabaseUrl, supabaseAnonKey)
    
    // Get the authorization header from the request
    const authHeader = req.headers.get('Authorization')
    if (!authHeader) {
      return new Response(
        JSON.stringify({ error: 'Authorization header missing' }),
        { status: 401, headers: { 'Content-Type': 'application/json' } }
      )
    }
    
    // Set the auth header for the Supabase client
    supabase.auth.setAuth(authHeader.replace('Bearer ', ''))
    
    // Parse the request body
    const body: RequestBody = await req.json()
    const userId = body.user_id
    
    if (!userId) {
      return new Response(
        JSON.stringify({ error: 'User ID is required' }),
        { status: 400, headers: { 'Content-Type': 'application/json' } }
      )
    }
    
    // Get the current session to verify the user is authorized
    const { data: { session }, error: sessionError } = await supabase.auth.getSession()
    
    if (sessionError || !session) {
      return new Response(
        JSON.stringify({ error: 'Unauthorized' }),
        { status: 401, headers: { 'Content-Type': 'application/json' } }
      )
    }
    
    // Only allow users to revoke their own tokens
    if (session.user.id !== userId) {
      return new Response(
        JSON.stringify({ error: 'Unauthorized' }),
        { status: 403, headers: { 'Content-Type': 'application/json' } }
      )
    }
    
    // Get user auth details from the admin client
    const { data: userData, error: userError } = await supabaseAdmin
      .from('auth.identities')
      .select('provider, identity_data')
      .eq('user_id', userId)
      .single()
    
    if (userError || !userData) {
      return new Response(
        JSON.stringify({ error: 'User not found', details: userError }),
        { status: 404, headers: { 'Content-Type': 'application/json' } }
      )
    }
    
    // Check if the user is an Apple user
    if (userData.provider !== 'apple') {
      return new Response(
        JSON.stringify({ message: 'Not an Apple user, no token to revoke' }),
        { status: 200, headers: { 'Content-Type': 'application/json' } }
      )
    }
    
    // Get Apple credentials from environment variables
    const clientId = Deno.env.get('APPLE_CLIENT_ID')
    const teamId = Deno.env.get('APPLE_TEAM_ID')
    const keyId = Deno.env.get('APPLE_KEY_ID')
    const privateKey = Deno.env.get('APPLE_PRIVATE_KEY')?.replace(/\\n/g, '\n')
    
    if (!clientId || !teamId || !keyId || !privateKey) {
      return new Response(
        JSON.stringify({ error: 'Apple credentials not configured' }),
        { status: 500, headers: { 'Content-Type': 'application/json' } }
      )
    }
    
    // Create JWT for Apple API
    const now = Math.floor(Date.now() / 1000)
    const jwt = await createJWT({
      clientId,
      teamId,
      keyId,
      privateKey,
      now
    })
    
    // Get the refresh token or sub value from identity data
    const { sub } = userData.identity_data
    
    if (!sub) {
      return new Response(
        JSON.stringify({ error: 'Apple user ID not found' }),
        { status: 400, headers: { 'Content-Type': 'application/json' } }
      )
    }
    
    // Call Apple's API to revoke the token
    const response = await fetch('https://appleid.apple.com/auth/revoke', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: new URLSearchParams({
        client_id: clientId,
        client_secret: jwt,
        token: sub,  // Using the user's Apple sub as the token
        token_type_hint: 'access_token'
      }).toString()
    })
    
    if (!response.ok) {
      const errorText = await response.text()
      return new Response(
        JSON.stringify({ 
          error: 'Failed to revoke Apple token', 
          status: response.status,
          details: errorText
        }),
        { status: 500, headers: { 'Content-Type': 'application/json' } }
      )
    }
    
    return new Response(
      JSON.stringify({ 
        message: 'Apple token successfully revoked',
        user_id: userId
      }),
      { status: 200, headers: { 'Content-Type': 'application/json' } }
    )
    
  } catch (error) {
    return new Response(
      JSON.stringify({ error: 'Internal server error', details: error.message }),
      { status: 500, headers: { 'Content-Type': 'application/json' } }
    )
  }
})

// Helper function to create a JWT for Apple
async function createJWT({ clientId, teamId, keyId, privateKey, now }: { 
  clientId: string;
  teamId: string;
  keyId: string;
  privateKey: string;
  now: number;
}) {
  // Create the JWT header
  const header = {
    alg: 'ES256',
    kid: keyId
  }
  
  // Create the JWT payload
  const payload = {
    iss: teamId,
    iat: now,
    exp: now + 3600,  // Token expires in 1 hour
    aud: 'https://appleid.apple.com',
    sub: clientId
  }
  
  // Encode the header and payload
  const encodedHeader = btoa(JSON.stringify(header))
    .replace(/\+/g, '-')
    .replace(/\//g, '_')
    .replace(/=+$/, '')
    
  const encodedPayload = btoa(JSON.stringify(payload))
    .replace(/\+/g, '-')
    .replace(/\//g, '_')
    .replace(/=+$/, '')
    
  // Create the signing input
  const signingInput = `${encodedHeader}.${encodedPayload}`
  
  // Create the signature using the private key
  const encoder = new TextEncoder()
  const data = encoder.encode(signingInput)
  
  // Import private key
  const algorithm = { name: 'ECDSA', namedCurve: 'P-256', hash: { name: 'SHA-256' } }
  const extractable = false
  const keyUsages = ['sign'] as const
  
  // Convert PEM to ArrayBuffer
  const pemHeader = '-----BEGIN PRIVATE KEY-----'
  const pemFooter = '-----END PRIVATE KEY-----'
  const pemContents = privateKey.substring(
    privateKey.indexOf(pemHeader) + pemHeader.length,
    privateKey.indexOf(pemFooter)
  ).replace(/\s/g, '')
  
  const binaryDer = atob(pemContents)
  const buffer = new ArrayBuffer(binaryDer.length)
  const bufView = new Uint8Array(buffer)
  
  for (let i = 0; i < binaryDer.length; i++) {
    bufView[i] = binaryDer.charCodeAt(i)
  }
  
  // Create key and sign
  const key = await crypto.subtle.importKey(
    'pkcs8',
    buffer,
    algorithm,
    extractable,
    keyUsages
  )
  
  const signature = await crypto.subtle.sign(
    algorithm,
    key,
    data
  )
  
  // Convert signature to base64
  const signatureBase64 = btoa(String.fromCharCode(...new Uint8Array(signature)))
    .replace(/\+/g, '-')
    .replace(/\//g, '_')
    .replace(/=+$/, '')
    
  // Return the complete JWT
  return `${signingInput}.${signatureBase64}`
} 