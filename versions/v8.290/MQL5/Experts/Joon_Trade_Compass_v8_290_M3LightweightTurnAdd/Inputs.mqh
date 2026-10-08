//+------------------------------------------------------------------+
//| Inputs.mqh - Strategy Tester / EA Inputs                         |
//| v5.07: explicit top-level tester input declaration unit          |
//+------------------------------------------------------------------+
#ifndef __JOON_INPUTS_MQH__
#define __JOON_INPUTS_MQH__

input group "M3 Low High Turn Pre-Signal (v8.290)"
input bool InpTurnTradeEnabled = true;       // exclusive new-signal orders; false restores legacy mode
input bool InpTurnReverseOnOpposite = true;  // close opposite position; reopen only after all exit deals
input bool InpTurnAddOnPre = true;           // same-side new PRE can add
input bool InpTurnAddOnDirection = true;     // same-side OFF->ON DIRECTION can add
input bool InpTurnPreEnabled = true;         // shared chart/CSV/order signal
input bool InpTurnRequireDivergence = true;
input int InpTurnLeftBars = 6;               // 2..12 prior bars, pivot uses one right closed bar
input double InpTurnMinReboundATR = 0.15;
input double InpTurnMaxDistanceATR = 1.25;
input double InpTurnMomentumDeadzoneATR = 0.01;
input int InpTurnSameSideCooldownBars = 3;
input bool InpTurnShowChart = true;
input bool InpTurnShowPivotAnchors = true;    // pivot dot appears ONLY after next bar closes
input int InpTurnChartHistoryBars = 2000;

input group "RANGE Profit Lock (Top)"
input double InpRangeProfitLockStartR = 0.80;      // Start trailing profit lock after this Peak R
input double InpRangeProfitLockPercent = 80.0;    // Lock this % of each layer's highest Peak R

input group "RANGE INITIAL Signal Count (Top)"
input int    InpRangeSignalsRequired = 3; // v8.00 compatibility display only; RANGE INITIAL is fixed at 3

input group "M3 Structure Recovery"
input int    InpM3StructureWarmupBars    = 400;   // closed M3 bars used only to rebuild current structure after startup/restart
input int    InpM3StructureWarmupMaxBars = 1600;   // adaptive recovery ceiling; not an entry filter

input group "AUTO Entry Path (Top)"
input ENUM_AUTO_ENTRY_PATH InpAutoEntryPath = AUTO_ENTRY_NORMAL_ONLY; // NORMAL ONLY default; Trigger order path OFF by default

input group "Chart Menu Settings (Top)"
input bool            InpSignalEnabled       = true;                      // SIGNAL ON/OFF
input bool            InpAutoTrading         = false;                     // AUTO ON/OFF
input ENUM_SIGNAL_DIRECTION InpSignalDirection = SIGNAL_BOTH;             // SIGNAL DIRECTION
input ENUM_TRADE_DIRECTION InpTradeDirection  = TRADE_BOTH;               // AUTO DIRECTION
input ENUM_TIMEFRAMES InpSignalTF            = PERIOD_M3;                 // LIVE unified TRADE TF; Strategy Tester uses tester Period (_Period)
input double          InpLots                = 0.10;                      // LOT
input double          InpRangeStopLossPercent = 0.20;                      // v4.71 RANGE default Broker SL %
input int             InpDefaultAdditionalEntries = 0;                    // MAX ADD count; 0 = OFF, any positive integer allowed
input int             InpMinimumAlertScore   = 0;                        // ALERT SCORE
input ENUM_WATCH_DISPLAY_MODE InpWatchMode = WATCH_MODE_CHART_ALERT;              // WATCH: OFF / CHART / CHART+ALERT
input bool            InpTerminalAlert       = true;                      // SYSTEM ALERT
input bool            InpMobileAlert         = false;                     // MOBILE ALERT
input bool            InpSystemEnabled       = true;                      // MASTER SYSTEM
input bool            InpTesterAutoStart     = true;                      // TESTER AUTO START

input group "Manual Assist State Evaluation"
input bool            InpAssistStateEnabled      = true;       // manual-trading state assistant
input int             InpAssistStateLookbackBars = 6;          // recent completed bars, clamped 4..12
input bool            InpAssistStateShowChart    = true;       // compact state panel + transition markers
input bool            InpAssistStateAlerts       = true;       // intuitive transition alerts
input bool            InpAssistStateWriteCSV     = true;       // one row per completed assist bar

