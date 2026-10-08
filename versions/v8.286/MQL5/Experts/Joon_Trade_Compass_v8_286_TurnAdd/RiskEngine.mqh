//+------------------------------------------------------------------+
//| RiskEngine.mqh                                               |
//| Joon Trend/Range AutoTrader modular component                    |
//+------------------------------------------------------------------+
#ifndef __JOON_RISKENGINE_MQH__
#define __JOON_RISKENGINE_MQH__


//+------------------------------------------------------------------+
double ValidStopPrice(const int side,
                      const double reference_price,
                      const double requested_distance)
{
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double minimum = ProtectionMinimumDistance();
   double desired =
      reference_price - side * MathMax(requested_distance, minimum);
   if(side > 0)
      desired = MathMin(desired, bid - minimum);
   else
      desired = MathMax(desired, ask + minimum);

   const double tick =
      MathMax(SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE), _Point);
   const int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   if(side > 0)
      return NormalizeDouble(MathFloor(desired / tick) * tick, digits);
   return NormalizeDouble(MathCeil(desired / tick) * tick, digits);
}

//+------------------------------------------------------------------+
double MoneyRisk(const ENUM_ORDER_TYPE order_type,
                 const double volume,
                 const double entry_price,
                 const double stop_price)
{
   double result = 0.0;
   if(volume <= 0.0 || entry_price <= 0.0 || stop_price <= 0.0 ||
      !OrderCalcProfit(order_type, _Symbol, volume,
                       entry_price, stop_price, result))
      return 1.0e100;
   return MathAbs(result);
}

//+------------------------------------------------------------------+
double RiskAverageClosedRange(const ENUM_TIMEFRAMES tf,
                              const int start_shift,
                              const int count)
{
   double total=0.0;
   int used=0;
   const int n=MathMax(1,count);
   for(int i=start_shift;i<start_shift+n;i++)
   {
      const double h=iHigh(_Symbol,tf,i);
      const double l=iLow(_Symbol,tf,i);
      if(h<=0.0 || l<=0.0 || h<=l)
         continue;
      total+=(h-l);
      used++;
   }
   return used>0 ? total/(double)used : 0.0;
}



//+------------------------------------------------------------------+
double StopDistancePrice(const double entry_price,
                         const double volume)
{
   if(g_stop_loss_percent <= 0.0)
      return 0.0;

   return entry_price * g_stop_loss_percent / 100.0;
}

//+------------------------------------------------------------------+
double CurrentProgressR(const int side)
{
   if(g_initial_entry_price <= 0.0 || g_initial_r_distance <= 0.0)
      return 0.0;
   const double quote =
      side > 0 ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
               : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   return side > 0 ?
      (quote - g_initial_entry_price) / g_initial_r_distance :
      (g_initial_entry_price - quote) / g_initial_r_distance;
}

//+------------------------------------------------------------------+
ENUM_ASSET_PROFILE DetectAssetProfile()
{
   if(!InpUseAssetProfile)
      return ASSET_GENERIC;
   if(InpAssetProfile != ASSET_AUTO)
      return InpAssetProfile;

   string symbol = _Symbol;
   StringToUpper(symbol);
   if(StringFind(symbol, "XAU") >= 0 || StringFind(symbol, "GOLD") >= 0)
      return ASSET_GOLD;
   if(StringFind(symbol, "WTI") >= 0 || StringFind(symbol, "USOIL") >= 0 ||
      StringFind(symbol, "XTI") >= 0 || StringFind(symbol, "OIL") >= 0)
      return ASSET_WTI;
   if(StringFind(symbol, "NAS") >= 0 || StringFind(symbol, "USTEC") >= 0 ||
      StringFind(symbol, "US100") >= 0 || StringFind(symbol, "NQ") >= 0)
      return ASSET_NASDAQ;
   if(StringFind(symbol, "COPPER") >= 0 || StringFind(symbol, "XCU") >= 0 ||
      StringFind(symbol, "HG") >= 0)
      return ASSET_COPPER;
   if(StringFind(symbol, "BTC") >= 0 || StringFind(symbol, "XBT") >= 0 ||
      StringFind(symbol, "BITCOIN") >= 0)
      return ASSET_BITCOIN;
   return ASSET_GENERIC;
}

//+------------------------------------------------------------------+
string AssetProfileName()
{
   if(g_asset_profile == ASSET_NASDAQ) return "NASDAQ";
   if(g_asset_profile == ASSET_GOLD) return "GOLD";
   if(g_asset_profile == ASSET_WTI) return "WTI";
   if(g_asset_profile == ASSET_COPPER) return "COPPER";
   if(g_asset_profile == ASSET_BITCOIN) return "BITCOIN";
   return "GENERIC";
}

//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
// Current protective-SL ownership helpers.
// g_protected_sl is the latest group-level SL accepted by the Risk/UI path.
// When it is not available yet, fall back to the configured initial-risk SL
// calculated from the actual fill without widening it because of current price.
double RiskSelectedPositionExpectedSL(const int side)
{
   if(side == 0)
      return 0.0;

   const double fill_price = PositionGetDouble(POSITION_PRICE_OPEN);
   const double volume = PositionGetDouble(POSITION_VOLUME);
   if(fill_price <= 0.0 || volume <= 0.0)
      return 0.0;

   const double tick = MathMax(SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE), _Point);
   const int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   const double stop_distance = StopDistancePrice(fill_price, volume);
   if(stop_distance <= 0.0)
      return 0.0;

   double initial_sl = fill_price - side * stop_distance;
   if(side > 0)
      initial_sl = NormalizeDouble(MathFloor(initial_sl / tick) * tick, digits);
   else
      initial_sl = NormalizeDouble(MathCeil(initial_sl / tick) * tick, digits);

   double expected_sl = initial_sl;
   if(g_m3_position_managed && g_m3_initial_structural_sl > 0.0)
      expected_sl = g_m3_initial_structural_sl;

   // M3 structural protection is the strategic owner. Legacy g_protected_sl
   // may still contain a stronger server/UI protection, so it can only tighten.
   if(g_m3_position_managed && g_m3_protected_sl > 0.0)
   {
      if(side > 0) expected_sl = MathMax(expected_sl, g_m3_protected_sl);
      else         expected_sl = MathMin(expected_sl, g_m3_protected_sl);
   }
   else if(g_protected_sl > 0.0)
   {
      if(side > 0) expected_sl = MathMax(expected_sl, g_protected_sl);
      else         expected_sl = MathMin(expected_sl, g_protected_sl);
   }
   return NormalizePrice(expected_sl);
}

//+------------------------------------------------------------------+
bool RiskSLProtectsAtLeast(const int side,
                           const double actual_sl,
                           const double expected_sl)
{
   if(side == 0 || actual_sl <= 0.0 || expected_sl <= 0.0)
      return false;
   const double tolerance =
      MathMax(SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE), _Point) * 1.1;
   if(side > 0)
      return actual_sl + tolerance >= expected_sl;
   return actual_sl - tolerance <= expected_sl;
}

//+------------------------------------------------------------------+
bool RiskExpectedSLBrokerValid(const int side, const double expected_sl)
{
   if(side == 0 || expected_sl <= 0.0)
      return false;
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double minimum = ProtectionMinimumDistance();
   if(side > 0)
      return bid > 0.0 && expected_sl < bid - minimum;
   return ask > 0.0 && expected_sl > ask + minimum;
}

//+------------------------------------------------------------------+
// Runtime safety net: verify the broker-side SL is at least as protective as
// the latest SL already decided by RiskEngine/UI. It never widens a stop.
// A missing/outdated SL is repaired; if the required protection can no longer
// be legally installed because price has crossed the protected level, the
// affected position is closed rather than silently reverting to a weaker SL.
bool EnsureManagedStopsProtected(const bool force=false)
{
   static ulong last_check_ms = 0;
   static ulong failure_ticket = 0;
   static int failure_count = 0;

   const ulong now_ms = GetTickCount64();
   if(!force && last_check_ms > 0 && now_ms - last_check_ms < 250)
      return true;
   last_check_ms = now_ms;

   bool all_protected = true;
   for(int i=PositionsTotal()-1; i>=0; --i)
   {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket) ||
         PositionGetString(POSITION_SYMBOL) != _Symbol ||
         (ulong)PositionGetInteger(POSITION_MAGIC) != InpMagicNumber)
         continue;

      // v6.55: a manually moved native MT5 broker SL owns its current level.
      // Profit-protection may still tighten it through the central modify gate.
      if(ManualBrokerSLIsOwned(ticket))
      {
         if(failure_ticket==ticket){ failure_ticket=0; failure_count=0; }
         continue;
      }

      const ENUM_POSITION_TYPE type =
         (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const int side = (type == POSITION_TYPE_BUY ? 1 : -1);
      const double actual_sl = PositionGetDouble(POSITION_SL);
      const double current_tp = PositionGetDouble(POSITION_TP);
      const double expected_sl = RiskSelectedPositionExpectedSL(side);
      if(expected_sl <= 0.0)
      {
         all_protected = false;
         continue;
      }

      if(RiskSLProtectsAtLeast(side, actual_sl, expected_sl))
      {
         if(failure_ticket == ticket)
         {
            failure_ticket = 0;
            failure_count = 0;
         }
         continue;
      }

      all_protected = false;

      // Do not widen the stop merely to satisfy the broker's current distance.
      // If the already-required protection is no longer placeable, safety-close
      // this specific ticket instead of falling back to a weaker initial stop.
      if(!RiskExpectedSLBrokerValid(side, expected_sl))
      {
         const string safety_reason = StringFormat(
            "SL SAFETY CLOSE | REQUIRED %.*f | ACTUAL %.*f | STOPS %d | FREEZE %d",
            _Digits,expected_sl,_Digits,actual_sl,
            (int)SymbolInfoInteger(_Symbol,SYMBOL_TRADE_STOPS_LEVEL),
            (int)SymbolInfoInteger(_Symbol,SYMBOL_TRADE_FREEZE_LEVEL));
         g_status = StringFormat("SL SAFETY CLOSE | TICKET %I64u | REQUIRED %.*f",
                                 ticket, _Digits, expected_sl);
         Print(g_status, " | actual_sl=", DoubleToString(actual_sl,_Digits));
         g_pending_exit_reason=safety_reason;
         g_pending_exit_reason_time=TimeCurrent();
         WriteUnifiedOrderSignalAudit("EXIT_REQUEST","SL_SAFETY","EXIT",side,0,0,
                                      "REQUESTED",safety_reason,true,false,0,ticket);
         if(TradeExecutePositionClose(ticket) && TradeResultSucceeded())
         {
            WriteUnifiedOrderSignalAudit("EXIT_RESULT","SL_SAFETY","EXIT",side,0,0,
                                         "SENT",safety_reason,true,true,
                                         (long)trade.ResultRetcode(),ticket);
            JRO_InvalidatePositionSnapshot();
            failure_ticket = 0;
            failure_count = 0;
         }
         else
         {
            WriteUnifiedOrderSignalAudit("EXIT_RESULT","SL_SAFETY","EXIT",side,0,0,
                                         "FAILED",safety_reason,true,false,
                                         (long)trade.ResultRetcode(),ticket);
            if(g_pending_exit_reason==safety_reason)
            {
               g_pending_exit_reason="";
               g_pending_exit_reason_time=0;
            }
            RegisterOrderFailure("SL SAFETY CLOSE FAILED");
         }
         continue;
      }

      ResetLastError();
      const bool modified =
         TradeExecutePositionModify(ticket, expected_sl, current_tp) &&
         TradeResultSucceeded();
      JRO_InvalidatePositionSnapshot();

      bool verified = false;
      if(modified && PositionSelectByTicket(ticket))
      {
         const double applied_sl = PositionGetDouble(POSITION_SL);
         verified = RiskSLProtectsAtLeast(side, applied_sl, expected_sl);
      }

      if(verified)
      {
         g_protected_sl = expected_sl;
         g_consecutive_order_failures = 0;
         if(failure_ticket == ticket)
         {
            failure_ticket = 0;
            failure_count = 0;
         }
         g_status = StringFormat("SL PROTECTION RESTORED | %.*f", _Digits, expected_sl);
         continue;
      }

      if(failure_ticket != ticket)
      {
         failure_ticket = ticket;
         failure_count = 1;
      }
      else
         failure_count++;

      g_status = StringFormat("SL SYNC ERROR | TICKET %I64u | TRY %d",
                              ticket, failure_count);
      Print(g_status, " | required=", DoubleToString(expected_sl,_Digits),
            " | actual=", DoubleToString(actual_sl,_Digits),
            " | retcode=", (int)trade.ResultRetcode(),
            " | ", trade.ResultRetcodeDescription());

      // A persistent broker modify failure must not leave an unprotected or
      // under-protected position alive indefinitely.
      if(failure_count >= 3 && PositionSelectByTicket(ticket))
      {
         const double latest_sl = PositionGetDouble(POSITION_SL);
         if(!RiskSLProtectsAtLeast(side, latest_sl, expected_sl))
         {
            const string safety_reason = StringFormat(
               "SL SAFETY CLOSE AFTER SYNC FAILURE | REQUIRED %.*f | ACTUAL %.*f | TRY %d",
               _Digits,expected_sl,_Digits,latest_sl,failure_count);
            g_pending_exit_reason=safety_reason;
            g_pending_exit_reason_time=TimeCurrent();
            WriteUnifiedOrderSignalAudit("EXIT_REQUEST","SL_SAFETY_SYNC","EXIT",side,0,0,
                                         "REQUESTED",safety_reason,true,false,0,ticket);
            if(TradeExecutePositionClose(ticket) && TradeResultSucceeded())
            {
               WriteUnifiedOrderSignalAudit("EXIT_RESULT","SL_SAFETY_SYNC","EXIT",side,0,0,
                                            "SENT",safety_reason,true,true,
                                            (long)trade.ResultRetcode(),ticket);
               JRO_InvalidatePositionSnapshot();
               failure_ticket = 0;
               failure_count = 0;
               g_status = "SL SAFETY CLOSE AFTER SYNC FAILURE";
            }
            else
            {
               WriteUnifiedOrderSignalAudit("EXIT_RESULT","SL_SAFETY_SYNC","EXIT",side,0,0,
                                            "FAILED",safety_reason,true,false,
                                            (long)trade.ResultRetcode(),ticket);
               if(g_pending_exit_reason==safety_reason)
               {
                  g_pending_exit_reason="";
                  g_pending_exit_reason_time=0;
               }
               RegisterOrderFailure("SL SAFETY CLOSE AFTER SYNC FAILURE FAILED");
            }
         }
      }
   }
   return all_protected;
}

