package com.bgdude.app.pump

import com.jwoglom.pumpx2.pump.messages.models.PairingCodeType as X2PairingCodeType
import com.jwoglom.pumpx2.pump.messages.response.authentication.AbstractCentralChallengeResponse

/**
 * TASK-165: the pairing scheme→challenge decisions, extracted pure so they are
 * JVM-testable with no BLE dependencies. These pin the two commit-d18d72e fixes that
 * unblocked every JPAKE (6-digit) pump:
 *
 *  1. On a fresh pair, pumpx2 defaults to the legacy 16-char challenge-response
 *     (ApiVersionResponse hasn't arrived yet), which JPAKE firmware never answers —
 *     the scheme must default to SHORT_6CHAR unless a derived JPAKE secret from a
 *     prior pairing exists (re-auth uses that).
 *  2. JPAKE pumps supply NO CentralChallenge, so `pair()` must be invoked with a
 *     null challenge — gating it on `challenge != null` (the old behaviour) meant
 *     JPAKE pumps could never finish pairing.
 */
object PairingDecision {

    /** Everything a submitted code needs: `pair()` is ALWAYS invoked. */
    data class PairRequest(
        val challenge: AbstractCentralChallengeResponse?,
        val code: String,
        /** Never false — kept explicit so a regression to challenge-gating is loud. */
        val invokePair: Boolean = true,
    )

    /**
     * The request for a submitted pairing code. A null [pendingChallenge] is the
     * JPAKE path and still pairs; only the legacy 16-char flow carries a challenge.
     */
    fun pairRequest(
        pendingChallenge: AbstractCentralChallengeResponse?,
        code: String,
    ): PairRequest = PairRequest(challenge = pendingChallenge, code = code)

    /**
     * The scheme to select before scanning: SHORT_6CHAR (JPAKE) on a fresh pair,
     * or null to keep pumpx2's existing state when a derived JPAKE secret exists
     * (re-auth path).
     */
    fun initialScheme(jpakeDerivedSecret: String?): X2PairingCodeType? =
        if (jpakeDerivedSecret.isNullOrEmpty()) X2PairingCodeType.SHORT_6CHAR else null

    /** What the pairing dialog should ask for, given the active pumpx2 scheme. */
    fun promptType(scheme: X2PairingCodeType?): PairingCodeType =
        if (scheme == X2PairingCodeType.LONG_16CHAR) {
            PairingCodeType.LONG_16CHAR
        } else {
            PairingCodeType.SHORT_6CHAR
        }
}
