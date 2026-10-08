//+------------------------------------------------------------------+
//| HoldEngine.mqh                                               |
//| Joon Trend/Range AutoTrader modular component                    |
//+------------------------------------------------------------------+
#ifndef __JOON_HOLDENGINE_MQH__
#define __JOON_HOLDENGINE_MQH__


// HoldEngine owns all HOLD state transitions. SignalEngine may calculate
// evidence, but it must never mutate g_hold_state or the hold-state counters.
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
                               const double close_price)
{
   // M3 AUTO owns HOLD state completely. Legacy HoldEngine remains available
   // for non-M3/diagnostic paths but must never mutate HOLD state for a managed
   // M3 position.
   if(g_m3_position_managed)
      return;

   if(strong_trend_hold || fresh_extreme_update)
   {
      g_hold_weak_bars = 0;
      g_hold_warning_bars = 0;
      g_hold_exit_candidate_bars = 0;
   }
   else
   {
      g_hold_weak_bars = weak_hold_bar ? g_hold_weak_bars + 1 : 0;
      g_hold_warning_bars = warning_bar ? g_hold_warning_bars + 1 : 0;
      g_hold_exit_candidate_bars = exit_candidate_bar ?
         g_hold_exit_candidate_bars + 1 : 0;
   }

   const ENUM_HOLD_STATE previous_hold_state = g_hold_state;
   if(strong_trend_hold || (fresh_extreme_update && ma_normal_structure))
      g_hold_state = HOLD_STRONG;
   else if(g_hold_exit_candidate_bars >= MathMax(1, InpHoldExitCandidateConfirmBars))
      g_hold_state = HOLD_EXIT_CANDIDATE;
   else if(g_hold_warning_bars >= MathMax(1, InpHoldWarningConfirmBars))
      g_hold_state = HOLD_WARNING;
   else if(g_hold_weak_bars >= InpProfitProtectWeakBars)
      g_hold_state = HOLD_PROFIT_PROTECT;
   else if(ma_normal_structure)
      g_hold_state = HOLD_NORMAL;
   else
      g_hold_state = HOLD_WARNING;

   g_strong_hold_active = (g_hold_state == HOLD_STRONG);

   if(previous_hold_state == g_hold_state)
      return;

   string hold_reason = "STATE CHANGE";
   if(g_hold_state == HOLD_STRONG)
      hold_reason = strong_trend_hold ? "STRONG TREND CONDITIONS" :
                                       "FRESH EXTREME + MA STRUCTURE";
   else if(g_hold_state == HOLD_EXIT_CANDIDATE)
      hold_reason = StringFormat("EXIT FAILURES=%d CONFIRM_BARS=%d",
                                 exit_failure_count, g_hold_exit_candidate_bars);
   else if(g_hold_state == HOLD_WARNING)
      hold_reason = StringFormat(
         "WARNING BARS=%d | DELTA_DECLINE=%s | MACD_WEAK=%s | MA_WARNING=%s",
         g_hold_warning_bars, delta_declining ? "YES" : "NO",
         macd_slope_weak ? "YES" : "NO", ma_warning ? "YES" : "NO");
   else if(g_hold_state == HOLD_PROFIT_PROTECT)
      hold_reason = StringFormat("WEAK HOLD BARS=%d", g_hold_weak_bars);
   else
      hold_reason = "MA STRUCTURE NORMALIZED";

   WriteLifecycleEvent("HOLD_STATE_CHANGE", position_side,
      previous_hold_state == HOLD_STRONG ? "STRONG" :
      previous_hold_state == HOLD_WARNING ? "WARNING" :
      previous_hold_state == HOLD_EXIT_CANDIDATE ? "EXIT_CANDIDATE" :
      previous_hold_state == HOLD_PROFIT_PROTECT ? "PROFIT_PROTECT" : "NORMAL",
      g_hold_state == HOLD_STRONG ? "STRONG" :
      g_hold_state == HOLD_WARNING ? "WARNING" :
      g_hold_state == HOLD_EXIT_CANDIDATE ? "EXIT_CANDIDATE" :
      g_hold_state == HOLD_PROFIT_PROTECT ? "PROFIT_PROTECT" : "NORMAL",
      hold_reason, 0, close_price, 0.0, 0.0, TimeCurrent());
}

void HoldEngineResetState()
{
   g_strong_hold_active = false;
   g_hold_state = HOLD_UNKNOWN;
   g_hold_weak_bars = 0;
   g_hold_warning_bars = 0;
   g_hold_exit_candidate_bars = 0;
   g_hold_direction_score = 0;
   g_hold_strong_score = 0;
   g_hold_weakness_score = 0;
}

// Shared completed-bar RANGE low-energy context. HoldEngine owns the state
// interpretation; no position-management function should recreate it.
bool RangeLowEnergyWarningContext()
{
   return g_csv_neutral_flow ||
          g_csv_compressed_chop ||
          g_csv_no_market_energy;
}


//+------------------------------------------------------------------+

struct JTA_HoldSegmentMetrics
{
   int span;
   double macd_start;
   double macd_now;
   double macd_best;
   double macd_worst;
   double macd_direction_ratio;

   double delta_sum;
   double delta_same_sum;
   double delta_opposite_sum;
   double delta_direction_ratio;

   double ma_spread_start;
   double ma_spread_now;
   double ma_fast_slope;
   double ma_slow_slope;

   double price_start;
   double price_now;
   double segment_high;
   double segment_low;
   double progress_ratio;

   // v3.68 recent-deterioration diagnostics inside the SAME dynamic Leg.
   // These never own an exit. They only stop an old strong Leg from
   // over-supporting the current HOLD score after a genuine recent reversal.
   int recent_span;
   double recent_macd_direction_ratio;
   double recent_delta_direction_ratio;
   double extreme_giveback_ratio;
   bool recent_macd_reversal;
   bool recent_delta_reversal;
   bool recent_price_reversal;
   int recent_deterioration_count;

   bool macd_support;
   bool macd_fading;
   bool macd_opposite_expansion;

   bool delta_support;
   bool delta_fading;
   bool delta_opposite_pressure;

   bool ma_support;
   bool ma_compressing;
   bool ma_reversed;

   bool price_support;
   bool price_pullback;
   bool price_reversal;
};

int HoldSegmentLookback()
{
   // The segment length follows the live position, not a fixed N-bar rule.
   // A safety cap only prevents excessive CopyBuffer work on very old positions.
   const int held=MathMax(1,BarsSinceInitialEntry());
   return MathMax(8,MathMin(64,held+3));
}

int FindDirectionalSegmentEnd(const int side,const int loaded)
{
   // Search backward from the current completed bar for the most recent
   // structural boundary: price on the opposite side of MA22 together with
   // MA7/MA22 opposite ordering. The bars after that boundary are the current Leg.
   int end=MathMax(2,loaded-1);
   for(int i=2;i<loaded;i++)
   {
      const bool opposite_structure=side>0 ?
         (g_ms_rates[i].close<g_ms_slow_ma[i] &&
          g_ms_fast_ma[i]<=g_ms_slow_ma[i]) :
         (g_ms_rates[i].close>g_ms_slow_ma[i] &&
          g_ms_fast_ma[i]>=g_ms_slow_ma[i]);
      if(opposite_structure)
      {
         end=MathMax(2,i-1);
         break;
      }
   }
   return end;
}

