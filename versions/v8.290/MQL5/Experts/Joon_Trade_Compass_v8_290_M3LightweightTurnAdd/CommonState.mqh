//+------------------------------------------------------------------+
//| CommonState.mqh - shared runtime state/helpers                   |
//+------------------------------------------------------------------+
#ifndef __JOON_COMMON_STATE_MQH__
#define __JOON_COMMON_STATE_MQH__

// Shared UI lot value; declared here so execution modules can use it without
// depending on UI.mqh include order.
double g_ui_lots = 0.10;


struct JTA_WatchSnapshot
{
   datetime bar_time;
   int long_score;
   int short_score;
   int long_stage;
   int short_stage;
   int momentum_long;
   int momentum_short;
   int flow_long;
   int flow_short;
   int structure_long;
   int structure_short;
   int range_long;
   int range_short;
   int context_long;
   int context_short;
   bool active_compression;
   bool dead_range;
   bool opposite_pressure_decay_long;
   bool opposite_pressure_decay_short;
   bool price_response_long;
   bool price_response_short;
   bool chase_penalty_long;
   bool chase_penalty_short;
   int macd_turn_age_long;
   int macd_turn_age_short;
   int delta_turn_age_long;
   int delta_turn_age_short;
   int dema_turn_age_long;
   int dema_turn_age_short;
   double range_position;
   double atr_ratio;
   double delta_ratio;
   int dominant_side;
   int delta_dominance;
   datetime long_segment_start;
   datetime short_segment_start;
   double long_segment_start_price;
   double short_segment_start_price;
   double long_trigger_base_price;
   double short_trigger_base_price;
   double long_trigger_price;
   double short_trigger_price;
   double long_trigger_buffer;
   double short_trigger_buffer;
   string long_trigger_source;
   string short_trigger_source;
   bool long_trigger_fired;
   bool short_trigger_fired;
   datetime long_trigger_fire_time;
   datetime short_trigger_fire_time;
   double long_trigger_fire_price;
   double short_trigger_fire_price;
   string long_reason;
   string short_reason;
   bool system_alert_fired;
   bool mobile_alert_fired;

   // v8.29 diagnostic-only MACD representation shadow.
   // Active WATCH remains Buffer 7. Buffer 6 is evaluated without chart/alert/trigger/order authority.
   double macd_b7_now;
   double macd_b7_prev;
   double macd_b6_now;
   double macd_b6_prev;
   int macd_b7_regime;
   int macd_b6_regime;
   int macd_b6_turn_age_long;
   int macd_b6_turn_age_short;
   int delta_buy_bars;
   int delta_sell_bars;
   double delta_sum;
   double delta_raw_now;
   double delta_ema_now;
   bool current_long_authorized;
   bool current_short_authorized;
   bool shadow_b6_valid;
   bool shadow_b6_dead_range;
   int shadow_b6_momentum_long;
   int shadow_b6_momentum_short;
   int shadow_b6_context_long;
   int shadow_b6_context_short;
   int shadow_b6_long_score;
   int shadow_b6_short_score;
   int shadow_b6_long_stage;
   int shadow_b6_short_stage;
   int shadow_b6_dominant_side;
   bool shadow_b6_long_authorized;
   bool shadow_b6_short_authorized;
};

CTrade trade;
ENUM_TIMEFRAMES g_trading_tf = PERIOD_M3;
#define AUTO_TF g_trading_tf
int      g_macd_handle = INVALID_HANDLE;
int      g_delta_handle = INVALID_HANDLE;
int      g_add_ma_handle = INVALID_HANDLE;
int      g_slow_ma_handle = INVALID_HANDLE;
int      g_signal_macd_handle = INVALID_HANDLE;
int      g_signal_delta_handle = INVALID_HANDLE;
int      g_signal_fast_ma_handle = INVALID_HANDLE;
int      g_signal_slow_ma_handle = INVALID_HANDLE;
bool     g_signal_handles_shared_with_auto = false;
int      g_assist_macd_handle = INVALID_HANDLE;
int      g_assist_delta_handle = INVALID_HANDLE;
bool     g_assist_handles_owned = false;
JTAAssistStateSnapshot g_assist_state;
// v8.212: WEAK display lifecycle only; never consumed by AUTO/alert/risk.
// WEAK is owned by the most recent canonical WATCH and may only fire on a later bar.
bool     g_assist_long_weak_armed = true;
bool     g_assist_short_weak_armed = true;
int      g_assist_weak_watch_owner_side = 0; // +1 LONG WATCH, -1 SHORT WATCH
datetime g_assist_weak_watch_owner_time = 0;
// v8.252: price anchor of the exact canonical WATCH owner bar. This is owner
// metadata, not a new signal calculation, and is used only by REARM EXIT-only
// recovery evidence.
double   g_assist_weak_watch_owner_high = 0.0;
double   g_assist_weak_watch_owner_low = 0.0;

// v8.261: PRE-REARM EXIT uses a dedicated execution owner. Latest WATCH
// history may be refreshed by informational same-side WATCH events, but only
// a WATCH actually consumed by AUTO as INITIAL / opposite EXIT / REARM may
// replace these recovery anchors.
int      g_pre_rearm_execution_owner_side = 0;
datetime g_pre_rearm_execution_owner_time = 0;
double   g_pre_rearm_execution_owner_high = 0.0;
double   g_pre_rearm_execution_owner_low = 0.0;

// v8.279: broker-confirmed PREZERO EXIT may arm one same-side CONFIRMED
// re-entry while flat. This is execution lifecycle state only; it never
// creates a signal by itself. Opposite canonical WATCH cancels it.
bool     g_prezero_reentry_armed = false;
int      g_prezero_reentry_side = 0; // +1 LONG, -1 SHORT
datetime g_prezero_reentry_exit_time = 0;

// v8.259: active ACCEL authority is intentionally separate from historical
// WATCH metadata. A WATCH arms this owner; cancellation before the first
// later-bar canonical ACCEL invalidates it. Once canonical ACCEL confirms,
// the owner remains valid for the established directional episode until a
// new canonical WATCH replaces it.
int      g_assist_accel_owner_side = 0;
datetime g_assist_accel_owner_watch_time = 0;
bool     g_assist_accel_owner_confirmed = false;

// v8.280 diagnostic-only first-edge latch for opposite transition progress.
bool     g_assist_early_opposite_active = false;
int      g_assist_early_opposite_side = 0;

// v8.282 diagnostic-only TREND_REASSERTION lifecycle. These fields never
// own chart/alert/AUTO authority; they only preserve the early-opposite
// candidate long enough to audit existing-trend reassertion and target recovery.
bool     g_assist_early_candidate_track_active = false;
int      g_assist_early_candidate_track_side = 0;
datetime g_assist_early_candidate_start_time = 0;
int      g_assist_early_candidate_age_bars = 0;
bool     g_assist_trend_reassertion_pending = false;
int      g_assist_trend_reassertion_side = 0;
int      g_assist_trend_reassertion_age_bars = 0;
// v8.284: monotonically increasing diagnostic attempt id.
long     g_assist_early_candidate_episode_seq = 0;
long     g_assist_early_candidate_episode_id = 0;

datetime g_assist_state_bucket = 0;

// v8.242: one-shot same-EA reinitialization ownership snapshot.
bool     g_reinit_owner_snapshot_valid=false;
int      g_reinit_saved_assist_state=0;
int      g_reinit_saved_established_side=0;
datetime g_reinit_saved_established_time=0;
int      g_reinit_saved_direction_anchor=0;
int      g_reinit_saved_watch_owner_side=0;
datetime g_reinit_saved_watch_owner_time=0;
double   g_reinit_saved_watch_owner_high=0.0;
double   g_reinit_saved_watch_owner_low=0.0;
bool     g_reinit_saved_long_weak_armed=true;
bool     g_reinit_saved_short_weak_armed=true;
int      g_reinit_saved_last_accel_side=0;
datetime g_reinit_saved_last_accel_time=0;
// v8.259: persist active ACCEL ownership separately from historical WATCH.
int      g_reinit_saved_accel_owner_side=0;
datetime g_reinit_saved_accel_owner_watch_time=0;
bool     g_reinit_saved_accel_owner_confirmed=false;
int      g_reinit_saved_chart_accel_publish_count=0;
int      g_reinit_saved_chart_cont_accel_publish_count=0;
// v8.251: persist the pending reverse-order lifecycle across same-EA reinit.
// This is order state, not a new signal owner. It is reconciled only after
// historical ownership replay proves the saved WATCH is still canonical.
int      g_reinit_saved_pending_reverse_side=0;
datetime g_reinit_saved_pending_reverse_watch_time=0;
bool     g_reinit_saved_pending_reverse_requires_accel=false;
bool     g_reinit_saved_pending_reverse_accel_confirmed=false;
datetime g_reinit_saved_pending_reverse_accel_time=0;
// v8.251: execution obligation created when the pending reverse WATCH must
// first flatten an opposite managed position. Completion is never trusted
// from this saved flag; broker position state is reconciled after replay.
bool     g_reinit_saved_pending_reverse_exit_obligation=false;
// v8.252: separate execution-only obligation created before canonical REARM
// WATCH confirmation. It must never be folded into pending_reverse ownership.
bool     g_reinit_saved_pre_rearm_exit_obligation=false;
int      g_reinit_saved_pre_rearm_exit_recovery_side=0;
int      g_reinit_saved_pre_rearm_exit_owner_side=0;
datetime g_reinit_saved_pre_rearm_exit_owner_time=0;
// v8.261: preserve PRE-REARM execution owner independently from latest WATCH.
int      g_reinit_saved_pre_rearm_execution_owner_side=0;
datetime g_reinit_saved_pre_rearm_execution_owner_time=0;
double   g_reinit_saved_pre_rearm_execution_owner_high=0.0;
double   g_reinit_saved_pre_rearm_execution_owner_low=0.0;
// PERIOD_CURRENT means use the Inputs default until the operator changes it from the chart menu.
ENUM_TIMEFRAMES g_assist_state_tf_runtime = PERIOD_CURRENT;
int      g_assist_csv_handle = INVALID_HANDLE;
int      g_signal_bar_audit_handle = INVALID_HANDLE;
string   g_signal_bar_audit_file = "";
int      g_signal_bar_audit_rows_since_flush = 0;
int      g_pre_reversal_audit_handle = INVALID_HANDLE;
string   g_pre_reversal_audit_file = "";
int      g_pre_reversal_audit_rows_since_flush = 0;
int      g_performance_audit_handle = INVALID_HANDLE;
string   g_performance_audit_file = "";
int      g_performance_audit_rows_since_flush = 0;
// v7.22 visual tester analysis capture

string   g_assist_csv_file = "";

ENUM_TIMEFRAMES g_market_snapshot_tf = PERIOD_CURRENT;
// v4.57: 3X first breakout is only a continuation anchor, not order authority.

// Signal/market invalidation remains owned by SignalEngine. These fields only
// tell the active Candidate whether a failed submit may be retried.

// Baselines are captured from the FINAL/Candidate M1 bar. At the real
// signal-bar breakout tick, only continuation of that already-confirmed
// momentum is checked. This is not a new FINAL/direction score engine.

// engine or score. It only remembers a recent completed-bar FINAL while an
// overrule an otherwise NORMAL M1 hold. Opposite FINAL resets it immediately.
// v3.73 logging latch only: strategy/HOLD state is unchanged.
// while the same completed M1 bar remains current.

// with that broker-valid SL while keeping menu distance as the 1R basis.




// an order; they snapshot the candidate age and M1/M3 state at breakout time.
int      g_calc_macd_handle = INVALID_HANDLE;
int      g_calc_delta_handle = INVALID_HANDLE;
int      g_calc_fast_ma_handle = INVALID_HANDLE;
int      g_calc_slow_ma_handle = INVALID_HANDLE;
int      g_ma70_handle = INVALID_HANDLE;
int      g_ma111_handle = INVALID_HANDLE;
int      g_ma200_handle = INVALID_HANDLE;
int      g_signal_ma70_handle = INVALID_HANDLE;
int      g_signal_ma111_handle = INVALID_HANDLE;
int      g_signal_ma200_handle = INVALID_HANDLE;
int      g_calc_ma70_handle = INVALID_HANDLE;
int      g_calc_ma111_handle = INVALID_HANDLE;
int      g_calc_ma200_handle = INVALID_HANDLE;
ENUM_TIMEFRAMES g_calc_tf = PERIOD_M3;
ENUM_TIMEFRAMES g_signal_tf = PERIOD_M3;
ENUM_SIGNAL_DIRECTION g_signal_direction = SIGNAL_BOTH;
ENUM_TRADE_DIRECTION g_trade_direction = TRADE_BOTH;
ENUM_STRATEGY_MODE g_selected_strategy = STRATEGY_RANGE;
ENUM_STRATEGY_MODE g_position_strategy = STRATEGY_RANGE;
bool g_position_strategy_locked = false;
bool g_hold_evaluation_ready = false;
datetime g_hold_evaluation_bar = 0;
ENUM_STRATEGY_MODE g_hold_evaluation_strategy = STRATEGY_RANGE;
ENUM_JOON_RANGE_HOLD_STATE g_hold_evaluation_range_state = JOON_RANGE_HOLD_WARNING;
double   g_hold_evaluation_volume = 0.0;
double   g_hold_evaluation_average_price = 0.0;
double   g_highest_profit_r = 0.0;
bool     g_strong_hold_active = false;
ENUM_HOLD_STATE g_hold_state = HOLD_UNKNOWN;
ENUM_PROFIT_PROTECTION_STATE g_profit_protection_state = PROFIT_PROTECTION_UNKNOWN;
JoonRangeHoldRuntime g_range_hold_runtime;
int g_range_hold_last_side = 0;
datetime g_range_hold_position_time = 0;

