//+------------------------------------------------------------------+
//| M3AutoEngine.mqh                                                 |
//| M3 AUTO orchestration: state -> entry -> position execution      |
//+------------------------------------------------------------------+
#ifndef __JOON_M3_AUTO_ENGINE_MQH__
#define __JOON_M3_AUTO_ENGINE_MQH__

// M3SegmentEngine owns M3 data interpretation, segment lifecycle and
// structural state. This file owns AUTO orchestration and order handoff.
#include "M3SegmentEngine.mqh"

// AUTO activation belongs to the AUTO controller, not the segment state engine.
bool M3AutoEngineIsActive()
{
   return InpUseShortTermPriceActionEngine;
}

// Re-evaluate early directional formation using the previous completed-bar
// fields available in JTC_M3_STATE.  Kept separate from M3SegmentEngine so
// the segment remains the market-state owner while M3AutoEngine owns the
// order decision.
// Canonical StateEvaluation WATCH is the normal direct INITIAL authority.
// v8.249 exception: a REARM WATCH still owns EXIT, but its next-cycle INITIAL
// is confirmed by the first later same-direction owned STRUCTURAL ACCEL.
bool M3AutoSubmitSignalInitial(const JTC_M3_STATE &s,const int side,const string signal_name)
{
   // Do not apply the legacy post-exit cooldown here: canonical WATCH/confirmed
   // REARM-ACCEL order ownership must not be suppressed by an older path.
   // The explicit user-selected AUTO direction remains authoritative.
   if(side==0 || !g_auto_trading || ManagedPositionSide()!=0 ||
      !AutoDirectionAllows(side))
      return false;
   if(g_m3_last_entry_attempt_bar==s.bar_time)
      return false;

   const double price=side>0 ? SymbolInfoDouble(_Symbol,SYMBOL_ASK) :
                              SymbolInfoDouble(_Symbol,SYMBOL_BID);
   if(price<=0.0)
      return false;

   g_m3_last_entry_attempt_bar=s.bar_time;
   // v8.242: CSV-only execution source latch.
   g_csv_order_signal_source=(StringFind(signal_name,"ACCEL")>=0 ? "ACCEL" : "WATCH");
   g_csv_order_signal_side=side;
   g_csv_order_signal_time=s.bar_time;

   // v8.147: M3 AUTO owns a real trade cycle from INITIAL handoff through the
   // final close.  The legacy 3X path used to create this object before entry,
   // but the direct WATCH -> INITIAL path bypasses that lifecycle.  Ensure it
   // here so INITIAL / ADD / Peak80 / EXIT rows share one cycle_id.
   const string m3_source_event_id = side>0 ? g_current_long_signal_event_id :
                                               g_current_short_signal_event_id;
   TradeCycleEnsure(side,m3_source_event_id);

   g_m3_auto_execution_context_active=true;
   const string reason=StringFormat("M3 AUTO INITIAL %s | SIGNAL=%s | BAR=%s",
      side>0?"LONG":"SHORT",signal_name,
      TimeToString(s.bar_time,TIME_DATE|TIME_MINUTES));
   const bool submitted=EntryEngineSubmitInitial(side,0,reason,price,false);
   g_m3_auto_execution_context_active=false;
   if(!submitted && ManagedPositionSide()==0)
   {
      TradeCycleClear("M3_INITIAL_NOT_SUBMITTED");
      g_csv_order_signal_source="";
      g_csv_order_signal_side=0;
      g_csv_order_signal_time=0;
   }
   if(submitted)
   {
      g_m3_state=(side>0 ? JTC_M3_READY_LONG : JTC_M3_READY_SHORT);
      g_m3_runtime_mode=M3_RUNTIME_AUTOTRADING;
   }
   return submitted;
}

// Same-direction M3 ACCEL is the direct ADD authority. The existing
// EntryEngine ADD gateway remains the execution/safety owner.
bool M3AutoSubmitSignalAdd(const JTC_M3_STATE &s,const int side,const string signal_name)
{
   if(side==0 || !g_auto_trading || ManagedPositionSide()!=side)
      return false;
   if(g_max_additional_entries<=0 ||
      g_additional_entry_filled_count>=g_max_additional_entries)
      return false;
   if(g_m3_last_add_attempt_bar==s.bar_time)
      return false;
   // Same-direction M3 ACCEL is the canonical ADD authority. Do not let the
   // legacy post-exit cooldown suppress an otherwise valid M3 ADD signal.
   if(!AutoDirectionAllows(side))
      return false;

   const int stage=g_additional_entry_filled_count+1;
   g_m3_last_add_attempt_bar=s.bar_time;
   g_csv_order_signal_source=(StringFind(signal_name,"DIRECTION")>=0 ? "DIRECTION" :
                              StringFind(signal_name,"ACCEL")>=0 ? "ACCEL" : signal_name);
   g_csv_order_signal_side=side;
   g_csv_order_signal_time=s.bar_time;
   const string reason=StringFormat("M3 AUTO ADD%d %s | SIGNAL=%s | BAR=%s",
      stage,side>0?"LONG":"SHORT",signal_name,
      TimeToString(s.bar_time,TIME_DATE|TIME_MINUTES));
   g_m3_auto_execution_context_active=true;
   const bool submitted=EntryEngineSubmitAdditional(side,stage,reason);
   g_m3_auto_execution_context_active=false;
   if(!submitted)
   {
      g_csv_order_signal_source="";
      g_csv_order_signal_side=0;
      g_csv_order_signal_time=0;
   }
   return submitted;
}

// Canonical signal -> AUTO mapping:
//   normal StateEvaluation WATCH -> INITIAL when flat / opposite EXIT+reverse
//   REARM StateEvaluation WATCH  -> opposite EXIT; next INITIAL waits ACCEL
//   same-direction STRUCTURAL ACCEL -> ADD when already positioned
//   DIRECTION -> ADD only (consumed later)
// v8.261: copy the current canonical WATCH into the PRE-REARM execution
// owner only when AUTO actually consumes that WATCH as an execution lifecycle
// transition. Informational NONE_SAME_SIDE_WATCH events never call this helper.
void M3AutoPromotePrezeroReentryOwner(const JTC_M3_STATE &s,const int side)
{
   if(side==M3_SEG_NONE || s.bar_time<=0)
      return;
   const int signed_side=(side==M3_SEG_LONG ? 1 : -1);
   g_assist_weak_watch_owner_side=signed_side;
   g_assist_weak_watch_owner_time=s.bar_time;
   g_assist_weak_watch_owner_high=g_assist_state.high_price;
   g_assist_weak_watch_owner_low=g_assist_state.low_price;
   g_assist_long_weak_armed=(signed_side>0);
   g_assist_short_weak_armed=(signed_side<0);
   g_assist_accel_owner_side=signed_side;
   g_assist_accel_owner_watch_time=s.bar_time;
   g_assist_accel_owner_confirmed=false;
   g_pre_rearm_execution_owner_side=signed_side;
   g_pre_rearm_execution_owner_time=s.bar_time;
   g_pre_rearm_execution_owner_high=g_assist_state.high_price;
   g_pre_rearm_execution_owner_low=g_assist_state.low_price;
}

void M3AutoAdoptPreRearmExecutionOwner(const int side,const datetime watch_time)
{
   if(side==M3_SEG_NONE || watch_time<=0)
      return;
   const int signed_side=(side==M3_SEG_LONG ? 1 : -1);
   if(g_assist_weak_watch_owner_side!=signed_side ||
      g_assist_weak_watch_owner_time!=watch_time)
      return;
   g_pre_rearm_execution_owner_side=signed_side;
   g_pre_rearm_execution_owner_time=watch_time;
   g_pre_rearm_execution_owner_high=g_assist_weak_watch_owner_high;
   g_pre_rearm_execution_owner_low=g_assist_weak_watch_owner_low;
}

