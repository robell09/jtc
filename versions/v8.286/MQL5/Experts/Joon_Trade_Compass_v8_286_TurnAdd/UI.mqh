//+------------------------------------------------------------------+
//| UI.mqh                                                       |
//| Joon Trend/Range AutoTrader modular component                    |
//+------------------------------------------------------------------+
#ifndef __JOON_UI_MQH__
#define __JOON_UI_MQH__
#define UI_ENTRY_LINE "JMD_ENTRY"
#define UI_TP_LINE    "JMD_TP"
#define UI_SL_LINE    "JMD_SL"
#define UI_TP_BAR     "JMD_UI_TP_BAR"
#define UI_SL_BAR     "JMD_UI_SL_BAR"
#define UI_ENTRY_BAR  "JMD_UI_ENTRY_BAR"
#define UI_TP_TEXT    "JMD_UI_TP_TEXT"
#define UI_SL_TEXT    "JMD_UI_SL_TEXT"
#define UI_TP_LOCK    "JMD_UI_TP_LOCK"
#define UI_SL_LOCK    "JMD_UI_SL_LOCK"
#define UI_ENTRY_TEXT "JMD_UI_ENTRY_TEXT"
#define UI_SIDE_UP    "JMD_UI_SIDE_UP"
#define UI_SIDE_DOWN  "JMD_UI_SIDE_DOWN"
#define UI_NOW        "JMD_UI_NOW"
#define UI_LOCK       "JMD_UI_LOCK"
#define UI_RESET      "JMD_UI_RESET"
#define UI_SIGNAL     "JMD_UI_SIGNAL"
#define UI_AUTO       "JMD_UI_AUTO"
#define UI_MODE_TEXT  "JMD_UI_MODE_TEXT"
#define UI_STRATEGY   "JMD_UI_STRATEGY"
#define UI_STATE_TF   "JMD_UI_STATE_TF"
#define UI_DIR_TEXT   "JMD_UI_DIR_TEXT"
#define UI_DIR_BOTH   "JMD_UI_DIR_BOTH"
#define UI_DIR_LONG   "JMD_UI_DIR_LONG"
#define UI_DIR_SHORT  "JMD_UI_DIR_SHORT"
#define UI_ADD_TEXT   "JMD_UI_ADD_TEXT"
#define UI_MAX_ADD_EDIT "JMD_UI_MAX_ADD_EDIT"
#define UI_SIGDIR_TEXT  "JMD_UI_SIGDIR_TEXT"
#define UI_SIGDIR_BOTH  "JMD_UI_SIGDIR_BOTH"
#define UI_SIGDIR_LONG  "JMD_UI_SIGDIR_LONG"
#define UI_SIGDIR_SHORT "JMD_UI_SIGDIR_SHORT"
#define UI_SYS_ALERT    "JMD_UI_SYS_ALERT"
#define UI_MOB_ALERT    "JMD_UI_MOB_ALERT"
#define UI_WATCH_ALERT  "JMD_UI_WATCH_ALERT"
#define UI_ALERT_SCORE  "JMD_UI_ALERT_SCORE"
#define UI_ALERT_OFF    "JMD_UI_ALERT_OFF"
#define UI_ALERT_50     "JMD_UI_ALERT_50"
#define UI_ALERT_60     "JMD_UI_ALERT_60"
#define UI_ALERT_70     "JMD_UI_ALERT_70"
#define UI_ALERT_80     "JMD_UI_ALERT_80"
#define UI_ALERT_90     "JMD_UI_ALERT_90"
#define UI_LOT_MINUS  "JMD_UI_LOT_MINUS"
#define UI_LOT_LABEL  "JMD_UI_LOT_LABEL"
#define UI_LOT_EDIT   "JMD_UI_LOT_EDIT"
#define UI_LOT_PLUS   "JMD_UI_LOT_PLUS"
#define UI_SL_PERCENT_LABEL "JMD_UI_SL_PERCENT_LABEL"
#define UI_SL_PERCENT_EDIT "JMD_UI_SL_PERCENT_EDIT"
#define UI_HIDE_BUTTON "JMD_UI_HIDE_BUTTON"
#define JTA_OBJECT_PREFIX "JTA_"

const int UI_H = 18;
const int UI_MIN_WIDTH = 250;
const int UI_REFERENCE_WIDTH = 220;
const int UI_REFERENCE_MAX_WIDTH = 380;
const int UI_REFERENCE_TEXT_PADDING = 12;
const int UI_PANEL_GAP = 8;
const int UI_MAX_DRAG_EVENT_PX = 60;
// First-attachment spacing between the TP/SL reference boxes and the menu.
// Three pixels keeps the three areas visually separate while matching the
// compact layout shown in the operator's reference screen.
const int UI_INITIAL_CLEARANCE_PX = 3;
const int UI_CHART_EDGE_MARGIN_PX = 4;
bool   g_ui_buy = true;
bool   g_ui_locked = false;
bool   g_ui_tp_locked = false;
bool   g_ui_sl_locked = false;
int    g_ui_tp_lock_y_offset = 0;
int    g_ui_sl_lock_y_offset = 0;
int    g_ui_tp_lock_x_offset = 0;
int    g_ui_sl_lock_x_offset = 0;
bool   g_ui_restore_locked_offsets = false;
bool   g_ui_direction_dropdown = false;
bool   g_ui_signal_direction_dropdown = false;
bool   g_ui_additional_dropdown = false;
bool   g_ui_alert_score_dropdown = false;
bool   g_ui_menu_hidden = false;
int    g_ui_x = 70;
int    g_ui_tp_x = 70;
int    g_ui_sl_x = 70;
int    g_ui_tp_width = UI_REFERENCE_WIDTH;
int    g_ui_sl_width = UI_REFERENCE_WIDTH;
bool   g_ui_dragging = false;
bool   g_ui_left_down = false;
int    g_ui_drag_target = 0; // 1=main/ENTRY, 2=TP panel, 3=SL panel
int    g_ui_drag_x = 0;
int    g_ui_drag_y = 0;
int    g_ui_drag_panel_x = 0;
double g_ui_drag_entry = 0.0;
double g_ui_drag_tp = 0.0;
double g_ui_drag_sl = 0.0;
long   g_ui_last_drag_refresh_msc = 0;
const long UI_DRAG_REFRESH_INTERVAL_MSC = 40;
// TP is a planner line until the EA actually installs a broker-side TP.
// While a real TP exists, the TP line/box follows it. When the TP is removed
// or the position closes, the prior planner TP is restored.

string UITFName(const ENUM_TIMEFRAMES timeframe);

// A chart timeframe/symbol change unloads and immediately reloads the EA.
// Keep menu choices only across that chart-change cycle.  The one-shot values
// are deleted after restoration, so removing and attaching the EA again still
// starts from the declared input defaults (especially AUTO OFF on a live chart).
string UIStateKey(const string item)
{
   return "JMD55_UI_V144F_" +
          IntegerToString((long)AccountInfoInteger(ACCOUNT_LOGIN)) + "_" +
          IntegerToString(ChartID()) + "_" + item;
}

string UIAutoSessionKey()
{
   return UIStateKey("AUTO_SESSION_LATCH");
}

bool UIAutoSessionLatched()
{
   return GlobalVariableCheck(UIAutoSessionKey()) &&
          GlobalVariableGet(UIAutoSessionKey()) > 0.5;
}

void UISetAutoSessionLatch(const bool enabled)
{
   if(enabled)
   {
      GlobalVariableSet(UIAutoSessionKey(), 1.0);
      GlobalVariablesFlush();
   }
   else
      GlobalVariableDel(UIAutoSessionKey());
}

bool UIShouldPreserveRuntimeState(const int reason)
{
   // Preserve live menu/AUTO state only when MT5 is reinitializing the same EA.
   // A deliberate EA removal or chart close does not leave a stale AUTO-ON state
   // that could be restored by a later fresh attachment.
   return (reason == REASON_CHARTCHANGE ||
           reason == REASON_PARAMETERS ||
           reason == REASON_RECOMPILE ||
           reason == REASON_ACCOUNT ||
           reason == REASON_TEMPLATE);
}

//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
// User-facing alert localization only. Internal reason/event keys and CSV
// values remain unchanged because conversion happens immediately before
// Alert()/SendNotification().
string JTAUserAlertKorean(const string original)
{
   string s=original;

   // Position direction / generic execution words used in terminal alerts.
   StringReplace(s,"LONG ","롱 ");
   StringReplace(s,"SHORT ","숏 ");
   StringReplace(s," | LONG"," | 롱");
   StringReplace(s," | SHORT"," | 숏");

   // Additional-entry lifecycle.
   StringReplace(s,"ADD BLOCKED: CHASE NOT TREND-PROMOTED","추가진입 차단: 추격진입이 추세관리로 승격되지 않음");
   StringReplace(s,"ADD BLOCKED: TREND FATIGUE","추가진입 차단: 추세 피로");
   StringReplace(s,"ADD BLOCKED: NO TRADE ZONE","추가진입 차단: 거래금지구간");
   StringReplace(s,"ADD BLOCKED: CONF ","추가진입 차단: 신뢰도 ");
   StringReplace(s," / OPP "," / 반대 ");
   StringReplace(s,"ADD READY CANCEL: TIMEOUT","추가진입 준비 취소: 시간초과");
   StringReplace(s,"ADD READY CANCEL: STRUCTURE INVALID","추가진입 준비 취소: 가격구조 무효");
   StringReplace(s,"ADD READY CANCEL: INITIAL 3-SIGNAL STRUCTURE INVALID","추가진입 준비 취소: 최초 3회 신호 가격구조 무효");
   StringReplace(s,"ADD BREAK CONFIRMED: NEXT BAR HOLD WAIT","추가진입 돌파 확인: 다음 봉 유지 확인 대기");
   StringReplace(s,"ADD WAIT: NEXT BAR GATE FAIL / REBREAK REQUIRED","추가진입 대기: 다음 봉 게이트 실패 / 재돌파 필요");
   StringReplace(s,"ADD WAIT: NEXT BAR SEGMENT FAIL / REBREAK REQUIRED","추가진입 대기: 다음 봉 진행 실패 / 재돌파 필요");
   StringReplace(s,"ADD WAIT: FRESH TWO FINAL REQUIRED","추가진입 대기: 새 동일방향 확정신호 2회 필요");
   StringReplace(s,"MA22 PULLBACK SUPPORT + BUY DELTA","MA22 눌림 지지 + 매수 Delta");
   StringReplace(s,"PRIOR HIGH BREAK + BUY VOLUME EXPANSION","이전 고점 돌파 + 매수 거래량 확대");
   StringReplace(s,"MA22 REJECTION + SELL DELTA","MA22 저항 확인 + 매도 Delta");
   StringReplace(s,"PRIOR LOW BREAK + SELL VOLUME EXPANSION","이전 저점 돌파 + 매도 거래량 확대");
   StringReplace(s,"ADD EXPOSURE ROLLED BACK | ORIGINAL POSITION KEPT","추가진입 노출 복구 완료 | 기존 포지션 유지");
   StringReplace(s,"ADD ROLLBACK FAILED | CHECK POSITION/SL","추가진입 복구 실패 | 포지션/SL 확인 필요");
   StringReplace(s,"ADD LAYER CLOSED","추가진입 레이어 청산");
   StringReplace(s,"REMAINING ADD","남은 추가진입");
   StringReplace(s,"ADD POSITION SYNC CONFIRMED","추가진입 포지션 동기화 확인");
   StringReplace(s,"POSITION SYNC CONFIRMED","포지션 동기화 확인");
   StringReplace(s," SENT - POSITION SYNC PENDING | AUTO REMAINS ON"," 주문 전송 - 포지션 동기화 대기 | 자동매매 유지");
   StringReplace(s,"STAGE ","단계 ");
   StringReplace(s," ENTRY WAIT: "," 진입 대기: ");
   StringReplace(s,"[ADD","[추가진입");

   // Hold / profit protection / exit state notifications.
   StringReplace(s,"INITIAL HOLD: OPPOSITE","최초 포지션 홀딩: 반대 확정신호");
   StringReplace(s,"EXIT CANDIDATE: ","청산 후보: ");
   StringReplace(s," FAILURE | WAIT OPPOSITE SIGNAL","회 실패 | 반대 확정신호 대기");
   StringReplace(s,"WARNING: DELTA/MACD/MA7 OR HIGH-LOW STRUCTURE WEAKENING","경고: Delta/MACD/MA7 또는 고점·저점 구조 약화");
   StringReplace(s,"WARNING: DELTA/MACD/MA7 OR LOW-HIGH STRUCTURE WEAKENING","경고: Delta/MACD/MA7 또는 저점·고점 구조 약화");
   StringReplace(s,"STRONG HOLD: MACD + DELTA + MA + STRUCTURE | SCORE ","강한 홀딩: MACD + Delta + MA + 가격구조 | 점수 ");
   StringReplace(s," | NEW EXTREME"," | 신규 극값");
   StringReplace(s,"PROFIT PROTECT: MOMENTUM WEAK FOR CONFIRMED BARS","수익보전: 모멘텀 약화가 완료봉에서 확인됨");
   StringReplace(s,"NORMAL HOLD: TREND ALIVE, TEMPORARY MOMENTUM WEAKNESS ALLOWED","일반 홀딩: 추세 유지, 일시적 모멘텀 약화 허용");
   StringReplace(s,"HOLD: EARLY FAILURE BLOCKED","홀딩 유지: 조기 실패청산 차단");
   StringReplace(s,"DATA_NOT_READY","데이터 준비 안됨");
   StringReplace(s,"DIR_SUPPORT ","방향지지 ");
   StringReplace(s,"KEEP","유지");
   StringReplace(s,"LOST","이탈");
   StringReplace(s,"SHORT-TERM BREAK-EVEN ON","단기 손익분기 보호 적용");
   StringReplace(s,"RANGE PROFIT LOCK ON","횡보 수익잠금 적용");
   StringReplace(s,"SHORT-TERM PARTIAL EXIT: ","단기 부분청산: ");
   StringReplace(s,"PARTIAL EXIT: ","부분청산: ");
   StringReplace(s,"[PROFIT]","[수익]");
   StringReplace(s,"[EXIT]","[청산]");
   StringReplace(s,"[ENTRY]","[진입]");
   StringReplace(s," SAFELY CLOSED"," 안전 청산 완료");
   StringReplace(s," CLOSE FAILED"," 청산 실패");
   StringReplace(s," CLOSED |"," 청산완료 |");
   StringReplace(s," | INITIAL ONLY"," | 최초 포지션만 유지");
   StringReplace(s," | INITIAL HELD"," | 최초 포지션 유지");

   // Entry/order/operation information alerts.
   StringReplace(s,"ENTRY SENT - POSITION SYNC PENDING | AUTO REMAINS ON","진입 주문 전송 - 포지션 동기화 대기 | 자동매매 유지");
   StringReplace(s,"AUTO REMAINS ON - CHECK POSITION","자동매매 유지 - 포지션 확인 필요");
   StringReplace(s,"AUTO REMAINS ON","자동매매 유지");
   StringReplace(s,"AUTO ON - ORDER RETRY WAIT","자동매매 ON - 주문 재시도 대기");
   StringReplace(s,"AUTO ON","자동매매 ON");
   StringReplace(s," FILLED | SIGNALS "," 체결 | 신호누적 ");
   StringReplace(s," FILLED | "," 체결 | ");
   StringReplace(s," | CONF "," | 신뢰도 ");
   StringReplace(s,"PRE-DIRECTION RELEASED | OLD ","사전 방향성 해제 | 이전 ");
   StringReplace(s," | NEW "," | 신규 ");
   StringReplace(s," | COUNT "," | 누적 ");
   StringReplace(s," | SCORE "," | 점수 ");
   StringReplace(s,"CHASE->TREND PROMOTED | HOLD SCORE ","추격진입→추세관리 승격 | 홀딩점수 ");
   StringReplace(s,"[TP] TARGET EXIT | PRICE ","[익절] 목표가 청산 | 가격 ");
   StringReplace(s,"MOBILE PUSH ON - SIGNAL/ENTRY/ADD/EXIT/SL/TP ENABLED","모바일 알림 ON - 신호/진입/추가진입/청산/손절/익절 알림 활성화");
   StringReplace(s,"AUTO OFF·주문없음","자동매매 OFF·주문없음");
   StringReplace(s," | FINAL "," | 확정점수 ");
   // Display-only Korean labels for technical alert tags.
   StringReplace(s,"[FINAL_SIGNAL]","[확정신호]");
   StringReplace(s,"[CONFIRMED_MOMENTUM]","[확정모멘텀]");
   StringReplace(s,"[READY]","[진입대기]");
   StringReplace(s,"[OPPOSITE_FINAL]","[반대확정신호]");
   StringReplace(s,"[ADD_READY]","[추가진입준비]");
   StringReplace(s,"[SIGNAL_ONLY]","[신호전용]");
   StringReplace(s,"[INITIAL_ENTRY]","[자동진입]");
   StringReplace(s,"[ADD_ENTRY]","[추가진입]");
   StringReplace(s,"[REENTRY]","[재진입]");

   return s;
}