// v5.97 RANGE per-layer HoldEngine state. INITIAL, ADD1 and ADD2 each own an
// independent Dynamic-Leg runtime beginning at their own fill time.
JoonRangeHoldRuntime g_initial_layer_hold_runtime;
JoonRangeHoldRuntime g_add1_layer_hold_runtime;
JoonRangeHoldRuntime g_add2_layer_hold_runtime;
ENUM_JOON_RANGE_HOLD_STATE g_initial_layer_hold_state=JOON_RANGE_HOLD_NORMAL;
ENUM_JOON_RANGE_HOLD_STATE g_add1_layer_hold_state=JOON_RANGE_HOLD_NORMAL;
ENUM_JOON_RANGE_HOLD_STATE g_add2_layer_hold_state=JOON_RANGE_HOLD_NORMAL;
bool g_initial_layer_hold_ready=false;
bool g_add1_layer_hold_ready=false;
bool g_add2_layer_hold_ready=false;
datetime g_initial_layer_hold_tracked_time=0;
datetime g_add1_layer_hold_tracked_time=0;
datetime g_add2_layer_hold_tracked_time=0;
ENUM_TREND_INTERNAL_STATE g_trend_internal_state = TREND_STATE_SETUP;
ENUM_RANGE_INTERNAL_STATE g_range_internal_state = RANGE_STATE_SETUP;
int g_trend_internal_side = 0;
int g_range_internal_side = 0;
int g_trend_state_bars = 0;
int g_range_state_bars = 0;
ENUM_ENTRY_TYPE g_entry_type = ENTRY_NORMAL;
ENUM_ENTRY_CONFIDENCE g_entry_confidence = ENTRY_CONFIDENCE_HIGH;
int      g_entry_signal_count_at_open = 0;
string   g_entry_quality = "B";
bool     g_has_add_entry = false;
bool     g_reentry_protection_active = false;
int      g_hold_weak_bars = 0;
int      g_hold_warning_bars = 0;
int      g_hold_exit_candidate_bars = 0;
int      g_hold_direction_score = 0;
int      g_hold_strong_score = 0;
int      g_hold_weakness_score = 0;
int      g_trading_tf_long_direction_score = 0;
int      g_trading_tf_short_direction_score = 0;
int      g_chase_promotion_bars = 0;
bool     g_chase_promoted = false;
int      g_last_long_confidence = 0;
int      g_last_short_confidence = 0;
int      g_last_no_trade_flags = 0;

datetime g_last_bar_time = 0;
datetime g_last_auto_bar_time = 0;
datetime g_last_exit_bar_time = 0;
int      g_last_giveback_exit_side = 0;
datetime g_last_giveback_exit_time = 0;
double   g_last_giveback_exit_price = 0.0;
string   g_last_giveback_exit_reason = "";

int      g_last_stop_exit_side = 0;
datetime g_last_stop_exit_time = 0;
double   g_last_stop_exit_price = 0.0;
int      g_same_side_stop_count = 0;
#define FAST_TICK_CAPACITY 512
long     g_fast_tick_time_msc[FAST_TICK_CAPACITY];
double   g_fast_tick_mid[FAST_TICK_CAPACITY];
int      g_fast_tick_direction[FAST_TICK_CAPACITY];
int      g_fast_tick_head = 0;
int      g_fast_tick_count = 0;
double   g_fast_previous_mid = 0.0;
long     g_last_fast_entry_attempt_msc = 0;

// v8.36 single short-term price-action entry state. This is the only pending
// state for the new AUTO short-term model: impulse -> pullback -> re-accel ->
// live trigger. It is deliberately independent of the legacy RANGE 3X cycle.
bool     g_st_entry_armed = false;
bool     g_st_entry_active = false;
datetime g_st_entry_filled_bar = 0;
int      g_st_entry_side = 0;
datetime g_st_entry_setup_bar = 0;
datetime g_st_entry_expiry_bar = 0;
double   g_st_entry_trigger = 0.0;
double   g_st_entry_stop = 0.0;
double   g_st_entry_impulse_extreme = 0.0;
double   g_st_entry_pullback_extreme = 0.0;
bool     g_long_regime_traded = false;
bool     g_short_regime_traded = false;
bool     g_long_exit_pending = false;
bool     g_short_exit_pending = false;
int      g_exit_opposite_close_bars = 0;
string   g_status = "INITIALIZING";
string   g_entry_safety_block_reason = "";
string   g_pending_exit_reason = "";
datetime g_pending_exit_reason_time = 0;
string   g_last_chart_comment = "";
ENUM_AUTO_START_BIAS g_auto_start_bias = AUTO_BIAS_NEUTRAL;
bool     g_auto_start_bias_active = false;
int      g_auto_start_bias_bars_seen = 0;
datetime g_auto_start_bias_last_bar = 0;
int      g_pre_direction_long_count = 0;
int      g_pre_direction_short_count = 0;
datetime g_pre_direction_release_last_bar = 0;
int      g_pre_direction_release_score = 0;
string   g_pre_direction_release_condition = "NOT_EVALUATED";
string   g_pre_direction_release_block_reason = "NONE";
bool     g_pre_direction_bias_released = false;
string   g_pre_direction_last_bias = "NEUTRAL";

// v2.99 PRE-AUTO FINAL history.
// This is observation context only. It never grants order permission and is
// never copied into the AUTO three-signal counter.
#define PRE_AUTO_FINAL_CAPACITY 12
datetime g_pre_auto_final_time[PRE_AUTO_FINAL_CAPACITY];
int      g_pre_auto_final_side[PRE_AUTO_FINAL_CAPACITY];
int      g_pre_auto_final_score[PRE_AUTO_FINAL_CAPACITY];
int      g_pre_auto_final_strategy[PRE_AUTO_FINAL_CAPACITY];
int      g_pre_auto_final_tf_seconds[PRE_AUTO_FINAL_CAPACITY];
int      g_pre_auto_final_count = 0;
int      g_pre_auto_history_long_count = 0;
int      g_pre_auto_history_short_count = 0;
int      g_pre_auto_history_last_side = 0;
int      g_pre_auto_history_last_score = 0;
bool     g_pre_auto_history_used = false;

bool     g_auto_trading = false;
bool     g_signal_enabled = true;
bool     g_terminal_alert = true;
bool     g_mobile_alert = false;
ENUM_WATCH_DISPLAY_MODE g_watch_mode = WATCH_MODE_CHART_ALERT;
JTA_WatchSnapshot g_watch_snapshot;
int      g_watch_long_stage = 0;
int      g_watch_short_stage = 0;
int g_watch_user_long_stage=0;   // v8.20: user-visible WATCH promotion lifecycle
int g_watch_user_short_stage=0;  // v8.20: user-visible WATCH promotion lifecycle
bool g_watch_marker_drawn_this_bar=false; // v8.65: avoid full chart-object maintenance when no marker changed
int  g_watch_object_maintenance_bars=0; // v8.65: amortize WATCH object cleanup scans

datetime g_watch_last_long_alert_bar = 0;
datetime g_watch_last_short_alert_bar = 0;
datetime g_last_long_entry_condition_alert_bar = 0;
datetime g_last_short_entry_condition_alert_bar = 0;
bool     g_long_entry_condition_alerted = false;
bool     g_short_entry_condition_alerted = false;
int      g_signal_position_side = 0;
double   g_signal_entry_price = 0.0;
int      g_additional_entry_count = 0; // currently active ADD layers
int      g_additional_entry_filled_count = 0; // v3.68 cumulative successful ADD fills in the current INITIAL trade cycle
int      g_max_additional_entries = 0;
// v4.50: dominant RANGE direction persists through ordinary M2 pullbacks.
// It is signal interpretation state only; it has no direct order authority.
int      g_range_persistent_direction = 0; // -1 SHORT, 0 NONE/TRANSITION, +1 LONG
datetime g_range_persistent_since = 0;
// v8.02: density state is diagnostic-only for RANGE. It has no INITIAL/ADD
// broker authority; price-structure lifecycle owns continuation ADD permission.
bool     g_range_density_ready_long = false;
bool     g_range_density_ready_short = false;
bool     g_range_density_fresh_long = false;
bool     g_range_density_fresh_short = false;
datetime g_last_entry_time = 0;
datetime g_initial_entry_time = 0;
// v5.97 Hold time-origin is the Accepted FINAL that authorized the layer.
// Actual entry/deal clocks remain separate for P/L, R, age and broker logic.
datetime g_initial_hold_anchor_time = 0;
datetime g_pending_initial_hold_anchor_time = 0;
double   g_initial_entry_lots = 0.0;
double   g_initial_entry_price = 0.0;
double   g_initial_r_distance = 0.0;

// v8.60: M3 AUTO is the single strategic owner of the position's structural
// protection. These values are separate from legacy RANGE/TREND protection
// state so a generic percentage stop cannot silently replace the M3 structure.
bool     g_m3_structural_sl_active = false;
bool     g_m3_position_managed = false;
double   g_m3_initial_structural_sl = 0.0;
double   g_m3_protected_sl = 0.0;
int      g_m3_protection_stage = 0;
int      g_m3_position_state = JTC_M3_POS_FLAT;
double   g_m3_group_peak_r = 0.0;
double   g_m3_post_add_peak_r = 0.0;
double   g_m3_post_add_anchor_r = 0.0;
double   g_m3_post_add_protected_r = 0.0;
int      g_m3_group_add_count_at_peak = 0;
datetime g_m3_protection_last_time = 0;
// v8.145: explicit M3 Peak80 audit state for IntegratedTrace verification.
double   g_m3_audit_lock_target_r = 0.0;
double   g_m3_audit_lock_target_sl = 0.0;
bool     g_m3_audit_lock_active = false;
bool     g_m3_audit_lock_attempted = false;
bool     g_m3_audit_lock_applied = false;
string   g_m3_audit_lock_block_reason = "";
datetime g_m3_audit_lock_update_time = 0;
// v8.72: structural re-entry lock. A failed M3 segment cannot be reused until
// a genuinely new directional structure and breakout replaces it.
// v2.37 layer-specific ADD profit protection.
double   g_add1_entry_price = 0.0;
datetime g_add1_entry_time = 0;
datetime g_add1_hold_anchor_time = 0;
double   g_add1_r_distance = 0.0;
double   g_add1_volume = 0.0;
double   g_add1_peak_r = 0.0;
double   g_add1_lock_r = 0.0;

double   g_add2_entry_price = 0.0;
datetime g_add2_entry_time = 0;
datetime g_add2_hold_anchor_time = 0;
double   g_add2_r_distance = 0.0;
double   g_add2_volume = 0.0;
double   g_add2_peak_r = 0.0;
double   g_add2_lock_r = 0.0;


// v8.176: generalized ADD layer ownership. Index 0 = ADD1, index N-1 = ADDN.
// Legacy ADD1/ADD2 variables remain mirrored for compatibility with older
// diagnostics, while all order/risk/LIFO decisions use this canonical array.
struct JoonAddLayerState
{
   bool     active;
   int      stage;
   double   entry_price;
   datetime entry_time;
   datetime hold_anchor_time;
   double   r_distance;
   double   volume;
   double   peak_r;
   double   lock_r;
};
JoonAddLayerState g_add_layers[];

void JTAAddLayerEnsure(const int stage)
{
   if(stage<=0) return;
   const int old_size=ArraySize(g_add_layers);
   if(old_size>=stage) return;
   ArrayResize(g_add_layers,stage);
   for(int i=old_size;i<stage;++i)
   {
      g_add_layers[i].active=false; g_add_layers[i].stage=i+1;
      g_add_layers[i].entry_price=0.0; g_add_layers[i].entry_time=0;
      g_add_layers[i].hold_anchor_time=0; g_add_layers[i].r_distance=0.0;
      g_add_layers[i].volume=0.0; g_add_layers[i].peak_r=0.0; g_add_layers[i].lock_r=0.0;
   }
}

