// // Follow this setup guide to integrate the Deno language server with your editor:
// // https://deno.land/manual/getting_started/setup_your_environment
// // This enables autocomplete, go to definition, etc.

// // Setup type definitions for built-in Supabase Runtime APIs
// import "jsr:@supabase/functions-js/edge-runtime.d.ts"

// console.log("Hello from Functions!")

// Deno.serve(async (req) => {
//   const { name } = await req.json()
//   const data = {
//     message: `Hello ${name}!`,
//   }

//   return new Response(
//     JSON.stringify(data),
//     { headers: { "Content-Type": "application/json" } },
//   )
// })

// /* To invoke locally:

//   1. Run `supabase start` (see: https://supabase.com/docs/reference/cli/supabase-start)
//   2. Make an HTTP request:

//   curl -i --location --request POST 'http://127.0.0.1:54321/functions/v1/process-withgemini' \
//     --header 'Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0' \
//     --header 'Content-Type: application/json' \
//     --data '{"name":"Functions"}'

// */

import { GoogleGenerativeAI, Part } from "npm:@google/generative-ai@0.2.1";
import { encodeBase64 } from "https://deno.land/std@0.220.1/encoding/base64.ts";

// Health score calculation function
function calculateHealthScore(calories: number, protein: number, carbohydrates: number, fat: number, fiber: number): number {
  if (calories <= 0) return 0;
  
  let score = 50.0; // Base score
  
  // Protein score (higher protein = better, up to +25 points)
  const proteinRatio = protein / calories * 100; // protein per 100 calories
  if (proteinRatio >= 10) {
    score += 25;
  } else if (proteinRatio >= 7) {
    score += 20;
  } else if (proteinRatio >= 5) {
    score += 15;
  } else if (proteinRatio >= 3) {
    score += 10;
  } else if (proteinRatio >= 1) {
    score += 5;
  }
  
  // Fiber score (higher fiber = better, up to +20 points)
  const fiberRatio = fiber / calories * 100; // fiber per 100 calories
  if (fiberRatio >= 5) {
    score += 20;
  } else if (fiberRatio >= 3) {
    score += 15;
  } else if (fiberRatio >= 2) {
    score += 10;
  } else if (fiberRatio >= 1) {
    score += 5;
  }
  
  // Calorie density penalty (high calorie density = penalty, up to -15 points)
  if (calories > 600) {
    score -= 15;
  } else if (calories > 400) {
    score -= 10;
  } else if (calories > 300) {
    score -= 5;
  }
  
  // Fat ratio consideration (moderate fat is good, too much is bad)
  const fatRatio = (fat * 9) / calories; // fat calories / total calories
  if (fatRatio > 0.5) { // More than 50% fat
    score -= 10;
  } else if (fatRatio > 0.35) { // More than 35% fat
    score -= 5;
  } else if (fatRatio >= 0.20 && fatRatio <= 0.35) { // 20-35% fat (optimal)
    score += 5;
  }
  
  // Ensure score is within bounds
  return Math.round(Math.max(0, Math.min(100, score)));
}

// Get API key from environment variables
// You'll need to set this with: supabase secrets set GEMINI_API_KEY=your-api-key
const apiKey = Deno.env.get("GEMINI_API_KEY");

if (!apiKey) {
  console.error("GEMINI_API_KEY environment variable is missing");
}

console.info("Gemini image analysis function started");

