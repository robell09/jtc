#ifndef JTC_TURN_DIRECTION_ENGINE_MQH
#define JTC_TURN_DIRECTION_ENGINE_MQH
#include "TurnDirectionCore.mqh"
JTC_TURN_DIRECTION_STATE g_turn_direction_state;
void JTC_TurnDirectionProcess(const MqlRates &r[],const double &base[],
                              const bool historical_replay)
{
   g_assist_state.turn_direction_valid=false;
   g_assist_state.turn_direction_signal=false;
   g_assist_state.turn_direction_side=0;
   g_assist_state.turn_direction_bar=0;
   g_assist_state.turn_direction_owner_side=g_turn_direction_state.owner_side;
   g_assist_state.turn_direction_reason="NOT_READY";
   if(!InpTurnPreEnabled || AUTO_TF!=PERIOD_M3 || ArraySize(r)<3 || ArraySize(base)<3) return;
   const datetime bar=r[1].time;
   const bool valid=g_assist_state.turn_pre_data_valid && r[1].time-r[2].time==180 &&
      JTC_TurnFinite(base[1]) && JTC_TurnFinite(base[2]);
   const int owner=g_assist_state.turn_pre_signal ? g_assist_state.turn_pre_side : 0;
   const int side=JTC_TurnDirectionDecide(g_turn_direction_state,bar,valid,owner,
      r[1].close,r[2].close,r[1].high,r[2].high,r[1].low,r[2].low,base[1],base[2]);
   g_assist_state.turn_direction_valid=valid;
   g_assist_state.turn_direction_signal=(side!=0);
   g_assist_state.turn_direction_side=side;
   g_assist_state.turn_direction_bar=bar;
   g_assist_state.turn_direction_owner_side=g_turn_direction_state.owner_side;
   g_assist_state.turn_direction_reason=!valid ? "INVALID_OR_GAP" :
      (owner!=0 ? "TURN_LEG_START" : (side!=0 ? "DIRECTION_OFF_ON_PROGRESS" : "NO_NEW_DIRECTION"));
   if(side==0 || !InpTurnShowChart || _Period!=PERIOD_M3 ||
      (historical_replay && iBarShift(_Symbol,PERIOD_M3,bar,false)>InpTurnChartHistoryBars)) return;
   const string name="JTC_TURN284_EA_"+IntegerToString((long)InpMagicNumber)+"_DIR_"+IntegerToString((long)bar);
   const double offset=MathMax(_Point*10.0,g_assist_state.turn_pre_atr14*0.25);
   if(ObjectFind(0,name)<0 && ObjectCreate(0,name,OBJ_ARROW,0,bar,side>0 ? r[1].low-offset : r[1].high+offset))
   {
      ObjectSetInteger(0,name,OBJPROP_ARROWCODE,side>0 ? 241 : 242);
      ObjectSetInteger(0,name,OBJPROP_COLOR,side>0 ? clrDeepSkyBlue : clrOrange);
      ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);
      ObjectSetString(0,name,OBJPROP_TOOLTIP,"TURN DIRECTION ADD CANDIDATE | AVAILABLE AFTER "+TimeToString(bar+180,TIME_DATE|TIME_SECONDS));
   }
}
#endif