//+------------------------------------------------------------------+
void NotifyUser(const string message)
{
   Print(message);
   const bool tester =
      (bool)MQLInfoInteger(MQL_TESTER);
   if(g_terminal_alert && !tester)
   {
      const string user_message=JTAUserAlertKorean(message);
      Alert(user_message);
      // MOB is an additional delivery channel under SYS.
      // SYS OFF means no terminal alert and no mobile push.
      if(g_mobile_alert)
         SendNotification(user_message);
   }
}

//+------------------------------------------------------------------+
// Terminal-only information and error alerts.  These deliberately do not
// create mobile push notifications.
void NotifyTerminalOnly(const string message)
{
   Print(message);
   const bool tester =
      (bool)MQLInfoInteger(MQL_TESTER);
   if(g_terminal_alert && !tester)
      Alert(JTAUserAlertKorean(message));
}

//+------------------------------------------------------------------+
// Signal notification path. When AUTO is disabled the message explicitly
// states that no order was sent. MOBILE and terminal toggles are still
// controlled by NotifyUser().
void NotifySignalUser(const string message)
{
   string final_message = message;
   if(!g_auto_trading)
      final_message += " | AUTO OFF·주문없음 [SIGNAL_ONLY]";
   NotifyUser(final_message);
}

// v3.68: same terminal popup/mobile behavior as NotifyUser(), but the normal
// terminal Alert event sound is immediately stopped and replaced by the
// requested WAV. This is used only for 3X and WATCH Trigger Price events.
void NotifyUserWithPcSound(const string message,const string sound_file)
{
   Print(message);
   const bool tester=(bool)MQLInfoInteger(MQL_TESTER);
   if(g_terminal_alert && !tester)
   {
      const string user_message=JTAUserAlertKorean(message);
      Alert(user_message);
      // Alert() invokes the terminal's default alert event sound. Stop that
      // playback before starting the event-specific sound to avoid two sounds.
      PlaySound(NULL);
      if(sound_file!="")
         PlaySound(sound_file);
      if(g_mobile_alert)
         SendNotification(user_message);
   }
}

void NotifySignalUserWithPcSound(const string message,const string sound_file)
{
   string final_message=message;
   if(!g_auto_trading)
      final_message+=" | AUTO OFF·주문없음 [SIGNAL_ONLY]";
   NotifyUserWithPcSound(final_message,sound_file);
}

// v8.01: WATCH alert delivery deduplication is independent of chart objects and
// StateEvaluation reset/reinitialization. A chart timeframe change can unload
// and reload the EA, recreating the same closed-bar WATCH state. Persist the
// last delivered WATCH bar per symbol+direction in terminal Global Variables so
// the same market event is never replayed merely because the chart was changed.
// v8.32: StateEvaluation pre-reversal and SignalEngine reversal are
// independent user events.  Deduplicate by event family so one engine can
// never suppress the other on the same symbol/direction/closed bar.
string JTAWatchAlertDedupKey(const int side,const string event_family)
{
   return "JTC_WATCH_ALERT_V832_" +
          IntegerToString((long)AccountInfoInteger(ACCOUNT_LOGIN)) + "_" +
          _Symbol + "_" + event_family + "_" +
          (side>0 ? "LONG" : "SHORT");
}

bool JTAWatchAlertAlreadyDelivered(const int side,const datetime bar_time,const string event_family)
{
   if(side==0 || bar_time<=0)
      return false;
   const string key=JTAWatchAlertDedupKey(side,event_family);
   if(!GlobalVariableCheck(key))
      return false;
   return ((datetime)GlobalVariableGet(key))==bar_time;
}

void JTAWatchAlertMarkDelivered(const int side,const datetime bar_time,const string event_family)
{
   if(side==0 || bar_time<=0)
      return;
   GlobalVariableSet(JTAWatchAlertDedupKey(side,event_family),(double)bar_time);
}

string JTAPreReversalEpisodeKey(const int side)
{
   return "JTC_PRE_REV_EP_V832_" +
          IntegerToString((long)AccountInfoInteger(ACCOUNT_LOGIN)) + "_" +
          _Symbol + "_" + (side>0 ? "LONG" : "SHORT");
}

string JTAPreReversalRepeatAlertKey(const int side)
{
   return "JTC_PRE_REV_REPEAT_V832_" +
          IntegerToString((long)AccountInfoInteger(ACCOUNT_LOGIN)) + "_" +
          _Symbol + "_" + (side>0 ? "LONG" : "SHORT");
}

void JTAPreReversalEpisodeStart(const int side,const datetime start_bar)
{
   if(side==0 || start_bar<=0) return;
   GlobalVariableSet(JTAPreReversalEpisodeKey(side),(double)start_bar);
}

bool JTAPreReversalFirstRepeatPending(const int side)
{
   if(side==0) return false;
   const string episode_key=JTAPreReversalEpisodeKey(side);
   if(!GlobalVariableCheck(episode_key)) return false;
   const datetime episode_start=(datetime)GlobalVariableGet(episode_key);
   if(episode_start<=0) return false;
   const string repeat_key=JTAPreReversalRepeatAlertKey(side);
   if(!GlobalVariableCheck(repeat_key)) return true;
   return ((datetime)GlobalVariableGet(repeat_key))!=episode_start;
}

void JTAPreReversalMarkFirstRepeatDelivered(const int side)
{
   if(side==0) return;
   const string episode_key=JTAPreReversalEpisodeKey(side);
   if(!GlobalVariableCheck(episode_key)) return;
   GlobalVariableSet(JTAPreReversalRepeatAlertKey(side),GlobalVariableGet(episode_key));
}

void JTAPreReversalEpisodeClose(const int side)
{
   if(side==0) return;
   const string episode_key=JTAPreReversalEpisodeKey(side);
   const string repeat_key=JTAPreReversalRepeatAlertKey(side);
   if(GlobalVariableCheck(episode_key))
      GlobalVariableDel(episode_key);
   if(GlobalVariableCheck(repeat_key))
      GlobalVariableDel(repeat_key);
}


string JTAAlertModeKorean()
{
   const ENUM_STRATEGY_MODE mode =
      g_position_strategy_locked ? g_position_strategy : g_selected_strategy;
   if(mode==STRATEGY_TREND) return "레거시";
   if(mode==STRATEGY_RANGE) return "횡보";
   return "스캘핑";
}

string JTAAlertSideKorean(const int side)
{
   return side>0 ? "롱" : "숏";
}

string JTAAlertReasonKorean(const string reason)
{
   if(StringFind(reason,"OPPOSITE_FINAL_2")>=0 ||
      StringFind(reason,"OPPOSITE FINAL 2")>=0) return "반대 확정신호 2회";
   if(StringFind(reason,"PROFIT_LOCK")>=0 ||
      StringFind(reason,"PROFIT LOCK")>=0) return "수익보전";
   if(StringFind(reason,"STRATEGY FAILURE")>=0) return "진입 논리 실패";
   if(StringFind(reason,"HOLD_EXIT_CANDIDATE")>=0 ||
      StringFind(reason,"HOLD EXIT")>=0) return "홀딩조건 약화";
   if(StringFind(reason,"RANGE_HOLD_EXIT")>=0 ||
      StringFind(reason,"RANGE HOLD")>=0) return "횡보 홀딩조건 종료";
   if(StringFind(reason,"BROKER SL")>=0) return "설정 손절가 도달";
   if(StringFind(reason,"BROKER TP")>=0) return "설정 익절가 도달";
   if(StringFind(reason,"MANUAL CLOSE")>=0) return "수동청산";
   if(StringFind(reason,"GIVEBACK")>=0) return "최고수익 대비 수익 되돌림";
   if(StringFind(reason,"BE")>=0) return "손익분기 보호";
   if(StringFind(reason,"SPREAD")>=0) return "스프레드 초과";
   if(StringFind(reason,"INVALID QUOTE")>=0) return "가격정보 오류";
   if(StringFind(reason,"MAX")>=0 && StringFind(reason,"POSITION")>=0) return "최대 포지션 도달";
   if(StringFind(reason,"LOSS")>=0 && StringFind(reason,"ADD")>=0) return "손실 중 추가진입 금지";
   return "상세 영문사유 참조";
}

string JTAAlertSignedMoney(const double value)
{
   return StringFormat("%+.2f %s",value,AccountInfoString(ACCOUNT_CURRENCY));
}

string JTAAlertSide(const int side)
{
   return side>0 ? "LONG" : "SHORT";
}


string JTAFormatM3StructureTriggerAlert(const int side,const datetime bar_time,const double price,const string event_name)
{
   return StringFormat("[%s] %s M3 %s %s 신호 | 시간 %s | 가격 %.*f [M3_%s]",
      JTAAlertModeKorean(),_Symbol,JTAAlertSideKorean(side),event_name,
      TimeToString(bar_time,TIME_DATE|TIME_MINUTES),_Digits,price,event_name);
}

string JTAFormatFinalSignalAlert(const int side,const int score,
                                 const int count,const int required,
                                 const string pattern)
{
   string next_ko="관찰";
   if(required>0)
   {
      if(count>=required) next_ko="진입 방향확인 대기";
      else next_ko=StringFormat("%d회 추가 대기",MathMax(0,required-count));
   }
   return StringFormat("[%s] %s %s 확정신호 | 점수 %d | 누적 %d/%d | 다음: %s [FINAL_SIGNAL]",
      JTAAlertModeKorean(),_Symbol,JTAAlertSideKorean(side),score,
      MathMax(0,count),MathMax(1,required),next_ko);
}

string JTAFormatConfirmedMomentumAlert(const int side,const int score,const string detail)
{
   return StringFormat("[%s] %s %s확정 모멘텀 | FINAL %d | %s [CONFIRMED_MOMENTUM]",
      JTAAlertModeKorean(),_Symbol,side>0 ? "롱" : "숏",score,detail);
}

//+------------------------------------------------------------------+
// Observation-only momentum marker. Slightly larger than FINAL, but kept
// compact so it does not obscure candles or the existing FINAL score label.
void DrawConfirmedMomentumArrow(const int side,
                                const datetime signal_time,
                                const double signal_price,
                                const int score,
                                const ENUM_TIMEFRAMES signal_tf=PERIOD_CURRENT)
{
   const ENUM_TIMEFRAMES arrow_tf =
      (signal_tf==PERIOD_CURRENT ? g_calc_tf : signal_tf);
   if(signal_time<=0) return;

   const string name=
      "JTA_CONFIRMED_MOMENTUM_"+(side>0 ? "LONG_" : "SHORT_")+
      IntegerToString((long)signal_time);
   const double high=iHigh(_Symbol,arrow_tf,1);
   const double low=iLow(_Symbol,arrow_tf,1);
   const double range=MathMax(high-low,10.0*_Point);
   const double arrow_price=NormalizePrice(
      side>0 ? low-range*0.50 : high+range*0.50);

   if(ObjectFind(0,name)<0)
   {
      if(!ObjectCreate(0,name,OBJ_ARROW,0,signal_time,arrow_price)) return;
      ObjectSetInteger(0,name,OBJPROP_ARROWCODE,side>0 ? 233 : 234);
      ObjectSetInteger(0,name,OBJPROP_COLOR,
                       side>0 ? C'0,135,55' : C'210,25,35');
      ObjectSetInteger(0,name,OBJPROP_WIDTH,3);
      ObjectSetInteger(0,name,OBJPROP_ANCHOR,
                       side>0 ? ANCHOR_BOTTOM : ANCHOR_TOP);
      ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);
      ObjectSetInteger(0,name,OBJPROP_HIDDEN,false);
      ObjectSetInteger(0,name,OBJPROP_BACK,false);
   }
   ObjectMove(0,name,0,signal_time,arrow_price);
   ObjectSetString(0,name,OBJPROP_TOOLTIP,
      StringFormat("%s CONFIRMED MOMENTUM\nPrice: %.*f\nFINAL Score: %d",
                   side>0 ? "LONG" : "SHORT",_Digits,signal_price,score));
}

string JTAFormatReadyAlert(const int side,const int score,
                           const int count,const int required)
{
   return StringFormat("[%s] %s %s 확정신호 3회 누적 | 점수 %d | 다음: 가격돌파 확인 [READY]",
      JTAAlertModeKorean(),_Symbol,JTAAlertSideKorean(side),score);
}

string JTAFormatOppositeManagementAlert(const int held_side,
                                        const int opposite_score,
                                        const int count)
{
   const int opposite_side=-held_side;
   return StringFormat("[%s] %s 보유 %s | 반대 %s 확정신호 %d/2 | 점수 %d | %s [OPPOSITE_FINAL]",
      JTAAlertModeKorean(),_Symbol,JTAAlertSideKorean(held_side),
      JTAAlertSideKorean(opposite_side),MathMin(2,MathMax(0,count)),opposite_score,
      count>=2 ? "청산 확인" : "포지션 유지");
}

string JTAFormatAddSignalAlert(const int side,const int score,
                               const int count)
{
   return StringFormat("[%s] %s %s 추가진입 준비 | 점수 %d | 다음: 신호봉 돌파 [ADD_READY]",
      JTAAlertModeKorean(),_Symbol,JTAAlertSideKorean(side),score);
}

//+------------------------------------------------------------------+
// v4.38: position-management state updates are status-only.
// STRONG/NORMAL HOLD, PROFIT PROTECT, WARNING, ADD WAIT and similar
// management states no longer generate MT5 terminal/system alerts.
// Trading logic, status text, CSV/audit and actual execution alerts are unchanged.
void NotifyPositionState(const string state)
{
   g_status = state;
   if(state == g_last_position_state_alert)
      return;
   g_last_position_state_alert = state;
}

//+------------------------------------------------------------------+
void DrawSignalScoreLabel(const string arrow_name,
                          const int side,
                          const datetime signal_time,
                          const double arrow_price,
                          const int score,
                          const bool auto_marker=false)
{
   // v8.07: all chart arrow score/numeric text is disabled globally.
   // Retain this helper only to remove stale labels created by older versions.
   ObjectDelete(0,arrow_name+"_SCORE");
}

//+------------------------------------------------------------------+
//| v7.84 FINAL chart-object lifecycle                               |
//| WATCH already bounds its historical chart objects. FINAL now     |
//| follows the same ~300-object budget without scanning ObjectsTotal |
//| on every signal: 150 FINAL events x (arrow + score text).         |
//| This is chart/UI ownership only; signal/CSV/3X/order history is   |
//| untouched.                                                        |
//+------------------------------------------------------------------+
bool UIShouldDrawHistoricalSignalMarkers()
{
   return !((bool)MQLInfoInteger(MQL_TESTER) &&
            !(bool)MQLInfoInteger(MQL_VISUAL_MODE));
}

// v8.114: dedicated visual marker for the canonical M3 acceleration event.
// This is a chart/alert presentation layer only. It never creates or modifies
// the canonical market event or AUTO execution state.
void DrawM3AccelerationMarker(const int side,
                              const datetime signal_time,
                              const double signal_price)
{
   if(side==0 || signal_time<=0 || !UIShouldDrawHistoricalSignalMarkers())
      return;

   const string prefix="JTA_M3_ACCEL_";
   const string name=prefix+(side>0 ? "LONG_" : "SHORT_")+
                     IntegerToString((long)signal_time);
   const string label_name=name+"_LABEL";
   const double high=iHigh(_Symbol,AUTO_TF,1);
   const double low=iLow(_Symbol,AUTO_TF,1);
   const double range=MathMax(high-low,10.0*_Point);
   const double marker_price=NormalizePrice(
      side>0 ? low-range*0.30 : high+range*0.30);
   const color marker_color=(side>0 ? clrDeepSkyBlue : clrMagenta);
   const string label_text=(side>0 ? "LONG ACCEL" : "SHORT ACCEL");

   if(ObjectFind(0,name)>=0)
   {
      const ENUM_OBJECT type=(ENUM_OBJECT)ObjectGetInteger(0,name,OBJPROP_TYPE);
      if(type!=OBJ_ARROW)
         ObjectDelete(0,name);
   }

   if(ObjectFind(0,name)<0)
   {
      if(!ObjectCreate(0,name,OBJ_ARROW,0,signal_time,marker_price))
         return;
      ObjectSetInteger(0,name,OBJPROP_ARROWCODE,side>0 ? 233 : 234);
      ObjectSetInteger(0,name,OBJPROP_WIDTH,2);
      ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);
      ObjectSetInteger(0,name,OBJPROP_HIDDEN,false);
      ObjectSetInteger(0,name,OBJPROP_BACK,false);
      ObjectSetInteger(0,name,OBJPROP_ANCHOR,
                       side>0 ? ANCHOR_BOTTOM : ANCHOR_TOP);
   }
   ObjectMove(0,name,0,signal_time,marker_price);
   ObjectSetInteger(0,name,OBJPROP_COLOR,marker_color);
   ObjectSetString(0,name,OBJPROP_TOOLTIP,
      StringFormat("%s | M3 acceleration | %s",
                   label_text,EnumToString(AUTO_TF)));
   // v8.258: remove chart text for ACCEL and leave arrow marker only.
   // Delete stale label objects from older versions and do not recreate them.
   if(ObjectFind(0,label_name)>=0)
      ObjectDelete(0,label_name);
}

