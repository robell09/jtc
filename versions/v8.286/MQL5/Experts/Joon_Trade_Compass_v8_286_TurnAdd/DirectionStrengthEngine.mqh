//+------------------------------------------------------------------+
//| DirectionStrengthEngine.mqh                                      |
//| Common LONG/SHORT direction-strength classification              |
//+------------------------------------------------------------------+
#ifndef __JOON_DIRECTION_STRENGTH_ENGINE_MQH__
#define __JOON_DIRECTION_STRENGTH_ENGINE_MQH__

enum ENUM_JTA_DIRECTION_STRENGTH
{
   JTA_STRENGTH_OPPOSITE = -1,
   JTA_STRENGTH_NONE     = 0,
   JTA_STRENGTH_WEAK     = 1,
   JTA_STRENGTH_NORMAL   = 2,
   JTA_STRENGTH_STRONG   = 3
};

struct JTA_DirectionStrengthResult
{
   int direction;
   ENUM_JTA_DIRECTION_STRENGTH level;
   int score;
   int macd_score;
   int delta_score;
   int ma_score;
   int structure_score;
   int higher_tf_score;
   bool strengthening;
   bool weakening;
   bool opposite_pressure;
   string reason;
};

string JTA_DirectionStrengthName(const ENUM_JTA_DIRECTION_STRENGTH level)
{
   if(level == JTA_STRENGTH_STRONG)   return "STRONG";
   if(level == JTA_STRENGTH_NORMAL)   return "NORMAL";
   if(level == JTA_STRENGTH_WEAK)     return "WEAK";
   if(level == JTA_STRENGTH_OPPOSITE) return "OPPOSITE";
   return "NONE";
}

// side: +1 LONG, -1 SHORT. Directional normalization makes LONG and SHORT
// use the same scoring formula. This engine intentionally does not calculate
// duration or persistence bars.
JTA_DirectionStrengthResult EvaluateDirectionStrength(
   const int side,
   const double macd_now,
   const double macd_prev,
   const double delta_now,
   const double delta_prev,
   const double delta_ema_now,
   const double delta_ema_prev,
   const double fast_ma_now,
   const double fast_ma_prev,
   const double slow_ma_now,
   const double close_price,
   const bool higher_tf_aligned,
   const bool macd_strong,
   const bool delta_strong,
   const bool favourable_structure,
   const bool opposite_pressure)
{
   JTA_DirectionStrengthResult result;
   result.direction = side >= 0 ? 1 : -1;
   result.level = JTA_STRENGTH_NONE;
   result.score = 0;
   result.macd_score = 0;
   result.delta_score = 0;
   result.ma_score = 0;
   result.structure_score = 0;
   result.higher_tf_score = 0;
   result.strengthening = false;
   result.weakening = false;
   result.opposite_pressure = opposite_pressure;
   result.reason = "";

   const double sign = result.direction > 0 ? 1.0 : -1.0;
   const double n_macd = macd_now * sign;
   const double n_macd_prev = macd_prev * sign;
   const double n_delta = delta_now * sign;
   const double n_delta_prev = delta_prev * sign;
   const double n_delta_ema = delta_ema_now * sign;
   const double n_delta_ema_prev = delta_ema_prev * sign;
   const double n_ma_gap = (fast_ma_now - slow_ma_now) * sign;
   const double n_ma_slope = (fast_ma_now - fast_ma_prev) * sign;
   const double n_price_fast = (close_price - fast_ma_now) * sign;

   // MACD: direction alive, improving slope and pre-calculated strong state.
   if(n_macd > 0.0) result.macd_score += 14;
   else if(n_macd >= 0.0 || n_macd > n_macd_prev) result.macd_score += 7;
   if(n_macd > n_macd_prev) result.macd_score += 6;
   if(macd_strong) result.macd_score += 5;
   result.macd_score = MathMin(25, result.macd_score);

   // Delta: raw direction, EMA confirmation and improvement.
   if(n_delta > 0.0) result.delta_score += 10;
   else if(n_delta > n_delta_prev) result.delta_score += 5;
   if(n_delta_ema > 0.0) result.delta_score += 7;
   else if(n_delta_ema > n_delta_ema_prev) result.delta_score += 3;
   if(n_delta > n_delta_prev || n_delta_ema > n_delta_ema_prev)
      result.delta_score += 3;
   if(delta_strong) result.delta_score += 5;
   result.delta_score = MathMin(25, result.delta_score);

   // MA and price alignment.
   if(n_ma_gap > 0.0) result.ma_score += 12;
   else if(n_ma_slope > 0.0) result.ma_score += 5;
   if(n_ma_slope > 0.0) result.ma_score += 6;
   if(n_price_fast >= 0.0) result.ma_score += 7;
   result.ma_score = MathMin(25, result.ma_score);

   // Current price structure and higher-timeframe context.
   if(favourable_structure) result.structure_score += 14;
   result.structure_score = MathMin(14, result.structure_score);
   if(higher_tf_aligned) result.higher_tf_score = 11;

   result.score = result.macd_score + result.delta_score +
                  result.ma_score + result.structure_score +
                  result.higher_tf_score;

   if(opposite_pressure)
      result.score = MathMax(0, result.score - 20);

   result.strengthening =
      n_macd > n_macd_prev &&
      (n_delta > n_delta_prev || n_delta_ema > n_delta_ema_prev) &&
      n_ma_slope > 0.0;

   result.weakening =
      (n_macd <= n_macd_prev && n_delta <= n_delta_prev) ||
      n_ma_gap <= 0.0 || opposite_pressure;

   // A direction whose MACD, Delta and MA are all adverse is explicitly
   // OPPOSITE. Otherwise use the common 0-100 strength thresholds.
   const bool core_opposite =
      n_macd < 0.0 && n_delta < 0.0 && n_ma_gap < 0.0;

   if(core_opposite)
      result.level = JTA_STRENGTH_OPPOSITE;
   else if(result.score >= 80)
      result.level = JTA_STRENGTH_STRONG;
   else if(result.score >= 60)
      result.level = JTA_STRENGTH_NORMAL;
   else if(result.score >= 40)
      result.level = JTA_STRENGTH_WEAK;
   else
      result.level = JTA_STRENGTH_NONE;

   result.reason =
      "MACD=" + IntegerToString(result.macd_score) +
      " DELTA=" + IntegerToString(result.delta_score) +
      " MA=" + IntegerToString(result.ma_score) +
      " STRUCT=" + IntegerToString(result.structure_score) +
      " HTF=" + IntegerToString(result.higher_tf_score) +
      " TOTAL=" + IntegerToString(result.score) +
      " " + JTA_DirectionStrengthName(result.level);

   return result;
}

bool JTA_StrengthAtLeast(
   const JTA_DirectionStrengthResult &state,
   const ENUM_JTA_DIRECTION_STRENGTH minimum_level)
{
   return state.level >= minimum_level;
}

#endif // __JOON_DIRECTION_STRENGTH_ENGINE_MQH__