void JTAAddLayerMirrorLegacy()
{
   if(ArraySize(g_add_layers)>=1 && g_add_layers[0].active)
   {
      g_add1_entry_price=g_add_layers[0].entry_price; g_add1_entry_time=g_add_layers[0].entry_time;
      g_add1_hold_anchor_time=g_add_layers[0].hold_anchor_time; g_add1_r_distance=g_add_layers[0].r_distance;
      g_add1_volume=g_add_layers[0].volume; g_add1_peak_r=g_add_layers[0].peak_r; g_add1_lock_r=g_add_layers[0].lock_r;
   }
   else { g_add1_entry_price=0.0; g_add1_entry_time=0; g_add1_hold_anchor_time=0; g_add1_r_distance=0.0; g_add1_volume=0.0; g_add1_peak_r=0.0; g_add1_lock_r=0.0; }
   if(ArraySize(g_add_layers)>=2 && g_add_layers[1].active)
   {
      g_add2_entry_price=g_add_layers[1].entry_price; g_add2_entry_time=g_add_layers[1].entry_time;
      g_add2_hold_anchor_time=g_add_layers[1].hold_anchor_time; g_add2_r_distance=g_add_layers[1].r_distance;
      g_add2_volume=g_add_layers[1].volume; g_add2_peak_r=g_add_layers[1].peak_r; g_add2_lock_r=g_add_layers[1].lock_r;
   }
   else { g_add2_entry_price=0.0; g_add2_entry_time=0; g_add2_hold_anchor_time=0; g_add2_r_distance=0.0; g_add2_volume=0.0; g_add2_peak_r=0.0; g_add2_lock_r=0.0; }
}

void JTAAddLayerSet(const int stage,const double price,const datetime tm,const datetime anchor,
                    const double rdist,const double vol)
{
   if(stage<=0) return;
   JTAAddLayerEnsure(stage);
   const int i=stage-1;
   g_add_layers[i].active=true; g_add_layers[i].stage=stage;
   g_add_layers[i].entry_price=price; g_add_layers[i].entry_time=tm;
   g_add_layers[i].hold_anchor_time=(anchor>0?anchor:tm);
   g_add_layers[i].r_distance=rdist; g_add_layers[i].volume=vol;
   g_add_layers[i].peak_r=0.0; g_add_layers[i].lock_r=0.0;
   JTAAddLayerMirrorLegacy();
}

void JTAAddLayerClear(const int stage)
{
   if(stage<=0 || stage>ArraySize(g_add_layers)) return;
   const int i=stage-1;
   g_add_layers[i].active=false; g_add_layers[i].entry_price=0.0; g_add_layers[i].entry_time=0;
   g_add_layers[i].hold_anchor_time=0; g_add_layers[i].r_distance=0.0; g_add_layers[i].volume=0.0;
   g_add_layers[i].peak_r=0.0; g_add_layers[i].lock_r=0.0;
   JTAAddLayerMirrorLegacy();
}

void JTAAddLayerResetAll()
{
   ArrayResize(g_add_layers,0);
   JTAAddLayerMirrorLegacy();
}

int JTAAddLayerLatestActiveStage()
{
   for(int i=ArraySize(g_add_layers)-1;i>=0;--i)
      if(g_add_layers[i].active && g_add_layers[i].volume>0.0 && g_add_layers[i].entry_price>0.0) return i+1;
   return 0;
}

double JTAAddLayerVolume(const int stage)
{
   if(stage<=0 || stage>ArraySize(g_add_layers)) return 0.0;
   return g_add_layers[stage-1].active ? g_add_layers[stage-1].volume : 0.0;
}

bool     g_add_position_sync_pending = false;
int      g_add_pending_stage = 0;
int      g_add_pending_side = 0;
double   g_add_pending_volume = 0.0;
datetime g_pending_add_hold_anchor_time = 0;
int      g_pending_add_hold_anchor_stage = 0;
double   g_tp_distance = 0.0;
double   g_sl_distance = 0.0;
double   g_protected_sl = 0.0;
// v6.33: native MT5 broker-SL manual ownership per position ticket.
ulong    g_manual_broker_sl_tickets[];
ulong    g_pending_ea_sl_modify_ticket[];
double   g_pending_ea_sl_modify_price[];
ulong    g_pending_ea_sl_modify_ms[];

int ManualBrokerSLOwnershipIndex(const ulong ticket)
{
   if(ticket==0) return -1;
   for(int i=0;i<ArraySize(g_manual_broker_sl_tickets);++i)
      if(g_manual_broker_sl_tickets[i]==ticket) return i;
   return -1;
}
bool ManualBrokerSLIsOwned(const ulong ticket){ return ManualBrokerSLOwnershipIndex(ticket)>=0; }
void ManualBrokerSLSetOwned(const ulong ticket)
{
   if(ticket==0 || ManualBrokerSLIsOwned(ticket)) return;
   const int n=ArraySize(g_manual_broker_sl_tickets);
   if(ArrayResize(g_manual_broker_sl_tickets,n+1)==n+1) g_manual_broker_sl_tickets[n]=ticket;
}
void ManualBrokerSLClearAll(){ ArrayResize(g_manual_broker_sl_tickets,0); }

void ManualBrokerSLRecordEAModify(const ulong ticket,const double sl)
{
   const ulong now_ms=GetTickCount64();
   for(int i=ArraySize(g_pending_ea_sl_modify_ticket)-1;i>=0;--i)
   {
      if(g_pending_ea_sl_modify_ms[i]>0 && now_ms>=g_pending_ea_sl_modify_ms[i] &&
         now_ms-g_pending_ea_sl_modify_ms[i]<=5000) continue;
      const int n=ArraySize(g_pending_ea_sl_modify_ticket);
      for(int j=i;j<n-1;++j)
      {
         g_pending_ea_sl_modify_ticket[j]=g_pending_ea_sl_modify_ticket[j+1];
         g_pending_ea_sl_modify_price[j]=g_pending_ea_sl_modify_price[j+1];
         g_pending_ea_sl_modify_ms[j]=g_pending_ea_sl_modify_ms[j+1];
      }
      ArrayResize(g_pending_ea_sl_modify_ticket,n-1);
      ArrayResize(g_pending_ea_sl_modify_price,n-1);
      ArrayResize(g_pending_ea_sl_modify_ms,n-1);
   }
   const int n=ArraySize(g_pending_ea_sl_modify_ticket);
   if(ArrayResize(g_pending_ea_sl_modify_ticket,n+1)!=n+1 ||
      ArrayResize(g_pending_ea_sl_modify_price,n+1)!=n+1 ||
      ArrayResize(g_pending_ea_sl_modify_ms,n+1)!=n+1) return;
   g_pending_ea_sl_modify_ticket[n]=ticket;
   g_pending_ea_sl_modify_price[n]=NormalizePrice(sl);
   g_pending_ea_sl_modify_ms[n]=now_ms;
}
bool ManualBrokerSLConsumeEAModify(const ulong ticket,const double sl)
{
   const ulong now_ms=GetTickCount64();
   const double tolerance=MathMax(SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE),_Point)*1.1;
   for(int i=ArraySize(g_pending_ea_sl_modify_ticket)-1;i>=0;--i)
   {
      if(g_pending_ea_sl_modify_ticket[i]!=ticket) continue;
      if(g_pending_ea_sl_modify_ms[i]==0 || now_ms<g_pending_ea_sl_modify_ms[i] ||
         now_ms-g_pending_ea_sl_modify_ms[i]>5000) continue;
      if(MathAbs(NormalizePrice(sl)-g_pending_ea_sl_modify_price[i])>tolerance) continue;
      const int n=ArraySize(g_pending_ea_sl_modify_ticket);
      for(int j=i;j<n-1;++j)
      {
         g_pending_ea_sl_modify_ticket[j]=g_pending_ea_sl_modify_ticket[j+1];
         g_pending_ea_sl_modify_price[j]=g_pending_ea_sl_modify_price[j+1];
         g_pending_ea_sl_modify_ms[j]=g_pending_ea_sl_modify_ms[j+1];
      }
      ArrayResize(g_pending_ea_sl_modify_ticket,n-1);
      ArrayResize(g_pending_ea_sl_modify_price,n-1);
      ArrayResize(g_pending_ea_sl_modify_ms,n-1);
      return true;
   }
   return false;
}
void ManualBrokerSLClearPendingEAModifies()
{
   ArrayResize(g_pending_ea_sl_modify_ticket,0);
   ArrayResize(g_pending_ea_sl_modify_price,0);
   ArrayResize(g_pending_ea_sl_modify_ms,0);
}

// v3.79 INITIAL earned-profit virtual floor.
// Used only after the existing Profit Protection logic has actually earned a
// requested lock and broker stop/freeze geometry cannot host that full target.
// The best legal broker SL remains the server-side safety net; this runtime
// INITIAL and RANGE original INITIAL positions. ADD and CHASE are excluded.
bool     g_initial_virtual_profit_floor_active = false;
int      g_initial_virtual_profit_floor_side = 0;
double   g_initial_virtual_profit_floor_r = 0.0;
double   g_initial_virtual_profit_floor_price = 0.0;
datetime g_initial_virtual_profit_floor_time = 0;
bool     g_tp_enabled = false;
bool     g_sl_enabled = true;
int      g_consecutive_order_failures = 0;
datetime g_last_long_signal_bar = 0;
datetime g_last_short_signal_bar = 0;
int      g_range_long_signal_count = 0;
int      g_range_short_signal_count = 0;
datetime g_range_last_counted_signal_bar = 0;
datetime g_range_last_long_count_bar = 0;
datetime g_range_last_short_count_bar = 0;
// Diagnostic first-signal timestamps for measuring the full 3-signal span.
// They do not participate in the entry decision.
datetime g_range_first_long_count_bar = 0;
datetime g_range_first_short_count_bar = 0;
// Rolling AUTO entry signal windows.  Each array stores the actual
// completed-bar times consumed by the initial-entry counter.
datetime g_range_long_signal_window[3] = {0,0,0};
datetime g_range_short_signal_window[3] = {0,0,0};

// v7.91 RANGE order interpretation state. This is a five-completed-bar view
// of the canonical Accepted FINAL stream; it does not create another signal.
int      g_range_final_density_window[5] = {0,0,0,0,0}; // +1 LONG, -1 SHORT, 0 none
datetime g_range_final_density_last_bar = 0;
int      g_range_final_density_long_5 = 0;
int      g_range_final_density_short_5 = 0;
double   g_range_final_density_macd_wave = 0.0;
double   g_range_final_density_macd_change_3 = 0.0;
// RANGE initial-entry direction-confirmation state. The third signal arms this
// state; it never sends an order on the same completed bar.
// v4.83 RANGE Trigger-entry state: a real WATCH Trigger crossing may grant
// RANGE INITIAL only after the user-selected number (1/2/3) of new
// same-direction Accepted FINALs at/after the Trigger-fire bar.
// Pre-Trigger FINALs are never borrowed.
bool     g_range_trigger_entry_active = false;
int      g_range_trigger_entry_side = 0;
datetime g_range_trigger_entry_fire_time = 0;
double   g_range_trigger_entry_trigger_price = 0.0;
datetime g_range_trigger_entry_fire_bar = 0;
double   g_range_trigger_entry_fire_high = 0.0;
double   g_range_trigger_entry_fire_low = 0.0;
bool     g_range_trigger_entry_fire_bar_locked = false;
bool     g_range_trigger_entry_rebreak_confirmed = false;
int      g_range_trigger_entry_final_count = 0;
int      g_range_trigger_entry_opposite_count = 0; // opposite Accepted FINAL 2/2 resets Trigger-entry setup
datetime g_range_trigger_entry_last_final_bar = 0;
datetime g_range_trigger_entry_second_final_bar = 0;
double   g_range_trigger_entry_second_high = 0.0;
double   g_range_trigger_entry_second_low = 0.0;
double   g_range_trigger_entry_second_close = 0.0;
int      g_range_trigger_entry_second_score = 0;
bool     g_range_trigger_entry_second_ready = false;
datetime g_range_trigger_entry_next_retry_time = 0;

bool     g_range_direction_confirm_pending = false;
int      g_range_direction_confirm_side = 0;
datetime g_range_direction_confirm_signal_bar = 0;
double   g_range_direction_confirm_high = 0.0;
double   g_range_direction_confirm_low = 0.0;
double   g_range_direction_confirm_close = 0.0;
int      g_range_direction_confirm_wait_bars = 0;
int      g_range_direction_confirm_signal_count = 0;
double   g_range_direction_confirm_lots = 0.0;
// CSV-verifiable third-signal breakout lifecycle. These values remain valid
// from ARMED through ORDER_RESULT, then ResetRangeDirectionConfirmation clears them.
datetime g_range_break_confirm_bar_time = 0;
double   g_range_break_confirm_high = 0.0;
double   g_range_break_confirm_low = 0.0;
double   g_range_break_confirm_close = 0.0;
double   g_range_break_reference_price = 0.0;
double   g_range_break_distance = 0.0;
bool     g_range_break_confirmed = false;
bool     g_range_break_order_sent = false;
bool     g_range_break_order_result = false;
double   g_range_break_order_price = 0.0;
// Active-position snapshot of the continuation structure that actually
// authorized INITIAL. RANGE stores the first-break M2 directional extreme;
// remains available to RiskEngine until the managed group is fully closed.
bool     g_entry_breakout_active = false;
int      g_entry_breakout_side = 0;
double   g_entry_breakout_reference = 0.0;
datetime g_entry_breakout_confirm_bar_time = 0;
double   g_entry_breakout_confirm_close = 0.0;