void DeleteOldM3AccelerationMarkers()
{
   if((bool)MQLInfoInteger(MQL_TESTER))
      return;

   const int total=ObjectsTotal(0,0,-1);
   int kept=0;
   for(int i=total-1;i>=0;i--)
   {
      const string name=ObjectName(0,i,0,-1);
      if(StringFind(name,"JTA_M3_ACCEL_")!=0)
         continue;
      kept++;
      if(kept>150)
      {
         ObjectDelete(0,name);
         ObjectDelete(0,name+"_LABEL");
      }
   }
}


void UITrackFinalSignalMarker(const int side,const datetime signal_time)
{
   if(side==0 || signal_time<=0)
      return;

   if((bool)MQLInfoInteger(MQL_TESTER) &&
      (bool)MQLInfoInteger(MQL_VISUAL_MODE))
      return;

   const int max_events=150;
   static datetime times[150];
   static int sides[150];
   static int head=0;
   static int count=0;

   if(count>=max_events)
   {
      const datetime old_time=times[head];
      const int old_side=sides[head];
      if(old_time>0 && old_side!=0)
      {
         const string old_name=
            "JTA_SIGNAL_ARROW_" + (old_side>0 ? "LONG_" : "SHORT_") +
            IntegerToString((long)old_time);
         ObjectDelete(0,old_name+"_SCORE");
         ObjectDelete(0,old_name);
      }
   }
   else
      count++;

   times[head]=signal_time;
   sides[head]=side;
   head++;
   if(head>=max_events)
      head=0;
}

//+------------------------------------------------------------------+
void RemoveEntrySignalArrow(const int side)
{
   if(!UIShouldDrawHistoricalSignalMarkers())
      return;

   // v7.84: this function only owns the current completed bar. If this side
   // did not draw a FINAL on that bar, there is nothing to look up/delete.
   // This eliminates thousands of synchronous chart-object delete lookups
   // during ordinary blocked bars.
   const datetime signal_time = iTime(_Symbol, g_calc_tf, 1);
   if(signal_time <= 0)
      return;

   if(side>0)
   {
      if(g_last_long_signal_bar!=signal_time)
         return;
   }
   else if(side<0)
   {
      if(g_last_short_signal_bar!=signal_time)
         return;
   }
   else
      return;

   const string name =
      "JTA_SIGNAL_ARROW_" + (side > 0 ? "LONG_" : "SHORT_") +
      IntegerToString((long)signal_time);
   ObjectDelete(0,name+"_SCORE");
   ObjectDelete(0,name);

   if(side>0)
      g_last_long_signal_bar=0;
   else
      g_last_short_signal_bar=0;
}

//+------------------------------------------------------------------+
void DrawEntrySignalArrow(const int side,
                          const int score,
                          const string pattern,
                          const string macd_state,
                          const string delta_state,
                          const double signal_price,
                          const ENUM_TIMEFRAMES signal_tf=PERIOD_CURRENT)
{
   if(!UIShouldDrawHistoricalSignalMarkers())
      return;

   const ENUM_TIMEFRAMES arrow_tf =
      (signal_tf==PERIOD_CURRENT ? g_calc_tf : signal_tf);
   const datetime signal_time = iTime(_Symbol, arrow_tf, 1);
   if(signal_time <= 0)
      return;

   // v8.81: canonical M3 structure triggers are not score-based signals.
   // A negative score is reserved for this canonical path so the chart cannot
   // present legacy score/pattern information as the reason for an M3 trigger.
   // Legacy FINAL signals retain the historical score display.
   const bool canonical_m3 = (score < 0 && arrow_tf == AUTO_TF);
   const string name =
      "JTA_SIGNAL_ARROW_" + (side > 0 ? "LONG_" : "SHORT_") +
      IntegerToString((long)signal_time);
   const string tooltip = canonical_m3 ?
      StringFormat("M3 %s\nStructure Trigger\nPrice: %.*f",
                   side > 0 ? "LONG" : "SHORT", _Digits, signal_price) :
      StringFormat("%s FINAL\nPrice: %.*f\nScore: %d",
                   side > 0 ? "LONG" : "SHORT", _Digits, signal_price, score);
   const double high = iHigh(_Symbol, arrow_tf, 1);
   const double low = iLow(_Symbol, arrow_tf, 1);
   const double range = MathMax(high - low, 10.0 * _Point);
   const double arrow_price =
      NormalizePrice(side > 0 ? low - range * 0.22
                              : high + range * 0.22);
   const double score_price =
      NormalizePrice(side > 0 ? low - range * 0.36
                              : high + range * 0.36);

   if(ObjectFind(0, name) >= 0)
   {
      const ENUM_OBJECT existing_type=(ENUM_OBJECT)ObjectGetInteger(0,name,OBJPROP_TYPE);
      if(existing_type!=OBJ_ARROW)
         ObjectDelete(0,name);
   }
   if(ObjectFind(0, name) < 0)
   {
      if(!ObjectCreate(0,name,OBJ_ARROW,0,signal_time,arrow_price))
         return;
      UITrackFinalSignalMarker(side,signal_time);
      ObjectSetInteger(0,name,OBJPROP_ARROWCODE,side>0 ? 233 : 234);
      ObjectSetInteger(0,name,OBJPROP_COLOR,
                       side>0 ? C'0,135,55' : C'210,25,35');
      ObjectSetInteger(0,name,OBJPROP_WIDTH,2);
      ObjectSetInteger(0,name,OBJPROP_ANCHOR,
                       side>0 ? ANCHOR_BOTTOM : ANCHOR_TOP);
      ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);
      ObjectSetInteger(0,name,OBJPROP_HIDDEN,false);
      ObjectSetInteger(0,name,OBJPROP_BACK,false);
   }
   ObjectMove(0,name,0,signal_time,arrow_price);
   ObjectSetString(0,name,OBJPROP_TOOLTIP,tooltip);

   if(canonical_m3)
      ObjectDelete(0,name+"_SCORE");
   else
      DrawSignalScoreLabel(name, side, signal_time, score_price, score, false);
   if(side > 0)
      g_last_long_signal_bar = signal_time;
   else
      g_last_short_signal_bar = signal_time;
}

//+------------------------------------------------------------------+
void UpdateChartComment()
{
   if((bool)MQLInfoInteger(MQL_TESTER) &&
      !(bool)MQLInfoInteger(MQL_VISUAL_MODE))
      return;

   // v2.90: compare primitive displayed values before building strings.
   // Existing call sites remain unchanged, so UI behavior stays immediate
   // while per-tick string allocation/concatenation is skipped when unchanged.
   static bool initialized=false;
   static ENUM_SIGNAL_DIRECTION last_signal_direction=SIGNAL_BOTH;
   static bool last_system_enabled=false;
   static bool last_auto=false;
   static bool last_terminal_alert=false;
   static bool last_mobile_alert=false;
   static ENUM_TIMEFRAMES last_signal_tf=PERIOD_CURRENT;
   static double last_lots=0.0;
   static double last_sl_percent=0.0;

   const bool changed =
      !initialized ||
      last_signal_direction != g_signal_direction ||
      last_system_enabled != InpSystemEnabled ||
      last_auto != g_auto_trading ||
      last_terminal_alert != g_terminal_alert ||
      last_mobile_alert != g_mobile_alert ||
      last_signal_tf != g_signal_tf ||
      MathAbs(last_lots-g_ui_lots) > 1e-12 ||
      MathAbs(last_sl_percent-g_stop_loss_percent) > 1e-12;

   if(!changed && g_last_chart_comment!="")
      return;

   last_signal_direction=g_signal_direction;
   last_system_enabled=InpSystemEnabled;
   last_auto=g_auto_trading;
   last_terminal_alert=g_terminal_alert;
   last_mobile_alert=g_mobile_alert;
   last_signal_tf=g_signal_tf;
   last_lots=g_ui_lots;
   last_sl_percent=g_stop_loss_percent;
   initialized=true;

   const string signal_side =
      (g_signal_direction == SIGNAL_BOTH ? "BOTH" :
       g_signal_direction == SIGNAL_LONG_ONLY ? "BUY" : "SELL");

   const string next_comment =
      "SIGNAL DIR: " + signal_side + "\n" +
      "SYSTEM TRADING: " + (InpSystemEnabled ? "ON" : "OFF") +
      " | AUTO: " + (g_auto_trading ? "ON" : "OFF") + "\n" +
      "SYSTEM ALERT: " + (g_terminal_alert ? "ON" : "OFF") +
      " | MOBILE ALERT: " + (g_mobile_alert ? "ON" : "OFF") + "\n" +
      "TRADING TIMEFRAME: " + UITFName(AUTO_TF) +
      " | AUTO: M2/M5" +
      " | LOT: " + DoubleToString(g_ui_lots, 2) +
      " | SL: " + DoubleToString(g_stop_loss_percent, 2) + "%";

   if(next_comment == g_last_chart_comment)
      return;

   Comment(next_comment);
   g_last_chart_comment = next_comment;
}

double UITickSize()
{
   double value = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   if(value <= 0.0) value = _Point;
   return value;
}

double UIPrice(const string name)
{
   return ObjectGetDouble(0, name, OBJPROP_PRICE);
}

// v6.16: Keep the last UI values in EA memory instead of querying chart
// objects on every refresh. ObjectGet* calls are synchronous and can stall
// behind an already-busy chart command queue. These small caches preserve the
// v6.15 dirty-update behaviour without synchronous property reads.
struct SUIIntegerCacheEntry
{
   string name;
   int    property;
   long   value;
};

struct SUIDoubleCacheEntry
{
   string name;
   int    property;
   double value;
};

struct SUIStringCacheEntry
{
   string name;
   int    property;
   string value;
};

SUIIntegerCacheEntry g_ui_integer_cache[];
SUIDoubleCacheEntry  g_ui_double_cache[];
SUIStringCacheEntry  g_ui_string_cache[];

void UICacheReset()
{
   ArrayResize(g_ui_integer_cache,0);
   ArrayResize(g_ui_double_cache,0);
   ArrayResize(g_ui_string_cache,0);
}

int UIFindIntegerCache(const string name,const int property)
{
   for(int i=0;i<ArraySize(g_ui_integer_cache);i++)
      if(g_ui_integer_cache[i].property==property &&
         g_ui_integer_cache[i].name==name)
         return i;
   return -1;
}

int UIFindDoubleCache(const string name,const int property)
{
   for(int i=0;i<ArraySize(g_ui_double_cache);i++)
      if(g_ui_double_cache[i].property==property &&
         g_ui_double_cache[i].name==name)
         return i;
   return -1;
}

int UIFindStringCache(const string name,const int property)
{
   for(int i=0;i<ArraySize(g_ui_string_cache);i++)
      if(g_ui_string_cache[i].property==property &&
         g_ui_string_cache[i].name==name)
         return i;
   return -1;
}

bool UISetIntegerIfChanged(const string name,
                           const ENUM_OBJECT_PROPERTY_INTEGER property,
                           const long value)
{
   const int property_id=(int)property;
   int idx=UIFindIntegerCache(name,property_id);
   if(idx>=0 && g_ui_integer_cache[idx].value==value)
      return false;

   if(!ObjectSetInteger(0,name,property,value))
      return false;

   if(idx<0)
   {
      idx=ArraySize(g_ui_integer_cache);
      ArrayResize(g_ui_integer_cache,idx+1);
      g_ui_integer_cache[idx].name=name;
      g_ui_integer_cache[idx].property=property_id;
   }
   g_ui_integer_cache[idx].value=value;
   JRO_RequestChartRedraw();
   return true;
}

bool UISetDoubleIfChanged(const string name,
                          const ENUM_OBJECT_PROPERTY_DOUBLE property,
                          const double value,
                          const double tolerance)
{
   const int property_id=(int)property;
   int idx=UIFindDoubleCache(name,property_id);
   if(idx>=0 && MathAbs(g_ui_double_cache[idx].value-value)<=tolerance)
      return false;

   if(!ObjectSetDouble(0,name,property,value))
      return false;

   if(idx<0)
   {
      idx=ArraySize(g_ui_double_cache);
      ArrayResize(g_ui_double_cache,idx+1);
      g_ui_double_cache[idx].name=name;
      g_ui_double_cache[idx].property=property_id;
   }
   g_ui_double_cache[idx].value=value;
   JRO_RequestChartRedraw();
   return true;
}

bool UISetStringIfChanged(const string name,
                          const ENUM_OBJECT_PROPERTY_STRING property,
                          const string value)
{
   const int property_id=(int)property;
   int idx=UIFindStringCache(name,property_id);
   if(idx>=0 && g_ui_string_cache[idx].value==value)
      return false;

   if(!ObjectSetString(0,name,property,value))
      return false;

   if(idx<0)
   {
      idx=ArraySize(g_ui_string_cache);
      ArrayResize(g_ui_string_cache,idx+1);
      g_ui_string_cache[idx].name=name;
      g_ui_string_cache[idx].property=property_id;
   }
   g_ui_string_cache[idx].value=value;
   JRO_RequestChartRedraw();
   return true;
}

void UISetRect(const string name, const int x, const int y,
               const int width, const int height)
{
   UISetIntegerIfChanged(name, OBJPROP_XDISTANCE, MathMax(0, x));
   UISetIntegerIfChanged(name, OBJPROP_YDISTANCE, MathMax(0, y));
   UISetIntegerIfChanged(name, OBJPROP_XSIZE, MathMax(1, width));
   UISetIntegerIfChanged(name, OBJPROP_YSIZE, MathMax(1, height));
}

void UICreateRect(const string name, const color background,
                  const color border)
{
   ObjectCreate(0, name, OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_BGCOLOR, background);
   ObjectSetInteger(0, name, OBJPROP_COLOR, border);
   ObjectSetInteger(0, name, OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
}

void UICreateLabel(const string name)
{
   ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 8);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clrBlack);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
   ObjectSetString(0, name, OBJPROP_FONT, "Arial Bold");
}

void UICreateButton(const string name, const string text,
                    const color background, const int width)
{
   ObjectCreate(0, name, OBJ_BUTTON, 0, 0, 0);
   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_BGCOLOR, background);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clrBlack);
   ObjectSetInteger(0, name, OBJPROP_BORDER_COLOR, C'115,115,115');
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 8);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
   ObjectSetString(0, name, OBJPROP_FONT, "Arial Bold");
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   UISetRect(name, 0, 0, width, UI_H);
}

void UICreateHLine(const string name, const double price,
                   const color line_color)
{
   ObjectCreate(0, name, OBJ_HLINE, 0, 0, price);
   ObjectSetInteger(0, name, OBJPROP_COLOR, line_color);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, 1);
   ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_SOLID);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, false);
}

double UIInitialDistance(const double entry)
{
   const long height = ChartGetInteger(0, CHART_HEIGHT_IN_PIXELS, 0);
   const double maximum = ChartGetDouble(0, CHART_PRICE_MAX, 0);
   const double minimum = ChartGetDouble(0, CHART_PRICE_MIN, 0);
   double distance = 0.0;
   if(height > 0 && maximum > minimum)
      // Keep TP/main/SL boxes visibly separated from the whole control stack.
      distance = (maximum - minimum) * 175.0 / (double)height;
   if(distance <= 0.0)
      distance = entry * MathMax(0.01, InpInitialDistancePercent) / 100.0;
   const double tick = UITickSize();
   return MathMax(tick * 10.0, MathCeil(distance / tick) * tick);
}

bool UIYToPrice(const int y, double &price)
{
   int subwindow = 0;
   datetime time = 0;
   const int x = g_ui_x + MathMax(UI_MIN_WIDTH, InpMenuWidth) / 2;
   return ChartXYToTimePrice(0, x, y, subwindow, time, price);
}

