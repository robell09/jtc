#ifndef JOON_REVIEW_SHADOW_ENGINE_MQH
#define JOON_REVIEW_SHADOW_ENGINE_MQH
// Research tracker only. Order ownership never reads these lifecycle fields.
struct JTC_REVIEW_TRACKER
{
   bool active;
   int side;
   datetime start;
   int age;
   bool pending;
   int pending_age;
   datetime last_bar;
};
JTC_REVIEW_TRACKER g_review_tracker;
int g_review_adx_handle=INVALID_HANDLE;

void ReviewTrackerClear(JTC_REVIEW_TRACKER &t)
{
   t.active=false; t.side=0; t.start=0; t.age=0;
   t.pending=false; t.pending_age=0;
}

void ReviewTrackerStep(JTC_REVIEW_TRACKER &t,const datetime bar,
                       const bool pulse,const int pulse_side,
                       const bool watch,const bool gap,
                       const bool long_progress,const bool short_progress,
                       bool &recovered,bool &cancelled,string &end_reason,
                       datetime &ended_start,int &ended_side)
{
   recovered=false; cancelled=false; end_reason=""; ended_start=0; ended_side=0;
   if(bar<=0 || bar<=t.last_bar) return;
   t.last_bar=bar;
   if(gap || watch)
   {
      if(t.active)
      {
         ended_start=t.start; ended_side=t.side;
         end_reason=(gap ? "DATA_GAP" : "CANONICAL_WATCH");
      }
      ReviewTrackerClear(t);
      return;
   }
   bool started=false;
   if(pulse && pulse_side!=0 && (!t.active || t.side!=pulse_side))
   {
      if(t.active)
      {
         ended_start=t.start; ended_side=t.side; end_reason="SUPERSEDED";
      }
      ReviewTrackerClear(t);
      t.active=true; t.side=pulse_side; t.start=bar; started=true;
   }
   if(!t.active || started) return;
   // Same-side re-pulses must advance BOTH clocks and inspect recovery.
   t.age++;
   const bool target=(t.side>0 ? long_progress : short_progress);
   const bool existing=(t.side>0 ? short_progress : long_progress);
   if(t.pending)
   {
      t.pending_age++;
      if(target)
      {
         recovered=true; end_reason="TARGET_RECOVERED";
      }
      else if(t.pending_age>=5)
      {
         cancelled=true; end_reason="REASSERTION_TIMEOUT";
      }
   }
   else if(t.age<=8 && existing)
   {
      t.pending=true; t.pending_age=0;
   }
   else if(t.age>=8)
      end_reason="EXPIRED_NO_REASSERTION";
   if(end_reason!="" && end_reason!="SUPERSEDED")
   {
      ended_start=t.start; ended_side=t.side; ReviewTrackerClear(t);
   }
}

// Centralize the optional ADD predicate so its boundary cases are testable.
bool ReviewShouldBlockAdd(const bool enabled,const datetime signal_bar,
                          const datetime assist_bar,const bool qualified,
                          const int opposite_side,const int held_side)
{
   return enabled && signal_bar>0 && signal_bar==assist_bar && qualified &&
          held_side!=0 && opposite_side==-held_side;
}

// Platform ADX Wilder, completed bars only. Missing/warming data is NOT zero.
bool ReviewReadADX14(const int shift,double &value)
{
   value=0.0;
   if(g_review_adx_handle==INVALID_HANDLE)
      g_review_adx_handle=iADXWilder(_Symbol,AUTO_TF,14);
   if(g_review_adx_handle==INVALID_HANDLE || shift<1 ||
      BarsCalculated(g_review_adx_handle)<shift+28) return false;
   double data[];
   if(CopyBuffer(g_review_adx_handle,0,shift,1,data)!=1) return false;
   if(data[0]==EMPTY_VALUE || !MathIsValidNumber(data[0]) ||
      data[0]<0.0 || data[0]>100.0) return false;
   value=data[0]; return true;
}
void ReviewReleaseADX()
{
   if(g_review_adx_handle!=INVALID_HANDLE) IndicatorRelease(g_review_adx_handle);
   g_review_adx_handle=INVALID_HANDLE;
}
#endif
