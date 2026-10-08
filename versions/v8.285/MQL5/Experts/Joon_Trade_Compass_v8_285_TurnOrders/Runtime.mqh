//+------------------------------------------------------------------+
//| Runtime.mqh                                                  |
//| Joon Trend/Range AutoTrader modular component                    |
//+------------------------------------------------------------------+
#ifndef __JOON_RUNTIME_MQH__
#define __JOON_RUNTIME_MQH__

// v8.243: startup/reinitialization authority gate.  Historical reconstruction
// must complete before StateEvaluation/M3 can publish a new strategy signal or
// submit a strategy order. Position-safety management remains independent.
bool g_startup_rebuild_ready=false;
bool g_startup_rebuild_reconcile_pending=false;
// v8.245: live startup replay retries are timer-driven so high-tick symbols
// cannot repeatedly launch a 1600-bar rebuild from OnTick.
bool g_startup_rebuild_in_progress=false;
long g_startup_rebuild_last_probe_msc=0;
long g_startup_rebuild_last_full_attempt_msc=0;

// v8.246: legacy M3 structural pre-signal remains internal/diagnostic only.
// It has no chart marker, alert, push, or order authority. Canonical user-visible
// WATCH remains StateEvaluation WATCH only.

void InvalidateMarketSnapshot()
{
   g_market_snapshot.valid = false;
   g_market_snapshot.source_bar_time = 0;
   g_market_snapshot.closed_bar_time = 0;
   g_market_snapshot.loaded_count = 0;
   g_market_snapshot.common_loaded_count = 0;
   g_market_snapshot.assist_loaded_count = 0;
   g_market_snapshot.range_loaded_count = 0;
   g_market_snapshot_tf = PERIOD_CURRENT;
}

bool EnsureMarketSnapshot(const int requested_count)
{
   const int count = MathMax(3, requested_count);
   const ENUM_TIMEFRAMES data_tf=AUTO_TF;
   const int macd_handle=g_macd_handle;
   const int delta_handle=g_delta_handle;
   const int fast_handle=g_add_ma_handle;
   const int slow_handle=g_slow_ma_handle;

   // v4.04: every consumer of g_ms_* uses closed bars [1+]. Their values do
   // not change until a new bar opens, so key the cache to the data-TF current
   // bar time instead of tick.time_msc. This removes repeated CopyBuffer/
   // CopyRates work on high-tick symbols without changing any closed-bar value.
   const datetime source_bar_time=iTime(_Symbol,data_tf,0);
   const datetime closed_bar_time=iTime(_Symbol,data_tf,1);
   if(source_bar_time<=0 || closed_bar_time<=0)
      return false;

   const bool same_generation=
      g_market_snapshot.valid &&
      g_market_snapshot_tf==data_tf &&
      g_market_snapshot.source_bar_time==source_bar_time;

   if(same_generation &&
      g_market_snapshot.loaded_count>=count)
   {
      g_perf_snapshot_hits++;
      return true;
   }

   if(!same_generation)
   {
      g_market_snapshot.common_loaded_count=0;
      g_market_snapshot.assist_loaded_count=0;
      g_market_snapshot.range_loaded_count=0;
   }

   if(ArraySize(g_ms_macd) < count)
   {
      ArrayResize(g_ms_macd, count);
      ArraySetAsSeries(g_ms_macd, true);
   }
   if(ArraySize(g_ms_delta) < count)
   {
      ArrayResize(g_ms_delta, count);
      ArraySetAsSeries(g_ms_delta, true);
   }
   if(ArraySize(g_ms_fast_ma) < count)
   {
      ArrayResize(g_ms_fast_ma, count);
      ArraySetAsSeries(g_ms_fast_ma, true);
   }
   if(ArraySize(g_ms_slow_ma) < count)
   {
      ArrayResize(g_ms_slow_ma, count);
      ArraySetAsSeries(g_ms_slow_ma, true);
   }
   if(ArraySize(g_ms_rates) < count)
   {
      ArrayResize(g_ms_rates, count);
      ArraySetAsSeries(g_ms_rates, true);
   }

   if(MarketDataCopyBuffer(macd_handle, JTC_MACD_BASE_BUFFER, 0, count, g_ms_macd) < count ||
      MarketDataCopyBuffer(delta_handle, 2, 0, count, g_ms_delta) < count ||
      MarketDataCopyBuffer(fast_handle, 0, 0, count, g_ms_fast_ma) < count ||
      MarketDataCopyBuffer(slow_handle, 0, 0, count, g_ms_slow_ma) < count ||
      MarketDataCopyRates(_Symbol, data_tf, 0, count, g_ms_rates) < count)
   {
      InvalidateMarketSnapshot();
      return false;
   }

   g_market_snapshot.valid = true;
   g_market_snapshot_tf = data_tf;
   g_market_snapshot.source_bar_time = source_bar_time;
   g_market_snapshot.closed_bar_time = closed_bar_time;
   g_market_snapshot.loaded_count = count;
   g_perf_snapshot_misses++;
   return true;
}

// v7.82: extend the existing completed-bar snapshot by component group.
// No second cache/state machine is created. Each group records its own loaded
// history length, so later consumers expand only the data they actually need.
bool EnsureMarketSnapshotCommon(const int requested_count)
{
   const int count=MathMax(3,requested_count);
   if(!EnsureMarketSnapshot(count))
      return false;

   if(g_market_snapshot.common_loaded_count>=count)
      return true;

   if(ArraySize(g_ms_macd_direction)<count)
   {
      ArrayResize(g_ms_macd_direction,count);
      ArraySetAsSeries(g_ms_macd_direction,true);
   }
   if(ArraySize(g_ms_macd_zero_state)<count)
   {
      ArrayResize(g_ms_macd_zero_state,count);
      ArraySetAsSeries(g_ms_macd_zero_state,true);
   }
   if(ArraySize(g_ms_delta_ema)<count)
   {
      ArrayResize(g_ms_delta_ema,count);
      ArraySetAsSeries(g_ms_delta_ema,true);
   }
   if(ArraySize(g_ms_delta_volume)<count)
   {
      ArrayResize(g_ms_delta_volume,count);
      ArraySetAsSeries(g_ms_delta_volume,true);
   }

   if(MarketDataCopyBuffer(g_macd_handle,JTC_MACD_DIRECTION_BUFFER,0,count,g_ms_macd_direction)<count ||
      MarketDataCopyBuffer(g_macd_handle,JTC_MACD_ZERO_STATE_BUFFER,0,count,g_ms_macd_zero_state)<count ||
      MarketDataCopyBuffer(g_delta_handle,3,0,count,g_ms_delta_ema)<count ||
      MarketDataCopyBuffer(g_delta_handle,4,0,count,g_ms_delta_volume)<count)
   {
      g_market_snapshot.common_loaded_count=0;
      return false;
   }

   g_market_snapshot.common_loaded_count=count;
   return true;
}

bool EnsureMarketSnapshotAssist(const int requested_count)
{
   const int count=MathMax(3,requested_count);
   if(!EnsureMarketSnapshotCommon(count))
      return false;

   if(g_market_snapshot.assist_loaded_count>=count)
      return true;

   if(ArraySize(g_ms_macd_wave)<count)
   {
      ArrayResize(g_ms_macd_wave,count);
      ArraySetAsSeries(g_ms_macd_wave,true);
   }
   if(ArraySize(g_ms_macd_raw_price)<count)
   {
      ArrayResize(g_ms_macd_raw_price,count);
      ArraySetAsSeries(g_ms_macd_raw_price,true);
   }

   if(MarketDataCopyBuffer(g_macd_handle,JTC_MACD_WAVE_BUFFER,0,count,g_ms_macd_wave)<count ||
      MarketDataCopyBuffer(g_macd_handle,JTC_MACD_RAW_PRICE_BUFFER,0,count,g_ms_macd_raw_price)<count)
   {
      g_market_snapshot.assist_loaded_count=0;
      return false;
   }

   g_market_snapshot.assist_loaded_count=count;
   return true;
}

bool EnsureMarketSnapshotRange(const int requested_count)
{
   const int count=MathMax(3,requested_count);
   if(!EnsureMarketSnapshotCommon(count))
      return false;

   if(g_market_snapshot.range_loaded_count>=count)
      return true;

   if(ArraySize(g_ms_ma70)<count)
   {
      ArrayResize(g_ms_ma70,count);
      ArraySetAsSeries(g_ms_ma70,true);
   }
   if(ArraySize(g_ms_ma111)<count)
   {
      ArrayResize(g_ms_ma111,count);
      ArraySetAsSeries(g_ms_ma111,true);
   }
   if(ArraySize(g_ms_ma200)<count)
   {
      ArrayResize(g_ms_ma200,count);
      ArraySetAsSeries(g_ms_ma200,true);
   }

   if(MarketDataCopyBuffer(g_ma70_handle,0,0,count,g_ms_ma70)<count ||
      MarketDataCopyBuffer(g_ma111_handle,0,0,count,g_ms_ma111)<count ||
      MarketDataCopyBuffer(g_ma200_handle,0,0,count,g_ms_ma200)<count)
   {
      g_market_snapshot.range_loaded_count=0;
      return false;
   }

   g_market_snapshot.range_loaded_count=count;
   return true;
}

void UISaveChartChangeState()
{
   GlobalVariableSet(UIStateKey("VALID"), 1.0);

   // Strategy ownership must survive an in-terminal reinitialization.
   // Preserve the active RANGE/TREND management strategy across chart reinitialization.
   GlobalVariableSet(UIStateKey("STRATEGY"),
                     (double)g_selected_strategy);
   GlobalVariableSet(UIStateKey("POSITION_STRATEGY"),
                     (double)g_position_strategy);
   GlobalVariableSet(UIStateKey("POSITION_STRATEGY_LOCKED"),
                     g_position_strategy_locked ? 1.0 : 0.0);

   GlobalVariableSet(UIStateKey("SIGNAL_TF"), (double)g_signal_tf);
   GlobalVariableSet(UIStateKey("SIGNAL_DIR"), (double)g_signal_direction);
   GlobalVariableSet(UIStateKey("TRADE_DIR"), (double)g_trade_direction);
   GlobalVariableSet(UIStateKey("LOTS"), g_ui_lots);
   GlobalVariableSet(UIStateKey("SL_PERCENT"), g_stop_loss_percent);
   GlobalVariableSet(UIStateKey("MAX_ADD"),
                     (double)g_max_additional_entries);
   GlobalVariableSet(UIStateKey("SIGNAL_ON"),
                     g_signal_enabled ? 1.0 : 0.0);
   GlobalVariableSet(UIStateKey("AUTO_ON"),
                     g_auto_trading ? 1.0 : 0.0);
   GlobalVariableSet(UIStateKey("SYS_ALERT"),
                     g_terminal_alert ? 1.0 : 0.0);
   GlobalVariableSet(UIStateKey("WATCH_MODE"), (double)g_watch_mode);
   GlobalVariableSet(UIStateKey("MOB_ALERT"),
                     g_mobile_alert ? 1.0 : 0.0);
   GlobalVariableSet(UIStateKey("ALERT_SCORE"),
                     (double)g_minimum_alert_score);
   GlobalVariableSet(UIStateKey("BUY_SIDE"), g_ui_buy ? 1.0 : 0.0);

   // v8.242: preserve confirmed v8.230 ownership across same-EA reinit.
   GlobalVariableSet(UIStateKey("OWNER_VALID"),1.0);
   GlobalVariableSet(UIStateKey("OWNER_ASSIST_STATE"),(double)g_assist_state.state);
   GlobalVariableSet(UIStateKey("OWNER_EST_SIDE"),(double)g_assist_state.established_side);
   GlobalVariableSet(UIStateKey("OWNER_EST_TIME"),(double)g_assist_state.established_time);
   GlobalVariableSet(UIStateKey("OWNER_ANCHOR"),(double)g_assist_state.direction_anchor);
   GlobalVariableSet(UIStateKey("OWNER_WATCH_SIDE"),(double)g_assist_weak_watch_owner_side);
   GlobalVariableSet(UIStateKey("OWNER_WATCH_TIME"),(double)g_assist_weak_watch_owner_time);
   GlobalVariableSet(UIStateKey("OWNER_WATCH_HIGH"),g_assist_weak_watch_owner_high);
   GlobalVariableSet(UIStateKey("OWNER_WATCH_LOW"),g_assist_weak_watch_owner_low);
   GlobalVariableSet(UIStateKey("OWNER_WEAK_LONG_ARMED"),g_assist_long_weak_armed ? 1.0 : 0.0);
   GlobalVariableSet(UIStateKey("OWNER_WEAK_SHORT_ARMED"),g_assist_short_weak_armed ? 1.0 : 0.0);
   GlobalVariableSet(UIStateKey("OWNER_ACCEL_SIDE"),(double)g_m3_segment.last_accel_event_side);
   GlobalVariableSet(UIStateKey("OWNER_ACCEL_TIME"),(double)g_m3_segment.last_accel_event_time);
   GlobalVariableSet(UIStateKey("OWNER_ACTIVE_ACCEL_SIDE"),(double)g_assist_accel_owner_side);
   GlobalVariableSet(UIStateKey("OWNER_ACTIVE_ACCEL_WATCH_TIME"),(double)g_assist_accel_owner_watch_time);
   GlobalVariableSet(UIStateKey("OWNER_ACTIVE_ACCEL_CONFIRMED"),g_assist_accel_owner_confirmed ? 1.0 : 0.0);
   GlobalVariableSet(UIStateKey("OWNER_CHART_ACCEL_COUNT"),(double)g_m3_segment.chart_accel_publish_count);

   // v8.251: the v8.249 REARM -> ACCEL-confirmed INITIAL state must survive
   // same-EA chart/parameter/template reinitialization. The snapshot is only
   // accepted later if historical replay still ends on this exact WATCH owner.
   GlobalVariableSet(UIStateKey("OWNER_PENDING_REVERSE_SIDE"),(double)g_m3_pending_reverse_side);
   GlobalVariableSet(UIStateKey("OWNER_PENDING_REVERSE_WATCH_TIME"),(double)g_m3_pending_reverse_watch_time);
   GlobalVariableSet(UIStateKey("OWNER_PENDING_REVERSE_REQUIRES_ACCEL"),g_m3_pending_reverse_requires_accel ? 1.0 : 0.0);
   GlobalVariableSet(UIStateKey("OWNER_PENDING_REVERSE_ACCEL_CONFIRMED"),g_m3_pending_reverse_accel_confirmed ? 1.0 : 0.0);
   GlobalVariableSet(UIStateKey("OWNER_PENDING_REVERSE_ACCEL_TIME"),(double)g_m3_pending_reverse_accel_time);
   GlobalVariableSet(UIStateKey("OWNER_PENDING_REVERSE_EXIT_OBLIGATION"),g_m3_pending_reverse_exit_obligation ? 1.0 : 0.0);
   GlobalVariableSet(UIStateKey("OWNER_PRE_REARM_EXIT_OBLIGATION"),g_m3_pre_rearm_exit_obligation ? 1.0 : 0.0);
   GlobalVariableSet(UIStateKey("OWNER_PRE_REARM_EXIT_RECOVERY_SIDE"),(double)g_m3_pre_rearm_exit_recovery_side);
   GlobalVariableSet(UIStateKey("OWNER_PRE_REARM_EXIT_OWNER_SIDE"),(double)g_m3_pre_rearm_exit_owner_side);
   GlobalVariableSet(UIStateKey("OWNER_PRE_REARM_EXIT_OWNER_TIME"),(double)g_m3_pre_rearm_exit_owner_time);
   GlobalVariableSet(UIStateKey("OWNER_PRE_REARM_EXEC_SIDE"),(double)g_pre_rearm_execution_owner_side);
   GlobalVariableSet(UIStateKey("OWNER_PRE_REARM_EXEC_TIME"),(double)g_pre_rearm_execution_owner_time);
   GlobalVariableSet(UIStateKey("OWNER_PRE_REARM_EXEC_HIGH"),g_pre_rearm_execution_owner_high);
   GlobalVariableSet(UIStateKey("OWNER_PRE_REARM_EXEC_LOW"),g_pre_rearm_execution_owner_low);
   GlobalVariableSet(UIStateKey("OWNER_PREZERO_REENTRY_ARMED"),g_prezero_reentry_armed ? 1.0 : 0.0);
   GlobalVariableSet(UIStateKey("OWNER_PREZERO_REENTRY_SIDE"),(double)g_prezero_reentry_side);
   GlobalVariableSet(UIStateKey("OWNER_PREZERO_REENTRY_EXIT_TIME"),(double)g_prezero_reentry_exit_time);

   // v3.81: preserve earned INITIAL profit protection across an in-terminal
   // same-chart reinitialization. These values are restored only when the
   // same managed side still exists, so stale protection can never leak into
   // a new/flat lifecycle.
   const int protected_side = ManagedPositionSide();
   GlobalVariableSet(UIStateKey("PROTECT_SIDE"), (double)protected_side);
   GlobalVariableSet(UIStateKey("HIGHEST_PROFIT_R"), g_highest_profit_r);
   GlobalVariableSet(UIStateKey("VIRTUAL_FLOOR_ACTIVE"),
                     g_initial_virtual_profit_floor_active ? 1.0 : 0.0);
   GlobalVariableSet(UIStateKey("VIRTUAL_FLOOR_SIDE"),
                     (double)g_initial_virtual_profit_floor_side);
   GlobalVariableSet(UIStateKey("VIRTUAL_FLOOR_R"),
                     g_initial_virtual_profit_floor_r);
   GlobalVariableSet(UIStateKey("VIRTUAL_FLOOR_PRICE"),
                     g_initial_virtual_profit_floor_price);
   GlobalVariableSet(UIStateKey("VIRTUAL_FLOOR_TIME"),
                     (double)g_initial_virtual_profit_floor_time);

   // v3.04: preserve the operator's horizontal panel positions across
   // timeframe/parameter/template reinitialization. Vertical placement remains
   // price-driven and is intentionally recalculated on the new chart viewport.
   GlobalVariableSet(UIStateKey("MAIN_X"), (double)g_ui_x);
   GlobalVariableSet(UIStateKey("TP_X"),   (double)g_ui_tp_x);
   GlobalVariableSet(UIStateKey("SL_X"),   (double)g_ui_sl_x);

   int entry_y = 0, tp_y = 0, sl_y = 0;
   if(UIPriceToY(UIPrice(UI_ENTRY_LINE), entry_y))
   {
      if(UIPriceToY(UIPrice(UI_TP_LINE), tp_y))
         g_ui_tp_lock_y_offset = tp_y - entry_y;
      if(UIPriceToY(UIPrice(UI_SL_LINE), sl_y))
         g_ui_sl_lock_y_offset = sl_y - entry_y;
   }
   g_ui_tp_lock_x_offset = g_ui_tp_x - g_ui_x;
   g_ui_sl_lock_x_offset = g_ui_sl_x - g_ui_x;
   GlobalVariableSet(UIStateKey("TP_LOCK"),
                     g_ui_tp_locked ? 1.0 : 0.0);
   GlobalVariableSet(UIStateKey("SL_LOCK"),
                     g_ui_sl_locked ? 1.0 : 0.0);
   GlobalVariableSet(UIStateKey("TP_LOCK_Y"),
                     (double)g_ui_tp_lock_y_offset);
   GlobalVariableSet(UIStateKey("SL_LOCK_Y"),
                     (double)g_ui_sl_lock_y_offset);
   GlobalVariableSet(UIStateKey("TP_LOCK_X"),
                     (double)g_ui_tp_lock_x_offset);
   GlobalVariableSet(UIStateKey("SL_LOCK_X"),
                     (double)g_ui_sl_lock_x_offset);
   GlobalVariablesFlush();
}

