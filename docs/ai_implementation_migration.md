# AI Implementation Migration: From Vertex AI to Supabase Edge Function

## Overview
The AI image processing functionality has been migrated from Firebase Vertex AI to use a Supabase edge function. This change centralizes the AI processing on the server-side and provides better control over API keys and usage.

## What Changed

### Before (Vertex AI)
- Used `firebase_vertexai` package directly in Flutter
- Processed images client-side using Firebase Vertex AI
- Required Firebase project configuration for AI services

### After (Supabase Edge Function)
- Uses the existing `process-withgemini` Supabase edge function
- Sends compressed images via HTTP multipart requests to Supabase
- Server-side processing using Google Generative AI (Gemini 2.0-flash)
- Requires user authentication (uses current Supabase session)

## Technical Details

### Function Location
- **File**: `lib/AI/gemini.dart`
- **Function**: `processImageWithGemini(String imagePath)`
- **Edge Function**: `process-withgemini` (deployed in Supabase)

### Request Flow
1. Compress image locally using `flutter_image_compress`
2. Create multipart HTTP request to Supabase edge function
3. Include user authentication token from current session
4. Send compressed image to `/functions/v1/process-withgemini`
5. Parse JSON response containing nutrition analysis

### Dependencies
- **Added**: `http` package for HTTP requests (already in pubspec.yaml)
- **Added**: `dart:convert` for JSON parsing
- **Added**: `supabase_flutter` integration for authentication
- **Removed**: Direct usage of `firebase_vertexai` package

### Authentication
- Requires active Supabase user session
- Uses Bearer token authentication with edge function
- Function will fail if user is not authenticated

## Edge Function Details

The `process-withgemini` edge function:
- Accepts multipart form data with image file
- Uses Google Generative AI with Gemini 2.0-flash model
- Applies the same nutrition analysis prompt as before
- Returns structured JSON with meal nutrition information
- Includes error handling and CORS headers

## Benefits

1. **Centralized API Key Management**: Gemini API key stored securely in Supabase secrets
2. **Consistent Processing**: Same model and prompt across all requests
3. **Better Error Handling**: Server-side error management
4. **Authentication Integration**: Uses existing Supabase authentication
5. **Scalability**: Edge function auto-scales with demand

## Migration Verification

All existing function calls remain unchanged:
- `Dashboard.dart` - Line 154
- `searchPage.dart` - Line 424  
- `camera.dart` - Line 169

The function signature remains identical: `Future<String> processImageWithGemini(String imagePath)`

## Error Handling

The function includes comprehensive error handling for:
- Authentication failures (user not logged in)
- Network errors
- Edge function errors
- JSON parsing errors
- File compression issues

Errors are logged with `[Gemini Debug]` prefix for debugging purposes. 