input group "WATCH Observation Settings (PREP2 -> PREP3 -> READY)"
input int    InpWatchPrep2Score          = 55;
input int    InpWatchPrep3Score          = 70;
input int    InpWatchReadyScore          = 85;
input int    InpWatchResetScore          = 35;
input int    InpWatchCooldownBars        = 3;
input int    InpWatchRangeLookback       = 20;
input int    InpWatchStructureLookback   = 6;
input int    InpWatchFreshBars           = 3;
input double InpWatchCompressionRatio    = 0.78;
input bool   InpWatchShowChartMarkers    = true;
input bool   InpWatchWriteCSV            = true;
input bool   InpWatchUseTriggerPrice     = true;  // observation-only directional price boundary
input double InpWatchTriggerBufferRange  = 0.12;  // shared visible WATCH Trigger buffer
input bool   InpWatchShowTriggerLine     = true;  // show active WATCH trigger price/position


input group "TREND Strategy Settings"
input bool   InpUseEarlyEntry          = true;
input int    InpEarlyEntryScore        = 60; // same menu lot; no split order
input double InpEarlyMAGapRange        = 0.35; // MA7 may approach MA22 within avg-range fraction
input bool   InpUseNoTradeZone          = true;
input int    InpMinimumEntryConfidence  = 70; // absolute directional confidence required
input int    InpNoTradeMinimumFlags     = 3;  // ambiguity conditions required to block entry
input double InpFlatMA22RangeFactor     = 0.12; // MA22 slope / average bar range
input double InpNarrowMAGapRangeFactor  = 0.20; // MA7-MA22 gap / average bar range
input double InpSmallBoxRangeFactor     = 2.00; // last 3-bar range / average bar range
input int    InpMinimumConfidenceGap    = 10; // long-short confidence separation
input bool   InpUsePatternLearning       = true;
input int    InpPatternLookback          = 12;
input double InpDoubleTopBottomTolerance = 0.30; // fraction of average bar range
input double InpRetestToleranceRange     = 0.35; // fraction of average bar range
input double InpLongWickBodyRatio        = 1.50;
input int    InpPatternBonus             = 10;
input int    InpRetestBonus              = 15;
input int    InpFailedBreakPenalty       = 20;
input double InpStrongHoldMinimumR          = 0.00; // legacy compatibility; R no longer gates strong hold
input int    InpStrongHoldMinimumScore      = 4;    // directional evidence count required
input int    InpProfitProtectWeakBars       = 2;    // consecutive weak closed bars before protect mode
input int    InpHoldStructureLookbackBars    = 5;    // HH/HL or LL/LH structure evaluation
input int    InpHoldWarningConfirmBars       = 1;    // persistent weakening before WARNING
input int    InpHoldExitCandidateConfirmBars = 1;    // 2-of-3 failure persistence before candidate
input double InpPartialExitMinimumR         = 0.75; // partial exit only after useful profit
input int    InpReentryMinimumBars           = 1;    // fresh setup delay after strategy/TP exit
input bool   InpUseGivebackReentry          = false; // faster same-direction re-entry after profit giveback
input int    InpGivebackReentryWindowBars    = 20;
input int    InpGivebackReentrySignals       = 2;
input int    InpGivebackReentryMinimumScore  = 65;
input double InpGivebackReentryPriceBufferRange = 0.15;
input bool   InpGivebackReentryRequireReacceleration = true;
input bool   InpUseInitialDirectionalHoldProtection = true; // initial entry: suppress profit giveback exits while STRONG/NORMAL direction remains aligned
input bool   InpUseRProfitProtection       = true;
input double InpProfitProtectTriggerR      = 0.35; // first profit-protection activation
input double InpProfitLockStage1R          = 0.00; // near breakeven after 0.35R peak
input double InpProfitProtectStage2R       = 0.75;
input double InpProfitLockStage2R          = 0.15;
input double InpProfitProtectStage3R       = 1.25;
input double InpProfitLockStage3R          = 0.40;
// v8.60 M3 AUTO unified position protection. R only arms a protection
// stage; the actual stop price is constrained by confirmed M3 structure.
input double InpM3MaxInitialRiskATR            = 1.50; // maximum initial structural risk in ATR
input double InpProfitGivebackPercent      = 40.0; // protect-state giveback exit
input double InpNormalHoldGivebackPercent  = 60.0; // normal-hold giveback exit
input double InpMinimumGivebackPeakR       = 0.50; // ignore percentage noise below this peak
input double InpStrongHoldMinimumLockR     = 0.15; // loose minimum lock during strong trend
input double InpStrongHoldGivebackUnder2R  = 55.0;
input double InpStrongHoldGivebackUnder3R  = 40.0;
input double InpStrongHoldGivebackOver3R   = 30.0;
input bool   InpUseEntryTypeProtection       = true;
input double InpChaseProtectTriggerR          = 0.20;
input double InpChaseLockStage1R              = 0.02;
input double InpChaseProtectStage2R           = 0.40;
input double InpChaseLockStage2R              = 0.12;
input double InpChaseProtectStage3R           = 0.70;
input double InpChaseLockStage3R              = 0.30;
input double InpChaseNormalGivebackPercent    = 40.0;
input double InpChaseProtectGivebackPercent   = 27.5;
// ADD_ENTRY protects the whole averaged group faster than INITIAL, but less
// aggressively than a post-exit REENTRY/CHASE position.
input double InpAddProtectTriggerR            = 0.25;
input double InpAddLockStage1R                = 0.01;
input double InpAddProtectStage2R             = 0.50;
input double InpAddLockStage2R                = 0.10;
input double InpAddProtectStage3R             = 0.85;
input double InpAddLockStage3R                = 0.25;
input double InpAddStrongGivebackPercent      = 40.0;
input double InpAddNormalGivebackPercent      = 30.0;
input double InpAddProtectGivebackPercent     = 20.0;
input bool   InpEnableChaseTrendPromotion      = true;
input int    InpChasePromotionMinimumScore     = 6;    // directional evidence count
input int    InpChasePromotionConfirmBars      = 2;    // consecutive closed bars
input bool   InpChasePromotionRequireTradingTF        = true;

