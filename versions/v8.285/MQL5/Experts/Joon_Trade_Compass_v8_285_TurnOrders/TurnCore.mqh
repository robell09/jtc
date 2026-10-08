#ifndef JTC_TURN_CORE_MQH
#define JTC_TURN_CORE_MQH
// Pure causal core: shift >=1, pivot=shift+1; no forming/future bar reads.
struct JTC_TURN_FRAME
{
   bool valid;
   datetime bar_time;
   datetime pivot_time;
   double close_price;
   double high_price;
   double low_price;
   double pivot_close;
   double pivot_high;
   double pivot_low;
   double prior_low;
   double prior_high;
   double atr14;
   double raw_step_r;
   double wave_step_r;
   double raw_delta_pressure;
   double delta_step_norm;
   double long_divergence_r;
   double short_divergence_r;
};
struct JTC_TURN_RESULT
{
   int side;
   int long_score;
   int short_score;
   bool low_candidate;
   bool high_candidate;
   bool long_divergence;
   bool short_divergence;
   double distance_r;
   double pivot_price;
};
bool JTC_TurnFinite(const double v)
{
   return v!=EMPTY_VALUE && MathIsValidNumber(v);
}
void JTC_TurnBuildFrame(const MqlRates &r[],const double &raw[],
                       const double &wave[],const double &delta[],
                       const double &ema[],const double &volume[],
                       const int shift,const int left_bars,JTC_TURN_FRAME &f)
{
   ZeroMemory(f);
   if(shift<1 || left_bars<2 || left_bars>12) return;
   const int last=shift+MathMax(14,left_bars+1);
   if(ArraySize(r)<=last || ArraySize(raw)<=last || ArraySize(wave)<=shift+1 ||
      ArraySize(delta)<=shift || ArraySize(ema)<=shift+1 || ArraySize(volume)<=shift+1) return;
   for(int j=shift;j<=last;j++)
   {
      if(r[j].time<=0 || !JTC_TurnFinite(r[j].high) || !JTC_TurnFinite(r[j].low) ||
         !JTC_TurnFinite(r[j].close) || r[j].high<r[j].low ||
         r[j].close<r[j].low || r[j].close>r[j].high) return;
      if(j<last && r[j].time-r[j+1].time!=180) return;
   }
   for(int j=shift;j<=shift+1;j++)
      if(!JTC_TurnFinite(raw[j]) || !JTC_TurnFinite(wave[j]) ||
         !JTC_TurnFinite(ema[j]) || !JTC_TurnFinite(volume[j]) || volume[j]<=0.0) return;
   if(!JTC_TurnFinite(delta[shift])) return;
   int prior_low_idx=shift+2,prior_high_idx=shift+2;
   for(int j=shift+3;j<=shift+left_bars+1;j++)
   {
      // Strict comparisons keep the most recent extreme on equal prices.
      if(r[j].low<r[prior_low_idx].low) prior_low_idx=j;
      if(r[j].high>r[prior_high_idx].high) prior_high_idx=j;
   }
   if(!JTC_TurnFinite(raw[prior_low_idx]) || !JTC_TurnFinite(raw[prior_high_idx])) return;
   double tr=0.0;
   for(int j=shift;j<shift+14;j++)
      tr+=MathMax(r[j].high-r[j].low,
          MathMax(MathAbs(r[j].high-r[j+1].close),MathAbs(r[j].low-r[j+1].close)));
   const double atr=tr/14.0;
   if(!JTC_TurnFinite(atr) || atr<=0.0) return;
   const int p=shift+1;
   f.bar_time=r[shift].time; f.pivot_time=r[p].time;
   f.close_price=r[shift].close; f.high_price=r[shift].high; f.low_price=r[shift].low;
   f.pivot_close=r[p].close; f.pivot_high=r[p].high; f.pivot_low=r[p].low;
   f.prior_low=r[prior_low_idx].low; f.prior_high=r[prior_high_idx].high;
   f.atr14=atr;
   f.raw_step_r=(raw[shift]-raw[p])/atr;
   f.wave_step_r=(wave[shift]-wave[p])/atr;
   f.raw_delta_pressure=delta[shift]/volume[shift];
   f.delta_step_norm=(ema[shift]-ema[p])/((volume[shift]+volume[p])*0.5);
   f.long_divergence_r=(raw[p]-raw[prior_low_idx])/atr;
   f.short_divergence_r=(raw[prior_high_idx]-raw[p])/atr;
   f.valid=true;
}
void JTC_TurnDecide(const JTC_TURN_FRAME &f,const bool require_divergence,
                   const double min_rebound,const double max_distance,
                   const double momentum_deadzone,JTC_TURN_RESULT &q)
{
   ZeroMemory(q);
   if(!f.valid || !JTC_TurnFinite(f.atr14) || f.atr14<=0.0 || min_rebound<0.0 || max_distance<min_rebound || momentum_deadzone<0.0) return;
   const double ld=(f.close_price-f.pivot_low)/f.atr14;
   const double sd=(f.pivot_high-f.close_price)/f.atr14;
   q.low_candidate=(f.pivot_low<=f.prior_low && f.low_price>f.pivot_low &&
      f.close_price>f.pivot_close && ld>=min_rebound && ld<=max_distance);
   q.high_candidate=(f.pivot_high>=f.prior_high && f.high_price<f.pivot_high &&
      f.close_price<f.pivot_close && sd>=min_rebound && sd<=max_distance);
   q.long_divergence=(f.long_divergence_r>momentum_deadzone);
   q.short_divergence=(f.short_divergence_r>momentum_deadzone);
   const bool dl=(f.raw_delta_pressure>0.0 && f.delta_step_norm>0.0);
   const bool ds=(f.raw_delta_pressure<0.0 && f.delta_step_norm<0.0);
   q.long_score=(f.raw_step_r>momentum_deadzone ? 1 : 0)+
      (f.wave_step_r>momentum_deadzone ? 1 : 0)+(dl ? 1 : 0);
   q.short_score=(f.raw_step_r<-momentum_deadzone ? 1 : 0)+
      (f.wave_step_r<-momentum_deadzone ? 1 : 0)+(ds ? 1 : 0);
   const bool good_long=q.low_candidate && q.long_score==3 &&
      (!require_divergence || q.long_divergence);
   const bool good_short=q.high_candidate && q.short_score==3 &&
      (!require_divergence || q.short_divergence);
   if(good_long==good_short) return; // both/none never invent a direction
   q.side=(good_long ? 1 : -1);
   q.distance_r=(good_long ? ld : sd);
   q.pivot_price=(good_long ? f.pivot_low : f.pivot_high);
}
bool JTC_TurnEmit(const datetime bar,const int side,const int cooldown_bars,
                  datetime &last_long,datetime &last_short)
{
   if(bar<=0 || (side!=1 && side!=-1) || cooldown_bars<1) return false;
   const datetime prior=(side>0 ? last_long : last_short);
   if(prior>0 && bar-prior<(long)cooldown_bars*180) return false;
   if(side>0) last_long=bar; else last_short=bar;
   return true;
}
#endif
