//+------------------------------------------------------------------+
//| CommonTypes.mqh - shared interfaces, enums and constants         |
//+------------------------------------------------------------------+
#ifndef __JOON_COMMON_TYPES_MQH__
#define __JOON_COMMON_TYPES_MQH__

// v7.47 fixed Joon MACD v2.05 buffer contract.
// These are implementation constants, not strategy/user parameters.
// Display-only buffers 0/2 must never be substituted for calculation buffers 6/7.
#define JTC_MACD_DISPLAY_WAVE_BUFFER       0
#define JTC_MACD_DISPLAY_SIGNAL_BUFFER     2
#define JTC_MACD_DIRECTION_BUFFER          3
#define JTC_MACD_ZERO_STATE_BUFFER         4
#define JTC_MACD_RAW_PRICE_BUFFER          5
#define JTC_MACD_WAVE_BUFFER               6
#define JTC_MACD_BASE_BUFFER               7

#define JTC_EA_VERSION "8.286"

// v8.65 M3 unified market/position lifecycle ownership.
enum JTC_M3_MARKET_REGIME
{
   JTC_M3_REGIME_TRANSITION = 0,
   JTC_M3_REGIME_TREND      = 1,
   JTC_M3_REGIME_RANGE      = 2
};

enum JTC_M3_POSITION_STATE
{
   JTC_M3_POS_FLAT       = 0,
   JTC_M3_POS_RUN        = 1,
   JTC_M3_POS_WEAKENING = 2,
   JTC_M3_POS_PROTECT   = 3,
   JTC_M3_POS_RECOVERY  = 4,
   JTC_M3_POS_FAILURE   = 5
};

// ===== Cross-module function interfaces =====
// v8.50 compile-interface audit: declarations for functions/objects owned by
// Runtime, UI and RiskEngine but consumed by earlier-included modules.
bool EnsureMarketSnapshot(const int requested_count);
bool M3AutoEngineIsActive();
string JTAFormatM3StructureTriggerAlert(const int side,const datetime bar_time,const double price,const string event_name);
void DrawAutoTradeArrow(const int side,
                        const string marker_type,
                        const int score,
                        const string reason,
                        const double price);
double ValidStopPrice(const int side,const double entry_price,const double stop_distance);
double StopDistancePrice(const double entry_price,const double volume);
double CurrentProgressR(const int side);
bool EnsureManagedStopsProtected(const bool force=false);
bool ApplyPercentStopToTicket(const ulong ticket,
                              const int side,
                              const double entry_price,
                              const double stop_distance);
void NotifyTerminalOnly(const string message);
void NotifyPositionState(const string state);

// Definitions live in their single owning engine.
bool ApplyGroupProtection(const int side,
                          const double average_price,
                          const double old_sl);
bool ApplyM3ProfitLock(const int side,const double desired_sl);

bool ApplyManagedProfitLock(const int side,
                            const double average_price,
                            const double lock_r);

void NotifyUserWithPcSound(const string message,const string sound_file);
void NotifySignalUserWithPcSound(const string message,const string sound_file);
void DataExportWriteWatchSignalAudit();
void DataExportWritePreReversalLifecycleAudit(const datetime bar_time,const ENUM_TIMEFRAMES tf,const string event,const int side,const string detail);
void DataExportWriteConfirmedMomentumAudit(const datetime bar_time,const ENUM_TIMEFRAMES tf,const int side,const int final_score,const string mode,const string macd_state,const string delta_state,const string price_state,const string higher_tf_state,const string detail);
void WatchSignalResetState();
ENUM_TIMEFRAMES ActiveManagementTF();
bool ApplyProfitGuardLock(const int side,
                          const double average_price,
                          const double lock_percent);
bool ApplyShortTermBreakEven(const int side,
                             const double average_price);
string DataExportHoldStateName();
string DataExportProfitProtectionStateName();
void ManageRProfitProtection();
int BarsSinceMostRecentCross(const double &base_line[],
                             const int direction);
double CurrentGroupProgressR(const int side,
                             double &average_price);
void DeleteJTAObjects();
bool FastOrderEngine(const int side,
                     const int score,
                     const string reason,
                     const double signal_price,
                     const bool append_entry_quality);

// v4.43: one canonical trade-permission evaluator is shared by the UI and
// EntrySafety so the menu can never disagree with the actual order gate.
bool JTATradePermissionAllowed(string &reason)
{
   reason="OK";
   if(!(bool)TerminalInfoInteger(TERMINAL_TRADE_ALLOWED))
   {
      reason="TERMINAL_ALGO_OFF";
      return false;
   }
   if(!(bool)MQLInfoInteger(MQL_TRADE_ALLOWED))
   {
      reason="EA_ALGO_PERMISSION_OFF";
      return false;
   }
   if(!(bool)AccountInfoInteger(ACCOUNT_TRADE_ALLOWED))
   {
      reason="ACCOUNT_TRADE_OFF";
      return false;
   }
   if(!(bool)AccountInfoInteger(ACCOUNT_TRADE_EXPERT))
   {
      reason="ACCOUNT_EXPERT_OFF";
      return false;
   }
   return true;
}

string JTATradePermissionStatusText()
{
   string reason="";
   if(JTATradePermissionAllowed(reason))
      return "MT5 TRADING ON";

   if(reason=="TERMINAL_ALGO_OFF")
      return "MT5 OFF: ALGO";
   if(reason=="EA_ALGO_PERMISSION_OFF")
      return "EA TRADE OFF";
   if(reason=="ACCOUNT_TRADE_OFF")
      return "ACCOUNT TRADE OFF";
   if(reason=="ACCOUNT_EXPERT_OFF")
      return "EXPERT TRADE OFF";
   return "MT5 TRADING OFF";
}