void UIResetPrices()
{
   MqlTick tick;
   if(!SymbolInfoTick(_Symbol, tick)) return;
   const double entry = NormalizePrice(g_ui_buy ? tick.ask : tick.bid);
   ObjectSetDouble(0, UI_ENTRY_LINE, OBJPROP_PRICE, entry);

   // 먼저 현재가를 표시해 최종 차트 축척과 ENTRY 화면 위치를 얻는다.
   JRO_RequestChartRedraw();
   int entry_y = 0;
   if(UIPriceToY(entry, entry_y))
   {
      // 위쪽 박스는 주메뉴와 사진처럼 약 3px의 최소 여백만 둔다.
      // TP/SL 박스는 기준선에서 메뉴 방향으로 UI_H만큼 뻗는다.
      int upper_line_offset =
         UI_H / 2 + UI_INITIAL_CLEARANCE_PX + UI_H;

      // 닫힌 기본 상태메뉴는 ENTRY 아래에 9개 행이 있다:
      // controls, strategy/timeframe, signal/auto, SL status, system status,
      // signal direction, auto direction, additional entry, alerts.
      const int controls_top_offset = UI_H / 2 + 3;
      const int full_status_bottom_offset =
         controls_top_offset + 8 * UI_H + 7 * 3;
      int lower_line_offset =
         full_status_bottom_offset + UI_INITIAL_CLEARANCE_PX + UI_H;

      // Never initialize either reference line on or beyond a chart edge.
      // A short chart can otherwise push the SL line below the visible area.
      const int chart_height =
         (int)ChartGetInteger(0, CHART_HEIGHT_IN_PIXELS, 0);
      upper_line_offset =
         MathMin(upper_line_offset,
                 MathMax(1, entry_y - UI_CHART_EDGE_MARGIN_PX));
      lower_line_offset =
         MathMin(lower_line_offset,
                 MathMax(1, chart_height -
                            UI_CHART_EDGE_MARGIN_PX - entry_y));

      double upper_price = 0.0;
      double lower_price = 0.0;
      if(UIYToPrice(entry_y - upper_line_offset, upper_price) &&
         UIYToPrice(entry_y + lower_line_offset, lower_price))
      {
         ObjectSetDouble(0, UI_TP_LINE, OBJPROP_PRICE,
                         NormalizePrice(g_ui_buy ?
                                        upper_price : lower_price));
         ObjectSetDouble(0, UI_SL_LINE, OBJPROP_PRICE,
                         NormalizePrice(g_ui_buy ?
                                        lower_price : upper_price));
         return;
      }
   }

   // 차트 좌표가 아직 준비되지 않은 경우에만 가격 비율 방식으로 대체한다.
   const double distance = UIInitialDistance(entry);
   ObjectSetDouble(0, UI_TP_LINE, OBJPROP_PRICE,
                   NormalizePrice(entry + (g_ui_buy ? distance : -distance)));
   ObjectSetDouble(0, UI_SL_LINE, OBJPROP_PRICE,
                   NormalizePrice(entry + (g_ui_buy ? -distance : distance)));
}

void UIKeepReferenceLinesVisible()
{
   const long chart_height =
      ChartGetInteger(0, CHART_HEIGHT_IN_PIXELS, 0);
   const double maximum = ChartGetDouble(0, CHART_PRICE_MAX, 0);
   const double minimum = ChartGetDouble(0, CHART_PRICE_MIN, 0);
   if(chart_height <= 0 || maximum <= minimum)
      return;

   // Keep every line a few pixels inside the price window.  This also repairs
   // a line pushed outside the chart after automatic scale recalculation.
   const double price_per_pixel =
      (maximum - minimum) / (double)chart_height;
   const double edge_gap =
      MathMax(UITickSize() * 2.0,
              price_per_pixel * UI_CHART_EDGE_MARGIN_PX);
   const double visible_high = maximum - edge_gap;
   const double visible_low = minimum + edge_gap;

   double tp = UIPrice(UI_TP_LINE);
   double sl = UIPrice(UI_SL_LINE);
   tp = MathMax(visible_low, MathMin(visible_high, tp));
   sl = MathMax(visible_low, MathMin(visible_high, sl));
   ObjectSetDouble(0, UI_TP_LINE, OBJPROP_PRICE, NormalizePrice(tp));
   ObjectSetDouble(0, UI_SL_LINE, OBJPROP_PRICE, NormalizePrice(sl));
}

int UIStatusBottomOffset()
{
   const int row_gap=3;
   int offset = UI_H / 2 + row_gap;
   offset += UI_H + row_gap; // NOW / LOT / SL %
   offset += UI_H + row_gap; // strategy
   offset += UI_H + row_gap; // SIGNAL / AUTO
   offset += UI_H + row_gap; // MT5 permission
   offset += UI_H + row_gap; // directions
   if(g_ui_signal_direction_dropdown || g_ui_direction_dropdown)
      offset += UI_H + 2;
   offset += UI_H + row_gap; // maximum ADD
   offset += 20;             // alert row
   if(g_ui_alert_score_dropdown)
      offset += 2 * (UI_H + 2);
   return offset;
}

bool UIShiftAllToEntryY(const int current_entry_y,
                        const int target_entry_y)
{
   if(current_entry_y == target_entry_y)
      return true;

   double current_price = 0.0, target_price = 0.0;
   if(!UIYToPrice(current_entry_y, current_price) ||
      !UIYToPrice(target_entry_y, target_price))
      return false;

   const double delta = target_price - current_price;
   ObjectSetDouble(0, UI_ENTRY_LINE, OBJPROP_PRICE,
                   NormalizePrice(UIPrice(UI_ENTRY_LINE) + delta));
   ObjectSetDouble(0, UI_TP_LINE, OBJPROP_PRICE,
                   NormalizePrice(UIPrice(UI_TP_LINE) + delta));
   ObjectSetDouble(0, UI_SL_LINE, OBJPROP_PRICE,
                   NormalizePrice(UIPrice(UI_SL_LINE) + delta));
   return true;
}

void UIEnsureMenuLineSeparation()
{
   // TP/SL prices are user-selected values.  They may pass through the menu.
   // Only keep genuinely off-screen lines inside the visible price window.
   UIKeepReferenceLinesVisible();
}

void UIArrangeSide()
{
   const double entry = UIPrice(UI_ENTRY_LINE);
   const double tp_distance =
      MathMax(MathAbs(UIPrice(UI_TP_LINE) - entry), UITickSize() * 10.0);
   const double sl_distance =
      MathMax(MathAbs(UIPrice(UI_SL_LINE) - entry), UITickSize() * 10.0);
   ObjectSetDouble(0, UI_TP_LINE, OBJPROP_PRICE,
                   NormalizePrice(entry + (g_ui_buy ? tp_distance : -tp_distance)));
   ObjectSetDouble(0, UI_SL_LINE, OBJPROP_PRICE,
                   NormalizePrice(entry + (g_ui_buy ? -sl_distance : sl_distance)));
}

bool UIPriceToY(const double price, int &y)
{
   int x = 0;
   datetime time = iTime(_Symbol, _Period, 0);
   return ChartTimePriceToXY(0, 0, time, price, x, y);
}

void UICaptureLockOffset(const bool take_profit)
{
   int entry_y = 0, line_y = 0;
   const string line_name = take_profit ? UI_TP_LINE : UI_SL_LINE;
   if(!UIPriceToY(UIPrice(UI_ENTRY_LINE), entry_y) ||
      !UIPriceToY(UIPrice(line_name), line_y))
      return;

   if(take_profit)
   {
      g_ui_tp_lock_y_offset = line_y - entry_y;
      g_ui_tp_lock_x_offset = g_ui_tp_x - g_ui_x;
   }
   else
   {
      g_ui_sl_lock_y_offset = line_y - entry_y;
      g_ui_sl_lock_x_offset = g_ui_sl_x - g_ui_x;
   }
}

void UIApplyLockedOffsets()
{
   if(!g_ui_tp_locked && !g_ui_sl_locked)
      return;

   int entry_y = 0;
   if(!UIPriceToY(UIPrice(UI_ENTRY_LINE), entry_y))
      return;

   const int chart_height =
      (int)ChartGetInteger(0, CHART_HEIGHT_IN_PIXELS, 0);
   if(chart_height <= 0)
      return;

   double locked_price = 0.0;
   if(g_ui_tp_locked)
   {
      const int target_y =
         MathMax(UI_CHART_EDGE_MARGIN_PX,
                 MathMin(chart_height - UI_CHART_EDGE_MARGIN_PX,
                         entry_y + g_ui_tp_lock_y_offset));
      if(UIYToPrice(target_y, locked_price))
         ObjectSetDouble(0, UI_TP_LINE, OBJPROP_PRICE,
                         NormalizePrice(locked_price));
      g_ui_tp_x = g_ui_x + g_ui_tp_lock_x_offset;
   }
   if(g_ui_sl_locked)
   {
      const int target_y =
         MathMax(UI_CHART_EDGE_MARGIN_PX,
                 MathMin(chart_height - UI_CHART_EDGE_MARGIN_PX,
                         entry_y + g_ui_sl_lock_y_offset));
      if(UIYToPrice(target_y, locked_price))
         ObjectSetDouble(0, UI_SL_LINE, OBJPROP_PRICE,
                         NormalizePrice(locked_price));
      g_ui_sl_x = g_ui_x + g_ui_sl_lock_x_offset;
   }
}

double UIProfit(const double entry, const double exit_price)
{
   double result = 0.0;
   const ENUM_ORDER_TYPE type =
      g_ui_buy ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
   if(OrderCalcProfit(type, _Symbol, g_ui_lots, entry, exit_price, result))
      return result;
   return 0.0;
}

//+------------------------------------------------------------------+
// Keep the visible planner SL line/box on the actual broker-side SL while
// an EA-managed position is open.  The line is not overwritten while the
// user is actively dragging the SL panel; UIEndDrag() first applies the
// requested broker modification and the next refresh displays the accepted
// broker value.
// Follow a broker TP only when the EA has actually installed one.  A zero
// POSITION_TP means that TP is still managed by internal exit logic, so the
// user's planner TP must not be overwritten.
int UIReferenceWidthForText(const string text, const int lock_width)
{
   // MT5 does not expose a cheap, reliable text-width API for chart labels.
   // Approximate the 9pt bold caption width and always expand the box before
   // considering any font reduction.
   const int estimated_text_width = StringLen(text) * 6 + UI_REFERENCE_TEXT_PADDING;
   return MathMax(UI_REFERENCE_WIDTH,
                  MathMin(UI_REFERENCE_MAX_WIDTH,
                          estimated_text_width + lock_width));
}

