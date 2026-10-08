//+------------------------------------------------------------------+
//| PositionManager.mqh                                          |
//| Joon Trend/Range AutoTrader modular component                    |
//+------------------------------------------------------------------+
#ifndef __JOON_POSITIONMANAGER_MQH__
#define __JOON_POSITIONMANAGER_MQH__


//+------------------------------------------------------------------+
bool ManagedPosition(ulong &ticket,
                     ENUM_POSITION_TYPE &position_type,
                     double &open_price,
                     double &stop_loss,
                     double &take_profit,
                     datetime &position_time)
{
   JRO_RefreshPositionSnapshot(_Symbol, InpMagicNumber);
   if(!g_jro_positions.has_managed)
      return false;
   ticket = g_jro_positions.first_ticket;
   position_type = g_jro_positions.first_type;
   open_price = g_jro_positions.first_open_price;
   stop_loss = g_jro_positions.first_sl;
   take_profit = g_jro_positions.first_tp;
   position_time = g_jro_positions.first_position_time;
   return true;
}

//+------------------------------------------------------------------+
int ManagedPositionSide()
{
   JRO_RefreshPositionSnapshot(_Symbol, InpMagicNumber);
   return g_jro_positions.side;
}

//+------------------------------------------------------------------+
double ManagedFloatingProfit()
{
   JRO_RefreshPositionSnapshot(_Symbol, InpMagicNumber);
   return g_jro_positions.floating_profit;
}

//+------------------------------------------------------------------+
bool ForeignPositionExists()
{
   JRO_RefreshPositionSnapshot(_Symbol, InpMagicNumber);
   return g_jro_positions.has_foreign;
}

//+------------------------------------------------------------------+


//+------------------------------------------------------------------+


//+------------------------------------------------------------------+
bool CloseManagedPosition(const string reason)
{
   const int closing_side = ManagedPositionSide();
   if(closing_side == 0)
      return false;
   if(g_exit_order_in_progress)
   {
      WriteUnifiedOrderSignalAudit("EXIT_GATE",g_exit_source_event_id,"EXIT",closing_side,0,0,"BLOCKED","EXIT_ORDER_IN_PROGRESS",true,false,0,0);
      return false;
   }

   const double closing_price = closing_side > 0 ?
      SymbolInfoDouble(_Symbol, SYMBOL_BID) :
      SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   g_pending_exit_reason = reason;
   g_pending_exit_reason_time = TimeCurrent();

   // v7.88: strategy reversal authority is already resolved upstream. This
   // function only distinguishes incremental layer-profit-lock exits from
   // normal full managed exits; it no longer re-judges opposite FINAL counts.
   string upper_reason = reason;
   StringToUpper(upper_reason);
   const bool layer_profit_lock_exit =
      StringFind(upper_reason, "LAYER PROFIT LOCK") >= 0;

   const bool hedging =
      AccountInfoInteger(ACCOUNT_MARGIN_MODE) ==
      ACCOUNT_MARGIN_MODE_RETAIL_HEDGING;

   // v2.36: a profit-lock event is deliberately incremental.
   // Close only the newest ADD layer, realize its profit, then keep the older
   // ADD/INITIAL layers in the trend. A later profit-lock event removes the
   // next layer. Safety/strategy exits still use the original full LIFO unwind.
   if(layer_profit_lock_exit && g_additional_entry_count > 0 &&
      ManagedPositionSide() != 0)
   {
      bool layer_closed=false;
      if(hedging)
      {
         const ulong newest_ticket=NewestManagedPositionTicket(closing_side);
         layer_closed=newest_ticket>0 &&
                      ExitClosePosition(newest_ticket) &&
                      TradeResultSucceeded();
      }
      else
      {
         // Netting accounts merge fills. Realize exactly the newest virtual
         // ADD layer using its stored actual filled volume.
         const int newest_stage=JTAAddLayerLatestActiveStage();
         const double layer_volume=JTAAddLayerVolume(newest_stage);
         layer_closed=CloseManagedVolume(closing_side,
                                         NormalizeVolume(layer_volume>0.0 ? layer_volume : g_ui_lots),
                                         "LAYER PROFIT LOCK: " + reason);
      }

      if(!layer_closed)
      {
         RegisterOrderFailure("LAYER PROFIT LOCK CLOSE FAILED");
         return false;
      }

      const int closed_layer_stage=JTAAddLayerLatestActiveStage();
      g_additional_entry_count=MathMax(0,g_additional_entry_count-1);
      g_has_add_entry=g_additional_entry_count>0;
      JTAAddLayerClear(closed_layer_stage);
      g_consecutive_order_failures=0;
      TradeCycleSyncAddCounter("");
      JRO_RefreshPositionSnapshot(_Symbol,InpMagicNumber,true);

      g_status=StringFormat("[PROFIT] %s ADD LAYER CLOSED | REMAINING ADD %d | INITIAL %s",
         closing_side>0?"LONG":"SHORT",g_additional_entry_count,
         g_additional_entry_count==0?"ONLY":"HELD");
      NotifyPositionState(g_status);
      WriteUnifiedOrderSignalAudit("EXIT_RESULT",g_exit_source_event_id,
         "ADD_LAYER",closing_side,0,g_additional_entry_count,
         "LAYER_CLOSED",reason,true,true,(long)trade.ResultRetcode(),0);
      return true;
   }

   // LIFO: remove every additional layer from newest to oldest first.
   while(g_additional_entry_count > 0 && ManagedPositionSide() != 0)
   {
      bool layer_closed = false;
      if(hedging)
      {
         const ulong newest_ticket = NewestManagedPositionTicket(closing_side);
         layer_closed = newest_ticket > 0 &&
                        ExitClosePosition(newest_ticket) &&
                        TradeResultSucceeded();
      }
      else
      {
         // Netting accounts merge fills. Close exactly the newest stored
         // virtual ADD layer volume; UI lot is fallback only for legacy state.
         const int newest_stage=JTAAddLayerLatestActiveStage();
         const double layer_volume=JTAAddLayerVolume(newest_stage);
         layer_closed = CloseManagedVolume(closing_side,
                                           NormalizeVolume(layer_volume>0.0 ? layer_volume : g_ui_lots),
                                           "LIFO LAYER: " + reason);
      }

      if(!layer_closed)
      {
         RegisterOrderFailure("LIFO LAYER CLOSE FAILED");
         return false;
      }

      const int closed_stage=JTAAddLayerLatestActiveStage();
      g_additional_entry_count--;
      g_has_add_entry = g_additional_entry_count > 0;
      JTAAddLayerClear(closed_stage);
      g_consecutive_order_failures = 0;
      JRO_RefreshPositionSnapshot(_Symbol, InpMagicNumber, true);
   }

   // v7.88: legacy INITIAL opposite-FINAL 2/2 hold gate removed.
   // SignalEngine now owns RANGE reversal lifecycle: opposite WATCH=EXIT-PREP,
   // opposite Accepted FIRST=managed EXIT. PositionManager must not re-judge
   // that strategy decision; safety/profit exits remain independently valid.

   if(ManagedPositionSide() != 0)
   {
      g_exit_source_event_id = closing_side>0 ? g_current_short_signal_event_id : g_current_long_signal_event_id;
      TradeCycleMarkExitPending(g_exit_source_event_id,reason);
      WriteUnifiedOrderSignalAudit("EXIT_REQUEST",g_exit_source_event_id,"EXIT",closing_side,g_initial_opposite_confirm_count,g_initial_opposite_confirm_count,"REQUESTED",reason,true,false,0,0);
      g_exit_order_in_progress = true;
      const ulong initial_ticket = NewestManagedPositionTicket(closing_side);
      if(initial_ticket == 0 ||
         !ExitClosePosition(initial_ticket) || !TradeResultSucceeded())
      {
         g_exit_order_in_progress = false;
         WriteUnifiedOrderSignalAudit("EXIT_RESULT",g_exit_source_event_id,"EXIT",closing_side,0,0,"FAILED",reason,true,false,(long)trade.ResultRetcode(),0);
         RegisterOrderFailure("INITIAL CLOSE FAILED");
         return false;
      }
      WriteUnifiedOrderSignalAudit("EXIT_RESULT",g_exit_source_event_id,"EXIT",closing_side,0,0,"SENT",reason,true,true,(long)trade.ResultRetcode(),0);
      g_consecutive_order_failures = 0;
      JRO_RefreshPositionSnapshot(_Symbol, InpMagicNumber, true);
   }

   // Keep the shared cooldown timestamp in the same AUTO_TF basis used by
   // IsCooldownComplete() and the legacy TREND/RANGE re-entry calculations.
   g_last_exit_bar_time = iTime(_Symbol, AUTO_TF, 0);
   g_exit_cooldown_bars =
      (StringFind(reason, "stop loss") >= 0 ? InpStopLossCooldownBars
                                            : InpCooldownBars);
   // Prevent an immediate same-direction RANGE re-entry after a profit/hold
   // exit in the same extension leg. A fresh completed-bar setup is required.
   if(g_position_strategy == STRATEGY_RANGE &&
      (StringFind(reason, "RANGE 3-SIGNAL") >= 0 ||
       StringFind(reason, "RANGE HOLD EXIT") >= 0 ||
       StringFind(reason, "RANGE PROFIT") >= 0))
      g_exit_cooldown_bars = MathMax(g_exit_cooldown_bars,
                                     MathMax(2, InpRangeProfitExitCooldownBars));
   // v1.98: do not grant re-entry permission on an exit request.
   // The permission is created only after OnTradeTransaction confirms that
   // the managed position is fully closed by an eligible GIVEBACK deal.
   // This keeps live trading and Strategy Tester lifecycle transitions equal.
   g_long_exit_pending = false;
   g_short_exit_pending = false;
   g_status=StringFormat("[EXIT] %s CLOSED | %s",
      closing_side>0?"LONG":"SHORT",reason);
   // v4.60: normal realized close notification is owned exclusively by
   // OnTradeTransaction(), which has the actual deal price/P&L/R.
   return true;
}

//+------------------------------------------------------------------+
ulong NewestManagedPositionTicket(const int side)
{
   ulong newest_ticket = 0;
   long newest_time_msc = -1;
   const ENUM_POSITION_TYPE wanted =
      side > 0 ? POSITION_TYPE_BUY : POSITION_TYPE_SELL;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket) ||
         PositionGetString(POSITION_SYMBOL) != _Symbol ||
         (ulong)PositionGetInteger(POSITION_MAGIC) != InpMagicNumber ||
         (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) != wanted)
         continue;
      const long time_msc = PositionGetInteger(POSITION_TIME_MSC);
      if(time_msc > newest_time_msc ||
         (time_msc == newest_time_msc && ticket > newest_ticket))
      {
         newest_time_msc = time_msc;
         newest_ticket = ticket;
      }
   }
   return newest_ticket;
}

//+------------------------------------------------------------------+
// WAIT requires a material raw-Delta reversal after a completed supportive bar.

// RANGE keeps the current v4.29 behavior and does not use this helper.

// v4.31: restore v4.19 RANGE INITIAL final execution-time raw Delta reversal WAIT.
// This helper is RANGE-only; RANGE ADD is untouched.
bool InitialRangeLiveDeltaReversalWait(const int side,
                                       string &detail)
{
   detail="NOT_APPLICABLE";
   if(side==0)
      return false;

   const int delta_handle = g_delta_handle;
   if(delta_handle==INVALID_HANDLE)
   {
      detail="DATA_NOT_READY";
      return false; // preserve prior entry behavior if live data is unavailable
   }

   const int lookback=8;
   const int need=lookback+2;
   double raw[],ema[];
   ArrayResize(raw,need);
   ArrayResize(ema,need);
   ArraySetAsSeries(raw,true);
   ArraySetAsSeries(ema,true);
   if(MarketDataCopyBuffer(delta_handle,2,0,need,raw)<need ||
      MarketDataCopyBuffer(delta_handle,3,0,need,ema)<need)
   {
      detail="DATA_NOT_READY";
      return false;
   }

   // Direction-normalized values: positive supports the proposed order.
   const double completed=(double)side*raw[1];
   const double live=(double)side*raw[0];
   const double live_ema=(double)side*ema[0];

   double avg_abs=0.0;
   for(int i=1;i<=lookback;i++)
      avg_abs+=MathAbs(raw[i]);
   avg_abs=MathMax(_Point,avg_abs/(double)lookback);

   // A reversal requires a real same-direction completed-bar impulse first.
   // This prevents a near-zero/noisy prior bar from becoming the baseline.
   const bool completed_supported=
      completed>0.0 && MathAbs(raw[1])>=avg_abs*0.20;

   const double opposite_magnitude=MathMax(0.0,-live);
   const double completed_magnitude=MathAbs(raw[1]);
   const double activity_ratio=opposite_magnitude/avg_abs;
   const double flip_ratio=
      opposite_magnitude/MathMax(_Point,completed_magnitude);

   // "Clear/rapid" reversal: at least half of normal recent activity and at
   // least 60% of the immediately completed same-direction Delta impulse.
   // This is intentionally stricter than a simple raw-sign flip.
   const bool material_opposite=
      live<0.0 &&
      activity_ratio>=0.50 &&
      flip_ratio>=0.60;

   const bool wait=completed_supported && material_opposite;

   detail=StringFormat(
      "MODE=%s | COMPLETED_DELTA=%.6f | LIVE_DELTA=%.6f | LIVE_EMA=%.6f | "
      "AVG_ABS_DELTA=%.6f | OPP_ACTIVITY_R=%.3f | FLIP_R=%.3f | "
      "COMPLETED_SUPPORT=%d | MATERIAL_OPPOSITE=%d",
      "RANGE",
      completed,live,live_ema,avg_abs,activity_ratio,flip_ratio,
      completed_supported?1:0,material_opposite?1:0);

   return wait;
}