bool M3AutoProcessSignalEvents(const JTC_M3_STATE &s,
                               const bool watch_long,
                               const bool watch_short,
                               const bool accel_long,
                               const bool accel_short,
                               const bool prezero_reentry=false)
{
   if(!g_auto_trading)
      return false;

   // v8.162 canonical order ownership:
   // StateEvaluation WATCH -> INITIAL / opposite EXIT+reverse.
   // M3 display ACCEL      -> ADD1..ADDN up to the operator-configured MAX ADD count.
   // StateEvaluation remains the sole WATCH order authority.
   if(watch_long && !watch_short && g_m3_auto_signal_leg_side!=M3_SEG_LONG)
   {
      g_m3_auto_signal_leg_side=M3_SEG_LONG;
      g_internal_momentum_watch_owner_side=1;
      g_m3_auto_signal_leg_start_time=s.bar_time;
      g_m3_auto_signal_leg_watch_sequence=0;
   }
   else if(watch_short && !watch_long && g_m3_auto_signal_leg_side!=M3_SEG_SHORT)
   {
      g_m3_auto_signal_leg_side=M3_SEG_SHORT;
      g_internal_momentum_watch_owner_side=-1;
      g_m3_auto_signal_leg_start_time=s.bar_time;
      g_m3_auto_signal_leg_watch_sequence=0;
   }

   const bool owned_accel_long=(accel_long &&
      g_m3_auto_signal_leg_side==M3_SEG_LONG &&
      g_m3_auto_signal_leg_start_time>0 &&
      s.bar_time>g_m3_auto_signal_leg_start_time);
   const bool owned_accel_short=(accel_short &&
      g_m3_auto_signal_leg_side==M3_SEG_SHORT &&
      g_m3_auto_signal_leg_start_time>0 &&
      s.bar_time>g_m3_auto_signal_leg_start_time);

   const int position_side=ManagedPositionSide();
   const int current_watch_side=(watch_long && !watch_short ? M3_SEG_LONG :
                                 (watch_short && !watch_long ? M3_SEG_SHORT : M3_SEG_NONE));
   const bool current_watch_rearm=(current_watch_side!=M3_SEG_NONE &&
                                   g_assist_state.bar_time==s.bar_time &&
                                   g_assist_state.watch_pulse &&
                                   g_assist_state.watch_rearm_pulse);

   // v8.279: an actual opposite canonical WATCH invalidates any old PREZERO
   // same-side re-entry permission before it can be consumed.
   if(g_prezero_reentry_armed && current_watch_side!=M3_SEG_NONE &&
      current_watch_side!=(g_prezero_reentry_side>0 ? M3_SEG_LONG : M3_SEG_SHORT))
   {
      g_prezero_reentry_armed=false;
      g_prezero_reentry_side=0;
      g_prezero_reentry_exit_time=0;
   }

   // v8.252 REARM pre-zero recovery is risk EXIT-only. It is consumed only
   // from the exact StateEvaluation snapshot for this completed bar, only
   // while the opposite managed position is live, and never creates
   // pending_reverse or any entry authority. Canonical WATCH remains owner of
   // the later REARM -> ACCEL -> INITIAL lifecycle.
   const bool pre_rearm_exit_long=(
      g_assist_state.bar_time==s.bar_time &&
      g_assist_state.pre_rearm_exit_long);
   const bool pre_rearm_exit_short=(
      g_assist_state.bar_time==s.bar_time &&
      g_assist_state.pre_rearm_exit_short);

   // Once submitted, the EXIT-only obligation owns execution until broker
   // flat, canonical ownership change, or an already-established recovery-side
   // position proves the obligation obsolete. This blocks old-leg ACCEL/
   // DIRECTION ADD from racing an asynchronous EXIT on later M3 bars.
   if(g_m3_pre_rearm_exit_obligation)
   {
      const int owner_side=(g_pre_rearm_execution_owner_side>0 ? M3_SEG_LONG :
                            (g_pre_rearm_execution_owner_side<0 ? M3_SEG_SHORT : M3_SEG_NONE));
      const int est_side=(g_assist_state.established_side>0 ? M3_SEG_LONG :
                          (g_assist_state.established_side<0 ? M3_SEG_SHORT : M3_SEG_NONE));
      const bool lifecycle_valid=(
         owner_side==g_m3_pre_rearm_exit_owner_side &&
         g_pre_rearm_execution_owner_time==g_m3_pre_rearm_exit_owner_time &&
         est_side==g_m3_pre_rearm_exit_recovery_side &&
         owner_side==-g_m3_pre_rearm_exit_recovery_side);

      if(!lifecycle_valid || position_side==0 ||
         position_side==g_m3_pre_rearm_exit_recovery_side)
      {
         g_m3_pre_rearm_exit_obligation=false;
         g_m3_pre_rearm_exit_recovery_side=M3_SEG_NONE;
         g_m3_pre_rearm_exit_owner_side=M3_SEG_NONE;
         g_m3_pre_rearm_exit_owner_time=0;
      }
      else if(position_side==g_m3_pre_rearm_exit_owner_side)
      {
         if(!g_exit_order_in_progress)
            ExitEngineSubmitManaged(
               g_m3_pre_rearm_exit_recovery_side>0 ?
                  "M3 AUTO EXIT RETRY: PREZERO REARM RECOVERY LONG" :
                  "M3 AUTO EXIT RETRY: PREZERO REARM RECOVERY SHORT");
         return false;
      }
   }

   if(position_side<0 && pre_rearm_exit_long &&
      current_watch_side==M3_SEG_NONE)
   {
      g_m3_pre_rearm_exit_obligation=true;
      g_m3_pre_rearm_exit_recovery_side=M3_SEG_LONG;
      g_m3_pre_rearm_exit_owner_side=M3_SEG_SHORT;
      g_m3_pre_rearm_exit_owner_time=g_pre_rearm_execution_owner_time;
      return ExitEngineSubmitManaged(
         "M3 AUTO EXIT: PREZERO REARM RECOVERY LONG");
   }
   if(position_side>0 && pre_rearm_exit_short &&
      current_watch_side==M3_SEG_NONE)
   {
      g_m3_pre_rearm_exit_obligation=true;
      g_m3_pre_rearm_exit_recovery_side=M3_SEG_SHORT;
      g_m3_pre_rearm_exit_owner_side=M3_SEG_LONG;
      g_m3_pre_rearm_exit_owner_time=g_pre_rearm_execution_owner_time;
      return ExitEngineSubmitManaged(
         "M3 AUTO EXIT: PREZERO REARM RECOVERY SHORT");
   }

   // v8.249 lifecycle arbitration. A newly published opposite WATCH replaces
   // any older pending reversal intent. This prevents a stale REARM wait from
   // surviving after canonical WATCH ownership has flipped again.
   if(current_watch_side!=M3_SEG_NONE &&
      g_m3_pending_reverse_side!=M3_SEG_NONE &&
      current_watch_side!=g_m3_pending_reverse_side)
   {
      g_m3_pending_reverse_side=M3_SEG_NONE;
      g_m3_pending_reverse_watch_time=0;
      g_m3_pending_reverse_requires_accel=false;
      g_m3_pending_reverse_accel_confirmed=false;
      g_m3_pending_reverse_accel_time=0;
      g_m3_pending_reverse_exit_obligation=false;
   }

   // A REARM cycle can confirm its next INITIAL with the first later owned
   // STRUCTURAL ACCEL. Capture that evidence even if an asynchronous EXIT has
   // not yet reported flat on this exact completed bar.
   if(g_m3_pending_reverse_requires_accel &&
      g_m3_pending_reverse_side!=M3_SEG_NONE)
   {
      const bool pending_accel_confirmed=
         (g_m3_pending_reverse_side==M3_SEG_LONG && owned_accel_long) ||
         (g_m3_pending_reverse_side==M3_SEG_SHORT && owned_accel_short);
      if(pending_accel_confirmed)
      {
         g_m3_pending_reverse_accel_confirmed=true;
         g_m3_pending_reverse_accel_time=s.bar_time;
      }
   }

   // Complete a normal WATCH reversal immediately after flat confirmation.
   // REARM WATCH is different: EXIT happens at WATCH, but the next-cycle
   // INITIAL remains pending until a later same-direction STRUCTURAL ACCEL.
   if(position_side==0 && g_m3_pending_reverse_side!=M3_SEG_NONE)
   {
      // Live broker flat state confirms that any prior reverse EXIT obligation
      // is complete. Never carry a close obligation into the next INITIAL.
      g_m3_pending_reverse_exit_obligation=false;
      if(!g_m3_pending_reverse_requires_accel ||
         g_m3_pending_reverse_accel_confirmed)
      {
         const int reverse_side=g_m3_pending_reverse_side;
         const bool accel_confirmed=g_m3_pending_reverse_requires_accel;
         g_m3_pending_reverse_side=M3_SEG_NONE;
         g_m3_pending_reverse_watch_time=0;
         g_m3_pending_reverse_requires_accel=false;
         g_m3_pending_reverse_accel_confirmed=false;
         g_m3_pending_reverse_accel_time=0;
         g_m3_pending_reverse_exit_obligation=false;
         return M3AutoSubmitSignalInitial(
            s,reverse_side,
            accel_confirmed ?
               (reverse_side>0 ? "REARM ACCEL LONG INITIAL" : "REARM ACCEL SHORT INITIAL") :
               (reverse_side>0 ? "STATE WATCH LONG REVERSAL" : "STATE WATCH SHORT REVERSAL"));
      }
      // Still flat and waiting for the first same-direction ACCEL. A later
      // opposite WATCH will cancel this intent in the arbitration above.
      if(current_watch_side==M3_SEG_NONE)
         return false;
   }

   if(position_side>0 && watch_short)
   {
      M3AutoAdoptPreRearmExecutionOwner(M3_SEG_SHORT,s.bar_time);
      g_m3_pending_reverse_side=M3_SEG_SHORT;
      g_m3_pending_reverse_watch_time=s.bar_time;
      g_m3_pending_reverse_requires_accel=current_watch_rearm;
      g_m3_pending_reverse_accel_confirmed=false;
      g_m3_pending_reverse_accel_time=0;
      g_m3_pending_reverse_exit_obligation=true;
      return ExitEngineSubmitManaged(current_watch_rearm ?
         "M3 AUTO EXIT: REARM STATE WATCH SHORT" :
         "M3 AUTO EXIT: OPPOSITE STATE WATCH SHORT");
   }
   if(position_side<0 && watch_long)
   {
      M3AutoAdoptPreRearmExecutionOwner(M3_SEG_LONG,s.bar_time);
      g_m3_pending_reverse_side=M3_SEG_LONG;
      g_m3_pending_reverse_watch_time=s.bar_time;
      g_m3_pending_reverse_requires_accel=current_watch_rearm;
      g_m3_pending_reverse_accel_confirmed=false;
      g_m3_pending_reverse_accel_time=0;
      g_m3_pending_reverse_exit_obligation=true;
      return ExitEngineSubmitManaged(current_watch_rearm ?
         "M3 AUTO EXIT: REARM STATE WATCH LONG" :
         "M3 AUTO EXIT: OPPOSITE STATE WATCH LONG");
   }

   if(position_side==0)
   {
      if(watch_long && !watch_short)
      {
         M3AutoAdoptPreRearmExecutionOwner(M3_SEG_LONG,s.bar_time);
         if(current_watch_rearm)
         {
            g_m3_pending_reverse_side=M3_SEG_LONG;
            g_m3_pending_reverse_watch_time=s.bar_time;
            g_m3_pending_reverse_requires_accel=true;
            g_m3_pending_reverse_accel_confirmed=false;
            g_m3_pending_reverse_accel_time=0;
            g_m3_pending_reverse_exit_obligation=false;
            return false;
         }
         const bool submitted=M3AutoSubmitSignalInitial(s,1,
            prezero_reentry ? "PREZERO CONFIRMED REENTRY LONG" : "STATE WATCH LONG");
         if(submitted && prezero_reentry)
         {
            M3AutoPromotePrezeroReentryOwner(s,M3_SEG_LONG);
            g_prezero_reentry_armed=false;
            g_prezero_reentry_side=0;
            g_prezero_reentry_exit_time=0;
            g_assist_state.watch_informational_repeat=false;
         }
         return submitted;
      }
      if(watch_short && !watch_long)
      {
         M3AutoAdoptPreRearmExecutionOwner(M3_SEG_SHORT,s.bar_time);
         if(current_watch_rearm)
         {
            g_m3_pending_reverse_side=M3_SEG_SHORT;
            g_m3_pending_reverse_watch_time=s.bar_time;
            g_m3_pending_reverse_requires_accel=true;
            g_m3_pending_reverse_accel_confirmed=false;
            g_m3_pending_reverse_accel_time=0;
            g_m3_pending_reverse_exit_obligation=false;
            return false;
         }
         const bool submitted=M3AutoSubmitSignalInitial(s,-1,
            prezero_reentry ? "PREZERO CONFIRMED REENTRY SHORT" : "STATE WATCH SHORT");
         if(submitted && prezero_reentry)
         {
            M3AutoPromotePrezeroReentryOwner(s,M3_SEG_SHORT);
            g_prezero_reentry_armed=false;
            g_prezero_reentry_side=0;
            g_prezero_reentry_exit_time=0;
            g_assist_state.watch_informational_repeat=false;
         }
         return submitted;
      }
      return false;
   }

   // v8.211 explicit same-bar arbitration: WATCH has absolute AUTO priority.
   // Even a same-direction WATCH suppresses ACCEL/DIRECTION ADD authority on
   // this completed bar.  The WATCH event itself remains the signal-leg owner.
   if(watch_long || watch_short)
      return false;

   if(position_side>0 && owned_accel_long)
      return M3AutoSubmitSignalAdd(s,1,"M3 ACCEL LONG");
   if(position_side<0 && owned_accel_short)
      return M3AutoSubmitSignalAdd(s,-1,"M3 ACCEL SHORT");

   return false;
}


