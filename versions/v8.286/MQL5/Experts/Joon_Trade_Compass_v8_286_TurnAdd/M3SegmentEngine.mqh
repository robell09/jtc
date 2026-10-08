//+------------------------------------------------------------------+
//| M3SegmentEngine.mqh                                              |
//| M3 market-data interpretation and segment lifecycle owner        |
//+------------------------------------------------------------------+
#ifndef __JOON_M3_SEGMENT_ENGINE_MQH__
#define __JOON_M3_SEGMENT_ENGINE_MQH__

// AUTO is intentionally independent from the legacy RANGE/TREND signal
// authority. SignalEngine owns chart/alert signals; this engine owns AUTO.
// v8.77 rebuild: the persistent M3 episode is the single market-direction authority.
// Historical bars are replayed only to rebuild the current episode; they are not retained as a trading database.
// No signal-count, score, MA22-only, or symbol-specific entry path is permitted.

enum JTC_M3_LIFECYCLE_STATE
{
   JTC_M3_FLAT = 0,
   JTC_M3_WATCH_LONG,
   JTC_M3_WATCH_SHORT,
   JTC_M3_READY_LONG,
   JTC_M3_READY_SHORT,
   JTC_M3_HOLD_LONG,
   JTC_M3_HOLD_SHORT,
   JTC_M3_PROFIT_LONG,
   JTC_M3_PROFIT_SHORT,
   JTC_M3_FAILURE_LONG,
   JTC_M3_FAILURE_SHORT
};

enum JTC_M3_SEGMENT_DIRECTION
{
   M3_SEG_NONE  = 0,
   M3_SEG_LONG  = 1,
   M3_SEG_SHORT = -1,
   M3_SEG_RANGE = 2
};

enum JTC_M3_SEGMENT_PHASE
{
   M3_PHASE_NONE = 0,
   M3_PHASE_BUILD,
   M3_PHASE_ACTIVE,
   M3_PHASE_PULLBACK,
   M3_PHASE_REACCEL,
   M3_PHASE_EXHAUSTION,
   M3_PHASE_TRANSITION
};

// v8.242: backported v8.236 CSV-only ACCEL decision audit.
// WATCH ownership/progression fields below are diagnostic context only in this
// v8.230-based hybrid; they do NOT gate ACCEL publication.
double   g_m3_accel_audit_structure_high=0.0;
double   g_m3_accel_audit_structure_low=0.0;
string   g_m3_accel_audit_structure_high_source="NONE";
string   g_m3_accel_audit_structure_low_source="NONE";
bool     g_m3_accel_audit_raw_long_break=false;
bool     g_m3_accel_audit_raw_short_break=false;
int      g_m3_accel_audit_watch_owner_side=0;
datetime g_m3_accel_audit_watch_owner_time=0;
bool     g_m3_accel_audit_long_watch_authorized=false;
bool     g_m3_accel_audit_short_watch_authorized=false;
double   g_m3_accel_audit_prior_long_accel_high=0.0;
double   g_m3_accel_audit_prior_short_accel_low=0.0;
bool     g_m3_accel_audit_long_price_extension=false;
bool     g_m3_accel_audit_short_price_extension=false;
bool     g_m3_accel_audit_emit_long=false;
bool     g_m3_accel_audit_emit_short=false;
string   g_m3_accel_audit_long_block_reason="";
string   g_m3_accel_audit_short_block_reason="";

struct JTC_M3_STATE
{
   datetime bar_time;
   int side;
   double close;
   double high;
   double low;
   double ma7;
   double ma22;
   double ma7_prev;
   double ma22_prev;
   double wave;
   double signal;
   double wave_prev;
   double signal_prev;
   double wave_prev2;
   double signal_prev2;
   double hist;
   double hist_prev;
   double raw_delta;
   double raw_delta_prev;
   double delta_ema;
   double delta_ema_prev;
   double volume;
   double volume_prev;
   double volume_avg;
   double volume_ratio;
   double macd_direction;
   double macd_zero;
};

struct JTC_M3_MACD_STRUCTURE
{
   bool above_zero;
   bool below_zero;
   bool above_signal;
   bool below_signal;
   bool rising;
   bool falling;
   bool expanding;
   bool contracting;
};

struct JTC_M3_MA22_STRUCTURE
{
   bool price_above;
   bool price_below;
   bool rising;
   bool falling;
   bool flattening;
   double slope;
   double slope_norm;
   double distance;
};

enum JTC_M3_RUNTIME_MODE
{
   M3_RUNTIME_WARMUP = 0,
   M3_RUNTIME_MONITORING,
   M3_RUNTIME_AUTOTRADING
};

enum JTC_M3_EPISODE_STATE
{
   M3_EP_NONE = 0,
   M3_EP_STRUCTURE_FORMED,
   M3_EP_PERSISTING,
   M3_EP_PULLBACK_STARTED,
   M3_EP_PULLBACK_HELD,
   M3_EP_REACCELERATION,
   M3_EP_TRIGGER,
   M3_EP_TRIGGER_CONSUMED,
   M3_EP_INVALIDATED
};

struct JTC_M3_SEGMENT_CONTEXT
{
   long id;
   int direction;
   int phase;
   datetime start_time;
   double start_price;
   double start_ma22;
   double start_macd;
   bool structure_valid;
   bool macd_valid;
   bool ma22_valid;
   bool pullback_active;
   bool reaccel_active;
   bool exhaustion_active;
   double last_close;
   // Adaptive swing structure: confirmed pivots, not a fixed N-bar trend count.
   double prev_swing_high;
   double last_swing_high;
   double prev_swing_low;
   double last_swing_low;
   // Protected structural anchors: the latest meaningful HL/LH used for
   // directional structure validation. A newly printed LL/HH never silently
   // replaces these anchors before failure is classified.
   double protected_swing_low;
   double protected_swing_high;
   bool   have_protected_low;
   bool   have_protected_high;
   bool   recovery_ready;
   bool   have_swing_high;
   bool   have_swing_low;
   bool   higher_high;
   bool   higher_low;
   bool   lower_high;
   bool   lower_low;
   bool   structure_break;
   bool   pullback_held;
   bool   structure_established;
   int    regime;
   int    structure_state;
   double entry_anchor_price;
   datetime entry_anchor_time;

   // External structure = dominant M3 direction. Internal structure = the
   // faster pullback/re-expansion structure used to time an entry.
   bool external_bullish;
   bool external_bearish;
   bool internal_bullish;
   bool internal_bearish;
   bool internal_pullback;
   bool internal_reaccel;
   bool setup_long;
   bool setup_short;
   bool trigger_long;
   bool trigger_short;
   double internal_trigger_high;
   double internal_trigger_low;
   double setup_low;
   double setup_high;

   // Canonical chronological M3 episode memory. These fields are event memory,
   // not a re-evaluation of the current candle. An entry can only progress
   // through this sequence: STRUCTURE -> PULLBACK -> HOLD -> REACCEL -> TRIGGER.
   datetime structure_high_time;
   datetime structure_low_time;
   datetime pullback_start_time;
   datetime pullback_reference_time;
   datetime reaccel_time;
   datetime trigger_time;
   double structure_high;
   double structure_low;
   double pullback_extreme;
   double pullback_reference;
   double reaccel_reference;
   string invalidation_reason;
   bool structure_episode;
   bool persistence_confirmed;
   bool pullback_episode;
   bool pullback_reference_set;
   bool reacceleration_episode;

   // Canonical chronological episode state. Legacy booleans above are mirrors.
   int episode_state;
   datetime persistence_time;
   datetime pullback_held_time;
   bool trigger_consumed;
   datetime invalidation_time;

   // Immutable event latch: order execution may consume the actionable trigger,
   // but SignalEngine must still be able to observe the same market event on
   // the same closed bar. This is event history, not another signal authority.
   int      last_trigger_event_side;
   datetime last_trigger_event_time;


   // Canonical ACCEL publication state. Raw structural/price/MACD acceleration
   // remains available through audit fields, while these fields are published
   // only after the same-direction WATCH owns an earlier completed bar.
   bool     display_accel_long_active;
   bool     display_accel_short_active;
   bool     display_accel_long_break_active;
   bool     display_accel_short_break_active;
   double   display_accel_long_break_level;
   double   display_accel_short_break_level;
   datetime display_accel_long_break_time;
   datetime display_accel_short_break_time;
   int      display_accel_side;
   datetime display_accel_time;

   // v8.208/v8.256: immutable CANONICAL publication latch. Raw detection may
   // occur earlier, but only WATCH-owned later-bar ACCEL reaches this latch.
   int      last_accel_event_side;
   datetime last_accel_event_time;
   // v8.242 diagnostic-only extrema; not an ACCEL publication gate.
   double   last_accel_event_high;
   double   last_accel_event_low;

   // v8.254: same-WATCH continuation ACCEL is chart-only information.
   // It is intentionally separate from display_accel_* / last_accel_event_* so
   // AUTO INITIAL/ADD/EXIT, REARM confirmation and alerts cannot consume it.
   int      chart_cont_accel_owner_side;
   datetime chart_cont_accel_owner_time;
   bool     chart_cont_accel_long_armed;
   bool     chart_cont_accel_short_armed;
   double   chart_cont_accel_ref_high;
   double   chart_cont_accel_ref_low;
   int      chart_cont_accel_side;
   datetime chart_cont_accel_time;

   // v8.256: chart publication budget for one canonical WATCH episode.
   // The first canonical ACCEL plus chart-only continuation ACCEL markers share
   // one maximum of five visible ACCEL markers. Internal/AUTO canonical ACCEL
   // events remain active after the visual budget is exhausted.
   int      chart_accel_publish_count;
   bool     chart_primary_accel_allowed;
};

JTC_M3_LIFECYCLE_STATE g_m3_state=JTC_M3_FLAT;
datetime g_m3_last_decision_bar=0;
datetime g_m3_last_entry_attempt_bar=0;
datetime g_m3_last_add_attempt_bar=0;

// v8.143 AUTO signal lifecycle. Raw WATCH/ACCEL remain independent manual
// signals; AUTO uses WATCH only to establish/refresh directional ownership,
// and may consume ACCEL only on a later completed bar in that same leg.
int      g_m3_auto_signal_leg_side=M3_SEG_NONE;
datetime g_m3_auto_signal_leg_start_time=0;
int      g_m3_auto_signal_leg_watch_sequence=0;
// v8.162: opposite StateEvaluation WATCH is EXIT + reverse INITIAL.
// Keep the reverse intent until the managed position is actually flat.
int      g_m3_pending_reverse_side=M3_SEG_NONE;
datetime g_m3_pending_reverse_watch_time=0;
// v8.249: REARM WATCH keeps EXIT authority but its next-cycle INITIAL waits
// for the first later same-direction STRUCTURAL ACCEL. Normal WATCH reversal
// behavior remains immediate after flat confirmation.
bool     g_m3_pending_reverse_requires_accel=false;
bool     g_m3_pending_reverse_accel_confirmed=false;
datetime g_m3_pending_reverse_accel_time=0;
// v8.251: persistent execution obligation. True only while this pending
// reversal still requires the pre-existing opposite managed position to be
// flattened. Actual completion authority is the live broker position state.
bool     g_m3_pending_reverse_exit_obligation=false;
// v8.252: pre-REARM recovery may flatten the opposite managed position before
// canonical REARM WATCH exists. This obligation is execution-only and never
// becomes pending_reverse/entry ownership.
bool     g_m3_pre_rearm_exit_obligation=false;
int      g_m3_pre_rearm_exit_recovery_side=M3_SEG_NONE;
int      g_m3_pre_rearm_exit_owner_side=M3_SEG_NONE;
datetime g_m3_pre_rearm_exit_owner_time=0;

int g_m3_profit_fade_bars=0;
int g_m3_failure_bars=0;

JTC_M3_SEGMENT_CONTEXT g_m3_segment;
long g_m3_segment_sequence=0;
JTC_M3_RUNTIME_MODE g_m3_runtime_mode=M3_RUNTIME_WARMUP;
bool g_m3_warmup_complete=false;
int g_m3_eval_index=1;
datetime g_m3_last_observed_bar=0;

// Persistent M3 market-structure memory. These survive segment recreation so
// a new directional segment can inherit already-confirmed external/internal
// structure instead of restarting its analysis from zero.
double g_m3_ext_prev_high=0.0, g_m3_ext_last_high=0.0;
double g_m3_ext_prev_low=0.0,  g_m3_ext_last_low=0.0;
double g_m3_int_prev_high=0.0, g_m3_int_last_high=0.0;
double g_m3_int_prev_low=0.0,  g_m3_int_last_low=0.0;
datetime g_m3_ext_prev_high_time=0, g_m3_ext_last_high_time=0;
datetime g_m3_ext_prev_low_time=0,  g_m3_ext_last_low_time=0;
datetime g_m3_int_prev_high_time=0, g_m3_int_last_high_time=0;
datetime g_m3_int_prev_low_time=0,  g_m3_int_last_low_time=0;
bool g_m3_ext_hh=false, g_m3_ext_hl=false, g_m3_ext_lh=false, g_m3_ext_ll=false;
bool g_m3_int_hh=false, g_m3_int_hl=false, g_m3_int_lh=false, g_m3_int_ll=false;
datetime g_m3_structure_last_bar=0;
// v8.152: producer-owned pivot events for the current completed M3 bar.
// Declared once at module scope; reset by M3UpdateAdaptiveSwingStructure()
// for each newly processed completed M3 bar.
bool g_m3_new_ext_high=false, g_m3_new_ext_low=false;
bool g_m3_new_int_high=false, g_m3_new_int_low=false;

string M3SegmentDirectionName(const int direction)
{
   if(direction==M3_SEG_LONG)  return "LONG";
   if(direction==M3_SEG_SHORT) return "SHORT";
   if(direction==M3_SEG_RANGE) return "RANGE";
   return "NONE";
}

string M3SegmentPhaseName(const int phase)
{
   switch(phase)
   {
      case M3_PHASE_BUILD:      return "BUILD";
      case M3_PHASE_ACTIVE:     return "ACTIVE";
      case M3_PHASE_PULLBACK:   return "PULLBACK";
      case M3_PHASE_REACCEL:    return "REACCEL";
      case M3_PHASE_EXHAUSTION: return "EXHAUSTION";
      case M3_PHASE_TRANSITION: return "TRANSITION";
      default:                  return "NONE";
   }
}

string M3RegimeName(const int regime)
{
   if(regime==JTC_M3_REGIME_TREND) return "TREND";
   if(regime==JTC_M3_REGIME_RANGE) return "RANGE";
   return "TRANSITION";
}

