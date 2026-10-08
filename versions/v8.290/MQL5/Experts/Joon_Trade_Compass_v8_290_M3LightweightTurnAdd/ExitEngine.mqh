#ifndef JOON_EXIT_ENGINE_MQH
#define JOON_EXIT_ENGINE_MQH

// Final gateway for position-closing requests.
// Hold/Risk/Position modules may decide why to exit, but closing is routed here.

enum ENUM_JTA_EXIT_PRIORITY
{
   JTA_EXIT_NORMAL = 10,
   JTA_EXIT_PROFIT_PROTECT = 30,
   JTA_EXIT_OPPOSITE_SIGNAL = 50,
   JTA_EXIT_STRUCTURAL_STOP = 70,
   JTA_EXIT_EMERGENCY = 100
};


ENUM_JTA_EXIT_PRIORITY ExitEngineClassifyPriority(const string reason)
{
   string upper=reason;
   StringToUpper(upper);
   if(StringFind(upper,"STOP LOSS")>=0 || StringFind(upper,"EMERGENCY")>=0 ||
      StringFind(upper,"INVALID STOP")>=0 || StringFind(upper,"SL APPLY FAILED")>=0)
      return JTA_EXIT_EMERGENCY;
   if(StringFind(upper,"STRUCTURE")>=0 ||
      StringFind(upper,"HARD INVALIDATION")>=0 || StringFind(upper,"MACD BELOW ZERO")>=0 ||
      StringFind(upper,"MACD ABOVE ZERO")>=0)
      return JTA_EXIT_STRUCTURAL_STOP;
   if(StringFind(upper,"OPPOSITE")>=0)
      return JTA_EXIT_OPPOSITE_SIGNAL;
   if(StringFind(upper,"GIVEBACK")>=0 || StringFind(upper,"PROFIT")>=0 ||
      StringFind(upper,"HOLD SCORE")>=0 || StringFind(upper,"EXIT CANDIDATE")>=0)
      return JTA_EXIT_PROFIT_PROTECT;
   return JTA_EXIT_NORMAL;
}

struct JTAExitDecision
{
   bool required;
   bool partial;
   ulong ticket;
   double volume;
   ENUM_JTA_EXIT_PRIORITY priority;
   string reason;
};

JTAExitDecision MakeExitDecision(const ulong ticket,
                                 const string reason,
                                 const ENUM_JTA_EXIT_PRIORITY priority=JTA_EXIT_NORMAL,
                                 const bool partial=false,
                                 const double volume=0.0)
{
   JTAExitDecision decision;
   decision.required = (ticket > 0);
   decision.partial = partial;
   decision.ticket = ticket;
   decision.volume = volume;
   decision.priority = priority;
   decision.reason = reason;
   return decision;
}

bool ExecuteExitDecision(const JTAExitDecision &decision)
{
   if(!decision.required || decision.ticket == 0)
      return false;

   if(decision.partial)
   {
      if(decision.volume <= 0.0)
         return false;
      return TradeExecutePositionClosePartial(decision.ticket, decision.volume);
   }

   return TradeExecutePositionClose(decision.ticket);
}

bool ExitClosePosition(const ulong ticket,
                       const string reason="",
                       const ENUM_JTA_EXIT_PRIORITY priority=JTA_EXIT_NORMAL)
{
   return ExecuteExitDecision(MakeExitDecision(ticket, reason, priority, false, 0.0));
}

bool ExitClosePositionPartial(const ulong ticket,
                              const double volume,
                              const string reason="",
                              const ENUM_JTA_EXIT_PRIORITY priority=JTA_EXIT_NORMAL)
{
   return ExecuteExitDecision(MakeExitDecision(ticket, reason, priority, true, volume));
}