// v1.95 strategy-ownership gateways. SignalEngine produces decisions only;
// EntryEngine owns entry/add requests and ExitEngine owns managed-close requests.
bool OpenPosition(const int side,const string reason);
bool OpenAdditionalPosition(const int side,const int stage,const string reason);
bool CloseManagedPosition(const string reason);
bool CloseManagedVolume(const int side,const double requested_volume,const string reason);
bool EntryEngineSubmitInitial(const int side,const int score,const string reason,const double signal_price,const bool append_entry_quality=false);
void ShortTermResetEntry(const string reason="");
void RangeEntryEngine();
void EntryEngineUpdateRangeDensitySetupState(const string event_id);
void EntryEngineResetRangeStructureAdditional(const string reason);
bool EntryEngineUpdateRangeStructureAdditional(const int side,const string event_id);
void EntryEngineProcessRangeStructureAdditionalTick();
bool EntryEngineApproveTrendInitial(const int side,const bool strategy_path_ready,const bool three_signal_path,const bool auto_start_bias_ok,const bool auto_direction_allowed,const int score,const string path_reason,string &block_reason);
bool EntryEngineSubmitFastMomentum(const int side,const string reason,const double signal_price);
void EntryEngineCancelRangeInitial(const int cancelled_side,const string cancel_reason,const bool hard_counter_reset);
void ResetInitialSignalCountersOnly();
void ResetInitialSignalWindow(const int side);
void TrimInitialSignalWindow(const int side,const int max_count);
void ResetRangeDirectionConfirmation();
void ResetRangeTriggerFinalEntryState(const string reason="");
bool EntryEngineSubmitAdditional(const int side,const int stage,const string reason);
bool ExitEngineSubmitManaged(const string reason);
bool ExitEngineSubmitManagedPartial(const int side,const double volume,const string reason);
void ExitEngineManageOpenPositionUnified();
bool ManageShortTermPriceActionExit();
void HoldEngineApplyTrendState(const int position_side,
                               const bool strong_trend_hold,
                               const bool fresh_extreme_update,
                               const bool ma_normal_structure,
                               const bool weak_hold_bar,
                               const bool warning_bar,
                               const bool exit_candidate_bar,
                               const int exit_failure_count,
                               const bool delta_declining,
                               const bool macd_slope_weak,
                               const bool ma_warning,
                               const double close_price);
void HoldEngineResetState();
bool RangeLowEnergyWarningContext();
void RiskEngineResetProfitProtectionState();
void ManageRangeProfitGuard(const int side,
                            const double average_price,
                            const double market_price,
                            const double progress_percent);
bool HasConfirmedPullback(const int side,
                          const double &fast_ma[],
                          const double &slow_ma[]);
bool HasExploratoryPullback(const int side,
                            const double &fast_ma[],
                            const double &slow_ma[]);

bool M2Reaccelerating(const int side,
                      const double &fast_ma[],
                      const double &slow_ma[]);
int ManagedPositionSide();
bool ManagedGroupInfo(int &side,
                      double &total_volume,
                      double &average_price,
                      double &group_sl,
                      double &group_tp,
                      datetime &first_time);

void ProcessSelectedClosedBar(const bool process_signals,
                              const bool process_auto);
string TradeLogFileName();
string TradeLogResultName(const double net_profit);
string TradeLogSafeFileToken(string value);
string DataExportRunId();
string DataExportBaseFolder();
string TradeLogStrategyName();
bool WeakeningForBars(const double &base_line[],
                      const int side);
void WriteAutoTradeLogDeal(const ulong deal_ticket,
                           const string event_name,
                           const string action_reason);
void WriteMinimalOrderFailureLog(const string failure_stage);
void WriteUnifiedOrderSignalAudit(const string stage,
                                  const string source_event_id,
                                  const string counter_type,
                                  const int side,
                                  const int counter_before,
                                  const int counter_after,
                                  const string decision,
                                  const string reason,
                                  const bool order_requested,
                                  const bool order_result,
                                  const long retcode,
                                  const ulong position_id);

// Persistent AUTO-session latch. It preserves the operator's AUTO ON intent
// through broker fills and MT5 reinitialization, but is cleared by an explicit
// AUTO OFF click or deliberate EA removal.
string UIAutoSessionKey();
bool UIAutoSessionLatched();
void UISetAutoSessionLatch(const bool enabled);


// Strategy-tester CSV diagnostics shared between SignalEngine and DataExportEngine.
bool g_csv_neutral_flow = false;
bool g_csv_compressed_chop = false;
bool g_csv_no_market_energy = false;
bool g_csv_relative_energy_ok = false;
bool g_csv_real_energy_ok = false;
bool g_csv_direction_flow_long_ok = false;
bool g_csv_direction_flow_short_ok = false;
double g_csv_relative_range_ratio = 0.0;
double g_csv_relative_macd_ratio = 0.0;
double g_csv_relative_delta_ratio = 0.0;
bool g_csv_direction_long_allowed = false;
bool g_csv_direction_short_allowed = false;
int  g_csv_long_direction_quality = 0;
int  g_csv_short_direction_quality = 0;
string g_csv_range_long_gate_reason = "";
string g_csv_range_short_gate_reason = "";

// Strategy-tester audit snapshot for the 6-bar / 3-confirmed-signal counter.
// These fields are diagnostic only and do not change entry decisions.
bool     g_csv_counter_raw_long_confirmed = false;
bool     g_csv_counter_raw_short_confirmed = false;
bool     g_csv_counter_countable_long = false;
bool     g_csv_counter_countable_short = false;
int      g_csv_counter_long_before = 0;
int      g_csv_counter_short_before = 0;
int      g_csv_counter_long_after = 0;
int      g_csv_counter_short_after = 0;
int      g_csv_counter_long_last_shift = -1;
int      g_csv_counter_short_last_shift = -1;
int      g_csv_counter_long_first_shift = -1;
int      g_csv_counter_short_first_shift = -1;
bool     g_csv_counter_long_expired = false;
bool     g_csv_counter_short_expired = false;
bool     g_csv_counter_duplicate_bar = false;
int      g_csv_counter_opposite_decay = 0;
datetime g_csv_counter_bar_time = 0;
datetime g_csv_counter_long_first_time = 0;
datetime g_csv_counter_short_first_time = 0;
string   g_csv_counter_action = "NONE";
string   g_csv_counter_reset_reason = "NONE";

void WriteSignalDecisionLog(const int side,
                            const string stage,
                            const int signal_count,
                            const int score,
                            const string final_decision,
                            const string blocked_reason,
                            const bool order_requested,
                            const bool order_result,
                            const long order_retcode,
                            const double range_location);
void WriteMinimalPositionSummary(const ulong position_id,
                                 const string action_reason);
void WriteStrategyBarAudit(const int long_score,
                           const int short_score,
                           const bool raw_long_confirmed,
                           const bool raw_short_confirmed,
                           const bool countable_long,
                           const bool countable_short,
                           const string skip_reason);
void WriteLifecycleEvent(const string event_name,
                         const int side,
                         const string previous_state,
                         const string current_state,
                         const string reason,
                         const ulong position_id,
                         const double event_price,
                         const double event_volume,
                         const double event_profit,
                         const datetime event_time);
