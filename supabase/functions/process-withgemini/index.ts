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

    // Read image as bytes
    const imageBytes = new Uint8Array(await image.arrayBuffer());
    
    // Initialize the Google Generative AI client
    const genAI = new GoogleGenerativeAI(apiKey);
    
    // Get the Gemini model - using gemini-2.0-flash to match the Dart implementation
    const model = genAI.getGenerativeModel({ model: "gemini-2.0-flash" });

    // Define nutrition analysis prompt - same as in the Dart implementation
    const prompt = `
      Analyze the following meal and provide its nutritional content.
      Break down the meal into different foods and do the nutrition analysis for each food.
      give nutrition info for each food in the meal with different serving sizes. the serving sizes can be in grams, ounces, tablespoons, teaspoons, cups etc.
      Return only the numerical values for calories, protein, carbohydrates, fat, and fiber.
      Format the response in json exactly like this example, do not include any other information in the response, just the json object, not even the json title in the response.:
      meal: [
        {
          food: "food name 1",
          serving_size: ["serving size 1", "serving size 2", "serving size 3"],
          calories: [calories for serving 1, calories for serving 2, calories for serving 3],
          protein: [protein for serving 1, protein for serving 2, protein for serving 3],
          carbohydrates: [carbohydrates for serving 1, carbohydrates for serving 2, carbohydrates for serving 3],
          fat: [fat for serving 1, fat for serving 2, fat for serving 3],
          fiber: [fiber for serving 1, fiber for serving 2, fiber for serving 3]
        },
        {
          food: "food name 2",
          serving_size: ["serving size 1", "serving size 2", "serving size 3"],
          calories: [calories for serving 1, calories for serving 2, calories for serving 3],
          protein: [protein for serving 1, protein for serving 2, protein for serving 3],
          carbohydrates: [carbohydrates for serving 1, carbohydrates for serving 2, carbohydrates for serving 3],
          fat: [fat for serving 1, fat for serving 2, fat for serving 3],
          fiber: [fiber for serving 1, fiber for serving 2, fiber for serving 3]
        },
      ]
    `;
    
    // Create parts for the request
    const imagePart: Part = {
      inlineData: {
        data: encodeBase64(imageBytes),
        mimeType: image.type,
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

    return new Response(
      JSON.stringify({ result: text }),
      { 
        headers: { 
          "Content-Type": "application/json",
          "Connection": "keep-alive"
        } 
      }
    );
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
