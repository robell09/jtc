//+------------------------------------------------------------------+
//| EntryEngine.mqh                                              |
//| Joon Trend/Range AutoTrader modular component                    |
//+------------------------------------------------------------------+
#ifndef __JOON_ENTRYENGINE_MQH__
#define __JOON_ENTRYENGINE_MQH__


//+------------------------------------------------------------------+


//+------------------------------------------------------------------+
void RegisterOrderFailure(const string prefix)
{
   WriteMinimalOrderFailureLog(prefix);
   g_consecutive_order_failures++;
   g_status = prefix + ": " + trade.ResultRetcodeDescription();

   // Ordinary broker/order errors must not change the user's AUTO switch.
   // Keep AUTO ON and let the normal closed-bar/cooldown gates control retries.
   // AUTO is disabled only by an explicit user click. Catastrophic post-fill
   // protection failures are handled separately by their safety-close branch.
   if(InpMaximumOrderFailures > 0 &&
      g_consecutive_order_failures >= InpMaximumOrderFailures)
   {
      g_status += " | AUTO ON - ORDER RETRY WAIT";
      NotifyTerminalOnly(_Symbol + " " + g_status);
      // Avoid an ever-growing counter while preserving diagnostic meaning.
      g_consecutive_order_failures = InpMaximumOrderFailures;
   }
   Print(g_status);
}

//+------------------------------------------------------------------+
bool EntrySafetyAllows(const double new_volume,const int side=0)
{
   g_entry_safety_block_reason = "";

   string trade_permission_reason="";
   if(!JTATradePermissionAllowed(trade_permission_reason))
   {
      g_entry_safety_block_reason = trade_permission_reason;
      g_status = "ENTRY BLOCKED: "+trade_permission_reason;
      return false;
   }

   const long trade_mode = SymbolInfoInteger(_Symbol,SYMBOL_TRADE_MODE);
   if(trade_mode == SYMBOL_TRADE_MODE_DISABLED || trade_mode == SYMBOL_TRADE_MODE_CLOSEONLY ||
      (side > 0 && trade_mode == SYMBOL_TRADE_MODE_SHORTONLY) ||
      (side < 0 && trade_mode == SYMBOL_TRADE_MODE_LONGONLY))
   {
      g_entry_safety_block_reason = "SYMBOL_TRADE_MODE_BLOCK";
      g_status = "ENTRY BLOCKED: SYMBOL TRADE MODE";
      return false;
   }

   if(new_volume <= 0.0)
   {
      g_entry_safety_block_reason = "INVALID_VOLUME";
      g_status = "ENTRY BLOCKED: INVALID VOLUME";
      return false;
   }

   // v2.73 HEDGING manual-position independence:
   // On retail hedging accounts, foreign/manual positions on the same symbol
   // must not block Joon Trade Compass AUTO entries. Managed position state,
   // lot limits, Hold/Risk/Exit and ticket operations already use EA Magic only.
   // Keep the legacy foreign-position block only for non-hedging accounts.
   const bool hedging_account =
      AccountInfoInteger(ACCOUNT_MARGIN_MODE) ==
      ACCOUNT_MARGIN_MODE_RETAIL_HEDGING;
   if(!hedging_account &&
      InpBlockWhenManualPositionExists &&
      ForeignPositionExists())
   {
      g_entry_safety_block_reason = "MANUAL_OR_OTHER_EA_POSITION";
      g_status = "ENTRY BLOCKED: MANUAL/OTHER EA POSITION";
      return false;
   }
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0 || ask < bid)
   {
      g_entry_safety_block_reason = "INVALID_QUOTE";
      g_status = "ENTRY BLOCKED: INVALID QUOTE";
      return false;
   }
   if(InpMaximumSpreadPoints > 0.0 &&
      (ask - bid) / _Point > InpMaximumSpreadPoints)
   {
      g_entry_safety_block_reason = "SPREAD_TOO_WIDE";
      g_status = "ENTRY BLOCKED: SPREAD";
      return false;
   }
   int managed_side = 0;
   double total = 0.0, average = 0.0, sl = 0.0, tp = 0.0;
   datetime first_time = 0;
   ManagedGroupInfo(managed_side, total, average, sl, tp, first_time);
   if(InpMaximumTotalLots > 0.0 &&
      total + new_volume > InpMaximumTotalLots + 0.0000001)
   {
      g_entry_safety_block_reason = "MAX_TOTAL_LOTS";
      g_status = "ENTRY BLOCKED: MAX TOTAL LOTS";
      return false;
   }
   return true;
}