// Synchronize every chart-menu change immediately with the EA runtime
// property mirror. MQL5 input variables themselves are read-only after
// initialization, so the live values below are the authoritative settings
// used by signal, order, SL and position-management logic.
void UISyncRuntimeProperties(const string source)
{
   // Runtime menu values stay in memory while the EA is attached.
   // They are written as one-shot state only from OnDeinit(REASON_CHARTCHANGE),
   // so a fresh attachment always starts from the declared input defaults.
   PrintFormat(
      "[RUNTIME PROPERTY SYNC] %s | STRATEGY=%s | SIGNAL=%s | AUTO=%s | SIGNAL_DIR=%s | AUTO_DIR=%s | TF=%s | LOT=%.8f | SL=%.4f%% | ADD=%d | ALERT=%d",
      source,
      (g_selected_strategy == STRATEGY_TREND ? "TREND" : "RANGE"),
      (g_signal_enabled ? "ON" : "OFF"),
      (g_auto_trading ? "ON" : "OFF"),
      SignalDirectionName(),
      AutoDirectionName(),
      UITFName(g_signal_tf),
      g_ui_lots,
      g_stop_loss_percent,
      g_max_additional_entries,
      g_minimum_alert_score);
}

bool UIRestoreChartChangeState()
{
   if(!GlobalVariableCheck(UIStateKey("VALID")))
      return false;

   if(GlobalVariableCheck(UIStateKey("STRATEGY")))
   {
      const int saved_strategy =
         (int)GlobalVariableGet(UIStateKey("STRATEGY"));
      if(saved_strategy == (int)STRATEGY_RANGE)
         g_selected_strategy = STRATEGY_RANGE;
      else
         g_selected_strategy = STRATEGY_RANGE;
   }

   if(GlobalVariableCheck(UIStateKey("POSITION_STRATEGY")))
   {
      const int saved_position_strategy =
         (int)GlobalVariableGet(UIStateKey("POSITION_STRATEGY"));
      if(saved_position_strategy == (int)STRATEGY_TREND)
         g_position_strategy = STRATEGY_TREND;
      else
         g_position_strategy = STRATEGY_RANGE;
   }

   if(GlobalVariableCheck(UIStateKey("POSITION_STRATEGY_LOCKED")))
      g_position_strategy_locked =
         GlobalVariableGet(UIStateKey("POSITION_STRATEGY_LOCKED")) > 0.5;

   g_signal_tf =
      (ENUM_TIMEFRAMES)(int)GlobalVariableGet(UIStateKey("SIGNAL_TF"));
   g_trading_tf = g_signal_tf;
   g_assist_state_tf_runtime = g_trading_tf;
   g_signal_direction =
      (ENUM_SIGNAL_DIRECTION)(int)GlobalVariableGet(UIStateKey("SIGNAL_DIR"));
   g_trade_direction =
      (ENUM_TRADE_DIRECTION)(int)GlobalVariableGet(UIStateKey("TRADE_DIR"));
   g_ui_lots = NormalizeVolume(GlobalVariableGet(UIStateKey("LOTS")));
   g_stop_loss_percent =
      GlobalVariableGet(UIStateKey("SL_PERCENT"));
   g_max_additional_entries =
      (int)GlobalVariableGet(UIStateKey("MAX_ADD"));
   g_signal_enabled =
      GlobalVariableGet(UIStateKey("SIGNAL_ON")) > 0.5;
   g_auto_trading =
      GlobalVariableGet(UIStateKey("AUTO_ON")) > 0.5;
   g_terminal_alert =
      GlobalVariableGet(UIStateKey("SYS_ALERT")) > 0.5;
   if(GlobalVariableCheck(UIStateKey("WATCH_MODE")))
   {
      const int saved_watch_mode =
         (int)GlobalVariableGet(UIStateKey("WATCH_MODE"));
      if(saved_watch_mode>=(int)WATCH_MODE_OFF &&
         saved_watch_mode<=(int)WATCH_MODE_CHART_ALERT)
         g_watch_mode=(ENUM_WATCH_DISPLAY_MODE)saved_watch_mode;
   }
   else if(GlobalVariableCheck(UIStateKey("WATCH_ALERT")))
      g_watch_mode = GlobalVariableGet(UIStateKey("WATCH_ALERT")) > 0.5 ?
                     WATCH_MODE_CHART_ALERT : WATCH_MODE_OFF;
   // If neither preserved key exists, keep the v4.02 fresh-attach default:
   // WATCH_MODE_CHART_ALERT.
   g_mobile_alert =
      GlobalVariableGet(UIStateKey("MOB_ALERT")) > 0.5;
   if(GlobalVariableCheck(UIStateKey("ALERT_SCORE")))
   {
      const int saved_alert_score =
         (int)GlobalVariableGet(UIStateKey("ALERT_SCORE"));
      // v4.02: zero is a first-class persisted state meaning score-alert OFF.
      // Nonzero legacy/runtime values are still normalized to the supported
      // 50..90 selector range.
      g_minimum_alert_score =
         (saved_alert_score<=0 ? 0 :
          (int)MathMax(50,MathMin(90,saved_alert_score)));
   }
   g_ui_buy =
      GlobalVariableGet(UIStateKey("BUY_SIDE")) > 0.5;

   g_reinit_owner_snapshot_valid =
      GlobalVariableCheck(UIStateKey("OWNER_VALID")) &&
      GlobalVariableGet(UIStateKey("OWNER_VALID")) > 0.5;
   if(g_reinit_owner_snapshot_valid)
   {
      g_reinit_saved_assist_state = GlobalVariableCheck(UIStateKey("OWNER_ASSIST_STATE")) ? (int)GlobalVariableGet(UIStateKey("OWNER_ASSIST_STATE")) : (int)JTA_ASSIST_NEUTRAL;
      g_reinit_saved_established_side = GlobalVariableCheck(UIStateKey("OWNER_EST_SIDE")) ? (int)GlobalVariableGet(UIStateKey("OWNER_EST_SIDE")) : 0;
      g_reinit_saved_established_time = GlobalVariableCheck(UIStateKey("OWNER_EST_TIME")) ? (datetime)GlobalVariableGet(UIStateKey("OWNER_EST_TIME")) : 0;
      g_reinit_saved_direction_anchor = GlobalVariableCheck(UIStateKey("OWNER_ANCHOR")) ? (int)GlobalVariableGet(UIStateKey("OWNER_ANCHOR")) : 0;
      g_reinit_saved_watch_owner_side = GlobalVariableCheck(UIStateKey("OWNER_WATCH_SIDE")) ? (int)GlobalVariableGet(UIStateKey("OWNER_WATCH_SIDE")) : 0;
      g_reinit_saved_watch_owner_time = GlobalVariableCheck(UIStateKey("OWNER_WATCH_TIME")) ? (datetime)GlobalVariableGet(UIStateKey("OWNER_WATCH_TIME")) : 0;
      g_reinit_saved_watch_owner_high = GlobalVariableCheck(UIStateKey("OWNER_WATCH_HIGH")) ? GlobalVariableGet(UIStateKey("OWNER_WATCH_HIGH")) : 0.0;
      g_reinit_saved_watch_owner_low = GlobalVariableCheck(UIStateKey("OWNER_WATCH_LOW")) ? GlobalVariableGet(UIStateKey("OWNER_WATCH_LOW")) : 0.0;
      g_reinit_saved_long_weak_armed = GlobalVariableCheck(UIStateKey("OWNER_WEAK_LONG_ARMED")) ? GlobalVariableGet(UIStateKey("OWNER_WEAK_LONG_ARMED")) > 0.5 : true;
      g_reinit_saved_short_weak_armed = GlobalVariableCheck(UIStateKey("OWNER_WEAK_SHORT_ARMED")) ? GlobalVariableGet(UIStateKey("OWNER_WEAK_SHORT_ARMED")) > 0.5 : true;
      g_reinit_saved_last_accel_side = GlobalVariableCheck(UIStateKey("OWNER_ACCEL_SIDE")) ? (int)GlobalVariableGet(UIStateKey("OWNER_ACCEL_SIDE")) : 0;
      g_reinit_saved_last_accel_time = GlobalVariableCheck(UIStateKey("OWNER_ACCEL_TIME")) ? (datetime)GlobalVariableGet(UIStateKey("OWNER_ACCEL_TIME")) : 0;
      g_reinit_saved_accel_owner_side = GlobalVariableCheck(UIStateKey("OWNER_ACTIVE_ACCEL_SIDE")) ? (int)GlobalVariableGet(UIStateKey("OWNER_ACTIVE_ACCEL_SIDE")) : 0;
      g_reinit_saved_accel_owner_watch_time = GlobalVariableCheck(UIStateKey("OWNER_ACTIVE_ACCEL_WATCH_TIME")) ? (datetime)GlobalVariableGet(UIStateKey("OWNER_ACTIVE_ACCEL_WATCH_TIME")) : 0;
      g_reinit_saved_accel_owner_confirmed = GlobalVariableCheck(UIStateKey("OWNER_ACTIVE_ACCEL_CONFIRMED")) ? GlobalVariableGet(UIStateKey("OWNER_ACTIVE_ACCEL_CONFIRMED")) > 0.5 : false;
      g_reinit_saved_chart_accel_publish_count = GlobalVariableCheck(UIStateKey("OWNER_CHART_ACCEL_COUNT")) ? (int)GlobalVariableGet(UIStateKey("OWNER_CHART_ACCEL_COUNT")) : 0;
      g_reinit_saved_pending_reverse_side = GlobalVariableCheck(UIStateKey("OWNER_PENDING_REVERSE_SIDE")) ? (int)GlobalVariableGet(UIStateKey("OWNER_PENDING_REVERSE_SIDE")) : 0;
      g_reinit_saved_pending_reverse_watch_time = GlobalVariableCheck(UIStateKey("OWNER_PENDING_REVERSE_WATCH_TIME")) ? (datetime)GlobalVariableGet(UIStateKey("OWNER_PENDING_REVERSE_WATCH_TIME")) : 0;
      g_reinit_saved_pending_reverse_requires_accel = GlobalVariableCheck(UIStateKey("OWNER_PENDING_REVERSE_REQUIRES_ACCEL")) ? GlobalVariableGet(UIStateKey("OWNER_PENDING_REVERSE_REQUIRES_ACCEL")) > 0.5 : false;
      g_reinit_saved_pending_reverse_accel_confirmed = GlobalVariableCheck(UIStateKey("OWNER_PENDING_REVERSE_ACCEL_CONFIRMED")) ? GlobalVariableGet(UIStateKey("OWNER_PENDING_REVERSE_ACCEL_CONFIRMED")) > 0.5 : false;
      g_reinit_saved_pending_reverse_accel_time = GlobalVariableCheck(UIStateKey("OWNER_PENDING_REVERSE_ACCEL_TIME")) ? (datetime)GlobalVariableGet(UIStateKey("OWNER_PENDING_REVERSE_ACCEL_TIME")) : 0;
      g_reinit_saved_pending_reverse_exit_obligation = GlobalVariableCheck(UIStateKey("OWNER_PENDING_REVERSE_EXIT_OBLIGATION")) ? GlobalVariableGet(UIStateKey("OWNER_PENDING_REVERSE_EXIT_OBLIGATION")) > 0.5 : false;
      g_reinit_saved_pre_rearm_exit_obligation = GlobalVariableCheck(UIStateKey("OWNER_PRE_REARM_EXIT_OBLIGATION")) ? GlobalVariableGet(UIStateKey("OWNER_PRE_REARM_EXIT_OBLIGATION")) > 0.5 : false;
      g_reinit_saved_pre_rearm_exit_recovery_side = GlobalVariableCheck(UIStateKey("OWNER_PRE_REARM_EXIT_RECOVERY_SIDE")) ? (int)GlobalVariableGet(UIStateKey("OWNER_PRE_REARM_EXIT_RECOVERY_SIDE")) : 0;
      g_reinit_saved_pre_rearm_exit_owner_side = GlobalVariableCheck(UIStateKey("OWNER_PRE_REARM_EXIT_OWNER_SIDE")) ? (int)GlobalVariableGet(UIStateKey("OWNER_PRE_REARM_EXIT_OWNER_SIDE")) : 0;
      g_reinit_saved_pre_rearm_exit_owner_time = GlobalVariableCheck(UIStateKey("OWNER_PRE_REARM_EXIT_OWNER_TIME")) ? (datetime)GlobalVariableGet(UIStateKey("OWNER_PRE_REARM_EXIT_OWNER_TIME")) : 0;
      g_reinit_saved_pre_rearm_execution_owner_side = GlobalVariableCheck(UIStateKey("OWNER_PRE_REARM_EXEC_SIDE")) ? (int)GlobalVariableGet(UIStateKey("OWNER_PRE_REARM_EXEC_SIDE")) : 0;
      g_reinit_saved_pre_rearm_execution_owner_time = GlobalVariableCheck(UIStateKey("OWNER_PRE_REARM_EXEC_TIME")) ? (datetime)GlobalVariableGet(UIStateKey("OWNER_PRE_REARM_EXEC_TIME")) : 0;
      g_reinit_saved_pre_rearm_execution_owner_high = GlobalVariableCheck(UIStateKey("OWNER_PRE_REARM_EXEC_HIGH")) ? GlobalVariableGet(UIStateKey("OWNER_PRE_REARM_EXEC_HIGH")) : 0.0;
      g_reinit_saved_pre_rearm_execution_owner_low = GlobalVariableCheck(UIStateKey("OWNER_PRE_REARM_EXEC_LOW")) ? GlobalVariableGet(UIStateKey("OWNER_PRE_REARM_EXEC_LOW")) : 0.0;
      g_prezero_reentry_armed = GlobalVariableCheck(UIStateKey("OWNER_PREZERO_REENTRY_ARMED")) ? GlobalVariableGet(UIStateKey("OWNER_PREZERO_REENTRY_ARMED")) > 0.5 : false;
      g_prezero_reentry_side = GlobalVariableCheck(UIStateKey("OWNER_PREZERO_REENTRY_SIDE")) ? (int)GlobalVariableGet(UIStateKey("OWNER_PREZERO_REENTRY_SIDE")) : 0;
      g_prezero_reentry_exit_time = GlobalVariableCheck(UIStateKey("OWNER_PREZERO_REENTRY_EXIT_TIME")) ? (datetime)GlobalVariableGet(UIStateKey("OWNER_PREZERO_REENTRY_EXIT_TIME")) : 0;
   }

   // v3.81: earned protection is one-shot restored only for the same live
   // managed side. A flat position, opposite side, or missing ownership data
   // intentionally discards the snapshot.
   const int live_protected_side = ManagedPositionSide();
   const int saved_protected_side =
      GlobalVariableCheck(UIStateKey("PROTECT_SIDE")) ?
      (int)GlobalVariableGet(UIStateKey("PROTECT_SIDE")) : 0;
   if(live_protected_side != 0 && live_protected_side == saved_protected_side)
   {
      if(GlobalVariableCheck(UIStateKey("HIGHEST_PROFIT_R")))
         g_highest_profit_r = MathMax(0.0,
            GlobalVariableGet(UIStateKey("HIGHEST_PROFIT_R")));

      const bool saved_floor_active =
         GlobalVariableCheck(UIStateKey("VIRTUAL_FLOOR_ACTIVE")) &&
         GlobalVariableGet(UIStateKey("VIRTUAL_FLOOR_ACTIVE")) > 0.5;
      const int saved_floor_side =
         GlobalVariableCheck(UIStateKey("VIRTUAL_FLOOR_SIDE")) ?
         (int)GlobalVariableGet(UIStateKey("VIRTUAL_FLOOR_SIDE")) : 0;
      const double saved_floor_r =
         GlobalVariableCheck(UIStateKey("VIRTUAL_FLOOR_R")) ?
         GlobalVariableGet(UIStateKey("VIRTUAL_FLOOR_R")) : 0.0;
      const double saved_floor_price =
         GlobalVariableCheck(UIStateKey("VIRTUAL_FLOOR_PRICE")) ?
         GlobalVariableGet(UIStateKey("VIRTUAL_FLOOR_PRICE")) : 0.0;

      if(saved_floor_active && saved_floor_side == live_protected_side &&
         saved_floor_r > 0.0 && saved_floor_price > 0.0)
      {
         g_initial_virtual_profit_floor_active = true;
         g_initial_virtual_profit_floor_side = saved_floor_side;
         g_initial_virtual_profit_floor_r = saved_floor_r;
         g_initial_virtual_profit_floor_price = saved_floor_price;
         g_initial_virtual_profit_floor_time =
            GlobalVariableCheck(UIStateKey("VIRTUAL_FLOOR_TIME")) ?
            (datetime)GlobalVariableGet(UIStateKey("VIRTUAL_FLOOR_TIME")) : 0;
      }
   }

   if(GlobalVariableCheck(UIStateKey("MAIN_X")))
      g_ui_x=(int)GlobalVariableGet(UIStateKey("MAIN_X"));
   if(GlobalVariableCheck(UIStateKey("TP_X")))
      g_ui_tp_x=(int)GlobalVariableGet(UIStateKey("TP_X"));
   if(GlobalVariableCheck(UIStateKey("SL_X")))
      g_ui_sl_x=(int)GlobalVariableGet(UIStateKey("SL_X"));

   // UICreate() uses this one-shot marker to preserve the restored X values
   // instead of re-centering the menu.
   if(GlobalVariableCheck(UIStateKey("MAIN_X")) ||
      GlobalVariableCheck(UIStateKey("TP_X")) ||
      GlobalVariableCheck(UIStateKey("SL_X")))
      GlobalVariableSet(UIStateKey("RESTORED_X_ACTIVE"),1.0);

   g_ui_tp_locked =
      GlobalVariableCheck(UIStateKey("TP_LOCK")) &&
      GlobalVariableGet(UIStateKey("TP_LOCK")) > 0.5;
   g_ui_sl_locked =
      GlobalVariableCheck(UIStateKey("SL_LOCK")) &&
      GlobalVariableGet(UIStateKey("SL_LOCK")) > 0.5;
   if(GlobalVariableCheck(UIStateKey("TP_LOCK_Y")))
      g_ui_tp_lock_y_offset =
         (int)GlobalVariableGet(UIStateKey("TP_LOCK_Y"));
   if(GlobalVariableCheck(UIStateKey("SL_LOCK_Y")))
      g_ui_sl_lock_y_offset =
         (int)GlobalVariableGet(UIStateKey("SL_LOCK_Y"));
   if(GlobalVariableCheck(UIStateKey("TP_LOCK_X")))
      g_ui_tp_lock_x_offset =
         (int)GlobalVariableGet(UIStateKey("TP_LOCK_X"));
   if(GlobalVariableCheck(UIStateKey("SL_LOCK_X")))
      g_ui_sl_lock_x_offset =
         (int)GlobalVariableGet(UIStateKey("SL_LOCK_X"));
   g_ui_restore_locked_offsets = g_ui_tp_locked || g_ui_sl_locked;

   string items[] =
   {
      "VALID", "STRATEGY", "POSITION_STRATEGY",
      "POSITION_STRATEGY_LOCKED",
      "SIGNAL_TF", "SIGNAL_DIR", "TRADE_DIR", "LOTS",
      "SL_PERCENT", "MAX_ADD", "SIGNAL_ON", "AUTO_ON",
      "SYS_ALERT", "WATCH_MODE", "WATCH_ALERT", "MOB_ALERT", "ALERT_SCORE", "BUY_SIDE",
      "OWNER_VALID", "OWNER_ASSIST_STATE", "OWNER_EST_SIDE", "OWNER_EST_TIME",
      "OWNER_ANCHOR", "OWNER_WATCH_SIDE", "OWNER_WATCH_TIME",
      "OWNER_WATCH_HIGH", "OWNER_WATCH_LOW",
      "OWNER_WEAK_LONG_ARMED", "OWNER_WEAK_SHORT_ARMED",
      "OWNER_ACCEL_SIDE", "OWNER_ACCEL_TIME",
      "OWNER_ACTIVE_ACCEL_SIDE", "OWNER_ACTIVE_ACCEL_WATCH_TIME",
      "OWNER_ACTIVE_ACCEL_CONFIRMED", "OWNER_CHART_ACCEL_COUNT",
      "OWNER_PENDING_REVERSE_SIDE", "OWNER_PENDING_REVERSE_WATCH_TIME",
      "OWNER_PENDING_REVERSE_REQUIRES_ACCEL", "OWNER_PENDING_REVERSE_ACCEL_CONFIRMED",
      "OWNER_PENDING_REVERSE_ACCEL_TIME", "OWNER_PENDING_REVERSE_EXIT_OBLIGATION",
      "OWNER_PRE_REARM_EXIT_OBLIGATION", "OWNER_PRE_REARM_EXIT_RECOVERY_SIDE",
      "OWNER_PRE_REARM_EXIT_OWNER_SIDE", "OWNER_PRE_REARM_EXIT_OWNER_TIME",
      "OWNER_PRE_REARM_EXEC_SIDE", "OWNER_PRE_REARM_EXEC_TIME",
      "OWNER_PRE_REARM_EXEC_HIGH", "OWNER_PRE_REARM_EXEC_LOW",
      "PROTECT_SIDE", "HIGHEST_PROFIT_R",
      "VIRTUAL_FLOOR_ACTIVE", "VIRTUAL_FLOOR_SIDE", "VIRTUAL_FLOOR_R",
      "VIRTUAL_FLOOR_PRICE", "VIRTUAL_FLOOR_TIME",
      "MAIN_X", "TP_X", "SL_X",
      "TP_LOCK", "SL_LOCK", "TP_LOCK_Y", "SL_LOCK_Y",
      "TP_LOCK_X", "SL_LOCK_X"
   };
   for(int i = 0; i < ArraySize(items); i++)
      GlobalVariableDel(UIStateKey(items[i]));
   return true;
}