datetime TradeLogPositionEntryTime(const ulong position_id);
string PatternDatasetFileName();
void ExportPatternLearningSample(const datetime bar_time,
                                 const ENUM_TIMEFRAMES timeframe,
                                 const double open_price,
                                 const double high_price,
                                 const double low_price,
                                 const double close_price,
                                 const double fast_ma,
                                 const double slow_ma,
                                 const double macd_value,
                                 const double delta_value,
                                 const int detected_side,
                                 const string pattern_name,
                                 const string source_tag);
void ExportSignalLearningSample(const datetime bar_time,
                                const ENUM_TIMEFRAMES timeframe,
                                const double open_price,
                                const double high_price,
                                const double low_price,
                                const double close_price,
                                const double fast_ma,
                                const double slow_ma,
                                const double macd_value,
                                const double delta_value,
                                const int detected_side,
                                const string pattern_name,
                                const string source_tag);
void PatternLearningCaptureClosedBar(const string source_tag);


bool EvaluatePatternLifecycleAssist(const int side,
                                    bool &quality_pullback,
                                    bool &delta_absorption,
                                    bool &trend_fatigue,
                                    bool &compression_release,
                                    int &ma7_bounce_count,
                                    string &detail);
bool CandlePatternState(const ENUM_TIMEFRAMES tf,
                        const int side,
                        bool &rejection,
                        bool &engulfing,
                        bool &favourable_edge,
                        bool &opposite_edge);
bool RangePatternAllows(const ENUM_TIMEFRAMES tf,
                        const int side,
                        string &pattern_name);

// ===== Shared runtime and hold types/helpers =====

// v1.02 runtime cache used by Joon Trend/Range AutoTrader.
// It does not make strategy decisions. It only prevents repeated terminal scans
// and provides consistent tick/new-bar state to all modules in one event cycle.

struct JRO_PositionSnapshot
{
   bool     valid;
   bool     has_managed;
   bool     has_foreign;
   bool     group_side_consistent;
   int      managed_count;
   int      protected_count;
   int      side;
   ulong    first_ticket;
   ENUM_POSITION_TYPE first_type;
   double   first_open_price;
   double   first_sl;
   double   first_tp;
   datetime first_position_time;
   double   total_volume;
   double   weighted_open_price;
   double   average_open_price;
   double   floating_profit;
   double   group_sl;
   double   group_tp;
   datetime earliest_position_time;
   datetime refreshed_at;
};

struct JRO_MarketSnapshot
{
   bool     valid;
   MqlTick  tick;
   double   mid;
   double   spread_points;
   datetime signal_bar_time;
   datetime auto_bar_time;
   bool     signal_new_bar;
   bool     auto_new_bar;
};

JRO_PositionSnapshot g_jro_positions;
JRO_MarketSnapshot   g_jro_market;
bool                 g_jro_position_dirty = true;
bool                 g_jro_chart_dirty = false;

void JRO_ResetPositionSnapshot()
{
   ZeroMemory(g_jro_positions);
   g_jro_positions.valid = false;
   g_jro_positions.group_side_consistent = true;
}

void JRO_InvalidatePositionSnapshot()
{
   g_jro_position_dirty = true;
   g_jro_positions.valid = false;
}

bool JRO_RefreshPositionSnapshot(const string symbol,
                                 const ulong magic,
                                 const bool force=false)
{
   if(!force && !g_jro_position_dirty && g_jro_positions.valid)
      return true;

   JRO_ResetPositionSnapshot();
   int detected_side = 0;
   double weighted = 0.0;

   const int total = PositionsTotal();
   for(int i=total-1; i>=0; --i)
   {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != symbol)
         continue;

      const ulong position_magic = (ulong)PositionGetInteger(POSITION_MAGIC);
      if(position_magic != magic)
      {
         g_jro_positions.has_foreign = true;
         continue;
      }

      const ENUM_POSITION_TYPE type =
         (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const int current_side = (type == POSITION_TYPE_BUY ? 1 : -1);
      const double volume = PositionGetDouble(POSITION_VOLUME);
      const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      const double sl = PositionGetDouble(POSITION_SL);
      const double tp = PositionGetDouble(POSITION_TP);
      const datetime position_time =
         (datetime)PositionGetInteger(POSITION_TIME);

      if(!g_jro_positions.has_managed)
      {
         g_jro_positions.has_managed = true;
         g_jro_positions.first_ticket = ticket;
         g_jro_positions.first_type = type;
         g_jro_positions.first_open_price = open_price;
         g_jro_positions.first_sl = sl;
         g_jro_positions.first_tp = tp;
         g_jro_positions.first_position_time = position_time;
         detected_side = current_side;
      }
      else if(current_side != detected_side)
      {
         g_jro_positions.group_side_consistent = false;
      }

      g_jro_positions.managed_count++;
      if(sl > 0.0)
         g_jro_positions.protected_count++;
      g_jro_positions.total_volume += volume;
      weighted += open_price * volume;
      g_jro_positions.floating_profit +=
         PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);

      if(g_jro_positions.earliest_position_time == 0 ||
         position_time < g_jro_positions.earliest_position_time)
         g_jro_positions.earliest_position_time = position_time;

      if(sl > 0.0 &&
         (g_jro_positions.group_sl == 0.0 ||
          (current_side > 0 && sl > g_jro_positions.group_sl) ||
          (current_side < 0 && sl < g_jro_positions.group_sl)))
         g_jro_positions.group_sl = sl;
      if(tp > 0.0)
         g_jro_positions.group_tp = tp;
   }

   g_jro_positions.side =
      (g_jro_positions.has_managed && g_jro_positions.group_side_consistent)
      ? detected_side : 0;
   g_jro_positions.weighted_open_price = weighted;
   if(g_jro_positions.total_volume > 0.0)
      g_jro_positions.average_open_price =
         weighted / g_jro_positions.total_volume;

   g_jro_positions.refreshed_at = TimeCurrent();
   g_jro_positions.valid = true;
   g_jro_position_dirty = false;
   return true;
}

