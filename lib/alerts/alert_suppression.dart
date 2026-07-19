/// Snooze, acknowledge, and content-aware dedup (issue #107).
///
/// The existing [CooldownGate] answers "has enough time passed since this category last
/// fired?". That is necessary and not sufficient. Three things it can't express:
///
///  * **Snooze** — "I know, leave me alone for 30 minutes." A cooldown is the app's
///    policy; a snooze is the user's, and it should outlast a restart.
///  * **Acknowledge** — "I've dealt with this." The alert should stay quiet until the
///    situation actually changes, not merely until a timer expires. Re-alerting someone
///    who has already eaten the carbs is how alerts get muted permanently.
///  * **Content dedup** — a cooldown keyed only on category re-fires the *identical*
///    message the moment it lapses. "Low ahead, predicted 61 mg/dL" three times in an
///    hour, unchanged, is spam; the same category with a materially worse number is
///    news.
///
/// All pure and persisted, because there are now two evaluators — the foreground app and
/// the headless watch (issues #51/#28) — in separate processes. In-memory suppression
/// that one knows about and the other doesn't is how the same alert arrives twice.
library;

import 'dart:convert';

import '../insights/notification_prefs.dart';

/// A user-initiated suppression of one alert category.
class AlertSuppression {
  const AlertSuppression({
    required this.category,
    required this.until,
    this.acknowledgedSignature,
  });

  final NotificationCategory category;

  /// Suppressed until this instant (a snooze).
  final DateTime until;

  /// When set, the alert content the user acknowledged. Suppression persists past
  /// [until] for as long as the alert would say the same thing — an acknowledgement is
  /// about a situation, not a clock.
  final String? acknowledgedSignature;
}

/// Persisted snooze/acknowledge state, shared by both evaluators.
class AlertSuppressionState {
  const AlertSuppressionState(this.suppressions);

  final Map<NotificationCategory, AlertSuppression> suppressions;

  static const AlertSuppressionState empty = AlertSuppressionState({});

  /// Snooze [category] until [now] + [duration].
  AlertSuppressionState snooze(
    NotificationCategory category,
    DateTime now,
    Duration duration,
  ) =>
      AlertSuppressionState({
        ...suppressions,
        category: AlertSuppression(
          category: category,
          until: now.add(duration),
          // A snooze is time-based only: the user asked for quiet, not for the alert
          // to be dismissed on its merits.
          acknowledgedSignature: null,
        ),
      });

  /// Acknowledge [category] for the specific alert content [signature].
  ///
  /// Deliberately has NO minimum quiet period. An acknowledgement is held only while
  /// the alert would say the same thing — [alertSignature] buckets the value so a
  /// one-point wobble doesn't defeat it, but a materially worse reading re-alerts
  /// **immediately**.
  ///
  /// That is the safety-shaped choice. A time-based floor would mean a low that
  /// crashed from 61 to 45 within the window stayed silent because the user had
  /// acknowledged the milder version of it a few minutes earlier. Use [snooze] when
  /// what the user wants is quiet for a period regardless.
  AlertSuppressionState acknowledge(
    NotificationCategory category,
    String signature,
    DateTime now,
  ) =>
      AlertSuppressionState({
        ...suppressions,
        category: AlertSuppression(
          category: category,
          // No quiet window of its own; suppression is signature-based from here.
          until: now,
          acknowledgedSignature: signature,
        ),
      });

  AlertSuppressionState clear(NotificationCategory category) =>
      AlertSuppressionState({...suppressions}..remove(category));

  String encode() => jsonEncode({
        for (final e in suppressions.entries)
          e.key.name: {
            'until': e.value.until.millisecondsSinceEpoch,
            if (e.value.acknowledgedSignature != null)
              'ack': e.value.acknowledgedSignature,
          },
      });

