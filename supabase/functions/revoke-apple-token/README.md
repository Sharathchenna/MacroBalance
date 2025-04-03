# Apple Token Revocation Function

This Edge Function revokes Apple Sign In tokens when a user deletes their account, following [Apple's token revocation guidelines](https://developer.apple.com/documentation/signinwithapplerestapi/revoke_tokens).

## Deployment

Deploy this function to your Supabase project:

```bash
supabase functions deploy revoke-apple-token --project-ref your-project-ref
```

## Environment Variables

You need to set the following environment variables in your Supabase project:

```bash
supabase secrets set --env production APPLE_CLIENT_ID=your-apple-client-id
supabase secrets set --env production APPLE_TEAM_ID=your-apple-team-id
supabase secrets set --env production APPLE_KEY_ID=your-apple-key-id
supabase secrets set --env production APPLE_PRIVATE_KEY="$(cat /path/to/your/private/key.p8)"
```

Where:
- `APPLE_CLIENT_ID`: Your Apple Service ID
- `APPLE_TEAM_ID`: Your Apple Developer Team ID
- `APPLE_KEY_ID`: The Key ID for your private key
- `APPLE_PRIVATE_KEY`: The contents of your .p8 private key file from Apple

## How It Works

1. The function verifies that the user is authenticated
2. It checks if the user signed in with Apple
3. It creates a client secret JWT using your Apple credentials
4. It calls Apple's revocation endpoint to invalidate the user's token
5. It returns a success or error response

## Testing

You can test this function using the Supabase CLI:

```bash
supabase functions serve revoke-apple-token
```

Then in another terminal:

```bash
curl -X POST http://localhost:54321/functions/v1/revoke-apple-token \
  -H "Authorization: Bearer USER_JWT_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"user_id": "USER_ID_TO_REVOKE"}'
```

## Error Handling

The function handles various error scenarios and returns appropriate HTTP status codes:
- 400: Bad Request (missing user ID)
- 401: Unauthorized (missing or invalid authorization)
- 403: Forbidden (trying to revoke another user's token)
- 404: Not Found (user not found)
- 500: Server Error (Apple API error or internal error) 