bool JRO_UpdateMarketSnapshot(const string symbol,
                              const ENUM_TIMEFRAMES signal_tf,
                              const ENUM_TIMEFRAMES auto_tf,
                              const datetime previous_signal_bar,
                              const datetime previous_auto_bar)
{
   ZeroMemory(g_jro_market);
   if(!SymbolInfoTick(symbol, g_jro_market.tick))
      return false;

   g_jro_market.valid = true;
   g_jro_market.mid = (g_jro_market.tick.bid + g_jro_market.tick.ask) * 0.5;
   g_jro_market.spread_points =
      (g_jro_market.tick.ask - g_jro_market.tick.bid) / _Point;
   // Live charts may throttle series metadata reads to 100 ms because wall-clock
   // time advances normally. The strategy tester can simulate many minutes of
   // market time inside the same 100 ms of wall-clock time, so wall-clock
   // throttling there can skip completed bars. In tester mode refresh the
   // series timestamp on every tick; the downstream new-bar logic remains the
   // same for live trading and testing.
   static long last_series_check_msc = 0;
   static datetime cached_signal_bar_time = 0;
   static datetime cached_auto_bar_time = 0;
   static ENUM_TIMEFRAMES cached_signal_tf = PERIOD_CURRENT;
   static ENUM_TIMEFRAMES cached_auto_tf = PERIOD_CURRENT;
   const long now_msc = (long)GetTickCount64();
   const bool tester_mode = (MQLInfoInteger(MQL_TESTER) != 0);
   const bool refresh_series =
      tester_mode ||
      cached_signal_tf != signal_tf ||
      cached_auto_tf != auto_tf ||
      now_msc - last_series_check_msc >= 100;
   if(refresh_series)
   {
      long signal_bar_value = 0;
      long auto_bar_value = 0;
      if(SeriesInfoInteger(symbol, signal_tf, SERIES_LASTBAR_DATE,
                           signal_bar_value))
         cached_signal_bar_time = (datetime)signal_bar_value;
      if(signal_tf == auto_tf)
         cached_auto_bar_time = cached_signal_bar_time;
      else if(SeriesInfoInteger(symbol, auto_tf, SERIES_LASTBAR_DATE,
                                auto_bar_value))
         cached_auto_bar_time = (datetime)auto_bar_value;
      cached_signal_tf = signal_tf;
      cached_auto_tf = auto_tf;
      last_series_check_msc = now_msc;
   }
   g_jro_market.signal_bar_time = cached_signal_bar_time;
   g_jro_market.auto_bar_time = cached_auto_bar_time;
   g_jro_market.signal_new_bar =
      (g_jro_market.signal_bar_time > 0 &&
       g_jro_market.signal_bar_time != previous_signal_bar);
   g_jro_market.auto_new_bar =
      (g_jro_market.auto_bar_time > 0 &&
       g_jro_market.auto_bar_time != previous_auto_bar);
   return true;
}

void JRO_RequestChartRedraw()
{
   if((bool)MQLInfoInteger(MQL_TESTER) &&
      !(bool)MQLInfoInteger(MQL_VISUAL_MODE))
      return;
   g_jro_chart_dirty = true;
}

void JRO_FlushChartRedraw(const long chart_id=0)
{
   if((bool)MQLInfoInteger(MQL_TESTER) &&
      !(bool)MQLInfoInteger(MQL_VISUAL_MODE))
   {
      g_jro_chart_dirty = false;
      return;
   }
   if(!g_jro_chart_dirty)
      return;
   ChartRedraw(chart_id);
   g_jro_chart_dirty = false;
}



// Pure RANGE hold-state evaluator.
// It never opens, modifies or closes a position. The EA position manager is
// the sole owner of all broker actions.
enum ENUM_JOON_RANGE_HOLD_STATE
{
   JOON_RANGE_HOLD_NORMAL = 0,
   JOON_RANGE_HOLD_STRONG = 1,
   JOON_RANGE_HOLD_WARNING = 2,
   JOON_RANGE_HOLD_EXIT = 3
};

// ExitEngine RANGE hold-exit decision interface (enum is defined above).
bool ExitEngineHandleRangeHoldExit(const ENUM_JOON_RANGE_HOLD_STATE hold_state,
                                   const bool state_ready,
                                   const bool profitable,
                                   const int held_bars,
                                   const bool low_energy_warning,
                                   const int warning_state_bars);


void WriteRangeEarlyExitAudit(const ENUM_JOON_RANGE_HOLD_STATE range_state,
                              const string decision_point);

void ResetCsvProfitLockDiagnostics();
void WriteProfitLockModifyAudit(const string result,
                                const int side,
                                const double requested_r,
                                const double requested_sl,
                                const double applied_sl,
                                const uint retcode,
                                const string block_reason);

struct JoonRangeHoldConfig
{
   int strong_score;
   int normal_score;
   int warning_confirm_bars;
   int exit_confirm_bars;
};

struct JoonRangeHoldEvidence
{
   int score;
   bool macd_aligned;
   bool delta_aligned;
   bool ma7_aligned;
   bool opposite_macd;
   bool opposite_delta;
   bool ma_cross_failed;
   bool profitable;
};

struct JoonRangeHoldRuntime
{
   ENUM_JOON_RANGE_HOLD_STATE state;
   int warning_bars;
   int failure_bars;
   // v1.99 state hysteresis. STRONG requires two completed bars to promote,
   // while deterioration can downgrade immediately. warning_state_bars is
   // the consecutive canonical WARNING-state count used by ExitEngine policy.
   int strong_candidate_bars;
   int warning_state_bars;
   datetime last_closed_bar;
   ulong warning_window_bits;
   int warning_window_samples;
};

ENUM_JOON_RANGE_HOLD_STATE JoonEvaluateRangeHoldState(
   const JoonRangeHoldConfig &config,
   const JoonRangeHoldEvidence &evidence,
   const datetime closed_bar_time,
   JoonRangeHoldRuntime &runtime);

string JoonRangeHoldStateName(const ENUM_JOON_RANGE_HOLD_STATE state);

void JoonResetRangeHoldRuntime(JoonRangeHoldRuntime &runtime);

// v5.97 diagnostic-only pre-entry/add market-state snapshot.
// Declared here because SignalEngine is included before HoldEngine.
bool WriteRangeSignalStateSnapshot(const string event_name,
                                   const string event_id,
                                   const string stage,
                                   const int side,
                                   const int signal_count,
                                   const datetime episode_start_bar,
                                   const ulong position_id);
// v5.97 per-layer RANGE HoldEngine.
void ResetRangeLayerHoldStates();
bool ManageRangeLayerHoldStates(const int side);
void JTAHoldAnchorSave();
void JTAHoldAnchorLoad(const datetime initial_time);
void JTAHoldAnchorClear();

// v7.00: shared Dynamic-Leg MACD context used only to invalidate an already
// armed RANGE 3X setup when MACD clearly expands in the opposite direction.
// Return: -1=clear opposite expansion, 0=neutral/preparation, 1=clear same-direction.
int JTAGetRangeSharedMacdContext(const int side,
                                 const datetime episode_start_bar,
                                 string &detail);