//+------------------------------------------------------------------+
void RestoreAdditionalEntryState()
{
   ulong ticket = 0;
   ENUM_POSITION_TYPE type = POSITION_TYPE_BUY;
   double open_price = 0.0, sl = 0.0, tp = 0.0;
   datetime position_time = 0;
   if(!ManagedPosition(ticket, type, open_price, sl, tp, position_time))
   {
      g_additional_entry_count = 0;
      g_additional_entry_filled_count = 0;
      JTAAddPersistenceClear();
      g_last_entry_time = 0;
      g_initial_entry_time = 0;
      g_initial_entry_lots = 0.0;
      g_initial_entry_price = 0.0;
      g_initial_r_distance = 0.0;
      JTAAddLayerResetAll();
   g_highest_profit_r = 0.0;
   g_hold_state = HOLD_UNKNOWN;
   g_profit_protection_state = PROFIT_PROTECTION_UNKNOWN;
      g_tp_distance = 0.0;
      g_sl_distance = 0.0;
      g_protected_sl = 0.0;
      g_initial_virtual_profit_floor_active = false;
      g_initial_virtual_profit_floor_side = 0;
      g_initial_virtual_profit_floor_r = 0.0;
      g_initial_virtual_profit_floor_price = 0.0;
      g_initial_virtual_profit_floor_time = 0;
      g_original_tp = 0.0;
      g_profit_guard_peak_percent = 0.0;
      g_profit_guard_activated = false;
      g_hold_score_partial_done = false;
      g_chase_entry_candidate = false;
      g_chase_trend_hold_active = false;
      g_chase_weakness_bars = 0;
      return;
   }

   g_additional_entry_count = 0;
   g_additional_entry_filled_count = 0;
   g_last_entry_time = position_time;
   g_initial_entry_time = position_time;
   g_short_term_partial_taken = false;
   g_short_term_break_even_applied = false;
   g_profit_guard_peak_percent = 0.0;
   g_profit_guard_activated = false;
   g_hold_score_partial_done = false;
   g_chase_entry_candidate = false;
   g_chase_trend_hold_active = false;
   g_chase_weakness_bars = 0;
   if(!HistorySelect(position_time, TimeCurrent()))
      return;

   datetime first_add_deal_time=0;
   JTAAddLayerResetAll();
   const int total = HistoryDealsTotal();
   for(int i = 0; i < total; i++)
   {
      const ulong deal = HistoryDealGetTicket(i);
      if(deal == 0 ||
         HistoryDealGetString(deal, DEAL_SYMBOL) != _Symbol ||
         (ulong)HistoryDealGetInteger(deal, DEAL_MAGIC) != InpMagicNumber)
         continue;

      const string comment = HistoryDealGetString(deal, DEAL_COMMENT);
      const ENUM_DEAL_ENTRY deal_entry =
         (ENUM_DEAL_ENTRY)HistoryDealGetInteger(deal, DEAL_ENTRY);
      if(deal_entry == DEAL_ENTRY_OUT)
      {
         // A managed position still exists, so any recorded exit deal in
         // this position cycle represents a partial reduction.
         g_short_term_partial_taken = true;
         continue;
      }
      if(deal_entry != DEAL_ENTRY_IN)
         continue;
      const datetime deal_time =
         (datetime)HistoryDealGetInteger(deal, DEAL_TIME);
      const bool is_add_deal=
         (StringFind(comment, "additional entry") == 0 ||
          (StringFind(comment, "stage ") == 0 && StringFind(comment, " entry:") > 0));
      if(is_add_deal)
      {
         // v5.97: reconstruct layer anchors from actual broker deals so an EA
         // restart does not collapse ADD1/ADD2 HoldEngine history into INITIAL.
         g_additional_entry_count++;
         g_additional_entry_filled_count++;
         const double hist_price=HistoryDealGetDouble(deal,DEAL_PRICE);
         const double hist_volume=HistoryDealGetDouble(deal,DEAL_VOLUME);
         const int restored_stage=g_additional_entry_filled_count;
         const double restored_r=MathMax(_Point,StopDistancePrice(hist_price,hist_volume));
         JTAAddLayerSet(restored_stage,hist_price,deal_time,deal_time,restored_r,hist_volume);
         if(first_add_deal_time==0 || deal_time<first_add_deal_time)
            first_add_deal_time=deal_time;
      }
      else if(g_initial_entry_lots <= 0.0)
      {
         g_initial_entry_lots = HistoryDealGetDouble(deal, DEAL_VOLUME);
         g_initial_entry_price = HistoryDealGetDouble(deal, DEAL_PRICE);
      }
      if(deal_time > g_last_entry_time)
         g_last_entry_time = deal_time;
   }

   JTAHoldAnchorLoad(g_initial_entry_time);
   if(g_initial_hold_anchor_time<=0)
      g_initial_hold_anchor_time=g_initial_entry_time;
   for(int ai=0;ai<ArraySize(g_add_layers);++ai)
      if(g_add_layers[ai].active && g_add_layers[ai].hold_anchor_time<=0)
         g_add_layers[ai].hold_anchor_time=g_add_layers[ai].entry_time;
   JTAAddLayerMirrorLegacy();

   // v3.68: restore terminal-persistent original 3-signal structure and its
   // latched invalidation before ADD decisions resume. History remains the
   // authority for cumulative ADD fills; persistence can only increase that
   // recovered cumulative count, never reduce it.
   const int history_filled_count=g_additional_entry_filled_count;
   JTAAddPersistenceLoad(position_time);
   g_additional_entry_filled_count=
      MathMax(history_filled_count,g_additional_entry_filled_count);

   // ADD structural-invalidation reconstruction removed in v4.23;
   // ADD eligibility is now determined only by the active 2-FINAL/full-break
   // sequence plus the current Hold/Risk/Safety checks.
   if(g_initial_entry_lots <= 0.0)
      g_initial_entry_lots = PositionGetDouble(POSITION_VOLUME) /
                             (double)(MathMax(0,g_additional_entry_filled_count) + 1);
   int group_side = 0;
   double group_volume = 0.0, group_average = 0.0;
   double group_sl = 0.0, group_tp = 0.0;
   datetime group_time = 0;
   if(ManagedGroupInfo(group_side, group_volume, group_average,
                       group_sl, group_tp, group_time))
   {
      g_protected_sl = group_sl;

      if(group_sl > 0.0)
      {
         g_short_term_break_even_applied =
            group_side > 0 ? group_sl >= group_average
                           : group_sl <= group_average;
      }

      // v3.44: restoring an EA must not redefine 1R from the current broker
      // SL because that SL may already be BE or a profit-lock level. Restore
      // the original risk from the configured menu SL at the initial fill.
      if(g_initial_r_distance <= 0.0 && g_initial_entry_price > 0.0)
      {
         const double base_volume =
            g_initial_entry_lots > 0.0 ? g_initial_entry_lots : group_volume;
         const double menu_r_distance =
            JTAInitialRiskDistancePrice(g_initial_entry_price,base_volume);
         if(menu_r_distance > 0.0)
            g_initial_r_distance = MathMax(menu_r_distance,_Point);
      }
      if(g_initial_r_distance > 0.0)
         g_sl_distance = g_initial_r_distance;
      if(group_tp > 0.0)
      {
         g_tp_distance = MathAbs(group_tp - group_average);
         g_original_tp = group_tp;
      }
   }
}

//+------------------------------------------------------------------+
bool TradeResultSucceeded()
{
   return JTF_TradeResultSucceeded(trade);
}

//+------------------------------------------------------------------+
int BarsSinceLastEntry()
{
   if(g_last_entry_time <= 0)
      return -1;
   const ENUM_TIMEFRAMES tf=AUTO_TF;
   return iBarShift(_Symbol, tf, g_last_entry_time, false);
}

//+------------------------------------------------------------------+
ENUM_TIMEFRAMES ActiveManagementTF()
{
   return AUTO_TF;
}

int BarsSinceInitialEntry()
{
   if(g_initial_entry_time <= 0)
      return -1;
   return iBarShift(_Symbol, ActiveManagementTF(),
                    g_initial_entry_time, false);
}

//+------------------------------------------------------------------+
double ProfileEntryDeltaMultiplier()
{
   // The relaxed plan uses one common entry threshold. Asset profiles still
   // control oversized-bar filtering, but no longer raise Delta strength.
   return InpEntryDeltaMultiplier;
}

//+------------------------------------------------------------------+
string TradeLogEntryTypeName()
{
   switch(g_entry_type)
   {
      case ENTRY_EARLY: return "EARLY";
      case ENTRY_CHASE: return "CHASE";
      case ENTRY_ADD:   return "ADD";
      case ENTRY_RANGE: return "RANGE";
      default:          return "NORMAL";
   }
}

// Wilder-style ATR approximation from chart bars without adding another
// indicator handle.
double EntryATR(const ENUM_TIMEFRAMES timeframe)
{
   const int period = MathMax(3, InpATRCalculationPeriod);
   double sum = 0.0;
   int valid = 0;
   for(int shift = 1; shift <= period; shift++)
   {
      const double high_value = iHigh(_Symbol, timeframe, shift);
      const double low_value = iLow(_Symbol, timeframe, shift);
      const double previous_close = iClose(_Symbol, timeframe, shift + 1);
      if(high_value <= 0.0 || low_value <= 0.0 || previous_close <= 0.0)
         continue;
      const double true_range = MathMax(high_value - low_value,
         MathMax(MathAbs(high_value - previous_close),
                 MathAbs(low_value - previous_close)));
      sum += true_range;
      valid++;
   }
   return valid > 0 ? sum / valid : 0.0;
}

bool MACDAcceleratingForEntry(const int side)
{
   double macd[];
   ArrayResize(macd, 3);
   ArraySetAsSeries(macd, true);
   if(g_macd_handle == INVALID_HANDLE ||
      MarketDataCopyBuffer(g_macd_handle, JTC_MACD_WAVE_BUFFER, 0, 3, macd) < 3)
      return false;
   if(side > 0)
      return macd[0] > macd[1] && macd[1] >= macd[2];
   return macd[0] < macd[1] && macd[1] <= macd[2];
}