bool OpenPosition(const int side,
                  const string reason)
{
   const int decision_signal_count = side > 0 ? g_range_long_signal_count : g_range_short_signal_count;
   const int decision_score = side > 0 ? g_last_long_score : g_last_short_score;
   const ENUM_TIMEFRAMES entry_tf = AUTO_TF;
   const datetime order_bar = iTime(_Symbol, entry_tf, 1);

   if(g_exit_order_in_progress)
   {
      WriteUnifiedOrderSignalAudit("ORDER_GATE",side>0?g_current_long_signal_event_id:g_current_short_signal_event_id,"INITIAL",side,decision_signal_count,decision_signal_count,"BLOCKED","EXIT_ORDER_IN_PROGRESS",false,false,0,0);
      return false;
   }

   if(g_entry_order_in_progress)
   {
      WriteSignalDecisionLog(side, "ORDER_GATE", decision_signal_count,
                             decision_score, "BLOCKED",
                             "ENTRY_ORDER_IN_PROGRESS", false, false, 0, -1.0);
      return false;
   }
   if(order_bar > 0 && g_last_initial_order_bar == order_bar &&
      g_last_initial_order_side == side)
   {
      WriteSignalDecisionLog(side, "ORDER_GATE", decision_signal_count,
                             decision_score, "BLOCKED",
                             "DUPLICATE_INITIAL_ENTRY_SAME_BAR", false, false, 0, -1.0);
      return false;
   }

   if(ManagedPositionSide() != 0)
   {
      WriteSignalDecisionLog(side, "ORDER_GATE", decision_signal_count,
                             decision_score, "BLOCKED",
                             "EXISTING_POSITION", false, false, 0, -1.0);
      return false;
   }

   const bool use_direction_confirm_lot_snapshot =
      StringFind(reason, "DIRECTION-CONFIRMED") >= 0 &&
      g_range_direction_confirm_pending &&
      g_range_direction_confirm_side == side &&
      g_range_direction_confirm_lots > 0.0;
   const double volume = NormalizeVolume(use_direction_confirm_lot_snapshot ?
                                         g_range_direction_confirm_lots : g_ui_lots);
   if(!EntrySafetyAllows(volume,side))
   {
      const string safety_reason = g_entry_safety_block_reason != "" ?
                                   g_entry_safety_block_reason : "ENTRY_SAFETY_BLOCK";
      WriteSignalDecisionLog(side, "ORDER_GATE", decision_signal_count,
                             decision_score, "BLOCKED",
                             safety_reason, false, false, 0, -1.0);
      WriteUnifiedOrderSignalAudit("ORDER_GATE",
         side>0?g_current_long_signal_event_id:g_current_short_signal_event_id,
         "INITIAL",side,decision_signal_count,decision_signal_count,
         "BLOCKED",safety_reason,false,false,0,0);
      const bool retryable_safety=
         safety_reason=="INVALID_QUOTE" ||
         safety_reason=="SPREAD_TOO_WIDE" ||
         safety_reason=="TERMINAL_TRADE_DISABLED" ||
         safety_reason=="MQL_TRADE_DISABLED" ||
         safety_reason=="ACCOUNT_TRADE_DISABLED";
      return false;
   }
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double entry = (side > 0 ? ask : bid);

   double range_location = 0.50;
   double range_high = 0.0, range_low = 0.0;
   const bool have_range = CalculateRangeLocation(entry, range_location,
                                                   range_high, range_low);
   const bool strong_breakout = have_range &&
      StrongRangeBreakoutForEntry(side, entry, range_high, range_low);
   const bool legacy_chase_reason =
      StringFind(reason, "FAST") >= 0 ||
      StringFind(reason, "BREAK") >= 0 ||
      StringFind(reason, "RE-ACCEL") >= 0 ||
      StringFind(reason, "MOMENTUM") >= 0;
   const bool trigger_entry =
      (g_selected_strategy==STRATEGY_RANGE &&
       StringFind(reason, "RANGE TRIGGER") >= 0);
   const bool chase_reason=trigger_entry ? false : legacy_chase_reason;
   const bool strict_persistence=strong_breakout || chase_reason;

   const bool range_three_signal_entry =
      StringFind(reason, "RANGE 3-SIGNAL") >= 0;
   const bool trend_three_signal_entry =
      StringFind(reason, "TREND 3-SIGNAL") >= 0;
   const bool range_strategy_entry =
      g_selected_strategy == STRATEGY_RANGE &&
      StringFind(reason, "RANGE") >= 0;
   // RANGE AUTO has already passed its own score, direction, MACD, delta and
   // structure gates. Re-applying TREND persistence/chase filters here caused
   // valid confirmed signals to be rejected before trade.Buy/trade.Sell.
   const bool short_term_entry = StringFind(reason, "SHORT-TERM") >= 0;
   // v8.136: M3 AUTO has already been authorized by the visible canonical M3 signal
   // router. Legacy signal-close execution filters must not re-veto that
   // order path. Broker/terminal safety, spread, SL feasibility and trade
   // retcode checks remain authoritative.
   const bool turn_pre_entry = StringFind(reason, "TURN PRE INITIAL") >= 0;
   const bool m3_auto_entry = StringFind(reason, "M3 AUTO") >= 0 || turn_pre_entry;
   const bool bypass_duplicate_strategy_filters =
      m3_auto_entry || short_term_entry || g_entry_strategy_preapproved ||
      (((range_three_signal_entry || trend_three_signal_entry) &&
        InpRangeThreeSignalBypassStrategyFilters) ||
       (range_strategy_entry && InpRangeApprovedEntryBypassStrategyFilters));

   // Strong breakout is only an exception to the ATR chase restriction. It no
   // longer bypasses delta exhaustion, cumulative delta dominance, MACD fade,
   // or edge absorption filters.
   string delta_block = "";
   if(!bypass_duplicate_strategy_filters &&
      !DeltaNotExhaustedForEntry(side, delta_block))
   {
      g_status = "ENTRY BLOCKED: " + delta_block;
      WriteSignalDecisionLog(side, "ORDER_GATE", decision_signal_count,
                             decision_score, "BLOCKED", g_status,
                             false, false, 0, range_location);
      return false;
   }

   string persistence_block = "";
   if(!bypass_duplicate_strategy_filters &&
      !DirectionalPersistenceAllowsEntry(side, entry, strict_persistence,
                                          have_range, range_high, range_low,
                                          persistence_block))
   {
      g_status = "ENTRY BLOCKED: " + persistence_block;
      WriteSignalDecisionLog(side, "ORDER_GATE", decision_signal_count,
                             decision_score, "BLOCKED", g_status,
                             false, false, 0, range_location);
      return false;
   }

   if(!bypass_duplicate_strategy_filters &&
      !strong_breakout && ATRChaseEntryBlocked(side, entry))
   {
      g_status = StringFormat("ENTRY BLOCKED: ATR CHASE | RANGE %.0f%%",
                              range_location * 100.0);
      WriteSignalDecisionLog(side, "ORDER_GATE", decision_signal_count,
                             decision_score, "BLOCKED", g_status,
                             false, false, 0, range_location);
      return false;
   }

   if(!bypass_duplicate_strategy_filters &&
      !strong_breakout && MACDDeceleratingForEntry(side))
   {
      g_status = "ENTRY BLOCKED: MACD DECELERATION";
      WriteSignalDecisionLog(side, "ORDER_GATE", decision_signal_count,
                             decision_score, "BLOCKED", g_status,
                             false, false, 0, range_location);
      return false;
   }

   const double signal_price = iClose(_Symbol, entry_tf, 1);
   // BTC quotes commonly use 0.01 points, so the generic 100-point guard
   // would reject a fill only $1 away from the closed signal bar. BTC entries
   // are submitted directly from the selected signal timeframe instead.
   const bool range_direction_confirmed_entry =
      (StringFind(reason, "DIRECTION-CONFIRMED") >= 0 ||
       StringFind(reason, "CONTINUATION-CONFIRMED") >= 0);
   const bool post_third_confirmed_entry = range_direction_confirmed_entry;
   // v4.32: post-third confirmed entries already require a third-signal
   // price break. Do not reject that confirming move again as Price Deviation.
   // v8.41: a short-term M3 breakout is intentionally executed from the
   // live trigger price. The generic signal-close deviation guard was
   // designed for legacy signal entries and can reject a valid M3 breakout
   // simply because the live price has moved beyond the closed-bar close.
   // Do not use that legacy gate for the dedicated short-term AUTO path.
   if(!m3_auto_entry && !short_term_entry && !post_third_confirmed_entry && !range_strategy_entry &&
      g_asset_profile != ASSET_BITCOIN &&
      InpMaximumEntryDeviationPoints > 0.0 &&
      signal_price > 0.0 &&
      MathAbs(entry - signal_price) / _Point >
      InpMaximumEntryDeviationPoints)
   {
      g_status = "ENTRY BLOCKED: PRICE DEVIATION";
      WriteSignalDecisionLog(side, "ORDER_GATE", decision_signal_count,
                             decision_score, "BLOCKED", g_status,
                             false, false, 0, range_location);
      return false;
   }
   // All modes keep the configured percentage SL. Before any INITIAL order,
   // reject the entry if the broker's current stop/freeze distance (including
   // the live bid/ask spread) would force the actual SL farther away than the
   // user's menu risk. Safety close remains the final fallback after a fill;
   // this gate prevents a known-impossible SL from being submitted at all.
   // v4.84: RANGE Trigger INITIAL uses a tighter fixed 0.14% broker SL.
   // This exception applies only to the Trigger INITIAL path; normal RANGE 3X,
   const double trigger_initial_sl_percent =
      JTATriggerSLPercentForStrategy(g_selected_strategy);
   const bool m3_structure_sl =
      StringFind(reason, "M3 AUTO") >= 0 &&
      g_m3_structural_sl_active &&
      g_m3_initial_structural_sl>0.0;
   const bool short_term_structure_sl=
      (StringFind(reason, "SHORT-TERM") >= 0) &&
      g_st_entry_armed &&
      g_st_entry_side==side &&
      g_st_entry_stop>0.0;
   const bool use_m3_structure_sl = m3_structure_sl;
   const bool use_3x_structure_sl=
      range_three_signal_entry &&
      g_initial_3x_structure_stop_active &&
      g_initial_3x_structure_stop_side==side &&
      g_initial_3x_structure_stop_price>0.0;

   const double structural_stop_price=
      use_m3_structure_sl ? g_m3_initial_structural_sl :
      (short_term_structure_sl ? g_st_entry_stop :
      (use_3x_structure_sl ? g_initial_3x_structure_stop_price : 0.0));

   const bool use_structural_sl = use_m3_structure_sl || short_term_structure_sl || use_3x_structure_sl;
   const double stop_distance =
      use_structural_sl ? MathAbs(entry-structural_stop_price) :
      (trigger_entry ?
       (entry * trigger_initial_sl_percent / 100.0) :
       StopDistancePrice(entry, volume));

   // v3.86-v3.91: measure execution cost and forward room before the INITIAL
   // EntryCostR.  RANGE additionally uses its own M2/M5 forward-barrier room
   double quality_risk_distance=0.0;
   double quality_spread_price=0.0;
   double quality_entry_cost_r=0.0;
   double quality_barrier=0.0;
   string quality_barrier_type="NONE";
   double quality_forward_reward_r=-1.0;
   double quality_net_reward_r=-1.0;
   int quality_m3_trend=0;
   const bool quality_ready=EntryEngineInitialQualityMetrics(
      side,entry,volume,
      quality_risk_distance,quality_spread_price,quality_entry_cost_r,
      quality_barrier,quality_barrier_type,
      quality_forward_reward_r,quality_net_reward_r,quality_m3_trend);

   const string quality_detail=StringFormat(
      "ENTRY=%.*f | BID=%.*f | ASK=%.*f | RISK_DISTANCE=%.8f | SPREAD_PRICE=%.8f | ENTRY_COST_R=%.4f | NEAREST_BARRIER=%.*f | BARRIER_TYPE=%s | FORWARD_REWARD_R=%.4f | NET_REWARD_R=%.4f | M3_TREND=%d | COST_MODEL=SPREAD_ONLY_PRETRADE",
      _Digits,entry,_Digits,bid,_Digits,ask,
      quality_risk_distance,quality_spread_price,quality_entry_cost_r,
      _Digits,quality_barrier,quality_barrier_type,
      quality_forward_reward_r,quality_net_reward_r,quality_m3_trend);

   WriteUnifiedOrderSignalAudit(
      "ENTRY_QUALITY",
      side>0?g_current_long_signal_event_id:g_current_short_signal_event_id,
      "INITIAL",side,decision_signal_count,decision_signal_count,
      quality_ready?"OBSERVED":"DATA_NOT_READY",quality_detail,
      false,false,0,0);

   // v4.65: EntryCostR is diagnostic-only for INITIAL orders.
   // Keep ENTRY_QUALITY metrics/CSV, but cost alone no longer WAITs or blocks


   // v4.18: RANGE Forward Reward remains diagnostic-only.
   // 3X + third-signal breakout now owns directional entry approval;
   // FORWARD_REWARD_R / NET_REWARD_R continue to be exported in ENTRY_QUALITY
   // but no longer WAIT or block an otherwise valid RANGE INITIAL order.

   double sl=0.0;
   if(use_structural_sl)
   {
      const double struct_tick=MathMax(_Point,SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE));
      const int struct_digits=(int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS);
      sl=side>0 ?
         NormalizeDouble(MathFloor(structural_stop_price/struct_tick)*struct_tick,struct_digits) :
         NormalizeDouble(MathCeil(structural_stop_price/struct_tick)*struct_tick,struct_digits);
   }
   else
      sl=ValidStopPrice(side,entry,stop_distance);
   const double broker_effective_distance =
      (sl>0.0 ? MathAbs(entry-sl) : 0.0);
   const double broker_minimum_distance = ProtectionMinimumDistance();
   const double tick_size =
      MathMax(_Point,SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE));
   const int price_digits=(int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS);

   // v3.71: compare the broker-legal SL against the menu SL after the menu
   // price itself has been converted to the symbol's executable tick grid.
   // This separates harmless one-tick normalization from a genuine widening
   // forced by live Bid/Ask spread, STOPS_LEVEL or FREEZE_LEVEL.
   const double raw_menu_sl=entry-side*stop_distance;
   double menu_executable_sl=0.0;
   if(side>0)
      menu_executable_sl=NormalizeDouble(
         MathFloor(raw_menu_sl/tick_size)*tick_size,price_digits);
   else if(side<0)
      menu_executable_sl=NormalizeDouble(
         MathCeil(raw_menu_sl/tick_size)*tick_size,price_digits);

   const double menu_executable_distance=
      (menu_executable_sl>0.0 ? MathAbs(entry-menu_executable_sl) : 0.0);
   const double price_epsilon=MathMax(_Point*0.1,tick_size*1.0e-6);
   const bool broker_forced_wider=
      side>0 ? (sl<menu_executable_sl-price_epsilon) :
      side<0 ? (sl>menu_executable_sl+price_epsilon) : true;
   const double bid_now=SymbolInfoDouble(_Symbol,SYMBOL_BID);
   const double ask_now=SymbolInfoDouble(_Symbol,SYMBOL_ASK);
   const double spread_now=MathMax(0.0,ask_now-bid_now);
   string sl_feasibility_detail=StringFormat(
      "INITIAL SL FEASIBILITY | MENU_RAW=%.6f%% | MENU_EXEC=%.6f%% | "
      "BROKER_MIN=%.6f%% | EFFECTIVE=%.6f%% | ENTRY=%.*f | BID=%.*f | ASK=%.*f | "
      "SPREAD=%.6f%% | MENU_RAW_SL=%.*f | MENU_EXEC_SL=%.*f | BROKER_SL=%.*f | "
      "TICK=%.*f | POINT=%.*f | STOPS=%d | FREEZE=%d",
      (entry>0.0 ? stop_distance/entry*100.0 : 0.0),
      (entry>0.0 ? menu_executable_distance/entry*100.0 : 0.0),
      (entry>0.0 ? broker_minimum_distance/entry*100.0 : 0.0),
      (entry>0.0 ? broker_effective_distance/entry*100.0 : 0.0),
      price_digits,entry,price_digits,bid_now,price_digits,ask_now,
      (entry>0.0 ? spread_now/entry*100.0 : 0.0),
      price_digits,raw_menu_sl,price_digits,menu_executable_sl,price_digits,sl,
      price_digits,tick_size,price_digits,_Point,
      (int)SymbolInfoInteger(_Symbol,SYMBOL_TRADE_STOPS_LEVEL),
      (int)SymbolInfoInteger(_Symbol,SYMBOL_TRADE_FREEZE_LEVEL));

   const double stop_quote=side>0 ? bid_now : ask_now;
   const double broker_legal_sl=side>0 ?
      (stop_quote-broker_minimum_distance) :
      (stop_quote+broker_minimum_distance);

   // v8.41: preserve the pullback-structure stop, but when the live spread
   // and broker STOPS/FREEZE rules make that exact price illegal, widen it
   // only to the nearest broker-legal price. This is not a strategy filter;
   // it is execution normalization. If that legal widening would exceed the
   // configured/menu risk distance, reject the order rather than silently
   // taking more risk.
   if(use_structural_sl && broker_legal_sl>0.0)
   {
      const bool needs_widen = side>0 ? (sl>broker_legal_sl+price_epsilon)
                                     : (sl<broker_legal_sl-price_epsilon);
      if(needs_widen)
      {
         const double widened_sl=side>0 ?
            NormalizeDouble(MathFloor(broker_legal_sl/tick_size)*tick_size,price_digits) :
            NormalizeDouble(MathCeil(broker_legal_sl/tick_size)*tick_size,price_digits);
         if(widened_sl>0.0)
         {
            const double widened_distance=MathAbs(entry-widened_sl);
            if(menu_executable_sl>0.0 && widened_distance<=menu_executable_distance+price_epsilon)
            {
               sl=widened_sl;
               g_st_entry_stop=sl;
            }
         }
      }
   }

   const bool structural_side_valid=
      !use_structural_sl || (side>0 ? sl<entry : sl>entry);
   const bool structural_broker_distance_valid=
      !use_structural_sl ||
      (side>0 ? sl<=stop_quote-broker_minimum_distance+price_epsilon :
                sl>=stop_quote+broker_minimum_distance-price_epsilon);

   if(side==0 || entry<=0.0 || stop_distance<=0.0 || sl<=0.0 ||
      (use_structural_sl ?
       (!structural_side_valid || !structural_broker_distance_valid ||
        (menu_executable_sl>0.0 && MathAbs(entry-sl)>menu_executable_distance+price_epsilon)) :
       (menu_executable_sl<=0.0 || broker_forced_wider)))
   {
      sl_feasibility_detail+=use_m3_structure_sl ?
         " | BLOCK=INVALID_M3_STRUCTURAL_SL" :
         (short_term_structure_sl ? " | BLOCK=INVALID_SHORT_TERM_STRUCTURE_SL" :
         (use_3x_structure_sl ? " | BLOCK=INVALID_3X_STRUCTURE_SL" :
         " | BLOCK=BROKER_REQUIRES_WIDER_SL"));
      g_status="ENTRY BLOCKED: BROKER REQUIRES WIDER SL";
      WriteSignalDecisionLog(side,"ORDER_GATE",decision_signal_count,
                             decision_score,"BLOCKED",
                             sl_feasibility_detail,false,false,0,
                             range_location);
      WriteUnifiedOrderSignalAudit("ENTRY_SL_FEASIBILITY",
         side>0?g_current_long_signal_event_id:g_current_short_signal_event_id,
         "INITIAL",side,decision_signal_count,decision_signal_count,
         "BLOCKED",sl_feasibility_detail,false,false,0,0);
return false;
   }
   sl_feasibility_detail+=use_m3_structure_sl ?
      " | PASS=M3_STRUCTURAL_SL" :
      (short_term_structure_sl ? " | PASS=SHORT_TERM_PULLBACK_STRUCTURE_SL" :
      (use_3x_structure_sl ? " | PASS=FIRST_FINAL_STRUCTURE_SL" :
      " | PASS=BROKER_WITHIN_MENU_EXEC"));
   WriteUnifiedOrderSignalAudit("ENTRY_SL_FEASIBILITY",
      side>0?g_current_long_signal_event_id:g_current_short_signal_event_id,
      "INITIAL",side,decision_signal_count,decision_signal_count,
      "PASS",sl_feasibility_detail,false,false,0,0);
   const double tp = 0.0;

   const double entry_average_range = MathMax(_Point, AverageClosedBarRange());
   // No candidate state is retained. CHASE classification uses only the
   // current confirmed signal and current market extension.
   const bool chase_candidate =
      (!range_three_signal_entry && !trend_three_signal_entry &&
       (strong_breakout || chase_reason));
   // ENTRY_CHASE is reserved for an actual StrongRangeBreakoutForEntry()
   // extension at the order price, so CHASE Early Stop does not affect every



   // v4.31: restore v4.19 RANGE INITIAL live Delta emergency WAIT.
   // v4.68 RANGE simplification: no live-Delta or other strategy re-gate after
   // either approved RANGE entry signal. Broker/order safety remains downstream.
   const bool range_live_delta_gate = false;
   string range_live_delta_reversal_detail="";
   if(range_live_delta_gate &&
      InitialRangeLiveDeltaReversalWait(
         side,range_live_delta_reversal_detail))
   {
      g_status="RANGE ENTRY WAIT: LIVE DELTA REVERSAL";
      const string wait_reason=
         "LIVE_DELTA_REVERSAL_WAIT | "+range_live_delta_reversal_detail;
      WriteSignalDecisionLog(
         side,"ORDER_GATE",decision_signal_count,decision_score,
         "BLOCKED",wait_reason,false,false,0,range_location);
      WriteUnifiedOrderSignalAudit(
         "LIVE_DELTA_REVERSAL_GATE",
         side>0?g_current_long_signal_event_id:g_current_short_signal_event_id,
         "INITIAL",side,decision_signal_count,decision_signal_count,
         "WAIT",wait_reason,false,false,0,0);
      return false;
   }
   if((bool)MQLInfoInteger(MQL_TESTER))
      PrintFormat("[JTA ORDER REQUEST] %s | SCORE=%d | COUNT=%d | LOT=%.2f | SL=%.*f | REASON=%s",
                  side>0 ? "LONG" : "SHORT",decision_score,decision_signal_count,
                  volume,_Digits,sl,reason);

   // v7.39: one INITIAL broker attempt per completed TRADE-TF bar.
   // The duplicate gate already existed, but its state was never populated.
   if(order_bar>0)
   {
      g_last_initial_order_bar=order_bar;
      g_last_initial_order_side=side;
   }

   bool result = false;
   if(side > 0)
      result = TradeExecuteBuy(volume, _Symbol, 0.0, sl, tp, reason);
   else
      result = TradeExecuteSell(volume, _Symbol, 0.0, sl, tp, reason);

   // v3.36: Never bypass the pre-entry SL feasibility policy by retrying a
   // rejected INITIAL order without SL. If the broker invalidates the stop
   // between quote capture and order validation, fail this attempt safely.
   // The next normal entry evaluation can retry only after feasibility passes
   // again with a fresh quote.
   if((!result || !TradeResultSucceeded()) &&
      trade.ResultRetcode() == TRADE_RETCODE_INVALID_STOPS)
   {
      PrintFormat("ENTRY INVALID STOPS BLOCK | side=%d | requested_sl=%.*f | NO_NAKED_RETRY",
                  side, _Digits, sl);
   }

   WriteUnifiedOrderSignalAudit("ORDER_REQUEST",side>0?g_current_long_signal_event_id:g_current_short_signal_event_id,"INITIAL",side,decision_signal_count,decision_signal_count,"REQUESTED",reason,true,false,0,0);
   if(!result || !TradeResultSucceeded())
   {
      g_initial_entry_was_trigger=false;
      g_initial_trigger_sl_percent=0.0;
      if(range_direction_confirmed_entry && g_range_break_confirmed)
      {
         g_range_break_order_result = false;
         if(trade.ResultPrice() > 0.0)
            g_range_break_order_price = trade.ResultPrice();
      }
      g_entry_order_in_progress = false;
      if(g_trade_cycle.third_signal_time>0)
         g_trade_cycle.state=JTA_CYCLE_BREAKOUT_WAIT;
      else
         g_trade_cycle.state=JTA_CYCLE_SIGNAL_ACCUMULATING;
      g_trade_cycle.updated_time=TimeCurrent();
      WriteUnifiedOrderSignalAudit("ORDER_RESULT",side>0?g_current_long_signal_event_id:g_current_short_signal_event_id,"INITIAL",side,decision_signal_count,decision_signal_count,"FAILED",trade.ResultRetcodeDescription(),true,false,(long)trade.ResultRetcode(),0);
      RegisterOrderFailure("ENTRY FAILED");
      WriteSignalDecisionLog(side, "ORDER_RESULT", decision_signal_count,
                             decision_score, "ORDER_FAILED",
                             trade.ResultRetcodeDescription(), true, false,
                             (long)trade.ResultRetcode(), range_location);

       // v7.39: a NO_MONEY result cannot become valid by retrying the same
       // historical 3X setup. Require a fresh accepted-FINAL episode.
       if(trade.ResultRetcode()==TRADE_RETCODE_NO_MONEY &&
          g_range_direction_confirm_pending &&
          g_range_direction_confirm_side==side)
       {
          EntryEngineCancelRangeInitial(side,"ORDER_FAILED_NO_MONEY",true);
       }

      if((bool)MQLInfoInteger(MQL_TESTER))
         PrintFormat("[JTA ORDER RESULT] %s | FAILED | SCORE=%d | RETCODE=%d | %s",
                     side>0 ? "LONG" : "SHORT",decision_score,
                     (int)trade.ResultRetcode(),trade.ResultRetcodeDescription());
      return false;
   }
   g_entry_order_in_progress = false;
   g_initial_entry_source_event_id = side>0?g_current_long_signal_event_id:g_current_short_signal_event_id;
   WriteUnifiedOrderSignalAudit("ORDER_RESULT",g_initial_entry_source_event_id,"INITIAL",side,decision_signal_count,decision_signal_count,"SUCCESS",reason,true,true,(long)trade.ResultRetcode(),0);

   // RANGE ADD structural-invalidation anchors were removed in v4.23.
   // Persistence now retains only cycle time and cumulative ADD fills.

   JTAAddPersistenceSave();
   ResetAutoSignalCounters();
   if(range_direction_confirmed_entry && g_range_break_confirmed)
   {
      g_range_break_order_result = true;
      if(trade.ResultPrice() > 0.0)
         g_range_break_order_price = trade.ResultPrice();
   }
   WriteSignalDecisionLog(side, "ORDER_RESULT", decision_signal_count,
                          decision_score, "ORDER_SENT", reason,
                          true, true, (long)trade.ResultRetcode(),
                          range_location);
   if((bool)MQLInfoInteger(MQL_TESTER))
      PrintFormat("[JTA ORDER RESULT] %s | SUCCESS | SCORE=%d | PRICE=%.*f | RETCODE=%d",
                  side>0 ? "LONG" : "SHORT",decision_score,
                  _Digits,trade.ResultPrice(),(int)trade.ResultRetcode());
   g_consecutive_order_failures = 0;

   // v2.35: initialize the original R immediately after the broker accepts the
   // INITIAL order. On fast symbols MT5 can report SUCCESS before the new
   // position becomes visible; the old code returned through POSITION SYNC
   // PENDING with g_initial_r_distance still zero, disabling all R protection.
   const double provisional_fill_price =
      trade.ResultPrice() > 0.0 ? trade.ResultPrice() : entry;
   g_initial_entry_price = provisional_fill_price;
   if(StringFind(reason, "SHORT-TERM") >= 0 || StringFind(reason, "M3 AUTO") >= 0)
   {
      g_st_entry_active = true;
      g_st_entry_filled_bar = iTime(_Symbol, entry_tf, 0);
      g_st_entry_armed = false;
   }
   if(StringFind(reason, "M3 AUTO") >= 0)
   {
      g_m3_position_managed = true;
      g_m3_initial_structural_sl = sl;
      g_m3_protected_sl = sl;
      g_m3_protection_stage = 0;
      g_m3_position_state = JTC_M3_POS_RUN;
      g_m3_group_peak_r = 0.0;
      g_m3_post_add_peak_r = 0.0;
      g_m3_post_add_protected_r = 0.0;
      g_m3_group_add_count_at_peak = 0;
      g_m3_protection_last_time = iTime(_Symbol,AUTO_TF,0);
      // v8.148: M3 position ownership is independent of the removed structural-SL lifecycle.
      g_m3_structural_sl_active = false;
   }
   g_initial_r_distance = MathMax(MathAbs(provisional_fill_price-sl), _Point);
   g_sl_distance = g_initial_r_distance;
   g_protected_sl = sl;
   g_highest_profit_r = 0.0;
   g_profit_protection_state = PROFIT_PROTECTION_UNKNOWN;
   g_initial_virtual_profit_floor_active = false;
   g_initial_virtual_profit_floor_side = 0;
   g_initial_virtual_profit_floor_r = 0.0;
   g_initial_virtual_profit_floor_price = 0.0;
   g_initial_virtual_profit_floor_time = 0;

   // OpenPosition() is reached only from an authorized AUTO entry path. Preserve
   // AUTO ON immediately after the broker accepts the order. This also protects
   // against UI refresh/reinitialization races around the fill transaction.
   g_auto_trading = true;
   UISetAutoSessionLatch(true);

   // Freeze entry confidence at the initial fill. RANGE entries that bypass
   // the configured three-signal gate are managed more conservatively, while
   // the same HOLD engine can still extend a genuinely strong move.
   g_entry_signal_count_at_open = decision_signal_count;
   if(StringFind(reason, "SHORT-TERM") >= 0)
   {
      // v8.36: short-term price-action entries are fully qualified by the
      // impulse/pullback/re-acceleration model; do not downgrade their HOLD
      // management because the legacy RANGE signal counter is zero.
      g_entry_confidence = ENTRY_CONFIDENCE_HIGH;
   }
   else if(g_selected_strategy == STRATEGY_RANGE)
   {
      // v5.76: InpRangeSignalsRequired changes only RANGE INITIAL entry threshold.
      // Preserve v5.73 confidence semantics: three signals = HIGH, two = MEDIUM.
      if(decision_signal_count >= 3)
         g_entry_confidence = ENTRY_CONFIDENCE_HIGH;
      else if(decision_signal_count >= 2)
         g_entry_confidence = ENTRY_CONFIDENCE_MEDIUM;
      else
         g_entry_confidence = ENTRY_CONFIDENCE_LOW;
   }
   else
      g_entry_confidence = ENTRY_CONFIDENCE_HIGH;

   g_chase_entry_candidate = chase_candidate;
   // v1.98: re-entry protection becomes active only after the actual
   // REENTRY DEAL is confirmed in OnTradeTransaction.
   g_reentry_protection_active = false;
   g_has_add_entry = false;
   JTAAddLayerResetAll();
   g_position_opposite_signal_confirmed = false;
   g_position_direction_hold_supported = true;
   g_range_opposite_2of2_exit_pending=false;
   g_range_opposite_2of2_exit_side=0;
   g_range_opposite_2of2_exit_time=0;
   g_add_same_direction_signal_count=0;
   g_range_add_macd_contraction_seen=false;
   g_add_break_confirm_bar=0;
   g_add_last_counted_signal_bar = 0;
   g_add_first_signal_bar = 0;
   g_add_first_signal_event_id = "";
   g_add_second_signal_event_id = "";
   g_add_last_consumed_pair_key = "";
   g_initial_opposite_confirm_count = 0;
   g_range_opposite_2of2_exit_pending=false;
   g_range_opposite_2of2_exit_side=0;
   g_range_opposite_2of2_exit_time=0;
   g_initial_opposite_last_bar = 0;
   g_initial_opposite_first_bar = 0;
   g_initial_opposite_first_event_id = "";
   g_initial_opposite_second_event_id = "";
   g_entry_type = chase_candidate ? ENTRY_CHASE :
      (StringFind(reason, "EARLY") >= 0 ? ENTRY_EARLY :
       (range_strategy_entry ? ENTRY_RANGE : ENTRY_NORMAL));
   g_chase_trend_hold_active = false;
   g_chase_weakness_bars = 0;
   g_chase_average_range = entry_average_range;
   g_chase_reference_high = iHigh(_Symbol, entry_tf, 1);
   g_chase_reference_low = iLow(_Symbol, entry_tf, 1);
   g_chase_peak_progress = 0.0;
   g_chase_failure_bars = 0;
   g_chase_last_evaluation_bar = 0;
   g_initial_entry_lots = volume;
   g_sl_distance = stop_distance;
   g_protected_sl = sl;
   g_tp_distance = 0.0;
   g_original_tp = 0.0;

   // Rebase the requested ENTRY->SL/TP distances on the actual fill price.
   // Some symbols fill a little away from the quote used in the market order.
   ulong ticket = 0;
   ENUM_POSITION_TYPE position_type = POSITION_TYPE_BUY;
   double fill_price = 0.0, actual_sl = 0.0, actual_tp = 0.0;
   datetime position_time = 0;
   if(ManagedPosition(ticket, position_type, fill_price,
                      actual_sl, actual_tp, position_time))
   {
      if(!ApplyPercentStopToTicket(ticket, side, 0.0, stop_distance))
      {
         g_status = "ENTRY OPENED - SL APPLY FAILED: " +
                    trade.ResultRetcodeDescription();
         Print(g_status, " | fill=", DoubleToString(fill_price, _Digits),
               " requested_sl=", DoubleToString(sl, _Digits),
               " bid=", DoubleToString(SymbolInfoDouble(_Symbol, SYMBOL_BID), _Digits),
               " ask=", DoubleToString(SymbolInfoDouble(_Symbol, SYMBOL_ASK), _Digits),
               " stops=", (int)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL),
               " freeze=", (int)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_FREEZE_LEVEL));
         // A successful safety close is recoverable. Keep AUTO ON and wait
         // for the normal stop-loss cooldown before looking for another entry.
         if(CloseManagedPosition("stop loss apply failed after entry"))
         {
            g_consecutive_order_failures = 0;
            g_status += " | SAFELY CLOSED | AUTO ON";
            NotifyTerminalOnly(_Symbol + " " + g_status);
         }
         else
         {
            // Keep the user's AUTO switch ON. A close failure is a broker/order
            // safety event, not permission to silently change the menu state.
            // Existing-position checks prevent a duplicate initial entry while
            // the unresolved position remains open.
            g_status += " | CLOSE FAILED | AUTO REMAINS ON - CHECK POSITION";
            NotifyTerminalOnly(_Symbol + " " + g_status);
         }
         return false;
      }
      else
      {
         PositionSelectByTicket(ticket);
         g_protected_sl = PositionGetDouble(POSITION_SL);
         g_initial_entry_price = PositionGetDouble(POSITION_PRICE_OPEN);

         // v3.44: 1R belongs to the user's configured menu risk, not to the
         // broker-adjusted SL that happens to be installable after the fill.
         // Rebase the menu distance on the actual fill, while keeping the
         // actual broker SL separately in g_protected_sl. This prevents a
         // temporary stops/freeze/spread adjustment from delaying every
         // R-based profit-protection threshold.
         const double actual_volume = PositionGetDouble(POSITION_VOLUME);
         const double menu_r_distance =
            JTAInitialRiskDistancePrice(g_initial_entry_price,actual_volume);
         if(menu_r_distance > 0.0)
         {
            g_initial_r_distance = MathMax(menu_r_distance,_Point);
            g_sl_distance = g_initial_r_distance;
            g_trade_cycle.initial_sl = NormalizePrice(
               g_initial_entry_price - side * g_initial_r_distance);
         }
      }
   }
   else
   {
      // A successful market-order retcode can arrive before MT5 exposes the
      // resulting position through PositionSelect/PositionsTotal. Do not turn
      // AUTO OFF because of this short synchronization window.
      g_status = "ENTRY SENT - POSITION SYNC PENDING | AUTO REMAINS ON";
      NotifyTerminalOnly(_Symbol + " " + g_status);
      g_last_entry_time = TimeCurrent();
      return true;
   }

   if(side > 0)
      g_long_regime_traded = true;
   else
      g_short_regime_traded = true;

   g_ui_buy = (side > 0);
   UIArrangeSide();
   g_additional_entry_count = 0;
   g_additional_entry_filled_count = 0;
   if(g_initial_entry_was_trigger)
   {
      g_has_add_entry=false;
      g_add_same_direction_signal_count=0;
      g_range_add_macd_contraction_seen=false;
      g_add_break_confirm_bar=0;
      g_add_first_signal_bar=0;
      g_add_first_signal_event_id="";
      g_add_second_signal_event_id="";
      g_add_last_counted_signal_bar=0;
      g_add_last_consumed_pair_key="";
      g_last_add_attempt_bar=0;
   }
   g_last_entry_time = TimeCurrent();
   g_initial_entry_time = g_last_entry_time;
   // v5.97: a new INITIAL owns a fresh independent layer-HOLD runtime.
   ResetRangeLayerHoldStates();
   JTAAddPersistenceSave();
   g_status = StringFormat("[ENTRY] %s FILLED | SIGNALS %d | CONF %s | %s",
      side>0?"LONG":"SHORT",g_entry_signal_count_at_open,
      EntryConfidenceName(g_entry_confidence),reason);
   // v4.60: normal INITIAL fill notification is emitted once from
   // OnTradeTransaction() after the broker deal is confirmed.
   return true;
}