// Legacy v4.15 third-signal tick-stop state. v4.63 continuation-confirmed
// for backward/legacy state compatibility. Broker SL remains the hard backstop.
bool     g_initial_3x_structure_stop_active = false;
int      g_initial_3x_structure_stop_side = 0;
double   g_initial_3x_structure_stop_price = 0.0;
datetime g_initial_3x_structure_signal_bar = 0;
// Consecutive completed bars where the pending direction is blocked by the
// shared RANGE gate. A single temporary block does not cancel confirmation.
int      g_range_direction_confirm_gate_block_bars = 0;
// v3.68: most recent same-direction FINAL that still supports an armed
// BREAKOUT_WAIT. This refreshes evidence freshness without reopening or
// rebuilding the locked three-signal counter.
datetime g_range_direction_confirm_last_support_bar = 0;
// Consecutive fully confirmed opposite signals while post-third direction
// confirmation is pending. One opposite signal is treated as noise; two
// consecutive opposite confirmations cancel the pending direction.
int      g_range_direction_confirm_opposite_count = 0;
// Order transaction guards. These latches do not depend on the delayed MT5
// position snapshot, so two entry paths cannot submit the same initial/add
// order during the broker synchronization window.
bool     g_entry_order_in_progress = false;
datetime g_last_initial_order_bar = 0;
int      g_last_initial_order_side = 0;
double   g_last_initial_order_lots = 0.0;
bool     g_add_order_in_progress = false;
datetime g_last_add_order_signal_bar = 0;
int      g_last_add_order_side = 0;
// RANGE profit exits are released only by a confirmed opposite signal after
// the original-direction support has failed. SignalEngine refreshes these on
// every completed decision bar while a position is open.
bool     g_position_opposite_signal_confirmed = false;
bool     g_position_direction_hold_supported = true;
datetime g_last_long_alert_bar = 0;
datetime g_last_short_alert_bar = 0;
// v3.32 confirmed-momentum observation state. This is output-only and never
// participates in FINAL, 3X or AUTO permission.
bool     g_confirmed_momentum_long_active = false;
bool     g_confirmed_momentum_short_active = false;
datetime g_last_confirmed_momentum_long_bar = 0;
datetime g_last_confirmed_momentum_short_bar = 0;
// v8.271: completed-bar DIRECTION progression reference. Within the current
// WATCH-owned signal leg, a second+ DIRECTION must CLOSE beyond the prior
// same-direction DIRECTION extreme (LONG: prior high, SHORT: prior low).
double   g_last_direction_event_high = 0.0;
double   g_last_direction_event_low = 0.0;
// v8.210: internal-only legacy Confirmed Momentum bridge.
// No chart/system/mobile alert authority. M3 AUTO may consume a fresh event as ADD.
int      g_internal_momentum_watch_owner_side = 0;
datetime g_internal_momentum_event_time = 0;
int      g_internal_momentum_event_side = 0;
datetime g_internal_momentum_last_consumed_time = 0;
datetime g_last_add_attempt_bar = 0;
// RANGE additional-entry confirmation (v2.50):
// two fresh same-direction FINALs are required. After FINAL #2, that second
// signal bar becomes the breakout reference. A later completed bar must fully
// break it; the following completed bar must hold the breakout before ADD.
int      g_add_same_direction_signal_count = 0;
datetime g_add_last_counted_signal_bar = 0;
datetime g_add_first_signal_bar = 0;       // FINAL #1 bar
datetime g_add_break_confirm_bar = 0;      // legacy diagnostic field; RANGE ADD authority moved to shared structure in v8.02
// v8.02 RANGE continuation lifecycle. StateEvaluationEngine owns the structure
// evidence; EntryEngine only freezes one continuation reference and consumes it.
bool     g_range_structure_add_pending = false;
int      g_range_structure_add_side = 0;
double   g_range_structure_add_break_price = 0.0;
datetime g_range_structure_add_setup_bar = 0;
datetime g_range_structure_add_last_attempt_bar = 0;
bool     g_range_structure_add_break_confirmed = false;
string   g_range_structure_add_source_event_id = "";
string   g_add_first_signal_event_id = ""; // FINAL #1 event
string   g_add_second_signal_event_id = "";// FINAL #2 event / READY source
// g_add_last_counted_signal_bar is FINAL #2 bar while ADD READY is armed.
string   g_add_last_consumed_pair_key = "";
// CSV snapshot for additional-entry analysis. SignalEngine refreshes the
// decision context and PositionManager records the final attempt/result.
#ifndef __JOON_CSV_ADD_STATE_DECLARED__
#define __JOON_CSV_ADD_STATE_DECLARED__
bool     g_csv_add_enabled = false;
int      g_csv_add_count_before = 0;
int      g_csv_add_count_after = 0;
int      g_csv_add_signal_count = 0;
int      g_csv_add_signal_required = 2;
int      g_csv_add_capacity_remaining = 0;
int      g_csv_add_stage = 0;
bool     g_csv_add_same_direction_signal = false;
bool     g_csv_add_opposite_direction_signal = false;
bool     g_csv_add_exit_safe = false;
bool     g_csv_add_attempted = false;
bool     g_csv_add_result = false;
long     g_csv_add_retcode = 0;
string   g_csv_add_block_reason = "";
datetime g_csv_add_signal_bar_time = 0;
int      g_csv_add_bars_since_entry = 0;
double   g_csv_add_progress_r = 0.0;
double   g_csv_add_requested_volume = 0.0;
double   g_csv_add_fill_price = 0.0;
// v8.142 one-shot IntegratedTrace execution events. These are audit-only.
ulong    g_csv_exec_event_sequence = 0;
bool     g_csv_add_event_pending = false;
string   g_csv_add_event_id = "";
string   g_csv_add_event_phase = "";
datetime g_csv_add_event_time = 0;
int      g_csv_add_event_side = 0;
int      g_csv_add_event_layer = 0;
bool     g_csv_exit_event_pending = false;
string   g_csv_exit_event_id = "";
string   g_csv_exit_event_phase = "";
datetime g_csv_exit_event_time = 0;
string   g_csv_exit_event_reason = "";
bool     g_csv_position_closed_event_pending = false;
string   g_csv_position_closed_cycle_id = "";
datetime g_csv_position_closed_time = 0;
double   g_csv_position_final_pnl = 0.0;
double   g_csv_position_final_r = 0.0;
string   g_csv_position_exit_reason = "";
// v8.242: CSV-only source attribution / per-position close trace.
string   g_csv_order_signal_source = "";
int      g_csv_order_signal_side = 0;
datetime g_csv_order_signal_time = 0;
bool     g_csv_ticket_closed_event_pending = false;
ulong    g_csv_ticket_closed_id = 0;
double   g_csv_ticket_final_pnl = 0.0;

// v2.67 CSV-only diagnostics for v2.66+ net-positive Stage-1 protection.
// These values never grant trading authority; RiskEngine owns calculation/action.
double   g_csv_stage1_configured_r = 0.0;
double   g_csv_stage1_net_positive_r = 0.0;
double   g_csv_stage1_effective_r = 0.0;
double   g_csv_stage1_entry_charge = 0.0;
double   g_csv_stage1_negative_swap = 0.0;
double   g_csv_stage1_estimated_exit_cost = 0.0;
double   g_csv_stage1_one_r_money = 0.0;
// v2.77 audit de-duplication only. These fields never participate in the
// decision to modify a broker SL; they suppress identical NO_APPLIED_SL_CHANGE
// CSV rows until position/request/current-SL context changes.
ulong    g_profit_lock_no_improve_position_id = 0;
double   g_profit_lock_no_improve_requested_sl = 0.0;
double   g_profit_lock_no_improve_lock_r = 0.0;
double   g_profit_lock_no_improve_sl_signature = 0.0;

bool     g_csv_profit_lock_attempted = false;
double   g_csv_profit_lock_requested_r = 0.0;
double   g_csv_profit_lock_requested_sl = 0.0;
bool     g_csv_profit_lock_applied = false;
double   g_csv_profit_lock_applied_sl = 0.0;
uint     g_csv_profit_lock_retcode = 0;
string   g_csv_profit_lock_block_reason = "";
// v3.42 Profit Lock actual-SL diagnostics (diagnostic only; no policy change).
ulong    g_csv_profit_lock_ticket = 0;
int      g_csv_profit_lock_managed_count = 0;
int      g_csv_profit_lock_same_side_count = 0;
double   g_csv_profit_lock_current_sl_before = 0.0;
double   g_csv_profit_lock_actual_sl_after = 0.0;
double   g_csv_profit_lock_improvement_points = 0.0;
bool     g_csv_profit_lock_improves = false;
double   g_csv_profit_lock_bid = 0.0;
double   g_csv_profit_lock_ask = 0.0;
long     g_csv_profit_lock_stop_level_points = 0;
long     g_csv_profit_lock_freeze_level_points = 0;
double   g_csv_profit_lock_minimum_distance = 0.0;
bool     g_csv_profit_lock_verify_pass = false;

// v3.68 Hold/Profit diagnostic snapshot only.
// Populated by HoldEngine from the single canonical segment-metrics build.
// These fields never grant signal, hold, risk, exit or order authority.
int      g_csv_hold_recent_count = 0;
int      g_csv_hold_recent_span = 0;
double   g_csv_hold_recent_macd_ratio = 0.0;
double   g_csv_hold_recent_delta_ratio = 0.0;
double   g_csv_hold_extreme_giveback_ratio = 0.0;
bool     g_csv_hold_recent_macd_reverse = false;
bool     g_csv_hold_recent_delta_reverse = false;
bool     g_csv_hold_recent_price_reverse = false;
int      g_csv_hold_score_before_cap = 0;
int      g_csv_hold_score_after_cap = 0;
ENUM_JOON_RANGE_HOLD_STATE g_csv_hold_state_before = JOON_RANGE_HOLD_NORMAL;
ENUM_JOON_RANGE_HOLD_STATE g_csv_hold_state_after = JOON_RANGE_HOLD_NORMAL;
#endif // __JOON_CSV_ADD_STATE_DECLARED__
// Only the original entry layer receives the two-opposite-signal hold rule.
// Additional layers remain subject to the normal shared profit-lock/hold logic.
int      g_initial_opposite_confirm_count = 0;
// v5.97 RANGE: once opposite Accepted FINAL 2/2 is confirmed, retain the
// evidence as a cycle-local pending exit. HoldEngine owns whether market exit
// is allowed; Broker SL remains untouched and always authoritative.
bool     g_range_opposite_2of2_exit_pending = false;
int      g_range_opposite_2of2_exit_side = 0;
datetime g_range_opposite_2of2_exit_time = 0;
datetime g_initial_opposite_last_bar = 0;
datetime g_initial_opposite_first_bar = 0;
string   g_initial_opposite_first_event_id = "";
string   g_initial_opposite_second_event_id = "";
bool     g_exit_order_in_progress = false;
string   g_current_long_signal_event_id = "";
string   g_current_short_signal_event_id = "";
string   g_initial_entry_source_event_id = "";
string   g_add_entry_source_event_id = "";
string   g_exit_source_event_id = "";
string   g_last_position_state_alert = "";
int      g_exit_cooldown_bars = 0;
int      g_last_long_score = 0;
int      g_last_short_score = 0;
int      g_minimum_alert_score = 0;
double   g_original_tp = 0.0;
double   g_stop_loss_percent = 1.0;
bool     g_lot_editing = false;
bool     g_max_add_editing = false;
bool     g_sl_percent_editing = false;
string   g_last_lot_edit_text = "";
string   g_last_max_add_edit_text = "";
string   g_last_sl_percent_edit_text = "";
ENUM_ASSET_PROFILE g_asset_profile = ASSET_GENERIC;
const bool LEGACY_PROFIT_PROTECTION = false;
const int  LEGACY_WEAKENING_BARS = 2;
bool     g_short_term_partial_taken = false;
bool     g_short_term_break_even_applied = false;
double   g_profit_guard_peak_percent = 0.0;
bool     g_profit_guard_activated = false;
bool     g_hold_score_partial_done = false;
bool     g_chase_entry_candidate = false;
bool     g_chase_trend_hold_active = false;
int      g_chase_weakness_bars = 0;
// CHASE risk state. Confirmed signals do not retain a candidate origin.
double   g_chase_reference_high = 0.0;
double   g_chase_reference_low = 0.0;
double   g_chase_average_range = 0.0;
double   g_chase_peak_progress = 0.0;
int      g_chase_failure_bars = 0;
datetime g_chase_last_evaluation_bar = 0;


// v1.93 unified live/tester trade-cycle state. One object owns the complete
// lifecycle from the first counted signal until the managed position is fully
// closed. Working counters may be cleared after entry, but this snapshot stays
// intact so live trading and the strategy tester consume and audit one cycle.
enum ENUM_JTA_TRADE_CYCLE_STATE
{
   JTA_CYCLE_IDLE = 0,
   JTA_CYCLE_SIGNAL_ACCUMULATING,
   JTA_CYCLE_BREAKOUT_WAIT,
   JTA_CYCLE_ENTRY_PENDING,
   JTA_CYCLE_POSITION_OPEN,
   JTA_CYCLE_EXIT_PENDING,
   JTA_CYCLE_COOLDOWN
};

