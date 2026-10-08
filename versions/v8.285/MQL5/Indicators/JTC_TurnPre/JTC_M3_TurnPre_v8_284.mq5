#property strict
#property version "8.284"
#property indicator_chart_window
#property indicator_buffers 4
#property indicator_plots 4
#property indicator_label1 "TURN PRE LONG (confirmation bar)"
#property indicator_type1 DRAW_ARROW
#property indicator_color1 clrLimeGreen
#property indicator_width1 2
#property indicator_label2 "TURN PRE SHORT (confirmation bar)"
#property indicator_type2 DRAW_ARROW
#property indicator_color2 clrTomato
#property indicator_width2 2
#property indicator_label3 "LOW anchor (known after NEXT bar close)"
#property indicator_type3 DRAW_ARROW
#property indicator_color3 clrSilver
#property indicator_label4 "HIGH anchor (known after NEXT bar close)"
#property indicator_type4 DRAW_ARROW
#property indicator_color4 clrSilver
#property tester_indicator "Market\\Joon_MACD_v2_05_OPT_VALIDATION.ex5"
#property tester_indicator "Market\\Joon_delta_volume_v1_01_OPT_VALIDATION.ex5"
#include "TurnCore.mqh"
input int InpTurnLeftBars=6;
input bool InpTurnRequireDivergence=true;
input double InpTurnMinReboundATR=0.15;
input double InpTurnMaxDistanceATR=1.25;
input double InpTurnMomentumDeadzoneATR=0.01;
input int InpTurnSameSideCooldownBars=3;
input bool InpTurnShowPivotAnchors=true;
input int InpHistoryBars=3000;
double LongArrow[],ShortArrow[],LowAnchor[],HighAnchor[];
int g_turn_macd=INVALID_HANDLE,g_turn_delta=INVALID_HANDLE;
datetime g_turn_forming_bar=0;
int OnInit()
{
   if(_Period!=PERIOD_M3 || InpTurnLeftBars<2 || InpTurnLeftBars>12 ||
      InpTurnMinReboundATR<0.0 || InpTurnMaxDistanceATR<InpTurnMinReboundATR ||
      InpTurnMomentumDeadzoneATR<0.0 || InpTurnSameSideCooldownBars<1 ||
      InpTurnSameSideCooldownBars>100 || InpHistoryBars<100 || InpHistoryBars>20000)
   {Print("JTC TurnPre: M3 chart and valid input parameters required");return INIT_PARAMETERS_INCORRECT;}
   SetIndexBuffer(0,LongArrow,INDICATOR_DATA); ArraySetAsSeries(LongArrow,true);
   SetIndexBuffer(1,ShortArrow,INDICATOR_DATA); ArraySetAsSeries(ShortArrow,true);
   SetIndexBuffer(2,LowAnchor,INDICATOR_DATA); ArraySetAsSeries(LowAnchor,true);
   SetIndexBuffer(3,HighAnchor,INDICATOR_DATA); ArraySetAsSeries(HighAnchor,true);
   PlotIndexSetInteger(0,PLOT_ARROW,233); PlotIndexSetInteger(1,PLOT_ARROW,234);
   PlotIndexSetInteger(2,PLOT_ARROW,159); PlotIndexSetInteger(3,PLOT_ARROW,159);
   for(int k=0;k<4;k++) PlotIndexSetDouble(k,PLOT_EMPTY_VALUE,EMPTY_VALUE);
   IndicatorSetString(INDICATOR_SHORTNAME,"JTC M3 TURN PRE 8.284 (closed-bar)");
   g_turn_macd=iCustom(_Symbol,PERIOD_M3,"Market\\Joon_MACD_v2_05_OPT_VALIDATION");
   g_turn_delta=iCustom(_Symbol,PERIOD_M3,"Market\\Joon_delta_volume_v1_01_OPT_VALIDATION");
   if(g_turn_macd==INVALID_HANDLE || g_turn_delta==INVALID_HANDLE)
   {
      Print("JTC TurnPre: compile/install both supplied Market indicators first");
      if(g_turn_macd!=INVALID_HANDLE) IndicatorRelease(g_turn_macd);
      if(g_turn_delta!=INVALID_HANDLE) IndicatorRelease(g_turn_delta);
      g_turn_macd=INVALID_HANDLE;g_turn_delta=INVALID_HANDLE;
      return INIT_FAILED;
   }
   return INIT_SUCCEEDED;
}
void OnDeinit(const int reason)
{
   if(g_turn_macd!=INVALID_HANDLE) IndicatorRelease(g_turn_macd);
   if(g_turn_delta!=INVALID_HANDLE) IndicatorRelease(g_turn_delta);
}
int OnCalculate(const int rates_total,const int prev_calculated,
                const datetime &time[],const double &open[],const double &high[],
                const double &low[],const double &close[],const long &tick_volume[],
                const long &volume[],const int &spread[])
{
   ArraySetAsSeries(time,true);
   if(prev_calculated<=0)
   {
      ArrayInitialize(LongArrow,EMPTY_VALUE);ArrayInitialize(ShortArrow,EMPTY_VALUE);
      ArrayInitialize(LowAnchor,EMPTY_VALUE);ArrayInitialize(HighAnchor,EMPTY_VALUE);
   }
   if(rates_total>0)
   {LongArrow[0]=EMPTY_VALUE;ShortArrow[0]=EMPTY_VALUE;LowAnchor[0]=EMPTY_VALUE;HighAnchor[0]=EMPTY_VALUE;}
   if(rates_total<100) return 0;
   if(prev_calculated>0 && rates_total==prev_calculated && g_turn_forming_bar==time[0])
      return rates_total;
   const int count=MathMin(rates_total,InpHistoryBars+200);
   if(BarsCalculated(g_turn_macd)<count || BarsCalculated(g_turn_delta)<count)
      return prev_calculated;
   MqlRates r[]; double raw[],wave[],delta[],ema[],vol[];
   ArraySetAsSeries(r,true); ArraySetAsSeries(raw,true); ArraySetAsSeries(wave,true);
   ArraySetAsSeries(delta,true); ArraySetAsSeries(ema,true); ArraySetAsSeries(vol,true);
   if(CopyRates(_Symbol,PERIOD_M3,0,count,r)!=count ||
      CopyBuffer(g_turn_macd,5,0,count,raw)!=count ||
      CopyBuffer(g_turn_macd,6,0,count,wave)!=count ||
      CopyBuffer(g_turn_delta,2,0,count,delta)!=count ||
      CopyBuffer(g_turn_delta,3,0,count,ema)!=count ||
      CopyBuffer(g_turn_delta,4,0,count,vol)!=count || r[0].time!=time[0])
      return prev_calculated;
   ArrayInitialize(LongArrow,EMPTY_VALUE);ArrayInitialize(ShortArrow,EMPTY_VALUE);
   ArrayInitialize(LowAnchor,EMPTY_VALUE);ArrayInitialize(HighAnchor,EMPTY_VALUE);
   datetime last_long=0,last_short=0;
   // Rebuild only once per newly opened bar. Extra history seeds cooldown.
   for(int shift=count-15;shift>=1;shift--)
   {
      JTC_TURN_FRAME f; JTC_TURN_RESULT q;
      JTC_TurnBuildFrame(r,raw,wave,delta,ema,vol,shift,InpTurnLeftBars,f);
      JTC_TurnDecide(f,InpTurnRequireDivergence,InpTurnMinReboundATR,
         InpTurnMaxDistanceATR,InpTurnMomentumDeadzoneATR,q);
      if(q.side==0 || !JTC_TurnEmit(f.bar_time,q.side,InpTurnSameSideCooldownBars,last_long,last_short)) continue;
      if(shift>InpHistoryBars) continue;
      if(q.side>0)
      {
         LongArrow[shift]=f.low_price-f.atr14*0.12;
         if(InpTurnShowPivotAnchors) LowAnchor[shift+1]=q.pivot_price;
      }
      else
      {
         ShortArrow[shift]=f.high_price+f.atr14*0.12;
         if(InpTurnShowPivotAnchors) HighAnchor[shift+1]=q.pivot_price;
      }
   }
   // Bar 0 never contains a new arrow. Anchors are annotations, not entries.
   g_turn_forming_bar=time[0];
   return rates_total;
}