bool ApplyPercentStopToTicket(const ulong ticket,
                              const int side,
                              const double protection_floor_sl=0.0,
                              const double requested_stop_distance=0.0)
{
   if(ticket == 0 || !PositionSelectByTicket(ticket))
      return false;

   const double fill_price = PositionGetDouble(POSITION_PRICE_OPEN);
   const double current_sl = PositionGetDouble(POSITION_SL);
   const double current_tp = PositionGetDouble(POSITION_TP);
   const double stop_distance =
      requested_stop_distance>0.0 ? requested_stop_distance :
      StopDistancePrice(fill_price,PositionGetDouble(POSITION_VOLUME));
   if(fill_price <= 0.0 || stop_distance <= 0.0)
      return false;

   double desired_sl =
      ValidStopPrice(side, fill_price, stop_distance);
   // ADD or recovery may already have a stronger final protected SL.
   // Never let a fresh percentage-stop calculation weaken that protection.
   if(protection_floor_sl > 0.0)
   {
      if(side > 0) desired_sl = MathMax(desired_sl, protection_floor_sl);
      else         desired_sl = MathMin(desired_sl, protection_floor_sl);
      desired_sl = NormalizePrice(desired_sl);
   }
   const double tolerance =
      MathMax(SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE), _Point) * 1.1;

   // The SL attached to the market request was calculated from the quote seen
   // before execution. Re-check it against the actual fill and correct any
   // slippage-induced difference instead of accepting any non-zero SL.
   if(current_sl > 0.0 && MathAbs(current_sl - desired_sl) <= tolerance)
   {
      g_ui_drag_entry = NormalizePrice(fill_price);
      g_ui_drag_sl = NormalizePrice(current_sl);
      g_protected_sl = NormalizePrice(current_sl);
      RequestUIRefresh();
      JRO_RequestChartRedraw();
      return true;
   }

   if(!TradeExecutePositionModify(ticket, desired_sl, current_tp) ||
      !TradeResultSucceeded() ||
      !PositionSelectByTicket(ticket))
      return false;

   const double applied_sl = PositionGetDouble(POSITION_SL);
   if(applied_sl <= 0.0 || MathAbs(applied_sl - desired_sl) > tolerance)
      return false;

   g_ui_drag_entry = NormalizePrice(fill_price);
   g_ui_drag_sl = NormalizePrice(applied_sl);
   g_protected_sl = NormalizePrice(applied_sl);
   RequestUIRefresh();
   JRO_RequestChartRedraw();
   return true;
}

bool GivebackReentryWindowActive(const int side, int &bars_since_exit)
{
   // v1.98 compatibility wrapper. Re-entry lifecycle ownership moved to the
   // shared context so live and tester use one permission/window source.
   if(side==0 || !g_reentry_context.active || g_reentry_context.side!=side)
   {
      bars_since_exit=-1;
      return false;
   }
   return ReentryContextWindowActive(bars_since_exit);
}

//+------------------------------------------------------------------+
void ManageMaximumHoldingTime()
{
   if(InpMaximumHoldingBars <= 0)
      return;

   int side = 0;
   double total_volume = 0.0, average_price = 0.0;
   double group_sl = 0.0, group_tp = 0.0;
   datetime first_time = 0;
   if(!ManagedGroupInfo(side, total_volume, average_price,
                        group_sl, group_tp, first_time) || first_time <= 0)
      return;

   // Use the oldest ticket in the managed group. ManagedPosition() may return
   // an arbitrary ticket on hedging accounts after additional entries.
   const int held_bars =
      iBarShift(_Symbol, ActiveManagementTF(), first_time, false);
   // profit-management tool. Losing trades use only the broker-side
   // percentage SL configured in the menu.
   // No time-based profit exit. Profitable positions are managed only by
   // excessive giveback or SignalEngine opposite-signal confirmation.
}

// v8.00: legacy third-signal structural loss-stop remains removed.
// RANGE loss-stop ownership is the broker SL created/maintained by PositionManager.


void ManageRangeMaximumHoldingTime()
{
   // v4.69 RANGE has no time-based strategy exit.
   if(g_position_strategy==STRATEGY_RANGE)
      return;
   if(InpRangeMaximumHoldingBars <= 0 || ManagedPositionSide() == 0) return;
   int side = 0; double volume = 0.0, average = 0.0, sl = 0.0, tp = 0.0;
   datetime first_time = 0;
   if(!ManagedGroupInfo(side, volume, average, sl, tp, first_time)) return;
   const int held_bars =
      iBarShift(_Symbol, ActiveManagementTF(), first_time, false);
   // No RANGE time-based profit exit. Giveback and confirmed reversal only.
}

void ManageProtectiveStops()
{
   if(!InpUseBreakEven && !InpUseTrailingStop)
      return;

   int side = 0;
   double total_volume = 0.0, average_price = 0.0;
   double group_sl = 0.0, group_tp = 0.0;
   datetime first_time = 0;
   if(!ManagedGroupInfo(side, total_volume, average_price,
                        group_sl, group_tp, first_time) ||
      average_price <= 0.0)
      return;

   const double market_price =
      side > 0 ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
               : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(market_price <= 0.0)
      return;

   const double profit_points =
      side * (market_price - average_price) / _Point;
   double desired_group_sl = 0.0;

   if(InpUseBreakEven &&
      profit_points >= InpBreakEvenTriggerPoints)
      desired_group_sl = NormalizePrice(average_price +
         side * InpBreakEvenLockPoints * _Point);

   if(InpUseTrailingStop &&
      profit_points >= InpTrailingStartPoints)
   {
      const double trailing_sl = NormalizePrice(market_price -
         side * InpTrailingDistancePoints * _Point);
      if(desired_group_sl == 0.0 ||
         (side > 0 && trailing_sl > desired_group_sl) ||
         (side < 0 && trailing_sl < desired_group_sl))
         desired_group_sl = trailing_sl;
   }

   if(desired_group_sl <= 0.0)
      return;
   if(side > 0 && desired_group_sl >= market_price)
      return;
   if(side < 0 && desired_group_sl <= market_price)
      return;

   bool modified = false;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket) ||
         PositionGetString(POSITION_SYMBOL) != _Symbol ||
         (ulong)PositionGetInteger(POSITION_MAGIC) != InpMagicNumber)
         continue;

      const ENUM_POSITION_TYPE type =
         (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if((side > 0 && type != POSITION_TYPE_BUY) ||
         (side < 0 && type != POSITION_TYPE_SELL))
         continue;

      const double current_sl = PositionGetDouble(POSITION_SL);
      const double current_tp = PositionGetDouble(POSITION_TP);
      const bool improves =
         current_sl <= 0.0 ||
         (side > 0 && desired_group_sl > current_sl) ||
         (side < 0 && desired_group_sl < current_sl);
      if(!improves)
         continue;

      if(!TradeExecutePositionModify(ticket, desired_group_sl, current_tp) ||
         !TradeResultSucceeded())
      {
         RegisterOrderFailure("PROTECTIVE STOP UPDATE FAILED");
         continue;
      }
      modified = true;
   }

   if(modified)
   {
      g_protected_sl = desired_group_sl;
      g_consecutive_order_failures = 0;
   }
}

// RiskEngine owns profit-protection state reset.
void RiskEngineResetProfitProtectionState()
{
   g_profit_protection_state = PROFIT_PROTECTION_UNKNOWN;
   ResetCsvProfitLockDiagnostics();
}