// Strategy-level managed exit gateway. Decision engines call this function;
// PositionManager remains responsible for group/LIFO semantics and this engine
// remains the single strategic close gateway before TradeExecutionEngine.
bool ExitEngineSubmitManaged(const string reason)
{
   const int side=ManagedPositionSide();
   g_csv_exec_event_sequence++;
   g_csv_exit_event_pending=true;
   g_csv_exit_event_id=StringFormat("EXIT-%I64u",g_csv_exec_event_sequence);
   g_csv_exit_event_phase="REQUEST";
   g_csv_exit_event_time=TimeCurrent();
   g_csv_exit_event_reason=reason;
   const ENUM_JTA_EXIT_PRIORITY priority=ExitEngineClassifyPriority(reason);
   WriteUnifiedOrderSignalAudit("EXIT_CANDIDATE",g_exit_source_event_id,"EXIT",side,
      g_initial_opposite_confirm_count,g_initial_opposite_confirm_count,
      "CANDIDATE",StringFormat("P%d | %s",(int)priority,reason),false,false,0,0);
   return CloseManagedPosition(reason);
}

bool ExitEngineSubmitManagedPartial(const int side,const double volume,const string reason)
{
   if(side==0 || volume<=0.0 || g_exit_order_in_progress)
      return false;
   const ENUM_JTA_EXIT_PRIORITY priority=ExitEngineClassifyPriority(reason);
   WriteUnifiedOrderSignalAudit("EXIT_PARTIAL_CANDIDATE",g_exit_source_event_id,"EXIT",side,
      0,0,"CANDIDATE",StringFormat("P%d | %s",(int)priority,reason),false,false,0,0);
   return CloseManagedVolume(side,volume,reason);
}


// v7.94: RANGE strategic episode END is owned by the same persistence lifecycle
// that starts the episode.  Accepted FIRST is the single persistence commit
// owner in SignalEngine.  Therefore a managed RANGE position exits only when a
// non-zero current persistence side is opposite the held position.  Density and
// MACD remain entry/setup evidence; temporary contraction is not episode END.
// v8.00 RANGE loss-side strategic market exits are removed.
// Broker SL is the only loss-stop authority; reversal WATCH resets pending
// signal/entry lifecycle but never force-closes an open RANGE position.


// RANGE HoldEngine state consumer. v7.91+ HoldEngine is diagnostic/state only;
// RANGE strategic loss exits are disabled; Broker SL owns loss protection.
bool ExitEngineHandleRangeHoldExit(const ENUM_JOON_RANGE_HOLD_STATE hold_state,
                                   const bool state_ready,
                                   const bool profitable,
                                   const int held_bars,
                                   const bool low_energy_warning,
                                   const int warning_state_bars)
{
   // v7.91: HoldEngine is state/diagnostic only for RANGE. Strategic market
   // HoldEngine has no RANGE market-close authority.
   // RiskEngine/Broker SL remain independent protective authorities.
   if(!state_ready)
      return false;
   return hold_state==JOON_RANGE_HOLD_WARNING ||
          hold_state==JOON_RANGE_HOLD_EXIT;
}


// ExitEngine is the single owner of strategy/internal market-exit permission.
// PositionManager owns position state/execution only; it does not re-judge the
// strategy. ProfitExitAllowed() applies only to profit-taking/giveback paths.
// RANGE losing positions are never strategically market-closed; Broker SL owns loss stops.
bool ProfitExitAllowed()
{
   JRO_RefreshPositionSnapshot(_Symbol, InpMagicNumber);
   return g_jro_positions.side != 0 &&
          g_jro_positions.floating_profit > 0.0;
}

//+------------------------------------------------------------------+
bool StrategyExitAllowed()
{
   return ProfitExitAllowed();
}

// Backward-compatible alias for profit-taking call sites.
bool InternalExitAllowed()
{
   return ProfitExitAllowed();
}

// Routine RANGE market-profit exits remain conservative. This helper is retained
// only for ordinary giveback/profit paths; v7.91+ RANGE directional strategy exit
// is owned by the density+MACD invalidation path.
bool RangeConfirmedProfitExitAllowed()
{
   if(g_position_strategy != STRATEGY_RANGE)
      return ProfitExitAllowed();
   return ProfitExitAllowed() &&
          g_position_opposite_signal_confirmed;
}