bool MACDDeceleratingForEntry(const int side)
{
   if(!InpBlockMACDDeceleration)
      return false;
   double macd[];
   ArrayResize(macd, 3);
   ArraySetAsSeries(macd, true);
   if(g_macd_handle == INVALID_HANDLE ||
      MarketDataCopyBuffer(g_macd_handle, JTC_MACD_WAVE_BUFFER, 0, 3, macd) < 3)
      return true;
   if(side > 0)
      return macd[0] <= macd[1] && macd[1] <= macd[2];
   return macd[0] >= macd[1] && macd[1] >= macd[2];
}

bool StrongRangeBreakoutForEntry(const int side,
                                 const double entry_price,
                                 const double range_high,
                                 const double range_low)
{
   if(!InpAllowStrongRangeBreakout || range_high <= range_low)
      return false;
   const double atr = EntryATR(AUTO_TF);
   if(atr <= 0.0)
      return false;
   const double buffer = atr * MathMax(0.0, InpBreakoutBufferATR);
   const bool price_break = side > 0 ? entry_price > range_high + buffer :
                                      entry_price < range_low - buffer;
   if(!price_break || !MACDAcceleratingForEntry(side))
      return false;
   string delta_reason = "";
   return DeltaNotExhaustedForEntry(side, delta_reason);
}

bool ATRChaseEntryBlocked(const int side,
                          const double entry_price)
{
   if(!InpBlockATRChaseEntry)
      return false;
   const int lookback = MathMax(2, InpATRChaseLookbackBars);
   const double reference = iClose(_Symbol, AUTO_TF, lookback + 1);
   const double atr = EntryATR(AUTO_TF);
   if(reference <= 0.0 || atr <= 0.0)
      return false;
   const double directional_move = side > 0 ? entry_price - reference :
                                             reference - entry_price;
   return directional_move >= atr * MathMax(0.10, InpATRChaseMaximumMove);
}

// Blocks entries after same-side volume delta has already faded. A negative
// delta alone is not enough for a short: its magnitude must still be material
// and must not be weakening for consecutive observations.
bool DeltaNotExhaustedForEntry(const int side,
                               string &block_reason)
{
   block_reason = "";
   if(!InpBlockDeltaExhaustion)
      return true;

   // v3.68: lookback is now a sample REGION, not a "N consecutive bars"
   // requirement. Judge current participation against the region peak and
   // compare recent pressure with the older half of the same region.
   const int lookback = MathMax(4, InpDeltaExhaustionLookback + 2);
   const int shift = InpShortTermEntryMode == ENTRY_FAST_MOMENTUM ? 0 : 1;
   const int required = shift + lookback + 1;
   double delta[];
   ArrayResize(delta, required);
   ArraySetAsSeries(delta, true);
   if(g_delta_handle == INVALID_HANDLE ||
      MarketDataCopyBuffer(g_delta_handle, 2, 0, required, delta) < required)
   {
      block_reason = "DELTA DATA";
      return false;
   }

   const double current = delta[shift];
   if(side > 0 ? current <= 0.0 : current >= 0.0)
   {
      block_reason = "OPPOSITE DELTA";
      return false;
   }

   double same_sum=0.0, opposite_sum=0.0, same_peak=0.0;
   double recent_same=0.0, older_same=0.0;
   double recent_opp=0.0, older_opp=0.0;
   int recent_n=0, older_n=0;
   const int split=MathMax(2,lookback/2);

   for(int i=0;i<lookback;i++)
   {
      const double signed_value=side*delta[shift+i];
      if(signed_value>=0.0)
      {
         same_sum+=signed_value;
         same_peak=MathMax(same_peak,signed_value);
      }
      else
         opposite_sum+=-signed_value;

      if(i<split)
      {
         recent_same+=MathMax(0.0,signed_value);
         recent_opp+=MathMax(0.0,-signed_value);
         recent_n++;
      }
      else
      {
         older_same+=MathMax(0.0,signed_value);
         older_opp+=MathMax(0.0,-signed_value);
         older_n++;
      }
   }

   const double recent_same_avg=recent_same/MathMax(1,recent_n);
   const double older_same_avg=older_same/MathMax(1,older_n);
   const double recent_opp_avg=recent_opp/MathMax(1,recent_n);
   const double older_opp_avg=older_opp/MathMax(1,older_n);
   const double strength_floor=MathMax(0.10,InpDeltaMinimumStrengthRatio);
   const double current_strength=MathAbs(current);

   // Region exhaustion requires BOTH meaningful retreat from the same-side
   // peak and deterioration of recent participation. A large opposite-pressure
   // increase makes the exhaustion conclusion stronger.
   const bool peak_fade=
      same_peak>0.0 && current_strength<same_peak*strength_floor;
   const bool participation_fade=
      older_same_avg>0.0 && recent_same_avg<older_same_avg*strength_floor;
   const bool opposite_build=
      recent_opp_avg>0.0 &&
      recent_opp_avg>=MathMax(older_opp_avg,recent_same_avg*0.50);

   if(peak_fade && (participation_fade || opposite_build))
   {
      block_reason = "DELTA SEGMENT EXHAUSTION";
      return false;
   }

   // Preserve the original relative-strength safety intent without requiring
   // any particular count/order of same-sign bars.
   const double total=same_sum+opposite_sum;
   const double direction_ratio=total>0.0 ? same_sum/total : 0.0;
   if(direction_ratio<0.50 && opposite_build)
   {
      block_reason = "DELTA SEGMENT OPPOSITE PRESSURE";
      return false;
   }

   return true;
}

