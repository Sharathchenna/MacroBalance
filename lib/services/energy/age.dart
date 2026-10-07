/// The age to use in the maths: the age the user gave plus the whole years
/// since it was recorded. Dates are compared by day, not time of day.
///
/// With no record date (accounts from before it was kept) the stored age is
/// used as is. The result is capped at 100, the most an account can hold.
int effectiveAge({
  required int age,
  required DateTime? recordedOn,
  required DateTime today,
}) {
  if (recordedOn == null) return age;
  var years = today.year - recordedOn.year;
  final beforeAnniversary = today.month < recordedOn.month ||
      (today.month == recordedOn.month && today.day < recordedOn.day);
  if (beforeAnniversary) years--;
  if (years < 0) years = 0;
  return (age + years).clamp(0, 100);
}
