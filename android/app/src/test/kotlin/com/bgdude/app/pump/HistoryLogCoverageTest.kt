package com.bgdude.app.pump

import java.io.File
import java.util.jar.JarFile
import java.util.zip.ZipFile
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Decode-coverage report over the pump's history-log event types (issue #94).
 *
 * The pump streams 130+ distinct event types and bgdude decodes a handful. The number
 * itself is useful, but a hand-written figure in a doc rots the moment either side moves.
 * So this derives BOTH sides mechanically — the full type list from the pumpx2 jar on the
 * test classpath, and the handled list from `PumpHistoryMapper`'s own `is X` branches —
 * and fails when the committed report drifts from either.
 *
 * That makes the report a check rather than a claim: a pumpx2 upgrade that adds event
 * types, or a decode that gets added or removed, all surface here.
 */
class HistoryLogCoverageTest {

    private val packagePath = "com/jwoglom/pumpx2/pump/messages/response/historyLog/"

    private fun classpathEntries(): List<String> =
        (System.getProperty("java.class.path") ?: "").split(File.pathSeparator)

    /** Every concrete `*HistoryLog` type pumpx2 exposes, from the jar on the classpath. */
    private fun allEventTypes(): Set<String> {
        val types = sortedSetOf<String>()
        for (entry in classpathEntries()) {
            if (!entry.endsWith(".jar")) continue
            val file = File(entry)
            if (!file.isFile || !file.name.contains("pumpx2-messages")) continue
            JarFile(file).use { jar ->
                for (e in jar.entries()) {
                    val name = e.name
                    if (!name.startsWith(packagePath) || !name.endsWith("HistoryLog.class")) {
                        continue
                    }
                    // Skip nested/synthetic classes — not event types in their own right.
                    val simple = name.removePrefix(packagePath).removeSuffix(".class")
                    if (simple.contains('/') || simple.contains('$')) continue
                    types.add(simple)
                }
            }
        }
        return types
    }

    /** The types `PumpHistoryMapper` actually branches on, read from its source. */
    private fun decodedEventTypes(): Set<String> {
        val source = File("src/main/kotlin/com/bgdude/app/pump/PumpHistoryMapper.kt")
        assertTrue(
            "PumpHistoryMapper source not found at ${source.absolutePath} — this test " +
                "reads it to keep the coverage report honest",
            source.isFile,
        )
        return Regex("""\bis\s+([A-Za-z0-9_]+HistoryLog)\b""")
            .findAll(source.readText())
            .map { it.groupValues[1] }
            .toSortedSet()
    }

    @Test
    fun every_decoded_type_is_a_real_pumpx2_event_type() {
        val all = allEventTypes()
        assertTrue("no pumpx2 history-log types found on the classpath", all.isNotEmpty())

        val unknown = decodedEventTypes() - all
        assertEquals(
            "PumpHistoryMapper branches on types pumpx2 no longer has — a pumpx2 " +
                "upgrade probably renamed or removed them",
            emptySet<String>(),
            unknown,
        )
    }

    @Test
    fun the_committed_coverage_report_matches_reality() {
        val all = allEventTypes()
        val decoded = decodedEventTypes()

        val report = File("../../doc/pump-history-coverage.md")
        assertTrue("coverage report missing at ${report.absolutePath}", report.isFile)
        val text = report.readText()

        // The headline numbers, so the report can never quietly overstate coverage.
        assertTrue(
            "report does not state the current total of ${all.size} event types",
            text.contains("${all.size} event types"),
        )
        assertTrue(
            "report does not state the current decoded count of ${decoded.size}",
            text.contains("**${decoded.size} decoded**"),
        )

        // And every decoded type is listed by name, so the list is usable rather than
        // just a number.
        for (type in decoded) {
            assertTrue("report does not list decoded type $type", text.contains(type))
        }
    }

    @Test
    fun coverage_is_reported_honestly_as_a_minority_of_types() {
        val all = allEventTypes()
        val decoded = decodedEventTypes()

        // Not a quality bar — a guard against the report being generated from a stale or
        // empty scan and silently claiming full coverage.
        assertTrue("decoded ($decoded) should be a subset of all types", all.containsAll(decoded))
        assertTrue("expected pumpx2 to expose many event types, found ${all.size}", all.size > 100)
        assertTrue("expected at least some decoding, found ${decoded.size}", decoded.size >= 5)
    }

    /** Guards the scan itself: a silently-empty jar read would make coverage look total. */
    @Test
    fun the_classpath_scan_finds_the_pumpx2_jar() {
        val jars = classpathEntries()
            .filter { it.endsWith(".jar") && File(it).name.contains("pumpx2-messages") }
        assertTrue("pumpx2-messages jar not on the test classpath", jars.isNotEmpty())
        ZipFile(File(jars.first())).use { zip ->
            assertTrue(zip.entries().asSequence().any { it.name.startsWith(packagePath) })
        }
    }
}
