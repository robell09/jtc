//+------------------------------------------------------------------+
//| StateEvaluationEngine.mqh                                       |
//| v7.68 cached current-market trajectory/state interpreter        |
//| Owns closed-bar directional evidence; no order/exit/risk action. |
//+------------------------------------------------------------------+
#ifndef __JOON_STATE_EVALUATION_ENGINE_MQH__
#define __JOON_STATE_EVALUATION_ENGINE_MQH__
#include "ReviewShadowEngine.mqh"

// v8.253 cleanup: retired G4.4 oscillatory flip HOLD/PROMOTE state machine.
// Canonical WATCH is now decided only by the normal StateEvaluation candidate path.

// v8.255 compile regression fix: v8.227 historical replay guard remains a
// shared StateEvaluation/M3Auto execution-lifecycle flag. It was accidentally
// removed with the retired G4.4 globals in v8.253; restore the declaration only.
bool g_assist_history_replay=false;

// v8.266: canonical WATCH suppression latch. This is NOT WATCH ownership.
// It only consumes the same prioritized raw candidate episode after a rejected
// canonical WATCH publication attempt, preventing a rolling-window reissue on
// the next few bars. It is rebuilt from closed-bar history and never persisted.
bool g_assist_suppressed_watch_candidate_active=false;
int  g_assist_suppressed_watch_candidate_side=0;

// v8.273: remember only whether the canonical prioritized WATCH candidate was
// active on the previous completed bar.  This is publication-lifecycle state,
// not a new signal condition or order authority.  A FALSE->TRUE edge after a
// real candidate gap defines a new same-direction WATCH candidate episode.
bool g_assist_prev_prioritized_long_watch_candidate=false;
bool g_assist_prev_prioritized_short_watch_candidate=false;

// v8.229: bars exist during quote sessions, so quote-session metadata is the
// canonical way to distinguish a normal scheduled market closure from a true
// missing-data discontinuity. Return 1=open, 0=known closed, -1=unknown.
bool StateEvaluationHasQuoteSessionSchedule()
{
   for(int d=SUNDAY;d<=SATURDAY;d++)
   {
      datetime from=0,to=0;
      if(SymbolInfoSessionQuote(_Symbol,(ENUM_DAY_OF_WEEK)d,0,from,to))
         return true;
   }
   return false;
}

bool StateEvaluationScheduledMarketGap(const datetime older_bar,
                                       const datetime newer_bar,
                                       const int expected_bar_seconds)
{
   if(older_bar<=0 || newer_bar<=older_bar || expected_bar_seconds<=0)
      return false;
   if((newer_bar-older_bar)<=expected_bar_seconds)
      return false;
   if(!StateEvaluationHasQuoteSessionSchedule())
      return false;

   // Check whether any broker quote session overlaps the missing-bar window.
   // Iterate calendar days, not every missing M3 slot, so weekend gaps remain
   // one-time/lightweight startup/session-boundary work.
   MqlDateTime ds;
   if(!TimeToStruct(older_bar,ds)) return false;
   ds.hour=0; ds.min=0; ds.sec=0;
   datetime day_start=StructToTime(ds)-86400; // previous day catches >24h sessions
   const datetime missing_from=older_bar+expected_bar_seconds;
   const datetime missing_to=newer_bar;

   for(;day_start<=newer_bar;day_start+=86400)
   {
      MqlDateTime dd;
      if(!TimeToStruct(day_start,dd)) return false;
      for(uint idx=0;idx<16;idx++)
      {
         datetime from=0,to=0;
         if(!SymbolInfoSessionQuote(_Symbol,(ENUM_DAY_OF_WEEK)dd.day_of_week,idx,from,to))
            break;
         const long a=(long)from,b=(long)to;
         if(a==b && a==0) continue;
         const datetime session_from=(datetime)((long)day_start+a);
         datetime session_to=(datetime)((long)day_start+b);
         if(b<a) session_to+=86400;
         if(session_to>missing_from && session_from<missing_to)
            return false; // quotes should have been possible -> unexpected gap
      }
   }
   return true;
}

void StateEvaluationConfirmEstablishedByAccel(const int side,const datetime bar_time)
{
   if(side==0 || bar_time<=0) return;

   // v8.259 canonical invariant: confirmation is owned by the active WATCH-created
   // ACCEL leg, not by the transient StateEvaluation WATCH display state. A valid
   // WATCH may leave the literal WATCH state before its later-bar ACCEL arrives;
   // only explicit recovery/cancel evidence invalidates the pending owner.
   const int owner_side=g_assist_accel_owner_side;
   const datetime owner_time=g_assist_accel_owner_watch_time;
   if(owner_side!=(side>0 ? 1 : -1) || owner_time<=0 || bar_time<=owner_time)
      return;

   // Consumer-side proof that this is the actual canonical ACCEL event.
   const int accel_side=(side>0 ? M3_SEG_LONG : M3_SEG_SHORT);
   if(g_m3_segment.last_accel_event_side!=accel_side ||
      g_m3_segment.last_accel_event_time!=bar_time)
      return;

   g_assist_accel_owner_confirmed=true;
   g_assist_state.established_side=(side>0 ? 1 : -1);
   g_assist_state.established_time=bar_time;
   g_assist_state.direction_anchor=g_assist_state.established_side;
}

bool StateEvaluationClassifyWatchCandidate(const int side,
                                          const double aroon_osc_21,
                                          const double chop_14,
                                          const double progress3_raw_r,
                                          const double chop8_delta3,
                                          string &stage,
                                          string &suppress_reason,
                                          double &progress3_r,
                                          double &aroon_spread)
{
   stage="NONE";
   suppress_reason="";
   progress3_r=progress3_raw_r*(double)side;
   aroon_spread=aroon_osc_21*(double)side;

   if(aroon_spread<=-25.0)
      stage="EARLY";
   else if(aroon_spread>=50.0)
      stage="CONFIRMED";
   else
   {
      stage="TRANSITION";
      if(chop_14>=60.0)
         suppress_reason="RANGE_TRANSITION";
      else if(progress3_r>=1.20 && chop8_delta3<0.0)
         suppress_reason="LATE_BURST";
   }
   return suppress_reason!="";
}

bool StateEvaluationWatchPublishBlocked(const int side,
                                        const double aroon_osc_21,
                                        const double chop_14,
                                        const double progress3_raw_r,
                                        const double chop8_delta3,
                                        string &stage,
                                        string &suppress_reason,
                                        double &progress3_r,
                                        double &aroon_spread,
                                        bool &new_suppress_event)
{
   new_suppress_event=false;
   const bool quality_suppress=StateEvaluationClassifyWatchCandidate(
      side,aroon_osc_21,chop_14,progress3_raw_r,chop8_delta3,
      stage,suppress_reason,progress3_r,aroon_spread);

   if(g_assist_suppressed_watch_candidate_active &&
      g_assist_suppressed_watch_candidate_side==side)
   {
      // Preserve the original reason only for the onset row; continuation rows
      // are explicitly identified so CSV can reconstruct the candidate episode.
      suppress_reason="LATCH_CONTINUATION";
      return true;
   }

   if(!quality_suppress)
      return false;

   g_assist_suppressed_watch_candidate_active=true;
   g_assist_suppressed_watch_candidate_side=side;
   new_suppress_event=true;
   return true;
}

ENUM_TIMEFRAMES StateEvaluationTimeframe()
{
   return AUTO_TF;
}

string AssistStateName(const ENUM_JTA_ASSIST_STATE state)
{
   switch(state)
   {
      case JTA_ASSIST_UP:                    return "UP";
      case JTA_ASSIST_UP_WEAKENING:          return "UP WEAKENING";
      case JTA_ASSIST_REVERSAL_WATCH_DOWN:   return "SHORT WATCH";
      case JTA_ASSIST_DOWN:                  return "DOWN";
      case JTA_ASSIST_DOWN_WEAKENING:        return "DOWN WEAKENING";
      case JTA_ASSIST_REVERSAL_WATCH_UP:     return "LONG WATCH";
      default:                               return "NEUTRAL";
   }
}

int AssistStateDirection(const ENUM_JTA_ASSIST_STATE state)
{
   if(state==JTA_ASSIST_UP || state==JTA_ASSIST_UP_WEAKENING ||
      state==JTA_ASSIST_REVERSAL_WATCH_UP)
      return 1;
   if(state==JTA_ASSIST_DOWN || state==JTA_ASSIST_DOWN_WEAKENING ||
      state==JTA_ASSIST_REVERSAL_WATCH_DOWN)
      return -1;
   return 0;
}

void StateEvaluationReset()
{
   ZeroMemory(g_assist_state);
   JTC_TurnEngineReset();
   ReviewTrackerClear(g_review_tracker);
   g_review_tracker.last_bar=0;
   g_assist_state.state=JTA_ASSIST_NEUTRAL;
   g_assist_state.previous_state=JTA_ASSIST_NEUTRAL;
   g_assist_state.timeframe=StateEvaluationTimeframe();
   g_assist_state.direction_anchor=0;
   g_assist_state.established_side=0;
   g_assist_state.established_time=0;
   g_assist_state.reason="INITIALIZING";
   g_assist_state.changed=false;
   g_assist_state.post_discontinuity_rearm=false;
   g_assist_state.expected_bar_seconds=0;
   g_assist_state.market_gap_seconds=0;
   g_assist_state.data_discontinuity=false;
   g_assist_state.scheduled_market_gap=false;
   g_assist_state.weak_pulse=false;
   g_assist_state.weak_side=0;
   g_assist_early_opposite_active=false;
   g_assist_early_opposite_side=0;
   g_assist_early_candidate_track_active=false;
   g_assist_early_candidate_track_side=0;
   g_assist_early_candidate_start_time=0;
   g_assist_early_candidate_age_bars=0;
   g_assist_trend_reassertion_pending=false;
   g_assist_trend_reassertion_side=0;
   g_assist_trend_reassertion_age_bars=0;
   g_assist_long_weak_armed=true;
   g_assist_short_weak_armed=true;
   g_assist_accel_owner_side=0;
   g_assist_accel_owner_watch_time=0;
   g_assist_accel_owner_confirmed=false;
   g_assist_state_bucket=0;
   g_assist_suppressed_watch_candidate_active=false;
   g_assist_suppressed_watch_candidate_side=0;
   g_assist_prev_prioritized_long_watch_candidate=false;
   g_assist_prev_prioritized_short_watch_candidate=false;
}

bool StateEvaluationInitialize()
{
   StateEvaluationReset();
   g_assist_macd_handle=INVALID_HANDLE;
   g_assist_delta_handle=INVALID_HANDLE;
   g_assist_handles_owned=false;

   // v8.03: the cached state/structure snapshot is shared AUTO infrastructure,
   // not a UI/manual-assist dependency. InpAssistStateEnabled controls only
   // assist consumers (chart/alerts/CSV/signal-assist gates), never calculation.

   // Reuse only canonical handles whose lifetime never changes at runtime.
   // Menu-controlled SIGNAL handles are not shared here because they can be
   // released/recreated while the EA is live.
   const ENUM_TIMEFRAMES assist_tf=StateEvaluationTimeframe();
   // v7.18: state evaluation shares the same canonical TRADE TF data set.
   g_assist_macd_handle=g_macd_handle;
   g_assist_delta_handle=g_delta_handle;
   g_assist_handles_owned=false;

   if(g_assist_macd_handle==INVALID_HANDLE || g_assist_delta_handle==INVALID_HANDLE)
   {
      PrintFormat("[ASSIST STATE] indicator handle initialization failed | TF=%s | error=%d",
         EnumToString(assist_tf),GetLastError());
      return false;
   }

   // v8.227: do not evaluate the latest bar here.  Live startup restores the
   // closed-bar ownership chronologically in StateEvaluationWarmupRebuild();
   // Strategy Tester preserves the legacy one-bar prime from Runtime.mqh.
   return true;
}

