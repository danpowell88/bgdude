package com.bgdude.app.pump

import com.jwoglom.pumpx2.pump.messages.Message
import com.jwoglom.pumpx2.pump.messages.MessageType
import com.jwoglom.pumpx2.pump.messages.bluetooth.Characteristic

/**
 * Read-only protocol probe: reflectively builds a `currentStatus` **request** message from a
 * short class name so the Protocol Explorer screen can fire any read the pump supports —
 * including the messages bgdude doesn't otherwise surface (HomeScreenMirror, PumpFeatures,
 * PumpSettings, SecretMenu, …) — to discover undocumented fields.
 *
 * The read-only guarantee of [PumpCommHandler] is preserved **by construction** here:
 * [buildSafeRequest] refuses anything that is not an unsigned CURRENT_STATUS request that
 * does not modify insulin delivery. A control/authorization/stream/signed message, or a
 * class outside the `request.currentStatus` package, can never be built — so it can never be
 * sent. This is a defensive second layer on top of pumpx2's own
 * `enableActionsAffectingInsulinDelivery` gate (which we never enable).
 */
object ProtocolProbe {

    /** The only package a probe is ever allowed to instantiate from. */
    const val REQUEST_PACKAGE = "com.jwoglom.pumpx2.pump.messages.request.currentStatus"

    /** Requests that take constructor parameters; everything else uses the no-arg ctor. */
    private val PARAMETRIC = mapOf(
        "IDPSegmentRequest" to IntArray(2), // (idpId, segmentIndex)
        "HistoryLogRequest" to IntArray(2), // (startSeq, count)
    )

    sealed interface Result {
        data class Ok(val message: Message) : Result
        data class Refused(val reason: String) : Result
    }

    /**
     * Build a request [Message] for [simpleName] (a class in [REQUEST_PACKAGE]), or refuse.
     * [arg1]/[arg2] are used only for the two parametric requests; ignored otherwise.
     */
    fun buildSafeRequest(simpleName: String, arg1: Int? = null, arg2: Int? = null): Result {
        val clean = simpleName.substringAfterLast('.')
        val fqcn = "$REQUEST_PACKAGE.$clean"

        val cls = try {
            Class.forName(fqcn)
        } catch (e: ClassNotFoundException) {
            return Result.Refused("unknown request '$clean'")
        }
        if (!Message::class.java.isAssignableFrom(cls)) {
            return Result.Refused("'$clean' is not a pump Message")
        }

        val message = try {
            if (PARAMETRIC.containsKey(clean) && arg1 != null && arg2 != null) {
                cls.getConstructor(Int::class.javaPrimitiveType, Int::class.javaPrimitiveType)
                    .newInstance(arg1, arg2) as Message
            } else {
                cls.getDeclaredConstructor().newInstance() as Message
            }
        } catch (t: Throwable) {
            return Result.Refused("could not construct '$clean': ${t.message}")
        }

        gate(message)?.let { return Result.Refused(it) }
        return Result.Ok(message)
    }

    /** Returns a refusal reason, or null if the message is a safe read. */
    private fun gate(message: Message): String? {
        // Package check: even if a class elsewhere were somehow reached, only the
        // currentStatus request package is ever acceptable.
        val pkg = message.javaClass.name.substringBeforeLast('.')
        if (pkg != REQUEST_PACKAGE) return "not a currentStatus request (${message.javaClass.name})"

        // MessageProps is a Java annotation; Kotlin exposes its members as properties.
        val props = message.props() ?: return "no MessageProps annotation"
        if (props.type != MessageType.REQUEST) return "not a REQUEST (${props.type})"
        if (props.characteristic != Characteristic.CURRENT_STATUS) {
            return "wrong characteristic (${props.characteristic})"
        }
        if (props.signed) return "signed message (control) — blocked"
        if (props.modifiesInsulinDelivery) return "modifies insulin delivery — blocked"
        if (props.stream) return "stream message — blocked"
        return null
    }

    /** A JSON-serialisable description of any received/sent message, for the explorer log. */
    fun describe(message: Message, direction: String, timestampMs: Long): Map<String, Any?> {
        val props = runCatching { message.props() }.getOrNull()
        return mapOf(
            "kind" to "probe",
            "direction" to direction, // "tx" (request we sent) | "rx" (response received)
            "ts" to timestampMs,
            "name" to message.javaClass.simpleName,
            "opcode" to (props?.opCode?.toInt()?.and(0xFF)),
            "characteristic" to (props?.characteristic?.name),
            "cargoHex" to hex(runCatching { message.cargo }.getOrNull()),
            "json" to runCatching { message.jsonToString() }.getOrNull(),
            "verbose" to runCatching { message.verboseToString() }.getOrNull(),
        )
    }

    private fun hex(bytes: ByteArray?): String? =
        bytes?.joinToString(" ") { "%02x".format(it) }
}
