import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import { GoogleGenerativeAI } from "npm:@google/generative-ai@0.2.1";

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

console.log('Analyze Meal function starting...');

// Gemini sometimes writes arithmetic instead of numbers ("72*0.5"), which is
// not valid JSON. Evaluate simple a*b and a/b before parsing.
function evaluateSimpleArithmetic(json: string): string {
  return json.replace(/(\d+(?:\.\d+)?)\s*([*\/])\s*(\d+(?:\.\d+)?)/g, (match, a, op, b) => {
    const left = parseFloat(a);
    const right = parseFloat(b);
    if (op === '/' && right === 0) return match;
    const value = op === '*' ? left * right : left / right;
    return Number.isInteger(value) ? String(value) : value.toFixed(2);
  });
}

serve(async (req) => {
  // Handle CORS preflight requests
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    // Authentication (optional but recommended)
    const supabaseUrl = Deno.env.get('SUPABASE_URL');
    const supabaseAnonKey = Deno.env.get('SUPABASE_ANON_KEY');

    if (supabaseUrl && supabaseAnonKey) {
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
        return new Response(
          JSON.stringify({ error: 'Unauthorized' }),
          { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        );
      }

      console.log('User authenticated:', user.id);
    }

    // Parse request body
    const { meal } = await req.json();

    if (!meal || typeof meal !== 'string' || meal.trim() === '') {
      return new Response(
        JSON.stringify({ error: 'Meal description is required' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    console.log('Analyzing meal:', meal);

    // Get Gemini API key from environment variables
    const apiKey = Deno.env.get('GEMINI_API_KEY');
    if (!apiKey) {
      console.error('GEMINI_API_KEY is not set');
      throw new Error('API key not configured');
    }

    // Initialize Gemini AI
    const genAI = new GoogleGenerativeAI(apiKey);
    const model = genAI.getGenerativeModel({ model: 'gemini-2.0-flash' });

    // Create the prompt
    const prompt = `
Analyze the following meal description and extract all food items with their nutritional content.
Break the meal into individual food items. do not breakdown the meal into ingredients but rather into food items. for example, "turkey sandwich with avocado and cheese" should be broken down into "turkey sandwich", "avocado", and "cheese". another example is "a banana milkshake with chocolate syrup" should be broken down into "banana milkshake" and "chocolate syrup".
For each item provide:
1. The name of the food item
2. A list of serving sizes
3. Calories, protein, carbohydrates, fat, and fiber for each serving size

Return the response as a JSON list of objects with this structure:
[
  {
    "name": "Food name",
    "servingSizes": ["1 cup", "100g", etc.],
    "calories": [200, 150, etc.],
    "protein": [10, 7.5, etc.],
    "carbohydrates": [25, 18.75, etc.],
    "fat": [8, 6, etc.],
    "fiber": [3, 2.25, etc.]
  },
  {...}
]
Important note: Do not leave any trailing commas in the JSON response.
**Crucially, all numeric values in the arrays (calories, protein, etc.) MUST be calculated final numbers, not mathematical expressions (e.g., use 36, not 72*0.5).**
Make educated estimates for nutrition values if needed. If the meal is complex, break it down into its main components.
Ensure each food has at least two serving size options (e.g., "1 serving" and "100g").
Meal to analyze: ${meal}
`;

    // Generate content
    const result = await model.generateContent(prompt);
    const response = await result.response;
    const text = response.text();

    if (!text) {
      throw new Error('No response from Gemini');
    }

    console.log('Raw Gemini response:', text);

    // Extract JSON from response (in case there's any text around it)
    const jsonRegExp = /(\[[\s\S]*\])/;
    const match = jsonRegExp.exec(text);

    let jsonData;
    if (match) {
      const jsonString = match[1];
      console.log('Extracted JSON:', jsonString);
      
      // Parse to ensure valid JSON
      jsonData = JSON.parse(evaluateSimpleArithmetic(jsonString));
    } else {
      // Try parsing the entire response as JSON
      jsonData = JSON.parse(evaluateSimpleArithmetic(text));
    }

    // Return the parsed JSON data
    return new Response(
      JSON.stringify(jsonData),
      { 
        status: 200,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
      }
    );

  } catch (error) {
    console.error('Error in analyze-meal function:', error);
    return new Response(
      JSON.stringify({ 
        error: 'Failed to analyze meal',
        details: error.message 
      }),
      { 
        status: 500, 
        headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
      }
    );
  }
});