//+------------------------------------------------------------------+
// v5.36 (v5.08 base): ADD is permitted only when every predecessor
// managed layer is individually profitable at the executable exit quote.
// The existing managed-group CurrentProgressR(side) > 0 gate remains unchanged
// and acts as an additional independent safety boundary.
bool AllPriorAddLayersIndividuallyProfitable(const int side,string &detail)
{
   detail="";
   if(side==0)
   {
      detail="INVALID_SIDE";
      return false;
   }

   const double exit_quote =
      side>0 ? SymbolInfoDouble(_Symbol,SYMBOL_BID)
             : SymbolInfoDouble(_Symbol,SYMBOL_ASK);
   if(exit_quote<=0.0)
   {
      detail="NO_EXIT_QUOTE";
      return false;
   }

   // Use one point as the strict breakeven boundary. A layer must have
   // positive executable-price progress, not merely group-average profit.
   const double eps=MathMax(_Point,0.00000001);

   const ENUM_ACCOUNT_MARGIN_MODE margin_mode=
      (ENUM_ACCOUNT_MARGIN_MODE)AccountInfoInteger(ACCOUNT_MARGIN_MODE);
   const bool hedging=(margin_mode==ACCOUNT_MARGIN_MODE_RETAIL_HEDGING);

   if(hedging)
   {
      int managed_layers=0;
      const int total=PositionsTotal();

      for(int i=0;i<total;i++)
      {
         const ulong ticket=PositionGetTicket(i);
         if(ticket==0 || !PositionSelectByTicket(ticket))
            continue;

         if(PositionGetString(POSITION_SYMBOL)!=_Symbol)
            continue;
         if((ulong)PositionGetInteger(POSITION_MAGIC)!=(ulong)InpMagicNumber)
            continue;

         const ENUM_POSITION_TYPE type=
            (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
         const int layer_side=
            type==POSITION_TYPE_BUY ? 1 :
            type==POSITION_TYPE_SELL ? -1 : 0;

         if(layer_side!=side)
         {
            detail=StringFormat("SIDE_MISMATCH_TICKET_%I64u",ticket);
            return false;
         }

         const double open_price=PositionGetDouble(POSITION_PRICE_OPEN);
         if(open_price<=0.0)
         {
            detail=StringFormat("OPEN_PRICE_UNKNOWN_TICKET_%I64u",ticket);
            return false;
         }

         const double price_profit=
            side>0 ? exit_quote-open_price : open_price-exit_quote;

         if(price_profit<=eps)
         {
            detail=StringFormat(
               "LAYER_NOT_PROFITABLE_TICKET_%I64u_OPEN_%.*f_EXIT_%.*f",
               ticket,_Digits,open_price,_Digits,exit_quote);
            return false;
         }

         managed_layers++;
      }

      if(managed_layers<=0)
      {
         detail="NO_MANAGED_LAYER";
         return false;
      }

      detail=StringFormat("ALL_%d_PRIOR_LAYERS_PROFITABLE",managed_layers);
      return true;
   }

   // Netting mode: MT5 merges broker positions, so use the EA's existing
   // stored virtual layer entry prices to preserve the same rule per layer.
   if(g_initial_entry_price<=0.0)
   {
      detail="INITIAL_PRICE_UNKNOWN";
      return false;
   }

   const double initial_profit=
      side>0 ? exit_quote-g_initial_entry_price
             : g_initial_entry_price-exit_quote;
   if(initial_profit<=eps)
   {
      detail=StringFormat("INITIAL_NOT_PROFITABLE_OPEN_%.*f_EXIT_%.*f",
                          _Digits,g_initial_entry_price,_Digits,exit_quote);
      return false;
   }

   for(int i=0;i<ArraySize(g_add_layers);++i)
   {
      if(!g_add_layers[i].active || g_add_layers[i].volume<=0.0) continue;
      if(g_add_layers[i].entry_price<=0.0)
      {
         detail=StringFormat("ADD%d_PRICE_UNKNOWN",i+1);
         return false;
      }
      const double add_profit=side>0 ? exit_quote-g_add_layers[i].entry_price
                                     : g_add_layers[i].entry_price-exit_quote;
      if(add_profit<=eps)
      {
         detail=StringFormat("ADD%d_NOT_PROFITABLE_OPEN_%.*f_EXIT_%.*f",
                             i+1,_Digits,g_add_layers[i].entry_price,_Digits,exit_quote);
         return false;
      }
   }

   detail="ALL_PRIOR_VIRTUAL_LAYERS_PROFITABLE";
   return true;
}

//+------------------------------------------------------------------+
bool OpenAdditionalPosition(const int side,
                            const int entry_stage,
                            const string setup_reason)
{
   const bool turn_add = InpTurnTradeEnabled && StringFind(setup_reason,"TURN ADD")>=0;
   // Legacy Trigger-origin INITIAL restriction does not apply to the new
   // signal-driven M3 AUTO path. M3AutoEngine has already authorized this ADD
   // from a same-direction ACCEL event. Keep the restriction for legacy paths.
   if(g_initial_entry_was_trigger && !g_m3_auto_execution_context_active)
      return false;

   // Additional entries are allowed in both TREND and RANGE. v8.02+ RANGE
   // receives only a confirmed shared-structure continuation re-break from
   // EntryEngine. PositionManager owns capacity, prior-layer profitability,
   // broker-SL, group-risk and execution-safety authority; it does not
   // reinterpret market direction or continuation structure.

   g_csv_add_enabled = (g_max_additional_entries > 0);
   g_csv_add_attempted = true;
   g_csv_add_result = false;
   g_csv_exec_event_sequence++;
   g_csv_add_event_pending=true;
   g_csv_add_event_id=StringFormat("ADD-%I64u",g_csv_exec_event_sequence);
   g_csv_add_event_phase="REQUEST";
   g_csv_add_event_time=TimeCurrent();
   g_csv_add_event_side=side;
   g_csv_add_event_layer=entry_stage;
   g_csv_add_retcode = 0;
   g_csv_add_count_before = g_additional_entry_filled_count;
   g_csv_add_count_after = g_additional_entry_filled_count;
   g_csv_add_stage = entry_stage;
   if(g_exit_order_in_progress)
   {
      WriteUnifiedOrderSignalAudit("ADD_ORDER_GATE",g_add_second_signal_event_id,"ADD",side,g_add_same_direction_signal_count,g_add_same_direction_signal_count,"BLOCKED","EXIT_ORDER_IN_PROGRESS",false,false,0,0);
      return false;
   }
   g_add_entry_source_event_id = g_add_second_signal_event_id;
   g_csv_add_signal_count = g_add_same_direction_signal_count;
   g_csv_add_signal_required = (g_position_strategy==STRATEGY_RANGE ? 1 : 2);
   g_csv_add_capacity_remaining = MathMax(0, g_max_additional_entries-g_additional_entry_filled_count);
   g_csv_add_bars_since_entry = BarsSinceLastEntry();
   g_csv_add_progress_r = CurrentProgressR(side);
   g_csv_add_requested_volume = 0.0;
   g_csv_add_fill_price = 0.0;
   g_csv_add_block_reason = "";

   if(g_max_additional_entries <= 0 ||
      g_additional_entry_filled_count >= g_max_additional_entries ||
      ManagedPositionSide() != side)
   {
      g_csv_add_block_reason = "CAPACITY_OR_SIDE_BLOCK";
      WriteSignalDecisionLog(side, "ADD_ENTRY_DECISION", g_add_same_direction_signal_count,
         side > 0 ? g_last_long_score : g_last_short_score, "BLOCKED",
         g_csv_add_block_reason, false, false, 0, -1.0);
      return false;
   }

   const datetime add_signal_bar = iTime(_Symbol, ActiveManagementTF(), 1);
   if(g_add_order_in_progress)
   {
      g_status = "ADD BLOCKED: ORDER IN PROGRESS";
      g_csv_add_block_reason = "ORDER_IN_PROGRESS";
      WriteSignalDecisionLog(side, "ADD_ENTRY_DECISION", g_add_same_direction_signal_count, side > 0 ? g_last_long_score : g_last_short_score, "BLOCKED", g_csv_add_block_reason, false, false, 0, -1.0);
      return false;
   }
   if(add_signal_bar > 0 && g_last_add_order_signal_bar == add_signal_bar &&
      g_last_add_order_side == side)
   {
      g_status = "ADD BLOCKED: SIGNAL ALREADY USED";
      g_csv_add_block_reason = "SIGNAL_ALREADY_USED";
      WriteSignalDecisionLog(side, "ADD_ENTRY_DECISION", g_add_same_direction_signal_count, side > 0 ? g_last_long_score : g_last_short_score, "BLOCKED", g_csv_add_block_reason, false, false, 0, -1.0);
      return false;
   }

   const int bars_since_entry = BarsSinceLastEntry();
   if(!g_m3_auto_execution_context_active &&
      bars_since_entry < MathMax(1, InpMinimumAdditionalEntryBars))
   {
      g_status = "ADD BLOCKED: WAIT FOR NEW CLOSED BAR";
      g_csv_add_block_reason = "MINIMUM_BARS_NOT_MET";
      WriteSignalDecisionLog(side, "ADD_ENTRY_DECISION", g_add_same_direction_signal_count, side > 0 ? g_last_long_score : g_last_short_score, "BLOCKED", g_csv_add_block_reason, false, false, 0, -1.0);
      return false;
   }

   // Never add to a losing managed group. RANGE continuation authority comes
   // from the shared-structure pullback/re-break setup; this gate prevents
   // averaging down regardless of the market-structure interpretation.
   const double add_progress_r = CurrentProgressR(side);
   if(!g_m3_auto_execution_context_active && add_progress_r <= 0.0)
   {
      g_status = "ADD BLOCKED: POSITION NOT PROFITABLE";
      g_csv_add_block_reason = "LOSS_OR_BREAKEVEN_ADD_BLOCK";
      WriteSignalDecisionLog(side, "ADD_ENTRY_DECISION", g_add_same_direction_signal_count,
         side > 0 ? g_last_long_score : g_last_short_score, "BLOCKED",
         g_csv_add_block_reason, false, false, 0, -1.0);
      WriteUnifiedOrderSignalAudit("ADD_ORDER_GATE",g_add_entry_source_event_id,"ADD",side,
         g_add_same_direction_signal_count,g_add_same_direction_signal_count,
         "BLOCKED",g_csv_add_block_reason,false,false,0,0);
      return false;
   }

   // v5.36: group profit alone is not sufficient. Every earlier managed
   // layer (INITIAL and any existing ADD) must itself be strictly profitable
   // before the next ADD can be submitted.
   string prior_layer_detail="";
   if(!g_m3_auto_execution_context_active &&
      !AllPriorAddLayersIndividuallyProfitable(side,prior_layer_detail))
   {
      g_status="ADD BLOCKED: PRIOR LAYER NOT PROFITABLE";
      g_csv_add_block_reason="PRIOR_LAYER_NOT_PROFITABLE: "+prior_layer_detail;
      WriteSignalDecisionLog(side,"ADD_ENTRY_DECISION",
         g_add_same_direction_signal_count,
         side>0 ? g_last_long_score : g_last_short_score,
         "BLOCKED",g_csv_add_block_reason,false,false,0,-1.0);
      WriteUnifiedOrderSignalAudit("ADD_ORDER_GATE",g_add_entry_source_event_id,
         "ADD",side,g_add_same_direction_signal_count,
         g_add_same_direction_signal_count,"BLOCKED",
         g_csv_add_block_reason,false,false,0,0);
      return false;
   }

   // RANGE: the caller supplies an already-validated shared-structure
   // continuation re-break, so do not duplicate structure, MACD/Delta/MA or
   // timeframe direction checks here. TREND keeps its safeguards.
   if(g_position_strategy == STRATEGY_TREND && !turn_add)
   {
      if(CurrentProgressR(side) <
         MathMax(0.0, InpMinimumAdditionalProgressR))
      {
         g_status = "ADD BLOCKED: NO PRICE PROGRESS";
         g_csv_add_block_reason = "NO_PRICE_PROGRESS";
         WriteSignalDecisionLog(side, "ADD_ENTRY_DECISION", g_add_same_direction_signal_count, side > 0 ? g_last_long_score : g_last_short_score, "BLOCKED", g_csv_add_block_reason, false, false, 0, -1.0);
         return false;
      }

      double fast_ma[], slow_ma[];
      const int ma_count = MathMax(4, InpPullbackLookbackBars + 3);
      ArrayResize(fast_ma, ma_count);
      ArrayResize(slow_ma, ma_count);
      ArraySetAsSeries(fast_ma, true);
      ArraySetAsSeries(slow_ma, true);
      if(g_add_ma_handle == INVALID_HANDLE ||
         g_slow_ma_handle == INVALID_HANDLE ||
         MarketDataCopyBuffer(g_add_ma_handle, 0, 0, ma_count, fast_ma) < ma_count ||
         MarketDataCopyBuffer(g_slow_ma_handle, 0, 0, ma_count, slow_ma) < ma_count)
         return false;

      if(!M2Reaccelerating(side, fast_ma, slow_ma))
      {
         g_status = "ADD WAIT: TRADE TF NOT RE-ACCELERATING";
         g_csv_add_block_reason = "TRADING_TF_NOT_REACCELERATING";
         WriteSignalDecisionLog(side, "ADD_ENTRY_DECISION", g_add_same_direction_signal_count, side > 0 ? g_last_long_score : g_last_short_score, "BLOCKED", g_csv_add_block_reason, false, false, 0, -1.0);
         return false;
      }
      if(!TradingTFDirectionMaintained(side))
      {
         g_status = "ADD BLOCKED: TRADE TF DIRECTION";
         g_csv_add_block_reason = "TRADING_TF_DIRECTION_BLOCK";
         WriteSignalDecisionLog(side, "ADD_ENTRY_DECISION", g_add_same_direction_signal_count, side > 0 ? g_last_long_score : g_last_short_score, "BLOCKED", g_csv_add_block_reason, false, false, 0, -1.0);
         return false;
      }
   }

   int group_side = 0;
   double total_volume = 0.0, average_price = 0.0;
   double old_sl = 0.0, old_tp = 0.0;
   datetime first_time = 0;
   if(!ManagedGroupInfo(group_side, total_volume, average_price,
                        old_sl, old_tp, first_time) ||
      group_side != side)
      return false;
   if(g_initial_entry_price <= 0.0)
      g_initial_entry_price = average_price;
   if(g_initial_r_distance <= 0.0 && g_initial_entry_price > 0.0)
   {
      // v3.44: ADD preparation must not derive the original 1R from the
      // current group SL because it may already be BE/profit-locked.
      const double base_volume =
         g_initial_entry_lots > 0.0 ? g_initial_entry_lots : total_volume;
      const double menu_r_distance =
         JTAInitialRiskDistancePrice(g_initial_entry_price,base_volume);
      if(menu_r_distance > 0.0)
         g_initial_r_distance = MathMax(menu_r_distance,_Point);
   }

   // Preserve the strongest protection that existed before the ADD.
   // The new layer must inherit this floor; ADD must never reset BE/Profit Lock
   // back to its own wider initial percentage stop.
   const double protected_sl_before_add =
      (g_protected_sl > 0.0 ? g_protected_sl : old_sl);

   // RANGE ADD reaches this point only after EntryEngine has approved a
   // shared-structure pullback and immutable continuation re-break. RANGE does
   // not re-apply MACD/Delta/MA, timeframe direction, or Hold filters here.
   // TREND keeps its own continuation safeguards above.

   // Use the configured lot size for every additional entry.
   // This follows the current panel/tester lot setting without reducing it.
   const double volume = NormalizeVolume(g_ui_lots);
   g_csv_add_requested_volume = volume;
   if(volume <= 0.0 || !EntrySafetyAllows(volume,side))
   {
      g_csv_add_block_reason = volume <= 0.0 ? "INVALID_VOLUME" :
         (g_entry_safety_block_reason != "" ? g_entry_safety_block_reason : "ENTRY_SAFETY_BLOCK");
      WriteSignalDecisionLog(side, "ADD_ENTRY_DECISION", g_add_same_direction_signal_count, side > 0 ? g_last_long_score : g_last_short_score, "BLOCKED", g_csv_add_block_reason, false, false, 0, -1.0);
      return false;
   }

   // Every new fill receives the same percentage stop from its own entry.
   const double quote =
      side > 0 ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
               : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double projected_sl =
      ValidStopPrice(side, quote, StopDistancePrice(quote, volume));
   const double minimum_distance = ProtectionMinimumDistance();
   if(projected_sl <= 0.0 ||
      (side > 0 &&
       projected_sl >= SymbolInfoDouble(_Symbol, SYMBOL_BID) - minimum_distance) ||
      (side < 0 &&
       projected_sl <= SymbolInfoDouble(_Symbol, SYMBOL_ASK) + minimum_distance))
   {
      const double current_bid=SymbolInfoDouble(_Symbol,SYMBOL_BID);
      const double current_ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK);
      g_status = "ADD BLOCKED: SL MINIMUM DISTANCE";
      g_csv_add_block_reason = StringFormat(
         "ADD_SL_FEASIBILITY_BLOCK | QUOTE=%.*f | PROJECTED_SL=%.*f | BID=%.*f | ASK=%.*f | MIN_DISTANCE=%.8f",
         _Digits,quote,_Digits,projected_sl,
         _Digits,current_bid,_Digits,current_ask,minimum_distance);
      WriteSignalDecisionLog(side,"ADD_ENTRY_DECISION",
         g_add_same_direction_signal_count,
         side > 0 ? g_last_long_score : g_last_short_score,
         "BLOCKED",g_csv_add_block_reason,false,false,0,-1.0);
      WriteUnifiedOrderSignalAudit("ADD_ORDER_GATE",g_add_entry_source_event_id,
         "ADD",side,g_add_same_direction_signal_count,
         g_add_same_direction_signal_count,"BLOCKED",
         g_csv_add_block_reason,false,false,0,0);
      return false;
   }

   // v4.36: RANGE ADD no longer applies a separate Equity-percent risk gate.
   // Risk is defined by the configured lot size and the broker-valid SL for
   // this ADD layer. Existing protections remain: profitable-group only,
   // maximum ADD count, EntrySafety, and broker SL feasibility.

   const string reason =
      "stage " + IntegerToString(entry_stage) + " entry: " + setup_reason;

   g_add_order_in_progress = true;
   g_last_add_order_signal_bar = add_signal_bar;
   g_last_add_order_side = side;

   if((bool)MQLInfoInteger(MQL_TESTER))
      PrintFormat("[JTA ADD ORDER REQUEST] %s | SCORE=%d | COUNT=%d/%d | LOT=%.2f | SL=%.*f",
                  side>0 ? "LONG" : "SHORT",
                  side>0 ? g_last_long_score : g_last_short_score,
                  g_add_same_direction_signal_count,g_max_additional_entries,volume,_Digits,projected_sl);

   bool result = false;
   if(side > 0)
      result = TradeExecuteBuy(volume, _Symbol, 0.0, projected_sl, 0.0, reason);
   else
      result = TradeExecuteSell(volume, _Symbol, 0.0, projected_sl, 0.0, reason);

   // v3.36: ADD orders must also never be retried naked after INVALID_STOPS.
   // Preserve the approved projected SL/risk contract and fail this attempt.
   if((!result || !TradeResultSucceeded()) &&
      trade.ResultRetcode() == TRADE_RETCODE_INVALID_STOPS)
   {
      PrintFormat("ADD ENTRY INVALID STOPS BLOCK | side=%d | requested_sl=%.*f | NO_NAKED_RETRY",
                  side, _Digits, projected_sl);
   }

   WriteUnifiedOrderSignalAudit("ADD_ORDER_REQUEST",g_add_entry_source_event_id,"ADD",side,g_add_same_direction_signal_count,g_add_same_direction_signal_count,"REQUESTED",setup_reason,true,false,0,0);
   if(!result || !TradeResultSucceeded())
   {
      g_add_order_in_progress = false;
      g_csv_add_result = false;
      g_csv_add_event_phase="FAILED";
      g_csv_add_event_time=TimeCurrent();
      g_csv_add_retcode = (long)trade.ResultRetcode();
      g_csv_add_block_reason = "ORDER_FAILED: " + trade.ResultRetcodeDescription();
      WriteSignalDecisionLog(side, "ADD_ENTRY_ORDER_RESULT", g_add_same_direction_signal_count, side > 0 ? g_last_long_score : g_last_short_score, "FAILED", g_csv_add_block_reason, true, false, g_csv_add_retcode, -1.0);
      WriteUnifiedOrderSignalAudit("ADD_ORDER_RESULT",g_add_entry_source_event_id,"ADD",side,g_add_same_direction_signal_count,g_add_same_direction_signal_count,"FAILED",g_csv_add_block_reason,true,false,g_csv_add_retcode,0);
      if((bool)MQLInfoInteger(MQL_TESTER))
         PrintFormat("[JTA ADD ORDER RESULT] %s | FAILED | SCORE=%d | RETCODE=%d | %s",
                     side>0 ? "LONG" : "SHORT",
                     side>0 ? g_last_long_score : g_last_short_score,
                     (int)g_csv_add_retcode,g_csv_add_block_reason);
      RegisterOrderFailure("ADD ENTRY FAILED");
      return false;
   }
   g_add_order_in_progress = false;
   g_consecutive_order_failures = 0;

   g_additional_entry_count++;
   g_additional_entry_filled_count++;
   const int filled_stage=g_additional_entry_filled_count;
   JTAAddPersistenceSave();
   g_csv_add_result = true;
   g_csv_add_event_phase="SUCCESS";
   g_csv_add_event_time=TimeCurrent();
   g_csv_add_retcode = (long)trade.ResultRetcode();
   g_csv_add_count_after = g_additional_entry_filled_count;
   g_csv_add_capacity_remaining = MathMax(0, g_max_additional_entries-g_additional_entry_filled_count);
   g_csv_add_fill_price = trade.ResultPrice();
   g_csv_add_block_reason = "";
   WriteSignalDecisionLog(side, "ADD_ENTRY_ORDER_RESULT", g_add_same_direction_signal_count, side > 0 ? g_last_long_score : g_last_short_score, "SUCCESS", "", true, true, g_csv_add_retcode, -1.0);
   WriteUnifiedOrderSignalAudit("ADD_ORDER_RESULT",g_add_entry_source_event_id,"ADD",side,g_add_same_direction_signal_count,0,"SUCCESS",setup_reason,true,true,g_csv_add_retcode,0);
   if((bool)MQLInfoInteger(MQL_TESTER))
      PrintFormat("[JTA ADD ORDER RESULT] %s | SUCCESS | SCORE=%d | PRICE=%.*f | RETCODE=%d",
                  side>0 ? "LONG" : "SHORT",
                  side>0 ? g_last_long_score : g_last_short_score,
                  _Digits,trade.ResultPrice(),(int)g_csv_add_retcode);
   g_has_add_entry = true;
   g_add_same_direction_signal_count=0;
   g_range_add_macd_contraction_seen=false;
   g_add_break_confirm_bar=0;
   g_add_first_signal_bar = 0;
   g_add_first_signal_event_id = "";
   g_add_second_signal_event_id = "";
   g_add_last_counted_signal_bar = add_signal_bar;
   g_last_entry_time = TimeCurrent();

   // Hedging: modify only the newly created ticket from its own fill.
   // Netting: MT5 merges fills. A successful order can be acknowledged before
   // the updated position snapshot is visible. Treat that as sync-pending,
   // never as an SL-apply failure.
   const ulong protected_ticket = NewestManagedPositionTicket(side);
   if(protected_ticket==0 || !PositionSelectByTicket(protected_ticket))
   {
      g_add_position_sync_pending=true;
      g_add_pending_stage=filled_stage;
      g_add_pending_side=side;
      g_add_pending_volume=volume;
      g_status=StringFormat("ADD%d SENT - POSITION SYNC PENDING | AUTO REMAINS ON",
                            filled_stage);
      NotifyTerminalOnly(_Symbol+" "+g_status);
      return true;
   }

   if(!ApplyPercentStopToTicket(protected_ticket, side,
                               protected_sl_before_add))
   {
      g_status = "ADD ENTRY OPENED - SL APPLY FAILED: " +
                 trade.ResultRetcodeDescription();
      const bool rolled_back = CloseManagedVolume(side, volume,
         "ADD SL APPLY FAILED ROLLBACK");
      if(rolled_back)
      {
         const int rolled_stage=filled_stage;
         g_additional_entry_count=MathMax(0,g_additional_entry_count-1);
         g_additional_entry_filled_count=MathMax(0,g_additional_entry_filled_count-1);
         JTAAddPersistenceSave();
         g_has_add_entry=g_additional_entry_count>0;
         JTAAddLayerClear(rolled_stage);
         TradeCycleSyncAddCounter("");
         g_consecutive_order_failures=0;
         g_protected_sl=protected_sl_before_add;
         EnsureManagedStopsProtected(true);
         g_status+=" | ADD EXPOSURE ROLLED BACK | ORIGINAL POSITION KEPT";
         NotifyTerminalOnly(_Symbol+" "+g_status);
      }
      else
      {
         g_status+=" | ADD ROLLBACK FAILED | CHECK POSITION/SL";
         NotifyTerminalOnly(_Symbol+" "+g_status);
      }
      return false;
   }

   PositionSelectByTicket(protected_ticket);
   g_protected_sl=PositionGetDouble(POSITION_SL);

   double layer_fill=trade.ResultPrice();
   double layer_r_distance=0.0;
   const bool hedging_account=
      AccountInfoInteger(ACCOUNT_MARGIN_MODE)==ACCOUNT_MARGIN_MODE_RETAIL_HEDGING;
   if(hedging_account && protected_ticket>0 && PositionSelectByTicket(protected_ticket))
   {
      const double ticket_fill=PositionGetDouble(POSITION_PRICE_OPEN);
      const double ticket_sl=PositionGetDouble(POSITION_SL);
      if(ticket_fill>0.0) layer_fill=ticket_fill;
      if(ticket_fill>0.0 && ticket_sl>0.0)
         layer_r_distance=MathAbs(ticket_fill-ticket_sl);
   }
   if(layer_fill<=0.0) layer_fill=quote;
   if(layer_r_distance<=0.0)
      layer_r_distance=MathMax(_Point,StopDistancePrice(layer_fill,volume));

   JTAAddLayerSet(filled_stage,layer_fill,TimeCurrent(),
                  g_pending_add_hold_anchor_time,layer_r_distance,volume);

   // v8.65 M3 group protection: the current group R becomes the baseline for
   // profit earned after this ADD. INITIAL protection remains independent.
   if(g_m3_position_managed)
   {
      double group_avg=0.0;
      const double post_add_r=CurrentGroupProgressR(side,group_avg);
      g_m3_post_add_anchor_r=post_add_r;
      g_m3_post_add_peak_r=0.0;
      g_m3_post_add_protected_r=0.0;
      g_m3_group_add_count_at_peak=filled_stage;
   }

   g_add_position_sync_pending=false;
   g_add_pending_stage=0;
   g_add_pending_side=0;
   g_add_pending_volume=0.0;

   g_status=StringFormat("[ADD%d] %s FILLED | %s",
      filled_stage,side>0?"LONG":"SHORT",setup_reason);
   g_last_position_state_alert=g_status;
   // v4.60: normal ADD fill notification is emitted once from
   // OnTradeTransaction() after the broker deal is confirmed.
   return true;
}