bool BuildHoldSegmentMetrics(const int side,JTA_HoldSegmentMetrics &m)
{
   ZeroMemory(m);
   if(side==0)
      return false;

   const int requested=HoldSegmentLookback();
   if(!EnsureMarketSnapshot(requested))
      return false;

   const int loaded=MathMin(g_market_snapshot.loaded_count,requested);
   if(loaded<4)
      return false;

   const int end=FindDirectionalSegmentEnd(side,loaded);
   m.span=MathMax(1,end);
   m.price_now=g_ms_rates[1].close;
   m.price_start=g_ms_rates[end].close;
   m.macd_now=g_ms_macd[1];
   m.macd_start=g_ms_macd[end];

   m.segment_high=g_ms_rates[1].high;
   m.segment_low=g_ms_rates[1].low;
   m.macd_best=g_ms_macd[1];
   m.macd_worst=g_ms_macd[1];

   double macd_direction_total=0.0;
   double macd_direction_good=0.0;
   double recent_same_delta=0.0;
   double older_same_delta=0.0;
   double recent_opp_delta=0.0;
   double older_opp_delta=0.0;
   int recent_n=0,older_n=0;

   // Recent window follows the Leg itself instead of a fixed 1-2 bar rule.
   // About the newest third of the current Leg is enough to represent current
   // deterioration while still filtering single-bar RANGE noise.
   m.recent_span=MathMax(2,MathMin(end,(end+2)/3));
   double recent_macd_total=0.0;
   double recent_macd_good=0.0;
   double recent_delta_same_sum=0.0;
   double recent_delta_opp_sum=0.0;

   for(int i=1;i<=end;i++)
   {
      m.segment_high=MathMax(m.segment_high,g_ms_rates[i].high);
      m.segment_low=MathMin(m.segment_low,g_ms_rates[i].low);
      m.macd_best=side>0?MathMax(m.macd_best,g_ms_macd[i]):
                         MathMin(m.macd_best,g_ms_macd[i]);
      m.macd_worst=side>0?MathMin(m.macd_worst,g_ms_macd[i]):
                          MathMax(m.macd_worst,g_ms_macd[i]);

      const double signed_delta=side*g_ms_delta[i];
      m.delta_sum+=signed_delta;
      if(signed_delta>=0.0) m.delta_same_sum+=signed_delta;
      else                  m.delta_opposite_sum+=-signed_delta;

      const double weight=1.0/(double)MathMax(1,i);
      macd_direction_total+=weight;
      const bool macd_good=side>0 ?
         (g_ms_macd[i]>=g_ms_macd[MathMin(end,i+1)]) :
         (g_ms_macd[i]<=g_ms_macd[MathMin(end,i+1)]);
      if(macd_good) macd_direction_good+=weight;

      if(i<=m.recent_span)
      {
         recent_macd_total+=1.0;
         if(macd_good) recent_macd_good+=1.0;
         if(signed_delta>=0.0) recent_delta_same_sum+=signed_delta;
         else                  recent_delta_opp_sum+=-signed_delta;
      }

      // Compare the recent half of the current Leg with its older half.
      // The split is derived from the Leg length itself, not a fixed bar count.
      if(i<=MathMax(1,end/2))
      {
         recent_same_delta+=MathMax(0.0,signed_delta);
         recent_opp_delta+=MathMax(0.0,-signed_delta);
         recent_n++;
      }
      else
      {
         older_same_delta+=MathMax(0.0,signed_delta);
         older_opp_delta+=MathMax(0.0,-signed_delta);
         older_n++;
      }
   }

   m.macd_direction_ratio=macd_direction_total>0.0?
      macd_direction_good/macd_direction_total:0.0;

   const double delta_total=m.delta_same_sum+m.delta_opposite_sum;
   m.delta_direction_ratio=delta_total>0.0?
      m.delta_same_sum/delta_total:0.5;

   m.recent_macd_direction_ratio=recent_macd_total>0.0?
      recent_macd_good/recent_macd_total:0.5;
   const double recent_delta_total=
      recent_delta_same_sum+recent_delta_opp_sum;
   m.recent_delta_direction_ratio=recent_delta_total>0.0?
      recent_delta_same_sum/recent_delta_total:0.5;

   const double recent_same_avg=recent_same_delta/MathMax(1,recent_n);
   const double older_same_avg=older_same_delta/MathMax(1,older_n);
   const double recent_opp_avg=recent_opp_delta/MathMax(1,recent_n);
   const double older_opp_avg=older_opp_delta/MathMax(1,older_n);

   m.ma_spread_now=side*(g_ms_fast_ma[1]-g_ms_slow_ma[1]);
   m.ma_spread_start=side*(g_ms_fast_ma[end]-g_ms_slow_ma[end]);
   m.ma_fast_slope=side*(g_ms_fast_ma[1]-g_ms_fast_ma[end])/
      (double)MathMax(1,end-1);
   m.ma_slow_slope=side*(g_ms_slow_ma[1]-g_ms_slow_ma[end])/
      (double)MathMax(1,end-1);

   const double segment_range=MathMax(m.segment_high-m.segment_low,_Point);
   const double directional_progress=side*(m.price_now-m.price_start);
   m.progress_ratio=directional_progress/segment_range;

   // MACD: support is either same-side location or a clear recovery through
   // the current Leg. Fading means the Leg made progress but MACD surrendered
   // a meaningful portion of its own directional extreme.
   const bool macd_same_side=side*m.macd_now>0.0;
   const bool macd_improving=side*(m.macd_now-m.macd_start)>0.0 &&
                             m.macd_direction_ratio>=0.50;
   m.macd_support=macd_same_side || macd_improving;

   const double macd_excursion=MathAbs(m.macd_best-m.macd_worst);
   const double macd_from_best=MathAbs(m.macd_best-m.macd_now);
   m.macd_fading=m.macd_support && macd_excursion>0.0 &&
      macd_from_best/macd_excursion>0.50 &&
      side*(m.macd_now-m.macd_start)<=0.0;

   m.macd_opposite_expansion=side*m.macd_now<0.0 &&
      side*(m.macd_now-m.macd_start)<0.0 &&
      m.macd_direction_ratio<0.50;

   // Delta: use participation across the whole Leg plus whether recent pressure
   // is strengthening or being replaced by opposite participation.
   m.delta_support=m.delta_direction_ratio>=0.55 ||
      (m.delta_sum>0.0 && recent_same_avg>=older_same_avg);
   m.delta_fading=m.delta_support &&
      older_n>0 && recent_same_avg<older_same_avg &&
      recent_opp_avg>older_opp_avg;
   m.delta_opposite_pressure=m.delta_direction_ratio<0.45 &&
      recent_opp_avg>=older_opp_avg;

   // MA7/22 form the structural spine.
   m.ma_support=m.ma_spread_now>=0.0 &&
      m.ma_slow_slope>=0.0;
   m.ma_compressing=!m.ma_reversed &&
      m.ma_spread_now>=0.0 &&
      m.ma_spread_now<m.ma_spread_start &&
      m.ma_fast_slope<m.ma_slow_slope;
   m.ma_reversed=m.ma_spread_now<0.0 &&
      m.ma_fast_slope<0.0 &&
      m.ma_slow_slope<=0.0;

   // Price: interpret the whole Leg. A pullback is allowed while MA22 structure
   // is preserved; reversal requires both adverse location and adverse progress.
   const bool above_slow=side>0 ? m.price_now>=g_ms_slow_ma[1]
                                : m.price_now<=g_ms_slow_ma[1];
   const bool above_fast=side>0 ? m.price_now>=g_ms_fast_ma[1]
                                : m.price_now<=g_ms_fast_ma[1];
   m.price_support=directional_progress>=0.0 && above_slow;
   m.price_pullback=!above_fast && above_slow && directional_progress>=0.0;
   m.price_reversal=!above_slow && directional_progress<0.0;

   // Recent deterioration overlay. Keep the full Dynamic Leg as context,
   // but compare the newest Leg portion with the position direction.
   // This is deliberately NOT a direct failure/exit rule.
   const double giveback_from_extreme=side>0 ?
      (m.segment_high-m.price_now) :
      (m.price_now-m.segment_low);
   m.extreme_giveback_ratio=MathMax(0.0,
      MathMin(1.5,giveback_from_extreme/segment_range));

   // Recent MACD reversal requires the newest dynamic sub-region to be
   // predominantly moving against the held side AND current MACD to have
   // deteriorated versus the sub-region's older edge.
   const int recent_edge=MathMin(end,MathMax(2,m.recent_span));
   m.recent_macd_reversal=
      m.recent_macd_direction_ratio<0.40 &&
      side*(g_ms_macd[1]-g_ms_macd[recent_edge])<0.0;

   // Recent Delta must actually be opposite-dominant. The old full-Leg Delta
   // may remain supportive, but it can no longer by itself preserve STRONG.
   m.recent_delta_reversal=
      m.recent_delta_direction_ratio<0.45 &&
      recent_delta_opp_sum>recent_delta_same_sum &&
      recent_opp_avg>=older_opp_avg;

   // Price reversal requires meaningful giveback from the Leg extreme plus
   // loss of the fast-MA side. Crossing MA22 remains a stronger existing
   // direct structural condition, so this recent signal only caps HOLD state.
   m.recent_price_reversal=
      m.extreme_giveback_ratio>=0.50 &&
      !above_fast;

   m.recent_deterioration_count=
      (m.recent_macd_reversal?1:0)+
      (m.recent_delta_reversal?1:0)+
      (m.recent_price_reversal?1:0);

   return true;
}