void UIRefresh()
{
   if((bool)MQLInfoInteger(MQL_TESTER) &&
      !(bool)MQLInfoInteger(MQL_VISUAL_MODE))
      return;
   // v4.44: TP/SL planner lines no longer auto-follow broker TP/SL values.
   // They remain visual/manual references and are committed to managed
   // positions only when the user explicitly drags and releases them.
   if(!g_ui_dragging)
      UIEnsureMenuLineSeparation();

   int entry_y = 0, tp_y = 0, sl_y = 0;
   if(!UIPriceToY(UIPrice(UI_ENTRY_LINE), entry_y) ||
      !UIPriceToY(UIPrice(UI_TP_LINE), tp_y) ||
      !UIPriceToY(UIPrice(UI_SL_LINE), sl_y))
      return;

   const int width = MathMax(UI_MIN_WIDTH, InpMenuWidth);
   const int chart_width =
      (int)ChartGetInteger(0, CHART_WIDTH_IN_PIXELS, 0);
   const int maximum_x = MathMax(0, chart_width - width - 30);
   g_ui_x = MathMax(0, MathMin(maximum_x, g_ui_x));
   const int reference_maximum_x =
      MathMax(0, chart_width - UI_REFERENCE_WIDTH - 3);
   g_ui_tp_x = MathMax(0, MathMin(reference_maximum_x, g_ui_tp_x));
   g_ui_sl_x = MathMax(0, MathMin(reference_maximum_x, g_ui_sl_x));
   const int arrow_x = g_ui_x + width + 3;

   // TP, ENTRY/main and SL are independent panels.  Each reference box stays
   // attached to its own real price line and keeps its own horizontal anchor.
   // BUY : TP line is the top edge, SL line is the bottom edge.
   // SELL: SL line is the top edge, TP line is the bottom edge.
   int tp_bar_y = g_ui_buy ? tp_y : tp_y - UI_H;
   int sl_bar_y = g_ui_buy ? sl_y - UI_H : sl_y;

   const int chart_height =
      (int)ChartGetInteger(0, CHART_HEIGHT_IN_PIXELS, 0);
   tp_bar_y = MathMax(0, MathMin(chart_height - UI_H, tp_bar_y));
   sl_bar_y = MathMax(0, MathMin(chart_height - UI_H, sl_bar_y));
   // TP/SL reference panels are always visible.  Before an AUTO fill they are
   // an independent what-if profit/loss calculator; after a fill the same
   // objects remain independent planner/manual reference levels even while a
   // managed position is open. Their prices never auto-follow broker TP/SL and
   // never participate in AUTO entry or automatic stop-loss calculation.
   const bool show_tp = true;
   const bool show_sl = true;
   const double entry = UIPrice(UI_ENTRY_LINE);
   const double tp = UIPrice(UI_TP_LINE);
   const double sl = UIPrice(UI_SL_LINE);
   const double tp_money = UIProfit(entry, tp);
   const double sl_money = UIProfit(entry, sl);
   const double risk = MathAbs(sl_money);
   const double rr = risk > 0.0 ? MathAbs(tp_money) / risk : 0.0;
   const double tp_percent = MathAbs(entry) > 0.0 ? (tp-entry)/entry*100.0 : 0.0;
   const double sl_percent = MathAbs(entry) > 0.0 ? (sl-entry)/entry*100.0 : 0.0;
   const double point = (_Point > 0.0 ? _Point : UITickSize());
   const string tp_caption = StringFormat("TP %+.2f%%  %.1fP  $%+.2f  R1:%.2f",
      tp_percent, MathAbs(tp-entry)/point, tp_money, rr);
   const string sl_caption = StringFormat("SL %+.2f%%  %.1fP  $%+.2f",
      sl_percent, MathAbs(sl-entry)/point, sl_money);
   const int lock_width = 42;
   g_ui_tp_width = MathMin(chart_width - UI_CHART_EDGE_MARGIN_PX,
                           UIReferenceWidthForText(tp_caption, lock_width));
   g_ui_sl_width = MathMin(chart_width - UI_CHART_EDGE_MARGIN_PX,
                           UIReferenceWidthForText(sl_caption, lock_width));
   g_ui_tp_x = MathMax(0, MathMin(MathMax(0, chart_width-g_ui_tp_width-3), g_ui_tp_x));
   g_ui_sl_x = MathMax(0, MathMin(MathMax(0, chart_width-g_ui_sl_width-3), g_ui_sl_x));
   UISetRect(UI_TP_BAR, show_tp ? g_ui_tp_x : chart_width + 50,
             show_tp ? tp_bar_y : 0,
             show_tp ? g_ui_tp_width : 1,
             show_tp ? UI_H : 1);
   UISetRect(UI_SL_BAR, show_sl ? g_ui_sl_x : chart_width + 50,
             show_sl ? sl_bar_y : 0,
             show_sl ? g_ui_sl_width : 1,
             show_sl ? UI_H : 1);
   UISetRect(UI_TP_LOCK,
             show_tp ? g_ui_tp_x + g_ui_tp_width - lock_width :
                       chart_width + 50,
             show_tp ? tp_bar_y : 0, show_tp ? lock_width : 1,
             show_tp ? UI_H : 1);
   UISetRect(UI_SL_LOCK,
             show_sl ? g_ui_sl_x + g_ui_sl_width - lock_width :
                       chart_width + 50,
             show_sl ? sl_bar_y : 0, show_sl ? lock_width : 1,
             show_sl ? UI_H : 1);
   UISetStringIfChanged(UI_TP_LOCK, OBJPROP_TEXT,
                        g_ui_tp_locked ? "LOCK" : "FREE");
   UISetStringIfChanged(UI_SL_LOCK, OBJPROP_TEXT,
                        g_ui_sl_locked ? "LOCK" : "FREE");
   UISetIntegerIfChanged(UI_TP_LOCK, OBJPROP_BGCOLOR,
                         g_ui_tp_locked ? C'65,145,85' : C'215,235,218');
   UISetIntegerIfChanged(UI_SL_LOCK, OBJPROP_BGCOLOR,
                         g_ui_sl_locked ? C'190,75,75' : C'245,215,215');
   UISetIntegerIfChanged(UI_TP_LOCK, OBJPROP_COLOR,
                         g_ui_tp_locked ? clrWhite : clrBlack);
   UISetIntegerIfChanged(UI_SL_LOCK, OBJPROP_COLOR,
                         g_ui_sl_locked ? clrWhite : clrBlack);
   UISetIntegerIfChanged(UI_TP_LINE, OBJPROP_COLOR,
                         show_tp ? C'61,178,95' : clrNONE);
   UISetIntegerIfChanged(UI_SL_LINE, OBJPROP_COLOR,
                         show_sl ? C'232,92,92' : clrNONE);
   UISetRect(UI_ENTRY_BAR, g_ui_x, entry_y - UI_H / 2, width, UI_H);
   UISetRect(UI_SIDE_UP, arrow_x, entry_y - UI_H - 1, 22, UI_H);
   UISetRect(UI_SIDE_DOWN, arrow_x, entry_y + 1, 22, UI_H);

   // v4.47 compact aligned grid. Every main row uses the same left/right
   // edges and consistent 3 px vertical / 2 px horizontal spacing.
   const int row_gap=3;
   const int col_gap=2;
   const int controls_y = entry_y + UI_H / 2 + row_gap;

   // Row 1: NOW | LOT | value | SL % | value
   const int now_width=36;
   const int lot_label_width=28;
   const int sl_label_width=30;
   const int edit_width=
      (width-now_width-lot_label_width-sl_label_width-4*col_gap)/2;
   int compact_x=g_ui_x;
   UISetRect(UI_NOW,compact_x,controls_y,now_width,UI_H);
   compact_x+=now_width+col_gap;
   UISetRect(UI_LOT_LABEL,compact_x,controls_y,lot_label_width,UI_H);
   compact_x+=lot_label_width+col_gap;
   UISetRect(UI_LOT_EDIT,compact_x,controls_y,edit_width,UI_H);
   compact_x+=edit_width+col_gap;
   UISetRect(UI_SL_PERCENT_LABEL,compact_x,controls_y,sl_label_width,UI_H);
   compact_x+=sl_label_width+col_gap;
   UISetRect(UI_SL_PERCENT_EDIT,compact_x,controls_y,
             g_ui_x+width-compact_x,UI_H);

   // v7.11 Row 2: manual-assist state timeframe only.
   // RANGE-only build: this row is dedicated to the manual-assist state timeframe.
   const int selector_y=controls_y+UI_H+row_gap;
   UISetRect(UI_STATE_TF,g_ui_x,selector_y,width,UI_H);

   // Row 3: SIGNAL / AUTO exactly half-and-half.
   const int mode_y=selector_y+UI_H+row_gap;
   const int mode_left_width=(width-col_gap)/2;
   UISetRect(UI_SIGNAL,g_ui_x,mode_y,mode_left_width,UI_H);
   UISetRect(UI_AUTO,g_ui_x+mode_left_width+col_gap,mode_y,
             width-mode_left_width-col_gap,UI_H);

   // Row 4: terminal/EA/account trading permission.
   const int system_status_y=mode_y+UI_H+row_gap;
   UISetRect(UI_MODE_TEXT,g_ui_x,system_status_y,width,UI_H);

   // Row 5: SIGNAL direction / AUTO direction.
   const int signal_direction_y=system_status_y+UI_H+row_gap;
   const int direction_left_width=(width-col_gap)/2;
   const int direction_right_x=g_ui_x+direction_left_width+col_gap;
   const int direction_right_width=width-direction_left_width-col_gap;
   UISetRect(UI_SIGDIR_TEXT,g_ui_x,signal_direction_y,
             direction_left_width,UI_H);
   UISetRect(UI_DIR_TEXT,direction_right_x,signal_direction_y,
             direction_right_width,UI_H);

   const int direction_items_y=signal_direction_y+UI_H+2;
   if(g_ui_signal_direction_dropdown)
   {
      const int w=(direction_left_width-2*col_gap)/3;
      UISetRect(UI_SIGDIR_BOTH,g_ui_x,direction_items_y,w,UI_H);
      UISetRect(UI_SIGDIR_LONG,g_ui_x+w+col_gap,direction_items_y,w,UI_H);
      UISetRect(UI_SIGDIR_SHORT,g_ui_x+2*(w+col_gap),direction_items_y,
                direction_left_width-2*(w+col_gap),UI_H);
   }
   else
   {
      UISetRect(UI_SIGDIR_BOTH,chart_width+50,0,1,1);
      UISetRect(UI_SIGDIR_LONG,chart_width+50,0,1,1);
      UISetRect(UI_SIGDIR_SHORT,chart_width+50,0,1,1);
   }

   if(g_ui_direction_dropdown)
   {
      const int w=(direction_right_width-2*col_gap)/3;
      UISetRect(UI_DIR_BOTH,direction_right_x,direction_items_y,w,UI_H);
      UISetRect(UI_DIR_LONG,direction_right_x+w+col_gap,direction_items_y,w,UI_H);
      UISetRect(UI_DIR_SHORT,direction_right_x+2*(w+col_gap),direction_items_y,
                direction_right_width-2*(w+col_gap),UI_H);
   }
   else
   {
      UISetRect(UI_DIR_BOTH,chart_width+50,0,1,1);
      UISetRect(UI_DIR_LONG,chart_width+50,0,1,1);
      UISetRect(UI_DIR_SHORT,chart_width+50,0,1,1);
   }

   const int combined_direction_dropdown_height=
      (g_ui_signal_direction_dropdown||g_ui_direction_dropdown)?UI_H+2:0;

   // Row 6: MAX ADD count, direct numeric entry like LOT.
   const int additional_y=
      signal_direction_y+UI_H+row_gap+combined_direction_dropdown_height;
   const int add_label_width=(width*46)/100;
   UISetRect(UI_ADD_TEXT,g_ui_x,additional_y,add_label_width,UI_H);
   UISetRect(UI_MAX_ADD_EDIT,g_ui_x+add_label_width+col_gap,additional_y,
             width-add_label_width-col_gap,UI_H);

   // Row 7: user-facing trading alert controls.
   // WATCH controls WATCH notification only; chart WATCH markers remain unchanged.
   // Mobile delivery keeps the existing NotifyUser() hierarchy.
   const int alert_y=additional_y+UI_H+row_gap;
   const int alert_gap=col_gap;
   const int alert_available=width-2*alert_gap;
   const int watch_alert_width=(alert_available*36)/100;
   const int sys_alert_width=(alert_available*32)/100;
   int alert_x=g_ui_x;
   const int alert_row_h=20;
   UISetRect(UI_WATCH_ALERT,alert_x,alert_y,watch_alert_width,alert_row_h);
   alert_x+=watch_alert_width+alert_gap;
   UISetRect(UI_SYS_ALERT,alert_x,alert_y,sys_alert_width,alert_row_h);
   alert_x+=sys_alert_width+alert_gap;
   UISetRect(UI_MOB_ALERT,alert_x,alert_y,g_ui_x+width-alert_x,alert_row_h);
   // Legacy score-alert dropdown is no longer a primary menu control.
   UISetRect(UI_ALERT_SCORE,chart_width+50,0,1,1);

   string alert_score_items[] =
   {
      UI_ALERT_OFF, UI_ALERT_50, UI_ALERT_60,
      UI_ALERT_70, UI_ALERT_80, UI_ALERT_90
   };
   for(int i = 0; i < ArraySize(alert_score_items); i++)
   {
      if(g_ui_alert_score_dropdown)
      {
         const int column = i % 3;
         const int row = i / 3;
         const int item_width = (width - 4) / 3;
         UISetRect(alert_score_items[i],
                   g_ui_x + column * (item_width + 2),
                   alert_y + UI_H + 2 + row * (UI_H + 2),
                   (column == 2 ?
                    width - 2 * (item_width + 2) : item_width),
                   UI_H);
      }
      else
         UISetRect(alert_score_items[i], chart_width + 50, 0, 1, 1);
   }

   const int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);

   UISetStringIfChanged(UI_TP_TEXT, OBJPROP_TEXT, tp_caption);
   UISetStringIfChanged(UI_SL_TEXT, OBJPROP_TEXT, sl_caption);
   UISetStringIfChanged(UI_ENTRY_TEXT, OBJPROP_TEXT,
      (g_ui_buy ? "BUY  " : "SELL  ") +
      DoubleToString(entry, digits) + "   " +
      DoubleToString(g_ui_lots, 2) + " lot");
   // Center the text in the visible caption area, excluding the lock button.
   const int tp_text_width = g_ui_tp_width - lock_width;
   const int sl_text_width = g_ui_sl_width - lock_width;
   UISetIntegerIfChanged(UI_TP_TEXT, OBJPROP_XDISTANCE,
                    g_ui_tp_x + tp_text_width / 2);
   UISetIntegerIfChanged(UI_TP_TEXT, OBJPROP_YDISTANCE,
                    tp_bar_y + UI_H / 2);
   UISetIntegerIfChanged(UI_SL_TEXT, OBJPROP_XDISTANCE,
                    g_ui_sl_x + sl_text_width / 2);
   UISetIntegerIfChanged(UI_SL_TEXT, OBJPROP_YDISTANCE,
                    sl_bar_y + UI_H / 2);
   UISetIntegerIfChanged(UI_ENTRY_TEXT, OBJPROP_XDISTANCE, g_ui_x + 8);
   UISetIntegerIfChanged(UI_ENTRY_TEXT, OBJPROP_YDISTANCE, entry_y - 6);
   UISetStringIfChanged(UI_LOT_LABEL, OBJPROP_TEXT, "LOT");
   if(!g_lot_editing)
      UISetStringIfChanged(UI_LOT_EDIT, OBJPROP_TEXT,
                      UICompactNumber(g_ui_lots, 2));
   UISetStringIfChanged(UI_SL_PERCENT_LABEL, OBJPROP_TEXT, "SL %");
   if(!g_sl_percent_editing)
      UISetStringIfChanged(UI_SL_PERCENT_EDIT, OBJPROP_TEXT,
                      UICompactNumber(g_stop_loss_percent, 2));
   UISetIntegerIfChanged(UI_SIGNAL, OBJPROP_BGCOLOR,
                    g_signal_enabled ? C'70,180,100' : C'150,150,150');
   UISetIntegerIfChanged(UI_AUTO, OBJPROP_BGCOLOR,
                    g_auto_trading ? C'235,95,95' : C'205,205,205');
   UISetIntegerIfChanged(UI_SIGNAL, OBJPROP_COLOR,
                    g_signal_enabled ? clrWhite : clrBlack);
   UISetIntegerIfChanged(UI_AUTO, OBJPROP_COLOR,
                    g_auto_trading ? clrWhite : clrBlack);
   string trade_permission_reason="";
   const bool terminal_trade_allowed =
      JTATradePermissionAllowed(trade_permission_reason);
   UISetStringIfChanged(UI_SIGNAL, OBJPROP_TEXT,
                   g_signal_enabled ? "SIGNAL ON" : "SIGNAL OFF");
   UISetStringIfChanged(UI_AUTO, OBJPROP_TEXT,
                   g_auto_trading ? "AUTO ON" : "AUTO OFF");
   // Keep the MT5-wide trading permission distinct from this EA's AUTO
   // button. Strategy/timeframe text is already shown elsewhere in the menu.
   const string mt5_trading_text = JTATradePermissionStatusText();
   UISetStringIfChanged(UI_MODE_TEXT, OBJPROP_TEXT, mt5_trading_text);
   UISetStringIfChanged(UI_STATE_TF, OBJPROP_TEXT,
                   "TRADE TF: " + UITFName(StateEvaluationTimeframe()));
   UISetIntegerIfChanged(UI_STATE_TF, OBJPROP_BGCOLOR, C'185,215,235');
   UISetIntegerIfChanged(UI_STATE_TF, OBJPROP_COLOR, C'25,70,115');
   UISetIntegerIfChanged(UI_MODE_TEXT, OBJPROP_COLOR,
                    terminal_trade_allowed ? C'25,155,70' :
                                             C'220,35,35');
   UISetStringIfChanged(UI_SIGDIR_TEXT, OBJPROP_TEXT,
                   "SIGNAL: " + SignalDirectionName() + "  ▼");
   UISetIntegerIfChanged(UI_SIGDIR_TEXT, OBJPROP_COLOR, C'35,75,145');
   UISetStringIfChanged(UI_DIR_TEXT, OBJPROP_TEXT,
                   "AUTO: " + AutoDirectionName() + "  ▼");
   UISetIntegerIfChanged(UI_DIR_TEXT, OBJPROP_COLOR,
                    g_trade_direction == TRADE_LONG_ONLY ? C'20,125,55' :
                    (g_trade_direction == TRADE_SHORT_ONLY ?
                     C'190,30,30' : C'35,75,145'));
   UISetStringIfChanged(UI_ADD_TEXT, OBJPROP_TEXT,
                   StringFormat("MAX ADD: %d/%d",
                                g_additional_entry_count,
                                g_max_additional_entries));
   if(!g_max_add_editing)
      UISetStringIfChanged(UI_MAX_ADD_EDIT, OBJPROP_TEXT,
                           IntegerToString(g_max_additional_entries));
   UISetIntegerIfChanged(UI_ADD_TEXT, OBJPROP_COLOR,
                    g_max_additional_entries > 0 ?
                    C'135,75,15' : C'100,100,100');
   UISetIntegerIfChanged(UI_ADD_TEXT, OBJPROP_BGCOLOR,C'245,225,185');


   UISetStringIfChanged(UI_SYS_ALERT, OBJPROP_TEXT,
                   g_terminal_alert ? "SYS ON" : "SYS OFF");
   UISetStringIfChanged(UI_MOB_ALERT, OBJPROP_TEXT,
                   g_mobile_alert ? "MOB ON" : "MOB OFF");
   UISetStringIfChanged(UI_WATCH_ALERT, OBJPROP_TEXT,
                   g_watch_mode==WATCH_MODE_CHART_ALERT ? "WATCH ON" : "WATCH OFF");
   UISetStringIfChanged(UI_ALERT_SCORE, OBJPROP_TEXT,
                   g_minimum_alert_score<=0 ?
                   "ALERT OFF  ▼" :
                   StringFormat("ALERT %d+  ▼", g_minimum_alert_score));
   UISetIntegerIfChanged(UI_ALERT_SCORE, OBJPROP_BGCOLOR,
                    g_minimum_alert_score<=0 ? C'205,205,205' : C'235,190,85');
   UISetIntegerIfChanged(UI_ALERT_SCORE, OBJPROP_COLOR, clrBlack);
   string alert_score_buttons[] =
   {
      UI_ALERT_OFF, UI_ALERT_50, UI_ALERT_60,
      UI_ALERT_70, UI_ALERT_80, UI_ALERT_90
   };
   int alert_score_values[] = {0, 50, 60, 70, 80, 90};
   for(int i = 0; i < ArraySize(alert_score_buttons); i++)
   {
      const int score = alert_score_values[i];
      const bool selected = (score == g_minimum_alert_score);
      UISetIntegerIfChanged(alert_score_buttons[i], OBJPROP_BGCOLOR,
                       selected ? C'220,155,35' :
                       (score==0 ? C'220,220,220' : C'250,225,160'));
      UISetIntegerIfChanged(alert_score_buttons[i], OBJPROP_COLOR,
                       selected ? clrWhite : clrBlack);
   }
   UISetIntegerIfChanged(UI_SYS_ALERT, OBJPROP_BGCOLOR,
                    g_terminal_alert ? C'75,145,210' : C'205,205,205');
   UISetIntegerIfChanged(UI_MOB_ALERT, OBJPROP_BGCOLOR,
                    g_mobile_alert ? C'130,100,205' : C'205,205,205');
   UISetIntegerIfChanged(UI_WATCH_ALERT, OBJPROP_BGCOLOR,
                    g_watch_mode==WATCH_MODE_CHART_ALERT ? C'235,165,70' : C'205,205,205');
   UISetIntegerIfChanged(UI_WATCH_ALERT, OBJPROP_COLOR,
                    g_watch_mode==WATCH_MODE_CHART_ALERT ? clrWhite : clrBlack);
   UISetIntegerIfChanged(UI_SYS_ALERT, OBJPROP_COLOR,
                    g_terminal_alert ? clrWhite : clrBlack);
   UISetIntegerIfChanged(UI_MOB_ALERT, OBJPROP_COLOR,
                    g_mobile_alert ? clrWhite : clrBlack);
   UISetMenuObjectsVisible(!g_ui_menu_hidden);
   UIRefreshHideButton();
}

void UISetMenuObjectsVisible(const bool visible)
{
   const long periods = visible ? OBJ_ALL_PERIODS : OBJ_NO_PERIODS;
   string names[] =
   {
      UI_TP_BAR, UI_SL_BAR, UI_ENTRY_BAR,
      UI_TP_TEXT, UI_SL_TEXT, UI_ENTRY_TEXT, UI_TP_LOCK, UI_SL_LOCK,
      UI_SIDE_UP, UI_SIDE_DOWN, UI_NOW, UI_LOCK, UI_RESET,
      UI_SIGNAL, UI_AUTO, UI_MODE_TEXT, UI_STRATEGY, UI_STATE_TF,
      UI_SIGDIR_TEXT, UI_SIGDIR_BOTH, UI_SIGDIR_LONG, UI_SIGDIR_SHORT,
      UI_DIR_TEXT, UI_DIR_BOTH, UI_DIR_LONG, UI_DIR_SHORT,
      UI_ADD_TEXT, UI_MAX_ADD_EDIT,
       UI_WATCH_ALERT, UI_ALERT_SCORE, UI_SYS_ALERT, UI_MOB_ALERT,
      UI_ALERT_OFF, UI_ALERT_50, UI_ALERT_60, UI_ALERT_70, UI_ALERT_80, UI_ALERT_90,
      UI_LOT_MINUS, UI_LOT_LABEL, UI_LOT_EDIT, UI_LOT_PLUS,
      UI_SL_PERCENT_LABEL, UI_SL_PERCENT_EDIT
   };
   for(int i = 0; i < ArraySize(names); i++)
      if(ObjectFind(0, names[i]) >= 0)
         UISetIntegerIfChanged(names[i], OBJPROP_TIMEFRAMES, periods);
}

