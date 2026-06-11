/// 8週重評到期門檻（日）— DESIGN SPEC.md §3.
const int retestDueDays = 56;

/// 由上次完整評估日期計起，係咪已到8週重評期（含第56日）。
bool isRetestDue(DateTime lastFullAssessmentDate, DateTime now) {
  return now.difference(lastFullAssessmentDate).inDays >= retestDueDays;
}