// v5.97 diagnostic-only: build the same Dynamic-Leg market metrics used by
// RANGE HoldEngine, but from a caller-supplied pre-entry/add lookback. This
// function does not read or mutate position/HOLD runtime state.
bool BuildRangeSignalStateSegmentMetrics(const int side,
                                        const int requested_lookback,
                                        JTA_HoldSegmentMetrics &m)
{
   ZeroMemory(m);
   if(side==0)
      return false;

   const int requested=MathMax(8,MathMin(64,requested_lookback));
   if(!EnsureMarketSnapshot(requested))
      return false;

   const int loaded=MathMin(g_market_snapshot.loaded_count,requested);
   if(loaded<4)
      return false;

   const int end=FindDirectionalSegmentEnd(side,loaded);
   m.span=MathMax(1,end);
   m.price_now=g_ms_rates[1].close;
   m.price_start=g_ms_rates[end].close;
   m.macd_now=g_ms_macd[1];
   m.macd_start=g_ms_macd[end];

   m.segment_high=g_ms_rates[1].high;
   m.segment_low=g_ms_rates[1].low;
   m.macd_best=g_ms_macd[1];
   m.macd_worst=g_ms_macd[1];

   double macd_direction_total=0.0;
   double macd_direction_good=0.0;
   double recent_same_delta=0.0;
   double older_same_delta=0.0;
   double recent_opp_delta=0.0;
   double older_opp_delta=0.0;
   int recent_n=0,older_n=0;

   // Recent window follows the Leg itself instead of a fixed 1-2 bar rule.
   // About the newest third of the current Leg is enough to represent current
   // deterioration while still filtering single-bar RANGE noise.
   m.recent_span=MathMax(2,MathMin(end,(end+2)/3));
   double recent_macd_total=0.0;
   double recent_macd_good=0.0;
   double recent_delta_same_sum=0.0;
   double recent_delta_opp_sum=0.0;

   for(int i=1;i<=end;i++)
   {
      m.segment_high=MathMax(m.segment_high,g_ms_rates[i].high);
      m.segment_low=MathMin(m.segment_low,g_ms_rates[i].low);
      m.macd_best=side>0?MathMax(m.macd_best,g_ms_macd[i]):
                         MathMin(m.macd_best,g_ms_macd[i]);
      m.macd_worst=side>0?MathMin(m.macd_worst,g_ms_macd[i]):
                          MathMax(m.macd_worst,g_ms_macd[i]);

      const double signed_delta=side*g_ms_delta[i];
      m.delta_sum+=signed_delta;
      if(signed_delta>=0.0) m.delta_same_sum+=signed_delta;
      else                  m.delta_opposite_sum+=-signed_delta;

      const double weight=1.0/(double)MathMax(1,i);
      macd_direction_total+=weight;
      const bool macd_good=side>0 ?
         (g_ms_macd[i]>=g_ms_macd[MathMin(end,i+1)]) :
         (g_ms_macd[i]<=g_ms_macd[MathMin(end,i+1)]);
      if(macd_good) macd_direction_good+=weight;

      if(i<=m.recent_span)
      {
         recent_macd_total+=1.0;
         if(macd_good) recent_macd_good+=1.0;
         if(signed_delta>=0.0) recent_delta_same_sum+=signed_delta;
         else                  recent_delta_opp_sum+=-signed_delta;
      }

      // Compare the recent half of the current Leg with its older half.
      // The split is derived from the Leg length itself, not a fixed bar count.
      if(i<=MathMax(1,end/2))
      {
         recent_same_delta+=MathMax(0.0,signed_delta);
         recent_opp_delta+=MathMax(0.0,-signed_delta);
         recent_n++;
      }
      else
      {
         older_same_delta+=MathMax(0.0,signed_delta);
         older_opp_delta+=MathMax(0.0,-signed_delta);
         older_n++;
      }
   }

   m.macd_direction_ratio=macd_direction_total>0.0?
      macd_direction_good/macd_direction_total:0.0;

   const double delta_total=m.delta_same_sum+m.delta_opposite_sum;
   m.delta_direction_ratio=delta_total>0.0?
      m.delta_same_sum/delta_total:0.5;

   m.recent_macd_direction_ratio=recent_macd_total>0.0?
      recent_macd_good/recent_macd_total:0.5;
   const double recent_delta_total=
      recent_delta_same_sum+recent_delta_opp_sum;
   m.recent_delta_direction_ratio=recent_delta_total>0.0?
      recent_delta_same_sum/recent_delta_total:0.5;

   const double recent_same_avg=recent_same_delta/MathMax(1,recent_n);
   const double older_same_avg=older_same_delta/MathMax(1,older_n);
   const double recent_opp_avg=recent_opp_delta/MathMax(1,recent_n);
   const double older_opp_avg=older_opp_delta/MathMax(1,older_n);

   m.ma_spread_now=side*(g_ms_fast_ma[1]-g_ms_slow_ma[1]);
   m.ma_spread_start=side*(g_ms_fast_ma[end]-g_ms_slow_ma[end]);
   m.ma_fast_slope=side*(g_ms_fast_ma[1]-g_ms_fast_ma[end])/
      (double)MathMax(1,end-1);
   m.ma_slow_slope=side*(g_ms_slow_ma[1]-g_ms_slow_ma[end])/
      (double)MathMax(1,end-1);

   const double segment_range=MathMax(m.segment_high-m.segment_low,_Point);
   const double directional_progress=side*(m.price_now-m.price_start);
   m.progress_ratio=directional_progress/segment_range;

   // MACD: support is either same-side location or a clear recovery through
   // the current Leg. Fading means the Leg made progress but MACD surrendered
   // a meaningful portion of its own directional extreme.
   const bool macd_same_side=side*m.macd_now>0.0;
   const bool macd_improving=side*(m.macd_now-m.macd_start)>0.0 &&
                             m.macd_direction_ratio>=0.50;
   m.macd_support=macd_same_side || macd_improving;

   const double macd_excursion=MathAbs(m.macd_best-m.macd_worst);
   const double macd_from_best=MathAbs(m.macd_best-m.macd_now);
   m.macd_fading=m.macd_support && macd_excursion>0.0 &&
      macd_from_best/macd_excursion>0.50 &&
      side*(m.macd_now-m.macd_start)<=0.0;

   m.macd_opposite_expansion=side*m.macd_now<0.0 &&
      side*(m.macd_now-m.macd_start)<0.0 &&
      m.macd_direction_ratio<0.50;

   // Delta: use participation across the whole Leg plus whether recent pressure
   // is strengthening or being replaced by opposite participation.
   m.delta_support=m.delta_direction_ratio>=0.55 ||
      (m.delta_sum>0.0 && recent_same_avg>=older_same_avg);
   m.delta_fading=m.delta_support &&
      older_n>0 && recent_same_avg<older_same_avg &&
      recent_opp_avg>older_opp_avg;
   m.delta_opposite_pressure=m.delta_direction_ratio<0.45 &&
      recent_opp_avg>=older_opp_avg;

   // MA7/22 form the structural spine.
   m.ma_support=m.ma_spread_now>=0.0 &&
      m.ma_slow_slope>=0.0;
   m.ma_compressing=!m.ma_reversed &&
      m.ma_spread_now>=0.0 &&
      m.ma_spread_now<m.ma_spread_start &&
      m.ma_fast_slope<m.ma_slow_slope;
   m.ma_reversed=m.ma_spread_now<0.0 &&
      m.ma_fast_slope<0.0 &&
      m.ma_slow_slope<=0.0;

   // Price: interpret the whole Leg. A pullback is allowed while MA22 structure
   // is preserved; reversal requires both adverse location and adverse progress.
   const bool above_slow=side>0 ? m.price_now>=g_ms_slow_ma[1]
                                : m.price_now<=g_ms_slow_ma[1];
   const bool above_fast=side>0 ? m.price_now>=g_ms_fast_ma[1]
                                : m.price_now<=g_ms_fast_ma[1];
   m.price_support=directional_progress>=0.0 && above_slow;
   m.price_pullback=!above_fast && above_slow && directional_progress>=0.0;
   m.price_reversal=!above_slow && directional_progress<0.0;

   // Recent deterioration overlay. Keep the full Dynamic Leg as context,
   // but compare the newest Leg portion with the position direction.
   // This is deliberately NOT a direct failure/exit rule.
   const double giveback_from_extreme=side>0 ?
      (m.segment_high-m.price_now) :
      (m.price_now-m.segment_low);
   m.extreme_giveback_ratio=MathMax(0.0,
      MathMin(1.5,giveback_from_extreme/segment_range));

   // Recent MACD reversal requires the newest dynamic sub-region to be
   // predominantly moving against the held side AND current MACD to have
   // deteriorated versus the sub-region's older edge.
   const int recent_edge=MathMin(end,MathMax(2,m.recent_span));
   m.recent_macd_reversal=
      m.recent_macd_direction_ratio<0.40 &&
      side*(g_ms_macd[1]-g_ms_macd[recent_edge])<0.0;

   // Recent Delta must actually be opposite-dominant. The old full-Leg Delta
   // may remain supportive, but it can no longer by itself preserve STRONG.
   m.recent_delta_reversal=
      m.recent_delta_direction_ratio<0.45 &&
      recent_delta_opp_sum>recent_delta_same_sum &&
      recent_opp_avg>=older_opp_avg;

   // Price reversal requires meaningful giveback from the Leg extreme plus
   // loss of the fast-MA side. Crossing MA22 remains a stronger existing
   // direct structural condition, so this recent signal only caps HOLD state.
   m.recent_price_reversal=
      m.extreme_giveback_ratio>=0.50 &&
      !above_fast;

   m.recent_deterioration_count=
      (m.recent_macd_reversal?1:0)+
      (m.recent_delta_reversal?1:0)+
      (m.recent_price_reversal?1:0);

   return true;
}

bool BuildRangeLayerAnchoredSegmentMetrics(const int side,
                                           const int entry_shift,
                                           JTA_HoldSegmentMetrics &m)
{
   ZeroMemory(m);
   if(side==0)
      return false;

   // v5.97: load enough history for indicators, but the metric endpoint is
   // the layer's own entry bar. Never move the layer start to a later common
   // structural boundary shared by INITIAL/ADD1/ADD2.
   const int anchor=MathMax(1,MathMin(63,entry_shift));
   const int requested=MathMax(8,MathMin(64,anchor+2));
   if(!EnsureMarketSnapshot(requested))
      return false;

   const int loaded=MathMin(g_market_snapshot.loaded_count,requested);
   if(loaded<3 || anchor>=loaded)
      return false;

   const int end=anchor;
   m.span=MathMax(1,end);
   m.price_now=g_ms_rates[1].close;
   m.price_start=g_ms_rates[end].close;
   m.macd_now=g_ms_macd[1];
   m.macd_start=g_ms_macd[end];

   m.segment_high=g_ms_rates[1].high;
   m.segment_low=g_ms_rates[1].low;
   m.macd_best=g_ms_macd[1];
   m.macd_worst=g_ms_macd[1];

   double macd_direction_total=0.0;
   double macd_direction_good=0.0;
   double recent_same_delta=0.0;
   double older_same_delta=0.0;
   double recent_opp_delta=0.0;
   double older_opp_delta=0.0;
   int recent_n=0,older_n=0;

   // Recent window follows the Leg itself instead of a fixed 1-2 bar rule.
   // About the newest third of the current Leg is enough to represent current
   // deterioration while still filtering single-bar RANGE noise.
   m.recent_span=MathMax(2,MathMin(end,(end+2)/3));
   double recent_macd_total=0.0;
   double recent_macd_good=0.0;
   double recent_delta_same_sum=0.0;
   double recent_delta_opp_sum=0.0;

   for(int i=1;i<=end;i++)
   {
      m.segment_high=MathMax(m.segment_high,g_ms_rates[i].high);
      m.segment_low=MathMin(m.segment_low,g_ms_rates[i].low);
      m.macd_best=side>0?MathMax(m.macd_best,g_ms_macd[i]):
                         MathMin(m.macd_best,g_ms_macd[i]);
      m.macd_worst=side>0?MathMin(m.macd_worst,g_ms_macd[i]):
                          MathMax(m.macd_worst,g_ms_macd[i]);

      const double signed_delta=side*g_ms_delta[i];
      m.delta_sum+=signed_delta;
      if(signed_delta>=0.0) m.delta_same_sum+=signed_delta;
      else                  m.delta_opposite_sum+=-signed_delta;

      const double weight=1.0/(double)MathMax(1,i);
      macd_direction_total+=weight;
      const bool macd_good=side>0 ?
         (g_ms_macd[i]>=g_ms_macd[MathMin(end,i+1)]) :
         (g_ms_macd[i]<=g_ms_macd[MathMin(end,i+1)]);
      if(macd_good) macd_direction_good+=weight;

      if(i<=m.recent_span)
      {
         recent_macd_total+=1.0;
         if(macd_good) recent_macd_good+=1.0;
         if(signed_delta>=0.0) recent_delta_same_sum+=signed_delta;
         else                  recent_delta_opp_sum+=-signed_delta;
      }

      // Compare the recent half of the current Leg with its older half.
      // The split is derived from the Leg length itself, not a fixed bar count.
      if(i<=MathMax(1,end/2))
      {
         recent_same_delta+=MathMax(0.0,signed_delta);
         recent_opp_delta+=MathMax(0.0,-signed_delta);
         recent_n++;
      }
      else
      {
         older_same_delta+=MathMax(0.0,signed_delta);
         older_opp_delta+=MathMax(0.0,-signed_delta);
         older_n++;
      }
   }

   m.macd_direction_ratio=macd_direction_total>0.0?
      macd_direction_good/macd_direction_total:0.0;

   const double delta_total=m.delta_same_sum+m.delta_opposite_sum;
   m.delta_direction_ratio=delta_total>0.0?
      m.delta_same_sum/delta_total:0.5;

   m.recent_macd_direction_ratio=recent_macd_total>0.0?
      recent_macd_good/recent_macd_total:0.5;
   const double recent_delta_total=
      recent_delta_same_sum+recent_delta_opp_sum;
   m.recent_delta_direction_ratio=recent_delta_total>0.0?
      recent_delta_same_sum/recent_delta_total:0.5;

   const double recent_same_avg=recent_same_delta/MathMax(1,recent_n);
   const double older_same_avg=older_same_delta/MathMax(1,older_n);
   const double recent_opp_avg=recent_opp_delta/MathMax(1,recent_n);
   const double older_opp_avg=older_opp_delta/MathMax(1,older_n);

   m.ma_spread_now=side*(g_ms_fast_ma[1]-g_ms_slow_ma[1]);
   m.ma_spread_start=side*(g_ms_fast_ma[end]-g_ms_slow_ma[end]);
   m.ma_fast_slope=side*(g_ms_fast_ma[1]-g_ms_fast_ma[end])/
      (double)MathMax(1,end-1);
   m.ma_slow_slope=side*(g_ms_slow_ma[1]-g_ms_slow_ma[end])/
      (double)MathMax(1,end-1);

   const double segment_range=MathMax(m.segment_high-m.segment_low,_Point);
   const double directional_progress=side*(m.price_now-m.price_start);
   m.progress_ratio=directional_progress/segment_range;

   // MACD: support is either same-side location or a clear recovery through
   // the current Leg. Fading means the Leg made progress but MACD surrendered
   // a meaningful portion of its own directional extreme.
   const bool macd_same_side=side*m.macd_now>0.0;
   const bool macd_improving=side*(m.macd_now-m.macd_start)>0.0 &&
                             m.macd_direction_ratio>=0.50;
   m.macd_support=macd_same_side || macd_improving;

   const double macd_excursion=MathAbs(m.macd_best-m.macd_worst);
   const double macd_from_best=MathAbs(m.macd_best-m.macd_now);
   m.macd_fading=m.macd_support && macd_excursion>0.0 &&
      macd_from_best/macd_excursion>0.50 &&
      side*(m.macd_now-m.macd_start)<=0.0;

   m.macd_opposite_expansion=side*m.macd_now<0.0 &&
      side*(m.macd_now-m.macd_start)<0.0 &&
      m.macd_direction_ratio<0.50;

   // Delta: use participation across the whole Leg plus whether recent pressure
   // is strengthening or being replaced by opposite participation.
   m.delta_support=m.delta_direction_ratio>=0.55 ||
      (m.delta_sum>0.0 && recent_same_avg>=older_same_avg);
   m.delta_fading=m.delta_support &&
      older_n>0 && recent_same_avg<older_same_avg &&
      recent_opp_avg>older_opp_avg;
   m.delta_opposite_pressure=m.delta_direction_ratio<0.45 &&
      recent_opp_avg>=older_opp_avg;

   // MA7/22 form the structural spine.
   m.ma_support=m.ma_spread_now>=0.0 &&
      m.ma_slow_slope>=0.0;
   m.ma_compressing=!m.ma_reversed &&
      m.ma_spread_now>=0.0 &&
      m.ma_spread_now<m.ma_spread_start &&
      m.ma_fast_slope<m.ma_slow_slope;
   m.ma_reversed=m.ma_spread_now<0.0 &&
      m.ma_fast_slope<0.0 &&
      m.ma_slow_slope<=0.0;

   // Price: interpret the whole Leg. A pullback is allowed while MA22 structure
   // is preserved; reversal requires both adverse location and adverse progress.
   const bool above_slow=side>0 ? m.price_now>=g_ms_slow_ma[1]
                                : m.price_now<=g_ms_slow_ma[1];
   const bool above_fast=side>0 ? m.price_now>=g_ms_fast_ma[1]
                                : m.price_now<=g_ms_fast_ma[1];
   m.price_support=directional_progress>=0.0 && above_slow;
   m.price_pullback=!above_fast && above_slow && directional_progress>=0.0;
   m.price_reversal=!above_slow && directional_progress<0.0;

   // Recent deterioration overlay. Keep the full Dynamic Leg as context,
   // but compare the newest Leg portion with the position direction.
   // This is deliberately NOT a direct failure/exit rule.
   const double giveback_from_extreme=side>0 ?
      (m.segment_high-m.price_now) :
      (m.price_now-m.segment_low);
   m.extreme_giveback_ratio=MathMax(0.0,
      MathMin(1.5,giveback_from_extreme/segment_range));

   // Recent MACD reversal requires the newest dynamic sub-region to be
   // predominantly moving against the held side AND current MACD to have
   // deteriorated versus the sub-region's older edge.
   const int recent_edge=MathMin(end,MathMax(2,m.recent_span));
   m.recent_macd_reversal=
      m.recent_macd_direction_ratio<0.40 &&
      side*(g_ms_macd[1]-g_ms_macd[recent_edge])<0.0;

   // Recent Delta must actually be opposite-dominant. The old full-Leg Delta
   // may remain supportive, but it can no longer by itself preserve STRONG.
   m.recent_delta_reversal=
      m.recent_delta_direction_ratio<0.45 &&
      recent_delta_opp_sum>recent_delta_same_sum &&
      recent_opp_avg>=older_opp_avg;

   // Price reversal requires meaningful giveback from the Leg extreme plus
   // loss of the fast-MA side. Crossing MA22 remains a stronger existing
   // direct structural condition, so this recent signal only caps HOLD state.
   m.recent_price_reversal=
      m.extreme_giveback_ratio>=0.50 &&
      !above_fast;

   m.recent_deterioration_count=
      (m.recent_macd_reversal?1:0)+
      (m.recent_delta_reversal?1:0)+
      (m.recent_price_reversal?1:0);

   return true;
}

