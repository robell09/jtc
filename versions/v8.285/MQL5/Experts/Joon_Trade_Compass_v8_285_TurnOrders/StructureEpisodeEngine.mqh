//+------------------------------------------------------------------+
//| StructureEpisodeEngine.mqh                                       |
//| v8.172 position-owned structure state + trigger episode recorder      |
//+------------------------------------------------------------------+
#ifndef __JOON_STRUCTURE_EPISODE_ENGINE_MQH__
#define __JOON_STRUCTURE_EPISODE_ENGINE_MQH__

struct JTC_STRUCTURE_EPISODE
{
   bool active;
   long id;
   int side;
   datetime entry_time;
   double entry_price;
   datetime last_bar_time;
   int bar_offset;
   double mfe_price;
   double mae_price;
   int add_count;
   string last_event;
   datetime last_event_time;
   string exit_reason;
   double exit_price;
   double realized_pnl;

   // Frozen entry-time structural anchors.
   double entry_prev_swing_high;
   double entry_last_swing_high;
   double entry_prev_swing_low;
   double entry_last_swing_low;
   double entry_protected_high;
   double entry_protected_low;
   // v8.172: position-owned protected anchor reconstructed at actual INITIAL fill.
   double entry_position_protected_price;
   datetime entry_position_protected_time;
   string entry_position_protected_source;
   string entry_position_protected_type;
   double entry_ma7;
   double entry_ma22;
   double entry_macd_wave;
   double entry_macd_hist;
   double entry_delta;
   double entry_volume;

   // Latest completed M3 frame (read-only evidence; no order authority).
   double frame_open;
   double frame_high;
   double frame_low;
   double frame_close;
   double frame_ma7;
   double frame_ma22;
   double frame_macd_wave;
   double frame_macd_hist;
   double frame_delta;
   double frame_delta_ema;
   double frame_volume;
   bool frame_hh;
   bool frame_hl;
   bool frame_lh;
   bool frame_ll;
   bool frame_structure_break;
   bool frame_external_bullish;
   bool frame_external_bearish;
   bool frame_internal_bullish;
   bool frame_internal_bearish;

   // v8.170: diagnostic structure lifecycle owned by the actual INITIAL deal side.
   string diagnostic_state;
   datetime diagnostic_state_start_time;
   int diagnostic_bars_in_state;
   double diagnostic_protected_price;
   datetime diagnostic_protected_time;
   string diagnostic_protected_source;
   double diagnostic_break_price;
   datetime diagnostic_break_time;
   bool diagnostic_recovery_seen;
   double diagnostic_adverse_extreme;
   double previous_close;
   double previous_high;
   double previous_low;
   double previous_macd_wave;

   // Per-frame structural evidence. Diagnostic only.
   double frame_prev_swing_high;
   double frame_last_swing_high;
   double frame_prev_swing_low;
   double frame_last_swing_low;
   double frame_protected_high;
   double frame_protected_low;
   bool frame_new_directional_swing;
   bool frame_directional_progress;
   bool frame_macd_progress;
   bool frame_macd_weakening;
   bool frame_protected_test;
   bool frame_protected_break;
   bool frame_recovery_attempt;
   bool frame_recovered;
   bool frame_recovery_failed;
   bool frame_structure_failed;
   // v8.173: separate internal protected damage from confirmed external trend failure.
   bool frame_internal_break;
   bool frame_external_failure_confirmed;
   bool frame_external_opposite_high_relation;
   bool frame_external_opposite_low_relation;
   bool frame_external_pivots_after_break;
   bool frame_external_macd_confirm;
   datetime diagnostic_recovery_failed_time;
   string frame_diagnostic_state;
   datetime frame_state_start_time;
   int frame_bars_in_state;
   double frame_diagnostic_protected_price;
   double frame_diagnostic_break_price;
   // v8.172: position-owned protected anchor audit.
   double frame_position_protected_price;
   datetime frame_position_protected_time;
   string frame_position_protected_source;
   bool frame_position_protected_updated;
   double frame_position_protected_old_price;
   string frame_position_protected_update_reason;
   double frame_position_candidate_price;
   datetime frame_position_candidate_time;
   string frame_position_candidate_source;

