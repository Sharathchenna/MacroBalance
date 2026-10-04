import { serve } from 'https://deno.land/std@0.177.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import { corsHeaders } from '../_shared/cors.ts';
import { GoogleGenAI } from "npm:@google/genai@1.50.1";

// Same model across all AI functions.
const GEMINI_MODEL = 'gemini-3.1-flash-lite';

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

// Same shape the photo (process-withgemini) and Ask AI flows use, so the app
// can show every AI result in one screen with real serving options.
interface AIFoodItem {
  food: string;
  serving_size: string[];
  calories: number[];
  protein: number[];
  carbohydrates: number[];
  fat: number[];
  fiber: number[];
  description?: string;
}

// Legacy single-serving shape. Builds before 1.0.19 read only this, so it is
// still returned (derived from each item's first serving).
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

function toNumberArray(value: unknown, length: number): number[] {
  const arr = Array.isArray(value) ? value : [value];
  return Array.from({ length }, (_, i) => {
    const n = Number(arr[i] ?? arr[0] ?? 0);
    return Number.isFinite(n) ? n : 0;
  });
}

function normalizeItem(raw: Record<string, unknown>): AIFoodItem | null {
  const servings = (Array.isArray(raw.serving_size) ? raw.serving_size : [raw.serving_size])
    .filter((s) => typeof s === 'string' && s.trim().length > 0) as string[];
  const name = (raw.food ?? raw.name) as string | undefined;
  if (!name || servings.length === 0) return null;
  const n = servings.length;
  return {
    food: name,
    serving_size: servings,
    calories: toNumberArray(raw.calories, n),
    protein: toNumberArray(raw.protein, n),
    carbohydrates: toNumberArray(raw.carbohydrates, n),
    fat: toNumberArray(raw.fat, n),
    fiber: toNumberArray(raw.fiber, n),
    description: typeof raw.description === 'string' ? raw.description : undefined,
  };
}

function toLegacySuggestion(item: AIFoodItem): AIFoodSuggestion {
  return {
    name: item.food,
    brand_name: 'AI Generated',
    calories: item.calories[0],
    protein: item.protein[0],
    carbohydrates: item.carbohydrates[0],
    fat: item.fat[0],
    fiber: item.fiber[0],
    serving_size: item.serving_size[0],
    description: item.description ?? 'AI-generated food suggestion',
  };
}

async function generateFoodItems(query: string, maxResults: number = 3): Promise<AIFoodItem[]> {
  if (!geminiApiKey) {
    throw new Error('Gemini API key not configured');
  }

  const prompt = `You are a nutrition expert AI assistant. When given a food search query, generate realistic food suggestions with accurate nutritional information. Return only valid JSON in the exact format specified.

Rules:
1. Generate ${maxResults} realistic food items that match the search query.
2. For each food, give 2 to 4 serving sizes that suit that food, the way people actually eat it (for example "1 slice (35g)", "1 cup (240ml)", "1 medium (118g)"), and always include "100g". Factor in the user's description when choosing serving sizes, and put the most appropriate serving for what the user asked for first. Include the weight in grams in brackets where it makes sense.
3. Every nutrition array must have one value per serving size, in the same order. Use plain numbers, never null or arithmetic; use 0 if a value is truly unknown.
4. Provide a short, helpful description.
5. Ensure all nutritional values are real and accurate.
6. Do not hallucinate. If you are unsure about a food, think carefully, and do not return a wrong result.

Query: "${query}"

Response format (JSON only, no other text):
{
  "items": [
    {
      "food": "Food name",
      "serving_size": ["1 slice (35g)", "100g"],
      "calories": [90, 257],
      "protein": [3.1, 8.9],
      "carbohydrates": [17.0, 48.6],
      "fat": [1.1, 3.2],
      "fiber": [0.9, 2.7],
      "description": "One short sentence about the food"
    }
  ]
}`;

  try {
    const genAI = new GoogleGenAI({ apiKey: geminiApiKey });

    const result = await genAI.models.generateContent({
      model: GEMINI_MODEL,
      contents: prompt,
    });
    const text = result.text;

    if (!text) {
      throw new Error('No response from Gemini');
    }

    const cleanedText = text.trim().replace(/```json/g, '').replace(/```/g, '');
    const parsedResponse = JSON.parse(cleanedText);
    const rawItems = parsedResponse.items ?? parsedResponse.suggestions;

    if (!Array.isArray(rawItems)) {
      throw new Error('Invalid response format from Gemini');
    }

    return rawItems
      .map((raw: Record<string, unknown>) => normalizeItem(raw))
      .filter((item: AIFoodItem | null): item is AIFoodItem => item !== null)
      .slice(0, maxResults);
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
    const items = await generateFoodItems(requestData.query, maxResults);
    const suggestions = items.map(toLegacySuggestion);

    // Return the suggestions
    return new Response(JSON.stringify({ items, suggestions }), {
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