struct JTA_TRADE_CYCLE
{
   string cycle_id;
   string parent_cycle_id;
   bool reentry_origin;
   ENUM_JTA_TRADE_CYCLE_STATE state;
   int side;
   datetime created_time;
   datetime updated_time;

   int initial_signal_count;
   datetime initial_signal_times[3];
   string initial_signal_ids[3];

   datetime third_signal_time;
   string third_signal_id;
   double breakout_reference;
   int breakout_elapsed_bars;

   string entry_source_event_id;
   ulong entry_order_ticket;
   ulong position_id;
   datetime entry_time;
   double entry_price;
   double initial_sl;
   double initial_tp;

   int add_signal_count;
   datetime add_signal_times[2];
   string add_signal_ids[2];
   int additional_entry_count;
   int additional_entry_filled_count;
   string add_last_consumed_pair_key;

   // v1.97 position-management snapshot: the same cycle retains the
   // canonical HoldEngine/RiskEngine states until final close.
   ENUM_HOLD_STATE hold_state;
   ENUM_PROFIT_PROTECTION_STATE protection_state;
   double peak_r;

   int opposite_signal_count;
   datetime opposite_signal_times[2];
   string opposite_signal_ids[2];

   string exit_source_event_id;
   string exit_reason;
   string last_reset_reason;

   // v1.94 authoritative lifecycle/audit fields. These values remain inside
   // the same cycle from the first counted signal through the final close.
   long event_sequence;
   string last_stage;
   string last_transition_reason;
   datetime last_decision_bar_time;
   ulong entry_deal_ticket;
   ulong exit_deal_ticket;
   datetime exit_time;
   double exit_price;
   double realized_net;
   bool completed;

   // v2.69 strategy-consistency audit.
   ENUM_STRATEGY_MODE entry_strategy;
   bool entry_strategy_valid;
   bool strategy_changed_after_entry;
   datetime strategy_change_time;
};


JTA_TRADE_CYCLE g_trade_cycle;

// v3.68 terminal-persistent RANGE ADD-cycle state.
// Terminal Global Variables survive EA/chart/terminal restarts. They are
// keyed by symbol+magic and validated against the original managed-position
// open time so stale state from an older trade cycle cannot be reused.
string JTAAddPersistKey(const string suffix)
{
   string symbol_key=StringSubstr(_Symbol,0,16);
   return "JTCADD_"+symbol_key+"_"+StringFormat("%I64d",(long)InpMagicNumber)+"_"+suffix;
}

datetime JTAManagedInitialPositionTime()
{
   datetime earliest=0;
   for(int i=0;i<PositionsTotal();i++)
   {
      const ulong ticket=PositionGetTicket(i);
      if(ticket==0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL)!=_Symbol ||
         (ulong)PositionGetInteger(POSITION_MAGIC)!=InpMagicNumber)
         continue;
      const datetime pt=(datetime)PositionGetInteger(POSITION_TIME);
      if(pt>0 && (earliest==0 || pt<earliest))
         earliest=pt;
   }
   return earliest;
}

// v4.85: current INITIAL source ownership for Trigger-specific original risk.
bool g_initial_entry_was_trigger=false;
// v7.86 RANGE ADD: contraction must occur before re-expansion+REPEAT.
bool g_range_add_macd_contraction_seen=false;
double g_initial_trigger_sl_percent=0.0;

double JTATriggerSLPercentForStrategy(const ENUM_STRATEGY_MODE strategy)
{
   if(strategy==STRATEGY_RANGE)
      return MathMax(0.01,InpRangeTriggerSLPercent);
   return 0.0;
}

double JTATriggerMinDistanceRangeForStrategy(const ENUM_STRATEGY_MODE strategy)
{
   if(strategy==STRATEGY_RANGE)
      return MathMax(0.0,InpRangeTriggerMinDistanceRange);
   return 0.0;
}

int JTATriggerEntryExpiryBarsForStrategy(const ENUM_STRATEGY_MODE strategy)
{
   if(strategy==STRATEGY_RANGE)
      return MathMax(1,InpRangeTriggerEntryExpiryBars);
   return 1;
}

double JTAInitialRiskDistancePrice(const double entry,const double volume)
{
   if(entry<=0.0)
      return 0.0;
   if(g_initial_entry_was_trigger && g_initial_trigger_sl_percent>0.0)
      return entry*MathMax(0.01,g_initial_trigger_sl_percent)/100.0;
   return StopDistancePrice(entry,volume);
}

void JTAAddPersistenceClear()
{
   // LOW/HIGH/INV1 are legacy v3.68 keys. They are deleted for migration
   // hygiene but are no longer saved or loaded by current ADD logic.
   const string suffixes[]={"TIME","FILLED","TRIGGER_INITIAL","TRIGGER_SL_PCT","LOW","HIGH","INV1"};
   for(int i=0;i<ArraySize(suffixes);i++)
   {
      const string key=JTAAddPersistKey(suffixes[i]);
      if(GlobalVariableCheck(key))
         GlobalVariableDel(key);
   }
}

void JTAAddPersistenceSave()
{
   datetime cycle_time=JTAManagedInitialPositionTime();
   if(cycle_time<=0)
      cycle_time=g_initial_entry_time;
   if(cycle_time<=0)
      return;

   GlobalVariableSet(JTAAddPersistKey("TIME"),(double)cycle_time);
   GlobalVariableSet(JTAAddPersistKey("FILLED"),(double)MathMax(0,g_additional_entry_filled_count));
   GlobalVariableSet(JTAAddPersistKey("TRIGGER_INITIAL"),g_initial_entry_was_trigger?1.0:0.0);
   GlobalVariableSet(JTAAddPersistKey("TRIGGER_SL_PCT"),g_initial_trigger_sl_percent);
}

bool JTAAddPersistenceLoad(const datetime cycle_time)
{
   if(cycle_time<=0 || !GlobalVariableCheck(JTAAddPersistKey("TIME")))
      return false;

   const datetime stored_time=(datetime)(long)GlobalVariableGet(JTAAddPersistKey("TIME"));
   if(stored_time!=cycle_time)
      return false;

   if(GlobalVariableCheck(JTAAddPersistKey("FILLED")))
      g_additional_entry_filled_count=MathMax(
         g_additional_entry_filled_count,
         (int)MathRound(GlobalVariableGet(JTAAddPersistKey("FILLED"))));
   if(GlobalVariableCheck(JTAAddPersistKey("TRIGGER_INITIAL")))
      g_initial_entry_was_trigger=
         GlobalVariableGet(JTAAddPersistKey("TRIGGER_INITIAL"))>0.5;
   if(GlobalVariableCheck(JTAAddPersistKey("TRIGGER_SL_PCT")))
      g_initial_trigger_sl_percent=
         GlobalVariableGet(JTAAddPersistKey("TRIGGER_SL_PCT"));
   return true;
}
// v2.77 user-alert accounting. This is presentation-only state.
// Every managed EXIT deal contributes its actual net value, allowing the final
// close alert to show the whole EA trade-cycle P/L even on hedging accounts
// with INITIAL + ADD tickets.
double g_alert_cycle_realized_net = 0.0;

int g_trade_cycle_sequence = 0;
bool g_entry_strategy_preapproved = false;

// v1.98: re-entry is a child lifecycle derived only from a completed
// giveback exit. It owns its own final-signal window and one-shot setup key,
// so it cannot borrow the normal initial-entry counter or repeatedly submit
// the same signal pair on later bars.
enum ENUM_JTA_REENTRY_PERMISSION
{
   JTA_REENTRY_NONE = 0,
   JTA_REENTRY_GIVEBACK
};

struct JTA_REENTRY_CONTEXT
{
   ENUM_JTA_REENTRY_PERMISSION permission;
   bool active;
   string parent_cycle_id;
   string child_cycle_id;
   int side;
   datetime exit_time;
   double exit_price;
   string exit_reason;
   int signal_count;
   datetime signal_times[2];
   string signal_ids[2];
   string last_attempted_pair_key;
   bool order_pending;
   string last_block_reason;
};

JTA_REENTRY_CONTEXT g_reentry_context;

string ReentryPermissionName()
{
   return g_reentry_context.permission==JTA_REENTRY_GIVEBACK ? "GIVEBACK" : "NONE";
}

void ReentryContextReset(const string reason)
{
   g_reentry_context.permission=JTA_REENTRY_NONE;
   g_reentry_context.active=false;
   g_reentry_context.parent_cycle_id="";
   g_reentry_context.child_cycle_id="";
   g_reentry_context.side=0;
   g_reentry_context.exit_time=0;
   g_reentry_context.exit_price=0.0;
   g_reentry_context.exit_reason="";
   g_reentry_context.signal_count=0;
   for(int i=0;i<2;i++)
   {
      g_reentry_context.signal_times[i]=0;
      g_reentry_context.signal_ids[i]="";
   }
   g_reentry_context.last_attempted_pair_key="";
   g_reentry_context.order_pending=false;
   g_reentry_context.last_block_reason=reason;
}

void ReentryContextArmGiveback(const string parent_cycle_id,const int side,
                               const datetime exit_time,const double exit_price,
                               const string exit_reason)
{
   ReentryContextReset("");
   if(!InpUseGivebackReentry || side==0 || exit_time<=0 || exit_price<=0.0)
      return;
   g_reentry_context.permission=JTA_REENTRY_GIVEBACK;
   g_reentry_context.active=true;
   g_reentry_context.parent_cycle_id=parent_cycle_id;
   g_reentry_context.side=side;
   g_reentry_context.exit_time=exit_time;
   g_reentry_context.exit_price=exit_price;
   g_reentry_context.exit_reason=exit_reason;
}

bool ReentryContextWindowActive(int &bars_since_exit)
{
   bars_since_exit=-1;
   if(!g_reentry_context.active ||
      g_reentry_context.permission!=JTA_REENTRY_GIVEBACK ||
      g_reentry_context.side==0 || g_reentry_context.exit_time<=0)
      return false;
   bars_since_exit=iBarShift(_Symbol,AUTO_TF,g_reentry_context.exit_time,false);
   const int min_bars=MathMax(1,InpReentryMinimumBars);
   const int max_bars=MathMax(min_bars,InpGivebackReentryWindowBars);
   if(bars_since_exit<0 || bars_since_exit>max_bars)
   {
      ReentryContextReset("REENTRY_WINDOW_EXPIRED");
      return false;
   }
   return bars_since_exit>=min_bars;
}

void ReentryContextPruneSignals(const datetime current_bar_time)
{
   if(!g_reentry_context.active || g_reentry_context.signal_count<=0)
      return;
   const int window=MathMax(1,InpRangeSignalWindowBars);
   datetime kept_times[2]; string kept_ids[2]; int kept=0;
   for(int i=0;i<g_reentry_context.signal_count && i<2;i++)
   {
      const datetime t=g_reentry_context.signal_times[i];
      if(t<=0) continue;
      const int shift=iBarShift(_Symbol,AUTO_TF,t,true);
      if(shift>=1 && shift<=window)
      {
         kept_times[kept]=t; kept_ids[kept]=g_reentry_context.signal_ids[i]; kept++;
      }
   }
   for(int j=0;j<2;j++)
   {
      g_reentry_context.signal_times[j]=(j<kept?kept_times[j]:0);
      g_reentry_context.signal_ids[j]=(j<kept?kept_ids[j]:"");
   }
   g_reentry_context.signal_count=kept;
}

void ReentryContextConsumeFinalSignal(const int side,const string event_id,const datetime bar_time)
{
   if(!g_reentry_context.active || side==0 || event_id=="" || bar_time<=0) return;
   ReentryContextPruneSignals(bar_time);
   if(side!=g_reentry_context.side)
   {
      // Any opposite FINAL_CONFIRMED invalidates the quick same-direction
      // re-entry setup. A future entry must use the normal 3-signal path.
      ReentryContextReset("OPPOSITE_FINAL_SIGNAL");
      return;
   }
   for(int i=0;i<g_reentry_context.signal_count;i++)
      if(g_reentry_context.signal_ids[i]==event_id || g_reentry_context.signal_times[i]==bar_time)
         return;
   if(g_reentry_context.signal_count<2)
   {
      const int idx=g_reentry_context.signal_count++;
      g_reentry_context.signal_times[idx]=bar_time;
      g_reentry_context.signal_ids[idx]=event_id;
   }
   else
   {
      g_reentry_context.signal_times[0]=g_reentry_context.signal_times[1];
      g_reentry_context.signal_ids[0]=g_reentry_context.signal_ids[1];
      g_reentry_context.signal_times[1]=bar_time;
      g_reentry_context.signal_ids[1]=event_id;
   }
}

