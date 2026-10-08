//+------------------------------------------------------------------+
//| WatchEpisodeEngine.mqh                                           |
//| v8.276 observation-only WATCH episode/cluster path diagnostics  |
//+------------------------------------------------------------------+
#ifndef __JOON_WATCH_EPISODE_ENGINE_MQH__
#define __JOON_WATCH_EPISODE_ENGINE_MQH__

struct JTC_WATCH_EPISODE_DIAG
{
   bool active;
   long id;
   int side;
   datetime start_time;
   double start_price;
   int age_bars;
   double mfe_price;
   double mae_price;
   int opposite_watch_age;
   int first_accel_age;
   datetime first_accel_time;
   string state;

   // Causal active-episode path diagnostics. Observation only.
   double last_close;
   double price_travel;
   double net_displacement;
   double efficiency;
   double best_extreme;
   double extreme_extension_r;
   int repeat_count;
   double last_repeat_price;
   double last_repeat_displacement_r;

   // v8.276 multi-episode path memory: up to three completed canonical
   // episodes plus the active episode (four WATCH episodes total).
   double cluster_price_travel;
   double cluster_net_displacement;
   double cluster_efficiency;

   // Frozen WATCH-time context. Diagnostic only.
   double pre_net_progress_r;
   double pre_recent_progress_r;
   double pre_price_travel_3_r;
   double pre_price_efficiency_3;
   double pre_macd_base_efficiency_3;
   double pre_macd_wave_efficiency_3;
   int pre_macd_zero_flip_count_5;
   int pre_up_close_steps;
   int pre_down_close_steps;
};

JTC_WATCH_EPISODE_DIAG g_watch_episode_diag;

struct JTC_WATCH_EPISODE_CLOSED_DIAG
{
   long id;
   int side;
   datetime close_time;
   int age_bars;
   double mfe_price;
   double mae_price;
};

JTC_WATCH_EPISODE_CLOSED_DIAG g_watch_episode_closed_diag;

struct JTC_WATCH_EPISODE_HISTORY_ITEM
{
   long id;
   int side;
   datetime start_time;
   datetime end_time;
   double start_price;
   double end_price;
   double price_travel;
   double net_displacement;
   double efficiency;
};

// Three closed episodes + current active episode = four-episode cluster.
JTC_WATCH_EPISODE_HISTORY_ITEM g_watch_episode_history[3];
int g_watch_episode_history_count=0;

long WatchEpisodeStableId(const datetime start_time,const int side)
{
   if(start_time<=0 || side==0) return 0;
   // Stable across live/warmup/restart; side code avoids ambiguity.
   return ((long)start_time*10L)+(side>0 ? 1L : 2L);
}

void WatchEpisodeResetRuntime()
{
   ZeroMemory(g_watch_episode_diag);
   ZeroMemory(g_watch_episode_closed_diag);
   for(int i=0;i<3;i++) ZeroMemory(g_watch_episode_history[i]);
   g_watch_episode_history_count=0;
   g_watch_episode_diag.active=false;
   g_watch_episode_diag.state="NONE";
}

void WatchEpisodeRecalculateCluster(const double current_close)
{
   if(!g_watch_episode_diag.active)
   {
      g_watch_episode_diag.cluster_price_travel=0.0;
      g_watch_episode_diag.cluster_net_displacement=0.0;
      g_watch_episode_diag.cluster_efficiency=0.0;
      return;
   }

   double travel=g_watch_episode_diag.price_travel;
   double oldest_start=g_watch_episode_diag.start_price;
   if(g_watch_episode_history_count>0)
   {
      oldest_start=g_watch_episode_history[0].start_price;
      for(int i=0;i<g_watch_episode_history_count;i++)
         travel += g_watch_episode_history[i].price_travel;
   }

   g_watch_episode_diag.cluster_price_travel=travel;
   g_watch_episode_diag.cluster_net_displacement=MathAbs(current_close-oldest_start);
   g_watch_episode_diag.cluster_efficiency=(travel>_Point
      ? g_watch_episode_diag.cluster_net_displacement/travel : 0.0);
}