  /// Unreadable state decodes to empty — failing OPEN, so a corrupt file can never
  /// silently mute an urgent low.
  static AlertSuppressionState decode(String? raw) {
    if (raw == null || raw.trim().isEmpty) return empty;
    try {
      final json = jsonDecode(raw);
      if (json is! Map) return empty;
      final out = <NotificationCategory, AlertSuppression>{};
      for (final c in NotificationCategory.values) {
        final v = json[c.name];
        if (v is! Map) continue;
        final until = v['until'];
        if (until is! int) continue;
        out[c] = AlertSuppression(
          category: c,
          until: DateTime.fromMillisecondsSinceEpoch(until),
          acknowledgedSignature: v['ack'] as String?,
        );
      }
      return AlertSuppressionState(out);
    } catch (_) {
      return empty;
    }
  }
}

/// Categories a user may never silence.
///
/// An urgent low is the one alert whose entire purpose is to interrupt. Letting it be
/// snoozed would make the app's most important guarantee user-defeatable by a mistaken
/// tap at 3am — and the person tapping is, by definition, not at their sharpest.
const Set<NotificationCategory> unsnoozableCategories = {
  NotificationCategory.urgentLow,
};

/// Whether an alert may fire, given user suppression.
///
/// [signature] is a stable description of what the alert would SAY (see
/// [alertSignature]). An acknowledged alert stays quiet while its signature is
/// unchanged, and speaks again the moment the situation materially differs.
bool alertAllowed({
  required NotificationCategory category,
  required String signature,
  required AlertSuppressionState state,
  required DateTime now,
}) {
  if (unsnoozableCategories.contains(category)) return true;

  final s = state.suppressions[category];
  if (s == null) return true;

  // A backwards clock change can leave `until` absurdly far ahead, which would mute a
  // category indefinitely. Anything beyond the longest legitimate snooze is treated as
  // bogus and ignored — failing open, because a stuck mute is the dangerous direction.
  final remaining = s.until.difference(now);
  final windowActive = !remaining.isNegative && remaining <= maxSuppression;

  if (windowActive && s.acknowledgedSignature == null) {
    // A plain snooze: quiet until it expires, whatever the alert would say.
    return false;
  }

  // An acknowledgement outlives its minimum-quiet window, but only for as long as the
  // alert would say the same thing. The moment the situation materially differs, the
  // signature changes and it speaks again.
  if (s.acknowledgedSignature != null) {
    return s.acknowledgedSignature != signature;
  }
  return true;
}

/// The longest a suppression is ever honoured.
///
/// A ceiling rather than a policy: no legitimate snooze runs this long, so a stored
/// value beyond it means a clock change, not a user choice.
const Duration maxSuppression = Duration(hours: 8);

/// A stable signature for an alert's content, for dedup and acknowledgement.
///
/// Buckets the value rather than using it raw: a predicted low of 61 and one of 62 are
/// the same news, and treating them as different content would let a one-point wobble
/// defeat an acknowledgement. [bucketMgdl] of 10 means the alert speaks again only when
/// the figure moves a clinically meaningful amount.
String alertSignature({
  required NotificationCategory category,
  required double valueMgdl,
  int bucketMgdl = 10,
}) {
  final bucket = (valueMgdl / bucketMgdl).floor() * bucketMgdl;
  return '${category.name}:$bucket';
}

/// Whether [next] is materially worse than the acknowledged [previous] value, in the
/// direction that matters for [category].
///
/// Used so an acknowledged low that keeps falling still re-alerts: "I've dealt with it"
/// applies to the situation described, not to every future version of it.
bool materiallyWorse({
  required NotificationCategory category,
  required double previousMgdl,
  required double nextMgdl,
  double marginMgdl = 10,
}) {
  final lowSide = category == NotificationCategory.predictedLow ||
      category == NotificationCategory.urgentLow ||
      category == NotificationCategory.overnightLowRisk;
  return lowSide
      ? nextMgdl <= previousMgdl - marginMgdl
      : nextMgdl >= previousMgdl + marginMgdl;
}