string ReentryContextPairKey()
{
   if(g_reentry_context.signal_count<2) return "";
   return g_reentry_context.signal_ids[0]+"=>"+g_reentry_context.signal_ids[1];
}

bool ReentryContextPairReady()
{
   if(!g_reentry_context.active || g_reentry_context.signal_count<2 || g_reentry_context.order_pending) return false;
   const string key=ReentryContextPairKey();
   return key!="" && key!=g_reentry_context.last_attempted_pair_key;
}

void ReentryContextConsumeAttempt(const string block_reason,const bool order_pending)
{
   const string key=ReentryContextPairKey();
   if(key!="") g_reentry_context.last_attempted_pair_key=key;
   g_reentry_context.last_block_reason=block_reason;
   g_reentry_context.order_pending=order_pending;
   g_reentry_context.signal_count=0;
   for(int i=0;i<2;i++) { g_reentry_context.signal_times[i]=0; g_reentry_context.signal_ids[i]=""; }
}

bool TradeCycleIsActive();
void TradeCycleEnsure(const int side,const string source_event_id);

void TradeCyclePrepareReentry(const int side,const string source_event_id,const string parent_cycle_id)
{
   if(TradeCycleIsActive()) return;
   TradeCycleEnsure(side,source_event_id);
   g_trade_cycle.entry_source_event_id=source_event_id;
   g_trade_cycle.parent_cycle_id=parent_cycle_id;
   g_trade_cycle.reentry_origin=true;
   g_trade_cycle.last_transition_reason="REENTRY_FROM_PARENT:"+parent_cycle_id;
   g_reentry_context.child_cycle_id=g_trade_cycle.cycle_id;
}

struct JTA_DECISION_SNAPSHOT
{
   datetime bar_time;
   int timeframe_seconds;
   bool final_long;
   bool final_short;
   int long_score;
   int short_score;
   int long_score_pre_context;
   int short_score_pre_context;
   int long_context_penalty;
   int short_context_penalty;
   int long_confidence;
   int short_confidence;
   bool long_bias;
   bool short_bias;
   bool long_timing;
   bool short_timing;
   bool long_pullback;
   bool short_pullback;
   bool long_reaccel;
   bool short_reaccel;
   bool long_strong_direction;
   bool short_strong_direction;
   bool long_no_trade;
   bool short_no_trade;
   bool long_unsafe;
   bool short_unsafe;
   bool long_chase;
   bool short_chase;
   string long_event_id;
   string short_event_id;
   bool shared_signal_auto_pass;
};

JTA_DECISION_SNAPSHOT g_decision_snapshot;

// v8.57: when M3 AUTO is active, this flag makes the legacy TREND/RANGE
// initial-entry paths analysis-only. M3AutoEngine is the sole INITIAL authority.
bool g_m3_auto_order_authority_active=false;
// Execution context is asserted only by M3AutoEngine immediately around a canonical M3 order submission.
// This is stricter than the legacy authority flag: diagnostics/legacy callers can never reach the gateway.
bool g_m3_auto_execution_context_active=false;

string TradeCycleStateName(const ENUM_JTA_TRADE_CYCLE_STATE state)
{
   if(state==JTA_CYCLE_SIGNAL_ACCUMULATING) return "SIGNAL_ACCUMULATING";
   if(state==JTA_CYCLE_BREAKOUT_WAIT) return "BREAKOUT_WAIT";
   if(state==JTA_CYCLE_ENTRY_PENDING) return "ENTRY_PENDING";
   if(state==JTA_CYCLE_POSITION_OPEN) return "POSITION_OPEN";
   if(state==JTA_CYCLE_EXIT_PENDING) return "EXIT_PENDING";
   if(state==JTA_CYCLE_COOLDOWN) return "COOLDOWN";
   return "IDLE";
}

string TradeCycleHoldStateName()
{
   if(g_trade_cycle.hold_state==HOLD_STRONG) return "STRONG";
   if(g_trade_cycle.hold_state==HOLD_NORMAL) return "NORMAL";
   if(g_trade_cycle.hold_state==HOLD_WARNING) return "WARNING";
   if(g_trade_cycle.hold_state==HOLD_PROFIT_PROTECT) return "PROFIT_PROTECT";
   if(g_trade_cycle.hold_state==HOLD_EXIT_CANDIDATE) return "EXIT_CANDIDATE";
   return "UNKNOWN";
}

string TradeCycleProtectionStateName()
{
   if(g_trade_cycle.protection_state==PROFIT_PROTECTION_ARMED) return "ARMED";
   if(g_trade_cycle.protection_state==PROFIT_PROTECTION_STRONG) return "STRONG";
   if(g_trade_cycle.protection_state==PROFIT_PROTECTION_NORMAL) return "NORMAL";
   if(g_trade_cycle.protection_state==PROFIT_PROTECTION_WARNING) return "WARNING";
   if(g_trade_cycle.protection_state==PROFIT_PROTECTION_EXIT) return "EXIT";
   return "UNKNOWN";
}

bool TradeCycleIsActive()
{
   return (g_trade_cycle.cycle_id!="" && g_trade_cycle.state!=JTA_CYCLE_IDLE);
}

bool TradeCycleOwnsInitialCounting()
{
   return (g_trade_cycle.state==JTA_CYCLE_SIGNAL_ACCUMULATING ||
           g_trade_cycle.state==JTA_CYCLE_BREAKOUT_WAIT ||
           g_trade_cycle.state==JTA_CYCLE_ENTRY_PENDING);
}

bool TradeCycleOwnsOpenPosition()
{
   return (g_trade_cycle.state==JTA_CYCLE_POSITION_OPEN ||
           g_trade_cycle.state==JTA_CYCLE_EXIT_PENDING);
}

void TradeCycleTouch(const string stage,const string reason,const datetime decision_bar_time=0)
{
   if(!TradeCycleIsActive())
      return;
   g_trade_cycle.event_sequence++;
   g_trade_cycle.last_stage=stage;
   g_trade_cycle.last_transition_reason=reason;
   if(decision_bar_time>0)
      g_trade_cycle.last_decision_bar_time=decision_bar_time;
   g_trade_cycle.updated_time=TimeCurrent();
}

void TradeCycleClear(const string reset_reason)
{
   g_trade_cycle.cycle_id="";
   g_trade_cycle.parent_cycle_id="";
   g_trade_cycle.reentry_origin=false;
   g_trade_cycle.state=JTA_CYCLE_IDLE;
   g_trade_cycle.side=0;
   g_trade_cycle.created_time=0;
   g_trade_cycle.updated_time=TimeCurrent();
   g_trade_cycle.initial_signal_count=0;
   for(int i=0;i<3;i++)
   {
      g_trade_cycle.initial_signal_times[i]=0;
      g_trade_cycle.initial_signal_ids[i]="";
   }
   g_trade_cycle.third_signal_time=0;
   g_trade_cycle.third_signal_id="";
   g_trade_cycle.breakout_reference=0.0;
   g_trade_cycle.breakout_elapsed_bars=0;
   g_trade_cycle.entry_source_event_id="";
   g_trade_cycle.entry_order_ticket=0;
   g_trade_cycle.position_id=0;
   g_trade_cycle.entry_time=0;
   g_trade_cycle.entry_price=0.0;
   g_trade_cycle.initial_sl=0.0;
   g_trade_cycle.initial_tp=0.0;
   g_trade_cycle.add_signal_count=0;
   for(int j=0;j<2;j++)
   {
      g_trade_cycle.add_signal_times[j]=0;
      g_trade_cycle.add_signal_ids[j]="";
      g_trade_cycle.opposite_signal_times[j]=0;
      g_trade_cycle.opposite_signal_ids[j]="";
   }
   g_trade_cycle.additional_entry_count=0;
   g_trade_cycle.additional_entry_filled_count=0;
   g_trade_cycle.add_last_consumed_pair_key="";
   g_trade_cycle.hold_state=HOLD_UNKNOWN;
   g_trade_cycle.protection_state=PROFIT_PROTECTION_UNKNOWN;
   g_trade_cycle.peak_r=0.0;
   g_trade_cycle.opposite_signal_count=0;
   g_trade_cycle.exit_source_event_id="";
   g_trade_cycle.exit_reason="";
   g_trade_cycle.last_reset_reason=reset_reason;
   g_trade_cycle.event_sequence=0;
   g_trade_cycle.last_stage="IDLE";
   g_trade_cycle.last_transition_reason=reset_reason;
   g_trade_cycle.last_decision_bar_time=0;
   g_trade_cycle.entry_deal_ticket=0;
   g_trade_cycle.exit_deal_ticket=0;
   g_trade_cycle.exit_time=0;
   g_trade_cycle.exit_price=0.0;
   g_trade_cycle.realized_net=0.0;
   g_alert_cycle_realized_net=0.0;
   g_trade_cycle.completed=false;
   g_trade_cycle.entry_strategy=STRATEGY_RANGE;
   g_trade_cycle.entry_strategy_valid=false;
   g_trade_cycle.strategy_changed_after_entry=false;
   g_trade_cycle.strategy_change_time=0;
}

void TradeCycleCaptureEntryStrategy(const ENUM_STRATEGY_MODE strategy)
{
   g_trade_cycle.entry_strategy=strategy;
   g_trade_cycle.entry_strategy_valid=true;
   g_trade_cycle.strategy_changed_after_entry=false;
   g_trade_cycle.strategy_change_time=0;
}

void TradeCycleObserveStrategyChange(const ENUM_STRATEGY_MODE current_strategy)
{
   if(!g_trade_cycle.entry_strategy_valid ||
      g_trade_cycle.strategy_changed_after_entry)
      return;

   if(current_strategy!=g_trade_cycle.entry_strategy)
   {
      g_trade_cycle.strategy_changed_after_entry=true;
      g_trade_cycle.strategy_change_time=TimeCurrent();
   }
}

void TradeCycleEnsure(const int side,const string source_event_id)
{
   if(g_trade_cycle.state!=JTA_CYCLE_IDLE && g_trade_cycle.cycle_id!="")
      return;
   g_trade_cycle_sequence++;
   g_trade_cycle.cycle_id=StringFormat("%s|%I64d|%d",_Symbol,(long)TimeCurrent(),g_trade_cycle_sequence);
   g_trade_cycle.state=JTA_CYCLE_SIGNAL_ACCUMULATING;
   g_trade_cycle.side=side;
   g_trade_cycle.created_time=TimeCurrent();
   g_trade_cycle.updated_time=TimeCurrent();
   g_trade_cycle.last_reset_reason="";
   g_trade_cycle.event_sequence=0;
   g_trade_cycle.completed=false;
   g_trade_cycle.last_stage="CYCLE_CREATED";
   g_trade_cycle.last_transition_reason="FIRST_FINAL_SIGNAL";
   if(source_event_id!="")
      g_trade_cycle.entry_source_event_id=source_event_id;
}

void TradeCycleSyncInitialWindow(const int side,const string source_event_id)
{
   const int active_count=(side>0?g_range_long_signal_count:g_range_short_signal_count);
   if(active_count<=0)
   {
      if(g_trade_cycle.state==JTA_CYCLE_SIGNAL_ACCUMULATING && g_trade_cycle.side==side)
         TradeCycleClear("INITIAL_WINDOW_EMPTY");
      return;
   }
   TradeCycleEnsure(side,source_event_id);
   // v2.23: once the third signal has armed BREAKOUT_WAIT, SignalEngine no
   // longer owns the initial-entry state. Later same-direction chart signals
   // must never push the lifecycle back to SIGNAL_ACCUMULATING.
   if(g_trade_cycle.state==JTA_CYCLE_BREAKOUT_WAIT ||
      g_trade_cycle.state==JTA_CYCLE_ENTRY_PENDING ||
      g_trade_cycle.state==JTA_CYCLE_POSITION_OPEN ||
      g_trade_cycle.state==JTA_CYCLE_EXIT_PENDING)
      return;
   g_trade_cycle.side=side;
   g_trade_cycle.state=JTA_CYCLE_SIGNAL_ACCUMULATING;
   g_trade_cycle.initial_signal_count=active_count;
   for(int i=0;i<3;i++)
   {
      datetime t=(side>0?g_range_long_signal_window[i]:g_range_short_signal_window[i]);
      g_trade_cycle.initial_signal_times[i]=t;
      g_trade_cycle.initial_signal_ids[i]=(t>0?StringFormat("%s|%d|%s",TimeToString(t,TIME_DATE|TIME_MINUTES),PeriodSeconds(AUTO_TF),side>0?"LONG":"SHORT"):"");
   }
   if(source_event_id!="")
      g_trade_cycle.entry_source_event_id=source_event_id;
   TradeCycleTouch("INITIAL_WINDOW_SYNC","COUNT_SYNC",0);
}

void TradeCycleArmBreakout(const int side,const string third_event_id,
                           const datetime third_time,const double reference_price)
{
   TradeCycleEnsure(side,third_event_id);
   g_trade_cycle.state=JTA_CYCLE_BREAKOUT_WAIT;
   g_trade_cycle.side=side;
   g_trade_cycle.third_signal_id=third_event_id;
   g_trade_cycle.third_signal_time=third_time;
   g_trade_cycle.breakout_reference=reference_price;
   g_trade_cycle.breakout_elapsed_bars=0;
   TradeCycleTouch("BREAKOUT_WAIT","THREE_SIGNALS_REACHED",third_time);
}