string M3StructureStateName(const int state)
{
   if(state==JTC_M3_POS_RUN) return "HEALTHY";
   if(state==JTC_M3_POS_WEAKENING) return "WEAKENING";
   if(state==JTC_M3_POS_PROTECT) return "BREAK";
   if(state==JTC_M3_POS_RECOVERY) return "RECOVERY";
   if(state==JTC_M3_POS_FAILURE) return "FAILURE";
   return "UNKNOWN";
}

string M3StateName(const JTC_M3_LIFECYCLE_STATE state)
{
   switch(state)
   {
      case JTC_M3_WATCH_LONG:   return "WATCH_LONG";
      case JTC_M3_WATCH_SHORT:  return "WATCH_SHORT";
      case JTC_M3_READY_LONG:   return "READY_LONG";
      case JTC_M3_READY_SHORT:  return "READY_SHORT";
      case JTC_M3_HOLD_LONG:    return "HOLD_LONG";
      case JTC_M3_HOLD_SHORT:   return "HOLD_SHORT";
      case JTC_M3_PROFIT_LONG:  return "PROFIT_LONG";
      case JTC_M3_PROFIT_SHORT: return "PROFIT_SHORT";
      case JTC_M3_FAILURE_LONG: return "FAILURE_LONG";
      case JTC_M3_FAILURE_SHORT:return "FAILURE_SHORT";
      default:                  return "FLAT";
   }
}

void M3AutoResetSegment()
{
   g_m3_segment.id=0;
   g_m3_segment.direction=M3_SEG_NONE;
   g_m3_segment.phase=M3_PHASE_NONE;
   g_m3_segment.start_time=0;
   g_m3_segment.start_price=0.0;
   g_m3_segment.start_ma22=0.0;
   g_m3_segment.start_macd=0.0;
   g_m3_segment.structure_valid=false;
   g_m3_segment.macd_valid=false;
   g_m3_segment.ma22_valid=false;
   g_m3_segment.pullback_active=false;
   g_m3_segment.reaccel_active=false;
   g_m3_segment.exhaustion_active=false;
   g_m3_segment.last_close=0.0;
   g_m3_segment.prev_swing_high=0.0;
   g_m3_segment.last_swing_high=0.0;
   g_m3_segment.prev_swing_low=0.0;
   g_m3_segment.last_swing_low=0.0;
   g_m3_segment.protected_swing_low=0.0;
   g_m3_segment.protected_swing_high=0.0;
   g_m3_segment.have_protected_low=false;
   g_m3_segment.have_protected_high=false;
   g_m3_segment.recovery_ready=false;
   g_m3_segment.have_swing_high=false;
   g_m3_segment.have_swing_low=false;
   g_m3_segment.higher_high=false;
   g_m3_segment.higher_low=false;
   g_m3_segment.lower_high=false;
   g_m3_segment.lower_low=false;
   g_m3_segment.structure_break=false;
   g_m3_segment.pullback_held=false;
   g_m3_segment.structure_established=false;
   g_m3_segment.regime=JTC_M3_REGIME_TRANSITION;
   g_m3_segment.structure_state=JTC_M3_POS_FLAT;
   g_m3_segment.entry_anchor_price=0.0;
   g_m3_segment.entry_anchor_time=0;
   g_m3_segment.external_bullish=false;
   g_m3_segment.external_bearish=false;
   g_m3_segment.internal_bullish=false;
   g_m3_segment.internal_bearish=false;
   g_m3_segment.internal_pullback=false;
   g_m3_segment.internal_reaccel=false;
   g_m3_segment.setup_long=false;
   g_m3_segment.setup_short=false;
   g_m3_segment.trigger_long=false;
   g_m3_segment.trigger_short=false;
   g_m3_segment.internal_trigger_high=0.0;
   g_m3_segment.internal_trigger_low=0.0;
   g_m3_segment.setup_low=0.0;
   g_m3_segment.setup_high=0.0;
   g_m3_segment.structure_high_time=0;
   g_m3_segment.structure_low_time=0;
   g_m3_segment.pullback_start_time=0;
   g_m3_segment.pullback_reference_time=0;
   g_m3_segment.reaccel_time=0;
   g_m3_segment.trigger_time=0;
   g_m3_segment.structure_high=0.0;
   g_m3_segment.structure_low=0.0;
   g_m3_segment.pullback_extreme=0.0;
   g_m3_segment.pullback_reference=0.0;
   g_m3_segment.reaccel_reference=0.0;
   g_m3_segment.invalidation_reason="";
   g_m3_segment.structure_episode=false;
   g_m3_segment.persistence_confirmed=false;
   g_m3_segment.pullback_episode=false;
   g_m3_segment.pullback_reference_set=false;
   g_m3_segment.reacceleration_episode=false;
   g_m3_segment.episode_state=M3_EP_NONE;
   g_m3_segment.persistence_time=0;
   g_m3_segment.pullback_held_time=0;
   g_m3_segment.trigger_consumed=false;
   g_m3_segment.invalidation_time=0;
   g_m3_segment.display_accel_long_active=false;
   g_m3_segment.display_accel_short_active=false;
   g_m3_segment.display_accel_long_break_active=false;
   g_m3_segment.display_accel_short_break_active=false;
   g_m3_segment.display_accel_long_break_level=0.0;
   g_m3_segment.display_accel_short_break_level=0.0;
   g_m3_segment.display_accel_long_break_time=0;
   g_m3_segment.display_accel_short_break_time=0;
   g_m3_segment.display_accel_side=0;
   g_m3_segment.display_accel_time=0;
   g_m3_segment.last_accel_event_side=0;
   g_m3_segment.last_accel_event_time=0;
   g_m3_segment.last_accel_event_high=0.0;
   g_m3_segment.last_accel_event_low=0.0;
   g_m3_segment.chart_cont_accel_owner_side=M3_SEG_NONE;
   g_m3_segment.chart_cont_accel_owner_time=0;
   g_m3_segment.chart_cont_accel_long_armed=false;
   g_m3_segment.chart_cont_accel_short_armed=false;
   g_m3_segment.chart_cont_accel_ref_high=0.0;
   g_m3_segment.chart_cont_accel_ref_low=0.0;
   g_m3_segment.chart_cont_accel_side=M3_SEG_NONE;
   g_m3_segment.chart_cont_accel_time=0;
   g_m3_segment.chart_accel_publish_count=0;
   g_m3_segment.chart_primary_accel_allowed=false;

   g_m3_auto_signal_leg_side=M3_SEG_NONE;
   g_m3_auto_signal_leg_start_time=0;
   g_m3_auto_signal_leg_watch_sequence=0;
   g_m3_pending_reverse_side=M3_SEG_NONE;
   g_m3_pending_reverse_watch_time=0;
   g_m3_pending_reverse_requires_accel=false;
   g_m3_pending_reverse_accel_confirmed=false;
   g_m3_pending_reverse_accel_time=0;
   g_m3_pending_reverse_exit_obligation=false;
   g_m3_pre_rearm_exit_obligation=false;
   g_m3_pre_rearm_exit_recovery_side=M3_SEG_NONE;
   g_m3_pre_rearm_exit_owner_side=M3_SEG_NONE;
   g_m3_pre_rearm_exit_owner_time=0;
}

void M3AutoResetFlatState()
{
   g_m3_state=JTC_M3_FLAT;
   g_m3_profit_fade_bars=0;
   g_m3_failure_bars=0;
   g_m3_ext_prev_high=0.0; g_m3_ext_last_high=0.0;
   g_m3_ext_prev_low=0.0;  g_m3_ext_last_low=0.0;
   g_m3_int_prev_high=0.0; g_m3_int_last_high=0.0;
   g_m3_int_prev_low=0.0;  g_m3_int_last_low=0.0;
   g_m3_ext_prev_high_time=0; g_m3_ext_last_high_time=0;
   g_m3_ext_prev_low_time=0;  g_m3_ext_last_low_time=0;
   g_m3_int_prev_high_time=0; g_m3_int_last_high_time=0;
   g_m3_int_prev_low_time=0;  g_m3_int_last_low_time=0;
   g_m3_ext_hh=false; g_m3_ext_hl=false; g_m3_ext_lh=false; g_m3_ext_ll=false;
   g_m3_int_hh=false; g_m3_int_hl=false; g_m3_int_lh=false; g_m3_int_ll=false;
   g_m3_structure_last_bar=0;
   M3AutoResetSegment();
}

bool M3AutoReadState(JTC_M3_STATE &s)
{
   if(!EnsureMarketSnapshotAssist(10))
      return false;

   // M3 decisions are always stamped with the completed [1] bar.
   // source_bar_time remains the cache generation key for the current [0] bar.
   s.bar_time=g_market_snapshot.closed_bar_time;
   s.close=g_ms_rates[1].close;
   s.high=g_ms_rates[1].high;
   s.low=g_ms_rates[1].low;
   s.ma7=g_ms_fast_ma[1];
   s.ma22=g_ms_slow_ma[1];
   s.ma7_prev=g_ms_fast_ma[2];
   s.ma22_prev=g_ms_slow_ma[2];

   s.wave=g_ms_macd_wave[1];
   s.signal=g_ms_macd[1];
   s.wave_prev=g_ms_macd_wave[2];
   s.signal_prev=g_ms_macd[2];
   s.wave_prev2=g_ms_macd_wave[3];
   s.signal_prev2=g_ms_macd[3];
   s.hist=s.wave-s.signal;
   s.hist_prev=s.wave_prev-s.signal_prev;

   s.raw_delta=g_ms_delta[1];
   s.raw_delta_prev=g_ms_delta[2];
   s.delta_ema=g_ms_delta_ema[1];
   s.delta_ema_prev=g_ms_delta_ema[2];
   s.volume=g_ms_delta_volume[1];
   s.volume_prev=g_ms_delta_volume[2];

   double sum=0.0;
   int n=0;
   for(int i=2;i<=8;i++)
   {
      if(g_ms_delta_volume[i]>0.0)
      {
         sum+=g_ms_delta_volume[i];
         n++;
      }
   }
   s.volume_avg=n>0 ? sum/n : MathMax(1.0,s.volume_prev);
   s.volume_ratio=s.volume_avg>0.0 ? s.volume/s.volume_avg : 1.0;
   s.macd_direction=g_ms_macd_direction[1];
   s.macd_zero=g_ms_macd_zero_state[1];
   return true;
}

double M3AutoATR()
{
   // During warmup/replay, use the ATR of the historical evaluation bar so
   // structure reconstruction is causal. Live processing keeps the existing
   // cached EntryATR path.
   if(g_m3_eval_index>1 && ArraySize(g_ms_rates)>g_m3_eval_index+15)
   {
      double tr_sum=0.0;
      int n=0;
      for(int i=g_m3_eval_index;i<g_m3_eval_index+14;i++)
      {
         const double h=g_ms_rates[i].high;
         const double l=g_ms_rates[i].low;
         const double pc=g_ms_rates[i+1].close;
         const double tr=MathMax(h-l,MathMax(MathAbs(h-pc),MathAbs(l-pc)));
         if(tr>0.0) { tr_sum+=tr; n++; }
      }
      if(n>0) return MathMax(_Point,tr_sum/n);
   }
   static datetime cached_bar=0;
   static double cached_atr=0.0;
   const datetime bar=(g_market_snapshot.closed_bar_time>0 ?
                        g_market_snapshot.closed_bar_time : iTime(_Symbol,AUTO_TF,1));
   if(bar==cached_bar && cached_atr>0.0) return cached_atr;
   cached_atr=EntryATR(AUTO_TF);
   cached_bar=bar;
   return cached_atr;
}

void M3AnalyzeMACD(const JTC_M3_STATE &s,JTC_M3_MACD_STRUCTURE &m)
{
   m.above_zero=(s.wave>0.0);
   m.below_zero=(s.wave<0.0);
   m.above_signal=(s.wave>s.signal);
   m.below_signal=(s.wave<s.signal);
   m.rising=(s.wave>s.wave_prev);
   m.falling=(s.wave<s.wave_prev);
   // Expanding/contracting remain descriptive magnitude states. They are not
   // directional evidence by themselves: |hist| can expand while momentum
   // strengthens in the opposite direction. Reacceleration logic below uses
   // the signed MACD movement instead.
   m.expanding=(MathAbs(s.hist)>MathAbs(s.hist_prev));
   m.contracting=(MathAbs(s.hist)<MathAbs(s.hist_prev));
}

void M3AnalyzeMA22(const JTC_M3_STATE &s,JTC_M3_MA22_STRUCTURE &m)
{
   const double atr=MathMax(_Point,M3AutoATR());
   m.slope=s.ma22-s.ma22_prev;
   m.slope_norm=m.slope/atr;
   m.price_above=(s.close>s.ma22);
   m.price_below=(s.close<s.ma22);
   m.rising=(m.slope>0.0);
   m.falling=(m.slope<0.0);
   m.flattening=(MathAbs(m.slope_norm)<=0.02);
   m.distance=MathAbs(s.close-s.ma22);
}

// v8.103: indicator alignment for structural acceleration pre-signals.
// Price structure remains primary. Indicators confirm that the new structural
// extension is actually accelerating in the same direction. No new numeric
// score, timer, cooldown, or symbol-specific threshold is introduced.
bool M3AccelerationIndicatorAligned(const JTC_M3_STATE &s,
                                    const JTC_M3_MACD_STRUCTURE &macd,
                                    const JTC_M3_MA22_STRUCTURE &ma22,
                                    const int side)
{
   const double atr=MathMax(_Point,M3AutoATR());

   // MACD is the leading momentum confirmation. Use signed movement rather
   // than absolute histogram expansion, because |hist| can expand in the
   // wrong direction.
   const bool macd_long=(macd.rising && s.hist>=s.hist_prev);
   const bool macd_short=(macd.falling && s.hist<=s.hist_prev);

   // MA22 remains contextual, not a hard price-side gate. The same context
   // used by the existing M3 reacceleration path is retained.
   const bool ma22_long=(s.close>s.ma22-atr*0.15 && (ma22.rising || s.close>=s.ma22));
   const bool ma22_short=(s.close<s.ma22+atr*0.15 && (ma22.falling || s.close<=s.ma22));

   // Delta supplies directional participation evidence. Both raw Delta and
   // its EMA trajectory are used so a single noisy bar is not treated as a
   // directional impulse by itself.
   const bool delta_long=(s.raw_delta>0.0 && s.delta_ema>=s.delta_ema_prev);
   const bool delta_short=(s.raw_delta<0.0 && s.delta_ema<=s.delta_ema_prev);

   // Volume is supporting acceleration evidence. Either expansion versus the
   // immediately prior bar or versus the existing rolling average is enough;
   // no arbitrary volume multiplier is introduced.
   const bool volume_expanding=(s.volume>s.volume_prev || s.volume_ratio>1.0);

   if(side>0)
      return macd_long && ma22_long && (delta_long || volume_expanding);
   if(side<0)
      return macd_short && ma22_short && (delta_short || volume_expanding);
   return false;
}