bool StateEvaluationSetTimeframe(const ENUM_TIMEFRAMES timeframe)
{
   if(timeframe!=PERIOD_M1 && timeframe!=PERIOD_M2 && timeframe!=PERIOD_M3 &&
      timeframe!=PERIOD_M5 && timeframe!=PERIOD_M15)
      return false;

   if(AUTO_TF==timeframe && g_signal_tf==timeframe)
      return true;

   // A live position must never change its structural timeframe mid-cycle.
   if(ManagedPositionSide()!=0)
   {
      g_status=StringFormat("TF CHANGE BLOCKED: POSITION OPEN (%s)",EnumToString(AUTO_TF));
      return false;
   }

   // Create the new unified indicator set before releasing the current one.
   const int new_macd=iCustom(_Symbol,timeframe,"Market\\Joon_MACD_v2_05_OPT_VALIDATION");
   const int new_delta=iCustom(_Symbol,timeframe,"Market\\Joon_delta_volume_v1_01_OPT_VALIDATION");
   const int new_fast=iMA(_Symbol,timeframe,InpFastMAPeriod,0,MODE_SMA,PRICE_CLOSE);
   const int new_slow=iMA(_Symbol,timeframe,InpSlowMAPeriod,0,MODE_SMA,PRICE_CLOSE);
   const int new_ma70=iMA(_Symbol,timeframe,InpTrendMAPeriod,0,MODE_SMA,PRICE_CLOSE);
   const int new_ma111=iMA(_Symbol,timeframe,InpSupportMAPeriod,0,MODE_SMA,PRICE_CLOSE);
   const int new_ma200=iMA(_Symbol,timeframe,InpLongMAPeriod,0,MODE_SMA,PRICE_CLOSE);
   if(new_macd==INVALID_HANDLE || new_delta==INVALID_HANDLE ||
      new_fast==INVALID_HANDLE || new_slow==INVALID_HANDLE ||
      new_ma70==INVALID_HANDLE || new_ma111==INVALID_HANDLE ||
      new_ma200==INVALID_HANDLE)
   {
      if(new_macd!=INVALID_HANDLE) IndicatorRelease(new_macd);
      if(new_delta!=INVALID_HANDLE) IndicatorRelease(new_delta);
      if(new_fast!=INVALID_HANDLE) IndicatorRelease(new_fast);
      if(new_slow!=INVALID_HANDLE) IndicatorRelease(new_slow);
      if(new_ma70!=INVALID_HANDLE) IndicatorRelease(new_ma70);
      if(new_ma111!=INVALID_HANDLE) IndicatorRelease(new_ma111);
      if(new_ma200!=INVALID_HANDLE) IndicatorRelease(new_ma200);
      g_status="TRADING TF CHANGE FAILED";
      return false;
   }

   // Assist may be sharing the canonical handles. Detach its references first.
   StateEvaluationRelease();

   // Dedicated SIGNAL handles, if any legacy state exists, are released separately.
   if(!g_signal_handles_shared_with_auto)
   {
      if(g_signal_macd_handle!=INVALID_HANDLE) IndicatorRelease(g_signal_macd_handle);
      if(g_signal_delta_handle!=INVALID_HANDLE) IndicatorRelease(g_signal_delta_handle);
      if(g_signal_fast_ma_handle!=INVALID_HANDLE) IndicatorRelease(g_signal_fast_ma_handle);
      if(g_signal_slow_ma_handle!=INVALID_HANDLE) IndicatorRelease(g_signal_slow_ma_handle);
      if(g_signal_ma70_handle!=INVALID_HANDLE) IndicatorRelease(g_signal_ma70_handle);
      if(g_signal_ma111_handle!=INVALID_HANDLE) IndicatorRelease(g_signal_ma111_handle);
      if(g_signal_ma200_handle!=INVALID_HANDLE) IndicatorRelease(g_signal_ma200_handle);
   }

   if(g_macd_handle!=INVALID_HANDLE) IndicatorRelease(g_macd_handle);
   if(g_delta_handle!=INVALID_HANDLE) IndicatorRelease(g_delta_handle);
   if(g_add_ma_handle!=INVALID_HANDLE) IndicatorRelease(g_add_ma_handle);
   if(g_slow_ma_handle!=INVALID_HANDLE) IndicatorRelease(g_slow_ma_handle);
   if(g_ma70_handle!=INVALID_HANDLE) IndicatorRelease(g_ma70_handle);
   if(g_ma111_handle!=INVALID_HANDLE) IndicatorRelease(g_ma111_handle);
   if(g_ma200_handle!=INVALID_HANDLE) IndicatorRelease(g_ma200_handle);

   g_trading_tf=timeframe;
   g_signal_tf=timeframe;
   g_assist_state_tf_runtime=timeframe;

   g_macd_handle=new_macd;
   g_delta_handle=new_delta;
   g_add_ma_handle=new_fast;
   g_slow_ma_handle=new_slow;
   g_ma70_handle=new_ma70;
   g_ma111_handle=new_ma111;
   g_ma200_handle=new_ma200;

   // SIGNAL and AUTO now intentionally share one unified timeframe and one data set.
   g_signal_macd_handle=g_macd_handle;
   g_signal_delta_handle=g_delta_handle;
   g_signal_fast_ma_handle=g_add_ma_handle;
   g_signal_slow_ma_handle=g_slow_ma_handle;
   g_signal_ma70_handle=g_ma70_handle;
   g_signal_ma111_handle=g_ma111_handle;
   g_signal_ma200_handle=g_ma200_handle;
   g_signal_handles_shared_with_auto=true;

   g_calc_tf=timeframe;
   g_calc_macd_handle=g_macd_handle;
   g_calc_delta_handle=g_delta_handle;
   g_calc_fast_ma_handle=g_add_ma_handle;
   g_calc_slow_ma_handle=g_slow_ma_handle;
   g_calc_ma70_handle=g_ma70_handle;
   g_calc_ma111_handle=g_ma111_handle;
   g_calc_ma200_handle=g_ma200_handle;
   g_market_snapshot_tf=PERIOD_CURRENT;

   // Every TF-dependent lifecycle must restart cleanly on a new basis.
   ResetAutoSignalCounters();
   ResetRepeatFinalTracking();
   ResetRangeDirectionalPersistence("TRADING TF CHANGED");
   WatchSignalResetState();
   ResetPreAutoFinalHistory("TRADING TF CHANGED");
   g_last_bar_time=iTime(_Symbol,timeframe,0);
   g_last_auto_bar_time=g_last_bar_time;

   if(!StateEvaluationInitialize())
   {
      g_status="TRADING TF CHANGED; SHARED STATE INIT FAILED";
      return false;
   }
   if((bool)MQLInfoInteger(MQL_TESTER))
      StateEvaluationUpdateOnClosedBar();
   else if(!StateEvaluationWarmupRebuild())
      StateEvaluationUpdateOnClosedBar();

   GlobalVariableSet(UIStateKey("SIGNAL_TF"),(double)timeframe);
   g_status=StringFormat("TRADING TF: %s",EnumToString(timeframe));
   return true;
}

void StateEvaluationRelease()
{
   if(g_assist_handles_owned)
   {
      if(g_assist_macd_handle!=INVALID_HANDLE)
         IndicatorRelease(g_assist_macd_handle);
      if(g_assist_delta_handle!=INVALID_HANDLE)
         IndicatorRelease(g_assist_delta_handle);
   }
   g_assist_macd_handle=INVALID_HANDLE;
   g_assist_delta_handle=INVALID_HANDLE;
   g_assist_handles_owned=false;
}

// One data acquisition pass per completed assist bar. The same cached snapshot
// is consumed by chart/UI/CSV. No consumer is allowed to CopyRates/CopyBuffer
// again for this state decision.
// v8.263 observation-only CHOP/Aroon diagnostics. These helpers consume only
// the existing closed-bar rates[] snapshot and never vote on WATCH/AUTO state.
bool StateEvaluationCalcChopAtShift(const MqlRates &rates[],const int period,const int start_shift,double &value)
{
   value=0.0;
   if(period<2 || start_shift<1 || ArraySize(rates)<=start_shift+period)
      return false;

   double tr_sum=0.0;
   double highest=rates[start_shift].high;
   double lowest=rates[start_shift].low;
   const int last=start_shift+period-1;
   for(int i=start_shift;i<=last;i++)
   {
      highest=MathMax(highest,rates[i].high);
      lowest=MathMin(lowest,rates[i].low);
      const double prev_close=rates[i+1].close;
      const double tr=MathMax(rates[i].high-rates[i].low,
                              MathMax(MathAbs(rates[i].high-prev_close),
                                      MathAbs(rates[i].low-prev_close)));
      tr_sum+=tr;
   }

   const double span=highest-lowest;
   if(span<=0.0 || tr_sum<=0.0)
      return false;

   const double ratio=tr_sum/span;
   if(ratio<=0.0)
      return false;

   value=100.0*MathLog(ratio)/MathLog((double)period);
   return MathIsValidNumber(value);
}

bool StateEvaluationCalcChop(const MqlRates &rates[],const int period,double &value)
{
   return StateEvaluationCalcChopAtShift(rates,period,1,value);
}

bool StateEvaluationCalcAtrAtShift(const MqlRates &rates[],const int period,const int start_shift,double &value)
{
   value=0.0;
   if(period<1 || start_shift<1 || ArraySize(rates)<=start_shift+period)
      return false;
   double tr_sum=0.0;
   const int last=start_shift+period-1;
   for(int i=start_shift;i<=last;i++)
   {
      const double prev_close=rates[i+1].close;
      const double tr=MathMax(rates[i].high-rates[i].low,
                              MathMax(MathAbs(rates[i].high-prev_close),
                                      MathAbs(rates[i].low-prev_close)));
      tr_sum+=tr;
   }
   value=tr_sum/(double)period;
   return value>0.0 && MathIsValidNumber(value);
}


// v8.269: calculate the WATCH regime diagnostics from one shared True Range
// pass. This is numerically equivalent to the legacy individual helpers but
// avoids recalculating the same TR values for CHOP8/14/21, ATR14 and shifted
// CHOP8 on every completed assist bar.
bool StateEvaluationCalcRegimeObservation(const MqlRates &rates[],
                                          double &chop8,double &chop14,double &chop21,
                                          double &atr14,double &chop8_prev3)
{
   chop8=0.0; chop14=0.0; chop21=0.0; atr14=0.0; chop8_prev3=0.0;
   if(ArraySize(rates)<=22)
      return false;

   double tr[22];
   ArrayInitialize(tr,0.0);
   for(int i=1;i<=21;i++)
   {
      const double prev_close=rates[i+1].close;
      tr[i]=MathMax(rates[i].high-rates[i].low,
                    MathMax(MathAbs(rates[i].high-prev_close),
                            MathAbs(rates[i].low-prev_close)));
   }

   double tr8=0.0,tr14=0.0,tr21=0.0,tr8_prev3=0.0;
   double hi8=rates[1].high,lo8=rates[1].low;
   double hi14=hi8,lo14=lo8;
   double hi21=hi8,lo21=lo8;
   double hi8_prev3=rates[4].high,lo8_prev3=rates[4].low;

   for(int i=1;i<=21;i++)
   {
      tr21+=tr[i];
      hi21=MathMax(hi21,rates[i].high);
      lo21=MathMin(lo21,rates[i].low);
      if(i<=14)
      {
         tr14+=tr[i];
         hi14=MathMax(hi14,rates[i].high);
         lo14=MathMin(lo14,rates[i].low);
      }
      if(i<=8)
      {
         tr8+=tr[i];
         hi8=MathMax(hi8,rates[i].high);
         lo8=MathMin(lo8,rates[i].low);
      }
      if(i>=4 && i<=11)
      {
         tr8_prev3+=tr[i];
         hi8_prev3=MathMax(hi8_prev3,rates[i].high);
         lo8_prev3=MathMin(lo8_prev3,rates[i].low);
      }
   }

   const double span8=hi8-lo8;
   const double span14=hi14-lo14;
   const double span21=hi21-lo21;
   const double span8_prev3=hi8_prev3-lo8_prev3;
   if(span8<=0.0 || span14<=0.0 || span21<=0.0 || span8_prev3<=0.0 ||
      tr8<=0.0 || tr14<=0.0 || tr21<=0.0 || tr8_prev3<=0.0)
      return false;

   chop8=100.0*MathLog(tr8/span8)/MathLog(8.0);
   chop14=100.0*MathLog(tr14/span14)/MathLog(14.0);
   chop21=100.0*MathLog(tr21/span21)/MathLog(21.0);
   chop8_prev3=100.0*MathLog(tr8_prev3/span8_prev3)/MathLog(8.0);
   atr14=tr14/14.0;
   return MathIsValidNumber(chop8) && MathIsValidNumber(chop14) &&
          MathIsValidNumber(chop21) && MathIsValidNumber(chop8_prev3) &&
          MathIsValidNumber(atr14) && atr14>0.0;
}

bool StateEvaluationCalcAroon21(const MqlRates &rates[],double &up,double &down,double &osc)
{
   const int period=21;
   up=0.0; down=0.0; osc=0.0;
   if(ArraySize(rates)<=period)
      return false;

   int high_age=0;
   int low_age=0;
   double highest=rates[1].high;
   double lowest=rates[1].low;
   for(int i=2;i<=period;i++)
   {
      // Keep the most recent extreme when equal values occur.
      if(rates[i].high>highest)
      {
         highest=rates[i].high;
         high_age=i-1;
      }
      if(rates[i].low<lowest)
      {
         lowest=rates[i].low;
         low_age=i-1;
      }
   }

   // Standard Aroon definition: 100 * (period - bars_since_extreme) / period.
   up=100.0*((double)period-(double)high_age)/(double)period;
   down=100.0*((double)period-(double)low_age)/(double)period;
   osc=up-down;
   return true;
}