// v6.99 shared pending-3X MACD context.
// Reuses HoldEngine's existing Dynamic-Leg MACD metrics; no new MACD engine.
int JTAGetRangeSharedMacdContext(const int side,
                                 const datetime episode_start_bar,
                                 string &detail)
{
   detail="";
   if(side==0)
   {
      detail="SIDE=0";
      return 0;
   }

   int requested=8;
   if(episode_start_bar>0)
   {
      const int start_shift=iBarShift(_Symbol,g_calc_tf,episode_start_bar,false);
      if(start_shift>=1)
         requested=MathMax(8,MathMin(64,start_shift+3));
   }

   JTA_HoldSegmentMetrics m;
   if(!BuildRangeSignalStateSegmentMetrics(side,requested,m))
   {
      detail=StringFormat("DATA_UNAVAILABLE|LOOKBACK=%d",requested);
      return 0;
   }

   const bool macd_progress=
      side*(m.macd_now-m.macd_start)>0.0 &&
      m.macd_direction_ratio>=0.50;
   const bool clear_same_direction=
      macd_progress && m.macd_support && !m.macd_fading &&
      !m.macd_opposite_expansion && !m.recent_macd_reversal;

   detail=StringFormat(
      "SPAN=%d|LOOKBACK=%d|NOW=%.6f|START=%.6f|DIR=%.3f|SUP=%d|FADE=%d|OPP=%d|REC_REV=%d|PROGRESS=%d",
      m.span,requested,m.macd_now,m.macd_start,m.macd_direction_ratio,
      m.macd_support?1:0,m.macd_fading?1:0,m.macd_opposite_expansion?1:0,
      m.recent_macd_reversal?1:0,macd_progress?1:0);

   if(m.macd_opposite_expansion) return -1;
   if(clear_same_direction) return 1;
   return 0;
}

int CalculateRangeHoldScoreFromMetrics(const int side,
                                       const double average_price,
                                       const double market_price,
                                       const JTA_HoldSegmentMetrics &m,
                                       string &detail)
{
   detail="";
   int score=0;

   // Momentum/participation: 50 points.
   if(m.macd_support) score+=20;
   if(m.macd_support && !m.macd_fading) score+=5;
   if(m.delta_support) score+=20;
   if(m.delta_support && !m.delta_fading) score+=5;

   // Structural spine: 35 points.
   if(m.ma_support) score+=20;
   if(m.ma_support && !m.ma_compressing) score+=5;
   if(m.price_support) score+=10;

   // Quality of the current Leg: 15 points.
   if(m.progress_ratio>0.0) score+=5;
   if(m.macd_direction_ratio>=0.60) score+=5;
   if(m.delta_direction_ratio>=0.60) score+=5;

   // Deterioration is a deduction, not an independent exit authority.
   if(m.macd_fading) score-=5;
   if(m.delta_fading) score-=5;
   if(m.ma_compressing) score-=5;
   if(m.price_pullback) score-=3;
   if(m.macd_opposite_expansion) score-=10;
   if(m.delta_opposite_pressure) score-=10;
   if(m.ma_reversed) score-=15;
   if(m.price_reversal) score-=10;

   // v3.68: recent deterioration is a state-cap, not a new exit engine.
   // One item is only a small penalty. Two independent recent reversals stop
   // an old Leg from remaining STRONG. All three make it a WARNING candidate
   // by capping below the existing NORMAL threshold; persistence/severity
   // rules in JoonEvaluateRangeHoldState() remain authoritative.
   if((g_position_strategy==STRATEGY_RANGE) &&
      m.recent_deterioration_count==1)
      score-=5;

   bool pattern_pullback=false,pattern_absorption=false,pattern_fatigue=false;
   bool pattern_compression=false;
   int pattern_bounces=0;
   string pattern_detail="";
   EvaluatePatternLifecycleAssist(side,pattern_pullback,pattern_absorption,
                                  pattern_fatigue,pattern_compression,
                                  pattern_bounces,pattern_detail);

   // Existing pattern logic is retained only as a small tie-breaker.
   int pattern_adjustment=0;
   if(pattern_pullback || pattern_absorption) pattern_adjustment+=3;
   if(pattern_bounces>=2) pattern_adjustment+=2;
   if(pattern_fatigue) pattern_adjustment-=5;
   pattern_adjustment=MathMax(-5,MathMin(5,pattern_adjustment));

   score=MathMax(0,MathMin(100,score+pattern_adjustment));
   g_csv_hold_score_before_cap=score;

   if((g_position_strategy==STRATEGY_RANGE) &&
      m.recent_deterioration_count>=2)
   {
      score=MathMin(score,MathMax(0,InpHoldScoreStrongThreshold-1));
      if(m.recent_deterioration_count>=3)
         score=MathMin(score,MathMax(0,InpHoldScoreTrailingThreshold-1));
   }
   g_csv_hold_score_after_cap=score;

   detail=StringFormat(
      "SEG%d | MACD SUP%d FADE%d OPP%d DIR%.2f | "
      "DELTA SUP%d FADE%d OPP%d SHARE%.2f | "
      "MA SUP%d CMP%d REV%d FAST%.5f SLOW%.5f | "
      "PRICE SUP%d PB%d REV%d PROG%.2f | "
      "RECENT%d/%d MACD%.2f DLT%.2f GB%.2f RM%d RD%d RP%d | PAT%d [%s]",
      m.span,
      m.macd_support?1:0,m.macd_fading?1:0,m.macd_opposite_expansion?1:0,
      m.macd_direction_ratio,
      m.delta_support?1:0,m.delta_fading?1:0,m.delta_opposite_pressure?1:0,
      m.delta_direction_ratio,
      m.ma_support?1:0,m.ma_compressing?1:0,m.ma_reversed?1:0,
      m.ma_fast_slope,m.ma_slow_slope,
      m.price_support?1:0,m.price_pullback?1:0,m.price_reversal?1:0,
      m.progress_ratio,
      m.recent_deterioration_count,m.recent_span,
      m.recent_macd_direction_ratio,m.recent_delta_direction_ratio,
      m.extreme_giveback_ratio,
      m.recent_macd_reversal?1:0,
      m.recent_delta_reversal?1:0,
      m.recent_price_reversal?1:0,
      pattern_adjustment,pattern_detail);
   return score;
}