Deno.serve(async (req: Request) => {
  // Only allow POST requests
  if (req.method !== "POST") {
    return new Response(
      JSON.stringify({ error: "Method not allowed" }),
      { 
        status: 405,
        headers: { "Content-Type": "application/json" }
      }
    );
  }

  try {
    // Parse the multipart form data with the image
    const formData = await req.formData();
    const image = formData.get("image");
    
    // Validate image was provided
    if (!image || !(image instanceof File)) {
      return new Response(
        JSON.stringify({ error: "Image is required as a file" }),
        { 
          status: 400,
          headers: { "Content-Type": "application/json" }
        }
      );
    }

    console.log(`Received image: ${image.name}, type: ${image.type}, size: ${image.size}`);

    // Read image as bytes
    const imageBytes = new Uint8Array(await image.arrayBuffer());
    
    // Initialize the Google Generative AI client
    const genAI = new GoogleGenerativeAI(apiKey);
    
    // Get the Gemini model - using gemini-2.0-flash to match the Dart implementation
    const model = genAI.getGenerativeModel({ model: "gemini-2.0-flash" });

    // Define nutrition analysis prompt - updated to include health score
    const prompt = `
      Analyze the following meal and provide its nutritional content including health scores.
      if the image is a nutrition label, extract the nutrition information from the label and return response in the specified format, give correct nutrition values for different serving sizes, if given percentages then convert them into relavant values, do not provide null values if you couldn't get the number return 0.
      If the image is food, identify the food and provide the nutrition information for the meal.
      The meal can be a single food item or a combination of different foods.
      Break down the meal into different foods and do the nutrition analysis for each food.
      give nutrition info for each food in the meal with different serving sizes. the serving sizes can be in grams, ounces, tablespoons, teaspoons, cups etc.
      Return only the numerical values for calories, protein, carbohydrates, fat, fiber, and health_score.
      
      For health_score, calculate a score from 0-100 based on:
      - Higher protein content = better score (up to +25 points for 10+ grams protein per 100 calories)
      - Higher fiber content = better score (up to +20 points for 5+ grams fiber per 100 calories)  
      - Lower calorie density = better score (penalty for foods over 300-600 calories)
      - Balanced fat content = better score (20-35% of calories from fat is optimal)
      - Base score starts at 50, with adjustments applied
      
      Format the response in json exactly like this example, do not include any other information in the response, just the json object, not even the json title in the response.:
      meal: [
        {
          food: "food name 1",
          serving_size: ["serving size 1", "serving size 2", "serving size 3"],
          calories: [calories for serving 1, calories for serving 2, calories for serving 3],
          protein: [protein for serving 1, protein for serving 2, protein for serving 3],
          carbohydrates: [carbohydrates for serving 1, carbohydrates for serving 2, carbohydrates for serving 3],
          fat: [fat for serving 1, fat for serving 2, fat for serving 3],
          fiber: [fiber for serving 1, fiber for serving 2, fiber for serving 3],
          health_score: [health_score for serving 1, health_score for serving 2, health_score for serving 3]
        },
        {
          food: "food name 2",
          serving_size: ["serving size 1", "serving size 2", "serving size 3"],
          calories: [calories for serving 1, calories for serving 2, calories for serving 3],
          protein: [protein for serving 1, protein for serving 2, protein for serving 3],
          carbohydrates: [carbohydrates for serving 1, carbohydrates for serving 2, carbohydrates for serving 3],
          fat: [fat for serving 1, fat for serving 2, fat for serving 3],
          fiber: [fiber for serving 1, fiber for serving 2, fiber for serving 3],
          health_score: [health_score for serving 1, health_score for serving 2, health_score for serving 3]
        },
      ]
    `;
    
    // Determine the correct MIME type
    let mimeType = image.type;
    
    // If the MIME type is not set or is application/octet-stream, determine from filename
    if (!mimeType || mimeType === 'application/octet-stream') {
      const fileName = image.name?.toLowerCase() || '';
      if (fileName.endsWith('.jpg') || fileName.endsWith('.jpeg')) {
        mimeType = 'image/jpeg';
      } else if (fileName.endsWith('.png')) {
        mimeType = 'image/png';
      } else if (fileName.endsWith('.webp')) {
        mimeType = 'image/webp';
      } else if (fileName.endsWith('.gif')) {
        mimeType = 'image/gif';
      } else {
        // Default to jpeg since that's what the Flutter app compresses to
        mimeType = 'image/jpeg';
      }
    }
    
    console.log(`Using MIME type: ${mimeType}`);
    
    // Create parts for the request
    const imagePart: Part = {
      inlineData: {
        data: encodeBase64(imageBytes),
        mimeType: mimeType,
      },
    };
    
    const textPart: Part = {
      text: prompt,
    };
    
    // Generate content with the image and prompt
    const result = await model.generateContent({
      contents: [{ role: "user", parts: [textPart, imagePart] }],
    });
    
    const response = await result.response;
    const text = response.text();

    // Try to parse the response and add health scores if missing
    try {
      const parsed = JSON.parse(text);
      
      if (parsed.meal && Array.isArray(parsed.meal)) {
        for (const foodItem of parsed.meal) {
          // Check if health_score is missing or contains invalid values
          if (!foodItem.health_score || !Array.isArray(foodItem.health_score) || 
              foodItem.health_score.some((score: any) => score === null || score === undefined || isNaN(score))) {
            
            console.log(`Calculating health scores for ${foodItem.food}`);
            
            // Calculate health scores for each serving size
            const healthScores = [];
            for (let i = 0; i < foodItem.serving_size.length; i++) {
              const calories = foodItem.calories[i] || 0;
              const protein = foodItem.protein[i] || 0;
              const carbohydrates = foodItem.carbohydrates[i] || 0;
              const fat = foodItem.fat[i] || 0;
              const fiber = foodItem.fiber[i] || 0;
              
              const healthScore = calculateHealthScore(calories, protein, carbohydrates, fat, fiber);
              healthScores.push(healthScore);
            }
            
            foodItem.health_score = healthScores;
          }
        }
      }
      
      return new Response(
        JSON.stringify({ result: JSON.stringify(parsed) }),
        { 
          headers: { 
            "Content-Type": "application/json",
            "Connection": "keep-alive"
          } 
        }
      );
    } catch (parseError) {
      console.log("Could not parse Gemini response as JSON, returning raw response");
      
      return new Response(
        JSON.stringify({ result: text }),
        { 
          headers: { 
            "Content-Type": "application/json",
            "Connection": "keep-alive"
          } 
        }
      );
    }
  } catch (error: unknown) {
    console.error("Error processing image with Gemini:", error);
    const errorMessage = error instanceof Error ? error.message : "An unknown error occurred";
    return new Response(
      JSON.stringify({ error: `Error processing image: ${errorMessage}` }),
      { 
        status: 500, 
        headers: { "Content-Type": "application/json" }
      }
    );
  }
});