void WatchEpisodePushClosedHistory(const JTC_WATCH_EPISODE_DIAG &ep,
                                   const datetime end_time,const double end_price)
{
   JTC_WATCH_EPISODE_HISTORY_ITEM item;
   ZeroMemory(item);
   item.id=ep.id;
   item.side=ep.side;
   item.start_time=ep.start_time;
   item.end_time=end_time;
   item.start_price=ep.start_price;
   item.end_price=end_price;
   item.price_travel=ep.price_travel;
   item.net_displacement=MathAbs(end_price-ep.start_price);
   item.efficiency=(item.price_travel>_Point ? item.net_displacement/item.price_travel : 0.0);

   if(g_watch_episode_history_count<3)
      g_watch_episode_history[g_watch_episode_history_count++]=item;
   else
   {
      g_watch_episode_history[0]=g_watch_episode_history[1];
      g_watch_episode_history[1]=g_watch_episode_history[2];
      g_watch_episode_history[2]=item;
   }
}

void WatchEpisodeStart(const JTC_M3_STATE &s,const int side)
{
   if(side==0 || s.bar_time<=0) return;
   ZeroMemory(g_watch_episode_diag);
   g_watch_episode_diag.active=true;
   g_watch_episode_diag.id=WatchEpisodeStableId(s.bar_time,side);
   g_watch_episode_diag.side=side;
   g_watch_episode_diag.start_time=s.bar_time;
   g_watch_episode_diag.start_price=s.close;
   g_watch_episode_diag.age_bars=0;
   g_watch_episode_diag.mfe_price=s.close;
   g_watch_episode_diag.mae_price=s.close;
   g_watch_episode_diag.opposite_watch_age=-1;
   g_watch_episode_diag.first_accel_age=-1;
   g_watch_episode_diag.state="OBSERVING";
   g_watch_episode_diag.last_close=s.close;
   g_watch_episode_diag.price_travel=0.0;
   g_watch_episode_diag.net_displacement=0.0;
   g_watch_episode_diag.efficiency=0.0;
   g_watch_episode_diag.best_extreme=s.close;
   g_watch_episode_diag.extreme_extension_r=0.0;
   g_watch_episode_diag.repeat_count=0;
   g_watch_episode_diag.last_repeat_price=0.0;
   g_watch_episode_diag.last_repeat_displacement_r=0.0;
   g_watch_episode_diag.cluster_price_travel=0.0;
   g_watch_episode_diag.cluster_net_displacement=0.0;
   g_watch_episode_diag.cluster_efficiency=0.0;
   g_watch_episode_diag.pre_net_progress_r=g_assist_state.net_progress_r;
   g_watch_episode_diag.pre_recent_progress_r=g_assist_state.recent_progress_r;
   g_watch_episode_diag.pre_price_travel_3_r=g_assist_state.price_travel_3_r;
   g_watch_episode_diag.pre_price_efficiency_3=g_assist_state.price_efficiency_3;
   g_watch_episode_diag.pre_macd_base_efficiency_3=g_assist_state.macd_base_efficiency_3;
   g_watch_episode_diag.pre_macd_wave_efficiency_3=g_assist_state.macd_wave_efficiency_3;
   g_watch_episode_diag.pre_macd_zero_flip_count_5=g_assist_state.macd_zero_flip_count_5;
   g_watch_episode_diag.pre_up_close_steps=g_assist_state.up_close_steps;
   g_watch_episode_diag.pre_down_close_steps=g_assist_state.down_close_steps;
   WatchEpisodeRecalculateCluster(s.close);
}