// v8.110: PRE-SIGNAL IS AN EVENT, NOT A PER-BAR MOMENTUM PULSE.
// The first qualifying price+MACD expansion can create a WATCH.  A same-
// direction WATCH is allowed again only after the market has actually formed
// a pullback and then broken the pre-pullback structural extreme with renewed
// MACD strengthening.  No timer/cooldown or arbitrary bar-count gate is used.
// v8.138: canonical visible/order acceleration detection.
// This is the single ACCEL source shared by chart, CSV and AUTO execution.
// The user wants a visible marker when a strong M3 directional move STARTS
// accelerating, including the first strong expansion of a live directional
// leg. It must not require a prior pullback/re-expansion event and must not
// publish only WATCH-owned later-bar canonical ACCEL through display_accel_side/time.
bool M3UpdateDisplayAcceleration(const JTC_M3_STATE &s,
                                  const int closed_index=1,
                                  const double prior_structure_high=0.0,
                                  const double prior_structure_low=0.0,
                                  const datetime prior_structure_high_time=0,
                                  const datetime prior_structure_low_time=0,
                                  const double prior_internal_high=0.0,
                                  const double prior_internal_low=0.0,
                                  const datetime prior_internal_high_time=0,
                                  const datetime prior_internal_low_time=0)
{
   // v8.242: reset CSV-only ACCEL audit for this completed M3 bar.
   g_m3_accel_audit_structure_high=0.0;
   g_m3_accel_audit_structure_low=0.0;
   g_m3_accel_audit_structure_high_source="NONE";
   g_m3_accel_audit_structure_low_source="NONE";
   g_m3_accel_audit_raw_long_break=false;
   g_m3_accel_audit_raw_short_break=false;
   g_m3_accel_audit_watch_owner_side=0;
   g_m3_accel_audit_watch_owner_time=0;
   g_m3_accel_audit_long_watch_authorized=false;
   g_m3_accel_audit_short_watch_authorized=false;
   g_m3_accel_audit_prior_long_accel_high=0.0;
   g_m3_accel_audit_prior_short_accel_low=0.0;
   g_m3_accel_audit_long_price_extension=false;
   g_m3_accel_audit_short_price_extension=false;
   g_m3_accel_audit_emit_long=false;
   g_m3_accel_audit_emit_short=false;
   g_m3_accel_audit_long_block_reason="";
   g_m3_accel_audit_short_block_reason="";

   // v8.120: structural-break + MACD-expansion event with strict MACD regime.
   //
   // ACCEL is the canonical acceleration event shared by chart/CSV/AUTO.
   // It remains independent from the WATCH/pre-signal calculation.
   //
   // Structure answers WHERE the expansion is occurring.
   // Price confirms that the structural break is real.
   // MACD answers WHETHER the break has entered directional expansion.
   //
   // A structural break is kept as a live pending event while price remains
   // beyond the broken level.  This is intentionally NOT a fixed bar window
   // or cooldown.  If MACD confirms on the break bar, the marker is immediate;
   // if MACD confirms on the next valid bar while the same break remains live,
   // the marker can still be produced.  If a new structural extreme replaces
   // the pending reference, the old pending event is discarded.
   g_m3_segment.display_accel_side=0;
   g_m3_segment.display_accel_time=0;
   // v8.256: chart permission for a canonical primary ACCEL is a one-bar pulse.
   g_m3_segment.chart_primary_accel_allowed=false;
   // v8.254 chart-only continuation event is also a one-bar pulse.
   g_m3_segment.chart_cont_accel_side=M3_SEG_NONE;
   g_m3_segment.chart_cont_accel_time=0;

   const int idx=closed_index;
   if(s.bar_time<=0 || idx<1 ||
      ArraySize(g_ms_rates)<idx+3 ||
      ArraySize(g_ms_macd_wave)<idx+3 ||
      ArraySize(g_ms_macd)<idx+3 ||
      ArraySize(g_ms_macd_direction)<idx+1)
   {
      g_m3_segment.display_accel_long_break_active=false;
      g_m3_segment.display_accel_short_break_active=false;
      g_m3_segment.display_accel_long_active=false;
      g_m3_segment.display_accel_short_active=false;
      return false;
   }

   const MqlRates prev=g_ms_rates[idx+1];

   // v8.153: use the newest already-confirmed structural reference. External
   // structure remains the major reference, while the faster confirmed internal
   // pivot can own the next expansion when it is newer. This moves ACCEL toward
   // the start of a real INITIAL/REEXPANSION without a timer, score or strength
   // filter and without deleting the external-structure path.
   double structure_high=prior_structure_high;
   double structure_low=prior_structure_low;
   if(prior_internal_high>0.0 && prior_internal_high_time>prior_structure_high_time)
      structure_high=prior_internal_high;
   if(prior_internal_low>0.0 && prior_internal_low_time>prior_structure_low_time)
      structure_low=prior_internal_low;

   const bool have_long_structure=(structure_high>0.0);
   const bool have_short_structure=(structure_low>0.0);

   const bool long_break=have_long_structure &&
                          s.close>structure_high &&
                          s.high>structure_high;
   const bool short_break=have_short_structure &&
                           s.close<structure_low &&
                           s.low<structure_low;

   g_m3_accel_audit_structure_high=structure_high;
   g_m3_accel_audit_structure_low=structure_low;
   if(structure_high>0.0)
      g_m3_accel_audit_structure_high_source=(prior_internal_high>0.0 && prior_internal_high_time>prior_structure_high_time) ? "INTERNAL" : "EXTERNAL";
   if(structure_low>0.0)
      g_m3_accel_audit_structure_low_source=(prior_internal_low>0.0 && prior_internal_low_time>prior_structure_low_time) ? "INTERNAL" : "EXTERNAL";
   g_m3_accel_audit_raw_long_break=long_break;
   g_m3_accel_audit_raw_short_break=short_break;

   // ------------------------- MACD trajectory -------------------------
   // Wave is the primary directional component. Histogram confirms the
   // expansion but is not required to accelerate on exactly the same candle.
   // Zero-line state is context, never a trigger.
   const double wave0=g_ms_macd_wave[idx];
   const double wave1=g_ms_macd_wave[idx+1];
   const double wave2=g_ms_macd_wave[idx+2];
   const double signal0=g_ms_macd[idx];
   const double signal1=g_ms_macd[idx+1];
   const double signal2=g_ms_macd[idx+2];

   const double hist0=wave0-signal0;
   const double hist1=wave1-signal1;
   const double hist2=wave2-signal2;

   const double wave_d1=wave0-wave1;
   const double wave_d2=wave1-wave2;
   const double hist_d1=hist0-hist1;
   const double hist_d2=hist1-hist2;
   const double macd_direction=g_ms_macd_direction[idx];

   // v8.120: zero-line regime is a strict context gate for ACCEL.
   // LONG acceleration must be confirmed in the positive MACD region; a
   // merely rising negative MACD is not enough. SHORT is symmetric.
   const bool long_zero_support=(wave0>0.0);
   const bool short_zero_support=(wave0<0.0);

   const bool long_wave_direction=(wave_d1>0.0);
   const bool short_wave_direction=(wave_d1<0.0);
   const bool long_direction=(macd_direction>0.5);
   const bool short_direction=(macd_direction<-0.5);

   // Expansion means the directional movement is strengthening OR is newly
   // leaving a non-directional/neutral state.  It does NOT require the second
   // derivative to increase on every candle.
   const bool long_wave_expansion=(wave_d1>0.0) &&
                                   ((wave_d1>wave_d2) || (wave1<=wave2));
   const bool short_wave_expansion=(wave_d1<0.0) &&
                                    ((wave_d1<wave_d2) || (wave1>=wave2));

   const bool long_hist_expansion=(hist_d1>0.0) &&
                                   ((hist_d1>hist_d2) || (hist1<=hist2));
   const bool short_hist_expansion=(hist_d1<0.0) &&
                                    ((hist_d1<hist_d2) || (hist1>=hist2));

   // Histogram alignment is deliberately soft.  A one-bar histogram pause
   // cannot cancel a clear Wave expansion.  The opposite-direction histogram
   // movement is tolerated only when Wave itself is the clear expansion leg.
   const bool long_hist_support=(hist0>=0.0 || hist_d1>=0.0);
   const bool short_hist_support=(hist0<=0.0 || hist_d1<=0.0);

   const bool long_macd_expand=long_zero_support &&
                                long_wave_direction &&
                                long_direction &&
                                long_hist_support &&
                                (long_wave_expansion || long_hist_expansion);

   const bool short_macd_expand=short_zero_support &&
                                 short_wave_direction &&
                                 short_direction &&
                                 short_hist_support &&
                                 (short_wave_expansion || short_hist_expansion);

   // Price drive is relative to the immediately preceding completed bar. No
   // absolute price/ATR threshold is introduced.
   const bool long_price_drive=(s.close>prev.close && s.high>=prev.high);
   const bool short_price_drive=(s.close<prev.close && s.low<=prev.low);

   // ------------------------- Pending structural break -------------------------
   // If an earlier pending reference is replaced by a newly confirmed
   // structural extreme, the earlier pending event is no longer the correct
   // event to wait on.  This prevents a late MACD pulse from producing an
   // ACCEL for an obsolete structure.
   if(g_m3_segment.display_accel_long_break_active &&
      structure_high>0.0 &&
      g_m3_segment.display_accel_long_break_level>0.0 &&
      MathAbs(structure_high-g_m3_segment.display_accel_long_break_level)>_Point)
   {
      g_m3_segment.display_accel_long_break_active=false;
      g_m3_segment.display_accel_long_break_level=0.0;
      g_m3_segment.display_accel_long_break_time=0;
   }

   if(g_m3_segment.display_accel_short_break_active &&
      structure_low>0.0 &&
      g_m3_segment.display_accel_short_break_level>0.0 &&
      MathAbs(structure_low-g_m3_segment.display_accel_short_break_level)>_Point)
   {
      g_m3_segment.display_accel_short_break_active=false;
      g_m3_segment.display_accel_short_break_level=0.0;
      g_m3_segment.display_accel_short_break_time=0;
   }

   // v8.242 backport of v8.237: preserve the FIRST pending break timestamp.
   if(long_break &&
      !g_m3_segment.display_accel_long_active &&
      !g_m3_segment.display_accel_long_break_active)
   {
      g_m3_segment.display_accel_long_break_active=true;
      g_m3_segment.display_accel_long_break_level=structure_high;
      g_m3_segment.display_accel_long_break_time=s.bar_time;
   }

   if(short_break &&
      !g_m3_segment.display_accel_short_active &&
      !g_m3_segment.display_accel_short_break_active)
   {
      g_m3_segment.display_accel_short_break_active=true;
      g_m3_segment.display_accel_short_break_level=structure_low;
      g_m3_segment.display_accel_short_break_time=s.bar_time;
   }

   // If the confirmed structural reference changes after an ACCEL was already
   // emitted, the old episode has completed structurally.  This is what allows
   // a genuinely new structure -> break -> MACD expansion to create a new
   // marker without using a time-based cooldown.
   if(g_m3_segment.display_accel_long_active &&
      structure_high>0.0 &&
      g_m3_segment.display_accel_long_break_level>0.0 &&
      MathAbs(structure_high-g_m3_segment.display_accel_long_break_level)>_Point)
   {
      g_m3_segment.display_accel_long_active=false;
      g_m3_segment.display_accel_long_break_level=0.0;
      g_m3_segment.display_accel_long_break_time=0;
   }

   if(g_m3_segment.display_accel_short_active &&
      structure_low>0.0 &&
      g_m3_segment.display_accel_short_break_level>0.0 &&
      MathAbs(structure_low-g_m3_segment.display_accel_short_break_level)>_Point)
   {
      g_m3_segment.display_accel_short_active=false;
      g_m3_segment.display_accel_short_break_level=0.0;
      g_m3_segment.display_accel_short_break_time=0;
   }

   // A pending break remains valid only while price remains beyond the broken
   // level. No timer is used. Returning through the level invalidates it.
   if(g_m3_segment.display_accel_long_break_active &&
      s.close<=g_m3_segment.display_accel_long_break_level)
   {
      g_m3_segment.display_accel_long_break_active=false;
      g_m3_segment.display_accel_long_break_level=0.0;
      g_m3_segment.display_accel_long_break_time=0;
   }

   if(g_m3_segment.display_accel_short_break_active &&
      s.close>=g_m3_segment.display_accel_short_break_level)
   {
      g_m3_segment.display_accel_short_break_active=false;
      g_m3_segment.display_accel_short_break_level=0.0;
      g_m3_segment.display_accel_short_break_time=0;
   }

   // Once an ACCEL has been emitted, the current structural expansion episode
   // is latched. A later new structural break can reset that episode when its
   // reference changes; no fixed cooldown is involved.
   if(g_m3_segment.display_accel_long_active &&
      (g_m3_segment.display_accel_long_break_level<=0.0 ||
       s.close<=g_m3_segment.display_accel_long_break_level))
   {
      g_m3_segment.display_accel_long_active=false;
   }
   if(g_m3_segment.display_accel_short_active &&
      (g_m3_segment.display_accel_short_break_level<=0.0 ||
       s.close>=g_m3_segment.display_accel_short_break_level))
   {
      g_m3_segment.display_accel_short_active=false;
   }

   const bool long_pending=g_m3_segment.display_accel_long_break_active;
   const bool short_pending=g_m3_segment.display_accel_short_break_active;

   // v8.256: separate raw market acceleration from canonical ACCEL publication.
   // Raw structural/price/MACD evidence is still calculated regardless of WATCH
   // ownership. Only a same-direction canonical WATCH on an EARLIER completed
   // bar may authorize display_accel_*/last_accel_event_* publication.
   const int accel_watch_owner_side=g_assist_accel_owner_side;
   const datetime accel_watch_owner_time=g_assist_accel_owner_watch_time;
   const bool long_watch_context=(accel_watch_owner_side==1 && accel_watch_owner_time>0 &&
                                  s.bar_time>accel_watch_owner_time);
   const bool short_watch_context=(accel_watch_owner_side==-1 && accel_watch_owner_time>0 &&
                                   s.bar_time>accel_watch_owner_time);
   const bool prior_long_accel=(g_m3_segment.last_accel_event_side==M3_SEG_LONG &&
                                g_m3_segment.last_accel_event_time>accel_watch_owner_time &&
                                g_m3_segment.last_accel_event_high>0.0);
   const bool prior_short_accel=(g_m3_segment.last_accel_event_side==M3_SEG_SHORT &&
                                 g_m3_segment.last_accel_event_time>accel_watch_owner_time &&
                                 g_m3_segment.last_accel_event_low>0.0);
   const bool long_price_extension=(!prior_long_accel || s.close>g_m3_segment.last_accel_event_high);
   const bool short_price_extension=(!prior_short_accel || s.close<g_m3_segment.last_accel_event_low);

   const bool raw_emit_long=long_pending &&
                             !g_m3_segment.display_accel_long_active &&
                             long_price_drive && long_macd_expand;
   const bool raw_emit_short=short_pending &&
                              !g_m3_segment.display_accel_short_active &&
                              short_price_drive && short_macd_expand;

   const bool emit_long=(raw_emit_long && long_price_extension && long_watch_context);
   const bool emit_short=(raw_emit_short && short_price_extension && short_watch_context);

   g_m3_accel_audit_watch_owner_side=accel_watch_owner_side;
   g_m3_accel_audit_watch_owner_time=accel_watch_owner_time;
   g_m3_accel_audit_long_watch_authorized=long_watch_context;
   g_m3_accel_audit_short_watch_authorized=short_watch_context;
   g_m3_accel_audit_prior_long_accel_high=prior_long_accel ? g_m3_segment.last_accel_event_high : 0.0;
   g_m3_accel_audit_prior_short_accel_low=prior_short_accel ? g_m3_segment.last_accel_event_low : 0.0;
   g_m3_accel_audit_long_price_extension=long_price_extension;
   g_m3_accel_audit_short_price_extension=short_price_extension;
   // Keep audit_emit_* as RAW readiness diagnostics; block reason identifies
   // whether that raw evidence became a canonical WATCH-owned ACCEL.
   g_m3_accel_audit_emit_long=raw_emit_long;
   g_m3_accel_audit_emit_short=raw_emit_short;

   if(emit_long) g_m3_accel_audit_long_block_reason="CANONICAL_EMIT";
   else if(raw_emit_long && long_watch_context && !long_price_extension) g_m3_accel_audit_long_block_reason="NO_CLOSE_BEYOND_PRIOR_ACCEL_HIGH";
   else if(raw_emit_long && accel_watch_owner_side!=1) g_m3_accel_audit_long_block_reason="RAW_READY_NO_LONG_WATCH_OWNER";
   else if(raw_emit_long && accel_watch_owner_time>0 && s.bar_time<=accel_watch_owner_time) g_m3_accel_audit_long_block_reason="RAW_READY_SAME_BAR_WATCH";
   else if(!have_long_structure) g_m3_accel_audit_long_block_reason="NO_STRUCTURE";
   else if(!long_pending) g_m3_accel_audit_long_block_reason="NO_PENDING_BREAK";
   else if(g_m3_segment.display_accel_long_active) g_m3_accel_audit_long_block_reason="ACTIVE_LATCH";
   else if(!long_price_drive) g_m3_accel_audit_long_block_reason="NO_PRICE_DRIVE";
   else if(!long_macd_expand) g_m3_accel_audit_long_block_reason="NO_MACD_EXPAND";
   else g_m3_accel_audit_long_block_reason="OTHER";

   if(emit_short) g_m3_accel_audit_short_block_reason="CANONICAL_EMIT";
   else if(raw_emit_short && short_watch_context && !short_price_extension) g_m3_accel_audit_short_block_reason="NO_CLOSE_BELOW_PRIOR_ACCEL_LOW";
   else if(raw_emit_short && accel_watch_owner_side!=-1) g_m3_accel_audit_short_block_reason="RAW_READY_NO_SHORT_WATCH_OWNER";
   else if(raw_emit_short && accel_watch_owner_time>0 && s.bar_time<=accel_watch_owner_time) g_m3_accel_audit_short_block_reason="RAW_READY_SAME_BAR_WATCH";
   else if(!have_short_structure) g_m3_accel_audit_short_block_reason="NO_STRUCTURE";
   else if(!short_pending) g_m3_accel_audit_short_block_reason="NO_PENDING_BREAK";
   else if(g_m3_segment.display_accel_short_active) g_m3_accel_audit_short_block_reason="ACTIVE_LATCH";
   else if(!short_price_drive) g_m3_accel_audit_short_block_reason="NO_PRICE_DRIVE";
   else if(!short_macd_expand) g_m3_accel_audit_short_block_reason="NO_MACD_EXPAND";
   else g_m3_accel_audit_short_block_reason="OTHER";

   // v8.256: one visual ACCEL budget belongs to one canonical WATCH owner.
   // A new/opposite canonical WATCH resets the visible count to zero.
   if(g_m3_segment.chart_cont_accel_owner_side!=accel_watch_owner_side ||
      g_m3_segment.chart_cont_accel_owner_time!=accel_watch_owner_time)
   {
      g_m3_segment.chart_cont_accel_owner_side=accel_watch_owner_side;
      g_m3_segment.chart_cont_accel_owner_time=accel_watch_owner_time;
      g_m3_segment.chart_cont_accel_long_armed=false;
      g_m3_segment.chart_cont_accel_short_armed=false;
      g_m3_segment.chart_cont_accel_ref_high=0.0;
      g_m3_segment.chart_cont_accel_ref_low=0.0;
      g_m3_segment.chart_accel_publish_count=0;
   }

   if(emit_long)
   {
      g_assist_accel_owner_confirmed=true;
      g_m3_segment.display_accel_long_active=true;
      g_m3_segment.display_accel_long_break_active=false;
      g_m3_segment.display_accel_side=M3_SEG_LONG;
      g_m3_segment.display_accel_time=s.bar_time;
      g_m3_segment.last_accel_event_side=M3_SEG_LONG;
      g_m3_segment.last_accel_event_time=s.bar_time;
      g_m3_segment.last_accel_event_high=s.high;
      g_m3_segment.last_accel_event_low=s.low;
      if(g_m3_segment.chart_accel_publish_count<5)
      {
         g_m3_segment.chart_accel_publish_count++;
         g_m3_segment.chart_primary_accel_allowed=true;
      }
   }

   if(emit_short)
   {
      g_assist_accel_owner_confirmed=true;
      g_m3_segment.display_accel_short_active=true;
      g_m3_segment.display_accel_short_break_active=false;
      g_m3_segment.display_accel_side=M3_SEG_SHORT;
      g_m3_segment.display_accel_time=s.bar_time;
      g_m3_segment.last_accel_event_side=M3_SEG_SHORT;
      g_m3_segment.last_accel_event_time=s.bar_time;
      g_m3_segment.last_accel_event_high=s.high;
      g_m3_segment.last_accel_event_low=s.low;
      if(g_m3_segment.chart_accel_publish_count<5)
      {
         g_m3_segment.chart_accel_publish_count++;
         g_m3_segment.chart_primary_accel_allowed=true;
      }
   }

   // ---------------- chart-only same-episode continuation ACCEL ----------------
   // v8.254: after a canonical same-direction WATCH has already owned a real
   // ACCEL, allow the chart to show renewed acceleration inside the same WATCH
   // episode without requiring a newly confirmed structural pivot.
   //
   // Publication rule (no arbitrary timer/point threshold):
   //   1) same canonical WATCH owner remains in force,
   //   2) a real ACCEL occurred after that WATCH,
   //   3) price-drive or MACD-expansion weakened at least once,
   //   4) both price-drive and MACD-expansion become valid again, and
   //   5) the completed-bar close extends beyond the previous chart ACCEL reference extreme.
   //
   // IMPORTANT: this pulse is CHART ONLY. It never writes display_accel_* or
   // last_accel_event_*, so M3AutoEngine, REARM confirmation and alerts cannot
   // interpret it as an order-authorized ACCEL. DIRECTION keeps ADD ownership.
   const bool owned_real_long_accel=(accel_watch_owner_side==1 && accel_watch_owner_time>0 &&
                                     g_m3_segment.last_accel_event_side==M3_SEG_LONG &&
                                     g_m3_segment.last_accel_event_time>accel_watch_owner_time);
   const bool owned_real_short_accel=(accel_watch_owner_side==-1 && accel_watch_owner_time>0 &&
                                      g_m3_segment.last_accel_event_side==M3_SEG_SHORT &&
                                      g_m3_segment.last_accel_event_time>accel_watch_owner_time);

   // A newly published real ACCEL becomes the continuation reference.
   if(emit_long && accel_watch_owner_side==1 && accel_watch_owner_time>0 &&
      s.bar_time>accel_watch_owner_time)
   {
      g_m3_segment.chart_cont_accel_ref_high=s.high;
      g_m3_segment.chart_cont_accel_ref_low=s.low;
      g_m3_segment.chart_cont_accel_long_armed=false;
      g_m3_segment.chart_cont_accel_short_armed=false;
   }
   else if(emit_short && accel_watch_owner_side==-1 && accel_watch_owner_time>0 &&
           s.bar_time>accel_watch_owner_time)
   {
      g_m3_segment.chart_cont_accel_ref_high=s.high;
      g_m3_segment.chart_cont_accel_ref_low=s.low;
      g_m3_segment.chart_cont_accel_short_armed=false;
      g_m3_segment.chart_cont_accel_long_armed=false;
   }
   else
   {
      if(owned_real_long_accel)
      {
         if(g_m3_segment.chart_cont_accel_ref_high<=0.0)
         {
            g_m3_segment.chart_cont_accel_ref_high=g_m3_segment.last_accel_event_high;
            g_m3_segment.chart_cont_accel_ref_low=g_m3_segment.last_accel_event_low;
         }

         if(!long_price_drive || !long_macd_expand)
            g_m3_segment.chart_cont_accel_long_armed=true;

         if(g_m3_segment.chart_cont_accel_long_armed &&
            long_price_drive && long_macd_expand &&
            g_m3_segment.chart_cont_accel_ref_high>0.0 &&
            s.close>g_m3_segment.chart_cont_accel_ref_high)
         {
            if(g_m3_segment.chart_accel_publish_count<5)
            {
               g_m3_segment.chart_cont_accel_side=M3_SEG_LONG;
               g_m3_segment.chart_cont_accel_time=s.bar_time;
               g_m3_segment.chart_accel_publish_count++;
            }
            g_m3_segment.chart_cont_accel_ref_high=s.high;
            g_m3_segment.chart_cont_accel_ref_low=s.low;
            g_m3_segment.chart_cont_accel_long_armed=false;
         }
      }
      else if(owned_real_short_accel)
      {
         if(g_m3_segment.chart_cont_accel_ref_low<=0.0)
         {
            g_m3_segment.chart_cont_accel_ref_high=g_m3_segment.last_accel_event_high;
            g_m3_segment.chart_cont_accel_ref_low=g_m3_segment.last_accel_event_low;
         }

         if(!short_price_drive || !short_macd_expand)
            g_m3_segment.chart_cont_accel_short_armed=true;

         if(g_m3_segment.chart_cont_accel_short_armed &&
            short_price_drive && short_macd_expand &&
            g_m3_segment.chart_cont_accel_ref_low>0.0 &&
            s.close<g_m3_segment.chart_cont_accel_ref_low)
         {
            if(g_m3_segment.chart_accel_publish_count<5)
            {
               g_m3_segment.chart_cont_accel_side=M3_SEG_SHORT;
               g_m3_segment.chart_cont_accel_time=s.bar_time;
               g_m3_segment.chart_accel_publish_count++;
            }
            g_m3_segment.chart_cont_accel_ref_high=s.high;
            g_m3_segment.chart_cont_accel_ref_low=s.low;
            g_m3_segment.chart_cont_accel_short_armed=false;
         }
      }
   }

   if(emit_long && !emit_short)
      return true;
   if(emit_short && !emit_long)
      return true;
   if(emit_long && emit_short)
   {
      if(long_macd_expand && !short_macd_expand)
         g_m3_segment.display_accel_side=M3_SEG_LONG;
      else if(short_macd_expand && !long_macd_expand)
         g_m3_segment.display_accel_side=M3_SEG_SHORT;
      else
         g_m3_segment.display_accel_side=(s.close>=prev.close ? M3_SEG_LONG : M3_SEG_SHORT);
      g_m3_segment.display_accel_time=s.bar_time;
      g_m3_segment.last_accel_event_side=g_m3_segment.display_accel_side;
      g_m3_segment.last_accel_event_time=s.bar_time;
      g_m3_segment.last_accel_event_high=s.high;
      g_m3_segment.last_accel_event_low=s.low;
      return true;
   }

   return false;
}