bool StateEvaluationUpdateAtClosedShift(const int closed_shift,const bool historical_replay)
{
   if(g_assist_macd_handle==INVALID_HANDLE ||
      g_assist_delta_handle==INVALID_HANDLE)
      return false;

   if(closed_shift<1)
      return false;
   // Copy windows are series arrays.  start_pos=closed_shift-1 keeps the
   // requested historical closed bar at rates[1], so the entire legacy
   // decision body remains byte-for-byte index compatible.
   const int source_start=closed_shift-1;

   int lookback=InpAssistStateLookbackBars;
   if(lookback<4) lookback=4;
   if(lookback>12) lookback=12;
   // v7.48: WATCH trajectory uses the faster unscaled Final Wave plus Raw
   // Price MACD.  The slower unscaled Signal/Base remains available for FINAL
   // and audit context, but no longer owns reversal-transition timing.
   // v8.02: the same one-pass snapshot also owns the canonical recent/older
   // swing structure used by RANGE continuation ADD. No consumer may perform
   // another structure history read for this decision bar.
   const int requested_pattern_lookback=(InpPatternLookback<6 ? 6 : InpPatternLookback);
   const int requested_hold_lookback=(InpHoldStructureLookbackBars<4 ? 4 : InpHoldStructureLookbackBars);
   const int structure_need=MathMax(requested_pattern_lookback+2,
                                    requested_hold_lookback*2+2);
   const int regime_diag_need=23; // CHOP21 needs rates[22] for previous-close TR.
   const int need=MathMax(MathMax(lookback+2,structure_need),regime_diag_need);

   MqlRates rates[];
   double macd_base[],macd_wave[],raw_macd[],macd_direction[],macd_zero_state[],raw_delta[],ema_delta[],source_volume[];
   ArrayResize(rates,need);
   ArrayResize(macd_base,need);
   ArrayResize(macd_wave,need);
   ArrayResize(raw_macd,need);
   ArrayResize(macd_direction,need);
   ArrayResize(macd_zero_state,need);
   ArrayResize(raw_delta,need);
   ArrayResize(ema_delta,need);
   ArrayResize(source_volume,need);
   ArraySetAsSeries(rates,true);
   ArraySetAsSeries(macd_base,true);
   ArraySetAsSeries(macd_wave,true);
   ArraySetAsSeries(raw_macd,true);
   ArraySetAsSeries(macd_direction,true);
   ArraySetAsSeries(macd_zero_state,true);
   ArraySetAsSeries(raw_delta,true);
   ArraySetAsSeries(ema_delta,true);
   ArraySetAsSeries(source_volume,true);

   // v7.82 RANGE shared-basis optimization:
   // StateEvaluation is the first completed-bar consumer. On the unified RANGE
   // timeframe, expand the EXISTING market snapshot once to the signal history
   // length so ProcessRangeClosedBar can reuse the same terminal reads. Other
   // strategies/timeframes keep the original direct acquisition path.
   const bool shared_range_snapshot=
      (historical_replay ||
       (InpSystemEnabled && g_selected_strategy==STRATEGY_RANGE)) &&
      StateEvaluationTimeframe()==AUTO_TF &&
      g_assist_macd_handle==g_macd_handle &&
      g_assist_delta_handle==g_delta_handle;

   bool data_ready=false;
   if(shared_range_snapshot)
   {
      const int shared_need=MathMax(need,SignalRequiredHistoryCount());
      if(EnsureMarketSnapshotAssist(shared_need+source_start))
      {
         data_ready=
            ArrayCopy(rates,g_ms_rates,0,source_start,need)==need &&
            ArrayCopy(macd_base,g_ms_macd,0,source_start,need)==need &&
            ArrayCopy(macd_wave,g_ms_macd_wave,0,source_start,need)==need &&
            ArrayCopy(raw_macd,g_ms_macd_raw_price,0,source_start,need)==need &&
            ArrayCopy(macd_direction,g_ms_macd_direction,0,source_start,need)==need &&
            ArrayCopy(macd_zero_state,g_ms_macd_zero_state,0,source_start,need)==need &&
            ArrayCopy(raw_delta,g_ms_delta,0,source_start,need)==need &&
            ArrayCopy(ema_delta,g_ms_delta_ema,0,source_start,need)==need &&
            ArrayCopy(source_volume,g_ms_delta_volume,0,source_start,need)==need;
      }
   }

   // Exact legacy fallback: snapshot readiness must never become a new
   // signal/assist gate (for example while MA handles are still warming up).
   if(!data_ready)
   {
      data_ready=
         MarketDataCopyRates(_Symbol,StateEvaluationTimeframe(),source_start,need,rates)>=need &&
         MarketDataCopyBuffer(g_assist_macd_handle,JTC_MACD_BASE_BUFFER,source_start,need,macd_base)>=need &&
         MarketDataCopyBuffer(g_assist_macd_handle,JTC_MACD_WAVE_BUFFER,source_start,need,macd_wave)>=need &&
         MarketDataCopyBuffer(g_assist_macd_handle,JTC_MACD_RAW_PRICE_BUFFER,source_start,need,raw_macd)>=need &&
         MarketDataCopyBuffer(g_assist_macd_handle,JTC_MACD_DIRECTION_BUFFER,source_start,need,macd_direction)>=need &&
         MarketDataCopyBuffer(g_assist_macd_handle,JTC_MACD_ZERO_STATE_BUFFER,source_start,need,macd_zero_state)>=need &&
         MarketDataCopyBuffer(g_assist_delta_handle,2,source_start,need,raw_delta)>=need &&
         MarketDataCopyBuffer(g_assist_delta_handle,3,source_start,need,ema_delta)>=need &&
         MarketDataCopyBuffer(g_assist_delta_handle,4,source_start,need,source_volume)>=need;
   }
   if(!data_ready)
      return false;

   const datetime closed_bar=rates[1].time;
   if(closed_bar<=0 || closed_bar==g_assist_state.bar_time)
      return closed_bar>0;

   JTC_TurnProcess(rates,raw_macd,macd_wave,raw_delta,ema_delta,source_volume,historical_replay,closed_shift);

   // v8.263 observation-only market-regime snapshot.
   double chop_8=0.0,chop_14=0.0,chop_21=0.0;
   double aroon_up_21=0.0,aroon_down_21=0.0,aroon_osc_21=0.0;
   double observe_atr14=0.0;
   double observe_chop8_prev3=0.0;
   StateEvaluationCalcRegimeObservation(rates,chop_8,chop_14,chop_21,
                                        observe_atr14,observe_chop8_prev3);
   StateEvaluationCalcAroon21(rates,aroon_up_21,aroon_down_21,aroon_osc_21);

   // v8.264 observation-only WATCH quality inputs. Match the offline study exactly:
   // Progress3 = close[1]-close[4], normalized by simple ATR14 on the current
   // completed bar; CHOP8 delta3 = CHOP8(current) - CHOP8(three bars ago).
   const double observe_progress3_raw_r=
      (observe_atr14>0.0 ? (rates[1].close-rates[4].close)/observe_atr14 : 0.0);
   const double observe_chop8_delta3=chop_8-observe_chop8_prev3;

   // v7.68 directional-episode continuity repair. StateEvaluation is the
   // first completed-bar consumer, so signal continuity built from missing
   // TRADE-TF bars is retired here using the rates that are already cached.
   // No new history/indicator read, loop, timer or tick work is introduced.
   const int expected_bar_seconds=PeriodSeconds(StateEvaluationTimeframe());
   // v7.68: continuity is a property of the market bars themselves, not of
   // how long the EA happened to go between StateEvaluation calls. Comparing
   // rates[1] with rates[2] prevents terminal/tick/EA processing interruptions
   // from being misclassified as missing market data.
   const int market_gap_seconds=
      (rates[1].time>0 && rates[2].time>0 ? (int)(rates[1].time-rates[2].time) : 0);
   const bool data_discontinuity=
      expected_bar_seconds>0 && market_gap_seconds>expected_bar_seconds;
   const bool scheduled_market_gap=
      data_discontinuity &&
      StateEvaluationScheduledMarketGap(rates[2].time,rates[1].time,expected_bar_seconds);
   // v8.229 continuity diagnostics: keep the raw bar-gap decision and also
   // distinguish a normal symbol quote-session closure from missing live data.
   g_assist_state.expected_bar_seconds=expected_bar_seconds;
   g_assist_state.market_gap_seconds=market_gap_seconds;
   g_assist_state.data_discontinuity=data_discontinuity;
   g_assist_state.scheduled_market_gap=scheduled_market_gap;
   if(data_discontinuity && g_selected_strategy==STRATEGY_RANGE)
   {
      const int old_established=g_assist_state.established_side;

      // Historical StateEvaluation replay restores assist ownership only.
      // Never mutate live Signal/TradeCycle counters while walking old bars.
      if(!historical_replay)
      {
         ResetInitialSignalCountersOnly();
         if(g_trade_cycle.state==JTA_CYCLE_SIGNAL_ACCUMULATING)
            TradeCycleClear(scheduled_market_gap ? "TRADE-TF SCHEDULED SESSION GAP" : "TRADE-TF DATA DISCONTINUITY");
         ResetRepeatFinalTracking();
         ResetPreAutoFinalHistory(scheduled_market_gap ? "TRADE-TF SCHEDULED SESSION GAP" : "TRADE-TF DATA DISCONTINUITY");
      }

      if(scheduled_market_gap)
      {
         // A normal exchange/broker session closure ends provisional WATCH/HOLD
         // state but does not erase a direction already confirmed by WATCH->ACCEL.
         const int keep=g_assist_state.established_side;
         g_assist_state.direction_anchor=keep;
         g_assist_state.state=(keep>0 ? JTA_ASSIST_UP : (keep<0 ? JTA_ASSIST_DOWN : JTA_ASSIST_NEUTRAL));
         g_assist_state.previous_state=g_assist_state.state;
         g_assist_state.post_discontinuity_rearm=false;
      }
      else
      {
         // True missing-data continuity cannot safely carry predictive ownership.
         g_assist_state.established_side=0;
         g_assist_state.established_time=0;
         g_assist_state.direction_anchor=0;
         g_assist_state.state=JTA_ASSIST_NEUTRAL;
         g_assist_state.previous_state=JTA_ASSIST_NEUTRAL;
         g_assist_state.post_discontinuity_rearm=true;
      }

      if(!historical_replay)
         WriteUnifiedOrderSignalAudit(
            scheduled_market_gap ? "RANGE_SIGNAL_SCHEDULED_GAP_RESET" : "RANGE_SIGNAL_DATA_CONTINUITY_RESET",
            TimeToString(closed_bar,TIME_DATE|TIME_MINUTES),
            "ASSIST",old_established,g_assist_state.established_side,0,"RESET",
            StringFormat("GAP_SECONDS=%d EXPECTED=%d SCHEDULED=%d ESTABLISHED_BEFORE=%d ESTABLISHED_AFTER=%d REARM=%d",
                         market_gap_seconds,expected_bar_seconds,(scheduled_market_gap?1:0),
                         old_established,g_assist_state.established_side,
                         (g_assist_state.post_discontinuity_rearm?1:0)),
            false,false,0,g_trade_cycle.position_id);
   }

   double range_sum=0.0;
   int higher_high_steps=0,higher_low_steps=0;
   int lower_high_steps=0,lower_low_steps=0;
   int up_close_steps=0,down_close_steps=0;
   for(int i=lookback;i>=1;i--)
   {
      range_sum+=MathMax(_Point,rates[i].high-rates[i].low);
      if(i>1)
      {
         const double eps=_Point;
         if(rates[i-1].high>rates[i].high+eps) higher_high_steps++;
         if(rates[i-1].low >rates[i].low +eps) higher_low_steps++;
         if(rates[i-1].high<rates[i].high-eps) lower_high_steps++;
         if(rates[i-1].low <rates[i].low -eps) lower_low_steps++;
         if(rates[i-1].close>rates[i].close+eps) up_close_steps++;
         if(rates[i-1].close<rates[i].close-eps) down_close_steps++;
      }
   }

   const double avg_range=MathMax(_Point,range_sum/lookback);
   const double net_progress=(rates[1].close-rates[lookback].close)/avg_range;
   const int recent_index=3;
   const double recent_progress=(rates[1].close-rates[recent_index].close)/avg_range;
   // v8.221: observation-only path diagnostics. Reuse already-loaded arrays.
   const double price_travel_3=
      MathAbs(rates[1].close-rates[2].close)+
      MathAbs(rates[2].close-rates[3].close)+
      MathAbs(rates[3].close-rates[4].close);
   const double price_net_3=MathAbs(rates[1].close-rates[4].close);
   const double price_travel_3_r=price_travel_3/avg_range;
   const double price_efficiency_3=(price_travel_3>0.0 ? price_net_3/price_travel_3 : 0.0);
   int macd_zero_flip_count_5=0;
   for(int z=1;z<=5;z++)
   {
      const int za=(macd_zero_state[z]>0.5 ? 1 : (macd_zero_state[z]<-0.5 ? -1 : 0));
      const int zb=(macd_zero_state[z+1]>0.5 ? 1 : (macd_zero_state[z+1]<-0.5 ? -1 : 0));
      if(za!=0 && zb!=0 && za!=zb) macd_zero_flip_count_5++;
   }

   // v8.02 canonical swing structure. This is the existing SignalEngine
   // recent-vs-older structure calculation moved to the shared snapshot owner.
   const int pattern_lookback=requested_pattern_lookback;
   const int half_pattern=MathMax(3,pattern_lookback/2);
   double recent_swing_low=rates[2].low;
   double recent_swing_high=rates[2].high;
   double older_swing_low=rates[half_pattern+2].low;
   double older_swing_high=rates[half_pattern+2].high;
   for(int i=2;i<=half_pattern+1;i++)
   {
      recent_swing_low=MathMin(recent_swing_low,rates[i].low);
      recent_swing_high=MathMax(recent_swing_high,rates[i].high);
   }
   for(int i=half_pattern+2;i<=pattern_lookback+1;i++)
   {
      older_swing_low=MathMin(older_swing_low,rates[i].low);
      older_swing_high=MathMax(older_swing_high,rates[i].high);
   }
   const double structure_tolerance=avg_range*InpDoubleTopBottomTolerance;
   const bool structure_higher_low=
      recent_swing_low>older_swing_low+structure_tolerance;
   const bool structure_lower_high=
      recent_swing_high<older_swing_high-structure_tolerance;

   // A continuation setup is a price condition, not a new signal score:
   // the latest multi-bar path must have pulled against the held direction
   // while preserving HL (LONG) or LH (SHORT). The frozen opposite extreme
   // is then the only re-break reference consumed by EntryEngine.
   const bool pullback_long_ready=structure_higher_low && recent_progress<0.0;
   const bool pullback_short_ready=structure_lower_high && recent_progress>0.0;
   const double macd_change_1=raw_macd[1]-raw_macd[2];
   const double macd_change_3=raw_macd[1]-raw_macd[recent_index];
   const double delta_change=ema_delta[1]-ema_delta[recent_index];
   const int macd_dir=macd_direction[1]>0.5 ? 1 :
                      (macd_direction[1]<-0.5 ? -1 : 0);

   // Price owns the directional interpretation. MACD/Delta only describe
   // persistence/weakening; they cannot create a trend against price.
   const bool price_up=
      net_progress>=0.65 &&
      up_close_steps>=down_close_steps+1 &&
      higher_high_steps>=lower_high_steps &&
      higher_low_steps>=lower_low_steps;
   const bool price_down=
      net_progress<=-0.65 &&
      down_close_steps>=up_close_steps+1 &&
      lower_high_steps>=higher_high_steps &&
      lower_low_steps>=higher_low_steps;

   // v7.48 reversal timing:
   // Use trajectory, not a single cross/threshold. Final Wave supplies the
   // responsive transition path; Raw MACD confirms that the underlying price
   // momentum has moved in the same direction on at least 2 of the last
   // 3 completed steps.  Repeated WATCH pulses remain possible while this
   // trajectory and price progress continue before FINAL.
   const double macd_wave_change_1=macd_wave[1]-macd_wave[2];
   const double macd_wave_change_3=macd_wave[1]-macd_wave[3];

   // v8.218: observation-only MACD flatness diagnostics. These values do not
   // participate in WATCH/WEAK/DIRECTION/ACCEL or order authority.
   const double macd_base_change_1=macd_base[1]-macd_base[2];
   const double macd_base_change_3=macd_base[1]-macd_base[4];
   const double macd_base_travel_3=
      MathAbs(macd_base[1]-macd_base[2])+
      MathAbs(macd_base[2]-macd_base[3])+
      MathAbs(macd_base[3]-macd_base[4]);
   const double macd_base_net_3=MathAbs(macd_base[1]-macd_base[4]);
   const double macd_base_efficiency_3=
      (macd_base_travel_3>0.0 ? macd_base_net_3/macd_base_travel_3 : 0.0);
   const double macd_wave_travel_3=
      MathAbs(macd_wave[1]-macd_wave[2])+
      MathAbs(macd_wave[2]-macd_wave[3])+
      MathAbs(macd_wave[3]-macd_wave[4]);
   const double macd_wave_net_3=MathAbs(macd_wave[1]-macd_wave[4]);
   const double macd_wave_efficiency_3=
      (macd_wave_travel_3>0.0 ? macd_wave_net_3/macd_wave_travel_3 : 0.0);

   // v8.253 cleanup: G4.4 is retired. Keep deprecated CSV fields neutral so
   // the integrated CSV schema stays byte-for-byte comparable with v8.252.
   const bool flip_path_oscillatory=false;
   const bool flip_raw_path_directional=false;
   const bool flip_wave_path_directional=false;
   const int raw_last_sign=0;
   const int wave_last_sign=0;
   const double raw_efficiency_5=0.0;
   const double wave_efficiency_5=0.0;

   int raw_up_steps=0,raw_down_steps=0;
   for(int i=1;i<=3;i++)
   {
      const double raw_step=raw_macd[i]-raw_macd[i+1];
      if(raw_step>0.0) raw_up_steps++;
      else if(raw_step<0.0) raw_down_steps++;
   }
   const bool raw_up_persistent=(raw_up_steps>=2);
   const bool raw_down_persistent=(raw_down_steps>=2);
   const bool raw_current_up=(macd_change_1>0.0);
   const bool raw_current_down=(macd_change_1<0.0);
   const bool wave_current_up=(macd_wave_change_1>0.0);
   const bool wave_current_down=(macd_wave_change_1<0.0);

   // v7.49: trajectory requires both accumulated progress and the current
   // completed step to still point in the same direction.  This prevents a
   // stale 2-of-3 history from generating another WATCH after momentum has
   // already started turning back the other way.
   // macd_wave_change_3 is kept for CSV continuity; it is the net change
   // between completed bars [3] and [1] (two bar intervals).
   const double macd_transition_progress=macd_wave_change_3;
   const bool macd_transition_up=
      macd_wave_change_3>0.0 &&
      macd_change_3>0.0 &&
      raw_up_persistent &&
      wave_current_up &&
      raw_current_up;
   const bool macd_transition_down=
      macd_wave_change_3<0.0 &&
      macd_change_3<0.0 &&
      raw_down_persistent &&
      wave_current_down &&
      raw_current_down;

   const bool macd_weak_for_up=(macd_change_3<0.0 || macd_change_1<0.0);
   const bool macd_weak_for_down=(macd_change_3>0.0 || macd_change_1>0.0);
   const bool delta_weak_for_up=(delta_change<0.0 || raw_delta[1]<0.0);
   const bool delta_weak_for_down=(delta_change>0.0 || raw_delta[1]>0.0);

   // v7.50: Delta confirms only a NEW counter-direction WATCH or a WATCH
   // direction flip.  It is participation evidence, not a zero-line gate:
   // EMA Delta may still be negative for LONG (or positive for SHORT) as long
   // as it is moving toward the reversal direction and Raw Delta participation
   // supports that direction on at least 2 of the last 3 completed bars.
   int delta_buy_steps=0,delta_sell_steps=0;
   for(int i=1;i<=3;i++)
   {
      if(raw_delta[i]>0.0) delta_buy_steps++;
      else if(raw_delta[i]<0.0) delta_sell_steps++;
   }
   const bool delta_long_participation=
      delta_change>0.0 &&
      delta_buy_steps>=2;
   const bool delta_short_participation=
      delta_change<0.0 &&
      delta_sell_steps>=2;

   // v8.212 WATCH-owned chart-only WEAK information signal.
   // Deliberately NO Raw-MACD absolute/zero-side threshold is used.
   // Candidate calculation is independent, but publication authority belongs
   // to the most recent canonical WATCH and only from a later completed bar.
   const bool long_weak_candidate=
      macd_transition_down &&
      delta_short_participation &&
      structure_lower_high;
   const bool short_weak_candidate=
      macd_transition_up &&
      delta_long_participation &&
      structure_higher_low;

   bool weak_pulse=false;
   int weak_side=0;

   const bool recent_against_up=(recent_progress<0.0 && rates[1].close<rates[2].close);
   const bool recent_against_down=(recent_progress>0.0 && rates[1].close>rates[2].close);
   const bool short_transition_progress=
      macd_transition_down && recent_against_up;
   const bool long_transition_progress=
      macd_transition_up && recent_against_down;

   // Existing price-path recovery/resolution remains the background-state
   // authority. WATCH itself now reflects continuing transition progress.
   const double eps=_Point;
   const bool up_path_recovered=
      rates[1].high>rates[2].high+eps &&
      rates[1].close>rates[2].close+eps &&
      recent_progress>0.0;
   const bool down_path_recovered=
      rates[1].low<rates[2].low-eps &&
      rates[1].close<rates[2].close-eps &&
      recent_progress<0.0;

   double prior_short_low=rates[2].low;
   double prior_short_high=rates[2].high;
   const int structure_depth=MathMin(4,lookback);
   for(int i=3;i<=structure_depth;i++)
   {
      prior_short_low=MathMin(prior_short_low,rates[i].low);
      prior_short_high=MathMax(prior_short_high,rates[i].high);
   }
   const bool downside_structure_break=
      rates[1].close<prior_short_low-_Point && macd_change_1<0.0;
   const bool upside_structure_break=
      rates[1].close>prior_short_high+_Point && macd_change_1>0.0;

   const ENUM_JTA_ASSIST_STATE old_state=g_assist_state.state;
   ENUM_JTA_ASSIST_STATE new_state=old_state;
   string reason="STATE_CONTINUES";
   int anchor=g_assist_state.direction_anchor;
   bool post_gap_rearm=g_assist_state.post_discontinuity_rearm;

   // v8.229 ASSIST ownership cleanup. FINAL/persistence is no longer active;
   // WATCH->same-direction ACCEL confirms the established ASSIST direction.
   // The old anchor remains provisional only until that confirmation exists.
   const int established_side=g_assist_state.established_side;
   const int episode_side=(established_side!=0 ? established_side : anchor);
   if(established_side!=0)
      anchor=established_side;

   bool watch_pulse=false;
   bool watch_informational_repeat=false;
   bool watch_rearm_pulse=false;
   bool watch_suppress_event=false;
   bool watch_suppress_release=false;
   int watch_suppress_attempt_side=0;
   string watch_suppress_attempt_stage="NONE";
   string watch_suppress_attempt_reason="";
   double watch_suppress_attempt_progress3_r=0.0;
   double watch_suppress_attempt_aroon_spread=0.0;

   // v7.89 WATCH priority: MACD is the reversal-direction owner.
   // A LONG WATCH cannot start/flip while Final Wave is still below zero,
   // and a SHORT WATCH cannot start/flip while Final Wave is still above zero.
   // Price confirms that the transition exists in the market. Delta remains
   // participation/audit evidence only; it cannot authorize or veto WATCH.
   // Existing cached values are reused, so this adds no indicator/history read.
   const bool indicator_consensus_long =
      macd_wave[1]>0.0;
   const bool indicator_consensus_short =
      macd_wave[1]<0.0;

   const bool full_long_watch_candidate =
      macd_transition_up &&
      price_up;
   const bool full_short_watch_candidate =
      macd_transition_down &&
      price_down;

   const bool long_watch_priority_allowed =
      !indicator_consensus_short;
   const bool short_watch_priority_allowed =
      !indicator_consensus_long;

   const bool prioritized_long_watch_candidate =
      full_long_watch_candidate &&
      long_watch_priority_allowed;
   const bool prioritized_short_watch_candidate =
      full_short_watch_candidate &&
      short_watch_priority_allowed;

   // v8.273 same-direction WATCH episode lifecycle.  Continuous TRUE bars are
   // one candidate episode and must not spam repeated WATCH pulses.  Only a
   // completed-bar FALSE->TRUE edge starts a new episode.  A true data gap also
   // breaks continuity; normal post-gap rearm branches still retain priority.
   const bool long_watch_candidate_episode_start =
      prioritized_long_watch_candidate &&
      (!g_assist_prev_prioritized_long_watch_candidate || data_discontinuity);
   const bool short_watch_candidate_episode_start =
      prioritized_short_watch_candidate &&
      (!g_assist_prev_prioritized_short_watch_candidate || data_discontinuity);

   // v8.266: a rejected candidate is consumed only for the lifetime of the same
   // prioritized raw-candidate episode. Scheduled/true gaps break continuity.
   if(g_assist_suppressed_watch_candidate_active)
   {
      const int latched_side=g_assist_suppressed_watch_candidate_side;
      const bool candidate_still_active=
         (latched_side>0 ? prioritized_long_watch_candidate :
          (latched_side<0 ? prioritized_short_watch_candidate : false));
      if(data_discontinuity || !candidate_still_active)
      {
         g_assist_suppressed_watch_candidate_active=false;
         g_assist_suppressed_watch_candidate_side=0;
         watch_suppress_release=true;
      }
   }

   // v7.56: WATCH is reversal-only. The already-existing RANGE persistence is
   // the owner of the last established direction; transient UP/DOWN/NEUTRAL
   // price states must not redefine what "reversal" means. A fresh LONG WATCH
   // therefore exists only against an established SHORT episode, and vice
   // versa. Persistence==0 is a new/undetermined trend, not a reversal WATCH.
   const bool fresh_long_watch_context = post_gap_rearm || episode_side<0;
   const bool fresh_short_watch_context = post_gap_rearm || episode_side>0;

   // v8.247 canonical WATCH rearm ownership:
   // If an opposite canonical WATCH was actually published after the current
   // established episode began, that WATCH interrupts the established leg.
   // When the established direction later rebuilds its normal prioritized
   // WATCH candidate, publish exactly one same-direction WATCH to transfer
   // canonical ownership back.  This is lifecycle ownership only: no new
   // indicator threshold, bar-count timeout, recovery reason exception, or
   // legacy M3 pre-signal authority is introduced.
   const bool rearm_long_after_opposite_watch =
      established_side>0 &&
      g_assist_weak_watch_owner_side<0 &&
      g_assist_weak_watch_owner_time>0 &&
      (g_assist_state.established_time<=0 ||
       g_assist_weak_watch_owner_time>=g_assist_state.established_time) &&
      prioritized_long_watch_candidate;

   const bool rearm_short_after_opposite_watch =
      established_side<0 &&
      g_assist_weak_watch_owner_side>0 &&
      g_assist_weak_watch_owner_time>0 &&
      (g_assist_state.established_time<=0 ||
       g_assist_weak_watch_owner_time>=g_assist_state.established_time) &&
      prioritized_short_watch_candidate;

   // v8.252 REARM pre-zero recovery is EXIT-only evidence. Keep canonical
   // WATCH timing unchanged: full candidate must exist, MACD must still be on
   // the opposite zero-side, and price must have closed beyond the exact
   // opposite canonical WATCH owner-bar extreme. No threshold or new signal
   // owner is introduced.
   // v8.261: PRE-REARM recovery is anchored to the WATCH that actually
   // transferred execution ownership, not merely the latest informational
   // WATCH. This prevents NONE_SAME_SIDE_WATCH from tightening the recovery
   // high/low around an already-live position.
   const bool pre_rearm_exit_long =
      established_side>0 &&
      g_pre_rearm_execution_owner_side<0 &&
      g_pre_rearm_execution_owner_time>0 &&
      (g_assist_state.established_time<=0 ||
       g_pre_rearm_execution_owner_time>=g_assist_state.established_time) &&
      full_long_watch_candidate &&
      macd_wave[1]<0.0 &&
      g_pre_rearm_execution_owner_high>0.0 &&
      rates[1].close>g_pre_rearm_execution_owner_high;

   const bool pre_rearm_exit_short =
      established_side<0 &&
      g_pre_rearm_execution_owner_side>0 &&
      g_pre_rearm_execution_owner_time>0 &&
      (g_assist_state.established_time<=0 ||
       g_pre_rearm_execution_owner_time>=g_assist_state.established_time) &&
      full_short_watch_candidate &&
      macd_wave[1]>0.0 &&
      g_pre_rearm_execution_owner_low>0.0 &&
      rates[1].close<g_pre_rearm_execution_owner_low;

   // v8.229 WATCH confirmation is owned by same-direction ACCEL.
   // Retired FIRST FINAL/persistence is no longer an ASSIST lifecycle owner.

   // v7.89 transition-state WATCH:
   // MACD trajectory owns reversal direction. A NEW counter-direction WATCH
   // or opposite WATCH flip is promoted only when MACD has reached the new
   // zero-side and the existing full price_up/price_down structure confirms it.
   // Delta is retained only as participation/audit evidence.
   // Same-direction WATCH progress remains unchanged after promotion.
   // v8.259: do not infer ACCEL confirmation from established_side. REARM WATCH
   // intentionally starts in the already-established direction, so that test
   // falsely confirmed the WATCH on the next bar even when no ACCEL existed.
   // Actual confirmation is performed only by StateEvaluationConfirmEstablishedByAccel()
   // after a canonical later-bar ACCEL has been published.
   // v8.229 WATCH lifecycle ownership:
   // A reversal WATCH remains a transition until same-direction ACCEL confirms
   // that direction, or recovery/flip logic invalidates it.

   // v8.247: opposite WATCH interruption -> established-direction WATCH rearm.
   // These branches intentionally precede the v8.229 recovery branches so a
   // fully rebuilt prioritized candidate is published as the new canonical
   // WATCH instead of being silently consumed as DOWN/UP recovery.  The normal
   // StateEvaluation WATCH pulse path then owns chart/alarm/AUTO uniformly.
   if(rearm_long_after_opposite_watch)
   {
      watch_suppress_attempt_side=1;
      const bool blocked=StateEvaluationWatchPublishBlocked(1,aroon_osc_21,chop_14,
         observe_progress3_raw_r,observe_chop8_delta3,
         watch_suppress_attempt_stage,watch_suppress_attempt_reason,
         watch_suppress_attempt_progress3_r,watch_suppress_attempt_aroon_spread,
         watch_suppress_event);
      if(blocked)
      {
         new_state=old_state;
         watch_pulse=false;
         watch_rearm_pulse=false;
         reason="LONG_REARM_WATCH_SUPPRESSED_"+watch_suppress_attempt_reason;
      }
      else
      {
         new_state=JTA_ASSIST_REVERSAL_WATCH_UP;
         anchor=1;
         watch_pulse=true;
         watch_rearm_pulse=true;
         reason=StringFormat("LONG_REARM_AFTER_OPPOSITE_WATCH | WAVE2NET=%.2f WAVE1=%.2f RAW2NET=%.2f RAW1=%.2f RAWUP=%d/3 PRICE=%.2f DEMA2=%.2f DBUY=%d/3",
                             macd_wave_change_3,macd_wave_change_1,macd_change_3,macd_change_1,raw_up_steps,recent_progress,delta_change,delta_buy_steps);
      }
   }
   else if(rearm_short_after_opposite_watch)
   {
      watch_suppress_attempt_side=-1;
      const bool blocked=StateEvaluationWatchPublishBlocked(-1,aroon_osc_21,chop_14,
         observe_progress3_raw_r,observe_chop8_delta3,
         watch_suppress_attempt_stage,watch_suppress_attempt_reason,
         watch_suppress_attempt_progress3_r,watch_suppress_attempt_aroon_spread,
         watch_suppress_event);
      if(blocked)
      {
         new_state=old_state;
         watch_pulse=false;
         watch_rearm_pulse=false;
         reason="SHORT_REARM_WATCH_SUPPRESSED_"+watch_suppress_attempt_reason;
      }
      else
      {
         new_state=JTA_ASSIST_REVERSAL_WATCH_DOWN;
         anchor=-1;
         watch_pulse=true;
         watch_rearm_pulse=true;
         reason=StringFormat("SHORT_REARM_AFTER_OPPOSITE_WATCH | WAVE2NET=%.2f WAVE1=%.2f RAW2NET=%.2f RAW1=%.2f RAWDN=%d/3 PRICE=%.2f DEMA2=%.2f DSELL=%d/3",
                             macd_wave_change_3,macd_wave_change_1,macd_change_3,macd_change_1,raw_down_steps,recent_progress,delta_change,delta_sell_steps);
      }
   }

   // v8.229 transition ownership:
   // Returning to the still-established ASSIST direction is recovery,
   // not a brand-new opposite WATCH. Resolve recovery before considering a
   // true WATCH flip so short-lived reversal attempts do not restart the
   // original episode.
   else if(old_state==JTA_ASSIST_REVERSAL_WATCH_DOWN &&
           established_side>0 &&
           up_path_recovered && !macd_weak_for_up)
   {
      new_state=JTA_ASSIST_UP;
      anchor=1;
      watch_pulse=false;
      reason="WATCH_DOWN_CANCELLED_BY_UP_RECOVERY";
   }
   else if(old_state==JTA_ASSIST_REVERSAL_WATCH_UP &&
           established_side<0 &&
           down_path_recovered && !macd_weak_for_down)
   {
      new_state=JTA_ASSIST_DOWN;
      anchor=-1;
      watch_pulse=false;
      reason="WATCH_UP_CANCELLED_BY_DOWN_RECOVERY";
   }
   // v8.229: a full candidate back in the established direction is recovery,
   // not a new opposite WATCH. This restores the lifecycle that FIRST FINAL
   // used to own without reintroducing FINAL/persistence.
   else if(old_state==JTA_ASSIST_REVERSAL_WATCH_DOWN &&
           established_side>0 && prioritized_long_watch_candidate)
   {
      new_state=JTA_ASSIST_UP;
      anchor=1;
      watch_pulse=false;
      reason="WATCH_DOWN_CANCELLED_BY_ESTABLISHED_LONG";
   }
   else if(old_state==JTA_ASSIST_REVERSAL_WATCH_UP &&
           established_side<0 && prioritized_short_watch_candidate)
   {
      new_state=JTA_ASSIST_DOWN;
      anchor=-1;
      watch_pulse=false;
      reason="WATCH_UP_CANCELLED_BY_ESTABLISHED_SHORT";
   }
   else if(old_state==JTA_ASSIST_REVERSAL_WATCH_DOWN &&
           established_side!=1 &&
           long_transition_progress &&
           price_up &&
           long_watch_priority_allowed)
   {
      watch_suppress_attempt_side=1;
      const bool blocked=StateEvaluationWatchPublishBlocked(1,aroon_osc_21,chop_14,
         observe_progress3_raw_r,observe_chop8_delta3,
         watch_suppress_attempt_stage,watch_suppress_attempt_reason,
         watch_suppress_attempt_progress3_r,watch_suppress_attempt_aroon_spread,
         watch_suppress_event);
      if(blocked)
      {
         new_state=old_state;
         watch_pulse=false;
         reason="WATCH_FLIP_TO_LONG_SUPPRESSED_"+watch_suppress_attempt_reason;
      }
      else
      {
         new_state=JTA_ASSIST_REVERSAL_WATCH_UP;
         watch_pulse=true;
         reason=StringFormat("WATCH_FLIP_TO_LONG | WAVE2NET=%.2f WAVE1=%.2f RAW2NET=%.2f RAW1=%.2f RAWUP=%d/3 PRICE=%.2f DEMA2=%.2f DBUY=%d/3",
                             macd_wave_change_3,macd_wave_change_1,macd_change_3,macd_change_1,raw_up_steps,recent_progress,delta_change,delta_buy_steps);
      }
   }
   else if(old_state==JTA_ASSIST_REVERSAL_WATCH_UP &&
           established_side!=-1 &&
           short_transition_progress &&
           price_down &&
           short_watch_priority_allowed)
   {
      watch_suppress_attempt_side=-1;
      const bool blocked=StateEvaluationWatchPublishBlocked(-1,aroon_osc_21,chop_14,
         observe_progress3_raw_r,observe_chop8_delta3,
         watch_suppress_attempt_stage,watch_suppress_attempt_reason,
         watch_suppress_attempt_progress3_r,watch_suppress_attempt_aroon_spread,
         watch_suppress_event);
      if(blocked)
      {
         new_state=old_state;
         watch_pulse=false;
         reason="WATCH_FLIP_TO_SHORT_SUPPRESSED_"+watch_suppress_attempt_reason;
      }
      else
      {
         new_state=JTA_ASSIST_REVERSAL_WATCH_DOWN;
         watch_pulse=true;
         reason=StringFormat("WATCH_FLIP_TO_SHORT | WAVE2NET=%.2f WAVE1=%.2f RAW2NET=%.2f RAW1=%.2f RAWDN=%d/3 PRICE=%.2f DEMA2=%.2f DSELL=%d/3",
                             macd_wave_change_3,macd_wave_change_1,macd_change_3,macd_change_1,raw_down_steps,recent_progress,delta_change,delta_sell_steps);
      }
   }
   // v7.89 WATCH continuation ownership:
   // The same MACD zero-side ownership that controls WATCH START/FLIP also
   // controls whether an active WATCH may keep reversal authority. If MACD
   // returns to the still-established ASSIST side, the predictive WATCH
   // ends immediately. SignalEngine persistence is untouched; Delta remains
   // participation/audit evidence only.
   else if(old_state==JTA_ASSIST_REVERSAL_WATCH_UP &&
           established_side<0 &&
           indicator_consensus_short)
   {
      new_state=JTA_ASSIST_DOWN;
      anchor=-1;
      watch_pulse=false;
      reason="LONG_WATCH_RELEASED_BY_SHORT_INDICATOR_CONSENSUS";
   }
   else if(old_state==JTA_ASSIST_REVERSAL_WATCH_DOWN &&
           established_side>0 &&
           indicator_consensus_long)
   {
      new_state=JTA_ASSIST_UP;
      anchor=1;
      watch_pulse=false;
      reason="SHORT_WATCH_RELEASED_BY_LONG_INDICATOR_CONSENSUS";
   }
   // v8.262: a WATCH event must not monopolize StateEvaluation after its
   // direction is already the established direction.  Return the display/state
   // machine to the established UP/DOWN state without fabricating an ACCEL
   // confirmation.  The independent active ACCEL owner remains pending and can
   // still be confirmed later by a real same-direction canonical ACCEL.
   // Opposite WATCH flips and explicit recovery/cancel branches above keep
   // priority over this state-only release.
   else if(old_state==JTA_ASSIST_REVERSAL_WATCH_DOWN &&
           established_side<0)
   {
      new_state=JTA_ASSIST_DOWN;
      anchor=-1;
      watch_pulse=false;
      reason="SHORT_WATCH_RETURN_TO_ESTABLISHED";
   }
   else if(old_state==JTA_ASSIST_REVERSAL_WATCH_UP &&
           established_side>0)
   {
      new_state=JTA_ASSIST_UP;
      anchor=1;
      watch_pulse=false;
      reason="LONG_WATCH_RETURN_TO_ESTABLISHED";
   }
   // v8.273: a canonical reversal WATCH may remain the display state after its
   // raw prioritized candidate has actually ended.  If the same-direction
   // candidate later forms again after at least one completed FALSE bar, treat
   // that FALSE->TRUE edge as a new candidate episode and allow one new WATCH
   // publication.  Reuse the exact canonical suppression classifier; no WATCH
   // threshold, structure filter, timeout, or order exception is introduced.
   else if(old_state==JTA_ASSIST_REVERSAL_WATCH_UP &&
           fresh_long_watch_context &&
           long_watch_candidate_episode_start)
   {
      watch_suppress_attempt_side=1;
      const bool blocked=StateEvaluationWatchPublishBlocked(1,aroon_osc_21,chop_14,
         observe_progress3_raw_r,observe_chop8_delta3,
         watch_suppress_attempt_stage,watch_suppress_attempt_reason,
         watch_suppress_attempt_progress3_r,watch_suppress_attempt_aroon_spread,
         watch_suppress_event);
      if(blocked)
      {
         new_state=old_state;
         watch_pulse=false;
         reason="LONG_REPEAT_WATCH_EPISODE_SUPPRESSED_"+watch_suppress_attempt_reason;
      }
      else
      {
         new_state=JTA_ASSIST_REVERSAL_WATCH_UP;
         anchor=1;
         watch_pulse=true;
         watch_informational_repeat=true;
         reason=StringFormat("LONG_REPEAT_WATCH_EPISODE | WAVE2NET=%.2f WAVE1=%.2f RAW2NET=%.2f RAW1=%.2f RAWUP=%d/3 PRICE=%.2f DEMA2=%.2f DBUY=%d/3",
                             macd_wave_change_3,macd_wave_change_1,macd_change_3,macd_change_1,raw_up_steps,recent_progress,delta_change,delta_buy_steps);
      }
   }
   else if(old_state==JTA_ASSIST_REVERSAL_WATCH_DOWN &&
           fresh_short_watch_context &&
           short_watch_candidate_episode_start)
   {
      watch_suppress_attempt_side=-1;
      const bool blocked=StateEvaluationWatchPublishBlocked(-1,aroon_osc_21,chop_14,
         observe_progress3_raw_r,observe_chop8_delta3,
         watch_suppress_attempt_stage,watch_suppress_attempt_reason,
         watch_suppress_attempt_progress3_r,watch_suppress_attempt_aroon_spread,
         watch_suppress_event);
      if(blocked)
      {
         new_state=old_state;
         watch_pulse=false;
         reason="SHORT_REPEAT_WATCH_EPISODE_SUPPRESSED_"+watch_suppress_attempt_reason;
      }
      else
      {
         new_state=JTA_ASSIST_REVERSAL_WATCH_DOWN;
         anchor=-1;
         watch_pulse=true;
         watch_informational_repeat=true;
         reason=StringFormat("SHORT_REPEAT_WATCH_EPISODE | WAVE2NET=%.2f WAVE1=%.2f RAW2NET=%.2f RAW1=%.2f RAWDN=%d/3 PRICE=%.2f DEMA2=%.2f DSELL=%d/3",
                             macd_wave_change_3,macd_wave_change_1,macd_change_3,macd_change_1,raw_down_steps,recent_progress,delta_change,delta_sell_steps);
      }
   }
   else if(old_state==JTA_ASSIST_REVERSAL_WATCH_DOWN &&
           short_transition_progress)
   {
      new_state=JTA_ASSIST_REVERSAL_WATCH_DOWN;
      // Opposite-established reversal WATCH may persist while its transition
      // remains active. Same-side WATCH is released by the v8.262 branch above.
      watch_pulse=false;
      reason=StringFormat("SHORT_TRANSITION_PROGRESS | WAVE2NET=%.2f WAVE1=%.2f RAW2NET=%.2f RAW1=%.2f RAWDN=%d/3 PRICE=%.2f",
                          macd_wave_change_3,macd_wave_change_1,macd_change_3,macd_change_1,raw_down_steps,recent_progress);
   }
   else if(old_state==JTA_ASSIST_REVERSAL_WATCH_UP &&
           long_transition_progress)
   {
      new_state=JTA_ASSIST_REVERSAL_WATCH_UP;
      // Opposite-established reversal WATCH may persist while its transition
      // remains active. Same-side WATCH is released by the v8.262 branch above.
      watch_pulse=false;
      reason=StringFormat("LONG_TRANSITION_PROGRESS | WAVE2NET=%.2f WAVE1=%.2f RAW2NET=%.2f RAW1=%.2f RAWUP=%d/3 PRICE=%.2f",
                          macd_wave_change_3,macd_wave_change_1,macd_change_3,macd_change_1,raw_up_steps,recent_progress);
   }
   else if(old_state==JTA_ASSIST_REVERSAL_WATCH_DOWN)
   {
      new_state=JTA_ASSIST_REVERSAL_WATCH_DOWN;
      reason="SHORT_WATCH_CONTINUES";
   }
   else if(old_state==JTA_ASSIST_REVERSAL_WATCH_UP)
   {
      new_state=JTA_ASSIST_REVERSAL_WATCH_UP;
      reason="LONG_WATCH_CONTINUES";
   }
   // v7.55: fresh completed WATCH candidates are resolved BEFORE generic
   // path recovery / weakening / price-state branches. This prevents a valid
   // reversal from being consumed by NEUTRAL->UP/DOWN or PATH_RECOVERED.
   else if(fresh_long_watch_context && prioritized_long_watch_candidate)
   {
      watch_suppress_attempt_side=1;
      const bool blocked=StateEvaluationWatchPublishBlocked(1,aroon_osc_21,chop_14,
         observe_progress3_raw_r,observe_chop8_delta3,
         watch_suppress_attempt_stage,watch_suppress_attempt_reason,
         watch_suppress_attempt_progress3_r,watch_suppress_attempt_aroon_spread,
         watch_suppress_event);
      if(blocked)
      {
         new_state=old_state;
         watch_pulse=false;
         reason="LONG_TRANSITION_WATCH_SUPPRESSED_"+watch_suppress_attempt_reason;
      }
      else
      {
         new_state=JTA_ASSIST_REVERSAL_WATCH_UP;
         watch_pulse=true;
         const bool was_post_gap_rearm=post_gap_rearm;
         post_gap_rearm=false;

         // v8.277: if this same-direction WATCH owner already belongs to the
         // current established episode, a state-only WATCH->UP/DOWN release
         // must not let the next generic TRANSITION_START refresh canonical
         // WEAK/ACCEL/AUTO ownership. Keep the pulse information-only, exactly
         // like v8.274 repeat WATCH authority. Opposite-owner REARM/FLIP paths
         // are resolved earlier and therefore remain canonical.
         const bool same_side_owner_continuation=
            !was_post_gap_rearm &&
            g_assist_weak_watch_owner_side>0 &&
            g_assist_weak_watch_owner_time>0 &&
            (g_assist_state.established_time<=0 ||
             g_assist_weak_watch_owner_time>=g_assist_state.established_time);
         if(same_side_owner_continuation)
            watch_informational_repeat=true;

         reason=StringFormat("%s | WAVE2NET=%.2f WAVE1=%.2f RAW2NET=%.2f RAW1=%.2f RAWUP=%d/3 PRICE=%.2f DEMA2=%.2f DBUY=%d/3",
                             (was_post_gap_rearm ? "POST_GAP_LONG_REARM_WATCH" :
                              (same_side_owner_continuation ? "LONG_SAME_SIDE_WATCH_CONTINUATION" : "LONG_TRANSITION_START_PRIORITY")),
                             macd_wave_change_3,macd_wave_change_1,macd_change_3,macd_change_1,raw_up_steps,recent_progress,delta_change,delta_buy_steps);
      }
   }
   else if(fresh_short_watch_context && prioritized_short_watch_candidate)
   {
      watch_suppress_attempt_side=-1;
      const bool blocked=StateEvaluationWatchPublishBlocked(-1,aroon_osc_21,chop_14,
         observe_progress3_raw_r,observe_chop8_delta3,
         watch_suppress_attempt_stage,watch_suppress_attempt_reason,
         watch_suppress_attempt_progress3_r,watch_suppress_attempt_aroon_spread,
         watch_suppress_event);
      if(blocked)
      {
         new_state=old_state;
         watch_pulse=false;
         reason="SHORT_TRANSITION_WATCH_SUPPRESSED_"+watch_suppress_attempt_reason;
      }
      else
      {
         new_state=JTA_ASSIST_REVERSAL_WATCH_DOWN;
         watch_pulse=true;
         const bool was_post_gap_rearm=post_gap_rearm;
         post_gap_rearm=false;

         // v8.277: symmetric same-side canonical-owner continuation guard.
         const bool same_side_owner_continuation=
            !was_post_gap_rearm &&
            g_assist_weak_watch_owner_side<0 &&
            g_assist_weak_watch_owner_time>0 &&
            (g_assist_state.established_time<=0 ||
             g_assist_weak_watch_owner_time>=g_assist_state.established_time);
         if(same_side_owner_continuation)
            watch_informational_repeat=true;

         reason=StringFormat("%s | WAVE2NET=%.2f WAVE1=%.2f RAW2NET=%.2f RAW1=%.2f RAWDN=%d/3 PRICE=%.2f DEMA2=%.2f DSELL=%d/3",
                             (was_post_gap_rearm ? "POST_GAP_SHORT_REARM_WATCH" :
                              (same_side_owner_continuation ? "SHORT_SAME_SIDE_WATCH_CONTINUATION" : "SHORT_TRANSITION_START_PRIORITY")),
                             macd_wave_change_3,macd_wave_change_1,macd_change_3,macd_change_1,raw_down_steps,recent_progress,delta_change,delta_sell_steps);
      }
   }
   // v7.67: when no persistent/anchored episode exists, the first full
   // three-domain directional candidate establishes an episode anchor without
   // calling it a reversal WATCH. A later opposite full candidate may then use
   // that same anchor as reversal context.
   else if(established_side==0 && anchor==0 &&
           full_long_watch_candidate)
   {
      new_state=JTA_ASSIST_UP;
      anchor=1;
      reason="FULL_DIRECTION_ANCHOR_LONG";
   }
   else if(established_side==0 && anchor==0 &&
           full_short_watch_candidate)
   {
      new_state=JTA_ASSIST_DOWN;
      anchor=-1;
      reason="FULL_DIRECTION_ANCHOR_SHORT";
   }
   else if(episode_side>0 && up_path_recovered && !macd_weak_for_up)
   {
      new_state=JTA_ASSIST_UP;
      anchor=1;
      reason="UP_PATH_RECOVERED";
   }
   else if(episode_side<0 && down_path_recovered && !macd_weak_for_down)
   {
      new_state=JTA_ASSIST_DOWN;
      anchor=-1;
      reason="DOWN_PATH_RECOVERED";
   }
   else if(episode_side>0 && ((recent_progress<=0.10 && macd_weak_for_up) ||
                       (macd_weak_for_up && delta_weak_for_up)))
   {
      new_state=JTA_ASSIST_UP_WEAKENING;
      reason="UP_MOMENTUM_WEAKENING";
   }
   else if(episode_side<0 && ((recent_progress>=-0.10 && macd_weak_for_down) ||
                       (macd_weak_for_down && delta_weak_for_down)))
   {
      new_state=JTA_ASSIST_DOWN_WEAKENING;
      reason="DOWN_MOMENTUM_WEAKENING";
   }
   // v7.70 episode-owned fallback:
   // Generic price-path evidence must never contradict an already-established
   // episode anchor.  A counter-direction price path without a full
   // MACD+Price WATCH is weakening/transition evidence, not a new
   // directional state.  When no episode anchor exists, price alone is not
   // sufficient to establish UP/DOWN; the full three-domain anchor branches
   // above own that responsibility.
   else if(episode_side>0 && price_up)
   {
      new_state=JTA_ASSIST_UP;
      reason="EPISODE_LONG_PRICE_PATH_CONTINUES";
   }
   else if(episode_side<0 && price_down)
   {
      new_state=JTA_ASSIST_DOWN;
      reason="EPISODE_SHORT_PRICE_PATH_CONTINUES";
   }
   else if(episode_side>0 && price_down)
   {
      new_state=JTA_ASSIST_UP_WEAKENING;
      reason="EPISODE_LONG_COUNTER_PRICE_WEAKENING";
   }
   else if(episode_side<0 && price_up)
   {
      new_state=JTA_ASSIST_DOWN_WEAKENING;
      reason="EPISODE_SHORT_COUNTER_PRICE_WEAKENING";
   }
   else
   {
      new_state=JTA_ASSIST_NEUTRAL;
      reason=(anchor==0 ? "NO_ESTABLISHED_EPISODE" : "NO_CLEAR_PRICE_PATH");
   }

   // v8.280 diagnostic-only opposite WATCH lead shadow. This intentionally
   // observes the first edge of current-direction WEAKENING + opposite
   // transition progress before canonical WATCH publication. It NEVER changes
   // state, ownership, chart, alert or AUTO authority. RANGE_TRANSITION and
   // LATE_BURST are recorded as classifications only so later CSV research can
   // decide whether an earlier publish is safe without weakening canonical gates.
   int early_opposite_side=0;
   if(!watch_pulse && established_side>0 &&
      new_state==JTA_ASSIST_UP_WEAKENING &&
      short_transition_progress && price_down)
      early_opposite_side=-1;
   else if(!watch_pulse && established_side<0 &&
           new_state==JTA_ASSIST_DOWN_WEAKENING &&
           long_transition_progress && price_up)
      early_opposite_side=1;

   bool early_opposite_shadow=(early_opposite_side!=0);
   bool early_opposite_pulse=false;
   string early_opposite_stage="NONE";
   string early_opposite_classification="";
   double early_progress3_r=0.0;
   double early_aroon_spread=0.0;
   if(early_opposite_shadow)
   {
      StateEvaluationClassifyWatchCandidate(early_opposite_side,aroon_osc_21,chop_14,
         observe_progress3_raw_r,observe_chop8_delta3,
         early_opposite_stage,early_opposite_classification,
         early_progress3_r,early_aroon_spread);
      early_opposite_pulse=(!g_assist_early_opposite_active ||
                            g_assist_early_opposite_side!=early_opposite_side);
      g_assist_early_opposite_active=true;
      g_assist_early_opposite_side=early_opposite_side;
   }
   else
   {
      g_assist_early_opposite_active=false;
      g_assist_early_opposite_side=0;
   }

   // v8.283: independent research lifecycle; same-side pulses advance age.
   bool trend_reassertion_target_recovered_pulse=false;
   bool trend_reassertion_cancel_pulse=false;
   string review_end_reason="";
   datetime review_ended_start=0;
   int review_ended_side=0;
   ReviewTrackerStep(g_review_tracker,closed_bar,early_opposite_pulse,
      early_opposite_side,watch_pulse,data_discontinuity,
      long_transition_progress,short_transition_progress,
      trend_reassertion_target_recovered_pulse,trend_reassertion_cancel_pulse,
      review_end_reason,review_ended_start,review_ended_side);
   g_assist_early_candidate_track_active=g_review_tracker.active;
   g_assist_early_candidate_track_side=g_review_tracker.side;
   g_assist_early_candidate_start_time=g_review_tracker.start;
   g_assist_early_candidate_age_bars=g_review_tracker.age;
   g_assist_trend_reassertion_pending=g_review_tracker.pending;
   g_assist_trend_reassertion_side=(g_review_tracker.pending ? -g_review_tracker.side : 0);
   g_assist_trend_reassertion_age_bars=g_review_tracker.pending_age;

   double review_adx14=0.0;
   const bool review_adx_valid=ReviewReadADX14(source_start+1,review_adx14);
   const int review_seconds=PeriodSeconds(StateEvaluationTimeframe());
   const bool review_continuous=(review_seconds>0 &&
      rates[1].time-rates[2].time==review_seconds &&
      rates[2].time-rates[3].time==review_seconds &&
      rates[3].time-rates[4].time==review_seconds);
   const double review_high=MathMax(rates[2].high,MathMax(rates[3].high,rates[4].high));
   const double review_low=MathMin(rates[2].low,MathMin(rates[3].low,rates[4].low));
   const bool review_break3=(review_continuous &&
      ((early_opposite_side>0 && rates[1].close>review_high) ||
       (early_opposite_side<0 && rates[1].close<review_low)));
   g_assist_state.review_shadow_end_reason=review_end_reason;
   g_assist_state.review_shadow_ended_start=review_ended_start;
   g_assist_state.review_shadow_ended_side=review_ended_side;
   g_assist_state.review_adx14=review_adx14;
   g_assist_state.review_adx14_valid=review_adx_valid;
   g_assist_state.review_price_break3=review_break3;
   g_assist_state.review_qualified_early_opposite=(early_opposite_pulse &&
      review_break3 && review_adx_valid && review_adx14>=25.0);
   g_assist_state.review_add_block_option=InpReviewBlockAddOnQualifiedOpposite;
   g_assist_state.review_add_blocked=false;

   // v8.212 canonical WATCH owns subsequent WEAK publication.
   // Same-bar WEAK is intentionally forbidden: owner_time must be earlier.
   if(watch_pulse && !watch_informational_repeat && new_state==JTA_ASSIST_REVERSAL_WATCH_UP)
   {
      g_assist_weak_watch_owner_side=1;
      g_assist_weak_watch_owner_time=closed_bar;
      g_assist_weak_watch_owner_high=rates[1].high;
      g_assist_weak_watch_owner_low=rates[1].low;
      g_assist_long_weak_armed=true;
      g_assist_short_weak_armed=false;

      // v8.259: every canonical WATCH starts a fresh pending ACCEL authority.
      // Historical WATCH metadata above is retained even if this attempt later
      // fails; only this active authority is invalidated on pre-ACCEL cancel.
      g_assist_accel_owner_side=1;
      g_assist_accel_owner_watch_time=closed_bar;
      g_assist_accel_owner_confirmed=false;
   }
   else if(watch_pulse && !watch_informational_repeat && new_state==JTA_ASSIST_REVERSAL_WATCH_DOWN)
   {
      g_assist_weak_watch_owner_side=-1;
      g_assist_weak_watch_owner_time=closed_bar;
      g_assist_weak_watch_owner_high=rates[1].high;
      g_assist_weak_watch_owner_low=rates[1].low;
      g_assist_short_weak_armed=true;
      g_assist_long_weak_armed=false;

      g_assist_accel_owner_side=-1;
      g_assist_accel_owner_watch_time=closed_bar;
      g_assist_accel_owner_confirmed=false;
   }
   else if(g_assist_accel_owner_side!=0 &&
           !g_assist_accel_owner_confirmed &&
           g_assist_accel_owner_watch_time>0)
   {
      // v8.259: leaving the literal WATCH display state is not itself a failed
      // WATCH attempt. Keep pending ACCEL authority alive until StateEvaluation
      // produces explicit recovery/cancellation evidence. A new WATCH pulse is
      // handled above and replaces the owner directly. Historical WATCH metadata
      // remains untouched for REARM/PRE-REARM semantics.
      const bool pending_long_cancelled=(g_assist_accel_owner_side>0 &&
         (reason=="WATCH_UP_CANCELLED_BY_DOWN_RECOVERY" ||
          reason=="WATCH_UP_CANCELLED_BY_ESTABLISHED_SHORT" ||
          reason=="LONG_WATCH_RELEASED_BY_SHORT_INDICATOR_CONSENSUS"));
      const bool pending_short_cancelled=(g_assist_accel_owner_side<0 &&
         (reason=="WATCH_DOWN_CANCELLED_BY_UP_RECOVERY" ||
          reason=="WATCH_DOWN_CANCELLED_BY_ESTABLISHED_LONG" ||
          reason=="SHORT_WATCH_RELEASED_BY_LONG_INDICATOR_CONSENSUS"));
      if(pending_long_cancelled || pending_short_cancelled)
      {
         g_assist_accel_owner_side=0;
         g_assist_accel_owner_watch_time=0;
         g_assist_accel_owner_confirmed=false;
      }
   }

   const bool long_weak_owned=
      g_assist_weak_watch_owner_side==1 &&
      g_assist_weak_watch_owner_time>0 &&
      closed_bar>g_assist_weak_watch_owner_time;
   const bool short_weak_owned=
      g_assist_weak_watch_owner_side==-1 &&
      g_assist_weak_watch_owner_time>0 &&
      closed_bar>g_assist_weak_watch_owner_time;

   if(long_weak_owned && g_assist_long_weak_armed && long_weak_candidate)
   {
      weak_pulse=true;
      weak_side=1;
      g_assist_long_weak_armed=false;
   }
   else if(short_weak_owned && g_assist_short_weak_armed && short_weak_candidate)
   {
      weak_pulse=true;
      weak_side=-1;
      g_assist_short_weak_armed=false;
   }

   // Rearm only the WATCH-owned WEAK side after price + MACD Wave recovery.
   // Raw MACD remains intentionally absent from the WEAK lifecycle.
   if(long_weak_owned && !long_weak_candidate && !g_assist_long_weak_armed &&
      price_up && wave_current_up)
      g_assist_long_weak_armed=true;
   if(short_weak_owned && !short_weak_candidate && !g_assist_short_weak_armed &&
      price_down && wave_current_down)
      g_assist_short_weak_armed=true;

   // v8.266 canonical WATCH classifier. Published WATCH rows and suppressed
   // publication attempts use the exact same calculation so CSV can reconstruct
   // what changed from v8.264 without a second indicator/history pass.
   bool observe_watch_original=false;
   bool observe_watch_new_candidate=false;
   string observe_watch_stage="NONE";
   string observe_watch_suppress_reason="";
   double observe_watch_progress3_r=0.0;
   double observe_watch_aroon_spread=0.0;
   if(watch_suppress_attempt_side!=0 && !watch_pulse)
   {
      observe_watch_original=true;
      observe_watch_new_candidate=false;
      observe_watch_stage=watch_suppress_attempt_stage;
      observe_watch_suppress_reason=watch_suppress_attempt_reason;
      observe_watch_progress3_r=watch_suppress_attempt_progress3_r;
      observe_watch_aroon_spread=watch_suppress_attempt_aroon_spread;
   }
   else if(watch_pulse && (new_state==JTA_ASSIST_REVERSAL_WATCH_UP ||
                           new_state==JTA_ASSIST_REVERSAL_WATCH_DOWN))
   {
      observe_watch_original=true;
      const int observe_side=(new_state==JTA_ASSIST_REVERSAL_WATCH_UP ? 1 : -1);
      StateEvaluationClassifyWatchCandidate(observe_side,aroon_osc_21,chop_14,
         observe_progress3_raw_r,observe_chop8_delta3,
         observe_watch_stage,observe_watch_suppress_reason,
         observe_watch_progress3_r,observe_watch_aroon_spread);
      observe_watch_new_candidate=true;
      // A published WATCH is never marked suppressed, even if the raw quality
      // threshold would theoretically match after a lifecycle/state change.
      observe_watch_suppress_reason="";
   }

   g_assist_state.previous_state=old_state;
   g_assist_state.state=new_state;
   g_assist_state.bar_time=closed_bar;
   g_assist_state.timeframe=StateEvaluationTimeframe();
   g_assist_state.direction_anchor=anchor;
   g_assist_state.open_price=rates[1].open;
   g_assist_state.high_price=rates[1].high;
   g_assist_state.low_price=rates[1].low;
   g_assist_state.close_price=rates[1].close;
   g_assist_state.macd_zero_state=(macd_zero_state[1]>0.5 ? 1 : (macd_zero_state[1]<-0.5 ? -1 : 0));
   g_assist_state.source_volume=source_volume[1];
   g_assist_state.avg_range=avg_range;
   g_assist_state.net_progress_r=net_progress;
   g_assist_state.recent_progress_r=recent_progress;
   g_assist_state.price_travel_3_r=price_travel_3_r;
   g_assist_state.price_efficiency_3=price_efficiency_3;
   g_assist_state.macd_zero_flip_count_5=macd_zero_flip_count_5;
   g_assist_state.chop_8=chop_8;
   g_assist_state.chop_14=chop_14;
   g_assist_state.chop_21=chop_21;
   g_assist_state.aroon_up_21=aroon_up_21;
   g_assist_state.aroon_down_21=aroon_down_21;
   g_assist_state.aroon_osc_21=aroon_osc_21;
   g_assist_state.watch_observe_original=observe_watch_original;
   g_assist_state.watch_observe_new_candidate=observe_watch_new_candidate;
   g_assist_state.watch_observe_stage=observe_watch_stage;
   g_assist_state.watch_observe_suppress_reason=observe_watch_suppress_reason;
   g_assist_state.watch_observe_progress3_r=observe_watch_progress3_r;
   g_assist_state.watch_observe_chop8_delta3=observe_chop8_delta3;
   g_assist_state.watch_observe_chop14=chop_14;
   g_assist_state.watch_observe_aroon_spread=observe_watch_aroon_spread;
   g_assist_state.watch_suppress_latch_active=g_assist_suppressed_watch_candidate_active;
   g_assist_state.watch_suppress_latch_side=g_assist_suppressed_watch_candidate_side;
   g_assist_state.watch_suppress_event=watch_suppress_event;
   g_assist_state.watch_suppress_release=watch_suppress_release;
   g_assist_state.higher_high_steps=higher_high_steps;
   g_assist_state.higher_low_steps=higher_low_steps;
   g_assist_state.lower_high_steps=lower_high_steps;
   g_assist_state.lower_low_steps=lower_low_steps;
   g_assist_state.recent_swing_high=recent_swing_high;
   g_assist_state.recent_swing_low=recent_swing_low;
   g_assist_state.older_swing_high=older_swing_high;
   g_assist_state.older_swing_low=older_swing_low;
   g_assist_state.structure_higher_low=structure_higher_low;
   g_assist_state.structure_lower_high=structure_lower_high;
   g_assist_state.pullback_long_ready=pullback_long_ready;
   g_assist_state.pullback_short_ready=pullback_short_ready;
   g_assist_state.continuation_break_high=recent_swing_high;
   g_assist_state.continuation_break_low=recent_swing_low;
   g_assist_state.up_close_steps=up_close_steps;
   g_assist_state.down_close_steps=down_close_steps;
   g_assist_state.raw_macd=raw_macd[1];
   g_assist_state.macd_base=macd_base[1];
   g_assist_state.macd_wave=macd_wave[1];
   g_assist_state.macd_wave_change_1=macd_wave_change_1;
   g_assist_state.macd_wave_change_3=macd_wave_change_3;
   g_assist_state.macd_base_change_1=macd_base_change_1;
   g_assist_state.macd_base_change_3=macd_base_change_3;
   g_assist_state.macd_base_travel_3=macd_base_travel_3;
   g_assist_state.macd_base_efficiency_3=macd_base_efficiency_3;
   g_assist_state.macd_wave_travel_3=macd_wave_travel_3;
   g_assist_state.macd_wave_efficiency_3=macd_wave_efficiency_3;
   g_assist_state.macd_change_1=macd_change_1;
   g_assist_state.macd_change_3=macd_change_3;
   g_assist_state.raw_up_steps=raw_up_steps;
   g_assist_state.raw_down_steps=raw_down_steps;
   g_assist_state.macd_transition_progress=macd_transition_progress;
   g_assist_state.macd_direction=macd_dir;
   g_assist_state.macd_transition_up=macd_transition_up;
   g_assist_state.macd_transition_down=macd_transition_down;
   g_assist_state.long_transition_progress=long_transition_progress;
   g_assist_state.short_transition_progress=short_transition_progress;
   g_assist_state.early_opposite_watch_shadow=early_opposite_shadow;
   g_assist_state.early_opposite_watch_pulse=early_opposite_pulse;
   g_assist_state.early_opposite_watch_side=early_opposite_side;
   g_assist_state.early_opposite_watch_stage=early_opposite_stage;
   g_assist_state.early_opposite_watch_classification=early_opposite_classification;
   g_assist_state.early_candidate_track_active=g_assist_early_candidate_track_active;
   g_assist_state.early_candidate_track_side=g_assist_early_candidate_track_side;
   g_assist_state.early_candidate_start_time=g_assist_early_candidate_start_time;
   g_assist_state.early_candidate_age_bars=g_assist_early_candidate_age_bars;
   g_assist_state.trend_reassertion_pending=g_assist_trend_reassertion_pending;
   g_assist_state.trend_reassertion_side=g_assist_trend_reassertion_side;
   g_assist_state.trend_reassertion_age_bars=g_assist_trend_reassertion_age_bars;
   g_assist_state.trend_reassertion_target_recovered_pulse=trend_reassertion_target_recovered_pulse;
   g_assist_state.trend_reassertion_cancel_pulse=trend_reassertion_cancel_pulse;
   g_assist_state.watch_pulse=watch_pulse;
   g_assist_state.watch_informational_repeat=watch_informational_repeat;
   g_assist_state.watch_rearm_pulse=watch_rearm_pulse;
   g_assist_state.post_discontinuity_rearm=post_gap_rearm;
   g_assist_state.raw_delta=raw_delta[1];
   g_assist_state.ema_delta=ema_delta[1];
   g_assist_state.delta_change=delta_change;
   g_assist_state.delta_buy_steps=delta_buy_steps;
   g_assist_state.delta_sell_steps=delta_sell_steps;
   g_assist_state.delta_long_participation=delta_long_participation;
   g_assist_state.delta_short_participation=delta_short_participation;
   g_assist_state.weak_pulse=weak_pulse;
   g_assist_state.weak_side=weak_side;
   // v7.66: publish the already-computed price/full-transition evidence so
   // SignalEngine can reuse the exact StateEvaluation decision without any
   // second indicator/history pass.
   g_assist_state.price_up=price_up;
   g_assist_state.price_down=price_down;
   g_assist_state.full_long_watch_candidate=full_long_watch_candidate;
   g_assist_state.full_short_watch_candidate=full_short_watch_candidate;
   g_assist_state.pre_rearm_exit_long=pre_rearm_exit_long;
   g_assist_state.pre_rearm_exit_short=pre_rearm_exit_short;
   g_assist_state.flip_path_oscillatory=flip_path_oscillatory;
   g_assist_state.flip_raw_path_directional=flip_raw_path_directional;
   g_assist_state.flip_wave_path_directional=flip_wave_path_directional;
   g_assist_state.flip_raw_path_direction=raw_last_sign;
   g_assist_state.flip_wave_path_direction=wave_last_sign;
   g_assist_state.flip_raw_efficiency_5=raw_efficiency_5;
   g_assist_state.flip_wave_efficiency_5=wave_efficiency_5;
   g_assist_state.flip_hold_active=false;
   g_assist_state.flip_hold_contested=false;
   g_assist_state.flip_hold_side=0;
   g_assist_state.flip_hold_action="RETIRED_V8_253";
   g_assist_state.changed=(new_state!=old_state || watch_pulse);
   g_assist_state.reason=reason;

   // v8.273: advance raw candidate episode memory only after this completed
   // bar has been fully evaluated. Historical warmup therefore rebuilds the
   // exact same edge state chronologically without persistence or look-ahead.
   g_assist_prev_prioritized_long_watch_candidate=prioritized_long_watch_candidate;
   g_assist_prev_prioritized_short_watch_candidate=prioritized_short_watch_candidate;

   // v8.30 diagnostic-only StateEvaluation pre-reversal lifecycle.
   // No strategy/state authority is added; the event is derived from the
   // already-finalized old/new state and WATCH pulse.
   const bool old_pre_long=(old_state==JTA_ASSIST_REVERSAL_WATCH_UP);
   const bool old_pre_short=(old_state==JTA_ASSIST_REVERSAL_WATCH_DOWN);
   const bool new_pre_long=(new_state==JTA_ASSIST_REVERSAL_WATCH_UP);
   const bool new_pre_short=(new_state==JTA_ASSIST_REVERSAL_WATCH_DOWN);
   if(!historical_replay && watch_pulse && (new_pre_long || new_pre_short))
   {
      const int pre_side=(new_pre_long ? 1 : -1);
      string pre_event="REPEAT";
      if(!(old_pre_long || old_pre_short)) pre_event="START";
      else if((old_pre_long && new_pre_short) || (old_pre_short && new_pre_long)) pre_event="FLIP";
      DataExportWritePreReversalLifecycleAudit(closed_bar,StateEvaluationTimeframe(),pre_event,pre_side,reason);
   }
   else if(!historical_replay &&
           (old_pre_long || old_pre_short) && !(new_pre_long || new_pre_short))
   {
      // v8.259: a WATCH display-state transition is not automatically a WATCH
      // lifecycle cancellation. Audit CANCEL only when the same explicit
      // recovery/consensus evidence that invalidates the pending ACCEL owner
      // is present, so CSV reconstruction matches execution ownership.
      const bool explicit_long_cancel=(old_pre_long &&
         (reason=="WATCH_UP_CANCELLED_BY_DOWN_RECOVERY" ||
          reason=="WATCH_UP_CANCELLED_BY_ESTABLISHED_SHORT" ||
          reason=="LONG_WATCH_RELEASED_BY_SHORT_INDICATOR_CONSENSUS"));
      const bool explicit_short_cancel=(old_pre_short &&
         (reason=="WATCH_DOWN_CANCELLED_BY_UP_RECOVERY" ||
          reason=="WATCH_DOWN_CANCELLED_BY_ESTABLISHED_LONG" ||
          reason=="SHORT_WATCH_RELEASED_BY_LONG_INDICATOR_CONSENSUS"));
      if(explicit_long_cancel || explicit_short_cancel)
         DataExportWritePreReversalLifecycleAudit(closed_bar,StateEvaluationTimeframe(),"CANCEL",old_pre_long?1:-1,reason);
   }

   return true;
}