void TradeCycleMarkEntryPending(const int side,const string source_event_id,
                                const double sl,const double tp)
{
   TradeCycleEnsure(side,source_event_id);
   g_trade_cycle.state=JTA_CYCLE_ENTRY_PENDING;
   g_trade_cycle.side=side;
   g_trade_cycle.entry_source_event_id=source_event_id;
   g_trade_cycle.initial_sl=sl;
   g_trade_cycle.initial_tp=tp;
   TradeCycleTouch("ENTRY_PENDING","ORDER_REQUEST_ACCEPTED",0);
}

void TradeCycleMarkPositionOpen(const ulong position_id,const datetime entry_time,
                                const double entry_price)
{
   g_trade_cycle.state=JTA_CYCLE_POSITION_OPEN;
   g_trade_cycle.position_id=position_id;
   g_trade_cycle.entry_time=entry_time;
   g_trade_cycle.entry_price=entry_price;
   TradeCycleTouch("POSITION_OPEN","DEAL_CONFIRMED",entry_time);
}

void TradeCycleSyncAddCounter(const string source_event_id)
{
   g_trade_cycle.add_signal_count=g_add_same_direction_signal_count;
   g_trade_cycle.add_signal_times[0]=g_add_first_signal_bar;
   g_trade_cycle.add_signal_times[1]=g_add_last_counted_signal_bar;
   g_trade_cycle.add_signal_ids[0]=g_add_first_signal_event_id;
   g_trade_cycle.add_signal_ids[1]=source_event_id!=""?source_event_id:g_add_second_signal_event_id;
   g_trade_cycle.additional_entry_count=g_additional_entry_count;
   g_trade_cycle.additional_entry_filled_count=g_additional_entry_filled_count;
   g_trade_cycle.add_last_consumed_pair_key=g_add_last_consumed_pair_key;
   JTAAddPersistenceSave();
   TradeCycleTouch("ADD_COUNTER_SYNC","ADD_SIGNAL_UPDATE",0);
}

void TradeCycleSyncOppositeCounter(const string source_event_id)
{
   g_trade_cycle.opposite_signal_count=g_initial_opposite_confirm_count;
   g_trade_cycle.opposite_signal_times[0]=g_initial_opposite_first_bar;
   g_trade_cycle.opposite_signal_times[1]=g_initial_opposite_last_bar;
   g_trade_cycle.opposite_signal_ids[0]=g_initial_opposite_first_event_id;
   g_trade_cycle.opposite_signal_ids[1]=source_event_id!=""?source_event_id:g_initial_opposite_second_event_id;
   TradeCycleTouch("OPPOSITE_COUNTER_SYNC","OPPOSITE_SIGNAL_UPDATE",0);
}

void TradeCycleRestorePositionWorkingState()
{
   if(g_trade_cycle.cycle_id=="" ||
      (g_trade_cycle.state!=JTA_CYCLE_POSITION_OPEN &&
       g_trade_cycle.state!=JTA_CYCLE_EXIT_PENDING))
      return;

   g_add_same_direction_signal_count=g_trade_cycle.add_signal_count;
   // Break-confirm is intentionally not persisted. After terminal/reload the
   // pair remains READY, but a fresh full-break must be observed before ADD.
   g_add_break_confirm_bar=0;
   g_add_first_signal_bar=g_trade_cycle.add_signal_times[0];
   g_add_last_counted_signal_bar=g_trade_cycle.add_signal_times[1];
   g_add_first_signal_event_id=g_trade_cycle.add_signal_ids[0];
   g_add_second_signal_event_id=g_trade_cycle.add_signal_ids[1];
   g_additional_entry_count=g_trade_cycle.additional_entry_count;
   g_additional_entry_filled_count=g_trade_cycle.additional_entry_filled_count;
   g_add_last_consumed_pair_key=g_trade_cycle.add_last_consumed_pair_key;

   g_initial_opposite_confirm_count=g_trade_cycle.opposite_signal_count;
   g_initial_opposite_first_bar=g_trade_cycle.opposite_signal_times[0];
   g_initial_opposite_last_bar=g_trade_cycle.opposite_signal_times[1];
   g_initial_opposite_first_event_id=g_trade_cycle.opposite_signal_ids[0];
   g_initial_opposite_second_event_id=g_trade_cycle.opposite_signal_ids[1];
}

void TradeCycleSyncManagementState()
{
   if(!TradeCycleOwnsOpenPosition())
      return;
   g_trade_cycle.hold_state=g_hold_state;
   g_trade_cycle.protection_state=g_profit_protection_state;
   g_trade_cycle.peak_r=g_highest_profit_r;
   TradeCycleTouch("MANAGEMENT_SYNC","HOLD_RISK_STATE",0);
}

void TradeCycleMarkExitPending(const string source_event_id,const string reason)
{
   g_trade_cycle.state=JTA_CYCLE_EXIT_PENDING;
   g_trade_cycle.exit_source_event_id=source_event_id;
   g_trade_cycle.exit_reason=reason;
   TradeCycleTouch("EXIT_PENDING",reason,0);
}

void TradeCycleMarkCompleted(const ulong exit_deal_ticket,const datetime exit_time,
                             const double exit_price,const double realized_net,
                             const string reason)
{
   if(!TradeCycleIsActive())
      return;
   g_trade_cycle.exit_deal_ticket=exit_deal_ticket;
   g_trade_cycle.exit_time=exit_time;
   g_trade_cycle.exit_price=exit_price;
   g_trade_cycle.realized_net+=realized_net;
   g_trade_cycle.completed=true;
   g_trade_cycle.exit_reason=reason;
   TradeCycleTouch("CYCLE_COMPLETED",reason,exit_time);
}

// v1.54 runtime cache and diagnostics. Strategy rules are unchanged here.
struct JTA_FastIndicatorCache
{
   bool valid;
   long time_msc;
   bool long_allowed;
   bool short_allowed;
};
JTA_FastIndicatorCache g_fast_indicator_cache;
ulong g_perf_tick_calls = 0;
ulong g_perf_new_bar_calls = 0;
ulong g_perf_fast_cache_hits = 0;
ulong g_perf_fast_cache_misses = 0;
ulong g_perf_ui_refreshes = 0;
ulong g_perf_last_tick_us = 0;
ulong g_perf_peak_tick_us = 0;
// v8.269: completed-bar section latency diagnostics. Observation only; no
// strategy decision consumes these values.
ulong g_perf_last_state_eval_us = 0;
ulong g_perf_peak_state_eval_us = 0;
ulong g_perf_last_m3_auto_us = 0;
ulong g_perf_peak_m3_auto_us = 0;
ulong g_perf_last_signal_us = 0;
ulong g_perf_peak_signal_us = 0;
// v8.286: split SignalEngine latency into legacy RANGE and legacy WATCH subpaths.
ulong g_perf_last_signal_range_us = 0;
ulong g_perf_peak_signal_range_us = 0;
ulong g_perf_last_signal_watch_us = 0;
ulong g_perf_peak_signal_watch_us = 0;
// v8.288: M3 lightweight DIRECTION shadow parity audit. Observation only.
ulong g_perf_last_light_direction_us = 0;
ulong g_perf_peak_light_direction_us = 0;
ulong g_light_direction_parity_checks = 0;
ulong g_light_direction_parity_mismatches = 0;
int   g_light_direction_shadow_pulse_side = 0;
int   g_light_direction_actual_pulse_side = 0;
bool  g_light_direction_last_parity = true;
bool  g_light_direction_shadow_initialized = false;
bool  g_light_direction_shadow_long_active = false;
bool  g_light_direction_shadow_short_active = false;
datetime g_light_direction_shadow_last_long_bar = 0;
datetime g_light_direction_shadow_last_short_bar = 0;
datetime g_light_direction_shadow_event_time = 0;
int      g_light_direction_shadow_event_side = 0;
double   g_light_direction_shadow_last_high = 0.0;
double   g_light_direction_shadow_last_low = 0.0;
ulong g_perf_last_assist_write_us = 0;
ulong g_perf_peak_assist_write_us = 0;
long  g_last_ui_refresh_msc = 0;
bool  g_ui_force_refresh = true;
// Last integrated position side used to avoid repeating the complete flat-state
// reset block on every market tick while no position exists. 999 means that
// the first OnTick call must initialize the flat state once.
int   g_last_integrated_side = 999;

void RequestUIRefresh() { g_ui_force_refresh = true; }

// UI change-cache helpers are implemented with the panel functions below.
bool UISetIntegerIfChanged(const string name,
                           const ENUM_OBJECT_PROPERTY_INTEGER property,
                           const long value);
bool UISetDoubleIfChanged(const string name,
                          const ENUM_OBJECT_PROPERTY_DOUBLE property,
                          const double value,
                          const double tolerance = 0.0);
bool UISetStringIfChanged(const string name,
                          const ENUM_OBJECT_PROPERTY_STRING property,
                          const string value);

// v4.04 shared completed-bar market snapshot. Entry/hold/exit helpers that
// consume only closed bars reuse one CopyBuffer/CopyRates set for the complete
// active bar. If a later caller needs a longer lookback, the cache expands once.
// Live Bid/Ask, Peak-R, SL protection and Trigger crossing remain tick-driven.
struct JTA_MarketSnapshotMeta
{
   bool valid;
   datetime source_bar_time;  // open time of current [0] bar; cache generation key
   datetime closed_bar_time;  // open time of completed [1] bar; M3 decision/event key
   int loaded_count;         // core: Rates + MACD Base + Delta Raw + MA7/22
   int common_loaded_count;  // Direction/Zero + Delta EMA/Volume
   int assist_loaded_count;  // MACD Final Wave + Raw Price MACD
   int range_loaded_count;   // MA70/111/200
};
JTA_MarketSnapshotMeta g_market_snapshot;

// Existing canonical completed-bar snapshot. v7.82 extends this one owner
// instead of creating a second signal-specific cache.
double   g_ms_macd[];               // MACD Base
double   g_ms_delta[];              // Delta Raw
double   g_ms_fast_ma[];            // MA7
double   g_ms_slow_ma[];            // MA22
MqlRates g_ms_rates[];

double   g_ms_macd_direction[];
double   g_ms_macd_zero_state[];
double   g_ms_delta_ema[];
double   g_ms_delta_volume[];

double   g_ms_macd_wave[];
double   g_ms_macd_raw_price[];

double   g_ms_ma70[];
double   g_ms_ma111[];
double   g_ms_ma200[];
ulong    g_perf_snapshot_hits = 0;
ulong    g_perf_snapshot_misses = 0;


// ===== Integrated common helper library =====
//+------------------------------------------------------------------+
//| Joon_Integrated_Function_Library_v1_02.mqh                       |
//| Pure common helpers only; no signal, hold or exit decisions       |
//| Install: MQL5\Include\Joon\                                    |
//+------------------------------------------------------------------+


struct JTF_PositionGroup
{
   int      side;          // +1 buy, -1 sell, 0 none/mixed
   int      count;
   double   volume;
   double   average_price;
   double   sl;
   double   tp;
   double   floating_profit;
   datetime oldest_time;
   ulong    newest_ticket;

   void Reset()
   {
      side            = 0;
      count           = 0;
      volume          = 0.0;
      average_price   = 0.0;
      sl              = 0.0;
      tp              = 0.0;
      floating_profit = 0.0;
      oldest_time     = 0;
      newest_ticket   = 0;
   }
};

//------------------------- Numeric helpers --------------------------
double JTF_ClampDouble(const double value,const double minimum,const double maximum)
{
   return MathMax(minimum,MathMin(maximum,value));
}

int JTF_ClampInt(const int value,const int minimum,const int maximum)
{
   return (int)MathMax(minimum,MathMin(maximum,value));
}

double JTF_SafeDivide(const double numerator,const double denominator,const double fallback=0.0)
{
   if(MathAbs(denominator)<=DBL_EPSILON)
      return fallback;
   return numerator/denominator;
}

double JTF_TickSize(const string symbol="")
{
   const string target=(symbol=="" ? _Symbol : symbol);
   double value=SymbolInfoDouble(target,SYMBOL_TRADE_TICK_SIZE);
   if(value<=0.0)
      value=SymbolInfoDouble(target,SYMBOL_POINT);
   return value;
}

double JTF_NormalizePrice(const double price,const string symbol="")
{
   const string target=(symbol=="" ? _Symbol : symbol);
   const double tick=JTF_TickSize(target);
   const int digits=(int)SymbolInfoInteger(target,SYMBOL_DIGITS);
   if(tick<=0.0)
      return NormalizeDouble(price,digits);
   return NormalizeDouble(MathRound(price/tick)*tick,digits);
}

