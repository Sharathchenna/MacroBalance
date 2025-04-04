import { serve } from 'https://deno.land/std@0.177.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import { corsHeaders } from '../_shared/cors.ts';

console.log('fatsecret-proxy function starting...');

// --- Interfaces ---
interface FatSecretProxyParams {
  endpoint: 'search' | 'autocomplete' | 'get'; // Add other endpoints as needed
  query: any; // Define more specific types based on endpoint (e.g., string for search/autocomplete, id for get)
  // Add other potential parameters your Flutter app might send
}

// --- Environment Variables & Secrets ---
// These secrets are automatically injected from Supabase Vault
const fatSecretClientId = Deno.env.get('FATSECRET_CLIENT_ID');
const fatSecretClientSecret = Deno.env.get('FATSECRET_CLIENT_SECRET');

if (!fatSecretClientId || !fatSecretClientSecret) {
  console.error('FATSECRET_CLIENT_ID or FATSECRET_CLIENT_SECRET not found in environment variables/Vault.');
  // Consider throwing an error or returning a specific status in a real scenario
}

// --- FatSecret API Configuration ---
const FATSECRET_TOKEN_URL = 'https://oauth.fatsecret.com/connect/token';
const FATSECRET_API_BASE_URL = 'https://platform.fatsecret.com/rest/server.api'; // Note: REST API base, adjust if using different endpoints

// --- Supabase Client (for Auth) ---
// Use anon key and URL from environment - these are safe to expose
// You might need to set these in your function's environment variables via Supabase dashboard/CLI if not automatically injected
const supabaseUrl = Deno.env.get('SUPABASE_URL');
const supabaseAnonKey = Deno.env.get('SUPABASE_ANON_KEY');

if (!supabaseUrl || !supabaseAnonKey) {
    console.error('SUPABASE_URL or SUPABASE_ANON_KEY not found.');
    // Handle error appropriately
}


// --- FatSecret Token Helper ---
async function getFatSecretAccessToken(): Promise<string> {
  if (!fatSecretClientId || !fatSecretClientSecret) {
    throw new Error('FatSecret credentials missing in environment.');
  }

  const credentials = btoa(`${fatSecretClientId}:${fatSecretClientSecret}`); // Base64 encode credentials

  try {
    const response = await fetch(FATSECRET_TOKEN_URL, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
        'Authorization': `Basic ${credentials}`,
      },
      // Request 'premier' scope instead of 'basic'
      body: 'grant_type=client_credentials&scope=premier',
    });

    if (!response.ok) {
      const errorBody = await response.text();
      console.error(`FatSecret Token Error (${response.status}): ${errorBody}`);
      throw new Error(`Failed to get FatSecret token: ${response.statusText}`);
    }

    const data = await response.json();
    if (!data.access_token) {
        console.error('FatSecret Token Response missing access_token:', data);
        throw new Error('FatSecret token response did not contain access_token.');
    }

    console.log('Successfully obtained FatSecret access token.');
    return data.access_token;

  } catch (error) {
    console.error('Error fetching FatSecret token:', error);
    throw error; // Re-throw the error to be caught by the main handler
  }
}


