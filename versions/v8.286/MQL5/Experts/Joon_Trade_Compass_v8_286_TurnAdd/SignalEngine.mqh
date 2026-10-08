//+------------------------------------------------------------------+
//| SignalEngine.mqh                                             |
//| Joon Trend/Range AutoTrader modular component                    |
//+------------------------------------------------------------------+
#ifndef __JOON_SIGNALENGINE_MQH__
#define __JOON_SIGNALENGINE_MQH__

void StructuralResetSide(const int side); // v5.73 forward declaration for explicit lifecycle resets.

//+------------------------------------------------------------------+
//| Returns true while at least two of MACD, Delta and MA22/price   |
//| still support the direction of the managed position.            |
//+------------------------------------------------------------------+




//+------------------------------------------------------------------+
bool CalculateTradingTFTrendScores(int &long_score, int &short_score)
{
   long_score=0; short_score=0; const int count=6;
   double macd[],raw[],delta_ema[];
   ArrayResize(macd,count); ArrayResize(raw,count); ArrayResize(delta_ema,count);
   ArraySetAsSeries(macd,true); ArraySetAsSeries(raw,true); ArraySetAsSeries(delta_ema,true);
   if(g_macd_handle==INVALID_HANDLE || g_delta_handle==INVALID_HANDLE ||
      MarketDataCopyBuffer(g_macd_handle,JTC_MACD_BASE_BUFFER,0,count,macd)<count ||
      MarketDataCopyBuffer(g_delta_handle,2,0,count,raw)<count ||
      MarketDataCopyBuffer(g_delta_handle,3,0,count,delta_ema)<count) return false;
   const bool mu=macd[1]>macd[2] && macd[2]>=macd[3];
   const bool md=macd[1]<macd[2] && macd[2]<=macd[3];
   const bool mp=macd[1]>0.0, mn=macd[1]<0.0;
   const bool du=raw[1]>raw[2] && delta_ema[1]>=delta_ema[2];
   const bool dd=raw[1]<raw[2] && delta_ema[1]<=delta_ema[2];
   const bool dp=raw[1]>0.0 && delta_ema[1]>0.0;
   const bool dn=raw[1]<0.0 && delta_ema[1]<0.0;
   if(mu) long_score+=30; if(mp) long_score+=15; if(du) long_score+=30; if(dp) long_score+=15; if(macd[1]>macd[4]) long_score+=10;
   if(md) short_score+=30; if(mn) short_score+=15; if(dd) short_score+=30; if(dn) short_score+=15; if(macd[1]<macd[4]) short_score+=10;
   if(dn) long_score-=15; if(dp) short_score-=15; if(mn&&md) long_score-=10; if(mp&&mu) short_score-=10;
   long_score=MathMax(0,MathMin(100,long_score)); short_score=MathMax(0,MathMin(100,short_score));
   return true;
}

bool CalculateTradingTFTrendRestart(const int side,bool &pullback_seen,bool &restart_trigger)
{
   pullback_seen=false; restart_trigger=false; const int count=6;
   double macd[],raw[],delta_ema[],fast[]; MqlRates rates[];
   ArrayResize(macd,count); ArrayResize(raw,count); ArrayResize(delta_ema,count); ArrayResize(fast,count); ArrayResize(rates,count);
   ArraySetAsSeries(macd,true); ArraySetAsSeries(raw,true); ArraySetAsSeries(delta_ema,true); ArraySetAsSeries(fast,true); ArraySetAsSeries(rates,true);
   if(g_macd_handle==INVALID_HANDLE || g_delta_handle==INVALID_HANDLE || g_add_ma_handle==INVALID_HANDLE ||
      MarketDataCopyBuffer(g_macd_handle,JTC_MACD_BASE_BUFFER,0,count,macd)<count ||
      MarketDataCopyBuffer(g_delta_handle,2,0,count,raw)<count || MarketDataCopyBuffer(g_delta_handle,3,0,count,delta_ema)<count ||
      MarketDataCopyBuffer(g_add_ma_handle,0,0,count,fast)<count || MarketDataCopyRates(_Symbol,AUTO_TF,0,count,rates)<count) return false;
   double avg_range=0.0; for(int i=1;i<=4;i++) avg_range+=rates[i].high-rates[i].low; avg_range/=4.0;
   const double tol=avg_range*InpM4MA7TouchToleranceRange;
   if(side>0)
   {
      pullback_seen=rates[1].low<=fast[1]+tol || rates[2].low<=fast[2]+tol || rates[3].low<=fast[3]+tol;
      const bool ma7=rates[1].low<=fast[1]+tol && rates[1].close>fast[1] && fast[1]>=fast[2];
      const bool macd_ok=macd[1]>macd[2] && macd[2]<=macd[3];
      const bool delta_ok=raw[1]>raw[2] && raw[1]>0.0 && delta_ema[1]>=delta_ema[2];
      restart_trigger=ma7 && (!InpRequireM4MACDReExpansion||macd_ok) && (!InpRequireM4DeltaReExpansion||delta_ok);
   }
   else
   {
      pullback_seen=rates[1].high>=fast[1]-tol || rates[2].high>=fast[2]-tol || rates[3].high>=fast[3]-tol;
      const bool ma7=rates[1].high>=fast[1]-tol && rates[1].close<fast[1] && fast[1]<=fast[2];
      const bool macd_ok=macd[1]<macd[2] && macd[2]>=macd[3];
      const bool delta_ok=raw[1]<raw[2] && raw[1]<0.0 && delta_ema[1]<=delta_ema[2];
      restart_trigger=ma7 && (!InpRequireM4MACDReExpansion||macd_ok) && (!InpRequireM4DeltaReExpansion||delta_ok);
   }
   return true;
}

bool CalculateTradingTFDirectionScores(int &long_score, int &short_score)
{
   long_score = 0;
   short_score = 0;
   const int count = 6;
   double macd[], raw[], delta_ema[];
   ArrayResize(macd, count); ArrayResize(raw, count); ArrayResize(delta_ema, count);
   ArraySetAsSeries(macd, true); ArraySetAsSeries(raw, true); ArraySetAsSeries(delta_ema, true);

   if(g_macd_handle == INVALID_HANDLE || g_delta_handle == INVALID_HANDLE ||
      MarketDataCopyBuffer(g_macd_handle, JTC_MACD_BASE_BUFFER, 0, count, macd) < count ||
      MarketDataCopyBuffer(g_delta_handle, 2, 0, count, raw) < count ||
      MarketDataCopyBuffer(g_delta_handle, 3, 0, count, delta_ema) < count)
      return false;

   const bool macd_up = macd[1] > macd[2] && macd[2] >= macd[3];
   const bool macd_down = macd[1] < macd[2] && macd[2] <= macd[3];
   const bool macd_positive = macd[1] > 0.0;
   const bool macd_negative = macd[1] < 0.0;
   const bool delta_up = raw[1] > raw[2] && delta_ema[1] >= delta_ema[2];
   const bool delta_down = raw[1] < raw[2] && delta_ema[1] <= delta_ema[2];
   const bool delta_positive = raw[1] > 0.0 && delta_ema[1] > 0.0;
   const bool delta_negative = raw[1] < 0.0 && delta_ema[1] < 0.0;

   if(macd_up) long_score += 30; if(macd_positive) long_score += 15;
   if(delta_up) long_score += 30; if(delta_positive) long_score += 15;
   if(macd[1] > macd[4]) long_score += 10;
   if(macd_down) short_score += 30; if(macd_negative) short_score += 15;
   if(delta_down) short_score += 30; if(delta_negative) short_score += 15;
   if(macd[1] < macd[4]) short_score += 10;
   if(delta_negative) long_score -= 15; if(delta_positive) short_score -= 15;
   if(macd_negative && macd_down) long_score -= 10;
   if(macd_positive && macd_up) short_score -= 10;
   long_score = MathMax(0, MathMin(100, long_score));
   short_score = MathMax(0, MathMin(100, short_score));
   g_trading_tf_long_direction_score = long_score;
   g_trading_tf_short_direction_score = short_score;
   return true;
}

bool TradingTFDirectionMaintained(const int side)
{
   if(!InpRequireTradingTFDirectionForAdd && !InpRequireTradingTFBiasForInitialEntry)
      return true;
   int long_score = 0, short_score = 0;
   if(!CalculateTradingTFDirectionScores(long_score, short_score))
      return false;
   if(side > 0)
      return long_score >= InpTradingTFDirectionMinimumScore &&
             long_score >= short_score + InpTradingTFDirectionMinimumGap;
   return short_score >= InpTradingTFDirectionMinimumScore &&
          short_score >= long_score + InpTradingTFDirectionMinimumGap;
}

//+------------------------------------------------------------------+
string SignalDirectionName()
{
   if(g_signal_direction == SIGNAL_LONG_ONLY) return "LONG";
   if(g_signal_direction == SIGNAL_SHORT_ONLY) return "SHORT";
   return "BOTH";
}

//+------------------------------------------------------------------+
bool SignalDirectionAllows(const int side)
{
   return g_signal_direction == SIGNAL_BOTH ||
          (side > 0 && g_signal_direction == SIGNAL_LONG_ONLY) ||
          (side < 0 && g_signal_direction == SIGNAL_SHORT_ONLY);
}

//+------------------------------------------------------------------+
bool AutoDirectionAllows(const int side)
{
   return g_trade_direction == TRADE_BOTH ||
          (side > 0 && g_trade_direction == TRADE_LONG_ONLY) ||
          (side < 0 && g_trade_direction == TRADE_SHORT_ONLY);
}

//+------------------------------------------------------------------+
string AutoDirectionName()
{
   if(g_trade_direction == TRADE_LONG_ONLY) return "LONG";
   if(g_trade_direction == TRADE_SHORT_ONLY) return "SHORT";
   return "BOTH";
}

//+------------------------------------------------------------------+
void ApplySignalDirection(const ENUM_SIGNAL_DIRECTION new_direction)
{
   if(new_direction == g_signal_direction)
      return;

   // Only an opposite virtual signal is discarded. Actual positions,
   // AUTO DIR, past arrows and the retained direction's duplicate guard
   // are deliberately left untouched.
   if(new_direction == SIGNAL_LONG_ONLY && g_signal_position_side < 0)
   {
      g_signal_position_side = 0;
      g_signal_entry_price = 0.0;
      g_short_exit_pending = false;
   }
   else if(new_direction == SIGNAL_SHORT_ONLY && g_signal_position_side > 0)
   {
      g_signal_position_side = 0;
      g_signal_entry_price = 0.0;
      g_long_exit_pending = false;
   }

   g_signal_direction = new_direction;
   g_status = "SIGNAL DIRECTION " + SignalDirectionName();
}

//+------------------------------------------------------------------+
double ProfileMaximumRangeMultiplier()
{
   if(g_asset_profile == ASSET_WTI) return 1.60;
   if(g_asset_profile == ASSET_GOLD) return 1.80;
   if(g_asset_profile == ASSET_NASDAQ) return 2.00;
   if(g_asset_profile == ASSET_COPPER) return 1.70;
   if(g_asset_profile == ASSET_BITCOIN) return 2.50;
   return 2.00;
}

//+------------------------------------------------------------------+
bool OversizedClosedBar()
{
   if(!InpBlockOversizedBar || InpRangeAveragePeriod < 2)
      return false;
   double average = 0.0;
   for(int shift = 2; shift < 2 + InpRangeAveragePeriod; shift++)
      average += iHigh(_Symbol, g_calc_tf, shift) -
                 iLow(_Symbol, g_calc_tf, shift);
   average /= (double)InpRangeAveragePeriod;
   if(average <= 0.0)
      return false;
   const double current =
      iHigh(_Symbol, g_calc_tf, 1) - iLow(_Symbol, g_calc_tf, 1);
   return current > average * ProfileMaximumRangeMultiplier();
}

//+------------------------------------------------------------------+
double AverageClosedBarRange()
{
   if(InpRangeAveragePeriod < 2)
      return 0.0;
   double average = 0.0;
   for(int shift = 2; shift < 2 + InpRangeAveragePeriod; shift++)
      average += iHigh(_Symbol, g_calc_tf, shift) -
                 iLow(_Symbol, g_calc_tf, shift);
   return average / (double)InpRangeAveragePeriod;
}

//+------------------------------------------------------------------+
bool IsChasingSignal(const int side, const double close_price,
                     const double slow_ma)
{
   if(InpMaximumChaseRange <= 0.0)
      return false;
   const double average_range = AverageClosedBarRange();
   if(average_range <= 0.0)
      return false;
   const double directional_distance =
      side > 0 ? close_price - slow_ma : slow_ma - close_price;
   return directional_distance >
          average_range * InpMaximumChaseRange;
}

//+------------------------------------------------------------------+
// Calculates the current position inside the preceding closed-bar range.
// Location is a score component, not an absolute entry ban.
bool CalculateRangeLocation(const double entry_price,
                            double &location,
                            double &range_high,
                            double &range_low)
{
   location = 0.50;
   range_high = 0.0;
   range_low = 0.0;
   const int lookback = MathMax(10, InpRangeLocationLookbackBars);
   range_high = iHigh(_Symbol, AUTO_TF, 2);
   range_low  = iLow(_Symbol, AUTO_TF, 2);
   if(range_high <= 0.0 || range_low <= 0.0)
      return false;
   for(int shift = 3; shift <= lookback + 1; shift++)
   {
      const double high_value = iHigh(_Symbol, AUTO_TF, shift);
      const double low_value  = iLow(_Symbol, AUTO_TF, shift);
      if(high_value > 0.0) range_high = MathMax(range_high, high_value);
      if(low_value > 0.0)  range_low  = MathMin(range_low, low_value);
   }
   const double width = range_high - range_low;
   if(width <= MathMax(_Point, InpRangeMinimumWidthPoints * _Point))
      return false;
   location = MathMax(0.0, MathMin(1.0,
      (entry_price - range_low) / width));
   return true;
}

// Lower locations favour BUY and upper locations favour SELL. The middle is
// neutral. This avoids losing valid trend starts through a rigid location ban.
int RangeLocationScoreAdjustment(const int side,
                                 const double location)
{
   if(!InpUseRangeLocationScore)
      return 0;
   const int maximum = MathMax(0, InpRangeLocationMaximumScore);
   const double directional = side > 0 ? (0.50 - location) * 2.0 :
                                       (location - 0.50) * 2.0;
   return (int)MathRound(MathMax(-1.0, MathMin(1.0, directional)) * maximum);
}

//+------------------------------------------------------------------+
double AverageAbsoluteDelta(const double &raw_delta[])
{
   double total = 0.0;
   for(int i = 2; i < 2 + InpDeltaAveragePeriod; i++)
      total += MathAbs(raw_delta[i]);
   return total / (double)InpDeltaAveragePeriod;
}

//+------------------------------------------------------------------+
bool IsCooldownComplete()
{
   if(g_last_exit_bar_time <= 0)
      return true;
   const int shift = iBarShift(_Symbol, AUTO_TF, g_last_exit_bar_time, false);
   return (shift > g_exit_cooldown_bars);
}

//+------------------------------------------------------------------+
void ResetRangeTriggerFinalEntryState(const string reason="")
{
   if(reason!="" && g_range_trigger_entry_active)
   {
      WriteUnifiedOrderSignalAudit(
         "RANGE_TRIGGER_FINAL_RESET",
         "","INITIAL",
         g_range_trigger_entry_side,0,g_range_trigger_entry_final_count,
         "RESET",reason,false,false,0,g_trade_cycle.position_id);
   }
   g_range_trigger_entry_active=false;
   g_range_trigger_entry_side=0;
   g_range_trigger_entry_fire_time=0;
   g_range_trigger_entry_trigger_price=0.0;
   g_range_trigger_entry_fire_bar=0;
   g_range_trigger_entry_fire_high=0.0;
   g_range_trigger_entry_fire_low=0.0;
   g_range_trigger_entry_fire_bar_locked=false;
   g_range_trigger_entry_rebreak_confirmed=false;
   g_range_trigger_entry_final_count=0;
   g_range_trigger_entry_opposite_count=0;
   g_range_trigger_entry_last_final_bar=0;
   g_range_trigger_entry_second_final_bar=0;
   g_range_trigger_entry_second_high=0.0;
   g_range_trigger_entry_second_low=0.0;
   g_range_trigger_entry_second_close=0.0;
   g_range_trigger_entry_second_score=0;
   g_range_trigger_entry_second_ready=false;
   g_range_trigger_entry_next_retry_time=0;
}

bool TriggerEntryAuthorityExpired(const ENUM_STRATEGY_MODE strategy,
                                  int &age_bars)
{
   age_bars=-1;
   if(!g_range_trigger_entry_active || g_range_trigger_entry_fire_bar<=0)
      return false;

   const ENUM_TIMEFRAMES tf=AUTO_TF;
   age_bars=iBarShift(_Symbol,tf,g_range_trigger_entry_fire_bar,false);
   if(age_bars<0)
      return false;

   return age_bars>JTATriggerEntryExpiryBarsForStrategy(strategy);
}

void ResetRangeDirectionConfirmation()
{
   g_range_direction_confirm_pending = false;
   g_range_direction_confirm_side = 0;
   g_range_direction_confirm_signal_bar = 0;
   g_range_direction_confirm_high = 0.0;
   g_range_direction_confirm_low = 0.0;
   g_range_direction_confirm_close = 0.0;
   g_range_direction_confirm_wait_bars = 0;
   g_range_direction_confirm_signal_count = 0;
   g_range_direction_confirm_lots = 0.0;
   g_range_break_confirm_bar_time = 0;
   g_range_break_confirm_high = 0.0;
   g_range_break_confirm_low = 0.0;
   g_range_break_confirm_close = 0.0;
   g_range_break_reference_price = 0.0;
   g_range_break_distance = 0.0;
   g_range_break_confirmed = false;
   g_range_break_order_sent = false;
   g_range_break_order_result = false;
   g_range_break_order_price = 0.0;
   g_range_direction_confirm_gate_block_bars = 0;
   g_range_direction_confirm_last_support_bar = 0;
   g_range_direction_confirm_opposite_count = 0;

   g_initial_3x_structure_stop_active=false;
   g_initial_3x_structure_stop_side=0;
   g_initial_3x_structure_stop_price=0.0;
   g_initial_3x_structure_signal_bar=0;
}

void ResetInitialSignalWindow(const int side)
{
   if(side >= 0)
   {
      for(int i=0; i<3; i++)
         g_range_long_signal_window[i] = 0;
      g_range_long_signal_count = 0;
      g_range_first_long_count_bar = 0;
      g_range_last_long_count_bar = 0;
      g_long_entry_condition_alerted = false;
   }
   if(side <= 0)
   {
      for(int i=0; i<3; i++)
         g_range_short_signal_window[i] = 0;
      g_range_short_signal_count = 0;
      g_range_first_short_count_bar = 0;
      g_range_last_short_count_bar = 0;
      g_short_entry_condition_alerted = false;
   }
}

void SyncInitialSignalWindowState(const int side)
{
   int count = 0;
   datetime first_bar = 0;
   datetime last_bar = 0;

   if(side > 0)
   {
      for(int i=0; i<3; i++)
      {
         if(g_range_long_signal_window[i] <= 0)
            continue;
         if(count == 0)
            first_bar = g_range_long_signal_window[i];
         last_bar = g_range_long_signal_window[i];
         count++;
      }
      g_range_long_signal_count = count;
      g_range_first_long_count_bar = first_bar;
      g_range_last_long_count_bar = last_bar;
   }
   else
   {
      for(int i=0; i<3; i++)
      {
         if(g_range_short_signal_window[i] <= 0)
            continue;
         if(count == 0)
            first_bar = g_range_short_signal_window[i];
         last_bar = g_range_short_signal_window[i];
         count++;
      }
      g_range_short_signal_count = count;
      g_range_first_short_count_bar = first_bar;
      g_range_last_short_count_bar = last_bar;
   }
}

bool AddInitialSignalToWindow(const int side,
                               const datetime signal_bar,
                               const int window_bars)
{
   if(side==0 || signal_bar<=0)
      return false;

   // v8.09: INITIAL 3X definition is fixed: all three same-direction FINALs
   // must occur within seven completed signal bars inclusive (#1..#3 <= 7).
   // window_bars remains in the signature for compatibility with existing callers.
   const int max_bars=7;
   int count=side>0 ? g_range_long_signal_count : g_range_short_signal_count;

   // Reject duplicate FINAL bar.
   for(int i=0;i<count;i++)
   {
      const datetime existing=side>0 ?
         g_range_long_signal_window[i] : g_range_short_signal_window[i];
      if(existing==signal_bar)
         return false;
   }

   // Drop stale oldest FINALs until FINAL #1 -> current FINAL fits inside
   // the configured inclusive completed-bar span.
   while(count>0)
   {
      const datetime first=side>0 ?
         g_range_long_signal_window[0] : g_range_short_signal_window[0];
      const int first_shift=iBarShift(_Symbol,g_calc_tf,first,true);
      const int cur_shift=iBarShift(_Symbol,g_calc_tf,signal_bar,true);

      if(first_shift<0 || cur_shift<0)
         break;

      const int inclusive_span=MathAbs(first_shift-cur_shift)+1;
      if(inclusive_span<=max_bars)
         break;

      if(side>0)
      {
         g_range_long_signal_window[0]=g_range_long_signal_window[1];
         g_range_long_signal_window[1]=g_range_long_signal_window[2];
         g_range_long_signal_window[2]=0;
      }
      else
      {
         g_range_short_signal_window[0]=g_range_short_signal_window[1];
         g_range_short_signal_window[1]=g_range_short_signal_window[2];
         g_range_short_signal_window[2]=0;
      }
      count--;
   }

   if(side>0)
   {
      if(count>=3)
      {
         g_range_long_signal_window[0]=g_range_long_signal_window[1];
         g_range_long_signal_window[1]=g_range_long_signal_window[2];
         g_range_long_signal_window[2]=signal_bar;
      }
      else
         g_range_long_signal_window[count]=signal_bar;
   }
   else
   {
      if(count>=3)
      {
         g_range_short_signal_window[0]=g_range_short_signal_window[1];
         g_range_short_signal_window[1]=g_range_short_signal_window[2];
         g_range_short_signal_window[2]=signal_bar;
      }
      else
         g_range_short_signal_window[count]=signal_bar;
   }

   SyncInitialSignalWindowState(side);

   // Final guard: 3X exists only if FINAL #1..#3 are within max_bars inclusive.
   const int final_count=side>0 ? g_range_long_signal_count : g_range_short_signal_count;
   if(final_count>=3)
   {
      const datetime first=side>0 ? g_range_long_signal_window[0] :
                                    g_range_short_signal_window[0];
      const datetime third=side>0 ? g_range_long_signal_window[2] :
                                    g_range_short_signal_window[2];
      const int first_shift=iBarShift(_Symbol,g_calc_tf,first,true);
      const int third_shift=iBarShift(_Symbol,g_calc_tf,third,true);
      if(first_shift>=0 && third_shift>=0 &&
         MathAbs(first_shift-third_shift)+1>max_bars)
      {
         if(side>0)
         {
            g_range_long_signal_window[0]=g_range_long_signal_window[1];
            g_range_long_signal_window[1]=g_range_long_signal_window[2];
            g_range_long_signal_window[2]=0;
         }
         else
         {
            g_range_short_signal_window[0]=g_range_short_signal_window[1];
            g_range_short_signal_window[1]=g_range_short_signal_window[2];
            g_range_short_signal_window[2]=0;
         }
         SyncInitialSignalWindowState(side);
      }
   }
   return true;
}

void TrimInitialSignalWindow(const int side,const int max_count)
{
   const int keep = MathMax(0,MathMin(3,max_count));
   int count = side > 0 ? g_range_long_signal_count : g_range_short_signal_count;
   while(count > keep)
   {
      if(side > 0)
      {
         g_range_long_signal_window[0] = g_range_long_signal_window[1];
         g_range_long_signal_window[1] = g_range_long_signal_window[2];
         g_range_long_signal_window[2] = 0;
      }
      else
      {
         g_range_short_signal_window[0] = g_range_short_signal_window[1];
         g_range_short_signal_window[1] = g_range_short_signal_window[2];
         g_range_short_signal_window[2] = 0;
      }
      count--;
   }
   SyncInitialSignalWindowState(side);
}

void ResetInitialSignalCountersOnly()
{
   ResetInitialSignalWindow(0);
   g_range_last_counted_signal_bar = 0;
   g_long_entry_condition_alerted = false;
   g_short_entry_condition_alerted = false;
}

void ResetRangeDirectionalPersistence(const string reason)
{
   const int previous=g_range_persistent_direction;
   g_range_persistent_direction=0;
   g_range_persistent_since=0;
   g_range_density_ready_long=false;
   g_range_density_ready_short=false;
   g_range_density_fresh_long=false;
   g_range_density_fresh_short=false;
   for(int density_i=0;density_i<5;density_i++)
      g_range_final_density_window[density_i]=0;
   g_range_final_density_last_bar=0;
   g_range_final_density_long_5=0;
   g_range_final_density_short_5=0;
   g_range_final_density_macd_wave=0.0;
   g_range_final_density_macd_change_3=0.0;
   if(previous!=0 && reason!="")
   {
      WriteUnifiedOrderSignalAudit(
         "RANGE_DIRECTION_PERSISTENCE","",
         "SIGNAL",previous,0,0,"RESET",reason,
         false,false,0,g_trade_cycle.position_id);
   }
}


void ResetAutoSignalCounters()
{
   ResetInitialSignalCountersOnly();
   ResetRangeDirectionConfirmation();
   ResetRangeTriggerFinalEntryState("AUTO_COUNTER_RESET");
}

// v1.94: the trade-cycle object is authoritative during pre-entry. Restore
// working counters before processing a new AUTO completed bar so live/tester
// orchestration cannot accidentally lose a still-valid cycle snapshot.
void TradeCycleRestoreInitialWorkingState()
{
   if(g_trade_cycle.state!=JTA_CYCLE_SIGNAL_ACCUMULATING ||
      g_trade_cycle.cycle_id=="" || g_trade_cycle.side==0)
      return;
   ResetInitialSignalWindow(0);
   const int count=MathMax(0,MathMin(3,g_trade_cycle.initial_signal_count));
   for(int i=0;i<count;i++)
   {
      if(g_trade_cycle.side>0)
         g_range_long_signal_window[i]=g_trade_cycle.initial_signal_times[i];
      else
         g_range_short_signal_window[i]=g_trade_cycle.initial_signal_times[i];
   }
   SyncInitialSignalWindowState(g_trade_cycle.side);
}

int SignalRequiredHistoryCount()
{
   int required=64;
   required=MathMax(required,InpDeltaAveragePeriod+5);
   required=MathMax(required,InpSignalValidBars+5);
   required=MathMax(required,InpPullbackLookbackBars+5);
   required=MathMax(required,InpCompressionLookback+5);
   required=MathMax(required,InpCompressionRecentBars+5);
   required=MathMax(required,InpSwingLookback+5);
   required=MathMax(required,InpDominanceLookback+5);
   required=MathMax(required,InpMACDReferenceBars+5);
   required=MathMax(required,InpRangeStrengthLookbackBars+5);
   required=MathMax(required,InpTrendStrengthLookbackBars+5);
   required=MathMax(required,InpDirectionQualityLookback+5);
   required=MathMax(required,InpStrongPersistenceLookbackBars+5);
   required=MathMax(required,InpTimingBreakLookback+5);
   required=MathMax(required,InpPatternLookback+7);
   required=MathMax(required,InpExitConfirmBars+5);
   required=MathMax(required,InpRangeLocationLookbackBars+5);
   return required;
}

bool CopySignalData(double &base_line[],
                    double &color_state[],
                    double &zero_state[],
                    double &raw_delta[],
                    double &ema_delta[])
{
   const int count=SignalRequiredHistoryCount();

   ArrayResize(base_line, count);
   ArrayResize(color_state, count);
   ArrayResize(zero_state, count);
   ArrayResize(raw_delta, count);
   ArrayResize(ema_delta, count);
   ArraySetAsSeries(base_line, true);
   ArraySetAsSeries(color_state, true);
   ArraySetAsSeries(zero_state, true);
   ArraySetAsSeries(raw_delta, true);
   ArraySetAsSeries(ema_delta, true);

   ResetLastError();

   // v8.86: M3 canonical signal calculations must consume the same shared
   // snapshot as M3 structure/AUTO.  Do not fall back to a second direct
   // indicator read merely because legacy signal handles are present.
   const bool shared_range_snapshot=
      g_selected_strategy==STRATEGY_RANGE &&
      g_calc_tf==AUTO_TF &&
      M3AutoEngineIsActive() &&
      g_calc_macd_handle==g_macd_handle &&
      g_calc_delta_handle==g_delta_handle;

   if(shared_range_snapshot && EnsureMarketSnapshotCommon(count))
   {
      if(ArrayCopy(base_line,g_ms_macd,0,0,count)!=count ||
         ArrayCopy(color_state,g_ms_macd_direction,0,0,count)!=count ||
         ArrayCopy(zero_state,g_ms_macd_zero_state,0,0,count)!=count ||
         ArrayCopy(raw_delta,g_ms_delta,0,0,count)!=count ||
         ArrayCopy(ema_delta,g_ms_delta_ema,0,0,count)!=count)
      {
         g_status="WAITING FOR SNAPSHOT DATA";
         return false;
      }
      return true;
   }

   if(MarketDataCopyBuffer(g_calc_macd_handle, JTC_MACD_BASE_BUFFER, 0, count, base_line) < count ||
      MarketDataCopyBuffer(g_calc_macd_handle, JTC_MACD_DIRECTION_BUFFER, 0, count, color_state) < count ||
      MarketDataCopyBuffer(g_calc_macd_handle,JTC_MACD_ZERO_STATE_BUFFER, 0, count, zero_state) < count ||
      MarketDataCopyBuffer(g_calc_delta_handle, 2, 0, count, raw_delta) < count ||
      MarketDataCopyBuffer(g_calc_delta_handle, 3, 0, count, ema_delta) < count)
   {
      g_status = "WAITING FOR INDICATOR DATA";
      return false;
   }
   return true;
}

//+------------------------------------------------------------------+
bool ExitConfirmTrendReversed(const int side)
{
   double fast[], slow[];
   ArrayResize(fast, 3);
   ArrayResize(slow, 3);
   ArraySetAsSeries(fast, true);
   ArraySetAsSeries(slow, true);
   if(g_add_ma_handle == INVALID_HANDLE ||
      g_slow_ma_handle == INVALID_HANDLE ||
      MarketDataCopyBuffer(g_add_ma_handle, 0, 0, 3, fast) < 3 ||
      MarketDataCopyBuffer(g_slow_ma_handle, 0, 0, 3, slow) < 3)
      return false;
   return side > 0 ? fast[1] < slow[1] : fast[1] > slow[1];
}

//+------------------------------------------------------------------+
string TrendInternalStateName()
{
   if(g_trend_internal_state == TREND_STATE_PULLBACK) return "PULLBACK";
   if(g_trend_internal_state == TREND_STATE_ENTRY) return "ENTRY";
   if(g_trend_internal_state == TREND_STATE_HOLD) return "HOLD";
   if(g_trend_internal_state == TREND_STATE_EXIT) return "EXIT";
   return "SETUP";
}

string RangeInternalStateName()
{
   if(g_range_internal_state == RANGE_STATE_REVERSAL) return "REVERSAL";
   if(g_range_internal_state == RANGE_STATE_ENTRY) return "ENTRY";
   if(g_range_internal_state == RANGE_STATE_HOLD) return "HOLD";
   if(g_range_internal_state == RANGE_STATE_EXIT) return "EXIT";
   return "SETUP";
}

void UpdateTrendInternalState(const bool long_bias, const bool short_bias,
                              const bool long_pullback, const bool short_pullback,
                              const bool long_trigger, const bool short_trigger)
{
   const int position_side = ManagedPositionSide();
   if(position_side != 0)
   {
      ReleaseAutoStartBias("FIRST POSITION OPENED");
      g_trend_internal_state = TREND_STATE_HOLD;
      g_trend_internal_side = position_side;
      g_trend_state_bars = 0;
      return;
   }

   // ENTRY is valid only on the trigger bar. If no order was opened, rebuild the setup.
   if(g_trend_internal_state == TREND_STATE_ENTRY)
   {
      g_trend_internal_state = TREND_STATE_SETUP;
      g_trend_internal_side = 0;
      g_trend_state_bars = 0;
   }
   g_trend_state_bars++;
   if(g_trend_state_bars > MathMax(6, InpSignalValidBars + InpPullbackLookbackBars))
   {
      g_trend_internal_state = TREND_STATE_SETUP;
      g_trend_internal_side = 0;
      g_trend_state_bars = 0;
   }

   if(long_bias && !short_bias)
   {
      if(g_trend_internal_side != 1)
      {
         g_trend_internal_side = 1;
         g_trend_internal_state = TREND_STATE_SETUP;
         g_trend_state_bars = 0;
      }
      if(long_pullback) g_trend_internal_state = TREND_STATE_PULLBACK;
      if(long_trigger && (g_trend_internal_state == TREND_STATE_PULLBACK || long_pullback))
         g_trend_internal_state = TREND_STATE_ENTRY;
   }
   else if(short_bias && !long_bias)
   {
      if(g_trend_internal_side != -1)
      {
         g_trend_internal_side = -1;
         g_trend_internal_state = TREND_STATE_SETUP;
         g_trend_state_bars = 0;
      }
      if(short_pullback) g_trend_internal_state = TREND_STATE_PULLBACK;
      if(short_trigger && (g_trend_internal_state == TREND_STATE_PULLBACK || short_pullback))
         g_trend_internal_state = TREND_STATE_ENTRY;
   }
   else if(g_trend_internal_state != TREND_STATE_ENTRY)
   {
      g_trend_internal_state = TREND_STATE_SETUP;
      g_trend_internal_side = 0;
   }
}

void UpdateRangeInternalState(const bool long_setup, const bool short_setup,
                              const bool long_reversal, const bool short_reversal,
                              const bool long_trigger, const bool short_trigger)
{
   const int position_side = ManagedPositionSide();
   if(position_side != 0)
   {
      g_range_internal_state = RANGE_STATE_HOLD;
      g_range_internal_side = position_side;
      g_range_state_bars = 0;
      return;
   }

   // ENTRY is valid only on the trigger bar. If no order was opened, wait for a fresh reversal.
   if(g_range_internal_state == RANGE_STATE_ENTRY)
   {
      g_range_internal_state = RANGE_STATE_SETUP;
      g_range_internal_side = 0;
      g_range_state_bars = 0;
   }
   g_range_state_bars++;
   if(g_range_state_bars > MathMax(5, InpSignalValidBars + 2))
   {
      g_range_internal_state = RANGE_STATE_SETUP;
      g_range_internal_side = 0;
      g_range_state_bars = 0;
   }

   if(long_setup && !short_setup)
   {
      if(g_range_internal_side != 1)
      {
         g_range_internal_side = 1;
         g_range_internal_state = RANGE_STATE_SETUP;
         g_range_state_bars = 0;
      }
      if(long_reversal) g_range_internal_state = RANGE_STATE_REVERSAL;
      if(long_trigger && g_range_internal_state == RANGE_STATE_REVERSAL)
         g_range_internal_state = RANGE_STATE_ENTRY;
   }
   else if(short_setup && !long_setup)
   {
      if(g_range_internal_side != -1)
      {
         g_range_internal_side = -1;
         g_range_internal_state = RANGE_STATE_SETUP;
         g_range_state_bars = 0;
      }
      if(short_reversal) g_range_internal_state = RANGE_STATE_REVERSAL;
      if(short_trigger && g_range_internal_state == RANGE_STATE_REVERSAL)
         g_range_internal_state = RANGE_STATE_ENTRY;
   }
   else if(g_range_internal_state != RANGE_STATE_ENTRY)
   {
      g_range_internal_state = RANGE_STATE_SETUP;
      g_range_internal_side = 0;
   }
}


void ResetPreAutoFinalHistory(const string reason)
{
   for(int i=0;i<PRE_AUTO_FINAL_CAPACITY;i++)
   {
      g_pre_auto_final_time[i]=0;
      g_pre_auto_final_side[i]=0;
      g_pre_auto_final_score[i]=0;
      g_pre_auto_final_strategy[i]=0;
      g_pre_auto_final_tf_seconds[i]=0;
   }
   g_pre_auto_final_count=0;
   g_pre_auto_history_long_count=0;
   g_pre_auto_history_short_count=0;
   g_pre_auto_history_last_side=0;
   g_pre_auto_history_last_score=0;
   g_pre_auto_history_used=false;
   if(reason!="")
      Print(_Symbol+" PRE-AUTO FINAL HISTORY RESET: "+reason);
}

void RecordPreAutoFinalSignal(const int side,
                              const int score,
                              const datetime bar_time,
                              const ENUM_STRATEGY_MODE strategy,
                              const ENUM_TIMEFRAMES tf)
{
   // PRE-AUTO history is strictly observation-only and flat-only.
   if(g_auto_trading || !g_signal_enabled || ManagedPositionSide()!=0 ||
      side==0 || bar_time<=0)
      return;

   const int tf_seconds=MathMax(1,PeriodSeconds(tf));

   // Avoid duplicate recording when the same completed signal bar is evaluated
   // more than once by live/test orchestration.
   for(int i=0;i<g_pre_auto_final_count;i++)
   {
      if(g_pre_auto_final_time[i]==bar_time &&
         g_pre_auto_final_side[i]==side &&
         g_pre_auto_final_strategy[i]==(int)strategy &&
         g_pre_auto_final_tf_seconds[i]==tf_seconds)
         return;
   }

   if(g_pre_auto_final_count<PRE_AUTO_FINAL_CAPACITY)
      g_pre_auto_final_count++;
   for(int i=g_pre_auto_final_count-1;i>0;i--)
   {
      g_pre_auto_final_time[i]=g_pre_auto_final_time[i-1];
      g_pre_auto_final_side[i]=g_pre_auto_final_side[i-1];
      g_pre_auto_final_score[i]=g_pre_auto_final_score[i-1];
      g_pre_auto_final_strategy[i]=g_pre_auto_final_strategy[i-1];
      g_pre_auto_final_tf_seconds[i]=g_pre_auto_final_tf_seconds[i-1];
   }

   g_pre_auto_final_time[0]=bar_time;
   g_pre_auto_final_side[0]=side;
   g_pre_auto_final_score[0]=MathMax(0,MathMin(100,score));
   g_pre_auto_final_strategy[0]=(int)strategy;
   g_pre_auto_final_tf_seconds[0]=tf_seconds;
}

void AnalyzePreAutoFinalHistory(int &long_count,
                                int &short_count,
                                int &last_side,
                                int &last_score,
                                bool &history_used)
{
   long_count=0;
   short_count=0;
   last_side=0;
   last_score=0;
   history_used=false;

   const ENUM_STRATEGY_MODE strategy=g_selected_strategy;
   const ENUM_TIMEFRAMES expected_tf=g_signal_tf;
   const int expected_seconds=MathMax(1,PeriodSeconds(expected_tf));
   const int max_age_bars=6;

   datetime newest_time=0;
   for(int i=0;i<g_pre_auto_final_count;i++)
   {
      if(g_pre_auto_final_time[i]<=0 ||
         g_pre_auto_final_strategy[i]!=(int)strategy ||
         g_pre_auto_final_tf_seconds[i]!=expected_seconds)
         continue;

      const int age=iBarShift(_Symbol,expected_tf,g_pre_auto_final_time[i],false);
      if(age<1 || age>max_age_bars)
         continue;

      if(g_pre_auto_final_side[i]>0) long_count++;
      else if(g_pre_auto_final_side[i]<0) short_count++;

      if(g_pre_auto_final_time[i]>newest_time)
      {
         newest_time=g_pre_auto_final_time[i];
         last_side=g_pre_auto_final_side[i];
         last_score=g_pre_auto_final_score[i];
      }
   }

   history_used=(long_count+short_count)>0;
}

string AutoStartBiasName()
{
   if(g_auto_start_bias == AUTO_BIAS_LONG) return "LONG";
   if(g_auto_start_bias == AUTO_BIAS_SHORT) return "SHORT";
   return "NEUTRAL";
}

void ReleaseAutoStartBias(const string reason)
{
   if(!g_auto_start_bias_active)
      return;
   g_pre_direction_last_bias = AutoStartBiasName();
   g_auto_start_bias_active = false;
   g_pre_direction_bias_released = true;
   g_pre_direction_release_condition = reason;
   g_pre_direction_release_block_reason = "NONE";
   Print(_Symbol + " AUTO START BIAS RELEASED: " + reason);
}

void InitializeAutoStartBias()
{
   g_auto_start_bias = AUTO_BIAS_NEUTRAL;
   g_auto_start_bias_active = false;
   g_auto_start_bias_bars_seen = 0;
   g_auto_start_bias_last_bar = iTime(_Symbol, AUTO_TF, 1);
   g_pre_direction_long_count = 0;
   g_pre_direction_short_count = 0;
   g_pre_direction_release_last_bar = 0;
   g_pre_direction_release_score = 0;
   g_pre_direction_release_condition = "WAITING_FOR_OPPOSITE_CONFIRMED_SIGNAL";
   g_pre_direction_release_block_reason = "NONE";
   g_pre_direction_bias_released = false;
   g_pre_direction_last_bias = "NEUTRAL";
   if(!InpUseAutoStartBias)
      return;

   const int lookback = MathMax(3, InpAutoStartBiasLookbackBars);
   double fast[], slow[], ma70[], macd[], delta[];
   ArrayResize(fast, lookback + 2);
   ArrayResize(slow, lookback + 2);
   ArrayResize(ma70, lookback + 2);
   ArrayResize(macd, lookback + 2);
   ArrayResize(delta, lookback + 2);
   ArraySetAsSeries(fast, true);
   ArraySetAsSeries(slow, true);
   ArraySetAsSeries(ma70, true);
   ArraySetAsSeries(macd, true);
   ArraySetAsSeries(delta, true);

   if(MarketDataCopyBuffer(g_calc_fast_ma_handle, 0, 0, lookback + 2, fast) < lookback + 2 ||
      MarketDataCopyBuffer(g_calc_slow_ma_handle, 0, 0, lookback + 2, slow) < lookback + 2 ||
      MarketDataCopyBuffer(g_calc_ma70_handle, 0, 0, lookback + 2, ma70) < lookback + 2 ||
      MarketDataCopyBuffer(g_calc_macd_handle, JTC_MACD_BASE_BUFFER, 0, lookback + 2, macd) < lookback + 2 ||
      MarketDataCopyBuffer(g_calc_delta_handle, 0, 0, lookback + 2, delta) < lookback + 2)
   {
      Print(_Symbol + " AUTO START BIAS: DATA NOT READY -> NEUTRAL");
      return;
   }

   int long_evidence = 0, short_evidence = 0;
   const double close1 = iClose(_Symbol, AUTO_TF, 1);
   if(fast[1] > slow[1]) long_evidence++; else if(fast[1] < slow[1]) short_evidence++;
   if(close1 > slow[1]) long_evidence++; else if(close1 < slow[1]) short_evidence++;
   if(slow[1] > slow[MathMin(lookback, 4)]) long_evidence++;
   else if(slow[1] < slow[MathMin(lookback, 4)]) short_evidence++;
   if(close1 > ma70[1]) long_evidence++; else if(close1 < ma70[1]) short_evidence++;

   int positive_macd = 0, negative_macd = 0, positive_delta = 0, negative_delta = 0;
   for(int i = 1; i <= lookback; i++)
   {
      if(macd[i] > 0.0) positive_macd++;
      if(macd[i] < 0.0) negative_macd++;
      if(delta[i] > 0.0) positive_delta++;
      if(delta[i] < 0.0) negative_delta++;
   }
   if(positive_macd > negative_macd) long_evidence++;
   else if(negative_macd > positive_macd) short_evidence++;
   if(positive_delta > negative_delta) long_evidence++;
   else if(negative_delta > positive_delta) short_evidence++;

   // v2.99: use recent FINAL signals observed while AUTO was OFF only as
   // directional context. They do not become AUTO signal counts or candidates.
   int pre_long=0,pre_short=0,pre_last_side=0,pre_last_score=0;
   bool pre_used=false;
   AnalyzePreAutoFinalHistory(pre_long,pre_short,
                              pre_last_side,pre_last_score,pre_used);

   g_pre_auto_history_long_count=pre_long;
   g_pre_auto_history_short_count=pre_short;
   g_pre_auto_history_last_side=pre_last_side;
   g_pre_auto_history_last_score=pre_last_score;
   g_pre_auto_history_used=pre_used;

   // Only reinforce a side when recent FINAL history is clearly one-sided,
   // the newest FINAL agrees, and the CURRENT market evidence is not opposite.
   // This prevents stale history from overriding the live market snapshot.
   const bool pre_long_dominant=
      pre_long>=2 && pre_long>=pre_short+2 && pre_last_side>0 &&
      long_evidence>=short_evidence;
   const bool pre_short_dominant=
      pre_short>=2 && pre_short>=pre_long+2 && pre_last_side<0 &&
      short_evidence>=long_evidence;

   if(pre_long_dominant)
      long_evidence+=2;
   else if(pre_short_dominant)
      short_evidence+=2;

   const int required = MathMax(2, InpAutoStartBiasMinimumEvidence);
   if(long_evidence >= required && long_evidence >= short_evidence + 2)
      g_auto_start_bias = AUTO_BIAS_LONG;
   else if(short_evidence >= required && short_evidence >= long_evidence + 2)
      g_auto_start_bias = AUTO_BIAS_SHORT;

   g_auto_start_bias_active =
      g_auto_start_bias != AUTO_BIAS_NEUTRAL && InpAutoStartBiasMaximumBars > 0;
   Print(StringFormat("%s AUTO START BIAS: %s | LONG %d SHORT %d | MAX %d BARS | PRE-AUTO L%d S%d LAST %s %d USED=%s",
      _Symbol, AutoStartBiasName(), long_evidence, short_evidence,
      MathMax(0, InpAutoStartBiasMaximumBars),
      g_pre_auto_history_long_count,g_pre_auto_history_short_count,
      g_pre_auto_history_last_side>0 ? "LONG" :
         (g_pre_auto_history_last_side<0 ? "SHORT" : "NONE"),
      g_pre_auto_history_last_score,
      g_pre_auto_history_used ? "YES" : "NO"));

   DataExportWriteUnifiedEvent("AUTO","AUTO_START_BIAS",
      g_auto_start_bias==AUTO_BIAS_LONG ? 1 :
         (g_auto_start_bias==AUTO_BIAS_SHORT ? -1 : 0),
      0,0.0,0.0,g_pre_auto_history_last_score,
      AutoStartBiasName(),
      g_pre_auto_history_used ? "PRE_AUTO_FINAL_HISTORY_EVALUATED" :
                                "NO_VALID_PRE_AUTO_FINAL_HISTORY",
      "",
      (double)g_pre_auto_history_long_count,
      (double)g_pre_auto_history_short_count,
      StringFormat("LAST_SIDE=%s LAST_SCORE=%d BIAS_EVIDENCE_L=%d BIAS_EVIDENCE_S=%d",
         g_pre_auto_history_last_side>0 ? "LONG" :
            (g_pre_auto_history_last_side<0 ? "SHORT" : "NONE"),
         g_pre_auto_history_last_score,long_evidence,short_evidence),
      TimeCurrent());
}

void UpdateAutoStartBiasWindow()
{
   if(!g_auto_start_bias_active)
      return;
   const datetime closed_bar = iTime(_Symbol, AUTO_TF, 1);
   if(closed_bar <= 0 || closed_bar == g_auto_start_bias_last_bar)
      return;
   g_auto_start_bias_last_bar = closed_bar;
   g_auto_start_bias_bars_seen++;
   if(g_auto_start_bias_bars_seen >= MathMax(1, InpAutoStartBiasMaximumBars))
      ReleaseAutoStartBias("WINDOW COMPLETE");
}

bool AutoStartBiasAllows(const int side,
                         const bool fresh_structure_reversal,
                         const bool confirmed_signal,
                         const int observed_signal_count)
{
   if(!g_auto_start_bias_active || g_auto_start_bias == AUTO_BIAS_NEUTRAL)
      return true;
   if((side > 0 && g_auto_start_bias == AUTO_BIAS_LONG) ||
      (side < 0 && g_auto_start_bias == AUTO_BIAS_SHORT))
      return true;

   const datetime closed_bar = iTime(_Symbol, AUTO_TF, 1);
   if(closed_bar > 0 && closed_bar != g_pre_direction_release_last_bar)
   {
      g_pre_direction_release_last_bar = closed_bar;
      g_pre_direction_bias_released = false;
      if(confirmed_signal)
      {
         if(side > 0)
         {
            g_pre_direction_long_count++;
            g_pre_direction_short_count = 0;
         }
         else
         {
            g_pre_direction_short_count++;
            g_pre_direction_long_count = 0;
         }
      }
   }

   const int internal_count = side > 0 ?
      g_pre_direction_long_count : g_pre_direction_short_count;
   const int opposite_count = MathMax(internal_count, observed_signal_count);
   const int required_count = MathMax(1, InpPreDirectionReleaseSignals);

   int release_score = 0;
   if(confirmed_signal) release_score += 40;
   release_score += MathMin(40, opposite_count * 40 / required_count);
   if(fresh_structure_reversal) release_score += 20;
   g_pre_direction_release_score = MathMin(100, release_score);
   g_pre_direction_release_condition = StringFormat(
      "%s_CONFIRMED=%s;OPPOSITE_COUNT=%d/%d;STRUCTURE=%s",
      side > 0 ? "LONG" : "SHORT",
      confirmed_signal ? "YES" : "NO",
      opposite_count, required_count,
      fresh_structure_reversal ? "YES" : "NO");

   if(!confirmed_signal)
      g_pre_direction_release_block_reason = "OPPOSITE_CONFIRMED_SIGNAL_NOT_REACHED";
   else if(opposite_count < required_count)
      g_pre_direction_release_block_reason = "OPPOSITE_SIGNAL_COUNT_NOT_REACHED";
   else if(g_pre_direction_release_score < MathMax(1, InpPreDirectionReleaseScore))
      g_pre_direction_release_block_reason = "RELEASE_SCORE_NOT_REACHED";
   else
      g_pre_direction_release_block_reason = "NONE";

   if(confirmed_signal && opposite_count >= required_count &&
      g_pre_direction_release_score >= MathMax(1, InpPreDirectionReleaseScore))
   {
      const string released_bias = AutoStartBiasName();
      ReleaseAutoStartBias(StringFormat("OPPOSITE %s CONFIRMED %d/%d SCORE %d",
         side > 0 ? "LONG" : "SHORT", opposite_count, required_count,
         g_pre_direction_release_score));
      NotifyTerminalOnly(StringFormat(
         "%s PRE-DIRECTION RELEASED | OLD %s | NEW %s | COUNT %d | SCORE %d",
         _Symbol, released_bias, side > 0 ? "LONG" : "SHORT",
         opposite_count, g_pre_direction_release_score));
      return true;
   }
   return false;
}

// One common direction-quality calculation for chart signals, RANGE AUTO and TREND AUTO.
// The modes may use different setup/timing rules, but they cannot disagree about whether
// MA, MACD and Delta provide a usable long or short direction.
void CalculateCommonDirectionQuality(const double &fast[],
                                     const double &slow[],
                                     const double &ma70[],
                                     const double &base_line[],
                                     const double &raw[],
                                     const int count,
                                     const double close1,
                                     const bool base_up,
                                     const bool base_down,
                                     const bool buy_dominance,
                                     const bool sell_dominance,
                                     const double dominance_sum,
                                     const double average_delta,
                                     const bool ma22_up,
                                     const bool ma22_down,
                                     const bool ma70_up,
                                     const bool ma70_down,
                                     int &long_quality,
                                     int &short_quality,
                                     bool &long_allowed,
                                     bool &short_allowed,
                                     bool &neutral_flow,
                                     bool &compressed_chop,
                                     bool &late_long,
                                     bool &late_short)
{
   const int lookback = MathMax(3, MathMin(InpDirectionQualityLookback, count - 3));
   const double average_range = MathMax(_Point, AverageClosedBarRange());
   int ma_cross_count = 0;
   int positive_macd_bars = 0, negative_macd_bars = 0;
   int positive_delta_bars = 0, negative_delta_bars = 0;
   int consecutive_positive_delta = 0, consecutive_negative_delta = 0;
   double direction_high = iHigh(_Symbol, g_calc_tf, 1);
   double direction_low = iLow(_Symbol, g_calc_tf, 1);
   double direction_path = 0.0;

   for(int i = 1; i <= lookback; i++)
   {
      const double diff_now = fast[i] - slow[i];
      const double diff_prev = fast[i + 1] - slow[i + 1];
      if((diff_now > 0.0 && diff_prev <= 0.0) ||
         (diff_now < 0.0 && diff_prev >= 0.0))
         ma_cross_count++;
      if(base_line[i] > 0.0) positive_macd_bars++;
      if(base_line[i] < 0.0) negative_macd_bars++;
      if(raw[i] > 0.0) positive_delta_bars++;
      if(raw[i] < 0.0) negative_delta_bars++;
      if(i == consecutive_positive_delta + 1 && raw[i] > 0.0)
         consecutive_positive_delta++;
      if(i == consecutive_negative_delta + 1 && raw[i] < 0.0)
         consecutive_negative_delta++;
      direction_high = MathMax(direction_high, iHigh(_Symbol, g_calc_tf, i));
      direction_low = MathMin(direction_low, iLow(_Symbol, g_calc_tf, i));
      if(i < lookback)
         direction_path += MathAbs(iClose(_Symbol, g_calc_tf, i) -
                                   iClose(_Symbol, g_calc_tf, i + 1));
   }

   const double ma_gap_now = fast[1] - slow[1];
   const double ma_gap_old = fast[MathMin(3, lookback)] - slow[MathMin(3, lookback)];
   const double ma_gap_in_ranges = MathAbs(ma_gap_now) / average_range;
   const double direction_range_in_ranges =
      (direction_high - direction_low) / average_range;
   const double direction_net =
      iClose(_Symbol, g_calc_tf, 1) - iClose(_Symbol, g_calc_tf, lookback);
   const double direction_efficiency =
      direction_path > _Point ? MathAbs(direction_net) / direction_path : 0.0;
   const double long_delta_ratio = (double)positive_delta_bars / (double)lookback;
   const double short_delta_ratio = (double)negative_delta_bars / (double)lookback;
   const double long_macd_ratio = (double)positive_macd_bars / (double)lookback;
   const double short_macd_ratio = (double)negative_macd_bars / (double)lookback;

   const bool ma_flat =
      MathAbs(slow[1] - slow[lookback]) <= average_range * 0.20;
   const bool narrow_direction_range =
      direction_range_in_ranges <= MathMax(2.5, lookback * 0.45);
   const bool mixed_macd_flow =
      MathAbs(positive_macd_bars - negative_macd_bars) <= 1;
   const bool mixed_delta_flow =
      MathAbs(positive_delta_bars - negative_delta_bars) <= 1 ||
      MathAbs(dominance_sum) <= average_delta * lookback * 0.50;

   int neutral_flags = 0;
   if(ma_cross_count >= InpDirectionMaximumMACrosses) neutral_flags++;
   if(ma_gap_in_ranges < InpDirectionMinimumMAGapRange) neutral_flags++;
   if(ma_flat) neutral_flags++;
   if(narrow_direction_range) neutral_flags++;
   if(mixed_macd_flow) neutral_flags++;
   if(mixed_delta_flow) neutral_flags++;
   neutral_flow = InpDirectionBlockNeutralFlow &&
                  direction_efficiency < InpDirectionMinimumEfficiency &&
                  neutral_flags >= 3;
   compressed_chop = InpDirectionBlockCompressedChop &&
                     direction_efficiency < InpDirectionMinimumEfficiency &&
                     neutral_flags >= 4;

   const double fast_slope = (fast[1] - fast[MathMin(3, lookback)]) / average_range;
   const double slow_slope = (slow[1] - slow[MathMin(3, lookback)]) / average_range;
   const bool long_ma_slope = fast_slope > 0.0 && slow_slope > 0.0;
   const bool short_ma_slope = fast_slope < 0.0 && slow_slope < 0.0;
   const bool long_gap_expanding = ma_gap_now > 0.0 && ma_gap_now > ma_gap_old;
   const bool short_gap_expanding = ma_gap_now < 0.0 && ma_gap_now < ma_gap_old;
   const bool long_macd_expanding = base_line[1] > 0.0 &&
                                     base_line[1] > base_line[2] &&
                                     MathAbs(base_line[1]) > MathAbs(base_line[2]);
   const bool short_macd_expanding = base_line[1] < 0.0 &&
                                      base_line[1] < base_line[2] &&
                                      MathAbs(base_line[1]) > MathAbs(base_line[2]);
   const bool long_delta_persistent =
      consecutive_positive_delta >= MathMax(1, InpDirectionDeltaPersistenceBars);
   const bool short_delta_persistent =
      consecutive_negative_delta >= MathMax(1, InpDirectionDeltaPersistenceBars);

   const double fast_distance = MathAbs(close1 - fast[1]) / average_range;
   const bool extreme_buy_delta = raw[1] > average_delta * InpDirectionExtremeDeltaMultiplier;
   const bool extreme_sell_delta = raw[1] < -average_delta * InpDirectionExtremeDeltaMultiplier;
   late_long = close1 > fast[1] &&
               fast_distance > InpDirectionLateDistanceRange &&
               base_line[1] > 0.0 && extreme_buy_delta;
   late_short = close1 < fast[1] &&
                fast_distance > InpDirectionLateDistanceRange &&
                base_line[1] < 0.0 && extreme_sell_delta;

   long_quality = 0;
   short_quality = 0;
   if(base_line[1] > 0.0) long_quality += 15;
   if(base_line[1] < 0.0) short_quality += 15;
   if(base_up) long_quality += 10;
   if(base_down) short_quality += 10;
   if(long_macd_ratio >= 0.60) long_quality += 10;
   if(short_macd_ratio >= 0.60) short_quality += 10;
   if(buy_dominance) long_quality += 20;
   if(sell_dominance) short_quality += 20;
   if(long_delta_ratio >= InpDirectionMinimumDeltaRatio) long_quality += 10;
   if(short_delta_ratio >= InpDirectionMinimumDeltaRatio) short_quality += 10;
   if(fast[1] > slow[1] && close1 > slow[1]) long_quality += 15;
   if(fast[1] < slow[1] && close1 < slow[1]) short_quality += 15;
   if(ma22_up) long_quality += 10;
   if(ma22_down) short_quality += 10;
   if(ma_gap_in_ranges >= InpDirectionMinimumMAGapRange)
   {
      if(fast[1] > slow[1]) long_quality += 5;
      if(fast[1] < slow[1]) short_quality += 5;
   }
   if(close1 > ma70[1] && ma70_up) long_quality += 5;
   if(close1 < ma70[1] && ma70_down) short_quality += 5;
   if(direction_efficiency >= InpDirectionMinimumEfficiency)
   {
      if(direction_net > 0.0) long_quality += 15;
      if(direction_net < 0.0) short_quality += 15;
   }
   else
   {
      long_quality -= 10;
      short_quality -= 10;
   }

   if(long_ma_slope) long_quality += InpDirectionSlopeBonus;
   if(short_ma_slope) short_quality += InpDirectionSlopeBonus;
   if(long_gap_expanding) long_quality += InpDirectionGapExpansionBonus;
   if(short_gap_expanding) short_quality += InpDirectionGapExpansionBonus;
   if(long_macd_expanding) long_quality += InpDirectionMACDExpansionBonus;
   if(short_macd_expanding) short_quality += InpDirectionMACDExpansionBonus;
   if(long_delta_persistent) long_quality += InpDirectionDeltaPersistenceBonus;
   if(short_delta_persistent) short_quality += InpDirectionDeltaPersistenceBonus;
   if(late_long) long_quality -= InpDirectionLateTrendPenalty;
   if(late_short) short_quality -= InpDirectionLateTrendPenalty;

   // Do not let stale MA alignment keep Direction Quality near 80-100 while
   // current MACD and Delta are both weakening. Reuse the existing direction
   // components and cap only the weakening side; no new score or signal path.
   const bool long_macd_delta_weakening =
      base_line[1] <= base_line[2] && raw[1] <= raw[2];
   const bool short_macd_delta_weakening =
      base_line[1] >= base_line[2] && raw[1] >= raw[2];
   const bool long_direction_weakening =
      long_macd_delta_weakening && (!long_gap_expanding || !long_ma_slope);
   const bool short_direction_weakening =
      short_macd_delta_weakening && (!short_gap_expanding || !short_ma_slope);
   const int weakening_quality_cap = 60;
   if(long_direction_weakening)
      long_quality = MathMin(long_quality, weakening_quality_cap);
   if(short_direction_weakening)
      short_quality = MathMin(short_quality, weakening_quality_cap);

   if(ma_cross_count >= InpDirectionMaximumMACrosses)
   {
      long_quality -= 20;
      short_quality -= 20;
   }
   if(neutral_flow || compressed_chop)
   {
      long_quality = 0;
      short_quality = 0;
   }

   long_quality = MathMax(0, MathMin(100, long_quality));
   short_quality = MathMax(0, MathMin(100, short_quality));
   long_allowed = !InpUseDirectionQualityFilter ||
      (!neutral_flow && !compressed_chop && !late_long &&
       long_quality >= InpMinimumDirectionQuality &&
       long_quality >= short_quality + InpMinimumDirectionQualityGap);
   short_allowed = !InpUseDirectionQualityFilter ||
      (!neutral_flow && !compressed_chop && !late_short &&
       short_quality >= InpMinimumDirectionQuality &&
       short_quality >= long_quality + InpMinimumDirectionQualityGap);
}


// Common MACD / Volume Delta strength and persistence calculation.
// This is not a separate signal engine: it only evaluates the indicator
// arrays already copied by the calling RANGE/TREND routine. Entry, holding,
// additional-entry and exit logic can therefore use one identical definition
// of directional strength without creating new handles or state variables.
bool CalculateCommonStrengthPersistence(
   const double &base_line[],
   const double &macd_color_state[],
   const double &raw[],
   const double &delta_ema[],
   const int strength_lookback_bars,
   const double macd_strength_factor,
   const double delta_strength_factor,
   bool &macd_strong_long,
   bool &macd_strong_short,
   bool &delta_strong_long,
   bool &delta_strong_short)
{
   macd_strong_long=false;
   macd_strong_short=false;
   delta_strong_long=false;
   delta_strong_short=false;

   const int available=MathMin(MathMin(ArraySize(base_line),ArraySize(raw)),
                               MathMin(ArraySize(macd_color_state),ArraySize(delta_ema)));
   if(available<4)
      return false;

   // Strength lookback remains a normalization region. It is not interpreted
   // as a number of required same-direction candles.
   const int strength_bars=
      MathMax(3,MathMin(strength_lookback_bars,available-2));
   double macd_abs_sum=0.0,delta_abs_sum=0.0;
   for(int i=1;i<=strength_bars;i++)
   {
      macd_abs_sum+=MathAbs(base_line[i]);
      delta_abs_sum+=MathAbs(raw[i]);
   }
   const double macd_abs_average=macd_abs_sum/strength_bars;
   const double delta_abs_average=delta_abs_sum/strength_bars;
   const double macd_minimum=
      macd_abs_average*MathMax(0.0,macd_strength_factor);
   const double delta_minimum=
      delta_abs_average*MathMax(0.0,delta_strength_factor);

   const int region=
      MathMax(3,MathMin(InpStrongPersistenceLookbackBars,available-1));
   const double required_ratio=MathMax(0.50,MathMin(0.95,
      (double)MathMax(1,InpStrongPersistenceMinimumBars)/
      (double)MathMax(1,region)));

   double total_weight=0.0;
   double macd_long_weight=0.0,macd_short_weight=0.0;
   double delta_long_weight=0.0,delta_short_weight=0.0;
   double macd_long_peak=0.0,macd_short_peak=0.0;
   double delta_long_peak=0.0,delta_short_peak=0.0;

   for(int i=1;i<=region;i++)
   {
      const double weight=1.0/(double)i;
      total_weight+=weight;

      if(base_line[i]>0.0 && macd_color_state[i]>0.0)
      {
         macd_long_weight+=weight;
         macd_long_peak=MathMax(macd_long_peak,MathAbs(base_line[i]));
      }
      if(base_line[i]<0.0 && macd_color_state[i]<0.0)
      {
         macd_short_weight+=weight;
         macd_short_peak=MathMax(macd_short_peak,MathAbs(base_line[i]));
      }
      if(raw[i]>0.0 && delta_ema[i]>0.0)
      {
         delta_long_weight+=weight;
         delta_long_peak=MathMax(delta_long_peak,MathAbs(raw[i]));
      }
      if(raw[i]<0.0 && delta_ema[i]<0.0)
      {
         delta_short_weight+=weight;
         delta_short_peak=MathMax(delta_short_peak,MathAbs(raw[i]));
      }
   }

   const double macd_long_ratio=total_weight>0.0?macd_long_weight/total_weight:0.0;
   const double macd_short_ratio=total_weight>0.0?macd_short_weight/total_weight:0.0;
   const double delta_long_ratio=total_weight>0.0?delta_long_weight/total_weight:0.0;
   const double delta_short_ratio=total_weight>0.0?delta_short_weight/total_weight:0.0;

   const double retention=MathMax(0.0,MathMin(1.0,InpStrongMomentumRetention));
   const bool macd_long_retained=
      macd_long_peak<=0.0 || MathAbs(base_line[1])>=macd_long_peak*retention;
   const bool macd_short_retained=
      macd_short_peak<=0.0 || MathAbs(base_line[1])>=macd_short_peak*retention;
   const bool delta_long_retained=
      delta_long_peak<=0.0 || MathAbs(raw[1])>=delta_long_peak*retention;
   const bool delta_short_retained=
      delta_short_peak<=0.0 || MathAbs(raw[1])>=delta_short_peak*retention;

   const bool delta_ema_long_ok=
      !InpRequireDeltaEMADirection ||
      (delta_ema[1]>0.0 &&
       (delta_ema[1]>=delta_ema[2] ||
        MathAbs(delta_ema[1])>=MathAbs(delta_ema[2])*retention));
   const bool delta_ema_short_ok=
      !InpRequireDeltaEMADirection ||
      (delta_ema[1]<0.0 &&
       (delta_ema[1]<=delta_ema[2] ||
        MathAbs(delta_ema[1])>=MathAbs(delta_ema[2])*retention));

   macd_strong_long=
      base_line[1]>0.0 && macd_color_state[1]>0.0 &&
      MathAbs(base_line[1])>=macd_minimum &&
      macd_long_ratio>=required_ratio && macd_long_retained;
   macd_strong_short=
      base_line[1]<0.0 && macd_color_state[1]<0.0 &&
      MathAbs(base_line[1])>=macd_minimum &&
      macd_short_ratio>=required_ratio && macd_short_retained;
   delta_strong_long=
      raw[1]>0.0 && MathAbs(raw[1])>=delta_minimum &&
      delta_long_ratio>=required_ratio &&
      delta_long_retained && delta_ema_long_ok;
   delta_strong_short=
      raw[1]<0.0 && MathAbs(raw[1])>=delta_minimum &&
      delta_short_ratio>=required_ratio &&
      delta_short_retained && delta_ema_short_ok;
   return true;
}


// v4.10 repeated FINAL persistence tracking.
// Purpose: the first FINAL in a directional episode remains unchanged.
// A later same-direction FINAL inside the existing observation window must
// demonstrate fresh MACD/Delta/price continuation before it is published.
// This state has SIGNAL authority only. POSITION-management FINALs do not use it.
struct JTA_REPEAT_FINAL_TRACK
{
   bool used;
   ENUM_STRATEGY_MODE strategy;
   ENUM_TIMEFRAMES tf;
   datetime long_bar;
   datetime short_bar;
   double long_high;
   double long_low;
   double long_close;
   double short_high;
   double short_low;
   double short_close;
};

JTA_REPEAT_FINAL_TRACK g_repeat_final_track[8];

int RepeatFinalTrackIndex(const ENUM_STRATEGY_MODE strategy,
                          const ENUM_TIMEFRAMES tf)
{
   int free_index=-1;
   for(int i=0;i<ArraySize(g_repeat_final_track);i++)
   {
      if(g_repeat_final_track[i].used &&
         g_repeat_final_track[i].strategy==strategy &&
         g_repeat_final_track[i].tf==tf)
         return i;
      if(!g_repeat_final_track[i].used && free_index<0)
         free_index=i;
   }

   if(free_index<0)
      free_index=0;

   g_repeat_final_track[free_index].used=true;
   g_repeat_final_track[free_index].strategy=strategy;
   g_repeat_final_track[free_index].tf=tf;
   g_repeat_final_track[free_index].long_bar=0;
   g_repeat_final_track[free_index].short_bar=0;
   g_repeat_final_track[free_index].long_high=0.0;
   g_repeat_final_track[free_index].long_low=0.0;
   g_repeat_final_track[free_index].long_close=0.0;
   g_repeat_final_track[free_index].short_high=0.0;
   g_repeat_final_track[free_index].short_low=0.0;
   g_repeat_final_track[free_index].short_close=0.0;
   return free_index;
}


bool RepeatFinalPersistenceAllows(const ENUM_STRATEGY_MODE strategy,
                                  const ENUM_TIMEFRAMES tf,
                                  const int side,
                                  const datetime current_bar,
                                  const double current_close,
                                  const bool macd_continuation,
                                  const bool delta_continuation,
                                  const bool macd_opposite,
                                  const bool delta_opposite,
                                  const int domains_required,
                                  string &detail,
                                  datetime &previous_final_bar_out)
{
   // v7.77 diagnostic-only momentum/structure snapshot.
   // Accepted FINAL history owns FIRST/REPEAT phase. This function no longer
   // mutates Repeat tracking or reopens FIRST on temporary momentum/structure
   // changes.
   detail="NO_PREVIOUS_FINAL";
   previous_final_bar_out=0;
   if(side==0 || current_bar<=0 || current_close<=0.0)
      return true;

   const int idx=RepeatFinalTrackIndex(strategy,tf);
   const datetime previous_bar=side>0 ?
      g_repeat_final_track[idx].long_bar :
      g_repeat_final_track[idx].short_bar;
   previous_final_bar_out=previous_bar;

   if(previous_bar<=0 || previous_bar==current_bar)
      return true;

   const double previous_high=side>0 ?
      g_repeat_final_track[idx].long_high :
      g_repeat_final_track[idx].short_high;
   const double previous_low=side>0 ?
      g_repeat_final_track[idx].long_low :
      g_repeat_final_track[idx].short_low;

   const bool structure_invalid=
      side>0 ? (previous_low>0.0 && current_close<previous_low) :
               (previous_high>0.0 && current_close>previous_high);
   const bool momentum_invalid=macd_opposite && delta_opposite;

   const int domains=
      (macd_continuation?1:0)+
      (delta_continuation?1:0);
   const int required=MathMax(1,MathMin(2,domains_required));

   detail=StringFormat(
      "REPEAT_DIAGNOSTIC %d/%d | MACD=%d DELTA=%d | STRUCTURE=%d MOMENTUM=%d | PREV=%s CLOSE=%.8f",
      domains,required,
      macd_continuation?1:0,delta_continuation?1:0,
      structure_invalid?1:0,momentum_invalid?1:0,
      TimeToString(previous_bar,TIME_DATE|TIME_MINUTES),
      current_close);
   return domains>=required;
}

void RepeatFinalRecordAccepted(const ENUM_STRATEGY_MODE strategy,
                               const ENUM_TIMEFRAMES tf,
                               const int side,
                               const datetime bar_time,
                               const double high_price,
                               const double low_price,
                               const double close_price)
{
   if(side==0 || bar_time<=0)
      return;

   const int idx=RepeatFinalTrackIndex(strategy,tf);

   // v7.65: RANGE directional persistence is the authoritative owner of the
   // FIRST/REPEAT episode.  A FINAL accepted against the still-persistent side
   // is diagnostic/price evidence only for Repeat-tracker ownership: it must
   // neither erase the persistent side's anchor nor pre-seed an opposite-side
   // Repeat anchor.  Otherwise the old side can reopen as FIRST, or a later
   // WATCH-confirmed ownership transfer can incorrectly begin as REPEAT.
   const bool non_owning_opposite_final=
      strategy==STRATEGY_RANGE &&
      ((side>0 && g_range_persistent_direction==-1) ||
       (side<0 && g_range_persistent_direction==1));
   if(non_owning_opposite_final)
      return;

   if(side>0)
   {
      if(g_repeat_final_track[idx].long_bar!=bar_time)
      {
         g_repeat_final_track[idx].long_bar=bar_time;
         g_repeat_final_track[idx].long_high=high_price;
         g_repeat_final_track[idx].long_low=low_price;
         g_repeat_final_track[idx].long_close=close_price;
      }
      g_repeat_final_track[idx].short_bar=0;
      g_repeat_final_track[idx].short_high=0.0;
      g_repeat_final_track[idx].short_low=0.0;
      g_repeat_final_track[idx].short_close=0.0;
   }
   else
   {
      if(g_repeat_final_track[idx].short_bar!=bar_time)
      {
         g_repeat_final_track[idx].short_bar=bar_time;
         g_repeat_final_track[idx].short_high=high_price;
         g_repeat_final_track[idx].short_low=low_price;
         g_repeat_final_track[idx].short_close=close_price;
      }
      g_repeat_final_track[idx].long_bar=0;
      g_repeat_final_track[idx].long_high=0.0;
      g_repeat_final_track[idx].long_low=0.0;
      g_repeat_final_track[idx].long_close=0.0;
   }
}

void ResetRepeatFinalTracking()
{
   for(int i=0;i<ArraySize(g_repeat_final_track);i++)
   {
      g_repeat_final_track[i].used=false;
      g_repeat_final_track[i].strategy=STRATEGY_RANGE;
      g_repeat_final_track[i].tf=PERIOD_CURRENT;
      g_repeat_final_track[i].long_bar=0;
      g_repeat_final_track[i].short_bar=0;
      g_repeat_final_track[i].long_high=0.0;
      g_repeat_final_track[i].long_low=0.0;
      g_repeat_final_track[i].long_close=0.0;
      g_repeat_final_track[i].short_high=0.0;
      g_repeat_final_track[i].short_low=0.0;
      g_repeat_final_track[i].short_close=0.0;
   }
}

void ProcessRangeClosedBar(const bool process_signals,
                      const bool process_auto)
{
   double base_line[], macd_color_state[], macd_zero_state[], raw[], delta_ema[];
   if(!CopySignalData(base_line, macd_color_state, macd_zero_state, raw, delta_ema))
      return;

   double fast[], slow[], ma70[], ma111[], ma200[], volume[];
   MqlRates calc_rates[];
   const int count = SignalRequiredHistoryCount();
   ArrayResize(fast, count);
   ArrayResize(slow, count);
   ArrayResize(ma70, count);
   ArrayResize(ma111, count);
   ArrayResize(ma200, count);
   ArrayResize(volume, count);
   ArrayResize(calc_rates, count);
   ArraySetAsSeries(fast, true);
   ArraySetAsSeries(slow, true);
   ArraySetAsSeries(ma70, true);
   ArraySetAsSeries(ma111, true);
   ArraySetAsSeries(ma200, true);
   ArraySetAsSeries(volume, true);
   ArraySetAsSeries(calc_rates, true);
   // v7.82: unified RANGE reuses the existing completed-bar snapshot.
   // Local arrays keep their original size/series semantics so all downstream
   // calculations remain byte-for-byte equivalent in indexing behavior.
   const bool shared_range_structure=
      g_selected_strategy==STRATEGY_RANGE &&
      g_calc_tf==AUTO_TF &&
      g_calc_fast_ma_handle==g_add_ma_handle &&
      g_calc_slow_ma_handle==g_slow_ma_handle &&
      g_calc_ma70_handle==g_ma70_handle &&
      g_calc_ma111_handle==g_ma111_handle &&
      g_calc_ma200_handle==g_ma200_handle &&
      g_calc_delta_handle==g_delta_handle;

   bool structure_ready=false;
   if(shared_range_structure && EnsureMarketSnapshotRange(count))
   {
      structure_ready=
         ArrayCopy(fast,g_ms_fast_ma,0,0,count)==count &&
         ArrayCopy(slow,g_ms_slow_ma,0,0,count)==count &&
         ArrayCopy(ma70,g_ms_ma70,0,0,count)==count &&
         ArrayCopy(ma111,g_ms_ma111,0,0,count)==count &&
         ArrayCopy(ma200,g_ms_ma200,0,0,count)==count &&
         ArrayCopy(volume,g_ms_delta_volume,0,0,count)==count &&
         ArrayCopy(calc_rates,g_ms_rates,0,0,count)==count;
   }
   else
   {
      structure_ready=
         MarketDataCopyBuffer(g_calc_fast_ma_handle, 0, 0, count, fast)>=count &&
         MarketDataCopyBuffer(g_calc_slow_ma_handle, 0, 0, count, slow)>=count &&
         MarketDataCopyBuffer(g_calc_ma70_handle, 0, 0, count, ma70)>=count &&
         MarketDataCopyBuffer(g_calc_ma111_handle, 0, 0, count, ma111)>=count &&
         MarketDataCopyBuffer(g_calc_ma200_handle, 0, 0, count, ma200)>=count &&
         MarketDataCopyBuffer(g_calc_delta_handle, 4, 0, count, volume)>=count &&
         MarketDataCopyRates(_Symbol, g_calc_tf, 0, count, calc_rates)>=count;
   }

   if(!structure_ready)
   {
      g_status = "WAITING FOR STRUCTURE DATA";
      return;
   }

   const double average_delta = AverageAbsoluteDelta(raw);
   if(average_delta <= 0.0)
      return;

   bool trend_macd_strong_long = false, trend_macd_strong_short = false;
   bool trend_delta_strong_long = false, trend_delta_strong_short = false;
   if(!CalculateCommonStrengthPersistence(
         base_line, macd_color_state, raw, delta_ema,
         InpTrendStrengthLookbackBars, InpTrendMACDStrengthFactor,
         InpTrendDeltaStrengthFactor, trend_macd_strong_long,
         trend_macd_strong_short, trend_delta_strong_long,
         trend_delta_strong_short))
      return;
   const bool trend_strong_direction_long =
      trend_macd_strong_long && trend_delta_strong_long;
   const bool trend_strong_direction_short =
      trend_macd_strong_short && trend_delta_strong_short;

   // v7.61 performance: calc_rates[] is already loaded once for this completed
   // bar. Reuse its OHLC/time snapshot instead of issuing synchronous terminal
   // series calls for the same shift later in this decision.
   const double open1 = calc_rates[1].open;
   const double close1 = calc_rates[1].close;
   const double high1 = calc_rates[1].high;
   const double low1 = calc_rates[1].low;
   const datetime range_final_bar = calc_rates[1].time;
   const bool base_up = base_line[1] > base_line[2];
   const bool base_down = base_line[1] < base_line[2];
   if(process_auto)
   {
      if(base_line[1] <= 0.0) g_long_regime_traded = false;
      if(base_line[1] >= 0.0) g_short_regime_traded = false;
   }
   int buy_dominance_bars = 0, sell_dominance_bars = 0;
   double dominance_sum = 0.0, average_volume = 0.0;
   for(int i = 1; i <= InpDominanceLookback; i++)
   {
      if(raw[i] >= InpDominanceWeakLevel) buy_dominance_bars++;
      if(raw[i] <= -InpDominanceWeakLevel) sell_dominance_bars++;
      dominance_sum += raw[i];
      average_volume += volume[i];
   }
   average_volume /= (double)InpDominanceLookback;
   const bool buy_dominance =
      buy_dominance_bars >= InpDominanceMinBars && dominance_sum > 0.0;
   const bool sell_dominance =
      sell_dominance_bars >= InpDominanceMinBars && dominance_sum < 0.0;

   // A MACD touch near zero is normal during consolidation.  Measure a
   // meaningful zero-line failure against the recent baseline amplitude so
   // the same rule scales across BTC, indices, metals and oil.
   double macd_reference = 0.0;
   const int macd_reference_bars =
      MathMax(2, MathMin(InpMACDReferenceBars, ArraySize(base_line) - 3));
   for(int i = 2; i < 2 + macd_reference_bars; i++)
      macd_reference += MathAbs(base_line[i]);
   macd_reference /= (double)macd_reference_bars;
   const double meaningful_zero_distance =
      MathMax(_Point, macd_reference * InpMACDZeroBreakFactor);

   // Current absolute low-energy snapshot. The 20-bar environment below is
   // retained only for research/CSV diagnostics and has no trading authority.
   const double no_energy_delta_limit = MathMax(_Point, average_delta * 0.35);
   const bool macd_dead =
      MathAbs(base_line[1]) <= meaningful_zero_distance &&
      MathAbs(base_line[2]) <= meaningful_zero_distance;
   const bool delta_dead =
      MathAbs(raw[1]) <= no_energy_delta_limit &&
      MathAbs(delta_ema[1]) <= no_energy_delta_limit;
   const bool absolute_no_market_energy = macd_dead && delta_dead;

   const int relative_energy_bars = MathMax(3, MathMin(20, ArraySize(base_line) - 3));
   double recent_range_sum = 0.0;
   double recent_macd_sum = 0.0;
   double recent_delta_sum = 0.0;
   for(int i = 2; i < 2 + relative_energy_bars; i++)
   {
      recent_range_sum += MathMax(_Point, calc_rates[i].high - calc_rates[i].low);
      recent_macd_sum += MathAbs(base_line[i]);
      recent_delta_sum += MathAbs(raw[i]);
   }
   const double recent_range_avg = recent_range_sum / (double)relative_energy_bars;
   const double recent_macd_avg = recent_macd_sum / (double)relative_energy_bars;
   const double recent_delta_avg = recent_delta_sum / (double)relative_energy_bars;
   const double current_range = MathMax(_Point, high1 - low1);
   const double relative_range_ratio = current_range / MathMax(_Point, recent_range_avg);
   const double relative_macd_ratio = MathAbs(base_line[1]) / MathMax(_Point, recent_macd_avg);
   const double relative_delta_ratio = MathAbs(raw[1]) / MathMax(_Point, recent_delta_avg);

   // v2.62: close the dead-sideways blind spot without adding another engine
   // or another score.  A temporary Delta flicker must not create FINAL when:
   //   1) MACD is still effectively on zero,
   //   2) price/MA structure is compressed, and
   //   3) actual participation volume is weak.
   //
   // A real breakout is preserved because a meaningful price range or MA
   // expansion makes price_dead false even if MACD starts near zero.
   const double previous_close = calc_rates[2].close;
   const double close_progress =
      previous_close > 0.0 ? MathAbs(close1-previous_close) : current_range;
   const bool price_dead =
      current_range <= recent_range_avg * 0.35 &&
      close_progress <= recent_range_avg * 0.25 &&
      MathAbs(fast[1]-slow[1]) <= recent_range_avg * 0.12;
   const bool volume_dead =
      average_volume > 0.0 &&
      volume[1] <= average_volume * 0.60;
   const bool dead_sideways_structure =
      macd_dead && price_dead && volume_dead;

   // v2.29: 20-bar relative values are research/CSV diagnostics only.
   // They no longer create, rescue, block or cancel any trading signal.
   // Keep the booleans so historical CSV analysis remains available.
   const bool relative_macd_ok = relative_macd_ratio >= 0.80;
   const bool relative_delta_ok = relative_delta_ratio >= 0.80;
   const bool relative_energy_ok = relative_macd_ok && relative_delta_ok;

   // Current-market absolute energy remains part of the existing market-state
   // logic.  It is independent of the 20-bar relative baseline.
   const bool macd_absolute_ok = MathAbs(base_line[1]) > meaningful_zero_distance;
   const bool delta_absolute_ok =
      MathAbs(raw[1]) > no_energy_delta_limit ||
      MathAbs(delta_ema[1]) > no_energy_delta_limit;
   const bool real_energy_ok = macd_absolute_ok || delta_absolute_ok;

   // Dead-market detection remains current-state based.  Keep the original
   // MACD+Delta dead test and add only the low-volume compressed-price case.
   // This catches "MACD near zero + no participation + no price progress"
   // while allowing a genuine zero-line breakout to survive.
   const bool no_market_energy =
      absolute_no_market_energy || dead_sideways_structure;

   const int exit_confirm_bars =
      MathMax(1, MathMin(InpExitConfirmBars,
                        MathMin(ArraySize(base_line),
                                ArraySize(slow)) - 2));
   bool long_macd_failure = true, short_macd_failure = true;
   bool long_ma22_failure = true, short_ma22_failure = true;
   bool opposite_sell_confirmed = true, opposite_buy_confirmed = true;
   for(int i = 1; i <= exit_confirm_bars; i++)
   {
      if(!(base_line[i] < -meaningful_zero_distance &&
           base_line[i] < base_line[i + 1]))
         long_macd_failure = false;
      if(!(base_line[i] > meaningful_zero_distance &&
           base_line[i] > base_line[i + 1]))
         short_macd_failure = false;
      if(!(calc_rates[i].close < slow[i]))
         long_ma22_failure = false;
      if(!(calc_rates[i].close > slow[i]))
         short_ma22_failure = false;
      if(!(raw[i] <= -InpDominanceWeakLevel))
         opposite_sell_confirmed = false;
      if(!(raw[i] >= InpDominanceWeakLevel))
         opposite_buy_confirmed = false;
   }
   const bool strong_buy =
      raw[1] >= InpDominanceStrongLevel && delta_ema[1] > delta_ema[2];
   const bool strong_sell =
      raw[1] <= -InpDominanceStrongLevel && delta_ema[1] < delta_ema[2];
   const bool volume_expansion =
      average_volume > 0.0 &&
      volume[1] >= average_volume * InpBreakoutVolumeFactor;

   const bool macd_turn_long =
      BarsSinceMostRecentCross(base_line, 1) >= 0 && base_line[1] > 0.0;
   const bool macd_turn_short =
      BarsSinceMostRecentCross(base_line, -1) >= 0 && base_line[1] < 0.0;
   bool ma_turn_long = false;
   bool ma_turn_short = false;
   for(int shift = 1; shift <= InpSignalValidBars; shift++)
   {
      if(fast[shift] > slow[shift] &&
         fast[shift + 1] <= slow[shift + 1])
         ma_turn_long = true;
      if(fast[shift] < slow[shift] &&
         fast[shift + 1] >= slow[shift + 1])
         ma_turn_short = true;
   }

   const bool signal_reaccel_long =
      base_line[1] > 0.0 && base_up &&
      HasConfirmedPullback(1, fast, slow);
   const bool signal_reaccel_short =
      base_line[1] < 0.0 && base_down &&
      HasConfirmedPullback(-1, fast, slow);
   const bool auto_reaccel_long =
      base_line[1] > 0.0 && base_up &&
      HasConfirmedPullback(1, fast, slow);
   const bool auto_reaccel_short =
      base_line[1] < 0.0 && base_down &&
      HasConfirmedPullback(-1, fast, slow);
   const bool turn_long = macd_turn_long && ma_turn_long;
   const bool turn_short = macd_turn_short && ma_turn_short;

   double prior_high = calc_rates[2].high;
   double prior_low = calc_rates[2].low;
   for(int i = 3; i <= InpSwingLookback + 1; i++)
   {
      prior_high = MathMax(prior_high, calc_rates[i].high);
      prior_low = MathMin(prior_low, calc_rates[i].low);
   }
   const bool high_break = close1 > prior_high;
   const bool low_break = close1 < prior_low;

   double recent_high = calc_rates[2].high;
   double recent_low = calc_rates[2].low;
   double older_high = recent_high, older_low = recent_low;
   for(int i = 2; i <= InpCompressionRecentBars + 1; i++)
   {
      recent_high = MathMax(recent_high, calc_rates[i].high);
      recent_low = MathMin(recent_low, calc_rates[i].low);
   }
   for(int i = InpCompressionRecentBars + 2;
       i <= InpCompressionLookback + 1; i++)
   {
      older_high = MathMax(older_high, calc_rates[i].high);
      older_low = MathMin(older_low, calc_rates[i].low);
   }
   const double recent_range = recent_high - recent_low;
   const double older_range = older_high - older_low;
   const bool compressed =
      older_range > 0.0 &&
      recent_range <= older_range * InpCompressionRatio;
   const bool long_decline_or_sideways =
      ma70[InpCompressionRecentBars + 1] >= ma70[1] ||
      MathAbs(ma70[1] - ma70[InpCompressionRecentBars + 1]) <=
      MathMax(_Point, recent_range * 0.20);
   const bool compression_break_long =
      compressed && long_decline_or_sideways && close1 > recent_high &&
      volume_expansion;
   const bool compression_break_short =
      compressed && close1 < recent_low && volume_expansion;
   const bool ma22_up = slow[1] > slow[3];
   const bool ma22_down = slow[1] < slow[3];
   const bool ma70_up = ma70[1] > ma70[3];
   const bool ma70_down = ma70[1] < ma70[3];

   // Common Direction Quality snapshot used by common chart signals and RANGE AUTO.
   int long_direction_quality = 0, short_direction_quality = 0;
   bool direction_long_allowed = false, direction_short_allowed = false;
   bool neutral_flow = false, compressed_chop = false;
   bool late_direction_long = false, late_direction_short = false;
   CalculateCommonDirectionQuality(fast, slow, ma70, base_line, raw, count,
      close1, base_up, base_down, buy_dominance, sell_dominance,
      dominance_sum, average_delta, ma22_up, ma22_down, ma70_up, ma70_down,
      long_direction_quality, short_direction_quality,
      direction_long_allowed, direction_short_allowed,
      neutral_flow, compressed_chop, late_direction_long, late_direction_short);

   const bool long_retest =
      low1 <= slow[1] && close1 > slow[1] && buy_dominance;
   const bool short_retest =
      high1 >= slow[1] && close1 < slow[1] && sell_dominance;
   const bool protected_by_111 =
      close1 > ma111[1] && ma111[1] >= ma111[3] &&
      slow[1] > ma70[1] && !low_break;
   const bool oversized = OversizedClosedBar();

   // Timing-window logic: detect the first usable price trigger after MACD/Delta
   // direction turns. This does not require a zero-line cross and therefore
   // catches the boxed reversal legs without entering on the first weak hint.
   const double timing_average_range = MathMax(_Point, AverageClosedBarRange());
   double timing_high = calc_rates[2].high;
   double timing_low  = calc_rates[2].low;
   const int timing_lookback = MathMax(2, MathMin(InpTimingBreakLookback, count - 3));
   for(int i = 3; i <= timing_lookback + 1; i++)
   {
      timing_high = MathMax(timing_high, calc_rates[i].high);
      timing_low  = MathMin(timing_low,  calc_rates[i].low);
   }
   const bool micro_break_long = close1 > timing_high;
   const bool micro_break_short = close1 < timing_low;
   const bool fast_reclaim_long =
      low1 <= fast[1] && close1 > fast[1] && close1 > open1;
   const bool fast_reject_short =
      high1 >= fast[1] && close1 < fast[1] && close1 < open1;
   const bool macd_turning_long =
      base_up && (base_line[2] <= base_line[3] || base_line[1] > base_line[3]);
   const bool macd_turning_short =
      base_down && (base_line[2] >= base_line[3] || base_line[1] < base_line[3]);
   const bool delta_recovery_long =
      raw[1] > 0.0 || (raw[1] > raw[2] && delta_ema[1] > delta_ema[2] && dominance_sum > 0.0);
   const bool delta_recovery_short =
      raw[1] < 0.0 || (raw[1] < raw[2] && delta_ema[1] < delta_ema[2] && dominance_sum < 0.0);
   const bool timing_not_late_long =
      close1 >= fast[1] && (close1 - fast[1]) <= timing_average_range * InpTimingMaxFastDistance;
   const bool timing_not_late_short =
      close1 <= fast[1] && (fast[1] - close1) <= timing_average_range * InpTimingMaxFastDistance;
   const bool range_timing_long =
      macd_turning_long && delta_recovery_long && timing_not_late_long &&
      (micro_break_long || fast_reclaim_long);
   const bool range_timing_short =
      macd_turning_short && delta_recovery_short && timing_not_late_short &&
      (micro_break_short || fast_reject_short);

   // v6.61 RANGE directional momentum regime.
   // Direction is NOT predicted before MACD confirmation.  A same-direction
   // FINAL sequence becomes eligible only when MACD is already meaningfully on
   // that side of zero, Delta participation is on the same side, and price is
   // actually progressing in that direction.
   const bool range_price_progress_long =
      high_break || micro_break_long ||
      (close1 > calc_rates[2].close && fast[1] > fast[2] && close1 >= fast[1]);
   const bool range_price_progress_short =
      low_break || micro_break_short ||
      (close1 < calc_rates[2].close && fast[1] < fast[2] && close1 <= fast[1]);

   const bool range_directional_regime_long =
      base_line[1] > meaningful_zero_distance &&
      macd_absolute_ok &&
      raw[1] > 0.0 && delta_ema[1] > 0.0 && delta_absolute_ok &&
      range_price_progress_long &&
      !strong_sell;
   const bool range_directional_regime_short =
      base_line[1] < -meaningful_zero_distance &&
      macd_absolute_ok &&
      raw[1] < 0.0 && delta_ema[1] < 0.0 && delta_absolute_ok &&
      range_price_progress_short &&
      !strong_buy &&
      !protected_by_111;

   // M5 predicts direction; M2 MA22 authorizes the actual fill.
   const double ma22_touch_tolerance =
      timing_average_range * InpTradingTFMA22TouchToleranceRange;
   const bool m2_ma22_long_trigger =
      (low1 <= slow[1] + ma22_touch_tolerance && close1 > slow[1]) ||
      (InpAllowRangeMA22DirectCross && calc_rates[2].close <= slow[2] && close1 > slow[1]);
   const bool m2_ma22_short_trigger =
      (high1 >= slow[1] - ma22_touch_tolerance && close1 < slow[1]) ||
      (InpAllowRangeMA22DirectCross && calc_rates[2].close >= slow[2] && close1 < slow[1]);
   // v7.61 performance: TradingTFDirectionMaintained() internally performs
   // three CopyBuffer reads. This closed-bar path used to call it six times
   // with identical market inputs. Calculate the scores once and reuse the
   // two directional booleans throughout this decision.
   const bool trading_tf_direction_required =
      InpRequireTradingTFDirectionForAdd ||
      InpRequireTradingTFBiasForInitialEntry;
   int cached_trading_tf_long_score=0;
   int cached_trading_tf_short_score=0;
   const bool trading_tf_scores_ready =
      !trading_tf_direction_required ||
      CalculateTradingTFDirectionScores(
         cached_trading_tf_long_score,cached_trading_tf_short_score);
   const bool trading_tf_long_maintained =
      !trading_tf_direction_required ||
      (trading_tf_scores_ready &&
       cached_trading_tf_long_score>=InpTradingTFDirectionMinimumScore &&
       cached_trading_tf_long_score>=
          cached_trading_tf_short_score+InpTradingTFDirectionMinimumGap);
   const bool trading_tf_short_maintained =
      !trading_tf_direction_required ||
      (trading_tf_scores_ready &&
       cached_trading_tf_short_score>=InpTradingTFDirectionMinimumScore &&
       cached_trading_tf_short_score>=
          cached_trading_tf_long_score+InpTradingTFDirectionMinimumGap);

   const bool trading_tf_bias_long =
      !InpRequireTradingTFBiasForInitialEntry || trading_tf_long_maintained;
   const bool trading_tf_bias_short =
      !InpRequireTradingTFBiasForInitialEntry || trading_tf_short_maintained;

   bool bull_rejection = false, bull_engulfing = false;
   bool bull_favourable_edge = false, bull_opposite_edge = false;
   bool bear_rejection = false, bear_engulfing = false;
   bool bear_favourable_edge = false, bear_opposite_edge = false;
   CandlePatternState(g_calc_tf, 1, bull_rejection, bull_engulfing,
                      bull_favourable_edge, bull_opposite_edge);
   CandlePatternState(g_calc_tf, -1, bear_rejection, bear_engulfing,
                      bear_favourable_edge, bear_opposite_edge);
   const bool bullish_pattern = bull_rejection || bull_engulfing;
   const bool bearish_pattern = bear_rejection || bear_engulfing;

   // v1.96 context-balanced score engine.
   // Each evidence family has a hard cap so correlated observations cannot
   // multiply the same move into an artificial 80-100 score. Final gates are
   // unchanged; this only makes the score itself represent evidence quality.
   // v6.63 directional-core scoring.
   // Once MACD is meaningfully on one side of zero, that confirmed state is
   // evidence by itself; a fresh turn/slope acceleration is an enhancement,
   // not a prerequisite for a useful score.
   int long_macd_score = 0, short_macd_score = 0;
   if(base_line[1] > meaningful_zero_distance && macd_absolute_ok)
   {
      long_macd_score = 20;
      if(base_up || macd_turn_long || signal_reaccel_long)
         long_macd_score += 5;
   }
   else if(macd_turn_long)
      long_macd_score = 15;

   if(base_line[1] < -meaningful_zero_distance && macd_absolute_ok)
   {
      short_macd_score = 20;
      if(base_down || macd_turn_short || signal_reaccel_short)
         short_macd_score += 5;
   }
   else if(macd_turn_short)
      short_macd_score = 15;

   int long_delta_score = 0, short_delta_score = 0;
   // Same-side raw + EMA participation receives a stable core score.  Strong
   // dominance/expansion still improves quality but is no longer required on
   // every completed bar of a valid directional episode.
   if(raw[1] > 0.0 && delta_ema[1] > 0.0 && delta_absolute_ok)
      long_delta_score += 15;
   if(buy_dominance) long_delta_score += 5;
   if(strong_buy) long_delta_score += 3;
   if(volume_expansion && raw[1] > 0.0) long_delta_score += 2;

   if(raw[1] < 0.0 && delta_ema[1] < 0.0 && delta_absolute_ok)
      short_delta_score += 15;
   if(sell_dominance) short_delta_score += 5;
   if(strong_sell) short_delta_score += 3;
   if(volume_expansion && raw[1] < 0.0) short_delta_score += 2;

   long_delta_score = MathMin(25,long_delta_score);
   short_delta_score = MathMin(25,short_delta_score);

   int long_ma_score = 0, short_ma_score = 0;
   if(ma22_up && close1 > slow[1]) long_ma_score += 10;
   if(slow[1] > ma70[1] && ma70_up) long_ma_score += 10;
   if(close1 > ma111[1] && close1 > ma200[1]) long_ma_score += 5;
   if(ma22_down && close1 < slow[1]) short_ma_score += 10;
   if(slow[1] < ma70[1] && ma70_down) short_ma_score += 10;
   if(close1 < ma111[1] && close1 < ma200[1]) short_ma_score += 5;
   long_ma_score = MathMin(20,long_ma_score);
   short_ma_score = MathMin(20,short_ma_score);

   int long_price_score = 0, short_price_score = 0;
   // Fresh same-direction progression is a primary directional-core domain.
   // Structural/micro breaks add quality, while the family remains capped.
   if(range_price_progress_long) long_price_score += 10;
   if(high_break || compression_break_long) long_price_score += 5;
   if(range_timing_long || micro_break_long) long_price_score += 5;

   if(range_price_progress_short) short_price_score += 10;
   if(low_break || compression_break_short) short_price_score += 5;
   if(range_timing_short || micro_break_short) short_price_score += 5;

   long_price_score = MathMin(20,long_price_score);
   short_price_score = MathMin(20,short_price_score);

   int long_pattern_score = bull_rejection ? 10 : (bull_engulfing ? 7 : (bull_favourable_edge ? 4 : 0));
   int short_pattern_score = bear_rejection ? 10 : (bear_engulfing ? 7 : (bear_favourable_edge ? 4 : 0));
   if(bearish_pattern) long_pattern_score -= 10;
   if(bullish_pattern) short_pattern_score -= 10;
   if(InpBlockOppositeRangeEdge && bull_opposite_edge && !bullish_pattern) long_pattern_score -= 10;
   if(InpBlockOppositeRangeEdge && bear_opposite_edge && !bearish_pattern) short_pattern_score -= 10;

   const int long_tf_score = trading_tf_long_maintained ? 10 : 0;
   const int short_tf_score = trading_tf_short_maintained ? 10 : 0;

   double score_location = 0.50, score_range_high = 0.0, score_range_low = 0.0;
   const bool range_location_valid =
      CalculateRangeLocation(close1, score_location,
                             score_range_high, score_range_low);
   const double decision_range_location =
      range_location_valid ? score_location : -1.0;
   int long_location_score = 0, short_location_score = 0;
   if(range_location_valid)
   {
      const int location_cap = MathMin(10,MathMax(0,InpRangeLocationMaximumScore));
      const double long_directional = MathMax(-1.0,MathMin(1.0,(0.50-score_location)*2.0));
      const double short_directional = MathMax(-1.0,MathMin(1.0,(score_location-0.50)*2.0));
      long_location_score = (int)MathRound(long_directional*location_cap);
      short_location_score = (int)MathRound(short_directional*location_cap);

      if(range_directional_regime_long && long_location_score<0)
         long_location_score=0;
      if(range_directional_regime_short && short_location_score<0)
         short_location_score=0;
   }

   int long_score_pre_context = long_macd_score + long_delta_score + long_ma_score +
                                long_price_score + long_pattern_score + long_tf_score + long_location_score;
   int short_score_pre_context = short_macd_score + short_delta_score + short_ma_score +
                                 short_price_score + short_pattern_score + short_tf_score + short_location_score;

      // Opposite dominance is negative evidence, not a second independent score family.
   if(sell_dominance) long_score_pre_context -= 10;
   if(buy_dominance) short_score_pre_context -= 10;

   // Context penalty: a tiny rebound inside an established opposite trend may
   // turn MACD/Delta briefly and collect points, but it should not look like a
   // high-quality reversal. The penalty disappears once MA22, MACD direction
   // and raw Delta genuinely confirm a reversal, so legitimate reversals are
   // not delayed by a higher threshold.
   const bool genuine_reversal_long_context = close1 > slow[1] && base_up && raw[1] > 0.0;
   const bool genuine_reversal_short_context = close1 < slow[1] && base_down && raw[1] < 0.0;
   int long_context_penalty = 0, short_context_penalty = 0;

   // v6.64: a fully confirmed CURRENT directional regime already contains
   // MACD side/energy + Delta side/energy + fresh same-direction Price
   // progression. Do not subtract stale MA/old-trend context from that core.
   // Opposite momentum, pattern, energy/chop, late-direction and countertrend
   // protections remain independent downstream gates.
   if(!genuine_reversal_long_context && !range_directional_regime_long)
   {
      if(trend_strong_direction_short) long_context_penalty += 10;
      if(fast[1] < slow[1]) long_context_penalty += 5;
      if(close1 < slow[1]) long_context_penalty += 5;
      if(slow[1] <= ma70[1]) long_context_penalty += 5;
      if(base_line[1] < 0.0) long_context_penalty += 5;
      if(ma22_down) long_context_penalty += 5;
   }
   if(!genuine_reversal_short_context && !range_directional_regime_short)
   {
      if(trend_strong_direction_long) short_context_penalty += 10;
      if(fast[1] > slow[1]) short_context_penalty += 5;
      if(close1 > slow[1]) short_context_penalty += 5;
      if(slow[1] >= ma70[1]) short_context_penalty += 5;
      if(base_line[1] > 0.0) short_context_penalty += 5;
      if(ma22_up) short_context_penalty += 5;
   }
   long_context_penalty = MathMin(35,long_context_penalty);
   short_context_penalty = MathMin(35,short_context_penalty);

   int long_score = long_score_pre_context - long_context_penalty;
   int short_score = short_score_pre_context - short_context_penalty;
   long_score = MathMax(0, MathMin(100, long_score));
   short_score = MathMax(0, MathMin(100, short_score));
   g_last_long_score = long_score;
   g_last_short_score = short_score;

   const bool unsafe_long =
      oversized || strong_sell || (!buy_dominance && !delta_recovery_long) || bearish_pattern ||
      (InpUseRangePatternFilter && InpBlockOppositeRangeEdge &&
       bull_opposite_edge && !bullish_pattern) ||
      (!ma22_up && MathAbs(slow[1] - slow[3]) < _Point);
   const bool unsafe_short =
      oversized || strong_buy || (!sell_dominance && !delta_recovery_short) || protected_by_111 ||
      bullish_pattern ||
      (InpUseRangePatternFilter && InpBlockOppositeRangeEdge &&
       bear_opposite_edge && !bearish_pattern) ||
      (!ma22_down && MathAbs(slow[1] - slow[3]) < _Point);

   // Dominant directional context prevents a single opposite delta bar or a
   // small MACD contraction from being advertised as a reversal signal.
   const bool dominant_long_context =
      base_line[1] > 0.0 && buy_dominance && dominance_sum > 0.0 &&
      close1 > slow[1] && ma22_up;
   const bool dominant_short_context =
      base_line[1] < 0.0 && sell_dominance && dominance_sum < 0.0 &&
      close1 < slow[1] && ma22_down;

   // RANGE chart signals are deliberately more permissive than AUTO entry,
   // but an EARLY TURN may not oppose an established MACD/Delta trend.
   const bool early_turn_long =
      (!InpBlockCounterTrendEarlySignal || !dominant_short_context) &&
      macd_turning_long && delta_recovery_long &&
      (fast[1] > fast[2] || close1 >= fast[1] || micro_break_long);
   const bool early_turn_short =
      (!InpBlockCounterTrendEarlySignal || !dominant_long_context) &&
      macd_turning_short && delta_recovery_short &&
      (fast[1] < fast[2] || close1 <= fast[1] || micro_break_short);

   // Controlled continuation entry restores the former RE-ACCEL/CHASE fill
   // without allowing an unlimited late entry. It requires dominant MACD and
   // Delta direction, aligned MA structure, a fresh break and bounded MA7 distance.
   const bool continuation_distance_long =
      close1 >= fast[1] &&
      (close1 - fast[1]) <= timing_average_range * InpContinuationMaxFastDistance;
   const bool continuation_distance_short =
      close1 <= fast[1] &&
      (fast[1] - close1) <= timing_average_range * InpContinuationMaxFastDistance;
   const bool continuation_break_long =
      !InpContinuationRequireBreak || micro_break_long || high_break;
   const bool continuation_break_short =
      !InpContinuationRequireBreak || micro_break_short || low_break;
   const bool continuation_long_entry =
      InpAllowTrendContinuationAuto && dominant_long_context &&
      fast[1] > slow[1] && signal_reaccel_long && continuation_distance_long &&
      continuation_break_long && !oversized && !strong_sell;
   const bool continuation_short_entry =
      InpAllowTrendContinuationAuto && dominant_short_context &&
      fast[1] < slow[1] && signal_reaccel_short && continuation_distance_short &&
      continuation_break_short && !oversized && !strong_buy && !protected_by_111;

   // v2.16 simplified RANGE signal decision.
   // There is only one numeric decision score per side: long_score/short_score.
   // DQ, EARLY/CONFIRMED labels and internal RANGE state remain diagnostic
   // context only and never create a second score or independent signal.
   const int range_display_long_score = long_score;
   const int range_display_short_score = short_score;

   // Preserve the internal state machine only for diagnostics/CSV continuity.
   // It has no authority over FINAL signal creation or AUTO entry.
   const bool range_state_long_setup =
      long_score >= InpChartSignalScore &&
      (macd_turning_long || delta_recovery_long);
   const bool range_state_short_setup =
      short_score >= InpChartSignalScore &&
      (macd_turning_short || delta_recovery_short);
   UpdateRangeInternalState(range_state_long_setup, range_state_short_setup,
                            early_turn_long, early_turn_short,
                            m2_ma22_long_trigger && trading_tf_bias_long,
                            m2_ma22_short_trigger && trading_tf_bias_short);

   // EARLY/CONFIRMED are no longer separate signal paths. Their underlying
   // MACD/Delta/MA/price evidence is already represented in the final score.
   // A RANGE candidate is therefore just a >=65 final score with a current
   // directional trigger; the common market gate is applied below.
   const bool range_signal_trigger_long =
      range_timing_long || turn_long || compression_break_long || early_turn_long ||
      range_directional_regime_long ||
      (InpAllowContinuation && signal_reaccel_long);
   const bool range_signal_trigger_short =
      range_timing_short || turn_short || compression_break_short || early_turn_short ||
      range_directional_regime_short ||
      (InpAllowContinuation && signal_reaccel_short);

   // v7.02: keep one common FINAL score threshold. Direction is constrained
   // by the MACD zero line before a RANGE FINAL can exist: LONG only when the
   // completed-bar MACD is meaningfully above zero, SHORT only when it is
   // meaningfully below zero. The existing meaningful_zero_distance is reused
   // as the zero/chop dead band; no new fixed symbol-dependent threshold is added.
   const int range_long_required_score = InpChartSignalScore;
   const int range_short_required_score = InpChartSignalScore;
   const bool range_macd_side_long =
      base_line[1] > meaningful_zero_distance && macd_absolute_ok;
   const bool range_macd_side_short =
      base_line[1] < -meaningful_zero_distance && macd_absolute_ok;

   // v7.51: FIRST FINAL remains strict.  Once the existing RANGE persistence
   // has already established a direction, do not make continuation FINALs
   // re-qualify through the slow Signal/Base zero-side and a fresh turn /
   // compression / reacceleration event on every completed bar.  Score and
   // score-gap remain required here; the existing continuation/final gates,
   // opposite-momentum, countertrend and Repeat-FINAL protections still apply
   // downstream.
   const bool range_persistent_candidate_long =
      g_range_persistent_direction>0 &&
      long_score >= range_long_required_score &&
      long_score >= short_score + InpBothDirectionMinimumScoreGap;
   const bool range_persistent_candidate_short =
      g_range_persistent_direction<0 &&
      short_score >= range_short_required_score &&
      short_score >= long_score + InpBothDirectionMinimumScoreGap;

   const bool range_score_candidate_long =
      (range_macd_side_long && range_signal_trigger_long &&
       long_score >= range_long_required_score &&
       long_score >= short_score + InpBothDirectionMinimumScoreGap) ||
      range_persistent_candidate_long;
   const bool range_score_candidate_short =
      (range_macd_side_short && range_signal_trigger_short &&
       short_score >= range_short_required_score &&
       short_score >= long_score + InpBothDirectionMinimumScoreGap) ||
      range_persistent_candidate_short;

   // Keep strength calculation for diagnostics and legacy non-initial paths.
   // It does not decide the completed-bar FINAL signal.
   bool range_macd_strong_long = false, range_macd_strong_short = false;
   bool range_delta_strong_long = false, range_delta_strong_short = false;
   if(!CalculateCommonStrengthPersistence(
         base_line, macd_color_state, raw, delta_ema,
         InpRangeStrengthLookbackBars, InpRangeMACDStrengthFactor,
         InpRangeDeltaStrengthFactor, range_macd_strong_long,
         range_macd_strong_short, range_delta_strong_long,
         range_delta_strong_short))
      return;

   // v2.29 RANGE final gate.
   // The 20-bar relative baseline has no trading authority.  FINAL signals use
   // only the existing current-market structure: directional MACD+Delta flow,
   // absolute dead-market protection, neutral/compressed state and direction.
   const bool direction_flow_long_ok = base_up && delta_recovery_long;
   const bool direction_flow_short_ok = base_down && delta_recovery_short;

   // v5.59 (exact v5.41 base):
   // Keep the original strict MACD+Delta flow for new/turning direction.
   // Only when RANGE directional persistence is already established, allow
   // existing price/MA structure to confirm continuation through a temporary
   // MACD/Delta re-acceleration pause. No new score/state/engine is added.
   const bool range_assist_snapshot_valid=
      InpAssistStateEnabled &&
      g_assist_state.bar_time==range_final_bar &&
      g_assist_state.timeframe==g_calc_tf;

   // v7.74 canonical established-episode context.
   // Previous versions accumulated multiple continuation rescue paths and then
   // briefly made exact StateEvaluation UP/DOWN a second episode gate.  The
   // established episode now has one owner only: RANGE persistence.
   // v7.74 canonical established-episode ownership:
   // Persistence itself owns whether an episode is established.
   // StateEvaluation describes the current condition *inside* that episode
   // (UP/DOWN, WEAKENING, NEUTRAL, WATCH) and must not become a second
   // episode-existence gate.  Opposite WATCH/structure lifecycle resets the
   // Repeat tracker separately, so no additional state==UP/DOWN filter is needed.
   const bool range_established_episode_long =
      g_range_persistent_direction>0;
   const bool range_established_episode_short =
      g_range_persistent_direction<0;

   // v7.77 signal phase ownership:
   // Persistence is last-established direction memory. An active WATCH is a
   // transition phase, so persistence remains intact but continuation REPEAT
   // is not eligible until WATCH is cancelled or FIRST commits the new side.
   const bool range_transition_active =
      range_assist_snapshot_valid &&
      (g_assist_state.state==JTA_ASSIST_REVERSAL_WATCH_UP ||
       g_assist_state.state==JTA_ASSIST_REVERSAL_WATCH_DOWN);
   const bool range_continuation_phase_long =
      range_established_episode_long && !range_transition_active;
   const bool range_continuation_phase_short =
      range_established_episode_short && !range_transition_active;

   // Backward-compatible CSV fields only. These names no longer own strategy
   // authority and intentionally mirror the single canonical episode context.
   const bool assist_persistent_continuation_long=range_established_episode_long;
   const bool assist_persistent_continuation_short=range_established_episode_short;

   // v6.62: the fully confirmed MACD+Delta+Price directional regime is
   // itself valid directional FLOW.  Do not require MACD to accelerate again
   // on every completed bar once it is meaningfully on the correct side of
   // zero and fresh same-direction price progression is present.
   const bool effective_direction_flow_long_ok =
      direction_flow_long_ok ||
      range_directional_regime_long ||
      range_established_episode_long;
   const bool effective_direction_flow_short_ok =
      direction_flow_short_ok ||
      range_directional_regime_short ||
      range_established_episode_short;

   // v6.64: lookback Direction Quality is intentionally slower than the
   // current-bar directional regime. When the current regime is fully proven,
   // stale historical ratios/MA alignment may not veto the first valid FINAL.
   // Neutral, compressed-chop and late-entry protection remain hard.
   const bool current_regime_long_allowed =
      range_directional_regime_long &&
      !neutral_flow && !compressed_chop && !late_direction_long;
   const bool current_regime_short_allowed =
      range_directional_regime_short &&
      !neutral_flow && !compressed_chop && !late_direction_short;

   const bool range_direction_long_allowed =
      current_regime_long_allowed ||
      (direction_long_allowed && !late_direction_long &&
       long_direction_quality >= short_direction_quality + InpMinimumDirectionQualityGap);
   const bool range_direction_short_allowed =
      current_regime_short_allowed ||
      (direction_short_allowed && !late_direction_short &&
       short_direction_quality >= long_direction_quality + InpMinimumDirectionQualityGap);

   // Neutral/compression/dead-market authority is retained. The continuation
   // alternative can only replace the transient FLOW_MISMATCH requirement;
   // it cannot bypass market-energy, chop, direction-quality or countertrend
   // gates elsewhere in the existing FINAL path.
   const bool range_neutral_block_long =
      neutral_flow && !(effective_direction_flow_long_ok && real_energy_ok);
   const bool range_neutral_block_short =
      neutral_flow && !(effective_direction_flow_short_ok && real_energy_ok);

   // v7.56: once the existing RANGE persistence and current Assist snapshot
   // agree on a continuation direction, do not re-veto that same episode with
   // transient FLOW_MISMATCH or the slower direction-quality gate. The live
   // dead-market/chop and strong-opposite protections remain authoritative.
   const bool range_long_final_gate =
      !no_market_energy && !compressed_chop &&
      (range_established_episode_long ||
       (effective_direction_flow_long_ok &&
        !range_neutral_block_long && range_direction_long_allowed));
   const bool range_short_final_gate =
      !no_market_energy && !compressed_chop &&
      (range_established_episode_short ||
       (effective_direction_flow_short_ok &&
        !range_neutral_block_short && range_direction_short_allowed));
   string range_long_gate_block_reason = "";
   string range_short_gate_block_reason = "";
   if(no_market_energy)
      range_long_gate_block_reason = "NO_MARKET_ENERGY";
   else if(compressed_chop)
      range_long_gate_block_reason = "COMPRESSED_CHOP";
   else if(!range_established_episode_long && !effective_direction_flow_long_ok)
      range_long_gate_block_reason = "FLOW_MISMATCH";
   else if(!range_established_episode_long && range_neutral_block_long)
      range_long_gate_block_reason = "NEUTRAL_FLOW";
   else if(!range_established_episode_long && !range_direction_long_allowed)
      range_long_gate_block_reason = "LONG_DIRECTION_NOT_ALLOWED";

   if(no_market_energy)
      range_short_gate_block_reason = "NO_MARKET_ENERGY";
   else if(compressed_chop)
      range_short_gate_block_reason = "COMPRESSED_CHOP";
   else if(!range_established_episode_short && !effective_direction_flow_short_ok)
      range_short_gate_block_reason = "FLOW_MISMATCH";
   else if(!range_established_episode_short && range_neutral_block_short)
      range_short_gate_block_reason = "NEUTRAL_FLOW";
   else if(!range_established_episode_short && !range_direction_short_allowed)
      range_short_gate_block_reason = "SHORT_DIRECTION_NOT_ALLOWED";

   // Persist the completed-bar market-regime snapshot for the single tester CSV.
   g_csv_neutral_flow = neutral_flow;
   g_csv_compressed_chop = compressed_chop;
   g_csv_no_market_energy = no_market_energy;
   g_csv_relative_energy_ok = relative_energy_ok;
   g_csv_real_energy_ok = real_energy_ok;
   g_csv_direction_flow_long_ok = direction_flow_long_ok;
   g_csv_direction_flow_short_ok = direction_flow_short_ok;
   g_csv_relative_range_ratio = relative_range_ratio;
   g_csv_relative_macd_ratio = relative_macd_ratio;
   g_csv_relative_delta_ratio = relative_delta_ratio;
   g_csv_direction_long_allowed = range_direction_long_allowed;
   g_csv_direction_short_allowed = range_direction_short_allowed;
   g_csv_long_direction_quality = long_direction_quality;
   g_csv_short_direction_quality = short_direction_quality;
   g_csv_range_long_gate_reason = range_long_gate_block_reason;
   g_csv_range_short_gate_reason = range_short_gate_block_reason;

   // Single candidate definition is shared by chart diagnostics and AUTO
   // diagnostics. FINAL signal creation below is the sole downstream authority.
   const bool signal_long_setup_raw =
      process_signals && g_signal_enabled &&
      SignalDirectionAllows(1) &&
      range_score_candidate_long &&
      !strong_sell &&
      (!InpChartSignalRequireM5Bias || trading_tf_bias_long);
   const bool signal_short_setup_raw =
      process_signals && g_signal_enabled &&
      SignalDirectionAllows(-1) &&
      range_score_candidate_short &&
      !strong_buy && !protected_by_111 &&
      (!InpChartSignalRequireM5Bias || trading_tf_bias_short);
   const bool signal_long_setup = signal_long_setup_raw && range_long_final_gate;
   const bool signal_short_setup = signal_short_setup_raw && range_short_final_gate;

   // AUTO sees the same completed-bar score candidate. It does not maintain a
   // separate EARLY/CONFIRMED qualification path.
   const bool range_counter_long_setup_raw =
      g_signal_enabled && SignalDirectionAllows(1) &&
      range_score_candidate_long && !strong_sell &&
      (!InpChartSignalRequireM5Bias || trading_tf_bias_long);
   const bool range_counter_short_setup_raw =
      g_signal_enabled && SignalDirectionAllows(-1) &&
      range_score_candidate_short &&
      !strong_buy && !protected_by_111 &&
      (!InpChartSignalRequireM5Bias || trading_tf_bias_short);
   const bool range_counter_long_setup =
      range_counter_long_setup_raw && range_long_final_gate;
   const bool range_counter_short_setup =
      range_counter_short_setup_raw && range_short_final_gate;

   // RANGE entry-pipeline diagnostics. These rows make it possible to count
   // exactly where M2 opportunities disappear: raw setup, common final gate,
   // confirmed signal, counter increment, third-signal arm, breakout and order.
   // Keep this block after the raw counter setup declarations so MQL5 resolves
   // range_counter_long_setup_raw / range_counter_short_setup_raw correctly.
   // Logging is limited to the AUTO completed-bar pass to avoid duplicate rows.
   if(process_auto && (DataExportIsTester() || InpEnableAutoTradeLog))
   {
      const datetime diagnostic_bar = range_final_bar;
      static datetime last_range_pipeline_bar = 0;
      if(diagnostic_bar > 0 && diagnostic_bar != last_range_pipeline_bar)
      {
         last_range_pipeline_bar = diagnostic_bar;
         if(range_counter_long_setup_raw)
         {
            WriteSignalDecisionLog(1, "RANGE_PIPELINE_RAW",
               g_range_long_signal_count, range_display_long_score,
               "DETECTED", "RAW_LONG_SETUP", false, false, 0, decision_range_location);
            WriteSignalDecisionLog(1, "RANGE_PIPELINE_COMMON_GATE",
               g_range_long_signal_count, range_display_long_score,
               range_long_final_gate ? "PASSED" : "BLOCKED",
               range_long_final_gate ? "COMMON_GATE_PASS" : range_long_gate_block_reason,
               false, false, 0, decision_range_location);
         }
         if(range_counter_short_setup_raw)
         {
            WriteSignalDecisionLog(-1, "RANGE_PIPELINE_RAW",
               g_range_short_signal_count, range_display_short_score,
               "DETECTED", "RAW_SHORT_SETUP", false, false, 0, decision_range_location);
            WriteSignalDecisionLog(-1, "RANGE_PIPELINE_COMMON_GATE",
               g_range_short_signal_count, range_display_short_score,
               range_short_final_gate ? "PASSED" : "BLOCKED",
               range_short_final_gate ? "COMMON_GATE_PASS" : range_short_gate_block_reason,
               false, false, 0, decision_range_location);
         }
      }
   }
   const bool counter_confirmed_long_raw = range_counter_long_setup;
   const bool counter_confirmed_short_raw = range_counter_short_setup;

   // Countertrend micro-rebounds are rejected at the signal source, not only
   // hidden from the chart.  A genuine reversal must recover/break MA22 while
   // MACD and Delta confirm the new direction.  Because these booleans feed
   // SIGNAL, AUTO counters, alerts, CSV and execution, a blocked rebound does
   // not exist anywhere downstream.
   const bool established_range_long_trend =
      trend_strong_direction_long && fast[1] > slow[1] && close1 > slow[1] &&
      slow[1] >= ma70[1] && base_line[1] >= 0.0;
   const bool established_range_short_trend =
      trend_strong_direction_short && fast[1] < slow[1] && close1 < slow[1] &&
      slow[1] <= ma70[1] && base_line[1] <= 0.0;
   const bool confirmed_range_reversal_long =
      (close1 > slow[1] && base_up && raw[1] > 0.0 &&
       (range_timing_long || compression_break_long ||
        (early_turn_long && fast[1] >= slow[1]))) ||
      range_directional_regime_long;
   const bool confirmed_range_reversal_short =
      (close1 < slow[1] && base_down && raw[1] < 0.0 &&
       (range_timing_short || compression_break_short ||
        (early_turn_short && fast[1] <= slow[1]))) ||
      range_directional_regime_short;

   // v4.53 RANGE directional interpretation.
   // Keep the current short-term direction while price/MACD/Delta still support it,
   // but release that direction BEFORE a full opposite trend is confirmed.
   // This separates "old direction is no longer valid" from "new direction is valid".
   const datetime persistence_bar=range_final_bar;
   // v7.58 audit: preserve the exact direction ownership seen by
   // StateEvaluation before SignalEngine can release/establish persistence.
   const int persistence_direction_before=g_range_persistent_direction;
   string persistence_transition_reason="NONE";

   // v7.53: StateEvaluation runs before SignalEngine on the same completed bar.
   // A NEW/FLIPPED WATCH is already MACD+Delta+full-price confirmed in v7.52,
   // so reuse that event as the start of a new RANGE directional episode.
   // Same-direction WATCH progress does not restart the episode.
   const bool assist_watch_snapshot_valid=
      InpAssistStateEnabled &&
      g_assist_state.bar_time==persistence_bar &&
      g_assist_state.timeframe==g_calc_tf;
   const bool assist_watch_long_event=
      assist_watch_snapshot_valid &&
      g_assist_state.watch_pulse &&
      g_assist_state.state==JTA_ASSIST_REVERSAL_WATCH_UP &&
      g_assist_state.previous_state!=JTA_ASSIST_REVERSAL_WATCH_UP;
   const bool assist_watch_short_event=
      assist_watch_snapshot_valid &&
      g_assist_state.watch_pulse &&
      g_assist_state.state==JTA_ASSIST_REVERSAL_WATCH_DOWN &&
      g_assist_state.previous_state!=JTA_ASSIST_REVERSAL_WATCH_DOWN;

   // v8.00: a fresh/flipped reversal WATCH starts a new signal-counting
   // episode immediately. Reset both AUTO 3X counters and the user-facing
   // 3X alert counters once on the WATCH pulse; same-direction WATCH progress
   // does not repeatedly reset the episode.
   if(process_auto && (assist_watch_long_event || assist_watch_short_event))
   {
      // v8.00: reversal WATCH is the single strategy-level cancellation owner
      // for an armed third-signal breakout. Cancel the pending reference before
      // resetting both directional counters so a stale 3X cannot fire later.
      if(g_range_direction_confirm_pending && g_range_direction_confirm_side!=0)
         EntryEngineCancelRangeInitial(
            g_range_direction_confirm_side,
            assist_watch_long_event ? "REVERSAL_WATCH_LONG" : "REVERSAL_WATCH_SHORT",
            true);
      ResetInitialSignalCountersOnly();
      ResetRepeatFinalTracking();
      g_csv_counter_action="RESET_ON_REVERSAL_WATCH";
      g_csv_counter_reset_reason=assist_watch_long_event ?
         "REVERSAL_WATCH_LONG" : "REVERSAL_WATCH_SHORT";
      WriteUnifiedOrderSignalAudit(
         "SIGNAL_COUNTER_RESET","","SIGNAL",
         assist_watch_long_event ? 1 : -1,0,0,"RESET",
         g_csv_counter_reset_reason,false,false,0,g_trade_cycle.position_id);
   }

   // v7.77 WATCH is transition-only. Accepted FINAL tracking belongs to
   // established episodes and is not mutated by an unconfirmed WATCH.

   const bool long_price_weak =
      close1 < fast[1] &&
      (fast[1] <= fast[2] || close1 < slow[1]);
   const bool short_price_weak =
      close1 > fast[1] &&
      (fast[1] >= fast[2] || close1 > slow[1]);

   const bool long_macd_weak =
      base_down;
   const bool short_macd_weak =
      base_up;

   const bool long_delta_weak =
      raw[1] < 0.0 && delta_ema[1] < delta_ema[2];
   const bool short_delta_weak =
      raw[1] > 0.0 && delta_ema[1] > delta_ema[2];

   // v7.76 established-direction ownership:
   // WATCH is transition evidence only. It must not release the current
   // established persistence or pre-claim the opposite direction. A failed
   // WATCH therefore returns naturally to the existing episode. Persistence
   // changes direction only after the opposite FIRST FINAL is Accepted below.
   // v7.78 persistence has one commit owner only:
   // an Accepted FIRST FINAL. Strong-trend context may help qualify a FIRST,
   // but it may not establish persistence independently.

   const bool persistent_block_range_long =
      g_range_persistent_direction<0;
   const bool persistent_block_range_short =
      g_range_persistent_direction>0;

   const bool block_range_long_countertrend =
      established_range_short_trend &&
      !confirmed_range_reversal_long &&
      g_range_persistent_direction!=1;
   const bool block_range_short_countertrend =
      established_range_long_trend &&
      !confirmed_range_reversal_short &&
      g_range_persistent_direction!=-1;

   const bool counter_confirmed_long =
      counter_confirmed_long_raw &&
      !block_range_long_countertrend &&
      !persistent_block_range_long;
   const bool counter_confirmed_short =
      counter_confirmed_short_raw &&
      !block_range_short_countertrend &&
      !persistent_block_range_short;

   // v2.16: one completed-bar FINAL signal owns chart, alert, CSV, counters
   // and AUTO. Only the final score is a numeric qualification. DQ is retained
   // for diagnostics only, so it cannot independently create or veto a signal.
   // v7.02: all RANGE FINAL paths use the same normal score threshold.
   // MACD zero-line side authorization is handled separately by the shared
   // score candidate so chart/AUTO/counters cannot create the opposite side.
   const bool completed_bar_score_long =
      long_score >= range_long_required_score &&
      long_score >= short_score + InpBothDirectionMinimumScoreGap;
   const bool completed_bar_score_short =
      short_score >= range_short_required_score &&
      short_score >= long_score + InpBothDirectionMinimumScoreGap;

   // v7.53: after a WATCH-confirmed directional episode is persistent, the
   // existing price/MA continuation may stand in for the slow Signal/Base
   // zero-side while that Base catches up. Delta remains an independent live
   // participation domain below, so continuation is not price-only.
   const bool range_macd_continue_long=
      (base_line[1] > meaningful_zero_distance && macd_absolute_ok) ||
      range_established_episode_long;
   const bool range_macd_continue_short=
      (base_line[1] < -meaningful_zero_distance && macd_absolute_ok) ||
      range_established_episode_short;
   // v6.63 Repeat-FINAL Delta persistence:
   // one raw opposite M2 bar does not terminate an established episode while
   // the smoothed Delta regime is still same-side and no strong opposite
   // participation is present.  Fresh Price progression is still mandatory
   // upstream through range_score_candidate/range_signal_trigger.
   const bool range_delta_continue_long=
      delta_ema[1]>0.0 && !strong_sell && delta_absolute_ok;
   const bool range_delta_continue_short=
      delta_ema[1]<0.0 && !strong_buy && delta_absolute_ok;

   const bool range_macd_opposite_long=
      base_down && base_line[1]<0.0 &&
      !range_established_episode_long;
   const bool range_macd_opposite_short=
      base_up && base_line[1]>0.0 &&
      !range_established_episode_short;
   const bool range_delta_opposite_long=
      raw[1]<0.0 && delta_ema[1]<0.0;
   const bool range_delta_opposite_short=
      raw[1]>0.0 && delta_ema[1]>0.0;

   // v7.77 Accepted FINAL history directly owns FIRST/REPEAT phase.
   // This is an O(1) lookup of the existing tracker; no new loop/history read.
   const int range_repeat_track_idx=
      RepeatFinalTrackIndex(STRATEGY_RANGE,g_calc_tf);
   datetime range_previous_long_final_bar=
      g_repeat_final_track[range_repeat_track_idx].long_bar;
   datetime range_previous_short_final_bar=
      g_repeat_final_track[range_repeat_track_idx].short_bar;
   const double range_previous_long_final_low=
      g_repeat_final_track[range_repeat_track_idx].long_low;
   const double range_previous_long_final_close=
      g_repeat_final_track[range_repeat_track_idx].long_close;
   const double range_previous_short_final_high=
      g_repeat_final_track[range_repeat_track_idx].short_high;
   const double range_previous_short_final_close=
      g_repeat_final_track[range_repeat_track_idx].short_close;

   const bool range_repeat_long_is_repeat=
      range_continuation_phase_long &&
      range_previous_long_final_bar>0 &&
      range_previous_long_final_bar!=range_final_bar;
   const bool range_repeat_short_is_repeat=
      range_continuation_phase_short &&
      range_previous_short_final_bar>0 &&
      range_previous_short_final_bar!=range_final_bar;

   string range_repeat_long_detail="",range_repeat_short_detail="";
   const int range_repeat_long_domains_required=
      range_established_episode_long ? 1 : 2;
   const int range_repeat_short_domains_required=
      range_established_episode_short ? 1 : 2;
   datetime range_repeat_diag_previous_long_bar=0;
   datetime range_repeat_diag_previous_short_bar=0;
   const bool range_repeat_long_momentum_ok=
      RepeatFinalPersistenceAllows(
         STRATEGY_RANGE,g_calc_tf,1,range_final_bar,close1,
         range_macd_continue_long,range_delta_continue_long,
         range_macd_opposite_long,range_delta_opposite_long,
         range_repeat_long_domains_required,
         range_repeat_long_detail,
         range_repeat_diag_previous_long_bar);
   const bool range_repeat_short_momentum_ok=
      RepeatFinalPersistenceAllows(
         STRATEGY_RANGE,g_calc_tf,-1,range_final_bar,close1,
         range_macd_continue_short,range_delta_continue_short,
         range_macd_opposite_short,range_delta_opposite_short,
         range_repeat_short_domains_required,
         range_repeat_short_detail,
         range_repeat_diag_previous_short_bar);

   // v7.77 phase is not parsed from a diagnostic string.

   // v7.66 StateEvaluation-owned FIRST authority:
   // WATCH must exist first. On a later completed bar, the SAME cached
   // MACD-trajectory + Delta-participation + Price-path evidence may confirm
   // the first FINAL without waiting for the absolute 55-point maturity
   // threshold. The relative score gap remains required so ambiguous two-way
   // conditions cannot qualify. This path remains FIRST-only; v7.69 adds a
   // separate established-direction STATE_REPEAT authority below.
   // No new indicator read, lookback, loop, timer or chart work is introduced.
   const bool range_state_first_snapshot_valid=
      InpAssistStateEnabled &&
      g_assist_state.bar_time==range_final_bar &&
      g_assist_state.timeframe==g_calc_tf;
   // v7.76 WATCH->FIRST is owned by the existing persistent WATCH state.
   // No new pending flag, bar timeout or rescue path is added.
   const bool range_state_first_long_candidate=
      !range_repeat_long_is_repeat &&
      range_state_first_snapshot_valid &&
      g_assist_state.state==JTA_ASSIST_REVERSAL_WATCH_UP &&
      g_assist_state.full_long_watch_candidate &&
      long_score>=short_score+InpBothDirectionMinimumScoreGap;
   const bool range_state_first_short_candidate=
      !range_repeat_short_is_repeat &&
      range_state_first_snapshot_valid &&
      g_assist_state.state==JTA_ASSIST_REVERSAL_WATCH_DOWN &&
      g_assist_state.full_short_watch_candidate &&
      short_score>=long_score+InpBothDirectionMinimumScoreGap;

   // v7.83 REPEAT fresh-price ownership:
   // Keep the original breakout/micro-break proof unchanged. In the soft
   // one-bar continuation path, MA7 slope normally proves freshness. If MA7 is
   // one step late, the existing Accepted-FINAL tracker may supply the same
   // proof only when price itself has advanced beyond the previous Accepted
   // FINAL close. This is not a rescue path: it is one canonical definition of
   // REPEAT price freshness, and it remains REPEAT-only.
   const bool range_repeat_episode_progress_long=
      range_previous_long_final_close>0.0 &&
      close1>range_previous_long_final_close;
   const bool range_repeat_episode_progress_short=
      range_previous_short_final_close>0.0 &&
      close1<range_previous_short_final_close;

   const bool range_repeat_soft_progress_long=
      close1>calc_rates[2].close &&
      close1>=fast[1] &&
      (fast[1]>fast[2] || range_repeat_episode_progress_long);
   const bool range_repeat_soft_progress_short=
      close1<calc_rates[2].close &&
      close1<=fast[1] &&
      (fast[1]<fast[2] || range_repeat_episode_progress_short);

   const bool range_repeat_fresh_progress_long=
      high_break || micro_break_long || range_repeat_soft_progress_long;
   const bool range_repeat_fresh_progress_short=
      low_break || micro_break_short || range_repeat_soft_progress_short;

   const bool range_repeat_long_price_ok=
      !range_repeat_long_is_repeat || range_repeat_fresh_progress_long;
   const bool range_repeat_short_price_ok=
      !range_repeat_short_is_repeat || range_repeat_fresh_progress_short;

   // v7.33: Same-bar Assist interpretation may slow only SAME-DIRECTION
   // Repeat FINALs after an already-established move has begun weakening.
   // It never creates the opposite signal and never blocks FIRST_FINAL.
   // Reuse StateEvaluation's existing 0.65R trend / 0.10R weakening basis;
   // no duplicate calculation or new threshold family is introduced.
   const bool range_repeat_assist_snapshot_valid=
      (InpAssistStateEnabled &&
       g_assist_state.bar_time==range_final_bar &&
       g_assist_state.timeframe==g_calc_tf);

   const bool range_repeat_long_late_block=
      range_repeat_long_is_repeat &&
      range_repeat_assist_snapshot_valid &&
      g_assist_state.net_progress_r>=0.65 &&
      g_assist_state.recent_progress_r<=0.10 &&
      g_assist_state.state==JTA_ASSIST_UP_WEAKENING;

   const bool range_repeat_short_late_block=
      range_repeat_short_is_repeat &&
      range_repeat_assist_snapshot_valid &&
      g_assist_state.net_progress_r<=-0.65 &&
      g_assist_state.recent_progress_r>=-0.10 &&
      g_assist_state.state==JTA_ASSIST_DOWN_WEAKENING;

   // v7.75 established REPEAT has one owner and one job.
   // Persistence already owns the accepted direction; StateEvaluation/opposite
   // WATCH owns reversal.  Requiring MACD/Delta again here re-judges the same
   // direction and creates gaps late in a valid episode.  REPEAT therefore
   // proves continuation only with fresh completed-bar price progression and
   // the existing late-stage protection.
   //
   // range_repeat_*_momentum_ok remains calculated/exported as diagnostic data
   // so CSV can verify whether MACD/Delta agree, but it has no FINAL authority.
   const bool range_repeat_long_ok=
      !range_repeat_long_is_repeat ||
      (range_continuation_phase_long &&
       range_repeat_long_price_ok &&
       !range_repeat_long_late_block);
   const bool range_repeat_short_ok=
      !range_repeat_short_is_repeat ||
      (range_continuation_phase_short &&
       range_repeat_short_price_ok &&
       !range_repeat_short_late_block);

   if(range_repeat_long_is_repeat && !range_repeat_long_price_ok)
      range_repeat_long_detail += " | PRICE_PROGRESS=0";
   if(range_repeat_short_is_repeat && !range_repeat_short_price_ok)
      range_repeat_short_detail += " | PRICE_PROGRESS=0";
   if(range_repeat_long_late_block)
      range_repeat_long_detail += " | LATE_TREND_REPEAT_BLOCK";
   if(range_repeat_short_late_block)
      range_repeat_short_detail += " | LATE_TREND_REPEAT_BLOCK";

   // v7.77 Repeat tracker no longer owns episode reset. Persistence/FIRST owns
   // directional lifecycle. A breach of the last Accepted FINAL structure may
   // still invalidate only active 3X continuity while the episode itself and
   // Repeat anchor remain intact.
   const bool range_long_structure_continuity_break=
      range_repeat_long_is_repeat &&
      range_previous_long_final_low>0.0 &&
      close1<range_previous_long_final_low;
   const bool range_short_structure_continuity_break=
      range_repeat_short_is_repeat &&
      range_previous_short_final_high>0.0 &&
      close1>range_previous_short_final_high;

   if(range_long_structure_continuity_break)
   {
      const int auto_count_before=g_range_long_signal_count;
      const bool reset_auto=process_auto && auto_count_before>0;
      if(reset_auto)
      {
         ResetInitialSignalWindow(1);
         WriteUnifiedOrderSignalAudit(
            "RANGE_3X_STRUCTURE_CONTINUITY_RESET",
            TimeToString(range_final_bar,TIME_DATE|TIME_MINUTES),
            "SIGNAL",1,auto_count_before,g_range_long_signal_count,"RESET",
            StringFormat("AUTO_COUNT_BEFORE=%d | PERSISTENT_LONG_EPISODE_RETAINED | REPEAT_TRACKER_RETAINED",
                         auto_count_before),
            false,false,0,g_trade_cycle.position_id);
      }
   }
   if(range_short_structure_continuity_break)
   {
      const int auto_count_before=g_range_short_signal_count;
      const bool reset_auto=process_auto && auto_count_before>0;
      if(reset_auto)
      {
         ResetInitialSignalWindow(-1);
         WriteUnifiedOrderSignalAudit(
            "RANGE_3X_STRUCTURE_CONTINUITY_RESET",
            TimeToString(range_final_bar,TIME_DATE|TIME_MINUTES),
            "SIGNAL",-1,auto_count_before,g_range_short_signal_count,"RESET",
            StringFormat("AUTO_COUNT_BEFORE=%d | PERSISTENT_SHORT_EPISODE_RETAINED | REPEAT_TRACKER_RETAINED",
                         auto_count_before),
            false,false,0,g_trade_cycle.position_id);
      }
   }

   // v7.66 WATCH/FIRST lifecycle: a newly started reversal WATCH must be
   // visible before the same-direction FINAL. The WATCH-start bar itself can
   // never be an Accepted FINAL; a later completed bar must re-prove the
   // direction. This is a lifecycle rule, not an additional market filter.
   const bool range_watch_lead_block_long=assist_watch_long_event;
   const bool range_watch_lead_block_short=assist_watch_short_event;

   // v7.73 single phase-owned FINAL qualification.
   // There is no parallel Legacy-vs-State REPEAT path:
   // - FIRST after WATCH is owned by the WATCH->FIRST evidence itself.
   // - FIRST outside a WATCH lifecycle keeps the legacy score qualification.
   // - REPEAT is owned by the established episode + continuation evidence.
   // The absolute maturity score is diagnostic for REPEAT.
   const bool range_watch_first_context_long=
      !range_repeat_long_is_repeat &&
      range_state_first_snapshot_valid &&
      g_assist_state.state==JTA_ASSIST_REVERSAL_WATCH_UP;
   const bool range_watch_first_context_short=
      !range_repeat_short_is_repeat &&
      range_state_first_snapshot_valid &&
      g_assist_state.state==JTA_ASSIST_REVERSAL_WATCH_DOWN;

   // v7.77 FIRST is phase-owned. During TRANSITION only the active WATCH
   // direction may confirm FIRST; the old established side cannot fall through
   // to legacy score and publish a contradictory FIRST. Outside TRANSITION the
   // existing non-WATCH score-based initial establishment remains available.
   const bool range_first_long_qualified=
      !range_repeat_long_is_repeat &&
      (range_transition_active
       ? (range_watch_first_context_long && range_state_first_long_candidate)
       : range_score_candidate_long);
   const bool range_first_short_qualified=
      !range_repeat_short_is_repeat &&
      (range_transition_active
       ? (range_watch_first_context_short && range_state_first_short_candidate)
       : range_score_candidate_short);

   // v7.75 score is maturity/diagnostic information after FIRST.
   // Relative score separation must not become a second directional authority
   // inside an episode whose direction is already owned by persistence.
   const bool range_repeat_long_qualified=
      range_repeat_long_is_repeat && range_repeat_long_ok;
   const bool range_repeat_short_qualified=
      range_repeat_short_is_repeat && range_repeat_short_ok;

   const bool range_final_candidate_long=
      range_first_long_qualified || range_repeat_long_qualified;
   const bool range_final_candidate_short=
      range_first_short_qualified || range_repeat_short_qualified;

   // v7.75 phase ownership:
   // countertrend / strong-opposite / MA111 are new-direction (FIRST) safety.
   // Once persistence owns an episode they are transition diagnostics for
   // StateEvaluation/WATCH, not independent REPEAT vetoes.
   // v7.76 phase-owned FIRST safety. A WATCH-confirmed FIRST is the event
   // that replaces old persistence, so the old direction cannot veto that
   // confirmation. Existing dead/chop and strong-opposite/SHORT-MA111 safety
   // remain unchanged.
   const bool range_state_first_long_market_gate=
      range_state_first_long_candidate
      ? (!no_market_energy && !compressed_chop)
      : range_long_final_gate;
   const bool range_state_first_short_market_gate=
      range_state_first_short_candidate
      ? (!no_market_energy && !compressed_chop)
      : range_short_final_gate;

   const bool range_first_long_safety_ok=
      (range_state_first_long_candidate || !block_range_long_countertrend) &&
      !strong_sell;
   const bool range_first_short_safety_ok=
      (range_state_first_short_candidate || !block_range_short_countertrend) &&
      !strong_buy && !protected_by_111;

   // v8.98: FINAL/확정신호 is no longer a user-facing or trading signal.
   // Keep the legacy qualification variables out of the active decision path;
   // M3 Structure Trigger is the only canonical M3 signal event.
   const bool final_confirmed_long=false;
   const bool final_confirmed_short=false;

   const bool final_long_state_first_authority=
      final_confirmed_long && range_watch_first_context_long &&
      range_state_first_long_candidate;
   const bool final_short_state_first_authority=
      final_confirmed_short && range_watch_first_context_short &&
      range_state_first_short_candidate;
   const bool final_long_episode_repeat_authority=
      final_confirmed_long && range_repeat_long_is_repeat;
   const bool final_short_episode_repeat_authority=
      final_confirmed_short && range_repeat_short_is_repeat;

   // v7.60: diagnostic phase classification only. No trading authority.
   const string long_final_phase =
      final_confirmed_long ? (range_repeat_long_is_repeat ? "REPEAT" : "FIRST") : "NONE";
   const string short_final_phase =
      final_confirmed_short ? (range_repeat_short_is_repeat ? "REPEAT" : "FIRST") : "NONE";

   // v7.78 Accepted FIRST is the single persistence commit owner.
   // This applies equally to WATCH-confirmed reversal FIRST and non-WATCH
   // initial FIRST. REPEAT never commits direction and WATCH never pre-commits.
   const bool accepted_long_first=
      final_confirmed_long && !range_repeat_long_is_repeat;
   const bool accepted_short_first=
      final_confirmed_short && !range_repeat_short_is_repeat;

   if(accepted_long_first)
      DataExportWritePreReversalLifecycleAudit(range_final_bar,g_calc_tf,"FIRST_FINAL",1,
         range_state_first_long_candidate ? "STATE_PRE_REVERSAL_CONFIRMED" : "NON_STATE_FIRST_FINAL");
   if(accepted_short_first)
      DataExportWritePreReversalLifecycleAudit(range_final_bar,g_calc_tf,"FIRST_FINAL",-1,
         range_state_first_short_candidate ? "STATE_PRE_REVERSAL_CONFIRMED" : "NON_STATE_FIRST_FINAL");

   if(accepted_long_first && g_range_persistent_direction!=1)
   {
      const int before_commit=g_range_persistent_direction;
      if(before_commit!=0)
      {
         if(g_range_direction_confirm_pending &&
            g_range_direction_confirm_side==before_commit)
            EntryEngineCancelRangeInitial(
               before_commit,"DIRECTION_REPLACED_BY_FIRST_FINAL",true);
         WatchResetActiveTriggerSide(before_commit);
         StructuralResetSide(before_commit);
         WatchDeleteTriggerObjects(before_commit);
      }

      g_range_persistent_direction=1;
      g_range_persistent_since=range_final_bar;
      persistence_transition_reason="FIRST_FINAL_CONFIRMED_LONG";

      WriteUnifiedOrderSignalAudit(
         "RANGE_DIRECTION_PERSISTENCE",
         TimeToString(range_final_bar,TIME_DATE|TIME_MINUTES),
         "SIGNAL",before_commit,1,0,"ESTABLISHED_BY_FIRST",
         range_state_first_long_candidate
            ? "WATCH_CONFIRMED_LONG_FIRST_FINAL"
            : "NON_WATCH_LONG_FIRST_FINAL",
         false,false,0,g_trade_cycle.position_id);
   }
   else if(accepted_short_first && g_range_persistent_direction!=-1)
   {
      const int before_commit=g_range_persistent_direction;
      if(before_commit!=0)
      {
         if(g_range_direction_confirm_pending &&
            g_range_direction_confirm_side==before_commit)
            EntryEngineCancelRangeInitial(
               before_commit,"DIRECTION_REPLACED_BY_FIRST_FINAL",true);
         WatchResetActiveTriggerSide(before_commit);
         StructuralResetSide(before_commit);
         WatchDeleteTriggerObjects(before_commit);
      }

      g_range_persistent_direction=-1;
      g_range_persistent_since=range_final_bar;
      persistence_transition_reason="FIRST_FINAL_CONFIRMED_SHORT";

      WriteUnifiedOrderSignalAudit(
         "RANGE_DIRECTION_PERSISTENCE",
         TimeToString(range_final_bar,TIME_DATE|TIME_MINUTES),
         "SIGNAL",before_commit,-1,0,"ESTABLISHED_BY_FIRST",
         range_state_first_short_candidate
            ? "WATCH_CONFIRMED_SHORT_FIRST_FINAL"
            : "NON_WATCH_SHORT_FIRST_FINAL",
         false,false,0,g_trade_cycle.position_id);
   }

   if(final_confirmed_long)
   {
      RepeatFinalRecordAccepted(
         STRATEGY_RANGE,g_calc_tf,1,range_final_bar,high1,low1,close1);
      FinalTriggerUpdateFromAcceptedFinal(
         STRATEGY_RANGE,1,range_final_bar,long_score);
   }
   if(final_confirmed_short)
   {
      RepeatFinalRecordAccepted(
         STRATEGY_RANGE,g_calc_tf,-1,range_final_bar,high1,low1,close1);
      FinalTriggerUpdateFromAcceptedFinal(
         STRATEGY_RANGE,-1,range_final_bar,short_score);
   }

   // v7.88 selectable Trigger path: only Accepted FINALs completed at/after
   // the Trigger-fire bar count. Pre-Trigger FINALs are never borrowed.
   if(InpAutoEntryPath!=AUTO_ENTRY_NORMAL_ONLY &&
      process_auto && g_auto_trading && ManagedPositionSide()==0 &&
      g_range_trigger_entry_active && g_range_trigger_entry_side!=0 &&
      range_final_bar>0 && range_final_bar>=g_range_trigger_entry_fire_bar)
   {
      int trigger_age_bars=-1;
      if(TriggerEntryAuthorityExpired(STRATEGY_RANGE,trigger_age_bars))
      {
         WriteUnifiedOrderSignalAudit(
            "RANGE_TRIGGER_ENTRY_EXPIRED","","INITIAL",
            g_range_trigger_entry_side,g_range_trigger_entry_final_count,
            g_range_trigger_entry_final_count,"EXPIRED",
            StringFormat("AGE_BARS=%d | MAX=%d",trigger_age_bars,
                         JTATriggerEntryExpiryBarsForStrategy(STRATEGY_RANGE)),
            false,false,0,g_trade_cycle.position_id);
         ResetRangeTriggerFinalEntryState("TRIGGER ENTRY AUTHORITY EXPIRED");
      }

      const int trigger_side=g_range_trigger_entry_side;
      const int trigger_finals_required=
         MathMax(1,MathMin(3,(int)InpRangeTriggerFinalsRequired));
      const bool same_trigger_final=
         trigger_side>0 ? final_confirmed_long : final_confirmed_short;
      const bool opposite_trigger_final=
         trigger_side>0 ? final_confirmed_short : final_confirmed_long;

      if(g_range_trigger_entry_active && same_trigger_final &&
         range_final_bar!=g_range_trigger_entry_last_final_bar)
      {
         g_range_trigger_entry_opposite_count=0;
         g_range_trigger_entry_last_final_bar=range_final_bar;
         if(g_range_trigger_entry_final_count<trigger_finals_required)
            g_range_trigger_entry_final_count++;

         const int trigger_final_score=
            trigger_side>0 ? long_score : short_score;
         const bool trigger_final_ready=
            g_range_trigger_entry_final_count>=trigger_finals_required;
         WriteUnifiedOrderSignalAudit(
            "RANGE_TRIGGER_FINAL_COUNT",
            trigger_side>0?g_current_long_signal_event_id:g_current_short_signal_event_id,
            "INITIAL",trigger_side,
            MathMax(0,g_range_trigger_entry_final_count-1),
            g_range_trigger_entry_final_count,"COUNTED",
            trigger_final_ready ?
               StringFormat("POST_TRIGGER_ACCEPTED_FINAL_%d_OF_%d_READY",
                  trigger_finals_required,trigger_finals_required) :
               StringFormat("POST_TRIGGER_ACCEPTED_FINAL_%d_OF_%d",
                  g_range_trigger_entry_final_count,trigger_finals_required),
            false,false,0,g_trade_cycle.position_id);

         if(trigger_final_ready)
         {
            g_range_trigger_entry_second_final_bar=range_final_bar;
            g_range_trigger_entry_second_high=high1;
            g_range_trigger_entry_second_low=low1;
            g_range_trigger_entry_second_close=close1;
            g_range_trigger_entry_second_score=trigger_final_score;
            g_range_trigger_entry_second_ready=true;
         }
      }
      else if(g_range_trigger_entry_active && opposite_trigger_final)
      {
         g_range_trigger_entry_opposite_count++;
         if(g_range_trigger_entry_opposite_count>=1)
            ResetRangeTriggerFinalEntryState("OPPOSITE_ACCEPTED_FINAL_AFTER_TRIGGER");
      }
   }

   // v7.58: obsolete POSITION FINAL shadow qualification removed.
   // Opposite FINAL no longer owns direct market-exit authority; the unused
   // local POSITION_LONG/POSITION_SHORT event IDs had no downstream consumer.

   // v7.73 phase-owned completed-bar block diagnostics.
   // FIRST and REPEAT report the gate
   // that belongs to their own lifecycle; removed legacy/state bypass names do
   // not remain as hidden diagnostic authorities.
   string final_long_block_reason = "";
   string final_short_block_reason = "";
   if(!final_confirmed_long)
   {
      if(!g_signal_enabled) final_long_block_reason = "SIGNAL_DISABLED";
      else if(!SignalDirectionAllows(1)) final_long_block_reason = "SIGNAL_DIRECTION_BLOCK";
      else if(range_watch_lead_block_long) final_long_block_reason = "WATCH_LEAD_REQUIRED";
      else if(range_repeat_long_is_repeat && !range_established_episode_long)
         final_long_block_reason = "REPEAT_EPISODE_NOT_ESTABLISHED";
      else if(range_repeat_long_is_repeat && !range_repeat_long_price_ok)
         final_long_block_reason = "REPEAT_PRICE_PROGRESS_NOT_MET";
      else if(range_repeat_long_late_block)
         final_long_block_reason = "LATE_TREND_REPEAT_BLOCK";
      else if(!range_repeat_long_is_repeat && range_watch_first_context_long &&
              !range_state_first_long_candidate)
         final_long_block_reason = "WATCH_FIRST_EVIDENCE_NOT_RECONFIRMED";
       else if(range_transition_active && !range_watch_first_context_long)
          final_long_block_reason = "TRANSITION_OTHER_SIDE_INACTIVE";
      else if(!range_repeat_long_is_repeat && !range_watch_first_context_long &&
              long_score < range_long_required_score)
         final_long_block_reason = "FINAL_SCORE_NOT_REACHED";
      else if(!range_repeat_long_is_repeat &&
               long_score < short_score + InpBothDirectionMinimumScoreGap)
          final_long_block_reason = "FINAL_SCORE_GAP_NOT_MET";
      else if(!range_repeat_long_is_repeat && !range_watch_first_context_long &&
              !range_persistent_candidate_long && !range_macd_side_long)
         final_long_block_reason = "MACD_ZERO_OR_WRONG_SIDE";
      else if(!range_repeat_long_is_repeat && !range_watch_first_context_long &&
              !range_persistent_candidate_long && !range_signal_trigger_long)
         final_long_block_reason = "FINAL_TRIGGER_NOT_MET";
       else if(!range_state_first_long_candidate && !range_long_final_gate)
          final_long_block_reason = range_long_gate_block_reason;
       else if(!range_state_first_long_candidate && block_range_long_countertrend)
          final_long_block_reason = "COUNTERTREND_LONG_BLOCK";
       else if(!range_state_first_long_candidate && persistent_block_range_long)
          final_long_block_reason = "PERSISTENT_SHORT_TREND_PULLBACK_BLOCK";
       else if(!range_repeat_long_is_repeat && strong_sell)
          final_long_block_reason = "OPPOSITE_MOMENTUM";
      else if(!range_final_candidate_long) final_long_block_reason = "LONG_PHASE_NOT_QUALIFIED";
      else final_long_block_reason = "DIRECTION_LONG_BLOCKED";
   }
   if(!final_confirmed_short)
   {
      if(!g_signal_enabled) final_short_block_reason = "SIGNAL_DISABLED";
      else if(!SignalDirectionAllows(-1)) final_short_block_reason = "SIGNAL_DIRECTION_BLOCK";
      else if(range_watch_lead_block_short) final_short_block_reason = "WATCH_LEAD_REQUIRED";
      else if(range_repeat_short_is_repeat && !range_established_episode_short)
         final_short_block_reason = "REPEAT_EPISODE_NOT_ESTABLISHED";
      else if(range_repeat_short_is_repeat && !range_repeat_short_price_ok)
         final_short_block_reason = "REPEAT_PRICE_PROGRESS_NOT_MET";
      else if(range_repeat_short_late_block)
         final_short_block_reason = "LATE_TREND_REPEAT_BLOCK";
      else if(!range_repeat_short_is_repeat && range_watch_first_context_short &&
              !range_state_first_short_candidate)
         final_short_block_reason = "WATCH_FIRST_EVIDENCE_NOT_RECONFIRMED";
       else if(range_transition_active && !range_watch_first_context_short)
          final_short_block_reason = "TRANSITION_OTHER_SIDE_INACTIVE";
      else if(!range_repeat_short_is_repeat && !range_watch_first_context_short &&
              short_score < range_short_required_score)
         final_short_block_reason = "FINAL_SCORE_NOT_REACHED";
      else if(!range_repeat_short_is_repeat &&
               short_score < long_score + InpBothDirectionMinimumScoreGap)
          final_short_block_reason = "FINAL_SCORE_GAP_NOT_MET";
      else if(!range_repeat_short_is_repeat && !range_watch_first_context_short &&
              !range_persistent_candidate_short && !range_macd_side_short)
         final_short_block_reason = "MACD_ZERO_OR_WRONG_SIDE";
      else if(!range_repeat_short_is_repeat && !range_watch_first_context_short &&
              !range_persistent_candidate_short && !range_signal_trigger_short)
         final_short_block_reason = "FINAL_TRIGGER_NOT_MET";
       else if(!range_state_first_short_candidate && !range_short_final_gate)
          final_short_block_reason = range_short_gate_block_reason;
       else if(!range_state_first_short_candidate && block_range_short_countertrend)
          final_short_block_reason = "COUNTERTREND_SHORT_BLOCK";
       else if(!range_state_first_short_candidate && persistent_block_range_short)
          final_short_block_reason = "PERSISTENT_LONG_TREND_PULLBACK_BLOCK";
       else if(!range_repeat_short_is_repeat && strong_buy)
          final_short_block_reason = "OPPOSITE_MOMENTUM";
       else if(!range_repeat_short_is_repeat && protected_by_111)
          final_short_block_reason = "MA111_PROTECTION";
      else if(!range_final_candidate_short) final_short_block_reason = "SHORT_PHASE_NOT_QUALIFIED";
      else final_short_block_reason = "DIRECTION_SHORT_BLOCKED";
   }

   // v8.138: M3 visible/order signals have exactly two owners:
   //   StateEvaluation WATCH -> LONG/SHORT WATCH -> INITIAL / opposite EXIT
   //   display_accel_* -> LONG/SHORT ACCEL -> same-direction ADD
   // The former signal_event_* / M3CanonicalTriggerActive stream was removed.
   // Legacy FINAL/3X logic cannot manufacture an additional M3 signal.
   const bool use_m3_canonical_signal = (g_calc_tf==AUTO_TF);
   const bool signal_long_event = false;
   const bool signal_short_event = false;
   const bool signal_long = false;
   const bool signal_short = false;

   // v8.256: display_accel_* remains the canonical internal/AUTO event.
   // Chart/SYS publication shares one five-marker budget per WATCH episode.
   const bool m3_acceleration_long =
      use_m3_canonical_signal &&
      g_m3_segment.chart_primary_accel_allowed &&
      g_m3_segment.display_accel_side==M3_SEG_LONG &&
      g_m3_segment.display_accel_time==range_final_bar;
   const bool m3_acceleration_short =
      use_m3_canonical_signal &&
      g_m3_segment.chart_primary_accel_allowed &&
      g_m3_segment.display_accel_side==M3_SEG_SHORT &&
      g_m3_segment.display_accel_time==range_final_bar;

   // v8.254/v8.256: continuation ACCEL is chart-only and shares the same
   // per-WATCH five-marker visual budget. It intentionally bypasses the
   // AUTO/alert ACCEL fields and therefore has no INITIAL/ADD/EXIT authority.
   const bool m3_chart_cont_acceleration_long =
      use_m3_canonical_signal &&
      g_m3_segment.chart_cont_accel_side==M3_SEG_LONG &&
      g_m3_segment.chart_cont_accel_time==range_final_bar;
   const bool m3_chart_cont_acceleration_short =
      use_m3_canonical_signal &&
      g_m3_segment.chart_cont_accel_side==M3_SEG_SHORT &&
      g_m3_segment.chart_cont_accel_time==range_final_bar;

   const string long_signal_event_id = signal_long ?
      StringFormat("%s|%d|LONG",TimeToString(range_final_bar,TIME_DATE|TIME_MINUTES),PeriodSeconds(g_calc_tf)) : "";
   const string short_signal_event_id = signal_short ?
      StringFormat("%s|%d|SHORT",TimeToString(range_final_bar,TIME_DATE|TIME_MINUTES),PeriodSeconds(g_calc_tf)) : "";

   g_current_long_signal_event_id = long_signal_event_id;
   g_current_short_signal_event_id = short_signal_event_id;

   // v4.82: obsolete Trigger-bar rebreak + second FINAL counter removed.
   // The real Trigger crossing itself is the structural price confirmation;
   // one subsequent same-direction Accepted FINAL is sufficient.

   if(process_signals && !g_auto_trading)
   {
      const datetime pre_auto_bar=range_final_bar;
      if(final_confirmed_long)
         RecordPreAutoFinalSignal(1,long_score,pre_auto_bar,
                                  g_selected_strategy,g_calc_tf);
      if(final_confirmed_short)
         RecordPreAutoFinalSignal(-1,short_score,pre_auto_bar,
                                  g_selected_strategy,g_calc_tf);
   }

   g_decision_snapshot.bar_time=range_final_bar;
   g_decision_snapshot.timeframe_seconds=PeriodSeconds(g_calc_tf);
   g_decision_snapshot.final_long=final_confirmed_long;
   g_decision_snapshot.final_short=final_confirmed_short;
   g_decision_snapshot.long_score=long_score;
   g_decision_snapshot.short_score=short_score;
   g_decision_snapshot.long_score_pre_context=long_score_pre_context;
   g_decision_snapshot.short_score_pre_context=short_score_pre_context;
   g_decision_snapshot.long_context_penalty=long_context_penalty;
   g_decision_snapshot.short_context_penalty=short_context_penalty;
   g_decision_snapshot.long_event_id=long_signal_event_id;
   g_decision_snapshot.short_event_id=short_signal_event_id;
   g_decision_snapshot.shared_signal_auto_pass=(process_signals && process_auto);

   // v1.98: quick giveback re-entry owns an independent 2-final-signal
   // window. It does not borrow the normal initial 3-signal counter.

   // Common AUTO confirmation counter for RANGE and TREND. Count only one
   // closed-bar signal per bar. Three same-direction signals inside the
   // configured window create a direct AUTO-entry permission in either mode.
   // An opposite signal cancels the previous directional count.
   bool current_auto_count_long = false;
   bool current_auto_count_short = false;
   const datetime range_signal_bar = range_final_bar;

   // v7.91 canonical five-completed-bar Accepted FINAL density. This is an
   // interpretation of the existing FINAL stream, not a new signal source.
   if(process_auto && range_signal_bar>0 &&
      range_signal_bar!=g_range_final_density_last_bar)
   {
      for(int density_i=0;density_i<4;density_i++)
         g_range_final_density_window[density_i]=
            g_range_final_density_window[density_i+1];
      int density_side=0;
      if(final_confirmed_long && !final_confirmed_short) density_side=1;
      else if(final_confirmed_short && !final_confirmed_long) density_side=-1;
      else if(final_confirmed_long && final_confirmed_short)
      {
         if(long_score>=short_score+InpBothDirectionMinimumScoreGap) density_side=1;
         else if(short_score>=long_score+InpBothDirectionMinimumScoreGap) density_side=-1;
      }
      g_range_final_density_window[4]=density_side;
      g_range_final_density_last_bar=range_signal_bar;
      g_range_final_density_long_5=0;
      g_range_final_density_short_5=0;
      for(int density_i=0;density_i<5;density_i++)
      {
         if(g_range_final_density_window[density_i]>0) g_range_final_density_long_5++;
         else if(g_range_final_density_window[density_i]<0) g_range_final_density_short_5++;
      }
      // v7.92: Density/MACD order architecture must use the canonical
      // Unscaled Final Wave (buffer 6), not the legacy MACD base/signal line
      // carried in base_line (buffer 7). Keep other legacy consumers unchanged.
      double density_macd_wave[];
      ArrayResize(density_macd_wave,5);
      ArraySetAsSeries(density_macd_wave,true);
      if(MarketDataCopyBuffer(g_calc_macd_handle,JTC_MACD_WAVE_BUFFER,0,5,density_macd_wave)>=5)
      {
         g_range_final_density_macd_wave=density_macd_wave[1];
         g_range_final_density_macd_change_3=density_macd_wave[1]-density_macd_wave[4];
      }
      else
      {
         // Fail closed: never authorize density entry/exit from stale or wrong MACD data.
         g_range_final_density_macd_wave=0.0;
         g_range_final_density_macd_change_3=0.0;
      }
   }

   if(process_auto && range_signal_bar>0)
   {
      const string density_setup_event_id=
         g_range_persistent_direction>0 ? long_signal_event_id :
         (g_range_persistent_direction<0 ? short_signal_event_id : "");
      EntryEngineUpdateRangeDensitySetupState(density_setup_event_id);
   }

// AUTO confirmation counters belong exclusively to AUTO_TF.  Chart SIGNAL
   // timeframes never add to, decay or reset the AUTO entry count.  AUTO OFF
   // and cooldown periods also cannot accumulate stale entry permission.
   // Initial-entry counters must never keep accumulating while a managed
   // position is already open. Holding, opposite-signal exit and add-entry
   // logic consume the same confirmed event through their own state paths.
   if(process_auto && ManagedPositionSide()==0 && g_auto_trading && IsCooldownComplete())
      TradeCycleRestoreInitialWorkingState();
   if(process_auto && ManagedPositionSide()!=0)
      TradeCycleRestorePositionWorkingState();

   if(process_auto && (!g_auto_trading || !IsCooldownComplete() ||
                       ManagedPositionSide() != 0))
      ResetAutoSignalCounters();
   else if(process_auto && g_auto_trading &&
           range_signal_bar > 0 &&
           range_signal_bar != g_range_last_counted_signal_bar)
   {
      // v8.269: the legacy RANGE FINAL/3X counter pipeline is permanently
      // non-authoritative in the single M3 AUTO architecture. RANGE FINAL is
      // hard-disabled, so the old counter/window/audit path could only emit
      // zero-state diagnostics while performing synchronous iBarShift/log work.
      // Keep compatibility fields deterministic for the unchanged 566-column
      // CSV schema, but do not execute the retired counter lifecycle.
      g_range_last_counted_signal_bar = range_signal_bar;
      current_auto_count_long = false;
      current_auto_count_short = false;

      g_range_long_signal_count = 0;
      g_range_short_signal_count = 0;
      g_range_first_long_count_bar = 0;
      g_range_first_short_count_bar = 0;
      g_range_last_long_count_bar = 0;
      g_range_last_short_count_bar = 0;
      for(int legacy_idx=0; legacy_idx<3; ++legacy_idx)
      {
         g_range_long_signal_window[legacy_idx] = 0;
         g_range_short_signal_window[legacy_idx] = 0;
      }

      g_csv_counter_bar_time = range_signal_bar;
      g_csv_counter_raw_long_confirmed = false;
      g_csv_counter_raw_short_confirmed = false;
      g_csv_counter_countable_long = false;
      g_csv_counter_countable_short = false;
      g_csv_counter_long_before = 0;
      g_csv_counter_short_before = 0;
      g_csv_counter_long_after = 0;
      g_csv_counter_short_after = 0;
      g_csv_counter_long_expired = false;
      g_csv_counter_short_expired = false;
      g_csv_counter_duplicate_bar = false;
      g_csv_counter_opposite_decay = MathMax(0, InpOppositeSignalCountDecay);
      g_csv_counter_action = "NO_COUNTABLE_SIGNAL";
      g_csv_counter_reset_reason = "NONE";
      g_csv_counter_long_last_shift = -1;
      g_csv_counter_short_last_shift = -1;
      g_csv_counter_long_first_shift = -1;
      g_csv_counter_short_first_shift = -1;
      g_csv_counter_long_first_time = 0;
      g_csv_counter_short_first_time = 0;

      // Defensive compatibility only. A BREAKOUT_WAIT can no longer be armed
      // by active code after v8.267, but clear an orphan recovered from stale
      // state without touching the current M3 ENTRY/POSITION lifecycle.
      if(!g_range_direction_confirm_pending &&
         g_trade_cycle.state==JTA_CYCLE_BREAKOUT_WAIT &&
         ManagedPositionSide()==0)
      {
         TradeCycleClear("RETIRED_3X_BREAKOUT_WAIT");
      }
   }

   // v7.20 signal research audit. Reuse this bar's already-loaded OHLC/MA/MACD/Delta
   // arrays; no additional market/indicator read is performed here.
   // v7.62: write the same deterministic decision row in Tester and Live so
   // all signal decisions can be verified from CSV without chart screenshots.
   {
      const int audit_lookback=MathMax(4,MathMin(InpAssistStateLookbackBars,count-2));
      const int audit_recent_index=MathMin(3,audit_lookback);
      const bool audit_use_assist_snapshot=
         (InpAssistStateEnabled &&
          g_assist_state.bar_time==range_signal_bar &&
          g_assist_state.timeframe==g_calc_tf);

      double audit_avg_range=0.0;
      double audit_net_progress=0.0;
      double audit_recent_progress=0.0;
      int audit_hh=0,audit_hl=0,audit_lh=0,audit_ll=0,audit_up_close=0,audit_down_close=0;

      if(audit_use_assist_snapshot)
      {
         audit_avg_range=g_assist_state.avg_range;
         audit_net_progress=g_assist_state.net_progress_r;
         audit_recent_progress=g_assist_state.recent_progress_r;
         audit_hh=g_assist_state.higher_high_steps;
         audit_hl=g_assist_state.higher_low_steps;
         audit_lh=g_assist_state.lower_high_steps;
         audit_ll=g_assist_state.lower_low_steps;
         audit_up_close=g_assist_state.up_close_steps;
         audit_down_close=g_assist_state.down_close_steps;
      }
      else
      {
         double audit_range_sum=0.0;
         for(int i=audit_lookback;i>=1;i--)
         {
            audit_range_sum+=MathMax(_Point,calc_rates[i].high-calc_rates[i].low);
            if(i>1)
            {
               const double audit_eps=_Point;
               if(calc_rates[i-1].high>calc_rates[i].high+audit_eps) audit_hh++;
               if(calc_rates[i-1].low >calc_rates[i].low +audit_eps) audit_hl++;
               if(calc_rates[i-1].high<calc_rates[i].high-audit_eps) audit_lh++;
               if(calc_rates[i-1].low <calc_rates[i].low -audit_eps) audit_ll++;
               if(calc_rates[i-1].close>calc_rates[i].close+audit_eps) audit_up_close++;
               if(calc_rates[i-1].close<calc_rates[i].close-audit_eps) audit_down_close++;
            }
         }
         audit_avg_range=MathMax(_Point,audit_range_sum/audit_lookback);
         audit_net_progress=(calc_rates[1].close-calc_rates[audit_lookback].close)/audit_avg_range;
         audit_recent_progress=(calc_rates[1].close-calc_rates[audit_recent_index].close)/audit_avg_range;
      }

      const int audit_macd_dir=macd_color_state[1]>0.5 ? 1 : (macd_color_state[1]<-0.5 ? -1 : 0);
      const int audit_zero_state=macd_zero_state[1]>0.5 ? 1 : (macd_zero_state[1]<-0.5 ? -1 : 0);
      const double audit_assist_macd_base=
         audit_use_assist_snapshot ? g_assist_state.macd_base : base_line[1];
      const double audit_assist_macd_wave=
         audit_use_assist_snapshot ? g_assist_state.macd_wave : 0.0;
      const double audit_assist_macd_raw_price=
         audit_use_assist_snapshot ? g_assist_state.raw_macd : 0.0;
      const double audit_assist_macd_wave_change_1=
         audit_use_assist_snapshot ? g_assist_state.macd_wave_change_1 : 0.0;
      const double audit_assist_macd_wave_change_3=
         audit_use_assist_snapshot ? g_assist_state.macd_wave_change_3 : 0.0;
      const double audit_assist_macd_base_change_1=
         audit_use_assist_snapshot ? g_assist_state.macd_base_change_1 : 0.0;
      const double audit_assist_macd_base_change_3=
         audit_use_assist_snapshot ? g_assist_state.macd_base_change_3 : 0.0;
      const double audit_assist_macd_base_travel_3=
         audit_use_assist_snapshot ? g_assist_state.macd_base_travel_3 : 0.0;
      const double audit_assist_macd_base_efficiency_3=
         audit_use_assist_snapshot ? g_assist_state.macd_base_efficiency_3 : 0.0;
      const double audit_assist_macd_wave_travel_3=
         audit_use_assist_snapshot ? g_assist_state.macd_wave_travel_3 : 0.0;
      const double audit_assist_macd_wave_efficiency_3=
         audit_use_assist_snapshot ? g_assist_state.macd_wave_efficiency_3 : 0.0;
      const int audit_assist_raw_up_steps=
         audit_use_assist_snapshot ? g_assist_state.raw_up_steps : 0;
      const int audit_assist_raw_down_steps=
         audit_use_assist_snapshot ? g_assist_state.raw_down_steps : 0;
      const double audit_assist_raw_delta=
         audit_use_assist_snapshot ? g_assist_state.raw_delta : 0.0;
      const double audit_assist_ema_delta=
         audit_use_assist_snapshot ? g_assist_state.ema_delta : 0.0;
      const double audit_assist_delta_change=
         audit_use_assist_snapshot ? g_assist_state.delta_change : 0.0;
      const int audit_assist_delta_buy_steps=
         audit_use_assist_snapshot ? g_assist_state.delta_buy_steps : 0;
      const int audit_assist_delta_sell_steps=
         audit_use_assist_snapshot ? g_assist_state.delta_sell_steps : 0;
      const bool audit_assist_delta_long_participation=
         audit_use_assist_snapshot ? g_assist_state.delta_long_participation : false;
      const bool audit_assist_delta_short_participation=
         audit_use_assist_snapshot ? g_assist_state.delta_short_participation : false;
      const bool audit_assist_snapshot_aligned=audit_use_assist_snapshot;
      const double audit_assist_macd_transition_progress=
         audit_use_assist_snapshot ? g_assist_state.macd_transition_progress :
         (base_line[1]-base_line[MathMin(3,count-1)]);
      const bool audit_assist_macd_transition_up=
         audit_use_assist_snapshot ? g_assist_state.macd_transition_up :
         (audit_assist_macd_transition_progress>0.0);
      const bool audit_assist_macd_transition_down=
         audit_use_assist_snapshot ? g_assist_state.macd_transition_down :
         (audit_assist_macd_transition_progress<0.0);
      const bool audit_assist_long_transition_progress=
         audit_use_assist_snapshot ? g_assist_state.long_transition_progress :
         (audit_assist_macd_transition_up && audit_recent_progress>0.0 &&
          calc_rates[1].close>calc_rates[2].close);
      const bool audit_assist_short_transition_progress=
         audit_use_assist_snapshot ? g_assist_state.short_transition_progress :
         (audit_assist_macd_transition_down && audit_recent_progress<0.0 &&
          calc_rates[1].close<calc_rates[2].close);
      const bool audit_assist_watch_pulse=
         audit_use_assist_snapshot ? g_assist_state.watch_pulse : false;
      const int audit_assist_direction_anchor=
         audit_use_assist_snapshot ? g_assist_state.direction_anchor : 0;
      const string audit_assist_previous_state=
         audit_use_assist_snapshot ? AssistStateName(g_assist_state.previous_state) : "UNAVAILABLE";
      const string audit_assist_state=audit_use_assist_snapshot ? AssistStateName(g_assist_state.state) : "UNAVAILABLE";
      const string audit_assist_reason=audit_use_assist_snapshot ? g_assist_state.reason : "";

      // v7.58 Signal Decision Dataset: explicitly persist the WATCH decision
      // inputs so offline analysis does not need to infer them from chart images.
      const bool audit_price_up=
         audit_net_progress>=0.65 &&
         audit_up_close>=audit_down_close+1 &&
         audit_hh>=audit_lh &&
         audit_hl>=audit_ll;
      const bool audit_price_down=
         audit_net_progress<=-0.65 &&
         audit_down_close>=audit_up_close+1 &&
         audit_lh>=audit_hh &&
         audit_ll>=audit_hl;
      // v7.89: mirror the canonical StateEvaluation WATCH decision exactly.
      // MACD owns reversal direction, Price confirms it, and Delta is audit-only
      // participation evidence. Never reconstruct a second Delta-gated WATCH here.
      const bool audit_full_long_watch_candidate=
         audit_use_assist_snapshot ? g_assist_state.full_long_watch_candidate :
         (audit_assist_macd_transition_up && audit_price_up);
      const bool audit_full_short_watch_candidate=
         audit_use_assist_snapshot ? g_assist_state.full_short_watch_candidate :
         (audit_assist_macd_transition_down && audit_price_down);
      const bool audit_long_watch_authorized=
         persistence_direction_before<0 &&
         (!audit_use_assist_snapshot || g_assist_state.macd_wave>=0.0);
      const bool audit_short_watch_authorized=
         persistence_direction_before>0 &&
         (!audit_use_assist_snapshot || g_assist_state.macd_wave<=0.0);

      WriteSignalBarAuditV111(
         range_signal_bar,g_calc_tf,
         calc_rates[1].open,calc_rates[1].high,calc_rates[1].low,calc_rates[1].close,
         volume[1],fast[1],slow[1],ma70[1],ma111[1],ma200[1],
         base_line[1],audit_macd_dir,audit_zero_state,
         base_line[1]-base_line[2],base_line[1]-base_line[audit_recent_index],
         raw[1],delta_ema[1],delta_ema[1]-delta_ema[audit_recent_index],
         audit_avg_range,audit_net_progress,audit_recent_progress,
         audit_hh,audit_hl,audit_lh,audit_ll,audit_up_close,audit_down_close,
         range_display_long_score,range_display_short_score,
         final_confirmed_long,final_confirmed_short,
         g_range_long_signal_count,g_range_short_signal_count,
         neutral_flow,compressed_chop,no_market_energy,
         relative_range_ratio,relative_macd_ratio,relative_delta_ratio,
         long_direction_quality,short_direction_quality,
         range_direction_long_allowed,range_direction_short_allowed,
         range_long_gate_block_reason,range_short_gate_block_reason,
         final_long_block_reason,final_short_block_reason,
         audit_assist_macd_base,audit_assist_macd_wave,audit_assist_macd_raw_price,
         audit_assist_macd_wave_change_1,audit_assist_macd_wave_change_3,
         audit_assist_macd_base_change_1,audit_assist_macd_base_change_3,
         audit_assist_macd_base_travel_3,audit_assist_macd_base_efficiency_3,
         audit_assist_macd_wave_travel_3,audit_assist_macd_wave_efficiency_3,
         audit_assist_raw_up_steps,audit_assist_raw_down_steps,
         audit_assist_raw_delta,audit_assist_ema_delta,audit_assist_delta_change,
         audit_assist_delta_buy_steps,audit_assist_delta_sell_steps,
         audit_assist_delta_long_participation,audit_assist_delta_short_participation,
         audit_assist_snapshot_aligned,audit_assist_macd_transition_progress,
         audit_assist_macd_transition_up,audit_assist_macd_transition_down,
         audit_assist_long_transition_progress,audit_assist_short_transition_progress,
         audit_assist_watch_pulse,audit_assist_direction_anchor,
         audit_assist_previous_state,audit_assist_state,audit_assist_reason,
         persistence_direction_before,g_range_persistent_direction,
         persistence_transition_reason,
         range_directional_regime_long,range_directional_regime_short,
         audit_price_up,audit_price_down,
         audit_full_long_watch_candidate,audit_full_short_watch_candidate,
         audit_long_watch_authorized,audit_short_watch_authorized,
         range_persistent_candidate_long,range_persistent_candidate_short,
         assist_persistent_continuation_long,assist_persistent_continuation_short,
         effective_direction_flow_long_ok,effective_direction_flow_short_ok,
         range_long_final_gate,range_short_final_gate,
         range_repeat_long_ok,range_repeat_short_ok,
         range_repeat_long_late_block,range_repeat_short_late_block,
         protected_by_111,strong_buy,strong_sell,
         long_macd_score,short_macd_score,
         long_delta_score,short_delta_score,
         long_ma_score,short_ma_score,
         long_price_score,short_price_score,
         long_pattern_score,short_pattern_score,
         long_tf_score,short_tf_score,
         long_location_score,short_location_score,
         long_score_pre_context,short_score_pre_context,
         long_context_penalty,short_context_penalty,
         (long_score>=range_long_required_score),
         (short_score>=range_short_required_score),
         (long_score>=short_score+InpBothDirectionMinimumScoreGap),
         (short_score>=long_score+InpBothDirectionMinimumScoreGap),
         range_macd_side_long,range_macd_side_short,
         range_signal_trigger_long,range_signal_trigger_short,
         range_repeat_long_is_repeat,range_repeat_short_is_repeat,
         range_repeat_long_momentum_ok,range_repeat_short_momentum_ok,
         range_repeat_long_price_ok,range_repeat_short_price_ok,
         range_repeat_episode_progress_long,range_repeat_episode_progress_short,
         range_previous_long_final_close,range_previous_short_final_close,
         range_repeat_long_detail,range_repeat_short_detail,
         range_previous_long_final_bar,range_previous_short_final_bar,
         long_final_phase,short_final_phase,
         long_signal_event_id,short_signal_event_id);
   }

   const bool chase_long = IsChasingSignal(1, close1, slow[1]);
   const bool chase_short = IsChasingSignal(-1, close1, slow[1]);

   // Countertrend filtering has already been applied to signal_long/signal_short.
   const bool show_range_long_signal = signal_long;
   const bool show_range_short_signal = signal_short;

   if(block_range_long_countertrend || !range_long_final_gate)
      RemoveEntrySignalArrow(1);
   if(block_range_short_countertrend || !range_short_final_gate)
      RemoveEntrySignalArrow(-1);

   if(signal_long || m3_acceleration_long || m3_chart_cont_acceleration_long)
   {
      if(use_m3_canonical_signal)
      {
         // v8.114: only the large-direction acceleration event is published
         // as a manual chart signal. INITIAL/REEXPANSION remain internal
         // canonical events for AUTO/execution consumers.
         if(m3_acceleration_long)
         {
            DrawM3AccelerationMarker(1,range_final_bar,close1);
            g_status = "M3 LONG | ACCELERATION";

            static datetime last_m3_long_accel_alert_bar=0;
            if(range_final_bar>0 && range_final_bar!=last_m3_long_accel_alert_bar)
            {
               const string m3_alert=StringFormat(
                  "!!! [가속신호 LONG] %s | M3",
                  _Symbol);
               NotifySignalUserWithPcSound(m3_alert,"alert2.wav");
               last_m3_long_accel_alert_bar=range_final_bar;
            }
         }
         else if(m3_chart_cont_acceleration_long)
         {
            // v8.254: visual information only. No SYS/MOB alert and no AUTO.
            DrawM3AccelerationMarker(1,range_final_bar,close1);
            g_status = "M3 LONG | ACCELERATION (CONTINUATION CHART ONLY)";
         }
         else
         {
            g_status = "M3 LONG | WATCH";
         }
      }
      else
      {
      const string chart_long_pattern =
         range_timing_long ? "TIMED REVERSAL" :
         (early_turn_long ? "EARLY TURN" :
         (compression_break_long ? "COMPRESSION BREAK" :
         (turn_long ? "TURN" : (signal_reaccel_long ? "RE-ACCEL" : "MOMENTUM"))));
      if(show_range_long_signal)
         DrawEntrySignalArrow(1, range_display_long_score, chart_long_pattern,
                              macd_turning_long ? "TURN UP" : (base_up ? "RISING" : "FLAT"),
                              raw[1] > 0.0 ? "BUY" : "BUY RECOVERY", close1);
      else
         RemoveEntrySignalArrow(1);
      g_status = StringFormat("BUY SIGNAL %s | STATE %s | SCORE %d | DQ %d | DELTA BUY",
         range_timing_long ? "TIMED REVERSAL" :
         (early_turn_long ? "EARLY TURN" :
         (compression_break_long ? "COMPRESSION BREAK" :
         (turn_long ? "TURN" : "RE-ACCEL"))), RangeInternalStateName(), range_display_long_score, long_direction_quality);
      if(g_minimum_alert_score>0 && range_display_long_score >= g_minimum_alert_score &&
         !unsafe_long && !chase_long && IsNewAlertBar(1))
      {
         const string alert_pattern_long =
            range_timing_long ? "TIMED REVERSAL" :
            (early_turn_long ? "EARLY TURN" :
            (compression_break_long ? "COMPRESSION BREAK" :
            (turn_long ? "TURN" : "RE-ACCEL")));
         g_status = JTAFormatFinalSignalAlert(1,range_display_long_score,
            MathMax(1,g_range_long_signal_count),
            3,alert_pattern_long);
         // v4.14: ordinary FINAL SYS/MOB alert removed; chart/status/CSV remain.
      }
      }
   }
   if(signal_short || m3_acceleration_short || m3_chart_cont_acceleration_short)
   {
      if(use_m3_canonical_signal)
      {
         if(m3_acceleration_short)
         {
            DrawM3AccelerationMarker(-1,range_final_bar,close1);
            g_status = "M3 SHORT | ACCELERATION";

            static datetime last_m3_short_accel_alert_bar=0;
            if(range_final_bar>0 && range_final_bar!=last_m3_short_accel_alert_bar)
            {
               const string m3_alert=StringFormat(
                  "!!! [가속신호 SHORT] %s | M3",
                  _Symbol);
               NotifySignalUserWithPcSound(m3_alert,"alert2.wav");
               last_m3_short_accel_alert_bar=range_final_bar;
            }
         }
         else if(m3_chart_cont_acceleration_short)
         {
            // v8.254: visual information only. No SYS/MOB alert and no AUTO.
            DrawM3AccelerationMarker(-1,range_final_bar,close1);
            g_status = "M3 SHORT | ACCELERATION (CONTINUATION CHART ONLY)";
         }
         else
         {
            g_status = "M3 SHORT | WATCH";
         }
      }
      else
      {
      const string chart_short_pattern =
         range_timing_short ? "TIMED REVERSAL" :
         (early_turn_short ? "EARLY TURN" :
         (compression_break_short ? "COMPRESSION BREAK" :
         (turn_short ? "TURN" : (signal_reaccel_short ? "RE-ACCEL" : "MOMENTUM"))));
      if(show_range_short_signal)
         DrawEntrySignalArrow(-1, range_display_short_score, chart_short_pattern,
                              macd_turning_short ? "TURN DOWN" : (base_down ? "FALLING" : "FLAT"),
                              raw[1] < 0.0 ? "SELL" : "SELL RECOVERY", close1);
      else
         RemoveEntrySignalArrow(-1);
      g_status = StringFormat("SELL SIGNAL %s | STATE %s | SCORE %d | DQ %d | DELTA SELL",
         range_timing_short ? "TIMED REVERSAL" :
         (early_turn_short ? "EARLY TURN" :
         (compression_break_short ? "COMPRESSION BREAK" :
         (turn_short ? "TURN" : "RE-ACCEL"))), RangeInternalStateName(), range_display_short_score, short_direction_quality);
      if(g_minimum_alert_score>0 && range_display_short_score >= g_minimum_alert_score &&
         !unsafe_short && !chase_short && IsNewAlertBar(-1))
      {
         const string alert_pattern_short =
            range_timing_short ? "TIMED REVERSAL" :
            (early_turn_short ? "EARLY TURN" :
            (compression_break_short ? "COMPRESSION BREAK" :
            (turn_short ? "TURN" : "RE-ACCEL")));
         g_status = JTAFormatFinalSignalAlert(-1,range_display_short_score,
            MathMax(1,g_range_short_signal_count),
            3,alert_pattern_short);
         // v4.14: ordinary FINAL SYS/MOB alert removed; chart/status/CSV remain.
      }
      }
   }

   // v8.217: DIRECTION must execute on the shared signal-bar path before
   // process_auto=false returns. Order authority remains in M3AutoEngine;
   // this block only publishes the completed-bar DIRECTION event.
   // v8.217: simple DIRECTION = current WATCH ownership + completed-bar
   // price progress + MACD-wave progress.  No legacy FINAL/M5/Delta/MA/score
   // dependency.  ProcessConfirmedMomentumObservation owns the OFF->ON rearm:
   // persistent TRUE emits once; after FALSE, the next TRUE may emit again.
   const bool simple_direction_after_watch =
      g_m3_auto_signal_leg_start_time>0 &&
      range_final_bar>g_m3_auto_signal_leg_start_time;
   const bool prior_long_direction =
      (g_internal_momentum_event_side>0 &&
       g_internal_momentum_event_time>g_m3_auto_signal_leg_start_time &&
       g_last_direction_event_high>0.0);
   const bool prior_short_direction =
      (g_internal_momentum_event_side<0 &&
       g_internal_momentum_event_time>g_m3_auto_signal_leg_start_time &&
       g_last_direction_event_low>0.0);
   const bool long_direction_price_extension =
      (!prior_long_direction || close1>g_last_direction_event_high);
   const bool short_direction_price_extension =
      (!prior_short_direction || close1<g_last_direction_event_low);
   const bool simple_direction_long =
      g_internal_momentum_watch_owner_side>0 &&
      simple_direction_after_watch &&
      close1>calc_rates[2].close &&
      high1>calc_rates[2].high &&
      base_line[1]>base_line[2] &&
      long_direction_price_extension;
   const bool simple_direction_short =
      g_internal_momentum_watch_owner_side<0 &&
      simple_direction_after_watch &&
      close1<calc_rates[2].close &&
      low1<calc_rates[2].low &&
      base_line[1]<base_line[2] &&
      short_direction_price_extension;

   const datetime range_momentum_bar=range_final_bar;
   ProcessConfirmedMomentumObservation(1,simple_direction_long,
      process_signals && g_auto_trading && InpUseShortTermPriceActionEngine,range_display_long_score,range_momentum_bar,close1,high1,low1,g_calc_tf,
      "SIMPLE_DIRECTION",
      StringFormat("MACD_PROGRESS=%d MACD=%.6f->%.6f",(base_line[1]>base_line[2])?1:0,base_line[2],base_line[1]),
      "NO_DELTA_GATE",
      StringFormat("PRICE_PROGRESS=%d CLOSE=%.5f->%.5f HIGH=%.5f->%.5f PRIOR_DIR_HIGH=%.5f CLOSE_EXT=%d",
         (close1>calc_rates[2].close && high1>calc_rates[2].high)?1:0,calc_rates[2].close,close1,calc_rates[2].high,high1,
         prior_long_direction?g_last_direction_event_high:0.0,long_direction_price_extension?1:0),
      StringFormat("WATCH_OWNED=%d AFTER_WATCH=%d",g_internal_momentum_watch_owner_side>0?1:0,simple_direction_after_watch?1:0),
      "WATCH_OWNER + CLOSE/HIGH_PROGRESS + MACD_PROGRESS + OFF_ON_REARM");
   ProcessConfirmedMomentumObservation(-1,simple_direction_short,
      process_signals && g_auto_trading && InpUseShortTermPriceActionEngine,range_display_short_score,range_momentum_bar,close1,high1,low1,g_calc_tf,
      "SIMPLE_DIRECTION",
      StringFormat("MACD_PROGRESS=%d MACD=%.6f->%.6f",(base_line[1]<base_line[2])?1:0,base_line[2],base_line[1]),
      "NO_DELTA_GATE",
      StringFormat("PRICE_PROGRESS=%d CLOSE=%.5f->%.5f LOW=%.5f->%.5f PRIOR_DIR_LOW=%.5f CLOSE_EXT=%d",
         (close1<calc_rates[2].close && low1<calc_rates[2].low)?1:0,calc_rates[2].close,close1,calc_rates[2].low,low1,
         prior_short_direction?g_last_direction_event_low:0.0,short_direction_price_extension?1:0),
      StringFormat("WATCH_OWNED=%d AFTER_WATCH=%d",g_internal_momentum_watch_owner_side<0?1:0,simple_direction_after_watch?1:0),
      "WATCH_OWNER + CLOSE/LOW_PROGRESS + MACD_PROGRESS + OFF_ON_REARM");

   // AUTO entry is intentionally not split by asset. Bitcoin and all other
   // symbols use the same strict gate; asset-specific differences remain in
   // profile thresholds, spread, volatility, SL/TP and cooldown settings.

   // Signal arrows/alerts use only SIG TF. They never inspect, add, close,
   // or open a real position.
   if(!process_auto)
      return;

   // v8.67: M3 AUTO owns the complete order lifecycle. SignalEngine remains
   // chart/alert/diagnostic only and must never hand INITIAL/ADD/HOLD/EXIT
   // authority to legacy Entry/Hold/Exit paths while M3 AUTO is enabled.
   if(M3AutoEngineIsActive() && g_auto_trading)
      return;

   const int position_side = ManagedPositionSide();
   if(position_side != 0)
   {
      // v7.91 SignalEngine owns only signal lifecycle. Opposite WATCH remains
      // predictive EXIT-PREP evidence; strategic close is owned by ExitEngine.
      const bool same_direction_final_signal=
         position_side>0 ? final_confirmed_long : final_confirmed_short;
      const bool opposite_watch_event=
         position_side>0 ? assist_watch_short_event : assist_watch_long_event;
      const string opposite_position_event_id=
         position_side>0 ? short_signal_event_id : long_signal_event_id;

      if(opposite_watch_event)
      {
         // v8.02: opposite WATCH cancels only unconsumed continuation ADD
         // permission. It does not close the position.
         EntryEngineResetRangeStructureAdditional("OPPOSITE_WATCH");
         g_long_exit_pending=position_side>0;
         g_short_exit_pending=position_side<0;
         g_exit_opposite_close_bars=0;
         WriteUnifiedOrderSignalAudit(
            "OPPOSITE_WATCH_EXIT_PREP",opposite_position_event_id,
            "POSITION_MANAGEMENT",-position_side,0,0,"EXIT_PREP",
            "WATCH_PREDICTIVE_ONLY_DENSITY_MACD_OWNS_EXIT",
            false,false,0,g_trade_cycle.position_id);
      }
      if(same_direction_final_signal)
      {
         g_long_exit_pending=false;
         g_short_exit_pending=false;
         g_exit_opposite_close_bars=0;
      }

      // v8.02: RANGE continuation ADD is owned by shared closed-bar price
      // structure, not FINAL density or MACD re-scoring. PositionManager keeps
      // the existing execution-safety ownership after structure confirmation.
      g_range_add_macd_contraction_seen=false;
      g_position_opposite_signal_confirmed=false;

      const string same_direction_event_id=
         position_side>0 ? long_signal_event_id : short_signal_event_id;
      EntryEngineUpdateRangeStructureAdditional(position_side,
                                                 same_direction_event_id);
      return;
   }

   EntryEngineResetRangeStructureAdditional("");
   g_long_exit_pending=false;
   g_short_exit_pending=false;
   g_exit_opposite_close_bars=0;
   g_last_position_state_alert="";
   g_range_add_macd_contraction_seen=false;
   if(!g_auto_trading || !IsCooldownComplete())
      return;

   // v8.02: density remains diagnostic-only. RANGE INITIAL broker authority is
   // 3X + third-FINAL break; RANGE ADD authority is price-structure continuation.

   if(InpShortTermEntryMode == ENTRY_FAST_MOMENTUM)
   {
      g_status = "FAST MOMENTUM: WAITING FOR TICK BREAKOUT";
      return;
   }

   UpdateAutoStartBiasWindow();

   // AUTO START BIAS is a temporary context only. It never affects chart
   // signals, counters, holding or stop management.
   const bool auto_start_long_ok = AutoStartBiasAllows(1,
      turn_long || high_break || compression_break_long || micro_break_long,
      final_confirmed_long, g_range_long_signal_count);
   const bool auto_start_short_ok = AutoStartBiasAllows(-1,
      turn_short || low_break || compression_break_short || micro_break_short,
      final_confirmed_short, g_range_short_signal_count);

   // AUTO DIR is deliberately independent from SIGNAL DIR.
   const bool auto_turn_long =
      !g_long_regime_traded && turn_long;
   const bool auto_turn_short =
      !g_short_regime_traded && turn_short;
   // v2.16: internal RANGE state is diagnostic only. It cannot block AUTO.
   const bool range_auto_state_long = true;
   const bool range_auto_state_short = true;

   // RANGE AUTO is independent from the chart-signal state machine.
   // The original confirmed path remains available, while a synchronized
   // M2 impulse may enter without waiting for an M5 confirmation, an internal
   // ENTRY state, or a fresh MA22 touch. M5 is used only as a veto when it is
   // clearly maintaining the opposite direction.
   const bool m5_not_strongly_opposite_long =
      !InpRequireTradingTFBiasForInitialEntry || !trading_tf_short_maintained;
   const bool m5_not_strongly_opposite_short =
      !InpRequireTradingTFBiasForInitialEntry || !trading_tf_long_maintained;

   // Common LONG/SHORT state-strength engine. The same normalized formula is
   // shared by all RANGE entry paths. No duration/persistence bars are used.
   const JTA_DirectionStrengthResult range_long_strength =
      EvaluateDirectionStrength(
         1, base_line[1], base_line[2], raw[1], raw[2],
         delta_ema[1], delta_ema[2], fast[1], fast[2], slow[1], close1,
         trading_tf_bias_long, range_macd_strong_long, range_delta_strong_long,
         (high_break || micro_break_long || compression_break_long || turn_long),
         (strong_sell || bearish_pattern));
   const JTA_DirectionStrengthResult range_short_strength =
      EvaluateDirectionStrength(
         -1, base_line[1], base_line[2], raw[1], raw[2],
         delta_ema[1], delta_ema[2], fast[1], fast[2], slow[1], close1,
         trading_tf_bias_short, range_macd_strong_short, range_delta_strong_short,
         (low_break || micro_break_short || compression_break_short || turn_short),
         (strong_buy || bullish_pattern));
   const bool range_strength_strong_long =
      JTA_StrengthAtLeast(range_long_strength, JTA_STRENGTH_STRONG);
   const bool range_strength_strong_short =
      JTA_StrengthAtLeast(range_short_strength, JTA_STRENGTH_STRONG);
   const bool range_strength_normal_long =
      JTA_StrengthAtLeast(range_long_strength, JTA_STRENGTH_NORMAL);
   const bool range_strength_normal_short =
      JTA_StrengthAtLeast(range_short_strength, JTA_STRENGTH_NORMAL);
   const bool range_impulse_long =
      AutoDirectionAllows(1) &&
      long_score >= InpEntryScore && !unsafe_long &&
      m5_not_strongly_opposite_long &&
      range_strength_strong_long &&
      base_line[1] > 0.0 && base_up && buy_dominance &&
      close1 > fast[1] && close1 > slow[1] &&
      timing_not_late_long &&
      (range_timing_long || micro_break_long || high_break ||
       compression_break_long);
   const bool range_impulse_short =
      AutoDirectionAllows(-1) &&
      short_score >= InpEntryScore && !unsafe_short &&
      m5_not_strongly_opposite_short &&
      range_strength_strong_short &&
      base_line[1] < 0.0 && base_down && sell_dominance &&
      close1 < fast[1] && close1 < slow[1] &&
      timing_not_late_short &&
      (range_timing_short || micro_break_short || low_break ||
       compression_break_short);



   const bool range_confirmed_long =
      AutoDirectionAllows(1) &&
      long_score >= InpEntryScore &&
      range_strength_normal_long &&
      !unsafe_long && trading_tf_bias_long && range_auto_state_long &&
      (!InpRequireTradingTFMA22Trigger || m2_ma22_long_trigger || continuation_long_entry) &&
      (range_signal_trigger_long || continuation_long_entry);
   const bool range_confirmed_short =
      AutoDirectionAllows(-1) &&
      short_score >= InpEntryScore &&
      range_strength_normal_short &&
      !unsafe_short && trading_tf_bias_short && range_auto_state_short &&
      (!InpRequireTradingTFMA22Trigger || m2_ma22_short_trigger || continuation_short_entry) &&
      (range_signal_trigger_short || continuation_short_entry);
   const int range_signals_required = 3; // v8.00 fixed RANGE INITIAL threshold
   const bool range_three_signal_long =
      current_auto_count_long &&
      g_range_long_signal_count >= range_signals_required && AutoDirectionAllows(1);
   const bool range_three_signal_short =
      current_auto_count_short &&
      g_range_short_signal_count >= range_signals_required && AutoDirectionAllows(-1);

   // The third fresh signal is an execution trigger, not another watch state.
   // Direction Quality is intentionally not a hard veto here because a valid
   // RANGE reversal normally begins against the previous directional reading.
   const bool three_signal_location_long =
      !range_location_valid || score_location <= 0.70;
   const bool three_signal_location_short =
      !range_location_valid || score_location >= 0.30;
   const bool three_signal_momentum_long =
      (macd_turning_long || base_up) &&
      (delta_recovery_long || raw[1] >= 0.0);
   const bool three_signal_momentum_short =
      (macd_turning_short || base_down) &&
      (delta_recovery_short || raw[1] <= 0.0);

   // RANGE final-entry approval. A three-signal count is necessary but no
   // longer sufficient: the current closed-bar MACD, Delta and MA condition
   // must also be acceptable. Recent-high/low proximity is intentionally not
   // used because valid reversals and breakouts can begin near those levels.
   const int final_weakness_region =
      MathMax(3,MathMin(8,MathMax(InpRangeFinalWeaknessBars,
                                 InpStrongPersistenceLookbackBars)));
   double final_macd_long_peak=0.0,final_macd_short_peak=0.0;
   double final_delta_long_peak=0.0,final_delta_short_peak=0.0;
   double final_recent_long_delta=0.0,final_older_long_delta=0.0;
   double final_recent_short_delta=0.0,final_older_short_delta=0.0;
   int final_recent_n=0,final_older_n=0;
   const int final_split=MathMax(2,final_weakness_region/2);
   for(int final_i=1;final_i<=final_weakness_region;final_i++)
   {
      if(base_line[final_i]>0.0)
         final_macd_long_peak=MathMax(final_macd_long_peak,MathAbs(base_line[final_i]));
      if(base_line[final_i]<0.0)
         final_macd_short_peak=MathMax(final_macd_short_peak,MathAbs(base_line[final_i]));
      if(raw[final_i]>0.0)
         final_delta_long_peak=MathMax(final_delta_long_peak,MathAbs(raw[final_i]));
      if(raw[final_i]<0.0)
         final_delta_short_peak=MathMax(final_delta_short_peak,MathAbs(raw[final_i]));

      if(final_i<=final_split)
      {
         final_recent_long_delta+=MathMax(0.0,raw[final_i]);
         final_recent_short_delta+=MathMax(0.0,-raw[final_i]);
         final_recent_n++;
      }
      else
      {
         final_older_long_delta+=MathMax(0.0,raw[final_i]);
         final_older_short_delta+=MathMax(0.0,-raw[final_i]);
         final_older_n++;
      }
   }
   const double final_recent_long_avg=final_recent_long_delta/MathMax(1,final_recent_n);
   const double final_recent_short_avg=final_recent_short_delta/MathMax(1,final_recent_n);
   const double final_older_long_avg=final_older_long_delta/MathMax(1,final_older_n);
   const double final_older_short_avg=final_older_short_delta/MathMax(1,final_older_n);

   const bool final_macd_weak_long=
      base_line[1]>0.0 && final_macd_long_peak>0.0 &&
      MathAbs(base_line[1])<final_macd_long_peak*0.60;
   const bool final_macd_weak_short=
      base_line[1]<0.0 && final_macd_short_peak>0.0 &&
      MathAbs(base_line[1])<final_macd_short_peak*0.60;
   const bool final_delta_weak_long=
      raw[1]>0.0 && final_delta_long_peak>0.0 &&
      MathAbs(raw[1])<final_delta_long_peak*0.60 &&
      final_older_long_avg>0.0 &&
      final_recent_long_avg<final_older_long_avg*0.70;
   const bool final_delta_weak_short=
      raw[1]<0.0 && final_delta_short_peak>0.0 &&
      MathAbs(raw[1])<final_delta_short_peak*0.60 &&
      final_older_short_avg>0.0 &&
      final_recent_short_avg<final_older_short_avg*0.70;
   const bool final_macd_long_ok =
      !InpUseRangeFinalEntryFilter ||
      (range_macd_strong_long && !final_macd_weak_long);
   const bool final_macd_short_ok =
      !InpUseRangeFinalEntryFilter ||
      (range_macd_strong_short && !final_macd_weak_short);
   const bool final_delta_long_ok =
      !InpUseRangeFinalEntryFilter ||
      (range_delta_strong_long && !final_delta_weak_long);
   const bool final_delta_short_ok =
      !InpUseRangeFinalEntryFilter ||
      (range_delta_strong_short && !final_delta_weak_short);

   // Do not demand a perfect slope. Only reject a clearly adverse MA state so
   // a legitimate lower-edge reversal is not filtered out prematurely.
   const bool final_ma_long_ok =
      !InpUseRangeFinalEntryFilter || fast[1] >= fast[2] || close1 >= fast[1];
   const bool final_ma_short_ok =
      !InpUseRangeFinalEntryFilter || fast[1] <= fast[2] || close1 <= fast[1];

   // RANGE-only late-move filter. It does not alter TREND entries or holding.
   // A trade is rejected only when at least N independent late-entry warnings
   // agree: same-direction MACD is fading, same-direction Delta is fading,
   // and price is already near the opposite range edge (BUY high / SELL low).
   const int late_move_region=MathMax(4,MathMin(10,InpRangeLateMoveBars+2));
   double late_macd_long_peak=0.0,late_macd_short_peak=0.0;
   double late_delta_long_peak=0.0,late_delta_short_peak=0.0;
   double late_recent_long_delta=0.0,late_older_long_delta=0.0;
   double late_recent_short_delta=0.0,late_older_short_delta=0.0;
   int late_recent_n=0,late_older_n=0;
   const int late_split=MathMax(2,late_move_region/2);
   for(int late_i=1;late_i<=late_move_region;late_i++)
   {
      if(base_line[late_i]>0.0)
         late_macd_long_peak=MathMax(late_macd_long_peak,MathAbs(base_line[late_i]));
      if(base_line[late_i]<0.0)
         late_macd_short_peak=MathMax(late_macd_short_peak,MathAbs(base_line[late_i]));
      if(raw[late_i]>0.0)
         late_delta_long_peak=MathMax(late_delta_long_peak,MathAbs(raw[late_i]));
      if(raw[late_i]<0.0)
         late_delta_short_peak=MathMax(late_delta_short_peak,MathAbs(raw[late_i]));

      if(late_i<=late_split)
      {
         late_recent_long_delta+=MathMax(0.0,raw[late_i]);
         late_recent_short_delta+=MathMax(0.0,-raw[late_i]);
         late_recent_n++;
      }
      else
      {
         late_older_long_delta+=MathMax(0.0,raw[late_i]);
         late_older_short_delta+=MathMax(0.0,-raw[late_i]);
         late_older_n++;
      }
   }
   const double late_recent_long_avg=late_recent_long_delta/MathMax(1,late_recent_n);
   const double late_recent_short_avg=late_recent_short_delta/MathMax(1,late_recent_n);
   const double late_older_long_avg=late_older_long_delta/MathMax(1,late_older_n);
   const double late_older_short_avg=late_older_short_delta/MathMax(1,late_older_n);

   const bool late_macd_fade_long=
      base_line[1]>0.0 && late_macd_long_peak>0.0 &&
      MathAbs(base_line[1])<late_macd_long_peak*0.60;
   const bool late_macd_fade_short=
      base_line[1]<0.0 && late_macd_short_peak>0.0 &&
      MathAbs(base_line[1])<late_macd_short_peak*0.60;
   const bool late_delta_fade_long=
      raw[1]>0.0 && late_delta_long_peak>0.0 &&
      MathAbs(raw[1])<late_delta_long_peak*0.60 &&
      late_older_long_avg>0.0 &&
      late_recent_long_avg<late_older_long_avg*0.70;
   const bool late_delta_fade_short=
      raw[1]<0.0 && late_delta_short_peak>0.0 &&
      MathAbs(raw[1])<late_delta_short_peak*0.60 &&
      late_older_short_avg>0.0 &&
      late_recent_short_avg<late_older_short_avg*0.70;
   const double late_edge_zone = MathMax(0.05, MathMin(0.45, InpRangeLateMoveEdgeZone));
   const bool late_bad_location_long =
      range_location_valid && score_location >= (1.0 - late_edge_zone);
   const bool late_bad_location_short =
      range_location_valid && score_location <= late_edge_zone;
   const int late_move_score_long =
      (late_macd_fade_long ? 1 : 0) +
      (late_delta_fade_long ? 1 : 0) +
      (late_bad_location_long ? 1 : 0);
   const int late_move_score_short =
      (late_macd_fade_short ? 1 : 0) +
      (late_delta_fade_short ? 1 : 0) +
      (late_bad_location_short ? 1 : 0);
   const int late_move_block_score = MathMax(1, MathMin(3, InpRangeLateMoveBlockScore));
   const bool range_late_move_long =
      InpUseRangeLateMoveFilter && late_move_score_long >= late_move_block_score;
   const bool range_late_move_short =
      InpUseRangeLateMoveFilter && late_move_score_short >= late_move_block_score;

   const bool range_final_long_ok =
      final_macd_long_ok && final_delta_long_ok && final_ma_long_ok &&
      !range_late_move_long;
   const bool range_final_short_ok =
      final_macd_short_ok && final_delta_short_ok && final_ma_short_ok &&
      !range_late_move_short;

   // v2.24: POST_THIRD_SAFETY is intentionally retained for INITIAL entry.
   // The three FINAL signals establish persistence, but the later breakout bar
   // must still be safe/tradeable at execution time. This is not an EntryScore
   // re-check; it is a final MACD/Delta/range/countertrend safety gate.
   // v2.29 common fix:
   // Re-check the current RANGE market-safety gate on the actual breakout
   // execution bar. A failed re-gate does NOT cancel the armed POST_THIRD
   // setup; EntryEngine returns WAIT/BLOCKED and the existing opposite-2 /
   // structural invalidation rules remain the only cancellation authorities.
   //
   // v2.78: FLOW_MISMATCH is diagnostic-only after three FINAL signals plus
   // real later-bar price confirmation. Each FINAL signal already required the
   // directional MACD+Delta flow gate, so requiring direction_flow_*_ok again
   // here duplicated qualification and could block a valid confirmed breakout.
   // Dead-market, compressed/neutral market and direction-allowed protections
   // remain hard POST_THIRD safety gates. The flow values/reasons above are
   // still exported to CSV for analysis.
   // v4.15: three accepted FINALs already performed repeated signal-quality
   // validation. After the third signal, Entry owns only price confirmation;
   // execution safety (cost/SL/live-Delta emergency gate) remains downstream.
   const bool post_third_common_regate_long = true;
   const bool post_third_common_regate_short = true;
   // v4.55: after 3X, re-check only the current completed-M2 direction flow.
   const bool post_third_safety_long = direction_flow_long_ok;
   const bool post_third_safety_short = direction_flow_short_ok;
   string post_third_safety_reason_long =
      post_third_safety_long ? "" : "CURRENT_DIRECTION_FLOW_LONG_WAIT";
   string post_third_safety_reason_short =
      post_third_safety_short ? "" : "CURRENT_DIRECTION_FLOW_SHORT_WAIT";

   // v2.29: automatic REENTRY strategy removed.
   // Any future trade after exit must qualify through the normal INITIAL path.
   const bool giveback_reentry_long = false;
   const bool giveback_reentry_short = false;
   // The third signal now arms a pending initial-entry state. An order is not
   // allowed on the same completed bar. The next completed bar(s) must prove
   // that price is actually progressing in the third-signal direction.
   // v7.61 performance: when this decision already runs on AUTO_TF, reuse the
   // loaded calc_rates snapshot. If chart-signal TF differs, preserve the
   // original AUTO_TF terminal lookup exactly once.
   const bool calc_tf_is_auto_tf=(g_calc_tf==AUTO_TF);
   const datetime auto_closed_bar_time =
      calc_tf_is_auto_tf ? range_final_bar : iTime(_Symbol,AUTO_TF,1);
   const double auto_closed_bar_high =
      calc_tf_is_auto_tf ? high1 : iHigh(_Symbol,AUTO_TF,1);
   const double auto_closed_bar_low =
      calc_tf_is_auto_tf ? low1 : iLow(_Symbol,AUTO_TF,1);
   const bool fresh_range_signal_set =
      (g_last_stop_exit_time <= 0 ||
       JTF_FreshClosedBarAfter(auto_closed_bar_time, g_last_stop_exit_time));

   // v2.01: reaching three direction confirmations arms breakout waiting
   // immediately.  Strength/unsafe/M5/order quality is intentionally deferred
   // to the later breakout bar so the 3-count measures persistence only.
   // v4.68 RANGE simplified 3X path: an active accepted-FINAL episode reaches
   // exactly three same-direction signals, then the third FINAL bar extreme is
   // the sole price trigger. No post-third MACD/Delta/MA/M5/flow re-gate.
   const bool range_three_signal_direct_long =
      current_auto_count_long && g_range_long_signal_count>=range_signals_required && AutoDirectionAllows(1);
   const bool range_three_signal_direct_short =
      current_auto_count_short && g_range_short_signal_count>=range_signals_required && AutoDirectionAllows(-1);

   const datetime current_closed_bar_time = auto_closed_bar_time;
   const double current_closed_high = auto_closed_bar_high;
   const double current_closed_low = auto_closed_bar_low;
   // Pending RANGE 3X cancellation is episode/structure driven:
   // 1) two consecutive fully confirmed opposite signals,
   // 2) complete structural invalidation beyond the third-signal bar, or
   // 3) explicit directional-persistence release to NONE.
   // Later same-direction FINALs and temporary indicator changes do not reset
   // the already armed 3X setup.
   // v4.68: once the 3X accepted-FINAL episode is armed, wait only for the
   // third FINAL directional extreme break. No opposite/structure/flow strategy
   // cancellation is applied to this already-qualified entry condition.
   bool direction_confirm_cancelled_this_bar = false;

   // v8.00: the canonical RANGE INITIAL lifecycle is now visible here as
   // ARMED/BREAKOUT_WAIT until EntryEngine observes the third-FINAL High/Low
   // break on live Bid. These booleans remain decision/audit mirrors only.
   const bool range_direction_confirmed_long =
      g_range_direction_confirm_pending && g_range_direction_confirm_side>0 &&
      g_range_break_confirmed;
   const bool range_direction_confirmed_short =
      g_range_direction_confirm_pending && g_range_direction_confirm_side<0 &&
      g_range_break_confirmed;
   const bool price_break_confirmed_long = range_direction_confirmed_long;
   const bool price_break_confirmed_short = range_direction_confirmed_short;
   string post_third_block_long = g_range_direction_confirm_pending &&
      g_range_direction_confirm_side>0 ? "WAIT_THIRD_FINAL_HIGH_BREAK" : "";
   string post_third_block_short = g_range_direction_confirm_pending &&
      g_range_direction_confirm_side<0 ? "WAIT_THIRD_FINAL_LOW_BREAK" : "";

   // v7.86 legacy RANGE impulse/confirmed/3X booleans below are diagnostic only.
   // The sole RANGE INITIAL broker authority is FIRST->first REPEAT above.
   const bool approved_initial_long = false;
   const bool approved_initial_short = false;
   // No secondary RANGE INITIAL path is allowed in v7.86.
   const bool auto_long = false;
   const bool auto_short = false;

   // Full decision snapshot: write one row for each active direction before
   // order routing. This captures confirmed signal state, signal count, score,
   // AUTO-start bias, internal state and the first concrete gate that prevents
   // entry, even when no broker order is requested.
   if(g_range_long_signal_count > 0 || final_confirmed_long || range_state_long_setup ||
      signal_long_setup_raw || range_counter_long_setup_raw)
   {
      string reason_long = "";
      if(range_direction_confirmed_long) reason_long = "";
      else if(price_break_confirmed_long && post_third_block_long != "") reason_long = post_third_block_long;
      else if(g_range_direction_confirm_pending && g_range_direction_confirm_side > 0)
         reason_long = g_range_break_confirmed ? "CONTINUATION_REBREAK_WAIT" : "BREAKOUT_WAIT";
      else if(!range_long_final_gate) reason_long = range_long_gate_block_reason;
      else if(!auto_start_long_ok) reason_long = "PRE_DIRECTION_BIAS_BLOCK";
      else if(!AutoDirectionAllows(1)) reason_long = "AUTO_DIRECTION_BLOCK";
      else if(!range_three_signal_direct_long && !range_impulse_long &&
              !range_confirmed_long && !giveback_reentry_long)
         reason_long = "NO_APPROVED_ENTRY_PATH";
      else if(auto_short && long_score < short_score + InpBothDirectionMinimumScoreGap) reason_long = "OPPOSITE_SCORE_GAP_BLOCK";
      WriteSignalDecisionLog(1, "FULL_DECISION_SNAPSHOT",
         g_range_long_signal_count, long_score,
         auto_long ? "AUTO_PATH_CONFIRMED" : "WAITING_OR_BLOCKED",
         reason_long, false, false, 0, decision_range_location);
   }
   if(g_range_short_signal_count > 0 || final_confirmed_short || range_state_short_setup ||
      signal_short_setup_raw || range_counter_short_setup_raw)
   {
      string reason_short = "";
      if(range_direction_confirmed_short) reason_short = "";
      else if(price_break_confirmed_short && post_third_block_short != "") reason_short = post_third_block_short;
      else if(g_range_direction_confirm_pending && g_range_direction_confirm_side < 0)
         reason_short = g_range_break_confirmed ? "CONTINUATION_REBREAK_WAIT" : "BREAKOUT_WAIT";
      else if(!range_short_final_gate) reason_short = range_short_gate_block_reason;
      else if(!auto_start_short_ok) reason_short = "PRE_DIRECTION_BIAS_BLOCK";
      else if(!AutoDirectionAllows(-1)) reason_short = "AUTO_DIRECTION_BLOCK";
      else if(!range_three_signal_direct_short && !range_impulse_short &&
              !range_confirmed_short && !giveback_reentry_short)
         reason_short = "NO_APPROVED_ENTRY_PATH";
      else if(auto_long && short_score < long_score + InpBothDirectionMinimumScoreGap) reason_short = "OPPOSITE_SCORE_GAP_BLOCK";
      WriteSignalDecisionLog(-1, "FULL_DECISION_SNAPSHOT",
         g_range_short_signal_count, short_score,
         auto_short ? "AUTO_PATH_CONFIRMED" : "WAITING_OR_BLOCKED",
         reason_short, false, false, 0, decision_range_location);
   }

   if(range_three_signal_long && !range_three_signal_direct_long)
   {
      string block_reason = "RANGE BUY BLOCK:";
      if(oversized) block_reason += " OVERSIZED";
      if(strong_sell || bearish_pattern) block_reason += " OPPOSITE MOMENTUM";
      if(!range_strength_normal_long)
         block_reason += " STRENGTH " + JTA_DirectionStrengthName(range_long_strength.level) +
                         "(" + IntegerToString(range_long_strength.score) + ")";
      g_status = block_reason;
      WriteSignalDecisionLog(1, "THREE_SIGNAL_GATE",
                             g_range_long_signal_count, long_score,
                             "BLOCKED", block_reason,
                             false, false, 0, decision_range_location);
      WriteUnifiedOrderSignalAudit("THREE_SIGNAL_GATE",long_signal_event_id,
         "INITIAL",1,g_range_long_signal_count,g_range_long_signal_count,
         "BLOCKED",block_reason,false,false,0,g_trade_cycle.position_id);
   }
   else if(range_three_signal_short && !range_three_signal_direct_short)
   {
      string block_reason = "RANGE SELL BLOCK:";
      if(oversized) block_reason += " OVERSIZED";
      if(strong_buy || bullish_pattern) block_reason += " OPPOSITE MOMENTUM";
      if(protected_by_111) block_reason += " MA111 PROTECT";
      if(!range_strength_normal_short)
         block_reason += " STRENGTH " + JTA_DirectionStrengthName(range_short_strength.level) +
                         "(" + IntegerToString(range_short_strength.score) + ")";
      g_status = block_reason;
      WriteSignalDecisionLog(-1, "THREE_SIGNAL_GATE",
                             g_range_short_signal_count, short_score,
                             "BLOCKED", block_reason,
                             false, false, 0, decision_range_location);
      WriteUnifiedOrderSignalAudit("THREE_SIGNAL_GATE",short_signal_event_id,
         "INITIAL",-1,g_range_short_signal_count,g_range_short_signal_count,
         "BLOCKED",block_reason,false,false,0,g_trade_cycle.position_id);
   }

   // v7.86: no secondary completed-bar RANGE INITIAL broker path remains.
   // All RANGE INITIAL submissions are owned above by FIRST->first REPEAT.
   if(!signal_long && !signal_short)
      g_status = StringFormat("WAITING FOR SIGNAL | RANGE COUNT L%d/S%d | LONG DQ %d | SHORT DQ %d",
         g_range_long_signal_count, g_range_short_signal_count,
         long_direction_quality, short_direction_quality);
}

//+------------------------------------------------------------------+
// Lightweight chart-pattern layer. It does not replace direction or entry
// scoring. It only assists position holding, add-entry and profit protection.


//+------------------------------------------------------------------+


//+------------------------------------------------------------------+


bool ChangeSignalTimeframe(const ENUM_TIMEFRAMES timeframe)
{
   // v7.16: SIGNAL TF can no longer diverge from the unified trading timeframe.
   // The chart TRADE TF menu is the only runtime timeframe authority.
   return StateEvaluationSetTimeframe(timeframe);
}

void ProcessTrendClosedBar(const bool process_signals,
                      const bool process_auto)
{
   double base_line[], macd_color_state[], macd_zero_state_unused[], raw[], delta_ema[];
   if(!CopySignalData(base_line, macd_color_state, macd_zero_state_unused, raw, delta_ema))
      return;

   double fast[], slow[], ma70[], ma111[], ma200[], volume[];
   const int count = SignalRequiredHistoryCount();
   ArrayResize(fast, count);
   ArrayResize(slow, count);
   ArrayResize(ma70, count);
   ArrayResize(ma111, count);
   ArrayResize(ma200, count);
   ArrayResize(volume, count);
   ArraySetAsSeries(fast, true);
   ArraySetAsSeries(slow, true);
   ArraySetAsSeries(ma70, true);
   ArraySetAsSeries(ma111, true);
   ArraySetAsSeries(ma200, true);
   ArraySetAsSeries(volume, true);
   if(MarketDataCopyBuffer(g_calc_fast_ma_handle, 0, 0, count, fast) < count ||
      MarketDataCopyBuffer(g_calc_slow_ma_handle, 0, 0, count, slow) < count ||
      MarketDataCopyBuffer(g_calc_ma70_handle, 0, 0, count, ma70) < count ||
      MarketDataCopyBuffer(g_calc_ma111_handle, 0, 0, count, ma111) < count ||
      MarketDataCopyBuffer(g_calc_ma200_handle, 0, 0, count, ma200) < count ||
      MarketDataCopyBuffer(g_calc_delta_handle, 4, 0, count, volume) < count)
   {
      g_status = "WAITING FOR STRUCTURE DATA";
      return;
   }

   const double average_delta = AverageAbsoluteDelta(raw);
   if(average_delta <= 0.0)
      return;

   bool trend_macd_strong_long = false, trend_macd_strong_short = false;
   bool trend_delta_strong_long = false, trend_delta_strong_short = false;
   if(!CalculateCommonStrengthPersistence(
         base_line, macd_color_state, raw, delta_ema,
         InpTrendStrengthLookbackBars, InpTrendMACDStrengthFactor,
         InpTrendDeltaStrengthFactor, trend_macd_strong_long,
         trend_macd_strong_short, trend_delta_strong_long,
         trend_delta_strong_short))
      return;
   const bool trend_strong_direction_long =
      trend_macd_strong_long && trend_delta_strong_long;
   const bool trend_strong_direction_short =
      trend_macd_strong_short && trend_delta_strong_short;

   const double close1 = iClose(_Symbol, g_calc_tf, 1);
   const double high1 = iHigh(_Symbol, g_calc_tf, 1);
   const double low1 = iLow(_Symbol, g_calc_tf, 1);
   const bool base_up = base_line[1] > base_line[2];
   const bool base_down = base_line[1] < base_line[2];
   if(process_auto)
   {
      if(base_line[1] <= 0.0) g_long_regime_traded = false;
      if(base_line[1] >= 0.0) g_short_regime_traded = false;
   }
   int buy_dominance_bars = 0, sell_dominance_bars = 0;
   double dominance_sum = 0.0, average_volume = 0.0;
   for(int i = 1; i <= InpDominanceLookback; i++)
   {
      if(raw[i] >= InpDominanceWeakLevel) buy_dominance_bars++;
      if(raw[i] <= -InpDominanceWeakLevel) sell_dominance_bars++;
      dominance_sum += raw[i];
      average_volume += volume[i];
   }
   average_volume /= (double)InpDominanceLookback;
   const bool buy_dominance =
      buy_dominance_bars >= InpDominanceMinBars && dominance_sum > 0.0;
   const bool sell_dominance =
      sell_dominance_bars >= InpDominanceMinBars && dominance_sum < 0.0;

   // A MACD touch near zero is normal during consolidation.  Measure a
   // meaningful zero-line failure against the recent baseline amplitude so
   // the same rule scales across BTC, indices, metals and oil.
   double macd_reference = 0.0;
   const int macd_reference_bars =
      MathMax(2, MathMin(InpMACDReferenceBars, ArraySize(base_line) - 3));
   for(int i = 2; i < 2 + macd_reference_bars; i++)
      macd_reference += MathAbs(base_line[i]);
   macd_reference /= (double)macd_reference_bars;
   const double meaningful_zero_distance =
      MathMax(_Point, macd_reference * InpMACDZeroBreakFactor);

   const int exit_confirm_bars =
      MathMax(1, MathMin(InpExitConfirmBars,
                        MathMin(ArraySize(base_line),
                                ArraySize(slow)) - 2));
   bool long_macd_failure = true, short_macd_failure = true;
   bool long_ma22_failure = true, short_ma22_failure = true;
   bool opposite_sell_confirmed = true, opposite_buy_confirmed = true;
   for(int i = 1; i <= exit_confirm_bars; i++)
   {
      if(!(base_line[i] < -meaningful_zero_distance &&
           base_line[i] < base_line[i + 1]))
         long_macd_failure = false;
      if(!(base_line[i] > meaningful_zero_distance &&
           base_line[i] > base_line[i + 1]))
         short_macd_failure = false;
      if(!(iClose(_Symbol, g_calc_tf, i) < slow[i]))
         long_ma22_failure = false;
      if(!(iClose(_Symbol, g_calc_tf, i) > slow[i]))
         short_ma22_failure = false;
      if(!(raw[i] <= -InpDominanceWeakLevel))
         opposite_sell_confirmed = false;
      if(!(raw[i] >= InpDominanceWeakLevel))
         opposite_buy_confirmed = false;
   }
   const bool strong_buy =
      raw[1] >= InpDominanceStrongLevel && delta_ema[1] > delta_ema[2];
   const bool strong_sell =
      raw[1] <= -InpDominanceStrongLevel && delta_ema[1] < delta_ema[2];
   const bool volume_expansion =
      average_volume > 0.0 &&
      volume[1] >= average_volume * InpBreakoutVolumeFactor;

   const bool macd_turn_long =
      BarsSinceMostRecentCross(base_line, 1) >= 0 && base_line[1] > 0.0;
   const bool macd_turn_short =
      BarsSinceMostRecentCross(base_line, -1) >= 0 && base_line[1] < 0.0;
   bool ma_turn_long = false;
   bool ma_turn_short = false;
   for(int shift = 1; shift <= InpSignalValidBars; shift++)
   {
      if(fast[shift] > slow[shift] &&
         fast[shift + 1] <= slow[shift + 1])
         ma_turn_long = true;
      if(fast[shift] < slow[shift] &&
         fast[shift + 1] >= slow[shift + 1])
         ma_turn_short = true;
   }

   const bool signal_reaccel_long =
      base_line[1] > 0.0 && base_up &&
      HasConfirmedPullback(1, fast, slow);
   const bool signal_reaccel_short =
      base_line[1] < 0.0 && base_down &&
      HasConfirmedPullback(-1, fast, slow);
   const bool auto_reaccel_long =
      base_line[1] > 0.0 && base_up &&
      HasConfirmedPullback(1, fast, slow);
   const bool auto_reaccel_short =
      base_line[1] < 0.0 && base_down &&
      HasConfirmedPullback(-1, fast, slow);
   const bool turn_long = macd_turn_long && ma_turn_long;
   const bool turn_short = macd_turn_short && ma_turn_short;

   double prior_high = iHigh(_Symbol, g_calc_tf, 2);
   double prior_low = iLow(_Symbol, g_calc_tf, 2);
   for(int i = 3; i <= InpSwingLookback + 1; i++)
   {
      prior_high = MathMax(prior_high, iHigh(_Symbol, g_calc_tf, i));
      prior_low = MathMin(prior_low, iLow(_Symbol, g_calc_tf, i));
   }
   const bool high_break = close1 > prior_high;
   const bool low_break = close1 < prior_low;

   double recent_high = iHigh(_Symbol, g_calc_tf, 2);
   double recent_low = iLow(_Symbol, g_calc_tf, 2);
   double older_high = recent_high, older_low = recent_low;
   for(int i = 2; i <= InpCompressionRecentBars + 1; i++)
   {
      recent_high = MathMax(recent_high, iHigh(_Symbol, g_calc_tf, i));
      recent_low = MathMin(recent_low, iLow(_Symbol, g_calc_tf, i));
   }
   for(int i = InpCompressionRecentBars + 2;
       i <= InpCompressionLookback + 1; i++)
   {
      older_high = MathMax(older_high, iHigh(_Symbol, g_calc_tf, i));
      older_low = MathMin(older_low, iLow(_Symbol, g_calc_tf, i));
   }
   const double recent_range = recent_high - recent_low;
   const double older_range = older_high - older_low;
   const bool compressed =
      older_range > 0.0 &&
      recent_range <= older_range * InpCompressionRatio;
   const bool long_decline_or_sideways =
      ma70[InpCompressionRecentBars + 1] >= ma70[1] ||
      MathAbs(ma70[1] - ma70[InpCompressionRecentBars + 1]) <=
      MathMax(_Point, recent_range * 0.20);
   const bool compression_break_long =
      compressed && long_decline_or_sideways && close1 > recent_high &&
      volume_expansion;
   const bool compression_break_short =
      compressed && close1 < recent_low && volume_expansion;
   const bool ma22_up = slow[1] > slow[3];
   const bool ma22_down = slow[1] < slow[3];
   const bool ma70_up = ma70[1] > ma70[3];
   const bool ma70_down = ma70[1] < ma70[3];

   // The identical Direction Quality snapshot is used by TREND AUTO.
   int trend_long_direction_quality = 0, trend_short_direction_quality = 0;
   bool trend_direction_long_allowed = false, trend_direction_short_allowed = false;
   bool trend_neutral_flow = false, trend_compressed_chop = false;
   bool trend_late_long = false, trend_late_short = false;
   CalculateCommonDirectionQuality(fast, slow, ma70, base_line, raw, count,
      close1, base_up, base_down, buy_dominance, sell_dominance,
      dominance_sum, average_delta, ma22_up, ma22_down, ma70_up, ma70_down,
      trend_long_direction_quality, trend_short_direction_quality,
      trend_direction_long_allowed, trend_direction_short_allowed,
      trend_neutral_flow, trend_compressed_chop, trend_late_long, trend_late_short);

   const bool long_retest =
      low1 <= slow[1] && close1 > slow[1] && buy_dominance;
   const bool short_retest =
      high1 >= slow[1] && close1 < slow[1] && sell_dominance;
   const bool protected_by_111 =
      close1 > ma111[1] && ma111[1] >= ma111[3] &&
      slow[1] > ma70[1] && !low_break;
   const bool oversized = OversizedClosedBar();

   // Chart-pattern learning: convert visual structures into objective price,
   // MACD and delta conditions. All patterns use closed bars only.
   const double average_range = MathMax(_Point, AverageClosedBarRange());
   double trend_timing_high = iHigh(_Symbol, g_calc_tf, 2);
   double trend_timing_low  = iLow(_Symbol, g_calc_tf, 2);
   const int trend_timing_lookback = MathMax(2, MathMin(InpTimingBreakLookback, count - 3));
   for(int i = 3; i <= trend_timing_lookback + 1; i++)
   {
      trend_timing_high = MathMax(trend_timing_high, iHigh(_Symbol, g_calc_tf, i));
      trend_timing_low  = MathMin(trend_timing_low,  iLow(_Symbol, g_calc_tf, i));
   }
   const bool trend_micro_break_long = close1 > trend_timing_high;
   const bool trend_micro_break_short = close1 < trend_timing_low;
   const bool trend_fast_reclaim_long = low1 <= fast[1] && close1 > fast[1];
   const bool trend_fast_reject_short = high1 >= fast[1] && close1 < fast[1];
   const bool trend_macd_turn_long = base_up && (base_line[2] <= base_line[3] || base_line[1] > base_line[3]);
   const bool trend_macd_turn_short = base_down && (base_line[2] >= base_line[3] || base_line[1] < base_line[3]);
   const bool trend_delta_long = raw[1] > 0.0 || (raw[1] > raw[2] && delta_ema[1] > delta_ema[2] && dominance_sum > 0.0);
   const bool trend_delta_short = raw[1] < 0.0 || (raw[1] < raw[2] && delta_ema[1] < delta_ema[2] && dominance_sum < 0.0);
   const bool trend_not_late_long = close1 >= fast[1] && (close1 - fast[1]) <= average_range * InpTimingMaxFastDistance;
   const bool trend_not_late_short = close1 <= fast[1] && (fast[1] - close1) <= average_range * InpTimingMaxFastDistance;
   const bool trend_timing_long = trend_macd_turn_long && trend_delta_long && trend_not_late_long &&
      (trend_micro_break_long || trend_fast_reclaim_long);
   const bool trend_timing_short = trend_macd_turn_short && trend_delta_short && trend_not_late_short &&
      (trend_micro_break_short || trend_fast_reject_short);
   const double body1 = MathMax(_Point, MathAbs(close1 - iOpen(_Symbol, g_calc_tf, 1)));
   const double upper_wick1 = high1 - MathMax(close1, iOpen(_Symbol, g_calc_tf, 1));
   const double lower_wick1 = MathMin(close1, iOpen(_Symbol, g_calc_tf, 1)) - low1;
   const bool long_upper_rejection = upper_wick1 >= body1 * InpLongWickBodyRatio;
   const bool short_lower_rejection = lower_wick1 >= body1 * InpLongWickBodyRatio;

   // v8.03: canonical recent/older swing structure is owned by
   // StateEvaluationEngine. SignalEngine consumes the same closed-bar snapshot
   // used by RANGE continuation ADD instead of re-reading price history.
   const int half_pattern = MathMax(3, InpPatternLookback / 2);
   const bool shared_structure_ready =
      g_assist_state.bar_time==iTime(_Symbol,g_calc_tf,1) &&
      g_assist_state.timeframe==g_calc_tf;
   if(!shared_structure_ready)
      return;
   const double recent_swing_low = g_assist_state.recent_swing_low;
   const double older_swing_low = g_assist_state.older_swing_low;
   const double recent_swing_high = g_assist_state.recent_swing_high;
   const double older_swing_high = g_assist_state.older_swing_high;
   const double pattern_tolerance = average_range * InpDoubleTopBottomTolerance;
   const double retest_tolerance = average_range * InpRetestToleranceRange;
   const bool higher_low = g_assist_state.structure_higher_low;
   const bool lower_high = g_assist_state.structure_lower_high;
   const bool double_bottom =
      MathAbs(recent_swing_low - older_swing_low) <= pattern_tolerance &&
      base_line[1] > base_line[half_pattern + 1] &&
      raw[1] > raw[half_pattern + 1];
   const bool double_top =
      MathAbs(recent_swing_high - older_swing_high) <= pattern_tolerance &&
      base_line[1] < base_line[half_pattern + 1] &&
      raw[1] < raw[half_pattern + 1];
   const bool breakout_retest_long =
      close1 > prior_high && low1 <= prior_high + retest_tolerance &&
      low1 >= prior_high - retest_tolerance && buy_dominance && base_up;
   const bool breakout_retest_short =
      close1 < prior_low && high1 >= prior_low - retest_tolerance &&
      high1 <= prior_low + retest_tolerance && sell_dominance && base_down;
   const bool pullback_continuation_long =
      slow[1] > ma70[1] && ma22_up && long_retest &&
      (higher_low || close1 > recent_swing_high) && base_up;
   const bool pullback_continuation_short =
      slow[1] < ma70[1] && ma22_down && short_retest &&
      (lower_high || close1 < recent_swing_low) && base_down;
   const bool failed_break_long =
      high1 > prior_high && close1 <= prior_high &&
      (long_upper_rejection || strong_sell ||
       (raw[1] > 0.0 && !base_up));
   const bool failed_break_short =
      low1 < prior_low && close1 >= prior_low &&
      (short_lower_rejection || strong_buy ||
       (raw[1] < 0.0 && !base_down));
   const bool bottom_reversal =
      (double_bottom || higher_low) && turn_long && buy_dominance;
   const bool top_reversal =
      (double_top || lower_high) && turn_short && sell_dominance;

   string long_pattern = trend_timing_long ? "TIMED TREND START" :
                         (compression_break_long ? "COMPRESSION BREAK" :
                         (breakout_retest_long ? "BREAKOUT RETEST" :
                         (pullback_continuation_long ? "PULLBACK CONTINUATION" :
                         (bottom_reversal ? "BOTTOM REVERSAL" :
                         (turn_long ? "TURN" : "RE-ACCEL")))));
   string short_pattern = trend_timing_short ? "TIMED TREND START" :
                          (compression_break_short ? "COMPRESSION BREAK" :
                          (breakout_retest_short ? "BREAKOUT RETEST" :
                          (pullback_continuation_short ? "PULLBACK CONTINUATION" :
                          (top_reversal ? "TOP REVERSAL" :
                          (turn_short ? "TURN" : "RE-ACCEL")))));

   int long_score = 0, short_score = 0;
   long_score += macd_turn_long ? 25 : (base_line[1] > 0.0 && base_up ? 15 : 0);
   short_score += macd_turn_short ? 25 : (base_line[1] < 0.0 && base_down ? 15 : 0);
   if(ma22_up && close1 > slow[1]) long_score += 15;
   if(ma22_down && close1 < slow[1]) short_score += 15;
   if(slow[1] > ma70[1] && ma70_up) long_score += 15;
   if(slow[1] < ma70[1] && ma70_down) short_score += 15;
   if(buy_dominance) long_score += 15;
   if(sell_dominance) short_score += 15;
   if(strong_buy) long_score += 5;
   if(strong_sell) short_score += 5;
   if(close1 > ma111[1] && close1 > ma200[1]) long_score += 10;
   if(close1 < ma111[1] && close1 < ma200[1]) short_score += 10;
   if(high_break || compression_break_long) long_score += 10;
   if(low_break || compression_break_short) short_score += 10;
   if(volume_expansion && raw[1] > 0.0) long_score += 10;
   if(volume_expansion && raw[1] < 0.0) short_score += 10;
   if(TradingTFDirectionMaintained(1)) long_score += 10;
   if(TradingTFDirectionMaintained(-1)) short_score += 10;
   if(trend_timing_long) long_score += 20;
   if(trend_timing_short) short_score += 20;
   if(InpUsePatternLearning)
   {
      if(compression_break_long || bottom_reversal || higher_low)
         long_score += InpPatternBonus;
      if(compression_break_short || top_reversal || lower_high)
         short_score += InpPatternBonus;
      if(breakout_retest_long || pullback_continuation_long)
         long_score += InpRetestBonus;
      if(breakout_retest_short || pullback_continuation_short)
         short_score += InpRetestBonus;
      if(failed_break_long)
         long_score -= InpFailedBreakPenalty;
      if(failed_break_short)
         short_score -= InpFailedBreakPenalty;
   }
   if(sell_dominance) long_score -= 15;
   if(buy_dominance) short_score -= 15;
   long_score = MathMax(0, MathMin(100, long_score));
   short_score = MathMax(0, MathMin(100, short_score));
   g_last_long_score = long_score;
   g_last_short_score = short_score;

   // Entry confidence is separate from the setup score. A direction can have
   // enough historical score while current momentum is contracting or price is
   // trapped around the moving averages. Confidence measures whether the market
   // is actually expanding in the proposed direction now.
   const bool macd_expanding_long =
      base_line[1] > 0.0 && base_up && MathAbs(base_line[1]) > MathAbs(base_line[2]);
   const bool macd_expanding_short =
      base_line[1] < 0.0 && base_down && MathAbs(base_line[1]) > MathAbs(base_line[2]);
   const bool macd_contracting =
      MathAbs(base_line[1]) < MathAbs(base_line[2]) &&
      MathAbs(base_line[2]) <= MathAbs(base_line[3]);
   const bool delta_expanding_long =
      raw[1] > 0.0 && raw[1] > raw[2] && delta_ema[1] > delta_ema[2];
   const bool delta_expanding_short =
      raw[1] < 0.0 && raw[1] < raw[2] && delta_ema[1] < delta_ema[2];
   const bool delta_contracting =
      MathAbs(raw[1]) < MathAbs(raw[2]) &&
      MathAbs(delta_ema[1]) <= MathAbs(delta_ema[2]);

   int long_confidence = 0, short_confidence = 0;
   long_confidence += trend_macd_strong_long ? 20 :
      (macd_expanding_long ? 10 : 0);
   short_confidence += trend_macd_strong_short ? 20 :
      (macd_expanding_short ? 10 : 0);
   long_confidence += trend_delta_strong_long ? 20 : (buy_dominance ? 5 : 0);
   short_confidence += trend_delta_strong_short ? 20 : (sell_dominance ? 5 : 0);
   if(ma22_up && close1 > slow[1]) long_confidence += 15;
   if(ma22_down && close1 < slow[1]) short_confidence += 15;
   if((fast[1] > slow[1] && close1 > fast[1]) ||
      breakout_retest_long || pullback_continuation_long || high_break)
      long_confidence += 20;
   if((fast[1] < slow[1] && close1 < fast[1]) ||
      breakout_retest_short || pullback_continuation_short || low_break)
      short_confidence += 20;
   if(TradingTFDirectionMaintained(1)) long_confidence += 15;
   if(TradingTFDirectionMaintained(-1)) short_confidence += 15;
   if(volume_expansion && raw[1] > 0.0) long_confidence += 10;
   if(volume_expansion && raw[1] < 0.0) short_confidence += 10;
   if(macd_contracting)
   {
      long_confidence -= 10;
      short_confidence -= 10;
   }
   if(delta_contracting)
   {
      long_confidence -= 10;
      short_confidence -= 10;
   }
   long_confidence = MathMax(0, MathMin(100, long_confidence));
   short_confidence = MathMax(0, MathMin(100, short_confidence));
   g_last_long_confidence = long_confidence;
   g_last_short_confidence = short_confidence;

   double box_high = iHigh(_Symbol, g_calc_tf, 1);
   double box_low = iLow(_Symbol, g_calc_tf, 1);
   for(int i = 2; i <= 3; i++)
   {
      box_high = MathMax(box_high, iHigh(_Symbol, g_calc_tf, i));
      box_low = MathMin(box_low, iLow(_Symbol, g_calc_tf, i));
   }
   const bool ma22_flat =
      MathAbs(slow[1] - slow[3]) <= average_range * InpFlatMA22RangeFactor;
   const bool ma_gap_narrow =
      MathAbs(fast[1] - slow[1]) <= average_range * InpNarrowMAGapRangeFactor;
   const bool small_recent_box =
      (box_high - box_low) <= average_range * InpSmallBoxRangeFactor;
   const bool score_gap_small =
      MathAbs(long_score - short_score) < InpBothDirectionMinimumScoreGap;
   const bool confidence_gap_small =
      MathAbs(long_confidence - short_confidence) < InpMinimumConfidenceGap;

   int no_trade_flags = 0;
   if(macd_contracting) no_trade_flags++;
   if(delta_contracting) no_trade_flags++;
   if(ma22_flat) no_trade_flags++;
   if(ma_gap_narrow) no_trade_flags++;
   if(small_recent_box) no_trade_flags++;
   if(score_gap_small) no_trade_flags++;
   if(confidence_gap_small) no_trade_flags++;
   g_last_no_trade_flags = no_trade_flags;
   const bool no_trade_zone =
      InpUseNoTradeZone && no_trade_flags >= InpNoTradeMinimumFlags;
   const bool long_confident =
      long_confidence >= InpMinimumEntryConfidence &&
      (!InpUseNoTradeZone ||
       long_confidence >= short_confidence + InpMinimumConfidenceGap);
   const bool short_confident =
      short_confidence >= InpMinimumEntryConfidence &&
      (!InpUseNoTradeZone ||
       short_confidence >= long_confidence + InpMinimumConfidenceGap);

   const bool unsafe_long =
      oversized || strong_sell || failed_break_long || !buy_dominance ||
      (!ma22_up && MathAbs(slow[1] - slow[3]) < _Point);
   const bool unsafe_short =
      oversized || strong_buy || failed_break_short || !sell_dominance || protected_by_111 ||
      (!ma22_down && MathAbs(slow[1] - slow[3]) < _Point);

   // v7.16 RANGE-only: removed unused fixed-M5 direction-score calculation.
   // It had no downstream order/signal consumer and only duplicated indicator reads.
   const double trend_ma22_tolerance =
      average_range * InpTradingTFMA22TouchToleranceRange;
   const bool trend_ma22_long_trigger =
      low1 <= slow[1] + trend_ma22_tolerance && close1 > slow[1] &&
      (fast[1] >= slow[1] || fast[1] > fast[2]);
   const bool trend_ma22_short_trigger =
      high1 >= slow[1] - trend_ma22_tolerance && close1 < slow[1] &&
      (fast[1] <= slow[1] || fast[1] < fast[2]);

   // TREND: M15 SETUP -> M4 first pullback -> M4 MA7/MACD/Delta restart -> M2 MA22 permission -> HOLD.
   int m15_long_score=0,m15_short_score=0;
   const bool m15_ready=CalculateTradingTFTrendScores(m15_long_score,m15_short_score);
   const bool trend_state_long_bias=m15_ready && m15_long_score>=InpM15TrendMinimumScore &&
      m15_long_score>=m15_short_score+InpM15TrendMinimumGap && !strong_sell;
   const bool trend_state_short_bias=m15_ready && m15_short_score>=InpM15TrendMinimumScore &&
      m15_short_score>=m15_long_score+InpM15TrendMinimumGap && !strong_buy && !protected_by_111;
   bool m4_long_pullback=false,m4_long_restart=false,m4_short_pullback=false,m4_short_restart=false;
   const bool m4_long_ready=CalculateTradingTFTrendRestart(1,m4_long_pullback,m4_long_restart);
   const bool m4_short_ready=CalculateTradingTFTrendRestart(-1,m4_short_pullback,m4_short_restart);
   const bool trend_state_long_pullback=trend_state_long_bias && m4_long_ready && m4_long_pullback;
   const bool trend_state_short_pullback=trend_state_short_bias && m4_short_ready && m4_short_pullback;
   const bool trend_state_long_trigger=trend_state_long_bias && m4_long_ready && m4_long_restart &&
      (!InpRequireTradingTFMA22Trigger || trend_ma22_long_trigger);
   const bool trend_state_short_trigger=trend_state_short_bias && m4_short_ready && m4_short_restart &&
      (!InpRequireTradingTFMA22Trigger || trend_ma22_short_trigger);
   UpdateTrendInternalState(trend_state_long_bias, trend_state_short_bias,
                            trend_state_long_pullback, trend_state_short_pullback,
                            trend_state_long_trigger, trend_state_short_trigger);
   // v3.08: separate TREND signal-observation authority from AUTO entry state.
   //
   // Before entry, chart FINAL signals keep the existing PULLBACK/ENTRY state
   // requirement.  Once a managed TREND position exists, UpdateTrendInternalState()
   // intentionally moves the lifecycle to HOLD; HOLD must not silence the market
   // signal engine.  While HOLD is active, a fresh M15 directional bias may again
   // authorize chart/alert FINAL evaluation in either direction.  All the existing
   // score, confidence, MACD/Delta, timing and countertrend/reversal gates below
   // still apply, so HOLD alone can never manufacture a FINAL signal.
   //
   // AUTO INITIAL permission remains strictly ENTRY-state only through
   // trend_state_allows_long/short.  Therefore this change restores signal
   // visibility/3X/ADD evidence without creating duplicate INITIAL orders.
   const int trend_managed_position_side = ManagedPositionSide();
   const bool trend_hold_observation =
      trend_managed_position_side != 0 &&
      g_trend_internal_state == TREND_STATE_HOLD;

   const bool trend_signal_state_long =
      (g_trend_internal_side == 1 &&
       (g_trend_internal_state == TREND_STATE_PULLBACK ||
        g_trend_internal_state == TREND_STATE_ENTRY)) ||
      (trend_hold_observation && trend_state_long_bias);

   const bool trend_signal_state_short =
      (g_trend_internal_side == -1 &&
       (g_trend_internal_state == TREND_STATE_PULLBACK ||
        g_trend_internal_state == TREND_STATE_ENTRY)) ||
      (trend_hold_observation && trend_state_short_bias);

   const bool trend_state_allows_long =
      g_trend_internal_side == 1 && g_trend_internal_state == TREND_STATE_ENTRY;
   const bool trend_state_allows_short =
      g_trend_internal_side == -1 && g_trend_internal_state == TREND_STATE_ENTRY;

   // Earlier closed-bar entry. It uses the exact same menu lot as every
   // initial order; there is no half-size or confirmation fill.
   const double early_ma_tolerance = average_range * InpEarlyMAGapRange;
   const bool early_delta_long = trend_delta_strong_long;
   const bool early_delta_short = trend_delta_strong_short;
   // Early AUTO is deliberately independent from chart-signal and TREND internal
   // ENTRY state. It still requires direction, confidence, structure and order flow.
   const bool early_long_setup =
      InpUseEarlyEntry && long_score >= InpEarlyEntryScore &&
      (!no_trade_zone || InpNoTradeFlagsDiagnosticOnly) && long_confident &&
      !failed_break_long && !oversized && !strong_sell &&
      base_up && base_line[1] >= -meaningful_zero_distance &&
      fast[1] > fast[2] && fast[1] >= slow[1] - early_ma_tolerance &&
      close1 > fast[1] && early_delta_long && !TradingTFDirectionMaintained(-1);
   const bool early_short_setup =
      InpUseEarlyEntry && short_score >= InpEarlyEntryScore &&
      (!no_trade_zone || InpNoTradeFlagsDiagnosticOnly) && short_confident &&
      !failed_break_short && !oversized && !strong_buy && !protected_by_111 &&
      base_down && base_line[1] <= meaningful_zero_distance &&
      fast[1] < fast[2] && fast[1] <= slow[1] + early_ma_tolerance &&
      close1 < fast[1] && early_delta_short && !TradingTFDirectionMaintained(1);

   const bool signal_long_setup =
      process_signals && g_signal_enabled &&
      SignalDirectionAllows(1) && long_score >= InpWatchScore &&
      (!no_trade_zone || InpNoTradeFlagsDiagnosticOnly) && long_confident &&
      (!InpRequireMACDColor || macd_color_state[1] > 0.0) &&
      !strong_sell && buy_dominance && trend_signal_state_long &&
      (trend_timing_long || turn_long || compression_break_long || bottom_reversal ||
       breakout_retest_long || pullback_continuation_long ||
       (InpAllowContinuation && signal_reaccel_long));
   const bool signal_short_setup =
      process_signals && g_signal_enabled &&
      SignalDirectionAllows(-1) && short_score >= InpWatchScore &&
      (!no_trade_zone || InpNoTradeFlagsDiagnosticOnly) && short_confident &&
      (!InpRequireMACDColor || macd_color_state[1] < 0.0) &&
      !strong_buy && sell_dominance && !protected_by_111 && trend_signal_state_short &&
      (trend_timing_short || turn_short || compression_break_short || top_reversal ||
       breakout_retest_short || pullback_continuation_short ||
       (InpAllowContinuation && signal_reaccel_short));
   const int confirmed_signal_score =
      InpUseEntryScoreForSignal ? InpEntryScore : InpChartSignalScore;

   // Reject opposite-direction micro-pullbacks before a final TREND signal is
   // created.  Only a structurally confirmed reversal can pass.  This blocks
   // chart arrows, alerts, CSV signal rows, AUTO counters and orders together.
   const bool established_chart_long_trend =
      trend_strong_direction_long && fast[1] > slow[1] && slow[1] > ma70[1] &&
      close1 > slow[1] && base_line[1] >= 0.0;
   const bool established_chart_short_trend =
      trend_strong_direction_short && fast[1] < slow[1] && slow[1] < ma70[1] &&
      close1 < slow[1] && base_line[1] <= 0.0;
   const bool confirmed_chart_reversal_long =
      close1 > slow[1] && base_up && raw[1] > 0.0 &&
      (bottom_reversal || compression_break_long ||
       (turn_long && fast[1] >= slow[1]));
   const bool confirmed_chart_reversal_short =
      close1 < slow[1] && base_down && raw[1] < 0.0 &&
      (top_reversal || compression_break_short ||
       (turn_short && fast[1] <= slow[1]));
   const bool block_trend_long_countertrend =
      established_chart_short_trend && !confirmed_chart_reversal_long;
   const bool block_trend_short_countertrend =
      established_chart_long_trend && !confirmed_chart_reversal_short;

   const bool confirmed_long =
      signal_long_setup && long_score >= confirmed_signal_score &&
      !block_trend_long_countertrend;
   const bool confirmed_short =
      signal_short_setup && short_score >= confirmed_signal_score &&
      !block_trend_short_countertrend;
   // TREND signal arbitration continues directly; the retired 3X observation
   // alert no longer inserts a process_signals wrapper here.
   const bool signal_both_mode =
      g_signal_direction == SIGNAL_BOTH;
   const bool signal_long =
      confirmed_long &&
      (!signal_both_mode || !confirmed_short ||
       long_score >= short_score + InpBothDirectionMinimumScoreGap);
   const bool signal_short =
      confirmed_short &&
      (!signal_both_mode || !confirmed_long ||
       short_score >= long_score + InpBothDirectionMinimumScoreGap);

   // v8.56: publish the existing TREND analysis as the single M3 AUTO
   // decision snapshot. M3 AUTO must not rebuild another trend detector.
   g_decision_snapshot.bar_time=iTime(_Symbol,g_calc_tf,1);
   g_decision_snapshot.timeframe_seconds=PeriodSeconds(g_calc_tf);
   g_decision_snapshot.final_long=signal_long;
   g_decision_snapshot.final_short=signal_short;
   g_decision_snapshot.long_score=long_score;
   g_decision_snapshot.short_score=short_score;
   g_decision_snapshot.long_confidence=long_confidence;
   g_decision_snapshot.short_confidence=short_confidence;
   g_decision_snapshot.long_bias=trend_state_long_bias;
   g_decision_snapshot.short_bias=trend_state_short_bias;
   g_decision_snapshot.long_timing=trend_timing_long;
   g_decision_snapshot.short_timing=trend_timing_short;
   g_decision_snapshot.long_pullback=pullback_continuation_long;
   g_decision_snapshot.short_pullback=pullback_continuation_short;
   g_decision_snapshot.long_reaccel=auto_reaccel_long;
   g_decision_snapshot.short_reaccel=auto_reaccel_short;
   g_decision_snapshot.long_strong_direction=trend_strong_direction_long;
   g_decision_snapshot.short_strong_direction=trend_strong_direction_short;
   g_decision_snapshot.long_no_trade=no_trade_zone;
   g_decision_snapshot.short_no_trade=no_trade_zone;
   g_decision_snapshot.long_unsafe=unsafe_long;
   g_decision_snapshot.short_unsafe=unsafe_short;
   g_decision_snapshot.long_chase=IsChasingSignal(1,close1,slow[1]);
   g_decision_snapshot.short_chase=IsChasingSignal(-1,close1,slow[1]);
   g_decision_snapshot.long_event_id=signal_long ?
      StringFormat("%s|%d|LONG",TimeToString(g_decision_snapshot.bar_time,TIME_DATE|TIME_MINUTES),PeriodSeconds(g_calc_tf)) : "";
   g_decision_snapshot.short_event_id=signal_short ?
      StringFormat("%s|%d|SHORT",TimeToString(g_decision_snapshot.bar_time,TIME_DATE|TIME_MINUTES),PeriodSeconds(g_calc_tf)) : "";
   g_decision_snapshot.shared_signal_auto_pass=false;

   if(process_signals && !g_auto_trading)
   {
      const datetime pre_auto_bar=iTime(_Symbol,g_calc_tf,1);
      if(signal_long)
         RecordPreAutoFinalSignal(1,long_score,pre_auto_bar,
                                  STRATEGY_TREND,g_calc_tf);
      if(signal_short)
         RecordPreAutoFinalSignal(-1,short_score,pre_auto_bar,
                                  STRATEGY_TREND,g_calc_tf);
   }

   const bool chase_long = IsChasingSignal(1, close1, slow[1]);
   const bool chase_short = IsChasingSignal(-1, close1, slow[1]);
   const bool show_trend_long_signal = signal_long;
   const bool show_trend_short_signal = signal_short;

   if(block_trend_long_countertrend) RemoveEntrySignalArrow(1);
   if(block_trend_short_countertrend) RemoveEntrySignalArrow(-1);

   if(signal_long)
   {
      if(show_trend_long_signal)
         DrawEntrySignalArrow(1, long_score, long_pattern, base_up ? "RISING" : "FLAT",
                              raw[1] > 0.0 ? "BUY" : "RECOVERY", close1);
      else
         RemoveEntrySignalArrow(1);
      g_status = StringFormat("BUY SIGNAL %s | STATE %s | SCORE %d | DELTA BUY",
         long_pattern, TrendInternalStateName(), long_score);
      if(g_minimum_alert_score>0 && long_score >= g_minimum_alert_score &&
         !unsafe_long && !chase_long && IsNewAlertBar(1))
      {
         g_status=JTAFormatFinalSignalAlert(1,long_score,1,1,long_pattern);
         // v4.14: ordinary FINAL SYS/MOB alert removed; chart/status/CSV remain.
      }
   }
   if(signal_short)
   {
      if(show_trend_short_signal)
         DrawEntrySignalArrow(-1, short_score, short_pattern, base_down ? "FALLING" : "FLAT",
                              raw[1] < 0.0 ? "SELL" : "RECOVERY", close1);
      else
         RemoveEntrySignalArrow(-1);
      g_status = StringFormat("SELL SIGNAL %s | STATE %s | SCORE %d | DELTA SELL",
         short_pattern, TrendInternalStateName(), short_score);
      if(g_minimum_alert_score>0 && short_score >= g_minimum_alert_score &&
         !unsafe_short && !chase_short && IsNewAlertBar(-1))
      {
         g_status=JTAFormatFinalSignalAlert(-1,short_score,1,1,short_pattern);
         // v4.14: ordinary FINAL SYS/MOB alert removed; chart/status/CSV remain.
      }
   }

   if(no_trade_zone && ManagedPositionSide() == 0)
      g_status = StringFormat("NO TRADE ZONE | FLAGS %d | CONF L%d/S%d",
                              no_trade_flags, long_confidence, short_confidence);
   else if(ManagedPositionSide() == 0 &&
           !long_confident && !short_confident)
      g_status = StringFormat("LOW CONFIDENCE | L%d/S%d | MIN %d",
                              long_confidence, short_confidence,
                              InpMinimumEntryConfidence);

   // AUTO entry is intentionally not split by asset. Bitcoin and all other
   // symbols use the same strict gate; profile-specific risk values remain active.

   // Signal arrows/alerts use only SIG TF. They never inspect, add, close,
   // or open a real position.
   if(!process_auto)
      return;

   // v8.67: M3 AUTO owns the complete order lifecycle. This legacy completed-bar
   // path is diagnostic/chart-only whenever M3 AUTO is active.
   if(M3AutoEngineIsActive() && g_auto_trading)
      return;

   // v8.57 ORDER AUTHORITY: when M3 AUTO is active and there is no managed
   // position, this legacy TREND block is analysis/diagnostics only. Its old
   // regular/early/3-signal INITIAL paths must never reach EntryEngine.
   // The already-published decision snapshot is consumed by M3AutoEngine.
   // Existing-position Hold/Exit/Add processing below remains available because
   // it is the current canonical completed-bar position-management path.
   if(g_m3_auto_order_authority_active && ManagedPositionSide()==0)
   {
      if(signal_long || signal_short)
         g_status=StringFormat("M3 AUTO AUTHORITY | TREND SIGNAL %s | INITIAL OWNED BY M3",
                               signal_long && signal_short ? "CONFLICT" :
                               (signal_long ? "LONG" : "SHORT"));
      return;
   }

   const int position_side = ManagedPositionSide();
   // v8.65: when M3 AUTO owns the lifecycle, legacy SignalEngine may still
   // publish diagnostics above, but it must never ADD/HOLD/EXIT the position.
   if(g_m3_auto_order_authority_active && position_side!=0)
      return;

   if(position_side != 0)
   {
      // Same-side delta dominance has priority during consolidation.  MACD
      // colour changes, a shallow zero touch, MA7/MA22 noise and a single
      // swing break cannot close the position while this protection is true.
      const bool long_sideways_hold =
         position_side > 0 && buy_dominance &&
         dominance_sum > 0.0 && !long_macd_failure;
      const bool short_sideways_hold =
         position_side < 0 && sell_dominance &&
         dominance_sum < 0.0 && !short_macd_failure;
      const bool shallow_long_zero_break =
         position_side > 0 && base_line[1] < 0.0 &&
         base_line[1] >= -meaningful_zero_distance;
      const bool shallow_short_zero_break =
         position_side < 0 && base_line[1] > 0.0 &&
         base_line[1] <= meaningful_zero_distance;
      const bool trading_tf_direction_hold = TradingTFDirectionMaintained(position_side);
      const double current_progress_r = CurrentProgressR(position_side);
      bool lifecycle_pullback=false, lifecycle_absorption=false, lifecycle_fatigue=false;
      bool lifecycle_compression=false;
      int lifecycle_bounces=0;
      string lifecycle_pattern_detail="";
      EvaluatePatternLifecycleAssist(position_side, lifecycle_pullback,
         lifecycle_absorption, lifecycle_fatigue, lifecycle_compression,
         lifecycle_bounces, lifecycle_pattern_detail);
      const bool lifecycle_pattern_support = lifecycle_pullback ||
         lifecycle_absorption || lifecycle_compression || lifecycle_bounces >= 2;

      // Closed-bar market-structure memory.  A fresh higher high (LONG) or
      // lower low (SHORT) protects the position from strategy exits.  Failure
      // requires both no fresh extreme and repeated adverse swing movement.
      const int hold_structure_bars = MathMax(3, InpHoldStructureLookbackBars);
      double recent_high = -DBL_MAX, prior_high = -DBL_MAX;
      double recent_low = DBL_MAX, prior_low = DBL_MAX;
      int falling_lows = 0, rising_highs = 0;
      for(int i = 1; i <= hold_structure_bars; i++)
      {
         const double bar_high = iHigh(_Symbol, g_calc_tf, i);
         const double bar_low = iLow(_Symbol, g_calc_tf, i);
         recent_high = MathMax(recent_high, bar_high);
         recent_low = MathMin(recent_low, bar_low);
         if(i < hold_structure_bars)
         {
            if(bar_low < iLow(_Symbol, g_calc_tf, i + 1)) falling_lows++;
            if(bar_high > iHigh(_Symbol, g_calc_tf, i + 1)) rising_highs++;
         }
      }
      for(int i = hold_structure_bars + 1; i <= hold_structure_bars * 2; i++)
      {
         prior_high = MathMax(prior_high, iHigh(_Symbol, g_calc_tf, i));
         prior_low = MathMin(prior_low, iLow(_Symbol, g_calc_tf, i));
      }
      const bool fresh_high_update = position_side > 0 && recent_high > prior_high;
      const bool fresh_low_update = position_side < 0 && recent_low < prior_low;
      const int structure_sequence_min = MathMax(2, hold_structure_bars / 2);
      const bool long_structure_stall = position_side > 0 &&
         !fresh_high_update && falling_lows >= structure_sequence_min;
      const bool short_structure_stall = position_side < 0 &&
         !fresh_low_update && rising_highs >= structure_sequence_min;
      const bool fresh_extreme_update = fresh_high_update || fresh_low_update;
      const bool structure_stall = long_structure_stall || short_structure_stall;

      // Directional hold scoring is independent of profit R.  MACD and delta
      // agreement can activate strong hold immediately after entry.
      int hold_score = 0;
      if(position_side > 0)
      {
         if(trend_macd_strong_long) hold_score += 2;
         else if(base_line[1] > 0.0 && base_up) hold_score++;
         if(trend_delta_strong_long) hold_score += 2;
         else if(buy_dominance && delta_ema[1] > 0.0) hold_score++;
         if(close1 > fast[1]) hold_score++;
         if(fast[1] > slow[1]) hold_score++;
         if(ma22_up) hold_score++;
         if(trading_tf_direction_hold) hold_score++;
         if(higher_low || breakout_retest_long) hold_score++;
         if(fresh_high_update) hold_score++;
         if(!failed_break_long && !strong_sell) hold_score++;
      }
      else
      {
         if(trend_macd_strong_short) hold_score += 2;
         else if(base_line[1] < 0.0 && base_down) hold_score++;
         if(trend_delta_strong_short) hold_score += 2;
         else if(sell_dominance && delta_ema[1] < 0.0) hold_score++;
         if(close1 < fast[1]) hold_score++;
         if(fast[1] < slow[1]) hold_score++;
         if(ma22_down) hold_score++;
         if(trading_tf_direction_hold) hold_score++;
         if(lower_high || breakout_retest_short) hold_score++;
         if(fresh_low_update) hold_score++;
         if(!failed_break_short && !strong_buy) hold_score++;
      }
      // Pattern learning only nudges the existing 0..10 evidence count.
      // It never creates direction by itself.
      if(lifecycle_pattern_support && hold_score > 0) hold_score++;
      if(lifecycle_fatigue && hold_score > 1) hold_score -= 2;
      hold_score = MathMax(0, MathMin(10, hold_score));
      g_hold_direction_score = hold_score;
      g_hold_strong_score = MathMax(0, MathMin(100, hold_score * 10));

      const bool macd_direction_ok = position_side > 0 ?
         (base_line[1] > -meaningful_zero_distance && !long_macd_failure) :
         (base_line[1] < meaningful_zero_distance && !short_macd_failure);
      const bool delta_direction_ok = position_side > 0 ?
         ((buy_dominance && !opposite_sell_confirmed) || lifecycle_absorption) :
         ((sell_dominance && !opposite_buy_confirmed) || lifecycle_absorption);
      const bool structure_direction_ok = position_side > 0 ?
         (close1 > fast[1] || fast[1] > slow[1] || ma22_up) :
         (close1 < fast[1] || fast[1] < slow[1] || ma22_down);

      // TREND-mode moving-average structure for holding decisions.
      // LONG/SHORT are evaluated symmetrically.
      const double ma7_slope_value = fast[1] - fast[2];
      const double ma22_slope_value = slow[1] - slow[2];
      const double ma70_slope_value = ma70[1] - ma70[2];
      const double ma_flat_tolerance = MathMax(_Point, average_range * 0.05);
      const double ma_approach_tolerance = MathMax(_Point * 2.0,
         average_range * 0.12);

      const bool ma7_rising = ma7_slope_value > ma_flat_tolerance;
      const bool ma7_falling = ma7_slope_value < -ma_flat_tolerance;
      const bool ma22_rising = ma22_slope_value > ma_flat_tolerance;
      const bool ma22_falling = ma22_slope_value < -ma_flat_tolerance;
      const bool ma70_rising = ma70_slope_value > ma_flat_tolerance;
      const bool ma70_falling = ma70_slope_value < -ma_flat_tolerance;
      const bool hold_ma22_flat = MathAbs(ma22_slope_value) <= ma_flat_tolerance;
      const bool hold_ma70_flat = MathAbs(ma70_slope_value) <= ma_flat_tolerance;

      const bool ma_strong_structure = position_side > 0 ?
         (fast[1] > slow[1] && slow[1] > ma70[1] &&
          ma7_rising && ma22_rising && ma70_rising) :
         (fast[1] < slow[1] && slow[1] < ma70[1] &&
          ma7_falling && ma22_falling && ma70_falling);
      const bool ma_normal_structure = position_side > 0 ?
         (fast[1] > slow[1] && !ma22_falling &&
          (ma70_rising || hold_ma70_flat)) :
         (fast[1] < slow[1] && !ma22_rising &&
          (ma70_falling || hold_ma70_flat));
      const bool ma7_ma22_approaching =
         MathAbs(fast[1] - slow[1]) <= ma_approach_tolerance;
      const bool ma7_ma22_crossed = position_side > 0 ?
         (fast[1] <= slow[1]) : (fast[1] >= slow[1]);
      const bool ma22_slope_reversed = position_side > 0 ?
         ma22_falling : ma22_rising;
      const bool ma70_breached = position_side > 0 ?
         (close1 < ma70[1]) : (close1 > ma70[1]);

      const bool common_strong_hold = position_side > 0 ?
         trend_strong_direction_long : trend_strong_direction_short;
      // v3.68: TREND "persistence" uses regional strength distribution.
      // Existing HoldEngine counters remain only as time confirmation after
      // the market-quality evidence has deteriorated.
      const int persistence_region=MathMin(8,ArraySize(raw)-1);
      double trend_delta_same=0.0,trend_delta_opp=0.0;
      double trend_macd_good_weight=0.0,trend_macd_total_weight=0.0;
      double trend_recent_same=0.0,trend_older_same=0.0;
      int trend_recent_n=0,trend_older_n=0;
      const int trend_split=MathMax(2,persistence_region/2);
      for(int hold_i=1;hold_i<=persistence_region;hold_i++)
      {
         const double signed_delta=position_side*raw[hold_i];
         if(signed_delta>=0.0) trend_delta_same+=signed_delta;
         else                  trend_delta_opp+=-signed_delta;

         const double weight=1.0/(double)hold_i;
         trend_macd_total_weight+=weight;
         if(position_side*(base_line[hold_i]-
            base_line[MathMin(persistence_region,hold_i+1)])>=0.0)
            trend_macd_good_weight+=weight;

         if(hold_i<=trend_split)
         {
            trend_recent_same+=MathMax(0.0,signed_delta);
            trend_recent_n++;
         }
         else
         {
            trend_older_same+=MathMax(0.0,signed_delta);
            trend_older_n++;
         }
      }
      const double trend_delta_total=trend_delta_same+trend_delta_opp;
      const double trend_delta_ratio=trend_delta_total>0.0?
         trend_delta_same/trend_delta_total:0.5;
      const double trend_macd_direction_ratio=trend_macd_total_weight>0.0?
         trend_macd_good_weight/trend_macd_total_weight:0.0;
      const double trend_recent_same_avg=trend_recent_same/MathMax(1,trend_recent_n);
      const double trend_older_same_avg=trend_older_same/MathMax(1,trend_older_n);

      const bool macd_same_side_expanding=
         position_side*base_line[1]>0.0 &&
         trend_macd_direction_ratio>=0.55;
      const bool delta_repeated_same_side=
         trend_delta_ratio>=0.60 &&
         (trend_older_same_avg<=0.0 ||
          trend_recent_same_avg>=trend_older_same_avg*0.70);
      const bool explicit_momentum_hold=
         macd_same_side_expanding&&delta_repeated_same_side&&
         structure_direction_ok&&!lifecycle_fatigue;
      const bool strong_trend_hold =
         ((hold_score >= InpStrongHoldMinimumScore && common_strong_hold &&
           macd_direction_ok && delta_direction_ok && structure_direction_ok &&
           ma_strong_structure && !lifecycle_fatigue) ||
          (explicit_momentum_hold && ma_normal_structure));

      // Five-level holding model.
      // WARNING is memory only; it does not close a position.  EXIT CANDIDATE
      // needs at least two failures among MACD, opposite delta and MA7 loss.
      const bool delta_declining=
         trend_older_same_avg>0.0 &&
         trend_recent_same_avg<trend_older_same_avg*0.65;
      const bool macd_slope_weak=
         trend_macd_direction_ratio<0.45 ||
         (position_side*base_line[1]>0.0 &&
          MathAbs(base_line[1])<
             MathMax(MathAbs(base_line[2]),MathAbs(base_line[3]))*0.65);
      const bool ma7_flat = MathAbs(ma7_slope_value) <= ma_flat_tolerance;
      const bool ma7_lost = position_side > 0 ? close1 < fast[1] : close1 > fast[1];
      const bool macd_opposite = position_side > 0 ?
         (trend_macd_strong_short || long_macd_failure) :
         (trend_macd_strong_long || short_macd_failure);
      const bool delta_opposite = position_side > 0 ?
         (trend_delta_strong_short || opposite_sell_confirmed) :
         (trend_delta_strong_long || opposite_buy_confirmed);
      int exit_failure_count = 0;
      if(macd_opposite) exit_failure_count++;
      if(delta_opposite) exit_failure_count++;
      if(ma7_lost) exit_failure_count++;
      if(ma7_ma22_crossed) exit_failure_count++;
      if(ma22_slope_reversed) exit_failure_count++;

      // A MA70 breach is a high-priority trend-break candidate. It does not
      // bypass confirmation by itself, but counts as two failures so the
      // existing EXIT CANDIDATE confirmation path reacts quickly.
      if(ma70_breached) exit_failure_count += 2;

      const bool exit_candidate_bar = exit_failure_count >= 2;
      const bool ma_warning = ma7_flat || hold_ma22_flat || ma7_ma22_approaching;
      const bool warning_bar = delta_declining || macd_slope_weak || ma_warning ||
         structure_stall || lifecycle_fatigue;
      const bool weak_hold_bar = !lifecycle_pattern_support &&
         (warning_bar || exit_candidate_bar);
      g_hold_weakness_score = MathMin(100,
         exit_failure_count * 20 +
         (delta_declining ? 10 : 0) +
         (macd_slope_weak ? 10 : 0) +
         (ma_warning ? 10 : 0) +
         (structure_stall ? 10 : 0) +
         (lifecycle_fatigue ? 10 : 0));

      // HoldEngine is the sole owner of HOLD state transitions. SignalEngine
      // only publishes the completed-bar evidence used by that state machine.
      HoldEngineApplyTrendState(position_side, strong_trend_hold,
         fresh_extreme_update, ma_normal_structure, weak_hold_bar, warning_bar,
         exit_candidate_bar, exit_failure_count, delta_declining,
         macd_slope_weak, ma_warning, close1);

      // A late CHASE entry is promoted to NORMAL trend management when the
      // current market proves that the move is a genuine directional trend.
      // After promotion, strong-hold giveback is disabled just like a normal
      // trend entry. If the trend later weakens, the existing hold-state
      // machine automatically returns the position to profit protection.
      if(InpEnableChaseTrendPromotion && g_entry_type == ENTRY_CHASE)
      {
         const bool promotion_m5_ok =
            !InpChasePromotionRequireTradingTF || trading_tf_direction_hold;
         const bool promotion_core_ok = position_side > 0 ?
            (trend_strong_direction_long && ma22_up &&
             (fast[1] > slow[1] || higher_low || breakout_retest_long)) :
            (trend_strong_direction_short && ma22_down &&
             (fast[1] < slow[1] || lower_high || breakout_retest_short));
         const bool promotion_bar_ok =
            hold_score >= InpChasePromotionMinimumScore &&
            promotion_core_ok && promotion_m5_ok && !weak_hold_bar;

         if(promotion_bar_ok)
            g_chase_promotion_bars++;
         else
            g_chase_promotion_bars = 0;

         if(g_chase_promotion_bars >= InpChasePromotionConfirmBars)
         {
            g_entry_type = ENTRY_NORMAL;
            g_entry_quality = hold_score >= 8 ? "A" : "B";
            g_chase_promoted = true;
            g_chase_promotion_bars = 0;
            g_status = StringFormat(
               "%s CHASE->TREND PROMOTED | HOLD SCORE %d",
               position_side > 0 ? "LONG" : "SHORT", hold_score);
            // v4.14: CHASE promotion remains a chart/status event only;
            // user SYS/MOB signal alerts are reserved for 3X/3X structure/Trigger.
         }
      }
      else if(g_entry_type != ENTRY_CHASE)
      {
         g_chase_promotion_bars = 0;
      }

      const bool sideways_hold =
         long_sideways_hold || short_sideways_hold ||
         shallow_long_zero_break || shallow_short_zero_break ||
         lifecycle_absorption || lifecycle_pullback ||
         strong_trend_hold ||
         (position_side > 0 && (higher_low || breakout_retest_long) && !failed_break_long) ||
         (position_side < 0 && (lower_high || breakout_retest_short) && !failed_break_short);

      // M2 entries should show progress quickly. Close only when the initial
      // move has stalled, same-side delta dominance is absent, MACD is not
      // expanding and price has lost the fast MA. Strong trends are untouched.
      const int bars_since_initial = BarsSinceInitialEntry();
      const bool early_failure_window =
         InpEarlyFailureCheckBars > 0 &&
         bars_since_initial >= InpEarlyFailureCheckBars &&
         bars_since_initial <= InpEarlyFailureCheckBars + 2;
      const bool same_side_dominance =
         position_side > 0 ? buy_dominance : sell_dominance;
      const bool same_side_macd_expanding =
         position_side > 0 ?
         ((base_line[1] > 0.0 && base_up) ||
          shallow_long_zero_break) :
         ((base_line[1] < 0.0 && base_down) ||
          shallow_short_zero_break);
      const bool fast_ma_lost =
         position_side > 0 ? close1 < fast[1] : close1 > fast[1];
      const bool early_failure =
         early_failure_window &&
         CurrentProgressR(position_side) <= InpEarlyFailureMaximumR &&
         !same_side_dominance && !same_side_macd_expanding && fast_ma_lost;
      const bool opposite_signal_confirmed = position_side > 0 ?
         opposite_sell_confirmed : opposite_buy_confirmed;
      int direction_support_count = 0;
      string direction_support_detail = "";
      const bool direction_hold_supported =
         PositionDirectionHoldSupported(position_side,
                                        direction_support_count,
                                        direction_support_detail);

      // Publish the completed-bar decision to HoldEngine/RiskEngine so no
      // RANGE profit/giveback path can bypass the canonical exit rule.
      g_position_opposite_signal_confirmed = opposite_signal_confirmed;
      g_position_direction_hold_supported = direction_hold_supported;

      const bool full_exit =
         position_side > 0 ?
         (long_macd_failure && long_ma22_failure &&
          opposite_sell_confirmed && sell_dominance) :
         (short_macd_failure && short_ma22_failure &&
          opposite_buy_confirmed && buy_dominance);
      if(ExitEngineEvaluateCompletedBarSignalExit(position_side,
                                                  early_failure,
                                                  direction_hold_supported,
                                                  direction_support_detail,
                                                  opposite_signal_confirmed,
                                                  fresh_extreme_update,
                                                  full_exit,
                                                  sideways_hold))
         return;

      const bool warning = g_hold_state == HOLD_WARNING ||
                           g_hold_state == HOLD_EXIT_CANDIDATE;
      if(warning)
      {
         g_long_exit_pending = position_side > 0;
         g_short_exit_pending = position_side < 0;
         if(g_hold_state == HOLD_EXIT_CANDIDATE)
            NotifyPositionState(StringFormat(
               "%s EXIT CANDIDATE: %d/3 FAILURE | WAIT OPPOSITE SIGNAL",
               position_side > 0 ? "LONG" : "SHORT", exit_failure_count));
         else
            NotifyPositionState(position_side > 0 ?
               "LONG WARNING: DELTA/MACD/MA7 OR HIGH-LOW STRUCTURE WEAKENING" :
               "SHORT WARNING: DELTA/MACD/MA7 OR LOW-HIGH STRUCTURE WEAKENING");
      }
      else
      {
         g_long_exit_pending = false;
         g_short_exit_pending = false;
         g_exit_opposite_close_bars = 0;
         if(g_hold_state == HOLD_STRONG)
            NotifyPositionState(StringFormat(
               "%s STRONG HOLD: MACD + DELTA + MA + STRUCTURE | SCORE %d%s",
               position_side > 0 ? "LONG" : "SHORT", hold_score,
               fresh_extreme_update ? " | NEW EXTREME" : ""));
         else if(g_hold_state == HOLD_PROFIT_PROTECT)
            NotifyPositionState(position_side > 0 ?
               "LONG PROFIT PROTECT: MOMENTUM WEAK FOR CONFIRMED BARS" :
               "SHORT PROFIT PROTECT: MOMENTUM WEAK FOR CONFIRMED BARS");
         else
            NotifyPositionState(position_side > 0 ?
               "LONG NORMAL HOLD: TREND ALIVE, TEMPORARY MOMENTUM WEAKNESS ALLOWED" :
               "SHORT NORMAL HOLD: TREND ALIVE, TEMPORARY MOMENTUM WEAKNESS ALLOWED");
      }

      const bool add_stage_two =
         g_additional_entry_filled_count == 0 &&
         (position_side > 0 ?
          (breakout_retest_long || pullback_continuation_long || long_retest) :
          (breakout_retest_short || pullback_continuation_short || short_retest));
      const bool add_stage_three =
         g_additional_entry_filled_count == 1 &&
         (position_side > 0 ?
          ((high_break || breakout_retest_long) && volume_expansion &&
           trend_strong_direction_long && !failed_break_long) :
          ((low_break || breakout_retest_short) && volume_expansion &&
           trend_strong_direction_short && !failed_break_short));
      const bool add_bias_ok =
         !InpRequireTrendBiasForAdds ||
         (position_side > 0 ? trend_state_long_bias : trend_state_short_bias);
      const bool add_pattern_ok =
         !InpPatternBlockAddsOnFatigue || !lifecycle_fatigue;
      const bool add_structure_ok =
         add_bias_ok && add_pattern_ok && (position_side > 0 ?
         (ma22_up && slow[1] > ma70[1] &&
          trend_strong_direction_long) :
         (ma22_down && slow[1] < ma70[1] &&
          trend_strong_direction_short && !protected_by_111));

      // A CHASE position cannot add until the promotion logic has converted
      // the entry type to ENTRY_NORMAL after confirmed same-side trend bars.
      const bool add_chase_promoted = (g_entry_type != ENTRY_CHASE);
      const int add_confidence =
         position_side > 0 ? long_confidence : short_confidence;
      const int opposite_add_confidence =
         position_side > 0 ? short_confidence : long_confidence;
      const bool add_confident =
         add_confidence >= InpMinimumEntryConfidence &&
         (!InpUseNoTradeZone ||
          add_confidence >= opposite_add_confidence +
                            InpMinimumConfidenceGap);
      const bool add_market_filter_ok =
         !no_trade_zone && add_confident;

      const datetime closed_auto_bar=iTime(_Symbol,g_calc_tf,1);
      EntryEngineEvaluateTrendAdditional(position_side,
                                         add_chase_promoted,
                                         add_pattern_ok,
                                         no_trade_zone,
                                         no_trade_flags,
                                         add_confident,
                                         add_confidence,
                                         opposite_add_confidence,
                                         add_market_filter_ok,
                                         add_structure_ok,
                                         add_stage_two,
                                         add_stage_three,
                                         oversized,
                                         closed_auto_bar,
                                         lifecycle_pattern_detail);
      return;
   }

   g_long_exit_pending = false;
   g_short_exit_pending = false;
   g_exit_opposite_close_bars = 0;
   g_last_position_state_alert = "";
   HoldEngineResetState();
   RiskEngineResetProfitProtectionState();
   if(!g_auto_trading || !IsCooldownComplete())
      return;

   // Re-entry requires both the configured cooldown and a fresh closed-bar
   // setup. This avoids immediate repeated entries in a choppy zero-line area.
   int bars_after_exit = 1000000;
   if(g_last_exit_bar_time > 0)
      bars_after_exit = iBarShift(_Symbol, AUTO_TF,
                                  g_last_exit_bar_time, false);
   const bool reentry_delay_ready =
      g_last_exit_bar_time <= 0 ||
      bars_after_exit > MathMax(g_exit_cooldown_bars,
                                InpReentryMinimumBars);

   UpdateAutoStartBiasWindow();
   const bool auto_start_long_ok = AutoStartBiasAllows(1,
      turn_long || high_break || compression_break_long || trend_micro_break_long,
      confirmed_long, 0);
   const bool auto_start_short_ok = AutoStartBiasAllows(-1,
      turn_short || low_break || compression_break_short || trend_micro_break_short,
      confirmed_short, 0);

   // AUTO DIR is deliberately independent from SIGNAL DIR.
   const bool auto_turn_long =
      !g_long_regime_traded && turn_long;
   const bool auto_turn_short =
      !g_short_regime_traded && turn_short;
   // Internal M15/M4/M2 state is one valid timing path, not a mandatory
   // dependency. Learned continuation/retest/breakout structures can authorize
   // AUTO directly when direction, confidence and safety gates agree.
   const bool strong_trend_restart_long =
      long_confident && !unsafe_long &&
      ma22_up && trend_strong_direction_long &&
      (trend_timing_long || pullback_continuation_long || breakout_retest_long ||
       trend_micro_break_long || high_break);
   const bool strong_trend_restart_short =
      short_confident && !unsafe_short &&
      ma22_down && trend_strong_direction_short &&
      (trend_timing_short || pullback_continuation_short || breakout_retest_short ||
       trend_micro_break_short || low_break);

   const bool trend_auto_state_long =
      !InpRequireInternalEntryStateForAuto || trend_state_allows_long ||
      strong_trend_restart_long;
   const bool trend_auto_state_short =
      !InpRequireInternalEntryStateForAuto || trend_state_allows_short ||
      strong_trend_restart_short;
   const bool trend_entry_trigger_long =
      auto_turn_long || compression_break_long || trend_timing_long ||
      pullback_continuation_long || breakout_retest_long ||
      strong_trend_restart_long ||
      (InpAllowContinuation && auto_reaccel_long);
   const bool trend_entry_trigger_short =
      auto_turn_short || compression_break_short || trend_timing_short ||
      pullback_continuation_short || breakout_retest_short ||
      strong_trend_restart_short ||
      (InpAllowContinuation && auto_reaccel_short);
   const bool trend_fresh_momentum_long =
      trend_strong_direction_long || trend_timing_long ||
      pullback_continuation_long || breakout_retest_long ||
      strong_trend_restart_long || early_long_setup;
   const bool trend_fresh_momentum_short =
      trend_strong_direction_short || trend_timing_short ||
      pullback_continuation_short || breakout_retest_short ||
      strong_trend_restart_short || early_short_setup;

   const bool regular_auto_long =
      reentry_delay_ready && trend_auto_state_long &&
      long_score >= InpEntryScore &&
      !no_trade_zone && !unsafe_long && trend_fresh_momentum_long &&
      trend_entry_trigger_long;
   const bool regular_auto_short =
      reentry_delay_ready && trend_auto_state_short &&
      short_score >= InpEntryScore &&
      !no_trade_zone && !unsafe_short && trend_fresh_momentum_short &&
      trend_entry_trigger_short;

   // v8.57: the historical TREND 3-signal sequence remains available only
   // as an observation/alert concept. It is no longer an INITIAL order path.
   // The user explicitly rejected that former entry method because it repeatedly
   // lost in sideways markets. M3 AUTO must not inherit it through SignalEngine.
   const int trend_signals_required = 3; // retained only for legacy observation/audit compatibility
   const bool trend_three_signal_long = false;
   const bool trend_three_signal_short = false;

   const bool trend_early_path_long =
      reentry_delay_ready && long_score >= InpEarlyEntryScore &&
      !no_trade_zone && !unsafe_long && early_long_setup;
   const bool trend_early_path_short =
      reentry_delay_ready && short_score >= InpEarlyEntryScore &&
      !no_trade_zone && !unsafe_short && early_short_setup;
   const bool trend_strategy_path_long =
      trend_three_signal_long || regular_auto_long || trend_early_path_long;
   const bool trend_strategy_path_short =
      trend_three_signal_short || regular_auto_short || trend_early_path_short;

   string trend_entry_block_long = "";
   string trend_entry_block_short = "";
   const bool auto_long = EntryEngineApproveTrendInitial(
      1,trend_strategy_path_long,trend_three_signal_long,auto_start_long_ok,
      AutoDirectionAllows(1),long_score,
      trend_three_signal_long ? "TREND_3_SIGNAL" : (regular_auto_long ? "TREND_REGULAR" : "TREND_EARLY"),
      trend_entry_block_long);
   const bool auto_short = EntryEngineApproveTrendInitial(
      -1,trend_strategy_path_short,trend_three_signal_short,auto_start_short_ok,
      AutoDirectionAllows(-1),short_score,
      trend_three_signal_short ? "TREND_3_SIGNAL" : (regular_auto_short ? "TREND_REGULAR" : "TREND_EARLY"),
      trend_entry_block_short);

   // Expose the actual AUTO gate when a strong directional structure exists
   // but no confirmed signal is produced. This is diagnostic only and does not alter orders.
   if(!auto_long && !auto_short && ManagedPositionSide() == 0)
   {
      if(strong_trend_restart_long || early_long_setup)
      {
         g_status = StringFormat(
            "TREND AUTO LONG WAIT | STATE %s SCORE %d CONF %d NTZ %s UNSAFE %s",
            trend_auto_state_long ? "OK" : "BLOCK", long_score, long_confidence,
            no_trade_zone ? "YES" : "NO", unsafe_long ? "YES" : "NO");
         if(trend_entry_block_long != "") g_status += " | " + trend_entry_block_long;
      }
      else if(strong_trend_restart_short || early_short_setup)
      {
         g_status = StringFormat(
            "TREND AUTO SHORT WAIT | STATE %s SCORE %d CONF %d NTZ %s UNSAFE %s",
            trend_auto_state_short ? "OK" : "BLOCK", short_score, short_confidence,
            no_trade_zone ? "YES" : "NO", unsafe_short ? "YES" : "NO");
         if(trend_entry_block_short != "") g_status += " | " + trend_entry_block_short;
      }
   }

   const bool both_mode = g_trade_direction == TRADE_BOTH;
   const bool long_wins =
      trend_three_signal_long || !both_mode || !auto_short ||
      long_score >= short_score + InpBothDirectionMinimumScoreGap;
   const bool short_wins =
      trend_three_signal_short || !both_mode || !auto_long ||
      short_score >= long_score + InpBothDirectionMinimumScoreGap;

   if(auto_long && long_wins)
   {
      const string reason = trend_three_signal_long ?
         "TREND 3-SIGNAL LONG" :
         ResolveTrendEntryReason(
            trend_timing_long, compression_break_long, auto_turn_long,
            !regular_auto_long, long_pattern);
      if(EntryEngineSubmitInitial(1, long_score, reason, close1, true))
      {
         // PositionManager owns successful-order signal-state reset.
      }
   }
   else if(auto_short && short_wins)
   {
      const string reason = trend_three_signal_short ?
         "TREND 3-SIGNAL SHORT" :
         ResolveTrendEntryReason(
            trend_timing_short, compression_break_short, auto_turn_short,
            !regular_auto_short, short_pattern);
      if(EntryEngineSubmitInitial(-1, short_score, reason, close1, true))
      {
         // PositionManager owns successful-order signal-state reset.
      }
   }
   else if(both_mode && auto_long && auto_short)
      g_status = "BOTH SIGNALS CONFLICT: WAIT FOR SCORE GAP";
   else if(!signal_long && !signal_short && !no_trade_zone &&
           (long_confident || short_confident))
      g_status = "WAITING FOR SIGNAL";
}

//+------------------------------------------------------------------+
// Closed-bar candle-pattern filter for a RANGE strategy.
// Patterns never trigger an order alone. They only confirm MACD + Delta or
// block entries that run directly into the opposite edge of the recent box.





// ===== Functions moved from Common.mqh during ownership audit =====
bool M2Reaccelerating(const int side,
                      const double &fast_ma[],
                      const double &slow_ma[])
{
   const double close1 = iClose(_Symbol, AUTO_TF, 1);
   const double close2 = iClose(_Symbol, AUTO_TF, 2);
   if(close1 <= 0.0 || close2 <= 0.0)
      return false;
   const bool trend =
      side > 0 ? fast_ma[1] > slow_ma[1] && fast_ma[1] > fast_ma[2]
               : fast_ma[1] < slow_ma[1] && fast_ma[1] < fast_ma[2];
   const bool price_acceleration =
      side > 0 ? close1 > fast_ma[1] && close1 > close2
               : close1 < fast_ma[1] && close1 < close2;
   return trend && price_acceleration &&
          HasConfirmedPullback(side, fast_ma, slow_ma);
}

//+------------------------------------------------------------------+
// v3.32 observation-only FINAL momentum publisher. It never changes FINAL
// score, 3X counters, candidates or AUTO order permission. Continuous same-
// direction momentum is announced once; after alignment disappears it may
// alert again when momentum is re-confirmed.
void ProcessConfirmedMomentumObservation(const int side,
                                         const bool aligned,
                                         const bool allow_output,
                                         const int final_score,
                                         const datetime bar_time,
                                         const double signal_price,
                                         const double signal_high,
                                         const double signal_low,
                                         const ENUM_TIMEFRAMES signal_tf,
                                         const string mode,
                                         const string macd_state,
                                         const string delta_state,
                                         const string price_state,
                                         const string higher_tf_state,
                                         const string detail)
{
   // v8.217: simple DIRECTION OFF->ON rearm lifecycle. Chart arrow and SYS/MOB
   // output stay disabled; a fresh OFF->ON event is published only to AUTO/CSV.
   bool active = side>0 ? g_confirmed_momentum_long_active
                        : g_confirmed_momentum_short_active;
   if(!aligned)
   {
      if(side>0) g_confirmed_momentum_long_active=false;
      else       g_confirmed_momentum_short_active=false;
      return;
   }
   if(!allow_output || active || bar_time<=0)
      return;

   datetime last_bar = side>0 ? g_last_confirmed_momentum_long_bar
                              : g_last_confirmed_momentum_short_bar;
   if(last_bar==bar_time) return;

   if(side>0)
   {
      g_confirmed_momentum_long_active=true;
      g_last_confirmed_momentum_long_bar=bar_time;
   }
   else
   {
      g_confirmed_momentum_short_active=true;
      g_last_confirmed_momentum_short_bar=bar_time;
   }

   g_internal_momentum_event_time=bar_time;
   g_internal_momentum_event_side=side;
   g_last_direction_event_high=signal_high;
   g_last_direction_event_low=signal_low;
   WriteUnifiedOrderSignalAudit(
      side>0 ? "DIRECTION_LONG" : "DIRECTION_SHORT",
      "","SIGNAL",side,0,0,"ADD_CANDIDATE",detail,false,false,0,0);
}

int BarsSinceMostRecentCross(const double &base_line[],
                             const int direction)
{
   for(int shift = 1; shift <= InpSignalValidBars; shift++)
   {
      if(direction > 0 &&
         base_line[shift] > 0.0 &&
         base_line[shift + 1] <= 0.0)
         return shift - 1;

      if(direction < 0 &&
         base_line[shift] < 0.0 &&
         base_line[shift + 1] >= 0.0)
         return shift - 1;
   }
   return -1;
}

bool HasConfirmedPullback(const int side,
                          const double &fast_ma[],
                          const double &slow_ma[])
{
   if(InpPullbackLookbackBars < 2)
      return false;

   const double tolerance = MathMax(0.0, InpPullbackTolerancePoints) * _Point;
   bool touched_fast_ma = false;
   bool momentum_paused = false;
   for(int shift = 2; shift <= InpPullbackLookbackBars + 1; shift++)
   {
      const double low = iLow(_Symbol, g_calc_tf, shift);
      const double high = iHigh(_Symbol, g_calc_tf, shift);
      const double close = iClose(_Symbol, g_calc_tf, shift);
      if(side > 0)
      {
         if(low <= fast_ma[shift] + tolerance)
            touched_fast_ma = true;
         if(close <= fast_ma[shift] || fast_ma[shift] <= fast_ma[shift + 1])
            momentum_paused = true;
      }
      else
      {
         if(high >= fast_ma[shift] - tolerance)
            touched_fast_ma = true;
         if(close >= fast_ma[shift] || fast_ma[shift] >= fast_ma[shift + 1])
            momentum_paused = true;
      }
   }

   const double closed_price = iClose(_Symbol, g_calc_tf, 1);
   const bool trend_ok =
      side > 0 ? (fast_ma[1] > slow_ma[1] && closed_price > fast_ma[1])
               : (fast_ma[1] < slow_ma[1] && closed_price < fast_ma[1]);

   // Relaxed RE-ACCEL: an MA touch or a brief momentum pause is sufficient.
   // Fast/slow MA slope agreement is already represented by MACD direction,
   // MA alignment and the close location in ProcessClosedBar().
   return trend_ok && (touched_fast_ma || momentum_paused);
}

bool HasExploratoryPullback(const int side,
                            const double &fast_ma[],
                            const double &slow_ma[])
{
   if(InpPullbackLookbackBars < 2)
      return false;

   const double tolerance = MathMax(0.0, InpPullbackTolerancePoints) * _Point;
   bool touched_fast_ma = false;
   bool momentum_paused = false;
   for(int shift = 2; shift <= InpPullbackLookbackBars + 1; shift++)
   {
      const double low = iLow(_Symbol, g_calc_tf, shift);
      const double high = iHigh(_Symbol, g_calc_tf, shift);
      const double close = iClose(_Symbol, g_calc_tf, shift);
      if(side > 0)
      {
         if(low <= fast_ma[shift] + tolerance)
            touched_fast_ma = true;
         if(close <= fast_ma[shift] || fast_ma[shift] <= fast_ma[shift + 1])
            momentum_paused = true;
      }
      else
      {
         if(high >= fast_ma[shift] - tolerance)
            touched_fast_ma = true;
         if(close >= fast_ma[shift] || fast_ma[shift] >= fast_ma[shift + 1])
            momentum_paused = true;
      }
   }

   const double closed_price = iClose(_Symbol, g_calc_tf, 1);
   const bool direction_ok =
      side > 0 ? (fast_ma[1] > slow_ma[1] && closed_price > fast_ma[1])
               : (fast_ma[1] < slow_ma[1] && closed_price < fast_ma[1]);

   // Alerts are exploratory: either an MA touch or a momentum pause is enough.
   return direction_ok && (touched_fast_ma || momentum_paused);
}

bool WeakeningForBars(const double &base_line[],
                      const int side)
{
   for(int i = 1; i <= LEGACY_WEAKENING_BARS; i++)
   {
      if(side > 0 && !(base_line[i] < base_line[i + 1]))
         return false;
      if(side < 0 && !(base_line[i] > base_line[i + 1]))
         return false;
   }
   return true;
}


//+------------------------------------------------------------------+
//+------------------------------------------------------------------+

// v3.00: MACD zero-line regime + recent Volume Delta dominance.
// MACD defines the directional regime; Delta confirms actual pressure.
// No new score engine/input is introduced: existing M1/M3 handles and
// InpMACDZeroBreakFactor are reused.






// Initial reversal evidence is intentionally separate from the strict NORMAL
// unchanged. Reversal support accepts improving momentum before full MA/MACD
// zero-line alignment, while still requiring price response and M3 recovery.








// Return: 0=HEALTHY/PASS, 1=WEAK/WAIT, 2=COLLAPSED/CANCEL.
// Uses live M1 shift-0 only after the original signal-bar breakout has occurred.

// rescored here. This gate only waits when the live breakout has insufficient
// current propulsion: weak/near-zero MACD activity together with weak Delta
// and weak price extension, or severe Candidate Delta collapse while absolute
// MACD activity is still low and price has barely extended beyond the signal
// bar. Candidate remains ACTIVE and may recover on a later tick.





//+------------------------------------------------------------------+
//| This is NOT a direction recheck. It blocks only when price, MACD |
//| and Delta activity are simultaneously dead at the actual         |
//| signal-bar breakout tick.                                       |
//+------------------------------------------------------------------+




//+------------------------------------------------------------------+
//| WATCH observation layer (integrated into SignalEngine, v3.11)   |
//+------------------------------------------------------------------+
// WATCH observation layer is owned by SignalEngine. It never modifies FINAL signals,
// 3-signal counters, AUTO state, entry approval, or position management.
// External WATCH stages are PREP2 -> PREP3 -> READY only.



// v5.73: Structural Trigger is an Accepted-FINAL-owned read-only alert/display subsystem.
// It never owns AUTO entry, 3X/FINAL counters, ADD state, cooldown, Hold/Risk/Exit,
// or any managed-position lifecycle state.  v5.59 Execution Trigger remains the
// sole AUTO Trigger reference; these variables are alert-only.
double   g_struct_long_trigger_price=0.0;
double   g_struct_short_trigger_price=0.0;
double   g_struct_long_trigger_base_price=0.0;
double   g_struct_short_trigger_base_price=0.0;
double   g_struct_long_trigger_buffer=0.0;
double   g_struct_short_trigger_buffer=0.0;
datetime g_struct_long_segment_start=0;
datetime g_struct_short_segment_start=0;
string   g_struct_long_trigger_source="";
string   g_struct_short_trigger_source="";
bool     g_struct_long_trigger_fired=false;
bool     g_struct_short_trigger_fired=false;
datetime g_struct_long_trigger_fire_time=0;
datetime g_struct_short_trigger_fire_time=0;
double   g_struct_long_trigger_fire_price=0.0;
double   g_struct_short_trigger_fire_price=0.0;
int      g_struct_long_score=0;
int      g_struct_short_score=0;

void StructuralResetSide(const int side);
bool FinalTriggerCopyData(const ENUM_STRATEGY_MODE strategy,
                          MqlRates &rates[],
                          double &macd[],
                          double &delta[],
                          double &dema[]);

void WatchSignalResetState()
{
   g_watch_long_stage=0;
   g_watch_short_stage=0;
   g_watch_user_long_stage=0;
   g_watch_user_short_stage=0;
   g_watch_last_long_alert_bar=0;
   g_watch_last_short_alert_bar=0;
   g_watch_snapshot.bar_time=0;
   g_watch_snapshot.long_score=0;
   g_watch_snapshot.short_score=0;
   g_watch_snapshot.long_stage=0;
   g_watch_snapshot.short_stage=0;
   g_watch_snapshot.long_reason="";
   g_watch_snapshot.short_reason="";
   g_watch_snapshot.dominant_side=0;
   g_watch_snapshot.delta_dominance=0;
   g_watch_snapshot.long_segment_start=0;
   g_watch_snapshot.short_segment_start=0;
   g_watch_snapshot.long_segment_start_price=0.0;
   g_watch_snapshot.short_segment_start_price=0.0;
   g_watch_snapshot.long_trigger_base_price=0.0;
   g_watch_snapshot.short_trigger_base_price=0.0;
   g_watch_snapshot.long_trigger_price=0.0;
   g_watch_snapshot.short_trigger_price=0.0;
   g_watch_snapshot.long_trigger_buffer=0.0;
   g_watch_snapshot.short_trigger_buffer=0.0;
   g_watch_snapshot.long_trigger_source="";
   g_watch_snapshot.short_trigger_source="";
   g_watch_snapshot.long_trigger_fired=false;
   g_watch_snapshot.short_trigger_fired=false;
   g_watch_snapshot.long_trigger_fire_time=0;
   g_watch_snapshot.short_trigger_fire_time=0;
   g_watch_snapshot.long_trigger_fire_price=0.0;
   g_watch_snapshot.short_trigger_fire_price=0.0;

   g_struct_long_trigger_price=0.0;
   g_struct_short_trigger_price=0.0;
   g_struct_long_trigger_base_price=0.0;
   g_struct_short_trigger_base_price=0.0;
   g_struct_long_trigger_buffer=0.0;
   g_struct_short_trigger_buffer=0.0;
   g_struct_long_segment_start=0;
   g_struct_short_segment_start=0;
   g_struct_long_trigger_source="";
   g_struct_short_trigger_source="";
   g_struct_long_trigger_fired=false;
   g_struct_short_trigger_fired=false;
   g_struct_long_trigger_fire_time=0;
   g_struct_short_trigger_fire_time=0;
   g_struct_long_trigger_fire_price=0.0;
   g_struct_short_trigger_fire_price=0.0;
   g_struct_long_score=0;
   g_struct_short_score=0;
   ObjectDelete(0,"JTA_WATCH_STRUCT_LONG_TRIGGER_LINE");
   ObjectDelete(0,"JTA_WATCH_STRUCT_LONG_TRIGGER_LABEL");
   ObjectDelete(0,"JTA_WATCH_STRUCT_SHORT_TRIGGER_LINE");
   ObjectDelete(0,"JTA_WATCH_STRUCT_SHORT_TRIGGER_LABEL");
   ObjectDelete(0,"JTA_WATCH_STRUCT_LONG_TRIGGER_PERSIST_LINE");
   ObjectDelete(0,"JTA_WATCH_STRUCT_LONG_TRIGGER_PERSIST_LABEL");
   ObjectDelete(0,"JTA_WATCH_STRUCT_SHORT_TRIGGER_PERSIST_LINE");
   ObjectDelete(0,"JTA_WATCH_STRUCT_SHORT_TRIGGER_PERSIST_LABEL");
   // v3.93: clear both legacy single-trigger objects and the new independent
   // LONG/SHORT trigger objects.
   ObjectDelete(0,"JTA_WATCH_TRIGGER_LINE");
   ObjectDelete(0,"JTA_WATCH_TRIGGER_LABEL");
   ObjectDelete(0,"JTA_WATCH_LONG_TRIGGER_LINE");
   ObjectDelete(0,"JTA_WATCH_LONG_TRIGGER_LABEL");
   ObjectDelete(0,"JTA_WATCH_SHORT_TRIGGER_LINE");
   ObjectDelete(0,"JTA_WATCH_SHORT_TRIGGER_LABEL");
   ObjectDelete(0,"JTA_WATCH_LONG_TRIGGER_PERSIST_LINE");
   ObjectDelete(0,"JTA_WATCH_LONG_TRIGGER_PERSIST_LABEL");
   ObjectDelete(0,"JTA_WATCH_SHORT_TRIGGER_PERSIST_LINE");
   ObjectDelete(0,"JTA_WATCH_SHORT_TRIGGER_PERSIST_LABEL");
   g_watch_snapshot.system_alert_fired=false;
   g_watch_snapshot.mobile_alert_fired=false;
}

string WatchTfName()
{
   string s=EnumToString(g_signal_tf);
   StringReplace(s,"PERIOD_","");
   return s;
}

int WatchScoreToStage(const int score)
{
   if(score>=InpWatchReadyScore) return 4;
   if(score>=InpWatchPrep3Score) return 3;
   if(score>=InpWatchPrep2Score) return 2;
   return 0;
}

string WatchStageKorean(const int side,const int stage)
{
   if(side>0)
   {
      if(stage>=4) return "상승 전환 강하게 의심";
      if(stage==3) return "상승 가능성 강화";
      if(stage==2) return "상승 가능성 감지";
      return "상승 가능성 관찰";
   }
   if(stage>=4) return "하락 전환 강하게 의심";
   if(stage==3) return "하락 가능성 강화";
   if(stage==2) return "하락 가능성 감지";
   return "하락 가능성 관찰";
}

string WatchStageCode(const int side,const int stage)
{
   if(stage<=0) return "NONE";
   const string p=side>0?"ACCUM_":"DIST_";
   if(stage==2) return p+"PREP_2";
   if(stage==3) return p+"PREP_3";
   return p+"READY";
}

double WatchSafeDiv(const double a,const double b)
{
   return MathAbs(b)>1e-12?a/b:0.0;
}

int WatchClamp(const int v,const int lo,const int hi)
{
   return (int)MathMax(lo,MathMin(hi,v));
}

int WatchRecentTurnAge(const double &v[],const bool long_side,const int max_age)
{
   const int n=MathMin(ArraySize(v)-2,max_age+2);
   if(n<2) return 99;
   for(int i=0;i<n;i++)
   {
      const double now=v[i]-v[i+1];
      const double prev=v[i+1]-v[i+2];
      if(long_side && now>0.0 && prev<=0.0) return i;
      if(!long_side && now<0.0 && prev>=0.0) return i;
   }
   return 99;
}

void WatchAppendReason(string &dst,const string token)
{
   if(token=="") return;
   if(dst!="") dst+="|";
   dst+=token;
}

void WatchDeleteAllObjects()
{
   const int total=ObjectsTotal(0,0,-1);
   for(int i=total-1;i>=0;i--)
   {
      const string name=ObjectName(0,i,0,-1);
      if(StringFind(name,"JTA_WATCH_")==0)
         ObjectDelete(0,name);
   }
}

void WatchDeleteOldObjects()
{
   // Visual Tester preserves full WATCH history; non-visual Tester creates no
   // WATCH objects. Only live charts use the bounded historical display.
   if((bool)MQLInfoInteger(MQL_TESTER))
      return;

   const int total=ObjectsTotal(0,0,-1);
   int kept=0;
   for(int i=total-1;i>=0;i--)
   {
      const string name=ObjectName(0,i,0,-1);
      if(StringFind(name,"JTA_WATCH_")!=0) continue;
      kept++;
      if(kept>300) ObjectDelete(0,name);
   }
}

void WatchDrawMarker(const int side,const int stage,const int score,const datetime t,const double price,const double offset)
{
   // v3.05: WATCH menu OFF means no WATCH chart marker and no WATCH alert.
   // Calculation/snapshot/CSV remain active for research and diagnostics.
   if(g_watch_mode==WATCH_MODE_OFF || !InpWatchShowChartMarkers || stage<2) return;
   g_watch_marker_drawn_this_bar=true;
   if((bool)MQLInfoInteger(MQL_TESTER) &&
      !(bool)MQLInfoInteger(MQL_VISUAL_MODE))
      return;
   const string name=StringFormat("JTA_WATCH_%s_%I64d",side>0?"UP":"DN",(long)t);
   const string score_name=name+"_SCORE";
   const double arrow_price=side>0?price-offset:price+offset;
   const double score_price=side>0?price-offset*1.75:price+offset*1.75;
   const color marker_color=side>0?clrDodgerBlue:clrTomato;
   const string tooltip=StringFormat("%s | 관찰강도 %d | %s",
                                     WatchStageKorean(side,stage),score,WatchTfName());

   // v3.26: WATCH uses a directional arrow plus numeric score.  WATCH remains
   // closer to the candle than FINAL so simultaneous signals stay separated.
   if(ObjectFind(0,name)>=0)
   {
      const ENUM_OBJECT existing_type=(ENUM_OBJECT)ObjectGetInteger(0,name,OBJPROP_TYPE);
      if(existing_type!=OBJ_ARROW)
         ObjectDelete(0,name);
   }
   if(ObjectFind(0,name)<0)
   {
      if(!ObjectCreate(0,name,OBJ_ARROW,0,t,arrow_price)) return;
      ObjectSetInteger(0,name,OBJPROP_ARROWCODE,side>0 ? 233 : 234);
      ObjectSetInteger(0,name,OBJPROP_WIDTH,1);
      ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);
      ObjectSetInteger(0,name,OBJPROP_HIDDEN,false);
      ObjectSetInteger(0,name,OBJPROP_BACK,false);
      ObjectSetInteger(0,name,OBJPROP_ANCHOR,side>0?ANCHOR_BOTTOM:ANCHOR_TOP);
   }
   ObjectMove(0,name,0,t,arrow_price);
   ObjectSetInteger(0,name,OBJPROP_COLOR,marker_color);
   ObjectSetString(0,name,OBJPROP_TOOLTIP,tooltip);

   // v8.33: SignalEngine reversal WATCH uses the same compact LONG WATCH /\n   // SHORT WATCH wording as requested, distinguished from StateEvaluation\n   // by directional text color: LONG green, SHORT red. Signal authority unchanged.
   const string label_name=name+"_LABEL";
   const string label_text=(side>0 ? "LONG WATCH" : "SHORT WATCH");
   const color label_color=(side>0 ? clrGreen : clrRed);
   const double label_price=side>0 ? price-offset*1.75 : price+offset*1.75;

   // Remove the old numeric score object; WATCH score remains in tooltip/CSV.
   ObjectDelete(0,score_name);

   if(ObjectFind(0,label_name)>=0)
   {
      const ENUM_OBJECT label_type=(ENUM_OBJECT)ObjectGetInteger(0,label_name,OBJPROP_TYPE);
      if(label_type!=OBJ_TEXT)
         ObjectDelete(0,label_name);
   }
   if(ObjectFind(0,label_name)<0)
   {
      if(ObjectCreate(0,label_name,OBJ_TEXT,0,t,label_price))
      {
         ObjectSetInteger(0,label_name,OBJPROP_FONTSIZE,9);
         ObjectSetInteger(0,label_name,OBJPROP_SELECTABLE,false);
         ObjectSetInteger(0,label_name,OBJPROP_HIDDEN,false);
         ObjectSetInteger(0,label_name,OBJPROP_BACK,false);
         ObjectSetInteger(0,label_name,OBJPROP_ANCHOR,side>0?ANCHOR_UPPER:ANCHOR_LOWER);
      }
   }
   if(ObjectFind(0,label_name)>=0)
   {
      ObjectMove(0,label_name,0,t,label_price);
      ObjectSetInteger(0,label_name,OBJPROP_COLOR,label_color);
      ObjectSetString(0,label_name,OBJPROP_TEXT,label_text);
      ObjectSetString(0,label_name,OBJPROP_TOOLTIP,tooltip);
   }
}

bool WatchCooldownPassed(const int side,const datetime bar_time)
{
   const datetime last=side>0?g_watch_last_long_alert_bar:g_watch_last_short_alert_bar;
   if(last<=0) return true;
   const int bars=iBarShift(_Symbol,g_signal_tf,last,false);
   if(bars<0) return true;
   return bars>=MathMax(1,InpWatchCooldownBars);
}

void WatchSendAlert(const int side,const int stage,const int score,const datetime bar_time,const bool bypass_cooldown=false)
{
   // v8.22: user-authorized WATCH is the primary reversal alert.
   // Keep delivery ownership here so chart marker, system alert and optional
   // mobile push all refer to the exact same authorized closed-bar event.
   if(side==0 || stage<2 || bar_time<=0)
      return;

   if(JTAWatchAlertAlreadyDelivered(side,bar_time,"SIGNAL_REVERSAL"))
      return;

   if(!bypass_cooldown && !WatchCooldownPassed(side,bar_time))
      return;

   const string direction=(side>0 ? "LONG" : "SHORT");
   const string meaning=(side>0 ? "상승 반전 가능성" : "하락 반전 가능성");
   const string tf=EnumToString(g_signal_tf);
   const string msg=StringFormat(
      "!!! [반전신호 %s] %s | %s | SCORE %d | %s",
      direction,_Symbol,meaning,score,tf);

   // Dedicated WATCH sound. 3X uses alert2.wav and structural break uses
   // news.wav, so reversal WATCH remains immediately distinguishable.
   if(g_terminal_alert && !(bool)MQLInfoInteger(MQL_TESTER))
      NotifyUserWithPcSound(msg,"expert.wav");
   else
      Print(msg);

   JTAWatchAlertMarkDelivered(side,bar_time,"SIGNAL_REVERSAL");
   if(side>0)
      g_watch_last_long_alert_bar=bar_time;
   else
      g_watch_last_short_alert_bar=bar_time;

   g_watch_snapshot.system_alert_fired=
      (g_terminal_alert && !(bool)MQLInfoInteger(MQL_TESTER));
   g_watch_snapshot.mobile_alert_fired=
      (g_watch_snapshot.system_alert_fired && g_mobile_alert);
}

bool WatchCopyData(MqlRates &rates[],double &macd[],double &delta[],double &dema[],
                   double &ma7[],double &ma22[],double &ma70[],double &ma111[])
{
   const int need=MathMax(24,
      MathMax(InpWatchRangeLookback+8,
      MathMax(InpWatchStructureLookback+3,InpWatchFreshBars+8)));
   ArrayResize(rates,need); ArraySetAsSeries(rates,true);
   ArrayResize(macd,need); ArraySetAsSeries(macd,true);
   ArrayResize(delta,need); ArraySetAsSeries(delta,true);
   ArrayResize(dema,need); ArraySetAsSeries(dema,true);
   ArrayResize(ma7,need); ArraySetAsSeries(ma7,true);
   ArrayResize(ma22,need); ArraySetAsSeries(ma22,true);
   ArrayResize(ma70,need); ArraySetAsSeries(ma70,true);
   ArrayResize(ma111,need); ArraySetAsSeries(ma111,true);

   const bool shared_snapshot=
      g_signal_tf==AUTO_TF &&
      g_signal_macd_handle==g_macd_handle &&
      g_signal_delta_handle==g_delta_handle &&
      g_signal_fast_ma_handle==g_add_ma_handle &&
      g_signal_slow_ma_handle==g_slow_ma_handle &&
      g_signal_ma70_handle==g_ma70_handle &&
      g_signal_ma111_handle==g_ma111_handle;

   // Caller arrays are shift-1 based; canonical snapshot is shift-0 based.
   if(shared_snapshot && EnsureMarketSnapshotRange(need+1))
   {
      if(ArrayCopy(rates,g_ms_rates,0,1,need)==need &&
         ArrayCopy(macd,g_ms_macd,0,1,need)==need &&
         ArrayCopy(delta,g_ms_delta,0,1,need)==need &&
         ArrayCopy(dema,g_ms_delta_ema,0,1,need)==need &&
         ArrayCopy(ma7,g_ms_fast_ma,0,1,need)==need &&
         ArrayCopy(ma22,g_ms_slow_ma,0,1,need)==need &&
         ArrayCopy(ma70,g_ms_ma70,0,1,need)==need &&
         ArrayCopy(ma111,g_ms_ma111,0,1,need)==need)
         return true;
   }

   if(MarketDataCopyRates(_Symbol,g_signal_tf,1,need,rates)<need) return false;
   if(MarketDataCopyBuffer(g_signal_macd_handle,JTC_MACD_BASE_BUFFER,1,need,macd)<need) return false;
   if(MarketDataCopyBuffer(g_signal_delta_handle,2,1,need,delta)<need) return false;
   if(MarketDataCopyBuffer(g_signal_delta_handle,3,1,need,dema)<need) return false;
   if(MarketDataCopyBuffer(g_signal_fast_ma_handle,0,1,need,ma7)<need) return false;
   if(MarketDataCopyBuffer(g_signal_slow_ma_handle,0,1,need,ma22)<need) return false;
   if(MarketDataCopyBuffer(g_signal_ma70_handle,0,1,need,ma70)<need) return false;
   if(MarketDataCopyBuffer(g_signal_ma111_handle,0,1,need,ma111)<need) return false;
   return true;
}

int WatchMacdRegime(const double &macd[],double &zero_zone)
{
   zero_zone=0.0;
   const int n=MathMin(8,ArraySize(macd)-2);
   if(n<3) return 0;
   double avg_abs=0.0;
   for(int i=1;i<=n;i++)
      avg_abs+=MathAbs(macd[i]);
   avg_abs/=n;
   zero_zone=MathMax(_Point,avg_abs*InpMACDZeroBreakFactor);
   if(macd[0]>zero_zone) return 1;
   if(macd[0]<-zero_zone) return -1;
   return 0;
}

int WatchDeltaDominance(const double &delta[],const double &dema[],
                        int &buy_bars,int &sell_bars,double &sum_delta)
{
   buy_bars=0; sell_bars=0; sum_delta=0.0;
   const int n=MathMin(3,MathMin(ArraySize(delta),ArraySize(dema)));
   for(int i=0;i<n;i++)
   {
      sum_delta+=delta[i];
      if(delta[i]>0.0 && dema[i]>0.0) buy_bars++;
      else if(delta[i]<0.0 && dema[i]<0.0) sell_bars++;
   }
   if(buy_bars>=2 && buy_bars>sell_bars && sum_delta>0.0) return 1;
   if(sell_bars>=2 && sell_bars>buy_bars && sum_delta<0.0) return -1;
   return 0;
}


int WatchFindObservationPivot(const int side,
                              MqlRates &r[],
                              const double &macd[],
                              const double &delta[],
                              const double &dema[],
                              const int macd_age,
                              const int delta_age,
                              const int dema_age)
{
   // v3.68: common WATCH observation segment. Timeframe/mode does not change
   // directional observation. We locate the price pivot nearest the most
   // recent internal turn and require price structure to participate.
   const int max_i=MathMin(10,ArraySize(r)-3);
   if(max_i<2) return -1;
   int turn_age=MathMin(macd_age,MathMin(delta_age,dema_age));
   if(turn_age<0 || turn_age>max_i) turn_age=0;

   int best=-1;
   double best_distance=DBL_MAX;
   for(int i=0;i<=max_i;i++)
   {
      const bool pivot_price=side>0 ?
         (r[i].low<=r[MathMin(max_i,i+1)].low &&
          r[i].low<=r[MathMax(0,i-1)].low) :
         (r[i].high>=r[MathMin(max_i,i+1)].high &&
          r[i].high>=r[MathMax(0,i-1)].high);

      const double rr=MathMax(_Point,r[i].high-r[i].low);
      const double lower_wick=MathMin(r[i].open,r[i].close)-r[i].low;
      const double upper_wick=r[i].high-MathMax(r[i].open,r[i].close);
      const bool rejection=side>0 ?
         lower_wick/rr>=0.25 : upper_wick/rr>=0.25;

      bool internal_turn=false;
      if(i+2<ArraySize(macd))
      {
         const double m_now=macd[i]-macd[i+1];
         const double m_prev=macd[i+1]-macd[i+2];
         const double d_now=delta[i]-delta[i+1];
         const double d_prev=delta[i+1]-delta[i+2];
         const double e_now=dema[i]-dema[i+1];
         const double e_prev=dema[i+1]-dema[i+2];
         internal_turn=side>0 ?
            ((m_now>0.0&&m_prev<=0.0)||(d_now>0.0&&d_prev<=0.0)||(e_now>0.0&&e_prev<=0.0)) :
            ((m_now<0.0&&m_prev>=0.0)||(d_now<0.0&&d_prev>=0.0)||(e_now<0.0&&e_prev>=0.0));
      }

      // Price structure must be present. Internal turn may be at the same bar
      // or close to the recent turn age already detected by WATCH.
      if(!(pivot_price||rejection)) continue;
      const double distance=MathAbs((double)i-(double)turn_age);
      if(internal_turn) 
      {
         if(distance<best_distance){best=i;best_distance=distance;}
      }
      else if(distance<=2.0 && best<0)
      {
         best=i; best_distance=distance+0.5;
      }
   }
   return best;
}

double WatchTriggerCandidate(const int side,
                             const ENUM_STRATEGY_MODE strategy,
                             MqlRates &r[],
                             const int pivot_index,
                             const int macd_age,
                             const int delta_age,
                             const int dema_age,
                             string &source)
{
   source="";
   if(pivot_index<0 || ArraySize(r)<3) return 0.0;

   const int max_i=MathMin(pivot_index,ArraySize(r)-1);
   int window_end=max_i;

   double candidate=side>0 ? -DBL_MAX : DBL_MAX;
   int candidate_i=-1;
   for(int i=0;i<=window_end;i++)
   {
      const double p=side>0?r[i].high:r[i].low;
      if((side>0 && p>candidate)||(side<0 && p<candidate))
      {
         candidate=p; candidate_i=i;
      }
   }

   // Internal-turn candles are valid structural candidates. For RANGE/TREND
   // accepts nearby turn candles so the trigger is not excessively distant.
   int ages[3]={macd_age,delta_age,dema_age};
   string names[3]={"MACD_TURN","DELTA_TURN","DEMA_TURN"};
   for(int k=0;k<3;k++)
   {
      const int a=ages[k];
      if(a<0 || a>max_i) continue;
      const double p=side>0?r[a].high:r[a].low;
      if((side>0 && p>candidate)||(side<0 && p<candidate))
      {
         candidate=p; candidate_i=a; source=names[k];
      }
   }

   if(source=="")
   {
      if(strategy==STRATEGY_RANGE) source="RANGE_SWING_PIVOT";
      else source="TREND_PULLBACK_PIVOT";
   }
   if(candidate_i<0 || candidate==DBL_MAX || candidate==-DBL_MAX) return 0.0;
   return candidate;
}

// v4.00: WATCH signal/stage logic remains on its existing calculation TF,
// but the displayed/alerted Trigger price is anchored to a COMPLETED M5 candle.
// This deliberately separates fast observation from a more stable structural
// breakout reference.  No AUTO/order authority is added.
//
// The reference is the completed M5 bar nearest the WATCH observation segment.
// If the WATCH segment belongs to the still-forming M5 bar, the latest fully
// completed M5 bar is used. LONG uses that M5 High; SHORT uses that M5 Low.
// Trigger buffer and refresh-distance normalization also use recent completed
// M5 average range so the line does not inherit M1/M2 micro-noise.
bool WatchM5TriggerReference(const ENUM_STRATEGY_MODE strategy,
                             const int side,
                             const datetime watch_segment_time,
                             double &base_price,
                             datetime &m5_reference_time,
                             double &m5_reference_price,
                             double &m5_avg_range,
                             string &source)
{
   base_price=0.0;
   m5_reference_time=0;
   m5_reference_price=0.0;
   m5_avg_range=0.0;
   source="";

   if(side==0 || watch_segment_time<=0)
      return false;

   // v6.45: Execution Trigger now uses the same structural meaning as the
   // visible Structural Trigger: a confirmed/respected completed-M5 swing,
   // not an arbitrary completed M5 High/Low.
   const int max_search=36;
   MqlRates m5[];
   ArrayResize(m5,max_search);
   ArraySetAsSeries(m5,true);
   const int copied=MarketDataCopyRates(_Symbol,PERIOD_M5,1,max_search,m5);
   if(copied<5)
      return false;

   double range_sum=0.0;
   int range_n=0;
   for(int i=0;i<copied;i++)
   {
      const double rr=m5[i].high-m5[i].low;
      if(rr>0.0)
      {
         range_sum+=rr;
         range_n++;
      }
   }
   if(range_n<=0)
      return false;

   m5_avg_range=MathMax(_Point,range_sum/(double)range_n);
   const double buffer=MathMax(
      _Point,m5_avg_range*MathMax(0.0,InpWatchTriggerBufferRange));

   MqlTick tick;
   if(!SymbolInfoTick(_Symbol,tick) || tick.bid<=0.0)
      return false;
   const double current_bid=tick.bid;

   const double min_trigger_distance=MathMax(
      _Point,m5_avg_range*JTATriggerMinDistanceRangeForStrategy(strategy));

   int ref=-1;
   double best_price_distance=DBL_MAX;
   datetime best_reference_time=0;

   for(int i=1;i<copied-1;i++)
   {
      // Confirmed completed-M5 pivot.
      const bool confirmed=side>0 ?
         (m5[i].high>m5[i-1].high && m5[i].high>=m5[i+1].high) :
         (m5[i].low<m5[i-1].low && m5[i].low<=m5[i+1].low);
      if(!confirmed)
         continue;

      // The structure must still be respected by all later completed M5 closes.
      bool respected=true;
      for(int j=0;j<i;j++)
      {
         if(side>0 && m5[j].close>m5[i].high)
         {
            respected=false;
            break;
         }
         if(side<0 && m5[j].close<m5[i].low)
         {
            respected=false;
            break;
         }
      }
      if(!respected)
         continue;

      const double candidate=NormalizePrice(
         side>0 ? m5[i].high+buffer : m5[i].low-buffer);

      const bool ahead=side>0 ? candidate>current_bid : candidate<current_bid;
      if(!ahead)
         continue;

      const double price_distance=MathAbs(candidate-current_bid);
      if(price_distance<min_trigger_distance)
         continue;

      // Nearest valid structure ahead of market is authoritative; if tied,
      // prefer the newer completed-M5 structural reference.
      const double distance_eps=MathMax(_Point*0.5,1e-12);
      if(ref<0 ||
         price_distance<best_price_distance-distance_eps ||
         (MathAbs(price_distance-best_price_distance)<=distance_eps &&
          m5[i].time>best_reference_time))
      {
         ref=i;
         best_price_distance=price_distance;
         best_reference_time=m5[i].time;
      }
   }

   if(ref<0)
      return false;

   m5_reference_time=m5[ref].time;
   m5_reference_price=side>0 ? m5[ref].low : m5[ref].high;
   base_price=side>0 ? m5[ref].high : m5[ref].low;
   source=StringFormat("%s_%s_CONFIRMED_M5_STRUCTURE",
      "RANGE",
      side>0?"SWING_HIGH":"SWING_LOW");
   return base_price>0.0;
}

string WatchTriggerLineName(const int side)
{
   return side>0 ? "JTA_WATCH_LONG_TRIGGER_LINE" :
                   "JTA_WATCH_SHORT_TRIGGER_LINE";
}

string WatchTriggerLabelName(const int side)
{
   return side>0 ? "JTA_WATCH_LONG_TRIGGER_LABEL" :
                   "JTA_WATCH_SHORT_TRIGGER_LABEL";
}

string WatchPersistTriggerLineName(const int side)
{
   return side>0 ? "JTA_WATCH_LONG_TRIGGER_PERSIST_LINE" :
                   "JTA_WATCH_SHORT_TRIGGER_PERSIST_LINE";
}

string WatchPersistTriggerLabelName(const int side)
{
   return side>0 ? "JTA_WATCH_LONG_TRIGGER_PERSIST_LABEL" :
                   "JTA_WATCH_SHORT_TRIGGER_PERSIST_LABEL";
}

void WatchDeleteTriggerObjects(const int side=0)
{
   // Remove old pre-v3.93 single-trigger objects as migration cleanup.
   ObjectDelete(0,"JTA_WATCH_TRIGGER_LINE");
   ObjectDelete(0,"JTA_WATCH_TRIGGER_LABEL");

   if(side>=0)
   {
      ObjectDelete(0,WatchTriggerLineName(1));
      ObjectDelete(0,WatchTriggerLabelName(1));
   }
   if(side<=0)
   {
      ObjectDelete(0,WatchTriggerLineName(-1));
      ObjectDelete(0,WatchTriggerLabelName(-1));
   }
}

void WatchDeletePersistedTriggerObjects(const int side=0)
{
   // Remove old pre-v3.93 persisted objects as migration cleanup.
   ObjectDelete(0,"JTA_WATCH_TRIGGER_PERSIST_LINE");
   ObjectDelete(0,"JTA_WATCH_TRIGGER_PERSIST_LABEL");

   if(side>=0)
   {
      ObjectDelete(0,WatchPersistTriggerLineName(1));
      ObjectDelete(0,WatchPersistTriggerLabelName(1));
   }
   if(side<=0)
   {
      ObjectDelete(0,WatchPersistTriggerLineName(-1));
      ObjectDelete(0,WatchPersistTriggerLabelName(-1));
   }
}

// Reset only the live/active Trigger snapshot for one WATCH direction.
// The last fired persisted chart line is deliberately untouched here.
void WatchResetActiveTriggerSide(const int side)
{
   if(side>0)
   {
      g_watch_snapshot.long_segment_start=0;
      g_watch_snapshot.long_segment_start_price=0.0;
      g_watch_snapshot.long_trigger_base_price=0.0;
      g_watch_snapshot.long_trigger_price=0.0;
      g_watch_snapshot.long_trigger_buffer=0.0;
      g_watch_snapshot.long_trigger_source="";
      g_watch_snapshot.long_trigger_fired=false;
      g_watch_snapshot.long_trigger_fire_time=0;
      g_watch_snapshot.long_trigger_fire_price=0.0;
   }
   else if(side<0)
   {
      g_watch_snapshot.short_segment_start=0;
      g_watch_snapshot.short_segment_start_price=0.0;
      g_watch_snapshot.short_trigger_base_price=0.0;
      g_watch_snapshot.short_trigger_price=0.0;
      g_watch_snapshot.short_trigger_buffer=0.0;
      g_watch_snapshot.short_trigger_source="";
      g_watch_snapshot.short_trigger_fired=false;
      g_watch_snapshot.short_trigger_fire_time=0;
      g_watch_snapshot.short_trigger_fire_price=0.0;
   }

}

// Preserve exactly the latest fired WATCH Trigger on chart. It has no signal
// or order authority and is replaced only when a new valid Segment is armed.
void WatchPersistFiredTrigger(const int side,
                              const datetime segment_start,
                              const double trigger_price,
                              const int score)
{
   // v5.72: v5.59 Execution Trigger is AUTO-only.
   // Structural Trigger owns the user-visible line and breakout alert.
   return;
}


void WatchDrawTrigger(const int side,
                      const datetime segment_start,
                      const double trigger_price,
                      const int score)
{
   // v5.72: keep v5.59 Execution Trigger state/order authority intact but hidden.
   return;
}




string StructuralTriggerLineName(const int side)
{
   return side>0 ? "JTA_WATCH_STRUCT_LONG_TRIGGER_LINE" :
                   "JTA_WATCH_STRUCT_SHORT_TRIGGER_LINE";
}

string StructuralTriggerLabelName(const int side)
{
   return side>0 ? "JTA_WATCH_STRUCT_LONG_TRIGGER_LABEL" :
                   "JTA_WATCH_STRUCT_SHORT_TRIGGER_LABEL";
}

string StructuralPersistLineName(const int side)
{
   return side>0 ? "JTA_WATCH_STRUCT_LONG_TRIGGER_PERSIST_LINE" :
                   "JTA_WATCH_STRUCT_SHORT_TRIGGER_PERSIST_LINE";
}

string StructuralPersistLabelName(const int side)
{
   return side>0 ? "JTA_WATCH_STRUCT_LONG_TRIGGER_PERSIST_LABEL" :
                   "JTA_WATCH_STRUCT_SHORT_TRIGGER_PERSIST_LABEL";
}

void StructuralDeleteLiveObjects(const int side=0)
{
   if(side>=0)
   {
      ObjectDelete(0,StructuralTriggerLineName(1));
      ObjectDelete(0,StructuralTriggerLabelName(1));
   }
   if(side<=0)
   {
      ObjectDelete(0,StructuralTriggerLineName(-1));
      ObjectDelete(0,StructuralTriggerLabelName(-1));
   }
}

void StructuralDeletePersistedObjects(const int side=0)
{
   if(side>=0)
   {
      ObjectDelete(0,StructuralPersistLineName(1));
      ObjectDelete(0,StructuralPersistLabelName(1));
   }
   if(side<=0)
   {
      ObjectDelete(0,StructuralPersistLineName(-1));
      ObjectDelete(0,StructuralPersistLabelName(-1));
   }
}

void StructuralResetSide(const int side)
{
   if(side>0)
   {
      g_struct_long_trigger_price=0.0;
      g_struct_long_trigger_base_price=0.0;
      g_struct_long_trigger_buffer=0.0;
      g_struct_long_segment_start=0;
      g_struct_long_trigger_source="";
      g_struct_long_trigger_fired=false;
      g_struct_long_trigger_fire_time=0;
      g_struct_long_trigger_fire_price=0.0;
      g_struct_long_score=0;
   }
   else if(side<0)
   {
      g_struct_short_trigger_price=0.0;
      g_struct_short_trigger_base_price=0.0;
      g_struct_short_trigger_buffer=0.0;
      g_struct_short_segment_start=0;
      g_struct_short_trigger_source="";
      g_struct_short_trigger_fired=false;
      g_struct_short_trigger_fire_time=0;
      g_struct_short_trigger_fire_price=0.0;
      g_struct_short_score=0;
   }
   StructuralDeleteLiveObjects(side);
}

bool StructuralActiveAheadOfMarket(const int side,const double trigger);

void StructuralDrawTrigger(const int side,const datetime segment_start,
                           const double trigger_price,const int score)
{
   if(!InpWatchShowTriggerLine || !InpWatchUseTriggerPrice ||
      side==0 || segment_start<=0 || trigger_price<=0.0)
   {
      StructuralDeleteLiveObjects(side);
      return;
   }

   // v5.97 visual invariant: ACTIVE SHORT < Bid < ACTIVE LONG.
   // PAST/reference objects are exempt because they intentionally preserve
   // historical structure and carry no alert/order authority.
   if(!StructuralActiveAheadOfMarket(side,trigger_price))
   {
      StructuralDeleteLiveObjects(side);
      return;
   }

   const string line=StructuralTriggerLineName(side);
   const string label=StructuralTriggerLabelName(side);
   const int tf_sec=MathMax(60,PeriodSeconds(g_signal_tf));
   const datetime label_time=TimeCurrent()+tf_sec*3;
   const color c=side>0?clrDodgerBlue:clrTomato;

   if(ObjectFind(0,line)<0)
   {
      if(!ObjectCreate(0,line,OBJ_HLINE,0,0,trigger_price)) return;
      ObjectSetInteger(0,line,OBJPROP_SELECTABLE,false);
      ObjectSetInteger(0,line,OBJPROP_HIDDEN,false);
      ObjectSetInteger(0,line,OBJPROP_BACK,false);
      ObjectSetInteger(0,line,OBJPROP_WIDTH,2);
      ObjectSetInteger(0,line,OBJPROP_STYLE,STYLE_SOLID);
   }
   ObjectSetDouble(0,line,OBJPROP_PRICE,trigger_price);
   ObjectSetInteger(0,line,OBJPROP_COLOR,c);

   const string text=StringFormat("%s STRUCT TRIGGER  %s  (%d)",
      side>0?"LONG":"SHORT",DoubleToString(trigger_price,_Digits),score);
   if(ObjectFind(0,label)<0)
   {
      if(!ObjectCreate(0,label,OBJ_TEXT,0,label_time,trigger_price)) return;
      ObjectSetInteger(0,label,OBJPROP_SELECTABLE,false);
      ObjectSetInteger(0,label,OBJPROP_HIDDEN,false);
      ObjectSetInteger(0,label,OBJPROP_FONTSIZE,8);
      ObjectSetString(0,label,OBJPROP_FONT,"Arial Bold");
      ObjectSetInteger(0,label,OBJPROP_ANCHOR,ANCHOR_LEFT);
   }
   ObjectMove(0,label,0,label_time,trigger_price);
   ObjectSetString(0,label,OBJPROP_TEXT,text);
   ObjectSetInteger(0,label,OBJPROP_COLOR,c);

   const string tip=StringFormat("%s M5 구조 Trigger %s | SCORE %d | Ref %s",
      side>0?"롱":"숏",DoubleToString(trigger_price,_Digits),score,
      TimeToString(segment_start,TIME_DATE|TIME_MINUTES));
   ObjectSetString(0,line,OBJPROP_TOOLTIP,tip);
   ObjectSetString(0,label,OBJPROP_TOOLTIP,tip);
}

void StructuralPersistFired(const int side,const double trigger_price,const int score)
{
   if(!InpWatchShowTriggerLine || side==0 || trigger_price<=0.0) return;
   StructuralDeletePersistedObjects(side);
   const string line=StructuralPersistLineName(side);
   const string label=StructuralPersistLabelName(side);
   const datetime fire_time=TimeCurrent();
   const color c=side>0?clrDodgerBlue:clrTomato;
   if(ObjectCreate(0,line,OBJ_HLINE,0,0,trigger_price))
   {
      ObjectSetInteger(0,line,OBJPROP_SELECTABLE,false);
      ObjectSetInteger(0,line,OBJPROP_HIDDEN,false);
      ObjectSetInteger(0,line,OBJPROP_WIDTH,1);
      ObjectSetInteger(0,line,OBJPROP_STYLE,STYLE_DOT);
      ObjectSetInteger(0,line,OBJPROP_COLOR,c);
      ObjectSetString(0,line,OBJPROP_TOOLTIP,
         StringFormat("%s TF 이전 구조가격 %s | SCORE %d",
            side>0?"롱":"숏",DoubleToString(trigger_price,_Digits),score));
   }
   if(ObjectCreate(0,label,OBJ_TEXT,0,fire_time,trigger_price))
   {
      ObjectSetInteger(0,label,OBJPROP_SELECTABLE,false);
      ObjectSetInteger(0,label,OBJPROP_HIDDEN,false);
      ObjectSetInteger(0,label,OBJPROP_FONTSIZE,8);
      ObjectSetString(0,label,OBJPROP_FONT,"Arial Bold");
      ObjectSetInteger(0,label,OBJPROP_ANCHOR,ANCHOR_LEFT);
      ObjectSetInteger(0,label,OBJPROP_COLOR,c);
      ObjectSetString(0,label,OBJPROP_TEXT,
         StringFormat("%s PAST TRIGGER %s (%d)",
            side>0?"LONG":"SHORT",DoubleToString(trigger_price,_Digits),score));
   }
}

// v5.71 confirmed/respected completed-M5 swing algorithm, isolated for alert use.
bool StructuralM5TriggerReference(const ENUM_STRATEGY_MODE strategy,
                                  const int side,
                                  const datetime watch_segment_time,
                                  double &base_price,
                                  datetime &m5_reference_time,
                                  double &m5_reference_price,
                                  double &m5_avg_range,
                                  string &source)
{
   base_price=0.0; m5_reference_time=0; m5_reference_price=0.0;
   m5_avg_range=0.0; source="";
   if(side==0 || watch_segment_time<=0) return false;

   const int max_search=36;
   MqlRates m5[];
   ArrayResize(m5,max_search); ArraySetAsSeries(m5,true);
   const int copied=MarketDataCopyRates(_Symbol,PERIOD_M5,1,max_search,m5);
   if(copied<5) return false;

   double range_sum=0.0;
   for(int i=0;i<copied;i++) range_sum+=MathMax(0.0,m5[i].high-m5[i].low);
   m5_avg_range=(copied>0 ? range_sum/(double)copied : 0.0);
   if(m5_avg_range<=0.0) return false;

   MqlTick tick;
   if(!SymbolInfoTick(_Symbol,tick) || tick.bid<=0.0) return false;
   const double current_bid=tick.bid;
   const double buffer=MathMax(_Point,m5_avg_range*MathMax(0.0,InpWatchTriggerBufferRange));
   const double min_trigger_distance=MathMax(
      _Point,m5_avg_range*JTATriggerMinDistanceRangeForStrategy(strategy));

   int ref=-1;
   double best_price_distance=DBL_MAX;
   datetime best_reference_time=0;
   for(int i=1;i<copied-1;i++)
   {
      bool confirmed=false;
      if(side>0)
         confirmed=(m5[i].high>m5[i-1].high && m5[i].high>=m5[i+1].high);
      else
         confirmed=(m5[i].low<m5[i-1].low && m5[i].low<=m5[i+1].low);
      if(!confirmed) continue;

      bool respected=true;
      for(int j=0;j<i;j++)
      {
         if(side>0 && m5[j].close>m5[i].high){ respected=false; break; }
         if(side<0 && m5[j].close<m5[i].low){ respected=false; break; }
      }
      if(!respected) continue;

      const double candidate=NormalizePrice(side>0?m5[i].high+buffer:m5[i].low-buffer);
      const bool ahead=side>0?candidate>current_bid:candidate<current_bid;
      if(!ahead) continue;
      const double price_distance=MathAbs(candidate-current_bid);
      if(price_distance<min_trigger_distance) continue;

      // v6.13: the visible CURRENT Structural Trigger represents the nearest
      // valid completed-M5 breakout structure ahead of the live market.
      // Do not prefer a structure merely because its timestamp is closer to
      // the observation anchor; that can leave CURRENT pinned to a distant
      // historical outer level after market structure has migrated.
      // Price distance is authoritative.  If two candidates are effectively
      // equidistant, prefer the more recent completed-M5 reference.
      const double distance_eps=MathMax(_Point*0.5,1e-12);
      if(ref<0 || price_distance < best_price_distance-distance_eps ||
         (MathAbs(price_distance-best_price_distance)<=distance_eps &&
          m5[i].time>best_reference_time))
      {
         ref=i;
         best_price_distance=price_distance;
         best_reference_time=m5[i].time;
      }
   }
   if(ref<0) return false;

   m5_reference_time=m5[ref].time;
   m5_reference_price=side>0?m5[ref].low:m5[ref].high;
   base_price=side>0?m5[ref].high:m5[ref].low;
   source=StringFormat("%s_%s_CONFIRMED_M5_STRUCTURE",
      "RANGE",
      side>0?"SWING_HIGH":"SWING_LOW");
   return base_price>0.0;
}

bool StructuralActiveAheadOfMarket(const int side,const double trigger)
{
   if(side==0 || trigger<=0.0)
      return false;
   MqlTick tick;
   if(!SymbolInfoTick(_Symbol,tick) || tick.bid<=0.0)
      return false;
   return side>0 ? trigger>tick.bid : trigger<tick.bid;
}

void StructuralRetireActiveToPast(const int side)
{
   if(side==0)
      return;

   const double trigger=side>0 ?
      g_struct_long_trigger_price : g_struct_short_trigger_price;
   const int score=side>0 ? g_struct_long_score : g_struct_short_score;

   if(trigger>0.0)
      StructuralPersistFired(side,trigger,score); // one PAST per side; replaces older PAST

   StructuralDeleteLiveObjects(side);

   if(side>0)
   {
      g_struct_long_trigger_price=0.0;
      g_struct_long_trigger_base_price=0.0;
      g_struct_long_trigger_buffer=0.0;
      g_struct_long_segment_start=0;
      g_struct_long_trigger_source="";
      g_struct_long_trigger_fired=false;
      g_struct_long_trigger_fire_time=0;
      g_struct_long_trigger_fire_price=0.0;
      g_struct_long_score=0;
   }
   else
   {
      g_struct_short_trigger_price=0.0;
      g_struct_short_trigger_base_price=0.0;
      g_struct_short_trigger_buffer=0.0;
      g_struct_short_segment_start=0;
      g_struct_short_trigger_source="";
      g_struct_short_trigger_fired=false;
      g_struct_short_trigger_fire_time=0;
      g_struct_short_trigger_fire_price=0.0;
      g_struct_short_score=0;
   }
}

void StructuralApplyCandidate(const ENUM_STRATEGY_MODE strategy,const int side,
                              const datetime observation_segment,const int score,
                              const string owner)
{
   if(side==0 || observation_segment<=0 || !InpWatchUseTriggerPrice) return;
   double active=side>0?g_struct_long_trigger_price:g_struct_short_trigger_price;
   bool fired=side>0?g_struct_long_trigger_fired:g_struct_short_trigger_fired;
   datetime stored=side>0?g_struct_long_segment_start:g_struct_short_segment_start;

   // v5.97: CURRENT ACTIVE is validated before replacement search.
   // A passed/fired ACTIVE immediately becomes the single dotted PAST
   // reference. If no valid completed-M5 replacement exists, ACTIVE remains
   // empty rather than retaining a stale level on the wrong side of Bid.
   if(active>0.0 && (!StructuralActiveAheadOfMarket(side,active) || fired))
   {
      StructuralRetireActiveToPast(side);
      active=0.0;
      fired=false;
      stored=0;
   }

   double base=0.0,ref_price=0.0,avg_range=0.0;
   datetime ref_time=0; string source="";
   if(!StructuralM5TriggerReference(strategy,side,observation_segment,
         base,ref_time,ref_price,avg_range,source)) return;

   const double buffer=MathMax(_Point,avg_range*MathMax(0.0,InpWatchTriggerBufferRange));
   const double trigger=NormalizePrice(side>0?base+buffer:base-buffer);

   const bool should_arm=(active<=0.0);
   bool should_refresh=false;
   if(active>0.0)
   {
      // v6.14: once an Accepted-FINAL refresh event has selected the nearest
      // valid completed-M5 structure ahead of current Bid, CURRENT must use
      // that nearest valid level.  Do not keep an older ACTIVE merely because
      // the price difference is smaller than the former avg-range/buffer
      // refresh threshold.  Candidate validity/minimum market distance is
      // still enforced inside StructuralM5TriggerReference().
      const double price_eps=MathMax(_Point*0.5,1e-12);
      should_refresh=(MathAbs(trigger-active)>price_eps);
   }
   if(!should_arm && !should_refresh){ StructuralDrawTrigger(side,stored,active,score); return; }

   StructuralDeleteLiveObjects(side);
   if(side>0)
   {
      g_struct_long_trigger_price=trigger; g_struct_long_trigger_base_price=base;
      g_struct_long_trigger_buffer=buffer; g_struct_long_segment_start=ref_time;
      g_struct_long_trigger_source=source; g_struct_long_trigger_fired=false;
      g_struct_long_trigger_fire_time=0; g_struct_long_trigger_fire_price=0.0;
      g_struct_long_score=score;
   }
   else
   {
      g_struct_short_trigger_price=trigger; g_struct_short_trigger_base_price=base;
      g_struct_short_trigger_buffer=buffer; g_struct_short_segment_start=ref_time;
      g_struct_short_trigger_source=source; g_struct_short_trigger_fired=false;
      g_struct_short_trigger_fire_time=0; g_struct_short_trigger_fire_price=0.0;
      g_struct_short_score=score;
   }

   WriteUnifiedOrderSignalAudit(
      "STRUCT_TRIGGER_LIFECYCLE","","OBSERVE",side,0,score,
      should_refresh?"STRUCT_TRIGGER_REFRESH":"STRUCT_TRIGGER_ARM",
      StringFormat("OWNER=%s | OLD=%s | NEW=%s | M5_REF=%s | SOURCE=%s",
         owner,active>0.0?DoubleToString(active,_Digits):"NONE",
         DoubleToString(trigger,_Digits),TimeToString(ref_time,TIME_DATE|TIME_MINUTES),source),
      false,false,0,g_trade_cycle.position_id);
   StructuralDrawTrigger(side,ref_time,trigger,score);
}

void StructuralUpdateFromAcceptedFinal(const ENUM_STRATEGY_MODE strategy,
                                       const int accepted_side,
                                       const datetime final_bar,
                                       const int final_score)
{
   if(accepted_side==0 || final_bar<=0 || !g_signal_enabled ||
      !InpWatchUseTriggerPrice)
      return;

   MqlRates r[];
   double macd[],delta[],dema[];
   if(!FinalTriggerCopyData(strategy,r,macd,delta,dema))
      return;

   // v5.97 (v5.97 base): one Accepted FINAL is the refresh event for the
   // VISIBLE Structural Trigger map as well. Recalculate LONG and SHORT
   // independently so valid completed-M5 breakout levels can coexist above
   // and below current price. This layer remains display/alert-only and never
   // receives order, FINAL counter, 3X, ADD, Hold, Risk or Exit authority.
   const int fresh=MathMax(1,InpWatchFreshBars);

   for(int pass=0; pass<2; pass++)
   {
      const int side=(pass==0 ? 1 : -1);
      const int ma=WatchRecentTurnAge(macd,side>0,fresh+3);
      const int da=WatchRecentTurnAge(delta,side>0,fresh+3);
      const int ea=WatchRecentTurnAge(dema,side>0,fresh+3);
      const int pivot=WatchFindObservationPivot(
         side,r,macd,delta,dema,ma,da,ea);

      // v5.97: visible bilateral Structural Trigger fallback only.
      // If this side has no WATCH observation pivot, do not abandon the side.
      // Use the Accepted FINAL bar as the observation anchor and let the
      // existing completed-M5 structural reference finder decide whether a
      // valid LONG/SHORT Trigger exists. No execution/order authority changes.
      const datetime observation_anchor=
         (pivot>=0 ? r[pivot].time : final_bar);

      // The Accepted-FINAL side carries its actual FINAL score. The opposite
      // visible side keeps its own latest structural/watch score; score never
      // grants Structural Trigger order authority.
      int score=0;
      if(side==accepted_side)
         score=final_score;
      else if(side>0)
         score=MathMax(g_struct_long_score,
                       MathMax(0,g_watch_snapshot.long_score));
      else
         score=MathMax(g_struct_short_score,
                       MathMax(0,g_watch_snapshot.short_score));

      StructuralApplyCandidate(
         strategy,side,observation_anchor,score,
         side==accepted_side ?
            (pivot>=0 ?
               "ACCEPTED_FINAL_BILATERAL_VISIBLE_MAP" :
               "ACCEPTED_FINAL_BILATERAL_VISIBLE_FALLBACK") :
            (pivot>=0 ?
               "ACCEPTED_FINAL_BILATERAL_OPPOSITE_MAP" :
               "ACCEPTED_FINAL_BILATERAL_OPPOSITE_FALLBACK"));
   }
}

void StructuralApplyCandidate(const ENUM_STRATEGY_MODE strategy,const int side,
                              const datetime observation_segment,const int score,
                              const string owner);

void StructuralCheckSideTick(const int side,const double px)
{
   if(side==0 || px<=0.0) return;
   const double trigger=side>0?g_struct_long_trigger_price:g_struct_short_trigger_price;
   if(trigger<=0.0) return;
   const bool fired=side>0?g_struct_long_trigger_fired:g_struct_short_trigger_fired;
   if(fired) return;
   const bool crossed=side>0?px>=trigger:px<=trigger;
   if(!crossed) return;

   const int score=side>0?g_struct_long_score:g_struct_short_score;
   const string source=side>0?g_struct_long_trigger_source:g_struct_short_trigger_source;
   if(side>0)
   {
      g_struct_long_trigger_fired=true; g_struct_long_trigger_fire_time=TimeCurrent();
      g_struct_long_trigger_fire_price=px;
   }
   else
   {
      g_struct_short_trigger_fired=true; g_struct_short_trigger_fire_time=TimeCurrent();
      g_struct_short_trigger_fire_price=px;
   }
   StructuralRetireActiveToPast(side);
   StructuralDeleteLiveObjects(side);

   const string msg=StringFormat("[%s M5 구조돌파] %s | 구조가격 %s | SCORE %d",
      side>0?"롱":"숏",_Symbol,DoubleToString(trigger,_Digits),score);
   if(g_terminal_alert && !(bool)MQLInfoInteger(MQL_TESTER))
      NotifyUserWithPcSound(msg,"news.wav");

   WriteUnifiedOrderSignalAudit(
      "STRUCT_TRIGGER","","SIGNAL",side,0,score,"STRUCT_TRIGGER_FIRED",
      StringFormat("TRIGGER=%s | FIRE=%s | SOURCE=%s | ORDER_AUTHORITY=NO",
         DoubleToString(trigger,_Digits),DoubleToString(px,_Digits),source),
      false,false,0,g_trade_cycle.position_id);

   // v5.97: the fired price is now only PAST/reference. Immediately search
   // completed-M5 structure for the next ACTIVE on this same side so the live
   // map does not remain empty until another Accepted FINAL arrives.
   StructuralApplyCandidate(
      g_selected_strategy,side,TimeCurrent(),score,
      "POST_BREAK_RECALC");

   // Deliberately NO order state, FINAL/3X state, cooldown or position mutation.
}

bool FinalTriggerCopyData(const ENUM_STRATEGY_MODE strategy,
                          MqlRates &rates[],
                          double &macd[],
                          double &delta[],
                          double &dema[])
{
   const ENUM_TIMEFRAMES tf=g_calc_tf;
   const int macd_handle=g_calc_macd_handle;
   const int delta_handle=g_calc_delta_handle;
   if(macd_handle==INVALID_HANDLE || delta_handle==INVALID_HANDLE)
      return false;

   const int need=MathMax(14,InpWatchFreshBars+8);
   ArrayResize(rates,need); ArraySetAsSeries(rates,true);
   ArrayResize(macd,need);  ArraySetAsSeries(macd,true);
   ArrayResize(delta,need); ArraySetAsSeries(delta,true);
   ArrayResize(dema,need);  ArraySetAsSeries(dema,true);

   const bool shared_snapshot=
      strategy==STRATEGY_RANGE &&
      tf==AUTO_TF &&
      macd_handle==g_macd_handle &&
      delta_handle==g_delta_handle;

   if(shared_snapshot && EnsureMarketSnapshotCommon(need+1))
   {
      if(ArrayCopy(rates,g_ms_rates,0,1,need)==need &&
         ArrayCopy(macd,g_ms_macd,0,1,need)==need &&
         ArrayCopy(delta,g_ms_delta,0,1,need)==need &&
         ArrayCopy(dema,g_ms_delta_ema,0,1,need)==need)
         return true;
   }

   if(MarketDataCopyRates(_Symbol,tf,1,need,rates)<need) return false;
   if(MarketDataCopyBuffer(macd_handle,JTC_MACD_BASE_BUFFER,1,need,macd)<need)
      return false;
   if(MarketDataCopyBuffer(delta_handle,2,1,need,delta)<need)
      return false;
   if(MarketDataCopyBuffer(delta_handle,3,1,need,dema)<need)
      return false;
   return true;
}

// v4.62: Accepted FINAL is the refresh event for the two-sided Trigger map.
// Trigger levels use completed-M5 structure and must remain ahead of current Bid.
// v4.83 Trigger keeps chart/alert authority and may also arm the selectable RANGE 1/2/3-FINAL INITIAL path.
void FinalTriggerUpdateOneSideFromAcceptedFinal(const ENUM_STRATEGY_MODE strategy,
                                                const int side,
                                                const datetime final_bar,
                                                const int final_score)
{
   if(side==0 || final_bar<=0 || !g_signal_enabled || !InpWatchUseTriggerPrice)
      return;

   MqlRates r[];
   double macd[],delta[],dema[];
   if(!FinalTriggerCopyData(strategy,r,macd,delta,dema))
      return;

   const int fresh=MathMax(1,InpWatchFreshBars);
   const int macd_age=WatchRecentTurnAge(macd,side>0,fresh+3);
   const int delta_age=WatchRecentTurnAge(delta,side>0,fresh+3);
   const int dema_age=WatchRecentTurnAge(dema,side>0,fresh+3);

   // Preserve the old WATCH structural-pivot logic. FINAL does not itself
   // become the Trigger price.
   const int pivot=WatchFindObservationPivot(
      side,r,macd,delta,dema,macd_age,delta_age,dema_age);
   if(pivot<0)
      return;

   const datetime observation_segment=r[pivot].time;
   double base=0.0,m5_ref_price=0.0,m5_avg_range=0.0;
   datetime m5_ref_time=0;
   string source="";
   if(!WatchM5TriggerReference(
         strategy,side,observation_segment,base,m5_ref_time,m5_ref_price,
         m5_avg_range,source))
      return;

   const double buffer=MathMax(
      _Point,m5_avg_range*MathMax(0.0,InpWatchTriggerBufferRange));
   const double trigger=NormalizePrice(side>0 ? base+buffer : base-buffer);

   const double active_trigger=
      side>0 ? g_watch_snapshot.long_trigger_price :
               g_watch_snapshot.short_trigger_price;
   const bool already_fired=
      side>0 ? g_watch_snapshot.long_trigger_fired :
               g_watch_snapshot.short_trigger_fired;
   const datetime stored_segment=
      side>0 ? g_watch_snapshot.long_segment_start :
               g_watch_snapshot.short_segment_start;

   // One fired Trigger is immutable for the current directional FINAL episode.
   // Episode reset clears the live side and permits a fresh Trigger later.
   if(active_trigger>0.0 && already_fired)
   {
      WatchDrawTrigger(side,stored_segment,active_trigger,final_score);
      return;
   }

   bool should_arm=(active_trigger<=0.0);
   bool should_refresh=false;
   if(active_trigger>0.0)
   {
      const bool newer_segment=(m5_ref_time>stored_segment);
      const double min_refresh_distance=MathMax(
         _Point,MathMax(m5_avg_range*0.10,buffer*2.0));
      const bool meaningful_change=
         MathAbs(trigger-active_trigger)>=min_refresh_distance;
      should_refresh=newer_segment && meaningful_change;
   }

   if(!should_arm && !should_refresh)
   {
      WatchDrawTrigger(side,stored_segment,active_trigger,final_score);
      return;
   }

   WatchDeleteTriggerObjects(side);
   if(side>0)
   {
      g_watch_snapshot.long_score=final_score;
      g_watch_snapshot.long_segment_start=m5_ref_time;
      g_watch_snapshot.long_segment_start_price=m5_ref_price;
      g_watch_snapshot.long_trigger_base_price=base;
      g_watch_snapshot.long_trigger_buffer=buffer;
      g_watch_snapshot.long_trigger_price=trigger;
      g_watch_snapshot.long_trigger_source=source;
      g_watch_snapshot.long_trigger_fired=false;
      g_watch_snapshot.long_trigger_fire_time=0;
      g_watch_snapshot.long_trigger_fire_price=0.0;
   }
   else
   {
      g_watch_snapshot.short_score=final_score;
      g_watch_snapshot.short_segment_start=m5_ref_time;
      g_watch_snapshot.short_segment_start_price=m5_ref_price;
      g_watch_snapshot.short_trigger_base_price=base;
      g_watch_snapshot.short_trigger_buffer=buffer;
      g_watch_snapshot.short_trigger_price=trigger;
      g_watch_snapshot.short_trigger_source=source;
      g_watch_snapshot.short_trigger_fired=false;
      g_watch_snapshot.short_trigger_fire_time=0;
      g_watch_snapshot.short_trigger_fire_price=0.0;
   }

   const string lifecycle=should_refresh ? "FINAL_TRIGGER_REFRESH" :
                                           "FINAL_TRIGGER_ARM";
   WriteUnifiedOrderSignalAudit(
      "FINAL_TRIGGER_LIFECYCLE",
      TimeToString(final_bar,TIME_DATE|TIME_MINUTES),
      "SIGNAL",side,0,final_score,lifecycle,
      StringFormat(
         "OLD=%s | NEW=%s | M5_REF=%s | SOURCE=%s",
         active_trigger>0.0?DoubleToString(active_trigger,_Digits):"NONE",
         DoubleToString(trigger,_Digits),
         TimeToString(m5_ref_time,TIME_DATE|TIME_MINUTES),source),
      false,false,0,g_trade_cycle.position_id);

   WatchDrawTrigger(side,m5_ref_time,trigger,final_score);
}


void FinalTriggerUpdateFromAcceptedFinal(const ENUM_STRATEGY_MODE strategy,
                                         const int accepted_side,
                                         const datetime final_bar,
                                         const int final_score)
{
   if(accepted_side==0 || final_bar<=0 || !g_signal_enabled ||
      !InpWatchUseTriggerPrice)
      return;

   // v4.62: one accepted FINAL is the refresh event for the visible Trigger
   // map. Recalculate BOTH independent sides from current Bid so the chart can
   // show the nearest valid completed-M5 breakout above and below price at once.
   const int long_score=(accepted_side>0 ? final_score :
                         MathMax(0,g_watch_snapshot.long_score));
   const int short_score=(accepted_side<0 ? final_score :
                          MathMax(0,g_watch_snapshot.short_score));

   FinalTriggerUpdateOneSideFromAcceptedFinal(
      strategy,1,final_bar,long_score);
   FinalTriggerUpdateOneSideFromAcceptedFinal(
      strategy,-1,final_bar,short_score);

   // v5.72 alert-only structural layer. It never changes execution state.
   StructuralUpdateFromAcceptedFinal(strategy,accepted_side,final_bar,final_score);
}

void WatchUpdateTriggerState(const int dominant_side,
                             const int long_stage,
                             const int short_stage,
                             const int long_score,
                             const int short_score,
                             const int delta_dominance,
                             MqlRates &r[],
                             const double &macd[],
                             const double &delta[],
                             const double &dema[],
                             const double avg_range,
                             const int macd_age_l,
                             const int macd_age_s,
                             const int delta_age_l,
                             const int delta_age_s,
                             const int dema_age_l,
                             const int dema_age_s)
{
   g_watch_snapshot.dominant_side=dominant_side;
   g_watch_snapshot.delta_dominance=delta_dominance;

   if(!InpWatchUseTriggerPrice)
   {
      WatchResetActiveTriggerSide(1);
      WatchResetActiveTriggerSide(-1);
      StructuralResetSide(1);
      StructuralResetSide(-1);
      WatchDeleteTriggerObjects();
      return;
   }

   // v3.95: LONG and SHORT Trigger lifecycles remain independent.
   // New behavior: an ARMED but NOT-FIRED Trigger may refresh only when a
   // genuinely newer observation pivot/segment is confirmed for the same side.
   // We do NOT move the trigger every bar.  The new pivot must be newer than
   // the stored segment start and the resulting trigger must differ by a
   // meaningful minimum distance.  Fired/persisted triggers never move.
   for(int pass=0; pass<2; pass++)
   {
      const int side=(pass==0 ? 1 : -1);
      const int stage=side>0 ? long_stage : short_stage;
      const int score=side>0 ? long_score : short_score;

      const double active_trigger=
         side>0 ? g_watch_snapshot.long_trigger_price :
                  g_watch_snapshot.short_trigger_price;
      const bool already_fired=
         side>0 ? g_watch_snapshot.long_trigger_fired :
                  g_watch_snapshot.short_trigger_fired;
      const datetime stored_segment=
         side>0 ? g_watch_snapshot.long_segment_start :
                  g_watch_snapshot.short_segment_start;

      // Existing armed side retires only when its own WATCH score truly resets.
      if(active_trigger>0.0 && score<InpWatchResetScore)
      {
         WatchResetActiveTriggerSide(side);
         WatchDeleteTriggerObjects(side);
         continue;
      }

      // A new or refreshed Trigger still requires this side's normal PREP2+.
      if(stage<2)
      {
         if(active_trigger<=0.0)
            WatchDeleteTriggerObjects(side);
         else
            WatchDrawTrigger(side,stored_segment,active_trigger,score);
         continue;
      }

      const int ma=side>0?macd_age_l:macd_age_s;
      const int da=side>0?delta_age_l:delta_age_s;
      const int ea=side>0?dema_age_l:dema_age_s;
      const int pivot=WatchFindObservationPivot(side,r,macd,delta,dema,ma,da,ea);

      // If no new valid pivot can be identified, keep the existing armed level.
      if(pivot<0)
      {
         if(active_trigger>0.0)
            WatchDrawTrigger(side,stored_segment,active_trigger,score);
         continue;
      }

      // v4.00: WATCH observation pivot still decides WHEN a Trigger may be
      // armed/refreshed, but the actual breakout level is now anchored to a
      // completed M5 candle.  This keeps fast WATCH sensitivity while making
      // the visible Trigger/alert price a higher-timeframe structure level.
      const datetime watch_seg_time=r[pivot].time;
      double base=0.0;
      datetime seg_time=0;
      double seg_price=0.0;
      double trigger_avg_range=0.0;
      string source="";
      if(!WatchM5TriggerReference(
            g_selected_strategy,side,watch_seg_time,base,seg_time,seg_price,
            trigger_avg_range,source))
      {
         if(active_trigger>0.0)
            WatchDrawTrigger(side,stored_segment,active_trigger,score);
         continue;
      }

      const double buffer=MathMax(
         _Point,trigger_avg_range*MathMax(0.0,InpWatchTriggerBufferRange));
      const double trigger=NormalizePrice(
         side>0 ? base+buffer : base-buffer);

      // Already fired Trigger is immutable. Keep its persisted record and do not
      // re-arm or chase price with a new candidate on the same side.
      if(active_trigger>0.0 && already_fired)
      {
         WatchDrawTrigger(side,stored_segment,active_trigger,score);
         continue;
      }

      bool should_arm=(active_trigger<=0.0);
      bool should_refresh=false;

      if(active_trigger>0.0 && !already_fired)
      {
         // Refresh only for a genuinely newer segment/pivot.
         const bool newer_segment=(seg_time>stored_segment);

         // Ignore trivial price changes. Require at least 10% of the recent
         // average range or 2 trigger buffers, whichever is larger.
         const double min_refresh_distance=MathMax(
            _Point,
            MathMax(trigger_avg_range*0.10,buffer*2.0));
         const bool meaningful_change=
            MathAbs(trigger-active_trigger)>=min_refresh_distance;

         // The new level must still be logically ahead of current WATCH
         // structure.  We only replace when both freshness and distance hold.
         should_refresh=newer_segment && meaningful_change;
      }

      if(!should_arm && !should_refresh)
      {
         WatchDrawTrigger(side,stored_segment,active_trigger,score);
         continue;
      }

      // Replacing an un-fired active level should not delete the opposite side
      // nor any already-fired opposite persisted line.  For the same side,
      // clear only old live objects before drawing the refreshed level.
      WatchDeleteTriggerObjects(side);

      if(side>0)
      {
         g_watch_snapshot.long_segment_start=seg_time;
         g_watch_snapshot.long_segment_start_price=seg_price;
         g_watch_snapshot.long_trigger_base_price=base;
         g_watch_snapshot.long_trigger_buffer=buffer;
         g_watch_snapshot.long_trigger_price=trigger;
         g_watch_snapshot.long_trigger_source=source;
         g_watch_snapshot.long_trigger_fired=false;
         g_watch_snapshot.long_trigger_fire_time=0;
         g_watch_snapshot.long_trigger_fire_price=0.0;
      }
      else
      {
         g_watch_snapshot.short_segment_start=seg_time;
         g_watch_snapshot.short_segment_start_price=seg_price;
         g_watch_snapshot.short_trigger_base_price=base;
         g_watch_snapshot.short_trigger_buffer=buffer;
         g_watch_snapshot.short_trigger_price=trigger;
         g_watch_snapshot.short_trigger_source=source;
         g_watch_snapshot.short_trigger_fired=false;
         g_watch_snapshot.short_trigger_fire_time=0;
         g_watch_snapshot.short_trigger_fire_price=0.0;
      }

      const string lifecycle=should_refresh ? "TRIGGER_REFRESH" : "TRIGGER_ARM";
      WriteUnifiedOrderSignalAudit(
         "WATCH_TRIGGER_LIFECYCLE","",
         "OBSERVE",side,0,0,lifecycle,
         StringFormat(
            "OLD=%s | NEW=%s | M5_REF=%s | SCORE=%d | SOURCE=%s",
            active_trigger>0.0?DoubleToString(active_trigger,_Digits):"NONE",
            DoubleToString(trigger,_Digits),
            TimeToString(seg_time,TIME_DATE|TIME_MINUTES),
            score,source),
         false,false,0,0);

      WatchDrawTrigger(side,seg_time,trigger,score);
   }
}

void WatchCheckTriggerSideTick(const int side,const double px)
{
   if(side==0 || px<=0.0) return;

   const double trigger=side>0?g_watch_snapshot.long_trigger_price:
                                  g_watch_snapshot.short_trigger_price;
   if(trigger<=0.0) return;

   const bool already=side>0?g_watch_snapshot.long_trigger_fired:
                              g_watch_snapshot.short_trigger_fired;
   if(already) return;

   // v3.93: once a Trigger has been armed, its crossing is independent of the
   // currently dominant WATCH direction. Bid remains the chart/alert basis for
   // both sides, preserving the v3.80 displayed-line/crossing consistency.
   const bool crossed=side>0?px>=trigger:px<=trigger;
   if(!crossed) return;

   if(side>0)
   {
      g_watch_snapshot.long_trigger_fired=true;
      g_watch_snapshot.long_trigger_fire_time=TimeCurrent();
      g_watch_snapshot.long_trigger_fire_price=px;
   }
   else
   {
      g_watch_snapshot.short_trigger_fired=true;
      g_watch_snapshot.short_trigger_fire_time=TimeCurrent();
      g_watch_snapshot.short_trigger_fire_price=px;
   }

   const int score=side>0?g_watch_snapshot.long_score:
                            g_watch_snapshot.short_score;
   WatchPersistFiredTrigger(
      side,
      side>0?g_watch_snapshot.long_segment_start:
             g_watch_snapshot.short_segment_start,
      trigger,score);

   // v5.72: Execution Trigger no longer emits the user Trigger-break alert.
   // If it causes an AUTO order, the existing order-fill alert still fires.
   g_watch_snapshot.system_alert_fired=false;
   g_watch_snapshot.mobile_alert_fired=false;

   WriteUnifiedOrderSignalAudit(
      "FINAL_TRIGGER","","SIGNAL",side,0,0,
      "TRIGGER_FIRED",
      StringFormat("TRIGGER=%s | FIRE=%s | SCORE=%d | SOURCE=%s",
         DoubleToString(trigger,_Digits),DoubleToString(px,_Digits),score,
         side>0?g_watch_snapshot.long_trigger_source:
                g_watch_snapshot.short_trigger_source),
      false,false,0,0);

   // v7.88: Trigger order path is available again, but remains OFF by default
   // because InpAutoEntryPath defaults to AUTO_ENTRY_NORMAL_ONLY. Trigger and
   // normal FIRST->first REPEAT are independent selectable INITIAL paths.
   if(InpAutoEntryPath!=AUTO_ENTRY_NORMAL_ONLY &&
      g_selected_strategy==STRATEGY_RANGE &&
      g_auto_trading && ManagedPositionSide()==0 && AutoDirectionAllows(side))
   {
      ResetRangeTriggerFinalEntryState("");
      g_range_trigger_entry_active=true;
      g_range_trigger_entry_side=side;
      g_range_trigger_entry_fire_time=TimeCurrent();
      g_range_trigger_entry_trigger_price=trigger;
      const ENUM_TIMEFRAMES trigger_tf=g_calc_tf;
      g_range_trigger_entry_fire_bar=iTime(_Symbol,trigger_tf,0);
      const int required=
         MathMax(1,MathMin(3,(int)InpRangeTriggerFinalsRequired));
      WriteUnifiedOrderSignalAudit(
         "RANGE_TRIGGER_FINAL_ARM",
         "","INITIAL",side,0,0,"ARMED",
         StringFormat("TRIGGER_FIRED_%.*f | WAIT_POST_TRIGGER_FINAL_1_OF_%d",
                      _Digits,trigger,required),
         false,false,0,g_trade_cycle.position_id);
   }

   DataExportWriteWatchSignalAudit();
}


void ProcessTriggerFinalEntryTick()
{
   // v8.00: Trigger remains chart/diagnostic state only. RANGE INITIAL broker
   // authority is exclusively 3X qualification plus third-FINAL High/Low break.
   return;
}


void WatchCheckTriggerTick()
{
   if(!InpWatchUseTriggerPrice) return;

   // v6.18: no trigger crossing work is required when every execution and
   // structural side is either absent or already fired. Avoid an extra tick
   // request on the highest-frequency flat path.
   const bool exec_long_active=
      g_watch_snapshot.long_trigger_price>0.0 &&
      !g_watch_snapshot.long_trigger_fired;
   const bool exec_short_active=
      g_watch_snapshot.short_trigger_price>0.0 &&
      !g_watch_snapshot.short_trigger_fired;
   const bool struct_long_active=
      g_struct_long_trigger_price>0.0 && !g_struct_long_trigger_fired;
   const bool struct_short_active=
      g_struct_short_trigger_price>0.0 && !g_struct_short_trigger_fired;
   if(!exec_long_active && !exec_short_active &&
      !struct_long_active && !struct_short_active)
      return;

   // OnTick already populated one authoritative market snapshot. Reuse it so
   // Trigger crossing cannot issue a second SymbolInfoTick() for the same tick.
   if(!g_jro_market.valid || g_jro_market.tick.bid<=0.0) return;
   const double bid=g_jro_market.tick.bid;

   if(exec_long_active) WatchCheckTriggerSideTick(1,bid);
   if(exec_short_active) WatchCheckTriggerSideTick(-1,bid);

   // v5.72 user-visible alert Trigger is fully independent from AUTO execution.
   if(struct_long_active) StructuralCheckSideTick(1,bid);
   if(struct_short_active) StructuralCheckSideTick(-1,bid);
}

// v8.29: diagnostic-only counterfactual for Joon MACD Buffer 6.
// This helper has no runtime authority. It reuses the existing WATCH component
// scores and applies the same MACD/context/stage/user-authorization rules while
// replacing only the MACD representation. No marker, alert, Trigger, 3X, order,
// Hold, Risk or Exit state is changed by this calculation.
void WatchEvaluateMacdShadow(const double &shadow_macd[],
                             const double &delta[],
                             const double &dema[],
                             const int fresh,
                             const bool compression,
                             const double delta_ratio,
                             const bool price_response_long,
                             const bool price_response_short,
                             const bool chase_long,
                             const bool chase_short,
                             const int flowL,
                             const int flowS,
                             const int strL,
                             const int strS,
                             const int rngL,
                             const int rngS,
                             const int higher_trend_penalty_long,
                             const int higher_trend_penalty_short,
                             const int delta_age_l,
                             const int delta_age_s,
                             const int dema_age_l,
                             const int dema_age_s,
                             const int delta_dominance,
                             const double range_pos,
                             int &regime,
                             int &macd_age_l,
                             int &macd_age_s,
                             bool &dead_range,
                             int &momL,
                             int &momS,
                             int &ctxL,
                             int &ctxS,
                             int &longScore,
                             int &shortScore,
                             int &longStage,
                             int &shortStage,
                             int &dominantSide,
                             bool &longAuthorized,
                             bool &shortAuthorized)
{
   momL=0; momS=0; ctxL=0; ctxS=0;
   longScore=0; shortScore=0; longStage=0; shortStage=0;
   dominantSide=0; longAuthorized=false; shortAuthorized=false;
   dead_range=false;

   double zero_zone=0.0;
   regime=WatchMacdRegime(shadow_macd,zero_zone);
   macd_age_l=WatchRecentTurnAge(shadow_macd,true,fresh+3);
   macd_age_s=WatchRecentTurnAge(shadow_macd,false,fresh+3);
   const bool macd_up=shadow_macd[0]>shadow_macd[1];
   const bool macd_dn=shadow_macd[0]<shadow_macd[1];
   const bool macd_accel_up=(shadow_macd[0]-shadow_macd[1])>(shadow_macd[1]-shadow_macd[2]);
   const bool macd_accel_dn=(shadow_macd[0]-shadow_macd[1])<(shadow_macd[1]-shadow_macd[2]);

   if(regime>0)
   {
      if(macd_up) momL+=10;
      if(macd_accel_up) momL+=8;
      if(macd_dn) momS+=3;
      if(macd_age_l<=fresh) momL+=7;
   }
   else if(regime<0)
   {
      if(macd_dn) momS+=10;
      if(macd_accel_dn) momS+=8;
      if(macd_up) momL+=3;
      if(macd_age_s<=fresh) momS+=7;
   }
   else
   {
      if(macd_up) momL+=4;
      if(macd_dn) momS+=4;
      if(macd_age_l<=fresh) momL+=3;
      if(macd_age_s<=fresh) momS+=3;
   }
   momL=WatchClamp(momL,0,25);
   momS=WatchClamp(momS,0,25);

   double avg_macd_step=0.0,avg_delta_step=0.0;
   for(int i=0;i<5;i++)
   {
      avg_macd_step+=MathAbs(shadow_macd[i]-shadow_macd[i+1]);
      avg_delta_step+=MathAbs(delta[i]-delta[i+1]);
   }
   avg_macd_step/=5.0;
   avg_delta_step/=5.0;
   const bool internal_waking=(MathAbs(shadow_macd[0]-shadow_macd[1])>avg_macd_step*0.85 ||
                               MathAbs(delta[0]-delta[1])>avg_delta_step*0.85 ||
                               MathAbs(dema[0]-dema[1])>avg_delta_step*0.35);
   dead_range=compression && !internal_waking && delta_ratio<0.80;

   const int bestFreshL=MathMin(macd_age_l,MathMin(delta_age_l,dema_age_l));
   const int bestFreshS=MathMin(macd_age_s,MathMin(delta_age_s,dema_age_s));
   if(bestFreshL<=1) ctxL+=6; else if(bestFreshL<=fresh) ctxL+=3;
   if(bestFreshS<=1) ctxS+=6; else if(bestFreshS<=fresh) ctxS+=3;
   if(price_response_long) ctxL+=4;
   if(price_response_short) ctxS+=4;
   if(dead_range){ctxL-=5;ctxS-=5;}
   if(chase_long) ctxL-=7;
   if(chase_short) ctxS-=7;
   ctxL=WatchClamp(ctxL,0,10);
   ctxS=WatchClamp(ctxS,0,10);

   longScore=WatchClamp(momL+flowL+strL+rngL+ctxL-higher_trend_penalty_long,0,100);
   shortScore=WatchClamp(momS+flowS+strS+rngS+ctxS-higher_trend_penalty_short,0,100);
   longStage=WatchScoreToStage(longScore);
   shortStage=WatchScoreToStage(shortScore);

   if(longStage>1 && delta_dominance!=1) longStage=0;
   if(shortStage>1 && delta_dominance!=-1) shortStage=0;
   if(range_pos>=0.85 && longStage>1) longStage=0;
   if(range_pos<=0.15 && shortStage>1) shortStage=0;

   if(longStage>0 && shortStage<=0) dominantSide=1;
   else if(shortStage>0 && longStage<=0) dominantSide=-1;
   else if(longStage>0 && shortStage>0)
   {
      const int score_gap=longScore-shortScore;
      if(score_gap>=10) dominantSide=1;
      else if(score_gap<=-10) dominantSide=-1;
   }

   const int outputLongStage=(dominantSide==1 ? longStage : 0);
   const int outputShortStage=(dominantSide==-1 ? shortStage : 0);
   longAuthorized=(outputLongStage>=2 && longScore>=65 && flowL>=20 && strL>=8);
   shortAuthorized=(outputShortStage>=2 && momS<=8 && strS>=8 && rngS>=10);
}

void WatchSignalProcessClosedBar()
{
   g_watch_marker_drawn_this_bar=false;
   // It retains the exact same scoring/stage logic and never grants order,
   // candidate, 3X, Hold, Risk or Exit authority.

   // v3.07: WATCH OFF still keeps calculations/CSV diagnostics active.
   // Existing WATCH chart objects are removed once, immediately when the
   // operator turns WATCH OFF in UI.mqh. Do not rescan all chart objects on
   // every completed bar while WATCH remains OFF.
   MqlRates r[]; double macd[],delta[],dema[],ma7[],ma22[],ma70[],ma111[];
   if(!WatchCopyData(r,macd,delta,dema,ma7,ma22,ma70,ma111)) return;
   // v8.65: protect the chart/alert layer from accidental duplicate calls for
   // the same completed bar. The first successful calculation owns that bar.
   if(ArraySize(r)>0 && g_watch_snapshot.bar_time==r[0].time) return;

   // v8.65 performance: Buffer 6 is diagnostic-only. On the canonical AUTO
   // timeframe reuse the already cached M3 assist snapshot instead of issuing
   // another CopyBuffer request for the same completed-bar series.
   double macd_b6[];
   ArrayResize(macd_b6,ArraySize(macd));
   ArraySetAsSeries(macd_b6,true);
   bool shadow_b6_valid=false;
   if(g_signal_tf==AUTO_TF && g_signal_macd_handle==g_macd_handle)
   {
      const int need_b6=ArraySize(macd_b6)+1;
      if(EnsureMarketSnapshotAssist(need_b6) && ArraySize(g_ms_macd_wave)>=need_b6)
      {
         shadow_b6_valid=(ArrayCopy(macd_b6,g_ms_macd_wave,0,1,ArraySize(macd_b6))==ArraySize(macd_b6));
      }
   }
   else if(g_signal_macd_handle!=INVALID_HANDLE)
   {
      shadow_b6_valid=(MarketDataCopyBuffer(g_signal_macd_handle,6,1,ArraySize(macd_b6),macd_b6)>=ArraySize(macd_b6));
   }

   const int look=MathMax(10,InpWatchRangeLookback);
   double hi=-DBL_MAX,lo=DBL_MAX,avg_range=0.0,avg_abs_delta=0.0;
   double recent_range=0.0;
   for(int i=0;i<look;i++)
   {
      hi=MathMax(hi,r[i].high); lo=MathMin(lo,r[i].low);
      avg_range+=r[i].high-r[i].low;
      avg_abs_delta+=MathAbs(delta[i]);
      if(i<5) recent_range+=r[i].high-r[i].low;
   }
   avg_range/=look; avg_abs_delta/=look; recent_range/=5.0;
   const double range_pos=(hi>lo)?MathMax(0.0,MathMin(1.0,(r[0].close-lo)/(hi-lo))):0.5;
   const double atr_ratio=WatchSafeDiv(recent_range,avg_range);
   const double delta_ratio=WatchSafeDiv(MathAbs(delta[0]),avg_abs_delta);
   const bool compression=(avg_range>0.0 && atr_ratio<=InpWatchCompressionRatio);

   // DEAD_RANGE requires both price and internal flow to be quiet. Compression
   // alone is intentionally NOT blocked because it is the prime WATCH habitat.
   double avg_macd_step=0.0,avg_delta_step=0.0;
   for(int i=0;i<5;i++)
   {
      avg_macd_step+=MathAbs(macd[i]-macd[i+1]);
      avg_delta_step+=MathAbs(delta[i]-delta[i+1]);
   }
   avg_macd_step/=5.0; avg_delta_step/=5.0;
   const bool internal_waking=(MathAbs(macd[0]-macd[1])>avg_macd_step*0.85 ||
                               MathAbs(delta[0]-delta[1])>avg_delta_step*0.85 ||
                               MathAbs(dema[0]-dema[1])>avg_delta_step*0.35);
   const bool active_compression=compression && internal_waking;
   const bool dead_range=compression && !internal_waking && delta_ratio<0.80;

   const int fresh=MathMax(1,InpWatchFreshBars);
   const int macd_age_l=WatchRecentTurnAge(macd,true,fresh+3);
   const int macd_age_s=WatchRecentTurnAge(macd,false,fresh+3);
   const int delta_age_l=WatchRecentTurnAge(delta,true,fresh+3);
   const int delta_age_s=WatchRecentTurnAge(delta,false,fresh+3);
   const int dema_age_l=WatchRecentTurnAge(dema,true,fresh+3);
   const int dema_age_s=WatchRecentTurnAge(dema,false,fresh+3);

   const bool macd_up=macd[0]>macd[1];
   const bool macd_dn=macd[0]<macd[1];
   const bool macd_accel_up=(macd[0]-macd[1])>(macd[1]-macd[2]);
   const bool macd_accel_dn=(macd[0]-macd[1])<(macd[1]-macd[2]);
   const bool delta_up=delta[0]>delta[1];
   const bool delta_dn=delta[0]<delta[1];
   const bool dema_up=dema[0]>dema[1];
   const bool dema_dn=dema[0]<dema[1];

   // v3.03: WATCH interprets MACD slope inside its zero-line regime.
   // +MACD falling is LONG weakening, not a full SHORT direction.
   // -MACD rising is SHORT weakening, not a full LONG direction.
   double watch_macd_zero_zone=0.0;
   const int watch_macd_regime=WatchMacdRegime(macd,watch_macd_zero_zone);
   int watch_delta_buy_bars=0,watch_delta_sell_bars=0;
   double watch_delta_sum=0.0;
   const int watch_delta_dominance=WatchDeltaDominance(
      delta,dema,watch_delta_buy_bars,watch_delta_sell_bars,watch_delta_sum);

   // Opposite pressure decay: compare the most recent 3 bars with the previous 3.
   double neg_recent=0,neg_old=0,pos_recent=0,pos_old=0;
   for(int i=0;i<3;i++)
   {
      neg_recent+=MathMax(0.0,-delta[i]); pos_recent+=MathMax(0.0,delta[i]);
      neg_old+=MathMax(0.0,-delta[i+3]);  pos_old+=MathMax(0.0,delta[i+3]);
   }
   const bool sell_pressure_decay=(neg_old>0.0 && neg_recent<neg_old*0.80);
   const bool buy_pressure_decay=(pos_old>0.0 && pos_recent<pos_old*0.80);
   const bool bull_delta_div=(r[0].low<=r[5].low && delta[0]>delta[5]);
   const bool bear_delta_div=(r[0].high>=r[5].high && delta[0]<delta[5]);

   const int sn=MathMax(4,InpWatchStructureLookback);
   const int half=sn/2;
   double recent_low=DBL_MAX,old_low=DBL_MAX,recent_high=-DBL_MAX,old_high=-DBL_MAX;
   for(int i=0;i<half;i++){ recent_low=MathMin(recent_low,r[i].low); recent_high=MathMax(recent_high,r[i].high); }
   for(int i=half;i<sn;i++){ old_low=MathMin(old_low,r[i].low); old_high=MathMax(old_high,r[i].high); }
   const bool higher_low=recent_low>old_low;
   const bool lower_high=recent_high<old_high;
   const double cur_range=MathMax(_Point,r[0].high-r[0].low);
   const double lower_wick=MathMin(r[0].open,r[0].close)-r[0].low;
   const double upper_wick=r[0].high-MathMax(r[0].open,r[0].close);
   const bool lower_reject=lower_wick/cur_range>=0.32;
   const bool upper_reject=upper_wick/cur_range>=0.32;
   const bool ma7_recover=r[0].close>ma7[0] && r[1].close<=ma7[1];
   const bool ma7_break=r[0].close<ma7[0] && r[1].close>=ma7[1];
   const bool price_response_long=higher_low||lower_reject||ma7_recover;
   const bool price_response_short=lower_high||upper_reject||ma7_break;

   // v3.26: distinguish an early reversal WATCH from a short-lived countertrend
   // bounce. Reuse existing MA22/70/111 data; no new indicator or state.
   const bool strong_higher_trend_long =
      r[0].close>ma22[0] &&
      ma22[0]>ma70[0] && ma70[0]>ma111[0] &&
      ma22[0]>ma22[1] && ma70[0]>=ma70[1];
   const bool strong_higher_trend_short =
      r[0].close<ma22[0] &&
      ma22[0]<ma70[0] && ma70[0]<ma111[0] &&
      ma22[0]<ma22[1] && ma70[0]<=ma70[1];

   // Range pressure rewards asymmetric rejection/flow inside compression.
   int lower_rejects=0,upper_rejects=0;
   for(int i=0;i<MathMin(8,look);i++)
   {
      const double rr=MathMax(_Point,r[i].high-r[i].low);
      if((MathMin(r[i].open,r[i].close)-r[i].low)/rr>=0.30) lower_rejects++;
      if((r[i].high-MathMax(r[i].open,r[i].close))/rr>=0.30) upper_rejects++;
   }

   const double move5=WatchSafeDiv(r[0].close-r[5].close,MathMax(_Point,avg_range));
   const bool chase_long=move5>2.20;
   const bool chase_short=move5<-2.20;

   int momL=0,momS=0,flowL=0,flowS=0,strL=0,strS=0,rngL=0,rngS=0,ctxL=0,ctxS=0;
   string reasonL="",reasonS="";

   if(watch_macd_regime>0)
   {
      if(macd_up){momL+=10;WatchAppendReason(reasonL,"MACD_POS_UP");}
      if(macd_accel_up){momL+=8;WatchAppendReason(reasonL,"MACD_POS_ACCEL");}
      if(macd_dn)
      {
         momS+=3;
         WatchAppendReason(reasonS,"LONG_WEAKENING");
      }
      if(macd_age_l<=fresh){momL+=7;WatchAppendReason(reasonL,"MACD_FRESH");}
   }
   else if(watch_macd_regime<0)
   {
      if(macd_dn){momS+=10;WatchAppendReason(reasonS,"MACD_NEG_DN");}
      if(macd_accel_dn){momS+=8;WatchAppendReason(reasonS,"MACD_NEG_ACCEL");}
      if(macd_up)
      {
         momL+=3;
         WatchAppendReason(reasonL,"SHORT_WEAKENING");
      }
      if(macd_age_s<=fresh){momS+=7;WatchAppendReason(reasonS,"MACD_FRESH");}
   }
   else
   {
      // Zero-zone remains a valid early-turn habitat, but only weak momentum
      // points are given until Delta/structure confirm a side.
      if(macd_up){momL+=4;WatchAppendReason(reasonL,"MACD_ZERO_UP");}
      if(macd_dn){momS+=4;WatchAppendReason(reasonS,"MACD_ZERO_DN");}
      if(macd_age_l<=fresh){momL+=3;WatchAppendReason(reasonL,"MACD_ZERO_FRESH");}
      if(macd_age_s<=fresh){momS+=3;WatchAppendReason(reasonS,"MACD_ZERO_FRESH");}
   }
   momL=WatchClamp(momL,0,25); momS=WatchClamp(momS,0,25);

   if(delta_up){flowL+=8;WatchAppendReason(reasonL,"DELTA_UP");}
   if(delta_dn){flowS+=8;WatchAppendReason(reasonS,"DELTA_DN");}
   if(dema_up){flowL+=6;WatchAppendReason(reasonL,"DEMA_UP");}
   if(dema_dn){flowS+=6;WatchAppendReason(reasonS,"DEMA_DN");}
   if(sell_pressure_decay){flowL+=7;WatchAppendReason(reasonL,"SELL_PRESSURE_DECAY");}
   if(buy_pressure_decay){flowS+=7;WatchAppendReason(reasonS,"BUY_PRESSURE_DECAY");}
   if(delta_age_l<=fresh || dema_age_l<=fresh){flowL+=4;WatchAppendReason(reasonL,"FLOW_FRESH");}
   if(delta_age_s<=fresh || dema_age_s<=fresh){flowS+=4;WatchAppendReason(reasonS,"FLOW_FRESH");}
   if(bull_delta_div){flowL+=4;WatchAppendReason(reasonL,"BULL_DELTA_DIV");}
   if(bear_delta_div){flowS+=4;WatchAppendReason(reasonS,"BEAR_DELTA_DIV");}
   if(watch_delta_dominance>0)
   {
      flowL+=6;
      WatchAppendReason(reasonL,"DELTA_BUY_DOM");
   }
   else if(watch_delta_dominance<0)
   {
      flowS+=6;
      WatchAppendReason(reasonS,"DELTA_SELL_DOM");
   }
   else
   {
      WatchAppendReason(reasonL,"DELTA_MIXED");
      WatchAppendReason(reasonS,"DELTA_MIXED");
   }
   flowL=WatchClamp(flowL,0,25); flowS=WatchClamp(flowS,0,25);

   if(higher_low){strL+=8;WatchAppendReason(reasonL,"HIGHER_LOW");}
   if(lower_high){strS+=8;WatchAppendReason(reasonS,"LOWER_HIGH");}
   if(lower_reject){strL+=5;WatchAppendReason(reasonL,"LOWER_REJECT");}
   if(upper_reject){strS+=5;WatchAppendReason(reasonS,"UPPER_REJECT");}
   if(ma7_recover){strL+=7;WatchAppendReason(reasonL,"MA7_RECOVER");}
   if(ma7_break){strS+=7;WatchAppendReason(reasonS,"MA7_BREAK");}
   strL=WatchClamp(strL,0,20); strS=WatchClamp(strS,0,20);

   if(active_compression){WatchAppendReason(reasonL,"ACTIVE_COMPRESSION");WatchAppendReason(reasonS,"ACTIVE_COMPRESSION");}
   if(range_pos<=0.45){rngL+=4;WatchAppendReason(reasonL,"LOWER_HALF");}
   if(range_pos>=0.55){rngS+=4;WatchAppendReason(reasonS,"UPPER_HALF");}
   if(lower_rejects>=upper_rejects+2){rngL+=6;WatchAppendReason(reasonL,"LOWER_REJECT_REPEAT");}
   if(upper_rejects>=lower_rejects+2){rngS+=6;WatchAppendReason(reasonS,"UPPER_REJECT_REPEAT");}
   if(sell_pressure_decay && delta_up){rngL+=5;WatchAppendReason(reasonL,"RANGE_BUY_PRESSURE");}
   if(buy_pressure_decay && delta_dn){rngS+=5;WatchAppendReason(reasonS,"RANGE_SELL_PRESSURE");}
   rngL=WatchClamp(rngL,0,20); rngS=WatchClamp(rngS,0,20);

   const int bestFreshL=MathMin(macd_age_l,MathMin(delta_age_l,dema_age_l));
   const int bestFreshS=MathMin(macd_age_s,MathMin(delta_age_s,dema_age_s));
   if(bestFreshL<=1) ctxL+=6; else if(bestFreshL<=fresh) ctxL+=3;
   if(bestFreshS<=1) ctxS+=6; else if(bestFreshS<=fresh) ctxS+=3;
   if(price_response_long) ctxL+=4;
   if(price_response_short) ctxS+=4;
   if(dead_range){ctxL-=5;ctxS-=5;WatchAppendReason(reasonL,"DEAD_RANGE");WatchAppendReason(reasonS,"DEAD_RANGE");}
   if(chase_long){ctxL-=7;WatchAppendReason(reasonL,"CHASE_PENALTY");}
   if(chase_short){ctxS-=7;WatchAppendReason(reasonS,"CHASE_PENALTY");}

   // Preserve the original WATCH Context semantics from v3.23.
   // DEAD_RANGE / CHASE may reduce positive Context, but cannot by themselves
   // make the total score negative through Context.
   ctxL=WatchClamp(ctxL,0,10); ctxS=WatchClamp(ctxS,0,10);

   // v3.26: higher-trend countertrend suppression is an independent penalty.
   // This avoids changing the legacy DEAD_RANGE / CHASE behavior.
   int higher_trend_penalty_long=0;
   int higher_trend_penalty_short=0;
   if(strong_higher_trend_short)
   {
      higher_trend_penalty_long=10;
      WatchAppendReason(reasonL,"HIGHER_TREND_SHORT_PENALTY");
   }
   if(strong_higher_trend_long)
   {
      higher_trend_penalty_short=10;
      WatchAppendReason(reasonS,"HIGHER_TREND_LONG_PENALTY");
   }

   int longScore=WatchClamp(
      momL+flowL+strL+rngL+ctxL-higher_trend_penalty_long,0,100);
   int shortScore=WatchClamp(
      momS+flowS+strS+rngS+ctxS-higher_trend_penalty_short,0,100);

   const int rawLongStage=WatchScoreToStage(longScore);
   const int rawShortStage=WatchScoreToStage(shortScore);
   int longStage=rawLongStage;
   int shortStage=rawShortStage;

   // WATCH PREP2+ requires recent real order-flow dominance.
   // Without it there is no external WATCH stage; diagnostics still keep the raw score/reason.
   if(longStage>1 && watch_delta_dominance!=1)
   {
      longStage=0;
      WatchAppendReason(reasonL,"DELTA_DOM_STAGE_BLOCK");
   }
   if(shortStage>1 && watch_delta_dominance!=-1)
   {
      shortStage=0;
      WatchAppendReason(reasonS,"DELTA_DOM_STAGE_BLOCK");
   }

   if(range_pos>=0.85 && longStage>1)
   {
      longStage=0;
      WatchAppendReason(reasonL,"RANGE_TOP_STAGE_BLOCK");
   }
   if(range_pos<=0.15 && shortStage>1)
   {
      shortStage=0;
      WatchAppendReason(reasonS,"RANGE_BOTTOM_STAGE_BLOCK");
   }

   int dominantSide=0;
   if(longStage>0 && shortStage<=0) dominantSide=1;
   else if(shortStage>0 && longStage<=0) dominantSide=-1;
   else if(longStage>0 && shortStage>0)
   {
      const int score_gap=longScore-shortScore;
      if(score_gap>=10) dominantSide=1;
      else if(score_gap<=-10) dominantSide=-1;
      else
      {
         WatchAppendReason(reasonL,"AMBIGUOUS_OUTPUT");
         WatchAppendReason(reasonS,"AMBIGUOUS_OUTPUT");
      }
   }

   const int outputLongStage=(dominantSide==1 ? longStage : 0);
   const int outputShortStage=(dominantSide==-1 ? shortStage : 0);

   // v8.19 (v8.09 base): separate sensitive WATCH observation from
   // user-visible reversal authorization using components already owned by
   // this WATCH engine. No external filter/state engine is introduced.
   //
   // COPPER M3 development + MRNA.O M3 external verification:
   // LONG  : score>=65, flow>=20, structure>=8
   // SHORT : momentum<=8, structure>=8, range pressure>=10
   const bool longUserWatchAuthorized=
      (outputLongStage>=2 && longScore>=65 && flowL>=20 && strL>=8);
   const bool shortUserWatchAuthorized=
      (outputShortStage>=2 && momS<=8 && strS>=8 && rngS>=10);

   if(outputLongStage>=2 && !longUserWatchAuthorized)
      WatchAppendReason(reasonL,"USER_WATCH_NOT_AUTHORIZED");
   if(outputShortStage>=2 && !shortUserWatchAuthorized)
      WatchAppendReason(reasonS,"USER_WATCH_NOT_AUTHORIZED");

   // v8.29 diagnostic shadow: calculate the counterfactual Buffer 6 result
   // with the same Delta/structure/range/context rules. It has no authority.
   int shadow_b6_regime=0,shadow_b6_age_l=99,shadow_b6_age_s=99;
   bool shadow_b6_dead_range=false;
   int shadow_b6_momL=0,shadow_b6_momS=0,shadow_b6_ctxL=0,shadow_b6_ctxS=0;
   int shadow_b6_longScore=0,shadow_b6_shortScore=0;
   int shadow_b6_longStage=0,shadow_b6_shortStage=0,shadow_b6_dominantSide=0;
   bool shadow_b6_longAuthorized=false,shadow_b6_shortAuthorized=false;
   if(shadow_b6_valid)
   {
      WatchEvaluateMacdShadow(
         macd_b6,delta,dema,fresh,compression,delta_ratio,
         price_response_long,price_response_short,chase_long,chase_short,
         flowL,flowS,strL,strS,rngL,rngS,
         higher_trend_penalty_long,higher_trend_penalty_short,
         delta_age_l,delta_age_s,dema_age_l,dema_age_s,
         watch_delta_dominance,range_pos,
         shadow_b6_regime,shadow_b6_age_l,shadow_b6_age_s,shadow_b6_dead_range,
         shadow_b6_momL,shadow_b6_momS,shadow_b6_ctxL,shadow_b6_ctxS,
         shadow_b6_longScore,shadow_b6_shortScore,
         shadow_b6_longStage,shadow_b6_shortStage,shadow_b6_dominantSide,
         shadow_b6_longAuthorized,shadow_b6_shortAuthorized);
   }

   // v8.20: keep internal WATCH observation lifecycle and user-visible
   // promotion lifecycle separate. Internal stage memory remains v8.09-owned;
   // user stage memory advances only after a user-authorized WATCH.
   if(longScore<InpWatchResetScore)
   {
      g_watch_long_stage=0;
      g_watch_user_long_stage=0;
   }
   if(shortScore<InpWatchResetScore)
   {
      g_watch_short_stage=0;
      g_watch_user_short_stage=0;
   }

   // v8.34: preserve raw B7 authorization for diagnostics/Trigger/CSV, while
   // user-facing reversal WATCH is shown only against established persistence.
   // Same-persistence WATCH remains observable internally for continuation research.
   const bool longRawRise=
      (longUserWatchAuthorized && outputLongStage>g_watch_user_long_stage);
   const bool shortRawRise=
      (shortUserWatchAuthorized && outputShortStage>g_watch_user_short_stage);
   const bool longRise=
      (longRawRise && g_range_persistent_direction<0);
   const bool shortRise=
      (shortRawRise && g_range_persistent_direction>0);

   g_watch_snapshot.system_alert_fired=false;
   g_watch_snapshot.mobile_alert_fired=false;
   g_watch_snapshot.long_reason="";
   g_watch_snapshot.short_reason="";
   g_watch_snapshot.bar_time=r[0].time;
   g_watch_snapshot.long_score=longScore; g_watch_snapshot.short_score=shortScore;
   g_watch_snapshot.long_stage=longStage; g_watch_snapshot.short_stage=shortStage;
   g_watch_snapshot.momentum_long=momL; g_watch_snapshot.momentum_short=momS;
   g_watch_snapshot.flow_long=flowL; g_watch_snapshot.flow_short=flowS;
   g_watch_snapshot.structure_long=strL; g_watch_snapshot.structure_short=strS;
   g_watch_snapshot.range_long=rngL; g_watch_snapshot.range_short=rngS;
   g_watch_snapshot.context_long=ctxL; g_watch_snapshot.context_short=ctxS;
   g_watch_snapshot.active_compression=active_compression; g_watch_snapshot.dead_range=dead_range;
   g_watch_snapshot.opposite_pressure_decay_long=sell_pressure_decay;
   g_watch_snapshot.opposite_pressure_decay_short=buy_pressure_decay;
   g_watch_snapshot.price_response_long=price_response_long;
   g_watch_snapshot.price_response_short=price_response_short;
   g_watch_snapshot.chase_penalty_long=chase_long; g_watch_snapshot.chase_penalty_short=chase_short;
   g_watch_snapshot.macd_turn_age_long=macd_age_l; g_watch_snapshot.macd_turn_age_short=macd_age_s;
   g_watch_snapshot.delta_turn_age_long=delta_age_l; g_watch_snapshot.delta_turn_age_short=delta_age_s;
   g_watch_snapshot.dema_turn_age_long=dema_age_l; g_watch_snapshot.dema_turn_age_short=dema_age_s;
   g_watch_snapshot.range_position=range_pos; g_watch_snapshot.atr_ratio=atr_ratio;
   g_watch_snapshot.delta_ratio=delta_ratio;

   // v8.29 shadow diagnostics. Current B7 values are recorded beside B6.
   g_watch_snapshot.macd_b7_now=(ArraySize(macd)>0 ? macd[0] : 0.0);
   g_watch_snapshot.macd_b7_prev=(ArraySize(macd)>1 ? macd[1] : 0.0);
   g_watch_snapshot.macd_b6_now=(shadow_b6_valid && ArraySize(macd_b6)>0 ? macd_b6[0] : 0.0);
   g_watch_snapshot.macd_b6_prev=(shadow_b6_valid && ArraySize(macd_b6)>1 ? macd_b6[1] : 0.0);
   g_watch_snapshot.macd_b7_regime=watch_macd_regime;
   g_watch_snapshot.macd_b6_regime=shadow_b6_regime;
   g_watch_snapshot.macd_b6_turn_age_long=shadow_b6_age_l;
   g_watch_snapshot.macd_b6_turn_age_short=shadow_b6_age_s;
   g_watch_snapshot.delta_buy_bars=watch_delta_buy_bars;
   g_watch_snapshot.delta_sell_bars=watch_delta_sell_bars;
   g_watch_snapshot.delta_sum=watch_delta_sum;
   g_watch_snapshot.delta_raw_now=(ArraySize(delta)>0 ? delta[0] : 0.0);
   g_watch_snapshot.delta_ema_now=(ArraySize(dema)>0 ? dema[0] : 0.0);
   g_watch_snapshot.current_long_authorized=longUserWatchAuthorized;
   g_watch_snapshot.current_short_authorized=shortUserWatchAuthorized;
   g_watch_snapshot.shadow_b6_valid=shadow_b6_valid;
   g_watch_snapshot.shadow_b6_dead_range=shadow_b6_dead_range;
   g_watch_snapshot.shadow_b6_momentum_long=shadow_b6_momL;
   g_watch_snapshot.shadow_b6_momentum_short=shadow_b6_momS;
   g_watch_snapshot.shadow_b6_context_long=shadow_b6_ctxL;
   g_watch_snapshot.shadow_b6_context_short=shadow_b6_ctxS;
   g_watch_snapshot.shadow_b6_long_score=shadow_b6_longScore;
   g_watch_snapshot.shadow_b6_short_score=shadow_b6_shortScore;
   g_watch_snapshot.shadow_b6_long_stage=shadow_b6_longStage;
   g_watch_snapshot.shadow_b6_short_stage=shadow_b6_shortStage;
   g_watch_snapshot.shadow_b6_dominant_side=shadow_b6_dominantSide;
   g_watch_snapshot.shadow_b6_long_authorized=shadow_b6_longAuthorized;
   g_watch_snapshot.shadow_b6_short_authorized=shadow_b6_shortAuthorized;

   WatchAppendReason(reasonL,StringFormat("MACD_REG=%d",watch_macd_regime));
   WatchAppendReason(reasonS,StringFormat("MACD_REG=%d",watch_macd_regime));
   WatchAppendReason(reasonL,StringFormat("DELTA_DOM=%d",watch_delta_dominance));
   WatchAppendReason(reasonS,StringFormat("DELTA_DOM=%d",watch_delta_dominance));
   g_watch_snapshot.long_reason=reasonL; g_watch_snapshot.short_reason=reasonS;

   // v8.20: user-facing WATCH Trigger follows the same authorization owner
   // as user-visible WATCH. Internal WATCH score/stage/CSV remain unchanged.
   int userTriggerSide=0;
   int userTriggerLongStage=0;
   int userTriggerShortStage=0;
   if(longUserWatchAuthorized)
   {
      userTriggerSide=1;
      userTriggerLongStage=outputLongStage;
   }
   else if(shortUserWatchAuthorized)
   {
      userTriggerSide=-1;
      userTriggerShortStage=outputShortStage;
   }

   WatchUpdateTriggerState(
      userTriggerSide,userTriggerLongStage,userTriggerShortStage,longScore,shortScore,
      watch_delta_dominance,r,macd,delta,dema,avg_range,
      macd_age_l,macd_age_s,delta_age_l,delta_age_s,dema_age_l,dema_age_s);


   // Raw rises remain in lifecycle diagnostics even when they are same-persistence.
   if(longRawRise)
      DataExportWritePreReversalLifecycleAudit(r[0].time,g_signal_tf,
         (longRise ? "SIGNAL_REVERSAL" : "SIGNAL_SAME_PERSISTENCE"),1,
         StringFormat("B7_SCORE=%d STAGE=%d B6_AUTH=%d PERSIST=%d",
            longScore,outputLongStage,shadow_b6_longAuthorized?1:0,g_range_persistent_direction));
   if(shortRawRise)
      DataExportWritePreReversalLifecycleAudit(r[0].time,g_signal_tf,
         (shortRise ? "SIGNAL_REVERSAL" : "SIGNAL_SAME_PERSISTENCE"),-1,
         StringFormat("B7_SCORE=%d STAGE=%d B6_AUTH=%d PERSIST=%d",
            shortScore,outputShortStage,shadow_b6_shortAuthorized?1:0,g_range_persistent_direction));

   // v8.248: legacy WatchSignal remains diagnostic/CSV/trigger state only.
   // User-facing WATCH chart markers and alerts are owned exclusively by
   // StateEvaluation WATCH.  Do not publish legacy WATCH output here.

   // Internal v8.09 stage lifecycle is preserved exactly.
   g_watch_long_stage=outputLongStage;
   g_watch_short_stage=outputShortStage;

   // User-visible stage memory advances only when an authorized WATCH is shown.
   if(longRise)
      g_watch_user_long_stage=outputLongStage;
   if(shortRise)
      g_watch_user_short_stage=outputShortStage;

   // v3.93: dominantSide==0 no longer deletes armed directional Trigger
   // levels. Each direction retires independently when its own WATCH score
   // falls below InpWatchResetScore.
   if(InpWatchWriteCSV && (longStage>0 || shortStage>0 || active_compression))
      DataExportWriteWatchSignalAudit();
   // v8.65: ObjectName/ObjectDelete scan is amortized. A marker change gets
   // prompt maintenance; otherwise cleanup is performed only periodically.
   g_watch_object_maintenance_bars++;
   if(g_watch_marker_drawn_this_bar || g_watch_object_maintenance_bars>=20)
   {
      WatchDeleteOldObjects();
      DeleteOldM3AccelerationMarkers();
      g_watch_object_maintenance_bars=0;
   }
}

#endif // __JOON_SIGNALENGINE_MQH__