   // v8.170 trigger transition evidence. Existing trigger logic remains read-only.
   double entry_internal_trigger_high;
   double entry_internal_trigger_low;
   double entry_struct_long_trigger_price;
   double entry_struct_short_trigger_price;
   double prev_internal_trigger_high;
   double prev_internal_trigger_low;
   double prev_struct_long_trigger_price;
   double prev_struct_short_trigger_price;
   bool frame_internal_trigger_high_changed;
   bool frame_internal_trigger_low_changed;
   bool frame_struct_long_trigger_changed;
   bool frame_struct_short_trigger_changed;
   bool frame_struct_long_close_break;
   bool frame_struct_short_close_break;
   bool frame_struct_long_recovered;
   bool frame_struct_short_recovered;
   bool frame_struct_long_rebreak;
   bool frame_struct_short_rebreak;
   bool trigger_long_break_seen;
   bool trigger_short_break_seen;
   bool trigger_long_recovery_seen;
   bool trigger_short_recovery_seen;

   // v8.169: one-shot CSV ownership for a completed M3 structure frame.
   bool frame_export_pending;

   // Existing trigger lifecycle snapshots. Diagnostic only; no order authority.
   double frame_internal_trigger_high;
   double frame_internal_trigger_low;
   bool frame_trigger_long;
   bool frame_trigger_short;
   int frame_last_trigger_side;
   datetime frame_last_trigger_time;
   double frame_struct_long_trigger_price;
   double frame_struct_short_trigger_price;
   double frame_struct_long_trigger_base_price;
   double frame_struct_short_trigger_base_price;
   bool frame_struct_long_trigger_fired;
   bool frame_struct_short_trigger_fired;
   datetime frame_struct_long_trigger_fire_time;
   datetime frame_struct_short_trigger_fire_time;
};

JTC_STRUCTURE_EPISODE g_structure_episode;
long g_structure_episode_sequence=0;

void StructureEpisodeResetRuntime()
{
   ZeroMemory(g_structure_episode);
   g_structure_episode.active=false;
   g_structure_episode.last_event="NONE";
}

bool StructureEpisodeSelectEntryProtected(const int side,const datetime deal_time,const double deal_price,
                                         double &price,datetime &pivot_time,string &source,string &pivot_type)
{
   price=0.0; pivot_time=0; source="NONE"; pivot_type=(side>0 ? "HL" : "LH");
   if(side>0)
   {
      // Primary: completed external 2/2 confirmed HL. Secondary: completed internal 1/1 confirmed HL.
      if(g_m3_ext_hl && g_m3_ext_last_low>0.0 && g_m3_ext_last_low_time>0 &&
         g_m3_ext_last_low_time<deal_time && g_m3_ext_last_low<deal_price)
      { price=g_m3_ext_last_low; pivot_time=g_m3_ext_last_low_time; source="EXTERNAL_2_2_HL"; return true; }
      if(g_m3_int_hl && g_m3_int_last_low>0.0 && g_m3_int_last_low_time>0 &&
         g_m3_int_last_low_time<deal_time && g_m3_int_last_low<deal_price)
      { price=g_m3_int_last_low; pivot_time=g_m3_int_last_low_time; source="INTERNAL_1_1_HL"; return true; }
      // If relationship history is not yet available, retain the latest confirmed pivot as audit fallback,
      // but never import g_m3_segment.protected_swing_* into position ownership.
      if(g_m3_ext_last_low>0.0 && g_m3_ext_last_low_time>0 && g_m3_ext_last_low_time<deal_time && g_m3_ext_last_low<deal_price)
      { price=g_m3_ext_last_low; pivot_time=g_m3_ext_last_low_time; source="EXTERNAL_2_2_CONFIRMED_LOW"; return true; }
      if(g_m3_int_last_low>0.0 && g_m3_int_last_low_time>0 && g_m3_int_last_low_time<deal_time && g_m3_int_last_low<deal_price)
      { price=g_m3_int_last_low; pivot_time=g_m3_int_last_low_time; source="INTERNAL_1_1_CONFIRMED_LOW"; return true; }
   }
   else
   {
      if(g_m3_ext_lh && g_m3_ext_last_high>0.0 && g_m3_ext_last_high_time>0 &&
         g_m3_ext_last_high_time<deal_time && g_m3_ext_last_high>deal_price)
      { price=g_m3_ext_last_high; pivot_time=g_m3_ext_last_high_time; source="EXTERNAL_2_2_LH"; return true; }
      if(g_m3_int_lh && g_m3_int_last_high>0.0 && g_m3_int_last_high_time>0 &&
         g_m3_int_last_high_time<deal_time && g_m3_int_last_high>deal_price)
      { price=g_m3_int_last_high; pivot_time=g_m3_int_last_high_time; source="INTERNAL_1_1_LH"; return true; }
      if(g_m3_ext_last_high>0.0 && g_m3_ext_last_high_time>0 && g_m3_ext_last_high_time<deal_time && g_m3_ext_last_high>deal_price)
      { price=g_m3_ext_last_high; pivot_time=g_m3_ext_last_high_time; source="EXTERNAL_2_2_CONFIRMED_HIGH"; return true; }
      if(g_m3_int_last_high>0.0 && g_m3_int_last_high_time>0 && g_m3_int_last_high_time<deal_time && g_m3_int_last_high>deal_price)
      { price=g_m3_int_last_high; pivot_time=g_m3_int_last_high_time; source="INTERNAL_1_1_CONFIRMED_HIGH"; return true; }
   }
   return false;
}

