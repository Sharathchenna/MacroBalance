import { serve } from 'https://deno.land/std@0.177.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import { corsHeaders } from '../_shared/cors.ts';
import { GoogleGenerativeAI } from "npm:@google/generative-ai@0.2.1";

console.log('AI Food Search function starting...');

// Get Gemini API key from environment variables
const geminiApiKey = Deno.env.get('GEMINI_API_KEY');

if (!geminiApiKey) {
  console.error('GEMINI_API_KEY environment variable is missing');
}

// Supabase configuration
const supabaseUrl = Deno.env.get('SUPABASE_URL');
const supabaseAnonKey = Deno.env.get('SUPABASE_ANON_KEY');

if (!supabaseUrl || !supabaseAnonKey) {
  console.error('SUPABASE_URL or SUPABASE_ANON_KEY not found.');
}

interface AIFoodSearchRequest {
  query: string;
  max_results?: number;
}

interface AIFoodSuggestion {
  name: string;
  brand_name: string;
  calories: number;
  protein: number;
  carbohydrates: number;
  fat: number;
  fiber: number;
  serving_size: string;
  description: string;
}

async function generateFoodSuggestions(query: string, maxResults: number = 3): Promise<AIFoodSuggestion[]> {
  if (!geminiApiKey) {
    throw new Error('Gemini API key not configured');
  }

  const prompt = `You are a nutrition expert AI assistant. When given a food search query, generate realistic food suggestions with accurate nutritional information. Return only valid JSON in the exact format specified.

Rules:
1. Generate realistic food items that match the search query
2. Include accurate nutritional information per 100g serving
3. Provide helpful descriptions
4. Use "AI Generated" as brand_name
5. Ensure all nutritional values are realistic and accurate

Generate ${maxResults} food suggestions for: "${query}"

Response format (JSON only, no other text):
{
  "suggestions": [
    {
      "name": "Food Name",
      "brand_name": "AI Generated",
      "calories": 200,
      "protein": 15.0,
      "carbohydrates": 25.0,
      "fat": 8.0,
      "fiber": 3.0,
      "serving_size": "100g",
      "description": "Brief description of the food item"
    }
  ]
}`;

  try {
    // Initialize the Google Generative AI client
    const genAI = new GoogleGenerativeAI(geminiApiKey);
    
    // Get the Gemini 2.0 Flash model
    const model = genAI.getGenerativeModel({ model: "gemini-2.0-flash" });

    // Generate content
    const result = await model.generateContent(prompt);
    const response = await result.response;
    const text = response.text();
    
    if (!text) {
      throw new Error('No response from Gemini');
    }

    // Clean up the response - remove any code block markers
    const cleanedText = text.trim().replace(/```json/g, '').replace(/```/g, '');

    // Parse the JSON response
    const parsedResponse = JSON.parse(cleanedText);
    
    if (!parsedResponse.suggestions || !Array.isArray(parsedResponse.suggestions)) {
      throw new Error('Invalid response format from Gemini');
    }

    return parsedResponse.suggestions;

  } catch (error) {
    console.error('Error generating food suggestions:', error);
    throw error;
  }
}

serve(async (req: Request) => {
  // Handle CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    // Authentication
    if (!supabaseUrl || !supabaseAnonKey) {
      throw new Error('Supabase client configuration missing.');
    }

    const supabaseClient = createClient(supabaseUrl, supabaseAnonKey, {
      global: { headers: { Authorization: req.headers.get('Authorization')! } },
      auth: {
        autoRefreshToken: false,
        persistSession: false
      }
    });

    // Verify user authentication
    const { data: { user }, error: authError } = await supabaseClient.auth.getUser();

    if (authError || !user) {
      console.error('Auth Error:', authError);
      return new Response(JSON.stringify({ error: 'Unauthorized: Invalid token or user session.' }), {
        status: 401,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    console.log('User authenticated:', user.id);

    // Parse request body
    let requestData: AIFoodSearchRequest;
    try {
      requestData = await req.json() as AIFoodSearchRequest;
    } catch (e) {
      return new Response(JSON.stringify({ error: 'Invalid JSON body' }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    // Validate request
    if (!requestData.query || typeof requestData.query !== 'string') {
      return new Response(JSON.stringify({ error: 'Query parameter is required and must be a string' }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    const maxResults = requestData.max_results || 3;
    
    // Validate maxResults
    if (maxResults < 1 || maxResults > 10) {
      return new Response(JSON.stringify({ error: 'max_results must be between 1 and 10' }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    console.log(`Generating AI food suggestions for query: "${requestData.query}" with max_results: ${maxResults}`);

    // Generate food suggestions using Gemini
    const suggestions = await generateFoodSuggestions(requestData.query, maxResults);

    // Return the suggestions
    return new Response(JSON.stringify({ suggestions }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 200,
    });

  } catch (error) {
    console.error('Function Error:', error);
    return new Response(JSON.stringify({ 
      error: 'Internal server error', 
      details: error.message 
    }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }
});