//+------------------------------------------------------------------+
bool CloseManagedVolume(const int side,
                        const double requested_volume,
                        const string reason)
{
   int group_side = 0;
   double total_volume = 0.0, average_price = 0.0;
   double group_sl = 0.0, group_tp = 0.0;
   datetime first_time = 0;
   if(!ManagedGroupInfo(group_side, total_volume, average_price,
                        group_sl, group_tp, first_time) ||
      group_side != side || requested_volume <= 0.0)
      return false;

   const double minimum = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   const double step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   if(minimum <= 0.0 || step <= 0.0)
      return false;
   double close_volume =
      MathFloor(MathMin(requested_volume, total_volume) /
                step + 0.0000001) * step;
   close_volume = NormalizeDouble(close_volume, 8);
   if(close_volume < minimum ||
      total_volume - close_volume < minimum - 0.0000001)
      return false;

   g_pending_exit_reason = "PARTIAL EXIT: " + reason;
   g_pending_exit_reason_time = TimeCurrent();

   bool result = false;
   if(AccountInfoInteger(ACCOUNT_MARGIN_MODE) ==
      ACCOUNT_MARGIN_MODE_RETAIL_HEDGING)
   {
      double remaining = close_volume;
      while(remaining >= minimum - 0.0000001)
      {
         const ulong ticket = NewestManagedPositionTicket(side);
         if(ticket == 0 || !PositionSelectByTicket(ticket))
            return false;
         const double ticket_volume =
            PositionGetDouble(POSITION_VOLUME);
         const double part =
            MathMin(ticket_volume, remaining);
         if(part >= ticket_volume - 0.0000001)
            result = ExitClosePosition(ticket);
         else
            result = ExitClosePositionPartial(ticket, part);
         if(!result || !TradeResultSucceeded())
         {
            RegisterOrderFailure("SHORT-TERM PARTIAL EXIT FAILED");
            return false;
         }
         remaining = NormalizeDouble(remaining - part, 8);
      }
   }
   else
   {
      result = side > 0 ?
         TradeExecuteSell(close_volume, _Symbol, 0.0, 0.0, 0.0,
                    "SHORT-TERM PARTIAL EXIT") :
         TradeExecuteBuy(close_volume, _Symbol, 0.0, 0.0, 0.0,
                   "SHORT-TERM PARTIAL EXIT");
      if(!result || !TradeResultSucceeded())
      {
         RegisterOrderFailure("SHORT-TERM PARTIAL EXIT FAILED");
         return false;
      }
   }

   g_consecutive_order_failures = 0;
   g_status = (side > 0 ? "LONG " : "SHORT ") +
              "SHORT-TERM PARTIAL EXIT: " + reason;
   // v4.61: normal partial-close success is notified once from
   // OnTradeTransaction() using the actual broker deal and realized P/L.
   return true;
}

