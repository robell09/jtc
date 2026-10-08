#ifndef JTC_TURN_DIRECTION_CORE_MQH
#define JTC_TURN_DIRECTION_CORE_MQH
// Existing SIMPLE_DIRECTION price/MACD-base progress and OFF->ON rule.
// The leg owner is now a confirmed TURN PRE, rather than a legacy WATCH.
struct JTC_TURN_DIRECTION_STATE
{
   datetime last_bar,leg_time,last_event_time;
   int owner_side;
   bool active;
   double prior_high,prior_low;
};
void JTC_TurnDirectionResetState(JTC_TURN_DIRECTION_STATE &s)
{
   ZeroMemory(s);
}
int JTC_TurnDirectionDecide(JTC_TURN_DIRECTION_STATE &s,const datetime bar,
   const bool valid,const int new_turn_side,const double close1,const double close2,
   const double high1,const double high2,const double low1,const double low2,
   const double base1,const double base2)
{
   if(bar<=0 || bar<=s.last_bar) return 0;
   s.last_bar=bar;
   if(!valid)
   {s.owner_side=0;s.leg_time=0;s.active=false;s.prior_high=0.0;s.prior_low=0.0;return 0;}
   if(new_turn_side==1 || new_turn_side==-1)
   {
      s.owner_side=new_turn_side;s.leg_time=bar;s.active=false;
      s.last_event_time=0;s.prior_high=0.0;s.prior_low=0.0;
      return 0; // PRE has priority; no DIRECTION on the same owner bar.
   }
   if(s.owner_side==0 || bar<=s.leg_time) return 0;
   const bool prior=s.last_event_time>s.leg_time;
   const bool aligned=s.owner_side>0 ?
      close1>close2 && high1>high2 && base1>base2 && (!prior || close1>s.prior_high) :
      close1<close2 && low1<low2 && base1<base2 && (!prior || close1<s.prior_low);
   if(!aligned) {s.active=false;return 0;}
   if(s.active) return 0;
   s.active=true;s.last_event_time=bar;s.prior_high=high1;s.prior_low=low1;
   return s.owner_side;
}
#endif
