// supabase/functions/schedule-notifications/index.ts
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

serve(async (req) => {
  try {
    const supabaseAdmin = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )
    
    const now = new Date()
    const currentHour = now.getUTCHours()
    const currentMinute = now.getUTCMinutes()
    const currentDay = now.getUTCDay() // 0 = Sunday, 1 = Monday, etc.
    
    // Get all users with meal reminders enabled where the time matches current UTC time
    const { data: mealReminders, error: mealError } = await supabaseAdmin
      .from('user_notification_preferences')
      .select('user_id')
      .eq('meal_reminders', true)
      .filter('meal_reminder_time', 'eq', `${currentHour.toString().padStart(2, '0')}:${currentMinute.toString().padStart(2, '0')}:00`)
    
    if (mealError) throw mealError
    
    // Get all users with weekly reports enabled where the day and time match
    const { data: weeklyReports, error: weeklyError } = await supabaseAdmin
      .from('user_notification_preferences')
      .select('user_id')
      .eq('weekly_reports', true)
      .eq('weekly_report_day', currentDay)
      .filter('weekly_report_time', 'eq', `${currentHour.toString().padStart(2, '0')}:${currentMinute.toString().padStart(2, '0')}:00`)
    
    if (weeklyError) throw weeklyError
    
    // Send notifications
    const results = []
    
    // Send meal reminders
    for (const { user_id } of mealReminders || []) {
      const response = await fetch(`${Deno.env.get('SUPABASE_URL')}/functions/v1/send-notifications`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')}`,
        },
        body: JSON.stringify({
          type: 'meal_reminder',
          userId: user_id,
        }),
      })
      
      results.push({
        type: 'meal_reminder',
        userId: user_id,
        status: response.status,
        result: await response.json(),
      })
    }
    
    // Send weekly reports
    for (const { user_id } of weeklyReports || []) {
      const response = await fetch(`${Deno.env.get('SUPABASE_URL')}/functions/v1/send-notifications`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')}`,
        },
        body: JSON.stringify({
          type: 'weekly_report',
          userId: user_id,
        }),
      })
      
      results.push({
        type: 'weekly_report',
        userId: user_id,
        status: response.status,
        result: await response.json(),
      })
    }
    
    return new Response(
      JSON.stringify({ 
        success: true, 
        sent: results.length,
        results 
      }),
      { headers: { 'Content-Type': 'application/json' } }
    )
    
  } catch (error) {
    return new Response(
      JSON.stringify({ success: false, error: error.message }),
      { 
        status: 400,
        headers: { 'Content-Type': 'application/json' } 
      }
    )
  }
})

/* To invoke locally:

  1. Run `supabase start` (see: https://supabase.com/docs/reference/cli/supabase-start)
  2. Make an HTTP request:

  curl -i --location --request POST 'http://127.0.0.1:54321/functions/v1/schedule-notifications' \
    --header 'Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0' \
    --header 'Content-Type: application/json' \
    --data '{"name":"Functions"}'

*/
