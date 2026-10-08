//+------------------------------------------------------------------+
//| PatternLearningEngine.mqh                                        |
//| Chart-pattern recognition and future learning-data integration   |
//+------------------------------------------------------------------+
#ifndef __JOON_PATTERNLEARNINGENGINE_MQH__
#define __JOON_PATTERNLEARNINGENGINE_MQH__


//+------------------------------------------------------------------+
bool EvaluatePatternLifecycleAssist(const int side,
                                    bool &quality_pullback,
                                    bool &delta_absorption,
                                    bool &trend_fatigue,
                                    bool &compression_release,
                                    int &ma7_bounce_count,
                                    string &detail)
{
   quality_pullback = false;
   delta_absorption = false;
   trend_fatigue = false;
   compression_release = false;
   ma7_bounce_count = 0;
   detail = "";
   if(!InpUsePatternLifecycleAssist || side == 0)
      return false;

   const int count = MathMax(8, InpPatternLifecycleLookback);
   if(!EnsureMarketSnapshot(count + 2))
      return false;

   double avg_abs_delta = 0.0;
   double recent_range = 0.0;
   double older_range = 0.0;
   int recent_n = 0, older_n = 0;
   for(int i = 1; i <= count; i++)
   {
      avg_abs_delta += MathAbs(g_ms_delta[i]);
      const double bar_range = MathMax(g_ms_rates[i].high - g_ms_rates[i].low, _Point);
      if(i <= 3) { recent_range += bar_range; recent_n++; }
      else       { older_range += bar_range; older_n++; }

      const double tolerance = bar_range * 0.20;
      if(side > 0 && g_ms_rates[i].low <= g_ms_fast_ma[i] + tolerance &&
         g_ms_rates[i].close >= g_ms_fast_ma[i])
         ma7_bounce_count++;
      if(side < 0 && g_ms_rates[i].high >= g_ms_fast_ma[i] - tolerance &&
         g_ms_rates[i].close <= g_ms_fast_ma[i])
         ma7_bounce_count++;
   }
   avg_abs_delta /= MathMax(1, count);
   recent_range /= MathMax(1, recent_n);
   older_range /= MathMax(1, older_n);

   // Good pullback: fast MA tested, slow MA preserved, then fast MA recovered,
   // without an extreme opposite delta impulse.
   bool fast_touched = false;
   bool slow_preserved = true;
   for(int i = 2; i <= MathMin(count, 6); i++)
   {
      const double bar_range = MathMax(g_ms_rates[i].high - g_ms_rates[i].low, _Point);
      const double tolerance = bar_range * 0.25;
      if(side > 0)
      {
         if(g_ms_rates[i].low <= g_ms_fast_ma[i] + tolerance) fast_touched = true;
         if(g_ms_rates[i].close < g_ms_slow_ma[i] - tolerance) slow_preserved = false;
      }
      else
      {
         if(g_ms_rates[i].high >= g_ms_fast_ma[i] - tolerance) fast_touched = true;
         if(g_ms_rates[i].close > g_ms_slow_ma[i] + tolerance) slow_preserved = false;
      }
   }
   const bool fast_recovered = side > 0 ? g_ms_rates[1].close >= g_ms_fast_ma[1]
                                        : g_ms_rates[1].close <= g_ms_fast_ma[1];
   const bool extreme_opposite_delta = side > 0 ?
      g_ms_delta[1] < -avg_abs_delta * MathMax(1.0, InpPatternOppositeDeltaExtreme) :
      g_ms_delta[1] >  avg_abs_delta * MathMax(1.0, InpPatternOppositeDeltaExtreme);
   quality_pullback = fast_touched && slow_preserved && fast_recovered &&
                      !extreme_opposite_delta;

   // Opposite delta with little price response is absorption, not automatic
   // trend failure. Wick rejection and fast-MA preservation confirm it.
   const double body1 = MathAbs(g_ms_rates[1].close - g_ms_rates[1].open);
   const double range1 = MathMax(g_ms_rates[1].high - g_ms_rates[1].low, _Point);
   const double upper_wick1 = g_ms_rates[1].high - MathMax(g_ms_rates[1].open, g_ms_rates[1].close);
   const double lower_wick1 = MathMin(g_ms_rates[1].open, g_ms_rates[1].close) - g_ms_rates[1].low;
   if(side > 0)
      delta_absorption = g_ms_delta[1] < 0.0 && g_ms_rates[1].close >= g_ms_fast_ma[1] &&
                         (lower_wick1 >= body1 || body1 / range1 < 0.35);
   else
      delta_absorption = g_ms_delta[1] > 0.0 && g_ms_rates[1].close <= g_ms_fast_ma[1] &&
                         (upper_wick1 >= body1 || body1 / range1 < 0.35);

   // Fatigue requires price progress while both MACD magnitude and same-side
   // delta participation weaken. This avoids reacting to a single soft bar.
   const bool price_progress = side > 0 ? g_ms_rates[1].close > g_ms_rates[3].close
                                        : g_ms_rates[1].close < g_ms_rates[3].close;
   const bool macd_weaker = MathAbs(g_ms_macd[1]) < MathAbs(g_ms_macd[2]) &&
                            MathAbs(g_ms_macd[2]) <= MathAbs(g_ms_macd[3]);
   double same_delta1 = side > 0 ? MathMax(g_ms_delta[1], 0.0) : MathMax(-g_ms_delta[1], 0.0);
   double same_delta2 = side > 0 ? MathMax(g_ms_delta[2], 0.0) : MathMax(-g_ms_delta[2], 0.0);
   double same_delta3 = side > 0 ? MathMax(g_ms_delta[3], 0.0) : MathMax(-g_ms_delta[3], 0.0);
   const bool delta_weaker = same_delta1 < same_delta2 && same_delta2 <= same_delta3;
   trend_fatigue = price_progress && macd_weaker && delta_weaker &&
                   !delta_absorption;

   // Compression release supports continuation only after a genuine smaller
   // range cluster followed by a directional expansion bar.
   const bool compressed = older_range > 0.0 &&
      recent_range <= older_range * MathMax(0.30, MathMin(0.95, InpPatternCompressionRatio));
   const bool expansion_bar = range1 >= recent_range * 1.20 &&
      (side > 0 ? g_ms_rates[1].close > g_ms_rates[1].open : g_ms_rates[1].close < g_ms_rates[1].open);
   const bool same_side_macd = side > 0 ? g_ms_macd[1] > g_ms_macd[2] : g_ms_macd[1] < g_ms_macd[2];
   const bool same_side_delta = side > 0 ? g_ms_delta[1] > 0.0 : g_ms_delta[1] < 0.0;
   compression_release = compressed && expansion_bar && same_side_macd && same_side_delta;

   detail = StringFormat("PB%d ABS%d FAT%d CMP%d BNC%d",
                         quality_pullback ? 1 : 0,
                         delta_absorption ? 1 : 0,
                         trend_fatigue ? 1 : 0,
                         compression_release ? 1 : 0,
                         ma7_bounce_count);
   return true;
}