void UIRefreshHideButton()
{
   if(ObjectFind(0, UI_HIDE_BUTTON) < 0)
      return;
   UISetIntegerIfChanged(UI_HIDE_BUTTON, OBJPROP_CORNER, CORNER_RIGHT_UPPER);
   UISetIntegerIfChanged(UI_HIDE_BUTTON, OBJPROP_XDISTANCE, 6);
   UISetIntegerIfChanged(UI_HIDE_BUTTON, OBJPROP_YDISTANCE, 6);
   UISetIntegerIfChanged(UI_HIDE_BUTTON, OBJPROP_XSIZE, 54);
   UISetIntegerIfChanged(UI_HIDE_BUTTON, OBJPROP_YSIZE, 20);
   UISetIntegerIfChanged(UI_HIDE_BUTTON, OBJPROP_TIMEFRAMES, OBJ_ALL_PERIODS);
   UISetIntegerIfChanged(UI_HIDE_BUTTON, OBJPROP_STATE, false);
   UISetStringIfChanged(UI_HIDE_BUTTON, OBJPROP_TEXT,
                   g_ui_menu_hidden ? "SHOW" : "HIDE");
   UISetIntegerIfChanged(UI_HIDE_BUTTON, OBJPROP_BGCOLOR,
                    g_ui_menu_hidden ? C'180,220,185' : C'220,220,220');
   UISetIntegerIfChanged(UI_HIDE_BUTTON, OBJPROP_COLOR, clrBlack);
}

void UICenterMenuVertically()
{
   const int chart_height =
      (int)ChartGetInteger(0, CHART_HEIGHT_IN_PIXELS, 0);
   if(chart_height <= 0)
      return;

   int current_entry_y = 0;
   if(!UIPriceToY(UIPrice(UI_ENTRY_LINE), current_entry_y))
      return;

   const int top_offset = UI_H / 2;
   const int bottom_offset = UIStatusBottomOffset();
   const int total_height = top_offset + bottom_offset;
   const int target_entry_y =
      MathMax(top_offset + UI_CHART_EDGE_MARGIN_PX,
              MathMin(chart_height - bottom_offset - UI_CHART_EDGE_MARGIN_PX,
                      (chart_height - total_height) / 2 + top_offset));
   UIShiftAllToEntryY(current_entry_y, target_entry_y);
}

void UICreate()
{
   UICacheReset();
   const int chart_width =
      (int)ChartGetInteger(0, CHART_WIDTH_IN_PIXELS, 0);
   const int width = MathMax(UI_MIN_WIDTH, InpMenuWidth);

   // v3.04: on a fresh attachment center the UI as before; after an MT5
   // chart-change reinitialization UIRestoreChartChangeState() has already
   // restored MAIN/TP/SL X values, so preserve them and only clamp on-screen.
   const bool restored_horizontal_position =
      GlobalVariableCheck(UIStateKey("RESTORED_X_ACTIVE"));
   if(!restored_horizontal_position)
   {
      g_ui_x = MathMax(0, (chart_width - width) / 2);
      const int initial_reference_x =
         MathMax(0, g_ui_x + width - UI_REFERENCE_WIDTH);
      g_ui_tp_x = initial_reference_x;
      g_ui_sl_x = initial_reference_x;
   }
   else
   {
      const int maximum_x = MathMax(0, chart_width - width - 30);
      g_ui_x = MathMax(0, MathMin(maximum_x, g_ui_x));
      const int ref_max = MathMax(0, chart_width - UI_REFERENCE_WIDTH - 3);
      g_ui_tp_x = MathMax(0, MathMin(ref_max, g_ui_tp_x));
      g_ui_sl_x = MathMax(0, MathMin(ref_max, g_ui_sl_x));
      GlobalVariableDel(UIStateKey("RESTORED_X_ACTIVE"));
   }
   UICreateHLine(UI_ENTRY_LINE, 0.0, clrGold);
   UICreateHLine(UI_TP_LINE, 0.0, C'61,178,95');
   UICreateHLine(UI_SL_LINE, 0.0, C'232,92,92');
   UICreateRect(UI_TP_BAR, C'190,255,198', C'90,170,100');
   UICreateRect(UI_SL_BAR, C'255,175,175', C'195,100,100');
   UICreateRect(UI_ENTRY_BAR, C'245,205,125', C'180,130,65');
   UICreateLabel(UI_TP_TEXT);
   UICreateLabel(UI_SL_TEXT);
   // Center TP/SL captions both horizontally and vertically inside the
   // usable box area (the right side is reserved for the FREE/LOCK button).
   ObjectSetInteger(0, UI_TP_TEXT, OBJPROP_ANCHOR, ANCHOR_CENTER);
   ObjectSetInteger(0, UI_SL_TEXT, OBJPROP_ANCHOR, ANCHOR_CENTER);
   UICreateLabel(UI_ENTRY_TEXT);
   UICreateButton(UI_TP_LOCK, "FREE", C'215,235,218', 44);
   UICreateButton(UI_SL_LOCK, "FREE", C'245,215,215', 44);
   UICreateButton(UI_HIDE_BUTTON, "HIDE", C'220,220,220', 54);
   ObjectSetInteger(0, UI_HIDE_BUTTON, OBJPROP_CORNER, CORNER_RIGHT_UPPER);
   UICreateButton(UI_SIDE_UP, "▲", C'190,225,190', 24);
   UICreateButton(UI_SIDE_DOWN, "▼", C'240,190,190', 24);
   UICreateButton(UI_NOW, "now", C'235,205,135', 45);
   UICreateButton(UI_SIGNAL, "SIGNAL ON", C'70,180,100', 78);
   UICreateButton(UI_AUTO, "AUTO OFF", C'205,205,205', 78);
   UICreateLabel(UI_MODE_TEXT);
   UICreateButton(UI_STATE_TF, "TRADE TF: M3", C'185,215,235', 212);
   UICreateButton(UI_SIGDIR_TEXT, "SIGNAL: BOTH", C'220,230,245', 160);
   UICreateButton(UI_SIGDIR_BOTH, "BOTH", C'90,145,205', 68);
   UICreateButton(UI_SIGDIR_LONG, "LONG", C'90,190,115', 68);
   UICreateButton(UI_SIGDIR_SHORT, "SHORT", C'235,110,110', 68);
   UICreateButton(UI_DIR_TEXT, "AUTO: BOTH", C'220,240,220', 160);
   UICreateButton(UI_DIR_BOTH, "BOTH", C'90,145,205', 68);
   UICreateButton(UI_DIR_LONG, "LONG", C'90,190,115', 68);
   UICreateButton(UI_DIR_SHORT, "SHORT", C'235,110,110', 68);
   UICreateButton(UI_ADD_TEXT, "MAX ADD: 0/0", C'245,225,185', 120);
   ObjectCreate(0, UI_MAX_ADD_EDIT, OBJ_EDIT, 0, 0, 0);
   ObjectSetInteger(0, UI_MAX_ADD_EDIT, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, UI_MAX_ADD_EDIT, OBJPROP_ALIGN, ALIGN_CENTER);
   ObjectSetInteger(0, UI_MAX_ADD_EDIT, OBJPROP_BGCOLOR, clrWhite);
   ObjectSetInteger(0, UI_MAX_ADD_EDIT, OBJPROP_COLOR, clrBlack);
   ObjectSetInteger(0, UI_MAX_ADD_EDIT, OBJPROP_BORDER_COLOR, C'75,75,75');
   ObjectSetInteger(0, UI_MAX_ADD_EDIT, OBJPROP_FONTSIZE, 9);
   ObjectSetString(0, UI_MAX_ADD_EDIT, OBJPROP_FONT, "Arial Bold");
   ObjectSetInteger(0, UI_MAX_ADD_EDIT, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, UI_MAX_ADD_EDIT, OBJPROP_HIDDEN, true);
   UICreateButton(UI_WATCH_ALERT, "WATCH ON", C'235,165,70', 58);
   UICreateButton(UI_ALERT_SCORE, "ALERT OFF", C'205,205,205', 52);
   UICreateButton(UI_ALERT_OFF, "OFF", C'220,220,220', 60);
   UICreateButton(UI_ALERT_50, "50+", C'250,225,160', 60);
   UICreateButton(UI_ALERT_60, "60+", C'250,225,160', 60);
   UICreateButton(UI_ALERT_70, "70+", C'250,225,160', 60);
   UICreateButton(UI_ALERT_80, "80+", C'250,225,160', 60);
   UICreateButton(UI_ALERT_90, "90+", C'250,225,160', 60);
   UICreateButton(UI_SYS_ALERT, "SYS ON", C'75,145,210', 48);
   UICreateButton(UI_MOB_ALERT, "MOB OFF", C'205,205,205', 48);

   // Bottom alert/control row uses WATCH/SYS/MOB. Keep captions
   // compact so all four controls remain visible.
   // text stays fully visible inside each box at the minimum menu width.
   ObjectSetInteger(0, UI_WATCH_ALERT, OBJPROP_FONTSIZE, 7);
   ObjectSetInteger(0, UI_ALERT_SCORE, OBJPROP_FONTSIZE, 7);
   ObjectSetInteger(0, UI_SYS_ALERT, OBJPROP_FONTSIZE, 7);
   ObjectSetInteger(0, UI_MOB_ALERT, OBJPROP_FONTSIZE, 7);

   UICreateButton(UI_LOT_LABEL, "LOT", C'215,220,225', 32);
   UICreateButton(UI_SL_PERCENT_LABEL, "SL %", C'215,220,225', 32);
   ObjectSetInteger(0, UI_TP_TEXT, OBJPROP_FONTSIZE, 8);
   ObjectSetInteger(0, UI_SL_TEXT, OBJPROP_FONTSIZE, 8);
   ObjectSetInteger(0, UI_ENTRY_TEXT, OBJPROP_FONTSIZE, 9);
   ObjectCreate(0, UI_LOT_EDIT, OBJ_EDIT, 0, 0, 0);
   ObjectSetInteger(0, UI_LOT_EDIT, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, UI_LOT_EDIT, OBJPROP_ALIGN, ALIGN_CENTER);
   ObjectSetInteger(0, UI_LOT_EDIT, OBJPROP_BGCOLOR, clrWhite);
   ObjectSetInteger(0, UI_LOT_EDIT, OBJPROP_COLOR, clrBlack);
   ObjectSetInteger(0, UI_LOT_EDIT, OBJPROP_BORDER_COLOR, C'75,75,75');
   ObjectSetInteger(0, UI_LOT_EDIT, OBJPROP_FONTSIZE, 9);
   ObjectSetString(0, UI_LOT_EDIT, OBJPROP_FONT, "Arial Bold");
   ObjectSetInteger(0, UI_LOT_EDIT, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, UI_LOT_EDIT, OBJPROP_HIDDEN, true);
   ObjectCreate(0, UI_SL_PERCENT_EDIT, OBJ_EDIT, 0, 0, 0);
   ObjectSetInteger(0, UI_SL_PERCENT_EDIT, OBJPROP_CORNER,
                    CORNER_LEFT_UPPER);
   ObjectSetInteger(0, UI_SL_PERCENT_EDIT, OBJPROP_ALIGN, ALIGN_CENTER);
   ObjectSetInteger(0, UI_SL_PERCENT_EDIT, OBJPROP_BGCOLOR, clrWhite);
   ObjectSetInteger(0, UI_SL_PERCENT_EDIT, OBJPROP_COLOR, clrBlack);
   ObjectSetInteger(0, UI_SL_PERCENT_EDIT, OBJPROP_BORDER_COLOR,
                    C'75,75,75');
   ObjectSetInteger(0, UI_SL_PERCENT_EDIT, OBJPROP_FONTSIZE, 9);
   ObjectSetString(0, UI_SL_PERCENT_EDIT, OBJPROP_FONT, "Arial Bold");
   ObjectSetInteger(0, UI_SL_PERCENT_EDIT, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, UI_SL_PERCENT_EDIT, OBJPROP_HIDDEN, true);
   UIResetPrices();
   JRO_FlushChartRedraw(0);
   UICenterMenuVertically();
   JRO_RequestChartRedraw();
   if(g_ui_restore_locked_offsets)
   {
      UIApplyLockedOffsets();
      g_ui_restore_locked_offsets = false;
   }
   UISetMenuObjectsVisible(!g_ui_menu_hidden);
   UIRefreshHideButton();
   UIRefresh();
}

void UIDelete()
{
   UICacheReset();
   string names[] =
   {
      UI_ENTRY_LINE, UI_TP_LINE, UI_SL_LINE, UI_TP_BAR, UI_SL_BAR,
      UI_ENTRY_BAR, UI_TP_TEXT, UI_SL_TEXT, UI_ENTRY_TEXT,
      UI_TP_LOCK, UI_SL_LOCK,
      UI_SIDE_UP, UI_SIDE_DOWN, UI_NOW, UI_LOCK, UI_RESET,
      UI_SIGNAL, UI_AUTO, UI_MODE_TEXT, UI_STRATEGY, UI_STATE_TF,
      UI_SIGDIR_TEXT, UI_SIGDIR_BOTH, UI_SIGDIR_LONG, UI_SIGDIR_SHORT,
      UI_DIR_TEXT, UI_DIR_BOTH, UI_DIR_LONG, UI_DIR_SHORT,
      UI_ADD_TEXT, UI_MAX_ADD_EDIT,
       UI_WATCH_ALERT, UI_ALERT_SCORE, UI_SYS_ALERT, UI_MOB_ALERT,
      UI_ALERT_OFF, UI_ALERT_50, UI_ALERT_60, UI_ALERT_70, UI_ALERT_80, UI_ALERT_90,
      UI_LOT_MINUS, UI_LOT_LABEL, UI_LOT_EDIT, UI_LOT_PLUS,
      UI_SL_PERCENT_LABEL, UI_SL_PERCENT_EDIT,
      UI_HIDE_BUTTON
   };
   for(int i = 0; i < ArraySize(names); i++)
      ObjectDelete(0, names[i]);
}

void UIRelease(const string name)
{
   ObjectSetInteger(0, name, OBJPROP_STATE, false);
}

string UICompactNumber(const double value, const int decimals)
{
   string text = DoubleToString(value, decimals);
   while(StringFind(text, ".") >= 0 &&
         StringLen(text) > 0 &&
         StringSubstr(text, StringLen(text) - 1, 1) == "0")
      text = StringSubstr(text, 0, StringLen(text) - 1);
   if(StringLen(text) > 0 &&
      StringSubstr(text, StringLen(text) - 1, 1) == ".")
      text = StringSubstr(text, 0, StringLen(text) - 1);
   return text;
}

double UIParseBracketValue(string text)
{
   StringReplace(text, "LOT", "");
   StringReplace(text, "SL", "");
   StringReplace(text, "%", "");
   StringReplace(text, "[", "");
   StringReplace(text, "]", "");
   StringReplace(text, " ", "");
   return StringToDouble(text);
}

void UIChangeLots(const int direction)
{
   double step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   if(step <= 0.0) step = 0.01;
   g_ui_lots = NormalizeVolume(g_ui_lots + direction * step);
}

ENUM_TIMEFRAMES UISupportedTF(const int index)
{
   ENUM_TIMEFRAMES values[] =
   {
      PERIOD_M1, PERIOD_M2, PERIOD_M3, PERIOD_M4, PERIOD_M5,
      PERIOD_M6, PERIOD_M10, PERIOD_M12, PERIOD_M15
   };
   const int safe_index = MathMax(0, MathMin(ArraySize(values) - 1, index));
   return values[safe_index];
}

string UITFName(const ENUM_TIMEFRAMES timeframe)
{
   switch(timeframe)
   {
      case PERIOD_M1:  return "M1";
      case PERIOD_M2:  return "M2";
      case PERIOD_M3:  return "M3";
      case PERIOD_M4:  return "M4";
      case PERIOD_M5:  return "M5";
      case PERIOD_M6:  return "M6";
      case PERIOD_M10: return "M10";
      case PERIOD_M12: return "M12";
      case PERIOD_M15: return "M15";
   }
   return EnumToString(timeframe);
}

int UITFIndex(const ENUM_TIMEFRAMES timeframe)
{
   for(int i = 0; i < 9; i++)
      if(UISupportedTF(i) == timeframe)
         return i;
   return 1; // Default M2
}

void UINow()
{
   if(g_ui_locked) return;
   MqlTick tick;
   if(!SymbolInfoTick(_Symbol, tick)) return;
   const double old_entry = UIPrice(UI_ENTRY_LINE);
   const double current = NormalizePrice(g_ui_buy ? tick.ask : tick.bid);
   const double delta = current - old_entry;
   ObjectSetDouble(0, UI_ENTRY_LINE, OBJPROP_PRICE, current);
   ObjectSetDouble(0, UI_TP_LINE, OBJPROP_PRICE,
                   NormalizePrice(UIPrice(UI_TP_LINE) + delta));
   ObjectSetDouble(0, UI_SL_LINE, OBJPROP_PRICE,
                   NormalizePrice(UIPrice(UI_SL_LINE) + delta));
}

