# Superwall Dashboard Configuration Guide

## Critical Configuration Required

Your Superwall dashboard needs these specific settings to fix the hard paywall dismissal and restore button issues.

## 1. Campaign Configuration

### Campaign Settings
1. **Go to Campaigns** in your Superwall dashboard
2. **Create or edit your campaign** for the onboarding paywall
3. Set the following:
   - **Name**: "Onboarding Hard Paywall"
   - **Placement**: `onboarding_paywall`
   - **Audience**: "All Users" (or create custom audience for non-subscribers)
   - **Traffic**: 100%

### Paywall Configuration
4. **Select your paywall template**
5. **In Paywall Settings**:
   - **Feature Gating**: Set to **"Gated"** (CRITICAL - this prevents dismissal)
   - **Allow Dismissal**: Set to **"No"** 
   - **Show Close Button**: Set to **"No"**
   - **Dismissal Type**: "None" or "Subscription Required"

## 2. Placement Configuration

### Create Placement
1. **Go to Placements** in dashboard
2. **Click "Create Placement"**
3. **Set details**:
   - **Placement Identifier**: `onboarding_paywall`
   - **Placement Type**: "Gated Feature"
   - **Default Behavior**: "Show Paywall"

### Placement Rules
4. **Configure Placement Rules**:
   - **When to Show**: "User does not have active subscription"
   - **Feature Access**: "Block access until subscription"
   - **Dismissal**: "Not allowed"

## 3. Audience Configuration

### Non-Subscriber Audience
1. **Go to Audiences**
2. **Create New Audience**: "Non-Subscribers"
3. **Set Rules**:
   - **Subscription Status**: "Not Active"
   - **OR User Property**: `has_subscription = false`

### Subscriber Audience  
4. **Create New Audience**: "Active Subscribers"
5. **Set Rules**:
   - **Subscription Status**: "Active"
   - **OR User Property**: `has_subscription = true`

## 4. Paywall Template Configuration

### Remove/Disable Default Restore
1. **Go to your paywall template**
2. **Find the restore button element**
3. **Either**:
   - **Delete the restore button** completely
   - **OR disable it** in the template
   - **OR change its action** to a custom action

### Alternative: Custom Restore Action
If you want to keep a restore button with custom behavior:
1. **Keep the restore button in template**
2. **Set button action** to: `custom_restore`
3. **This will trigger your custom restore logic** in the app

## 5. Product Configuration

### RevenueCat Integration
1. **Go to Integrations**
2. **Select RevenueCat**
3. **Verify Configuration**:
   - **API Key**: Correctly set
   - **Webhook URL**: Configured for real-time updates
   - **Product Mapping**: All products properly mapped

### Product Settings
4. **Go to Products**
5. **For each subscription product**:
   - **Verification**: "RevenueCat"
   - **Entitlement**: Match your RevenueCat entitlement names
   - **Auto-renewal**: "Yes" for subscriptions

## 6. Analytics & Events

### Track Critical Events
1. **Go to Analytics**
2. **Ensure these events are being tracked**:
   - `paywall_present`
   - `paywall_dismiss` (should be rare/impossible with hard paywall)
   - `subscription_start`
   - `restore_started`
   - `restore_success`
   - `restore_failed`

## 7. User Properties

### Required User Properties
Set these user properties in your app for better targeting:

```dart
// In your SuperwallService
await Superwall.shared.setUserProperties({
  'has_subscription': isSubscribed,
  'subscription_status': isSubscribed ? 'active' : 'inactive',
  'user_id': userId,
  'signup_date': signupDate,
  'onboarding_completed': true,
});
```

## 8. Testing Configuration

### Test Users
1. **Go to Test Users**
2. **Add your test accounts**
3. **Set different subscription states** for testing

### Sandbox Configuration
4. **Enable Sandbox Mode** for testing
5. **Configure sandbox products** to match production

## 9. Webhooks (Important for Real-time Updates)

### RevenueCat Webhook
1. **In RevenueCat Dashboard**:
   - Go to **Integrations → Webhooks**
   - Add **Superwall webhook URL**
   - Enable events: `INITIAL_PURCHASE`, `RENEWAL`, `CANCELLATION`, `EXPIRATION`

### Superwall Webhook Events
2. **In Superwall Dashboard**:
   - Go to **Integrations → Webhooks**
   - Configure endpoints for your backend
   - Track subscription events for analytics

## 10. Troubleshooting Common Issues

### Issue: Paywall Can Still Be Dismissed
**Solution**: 
- Verify **Feature Gating** is set to "Gated"
- Check **Allow Dismissal** is set to "No"
- Ensure **placement type** is "Gated Feature"

### Issue: Restore Shows False Success
**Solution**:
- Disable default restore button in template
- Implement custom restore action
- Use RevenueCat directly for restore logic

### Issue: Paywall Doesn't Show
**Solution**:
- Check **campaign traffic** is set to 100%
- Verify **audience rules** match your users
- Ensure **placement identifier** matches your code

### Issue: Subscription Status Not Updating
**Solution**:
- Configure **RevenueCat webhook** in Superwall
- Check **user properties** are being set correctly
- Verify **product mapping** between RevenueCat and Superwall

## 11. Validation Checklist

After configuration, verify these work:

### ✅ Hard Paywall Enforcement
- [ ] Paywall appears for non-subscribers
- [ ] Paywall CANNOT be dismissed without purchase
- [ ] No close/back button visible
- [ ] App content is completely blocked

### ✅ Subscription Detection  
- [ ] Purchase immediately updates subscription status
- [ ] App detects subscription and dismisses paywall
- [ ] User gains immediate access to content
- [ ] Subscription persists across app restarts

### ✅ Restore Functionality
- [ ] Restore works for users with previous purchases
- [ ] Restore shows appropriate error for users without purchases
- [ ] No misleading "success" messages for empty restores
- [ ] Successful restore dismisses paywall and grants access

### ✅ Edge Cases
- [ ] App backgrounding/foregrounding re-enforces paywall for non-subscribers
- [ ] Network issues don't bypass paywall
- [ ] Expired subscriptions re-show paywall
- [ ] Family sharing scenarios work correctly

## 12. Support & Documentation

### Superwall Support Resources
- **Dashboard Help**: Click "?" icon in Superwall dashboard
- **Documentation**: https://docs.superwall.com
- **Community**: Superwall Slack community
- **Support Email**: support@superwall.com

### Integration Documentation
- **Flutter SDK**: https://docs.superwall.com/docs/flutter
- **RevenueCat Integration**: https://docs.superwall.com/docs/revenuecat

---

## ⚠️ CRITICAL REMINDER

The hard paywall MUST be truly enforced. Users should NEVER be able to access your app without an active subscription. The current implementation has security flaws that allow unauthorized access.

**Complete this dashboard configuration immediately** to ensure proper monetization and prevent revenue loss. 