void StructureEpisodeStart(const int side,const datetime deal_time,const double deal_price)
{
   if(side==0 || deal_price<=0.0) return;
   StructureEpisodeResetRuntime();
   g_structure_episode_sequence++;
   g_structure_episode.active=true;
   g_structure_episode.id=g_structure_episode_sequence;
   g_structure_episode.side=side;
   g_structure_episode.entry_time=deal_time;
   g_structure_episode.entry_price=deal_price;
   g_structure_episode.last_event="EPISODE_START";
   g_structure_episode.last_event_time=deal_time;
   // Keep external pivot snapshots for backwards-compatible audit, but reconstruct position protection independently.
   g_structure_episode.entry_prev_swing_high=g_m3_ext_prev_high;
   g_structure_episode.entry_last_swing_high=g_m3_ext_last_high;
   g_structure_episode.entry_prev_swing_low=g_m3_ext_prev_low;
   g_structure_episode.entry_last_swing_low=g_m3_ext_last_low;
   g_structure_episode.entry_protected_high=g_m3_segment.protected_swing_high; // legacy audit only
   g_structure_episode.entry_protected_low=g_m3_segment.protected_swing_low;   // legacy audit only
   double entry_protect=0.0; datetime entry_protect_time=0; string entry_protect_source="NONE",entry_protect_type="";
   StructureEpisodeSelectEntryProtected(side,deal_time,deal_price,entry_protect,entry_protect_time,entry_protect_source,entry_protect_type);
   g_structure_episode.entry_position_protected_price=entry_protect;
   g_structure_episode.entry_position_protected_time=entry_protect_time;
   g_structure_episode.entry_position_protected_source=entry_protect_source;
   g_structure_episode.entry_position_protected_type=entry_protect_type;
   g_structure_episode.diagnostic_state="HEALTHY";
   g_structure_episode.diagnostic_state_start_time=deal_time;
   g_structure_episode.diagnostic_bars_in_state=0;
   g_structure_episode.diagnostic_protected_price=entry_protect;
   g_structure_episode.diagnostic_protected_time=entry_protect_time;
   g_structure_episode.diagnostic_protected_source=entry_protect_source;
   g_structure_episode.entry_internal_trigger_high=g_m3_segment.internal_trigger_high;
   g_structure_episode.entry_internal_trigger_low=g_m3_segment.internal_trigger_low;
   g_structure_episode.entry_struct_long_trigger_price=g_struct_long_trigger_price;
   g_structure_episode.entry_struct_short_trigger_price=g_struct_short_trigger_price;
   g_structure_episode.prev_internal_trigger_high=g_m3_segment.internal_trigger_high;
   g_structure_episode.prev_internal_trigger_low=g_m3_segment.internal_trigger_low;
   g_structure_episode.prev_struct_long_trigger_price=g_struct_long_trigger_price;
   g_structure_episode.prev_struct_short_trigger_price=g_struct_short_trigger_price;
   JTC_M3_STATE s;
   if(M3AutoReadState(s))
   {
      g_structure_episode.entry_ma7=s.ma7;
      g_structure_episode.entry_ma22=s.ma22;
      g_structure_episode.entry_macd_wave=s.wave;
      g_structure_episode.entry_macd_hist=s.hist;
      g_structure_episode.entry_delta=s.raw_delta;
      g_structure_episode.entry_volume=s.volume;
   }
}