//+------------------------------------------------------------------+
bool CandlePatternState(const ENUM_TIMEFRAMES tf,
                        const int side,
                        bool &rejection,
                        bool &engulfing,
                        bool &favourable_edge,
                        bool &opposite_edge)
{
   rejection = false;
   engulfing = false;
   favourable_edge = false;
   opposite_edge = false;

   const int lookback = MathMax(5, InpPatternRangeLookback);

   // v7.61 performance: LONG and SHORT pattern evaluation on the same closed
   // bar uses identical range/OHLC inputs. Cache those common primitives once
   // per symbol/timeframe/closed bar instead of repeating the full iHigh/iLow
   // lookback for each side.
   static string cache_symbol="";
   static ENUM_TIMEFRAMES cache_tf=PERIOD_CURRENT;
   static datetime cache_bar=0;
   static int cache_lookback=0;
   static bool cache_valid=false;
   static double cache_range_high=0.0,cache_range_low=0.0;
   static double cache_o1=0.0,cache_h1=0.0,cache_l1=0.0,cache_c1=0.0;
   static double cache_o2=0.0,cache_c2=0.0;

   const datetime closed_bar=iTime(_Symbol,tf,1);
   const bool cache_match=
      cache_valid &&
      cache_symbol==_Symbol &&
      cache_tf==tf &&
      cache_bar==closed_bar &&
      cache_lookback==lookback;

   if(!cache_match)
   {
      cache_valid=false;
      cache_symbol=_Symbol;
      cache_tf=tf;
      cache_bar=closed_bar;
      cache_lookback=lookback;

      if(closed_bar<=0)
         return false;

      double range_high = iHigh(_Symbol, tf, 2);
      double range_low  = iLow(_Symbol, tf, 2);
      if(range_high <= 0.0 || range_low <= 0.0)
         return false;

      for(int i = 3; i <= lookback + 1; i++)
      {
         range_high = MathMax(range_high, iHigh(_Symbol, tf, i));
         range_low  = MathMin(range_low,  iLow(_Symbol, tf, i));
      }

      cache_range_high=range_high;
      cache_range_low=range_low;
      cache_o1=iOpen(_Symbol,tf,1);
      cache_h1=iHigh(_Symbol,tf,1);
      cache_l1=iLow(_Symbol,tf,1);
      cache_c1=iClose(_Symbol,tf,1);
      cache_o2=iOpen(_Symbol,tf,2);
      cache_c2=iClose(_Symbol,tf,2);
      cache_valid=true;
   }

   const double range_high=cache_range_high;
   const double range_low=cache_range_low;
   const double box = range_high - range_low;
   if(box <= _Point)
      return false;

   const double o1=cache_o1;
   const double h1=cache_h1;
   const double l1=cache_l1;
   const double c1=cache_c1;
   const double o2=cache_o2;
   const double c2=cache_c2;
   const double candle_range = h1 - l1;
   if(candle_range <= _Point)
      return true;

   const double body = MathAbs(c1 - o1);
   const double safe_body = MathMax(body, _Point);
   const double upper_wick = h1 - MathMax(o1, c1);
   const double lower_wick = MathMin(o1, c1) - l1;
   const double body_ratio = body / candle_range;
   const double location = (c1 - range_low) / box;
   const double edge = MathMax(0.05, MathMin(0.45, InpRangeEdgeZone));

   if(side > 0)
   {
      favourable_edge = location <= edge || l1 <= range_low + box * edge;
      opposite_edge = location >= 1.0 - edge;
      rejection = InpAllowRejectionPattern && favourable_edge && c1 > o1 &&
                  lower_wick >= safe_body * InpRejectionWickBodyRatio &&
                  body_ratio >= InpMinimumPatternBodyRatio;
      engulfing = InpAllowEngulfingPattern && c1 > o1 && c2 < o2 &&
                  o1 <= c2 && c1 >= o2;
   }
   else
   {
      favourable_edge = location >= 1.0 - edge || h1 >= range_high - box * edge;
      opposite_edge = location <= edge;
      rejection = InpAllowRejectionPattern && favourable_edge && c1 < o1 &&
                  upper_wick >= safe_body * InpRejectionWickBodyRatio &&
                  body_ratio >= InpMinimumPatternBodyRatio;
      engulfing = InpAllowEngulfingPattern && c1 < o1 && c2 > o2 &&
                  o1 >= c2 && c1 <= o2;
   }
   return true;
}

