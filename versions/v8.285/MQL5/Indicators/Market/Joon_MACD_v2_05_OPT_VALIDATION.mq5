//+------------------------------------------------------------------+
//|                       Joon_MACD_v2_05.mq5                        |
//| Price MACD + internal buy/sell pressure color confirmation       |
//|                                                                  |
//| Wave shape       : Price MACD                                    |
//| Green / Red      : Buy/Sell pressure direction                   |
//| Zero-line bias   : Slow price trend + cumulative pressure        |
//|                                                                  |
//| Buffer 0 = Final MACD Wave                                       |
//| Buffer 1 = Color Index (0 green / 1 red)                         |
//| Buffer 2 = Signal Line                                           |
//| Buffer 3 = Direction State (1 buy / -1 sell / 0 neutral)         |
//| Buffer 4 = Zero State (1 bullish / -1 bearish / 0 neutral)       |
//| Buffer 5 = Raw Price MACD                                        |
//| Buffer 6 = Unscaled Final Wave (EA calculation)                  |
//| Buffer 7 = Unscaled Signal Line (EA calculation)                 |
//+------------------------------------------------------------------+
#property copyright "Joon"
#property version   "2.05"
#property strict

#property indicator_separate_window
#property indicator_buffers 8
#property indicator_plots   7

#property indicator_label1  "Joon MACD"
#property indicator_type1   DRAW_COLOR_HISTOGRAM
#property indicator_color1  clrLimeGreen,clrRed
#property indicator_style1  STYLE_SOLID
#property indicator_width1  2

#property indicator_label2  "Signal"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrSilver
#property indicator_style2  STYLE_SOLID
#property indicator_width2  2

#property indicator_label3  "Direction State"
#property indicator_type3   DRAW_NONE

#property indicator_label4  "Zero State"
#property indicator_type4   DRAW_NONE

#property indicator_label5  "Raw Price MACD"
#property indicator_type5   DRAW_NONE

#property indicator_label6  "Unscaled Final Wave"
#property indicator_type6   DRAW_NONE

#property indicator_label7  "Unscaled Signal"
#property indicator_type7   DRAW_NONE

#property indicator_level1  0.0
#property indicator_levelcolor clrDimGray
#property indicator_levelstyle STYLE_DOT
#property indicator_levelwidth 1


input group "Price MACD"
input int InpFastEMA   = 12;
input int InpSlowEMA   = 26;
input int InpSignalEMA = 9;
input ENUM_APPLIED_PRICE InpAppliedPrice = PRICE_CLOSE;

input group "Buy Sell Pressure"
input int    InpPressureFastEMA   = 5;
input int    InpPressureSlowEMA   = 21;
input double InpCloseWeight       = 0.70;
input double InpBodyWeight        = 0.30;
input bool   InpUseRealVolume     = false;

input group "Color Logic"
input double InpBuyThreshold       = 0.10;
input double InpSellThreshold      = -0.10;
input double InpExitThreshold      = 0.03;
input int    InpColorConfirmBars   = 2;
input bool   InpUseMACDDirection   = true;
input bool   InpKeepPreviousColor  = true;

input group "Zero Line Bias"
input int    InpTrendEMA          = 22;
input int    InpBalanceEMA        = 34;
input int    InpATRPeriod         = 14;
input double InpPriceBiasWeight   = 0.65;
input double InpVolumeBiasWeight  = 0.35;
input double InpBiasStrengthATR   = 0.30;

input group "Signal Smoothing"
input int    InpSignalSmoothing2  = 5;
input double InpSignalDeadZoneATR = 0.03;

input group "Display"
input int    InpWaveSmoothing     = 2;
input int    InpAutoScalePeriod   = 50;
input double InpAutoTargetHeight  = 250.0;
input double InpAutoScaleMin      = 0.05;
input double InpAutoScaleMax      = 1000000.0;
input int    InpHistogramWidth    = 2;

