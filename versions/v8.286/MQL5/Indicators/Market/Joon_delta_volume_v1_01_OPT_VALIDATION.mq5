//+------------------------------------------------------------------+
//|                  Joon_delta_volume_v1_01.mq5                      |
//|    Volume Delta-style histogram based on candle pressure + EMA    |
//|    Install: MQL5\Indicators\Market                                |
//+------------------------------------------------------------------+
#property copyright "Joon"
#property version   "1.01"
#property strict

#property indicator_separate_window
#property indicator_buffers 5
#property indicator_plots   1

#property indicator_label1  "Volume Delta EMA"
#property indicator_type1   DRAW_COLOR_HISTOGRAM
#property indicator_color1  clrGreen, clrRed
#property indicator_style1  STYLE_SOLID
#property indicator_width1  3

#property indicator_level1  0.0
#property indicator_levelcolor clrGray
#property indicator_levelstyle STYLE_DOT
#property indicator_levelwidth 1

input group "Calculation"
input int    InpEMAPeriod        = 14;
input double InpCloseWeight      = 0.70;
input double InpBodyWeight       = 0.30;
input bool   InpUseRealVolume    = false;

input group "Display"
input double InpScale            = 1.00;
input int    InpHistogramWidth   = 3;

// Buffer 0: visible EMA delta
// Buffer 1: color index, 0=green / 1=red
// Buffer 2: raw delta
// Buffer 3: unscaled EMA delta for EA
// Buffer 4: source volume
double DisplayBuffer[];
double ColorBuffer[];
double RawDeltaBuffer[];
double EmaDeltaBuffer[];
double SourceVolumeBuffer[];

//+------------------------------------------------------------------+
double ClampValue(const double value,
                  const double minimum,
                  const double maximum)
{
   return MathMax(minimum, MathMin(maximum, value));
}

//+------------------------------------------------------------------+
//| Estimate buy/sell pressure from candle structure                 |
//| Returns a value in the range -1.0 to +1.0                        |
//+------------------------------------------------------------------+
double CalculatePressure(const double open_price,
                         const double high_price,
                         const double low_price,
                         const double close_price)
{
   const double range = high_price - low_price;

   if(range <= 0.0)
      return 0.0;

   // Close Location Value:
   // +1 when close is at the high, -1 when close is at the low.
   const double close_location =
      (2.0 * close_price - high_price - low_price) / range;

   // Candle body direction and size relative to full range.
   const double body_pressure =
      (close_price - open_price) / range;

   const double close_weight = MathMax(0.0, InpCloseWeight);
   const double body_weight  = MathMax(0.0, InpBodyWeight);
   const double weight_sum   = close_weight + body_weight;

   if(weight_sum <= 0.0)
      return 0.0;

   const double pressure =
      (close_location * close_weight +
       body_pressure  * body_weight) /
      weight_sum;

   return ClampValue(pressure, -1.0, 1.0);
}

//+------------------------------------------------------------------+
double SelectVolume(const int index,
                    const long &tick_volume[],
                    const long &real_volume[])
{
   if(InpUseRealVolume && real_volume[index] > 0)
      return (double)real_volume[index];

   return (double)MathMax((long)0, tick_volume[index]);
}

//+------------------------------------------------------------------+
void CalculateEMA(const int rates_total,
                  const int calculate_from,
                  const bool full_rebuild)
{
   const double alpha =
      2.0 / ((double)InpEMAPeriod + 1.0);

   if(full_rebuild)
   {
      const int oldest = rates_total - 1;
      EmaDeltaBuffer[oldest] = RawDeltaBuffer[oldest];
      for(int i = oldest - 1; i >= 0; i--)
      {
         EmaDeltaBuffer[i] =
            alpha * RawDeltaBuffer[i] +
            (1.0 - alpha) * EmaDeltaBuffer[i + 1];
      }
      return;
   }

   // Indicator buffers are terminal-managed time series, so the already
   // calculated value at calculate_from+1 is a valid recursive seed.
   const int start = MathMin(calculate_from, rates_total - 2);
   for(int i = start; i >= 0; i--)
   {
      EmaDeltaBuffer[i] =
         alpha * RawDeltaBuffer[i] +
         (1.0 - alpha) * EmaDeltaBuffer[i + 1];
   }
}