// A chase-style entry needs persistent directional participation, not merely
// one same-side delta bar. It also blocks fresh shorts near lows when buying
// delta is absorbing supply (and the mirrored condition for longs near highs).
bool DirectionalPersistenceAllowsEntry(const int side,
                                       const double entry_price,
                                       const bool strict_persistence,
                                       const bool have_range,
                                       const double range_high,
                                       const double range_low,
                                       string &block_reason)
{
   block_reason = "";
   if(!InpUseDirectionalPersistenceFilter)
      return true;

   // v3.68: these lookbacks define evidence REGIONS. The old minimum-bar
   // inputs are retained for menu compatibility, but converted into the
   // equivalent required directional ratio rather than literal bar counts.
   const int delta_lookback = MathMax(4, InpDirectionalPersistenceLookback);
   const int absorption_lookback = MathMax(4, InpAbsorptionLookbackBars);
   const int macd_lookback = MathMax(4, InpMACDPersistenceLookback);
   const int required = MathMax(delta_lookback, absorption_lookback) + 2;
   const int shift = InpShortTermEntryMode == ENTRY_FAST_MOMENTUM ? 0 : 1;

   double delta[];
   ArrayResize(delta, shift + required);
   ArraySetAsSeries(delta, true);
   if(g_delta_handle == INVALID_HANDLE ||
      MarketDataCopyBuffer(g_delta_handle, 2, 0, shift + required, delta) < shift + required)
   {
      block_reason = "DELTA PERSISTENCE DATA";
      return false;
   }

   double same_delta_sum=0.0, opposite_delta_sum=0.0;
   double weighted_delta_total=0.0, weighted_delta_same=0.0;
   double recent_same_delta=0.0, older_same_delta=0.0;
   double recent_opp_delta=0.0, older_opp_delta=0.0;
   int recent_delta_n=0, older_delta_n=0;
   const int delta_split=MathMax(2,delta_lookback/2);

   for(int i=0;i<delta_lookback;i++)
   {
      const double signed_value=side*delta[shift+i];
      const double weight=1.0/(double)(i+1);
      weighted_delta_total+=weight*MathAbs(signed_value);
      if(signed_value>=0.0)
      {
         same_delta_sum+=signed_value;
         weighted_delta_same+=weight*signed_value;
      }
      else
         opposite_delta_sum+=-signed_value;

      if(i<delta_split)
      {
         recent_same_delta+=MathMax(0.0,signed_value);
         recent_opp_delta+=MathMax(0.0,-signed_value);
         recent_delta_n++;
      }
      else
      {
         older_same_delta+=MathMax(0.0,signed_value);
         older_opp_delta+=MathMax(0.0,-signed_value);
         older_delta_n++;
      }
   }

   const double delta_direction_ratio=
      weighted_delta_total>0.0 ? weighted_delta_same/weighted_delta_total : 0.5;
   const double required_delta_ratio=MathMax(0.50,MathMin(0.90,
      (double)MathMax(1,InpMinimumSameDirectionDeltaBars)/
      (double)MathMax(1,delta_lookback)));
   const double recent_same_avg=recent_same_delta/MathMax(1,recent_delta_n);
   const double older_same_avg=older_same_delta/MathMax(1,older_delta_n);
   const double recent_opp_avg=recent_opp_delta/MathMax(1,recent_delta_n);
   const double older_opp_avg=older_opp_delta/MathMax(1,older_delta_n);

   if(strict_persistence)
   {
      if(delta_direction_ratio<required_delta_ratio)
      {
         block_reason = "DELTA REGION NOT PERSISTENT";
         return false;
      }
      if(opposite_delta_sum>0.0 &&
         same_delta_sum<opposite_delta_sum*MathMax(1.0,InpMinimumDeltaDominanceRatio))
      {
         block_reason = "DELTA REGION DOMINANCE WEAK";
         return false;
      }

      // A region whose recent same-side pressure is collapsing while opposite
      // pressure expands is not treated as persistent even if older bars were strong.
      if(older_same_avg>0.0 && recent_same_avg<older_same_avg*0.60 &&
         recent_opp_avg>MathMax(older_opp_avg,recent_same_avg))
      {
         block_reason = "DELTA REGION FADING";
         return false;
      }
   }

   double macd[];
   ArrayResize(macd, macd_lookback + 1);
   ArraySetAsSeries(macd, true);
   if(g_macd_handle == INVALID_HANDLE ||
      MarketDataCopyBuffer(g_macd_handle, JTC_MACD_WAVE_BUFFER, 0, macd_lookback + 1, macd) < macd_lookback + 1)
   {
      block_reason = "MACD PERSISTENCE DATA";
      return false;
   }

   double weighted_macd_total=0.0, weighted_macd_same=0.0;
   double weighted_expand_total=0.0, weighted_expand_good=0.0;
   double same_side_peak=0.0;
   for(int i=0;i<macd_lookback;i++)
   {
      const double signed_macd=side*macd[i];
      const double weight=1.0/(double)(i+1);
      weighted_macd_total+=weight;
      if(signed_macd>0.0)
      {
         weighted_macd_same+=weight;
         same_side_peak=MathMax(same_side_peak,signed_macd);
      }

      if(i+1<macd_lookback+1)
      {
         weighted_expand_total+=weight;
         if(side*(macd[i]-macd[i+1])>0.0)
            weighted_expand_good+=weight;
      }
   }

   const double macd_zone_ratio=
      weighted_macd_total>0.0 ? weighted_macd_same/weighted_macd_total : 0.0;
   const double macd_expand_ratio=
      weighted_expand_total>0.0 ? weighted_expand_good/weighted_expand_total : 0.0;
   const double required_macd_ratio=MathMax(0.50,MathMin(0.95,
      (double)MathMax(1,InpMinimumSameDirectionMACDBars)/
      (double)MathMax(1,macd_lookback)));
   const double required_expand_ratio=MathMax(0.20,MathMin(0.80,
      (double)MathMax(1,InpMinimumMACDExpansionBars)/
      (double)MathMax(1,macd_lookback-1)));
   const double current_signed_macd=side*macd[0];
   const bool macd_peak_fade=
      same_side_peak>0.0 && current_signed_macd>0.0 &&
      current_signed_macd<same_side_peak*0.60;

   if(strict_persistence && macd_zone_ratio<required_macd_ratio)
   {
      block_reason = "MACD REGION NOT PERSISTENT";
      return false;
   }

   // For both strict and ordinary entries, block only a genuine regional fade:
   // old same-side evidence remains in the window, but current momentum has
   // surrendered most of its peak and directional expansion has collapsed.
   if(macd_zone_ratio>=0.50 &&
      macd_expand_ratio<required_expand_ratio && macd_peak_fade)
   {
      block_reason = "MACD REGION FADING";
      return false;
   }

   if(InpBlockEdgeDeltaAbsorption && have_range)
   {
      const double atr = EntryATR(AUTO_TF);
      if(atr > 0.0)
      {
         const double edge_distance = atr * MathMax(0.0, InpAbsorptionEdgeDistanceATR);
         const bool near_exhausted_edge = side > 0 ?
            entry_price >= range_high - edge_distance :
            entry_price <= range_low + edge_distance;

         if(near_exhausted_edge)
         {
            double absorption_same_sum=0.0, absorption_opposite_sum=0.0;
            double recent_abs_same=0.0, older_abs_same=0.0;
            double recent_abs_opp=0.0, older_abs_opp=0.0;
            int recent_abs_n=0, older_abs_n=0;
            const int split=MathMax(2,absorption_lookback/2);

            for(int i=0;i<absorption_lookback;i++)
            {
               const double signed_value=side*delta[shift+i];
               if(signed_value>=0.0) absorption_same_sum+=signed_value;
               else                  absorption_opposite_sum+=-signed_value;

               if(i<split)
               {
                  recent_abs_same+=MathMax(0.0,signed_value);
                  recent_abs_opp+=MathMax(0.0,-signed_value);
                  recent_abs_n++;
               }
               else
               {
                  older_abs_same+=MathMax(0.0,signed_value);
                  older_abs_opp+=MathMax(0.0,-signed_value);
                  older_abs_n++;
               }
            }

            const double recent_abs_same_avg=recent_abs_same/MathMax(1,recent_abs_n);
            const double older_abs_same_avg=older_abs_same/MathMax(1,older_abs_n);
            const double recent_abs_opp_avg=recent_abs_opp/MathMax(1,recent_abs_n);
            const double older_abs_opp_avg=older_abs_opp/MathMax(1,older_abs_n);

            // Absorption is pressure-versus-progress, not an opposite-bar count.
            // At an exhausted range edge, block when opposite pressure is at
            // least as large as configured AND it is strengthening relative
            // to the older half while same-side pressure is not strengthening.
            const bool opposite_pressure_dominant=
               absorption_opposite_sum>=absorption_same_sum*
                  MathMax(0.10,InpAbsorptionOppositeSumRatio);
            const bool opposite_pressure_building=
               recent_abs_opp_avg>=MathMax(older_abs_opp_avg,
                                           recent_abs_same_avg);
            const bool same_pressure_not_building=
               older_abs_same_avg<=0.0 ||
               recent_abs_same_avg<=older_abs_same_avg*1.10;

            if(opposite_pressure_dominant &&
               opposite_pressure_building &&
               same_pressure_not_building)
            {
               block_reason = side > 0 ? "BEARISH DELTA REGION ABSORPTION" :
                                         "BULLISH DELTA REGION ABSORPTION";
               return false;
            }
         }
      }
   }

   return true;
}