// v8.253 cleanup: retired the duplicate M3Segment WATCH/PRE-ZERO state machine.
// StateEvaluation is the sole canonical WATCH owner; M3Segment retains structure and ACCEL only.
double M3Clamp01(const double v)
{
   return MathMax(0.0,MathMin(1.0,v));
}

bool M3UpdateAdaptiveSwingStructure(const JTC_M3_STATE &s,const int direction,const int closed_index=1)
{
   // Two structural speeds are maintained from the same completed M3 series:
   // external pivots use a 2/2 confirmation window; internal pivots use a
   // faster 1/1 window. No fixed number of directional candles is counted.
   if(ArraySize(g_ms_rates)<closed_index+6)
      return false;

   const datetime bar=s.bar_time;
   if(bar==g_m3_structure_last_bar)
   {
      g_m3_segment.external_bullish=(g_m3_ext_hh && g_m3_ext_hl);
      g_m3_segment.external_bearish=(g_m3_ext_lh && g_m3_ext_ll);
      g_m3_segment.internal_bullish=(g_m3_int_hh || g_m3_int_hl);
      g_m3_segment.internal_bearish=(g_m3_int_lh || g_m3_int_ll);
      return g_m3_segment.external_bullish || g_m3_segment.external_bearish;
   }
   g_m3_structure_last_bar=bar;
   // v8.152: fresh producer event set for this completed bar.
   g_m3_new_ext_high=false; g_m3_new_ext_low=false;
   g_m3_new_int_high=false; g_m3_new_int_low=false;

   // External pivot: 2 completed bars on each side of the candidate.
   const int ec=closed_index+2;
   const double eph=g_ms_rates[ec].high;
   const double epl=g_ms_rates[ec].low;
   const bool ext_high=(eph>g_ms_rates[ec-1].high && eph>g_ms_rates[ec-2].high &&
                        eph>=g_ms_rates[ec+1].high && eph>=g_ms_rates[ec+2].high);
   const bool ext_low=(epl<g_ms_rates[ec-1].low && epl<g_ms_rates[ec-2].low &&
                       epl<=g_ms_rates[ec+1].low && epl<=g_ms_rates[ec+2].low);

   if(ext_high)
   {
      g_m3_new_ext_high=true;
      g_m3_ext_prev_high=g_m3_ext_last_high;
      g_m3_ext_prev_high_time=g_m3_ext_last_high_time;
      g_m3_ext_last_high=eph;
      g_m3_ext_last_high_time=g_ms_rates[ec].time;
      if(g_m3_ext_prev_high>0.0)
      {
         g_m3_ext_hh=(g_m3_ext_last_high>g_m3_ext_prev_high);
         g_m3_ext_lh=(g_m3_ext_last_high<g_m3_ext_prev_high);
      }
   }
   if(ext_low)
   {
      g_m3_new_ext_low=true;
      g_m3_ext_prev_low=g_m3_ext_last_low;
      g_m3_ext_prev_low_time=g_m3_ext_last_low_time;
      g_m3_ext_last_low=epl;
      g_m3_ext_last_low_time=g_ms_rates[ec].time;
      if(g_m3_ext_prev_low>0.0)
      {
         g_m3_ext_hl=(g_m3_ext_last_low>g_m3_ext_prev_low);
         g_m3_ext_ll=(g_m3_ext_last_low<g_m3_ext_prev_low);
      }
   }

   // Internal pivot: faster 1/1 confirmation around the more recent bar.
   const int ic=closed_index+1;
   const double iph=g_ms_rates[ic].high;
   const double ipl=g_ms_rates[ic].low;
   const bool int_high=(iph>g_ms_rates[ic-1].high && iph>=g_ms_rates[ic+1].high);
   const bool int_low=(ipl<g_ms_rates[ic-1].low && ipl<=g_ms_rates[ic+1].low);

   if(int_high)
   {
      g_m3_new_int_high=true;
      g_m3_int_prev_high=g_m3_int_last_high;
      g_m3_int_prev_high_time=g_m3_int_last_high_time;
      g_m3_int_last_high=iph;
      g_m3_int_last_high_time=g_ms_rates[ic].time;
      if(g_m3_int_prev_high>0.0)
      {
         g_m3_int_hh=(g_m3_int_last_high>g_m3_int_prev_high);
         g_m3_int_lh=(g_m3_int_last_high<g_m3_int_prev_high);
      }
   }
   if(int_low)
   {
      g_m3_new_int_low=true;
      g_m3_int_prev_low=g_m3_int_last_low;
      g_m3_int_prev_low_time=g_m3_int_last_low_time;
      g_m3_int_last_low=ipl;
      g_m3_int_last_low_time=g_ms_rates[ic].time;
      if(g_m3_int_prev_low>0.0)
      {
         g_m3_int_hl=(g_m3_int_last_low>g_m3_int_prev_low);
         g_m3_int_ll=(g_m3_int_last_low<g_m3_int_prev_low);
      }
   }

   g_m3_segment.external_bullish=(g_m3_ext_hh && g_m3_ext_hl);
   g_m3_segment.external_bearish=(g_m3_ext_lh && g_m3_ext_ll);
   g_m3_segment.internal_bullish=(g_m3_int_hh || g_m3_int_hl);
   g_m3_segment.internal_bearish=(g_m3_int_lh || g_m3_int_ll);

   // Compatibility mirrors for the existing protection/recovery code.
   g_m3_segment.prev_swing_high=g_m3_ext_prev_high;
   g_m3_segment.last_swing_high=g_m3_ext_last_high;
   g_m3_segment.prev_swing_low=g_m3_ext_prev_low;
   g_m3_segment.last_swing_low=g_m3_ext_last_low;
   g_m3_segment.higher_high=g_m3_ext_hh;
   g_m3_segment.higher_low=g_m3_ext_hl;
   g_m3_segment.lower_high=g_m3_ext_lh;
   g_m3_segment.lower_low=g_m3_ext_ll;

   g_m3_segment.structure_established=
      (g_m3_segment.external_bullish || g_m3_segment.external_bearish);
   return g_m3_segment.structure_established;
}