// v5.97 diagnostic-only score. Mirrors the RANGE HoldEngine score without
// touching canonical HOLD CSV/runtime fields or state-machine persistence.
int CalculateRangeSignalStateScoreFromMetrics(const int side,
                                             const JTA_HoldSegmentMetrics &m,
                                             string &detail)
{
   detail="";
   int score=0;

   // Momentum/participation: 50 points.
   if(m.macd_support) score+=20;
   if(m.macd_support && !m.macd_fading) score+=5;
   if(m.delta_support) score+=20;
   if(m.delta_support && !m.delta_fading) score+=5;

   // Structural spine: 35 points.
   if(m.ma_support) score+=20;
   if(m.ma_support && !m.ma_compressing) score+=5;
   if(m.price_support) score+=10;

   // Quality of the current Leg: 15 points.
   if(m.progress_ratio>0.0) score+=5;
   if(m.macd_direction_ratio>=0.60) score+=5;
   if(m.delta_direction_ratio>=0.60) score+=5;

   // Deterioration is a deduction, not an independent exit authority.
   if(m.macd_fading) score-=5;
   if(m.delta_fading) score-=5;
   if(m.ma_compressing) score-=5;
   if(m.price_pullback) score-=3;
   if(m.macd_opposite_expansion) score-=10;
   if(m.delta_opposite_pressure) score-=10;
   if(m.ma_reversed) score-=15;
   if(m.price_reversal) score-=10;

   // v3.68: recent deterioration is a state-cap, not a new exit engine.
   // One item is only a small penalty. Two independent recent reversals stop
   // an old Leg from remaining STRONG. All three make it a WARNING candidate
   // by capping below the existing NORMAL threshold; persistence/severity
   // rules in JoonEvaluateRangeHoldState() remain authoritative.
   if(m.recent_deterioration_count==1)
      score-=5;

   bool pattern_pullback=false,pattern_absorption=false,pattern_fatigue=false;
   bool pattern_compression=false;
   int pattern_bounces=0;
   string pattern_detail="";
   EvaluatePatternLifecycleAssist(side,pattern_pullback,pattern_absorption,
                                  pattern_fatigue,pattern_compression,
                                  pattern_bounces,pattern_detail);

   // Existing pattern logic is retained only as a small tie-breaker.
   int pattern_adjustment=0;
   if(pattern_pullback || pattern_absorption) pattern_adjustment+=3;
   if(pattern_bounces>=2) pattern_adjustment+=2;
   if(pattern_fatigue) pattern_adjustment-=5;
   pattern_adjustment=MathMax(-5,MathMin(5,pattern_adjustment));

   score=MathMax(0,MathMin(100,score+pattern_adjustment));

   if(m.recent_deterioration_count>=2)
   {
      score=MathMin(score,MathMax(0,InpHoldScoreStrongThreshold-1));
      if(m.recent_deterioration_count>=3)
         score=MathMin(score,MathMax(0,InpHoldScoreTrailingThreshold-1));
   }

   detail=StringFormat(
      "SEG%d | MACD SUP%d FADE%d OPP%d DIR%.2f | "
      "DELTA SUP%d FADE%d OPP%d SHARE%.2f | "
      "MA SUP%d CMP%d REV%d FAST%.5f SLOW%.5f | "
      "PRICE SUP%d PB%d REV%d PROG%.2f | "
      "RECENT%d/%d MACD%.2f DLT%.2f GB%.2f RM%d RD%d RP%d | PAT%d [%s]",
      m.span,
      m.macd_support?1:0,m.macd_fading?1:0,m.macd_opposite_expansion?1:0,
      m.macd_direction_ratio,
      m.delta_support?1:0,m.delta_fading?1:0,m.delta_opposite_pressure?1:0,
      m.delta_direction_ratio,
      m.ma_support?1:0,m.ma_compressing?1:0,m.ma_reversed?1:0,
      m.ma_fast_slope,m.ma_slow_slope,
      m.price_support?1:0,m.price_pullback?1:0,m.price_reversal?1:0,
      m.progress_ratio,
      m.recent_deterioration_count,m.recent_span,
      m.recent_macd_direction_ratio,m.recent_delta_direction_ratio,
      m.extreme_giveback_ratio,
      m.recent_macd_reversal?1:0,
      m.recent_delta_reversal?1:0,
      m.recent_price_reversal?1:0,
      pattern_adjustment,pattern_detail);
   return score;
}

string RangeSignalStateSnapshotName(const int score,
                                    const int aligned_count,
                                    const int failure_count,
                                    const int weakness_score)
{
   if(failure_count>=3)
      return "INVALID";

   const bool structural_warning=
      weakness_score>=30 &&
      (score<InpHoldScoreTrailingThreshold || aligned_count<=1 || failure_count>=1);
   if(structural_warning || failure_count>=2)
      return "WARNING";

   if(score>=InpHoldScoreStrongThreshold && aligned_count==3 && failure_count==0)
      return "STRONG";

   if(score>=InpHoldScoreTrailingThreshold && aligned_count>=2 && failure_count<2)
      return "NORMAL";

   return "WARNING";
}

// v5.97 diagnostic-only snapshot used at RANGE INITIAL FINAL #2/#3 and
// RANGE ADD FINAL #1/#2. It has no order authority and never mutates the
// canonical HoldEngine runtime, g_hold_state, entry counters, or position state.
bool WriteRangeSignalStateSnapshot(const string event_name,
                                   const string event_id,
                                   const string stage,
                                   const int side,
                                   const int signal_count,
                                   const datetime episode_start_bar,
                                   const ulong position_id)
{
   if(side==0 || signal_count<=0)
      return false;

   int requested=8;
   if(episode_start_bar>0)
   {
      const int start_shift=iBarShift(_Symbol,g_calc_tf,episode_start_bar,false);
      if(start_shift>=1)
         requested=MathMax(8,MathMin(64,start_shift+3));
   }

   JTA_HoldSegmentMetrics m;
   if(!BuildRangeSignalStateSegmentMetrics(side,requested,m))
   {
      WriteUnifiedOrderSignalAudit(event_name,event_id,stage,side,
         MathMax(0,signal_count-1),signal_count,"DATA_UNAVAILABLE",
         StringFormat("LOOKBACK=%d|ORDER_AUTHORITY=NO",requested),
         false,false,0,position_id);
      return false;
   }

   string score_detail="";
   const int score=CalculateRangeSignalStateScoreFromMetrics(side,m,score_detail);
   const bool macd_aligned=m.macd_support && !m.macd_opposite_expansion;
   const bool delta_aligned=m.delta_support && !m.delta_opposite_pressure;
   const bool ma_aligned=m.ma_support && !m.ma_reversed;
   const int aligned_count=(macd_aligned?1:0)+(delta_aligned?1:0)+(ma_aligned?1:0);
   const int failure_count=(m.macd_opposite_expansion?1:0)+
                           (m.delta_opposite_pressure?1:0)+
                           ((m.ma_reversed && m.price_reversal)?1:0);

   int deterioration=0;
   if(m.macd_fading) deterioration+=10;
   if(m.delta_fading) deterioration+=10;
   if(m.ma_compressing) deterioration+=10;
   if(m.price_pullback) deterioration+=5;
   deterioration+=m.recent_deterioration_count*10;
   const int weakness_score=MathMin(100,
      failure_count*25+deterioration+
      (!macd_aligned?5:0)+(!delta_aligned?5:0)+(!ma_aligned?5:0));

   const string state=RangeSignalStateSnapshotName(
      score,aligned_count,failure_count,weakness_score);

   const string detail=StringFormat(
      "STATE=%s|SCORE=%d|ALIGN=%d|FAIL=%d|WEAK=%d|SPAN=%d|LOOKBACK=%d|"
      "MACD_SUP=%d|MACD_FADE=%d|MACD_OPP=%d|MACD_DIR=%.3f|"
      "DELTA_SUP=%d|DELTA_FADE=%d|DELTA_OPP=%d|DELTA_DIR=%.3f|"
      "MA_SUP=%d|MA_CMP=%d|MA_REV=%d|PRICE_SUP=%d|PRICE_PB=%d|PRICE_REV=%d|"
      "PROGRESS=%.3f|RECENT=%d|RECENT_MACD=%.3f|RECENT_DELTA=%.3f|GIVEBACK=%.3f|"
      "ORDER_AUTHORITY=NO",
      state,score,aligned_count,failure_count,weakness_score,m.span,requested,
      m.macd_support?1:0,m.macd_fading?1:0,m.macd_opposite_expansion?1:0,m.macd_direction_ratio,
      m.delta_support?1:0,m.delta_fading?1:0,m.delta_opposite_pressure?1:0,m.delta_direction_ratio,
      m.ma_support?1:0,m.ma_compressing?1:0,m.ma_reversed?1:0,
      m.price_support?1:0,m.price_pullback?1:0,m.price_reversal?1:0,
      m.progress_ratio,m.recent_deterioration_count,m.recent_macd_direction_ratio,
      m.recent_delta_direction_ratio,m.extreme_giveback_ratio);

   WriteUnifiedOrderSignalAudit(event_name,event_id,stage,side,
      MathMax(0,signal_count-1),signal_count,state,detail,
      false,false,0,position_id);
   return true;
}


//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
bool ShouldHoldRangePosition(const int side,string &detail)
{
   detail="";
   if(!InpUseRangeSimpleHold ||
      g_position_strategy!=STRATEGY_RANGE ||
      side==0 ||
      BarsSinceInitialEntry()<InpRangeSimpleHoldMinimumBars)
      return false;

   JTA_HoldSegmentMetrics m;
   if(!BuildHoldSegmentMetrics(side,m))
   {
      detail="SEGMENT DATA UNAVAILABLE";
      return false;
   }

   const int supports=(m.macd_support?1:0)+(m.delta_support?1:0)+
                      (m.ma_support?1:0)+(m.price_support?1:0);
   const int reversals=(m.macd_opposite_expansion?1:0)+
                       (m.delta_opposite_pressure?1:0)+
                       (m.ma_reversed?1:0)+(m.price_reversal?1:0);

   detail=StringFormat("SEG%d SUPPORT %d/4 REV %d/4 | MACD %.2f DELTA %.2f MA %.5f",
      m.span,supports,reversals,m.macd_direction_ratio,
      m.delta_direction_ratio,m.ma_spread_now);

   return supports>=3 && reversals<=1;
}