serve(async (req: Request) => {
  // --- CORS Preflight ---
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    // --- Authentication ---
    if (!supabaseUrl || !supabaseAnonKey) {
        throw new Error('Supabase client configuration missing.');
    }
    const supabaseClient = createClient(supabaseUrl, supabaseAnonKey, {
        global: { headers: { Authorization: req.headers.get('Authorization')! } },
        auth: {
            // Required to prevent auto-refreshing sessions, crucial for server-side/edge functions
            autoRefreshToken: false,
            persistSession: false
        }
    });

    // Get user session from Authorization header
    const { data: { user }, error: authError } = await supabaseClient.auth.getUser();

    if (authError || !user) {
      console.error('Auth Error:', authError);
      return new Response(JSON.stringify({ error: 'Unauthorized: Invalid token or user session.' }), {
        status: 401,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }
    console.log('User authenticated:', user.id);

    // --- Request Body Parsing ---
    let params: FatSecretProxyParams;
    if (req.body) {
        try {
            // Use type assertion after parsing
            params = await req.json() as FatSecretProxyParams;
        } catch (e) {
            return new Response(JSON.stringify({ error: 'Invalid JSON body' }), {
                status: 400,
                headers: { ...corsHeaders, 'Content-Type': 'application/json' },
            });
        }
    } else {
         return new Response(JSON.stringify({ error: 'Request body required' }), {
            status: 400,
            headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        });
    }

    // --- TODO: FatSecret Logic ---
    // 1. Get FatSecret Access Token
    //    - TODO: Implement caching for the token to avoid requesting it on every function invocation.
    const fatSecretAccessToken = await getFatSecretAccessToken();

    // 2. Determine which FatSecret API endpoint to call based on `params`
    //    (e.g., search, autocomplete, get food details)
    const endpointToCall = params?.endpoint; // Use optional chaining for safety
    const queryParams = params?.query; // Use optional chaining for safety

    // Add more robust validation based on the expected structure for each endpoint
    if (!endpointToCall || !queryParams) {
         return new Response(JSON.stringify({ error: 'Missing required parameters: endpoint and query' }), {
            status: 400,
            headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        });
    }

    // 3. Construct and execute the request to the FatSecret API
    //    - Use FATSECRET_API_BASE_URL
    //    - Add the obtained `fatSecretAccessToken` to the Authorization header (Bearer token).
    //    - Pass necessary parameters based on the `endpointToCall` and `queryParams`.

    console.log(`Calling FatSecret endpoint: ${endpointToCall} with query: ${queryParams}`);

    // --- TODO: Implement actual FatSecret API call logic ---
    // Example structure - replace with actual fetch calls based on FatSecret docs
    let fatSecretResponseData;
    const fatSecretApiUrl = new URL(FATSECRET_API_BASE_URL); // Use the correct base URL

    // Common parameters for FatSecret REST API
    fatSecretApiUrl.searchParams.set('format', 'json');

    switch (endpointToCall) {
        case 'search':
            fatSecretApiUrl.searchParams.set('method', 'foods.search.v3'); // Use v3 search
            fatSecretApiUrl.searchParams.set('search_expression', queryParams as string);
            fatSecretApiUrl.searchParams.set('flag_default_serving', 'true');
            // Add other search parameters as needed (e.g., page_number, max_results)
            break;
        case 'autocomplete':
             // Corrected method name based on FatSecret API structure
             fatSecretApiUrl.searchParams.set('method', 'foods.autocomplete');
             fatSecretApiUrl.searchParams.set('expression', queryParams as string);
             break;
        case 'get':
            fatSecretApiUrl.searchParams.set('method', 'food.get.v4'); // Use v4 get
            fatSecretApiUrl.searchParams.set('food_id', queryParams as string); // Assuming query is the food_id for 'get'
            break;
        default:
            return new Response(JSON.stringify({ error: `Unsupported endpoint: ${endpointToCall}` }), {
                status: 400,
                headers: { ...corsHeaders, 'Content-Type': 'application/json' },
            });
    }

    try {
        console.log(`Fetching from FatSecret URL: ${fatSecretApiUrl.toString()}`);
        const apiResponse = await fetch(fatSecretApiUrl.toString(), {
            method: 'GET', // Or POST depending on the FatSecret method
            headers: {
                'Authorization': `Bearer ${fatSecretAccessToken}`,
            },
        });

        if (!apiResponse.ok) {
            const errorBody = await apiResponse.text();
            console.error(`FatSecret API Error (${apiResponse.status}) for ${endpointToCall}: ${errorBody}`);
            throw new Error(`FatSecret API request failed: ${apiResponse.statusText}`);
        }

        fatSecretResponseData = await apiResponse.json();
        console.log(`Successfully received data from FatSecret for ${endpointToCall}.`);

    } catch (apiError) {
        console.error(`Error calling FatSecret API for ${endpointToCall}:`, apiError);
        // Return a specific error response
         return new Response(JSON.stringify({ error: `Failed to call FatSecret API: ${apiError.message}` }), {
            status: 502, // Bad Gateway might be appropriate
            headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        });
    }

    // --- Return Response ---
    return new Response(JSON.stringify(fatSecretResponseData), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 200,
    });

  } catch (error) {
    console.error('Internal Function Error:', error);
    return new Response(JSON.stringify({ error: error.message || 'Internal Server Error' }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }
});