input group "Unified Trading TF Direction / Legacy Trend Compatibility"
input int    InpTradingTFDirectionMinimumScore       = 55;
input int    InpTradingTFDirectionStrongScore        = 70;
input int    InpTradingTFDirectionMinimumGap         = 10;
input bool   InpRequireTradingTFBiasForInitialEntry  = true;
input bool   InpRequireTradingTFMA22Trigger          = true;
input double InpTradingTFMA22TouchToleranceRange     = 0.25;
input bool   InpAllowRangeMA22DirectCross      = true;
input int    InpM15TrendMinimumScore           = 55;
input int    InpM15TrendMinimumGap             = 10;
input double InpM4MA7TouchToleranceRange       = 0.20;
input bool   InpRequireM4MACDReExpansion       = true;
input bool   InpRequireM4DeltaReExpansion      = true;

input group "Unified Signal / Entry Control"
input bool   InpRequireInternalEntryStateForAuto = true; // signals and orders share one state snapshot
input bool   InpRequireTrendBiasForAdds           = true; // M15 direction must remain valid before adding
input int    InpRangeMaximumAdditionalEntries     = 0;    // legacy compatibility only; runtime MAX ADD numeric setting is authoritative
input bool   InpRangeRequireEdgeReversalForEntry  = true; // REVERSAL must precede ENTRY

input group "Common Chart Signal"
input int    InpChartSignalScore          = 55; // direction-confirmed chart/counter signal threshold
input int    InpChartStrongSignalScore    = 70; // strong signal / alert threshold
input int    InpChartSignalMinimumGap     = 5;  // long-short score separation when BOTH
input bool   InpChartSignalRequireM5Bias  = false; // optional higher-timeframe confirmation
input bool   InpBlockCounterTrendEarlySignal = true; // block one-bar reversal arrows against dominant MACD/Delta trend
input bool   InpAllowTrendContinuationAuto   = true; // permit controlled continuation entry without fresh MA22 touch
input double InpContinuationMaxFastDistance  = 2.00; // max MA7 distance in average-bar ranges
input bool   InpContinuationRequireBreak      = true; // require micro/prior swing break for continuation fill

input group "AUTO Start Bias"
input bool   InpUseAutoStartBias             = true; // analyze chart flow only when AUTO changes OFF -> ON
input int    InpAutoStartBiasLookbackBars     = 20;   // completed bars used for the initial context
input int    InpAutoStartBiasMaximumBars      = 5;    // bias expires after this many completed bars
input int    InpAutoStartBiasMinimumEvidence  = 3;    // MA, price, MACD, Delta evidence needed
input int    InpPreDirectionReleaseSignals     = 3;    // opposite confirmed signals required before release
input int    InpPreDirectionReleaseScore       = 70;   // minimum 0..100 release score