bool EnsureInitialRiskDistanceForProtection(const int side)
{
   if(g_initial_r_distance > 0.0)
      return true;

   int group_side=0;
   double volume=0.0,average=0.0,group_sl=0.0,group_tp=0.0;
   datetime first_time=0;
   if(!ManagedGroupInfo(group_side,volume,average,group_sl,group_tp,first_time) ||
      group_side!=side || average<=0.0)
      return false;

   if(g_initial_entry_price<=0.0)
      g_initial_entry_price=average;

   // First preference: the immutable menu-risk SL captured for the cycle.
   // v3.45 keeps this separate from any broker-adjusted/profit-lock SL.
   if(g_trade_cycle.initial_sl>0.0 && g_initial_entry_price>0.0)
      g_initial_r_distance=MathAbs(g_initial_entry_price-g_trade_cycle.initial_sl);

   // Restored-state fallback: rebuild 1R only from the configured menu risk at
   // the original entry. A current/group SL may already be BE, profit-lock,
   // manually changed, or broker-adjusted and must never redefine initial 1R.
   if(g_initial_r_distance<=0.0 && g_initial_entry_price>0.0)
   {
      const double base_volume =
         g_initial_entry_lots>0.0 ? g_initial_entry_lots : volume;
      const double menu_r_distance =
         StopDistancePrice(g_initial_entry_price,base_volume);
      if(menu_r_distance>0.0)
         g_initial_r_distance=MathMax(menu_r_distance,_Point);
   }


   if(g_initial_r_distance<=0.0)
      return false;

   g_sl_distance=g_initial_r_distance;
   return true;
}

void SyncRProtectionRuntimeToCycle()
{
   if(!TradeCycleOwnsOpenPosition())
      return;
   g_trade_cycle.peak_r=g_highest_profit_r;
   g_trade_cycle.hold_state=g_hold_state;
   g_trade_cycle.protection_state=g_profit_protection_state;
}


double InitialPeakFloorR(const int state,
                         const double peak_r)
{
   // v2.44: restore v2.34-style early holding. Dynamic Peak Floor is only
   // allowed after a meaningful 2R peak.
   const double dynamic_peak_floor_start_r=2.0;
   if(peak_r<dynamic_peak_floor_start_r)
      return 0.0;

   // Protection semantics must always be:
   // STRONG = loosest, NORMAL = middle, WARNING/PROFIT_PROTECT = tightest.
   // Reuse existing inputs, but normalize their ordering to prevent an input
   // combination from accidentally making STRONG tighter than WARNING.
   double configured_strong=InpStrongHoldGivebackUnder2R;
   if(peak_r>=3.0)
      configured_strong=InpStrongHoldGivebackOver3R;
   else if(peak_r>=2.0)
      configured_strong=InpStrongHoldGivebackUnder3R;

   const double configured_warning=InpProfitGivebackPercent;
   const double strong_giveback=MathMax(configured_strong,configured_warning);
   const double warning_giveback=MathMin(configured_strong,configured_warning);
   const double normal_giveback=MathMin(
      strong_giveback,
      MathMax(warning_giveback,InpNormalHoldGivebackPercent));

   double giveback_pct=100.0;
   if(state==HOLD_STRONG)
      giveback_pct=strong_giveback;
   else if(state==HOLD_NORMAL)
      giveback_pct=normal_giveback;
   else if(state==HOLD_WARNING || state==HOLD_PROFIT_PROTECT)
      giveback_pct=warning_giveback;
   else
      return 0.0;

   giveback_pct=MathMax(0.0,MathMin(100.0,giveback_pct));
   return peak_r*(1.0-giveback_pct/100.0);
}

bool ManageLayeredAddProfitProtection(const int side)
{
   if(!InpUseEntryTypeProtection || !g_has_add_entry ||
      g_additional_entry_count<=0 || side==0)
      return false;

   const double quote=side>0 ? SymbolInfoDouble(_Symbol,SYMBOL_BID)
                             : SymbolInfoDouble(_Symbol,SYMBOL_ASK);
   if(quote<=0.0) return false;

   const double range_lock_start_r=MathMax(0.0,InpRangeProfitLockStartR);
   const double range_lock_fraction=MathMax(0.0,MathMin(100.0,InpRangeProfitLockPercent))/100.0;

   // v8.176: every ADDN owns independent entry/R/peak/lock state.
   for(int i=0;i<ArraySize(g_add_layers);++i)
   {
      if(!g_add_layers[i].active || g_add_layers[i].volume<=0.0 ||
         g_add_layers[i].entry_price<=0.0 || g_add_layers[i].r_distance<=0.0) continue;
      const double current_r=side>0 ? (quote-g_add_layers[i].entry_price)/g_add_layers[i].r_distance
                                    : (g_add_layers[i].entry_price-quote)/g_add_layers[i].r_distance;
      if(current_r>g_add_layers[i].peak_r) g_add_layers[i].peak_r=current_r;
      if(g_add_layers[i].peak_r>=range_lock_start_r)
         g_add_layers[i].lock_r=MathMax(g_add_layers[i].lock_r,
                                        MathMax(0.0,g_add_layers[i].peak_r*range_lock_fraction));
   }
   JTAAddLayerMirrorLegacy();

   const int newest_stage=JTAAddLayerLatestActiveStage();
   if(newest_stage<=0) return false;
   const int i=newest_stage-1;
   const double newest_current_r=side>0 ? (quote-g_add_layers[i].entry_price)/g_add_layers[i].r_distance
                                        : (g_add_layers[i].entry_price-quote)/g_add_layers[i].r_distance;
   if(g_add_layers[i].peak_r<range_lock_start_r || g_add_layers[i].lock_r<=0.0 ||
      newest_current_r>g_add_layers[i].lock_r+1e-9) return false;

   return ExitEngineSubmitManaged(StringFormat(
      "LAYER PROFIT LOCK ADD%d | PEAK %.2fR CURRENT %.2fR LOCK %.2fR | RANGE CONFIG TRAIL",
      newest_stage,g_add_layers[i].peak_r,newest_current_r,g_add_layers[i].lock_r));
}

void ResetCsvProfitLockDiagnostics()
{
   g_csv_stage1_configured_r=0.0;
   g_csv_stage1_net_positive_r=0.0;
   g_csv_stage1_effective_r=0.0;
   g_csv_stage1_entry_charge=0.0;
   g_csv_stage1_negative_swap=0.0;
   g_csv_stage1_estimated_exit_cost=0.0;
   g_csv_stage1_one_r_money=0.0;

   g_csv_profit_lock_attempted=false;
   g_csv_profit_lock_requested_r=0.0;
   g_csv_profit_lock_requested_sl=0.0;
   g_csv_profit_lock_applied=false;
   g_csv_profit_lock_applied_sl=0.0;
   g_csv_profit_lock_retcode=0;
   g_csv_profit_lock_block_reason="";
   g_csv_profit_lock_ticket=0;
   g_csv_profit_lock_managed_count=0;
   g_csv_profit_lock_same_side_count=0;
   g_csv_profit_lock_current_sl_before=0.0;
   g_csv_profit_lock_actual_sl_after=0.0;
   g_csv_profit_lock_improvement_points=0.0;
   g_csv_profit_lock_improves=false;
   g_csv_profit_lock_bid=0.0;
   g_csv_profit_lock_ask=0.0;
   g_csv_profit_lock_stop_level_points=0;
   g_csv_profit_lock_freeze_level_points=0;
   g_csv_profit_lock_minimum_distance=0.0;
   g_csv_profit_lock_verify_pass=false;
}

double NetPositiveStage1LockR(const int side,
                                    const double average_price)
{
   g_csv_stage1_configured_r=InpProfitLockStage1R;
   g_csv_stage1_net_positive_r=0.01;
   g_csv_stage1_effective_r=MathMax(InpProfitLockStage1R,0.01);
   g_csv_stage1_entry_charge=0.0;
   g_csv_stage1_negative_swap=0.0;
   g_csv_stage1_estimated_exit_cost=0.0;
   g_csv_stage1_one_r_money=0.0;

   if(side==0 || average_price<=0.0 || g_initial_r_distance<=0.0)
      return g_csv_stage1_effective_r;

   int group_side=0;
   double volume=0.0, group_average=0.0, group_sl=0.0, group_tp=0.0;
   datetime first_time=0;
   if(!ManagedGroupInfo(group_side,volume,group_average,group_sl,group_tp,first_time) ||
      group_side!=side || volume<=0.0)
      return g_csv_stage1_effective_r;

   const ENUM_ORDER_TYPE order_type=(side>0 ? ORDER_TYPE_BUY : ORDER_TYPE_SELL);
   const double one_r_price=average_price+side*g_initial_r_distance;
   double one_r_money=0.0;
   if(!OrderCalcProfit(order_type,_Symbol,volume,average_price,one_r_price,one_r_money) ||
      MathAbs(one_r_money)<=1e-9)
      return g_csv_stage1_effective_r;
   one_r_money=MathAbs(one_r_money);
   g_csv_stage1_one_r_money=one_r_money;

   double entry_charge=0.0;
   if(g_trade_cycle.entry_deal_ticket!=0 &&
      HistoryDealSelect(g_trade_cycle.entry_deal_ticket))
   {
      entry_charge=MathAbs(HistoryDealGetDouble(g_trade_cycle.entry_deal_ticket,DEAL_COMMISSION))+
                   MathAbs(HistoryDealGetDouble(g_trade_cycle.entry_deal_ticket,DEAL_FEE));
   }

   double negative_swap=0.0;
   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      const ulong ticket=PositionGetTicket(i);
      if(ticket==0 || !PositionSelectByTicket(ticket) ||
         PositionGetString(POSITION_SYMBOL)!=_Symbol ||
         (ulong)PositionGetInteger(POSITION_MAGIC)!=InpMagicNumber)
         continue;
      negative_swap+=MathMax(0.0,-PositionGetDouble(POSITION_SWAP));
   }

   const double estimated_exit_cost=entry_charge;
   const double required_money=entry_charge+estimated_exit_cost+negative_swap;
   const double cost_r=required_money/one_r_money;
   const double net_positive_r=MathMax(cost_r,0.01);
   const double effective_r=MathMax(InpProfitLockStage1R,net_positive_r);

   g_csv_stage1_entry_charge=entry_charge;
   g_csv_stage1_negative_swap=negative_swap;
   g_csv_stage1_estimated_exit_cost=estimated_exit_cost;
   g_csv_stage1_net_positive_r=net_positive_r;
   g_csv_stage1_effective_r=effective_r;
   return effective_r;
}

// Reuse the existing M1 MACD/Delta sources; no new score/state engine.
// Both momentum and order-flow must weaken in the position direction before
// a sub-0.35R profit floor is allowed.