bool M3LongEntryLocationOK(const JTC_M3_STATE &s)
{
   const double atr=MathMax(_Point,M3AutoATR());
   const double reference=(g_m3_segment.setup_low>0.0 ? g_m3_segment.setup_low :
                           (g_m3_segment.internal_trigger_high>0.0 ? g_m3_segment.internal_trigger_high : s.ma22));
   const double extension=MathMax(0.0,s.close-reference)/atr;
   return extension<=1.25 && s.close>=s.ma22-atr*0.15;
}

bool M3ShortEntryLocationOK(const JTC_M3_STATE &s)
{
   const double atr=MathMax(_Point,M3AutoATR());
   const double reference=(g_m3_segment.setup_high>0.0 ? g_m3_segment.setup_high :
                           (g_m3_segment.internal_trigger_low>0.0 ? g_m3_segment.internal_trigger_low : s.ma22));
   const double extension=MathMax(0.0,reference-s.close)/atr;
   return extension<=1.25 && s.close<=s.ma22+atr*0.15;
}

bool M3InternalLongStructureReady(const datetime since_time=0)
{
   if(g_m3_int_last_high<=0.0 || g_m3_int_last_low<=0.0 ||
      g_m3_int_last_high_time<=0 || g_m3_int_last_low_time<=0)
      return false;
   if(since_time>0 &&
      (g_m3_int_last_high_time<=since_time || g_m3_int_last_low_time<=since_time))
      return false;
   return g_m3_int_hh && g_m3_int_hl;
}

bool M3InternalShortStructureReady(const datetime since_time=0)
{
   if(g_m3_int_last_high<=0.0 || g_m3_int_last_low<=0.0 ||
      g_m3_int_last_high_time<=0 || g_m3_int_last_low_time<=0)
      return false;
   if(since_time>0 &&
      (g_m3_int_last_high_time<=since_time || g_m3_int_last_low_time<=since_time))
      return false;
   return g_m3_int_lh && g_m3_int_ll;
}

bool M3CreateInternalStructureEpisode(const JTC_M3_STATE &s,const int side,const datetime since_time=0)
{
   if(side>0 && !M3InternalLongStructureReady(since_time)) return false;
   if(side<0 && !M3InternalShortStructureReady(since_time)) return false;
   g_m3_segment.structure_episode=true;
   g_m3_segment.structure_valid=true;
   g_m3_segment.structure_break=false;
   g_m3_segment.episode_state=M3_EP_STRUCTURE_FORMED;
   g_m3_segment.phase=M3_PHASE_ACTIVE;
   g_m3_segment.regime=JTC_M3_REGIME_TREND;
   g_m3_segment.persistence_confirmed=false;
   if(side>0)
   {
      g_m3_segment.structure_high=g_m3_int_last_high;
      g_m3_segment.structure_high_time=g_m3_int_last_high_time;
      g_m3_segment.structure_low=g_m3_int_last_low;
      g_m3_segment.structure_low_time=g_m3_int_last_low_time;
      g_m3_segment.protected_swing_low=g_m3_int_last_low;
      g_m3_segment.have_protected_low=true;
   }
   else
   {
      g_m3_segment.structure_low=g_m3_int_last_low;
      g_m3_segment.structure_low_time=g_m3_int_last_low_time;
      g_m3_segment.structure_high=g_m3_int_last_high;
      g_m3_segment.structure_high_time=g_m3_int_last_high_time;
      g_m3_segment.protected_swing_high=g_m3_int_last_high;
      g_m3_segment.have_protected_high=true;
   }
   return true;
}

bool M3LongStructuralBias(const JTC_M3_STATE &s,const JTC_M3_MACD_STRUCTURE &macd,const JTC_M3_MA22_STRUCTURE &ma22)
{
   // Price structure owns direction. External 2/2 pivots are slower context;
   // the confirmed 1/1 M3 sequence is the live structural basis.
   return g_m3_segment.external_bullish || M3InternalLongStructureReady();
}

bool M3ShortStructuralBias(const JTC_M3_STATE &s,const JTC_M3_MACD_STRUCTURE &macd,const JTC_M3_MA22_STRUCTURE &ma22)
{
   return g_m3_segment.external_bearish || M3InternalShortStructureReady();
}

bool M3LongSetupReady(const JTC_M3_STATE &s,const JTC_M3_MACD_STRUCTURE &macd,const JTC_M3_MA22_STRUCTURE &ma22)
{
   // Setup is a stored episode state. Current-bar proximity to MA22 or an
   // isolated candle cannot create a setup.
   return g_m3_segment.direction==M3_SEG_LONG &&
          g_m3_segment.regime==JTC_M3_REGIME_TREND &&
          g_m3_segment.structure_episode &&
          g_m3_segment.pullback_episode &&
          g_m3_segment.pullback_reference_set &&
          g_m3_segment.pullback_held &&
          (g_m3_segment.episode_state==M3_EP_PULLBACK_HELD ||
           g_m3_segment.episode_state==M3_EP_REACCELERATION ||
           g_m3_segment.episode_state==M3_EP_TRIGGER) &&
          !g_m3_segment.structure_break;
}

bool M3ShortSetupReady(const JTC_M3_STATE &s,const JTC_M3_MACD_STRUCTURE &macd,const JTC_M3_MA22_STRUCTURE &ma22)
{
   return g_m3_segment.direction==M3_SEG_SHORT &&
          g_m3_segment.regime==JTC_M3_REGIME_TREND &&
          g_m3_segment.structure_episode &&
          g_m3_segment.pullback_episode &&
          g_m3_segment.pullback_reference_set &&
          g_m3_segment.pullback_held &&
          (g_m3_segment.episode_state==M3_EP_PULLBACK_HELD ||
           g_m3_segment.episode_state==M3_EP_REACCELERATION ||
           g_m3_segment.episode_state==M3_EP_TRIGGER) &&
          !g_m3_segment.structure_break;
}

bool M3LongTrigger(const JTC_M3_STATE &s,const JTC_M3_MACD_STRUCTURE &macd,const JTC_M3_MA22_STRUCTURE &ma22)
{
   if(!M3LongSetupReady(s,macd,ma22) || !g_m3_segment.reacceleration_episode)
      return false;
   return g_m3_segment.pullback_reference>0.0 &&
          s.close>g_m3_segment.pullback_reference &&
          g_m3_segment.trigger_time==s.bar_time;
}

bool M3ShortTrigger(const JTC_M3_STATE &s,const JTC_M3_MACD_STRUCTURE &macd,const JTC_M3_MA22_STRUCTURE &ma22)
{
   if(!M3ShortSetupReady(s,macd,ma22) || !g_m3_segment.reacceleration_episode)
      return false;
   return g_m3_segment.pullback_reference>0.0 &&
          s.close<g_m3_segment.pullback_reference &&
          g_m3_segment.trigger_time==s.bar_time;
}

bool M3LongStructureBroken(const JTC_M3_STATE &s)
{
   if(!g_m3_segment.have_protected_low || g_m3_segment.protected_swing_low<=0.0)
      return false;
   // Protected HL is the owner of LONG structure. A confirmed closed-bar
   // close below that anchor invalidates the episode; a wick/pivot alone does not.
   return s.close < g_m3_segment.protected_swing_low;
}

bool M3ShortStructureBroken(const JTC_M3_STATE &s)
{
   if(!g_m3_segment.have_protected_high || g_m3_segment.protected_swing_high<=0.0)
      return false;
   // Protected LH is the owner of SHORT structure. A confirmed closed-bar
   // close above that anchor invalidates the episode; a wick/pivot alone does not.
   return s.close > g_m3_segment.protected_swing_high;
}

bool M3LongFailureConfirmed(const JTC_M3_STATE &s,const JTC_M3_MACD_STRUCTURE &macd,const JTC_M3_MA22_STRUCTURE &ma22)
{
   // Structural failure is owned by price structure. MACD/MA22 are descriptive
   // state inputs and must never delay the structural exit decision.
   return M3LongStructureBroken(s);
}

bool M3ShortFailureConfirmed(const JTC_M3_STATE &s,const JTC_M3_MACD_STRUCTURE &macd,const JTC_M3_MA22_STRUCTURE &ma22)
{
   return M3ShortStructureBroken(s);
}

bool M3LongStructureWeakening(const JTC_M3_STATE &s,const JTC_M3_MACD_STRUCTURE &macd,const JTC_M3_MA22_STRUCTURE &ma22)
{
   if(M3LongStructureBroken(s)) return true;
   const double atr=MathMax(_Point,M3AutoATR());
   const double reference=(g_m3_segment.have_protected_low ? g_m3_segment.protected_swing_low : (g_m3_segment.entry_anchor_price>0.0 ? g_m3_segment.entry_anchor_price : g_m3_segment.start_price));
   const double distance=s.close-reference;
   return distance>=0.0 && distance<=atr*0.20 && (macd.contracting || macd.falling || ma22.flattening);
}

bool M3ShortStructureWeakening(const JTC_M3_STATE &s,const JTC_M3_MACD_STRUCTURE &macd,const JTC_M3_MA22_STRUCTURE &ma22)
{
   if(M3ShortStructureBroken(s)) return true;
   const double atr=MathMax(_Point,M3AutoATR());
   const double reference=(g_m3_segment.have_protected_high ? g_m3_segment.protected_swing_high : (g_m3_segment.entry_anchor_price>0.0 ? g_m3_segment.entry_anchor_price : g_m3_segment.start_price));
   const double distance=reference-s.close;
   return distance>=0.0 && distance<=atr*0.20 && (macd.contracting || macd.rising || ma22.flattening);
}

bool M3LongStructureRecovered(const JTC_M3_STATE &s,const JTC_M3_MACD_STRUCTURE &macd,const JTC_M3_MA22_STRUCTURE &ma22)
{
   if(!g_m3_segment.have_protected_low || g_m3_segment.protected_swing_low<=0.0) return false;
   const bool new_hl=(g_m3_segment.have_swing_low && g_m3_segment.last_swing_low>g_m3_segment.protected_swing_low);
   const bool new_hh=(g_m3_segment.have_swing_high && g_m3_segment.higher_high);
   return new_hl && new_hh && s.close>g_m3_segment.protected_swing_low &&
          ma22.price_above && ma22.rising && (macd.above_signal || macd.rising);
}