void ExitEngineManageTrendPositionUnified()
{
   ManageRProfitProtection();
   if(ManagedPositionSide() != 0)
      ManageMaximumHoldingTime();
}



bool ManageShortTermProfitRun()
{
   if(g_m3_position_managed)
      return false;
   if(!g_st_entry_active || ManagedPositionSide()==0 || !InpUseRProfitProtection)
      return false;

   const int side=ManagedPositionSide();
   const double current_r=CurrentProgressR(side);
   if(current_r < 1.0 || g_initial_entry_price<=0.0 || g_initial_r_distance<=0.0)
      return false;

   // One coherent run-management rule: protect a portion of a real move,
   // then progressively give the trade more room as the move expands.
   // This is deliberately independent of legacy RANGE hold/profit stages.
   double lock_r=0.25;
   if(current_r>=2.0) lock_r=0.75;
   if(current_r>=3.0) lock_r=1.50;
   if(current_r>=4.0) lock_r=current_r-2.00;

   return ApplyManagedProfitLock(side,g_initial_entry_price,MathMax(0.0,lock_r));
}

bool ManageShortTermPriceActionExit()
{
   if(g_m3_position_managed)
      return false;
   if(!g_st_entry_active || ManagedPositionSide()==0)
      return false;

   const int side=ManagedPositionSide();
   MqlRates r[];
   ArrayResize(r,5);
   ArraySetAsSeries(r,true);
   double macd[];
   ArrayResize(macd,5);
   ArraySetAsSeries(macd,true);
   if(MarketDataCopyRates(_Symbol,AUTO_TF,0,5,r)<5 ||
      g_macd_handle==INVALID_HANDLE ||
      MarketDataCopyBuffer(g_macd_handle,JTC_MACD_WAVE_BUFFER,0,5,macd)<5)
      return false;

   const int held_bars=BarsSinceInitialEntry();
   if(held_bars<1)
      return false;

   const double avg_range=MathMax(_Point,
      (r[1].high-r[1].low+r[2].high-r[2].low+r[3].high-r[3].low)/3.0);
   const double body=MathAbs(r[1].close-r[1].open);
   const bool opposite_body = side>0 ?
      (r[1].close<r[1].open && body>=avg_range*0.30) :
      (r[1].close>r[1].open && body>=avg_range*0.30);
   const bool structure_break = side>0 ?
      (r[1].close<r[2].low) :
      (r[1].close>r[2].high);
   const bool macd_failure = side>0 ?
      (macd[1]<macd[2] && macd[2]<=macd[3]) :
      (macd[1]>macd[2] && macd[2]>=macd[3]);

   int failures=0;
   if(structure_break) failures++;
   if(opposite_body) failures++;
   if(macd_failure) failures++;

   // One weak/pullback bar is explicitly not an exit. The short-term thesis
   // is considered failed only when at least two independent pieces of closed-
   // bar evidence agree. This prevents the broker SL from being used as the
   // normal exit mechanism for ordinary pullbacks.
   if(failures>=2)
   {
      const string reason=StringFormat(
         "SHORT-TERM FAILURE EXIT | STRUCTURE=%d | OPP_BODY=%d | MACD=%d | HELD=%d",
         structure_break?1:0,opposite_body?1:0,macd_failure?1:0,held_bars);
      return ExitEngineSubmitManaged(reason);
   }

   // If the trade has already produced useful progress, the existing profit
   // protection may tighten the broker stop. It does not create a second
   // directional exit owner here.
   return false;
}