// v3.87: RANGE M2 momentum + Delta deterioration confirmation for the
// 0.25R -> first-trigger pre-protection gap. Reuse the permanent AUTO M2
// handles so this is independent of the user-selected chart/signal display TF.
// Completed bars [1]/[2] only: no live-bar flicker is allowed to arm the floor.
bool RangeM2MomentumDeltaWeakness(const int side,string &detail)
{
   detail="";
   if(side==0 || g_macd_handle==INVALID_HANDLE || g_delta_handle==INVALID_HANDLE)
      return false;

   double macd[],delta[];
   ArrayResize(macd,3); ArrayResize(delta,3);
   ArraySetAsSeries(macd,true); ArraySetAsSeries(delta,true);
   if(MarketDataCopyBuffer(g_macd_handle,JTC_MACD_BASE_BUFFER,0,3,macd)<3 ||
      MarketDataCopyBuffer(g_delta_handle,2,0,3,delta)<3)
      return false;

   const bool momentum_bad=side>0 ? macd[1]<macd[2] : macd[1]>macd[2];
   const bool delta_bad=side>0 ? delta[1]<delta[2] : delta[1]>delta[2];
   detail=StringFormat("M2 RANGE PRE-TRIGGER WEAK | MACD%d DELTA%d",
      momentum_bad?1:0,delta_bad?1:0);
   return momentum_bad && delta_bad;
}

void ManageRProfitProtection()
{
   // v8.60: M3 AUTO owns its complete strategic protection lifecycle.
   // Generic RANGE/TREND R protection must never create a second M3 stop owner.
   if(g_m3_position_managed)
      return;
   if(!InpUseRProfitProtection)
      return;

   const int side = ManagedPositionSide();
   if(side == 0)
      return;
   if(!EnsureInitialRiskDistanceForProtection(side))
      return;

   // INITIAL peak is always tracked from the INITIAL fill, even while ADD
   // layers exist. This preserves the long-running trend anchor independently.
   double average_price=g_initial_entry_price;
   const double current_r=CurrentProgressR(side);
   if(current_r>g_highest_profit_r)
      g_highest_profit_r=current_r;
   SyncRProtectionRuntimeToCycle();

   // RANGE protection uses one tester-configurable trailing rule for INITIAL, ADD1 and ADD2.
   // Start R and lock percentage are shared. Broker/layer locks remain monotonic and never loosen.
   if(g_position_strategy==STRATEGY_RANGE)
   {
      const double range_lock_start_r=MathMax(0.0,InpRangeProfitLockStartR);
      const double range_lock_fraction=MathMax(0.0,MathMin(100.0,InpRangeProfitLockPercent))/100.0;
      if(g_highest_profit_r>=range_lock_start_r)
      {
         const double simple_lock_r=MathMax(0.0,g_highest_profit_r*range_lock_fraction);
         ApplyManagedProfitLock(side,average_price,simple_lock_r);
      }
      if(g_has_add_entry && g_additional_entry_count>0)
         ManageLayeredAddProfitProtection(side);
      return;
   }

   

   // Newest ADD layer owns the fast lock. Once its lock triggers, only that
   // layer is realized LIFO. Do not drag a common broker SL across every layer.
   if(g_has_add_entry && g_additional_entry_count>0)
   {
      ManageLayeredAddProfitProtection(side);
      return;
   }

   // No ADD layers remain: this lower section is the TREND/legacy staged

   double trigger_r = InpProfitProtectTriggerR;

   const double cost_positive_stage1 = NetPositiveStage1LockR(side,average_price);
   double stage1_lock = cost_positive_stage1;
   double stage2_r = InpProfitProtectStage2R;
   double stage2_lock = InpProfitLockStage2R;
   double stage3_r = InpProfitProtectStage3R;
   double stage3_lock = InpProfitLockStage3R;

   //
   // Do NOT protect merely because Peak touched 0.15R.  Reuse the existing
   // M1 MACD+Delta weakness confirmation and require a substantial 60% Peak
   // giveback while Hold is no longer STRONG.  This targets trades that first
   // made meaningful progress and then visibly failed, without turning normal
   // M1 pullbacks into automatic exits.
   //
   // The action is only the existing cost-aware Stage-1 broker Profit Floor;
   // no new market-exit rule, score, state engine, or input is introduced.

   // Only fill the 0.25R -> generic trigger gap. The user's normal 0.35R+
   // Profit Protection and the existing CHASE profile remain unchanged.
   // A mere pullback is not enough: Peak must actually be falling, Hold may
   // no longer be STRONG, and both M1 MACD momentum and Delta must weaken.

   // v3.87: RANGE original INITIAL pre-trigger retention for the 0.25R ->
   // generic first-trigger gap. Historical GOLD RANGE trades repeatedly reached
   // roughly 0.32R-0.34R of Peak profit and then returned into loss because the
   // normal 0.35R Profit Protection trigger had not armed yet.
   //
   // alone. Require the original RANGE INITIAL position, no ADD/CHASE, positive
   // current R, Hold already degraded from STRONG to NORMAL/WARNING, >=60% Peak
   // giveback, and completed-M2 MACD + Delta deterioration. The action is only
   // the existing cost-aware Stage-1 Broker/Virtual Profit Floor. No market
   // exit, new state, score or input is introduced.
   const bool range_initial_pretrigger_profile =
      g_position_strategy==STRATEGY_RANGE &&
      IsInitialEntryType(g_entry_type) &&
      g_entry_type!=ENTRY_CHASE &&
      !g_has_add_entry &&
      g_additional_entry_count<=0 &&
      trigger_r>0.25 &&
      g_highest_profit_r>=0.25 &&
      g_highest_profit_r<trigger_r &&
      current_r>0.0 &&
      current_r<g_highest_profit_r &&
      (g_hold_state==HOLD_NORMAL ||
       g_hold_state==HOLD_WARNING ||
       g_hold_state==HOLD_PROFIT_PROTECT);

   if(range_initial_pretrigger_profile)
   {
      const double giveback_pct =
         g_highest_profit_r>0.0 ?
         100.0*(g_highest_profit_r-current_r)/g_highest_profit_r : 0.0;

      if(giveback_pct>=60.0)
      {
         string range_pretrigger_weak_detail="";
         if(RangeM2MomentumDeltaWeakness(side,range_pretrigger_weak_detail))
         {
            const double pretrigger_lock_r=cost_positive_stage1;
            if(pretrigger_lock_r>=0.0)
            {
               g_status=StringFormat(
                  "RANGE PRE-TRIGGER STAGE1 | PEAK %.2fR CURRENT %.2fR GIVEBACK %.1f%% LOCK %.2fR | %s",
                  g_highest_profit_r,current_r,giveback_pct,
                  pretrigger_lock_r,range_pretrigger_weak_detail);
               ApplyManagedProfitLock(side,average_price,pretrigger_lock_r);
            }
         }
      }
   }

   // Entry starts UNKNOWN. Reaching the first trigger only arms peak tracking;
   // it never moves the broker SL to breakeven by itself.
   if(g_highest_profit_r < trigger_r)
   {
      g_profit_protection_state = PROFIT_PROTECTION_UNKNOWN;
      SyncRProtectionRuntimeToCycle();
      return;
   }

   if(g_profit_protection_state == PROFIT_PROTECTION_UNKNOWN)
   {
      g_profit_protection_state = PROFIT_PROTECTION_ARMED;
      WriteLifecycleEvent("PROFIT_PROTECTION_ARMED", side,
         DataExportHoldStateName(), DataExportHoldStateName(),
         StringFormat("%s | PEAK %.2fR >= TRIGGER %.2fR; TRACK ONLY",
                      "INITIAL",
                      g_highest_profit_r, trigger_r),
         0, average_price, 0.0, 0.0, TimeCurrent());
   }

   double lock_r = 0.0;
   bool apply_broker_lock = false;

   if(g_hold_state == HOLD_EXIT_CANDIDATE)
   {
      g_profit_protection_state = PROFIT_PROTECTION_EXIT;
      SyncRProtectionRuntimeToCycle();
      return; // strategy engine owns immediate market exit
   }
   else if(g_hold_state == HOLD_STRONG)
   {
      g_profit_protection_state = PROFIT_PROTECTION_STRONG;

      // v3.34 RANGE INITIAL strong-hold protection:
      // RANGE position is still STRONG and no ADD layer exists, reaching the
      // first 0.35R trigger only arms/tracks protection.  Do not pull the
      // broker SL to the Stage-1 BE floor during the normal 0.35R->Stage-2
      // pullback zone.  Start the real broker floor from the existing Stage-2
      // threshold instead.  CHASE keeps its faster legacy protection profile.
      const bool range_initial_strong_slow_protect =
         g_position_strategy == STRATEGY_RANGE &&
         IsInitialEntryType(g_entry_type) &&
         g_entry_type != ENTRY_CHASE &&
         !g_has_add_entry;

      if(range_initial_strong_slow_protect)
      {
         // v3.68: STRONG remains STRONG and no market exit is introduced.
         // Once RANGE INITIAL has earned the normal first trigger, release only
         // the Stage-1 delay after a substantial 60% Peak giveback. This stops
         // a +0.35R+ trade from returning all the way into loss while preserving
         // normal STRONG pullback freedom before that giveback threshold.
         const double range_strong_giveback_pct =
            g_highest_profit_r>0.0 ?
            100.0*(g_highest_profit_r-current_r)/g_highest_profit_r : 0.0;
         const bool release_strong_stage1_delay =
            g_highest_profit_r>=trigger_r &&
            g_highest_profit_r<stage2_r &&
            range_strong_giveback_pct>=60.0;

         if(g_highest_profit_r >= stage2_r)
         {
            lock_r = stage2_lock;
            apply_broker_lock = lock_r >= 0.0;
         }
         else if(release_strong_stage1_delay)
         {
            lock_r = stage1_lock;
            apply_broker_lock = lock_r >= 0.0;
            g_status=StringFormat(
               "RANGE STRONG STAGE1 RELEASE | PEAK %.2fR CURRENT %.2fR GIVEBACK %.1f%% LOCK %.2fR",
               g_highest_profit_r,current_r,range_strong_giveback_pct,lock_r);
         }
         else
         {
            lock_r = 0.0;
            apply_broker_lock = false;
         }
      }
      else
      {
         // trigger, STRONG HOLD retains at least the Stage-1 floor.
         lock_r = stage1_lock;
         apply_broker_lock = lock_r >= 0.0;
      }

      // Existing STRONG trend protection remains unchanged above Stage-3.
      if(g_highest_profit_r >= stage3_r)
      {
         lock_r = MathMax(lock_r,
                          MathMin(stage3_lock, InpStrongHoldMinimumLockR));
         apply_broker_lock = true;
      }
   }
   else if(g_hold_state == HOLD_WARNING ||
           g_hold_state == HOLD_PROFIT_PROTECT)
   {
      g_profit_protection_state = PROFIT_PROTECTION_WARNING;
      // WARNING progressively tightens protection. For the INITIAL profile
      // stage1_lock is the cost-aware net-positive floor.
      lock_r = stage1_lock;
      if(g_highest_profit_r >= stage2_r) lock_r = stage2_lock;
      if(g_highest_profit_r >= stage3_r) lock_r = stage3_lock;

      // the generic trigger and Hold degrades to WARNING/PROFIT_PROTECT, retain
      // a modest fraction of the achieved Peak instead of allowing a full
      // return to the Stage-1 / near-BE floor.  Reuse the existing giveback
      // inputs; no new state, score, or exit engine is introduced.
      //
      // First WARNING: use the NORMAL giveback allowance (typically 60%),
      // therefore preserving about 40% of Peak.  If WARNING persists for at
      // least two completed hold bars AND the existing M1 MACD+Delta weakness
      // confirmation agrees, tighten to the normal profit-giveback allowance
      // (typically 40%), preserving about 60% of Peak.
      // STRONG/NORMAL Hold branches are unchanged, so trend continuation keeps
      // its original holding freedom.  Broker SL monotonicity prevents a later
      // STRONG recovery from loosening a floor already secured here.

      apply_broker_lock = lock_r >= 0.0;
   }
   else
   {
      g_profit_protection_state = PROFIT_PROTECTION_NORMAL;

      // v2.29 minimal profit-retention fix:
      // After the first trigger, NORMAL HOLD also keeps at least the Stage-1
      // floor.  HOLD continues normally; only loss-zone re-entry is prevented.
      lock_r = stage1_lock;
      apply_broker_lock = lock_r >= 0.0;

      //
      // NORMAL positions could reach meaningful Peak profit, then return almost
      // all the way to the cost-aware Stage-1 floor while Hold had not degraded
      // to WARNING.  Do not tighten merely because Peak touched 0.35R: preserve
      // normal pullback freedom and require BOTH a substantial Peak giveback and
      // the existing M1 MACD+Delta weakness confirmation.
      //
      // Scope is deliberately narrow: ENTRY_NORMAL, original INITIAL only, no
      // ADD layer, no CHASE, Hold NORMAL, Peak 0.35R..<0.75R, current profit
      // still positive, >=50% Peak giveback.  Reuse the existing NORMAL
      // giveback input, so the default 60% allowance preserves about 40% of
      // Peak.  Only the existing Broker/Virtual Profit Floor pathway is used;
      // no market exit, new state, score or input is introduced.

      if(g_highest_profit_r >= stage2_r)
      {
         lock_r = stage2_lock;
         apply_broker_lock = true;
      }
      if(g_highest_profit_r >= stage3_r)
      {
         lock_r = stage3_lock;
         apply_broker_lock = true;
      }
   }

   // v2.40: once Peak grows beyond the fixed stage locks, retain a
   // configurable fraction of that Peak using the EXISTING giveback settings.
   // This keeps STRONG the loosest, NORMAL tighter, and WARNING tightest without
   // adding another score/state engine.
   const double peak_floor_r=InitialPeakFloorR(g_hold_state,g_highest_profit_r);
   if(peak_floor_r>lock_r)
   {
      lock_r=peak_floor_r;
      apply_broker_lock=true;
   }

   // v3.85 RANGE INITIAL continuous Peak retention.
   //
   // Historical RANGE tests exposed a discontinuity at Stage-2: below
   // Stage-2, v3.69 retained a state-dependent fraction of Peak, but once
   // Peak crossed Stage-2 the fixed +Stage-2 lock could become LOWER than the
   // Peak-relative floor that had just been earned. Keep the existing fixed
   // Stage-2/Stage-3 locks, but continue the same NORMAL/WARNING Peak-relative
   // retention up to the existing >=2R dynamic Peak Floor start. Because this
   // block only raises lock_r when its floor is higher, the effective rule is
   // max(existing Stage lock, Peak-relative floor).
   //
   // STRONG remains intentionally unchanged and keeps its slow-hold freedom.
   // NORMAL  : preserve (100 - InpNormalHoldGivebackPercent)% of Peak.
   // WARNING : preserve (100 - InpProfitGivebackPercent)% of Peak.
   //
   // No new state/input/market exit is introduced. At >=2R the existing
   // InitialPeakFloorR() dynamic protection remains authoritative.
   const bool range_initial_mid_peak_profile =
      g_position_strategy==STRATEGY_RANGE &&
      IsInitialEntryType(g_entry_type) &&
      g_entry_type!=ENTRY_CHASE &&
      !g_has_add_entry &&
      g_additional_entry_count<=0 &&
      g_highest_profit_r>=trigger_r &&
      g_highest_profit_r<2.0;

   if(range_initial_mid_peak_profile &&
      g_hold_state==HOLD_NORMAL)
   {
      const double giveback_pct=
         MathMax(0.0,MathMin(100.0,InpNormalHoldGivebackPercent));
      const double floor_r=
         g_highest_profit_r*(1.0-giveback_pct/100.0);

      if(floor_r>lock_r)
      {
         lock_r=floor_r;
         apply_broker_lock=true;
         g_status=StringFormat(
            "RANGE NORMAL MID-PEAK FLOOR | PEAK %.2fR LOCK %.2fR",
            g_highest_profit_r,lock_r);
      }
   }
   else if(range_initial_mid_peak_profile &&
           (g_hold_state==HOLD_WARNING ||
            g_hold_state==HOLD_PROFIT_PROTECT))
   {
      const double giveback_pct=
         MathMax(0.0,MathMin(100.0,InpProfitGivebackPercent));
      const double floor_r=
         g_highest_profit_r*(1.0-giveback_pct/100.0);

      if(floor_r>lock_r)
      {
         lock_r=floor_r;
         apply_broker_lock=true;
         g_status=StringFormat(
            "RANGE WARNING MID-PEAK FLOOR | PEAK %.2fR LOCK %.2fR",
            g_highest_profit_r,lock_r);
      }
   }

   // Do not invent a new state/score engine. Reuse the existing M1 weakness
   // diagnostic plus the existing CHASE giveback inputs. STRONG HOLD is left
   // deliberately loose: it receives only the fixed CHASE stage lock above.
   //
   // NORMAL/WARNING below the generic +0.35R trigger may tighten the broker
   // floor only when at least 2 of 4 existing M1 weakness conditions agree.
   // This closes the +0.20~0.35R CHASE protection gap without forcing an early
   // market exit. The floor can only move in the profitable direction.

   SyncRProtectionRuntimeToCycle();
   if(apply_broker_lock)
      ApplyManagedProfitLock(side, average_price, lock_r);

   // The initial directional position owns the trend while STRONG/NORMAL hold
   // remains valid.  Do not convert a normal pullback into a market giveback
   // exit followed by a riskier same-direction chase/re-entry.  This bypasses
   // only the market giveback exit below; protective SL updates above and all
   // WARNING/EXIT_CANDIDATE/opposite-failure exits remain available.
   const bool initial_directional_hold_protected =
      InpUseInitialDirectionalHoldProtection &&
      IsInitialEntryType(g_entry_type) &&
      (g_hold_state == HOLD_STRONG || g_hold_state == HOLD_NORMAL);
   if(initial_directional_hold_protected)
      return;

   // v1.97: STRONG/NORMAL initial positions are already protected above.
   // Once HoldEngine degrades the position to WARNING/PROFIT_PROTECT, an
   // excessive giveback is an explicit exception to the opposite-2 hold rule.
   // ADD layers also keep their faster giveback profiles.

   if(g_highest_profit_r < InpMinimumGivebackPeakR ||
      g_highest_profit_r <= 0.0)
      return;

   // v2.42: INITIAL market giveback exit is intentionally delayed until a
   // meaningful peak has been achieved. Below 2R, WARNING/PROFIT_PROTECT may
   // still tighten BE/Peak Floor above, but cannot force an immediate market
   // exit. This avoids cutting a normal early pullback such as Peak 1.28R.
   // ADD layers keep their own faster layer-specific protection unchanged.
   const double initial_market_exit_min_peak_r = 2.0;
   if(IsInitialEntryType(g_entry_type) &&
      g_highest_profit_r < initial_market_exit_min_peak_r)
      return;

   double allowed_giveback = 0.0;
   if(g_hold_state == HOLD_STRONG)
   {
      if(g_highest_profit_r < 2.0)
         allowed_giveback = InpStrongHoldGivebackUnder2R;
      else if(g_highest_profit_r < 3.0)
         allowed_giveback = InpStrongHoldGivebackUnder3R;
      else
         allowed_giveback = InpStrongHoldGivebackOver3R;
   }
   else if(g_hold_state == HOLD_NORMAL)
      allowed_giveback = InpNormalHoldGivebackPercent;
   else
      allowed_giveback = InpProfitGivebackPercent;

   if(allowed_giveback <= 0.0)
      return;

   const double giveback_percent =
      100.0 * (g_highest_profit_r - current_r) / g_highest_profit_r;
   if(giveback_percent >= allowed_giveback &&
      current_r > 0.0 && InternalExitAllowed())
   {
      // INITIAL uses the raised broker Profit Floor as the retention mechanism.
      // Do not turn a single WARNING/giveback event into an immediate market
      // exit. Market-exit authority remains with EXIT_CANDIDATE, opposite
      // POSITION FINAL 2/2 and hard/structural safety.
      if(IsInitialEntryType(g_entry_type))
      {
         g_status=StringFormat(
            "INITIAL HOLD / PROFIT FLOOR | PEAK %.2fR CURRENT %.2fR GIVEBACK %.1f%%",
            g_highest_profit_r,current_r,giveback_percent);
      }
      else
      {
         const string management_name=EntryTypeName(g_entry_type);
         ExitEngineSubmitManaged(StringFormat(
            "PROFIT PROTECTION GIVEBACK EXIT | %s/%s %s | PEAK %.2fR CURRENT %.2fR GIVEBACK %.1f%%",
            management_name,g_entry_quality,
            DataExportProfitProtectionStateName(),g_highest_profit_r,
            current_r,giveback_percent));
      }
   }
}