//+------------------------------------------------------------------+
void FillDisplay(const int rates_total,
                 const int calculate_from,
                 const bool full_rebuild)
{
   const double scale =
      MathMax(0.0001, InpScale);

   const int start =
      (full_rebuild ? rates_total - 1 : MathMin(calculate_from, rates_total - 1));

   for(int i = start; i >= 0; i--)
   {
      const double value =
         EmaDeltaBuffer[i] * scale;

      DisplayBuffer[i] = value;
      ColorBuffer[i]   = (value >= 0.0 ? 0.0 : 1.0);
   }
}

//+------------------------------------------------------------------+
int OnInit()
{
   if(InpEMAPeriod < 1 ||
      InpScale <= 0.0 ||
      InpHistogramWidth < 1)
   {
      return INIT_PARAMETERS_INCORRECT;
   }

   SetIndexBuffer(0, DisplayBuffer, INDICATOR_DATA);
   SetIndexBuffer(1, ColorBuffer, INDICATOR_COLOR_INDEX);
   SetIndexBuffer(2, RawDeltaBuffer, INDICATOR_CALCULATIONS);
   SetIndexBuffer(3, EmaDeltaBuffer, INDICATOR_CALCULATIONS);
   SetIndexBuffer(4, SourceVolumeBuffer, INDICATOR_CALCULATIONS);

   ArraySetAsSeries(DisplayBuffer, true);
   ArraySetAsSeries(ColorBuffer, true);
   ArraySetAsSeries(RawDeltaBuffer, true);
   ArraySetAsSeries(EmaDeltaBuffer, true);
   ArraySetAsSeries(SourceVolumeBuffer, true);

   PlotIndexSetInteger(0, PLOT_LINE_WIDTH, InpHistogramWidth);
   PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, 0.0);

   IndicatorSetString(
      INDICATOR_SHORTNAME,
      "Joon Volume Delta (EMA" +
      IntegerToString(InpEMAPeriod) +
      ") v1.01"
   );

   IndicatorSetInteger(INDICATOR_DIGITS, 3);

   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
{
   if(rates_total < InpEMAPeriod + 5)
      return 0;

   ArraySetAsSeries(open, true);
   ArraySetAsSeries(high, true);
   ArraySetAsSeries(low, true);
   ArraySetAsSeries(close, true);
   ArraySetAsSeries(tick_volume, true);
   ArraySetAsSeries(volume, true);

   int calculate_from;
   const bool full_rebuild =
      (prev_calculated <= 0 || prev_calculated > rates_total);

   if(full_rebuild)
   {
      ArrayInitialize(DisplayBuffer, 0.0);
      ArrayInitialize(ColorBuffer, 0.0);
      ArrayInitialize(RawDeltaBuffer, 0.0);
      ArrayInitialize(EmaDeltaBuffer, 0.0);
      ArrayInitialize(SourceVolumeBuffer, 0.0);

      calculate_from = rates_total - 1;
   }
   else
   {
      calculate_from =
         MathMin(rates_total - 1,
                 rates_total - prev_calculated + InpEMAPeriod + 2);
   }

   for(int i = calculate_from; i >= 0; i--)
   {
      const double source_volume =
         SelectVolume(i, tick_volume, volume);

      const double pressure =
         CalculatePressure(open[i],
                           high[i],
                           low[i],
                           close[i]);

      SourceVolumeBuffer[i] = source_volume;
      RawDeltaBuffer[i]     = source_volume * pressure;
   }

   CalculateEMA(rates_total, calculate_from, full_rebuild);
   FillDisplay(rates_total, calculate_from, full_rebuild);

   return rates_total;
}
//+------------------------------------------------------------------+