bool M3ShortStructureRecovered(const JTC_M3_STATE &s,const JTC_M3_MACD_STRUCTURE &macd,const JTC_M3_MA22_STRUCTURE &ma22)
{
   if(!g_m3_segment.have_protected_high || g_m3_segment.protected_swing_high<=0.0) return false;
   const bool new_lh=(g_m3_segment.have_swing_high && g_m3_segment.last_swing_high<g_m3_segment.protected_swing_high);
   const bool new_ll=(g_m3_segment.have_swing_low && g_m3_segment.lower_low);
   return new_lh && new_ll && s.close<g_m3_segment.protected_swing_high &&
          ma22.price_below && ma22.falling && (macd.below_signal || macd.falling);
}

bool M3LongInvalidated(const JTC_M3_STATE &s,const JTC_M3_MACD_STRUCTURE &macd,const JTC_M3_MA22_STRUCTURE &ma22)
{
   return M3LongFailureConfirmed(s,macd,ma22);
}

bool M3ShortInvalidated(const JTC_M3_STATE &s,const JTC_M3_MACD_STRUCTURE &macd,const JTC_M3_MA22_STRUCTURE &ma22)
{
   return M3ShortFailureConfirmed(s,macd,ma22);
}

bool M3LongNormalPullback(const JTC_M3_STATE &s,const JTC_M3_MACD_STRUCTURE &macd,const JTC_M3_MA22_STRUCTURE &ma22)
{
   const double atr=MathMax(_Point,M3AutoATR());
   return M3LongStructuralBias(s,macd,ma22) &&
          ((g_m3_int_last_low>0.0 && s.low<=g_m3_int_last_low+atr*0.10) ||
           (s.low<=s.ma22+atr*0.10 && s.close>=s.ma22-atr*0.15)) &&
          !M3LongTrigger(s,macd,ma22);
}

bool M3ShortNormalPullback(const JTC_M3_STATE &s,const JTC_M3_MACD_STRUCTURE &macd,const JTC_M3_MA22_STRUCTURE &ma22)
{
   const double atr=MathMax(_Point,M3AutoATR());
   return M3ShortStructuralBias(s,macd,ma22) &&
          ((g_m3_int_last_high>0.0 && s.high>=g_m3_int_last_high-atr*0.10) ||
           (s.high>=s.ma22-atr*0.10 && s.close<=s.ma22+atr*0.15)) &&
          !M3ShortTrigger(s,macd,ma22);
}

bool M3LongReaccel(const JTC_M3_STATE &s,const JTC_M3_MACD_STRUCTURE &macd,const JTC_M3_MA22_STRUCTURE &ma22)
{
   return g_m3_segment.direction==M3_SEG_LONG &&
          g_m3_segment.internal_pullback &&
          M3LongTrigger(s,macd,ma22);
}

bool M3ShortReaccel(const JTC_M3_STATE &s,const JTC_M3_MACD_STRUCTURE &macd,const JTC_M3_MA22_STRUCTURE &ma22)
{
   return g_m3_segment.direction==M3_SEG_SHORT &&
          g_m3_segment.internal_pullback &&
          M3ShortTrigger(s,macd,ma22);
}

bool M3LongExhaustion(const JTC_M3_STATE &s,const JTC_M3_MACD_STRUCTURE &macd,const JTC_M3_MA22_STRUCTURE &ma22)
{
   const double atr=MathMax(_Point,M3AutoATR());
   const double extension=MathMax(0.0,s.close-s.ma22);
   const bool extended=extension>atr*MathMax(1.50,InpShortTermMaxEntryATR);
   const bool participation_fading=(s.raw_delta<=s.raw_delta_prev && s.volume<=s.volume_prev);
   return ma22.price_above && macd.above_zero && extended && macd.contracting && participation_fading;
}

bool M3ShortExhaustion(const JTC_M3_STATE &s,const JTC_M3_MACD_STRUCTURE &macd,const JTC_M3_MA22_STRUCTURE &ma22)
{
   const double atr=MathMax(_Point,M3AutoATR());
   const double extension=MathMax(0.0,s.ma22-s.close);
   const bool extended=extension>atr*MathMax(1.50,InpShortTermMaxEntryATR);
   const bool participation_fading=(s.raw_delta>=s.raw_delta_prev && s.volume<=s.volume_prev);
   return ma22.price_below && macd.below_zero && extended && macd.contracting && participation_fading;
}

void M3CreateSegment(const int direction,const JTC_M3_STATE &s)
{
   g_m3_segment_sequence++;
   g_m3_segment.id=g_m3_segment_sequence;
   g_m3_segment.direction=direction;
   g_m3_segment.phase=M3_PHASE_BUILD;
   g_m3_segment.last_close=s.close;
   g_m3_segment.prev_swing_high=0.0;
   g_m3_segment.last_swing_high=0.0;
   g_m3_segment.prev_swing_low=0.0;
   g_m3_segment.last_swing_low=0.0;
   g_m3_segment.protected_swing_low=0.0;
   g_m3_segment.protected_swing_high=0.0;
   g_m3_segment.have_protected_low=false;
   g_m3_segment.have_protected_high=false;
   g_m3_segment.recovery_ready=false;
   g_m3_segment.have_swing_high=false;
   g_m3_segment.have_swing_low=false;
   g_m3_segment.higher_high=false;
   g_m3_segment.higher_low=false;
   g_m3_segment.lower_high=false;
   g_m3_segment.lower_low=false;
   g_m3_segment.structure_break=false;
   g_m3_segment.pullback_held=false;
   g_m3_segment.structure_established=false;
   g_m3_segment.regime=(direction==M3_SEG_RANGE ? JTC_M3_REGIME_RANGE : JTC_M3_REGIME_TRANSITION);
   g_m3_segment.structure_state=JTC_M3_POS_RUN;
   g_m3_segment.entry_anchor_price=s.close;
   g_m3_segment.entry_anchor_time=s.bar_time;
   g_m3_segment.external_bullish=(g_m3_ext_hh && g_m3_ext_hl);
   g_m3_segment.external_bearish=(g_m3_ext_lh && g_m3_ext_ll);
   g_m3_segment.internal_bullish=(g_m3_int_hh || g_m3_int_hl);
   g_m3_segment.internal_bearish=(g_m3_int_lh || g_m3_int_ll);
   g_m3_segment.internal_pullback=false;
   g_m3_segment.internal_reaccel=false;
   g_m3_segment.setup_long=false;
   g_m3_segment.setup_short=false;
   g_m3_segment.trigger_long=false;
   g_m3_segment.trigger_short=false;
   g_m3_segment.internal_trigger_high=g_m3_int_last_high;
   g_m3_segment.internal_trigger_low=g_m3_int_last_low;
   if(direction==M3_SEG_LONG && g_m3_ext_hl && g_m3_ext_last_low>0.0)
   {
      g_m3_segment.protected_swing_low=g_m3_ext_last_low;
      g_m3_segment.have_protected_low=true;
   }
   if(direction==M3_SEG_SHORT && g_m3_ext_lh && g_m3_ext_last_high>0.0)
   {
      g_m3_segment.protected_swing_high=g_m3_ext_last_high;
      g_m3_segment.have_protected_high=true;
   }
   g_m3_segment.setup_low=0.0;
   g_m3_segment.setup_high=0.0;
   g_m3_segment.structure_high_time=0;
   g_m3_segment.structure_low_time=0;
   g_m3_segment.pullback_start_time=0;
   g_m3_segment.pullback_reference_time=0;
   g_m3_segment.reaccel_time=0;
   g_m3_segment.trigger_time=0;
   g_m3_segment.structure_high=0.0;
   g_m3_segment.structure_low=0.0;
   g_m3_segment.pullback_extreme=0.0;
   g_m3_segment.pullback_reference=0.0;
   g_m3_segment.reaccel_reference=0.0;
   g_m3_segment.invalidation_reason="";
   g_m3_segment.structure_episode=false;
   g_m3_segment.persistence_confirmed=false;
   g_m3_segment.pullback_episode=false;
   g_m3_segment.pullback_reference_set=false;
   g_m3_segment.reacceleration_episode=false;
   g_m3_segment.episode_state=M3_EP_NONE;
   g_m3_segment.persistence_time=0;
   g_m3_segment.pullback_held_time=0;
   g_m3_segment.trigger_consumed=false;
   g_m3_segment.invalidation_time=0;
   g_m3_segment.last_trigger_event_side=0;
   g_m3_segment.last_trigger_event_time=0;
   g_m3_segment.start_time=s.bar_time;
   g_m3_segment.start_price=s.close;
   g_m3_segment.start_ma22=s.ma22;
   g_m3_segment.start_macd=s.wave;
   g_m3_segment.structure_valid=true;
   g_m3_segment.macd_valid=true;
   g_m3_segment.ma22_valid=true;
   g_m3_segment.pullback_active=false;
   g_m3_segment.reaccel_active=false;
   g_m3_segment.exhaustion_active=false;
}

void M3CreateRangeSegment(const JTC_M3_STATE &s)
{
   M3CreateSegment(M3_SEG_RANGE,s);
   g_m3_segment.regime=JTC_M3_REGIME_RANGE;
   g_m3_segment.phase=M3_PHASE_TRANSITION;
}