void UIResetRuntimeForStrategyChange()
{
   // Strategy change is allowed only while flat. Reuse the same completed-
   // position cleanup authorities so no old mode state can leak into the new
   // mode. AUTO intent itself is intentionally preserved.
   FinalizeCompletedPositionClose(false);
   ResetAutoSignalCounters();
   ResetRangeDirectionalPersistence("STRATEGY CHANGED");
   WatchSignalResetState();
   ResetPreAutoFinalHistory("STRATEGY CHANGED");
   ReentryContextReset("STRATEGY_CHANGED");
   TradeCycleClear("STRATEGY_CHANGED");

   g_long_regime_traded=false;
   g_short_regime_traded=false;
   g_long_exit_pending=false;
   g_short_exit_pending=false;
   g_exit_opposite_close_bars=0;

   g_additional_entry_count=0;
   g_add_same_direction_signal_count=0;
   g_add_break_confirm_bar=0;
   g_add_last_counted_signal_bar=0;
   g_add_first_signal_bar=0;
   g_add_first_signal_event_id="";
   g_add_second_signal_event_id="";
   g_add_last_consumed_pair_key="";
   g_last_add_attempt_bar=0;

   g_initial_opposite_confirm_count=0;
   g_initial_opposite_last_bar=0;
   g_initial_opposite_first_bar=0;
   g_initial_opposite_first_event_id="";
   g_initial_opposite_second_event_id="";

   g_entry_breakout_active=false;
   g_entry_breakout_side=0;
   g_entry_breakout_reference=0.0;
   g_entry_breakout_confirm_bar_time=0;
   g_entry_breakout_confirm_close=0.0;

   // v2.96: order-in-progress latches are execution authority and are not
   // reset by UI strategy changes. The click handler blocks mode changes while
   // either latch is active.
   g_pending_exit_reason="";
   g_pending_exit_reason_time=0;
   g_entry_safety_block_reason="";

   // The new mode starts a genuinely new INITIAL cycle. A previous mode's
   // same-bar order guard and post-exit cooldown must not be inherited.
   g_last_initial_order_bar=0;
   g_last_initial_order_side=0;
   g_last_exit_bar_time=0;
   g_exit_cooldown_bars=0;

   g_signal_position_side=0;
   g_signal_entry_price=0.0;
   g_last_position_state_alert="";

   HoldEngineResetState();
   RiskEngineResetProfitProtectionState();

   // Rebuild AUTO START BIAS from the current market for the newly selected
   // mode while keeping AUTO ON/OFF exactly as the operator set it.
   ReleaseAutoStartBias("STRATEGY CHANGED");
   g_auto_start_bias=AUTO_BIAS_NEUTRAL;
   g_auto_start_bias_active=false;
   g_auto_start_bias_bars_seen=0;
   g_auto_start_bias_last_bar=0;
   g_pre_direction_long_count=0;
   g_pre_direction_short_count=0;
   g_pre_direction_release_last_bar=0;
   g_pre_direction_release_score=0;
   g_pre_direction_release_condition="STRATEGY_CHANGED";
   g_pre_direction_release_block_reason="NONE";
   g_pre_direction_bias_released=false;
   g_pre_direction_last_bias="NEUTRAL";

   if(g_auto_trading)
      InitializeAutoStartBias();
}

void UIHandleClick(const string name)
{
   UIRelease(name);
   if(name == UI_HIDE_BUTTON)
   {
      g_ui_menu_hidden = !g_ui_menu_hidden;
      g_ui_direction_dropdown = false;
      g_ui_signal_direction_dropdown = false;
      g_ui_additional_dropdown = false;
      g_ui_alert_score_dropdown = false;
      g_status = g_ui_menu_hidden ? "MENU HIDDEN" : "MENU SHOWN";
      UISetMenuObjectsVisible(!g_ui_menu_hidden);
      UIRefreshHideButton();
      JRO_RequestChartRedraw();
      return;
   }
   if(name == UI_TP_LOCK)
   {
      g_ui_tp_locked = !g_ui_tp_locked;
      if(g_ui_tp_locked)
      {
         UICaptureLockOffset(true);
         g_status = "TP LINE LOCKED TO MAIN MENU RANGE";
      }
      else
         g_status = "TP LINE FREE";
   }
   else if(name == UI_SL_LOCK)
   {
      g_ui_sl_locked = !g_ui_sl_locked;
      if(g_ui_sl_locked)
      {
         UICaptureLockOffset(false);
         g_status = "SL LINE LOCKED TO MAIN MENU RANGE";
      }
      else
         g_status = "SL LINE FREE";
   }
   else if(name == UI_SIDE_UP)
   {
      g_ui_buy = true;
      UIArrangeSide();
   }
   else if(name == UI_SIDE_DOWN)
   {
      g_ui_buy = false;
      UIArrangeSide();
   }
   else if(name == UI_NOW) UINow();
   else if(name == UI_STATE_TF)
   {
      const ENUM_TIMEFRAMES current_tf=AUTO_TF;
      ENUM_TIMEFRAMES next_tf=PERIOD_M3;
      if(current_tf==PERIOD_M1)       next_tf=PERIOD_M2;
      else if(current_tf==PERIOD_M2)  next_tf=PERIOD_M3;
      else if(current_tf==PERIOD_M3)  next_tf=PERIOD_M5;
      else if(current_tf==PERIOD_M5)  next_tf=PERIOD_M15;
      else                            next_tf=PERIOD_M1;

      // Never change structural timeframe during a live managed position.
      if(ManagedPositionSide()!=0)
      {
         g_status="TRADE TF CHANGE BLOCKED: POSITION OPEN";
      }
      else
      {
         // Keep each timeframe's diagnostic stream in a separate CSV file.
         CloseAssistStateCsv();
         if(StateEvaluationSetTimeframe(next_tf))
         {
            UIRenderAssistState();
            WriteAssistStateCsv();
            g_status="TRADE TF: "+UITFName(next_tf);
         }
         else
         {
            // Reopen the unchanged stream if handle creation failed.
            WriteAssistStateCsv();
            g_status="TRADE TF CHANGE FAILED";
         }
      }
   }
   else if(name == UI_SIGNAL)
   {
      g_signal_enabled = !g_signal_enabled;
      if(!g_signal_enabled)
      {
         g_signal_position_side = 0;
         g_signal_entry_price = 0.0;
         ResetAutoSignalCounters();
         ResetRangeDirectionalPersistence("SIGNAL OFF");
         WatchSignalResetState();
         ResetPreAutoFinalHistory("SIGNAL OFF");
         g_status = "SIGNAL OFF";
      }
      else
         g_status = "SIGNAL ON";
   }
   else if(name == UI_AUTO)
   {
      const bool was_auto=g_auto_trading; g_auto_trading=!g_auto_trading;
      // Only the operator's AUTO button controls the persistent AUTO intent.
      // Entry fills, SL handling and position synchronization must never clear it.
      UISetAutoSessionLatch(g_auto_trading);
      g_signal_position_side=0; g_signal_entry_price=0.0;
      ResetAutoSignalCounters();
      if(!was_auto && g_auto_trading)
      {
         // v4.08: visual-only AUTO ON marker. Keep exactly one latest marker.
         // Anchor the line to the current chart's active bar so it visually
         // aligns with the price bar that was current when AUTO was enabled.
         // This marker does not participate in AUTO Start Bias, signals,
         // entry, CSV timing or risk logic.
         datetime auto_marker_time=iTime(_Symbol,_Period,0);
         if(auto_marker_time<=0)
         {
            MqlTick auto_marker_tick;
            if(SymbolInfoTick(_Symbol,auto_marker_tick) && auto_marker_tick.time>0)
               auto_marker_time=auto_marker_tick.time;
            else
               auto_marker_time=TimeCurrent();
         }
         JTF_CreateVerticalMarker(ChartID(),"JTA_AUTO_ON_MARKER",auto_marker_time,
                                  clrGreen,STYLE_SOLID,1,"AUTO ON",false);
         InitializeAutoStartBias();
      }
      else if(was_auto && !g_auto_trading)
      {
         // Operator AUTO OFF is an explicit cancellation of all pending
         // automatic-entry intent. Pending RANGE entry context is reset below.
         ReleaseAutoStartBias("AUTO OFF");
         g_auto_start_bias = AUTO_BIAS_NEUTRAL;
         ResetPreAutoFinalHistory("AUTO OFF - NEW OBSERVATION WINDOW");
      }
      string auto_permission_reason="";
      if(g_auto_trading && !JTATradePermissionAllowed(auto_permission_reason))
         g_status="AUTO ON - "+auto_permission_reason;
      else
         g_status=g_auto_trading?"AUTO TRADING":"AUTO OFF";
   }
   else if(name == UI_DIR_TEXT)
   {
      g_ui_direction_dropdown = !g_ui_direction_dropdown;
      g_ui_signal_direction_dropdown = false;
      g_ui_additional_dropdown = false;
      g_ui_alert_score_dropdown = false;
   }
   else if(name == UI_DIR_BOTH ||
           name == UI_DIR_LONG || name == UI_DIR_SHORT)
   {
      if(name == UI_DIR_BOTH)
         g_trade_direction = TRADE_BOTH;
      else
         g_trade_direction =
            name == UI_DIR_LONG ? TRADE_LONG_ONLY : TRADE_SHORT_ONLY;
      g_ui_direction_dropdown = false;
      g_status = "AUTO DIRECTION " + AutoDirectionName();
   }
   else if(name == UI_SIGDIR_TEXT)
   {
      g_ui_signal_direction_dropdown =
         !g_ui_signal_direction_dropdown;
      g_ui_direction_dropdown = false;
      g_ui_additional_dropdown = false;
      g_ui_alert_score_dropdown = false;
   }
   else if(name == UI_SIGDIR_BOTH ||
           name == UI_SIGDIR_LONG ||
           name == UI_SIGDIR_SHORT)
   {
      ENUM_SIGNAL_DIRECTION new_direction = SIGNAL_BOTH;
      if(name == UI_SIGDIR_LONG)
         new_direction = SIGNAL_LONG_ONLY;
      else if(name == UI_SIGDIR_SHORT)
         new_direction = SIGNAL_SHORT_ONLY;
      ApplySignalDirection(new_direction);
      g_ui_signal_direction_dropdown = false;
   }
   else if(name == UI_ADD_TEXT)
   {
      g_status = "EDIT MAX ADD COUNT DIRECTLY";
   }
   else if(name == UI_WATCH_ALERT)
   {
      // Toggle WATCH notification only. WATCH chart display remains enabled.
      g_watch_mode = (g_watch_mode==WATCH_MODE_CHART_ALERT) ?
                     WATCH_MODE_CHART : WATCH_MODE_CHART_ALERT;
      g_status = g_watch_mode==WATCH_MODE_CHART_ALERT ?
                 "WATCH ALERT ON" : "WATCH ALERT OFF";
   }
   else if(name == UI_SYS_ALERT)
   {
      g_terminal_alert = !g_terminal_alert;
      g_status = g_terminal_alert ?
                 "SYSTEM ALERT ON" : "SYSTEM ALERT OFF";
   }
   else if(name == UI_ALERT_SCORE)
   {
      g_ui_alert_score_dropdown = !g_ui_alert_score_dropdown;
      g_ui_signal_direction_dropdown = false;
      g_ui_direction_dropdown = false;
      g_ui_additional_dropdown = false;
      g_status = "SELECT SCORE ALERT: OFF / 50+ / 60+ / 70+ / 80+ / 90+";
   }
   else if(name == UI_ALERT_OFF || name == UI_ALERT_50 ||
           name == UI_ALERT_60 || name == UI_ALERT_70 ||
           name == UI_ALERT_80 || name == UI_ALERT_90)
   {
      if(name == UI_ALERT_OFF)
         g_minimum_alert_score = 0;
      else
      {
         string score_text = name;
         StringReplace(score_text, "JMD_UI_ALERT_", "");
         g_minimum_alert_score = (int)StringToInteger(score_text);
      }
      g_ui_alert_score_dropdown = false;
      g_status = g_minimum_alert_score<=0 ?
                 "SIGNAL ALERTS: WATCH" :
                 "MINIMUM ALERT SCORE " +
                 IntegerToString(g_minimum_alert_score) +
                 " - SYSTEM/MOBILE APPLIED";
   }
   else if(name == UI_MOB_ALERT)
   {
      g_mobile_alert = !g_mobile_alert;
      g_status = g_mobile_alert ?
                 "MOBILE ALERT ON" : "MOBILE ALERT OFF";
      // Send an immediate confirmation so the operator can verify the
      // terminal MetaQuotes ID configuration before waiting for a trade.
      if(g_mobile_alert)
         NotifyUser(_Symbol +
                    " MOBILE PUSH ON - SIGNAL/ENTRY/ADD/EXIT/SL/TP ENABLED");
   }
   UISyncRuntimeProperties("MENU CLICK: " + name);
   UIRefresh();
}

void UIStartDrag(const int x, const int y)
{
   if(g_ui_locked) return;
   int entry_y = 0, tp_y = 0, sl_y = 0;
   if(!UIPriceToY(UIPrice(UI_ENTRY_LINE), entry_y) ||
      !UIPriceToY(UIPrice(UI_TP_LINE), tp_y) ||
      !UIPriceToY(UIPrice(UI_SL_LINE), sl_y))
      return;
   const int tp_bar_y =
      (int)ObjectGetInteger(0, UI_TP_BAR, OBJPROP_YDISTANCE);
   const int sl_bar_y =
      (int)ObjectGetInteger(0, UI_SL_BAR, OBJPROP_YDISTANCE);
   const int entry_bar_y =
      (int)ObjectGetInteger(0, UI_ENTRY_BAR, OBJPROP_YDISTANCE);
   const bool on_tp_box =
      (x >= g_ui_tp_x && x <= g_ui_tp_x + g_ui_tp_width &&
       y >= tp_bar_y && y <= tp_bar_y + UI_H);
   const bool on_sl_box =
      (x >= g_ui_sl_x && x <= g_ui_sl_x + g_ui_sl_width &&
       y >= sl_bar_y && y <= sl_bar_y + UI_H);
   const bool on_main_header =
      (x >= g_ui_x &&
       x <= g_ui_x + MathMax(UI_MIN_WIDTH, InpMenuWidth) &&
       y >= entry_bar_y && y <= entry_bar_y + UI_H);
   const int lock_width = 42;
   const bool on_tp_lock =
      (x >= g_ui_tp_x + g_ui_tp_width - lock_width &&
       x <= g_ui_tp_x + g_ui_tp_width &&
       y >= tp_bar_y && y <= tp_bar_y + UI_H);
   const bool on_sl_lock =
      (x >= g_ui_sl_x + g_ui_sl_width - lock_width &&
       x <= g_ui_sl_x + g_ui_sl_width &&
       y >= sl_bar_y && y <= sl_bar_y + UI_H);
   if(on_tp_lock || on_sl_lock)
      return;
   if(on_tp_box && !g_ui_tp_locked)
      g_ui_drag_target = 2;
   else if(on_sl_box && !g_ui_sl_locked)
      g_ui_drag_target = 3;
   else if(on_main_header)
      g_ui_drag_target = 1;
   else return;
   g_ui_dragging = true;
   g_ui_drag_x = x;
   g_ui_drag_y = y;
   g_ui_drag_panel_x =
      (g_ui_drag_target == 1 ? g_ui_x :
       g_ui_drag_target == 2 ? g_ui_tp_x : g_ui_sl_x);
   g_ui_drag_entry = UIPrice(UI_ENTRY_LINE);
   g_ui_drag_tp = UIPrice(UI_TP_LINE);
   g_ui_drag_sl = UIPrice(UI_SL_LINE);
   g_ui_last_drag_refresh_msc = 0;
   ChartSetInteger(0, CHART_MOUSE_SCROLL, false);
}