// v8.217: consume the simple DIRECTION event after SignalEngine
// has evaluated the same completed bar. It is an ADD candidate only. The
// existing M3 ADD gateway remains the execution/safety owner. If ACCEL already
// attempted an ADD on this bar, g_m3_last_add_attempt_bar deduplicates it.
bool M3AutoConsumeInternalMomentumEvent()
{
   if(!g_auto_trading || !M3AutoEngineIsActive())
      return false;
   if(g_internal_momentum_event_time<=0 || g_internal_momentum_event_side==0 ||
      g_internal_momentum_event_time==g_internal_momentum_last_consumed_time)
      return false;

   JTC_M3_STATE s;
   if(!M3AutoReadState(s) || s.bar_time!=g_internal_momentum_event_time)
      return false;

   const int side=g_internal_momentum_event_side;
   g_internal_momentum_last_consumed_time=g_internal_momentum_event_time;
   if(g_internal_momentum_watch_owner_side!=side || ManagedPositionSide()!=side)
      return false;

   // v8.211 explicit priority resolver for the late-published internal event:
   // WATCH > ACCEL > DIRECTION.  DIRECTION may consume a shared ADD
   // slot only when neither higher-priority signal exists on this M3 bar.
   const bool watch_same_bar=(g_assist_state.bar_time==s.bar_time &&
                              g_assist_state.watch_pulse &&
                              !g_assist_state.watch_informational_repeat &&
                              g_assist_state.changed);
   if(watch_same_bar)
      return false;

   const bool accel_same_bar=(g_m3_segment.last_accel_event_time==s.bar_time &&
                              g_m3_segment.last_accel_event_side!=M3_SEG_NONE);
   if(accel_same_bar)
      return false;

   // M3AutoSubmitSignalAdd owns the single shared ADD budget:
   // g_additional_entry_filled_count / g_max_additional_entries.
   return M3AutoSubmitSignalAdd(s,side,side>0 ? "DIRECTION LONG" : "DIRECTION SHORT");
}