void StructureEpisodeMarkAdd(const datetime deal_time)
{
   if(!g_structure_episode.active) return;
   g_structure_episode.add_count++;
   g_structure_episode.last_event=StringFormat("ADD%d",g_structure_episode.add_count);
   g_structure_episode.last_event_time=deal_time;
}

void StructureEpisodeSetDiagnosticState(const string next_state,const datetime bar_time)
{
   if(g_structure_episode.diagnostic_state!=next_state)
   {
      g_structure_episode.diagnostic_state=next_state;
      g_structure_episode.diagnostic_state_start_time=bar_time;
      g_structure_episode.diagnostic_bars_in_state=1;
   }
   else
      g_structure_episode.diagnostic_bars_in_state++;
}

void StructureEpisodeCaptureM3Frame()
{
   if(!g_structure_episode.active) return;
   JTC_M3_STATE s;
   if(!M3AutoReadState(s) || s.bar_time<=0 || s.bar_time==g_structure_episode.last_bar_time) return;
   g_structure_episode.last_bar_time=s.bar_time;
   g_structure_episode.bar_offset++;
   g_structure_episode.frame_open=iOpen(_Symbol,AUTO_TF,1);
   g_structure_episode.frame_high=s.high;
   g_structure_episode.frame_low=s.low;
   g_structure_episode.frame_close=s.close;
   g_structure_episode.frame_ma7=s.ma7;
   g_structure_episode.frame_ma22=s.ma22;
   g_structure_episode.frame_macd_wave=s.wave;
   g_structure_episode.frame_macd_hist=s.hist;
   g_structure_episode.frame_delta=s.raw_delta;
   g_structure_episode.frame_delta_ema=s.delta_ema;
   g_structure_episode.frame_volume=s.volume;
   g_structure_episode.frame_hh=g_m3_segment.higher_high;
   g_structure_episode.frame_hl=g_m3_segment.higher_low;
   g_structure_episode.frame_lh=g_m3_segment.lower_high;
   g_structure_episode.frame_ll=g_m3_segment.lower_low;
   g_structure_episode.frame_structure_break=g_m3_segment.structure_break;
   g_structure_episode.frame_external_bullish=g_m3_segment.external_bullish;
   g_structure_episode.frame_external_bearish=g_m3_segment.external_bearish;
   g_structure_episode.frame_internal_bullish=g_m3_segment.internal_bullish;
   g_structure_episode.frame_internal_bearish=g_m3_segment.internal_bearish;
   g_structure_episode.frame_internal_trigger_high=g_m3_segment.internal_trigger_high;
   g_structure_episode.frame_internal_trigger_low=g_m3_segment.internal_trigger_low;
   g_structure_episode.frame_trigger_long=g_m3_segment.trigger_long;
   g_structure_episode.frame_trigger_short=g_m3_segment.trigger_short;
   g_structure_episode.frame_last_trigger_side=g_m3_segment.last_trigger_event_side;
   g_structure_episode.frame_last_trigger_time=g_m3_segment.last_trigger_event_time;
   g_structure_episode.frame_struct_long_trigger_price=g_struct_long_trigger_price;
   g_structure_episode.frame_struct_short_trigger_price=g_struct_short_trigger_price;
   g_structure_episode.frame_struct_long_trigger_base_price=g_struct_long_trigger_base_price;
   g_structure_episode.frame_struct_short_trigger_base_price=g_struct_short_trigger_base_price;
   g_structure_episode.frame_struct_long_trigger_fired=g_struct_long_trigger_fired;
   g_structure_episode.frame_struct_short_trigger_fired=g_struct_short_trigger_fired;
   g_structure_episode.frame_struct_long_trigger_fire_time=g_struct_long_trigger_fire_time;
   g_structure_episode.frame_struct_short_trigger_fire_time=g_struct_short_trigger_fire_time;

   // v8.170 structural evidence is reconstructed from the actual trade side.
   g_structure_episode.frame_prev_swing_high=g_m3_ext_prev_high;
   g_structure_episode.frame_last_swing_high=g_m3_ext_last_high;
   g_structure_episode.frame_prev_swing_low=g_m3_ext_prev_low;
   g_structure_episode.frame_last_swing_low=g_m3_ext_last_low;
   g_structure_episode.frame_protected_high=g_m3_segment.protected_swing_high;
   g_structure_episode.frame_protected_low=g_m3_segment.protected_swing_low;

   const bool have_prev=(g_structure_episode.previous_close>0.0);
   const bool side_long=(g_structure_episode.side>0);
   g_structure_episode.frame_directional_progress=have_prev && (side_long ? s.close>g_structure_episode.previous_close : s.close<g_structure_episode.previous_close);
   g_structure_episode.frame_macd_progress=have_prev && (side_long ? s.wave>g_structure_episode.previous_macd_wave : s.wave<g_structure_episode.previous_macd_wave);
   g_structure_episode.frame_macd_weakening=have_prev && (side_long ? s.wave<g_structure_episode.previous_macd_wave : s.wave>g_structure_episode.previous_macd_wave);
   g_structure_episode.frame_new_directional_swing=side_long ? g_m3_segment.higher_high : g_m3_segment.lower_low;

   // v8.172: position-owned protected promotion. Only a newly confirmed favorable pivot may tighten it.
   g_structure_episode.frame_position_protected_updated=false;
   g_structure_episode.frame_position_protected_old_price=g_structure_episode.diagnostic_protected_price;
   g_structure_episode.frame_position_protected_update_reason="NONE";
   g_structure_episode.frame_position_candidate_price=0.0;
   g_structure_episode.frame_position_candidate_time=0;
   g_structure_episode.frame_position_candidate_source="NONE";

   double candidate=0.0; datetime candidate_time=0; string candidate_source="NONE";
   if(side_long)
   {
      if(g_m3_new_ext_low && g_m3_ext_hl && g_m3_ext_last_low>0.0 && g_m3_ext_last_low<s.close)
      { candidate=g_m3_ext_last_low; candidate_time=g_m3_ext_last_low_time; candidate_source="EXTERNAL_2_2_HL"; }
      else if(g_structure_episode.diagnostic_protected_price<=0.0 && g_m3_new_int_low && g_m3_int_hl && g_m3_int_last_low>0.0 && g_m3_int_last_low<s.close)
      { candidate=g_m3_int_last_low; candidate_time=g_m3_int_last_low_time; candidate_source="INTERNAL_1_1_HL"; }
      if(candidate>0.0 && (g_structure_episode.diagnostic_protected_price<=0.0 || candidate>g_structure_episode.diagnostic_protected_price))
      {
         g_structure_episode.diagnostic_protected_price=candidate;
         g_structure_episode.diagnostic_protected_time=candidate_time;
         g_structure_episode.diagnostic_protected_source=candidate_source;
         g_structure_episode.frame_position_protected_updated=true;
         g_structure_episode.frame_position_protected_update_reason="CONFIRMED_NEW_HL";
      }
   }
   else
   {
      if(g_m3_new_ext_high && g_m3_ext_lh && g_m3_ext_last_high>0.0 && g_m3_ext_last_high>s.close)
      { candidate=g_m3_ext_last_high; candidate_time=g_m3_ext_last_high_time; candidate_source="EXTERNAL_2_2_LH"; }
      else if(g_structure_episode.diagnostic_protected_price<=0.0 && g_m3_new_int_high && g_m3_int_lh && g_m3_int_last_high>0.0 && g_m3_int_last_high>s.close)
      { candidate=g_m3_int_last_high; candidate_time=g_m3_int_last_high_time; candidate_source="INTERNAL_1_1_LH"; }
      if(candidate>0.0 && (g_structure_episode.diagnostic_protected_price<=0.0 || candidate<g_structure_episode.diagnostic_protected_price))
      {
         g_structure_episode.diagnostic_protected_price=candidate;
         g_structure_episode.diagnostic_protected_time=candidate_time;
         g_structure_episode.diagnostic_protected_source=candidate_source;
         g_structure_episode.frame_position_protected_updated=true;
         g_structure_episode.frame_position_protected_update_reason="CONFIRMED_NEW_LH";
      }
   }
   g_structure_episode.frame_position_candidate_price=candidate;
   g_structure_episode.frame_position_candidate_time=candidate_time;
   g_structure_episode.frame_position_candidate_source=candidate_source;
   g_structure_episode.frame_position_protected_price=g_structure_episode.diagnostic_protected_price;
   g_structure_episode.frame_position_protected_time=g_structure_episode.diagnostic_protected_time;
   g_structure_episode.frame_position_protected_source=g_structure_episode.diagnostic_protected_source;

   const double protect=g_structure_episode.diagnostic_protected_price;
   g_structure_episode.frame_protected_test=(protect>0.0 && (side_long ? (s.low<=protect && s.close>=protect) : (s.high>=protect && s.close<=protect)));
   g_structure_episode.frame_protected_break=(protect>0.0 && (side_long ? s.close<protect : s.close>protect));
   g_structure_episode.frame_recovery_attempt=false;
   g_structure_episode.frame_recovered=false;
   g_structure_episode.frame_recovery_failed=false;
   g_structure_episode.frame_structure_failed=false;
   g_structure_episode.frame_internal_break=false;
   g_structure_episode.frame_external_failure_confirmed=false;
   g_structure_episode.frame_external_opposite_high_relation=false;
   g_structure_episode.frame_external_opposite_low_relation=false;
   g_structure_episode.frame_external_pivots_after_break=false;
   g_structure_episode.frame_external_macd_confirm=false;

   if(g_structure_episode.diagnostic_break_time<=0 && g_structure_episode.frame_protected_break)
   {
      g_structure_episode.diagnostic_break_time=s.bar_time;
      g_structure_episode.diagnostic_break_price=protect;
      g_structure_episode.diagnostic_adverse_extreme=(side_long ? s.low : s.high);
      g_structure_episode.frame_internal_break=true;
      g_structure_episode.diagnostic_recovery_failed_time=0;
      StructureEpisodeSetDiagnosticState("INTERNAL_BREAK",s.bar_time);
   }
   else if(g_structure_episode.diagnostic_break_time>0)
   {
      const bool back_inside=(side_long ? s.close>g_structure_episode.diagnostic_break_price : s.close<g_structure_episode.diagnostic_break_price);
      const bool adverse_again=(side_long ? s.close<g_structure_episode.diagnostic_break_price : s.close>g_structure_episode.diagnostic_break_price);
      if(back_inside)
      {
         g_structure_episode.frame_recovery_attempt=true;
         g_structure_episode.diagnostic_recovery_seen=true;
         if(g_structure_episode.frame_directional_progress && g_structure_episode.frame_macd_progress)
         {
            g_structure_episode.frame_recovered=true;
            g_structure_episode.diagnostic_break_time=0;
            g_structure_episode.diagnostic_break_price=0.0;
            g_structure_episode.diagnostic_recovery_seen=false;
            g_structure_episode.diagnostic_recovery_failed_time=0;
            StructureEpisodeSetDiagnosticState("RECOVERED",s.bar_time);
         }
         else
            StructureEpisodeSetDiagnosticState("RECOVERY_ATTEMPT",s.bar_time);
      }
      else if(g_structure_episode.diagnostic_recovery_seen && adverse_again &&
              !g_structure_episode.frame_directional_progress && g_structure_episode.frame_macd_weakening)
      {
         g_structure_episode.frame_recovery_failed=true;
         if(g_structure_episode.diagnostic_recovery_failed_time<=0)
            g_structure_episode.diagnostic_recovery_failed_time=s.bar_time;

         // v8.173: a protected re-break is internal damage only. Final failure requires
         // a complete opposite EXTERNAL 2/2 structure formed after the original break,
         // plus MACD progression in the adverse direction. No fixed ATR/bar threshold.
         const bool opposite_high_relation=(side_long ? g_m3_ext_lh : g_m3_ext_hh);
         const bool opposite_low_relation =(side_long ? g_m3_ext_ll : g_m3_ext_hl);
         const bool high_after_break=(g_m3_ext_last_high_time>g_structure_episode.diagnostic_break_time);
         const bool low_after_break =(g_m3_ext_last_low_time>g_structure_episode.diagnostic_break_time);
         const bool external_after_break=(high_after_break && low_after_break);
         const bool macd_adverse=g_structure_episode.frame_macd_weakening;

         g_structure_episode.frame_external_opposite_high_relation=opposite_high_relation;
         g_structure_episode.frame_external_opposite_low_relation=opposite_low_relation;
         g_structure_episode.frame_external_pivots_after_break=external_after_break;
         g_structure_episode.frame_external_macd_confirm=macd_adverse;

         if(opposite_high_relation && opposite_low_relation && external_after_break && macd_adverse)
         {
            g_structure_episode.frame_external_failure_confirmed=true;
            g_structure_episode.frame_structure_failed=true;
            g_structure_episode.diagnostic_adverse_extreme=(side_long ? s.low : s.high);
            StructureEpisodeSetDiagnosticState("STRUCTURE_FAILED",s.bar_time);
         }
         else
            StructureEpisodeSetDiagnosticState("RECOVERY_FAILED",s.bar_time);
      }
      else
      {
         const double adverse=(side_long ? s.low : s.high);
         if(side_long) g_structure_episode.diagnostic_adverse_extreme=MathMin(g_structure_episode.diagnostic_adverse_extreme,adverse);
         else g_structure_episode.diagnostic_adverse_extreme=MathMax(g_structure_episode.diagnostic_adverse_extreme,adverse);
         g_structure_episode.frame_internal_break=true;
         StructureEpisodeSetDiagnosticState("INTERNAL_BREAK",s.bar_time);
      }
   }
   else if(g_structure_episode.frame_protected_test)
      StructureEpisodeSetDiagnosticState("AT_RISK",s.bar_time);
   else if(have_prev && !g_structure_episode.frame_directional_progress && g_structure_episode.frame_macd_weakening)
      StructureEpisodeSetDiagnosticState("WEAKENING",s.bar_time);
   else
      StructureEpisodeSetDiagnosticState("HEALTHY",s.bar_time);

   g_structure_episode.frame_diagnostic_state=g_structure_episode.diagnostic_state;
   g_structure_episode.frame_state_start_time=g_structure_episode.diagnostic_state_start_time;
   g_structure_episode.frame_bars_in_state=g_structure_episode.diagnostic_bars_in_state;
   g_structure_episode.frame_diagnostic_protected_price=g_structure_episode.diagnostic_protected_price;
   g_structure_episode.frame_diagnostic_break_price=g_structure_episode.diagnostic_break_price;

   // Trigger transition audit: preserve raw legacy values and derive transitions without order authority.
   g_structure_episode.frame_internal_trigger_high_changed=(g_m3_segment.internal_trigger_high!=g_structure_episode.prev_internal_trigger_high);
   g_structure_episode.frame_internal_trigger_low_changed=(g_m3_segment.internal_trigger_low!=g_structure_episode.prev_internal_trigger_low);
   g_structure_episode.frame_struct_long_trigger_changed=(g_struct_long_trigger_price!=g_structure_episode.prev_struct_long_trigger_price);
   g_structure_episode.frame_struct_short_trigger_changed=(g_struct_short_trigger_price!=g_structure_episode.prev_struct_short_trigger_price);
   g_structure_episode.frame_struct_long_close_break=(g_struct_long_trigger_price>0.0 && s.close>g_struct_long_trigger_price);
   g_structure_episode.frame_struct_short_close_break=(g_struct_short_trigger_price>0.0 && s.close<g_struct_short_trigger_price);
   g_structure_episode.frame_struct_long_recovered=false;
   g_structure_episode.frame_struct_short_recovered=false;
   g_structure_episode.frame_struct_long_rebreak=false;
   g_structure_episode.frame_struct_short_rebreak=false;
   if(g_structure_episode.frame_struct_long_close_break)
   {
      if(g_structure_episode.trigger_long_recovery_seen) g_structure_episode.frame_struct_long_rebreak=true;
      g_structure_episode.trigger_long_break_seen=true;
   }
   else if(g_structure_episode.trigger_long_break_seen && g_struct_long_trigger_price>0.0)
   {
      g_structure_episode.frame_struct_long_recovered=true;
      g_structure_episode.trigger_long_recovery_seen=true;
   }
   if(g_structure_episode.frame_struct_short_close_break)
   {
      if(g_structure_episode.trigger_short_recovery_seen) g_structure_episode.frame_struct_short_rebreak=true;
      g_structure_episode.trigger_short_break_seen=true;
   }
   else if(g_structure_episode.trigger_short_break_seen && g_struct_short_trigger_price>0.0)
   {
      g_structure_episode.frame_struct_short_recovered=true;
      g_structure_episode.trigger_short_recovery_seen=true;
   }

   g_structure_episode.prev_internal_trigger_high=g_m3_segment.internal_trigger_high;
   g_structure_episode.prev_internal_trigger_low=g_m3_segment.internal_trigger_low;
   g_structure_episode.prev_struct_long_trigger_price=g_struct_long_trigger_price;
   g_structure_episode.prev_struct_short_trigger_price=g_struct_short_trigger_price;
   g_structure_episode.previous_close=s.close;
   g_structure_episode.previous_high=s.high;
   g_structure_episode.previous_low=s.low;
   g_structure_episode.previous_macd_wave=s.wave;
   g_structure_episode.frame_export_pending=true;
   if(g_structure_episode.side>0)
   {
      g_structure_episode.mfe_price=MathMax(g_structure_episode.mfe_price,s.high-g_structure_episode.entry_price);
      g_structure_episode.mae_price=MathMax(g_structure_episode.mae_price,g_structure_episode.entry_price-s.low);
   }
   else
   {
      g_structure_episode.mfe_price=MathMax(g_structure_episode.mfe_price,g_structure_episode.entry_price-s.low);
      g_structure_episode.mae_price=MathMax(g_structure_episode.mae_price,s.high-g_structure_episode.entry_price);
   }
   g_structure_episode.last_event="M3_FRAME";
   g_structure_episode.last_event_time=s.bar_time;
}

void StructureEpisodeFinish(const datetime deal_time,const double deal_price,const double realized_pnl,const string reason)
{
   if(!g_structure_episode.active) return;
   g_structure_episode.active=false;
   g_structure_episode.exit_price=deal_price;
   g_structure_episode.realized_pnl=realized_pnl;
   g_structure_episode.exit_reason=reason;
   g_structure_episode.last_event="EPISODE_END";
   g_structure_episode.last_event_time=deal_time;
}

#endif