//+------------------------------------------------------------------+
// Simple RANGE hold override.
// A profitable RANGE position is held while all three closed-bar conditions
// remain aligned with the position direction:
//   1) MACD baseline remains on the entry side of zero
//   2) Volume delta remains on the entry side of zero
//   3) MA7 is not turning against the position
// Broker SL and emergency protection remain active.
//+------------------------------------------------------------------+
// Unified open-position management. The initial broker SL created from
// the chart/menu is always the first line of defence. These managers may
// improve that SL after a profit trigger, take profit, or close early only after
// strict MA+MACD+Delta strategy-failure confirmation.
//+------------------------------------------------------------------+
// Synchronizes a manually moved chart SL line with every managed broker
// position for the current symbol. The existing TP is preserved.
// The function validates all positions before sending any modification so a
// hedging group cannot be left partially updated by an invalid stop price.
bool ApplyManualSLLineToManagedPositions(const double requested_sl)
{
   const double desired_sl = NormalizePrice(requested_sl);
   if(desired_sl <= 0.0)
   {
      g_status = "SL UPDATE FAILED: INVALID PRICE";
      return false;
   }

   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double minimum_distance = MathMax(
      (double)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * _Point,
      (double)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_FREEZE_LEVEL) * _Point);
   const double tolerance =
      MathMax(SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE), _Point) * 1.1;

   int managed_count = 0;
   double restore_sl = 0.0;

   // Validate every managed position first.
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket) ||
         PositionGetString(POSITION_SYMBOL) != _Symbol ||
         (ulong)PositionGetInteger(POSITION_MAGIC) != InpMagicNumber)
         continue;

      managed_count++;
      if(restore_sl <= 0.0)
         restore_sl = PositionGetDouble(POSITION_SL);

      const ENUM_POSITION_TYPE type =
         (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const bool invalid_buy =
         type == POSITION_TYPE_BUY && desired_sl >= bid - minimum_distance;
      const bool invalid_sell =
         type == POSITION_TYPE_SELL && desired_sl <= ask + minimum_distance;
      if(invalid_buy || invalid_sell)
      {
         if(restore_sl > 0.0)
            g_ui_drag_sl = NormalizePrice(restore_sl);
         RequestUIRefresh();
         JRO_RequestChartRedraw();
         g_status = "SL UPDATE REJECTED: BROKER STOP/FREEZE DISTANCE";
         Print(g_status, " | requested=", DoubleToString(desired_sl, _Digits),
               " | bid=", DoubleToString(bid, _Digits),
               " | ask=", DoubleToString(ask, _Digits));
         return false;
      }
   }

   // With no managed position, the line remains a planning reference only.
   if(managed_count == 0)
   {
      g_status = "SL LINE MOVED - NO OPEN POSITION";
      return true;
   }

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket) ||
         PositionGetString(POSITION_SYMBOL) != _Symbol ||
         (ulong)PositionGetInteger(POSITION_MAGIC) != InpMagicNumber)
         continue;

      const double current_sl = PositionGetDouble(POSITION_SL);
      const double current_tp = PositionGetDouble(POSITION_TP);
      if(current_sl > 0.0 && MathAbs(current_sl - desired_sl) <= tolerance)
         continue;

      ResetLastError();
      if(!TradeExecutePositionModify(ticket, desired_sl, current_tp) ||
         !TradeResultSucceeded())
      {
         if(PositionSelectByTicket(ticket))
         {
            const double actual_sl = PositionGetDouble(POSITION_SL);
            if(actual_sl > 0.0)
               g_ui_drag_sl = NormalizePrice(actual_sl);
         }
         RequestUIRefresh();
         JRO_RequestChartRedraw();
         g_status = "SL BROKER UPDATE FAILED: " +
                    trade.ResultRetcodeDescription();
         Print(g_status, " | ticket=", ticket,
               " | error=", GetLastError());
         return false;
      }
   }

   // Verify the broker accepted the requested value on every managed ticket.
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket) ||
         PositionGetString(POSITION_SYMBOL) != _Symbol ||
         (ulong)PositionGetInteger(POSITION_MAGIC) != InpMagicNumber)
         continue;

      const double applied_sl = PositionGetDouble(POSITION_SL);
      if(applied_sl <= 0.0 || MathAbs(applied_sl - desired_sl) > tolerance)
      {
         if(applied_sl > 0.0)
            g_ui_drag_sl = NormalizePrice(applied_sl);
         RequestUIRefresh();
         JRO_RequestChartRedraw();
         g_status = "SL VERIFY FAILED: BROKER PRICE DIFFERS";
         return false;
      }
   }

   g_ui_drag_sl = desired_sl;
   g_protected_sl = desired_sl;

   int group_side = 0;
   double group_volume = 0.0, group_average = 0.0;
   double group_sl = 0.0, group_tp = 0.0;
   datetime first_time = 0;
   if(ManagedGroupInfo(group_side, group_volume, group_average,
                       group_sl, group_tp, first_time) &&
      group_average > 0.0)
   {
      // v3.44: a manually moved/current broker SL must never redefine 1R.
      // If the initial risk is missing, reconstruct it from the configured
      // menu SL at the original entry instead of from the modified SL.
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
   }

   g_status = "BROKER SL UPDATED: " + DoubleToString(desired_sl, _Digits);
   UISyncRuntimeProperties("MANUAL SL BROKER SYNC");
   RequestUIRefresh();
   JRO_RequestChartRedraw();
   return true;
}