bool M3AutoApplyProtectionLive(const int side)
{
   if(side==0 || !g_m3_position_managed || g_initial_entry_price<=0.0 ||
      g_initial_r_distance<=0.0)
      return false;

   // v8.148: profit protection is tick-driven and independent of M3 bar/structure
   // lifecycle. WATCH/ACCEL remain completed-bar signals; profit already earned
   // by an open position is protected from the live executable quote.
   const double quote=(side>0 ? SymbolInfoDouble(_Symbol,SYMBOL_BID) :
                                SymbolInfoDouble(_Symbol,SYMBOL_ASK));
   if(quote<=0.0)
      return false;

   const double live_r=(side>0 ?
      (quote-g_initial_entry_price)/g_initial_r_distance :
      (g_initial_entry_price-quote)/g_initial_r_distance);

   if(live_r>g_highest_profit_r)
      g_highest_profit_r=live_r;
   if(live_r>g_m3_group_peak_r)
   {
      g_m3_group_peak_r=live_r;
      g_m3_group_add_count_at_peak=g_additional_entry_filled_count;
   }

   const double lock_start_r=MathMax(0.0,InpRangeProfitLockStartR);
   const double lock_fraction=MathMax(0.0,MathMin(100.0,InpRangeProfitLockPercent))/100.0;
   g_m3_audit_lock_active=(lock_fraction>0.0 && g_m3_group_peak_r>=lock_start_r);
   g_m3_audit_lock_target_r=0.0;
   g_m3_audit_lock_target_sl=0.0;
   if(!g_m3_audit_lock_active)
      return false;

   const double lock_r=g_m3_group_peak_r*lock_fraction;
   double candidate=(side>0 ?
      g_initial_entry_price+lock_r*g_initial_r_distance :
      g_initial_entry_price-lock_r*g_initial_r_distance);
   g_m3_audit_lock_target_r=lock_r;
   g_m3_audit_lock_target_sl=candidate;

   // Never move a previously protected stop backwards.
   if(g_m3_protected_sl>0.0)
      candidate=(side>0 ? MathMax(candidate,g_m3_protected_sl) : MathMin(candidate,g_m3_protected_sl));
   if(candidate<=0.0)
      return false;

   if(ApplyM3ProfitLock(side,candidate))
   {
      g_m3_protection_stage=1;
      g_m3_protection_last_time=TimeCurrent();
      g_m3_protected_sl=(side>0 ? MathMax(g_m3_protected_sl,candidate) :
         (g_m3_protected_sl<=0.0 ? candidate : MathMin(g_m3_protected_sl,candidate)));
      g_m3_position_state=JTC_M3_POS_PROTECT;
      return true;
   }
   return false;
}

// Called from Runtime::OnTick for an already-open M3 AUTO position.  This is
// intentionally separate from M3AutoEngineProcessTick(new_auto_bar), so the
// Peak80 lock cannot miss an intra-bar peak while waiting for the next M3 bar.
bool M3AutoManageProfitProtectionTick()
{
   if(!M3AutoEngineIsActive())
      return false;
   const int side=ManagedPositionSide();
   if(side==0 || !g_m3_position_managed)
      return false;
   return M3AutoApplyProtectionLive(side);
}

bool M3AutoManageOpenPosition(const JTC_M3_STATE &s,
                              const JTC_M3_MACD_STRUCTURE &macd,
                              const JTC_M3_MA22_STRUCTURE &ma22)
{
   const int side=ManagedPositionSide();
   if(side==0)
      return false;


   // v8.140: M3 AUTO strategic market-exit authority belongs only to the
   // opposite visible WATCH event in M3AutoProcessSignalEvents(). Structural
   // state may still drive broker-SL protection/diagnostics, but it must not
   // independently liquidate a signal-authorized position.
   const double progress_r=CurrentProgressR(side);
   if(progress_r>g_highest_profit_r)
      g_highest_profit_r=progress_r;

   // Structural protection is evaluated before the HOLD action. A new
   // favorable HL/LH can therefore tighten risk on the same completed bar while
   // the position itself remains in HOLD.
   // v8.148: Peak80 is managed on every tick by M3AutoManageProfitProtectionTick().
   // Completed-bar management must not be a second SL owner.
   if(g_m3_protection_stage>0)
      g_m3_position_state=JTC_M3_POS_PROTECT;
   else if(g_m3_segment.phase==M3_PHASE_EXHAUSTION)
      g_m3_position_state=JTC_M3_POS_WEAKENING;
   else
      g_m3_position_state=JTC_M3_POS_RUN;

   // A normal pullback is HOLD, not a reason to exit. ADD is authorized only
   // by the explicit same-direction M3 ACCEL event processed by
   // M3AutoProcessSignalEvents(). Position management never manufactures ADD.
   if(g_m3_segment.phase==M3_PHASE_REACCEL && progress_r>0.0)
   {
      g_m3_state=(side>0 ? JTC_M3_HOLD_LONG : JTC_M3_HOLD_SHORT);
      EnsureManagedStopsProtected(false);
      return false;
   }

   if(g_m3_segment.phase==M3_PHASE_EXHAUSTION)
      g_m3_state=(side>0 ? JTC_M3_PROFIT_LONG : JTC_M3_PROFIT_SHORT);
   else
      g_m3_state=(side>0 ? JTC_M3_HOLD_LONG : JTC_M3_HOLD_SHORT);

   EnsureManagedStopsProtected(false);
   return false;
}