bool ReadRangeHoldEvidence(const int side,
                           const double average_price,
                           JoonRangeHoldEvidence &evidence,
                           string &detail)
{
   ZeroMemory(evidence);
   detail="";
   if(average_price<=0.0)
      return false;

   JTA_HoldSegmentMetrics m;
   if(!BuildHoldSegmentMetrics(side,m))
      return false;

   // v3.68 single-metrics rule: score and evidence consume the exact same
   // Dynamic Segment snapshot. This removes the previous second segment-metrics
   // reconstruction pass from one canonical Hold evaluation.
   g_csv_hold_recent_count=m.recent_deterioration_count;
   g_csv_hold_recent_span=m.recent_span;
   g_csv_hold_recent_macd_ratio=m.recent_macd_direction_ratio;
   g_csv_hold_recent_delta_ratio=m.recent_delta_direction_ratio;
   g_csv_hold_extreme_giveback_ratio=m.extreme_giveback_ratio;
   g_csv_hold_recent_macd_reverse=m.recent_macd_reversal;
   g_csv_hold_recent_delta_reverse=m.recent_delta_reversal;
   g_csv_hold_recent_price_reverse=m.recent_price_reversal;

   evidence.score=CalculateRangeHoldScoreFromMetrics(
      side,average_price,m.price_now,m,detail);

   // Keep the public evidence structure unchanged. These booleans now mean
   // "the current Leg still supports the position", not "bar[1] has this sign".
   evidence.macd_aligned=m.macd_support && !m.macd_opposite_expansion;
   evidence.delta_aligned=m.delta_support && !m.delta_opposite_pressure;
   evidence.ma7_aligned=m.ma_support && !m.ma_reversed;

   // Direct failure requires a genuine opposite Leg condition.
   evidence.opposite_macd=m.macd_opposite_expansion;
   evidence.opposite_delta=m.delta_opposite_pressure;
   evidence.ma_cross_failed=m.ma_reversed && m.price_reversal;

   evidence.profitable=side>0 ? m.price_now>average_price
                              : m.price_now<average_price;

   g_hold_direction_score=evidence.score;
   g_hold_strong_score=MathMax(0,MathMin(100,evidence.score));

   const int range_failure_count=
      (evidence.opposite_macd?1:0)+
      (evidence.opposite_delta?1:0)+
      (evidence.ma_cross_failed?1:0);

   int deterioration=0;
   if(m.macd_fading) deterioration+=10;
   if(m.delta_fading) deterioration+=10;
   if(m.ma_compressing) deterioration+=10;
   if(m.price_pullback) deterioration+=5;
   if(g_position_strategy==STRATEGY_RANGE)
      deterioration+=m.recent_deterioration_count*10;

   g_hold_weakness_score=MathMin(100,
      range_failure_count*25+deterioration+
      (!evidence.macd_aligned?5:0)+
      (!evidence.delta_aligned?5:0)+
      (!evidence.ma7_aligned?5:0));

   return true;
}


// v5.97 RANGE per-layer HoldEngine.
// The canonical group HoldEngine remains available for legacy diagnostics/risk
// consumers, but each virtual layer now owns its own Dynamic-Leg runtime.

string JTAHoldAnchorKey(const string layer)
{
   return StringFormat("JTA.HA.%I64u.%s.%s",
      (ulong)InpMagicNumber,_Symbol,layer);
}

void JTAHoldAnchorSave()
{
   if(g_initial_entry_time<=0)
      return;
   GlobalVariableSet(JTAHoldAnchorKey("CYCLE"),(double)g_initial_entry_time);
   GlobalVariableSet(JTAHoldAnchorKey("INITIAL"),(double)g_initial_hold_anchor_time);
   GlobalVariableSet(JTAHoldAnchorKey("ADD1"),(double)g_add1_hold_anchor_time);
   GlobalVariableSet(JTAHoldAnchorKey("ADD2"),(double)g_add2_hold_anchor_time);
}

void JTAHoldAnchorLoad(const datetime initial_time)
{
   if(initial_time<=0)
      return;
   const string cycle_key=JTAHoldAnchorKey("CYCLE");
   if(!GlobalVariableCheck(cycle_key))
      return;
   const datetime saved_cycle=(datetime)MathRound(GlobalVariableGet(cycle_key));
   if(saved_cycle!=initial_time)
      return;

   const string i_key=JTAHoldAnchorKey("INITIAL");
   const string a1_key=JTAHoldAnchorKey("ADD1");
   const string a2_key=JTAHoldAnchorKey("ADD2");
   if(GlobalVariableCheck(i_key))
      g_initial_hold_anchor_time=(datetime)MathRound(GlobalVariableGet(i_key));
   if(GlobalVariableCheck(a1_key))
      g_add1_hold_anchor_time=(datetime)MathRound(GlobalVariableGet(a1_key));
   if(GlobalVariableCheck(a2_key))
      g_add2_hold_anchor_time=(datetime)MathRound(GlobalVariableGet(a2_key));
}

void JTAHoldAnchorClear()
{
   const string keys[4]={
      JTAHoldAnchorKey("CYCLE"),
      JTAHoldAnchorKey("INITIAL"),
      JTAHoldAnchorKey("ADD1"),
      JTAHoldAnchorKey("ADD2")
   };
   for(int i=0;i<4;i++)
      if(GlobalVariableCheck(keys[i]))
         GlobalVariableDel(keys[i]);
}

void ResetRangeLayerHoldStates()
{
   JoonResetRangeHoldRuntime(g_initial_layer_hold_runtime);
   JoonResetRangeHoldRuntime(g_add1_layer_hold_runtime);
   JoonResetRangeHoldRuntime(g_add2_layer_hold_runtime);

   g_initial_layer_hold_state=JOON_RANGE_HOLD_NORMAL;
   g_add1_layer_hold_state=JOON_RANGE_HOLD_NORMAL;
   g_add2_layer_hold_state=JOON_RANGE_HOLD_NORMAL;

   g_initial_layer_hold_ready=false;
   g_add1_layer_hold_ready=false;
   g_add2_layer_hold_ready=false;

   g_initial_layer_hold_tracked_time=0;
   g_add1_layer_hold_tracked_time=0;
   g_add2_layer_hold_tracked_time=0;
}

bool BuildRangeLayerHoldEvidence(const int side,
                                 const double entry_price,
                                 const datetime entry_time,
                                 JoonRangeHoldEvidence &evidence,
                                 int &weakness_score,
                                 string &detail)
{
   ZeroMemory(evidence);
   weakness_score=0;
   detail="";
   if(side==0 || entry_price<=0.0 || entry_time<=0)
      return false;

   const ENUM_TIMEFRAMES management_tf=ActiveManagementTF();
   int shift=iBarShift(_Symbol,management_tf,entry_time,false);
   if(shift<1)
      shift=1;

   JTA_HoldSegmentMetrics m;
   if(!BuildRangeLayerAnchoredSegmentMetrics(side,shift,m))
      return false;

   string score_detail="";
   evidence.score=CalculateRangeSignalStateScoreFromMetrics(
      side,m,score_detail);
   evidence.macd_aligned=m.macd_support && !m.macd_opposite_expansion;
   evidence.delta_aligned=m.delta_support && !m.delta_opposite_pressure;
   evidence.ma7_aligned=m.ma_support && !m.ma_reversed;
   evidence.opposite_macd=m.macd_opposite_expansion;
   evidence.opposite_delta=m.delta_opposite_pressure;
   evidence.ma_cross_failed=m.ma_reversed && m.price_reversal;
   evidence.profitable=side>0 ? m.price_now>entry_price
                              : m.price_now<entry_price;

   const int failure_count=
      (evidence.opposite_macd?1:0)+
      (evidence.opposite_delta?1:0)+
      (evidence.ma_cross_failed?1:0);

   int deterioration=0;
   if(m.macd_fading) deterioration+=10;
   if(m.delta_fading) deterioration+=10;
   if(m.ma_compressing) deterioration+=10;
   if(m.price_pullback) deterioration+=5;
   deterioration+=m.recent_deterioration_count*10;

   weakness_score=MathMin(100,
      failure_count*25+deterioration+
      (!evidence.macd_aligned?5:0)+
      (!evidence.delta_aligned?5:0)+
      (!evidence.ma7_aligned?5:0));

   detail=StringFormat(
      "ENTRY %.*f HOLD_ANCHOR %s | WEAK %d | %s",
      _Digits,entry_price,
      TimeToString(entry_time,TIME_DATE|TIME_MINUTES),
      weakness_score,score_detail);
   return true;
}