//+------------------------------------------------------------------+
// Synchronizes a manually moved chart TP line with every managed broker
// position for the current symbol. The existing SL is preserved.
// All managed tickets are validated before any modification is sent.
bool ApplyManualTPLineToManagedPositions(const double requested_tp)
{
   const double desired_tp = NormalizePrice(requested_tp);
   if(desired_tp <= 0.0)
   {
      g_status = "TP UPDATE FAILED: INVALID PRICE";
      return false;
   }

   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double minimum_distance = MathMax(
      (double)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * _Point,
      (double)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_FREEZE_LEVEL) * _Point);
   const double tolerance =
      MathMax(SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE), _Point) * 1.1;

   int managed_count = 0;
   double restore_tp = 0.0;

   // Validate every managed position first so a hedging group cannot be left
   // partially updated because the requested target is invalid for one side.
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket) ||
         PositionGetString(POSITION_SYMBOL) != _Symbol ||
         (ulong)PositionGetInteger(POSITION_MAGIC) != InpMagicNumber)
         continue;

      managed_count++;
      if(restore_tp <= 0.0)
         restore_tp = PositionGetDouble(POSITION_TP);

      const ENUM_POSITION_TYPE type =
         (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const bool invalid_buy =
         type == POSITION_TYPE_BUY && desired_tp <= ask + minimum_distance;
      const bool invalid_sell =
         type == POSITION_TYPE_SELL && desired_tp >= bid - minimum_distance;
      if(invalid_buy || invalid_sell)
      {
         if(restore_tp > 0.0)
            g_ui_drag_tp = NormalizePrice(restore_tp);
         RequestUIRefresh();
         JRO_RequestChartRedraw();
         g_status = "TP UPDATE REJECTED: BROKER STOP/FREEZE DISTANCE";
         Print(g_status, " | requested=", DoubleToString(desired_tp, _Digits),
               " | bid=", DoubleToString(bid, _Digits),
               " | ask=", DoubleToString(ask, _Digits));
         return false;
      }
   }

   // With no managed position, the TP line remains a planning reference only.
   if(managed_count == 0)
   {
      g_status = "TP LINE MOVED - NO OPEN POSITION";
      return true;
   }

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket) ||
         PositionGetString(POSITION_SYMBOL) != _Symbol ||
         (ulong)PositionGetInteger(POSITION_MAGIC) != InpMagicNumber)
         continue;

      const double current_sl = PositionGetDouble(POSITION_SL);
      const double current_tp = PositionGetDouble(POSITION_TP);
      if(current_tp > 0.0 && MathAbs(current_tp - desired_tp) <= tolerance)
         continue;

      ResetLastError();
      if(!TradeExecutePositionModify(ticket, current_sl, desired_tp) ||
         !TradeResultSucceeded())
      {
         if(PositionSelectByTicket(ticket))
         {
            const double actual_tp = PositionGetDouble(POSITION_TP);
            if(actual_tp > 0.0)
               g_ui_drag_tp = NormalizePrice(actual_tp);
         }
         RequestUIRefresh();
         JRO_RequestChartRedraw();
         g_status = "TP BROKER UPDATE FAILED: " +
                    trade.ResultRetcodeDescription();
         Print(g_status, " | ticket=", ticket,
               " | error=", GetLastError());
         return false;
      }
   }

   // Verify that every managed ticket now contains the requested broker TP.
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket) ||
         PositionGetString(POSITION_SYMBOL) != _Symbol ||
         (ulong)PositionGetInteger(POSITION_MAGIC) != InpMagicNumber)
         continue;

      const double applied_tp = PositionGetDouble(POSITION_TP);
      if(applied_tp <= 0.0 || MathAbs(applied_tp - desired_tp) > tolerance)
      {
         if(applied_tp > 0.0)
            g_ui_drag_tp = NormalizePrice(applied_tp);
         RequestUIRefresh();
         JRO_RequestChartRedraw();
         g_status = "TP VERIFY FAILED: BROKER PRICE DIFFERS";
         return false;
      }
   }

   g_ui_drag_tp = desired_tp;

   int group_side = 0;
   double group_volume = 0.0, group_average = 0.0;
   double group_sl = 0.0, group_tp = 0.0;
   datetime first_time = 0;
   if(ManagedGroupInfo(group_side, group_volume, group_average,
                       group_sl, group_tp, first_time) &&
      group_average > 0.0)
   {
      g_tp_distance = MathAbs(desired_tp - group_average);
      g_original_tp = desired_tp;
      g_tp_enabled = true;
   }

   g_status = "BROKER TP UPDATED: " + DoubleToString(desired_tp, _Digits);
   UISyncRuntimeProperties("MANUAL TP BROKER SYNC");
   RequestUIRefresh();
   JRO_RequestChartRedraw();
   return true;
}

