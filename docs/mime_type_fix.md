# MIME Type Fix for Gemini Edge Function

## Problem
The `process-withgemini` edge function was receiving images with `application/octet-stream` MIME type instead of proper image MIME types like `image/jpeg`. This caused the Google Gemini API to reject the requests with the error:

```
[400 Bad Request] Unable to submit request because it has a mimeType parameter with value application/octet-stream, which is not supported.
```

## Root Cause
- Flutter's `http.MultipartFile.fromBytes()` was not explicitly setting the content type
- The edge function was using `image.type` directly without fallback logic
- When MIME type detection failed, it defaulted to `application/octet-stream`

## Solution Applied

### 1. Flutter Client Fix ✅
Updated `lib/AI/gemini.dart` to explicitly set the content type:

```dart
// Before
final multipartFile = http.MultipartFile.fromBytes(
  'image',
  imageBytes,
  filename: 'image.jpg',
);

// After
final multipartFile = http.MultipartFile.fromBytes(
  'image',
  imageBytes,
  filename: 'image.jpg',
  contentType: MediaType('image', 'jpeg'),
);
```

### 2. Edge Function Fix (Needs Manual Deployment)
Updated `supabase/functions/process-withgemini/index.ts` with intelligent MIME type detection:

```typescript
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
```

## Manual Deployment Required

Since the Supabase MCP deployment is experiencing internal errors, you'll need to deploy the updated edge function manually:

### Option 1: Using Supabase CLI
```bash
# Navigate to your project root
cd /Users/sharathchenna/Developer/personal-projects/Macrotracker

# Deploy the specific function
supabase functions deploy process-withgemini

# Or deploy all functions
supabase functions deploy
```

### Option 2: Using Supabase Dashboard
1. Go to your Supabase project dashboard
2. Navigate to Edge Functions
3. Select `process-withgemini`
4. Copy the updated code from `supabase/functions/process-withgemini/index.ts`
5. Paste and deploy

## Verification Steps

After deployment:

1. **Test the AI feature** in your app by taking a photo
2. **Check logs** for the new MIME type detection:
   ```
   Received image: image.jpg, type: image/jpeg, size: 123456
   Using MIME type: image/jpeg
   ```
3. **Verify successful processing** without MIME type errors

## Expected Results

- ✅ No more `application/octet-stream` errors
- ✅ Proper image MIME type detection
- ✅ Successful Gemini API processing
- ✅ Improved error logging and debugging

## Status

- [x] Flutter client updated with explicit MIME type
- [x] Edge function code updated locally
- [ ] **Manual deployment needed** (MCP deployment failed)
- [ ] Testing and verification pending

The Flutter changes are already applied and working. The edge function update is ready in your local files and just needs to be deployed to resolve the MIME type issue completely. 