input group "Legacy Direction Quality Diagnostics"
input bool   InpUseDirectionQualityFilter      = false;  // diagnostic calculation only; no SIGNAL/AUTO/HOLD/SL veto
input int    InpMinimumDirectionQuality        = 50;    // minimum 0..100 directional quality for the selected side
input int    InpDirectionQualityLookback       = 8;     // closed bars used for MA-cross / persistence checks
input int    InpDirectionMaximumMACrosses      = 3;     // repeated MA7/MA22 crossings indicate chop
input double InpDirectionMinimumMAGapRange     = 0.10;  // minimum MA7-MA22 gap in average-bar ranges
input double InpDirectionMinimumDeltaRatio     = 0.60;  // same-side delta bar ratio needed for full delta score
input bool   InpDirectionBlockCompressedChop   = true;  // hard block narrow, flat, repeatedly crossing congestion
input int    InpMinimumDirectionQualityGap     = 10;    // selected side must exceed the opposite side by this amount
input double InpDirectionMinimumEfficiency     = 0.25;  // net movement / total close-to-close path
input bool   InpDirectionBlockNeutralFlow       = true;  // block low-efficiency mixed MACD/Delta sideways flow
input int    InpDirectionSlopeBonus              = 10;    // MA7/MA22 same-side slope quality
input int    InpDirectionGapExpansionBonus       = 10;    // MA7-MA22 gap expanding in selected direction
input int    InpDirectionMACDExpansionBonus      = 10;    // MACD magnitude expanding in selected direction
input int    InpDirectionDeltaPersistenceBars    = 3;     // consecutive same-side delta bars
input int    InpDirectionDeltaPersistenceBonus   = 10;    // bonus for persistent order flow
input double InpDirectionLateDistanceRange       = 2.25;  // MA7 distance in average ranges treated as late
input double InpDirectionExtremeDeltaMultiplier  = 2.00;  // extreme current delta / average absolute delta
input int    InpDirectionLateTrendPenalty        = 20;    // late chase penalty when distance and flow are extended
input group "System"
input ulong           InpMagicNumber         = 7262026;
input int             InpDeviationPoints     = 30;

enum ENUM_CSV_STORAGE_LOCATION
{
   CSV_STORAGE_TERMINAL = 0,
   CSV_STORAGE_COMMON   = 1
};

enum ENUM_TESTER_MODEL_LABEL
{
   TESTER_MODEL_REAL_TICKS = 0,
   TESTER_MODEL_EVERY_TICK = 1,
   TESTER_MODEL_M1_OHLC    = 2,
   TESTER_MODEL_OPEN_PRICE = 3,
   TESTER_MODEL_MATH       = 4
};

input group "AUTO Trade Log"
input bool   InpEnableAutoTradeLog       = true;  // write AUTO trade lifecycle deals to CSV
input bool   InpTradeLogIncludePartials  = true;  // include partial reductions
input bool   InpTradeLogPrintFileName    = true;  // print the active log path at startup
input bool   InpEnablePatternDatasetExport = false; // export closed-bar pattern features to CSV
input bool   InpEnableSignalDatasetExport  = false; // export closed-bar signal/score snapshots to CSV
input ENUM_CSV_STORAGE_LOCATION InpCsvStorageLocation = CSV_STORAGE_TERMINAL; // TERMINAL=MQL5\Files, COMMON=Terminal Common\Files
input datetime InpTesterFrom = 0; // strategy-test start date recorded in CSV metadata
input datetime InpTesterTo   = 0; // strategy-test end date recorded in CSV metadata
input ENUM_TESTER_MODEL_LABEL InpTesterModel = TESTER_MODEL_REAL_TICKS; // model label recorded in CSV metadata

input group "Test Line Menu"
input double InpInitialDistancePercent = 1.00;
input int    InpMenuRightMargin        = 45;
input int    InpMenuWidth              = 250;
input bool   InpMenuStartAsBuy         = true;

input group "Indicator Files"
input bool   InpRequireMACDColor = false;

