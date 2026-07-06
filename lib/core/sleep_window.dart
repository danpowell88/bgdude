/// The default "asleep" window used app-wide when no explicit sleep data is available:
/// **23:00–07:00 local**. This is a clinical policy (overnight lows are treated with a
/// tighter, more cautious hand, and it will likely become user-configurable), so it lives
/// in exactly one place rather than copy-pasted across the timeline, confirmation service,
/// providers, simulator and UI (TASK-102).
library;

/// Whether [t] falls in the default overnight sleep window (23:00–07:00 local).
bool defaultAsleepAt(DateTime t) => t.hour >= 23 || t.hour < 7;