// Preflight the exact indicator buffers used by the closed-bar engines.
// On a new bar MT5 can report the bar before custom indicator buffers have
// finished updating.  Returning false leaves the last-processed bar time
// unchanged, so the same bar is retried on the next tick instead of skipped.
bool SelectedCalculationDataReady()
{
   const int count = MathMax(64,
      MathMax(MathMax(InpDeltaAveragePeriod + 3, InpSignalValidBars + 4),
      MathMax(InpCompressionLookback + 3,
      MathMax(InpSwingLookback + 3,
      MathMax(InpDirectionQualityLookback + 3,
              InpRangeStrengthLookbackBars + 3)))));

   // v6.19 performance: readiness must not copy the same indicator history
   // that ProcessSelectedClosedBar() immediately copies again.  A handle only
   // needs to report enough calculated bars here; the actual buffer reads stay
   // in the strategy engine and therefore occur once.  This also prevents a
   // new-bar custom-indicator warm-up from hammering large CopyBuffer probes
   // on every incoming tick while BarsCalculated is still catching up.
   if(g_calc_macd_handle == INVALID_HANDLE ||
      g_calc_delta_handle == INVALID_HANDLE ||
      g_calc_fast_ma_handle == INVALID_HANDLE ||
      g_calc_slow_ma_handle == INVALID_HANDLE ||
      g_calc_ma70_handle == INVALID_HANDLE ||
      g_calc_ma111_handle == INVALID_HANDLE ||
      g_calc_ma200_handle == INVALID_HANDLE)
      return false;

   if(BarsCalculated(g_calc_macd_handle) < count ||
      BarsCalculated(g_calc_delta_handle) < count ||
      BarsCalculated(g_calc_fast_ma_handle) < count ||
      BarsCalculated(g_calc_slow_ma_handle) < count ||
      BarsCalculated(g_calc_ma70_handle) < count ||
      BarsCalculated(g_calc_ma111_handle) < count ||
      BarsCalculated(g_calc_ma200_handle) < count)
      return false;

   return true;
}


// ===== Simple same-symbol single-instance guard =====
// The terminal chart list is checked directly. No terminal Global Variable is
// used, so large ChartID values cannot lose precision through double storage.
bool g_symbol_instance_lock_acquired = false;
bool g_symbol_instance_lock_lost = false;
bool g_symbol_instance_loss_reported = false;
bool g_duplicate_chart_close_pending = false;

bool JTAChartRunsJoonAutoTrader(const long chart_id)
{
   if(chart_id < 0 || chart_id == ChartID())
      return false;
   if(ChartSymbol(chart_id) != _Symbol)
      return false;

   const string expert_name = ChartGetString(chart_id, CHART_EXPERT_NAME);
   return (StringFind(expert_name, "Joon_Trade_Compass") >= 0 ||
           StringFind(expert_name, "Joon_Trend_Range_AutoTrader") >= 0);
}

void JTAReportDuplicateInstance(const long owner_chart)
{
   const string message = StringFormat(
      "%s: 동일 종목에 Joon AutoTrader가 이미 실행 중입니다. 새로 적용한 중복 차트를 종료합니다. (기존 차트=%I64d)",
      _Symbol, owner_chart);
   Print("[DUPLICATE INSTANCE BLOCK] ", message);
   Alert(message);
}

long JTAFindDuplicateSymbolInstance()
{
   long chart_id = ChartFirst();
   while(chart_id >= 0)
   {
      if(JTAChartRunsJoonAutoTrader(chart_id))
         return chart_id;
      chart_id = ChartNext(chart_id);
   }
   return -1;
}

bool JTAAcquireSymbolInstanceLock()
{
   if((bool)MQLInfoInteger(MQL_TESTER))
      return true;

   g_symbol_instance_lock_acquired = false;
   g_symbol_instance_lock_lost = false;
   g_symbol_instance_loss_reported = false;

   long owner_chart = JTAFindDuplicateSymbolInstance();

   // A chart that has just been closed can remain briefly visible in MT5's
   // ChartFirst/ChartNext list with its old CHART_EXPERT_NAME. Do not classify
   // that transient handle as a live duplicate. Re-scan several times and only
   // block the new chart when the same-symbol EA remains present throughout.
   if(owner_chart >= 0)
   {
      const int recheck_count = 5;
      const int recheck_delay_ms = 200;

      PrintFormat("[DUPLICATE RECHECK START] symbol=%s | candidate_chart=%I64d",
                  _Symbol, owner_chart);

      for(int attempt = 1; attempt <= recheck_count; ++attempt)
      {
         Sleep(recheck_delay_ms);
         owner_chart = JTAFindDuplicateSymbolInstance();

         if(owner_chart < 0)
         {
            PrintFormat("[STALE DUPLICATE CLEARED] symbol=%s | attempt=%d/%d",
                        _Symbol, attempt, recheck_count);
            break;
         }

         if(attempt == recheck_count)
         {
            JTAReportDuplicateInstance(owner_chart);
            return false;
         }
      }
   }

   g_symbol_instance_lock_acquired = true;
   PrintFormat("[INSTANCE ACCEPTED] %s | chart=%I64d", _Symbol, ChartID());
   return true;
}

bool JTAValidateSymbolInstanceOwnership(const bool report_loss=true)
{
   // Direct chart-list validation is only needed during initialization.
   // Returning true here avoids removing a valid running instance later.
   return true;
}

void JTARefreshSymbolInstanceLock()
{
   // No heartbeat or Global Variable ownership is used.
}

void JTAReleaseSymbolInstanceLock()
{
   g_symbol_instance_lock_acquired = false;
   g_symbol_instance_lock_lost = false;
}