// Independent runtime version of the RANGE state machine.
// Do not use the canonical evaluator here because its legacy rolling warning
// window is shared. Each layer must keep its own warning history.
ENUM_JOON_RANGE_HOLD_STATE JoonEvaluateRangeLayerHoldState(
   const JoonRangeHoldConfig &config,
   const JoonRangeHoldEvidence &evidence,
   const int weakness_score,
   const datetime closed_bar_time,
   JoonRangeHoldRuntime &runtime)
{
   const bool new_closed_bar=
      closed_bar_time>0 && closed_bar_time!=runtime.last_closed_bar;

   const int aligned_count=(evidence.macd_aligned?1:0)+
                           (evidence.delta_aligned?1:0)+
                           (evidence.ma7_aligned?1:0);
   const int failure_count=(evidence.opposite_macd?1:0)+
                           (evidence.opposite_delta?1:0)+
                           (evidence.ma_cross_failed?1:0);

   const bool weak_evidence=
      evidence.score<config.normal_score ||
      aligned_count<=1 ||
      failure_count>=2;
   const bool strong_evidence=
      evidence.score>=config.strong_score &&
      aligned_count==3 && failure_count==0;
   const bool structural_warning=
      weakness_score>=30 &&
      (evidence.score<config.normal_score ||
       aligned_count<=1 || failure_count>=1);

   const bool immediate_exit=failure_count>=3;
   const bool moderate_exit=failure_count==2;

   const int warning_window=MathMax(1,MathMin(63,
      config.warning_confirm_bars));

   if(runtime.last_closed_bar==0)
   {
      runtime.warning_window_bits=0;
      runtime.warning_window_samples=0;
      runtime.warning_bars=0;
      runtime.failure_bars=0;
      runtime.strong_candidate_bars=0;
      runtime.warning_state_bars=0;
      runtime.state=JOON_RANGE_HOLD_NORMAL;
   }

   if(new_closed_bar)
   {
      runtime.last_closed_bar=closed_bar_time;
      runtime.warning_window_bits=
         ((runtime.warning_window_bits<<1) |
          (weak_evidence?(ulong)1:(ulong)0)) &
         JoonRangeHoldWindowMask(warning_window);
      runtime.warning_window_samples=
         MathMin(warning_window,runtime.warning_window_samples+1);
      runtime.warning_bars=
         JoonRangeHoldCountWindowBits(runtime.warning_window_bits);

      runtime.failure_bars=moderate_exit ?
         runtime.failure_bars+1 : 0;
      runtime.strong_candidate_bars=strong_evidence ?
         runtime.strong_candidate_bars+1 : 0;
   }

   const bool persistent_moderate_exit=
      moderate_exit && runtime.failure_bars>=2;

   if(immediate_exit || persistent_moderate_exit)
      runtime.state=JOON_RANGE_HOLD_EXIT;
   else if(structural_warning)
      runtime.state=JOON_RANGE_HOLD_WARNING;
   else if(strong_evidence && runtime.strong_candidate_bars>=2)
      runtime.state=JOON_RANGE_HOLD_STRONG;
   else if(evidence.score>=config.normal_score &&
           aligned_count>=2 && failure_count<2)
      runtime.state=JOON_RANGE_HOLD_NORMAL;
   else if(runtime.state==JOON_RANGE_HOLD_EXIT ||
           runtime.state==JOON_RANGE_HOLD_WARNING)
      runtime.state=JOON_RANGE_HOLD_NORMAL;

   if(new_closed_bar)
   {
      if(runtime.state==JOON_RANGE_HOLD_WARNING)
         runtime.warning_state_bars++;
      else
         runtime.warning_state_bars=0;
   }

   return runtime.state;
}

bool EvaluateOneRangeLayerHold(const string layer_name,
                               const int side,
                               const double entry_price,
                               const datetime entry_time,
                               JoonRangeHoldRuntime &runtime,
                               datetime &tracked_time,
                               ENUM_JOON_RANGE_HOLD_STATE &state,
                               bool &ready)
{
   if(entry_price<=0.0 || entry_time<=0)
   {
      if(tracked_time!=0 || ready)
         JoonResetRangeHoldRuntime(runtime);
      tracked_time=0;
      state=JOON_RANGE_HOLD_NORMAL;
      ready=false;
      return false;
   }

   if(tracked_time!=entry_time)
   {
      JoonResetRangeHoldRuntime(runtime);
      runtime.warning_window_bits=0;
      runtime.warning_window_samples=0;
      tracked_time=entry_time;
      state=JOON_RANGE_HOLD_NORMAL;
      ready=false;
   }

   const datetime closed_bar=iTime(_Symbol,ActiveManagementTF(),1);
   // v6.18: layer evidence uses completed-bar market snapshots only. Once this
   // layer has been evaluated for the current management bar, reuse the state
   // until a new bar or a new layer fill resets the runtime.
   if(ready && closed_bar>0 && runtime.last_closed_bar==closed_bar)
      return true;

   JoonRangeHoldEvidence evidence;
   int weakness_score=0;
   string detail="";
   if(!BuildRangeLayerHoldEvidence(
         side,entry_price,entry_time,evidence,weakness_score,detail))
   {
      ready=false;
      return false;
   }

   JoonRangeHoldConfig config;
   config.strong_score=InpHoldScoreStrongThreshold;
   config.normal_score=InpHoldScoreTrailingThreshold;
   config.warning_confirm_bars=MathMax(1,
      InpUseFastSimpleEngine ? InpHoldWarningConfirmBars :
                               InpRangeWeaknessConfirmBars);
   config.exit_confirm_bars=MathMax(1,InpHoldExitCandidateConfirmBars);

   const ENUM_JOON_RANGE_HOLD_STATE previous=state;
   state=JoonEvaluateRangeLayerHoldState(
      config,evidence,weakness_score,
      iTime(_Symbol,ActiveManagementTF(),1),runtime);
   ready=true;

   static datetime last_initial_log=0;
   static datetime last_add1_log=0;
   static datetime last_add2_log=0;
   datetime last_log=layer_name=="INITIAL" ? last_initial_log :
                     layer_name=="ADD1" ? last_add1_log : last_add2_log;
   if(closed_bar>0 && closed_bar!=last_log)
   {
      WriteUnifiedOrderSignalAudit(
         "LAYER_HOLD_STATE","",layer_name,side,
         (int)previous,(int)state,
         JoonRangeHoldStateName(state),
         StringFormat("SCORE=%d|PROFIT=%d|%s",
            evidence.score,evidence.profitable?1:0,detail),
         false,false,0,g_trade_cycle.position_id);
      if(layer_name=="INITIAL") last_initial_log=closed_bar;
      else if(layer_name=="ADD1") last_add1_log=closed_bar;
      else last_add2_log=closed_bar;
   }
   return true;
}

bool ManageRangeLayerHoldStates(const int side)
{
   if(g_position_strategy!=STRATEGY_RANGE || side==0)
      return false;

   EvaluateOneRangeLayerHold(
      "INITIAL",side,g_initial_entry_price,
      g_initial_hold_anchor_time>0 ?
         g_initial_hold_anchor_time : g_initial_entry_time,
      g_initial_layer_hold_runtime,g_initial_layer_hold_tracked_time,
      g_initial_layer_hold_state,g_initial_layer_hold_ready);

   EvaluateOneRangeLayerHold(
      "ADD1",side,g_add1_entry_price,
      g_add1_hold_anchor_time>0 ?
         g_add1_hold_anchor_time : g_add1_entry_time,
      g_add1_layer_hold_runtime,g_add1_layer_hold_tracked_time,
      g_add1_layer_hold_state,g_add1_layer_hold_ready);

   EvaluateOneRangeLayerHold(
      "ADD2",side,g_add2_entry_price,
      g_add2_hold_anchor_time>0 ?
         g_add2_hold_anchor_time : g_add2_entry_time,
      g_add2_layer_hold_runtime,g_add2_layer_hold_tracked_time,
      g_add2_layer_hold_state,g_add2_layer_hold_ready);

   return g_initial_layer_hold_ready;
}

bool ManageRangeHoldStateEngine(ENUM_JOON_RANGE_HOLD_STATE &evaluated_state)
{
   evaluated_state=JOON_RANGE_HOLD_NORMAL;
   const int side=ManagedPositionSide();
   if(side==0 || g_position_strategy!=STRATEGY_RANGE)
   {
      g_hold_evaluation_ready=false;
      g_hold_state=HOLD_UNKNOWN;
      g_strong_hold_active=false;
      return false;
   }

   // v7.94 RANGE uses one directional-episode lifecycle for entry, hold and
   // strategic exit.  Temporary FINAL-density/MACD contraction does not change
   // HOLD state.  A non-zero opposite persistence side means an opposite FIRST
   // has committed and the held episode has ended.
   const bool episode_flipped=
      g_range_persistent_direction!=0 &&
      g_range_persistent_direction!=side;
   evaluated_state=episode_flipped ? JOON_RANGE_HOLD_EXIT :
                                     JOON_RANGE_HOLD_NORMAL;

   g_csv_hold_state_before=g_hold_state==HOLD_EXIT_CANDIDATE ?
                           JOON_RANGE_HOLD_EXIT : JOON_RANGE_HOLD_NORMAL;
   g_csv_hold_state_after=evaluated_state;
   g_hold_state=episode_flipped ? HOLD_EXIT_CANDIDATE : HOLD_NORMAL;
   g_strong_hold_active=false;
   g_hold_evaluation_ready=true;
   g_hold_evaluation_bar=g_range_final_density_last_bar;
   g_hold_evaluation_strategy=g_position_strategy;
   g_hold_evaluation_range_state=evaluated_state;
   TradeCycleSyncManagementState();

   static datetime last_log_bar=0;
   if(g_range_final_density_last_bar>0 &&
      g_range_final_density_last_bar!=last_log_bar)
   {
      last_log_bar=g_range_final_density_last_bar;
      Print("RANGE HOLD ENGINE: ",JoonRangeHoldStateName(evaluated_state),
            " | POSITION_SIDE ",side,
            " | PERSISTENCE_SIDE ",g_range_persistent_direction,
            " | FINAL_DENSITY L",g_range_final_density_long_5,
            "/S",g_range_final_density_short_5,
            " | MACD ",DoubleToString(g_range_final_density_macd_wave,6));
   }
   return true;
}


// ===== Functions moved from Common.mqh during ownership audit =====

void JoonResetRangeHoldRuntime(JoonRangeHoldRuntime &runtime)
{
   runtime.state = JOON_RANGE_HOLD_NORMAL;
   runtime.warning_bars = 0;
   runtime.failure_bars = 0;
   runtime.strong_candidate_bars = 0;
   runtime.warning_state_bars = 0;
   runtime.last_closed_bar = 0;
   runtime.warning_window_bits = 0;
   runtime.warning_window_samples = 0;
}


string JoonRangeHoldStateName(const ENUM_JOON_RANGE_HOLD_STATE state)
{
   switch(state)
   {
      case JOON_RANGE_HOLD_STRONG: return "STRONG";
      case JOON_RANGE_HOLD_WARNING: return "WARNING";
      case JOON_RANGE_HOLD_EXIT: return "EXIT";
      default: return "NORMAL";
   }
}


int JoonRangeHoldCountWindowBits(ulong value)
{
   int count = 0;
   while(value != 0)
   {
      count += (int)(value & 1);
      value >>= 1;
   }
   return count;
}


ulong JoonRangeHoldWindowMask(const int requested_window)
{
   const int window = MathMax(1, MathMin(63, requested_window));
   if(window >= 63)
      return 0x7FFFFFFFFFFFFFFF;
   return (((ulong)1 << window) - 1);
}


int JoonRangeHoldWarningWindowThreshold(const int requested_window)
{
   const int window = MathMax(1, MathMin(63, requested_window));
   // WARNING when weak evidence occupies at least 60% of the recent window.
   return MathMax(1, (window * 3 + 4) / 5);
}