//+------------------------------------------------------------------+
bool RangePatternAllows(const ENUM_TIMEFRAMES tf,
                        const int side,
                        string &pattern_name)
{
   pattern_name = "MOMENTUM";
   if(!InpUseRangePatternFilter)
      return true;

   bool rejection = false, engulfing = false;
   bool favourable_edge = false, opposite_edge = false;
   if(!CandlePatternState(tf, side, rejection, engulfing,
                         favourable_edge, opposite_edge))
      return false;

   if(InpBlockOppositeRangeEdge && opposite_edge &&
      !rejection && !engulfing)
      return false;

   if(rejection)
      pattern_name = "RANGE REJECTION";
   else if(engulfing)
      pattern_name = "ENGULFING";
   else if(favourable_edge)
      pattern_name = "RANGE EDGE";
   else
      pattern_name = "RANGE MID MOMENTUM";
   return true;
}


//+------------------------------------------------------------------+
// Captures one closed-bar feature row. External image analysis or offline
// learning results should be converted into features/weights consumed here;
// image files themselves are not interpreted inside MT5.
void PatternLearningCaptureClosedBar(const string source_tag)
{
   if(!InpEnablePatternDatasetExport && !InpEnableSignalDatasetExport)
      return;
   if(!EnsureMarketSnapshot(MathMax(8, InpPatternLifecycleLookback) + 2))
      return;

   bool bull_rejection=false, bull_engulfing=false;
   bool bull_edge=false, bull_opposite=false;
   bool bear_rejection=false, bear_engulfing=false;
   bool bear_edge=false, bear_opposite=false;
   CandlePatternState(g_calc_tf, 1, bull_rejection, bull_engulfing,
                      bull_edge, bull_opposite);
   CandlePatternState(g_calc_tf, -1, bear_rejection, bear_engulfing,
                      bear_edge, bear_opposite);

   int side = 0;
   string pattern = "NONE";
   if(bull_rejection)      { side=1;  pattern="BULL_REJECTION"; }
   else if(bull_engulfing) { side=1;  pattern="BULL_ENGULFING"; }
   else if(bear_rejection) { side=-1; pattern="BEAR_REJECTION"; }
   else if(bear_engulfing) { side=-1; pattern="BEAR_ENGULFING"; }
   else if(bull_edge)      { side=1;  pattern="BULL_RANGE_EDGE"; }
   else if(bear_edge)      { side=-1; pattern="BEAR_RANGE_EDGE"; }

   ExportPatternLearningSample(g_ms_rates[1].time, g_calc_tf,
      g_ms_rates[1].open, g_ms_rates[1].high, g_ms_rates[1].low,
      g_ms_rates[1].close, g_ms_fast_ma[1], g_ms_slow_ma[1],
      g_ms_macd[1], g_ms_delta[1], side, pattern, source_tag);

   ExportSignalLearningSample(g_ms_rates[1].time, g_calc_tf,
      g_ms_rates[1].open, g_ms_rates[1].high, g_ms_rates[1].low,
      g_ms_rates[1].close, g_ms_fast_ma[1], g_ms_slow_ma[1],
      g_ms_macd[1], g_ms_delta[1], side, pattern, source_tag);
}

#endif // __JOON_PATTERNLEARNINGENGINE_MQH__