//+------------------------------------------------------------------+
// Final-position-close cleanup shared by terminal/manual, EA, SL and TP exits.
// Exit-specific decisions (cooldown length, giveback re-entry metadata and
// regime consumption) are made before this function. This function only
// prevents stale runtime state from surviving into the next position.
// M3 re-entry lock is deliberately excluded from the generic flat reset.
void FinalizeCompletedPositionClose(const bool manual_close)
{
   ResetFlatRuntimeStateOnce();
   ResetAutoSignalCounters();

   // The breakout reference belongs only to the completed managed position.
   g_entry_breakout_active = false;
   g_entry_breakout_side = 0;
   g_entry_breakout_reference = 0.0;
   g_entry_breakout_confirm_bar_time = 0;
   g_entry_breakout_confirm_close = 0.0;

   g_long_exit_pending = false;
   g_short_exit_pending = false;
   g_exit_opposite_close_bars = 0;
   g_last_position_state_alert = "";

   HoldEngineResetState();
   ResetRangeLayerHoldStates();
   RiskEngineResetProfitProtectionState();

   g_chase_entry_candidate = false;
   g_chase_trend_hold_active = false;
   g_chase_weakness_bars = 0;
   g_entry_type = ENTRY_NORMAL;
   g_has_add_entry = false;
   g_reentry_protection_active = false;
   g_entry_confidence = ENTRY_CONFIDENCE_HIGH;
   g_entry_signal_count_at_open = 0;
   g_initial_3x_structure_stop_active=false;
   g_initial_3x_structure_stop_side=0;
   g_initial_3x_structure_stop_price=0.0;
   g_st_entry_active=false;
   g_st_entry_filled_bar=0;
   g_initial_3x_structure_signal_bar=0;
   g_add_same_direction_signal_count=0;
   g_range_add_macd_contraction_seen=false;
   g_add_break_confirm_bar=0;
   g_add_last_counted_signal_bar = 0;
   g_add_first_signal_bar = 0;
   g_add_first_signal_event_id = "";
   g_add_second_signal_event_id = "";
   g_add_last_consumed_pair_key = "";
   g_initial_opposite_confirm_count = 0;
   g_range_opposite_2of2_exit_pending=false;
   g_range_opposite_2of2_exit_side=0;
   g_range_opposite_2of2_exit_time=0;
   g_initial_opposite_last_bar = 0;
   g_initial_opposite_first_bar = 0;
   g_initial_opposite_first_event_id = "";
   g_initial_opposite_second_event_id = "";
   g_exit_order_in_progress = false;
   g_exit_source_event_id = "";

   // A manual close must not inherit giveback re-entry permission produced by
   // an older automatic exit. Automatic giveback exits retain their metadata.
   if(manual_close)
   {
      g_last_giveback_exit_side = 0;
      g_last_giveback_exit_time = 0;
      g_last_giveback_exit_price = 0.0;
      g_last_giveback_exit_reason = "";
      g_last_stop_exit_side = 0;
      g_last_stop_exit_time = 0;
      g_last_stop_exit_price = 0.0;
      g_same_side_stop_count = 0;
   }

   g_pending_exit_reason = "";
   g_pending_exit_reason_time = 0;

   g_initial_hold_anchor_time=0;
   g_pending_initial_hold_anchor_time=0;
   g_add1_hold_anchor_time=0;
   g_add2_hold_anchor_time=0;
   JTAAddLayerResetAll();
   g_pending_add_hold_anchor_time=0;
   g_pending_add_hold_anchor_stage=0;
   JTAHoldAnchorClear();

   g_position_strategy_locked = false;
   g_position_strategy = g_selected_strategy;
   g_last_integrated_side = 0;
   JRO_InvalidatePositionSnapshot();
}