void UIUpdateDrag(const int x, const int y)
{
   if(!g_ui_dragging) return;

   // Use only the movement since the previous mouse event.  This keeps
   // price movement stable if chart auto-scale changes during a drag.
   int move_y = y - g_ui_drag_y;
   move_y = MathMax(-UI_MAX_DRAG_EVENT_PX,
                    MathMin(UI_MAX_DRAG_EVENT_PX, move_y));

   int subwindow = 0;
   datetime time = 0;
   double price1 = 0.0, price2 = 0.0;
   if(!ChartXYToTimePrice(0, x, g_ui_drag_y, subwindow, time, price1) ||
      !ChartXYToTimePrice(0, x, g_ui_drag_y + move_y,
                         subwindow, time, price2))
      return;
   const double delta = price2 - price1;
   if(g_ui_drag_target == 1)
   {
      const long chart_width =
         ChartGetInteger(0, CHART_WIDTH_IN_PIXELS, 0);
      const int menu_width = MathMax(UI_MIN_WIDTH, InpMenuWidth) + 27;
      const int maximum_x =
         MathMax(0, (int)chart_width - menu_width - 3);
      g_ui_x = MathMax(0, MathMin(maximum_x,
                        g_ui_drag_panel_x + x - g_ui_drag_x));

      g_ui_drag_entry = NormalizePrice(g_ui_drag_entry + delta);
      ObjectSetDouble(0, UI_ENTRY_LINE, OBJPROP_PRICE,
                      g_ui_drag_entry);
      // A locked reference line keeps its exact screen-space range from the
      // main ENTRY panel and follows only main-panel dragging.
      if(g_ui_tp_locked)
      {
         g_ui_drag_tp = NormalizePrice(g_ui_drag_tp + delta);
         ObjectSetDouble(0, UI_TP_LINE, OBJPROP_PRICE, g_ui_drag_tp);
      }
      if(g_ui_sl_locked)
      {
         g_ui_drag_sl = NormalizePrice(g_ui_drag_sl + delta);
         ObjectSetDouble(0, UI_SL_LINE, OBJPROP_PRICE, g_ui_drag_sl);
      }
      UIApplyLockedOffsets();
   }
   else if(g_ui_drag_target == 2)
   {
      const int chart_width =
         (int)ChartGetInteger(0, CHART_WIDTH_IN_PIXELS, 0);
      const int maximum_x =
         MathMax(0, chart_width - UI_REFERENCE_WIDTH - 3);
      g_ui_tp_x = MathMax(0, MathMin(maximum_x,
                           g_ui_drag_panel_x + x - g_ui_drag_x));
      g_ui_drag_tp = NormalizePrice(g_ui_drag_tp + delta);
      ObjectSetDouble(0, UI_TP_LINE, OBJPROP_PRICE,
                      g_ui_drag_tp);
   }
   else if(g_ui_drag_target == 3)
   {
      const int chart_width =
         (int)ChartGetInteger(0, CHART_WIDTH_IN_PIXELS, 0);
      const int maximum_x =
         MathMax(0, chart_width - UI_REFERENCE_WIDTH - 3);
      g_ui_sl_x = MathMax(0, MathMin(maximum_x,
                           g_ui_drag_panel_x + x - g_ui_drag_x));
      g_ui_drag_sl = NormalizePrice(g_ui_drag_sl + delta);
      ObjectSetDouble(0, UI_SL_LINE, OBJPROP_PRICE,
                      g_ui_drag_sl);
   }

   g_ui_drag_y = y;

   // CHARTEVENT_MOUSE_MOVE can arrive hundreds of times per second.
   // UIRefresh() updates the entire panel, so cap it at roughly 25 FPS.
   // Price lines are still updated above on every mouse event.
   const long now_msc = (long)GetTickCount64();
   if(g_ui_last_drag_refresh_msc == 0 ||
      now_msc - g_ui_last_drag_refresh_msc >= UI_DRAG_REFRESH_INTERVAL_MSC)
   {
      UIRefresh();
      JRO_FlushChartRedraw(0);
      g_ui_last_drag_refresh_msc = now_msc;
   }
}

void UIEndDrag()
{
   const int completed_target = g_ui_drag_target;
   const bool main_moved_locked_sl =
      completed_target == 1 && g_ui_sl_locked;
   const bool main_moved_locked_tp =
      completed_target == 1 && g_ui_tp_locked;
   const bool sl_line_was_moved =
      completed_target == 3 || main_moved_locked_sl;
   const bool tp_line_was_moved =
      completed_target == 2 || main_moved_locked_tp;

   g_ui_dragging = false;
   g_ui_drag_target = 0;
   g_ui_last_drag_refresh_msc = 0;
   ChartSetInteger(0, CHART_MOUSE_SCROLL, true);

   // Chart lines are visual objects until a broker modification is sent.
   // Commit both manually moved protection lines when the drag ends.
   if(sl_line_was_moved)
      ApplyManualSLLineToManagedPositions(UIPrice(UI_SL_LINE));
   if(tp_line_was_moved)
      ApplyManualTPLineToManagedPositions(UIPrice(UI_TP_LINE));

   UIRefresh();
}

void DrawAutoTradeArrow(const int side,
                        const string state,
                        const int score,
                        const string pattern,
                        const double trade_price)
{
   const datetime signal_time = iTime(_Symbol, g_calc_tf, 1);
   if(signal_time <= 0)
      return;
   const string name =
      "JTA_AUTO_" + state + "_" + (side > 0 ? "LONG_" : "SHORT_") +
      IntegerToString((long)signal_time);
   const string tooltip = StringFormat(
      "%s\nPrice: %.*f\nScore: %d",
      side > 0 ? "LONG" : "SHORT", _Digits, trade_price, score);
   if(ObjectFind(0, name) >= 0)
   {
      ObjectSetString(0, name, OBJPROP_TOOLTIP, tooltip);
      const double existing_price = ObjectGetDouble(0, name, OBJPROP_PRICE, 0);
      DrawSignalScoreLabel(name, side, signal_time, existing_price, score, true);
      return;
   }

   const double high = iHigh(_Symbol, g_calc_tf, 1);
   const double low = iLow(_Symbol, g_calc_tf, 1);
   const double range = MathMax(high - low, 10.0 * _Point);
   const double price = NormalizePrice(side > 0 ?
      low - range * (state == "ENTRY" ? 0.38 : 0.22) :
      high + range * (state == "ENTRY" ? 0.38 : 0.22));
   if(!ObjectCreate(0, name, OBJ_ARROW, 0, signal_time, price))
      return;

   ObjectSetInteger(0, name, OBJPROP_ARROWCODE,
                    state == "ENTRY" ? (side > 0 ? 241 : 242) :
                                       (side > 0 ? 233 : 234));
   ObjectSetInteger(0, name, OBJPROP_COLOR,
                    state == "ENTRY" ? C'30,90,220' : C'235,150,20');
   ObjectSetInteger(0, name, OBJPROP_WIDTH, state == "ENTRY" ? 2 : 1);
   ObjectSetInteger(0, name, OBJPROP_ANCHOR,
                    side > 0 ? ANCHOR_BOTTOM : ANCHOR_TOP);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, false);
   ObjectSetString(0, name, OBJPROP_TOOLTIP, tooltip);
   DrawSignalScoreLabel(name, side, signal_time, price, score, true);
}


// ===== Functions moved from Common.mqh during ownership audit =====
void DeleteJTAObjects(){
   JTF_DeleteObjectsByPrefix(0,JTA_OBJECT_PREFIX,-1,-1,true);
}

//+------------------------------------------------------------------+
//| v7.11 Manual-assist state UI                                    |
//| One compact panel; chart markers only on meaningful transitions.|
//+------------------------------------------------------------------+
string UIAssistStateActionText(const ENUM_JTA_ASSIST_STATE state)
{
   switch(state)
   {
      case JTA_ASSIST_UP:                  return "상승 진행";
      case JTA_ASSIST_UP_WEAKENING:        return "상승 약화 · 신규 롱 주의";
      case JTA_ASSIST_REVERSAL_WATCH_DOWN: return "하락반전 주의 · 숏 준비";
      case JTA_ASSIST_DOWN:                return "하락 진행";
      case JTA_ASSIST_DOWN_WEAKENING:      return "하락 약화 · 신규 숏 주의";
      case JTA_ASSIST_REVERSAL_WATCH_UP:   return "상승반전 주의 · 롱 준비";
      default:                             return "방향 대기";
   }
}

string UIAssistStateDisplayName(const ENUM_JTA_ASSIST_STATE state)
{
   switch(state)
   {
      case JTA_ASSIST_REVERSAL_WATCH_DOWN: return "SHORT WATCH";
      case JTA_ASSIST_REVERSAL_WATCH_UP:   return "LONG WATCH";
      default:                             return AssistStateName(state);
   }
}

void UIRenderAssistState()
{
   // v8.34: StateEvaluation execution and notification ownership are independent
   // from chart visibility. InpAssistStateShowChart controls only panel/objects.
   if(!InpAssistStateEnabled || g_assist_state.bar_time<=0)
      return;

   const bool current_watch_up=
      g_assist_state.state==JTA_ASSIST_REVERSAL_WATCH_UP;
   const bool current_watch_down=
      g_assist_state.state==JTA_ASSIST_REVERSAL_WATCH_DOWN;
   const bool current_watch=current_watch_up || current_watch_down;

   const bool previous_watch_up=
      g_assist_state.previous_state==JTA_ASSIST_REVERSAL_WATCH_UP;
   const bool previous_watch_down=
      g_assist_state.previous_state==JTA_ASSIST_REVERSAL_WATCH_DOWN;

   // Explicitly close a completed/cancelled/flipped pre-reversal episode.
   // This only maintains alert lifecycle metadata; strategy state is untouched.
   if(g_assist_state.changed)
   {
      if(previous_watch_up && !current_watch_up)
         JTAPreReversalEpisodeClose(1);
      if(previous_watch_down && !current_watch_down)
         JTAPreReversalEpisodeClose(-1);
   }

   if(InpAssistStateShowChart)
   {
      const string panel="JTA_ASSIST_STATE_PANEL";
      if(ObjectFind(0,panel)<0)
      {
         if(ObjectCreate(0,panel,OBJ_LABEL,0,0,0))
         {
            ObjectSetInteger(0,panel,OBJPROP_CORNER,CORNER_RIGHT_UPPER);
            ObjectSetInteger(0,panel,OBJPROP_XDISTANCE,18);
            ObjectSetInteger(0,panel,OBJPROP_YDISTANCE,42);
            ObjectSetInteger(0,panel,OBJPROP_FONTSIZE,11);
            ObjectSetString(0,panel,OBJPROP_FONT,"Arial");
            ObjectSetInteger(0,panel,OBJPROP_SELECTABLE,false);
            ObjectSetInteger(0,panel,OBJPROP_HIDDEN,true);
         }
      }

      if(ObjectFind(0,panel)>=0)
      {
         color panel_color=clrSilver;
         if(g_assist_state.state==JTA_ASSIST_UP)
            panel_color=clrLimeGreen;
         else if(g_assist_state.state==JTA_ASSIST_DOWN)
            panel_color=clrTomato;
         else if(g_assist_state.state==JTA_ASSIST_UP_WEAKENING ||
                 g_assist_state.state==JTA_ASSIST_DOWN_WEAKENING)
            panel_color=clrOrange;
         else if(current_watch)
            panel_color=clrOrange;

         const string text=StringFormat("STATE %s | %s\n%s",
            UITFName(g_assist_state.timeframe),UIAssistStateDisplayName(g_assist_state.state),
            UIAssistStateActionText(g_assist_state.state));
         ObjectSetString(0,panel,OBJPROP_TEXT,text);
         ObjectSetInteger(0,panel,OBJPROP_COLOR,panel_color);
      }
   }

   // v8.209: WEAK is chart-only manual information.
   // No system alert, mobile push, AUTO, EXIT, ADD or SL path exists.
   if(InpAssistStateShowChart && g_assist_state.weak_pulse && g_assist_state.weak_side!=0)
   {
      const int weak_side=g_assist_state.weak_side;
      const string marker=StringFormat("JTA_WEAK_%I64d_%d",(long)g_assist_state.bar_time,weak_side);
      if(ObjectFind(0,marker)<0)
      {
         const double offset=MathMax(_Point,g_assist_state.avg_range*0.18);
         const bool long_weak=(weak_side>0);
         const double price=long_weak ? g_assist_state.high_price+offset : g_assist_state.low_price-offset;
         if(ObjectCreate(0,marker,OBJ_TEXT,0,g_assist_state.bar_time,price))
         {
            ObjectSetString(0,marker,OBJPROP_TEXT,long_weak ? "LONG WEAK" : "SHORT WEAK");
            ObjectSetInteger(0,marker,OBJPROP_COLOR,clrGray);
            ObjectSetInteger(0,marker,OBJPROP_FONTSIZE,9);
            ObjectSetInteger(0,marker,OBJPROP_ANCHOR,long_weak ? ANCHOR_LOWER : ANCHOR_UPPER);
            ObjectSetInteger(0,marker,OBJPROP_SELECTABLE,false);
            ObjectSetInteger(0,marker,OBJPROP_HIDDEN,true);
         }
      }
   }

   if(!g_assist_state.changed)
      return;

   if(!current_watch)
      return;

   const int watch_side=current_watch_up ? 1 : -1;

   // v8.280: pure same-side informational WATCH repeats remain available to
   // CSV/lifecycle diagnostics but are not useful as repeated manual-trading
   // chart signals or system alerts. Preserve visibility only when the same
   // informational pulse is currently eligible for the v8.279 PREZERO
   // CONFIRMED re-entry exception while flat. AUTO/ownership logic is untouched.
   const bool prezero_reentry_visible=(
      g_assist_state.watch_informational_repeat &&
      ManagedPositionSide()==0 &&
      g_prezero_reentry_armed && g_prezero_reentry_side!=0 &&
      g_prezero_reentry_exit_time>0 &&
      g_assist_state.bar_time>g_prezero_reentry_exit_time &&
      watch_side==g_prezero_reentry_side &&
      g_assist_state.watch_observe_stage=="CONFIRMED");
   const bool pure_informational_repeat=(
      g_assist_state.watch_informational_repeat && !prezero_reentry_visible);
   if(pure_informational_repeat)
      return;

   const bool repeat_pulse=
      g_assist_state.watch_pulse &&
      g_assist_state.previous_state==g_assist_state.state;

   // Chart objects are optional and do not gate alerts.
   if(InpAssistStateShowChart)
   {
      const string marker=StringFormat("JTA_ASSIST_%I64d_%d",
         (long)g_assist_state.bar_time,(int)g_assist_state.state);
      if(ObjectFind(0,marker)<0)
      {
         const int shift=iBarShift(_Symbol,g_assist_state.timeframe,g_assist_state.bar_time,true);
         if(shift>=0)
         {
            const bool up_marker=current_watch_up;
            const double high=g_assist_state.high_price;
            const double low=g_assist_state.low_price;
            const double offset=MathMax(_Point,g_assist_state.avg_range*0.18);
            const double price=up_marker ? low-offset : high+offset;
            if(ObjectCreate(0,marker,OBJ_TEXT,0,g_assist_state.bar_time,price))
            {
               // StateEvaluation pre-signal: green LONG WATCH / orange SHORT WATCH.
               const string label=(up_marker ? "LONG WATCH" : "SHORT WATCH");
               ObjectSetString(0,marker,OBJPROP_TEXT,label);
               ObjectSetInteger(0,marker,OBJPROP_COLOR,up_marker ? clrLime : clrOrange);
               ObjectSetInteger(0,marker,OBJPROP_FONTSIZE,10);
               ObjectSetInteger(0,marker,OBJPROP_ANCHOR,up_marker?ANCHOR_UPPER:ANCHOR_LOWER);
               ObjectSetInteger(0,marker,OBJPROP_SELECTABLE,false);
               ObjectSetInteger(0,marker,OBJPROP_HIDDEN,true);
            }
         }
      }
   }

   // v8.121: StateEvaluation pre-signal is a SYSTEM ALERT independently of
   // the WATCH chart-display mode. The chart marker remains controlled by
   // InpAssistStateShowChart, but SYSTEM ALERT must deliver the pre-signal
   // together with the M3 acceleration alert. Delivery remains deduplicated
   // by the existing side/bar/event keys.
   {
      const string direction=(watch_side>0 ? "LONG" : "SHORT");
      const string tf=UITFName(g_assist_state.timeframe);

      if(!repeat_pulse)
      {
         JTAPreReversalEpisodeClose(-watch_side);
         JTAPreReversalEpisodeStart(watch_side,g_assist_state.bar_time);
         if(!JTAWatchAlertAlreadyDelivered(watch_side,g_assist_state.bar_time,"PRE_START"))
         {
            const string msg=StringFormat(
               "!!! [사전반전 %s] %s | 반전 가능성 시작 | %s",
               direction,_Symbol,tf);
            NotifyUser(msg);
            JTAWatchAlertMarkDelivered(watch_side,g_assist_state.bar_time,"PRE_START");
         }
      }
      else if(JTAPreReversalFirstRepeatPending(watch_side) &&
              !JTAWatchAlertAlreadyDelivered(watch_side,g_assist_state.bar_time,"PRE_PROGRESS"))
      {
         const string msg=StringFormat(
            "!!! [반전진행 %s] %s | 사전반전 진행 재확인 | %s",
            direction,_Symbol,tf);
         NotifyUser(msg);
         JTAWatchAlertMarkDelivered(watch_side,g_assist_state.bar_time,"PRE_PROGRESS");
         JTAPreReversalMarkFirstRepeatDelivered(watch_side);
      }
   }
}

//+------------------------------------------------------------------+
//| v7.22 Visual tester analysis: attach existing canonical handles. |
//| No display-only indicator handles are created.                   |
//+------------------------------------------------------------------+



// v7.28: Visual Tester indicator display is owned entirely by MT5/template.
// The EA must not attach, delete, normalize, or duplicate any displayed indicator.



#endif // __JOON_UI_MQH__