void M3UpdateSegmentMemory(const JTC_M3_STATE &s)
{
   // Segment memory is intentionally limited to lifecycle timing. Directional
   // interpretation lives in external/internal structure, not accumulated scores.
   g_m3_segment.last_close=s.close;
}
void M3UpdateSegmentPhase(const JTC_M3_STATE &s,const JTC_M3_MACD_STRUCTURE &macd,const JTC_M3_MA22_STRUCTURE &ma22,const int closed_index=1)
{
   // IMPORTANT: this function is an event-driven episode reducer. It does not
   // ask whether the current candle "looks like" a setup. Every transition
   // below requires a previously stored structural event.
   const double atr=MathMax(_Point,M3AutoATR());
   const double old_ext_high=g_m3_ext_last_high;
   const double old_ext_low=g_m3_ext_last_low;
   const datetime old_ext_high_time=g_m3_ext_last_high_time;
   const datetime old_ext_low_time=g_m3_ext_last_low_time;
   const double old_int_high=g_m3_int_last_high;
   const double old_int_low=g_m3_int_last_low;
   const datetime old_int_high_time=g_m3_int_last_high_time;
   const datetime old_int_low_time=g_m3_int_last_low_time;
   const double old_structure_high=g_m3_segment.structure_high;
   const double old_structure_low=g_m3_segment.structure_low;
   const datetime old_structure_high_time=g_m3_segment.structure_high_time;
   const datetime old_structure_low_time=g_m3_segment.structure_low_time;

   // One canonical event may be published for this completed bar. The event
   // is cleared on the next bar, while last_trigger_event_* remains immutable
   // history. No opposite-direction signal is used as a reset condition.
   M3UpdateAdaptiveSwingStructure(s,g_m3_segment.direction,closed_index);

   // v8.138: update the single canonical ACCEL stream used by chart, CSV and AUTO.
   // No second acceleration-event generator exists.
   M3UpdateDisplayAcceleration(s,closed_index,
                               old_ext_high,old_ext_low,
                               old_ext_high_time,old_ext_low_time,
                               old_int_high,old_int_low,
                               old_int_high_time,old_int_low_time);

   // v8.152: consume the pivot events emitted by the structure producer.
   // Do not rediscover them by comparing timestamps after the producer has
   // already updated its state on this same completed bar.
   const bool new_ext_high=g_m3_new_ext_high;
   const bool new_ext_low=g_m3_new_ext_low;
   const bool new_int_high=g_m3_new_int_high;
   const bool new_int_low=g_m3_new_int_low;

   // A trigger is actionable only on its own closed bar. Once the next bar
   // begins, close that trigger event so the same structural episode can form
   // its next pullback/reacceleration cycle. The immutable event latch remains.
   if(g_m3_segment.episode_state==M3_EP_TRIGGER &&
      g_m3_segment.trigger_time>0 && g_m3_segment.trigger_time!=s.bar_time)
   {
      g_m3_segment.trigger_consumed=true;
      g_m3_segment.episode_state=M3_EP_TRIGGER_CONSUMED;
   }

   g_m3_segment.trigger_long=false;
   g_m3_segment.trigger_short=false;
   g_m3_segment.trigger_time=0;

   if(g_m3_segment.direction==M3_SEG_LONG)
   {
      g_m3_segment.structure_break=M3LongStructureBroken(s);
      if(g_m3_segment.structure_break)
      {
         g_m3_segment.structure_valid=false;
         g_m3_segment.structure_state=JTC_M3_POS_FAILURE;
         g_m3_segment.regime=JTC_M3_REGIME_TRANSITION;
         g_m3_segment.phase=M3_PHASE_TRANSITION;
         const bool newly_invalidated=(g_m3_segment.episode_state!=M3_EP_INVALIDATED ||
                                       g_m3_segment.invalidation_time<=0);
         if(newly_invalidated)
         {
            g_m3_segment.invalidation_reason="PROTECTED_HL_BROKEN";
            g_m3_segment.invalidation_time=s.bar_time;
            g_m3_segment.structure_episode=false;
            g_m3_segment.persistence_confirmed=false;
            g_m3_segment.pullback_episode=false;
            g_m3_segment.pullback_reference_set=false;
            g_m3_segment.reacceleration_episode=false;
            g_m3_segment.episode_state=M3_EP_INVALIDATED;
            g_m3_segment.trigger_consumed=false;
            g_m3_segment.setup_long=false;
         }
         return;
      }

      // Confirmed internal HH+HL is the canonical M3 live structure.
      // External 2/2 pivots remain slower context and must not pin a broken
      // episode to its old direction.
      if(!g_m3_segment.structure_episode &&
         M3InternalLongStructureReady(g_m3_segment.invalidation_time))
      {
         M3CreateInternalStructureEpisode(s,1,g_m3_segment.invalidation_time);
      }

      // FORMATION is committed only when a new external HL follows an
      // external HH. Once committed, a later HH alone does not erase the
      // episode; the next confirming HL advances it.
      if(!g_m3_segment.structure_episode && g_m3_segment.external_bullish &&
         g_m3_ext_last_high_time>0 && g_m3_ext_last_low_time>0 &&
         g_m3_ext_last_high_time<g_m3_ext_last_low_time)
      {
         g_m3_segment.structure_episode=true;
         g_m3_segment.persistence_confirmed=false;
         g_m3_segment.episode_state=M3_EP_STRUCTURE_FORMED;
         g_m3_segment.structure_high=g_m3_ext_last_high;
         g_m3_segment.structure_high_time=g_m3_ext_last_high_time;
         g_m3_segment.structure_low=g_m3_ext_last_low;
         g_m3_segment.structure_low_time=g_m3_ext_last_low_time;
         g_m3_segment.protected_swing_low=g_m3_ext_last_low;
         g_m3_segment.have_protected_low=true;
      }
      else if(g_m3_segment.structure_episode && g_m3_segment.persistence_confirmed &&
              new_ext_low && g_m3_ext_last_high_time>g_m3_segment.structure_high_time &&
              g_m3_ext_last_high_time<g_m3_ext_last_low_time &&
              g_m3_ext_last_low>g_m3_segment.protected_swing_low)
      {
         g_m3_segment.structure_high=g_m3_ext_last_high;
         g_m3_segment.structure_high_time=g_m3_ext_last_high_time;
         g_m3_segment.structure_low=g_m3_ext_last_low;
         g_m3_segment.structure_low_time=g_m3_ext_last_low_time;
         g_m3_segment.protected_swing_low=g_m3_ext_last_low;
         g_m3_segment.have_protected_low=true;
      }

      // A consumed trigger does not end the structural episode. A new external
      // HH starts the next pullback/reacceleration sub-cycle while preserving
      // the same directional episode and its structural history.
      if(g_m3_segment.structure_episode && g_m3_segment.trigger_consumed &&
         new_ext_high && g_m3_ext_last_high_time>g_m3_segment.structure_high_time &&
         g_m3_ext_last_high>g_m3_segment.structure_high)
      {
         g_m3_segment.structure_high=g_m3_ext_last_high;
         g_m3_segment.structure_high_time=g_m3_ext_last_high_time;
         g_m3_segment.persistence_confirmed=true;
         g_m3_segment.persistence_time=g_m3_ext_last_high_time;
         g_m3_segment.pullback_episode=false;
         g_m3_segment.pullback_held=false;
         g_m3_segment.pullback_held_time=0;
         g_m3_segment.pullback_reference_set=false;
         g_m3_segment.pullback_reference=0.0;
         g_m3_segment.pullback_reference_time=0;
         g_m3_segment.pullback_extreme=0.0;
         g_m3_segment.reacceleration_episode=false;
         g_m3_segment.reaccel_time=0;
         g_m3_segment.reaccel_reference=0.0;
         g_m3_segment.trigger_consumed=false;
         g_m3_segment.trigger_long=false;
         g_m3_segment.setup_long=false;
         g_m3_segment.internal_pullback=false;
         g_m3_segment.internal_reaccel=false;
         g_m3_segment.episode_state=M3_EP_PERSISTING;
         g_m3_segment.phase=M3_PHASE_ACTIVE;
      }

      // Persistence is a distinct structural event. After HH -> HL forms,
      // a later external HH must occur. No elapsed-bar or indicator score is
      // allowed to manufacture persistence.
      if(g_m3_segment.structure_episode && !g_m3_segment.persistence_confirmed &&
         new_ext_high && g_m3_segment.structure_low_time>0 &&
         g_m3_ext_last_high_time>g_m3_segment.structure_low_time &&
         g_m3_ext_last_high>g_m3_segment.structure_high)
      {
         g_m3_segment.persistence_confirmed=true;
         g_m3_segment.persistence_time=g_m3_ext_last_high_time;
         g_m3_segment.structure_high=g_m3_ext_last_high;
         g_m3_segment.structure_high_time=g_m3_ext_last_high_time;
         g_m3_segment.episode_state=M3_EP_PERSISTING;
      }

      // Pullback can start once a valid price-structure episode exists.
      // Persistence remains a diagnostic lifecycle event, but it is not a
      // mandatory gate for the first actionable pullback/reacceleration.
      // This keeps the signal near the actual structural transition instead
      // of waiting for a second external extension that may occur much later.
      if(g_m3_segment.structure_episode &&
         new_int_low &&
         g_m3_int_last_low_time>g_m3_segment.structure_high_time &&
         g_m3_int_last_low>g_m3_segment.protected_swing_low)
      {
         double ref_high=0.0;
         datetime ref_time=0;
         if(g_m3_int_last_high_time>g_m3_segment.structure_high_time)
         { ref_high=g_m3_int_last_high; ref_time=g_m3_int_last_high_time; }
         else
         { ref_high=g_m3_segment.structure_high; ref_time=g_m3_segment.structure_high_time; }

         if(ref_high>0.0)
         {
            g_m3_segment.pullback_episode=true;
            g_m3_segment.pullback_held=false;
            g_m3_segment.pullback_held_time=0;
            g_m3_segment.episode_state=M3_EP_PULLBACK_STARTED;
            g_m3_segment.pullback_start_time=g_m3_int_last_low_time;
            g_m3_segment.pullback_reference=ref_high;
            g_m3_segment.pullback_reference_time=ref_time;
            g_m3_segment.pullback_reference_set=true;
            g_m3_segment.pullback_extreme=g_m3_int_last_low;
            g_m3_segment.setup_low=g_m3_int_last_low;
            g_m3_segment.setup_high=ref_high;
            g_m3_segment.entry_anchor_price=g_m3_int_last_low;
            g_m3_segment.entry_anchor_time=g_m3_int_last_low_time;
            g_m3_segment.phase=M3_PHASE_PULLBACK;
            g_m3_segment.internal_pullback=true;
            g_m3_segment.internal_reaccel=false;
            g_m3_segment.reacceleration_episode=false;
         }
      }

      // The current pullback extreme is live episode memory and is distinct
      // from the protected HL. It may move deeper while the protected anchor
      // remains unchanged.
      if(g_m3_segment.pullback_episode && !g_m3_segment.reacceleration_episode &&
         new_int_low && g_m3_int_last_low_time>g_m3_segment.pullback_start_time &&
         g_m3_int_last_low>g_m3_segment.protected_swing_low)
      {
         g_m3_segment.pullback_extreme=MathMin(g_m3_segment.pullback_extreme,g_m3_int_last_low);
         g_m3_segment.entry_anchor_price=g_m3_segment.pullback_extreme;
         g_m3_segment.entry_anchor_time=g_m3_int_last_low_time;
      }

      // HELD is a later observation, not the same event that starts the
      // pullback. One subsequent completed bar that preserves the protected
      // structure is sufficient; no arbitrary N-bar persistence is introduced.
      if(g_m3_segment.episode_state==M3_EP_PULLBACK_STARTED &&
         g_m3_segment.pullback_episode &&
         s.bar_time>g_m3_segment.pullback_start_time &&
         s.close>=g_m3_segment.protected_swing_low)
      {
         g_m3_segment.pullback_held=true;
         g_m3_segment.pullback_held_time=s.bar_time;
         g_m3_segment.episode_state=M3_EP_PULLBACK_HELD;
      }

      // The pullback remains valid until price violates the stored protected HL.
      if(g_m3_segment.pullback_episode &&
         s.close<g_m3_segment.protected_swing_low)
      {
         g_m3_segment.structure_break=true;
         g_m3_segment.structure_valid=false;
         g_m3_segment.invalidation_reason="PULLBACK_BROKE_PROTECTED_HL";
         g_m3_segment.phase=M3_PHASE_TRANSITION;
         g_m3_segment.regime=JTC_M3_REGIME_TRANSITION;
         g_m3_segment.setup_long=false;
         return;
      }

      // Reacceleration is an event AFTER the pullback, led by renewed MACD
      // impulse and price expansion. It does not create the pullback.
      if(g_m3_segment.episode_state==M3_EP_PULLBACK_HELD &&
         g_m3_segment.pullback_episode && g_m3_segment.pullback_reference_set &&
         !g_m3_segment.reacceleration_episode &&
         macd.rising && s.hist>=s.hist_prev &&
         s.close>s.ma22-atr*0.15 &&
         s.close>g_ms_rates[closed_index+1].high)
      {
         g_m3_segment.reacceleration_episode=true;
         g_m3_segment.internal_reaccel=true;
         g_m3_segment.reaccel_time=s.bar_time;
         g_m3_segment.episode_state=M3_EP_REACCELERATION;
         g_m3_segment.reaccel_reference=s.close;
         g_m3_segment.phase=M3_PHASE_REACCEL;
      }

      if(g_m3_segment.episode_state==M3_EP_REACCELERATION &&
         !g_m3_segment.trigger_consumed &&
         g_m3_segment.pullback_episode && g_m3_segment.reacceleration_episode &&
         g_m3_segment.pullback_reference_set &&
         s.close>g_m3_segment.pullback_reference)
      {
         g_m3_segment.trigger_long=true;
         const bool prior_same_direction_event=(g_m3_segment.last_trigger_event_side==M3_SEG_LONG && g_m3_segment.last_trigger_event_time>0);
         g_m3_segment.last_trigger_event_side=M3_SEG_LONG;
         g_m3_segment.last_trigger_event_time=s.bar_time;
         g_m3_segment.episode_state=M3_EP_TRIGGER;
         g_m3_segment.trigger_time=s.bar_time;
         g_m3_segment.phase=M3_PHASE_REACCEL;
         g_m3_segment.setup_long=true;
         g_m3_segment.structure_valid=true;
         return;
      }

      g_m3_segment.structure_valid=g_m3_segment.structure_episode;
      g_m3_segment.regime=JTC_M3_REGIME_TREND;
      g_m3_segment.setup_long=(g_m3_segment.pullback_episode && g_m3_segment.pullback_held);
      if(g_m3_segment.setup_long && !g_m3_segment.reacceleration_episode)
         g_m3_segment.phase=M3_PHASE_PULLBACK;
      else if(g_m3_segment.structure_episode)
         g_m3_segment.phase=M3_PHASE_ACTIVE;
      return;
   }

   if(g_m3_segment.direction==M3_SEG_SHORT)
   {
      g_m3_segment.structure_break=M3ShortStructureBroken(s);
      if(g_m3_segment.structure_break)
      {
         g_m3_segment.structure_valid=false;
         g_m3_segment.structure_state=JTC_M3_POS_FAILURE;
         g_m3_segment.regime=JTC_M3_REGIME_TRANSITION;
         g_m3_segment.phase=M3_PHASE_TRANSITION;
         const bool newly_invalidated=(g_m3_segment.episode_state!=M3_EP_INVALIDATED ||
                                       g_m3_segment.invalidation_time<=0);
         if(newly_invalidated)
         {
            g_m3_segment.invalidation_reason="PROTECTED_LH_BROKEN";
            g_m3_segment.invalidation_time=s.bar_time;
            g_m3_segment.structure_episode=false;
            g_m3_segment.persistence_confirmed=false;
            g_m3_segment.pullback_episode=false;
            g_m3_segment.pullback_reference_set=false;
            g_m3_segment.reacceleration_episode=false;
            g_m3_segment.episode_state=M3_EP_INVALIDATED;
            g_m3_segment.trigger_consumed=false;
            g_m3_segment.setup_short=false;
         }
         return;
      }

      if(!g_m3_segment.structure_episode &&
         M3InternalShortStructureReady(g_m3_segment.invalidation_time))
      {
         M3CreateInternalStructureEpisode(s,-1,g_m3_segment.invalidation_time);
      }

      if(!g_m3_segment.structure_episode && g_m3_segment.external_bearish &&
         g_m3_ext_last_low_time>0 && g_m3_ext_last_high_time>0 &&
         g_m3_ext_last_low_time<g_m3_ext_last_high_time)
      {
         g_m3_segment.structure_episode=true;
         g_m3_segment.persistence_confirmed=false;
         g_m3_segment.episode_state=M3_EP_STRUCTURE_FORMED;
         g_m3_segment.structure_low=g_m3_ext_last_low;
         g_m3_segment.structure_low_time=g_m3_ext_last_low_time;
         g_m3_segment.structure_high=g_m3_ext_last_high;
         g_m3_segment.structure_high_time=g_m3_ext_last_high_time;
         g_m3_segment.protected_swing_high=g_m3_ext_last_high;
         g_m3_segment.have_protected_high=true;
      }
      else if(g_m3_segment.structure_episode && g_m3_segment.persistence_confirmed &&
              new_ext_high && g_m3_ext_last_low_time>g_m3_segment.structure_low_time &&
              g_m3_ext_last_low_time<g_m3_ext_last_high_time &&
              g_m3_ext_last_high<g_m3_segment.protected_swing_high)
      {
         g_m3_segment.structure_low=g_m3_ext_last_low;
         g_m3_segment.structure_low_time=g_m3_ext_last_low_time;
         g_m3_segment.structure_high=g_m3_ext_last_high;
         g_m3_segment.structure_high_time=g_m3_ext_last_high_time;
         g_m3_segment.protected_swing_high=g_m3_ext_last_high;
         g_m3_segment.have_protected_high=true;
      }

      // Same episode, next sub-cycle: a new external LL after a consumed
      // trigger resets only the pullback/reacceleration setup, not direction.
      if(g_m3_segment.structure_episode && g_m3_segment.trigger_consumed &&
         new_ext_low && g_m3_ext_last_low_time>g_m3_segment.structure_low_time &&
         g_m3_ext_last_low<g_m3_segment.structure_low)
      {
         g_m3_segment.structure_low=g_m3_ext_last_low;
         g_m3_segment.structure_low_time=g_m3_ext_last_low_time;
         g_m3_segment.persistence_confirmed=true;
         g_m3_segment.persistence_time=g_m3_ext_last_low_time;
         g_m3_segment.pullback_episode=false;
         g_m3_segment.pullback_held=false;
         g_m3_segment.pullback_held_time=0;
         g_m3_segment.pullback_reference_set=false;
         g_m3_segment.pullback_reference=0.0;
         g_m3_segment.pullback_reference_time=0;
         g_m3_segment.pullback_extreme=0.0;
         g_m3_segment.reacceleration_episode=false;
         g_m3_segment.reaccel_time=0;
         g_m3_segment.reaccel_reference=0.0;
         g_m3_segment.trigger_consumed=false;
         g_m3_segment.trigger_short=false;
         g_m3_segment.setup_short=false;
         g_m3_segment.internal_pullback=false;
         g_m3_segment.internal_reaccel=false;
         g_m3_segment.episode_state=M3_EP_PERSISTING;
         g_m3_segment.phase=M3_PHASE_ACTIVE;
      }

      // v8.110: chart pre-signal is independent of the SHORT order lifecycle.
      // Persistence for SHORT requires a later external LL after LL -> LH.
      if(g_m3_segment.structure_episode && !g_m3_segment.persistence_confirmed &&
         new_ext_low && g_m3_segment.structure_high_time>0 &&
         g_m3_ext_last_low_time>g_m3_segment.structure_high_time &&
         g_m3_ext_last_low<g_m3_segment.structure_low)
      {
         g_m3_segment.persistence_confirmed=true;
         g_m3_segment.persistence_time=g_m3_ext_last_low_time;
         g_m3_segment.structure_low=g_m3_ext_last_low;
         g_m3_segment.structure_low_time=g_m3_ext_last_low_time;
         g_m3_segment.episode_state=M3_EP_PERSISTING;
      }

      // SHORT mirrors LONG: a valid price-structure episode is sufficient
      // to begin the first actionable pullback. Persistence is retained as
      // lifecycle information, not as a first-trigger prerequisite.
      if(g_m3_segment.structure_episode &&
         new_int_high &&
         g_m3_int_last_high_time>g_m3_segment.structure_low_time &&
         g_m3_int_last_high<g_m3_segment.protected_swing_high)
      {
         double ref_low=0.0;
         datetime ref_time=0;
         if(g_m3_int_last_low_time>g_m3_segment.structure_low_time)
         { ref_low=g_m3_int_last_low; ref_time=g_m3_int_last_low_time; }
         else
         { ref_low=g_m3_segment.structure_low; ref_time=g_m3_segment.structure_low_time; }

         if(ref_low>0.0)
         {
            g_m3_segment.pullback_episode=true;
            g_m3_segment.pullback_held=false;
            g_m3_segment.pullback_held_time=0;
            g_m3_segment.episode_state=M3_EP_PULLBACK_STARTED;
            g_m3_segment.pullback_start_time=g_m3_int_last_high_time;
            g_m3_segment.pullback_reference=ref_low;
            g_m3_segment.pullback_reference_time=ref_time;
            g_m3_segment.pullback_reference_set=true;
            g_m3_segment.pullback_extreme=g_m3_int_last_high;
            g_m3_segment.setup_high=g_m3_int_last_high;
            g_m3_segment.setup_low=ref_low;
            g_m3_segment.entry_anchor_price=g_m3_int_last_high;
            g_m3_segment.entry_anchor_time=g_m3_int_last_high_time;
            g_m3_segment.phase=M3_PHASE_PULLBACK;
            g_m3_segment.internal_pullback=true;
            g_m3_segment.internal_reaccel=false;
            g_m3_segment.reacceleration_episode=false;
         }
      }

      if(g_m3_segment.pullback_episode && !g_m3_segment.reacceleration_episode &&
         new_int_high && g_m3_int_last_high_time>g_m3_segment.pullback_start_time &&
         g_m3_int_last_high<g_m3_segment.protected_swing_high)
      {
         g_m3_segment.pullback_extreme=MathMax(g_m3_segment.pullback_extreme,g_m3_int_last_high);
         g_m3_segment.entry_anchor_price=g_m3_segment.pullback_extreme;
         g_m3_segment.entry_anchor_time=g_m3_int_last_high_time;
      }

      if(g_m3_segment.episode_state==M3_EP_PULLBACK_STARTED &&
         g_m3_segment.pullback_episode &&
         s.bar_time>g_m3_segment.pullback_start_time &&
         s.close<=g_m3_segment.protected_swing_high)
      {
         g_m3_segment.pullback_held=true;
         g_m3_segment.pullback_held_time=s.bar_time;
         g_m3_segment.episode_state=M3_EP_PULLBACK_HELD;
      }

      if(g_m3_segment.pullback_episode &&
         s.close>g_m3_segment.protected_swing_high)
      {
         g_m3_segment.structure_break=true;
         g_m3_segment.structure_valid=false;
         g_m3_segment.invalidation_reason="PULLBACK_BROKE_PROTECTED_LH";
         g_m3_segment.phase=M3_PHASE_TRANSITION;
         g_m3_segment.regime=JTC_M3_REGIME_TRANSITION;
         g_m3_segment.setup_short=false;
         return;
      }

      if(g_m3_segment.episode_state==M3_EP_PULLBACK_HELD &&
         g_m3_segment.pullback_episode && g_m3_segment.pullback_reference_set &&
         !g_m3_segment.reacceleration_episode &&
         macd.falling && s.hist<=s.hist_prev &&
         s.close<s.ma22+atr*0.15 &&
         s.close<g_ms_rates[closed_index+1].low)
      {
         g_m3_segment.reacceleration_episode=true;
         g_m3_segment.internal_reaccel=true;
         g_m3_segment.reaccel_time=s.bar_time;
         g_m3_segment.reaccel_reference=s.close;
         g_m3_segment.episode_state=M3_EP_REACCELERATION;
         g_m3_segment.phase=M3_PHASE_REACCEL;
      }

      if(g_m3_segment.episode_state==M3_EP_REACCELERATION &&
         !g_m3_segment.trigger_consumed &&
         g_m3_segment.pullback_episode && g_m3_segment.reacceleration_episode &&
         g_m3_segment.pullback_reference_set &&
         s.close<g_m3_segment.pullback_reference)
      {
         g_m3_segment.trigger_short=true;
         const bool prior_same_direction_event=(g_m3_segment.last_trigger_event_side==M3_SEG_SHORT && g_m3_segment.last_trigger_event_time>0);
         g_m3_segment.last_trigger_event_side=M3_SEG_SHORT;
         g_m3_segment.last_trigger_event_time=s.bar_time;
         g_m3_segment.episode_state=M3_EP_TRIGGER;
         g_m3_segment.trigger_time=s.bar_time;
         g_m3_segment.phase=M3_PHASE_REACCEL;
         g_m3_segment.setup_short=true;
         g_m3_segment.structure_valid=true;
         return;
      }

      g_m3_segment.structure_valid=g_m3_segment.structure_episode;
      g_m3_segment.regime=JTC_M3_REGIME_TREND;
      g_m3_segment.setup_short=(g_m3_segment.pullback_episode && g_m3_segment.pullback_held);
      if(g_m3_segment.setup_short && !g_m3_segment.reacceleration_episode)
         g_m3_segment.phase=M3_PHASE_PULLBACK;
      else if(g_m3_segment.structure_episode)
         g_m3_segment.phase=M3_PHASE_ACTIVE;
      return;
   }

   g_m3_segment.regime=JTC_M3_REGIME_RANGE;
   g_m3_segment.phase=M3_PHASE_TRANSITION;
}

