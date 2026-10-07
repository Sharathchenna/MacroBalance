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

// --- Expenditure estimator ---
const int kWindowDays = 21;
const int kSwitchSettleDays = 4;
const int kMinCompleteDays = 7;
const int kMinWeighIns = 4;
const double kPartialFraction = 0.5;
const double kPriorSd = 300;
const double kProcessSdPerDay = 15;
const double kOverlapInflation = 7;
const double kIntakeBiasSd = 50;
const double kMaxDailyTdeeStep = 50;
const double kConfidentSd = 200;
const int kPausedAfterDays = 7;
const int algoVersion = 1;

// --- Safety limits ---
const double kFloorFemale = 1200;
const double kFloorMale = 1500;
const double kMaxDeficitFrac = 0.25;
const double kMaxSurplusFrac = 0.15;
const double kMaxLossPct = 1.0;
const double kMaxGainPct = 0.5;
const double kMaxCheckinStep = 150;
const double kNoChangeThreshold = 25;

// --- Phases ---
const double kPhasedLossPctObese = 10;
const double kPhasedLossPct = 5;
const int kMaintenanceWeeks = 4;
const int kMaxLossPhaseWeeks = 16;
const int kBreakEveryWeeks = 8;
const int kBreakWeeks = 2;

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