//+------------------------------------------------------------------+




// reclassifying NORMAL as CHASE. This runs only on completed M1 bars, only for
// the original INITIAL position, and only before the trade has achieved 0.10R.
// It reuses the existing M1 MACD/Delta data and the existing managed-exit path.






// ===== RANGE profit-lock ownership moved from HoldEngine (v2.09) =====
void ManageRangeProfitGuard(const int side,
                            const double average_price,
                            const double market_price,
                            const double progress_percent)
{
   if(!InpUseRangeProfitGuard || progress_percent <= 0.0)
      return;

   double activation_multiplier = 1.0;
   double giveback_multiplier = 1.0;
   if(InpUseEntryConfidenceProfitManagement &&
      g_position_strategy == STRATEGY_RANGE)
   {
      if(g_entry_confidence == ENTRY_CONFIDENCE_MEDIUM)
      {
         activation_multiplier =
            MathMax(0.10, InpMediumConfidenceActivationMultiplier);
         giveback_multiplier =
            MathMax(0.10, InpMediumConfidenceGivebackMultiplier);
      }
      else if(g_entry_confidence == ENTRY_CONFIDENCE_LOW)
      {
         activation_multiplier =
            MathMax(0.10, InpLowConfidenceActivationMultiplier);
         giveback_multiplier =
            MathMax(0.10, InpLowConfidenceGivebackMultiplier);
      }
   }

   const double effective_activation =
      InpProfitGuardActivationPercent * activation_multiplier;

   if(progress_percent > g_profit_guard_peak_percent)
      g_profit_guard_peak_percent = progress_percent;

   if(progress_percent >= effective_activation)
      g_profit_guard_activated = true;

   if(!g_profit_guard_activated)
      return;

   // v2.34: RANGE ProfitGuard no longer recalculates or reinterprets a second
   // Hold score. HoldEngine owns STRONG/NORMAL/WARNING/EXIT classification.
   // ExitEngine calls this guard only for canonical NORMAL state.
   if((g_position_strategy == STRATEGY_RANGE) &&
      g_hold_state != HOLD_NORMAL)
      return;

   // v3.30: keep the existing INITIAL directional-hold protection consistent
   // across both R-based profit protection and the legacy percent ProfitGuard.
   // A NORMAL/STRONG original position with no ADD layer must not be converted
   // into an immediate market exit by a small percent giveback while direction
   // remains valid. WARNING/EXIT_CANDIDATE, ADD/CHASE layer management, hard SL,
   // opposite-final and structural safety paths remain unchanged.
   const bool initial_directional_profitguard_protected =
      InpUseInitialDirectionalHoldProtection &&
      IsInitialEntryType(g_entry_type) &&
      !g_has_add_entry &&
      (g_hold_state == HOLD_STRONG || g_hold_state == HOLD_NORMAL);
   if(initial_directional_profitguard_protected)
      return;

   // Original INITIAL layer still respects the existing opposite POSITION FINAL
   // protection before a market giveback exit may occur.
   if(g_position_strategy == STRATEGY_RANGE &&
      !g_has_add_entry && !RangeConfirmedProfitExitAllowed())
      return;

   const double giveback =
      g_profit_guard_peak_percent - progress_percent;

   const double normal_peak_allowance =
      g_profit_guard_peak_percent *
      MathMax(0.0, InpRangeNormalHoldPeakGivebackPercent) / 100.0;
   const double normal_allowed_giveback =
      MathMax(InpProfitGuardMaximumGivebackPercent * giveback_multiplier,
              normal_peak_allowance * giveback_multiplier);

   if(giveback >= normal_allowed_giveback && ProfitExitAllowed())
   {
      ExitEngineSubmitManaged(
         "RANGE NORMAL-HOLD GIVEBACK | ALLOW " +
         DoubleToString(normal_allowed_giveback, 3) + "% | PEAK " +
         DoubleToString(g_profit_guard_peak_percent, 3) + "% -> " +
         DoubleToString(progress_percent, 3) + "%");
   }
}