//+------------------------------------------------------------------+
bool ReduceLatestAdditionalEntry(const int side,
                                 const string reason)
{
   if(g_additional_entry_count <= 0)
      return false;

   g_pending_exit_reason = "PARTIAL EXIT: " + reason;
   g_pending_exit_reason_time = TimeCurrent();
   const long margin_mode = AccountInfoInteger(ACCOUNT_MARGIN_MODE);
   bool result = false;
   if(margin_mode == ACCOUNT_MARGIN_MODE_RETAIL_HEDGING)
   {
      ulong newest_ticket = 0;
      datetime newest_time = 0;
      for(int i = PositionsTotal() - 1; i >= 0; i--)
      {
         const ulong ticket = PositionGetTicket(i);
         if(ticket == 0 || !PositionSelectByTicket(ticket) ||
            PositionGetString(POSITION_SYMBOL) != _Symbol ||
            (ulong)PositionGetInteger(POSITION_MAGIC) != InpMagicNumber)
            continue;
         const int ticket_side =
            PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY ? 1 : -1;
         const datetime ticket_time =
            (datetime)PositionGetInteger(POSITION_TIME);
         if(ticket_side == side && ticket_time >= newest_time)
         {
            newest_time = ticket_time;
            newest_ticket = ticket;
         }
      }
      if(newest_ticket > 0)
         result = ExitClosePosition(newest_ticket);
   }
   else
   {
      // v5.97: per-layer HoldEngine reductions must remove the actual newest
      // virtual ADD volume, not the current UI lot setting.
      const int reducing_stage=JTAAddLayerLatestActiveStage();
      const double reduce_volume=NormalizeVolume(JTAAddLayerVolume(reducing_stage));
      if(reduce_volume<=0.0)
         return false;
      if(side > 0)
         result = TradeExecuteSell(reduce_volume, _Symbol, 0.0, 0.0, 0.0,
                             "PARTIAL EXIT");
      else
         result = TradeExecuteBuy(reduce_volume, _Symbol, 0.0, 0.0, 0.0,
                            "PARTIAL EXIT");
   }

   if(!result || !TradeResultSucceeded())
   {
      g_status = "PARTIAL EXIT FAILED: " +
                 trade.ResultRetcodeDescription();
      return false;
   }
   const int reduced_stage=JTAAddLayerLatestActiveStage();
   JTAAddLayerClear(reduced_stage);
   g_additional_entry_count = MathMax(0, g_additional_entry_count - 1);
   g_has_add_entry=(g_additional_entry_count>0);
   JTAHoldAnchorSave();
   g_status = (side > 0 ? "LONG " : "SHORT ") +
              "PARTIAL EXIT: " + reason;
   // v4.61: normal partial-close success is notified once from
   // OnTradeTransaction() using the actual broker deal and realized P/L.
   return true;
}

string ResolveRangeEntryReason(const bool timed_reversal,
                               const bool early_turn,
                               const bool compression_break,
                               const bool turn_signal)
{
   if(timed_reversal)    return "TIMED REVERSAL";
   if(early_turn)        return "EARLY TURN";
   if(compression_break) return "COMPRESSION BREAK";
   if(turn_signal)       return "TURN";
   return "RE-ACCEL";
}

string ResolveTrendEntryReason(const bool timing_entry,
                               const bool compression_break,
                               const bool turn_signal,
                               const bool early_entry,
                               const string pattern_name)
{
   if(early_entry)       return "EARLY ENTRY";
   if(timing_entry)      return "TIMED ENTRY";
   if(compression_break) return "COMPRESSION BREAK";
   if(turn_signal)       return "TURN";
   if(pattern_name != "") return pattern_name;
   return "RE-ACCEL";
}

string EntryTypeName(const ENUM_ENTRY_TYPE entry_type)
{
   if(entry_type == ENTRY_EARLY) return "EARLY";
   if(entry_type == ENTRY_CHASE) return "CHASE";
   if(entry_type == ENTRY_ADD) return "ADD";
   if(entry_type == ENTRY_RANGE) return "RANGE";
   return "NORMAL";
}

ENUM_ENTRY_TYPE ClassifyInitialEntry(const int side, const string reason)
{
   if(StringFind(reason, "EARLY") >= 0)
      return ENTRY_EARLY;

   double slow_ma[];
   ArrayResize(slow_ma, 2);
   ArraySetAsSeries(slow_ma, true);
   const double close_price = iClose(_Symbol, AUTO_TF, 1);
   if(g_slow_ma_handle != INVALID_HANDLE &&
      MarketDataCopyBuffer(g_slow_ma_handle, 0, 0, 2, slow_ma) >= 2 &&
      IsChasingSignal(side, close_price, slow_ma[1]))
      return ENTRY_CHASE;

   // A continuation/re-acceleration entry far from the original turn is also
   // treated conservatively even when the MA-distance test is borderline.
   if(StringFind(reason, "RE-ACCEL") >= 0)
      return ENTRY_CHASE;
   return ENTRY_NORMAL;
}

string ClassifyEntryQuality(const ENUM_ENTRY_TYPE entry_type,
                            const int score)
{
   if(entry_type == ENTRY_ADD) return "D";
   if(entry_type == ENTRY_CHASE) return "C";
   if(entry_type == ENTRY_EARLY) return score >= InpEntryScore ? "B" : "C";
   if(score >= InpConfirmEntryScore) return "A";
   return "B";
}
//============== END TREND STRATEGY MODULE ================

// Independent strategy entry wrappers. These are the only AUTO entry routes
// selected by the chart menu. Both finish through FastOrderEngine().
void TrendEntryEngine()
{
   ProcessTrendClosedBar(false, true);
}


// ===== Functions moved from Common.mqh during ownership audit =====
bool FastOrderEngine(const int side,
                     const int score,
                     const string reason,
                     const double signal_price,
                     const bool append_entry_quality)
{
   // The calling engine supplies one fully confirmed BUY/SELL signal.
   if(!OpenPosition(side, reason))
      return false;

   string entry_reason = reason;
   if(append_entry_quality)
   {
      g_entry_quality = ClassifyEntryQuality(g_entry_type, score);
      entry_reason += " [" + EntryTypeName(g_entry_type) + "/" +
                      g_entry_quality + "]";
   }

   DrawAutoTradeArrow(side, "ENTRY", score, entry_reason,
                      g_initial_entry_price);
   return true;
}

