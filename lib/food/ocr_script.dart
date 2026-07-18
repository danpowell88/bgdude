/// Detecting a label the OCR cannot actually read (issue #103).
///
/// bgdude's text recognizer is wired to ML Kit's **Latin** script model. Point it at a
/// Chinese, Japanese, Korean, Cyrillic or Thai nutrition panel and it does not fail — it
/// returns confident nonsense, which is then fed to the parser and, if a model is
/// installed, to the LLM. The user sees "couldn't read that panel" and reasonably
/// concludes the photo was bad, and takes it again, and again.
///
/// This does not decide whether to ADD those recognizers — see
/// `doc/decisions/decision-19.md`. It makes the current limitation visible, which is
/// strictly better than silence either way: if CJK support is added later, this detector
/// simply stops firing.
library;

/// Scripts bgdude's recognizer cannot read, with the name to show the user.
enum UnsupportedScript {
  chineseJapaneseKorean('Chinese, Japanese or Korean'),
  cyrillic('Cyrillic'),
  thai('Thai'),
  arabic('Arabic'),
  devanagari('Devanagari');

  const UnsupportedScript(this.label);
  final String label;
}

/// Fraction of [text]'s letters that belong to [script].
///
/// Counts only letter-ish characters: digits and punctuation survive OCR of any script
/// and would dilute the signal, and a nutrition panel is mostly digits.
double _shareOf(String text, bool Function(int) test) {
  var letters = 0;
  var matching = 0;
  for (final rune in text.runes) {
    // Skip digits, whitespace and ASCII punctuation — script-neutral.
    if (rune < 0x30) continue;
    if (rune >= 0x30 && rune <= 0x39) continue;
    if (rune >= 0x3A && rune <= 0x40) continue;
    if (rune >= 0x5B && rune <= 0x60) continue;
    if (rune >= 0x7B && rune <= 0x7E) continue;
    letters++;
    if (test(rune)) matching++;
  }
  return letters == 0 ? 0 : matching / letters;
}

bool _isCjk(int r) =>
    (r >= 0x4E00 && r <= 0x9FFF) || // CJK unified ideographs
    (r >= 0x3040 && r <= 0x30FF) || // hiragana + katakana
    (r >= 0xAC00 && r <= 0xD7AF) || // hangul syllables
    (r >= 0x3400 && r <= 0x4DBF); // CJK extension A

bool _isCyrillic(int r) => r >= 0x0400 && r <= 0x04FF;
bool _isThai(int r) => r >= 0x0E00 && r <= 0x0E7F;
bool _isArabic(int r) => r >= 0x0600 && r <= 0x06FF;
bool _isDevanagari(int r) => r >= 0x0900 && r <= 0x097F;

/// The share of non-Latin letters above which the label is treated as unreadable.
///
/// Not zero: a Latin panel legitimately carries the odd non-Latin character (a °, a
/// trademark, a brand name), and firing on one of those would tell people their English
/// label is unsupported — worse than the silence this replaces.
const double unsupportedScriptThreshold = 0.3;

/// Which unsupported script dominates [text], or null when it looks readable.
///
/// Returns null for empty text too: nothing recognised is a different problem (a dark
/// photo, a missed panel) and must not be blamed on the script.
UnsupportedScript? detectUnsupportedScript(String text) {
  if (text.trim().isEmpty) return null;

  const tests = <UnsupportedScript, bool Function(int)>{
    UnsupportedScript.chineseJapaneseKorean: _isCjk,
    UnsupportedScript.cyrillic: _isCyrillic,
    UnsupportedScript.thai: _isThai,
    UnsupportedScript.arabic: _isArabic,
    UnsupportedScript.devanagari: _isDevanagari,
  };

  UnsupportedScript? best;
  var bestShare = unsupportedScriptThreshold;
  tests.forEach((script, test) {
    final share = _shareOf(text, test);
    if (share > bestShare) {
      bestShare = share;
      best = script;
    }
  });
  return best;
}

/// What to tell the user. Names the script, says it plainly, and offers the way forward
/// that actually works rather than suggesting they retake the photo.
String unsupportedScriptMessage(UnsupportedScript script) =>
    "This label looks like ${script.label} text. bgdude's label scanner only reads "
    'Latin-script labels at the moment, so retaking the photo will not help — '
    'enter the values by hand instead.';