void ManageShortTermProfit()
{
   if(!InpUseShortTermProfitTaking)
      return;

   int side=0;
   double total_volume=0.0,average_price=0.0;
   double group_sl=0.0,group_tp=0.0;
   datetime first_time=0;
   if(!ManagedGroupInfo(side,total_volume,average_price,
                        group_sl,group_tp,first_time) ||
      average_price<=0.0)
      return;

   const double market_price=
      side>0 ? SymbolInfoDouble(_Symbol,SYMBOL_BID)
             : SymbolInfoDouble(_Symbol,SYMBOL_ASK);
   if(market_price<=0.0)
      return;

   const double progress_percent=
      side>0 ? (market_price-average_price)/average_price*100.0
             : (average_price-market_price)/average_price*100.0;

   // v2.48 ownership cleanup:
   // HoldEngine is the only MACD/Delta/MA direction interpreter.
   // RiskEngine may protect money (ProfitGuard / BE / Peak Floor) but cannot
   // recreate a short-term momentum score and submit its own directional exit.
   string hold_detail="";
   const bool direction_hold=
      progress_percent>0.0 &&
      ShouldHoldRangePosition(side,hold_detail);

   if(direction_hold)
   {
      if(!g_short_term_break_even_applied &&
         progress_percent>=InpShortTermBreakEvenPercent)
         ApplyShortTermBreakEven(side,average_price);

      static datetime last_hold_log_bar=0;
      const datetime hold_bar=iTime(_Symbol,AUTO_TF,1);
      if(hold_bar>0 && hold_bar!=last_hold_log_bar)
      {
         last_hold_log_bar=hold_bar;
         Print("RANGE SEGMENT HOLD: ",hold_detail,
               " | PROFIT ",DoubleToString(progress_percent,3),"%",
               " | STATE ",(g_hold_state==HOLD_STRONG ? "STRONG" :
                (g_hold_state==HOLD_NORMAL ? "NORMAL" :
                 (g_hold_state==HOLD_WARNING ? "WARNING" :
                  (g_hold_state==HOLD_EXIT_CANDIDATE ? "EXIT_CANDIDATE" : "UNKNOWN")))));
      }

      if(InpUseEntryConfidenceProfitManagement &&
         g_entry_confidence!=ENTRY_CONFIDENCE_HIGH)
         ManageRangeProfitGuard(side,average_price,market_price,
                                progress_percent);
      return;
   }

   // Direction weakness is NOT reinterpreted here. The canonical HoldEngine
   // state will drive ExitEngine separately. Risk-only protections continue.
   ManageRangeProfitGuard(side,average_price,market_price,progress_percent);
   if(ManagedPositionSide()==0)
      return;

   if(!g_short_term_break_even_applied &&
      progress_percent>=InpShortTermBreakEvenPercent)
      ApplyShortTermBreakEven(side,average_price);
}


// ===== Functions moved from Common.mqh during ownership audit =====
bool ApplyGroupProtection(const int side,
                          const double average_price,
                          const double old_sl)
{
   double desired_sl = 0.0;
   double desired_tp = 0.0;
   if(g_sl_enabled && g_sl_distance > 0.0)
   {
      desired_sl = NormalizePrice(average_price - side * g_sl_distance);
      const double protected_sl =
         g_protected_sl > 0.0 ? g_protected_sl : old_sl;
      if(protected_sl > 0.0)
         desired_sl = side > 0 ? MathMax(desired_sl, protected_sl)
                               : MathMin(desired_sl, protected_sl);
   }
   if(g_tp_enabled && g_tp_distance > 0.0)
   {
      desired_tp = NormalizePrice(average_price + side * g_tp_distance);
      // Adding exposure must never move the original target farther away.
      if(g_original_tp > 0.0)
         desired_tp = side > 0 ? MathMin(desired_tp, g_original_tp)
                               : MathMax(desired_tp, g_original_tp);
   }

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   // v3.44: use the same broker protection distance as every other SL path.
   // This includes both STOPS_LEVEL and FREEZE_LEVEL via the shared helper.
   const double minimum_distance = ProtectionMinimumDistance();
   if((desired_sl > 0.0 &&
       ((side > 0 && desired_sl >= bid - minimum_distance) ||
        (side < 0 && desired_sl <= ask + minimum_distance))) ||
      (desired_tp > 0.0 &&
       ((side > 0 && desired_tp <= ask + minimum_distance) ||
        (side < 0 && desired_tp >= bid - minimum_distance))))
   {
      g_status = "PROTECTION INVALID - ADD ENTRY BLOCKED";
      return false;
   }

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket) ||
         PositionGetString(POSITION_SYMBOL) != _Symbol ||
         (ulong)PositionGetInteger(POSITION_MAGIC) != InpMagicNumber)
         continue;
      if(!TradeExecutePositionModify(ticket, desired_sl, desired_tp) ||
         !TradeResultSucceeded())
      {
         RegisterOrderFailure("TP/SL APPLY FAILED");
         return false;
      }
   }
   g_protected_sl = desired_sl;
   g_consecutive_order_failures = 0;
   return true;
}

bool ApplyM3ProfitLock(const int side,const double desired_sl)
{
   g_m3_audit_lock_attempted=true;
   g_m3_audit_lock_applied=false;
   g_m3_audit_lock_block_reason="";

   if(side==0 || desired_sl<=0.0 || !g_m3_position_managed)
   {
      g_m3_audit_lock_block_reason="INVALID_INPUT_OR_NOT_M3_MANAGED";
      return false;
   }

   const double bid=SymbolInfoDouble(_Symbol,SYMBOL_BID);
   const double ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK);
   const double minimum=ProtectionMinimumDistance();
   const double tick=MathMax(_Point,SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE));
   const int digits=(int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS);
   double sl=side>0 ? NormalizeDouble(MathFloor(desired_sl/tick)*tick,digits)
                     : NormalizeDouble(MathCeil(desired_sl/tick)*tick,digits);

   if((side>0 && (bid<=0.0 || sl>=bid-minimum)) ||
      (side<0 && (ask<=0.0 || sl<=ask+minimum)))
   {
      g_m3_audit_lock_block_reason="BROKER_MIN_DISTANCE";
      return false;
   }

   if(g_m3_protected_sl>0.0)
   {
      if(side>0 && sl<g_m3_protected_sl) sl=g_m3_protected_sl;
      if(side<0 && sl>g_m3_protected_sl) sl=g_m3_protected_sl;
      if((side>0 && sl>=bid-minimum) || (side<0 && sl<=ask+minimum))
      {
         g_m3_audit_lock_block_reason="MONOTONIC_SL_AT_BROKER_LIMIT";
         return false;
      }
   }

   bool changed=false;
   bool found_side_position=false;
   for(int i=PositionsTotal()-1;i>=0;--i)
   {
      const ulong ticket=PositionGetTicket(i);
      if(ticket==0 || !PositionSelectByTicket(ticket) ||
         PositionGetString(POSITION_SYMBOL)!=_Symbol ||
         (ulong)PositionGetInteger(POSITION_MAGIC)!=InpMagicNumber)
         continue;
      const ENUM_POSITION_TYPE type=(ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const int pside=(type==POSITION_TYPE_BUY ? 1 : -1);
      if(pside!=side) continue;
      found_side_position=true;
      const double current=PositionGetDouble(POSITION_SL);
      const bool improve= current<=0.0 ||
         (side>0 ? sl>current+tick*0.5 : sl<current-tick*0.5);
      if(!improve) continue;
      if(!TradeExecutePositionModify(ticket,sl,PositionGetDouble(POSITION_TP)) ||
         !TradeResultSucceeded())
      {
         g_m3_audit_lock_block_reason="POSITION_MODIFY_FAILED";
         return false;
      }
      changed=true;
   }

   if(changed)
   {
      g_m3_protected_sl=sl;
      g_protected_sl=sl;
      g_sl_distance=MathMax(_Point,MathAbs(g_initial_entry_price-sl));
      g_consecutive_order_failures=0;
      g_m3_audit_lock_applied=true;
      g_m3_audit_lock_update_time=TimeCurrent();
      return true;
   }

   g_m3_audit_lock_block_reason=(found_side_position ? "NO_SL_IMPROVEMENT" : "NO_MANAGED_SIDE_POSITION");
   return false;
}