//--- output buffers
double FinalWaveBuffer[];
double ColorIndexBuffer[];
double SignalBuffer[];
double DirectionStateBuffer[];
double ZeroStateBuffer[];
double RawMACDBuffer[];
double UnscaledFinalWaveBuffer[];
double UnscaledSignalBuffer[];

//--- internal arrays
double FastPriceEMA[];
double SlowPriceEMA[];
double TrendEMAArray[];
double SmoothedMACD[];
double FinalWaveRaw[];
double SignalRaw[];
double SignalSmooth2[];
double AutoAmplitudeEMA[];
double AutoScaleEMA[];
double ATRArray[];

double BuyPressureArray[];
double SellPressureArray[];
double FastPressureEMA[];
double SlowPressureEMA[];
double BalanceEMAArray[];
double PressureDirectionArray[];
double PressureBalanceArray[];

//+------------------------------------------------------------------+
double Clamp(const double value,
             const double minimum,
             const double maximum)
{
   return MathMax(minimum, MathMin(maximum, value));
}

//+------------------------------------------------------------------+
double GetAppliedPrice(const int index,
                       const double &open[],
                       const double &high[],
                       const double &low[],
                       const double &close[])
{
   switch(InpAppliedPrice)
   {
      case PRICE_OPEN:
         return open[index];
      case PRICE_HIGH:
         return high[index];
      case PRICE_LOW:
         return low[index];
      case PRICE_MEDIAN:
         return (high[index] + low[index]) / 2.0;
      case PRICE_TYPICAL:
         return (high[index] + low[index] + close[index]) / 3.0;
      case PRICE_WEIGHTED:
         return (high[index] + low[index] + 2.0 * close[index]) / 4.0;
      case PRICE_CLOSE:
      default:
         return close[index];
   }
}

//+------------------------------------------------------------------+
double GetVolumeValue(const int index,
                      const long &tick_volume[],
                      const long &real_volume[])
{
   if(InpUseRealVolume && real_volume[index] > 0)
      return (double)real_volume[index];

   return (double)MathMax((long)0, tick_volume[index]);
}

//+------------------------------------------------------------------+
void CalculateBuySellPressure(const int index,
                              const double &open[],
                              const double &high[],
                              const double &low[],
                              const double &close[],
                              const long &tick_volume[],
                              const long &real_volume[],
                              double &buy_pressure,
                              double &sell_pressure)
{
   const double total_volume =
      GetVolumeValue(index, tick_volume, real_volume);

   const double range =
      high[index] - low[index];

   if(total_volume <= 0.0 || range <= 0.0)
   {
      buy_pressure  = total_volume * 0.5;
      sell_pressure = total_volume * 0.5;
      return;
   }

   const double close_location =
      Clamp(
         (close[index] - low[index]) / range,
         0.0,
         1.0
      );

   const double body_component =
      Clamp(
         0.5 + 0.5 *
         (close[index] - open[index]) / range,
         0.0,
         1.0
      );

   const double close_weight =
      MathMax(0.0, InpCloseWeight);

   const double body_weight =
      MathMax(0.0, InpBodyWeight);

   const double weight_sum =
      MathMax(0.0001, close_weight + body_weight);

   const double buy_ratio =
      Clamp(
         (
            close_location * close_weight +
            body_component * body_weight
         ) / weight_sum,
         0.0,
         1.0
      );

   buy_pressure  = total_volume * buy_ratio;
   sell_pressure = total_volume * (1.0 - buy_ratio);
}


//+------------------------------------------------------------------+
void ResizeShiftSeries(double &arr[],
                       const int new_size,
                       const int shift)
{
   const int old_size = ArraySize(arr);
   ArrayResize(arr, new_size);
   ArraySetAsSeries(arr, true);

   if(shift <= 0 || old_size <= 0)
      return;

   const int capped_old = MathMin(old_size, new_size - shift);
   for(int i = capped_old - 1; i >= 0; i--)
      arr[i + shift] = arr[i];

   for(int i = 0; i < MathMin(shift, new_size); i++)
      arr[i] = 0.0;
}