input group "Entry"
input ENUM_SHORT_TERM_ENTRY_MODE InpShortTermEntryMode = ENTRY_CLASSIC_M2;
input int    InpSignalValidBars       = 3;
input int    InpDeltaAveragePeriod    = 10;
input double InpSignalDeltaMultiplier = 1.00; // same relaxed strength as AUTO
input double InpEntryDeltaMultiplier  = 1.00;
input bool   InpAllowContinuation     = true;  // signal alert only
input int    InpCooldownBars          = 1;
input int    InpStopLossCooldownBars  = 1;
input int    InpFastMAPeriod          = 7;
input int    InpSlowMAPeriod          = 22;
input int    InpPullbackLookbackBars  = 5;
input double InpPullbackTolerancePoints = 50.0;
input double InpMaximumEntryDeviationPoints = 100.0; // 0 = disabled
input double InpMaximumSpreadPoints   = 0.0;   // 0 = broker-independent disabled
input double InpMaximumTotalLots      = 0.0;   // 0 = disabled
input int    InpMaximumOrderFailures  = 3;
input bool   InpBlockWhenManualPositionExists = true; // non-hedging legacy safety; HEDGING ignores foreign/manual positions
input int    InpBothDirectionMinimumScoreGap = 5;

input group "FAST MOMENTUM Entry"
input int    InpFastMomentumWindowSeconds = 6;
input int    InpFastMomentumMinimumTicks  = 12;
input double InpFastMomentumDirectionalRatio = 0.62;
input double InpFastMomentumMinimumMovePercent = 0.015;
input int    InpFastMomentumBreakoutLookbackTicks = 8;
input double InpFastMomentumBreakoutBufferPoints = 0.0;
input bool   InpFastMomentumRequireClosedDelta = false;
input bool   InpFastMomentumRequireMACD = true;
input bool   InpFastMomentumAllowMACDPreZero = true; // rising/falling live MACD may enter before zero cross
input bool   InpFastMomentumRequireMATrend = true;
input double InpFastMomentumMaximumSpreadPoints = 0.0; // 0 = dynamic only
input double InpFastMomentumMaximumSpreadToMoveRatio = 0.35;

input group "Structure / Signal Score"
input int    InpTrendMAPeriod          = 70;
input int    InpSupportMAPeriod        = 111;
input int    InpLongMAPeriod           = 200;
input int    InpDominanceLookback      = 5;
input int    InpDominanceMinBars       = 3;
input double InpDominanceWeakLevel     = 10.0;
input double InpDominanceStrongLevel   = 30.0;
input int    InpSwingLookback          = 12;
input int    InpCompressionLookback    = 20;
input int    InpCompressionRecentBars  = 6;
input double InpCompressionRatio       = 0.65;
input double InpBreakoutVolumeFactor   = 1.50;
input int    InpWatchScore             = 50;
input int    InpEntryScore             = 65;
input int    InpConfirmEntryScore      = 80;
input int    InpStrongSignalScore      = 90;
input double InpMaximumChaseRange      = 1.50; // MA22 distance / avg bar range

input group "Entry Timing Window"
input int    InpTimingBreakLookback     = 3;    // first micro swing break window
input double InpTimingMaxFastDistance   = 1.25; // max distance from MA7 / average bar range
input bool   InpUseEntryScoreForSignal  = true; // TREND signal display follows entry threshold
input bool   InpNoTradeFlagsDiagnosticOnly = true; // flags are displayed but do not block a valid timing trigger

input group "RANGE 3-Signal AUTO Entry"
input ENUM_RANGE_TRIGGER_FINALS_REQUIRED InpRangeTriggerFinalsRequired = RANGE_TRIGGER_FINALS_1; // Trigger break -> new Accepted FINAL count (1/2/3)
input double InpRangeTriggerSLPercent = 0.14; // RANGE Trigger INITIAL only; SL and original 1R
input double InpRangeTriggerMinDistanceRange = 0.30; // RANGE Trigger minimum distance / M5 avg range
input int    InpRangeTriggerEntryExpiryBars = 6; // Trigger FIRE order authority max completed M2 bars
input int    InpRangeSignalWindowBars      = 7;  // compatibility/diagnostic; INITIAL 3X is fixed to 7 completed bars
input bool   InpRangeThreeSignalBypassStrategyFilters = true; // keep execution safety, bypass duplicate momentum filters
input bool   InpRangeApprovedEntryBypassStrategyFilters = true; // all RANGE-approved entries bypass duplicated TREND momentum filters
input bool   InpRangeRequirePostThirdDirectionConfirm = true; // v8.00 legacy compatibility; third-FINAL High/Low confirmation is canonical
input int    InpRangeDirectionConfirmMaxBars       = 3;    // legacy compatibility only; v1.95 does not timeout an armed third-signal breakout
input double InpRangeDirectionConfirmBufferRange   = 0.05; // legacy compatibility only; v8.00 uses exact third-FINAL High/Low with no extra buffer

