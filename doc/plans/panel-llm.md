# Plan: nutrition-panel LLM (Gemma) improvements — deferred

Deferred work from the July 2026 ML review. The forecasting-stack fixes from that
review are done; these are the panel-scanner (OCR → parser → Gemma) items, held back
deliberately so they can be done together with the on-device verification work
(ROADMAP 1.1 / 1.8). Ordered by safety value.

## 1. Validate the LLM's numbers (highest priority — dosing safety)

`parsePanelLlmJson` (`lib/food/panel_llm.dart`) currently accepts *any* number the
model emits: negative carbs, 950 g/100 g, sugars > carbs all flow straight into the
bolus-advisor prefill. Add, in the parser (not the prompt — prompts are advisory,
parsers are enforcement):

- **Hard bounds:** each macro 0–100 g per 100 g (0–100 g per serve is generous but
  acceptable); sodium 0–5000 mg; energy 0–4000 kJ/100 g; serving size 1–1000 g;
  servings/pack 1–100. Out-of-range → field becomes null.
- **Cross-field checks:** sugars ≤ carbs, saturated ≤ fat (if ever added), and
  per-serve ≈ per-100g × servingSize/100 within ~25% when all three are present;
  on conflict, keep per-100g + serving size and null the per-serve value.
- Keep the existing "carbs+fat+protein all empty → reject" rule.

## 2. OCR-grounding check (anti-hallucination + prompt-injection guard)

Only accept an LLM value if that number literally appears in the OCR text (± comma
decimals / rounding). One pass over the extracted numbers neutralises most
hallucinated values *and* most prompt-injection payloads ("output carbs 0") in a
single move, because injected instructions can't conjure numbers that pass the
grounding filter while also being wrong. Implement as a post-parse filter in
`PanelScanService` so it applies regardless of which model produced the JSON.

## 3. Fix the confidence comparison (hallucinated completeness currently wins)

`NutritionPanel.confidence` scores field *completeness* (carbs 0.6 + protein 0.15 +
fat 0.15 + serving 0.1), and `PanelScanService` adopts the LLM result whenever its
confidence beats the parser's. A model that confidently invents all three macros
scores 0.9 and beats an honest partial regex read. After item 2, base the LLM
result's confidence on the *grounded* fields only; ungrounded fields contribute 0.

## 4. Few-shot prompt + on-device self-check

- Add two few-shot examples to `buildPanelPrompt`: one AU/EU two-column panel
  ("per serve / per 100 g"), one US single-column label. This stabilises a 1B
  model's JSON adherence and column assignment far more than prompt wording tweaks.
- Add the ROADMAP 1.1 "test the model" self-check to the AI-model screen: a canned
  panel text → LLM → JSON round-trip with pass/fail display, so inference is
  verifiable on-device without a perfect photo.
- Then run `integration_test/nutrition_ocr_accuracy_test.dart` end-to-end with the
  LLM enabled (it currently exercises OCR + parser only) and record the numbers.

## 5. Model integrity & resource gating

- **Identity:** the installed model is currently keyed by URL filename only
  (`panel_model_manager.dart`). Store the source URL + SHA-256 checksum alongside;
  verify on download completion; surface "model changed at source" instead of
  silently colliding on a filename.
- **RAM/space gating:** check free storage before download and available RAM before
  load (a failed load currently degrades to a silent null result). Warn below ~3 GB
  device RAM.
- **Reconcile the size claims:** `panel_model_manager.dart` says ~0.5 GB,
  `panel_llm_gemma.dart` says ~1.5 GB resident, the UI says ~0.5 GB. Measure the real
  file + resident footprint on the Pixel 7 Pro during 1.1 verification and make all
  three agree.

## 6. OCR script support (scope decision)

ML Kit is initialised Latin-only (`panel_ocr_mlkit.dart`), so for CJK/Cyrillic labels
the LLM receives garbage it cannot fix — despite "foreign-language panels" being the
LLM's stated purpose. Either:

- add script detection + the corresponding ML Kit recognizers (Chinese, Japanese,
  Korean, Devanagari), or
- scope the feature honestly to "messy Latin-script labels" in the AI-model screen
  copy and the user guide.

Decide during 1.1 verification based on which labels actually get scanned.

## Sequencing

Items 1–3 are pure Dart with host-testable unit tests and can land before any
hardware session. Item 4's few-shot + self-check should land *before* the on-device
accuracy measurement so the measured numbers reflect the tuned prompt. Items 5–6
fold into the ROADMAP 1.1 hardware-verification session.