//+------------------------------------------------------------------+
int OnInit()
{
   if(InpFastEMA < 1 ||
      InpSlowEMA <= InpFastEMA ||
      InpSignalEMA < 1 ||
      InpPressureFastEMA < 1 ||
      InpPressureSlowEMA <= InpPressureFastEMA ||
      InpTrendEMA < 1 ||
      InpBalanceEMA < 1 ||
      InpATRPeriod < 1 ||
      InpWaveSmoothing < 1 ||
      InpSignalSmoothing2 < 1 ||
      InpColorConfirmBars < 1 ||
      InpBuyThreshold <= InpExitThreshold ||
      InpSellThreshold >= -InpExitThreshold ||
      InpAutoScalePeriod < 2 ||
      InpAutoTargetHeight <= 0.0 ||
      InpAutoScaleMin <= 0.0 ||
      InpAutoScaleMax <= InpAutoScaleMin)
   {
      Print("Joon_MACD_v2_04: invalid parameters.");
      return INIT_PARAMETERS_INCORRECT;
   }

   SetIndexBuffer(0, FinalWaveBuffer, INDICATOR_DATA);
   SetIndexBuffer(1, ColorIndexBuffer, INDICATOR_COLOR_INDEX);
   SetIndexBuffer(2, SignalBuffer, INDICATOR_DATA);
   SetIndexBuffer(3, DirectionStateBuffer, INDICATOR_DATA);
   SetIndexBuffer(4, ZeroStateBuffer, INDICATOR_DATA);
   SetIndexBuffer(5, RawMACDBuffer, INDICATOR_DATA);
   SetIndexBuffer(6, UnscaledFinalWaveBuffer, INDICATOR_DATA);
   SetIndexBuffer(7, UnscaledSignalBuffer, INDICATOR_DATA);

   ArraySetAsSeries(FinalWaveBuffer, true);
   ArraySetAsSeries(ColorIndexBuffer, true);
   ArraySetAsSeries(SignalBuffer, true);
   ArraySetAsSeries(DirectionStateBuffer, true);
   ArraySetAsSeries(ZeroStateBuffer, true);
   ArraySetAsSeries(RawMACDBuffer, true);
   ArraySetAsSeries(UnscaledFinalWaveBuffer, true);
   ArraySetAsSeries(UnscaledSignalBuffer, true);

   PlotIndexSetInteger(
      0,
      PLOT_LINE_WIDTH,
      MathMax(1, MathMin(InpHistogramWidth, 5))
   );

   IndicatorSetString(
      INDICATOR_SHORTNAME,
      "Joon MACD v2.05"
   );

   IndicatorSetInteger(INDICATOR_DIGITS, 2);

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
   const int minimum_bars =
      MathMax(
         InpSlowEMA,
         MathMax(
            InpPressureSlowEMA,
            MathMax(
               InpBalanceEMA,
               MathMax(InpTrendEMA, InpATRPeriod)
            )
         )
      )
      + InpSignalEMA
      + InpWaveSmoothing
      + InpColorConfirmBars
      + 30;

   if(rates_total < minimum_bars)
      return 0;

   ArraySetAsSeries(open, true);
   ArraySetAsSeries(high, true);
   ArraySetAsSeries(low, true);
   ArraySetAsSeries(close, true);
   ArraySetAsSeries(tick_volume, true);
   ArraySetAsSeries(volume, true);

   const bool full_rebuild =
      (prev_calculated <= 0 || prev_calculated > rates_total ||
       ArraySize(FastPriceEMA) <= 0);

   const int new_bars =
      (full_rebuild ? 0 : MathMax(0, rates_total - prev_calculated));

   if(full_rebuild)
   {
      ResizeShiftSeries(FastPriceEMA, rates_total, 0);
      ResizeShiftSeries(SlowPriceEMA, rates_total, 0);
      ResizeShiftSeries(TrendEMAArray, rates_total, 0);
      ResizeShiftSeries(SmoothedMACD, rates_total, 0);
      ResizeShiftSeries(FinalWaveRaw, rates_total, 0);
      ResizeShiftSeries(SignalRaw, rates_total, 0);
      ResizeShiftSeries(SignalSmooth2, rates_total, 0);
      ResizeShiftSeries(AutoAmplitudeEMA, rates_total, 0);
      ResizeShiftSeries(AutoScaleEMA, rates_total, 0);
      ResizeShiftSeries(ATRArray, rates_total, 0);
      ResizeShiftSeries(BuyPressureArray, rates_total, 0);
      ResizeShiftSeries(SellPressureArray, rates_total, 0);
      ResizeShiftSeries(FastPressureEMA, rates_total, 0);
      ResizeShiftSeries(SlowPressureEMA, rates_total, 0);
      ResizeShiftSeries(BalanceEMAArray, rates_total, 0);
      ResizeShiftSeries(PressureDirectionArray, rates_total, 0);
      ResizeShiftSeries(PressureBalanceArray, rates_total, 0);
   }
   else if(new_bars > 0 || ArraySize(FastPriceEMA) != rates_total)
   {
      ResizeShiftSeries(FastPriceEMA, rates_total, new_bars);
      ResizeShiftSeries(SlowPriceEMA, rates_total, new_bars);
      ResizeShiftSeries(TrendEMAArray, rates_total, new_bars);
      ResizeShiftSeries(SmoothedMACD, rates_total, new_bars);
      ResizeShiftSeries(FinalWaveRaw, rates_total, new_bars);
      ResizeShiftSeries(SignalRaw, rates_total, new_bars);
      ResizeShiftSeries(SignalSmooth2, rates_total, new_bars);
      ResizeShiftSeries(AutoAmplitudeEMA, rates_total, new_bars);
      ResizeShiftSeries(AutoScaleEMA, rates_total, new_bars);
      ResizeShiftSeries(ATRArray, rates_total, new_bars);
      ResizeShiftSeries(BuyPressureArray, rates_total, new_bars);
      ResizeShiftSeries(SellPressureArray, rates_total, new_bars);
      ResizeShiftSeries(FastPressureEMA, rates_total, new_bars);
      ResizeShiftSeries(SlowPressureEMA, rates_total, new_bars);
      ResizeShiftSeries(BalanceEMAArray, rates_total, new_bars);
      ResizeShiftSeries(PressureDirectionArray, rates_total, new_bars);
      ResizeShiftSeries(PressureBalanceArray, rates_total, new_bars);
   }

   const double fast_alpha =
      2.0 / (InpFastEMA + 1.0);

   const double slow_alpha =
      2.0 / (InpSlowEMA + 1.0);

   const double signal_alpha =
      2.0 / (InpSignalEMA + 1.0);

   const double signal_alpha_2 =
      2.0 / (InpSignalSmoothing2 + 1.0);

   const double auto_scale_alpha =
      2.0 / (InpAutoScalePeriod + 1.0);

   const double pressure_fast_alpha =
      2.0 / (InpPressureFastEMA + 1.0);

   const double pressure_slow_alpha =
      2.0 / (InpPressureSlowEMA + 1.0);

   const double balance_alpha =
      2.0 / (InpBalanceEMA + 1.0);

   const double trend_alpha =
      2.0 / (InpTrendEMA + 1.0);

   const double atr_alpha =
      2.0 / (InpATRPeriod + 1.0);

   const double wave_alpha =
      2.0 / (InpWaveSmoothing + 1.0);

   const double bias_weight_sum =
      MathMax(
         0.0001,
         InpPriceBiasWeight +
         InpVolumeBiasWeight
      );

   const int oldest = rates_total - 1;

   int calculate_from = 0;

   if(full_rebuild)
   {
      const double seed_price =
         GetAppliedPrice(oldest, open, high, low, close);

      FastPriceEMA[oldest] = seed_price;
      SlowPriceEMA[oldest] = seed_price;
      TrendEMAArray[oldest] = close[oldest];

      RawMACDBuffer[oldest] = 0.0;
      SmoothedMACD[oldest] = 0.0;
      FinalWaveRaw[oldest] = 0.0;
      SignalRaw[oldest] = 0.0;
      SignalSmooth2[oldest] = 0.0;
      ATRArray[oldest] = MathMax(_Point, high[oldest] - low[oldest]);
      AutoAmplitudeEMA[oldest] = MathMax(_Point, ATRArray[oldest]);
      AutoScaleEMA[oldest] = 1.0;

      double seed_buy = 0.0;
      double seed_sell = 0.0;
      CalculateBuySellPressure(
         oldest, open, high, low, close, tick_volume, volume,
         seed_buy, seed_sell);

      BuyPressureArray[oldest] = seed_buy;
      SellPressureArray[oldest] = seed_sell;

      const double seed_pressure = seed_buy - seed_sell;
      FastPressureEMA[oldest] = seed_pressure;
      SlowPressureEMA[oldest] = seed_pressure;
      BalanceEMAArray[oldest] = seed_pressure;
      PressureDirectionArray[oldest] = 0.0;
      PressureBalanceArray[oldest] = 0.0;

      FinalWaveBuffer[oldest] = 0.0;
      SignalBuffer[oldest] = 0.0;
      ColorIndexBuffer[oldest] = 0.0;
      DirectionStateBuffer[oldest] = 0.0;
      ZeroStateBuffer[oldest] = 0.0;
      UnscaledFinalWaveBuffer[oldest] = 0.0;
      UnscaledSignalBuffer[oldest] = 0.0;

      calculate_from = oldest - 1;
   }
   else
   {
      // Rebuild only the recent dependency window.  i+1 remains the exact
      // previously calculated recursive seed after the internal series arrays
      // are shifted for newly opened bars.
      const int overlap = MathMax(InpColorConfirmBars + 3, 8);
      calculate_from = MathMin(rates_total - 2, new_bars + overlap);
   }

   for(int i = calculate_from; i >= 0; i--)
   {
      const double price =
         GetAppliedPrice(i, open, high, low, close);

      FastPriceEMA[i] =
         fast_alpha * price +
         (1.0 - fast_alpha) * FastPriceEMA[i + 1];

      SlowPriceEMA[i] =
         slow_alpha * price +
         (1.0 - slow_alpha) * SlowPriceEMA[i + 1];

      TrendEMAArray[i] =
         trend_alpha * close[i] +
         (1.0 - trend_alpha) * TrendEMAArray[i + 1];

      RawMACDBuffer[i] =
         FastPriceEMA[i] - SlowPriceEMA[i];

      if(InpWaveSmoothing == 1)
      {
         SmoothedMACD[i] =
            RawMACDBuffer[i];
      }
      else
      {
         SmoothedMACD[i] =
            wave_alpha * RawMACDBuffer[i] +
            (1.0 - wave_alpha) *
            SmoothedMACD[i + 1];
      }

      const double previous_close =
         close[i + 1];

      const double true_range =
         MathMax(
            high[i] - low[i],
            MathMax(
               MathAbs(high[i] - previous_close),
               MathAbs(low[i] - previous_close)
            )
         );

      ATRArray[i] =
         atr_alpha * true_range +
         (1.0 - atr_alpha) * ATRArray[i + 1];

      double buy_pressure = 0.0;
      double sell_pressure = 0.0;

      CalculateBuySellPressure(
         i,
         open,
         high,
         low,
         close,
         tick_volume,
         volume,
         buy_pressure,
         sell_pressure
      );

      BuyPressureArray[i] = buy_pressure;
      SellPressureArray[i] = sell_pressure;

      const double net_pressure =
         buy_pressure - sell_pressure;

      FastPressureEMA[i] =
         pressure_fast_alpha * net_pressure +
         (1.0 - pressure_fast_alpha) *
         FastPressureEMA[i + 1];

      SlowPressureEMA[i] =
         pressure_slow_alpha * net_pressure +
         (1.0 - pressure_slow_alpha) *
         SlowPressureEMA[i + 1];

      BalanceEMAArray[i] =
         balance_alpha * net_pressure +
         (1.0 - balance_alpha) *
         BalanceEMAArray[i + 1];

      const double pressure_scale =
         MathMax(
            1.0,
            (
               MathAbs(FastPressureEMA[i]) +
               MathAbs(SlowPressureEMA[i]) +
               MathAbs(BalanceEMAArray[i])
            ) / 3.0
         );

      PressureDirectionArray[i] =
         Clamp(
            (
               FastPressureEMA[i] -
               SlowPressureEMA[i]
            ) / pressure_scale,
            -1.0,
            1.0
         );

      PressureBalanceArray[i] =
         Clamp(
            BalanceEMAArray[i] / pressure_scale,
            -1.0,
            1.0
         );

      const double safe_atr =
         MathMax(_Point, ATRArray[i]);

      const double price_trend_bias =
         Clamp(
            (
               0.65 * (close[i] - TrendEMAArray[i]) +
               0.35 * (TrendEMAArray[i] -
                       TrendEMAArray[i + 1])
            ) / safe_atr,
            -1.0,
            1.0
         );

      const double combined_bias =
         (
            InpPriceBiasWeight * price_trend_bias +
            InpVolumeBiasWeight * PressureBalanceArray[i]
         ) / bias_weight_sum;

      // Price MACD remains the main wave.
      // Slow trend/pressure only shifts its zero-line position.
      const double bias_component =
         combined_bias *
         safe_atr *
         InpBiasStrengthATR;

      FinalWaveRaw[i] =
         SmoothedMACD[i] + bias_component;

      SignalRaw[i] =
         signal_alpha * FinalWaveRaw[i] +
         (1.0 - signal_alpha) *
         SignalRaw[i + 1];

      // Second smoothing stage reduces small signal-line vibrations.
      SignalSmooth2[i] =
         signal_alpha_2 * SignalRaw[i] +
         (1.0 - signal_alpha_2) *
         SignalSmooth2[i + 1];

      // Dead-zone suppresses tiny movements around the prior signal.
      const double signal_dead_zone =
         MathMax(_Point, ATRArray[i]) *
         MathMax(0.0, InpSignalDeadZoneATR);

      if(MathAbs(SignalSmooth2[i] - SignalSmooth2[i + 1]) <
         signal_dead_zone)
      {
         SignalSmooth2[i] = SignalSmooth2[i + 1];
      }

      // Fully automatic display enlargement.
      // Recent average wave amplitude determines the chart scale.
      // This affects only visual height, not trading decisions.
      const double current_amplitude =
         MathMax(
            MathAbs(FinalWaveRaw[i]),
            MathAbs(SignalSmooth2[i])
         );

      AutoAmplitudeEMA[i] =
         auto_scale_alpha * current_amplitude +
         (1.0 - auto_scale_alpha) *
         AutoAmplitudeEMA[i + 1];

      const double minimum_amplitude =
         MathMax(
            _Point,
            ATRArray[i] * 0.01
         );

      const double raw_auto_scale =
         InpAutoTargetHeight /
         MathMax(minimum_amplitude, AutoAmplitudeEMA[i]);

      const double clamped_auto_scale =
         MathMax(
            InpAutoScaleMin,
            MathMin(InpAutoScaleMax, raw_auto_scale)
         );

      // Smooth the scale itself so the histogram does not suddenly resize.
      AutoScaleEMA[i] =
         auto_scale_alpha * clamped_auto_scale +
         (1.0 - auto_scale_alpha) *
         AutoScaleEMA[i + 1];

      // v2.05: expose calculation-stable, unscaled values for the EA.
      // AutoScale remains display-only and can no longer change trading slope,
      // acceleration, persistence, or adaptive zero-distance calculations.
      UnscaledFinalWaveBuffer[i] = FinalWaveRaw[i];
      UnscaledSignalBuffer[i] = SignalSmooth2[i];

      FinalWaveBuffer[i] =
         FinalWaveRaw[i] * AutoScaleEMA[i];

      SignalBuffer[i] =
         SignalSmooth2[i] * AutoScaleEMA[i];

      // Price MACD direction is the primary color direction.
      // Pressure is used only as confirmation and must never invert
      // a rising price MACD to red or a falling price MACD to green.
      const double macd_direction =
         SmoothedMACD[i] -
         SmoothedMACD[i + 1];

      const bool macd_rising =
         macd_direction >= 0.0;

      const bool macd_falling =
         macd_direction <= 0.0;

      const int previous_state =
         (int)DirectionStateBuffer[i + 1];

      int candidate_state = 0;

      if(InpUseMACDDirection)
      {
         if(macd_direction > 0.0)
            candidate_state = 1;
         else if(macd_direction < 0.0)
            candidate_state = -1;
         else
            candidate_state = previous_state;
      }
      else
      {
         if(PressureDirectionArray[i] >= InpBuyThreshold)
            candidate_state = 1;
         else if(PressureDirectionArray[i] <= InpSellThreshold)
            candidate_state = -1;
         else if(previous_state == 1 &&
                 PressureDirectionArray[i] > -InpExitThreshold)
            candidate_state = 1;
         else if(previous_state == -1 &&
                 PressureDirectionArray[i] < InpExitThreshold)
            candidate_state = -1;
      }

      bool confirmed =
         (candidate_state != 0);

      if(confirmed && InpColorConfirmBars > 1)
      {
         for(int c = 1;
             c < InpColorConfirmBars;
             c++)
         {
            const int check = i + c;

            if(check >= rates_total ||
               (InpUseMACDDirection && check + 1 >= rates_total))
            {
               confirmed = false;
               break;
            }

            const double check_direction =
               InpUseMACDDirection
               ? SmoothedMACD[check] - SmoothedMACD[check + 1]
               : PressureDirectionArray[check];

            if((candidate_state == 1 && check_direction < 0.0) ||
               (candidate_state == -1 && check_direction > 0.0))
            {
               confirmed = false;
               break;
            }
         }
      }

      if(confirmed && candidate_state == 1)
      {
         ColorIndexBuffer[i] = 0.0;
         DirectionStateBuffer[i] = 1.0;
      }
      else if(confirmed && candidate_state == -1)
      {
         ColorIndexBuffer[i] = 1.0;
         DirectionStateBuffer[i] = -1.0;
      }
      else if(InpKeepPreviousColor)
      {
         ColorIndexBuffer[i] =
            ColorIndexBuffer[i + 1];

         DirectionStateBuffer[i] =
            DirectionStateBuffer[i + 1];
      }
      else
      {
         ColorIndexBuffer[i] =
            (macd_direction >= 0.0) ? 0.0 : 1.0;

         DirectionStateBuffer[i] =
            (macd_direction >= 0.0) ? 1.0 : -1.0;
      }

      if(combined_bias > 0.05)
         ZeroStateBuffer[i] = 1.0;
      else if(combined_bias < -0.05)
         ZeroStateBuffer[i] = -1.0;
      else
         ZeroStateBuffer[i] = 0.0;
   }

   return rates_total;
}
//+------------------------------------------------------------------+