int OnInit()
{
   JTC_TurnClearChart();
   JTC_TurnOrderReset();
   if(InpTurnTradeEnabled && (!InpTurnPreEnabled ||
      ((bool)MQLInfoInteger(MQL_TESTER) ? _Period : InpSignalTF)!=PERIOD_M3))
   {Print("TURN order mode requires M3 and InpTurnPreEnabled=true");return INIT_PARAMETERS_INCORRECT;}
   if(InpTurnLeftBars<2 || InpTurnLeftBars>12 ||
      InpTurnMinReboundATR<0.0 || InpTurnMaxDistanceATR<InpTurnMinReboundATR ||
      InpTurnMomentumDeadzoneATR<0.0 || InpTurnSameSideCooldownBars<1 ||
      InpTurnSameSideCooldownBars>100 || InpTurnChartHistoryBars<1 || InpTurnChartHistoryBars>20000)
   {Print("v8.285 TURN PRE: invalid input parameters");return INIT_PARAMETERS_INCORRECT;}

   g_startup_rebuild_ready=false;
   g_startup_rebuild_reconcile_pending=false;
   g_startup_rebuild_in_progress=false;
   g_startup_rebuild_last_probe_msc=0;
   g_startup_rebuild_last_full_attempt_msc=0;
   InvalidateMarketSnapshot();
   ZeroMemory(g_fast_indicator_cache);
   g_ui_force_refresh = true;
   g_selected_strategy = STRATEGY_RANGE;
   g_position_strategy = g_selected_strategy;
   g_position_strategy_locked = false;
   // v5.97: print the exact invalid input before INIT_PARAMETERS_INCORRECT.
#define JTA_INIT_FAIL(MSG) { Print("ONINIT INPUT INVALID | ",MSG); return INIT_PARAMETERS_INCORRECT; }
   if(InpLots<=0.0) JTA_INIT_FAIL(StringFormat("InpLots=%.8f | REQUIRED > 0",InpLots));
   if(InpSignalValidBars<1) JTA_INIT_FAIL(StringFormat("InpSignalValidBars=%d | REQUIRED >= 1",InpSignalValidBars));
   if(InpDeltaAveragePeriod<2) JTA_INIT_FAIL(StringFormat("InpDeltaAveragePeriod=%d | REQUIRED >= 2",InpDeltaAveragePeriod));
   if(InpSignalDeltaMultiplier<=0.0 || InpSignalDeltaMultiplier>InpEntryDeltaMultiplier)
      JTA_INIT_FAIL(StringFormat("SignalDelta=%.4f EntryDelta=%.4f | REQUIRED 0 < SignalDelta <= EntryDelta",InpSignalDeltaMultiplier,InpEntryDeltaMultiplier));
   if(InpRangeStopLossPercent<=0.0) JTA_INIT_FAIL(StringFormat("InpRangeStopLossPercent=%.4f | REQUIRED > 0",InpRangeStopLossPercent));
   if(InpDefaultAdditionalEntries<0)
      JTA_INIT_FAIL(StringFormat("InpDefaultAdditionalEntries=%d | REQUIRED >= 0",InpDefaultAdditionalEntries));
   if(InpFastMAPeriod<1 || InpSlowMAPeriod<=InpFastMAPeriod ||
      InpTrendMAPeriod<=InpSlowMAPeriod || InpSupportMAPeriod<=InpTrendMAPeriod ||
      InpLongMAPeriod<=InpSupportMAPeriod)
      JTA_INIT_FAIL(StringFormat("MA periods Fast=%d Slow=%d Trend=%d Support=%d Long=%d | REQUIRED strictly increasing",
         InpFastMAPeriod,InpSlowMAPeriod,InpTrendMAPeriod,InpSupportMAPeriod,InpLongMAPeriod));
   if(InpProfitGuardActivationPercent<=0.0 || InpProfitGuardLockPercent<0.0 ||
      InpProfitGuardLockPercent>=InpProfitGuardActivationPercent)
      JTA_INIT_FAIL(StringFormat("ProfitGuard Activation=%.4f Lock=%.4f | REQUIRED Activation>0 and 0<=Lock<Activation",
         InpProfitGuardActivationPercent,InpProfitGuardLockPercent));
   if(InpHoldScoreStrongThreshold<1 || InpHoldScoreStrongThreshold>100 ||
      InpHoldScoreTrailingThreshold<1 || InpHoldScoreTrailingThreshold>=InpHoldScoreStrongThreshold ||
      InpHoldScorePartialThreshold<1 || InpHoldScorePartialThreshold>=InpHoldScoreTrailingThreshold)
      JTA_INIT_FAIL(StringFormat("Hold scores Partial=%d Trailing=%d Strong=%d | REQUIRED 1<=Partial<Trailing<Strong<=100",
         InpHoldScorePartialThreshold,InpHoldScoreTrailingThreshold,InpHoldScoreStrongThreshold));
   if(InpRangeCenterProgress<=0.0 || InpRangeCenterProgress>=InpRangeTargetProgress ||
      InpRangeTargetProgress>1.0)
      JTA_INIT_FAIL(StringFormat("Range progress Center=%.4f Target=%.4f | REQUIRED 0<Center<Target<=1",
         InpRangeCenterProgress,InpRangeTargetProgress));
   if(InpWatchPrep2Score<1 || InpWatchPrep3Score<=InpWatchPrep2Score ||
      InpWatchReadyScore<=InpWatchPrep3Score || InpWatchReadyScore>100 ||
      InpWatchResetScore<0 || InpWatchResetScore>=InpWatchPrep2Score)
      JTA_INIT_FAIL(StringFormat("WATCH scores Reset=%d Prep2=%d Prep3=%d Ready=%d | REQUIRED 0<=Reset<Prep2<Prep3<Ready<=100",
         InpWatchResetScore,InpWatchPrep2Score,InpWatchPrep3Score,InpWatchReadyScore));
   if(InpTradingTFDirectionMinimumScore<1 || InpTradingTFDirectionMinimumScore>100 ||
      InpTradingTFDirectionStrongScore<InpTradingTFDirectionMinimumScore ||
      InpTradingTFDirectionStrongScore>100)
      JTA_INIT_FAIL(StringFormat("M5 Direction Minimum=%d Strong=%d | REQUIRED 1<=Minimum<=Strong<=100",
         InpTradingTFDirectionMinimumScore,InpTradingTFDirectionStrongScore));
   if(InpPreDirectionReleaseSignals<1 || InpPreDirectionReleaseScore<1 ||
      InpPreDirectionReleaseScore>100)
      JTA_INIT_FAIL(StringFormat("PreDirection ReleaseSignals=%d ReleaseScore=%d | REQUIRED Signals>=1 and Score 1..100",
         InpPreDirectionReleaseSignals,InpPreDirectionReleaseScore));

   if(InpLots <= 0.0 ||
      InpSignalValidBars < 1 ||
      InpDeltaAveragePeriod < 2 ||
      InpSignalDeltaMultiplier <= 0.0 ||
      InpSignalDeltaMultiplier > InpEntryDeltaMultiplier ||
      InpEntryDeltaMultiplier <= 0.0 ||
      InpEmergencyDeltaMultiplier <= 0.0 ||
      InpExitConfirmBars < 1 ||
      InpCooldownBars < 0 ||
      InpStopLossCooldownBars < 0 ||
      InpDefaultAdditionalEntries < 0 ||
      InpFastMAPeriod < 1 ||
      InpSlowMAPeriod <= InpFastMAPeriod ||
      InpPullbackLookbackBars < 2 ||
      InpPullbackTolerancePoints < 0.0 ||
      InpMaximumEntryDeviationPoints < 0.0 ||
      InpMaximumOrderFailures < 0 ||
      InpBothDirectionMinimumScoreGap < 0 ||
      InpFastMomentumWindowSeconds < 1 ||
      InpFastMomentumMinimumTicks < 3 ||
      InpFastMomentumMinimumTicks > FAST_TICK_CAPACITY ||
      InpFastMomentumDirectionalRatio <= 0.50 ||
      InpFastMomentumDirectionalRatio > 1.0 ||
      InpFastMomentumMinimumMovePercent <= 0.0 ||
      InpFastMomentumBreakoutLookbackTicks < 3 ||
      InpFastMomentumBreakoutLookbackTicks >= FAST_TICK_CAPACITY ||
      InpFastMomentumBreakoutBufferPoints < 0.0 ||
      InpFastMomentumMaximumSpreadPoints < 0.0 ||
      InpFastMomentumMaximumSpreadToMoveRatio <= 0.0 ||
      InpFastMomentumMaximumSpreadToMoveRatio >= 1.0 ||
      InpDirectionQualityLookback < 3 ||
      InpDirectionDeltaPersistenceBars < 1 ||
      InpDirectionLateDistanceRange <= 0.0 ||
      InpDirectionExtremeDeltaMultiplier <= 0.0 ||
      InpDirectionLateTrendPenalty < 0 ||
      InpPatternRangeLookback < 5 ||
      InpRangeEdgeZone <= 0.0 || InpRangeEdgeZone >= 0.5 ||
      InpRejectionWickBodyRatio <= 0.0 ||
      InpMinimumPatternBodyRatio < 0.0 ||
      InpMinimumPatternBodyRatio >= 1.0 ||
      InpRangeLocationLookbackBars < 10 ||
      InpRangeLocationMaximumScore < 0 ||
      InpRangeMinimumWidthPoints < 0.0 ||
      InpATRChaseLookbackBars < 2 ||
      InpATRCalculationPeriod < 3 ||
      InpATRChaseMaximumMove <= 0.0 ||
      InpBreakoutBufferATR < 0.0 ||
      InpDeltaExhaustionLookback < 2 ||
      InpDeltaMinimumStrengthRatio <= 0.0 ||
      InpRangeStrengthLookbackBars < 5 ||
      InpRangeMACDStrengthFactor <= 0.0 ||
      InpRangeDeltaStrengthFactor <= 0.0 ||
      InpTrendStrengthLookbackBars < 5 ||
      InpTrendMACDStrengthFactor <= 0.0 ||
      InpTrendDeltaStrengthFactor <= 0.0 ||
      InpRangeStopLossPercent <= 0.0 ||
      InpMinimumAdditionalEntryBars < 1 ||
      InpMinimumAdditionalProgressR < 0.0 ||
      InpRangeTriggerMinDistanceRange < 0.0 ||      InpRangeTriggerEntryExpiryBars < 1 ||
      InpEarlyFailureCheckBars < 0 ||
      InpEarlyFailureMaximumR < 0.0 ||
      InpRangeSimpleHoldMinimumBars < 0 ||
      InpProfitGuardActivationPercent <= 0.0 ||
      InpProfitGuardLockPercent < 0.0 ||
      InpProfitGuardLockPercent >= InpProfitGuardActivationPercent ||
      InpProfitGuardMaximumGivebackPercent <= 0.0 ||
      InpStrongHoldMaximumGivebackPercent < InpProfitGuardMaximumGivebackPercent ||
      InpHoldScoreStrongThreshold < 1 ||
      InpHoldScoreStrongThreshold > 100 ||
      InpHoldScoreTrailingThreshold < 1 ||
      InpHoldScoreTrailingThreshold >= InpHoldScoreStrongThreshold ||
      InpHoldScorePartialThreshold < 1 ||
      InpHoldScorePartialThreshold >= InpHoldScoreTrailingThreshold ||
      InpHoldScorePartialClosePercent <= 0.0 ||
      InpHoldScorePartialClosePercent >= 100.0 ||
      InpStrongHoldGivebackUnder2R <= 0.0 ||
      InpStrongHoldGivebackUnder3R <= 0.0 ||
      InpStrongHoldGivebackOver3R <= 0.0 ||
      InpPatternLifecycleLookback < 6 ||
      InpPatternOppositeDeltaExtreme < 1.0 ||
      InpPatternCompressionRatio <= 0.0 || InpPatternCompressionRatio >= 1.0 ||
      InpPatternRangeMaximumAdjustment < 0 || InpPatternRangeMaximumAdjustment > 20 ||
      InpRangeMaximumHoldingBars < 0 ||
      InpRangeWeaknessConfirmBars < 1 ||
      InpRangePartialMinimumPercent < 0.0 ||
      InpRangeCenterProgress <= 0.0 ||
      InpRangeCenterProgress >= InpRangeTargetProgress ||
      InpRangeTargetProgress > 1.0 ||
      InpChaseTrendLookbackBars < 3 ||
      InpChaseMACDMinimumBars < 1 ||
      InpChaseMACDMinimumBars > InpChaseTrendLookbackBars ||
      InpChaseDeltaMinimumBars < 1 ||
      InpChaseDeltaMinimumBars > InpChaseTrendLookbackBars ||
      InpChaseTrendMinimumConditions < 1 ||
      InpChaseTrendMinimumConditions > 5 ||
      InpChaseWeaknessConfirmBars < 1 ||
      InpChaseStrongGivebackPercent <= 0.0 ||
      InpChaseWeakGivebackPercent <= 0.0 ||
      InpChaseStrongGivebackPercent < InpChaseWeakGivebackPercent ||
      InpShortTermBreakEvenPercent <= 0.0 ||
      InpShortTermWeakExitPercent < InpShortTermBreakEvenPercent ||
      InpShortTermWeakConditions < 1 ||
      InpShortTermWeakConditions > 3 ||
      InpShortTermFinalPercent < InpShortTermWeakExitPercent ||
      InpShortTermBreakEvenLockPercent < 0.0 ||
      InpShortTermBreakEvenLockPercent >=
         InpShortTermBreakEvenPercent ||      InpRangeProfitExitCooldownBars < 2 ||
      InpRangeAveragePeriod < 2 ||
      InpTrendMAPeriod <= InpSlowMAPeriod ||
      InpSupportMAPeriod <= InpTrendMAPeriod ||
      InpLongMAPeriod <= InpSupportMAPeriod ||
      InpDominanceLookback < 1 ||
      InpDominanceMinBars < 1 ||
      InpDominanceMinBars > InpDominanceLookback ||
      InpDominanceWeakLevel <= 0.0 ||
      InpDominanceStrongLevel <= InpDominanceWeakLevel ||
      InpSwingLookback < 3 ||
      InpCompressionRecentBars < 3 ||
      InpCompressionLookback <= InpCompressionRecentBars + 2 ||
      InpCompressionRatio <= 0.0 || InpCompressionRatio >= 1.0 ||
      InpBreakoutVolumeFactor < 1.0 ||
      InpWatchScore < 1 || InpEntryScore < InpWatchScore ||
      InpConfirmEntryScore < InpEntryScore ||
      InpStrongSignalScore < InpConfirmEntryScore ||
      InpRangeSignalMinimumGap < 0 ||
      InpRangeEarlyTurnBonus < 0 ||
      InpRangeEdgePenaltyRelief < 0 ||
      (InpMinimumAlertScore != 0 &&
       (InpMinimumAlertScore < 50 || InpMinimumAlertScore > 90)) ||
      InpWatchPrep2Score < 1 ||
      InpWatchPrep3Score <= InpWatchPrep2Score ||
      InpWatchReadyScore <= InpWatchPrep3Score ||
      InpWatchReadyScore > 100 ||
      InpWatchResetScore < 0 || InpWatchResetScore >= InpWatchPrep2Score ||
      InpWatchCooldownBars < 1 || InpWatchRangeLookback < 10 ||
      InpWatchStructureLookback < 4 || InpWatchFreshBars < 1 ||
      InpWatchCompressionRatio <= 0.0 || InpWatchCompressionRatio >= 1.0 ||
      InpMaximumChaseRange < 0.0 ||
      InpTradingTFDirectionMinimumScore < 1 || InpTradingTFDirectionMinimumScore > 100 ||
      InpTradingTFDirectionStrongScore < InpTradingTFDirectionMinimumScore ||
      InpTradingTFDirectionStrongScore > 100 ||
      InpTradingTFDirectionMinimumGap < 0 ||
      InpM15TrendMinimumScore < 1 || InpM15TrendMinimumScore > 100 ||
      InpM15TrendMinimumGap < 0 || InpM4MA7TouchToleranceRange < 0.0 ||
      InpTradingTFMA22TouchToleranceRange < 0.0 ||
      InpPreDirectionReleaseSignals < 1 ||
      InpPreDirectionReleaseScore < 1 ||
      InpPreDirectionReleaseScore > 100)
   {
      Print("ONINIT INPUT INVALID | A less-common validation rule failed. "
            "Check Advanced/Debug Inputs or reset tester Inputs to defaults. "
            "v5.97 diagnostic validation reached the legacy aggregate gate.");
      return INIT_PARAMETERS_INCORRECT;
   }
#undef JTA_INIT_FAIL

   if(!JTAAcquireSymbolInstanceLock())
   {
      // Do not initialize indicators, CSV, UI, or trading resources on the
      // duplicate chart. Close only the newly attached chart from OnTimer;
      // the already-running chart and its managed position remain untouched.
      g_duplicate_chart_close_pending = true;
      EventSetMillisecondTimer(100);
      PrintFormat("[DUPLICATE CHART CLOSE QUEUED] symbol=%s | duplicate_chart=%I64d | period=%s",
                  _Symbol, ChartID(), EnumToString((ENUM_TIMEFRAMES)_Period));
      return INIT_SUCCEEDED;
   }

   // Initialize files and runtime resources only after this chart owns the symbol lock.
   if(!DataExportInitialize())
      Print("[JTA CSV] WARNING: CSV initialization failed. Check Experts log error code.");
   if(InpEnableAutoTradeLog && InpTradeLogPrintFileName)
      Print("AUTO TRADE LOG: MQL5\\Files\\", TradeLogFileName());

   trade.SetExpertMagicNumber(InpMagicNumber);
   trade.SetDeviationInPoints(InpDeviationPoints);
   trade.SetTypeFillingBySymbol(_Symbol);
   trade.SetAsyncMode(false);
   ChartSetInteger(0, CHART_EVENT_MOUSE_MOVE, true);
   EventSetMillisecondTimer(500);
   // v7.30: In Strategy Tester the visual chart timeframe is the tester's
   // actual _Period. Indicators created for any other timeframe are not shown
   // on that visual chart. Therefore tester _Period is the single unified
   // TRADE TF source during testing. Live operation keeps InpSignalTF.
   if((bool)MQLInfoInteger(MQL_TESTER))
      g_signal_tf=(ENUM_TIMEFRAMES)_Period;
   else
      g_signal_tf=InpSignalTF;

   g_trading_tf=g_signal_tf;
   g_assist_state_tf_runtime=g_trading_tf;
   if(g_trading_tf!=PERIOD_M1 && g_trading_tf!=PERIOD_M2 && g_trading_tf!=PERIOD_M3 &&
      g_trading_tf!=PERIOD_M5 && g_trading_tf!=PERIOD_M15)
   {
      Print("ONINIT INPUT INVALID | Unified trading TF supports M1/M2/M3/M5/M15 only.");
      JTAReleaseSymbolInstanceLock();
      return INIT_PARAMETERS_INCORRECT;
   }
   g_signal_direction = InpSignalDirection;
   g_trade_direction = InpTradeDirection;
   g_asset_profile = DetectAssetProfile();

   // Keep all indicator handles created below visible in Visual Tester.
   // No ChartIndicatorAdd/Delete is used anywhere in the EA.
   if((bool)MQLInfoInteger(MQL_TESTER))
      TesterHideIndicators(false);

   // v7.14 RANGE-only: a single Broker SL source remains.
   g_stop_loss_percent = InpRangeStopLossPercent;
   g_ui_buy = InpMenuStartAsBuy;
   g_ui_lots = NormalizeVolume(InpLots);
   g_signal_enabled = InpSignalEnabled;
   const bool tester_auto_start =
      ((bool)MQLInfoInteger(MQL_TESTER) && InpTesterAutoStart);
   const bool auto_started_from_initial_settings =
      (InpAutoTrading || tester_auto_start);
   g_auto_trading =
      InpAutoTrading || tester_auto_start;
   g_terminal_alert = InpTerminalAlert;
   g_mobile_alert = InpMobileAlert;
   g_watch_mode = InpWatchMode;
   g_minimum_alert_score = InpMinimumAlertScore;
   // Strategy Tester/live-property default:
   // 0 disables additional entries; any positive integer allows that many ADD fills.
   // The chart menu can change the count directly while the EA is running.
   g_max_additional_entries = MathMax(0, InpDefaultAdditionalEntries);
   const bool restored_chart_menu = UIRestoreChartChangeState();
   g_startup_rebuild_reconcile_pending=restored_chart_menu;
   // v8.39: Strategy Tester AUTO state is controlled by tester inputs, not by
   // persisted chart GlobalVariables. A stale AUTO_ON=OFF from a prior live
   // chart must never disable tester automation when InpTesterAutoStart=true.
   if((bool)MQLInfoInteger(MQL_TESTER) && InpTesterAutoStart)
      g_auto_trading = true;
   // v7.17: M2 is a supported unified trading timeframe; normalize only unsupported legacy values.
   // Unified runtime supports only the chart-menu set M1/M2/M3/M5/M15.
   if(g_trading_tf!=PERIOD_M1 && g_trading_tf!=PERIOD_M2 && g_trading_tf!=PERIOD_M3 &&
      g_trading_tf!=PERIOD_M5 && g_trading_tf!=PERIOD_M15)
   {
      g_trading_tf=PERIOD_M3;
      g_signal_tf=g_trading_tf;
      g_assist_state_tf_runtime=g_trading_tf;
   }
   if(restored_chart_menu)
   {
      // Reinitialization can race with a manual/broker close. Never keep a
      // stale strategy lock if the position disappeared while the EA reloaded.
      const int restored_position_side = ManagedPositionSide();
      if(restored_position_side == 0)
      {
         g_position_strategy_locked = false;
         g_position_strategy = g_selected_strategy;
      }
   }

   // A normal in-terminal reinitialization restores the exact AUTO state from
   // the one-shot chart snapshot. A fresh initialization with a remaining AUTO
   // latch means the previous terminal session ended while AUTO was armed
   // (normal terminal shutdown, crash, power loss, or forced termination).
   // In that case AUTO must NOT resume. Any managed position is closed first,
   // then the stale session latch is cleared.
   if(!(bool)MQLInfoInteger(MQL_TESTER) && !restored_chart_menu)
   {
      if(UIAutoSessionLatched())
      {
         g_auto_trading = false;
         const int stale_side = ManagedPositionSide();
         if(stale_side != 0)
         {
            const bool closed = CloseManagedPosition(
               "AUTO SESSION LOST: TERMINAL RESTART FAIL-SAFE");
            if(closed)
            {
               UISetAutoSessionLatch(false);
               Print("[AUTO FAIL-SAFE] terminal session ended; managed positions closed; AUTO=OFF");
            }
            else
            {
               // Keep the latch so another initialization/tick can retry. AUTO
               // remains OFF and no new order is permitted.
               Print("[AUTO FAIL-SAFE ERROR] unable to close managed positions after terminal restart; AUTO=OFF; retry required");
            }
         }
         else
         {
            UISetAutoSessionLatch(false);
            Print("[AUTO FAIL-SAFE] stale AUTO session cleared; no managed position; AUTO=OFF");
         }
      }
      else
         g_auto_trading = false;
   }

   UISyncRuntimeProperties(restored_chart_menu ?
                           "INIT RESTORED MENU VALUES" :
                           "INIT INPUT DEFAULTS - AUTO OFF");

   // Unified trading timeframe: Signal, AUTO entry/add, state evaluation and base risk
   // all use AUTO_TF, which is runtime-selectable from the chart menu.
   g_macd_handle =
      iCustom(_Symbol, AUTO_TF,
              "Market\\Joon_MACD_v2_05_OPT_VALIDATION");
   g_delta_handle =
      iCustom(_Symbol, AUTO_TF,
              "Market\\Joon_delta_volume_v1_01_OPT_VALIDATION");
   g_add_ma_handle =
      iMA(_Symbol, AUTO_TF, InpFastMAPeriod,
          0, MODE_SMA, PRICE_CLOSE);
   g_slow_ma_handle =
      iMA(_Symbol, AUTO_TF, InpSlowMAPeriod,
          0, MODE_SMA, PRICE_CLOSE);
   g_ma70_handle =
      iMA(_Symbol, AUTO_TF, InpTrendMAPeriod,
          0, MODE_SMA, PRICE_CLOSE);
   g_ma111_handle =
      iMA(_Symbol, AUTO_TF, InpSupportMAPeriod,
          0, MODE_SMA, PRICE_CLOSE);
   g_ma200_handle =
      iMA(_Symbol, AUTO_TF, InpLongMAPeriod,
          0, MODE_SMA, PRICE_CLOSE);
   // Unified TF: SIGNAL and canonical AUTO always share the
   // exact same indicator instances.
   // Buffer contracts and strategy values are unchanged; only backend handles
   // are shared. ChangeSignalTimeframe() owns safe detach/reattach later.
   g_signal_handles_shared_with_auto=(g_signal_tf==AUTO_TF);
   if(g_signal_handles_shared_with_auto)
   {
      g_signal_macd_handle=g_macd_handle;
      g_signal_delta_handle=g_delta_handle;
      g_signal_fast_ma_handle=g_add_ma_handle;
      g_signal_slow_ma_handle=g_slow_ma_handle;
      g_signal_ma70_handle=g_ma70_handle;
      g_signal_ma111_handle=g_ma111_handle;
      g_signal_ma200_handle=g_ma200_handle;
   }
   else
   {
      g_signal_macd_handle =
         iCustom(_Symbol, g_signal_tf,
                 "Market\\Joon_MACD_v2_05_OPT_VALIDATION");
      g_signal_delta_handle =
         iCustom(_Symbol, g_signal_tf,
                 "Market\\Joon_delta_volume_v1_01_OPT_VALIDATION");
      g_signal_fast_ma_handle =
         iMA(_Symbol, g_signal_tf, InpFastMAPeriod,
             0, MODE_SMA, PRICE_CLOSE);
      g_signal_slow_ma_handle =
         iMA(_Symbol, g_signal_tf, InpSlowMAPeriod,
             0, MODE_SMA, PRICE_CLOSE);
      g_signal_ma70_handle =
         iMA(_Symbol, g_signal_tf, InpTrendMAPeriod,
             0, MODE_SMA, PRICE_CLOSE);
      g_signal_ma111_handle =
         iMA(_Symbol, g_signal_tf, InpSupportMAPeriod,
             0, MODE_SMA, PRICE_CLOSE);
      g_signal_ma200_handle =
         iMA(_Symbol, g_signal_tf, InpLongMAPeriod,
             0, MODE_SMA, PRICE_CLOSE);
   }
   if(g_macd_handle == INVALID_HANDLE ||
      g_delta_handle == INVALID_HANDLE ||
      g_add_ma_handle == INVALID_HANDLE ||
      g_slow_ma_handle == INVALID_HANDLE ||
      g_ma70_handle == INVALID_HANDLE ||
      g_ma111_handle == INVALID_HANDLE ||
      g_ma200_handle == INVALID_HANDLE ||
      g_signal_macd_handle == INVALID_HANDLE ||
      g_signal_delta_handle == INVALID_HANDLE ||
      g_signal_fast_ma_handle == INVALID_HANDLE ||
      g_signal_slow_ma_handle == INVALID_HANDLE ||
      g_signal_ma70_handle == INVALID_HANDLE ||
      g_signal_ma111_handle == INVALID_HANDLE ||
      g_signal_ma200_handle == INVALID_HANDLE)
   {
      Print("Initialization failed. Put both EX5 files in ",
            "MQL5\\Indicators\\Market. Error=", GetLastError());
      JTAReleaseSymbolInstanceLock();
      return INIT_FAILED;
   }

   // v8.76: rebuild the current M3 structure from a bounded recent history
   // window once at startup. Historical replay never submits orders.
   if(M3AutoEngineIsActive() && (bool)MQLInfoInteger(MQL_TESTER))
   {
      // Tester preserves the v8.225 structure startup path. Live M3+Assist is
      // rebuilt together after StateEvaluation handles are initialized below.
      if(!M3WarmupRebuild())
         Print("[M3 WARMUP] structure recovery deferred; waiting for synchronized history");
   }

   // v7.11: initialize the observation-only manual-assist state engine after
   // canonical indicator handles exist so identical timeframes can reuse them.
   if(!StateEvaluationInitialize())
   {
      Print("Initialization failed while creating manual-assist state handles.");
      JTAReleaseSymbolInstanceLock();
      return INIT_FAILED;
   }
   // v8.227: live/restart parity.  Strategy Tester already accumulates the
   // StateEvaluation lifecycle chronologically from its test start, so preserve
   // the legacy one-bar prime there.  Live startup/reinitialization reconstructs
   // recent closed-bar ownership before any chart/CSV consumer sees the state.
   if((bool)MQLInfoInteger(MQL_TESTER))
   {
      StateEvaluationUpdateOnClosedBar();
      // v8.244: tester startup is READY only when the independent M3 warmup
      // also succeeded.  If indicator buffers were not ready in OnInit, the
      // OnTick startup gate retries M3WarmupRebuild() instead of leaving the
      // engine permanently blocked.
      g_startup_rebuild_ready=(!M3AutoEngineIsActive() || g_m3_warmup_complete);
      g_startup_rebuild_reconcile_pending=false;
   }
   else
   {
      if(StateEvaluationWarmupRebuild())
      {
         // v8.243: only a complete chronological replay may open strategy
         // signal/order authority. Consume the latest replayed bucket so the
         // first live tick cannot evaluate shift=1 twice.
         StateEvaluationMarkCurrentBucketConsumed();
         M3AssistReconcileReinitOwnership(restored_chart_menu);
         // v8.261: ACCEL chart limit is session-scoped. A fresh/cold startup
         // starts the visible ACCEL counter at zero even though historical
         // replay reconstructs the current WATCH/ACCEL ownership. Same-session
         // chart/parameter/recompile reinit keeps the exact saved count via
         // M3AssistReconcileReinitOwnership().
         if(!restored_chart_menu)
            g_m3_segment.chart_accel_publish_count=0;
         g_startup_rebuild_reconcile_pending=false;
         g_startup_rebuild_ready=true;
         Print("[STARTUP REBUILD READY] historical ownership reconstruction complete");
      }
      else
      {
         // v8.243: do NOT prime authoritative state from a single latest bar.
         // Keep safety management alive, but block WATCH/ACCEL/DIRECTION and
         // all strategy INITIAL/ADD/EXIT until the full replay succeeds.
         g_startup_rebuild_ready=false;
         g_m3_auto_order_authority_active=false;
         g_status="STARTUP REBUILD PENDING - WAITING FOR HISTORY";
         Print("[STARTUP REBUILD DEFERRED] waiting for synchronized historical data; strategy authority blocked");
      }
   }
   UIRenderAssistState();
   WriteAssistStateCsv();

   // AUTO-start bias must be initialized identically whether AUTO is turned on
   // from the chart button or starts already enabled from Inputs/Strategy Tester.
   // InitializeAutoStartBias() reads the active calculation handles, so bind the
   // unified trading-TF handles first and call it exactly once for this startup path.
   if(auto_started_from_initial_settings && g_auto_trading)
   {
      g_calc_tf = AUTO_TF;
      g_calc_macd_handle = g_macd_handle;
      g_calc_delta_handle = g_delta_handle;
      g_calc_fast_ma_handle = g_add_ma_handle;
      g_calc_slow_ma_handle = g_slow_ma_handle;
      g_calc_ma70_handle = g_ma70_handle;
      g_calc_ma111_handle = g_ma111_handle;
      g_calc_ma200_handle = g_ma200_handle;
      InitializeAutoStartBias();
      PrintFormat("[AUTO START BIAS INIT] source=%s | bias=%s | active=%s",
                  tester_auto_start ? "TESTER" : "INPUT",
                  AutoStartBiasName(),
                  g_auto_start_bias_active ? "YES" : "NO");
   }

   g_last_bar_time = iTime(_Symbol, g_signal_tf, 0);
   g_last_auto_bar_time = iTime(_Symbol, AUTO_TF, 0);
   g_tp_enabled = false;
   g_sl_enabled = true;
   if(g_startup_rebuild_ready)
      g_status = (restored_chart_menu ? "MENU RESTORED - " : "READY - ") +
                 AssetProfileName();
   else
      g_status = "STARTUP REBUILD PENDING - WAITING FOR HISTORY";
   const long margin_mode = AccountInfoInteger(ACCOUNT_MARGIN_MODE);
   if(margin_mode == ACCOUNT_MARGIN_MODE_RETAIL_HEDGING)
   {
      Print("[HEDGING MODE] MANUAL/FOREIGN POSITIONS ARE INDEPENDENT FROM AUTO");
   }
   else
   {
      g_status = "READY - NETTING: SAME-SYMBOL MANUAL TRADING NOT RECOMMENDED";
      Print(g_status);
   }
   g_last_chart_comment = "";
   UICreate();
   RestoreAdditionalEntryState();
   if((bool)MQLInfoInteger(MQL_TESTER))
   {
      PrintFormat("TESTER READY | AUTO=%s | SYMBOL=%s | TRADING_TF=%s",
                  g_auto_trading ? "ON" : "OFF", _Symbol, EnumToString(AUTO_TF));
      PrintFormat("LOT=%.2f | SL=%.2f%% | TRADING_TF=%s",
                  g_ui_lots, g_stop_loss_percent,
                  EnumToString(g_signal_tf));
      Print("[JTA TESTER MONITOR] SIGNAL/ENTRY/ORDER/ADD/OPPOSITE state-change journal logging ENABLED");
   }
   UpdateChartComment();
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   JTC_TurnClearChart();
   ReviewReleaseADX();
   // A duplicate chart never initialized trading/UI resources and must not
   // execute normal session-end logic, because that could affect positions
   // managed by the original chart.
   if(g_duplicate_chart_close_pending)
   {
      EventKillTimer();
      g_duplicate_chart_close_pending = false;
      PrintFormat("[DUPLICATE CHART CLOSED] symbol=%s | chart=%I64d | reason=%d",
                  _Symbol, ChartID(), reason);
      return;
   }
   if(UIShouldPreserveRuntimeState(reason))
   {
      // Chart/parameter/recompile/account/template reinitialization is not an
      // AUTO session end. Preserve the complete live menu/AUTO state and do not
      // close the managed position.
      UISaveChartChangeState();
      PrintFormat("[AUTO STATE PROTECTED] saved before reinit | reason=%d | AUTO=%s",
                  reason, g_auto_trading ? "ON" : "OFF");
   }
   else if(reason == REASON_CLOSE ||
           reason == REASON_REMOVE ||
           reason == REASON_CHARTCLOSE)
   {
      // Once AUTO has been armed, an actual terminal/session end may leave no EA
      // to manage the position. Attempt an immediate fail-safe close. If MT5 is
      // already too far into shutdown for trading, keep the latch; the next
      // startup detects it and closes the managed position before AUTO can run.
      if(UIAutoSessionLatched())
      {
         const int shutdown_side = ManagedPositionSide();
         if(shutdown_side == 0)
         {
            UISetAutoSessionLatch(false);
            PrintFormat("[AUTO SESSION END] no managed position | reason=%d | AUTO=OFF", reason);
         }
         else
         {
            const bool closed = CloseManagedPosition(
               reason == REASON_CLOSE ?
                  "AUTO SESSION END: MT5 TERMINAL CLOSED" :
                  "AUTO SESSION END: EA OR CHART REMOVED");
            if(closed)
            {
               UISetAutoSessionLatch(false);
               PrintFormat("[AUTO SESSION END] managed positions closed | reason=%d | AUTO=OFF", reason);
            }
            else
            {
               PrintFormat("[AUTO SESSION END PENDING] close failed during deinit | reason=%d | retry on next startup", reason);
            }
         }
      }
   }
   // Keep ownership across a same-chart timeframe/parameter/template/recompile
   // reinitialization. The next OnInit has the same ChartID and resumes the
   // lock; a different chart remains blocked. If reinitialization never returns,
   // stale-lock recovery clears it after the heartbeat timeout.
   if(!UIShouldPreserveRuntimeState(reason))
      JTAReleaseSymbolInstanceLock();

   // Persist the final visual state before releasing the shared indicator handles.
   if((bool)MQLInfoInteger(MQL_TESTER) && (bool)MQLInfoInteger(MQL_VISUAL_MODE))
   // Persist every buffered diagnostic row on normal/reinit deinitialization.
   DataExportFlushBufferedDiagnostics(true);
   DataExportFlushLiveBufferedFiles(true);
   CloseAssistStateCsv();
   CloseSignalBarAudit();
   ClosePerformanceAudit();
   StateEvaluationRelease();
   EventKillTimer();
   if(g_macd_handle != INVALID_HANDLE)
      IndicatorRelease(g_macd_handle);
   if(g_delta_handle != INVALID_HANDLE)
      IndicatorRelease(g_delta_handle);
   if(g_add_ma_handle != INVALID_HANDLE)
      IndicatorRelease(g_add_ma_handle);
   if(g_slow_ma_handle != INVALID_HANDLE)
      IndicatorRelease(g_slow_ma_handle);
   if(g_ma70_handle != INVALID_HANDLE)
      IndicatorRelease(g_ma70_handle);
   if(g_ma111_handle != INVALID_HANDLE)
      IndicatorRelease(g_ma111_handle);
   if(g_ma200_handle != INVALID_HANDLE)
      IndicatorRelease(g_ma200_handle);
   // Shared SIGNAL/AUTO handles are released exactly once by the AUTO block
   // above. Dedicated SIGNAL handles are released here.
   if(!g_signal_handles_shared_with_auto)
   {
      if(g_signal_macd_handle != INVALID_HANDLE)
         IndicatorRelease(g_signal_macd_handle);
      if(g_signal_delta_handle != INVALID_HANDLE)
         IndicatorRelease(g_signal_delta_handle);
      if(g_signal_fast_ma_handle != INVALID_HANDLE)
         IndicatorRelease(g_signal_fast_ma_handle);
      if(g_signal_slow_ma_handle != INVALID_HANDLE)
         IndicatorRelease(g_signal_slow_ma_handle);
      if(g_signal_ma70_handle != INVALID_HANDLE)
         IndicatorRelease(g_signal_ma70_handle);
      if(g_signal_ma111_handle != INVALID_HANDLE)
         IndicatorRelease(g_signal_ma111_handle);
      if(g_signal_ma200_handle != INVALID_HANDLE)
         IndicatorRelease(g_signal_ma200_handle);
   }
   g_signal_handles_shared_with_auto=false;
   UIDelete();
   Comment("");
   g_last_chart_comment = "";
}