ENUM_JOON_RANGE_HOLD_STATE JoonEvaluateRangeHoldState(
   const JoonRangeHoldConfig &config,
   const JoonRangeHoldEvidence &evidence,
   const datetime closed_bar_time,
   JoonRangeHoldRuntime &runtime)
{
   // One RANGE position group is managed per EA instance. These static values
   // preserve the rolling weak-region history without changing Common.mqh or
   // the public runtime structure.
   static ulong warning_window_bits = 0;
   static int warning_window_samples = 0;

   // JoonResetRangeHoldRuntime() sets last_closed_bar to zero whenever the
   // managed position changes or becomes flat. Reset the private window too.
   if(runtime.last_closed_bar == 0)
   {
      warning_window_bits = 0;
      warning_window_samples = 0;
      runtime.warning_bars = 0;
   }

   const bool new_closed_bar = closed_bar_time > 0 &&
                               closed_bar_time != runtime.last_closed_bar;
   const int aligned_count = (evidence.macd_aligned ? 1 : 0) +
                             (evidence.delta_aligned ? 1 : 0) +
                             (evidence.ma7_aligned ? 1 : 0);
   const int failure_count = (evidence.opposite_macd ? 1 : 0) +
                             (evidence.opposite_delta ? 1 : 0) +
                             (evidence.ma_cross_failed ? 1 : 0);

   // v3.68 RANGE state interpretation:
   // RANGE must not classify a normal pullback from a fixed weak-bar count.
   // Its weakness score already combines Dynamic-Leg deterioration:
   // MACD fade, Delta fade, MA compression, price pullback, alignment loss
   // rolling-window behaviour below.
   const bool weak_evidence =
      evidence.score < config.normal_score ||
      aligned_count <= 1 ||
      failure_count >= 2;
   const bool strong_evidence =
      evidence.score >= config.strong_score &&
      aligned_count == 3 && failure_count == 0;

   const bool range_mode=(g_position_strategy==STRATEGY_RANGE);
   const bool range_structural_warning =
      range_mode &&
      g_hold_weakness_score>=30 &&
      (evidence.score<config.normal_score ||
       aligned_count<=1 ||
       failure_count>=1);

   // Three direct failures mean MACD opposite expansion + Delta opposite
   // pressure + MA/price structural failure together. This is strong enough
   // for immediate RANGE EXIT. Two direct failures are meaningful but can
   // occur during a deep RANGE pullback, so they need persistence.
   const bool range_immediate_exit=
      range_mode && failure_count>=3;
   const bool range_moderate_exit=
      range_mode && failure_count==2;

   const int warning_window = MathMax(1, MathMin(63,
      config.warning_confirm_bars));

   if(new_closed_bar)
   {
      runtime.last_closed_bar = closed_bar_time;

      warning_window_bits =
         ((warning_window_bits << 1) |
          (weak_evidence ? (ulong)1 : (ulong)0)) &
         JoonRangeHoldWindowMask(warning_window);

      warning_window_samples =
         MathMin(warning_window, warning_window_samples + 1);

      // Retain the existing log field name, but it now reports the number of
      // weak bars inside the current evaluation region, not a consecutive run.
      runtime.warning_bars =
         JoonRangeHoldCountWindowBits(warning_window_bits);

      // RANGE uses failure strength first and time only as secondary
      if(range_mode)
      {
         if(range_moderate_exit)
            runtime.failure_bars++;
         else
            runtime.failure_bars=0;
      }
      else
      {
         if(failure_count >= 2)
            runtime.failure_bars++;
         else
            runtime.failure_bars = 0;
      }

      // v1.99 asymmetric state hysteresis: promotion to STRONG requires two
      // consecutive completed bars. A loss of strong evidence resets the
      // promotion counter immediately, so deterioration is never delayed.
      if(strong_evidence)
         runtime.strong_candidate_bars++;
      else
         runtime.strong_candidate_bars = 0;
   }

   const int required_weak_bars =
      JoonRangeHoldWarningWindowThreshold(warning_window);
   const bool warning_region_ready =
      warning_window_samples >= warning_window;
   const bool warning_region =
      warning_region_ready &&
      runtime.warning_bars >= required_weak_bars;

   if(range_mode)
   {
      // v3.68: RANGE exit is severity-aware rather than bar-count-only.
      // 3/3 direct failures => immediate structural invalidation.
      // 2/3 direct failures => require two completed evaluations.
      const bool persistent_moderate_exit=
         range_moderate_exit && runtime.failure_bars>=2;

      if(range_immediate_exit || persistent_moderate_exit)
         runtime.state = JOON_RANGE_HOLD_EXIT;
      else if(range_structural_warning)
         runtime.state = JOON_RANGE_HOLD_WARNING;
      else if(strong_evidence && runtime.strong_candidate_bars >= 2)
         runtime.state = JOON_RANGE_HOLD_STRONG;
      else if(evidence.score >= config.normal_score &&
              aligned_count >= 2 && failure_count < 2)
         runtime.state = JOON_RANGE_HOLD_NORMAL;
      else
      {
         // A shallow pullback that does not meet the composite deterioration
         // threshold remains NORMAL instead of being downgraded solely because
         // one or two recent bars were weak.
         if(runtime.state == JOON_RANGE_HOLD_EXIT ||
            runtime.state == JOON_RANGE_HOLD_WARNING)
            runtime.state = JOON_RANGE_HOLD_NORMAL;
      }
   }
   else
   {
      if(runtime.failure_bars >= MathMax(1, config.exit_confirm_bars))
         runtime.state = JOON_RANGE_HOLD_EXIT;
      else if(warning_region)
         runtime.state = JOON_RANGE_HOLD_WARNING;
      else if(strong_evidence && runtime.strong_candidate_bars >= 2)
         runtime.state = JOON_RANGE_HOLD_STRONG;
      else if(evidence.score >= config.normal_score &&
              aligned_count >= 2 && failure_count < 2)
         runtime.state = JOON_RANGE_HOLD_NORMAL;
      else
      {
         if(runtime.state == JOON_RANGE_HOLD_EXIT)
            runtime.state = JOON_RANGE_HOLD_WARNING;
      }
   }

   if(new_closed_bar)
   {
      if(runtime.state == JOON_RANGE_HOLD_WARNING)
         runtime.warning_state_bars++;
      else
         runtime.warning_state_bars = 0;
   }

   return runtime.state;
}


// v2.95 moved from SignalEngine: HoldEngine owns support/state evidence.
bool PositionDirectionHoldSupported(const int side,
                                    int &support_count,
                                    string &detail)
{
   support_count = 0;
   detail = "DATA_NOT_READY";
   if(side == 0 || !EnsureMarketSnapshot(3))
      return false;

   const double close1 = g_ms_rates[1].close;
   const bool macd_support = side > 0 ? g_ms_macd[1] > 0.0
                                      : g_ms_macd[1] < 0.0;
   const bool delta_support = side > 0 ? g_ms_delta[1] > 0.0
                                       : g_ms_delta[1] < 0.0;
   const bool ma_support = side > 0 ? close1 >= g_ms_slow_ma[1]
                                    : close1 <= g_ms_slow_ma[1];

   support_count = (macd_support ? 1 : 0) +
                   (delta_support ? 1 : 0) +
                   (ma_support ? 1 : 0);
   detail = StringFormat("DIR_SUPPORT %d/3 | MACD %s | DELTA %s | MA22 %s",
      support_count,
      macd_support ? "KEEP" : "LOST",
      delta_support ? "KEEP" : "LOST",
      ma_support ? "KEEP" : "LOST");
   return support_count >= 2;
}


// v2.95 moved from SignalEngine: HoldEngine owns support/state evidence.
bool EvaluateChaseTrendPersistence(const int side,
                                   int &conditions,
                                   int &macd_same_bars,
                                   int &delta_same_bars,
                                   string &detail)
{
   conditions = 0;
   macd_same_bars = 0;
   delta_same_bars = 0;
   detail = "";
   if(!InpUseChaseTrendHold || !g_chase_entry_candidate)
      return false;

   const int count = MathMax(InpChaseTrendLookbackBars, 3);
   double macd[], delta[], fast_ma[], slow_ma[];
   MqlRates rates[];
   ArrayResize(macd, count + 1);
   ArrayResize(delta, count);
   ArrayResize(fast_ma, count);
   ArrayResize(slow_ma, count);
   ArrayResize(rates, count + 2);
   ArraySetAsSeries(macd, true);
   ArraySetAsSeries(delta, true);
   ArraySetAsSeries(fast_ma, true);
   ArraySetAsSeries(slow_ma, true);
   ArraySetAsSeries(rates, true);

   if(MarketDataCopyBuffer(g_macd_handle, JTC_MACD_BASE_BUFFER, 0, count + 1, macd) < count + 1 ||
      MarketDataCopyBuffer(g_delta_handle, 2, 0, count, delta) < count ||
      MarketDataCopyBuffer(g_add_ma_handle, 0, 0, count, fast_ma) < count ||
      MarketDataCopyBuffer(g_slow_ma_handle, 0, 0, count, slow_ma) < count ||
      MarketDataCopyRates(_Symbol, AUTO_TF, 0, count + 2, rates) < count + 2)
      return false;

   for(int i = 0; i < count; i++)
   {
      if(side > 0 ? macd[i] > 0.0 : macd[i] < 0.0)
         macd_same_bars++;
      if(side > 0 ? delta[i] > 0.0 : delta[i] < 0.0)
         delta_same_bars++;
   }

   const bool macd_persistent = macd_same_bars >= InpChaseMACDMinimumBars;
   const bool delta_persistent = delta_same_bars >= InpChaseDeltaMinimumBars;
   const bool ma_aligned = side > 0 ?
      (fast_ma[0] > slow_ma[0] && fast_ma[0] >= fast_ma[count-1]) :
      (fast_ma[0] < slow_ma[0] && fast_ma[0] <= fast_ma[count-1]);
   const double market_price = side > 0 ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
                                        : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const bool price_on_trend_side = side > 0 ? market_price >= fast_ma[0]
                                              : market_price <= fast_ma[0];
   const bool structure_progress = side > 0 ?
      (rates[0].high >= rates[1].high || rates[1].high >= rates[2].high) :
      (rates[0].low <= rates[1].low || rates[1].low <= rates[2].low);

   if(macd_persistent) conditions++;
   if(delta_persistent) conditions++;
   if(ma_aligned) conditions++;
   if(price_on_trend_side) conditions++;
   if(structure_progress) conditions++;

   detail = "COND " + IntegerToString(conditions) + "/5" +
            " MACD " + IntegerToString(macd_same_bars) + "/" + IntegerToString(count) +
            " DELTA " + IntegerToString(delta_same_bars) + "/" + IntegerToString(count);
   return conditions >= InpChaseTrendMinimumConditions;
}

#endif // __JOON_HOLDENGINE_MQH__