// v8.242: reconcile same-EA reinitialization ownership with the v8.230
// historical warmup result. Newer causal confirmation wins; NONE/older replay
// may not erase a confirmed saved owner. Signal publication rules are unchanged.
void M3AssistReconcileReinitOwnership(const bool restored_chart_menu)
{
   if(!restored_chart_menu || !g_reinit_owner_snapshot_valid) return;

   const int replay_est_side=g_assist_state.established_side;
   const datetime replay_est_time=g_assist_state.established_time;
   const int replay_watch_side=g_assist_weak_watch_owner_side;
   const datetime replay_watch_time=g_assist_weak_watch_owner_time;
   const int replay_accel_side=g_m3_segment.last_accel_event_side;
   const datetime replay_accel_time=g_m3_segment.last_accel_event_time;
   const int replay_active_accel_owner_side=g_assist_accel_owner_side;
   const datetime replay_active_accel_owner_time=g_assist_accel_owner_watch_time;
   const bool replay_active_accel_owner_confirmed=g_assist_accel_owner_confirmed;
   bool restored_est=false, restored_watch=false, restored_accel=false;
   bool restored_active_accel_owner=false;

   if(g_reinit_saved_established_side!=0 && g_reinit_saved_established_time>0 &&
      (replay_est_side==0 || replay_est_time<g_reinit_saved_established_time))
   {
      g_assist_state.established_side=(g_reinit_saved_established_side>0 ? 1 : -1);
      g_assist_state.established_time=g_reinit_saved_established_time;
      restored_est=true;
   }
   if(g_reinit_saved_watch_owner_side!=0 && g_reinit_saved_watch_owner_time>0 &&
      (replay_watch_side==0 || replay_watch_time<g_reinit_saved_watch_owner_time))
   {
      g_assist_weak_watch_owner_side=(g_reinit_saved_watch_owner_side>0 ? 1 : -1);
      g_assist_weak_watch_owner_time=g_reinit_saved_watch_owner_time;
      g_assist_weak_watch_owner_high=g_reinit_saved_watch_owner_high;
      g_assist_weak_watch_owner_low=g_reinit_saved_watch_owner_low;
      g_assist_long_weak_armed=g_reinit_saved_long_weak_armed;
      g_assist_short_weak_armed=g_reinit_saved_short_weak_armed;
      restored_watch=true;
   }
   if(g_reinit_saved_last_accel_side!=0 && g_reinit_saved_last_accel_time>0 &&
      (replay_accel_side==0 || replay_accel_time<g_reinit_saved_last_accel_time))
   {
      g_m3_segment.last_accel_event_side=g_reinit_saved_last_accel_side;
      g_m3_segment.last_accel_event_time=g_reinit_saved_last_accel_time;
      restored_accel=true;
   }

   // v8.259: active ACCEL authority is restored only when the final historical
   // WATCH owner is the exact WATCH that created it. This preserves a live
   // pending/confirmed episode without reviving a cancelled stale WATCH.
   if(g_reinit_saved_accel_owner_side!=0 && g_reinit_saved_accel_owner_watch_time>0)
   {
      const int saved_active_side=(g_reinit_saved_accel_owner_side>0 ? 1 : -1);
      const bool exact_watch=(g_assist_weak_watch_owner_side==saved_active_side &&
                              g_assist_weak_watch_owner_time==g_reinit_saved_accel_owner_watch_time);
      const bool replay_not_newer=(replay_active_accel_owner_side==0 ||
                                   replay_active_accel_owner_time<=g_reinit_saved_accel_owner_watch_time);
      bool saved_confirm_valid=true;
      if(g_reinit_saved_accel_owner_confirmed)
         saved_confirm_valid=(g_m3_segment.last_accel_event_side==(saved_active_side>0 ? M3_SEG_LONG : M3_SEG_SHORT) &&
                              g_m3_segment.last_accel_event_time>g_reinit_saved_accel_owner_watch_time);

      if(exact_watch && replay_not_newer && saved_confirm_valid)
      {
         g_assist_accel_owner_side=saved_active_side;
         g_assist_accel_owner_watch_time=g_reinit_saved_accel_owner_watch_time;
         g_assist_accel_owner_confirmed=g_reinit_saved_accel_owner_confirmed;
         g_m3_segment.chart_cont_accel_owner_side=saved_active_side;
         g_m3_segment.chart_cont_accel_owner_time=g_reinit_saved_accel_owner_watch_time;
         // v8.261: this is a same-session reinitialization snapshot. Restore
         // the exact visible ACCEL count that existed before reinit; historical
         // replay must not inflate the current session count.
         g_m3_segment.chart_accel_publish_count=(int)MathMax(0,MathMin(5,g_reinit_saved_chart_accel_publish_count));
         g_m3_segment.chart_cont_accel_publish_count=(int)MathMax(0,MathMin(5,g_reinit_saved_chart_cont_accel_publish_count));
         restored_active_accel_owner=true;
      }
   }

   // v8.261: same-session reinit restores the dedicated PRE-REARM
   // execution owner only when the same managed side is still live.
   if(g_reinit_saved_pre_rearm_execution_owner_side!=0 &&
      g_reinit_saved_pre_rearm_execution_owner_time>0)
   {
      const int live_side=ManagedPositionSide();
      const int saved_exec_side=(g_reinit_saved_pre_rearm_execution_owner_side>0 ? M3_SEG_LONG : M3_SEG_SHORT);
      if(live_side==saved_exec_side || g_m3_pending_reverse_side==saved_exec_side)
      {
         g_pre_rearm_execution_owner_side=(saved_exec_side==M3_SEG_LONG ? 1 : -1);
         g_pre_rearm_execution_owner_time=g_reinit_saved_pre_rearm_execution_owner_time;
         g_pre_rearm_execution_owner_high=g_reinit_saved_pre_rearm_execution_owner_high;
         g_pre_rearm_execution_owner_low=g_reinit_saved_pre_rearm_execution_owner_low;
      }
   }

   if(restored_est)
   {
      const int est=g_assist_state.established_side;
      const datetime est_time=g_assist_state.established_time;
      const int owner=g_assist_weak_watch_owner_side;
      const datetime owner_time=g_assist_weak_watch_owner_time;
      const bool newer_opposite_watch=(owner!=0 && owner!=est && owner_time>est_time);
      g_assist_state.state=(newer_opposite_watch ?
                            (owner>0 ? JTA_ASSIST_REVERSAL_WATCH_UP : JTA_ASSIST_REVERSAL_WATCH_DOWN) :
                            (est>0 ? JTA_ASSIST_UP : JTA_ASSIST_DOWN));
      g_assist_state.direction_anchor=est;
      g_assist_state.previous_state=g_assist_state.state;
      g_assist_state.watch_pulse=false;
      g_assist_state.watch_informational_repeat=false;
      g_assist_state.watch_rearm_pulse=false;
      g_assist_state.weak_pulse=false;
      g_assist_state.weak_side=0;
      g_assist_state.changed=false;
      g_assist_state.reason="REINIT_OWNER_RECONCILED";
   }
   else if(g_assist_state.established_side==0 && restored_watch)
   {
      if(g_assist_state.direction_anchor==0 && g_reinit_saved_direction_anchor!=0)
         g_assist_state.direction_anchor=(g_reinit_saved_direction_anchor>0 ? 1 : -1);
      g_assist_state.state=(g_assist_weak_watch_owner_side>0 ? JTA_ASSIST_REVERSAL_WATCH_UP : JTA_ASSIST_REVERSAL_WATCH_DOWN);
      g_assist_state.previous_state=g_assist_state.state;
      g_assist_state.watch_pulse=false;
      g_assist_state.watch_informational_repeat=false;
      g_assist_state.watch_rearm_pulse=false;
      g_assist_state.weak_pulse=false;
      g_assist_state.weak_side=0;
      g_assist_state.changed=false;
      g_assist_state.reason="REINIT_WATCH_OWNER_RECONCILED";
   }

   if(g_assist_weak_watch_owner_side!=0 && g_assist_weak_watch_owner_time>0)
   {
      g_m3_auto_signal_leg_side=(g_assist_weak_watch_owner_side>0 ? M3_SEG_LONG : M3_SEG_SHORT);
      g_m3_auto_signal_leg_start_time=g_assist_weak_watch_owner_time;
      g_m3_auto_signal_leg_watch_sequence=0;
      g_internal_momentum_watch_owner_side=g_assist_weak_watch_owner_side;
   }

   // v8.251: reconcile the pending reverse-order lifecycle only after the
   // canonical WATCH/ACCEL owners above have been reconciled. This prevents a
   // stale saved REARM intent from surviving a newer opposite WATCH discovered
   // during historical replay. A same-side live position means the reverse
   // INITIAL was already established, so the pending intent is discarded.
   bool restored_pending_reverse=false;
   bool discarded_pending_reverse=false;
   if(g_reinit_saved_pending_reverse_side!=0 &&
      g_reinit_saved_pending_reverse_watch_time>0)
   {
      const int saved_pending_side=(g_reinit_saved_pending_reverse_side>0 ? M3_SEG_LONG : M3_SEG_SHORT);
      const int final_watch_side=(g_assist_weak_watch_owner_side>0 ? M3_SEG_LONG :
                                  (g_assist_weak_watch_owner_side<0 ? M3_SEG_SHORT : M3_SEG_NONE));
      const bool watch_owner_matches=(final_watch_side==saved_pending_side &&
                                      g_assist_weak_watch_owner_time==g_reinit_saved_pending_reverse_watch_time);
      const int live_side=ManagedPositionSide();
      const bool already_established=(live_side==saved_pending_side);

      bool accel_state_valid=true;
      if(g_reinit_saved_pending_reverse_requires_accel &&
         g_reinit_saved_pending_reverse_accel_confirmed)
      {
         accel_state_valid=(g_reinit_saved_pending_reverse_accel_time>g_reinit_saved_pending_reverse_watch_time &&
                            g_m3_segment.last_accel_event_side==saved_pending_side &&
                            g_m3_segment.last_accel_event_time>=g_reinit_saved_pending_reverse_accel_time);
      }
      else if(g_reinit_saved_pending_reverse_accel_confirmed)
      {
         // Confirmed-without-requirement is not a valid v8.249 lifecycle state.
         accel_state_valid=false;
      }

      if(watch_owner_matches && !already_established && accel_state_valid)
      {
         g_m3_pending_reverse_side=saved_pending_side;
         g_m3_pending_reverse_watch_time=g_reinit_saved_pending_reverse_watch_time;
         g_m3_pending_reverse_requires_accel=g_reinit_saved_pending_reverse_requires_accel;
         g_m3_pending_reverse_accel_confirmed=(g_reinit_saved_pending_reverse_requires_accel ?
                                                g_reinit_saved_pending_reverse_accel_confirmed : false);
         g_m3_pending_reverse_accel_time=(g_m3_pending_reverse_accel_confirmed ?
                                          g_reinit_saved_pending_reverse_accel_time : 0);

         // v8.251: saved obligation is only meaningful while the exact
         // opposite managed position still exists after canonical ownership
         // replay. FLAT means broker-confirmed completion; same-side means the
         // reverse INITIAL was already established and is handled above.
         g_m3_pending_reverse_exit_obligation=(
            g_reinit_saved_pending_reverse_exit_obligation &&
            live_side==-saved_pending_side);
         restored_pending_reverse=true;

         // Reconcile exactly once during reinit. Do not regenerate a WATCH or
         // invent a new exit owner; reuse the existing managed EXIT gateway.
         if(g_m3_pending_reverse_exit_obligation && !g_exit_order_in_progress)
         {
            const bool recovered_exit=ExitEngineSubmitManaged(
               saved_pending_side>0 ?
                  "M3 AUTO EXIT RECOVERY: REARM STATE WATCH LONG" :
                  "M3 AUTO EXIT RECOVERY: REARM STATE WATCH SHORT");
            PrintFormat("[ASSIST REINIT EXIT RECOVERY] pending=%d live=%d submitted=%d",
               saved_pending_side,live_side,recovered_exit?1:0);
         }
      }
      else
      {
         g_m3_pending_reverse_side=M3_SEG_NONE;
         g_m3_pending_reverse_watch_time=0;
         g_m3_pending_reverse_requires_accel=false;
         g_m3_pending_reverse_accel_confirmed=false;
         g_m3_pending_reverse_accel_time=0;
         g_m3_pending_reverse_exit_obligation=false;
         discarded_pending_reverse=true;
      }
   }

   // v8.252: reconcile pre-REARM EXIT-only obligation separately from
   // pending_reverse. The exact saved opposite WATCH owner must still be
   // canonical, the established recovery side must still match, and only the
   // exact opposite managed position may be flattened. FLAT/same-side/stale
   // ownership discards the obligation without generating any signal.
   bool restored_pre_rearm_exit=false;
   bool discarded_pre_rearm_exit=false;
   if(g_reinit_saved_pre_rearm_exit_obligation &&
      g_reinit_saved_pre_rearm_exit_recovery_side!=0 &&
      g_reinit_saved_pre_rearm_exit_owner_side!=0 &&
      g_reinit_saved_pre_rearm_exit_owner_time>0)
   {
      const int saved_recovery=(g_reinit_saved_pre_rearm_exit_recovery_side>0 ? M3_SEG_LONG : M3_SEG_SHORT);
      const int saved_owner=(g_reinit_saved_pre_rearm_exit_owner_side>0 ? M3_SEG_LONG : M3_SEG_SHORT);
      const int final_owner=(g_pre_rearm_execution_owner_side>0 ? M3_SEG_LONG :
                             (g_pre_rearm_execution_owner_side<0 ? M3_SEG_SHORT : M3_SEG_NONE));
      const int final_est=(g_assist_state.established_side>0 ? M3_SEG_LONG :
                           (g_assist_state.established_side<0 ? M3_SEG_SHORT : M3_SEG_NONE));
      const int live_side=ManagedPositionSide();
      const bool exact_owner=(final_owner==saved_owner &&
                              g_pre_rearm_execution_owner_time==g_reinit_saved_pre_rearm_exit_owner_time);
      const bool lifecycle_valid=(exact_owner && final_est==saved_recovery && saved_owner==-saved_recovery);

      if(lifecycle_valid && live_side==saved_owner)
      {
         g_m3_pre_rearm_exit_obligation=true;
         g_m3_pre_rearm_exit_recovery_side=saved_recovery;
         g_m3_pre_rearm_exit_owner_side=saved_owner;
         g_m3_pre_rearm_exit_owner_time=g_reinit_saved_pre_rearm_exit_owner_time;
         restored_pre_rearm_exit=true;
         if(!g_exit_order_in_progress)
         {
            const bool recovered_exit=ExitEngineSubmitManaged(
               saved_recovery>0 ?
                  "M3 AUTO EXIT RECOVERY: PREZERO REARM RECOVERY LONG" :
                  "M3 AUTO EXIT RECOVERY: PREZERO REARM RECOVERY SHORT");
            PrintFormat("[ASSIST PRE-REARM EXIT RECOVERY] recovery=%d owner=%d live=%d submitted=%d",
               saved_recovery,saved_owner,live_side,recovered_exit?1:0);
         }
      }
      else
      {
         g_m3_pre_rearm_exit_obligation=false;
         g_m3_pre_rearm_exit_recovery_side=M3_SEG_NONE;
         g_m3_pre_rearm_exit_owner_side=M3_SEG_NONE;
         g_m3_pre_rearm_exit_owner_time=0;
         discarded_pre_rearm_exit=true;
      }
   }

   PrintFormat("[ASSIST REINIT RECONCILE] saved_est=%d@%s replay_est=%d@%s final_est=%d@%s | saved_watch=%d@%s replay_watch=%d@%s final_watch=%d@%s | saved_accel=%d@%s replay_accel=%d@%s final_accel=%d@%s | restored=%d/%d/%d | pending_saved=%d@%s req=%d conf=%d@%s exit_ob=%d pending_final=%d@%s req=%d conf=%d@%s exit_ob=%d pending_restore=%d discard=%d",
      g_reinit_saved_established_side,TimeToString(g_reinit_saved_established_time,TIME_DATE|TIME_MINUTES),
      replay_est_side,TimeToString(replay_est_time,TIME_DATE|TIME_MINUTES),
      g_assist_state.established_side,TimeToString(g_assist_state.established_time,TIME_DATE|TIME_MINUTES),
      g_reinit_saved_watch_owner_side,TimeToString(g_reinit_saved_watch_owner_time,TIME_DATE|TIME_MINUTES),
      replay_watch_side,TimeToString(replay_watch_time,TIME_DATE|TIME_MINUTES),
      g_assist_weak_watch_owner_side,TimeToString(g_assist_weak_watch_owner_time,TIME_DATE|TIME_MINUTES),
      g_reinit_saved_last_accel_side,TimeToString(g_reinit_saved_last_accel_time,TIME_DATE|TIME_MINUTES),
      replay_accel_side,TimeToString(replay_accel_time,TIME_DATE|TIME_MINUTES),
      g_m3_segment.last_accel_event_side,TimeToString(g_m3_segment.last_accel_event_time,TIME_DATE|TIME_MINUTES),
      restored_est?1:0,restored_watch?1:0,restored_accel?1:0,
      g_reinit_saved_pending_reverse_side,TimeToString(g_reinit_saved_pending_reverse_watch_time,TIME_DATE|TIME_MINUTES),
      g_reinit_saved_pending_reverse_requires_accel?1:0,
      g_reinit_saved_pending_reverse_accel_confirmed?1:0,
      TimeToString(g_reinit_saved_pending_reverse_accel_time,TIME_DATE|TIME_MINUTES),
      g_reinit_saved_pending_reverse_exit_obligation?1:0,
      g_m3_pending_reverse_side,TimeToString(g_m3_pending_reverse_watch_time,TIME_DATE|TIME_MINUTES),
      g_m3_pending_reverse_requires_accel?1:0,
      g_m3_pending_reverse_accel_confirmed?1:0,
      TimeToString(g_m3_pending_reverse_accel_time,TIME_DATE|TIME_MINUTES),
      g_m3_pending_reverse_exit_obligation?1:0,
      restored_pending_reverse?1:0,discarded_pending_reverse?1:0);

   PrintFormat("[ASSIST PRE-REARM REINIT] saved_ob=%d recovery=%d owner=%d@%s final_ob=%d final_recovery=%d final_owner=%d@%s restored=%d discard=%d",
      g_reinit_saved_pre_rearm_exit_obligation?1:0,
      g_reinit_saved_pre_rearm_exit_recovery_side,
      g_reinit_saved_pre_rearm_exit_owner_side,TimeToString(g_reinit_saved_pre_rearm_exit_owner_time,TIME_DATE|TIME_MINUTES),
      g_m3_pre_rearm_exit_obligation?1:0,g_m3_pre_rearm_exit_recovery_side,
      g_m3_pre_rearm_exit_owner_side,TimeToString(g_m3_pre_rearm_exit_owner_time,TIME_DATE|TIME_MINUTES),
      restored_pre_rearm_exit?1:0,discarded_pre_rearm_exit?1:0);

   g_reinit_owner_snapshot_valid=false;
}