// v1.78: Modular position-manager cleanup.
// - AUTO-start bias remains an initial chart-context filter only.
// - RANGE hold include is now a pure state evaluator; it never closes positions.
// - RANGE hold exits are decided only by ExitEngineManageRangePositionUnified().
// - Direction Quality diagnostic veto branches and a duplicated lifecycle condition were removed.
// - Include modules were revised to v1.02 with explicit strategy/runtime boundaries.
// v1.77: Direction Quality reduced to AUTO-start context only.
// - AUTO ON evaluates the pre-existing chart flow once as LONG/SHORT/NEUTRAL bias.
// - The bias is active for at most 5 completed bars or until the first successful entry.
// - RANGE/TREND signal counters, normal entry filters, holding and profit exits no longer use Direction Quality.
// - An entry against the short-lived AUTO-start bias is allowed when a fresh turn/break structure is present.
// - Existing hard SL and holding logic are otherwise unchanged.
// v1.74: RANGE/TREND entry interpretation overhaul.
// - Preserves the 3-signal concept but executes the fresh third signal directly after minimal safety checks.
// - Restores RANGE impulse/confirmed entry paths that were calculated but not included in the final AUTO gate.
// - Separates RANGE reversal timing from the common direction-quality veto.
// - Relaxes TREND entry from duplicated strong-momentum confirmation to fresh restart/pullback evidence.
// - Synchronizes RANGE hold score with lifecycle logging/state output.
// v1.73: RANGE Strong/Normal Hold giveback priority adjustment only.
// - Strong/Normal RANGE positions now use peak-relative giveback allowances.
// - Warning/partial tiers, TREND logic, entries, scores, SL/TP and exits remain unchanged.
// v1.72: Unified final-close state handling for EA, manual, SL and TP exits.
// Keeps strategy rules unchanged while applying identical runtime cleanup and cooldown state.
// - Flat-state runtime resets now run only on the position transition to flat, not on every tick.
// - The 200 ms FAST indicator cache is preserved while flat instead of being invalidated every tick.
// - AUTO regime-traded flags are no longer set before a broker order succeeds.
// - Trading conditions, scores, signal count, SL/TP, hold and exit rules are unchanged.
// v1.70: Signal-counter isolation, same-bar retry and stale-count prevention.
// - The current closed M2 bar is counted in the AUTO path before entry evaluation.
// - The later chart-signal path cannot count the same bar twice.
// - Signal rules, scores, required count, SL, hold and exit logic are unchanged.
// v1.66: Fixed chart-menu alert-score restoration; saved 50-90 setting is restored exactly.
// - RangeEntryEngine and TrendEntryEngine remain strategy-specific.
// - FastOrderEngine centralizes confirmed-signal order transmission and entry drawing.
// - Entry rules, scores, signal counts, re-entry rules, SL/TP and hold/exit logic are unchanged.
// v1.64: AUTO entry-priority optimization without changing signal rules.
// - AUTO closed-bar execution runs before chart SIGNAL work when both bars open together.
// - FAST tick entry checks run only while the managed position is flat.
// - Existing runtime indicator/position caches, deferred chart redraw and unchanged-comment suppression remain active.
//+------------------------------------------------------------------+
//|                 Joon_Trend_Range_AutoTrader.mq5                |
//| Manual TREND / RANGE selectable integrated auto-trading EA         |
//| Install: MQL5\Experts\Market                                     |
//| Required indicators: MQL5\Indicators\Market                      |
//|   Joon_MACD_v2_05_OPT_VALIDATION.ex5                                            |
//|   Joon_delta_volume_v1_01_OPT_VALIDATION.ex5                                    |
//+------------------------------------------------------------------+
#property copyright "Joon"
// v1.66 keeps the separated RANGE/TREND entry architecture and fixes alert-score state restoration.
// Saved menu alert scores are clamped to the actual menu range (50-90), not forced to 90-100.
// and share one optimized FastOrderEngine for the final broker-order path.
// v1.64 entry-priority optimization: AUTO calculation/order path is executed
// before chart-signal drawing when SIGNAL TF and AUTO TF produce a bar together.
// v1.54 runtime optimization: position-scan reuse, FAST indicator micro-cache,
// split CHASE tick/bar management, throttled UI refresh, and performance counters.
// v1.63 keeps SL synchronized continuously and follows TP only while the EA has actually placed a broker TP.
// v1.48 records AUTO entry/add/re-entry/partial-close/close/TP/SL deals to daily CSV logs.
// v1.47 renames AUTO START to AUTO LINE and centers TP/SL text inside the boxes.
// v1.46 adds RANGE-only late-move entry blocking; TREND logic unchanged.
// - RANGE AUTO entry requires 3 same-direction signals by default.
// - After profit lock is armed, the first confirmed MACD/Delta/MA7 fade exits.
// - Existing broker SL and minimal analysis logs remain active.
//
// v1.56 MINIMAL ANALYSIS LOG:
// - Record compact broker/order failures in JTA_OrderFailure CSV.
// - Record one final row per closed position in JTA_PositionSummary CSV.
// - Mark entry/add/re-entry deal rows as OPEN instead of incorrectly counting fees as LOSS.
// v1.55 AUTO STATE PROTECTION:
// - Preserve runtime menu/AUTO state across chart, parameter, account and recompile reinitialization.
// - Never turn AUTO OFF only because ordinary order failures reached a counter threshold.
// - Retry TRADE_RETCODE_INVALID_STOPS entries once without SL, then apply the configured SL from actual fill.
// v1.44 fresh-default fix: new attach AUTO OFF, LOT 0.10, SL 0.30; chart-change menu state retained.
#property strict
// Chart signals remain visual guidance only. AUTO entry is evaluated independently.
// Both may share market-analysis values, but a chart arrow or internal signal state is
// never required for a real order. TREND/RANGE retain separate AUTO timing gates.
#property tester_indicator "Market\\Joon_MACD_v2_05_OPT_VALIDATION.ex5"
#property tester_indicator "Market\\Joon_delta_volume_v1_01_OPT_VALIDATION.ex5"

#include <Trade/Trade.mqh>
enum ENUM_STOP_MODE
{
   STOP_DISABLED = 0,
   STOP_POINTS   = 1,
   STOP_PERCENT  = 2,
   STOP_MONEY    = 3
};