bool ApplyShortTermBreakEven(const int side,
                             const double average_price)
{
   if(average_price <= 0.0)
      return false;

   const double market_price =
      side > 0 ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
               : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double minimum = ProtectionMinimumDistance();
   const double desired_sl =
      NormalizePrice(average_price +
                     side * average_price *
                     InpShortTermBreakEvenLockPercent / 100.0);
   if((side > 0 && desired_sl >= market_price - minimum) ||
      (side < 0 && desired_sl <= market_price + minimum))
      return false;

   bool modified = false;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket) ||
         PositionGetString(POSITION_SYMBOL) != _Symbol ||
         (ulong)PositionGetInteger(POSITION_MAGIC) != InpMagicNumber)
         continue;
      const double current_sl = PositionGetDouble(POSITION_SL);
      const double current_tp = PositionGetDouble(POSITION_TP);
      const bool improves =
         current_sl == 0.0 ||
         (side > 0 && desired_sl > current_sl) ||
         (side < 0 && desired_sl < current_sl);
      if(!improves)
         continue;
      if(!TradeExecutePositionModify(ticket, desired_sl, current_tp) ||
         !TradeResultSucceeded())
      {
         RegisterOrderFailure("SHORT-TERM BREAK-EVEN FAILED");
         return false;
      }
      modified = true;
   }
   if(modified)
   {
      g_protected_sl = desired_sl;
      g_short_term_break_even_applied = true;
      NotifyPositionState((side > 0 ? "LONG " : "SHORT ") +
         "SHORT-TERM BREAK-EVEN ON");
   }
   return modified;
}

bool ApplyProfitGuardLock(const int side,
                          const double average_price,
                          const double lock_percent)
{
   if(average_price <= 0.0)
      return false;

   const double market_price =
      side > 0 ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
               : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double minimum = ProtectionMinimumDistance();
   const double desired_sl =
      NormalizePrice(average_price +
                     side * average_price *
                     MathMax(0.0, lock_percent) / 100.0);
   if((side > 0 && desired_sl >= market_price - minimum) ||
      (side < 0 && desired_sl <= market_price + minimum))
      return false;

   bool modified = false;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket) ||
         PositionGetString(POSITION_SYMBOL) != _Symbol ||
         (ulong)PositionGetInteger(POSITION_MAGIC) != InpMagicNumber)
         continue;

      const double current_sl = PositionGetDouble(POSITION_SL);
      const double current_tp = PositionGetDouble(POSITION_TP);
      const bool improves =
         current_sl == 0.0 ||
         (side > 0 && desired_sl > current_sl) ||
         (side < 0 && desired_sl < current_sl);
      if(!improves)
         continue;

      if(!TradeExecutePositionModify(ticket, desired_sl, current_tp) ||
         !TradeResultSucceeded())
      {
         RegisterOrderFailure("RANGE PROFIT GUARD SL FAILED");
         return false;
      }
      modified = true;
   }

   if(modified)
   {
      g_protected_sl = desired_sl;
      NotifyPositionState((side > 0 ? "LONG " : "SHORT ") +
         "RANGE PROFIT LOCK ON");
   }
   return modified;
}

double CurrentGroupProgressR(const int side,
                             double &average_price)
{
   average_price = 0.0;
   if(g_initial_r_distance <= 0.0)
      return 0.0;

   int group_side = 0;
   double total_volume = 0.0, group_sl = 0.0, group_tp = 0.0;
   datetime first_time = 0;
   if(!ManagedGroupInfo(group_side, total_volume, average_price,
                        group_sl, group_tp, first_time) ||
      group_side != side || average_price <= 0.0)
      return CurrentProgressR(side);

   const double quote =
      side > 0 ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
               : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   return side > 0 ?
      (quote - average_price) / g_initial_r_distance :
      (average_price - quote) / g_initial_r_distance;
}



// Keep the existing entry/protection thresholds; this only makes the broker
// profit-protection profile.

// Verify the protection that is already stored at the broker before treating
// "cannot improve" as a failure.  Every managed same-side ticket must already
// protect at least the requested R floor.
bool ManagedGroupSLProtectsR(const int side,
                             const double average_price,
                             const double required_r)
{
   if(side==0 || average_price<=0.0 ||
      g_initial_r_distance<=0.0 || required_r<0.0)
      return false;

   const double target_sl=NormalizePrice(
      average_price+side*required_r*g_initial_r_distance);
   const double tolerance=
      MathMax(SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE),_Point)*1.1;

   int same_side_count=0;
   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      const ulong ticket=PositionGetTicket(i);
      if(ticket==0 || !PositionSelectByTicket(ticket) ||
         PositionGetString(POSITION_SYMBOL)!=_Symbol ||
         (ulong)PositionGetInteger(POSITION_MAGIC)!=InpMagicNumber)
         continue;

      const long position_type=PositionGetInteger(POSITION_TYPE);
      const int position_side=(position_type==POSITION_TYPE_BUY ? 1 : -1);
      if(position_side!=side)
         continue;

      same_side_count++;
      const double current_sl=PositionGetDouble(POSITION_SL);
      if(current_sl<=0.0)
         return false;

      const bool protects=side>0 ?
         current_sl+tolerance>=target_sl :
         current_sl-tolerance<=target_sl;
      if(!protects)
         return false;
   }

   return same_side_count>0;
}

