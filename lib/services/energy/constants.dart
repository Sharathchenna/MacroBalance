/// Every tunable of the adaptive goals maths (spec §5, §6.5, §6.6).
///
/// Pure Dart: nothing under `lib/services/energy/` imports Flutter or Supabase.
library;

// --- Body composition (Hall 2008, Forbes) ---
const double kLeanEnergyKcalPerKg = 1816; // 7.6 MJ/kg
const double kFatEnergyKcalPerKg = 9440; // 39.5 MJ/kg
const double kForbesC = 10.4; // kg
const double kMinBodyFatPct = 5;
const double kMaxBodyFatPct = 60;

// --- BMR and formula TDEE ---
/// Index = activity level − 1 (1 sedentary … 5 extra active).
const List<double> kActivityFactors = [1.2, 1.375, 1.55, 1.725, 1.9];

// --- Trend weight ---
const double kTrendAlpha = 0.10;
const double kOutlierPct = 0.03;
const int kOutlierRunToAccept = 3;
/// Weight tab: actual pace within this many %/wk of the goal pace reads as on pace.
const double kPaceTolerancePct = 0.15;

// --- Expenditure estimator ---
const int kWindowDays = 21;
const int kSwitchSettleDays = 4;
const int kMinCompleteDays = 7;
const int kMinWeighIns = 4;
const double kPartialFraction = 0.5;
const double kPriorSd = 300;
const double kProcessSdPerDay = 15;
/// Observation variance multiplier for overlapping windows. Tuned in the
/// simulation harness (test/unit/energy/simulated_user.dart) for calibration
/// and accuracy together: at 12 the truth is within ±1.28 sd on 77% of
/// seed-days (tuning seeds) and 80% (held-out seeds), inside the 75–85% band,
/// and day-28 accuracy is as good as anywhere in 4–25 (the spec's starting
/// value, 7, gave 71% calibration; 16 was well calibrated but less accurate).
const double kOverlapInflation = 12;
const double kIntakeBiasSd = 50;
const double kMaxDailyTdeeStep = 50;
const double kConfidentSd = 200;
const int kPausedAfterDays = 7;
const int algoVersion = 1;

// --- Pace (% of body weight per week) ---
const List<double> kLosePaceOptions = [0.25, 0.5, 0.75, 1.0];
const List<double> kGainPaceOptions = [0.1, 0.25, 0.5];
const double kDefaultLosePace = 0.5;
const double kDefaultGainPace = 0.25;

// --- Safety limits ---
const double kFloorFemale = 1200;
const double kFloorMale = 1500;
const double kMaxDeficitFrac = 0.25;
const double kMaxSurplusFrac = 0.15;
const double kMaxLossPct = 1.0;
const double kMaxGainPct = 0.5;
const double kMaxCheckinStep = 150;
const double kNoChangeThreshold = 25;

// --- Check-ins ---
/// The first check-in is at least this many days after onboarding (6.8).
const int kFirstCheckinAfterDays = 7;

/// The check-in runs at the first app open at or after this hour (local) on
/// the check-in day (6.8).
const int kCheckinHour = 4;

// --- Recalculate ---
/// A weigh-in this recent (today and the 2 days before) makes the trend a
/// one-tap weight in recalculate (plan 10.4).
const int kRecentWeighInDays = 3;

// --- Phases ---
const double kPhasedLossPctObese = 10;
const double kPhasedLossPct = 5;
const int kMaintenanceWeeks = 4;
const int kMaxLossPhaseWeeks = 16;
const int kBreakEveryWeeks = 8;
const int kBreakWeeks = 2;
/// "Extend break" on check-in variant G adds this many weeks (spec 6.7).
const int kExtendBreakWeeks = 2;
/// A lose goal more than this share of body weight away pre-selects the
/// phased plan (plan 10.3).
const double kPhasedDefaultGoalFrac = 0.10;
/// Longest any plan is walked forward (spec 6.9).
const int kMaxProjectionWeeks = 156;

// --- Macros ---
/// The BMI whose weight caps the protein reference weight.
const double kReferenceBmi = 25;
const double kDefaultFatRatio = 0.25;
/// Fat floor: the larger of g per kg of reference weight and share of cals.
const double kFatFloorPerKg = 0.5;
const double kFatFloorRatio = 0.20;
/// Lowest protein (g per kg of reference weight) when cals are too tight.
const double kMinProteinPerKg = 1.2;

/// Default protein, g per kg of reference weight.
const double kProteinLoseLean = 2.6; // reference = lean mass
const double kProteinLoseRef = 2.0; // reference = capped body weight
const double kProteinOtherLean = 2.0;
const double kProteinOtherRef = 1.6;

const double kKcalPerGramProtein = 4;
const double kKcalPerGramCarbs = 4;
const double kKcalPerGramFat = 9;