void ExitEngineManageRangePositionUnified()
{
   ENUM_JOON_RANGE_HOLD_STATE hold_state = JOON_RANGE_HOLD_WARNING;
   const bool state_ready = ManageRangeHoldStateEngine(hold_state);
   const int side = ManagedPositionSide();
   if(side == 0)
      return;

   // v8.00 RANGE management separation:
   // SignalEngine owns WATCH/FIRST interpretation for future entry lifecycle
   // only. Open-position loss protection belongs to Broker SL; HoldEngine
   // remains state/diagnostic support and RiskEngine manages profit locks.
   if(g_position_strategy==STRATEGY_RANGE)
   {
      if(g_st_entry_active)
      {
         if(ManageShortTermPriceActionExit())
            return;
         if(ManagedPositionSide()==0)
            return;
         ManageShortTermProfitRun();
         return;
      }
      ManageRangeLayerHoldStates(side);
      ManageRProfitProtection();
      return;
   }

   // HoldEngine has now produced the authoritative interpretation.

   // Diagnostic-only CSV. The decision point identifies the new unified
   // priority controller without changing the existing CSV schema.
   WriteRangeEarlyExitAudit(hold_state, "UNIFIED_RANGE_EXIT_PRIORITY");

   // Broker-side R protection remains active for every state. It may improve
   // the SL, but RANGE market exits below are owned by this single controller.
   ManageRProfitProtection();
   if(ManagedPositionSide() == 0)
      return;

   const bool profitable = ProfitExitAllowed();
   const int held_bars = BarsSinceInitialEntry();

   // RANGE low-energy CSV flags are produced by the ordinary RANGE signal
   // stale and must not influence M1/M3 management.
   const bool low_energy_warning = RangeLowEnergyWarningContext();

   // ExitEngine is the sole owner of the remaining strategic exits.
   if(ExitEngineHandleRangeHoldExit(hold_state, state_ready, profitable, held_bars,
                                    low_energy_warning,
                                    g_range_hold_runtime.warning_state_bars))
   {
      if(ManagedPositionSide()!=0)
         ManageRangeMaximumHoldingTime();
      return;
   }

   // NORMAL: only the existing peak/giveback Profit Guard manages exit.
   if(state_ready && hold_state == JOON_RANGE_HOLD_NORMAL)
      {
         int group_side = 0;
         double volume = 0.0, average_price = 0.0, sl = 0.0, tp = 0.0;
         datetime first_time = 0;
         if(profitable &&
            ManagedGroupInfo(group_side, volume, average_price, sl, tp, first_time) &&
            group_side != 0 && average_price > 0.0)
         {
            const double market_price = group_side > 0 ?
               SymbolInfoDouble(_Symbol, SYMBOL_BID) :
               SymbolInfoDouble(_Symbol, SYMBOL_ASK);
            if(market_price > 0.0)
            {
               const double progress_percent = group_side > 0 ?
                  (market_price - average_price) / average_price * 100.0 :
                  (average_price - market_price) / average_price * 100.0;
               ManageRangeProfitGuard(group_side, average_price,
                                      market_price, progress_percent);
            }
         }
         if(ManagedPositionSide() != 0)
            ManageRangeMaximumHoldingTime();
         return;
      }

   // STRONG: preserve the trend. R protection may move the broker SL, but
   if(state_ready && hold_state == JOON_RANGE_HOLD_STRONG)
      {
         ManageRangeMaximumHoldingTime();
         return;
      }

   // If the hold state cannot be calculated, use only the existing maximum
   // to prevent duplicate and conflicting RANGE close authority.
   ManageRangeMaximumHoldingTime();
}





void ExitEngineManageOpenPositionUnified()
{
   if(ManagedPositionSide() == 0)
      return;

   if(g_position_strategy == STRATEGY_TREND)
   {
      ExitEngineManageTrendPositionUnified();
   }
   else
      ExitEngineManageRangePositionUnified();
}