input group "Fast Simple Execution"
input bool   InpUseFastSimpleEngine            = true;
input int    InpRangePostStopMinimumBars       = 0; // next fresh closed-bar signal may start the new 3-signal set
input int    InpTrendPostStopMinimumBars       = 1; // one completed bar before a fresh TREND setup
input bool   InpRangeUseTwoOfThreeFailureExit  = true;
input int    InpRangeFailureEvidenceRequired   = 2; // MACD, Delta, MA: any 2
input int    InpTrendFailureEvidenceRequired   = 3; // TREND remains stricter

input group "RANGE Final Entry Approval"
input bool   InpUseRangeFinalEntryFilter       = false;  // 3 signals -> MACD/Delta/MA -> entry
input int    InpRangeFinalWeaknessBars          = 3;     // consecutive weakening bars for MACD/Delta veto
input int    InpRangeStrengthLookbackBars       = 20;    // completed bars used for relative MACD/Delta strength
input double InpRangeMACDStrengthFactor         = 0.60;  // MACD must exceed this fraction of recent abs average
input double InpRangeDeltaStrengthFactor        = 0.60;  // Delta must exceed this fraction of recent abs average

input group "RANGE Late Move Filter"
input bool   InpUseRangeLateMoveFilter     = true; // RANGE only: block late chase entries after momentum fades near the opposite edge
input int    InpRangeLateMoveBars          = 3;    // completed bars used to confirm MACD/Delta deceleration (2-5)
input int    InpRangeLateMoveBlockScore    = 3;    // block when this many conditions are true: MACD fade, Delta fade, bad range location
input double InpRangeLateMoveEdgeZone      = 0.30; // BUY blocked in upper 30%, SELL blocked in lower 30% when combined with fading momentum
input int    InpTrendStrengthLookbackBars       = 20;    // TREND completed bars for relative MACD/Delta strength
input double InpTrendMACDStrengthFactor         = 0.60;  // TREND MACD minimum relative strength
input double InpTrendDeltaStrengthFactor        = 0.60;  // TREND Delta minimum relative strength
input int    InpStrongPersistenceLookbackBars   = 3;     // weighted strength-region sample length
input int    InpStrongPersistenceMinimumBars    = 2;     // converted to equivalent weighted direction-ratio threshold
input double InpStrongMomentumRetention         = 0.85;  // current strength may retain at least 85% of previous bar
input bool   InpRequireDeltaEMADirection         = true;  // Delta EMA must agree with direction and not materially weaken

input group "RANGE Signal Display (Does Not Change AUTO Entry)"
input int    InpRangeSignalMinimumGap   = 3;    // display-side long/short score separation
input int    InpRangeEarlyTurnBonus     = 10;   // display score only; AUTO score is unchanged
input bool   InpUseRangeEarlySignal       = true; // permit a directional turn before MACD/Delta zero confirmation
input int    InpRangeEarlySignalScore      = 50;   // minimum display score for EARLY signal/counter
input bool   InpRangeEarlyRequireRawDelta  = true; // current completed raw delta must agree with direction
input int    InpOppositeSignalCountDecay   = 1;    // legacy compatibility; INITIAL 3X opposite FINAL now resets the episode
input int    InpRangeEdgePenaltyRelief  = 10;   // display-only relief near opposite range edge

input group "Range Pattern Filter"
input bool   InpUseRangePatternFilter  = true;
input int    InpPatternRangeLookback   = 12;
input double InpRangeEdgeZone          = 0.25; // outer 25% of recent range
input double InpRejectionWickBodyRatio = 1.50;
input double InpMinimumPatternBodyRatio = 0.20;
input bool   InpAllowEngulfingPattern  = true;
input bool   InpAllowRejectionPattern  = true;
input bool   InpBlockOppositeRangeEdge = true;