// v8.276: canonical WATCH extraction is shared by live and warmup replay so
// WatchEpisode diagnostics rebuild with exactly the same ownership semantics.
void M3AssistExtractWatchEventsForBar(const datetime bar_time,
                                      bool &pre_long,bool &pre_short,
                                      bool &info_repeat,int &info_repeat_side)
{
   const bool same_bar=(g_assist_state.bar_time==bar_time);
   const bool canonical=(same_bar && g_assist_state.watch_pulse &&
                         !g_assist_state.watch_informational_repeat &&
                         g_assist_state.changed);
   pre_long=(canonical && g_assist_state.state==JTA_ASSIST_REVERSAL_WATCH_UP);
   pre_short=(canonical && g_assist_state.state==JTA_ASSIST_REVERSAL_WATCH_DOWN);
   info_repeat=(same_bar && g_assist_state.watch_pulse &&
                g_assist_state.watch_informational_repeat);
   info_repeat_side=0;
   if(info_repeat)
   {
      if(g_assist_state.state==JTA_ASSIST_REVERSAL_WATCH_UP) info_repeat_side=M3_SEG_LONG;
      else if(g_assist_state.state==JTA_ASSIST_REVERSAL_WATCH_DOWN) info_repeat_side=M3_SEG_SHORT;
   }
}