// v2.95 moved from SignalEngine: ExitEngine owns chase-profit exits.
bool ManageChaseTrendProfit(const int side,
                            const double progress_percent,
                            const int hold_score)
{
   if(!InpUseChaseTrendHold || !g_chase_entry_candidate)
      return false;

   int conditions = 0, macd_bars = 0, delta_bars = 0;
   string trend_detail = "";
   const bool strong_trend = EvaluateChaseTrendPersistence(side, conditions,
                                                            macd_bars, delta_bars,
                                                            trend_detail);
   const double giveback = g_profit_guard_peak_percent - progress_percent;

   if(strong_trend)
   {
      g_chase_trend_hold_active = true;
      g_chase_weakness_bars = 0;
      if(giveback >= InpChaseStrongGivebackPercent && ProfitExitAllowed())
      {
         ExitEngineSubmitManaged("CHASE TREND GIVEBACK: " + trend_detail +
            " | SCORE " + IntegerToString(hold_score) +
            " | PEAK " + DoubleToString(g_profit_guard_peak_percent, 3) + "% -> " +
            DoubleToString(progress_percent, 3) + "%");
      }
      return true;
   }

   if(g_chase_trend_hold_active)
   {
      g_chase_weakness_bars++;
      if(g_chase_weakness_bars < InpChaseWeaknessConfirmBars)
         return true;

      if(giveback >= InpChaseWeakGivebackPercent && ProfitExitAllowed())
      {
         ExitEngineSubmitManaged("CHASE TREND WEAK EXIT: " + trend_detail +
            " | SCORE " + IntegerToString(hold_score) +
            " | PEAK " + DoubleToString(g_profit_guard_peak_percent, 3) + "% -> " +
            DoubleToString(progress_percent, 3) + "%");
         return true;
      }

      // Confirmed loss of persistence: hand control back to the range guard.
      g_chase_trend_hold_active = false;
   }
   return false;
}


// v2.95: SignalEngine supplies completed-bar evidence; ExitEngine owns final
// close authorization. Conditions are identical to v2.94.
bool ExitEngineEvaluateCompletedBarSignalExit(const int position_side,
                                              const bool early_failure,
                                              const bool direction_hold_supported,
                                              const string direction_support_detail,
                                              const bool opposite_signal_confirmed,
                                              const bool fresh_extreme_update,
                                              const bool full_exit,
                                              const bool sideways_hold)
{
   // M3 AUTO owns strategy-level EXIT. Legacy SignalEngine MACD/MA22/Delta
   // exits must never compete with the canonical opposite-pre-signal exit or
   // M3 structural protection. Broker SL/TP and M3 protection remain separate.
   if(M3AutoEngineIsActive() && g_m3_position_managed)
      return false;

   if(early_failure && g_hold_state==HOLD_PROFIT_PROTECT && InternalExitAllowed())
   {
      if(direction_hold_supported)
      {
         NotifyPositionState(StringFormat("%s HOLD: EARLY FAILURE BLOCKED | %s",
            position_side>0 ? "LONG" : "SHORT",direction_support_detail));
      }
      else
      {
         g_profit_protection_state=PROFIT_PROTECTION_EXIT;
         g_last_position_state_alert="";
         ExitEngineSubmitManaged(StringFormat("%s EARLY FAILURE EXIT: %s",
            position_side>0 ? "LONG" : "SHORT",direction_support_detail));
         g_exit_opposite_close_bars=0;
         return true;
      }
   }

   if(g_hold_state==HOLD_EXIT_CANDIDATE && opposite_signal_confirmed &&
      !direction_hold_supported && !fresh_extreme_update && InternalExitAllowed())
   {
      g_profit_protection_state=PROFIT_PROTECTION_EXIT;
      g_last_position_state_alert="";
      ExitEngineSubmitManaged(StringFormat("%s EXIT: OPPOSITE SIGNAL + %s",
         position_side>0 ? "LONG" : "SHORT",direction_support_detail));
      g_exit_opposite_close_bars=0;
      return true;
   }

   if(full_exit && !direction_hold_supported && !sideways_hold && InternalExitAllowed())
   {
      g_last_position_state_alert="";
      ExitEngineSubmitManaged(position_side>0 ?
         "LONG EXIT: MACD BELOW ZERO CONFIRMED + MA22 + SELL DELTA" :
         "SHORT EXIT: MACD ABOVE ZERO CONFIRMED + MA22 + BUY DELTA");
      g_exit_opposite_close_bars=0;
      return true;
   }
   return false;
}

#endif // JOON_EXIT_ENGINE_MQH