input group "Adaptive Range / Chase Entry Filter"
input bool   InpUseRangeLocationScore = true;
input int    InpRangeLocationLookbackBars = 40;
input int    InpRangeLocationMaximumScore = 30; // favourable edge +30, opposite edge -30
input double InpRangeMinimumWidthPoints = 20.0;
input bool   InpBlockATRChaseEntry = true;
input int    InpATRChaseLookbackBars = 8;
input int    InpATRCalculationPeriod = 14;
input double InpATRChaseMaximumMove = 1.00; // block after same-side move >= 1 ATR
input bool   InpBlockMACDDeceleration = true;
input bool   InpAllowStrongRangeBreakout = true;
input double InpBreakoutBufferATR = 0.10;
input bool   InpBlockDeltaExhaustion = true;
input int    InpDeltaExhaustionLookback = 3; // seed length; v3.68 evaluates a strength region, not consecutive bars
input double InpDeltaMinimumStrengthRatio = 0.65;

input group "Directional Persistence / Absorption Filter"
input bool   InpUseDirectionalPersistenceFilter = true;
input int    InpDirectionalPersistenceLookback = 6; // evidence-region sample length
input int    InpMinimumSameDirectionDeltaBars = 4; // converted to equivalent directional-ratio threshold
input double InpMinimumDeltaDominanceRatio = 1.50;
input int    InpMACDPersistenceLookback = 5; // evidence-region sample length
input int    InpMinimumSameDirectionMACDBars = 4; // converted to equivalent weighted zone-ratio threshold
input int    InpMinimumMACDExpansionBars = 2; // converted to equivalent weighted expansion-ratio threshold
input bool   InpBlockEdgeDeltaAbsorption = true;
input int    InpAbsorptionLookbackBars = 5; // absorption pressure-region sample length
input int    InpAbsorptionOppositeMinimumBars = 3; // legacy-compatible input; pressure ratio is authoritative in v3.68
input double InpAbsorptionOppositeSumRatio = 1.00;
input double InpAbsorptionEdgeDistanceATR = 0.50;

input group "Gold / WTI / Nasdaq / Copper Common Auto Filter"
input bool               InpUseAssetProfile       = true;
input ENUM_ASSET_PROFILE InpAssetProfile          = ASSET_AUTO;
input int                InpRangeAveragePeriod    = 10;
input bool               InpBlockOversizedBar     = true;

input group "Additional Entry"
input double InpMaximumGroupRiskPercent  = 0.45; // legacy compatibility only; RANGE ADD risk gate removed in v4.36
input bool   InpRequireTradingTFDirectionForAdd = true;
input int    InpMinimumAdditionalEntryBars = 1; // never add on the initial-entry bar
input double InpMinimumAdditionalProgressR = 0.10; // favourable progress from first fill

input group "Exit"
input double InpEmergencyDeltaMultiplier = 1.50;
input int    InpExitConfirmBars           = 2;
input int    InpMACDReferenceBars         = 20;
input double InpMACDZeroBreakFactor       = 0.25;
input int    InpMaximumHoldingBars        = 0; // 0 = disabled
input int    InpEarlyFailureCheckBars     = 5; // 0 = disabled
input double InpEarlyFailureMaximumR      = 0.10;
input bool   InpExitOnConfirmedStrategyFailure = true; // profit-only strategy exit

input group "RANGE Chase Early Stop"
input int    InpChaseMaxWaitBars           = 2;    // bars allowed to prove immediate continuation
input double InpChaseMinProgressRange      = 0.10; // required favourable progress / average bar range
input double InpChaseInvalidationBufferRange = 0.10; // entry signal candle invalidation buffer / avg range
input int    InpChaseFailureConfirmBars    = 1;    // completed bars required for 2-of-3 failure exit
input int    InpChaseOppositeConditions    = 2;    // MACD, Delta, MA/price failures required


input group "Short-Term Price Action Engine"
input bool   InpUseShortTermPriceActionEngine = true; // v8.36: single short-term AUTO entry model
input int    InpShortTermStructureBars = 3;          // legacy compatibility; M3 AUTO no longer uses fixed bar counts
input double InpShortTermImpulseATR = 0.55;           // legacy compatibility; M3 AUTO uses structure events
input double InpShortTermMaxRetrace = 0.85;           // legacy compatibility; M3 AUTO uses structural setup
input double InpShortTermMinReaccelBody = 0.15;      // legacy compatibility; M3 AUTO uses structural trigger
input double InpShortTermVolumeRatio = 0.75;         // re-acceleration volume / pullback volume
input double InpShortTermMaxEntryATR = 0.50;          // legacy execution-distance input; M3 structural location caps independently
input int    InpShortTermSetupExpiryBars = 3;         // M3 trend setup remains triggerable for this many new bars
input double InpShortTermStopBufferATR = 0.08;        // broker SL beyond pullback extreme

