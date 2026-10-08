//+------------------------------------------------------------------+
//| Joon_Trade_Compass_v8_136.mq5           |
//| v8.139 M3 compile cleanup                 |
//+------------------------------------------------------------------+
#property strict
#property version   "8.285"

// Shared types, inputs, state and cross-module interfaces only.
#property tester_indicator "Market\\Joon_delta_volume_v1_01_OPT_VALIDATION.ex5"
#property tester_indicator "Market\\Joon_MACD_v2_05_OPT_VALIDATION.ex5"

// v5.07: explicit tester-input compilation order.
#include "CommonTypes.mqh"
#include "Inputs.mqh"
#include "CommonState.mqh"
#include "MarketDataEngine.mqh"
#include "DirectionStrengthEngine.mqh"
#include "TradeExecutionEngine.mqh"
#include "ExitEngine.mqh"

// Decision and execution engines.
#include "PatternLearningEngine.mqh"
#include "SignalEngine.mqh"
#include "EntryEngine.mqh"
#include "PositionManager.mqh"
#include "HoldEngine.mqh"
#include "TurnSignalEngine.mqh"
#include "StateEvaluationEngine.mqh"
#include "RiskEngine.mqh"
#include "UI.mqh"
#include "M3SegmentEngine.mqh"
#include "StructureEpisodeEngine.mqh"
#include "WatchEpisodeEngine.mqh"
#include "DataExportEngine.mqh"
#include "M3AutoEngine.mqh"
#include "TurnOrderEngine.mqh"

// MT5 event handlers are owned only by Runtime.mqh.
#include "Runtime.mqh"