// v7.86: legacy 3X creation authority removed. Cancellation is retained only
// to clear stale pre-v7.86 pending state after upgrade/reinitialization.
void EntryEngineCancelRangeInitial(const int cancelled_side,
                                   const string cancel_reason,
                                   const bool hard_counter_reset)
{
   ResetRangeDirectionConfirmation();
   if(hard_counter_reset)
      ResetInitialSignalWindow(cancelled_side);
   else
      TrimInitialSignalWindow(cancelled_side,2);

   if(ManagedPositionSide()==0 &&
      (g_trade_cycle.state==JTA_CYCLE_SIGNAL_ACCUMULATING ||
       g_trade_cycle.state==JTA_CYCLE_BREAKOUT_WAIT ||
       g_trade_cycle.state==JTA_CYCLE_ENTRY_PENDING))
      TradeCycleClear(cancel_reason);
}

bool EntryEngineApproveTrendInitial(const int side,
                                    const bool strategy_path_ready,
                                    const bool three_signal_path,
                                    const bool auto_start_bias_ok,
                                    const bool auto_direction_allowed,
                                    const int score,
                                    const string path_reason,
                                    string &block_reason)
{
   block_reason = "";
   const int signal_count = side>0 ? g_range_long_signal_count : g_range_short_signal_count;
   if(!strategy_path_ready)
   {
      block_reason = "NO_APPROVED_TREND_ENTRY_PATH";
      return false;
   }
   if(!g_auto_trading)
      block_reason = "ORDER_BLOCK_AUTO_OFF";
   else if(!auto_direction_allowed)
      block_reason = "ORDER_BLOCK_DIRECTION";
   else if(!three_signal_path && !auto_start_bias_ok)
      block_reason = "PRE_DIRECTION_BIAS_BLOCK";

   if(block_reason != "")
   {
      WriteSignalDecisionLog(side,"TREND_ENTRY_PERMISSION",signal_count,score,
                             "BLOCKED",block_reason,false,false,0,-1.0);
      WriteUnifiedOrderSignalAudit("TREND_ENTRY_PERMISSION",
         side>0?g_current_long_signal_event_id:g_current_short_signal_event_id,
         "INITIAL",side,signal_count,signal_count,"BLOCKED",block_reason,
         false,false,0,0);
      return false;
   }

   WriteSignalDecisionLog(side,"TREND_ENTRY_PERMISSION",signal_count,score,
                          "PASS",path_reason,false,false,0,-1.0);
   return true;
}

// Fast-momentum remains subject to the existing PositionManager strategy
// filters, but Runtime no longer bypasses EntryEngine ownership.
bool EntryEngineSubmitFastMomentum(const int side,const string reason,const double signal_price)
{
   g_entry_strategy_preapproved=false;
   return FastOrderEngine(side,0,reason,signal_price,false);
}

// v3.26: Compute an M3 SMA from completed bars only. Evaluated only when a


// v3.91: Generic completed-bar SMA helper used only by entry-quality
// diagnostics/gates.  It does not create a new trend engine.
bool EntryEngineTimeframeSMA(const ENUM_TIMEFRAMES timeframe,
                             const int period,
                             double &value)
{
   value=0.0;
   const int p=MathMax(2,period);
   double close[];
   ArrayResize(close,p);
   ArraySetAsSeries(close,true);
   if(CopyClose(_Symbol,timeframe,1,p,close)<p)
      return false;

   double sum=0.0;
   for(int i=0;i<p;i++)
   {
      if(close[i]<=0.0) return false;
      sum+=close[i];
   }
   value=sum/(double)p;
   return value>0.0;
}

// v3.91: RANGE-specific forward barrier. RANGE entries are
// M2 completed-bar setups with an M5 context, so use the nearest completed M2
// structural swing/range edge plus forward M5 MA22/70/111 instead.
// This is entry quality only; it does not alter signal scoring or trend state.
bool EntryEngineRangeNearestForwardBarrier(const int side,
                                           const double entry_price,
                                           double &barrier,
                                           string &barrier_type)
{
   barrier=0.0;
   barrier_type="NONE";
   if(side==0 || entry_price<=0.0)
      return false;

   const int lookback=MathMax(12,InpRangeLocationLookbackBars);
   MqlRates bars[];
   ArrayResize(bars,lookback);
   ArraySetAsSeries(bars,true);
   const int copied=MarketDataCopyRates(_Symbol,AUTO_TF,1,lookback,bars);
   if(copied<8)
      return false;

   double best_distance=DBL_MAX;

   // Prefer a local completed-M2 structural swing in front of the entry.
   for(int i=1;i<copied-1;i++)
   {
      double level=0.0;
      bool local=false;
      if(side>0)
      {
         local=bars[i].high>=bars[i-1].high &&
               bars[i].high>=bars[i+1].high;
         level=bars[i].high;
         if(!local || level<=entry_price) continue;
      }
      else
      {
         local=bars[i].low<=bars[i-1].low &&
               bars[i].low<=bars[i+1].low;
         level=bars[i].low;
         if(!local || level>=entry_price) continue;
      }

      const double distance=MathAbs(level-entry_price);
      if(distance<best_distance)
      {
         best_distance=distance;
         barrier=level;
         barrier_type=side>0?"M2_SWING_HIGH":"M2_SWING_LOW";
      }
   }

   // If no clean local swing exists, the closest recent completed-M2 extreme
   // is still a useful RANGE obstacle.
   if(barrier<=0.0)
   {
      for(int i=0;i<copied;i++)
      {
         const double level=side>0?bars[i].high:bars[i].low;
         if((side>0 && level<=entry_price) ||
            (side<0 && level>=entry_price))
            continue;

         const double distance=MathAbs(level-entry_price);
         if(distance<best_distance)
         {
            best_distance=distance;
            barrier=level;
            barrier_type=side>0?"M2_RECENT_HIGH":"M2_RECENT_LOW";
         }
      }
   }

   // RANGE forward-barrier MA levels use the selected unified trading timeframe.
   // Only a MA physically in front of the proposed order can be a forward barrier.
   const int periods[3]={InpSlowMAPeriod,InpTrendMAPeriod,InpSupportMAPeriod};
   const string names[3]={"TF_MA22","TF_MA70","TF_MA111"};
   for(int k=0;k<3;k++)
   {
      double level=0.0;
      if(!EntryEngineTimeframeSMA(AUTO_TF,periods[k],level))
         continue;
      if((side>0 && level<=entry_price) ||
         (side<0 && level>=entry_price))
         continue;

      const double distance=MathAbs(level-entry_price);
      if(distance<best_distance)
      {
         best_distance=distance;
         barrier=level;
         barrier_type=names[k];
      }
   }

   return barrier>0.0 && best_distance<DBL_MAX;
}