input group "Short-Term Profit Taking"
input bool   InpUseShortTermProfitTaking  = true;
input double InpShortTermBreakEvenPercent = 0.08;
input double InpShortTermWeakExitPercent  = 0.12;
input int    InpShortTermWeakConditions   = 2;
input double InpShortTermFinalPercent     = 0.18;
input double InpShortTermBreakEvenLockPercent = 0.01;

input int    InpRangeProfitExitCooldownBars    = 2;    // completed M2 bars before same-direction RANGE re-entry

input group "RANGE Simple Hold"
input bool   InpUseRangeSimpleHold = true; // hold profitable RANGE positions while MACD, delta and MA7 remain aligned
input int    InpRangeSimpleHoldMinimumBars = 1; // minimum completed bars after entry before simple hold can activate

input group "Range Profit Guard"
input bool   InpUseRangeProfitGuard = true;
input double InpProfitGuardActivationPercent = 0.03; // start protecting open profit
input double InpProfitGuardLockPercent = 0.005;      // broker-side minimum locked profit
input double InpProfitGuardMaximumGivebackPercent = 0.02; // warning/partial-tier absolute giveback
input double InpStrongHoldMaximumGivebackPercent = 0.04; // strong-hold minimum absolute giveback
input double InpRangeNormalHoldPeakGivebackPercent = 35.0; // normal hold: allow this share of peak profit
input double InpRangeStrongHoldPeakGivebackPercent = 50.0; // strong hold: allow this share of peak profit

input group "Entry Confidence Profit Management"
input bool   InpUseEntryConfidenceProfitManagement = true; // keep HOLD logic, but protect low-confidence RANGE entries earlier
input double InpMediumConfidenceActivationMultiplier = 0.75; // MEDIUM guard activation versus normal
input double InpLowConfidenceActivationMultiplier = 0.50;    // LOW guard activation versus normal
input double InpMediumConfidenceGivebackMultiplier = 0.75;   // MEDIUM allowed giveback versus normal
input double InpLowConfidenceGivebackMultiplier = 0.50;      // LOW allowed giveback versus normal
input int    InpMediumConfidenceHoldScorePenalty = 5;         // still permits STRONG/NORMAL HOLD when evidence is strong
input int    InpLowConfidenceHoldScorePenalty = 10;

input group "Range Hold Thresholds"
input int    InpHoldScoreStrongThreshold = 80;
input int    InpHoldScoreTrailingThreshold = 60;
input int    InpHoldScorePartialThreshold = 40;
input double InpHoldScorePartialClosePercent = 50.0;
input double InpRangePartialMinimumPercent = 0.06;
input int    InpRangeMaximumHoldingBars = 15;
input int    InpRangeWeaknessConfirmBars = 2;
input double InpRangeCenterProgress = 0.50;
input double InpRangeTargetProgress = 0.80;

input group "Chart Pattern Lifecycle Assist"
input bool   InpUsePatternLifecycleAssist = true;
input int    InpPatternLifecycleLookback = 8;
input double InpPatternOppositeDeltaExtreme = 1.50;
input double InpPatternCompressionRatio = 0.70;
input int    InpPatternRangeMaximumAdjustment = 10;
input bool   InpPatternBlockAddsOnFatigue = true;

input group "Chase / Breakout Trend Hold"
input bool   InpUseChaseTrendHold = true;
input int    InpChaseTrendLookbackBars = 6;
input int    InpChaseMACDMinimumBars = 5;
input int    InpChaseDeltaMinimumBars = 4;
input int    InpChaseTrendMinimumConditions = 4;
input int    InpChaseWeaknessConfirmBars = 2;
input double InpChaseStrongGivebackPercent = 0.08;
input double InpChaseWeakGivebackPercent = 0.04;

input group "Break Even / Trailing"
input bool   InpUseBreakEven          = false;
input double InpBreakEvenTriggerPoints = 500.0;
input double InpBreakEvenLockPoints    = 20.0;
input bool   InpUseTrailingStop       = false;
input double InpTrailingStartPoints   = 700.0;
input double InpTrailingDistancePoints = 350.0;
#endif // __JOON_INPUTS_MQH__