bool StateEvaluationUpdateOnClosedBar()
{
   return StateEvaluationUpdateAtClosedShift(1,false);
}

bool StateEvaluationWarmupRebuild()
{
   // v8.227: when canonical M3 is active, replay StateEvaluation and M3Segment
   // together so historical replay follows the exact live StateEvaluation order.
   if(M3AutoEngineIsActive())
      return M3AssistWarmupRebuild();

   if(g_assist_macd_handle==INVALID_HANDLE || g_assist_delta_handle==INVALID_HANDLE)
      return false;

   const int requested=MathMax(64,InpM3StructureWarmupBars);
   const int ceiling=MathMax(requested,InpM3StructureWarmupMaxBars);
   if(!EnsureMarketSnapshotAssist(ceiling+64))
      return false;
   const int available=MathMin(ceiling,ArraySize(g_ms_rates)-64);
   if(available<32)
      return false;

   StateEvaluationReset();
   g_assist_history_replay=true;
   int replayed=0;
   for(int shift=available; shift>=1; --shift)
      if(StateEvaluationUpdateAtClosedShift(shift,true)) replayed++;
   g_assist_history_replay=false;

   g_assist_state.turn_pre_signal=false;
   g_assist_state.turn_pre_side=0;
   g_assist_state.review_qualified_early_opposite=false;
   g_assist_state.review_add_blocked=false;
   g_assist_state.watch_pulse=false;
   g_assist_state.early_opposite_watch_pulse=false;
   g_assist_state.trend_reassertion_target_recovered_pulse=false;
   g_assist_state.trend_reassertion_cancel_pulse=false;
   g_assist_state.watch_informational_repeat=false;
   g_assist_state.watch_rearm_pulse=false;
   g_assist_state.weak_pulse=false;
   g_assist_state.weak_side=0;
   g_assist_state.changed=false;
   g_assist_state.flip_hold_action="RETIRED_V8_253";
   PrintFormat("[ASSIST WARMUP] replayed=%d | bars=%d | final_bar=%s | state=%s | anchor=%d",
               replayed,available,
               TimeToString(g_assist_state.bar_time,TIME_DATE|TIME_MINUTES),
               AssistStateName(g_assist_state.state),
               g_assist_state.direction_anchor);
   return replayed>0;
}