enum ENUM_TRADE_DIRECTION
{
   TRADE_BOTH       = 0,
   TRADE_LONG_ONLY  = 1,
   TRADE_SHORT_ONLY = 2
};

enum ENUM_SIGNAL_DIRECTION
{
   SIGNAL_BOTH       = 0,
   SIGNAL_LONG_ONLY  = 1,
   SIGNAL_SHORT_ONLY = 2
};

enum ENUM_STRATEGY_MODE
{
   STRATEGY_TREND    = 0, // legacy internal value only; never selectable
   STRATEGY_RANGE    = 1,
};

void ResetRangeDirectionalPersistence(const string reason);
void FinalTriggerUpdateFromAcceptedFinal(const ENUM_STRATEGY_MODE strategy,
                                         const int side,
                                         const datetime final_bar,
                                         const int final_score);

// v4.48: user-facing strategy selector deliberately excludes legacy TREND.
// Numeric values match ENUM_STRATEGY_MODE for old .set compatibility.
enum ENUM_SELECTABLE_STRATEGY
{
   SELECT_STRATEGY_RANGE    = 1,
};

enum ENUM_AUTO_START_BIAS
{
   AUTO_BIAS_NEUTRAL = 0,
   AUTO_BIAS_LONG    = 1,
   AUTO_BIAS_SHORT   = -1
};

enum ENUM_HOLD_STATE
{
   HOLD_UNKNOWN        = 0,
   HOLD_NORMAL         = 1,
   HOLD_STRONG         = 2,
   HOLD_WARNING        = 3,
   HOLD_EXIT_CANDIDATE = 4,
   HOLD_PROFIT_PROTECT = 5
};

enum ENUM_PROFIT_PROTECTION_STATE
{
   PROFIT_PROTECTION_UNKNOWN = 0,
   PROFIT_PROTECTION_ARMED   = 1,
   PROFIT_PROTECTION_STRONG  = 2,
   PROFIT_PROTECTION_NORMAL  = 3,
   PROFIT_PROTECTION_WARNING = 4,
   PROFIT_PROTECTION_EXIT    = 5
};

// Internal states are automatic. The chart menu still exposes only TREND/RANGE.
enum ENUM_TREND_INTERNAL_STATE
{
   TREND_STATE_SETUP = 0,
   TREND_STATE_PULLBACK = 1,
   TREND_STATE_ENTRY = 2,
   TREND_STATE_HOLD = 3,
   TREND_STATE_EXIT = 4
};

enum ENUM_RANGE_INTERNAL_STATE
{
   RANGE_STATE_SETUP = 0,
   RANGE_STATE_REVERSAL = 1,
   RANGE_STATE_ENTRY = 2,
   RANGE_STATE_HOLD = 3,
   RANGE_STATE_EXIT = 4
};

enum ENUM_ENTRY_TYPE
{
   ENTRY_NORMAL = 0,
   ENTRY_EARLY  = 1,
   ENTRY_CHASE  = 2,
   ENTRY_ADD    = 3,
   ENTRY_RANGE  = 4
};


// v2.45 canonical layer-role classifier.
// ENTRY_NORMAL / ENTRY_RANGE / ENTRY_EARLY / ENTRY_CHASE describe how the
// original position was opened. Only ENTRY_ADD represents an additional layer.
bool IsInitialEntryType(const ENUM_ENTRY_TYPE entry_type)
{
   return entry_type!=ENTRY_ADD;
}

// Entry confidence is fixed when the initial position is opened.
// RANGE positions with fewer than the configured three signals retain the
// normal HOLD engine, but activate profit protection earlier and allow less
// giveback.
enum ENUM_ENTRY_CONFIDENCE
{
   ENTRY_CONFIDENCE_LOW = 0,
   ENTRY_CONFIDENCE_MEDIUM = 1,
   ENTRY_CONFIDENCE_HIGH = 2
};

string EntryConfidenceName(const ENUM_ENTRY_CONFIDENCE confidence)
{
   if(confidence == ENTRY_CONFIDENCE_HIGH) return "HIGH";
   if(confidence == ENTRY_CONFIDENCE_MEDIUM) return "MEDIUM";
   return "LOW";
}

enum ENUM_ASSET_PROFILE
{
   ASSET_AUTO     = 0,
   ASSET_NASDAQ   = 1,
   ASSET_GOLD     = 2,
   ASSET_WTI      = 3,
   ASSET_COPPER   = 4,
   ASSET_BITCOIN  = 5,
   ASSET_GENERIC  = 6
};

enum ENUM_SHORT_TERM_ENTRY_MODE
{
   ENTRY_CLASSIC_M2    = 0,
   ENTRY_FAST_MOMENTUM = 1,
   ENTRY_HYBRID        = 2
};

enum ENUM_WATCH_DISPLAY_MODE
{
   WATCH_MODE_OFF         = 0,
   WATCH_MODE_CHART       = 1,
   WATCH_MODE_CHART_ALERT = 2
};

// Number of new same-direction Accepted FINAL signals required after
// a real RANGE WATCH Trigger price crossing before RANGE INITIAL is allowed.
enum ENUM_RANGE_TRIGGER_FINALS_REQUIRED
{
   RANGE_TRIGGER_FINALS_1 = 1,
   RANGE_TRIGGER_FINALS_2 = 2,
   RANGE_TRIGGER_FINALS_3 = 3
};


enum ENUM_AUTO_ENTRY_PATH
{
   AUTO_ENTRY_BOTH         = 0, // NORMAL + TRIGGER
   AUTO_ENTRY_NORMAL_ONLY  = 1, // NORMAL only
   AUTO_ENTRY_TRIGGER_ONLY = 2  // TRIGGER only
};


// v7.11: lightweight, position-independent manual-assist interpretation.
// This state never owns signal, order, exit or risk authority.
enum ENUM_JTA_ASSIST_STATE
{
   JTA_ASSIST_NEUTRAL = 0,
   JTA_ASSIST_UP,
   JTA_ASSIST_UP_WEAKENING,
   JTA_ASSIST_REVERSAL_WATCH_DOWN,
   JTA_ASSIST_DOWN,
   JTA_ASSIST_DOWN_WEAKENING,
   JTA_ASSIST_REVERSAL_WATCH_UP
};