// ===== Functions moved from Common.mqh during ownership audit =====
// v2.45: broker/manual partial closes can remove an ADD layer without passing
// through CloseManagedPosition(). Reconcile the virtual ADD stack against the
// actual remaining managed volume so a stale ADD flag can never cause the
// INITIAL layer to be closed as if it were ADD1/ADD2.
void ReconcileAdditionalLayerState(const string reason)
{
   int side=0; double total_volume=0.0,average_price=0.0,group_sl=0.0,group_tp=0.0;
   datetime first_time=0;
   if(!ManagedGroupInfo(side,total_volume,average_price,group_sl,group_tp,first_time)) return;

   const double volume_step=MathMax(0.00000001,SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP));
   const double tolerance=MathMax(volume_step*0.51,0.00000001);
   double initial_volume=MathMax(0.0,g_initial_entry_lots);
   if(initial_volume<=0.0)
   {
      double add_sum=0.0;
      for(int i=0;i<ArraySize(g_add_layers);++i)
         if(g_add_layers[i].active) add_sum+=MathMax(0.0,g_add_layers[i].volume);
      initial_volume=MathMax(0.0,total_volume-add_sum);
   }

   double excess=MathMax(0.0,total_volume-initial_volume);
   int live_count=0;
   double accumulated=0.0;
   for(int i=0;i<ArraySize(g_add_layers);++i)
   {
      if(!g_add_layers[i].active || g_add_layers[i].volume<=0.0) continue;
      if(accumulated+g_add_layers[i].volume<=excess+tolerance)
      { accumulated+=g_add_layers[i].volume; live_count++; }
      else break;
   }
   // Broker volume is authoritative. Remove virtual newest layers that no longer exist.
   for(int i=ArraySize(g_add_layers)-1;i>=live_count;--i)
      if(g_add_layers[i].active) JTAAddLayerClear(i+1);

   const int before=g_additional_entry_count;
   g_additional_entry_count=live_count;
   g_has_add_entry=live_count>0;
   g_add_same_direction_signal_count=0;
   g_range_add_macd_contraction_seen=false;
   g_add_break_confirm_bar=0;
   g_add_first_signal_bar=0;
   g_add_last_counted_signal_bar=0;
   g_add_first_signal_event_id="";
   g_add_second_signal_event_id="";
   JTAAddPersistenceSave();
   if(before!=live_count)
      PrintFormat("[JTA ADD RECONCILE] %s | %d -> %d | VOLUME %.4f",reason,before,live_count,total_volume);
}

bool ManagedGroupInfo(int &side,
                      double &total_volume,
                      double &average_price,
                      double &group_sl,
                      double &group_tp,
                      datetime &first_time)
{
   JRO_RefreshPositionSnapshot(_Symbol, InpMagicNumber);
   if(!g_jro_positions.has_managed ||
      !g_jro_positions.group_side_consistent ||
      g_jro_positions.total_volume <= 0.0)
      return false;

   side = g_jro_positions.side;
   total_volume = g_jro_positions.total_volume;
   average_price = g_jro_positions.average_open_price;
   group_sl = g_jro_positions.group_sl;
   group_tp = g_jro_positions.group_tp;
   first_time = g_jro_positions.earliest_position_time;
   return true;
}

#endif // __JOON_POSITIONMANAGER_MQH__