// Cheap per-tick gate: integer time-bucket comparison only. CopyRates and
// CopyBuffer are called only after the selected assist timeframe advances.
// v8.228 live-start cursor parity: startup warm-up/fallback already consumes
// the latest closed assist bar. Mark the current timeframe bucket as consumed
// so the first live tick does not evaluate shift=1 a second time.
void StateEvaluationMarkCurrentBucketConsumed()
{
   const int seconds=PeriodSeconds(StateEvaluationTimeframe());
   if(seconds<=0)
      return;
   const datetime now=TimeCurrent();
   const datetime bucket=(datetime)(((long)now/seconds)*seconds);
   if(bucket>0)
      g_assist_state_bucket=bucket;
}

bool StateEvaluationProcessIfNewBar()
{
   // v8.03: always keep the shared AUTO structure snapshot current. UI and
   // manual-assist consumers remain independently gated by InpAssistStateEnabled.
   const int seconds=PeriodSeconds(StateEvaluationTimeframe());
   if(seconds<=0)
      return false;
   const datetime now=TimeCurrent();
   const datetime bucket=(datetime)(((long)now/seconds)*seconds);
   if(bucket<=0 || bucket==g_assist_state_bucket)
      return false;

   // Commit the bucket only after the closed-bar snapshot is actually ready.
   // If history/indicator buffers are still synchronizing on the first tick of
   // a new timeframe bucket, the next tick retries instead of skipping the
   // entire assist bar.
   if(!StateEvaluationUpdateOnClosedBar())
      return false;

   g_assist_state_bucket=bucket;
   return true;
}

#endif // __JOON_STATE_EVALUATION_ENGINE_MQH__