struct JTAAssistStateSnapshot
{
   datetime bar_time;
   ENUM_TIMEFRAMES timeframe;
   ENUM_JTA_ASSIST_STATE state;
   ENUM_JTA_ASSIST_STATE previous_state;
   int direction_anchor;
   // v8.229 ASSIST-only established owner confirmed by same-direction ACCEL.
   int established_side;
   datetime established_time;
   double open_price;
   double high_price;
   double low_price;
   double close_price;
   int macd_zero_state;
   double source_volume;
   double avg_range;
   double net_progress_r;
   double recent_progress_r;
   // v8.221 observation-only price-path / zero-flip diagnostics.
   double price_travel_3_r;
   double price_efficiency_3;
   int macd_zero_flip_count_5;
   // v8.263 observation-only market-regime diagnostics. No signal/order authority.
   double chop_8;
   double chop_14;
   double chop_21;
   double aroon_up_21;
   double aroon_down_21;
   double aroon_osc_21;
   // v8.264 observation-only WATCH quality classifier. Never owns signal/order authority.
   bool watch_observe_original;
   bool watch_observe_new_candidate;
   string watch_observe_stage;
   string watch_observe_suppress_reason;
   double watch_observe_progress3_r;
   double watch_observe_chop8_delta3;
   double watch_observe_chop14;
   double watch_observe_aroon_spread;
   // v8.266 canonical WATCH suppression lifecycle diagnostics.
   bool watch_suppress_latch_active;
   int watch_suppress_latch_side;
   bool watch_suppress_event;
   bool watch_suppress_release;
   int higher_high_steps;
   int higher_low_steps;
   int lower_high_steps;
   int lower_low_steps;
   // v8.02: canonical closed-bar price-structure snapshot.  These values are
   // calculated once in StateEvaluationEngine and consumed by RANGE ADD/HOLD
   // logic; consumers must not create their own competing swing calculation.
   double recent_swing_high;
   double recent_swing_low;
   double older_swing_high;
   double older_swing_low;
   bool structure_higher_low;
   bool structure_lower_high;
   bool pullback_long_ready;
   bool pullback_short_ready;
   double continuation_break_high;
   double continuation_break_low;
   int up_close_steps;
   int down_close_steps;
   double raw_macd;
   double macd_base;
   double macd_wave;
   double macd_wave_change_1;
   double macd_wave_change_3;
   // v8.218: observation-only MACD flatness diagnostics.
   double macd_base_change_1;
   double macd_base_change_3;
   double macd_base_travel_3;
   double macd_base_efficiency_3;
   double macd_wave_travel_3;
   double macd_wave_efficiency_3;
   double macd_change_1;
   double macd_change_3;
   int raw_up_steps;
   int raw_down_steps;
   double macd_transition_progress;
   int macd_direction;
   bool macd_transition_up;
   bool macd_transition_down;
   bool long_transition_progress;
   bool short_transition_progress;
   // v8.280 diagnostic-only opposite WATCH lead study. No chart/alert/AUTO authority.
   bool early_opposite_watch_shadow;
   bool early_opposite_watch_pulse;
   int early_opposite_watch_side; // +1 LONG, -1 SHORT
   string early_opposite_watch_stage;
   string early_opposite_watch_classification;
   // v8.282 diagnostic-only trend reassertion lifecycle shadow.
   bool early_candidate_track_active;
   int early_candidate_track_side;
   datetime early_candidate_start_time;
   int early_candidate_age_bars;
   bool trend_reassertion_pending;
   int trend_reassertion_side;
   int trend_reassertion_age_bars;
   bool trend_reassertion_target_recovered_pulse;
   bool trend_reassertion_cancel_pulse;
   string review_shadow_end_reason;
   datetime review_shadow_ended_start;
   int review_shadow_ended_side;
   double review_adx14;
   bool review_adx14_valid;
   bool review_price_break3;
   bool review_qualified_early_opposite;
   bool review_add_block_option;
   bool review_add_blocked;
   bool turn_pre_enabled;
   bool turn_pre_data_valid;
   bool turn_pre_signal;
   int turn_pre_side;
   datetime turn_pre_confirm_bar;
   datetime turn_pre_available_time;
   datetime turn_pre_pivot_time;
   double turn_pre_pivot_price;
   int turn_pre_score;
   double turn_pre_distance_r;
   double turn_pre_long_divergence_r;
   double turn_pre_short_divergence_r;
   bool turn_pre_opposite;
   string turn_pre_reason;
   bool turn_pre_require_divergence;
   double turn_pre_atr14;
   bool turn_direction_valid;
   bool turn_direction_signal;
   int turn_direction_side;
   datetime turn_direction_bar;
   int turn_direction_owner_side;
   string turn_direction_reason;


   bool watch_pulse;
   // v8.276/v8.280: same-direction informational WATCH pulse. It remains in
   // CSV diagnostics but v8.280 suppresses pure repeats from chart/system alert.
   // It has no canonical AUTO/ACCEL ownership; PREZERO CONFIRMED re-entry may
   // explicitly promote it through M3AutoEngine.
   bool watch_informational_repeat;
   // v8.249: true only for a canonical WATCH published by the
   // opposite-WATCH -> established-direction REARM lifecycle.
   // User-facing semantics remain WATCH; AUTO uses this bit only to split
   // EXIT authority from the next-cycle INITIAL timing.
   bool watch_rearm_pulse;
   // v7.71: lifecycle-only re-arm after an opposing market-data discontinuity.
   // This is not a strategy filter or direction vote. It allows the first
   // post-gap full MACD+Delta+Price evidence to re-establish WATCH ownership.
   bool post_discontinuity_rearm;
   // v8.223 observation-only: exact market-bar continuity used by StateEvaluation.
   int expected_bar_seconds;
   int market_gap_seconds;
   bool data_discontinuity;
   bool scheduled_market_gap;
   double raw_delta;
   double ema_delta;
   double delta_change;
   int delta_buy_steps;
   int delta_sell_steps;
   bool delta_long_participation;
   bool delta_short_participation;
   // v8.209: chart-only WEAK information pulse. No alert/order authority.
   bool weak_pulse;
   int weak_side; // +1 LONG WEAK, -1 SHORT WEAK
   // v7.66: cached closed-bar directional evidence. SignalEngine reuses
   // these booleans directly; no additional CopyRates/CopyBuffer/lookback
   // work is permitted for FIRST-FINAL qualification.
   bool price_up;
   bool price_down;
   bool full_long_watch_candidate;
   bool full_short_watch_candidate;
   // v8.252 REARM pre-zero recovery evidence. EXIT-only: these fields never
   // publish WATCH/ACCEL or authorize INITIAL/ADD. They identify the narrow
   // interval where the established side has rebuilt full price+MACD evidence
   // and recovered the opposite canonical WATCH extreme before MACD zero-side.
   bool pre_rearm_exit_long;
   bool pre_rearm_exit_short;
   // v8.225 G4.4 diagnostics: oscillatory opposite-FLIP HOLD lifecycle.
   bool flip_path_oscillatory;
   bool flip_hold_contested;
   bool flip_raw_path_directional;
   bool flip_wave_path_directional;
   int flip_raw_path_direction;
   int flip_wave_path_direction;
   double flip_raw_efficiency_5;
   double flip_wave_efficiency_5;
   bool flip_hold_active;
   int flip_hold_side;
   string flip_hold_action;
   bool changed;
   string reason;
};


