#ifndef JTC_TURN_SIGNAL_ENGINE_MQH
#define JTC_TURN_SIGNAL_ENGINE_MQH
#include "TurnCore.mqh"
datetime g_turn_last_long=0,g_turn_last_short=0,g_turn_last_bar=0;
void JTC_TurnClearChart()
{
   ObjectsDeleteAll(0,"JTC_TURN284_EA_"+IntegerToString((long)InpMagicNumber)+"_");
}
void JTC_TurnEngineReset()
{
   g_turn_last_long=0; g_turn_last_short=0; g_turn_last_bar=0;
}
void JTC_TurnDraw(const JTC_TURN_FRAME &f,const JTC_TURN_RESULT &q)
{
   if(!InpTurnShowChart || _Period!=PERIOD_M3 || q.side==0) return;
   const string prefix="JTC_TURN284_EA_"+IntegerToString((long)InpMagicNumber)+"_";
   const string name=prefix+IntegerToString((long)f.bar_time)+(q.side>0 ? "_L" : "_S");
   const double marker=q.side>0 ? f.low_price-f.atr14*0.12 : f.high_price+f.atr14*0.12;
   const color shade=q.side>0 ? clrLimeGreen : clrTomato;
   const string tip=StringFormat("M3 TURN PRE %s | pivot=%s | confirmed-bar=%s | available-after=%s | score=3/3 | distance=%.3f ATR",
      q.side>0 ? "LONG" : "SHORT",TimeToString(f.pivot_time,TIME_DATE|TIME_SECONDS),
      TimeToString(f.bar_time,TIME_DATE|TIME_SECONDS),TimeToString(f.bar_time+180,TIME_DATE|TIME_SECONDS),q.distance_r);
   if(ObjectFind(0,name)<0 && ObjectCreate(0,name,OBJ_ARROW,0,f.bar_time,marker))
   {
      ObjectSetInteger(0,name,OBJPROP_ARROWCODE,q.side>0 ? 233 : 234);
      ObjectSetInteger(0,name,OBJPROP_COLOR,shade);
      ObjectSetInteger(0,name,OBJPROP_WIDTH,2);
      ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);
      ObjectSetString(0,name,OBJPROP_TOOLTIP,tip);
   }
   if(InpTurnShowPivotAnchors)
   {
      const string anchor=name+"_PIVOT_KNOWN_LATER";
      if(ObjectFind(0,anchor)<0 && ObjectCreate(0,anchor,OBJ_ARROW,0,f.pivot_time,q.pivot_price))
      {
         ObjectSetInteger(0,anchor,OBJPROP_ARROWCODE,159);
         ObjectSetInteger(0,anchor,OBJPROP_COLOR,clrSilver);
         ObjectSetInteger(0,anchor,OBJPROP_WIDTH,1);
         ObjectSetInteger(0,anchor,OBJPROP_SELECTABLE,false);
         ObjectSetString(0,anchor,OBJPROP_TOOLTIP,"PIVOT ANCHOR (NOT AVAILABLE ON THIS BAR) | "+tip);
      }
   }
}
void JTC_TurnProcess(const MqlRates &r[],const double &raw[],const double &wave[],
                    const double &delta[],const double &ema[],const double &volume[],
                    const bool historical_replay,const int historical_shift)
{
   g_assist_state.turn_pre_enabled=InpTurnPreEnabled;
   g_assist_state.turn_pre_data_valid=false; g_assist_state.turn_pre_signal=false;
   g_assist_state.turn_pre_side=0; g_assist_state.turn_pre_score=0;
   g_assist_state.turn_pre_confirm_bar=0; g_assist_state.turn_pre_available_time=0;
   g_assist_state.turn_pre_pivot_time=0; g_assist_state.turn_pre_pivot_price=0.0;
   g_assist_state.turn_pre_distance_r=0.0;
   g_assist_state.turn_pre_long_divergence_r=0.0; g_assist_state.turn_pre_short_divergence_r=0.0;
   g_assist_state.turn_pre_atr14=0.0; g_assist_state.turn_pre_opposite=false;
   g_assist_state.turn_pre_require_divergence=InpTurnRequireDivergence;
   g_assist_state.turn_pre_reason="DISABLED";
   if(!InpTurnPreEnabled) return;
   if(AUTO_TF!=PERIOD_M3) {g_assist_state.turn_pre_reason="M3_REQUIRED";return;}
   JTC_TURN_FRAME f; JTC_TURN_RESULT q;
   JTC_TurnBuildFrame(r,raw,wave,delta,ema,volume,1,InpTurnLeftBars,f);
   if(!f.valid) {g_assist_state.turn_pre_reason="NOT_READY_OR_GAP";return;}
   if(f.bar_time<=g_turn_last_bar) {g_assist_state.turn_pre_reason="DUPLICATE_BAR";return;}
   g_turn_last_bar=f.bar_time;
   JTC_TurnDecide(f,InpTurnRequireDivergence,InpTurnMinReboundATR,
      InpTurnMaxDistanceATR,InpTurnMomentumDeadzoneATR,q);
   g_assist_state.turn_pre_data_valid=true;
   g_assist_state.turn_pre_confirm_bar=f.bar_time;
   g_assist_state.turn_pre_available_time=f.bar_time+180;
   g_assist_state.turn_pre_pivot_time=f.pivot_time;
   g_assist_state.turn_pre_atr14=f.atr14;
   g_assist_state.turn_pre_long_divergence_r=f.long_divergence_r;
   g_assist_state.turn_pre_short_divergence_r=f.short_divergence_r;
   g_assist_state.turn_pre_reason="NO_TURN_CONFIRMATION";
   if(q.side==0) return;
   if(!JTC_TurnEmit(f.bar_time,q.side,InpTurnSameSideCooldownBars,g_turn_last_long,g_turn_last_short))
   {g_assist_state.turn_pre_reason="COOLDOWN";return;}
   g_assist_state.turn_pre_signal=true; g_assist_state.turn_pre_side=q.side;
   g_assist_state.turn_pre_pivot_price=q.pivot_price;
   g_assist_state.turn_pre_score=3; g_assist_state.turn_pre_distance_r=q.distance_r;
   g_assist_state.turn_pre_opposite=(g_assist_state.established_side*q.side<0);
   g_assist_state.turn_pre_reason=q.side>0 ? "LOW_TURN_PRE" : "HIGH_TURN_PRE";
   if(!historical_replay || historical_shift<=InpTurnChartHistoryBars) JTC_TurnDraw(f,q);
}
#endif