//+------------------------------------------------------------------+
void OnChartEvent(const int id,
                  const long &lparam,
                  const double &dparam,
                  const string &sparam)
{
   if(g_duplicate_chart_close_pending)
      return;

   if(id == CHARTEVENT_CHART_CHANGE)
   {
      // v6.11: chart scroll/zoom/timeframe changes can emit bursts of
      // CHARTEVENT_CHART_CHANGE events. Do not bypass the existing UI throttle
      // with an immediate full UIRefresh() on every event. Mark the UI dirty
      // and let OnTimer coalesce the burst into one normal throttled refresh.
      // Trading/signal/trigger/hold/risk processing is unchanged.
      RequestUIRefresh();
      return;
   }

   if(id == CHARTEVENT_OBJECT_CLICK)
   {
      if(sparam == UI_LOT_EDIT)
      {
         g_lot_editing = true;
         g_last_lot_edit_text =
            ObjectGetString(0, UI_LOT_EDIT, OBJPROP_TEXT);
         return;
      }
      if(sparam == UI_MAX_ADD_EDIT)
      {
         g_max_add_editing = true;
         g_last_max_add_edit_text = ObjectGetString(0, UI_MAX_ADD_EDIT, OBJPROP_TEXT);
         return;
      }
      if(sparam == UI_SL_PERCENT_EDIT)
      {
         g_sl_percent_editing = true;
         g_last_sl_percent_edit_text =
            ObjectGetString(0, UI_SL_PERCENT_EDIT, OBJPROP_TEXT);
         return;
      }
      if(StringFind(sparam, "JMD_UI_") == 0)
         UIHandleClick(sparam);
      return;
   }

   if(id == CHARTEVENT_OBJECT_ENDEDIT && sparam == UI_LOT_EDIT)
   {
      g_lot_editing = false;
      const double requested =
         UIParseBracketValue(
            ObjectGetString(0, UI_LOT_EDIT, OBJPROP_TEXT));
      if(requested > 0.0)
      {
         g_ui_lots = NormalizeVolume(requested);
         UISyncRuntimeProperties("LOT EDIT COMPLETE");
      }
      UIRefresh();
      return;
   }

   if(id == CHARTEVENT_OBJECT_ENDEDIT && sparam == UI_MAX_ADD_EDIT)
   {
      g_max_add_editing = false;
      const int requested = (int)MathRound(UIParseBracketValue(
         ObjectGetString(0, UI_MAX_ADD_EDIT, OBJPROP_TEXT)));
      g_max_additional_entries = MathMax(0, requested);
      UISyncRuntimeProperties("MAX ADD EDIT COMPLETE");
      UIRefresh();
      return;
   }

   if(id == CHARTEVENT_OBJECT_ENDEDIT &&
      sparam == UI_SL_PERCENT_EDIT)
   {
      g_sl_percent_editing = false;
      const double requested =
         UIParseBracketValue(
            ObjectGetString(0, UI_SL_PERCENT_EDIT, OBJPROP_TEXT));
      if(requested > 0.0 && requested <= 100.0)
      {
         g_stop_loss_percent = requested;
         g_status = "AUTO SL " +
                    UICompactNumber(g_stop_loss_percent, 2) + "%";
         UISyncRuntimeProperties("SL EDIT COMPLETE");
      }
      else
         g_status = "SL% MUST BE ABOVE 0 AND AT MOST 100";
      UIRefresh();
      return;
   }

   if(id != CHARTEVENT_MOUSE_MOVE)
      return;

   // Most mouse-move events occur with no button pressed. Skip them before
   // parsing coordinates/button masks; this keeps chart scrolling and cursor
   // movement from consuming EA CPU while preserving custom panel dragging.
   if(!g_ui_left_down && (sparam == "0" || sparam == ""))
      return;

   const int mouse_x = (int)lparam;
   const int mouse_y = (int)dparam;
   const bool left_down =
      (((int)StringToInteger(sparam) & 1) != 0);

   if(left_down && !g_ui_left_down)
      UIStartDrag(mouse_x, mouse_y);
   else if(left_down && g_ui_dragging)
      UIUpdateDrag(mouse_x, mouse_y);
   else if(!left_down && g_ui_left_down && g_ui_dragging)
      UIEndDrag();

   g_ui_left_down = left_down;
}

//+------------------------------------------------------------------+
bool JTADealBelongsToManagedPosition(const ulong deal_ticket)
{
   if(deal_ticket==0)
      return false;

   const ulong deal_magic=
      (ulong)HistoryDealGetInteger(deal_ticket,DEAL_MAGIC);
   if(deal_magic==InpMagicNumber)
      return true;

   const ENUM_DEAL_ENTRY deal_entry=
      (ENUM_DEAL_ENTRY)HistoryDealGetInteger(deal_ticket,DEAL_ENTRY);
   if(deal_entry!=DEAL_ENTRY_OUT && deal_entry!=DEAL_ENTRY_OUT_BY)
      return false;

   const ulong position_id=
      (ulong)HistoryDealGetInteger(deal_ticket,DEAL_POSITION_ID);
   if(position_id==0)
      return false;

   // Fast path: the active lifecycle already owns this position.
   if(g_trade_cycle.position_id!=0 &&
      g_trade_cycle.position_id==position_id)
      return true;

   // Manual terminal/mobile/web close deals can have DEAL_MAGIC=0.
   // Recover ownership from the position's entry history instead of the
   // closing deal's magic number.
   if(!HistorySelectByPosition(position_id))
      return false;

   const int total=HistoryDealsTotal();
   for(int i=0;i<total;i++)
   {
      const ulong history_deal=HistoryDealGetTicket(i);
      if(history_deal==0)
         continue;

      const ENUM_DEAL_ENTRY history_entry=
         (ENUM_DEAL_ENTRY)HistoryDealGetInteger(history_deal,DEAL_ENTRY);
      if(history_entry!=DEAL_ENTRY_IN &&
         history_entry!=DEAL_ENTRY_INOUT)
         continue;

      if(HistoryDealGetString(history_deal,DEAL_SYMBOL)!=_Symbol)
         continue;

      if((ulong)HistoryDealGetInteger(history_deal,DEAL_MAGIC)==
         InpMagicNumber)
         return true;
   }

   return false;
}