// v3.86/v3.91: Common INITIAL entry-quality snapshot. ENTRY_COST_R is the
// existing barrier; RANGE now uses the selected unified-TF barrier model.
// RANGE-specific forward room as a temporary WAIT gate.
bool EntryEngineInitialQualityMetrics(const int side,
                                      const double entry_price,
                                      const double volume,
                                      double &risk_distance,
                                      double &spread_price,
                                      double &entry_cost_r,
                                      double &barrier,
                                      string &barrier_type,
                                      double &forward_reward_r,
                                      double &net_reward_r,
                                      int &m3_trend_side)
{
   risk_distance=0.0;
   spread_price=0.0;
   entry_cost_r=0.0;
   barrier=0.0;
   barrier_type="NONE";
   forward_reward_r=-1.0;
   net_reward_r=-1.0;
   m3_trend_side=0;

   if(side==0 || entry_price<=0.0 || volume<=0.0)
      return false;

   const double ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK);
   const double bid=SymbolInfoDouble(_Symbol,SYMBOL_BID);
   if(ask<=0.0 || bid<=0.0 || ask<bid)
      return false;

   risk_distance=MathMax(_Point,StopDistancePrice(entry_price,volume));
   spread_price=MathMax(0.0,ask-bid);
   entry_cost_r=risk_distance>0.0 ? spread_price/risk_distance : 0.0;

   bool barrier_ready=false;
   barrier_ready=EntryEngineRangeNearestForwardBarrier(
         side,entry_price,barrier,barrier_type);

   if(barrier_ready)
   {
      const double reward_distance=side>0 ?
         MathMax(0.0,barrier-entry_price) :
         MathMax(0.0,entry_price-barrier);
      forward_reward_r=risk_distance>0.0 ? reward_distance/risk_distance : 0.0;
      net_reward_r=MathMax(0.0,forward_reward_r-entry_cost_r);
   }

   return true;
}


// v1.95: EntryEngine is the sole strategy-level gateway for initial and
// additional entries. PositionManager performs execution-safety checks only
// for these preapproved decisions; it must not recalculate signal quality.
bool EntryEngineSubmitInitial(const int side,const int score,const string reason,
                              const double signal_price,const bool append_entry_quality)
{
   // M3 AUTO has one and only one execution context. The broad authority flag
   // is not sufficient because legacy/runtime callers can execute later in the
   // same tick. Only M3AutoEngine may assert this narrow context.
   if(M3AutoEngineIsActive() && !g_m3_auto_execution_context_active)
      return false;

   // forward-room is no longer a second strategy-quality veto here.

   TradeCycleCaptureEntryStrategy(g_selected_strategy);

   g_entry_strategy_preapproved=true;
   const bool ok=FastOrderEngine(side,score,reason,signal_price,append_entry_quality);
   g_entry_strategy_preapproved=false;
   return ok;
}

// v8.267: retired legacy RANGE 3X FINAL breakout order path. M3 AUTO is the sole strategy-level order router.

// v7.94: EntryEngine owns RANGE setup formation and entry timing.  A setup is
// READY only while the current persistence episode has >=4 Accepted FINALs in
// the last five completed bars and the canonical MACD Final Wave is on the same
// side.  Order permission is the READY false->true edge, not a fixed re-entry
// count.  Therefore a setup that stays 4/5 or 5/5 cannot immediately re-enter
// after a Broker/Risk close; it must first fall out of READY and form again.
void EntryEngineUpdateRangeDensitySetupState(const string event_id)
{
   const bool long_now=
      g_range_persistent_direction==1 &&
      g_range_final_density_long_5>=4 &&
      g_range_final_density_macd_wave>0.0;
   const bool short_now=
      g_range_persistent_direction==-1 &&
      g_range_final_density_short_5>=4 &&
      g_range_final_density_macd_wave<0.0;

   g_range_density_fresh_long=long_now && !g_range_density_ready_long;
   g_range_density_fresh_short=short_now && !g_range_density_ready_short;

   if(g_range_density_fresh_long)
      WriteUnifiedOrderSignalAudit(
         "RANGE_DENSITY_SETUP_EDGE",event_id,"INITIAL",1,
         g_range_final_density_long_5,5,"FRESH_READY",
         StringFormat("DENSITY=%d/5|MACD=%.8f",
            g_range_final_density_long_5,g_range_final_density_macd_wave),
         false,false,0,g_trade_cycle.position_id);
   if(g_range_density_fresh_short)
      WriteUnifiedOrderSignalAudit(
         "RANGE_DENSITY_SETUP_EDGE",event_id,"INITIAL",-1,
         g_range_final_density_short_5,5,"FRESH_READY",
         StringFormat("DENSITY=%d/5|MACD=%.8f",
            g_range_final_density_short_5,g_range_final_density_macd_wave),
         false,false,0,g_trade_cycle.position_id);

   g_range_density_ready_long=long_now;
   g_range_density_ready_short=short_now;
}

// v8.02: RANGE density has no broker-order authority.
// It remains diagnostic-only for CSV/analysis; INITIAL and ADD use price structure.

void EntryEngineResetRangeStructureAdditional(const string reason)
{
   if(g_range_structure_add_pending && reason!="")
   {
      WriteUnifiedOrderSignalAudit(
         "RANGE_STRUCTURE_ADD_RESET",g_range_structure_add_source_event_id,
         "ADD",g_range_structure_add_side,0,0,"RESET",reason,
         false,false,0,g_trade_cycle.position_id);
   }
   g_range_structure_add_pending=false;
   g_range_structure_add_side=0;
   g_range_structure_add_break_price=0.0;
   g_range_structure_add_setup_bar=0;
   g_range_structure_add_last_attempt_bar=0;
   g_range_structure_add_break_confirmed=false;
   g_range_structure_add_source_event_id="";
}

// v8.02: RANGE ADD authorization is price-structure continuation only.
// StateEvaluationEngine owns the closed-bar swing calculation. EntryEngine
// freezes that already-computed reference and never re-scores MACD/FINALs.
bool EntryEngineUpdateRangeStructureAdditional(const int side,
                                                const string event_id)
{
   // M3 AUTO owns same-direction ADD. Do not arm legacy RANGE structure ADD
   // state while the M3 controller is active.
   if(M3AutoEngineIsActive())
      return false;

   if(g_selected_strategy!=STRATEGY_RANGE || side==0 ||
      ManagedPositionSide()!=side || !g_auto_trading ||
      g_initial_entry_was_trigger)
   {
      if(ManagedPositionSide()==0)
         EntryEngineResetRangeStructureAdditional("POSITION_FLAT");
      return false;
   }

   const int stage=g_additional_entry_filled_count+1;
   if(stage<1 || stage>g_max_additional_entries)
   {
      EntryEngineResetRangeStructureAdditional("ADD_CAPACITY_REACHED");
      return false;
   }

   // Keep one immutable continuation reference until it is consumed/reset.
   if(g_range_structure_add_pending)
      return g_range_structure_add_side==side;

   if(g_assist_state.bar_time<=0 || g_assist_state.timeframe!=AUTO_TF)
      return false;

   const bool pullback_ready=side>0 ? g_assist_state.pullback_long_ready :
                                      g_assist_state.pullback_short_ready;
   const double reference=side>0 ? g_assist_state.continuation_break_high :
                                   g_assist_state.continuation_break_low;
   if(!pullback_ready || reference<=0.0)
      return false;

   g_range_structure_add_pending=true;
   g_range_structure_add_side=side;
   g_range_structure_add_break_price=reference;
   g_range_structure_add_setup_bar=g_assist_state.bar_time;
   g_range_structure_add_last_attempt_bar=0;
   g_range_structure_add_break_confirmed=false;
   g_range_structure_add_source_event_id=event_id;

   // Preserve the existing ADD audit/PositionManager compatibility fields.
   g_add_same_direction_signal_count=1;
   g_add_second_signal_event_id=event_id;
   g_add_entry_source_event_id=event_id;

   WriteUnifiedOrderSignalAudit(
      "RANGE_STRUCTURE_ADD_ARMED",event_id,"ADD",side,stage,stage,
      "ARMED",
      side>0 ?
         StringFormat("HL_PULLBACK|WAIT_RECENT_SWING_HIGH_BREAK|REF=%.*f",_Digits,reference) :
         StringFormat("LH_PULLBACK|WAIT_RECENT_SWING_LOW_BREAK|REF=%.*f",_Digits,reference),
      false,false,0,g_trade_cycle.position_id);
   return true;
}