// v7.16 unified runtime timeframe authority (implemented by StateEvaluationEngine).
bool StateEvaluationSetTimeframe(const ENUM_TIMEFRAMES timeframe);


// v7.20 signal research audit: one completed TRADE-TF row, no trading authority.
void CloseSignalBarAudit();
void ClosePerformanceAudit();
void WritePerformanceAuditV100(const datetime bar_time,
                               const ENUM_TIMEFRAMES timeframe);
void WriteSignalBarAuditV111(const datetime bar_time,
                             const ENUM_TIMEFRAMES timeframe,
                             const double open_price,
                             const double high_price,
                             const double low_price,
                             const double close_price,
                             const double source_volume,
                             const double ma7,
                             const double ma22,
                             const double ma70,
                             const double ma111,
                             const double ma200,
                             const double macd_base_unscaled,
                             const int macd_direction,
                             const int macd_zero_state,
                             const double macd_change_1,
                             const double macd_change_3,
                             const double raw_delta,
                             const double ema_delta,
                             const double delta_change,
                             const double avg_range,
                             const double net_progress_r,
                             const double recent_progress_r,
                             const int higher_high_steps,
                             const int higher_low_steps,
                             const int lower_high_steps,
                             const int lower_low_steps,
                             const int up_close_steps,
                             const int down_close_steps,
                             const int long_score,
                             const int short_score,
                             const bool final_long,
                             const bool final_short,
                             const int long_signal_count,
                             const int short_signal_count,
                             const bool neutral_flow,
                             const bool compressed_chop,
                             const bool no_market_energy,
                             const double relative_range_ratio,
                             const double relative_macd_ratio,
                             const double relative_delta_ratio,
                             const int long_direction_quality,
                             const int short_direction_quality,
                             const bool direction_long_allowed,
                             const bool direction_short_allowed,
                             const string long_gate_reason,
                             const string short_gate_reason,
                             const string final_long_block_reason,
                             const string final_short_block_reason,
                             const double assist_macd_base,
                             const double assist_macd_wave,
                             const double assist_macd_raw_price,
                             const double assist_macd_wave_change_1,
                             const double assist_macd_wave_change_3,
                             const double assist_macd_base_change_1,
                             const double assist_macd_base_change_3,
                             const double assist_macd_base_travel_3,
                             const double assist_macd_base_efficiency_3,
                             const double assist_macd_wave_travel_3,
                             const double assist_macd_wave_efficiency_3,
                             const int assist_raw_up_steps,
                             const int assist_raw_down_steps,
                             const double assist_raw_delta,
                             const double assist_ema_delta,
                             const double assist_delta_change,
                             const int assist_delta_buy_steps,
                             const int assist_delta_sell_steps,
                             const bool assist_delta_long_participation,
                             const bool assist_delta_short_participation,
                             const bool assist_snapshot_aligned,
                             const double assist_macd_transition_progress,
                             const bool assist_macd_transition_up,
                             const bool assist_macd_transition_down,
                             const bool assist_long_transition_progress,
                             const bool assist_short_transition_progress,
                             const bool assist_watch_pulse,
                             const int assist_direction_anchor,
                             const string assist_previous_state,
                             const string assist_state,
                             const string assist_reason,
                             const int persistent_direction_before,
                             const int persistent_direction_after,
                             const string persistence_transition_reason,
                             const bool directional_regime_long,
                             const bool directional_regime_short,
                             const bool price_up,
                             const bool price_down,
                             const bool full_long_watch_candidate,
                             const bool full_short_watch_candidate,
                             const bool long_watch_authorized,
                             const bool short_watch_authorized,
                             const bool persistent_candidate_long,
                             const bool persistent_candidate_short,
                             const bool assist_persistent_continuation_long,
                             const bool assist_persistent_continuation_short,
                             const bool effective_flow_long,
                             const bool effective_flow_short,
                             const bool final_gate_long,
                             const bool final_gate_short,
                             const bool repeat_final_long_ok,
                             const bool repeat_final_short_ok,
                             const bool repeat_late_block_long,
                             const bool repeat_late_block_short,
                             const bool ma111_protection,
                             const bool strong_buy,
                             const bool strong_sell,
                             const int long_macd_score,
                             const int short_macd_score,
                             const int long_delta_score,
                             const int short_delta_score,
                             const int long_ma_score,
                             const int short_ma_score,
                             const int long_price_score,
                             const int short_price_score,
                             const int long_pattern_score,
                             const int short_pattern_score,
                             const int long_tf_score,
                             const int short_tf_score,
                             const int long_location_score,
                             const int short_location_score,
                             const int long_score_pre_context,
                             const int short_score_pre_context,
                             const int long_context_penalty,
                             const int short_context_penalty,
                             const bool long_score_threshold_pass,
                             const bool short_score_threshold_pass,
                             const bool long_score_gap_pass,
                             const bool short_score_gap_pass,
                             const bool macd_side_long,
                             const bool macd_side_short,
                             const bool signal_trigger_long,
                             const bool signal_trigger_short,
                             const bool repeat_long_is_repeat,
                             const bool repeat_short_is_repeat,
                             const bool repeat_long_momentum_ok,
                             const bool repeat_short_momentum_ok,
                             const bool repeat_long_price_ok,
                             const bool repeat_short_price_ok,
                             const bool repeat_long_episode_progress,
                             const bool repeat_short_episode_progress,
                             const double previous_long_final_close,
                             const double previous_short_final_close,
                             const string repeat_long_detail,
                             const string repeat_short_detail,
                             const datetime previous_long_final_bar,
                             const datetime previous_short_final_bar,
                             const string long_final_phase,
                             const string short_final_phase,
                             const string long_signal_event_id,
                             const string short_signal_event_id);


// v7.22 visual tester chart/PNG analysis helpers

#endif // __JOON_COMMON_TYPES_MQH__