void OnTradeTransaction(const MqlTradeTransaction &transaction,
                        const MqlTradeRequest &request,
                        const MqlTradeResult &result)
{
   if(g_duplicate_chart_close_pending)
      return;

   JRO_InvalidatePositionSnapshot();

   // v6.55: recognize direct operator drag of the native MT5 broker SL line.
   // EA-originated SLTP requests are consumed from the recent ticket+SL queue.
   if(transaction.type==TRADE_TRANSACTION_REQUEST &&
      request.action==TRADE_ACTION_SLTP &&
      request.position>0 &&
      (result.retcode==TRADE_RETCODE_DONE || result.retcode==TRADE_RETCODE_PLACED))
   {
      const double request_sl=NormalizePrice(request.sl);
      if(ManualBrokerSLConsumeEAModify(request.position,request_sl))
         return;

      const ulong manual_ticket=request.position;
      if(PositionSelectByTicket(manual_ticket) &&
         PositionGetString(POSITION_SYMBOL)==_Symbol &&
         (ulong)PositionGetInteger(POSITION_MAGIC)==InpMagicNumber)
      {
         const double actual_sl=PositionGetDouble(POSITION_SL);
         if(actual_sl>0.0)
         {
            ManualBrokerSLSetOwned(manual_ticket);
            g_status=StringFormat("MANUAL BROKER SL OWNERSHIP | TICKET %I64u | %.*f",
                                  manual_ticket,_Digits,NormalizePrice(actual_sl));
            Print(g_status);
         }
      }
      return;
   }

   if(transaction.type != TRADE_TRANSACTION_DEAL_ADD ||
      transaction.deal == 0 ||
      !HistoryDealSelect(transaction.deal))
      return;
   if(HistoryDealGetString(transaction.deal, DEAL_SYMBOL) != _Symbol)
      return;

   // EA-created deals are owned by DEAL_MAGIC. Manual terminal/mobile/web
   // closing deals may carry magic=0, so EXIT ownership is recovered from
   // DEAL_POSITION_ID and the original entry-deal history.
   if(!JTADealBelongsToManagedPosition(transaction.deal))
      return;

   const ENUM_DEAL_ENTRY deal_entry =
      (ENUM_DEAL_ENTRY)HistoryDealGetInteger(transaction.deal, DEAL_ENTRY);
   const ENUM_DEAL_REASON reason =
      (ENUM_DEAL_REASON)HistoryDealGetInteger(transaction.deal, DEAL_REASON);
   const string deal_comment =
      HistoryDealGetString(transaction.deal, DEAL_COMMENT);
   const ENUM_DEAL_TYPE deal_type =
      (ENUM_DEAL_TYPE)HistoryDealGetInteger(transaction.deal, DEAL_TYPE);
   const double deal_price =
      HistoryDealGetDouble(transaction.deal, DEAL_PRICE);
   const double deal_volume_all =
      HistoryDealGetDouble(transaction.deal, DEAL_VOLUME);
   const double deal_net =
      HistoryDealGetDouble(transaction.deal, DEAL_PROFIT) +
      HistoryDealGetDouble(transaction.deal, DEAL_SWAP) +
      HistoryDealGetDouble(transaction.deal, DEAL_COMMISSION) +
      HistoryDealGetDouble(transaction.deal, DEAL_FEE);

   if(deal_entry == DEAL_ENTRY_IN || deal_entry == DEAL_ENTRY_INOUT)
   {
      string event_name = "ENTRY";
      if(StringFind(deal_comment, "stage ") >= 0 ||
         StringFind(deal_comment, "additional entry") >= 0)
         event_name = "ADD_ENTRY";
      else if(StringFind(deal_comment, "RE-ENTRY") >= 0 ||
              StringFind(deal_comment, "REENTRY") >= 0)
         event_name = "REENTRY";

      if(event_name == "ADD_ENTRY")
         g_has_add_entry = true;
      else if(event_name == "REENTRY")
      {
         g_reentry_protection_active = false;
         g_reentry_context.order_pending=false;
         g_reentry_context.active=false;
         g_reentry_context.last_block_reason="REENTRY_DEAL_FILLED";
      }

      const ulong filled_position_id=(ulong)HistoryDealGetInteger(transaction.deal,DEAL_POSITION_ID);
      if(event_name=="ENTRY" || event_name=="REENTRY")
      {
         const datetime deal_time=
            (datetime)HistoryDealGetInteger(transaction.deal,DEAL_TIME);

         // v3.68 INITIAL fill lifecycle synchronization. A successful market
         // order can produce DEAL_ENTRY_IN before PositionSelect/PositionsTotal
         // exposes the new position. The normal OpenPosition() path then exits
         // through POSITION SYNC PENDING. Finalize the canonical INITIAL clock
         // and actual fill here so BarsSinceInitialEntry(), CHASE no-progress,
         // NORMAL early-failure and Hold/Risk age logic cannot remain at 0/-1.
         if(event_name=="ENTRY")
         {
            g_initial_entry_time=deal_time;
            if(g_selected_strategy==STRATEGY_RANGE)
               g_initial_hold_anchor_time=
                  g_pending_initial_hold_anchor_time>0 ?
                  g_pending_initial_hold_anchor_time : deal_time;
            g_last_entry_time=deal_time;
            if(deal_price>0.0)
               g_initial_entry_price=deal_price;
            if(g_initial_entry_lots<=0.0 && deal_volume_all>0.0)
               g_initial_entry_lots=deal_volume_all;

            // Rebase 1R on the actual DEAL fill just as the immediate-position
            // path does. This is strategy-neutral and only repairs the sync
            // window where PositionGetDouble(POSITION_PRICE_OPEN) was skipped.
            const double base_volume=
               g_initial_entry_lots>0.0 ? g_initial_entry_lots : deal_volume_all;
            if(g_initial_entry_price>0.0 && base_volume>0.0)
            {
               const double menu_r_distance=
                  JTAInitialRiskDistancePrice(g_initial_entry_price,base_volume);
               if(menu_r_distance>0.0)
               {
                  g_initial_r_distance=MathMax(menu_r_distance,_Point);
                  g_sl_distance=g_initial_r_distance;
                  const int fill_side=(deal_type==DEAL_TYPE_BUY ? 1 : -1);
                  g_trade_cycle.initial_sl=NormalizePrice(
                     g_initial_entry_price-fill_side*g_initial_r_distance);
               }
            }

            const int fill_side=(deal_type==DEAL_TYPE_BUY ? 1 : -1);
            if(fill_side>0) g_long_regime_traded=true;
            else            g_short_regime_traded=true;
            g_ui_buy=(fill_side>0);
            UIArrangeSide();
            g_additional_entry_count=0;
            g_additional_entry_filled_count=0;
            JTAHoldAnchorSave();
         }

         // Start the alert-cycle net with the actual entry deal net so entry
         // commission/fee is included in the final realized P/L.
         g_alert_cycle_realized_net=deal_net;
         TradeCycleMarkPositionOpen(filled_position_id,deal_time,deal_price);
         JTAAddPersistenceSave();
         g_trade_cycle.entry_deal_ticket=transaction.deal;
         TradeCycleTouch("ENTRY_DEAL_FILLED",event_name,deal_time);
         if(event_name=="ENTRY")
            g_pending_initial_hold_anchor_time=0;
      }
      else if(event_name=="ADD_ENTRY")
       {
          // v5.97: the broker DEAL_TIME is the authoritative layer-HOLD anchor.
          // Capture it for every ADD fill, independent of position-sync timing.
          const datetime add_deal_time=
             (datetime)HistoryDealGetInteger(transaction.deal,DEAL_TIME);

          // ADD entry charges belong to the same trade-cycle realized result.
          g_alert_cycle_realized_net+=deal_net;
          g_trade_cycle.state=JTA_CYCLE_POSITION_OPEN;
          g_trade_cycle.position_id=filled_position_id;
          g_trade_cycle.additional_entry_count=g_additional_entry_count;
          g_trade_cycle.updated_time=TimeCurrent();

          // v3.26: finalize ADD state when the broker deal arrives before the
          // normal order path can see the updated position snapshot.
          if(g_add_position_sync_pending)
          {
             const int pending_stage=MathMax(1,g_add_pending_stage);
             const int pending_side=(g_add_pending_side!=0 ?
                                     g_add_pending_side :
                                     (deal_type==DEAL_TYPE_BUY ? 1 : -1));
             const double pending_volume=(g_add_pending_volume>0.0 ?
                                          g_add_pending_volume : deal_volume_all);

             EnsureManagedStopsProtected(true);

             double pending_r=MathMax(_Point,
                StopDistancePrice(deal_price,pending_volume));
             const ulong sync_ticket=NewestManagedPositionTicket(pending_side);
             if(sync_ticket>0 && PositionSelectByTicket(sync_ticket))
             {
                const double sync_fill=PositionGetDouble(POSITION_PRICE_OPEN);
                const double sync_sl=PositionGetDouble(POSITION_SL);
                if(sync_fill>0.0 && sync_sl>0.0)
                   pending_r=MathAbs(sync_fill-sync_sl);
             }

             const datetime pending_anchor=
                (g_pending_add_hold_anchor_stage==pending_stage &&
                 g_pending_add_hold_anchor_time>0) ?
                 g_pending_add_hold_anchor_time : add_deal_time;
             JTAAddLayerSet(pending_stage,deal_price,add_deal_time,pending_anchor,
                            pending_r,pending_volume);

             g_add_position_sync_pending=false;
             g_add_pending_stage=0;
             g_add_pending_side=0;
             g_add_pending_volume=0.0;
             g_pending_add_hold_anchor_time=0;
             g_pending_add_hold_anchor_stage=0;
             JTAHoldAnchorSave();
             g_status=StringFormat("ADD%d POSITION SYNC CONFIRMED | %.*f",
                                   pending_stage,_Digits,deal_price);
             // v4.61: internal synchronization status only. The actual ADD
             // broker deal is notified once by the representative alert below.
          }
       }
      // v8.168 diagnostic-only structure episode recorder. Start only on
      // confirmed INITIAL broker deal; ADD remains inside the same episode.
      if(event_name=="ENTRY")
         StructureEpisodeStart(deal_type==DEAL_TYPE_BUY?1:-1,
            (datetime)HistoryDealGetInteger(transaction.deal,DEAL_TIME),deal_price);
      else if(event_name=="ADD_ENTRY")
         StructureEpisodeMarkAdd((datetime)HistoryDealGetInteger(transaction.deal,DEAL_TIME));

      WriteUnifiedOrderSignalAudit("DEAL_FILLED",event_name=="ADD_ENTRY"?g_add_entry_source_event_id:g_initial_entry_source_event_id,event_name,deal_type==DEAL_TYPE_BUY?1:-1,0,0,"FILLED",deal_comment,true,true,0,filled_position_id);
      WriteAutoTradeLogDeal(transaction.deal, event_name, deal_comment);
      WriteLifecycleEvent(event_name,
         deal_type == DEAL_TYPE_BUY ? 1 : -1,
         DataExportHoldStateName(), DataExportHoldStateName(), deal_comment,
         (ulong)HistoryDealGetInteger(transaction.deal, DEAL_POSITION_ID),
         deal_price, deal_volume_all, deal_net,
         (datetime)HistoryDealGetInteger(transaction.deal, DEAL_TIME));
      // v8.242 consume audit-only order source after entry rows are persisted.
      g_csv_order_signal_source="";
      g_csv_order_signal_side=0;
      g_csv_order_signal_time=0;
      const string entry_side =
         (deal_type == DEAL_TYPE_BUY ? "LONG" : "SHORT");
      const string entry_ko =
         (event_name=="ADD_ENTRY" ? "추가진입 체결" :
          (event_name=="REENTRY" ? "재진입 체결" : "자동진입 체결"));
      NotifyUser(StringFormat("[%s] %s %s %s | 수량 %.2f | 체결가 %.*f [%s]",
                 JTAAlertModeKorean(),_Symbol,
                 deal_type==DEAL_TYPE_BUY ? "롱" : "숏",entry_ko,
                 deal_volume_all,_Digits,deal_price,event_name));
      // A successful INITIAL deal can be reported synchronously while the
      // market-order call is still in progress. During that narrow window the
      // new position risk state (fill-based R / protected SL) is not finalized
      // yet. Defer the forced SL safety check until the normal order path has
      // completed ApplyPercentStopToTicket(); Runtime will verify again after
      // position synchronization. ADD/REENTRY keep the existing immediate path.
      if(!(event_name=="ENTRY" && g_entry_order_in_progress))
         EnsureManagedStopsProtected(true);
      return;
   }

   if(deal_entry != DEAL_ENTRY_OUT && deal_entry != DEAL_ENTRY_OUT_BY)
      return;

   const double deal_volume =
      HistoryDealGetDouble(transaction.deal, DEAL_VOLUME);
   const bool position_still_open = ManagedPositionSide() != 0;
   string event_name = position_still_open ? "PARTIAL_CLOSE" : "CLOSE";
   string action_reason = g_pending_exit_reason;
   if(action_reason == "")
      action_reason = deal_comment;

   const bool strategy_stop_exit =
      (StringFind(g_pending_exit_reason, "STRATEGY FAILURE") >= 0);

   if(reason == DEAL_REASON_SL)
   {
      event_name = "STOP_LOSS";
      action_reason = "BROKER SL";
   }
   else if(strategy_stop_exit)
   {
      event_name = "STRATEGY_STOP";
      action_reason = g_pending_exit_reason;
   }
   else if(reason == DEAL_REASON_TP)
   {
      event_name = "TAKE_PROFIT";
      action_reason = "BROKER TP";
   }
   else if(reason == DEAL_REASON_CLIENT ||
           reason == DEAL_REASON_MOBILE ||
           reason == DEAL_REASON_WEB)
   {
      if(g_pending_exit_reason == "")
         action_reason = "MANUAL CLOSE";
   }

   if(InpTradeLogIncludePartials || !position_still_open ||
      reason == DEAL_REASON_SL || reason == DEAL_REASON_TP)
      WriteAutoTradeLogDeal(transaction.deal, event_name, action_reason);

   // v8.242 per-position realized PnL trace; independent from cycle/group PnL.
   const ulong csv_closed_position_id=(ulong)HistoryDealGetInteger(transaction.deal,DEAL_POSITION_ID);
   if(csv_closed_position_id>0 && !DataExportPositionIdentifierOpen(csv_closed_position_id))
   {
      double csv_avg_entry=0.0,csv_entry_volume=0.0,csv_position_net=0.0;
      int csv_entry_count=0;
      DataExportPositionHistoryStats(csv_closed_position_id,csv_avg_entry,csv_entry_volume,csv_entry_count,csv_position_net);
      g_csv_ticket_closed_event_pending=true;
      g_csv_ticket_closed_id=csv_closed_position_id;
      g_csv_ticket_final_pnl=csv_position_net;
   }

   WriteLifecycleEvent(event_name,
      deal_type == DEAL_TYPE_SELL ? 1 : -1,
      DataExportHoldStateName(), position_still_open ? DataExportHoldStateName() : "FLAT",
      action_reason,
      (ulong)HistoryDealGetInteger(transaction.deal, DEAL_POSITION_ID),
      deal_price, deal_volume, deal_net,
      (datetime)HistoryDealGetInteger(transaction.deal, DEAL_TIME));

   const string closed_side =
      (deal_type == DEAL_TYPE_SELL ? "LONG" : "SHORT");
   const int alert_closed_side=(deal_type==DEAL_TYPE_SELL ? 1 : -1);

   // Actual realized money is accumulated from every managed EXIT deal.
   // On the final close this is the complete INITIAL+ADD cycle result.
   g_alert_cycle_realized_net += deal_net;
   const double alert_realized_net=g_alert_cycle_realized_net;

   // v8.168 preserve the completed episode summary before legacy cycle reset.
   if(!position_still_open)
      StructureEpisodeFinish((datetime)HistoryDealGetInteger(transaction.deal,DEAL_TIME),
         deal_price,alert_realized_net,action_reason);

   // R display uses the actual execution price, never the post-fill BID/ASK.
   // The EA's canonical initial entry / initial-R distance remain unchanged.
   double alert_result_r=0.0;
   if(g_initial_entry_price>0.0 && g_initial_r_distance>0.0)
      alert_result_r=alert_closed_side>0 ?
         (deal_price-g_initial_entry_price)/g_initial_r_distance :
         (g_initial_entry_price-deal_price)/g_initial_r_distance;

   const double alert_peak_r=g_highest_profit_r;
   if(!position_still_open)
   {
      g_csv_position_closed_event_pending=true;
      g_csv_position_closed_cycle_id=g_trade_cycle.cycle_id;
      g_csv_position_closed_time=(datetime)HistoryDealGetInteger(transaction.deal,DEAL_TIME);
      g_csv_position_final_pnl=alert_realized_net;
      g_csv_position_final_r=alert_result_r;
      g_csv_position_exit_reason=action_reason;
      if(!g_csv_exit_event_pending)
      {
         g_csv_exec_event_sequence++;
         g_csv_exit_event_id=StringFormat("EXIT-%I64u",g_csv_exec_event_sequence);
         g_csv_exit_event_pending=true;
      }
      g_csv_exit_event_phase="FILLED";
      g_csv_exit_event_time=g_csv_position_closed_time;
      g_csv_exit_event_reason=action_reason;
   }
   const string alert_reason_ko=JTAAlertReasonKorean(action_reason);
   NotifyUser(StringFormat("[%s] %s %s %s | 체결가 %.*f | 실현손익 %s | 결과 %+.2fR | 최고 %+.2fR | 사유: %s [%s]",
              JTAAlertModeKorean(),_Symbol,JTAAlertSideKorean(alert_closed_side),
              position_still_open ? "부분청산" : "청산",
              _Digits,deal_price,JTAAlertSignedMoney(alert_realized_net),
              alert_result_r,alert_peak_r,alert_reason_ko,event_name));

   // v2.45: an ADD can disappear through its own broker SL/TP, manual partial
   // close or any external partial-close path. Synchronize the virtual layer
   // stack immediately before RiskEngine/PositionManager can act again.
   if(position_still_open)
      ReconcileAdditionalLayerState(
         StringFormat("%s | DEAL_VOL %.2f",event_name,deal_volume));

   if(!position_still_open)
   {
      const ulong position_id =
         (ulong)HistoryDealGetInteger(transaction.deal, DEAL_POSITION_ID);
      WriteMinimalPositionSummary(position_id, action_reason);
   }

   g_last_exit_bar_time = iTime(_Symbol, AUTO_TF, 0);
   if(reason == DEAL_REASON_SL || strategy_stop_exit)
   {
      const int closing_side =
         (g_last_integrated_side != 0 ? g_last_integrated_side : g_last_stop_exit_side);
      const int previous_stop_side = g_last_stop_exit_side;
      g_last_stop_exit_side = closing_side;
      g_last_stop_exit_time = (datetime)HistoryDealGetInteger(transaction.deal, DEAL_TIME);
      g_last_stop_exit_price = HistoryDealGetDouble(transaction.deal, DEAL_PRICE);
      g_same_side_stop_count =
         (closing_side != 0 && closing_side == previous_stop_side) ?
         g_same_side_stop_count + 1 : 1;

      g_exit_cooldown_bars = JTF_PostExitMinimumBars(
         InpUseFastSimpleEngine,
         g_position_strategy == STRATEGY_RANGE,
         true,
         InpStopLossCooldownBars,
         InpRangePostStopMinimumBars,
         InpTrendPostStopMinimumBars);

      g_last_position_state_alert = "";
      // The detailed close notification above already reports STOP reason,
      // execution price, realized P/L and R. Do not emit a second duplicate
      // terminal-only STOP alert here.
   }
   else if(reason == DEAL_REASON_TP)
   {
      g_exit_cooldown_bars = InpCooldownBars;
      g_last_position_state_alert = "";
      // v4.60: the detailed OnTradeTransaction close notification above already
      // includes TP reason, actual fill price, realized P/L, R and Peak R.
   }
   else
      g_exit_cooldown_bars = InpCooldownBars;

   const bool manual_close =
      (reason == DEAL_REASON_CLIENT ||
       reason == DEAL_REASON_MOBILE ||
       reason == DEAL_REASON_WEB);
   if(manual_close)
   {
      // A manual close consumes the current regime. A genuinely new pullback
      // and reacceleration event is required before another automatic entry.
      g_long_regime_traded = true;
      g_short_regime_traded = true;
      g_status = "MANUAL CLOSE DETECTED - REENTRY LOCKED";
   }

   // Partial closes keep the live position-management state. Only the final
   // deal that leaves no managed position performs the shared cleanup.
   if(!position_still_open)
   {
      const ulong closed_position_id=(ulong)HistoryDealGetInteger(transaction.deal,DEAL_POSITION_ID);
      const datetime closed_time=(datetime)HistoryDealGetInteger(transaction.deal,DEAL_TIME);
      const string completed_parent_cycle_id=g_trade_cycle.cycle_id;
      // v8.279: snapshot the completed cycle side before lifecycle finalization.
      // Multi-deal PREZERO exits may deliver sibling close transactions after
      // the first transaction has already reset g_trade_cycle.
      const int completed_cycle_side=g_trade_cycle.side;
      string reentry_reason_upper=action_reason;
      StringToUpper(reentry_reason_upper);
      // v2.29: automatic REENTRY removed.
      // Every completed exit clears reentry permission. A future trade must
      // rebuild the ordinary INITIAL signal sequence.
      ReentryContextReset(manual_close ? "MANUAL_EXIT" : "POSITION_CLOSED");

      TradeCycleMarkCompleted(transaction.deal,closed_time,deal_price,deal_net,action_reason);
      WriteUnifiedOrderSignalAudit("CYCLE_COMPLETED",g_exit_source_event_id,"EXIT",deal_type==DEAL_TYPE_SELL?1:-1,0,0,"FILLED",action_reason,true,true,0,closed_position_id);

      // v8.279: PREZERO is EXIT-only, but a broker-confirmed flat may arm
      // exactly one recovery-side CONFIRMED same-side WATCH re-entry. Any
      // other completed exit clears this permission so stale authority cannot
      // leak into an unrelated future cycle.
      const bool completed_prezero_exit=(
         StringFind(reentry_reason_upper,"PREZERO REARM RECOVERY")>=0 &&
         completed_cycle_side!=0);
      if(completed_prezero_exit)
      {
         // The PREZERO reason names the *recovery/opposite* side that caused
         // the EXIT. Re-entry, if later confirmed, must restore the side that
         // was actually closed, i.e. the snapshotted completed trade-cycle side.
         g_prezero_reentry_armed=true;
         g_prezero_reentry_side=(completed_cycle_side>0 ? 1 : -1);
         g_prezero_reentry_exit_time=closed_time;
      }
      else
      {
         // v8.279: a PREZERO EXIT can close INITIAL+ADD exposure through
         // multiple DEAL_ENTRY_OUT transactions. The first broker-flat callback
         // completes/resets g_trade_cycle; subsequent sibling close callbacks
         // therefore have no active cycle side and often no pending reason.
         // They belong to the same completed exit batch and must not erase the
         // PREZERO recovery arm created by the first callback. A genuinely new
         // completed managed cycle still clears stale permission normally.
         const bool sibling_after_cycle_reset=(
            g_prezero_reentry_armed &&
            completed_cycle_side==0 &&
            completed_parent_cycle_id=="");
         if(!sibling_after_cycle_reset)
         {
            g_prezero_reentry_armed=false;
            g_prezero_reentry_side=0;
            g_prezero_reentry_exit_time=0;
         }
      }

      // v8.251: broker-confirmed flat is the only completion authority for a
      // persisted reverse EXIT obligation. Partial closes leave it armed.
      if(g_m3_pending_reverse_side!=M3_SEG_NONE)
         g_m3_pending_reverse_exit_obligation=false;
      // v8.252: live broker flat is also the sole completion authority for
      // pre-REARM EXIT-only obligations. Partial closes leave it armed.
      g_m3_pre_rearm_exit_obligation=false;
      g_m3_pre_rearm_exit_recovery_side=M3_SEG_NONE;
      g_m3_pre_rearm_exit_owner_side=M3_SEG_NONE;
      g_m3_pre_rearm_exit_owner_time=0;

      g_exit_order_in_progress=false;
      FinalizeCompletedPositionClose(manual_close);
      // Export the completed object before clearing it. This preserves one
      // continuous cycle in both live and tester CSVs.
      WriteUnifiedOrderSignalAudit("CYCLE_RESET",g_exit_source_event_id,"LIFECYCLE",g_trade_cycle.side,0,0,"RESET","POSITION_FULLY_CLOSED",false,false,0,closed_position_id);
      TradeCycleClear("POSITION_FULLY_CLOSED");
   }
   // Confirm only after lifecycle bookkeeping above, including cycle reset.
   if(InpTurnTradeEnabled)
      JTC_TurnOrderOnExitDeal((ulong)HistoryDealGetInteger(transaction.deal,DEAL_POSITION_ID));
}

// v8.245: cheap live-startup readiness probe.  Do not copy the 1600-bar
// replay window here; only verify that terminal series and all calculation
// handles have enough synchronized data to justify one full rebuild attempt.
bool StartupHistoryCheapReadyProbe()
{
   if((bool)MQLInfoInteger(MQL_TESTER))
      return true;

   const int minimum_ready_bars=64;
   if(Bars(_Symbol,AUTO_TF)<minimum_ready_bars ||
      Bars(_Symbol,g_signal_tf)<minimum_ready_bars)
      return false;

   const int handles[]={
      g_macd_handle,g_delta_handle,g_add_ma_handle,g_slow_ma_handle,
      g_ma70_handle,g_ma111_handle,g_ma200_handle,
      g_signal_macd_handle,g_signal_delta_handle,g_signal_fast_ma_handle,
      g_signal_slow_ma_handle,g_signal_ma70_handle,g_signal_ma111_handle,
      g_signal_ma200_handle
   };
   for(int i=0;i<ArraySize(handles);i++)
   {
      if(handles[i]==INVALID_HANDLE || BarsCalculated(handles[i])<minimum_ready_bars)
         return false;
   }
   return true;
}

