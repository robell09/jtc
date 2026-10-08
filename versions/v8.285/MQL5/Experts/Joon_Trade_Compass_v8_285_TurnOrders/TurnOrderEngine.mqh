#ifndef JTC_TURN_ORDER_ENGINE_MQH
#define JTC_TURN_ORDER_ENGINE_MQH
// Exclusive TURN PRE order router. No history replay, WATCH/ACCEL or ADD orders.
datetime g_turn_order_consumed_bar=0;
datetime g_turn_order_pending_bar=0;
int g_turn_order_pending_side=0;
bool g_turn_order_flat_confirmed=false;
string g_turn_order_pending_event="";
ulong g_turn_order_exit_ids[];
bool g_turn_order_exit_seen[];

void JTC_TurnOrderCancelPending()
{
   g_turn_order_pending_bar=0; g_turn_order_pending_side=0;
   g_turn_order_flat_confirmed=false; g_turn_order_pending_event="";
   ArrayResize(g_turn_order_exit_ids,0); ArrayResize(g_turn_order_exit_seen,0);
}
void JTC_TurnOrderReset()
{
   g_turn_order_consumed_bar=0;
   JTC_TurnOrderCancelPending();
}
void JTC_TurnOrderSource(const int side,const datetime bar,const string event_id)
{
   g_csv_order_signal_source="TURN_PRE";
   g_csv_order_signal_side=side; g_csv_order_signal_time=bar;
   if(side>0)
   {
      g_current_long_signal_event_id=event_id;
      g_range_long_signal_count=3; g_last_long_score=3;
   }
   else
   {
      g_current_short_signal_event_id=event_id;
      g_range_short_signal_count=3; g_last_short_score=3;
   }
}
void JTC_TurnOrderAudit(const int side,const string event_id,const string action,
                        const string result,const string reason)
{
   g_status="TURN PRE "+action+" | "+result+" | "+reason;
   Print(g_status);
   WriteUnifiedOrderSignalAudit("TURN_ORDER",event_id,action,side,3,3,
      result,reason,false,false,0,0);
}
// Called only AFTER the existing exit-deal lifecycle has completed/reset.
// All captured position identifiers must report a final close before reversing.
void JTC_TurnOrderOnExitDeal(const ulong position_id)
{
   if(g_turn_order_pending_side==0 || position_id==0) return;
   for(int i=0;i<ArraySize(g_turn_order_exit_ids);++i)
      if(g_turn_order_exit_ids[i]==position_id && !DataExportPositionIdentifierOpen(position_id))
         g_turn_order_exit_seen[i]=true;
   if(ArraySize(g_turn_order_exit_ids)==0 || ManagedPositionSide()!=0) return;
   for(int i=0;i<ArraySize(g_turn_order_exit_seen);++i)
      if(!g_turn_order_exit_seen[i]) return;
   g_turn_order_flat_confirmed=true;
}
bool JTC_TurnOrderEntry(const int side,const datetime bar,const string event_id)
{
   if(!AutoDirectionAllows(side))
   {JTC_TurnOrderAudit(side,event_id,"INITIAL","BLOCKED","AUTO_DIRECTION");return false;}
   const double quote=SymbolInfoDouble(_Symbol,side>0 ? SYMBOL_ASK : SYMBOL_BID);
   const double atr=g_assist_state.turn_pre_atr14;
   const double distance=side*(quote-g_assist_state.turn_pre_pivot_price);
   if(quote<=0.0 || !MathIsValidNumber(quote) || !MathIsValidNumber(atr) ||
      !MathIsValidNumber(g_assist_state.turn_pre_pivot_price) || atr<=0.0 ||
      distance<atr*InpTurnMinReboundATR || distance>atr*InpTurnMaxDistanceATR)
   {JTC_TurnOrderAudit(side,event_id,"INITIAL","BLOCKED","LIVE_PRICE_OUTSIDE_TURN_ATR_RANGE");return false;}
   // Never start a new cycle while the old close callback or an entry sync is pending.
   if(g_exit_order_in_progress || g_entry_order_in_progress || ManagedPositionSide()!=0 ||
      g_trade_cycle.state==JTA_CYCLE_EXIT_PENDING || g_trade_cycle.state==JTA_CYCLE_ENTRY_PENDING ||
      g_trade_cycle.state==JTA_CYCLE_POSITION_OPEN)
   {JTC_TurnOrderAudit(side,event_id,"INITIAL","BLOCKED","POSITION_OR_LIFECYCLE_PENDING");return false;}
   JTC_TurnOrderSource(side,bar,event_id);
   TradeCycleEnsure(side,event_id);
   const bool old_context=g_m3_auto_execution_context_active;
   g_m3_auto_execution_context_active=true;
   // TURN-specific classification: retain percentage SL, never stale M3 structural SL.
   const string reason=StringFormat("TURN PRE INITIAL %s | SIGNAL=%s | BAR=%s",
      side>0 ? "LONG" : "SHORT",event_id,TimeToString(bar,TIME_DATE|TIME_SECONDS));
   const bool ok=EntryEngineSubmitInitial(side,3,reason,quote,false);
   g_m3_auto_execution_context_active=old_context;
   if(!ok && ManagedPositionSide()==0 && g_trade_cycle.state!=JTA_CYCLE_ENTRY_PENDING &&
      g_trade_cycle.state!=JTA_CYCLE_POSITION_OPEN)
      TradeCycleClear("TURN_INITIAL_NOT_SUBMITTED");
   JTC_TurnOrderAudit(side,event_id,"INITIAL",ok ? "SUBMITTED" : "FAILED_OR_BLOCKED",reason);
   return ok;
}
void JTC_TurnOrderProcessTick()
{
   if(!InpTurnTradeEnabled) return;
   g_m3_auto_order_authority_active=false;
   const datetime latest=iTime(_Symbol,PERIOD_M3,1);
   const bool enabled=InpSystemEnabled && g_auto_trading && InpTurnPreEnabled;
   if(g_turn_order_pending_side!=0)
   {
      if(!enabled || latest!=g_turn_order_pending_bar)
      {
         JTC_TurnOrderAudit(g_turn_order_pending_side,g_turn_order_pending_event,
            "REVERSE","CANCELLED",!enabled ? "SYSTEM_OR_AUTO_OFF" : "SIGNAL_EXPIRED");
         JTC_TurnOrderCancelPending();
      }
      else if(g_turn_order_flat_confirmed && ManagedPositionSide()==0)
      {
         const int side=g_turn_order_pending_side;
         const datetime bar=g_turn_order_pending_bar;
         const string event_id=g_turn_order_pending_event;
         JTC_TurnOrderCancelPending(); // exactly one attempt on a later tick
         JTC_TurnOrderEntry(side,bar,event_id);
      }
   }
   if(!g_assist_state.turn_pre_data_valid || !g_assist_state.turn_pre_signal) return;
   const datetime bar=g_assist_state.turn_pre_confirm_bar;
   const int side=g_assist_state.turn_pre_side;
   if(bar<=0 || bar<=g_turn_order_consumed_bar || (side!=1 && side!=-1)) return;
   // Consume while OFF as well: switching AUTO ON mid-bar must not resurrect an old signal.
   g_turn_order_consumed_bar=bar;
   const string event_id="TURN-"+IntegerToString((long)bar)+(side>0 ? "-L" : "-S");
   if(!enabled || bar!=latest || TimeCurrent()<g_assist_state.turn_pre_available_time)
   {JTC_TurnOrderAudit(side,event_id,"SIGNAL","IGNORED",!enabled ? "SYSTEM_OR_AUTO_OFF" : "STALE_OR_NOT_CLOSED");return;}
   const int held=ManagedPositionSide();
   if(held==side)
   {JTC_TurnOrderAudit(side,event_id,"HOLD","NO_ADD","SAME_SIDE_SIGNAL");return;}
   if(held==0)
   {JTC_TurnOrderEntry(side,bar,event_id);return;}
   string permission="";
   if(!JTATradePermissionAllowed(permission))
   {JTC_TurnOrderAudit(side,event_id,"EXIT","BLOCKED",permission);return;}
   JTC_TurnOrderSource(side,bar,event_id);
   JTC_TurnOrderCancelPending();
   g_turn_order_pending_side=side; g_turn_order_pending_bar=bar;
   g_turn_order_pending_event=event_id;
   // Capture all EA-owned tickets, including any old ADD layers restored on attachment.
   for(int i=PositionsTotal()-1;i>=0;--i)
   {
      const ulong ticket=PositionGetTicket(i);
      if(ticket==0 || !PositionSelectByTicket(ticket) ||
         PositionGetString(POSITION_SYMBOL)!=_Symbol ||
         (ulong)PositionGetInteger(POSITION_MAGIC)!=InpMagicNumber) continue;
      const int n=ArraySize(g_turn_order_exit_ids);
      ArrayResize(g_turn_order_exit_ids,n+1); ArrayResize(g_turn_order_exit_seen,n+1);
      g_turn_order_exit_ids[n]=(ulong)PositionGetInteger(POSITION_IDENTIFIER);
      g_turn_order_exit_seen[n]=false;
   }
   g_exit_source_event_id=event_id;
   const bool ok=CloseManagedPosition("TURN PRE OPPOSITE EXIT | SIGNAL="+event_id);
   if(!ok || !InpTurnReverseOnOpposite)
      JTC_TurnOrderCancelPending();
   JTC_TurnOrderAudit(side,event_id,"EXIT",ok ? "SUBMITTED" : "FAILED",
      ok && InpTurnReverseOnOpposite ? "WAIT_FOR_ALL_EXIT_DEALS_THEN_REVERSE" : "NO_REVERSE");
}
#endif