double JTF_NormalizeVolume(const double requested,const string symbol="")
{
   const string target=(symbol=="" ? _Symbol : symbol);
   double minimum=SymbolInfoDouble(target,SYMBOL_VOLUME_MIN);
   double maximum=SymbolInfoDouble(target,SYMBOL_VOLUME_MAX);
   double step=SymbolInfoDouble(target,SYMBOL_VOLUME_STEP);
   if(step<=0.0) step=(minimum>0.0 ? minimum : 0.01);
   if(minimum<=0.0) minimum=step;
   if(maximum<minimum) maximum=minimum;

   double value=MathMax(minimum,MathMin(maximum,requested));
   value=minimum+MathFloor((value-minimum)/step+1e-9)*step;
   return NormalizeDouble(MathMax(minimum,MathMin(maximum,value)),8);
}

double JTF_ProtectionMinimumDistance(const string symbol="")
{
   const string target=(symbol=="" ? _Symbol : symbol);
   const double point=SymbolInfoDouble(target,SYMBOL_POINT);
   const long stops=SymbolInfoInteger(target,SYMBOL_TRADE_STOPS_LEVEL);
   const long freeze=SymbolInfoInteger(target,SYMBOL_TRADE_FREEZE_LEVEL);
   return MathMax((double)MathMax(stops,freeze)*point,JTF_TickSize(target));
}

bool JTF_ValidStopPrice(const int side,const double reference_price,
                        const double requested_distance,double &stop_price,
                        const string symbol="")
{
   if(side==0 || reference_price<=0.0 || requested_distance<=0.0)
      return false;
   const string target=(symbol=="" ? _Symbol : symbol);
   const double distance=MathMax(requested_distance,JTF_ProtectionMinimumDistance(target));
   stop_price=JTF_NormalizePrice(reference_price-(side>0 ? distance : -distance),target);
   return (side>0 ? stop_price<reference_price : stop_price>reference_price);
}

// EntryEngine, PositionManager and SignalEngine share one result contract
// without creating a new engine.


//-------------------------- Data helpers -----------------------------
// Market data copying is centralized in MarketDataEngine.mqh.
// Strategy modules must consume the shared snapshot instead of calling CopyBuffer/CopyRates.

bool JTF_IsNewBar(datetime &stored_bar_time,const string symbol="",
                  const ENUM_TIMEFRAMES timeframe=PERIOD_CURRENT)
{
   const string target=(symbol=="" ? _Symbol : symbol);
   const datetime current=iTime(target,timeframe,0);
   if(current<=0 || current==stored_bar_time)
      return false;
   stored_bar_time=current;
   return true;
}

//------------------------- Position helpers --------------------------
bool JTF_IsManagedPositionSelected(const string symbol,const ulong magic)
{
   return PositionGetString(POSITION_SYMBOL)==symbol &&
          (ulong)PositionGetInteger(POSITION_MAGIC)==magic;
}

bool JTF_GetManagedPositionGroup(const string symbol,const ulong magic,
                                 JTF_PositionGroup &group)
{
   group.Reset();
   double weighted_price=0.0;
   int detected_side=0;

   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      const ulong ticket=PositionGetTicket(i);
      if(ticket==0 || !PositionSelectByTicket(ticket) ||
         !JTF_IsManagedPositionSelected(symbol,magic))
         continue;

      const ENUM_POSITION_TYPE type=(ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const int side=(type==POSITION_TYPE_BUY ? 1 : -1);
      const double volume=PositionGetDouble(POSITION_VOLUME);
      if(volume<=0.0)
         continue;

      if(detected_side==0) detected_side=side;
      else if(detected_side!=side) detected_side=2; // mixed hedge group

      const datetime position_time=(datetime)PositionGetInteger(POSITION_TIME);
      group.count++;
      group.volume+=volume;
      weighted_price+=PositionGetDouble(POSITION_PRICE_OPEN)*volume;
      group.floating_profit+=PositionGetDouble(POSITION_PROFIT);
      if(group.oldest_time==0 || position_time<group.oldest_time)
         group.oldest_time=position_time;
      if(ticket>group.newest_ticket)
         group.newest_ticket=ticket;

      const double position_sl=PositionGetDouble(POSITION_SL);
      const double position_tp=PositionGetDouble(POSITION_TP);
      if(position_sl>0.0)
      {
         if(group.sl<=0.0) group.sl=position_sl;
         else group.sl=(side>0 ? MathMax(group.sl,position_sl) : MathMin(group.sl,position_sl));
      }
      if(position_tp>0.0)
      {
         if(group.tp<=0.0) group.tp=position_tp;
         else group.tp=(side>0 ? MathMin(group.tp,position_tp) : MathMax(group.tp,position_tp));
      }
   }

   if(group.volume<=0.0)
      return false;
   group.average_price=weighted_price/group.volume;
   group.side=(detected_side==2 ? 0 : detected_side);
   return true;
}

bool JTF_ForeignPositionExists(const string symbol,const ulong managed_magic)
{
   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      const ulong ticket=PositionGetTicket(i);
      if(ticket==0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL)==symbol &&
         (ulong)PositionGetInteger(POSITION_MAGIC)!=managed_magic)
         return true;
   }
   return false;
}

//--------------------------- Trade helpers ---------------------------
bool JTF_TradeResultSucceeded(CTrade &trade_obj)
{
   const uint code=trade_obj.ResultRetcode();
   return code==TRADE_RETCODE_DONE ||
          code==TRADE_RETCODE_DONE_PARTIAL ||
          code==TRADE_RETCODE_PLACED ||
          code==TRADE_RETCODE_NO_CHANGES;
}

string JTF_TradeRetcodeText(CTrade &trade_obj)
{
   return IntegerToString((int)trade_obj.ResultRetcode())+" / "+trade_obj.ResultRetcodeDescription();
}

//--------------------------- Object helpers --------------------------
int JTF_DeleteObjectsByPrefix(const long chart_id,const string prefix,
                              const int subwindow=-1,const int object_type=-1,
                              const bool redraw=true)
{
   int deleted=0;
   for(int i=ObjectsTotal(chart_id,subwindow,object_type)-1;i>=0;i--)
   {
      const string name=ObjectName(chart_id,i,subwindow,object_type);
      if(StringFind(name,prefix)!=0)
         continue;
      if(ObjectDelete(chart_id,name))
         deleted++;
   }
   if(redraw) ChartRedraw(chart_id);
   return deleted;
}

int JTF_StyleVerticalLinesByPrefix(const long chart_id,const string prefix,
                                   const color line_color,const ENUM_LINE_STYLE style,
                                   const int width=1)
{
   int changed=0;
   for(int i=ObjectsTotal(chart_id,-1,OBJ_VLINE)-1;i>=0;i--)
   {
      const string name=ObjectName(chart_id,i,-1,OBJ_VLINE);
      if(StringFind(name,prefix)!=0)
         continue;
      ObjectSetInteger(chart_id,name,OBJPROP_COLOR,line_color);
      ObjectSetInteger(chart_id,name,OBJPROP_STYLE,style);
      ObjectSetInteger(chart_id,name,OBJPROP_WIDTH,width);
      changed++;
   }
   return changed;
}

bool JTF_CreateVerticalMarker(const long chart_id,const string name,
                              const datetime time_value,const color line_color,
                              const ENUM_LINE_STYLE style,const int width,
                              const string tooltip,const bool selectable=true)
{
   if(ObjectFind(chart_id,name)>=0)
      ObjectDelete(chart_id,name);
   if(!ObjectCreate(chart_id,name,OBJ_VLINE,0,time_value,0.0))
      return false;
   ObjectSetInteger(chart_id,name,OBJPROP_COLOR,line_color);
   ObjectSetInteger(chart_id,name,OBJPROP_STYLE,style);
   ObjectSetInteger(chart_id,name,OBJPROP_WIDTH,width);
   ObjectSetInteger(chart_id,name,OBJPROP_SELECTABLE,selectable);
   ObjectSetInteger(chart_id,name,OBJPROP_HIDDEN,false);
   ObjectSetString(chart_id,name,OBJPROP_TOOLTIP,tooltip);
   ChartRedraw(chart_id);
   return true;
}

//---------------------------- File helpers ---------------------------
string JTF_SafeFileToken(string value)
{
   const string invalid="\\/:*?\"<>|";
   for(int i=0;i<StringLen(invalid);i++)
      StringReplace(value,StringSubstr(invalid,i,1),"_");
   StringReplace(value," ","_");
   return value;
}


//-------------------- Fast/simple strategy helpers -------------------
// These helpers centralize generic decisions so the EA does not repeat
// cooldown and N-of-3 logic in multiple RANGE/TREND paths.
int JTF_BoolCount3(const bool a,const bool b,const bool c)
{
   return (a ? 1 : 0)+(b ? 1 : 0)+(c ? 1 : 0);
}

bool JTF_AtLeastNOf3(const bool a,const bool b,const bool c,const int required)
{
   return JTF_BoolCount3(a,b,c)>=JTF_ClampInt(required,1,3);
}

int JTF_PostExitMinimumBars(const bool fast_simple,
                            const bool range_strategy,
                            const bool stop_exit,
                            const int normal_cooldown,
                            const int range_stop_bars,
                            const int trend_stop_bars)
{
   if(!fast_simple || !stop_exit)
      return MathMax(0,normal_cooldown);
   return range_strategy ? MathMax(0,range_stop_bars)
                         : MathMax(0,trend_stop_bars);
}

bool JTF_FreshClosedBarAfter(const datetime closed_bar_time,
                             const datetime event_time)
{
   return closed_bar_time>0 && (event_time<=0 || closed_bar_time>event_time);
}

bool JTF_ReentryReady(const int bars_after_exit,
                      const int minimum_bars,
                      const bool fresh_signal_set,
                      const bool structure_valid)
{
   return bars_after_exit>=MathMax(0,minimum_bars) &&
          fresh_signal_set &&
          structure_valid;
}

//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
double NormalizeVolume(const double requested)
{
   return JTF_NormalizeVolume(requested,_Symbol);
}

//+------------------------------------------------------------------+
double NormalizePrice(const double price)
{
   return JTF_NormalizePrice(price,_Symbol);
}

//+------------------------------------------------------------------+
double ProtectionMinimumDistance()
{
   return JTF_ProtectionMinimumDistance(_Symbol);
}

//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
bool IsNewAlertBar(const int side)
{
   const datetime bar_time = iTime(_Symbol, g_calc_tf, 1);
   if(bar_time <= 0)
      return false;
   if(side > 0)
   {
      if(bar_time == g_last_long_alert_bar)
         return false;
      g_last_long_alert_bar = bar_time;
      return true;
   }
   if(bar_time == g_last_short_alert_bar)
      return false;
   g_last_short_alert_bar = bar_time;
   return true;
}

//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
// Shared final order path for both strategy entry engines.
// Strategy-specific qualification must be completed before this function.
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+


//================ TREND STRATEGY MODULE ==================
//+------------------------------------------------------------------+


// v2.95 engine responsibility forward declarations.
bool PositionDirectionHoldSupported(const int side,int &support_count,string &detail);
bool EvaluateChaseTrendPersistence(const int side,int &conditions,int &macd_same_bars,
                                   int &delta_same_bars,string &detail);
bool ManageChaseTrendProfit(const int side,const double progress_percent,const int hold_score);
bool ExitEngineEvaluateCompletedBarSignalExit(const int position_side,
                                              const bool early_failure,
                                              const bool direction_hold_supported,
                                              const string direction_support_detail,
                                              const bool opposite_signal_confirmed,
                                              const bool fresh_extreme_update,
                                              const bool full_exit,
                                              const bool sideways_hold);
bool EntryEngineEvaluateTrendAdditional(const int position_side,
                                        const bool add_chase_promoted,
                                        const bool add_pattern_ok,
                                        const bool no_trade_zone,
                                        const int no_trade_flags,
                                        const bool add_confident,
                                        const int add_confidence,
                                        const int opposite_add_confidence,
                                        const bool add_market_filter_ok,
                                        const bool add_structure_ok,
                                        const bool add_stage_two,
                                        const bool add_stage_three,
                                        const bool oversized,
                                        const datetime closed_auto_bar,
                                        const string lifecycle_pattern_detail);




// v2.99 forward declaration for AUTO START diagnostic event.
void DataExportWriteUnifiedEvent(const string record_type,
                                 const string event_name,
                                 const int side,
                                 const ulong position_id,
                                 const double price,
                                 const double volume,
                                 const int score,
                                 const string decision,
                                 const string reason,
                                 const string source_event_id,
                                 const double value1,
                                 const double value2,
                                 const string detail,
                                 const datetime event_time);

string AssistStateName(const ENUM_JTA_ASSIST_STATE state);
int AssistStateDirection(const ENUM_JTA_ASSIST_STATE state);
void StateEvaluationReset();
bool StateEvaluationInitialize();
bool StateEvaluationWarmupRebuild();
bool M3AssistWarmupRebuild();
void StateEvaluationRelease();
bool StateEvaluationUpdateOnClosedBar();
bool StateEvaluationProcessIfNewBar();
void UIRenderAssistState();
void WriteAssistStateCsv();
void CloseAssistStateCsv();

#endif // __JOON_COMMON_STATE_MQH__