void WatchEpisodeAccumulateBar(const JTC_M3_STATE &s)
{
   if(!g_watch_episode_diag.active || s.bar_time<=g_watch_episode_diag.start_time) return;

   g_watch_episode_diag.age_bars++;
   if(g_watch_episode_diag.last_close>0.0)
      g_watch_episode_diag.price_travel += MathAbs(s.close-g_watch_episode_diag.last_close);
   g_watch_episode_diag.last_close=s.close;
   g_watch_episode_diag.net_displacement=MathAbs(s.close-g_watch_episode_diag.start_price);
   g_watch_episode_diag.efficiency=(g_watch_episode_diag.price_travel>_Point
      ? g_watch_episode_diag.net_displacement/g_watch_episode_diag.price_travel : 0.0);

   const double scale=MathMax(_Point,g_assist_state.avg_range);
   if(g_watch_episode_diag.side>0)
   {
      if(s.high>g_watch_episode_diag.mfe_price) g_watch_episode_diag.mfe_price=s.high;
      if(s.low <g_watch_episode_diag.mae_price) g_watch_episode_diag.mae_price=s.low;
      if(s.high>g_watch_episode_diag.best_extreme) g_watch_episode_diag.best_extreme=s.high;
      g_watch_episode_diag.extreme_extension_r=(g_watch_episode_diag.best_extreme-g_watch_episode_diag.start_price)/scale;
   }
   else
   {
      if(s.low <g_watch_episode_diag.mfe_price) g_watch_episode_diag.mfe_price=s.low;
      if(s.high>g_watch_episode_diag.mae_price) g_watch_episode_diag.mae_price=s.high;
      if(s.low<g_watch_episode_diag.best_extreme) g_watch_episode_diag.best_extreme=s.low;
      g_watch_episode_diag.extreme_extension_r=(g_watch_episode_diag.start_price-g_watch_episode_diag.best_extreme)/scale;
   }
   WatchEpisodeRecalculateCluster(s.close);
}

void WatchEpisodeUpdate(const JTC_M3_STATE &s,const bool watch_event,const int watch_side,
                        const bool accel_event,const int accel_side)
{
   if(s.bar_time<=0) return;

   if(!g_watch_episode_diag.active)
   {
      if(watch_event && watch_side!=0) WatchEpisodeStart(s,watch_side);
   }
   else
   {
      // v8.276: first account for the full price path through the opposite
      // WATCH bar. That transition bar belongs to the WATCH->opposite-WATCH
      // path of the closing episode.
      WatchEpisodeAccumulateBar(s);

      if(watch_event && watch_side!=0 && g_watch_episode_diag.side!=watch_side)
      {
         g_watch_episode_closed_diag.id=g_watch_episode_diag.id;
         g_watch_episode_closed_diag.side=g_watch_episode_diag.side;
         g_watch_episode_closed_diag.close_time=s.bar_time;
         g_watch_episode_closed_diag.age_bars=g_watch_episode_diag.age_bars;
         g_watch_episode_closed_diag.mfe_price=g_watch_episode_diag.mfe_price;
         g_watch_episode_closed_diag.mae_price=g_watch_episode_diag.mae_price;

         WatchEpisodePushClosedHistory(g_watch_episode_diag,s.bar_time,s.close);
         WatchEpisodeStart(s,watch_side);
      }
      // Same-side canonical WATCH pulse, if ever reintroduced, keeps one owner.
   }

   if(!g_watch_episode_diag.active) return;

   if(accel_event && accel_side==g_watch_episode_diag.side &&
      g_watch_episode_diag.first_accel_time<=0 && s.bar_time>g_watch_episode_diag.start_time)
   {
      g_watch_episode_diag.first_accel_time=s.bar_time;
      g_watch_episode_diag.first_accel_age=g_watch_episode_diag.age_bars;
   }
}

void WatchEpisodeRecordInformationalRepeat(const JTC_M3_STATE &s,const int repeat_side)
{
   if(!g_watch_episode_diag.active || s.bar_time<=0 || repeat_side==0) return;
   if(repeat_side!=g_watch_episode_diag.side) return;
   g_watch_episode_diag.repeat_count++;
   g_watch_episode_diag.last_repeat_price=s.close;
   const double scale=MathMax(_Point,g_assist_state.avg_range);
   g_watch_episode_diag.last_repeat_displacement_r=
      (repeat_side>0 ? (s.close-g_watch_episode_diag.start_price)
                     : (g_watch_episode_diag.start_price-s.close))/scale;
}

#endif