// v8.245: delayed live historical rebuilds are performed only from the
// existing 500 ms timer.  A cheap probe may run every timer cycle, while a
// full replay is throttled to at most once per second.  OnTick never launches
// the heavy replay on high-tick symbols such as GOLD.
bool StartupTryHistoricalRebuildFromTimer(const long now_msc)
{
   if((bool)MQLInfoInteger(MQL_TESTER) || g_startup_rebuild_ready)
      return g_startup_rebuild_ready;
   if(g_startup_rebuild_in_progress)
      return false;

   if(now_msc-g_startup_rebuild_last_probe_msc<500)
      return false;
   g_startup_rebuild_last_probe_msc=now_msc;

   if(!StartupHistoryCheapReadyProbe())
   {
      g_m3_auto_order_authority_active=false;
      g_status="STARTUP REBUILD PENDING - WAITING FOR HISTORY";
      return false;
   }

   if(now_msc-g_startup_rebuild_last_full_attempt_msc<1000)
      return false;
   g_startup_rebuild_last_full_attempt_msc=now_msc;
   g_startup_rebuild_in_progress=true;
   g_m3_auto_order_authority_active=false;

   const bool rebuilt=StateEvaluationWarmupRebuild();
   if(!rebuilt)
   {
      g_startup_rebuild_in_progress=false;
      g_status="STARTUP REBUILD PENDING - WAITING FOR HISTORY";
      return false;
   }

   StateEvaluationMarkCurrentBucketConsumed();
   M3AssistReconcileReinitOwnership(g_startup_rebuild_reconcile_pending);
   g_startup_rebuild_reconcile_pending=false;

   // The replay already consumed the latest completed bars.  Synchronize all
   // live cursors before reopening authority so the READY boundary cannot
   // process shift=1 twice if a new-bar snapshot was observed before rebuild.
   g_last_bar_time=iTime(_Symbol,g_signal_tf,0);
   g_last_auto_bar_time=iTime(_Symbol,AUTO_TF,0);
   const datetime replayed_m3_bar=iTime(_Symbol,AUTO_TF,1);
   if(replayed_m3_bar>0)
      g_m3_last_decision_bar=replayed_m3_bar;

   g_startup_rebuild_ready=true;
   g_startup_rebuild_in_progress=false;
   g_status="STARTUP REBUILD READY - "+AssetProfileName();
   Print("[STARTUP REBUILD READY] timer historical reconstruction complete; cursors synchronized; strategy authority opens on next tick");
   UIRenderAssistState();
   WriteAssistStateCsv();
   return true;
}

//+------------------------------------------------------------------+
void OnTimer()
{
   if(g_duplicate_chart_close_pending)
   {
      const long duplicate_chart_id = ChartID();
      ResetLastError();
      if(!ChartClose(duplicate_chart_id))
      {
         PrintFormat("[DUPLICATE CHART CLOSE FAILED] symbol=%s | chart=%I64d | error=%d",
                     _Symbol, duplicate_chart_id, GetLastError());
      }
      return;
   }

   const long timer_now_msc = (long)GetTickCount64();
   static long last_position_refresh_msc = 0;


   if(!JTAValidateSymbolInstanceOwnership(true))
      return;

   // Broker-position scans are forced at most once per second. Trade
   // transactions still invalidate the cache immediately, so fills and closes
   // are not delayed. Tick-level protection reuses the cached group snapshot.
   if(timer_now_msc - last_position_refresh_msc >= 1000)
   {
      JRO_RefreshPositionSnapshot(_Symbol, InpMagicNumber, true);
      last_position_refresh_msc = timer_now_msc;
   }

   // v8.245: live startup replay is intentionally detached from tick bursts.
   // If a full rebuild attempt runs (success or failure), end this timer cycle
   // so UI redraw/CSV flush work is not stacked on the expensive replay.
   if(!(bool)MQLInfoInteger(MQL_TESTER) && !g_startup_rebuild_ready)
   {
      const long before_attempt=g_startup_rebuild_last_full_attempt_msc;
      StartupTryHistoricalRebuildFromTimer(timer_now_msc);
      if(g_startup_rebuild_last_full_attempt_msc!=before_attempt)
         return;
   }
   // Apply edit-box values while the user is typing.  This removes the need
   // to press Enter or click outside the field before LOT/SL% takes effect.
   if(g_lot_editing)
   {
      const string text =
         ObjectGetString(0, UI_LOT_EDIT, OBJPROP_TEXT);
      if(text != g_last_lot_edit_text)
      {
         g_last_lot_edit_text = text;
         const double requested = UIParseBracketValue(text);
         if(requested > 0.0)
         {
            g_ui_lots = NormalizeVolume(requested);
            UISyncRuntimeProperties("LOT LIVE EDIT");
            UIRefresh();
         }
      }
   }

   if(g_sl_percent_editing)
   {
      const string text =
         ObjectGetString(0, UI_SL_PERCENT_EDIT, OBJPROP_TEXT);
      if(text != g_last_sl_percent_edit_text)
      {
         g_last_sl_percent_edit_text = text;
         const double requested = UIParseBracketValue(text);
         if(requested > 0.0 && requested <= 100.0)
         {
            g_stop_loss_percent = requested;
            g_status = "AUTO SL " +
                       UICompactNumber(g_stop_loss_percent, 2) + "%";
            UISyncRuntimeProperties("SL LIVE EDIT");
         }
      }
   }

   // Full object refresh is not needed in non-visual Strategy Tester runs.
   // Visual tests and live charts keep the normal throttled UI path.
   const bool nonvisual_tester =
      (bool)MQLInfoInteger(MQL_TESTER) &&
      !(bool)MQLInfoInteger(MQL_VISUAL_MODE);
   const long timer_msc = timer_now_msc;
   if(!nonvisual_tester &&
      !g_ui_dragging &&
      (g_ui_force_refresh || timer_msc - g_last_ui_refresh_msc >= 1000))
   {
      UIRefresh();
      g_perf_ui_refreshes++;
      g_ui_force_refresh = false;
      g_last_ui_refresh_msc = timer_msc;
   }
   if(!nonvisual_tester)
      JRO_FlushChartRedraw(0);

   // v4.06: flush diagnostic and major live CSV buffers at most once/sec.
   DataExportFlushBufferedDiagnostics(false);
   DataExportFlushLiveBufferedFiles(false);
}

//+------------------------------------------------------------------+
void StoreFastMomentumTick(const MqlTick &tick)
{
   const double mid = (tick.bid + tick.ask) * 0.5;
   int direction = 0;
   if(g_fast_previous_mid > 0.0)
   {
      if(mid > g_fast_previous_mid) direction = 1;
      else if(mid < g_fast_previous_mid) direction = -1;
   }
   g_fast_previous_mid = mid;

   g_fast_tick_time_msc[g_fast_tick_head] = tick.time_msc;
   g_fast_tick_mid[g_fast_tick_head] = mid;
   g_fast_tick_direction[g_fast_tick_head] = direction;
   g_fast_tick_head = (g_fast_tick_head + 1) % FAST_TICK_CAPACITY;
   if(g_fast_tick_count < FAST_TICK_CAPACITY)
      g_fast_tick_count++;
}

//+------------------------------------------------------------------+
bool RefreshFastMomentumIndicatorCache(const long now_msc)
{
   // The live-bar inputs can change on every tick, but several ticks often
   // arrive within the same millisecond burst. Reuse the result for 200 ms.
   if(g_fast_indicator_cache.valid &&
      now_msc >= g_fast_indicator_cache.time_msc &&
      now_msc - g_fast_indicator_cache.time_msc <= 200)
   {
      g_perf_fast_cache_hits++;
      return true;
   }

   double fast_ma[], slow_ma[], macd[], delta[];
   ArrayResize(fast_ma, 2); ArrayResize(slow_ma, 2);
   ArrayResize(macd, 2);    ArrayResize(delta, 2);
   ArraySetAsSeries(fast_ma, true); ArraySetAsSeries(slow_ma, true);
   ArraySetAsSeries(macd, true);    ArraySetAsSeries(delta, true);
   if(MarketDataCopyBuffer(g_add_ma_handle, 0, 0, 2, fast_ma) < 2 ||
      MarketDataCopyBuffer(g_slow_ma_handle, 0, 0, 2, slow_ma) < 2 ||
      MarketDataCopyBuffer(g_macd_handle, JTC_MACD_BASE_BUFFER, 0, 2, macd) < 2 ||
      MarketDataCopyBuffer(g_delta_handle, 2, 0, 2, delta) < 2)
   {
      g_fast_indicator_cache.valid = false;
      return false;
   }

   for(int side_index=0; side_index<2; side_index++)
   {
      const int test_side = side_index == 0 ? 1 : -1;
      const bool ma_allows = test_side > 0 ?
         (fast_ma[0] > slow_ma[0] ||
          (fast_ma[0] > fast_ma[1] && fast_ma[0] >= slow_ma[0] - 2.0 * _Point)) :
         (fast_ma[0] < slow_ma[0] ||
          (fast_ma[0] < fast_ma[1] && fast_ma[0] <= slow_ma[0] + 2.0 * _Point));
      const bool macd_live_direction =
         test_side > 0 ? macd[0] > macd[1] : macd[0] < macd[1];
      const bool macd_zero_confirmed =
         test_side > 0 ? macd[0] > 0.0 : macd[0] < 0.0;
      const double selected_delta =
         InpFastMomentumRequireClosedDelta ? delta[1] : delta[0];
      const bool delta_allows = test_side > 0 ?
         selected_delta > 0.0 : selected_delta < 0.0;
      const bool allowed =
         (!InpFastMomentumRequireMATrend || ma_allows) &&
         (!InpFastMomentumRequireMACD || macd_zero_confirmed ||
          (InpFastMomentumAllowMACDPreZero && macd_live_direction)) &&
         delta_allows;
      if(test_side > 0) g_fast_indicator_cache.long_allowed = allowed;
      else              g_fast_indicator_cache.short_allowed = allowed;
   }
   g_fast_indicator_cache.valid = true;
   g_fast_indicator_cache.time_msc = now_msc;
   g_perf_fast_cache_misses++;
   return true;
}

bool FastMomentumIndicatorAllows(const int side, const long now_msc)
{
   if(!RefreshFastMomentumIndicatorCache(now_msc))
      return false;
   return side > 0 ? g_fast_indicator_cache.long_allowed
                   : g_fast_indicator_cache.short_allowed;
}

//+------------------------------------------------------------------+
void ShortTermResetEntry(const string reason="")
{
   g_st_entry_armed=false;
   g_st_entry_side=0;
   g_st_entry_setup_bar=0;
   g_st_entry_expiry_bar=0;
   g_st_entry_trigger=0.0;
   g_st_entry_stop=0.0;
   g_st_entry_impulse_extreme=0.0;
   g_st_entry_pullback_extreme=0.0;
   if(reason!="")
      WriteUnifiedOrderSignalAudit("SHORT_TERM_SETUP_RESET", "", "INITIAL", 0, 0, 0, "RESET", reason, false, false, 0, 0);
}

bool ShortTermArmSetup()
{
   // v8.42: M3 AUTO is a continuously evaluated short-term trading engine.
   // Do not require the old exact 3-bar impulse/pullback/re-acceleration
   // pattern. Every new M3 bar gets a fresh opportunity assessment.
   if(!InpUseShortTermPriceActionEngine || !g_auto_trading || ManagedPositionSide()!=0)
      return false;
   if(!IsCooldownComplete())
      return false;

   MqlRates r[];
   ArrayResize(r,4);
   ArraySetAsSeries(r,true);
   if(MarketDataCopyRates(_Symbol,AUTO_TF,0,4,r)<4)
      return false;

   double macd[];
   ArrayResize(macd,4);
   ArraySetAsSeries(macd,true);
   if(g_macd_handle==INVALID_HANDLE ||
      MarketDataCopyBuffer(g_macd_handle,JTC_MACD_WAVE_BUFFER,0,4,macd)<4)
      return false;

   const double atr=EntryATR(AUTO_TF);
   if(atr<=0.0)
      return false;

   // [1] is the most recently completed M3 candle. We look for a fresh
   // directional expansion and arm its high/low for an intrabar break.
   const double range1=r[1].high-r[1].low;
   const double range2=r[2].high-r[2].low;
   const double body1=MathAbs(r[1].close-r[1].open);
   const double avg_range=MathMax(_Point,(range1+range2)/2.0);
   const double min_impulse=atr*MathMax(0.20,InpShortTermImpulseATR*0.65);

   if(range1<min_impulse || body1<avg_range*MathMax(0.05,InpShortTermMinReaccelBody*0.50))
      return false;

   const bool long_bar=r[1].close>r[1].open;
   const bool short_bar=r[1].close<r[1].open;
   const bool long_momentum=long_bar && macd[1]>0.0 && macd[1]>=macd[2];
   const bool short_momentum=short_bar && macd[1]<0.0 && macd[1]<=macd[2];

   int side=0;
   if(long_momentum && !short_momentum)
      side=1;
   else if(short_momentum && !long_momentum)
      side=-1;
   else
      return false;

   if(g_trade_direction==TRADE_LONG_ONLY && side<0)
      return false;
   if(g_trade_direction==TRADE_SHORT_ONLY && side>0)
      return false;

   // Avoid entering a candle that has already travelled excessively from
   // the previous M3 close. This is an anti-chase check, not a signal gate.
   const double trigger=side>0 ? r[1].high : r[1].low;
   const double buffer=atr*MathMax(0.0,InpShortTermStopBufferATR);
   const double structure_extreme=side>0 ? MathMin(r[1].low,r[2].low)
                                         : MathMax(r[1].high,r[2].high);
   const double stop=side>0 ? structure_extreme-buffer : structure_extreme+buffer;

   if((side>0 && stop>=trigger) || (side<0 && stop<=trigger))
      return false;

   g_st_entry_armed=true;
   g_st_entry_side=side;
   g_st_entry_setup_bar=r[1].time;
   g_st_entry_expiry_bar=iTime(_Symbol,AUTO_TF,0)+
      (datetime)MathMax(1,InpShortTermSetupExpiryBars)*PeriodSeconds(AUTO_TF);
   g_st_entry_trigger=trigger;
   g_st_entry_stop=stop;
   g_st_entry_impulse_extreme=side>0 ? r[1].high : r[1].low;
   g_st_entry_pullback_extreme=structure_extreme;

   const string detail=StringFormat(
      "%s M3 MOMENTUM BREAK | TRIGGER=%.*f | STOP=%.*f | ATR=%.*f | RANGE=%.2fATR | BODY=%.2fAVG",
      side>0?"LONG":"SHORT",_Digits,trigger,_Digits,stop,_Digits,atr,
      range1/atr,body1/avg_range);
   WriteUnifiedOrderSignalAudit("SHORT_TERM_SETUP_ARMED", "", "INITIAL", side, 0, 0,
      "ARMED", detail, false, false, 0, 0);
   g_status="M3 AUTO ARMED: "+(side>0?"LONG":"SHORT");
   return true;
}

void ProcessFastMomentumTick(const MqlTick &tick)
{
   if(M3AutoEngineIsActive())
      return;

   // v8.36: this function is retained as the single tick-level trigger owner,
   // but the old raw-tick momentum entry model is removed. Entry is now armed
   // only by the completed-bar impulse/pullback/re-acceleration structure.
   if(!InpUseShortTermPriceActionEngine || !g_auto_trading || ManagedPositionSide()!=0)
      return;
   if(!g_st_entry_armed || g_st_entry_side==0 || g_st_entry_trigger<=0.0)
      return;

   const datetime current_bar=iTime(_Symbol,AUTO_TF,0);
   if(current_bar<=0 || (g_st_entry_expiry_bar>0 && current_bar>g_st_entry_expiry_bar))
   {
      ShortTermResetEntry("SETUP_EXPIRED");
      return;
   }

   const double spread_points=(tick.ask-tick.bid)/_Point;
   const double maximum_spread=InpFastMomentumMaximumSpreadPoints>0.0 ?
      InpFastMomentumMaximumSpreadPoints : InpMaximumSpreadPoints;
   if(maximum_spread>0.0 && spread_points>maximum_spread)
      return;

   const double atr=EntryATR(AUTO_TF);
   if(atr<=0.0)
      return;
   const double price=g_st_entry_side>0 ? tick.ask : tick.bid;
   const double distance=MathAbs(price-g_st_entry_trigger);
   if(distance > atr*MathMax(0.05,InpShortTermMaxEntryATR))
   {
      ShortTermResetEntry("TRIGGER_OVEREXTENDED");
      return;
   }
   const bool crossed=g_st_entry_side>0 ? price>g_st_entry_trigger : price<g_st_entry_trigger;
   if(!crossed)
      return;

   const int side=g_st_entry_side;
   const string reason=StringFormat("SHORT-TERM %s REACCEL BREAK | TRIGGER=%.*f | STOP=%.*f | DIST=%.2fATR",
      side>0?"LONG":"SHORT",_Digits,g_st_entry_trigger,_Digits,g_st_entry_stop,
      distance/atr);
   // OpenPosition consumes the armed structural stop while this state is active.
   if(EntryEngineSubmitInitial(side,0,reason,price,false))
      ShortTermResetEntry("ENTRY_SENT");
}

// v8.36: completed-bar setup formation is the only AUTO entry setup authority.
void RangeEntryEngine()
{
   if(M3AutoEngineIsActive())
      return;

   if(!InpUseShortTermPriceActionEngine)
   {
      ProcessRangeClosedBar(false,true);
      return;
   }
   if(ManagedPositionSide()!=0)
      return;
   if(g_st_entry_armed)
      return;
   ShortTermArmSetup();
}


//+------------------------------------------------------------------+
void ResetFlatRuntimeStateOnce()
{
   EntryEngineResetRangeStructureAdditional("");
   g_additional_entry_count = 0;
   g_additional_entry_filled_count = 0;
   JTAAddPersistenceClear();
   g_last_entry_time = 0;
   g_initial_entry_time = 0;
   g_initial_hold_anchor_time = 0;
   g_pending_initial_hold_anchor_time = 0;
   g_add1_hold_anchor_time = 0;
   g_add2_hold_anchor_time = 0;
   JTAAddLayerResetAll();
   g_pending_add_hold_anchor_time = 0;
   g_pending_add_hold_anchor_stage = 0;
   JTAHoldAnchorClear();
   g_initial_entry_lots = 0.0;
   g_initial_entry_price = 0.0;
   g_initial_r_distance = 0.0;
   g_m3_structural_sl_active = false;
   g_m3_position_managed = false;
   g_m3_initial_structural_sl = 0.0;
   g_m3_protected_sl = 0.0;
   g_m3_protection_stage = 0;
   g_m3_protection_last_time = 0;
   g_m3_audit_lock_target_r = 0.0;
   g_m3_audit_lock_target_sl = 0.0;
   g_m3_audit_lock_active = false;
   g_m3_audit_lock_attempted = false;
   g_m3_audit_lock_applied = false;
   g_m3_audit_lock_block_reason = "";
   g_m3_audit_lock_update_time = 0;
   // M3 re-entry lock intentionally survives flat-position cleanup. It is
   // strategic lifecycle state created by a failed M3 segment and may only be
   // released by M3AutoEngine after a genuinely new structural segment is
   // established. Resetting it here recreated the old failure -> immediate
   // re-entry loop because broker/strategic close cleanup erased the lock.
   // The fields are cleared by M3AutoEngine only after its release test passes.
   g_m3_position_state = JTC_M3_POS_FLAT;
   g_m3_group_peak_r = 0.0;
   g_m3_post_add_peak_r = 0.0;
   g_m3_post_add_anchor_r = 0.0;
   g_m3_post_add_protected_r = 0.0;
   g_m3_group_add_count_at_peak = 0;
   // A flat lifecycle must never leak the previous position's protection
   // levels into the next INITIAL entry.
   g_protected_sl = 0.0;
   ManualBrokerSLClearAll();
   ManualBrokerSLClearPendingEAModifies();
   g_initial_virtual_profit_floor_active = false;
   g_initial_virtual_profit_floor_side = 0;
   g_initial_virtual_profit_floor_r = 0.0;
   g_initial_virtual_profit_floor_price = 0.0;
   g_initial_virtual_profit_floor_time = 0;
   g_sl_distance = 0.0;
   g_original_tp = 0.0;
   g_tp_distance = 0.0;
   g_highest_profit_r = 0.0;
   g_hold_state = HOLD_UNKNOWN;
   g_profit_protection_state = PROFIT_PROTECTION_UNKNOWN;
   g_short_term_partial_taken = false;
   g_short_term_break_even_applied = false;
   g_profit_guard_peak_percent = 0.0;
   g_profit_guard_activated = false;
   g_hold_score_partial_done = false;
   g_chase_reference_high = 0.0;
   g_chase_reference_low = 0.0;
   g_chase_average_range = 0.0;
   g_chase_peak_progress = 0.0;
   g_chase_failure_bars = 0;
   g_chase_last_evaluation_bar = 0;
   g_add_position_sync_pending=false;
   g_add_pending_stage=0;
   g_add_pending_side=0;
   g_add_pending_volume=0.0;
   // Invalidate once when a position closes. Repeated invalidation while flat
   // previously disabled the intended 200 ms FAST indicator reuse.
   g_fast_indicator_cache.valid = false;
}

