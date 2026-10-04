import { serve } from 'https://deno.land/std@0.177.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.7.1';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

serve(async (req) => {
  // Handle CORS preflight request
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    console.log('Delete user function called');
    
    // Create a Supabase client with the Admin key
    const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? '';
    const supabaseServiceRole = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';
    
    console.log('Supabase URL available:', !!supabaseUrl);
    console.log('Supabase Service Role available:', !!supabaseServiceRole);
    
    if (!supabaseUrl || !supabaseServiceRole) {
      return new Response(
        JSON.stringify({ error: 'Missing environment variables' }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    const supabaseAdmin = createClient(supabaseUrl, supabaseServiceRole, {
      auth: {
        autoRefreshToken: false,
        persistSession: false,
      },
    });

    // Get the authorization header from the request
    const authHeader = req.headers.get('Authorization');
    if (!authHeader) {
      return new Response(
        JSON.stringify({ error: 'Missing authorization header' }),
        { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    // Validate the JWT
    const token = authHeader.replace('Bearer ', '');
    console.log('Token available:', !!token);
    
    const { data, error: userError } = await supabaseAdmin.auth.getUser(token);
    
    if (userError || !data.user) {
      console.error('User validation error:', userError);
      return new Response(
        JSON.stringify({ error: 'Invalid token', details: userError?.message }),
        { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }
    
    const user = data.user;
    console.log('User found:', user.id);

    // Parse the request body to get the user_id
    const requestData = await req.json();
    const { user_id } = requestData;
    
    console.log('Requested user_id:', user_id);

    // Verify that the user is trying to delete their own account
    if (user.id !== user_id) {
      return new Response(
        JSON.stringify({ error: 'You can only delete your own account' }),
        { status: 403, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    // Delete the user's data from all tables
    // Tables the app actually writes to (see lib/). 'user_food_entries' was a
    // stale name: food logs live in 'food_entries'.
    const tables = [
      'food_entries',
      'nutrition_goals',
      'saved_foods',
      'weight_entries',
      'workout_entries',
      'workout_monthly_stats',
      'profiles',
      'user_notification_preferences',
      'user_notification_tokens',
      'user_preferences', 
      'user_settings',
      'user_macros',
      'feedback'
    ];

    // Delete user data from each table
    let tableResults = {};
    // supabase-js reports failures in `error` rather than throwing, so check it
    // explicitly before falling back to tables keyed by `id` (user_macros, profiles).
    for (const table of tables) {
      const byUserId = await supabaseAdmin.from(table).delete().eq('user_id', user_id);
      if (!byUserId.error) {
        tableResults[table] = { success: true, count: byUserId.count };
        continue;
      }
      const byId = await supabaseAdmin.from(table).delete().eq('id', user_id);
      if (!byId.error) {
        tableResults[table] = { success: true, count: byId.count };
      } else {
        tableResults[table] = { success: false, error: byId.error.message };
        console.error(`Error deleting from ${table}:`, byUserId.error.message, byId.error.message);
      }
    }

    // Try to delete the user from auth.users - this requires admin privileges
    try {
      console.log('Attempting to delete user from auth');
      console.log('Admin API available:', typeof supabaseAdmin.auth.admin !== 'undefined');
      
      const { error: deleteError } = await supabaseAdmin.auth.admin.deleteUser(user_id);

      if (deleteError) {
        console.error('Error deleting user:', deleteError);
        
        // Fallback approach: If we can't directly delete the user, mark them as inactive
        // This is a common pattern when full deletion isn't possible
        try {
          console.log('Attempting alternative approach');
          
          // Update the user's email to a non-functioning one, remove identifiers
          // This effectively deactivates the account while preserving auth records
          const randomSuffix = Date.now().toString(36);
          const { error: updateError } = await supabaseAdmin.auth.admin.updateUserById(
            user_id,
            {
              email: `deleted-${randomSuffix}@deleted.account`,
              phone: null,
              user_metadata: {
                deleted: true,
                deleted_at: new Date().toISOString(),
                original_email: user.email
              }
            }
          );
          
          if (updateError) {
            console.error('Error updating user:', updateError);
            
            // If this approach also fails, return partial success
            return new Response(
              JSON.stringify({ 
                success: true, 
                partial: true,
                message: 'User data deleted but account remains. Manual deletion may be required.',
                details: `${deleteError.message}. Update failed: ${updateError.message}`,
                tableResults 
              }),
              { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
            );
          } else {
            // User successfully deactivated
            return new Response(
              JSON.stringify({ 
                success: true, 
                account_deactivated: true,
                message: 'User data deleted and account deactivated.',
                tableResults 
              }),
              { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
            );
          }
        } catch (fallbackError) {
          console.error('Fallback approach failed:', fallbackError);
          
          // Both approaches failed
          return new Response(
            JSON.stringify({ 
              success: true, 
              partial: true,
              message: 'User data deleted but account remains. Manual deletion may be required.',
              details: `${deleteError.message}. Fallback failed: ${fallbackError.message}`,
              tableResults 
            }),
            { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
          );
        }
      }
      
      // Original deletion succeeded
      return new Response(
        JSON.stringify({ 
          success: true, 
          account_deleted: true,
          message: 'User account and all data successfully deleted.',
          tableResults 
        }),
        { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    } catch (adminError) {
      console.error('Admin deletion error:', adminError);
      // If the admin API fails, return a partial success
      return new Response(
        JSON.stringify({ 
          success: true, 
          partial: true,
          message: 'User data deleted but account remains. Manual deletion may be required.',
          details: adminError.message,
          tableResults 
        }),
        { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }
  } catch (error) {
    console.error('General error:', error);
    return new Response(
      JSON.stringify({ error: error.message, stack: error.stack }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  }
}); 