// Tick-routed continuation confirmation. The structural reference is frozen
// on a completed bar; one execution attempt per completed decision bar avoids
// repeated safety/log spam while preserving retry after temporary blocks.
void EntryEngineProcessRangeStructureAdditionalTick()
{
   if(M3AutoEngineIsActive())
   {
      if(g_range_structure_add_pending)
         EntryEngineResetRangeStructureAdditional("M3_AUTO_OWNS_ADD");
      return;
   }

   if(!g_range_structure_add_pending || g_range_structure_add_side==0 ||
      g_selected_strategy!=STRATEGY_RANGE || !g_auto_trading)
      return;

   const int side=ManagedPositionSide();
   if(side==0 || side!=g_range_structure_add_side)
   {
      EntryEngineResetRangeStructureAdditional("POSITION_SIDE_CHANGED");
      return;
   }

   if(!g_jro_market.valid || g_jro_market.tick.bid<=0.0)
      return;

   const double reference=g_range_structure_add_break_price;
   const double bid=g_jro_market.tick.bid;
   if(reference<=0.0)
      return;

   if(!g_range_structure_add_break_confirmed)
   {
      const bool crossed=side>0 ? bid>reference : bid<reference;
      if(!crossed)
         return;

      g_range_structure_add_break_confirmed=true;
      WriteUnifiedOrderSignalAudit(
         "RANGE_STRUCTURE_ADD_PRICE_CONFIRMED",g_range_structure_add_source_event_id,
         "ADD",side,1,1,"CONFIRMED",
         side>0 ?
            StringFormat("RECENT_SWING_HIGH_BROKEN|REF=%.*f|BID=%.*f",_Digits,reference,_Digits,bid) :
            StringFormat("RECENT_SWING_LOW_BROKEN|REF=%.*f|BID=%.*f",_Digits,reference,_Digits,bid),
         false,false,0,g_trade_cycle.position_id);
   }

   if(!IsCooldownComplete() || !AutoDirectionAllows(side))
      return;

   const datetime decision_bar=g_assist_state.bar_time;
   if(decision_bar<=0 || g_range_structure_add_last_attempt_bar==decision_bar)
      return;
   g_range_structure_add_last_attempt_bar=decision_bar;

   const int stage=g_additional_entry_filled_count+1;
   if(stage<1 || stage>g_max_additional_entries)
   {
      EntryEngineResetRangeStructureAdditional("ADD_CAPACITY_REACHED");
      return;
   }

   g_add_same_direction_signal_count=1;
   g_add_second_signal_event_id=g_range_structure_add_source_event_id;
   g_add_entry_source_event_id=g_range_structure_add_source_event_id;
   const string reason=StringFormat(
      "RANGE ADD%d PRICE-STRUCTURE CONTINUATION",stage);

   WriteUnifiedOrderSignalAudit(
      "RANGE_STRUCTURE_ADD_READY",g_range_structure_add_source_event_id,
      "ADD",side,stage,stage,"READY",
      StringFormat("STAGE=%d|BREAK_REF=%.*f",stage,_Digits,reference),
      false,false,0,g_trade_cycle.position_id);

   if(!EntryEngineSubmitAdditional(side,stage,reason))
      return;

   EntryEngineResetRangeStructureAdditional("");
}

bool EntryEngineSubmitAdditional(const int side,const int stage,const string reason)
{
   // ADD has the same narrow execution-context boundary as INITIAL.
   if(M3AutoEngineIsActive() && !g_m3_auto_execution_context_active)
      return false;

   // v8.140: legacy Trigger-origin INITIAL cycles remain single-entry, but
   // M3 AUTO ACCEL is an explicit ADD authorization and must pass this gateway.
   if(g_initial_entry_was_trigger && !g_m3_auto_execution_context_active)
      return false;
   g_entry_strategy_preapproved=true;
   const bool ok=OpenAdditionalPosition(side,stage,reason);
   g_entry_strategy_preapproved=false;
   return ok;
}


// v2.95: SignalEngine supplies trend/add evidence; EntryEngine owns final
// additional-entry approval and submission. Conditions are unchanged.
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
                                        const string lifecycle_pattern_detail)
{
   if(g_initial_entry_was_trigger)
      return false;

   if(g_auto_trading && (add_stage_two || add_stage_three) &&
      add_structure_ok && closed_auto_bar>0 &&
      closed_auto_bar!=g_last_add_attempt_bar)
   {
      if(!add_chase_promoted)
         NotifyPositionState((position_side>0 ? "LONG " : "SHORT ") +
            "ADD BLOCKED: CHASE NOT TREND-PROMOTED");
      else if(!add_pattern_ok)
         NotifyPositionState((position_side>0 ? "LONG " : "SHORT ") +
            "ADD BLOCKED: TREND FATIGUE | " + lifecycle_pattern_detail);
      else if(no_trade_zone)
         NotifyPositionState((position_side>0 ? "LONG " : "SHORT ") +
            StringFormat("ADD BLOCKED: NO TRADE ZONE | FLAGS %d",no_trade_flags));
      else if(!add_confident)
         NotifyPositionState((position_side>0 ? "LONG " : "SHORT ") +
            StringFormat("ADD BLOCKED: CONF %d / OPP %d",
                         add_confidence,opposite_add_confidence));
   }

   if(!(g_auto_trading && g_position_strategy==STRATEGY_TREND &&
        add_chase_promoted && add_market_filter_ok && add_structure_ok &&
        (add_stage_two || add_stage_three) && !oversized &&
        closed_auto_bar>0 && closed_auto_bar!=g_last_add_attempt_bar))
      return false;

   g_last_add_attempt_bar=closed_auto_bar;
   const int stage=add_stage_two ? 2 : 3;
   const string add_reason=position_side>0 ?
      (add_stage_two ? "MA22 PULLBACK SUPPORT + BUY DELTA" :
                       "PRIOR HIGH BREAK + BUY VOLUME EXPANSION") :
      (add_stage_two ? "MA22 REJECTION + SELL DELTA" :
                       "PRIOR LOW BREAK + SELL VOLUME EXPANSION");

   if(!EntryEngineSubmitAdditional(position_side,stage,add_reason))
   {
      NotifyPositionState((position_side>0 ? "LONG " : "SHORT ") +
         "STAGE " + IntegerToString(stage) + " ENTRY WAIT: " + add_reason);
      return false;
   }
   return true;
}



#endif // __JOON_ENTRYENGINE_MQH__
