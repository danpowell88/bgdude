# Pump history-log decode coverage

> **Generated and verified by `HistoryLogCoverageTest`** (issue #94). The totals and the
> decoded list below are derived from the pumpx2 jar on the test classpath and from
> `PumpHistoryMapper`'s own `is X` branches — the test fails if this file drifts from
> either, so it cannot quietly overstate what bgdude understands.

pumpx2 1.9.0 exposes **134 event types**. bgdude has **8 decoded**
(**6.0%**); the remaining 126 stream through as raw entries with a timestamp
and a sequence number, and are shown in the raw viewer but not turned into therapy data.

## Why the rest are not decoded

Not an oversight, and not a backlog to burn down for its own sake. The decoded eight are
the events that change what the app *says*: insulin delivered, carbs entered, basal rate,
cartridge/cannula changes, alarms and alerts, and CGM readings. Decoding a settings-change
event or an internal state transition would add a row to a log nobody reads and a decoder
nobody can verify without a pump that emits it.

The value of this report is knowing *which* events are going past undecoded, so that when
something unexplained shows up in the history the raw viewer can name it.

## Decoded

- `AlarmActivatedHistoryLog`
- `AlertActivatedHistoryLog`
- `BasalRateChangeHistoryLog`
- `BolusCompletedHistoryLog`
- `CannulaFilledHistoryLog`
- `CarbEnteredHistoryLog`
- `CartridgeFilledHistoryLog`
- `CgmDataGxHistoryLog`

## Not decoded

**AA** (3)

- `AAExerciseChoiceChangeHistoryLog`
- `AAExerciseTimeChangeHistoryLog`
- `AATdiEstChangeHistoryLog`

**Aa** (6)

- `AaAutoBolusRejectedHistoryLog`
- `AaDeliveryStatusChangeHistoryLog`
- `AaEnableSettingChangeHistoryLog`
- `AaSleepScheduleChangeHistoryLog`
- `AaTdiSettingChangeHistoryLog`
- `AaWeightSettingChangeHistoryLog`

**Alarm** (2)

- `AlarmAckHistoryLog`
- `AlarmClearedHistoryLog`

**Alert** (2)

- `AlertAckHistoryLog`
- `AlertClearedHistoryLog`

**Basal** (2)

- `BasalDeliveryHistoryLog`
- `BasalIqSettingsChangeHistoryLog`

**Bolus** (5)

- `BolusActivatedHistoryLog`
- `BolusDeliveryHistoryLog`
- `BolusRequestedMsg1HistoryLog`
- `BolusRequestedMsg2HistoryLog`
- `BolusRequestedMsg3HistoryLog`

**Cartridge** (2)

- `CartridgeInsertedHistoryLog`
- `CartridgeRemovedHistoryLog`

**Cgm** (47)

- `CgmAlertAckDexHistoryLog`
- `CgmAlertAckHistoryLog`
- `CgmAlertActivatedDexHistoryLog`
- `CgmAlertActivatedFsl2HistoryLog`
- `CgmAlertActivatedHistoryLog`
- `CgmAlertClearedDexHistoryLog`
- `CgmAlertClearedFsl2HistoryLog`
- `CgmAlertClearedHistoryLog`
- `CgmAnnuSettingsHistoryLog`
- `CgmBleCalibrationEvtG7HistoryLog`
- `CgmCalibrationG7HistoryLog`
- `CgmCalibrationGxHistoryLog`
- `CgmCalibrationHistoryLog`
- `CgmDataFsl2HistoryLog`
- `CgmDataFsl3HistoryLog`
- `CgmDataSampleHistoryLog`
- `CgmFraSettingsHistoryLog`
- `CgmHgaSettingsHistoryLog`
- `CgmInactiveG7HistoryLog`
- `CgmInactiveGxHistoryLog`
- `CgmJoinSessionFsl2HistoryLog`
- `CgmJoinSessionFsl3HistoryLog`
- `CgmJoinSessionG7HistoryLog`
- `CgmJoinSessionHistoryLog`
- `CgmLgaSettingsHistoryLog`
- `CgmOorSettingsHistoryLog`
- `CgmPairingCodeG7HistoryLog`
- `CgmRejoinSessionHistoryLog`
- `CgmRraSettingsHistoryLog`
- `CgmSensorTypeChangeHistoryLog`
- `CgmSessionTypeChangeHistoryLog`
- `CgmStartSensorReqG7HistoryLog`
- `CgmStartSessionFsl2HistoryLog`
- `CgmStartSessionHistoryLog`
- `CgmStartSessionReqGxHistoryLog`
- `CgmStopSessionFsl2HistoryLog`
- `CgmStopSessionFsl3HistoryLog`
- `CgmStopSessionG7HistoryLog`
- `CgmStopSessionHistoryLog`
- `CgmStopSessionMsg1HistoryLog`
- `CgmStopSessionMsg2HistoryLog`
- `CgmStopSessionReqG7HistoryLog`
- `CgmStopSessionReqGxHistoryLog`
- `CgmTransmitterIdGxHistoryLog`
- `CgmTransmitterIdHistoryLog`
- `CgmTransmitterVersionGxHistoryLog`
- `CgmUnexpectedGeAlertHistoryLog`

**ControlIQ** (2)

- `ControlIQPcmChangeHistoryLog`
- `ControlIQUserModeChangeHistoryLog`

**Daily** (2)

- `DailyBasalHistoryLog`
- `DailyStatusHistoryLog`

**Data** (1)

- `DataLogCorruptionHistoryLog`

**Date** (1)

- `DateChangeHistoryLog`

**Fill** (1)

- `FillEstimateFinalHistoryLog`

**Hypo** (2)

- `HypoMinimizerResumeHistoryLog`
- `HypoMinimizerSuspendHistoryLog`

**Idp** (5)

- `IdpActionHistoryLog`
- `IdpActionMsg2HistoryLog`
- `IdpBolusHistoryLog`
- `IdpListHistoryLog`
- `IdpTimeDependentSegmentHistoryLog`

**Log** (1)

- `LogErasedHistoryLog`

**New** (1)

- `NewDayHistoryLog`

**Other** (29)

- `ArmInitHistoryLog`
- `BGHistoryLog`
- `BolexActivatedHistoryLog`
- `BolexCompletedHistoryLog`
- `ConfirmCartridgeFilledHistoryLog`
- `CorrectionDeclinedHistoryLog`
- `DexcomG6CGMHistoryLog`
- `DexcomG7CGMHistoryLog`
- `FactoryResetHistoryLog`
- `HistoryLog`
- `MalfunctionAckHistoryLog`
- `MalfunctionHistoryLog`
- `PlgsPeriodicHistoryLog`
- `PrimeInprocessHistoryLog`
- `ReminderActivatedHistoryLog`
- `ReminderDismissedHistoryLog`
- `ReminderSnoozedHistoryLog`
- `ShelfModeHistoryLog`
- `SnoozeActivatedHistoryLog`
- `TipsErrorHistoryLog`
- `TipscReqPrimeCannulaHistoryLog`
- `TubingFilledHistoryLog`
- `UnknownHistoryLog`
- `UpdateStatusHistoryLog`
- `VersionInfoHistoryLog`
- `VersionsAHistoryLog`
- `WumpCartridgeFilledHistoryLog`
- `WumpCartridgeRemovedHistoryLog`
- `WumpOcclusionDebugHistoryLog`

**Param** (4)

- `ParamChangeGlobalSettingsHistoryLog`
- `ParamChangePumpSettingsHistoryLog`
- `ParamChangeRemSettingsHistoryLog`
- `ParamChangeReminderHistoryLog`

**Pump** (2)

- `PumpingResumedHistoryLog`
- `PumpingSuspendedHistoryLog`

**Temp** (2)

- `TempRateActivatedHistoryLog`
- `TempRateCompletedHistoryLog`

**Time** (1)

- `TimeChangedHistoryLog`

**Usb** (3)

- `UsbConnectedHistoryLog`
- `UsbDisconnectedHistoryLog`
- `UsbEnumeratedHistoryLog`