// v8.227 live/restart parity: replay StateEvaluation and M3Segment in the same
// closed-bar order used by the live runtime.  Historical replay restores state
// only; no order, UI, alert, push or CSV pulse is emitted.
bool M3AssistWarmupRebuild()
{
   g_m3_runtime_mode=M3_RUNTIME_WARMUP;
   g_m3_warmup_complete=false;

   const int requested=MathMax(64,InpM3StructureWarmupBars);
   const int ceiling=MathMax(requested,InpM3StructureWarmupMaxBars);
   // v8.227: StateEvaluation ownership can predate the bounded M3 segment window.
   // Startup/restart is one-time work, so replay the full existing ceiling to
   // avoid false anchor reconstruction from an arbitrary 400-bar boundary.
   const int replay_bars=ceiling;
   int final_replayed=0;

   {
      M3AutoResetFlatState();
      StateEvaluationReset();
      WatchEpisodeResetRuntime();
      g_assist_history_replay=true;

      if(!EnsureMarketSnapshotAssist(replay_bars+64))
      {
         g_assist_history_replay=false;
         return false;
      }
      const int available=MathMin(replay_bars,ArraySize(g_ms_rates)-64);
      if(available<32)
      {
         g_assist_history_replay=false;
         return false;
      }

      int replayed=0;
      for(int i=available;i>=1;i--)
      {
         // Live order: StateEvaluation first, then M3Segment update.
         if(StateEvaluationUpdateAtClosedShift(i,true)) replayed++;

         JTC_M3_STATE hs; if(!M3BuildStateAtIndex(i,hs)) continue;
         JTC_M3_MACD_STRUCTURE hm; M3AnalyzeMACD(hs,hm);
         JTC_M3_MA22_STRUCTURE hma; M3AnalyzeMA22(hs,hma);
         g_m3_eval_index=i;
         M3SegmentUpdate(hs,hm,hma,i);
         if(g_m3_segment.last_accel_event_time==hs.bar_time)
            StateEvaluationConfirmEstablishedByAccel(
               g_m3_segment.last_accel_event_side==M3_SEG_LONG ? 1 :
               (g_m3_segment.last_accel_event_side==M3_SEG_SHORT ? -1 : 0),
               hs.bar_time);

         bool h_pre_long=false,h_pre_short=false,h_info_repeat=false; int h_info_side=0;
         M3AssistExtractWatchEventsForBar(hs.bar_time,h_pre_long,h_pre_short,h_info_repeat,h_info_side);
         const bool h_accel_long=(g_m3_segment.last_accel_event_time==hs.bar_time &&
                                  g_m3_segment.last_accel_event_side==M3_SEG_LONG);
         const bool h_accel_short=(g_m3_segment.last_accel_event_time==hs.bar_time &&
                                   g_m3_segment.last_accel_event_side==M3_SEG_SHORT);
         WatchEpisodeUpdate(hs,(h_pre_long || h_pre_short),
            (h_pre_long ? M3_SEG_LONG : (h_pre_short ? M3_SEG_SHORT : 0)),
            (h_accel_long || h_accel_short),
            (h_accel_long ? M3_SEG_LONG : (h_accel_short ? M3_SEG_SHORT : 0)));
         if(h_info_repeat) WatchEpisodeRecordInformationalRepeat(hs,h_info_side);
      }
      g_m3_eval_index=1;
      final_replayed=replayed;

   }

   g_assist_history_replay=false;

   // Consume all historical transient events.  Persistent state/ownership stays.
   g_assist_state.turn_pre_signal=false;g_assist_state.turn_pre_side=0;
   g_assist_state.turn_direction_signal=false;g_assist_state.turn_direction_side=0;
   g_assist_state.watch_pulse=false;
   g_assist_state.watch_informational_repeat=false;
   g_assist_state.watch_rearm_pulse=false;
   g_assist_state.weak_pulse=false;
   g_assist_state.weak_side=0;
   g_assist_state.changed=false;
   g_assist_state.flip_hold_action="RETIRED_V8_253";
   g_m3_segment.trigger_long=false;
   g_m3_segment.trigger_short=false;
   g_m3_segment.trigger_consumed=true;
   if(g_m3_segment.episode_state==M3_EP_TRIGGER)
      g_m3_segment.episode_state=M3_EP_TRIGGER_CONSUMED;
   g_m3_new_ext_high=false;
   g_m3_new_ext_low=false;
   g_m3_warmup_complete=true;
   g_m3_runtime_mode=(g_auto_trading ? M3_RUNTIME_AUTOTRADING : M3_RUNTIME_MONITORING);

   PrintFormat("[M3+ASSIST WARMUP] replayed=%d | bars=%d | final_bar=%s | assist=%s | anchor=%d | segment=%d",
               final_replayed,replay_bars,
               TimeToString(g_assist_state.bar_time,TIME_DATE|TIME_MINUTES),
               AssistStateName(g_assist_state.state),g_assist_state.direction_anchor,
               (int)g_m3_segment.direction);
   return final_replayed>0;
}