// v8.245: OnTick is never allowed to launch the heavy live historical replay.
// Strategy Tester keeps the v8.244 deterministic M3 retry path; live charts
// are rebuilt only by OnTimer via StartupTryHistoricalRebuildFromTimer().
bool StartupEnsureHistoricalRebuildReady()
{
   const bool m3_active=M3AutoEngineIsActive();
   if(g_startup_rebuild_ready && (!m3_active || g_m3_warmup_complete))
      return true;

   if(!(bool)MQLInfoInteger(MQL_TESTER))
   {
      g_m3_auto_order_authority_active=false;
      return false;
   }

   if(m3_active && !g_m3_warmup_complete)
   {
      g_m3_auto_order_authority_active=false;
      if(!M3WarmupRebuild())
      {
         g_startup_rebuild_ready=false;
         g_status="STARTUP REBUILD PENDING - M3 HISTORY";
         return false;
      }
   }
   g_startup_rebuild_ready=true;
   g_startup_rebuild_reconcile_pending=false;
   g_status="STARTUP REBUILD READY - "+AssetProfileName();
   return true;
}

//+------------------------------------------------------------------+
void OnTick()
{
   if(g_duplicate_chart_close_pending)
      return;

   if(!JTAValidateSymbolInstanceOwnership(true))
      return;

   const ulong tick_started_us = GetMicrosecondCount();
   g_perf_tick_calls++;
   // Build one consistent terminal snapshot for the complete tick cycle.
   // All position helper functions below reuse this scan until a trade
   // transaction invalidates it.
   JRO_RefreshPositionSnapshot(_Symbol, InpMagicNumber, false);
   const int integrated_side = g_jro_positions.side;

   if(integrated_side != 0 && !g_position_strategy_locked)
   {
      g_position_strategy = g_selected_strategy;
      g_position_strategy_locked = true;
   }
   else if(integrated_side == 0 && g_position_strategy_locked)
   {
      g_position_strategy_locked = false;
      g_position_strategy = g_selected_strategy;
   }

   if(integrated_side!=0 && g_trade_cycle.entry_strategy_valid)
      TradeCycleObserveStrategyChange(g_selected_strategy);

   const bool has_tick =
      JRO_UpdateMarketSnapshot(_Symbol, g_signal_tf, AUTO_TF,
                               g_last_bar_time, g_last_auto_bar_time);

   if(integrated_side == 0)
   {
      if(g_last_integrated_side != 0)
         ResetFlatRuntimeStateOnce();
   }
   else if(g_last_entry_time<=0 || g_initial_entry_time<=0 ||
           g_initial_entry_price<=0.0)
      RestoreAdditionalEntryState();

   g_last_integrated_side = integrated_side;

   // SL is a position-safety invariant, independent of AUTO and SYSTEM
   // permission. Existing managed positions must remain broker-protected even
   // if new signal/order processing is disabled.
   if(integrated_side != 0)
   {
      // v8.162: pure State-WATCH + M3-ACCEL validation mode.
      // M3 AUTO positions are intentionally not given a second SL/Peak80 exit
      // authority; signal-order performance must be measurable by itself.
      if(InpTurnTradeEnabled || !M3AutoEngineIsActive())
         EnsureManagedStopsProtected(false);
   }

   // v8.243: position-safety work above remains active while startup history is
   // incomplete. Everything below this gate can publish or consume strategy
   // state, so wait for the complete chronological replay first.
   if(!StartupEnsureHistoricalRebuildReady())
   {
      // v8.245: keep the high-frequency pending path minimal.  Status/UI is
      // refreshed by OnTimer; OnTick retains only position safety above.
      return;
   }

   // v7.11: manual-assist state interpretation is independent of AUTO and
   // strategy order authority. Heavy analysis runs only on a new selected-TF
   // bucket; UI/CSV consume the same cached snapshot.
   const ulong perf_state_started_us=GetMicrosecondCount();
   const bool assist_state_updated=StateEvaluationProcessIfNewBar();
   const ulong perf_state_elapsed_us=GetMicrosecondCount()-perf_state_started_us;
   g_perf_last_state_eval_us=perf_state_elapsed_us;
   if(perf_state_elapsed_us>g_perf_peak_state_eval_us)
      g_perf_peak_state_eval_us=perf_state_elapsed_us;
   if(assist_state_updated)
   {
      UIRenderAssistState();
      const ulong perf_assist_write_started_us=GetMicrosecondCount();
      WriteAssistStateCsv();
      const ulong perf_assist_write_elapsed_us=GetMicrosecondCount()-perf_assist_write_started_us;
      g_perf_last_assist_write_us=perf_assist_write_elapsed_us;
      if(perf_assist_write_elapsed_us>g_perf_peak_assist_write_us)
         g_perf_peak_assist_write_us=perf_assist_write_elapsed_us;
   }

   // v8.285: exclusive new-signal authority returns before every legacy order router.
   if(InpTurnTradeEnabled)
   {
      JTC_TurnOrderProcessTick();
      if(has_tick)
      {
         if(g_jro_market.auto_new_bar)
         {
            WritePerformanceAuditV100(g_jro_market.auto_bar_time,AUTO_TF);
            g_last_auto_bar_time=g_jro_market.auto_bar_time;
         }
         if(g_jro_market.signal_new_bar)
            g_last_bar_time=g_jro_market.signal_bar_time;
      }
      UpdateChartComment();
      const ulong turn_elapsed_us=GetMicrosecondCount()-tick_started_us;
      g_perf_last_tick_us=turn_elapsed_us;
      if(turn_elapsed_us>g_perf_peak_tick_us) g_perf_peak_tick_us=turn_elapsed_us;
      return;
   }

   if(!InpSystemEnabled)
   {
      g_status = "SYSTEM OFF";
      UpdateChartComment();
      return;
   }

   // Defensive AUTO retention: after an AUTO-created fill the session latch is
   // authoritative unless the operator explicitly pressed AUTO OFF.
   if(!g_auto_trading && integrated_side != 0 && UIAutoSessionLatched())
   {
      g_auto_trading = true;
      g_status = "AUTO RESTORED AFTER ENTRY";
      Print("[AUTO STATE RESTORED] active managed position | AUTO=ON");
      UIRefresh();
   }

   bool chase_closed=false;
   if(integrated_side!=0)
   {
      // v8.43: the unified M3 engine owns the complete AUTO lifecycle when
      // enabled. Legacy RANGE/TREND exit logic remains available only when
      // the unified engine is disabled.
      if(!M3AutoEngineIsActive())
         ExitEngineManageOpenPositionUnified();
   }

   if(g_auto_trading && has_tick && !chase_closed && integrated_side==0)
   {
      if(!M3AutoEngineIsActive())
         ProcessFastMomentumTick(g_jro_market.tick);
   }

   // Strategy calculations run only when their timeframe opens a new bar.
   // v1.95 shared completed-bar decision path. When RANGE chart-signal TF and
   // AUTO_TF are the same completed bar, calculate the signal exactly once and
   // let chart/alert/counter/entry consume that same result. Different TFs and
   // non-shared RANGE AUTO/signal bars remain independent by design.
   const bool shared_range_decision_bar = has_tick &&
      g_selected_strategy==STRATEGY_RANGE &&
      g_jro_market.auto_new_bar && g_jro_market.signal_new_bar &&
      g_signal_tf==AUTO_TF &&
      g_jro_market.auto_bar_time==g_jro_market.signal_bar_time;

   if(shared_range_decision_bar)
   {
      g_perf_new_bar_calls++;
      g_calc_tf=AUTO_TF;
      g_calc_macd_handle=g_macd_handle;
      g_calc_delta_handle=g_delta_handle;
      g_calc_fast_ma_handle=g_add_ma_handle;
      g_calc_slow_ma_handle=g_slow_ma_handle;
      g_calc_ma70_handle=g_ma70_handle;
      g_calc_ma111_handle=g_ma111_handle;
      g_calc_ma200_handle=g_ma200_handle;

      // v8.40: when short-term AUTO owns trading, signal publication and
      // short-term entry setup are independent. The legacy RANGE decision
      // bundle must not become an AUTO prerequisite merely because SIGNAL_TF
      // and AUTO_TF happen to be the same timeframe.
      if(M3AutoEngineIsActive())
      {
         if(!g_m3_warmup_complete)
         {
            g_m3_auto_order_authority_active=false;
            g_status="STARTUP REBUILD PENDING - M3 NOT READY";
            UpdateChartComment();
            return;
         }
         g_m3_auto_order_authority_active=g_auto_trading;
         // v8.138: M3 AUTO consumes the same WATCH/ACCEL event fields used by
         // chart and CSV output. SignalEngine is output-only here and cannot
         // create a second M3 signal or order authority.
         const ulong perf_m3_started_us=GetMicrosecondCount();
         M3AutoEngineProcessTick(true);
         const ulong perf_m3_elapsed_us=GetMicrosecondCount()-perf_m3_started_us;
         g_perf_last_m3_auto_us=perf_m3_elapsed_us;
         if(perf_m3_elapsed_us>g_perf_peak_m3_auto_us) g_perf_peak_m3_auto_us=perf_m3_elapsed_us;
         StructureEpisodeCaptureM3Frame();
         g_last_auto_bar_time=g_jro_market.auto_bar_time;

         // Signal publication is output-only here. It cannot submit orders
         // because process_auto=false and M3 AUTO is the sole execution owner.
         // Do not skip this call on a shared bar; otherwise AUTO ON would
         // suppress the canonical M3 chart/system signal entirely.
         const ulong perf_signal_started_us=GetMicrosecondCount();
         ProcessSelectedClosedBar(true,false);
         const ulong perf_signal_elapsed_us=GetMicrosecondCount()-perf_signal_started_us;
         g_perf_last_signal_us=perf_signal_elapsed_us;
         if(perf_signal_elapsed_us>g_perf_peak_signal_us) g_perf_peak_signal_us=perf_signal_elapsed_us;
         // v8.217: on the shared M3 decision bar, SignalEngine publishes the
         // simple DIRECTION event after the canonical WATCH/ACCEL AUTO pass.
         // Consume that event now on the same completed bar. The consumer
         // preserves WATCH > ACCEL > DIRECTION and the shared MAX ADD counter.
         if(g_auto_trading)
            M3AutoConsumeInternalMomentumEvent();
         PatternLearningCaptureClosedBar("SIGNAL_CLOSED_BAR");
         g_last_bar_time=g_jro_market.signal_bar_time;
      }
      else if(!M3AutoEngineIsActive() && SelectedCalculationDataReady())
      {
         g_m3_auto_order_authority_active=false;
         ProcessSelectedClosedBar(true,true);
         PatternLearningCaptureClosedBar("SIGNAL_CLOSED_BAR");
         g_last_auto_bar_time=g_jro_market.auto_bar_time;
         g_last_bar_time=g_jro_market.signal_bar_time;
      }
      else
         g_status="WAITING FOR SHARED RANGE DATA - RETRY SAME BAR";
   }

   // v8.40: the short-term AUTO engine is an independent trading path.
   // It must not wait for the legacy RANGE/SIGNAL calculation bundle
   // (Delta/MA70/MA111/MA200/long lookbacks) before it can form a local
   // price-action setup. Those indicators remain available for chart signals
   // and diagnostics, but they are not prerequisites for short-term AUTO.
   if(!shared_range_decision_bar && has_tick && g_jro_market.auto_new_bar)
   {
      g_perf_new_bar_calls++;
      g_calc_tf = AUTO_TF;
      g_calc_macd_handle = g_macd_handle;
      g_calc_delta_handle = g_delta_handle;
      g_calc_fast_ma_handle = g_add_ma_handle;
      g_calc_slow_ma_handle = g_slow_ma_handle;
      g_calc_ma70_handle = g_ma70_handle;
      g_calc_ma111_handle = g_ma111_handle;
      g_calc_ma200_handle = g_ma200_handle;

      if(M3AutoEngineIsActive())
      {
         if(!g_m3_warmup_complete)
         {
            g_m3_auto_order_authority_active=false;
            g_status="STARTUP REBUILD PENDING - M3 NOT READY";
            UpdateChartComment();
            return;
         }
         g_m3_auto_order_authority_active=g_auto_trading;
         // v8.76: do not run the legacy TREND calculation bundle on the M3
         // AUTO bar. It duplicates indicator/lookback work that is not used
         // by M3 order authority. M3AutoEngine builds the required snapshot.
         const ulong perf_m3_started_us=GetMicrosecondCount();
         M3AutoEngineProcessTick(true);
         const ulong perf_m3_elapsed_us=GetMicrosecondCount()-perf_m3_started_us;
         g_perf_last_m3_auto_us=perf_m3_elapsed_us;
         if(perf_m3_elapsed_us>g_perf_peak_m3_auto_us) g_perf_peak_m3_auto_us=perf_m3_elapsed_us;
         StructureEpisodeCaptureM3Frame();
         g_last_auto_bar_time = g_jro_market.auto_bar_time;
      }
      else if(!M3AutoEngineIsActive() && SelectedCalculationDataReady())
      {
         g_m3_auto_order_authority_active=false;
         ProcessSelectedClosedBar(false, true);
         g_last_auto_bar_time = g_jro_market.auto_bar_time;
      }
      else
         g_status = "WAITING FOR AUTO DATA - RETRY SAME BAR";
   }

   // Chart signals and alert rendering are intentionally second priority.
   // They still run on the same tick after the AUTO order path completes.
   if(!shared_range_decision_bar && has_tick && g_jro_market.signal_new_bar)
   {
      g_calc_tf = g_signal_tf;
      g_calc_macd_handle = g_signal_macd_handle;
      g_calc_delta_handle = g_signal_delta_handle;
      g_calc_fast_ma_handle = g_signal_fast_ma_handle;
      g_calc_slow_ma_handle = g_signal_slow_ma_handle;
      g_calc_ma70_handle = g_signal_ma70_handle;
      g_calc_ma111_handle = g_signal_ma111_handle;
      g_calc_ma200_handle = g_signal_ma200_handle;
      if(SelectedCalculationDataReady())
      {
         // v8.81: M3 structure observation is independent of AUTO execution.
         // When the short-term M3 engine is enabled, AUTO OFF must still build
         // the same canonical structure/trigger state before SignalEngine
         // publishes the manual-trading signal.
         if(M3AutoEngineIsActive() && g_signal_tf==AUTO_TF)
         {
            if(!g_m3_warmup_complete)
            {
               g_m3_auto_order_authority_active=false;
               g_status="STARTUP REBUILD PENDING - M3 NOT READY";
               UpdateChartComment();
               return;
            }
            g_m3_auto_order_authority_active=false;
            const ulong perf_m3_started_us=GetMicrosecondCount();
            M3AutoEngineProcessTick(true);
            const ulong perf_m3_elapsed_us=GetMicrosecondCount()-perf_m3_started_us;
            g_perf_last_m3_auto_us=perf_m3_elapsed_us;
            if(perf_m3_elapsed_us>g_perf_peak_m3_auto_us) g_perf_peak_m3_auto_us=perf_m3_elapsed_us;
            StructureEpisodeCaptureM3Frame();
         }
         const ulong perf_signal_started_us=GetMicrosecondCount();
         ProcessSelectedClosedBar(true, false);
         const ulong perf_signal_elapsed_us=GetMicrosecondCount()-perf_signal_started_us;
         g_perf_last_signal_us=perf_signal_elapsed_us;
         if(perf_signal_elapsed_us>g_perf_peak_signal_us) g_perf_peak_signal_us=perf_signal_elapsed_us;
         // v8.210: SignalEngine publishes internal momentum after the normal M3
         // AUTO pass. Consume it now on the same completed bar as an alternate
         // ADD candidate. No chart object or alert is produced.
         if(M3AutoEngineIsActive() && g_auto_trading)
            M3AutoConsumeInternalMomentumEvent();
         PatternLearningCaptureClosedBar("SIGNAL_CLOSED_BAR");
         g_last_bar_time = g_jro_market.signal_bar_time;
      }
      else
         g_status = "WAITING FOR SIGNAL DATA - RETRY SAME BAR";
   }

   // v8.136: M3 AUTO is the sole strategy-level order router. Legacy RANGE
   // breakout/structure-add tick routers are available only in non-M3 modes.
   if(!M3AutoEngineIsActive())
   {
      // v8.267: legacy RANGE 3X FINAL breakout tick router retired.
      if(g_selected_strategy==STRATEGY_RANGE && integrated_side!=0)
         EntryEngineProcessRangeStructureAdditionalTick();
   }

   // Watch/chart trigger observation is retained for diagnostics/alerts.
   WatchCheckTriggerTick();
   if(!M3AutoEngineIsActive() &&
      g_selected_strategy==STRATEGY_RANGE && integrated_side==0 && !InpUseShortTermPriceActionEngine)
      ProcessTriggerFinalEntryTick();
   UpdateChartComment();
   const ulong elapsed_us = GetMicrosecondCount() - tick_started_us;
   g_perf_last_tick_us = elapsed_us;
   if(elapsed_us > g_perf_peak_tick_us) g_perf_peak_tick_us = elapsed_us;

   // v7.47: record existing cumulative performance counters once per
   // completed unified trading-TF bar. No extra indicator/price read occurs.
   if(has_tick && g_jro_market.auto_new_bar)
      WritePerformanceAuditV100(g_jro_market.auto_bar_time,AUTO_TF);
}


// ===== Functions moved from Common.mqh during ownership audit =====

void ProcessSelectedClosedBar(const bool process_signals,
                              const bool process_auto)
{
   // RANGE with a shared signal/AUTO bar is evaluated exactly once. This is
   // the canonical live/tester path and guarantees that the chart confirmed
   // signal is the same event consumed by counters and entry logic.
   if(process_signals && process_auto && g_selected_strategy==STRATEGY_RANGE)
   {
      ProcessRangeClosedBar(true,false);

      // v8.05: WATCH belongs to SIGNAL ownership, not AUTO ownership.
      // Reuse the existing WATCH engine exactly once for this completed signal bar.
      if(g_signal_enabled)
         WatchSignalProcessClosedBar();
      if(process_auto)
         RangeEntryEngine();
      return;
   }

   if(process_signals)
   {
      ProcessRangeClosedBar(true,false);

      // v8.05: SIGNAL ON must continue to produce reversal WATCH arrows even
      // when AUTO is OFF. No new WATCH logic/state is introduced here.
      if(g_signal_enabled)
         WatchSignalProcessClosedBar();
   }

   if(process_auto)
      RangeEntryEngine();
}

#endif // __JOON_RUNTIME_MQH__