void M3SegmentUpdate(const JTC_M3_STATE &s,const JTC_M3_MACD_STRUCTURE &macd,const JTC_M3_MA22_STRUCTURE &ma22,const int closed_index=1)
{
   // Update structure memory before deriving direction. Direction is created
   // only from confirmed external price structure; indicators never seed it.
   M3UpdateAdaptiveSwingStructure(s,M3_SEG_NONE,closed_index);

   const bool long_bias=M3LongStructuralBias(s,macd,ma22);
   const bool short_bias=M3ShortStructuralBias(s,macd,ma22);

   if(g_m3_segment.direction==M3_SEG_NONE)
   {
      if(long_bias && !short_bias)
      {
         M3CreateSegment(M3_SEG_LONG,s);
         M3UpdateAdaptiveSwingStructure(s,g_m3_segment.direction,closed_index);
         M3UpdateSegmentPhase(s,macd,ma22,closed_index);
      }
      else if(short_bias && !long_bias)
      {
         M3CreateSegment(M3_SEG_SHORT,s);
         M3UpdateAdaptiveSwingStructure(s,g_m3_segment.direction,closed_index);
         M3UpdateSegmentPhase(s,macd,ma22,closed_index);
      }
      else
      {
         // No confirmed price structure = no directional segment. Do not seed
         // direction from indicators. If both internal directions are present,
         // use the more recent pivot side only when it is structurally clearer.
         const bool il=M3InternalLongStructureReady();
         const bool is=M3InternalShortStructureReady();
         if(il && !is)
         {
            M3CreateSegment(M3_SEG_LONG,s);
            M3UpdateAdaptiveSwingStructure(s,g_m3_segment.direction,closed_index);
            M3UpdateSegmentPhase(s,macd,ma22,closed_index);
         }
         else if(is && !il)
         {
            M3CreateSegment(M3_SEG_SHORT,s);
            M3UpdateAdaptiveSwingStructure(s,g_m3_segment.direction,closed_index);
            M3UpdateSegmentPhase(s,macd,ma22,closed_index);
         }
         else
         {
            g_m3_segment.regime=JTC_M3_REGIME_RANGE;
            g_m3_segment.phase=M3_PHASE_TRANSITION;
         }
      }
      return;
   }

   M3UpdateSegmentMemory(s);
   M3UpdateSegmentPhase(s,macd,ma22,closed_index);

   // Range is defined by structural conflict/compression, not a continuity score.
   const bool no_external=(!g_m3_segment.external_bullish && !g_m3_segment.external_bearish);
   const bool compressed=ma22.flattening && !g_m3_segment.trigger_long && !g_m3_segment.trigger_short;
   if(g_m3_segment.direction!=M3_SEG_RANGE && no_external && compressed &&
      !g_m3_segment.internal_pullback && !g_m3_segment.internal_reaccel)
   {
      g_m3_segment.regime=JTC_M3_REGIME_RANGE;
      g_m3_segment.phase=M3_PHASE_TRANSITION;
   }

   if(g_m3_segment.phase==M3_PHASE_TRANSITION)
   {
      // After a protected structure break, do not flip direction from a
      // transient latest HH/HL or LH/LL flag. The opposite episode must have
      // its required external high AND low confirmed after the invalidation.
      // This prevents the previous episode's pivot from pinning the engine in
      // TRANSITION while also preventing an immediate one-bar direction flip.
      const bool opposite_short_ready=(
         g_m3_segment.episode_state==M3_EP_INVALIDATED &&
         g_m3_segment.direction==M3_SEG_LONG &&
         g_m3_segment.invalidation_time>0 &&
         M3InternalShortStructureReady(g_m3_segment.invalidation_time));
      const bool opposite_long_ready=(
         g_m3_segment.episode_state==M3_EP_INVALIDATED &&
         g_m3_segment.direction==M3_SEG_SHORT &&
         g_m3_segment.invalidation_time>0 &&
         M3InternalLongStructureReady(g_m3_segment.invalidation_time));
      if(opposite_short_ready)
         M3CreateSegment(M3_SEG_SHORT,s);
      else if(opposite_long_ready)
         M3CreateSegment(M3_SEG_LONG,s);
      else if(g_m3_segment.direction==M3_SEG_RANGE)
      {
         if(long_bias && !short_bias) M3CreateSegment(M3_SEG_LONG,s);
         else if(short_bias && !long_bias) M3CreateSegment(M3_SEG_SHORT,s);
      }
   }
}



// Build the same causal state used by live processing for a historical closed bar.
bool M3BuildStateAtIndex(const int i,JTC_M3_STATE &s)
{
   const int n=ArraySize(g_ms_rates);
   if(i<1 || i+8>=n) return false;
   s.bar_time=g_ms_rates[i].time;
   s.close=g_ms_rates[i].close;
   s.high=g_ms_rates[i].high;
   s.low=g_ms_rates[i].low;
   s.ma7=g_ms_fast_ma[i]; s.ma22=g_ms_slow_ma[i];
   s.ma7_prev=g_ms_fast_ma[i+1]; s.ma22_prev=g_ms_slow_ma[i+1];
   s.wave=g_ms_macd_wave[i]; s.signal=g_ms_macd[i];
   s.wave_prev=g_ms_macd_wave[i+1]; s.signal_prev=g_ms_macd[i+1];
   s.wave_prev2=g_ms_macd_wave[i+2]; s.signal_prev2=g_ms_macd[i+2];
   s.hist=s.wave-s.signal; s.hist_prev=s.wave_prev-s.signal_prev;
   s.raw_delta=g_ms_delta[i]; s.raw_delta_prev=g_ms_delta[i+1];
   s.delta_ema=g_ms_delta_ema[i]; s.delta_ema_prev=g_ms_delta_ema[i+1];
   s.volume=g_ms_delta_volume[i]; s.volume_prev=g_ms_delta_volume[i+1];
   double sum=0.0; int nvol=0;
   for(int j=i+1;j<=i+7;j++) if(g_ms_delta_volume[j]>0.0){sum+=g_ms_delta_volume[j]; nvol++;}
   s.volume_avg=nvol>0 ? sum/nvol : MathMax(1.0,s.volume_prev);
   s.volume_ratio=s.volume_avg>0.0 ? s.volume/s.volume_avg : 1.0;
   s.macd_direction=g_ms_macd_direction[i]; s.macd_zero=g_ms_macd_zero_state[i];
   return true;
}

bool M3WarmupRebuild()
{
   g_m3_runtime_mode=M3_RUNTIME_WARMUP;
   g_m3_warmup_complete=false;

   const int requested=MathMax(64,InpM3StructureWarmupBars);
   const int ceiling=MathMax(requested,InpM3StructureWarmupMaxBars);
   int replay_bars=requested;

   for(int attempt=0; attempt<2; ++attempt)
   {
      M3AutoResetFlatState();
      if(!EnsureMarketSnapshotAssist(replay_bars))
         return false;

      const int available=MathMin(replay_bars,ArraySize(g_ms_rates)-9);
      if(available<32) return false;

      for(int i=available;i>=1;i--)
      {
         JTC_M3_STATE hs; if(!M3BuildStateAtIndex(i,hs)) continue;
         JTC_M3_MACD_STRUCTURE hm; M3AnalyzeMACD(hs,hm);
         JTC_M3_MA22_STRUCTURE hma; M3AnalyzeMA22(hs,hma);
         g_m3_eval_index=i;
         M3SegmentUpdate(hs,hm,hma,i);
      }
      g_m3_eval_index=1;

      // Expand only when the active directional episode actually reaches the
      // replay boundary. A normal episode remains at the configured start
      // window; no unconditional 1600-bar replay is performed.
      const datetime oldest_time=g_ms_rates[available].time;
      const bool boundary_reached=(g_m3_segment.direction!=M3_SEG_NONE &&
                                   g_m3_segment.direction!=M3_SEG_RANGE &&
                                   g_m3_segment.start_time>0 &&
                                   g_m3_segment.start_time<=oldest_time);
      if(boundary_reached && replay_bars<ceiling)
      {
         replay_bars=ceiling;
         continue;
      }
      break;
   }

   // Historical trigger events are never actionable at startup. The immutable
   // latch is retained only if it belongs to a future live bar; warmup bars are
   // therefore explicitly consumed and the executable flags are cleared.
   g_m3_segment.trigger_long=false;
   g_m3_segment.trigger_short=false;
   g_m3_segment.trigger_consumed=true;
   if(g_m3_segment.episode_state==M3_EP_TRIGGER)
      g_m3_segment.episode_state=M3_EP_TRIGGER_CONSUMED;
   g_m3_warmup_complete=true;
   g_m3_runtime_mode=(g_auto_trading ? M3_RUNTIME_AUTOTRADING : M3_RUNTIME_MONITORING);
   return true;
}

// Compatibility wrapper: legacy callers may still reference this function,
// but it now returns the persistent segment direction rather than calculating
// an independent candle/regime signal.

#endif