bool M3AutoEngineProcessTick(const bool new_auto_bar)
{
   if(!M3AutoEngineIsActive())
      return false;

   // v8.243 final defensive barrier: no caller may process a new M3 strategy
   // bar until authoritative historical reconstruction has completed.
   if(!g_m3_warmup_complete)
   {
      g_m3_auto_order_authority_active=false;
      return false;
   }

   g_m3_auto_order_authority_active=g_auto_trading;

   if(!new_auto_bar)
      return false;

   g_m3_runtime_mode=(g_auto_trading ? M3_RUNTIME_AUTOTRADING : M3_RUNTIME_MONITORING);

   JTC_M3_STATE s;
   if(!M3AutoReadState(s))
      return false;
   if(s.bar_time==g_m3_last_decision_bar)
      return false;
   g_m3_last_decision_bar=s.bar_time;

   // M3SegmentEngine remains the single M3 market-state/signal calculator.
   // It must update before AUTO reads the event fields below.
   JTC_M3_MACD_STRUCTURE macd;
   JTC_M3_MA22_STRUCTURE ma22;
   M3AnalyzeMACD(s,macd);
   M3AnalyzeMA22(s,ma22);

   M3SegmentUpdate(s,macd,ma22);

   // v8.229: WATCH->same-direction ACCEL replaces the retired FIRST FINAL as
   // ASSIST established-direction confirmation. This state is assist-only and
   // never mutates SignalEngine persistence/order ownership.
   if(g_m3_segment.last_accel_event_time==s.bar_time)
      StateEvaluationConfirmEstablishedByAccel(
         g_m3_segment.last_accel_event_side==M3_SEG_LONG ? 1 :
         (g_m3_segment.last_accel_event_side==M3_SEG_SHORT ? -1 : 0),
         s.bar_time);

   // v8.162: StateEvaluation is the sole WATCH order authority.
   // Consume only a newly published WATCH pulse on this completed M3 bar.
   bool pre_long=false,pre_short=false,info_repeat=false; int info_repeat_side=0;
   M3AssistExtractWatchEventsForBar(s.bar_time,pre_long,pre_short,info_repeat,info_repeat_side);
   const bool accel_long=(g_m3_segment.last_accel_event_time==s.bar_time &&
                          g_m3_segment.last_accel_event_side==M3_SEG_LONG);
   const bool accel_short=(g_m3_segment.last_accel_event_time==s.bar_time &&
                           g_m3_segment.last_accel_event_side==M3_SEG_SHORT);

   // v8.221 observation-only WATCH episode recorder. It consumes canonical
   // WATCH/ACCEL events and never changes signal/order/risk state.
   WatchEpisodeUpdate(s,(pre_long || pre_short),
      (pre_long ? M3_SEG_LONG : (pre_short ? M3_SEG_SHORT : 0)),
      (accel_long || accel_short),
      (accel_long ? M3_SEG_LONG : (accel_short ? M3_SEG_SHORT : 0)));
   if(info_repeat) WatchEpisodeRecordInformationalRepeat(s,info_repeat_side);

   // v8.279: canonical opposite WATCH invalidates a PREZERO re-entry arm even
   // while AUTO is temporarily disabled. This prevents stale execution
   // permission from surviving a later signal-ownership flip.
   const int raw_canonical_watch_side=(pre_long ? M3_SEG_LONG :
                                       (pre_short ? M3_SEG_SHORT : M3_SEG_NONE));
   if(g_prezero_reentry_armed && raw_canonical_watch_side!=M3_SEG_NONE &&
      raw_canonical_watch_side!=(g_prezero_reentry_side>0 ? M3_SEG_LONG : M3_SEG_SHORT))
   {
      g_prezero_reentry_armed=false;
      g_prezero_reentry_side=0;
      g_prezero_reentry_exit_time=0;
   }

   // Diagnostic lifecycle above also runs in monitoring mode. Execution path
   // remains byte-for-byte gated by the original AUTO permission here.
   if(!g_auto_trading)
      return false;

   const int position_side_before=ManagedPositionSide();
   const bool prezero_reentry_candidate=(
      position_side_before==0 &&
      g_prezero_reentry_armed &&
      g_prezero_reentry_side!=0 &&
      g_prezero_reentry_exit_time>0 &&
      s.bar_time>g_prezero_reentry_exit_time &&
      info_repeat &&
      info_repeat_side==(g_prezero_reentry_side>0 ? M3_SEG_LONG : M3_SEG_SHORT) &&
      g_assist_state.watch_observe_stage=="CONFIRMED");
   const bool auto_pre_long=(pre_long ||
      (prezero_reentry_candidate && g_prezero_reentry_side>0));
   const bool auto_pre_short=(pre_short ||
      (prezero_reentry_candidate && g_prezero_reentry_side<0));

   // Opposite pre-signal is a strategic ALL EXIT event. Do not run the normal
   // position-management pass again on the same bar after submitting it.
   if((position_side_before>0 && auto_pre_short) ||
      (position_side_before<0 && auto_pre_long))
      return M3AutoProcessSignalEvents(s,auto_pre_long,auto_pre_short,accel_long,accel_short,prezero_reentry_candidate);

   const bool signal_handled=M3AutoProcessSignalEvents(
      s,auto_pre_long,auto_pre_short,accel_long,accel_short,prezero_reentry_candidate);

   // v8.162: no independent M3 protection/exit owner in the pure signal-order
   // validation path. State WATCH owns INITIAL/reversal EXIT; ACCEL owns ADD.
   return signal_handled;
}

#endif