bool ApplyManagedProfitLock(const int side,
                            const double average_price,
                            const double lock_r)
{
   bool audit_written=false;
   double effective_lock_r=lock_r;

   g_csv_profit_lock_attempted=true;
   g_csv_profit_lock_requested_r=lock_r;
   g_csv_profit_lock_requested_sl=0.0;
   g_csv_profit_lock_applied=false;
   g_csv_profit_lock_applied_sl=0.0;
   g_csv_profit_lock_retcode=0;
   g_csv_profit_lock_block_reason="";

   if(average_price <= 0.0 || g_initial_r_distance <= 0.0 || lock_r < 0.0)
   {
      g_csv_profit_lock_block_reason="INVALID_LOCK_INPUT";
      WriteProfitLockModifyAudit("BLOCKED",side,lock_r,0.0,0.0,0,
         g_csv_profit_lock_block_reason);
      return false;
   }

   // v3.79: preserve an already-earned INITIAL profit-lock target when broker
   // stop/freeze geometry cannot host the full requested lock.  The best legal
   // broker SL remains the server-side safety net while this runtime floor
   // preserves the stronger target.  Scope is deliberately limited to the
   // remain under their existing dedicated protection paths.
   // v4.70 RANGE simplification: RANGE profit protection is broker-SL only.
   // A virtual floor must never create a separate market-exit authority.
   if((g_position_strategy==STRATEGY_RANGE) &&
      g_initial_virtual_profit_floor_active)
   {
      g_initial_virtual_profit_floor_active=false;
      g_initial_virtual_profit_floor_side=0;
      g_initial_virtual_profit_floor_r=0.0;
      g_initial_virtual_profit_floor_price=0.0;
      g_initial_virtual_profit_floor_time=0;
   }

   if(g_initial_virtual_profit_floor_active)
   {
      const bool virtual_strategy_valid =
         (g_position_strategy==STRATEGY_RANGE &&
          g_entry_type==ENTRY_RANGE);
      const bool virtual_context_valid =
         virtual_strategy_valid &&
         !g_has_add_entry &&
         g_additional_entry_count<=0 &&
         g_initial_virtual_profit_floor_side==side &&
         side!=0 &&
         average_price>0.0 &&
         g_initial_r_distance>0.0;

      if(!virtual_context_valid)
      {
         g_initial_virtual_profit_floor_active=false;
         g_initial_virtual_profit_floor_side=0;
         g_initial_virtual_profit_floor_r=0.0;
         g_initial_virtual_profit_floor_price=0.0;
         g_initial_virtual_profit_floor_time=0;
      }
      else if(ManagedGroupSLProtectsR(
                 side,average_price,g_initial_virtual_profit_floor_r))
      {
         // A real broker SL now owns at least the same protection.
         g_initial_virtual_profit_floor_active=false;
         g_initial_virtual_profit_floor_side=0;
         g_initial_virtual_profit_floor_r=0.0;
         g_initial_virtual_profit_floor_price=0.0;
         g_initial_virtual_profit_floor_time=0;
      }
      else if(g_hold_state!=HOLD_EXIT_CANDIDATE)
      {
         const double virtual_quote = side>0 ?
            SymbolInfoDouble(_Symbol,SYMBOL_BID) :
            SymbolInfoDouble(_Symbol,SYMBOL_ASK);
         const bool virtual_floor_breached = side>0 ?
            virtual_quote<=g_initial_virtual_profit_floor_price :
            virtual_quote>=g_initial_virtual_profit_floor_price;

         // continuation authority while Hold remains NORMAL/STRONG. A Virtual
         // Floor touch alone is not an independent market-exit authority.
         const bool initial_hold_owns_continuation =
            ((g_position_strategy==STRATEGY_RANGE &&
              g_entry_type==ENTRY_RANGE) &&
             !g_has_add_entry &&
             g_additional_entry_count<=0 &&
             (g_hold_state==HOLD_NORMAL || g_hold_state==HOLD_STRONG));

         if(virtual_quote>0.0 && virtual_floor_breached)
         {
            if(initial_hold_owns_continuation)
            {
               g_csv_profit_lock_requested_r=g_initial_virtual_profit_floor_r;
               g_csv_profit_lock_requested_sl=g_initial_virtual_profit_floor_price;
               g_csv_profit_lock_block_reason=
                  "INITIAL_VIRTUAL_FLOOR_HOLD_CONTINUATION";
               g_status=StringFormat(
                  "%s VIRTUAL FLOOR PENDING | HOLD %s | FLOOR %.2fR",
                  "RANGE",
                  g_hold_state==HOLD_STRONG ? "STRONG" : "NORMAL",
                  g_initial_virtual_profit_floor_r);
               return false;
            }

            g_csv_profit_lock_requested_r=g_initial_virtual_profit_floor_r;
            g_csv_profit_lock_requested_sl=g_initial_virtual_profit_floor_price;
            g_csv_profit_lock_block_reason=
               "INITIAL_VIRTUAL_PROFIT_FLOOR_EXIT";
            WriteProfitLockModifyAudit(
               "BLOCKED",side,g_initial_virtual_profit_floor_r,
               g_initial_virtual_profit_floor_price,0.0,0,
               g_csv_profit_lock_block_reason);

            if(g_position_strategy==STRATEGY_RANGE)
            {
               g_csv_profit_lock_block_reason="BROKER_SL_ONLY_NO_VIRTUAL_EXIT";
               return false;
            }

            const bool exit_sent=ExitEngineSubmitManaged(StringFormat(
               "INITIAL VIRTUAL PROFIT FLOOR | %s | HOLD %s | FLOOR %.2fR | PRICE %.*f",
               "RANGE",
               g_hold_state==HOLD_STRONG ? "STRONG" :
               (g_hold_state==HOLD_NORMAL ? "NORMAL" : "WEAKENED"),
               g_initial_virtual_profit_floor_r,_Digits,
               g_initial_virtual_profit_floor_price));
            if(exit_sent)
            {
               g_initial_virtual_profit_floor_active=false;
               g_initial_virtual_profit_floor_side=0;
               g_initial_virtual_profit_floor_r=0.0;
               g_initial_virtual_profit_floor_price=0.0;
               g_initial_virtual_profit_floor_time=0;
            }
            return false;
         }
      }
   }


   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const long stop_level_points=SymbolInfoInteger(_Symbol,SYMBOL_TRADE_STOPS_LEVEL);
   const long freeze_level_points=SymbolInfoInteger(_Symbol,SYMBOL_TRADE_FREEZE_LEVEL);
   const double minimum_distance = MathMax(
      (double)stop_level_points * _Point,
      (double)freeze_level_points * _Point);
   g_csv_profit_lock_bid=bid;
   g_csv_profit_lock_ask=ask;
   g_csv_profit_lock_stop_level_points=stop_level_points;
   g_csv_profit_lock_freeze_level_points=freeze_level_points;
   g_csv_profit_lock_minimum_distance=minimum_distance;
   double desired_sl = NormalizePrice(average_price +
                                      side * lock_r * g_initial_r_distance);
   const double earned_target_sl=desired_sl;
   const double earned_target_r=lock_r;
   g_csv_profit_lock_requested_sl=desired_sl;

   // A broker cannot place a stop inside its minimum stop/freeze distance.
   if(side > 0 && desired_sl >= bid - minimum_distance)
      desired_sl = NormalizePrice(bid - minimum_distance);
   if(side < 0 && desired_sl <= ask + minimum_distance)
      desired_sl = NormalizePrice(ask + minimum_distance);
   g_csv_profit_lock_requested_sl=desired_sl;

   // v3.79 earned-lock preservation.  Only an already-requested lock can
   // create a virtual target; RANGE Stage-1 delay therefore remains untouched
   // because ManageRProfitProtection() never calls this function while
   // apply_broker_lock is false.  Never lower an existing virtual target.
   const double broker_geometry_lock_r =
      side*(desired_sl-average_price)/g_initial_r_distance;
   const bool original_initial_virtual_eligible =
      !g_has_add_entry &&
      g_additional_entry_count<=0 &&
      g_position_strategy==STRATEGY_RANGE &&
      g_entry_type==ENTRY_RANGE;
   const bool full_earned_target_shortfall =
      broker_geometry_lock_r + 1e-9 < earned_target_r;

   if(original_initial_virtual_eligible &&
      g_hold_state!=HOLD_EXIT_CANDIDATE &&
      full_earned_target_shortfall &&
      earned_target_r>=0.0 &&
      !ManagedGroupSLProtectsR(side,average_price,earned_target_r))
   {
      if(!g_initial_virtual_profit_floor_active ||
         g_initial_virtual_profit_floor_side!=side ||
         earned_target_r>g_initial_virtual_profit_floor_r+1e-9)
      {
         g_initial_virtual_profit_floor_active=false;
         g_initial_virtual_profit_floor_side=side;
         g_initial_virtual_profit_floor_r=earned_target_r;
         g_initial_virtual_profit_floor_price=earned_target_sl;
         g_initial_virtual_profit_floor_time=TimeCurrent();
      }
   }

   // v2.29 common fix:
   // lock_r==0.0 is the intentional Stage-1 WARNING breakeven floor.
   // Previously equality with average_price was rejected, so a position that
   // had reached >=0.35R could degrade to WARNING yet still keep its original
   // loss-side SL.  Allow exact BE, but still reject any broker-adjusted stop
   // that falls back into the loss zone.
   bool breakeven_request = MathAbs(effective_lock_r) <= 1e-9;
   bool adjusted_to_loss_zone =
      side > 0
         ? (breakeven_request ? desired_sl < average_price
                              : desired_sl <= average_price)
         : (breakeven_request ? desired_sl > average_price
                              : desired_sl >= average_price);

   if(adjusted_to_loss_zone)
   {
      g_csv_profit_lock_block_reason=
         "BROKER_ADJUSTED_TO_LOSS_ZONE";
      WriteProfitLockModifyAudit(
         "BLOCKED",side,effective_lock_r,
         g_csv_profit_lock_requested_sl,0.0,0,
         g_csv_profit_lock_block_reason);
      return false;
   }

   bool changed = false;
   double current_sl_signature=0.0;
   int managed_sl_count=0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket) ||
         PositionGetString(POSITION_SYMBOL) != _Symbol ||
         (ulong)PositionGetInteger(POSITION_MAGIC) != InpMagicNumber)
         continue;

      g_csv_profit_lock_managed_count++;
      const long position_type=PositionGetInteger(POSITION_TYPE);
      const int position_side=(position_type==POSITION_TYPE_BUY ? 1 : -1);
      if(position_side!=side)
         continue;
      g_csv_profit_lock_same_side_count++;

      const double current_sl = PositionGetDouble(POSITION_SL);
      const double current_tp = PositionGetDouble(POSITION_TP);
      if(managed_sl_count==0)
         current_sl_signature=current_sl;
      else if(side>0)
      {
         if(current_sl<=0.0 || current_sl_signature<=0.0) current_sl_signature=0.0;
         else current_sl_signature=MathMin(current_sl_signature,current_sl);
      }
      else
      {
         if(current_sl<=0.0 || current_sl_signature<=0.0) current_sl_signature=0.0;
         else current_sl_signature=MathMax(current_sl_signature,current_sl);
      }
      managed_sl_count++;

      const bool improves = current_sl <= 0.0 ||
         (side > 0 && desired_sl > current_sl + _Point) ||
         (side < 0 && desired_sl < current_sl - _Point);
      const double improvement_points = current_sl<=0.0 ? 0.0 :
         (side>0 ? (desired_sl-current_sl)/_Point : (current_sl-desired_sl)/_Point);
      g_csv_profit_lock_ticket=ticket;
      g_csv_profit_lock_current_sl_before=current_sl;
      g_csv_profit_lock_improvement_points=improvement_points;
      g_csv_profit_lock_improves=improves;
      if(!improves)
         continue;

      if(!TradeExecutePositionModify(ticket, desired_sl, current_tp) ||
         !TradeResultSucceeded())
      {
         g_csv_profit_lock_retcode=trade.ResultRetcode();
         g_csv_profit_lock_block_reason="POSITION_MODIFY_FAILED";
         Print("R profit-lock update failed: ",
               trade.ResultRetcodeDescription());
         continue;
      }
      g_csv_profit_lock_retcode=trade.ResultRetcode();

      // Re-select the broker position and verify the SL actually stored there.
      double actual_sl_after=0.0;
      bool verify_pass=false;
      if(PositionSelectByTicket(ticket))
      {
         actual_sl_after=PositionGetDouble(POSITION_SL);
         const double tolerance=MathMax(_Point*1.1,SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE)*1.1);
         verify_pass=MathAbs(actual_sl_after-desired_sl)<=tolerance;
      }
      g_csv_profit_lock_actual_sl_after=actual_sl_after;
      g_csv_profit_lock_verify_pass=verify_pass;
      if(!verify_pass)
      {
         g_csv_profit_lock_block_reason="POSITION_MODIFY_SL_MISMATCH";
         continue;
      }
      changed = true;
   }

   if(changed)
   {
      g_csv_profit_lock_applied=true;
      g_csv_profit_lock_applied_sl=desired_sl;
      g_csv_profit_lock_block_reason="APPLIED";
      g_protected_sl = desired_sl;
      if(g_initial_virtual_profit_floor_active &&
         g_initial_virtual_profit_floor_side==side &&
         ManagedGroupSLProtectsR(
            side,average_price,g_initial_virtual_profit_floor_r))
      {
         g_initial_virtual_profit_floor_active=false;
         g_initial_virtual_profit_floor_side=0;
         g_initial_virtual_profit_floor_r=0.0;
         g_initial_virtual_profit_floor_price=0.0;
         g_initial_virtual_profit_floor_time=0;
      }
      if(g_initial_virtual_profit_floor_active &&
         g_initial_virtual_profit_floor_side==side)
         g_status=StringFormat(
            "PROFIT LOCK BROKER %.*f + VIRTUAL %.2fR | PEAK %.2fR",
            _Digits,desired_sl,g_initial_virtual_profit_floor_r,
            g_highest_profit_r);
      else
         g_status = StringFormat("PROFIT LOCK %.2fR | PEAK %.2fR",
                                 effective_lock_r, g_highest_profit_r);
   }
   if(!changed && g_csv_profit_lock_block_reason=="")
   {
      if(g_csv_profit_lock_managed_count<=0)
         g_csv_profit_lock_block_reason="NO_MANAGED_POSITION";
      else if(g_csv_profit_lock_same_side_count<=0)
         g_csv_profit_lock_block_reason="SIDE_MISMATCH";
      else if(!g_csv_profit_lock_improves)
      {
         if(ManagedGroupSLProtectsR(side,average_price,effective_lock_r))
            g_csv_profit_lock_block_reason="ALREADY_PROTECTED";
         else
            g_csv_profit_lock_block_reason=
               MathAbs(g_csv_profit_lock_improvement_points)<=1.0
                  ? "SL_IMPROVEMENT_TOO_SMALL" : "ALREADY_PROTECTED";
      }
      else
         g_csv_profit_lock_block_reason="NO_APPLIED_SL_CHANGE";
   }

   bool suppress_duplicate_no_improve=false;
   const bool repetitive_no_change =
      !changed &&
      (g_csv_profit_lock_block_reason=="NO_APPLIED_SL_CHANGE" ||
       g_csv_profit_lock_block_reason=="SL_IMPROVEMENT_TOO_SMALL" ||
       g_csv_profit_lock_block_reason=="ALREADY_PROTECTED");
   if(repetitive_no_change)
   {
      const ulong context_position_id=g_trade_cycle.position_id;
      const double sl_signature=
         managed_sl_count>0 ? current_sl_signature : 0.0;
      suppress_duplicate_no_improve=
         context_position_id==g_profit_lock_no_improve_position_id &&
         MathAbs(g_csv_profit_lock_requested_sl-
                 g_profit_lock_no_improve_requested_sl)<=_Point*0.1 &&
         MathAbs(effective_lock_r-g_profit_lock_no_improve_lock_r)<=1e-9 &&
         MathAbs(sl_signature-
                 g_profit_lock_no_improve_sl_signature)<=_Point*0.1;

      if(!suppress_duplicate_no_improve)
      {
         g_profit_lock_no_improve_position_id=context_position_id;
         g_profit_lock_no_improve_requested_sl=g_csv_profit_lock_requested_sl;
         g_profit_lock_no_improve_lock_r=effective_lock_r;
         g_profit_lock_no_improve_sl_signature=sl_signature;
      }
   }
   else
   {
      // Any applied/failed/different state makes the next identical
      // no-change status meaningful again.
      g_profit_lock_no_improve_position_id=0;
      g_profit_lock_no_improve_requested_sl=0.0;
      g_profit_lock_no_improve_lock_r=0.0;
      g_profit_lock_no_improve_sl_signature=0.0;
   }

   if(!audit_written && !g_csv_profit_lock_applied &&
      !suppress_duplicate_no_improve)
      WriteProfitLockModifyAudit("BLOCKED",side,effective_lock_r,
         g_csv_profit_lock_requested_sl,0.0,g_csv_profit_lock_retcode,
         g_csv_profit_lock_block_reason);
   return changed;
}


//+------------------------------------------------------------------+
//+------------------------------------------------------------------+



#endif // __JOON_RISKENGINE_MQH__


