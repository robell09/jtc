//+------------------------------------------------------------------+
//| DataExportEngine.mqh                                             |
//| Single owner of CSV/file persistence for the entire EA           |
//+------------------------------------------------------------------+
#ifndef __JOON_DATAEXPORTENGINE_MQH__
#define __JOON_DATAEXPORTENGINE_MQH__

// Compile-safety fallback for mixed file installations.
// In the complete package these variables are declared by Common.mqh.
#ifndef __JOON_CSV_ADD_STATE_DECLARED__
#define __JOON_CSV_ADD_STATE_DECLARED__
bool     g_csv_add_enabled = false;
int      g_csv_add_count_before = 0;
int      g_csv_add_count_after = 0;
int      g_csv_add_signal_count = 0;
int      g_csv_add_signal_required = 2;
int      g_csv_add_capacity_remaining = 0;
int      g_csv_add_stage = 0;
bool     g_csv_add_same_direction_signal = false;
bool     g_csv_add_opposite_direction_signal = false;
bool     g_csv_add_exit_safe = false;
bool     g_csv_add_attempted = false;
bool     g_csv_add_result = false;
long     g_csv_add_retcode = 0;
string   g_csv_add_block_reason = "";
datetime g_csv_add_signal_bar_time = 0;
int      g_csv_add_bars_since_entry = 0;
double   g_csv_add_progress_r = 0.0;
double   g_csv_add_requested_volume = 0.0;
double   g_csv_add_fill_price = 0.0;
#endif // __JOON_CSV_ADD_STATE_DECLARED__



//+------------------------------------------------------------------+
string DataExportCsvEscape(const string value)
{
   string escaped = value;
   StringReplace(escaped, "\"", "\"\"");
   if(StringFind(escaped, ",") >= 0 || StringFind(escaped, "\"") >= 0 ||
      StringFind(escaped, "\r") >= 0 || StringFind(escaped, "\n") >= 0)
      return "\"" + escaped + "\"";
   return escaped;
}

void DataExportCsvAdd(string &line, const string value)
{
   if(StringLen(line) > 0)
      line += ",";
   line += DataExportCsvEscape(value);
}

// Count CSV fields while respecting quoted commas and doubled quotes.
// v3.06: the current unified Strategy Tester header and row both contain
// exactly 180 columns. Keep this validator synchronized with the actual
// schema builders, not with an obsolete historical target.
int DataExportCsvColumnCount(const string line)
{
   const int length = StringLen(line);
   if(length <= 0) return 0;
   int columns = 1;
   bool in_quotes = false;
   for(int i=0; i<length; i++)
   {
      const ushort ch = StringGetCharacter(line, i);
      if(ch == '"')
      {
         if(in_quotes && i+1 < length && StringGetCharacter(line, i+1) == '"')
         {
            i++;
            continue;
         }
         in_quotes = !in_quotes;
      }
      else if(ch == ',' && !in_quotes)
         columns++;
   }
   return columns;
}

int DataExportStrategyTestColumnCount()
{
   // v8.266: +4 canonical WATCH suppression-lifecycle diagnostics on top of v8.264.
   // Header/row/schema guard remain synchronized.
   return 628;
}


//+------------------------------------------------------------------+
bool DataExportIsTester()
{
   return (bool)MQLInfoInteger(MQL_TESTER);
}

string DataExportEnvironment()
{
   return DataExportIsTester() ? "TESTER" : "LIVE";
}

string DataExportTesterModelName()
{
   if(!DataExportIsTester()) return "LIVE";
   switch(InpTesterModel)
   {
      case TESTER_MODEL_REAL_TICKS: return "REAL_TICKS";
      case TESTER_MODEL_EVERY_TICK: return "EVERY_TICK";
      case TESTER_MODEL_M1_OHLC:    return "M1_OHLC";
      case TESTER_MODEL_OPEN_PRICE: return "OPEN_PRICE";
      case TESTER_MODEL_MATH:       return "MATH";
   }
   return "UNKNOWN";
}

uint DataExportHash32(const string value)
{
   uint hash = 2166136261;
   const int n = StringLen(value);
   for(int i=0; i<n; i++)
   {
      hash ^= (uint)StringGetCharacter(value,i);
      hash *= 16777619;
   }
   return hash;
}

string DataExportTerminalToken()
{
   static string token = "";
   if(token != "") return token;
   token = StringFormat("T%I64u",(ulong)DataExportHash32(TerminalInfoString(TERMINAL_PATH)));
   return token;
}

string DataExportDataInstanceToken()
{
   static string token = "";
   if(token != "") return token;
   token = StringFormat("D%I64u",(ulong)DataExportHash32(TerminalInfoString(TERMINAL_DATA_PATH)));
   return token;
}

string g_data_export_run_id = "";
ulong  g_data_export_run_nonce = 0;

// v8.89: one canonical CSV stream for Tester and LIVE; full validation state retained.
bool g_integrated_csv_mode = true;
bool g_integrated_csv_event_guard = false;

// v2.90 diagnostic-only buffered I/O. Core order/lifecycle CSVs are untouched.
int    g_diag_profit_lock_handle = INVALID_HANDLE;
int    g_diag_range_exit_handle  = INVALID_HANDLE;
int    g_diag_watch_handle       = INVALID_HANDLE;
string g_diag_profit_lock_file   = "";
string g_diag_range_exit_file    = "";
string g_diag_watch_file         = "";
bool   g_diag_profit_lock_dirty  = false;
bool   g_diag_range_exit_dirty   = false;
bool   g_diag_watch_dirty        = false;
ulong  g_diag_profit_lock_flush_msc = 0;
ulong  g_diag_range_exit_flush_msc  = 0;
ulong  g_diag_watch_flush_msc       = 0;

// v4.06: major live CSV streams keep persistent file handles instead of
// FileOpen/Flush/Close on every event. Tester-specific fast handles remain
// untouched. These handles are live-only and flushed by OnTimer once per sec.
int    g_live_unified_event_handle = INVALID_HANDLE;
int    g_live_order_audit_handle   = INVALID_HANDLE;
int    g_live_signal_decision_handle = INVALID_HANDLE;
int    g_live_lifecycle_handle     = INVALID_HANDLE;
// v6.15: ConfirmedMomentumAudit is analysis-critical but diagnostic-only.
// Keep every row/schema unchanged while avoiding per-FINAL open/flush/close in LIVE.
int    g_live_confirmed_momentum_handle = INVALID_HANDLE;

string g_live_unified_event_file = "";
string g_live_order_audit_file   = "";
string g_live_signal_decision_file = "";
string g_live_lifecycle_file     = "";
string g_live_confirmed_momentum_file = "";

bool   g_live_unified_event_dirty = false;
bool   g_live_order_audit_dirty   = false;
bool   g_live_signal_decision_dirty = false;
bool   g_live_lifecycle_dirty     = false;
bool   g_live_confirmed_momentum_dirty = false;

ulong  g_live_unified_event_flush_msc = 0;
ulong  g_live_order_audit_flush_msc   = 0;
ulong  g_live_signal_decision_flush_msc = 0;
ulong  g_live_lifecycle_flush_msc     = 0;
ulong  g_live_confirmed_momentum_flush_msc = 0;

// v4.06 repeated diagnostic dedup.
// Only non-critical WAIT/BLOCK/OBSERVE audit rows are deduplicated.
// Real order/filled/exit/SL/profit-lock/trigger events are never suppressed.
datetime g_audit_dedup_bar_time = 0;
string   g_audit_dedup_key = "";

void DataExportFlushOneDiagnostic(int &handle,
                                  bool &dirty,
                                  ulong &last_flush_msc,
                                  const bool close_handle)
{
   if(handle==INVALID_HANDLE)
      return;

   if(dirty)
   {
      FileFlush(handle);
      dirty=false;
      last_flush_msc=GetTickCount64();
   }

   if(close_handle)
   {
      FileClose(handle);
      handle=INVALID_HANDLE;
   }
}



void DataExportCloseLiveHandle(int &handle,string &active_file,bool &dirty)
{
   if(handle==INVALID_HANDLE)
      return;
   if(dirty)
      FileFlush(handle);
   FileClose(handle);
   handle=INVALID_HANDLE;
   active_file="";
   dirty=false;
}

bool DataExportEnsureLiveBufferedHandle(const string file_name,
                                        int &handle,
                                        string &active_file)
{
   if(DataExportIsTester())
      return false;

   if(handle!=INVALID_HANDLE && active_file==file_name)
      return true;

   if(handle!=INVALID_HANDLE)
   {
      FileFlush(handle);
      FileClose(handle);
      handle=INVALID_HANDLE;
   }

   handle=FileOpen(file_name,
      DataExportFileFlags(FILE_READ|FILE_WRITE|FILE_ANSI|FILE_SHARE_READ|FILE_SHARE_WRITE),
      0,CP_UTF8);
   if(handle==INVALID_HANDLE)
   {
      active_file="";
      return false;
   }

   active_file=file_name;
   FileSeek(handle,0,SEEK_END);
   return true;
}

void DataExportFlushLiveBufferedFiles(const bool close_handles=false)
{
   const ulong now_msc=GetTickCount64();

   if(g_live_unified_event_handle!=INVALID_HANDLE &&
      (close_handles ||
       (g_live_unified_event_dirty &&
        (g_live_unified_event_flush_msc==0 ||
         now_msc-g_live_unified_event_flush_msc>=1000))))
   {
      if(g_live_unified_event_dirty)
      {
         FileFlush(g_live_unified_event_handle);
         g_live_unified_event_dirty=false;
         g_live_unified_event_flush_msc=now_msc;
      }
      if(close_handles)
      {
         FileClose(g_live_unified_event_handle);
         g_live_unified_event_handle=INVALID_HANDLE;
         g_live_unified_event_file="";
      }
   }

   if(g_live_order_audit_handle!=INVALID_HANDLE &&
      (close_handles ||
       (g_live_order_audit_dirty &&
        (g_live_order_audit_flush_msc==0 ||
         now_msc-g_live_order_audit_flush_msc>=1000))))
   {
      if(g_live_order_audit_dirty)
      {
         FileFlush(g_live_order_audit_handle);
         g_live_order_audit_dirty=false;
         g_live_order_audit_flush_msc=now_msc;
      }
      if(close_handles)
      {
         FileClose(g_live_order_audit_handle);
         g_live_order_audit_handle=INVALID_HANDLE;
         g_live_order_audit_file="";
      }
   }

   if(g_live_signal_decision_handle!=INVALID_HANDLE &&
      (close_handles ||
       (g_live_signal_decision_dirty &&
        (g_live_signal_decision_flush_msc==0 ||
         now_msc-g_live_signal_decision_flush_msc>=1000))))
   {
      if(g_live_signal_decision_dirty)
      {
         FileFlush(g_live_signal_decision_handle);
         g_live_signal_decision_dirty=false;
         g_live_signal_decision_flush_msc=now_msc;
      }
      if(close_handles)
      {
         FileClose(g_live_signal_decision_handle);
         g_live_signal_decision_handle=INVALID_HANDLE;
         g_live_signal_decision_file="";
      }
   }

   if(g_live_lifecycle_handle!=INVALID_HANDLE &&
      (close_handles ||
       (g_live_lifecycle_dirty &&
        (g_live_lifecycle_flush_msc==0 ||
         now_msc-g_live_lifecycle_flush_msc>=1000))))
   {
      if(g_live_lifecycle_dirty)
      {
         FileFlush(g_live_lifecycle_handle);
         g_live_lifecycle_dirty=false;
         g_live_lifecycle_flush_msc=now_msc;
      }
      if(close_handles)
      {
         FileClose(g_live_lifecycle_handle);
         g_live_lifecycle_handle=INVALID_HANDLE;
         g_live_lifecycle_file="";
      }
   }


   if(g_live_confirmed_momentum_handle!=INVALID_HANDLE &&
      (close_handles ||
       (g_live_confirmed_momentum_dirty &&
        (g_live_confirmed_momentum_flush_msc==0 ||
         now_msc-g_live_confirmed_momentum_flush_msc>=1000))))
   {
      if(g_live_confirmed_momentum_dirty)
      {
         FileFlush(g_live_confirmed_momentum_handle);
         g_live_confirmed_momentum_dirty=false;
         g_live_confirmed_momentum_flush_msc=now_msc;
      }
      if(close_handles)
      {
         FileClose(g_live_confirmed_momentum_handle);
         g_live_confirmed_momentum_handle=INVALID_HANDLE;
         g_live_confirmed_momentum_file="";
      }
   }
}

// Same completed execution bar + same diagnostic state is written once.
// This reduces repeated WAIT/BLOCK spam without removing state changes.

bool DataExportIsCriticalEvent(const string record_type,
                               const string event_name,
                               const string decision)
{
   const string rt=record_type;
   const string ev=event_name;
   const string dc=decision;

   if(rt=="LIFECYCLE")
      return true;
   if(rt=="TRADE" || rt=="POSITION" || rt=="RISK")
      return true;
   if(StringFind(ev,"ORDER")>=0 ||
      StringFind(ev,"FILL")>=0 ||
      StringFind(ev,"DEAL")>=0 ||
      StringFind(ev,"EXIT")>=0 ||
      StringFind(ev,"CLOSE")>=0 ||
      StringFind(ev,"SL")>=0 ||
      StringFind(ev,"PROFIT_LOCK")>=0 ||
      StringFind(ev,"WATCH_TRIGGER")>=0 ||
      dc=="SUCCESS" || dc=="FILLED" || dc=="TRIGGER_FIRED")
      return true;
   return false;
}

void DataExportFlushLiveHandleNow(int handle,bool &dirty,ulong &last_flush_msc)
{
   if(handle==INVALID_HANDLE || !dirty)
      return;
   FileFlush(handle);
   dirty=false;
   last_flush_msc=GetTickCount64();
}

bool DataExportShouldSkipRepeatedAudit(const string stage,
                                       const string decision,
                                       const int side,
                                       const string reason)
{
   const bool repeatable=
      (decision=="WAIT" || decision=="BLOCKED" ||
       decision=="OBSERVE" || decision=="RECHECK");
   if(!repeatable)
      return false;

   ENUM_TIMEFRAMES tf=AUTO_TF;
   if(g_calc_tf!=PERIOD_CURRENT)
      tf=g_calc_tf;

   const datetime bar_time=iTime(_Symbol,tf,0);
   if(bar_time<=0)
      return false;

   // v4.07: use stable state identity for dedup. The full reason string often
   // contains live MACD/Delta/price numbers that change every tick and would
   // defeat bar-level dedup. Stage + decision + side is the diagnostic state;
   // the first row still preserves the complete reason payload.
   const string key=stage+"|"+decision+"|"+IntegerToString(side);
   if(g_audit_dedup_bar_time==bar_time && g_audit_dedup_key==key)
      return true;

   g_audit_dedup_bar_time=bar_time;
   g_audit_dedup_key=key;
   return false;
}

void DataExportFlushBufferedDiagnostics(const bool close_handles=false)
{
   const ulong now_msc=GetTickCount64();

   if(close_handles ||
      (g_diag_profit_lock_dirty &&
       (g_diag_profit_lock_flush_msc==0 ||
        now_msc-g_diag_profit_lock_flush_msc>=1000)))
      DataExportFlushOneDiagnostic(g_diag_profit_lock_handle,
         g_diag_profit_lock_dirty,g_diag_profit_lock_flush_msc,close_handles);

   if(close_handles ||
      (g_diag_range_exit_dirty &&
       (g_diag_range_exit_flush_msc==0 ||
        now_msc-g_diag_range_exit_flush_msc>=1000)))
      DataExportFlushOneDiagnostic(g_diag_range_exit_handle,
         g_diag_range_exit_dirty,g_diag_range_exit_flush_msc,close_handles);

   if(close_handles ||
      (g_diag_watch_dirty &&
       (g_diag_watch_flush_msc==0 ||
        now_msc-g_diag_watch_flush_msc>=1000)))
      DataExportFlushOneDiagnostic(g_diag_watch_handle,
         g_diag_watch_dirty,g_diag_watch_flush_msc,close_handles);

   if(close_handles)
   {
      g_diag_profit_lock_file="";
      g_diag_range_exit_file="";
      g_diag_watch_file="";
   }
}

string DataExportRunId()
{
   if(g_data_export_run_id != "") return g_data_export_run_id;
   MqlDateTime t;
   TimeToStruct(TimeLocal(), t);
   if(g_data_export_run_nonce == 0)
      g_data_export_run_nonce = GetMicrosecondCount();
   g_data_export_run_id = StringFormat("%04d%02d%02d_%02d%02d%02d_%I64d_%s_%I64u",
      t.year,t.mon,t.day,t.hour,t.min,t.sec,ChartID(),DataExportDataInstanceToken(),g_data_export_run_nonce);
   return g_data_export_run_id;
}

string DataExportTestFrom()
{
   if(!DataExportIsTester()) return "";
   const datetime value = InpTesterFrom > 0 ? InpTesterFrom : TimeCurrent();
   return TimeToString(value, TIME_DATE|TIME_MINUTES);
}

string DataExportTestTo()
{
   if(!DataExportIsTester() || InpTesterTo <= 0) return "";
   return TimeToString(InpTesterTo, TIME_DATE|TIME_MINUTES);
}

int DataExportCommonFlag()
{
   return InpCsvStorageLocation == CSV_STORAGE_COMMON ? FILE_COMMON : 0;
}

int DataExportFileFlags(const int flags)
{
   return flags | DataExportCommonFlag();
}

string DataExportProgramName(){ return "Joon Trade Compass"; }
string DataExportEaVersion(){ return JTC_EA_VERSION; }
string DataExportCsvSchemaVersion(){ return "8.285-TURNPRE-ORDERS"; }
string DataExportStrategyNameValue(const ENUM_STRATEGY_MODE mode)
{
   if(mode==STRATEGY_TREND) return "TREND";
   return "RANGE";
}
string DataExportSignalTfName()
{
   return EnumToString(g_signal_tf);
}
string DataExportManagementTfName()
{
   return EnumToString(ActiveManagementTF());
}
string DataExportEntryStrategyName()
{
   return g_trade_cycle.entry_strategy_valid ?
      DataExportStrategyNameValue(g_trade_cycle.entry_strategy) : "UNKNOWN";
}
string DataExportStrategyChangedAfterEntry()
{
   return g_trade_cycle.entry_strategy_valid ?
      (g_trade_cycle.strategy_changed_after_entry ? "YES" : "NO") : "UNKNOWN";
}
string DataExportStrategyChangeTime()
{
   return g_trade_cycle.strategy_change_time>0 ?
      TimeToString(g_trade_cycle.strategy_change_time,TIME_DATE|TIME_SECONDS) : "";
}
string DataExportStrategyConsistent()
{
   if(!g_trade_cycle.entry_strategy_valid)
      return "UNKNOWN";
   return g_trade_cycle.entry_strategy==g_position_strategy ? "YES" : "NO";
}

void DataExportAddContextHeader(string &line)
{
   DataExportCsvAdd(line, "environment");
   DataExportCsvAdd(line, "test_from");
   DataExportCsvAdd(line, "test_to");
   DataExportCsvAdd(line, "run_id");
   DataExportCsvAdd(line, "tester_model");
   DataExportCsvAdd(line, "terminal_token");
   DataExportCsvAdd(line, "data_instance_token");
   DataExportCsvAdd(line, "program_name");
   DataExportCsvAdd(line, "ea_version");
   DataExportCsvAdd(line, "csv_schema_version");
   DataExportCsvAdd(line, "selected_strategy");
   DataExportCsvAdd(line, "position_strategy");
   DataExportCsvAdd(line, "signal_tf");
   DataExportCsvAdd(line, "management_tf");

   DataExportCsvAdd(line, "entry_strategy");
   DataExportCsvAdd(line, "current_selected_strategy");
   DataExportCsvAdd(line, "position_management_strategy");
   DataExportCsvAdd(line, "strategy_changed_after_entry");
   DataExportCsvAdd(line, "strategy_change_time");
   DataExportCsvAdd(line, "strategy_consistent");
}

void DataExportAddContextRow(string &line)
{
   DataExportCsvAdd(line, DataExportEnvironment());
   DataExportCsvAdd(line, DataExportTestFrom());
   DataExportCsvAdd(line, DataExportTestTo());
   DataExportCsvAdd(line, DataExportRunId());
   DataExportCsvAdd(line, DataExportTesterModelName());
   DataExportCsvAdd(line, DataExportTerminalToken());
   DataExportCsvAdd(line, DataExportDataInstanceToken());
   DataExportCsvAdd(line, DataExportProgramName());
   DataExportCsvAdd(line, DataExportEaVersion());
   DataExportCsvAdd(line, DataExportCsvSchemaVersion());
   DataExportCsvAdd(line, DataExportStrategyNameValue(g_selected_strategy));
   DataExportCsvAdd(line, DataExportStrategyNameValue(g_position_strategy));
   DataExportCsvAdd(line, DataExportSignalTfName());
   DataExportCsvAdd(line, DataExportManagementTfName());

   DataExportCsvAdd(line, DataExportEntryStrategyName());
   DataExportCsvAdd(line, DataExportStrategyNameValue(g_selected_strategy));
   DataExportCsvAdd(line, DataExportStrategyNameValue(g_position_strategy));
   DataExportCsvAdd(line, DataExportStrategyChangedAfterEntry());
   DataExportCsvAdd(line, DataExportStrategyChangeTime());
   DataExportCsvAdd(line, DataExportStrategyConsistent());
}

string DataExportBaseFolder()
{
   return DataExportIsTester() ? "Joon\\Test" : "Joon";
}

string DataExportPath(const string file_name)
{
   const string prefix = DataExportIsTester() ? ("TEST_" + DataExportRunId() + "_") : "";
   return DataExportBaseFolder() + "\\" + prefix + file_name;
}

bool DataExportEnsureFolder()
{
   ResetLastError();
   FolderCreate("Joon", DataExportCommonFlag());
   ResetLastError();
   if(FolderCreate(DataExportBaseFolder(), DataExportCommonFlag()))
   {
      Print("[JTA CSV] Folder ready: MQL5\\Files\\", DataExportBaseFolder());
      return true;
   }

   const int error = GetLastError();
   // 5010/5004 may be returned by some terminals when the folder already exists.
   // Confirm usability by opening a small startup file below instead of failing here.
   PrintFormat("[JTA CSV] FolderCreate result | folder=MQL5\\Files\\%s | error=%d", DataExportBaseFolder(), error);
   ResetLastError();
   return true;
}

void DataExportWriteRunInfo()
{
   if(g_integrated_csv_mode)
   {
      DataExportWriteUnifiedEvent("SYSTEM","RUN_INFO",0,0,0.0,0.0,0,
         "OBSERVE","RUN_INFO","",0.0,0.0,
         StringFormat("BUILD=%d STRATEGY=%s SIGNAL_TF=%s MANAGEMENT_TF=%s MAGIC=%I64u",
            (int)TerminalInfoInteger(TERMINAL_BUILD),
            DataExportStrategyNameValue(g_selected_strategy),
            DataExportSignalTfName(),DataExportManagementTfName(),InpMagicNumber),
         TimeCurrent());
      return;
   }
   if(DataExportIsTester()) return;
   const string file_name = DataExportPath("RunInfo_v2_69.csv");
   const int handle = FileOpen(file_name,
      DataExportFileFlags(FILE_READ|FILE_WRITE|FILE_ANSI|FILE_SHARE_READ|FILE_SHARE_WRITE),
      0, CP_UTF8);
   if(handle == INVALID_HANDLE)
   {
      PrintFormat("[JTA CSV] RUN INFO OPEN FAILED | file=%s | error=%d",
                  file_name, GetLastError());
      return;
   }
   if(FileSize(handle) == 0)
   {
      string header="";
      DataExportAddContextHeader(header);
      DataExportCsvAdd(header,"ea_name");
      DataExportCsvAdd(header,"terminal_build");
      DataExportCsvAdd(header,"symbol");
      DataExportCsvAdd(header,"timeframe");
      DataExportCsvAdd(header,"magic");
      DataExportCsvAdd(header,"strategy");
      DataExportCsvAdd(header,"signal_direction");
      DataExportCsvAdd(header,"trade_direction");
      DataExportCsvAdd(header,"lots");
      DataExportCsvAdd(header,"sl_percent");
      DataExportCsvAdd(header,"max_additional_entries");
      DataExportCsvAdd(header,"storage");
      FileWriteString(g_signal_bar_audit_handle,header+"\r\n");
   }
   FileSeek(handle, 0, SEEK_END);
   string row = "";
   DataExportAddContextRow(row);
   DataExportCsvAdd(row, DataExportProgramName());
   DataExportCsvAdd(row, (string)TerminalInfoInteger(TERMINAL_BUILD));
   DataExportCsvAdd(row, _Symbol);
   DataExportCsvAdd(row, EnumToString(g_signal_tf));
   DataExportCsvAdd(row, (string)InpMagicNumber);
   DataExportCsvAdd(row,"RANGE");
   DataExportCsvAdd(row, EnumToString(InpSignalDirection));
   DataExportCsvAdd(row, EnumToString(InpTradeDirection));
   DataExportCsvAdd(row, DoubleToString(InpLots, 8));
   DataExportCsvAdd(row, DoubleToString(InpRangeStopLossPercent, 4));
   DataExportCsvAdd(row, (string)InpDefaultAdditionalEntries);
   DataExportCsvAdd(row, InpCsvStorageLocation == CSV_STORAGE_COMMON ? "COMMON" : "TERMINAL");
   FileWriteString(handle, row + "\r\n");
   FileFlush(handle);
   FileClose(handle);
}

string SignalDecisionFileName()
{
   // v8.171: keep the canonical integrated CSV name short and self-identifying.
   // DataExportRunId() begins with YYYYMMDD_HHMMSS; the long chart/data/nonce
   // suffix remains inside the CSV run_id field and is not repeated in the filename.
   const string short_run=StringSubstr(DataExportRunId(),0,15);
   return DataExportPath(StringFormat(
      "JTC_v%s_%s_%s.csv",
      DataExportEaVersion(), TradeLogSafeFileToken(_Symbol), short_run));
}

bool DataExportStatusHeaderMatches(const string file_name)
{
   if(!FileIsExist(file_name,DataExportCommonFlag()))
      return true;

   const int handle=FileOpen(file_name,
      DataExportFileFlags(FILE_READ|FILE_TXT|FILE_ANSI|FILE_SHARE_READ|FILE_SHARE_WRITE),
      0,CP_UTF8);
   if(handle==INVALID_HANDLE)
      return false;

   if(FileSize(handle)==0)
   {
      FileClose(handle);
      return true;
   }

   // The legacy status-file schema is not part of the canonical integrated
   // export path.  Do not attempt to call an undefined/generated header
   // function here.  Preserve any existing legacy file and route current
   // schema output to the versioned status file instead.
   FileClose(handle);
   return false;
}

string DataExportResolvedStatusFileName()
{
   const string legacy_name=DataExportPath("JTA_CSV_Status.csv");
   if(DataExportStatusHeaderMatches(legacy_name))
      return legacy_name;

   // Preserve the old mixed/legacy file untouched. Current-schema rows go to
   // a versioned file so 4-column and 9-column records can never be appended
   // into the same CSV again.
   Print("[JTA CSV] STATUS SCHEMA MISMATCH | legacy file preserved | NEW=JTA_CSV_Status_v277.csv");
   return DataExportPath("JTA_CSV_Status_v277.csv");
}

bool DataExportInitialize()
{
   DataExportEnsureFolder();
   DataExportRunId();
   if(!g_integrated_csv_mode) return true;

   const string file_name=SignalDecisionFileName();
   ResetLastError();
   const int handle=FileOpen(file_name,
      DataExportFileFlags(FILE_READ|FILE_WRITE|FILE_TXT|FILE_ANSI|FILE_SHARE_READ|FILE_SHARE_WRITE),
      0,CP_UTF8);
   if(handle==INVALID_HANDLE)
   {
      PrintFormat("[JTA CSV] INTEGRATED INIT FAILED | file=%s | error=%d",file_name,GetLastError());
      return false;
   }
   FileSeek(handle,0,SEEK_END);
   FileClose(handle);
   PrintFormat("[JTA CSV] SINGLE INTEGRATED FILE | schema=%d | MQL5\\Files\\%s",
               DataExportStrategyTestColumnCount(),file_name);
   return true;
}

//+------------------------------------------------------------------+
string TradeLogSafeFileToken(string value)
{
   StringReplace(value, "\\", "_");
   StringReplace(value, "/", "_");
   StringReplace(value, ":", "_");
   StringReplace(value, "*", "_");
   StringReplace(value, "?", "_");
   StringReplace(value, "\"", "_");
   StringReplace(value, "<", "_");
   StringReplace(value, ">", "_");
   StringReplace(value, "|", "_");
   return value;
}

//+------------------------------------------------------------------+
string TradeLogFileName()
{
   MqlDateTime now;
   TimeToStruct(TimeCurrent(), now);
   return DataExportPath(StringFormat("JTA_TradeAnalysis_v2_%s_%I64u_%04d%02d%02d.csv",
                       TradeLogSafeFileToken(_Symbol), InpMagicNumber,
                       now.year, now.mon, now.day));
}

//+------------------------------------------------------------------+
string TradeLogStrategyName()
{
   const ENUM_STRATEGY_MODE mode =
      g_position_strategy_locked ? g_position_strategy : g_selected_strategy;
   if(mode==STRATEGY_TREND) return "TREND";
   if(mode==STRATEGY_RANGE) return "RANGE";
   return "TREND";
}

//+------------------------------------------------------------------+
string TradeLogResultName(const double net_profit)
{
   if(net_profit > 0.0000001) return "PROFIT";
   if(net_profit < -0.0000001) return "LOSS";
   return "FLAT";
}

//+------------------------------------------------------------------+
string DataExportSessionName(const datetime value)
{
   MqlDateTime t;
   TimeToStruct(value, t);
   if(t.hour < 8)  return "ASIA";
   if(t.hour < 16) return "EUROPE";
   return "US";
}

//+------------------------------------------------------------------+
string DataExportWeekdayName(const datetime value)
{
   MqlDateTime t;
   TimeToStruct(value, t);
   const string names[7] = {"SUN","MON","TUE","WED","THU","FRI","SAT"};
   if(t.day_of_week < 0 || t.day_of_week > 6) return "UNKNOWN";
   return names[t.day_of_week];
}

//+------------------------------------------------------------------+
string DataExportSignalId(const datetime value, const int side,
                          const ulong position_id)
{
   MqlDateTime t;
   TimeToStruct(value, t);
   return StringFormat("%s_%04d%02d%02d_%02d%02d%02d_%s_%I64u",
      TradeLogSafeFileToken(_Symbol), t.year, t.mon, t.day,
      t.hour, t.min, t.sec, side >= 0 ? "LONG" : "SHORT", position_id);
}

//+------------------------------------------------------------------+
string DataExportConfidenceName(const int confidence)
{
   if(confidence >= 70) return "HIGH";
   if(confidence >= 50) return "MEDIUM";
   return "LOW";
}

//+------------------------------------------------------------------+
datetime TradeLogPositionEntryTime(const ulong position_id)
{
   if(position_id == 0 || !HistorySelectByPosition(position_id))
      return 0;
   datetime first_time = 0;
   const int total = HistoryDealsTotal();
   for(int i = 0; i < total; i++)
   {
      const ulong deal = HistoryDealGetTicket(i);
      if(deal == 0)
         continue;
      const ENUM_DEAL_ENTRY entry =
         (ENUM_DEAL_ENTRY)HistoryDealGetInteger(deal, DEAL_ENTRY);
      if(entry != DEAL_ENTRY_IN && entry != DEAL_ENTRY_INOUT)
         continue;
      const datetime deal_time =
         (datetime)HistoryDealGetInteger(deal, DEAL_TIME);
      if(first_time == 0 || deal_time < first_time)
         first_time = deal_time;
   }
   return first_time;
}

//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| v2.96 Unified event CSV                                          |
//| Transitional parallel log: existing specialized CSVs are kept    |
//| for one validation version.                                      |
//+------------------------------------------------------------------+

bool DataExportTesterKeepStrategyDecisionStage(const string stage)
{
   if(!DataExportIsTester()) return true;
   if(StringFind(stage,"INTEGRATED_")==0) return true;

   // Keep only decisions that change/confirm the strategy lifecycle.
   if(stage=="FINAL_CONFIRMED" || stage=="FINAL_BLOCKED") return true;
   if(stage=="POST_THIRD_DIRECTION_CONFIRM" || stage=="THREE_SIGNAL_GATE") return true;
   if(stage=="ENTRY_PERMISSION" || stage=="TREND_ENTRY_PERMISSION") return true;
   if(stage=="ORDER_GATE" || stage=="ORDER_RESULT") return true;
   if(stage=="ADD_ENTRY_DECISION" || stage=="ADD_ENTRY_ORDER_RESULT") return true;
   if(StringFind(stage,"LIFECYCLE_")==0) return true;
   return false;
}

bool DataExportTesterKeepOrderAuditStage(const string stage)
{
   if(!DataExportIsTester()) return true;

   // v7.62 trace completeness: every stage that reaches the unified order
   // audit is part of the reproducible Signal->Order->Position lifecycle.
   // Repeated identical diagnostics are still suppressed separately.
   return true;
}

bool DataExportTesterKeepUnifiedEventType(const string record_type)
{
   if(!DataExportIsTester()) return true;

   // SIGNAL is fully represented by SignalBarAudit/StrategyTest Slim.
   // ORDER is fully represented by UnifiedOrderSignalAudit Slim.
   // WATCH is represented by SignalBarAudit Assist columns.
   return (record_type=="LIFECYCLE" ||
           record_type=="POSITION" ||
           record_type=="RISK" ||
           record_type=="AUTO");
}


// Canonical integrated CSV event context.
bool     g_test_csv_lifecycle_active = false;
string   g_test_csv_event_type = "";
string   g_test_csv_previous_state = "";
string   g_test_csv_current_state = "";
string   g_test_csv_event_reason = "";
string   g_test_csv_source_event_id = "";
ulong    g_test_csv_position_id = 0;
double   g_test_csv_event_price = 0.0;
double   g_test_csv_event_volume = 0.0;
double   g_test_csv_event_profit = 0.0;
datetime g_test_csv_event_time = 0;

void DataExportWriteUnifiedEvent(const string record_type,
                                 const string event_name,
                                 const int side,
                                 const ulong position_id,
                                 const double price,
                                 const double volume,
                                 const int score,
                                 const string decision,
                                 const string reason,
                                 const string source_event_id,
                                 const double value1,
                                 const double value2,
                                 const string detail,
                                 const datetime event_time=0)
{
   if(!g_integrated_csv_mode || g_integrated_csv_event_guard)
      return;

   const bool saved_active = g_test_csv_lifecycle_active;
   const string saved_type = g_test_csv_event_type;
   const string saved_prev = g_test_csv_previous_state;
   const string saved_current = g_test_csv_current_state;
   const string saved_reason = g_test_csv_event_reason;
   const string saved_source_event_id = g_test_csv_source_event_id;
   const ulong saved_position = g_test_csv_position_id;
   const double saved_price = g_test_csv_event_price;
   const double saved_volume = g_test_csv_event_volume;
   const double saved_profit = g_test_csv_event_profit;
   const datetime saved_time = g_test_csv_event_time;

   g_integrated_csv_event_guard = true;
   g_test_csv_lifecycle_active = true;
   g_test_csv_event_type = record_type + ":" + event_name;
   g_test_csv_previous_state = "";
   g_test_csv_current_state = decision;
   g_test_csv_event_reason = reason;
   g_test_csv_source_event_id = source_event_id;
   g_test_csv_position_id = position_id;
   g_test_csv_event_price = price;
   g_test_csv_event_volume = volume;
   g_test_csv_event_profit = value1;
   g_test_csv_event_time = event_time > 0 ? event_time : TimeCurrent();

   string integrated_reason = reason;
   if(source_event_id != "")
      integrated_reason += (integrated_reason=="" ? "" : " | ") + "SOURCE=" + source_event_id;
   if(detail != "")
      integrated_reason += (integrated_reason=="" ? "" : " | ") + detail;
   if(value2 != 0.0)
      integrated_reason += (integrated_reason=="" ? "" : " | ") + StringFormat("VALUE2=%.8f",value2);

   WriteSignalDecisionLog(side,
      "INTEGRATED_" + record_type + "_" + event_name,
      0, score, decision, integrated_reason,
      StringFind(detail,"ORDER_REQ=YES")>=0,
      StringFind(detail,"ORDER_RESULT=YES")>=0, 0, value1);

   g_test_csv_lifecycle_active = saved_active;
   g_test_csv_event_type = saved_type;
   g_test_csv_previous_state = saved_prev;
   g_test_csv_current_state = saved_current;
   g_test_csv_event_reason = saved_reason;
   g_test_csv_source_event_id = saved_source_event_id;
   g_test_csv_position_id = saved_position;
   g_test_csv_event_price = saved_price;
   g_test_csv_event_volume = saved_volume;
   g_test_csv_event_profit = saved_profit;
   g_test_csv_event_time = saved_time;
   g_integrated_csv_event_guard = false;
}

void WriteMinimalOrderFailureLog(const string failure_stage)
{
   if(g_integrated_csv_mode)
   {
      DataExportWriteUnifiedEvent("ORDER","ORDER_FAILURE",ManagedPositionSide(),0,
         trade.RequestPrice(),trade.RequestVolume(),0,"FAILED",failure_stage,"",
         (double)trade.ResultRetcode(),0.0,trade.ResultRetcodeDescription(),TimeCurrent());
      return;
   }

   if(DataExportIsTester()) return;
   if(!InpEnableAutoTradeLog)
      return;

   MqlDateTime now;
   TimeToStruct(TimeCurrent(), now);
   string symbol_token = _Symbol;
   StringReplace(symbol_token, "\\", "_");
   StringReplace(symbol_token, "/", "_");
   StringReplace(symbol_token, ":", "_");

   const string file_name = DataExportPath(StringFormat(
      "JTA_OrderFailure_%s_%I64u_%04d%02d%02d.csv",
      symbol_token, InpMagicNumber, now.year, now.mon, now.day));

   const int handle = FileOpen(file_name,
      DataExportFileFlags(FILE_READ|FILE_WRITE|FILE_CSV|FILE_ANSI|FILE_SHARE_READ|FILE_SHARE_WRITE),
      ',', CP_UTF8);
   if(handle == INVALID_HANDLE)
      return;

   if(FileSize(handle) == 0)
      {
         string csv_header = "";
         DataExportAddContextHeader(csv_header);
         DataExportCsvAdd(csv_header, "time_server");
         DataExportCsvAdd(csv_header, "symbol");
         DataExportCsvAdd(csv_header, "strategy");
         DataExportCsvAdd(csv_header, "stage");
         DataExportCsvAdd(csv_header, "order_type");
         DataExportCsvAdd(csv_header, "volume");
         DataExportCsvAdd(csv_header, "request_price");
         DataExportCsvAdd(csv_header, "request_sl");
         DataExportCsvAdd(csv_header, "retcode");
         DataExportCsvAdd(csv_header, "error");
         FileWriteString(handle, csv_header + "\r\n");
      }

   FileSeek(handle, 0, SEEK_END);
   {
      string csv_row = "";
      DataExportAddContextRow(csv_row);
      DataExportCsvAdd(csv_row, (string)(TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS)));
      DataExportCsvAdd(csv_row, (string)(_Symbol));
      DataExportCsvAdd(csv_row, (string)(TradeLogStrategyName()));
      DataExportCsvAdd(csv_row, (string)(failure_stage));
      DataExportCsvAdd(csv_row, (string)(EnumToString(trade.RequestType())));
      DataExportCsvAdd(csv_row, (string)(DoubleToString(trade.RequestVolume(), 8)));
      DataExportCsvAdd(csv_row, (string)(DoubleToString(trade.RequestPrice(), _Digits)));
      DataExportCsvAdd(csv_row, (string)(DoubleToString(trade.RequestSL(), _Digits)));
      DataExportCsvAdd(csv_row, (string)((long)trade.ResultRetcode()));
      DataExportCsvAdd(csv_row, (string)(trade.ResultRetcodeDescription()));
      FileWriteString(handle, csv_row + "\r\n");
   }
   FileClose(handle);
}

//+------------------------------------------------------------------+
void WriteMinimalPositionSummary(const ulong position_id,
                                 const string exit_reason)
{
   if(g_integrated_csv_mode)
      return;

   if(DataExportIsTester()) return;
   if(!InpEnableAutoTradeLog || position_id == 0 ||
      !HistorySelectByPosition(position_id))
      return;

   datetime entry_time = 0;
   datetime exit_time = 0;
   string side = "";
   double entry_volume = 0.0;
   double entry_value = 0.0;
   double exit_volume = 0.0;
   double exit_value = 0.0;
   double gross_profit = 0.0;
   double total_commission = 0.0;
   double total_swap = 0.0;
   double total_fee = 0.0;
   double total_net = 0.0;
   int entry_count = 0;
   int exit_count = 0;

   const int total = HistoryDealsTotal();
   for(int i = 0; i < total; i++)
   {
      const ulong deal = HistoryDealGetTicket(i);
      if(deal == 0)
         continue;

      const ENUM_DEAL_ENTRY deal_entry =
         (ENUM_DEAL_ENTRY)HistoryDealGetInteger(deal, DEAL_ENTRY);
      const ENUM_DEAL_TYPE deal_type =
         (ENUM_DEAL_TYPE)HistoryDealGetInteger(deal, DEAL_TYPE);
      const datetime deal_time =
         (datetime)HistoryDealGetInteger(deal, DEAL_TIME);

      const double deal_profit = HistoryDealGetDouble(deal, DEAL_PROFIT);
      const double deal_commission = HistoryDealGetDouble(deal, DEAL_COMMISSION);
      const double deal_swap = HistoryDealGetDouble(deal, DEAL_SWAP);
      const double deal_fee = HistoryDealGetDouble(deal, DEAL_FEE);
      gross_profit += deal_profit;
      total_commission += deal_commission;
      total_swap += deal_swap;
      total_fee += deal_fee;
      total_net += deal_profit + deal_commission + deal_swap + deal_fee;

      if(deal_entry == DEAL_ENTRY_IN || deal_entry == DEAL_ENTRY_INOUT)
      {
         entry_count++;
         const double deal_volume = HistoryDealGetDouble(deal, DEAL_VOLUME);
         entry_volume += deal_volume;
         entry_value += deal_volume * HistoryDealGetDouble(deal, DEAL_PRICE);
         if(entry_time == 0 || deal_time < entry_time)
            entry_time = deal_time;
         if(side == "")
            side = deal_type == DEAL_TYPE_BUY ? "LONG" : "SHORT";
      }
      if(deal_entry == DEAL_ENTRY_OUT || deal_entry == DEAL_ENTRY_OUT_BY ||
         deal_entry == DEAL_ENTRY_INOUT)
      {
         exit_count++;
         const double deal_volume = HistoryDealGetDouble(deal, DEAL_VOLUME);
         exit_volume += deal_volume;
         exit_value += deal_volume * HistoryDealGetDouble(deal, DEAL_PRICE);
         if(deal_time > exit_time)
            exit_time = deal_time;
      }
   }

   MqlDateTime now;
   TimeToStruct(TimeCurrent(), now);
   const string file_name = DataExportPath(StringFormat(
      "JTA_PositionSummary_%s_%I64u_%04d%02d%02d.csv",
      TradeLogSafeFileToken(_Symbol), InpMagicNumber,
      now.year, now.mon, now.day));

   const int handle = FileOpen(file_name,
      DataExportFileFlags(FILE_READ|FILE_WRITE|FILE_CSV|FILE_ANSI|FILE_SHARE_READ|FILE_SHARE_WRITE),
      ',', CP_UTF8);
   if(handle == INVALID_HANDLE)
      return;

   if(FileSize(handle) == 0)
      FileWrite(handle, "environment", "test_from", "test_to", "run_id", "tester_model",
                "position_id", "signal_id", "symbol", "strategy", "side",
                "entry_time", "exit_time", "holding_seconds", "entry_count",
                "exit_count", "entry_volume", "exit_volume", "average_entry",
                "average_exit", "gross_profit", "commission", "swap", "fee",
                "net_profit", "result", "exit_reason", "session", "weekday");

   FileSeek(handle, 0, SEEK_END);
   FileWrite(handle,
      DataExportEnvironment(), DataExportTestFrom(), DataExportTestTo(),
      DataExportRunId(), DataExportTesterModelName(),
      position_id,
      DataExportSignalId(entry_time, side == "LONG" ? 1 : -1, position_id),
      _Symbol,
      TradeLogStrategyName(),
      side,
      TimeToString(entry_time, TIME_DATE|TIME_SECONDS),
      TimeToString(exit_time, TIME_DATE|TIME_SECONDS),
      (entry_time > 0 && exit_time >= entry_time) ? (long)(exit_time-entry_time) : 0,
      entry_count,
      exit_count,
      DoubleToString(entry_volume, 8),
      DoubleToString(exit_volume, 8),
      DoubleToString(entry_volume > 0.0 ? entry_value/entry_volume : 0.0, _Digits),
      DoubleToString(exit_volume > 0.0 ? exit_value/exit_volume : 0.0, _Digits),
      DoubleToString(gross_profit, 2),
      DoubleToString(total_commission, 2),
      DoubleToString(total_swap, 2),
      DoubleToString(total_fee, 2),
      DoubleToString(total_net, 2),
      TradeLogResultName(total_net),
      exit_reason,
      DataExportSessionName(entry_time),
      DataExportWeekdayName(entry_time));

   DataExportWriteUnifiedEvent("POSITION","CLOSE_SUMMARY",
      side=="LONG" ? 1 : (side=="SHORT" ? -1 : 0),
      position_id,
      exit_volume>0.0 ? exit_value/exit_volume : 0.0,
      exit_volume,0,TradeLogResultName(total_net),exit_reason,"",
      total_net,gross_profit,
      StringFormat("AVG_ENTRY=%.8f COMM=%.2f SWAP=%.2f FEE=%.2f",
         entry_volume>0.0 ? entry_value/entry_volume : 0.0,
         total_commission,total_swap,total_fee),
      exit_time);
   if(g_integrated_csv_mode) return;
   FileClose(handle);
}

//+------------------------------------------------------------------+
string DataExportHoldStateName()
{
   switch(g_hold_state)
   {
      case HOLD_STRONG:         return "STRONG";
      case HOLD_WARNING:        return "WARNING";
      case HOLD_EXIT_CANDIDATE: return "EXIT_CANDIDATE";
      case HOLD_PROFIT_PROTECT: return "PROFIT_PROTECT";
      case HOLD_NORMAL:         return "NORMAL";
      default:                  return "UNKNOWN";
   }
}

string DataExportProfitProtectionStateName()
{
   switch(g_profit_protection_state)
   {
      case PROFIT_PROTECTION_ARMED:   return "ARMED";
      case PROFIT_PROTECTION_STRONG:  return "STRONG";
      case PROFIT_PROTECTION_NORMAL:  return "NORMAL";
      case PROFIT_PROTECTION_WARNING: return "WARNING";
      case PROFIT_PROTECTION_EXIT:    return "EXIT";
      default:                        return "UNKNOWN";
   }
}

//+------------------------------------------------------------------+
string DataExportLifecycleFileName()
{
   MqlDateTime now;
   TimeToStruct(TimeCurrent(), now);
   return DataExportPath(StringFormat("JTA_Lifecycle_v7_65_%s_%I64u_%04d%02d%02d.csv",
      TradeLogSafeFileToken(_Symbol), InpMagicNumber,
      now.year, now.mon, now.day));
}

//+------------------------------------------------------------------+
void WriteLifecycleEvent(const string event_name,
                         const int side,
                         const string previous_state,
                         const string current_state,
                         const string reason,
                         const ulong position_id_value,
                         const double event_price,
                         const double event_volume,
                         const double event_profit,
                         const datetime event_time_value)
{

   DataExportWriteUnifiedEvent("LIFECYCLE",event_name,side,position_id_value,
      event_price,event_volume,0,current_state,reason,"",
      event_profit,0.0,previous_state+" -> "+current_state,event_time_value);
   if(g_integrated_csv_mode) return;

   if(DataExportIsTester())
   {
      g_test_csv_lifecycle_active = true;
      g_test_csv_event_type = event_name;
      g_test_csv_previous_state = previous_state;
      g_test_csv_current_state = current_state;
      g_test_csv_event_reason = reason;
      g_test_csv_position_id = position_id_value;
      g_test_csv_event_price = event_price;
      g_test_csv_event_volume = event_volume;
      g_test_csv_event_profit = event_profit;
      g_test_csv_event_time = event_time_value > 0 ? event_time_value : TimeCurrent();

      WriteSignalDecisionLog(side, "LIFECYCLE_" + event_name, 0, 0,
                             event_name, reason, false, false, 0, -1.0);

      g_test_csv_lifecycle_active = false;
      g_test_csv_event_type = "";
      g_test_csv_previous_state = "";
      g_test_csv_current_state = "";
      g_test_csv_event_reason = "";
      g_test_csv_position_id = 0;
      g_test_csv_event_price = 0.0;
      g_test_csv_event_volume = 0.0;
      g_test_csv_event_profit = 0.0;
      g_test_csv_event_time = 0;
      return;
   }
   DataExportEnsureFolder();
   const string file_name = DataExportLifecycleFileName();
   ResetLastError();
   int handle=INVALID_HANDLE;
   if(DataExportEnsureLiveBufferedHandle(
         file_name,g_live_lifecycle_handle,g_live_lifecycle_file))
      handle=g_live_lifecycle_handle;
   if(handle == INVALID_HANDLE)
   {
      PrintFormat("[JTA CSV] LIFECYCLE OPEN FAILED | file=%s | error=%d",
                  file_name, GetLastError());
      return;
   }

   if(FileSize(handle) == 0)
   {
      string header = "";
      DataExportAddContextHeader(header);
      DataExportCsvAdd(header, "time_server");
      DataExportCsvAdd(header, "event");
      DataExportCsvAdd(header, "symbol");
      DataExportCsvAdd(header, "magic");
      DataExportCsvAdd(header, "strategy");
      DataExportCsvAdd(header, "side");
      DataExportCsvAdd(header, "signal_id");
      DataExportCsvAdd(header, "position_id");
      DataExportCsvAdd(header, "cycle_id");
      DataExportCsvAdd(header, "cycle_state");
      DataExportCsvAdd(header, "cycle_side");
      DataExportCsvAdd(header, "cycle_entry_source_event_id");
      DataExportCsvAdd(header, "cycle_exit_source_event_id");
      DataExportCsvAdd(header, "entry_type");
      DataExportCsvAdd(header, "additional_entry_count");
      DataExportCsvAdd(header, "add_stage");
      DataExportCsvAdd(header, "add_signal_count");
      DataExportCsvAdd(header, "add_signal_required");
      DataExportCsvAdd(header, "add_attempted");
      DataExportCsvAdd(header, "add_result");
      DataExportCsvAdd(header, "add_block_reason");
      DataExportCsvAdd(header, "add_progress_r");
      DataExportCsvAdd(header, "add_fill_price");
      DataExportCsvAdd(header, "profit_protection_profile");
      DataExportCsvAdd(header, "initial_r_distance");
      DataExportCsvAdd(header, "current_profit_r");
      DataExportCsvAdd(header, "lock_trigger_r");
      DataExportCsvAdd(header, "lock_target_r");
      DataExportCsvAdd(header, "allowed_giveback_percent");
      DataExportCsvAdd(header, "protected_sl");
      DataExportCsvAdd(header, "previous_hold_state");
      DataExportCsvAdd(header, "current_hold_state");
      DataExportCsvAdd(header, "profit_protection_state");
      DataExportCsvAdd(header, "reason");
      DataExportCsvAdd(header, "event_price");
      DataExportCsvAdd(header, "event_volume");
      DataExportCsvAdd(header, "realized_profit");
      DataExportCsvAdd(header, "floating_profit");
      DataExportCsvAdd(header, "group_volume");
      DataExportCsvAdd(header, "average_entry");
      DataExportCsvAdd(header, "hold_seconds");
      DataExportCsvAdd(header, "hold_bars");
      DataExportCsvAdd(header, "long_score");
      DataExportCsvAdd(header, "short_score");
      DataExportCsvAdd(header, "score_gap");
      DataExportCsvAdd(header, "long_confidence");
      DataExportCsvAdd(header, "short_confidence");
      DataExportCsvAdd(header, "hold_score");
      DataExportCsvAdd(header, "strong_score");
      DataExportCsvAdd(header, "weakness_score");
      DataExportCsvAdd(header, "hold_weak_bars");
      DataExportCsvAdd(header, "hold_warning_bars");
      DataExportCsvAdd(header, "hold_exit_candidate_bars");
      DataExportCsvAdd(header, "highest_profit_r");
      DataExportCsvAdd(header, "ma7");
      DataExportCsvAdd(header, "ma22");
      DataExportCsvAdd(header, "ma70");
      DataExportCsvAdd(header, "ma111");
      DataExportCsvAdd(header, "ma200");
      DataExportCsvAdd(header, "macd");
      DataExportCsvAdd(header, "delta");
      DataExportCsvAdd(header, "bid");
      DataExportCsvAdd(header, "ask");
      DataExportCsvAdd(header, "spread_points");
      DataExportCsvAdd(header, "auto_enabled");
      DataExportCsvAdd(header, "signal_enabled");
      DataExportCsvAdd(header, "stage1_configured_r");
      DataExportCsvAdd(header, "stage1_net_positive_r");
      DataExportCsvAdd(header, "stage1_effective_r");
      DataExportCsvAdd(header, "stage1_entry_charge");
      DataExportCsvAdd(header, "stage1_negative_swap");
      DataExportCsvAdd(header, "stage1_estimated_exit_cost");
      DataExportCsvAdd(header, "stage1_one_r_money");
      DataExportCsvAdd(header, "profit_lock_attempted");
      DataExportCsvAdd(header, "profit_lock_requested_r");
      DataExportCsvAdd(header, "profit_lock_requested_sl");
      DataExportCsvAdd(header, "profit_lock_applied");
      DataExportCsvAdd(header, "profit_lock_applied_sl");
      DataExportCsvAdd(header, "profit_lock_retcode");
      DataExportCsvAdd(header, "profit_lock_block_reason");
      FileWriteString(handle, header + "\r\n");
   }

   const datetime event_time = event_time_value > 0 ? event_time_value : TimeCurrent();
   ulong position_id = position_id_value;
   int managed_side = ManagedPositionSide();
   int resolved_side = side != 0 ? side : managed_side;
   double group_volume = 0.0, average_entry = 0.0, group_sl = 0.0, group_tp = 0.0;
   datetime first_time = 0;
   int group_side = 0;
   if(ManagedGroupInfo(group_side, group_volume, average_entry,
                       group_sl, group_tp, first_time))
   {
      if(resolved_side == 0) resolved_side = group_side;
   }
   if(position_id == 0 && PositionSelect(_Symbol))
      position_id = (ulong)PositionGetInteger(POSITION_IDENTIFIER);

   double floating_profit = 0.0;
   if(PositionSelect(_Symbol) &&
      (ulong)PositionGetInteger(POSITION_MAGIC) == InpMagicNumber)
      floating_profit = PositionGetDouble(POSITION_PROFIT) +
                        PositionGetDouble(POSITION_SWAP);

   const datetime entry_time = first_time > 0 ? first_time : event_time;
   const int hold_seconds = first_time > 0 ? (int)MathMax(0, event_time-first_time) : 0;
   const int tf_seconds = MathMax(1, PeriodSeconds(g_calc_tf));
   const int hold_bars = hold_seconds / tf_seconds;
   // v4.07: preserve v4.05 Lifecycle column semantics exactly.
   // columns historically use the canonical AUTO_TF handles. Reuse the shared
   double ma7=0.0,ma22=0.0,macd=0.0,delta=0.0;
   const bool lifecycle_snapshot_compatible=
      EnsureMarketSnapshot(3) &&
      g_market_snapshot_tf==AUTO_TF;
   if(lifecycle_snapshot_compatible)
   {
      ma7=g_ms_fast_ma[1];
      ma22=g_ms_slow_ma[1];
      macd=g_ms_macd[1];
      delta=g_ms_delta[1];
   }
   else
   {
      ma7 = DataExportBufferValue(g_add_ma_handle, 0, 1);
      ma22 = DataExportBufferValue(g_slow_ma_handle, 0, 1);
      macd = DataExportBufferValue(g_macd_handle, JTC_MACD_BASE_BUFFER, 1);
      delta = DataExportBufferValue(g_delta_handle, 2, 1);
   }
   const double ma70 = DataExportBufferValue(g_ma70_handle, 0, 1);
   const double ma111 = DataExportBufferValue(g_ma111_handle, 0, 1);
   const double ma200 = DataExportBufferValue(g_ma200_handle, 0, 1);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const string protection_profile =
      (g_reentry_protection_active ? "REENTRY" :
       (g_has_add_entry ? "ADD_ENTRY" : "INITIAL"));

   double profile_trigger_r = InpProfitProtectTriggerR;
   double profile_lock_r = InpProfitLockStage1R;
   double profile_giveback = (g_hold_state == HOLD_STRONG ? InpStrongHoldGivebackUnder2R :
                              g_hold_state == HOLD_NORMAL ? InpNormalHoldGivebackPercent : InpProfitGivebackPercent);
   if(g_reentry_protection_active)
   {
      profile_trigger_r = InpChaseProtectTriggerR;
      profile_lock_r = g_highest_profit_r >= InpChaseProtectStage3R ? InpChaseLockStage3R :
                       g_highest_profit_r >= InpChaseProtectStage2R ? InpChaseLockStage2R : InpChaseLockStage1R;
      profile_giveback = g_hold_state == HOLD_NORMAL ? InpChaseNormalGivebackPercent :
                         InpChaseProtectGivebackPercent;
   }
   else if(g_has_add_entry)
   {
      profile_trigger_r = InpAddProtectTriggerR;
      profile_lock_r = g_highest_profit_r >= InpAddProtectStage3R ? InpAddLockStage3R :
                       g_highest_profit_r >= InpAddProtectStage2R ? InpAddLockStage2R : InpAddLockStage1R;
      profile_giveback = g_hold_state == HOLD_STRONG ? InpAddStrongGivebackPercent :
                         g_hold_state == HOLD_NORMAL ? InpAddNormalGivebackPercent : InpAddProtectGivebackPercent;
   }
   double current_average_for_r = 0.0;
   const double current_profit_r = ManagedPositionSide() != 0 ?
      CurrentGroupProgressR(ManagedPositionSide(), current_average_for_r) : 0.0;

   string row = "";
   DataExportAddContextRow(row);
   DataExportCsvAdd(row, TimeToString(event_time, TIME_DATE|TIME_SECONDS));
   DataExportCsvAdd(row, event_name);
   DataExportCsvAdd(row, _Symbol);
   DataExportCsvAdd(row, (string)InpMagicNumber);
   DataExportCsvAdd(row, TradeLogStrategyName());
   DataExportCsvAdd(row, resolved_side > 0 ? "LONG" : resolved_side < 0 ? "SHORT" : "NONE");
   DataExportCsvAdd(row, DataExportSignalId(entry_time, resolved_side, position_id));
   DataExportCsvAdd(row, (string)position_id);
   DataExportCsvAdd(row, (string)g_trade_cycle.cycle_id);
   DataExportCsvAdd(row, TradeCycleStateName(g_trade_cycle.state));
   DataExportCsvAdd(row, (string)g_trade_cycle.side);
   DataExportCsvAdd(row, g_trade_cycle.entry_source_event_id);
   DataExportCsvAdd(row, g_trade_cycle.exit_source_event_id);
   DataExportCsvAdd(row, TradeLogEntryTypeName());
   DataExportCsvAdd(row, (string)g_additional_entry_count);
   DataExportCsvAdd(row, (string)g_csv_add_stage);
   DataExportCsvAdd(row, (string)g_csv_add_signal_count);
   DataExportCsvAdd(row, (string)g_csv_add_signal_required);
   DataExportCsvAdd(row, g_csv_add_attempted ? "YES" : "NO");
   DataExportCsvAdd(row, g_csv_add_result ? "SUCCESS" : "NO");
   DataExportCsvAdd(row, g_csv_add_block_reason);
   DataExportCsvAdd(row, DoubleToString(g_csv_add_progress_r, 4));
   DataExportCsvAdd(row, DoubleToString(g_csv_add_fill_price, _Digits));
   DataExportCsvAdd(row, protection_profile);
   DataExportCsvAdd(row, DoubleToString(g_initial_r_distance, _Digits));
   DataExportCsvAdd(row, DoubleToString(current_profit_r, 4));
   DataExportCsvAdd(row, DoubleToString(profile_trigger_r, 4));
   DataExportCsvAdd(row, DoubleToString(profile_lock_r, 4));
   DataExportCsvAdd(row, DoubleToString(profile_giveback, 2));
   DataExportCsvAdd(row, DoubleToString(g_protected_sl, _Digits));
   DataExportCsvAdd(row, previous_state);
   DataExportCsvAdd(row, current_state);
   DataExportCsvAdd(row, DataExportProfitProtectionStateName());
   DataExportCsvAdd(row, reason);
   DataExportCsvAdd(row, DoubleToString(event_price, _Digits));
   DataExportCsvAdd(row, DoubleToString(event_volume, 8));
   DataExportCsvAdd(row, DoubleToString(event_profit, 2));
   DataExportCsvAdd(row, DoubleToString(floating_profit, 2));
   DataExportCsvAdd(row, DoubleToString(group_volume, 8));
   DataExportCsvAdd(row, DoubleToString(average_entry, _Digits));
   DataExportCsvAdd(row, (string)hold_seconds);
   DataExportCsvAdd(row, (string)hold_bars);
   DataExportCsvAdd(row, (string)g_last_long_score);
   DataExportCsvAdd(row, (string)g_last_short_score);
   DataExportCsvAdd(row, (string)MathAbs(g_last_long_score-g_last_short_score));
   DataExportCsvAdd(row, (string)g_last_long_confidence);
   DataExportCsvAdd(row, (string)g_last_short_confidence);
   DataExportCsvAdd(row, (string)g_hold_direction_score);
   DataExportCsvAdd(row, (string)g_hold_strong_score);
   DataExportCsvAdd(row, (string)g_hold_weakness_score);
   DataExportCsvAdd(row, (string)g_hold_weak_bars);
   DataExportCsvAdd(row, (string)g_hold_warning_bars);
   DataExportCsvAdd(row, (string)g_hold_exit_candidate_bars);
   DataExportCsvAdd(row, DoubleToString(g_highest_profit_r, 4));
   DataExportCsvAdd(row, DoubleToString(ma7, _Digits));
   DataExportCsvAdd(row, DoubleToString(ma22, _Digits));
   DataExportCsvAdd(row, DoubleToString(ma70, _Digits));
   DataExportCsvAdd(row, DoubleToString(ma111, _Digits));
   DataExportCsvAdd(row, DoubleToString(ma200, _Digits));
   DataExportCsvAdd(row, DoubleToString(macd, 8));
   DataExportCsvAdd(row, DoubleToString(delta, 8));
   DataExportCsvAdd(row, DoubleToString(bid, _Digits));
   DataExportCsvAdd(row, DoubleToString(ask, _Digits));
   DataExportCsvAdd(row, (string)((long)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD)));
   DataExportCsvAdd(row, g_auto_trading ? "YES" : "NO");
   DataExportCsvAdd(row, g_signal_enabled ? "YES" : "NO");
   DataExportCsvAdd(row, DoubleToString(g_csv_stage1_configured_r,6));
   DataExportCsvAdd(row, DoubleToString(g_csv_stage1_net_positive_r,6));
   DataExportCsvAdd(row, DoubleToString(g_csv_stage1_effective_r,6));
   DataExportCsvAdd(row, DoubleToString(g_csv_stage1_entry_charge,2));
   DataExportCsvAdd(row, DoubleToString(g_csv_stage1_negative_swap,2));
   DataExportCsvAdd(row, DoubleToString(g_csv_stage1_estimated_exit_cost,2));
   DataExportCsvAdd(row, DoubleToString(g_csv_stage1_one_r_money,2));
   DataExportCsvAdd(row, g_csv_profit_lock_attempted ? "YES" : "NO");
   DataExportCsvAdd(row, DoubleToString(g_csv_profit_lock_requested_r,6));
   DataExportCsvAdd(row, DoubleToString(g_csv_profit_lock_requested_sl,_Digits));
   DataExportCsvAdd(row, g_csv_profit_lock_applied ? "YES" : "NO");
   DataExportCsvAdd(row, DoubleToString(g_csv_profit_lock_applied_sl,_Digits));
   DataExportCsvAdd(row, (string)g_csv_profit_lock_retcode);
   DataExportCsvAdd(row, g_csv_profit_lock_block_reason);

   FileSeek(handle, 0, SEEK_END);
   FileWriteString(handle, row + "\r\n");
   g_live_lifecycle_dirty=true;
   // v4.07: Lifecycle is a critical trade record. Keep the persistent handle
   // but flush immediately so fill/close/SL state survives an abrupt terminal stop.
   DataExportFlushLiveHandleNow(g_live_lifecycle_handle,
      g_live_lifecycle_dirty,g_live_lifecycle_flush_msc);
}

//+------------------------------------------------------------------+
double DataExportBufferValue(const int handle,
                             const int buffer_index,
                             const int shift)
{
   if(handle == INVALID_HANDLE)
      return 0.0;
   double value[1];
   if(MarketDataCopyBuffer(handle, buffer_index, shift, 1, value) < 1)
      return 0.0;
   return value[0];
}

//+------------------------------------------------------------------+
string DataExportSlopeName(const double current_value,
                           const double previous_value)
{
   const double epsilon = MathMax(MathAbs(previous_value) * 0.000001, 0.00000001);
   if(current_value > previous_value + epsilon) return "RISING";
   if(current_value < previous_value - epsilon) return "FALLING";
   return "FLAT";
}

//+------------------------------------------------------------------+
bool DataExportPositionIdentifierOpen(const ulong position_id)
{
   if(position_id == 0) return false;
   const int total = PositionsTotal();
   for(int i=0; i<total; i++)
   {
      const ulong ticket=PositionGetTicket(i);
      if(ticket==0 || !PositionSelectByTicket(ticket)) continue;
      if((ulong)PositionGetInteger(POSITION_IDENTIFIER)==position_id) return true;
   }
   return false;
}

//+------------------------------------------------------------------+
void DataExportPositionHistoryStats(const ulong position_id,
                                    double &average_entry,
                                    double &entry_volume,
                                    int &entry_count,
                                    double &cumulative_net)
{
   average_entry = 0.0;
   entry_volume = 0.0;
   entry_count = 0;
   cumulative_net = 0.0;
   if(position_id == 0 || !HistorySelectByPosition(position_id))
      return;

   double entry_value = 0.0;
   const int total = HistoryDealsTotal();
   for(int i = 0; i < total; i++)
   {
      const ulong deal = HistoryDealGetTicket(i);
      if(deal == 0) continue;
      const ENUM_DEAL_ENTRY entry =
         (ENUM_DEAL_ENTRY)HistoryDealGetInteger(deal, DEAL_ENTRY);
      cumulative_net += HistoryDealGetDouble(deal, DEAL_PROFIT) +
                        HistoryDealGetDouble(deal, DEAL_COMMISSION) +
                        HistoryDealGetDouble(deal, DEAL_SWAP) +
                        HistoryDealGetDouble(deal, DEAL_FEE);
      if(entry == DEAL_ENTRY_IN || entry == DEAL_ENTRY_INOUT)
      {
         const double deal_volume = HistoryDealGetDouble(deal, DEAL_VOLUME);
         entry_volume += deal_volume;
         entry_value += deal_volume * HistoryDealGetDouble(deal, DEAL_PRICE);
         entry_count++;
      }
   }
   if(entry_volume > 0.0)
      average_entry = entry_value / entry_volume;
}

//+------------------------------------------------------------------+
void WriteAutoTradeLogDeal(const ulong deal_ticket,
                           const string event_name,
                           const string action_reason)
{
   if(DataExportIsTester()) return;
   if(!InpEnableAutoTradeLog || deal_ticket == 0 ||
      !HistoryDealSelect(deal_ticket))
      return;

   const datetime deal_time =
      (datetime)HistoryDealGetInteger(deal_ticket, DEAL_TIME);
   const long deal_time_msc =
      (long)HistoryDealGetInteger(deal_ticket, DEAL_TIME_MSC);
   const ENUM_DEAL_ENTRY deal_entry =
      (ENUM_DEAL_ENTRY)HistoryDealGetInteger(deal_ticket, DEAL_ENTRY);
   const ENUM_DEAL_TYPE deal_type =
      (ENUM_DEAL_TYPE)HistoryDealGetInteger(deal_ticket, DEAL_TYPE);
   const ENUM_DEAL_REASON deal_reason =
      (ENUM_DEAL_REASON)HistoryDealGetInteger(deal_ticket, DEAL_REASON);
   const ulong order_ticket =
      (ulong)HistoryDealGetInteger(deal_ticket, DEAL_ORDER);
   const ulong position_id =
      (ulong)HistoryDealGetInteger(deal_ticket, DEAL_POSITION_ID);
   const double volume = HistoryDealGetDouble(deal_ticket, DEAL_VOLUME);
   const double price = HistoryDealGetDouble(deal_ticket, DEAL_PRICE);
   const double profit = HistoryDealGetDouble(deal_ticket, DEAL_PROFIT);
   const double commission = HistoryDealGetDouble(deal_ticket, DEAL_COMMISSION);
   const double swap = HistoryDealGetDouble(deal_ticket, DEAL_SWAP);
   const double fee = HistoryDealGetDouble(deal_ticket, DEAL_FEE);
   const double net_profit = profit + commission + swap + fee;
   const string deal_comment =
      HistoryDealGetString(deal_ticket, DEAL_COMMENT);

   if(g_integrated_csv_mode)
   {
      const int integrated_side =
         (deal_entry == DEAL_ENTRY_IN || deal_entry == DEAL_ENTRY_INOUT) ?
         (deal_type == DEAL_TYPE_BUY ? 1 : -1) :
         (deal_type == DEAL_TYPE_SELL ? 1 : -1);
      DataExportWriteUnifiedEvent("POSITION",event_name,integrated_side,position_id,
         price,volume,0,"FILLED",action_reason,"DEAL="+(string)deal_ticket,
         net_profit,commission,
         StringFormat("ORDER=%I64u COMMENT=%s",order_ticket,deal_comment),deal_time);
      return;
   }

   string side = "";
   if(deal_entry == DEAL_ENTRY_IN || deal_entry == DEAL_ENTRY_INOUT)
      side = deal_type == DEAL_TYPE_BUY ? "LONG" : "SHORT";
   else
      side = deal_type == DEAL_TYPE_SELL ? "LONG" : "SHORT";

   const datetime first_time = TradeLogPositionEntryTime(position_id);
   const long hold_seconds =
      first_time > 0 && deal_time >= first_time ?
      (long)(deal_time - first_time) : 0;

   const string file_name = TradeLogFileName();
   ResetLastError();
   const int handle = FileOpen(file_name,
      DataExportFileFlags(FILE_READ|FILE_WRITE|FILE_CSV|FILE_ANSI|FILE_SHARE_READ|FILE_SHARE_WRITE),
      ',', CP_UTF8);
   if(handle == INVALID_HANDLE)
   {
      Print("AUTO TRADE LOG OPEN FAILED: ", file_name,
            " | Error=", GetLastError());
      return;
   }

   if(FileSize(handle) == 0)
   {
      {
         string csv_header = "";
         DataExportAddContextHeader(csv_header);
         DataExportCsvAdd(csv_header, "time_server");
         DataExportCsvAdd(csv_header, "time_msc");
         DataExportCsvAdd(csv_header, "event");
         DataExportCsvAdd(csv_header, "result");
         DataExportCsvAdd(csv_header, "symbol");
         DataExportCsvAdd(csv_header, "strategy");
         DataExportCsvAdd(csv_header, "side");
         DataExportCsvAdd(csv_header, "volume");
         DataExportCsvAdd(csv_header, "deal_price");
         DataExportCsvAdd(csv_header, "profit");
         DataExportCsvAdd(csv_header, "commission");
         DataExportCsvAdd(csv_header, "swap");
         DataExportCsvAdd(csv_header, "fee");
         DataExportCsvAdd(csv_header, "deal_net_profit");
         DataExportCsvAdd(csv_header, "position_cumulative_net");
         DataExportCsvAdd(csv_header, "hold_seconds");
         DataExportCsvAdd(csv_header, "hold_bars");
         DataExportCsvAdd(csv_header, "deal");
         DataExportCsvAdd(csv_header, "order");
         DataExportCsvAdd(csv_header, "position_id");
         DataExportCsvAdd(csv_header, "deal_entry");
         DataExportCsvAdd(csv_header, "deal_reason");
         DataExportCsvAdd(csv_header, "signal_id");
         DataExportCsvAdd(csv_header, "action_reason");
         DataExportCsvAdd(csv_header, "deal_comment");
         DataExportCsvAdd(csv_header, "entry_type");
         DataExportCsvAdd(csv_header, "entry_quality");
         DataExportCsvAdd(csv_header, "entry_confidence");
         DataExportCsvAdd(csv_header, "entry_signal_count");
         DataExportCsvAdd(csv_header, "profit_lock_mode");
         DataExportCsvAdd(csv_header, "confidence");
         DataExportCsvAdd(csv_header, "confidence_level");
         DataExportCsvAdd(csv_header, "long_score");
         DataExportCsvAdd(csv_header, "short_score");
         DataExportCsvAdd(csv_header, "score_gap");
         DataExportCsvAdd(csv_header, "hold_state");
         DataExportCsvAdd(csv_header, "profit_protection_state");
         DataExportCsvAdd(csv_header, "hold_score");
         DataExportCsvAdd(csv_header, "strong_score");
         DataExportCsvAdd(csv_header, "weakness_score");
         DataExportCsvAdd(csv_header, "hold_weak_bars");
         DataExportCsvAdd(csv_header, "hold_warning_bars");
         DataExportCsvAdd(csv_header, "hold_exit_candidate_bars");
         DataExportCsvAdd(csv_header, "strong_hold_active");
         DataExportCsvAdd(csv_header, "add_count");
         DataExportCsvAdd(csv_header, "entry_count");
         DataExportCsvAdd(csv_header, "entry_volume");
         DataExportCsvAdd(csv_header, "average_entry");
         DataExportCsvAdd(csv_header, "current_group_volume");
         DataExportCsvAdd(csv_header, "floating_profit_after_deal");
         DataExportCsvAdd(csv_header, "highest_profit_r");
         DataExportCsvAdd(csv_header, "profit_guard_peak_percent");
         DataExportCsvAdd(csv_header, "profit_guard_activated");
         DataExportCsvAdd(csv_header, "bid");
         DataExportCsvAdd(csv_header, "ask");
         DataExportCsvAdd(csv_header, "spread_points");
         DataExportCsvAdd(csv_header, "bar0_open");
         DataExportCsvAdd(csv_header, "bar0_high");
         DataExportCsvAdd(csv_header, "bar0_low");
         DataExportCsvAdd(csv_header, "bar0_close");
         DataExportCsvAdd(csv_header, "bar1_open");
         DataExportCsvAdd(csv_header, "bar1_high");
         DataExportCsvAdd(csv_header, "bar1_low");
         DataExportCsvAdd(csv_header, "bar1_close");
         DataExportCsvAdd(csv_header, "ma7_0");
         DataExportCsvAdd(csv_header, "ma7_1");
         DataExportCsvAdd(csv_header, "ma7_slope");
         DataExportCsvAdd(csv_header, "ma22_0");
         DataExportCsvAdd(csv_header, "ma22_1");
         DataExportCsvAdd(csv_header, "ma22_slope");
         DataExportCsvAdd(csv_header, "ma70_0");
         DataExportCsvAdd(csv_header, "ma111_0");
         DataExportCsvAdd(csv_header, "ma200_0");
         DataExportCsvAdd(csv_header, "price_above_ma7");
         DataExportCsvAdd(csv_header, "ma7_above_ma22");
         DataExportCsvAdd(csv_header, "macd_0");
         DataExportCsvAdd(csv_header, "macd_1");
         DataExportCsvAdd(csv_header, "macd_slope");
         DataExportCsvAdd(csv_header, "macd_zone");
         DataExportCsvAdd(csv_header, "delta_0");
         DataExportCsvAdd(csv_header, "delta_1");
         DataExportCsvAdd(csv_header, "delta_slope");
         DataExportCsvAdd(csv_header, "delta_zone");
         DataExportCsvAdd(csv_header, "session");
         DataExportCsvAdd(csv_header, "weekday");
         DataExportCsvAdd(csv_header, "auto_enabled");
         DataExportCsvAdd(csv_header, "signal_enabled");
         DataExportCsvAdd(csv_header, "mobile_alert");
         DataExportCsvAdd(csv_header, "signal_tf");
         DataExportCsvAdd(csv_header, "sl_percent");
         DataExportCsvAdd(csv_header, "current_sl");
         DataExportCsvAdd(csv_header, "current_tp");
         DataExportCsvAdd(csv_header, "magic");
         FileWriteString(handle, csv_header + "\r\n");
      }
   }
   FileSeek(handle, 0, SEEK_END);

   int group_side = 0;
   double group_volume = 0.0, group_average = 0.0;
   double current_sl = 0.0, current_tp = 0.0;
   datetime group_time = 0;
   ManagedGroupInfo(group_side, group_volume, group_average,
                    current_sl, current_tp, group_time);

   const bool opening_event =
      (event_name == "ENTRY" || event_name == "ADD_ENTRY" ||
       event_name == "REENTRY");

   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bar0_open = iOpen(_Symbol, AUTO_TF, 0);
   const double bar0_high = iHigh(_Symbol, AUTO_TF, 0);
   const double bar0_low = iLow(_Symbol, AUTO_TF, 0);
   const double bar0_close = iClose(_Symbol, AUTO_TF, 0);
   const double bar1_open = iOpen(_Symbol, AUTO_TF, 1);
   const double bar1_high = iHigh(_Symbol, AUTO_TF, 1);
   const double bar1_low = iLow(_Symbol, AUTO_TF, 1);
   const double bar1_close = iClose(_Symbol, AUTO_TF, 1);
   const double ma7_0 = DataExportBufferValue(g_add_ma_handle, 0, 0);
   const double ma7_1 = DataExportBufferValue(g_add_ma_handle, 0, 1);
   const double ma22_0 = DataExportBufferValue(g_slow_ma_handle, 0, 0);
   const double ma22_1 = DataExportBufferValue(g_slow_ma_handle, 0, 1);
   const double ma70_0 = DataExportBufferValue(g_ma70_handle, 0, 0);
   const double ma111_0 = DataExportBufferValue(g_ma111_handle, 0, 0);
   const double ma200_0 = DataExportBufferValue(g_ma200_handle, 0, 0);
   const double macd_0 = DataExportBufferValue(g_macd_handle, JTC_MACD_BASE_BUFFER, 0);
   const double macd_1 = DataExportBufferValue(g_macd_handle, JTC_MACD_BASE_BUFFER, 1);
   const double delta_0 = DataExportBufferValue(g_delta_handle, 2, 0);
   const double delta_1 = DataExportBufferValue(g_delta_handle, 2, 1);

   double average_entry = 0.0, entry_volume = 0.0, cumulative_net = 0.0;
   int entry_count = 0;
   DataExportPositionHistoryStats(position_id, average_entry, entry_volume,
                                  entry_count, cumulative_net);
   JRO_RefreshPositionSnapshot(_Symbol, InpMagicNumber);
   const double floating_after = g_jro_positions.floating_profit;
   const int hold_bars = first_time > 0 ? iBarShift(_Symbol, AUTO_TF, first_time, false) : 0;

   {
      string csv_row = "";
      DataExportAddContextRow(csv_row);
      DataExportCsvAdd(csv_row, (string)(TimeToString(deal_time, TIME_DATE|TIME_SECONDS)));
      DataExportCsvAdd(csv_row, (string)(deal_time_msc));
      DataExportCsvAdd(csv_row, (string)(event_name));
      DataExportCsvAdd(csv_row, (string)(opening_event ? "OPEN" : TradeLogResultName(net_profit)));
      DataExportCsvAdd(csv_row, (string)(_Symbol));
      DataExportCsvAdd(csv_row, (string)(TradeLogStrategyName()));
      DataExportCsvAdd(csv_row, (string)(side));
      DataExportCsvAdd(csv_row, (string)(DoubleToString(volume, 8)));
      DataExportCsvAdd(csv_row, (string)(DoubleToString(price, _Digits)));
      DataExportCsvAdd(csv_row, (string)(DoubleToString(profit, 2)));
      DataExportCsvAdd(csv_row, (string)(DoubleToString(commission, 2)));
      DataExportCsvAdd(csv_row, (string)(DoubleToString(swap, 2)));
      DataExportCsvAdd(csv_row, (string)(DoubleToString(fee, 2)));
      DataExportCsvAdd(csv_row, (string)(DoubleToString(net_profit, 2)));
      DataExportCsvAdd(csv_row, (string)(DoubleToString(cumulative_net, 2)));
      DataExportCsvAdd(csv_row, (string)(hold_seconds));
      DataExportCsvAdd(csv_row, (string)(hold_bars));
      DataExportCsvAdd(csv_row, (string)(deal_ticket));
      DataExportCsvAdd(csv_row, (string)(order_ticket));
      DataExportCsvAdd(csv_row, (string)(position_id));
      DataExportCsvAdd(csv_row, (string)(EnumToString(deal_entry)));
      DataExportCsvAdd(csv_row, (string)(EnumToString(deal_reason)));
      DataExportCsvAdd(csv_row, (string)(DataExportSignalId(first_time > 0 ? first_time : deal_time,
                         side == "LONG" ? 1 : -1, position_id)));
      DataExportCsvAdd(csv_row, (string)(action_reason));
      DataExportCsvAdd(csv_row, (string)(deal_comment));
      DataExportCsvAdd(csv_row, (string)(TradeLogEntryTypeName()));
      DataExportCsvAdd(csv_row, (string)(g_entry_quality));
      DataExportCsvAdd(csv_row, (string)(EntryConfidenceName(g_entry_confidence)));
      DataExportCsvAdd(csv_row, (string)(g_entry_signal_count_at_open));
      DataExportCsvAdd(csv_row, (string)(g_entry_confidence == ENTRY_CONFIDENCE_HIGH ? "NORMAL" : "CONSERVATIVE"));
      DataExportCsvAdd(csv_row, (string)(side == "LONG" ? g_last_long_confidence : g_last_short_confidence));
      DataExportCsvAdd(csv_row, (string)(DataExportConfidenceName(side == "LONG" ? g_last_long_confidence : g_last_short_confidence)));
      DataExportCsvAdd(csv_row, (string)(g_last_long_score));
      DataExportCsvAdd(csv_row, (string)(g_last_short_score));
      DataExportCsvAdd(csv_row, (string)(MathAbs(g_last_long_score-g_last_short_score)));
      DataExportCsvAdd(csv_row, (string)(DataExportHoldStateName()));
      DataExportCsvAdd(csv_row, (string)(DataExportProfitProtectionStateName()));
      DataExportCsvAdd(csv_row, (string)(g_hold_direction_score));
      DataExportCsvAdd(csv_row, (string)(g_hold_strong_score));
      DataExportCsvAdd(csv_row, (string)(g_hold_weakness_score));
      DataExportCsvAdd(csv_row, (string)(g_hold_weak_bars));
      DataExportCsvAdd(csv_row, (string)(g_hold_warning_bars));
      DataExportCsvAdd(csv_row, (string)(g_hold_exit_candidate_bars));
      DataExportCsvAdd(csv_row, (string)(g_strong_hold_active ? "YES" : "NO"));
      DataExportCsvAdd(csv_row, (string)(g_additional_entry_count));
      DataExportCsvAdd(csv_row, (string)(entry_count));
      DataExportCsvAdd(csv_row, (string)(DoubleToString(entry_volume, 8)));
      DataExportCsvAdd(csv_row, (string)(DoubleToString(average_entry, _Digits)));
      DataExportCsvAdd(csv_row, (string)(DoubleToString(group_volume, 8)));
      DataExportCsvAdd(csv_row, (string)(DoubleToString(floating_after, 2)));
      DataExportCsvAdd(csv_row, (string)(DoubleToString(g_highest_profit_r, 4)));
      DataExportCsvAdd(csv_row, (string)(DoubleToString(g_profit_guard_peak_percent, 4)));
      DataExportCsvAdd(csv_row, (string)(g_profit_guard_activated ? "YES" : "NO"));
      DataExportCsvAdd(csv_row, (string)(DoubleToString(bid, _Digits)));
      DataExportCsvAdd(csv_row, (string)(DoubleToString(ask, _Digits)));
      DataExportCsvAdd(csv_row, (string)((long)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD)));
      DataExportCsvAdd(csv_row, (string)(DoubleToString(bar0_open, _Digits)));
      DataExportCsvAdd(csv_row, (string)(DoubleToString(bar0_high, _Digits)));
      DataExportCsvAdd(csv_row, (string)(DoubleToString(bar0_low, _Digits)));
      DataExportCsvAdd(csv_row, (string)(DoubleToString(bar0_close, _Digits)));
      DataExportCsvAdd(csv_row, (string)(DoubleToString(bar1_open, _Digits)));
      DataExportCsvAdd(csv_row, (string)(DoubleToString(bar1_high, _Digits)));
      DataExportCsvAdd(csv_row, (string)(DoubleToString(bar1_low, _Digits)));
      DataExportCsvAdd(csv_row, (string)(DoubleToString(bar1_close, _Digits)));
      DataExportCsvAdd(csv_row, (string)(DoubleToString(ma7_0, _Digits)));
      DataExportCsvAdd(csv_row, (string)(DoubleToString(ma7_1, _Digits)));
      DataExportCsvAdd(csv_row, (string)(DataExportSlopeName(ma7_0, ma7_1)));
      DataExportCsvAdd(csv_row, (string)(DoubleToString(ma22_0, _Digits)));
      DataExportCsvAdd(csv_row, (string)(DoubleToString(ma22_1, _Digits)));
      DataExportCsvAdd(csv_row, (string)(DataExportSlopeName(ma22_0, ma22_1)));
      DataExportCsvAdd(csv_row, (string)(DoubleToString(ma70_0, _Digits)));
      DataExportCsvAdd(csv_row, (string)(DoubleToString(ma111_0, _Digits)));
      DataExportCsvAdd(csv_row, (string)(DoubleToString(ma200_0, _Digits)));
      DataExportCsvAdd(csv_row, (string)(bar0_close >= ma7_0 ? "YES" : "NO"));
      DataExportCsvAdd(csv_row, (string)(ma7_0 >= ma22_0 ? "YES" : "NO"));
      DataExportCsvAdd(csv_row, (string)(DoubleToString(macd_0, 8)));
      DataExportCsvAdd(csv_row, (string)(DoubleToString(macd_1, 8)));
      DataExportCsvAdd(csv_row, (string)(DataExportSlopeName(macd_0, macd_1)));
      DataExportCsvAdd(csv_row, (string)(macd_0 > 0.0 ? "POSITIVE" : (macd_0 < 0.0 ? "NEGATIVE" : "ZERO")));
      DataExportCsvAdd(csv_row, (string)(DoubleToString(delta_0, 8)));
      DataExportCsvAdd(csv_row, (string)(DoubleToString(delta_1, 8)));
      DataExportCsvAdd(csv_row, (string)(DataExportSlopeName(delta_0, delta_1)));
      DataExportCsvAdd(csv_row, (string)(delta_0 > 0.0 ? "POSITIVE" : (delta_0 < 0.0 ? "NEGATIVE" : "ZERO")));
      DataExportCsvAdd(csv_row, (string)(DataExportSessionName(deal_time)));
      DataExportCsvAdd(csv_row, (string)(DataExportWeekdayName(deal_time)));
      DataExportCsvAdd(csv_row, (string)(g_auto_trading ? "YES" : "NO"));
      DataExportCsvAdd(csv_row, (string)(g_signal_enabled ? "YES" : "NO"));
      DataExportCsvAdd(csv_row, (string)(g_mobile_alert ? "YES" : "NO"));
      DataExportCsvAdd(csv_row, (string)(EnumToString(g_signal_tf)));
      DataExportCsvAdd(csv_row, (string)(DoubleToString(g_stop_loss_percent, 4)));
      DataExportCsvAdd(csv_row, (string)(DoubleToString(current_sl, _Digits)));
      DataExportCsvAdd(csv_row, (string)(DoubleToString(current_tp, _Digits)));
      DataExportCsvAdd(csv_row, (string)(InpMagicNumber));
      FileWriteString(handle, csv_row + "\r\n");
   }
   FileClose(handle);
}


//+------------------------------------------------------------------+
string PatternDatasetFileName()
{
   MqlDateTime now;
   TimeToStruct(TimeCurrent(), now);
   return DataExportPath(StringFormat("JTA_PatternDataset_%s_%I64u_%04d%02d%02d.csv",
                       TradeLogSafeFileToken(_Symbol), InpMagicNumber,
                       now.year, now.mon, now.day));
}

//+------------------------------------------------------------------+
void ExportPatternLearningSample(const datetime bar_time,
                                 const ENUM_TIMEFRAMES timeframe,
                                 const double open_price,
                                 const double high_price,
                                 const double low_price,
                                 const double close_price,
                                 const double fast_ma,
                                 const double slow_ma,
                                 const double macd_value,
                                 const double delta_value,
                                 const int detected_side,
                                 const string pattern_name,
                                 const string source_tag)
{
   if(g_integrated_csv_mode)
   {
      DataExportWriteUnifiedEvent("DATASET","PATTERN_SAMPLE",detected_side,0,close_price,0.0,
         0,"OBSERVE",pattern_name,"",macd_value,delta_value,
         StringFormat("TF=%s SOURCE=%s O=%.8f H=%.8f L=%.8f",EnumToString(timeframe),source_tag,open_price,high_price,low_price),bar_time);
      return;
   }

   if(DataExportIsTester()) return;
   if(!InpEnablePatternDatasetExport || bar_time <= 0)
      return;

   const string file_name = PatternDatasetFileName();
   const int handle = FileOpen(file_name,
      DataExportFileFlags(FILE_READ|FILE_WRITE|FILE_CSV|FILE_ANSI|FILE_SHARE_READ|FILE_SHARE_WRITE),
      ',', CP_UTF8);
   if(handle == INVALID_HANDLE)
   {
      Print("PATTERN DATASET OPEN FAILED: ", file_name,
            " | Error=", GetLastError());
      return;
   }

   if(FileSize(handle) == 0)
      FileWrite(handle,
         "environment", "test_from", "test_to", "run_id", "tester_model",
         "time_server", "symbol", "timeframe", "open", "high", "low", "close",
         "body", "range", "body_ratio", "upper_wick", "lower_wick",
         "upper_wick_ratio", "lower_wick_ratio", "fast_ma", "slow_ma",
         "ma_gap", "ma_gap_points", "close_fast_distance",
         "close_slow_distance", "macd", "delta", "detected_side",
         "pattern", "source", "strategy", "long_score", "short_score",
         "long_confidence", "short_confidence", "session", "weekday",
         "spread_points", "auto_enabled", "magic");

   const double body = MathAbs(close_price - open_price);
   const double range = MathMax(high_price - low_price, _Point);
   const double upper_wick = high_price - MathMax(open_price, close_price);
   const double lower_wick = MathMin(open_price, close_price) - low_price;

   FileSeek(handle, 0, SEEK_END);
   FileWrite(handle,
      DataExportEnvironment(), DataExportTestFrom(), DataExportTestTo(),
      DataExportRunId(), DataExportTesterModelName(),
      TimeToString(bar_time, TIME_DATE|TIME_SECONDS),
      _Symbol,
      EnumToString(timeframe),
      DoubleToString(open_price, _Digits),
      DoubleToString(high_price, _Digits),
      DoubleToString(low_price, _Digits),
      DoubleToString(close_price, _Digits),
      DoubleToString(body, _Digits),
      DoubleToString(range, _Digits),
      DoubleToString(body/range, 6),
      DoubleToString(upper_wick, _Digits),
      DoubleToString(lower_wick, _Digits),
      DoubleToString(upper_wick/range, 6),
      DoubleToString(lower_wick/range, 6),
      DoubleToString(fast_ma, _Digits),
      DoubleToString(slow_ma, _Digits),
      DoubleToString(fast_ma-slow_ma, _Digits),
      DoubleToString((fast_ma-slow_ma)/_Point, 2),
      DoubleToString(close_price-fast_ma, _Digits),
      DoubleToString(close_price-slow_ma, _Digits),
      DoubleToString(macd_value, 8),
      DoubleToString(delta_value, 8),
      detected_side,
      pattern_name,
      source_tag,
      TradeLogStrategyName(),
      g_last_long_score,
      g_last_short_score,
      g_last_long_confidence,
      g_last_short_confidence,
      DataExportSessionName(bar_time),
      DataExportWeekdayName(bar_time),
      (long)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD),
      g_auto_trading ? "YES" : "NO",
      InpMagicNumber);
   FileClose(handle);
}


//+------------------------------------------------------------------+
string SignalDatasetFileName()
{
   MqlDateTime now;
   TimeToStruct(TimeCurrent(), now);
   return DataExportPath(StringFormat("JTA_SignalDataset_%s_%I64u_%04d%02d%02d.csv",
      TradeLogSafeFileToken(_Symbol), InpMagicNumber,
      now.year, now.mon, now.day));
}

//+------------------------------------------------------------------+
void ExportSignalLearningSample(const datetime bar_time,
                                const ENUM_TIMEFRAMES timeframe,
                                const double open_price,
                                const double high_price,
                                const double low_price,
                                const double close_price,
                                const double fast_ma,
                                const double slow_ma,
                                const double macd_value,
                                const double delta_value,
                                const int detected_side,
                                const string pattern_name,
                                const string source_tag)
{
   if(g_integrated_csv_mode)
   {
      DataExportWriteUnifiedEvent("DATASET","SIGNAL_SAMPLE",detected_side,0,close_price,0.0,
         0,"OBSERVE",pattern_name,source_tag,macd_value,delta_value,
         StringFormat("TF=%s O=%.8f H=%.8f L=%.8f FAST=%.8f SLOW=%.8f",EnumToString(timeframe),open_price,high_price,low_price,fast_ma,slow_ma),bar_time);
      return;
   }

   if(DataExportIsTester()) return;
   if(!InpEnableSignalDatasetExport || bar_time <= 0)
      return;

   const string file_name = SignalDatasetFileName();
   const int handle = FileOpen(file_name,
      DataExportFileFlags(FILE_READ|FILE_WRITE|FILE_CSV|FILE_ANSI|FILE_SHARE_READ|FILE_SHARE_WRITE),
      ',', CP_UTF8);
   if(handle == INVALID_HANDLE)
      return;

   if(FileSize(handle) == 0)
      FileWrite(handle,
         "environment", "test_from", "test_to", "run_id", "tester_model",
         "signal_id", "time_server", "symbol", "timeframe", "strategy",
         "selected_direction", "detected_pattern_side", "pattern", "source",
         "long_score", "short_score", "score_gap", "long_confidence",
         "short_confidence", "signal_score", "confidence_level",
         "entry_threshold", "strong_threshold", "open", "high", "low", "close",
         "fast_ma", "slow_ma", "ma_gap_points", "macd", "delta", "session",
         "weekday", "spread_points", "auto_enabled", "magic");

   int selected_side = 0;
   if(g_last_long_score >= InpChartSignalScore &&
      g_last_long_score >= g_last_short_score + InpChartSignalMinimumGap)
      selected_side = 1;
   else if(g_last_short_score >= InpChartSignalScore &&
           g_last_short_score >= g_last_long_score + InpChartSignalMinimumGap)
      selected_side = -1;

   const int selected_confidence = selected_side > 0 ? g_last_long_confidence :
                                   selected_side < 0 ? g_last_short_confidence :
                                   MathMax(g_last_long_confidence, g_last_short_confidence);
   const int signal_score = selected_side > 0 ? g_last_long_score :
                               selected_side < 0 ? g_last_short_score :
                               MathMax(g_last_long_score, g_last_short_score);

   FileSeek(handle, 0, SEEK_END);
   FileWrite(handle,
      DataExportEnvironment(), DataExportTestFrom(), DataExportTestTo(),
      DataExportRunId(), DataExportTesterModelName(),
      DataExportSignalId(bar_time, selected_side == 0 ? detected_side : selected_side, 0),
      TimeToString(bar_time, TIME_DATE|TIME_SECONDS),
      _Symbol,
      EnumToString(timeframe),
      TradeLogStrategyName(),
      selected_side,
      detected_side,
      pattern_name,
      source_tag,
      g_last_long_score,
      g_last_short_score,
      MathAbs(g_last_long_score-g_last_short_score),
      g_last_long_confidence,
      g_last_short_confidence,
      signal_score,
      DataExportConfidenceName(selected_confidence),
      InpChartSignalScore,
      InpChartStrongSignalScore,
      DoubleToString(open_price, _Digits),
      DoubleToString(high_price, _Digits),
      DoubleToString(low_price, _Digits),
      DoubleToString(close_price, _Digits),
      DoubleToString(fast_ma, _Digits),
      DoubleToString(slow_ma, _Digits),
      DoubleToString((fast_ma-slow_ma)/_Point, 2),
      DoubleToString(macd_value, 8),
      DoubleToString(delta_value, 8),
      DataExportSessionName(bar_time),
      DataExportWeekdayName(bar_time),
      (long)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD),
      g_auto_trading ? "YES" : "NO",
      InpMagicNumber);
   FileFlush(handle);
   FileClose(handle);

   // Record only final, score-qualified directional signals in the unified
   // lifecycle dataset. Non-selected diagnostic observations remain in SignalDataset.
   static datetime last_lifecycle_signal_time = 0;
   static int last_lifecycle_signal_side = 0;
   if(selected_side != 0 &&
      (bar_time != last_lifecycle_signal_time || selected_side != last_lifecycle_signal_side))
   {
      last_lifecycle_signal_time = bar_time;
      last_lifecycle_signal_side = selected_side;
      WriteLifecycleEvent("SIGNAL", selected_side, "", DataExportHoldStateName(),
         pattern_name + " | " + source_tag, 0, close_price, 0.0, 0.0, bar_time);
   }
}


//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
string DataExportPreDirectionName()
{
   if(!g_auto_start_bias_active)
      return "NEUTRAL";
   if(g_auto_start_bias == AUTO_BIAS_LONG)
      return "LONG";
   if(g_auto_start_bias == AUTO_BIAS_SHORT)
      return "SHORT";
   return "NEUTRAL";
}


//+------------------------------------------------------------------+
string DataExportRangeStateName()
{
   if(g_range_internal_state == RANGE_STATE_REVERSAL) return "REVERSAL";
   if(g_range_internal_state == RANGE_STATE_ENTRY) return "ENTRY";
   if(g_range_internal_state == RANGE_STATE_HOLD) return "HOLD";
   if(g_range_internal_state == RANGE_STATE_EXIT) return "EXIT";
   return "SETUP";
}

//+------------------------------------------------------------------+
string DataExportDecisionReasonCategory(const string reason)
{
   if(reason == "") return "NONE";
   if(StringFind(reason, "BIAS") >= 0 || StringFind(reason, "DIRECTION") >= 0) return "DIRECTION";
   if(StringFind(reason, "NEUTRAL_FLOW") >= 0 ||
      StringFind(reason, "COMPRESSED_CHOP") >= 0 ||
      StringFind(reason, "NO_MARKET_ENERGY") >= 0) return "MARKET_CONDITION";
   if(StringFind(reason, "SIGNAL") >= 0 || StringFind(reason, "COUNT") >= 0) return "SIGNAL_COUNT";
   if(StringFind(reason, "SCORE") >= 0) return "SCORE";
   if(StringFind(reason, "LOCATION") >= 0) return "LOCATION";
   if(StringFind(reason, "MOMENTUM") >= 0 || StringFind(reason, "MACD") >= 0 || StringFind(reason, "DELTA") >= 0) return "MOMENTUM";
   if(StringFind(reason, "POSITION") >= 0) return "POSITION";
   if(StringFind(reason, "COOLDOWN") >= 0) return "COOLDOWN";
   if(StringFind(reason, "SPREAD") >= 0 || StringFind(reason, "DEVIATION") >= 0 || StringFind(reason, "ATR") >= 0) return "EXECUTION_SAFETY";
   if(StringFind(reason, "ORDER") >= 0 || StringFind(reason, "BROKER") >= 0) return "BROKER";
   return "OTHER";
}

//+------------------------------------------------------------------+
string DataExportMAState(const double ma7,
                         const double ma22,
                         const double ma70,
                         const double ma111)
{
   if(ma7 > ma22 && ma22 > ma70 && ma70 > ma111) return "BULL_STACK";
   if(ma7 < ma22 && ma22 < ma70 && ma70 < ma111) return "BEAR_STACK";
   if(ma7 > ma22 && ma22 > ma70) return "BULL_TREND";
   if(ma7 < ma22 && ma22 < ma70) return "BEAR_TREND";
   return "MIXED";
}

JTA_DirectionStrengthResult DataExportDirectionStrength(const int requested_side)
{
   const int side = requested_side == 0 ?
      (g_last_long_score >= g_last_short_score ? 1 : -1) : requested_side;
   const double macd_now = DataExportBufferValue(g_macd_handle, JTC_MACD_BASE_BUFFER, 1);
   const double macd_prev = DataExportBufferValue(g_macd_handle, JTC_MACD_BASE_BUFFER, 2);
   const double delta_now = DataExportBufferValue(g_delta_handle, 2, 1);
   const double delta_prev = DataExportBufferValue(g_delta_handle, 2, 2);
   const double delta_ema_now = DataExportBufferValue(g_delta_handle, 3, 1);
   const double delta_ema_prev = DataExportBufferValue(g_delta_handle, 3, 2);
   const double ma7_now = DataExportBufferValue(g_add_ma_handle, 0, 1);
   const double ma7_prev = DataExportBufferValue(g_add_ma_handle, 0, 2);
   const double ma22_now = DataExportBufferValue(g_slow_ma_handle, 0, 1);
   const double close_now = iClose(_Symbol, AUTO_TF, 1);
   const double m5_macd = DataExportBufferValue(g_macd_handle, JTC_MACD_BASE_BUFFER, 1);
   const double m5_delta = DataExportBufferValue(g_delta_handle, 2, 1);
   const bool higher_tf_aligned = side > 0 ?
      (m5_macd >= 0.0 && m5_delta >= 0.0) :
      (m5_macd <= 0.0 && m5_delta <= 0.0);
   const bool macd_strong = side > 0 ?
      (macd_now > 0.0 && macd_now > macd_prev) :
      (macd_now < 0.0 && macd_now < macd_prev);
   const bool delta_strong = side > 0 ?
      (delta_now > 0.0 && delta_ema_now > 0.0 && delta_now > delta_prev) :
      (delta_now < 0.0 && delta_ema_now < 0.0 && delta_now < delta_prev);
   const bool favourable_structure = side > 0 ?
      (close_now >= ma7_now && ma7_now >= ma22_now) :
      (close_now <= ma7_now && ma7_now <= ma22_now);
   const bool opposite_pressure = side > 0 ?
      (macd_now < 0.0 && delta_now < 0.0) :
      (macd_now > 0.0 && delta_now > 0.0);
   return EvaluateDirectionStrength(side, macd_now, macd_prev,
      delta_now, delta_prev, delta_ema_now, delta_ema_prev,
      ma7_now, ma7_prev, ma22_now, close_now,
      higher_tf_aligned, macd_strong, delta_strong,
      favourable_structure, opposite_pressure);
}

//+------------------------------------------------------------------+
void WriteSignalDecisionLog(const int side,
                            const string stage,
                            const int signal_count,
                            const int score,
                            const string final_decision,
                            const string blocked_reason,
                            const bool order_requested,
                            const bool order_result,
                            const long order_retcode,
                            const double range_location)
{
   if(!DataExportTesterKeepStrategyDecisionStage(stage))
      return;


   if(!g_integrated_csv_mode)
   {
      DataExportWriteUnifiedEvent("SIGNAL",stage,side,0,0.0,0.0,score,
         final_decision,blocked_reason,"",
         (double)signal_count,range_location,
         StringFormat("ORDER_REQ=%s ORDER_RESULT=%s RETCODE=%I64d",
                      order_requested?"YES":"NO",
                      order_result?"YES":"NO",order_retcode));
   }

   const string file_name = SignalDecisionFileName();
   const bool tester_fast_io = DataExportIsTester();
   static int tester_handle = INVALID_HANDLE;
   static int tester_rows_since_flush = 0;

   int handle = INVALID_HANDLE;
   if(tester_fast_io)
   {
      if(tester_handle == INVALID_HANDLE)
      {
         tester_handle = FileOpen(file_name,
            DataExportFileFlags(FILE_READ|FILE_WRITE|FILE_ANSI|FILE_SHARE_READ|FILE_SHARE_WRITE),
            0, CP_UTF8);
         if(tester_handle != INVALID_HANDLE)
            FileSeek(tester_handle,0,SEEK_END);
      }
      handle = tester_handle;
   }
   else
   {
      if(DataExportEnsureLiveBufferedHandle(
            file_name,g_live_signal_decision_handle,g_live_signal_decision_file))
         handle=g_live_signal_decision_handle;
   }

   if(handle == INVALID_HANDLE)
   {
      PrintFormat("SIGNAL DECISION CSV OPEN FAILED | file=%s | error=%d",
                  file_name, GetLastError());
      return;
   }

   if(FileSize(handle) == 0)
   {
      string header = "";
      DataExportAddContextHeader(header);
      DataExportCsvAdd(header, "time_server");
      DataExportCsvAdd(header, "symbol");
      DataExportCsvAdd(header, "magic");
      DataExportCsvAdd(header, "strategy");
      DataExportCsvAdd(header, "direction");
      DataExportCsvAdd(header, "stage");
      DataExportCsvAdd(header, "same_direction_signal_count");
      DataExportCsvAdd(header, "score");
      DataExportCsvAdd(header, "direction_strength_level");
      DataExportCsvAdd(header, "direction_strength_score");
      DataExportCsvAdd(header, "macd_strength_score");
      DataExportCsvAdd(header, "delta_strength_score");
      DataExportCsvAdd(header, "ma_strength_score");
      DataExportCsvAdd(header, "structure_strength_score");
      DataExportCsvAdd(header, "higher_tf_strength_score");
      DataExportCsvAdd(header, "direction_strengthening");
      DataExportCsvAdd(header, "direction_weakening");
      DataExportCsvAdd(header, "hold_state");
      DataExportCsvAdd(header, "profit_protection_state");
      DataExportCsvAdd(header, "hold_score");
      DataExportCsvAdd(header, "strong_score");
      DataExportCsvAdd(header, "weakness_score");
      DataExportCsvAdd(header, "ma7");
      DataExportCsvAdd(header, "ma22");
      DataExportCsvAdd(header, "ma70");
      DataExportCsvAdd(header, "ma111");
      DataExportCsvAdd(header, "ma_state");
      DataExportCsvAdd(header, "operating_mode");
      DataExportCsvAdd(header, "long_score");
      DataExportCsvAdd(header, "short_score");
      DataExportCsvAdd(header, "long_confidence");
      DataExportCsvAdd(header, "short_confidence");
      DataExportCsvAdd(header, "auto_enabled");
      DataExportCsvAdd(header, "signal_enabled");
      DataExportCsvAdd(header, "mobile_enabled");
      DataExportCsvAdd(header, "selected_direction");
      DataExportCsvAdd(header, "pre_direction");
      DataExportCsvAdd(header, "pre_direction_active");
      DataExportCsvAdd(header, "managed_position_side");
      DataExportCsvAdd(header, "range_location_percent");
      DataExportCsvAdd(header, "spread_points");
      DataExportCsvAdd(header, "range_internal_state");
      DataExportCsvAdd(header, "range_internal_side");
      DataExportCsvAdd(header, "range_state_bars");
      DataExportCsvAdd(header, "signal_count_required");
      DataExportCsvAdd(header, "signal_count_pass");
      DataExportCsvAdd(header, "entry_score_required");
      DataExportCsvAdd(header, "entry_score_pass");
      DataExportCsvAdd(header, "bias_release_required");
      DataExportCsvAdd(header, "bias_released_or_not_required");
      DataExportCsvAdd(header, "current_bias");
      DataExportCsvAdd(header, "release_score");
      DataExportCsvAdd(header, "release_condition");
      DataExportCsvAdd(header, "bias_released");
      DataExportCsvAdd(header, "release_block_reason");
      DataExportCsvAdd(header, "bias_bars_seen");
      DataExportCsvAdd(header, "decision_reason_category");
      DataExportCsvAdd(header, "status_snapshot");
      DataExportCsvAdd(header, "market_regime");
      DataExportCsvAdd(header, "expected_trend_direction");
      DataExportCsvAdd(header, "trend_direction_matched");
      DataExportCsvAdd(header, "neutral_flow");
      DataExportCsvAdd(header, "compressed_chop");
      DataExportCsvAdd(header, "no_market_energy");
      DataExportCsvAdd(header, "relative_energy_ok");
      DataExportCsvAdd(header, "real_energy_ok");
      DataExportCsvAdd(header, "direction_flow_long_ok");
      DataExportCsvAdd(header, "direction_flow_short_ok");
      DataExportCsvAdd(header, "relative_range_ratio");
      DataExportCsvAdd(header, "relative_macd_ratio");
      DataExportCsvAdd(header, "relative_delta_ratio");
      DataExportCsvAdd(header, "direction_long_allowed");
      DataExportCsvAdd(header, "direction_short_allowed");
      DataExportCsvAdd(header, "long_direction_quality");
      DataExportCsvAdd(header, "short_direction_quality");
      DataExportCsvAdd(header, "common_range_gate_pass");
      DataExportCsvAdd(header, "selected_side_gate_reason");
      DataExportCsvAdd(header, "signal_generated_before_gate");
      DataExportCsvAdd(header, "signal_allowed_after_gate");
      DataExportCsvAdd(header, "order_requested");
      DataExportCsvAdd(header, "order_result");
      DataExportCsvAdd(header, "order_retcode");
      DataExportCsvAdd(header, "final_decision");
      DataExportCsvAdd(header, "blocked_reason");
      DataExportCsvAdd(header, "counter_window_bars");
      DataExportCsvAdd(header, "counter_bar_time");
      DataExportCsvAdd(header, "counter_raw_long_confirmed");
      DataExportCsvAdd(header, "counter_raw_short_confirmed");
      DataExportCsvAdd(header, "counter_countable_long");
      DataExportCsvAdd(header, "counter_countable_short");
      DataExportCsvAdd(header, "counter_long_before");
      DataExportCsvAdd(header, "counter_short_before");
      DataExportCsvAdd(header, "counter_long_after");
      DataExportCsvAdd(header, "counter_short_after");
      DataExportCsvAdd(header, "counter_long_last_shift");
      DataExportCsvAdd(header, "counter_short_last_shift");
      DataExportCsvAdd(header, "counter_long_first_shift");
      DataExportCsvAdd(header, "counter_short_first_shift");
      DataExportCsvAdd(header, "counter_long_first_time");
      DataExportCsvAdd(header, "counter_short_first_time");
      DataExportCsvAdd(header, "counter_long_expired");
      DataExportCsvAdd(header, "counter_short_expired");
      DataExportCsvAdd(header, "counter_opposite_decay");
      DataExportCsvAdd(header, "counter_action");
      DataExportCsvAdd(header, "counter_reset_reason");
      DataExportCsvAdd(header, "third_signal_bar_time");
      DataExportCsvAdd(header, "third_signal_high");
      DataExportCsvAdd(header, "third_signal_low");
      DataExportCsvAdd(header, "break_confirm_bar_time");
      DataExportCsvAdd(header, "break_confirm_high");
      DataExportCsvAdd(header, "break_confirm_low");
      DataExportCsvAdd(header, "break_confirm_close");
      DataExportCsvAdd(header, "break_reference_price");
      DataExportCsvAdd(header, "break_distance");
      DataExportCsvAdd(header, "break_confirmed");
      DataExportCsvAdd(header, "break_order_sent");
      DataExportCsvAdd(header, "break_order_result");
      DataExportCsvAdd(header, "break_order_price");
      DataExportCsvAdd(header, "event_type");
      DataExportCsvAdd(header, "position_id");
      DataExportCsvAdd(header, "event_time");
      DataExportCsvAdd(header, "event_price");
      DataExportCsvAdd(header, "event_volume");
      DataExportCsvAdd(header, "realized_profit");
      DataExportCsvAdd(header, "floating_profit");
      DataExportCsvAdd(header, "group_volume");
      DataExportCsvAdd(header, "average_entry");
      DataExportCsvAdd(header, "current_sl");
      DataExportCsvAdd(header, "current_tp");
      DataExportCsvAdd(header, "initial_r_distance");
      DataExportCsvAdd(header, "current_profit_r");
      DataExportCsvAdd(header, "highest_profit_r");
      DataExportCsvAdd(header, "protected_sl");
      DataExportCsvAdd(header, "previous_hold_state");
      DataExportCsvAdd(header, "current_hold_state");
      DataExportCsvAdd(header, "hold_seconds");
      DataExportCsvAdd(header, "hold_bars");
      DataExportCsvAdd(header, "additional_entry_count");
      DataExportCsvAdd(header, "add_enabled");
      DataExportCsvAdd(header, "add_max_count");
      DataExportCsvAdd(header, "add_count_before");
      DataExportCsvAdd(header, "add_count_after");
      DataExportCsvAdd(header, "add_capacity_remaining");
      DataExportCsvAdd(header, "add_stage");
      DataExportCsvAdd(header, "add_signal_count");
      DataExportCsvAdd(header, "add_signal_required");
      DataExportCsvAdd(header, "add_same_direction_signal");
      DataExportCsvAdd(header, "add_opposite_direction_signal");
      DataExportCsvAdd(header, "add_exit_safe");
      DataExportCsvAdd(header, "add_attempted");
      DataExportCsvAdd(header, "add_result");
      DataExportCsvAdd(header, "add_retcode");
      DataExportCsvAdd(header, "add_block_reason");
      DataExportCsvAdd(header, "add_signal_bar_time");
      DataExportCsvAdd(header, "add_bars_since_entry");
      DataExportCsvAdd(header, "add_progress_r");
      DataExportCsvAdd(header, "add_requested_volume");
      DataExportCsvAdd(header, "add_fill_price");
      DataExportCsvAdd(header, "entry_profile");
      DataExportCsvAdd(header, "m3_bar_time");
      DataExportCsvAdd(header, "m3_segment_id");
      DataExportCsvAdd(header, "m3_direction");
      DataExportCsvAdd(header, "m3_phase");
      DataExportCsvAdd(header, "m3_regime");
      DataExportCsvAdd(header, "m3_structure_valid");
      DataExportCsvAdd(header, "m3_structure_break");
      DataExportCsvAdd(header, "m3_structure_episode");
      DataExportCsvAdd(header, "m3_episode_state");
      // v8.238: immutable segment invalidation boundary audit.
      DataExportCsvAdd(header, "m3_invalidation_event");
      DataExportCsvAdd(header, "m3_invalidation_time");
      DataExportCsvAdd(header, "m3_invalidation_reason");
      DataExportCsvAdd(header, "m3_persistence_confirmed");
      DataExportCsvAdd(header, "m3_persistence_time");
      DataExportCsvAdd(header, "m3_pullback_active");
      DataExportCsvAdd(header, "m3_pullback_episode");
      DataExportCsvAdd(header, "m3_pullback_held");
      DataExportCsvAdd(header, "m3_pullback_start_time");
      DataExportCsvAdd(header, "m3_pullback_held_time");
      DataExportCsvAdd(header, "m3_pullback_extreme");
      DataExportCsvAdd(header, "m3_pullback_reference");
      DataExportCsvAdd(header, "m3_reacceleration_episode");
      DataExportCsvAdd(header, "m3_reaccel_time");
      DataExportCsvAdd(header, "m3_trigger_long");
      DataExportCsvAdd(header, "m3_trigger_short");
      DataExportCsvAdd(header, "m3_trigger_time");
      DataExportCsvAdd(header, "m3_trigger_consumed");
      DataExportCsvAdd(header, "m3_last_trigger_side");
      DataExportCsvAdd(header, "m3_last_trigger_time");
      DataExportCsvAdd(header, "m3_structure_high");
      DataExportCsvAdd(header, "m3_structure_high_time");
      DataExportCsvAdd(header, "m3_structure_low");
      DataExportCsvAdd(header, "m3_structure_low_time");
      DataExportCsvAdd(header, "m3_protected_low");
      DataExportCsvAdd(header, "m3_protected_high");
      DataExportCsvAdd(header, "m3_external_bullish");
      DataExportCsvAdd(header, "m3_external_bearish");
      // v8.272 observation-only: expose the global M3 1/1 internal structure producer.
      // No chart, alert, WATCH, ACCEL, DIRECTION or AUTO authority is attached.
      DataExportCsvAdd(header, "m3_internal_hh");
      DataExportCsvAdd(header, "m3_internal_hl");
      DataExportCsvAdd(header, "m3_internal_lh");
      DataExportCsvAdd(header, "m3_internal_ll");
      DataExportCsvAdd(header, "m3_internal_long_ready");
      DataExportCsvAdd(header, "m3_internal_short_ready");
      DataExportCsvAdd(header, "m3_internal_last_high");
      DataExportCsvAdd(header, "m3_internal_prev_high");
      DataExportCsvAdd(header, "m3_internal_last_low");
      DataExportCsvAdd(header, "m3_internal_prev_low");
      DataExportCsvAdd(header, "m3_internal_last_high_time");
      DataExportCsvAdd(header, "m3_internal_prev_high_time");
      DataExportCsvAdd(header, "m3_internal_last_low_time");
      DataExportCsvAdd(header, "m3_internal_prev_low_time");
      DataExportCsvAdd(header, "m3_internal_pullback");
      DataExportCsvAdd(header, "m3_internal_reaccel");
      DataExportCsvAdd(header, "m3_setup_long");
      DataExportCsvAdd(header, "m3_setup_short");
      DataExportCsvAdd(header, "m3_macd_wave");
      DataExportCsvAdd(header, "m3_macd_signal");
      DataExportCsvAdd(header, "m3_ma22");
      DataExportCsvAdd(header, "m3_delta");
      DataExportCsvAdd(header, "m3_volume");
      DataExportCsvAdd(header, "m3_close");
      // v8.122: canonical M3 ACCEL verification trace. These fields expose
      // the actual ACCEL event/state produced by M3SegmentEngine so Tester
      // and LIVE runs can be compared from the same integrated CSV.
      DataExportCsvAdd(header, "m3_accel_long_active");
      DataExportCsvAdd(header, "m3_accel_short_active");
      DataExportCsvAdd(header, "m3_accel_long_pending");
      DataExportCsvAdd(header, "m3_accel_short_pending");
      DataExportCsvAdd(header, "m3_accel_long_break_level");
      DataExportCsvAdd(header, "m3_accel_short_break_level");
      DataExportCsvAdd(header, "m3_accel_long_break_time");
      DataExportCsvAdd(header, "m3_accel_short_break_time");
      DataExportCsvAdd(header, "m3_accel_side");
      DataExportCsvAdd(header, "m3_accel_time");
      DataExportCsvAdd(header, "m3_accel_event");
      DataExportCsvAdd(header, "m3_accel_macd_regime");
      DataExportCsvAdd(header, "m3_accel_wave_delta");
      DataExportCsvAdd(header, "m3_accel_histogram");
      DataExportCsvAdd(header, "m3_accel_hist_delta");
      DataExportCsvAdd(header, "m3_accel_price_drive");
      DataExportCsvAdd(header, "m3_accel_long_macd_expand");
      DataExportCsvAdd(header, "m3_accel_short_macd_expand");
      DataExportCsvAdd(header, "m3_accel_signal");
      // v8.236: internal ACCEL gate audit. CSV-only diagnostics mirror the
      // exact M3UpdateDisplayAcceleration decision path without strategy authority.
      DataExportCsvAdd(header, "m3_accel_audit_structure_high");
      DataExportCsvAdd(header, "m3_accel_audit_structure_low");
      DataExportCsvAdd(header, "m3_accel_audit_structure_high_source");
      DataExportCsvAdd(header, "m3_accel_audit_structure_low_source");
      DataExportCsvAdd(header, "m3_accel_audit_raw_long_break");
      DataExportCsvAdd(header, "m3_accel_audit_raw_short_break");
      DataExportCsvAdd(header, "m3_accel_audit_watch_owner_side");
      DataExportCsvAdd(header, "m3_accel_audit_watch_owner_time");
      DataExportCsvAdd(header, "m3_accel_audit_long_watch_authorized");
      DataExportCsvAdd(header, "m3_accel_audit_short_watch_authorized");
      DataExportCsvAdd(header, "m3_accel_audit_prior_long_accel_high");
      DataExportCsvAdd(header, "m3_accel_audit_prior_short_accel_low");
      DataExportCsvAdd(header, "m3_accel_audit_long_price_extension");
      DataExportCsvAdd(header, "m3_accel_audit_short_price_extension");
      DataExportCsvAdd(header, "m3_accel_audit_emit_long");
      DataExportCsvAdd(header, "m3_accel_audit_emit_short");
      DataExportCsvAdd(header, "m3_accel_audit_long_block_reason");
      DataExportCsvAdd(header, "m3_accel_audit_short_block_reason");
      // v8.141: compact M3 signal/order audit extension. Raw M3 OHLC and
      // every WATCH predicate are exported so WATCH can be replayed exactly
      // from IntegratedTrace. Event IDs distinguish one signal event from
      // repeated audit rows, while leg/decision fields expose signal->AUTO.
      DataExportCsvAdd(header, "m3_open");
      DataExportCsvAdd(header, "m3_high");
      DataExportCsvAdd(header, "m3_low");
      DataExportCsvAdd(header, "m3_prev_open");
      DataExportCsvAdd(header, "m3_prev_high");
      DataExportCsvAdd(header, "m3_prev_low");
      DataExportCsvAdd(header, "m3_prev_close");
      DataExportCsvAdd(header, "watch_long_high_ok");
      DataExportCsvAdd(header, "watch_long_close_ok");
      DataExportCsvAdd(header, "watch_long_wave_side_ok");
      DataExportCsvAdd(header, "watch_long_wave_delta_ok");
      DataExportCsvAdd(header, "watch_long_hist_delta_ok");
      DataExportCsvAdd(header, "watch_short_low_ok");
      DataExportCsvAdd(header, "watch_short_close_ok");
      DataExportCsvAdd(header, "watch_short_wave_side_ok");
      DataExportCsvAdd(header, "watch_short_wave_delta_ok");
      DataExportCsvAdd(header, "watch_short_hist_delta_ok");
      DataExportCsvAdd(header, "watch_long_candidate");
      DataExportCsvAdd(header, "watch_short_candidate");
      DataExportCsvAdd(header, "watch_long_context_count");
      DataExportCsvAdd(header, "watch_short_context_count");
      DataExportCsvAdd(header, "watch_event_origin");
      // v8.162: cached StateEvaluation evidence for exact true-WATCH omission analysis.
      DataExportCsvAdd(header, "assist_bar_time");
      DataExportCsvAdd(header, "assist_timeframe");
      DataExportCsvAdd(header, "assist_state");
      DataExportCsvAdd(header, "assist_previous_state");
      DataExportCsvAdd(header, "assist_watch_pulse");
      DataExportCsvAdd(header, "assist_changed");
      DataExportCsvAdd(header, "assist_direction_anchor");
      DataExportCsvAdd(header, "assist_established_side");
      DataExportCsvAdd(header, "assist_established_time");
      // v8.222 observation-only legacy persistence retained for comparison only.
      DataExportCsvAdd(header, "assist_range_persistent_direction");
      DataExportCsvAdd(header, "assist_expected_bar_seconds");
      DataExportCsvAdd(header, "assist_market_gap_seconds");
      DataExportCsvAdd(header, "assist_data_discontinuity");
      DataExportCsvAdd(header, "assist_scheduled_market_gap");
      DataExportCsvAdd(header, "assist_reason");
      DataExportCsvAdd(header, "assist_raw_macd");
      DataExportCsvAdd(header, "assist_macd_base");
      DataExportCsvAdd(header, "assist_macd_wave");
      // v8.176 canonical MACD chart-replay fields. No signal/order authority.
      DataExportCsvAdd(header, "assist_macd_histogram");
      DataExportCsvAdd(header, "assist_macd_zero_state");
      DataExportCsvAdd(header, "assist_raw_up_steps");
      DataExportCsvAdd(header, "assist_raw_down_steps");
      DataExportCsvAdd(header, "assist_frame_canonical");
      DataExportCsvAdd(header, "assist_macd_wave_change_1");
      DataExportCsvAdd(header, "assist_macd_wave_change_3");
      // v8.219: observation-only MACD flatness diagnostics in the integrated CSV.
      DataExportCsvAdd(header, "assist_macd_base_change_1");
      DataExportCsvAdd(header, "assist_macd_base_change_3");
      DataExportCsvAdd(header, "assist_macd_base_travel_3");
      DataExportCsvAdd(header, "assist_macd_base_efficiency_3");
      DataExportCsvAdd(header, "assist_macd_wave_travel_3");
      DataExportCsvAdd(header, "assist_macd_wave_efficiency_3");
      DataExportCsvAdd(header, "assist_macd_change_1");
      DataExportCsvAdd(header, "assist_macd_change_3");
      DataExportCsvAdd(header, "assist_macd_transition_progress");
      DataExportCsvAdd(header, "assist_macd_direction");
      DataExportCsvAdd(header, "assist_macd_transition_up");
      DataExportCsvAdd(header, "assist_macd_transition_down");
      DataExportCsvAdd(header, "assist_long_transition_progress");
      DataExportCsvAdd(header, "assist_short_transition_progress");
      // v8.280 diagnostic-only early opposite WATCH shadow.
      DataExportCsvAdd(header, "early_opposite_watch_shadow");
      DataExportCsvAdd(header, "early_opposite_watch_pulse");
      DataExportCsvAdd(header, "early_opposite_watch_side");
      DataExportCsvAdd(header, "early_opposite_watch_stage");
      DataExportCsvAdd(header, "early_opposite_watch_classification");
      DataExportCsvAdd(header, "early_candidate_track_active");
      DataExportCsvAdd(header, "early_candidate_track_side");
      DataExportCsvAdd(header, "early_candidate_start_time");
      DataExportCsvAdd(header, "early_candidate_age_bars");
      DataExportCsvAdd(header, "trend_reassertion_pending");
      DataExportCsvAdd(header, "trend_reassertion_side");
      DataExportCsvAdd(header, "trend_reassertion_age_bars");
      DataExportCsvAdd(header, "trend_reassertion_target_recovered_pulse");
      DataExportCsvAdd(header, "trend_reassertion_cancel_pulse");
      DataExportCsvAdd(header, "review_shadow_end_reason");
      DataExportCsvAdd(header, "review_shadow_ended_start");
      DataExportCsvAdd(header, "review_shadow_ended_side");
      DataExportCsvAdd(header, "review_adx14");
      DataExportCsvAdd(header, "review_adx14_valid");
      DataExportCsvAdd(header, "review_price_break3");
      DataExportCsvAdd(header, "review_qualified_early_opposite");
      DataExportCsvAdd(header, "review_add_block_option");
      DataExportCsvAdd(header, "review_add_blocked");
      DataExportCsvAdd(header, "turn_pre_enabled");
      DataExportCsvAdd(header, "turn_pre_data_valid");
      DataExportCsvAdd(header, "turn_pre_signal");
      DataExportCsvAdd(header, "turn_pre_side");
      DataExportCsvAdd(header, "turn_pre_confirm_bar");
      DataExportCsvAdd(header, "turn_pre_available_time");
      DataExportCsvAdd(header, "turn_pre_pivot_time");
      DataExportCsvAdd(header, "turn_pre_pivot_price");
      DataExportCsvAdd(header, "turn_pre_score");
      DataExportCsvAdd(header, "turn_pre_distance_r");
      DataExportCsvAdd(header, "turn_pre_long_divergence_r");
      DataExportCsvAdd(header, "turn_pre_short_divergence_r");
      DataExportCsvAdd(header, "turn_pre_opposite");
      DataExportCsvAdd(header, "turn_pre_reason");
      DataExportCsvAdd(header, "turn_pre_require_divergence");
      DataExportCsvAdd(header, "turn_pre_atr14");
      DataExportCsvAdd(header, "assist_raw_delta");
      DataExportCsvAdd(header, "assist_ema_delta");
      DataExportCsvAdd(header, "assist_delta_change");
      DataExportCsvAdd(header, "assist_delta_buy_steps");
      DataExportCsvAdd(header, "assist_delta_sell_steps");
      DataExportCsvAdd(header, "assist_delta_long_participation");
      DataExportCsvAdd(header, "assist_delta_short_participation");
      DataExportCsvAdd(header, "assist_price_up");
      DataExportCsvAdd(header, "assist_price_down");
      DataExportCsvAdd(header, "assist_full_long_watch_candidate");
      DataExportCsvAdd(header, "assist_full_short_watch_candidate");
      DataExportCsvAdd(header, "assist_flip_path_oscillatory");
      DataExportCsvAdd(header, "assist_flip_raw_path_directional");
      DataExportCsvAdd(header, "assist_flip_wave_path_directional");
      DataExportCsvAdd(header, "assist_flip_raw_path_direction");
      DataExportCsvAdd(header, "assist_flip_wave_path_direction");
      DataExportCsvAdd(header, "assist_flip_raw_efficiency_5");
      DataExportCsvAdd(header, "assist_flip_wave_efficiency_5");
      DataExportCsvAdd(header, "assist_flip_hold_active");
      DataExportCsvAdd(header, "assist_flip_hold_side");
      DataExportCsvAdd(header, "assist_flip_hold_action");
      DataExportCsvAdd(header, "assist_flip_hold_contested");
      DataExportCsvAdd(header, "assist_structure_higher_low");
      DataExportCsvAdd(header, "assist_structure_lower_high");
      DataExportCsvAdd(header, "assist_pullback_long_ready");
      DataExportCsvAdd(header, "assist_pullback_short_ready");
      DataExportCsvAdd(header, "assist_recent_swing_high");
      DataExportCsvAdd(header, "assist_recent_swing_low");
      DataExportCsvAdd(header, "assist_older_swing_high");
      DataExportCsvAdd(header, "assist_older_swing_low");
      DataExportCsvAdd(header, "assist_up_close_steps");
      DataExportCsvAdd(header, "assist_down_close_steps");
      DataExportCsvAdd(header, "assist_post_discontinuity_rearm");
      DataExportCsvAdd(header, "watch_event");
      DataExportCsvAdd(header, "watch_side");
      DataExportCsvAdd(header, "watch_sequence");
      DataExportCsvAdd(header, "watch_event_id");
      DataExportCsvAdd(header, "m3_directional_leg_side");
      DataExportCsvAdd(header, "m3_directional_leg_id");
      DataExportCsvAdd(header, "accel_event_id");
      DataExportCsvAdd(header, "accel_matches_leg");
      DataExportCsvAdd(header, "auto_signal_type");
      DataExportCsvAdd(header, "auto_signal_side");
      // v8.235: separate actual execution source / DIRECTION event from same-bar priority state.
      DataExportCsvAdd(header, "event_source_event_id");
      DataExportCsvAdd(header, "order_signal_source");
      DataExportCsvAdd(header, "order_signal_side");
      DataExportCsvAdd(header, "order_signal_time");
      DataExportCsvAdd(header, "direction_event");
      DataExportCsvAdd(header, "direction_event_side");
      DataExportCsvAdd(header, "direction_event_time");
      DataExportCsvAdd(header, "m3_segment_direction");
      DataExportCsvAdd(header, "auto_decision");
      DataExportCsvAdd(header, "auto_order_expected");
      DataExportCsvAdd(header, "auto_leg_side");
      DataExportCsvAdd(header, "auto_leg_start_time");
      DataExportCsvAdd(header, "auto_accel_eligible");
      // v8.221 observation-only WATCH episode diagnostics. No order authority.
      DataExportCsvAdd(header, "assist_price_travel_3_r");
      DataExportCsvAdd(header, "assist_price_efficiency_3");
      DataExportCsvAdd(header, "assist_macd_zero_flip_count_5");
      // v8.263 observation-only market-regime diagnostics.
      DataExportCsvAdd(header, "assist_chop_8");
      DataExportCsvAdd(header, "assist_chop_14");
      DataExportCsvAdd(header, "assist_chop_21");
      DataExportCsvAdd(header, "assist_aroon_up_21");
      DataExportCsvAdd(header, "assist_aroon_down_21");
      DataExportCsvAdd(header, "assist_aroon_osc_21");
      // v8.264 observation-only WATCH candidate classification.
      DataExportCsvAdd(header, "watch_observe_original");
      DataExportCsvAdd(header, "watch_observe_new_candidate");
      DataExportCsvAdd(header, "watch_observe_stage");
      DataExportCsvAdd(header, "watch_observe_suppress_reason");
      DataExportCsvAdd(header, "watch_observe_progress3_r");
      DataExportCsvAdd(header, "watch_observe_chop8_delta3");
      DataExportCsvAdd(header, "watch_observe_chop14");
      DataExportCsvAdd(header, "watch_observe_aroon_spread");
      DataExportCsvAdd(header, "watch_suppress_latch_active");
      DataExportCsvAdd(header, "watch_suppress_latch_side");
      DataExportCsvAdd(header, "watch_suppress_event");
      DataExportCsvAdd(header, "watch_suppress_release");
      DataExportCsvAdd(header, "watch_episode_active");
      DataExportCsvAdd(header, "watch_episode_id");
      DataExportCsvAdd(header, "watch_episode_side");
      DataExportCsvAdd(header, "watch_episode_start_time");
      DataExportCsvAdd(header, "watch_episode_start_price");
      DataExportCsvAdd(header, "watch_episode_age_bars");
      DataExportCsvAdd(header, "watch_episode_mfe_price");
      DataExportCsvAdd(header, "watch_episode_mae_price");
      DataExportCsvAdd(header, "watch_episode_first_accel_age");
      DataExportCsvAdd(header, "watch_episode_first_accel_time");
      DataExportCsvAdd(header, "watch_episode_pre_net_progress_r");
      DataExportCsvAdd(header, "watch_episode_pre_recent_progress_r");
      DataExportCsvAdd(header, "watch_episode_pre_price_travel_3_r");
      DataExportCsvAdd(header, "watch_episode_pre_price_efficiency_3");
      DataExportCsvAdd(header, "watch_episode_pre_macd_base_efficiency_3");
      DataExportCsvAdd(header, "watch_episode_pre_macd_wave_efficiency_3");
      DataExportCsvAdd(header, "watch_episode_pre_macd_zero_flip_count_5");
      DataExportCsvAdd(header, "watch_episode_price_travel");
      DataExportCsvAdd(header, "watch_episode_net_displacement");
      DataExportCsvAdd(header, "watch_episode_efficiency");
      DataExportCsvAdd(header, "watch_episode_extreme_extension_r");
      DataExportCsvAdd(header, "watch_episode_cluster_price_travel");
      DataExportCsvAdd(header, "watch_episode_cluster_net_displacement");
      DataExportCsvAdd(header, "watch_episode_cluster_efficiency");
      DataExportCsvAdd(header, "watch_episode_repeat_count");
      DataExportCsvAdd(header, "watch_episode_last_repeat_displacement_r");
      DataExportCsvAdd(header, "watch_episode_closed_id");
      DataExportCsvAdd(header, "watch_episode_closed_side");
      DataExportCsvAdd(header, "watch_episode_closed_time");
      DataExportCsvAdd(header, "watch_episode_closed_age_bars");
      DataExportCsvAdd(header, "watch_episode_closed_mfe_price");
      DataExportCsvAdd(header, "watch_episode_closed_mae_price");
      DataExportCsvAdd(header, "audit_schema_version");
      // v8.168 post-entry structure episode evidence (diagnostic only).
      DataExportCsvAdd(header, "structure_episode_id");
      DataExportCsvAdd(header, "structure_episode_active");
      DataExportCsvAdd(header, "structure_episode_side");
      DataExportCsvAdd(header, "structure_entry_time");
      DataExportCsvAdd(header, "structure_entry_price");
      DataExportCsvAdd(header, "structure_bar_offset");
      DataExportCsvAdd(header, "structure_last_event");
      DataExportCsvAdd(header, "structure_last_event_time");
      DataExportCsvAdd(header, "structure_mfe_price");
      DataExportCsvAdd(header, "structure_mae_price");
      DataExportCsvAdd(header, "structure_add_count");
      DataExportCsvAdd(header, "structure_entry_prev_swing_high");
      DataExportCsvAdd(header, "structure_entry_last_swing_high");
      DataExportCsvAdd(header, "structure_entry_prev_swing_low");
      DataExportCsvAdd(header, "structure_entry_last_swing_low");
      DataExportCsvAdd(header, "structure_entry_protected_high");
      DataExportCsvAdd(header, "structure_entry_protected_low");
      DataExportCsvAdd(header, "structure_entry_position_protected_price");
      DataExportCsvAdd(header, "structure_entry_position_protected_time");
      DataExportCsvAdd(header, "structure_entry_position_protected_source");
      DataExportCsvAdd(header, "structure_entry_position_protected_type");
      DataExportCsvAdd(header, "structure_entry_ma7");
      DataExportCsvAdd(header, "structure_entry_ma22");
      DataExportCsvAdd(header, "structure_entry_macd_wave");
      DataExportCsvAdd(header, "structure_entry_macd_hist");
      DataExportCsvAdd(header, "structure_entry_delta");
      DataExportCsvAdd(header, "structure_entry_volume");
      DataExportCsvAdd(header, "structure_frame_open");
      DataExportCsvAdd(header, "structure_frame_high");
      DataExportCsvAdd(header, "structure_frame_low");
      DataExportCsvAdd(header, "structure_frame_close");
      DataExportCsvAdd(header, "structure_frame_ma7");
      DataExportCsvAdd(header, "structure_frame_ma22");
      DataExportCsvAdd(header, "structure_frame_macd_wave");
      DataExportCsvAdd(header, "structure_frame_macd_hist");
      DataExportCsvAdd(header, "structure_frame_delta");
      DataExportCsvAdd(header, "structure_frame_delta_ema");
      DataExportCsvAdd(header, "structure_frame_volume");
      DataExportCsvAdd(header, "structure_frame_hh");
      DataExportCsvAdd(header, "structure_frame_hl");
      DataExportCsvAdd(header, "structure_frame_lh");
      DataExportCsvAdd(header, "structure_frame_ll");
      DataExportCsvAdd(header, "structure_frame_legacy_structure_break");
      DataExportCsvAdd(header, "structure_frame_external_bullish");
      DataExportCsvAdd(header, "structure_frame_external_bearish");
      DataExportCsvAdd(header, "structure_frame_internal_bullish");
      DataExportCsvAdd(header, "structure_frame_internal_bearish");
      DataExportCsvAdd(header, "structure_frame_internal_trigger_high");
      DataExportCsvAdd(header, "structure_frame_internal_trigger_low");
      DataExportCsvAdd(header, "structure_frame_trigger_long");
      DataExportCsvAdd(header, "structure_frame_trigger_short");
      DataExportCsvAdd(header, "structure_frame_last_trigger_side");
      DataExportCsvAdd(header, "structure_frame_last_trigger_time");
      DataExportCsvAdd(header, "structure_frame_struct_long_trigger_price");
      DataExportCsvAdd(header, "structure_frame_struct_short_trigger_price");
      DataExportCsvAdd(header, "structure_frame_struct_long_trigger_base_price");
      DataExportCsvAdd(header, "structure_frame_struct_short_trigger_base_price");
      DataExportCsvAdd(header, "structure_frame_struct_long_trigger_fired");
      DataExportCsvAdd(header, "structure_frame_struct_short_trigger_fired");
      DataExportCsvAdd(header, "structure_frame_struct_long_trigger_fire_time");
      DataExportCsvAdd(header, "structure_frame_struct_short_trigger_fire_time");
      DataExportCsvAdd(header, "structure_entry_internal_trigger_high");
      DataExportCsvAdd(header, "structure_entry_internal_trigger_low");
      DataExportCsvAdd(header, "structure_entry_struct_long_trigger_price");
      DataExportCsvAdd(header, "structure_entry_struct_short_trigger_price");
      DataExportCsvAdd(header, "structure_frame_prev_swing_high");
      DataExportCsvAdd(header, "structure_frame_last_swing_high");
      DataExportCsvAdd(header, "structure_frame_prev_swing_low");
      DataExportCsvAdd(header, "structure_frame_last_swing_low");
      DataExportCsvAdd(header, "structure_frame_protected_high");
      DataExportCsvAdd(header, "structure_frame_protected_low");
      DataExportCsvAdd(header, "structure_frame_new_directional_swing");
      DataExportCsvAdd(header, "structure_frame_directional_progress");
      DataExportCsvAdd(header, "structure_frame_macd_progress");
      DataExportCsvAdd(header, "structure_frame_macd_weakening");
      DataExportCsvAdd(header, "structure_frame_protected_test");
      DataExportCsvAdd(header, "structure_frame_protected_break");
      DataExportCsvAdd(header, "structure_frame_recovery_attempt");
      DataExportCsvAdd(header, "structure_frame_recovered");
      DataExportCsvAdd(header, "structure_frame_recovery_failed");
      DataExportCsvAdd(header, "structure_frame_structure_failed");
      DataExportCsvAdd(header, "structure_frame_internal_break");
      DataExportCsvAdd(header, "structure_frame_external_failure_confirmed");
      DataExportCsvAdd(header, "structure_frame_external_opposite_high_relation");
      DataExportCsvAdd(header, "structure_frame_external_opposite_low_relation");
      DataExportCsvAdd(header, "structure_frame_external_pivots_after_break");
      DataExportCsvAdd(header, "structure_frame_external_macd_confirm");
      DataExportCsvAdd(header, "structure_recovery_failed_time");
      DataExportCsvAdd(header, "structure_frame_diagnostic_state");
      DataExportCsvAdd(header, "structure_frame_state_start_time");
      DataExportCsvAdd(header, "structure_frame_bars_in_state");
      DataExportCsvAdd(header, "structure_frame_diagnostic_protected_price");
      DataExportCsvAdd(header, "structure_frame_diagnostic_break_price");
      DataExportCsvAdd(header, "structure_frame_position_protected_price");
      DataExportCsvAdd(header, "structure_frame_position_protected_time");
      DataExportCsvAdd(header, "structure_frame_position_protected_source");
      DataExportCsvAdd(header, "structure_frame_position_protected_updated");
      DataExportCsvAdd(header, "structure_frame_position_protected_old_price");
      DataExportCsvAdd(header, "structure_frame_position_protected_update_reason");
      DataExportCsvAdd(header, "structure_frame_position_candidate_price");
      DataExportCsvAdd(header, "structure_frame_position_candidate_time");
      DataExportCsvAdd(header, "structure_frame_position_candidate_source");
      DataExportCsvAdd(header, "structure_frame_internal_trigger_high_changed");
      DataExportCsvAdd(header, "structure_frame_internal_trigger_low_changed");
      DataExportCsvAdd(header, "structure_frame_struct_long_trigger_changed");
      DataExportCsvAdd(header, "structure_frame_struct_short_trigger_changed");
      DataExportCsvAdd(header, "structure_frame_struct_long_close_break");
      DataExportCsvAdd(header, "structure_frame_struct_short_close_break");
      DataExportCsvAdd(header, "structure_frame_struct_long_recovered");
      DataExportCsvAdd(header, "structure_frame_struct_short_recovered");
      DataExportCsvAdd(header, "structure_frame_struct_long_rebreak");
      DataExportCsvAdd(header, "structure_frame_struct_short_rebreak");
      DataExportCsvAdd(header, "structure_exit_reason");
      DataExportCsvAdd(header, "structure_exit_price");
      DataExportCsvAdd(header, "structure_realized_pnl");

      DataExportCsvAdd(header, "add_event_id");
      DataExportCsvAdd(header, "add_event_phase");
      DataExportCsvAdd(header, "add_event_time");
      DataExportCsvAdd(header, "add_event_side");
      DataExportCsvAdd(header, "add_event_layer");
      DataExportCsvAdd(header, "exit_event_id");
      DataExportCsvAdd(header, "exit_event_phase");
      DataExportCsvAdd(header, "exit_event_time");
      DataExportCsvAdd(header, "exit_event_reason");
      DataExportCsvAdd(header, "position_cycle_id");
      DataExportCsvAdd(header, "position_closed_event");
      DataExportCsvAdd(header, "position_closed_cycle_id");
      DataExportCsvAdd(header, "position_closed_time");
      DataExportCsvAdd(header, "position_final_pnl");
      DataExportCsvAdd(header, "broker_position_closed_event");
      DataExportCsvAdd(header, "broker_position_id");
      DataExportCsvAdd(header, "broker_position_final_pnl");
      DataExportCsvAdd(header, "position_final_r");
      DataExportCsvAdd(header, "position_exit_reason");
      DataExportCsvAdd(header, "m3_profit_peak_r");
      DataExportCsvAdd(header, "m3_profit_lock_target_sl");
      DataExportCsvAdd(header, "m3_profit_lock_protected_sl");
      DataExportCsvAdd(header, "m3_profit_lock_attempted");
      DataExportCsvAdd(header, "m3_profit_lock_applied");
      DataExportCsvAdd(header, "m3_profit_lock_block_reason");
      DataExportCsvAdd(header, "m3_profit_lock_update_time");
      const int header_columns = DataExportCsvColumnCount(header);
      if(header_columns != DataExportStrategyTestColumnCount())
      {
         PrintFormat("[JTA CSV] STRATEGY TEST HEADER COLUMN ERROR | expected=%d actual=%d",
                     DataExportStrategyTestColumnCount(), header_columns);
         // v8.219: never leave a zero-byte integrated CSV on schema mismatch.
         // Persist the generated header for diagnosis, then abort row writing safely.
         FileWriteString(handle, header + "\r\n");
         FileFlush(handle);
         FileClose(handle);
         return;
      }
      FileWriteString(handle, header + "\r\n");
   }

   string selected_direction = "BOTH";
   if(g_trade_direction == TRADE_LONG_ONLY) selected_direction = "LONG_ONLY";
   else if(g_trade_direction == TRADE_SHORT_ONLY) selected_direction = "SHORT_ONLY";

   const JTA_DirectionStrengthResult strength = DataExportDirectionStrength(side);
   const double csv_ma7 = DataExportBufferValue(g_add_ma_handle, 0, 1);
   const double csv_ma22 = DataExportBufferValue(g_slow_ma_handle, 0, 1);
   const double csv_ma70 = DataExportBufferValue(g_ma70_handle, 0, 1);
   const double csv_ma111 = DataExportBufferValue(g_ma111_handle, 0, 1);

   string row = "";
   DataExportAddContextRow(row);
   DataExportCsvAdd(row, TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS));
   DataExportCsvAdd(row, _Symbol);
   DataExportCsvAdd(row, (string)InpMagicNumber);
   DataExportCsvAdd(row, TradeLogStrategyName());
   DataExportCsvAdd(row, side > 0 ? "LONG" : side < 0 ? "SHORT" : "NONE");
   DataExportCsvAdd(row, stage);
   DataExportCsvAdd(row, (string)signal_count);
   DataExportCsvAdd(row, (string)score);
   DataExportCsvAdd(row, JTA_DirectionStrengthName(strength.level));
   DataExportCsvAdd(row, (string)strength.score);
   DataExportCsvAdd(row, (string)strength.macd_score);
   DataExportCsvAdd(row, (string)strength.delta_score);
   DataExportCsvAdd(row, (string)strength.ma_score);
   DataExportCsvAdd(row, (string)strength.structure_score);
   DataExportCsvAdd(row, (string)strength.higher_tf_score);
   DataExportCsvAdd(row, strength.strengthening ? "YES" : "NO");
   DataExportCsvAdd(row, strength.weakening ? "YES" : "NO");
   DataExportCsvAdd(row, DataExportHoldStateName());
   DataExportCsvAdd(row, DataExportProfitProtectionStateName());
   DataExportCsvAdd(row, (string)g_hold_direction_score);
   DataExportCsvAdd(row, (string)g_hold_strong_score);
   DataExportCsvAdd(row, (string)g_hold_weakness_score);
   DataExportCsvAdd(row, DoubleToString(csv_ma7, _Digits));
   DataExportCsvAdd(row, DoubleToString(csv_ma22, _Digits));
   DataExportCsvAdd(row, DoubleToString(csv_ma70, _Digits));
   DataExportCsvAdd(row, DoubleToString(csv_ma111, _Digits));
   DataExportCsvAdd(row, DataExportMAState(csv_ma7, csv_ma22, csv_ma70, csv_ma111));
   DataExportCsvAdd(row, TradeLogStrategyName());
   DataExportCsvAdd(row, (string)g_last_long_score);
   DataExportCsvAdd(row, (string)g_last_short_score);
   DataExportCsvAdd(row, (string)g_last_long_confidence);
   DataExportCsvAdd(row, (string)g_last_short_confidence);
   DataExportCsvAdd(row, g_auto_trading ? "YES" : "NO");
   DataExportCsvAdd(row, g_signal_enabled ? "YES" : "NO");
   DataExportCsvAdd(row, g_mobile_alert ? "YES" : "NO");
   DataExportCsvAdd(row, selected_direction);
   DataExportCsvAdd(row, DataExportPreDirectionName());
   DataExportCsvAdd(row, g_auto_start_bias_active ? "YES" : "NO");
   DataExportCsvAdd(row, (string)ManagedPositionSide());
   DataExportCsvAdd(row, range_location >= 0.0 ? DoubleToString(range_location * 100.0, 2) : "NA");
   DataExportCsvAdd(row, (string)((long)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD)));
   DataExportCsvAdd(row, DataExportRangeStateName());
   DataExportCsvAdd(row, (string)g_range_internal_side);
   DataExportCsvAdd(row, (string)g_range_state_bars);
   const int required_signals = 3; // v8.00 execution truth
   DataExportCsvAdd(row, (string)required_signals);
   DataExportCsvAdd(row, signal_count >= required_signals ? "PASS" : "WAIT");
   DataExportCsvAdd(row, (string)InpEntryScore);
   DataExportCsvAdd(row, score >= InpEntryScore ? "PASS" : "FAIL");
   const bool opposite_bias = g_auto_start_bias_active &&
      ((side > 0 && g_auto_start_bias == AUTO_BIAS_SHORT) ||
       (side < 0 && g_auto_start_bias == AUTO_BIAS_LONG));
   DataExportCsvAdd(row, opposite_bias ? "YES" : "NO");
   DataExportCsvAdd(row, opposite_bias ? "NO" : "YES");
   DataExportCsvAdd(row, g_auto_start_bias_active ? DataExportPreDirectionName() :
                    (g_pre_direction_last_bias == "" ? "NEUTRAL" : g_pre_direction_last_bias));
   DataExportCsvAdd(row, (string)g_pre_direction_release_score);
   DataExportCsvAdd(row, g_pre_direction_release_condition);
   DataExportCsvAdd(row, g_pre_direction_bias_released ? "YES" : "NO");
   DataExportCsvAdd(row, g_pre_direction_release_block_reason);
   DataExportCsvAdd(row, (string)g_auto_start_bias_bars_seen);
   DataExportCsvAdd(row, DataExportDecisionReasonCategory(blocked_reason));
   DataExportCsvAdd(row, g_status);

   string expected_trend_direction = "NONE";
   string market_regime = "TRANSITION";
   const string ma_state = DataExportMAState(csv_ma7, csv_ma22, csv_ma70, csv_ma111);
   if(ma_state == "BULL_STACK" || (strength.score >= 65 && side > 0))
   {
      expected_trend_direction = "LONG";
      market_regime = "TREND_UP";
   }
   else if(ma_state == "BEAR_STACK" || (strength.score >= 65 && side < 0))
   {
      expected_trend_direction = "SHORT";
      market_regime = "TREND_DOWN";
   }
   else if(g_csv_neutral_flow || g_csv_compressed_chop || g_csv_no_market_energy)
      market_regime = "RANGE_AMBIGUOUS";
   else if(TradeLogStrategyName() == "RANGE")
      market_regime = "RANGE_VALID";

   const bool common_range_gate_pass =
      !(g_csv_neutral_flow || g_csv_compressed_chop || g_csv_no_market_energy) &&
      (side > 0 ? g_csv_direction_long_allowed :
       side < 0 ? g_csv_direction_short_allowed : false);
   const string selected_gate_reason = side > 0 ? g_csv_range_long_gate_reason :
                                       side < 0 ? g_csv_range_short_gate_reason : "NO_DIRECTION";
   const bool signal_generated_before_gate =
      (score > 0 || signal_count > 0 || StringFind(stage, "SIGNAL") >= 0 ||
       StringFind(stage, "DECISION") >= 0 || StringFind(stage, "GATE") >= 0);
   const bool signal_allowed_after_gate =
      TradeLogStrategyName() != "RANGE" ? true : common_range_gate_pass;
   string trend_match = "NA";
   if(expected_trend_direction != "NONE" && side != 0)
      trend_match = ((side > 0 && expected_trend_direction == "LONG") ||
                     (side < 0 && expected_trend_direction == "SHORT")) ? "YES" : "NO";

   DataExportCsvAdd(row, market_regime);
   DataExportCsvAdd(row, expected_trend_direction);
   DataExportCsvAdd(row, trend_match);
   DataExportCsvAdd(row, g_csv_neutral_flow ? "YES" : "NO");
   DataExportCsvAdd(row, g_csv_compressed_chop ? "YES" : "NO");
   DataExportCsvAdd(row, g_csv_no_market_energy ? "YES" : "NO");
   DataExportCsvAdd(row, g_csv_relative_energy_ok ? "YES" : "NO");
   DataExportCsvAdd(row, g_csv_real_energy_ok ? "YES" : "NO");
   DataExportCsvAdd(row, g_csv_direction_flow_long_ok ? "YES" : "NO");
   DataExportCsvAdd(row, g_csv_direction_flow_short_ok ? "YES" : "NO");
   DataExportCsvAdd(row, DoubleToString(g_csv_relative_range_ratio,4));
   DataExportCsvAdd(row, DoubleToString(g_csv_relative_macd_ratio,4));
   DataExportCsvAdd(row, DoubleToString(g_csv_relative_delta_ratio,4));
   DataExportCsvAdd(row, g_csv_direction_long_allowed ? "YES" : "NO");
   DataExportCsvAdd(row, g_csv_direction_short_allowed ? "YES" : "NO");
   DataExportCsvAdd(row, (string)g_csv_long_direction_quality);
   DataExportCsvAdd(row, (string)g_csv_short_direction_quality);
   DataExportCsvAdd(row, common_range_gate_pass ? "YES" : "NO");
   DataExportCsvAdd(row, selected_gate_reason);
   DataExportCsvAdd(row, signal_generated_before_gate ? "YES" : "NO");
   DataExportCsvAdd(row, signal_allowed_after_gate ? "YES" : "NO");
   DataExportCsvAdd(row, order_requested ? "YES" : "NO");
   DataExportCsvAdd(row, order_result ? "SUCCESS" : "NO");
   DataExportCsvAdd(row, (string)order_retcode);
   DataExportCsvAdd(row, final_decision);
   DataExportCsvAdd(row, blocked_reason);
   DataExportCsvAdd(row, (string)MathMax(1, InpRangeSignalWindowBars));
   DataExportCsvAdd(row, g_csv_counter_bar_time > 0 ?
                    TimeToString(g_csv_counter_bar_time, TIME_DATE|TIME_SECONDS) : "");
   DataExportCsvAdd(row, g_csv_counter_raw_long_confirmed ? "YES" : "NO");
   DataExportCsvAdd(row, g_csv_counter_raw_short_confirmed ? "YES" : "NO");
   DataExportCsvAdd(row, g_csv_counter_countable_long ? "YES" : "NO");
   DataExportCsvAdd(row, g_csv_counter_countable_short ? "YES" : "NO");
   DataExportCsvAdd(row, (string)g_csv_counter_long_before);
   DataExportCsvAdd(row, (string)g_csv_counter_short_before);
   DataExportCsvAdd(row, (string)g_csv_counter_long_after);
   DataExportCsvAdd(row, (string)g_csv_counter_short_after);
   DataExportCsvAdd(row, (string)g_csv_counter_long_last_shift);
   DataExportCsvAdd(row, (string)g_csv_counter_short_last_shift);
   DataExportCsvAdd(row, (string)g_csv_counter_long_first_shift);
   DataExportCsvAdd(row, (string)g_csv_counter_short_first_shift);
   DataExportCsvAdd(row, g_csv_counter_long_first_time > 0 ?
                    TimeToString(g_csv_counter_long_first_time, TIME_DATE|TIME_SECONDS) : "");
   DataExportCsvAdd(row, g_csv_counter_short_first_time > 0 ?
                    TimeToString(g_csv_counter_short_first_time, TIME_DATE|TIME_SECONDS) : "");
   DataExportCsvAdd(row, g_csv_counter_long_expired ? "YES" : "NO");
   DataExportCsvAdd(row, g_csv_counter_short_expired ? "YES" : "NO");
   DataExportCsvAdd(row, (string)g_csv_counter_opposite_decay);
   DataExportCsvAdd(row, g_csv_counter_action);
   DataExportCsvAdd(row, g_csv_counter_reset_reason);
   DataExportCsvAdd(row, g_range_direction_confirm_signal_bar > 0 ?
                    TimeToString(g_range_direction_confirm_signal_bar, TIME_DATE|TIME_SECONDS) : "");
   DataExportCsvAdd(row, DoubleToString(g_range_direction_confirm_high, _Digits));
   DataExportCsvAdd(row, DoubleToString(g_range_direction_confirm_low, _Digits));
   DataExportCsvAdd(row, g_range_break_confirm_bar_time > 0 ?
                    TimeToString(g_range_break_confirm_bar_time, TIME_DATE|TIME_SECONDS) : "");
   DataExportCsvAdd(row, DoubleToString(g_range_break_confirm_high, _Digits));
   DataExportCsvAdd(row, DoubleToString(g_range_break_confirm_low, _Digits));
   DataExportCsvAdd(row, DoubleToString(g_range_break_confirm_close, _Digits));
   DataExportCsvAdd(row, DoubleToString(g_range_break_reference_price, _Digits));
   DataExportCsvAdd(row, DoubleToString(g_range_break_distance, _Digits));
   DataExportCsvAdd(row, g_range_break_confirmed ? "YES" : "NO");
   DataExportCsvAdd(row, g_range_break_order_sent ? "YES" : "NO");
   DataExportCsvAdd(row, g_range_break_order_result ? "SUCCESS" :
                    (g_range_break_order_sent ? "FAILED_OR_PENDING" : "NO"));
   DataExportCsvAdd(row, DoubleToString(g_range_break_order_price, _Digits));

   int lifecycle_side = ManagedPositionSide();
   double lifecycle_volume = 0.0, lifecycle_average = 0.0;
   double lifecycle_sl = 0.0, lifecycle_tp = 0.0;
   datetime lifecycle_first_time = 0;
   int lifecycle_group_side = 0;
   ManagedGroupInfo(lifecycle_group_side, lifecycle_volume, lifecycle_average,
                    lifecycle_sl, lifecycle_tp, lifecycle_first_time);
   if(lifecycle_side == 0) lifecycle_side = lifecycle_group_side;

   double lifecycle_floating = 0.0;
   if(PositionSelect(_Symbol) &&
      (ulong)PositionGetInteger(POSITION_MAGIC) == InpMagicNumber)
      lifecycle_floating = PositionGetDouble(POSITION_PROFIT) +
                           PositionGetDouble(POSITION_SWAP);

   const datetime lifecycle_event_time = g_test_csv_lifecycle_active ?
      g_test_csv_event_time : TimeCurrent();
   const int lifecycle_hold_seconds = lifecycle_first_time > 0 ?
      (int)MathMax(0, lifecycle_event_time - lifecycle_first_time) : 0;
   const int lifecycle_hold_bars = lifecycle_hold_seconds /
      MathMax(1, PeriodSeconds(g_calc_tf));
   const double lifecycle_quote = lifecycle_side > 0 ?
      SymbolInfoDouble(_Symbol, SYMBOL_BID) :
      lifecycle_side < 0 ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : 0.0;
   const double lifecycle_current_r =
      (lifecycle_side != 0 && g_initial_entry_price > 0.0 &&
       g_initial_r_distance > 0.0 && lifecycle_quote > 0.0) ?
      (lifecycle_side > 0 ?
       (lifecycle_quote-g_initial_entry_price)/g_initial_r_distance :
       (g_initial_entry_price-lifecycle_quote)/g_initial_r_distance) : 0.0;
   const string lifecycle_profile = g_reentry_protection_active ? "REENTRY" :
      (g_has_add_entry ? "ADD_ENTRY" : "INITIAL");

   DataExportCsvAdd(row, g_test_csv_lifecycle_active ? g_test_csv_event_type : "SIGNAL_DECISION");
   DataExportCsvAdd(row, (string)(g_test_csv_lifecycle_active ? g_test_csv_position_id : 0));
   DataExportCsvAdd(row, TimeToString(lifecycle_event_time, TIME_DATE|TIME_SECONDS));
   DataExportCsvAdd(row, DoubleToString(g_test_csv_lifecycle_active ? g_test_csv_event_price : 0.0, _Digits));
   DataExportCsvAdd(row, DoubleToString(g_test_csv_lifecycle_active ? g_test_csv_event_volume : 0.0, 2));
   DataExportCsvAdd(row, DoubleToString(g_test_csv_lifecycle_active ? g_test_csv_event_profit : 0.0, 2));
   DataExportCsvAdd(row, DoubleToString(lifecycle_floating, 2));
   DataExportCsvAdd(row, DoubleToString(lifecycle_volume, 2));
   DataExportCsvAdd(row, DoubleToString(lifecycle_average, _Digits));
   DataExportCsvAdd(row, DoubleToString(lifecycle_sl, _Digits));
   DataExportCsvAdd(row, DoubleToString(lifecycle_tp, _Digits));
   DataExportCsvAdd(row, DoubleToString(g_initial_r_distance, _Digits));
   DataExportCsvAdd(row, DoubleToString(lifecycle_current_r, 4));
   DataExportCsvAdd(row, DoubleToString(g_highest_profit_r, 4));
   DataExportCsvAdd(row, DoubleToString(g_protected_sl, _Digits));
   DataExportCsvAdd(row, g_test_csv_lifecycle_active ? g_test_csv_previous_state : DataExportHoldStateName());
   DataExportCsvAdd(row, g_test_csv_lifecycle_active ? g_test_csv_current_state : DataExportHoldStateName());
   DataExportCsvAdd(row, (string)lifecycle_hold_seconds);
   DataExportCsvAdd(row, (string)lifecycle_hold_bars);
   DataExportCsvAdd(row, (string)g_additional_entry_count);
   DataExportCsvAdd(row, g_csv_add_enabled ? "YES" : "NO");
   DataExportCsvAdd(row, (string)g_max_additional_entries);
   DataExportCsvAdd(row, (string)g_csv_add_count_before);
   DataExportCsvAdd(row, (string)g_csv_add_count_after);
   DataExportCsvAdd(row, (string)g_csv_add_capacity_remaining);
   DataExportCsvAdd(row, (string)g_csv_add_stage);
   DataExportCsvAdd(row, (string)g_csv_add_signal_count);
   DataExportCsvAdd(row, (string)g_csv_add_signal_required);
   DataExportCsvAdd(row, g_csv_add_same_direction_signal ? "YES" : "NO");
   DataExportCsvAdd(row, g_csv_add_opposite_direction_signal ? "YES" : "NO");
   DataExportCsvAdd(row, g_csv_add_exit_safe ? "YES" : "NO");
   DataExportCsvAdd(row, g_csv_add_attempted ? "YES" : "NO");
   DataExportCsvAdd(row, g_csv_add_result ? "SUCCESS" : "NO");
   DataExportCsvAdd(row, (string)g_csv_add_retcode);
   DataExportCsvAdd(row, g_csv_add_block_reason);
   DataExportCsvAdd(row, g_csv_add_signal_bar_time > 0 ? TimeToString(g_csv_add_signal_bar_time, TIME_DATE|TIME_SECONDS) : "");
   DataExportCsvAdd(row, (string)g_csv_add_bars_since_entry);
   DataExportCsvAdd(row, DoubleToString(g_csv_add_progress_r, 4));
   DataExportCsvAdd(row, DoubleToString(g_csv_add_requested_volume, 8));
   DataExportCsvAdd(row, DoubleToString(g_csv_add_fill_price, _Digits));
   DataExportCsvAdd(row, lifecycle_profile);
   // v8.89: the integrated CSV remains the single validation source. Preserve
   // the full legacy decision columns and append the canonical M3 state/input
   // snapshot so Signal -> Trigger -> AUTO -> Position can be reconstructed
   // from this file alone. No additional indicator reads are performed here.
   const bool m3_data_ready = (ArraySize(g_ms_rates) > 1);
   const int m3_dir = g_m3_segment.direction;
   DataExportCsvAdd(row, g_market_snapshot.closed_bar_time > 0 ? TimeToString(g_market_snapshot.closed_bar_time,TIME_DATE|TIME_SECONDS) : "");
   DataExportCsvAdd(row, (string)g_m3_segment.id);
   DataExportCsvAdd(row, (string)m3_dir);
   DataExportCsvAdd(row, (string)g_m3_segment.phase);
   DataExportCsvAdd(row, (string)g_m3_segment.regime);
   DataExportCsvAdd(row, g_m3_segment.structure_valid ? "YES" : "NO");
   DataExportCsvAdd(row, g_m3_segment.structure_break ? "YES" : "NO");
   DataExportCsvAdd(row, g_m3_segment.structure_episode ? "YES" : "NO");
   DataExportCsvAdd(row, (string)g_m3_segment.episode_state);
   const bool m3_invalidation_event=(g_m3_segment.episode_state==M3_EP_INVALIDATED &&
                                     g_m3_segment.invalidation_time>0 &&
                                     g_market_snapshot.closed_bar_time==g_m3_segment.invalidation_time);
   DataExportCsvAdd(row, m3_invalidation_event ? "YES" : "NO");
   DataExportCsvAdd(row, g_m3_segment.invalidation_time>0 ? TimeToString(g_m3_segment.invalidation_time,TIME_DATE|TIME_SECONDS) : "");
   DataExportCsvAdd(row, g_m3_segment.invalidation_reason);
   DataExportCsvAdd(row, g_m3_segment.persistence_confirmed ? "YES" : "NO");
   DataExportCsvAdd(row, g_m3_segment.persistence_time > 0 ? TimeToString(g_m3_segment.persistence_time,TIME_DATE|TIME_SECONDS) : "");
   DataExportCsvAdd(row, g_m3_segment.pullback_active ? "YES" : "NO");
   DataExportCsvAdd(row, g_m3_segment.pullback_episode ? "YES" : "NO");
   DataExportCsvAdd(row, g_m3_segment.pullback_held ? "YES" : "NO");
   DataExportCsvAdd(row, g_m3_segment.pullback_start_time > 0 ? TimeToString(g_m3_segment.pullback_start_time,TIME_DATE|TIME_SECONDS) : "");
   DataExportCsvAdd(row, g_m3_segment.pullback_held_time > 0 ? TimeToString(g_m3_segment.pullback_held_time,TIME_DATE|TIME_SECONDS) : "");
   DataExportCsvAdd(row, DoubleToString(g_m3_segment.pullback_extreme,_Digits));
   DataExportCsvAdd(row, DoubleToString(g_m3_segment.pullback_reference,_Digits));
   DataExportCsvAdd(row, g_m3_segment.reacceleration_episode ? "YES" : "NO");
   DataExportCsvAdd(row, g_m3_segment.reaccel_time > 0 ? TimeToString(g_m3_segment.reaccel_time,TIME_DATE|TIME_SECONDS) : "");
   DataExportCsvAdd(row, g_m3_segment.trigger_long ? "YES" : "NO");
   DataExportCsvAdd(row, g_m3_segment.trigger_short ? "YES" : "NO");
   DataExportCsvAdd(row, g_m3_segment.trigger_time > 0 ? TimeToString(g_m3_segment.trigger_time,TIME_DATE|TIME_SECONDS) : "");
   DataExportCsvAdd(row, g_m3_segment.trigger_consumed ? "YES" : "NO");
   DataExportCsvAdd(row, (string)g_m3_segment.last_trigger_event_side);
   DataExportCsvAdd(row, g_m3_segment.last_trigger_event_time > 0 ? TimeToString(g_m3_segment.last_trigger_event_time,TIME_DATE|TIME_SECONDS) : "");
   DataExportCsvAdd(row, DoubleToString(g_m3_segment.structure_high,_Digits));
   DataExportCsvAdd(row, g_m3_segment.structure_high_time > 0 ? TimeToString(g_m3_segment.structure_high_time,TIME_DATE|TIME_SECONDS) : "");
   DataExportCsvAdd(row, DoubleToString(g_m3_segment.structure_low,_Digits));
   DataExportCsvAdd(row, g_m3_segment.structure_low_time > 0 ? TimeToString(g_m3_segment.structure_low_time,TIME_DATE|TIME_SECONDS) : "");
   DataExportCsvAdd(row, DoubleToString(g_m3_segment.protected_swing_low,_Digits));
   DataExportCsvAdd(row, DoubleToString(g_m3_segment.protected_swing_high,_Digits));
   DataExportCsvAdd(row, g_m3_segment.external_bullish ? "YES" : "NO");
   DataExportCsvAdd(row, g_m3_segment.external_bearish ? "YES" : "NO");
   // v8.272 observation-only global 1/1 internal structure audit.
   DataExportCsvAdd(row, g_m3_int_hh ? "YES" : "NO");
   DataExportCsvAdd(row, g_m3_int_hl ? "YES" : "NO");
   DataExportCsvAdd(row, g_m3_int_lh ? "YES" : "NO");
   DataExportCsvAdd(row, g_m3_int_ll ? "YES" : "NO");
   DataExportCsvAdd(row, M3InternalLongStructureReady() ? "YES" : "NO");
   DataExportCsvAdd(row, M3InternalShortStructureReady() ? "YES" : "NO");
   DataExportCsvAdd(row, g_m3_int_last_high>0.0 ? DoubleToString(g_m3_int_last_high,_Digits) : "");
   DataExportCsvAdd(row, g_m3_int_prev_high>0.0 ? DoubleToString(g_m3_int_prev_high,_Digits) : "");
   DataExportCsvAdd(row, g_m3_int_last_low>0.0 ? DoubleToString(g_m3_int_last_low,_Digits) : "");
   DataExportCsvAdd(row, g_m3_int_prev_low>0.0 ? DoubleToString(g_m3_int_prev_low,_Digits) : "");
   DataExportCsvAdd(row, g_m3_int_last_high_time>0 ? TimeToString(g_m3_int_last_high_time,TIME_DATE|TIME_SECONDS) : "");
   DataExportCsvAdd(row, g_m3_int_prev_high_time>0 ? TimeToString(g_m3_int_prev_high_time,TIME_DATE|TIME_SECONDS) : "");
   DataExportCsvAdd(row, g_m3_int_last_low_time>0 ? TimeToString(g_m3_int_last_low_time,TIME_DATE|TIME_SECONDS) : "");
   DataExportCsvAdd(row, g_m3_int_prev_low_time>0 ? TimeToString(g_m3_int_prev_low_time,TIME_DATE|TIME_SECONDS) : "");
   DataExportCsvAdd(row, g_m3_segment.internal_pullback ? "YES" : "NO");
   DataExportCsvAdd(row, g_m3_segment.internal_reaccel ? "YES" : "NO");
   DataExportCsvAdd(row, g_m3_segment.setup_long ? "YES" : "NO");
   DataExportCsvAdd(row, g_m3_segment.setup_short ? "YES" : "NO");
   DataExportCsvAdd(row, (m3_data_ready && ArraySize(g_ms_macd_wave)>1) ? DoubleToString(g_ms_macd_wave[1],8) : "");
   DataExportCsvAdd(row, (m3_data_ready && ArraySize(g_ms_macd)>1) ? DoubleToString(g_ms_macd[1],8) : "");
   DataExportCsvAdd(row, (m3_data_ready && ArraySize(g_ms_slow_ma)>1) ? DoubleToString(g_ms_slow_ma[1],_Digits) : "");
   DataExportCsvAdd(row, (m3_data_ready && ArraySize(g_ms_delta)>1) ? DoubleToString(g_ms_delta[1],8) : "");
   DataExportCsvAdd(row, (m3_data_ready && ArraySize(g_ms_delta_volume)>1) ? DoubleToString(g_ms_delta_volume[1],8) : "");
   DataExportCsvAdd(row, (m3_data_ready) ? DoubleToString(g_ms_rates[1].close,_Digits) : "");

   // v8.122: export the exact ACCEL state/event from M3SegmentEngine.
   const bool accel_event=(g_m3_segment.display_accel_time>0 &&
                           g_m3_segment.display_accel_time==g_market_snapshot.closed_bar_time);
   const bool accel_macd_ready=(m3_data_ready &&
                                 ArraySize(g_ms_macd_wave)>3 &&
                                 ArraySize(g_ms_macd)>3 &&
                                 ArraySize(g_ms_macd_direction)>1 &&
                                 ArraySize(g_ms_rates)>2);
   const double accel_wave0=accel_macd_ready ? g_ms_macd_wave[1] : 0.0;
   const double accel_wave1=accel_macd_ready ? g_ms_macd_wave[2] : 0.0;
   const double accel_wave2=accel_macd_ready ? g_ms_macd_wave[3] : 0.0;
   const double accel_signal0=accel_macd_ready ? g_ms_macd[1] : 0.0;
   const double accel_signal1=accel_macd_ready ? g_ms_macd[2] : 0.0;
   const double accel_signal2=accel_macd_ready ? g_ms_macd[3] : 0.0;
   const double accel_hist0=accel_wave0-accel_signal0;
   const double accel_hist1=accel_wave1-accel_signal1;
   const double accel_hist2=accel_wave2-accel_signal2;
   const double accel_wave_delta=accel_wave0-accel_wave1;
   const double accel_wave_delta_prev=accel_wave1-accel_wave2;
   const double accel_hist_delta=accel_hist0-accel_hist1;
   const double accel_hist_delta_prev=accel_hist1-accel_hist2;
   const double accel_price_delta=accel_macd_ready ?
                                   (g_ms_rates[1].close-g_ms_rates[2].close) : 0.0;
   const bool accel_long_price_drive=accel_macd_ready &&
                                     g_ms_rates[1].close>g_ms_rates[2].close &&
                                     g_ms_rates[1].high>=g_ms_rates[2].high;
   const bool accel_short_price_drive=accel_macd_ready &&
                                      g_ms_rates[1].close<g_ms_rates[2].close &&
                                      g_ms_rates[1].low<=g_ms_rates[2].low;
   const double accel_macd_direction=accel_macd_ready ? g_ms_macd_direction[1] : 0.0;
   const bool accel_long_zero=(accel_wave0>0.0);
   const bool accel_short_zero=(accel_wave0<0.0);
   const bool accel_long_wave_exp=(accel_wave_delta>0.0) &&
                                  ((accel_wave_delta>accel_wave_delta_prev) || (accel_wave1<=accel_wave2));
   const bool accel_short_wave_exp=(accel_wave_delta<0.0) &&
                                   ((accel_wave_delta<accel_wave_delta_prev) || (accel_wave1>=accel_wave2));
   const bool accel_long_hist_exp=(accel_hist_delta>0.0) &&
                                  ((accel_hist_delta>accel_hist_delta_prev) || (accel_hist1<=accel_hist2));
   const bool accel_short_hist_exp=(accel_hist_delta<0.0) &&
                                   ((accel_hist_delta<accel_hist_delta_prev) || (accel_hist1>=accel_hist2));
   const bool accel_long_hist_support=(accel_hist0>=0.0 || accel_hist_delta>=0.0);
   const bool accel_short_hist_support=(accel_hist0<=0.0 || accel_hist_delta<=0.0);
   const bool accel_long_macd_expand=accel_long_zero && accel_wave_delta>0.0 &&
                                     accel_macd_direction>0.5 && accel_long_hist_support &&
                                     (accel_long_wave_exp || accel_long_hist_exp);
   const bool accel_short_macd_expand=accel_short_zero && accel_wave_delta<0.0 &&
                                      accel_macd_direction<-0.5 && accel_short_hist_support &&
                                      (accel_short_wave_exp || accel_short_hist_exp);
   string accel_regime="";
   if(accel_wave0>0.0) accel_regime="POSITIVE";
   else if(accel_wave0<0.0) accel_regime="NEGATIVE";
   else accel_regime="ZERO";
   string accel_signal="";
   if(accel_event && g_m3_segment.display_accel_side==M3_SEG_LONG) accel_signal="LONG ACCEL";
   else if(accel_event && g_m3_segment.display_accel_side==M3_SEG_SHORT) accel_signal="SHORT ACCEL";
   DataExportCsvAdd(row, g_m3_segment.display_accel_long_active ? "YES" : "NO");
   DataExportCsvAdd(row, g_m3_segment.display_accel_short_active ? "YES" : "NO");
   DataExportCsvAdd(row, g_m3_segment.display_accel_long_break_active ? "YES" : "NO");
   DataExportCsvAdd(row, g_m3_segment.display_accel_short_break_active ? "YES" : "NO");
   DataExportCsvAdd(row, DoubleToString(g_m3_segment.display_accel_long_break_level,_Digits));
   DataExportCsvAdd(row, DoubleToString(g_m3_segment.display_accel_short_break_level,_Digits));
   DataExportCsvAdd(row, g_m3_segment.display_accel_long_break_time>0 ? TimeToString(g_m3_segment.display_accel_long_break_time,TIME_DATE|TIME_SECONDS) : "");
   DataExportCsvAdd(row, g_m3_segment.display_accel_short_break_time>0 ? TimeToString(g_m3_segment.display_accel_short_break_time,TIME_DATE|TIME_SECONDS) : "");
   DataExportCsvAdd(row, (string)g_m3_segment.display_accel_side);
   DataExportCsvAdd(row, g_m3_segment.display_accel_time>0 ? TimeToString(g_m3_segment.display_accel_time,TIME_DATE|TIME_SECONDS) : "");
   DataExportCsvAdd(row, accel_event ? "YES" : "NO");
   DataExportCsvAdd(row, accel_regime);
   DataExportCsvAdd(row, DoubleToString(accel_wave_delta,8));
   DataExportCsvAdd(row, DoubleToString(accel_hist0,8));
   DataExportCsvAdd(row, DoubleToString(accel_hist_delta,8));
   DataExportCsvAdd(row, accel_long_price_drive ? "LONG" : accel_short_price_drive ? "SHORT" : "NONE");
   DataExportCsvAdd(row, accel_long_macd_expand ? "YES" : "NO");
   DataExportCsvAdd(row, accel_short_macd_expand ? "YES" : "NO");
   DataExportCsvAdd(row, accel_signal);
   DataExportCsvAdd(row, DoubleToString(g_m3_accel_audit_structure_high,_Digits));
   DataExportCsvAdd(row, DoubleToString(g_m3_accel_audit_structure_low,_Digits));
   DataExportCsvAdd(row, g_m3_accel_audit_structure_high_source);
   DataExportCsvAdd(row, g_m3_accel_audit_structure_low_source);
   DataExportCsvAdd(row, g_m3_accel_audit_raw_long_break ? "YES" : "NO");
   DataExportCsvAdd(row, g_m3_accel_audit_raw_short_break ? "YES" : "NO");
   DataExportCsvAdd(row, (string)g_m3_accel_audit_watch_owner_side);
   DataExportCsvAdd(row, g_m3_accel_audit_watch_owner_time>0 ? TimeToString(g_m3_accel_audit_watch_owner_time,TIME_DATE|TIME_SECONDS) : "");
   DataExportCsvAdd(row, g_m3_accel_audit_long_watch_authorized ? "YES" : "NO");
   DataExportCsvAdd(row, g_m3_accel_audit_short_watch_authorized ? "YES" : "NO");
   DataExportCsvAdd(row, DoubleToString(g_m3_accel_audit_prior_long_accel_high,_Digits));
   DataExportCsvAdd(row, DoubleToString(g_m3_accel_audit_prior_short_accel_low,_Digits));
   DataExportCsvAdd(row, g_m3_accel_audit_long_price_extension ? "YES" : "NO");
   DataExportCsvAdd(row, g_m3_accel_audit_short_price_extension ? "YES" : "NO");
   DataExportCsvAdd(row, g_m3_accel_audit_emit_long ? "YES" : "NO");
   DataExportCsvAdd(row, g_m3_accel_audit_emit_short ? "YES" : "NO");
   DataExportCsvAdd(row, g_m3_accel_audit_long_block_reason);
   DataExportCsvAdd(row, g_m3_accel_audit_short_block_reason);

   // v8.141 M3 signal replay/audit fields. Use the same completed M3 bars that
   // M3SegmentEngine consumes; no extra indicator or market-data calls here.
   const bool m3_prev_ready=(ArraySize(g_ms_rates)>2);
   const MqlRates m3_now = m3_data_ready ? g_ms_rates[1] : g_ms_rates[0];
   const MqlRates m3_prev = m3_prev_ready ? g_ms_rates[2] : g_ms_rates[0];
   const double watch_wave_now=(m3_data_ready && ArraySize(g_ms_macd_wave)>1) ? g_ms_macd_wave[1] : 0.0;
   const double watch_wave_prev=(m3_prev_ready && ArraySize(g_ms_macd_wave)>2) ? g_ms_macd_wave[2] : 0.0;
   const double watch_signal_now=(m3_data_ready && ArraySize(g_ms_macd)>1) ? g_ms_macd[1] : 0.0;
   const double watch_signal_prev=(m3_prev_ready && ArraySize(g_ms_macd)>2) ? g_ms_macd[2] : 0.0;
   const double watch_hist_now=watch_wave_now-watch_signal_now;
   const double watch_hist_prev=watch_wave_prev-watch_signal_prev;
   const double watch_wave_delta=watch_wave_now-watch_wave_prev;
   const double watch_hist_delta=watch_hist_now-watch_hist_prev;
   const bool watch_long_high_ok=m3_prev_ready && m3_now.high>m3_prev.high;
   const bool watch_long_close_ok=m3_prev_ready && m3_now.close>m3_prev.close;
   // v8.153 audit mirrors the actual WATCH transition owner. Legacy histogram fields remain exported for comparison but histogram delta is
   // no longer a mandatory WATCH gate. Zero-side remains regime context.
   const bool watch_long_wave_side_ok=m3_prev_ready && watch_wave_now>0.0;
   const bool watch_long_wave_delta_ok=m3_prev_ready && watch_wave_delta>0.0;
   const bool watch_long_hist_delta_ok=m3_prev_ready && watch_hist_delta>0.0;
   const bool watch_short_low_ok=m3_prev_ready && m3_now.low<m3_prev.low;
   const bool watch_short_close_ok=m3_prev_ready && m3_now.close<m3_prev.close;
   const bool watch_short_wave_side_ok=m3_prev_ready && watch_wave_now<0.0;
   const bool watch_short_wave_delta_ok=m3_prev_ready && watch_wave_delta<0.0;
   const bool watch_short_hist_delta_ok=m3_prev_ready && watch_hist_delta<0.0;

   const double watch_ma22_now=(m3_data_ready && ArraySize(g_ms_slow_ma)>1) ? g_ms_slow_ma[1] : 0.0;
   const double watch_ma22_prev=(m3_prev_ready && ArraySize(g_ms_slow_ma)>2) ? g_ms_slow_ma[2] : watch_ma22_now;
   const double watch_ma22_dist_now=m3_now.close-watch_ma22_now;
   const double watch_ma22_dist_prev=m3_prev.close-watch_ma22_prev;
   const bool watch_long_ma22_improving=m3_prev_ready && (watch_ma22_dist_now>watch_ma22_dist_prev || watch_ma22_now>watch_ma22_prev);
   const bool watch_short_ma22_improving=m3_prev_ready && (watch_ma22_dist_now<watch_ma22_dist_prev || watch_ma22_now<watch_ma22_prev);
   const bool watch_delta_ready=(ArraySize(g_ms_delta)>2 && ArraySize(g_ms_delta_ema)>2);
   const bool watch_volume_ready=(ArraySize(g_ms_delta_volume)>8);
   const bool watch_long_delta_improving=watch_delta_ready && (g_ms_delta[1]>g_ms_delta[2] || g_ms_delta_ema[1]>g_ms_delta_ema[2]);
   const bool watch_short_delta_improving=watch_delta_ready && (g_ms_delta[1]<g_ms_delta[2] || g_ms_delta_ema[1]<g_ms_delta_ema[2]);
   double watch_volume_avg=0.0;
   int watch_volume_n=0;
   if(watch_volume_ready)
   {
      for(int watch_vi=2;watch_vi<=8;watch_vi++)
      {
         if(g_ms_delta_volume[watch_vi]>0.0)
         {
            watch_volume_avg+=g_ms_delta_volume[watch_vi];
            watch_volume_n++;
         }
      }
   }
   if(watch_volume_n>0) watch_volume_avg/=watch_volume_n;
   const bool watch_volume_improving=watch_volume_ready &&
      (g_ms_delta_volume[1]>g_ms_delta_volume[2] || (watch_volume_avg>0.0 && g_ms_delta_volume[1]>watch_volume_avg));
   const bool watch_long_context=watch_long_ma22_improving || watch_long_delta_improving || watch_volume_improving;
   const bool watch_short_context=watch_short_ma22_improving || watch_short_delta_improving || watch_volume_improving;
   const int watch_long_context_count=(watch_long_ma22_improving ? 1 : 0)+(watch_long_delta_improving ? 1 : 0)+(watch_volume_improving ? 1 : 0);
   const int watch_short_context_count=(watch_short_ma22_improving ? 1 : 0)+(watch_short_delta_improving ? 1 : 0)+(watch_volume_improving ? 1 : 0);
   const bool watch_long_candidate=watch_long_high_ok && watch_long_close_ok && watch_long_wave_side_ok && watch_long_wave_delta_ok && watch_long_context;
   const bool watch_short_candidate=watch_short_low_ok && watch_short_close_ok && watch_short_wave_side_ok && watch_short_wave_delta_ok && watch_short_context;
   // v8.253 cleanup: integrated WATCH audit and fallback leg ownership now
   // come from the same StateEvaluation/AUTO canonical ownership only.
   const bool watch_event=(g_assist_state.bar_time>0 &&
                           g_assist_state.bar_time==g_market_snapshot.closed_bar_time &&
                           g_assist_state.watch_pulse &&
                           g_assist_state.changed &&
                           (g_assist_state.state==JTA_ASSIST_REVERSAL_WATCH_UP ||
                            g_assist_state.state==JTA_ASSIST_REVERSAL_WATCH_DOWN));
   const int watch_side=watch_event ?
      (g_assist_state.state==JTA_ASSIST_REVERSAL_WATCH_UP ? M3_SEG_LONG : M3_SEG_SHORT) : 0;
   const bool watch_prezero_event=false;
   const string watch_event_origin=watch_event ? "STATE_EVALUATION" : "";
   const int leg_side=(g_m3_auto_signal_leg_side!=M3_SEG_NONE ?
      g_m3_auto_signal_leg_side :
      (g_assist_weak_watch_owner_side>0 ? M3_SEG_LONG :
       (g_assist_weak_watch_owner_side<0 ? M3_SEG_SHORT : 0)));
   string watch_event_id="";
   if(watch_event)
      watch_event_id=StringFormat("STATE-%I64d-WATCH-%s",(long)g_assist_state.bar_time,
         watch_side==M3_SEG_LONG ? "LONG" : "SHORT");
   string accel_event_id="";
   if(accel_event)
      accel_event_id=StringFormat("M3-%I64d-ACCEL-%s",(long)g_m3_segment.display_accel_time,g_m3_segment.display_accel_side==M3_SEG_LONG ? "LONG" : "SHORT");
   const bool accel_matches_leg=(accel_event && leg_side!=0 && g_m3_segment.display_accel_side==leg_side);
   const int audit_position_side=ManagedPositionSide();
   const bool audit_watch_informational=(watch_event && g_assist_state.watch_informational_repeat);
   const bool audit_prezero_reentry=(
      audit_watch_informational && audit_position_side==0 &&
      g_prezero_reentry_armed && g_prezero_reentry_side!=0 &&
      g_prezero_reentry_exit_time>0 &&
      g_market_snapshot.closed_bar_time>g_prezero_reentry_exit_time &&
      watch_side==(g_prezero_reentry_side>0 ? M3_SEG_LONG : M3_SEG_SHORT) &&
      g_assist_state.watch_observe_stage=="CONFIRMED");
   const bool audit_watch_canonical=(watch_event && (!audit_watch_informational || audit_prezero_reentry));
   // Mirror AUTO chronology for audit. Only a canonical WATCH (including the
   // v8.279 PREZERO CONFIRMED re-entry exception) refreshes the AUTO leg.
   const int audit_auto_leg_side=audit_watch_canonical ? watch_side : g_m3_auto_signal_leg_side;
   const datetime audit_auto_leg_start=audit_watch_canonical ? g_market_snapshot.closed_bar_time : g_m3_auto_signal_leg_start_time;
   const bool auto_accel_eligible=(accel_event && audit_auto_leg_side==g_m3_segment.display_accel_side &&
                                   audit_auto_leg_start>0 && g_market_snapshot.closed_bar_time>audit_auto_leg_start);
   string auto_signal_type="NONE";
   int auto_signal_side=0;
   string auto_decision="NONE";
   if(watch_event)
   {
      auto_signal_type=(audit_prezero_reentry ? "WATCH_PREZERO_REENTRY" : "WATCH");
      auto_signal_side=watch_side;
      if(audit_watch_informational && !audit_prezero_reentry)
         auto_decision="NONE_INFORMATIONAL_WATCH";
      else if(audit_position_side==0) auto_decision="INITIAL";
      else if(audit_position_side==-watch_side) auto_decision="EXIT_OPPOSITE_WATCH";
      else auto_decision="NONE_SAME_SIDE_WATCH";
   }
   else if(accel_event)
   {
      auto_signal_type="ACCEL";
      auto_signal_side=g_m3_segment.display_accel_side;
      if(!auto_accel_eligible) auto_decision="NONE_ACCEL_NOT_OWNED_OR_SAME_BAR";
      else if(audit_position_side==auto_signal_side) auto_decision="ADD";
      else if(audit_position_side==0) auto_decision="NONE_FLAT_ACCEL";
      else auto_decision="NONE_OPPOSITE_ACCEL";
   }
   else if(g_internal_momentum_event_time==g_market_snapshot.closed_bar_time &&
           g_internal_momentum_event_side!=0)
   {
      auto_signal_type="DIRECTION";
      auto_signal_side=g_internal_momentum_event_side;
      if(g_internal_momentum_watch_owner_side!=auto_signal_side)
         auto_decision="NONE_DIRECTION_NOT_OWNED";
      else if(audit_position_side==auto_signal_side)
         auto_decision=(g_additional_entry_filled_count<g_max_additional_entries ? "ADD" : "NONE_MAX_ADD");
      else if(audit_position_side==0) auto_decision="NONE_FLAT_DIRECTION";
      else auto_decision="NONE_OPPOSITE_DIRECTION";
   }
   const bool auto_order_expected=(auto_decision=="INITIAL" || auto_decision=="ADD" || auto_decision=="EXIT_OPPOSITE_WATCH");

   DataExportCsvAdd(row, m3_data_ready ? DoubleToString(m3_now.open,_Digits) : "");
   DataExportCsvAdd(row, m3_data_ready ? DoubleToString(m3_now.high,_Digits) : "");
   DataExportCsvAdd(row, m3_data_ready ? DoubleToString(m3_now.low,_Digits) : "");
   DataExportCsvAdd(row, m3_prev_ready ? DoubleToString(m3_prev.open,_Digits) : "");
   DataExportCsvAdd(row, m3_prev_ready ? DoubleToString(m3_prev.high,_Digits) : "");
   DataExportCsvAdd(row, m3_prev_ready ? DoubleToString(m3_prev.low,_Digits) : "");
   DataExportCsvAdd(row, m3_prev_ready ? DoubleToString(m3_prev.close,_Digits) : "");
   DataExportCsvAdd(row, watch_long_high_ok ? "YES" : "NO");
   DataExportCsvAdd(row, watch_long_close_ok ? "YES" : "NO");
   DataExportCsvAdd(row, watch_long_wave_side_ok ? "YES" : "NO");
   DataExportCsvAdd(row, watch_long_wave_delta_ok ? "YES" : "NO");
   DataExportCsvAdd(row, watch_long_hist_delta_ok ? "YES" : "NO");
   DataExportCsvAdd(row, watch_short_low_ok ? "YES" : "NO");
   DataExportCsvAdd(row, watch_short_close_ok ? "YES" : "NO");
   DataExportCsvAdd(row, watch_short_wave_side_ok ? "YES" : "NO");
   DataExportCsvAdd(row, watch_short_wave_delta_ok ? "YES" : "NO");
   DataExportCsvAdd(row, watch_short_hist_delta_ok ? "YES" : "NO");
   DataExportCsvAdd(row, watch_long_candidate ? "YES" : "NO");
   DataExportCsvAdd(row, watch_short_candidate ? "YES" : "NO");
   DataExportCsvAdd(row, (string)watch_long_context_count);
   DataExportCsvAdd(row, (string)watch_short_context_count);
   DataExportCsvAdd(row, watch_event_origin);
   DataExportCsvAdd(row, g_assist_state.bar_time>0 ? TimeToString(g_assist_state.bar_time,TIME_DATE|TIME_SECONDS) : "");
   DataExportCsvAdd(row, EnumToString(g_assist_state.timeframe));
   DataExportCsvAdd(row, AssistStateName(g_assist_state.state));
   DataExportCsvAdd(row, AssistStateName(g_assist_state.previous_state));
   DataExportCsvAdd(row, g_assist_state.watch_pulse ? "YES" : "NO");
   DataExportCsvAdd(row, g_assist_state.changed ? "YES" : "NO");
   DataExportCsvAdd(row, (string)g_assist_state.direction_anchor);
   DataExportCsvAdd(row, (string)g_assist_state.established_side);
   DataExportCsvAdd(row, g_assist_state.established_time>0 ? TimeToString(g_assist_state.established_time,TIME_DATE|TIME_SECONDS) : "");
   DataExportCsvAdd(row, (string)g_range_persistent_direction);
   DataExportCsvAdd(row, (string)g_assist_state.expected_bar_seconds);
   DataExportCsvAdd(row, (string)g_assist_state.market_gap_seconds);
   DataExportCsvAdd(row, g_assist_state.data_discontinuity ? "YES" : "NO");
   DataExportCsvAdd(row, g_assist_state.scheduled_market_gap ? "YES" : "NO");
   DataExportCsvAdd(row, g_assist_state.reason);
   DataExportCsvAdd(row, DoubleToString(g_assist_state.raw_macd,8));
   DataExportCsvAdd(row, DoubleToString(g_assist_state.macd_base,8));
   DataExportCsvAdd(row, DoubleToString(g_assist_state.macd_wave,8));
   // v8.176: canonical closed-M3 MACD replay fields; audit only.
   DataExportCsvAdd(row, DoubleToString(g_assist_state.macd_wave-g_assist_state.macd_base,8));
   DataExportCsvAdd(row, (string)g_assist_state.macd_zero_state);
   DataExportCsvAdd(row, (string)g_assist_state.raw_up_steps);
   DataExportCsvAdd(row, (string)g_assist_state.raw_down_steps);
   DataExportCsvAdd(row, (g_assist_state.bar_time>0 &&
                          g_assist_state.bar_time==g_market_snapshot.closed_bar_time) ? "YES" : "NO");
   DataExportCsvAdd(row, DoubleToString(g_assist_state.macd_wave_change_1,8));
   DataExportCsvAdd(row, DoubleToString(g_assist_state.macd_wave_change_3,8));
   DataExportCsvAdd(row, DoubleToString(g_assist_state.macd_base_change_1,8));
   DataExportCsvAdd(row, DoubleToString(g_assist_state.macd_base_change_3,8));
   DataExportCsvAdd(row, DoubleToString(g_assist_state.macd_base_travel_3,8));
   DataExportCsvAdd(row, DoubleToString(g_assist_state.macd_base_efficiency_3,8));
   DataExportCsvAdd(row, DoubleToString(g_assist_state.macd_wave_travel_3,8));
   DataExportCsvAdd(row, DoubleToString(g_assist_state.macd_wave_efficiency_3,8));
   DataExportCsvAdd(row, DoubleToString(g_assist_state.macd_change_1,8));
   DataExportCsvAdd(row, DoubleToString(g_assist_state.macd_change_3,8));
   DataExportCsvAdd(row, DoubleToString(g_assist_state.macd_transition_progress,8));
   DataExportCsvAdd(row, (string)g_assist_state.macd_direction);
   DataExportCsvAdd(row, g_assist_state.macd_transition_up ? "YES" : "NO");
   DataExportCsvAdd(row, g_assist_state.macd_transition_down ? "YES" : "NO");
   DataExportCsvAdd(row, g_assist_state.long_transition_progress ? "YES" : "NO");
   DataExportCsvAdd(row, g_assist_state.short_transition_progress ? "YES" : "NO");
   DataExportCsvAdd(row, g_assist_state.early_opposite_watch_shadow ? "YES" : "NO");
   DataExportCsvAdd(row, g_assist_state.early_opposite_watch_pulse ? "YES" : "NO");
   DataExportCsvAdd(row, g_assist_state.early_opposite_watch_side>0 ? "LONG" : g_assist_state.early_opposite_watch_side<0 ? "SHORT" : "NONE");
   DataExportCsvAdd(row, g_assist_state.early_opposite_watch_stage);
   DataExportCsvAdd(row, g_assist_state.early_opposite_watch_classification);
   DataExportCsvAdd(row, g_assist_state.early_candidate_track_active ? "YES" : "NO");
   DataExportCsvAdd(row, g_assist_state.early_candidate_track_side>0 ? "LONG" : g_assist_state.early_candidate_track_side<0 ? "SHORT" : "NONE");
   DataExportCsvAdd(row, g_assist_state.early_candidate_start_time>0 ? TimeToString(g_assist_state.early_candidate_start_time,TIME_DATE|TIME_MINUTES) : "");
   DataExportCsvAdd(row, IntegerToString(g_assist_state.early_candidate_age_bars));
   DataExportCsvAdd(row, g_assist_state.trend_reassertion_pending ? "YES" : "NO");
   DataExportCsvAdd(row, g_assist_state.trend_reassertion_side>0 ? "LONG" : g_assist_state.trend_reassertion_side<0 ? "SHORT" : "NONE");
   DataExportCsvAdd(row, IntegerToString(g_assist_state.trend_reassertion_age_bars));
   DataExportCsvAdd(row, g_assist_state.trend_reassertion_target_recovered_pulse ? "YES" : "NO");
   DataExportCsvAdd(row, g_assist_state.trend_reassertion_cancel_pulse ? "YES" : "NO");
   DataExportCsvAdd(row, g_assist_state.review_shadow_end_reason);
   DataExportCsvAdd(row, g_assist_state.review_shadow_ended_start>0 ? TimeToString(g_assist_state.review_shadow_ended_start,TIME_DATE|TIME_SECONDS) : "");
   DataExportCsvAdd(row, g_assist_state.review_shadow_ended_side>0 ? "LONG" : g_assist_state.review_shadow_ended_side<0 ? "SHORT" : "NONE");
   DataExportCsvAdd(row, g_assist_state.review_adx14_valid ? DoubleToString(g_assist_state.review_adx14,8) : "");
   DataExportCsvAdd(row, g_assist_state.review_adx14_valid ? "YES" : "NO");
   DataExportCsvAdd(row, g_assist_state.review_price_break3 ? "YES" : "NO");
   DataExportCsvAdd(row, g_assist_state.review_qualified_early_opposite ? "YES" : "NO");
   DataExportCsvAdd(row, g_assist_state.review_add_block_option ? "YES" : "NO");
   DataExportCsvAdd(row, g_assist_state.review_add_blocked ? "YES" : "NO");
   DataExportCsvAdd(row, g_assist_state.turn_pre_enabled ? "YES" : "NO");
   DataExportCsvAdd(row, g_assist_state.turn_pre_data_valid ? "YES" : "NO");
   DataExportCsvAdd(row, g_assist_state.turn_pre_signal ? "YES" : "NO");
   DataExportCsvAdd(row, g_assist_state.turn_pre_side>0 ? "LONG" : g_assist_state.turn_pre_side<0 ? "SHORT" : "NONE");
   DataExportCsvAdd(row, g_assist_state.turn_pre_confirm_bar>0 ? TimeToString(g_assist_state.turn_pre_confirm_bar,TIME_DATE|TIME_SECONDS) : "");
   DataExportCsvAdd(row, g_assist_state.turn_pre_available_time>0 ? TimeToString(g_assist_state.turn_pre_available_time,TIME_DATE|TIME_SECONDS) : "");
   DataExportCsvAdd(row, g_assist_state.turn_pre_pivot_time>0 ? TimeToString(g_assist_state.turn_pre_pivot_time,TIME_DATE|TIME_SECONDS) : "");
   DataExportCsvAdd(row, DoubleToString(g_assist_state.turn_pre_pivot_price,8));
   DataExportCsvAdd(row, IntegerToString(g_assist_state.turn_pre_score));
   DataExportCsvAdd(row, DoubleToString(g_assist_state.turn_pre_distance_r,8));
   DataExportCsvAdd(row, DoubleToString(g_assist_state.turn_pre_long_divergence_r,8));
   DataExportCsvAdd(row, DoubleToString(g_assist_state.turn_pre_short_divergence_r,8));
   DataExportCsvAdd(row, g_assist_state.turn_pre_opposite ? "YES" : "NO");
   DataExportCsvAdd(row, g_assist_state.turn_pre_reason);
   DataExportCsvAdd(row, g_assist_state.turn_pre_require_divergence ? "YES" : "NO");
   DataExportCsvAdd(row, DoubleToString(g_assist_state.turn_pre_atr14,8));
   DataExportCsvAdd(row, DoubleToString(g_assist_state.raw_delta,8));
   DataExportCsvAdd(row, DoubleToString(g_assist_state.ema_delta,8));
   DataExportCsvAdd(row, DoubleToString(g_assist_state.delta_change,8));
   DataExportCsvAdd(row, (string)g_assist_state.delta_buy_steps);
   DataExportCsvAdd(row, (string)g_assist_state.delta_sell_steps);
   DataExportCsvAdd(row, g_assist_state.delta_long_participation ? "YES" : "NO");
   DataExportCsvAdd(row, g_assist_state.delta_short_participation ? "YES" : "NO");
   DataExportCsvAdd(row, g_assist_state.price_up ? "YES" : "NO");
   DataExportCsvAdd(row, g_assist_state.price_down ? "YES" : "NO");
   DataExportCsvAdd(row, g_assist_state.full_long_watch_candidate ? "YES" : "NO");
   DataExportCsvAdd(row, g_assist_state.full_short_watch_candidate ? "YES" : "NO");
   DataExportCsvAdd(row, g_assist_state.flip_path_oscillatory ? "YES" : "NO");
   DataExportCsvAdd(row, g_assist_state.flip_raw_path_directional ? "YES" : "NO");
   DataExportCsvAdd(row, g_assist_state.flip_wave_path_directional ? "YES" : "NO");
   DataExportCsvAdd(row, IntegerToString(g_assist_state.flip_raw_path_direction));
   DataExportCsvAdd(row, IntegerToString(g_assist_state.flip_wave_path_direction));
   DataExportCsvAdd(row, DoubleToString(g_assist_state.flip_raw_efficiency_5,6));
   DataExportCsvAdd(row, DoubleToString(g_assist_state.flip_wave_efficiency_5,6));
   DataExportCsvAdd(row, g_assist_state.flip_hold_active ? "YES" : "NO");
   DataExportCsvAdd(row, IntegerToString(g_assist_state.flip_hold_side));
   DataExportCsvAdd(row, g_assist_state.flip_hold_action);
   DataExportCsvAdd(row, g_assist_state.flip_hold_contested ? "YES" : "NO");
   DataExportCsvAdd(row, g_assist_state.structure_higher_low ? "YES" : "NO");
   DataExportCsvAdd(row, g_assist_state.structure_lower_high ? "YES" : "NO");
   DataExportCsvAdd(row, g_assist_state.pullback_long_ready ? "YES" : "NO");
   DataExportCsvAdd(row, g_assist_state.pullback_short_ready ? "YES" : "NO");
   DataExportCsvAdd(row, DoubleToString(g_assist_state.recent_swing_high,_Digits));
   DataExportCsvAdd(row, DoubleToString(g_assist_state.recent_swing_low,_Digits));
   DataExportCsvAdd(row, DoubleToString(g_assist_state.older_swing_high,_Digits));
   DataExportCsvAdd(row, DoubleToString(g_assist_state.older_swing_low,_Digits));
   DataExportCsvAdd(row, (string)g_assist_state.up_close_steps);
   DataExportCsvAdd(row, (string)g_assist_state.down_close_steps);
   DataExportCsvAdd(row, g_assist_state.post_discontinuity_rearm ? "YES" : "NO");
   DataExportCsvAdd(row, watch_event ? "YES" : "NO");
   DataExportCsvAdd(row, watch_side==M3_SEG_LONG ? "LONG" : watch_side==M3_SEG_SHORT ? "SHORT" : "NONE");
   DataExportCsvAdd(row, watch_event ? (string)(long)g_assist_state.bar_time : "");
   DataExportCsvAdd(row, watch_event_id);
   DataExportCsvAdd(row, leg_side==M3_SEG_LONG ? "LONG" : leg_side==M3_SEG_SHORT ? "SHORT" : "NONE");
   DataExportCsvAdd(row, (string)g_m3_segment.id);
   DataExportCsvAdd(row, accel_event_id);
   DataExportCsvAdd(row, accel_event ? (accel_matches_leg ? "YES" : "NO") : "");
   const bool csv_direction_event =
      ((g_test_csv_event_type=="ORDER:DIRECTION_LONG" || g_test_csv_event_type=="ORDER:DIRECTION_SHORT") ||
       (g_internal_momentum_event_time>0 && g_decision_snapshot.bar_time==g_internal_momentum_event_time));
   DataExportCsvAdd(row, auto_signal_type);
   DataExportCsvAdd(row, auto_signal_side==M3_SEG_LONG ? "LONG" : auto_signal_side==M3_SEG_SHORT ? "SHORT" : "NONE");
   DataExportCsvAdd(row, g_test_csv_source_event_id);
   DataExportCsvAdd(row, g_csv_order_signal_source);
   DataExportCsvAdd(row, g_csv_order_signal_side>0 ? "LONG" : g_csv_order_signal_side<0 ? "SHORT" : "NONE");
   DataExportCsvAdd(row, g_csv_order_signal_time>0 ? TimeToString(g_csv_order_signal_time,TIME_DATE|TIME_SECONDS) : "");
   DataExportCsvAdd(row, csv_direction_event ? "YES" : "NO");
   DataExportCsvAdd(row, csv_direction_event ? (g_internal_momentum_event_side>0 ? "LONG" : g_internal_momentum_event_side<0 ? "SHORT" : "NONE") : "NONE");
   DataExportCsvAdd(row, csv_direction_event && g_internal_momentum_event_time>0 ? TimeToString(g_internal_momentum_event_time,TIME_DATE|TIME_SECONDS) : "");
   DataExportCsvAdd(row, g_m3_segment.direction==M3_SEG_LONG ? "LONG" : g_m3_segment.direction==M3_SEG_SHORT ? "SHORT" : g_m3_segment.direction==M3_SEG_RANGE ? "RANGE" : "NONE");
   DataExportCsvAdd(row, auto_decision);
   DataExportCsvAdd(row, auto_order_expected ? "YES" : "NO");
   DataExportCsvAdd(row, audit_auto_leg_side==M3_SEG_LONG ? "LONG" : audit_auto_leg_side==M3_SEG_SHORT ? "SHORT" : "NONE");
   DataExportCsvAdd(row, audit_auto_leg_start>0 ? TimeToString(audit_auto_leg_start,TIME_DATE|TIME_SECONDS) : "");
   DataExportCsvAdd(row, accel_event ? (auto_accel_eligible ? "YES" : "NO") : "");
   // v8.221 observation-only WATCH episode diagnostics.
   DataExportCsvAdd(row, DoubleToString(g_assist_state.price_travel_3_r,8));
   DataExportCsvAdd(row, DoubleToString(g_assist_state.price_efficiency_3,8));
   DataExportCsvAdd(row, (string)g_assist_state.macd_zero_flip_count_5);
   DataExportCsvAdd(row, DoubleToString(g_assist_state.chop_8,8));
   DataExportCsvAdd(row, DoubleToString(g_assist_state.chop_14,8));
   DataExportCsvAdd(row, DoubleToString(g_assist_state.chop_21,8));
   DataExportCsvAdd(row, DoubleToString(g_assist_state.aroon_up_21,8));
   DataExportCsvAdd(row, DoubleToString(g_assist_state.aroon_down_21,8));
   DataExportCsvAdd(row, DoubleToString(g_assist_state.aroon_osc_21,8));
   DataExportCsvAdd(row, g_assist_state.watch_observe_original ? "YES" : "NO");
   DataExportCsvAdd(row, g_assist_state.watch_observe_new_candidate ? "YES" : "NO");
   DataExportCsvAdd(row, g_assist_state.watch_observe_stage);
   DataExportCsvAdd(row, g_assist_state.watch_observe_suppress_reason);
   DataExportCsvAdd(row, DoubleToString(g_assist_state.watch_observe_progress3_r,8));
   DataExportCsvAdd(row, DoubleToString(g_assist_state.watch_observe_chop8_delta3,8));
   DataExportCsvAdd(row, DoubleToString(g_assist_state.watch_observe_chop14,8));
   DataExportCsvAdd(row, DoubleToString(g_assist_state.watch_observe_aroon_spread,8));
   DataExportCsvAdd(row, g_assist_state.watch_suppress_latch_active ? "YES" : "NO");
   DataExportCsvAdd(row, IntegerToString(g_assist_state.watch_suppress_latch_side));
   DataExportCsvAdd(row, g_assist_state.watch_suppress_event ? "YES" : "NO");
   DataExportCsvAdd(row, g_assist_state.watch_suppress_release ? "YES" : "NO");
   DataExportCsvAdd(row, g_watch_episode_diag.active ? "YES" : "NO");
   DataExportCsvAdd(row, g_watch_episode_diag.active ? (string)g_watch_episode_diag.id : "");
   DataExportCsvAdd(row, g_watch_episode_diag.active ? (g_watch_episode_diag.side>0 ? "LONG" : "SHORT") : "");
   DataExportCsvAdd(row, g_watch_episode_diag.active && g_watch_episode_diag.start_time>0 ? TimeToString(g_watch_episode_diag.start_time,TIME_DATE|TIME_SECONDS) : "");
   DataExportCsvAdd(row, g_watch_episode_diag.active ? DoubleToString(g_watch_episode_diag.start_price,_Digits) : "");
   DataExportCsvAdd(row, g_watch_episode_diag.active ? (string)g_watch_episode_diag.age_bars : "");
   DataExportCsvAdd(row, g_watch_episode_diag.active ? DoubleToString(g_watch_episode_diag.mfe_price,_Digits) : "");
   DataExportCsvAdd(row, g_watch_episode_diag.active ? DoubleToString(g_watch_episode_diag.mae_price,_Digits) : "");
   DataExportCsvAdd(row, g_watch_episode_diag.active ? (string)g_watch_episode_diag.first_accel_age : "");
   DataExportCsvAdd(row, g_watch_episode_diag.active && g_watch_episode_diag.first_accel_time>0 ? TimeToString(g_watch_episode_diag.first_accel_time,TIME_DATE|TIME_SECONDS) : "");
   DataExportCsvAdd(row, g_watch_episode_diag.active ? DoubleToString(g_watch_episode_diag.pre_net_progress_r,8) : "");
   DataExportCsvAdd(row, g_watch_episode_diag.active ? DoubleToString(g_watch_episode_diag.pre_recent_progress_r,8) : "");
   DataExportCsvAdd(row, g_watch_episode_diag.active ? DoubleToString(g_watch_episode_diag.pre_price_travel_3_r,8) : "");
   DataExportCsvAdd(row, g_watch_episode_diag.active ? DoubleToString(g_watch_episode_diag.pre_price_efficiency_3,8) : "");
   DataExportCsvAdd(row, g_watch_episode_diag.active ? DoubleToString(g_watch_episode_diag.pre_macd_base_efficiency_3,8) : "");
   DataExportCsvAdd(row, g_watch_episode_diag.active ? DoubleToString(g_watch_episode_diag.pre_macd_wave_efficiency_3,8) : "");
   DataExportCsvAdd(row, g_watch_episode_diag.active ? (string)g_watch_episode_diag.pre_macd_zero_flip_count_5 : "");
   DataExportCsvAdd(row, g_watch_episode_diag.active ? DoubleToString(g_watch_episode_diag.price_travel,_Digits) : "");
   DataExportCsvAdd(row, g_watch_episode_diag.active ? DoubleToString(g_watch_episode_diag.net_displacement,_Digits) : "");
   DataExportCsvAdd(row, g_watch_episode_diag.active ? DoubleToString(g_watch_episode_diag.efficiency,8) : "");
   DataExportCsvAdd(row, g_watch_episode_diag.active ? DoubleToString(g_watch_episode_diag.extreme_extension_r,8) : "");
   DataExportCsvAdd(row, g_watch_episode_diag.active ? DoubleToString(g_watch_episode_diag.cluster_price_travel,_Digits) : "");
   DataExportCsvAdd(row, g_watch_episode_diag.active ? DoubleToString(g_watch_episode_diag.cluster_net_displacement,_Digits) : "");
   DataExportCsvAdd(row, g_watch_episode_diag.active ? DoubleToString(g_watch_episode_diag.cluster_efficiency,8) : "");
   DataExportCsvAdd(row, g_watch_episode_diag.active ? (string)g_watch_episode_diag.repeat_count : "");
   DataExportCsvAdd(row, g_watch_episode_diag.active ? DoubleToString(g_watch_episode_diag.last_repeat_displacement_r,8) : "");
   DataExportCsvAdd(row, g_watch_episode_closed_diag.id>0 ? (string)g_watch_episode_closed_diag.id : "");
   DataExportCsvAdd(row, g_watch_episode_closed_diag.id>0 ? (g_watch_episode_closed_diag.side>0 ? "LONG" : "SHORT") : "");
   DataExportCsvAdd(row, g_watch_episode_closed_diag.close_time>0 ? TimeToString(g_watch_episode_closed_diag.close_time,TIME_DATE|TIME_SECONDS) : "");
   DataExportCsvAdd(row, g_watch_episode_closed_diag.id>0 ? (string)g_watch_episode_closed_diag.age_bars : "");
   DataExportCsvAdd(row, g_watch_episode_closed_diag.id>0 ? DoubleToString(g_watch_episode_closed_diag.mfe_price,_Digits) : "");
   DataExportCsvAdd(row, g_watch_episode_closed_diag.id>0 ? DoubleToString(g_watch_episode_closed_diag.mae_price,_Digits) : "");
   DataExportCsvAdd(row, "M3_AUDIT_V8_POSITION_STRUCTURE_TRIGGER");
   // v8.168 structure episode evidence. No field below has order authority.
   DataExportCsvAdd(row, (string)g_structure_episode.id);
   DataExportCsvAdd(row, g_structure_episode.active ? "YES" : "NO");
   DataExportCsvAdd(row, g_structure_episode.side>0 ? "LONG" : g_structure_episode.side<0 ? "SHORT" : "NONE");
   DataExportCsvAdd(row, g_structure_episode.entry_time>0 ? TimeToString(g_structure_episode.entry_time,TIME_DATE|TIME_SECONDS) : "");
   DataExportCsvAdd(row, DoubleToString(g_structure_episode.entry_price,_Digits));
   DataExportCsvAdd(row, (string)g_structure_episode.bar_offset);
   DataExportCsvAdd(row, g_structure_episode.last_event);
   DataExportCsvAdd(row, g_structure_episode.last_event_time>0 ? TimeToString(g_structure_episode.last_event_time,TIME_DATE|TIME_SECONDS) : "");
   DataExportCsvAdd(row, DoubleToString(g_structure_episode.mfe_price,_Digits));
   DataExportCsvAdd(row, DoubleToString(g_structure_episode.mae_price,_Digits));
   DataExportCsvAdd(row, (string)g_structure_episode.add_count);
   DataExportCsvAdd(row, DoubleToString(g_structure_episode.entry_prev_swing_high,_Digits));
   DataExportCsvAdd(row, DoubleToString(g_structure_episode.entry_last_swing_high,_Digits));
   DataExportCsvAdd(row, DoubleToString(g_structure_episode.entry_prev_swing_low,_Digits));
   DataExportCsvAdd(row, DoubleToString(g_structure_episode.entry_last_swing_low,_Digits));
   DataExportCsvAdd(row, DoubleToString(g_structure_episode.entry_protected_high,_Digits));
   DataExportCsvAdd(row, DoubleToString(g_structure_episode.entry_protected_low,_Digits));
   DataExportCsvAdd(row, DoubleToString(g_structure_episode.entry_position_protected_price,_Digits));
   DataExportCsvAdd(row, g_structure_episode.entry_position_protected_time>0 ? TimeToString(g_structure_episode.entry_position_protected_time,TIME_DATE|TIME_SECONDS) : "");
   DataExportCsvAdd(row, g_structure_episode.entry_position_protected_source);
   DataExportCsvAdd(row, g_structure_episode.entry_position_protected_type);
   DataExportCsvAdd(row, DoubleToString(g_structure_episode.entry_ma7,_Digits));
   DataExportCsvAdd(row, DoubleToString(g_structure_episode.entry_ma22,_Digits));
   DataExportCsvAdd(row, DoubleToString(g_structure_episode.entry_macd_wave,8));
   DataExportCsvAdd(row, DoubleToString(g_structure_episode.entry_macd_hist,8));
   DataExportCsvAdd(row, DoubleToString(g_structure_episode.entry_delta,8));
   DataExportCsvAdd(row, DoubleToString(g_structure_episode.entry_volume,2));
   const bool structure_frame_out=g_structure_episode.frame_export_pending;
   DataExportCsvAdd(row, structure_frame_out ? DoubleToString(g_structure_episode.frame_open,_Digits) : "");
   DataExportCsvAdd(row, structure_frame_out ? DoubleToString(g_structure_episode.frame_high,_Digits) : "");
   DataExportCsvAdd(row, structure_frame_out ? DoubleToString(g_structure_episode.frame_low,_Digits) : "");
   DataExportCsvAdd(row, structure_frame_out ? DoubleToString(g_structure_episode.frame_close,_Digits) : "");
   DataExportCsvAdd(row, structure_frame_out ? DoubleToString(g_structure_episode.frame_ma7,_Digits) : "");
   DataExportCsvAdd(row, structure_frame_out ? DoubleToString(g_structure_episode.frame_ma22,_Digits) : "");
   DataExportCsvAdd(row, structure_frame_out ? DoubleToString(g_structure_episode.frame_macd_wave,8) : "");
   DataExportCsvAdd(row, structure_frame_out ? DoubleToString(g_structure_episode.frame_macd_hist,8) : "");
   DataExportCsvAdd(row, structure_frame_out ? DoubleToString(g_structure_episode.frame_delta,8) : "");
   DataExportCsvAdd(row, structure_frame_out ? DoubleToString(g_structure_episode.frame_delta_ema,8) : "");
   DataExportCsvAdd(row, structure_frame_out ? DoubleToString(g_structure_episode.frame_volume,2) : "");
   DataExportCsvAdd(row, structure_frame_out ? (g_structure_episode.frame_hh ? "YES" : "NO") : "");
   DataExportCsvAdd(row, structure_frame_out ? (g_structure_episode.frame_hl ? "YES" : "NO") : "");
   DataExportCsvAdd(row, structure_frame_out ? (g_structure_episode.frame_lh ? "YES" : "NO") : "");
   DataExportCsvAdd(row, structure_frame_out ? (g_structure_episode.frame_ll ? "YES" : "NO") : "");
   DataExportCsvAdd(row, structure_frame_out ? (g_structure_episode.frame_structure_break ? "YES" : "NO") : "");
   DataExportCsvAdd(row, structure_frame_out ? (g_structure_episode.frame_external_bullish ? "YES" : "NO") : "");
   DataExportCsvAdd(row, structure_frame_out ? (g_structure_episode.frame_external_bearish ? "YES" : "NO") : "");
   DataExportCsvAdd(row, structure_frame_out ? (g_structure_episode.frame_internal_bullish ? "YES" : "NO") : "");
   DataExportCsvAdd(row, structure_frame_out ? (g_structure_episode.frame_internal_bearish ? "YES" : "NO") : "");
   DataExportCsvAdd(row, structure_frame_out ? DoubleToString(g_structure_episode.frame_internal_trigger_high,_Digits) : "");
   DataExportCsvAdd(row, structure_frame_out ? DoubleToString(g_structure_episode.frame_internal_trigger_low,_Digits) : "");
   DataExportCsvAdd(row, structure_frame_out ? (g_structure_episode.frame_trigger_long ? "YES" : "NO") : "");
   DataExportCsvAdd(row, structure_frame_out ? (g_structure_episode.frame_trigger_short ? "YES" : "NO") : "");
   DataExportCsvAdd(row, structure_frame_out ? (string)g_structure_episode.frame_last_trigger_side : "");
   DataExportCsvAdd(row, structure_frame_out && g_structure_episode.frame_last_trigger_time>0 ? TimeToString(g_structure_episode.frame_last_trigger_time,TIME_DATE|TIME_SECONDS) : "");
   DataExportCsvAdd(row, structure_frame_out ? DoubleToString(g_structure_episode.frame_struct_long_trigger_price,_Digits) : "");
   DataExportCsvAdd(row, structure_frame_out ? DoubleToString(g_structure_episode.frame_struct_short_trigger_price,_Digits) : "");
   DataExportCsvAdd(row, structure_frame_out ? DoubleToString(g_structure_episode.frame_struct_long_trigger_base_price,_Digits) : "");
   DataExportCsvAdd(row, structure_frame_out ? DoubleToString(g_structure_episode.frame_struct_short_trigger_base_price,_Digits) : "");
   DataExportCsvAdd(row, structure_frame_out ? (g_structure_episode.frame_struct_long_trigger_fired ? "YES" : "NO") : "");
   DataExportCsvAdd(row, structure_frame_out ? (g_structure_episode.frame_struct_short_trigger_fired ? "YES" : "NO") : "");
   DataExportCsvAdd(row, structure_frame_out && g_structure_episode.frame_struct_long_trigger_fire_time>0 ? TimeToString(g_structure_episode.frame_struct_long_trigger_fire_time,TIME_DATE|TIME_SECONDS) : "");
   DataExportCsvAdd(row, structure_frame_out && g_structure_episode.frame_struct_short_trigger_fire_time>0 ? TimeToString(g_structure_episode.frame_struct_short_trigger_fire_time,TIME_DATE|TIME_SECONDS) : "");
   DataExportCsvAdd(row, DoubleToString(g_structure_episode.entry_internal_trigger_high,_Digits));
   DataExportCsvAdd(row, DoubleToString(g_structure_episode.entry_internal_trigger_low,_Digits));
   DataExportCsvAdd(row, DoubleToString(g_structure_episode.entry_struct_long_trigger_price,_Digits));
   DataExportCsvAdd(row, DoubleToString(g_structure_episode.entry_struct_short_trigger_price,_Digits));
   DataExportCsvAdd(row, structure_frame_out ? DoubleToString(g_structure_episode.frame_prev_swing_high,_Digits) : "");
   DataExportCsvAdd(row, structure_frame_out ? DoubleToString(g_structure_episode.frame_last_swing_high,_Digits) : "");
   DataExportCsvAdd(row, structure_frame_out ? DoubleToString(g_structure_episode.frame_prev_swing_low,_Digits) : "");
   DataExportCsvAdd(row, structure_frame_out ? DoubleToString(g_structure_episode.frame_last_swing_low,_Digits) : "");
   DataExportCsvAdd(row, structure_frame_out ? DoubleToString(g_structure_episode.frame_protected_high,_Digits) : "");
   DataExportCsvAdd(row, structure_frame_out ? DoubleToString(g_structure_episode.frame_protected_low,_Digits) : "");
   DataExportCsvAdd(row, structure_frame_out ? (g_structure_episode.frame_new_directional_swing ? "YES" : "NO") : "");
   DataExportCsvAdd(row, structure_frame_out ? (g_structure_episode.frame_directional_progress ? "YES" : "NO") : "");
   DataExportCsvAdd(row, structure_frame_out ? (g_structure_episode.frame_macd_progress ? "YES" : "NO") : "");
   DataExportCsvAdd(row, structure_frame_out ? (g_structure_episode.frame_macd_weakening ? "YES" : "NO") : "");
   DataExportCsvAdd(row, structure_frame_out ? (g_structure_episode.frame_protected_test ? "YES" : "NO") : "");
   DataExportCsvAdd(row, structure_frame_out ? (g_structure_episode.frame_protected_break ? "YES" : "NO") : "");
   DataExportCsvAdd(row, structure_frame_out ? (g_structure_episode.frame_recovery_attempt ? "YES" : "NO") : "");
   DataExportCsvAdd(row, structure_frame_out ? (g_structure_episode.frame_recovered ? "YES" : "NO") : "");
   DataExportCsvAdd(row, structure_frame_out ? (g_structure_episode.frame_recovery_failed ? "YES" : "NO") : "");
   DataExportCsvAdd(row, structure_frame_out ? (g_structure_episode.frame_structure_failed ? "YES" : "NO") : "");
   DataExportCsvAdd(row, structure_frame_out ? (g_structure_episode.frame_internal_break ? "YES" : "NO") : "");
   DataExportCsvAdd(row, structure_frame_out ? (g_structure_episode.frame_external_failure_confirmed ? "YES" : "NO") : "");
   DataExportCsvAdd(row, structure_frame_out ? (g_structure_episode.frame_external_opposite_high_relation ? "YES" : "NO") : "");
   DataExportCsvAdd(row, structure_frame_out ? (g_structure_episode.frame_external_opposite_low_relation ? "YES" : "NO") : "");
   DataExportCsvAdd(row, structure_frame_out ? (g_structure_episode.frame_external_pivots_after_break ? "YES" : "NO") : "");
   DataExportCsvAdd(row, structure_frame_out ? (g_structure_episode.frame_external_macd_confirm ? "YES" : "NO") : "");
   DataExportCsvAdd(row, structure_frame_out && g_structure_episode.diagnostic_recovery_failed_time>0 ? TimeToString(g_structure_episode.diagnostic_recovery_failed_time,TIME_DATE|TIME_SECONDS) : "");
   DataExportCsvAdd(row, structure_frame_out ? g_structure_episode.frame_diagnostic_state : "");
   DataExportCsvAdd(row, structure_frame_out && g_structure_episode.frame_state_start_time>0 ? TimeToString(g_structure_episode.frame_state_start_time,TIME_DATE|TIME_SECONDS) : "");
   DataExportCsvAdd(row, structure_frame_out ? (string)g_structure_episode.frame_bars_in_state : "");
   DataExportCsvAdd(row, structure_frame_out ? DoubleToString(g_structure_episode.frame_diagnostic_protected_price,_Digits) : "");
   DataExportCsvAdd(row, structure_frame_out ? DoubleToString(g_structure_episode.frame_diagnostic_break_price,_Digits) : "");
   DataExportCsvAdd(row, structure_frame_out ? DoubleToString(g_structure_episode.frame_position_protected_price,_Digits) : "");
   DataExportCsvAdd(row, structure_frame_out && g_structure_episode.frame_position_protected_time>0 ? TimeToString(g_structure_episode.frame_position_protected_time,TIME_DATE|TIME_SECONDS) : "");
   DataExportCsvAdd(row, structure_frame_out ? g_structure_episode.frame_position_protected_source : "");
   DataExportCsvAdd(row, structure_frame_out ? (g_structure_episode.frame_position_protected_updated ? "YES" : "NO") : "");
   DataExportCsvAdd(row, structure_frame_out ? DoubleToString(g_structure_episode.frame_position_protected_old_price,_Digits) : "");
   DataExportCsvAdd(row, structure_frame_out ? g_structure_episode.frame_position_protected_update_reason : "");
   DataExportCsvAdd(row, structure_frame_out ? DoubleToString(g_structure_episode.frame_position_candidate_price,_Digits) : "");
   DataExportCsvAdd(row, structure_frame_out && g_structure_episode.frame_position_candidate_time>0 ? TimeToString(g_structure_episode.frame_position_candidate_time,TIME_DATE|TIME_SECONDS) : "");
   DataExportCsvAdd(row, structure_frame_out ? g_structure_episode.frame_position_candidate_source : "");
   DataExportCsvAdd(row, structure_frame_out ? (g_structure_episode.frame_internal_trigger_high_changed ? "YES" : "NO") : "");
   DataExportCsvAdd(row, structure_frame_out ? (g_structure_episode.frame_internal_trigger_low_changed ? "YES" : "NO") : "");
   DataExportCsvAdd(row, structure_frame_out ? (g_structure_episode.frame_struct_long_trigger_changed ? "YES" : "NO") : "");
   DataExportCsvAdd(row, structure_frame_out ? (g_structure_episode.frame_struct_short_trigger_changed ? "YES" : "NO") : "");
   DataExportCsvAdd(row, structure_frame_out ? (g_structure_episode.frame_struct_long_close_break ? "YES" : "NO") : "");
   DataExportCsvAdd(row, structure_frame_out ? (g_structure_episode.frame_struct_short_close_break ? "YES" : "NO") : "");
   DataExportCsvAdd(row, structure_frame_out ? (g_structure_episode.frame_struct_long_recovered ? "YES" : "NO") : "");
   DataExportCsvAdd(row, structure_frame_out ? (g_structure_episode.frame_struct_short_recovered ? "YES" : "NO") : "");
   DataExportCsvAdd(row, structure_frame_out ? (g_structure_episode.frame_struct_long_rebreak ? "YES" : "NO") : "");
   DataExportCsvAdd(row, structure_frame_out ? (g_structure_episode.frame_struct_short_rebreak ? "YES" : "NO") : "");
   DataExportCsvAdd(row, g_structure_episode.exit_reason);
   DataExportCsvAdd(row, DoubleToString(g_structure_episode.exit_price,_Digits));
   DataExportCsvAdd(row, DoubleToString(g_structure_episode.realized_pnl,2));

   DataExportCsvAdd(row, g_csv_add_event_pending ? g_csv_add_event_id : "");
   DataExportCsvAdd(row, g_csv_add_event_pending ? g_csv_add_event_phase : "");
   DataExportCsvAdd(row, g_csv_add_event_pending && g_csv_add_event_time>0 ? TimeToString(g_csv_add_event_time,TIME_DATE|TIME_SECONDS) : "");
   DataExportCsvAdd(row, g_csv_add_event_pending ? (g_csv_add_event_side>0 ? "LONG" : g_csv_add_event_side<0 ? "SHORT" : "NONE") : "");
   DataExportCsvAdd(row, g_csv_add_event_pending ? (string)g_csv_add_event_layer : "");
   DataExportCsvAdd(row, g_csv_exit_event_pending ? g_csv_exit_event_id : "");
   DataExportCsvAdd(row, g_csv_exit_event_pending ? g_csv_exit_event_phase : "");
   DataExportCsvAdd(row, g_csv_exit_event_pending && g_csv_exit_event_time>0 ? TimeToString(g_csv_exit_event_time,TIME_DATE|TIME_SECONDS) : "");
   DataExportCsvAdd(row, g_csv_exit_event_pending ? g_csv_exit_event_reason : "");
   DataExportCsvAdd(row, g_trade_cycle.cycle_id);
   DataExportCsvAdd(row, g_csv_position_closed_event_pending ? "YES" : "NO");
   DataExportCsvAdd(row, g_csv_position_closed_event_pending ? g_csv_position_closed_cycle_id : "");
   DataExportCsvAdd(row, g_csv_position_closed_event_pending && g_csv_position_closed_time>0 ? TimeToString(g_csv_position_closed_time,TIME_DATE|TIME_SECONDS) : "");
   DataExportCsvAdd(row, g_csv_position_closed_event_pending ? DoubleToString(g_csv_position_final_pnl,2) : "");
   DataExportCsvAdd(row, g_csv_ticket_closed_event_pending ? "YES" : "NO");
   DataExportCsvAdd(row, g_csv_ticket_closed_event_pending ? (string)g_csv_ticket_closed_id : "");
   DataExportCsvAdd(row, g_csv_ticket_closed_event_pending ? DoubleToString(g_csv_ticket_final_pnl,2) : "");
   DataExportCsvAdd(row, g_csv_position_closed_event_pending ? DoubleToString(g_csv_position_final_r,4) : "");
   DataExportCsvAdd(row, g_csv_position_closed_event_pending ? g_csv_position_exit_reason : "");
   DataExportCsvAdd(row, DoubleToString(g_m3_group_peak_r,6));
   DataExportCsvAdd(row, DoubleToString(g_m3_audit_lock_target_sl,_Digits));
   DataExportCsvAdd(row, DoubleToString(g_m3_protected_sl,_Digits));
   DataExportCsvAdd(row, g_m3_audit_lock_attempted ? "YES" : "NO");
   DataExportCsvAdd(row, g_m3_audit_lock_applied ? "YES" : "NO");
   DataExportCsvAdd(row, g_m3_audit_lock_block_reason);
   DataExportCsvAdd(row, g_m3_audit_lock_update_time>0 ? TimeToString(g_m3_audit_lock_update_time,TIME_DATE|TIME_SECONDS) : "");

   const int row_columns = DataExportCsvColumnCount(row);
   if(row_columns != DataExportStrategyTestColumnCount())
   {
      PrintFormat("[JTA CSV] STRATEGY TEST ROW COLUMN ERROR | expected=%d actual=%d | stage=%s | decision=%s",
                  DataExportStrategyTestColumnCount(), row_columns, stage, final_decision);
      if(tester_fast_io)
         FileFlush(handle);
      else
         DataExportCloseLiveHandle(g_live_signal_decision_handle,
            g_live_signal_decision_file,g_live_signal_decision_dirty);
      return;
   }

   if(!tester_fast_io)
      FileSeek(handle, 0, SEEK_END);
   FileWriteString(handle, row + "\r\n");
   // v8.169: a completed M3 structure frame is exported exactly once.
   if(structure_frame_out)
      g_structure_episode.frame_export_pending=false;
   // v8.142: consume one-shot execution events only after a valid row is persisted.
   g_csv_add_event_pending=false;
   g_csv_exit_event_pending=false;
   g_csv_position_closed_event_pending=false;
   g_csv_ticket_closed_event_pending=false;

   // v8.147: these are one-shot ADD audit values, not persistent position
   // state.  Leaving them latched made unrelated later rows look as if an ADD
   // order had just been attempted/succeeded.  Consume them with the row that
   // persisted the event.  Durable ADD state remains in the position/layer
   // fields and the explicit ADD event columns.
   g_csv_add_attempted=false;
   g_csv_add_result=false;
   g_csv_add_retcode=0;
   g_csv_add_block_reason="";

   if(tester_fast_io)
   {
      tester_rows_since_flush++;
      if(tester_rows_since_flush >= 128)
      {
         FileFlush(handle);
         tester_rows_since_flush = 0;
      }
   }
   else
   {
      g_live_signal_decision_dirty=true;
      if(order_requested || order_result)
         DataExportFlushLiveHandleNow(g_live_signal_decision_handle,
            g_live_signal_decision_dirty,g_live_signal_decision_flush_msc);
   }
}


//+------------------------------------------------------------------+
// Dedicated strategy-tester bar audit. This file is intentionally
// separate from the unified lifecycle CSV so every processed M2 bar can be
// inspected without expanding the production schema.
string DataExportStrategyBarAuditFileName()
{
   // v2.24: keep every tester CSV under the same Joon\Test folder.
   return DataExportBaseFolder() + "\\" +
      StringFormat("TEST_%s_JTA_BarAudit_%s_%I64u.csv",
         DataExportRunId(), TradeLogSafeFileToken(_Symbol), (ulong)InpMagicNumber);
}

void WriteStrategyBarAudit(const int long_score,
                           const int short_score,
                           const bool raw_long_confirmed,
                           const bool raw_short_confirmed,
                           const bool countable_long,
                           const bool countable_short,
                           const string skip_reason)
{
   if(g_integrated_csv_mode)
   {
      const datetime integrated_bar = g_csv_counter_bar_time>0 ? g_csv_counter_bar_time : iTime(_Symbol,AUTO_TF,1);
      if(integrated_bar>0)
         DataExportWriteUnifiedEvent("BAR","STRATEGY_BAR",0,0,0.0,0.0,
            MathMax(long_score,short_score),"OBSERVE",skip_reason,"",
            (double)long_score,(double)short_score,
            StringFormat("RAW_L=%s RAW_S=%s COUNT_L=%s COUNT_S=%s",
               raw_long_confirmed?"YES":"NO",raw_short_confirmed?"YES":"NO",
               countable_long?"YES":"NO",countable_short?"YES":"NO"),integrated_bar);
      return;
   }
   if(!DataExportIsTester())
      return;
   // v3.06: the unified 180-column tester CSV already carries completed-bar
   // decision state. Skip this redundant second file in non-visual tests.
   if(!(bool)MQLInfoInteger(MQL_VISUAL_MODE))
      return;

   const datetime bar_time = g_csv_counter_bar_time > 0 ?
      g_csv_counter_bar_time : iTime(_Symbol, AUTO_TF, 1);
   if(bar_time <= 0)
      return;

   static datetime last_written_bar = 0;
   if(last_written_bar == bar_time)
      return;
   last_written_bar = bar_time;

   const string filename = DataExportStrategyBarAuditFileName();
   const int flags = FILE_READ|FILE_WRITE|FILE_TXT|FILE_ANSI|DataExportCommonFlag();
   int handle = FileOpen(filename, flags);
   if(handle == INVALID_HANDLE)
   {
      PrintFormat("[JTA CSV] BAR AUDIT OPEN FAILED | %s | err=%d", filename, GetLastError());
      return;
   }

   if(FileSize(handle) == 0)
   {
      string header = "";
      DataExportCsvAdd(header,"run_id");
      DataExportCsvAdd(header,"environment");
      DataExportCsvAdd(header,"symbol");
      DataExportCsvAdd(header,"timeframe");
      DataExportCsvAdd(header,"bar_time");
      DataExportCsvAdd(header,"expected_previous_bar_time");
      DataExportCsvAdd(header,"gap_seconds");
      DataExportCsvAdd(header,"gap_bars_m2");
      DataExportCsvAdd(header,"signal_engine_called");
      DataExportCsvAdd(header,"skip_reason");
      DataExportCsvAdd(header,"raw_long_confirmed");
      DataExportCsvAdd(header,"raw_short_confirmed");
      DataExportCsvAdd(header,"countable_long");
      DataExportCsvAdd(header,"countable_short");
      DataExportCsvAdd(header,"long_score");
      DataExportCsvAdd(header,"short_score");
      DataExportCsvAdd(header,"long_count_before");
      DataExportCsvAdd(header,"long_count_after");
      DataExportCsvAdd(header,"short_count_before");
      DataExportCsvAdd(header,"short_count_after");
      DataExportCsvAdd(header,"long_last_shift");
      DataExportCsvAdd(header,"short_last_shift");
      DataExportCsvAdd(header,"long_first_shift");
      DataExportCsvAdd(header,"short_first_shift");
      DataExportCsvAdd(header,"window_bars");
      DataExportCsvAdd(header,"long_expired");
      DataExportCsvAdd(header,"short_expired");
      DataExportCsvAdd(header,"duplicate_bar_block");
      DataExportCsvAdd(header,"opposite_decay");
      DataExportCsvAdd(header,"counter_action");
      DataExportCsvAdd(header,"counter_reset_reason");
      DataExportCsvAdd(header,"three_signal_long_reached");
      DataExportCsvAdd(header,"three_signal_short_reached");
      DataExportCsvAdd(header,"wait_long_breakout");
      DataExportCsvAdd(header,"wait_short_breakout");
      DataExportCsvAdd(header,"long_break_reference");
      DataExportCsvAdd(header,"short_break_reference");
      DataExportCsvAdd(header,"test_from");
      DataExportCsvAdd(header,"test_to");
      DataExportCsvAdd(header,"tester_model");
      FileWriteString(handle, header+"\r\n");
   }

   static datetime previous_bar_time = 0;
   const int gap_seconds = previous_bar_time > 0 ? (int)(bar_time-previous_bar_time) : 0;
   const int gap_bars = gap_seconds > 0 ? gap_seconds / 120 : 0;
   const datetime expected_previous = previous_bar_time > 0 ? previous_bar_time+120 : 0;

   string row="";
   DataExportCsvAdd(row,DataExportRunId());
   DataExportCsvAdd(row,DataExportEnvironment());
   DataExportCsvAdd(row,_Symbol);
   DataExportCsvAdd(row,EnumToString(AUTO_TF));
   DataExportCsvAdd(row,TimeToString(bar_time,TIME_DATE|TIME_SECONDS));
   DataExportCsvAdd(row,expected_previous>0?TimeToString(expected_previous,TIME_DATE|TIME_SECONDS):"");
   DataExportCsvAdd(row,(string)gap_seconds);
   DataExportCsvAdd(row,(string)gap_bars);
   DataExportCsvAdd(row,"YES");
   DataExportCsvAdd(row,skip_reason);
   DataExportCsvAdd(row,raw_long_confirmed?"YES":"NO");
   DataExportCsvAdd(row,raw_short_confirmed?"YES":"NO");
   DataExportCsvAdd(row,countable_long?"YES":"NO");
   DataExportCsvAdd(row,countable_short?"YES":"NO");
   DataExportCsvAdd(row,(string)long_score);
   DataExportCsvAdd(row,(string)short_score);
   DataExportCsvAdd(row,(string)g_csv_counter_long_before);
   DataExportCsvAdd(row,(string)g_csv_counter_long_after);
   DataExportCsvAdd(row,(string)g_csv_counter_short_before);
   DataExportCsvAdd(row,(string)g_csv_counter_short_after);
   DataExportCsvAdd(row,(string)g_csv_counter_long_last_shift);
   DataExportCsvAdd(row,(string)g_csv_counter_short_last_shift);
   DataExportCsvAdd(row,(string)g_csv_counter_long_first_shift);
   DataExportCsvAdd(row,(string)g_csv_counter_short_first_shift);
   DataExportCsvAdd(row,(string)MathMax(1,InpRangeSignalWindowBars));
   DataExportCsvAdd(row,g_csv_counter_long_expired?"YES":"NO");
   DataExportCsvAdd(row,g_csv_counter_short_expired?"YES":"NO");
   DataExportCsvAdd(row,g_csv_counter_duplicate_bar?"YES":"NO");
   DataExportCsvAdd(row,(string)g_csv_counter_opposite_decay);
   DataExportCsvAdd(row,g_csv_counter_action);
   DataExportCsvAdd(row,g_csv_counter_reset_reason);
   DataExportCsvAdd(row,g_range_long_signal_count>=3?"YES":"NO");
   DataExportCsvAdd(row,g_range_short_signal_count>=3?"YES":"NO");
   DataExportCsvAdd(row,(g_range_direction_confirm_pending && g_range_direction_confirm_side>0)?"YES":"NO");
   DataExportCsvAdd(row,(g_range_direction_confirm_pending && g_range_direction_confirm_side<0)?"YES":"NO");
   DataExportCsvAdd(row,DoubleToString(g_range_direction_confirm_high,_Digits));
   DataExportCsvAdd(row,DoubleToString(g_range_direction_confirm_low,_Digits));
   DataExportCsvAdd(row,DataExportTestFrom());
   DataExportCsvAdd(row,DataExportTestTo());
   DataExportCsvAdd(row,DataExportTesterModelName());

   FileSeek(handle,0,SEEK_END);
   FileWriteString(handle,row+"\r\n");
   FileFlush(handle);
   FileClose(handle);
   previous_bar_time=bar_time;
}

//+------------------------------------------------------------------+
// RANGE early-profit diagnostic CSV. This function never closes or modifies
// a position; it records the evidence needed to tune an existing exit engine.
void WriteProfitLockModifyAudit(const string result,
                                const int side,
                                const double requested_r,
                                const double requested_sl,
                                const double applied_sl,
                                const uint retcode,
                                const string block_reason)
{
   if(g_integrated_csv_mode)
   {
      DataExportWriteUnifiedEvent("RISK","PROFIT_LOCK",side,0,applied_sl,0.0,0,
         result,block_reason,"",requested_r,requested_sl,
         StringFormat("APPLIED_SL=%.8f RETCODE=%u",applied_sl,retcode));
      return;
   }

   DataExportWriteUnifiedEvent("RISK","PROFIT_LOCK",side,0,applied_sl,0.0,0,
      result,block_reason,"",requested_r,requested_sl,
      StringFormat("APPLIED_SL=%.8f RETCODE=%u",applied_sl,retcode));

   // v7.62 core trace: every profit-lock broker-SL decision is also written
   // to the mandatory unified order/cycle audit in Tester and Live.
   WriteUnifiedOrderSignalAudit("PROFIT_LOCK",
      g_trade_cycle.entry_source_event_id,"RISK",side,0,0,
      result,block_reason,requested_sl>0.0,
      result=="APPLIED",(long)retcode,g_trade_cycle.position_id);

   if(!InpEnableAutoTradeLog)
      return;

   const string file_name=DataExportPath(StringFormat(
      "JTC_ProfitLockModifyAudit_v3_%s_%I64u.csv",
      TradeLogSafeFileToken(_Symbol),(ulong)InpMagicNumber));
   if(g_diag_profit_lock_handle==INVALID_HANDLE ||
      g_diag_profit_lock_file!=file_name)
   {
      if(g_diag_profit_lock_handle!=INVALID_HANDLE)
         DataExportFlushOneDiagnostic(g_diag_profit_lock_handle,
            g_diag_profit_lock_dirty,g_diag_profit_lock_flush_msc,true);

      const bool exists=FileIsExist(file_name);
      g_diag_profit_lock_handle=
         FileOpen(file_name,FILE_READ|FILE_WRITE|FILE_TXT|FILE_ANSI);
      g_diag_profit_lock_file=file_name;
      if(g_diag_profit_lock_handle==INVALID_HANDLE)
      {
         g_diag_profit_lock_file="";
         return;
      }
      FileSeek(g_diag_profit_lock_handle,0,SEEK_END);

      if(!exists || FileSize(g_diag_profit_lock_handle)==0)
      {
      string header="";
      DataExportCsvAdd(header,"program_name");
      DataExportCsvAdd(header,"ea_version");
      DataExportCsvAdd(header,"csv_schema_version");
      DataExportCsvAdd(header,"run_id");
      DataExportCsvAdd(header,"event_time");
      DataExportCsvAdd(header,"symbol");
      DataExportCsvAdd(header,"selected_strategy");
      DataExportCsvAdd(header,"position_strategy");
      DataExportCsvAdd(header,"signal_tf");
      DataExportCsvAdd(header,"management_tf");
      DataExportCsvAdd(header,"entry_strategy");
      DataExportCsvAdd(header,"current_selected_strategy");
      DataExportCsvAdd(header,"position_management_strategy");
      DataExportCsvAdd(header,"strategy_changed_after_entry");
      DataExportCsvAdd(header,"strategy_change_time");
      DataExportCsvAdd(header,"strategy_consistent");
      DataExportCsvAdd(header,"position_id");
      DataExportCsvAdd(header,"side");
      DataExportCsvAdd(header,"result");
      DataExportCsvAdd(header,"requested_r");
      DataExportCsvAdd(header,"requested_sl");
      DataExportCsvAdd(header,"applied_sl");
      DataExportCsvAdd(header,"retcode");
      DataExportCsvAdd(header,"block_reason");
      DataExportCsvAdd(header,"ticket");
      DataExportCsvAdd(header,"managed_position_count");
      DataExportCsvAdd(header,"same_side_position_count");
      DataExportCsvAdd(header,"current_sl_before");
      DataExportCsvAdd(header,"actual_sl_after");
      DataExportCsvAdd(header,"sl_improvement_points");
      DataExportCsvAdd(header,"improves");
      DataExportCsvAdd(header,"bid");
      DataExportCsvAdd(header,"ask");
      DataExportCsvAdd(header,"stop_level_points");
      DataExportCsvAdd(header,"freeze_level_points");
      DataExportCsvAdd(header,"minimum_distance");
      DataExportCsvAdd(header,"verify_pass");
      DataExportCsvAdd(header,"hold_recent_count");
      DataExportCsvAdd(header,"hold_recent_span");
      DataExportCsvAdd(header,"hold_recent_macd_ratio");
      DataExportCsvAdd(header,"hold_recent_delta_ratio");
      DataExportCsvAdd(header,"hold_extreme_giveback_ratio");
      DataExportCsvAdd(header,"hold_recent_macd_reverse");
      DataExportCsvAdd(header,"hold_recent_delta_reverse");
      DataExportCsvAdd(header,"hold_recent_price_reverse");
      DataExportCsvAdd(header,"hold_score_before_cap");
      DataExportCsvAdd(header,"hold_score_after_cap");
      DataExportCsvAdd(header,"hold_state_before");
      DataExportCsvAdd(header,"hold_state_after");
      DataExportCsvAdd(header,"stage1_configured_r");
      DataExportCsvAdd(header,"stage1_net_positive_r");
      DataExportCsvAdd(header,"stage1_effective_r");
      DataExportCsvAdd(header,"entry_charge");
      DataExportCsvAdd(header,"negative_swap");
      DataExportCsvAdd(header,"estimated_exit_cost");
      DataExportCsvAdd(header,"one_r_money");
         FileWriteString(g_diag_profit_lock_handle,header+"\r\n");
         FileFlush(g_diag_profit_lock_handle);
         g_diag_profit_lock_flush_msc=GetTickCount64();
      }
   }

   string row="";
   DataExportCsvAdd(row,"Joon Trade Compass");
   DataExportCsvAdd(row,DataExportEaVersion());
   DataExportCsvAdd(row,"3");
   DataExportCsvAdd(row,DataExportRunId());
   DataExportCsvAdd(row,TimeToString(TimeCurrent(),TIME_DATE|TIME_SECONDS));
   DataExportCsvAdd(row,_Symbol);
   DataExportCsvAdd(row,DataExportStrategyNameValue(g_selected_strategy));
   DataExportCsvAdd(row,DataExportStrategyNameValue(g_position_strategy));
   DataExportCsvAdd(row,EnumToString(g_signal_tf));
   DataExportCsvAdd(row,EnumToString(ActiveManagementTF()));
   DataExportCsvAdd(row,DataExportEntryStrategyName());
   DataExportCsvAdd(row,DataExportStrategyNameValue(g_selected_strategy));
   DataExportCsvAdd(row,DataExportStrategyNameValue(g_position_strategy));
   DataExportCsvAdd(row,DataExportStrategyChangedAfterEntry());
   DataExportCsvAdd(row,DataExportStrategyChangeTime());
   DataExportCsvAdd(row,DataExportStrategyConsistent());
   DataExportCsvAdd(row,(string)g_trade_cycle.position_id);
   DataExportCsvAdd(row,(string)side);
   DataExportCsvAdd(row,result);
   DataExportCsvAdd(row,DoubleToString(requested_r,6));
   DataExportCsvAdd(row,DoubleToString(requested_sl,_Digits));
   DataExportCsvAdd(row,DoubleToString(applied_sl,_Digits));
   DataExportCsvAdd(row,(string)retcode);
   DataExportCsvAdd(row,block_reason);
   DataExportCsvAdd(row,(string)g_csv_profit_lock_ticket);
   DataExportCsvAdd(row,(string)g_csv_profit_lock_managed_count);
   DataExportCsvAdd(row,(string)g_csv_profit_lock_same_side_count);
   DataExportCsvAdd(row,DoubleToString(g_csv_profit_lock_current_sl_before,_Digits));
   DataExportCsvAdd(row,DoubleToString(g_csv_profit_lock_actual_sl_after,_Digits));
   DataExportCsvAdd(row,DoubleToString(g_csv_profit_lock_improvement_points,2));
   DataExportCsvAdd(row,(g_csv_profit_lock_improves ? "1" : "0"));
   DataExportCsvAdd(row,DoubleToString(g_csv_profit_lock_bid,_Digits));
   DataExportCsvAdd(row,DoubleToString(g_csv_profit_lock_ask,_Digits));
   DataExportCsvAdd(row,(string)g_csv_profit_lock_stop_level_points);
   DataExportCsvAdd(row,(string)g_csv_profit_lock_freeze_level_points);
   DataExportCsvAdd(row,DoubleToString(g_csv_profit_lock_minimum_distance,_Digits));
   DataExportCsvAdd(row,(g_csv_profit_lock_verify_pass ? "1" : "0"));
   const bool hold_diag_applicable=
      (g_position_strategy==STRATEGY_RANGE);
   DataExportCsvAdd(row,hold_diag_applicable?(string)g_csv_hold_recent_count:"");
   DataExportCsvAdd(row,hold_diag_applicable?(string)g_csv_hold_recent_span:"");
   DataExportCsvAdd(row,hold_diag_applicable?DoubleToString(g_csv_hold_recent_macd_ratio,4):"");
   DataExportCsvAdd(row,hold_diag_applicable?DoubleToString(g_csv_hold_recent_delta_ratio,4):"");
   DataExportCsvAdd(row,hold_diag_applicable?DoubleToString(g_csv_hold_extreme_giveback_ratio,4):"");
   DataExportCsvAdd(row,hold_diag_applicable?(g_csv_hold_recent_macd_reverse?"YES":"NO"):"");
   DataExportCsvAdd(row,hold_diag_applicable?(g_csv_hold_recent_delta_reverse?"YES":"NO"):"");
   DataExportCsvAdd(row,hold_diag_applicable?(g_csv_hold_recent_price_reverse?"YES":"NO"):"");
   DataExportCsvAdd(row,hold_diag_applicable?(string)g_csv_hold_score_before_cap:"");
   DataExportCsvAdd(row,hold_diag_applicable?(string)g_csv_hold_score_after_cap:"");
   DataExportCsvAdd(row,hold_diag_applicable?JoonRangeHoldStateName(g_csv_hold_state_before):"");
   DataExportCsvAdd(row,hold_diag_applicable?JoonRangeHoldStateName(g_csv_hold_state_after):"");
   DataExportCsvAdd(row,DoubleToString(g_csv_stage1_configured_r,6));
   DataExportCsvAdd(row,DoubleToString(g_csv_stage1_net_positive_r,6));
   DataExportCsvAdd(row,DoubleToString(g_csv_stage1_effective_r,6));
   DataExportCsvAdd(row,DoubleToString(g_csv_stage1_entry_charge,2));
   DataExportCsvAdd(row,DoubleToString(g_csv_stage1_negative_swap,2));
   DataExportCsvAdd(row,DoubleToString(g_csv_stage1_estimated_exit_cost,2));
   DataExportCsvAdd(row,DoubleToString(g_csv_stage1_one_r_money,2));

   FileWriteString(g_diag_profit_lock_handle,row+"\r\n");
   g_diag_profit_lock_dirty=true;
   DataExportFlushBufferedDiagnostics(false);
}

string DataExportRangeEarlyExitAuditFileName()
{
   return DataExportPath(StringFormat(
      "JTA_RangeEarlyExitAudit_v4_%s_%I64u.csv",
      TradeLogSafeFileToken(_Symbol),(ulong)InpMagicNumber));
}


void WriteRangeEarlyExitAudit(const ENUM_JOON_RANGE_HOLD_STATE range_state,
                              const string decision_point)
{
   if(g_integrated_csv_mode)
   {
      DataExportWriteUnifiedEvent("RISK","RANGE_EARLY_EXIT",ManagedPositionSide(),0,0.0,0.0,0,
         "OBSERVE",decision_point,"",(double)range_state,0.0,
         "RANGE_EARLY_EXIT_AUDIT",TimeCurrent());
      return;
   }

   if(!InpEnableAutoTradeLog || g_position_strategy != STRATEGY_RANGE)
      return;

   int side=0;
   double volume=0.0,average_price=0.0,sl=0.0,tp=0.0;
   datetime first_time=0;
   if(!ManagedGroupInfo(side,volume,average_price,sl,tp,first_time) ||
      side==0 || average_price<=0.0)
      return;

   const datetime bar_time=iTime(_Symbol,AUTO_TF,1);
   if(bar_time<=0)
      return;
   static datetime last_written_bar=0;
   static datetime last_position_time=0;
   if(last_position_time!=first_time)
   {
      last_written_bar=0;
      last_position_time=first_time;
   }
   if(last_written_bar==bar_time)
      return;
   last_written_bar=bar_time;

   if(!EnsureMarketSnapshot(3))
      return;

   const double market_price=side>0?SymbolInfoDouble(_Symbol,SYMBOL_BID):SymbolInfoDouble(_Symbol,SYMBOL_ASK);
   if(market_price<=0.0)
      return;
   const double profit_percent=side>0?
      (market_price-average_price)/average_price*100.0:
      (average_price-market_price)/average_price*100.0;
   const double current_r=CurrentGroupProgressR(side,average_price);
   DataExportWriteUnifiedEvent("RISK","RANGE_EARLY_EXIT_STATE",side,0,
      market_price,volume,0,decision_point,"","",
      current_r,profit_percent,
      JoonRangeHoldStateName(range_state),bar_time);
   const double macd_now=g_ms_macd[1];
   const double macd_prev=g_ms_macd[2];
   const double delta_now=g_ms_delta[1];
   const double delta_prev=g_ms_delta[2];
   const double ma7_now=g_ms_fast_ma[1];
   const double ma7_prev=g_ms_fast_ma[2];
   const double ma22_now=g_ms_slow_ma[1];
   const double price_scale=MathMax(MathAbs(market_price),_Point);
   const double macd_ratio=MathAbs(macd_now)/price_scale*100.0;
   const double delta_change=MathAbs(delta_now-delta_prev);
   const double ma7_slope_percent=MathAbs(ma7_now-ma7_prev)/price_scale*100.0;
   const double ma_spread_percent=MathAbs(ma7_now-ma22_now)/price_scale*100.0;
   const bool macd_near_zero=macd_ratio<=0.010;
   const bool delta_weak=MathAbs(delta_now)<=MathMax(1.0,delta_change*0.50);
   const bool ma7_flat=ma7_slope_percent<=0.005;
   const bool ma_compressed=ma_spread_percent<=0.020;
   const int low_energy_count=(macd_near_zero?1:0)+(delta_weak?1:0)+(ma7_flat?1:0)+(ma_compressed?1:0);
   const bool early_exit_candidate=profit_percent>0.0 && low_energy_count>=3;
   const bool profit_exit_allowed=ProfitExitAllowed();
   const bool range_confirmed_exit_allowed=RangeConfirmedProfitExitAllowed();

   const string filename=DataExportRangeEarlyExitAuditFileName();
   const int flags=FILE_READ|FILE_WRITE|FILE_TXT|FILE_ANSI|DataExportCommonFlag();
   if(g_diag_range_exit_handle==INVALID_HANDLE ||
      g_diag_range_exit_file!=filename)
   {
      if(g_diag_range_exit_handle!=INVALID_HANDLE)
         DataExportFlushOneDiagnostic(g_diag_range_exit_handle,
            g_diag_range_exit_dirty,g_diag_range_exit_flush_msc,true);

      g_diag_range_exit_handle=FileOpen(filename,flags);
      g_diag_range_exit_file=filename;
      if(g_diag_range_exit_handle==INVALID_HANDLE)
      {
         g_diag_range_exit_file="";
         PrintFormat("[JTA CSV] RANGE EARLY EXIT AUDIT OPEN FAILED | %s | err=%d",filename,GetLastError());
         return;
      }
      FileSeek(g_diag_range_exit_handle,0,SEEK_END);
      if(FileSize(g_diag_range_exit_handle)==0)
      {
      string header="";
      DataExportCsvAdd(header,"run_id");
      DataExportCsvAdd(header,"environment");
      DataExportCsvAdd(header,"symbol");
      DataExportCsvAdd(header,"bar_time");
      DataExportCsvAdd(header,"position_time");
      DataExportCsvAdd(header,"position_side");
      DataExportCsvAdd(header,"decision_point");
      DataExportCsvAdd(header,"range_hold_state");
      DataExportCsvAdd(header,"common_hold_state");
      DataExportCsvAdd(header,"hold_direction_score");
      DataExportCsvAdd(header,"hold_weakness_score");
      DataExportCsvAdd(header,"hold_recent_count");
      DataExportCsvAdd(header,"hold_recent_span");
      DataExportCsvAdd(header,"hold_recent_macd_ratio");
      DataExportCsvAdd(header,"hold_recent_delta_ratio");
      DataExportCsvAdd(header,"hold_extreme_giveback_ratio");
      DataExportCsvAdd(header,"hold_recent_macd_reverse");
      DataExportCsvAdd(header,"hold_recent_delta_reverse");
      DataExportCsvAdd(header,"hold_recent_price_reverse");
      DataExportCsvAdd(header,"hold_score_before_cap");
      DataExportCsvAdd(header,"hold_score_after_cap");
      DataExportCsvAdd(header,"hold_state_before");
      DataExportCsvAdd(header,"hold_state_after");
      DataExportCsvAdd(header,"average_entry");
      DataExportCsvAdd(header,"market_price");
      DataExportCsvAdd(header,"current_sl");
      DataExportCsvAdd(header,"current_tp");
      DataExportCsvAdd(header,"volume");
      DataExportCsvAdd(header,"hold_bars");
      DataExportCsvAdd(header,"hold_seconds");
      DataExportCsvAdd(header,"profit_percent");
      DataExportCsvAdd(header,"current_profit_r");
      DataExportCsvAdd(header,"highest_profit_r");
      DataExportCsvAdd(header,"profit_guard_peak_percent");
      DataExportCsvAdd(header,"giveback_percent_points");
      DataExportCsvAdd(header,"macd_now");
      DataExportCsvAdd(header,"macd_prev");
      DataExportCsvAdd(header,"macd_abs_price_percent");
      DataExportCsvAdd(header,"macd_near_zero");
      DataExportCsvAdd(header,"delta_now");
      DataExportCsvAdd(header,"delta_prev");
      DataExportCsvAdd(header,"delta_change");
      DataExportCsvAdd(header,"delta_weak");
      DataExportCsvAdd(header,"ma7_now");
      DataExportCsvAdd(header,"ma7_prev");
      DataExportCsvAdd(header,"ma22_now");
      DataExportCsvAdd(header,"ma7_slope_percent");
      DataExportCsvAdd(header,"ma7_flat");
      DataExportCsvAdd(header,"ma7_ma22_spread_percent");
      DataExportCsvAdd(header,"ma_compressed");
      DataExportCsvAdd(header,"low_energy_count");
      DataExportCsvAdd(header,"early_exit_candidate");
      DataExportCsvAdd(header,"profit_exit_allowed");
      DataExportCsvAdd(header,"range_confirmed_exit_allowed");
      DataExportCsvAdd(header,"suggested_action");
         FileWriteString(g_diag_range_exit_handle,header+"\r\n");
         FileFlush(g_diag_range_exit_handle);
         g_diag_range_exit_flush_msc=GetTickCount64();
      }
   }

   string suggested="HOLD";
   if(early_exit_candidate && !profit_exit_allowed) suggested="CANDIDATE_BUT_EXIT_BLOCKED";
   else if(early_exit_candidate) suggested="EARLY_RANGE_PROFIT_CANDIDATE";
   else if(profit_percent<=0.0) suggested="NO_PROFIT";
   else suggested="ENERGY_OR_TREND_SUPPORT_REMAINS";

   string row="";
   DataExportCsvAdd(row,DataExportRunId());
   DataExportCsvAdd(row,DataExportEnvironment());
   DataExportCsvAdd(row,_Symbol);
   DataExportCsvAdd(row,TimeToString(bar_time,TIME_DATE|TIME_SECONDS));
   DataExportCsvAdd(row,TimeToString(first_time,TIME_DATE|TIME_SECONDS));
   DataExportCsvAdd(row,side>0?"LONG":"SHORT");
   DataExportCsvAdd(row,decision_point);
   DataExportCsvAdd(row,JoonRangeHoldStateName(range_state));
   DataExportCsvAdd(row,DataExportHoldStateName());
   DataExportCsvAdd(row,(string)g_hold_direction_score);
   DataExportCsvAdd(row,(string)g_hold_weakness_score);
   DataExportCsvAdd(row,(string)g_csv_hold_recent_count);
   DataExportCsvAdd(row,(string)g_csv_hold_recent_span);
   DataExportCsvAdd(row,DoubleToString(g_csv_hold_recent_macd_ratio,4));
   DataExportCsvAdd(row,DoubleToString(g_csv_hold_recent_delta_ratio,4));
   DataExportCsvAdd(row,DoubleToString(g_csv_hold_extreme_giveback_ratio,4));
   DataExportCsvAdd(row,g_csv_hold_recent_macd_reverse?"YES":"NO");
   DataExportCsvAdd(row,g_csv_hold_recent_delta_reverse?"YES":"NO");
   DataExportCsvAdd(row,g_csv_hold_recent_price_reverse?"YES":"NO");
   DataExportCsvAdd(row,(string)g_csv_hold_score_before_cap);
   DataExportCsvAdd(row,(string)g_csv_hold_score_after_cap);
   DataExportCsvAdd(row,JoonRangeHoldStateName(g_csv_hold_state_before));
   DataExportCsvAdd(row,JoonRangeHoldStateName(g_csv_hold_state_after));
   DataExportCsvAdd(row,DoubleToString(average_price,_Digits));
   DataExportCsvAdd(row,DoubleToString(market_price,_Digits));
   DataExportCsvAdd(row,DoubleToString(sl,_Digits));
   DataExportCsvAdd(row,DoubleToString(tp,_Digits));
   DataExportCsvAdd(row,DoubleToString(volume,8));
   DataExportCsvAdd(row,(string)BarsSinceInitialEntry());
   DataExportCsvAdd(row,(string)(TimeCurrent()-first_time));
   DataExportCsvAdd(row,DoubleToString(profit_percent,5));
   DataExportCsvAdd(row,DoubleToString(current_r,5));
   DataExportCsvAdd(row,DoubleToString(g_highest_profit_r,5));
   DataExportCsvAdd(row,DoubleToString(g_profit_guard_peak_percent,5));
   DataExportCsvAdd(row,DoubleToString(g_profit_guard_peak_percent-profit_percent,5));
   DataExportCsvAdd(row,DoubleToString(macd_now,8));
   DataExportCsvAdd(row,DoubleToString(macd_prev,8));
   DataExportCsvAdd(row,DoubleToString(macd_ratio,6));
   DataExportCsvAdd(row,macd_near_zero?"YES":"NO");
   DataExportCsvAdd(row,DoubleToString(delta_now,8));
   DataExportCsvAdd(row,DoubleToString(delta_prev,8));
   DataExportCsvAdd(row,DoubleToString(delta_change,8));
   DataExportCsvAdd(row,delta_weak?"YES":"NO");
   DataExportCsvAdd(row,DoubleToString(ma7_now,_Digits));
   DataExportCsvAdd(row,DoubleToString(ma7_prev,_Digits));
   DataExportCsvAdd(row,DoubleToString(ma22_now,_Digits));
   DataExportCsvAdd(row,DoubleToString(ma7_slope_percent,6));
   DataExportCsvAdd(row,ma7_flat?"YES":"NO");
   DataExportCsvAdd(row,DoubleToString(ma_spread_percent,6));
   DataExportCsvAdd(row,ma_compressed?"YES":"NO");
   DataExportCsvAdd(row,(string)low_energy_count);
   DataExportCsvAdd(row,early_exit_candidate?"YES":"NO");
   DataExportCsvAdd(row,profit_exit_allowed?"YES":"NO");
   DataExportCsvAdd(row,range_confirmed_exit_allowed?"YES":"NO");
   DataExportCsvAdd(row,suggested);

   FileWriteString(g_diag_range_exit_handle,row+"\r\n");
   g_diag_range_exit_dirty=true;
   DataExportFlushBufferedDiagnostics(false);
}


void WriteUnifiedOrderSignalAudit(const string stage,
                                  const string source_event_id,
                                  const string counter_type,
                                  const int side,
                                  const int counter_before,
                                  const int counter_after,
                                  const string decision,
                                  const string reason,
                                  const bool order_requested,
                                  const bool order_result,
                                  const long retcode,
                                  const ulong position_id)
{
   if(g_integrated_csv_mode)
   {
      const datetime audit_time =
         g_decision_snapshot.bar_time>0 ? g_decision_snapshot.bar_time : TimeCurrent();
      DataExportWriteUnifiedEvent("ORDER",stage,side,position_id,0.0,0.0,
         counter_after,decision,reason,source_event_id,
         (double)counter_before,(double)retcode,
         StringFormat("COUNTER_TYPE=%s COUNTER_BEFORE=%d COUNTER_AFTER=%d ORDER_REQ=%s ORDER_RESULT=%s",
            counter_type,counter_before,counter_after,
            order_requested?"YES":"NO",order_result?"YES":"NO"),
         audit_time);
      return;
   }
   // v7.62 common trace keys shared by Tester and Live CSVs.
   const datetime trace_bar_time =
      g_decision_snapshot.bar_time>0 ? g_decision_snapshot.bar_time :
      g_trade_cycle.last_decision_bar_time;
   const string trace_bar_key =
      trace_bar_time>0
      ? StringFormat("%s|%s|%I64d",
           _Symbol,EnumToString(g_calc_tf),(long)trace_bar_time)
      : "";
   const string trace_cycle_id=(string)g_trade_cycle.cycle_id;

   if(DataExportIsTester())
   {
      if(!DataExportTesterKeepOrderAuditStage(stage))
         return;
      if(DataExportShouldSkipRepeatedAudit(stage,decision,side,reason))
         return;

      const string file_name=DataExportPath(
         "JTA_UnifiedOrderSignalAudit_v2_65_Compact_" +
         TradeLogSafeFileToken(_Symbol) + "_" + (string)InpMagicNumber + ".csv");

      static int tester_compact_handle=INVALID_HANDLE;
      static string tester_compact_file="";
      static int tester_compact_rows_since_flush=0;

      if(tester_compact_handle==INVALID_HANDLE || tester_compact_file!=file_name)
      {
         if(tester_compact_handle!=INVALID_HANDLE)
         {
            FileFlush(tester_compact_handle);
            FileClose(tester_compact_handle);
         }
         tester_compact_handle=FileOpen(
            file_name,
            DataExportFileFlags(FILE_READ|FILE_WRITE|FILE_TXT|FILE_ANSI|FILE_SHARE_READ|FILE_SHARE_WRITE),
            0,CP_UTF8);
         tester_compact_file=file_name;
         tester_compact_rows_since_flush=0;
         if(tester_compact_handle!=INVALID_HANDLE)
            FileSeek(tester_compact_handle,0,SEEK_END);
      }
      if(tester_compact_handle==INVALID_HANDLE)
         return;

      if(FileSize(tester_compact_handle)==0)
      {
         string header="";
         DataExportCsvAdd(header,"run_id");
         DataExportCsvAdd(header,"environment");
         DataExportCsvAdd(header,"symbol");
         DataExportCsvAdd(header,"magic");
         DataExportCsvAdd(header,"ea_version");
         DataExportCsvAdd(header,"time");
         DataExportCsvAdd(header,"decision_bar_time");
         DataExportCsvAdd(header,"bar_key");
         DataExportCsvAdd(header,"stage");
         DataExportCsvAdd(header,"source_event_id");
         DataExportCsvAdd(header,"side");
         DataExportCsvAdd(header,"counter_type");
         DataExportCsvAdd(header,"counter_before");
         DataExportCsvAdd(header,"counter_after");
         DataExportCsvAdd(header,"decision");
         DataExportCsvAdd(header,"reason");
         DataExportCsvAdd(header,"order_requested");
         DataExportCsvAdd(header,"order_result");
         DataExportCsvAdd(header,"retcode");
         DataExportCsvAdd(header,"position_id");
         DataExportCsvAdd(header,"managed_side");
         DataExportCsvAdd(header,"initial_long_count");
         DataExportCsvAdd(header,"initial_short_count");
         DataExportCsvAdd(header,"add_count");
         DataExportCsvAdd(header,"cycle_id");
         DataExportCsvAdd(header,"cycle_state");
         DataExportCsvAdd(header,"cycle_side");
         DataExportCsvAdd(header,"cycle_third_signal_id");
         DataExportCsvAdd(header,"cycle_breakout_reference");
         DataExportCsvAdd(header,"cycle_entry_source_event_id");
         DataExportCsvAdd(header,"cycle_exit_source_event_id");
         DataExportCsvAdd(header,"direction_confirm_pending");
         DataExportCsvAdd(header,"direction_confirm_side");
         DataExportCsvAdd(header,"direction_confirm_bar");
         DataExportCsvAdd(header,"direction_confirm_high");
         DataExportCsvAdd(header,"direction_confirm_low");
         DataExportCsvAdd(header,"trigger_entry_active");
         DataExportCsvAdd(header,"trigger_entry_side");
         DataExportCsvAdd(header,"trigger_entry_fire_bar");
         DataExportCsvAdd(header,"trigger_entry_final_count");
         DataExportCsvAdd(header,"cycle_entry_price");
         DataExportCsvAdd(header,"cycle_initial_sl");
         DataExportCsvAdd(header,"cycle_peak_r");
         DataExportCsvAdd(header,"cycle_exit_reason");
         DataExportCsvAdd(header,"cycle_realized_net");
         FileWriteString(tester_compact_handle,header+"\r\n");
      }

      string row="";
      DataExportCsvAdd(row,DataExportRunId());
      DataExportCsvAdd(row,DataExportEnvironment());
      DataExportCsvAdd(row,_Symbol);
      DataExportCsvAdd(row,(string)InpMagicNumber);
      DataExportCsvAdd(row,DataExportEaVersion());
      DataExportCsvAdd(row,TimeToString(TimeCurrent(),TIME_DATE|TIME_SECONDS));
      DataExportCsvAdd(row,trace_bar_time>0 ?
         TimeToString(trace_bar_time,TIME_DATE|TIME_SECONDS) : "");
      DataExportCsvAdd(row,trace_bar_key);
      DataExportCsvAdd(row,stage);
      DataExportCsvAdd(row,source_event_id);
      DataExportCsvAdd(row,side>0 ? "L" : (side<0 ? "S" : "0"));
      DataExportCsvAdd(row,counter_type);
      DataExportCsvAdd(row,(string)counter_before);
      DataExportCsvAdd(row,(string)counter_after);
      DataExportCsvAdd(row,decision);
      DataExportCsvAdd(row,reason);
      DataExportCsvAdd(row,order_requested ? "1" : "0");
      DataExportCsvAdd(row,order_result ? "1" : "0");
      DataExportCsvAdd(row,(string)retcode);
      DataExportCsvAdd(row,(string)position_id);
      DataExportCsvAdd(row,(string)ManagedPositionSide());
      DataExportCsvAdd(row,(string)g_range_long_signal_count);
      DataExportCsvAdd(row,(string)g_range_short_signal_count);
      DataExportCsvAdd(row,(string)g_trade_cycle.additional_entry_filled_count);
      DataExportCsvAdd(row,trace_cycle_id);
      DataExportCsvAdd(row,TradeCycleStateName(g_trade_cycle.state));
      DataExportCsvAdd(row,(string)g_trade_cycle.side);
      DataExportCsvAdd(row,g_trade_cycle.third_signal_id);
      DataExportCsvAdd(row,DoubleToString(g_trade_cycle.breakout_reference,_Digits));
      DataExportCsvAdd(row,g_trade_cycle.entry_source_event_id);
      DataExportCsvAdd(row,g_trade_cycle.exit_source_event_id);
      DataExportCsvAdd(row,g_range_direction_confirm_pending ? "1" : "0");
      DataExportCsvAdd(row,(string)g_range_direction_confirm_side);
      DataExportCsvAdd(row,g_range_direction_confirm_signal_bar>0 ?
         TimeToString(g_range_direction_confirm_signal_bar,TIME_DATE|TIME_SECONDS) : "");
      DataExportCsvAdd(row,DoubleToString(g_range_direction_confirm_high,_Digits));
      DataExportCsvAdd(row,DoubleToString(g_range_direction_confirm_low,_Digits));
      DataExportCsvAdd(row,g_range_trigger_entry_active ? "1" : "0");
      DataExportCsvAdd(row,(string)g_range_trigger_entry_side);
      DataExportCsvAdd(row,g_range_trigger_entry_fire_bar>0 ?
         TimeToString(g_range_trigger_entry_fire_bar,TIME_DATE|TIME_SECONDS) : "");
      DataExportCsvAdd(row,(string)g_range_trigger_entry_final_count);
      DataExportCsvAdd(row,DoubleToString(g_trade_cycle.entry_price,_Digits));
      DataExportCsvAdd(row,DoubleToString(g_trade_cycle.initial_sl,_Digits));
      DataExportCsvAdd(row,DoubleToString(g_trade_cycle.peak_r,4));
      DataExportCsvAdd(row,g_trade_cycle.exit_reason);
      DataExportCsvAdd(row,DoubleToString(g_trade_cycle.realized_net,2));
      FileWriteString(tester_compact_handle,row+"\r\n");

      tester_compact_rows_since_flush++;
      const bool critical_tester_trace=
         order_requested || order_result ||
         stage=="CYCLE_COMPLETED" || stage=="CYCLE_RESET" ||
         StringFind(stage,"EXIT_RESULT")==0 ||
         StringFind(stage,"ADD_ORDER_RESULT")==0;
      if(critical_tester_trace || tester_compact_rows_since_flush>=128)
      {
         FileFlush(tester_compact_handle);
         tester_compact_rows_since_flush=0;
      }
      return;
   }


   if(!DataExportTesterKeepOrderAuditStage(stage))
      return;

   if(DataExportShouldSkipRepeatedAudit(stage,decision,side,reason))
      return;

   DataExportWriteUnifiedEvent("ORDER",stage,side,position_id,0.0,0.0,0,
      decision,reason,source_event_id,
      (double)counter_before,(double)counter_after,
      StringFormat("COUNTER=%s ORDER_REQ=%s ORDER_RESULT=%s RETCODE=%I64d",
                   counter_type,order_requested?"YES":"NO",
                   order_result?"YES":"NO",retcode));
   if(g_integrated_csv_mode) return;

   // v7.62: this compact lifecycle audit is mandatory verification data in
   // both Tester and Live. Optional AutoTradeLog still controls other verbose
   // diagnostics, but cannot disable core order/cycle traceability.
   const string file_name = DataExportPath(
      "JTA_UnifiedOrderSignalAudit_v2_65_Slim_" +
      TradeLogSafeFileToken(_Symbol) + "_" + (string)InpMagicNumber + ".csv");
   int handle=INVALID_HANDLE;
   if(DataExportEnsureLiveBufferedHandle(
         file_name,g_live_order_audit_handle,g_live_order_audit_file))
      handle=g_live_order_audit_handle;
   if(handle==INVALID_HANDLE) return;

   if(FileSize(handle)==0)
   {
      string header="";
      DataExportCsvAdd(header,"run_id");
      DataExportCsvAdd(header,"environment");
      DataExportCsvAdd(header,"test_from");
      DataExportCsvAdd(header,"test_to");
      DataExportCsvAdd(header,"tester_model");
      DataExportCsvAdd(header,"terminal_token");
      DataExportCsvAdd(header,"data_instance_token");
      DataExportCsvAdd(header,"server_time");
      DataExportCsvAdd(header,"decision_bar_time");
      DataExportCsvAdd(header,"bar_key");
      DataExportCsvAdd(header,"symbol");
      DataExportCsvAdd(header,"stage");
      DataExportCsvAdd(header,"source_event_id");
      DataExportCsvAdd(header,"counter_type");
      DataExportCsvAdd(header,"side");
      DataExportCsvAdd(header,"counter_before");
      DataExportCsvAdd(header,"counter_after");
      DataExportCsvAdd(header,"decision");
      DataExportCsvAdd(header,"reason");
      DataExportCsvAdd(header,"order_requested");
      DataExportCsvAdd(header,"order_result");
      DataExportCsvAdd(header,"retcode");
      DataExportCsvAdd(header,"position_id");
      DataExportCsvAdd(header,"position_side");
      DataExportCsvAdd(header,"initial_count_long");
      DataExportCsvAdd(header,"initial_count_short");
      DataExportCsvAdd(header,"direction_confirm_pending");
      DataExportCsvAdd(header,"direction_confirm_side");
      DataExportCsvAdd(header,"direction_confirm_bar");
      DataExportCsvAdd(header,"direction_confirm_high");
      DataExportCsvAdd(header,"direction_confirm_low");
      DataExportCsvAdd(header,"trigger_entry_active");
      DataExportCsvAdd(header,"trigger_entry_side");
      DataExportCsvAdd(header,"trigger_entry_fire_bar");
      DataExportCsvAdd(header,"trigger_entry_final_count");
      DataExportCsvAdd(header,"add_count");
      DataExportCsvAdd(header,"opposite_count");
      DataExportCsvAdd(header,"entry_in_progress");
      DataExportCsvAdd(header,"add_in_progress");
      DataExportCsvAdd(header,"exit_in_progress");
      DataExportCsvAdd(header,"hold_state");
      DataExportCsvAdd(header,"profit_protection_state");
      DataExportCsvAdd(header,"long_signal_1_time");
      DataExportCsvAdd(header,"long_signal_2_time");
      DataExportCsvAdd(header,"long_signal_3_time");
      DataExportCsvAdd(header,"short_signal_1_time");
      DataExportCsvAdd(header,"short_signal_2_time");
      DataExportCsvAdd(header,"short_signal_3_time");
      DataExportCsvAdd(header,"long_signal_1_shift");
      DataExportCsvAdd(header,"long_signal_2_shift");
      DataExportCsvAdd(header,"long_signal_3_shift");
      DataExportCsvAdd(header,"short_signal_1_shift");
      DataExportCsvAdd(header,"short_signal_2_shift");
      DataExportCsvAdd(header,"short_signal_3_shift");
      DataExportCsvAdd(header,"legacy_signal_window_bars");
      DataExportCsvAdd(header,"long_window_valid");
      DataExportCsvAdd(header,"short_window_valid");
      DataExportCsvAdd(header,"cycle_id");
      DataExportCsvAdd(header,"cycle_parent_id");
      DataExportCsvAdd(header,"cycle_reentry_origin");
      DataExportCsvAdd(header,"cycle_state");
      DataExportCsvAdd(header,"cycle_side");
      DataExportCsvAdd(header,"cycle_created_time");
      DataExportCsvAdd(header,"cycle_updated_time");
      DataExportCsvAdd(header,"cycle_initial_count");
      DataExportCsvAdd(header,"cycle_signal_1_time");
      DataExportCsvAdd(header,"cycle_signal_2_time");
      DataExportCsvAdd(header,"cycle_signal_3_time");
      DataExportCsvAdd(header,"cycle_third_signal_id");
      DataExportCsvAdd(header,"cycle_breakout_reference");
      DataExportCsvAdd(header,"cycle_breakout_elapsed_bars");
      DataExportCsvAdd(header,"cycle_entry_source_event_id");
      DataExportCsvAdd(header,"cycle_position_id");
      DataExportCsvAdd(header,"cycle_entry_time");
      DataExportCsvAdd(header,"cycle_entry_price");
      DataExportCsvAdd(header,"cycle_initial_sl");
      DataExportCsvAdd(header,"cycle_initial_tp");
      DataExportCsvAdd(header,"cycle_add_count");
      DataExportCsvAdd(header,"cycle_additional_entries");
      DataExportCsvAdd(header,"cycle_add_last_consumed_pair_key");
      DataExportCsvAdd(header,"cycle_hold_state");
      DataExportCsvAdd(header,"cycle_profit_protection_state");
      DataExportCsvAdd(header,"cycle_peak_r");
      DataExportCsvAdd(header,"cycle_opposite_count");
      DataExportCsvAdd(header,"cycle_exit_source_event_id");
      DataExportCsvAdd(header,"cycle_exit_reason");
      DataExportCsvAdd(header,"cycle_last_reset_reason");
      DataExportCsvAdd(header,"cycle_event_sequence");
      DataExportCsvAdd(header,"cycle_last_stage");
      DataExportCsvAdd(header,"cycle_last_transition_reason");
      DataExportCsvAdd(header,"cycle_last_decision_bar_time");
      DataExportCsvAdd(header,"cycle_entry_deal_ticket");
      DataExportCsvAdd(header,"cycle_exit_deal_ticket");
      DataExportCsvAdd(header,"cycle_exit_time");
      DataExportCsvAdd(header,"cycle_exit_price");
      DataExportCsvAdd(header,"cycle_realized_net");
      DataExportCsvAdd(header,"cycle_completed");
      DataExportCsvAdd(header,"cycle_position_consistent");
      DataExportCsvAdd(header,"snapshot_bar_time");
      DataExportCsvAdd(header,"snapshot_tf_seconds");
      DataExportCsvAdd(header,"snapshot_final_long");
      DataExportCsvAdd(header,"snapshot_final_short");
      DataExportCsvAdd(header,"snapshot_long_score");
      DataExportCsvAdd(header,"snapshot_short_score");
      DataExportCsvAdd(header,"snapshot_long_score_pre_context");
      DataExportCsvAdd(header,"snapshot_short_score_pre_context");
      DataExportCsvAdd(header,"snapshot_long_context_penalty");
      DataExportCsvAdd(header,"snapshot_short_context_penalty");
      DataExportCsvAdd(header,"snapshot_long_event_id");
      DataExportCsvAdd(header,"snapshot_short_event_id");
      DataExportCsvAdd(header,"snapshot_shared_signal_auto_pass");
      DataExportCsvAdd(header,"reentry_permission");
      DataExportCsvAdd(header,"reentry_active");
      DataExportCsvAdd(header,"reentry_parent_cycle_id");
      DataExportCsvAdd(header,"reentry_child_cycle_id");
      DataExportCsvAdd(header,"reentry_side");
      DataExportCsvAdd(header,"reentry_exit_time");
      DataExportCsvAdd(header,"reentry_exit_price");
      DataExportCsvAdd(header,"reentry_signal_count");
      DataExportCsvAdd(header,"reentry_signal_1_id");
      DataExportCsvAdd(header,"reentry_signal_2_id");
      DataExportCsvAdd(header,"reentry_pair_key");
      DataExportCsvAdd(header,"reentry_last_attempted_pair_key");
      DataExportCsvAdd(header,"reentry_order_pending");
      DataExportCsvAdd(header,"reentry_last_block_reason");
      DataExportCsvAdd(header,"management_strategy");
      DataExportCsvAdd(header,"management_tf");
      DataExportCsvAdd(header,"hold_evaluation_ready");
      DataExportCsvAdd(header,"hold_evaluation_bar");
      DataExportCsvAdd(header,"segment_score");
      DataExportCsvAdd(header,"weakness_score");
      DataExportCsvAdd(header,"peak_r");
      DataExportCsvAdd(header,"profit_lock_state");
      DataExportCsvAdd(header,"program_name");
      DataExportCsvAdd(header,"ea_version");
      DataExportCsvAdd(header,"csv_schema_version");
      DataExportCsvAdd(header,"selected_strategy");
      DataExportCsvAdd(header,"position_strategy");
      DataExportCsvAdd(header,"signal_tf");
      DataExportCsvAdd(header,"stage1_configured_r");
      DataExportCsvAdd(header,"stage1_net_positive_r");
      DataExportCsvAdd(header,"stage1_effective_r");
      DataExportCsvAdd(header,"stage1_entry_charge");
      DataExportCsvAdd(header,"stage1_negative_swap");
      DataExportCsvAdd(header,"stage1_estimated_exit_cost");
      DataExportCsvAdd(header,"stage1_one_r_money");
      DataExportCsvAdd(header,"profit_lock_attempted");
      DataExportCsvAdd(header,"profit_lock_requested_r");
      DataExportCsvAdd(header,"profit_lock_requested_sl");
      DataExportCsvAdd(header,"profit_lock_applied");
      DataExportCsvAdd(header,"profit_lock_applied_sl");
      DataExportCsvAdd(header,"profit_lock_retcode");
      DataExportCsvAdd(header,"profit_lock_block_reason");
      FileWriteString(handle,header+"\r\n");
   }

   FileSeek(handle,0,SEEK_END);
   // v7.62 live trace optimization: the RANGE counter is episode-driven and
   // elapsed-window shifts are compatibility diagnostics only. Signal times,
   // counts and cycle ids are sufficient to reconstruct the sequence offline,
   // so avoid six synchronous iBarShift calls on every live audit event.
   const int legacy_signal_window_bars = MathMax(1,InpRangeSignalWindowBars);
   const int long_shift_1=-1,long_shift_2=-1,long_shift_3=-1;
   const int short_shift_1=-1,short_shift_2=-1,short_shift_3=-1;
   const bool long_window_valid=true;
   const bool short_window_valid=true;

   string row="";
   DataExportCsvAdd(row,DataExportRunId());
   DataExportCsvAdd(row,DataExportEnvironment());
   DataExportCsvAdd(row,DataExportTestFrom());
   DataExportCsvAdd(row,DataExportTestTo());
   DataExportCsvAdd(row,DataExportTesterModelName());
   DataExportCsvAdd(row,DataExportTerminalToken());
   DataExportCsvAdd(row,DataExportDataInstanceToken());
   DataExportCsvAdd(row,TimeToString(TimeCurrent(),TIME_DATE|TIME_SECONDS));
   DataExportCsvAdd(row,trace_bar_time>0 ?
      TimeToString(trace_bar_time,TIME_DATE|TIME_SECONDS) : "");
   DataExportCsvAdd(row,trace_bar_key);
   DataExportCsvAdd(row,_Symbol);
   DataExportCsvAdd(row,stage);
   DataExportCsvAdd(row,source_event_id);
   DataExportCsvAdd(row,counter_type);
   DataExportCsvAdd(row,(string)side);
   DataExportCsvAdd(row,(string)counter_before);
   DataExportCsvAdd(row,(string)counter_after);
   DataExportCsvAdd(row,decision);
   DataExportCsvAdd(row,reason);
   DataExportCsvAdd(row,order_requested?"YES":"NO");
   DataExportCsvAdd(row,order_result?"YES":"NO");
   DataExportCsvAdd(row,(string)retcode);
   DataExportCsvAdd(row,(string)position_id);
   DataExportCsvAdd(row,(string)ManagedPositionSide());
   DataExportCsvAdd(row,(string)g_range_long_signal_count);
   DataExportCsvAdd(row,(string)g_range_short_signal_count);
   DataExportCsvAdd(row,g_range_direction_confirm_pending?"YES":"NO");
   DataExportCsvAdd(row,(string)g_range_direction_confirm_side);
   DataExportCsvAdd(row,g_range_direction_confirm_signal_bar>0?
      TimeToString(g_range_direction_confirm_signal_bar,TIME_DATE|TIME_SECONDS):"");
   DataExportCsvAdd(row,DoubleToString(g_range_direction_confirm_high,_Digits));
   DataExportCsvAdd(row,DoubleToString(g_range_direction_confirm_low,_Digits));
   DataExportCsvAdd(row,g_range_trigger_entry_active?"YES":"NO");
   DataExportCsvAdd(row,(string)g_range_trigger_entry_side);
   DataExportCsvAdd(row,g_range_trigger_entry_fire_bar>0?
      TimeToString(g_range_trigger_entry_fire_bar,TIME_DATE|TIME_SECONDS):"");
   DataExportCsvAdd(row,(string)g_range_trigger_entry_final_count);
   DataExportCsvAdd(row,(string)g_add_same_direction_signal_count);
   DataExportCsvAdd(row,(string)g_initial_opposite_confirm_count);
   DataExportCsvAdd(row,g_entry_order_in_progress?"YES":"NO");
   DataExportCsvAdd(row,g_add_order_in_progress?"YES":"NO");
   DataExportCsvAdd(row,g_exit_order_in_progress?"YES":"NO");
   DataExportCsvAdd(row,DataExportHoldStateName());
   DataExportCsvAdd(row,DataExportProfitProtectionStateName());
   DataExportCsvAdd(row,g_range_long_signal_window[0] > 0 ? TimeToString(g_range_long_signal_window[0],TIME_DATE|TIME_MINUTES) : "");
   DataExportCsvAdd(row,g_range_long_signal_window[1] > 0 ? TimeToString(g_range_long_signal_window[1],TIME_DATE|TIME_MINUTES) : "");
   DataExportCsvAdd(row,g_range_long_signal_window[2] > 0 ? TimeToString(g_range_long_signal_window[2],TIME_DATE|TIME_MINUTES) : "");
   DataExportCsvAdd(row,g_range_short_signal_window[0] > 0 ? TimeToString(g_range_short_signal_window[0],TIME_DATE|TIME_MINUTES) : "");
   DataExportCsvAdd(row,g_range_short_signal_window[1] > 0 ? TimeToString(g_range_short_signal_window[1],TIME_DATE|TIME_MINUTES) : "");
   DataExportCsvAdd(row,g_range_short_signal_window[2] > 0 ? TimeToString(g_range_short_signal_window[2],TIME_DATE|TIME_MINUTES) : "");
   DataExportCsvAdd(row,(string)long_shift_1);
   DataExportCsvAdd(row,(string)long_shift_2);
   DataExportCsvAdd(row,(string)long_shift_3);
   DataExportCsvAdd(row,(string)short_shift_1);
   DataExportCsvAdd(row,(string)short_shift_2);
   DataExportCsvAdd(row,(string)short_shift_3);
   DataExportCsvAdd(row,(string)legacy_signal_window_bars);
   DataExportCsvAdd(row,long_window_valid?"YES":"NO");
   DataExportCsvAdd(row,short_window_valid?"YES":"NO");
   DataExportCsvAdd(row,(string)g_trade_cycle.cycle_id);
   DataExportCsvAdd(row,g_trade_cycle.parent_cycle_id);
   DataExportCsvAdd(row,g_trade_cycle.reentry_origin?"YES":"NO");
   DataExportCsvAdd(row,TradeCycleStateName(g_trade_cycle.state));
   DataExportCsvAdd(row,(string)g_trade_cycle.side);
   DataExportCsvAdd(row,g_trade_cycle.created_time>0?TimeToString(g_trade_cycle.created_time,TIME_DATE|TIME_SECONDS):"");
   DataExportCsvAdd(row,g_trade_cycle.updated_time>0?TimeToString(g_trade_cycle.updated_time,TIME_DATE|TIME_SECONDS):"");
   DataExportCsvAdd(row,(string)g_trade_cycle.initial_signal_count);
   DataExportCsvAdd(row,g_trade_cycle.initial_signal_times[0]>0?TimeToString(g_trade_cycle.initial_signal_times[0],TIME_DATE|TIME_MINUTES):"");
   DataExportCsvAdd(row,g_trade_cycle.initial_signal_times[1]>0?TimeToString(g_trade_cycle.initial_signal_times[1],TIME_DATE|TIME_MINUTES):"");
   DataExportCsvAdd(row,g_trade_cycle.initial_signal_times[2]>0?TimeToString(g_trade_cycle.initial_signal_times[2],TIME_DATE|TIME_MINUTES):"");
   DataExportCsvAdd(row,g_trade_cycle.third_signal_id);
   DataExportCsvAdd(row,DoubleToString(g_trade_cycle.breakout_reference,_Digits));
   DataExportCsvAdd(row,(string)g_trade_cycle.breakout_elapsed_bars);
   DataExportCsvAdd(row,g_trade_cycle.entry_source_event_id);
   DataExportCsvAdd(row,(string)g_trade_cycle.position_id);
   DataExportCsvAdd(row,g_trade_cycle.entry_time>0?TimeToString(g_trade_cycle.entry_time,TIME_DATE|TIME_SECONDS):"");
   DataExportCsvAdd(row,DoubleToString(g_trade_cycle.entry_price,_Digits));
   DataExportCsvAdd(row,DoubleToString(g_trade_cycle.initial_sl,_Digits));
   DataExportCsvAdd(row,DoubleToString(g_trade_cycle.initial_tp,_Digits));
   DataExportCsvAdd(row,(string)g_trade_cycle.add_signal_count);
   DataExportCsvAdd(row,(string)g_trade_cycle.additional_entry_count);
   DataExportCsvAdd(row,g_trade_cycle.add_last_consumed_pair_key);
   DataExportCsvAdd(row,TradeCycleHoldStateName());
   DataExportCsvAdd(row,TradeCycleProtectionStateName());
   DataExportCsvAdd(row,DoubleToString(g_trade_cycle.peak_r,4));
   DataExportCsvAdd(row,(string)g_trade_cycle.opposite_signal_count);
   DataExportCsvAdd(row,g_trade_cycle.exit_source_event_id);
   DataExportCsvAdd(row,g_trade_cycle.exit_reason);
   DataExportCsvAdd(row,g_trade_cycle.last_reset_reason);
   DataExportCsvAdd(row,(string)g_trade_cycle.event_sequence);
   DataExportCsvAdd(row,g_trade_cycle.last_stage);
   DataExportCsvAdd(row,g_trade_cycle.last_transition_reason);
   DataExportCsvAdd(row,g_trade_cycle.last_decision_bar_time>0?TimeToString(g_trade_cycle.last_decision_bar_time,TIME_DATE|TIME_SECONDS):"");
   DataExportCsvAdd(row,(string)g_trade_cycle.entry_deal_ticket);
   DataExportCsvAdd(row,(string)g_trade_cycle.exit_deal_ticket);
   DataExportCsvAdd(row,g_trade_cycle.exit_time>0?TimeToString(g_trade_cycle.exit_time,TIME_DATE|TIME_SECONDS):"");
   DataExportCsvAdd(row,DoubleToString(g_trade_cycle.exit_price,_Digits));
   DataExportCsvAdd(row,DoubleToString(g_trade_cycle.realized_net,2));
   DataExportCsvAdd(row,g_trade_cycle.completed?"YES":"NO");
   const int managed_side_now=ManagedPositionSide();
   const bool cycle_position_consistent =
      ((g_trade_cycle.state==JTA_CYCLE_POSITION_OPEN || g_trade_cycle.state==JTA_CYCLE_EXIT_PENDING)
         ? (managed_side_now!=0 && (g_trade_cycle.side==0 || managed_side_now==g_trade_cycle.side))
         : (g_trade_cycle.state==JTA_CYCLE_ENTRY_PENDING || g_trade_cycle.state==JTA_CYCLE_BREAKOUT_WAIT ||
            g_trade_cycle.state==JTA_CYCLE_SIGNAL_ACCUMULATING || g_trade_cycle.state==JTA_CYCLE_IDLE));
   DataExportCsvAdd(row,cycle_position_consistent?"YES":"NO");
   DataExportCsvAdd(row,g_decision_snapshot.bar_time>0?TimeToString(g_decision_snapshot.bar_time,TIME_DATE|TIME_MINUTES):"");
   DataExportCsvAdd(row,(string)g_decision_snapshot.timeframe_seconds);
   DataExportCsvAdd(row,g_decision_snapshot.final_long?"YES":"NO");
   DataExportCsvAdd(row,g_decision_snapshot.final_short?"YES":"NO");
   DataExportCsvAdd(row,(string)g_decision_snapshot.long_score);
   DataExportCsvAdd(row,(string)g_decision_snapshot.short_score);
   DataExportCsvAdd(row,(string)g_decision_snapshot.long_score_pre_context);
   DataExportCsvAdd(row,(string)g_decision_snapshot.short_score_pre_context);
   DataExportCsvAdd(row,(string)g_decision_snapshot.long_context_penalty);
   DataExportCsvAdd(row,(string)g_decision_snapshot.short_context_penalty);
   DataExportCsvAdd(row,g_decision_snapshot.long_event_id);
   DataExportCsvAdd(row,g_decision_snapshot.short_event_id);
   DataExportCsvAdd(row,g_decision_snapshot.shared_signal_auto_pass?"YES":"NO");
   DataExportCsvAdd(row,ReentryPermissionName());
   DataExportCsvAdd(row,g_reentry_context.active?"YES":"NO");
   DataExportCsvAdd(row,g_reentry_context.parent_cycle_id);
   DataExportCsvAdd(row,g_reentry_context.child_cycle_id);
   DataExportCsvAdd(row,(string)g_reentry_context.side);
   DataExportCsvAdd(row,g_reentry_context.exit_time>0?TimeToString(g_reentry_context.exit_time,TIME_DATE|TIME_SECONDS):"");
   DataExportCsvAdd(row,DoubleToString(g_reentry_context.exit_price,_Digits));
   DataExportCsvAdd(row,(string)g_reentry_context.signal_count);
   DataExportCsvAdd(row,g_reentry_context.signal_ids[0]);
   DataExportCsvAdd(row,g_reentry_context.signal_ids[1]);
   DataExportCsvAdd(row,ReentryContextPairKey());
   DataExportCsvAdd(row,g_reentry_context.last_attempted_pair_key);
   DataExportCsvAdd(row,g_reentry_context.order_pending?"YES":"NO");
   DataExportCsvAdd(row,g_reentry_context.last_block_reason);
   const string management_strategy =
      (g_position_strategy==STRATEGY_RANGE ? "RANGE" : "TREND");

   DataExportCsvAdd(row,management_strategy);
   DataExportCsvAdd(row,EnumToString(ActiveManagementTF()));
   DataExportCsvAdd(row,g_hold_evaluation_ready?"YES":"NO");
   DataExportCsvAdd(row,g_hold_evaluation_bar>0?
      TimeToString(g_hold_evaluation_bar,TIME_DATE|TIME_MINUTES):"");
   DataExportCsvAdd(row,(string)g_hold_direction_score);
   DataExportCsvAdd(row,(string)g_hold_weakness_score);
   DataExportCsvAdd(row,DoubleToString(g_highest_profit_r,4));
   DataExportCsvAdd(row,DataExportProfitProtectionStateName());

   DataExportCsvAdd(row,DataExportProgramName());
   DataExportCsvAdd(row,DataExportEaVersion());
   DataExportCsvAdd(row,DataExportCsvSchemaVersion());
   DataExportCsvAdd(row,DataExportStrategyNameValue(g_selected_strategy));
   DataExportCsvAdd(row,DataExportStrategyNameValue(g_position_strategy));
   DataExportCsvAdd(row,DataExportSignalTfName());
   DataExportCsvAdd(row,DoubleToString(g_csv_stage1_configured_r,6));
   DataExportCsvAdd(row,DoubleToString(g_csv_stage1_net_positive_r,6));
   DataExportCsvAdd(row,DoubleToString(g_csv_stage1_effective_r,6));
   DataExportCsvAdd(row,DoubleToString(g_csv_stage1_entry_charge,2));
   DataExportCsvAdd(row,DoubleToString(g_csv_stage1_negative_swap,2));
   DataExportCsvAdd(row,DoubleToString(g_csv_stage1_estimated_exit_cost,2));
   DataExportCsvAdd(row,DoubleToString(g_csv_stage1_one_r_money,2));
   DataExportCsvAdd(row,g_csv_profit_lock_attempted?"YES":"NO");
   DataExportCsvAdd(row,DoubleToString(g_csv_profit_lock_requested_r,6));
   DataExportCsvAdd(row,DoubleToString(g_csv_profit_lock_requested_sl,_Digits));
   DataExportCsvAdd(row,g_csv_profit_lock_applied?"YES":"NO");
   DataExportCsvAdd(row,DoubleToString(g_csv_profit_lock_applied_sl,_Digits));
   DataExportCsvAdd(row,(string)g_csv_profit_lock_retcode);
   DataExportCsvAdd(row,g_csv_profit_lock_block_reason);
   FileWriteString(handle,row+"\r\n");
   g_live_order_audit_dirty=true;
   const bool critical_order_audit=
      order_requested || order_result ||
      DataExportIsCriticalEvent("ORDER",stage,decision);
   if(critical_order_audit)
      DataExportFlushLiveHandleNow(g_live_order_audit_handle,
         g_live_order_audit_dirty,g_live_order_audit_flush_msc);
}



void DataExportWritePreReversalLifecycleAudit(const datetime bar_time,
                                              const ENUM_TIMEFRAMES tf,
                                              const string event,
                                              const int side,
                                              const string detail)
{
   if(g_integrated_csv_mode)
   {
      if(bar_time>0 && side!=0)
         DataExportWriteUnifiedEvent("LIFECYCLE","PRE_REVERSAL_"+event,side,0,0.0,0.0,0,
            "OBSERVE",detail,"",0.0,0.0,"PRE_REVERSAL_LIFECYCLE",bar_time);
      return;
   }

   if(bar_time<=0 || side==0) return;

   // Diagnostic-only episode tracker. It never feeds StateEvaluation,
   // SignalEngine, FINAL, 3X, Trigger, Entry, Hold, Risk or Exit logic.
   static int active_side=0;
   static datetime episode_start=0;
   static ENUM_TIMEFRAMES episode_tf=PERIOD_CURRENT;
   static int pulse_count=0;
   static datetime signal_reversal_time=0;
   static datetime first_final_time=0;

   if(event=="START" || event=="FLIP")
   {
      active_side=side;
      episode_start=bar_time;
      episode_tf=tf;
      pulse_count=1;
      signal_reversal_time=0;
      first_final_time=0;
   }
   else if(event=="REPEAT" && active_side==side)
      pulse_count++;
   else if(event=="SIGNAL_REVERSAL" && active_side==side && signal_reversal_time<=0)
      signal_reversal_time=bar_time;
   else if(event=="FIRST_FINAL" && active_side==side && first_final_time<=0)
      first_final_time=bar_time;

   const ENUM_TIMEFRAMES audit_tf=(episode_start>0 && episode_tf!=PERIOD_CURRENT ? episode_tf : tf);
   int bars_from_start=-1;
   if(episode_start>0 && active_side==side)
   {
      const int shift=iBarShift(_Symbol,audit_tf,episode_start,false);
      const int now_shift=iBarShift(_Symbol,audit_tf,bar_time,false);
      if(shift>=0 && now_shift>=0) bars_from_start=MathMax(0,shift-now_shift);
   }

   const string tf_name=EnumToString(audit_tf);
   const string file_name=DataExportPath(StringFormat(
      "JTA_PreReversalLifecycleAudit_v1_00_%s_%s.csv",_Symbol,tf_name));
   if(g_pre_reversal_audit_handle==INVALID_HANDLE || g_pre_reversal_audit_file!=file_name)
   {
      if(g_pre_reversal_audit_handle!=INVALID_HANDLE)
      {
         FileFlush(g_pre_reversal_audit_handle);
         FileClose(g_pre_reversal_audit_handle);
      }
      g_pre_reversal_audit_handle=FileOpen(file_name,
         DataExportFileFlags(FILE_READ|FILE_WRITE|FILE_ANSI|FILE_SHARE_READ|FILE_SHARE_WRITE),0,CP_UTF8);
      g_pre_reversal_audit_file=file_name;
      if(g_pre_reversal_audit_handle==INVALID_HANDLE)
      {
         g_pre_reversal_audit_file="";
         PrintFormat("[PRE-REVERSAL CSV] OPEN FAILED | file=%s | error=%d",file_name,GetLastError());
         return;
      }
      FileSeek(g_pre_reversal_audit_handle,0,SEEK_END);
      if(FileSize(g_pre_reversal_audit_handle)==0)
      {
         string h="";
         DataExportCsvAdd(h,"time"); DataExportCsvAdd(h,"symbol"); DataExportCsvAdd(h,"tf");
         DataExportCsvAdd(h,"event"); DataExportCsvAdd(h,"side");
         DataExportCsvAdd(h,"episode_start"); DataExportCsvAdd(h,"pulse_count"); DataExportCsvAdd(h,"bars_from_start");
         DataExportCsvAdd(h,"signal_reversal_time"); DataExportCsvAdd(h,"first_final_time");
         DataExportCsvAdd(h,"persistent_direction"); DataExportCsvAdd(h,"assist_previous_state"); DataExportCsvAdd(h,"assist_state");
         DataExportCsvAdd(h,"assist_watch_pulse"); DataExportCsvAdd(h,"assist_macd_wave"); DataExportCsvAdd(h,"assist_raw_macd");
         DataExportCsvAdd(h,"assist_raw_delta"); DataExportCsvAdd(h,"assist_ema_delta");
         DataExportCsvAdd(h,"assist_macd_transition_up"); DataExportCsvAdd(h,"assist_macd_transition_down");
         DataExportCsvAdd(h,"assist_price_up"); DataExportCsvAdd(h,"assist_price_down");
         DataExportCsvAdd(h,"signal_b7_long_authorized"); DataExportCsvAdd(h,"signal_b7_short_authorized");
         DataExportCsvAdd(h,"signal_b6_long_authorized"); DataExportCsvAdd(h,"signal_b6_short_authorized");
         DataExportCsvAdd(h,"detail");
         FileWriteString(g_pre_reversal_audit_handle,h+"\r\n");
      }
   }

   string r="";
   DataExportCsvAdd(r,TimeToString(bar_time,TIME_DATE|TIME_SECONDS)); DataExportCsvAdd(r,_Symbol); DataExportCsvAdd(r,tf_name);
   DataExportCsvAdd(r,event); DataExportCsvAdd(r,side>0?"LONG":"SHORT");
   DataExportCsvAdd(r,episode_start>0?TimeToString(episode_start,TIME_DATE|TIME_SECONDS):"");
   DataExportCsvAdd(r,IntegerToString(pulse_count)); DataExportCsvAdd(r,IntegerToString(bars_from_start));
   DataExportCsvAdd(r,signal_reversal_time>0?TimeToString(signal_reversal_time,TIME_DATE|TIME_SECONDS):"");
   DataExportCsvAdd(r,first_final_time>0?TimeToString(first_final_time,TIME_DATE|TIME_SECONDS):"");
   DataExportCsvAdd(r,IntegerToString(g_range_persistent_direction));
   DataExportCsvAdd(r,AssistStateName(g_assist_state.previous_state)); DataExportCsvAdd(r,AssistStateName(g_assist_state.state));
   DataExportCsvAdd(r,g_assist_state.watch_pulse?"1":"0");
   DataExportCsvAdd(r,DoubleToString(g_assist_state.macd_wave,8)); DataExportCsvAdd(r,DoubleToString(g_assist_state.raw_macd,8));
   DataExportCsvAdd(r,DoubleToString(g_assist_state.raw_delta,8)); DataExportCsvAdd(r,DoubleToString(g_assist_state.ema_delta,8));
   DataExportCsvAdd(r,g_assist_state.macd_transition_up?"1":"0"); DataExportCsvAdd(r,g_assist_state.macd_transition_down?"1":"0");
   DataExportCsvAdd(r,g_assist_state.price_up?"1":"0"); DataExportCsvAdd(r,g_assist_state.price_down?"1":"0");
   const bool signal_event=(event=="SIGNAL_REVERSAL");
   DataExportCsvAdd(r,signal_event ? (g_watch_snapshot.current_long_authorized?"1":"0") : "");
   DataExportCsvAdd(r,signal_event ? (g_watch_snapshot.current_short_authorized?"1":"0") : "");
   DataExportCsvAdd(r,signal_event ? (g_watch_snapshot.shadow_b6_long_authorized?"1":"0") : "");
   DataExportCsvAdd(r,signal_event ? (g_watch_snapshot.shadow_b6_short_authorized?"1":"0") : "");
   DataExportCsvAdd(r,detail);
   FileWriteString(g_pre_reversal_audit_handle,r+"\r\n");
   g_pre_reversal_audit_rows_since_flush++;
   if(event!="REPEAT" || g_pre_reversal_audit_rows_since_flush>=64)
   {
      FileFlush(g_pre_reversal_audit_handle);
      g_pre_reversal_audit_rows_since_flush=0;
   }

   if(event=="CANCEL" && active_side==side)
   {
      active_side=0; episode_start=0; episode_tf=PERIOD_CURRENT; pulse_count=0; signal_reversal_time=0; first_final_time=0;
   }
   else if(event=="FIRST_FINAL" && active_side==side)
   {
      active_side=0; episode_start=0; episode_tf=PERIOD_CURRENT; pulse_count=0; signal_reversal_time=0; first_final_time=0;
   }
}


void DataExportWriteWatchSignalAudit()
{

   DataExportWriteUnifiedEvent("WATCH","WATCH_SNAPSHOT",0,0,0.0,0.0,
      MathMax(g_watch_snapshot.long_score,g_watch_snapshot.short_score),
      "OBSERVE",
      "LONG="+g_watch_snapshot.long_reason+" | SHORT="+g_watch_snapshot.short_reason,
      "",
      g_watch_snapshot.range_position,g_watch_snapshot.atr_ratio,
      StringFormat("L=%d/%d S=%d/%d DELTA_RATIO=%.6f DOM=%d LTRG=%.10f STRG=%.10f",
                   g_watch_snapshot.long_score,g_watch_snapshot.long_stage,
                   g_watch_snapshot.short_score,g_watch_snapshot.short_stage,
                   g_watch_snapshot.delta_ratio,g_watch_snapshot.dominant_side,
                   g_watch_snapshot.long_trigger_price,g_watch_snapshot.short_trigger_price),
      g_watch_snapshot.bar_time);
   if(g_integrated_csv_mode) return;

   if(!InpWatchWriteCSV || g_watch_snapshot.bar_time<=0) return;
   const string tf=DataExportSignalTfName();
   const string file_name=DataExportPath(StringFormat("JTA_WatchSignalAudit_v1_02_%s_%s.csv",_Symbol,tf));
   if(g_diag_watch_handle==INVALID_HANDLE ||
      g_diag_watch_file!=file_name)
   {
      if(g_diag_watch_handle!=INVALID_HANDLE)
         DataExportFlushOneDiagnostic(g_diag_watch_handle,
            g_diag_watch_dirty,g_diag_watch_flush_msc,true);

      g_diag_watch_handle=FileOpen(file_name,
         DataExportFileFlags(FILE_READ|FILE_WRITE|FILE_ANSI|FILE_SHARE_READ|FILE_SHARE_WRITE),
         0,CP_UTF8);
      g_diag_watch_file=file_name;
      if(g_diag_watch_handle==INVALID_HANDLE)
      {
         g_diag_watch_file="";
         PrintFormat("[WATCH CSV] OPEN FAILED | file=%s | error=%d",file_name,GetLastError());
         return;
      }
      FileSeek(g_diag_watch_handle,0,SEEK_END);
      if(FileSize(g_diag_watch_handle)==0)
      {
      string h="";
      DataExportCsvAdd(h,"time"); DataExportCsvAdd(h,"symbol"); DataExportCsvAdd(h,"tf");
      DataExportCsvAdd(h,"strategy"); DataExportCsvAdd(h,"watch_alert_enabled");
      DataExportCsvAdd(h,"system_alert_enabled"); DataExportCsvAdd(h,"mobile_alert_enabled");
      DataExportCsvAdd(h,"long_stage"); DataExportCsvAdd(h,"short_stage");
      DataExportCsvAdd(h,"long_score"); DataExportCsvAdd(h,"short_score");
      DataExportCsvAdd(h,"momentum_long"); DataExportCsvAdd(h,"momentum_short");
      DataExportCsvAdd(h,"flow_long"); DataExportCsvAdd(h,"flow_short");
      DataExportCsvAdd(h,"structure_long"); DataExportCsvAdd(h,"structure_short");
      DataExportCsvAdd(h,"range_pressure_long"); DataExportCsvAdd(h,"range_pressure_short");
      DataExportCsvAdd(h,"context_long"); DataExportCsvAdd(h,"context_short");
      DataExportCsvAdd(h,"active_compression"); DataExportCsvAdd(h,"dead_range");
      DataExportCsvAdd(h,"opposite_pressure_decay_long"); DataExportCsvAdd(h,"opposite_pressure_decay_short");
      DataExportCsvAdd(h,"price_response_long"); DataExportCsvAdd(h,"price_response_short");
      DataExportCsvAdd(h,"chase_penalty_long"); DataExportCsvAdd(h,"chase_penalty_short");
      DataExportCsvAdd(h,"macd_turn_age_long"); DataExportCsvAdd(h,"macd_turn_age_short");
      DataExportCsvAdd(h,"delta_turn_age_long"); DataExportCsvAdd(h,"delta_turn_age_short");
      DataExportCsvAdd(h,"dema_turn_age_long"); DataExportCsvAdd(h,"dema_turn_age_short");
      DataExportCsvAdd(h,"range_position"); DataExportCsvAdd(h,"atr_ratio"); DataExportCsvAdd(h,"delta_ratio");
      DataExportCsvAdd(h,"dominant_side"); DataExportCsvAdd(h,"delta_dominance");
      DataExportCsvAdd(h,"long_segment_start"); DataExportCsvAdd(h,"short_segment_start");
      DataExportCsvAdd(h,"long_segment_start_price"); DataExportCsvAdd(h,"short_segment_start_price");
      DataExportCsvAdd(h,"long_trigger_base_price"); DataExportCsvAdd(h,"short_trigger_base_price");
      DataExportCsvAdd(h,"long_trigger_price"); DataExportCsvAdd(h,"short_trigger_price");
      DataExportCsvAdd(h,"long_trigger_buffer"); DataExportCsvAdd(h,"short_trigger_buffer");
      DataExportCsvAdd(h,"long_trigger_source"); DataExportCsvAdd(h,"short_trigger_source");
      DataExportCsvAdd(h,"long_trigger_fired"); DataExportCsvAdd(h,"short_trigger_fired");
      DataExportCsvAdd(h,"long_trigger_fire_time"); DataExportCsvAdd(h,"short_trigger_fire_time");
      DataExportCsvAdd(h,"long_trigger_fire_price"); DataExportCsvAdd(h,"short_trigger_fire_price");
      DataExportCsvAdd(h,"system_alert_fired"); DataExportCsvAdd(h,"mobile_alert_fired");
      DataExportCsvAdd(h,"long_reason"); DataExportCsvAdd(h,"short_reason");
      DataExportCsvAdd(h,"macd_b7_now"); DataExportCsvAdd(h,"macd_b7_prev");
      DataExportCsvAdd(h,"macd_b6_now"); DataExportCsvAdd(h,"macd_b6_prev");
      DataExportCsvAdd(h,"macd_b7_regime"); DataExportCsvAdd(h,"macd_b6_regime");
      DataExportCsvAdd(h,"macd_b6_turn_age_long"); DataExportCsvAdd(h,"macd_b6_turn_age_short");
      DataExportCsvAdd(h,"delta_raw_now"); DataExportCsvAdd(h,"delta_ema_now");
      DataExportCsvAdd(h,"delta_buy_bars"); DataExportCsvAdd(h,"delta_sell_bars"); DataExportCsvAdd(h,"delta_sum");
      DataExportCsvAdd(h,"current_long_authorized"); DataExportCsvAdd(h,"current_short_authorized");
      DataExportCsvAdd(h,"shadow_b6_valid"); DataExportCsvAdd(h,"shadow_b6_dead_range");
      DataExportCsvAdd(h,"shadow_b6_momentum_long"); DataExportCsvAdd(h,"shadow_b6_momentum_short");
      DataExportCsvAdd(h,"shadow_b6_context_long"); DataExportCsvAdd(h,"shadow_b6_context_short");
      DataExportCsvAdd(h,"shadow_b6_long_score"); DataExportCsvAdd(h,"shadow_b6_short_score");
      DataExportCsvAdd(h,"shadow_b6_long_stage"); DataExportCsvAdd(h,"shadow_b6_short_stage");
      DataExportCsvAdd(h,"shadow_b6_dominant_side");
      DataExportCsvAdd(h,"shadow_b6_long_authorized"); DataExportCsvAdd(h,"shadow_b6_short_authorized");
         FileWriteString(g_diag_watch_handle,h+"\r\n");
         FileFlush(g_diag_watch_handle);
         g_diag_watch_flush_msc=GetTickCount64();
      }
   }
   string r="";
   DataExportCsvAdd(r,TimeToString(g_watch_snapshot.bar_time,TIME_DATE|TIME_SECONDS));
   DataExportCsvAdd(r,_Symbol); DataExportCsvAdd(r,tf); DataExportCsvAdd(r,DataExportStrategyNameValue(g_selected_strategy));
   DataExportCsvAdd(r,g_watch_mode!=WATCH_MODE_OFF?"YES":"NO"); DataExportCsvAdd(r,g_terminal_alert?"YES":"NO"); DataExportCsvAdd(r,g_mobile_alert?"YES":"NO");
   DataExportCsvAdd(r,WatchStageCode(1,g_watch_snapshot.long_stage)); DataExportCsvAdd(r,WatchStageCode(-1,g_watch_snapshot.short_stage));
   DataExportCsvAdd(r,IntegerToString(g_watch_snapshot.long_score)); DataExportCsvAdd(r,IntegerToString(g_watch_snapshot.short_score));
   DataExportCsvAdd(r,IntegerToString(g_watch_snapshot.momentum_long)); DataExportCsvAdd(r,IntegerToString(g_watch_snapshot.momentum_short));
   DataExportCsvAdd(r,IntegerToString(g_watch_snapshot.flow_long)); DataExportCsvAdd(r,IntegerToString(g_watch_snapshot.flow_short));
   DataExportCsvAdd(r,IntegerToString(g_watch_snapshot.structure_long)); DataExportCsvAdd(r,IntegerToString(g_watch_snapshot.structure_short));
   DataExportCsvAdd(r,IntegerToString(g_watch_snapshot.range_long)); DataExportCsvAdd(r,IntegerToString(g_watch_snapshot.range_short));
   DataExportCsvAdd(r,IntegerToString(g_watch_snapshot.context_long)); DataExportCsvAdd(r,IntegerToString(g_watch_snapshot.context_short));
   DataExportCsvAdd(r,g_watch_snapshot.active_compression?"YES":"NO"); DataExportCsvAdd(r,g_watch_snapshot.dead_range?"YES":"NO");
   DataExportCsvAdd(r,g_watch_snapshot.opposite_pressure_decay_long?"YES":"NO"); DataExportCsvAdd(r,g_watch_snapshot.opposite_pressure_decay_short?"YES":"NO");
   DataExportCsvAdd(r,g_watch_snapshot.price_response_long?"YES":"NO"); DataExportCsvAdd(r,g_watch_snapshot.price_response_short?"YES":"NO");
   DataExportCsvAdd(r,g_watch_snapshot.chase_penalty_long?"YES":"NO"); DataExportCsvAdd(r,g_watch_snapshot.chase_penalty_short?"YES":"NO");
   DataExportCsvAdd(r,IntegerToString(g_watch_snapshot.macd_turn_age_long)); DataExportCsvAdd(r,IntegerToString(g_watch_snapshot.macd_turn_age_short));
   DataExportCsvAdd(r,IntegerToString(g_watch_snapshot.delta_turn_age_long)); DataExportCsvAdd(r,IntegerToString(g_watch_snapshot.delta_turn_age_short));
   DataExportCsvAdd(r,IntegerToString(g_watch_snapshot.dema_turn_age_long)); DataExportCsvAdd(r,IntegerToString(g_watch_snapshot.dema_turn_age_short));
   DataExportCsvAdd(r,DoubleToString(g_watch_snapshot.range_position,4)); DataExportCsvAdd(r,DoubleToString(g_watch_snapshot.atr_ratio,4));
   DataExportCsvAdd(r,DoubleToString(g_watch_snapshot.delta_ratio,4));
   DataExportCsvAdd(r,IntegerToString(g_watch_snapshot.dominant_side));
   DataExportCsvAdd(r,IntegerToString(g_watch_snapshot.delta_dominance));
   DataExportCsvAdd(r,g_watch_snapshot.long_segment_start>0?TimeToString(g_watch_snapshot.long_segment_start,TIME_DATE|TIME_SECONDS):"");
   DataExportCsvAdd(r,g_watch_snapshot.short_segment_start>0?TimeToString(g_watch_snapshot.short_segment_start,TIME_DATE|TIME_SECONDS):"");
   DataExportCsvAdd(r,DoubleToString(g_watch_snapshot.long_segment_start_price,_Digits));
   DataExportCsvAdd(r,DoubleToString(g_watch_snapshot.short_segment_start_price,_Digits));
   DataExportCsvAdd(r,DoubleToString(g_watch_snapshot.long_trigger_base_price,_Digits));
   DataExportCsvAdd(r,DoubleToString(g_watch_snapshot.short_trigger_base_price,_Digits));
   DataExportCsvAdd(r,DoubleToString(g_watch_snapshot.long_trigger_price,_Digits));
   DataExportCsvAdd(r,DoubleToString(g_watch_snapshot.short_trigger_price,_Digits));
   DataExportCsvAdd(r,DoubleToString(g_watch_snapshot.long_trigger_buffer,_Digits));
   DataExportCsvAdd(r,DoubleToString(g_watch_snapshot.short_trigger_buffer,_Digits));
   DataExportCsvAdd(r,g_watch_snapshot.long_trigger_source);
   DataExportCsvAdd(r,g_watch_snapshot.short_trigger_source);
   DataExportCsvAdd(r,g_watch_snapshot.long_trigger_fired?"YES":"NO");
   DataExportCsvAdd(r,g_watch_snapshot.short_trigger_fired?"YES":"NO");
   DataExportCsvAdd(r,g_watch_snapshot.long_trigger_fire_time>0?TimeToString(g_watch_snapshot.long_trigger_fire_time,TIME_DATE|TIME_SECONDS):"");
   DataExportCsvAdd(r,g_watch_snapshot.short_trigger_fire_time>0?TimeToString(g_watch_snapshot.short_trigger_fire_time,TIME_DATE|TIME_SECONDS):"");
   DataExportCsvAdd(r,DoubleToString(g_watch_snapshot.long_trigger_fire_price,_Digits));
   DataExportCsvAdd(r,DoubleToString(g_watch_snapshot.short_trigger_fire_price,_Digits));
   DataExportCsvAdd(r,g_watch_snapshot.system_alert_fired?"YES":"NO"); DataExportCsvAdd(r,g_watch_snapshot.mobile_alert_fired?"YES":"NO");
   DataExportCsvAdd(r,g_watch_snapshot.long_reason); DataExportCsvAdd(r,g_watch_snapshot.short_reason);
   DataExportCsvAdd(r,DoubleToString(g_watch_snapshot.macd_b7_now,8)); DataExportCsvAdd(r,DoubleToString(g_watch_snapshot.macd_b7_prev,8));
   DataExportCsvAdd(r,DoubleToString(g_watch_snapshot.macd_b6_now,8)); DataExportCsvAdd(r,DoubleToString(g_watch_snapshot.macd_b6_prev,8));
   DataExportCsvAdd(r,IntegerToString(g_watch_snapshot.macd_b7_regime)); DataExportCsvAdd(r,IntegerToString(g_watch_snapshot.macd_b6_regime));
   DataExportCsvAdd(r,IntegerToString(g_watch_snapshot.macd_b6_turn_age_long)); DataExportCsvAdd(r,IntegerToString(g_watch_snapshot.macd_b6_turn_age_short));
   DataExportCsvAdd(r,DoubleToString(g_watch_snapshot.delta_raw_now,8)); DataExportCsvAdd(r,DoubleToString(g_watch_snapshot.delta_ema_now,8));
   DataExportCsvAdd(r,IntegerToString(g_watch_snapshot.delta_buy_bars)); DataExportCsvAdd(r,IntegerToString(g_watch_snapshot.delta_sell_bars)); DataExportCsvAdd(r,DoubleToString(g_watch_snapshot.delta_sum,8));
   DataExportCsvAdd(r,g_watch_snapshot.current_long_authorized?"YES":"NO"); DataExportCsvAdd(r,g_watch_snapshot.current_short_authorized?"YES":"NO");
   DataExportCsvAdd(r,g_watch_snapshot.shadow_b6_valid?"YES":"NO"); DataExportCsvAdd(r,g_watch_snapshot.shadow_b6_dead_range?"YES":"NO");
   DataExportCsvAdd(r,IntegerToString(g_watch_snapshot.shadow_b6_momentum_long)); DataExportCsvAdd(r,IntegerToString(g_watch_snapshot.shadow_b6_momentum_short));
   DataExportCsvAdd(r,IntegerToString(g_watch_snapshot.shadow_b6_context_long)); DataExportCsvAdd(r,IntegerToString(g_watch_snapshot.shadow_b6_context_short));
   DataExportCsvAdd(r,IntegerToString(g_watch_snapshot.shadow_b6_long_score)); DataExportCsvAdd(r,IntegerToString(g_watch_snapshot.shadow_b6_short_score));
   DataExportCsvAdd(r,IntegerToString(g_watch_snapshot.shadow_b6_long_stage)); DataExportCsvAdd(r,IntegerToString(g_watch_snapshot.shadow_b6_short_stage));
   DataExportCsvAdd(r,IntegerToString(g_watch_snapshot.shadow_b6_dominant_side));
   DataExportCsvAdd(r,g_watch_snapshot.shadow_b6_long_authorized?"YES":"NO"); DataExportCsvAdd(r,g_watch_snapshot.shadow_b6_short_authorized?"YES":"NO");
   FileWriteString(g_diag_watch_handle,r+"\r\n");
   g_diag_watch_dirty=true;
   DataExportFlushBufferedDiagnostics(false);
}


void DataExportWriteConfirmedMomentumAudit(const datetime bar_time,
                                           const ENUM_TIMEFRAMES tf,
                                           const int side,
                                           const int final_score,
                                           const string mode,
                                           const string macd_state,
                                           const string delta_state,
                                           const string price_state,
                                           const string higher_tf_state,
                                           const string detail)
{
   if(bar_time<=0 || side==0) return;
   DataExportWriteUnifiedEvent("SIGNAL",
      side>0 ? "CONFIRMED_MOMENTUM_LONG" : "CONFIRMED_MOMENTUM_SHORT",
      side,0,0.0,0.0,final_score,"OBSERVE",detail,"",0.0,0.0,
      mode+" | "+macd_state+" | "+delta_state+" | "+price_state+" | "+higher_tf_state,
      bar_time);
   if(g_integrated_csv_mode) return;

   const string tf_name=EnumToString(tf);
   const string file_name=DataExportPath(StringFormat(
      "JTA_ConfirmedMomentumAudit_v1_00_%s_%s.csv",_Symbol,tf_name));
   const bool live_buffered=DataExportEnsureLiveBufferedHandle(
      file_name,g_live_confirmed_momentum_handle,g_live_confirmed_momentum_file);
   int h=(live_buffered ? g_live_confirmed_momentum_handle :
      FileOpen(file_name,
         DataExportFileFlags(FILE_READ|FILE_WRITE|FILE_ANSI|FILE_SHARE_READ|FILE_SHARE_WRITE),
         0,CP_UTF8));
   if(h==INVALID_HANDLE)
   {
      PrintFormat("[CONFIRMED MOMENTUM CSV] OPEN FAILED | file=%s | error=%d",file_name,GetLastError());
      return;
   }
   // Persistent LIVE handle already stays at EOF after each write. Tester/fallback
   // keeps the original explicit EOF seek so generated analysis data is identical.
   if(!live_buffered)
      FileSeek(h,0,SEEK_END);
   if(FileSize(h)==0)
   {
      string header="";
      DataExportCsvAdd(header,"time");
      DataExportCsvAdd(header,"symbol");
      DataExportCsvAdd(header,"tf");
      DataExportCsvAdd(header,"strategy");
      DataExportCsvAdd(header,"side");
      DataExportCsvAdd(header,"final_score");
      DataExportCsvAdd(header,"mode");
      DataExportCsvAdd(header,"macd_state");
      DataExportCsvAdd(header,"delta_state");
      DataExportCsvAdd(header,"price_state");
      DataExportCsvAdd(header,"higher_tf_state");
      DataExportCsvAdd(header,"detail");
      DataExportCsvAdd(header,"auto_enabled");
      DataExportCsvAdd(header,"signal_enabled");
      FileWriteString(h,header+"\r\n");
   }
   string row="";
   DataExportCsvAdd(row,TimeToString(bar_time,TIME_DATE|TIME_SECONDS));
   DataExportCsvAdd(row,_Symbol);
   DataExportCsvAdd(row,tf_name);
   DataExportCsvAdd(row,DataExportStrategyNameValue(g_selected_strategy));
   DataExportCsvAdd(row,side>0 ? "LONG" : "SHORT");
   DataExportCsvAdd(row,IntegerToString(final_score));
   DataExportCsvAdd(row,mode);
   DataExportCsvAdd(row,macd_state);
   DataExportCsvAdd(row,delta_state);
   DataExportCsvAdd(row,price_state);
   DataExportCsvAdd(row,higher_tf_state);
   DataExportCsvAdd(row,detail);
   DataExportCsvAdd(row,g_auto_trading ? "YES" : "NO");
   DataExportCsvAdd(row,g_signal_enabled ? "YES" : "NO");
   FileWriteString(h,row+"\r\n");
   if(live_buffered)
   {
      g_live_confirmed_momentum_dirty=true;
      DataExportFlushLiveBufferedFiles(false);
   }
   else
   {
      // Tester/fallback semantics are intentionally unchanged for exact analysis parity.
      FileFlush(h);
      FileClose(h);
   }
}

//+------------------------------------------------------------------+
//| v7.11 Manual Assist State trajectory audit                       |
//| One buffered handle, one row per completed assist bar.           |
//+------------------------------------------------------------------+
void WriteAssistStateCsv()
{
   if(g_integrated_csv_mode)
   {
      if(g_assist_state.bar_time>0)
         DataExportWriteUnifiedEvent("ASSIST","STATE_"+AssistStateName(g_assist_state.state),0,0,
            g_assist_state.close_price,0.0,0,"OBSERVE",g_assist_state.reason,"",
            g_assist_state.raw_macd,g_assist_state.raw_delta,
            StringFormat("TF=%s PREV=%s",EnumToString(g_assist_state.timeframe),AssistStateName(g_assist_state.previous_state)),
            g_assist_state.bar_time);
      return;
   }

   if(!InpAssistStateEnabled || !InpAssistStateWriteCSV || g_assist_state.bar_time<=0)
      return;

   if(g_assist_csv_handle==INVALID_HANDLE)
   {
      const string tf_token=EnumToString(StateEvaluationTimeframe());
       g_assist_csv_file=StringFormat("%sJTA_AssistState_v%s_%s_%s.csv",
          DataExportIsTester() ? ("TEST_"+DataExportRunId()+"_") : "",
          JTC_EA_VERSION,TradeLogSafeFileToken(_Symbol),tf_token);
      g_assist_csv_handle=FileOpen(g_assist_csv_file,
         FILE_READ|FILE_WRITE|FILE_TXT|FILE_ANSI|FILE_SHARE_READ|FILE_SHARE_WRITE);
      if(g_assist_csv_handle==INVALID_HANDLE)
      {
         PrintFormat("[ASSIST STATE CSV] open failed | %s | error=%d",
            g_assist_csv_file,GetLastError());
         return;
      }
      if(FileSize(g_assist_csv_handle)==0)
      {
         FileWriteString(g_assist_csv_handle,
            "ea_version,run_id,time_server,symbol,timeframe,state,previous_state,reason,"+
            "open,high,low,close,macd_zero_state,source_volume,avg_range,net_progress_r,recent_progress_r,"+
            "higher_high_steps,higher_low_steps,lower_high_steps,lower_low_steps,"+
            "up_close_steps,down_close_steps,raw_macd,macd_change_1,macd_change_3,"+
            "macd_direction,raw_delta,ema_delta,delta_change\r\n");
      }
      FileSeek(g_assist_csv_handle,0,SEEK_END);
   }

   const string row=StringFormat(
      "%s,%s,%s,%s,%s,%s,%s,%s,%.*f,%.*f,%.*f,%.*f,%d,%.10f,%.8f,%.6f,%.6f,%d,%d,%d,%d,%d,%d,%.10f,%.10f,%.10f,%d,%.10f,%.10f,%.10f\r\n",
      JTC_EA_VERSION,DataExportRunId(),
      TimeToString(g_assist_state.bar_time,TIME_DATE|TIME_SECONDS),
      TradeLogSafeFileToken(_Symbol),EnumToString(g_assist_state.timeframe),
      AssistStateName(g_assist_state.state),AssistStateName(g_assist_state.previous_state),
       g_assist_state.reason,
       _Digits,g_assist_state.open_price,_Digits,g_assist_state.high_price,
       _Digits,g_assist_state.low_price,_Digits,g_assist_state.close_price,
       g_assist_state.macd_zero_state,g_assist_state.source_volume,
       g_assist_state.avg_range,g_assist_state.net_progress_r,g_assist_state.recent_progress_r,
       g_assist_state.higher_high_steps,g_assist_state.higher_low_steps,
       g_assist_state.lower_high_steps,g_assist_state.lower_low_steps,
       g_assist_state.up_close_steps,g_assist_state.down_close_steps,
       g_assist_state.raw_macd,g_assist_state.macd_change_1,g_assist_state.macd_change_3,
       g_assist_state.macd_direction,g_assist_state.raw_delta,g_assist_state.ema_delta,
       g_assist_state.delta_change);
   FileWriteString(g_assist_csv_handle,row);
}

void CloseAssistStateCsv()
{
   if(g_assist_csv_handle!=INVALID_HANDLE)
   {
      FileFlush(g_assist_csv_handle);
      FileClose(g_assist_csv_handle);
      g_assist_csv_handle=INVALID_HANDLE;
   }
}


//+------------------------------------------------------------------+
//| v7.47 PerformanceAudit: one cumulative runtime sample per        |
//| completed unified trading-TF bar. Uses existing performance      |
//| counters only; no strategy or indicator calculation is added.    |
//+------------------------------------------------------------------+
void WritePerformanceAuditV100(const datetime bar_time,
                               const ENUM_TIMEFRAMES timeframe)
{
   if(g_integrated_csv_mode)
   {
      if(bar_time>0)
         DataExportWriteUnifiedEvent("PERFORMANCE","BAR_METRICS",0,0,0.0,0.0,0,
            "OBSERVE","PERFORMANCE_AUDIT","",
            (double)g_perf_last_tick_us,(double)g_perf_peak_tick_us,
            StringFormat("TICKS=%I64u NEW_BARS=%I64u SNAP_H=%I64u SNAP_M=%I64u CACHE_H=%I64u CACHE_M=%I64u STATE_US=%I64u/%I64u M3_US=%I64u/%I64u SIGNAL_US=%I64u/%I64u ASSISTCSV_US=%I64u/%I64u",
               g_perf_tick_calls,g_perf_new_bar_calls,g_perf_snapshot_hits,g_perf_snapshot_misses,
               g_perf_fast_cache_hits,g_perf_fast_cache_misses,
               g_perf_last_state_eval_us,g_perf_peak_state_eval_us,
               g_perf_last_m3_auto_us,g_perf_peak_m3_auto_us,
               g_perf_last_signal_us,g_perf_peak_signal_us,
               g_perf_last_assist_write_us,g_perf_peak_assist_write_us),bar_time);
      return;
   }

   if(!DataExportIsTester() || bar_time<=0)
      return;

   static datetime last_bar=0;
   static ENUM_TIMEFRAMES last_tf=PERIOD_CURRENT;
   if(last_bar==bar_time && last_tf==timeframe)
      return;
   last_bar=bar_time;
   last_tf=timeframe;

   const string filename=DataExportBaseFolder()+"\\"+
      StringFormat("TEST_%s_JTA_PerformanceAudit_v1_00_%s_%s.csv",
         DataExportRunId(),TradeLogSafeFileToken(_Symbol),EnumToString(timeframe));

   if(g_performance_audit_handle==INVALID_HANDLE ||
      g_performance_audit_file!=filename)
   {
      ClosePerformanceAudit();
      const int flags=FILE_READ|FILE_WRITE|FILE_TXT|FILE_ANSI|DataExportCommonFlag();
      g_performance_audit_handle=FileOpen(filename,flags);
      g_performance_audit_file=filename;
      g_performance_audit_rows_since_flush=0;
      if(g_performance_audit_handle==INVALID_HANDLE)
      {
         PrintFormat("[JTA CSV] PERFORMANCE AUDIT OPEN FAILED | %s | err=%d",
                     filename,GetLastError());
         return;
      }
   }

   if(FileSize(g_performance_audit_handle)==0)
   {
      string header="";
      DataExportCsvAdd(header,"time_server");
      DataExportCsvAdd(header,"timeframe");
      DataExportCsvAdd(header,"tick_calls");
      DataExportCsvAdd(header,"new_bar_calls");
      DataExportCsvAdd(header,"snapshot_hits");
      DataExportCsvAdd(header,"snapshot_misses");
      DataExportCsvAdd(header,"snapshot_hit_rate");
      DataExportCsvAdd(header,"fast_cache_hits");
      DataExportCsvAdd(header,"fast_cache_misses");
      DataExportCsvAdd(header,"fast_cache_hit_rate");
      DataExportCsvAdd(header,"ui_refreshes");
      DataExportCsvAdd(header,"last_tick_us");
      DataExportCsvAdd(header,"peak_tick_us");
      FileWriteString(g_performance_audit_handle,header+"\r\n");
   }

   const ulong snapshot_total=g_perf_snapshot_hits+g_perf_snapshot_misses;
   const ulong fast_total=g_perf_fast_cache_hits+g_perf_fast_cache_misses;
   const double snapshot_hit_rate=
      snapshot_total>0 ? (double)g_perf_snapshot_hits/(double)snapshot_total : 0.0;
   const double fast_hit_rate=
      fast_total>0 ? (double)g_perf_fast_cache_hits/(double)fast_total : 0.0;

   FileSeek(g_performance_audit_handle,0,SEEK_END);
   string row="";
   DataExportCsvAdd(row,TimeToString(bar_time,TIME_DATE|TIME_SECONDS));
   DataExportCsvAdd(row,EnumToString(timeframe));
   DataExportCsvAdd(row,(string)g_perf_tick_calls);
   DataExportCsvAdd(row,(string)g_perf_new_bar_calls);
   DataExportCsvAdd(row,(string)g_perf_snapshot_hits);
   DataExportCsvAdd(row,(string)g_perf_snapshot_misses);
   DataExportCsvAdd(row,DoubleToString(snapshot_hit_rate,6));
   DataExportCsvAdd(row,(string)g_perf_fast_cache_hits);
   DataExportCsvAdd(row,(string)g_perf_fast_cache_misses);
   DataExportCsvAdd(row,DoubleToString(fast_hit_rate,6));
   DataExportCsvAdd(row,(string)g_perf_ui_refreshes);
   DataExportCsvAdd(row,(string)g_perf_last_tick_us);
   DataExportCsvAdd(row,(string)g_perf_peak_tick_us);
   FileWriteString(g_performance_audit_handle,row+"\r\n");

   g_performance_audit_rows_since_flush++;
   if(g_performance_audit_rows_since_flush>=64)
   {
      FileFlush(g_performance_audit_handle);
      g_performance_audit_rows_since_flush=0;
   }
}

void ClosePerformanceAudit()
{
   if(g_performance_audit_handle!=INVALID_HANDLE)
   {
      FileFlush(g_performance_audit_handle);
      FileClose(g_performance_audit_handle);
      g_performance_audit_handle=INVALID_HANDLE;
   }
   g_performance_audit_file="";
   g_performance_audit_rows_since_flush=0;
}


//+------------------------------------------------------------------+
//| v7.58 SignalBarAudit: one deterministic row per completed TRADE |
//| TF bar. Uses values already calculated by SignalEngine.          |
//+------------------------------------------------------------------+
void WriteSignalBarAuditV111(const datetime bar_time,
                             const ENUM_TIMEFRAMES timeframe,
                             const double open_price,
                             const double high_price,
                             const double low_price,
                             const double close_price,
                             const double source_volume,
                             const double ma7,
                             const double ma22,
                             const double ma70,
                             const double ma111,
                             const double ma200,
                             const double macd_base_unscaled,
                             const int macd_direction,
                             const int macd_zero_state,
                             const double macd_change_1,
                             const double macd_change_3,
                             const double raw_delta,
                             const double ema_delta,
                             const double delta_change,
                             const double avg_range,
                             const double net_progress_r,
                             const double recent_progress_r,
                             const int higher_high_steps,
                             const int higher_low_steps,
                             const int lower_high_steps,
                             const int lower_low_steps,
                             const int up_close_steps,
                             const int down_close_steps,
                             const int long_score,
                             const int short_score,
                             const bool final_long,
                             const bool final_short,
                             const int long_signal_count,
                             const int short_signal_count,
                             const bool neutral_flow,
                             const bool compressed_chop,
                             const bool no_market_energy,
                             const double relative_range_ratio,
                             const double relative_macd_ratio,
                             const double relative_delta_ratio,
                             const int long_direction_quality,
                             const int short_direction_quality,
                             const bool direction_long_allowed,
                             const bool direction_short_allowed,
                             const string long_gate_reason,
                             const string short_gate_reason,
                             const string final_long_block_reason,
                             const string final_short_block_reason,
                             const double assist_macd_base,
                             const double assist_macd_wave,
                             const double assist_macd_raw_price,
                             const double assist_macd_wave_change_1,
                             const double assist_macd_wave_change_3,
                             const double assist_macd_base_change_1,
                             const double assist_macd_base_change_3,
                             const double assist_macd_base_travel_3,
                             const double assist_macd_base_efficiency_3,
                             const double assist_macd_wave_travel_3,
                             const double assist_macd_wave_efficiency_3,
                             const int assist_raw_up_steps,
                             const int assist_raw_down_steps,
                             const double assist_raw_delta,
                             const double assist_ema_delta,
                             const double assist_delta_change,
                             const int assist_delta_buy_steps,
                             const int assist_delta_sell_steps,
                             const bool assist_delta_long_participation,
                             const bool assist_delta_short_participation,
                             const bool assist_snapshot_aligned,
                             const double assist_macd_transition_progress,
                             const bool assist_macd_transition_up,
                             const bool assist_macd_transition_down,
                             const bool assist_long_transition_progress,
                             const bool assist_short_transition_progress,
                             const bool assist_watch_pulse,
                             const int assist_direction_anchor,
                             const string assist_previous_state,
                             const string assist_state,
                             const string assist_reason,
                             const int persistent_direction_before,
                             const int persistent_direction_after,
                             const string persistence_transition_reason,
                             const bool directional_regime_long,
                             const bool directional_regime_short,
                             const bool price_up,
                             const bool price_down,
                             const bool full_long_watch_candidate,
                             const bool full_short_watch_candidate,
                             const bool long_watch_authorized,
                             const bool short_watch_authorized,
                             const bool persistent_candidate_long,
                             const bool persistent_candidate_short,
                             const bool assist_persistent_continuation_long,
                             const bool assist_persistent_continuation_short,
                             const bool effective_flow_long,
                             const bool effective_flow_short,
                             const bool final_gate_long,
                             const bool final_gate_short,
                             const bool repeat_final_long_ok,
                             const bool repeat_final_short_ok,
                             const bool repeat_late_block_long,
                             const bool repeat_late_block_short,
                             const bool ma111_protection,
                             const bool strong_buy,
                             const bool strong_sell,
                             const int long_macd_score,
                             const int short_macd_score,
                             const int long_delta_score,
                             const int short_delta_score,
                             const int long_ma_score,
                             const int short_ma_score,
                             const int long_price_score,
                             const int short_price_score,
                             const int long_pattern_score,
                             const int short_pattern_score,
                             const int long_tf_score,
                             const int short_tf_score,
                             const int long_location_score,
                             const int short_location_score,
                             const int long_score_pre_context,
                             const int short_score_pre_context,
                             const int long_context_penalty,
                             const int short_context_penalty,
                             const bool long_score_threshold_pass,
                             const bool short_score_threshold_pass,
                             const bool long_score_gap_pass,
                             const bool short_score_gap_pass,
                             const bool macd_side_long,
                             const bool macd_side_short,
                             const bool signal_trigger_long,
                             const bool signal_trigger_short,
                             const bool repeat_long_is_repeat,
                             const bool repeat_short_is_repeat,
                             const bool repeat_long_momentum_ok,
                             const bool repeat_short_momentum_ok,
                             const bool repeat_long_price_ok,
                             const bool repeat_short_price_ok,
                             const bool repeat_long_episode_progress,
                             const bool repeat_short_episode_progress,
                             const double previous_long_final_close,
                             const double previous_short_final_close,
                             const string repeat_long_detail,
                             const string repeat_short_detail,
                             const datetime previous_long_final_bar,
                             const datetime previous_short_final_bar,
                             const string long_final_phase,
                             const string short_final_phase,
                             const string long_signal_event_id,
                             const string short_signal_event_id)
{
   if(bar_time<=0)
      return;

   // v8.220: one canonical chart-frame record per completed bar/timeframe.
   // The integrated CSV used to return before the legacy duplicate guard, so
   // repeated calls for the same completed M3 bar could create multiple BAR rows.
   // Apply the same immutable bar-time guard before either CSV path.
   static datetime last_bar=0;
   static ENUM_TIMEFRAMES last_tf=PERIOD_CURRENT;
   if(last_bar==bar_time && last_tf==timeframe)
      return;
   last_bar=bar_time;
   last_tf=timeframe;

   if(g_integrated_csv_mode)
   {
      const string canonical_stage=(timeframe==PERIOD_M3 ? "M3_CANONICAL" : "SIGNAL_BAR");
      DataExportWriteUnifiedEvent("BAR",canonical_stage,0,0,close_price,source_volume,
         MathMax(long_score,short_score),"OBSERVE","SIGNAL_BAR_AUDIT",
         long_signal_event_id,macd_base_unscaled,raw_delta,
         StringFormat("TF=%s O=%.8f H=%.8f L=%.8f FINAL_L=%s FINAL_S=%s LQ=%d SQ=%d DL=%s DS=%s",
            EnumToString(timeframe),open_price,high_price,low_price,
            final_long?"YES":"NO",final_short?"YES":"NO",
            long_direction_quality,short_direction_quality,
            direction_long_allowed?"YES":"NO",direction_short_allowed?"YES":"NO"),bar_time);
      return;
   }

   // v7.62: identical signal-decision dataset in Tester and Live.
   // Live keeps one buffered file handle open; no additional indicator/market
   // reads are performed here.
   if(!DataExportIsTester())
      DataExportEnsureFolder();
   const string filename=DataExportIsTester()
      ? DataExportBaseFolder()+"\\"+
        StringFormat("TEST_%s_JTA_SignalBarAudit_v1_11_Slim_%s_%s.csv",
           DataExportRunId(),TradeLogSafeFileToken(_Symbol),EnumToString(timeframe))
      : DataExportBaseFolder()+"\\"+
        StringFormat("JTA_SignalBarAudit_v1_11_Slim_%s_%s.csv",
           TradeLogSafeFileToken(_Symbol),EnumToString(timeframe));

   if(g_signal_bar_audit_handle==INVALID_HANDLE || g_signal_bar_audit_file!=filename)
   {
      CloseSignalBarAudit();
      const int flags=FILE_READ|FILE_WRITE|FILE_TXT|FILE_ANSI|
                      FILE_SHARE_READ|FILE_SHARE_WRITE|DataExportCommonFlag();
      g_signal_bar_audit_handle=FileOpen(filename,flags,0,CP_UTF8);
      g_signal_bar_audit_file=filename;
      g_signal_bar_audit_rows_since_flush=0;
      if(g_signal_bar_audit_handle==INVALID_HANDLE)
      {
         PrintFormat("[JTA CSV] SIGNAL BAR AUDIT OPEN FAILED | %s | err=%d",
                     filename,GetLastError());
         return;
      }
      FileSeek(g_signal_bar_audit_handle,0,SEEK_END);
   }

   if(FileSize(g_signal_bar_audit_handle)==0)
   {
      string header="";
      DataExportCsvAdd(header,"run_id");
      DataExportCsvAdd(header,"environment");
      DataExportCsvAdd(header,"symbol");
      DataExportCsvAdd(header,"magic");
      DataExportCsvAdd(header,"ea_version");
      DataExportCsvAdd(header,"timeframe");
      DataExportCsvAdd(header,"bar_key");
      DataExportCsvAdd(header,"time_server");
      DataExportCsvAdd(header,"long_signal_event_id");
      DataExportCsvAdd(header,"short_signal_event_id");
      DataExportCsvAdd(header,"cycle_id");
      DataExportCsvAdd(header,"cycle_state");
      DataExportCsvAdd(header,"cycle_side");
      DataExportCsvAdd(header,"cycle_position_id");
      DataExportCsvAdd(header,"cycle_third_signal_id");
      DataExportCsvAdd(header,"cycle_breakout_reference");
      DataExportCsvAdd(header,"direction_confirm_pending");
      DataExportCsvAdd(header,"direction_confirm_side");
      DataExportCsvAdd(header,"direction_confirm_bar");
      DataExportCsvAdd(header,"direction_confirm_high");
      DataExportCsvAdd(header,"direction_confirm_low");
      DataExportCsvAdd(header,"trigger_entry_active");
      DataExportCsvAdd(header,"trigger_entry_side");
      DataExportCsvAdd(header,"trigger_entry_fire_bar");
      DataExportCsvAdd(header,"trigger_entry_final_count");
      DataExportCsvAdd(header,"open");
      DataExportCsvAdd(header,"high");
      DataExportCsvAdd(header,"low");
      DataExportCsvAdd(header,"close");
      DataExportCsvAdd(header,"source_volume");
      DataExportCsvAdd(header,"ma7");
      DataExportCsvAdd(header,"ma22");
      DataExportCsvAdd(header,"ma70");
      DataExportCsvAdd(header,"ma111");
      DataExportCsvAdd(header,"ma200");
      DataExportCsvAdd(header,"macd_base_unscaled");
      DataExportCsvAdd(header,"macd_direction");
      DataExportCsvAdd(header,"macd_zero_state");
      DataExportCsvAdd(header,"macd_change_1");
      DataExportCsvAdd(header,"macd_change_3");
      DataExportCsvAdd(header,"raw_delta");
      DataExportCsvAdd(header,"ema_delta");
      DataExportCsvAdd(header,"delta_change");
      DataExportCsvAdd(header,"avg_range");
      DataExportCsvAdd(header,"net_progress_r");
      DataExportCsvAdd(header,"recent_progress_r");
      DataExportCsvAdd(header,"higher_high_steps");
      DataExportCsvAdd(header,"higher_low_steps");
      DataExportCsvAdd(header,"lower_high_steps");
      DataExportCsvAdd(header,"lower_low_steps");
      DataExportCsvAdd(header,"up_close_steps");
      DataExportCsvAdd(header,"down_close_steps");
      DataExportCsvAdd(header,"long_score");
      DataExportCsvAdd(header,"short_score");
      DataExportCsvAdd(header,"final_long");
      DataExportCsvAdd(header,"final_short");
      DataExportCsvAdd(header,"long_signal_count");
      DataExportCsvAdd(header,"short_signal_count");
      DataExportCsvAdd(header,"neutral_flow");
      DataExportCsvAdd(header,"compressed_chop");
      DataExportCsvAdd(header,"no_market_energy");
      DataExportCsvAdd(header,"relative_range_ratio");
      DataExportCsvAdd(header,"relative_macd_ratio");
      DataExportCsvAdd(header,"relative_delta_ratio");
      DataExportCsvAdd(header,"long_direction_quality");
      DataExportCsvAdd(header,"short_direction_quality");
      DataExportCsvAdd(header,"direction_long_allowed");
      DataExportCsvAdd(header,"direction_short_allowed");
      DataExportCsvAdd(header,"long_gate_reason");
      DataExportCsvAdd(header,"short_gate_reason");
      DataExportCsvAdd(header,"final_long_block_reason");
      DataExportCsvAdd(header,"final_short_block_reason");
      DataExportCsvAdd(header,"assist_macd_base");
      DataExportCsvAdd(header,"assist_macd_wave");
      DataExportCsvAdd(header,"assist_macd_raw_price");
      DataExportCsvAdd(header,"assist_macd_wave_change_1");
      DataExportCsvAdd(header,"assist_macd_wave_change_3");
      DataExportCsvAdd(header,"assist_macd_base_change_1");
      DataExportCsvAdd(header,"assist_macd_base_change_3");
      DataExportCsvAdd(header,"assist_macd_base_travel_3");
      DataExportCsvAdd(header,"assist_macd_base_efficiency_3");
      DataExportCsvAdd(header,"assist_macd_wave_travel_3");
      DataExportCsvAdd(header,"assist_macd_wave_efficiency_3");
      DataExportCsvAdd(header,"assist_raw_up_steps");
      DataExportCsvAdd(header,"assist_raw_down_steps");
      DataExportCsvAdd(header,"assist_raw_delta");
      DataExportCsvAdd(header,"assist_ema_delta");
      DataExportCsvAdd(header,"assist_delta_change");
      DataExportCsvAdd(header,"assist_delta_buy_steps");
      DataExportCsvAdd(header,"assist_delta_sell_steps");
      DataExportCsvAdd(header,"assist_delta_long_participation");
      DataExportCsvAdd(header,"assist_delta_short_participation");
      DataExportCsvAdd(header,"assist_snapshot_aligned");
      DataExportCsvAdd(header,"assist_macd_transition_progress");
      DataExportCsvAdd(header,"assist_macd_transition_up");
      DataExportCsvAdd(header,"assist_macd_transition_down");
      DataExportCsvAdd(header,"assist_long_transition_progress");
      DataExportCsvAdd(header,"assist_short_transition_progress");
      DataExportCsvAdd(header,"assist_watch_pulse");
      DataExportCsvAdd(header,"assist_direction_anchor");
      DataExportCsvAdd(header,"assist_previous_state");
      DataExportCsvAdd(header,"assist_state");
      DataExportCsvAdd(header,"assist_reason");
      DataExportCsvAdd(header,"persistent_direction_before");
      DataExportCsvAdd(header,"persistent_direction_after");
      DataExportCsvAdd(header,"persistence_transition_reason");
      DataExportCsvAdd(header,"directional_regime_long");
      DataExportCsvAdd(header,"directional_regime_short");
      DataExportCsvAdd(header,"price_up");
      DataExportCsvAdd(header,"price_down");
      DataExportCsvAdd(header,"full_long_watch_candidate");
      DataExportCsvAdd(header,"full_short_watch_candidate");
      DataExportCsvAdd(header,"long_watch_authorized");
      DataExportCsvAdd(header,"short_watch_authorized");
      DataExportCsvAdd(header,"persistent_candidate_long");
      DataExportCsvAdd(header,"persistent_candidate_short");
      DataExportCsvAdd(header,"assist_persistent_continuation_long");
      DataExportCsvAdd(header,"assist_persistent_continuation_short");
      DataExportCsvAdd(header,"effective_flow_long");
      DataExportCsvAdd(header,"effective_flow_short");
      DataExportCsvAdd(header,"final_gate_long");
      DataExportCsvAdd(header,"final_gate_short");
      DataExportCsvAdd(header,"repeat_final_long_ok");
      DataExportCsvAdd(header,"repeat_final_short_ok");
      DataExportCsvAdd(header,"repeat_late_block_long");
      DataExportCsvAdd(header,"repeat_late_block_short");
      DataExportCsvAdd(header,"ma111_protection");
      DataExportCsvAdd(header,"strong_buy");
      DataExportCsvAdd(header,"strong_sell");
      DataExportCsvAdd(header,"long_macd_score");
      DataExportCsvAdd(header,"short_macd_score");
      DataExportCsvAdd(header,"long_delta_score");
      DataExportCsvAdd(header,"short_delta_score");
      DataExportCsvAdd(header,"long_ma_score");
      DataExportCsvAdd(header,"short_ma_score");
      DataExportCsvAdd(header,"long_price_score");
      DataExportCsvAdd(header,"short_price_score");
      DataExportCsvAdd(header,"long_pattern_score");
      DataExportCsvAdd(header,"short_pattern_score");
      DataExportCsvAdd(header,"long_tf_score");
      DataExportCsvAdd(header,"short_tf_score");
      DataExportCsvAdd(header,"long_location_score");
      DataExportCsvAdd(header,"short_location_score");
      DataExportCsvAdd(header,"long_score_pre_context");
      DataExportCsvAdd(header,"short_score_pre_context");
      DataExportCsvAdd(header,"long_context_penalty");
      DataExportCsvAdd(header,"short_context_penalty");
      DataExportCsvAdd(header,"long_score_threshold_pass");
      DataExportCsvAdd(header,"short_score_threshold_pass");
      DataExportCsvAdd(header,"long_score_gap_pass");
      DataExportCsvAdd(header,"short_score_gap_pass");
      DataExportCsvAdd(header,"macd_side_long");
      DataExportCsvAdd(header,"macd_side_short");
      DataExportCsvAdd(header,"signal_trigger_long");
      DataExportCsvAdd(header,"signal_trigger_short");
      DataExportCsvAdd(header,"repeat_long_is_repeat");
      DataExportCsvAdd(header,"repeat_short_is_repeat");
      DataExportCsvAdd(header,"repeat_long_momentum_ok");
      DataExportCsvAdd(header,"repeat_short_momentum_ok");
      DataExportCsvAdd(header,"repeat_long_price_ok");
      DataExportCsvAdd(header,"repeat_short_price_ok");
      DataExportCsvAdd(header,"repeat_long_episode_progress");
      DataExportCsvAdd(header,"repeat_short_episode_progress");
      DataExportCsvAdd(header,"previous_long_final_close");
      DataExportCsvAdd(header,"previous_short_final_close");
      DataExportCsvAdd(header,"repeat_long_detail");
      DataExportCsvAdd(header,"repeat_short_detail");
      DataExportCsvAdd(header,"previous_long_final_bar");
      DataExportCsvAdd(header,"previous_short_final_bar");
      DataExportCsvAdd(header,"long_final_phase");
      DataExportCsvAdd(header,"short_final_phase");
      FileWriteString(g_signal_bar_audit_handle,header+"\r\n");
   }

   FileSeek(g_signal_bar_audit_handle,0,SEEK_END);


   string row="";
   const string bar_key=StringFormat("%s|%s|%I64d",
      _Symbol,EnumToString(timeframe),(long)bar_time);
   DataExportCsvAdd(row,DataExportRunId());
   DataExportCsvAdd(row,DataExportEnvironment());
   DataExportCsvAdd(row,_Symbol);
   DataExportCsvAdd(row,(string)InpMagicNumber);
   DataExportCsvAdd(row,DataExportEaVersion());
   DataExportCsvAdd(row,EnumToString(timeframe));
   DataExportCsvAdd(row,bar_key);
   DataExportCsvAdd(row,TimeToString(bar_time,TIME_DATE|TIME_SECONDS));
   DataExportCsvAdd(row,long_signal_event_id);
   DataExportCsvAdd(row,short_signal_event_id);
   DataExportCsvAdd(row,(string)g_trade_cycle.cycle_id);
   DataExportCsvAdd(row,TradeCycleStateName(g_trade_cycle.state));
   DataExportCsvAdd(row,(string)g_trade_cycle.side);
   DataExportCsvAdd(row,(string)g_trade_cycle.position_id);
   DataExportCsvAdd(row,g_trade_cycle.third_signal_id);
   DataExportCsvAdd(row,DoubleToString(g_trade_cycle.breakout_reference,_Digits));
   DataExportCsvAdd(row,g_range_direction_confirm_pending ? "1" : "0");
   DataExportCsvAdd(row,(string)g_range_direction_confirm_side);
   DataExportCsvAdd(row,g_range_direction_confirm_signal_bar>0 ?
      TimeToString(g_range_direction_confirm_signal_bar,TIME_DATE|TIME_SECONDS) : "");
   DataExportCsvAdd(row,DoubleToString(g_range_direction_confirm_high,_Digits));
   DataExportCsvAdd(row,DoubleToString(g_range_direction_confirm_low,_Digits));
   DataExportCsvAdd(row,g_range_trigger_entry_active ? "1" : "0");
   DataExportCsvAdd(row,(string)g_range_trigger_entry_side);
   DataExportCsvAdd(row,g_range_trigger_entry_fire_bar>0 ?
      TimeToString(g_range_trigger_entry_fire_bar,TIME_DATE|TIME_SECONDS) : "");
   DataExportCsvAdd(row,(string)g_range_trigger_entry_final_count);
   DataExportCsvAdd(row,DoubleToString(open_price,_Digits));
   DataExportCsvAdd(row,DoubleToString(high_price,_Digits));
   DataExportCsvAdd(row,DoubleToString(low_price,_Digits));
   DataExportCsvAdd(row,DoubleToString(close_price,_Digits));
   DataExportCsvAdd(row,DoubleToString(source_volume,1));
   DataExportCsvAdd(row,DoubleToString(ma7,_Digits));
   DataExportCsvAdd(row,DoubleToString(ma22,_Digits));
   DataExportCsvAdd(row,DoubleToString(ma70,_Digits));
   DataExportCsvAdd(row,DoubleToString(ma111,_Digits));
   DataExportCsvAdd(row,DoubleToString(ma200,_Digits));
   DataExportCsvAdd(row,DoubleToString(macd_base_unscaled,7));
   DataExportCsvAdd(row,(string)macd_direction);
   DataExportCsvAdd(row,(string)macd_zero_state);
   DataExportCsvAdd(row,DoubleToString(macd_change_1,7));
   DataExportCsvAdd(row,DoubleToString(macd_change_3,7));
   DataExportCsvAdd(row,DoubleToString(raw_delta,7));
   DataExportCsvAdd(row,DoubleToString(ema_delta,7));
   DataExportCsvAdd(row,DoubleToString(delta_change,7));
   DataExportCsvAdd(row,DoubleToString(avg_range,6));
   DataExportCsvAdd(row,DoubleToString(net_progress_r,4));
   DataExportCsvAdd(row,DoubleToString(recent_progress_r,4));
   DataExportCsvAdd(row,(string)higher_high_steps);
   DataExportCsvAdd(row,(string)higher_low_steps);
   DataExportCsvAdd(row,(string)lower_high_steps);
   DataExportCsvAdd(row,(string)lower_low_steps);
   DataExportCsvAdd(row,(string)up_close_steps);
   DataExportCsvAdd(row,(string)down_close_steps);
   DataExportCsvAdd(row,(string)long_score);
   DataExportCsvAdd(row,(string)short_score);
   DataExportCsvAdd(row,final_long ? "1" : "0");
   DataExportCsvAdd(row,final_short ? "1" : "0");
   DataExportCsvAdd(row,(string)long_signal_count);
   DataExportCsvAdd(row,(string)short_signal_count);
   DataExportCsvAdd(row,neutral_flow ? "1" : "0");
   DataExportCsvAdd(row,compressed_chop ? "1" : "0");
   DataExportCsvAdd(row,no_market_energy ? "1" : "0");
   DataExportCsvAdd(row,DoubleToString(relative_range_ratio,4));
   DataExportCsvAdd(row,DoubleToString(relative_macd_ratio,4));
   DataExportCsvAdd(row,DoubleToString(relative_delta_ratio,4));
   DataExportCsvAdd(row,(string)long_direction_quality);
   DataExportCsvAdd(row,(string)short_direction_quality);
   DataExportCsvAdd(row,direction_long_allowed ? "1" : "0");
   DataExportCsvAdd(row,direction_short_allowed ? "1" : "0");
   DataExportCsvAdd(row,long_gate_reason);
   DataExportCsvAdd(row,short_gate_reason);
   DataExportCsvAdd(row,final_long_block_reason);
   DataExportCsvAdd(row,final_short_block_reason);
   DataExportCsvAdd(row,DoubleToString(assist_macd_base,7));
   DataExportCsvAdd(row,DoubleToString(assist_macd_wave,7));
   DataExportCsvAdd(row,DoubleToString(assist_macd_raw_price,7));
   DataExportCsvAdd(row,DoubleToString(assist_macd_wave_change_1,7));
   DataExportCsvAdd(row,DoubleToString(assist_macd_wave_change_3,7));
   DataExportCsvAdd(row,DoubleToString(assist_macd_base_change_1,7));
   DataExportCsvAdd(row,DoubleToString(assist_macd_base_change_3,7));
   DataExportCsvAdd(row,DoubleToString(assist_macd_base_travel_3,7));
   DataExportCsvAdd(row,DoubleToString(assist_macd_base_efficiency_3,7));
   DataExportCsvAdd(row,DoubleToString(assist_macd_wave_travel_3,7));
   DataExportCsvAdd(row,DoubleToString(assist_macd_wave_efficiency_3,7));
   DataExportCsvAdd(row,(string)assist_raw_up_steps);
   DataExportCsvAdd(row,(string)assist_raw_down_steps);
   DataExportCsvAdd(row,DoubleToString(assist_raw_delta,7));
   DataExportCsvAdd(row,DoubleToString(assist_ema_delta,7));
   DataExportCsvAdd(row,DoubleToString(assist_delta_change,7));
   DataExportCsvAdd(row,(string)assist_delta_buy_steps);
   DataExportCsvAdd(row,(string)assist_delta_sell_steps);
   DataExportCsvAdd(row,assist_delta_long_participation ? "1" : "0");
   DataExportCsvAdd(row,assist_delta_short_participation ? "1" : "0");
   DataExportCsvAdd(row,assist_snapshot_aligned ? "1" : "0");
   DataExportCsvAdd(row,DoubleToString(assist_macd_transition_progress,7));
   DataExportCsvAdd(row,assist_macd_transition_up ? "1" : "0");
   DataExportCsvAdd(row,assist_macd_transition_down ? "1" : "0");
   DataExportCsvAdd(row,assist_long_transition_progress ? "1" : "0");
   DataExportCsvAdd(row,assist_short_transition_progress ? "1" : "0");
   DataExportCsvAdd(row,assist_watch_pulse ? "1" : "0");
   DataExportCsvAdd(row,(string)assist_direction_anchor);
   DataExportCsvAdd(row,assist_previous_state);
   DataExportCsvAdd(row,assist_state);
   DataExportCsvAdd(row,assist_reason);
   DataExportCsvAdd(row,(string)persistent_direction_before);
   DataExportCsvAdd(row,(string)persistent_direction_after);
   DataExportCsvAdd(row,persistence_transition_reason);
   DataExportCsvAdd(row,directional_regime_long ? "1" : "0");
   DataExportCsvAdd(row,directional_regime_short ? "1" : "0");
   DataExportCsvAdd(row,price_up ? "1" : "0");
   DataExportCsvAdd(row,price_down ? "1" : "0");
   DataExportCsvAdd(row,full_long_watch_candidate ? "1" : "0");
   DataExportCsvAdd(row,full_short_watch_candidate ? "1" : "0");
   DataExportCsvAdd(row,long_watch_authorized ? "1" : "0");
   DataExportCsvAdd(row,short_watch_authorized ? "1" : "0");
   DataExportCsvAdd(row,persistent_candidate_long ? "1" : "0");
   DataExportCsvAdd(row,persistent_candidate_short ? "1" : "0");
   DataExportCsvAdd(row,assist_persistent_continuation_long ? "1" : "0");
   DataExportCsvAdd(row,assist_persistent_continuation_short ? "1" : "0");
   DataExportCsvAdd(row,effective_flow_long ? "1" : "0");
   DataExportCsvAdd(row,effective_flow_short ? "1" : "0");
   DataExportCsvAdd(row,final_gate_long ? "1" : "0");
   DataExportCsvAdd(row,final_gate_short ? "1" : "0");
   DataExportCsvAdd(row,repeat_final_long_ok ? "1" : "0");
   DataExportCsvAdd(row,repeat_final_short_ok ? "1" : "0");
   DataExportCsvAdd(row,repeat_late_block_long ? "1" : "0");
   DataExportCsvAdd(row,repeat_late_block_short ? "1" : "0");
   DataExportCsvAdd(row,ma111_protection ? "1" : "0");
   DataExportCsvAdd(row,strong_buy ? "1" : "0");
   DataExportCsvAdd(row,strong_sell ? "1" : "0");
   DataExportCsvAdd(row,(string)long_macd_score);
   DataExportCsvAdd(row,(string)short_macd_score);
   DataExportCsvAdd(row,(string)long_delta_score);
   DataExportCsvAdd(row,(string)short_delta_score);
   DataExportCsvAdd(row,(string)long_ma_score);
   DataExportCsvAdd(row,(string)short_ma_score);
   DataExportCsvAdd(row,(string)long_price_score);
   DataExportCsvAdd(row,(string)short_price_score);
   DataExportCsvAdd(row,(string)long_pattern_score);
   DataExportCsvAdd(row,(string)short_pattern_score);
   DataExportCsvAdd(row,(string)long_tf_score);
   DataExportCsvAdd(row,(string)short_tf_score);
   DataExportCsvAdd(row,(string)long_location_score);
   DataExportCsvAdd(row,(string)short_location_score);
   DataExportCsvAdd(row,(string)long_score_pre_context);
   DataExportCsvAdd(row,(string)short_score_pre_context);
   DataExportCsvAdd(row,(string)long_context_penalty);
   DataExportCsvAdd(row,(string)short_context_penalty);
   DataExportCsvAdd(row,long_score_threshold_pass ? "1" : "0");
   DataExportCsvAdd(row,short_score_threshold_pass ? "1" : "0");
   DataExportCsvAdd(row,long_score_gap_pass ? "1" : "0");
   DataExportCsvAdd(row,short_score_gap_pass ? "1" : "0");
   DataExportCsvAdd(row,macd_side_long ? "1" : "0");
   DataExportCsvAdd(row,macd_side_short ? "1" : "0");
   DataExportCsvAdd(row,signal_trigger_long ? "1" : "0");
   DataExportCsvAdd(row,signal_trigger_short ? "1" : "0");
   DataExportCsvAdd(row,repeat_long_is_repeat ? "1" : "0");
   DataExportCsvAdd(row,repeat_short_is_repeat ? "1" : "0");
   DataExportCsvAdd(row,repeat_long_momentum_ok ? "1" : "0");
   DataExportCsvAdd(row,repeat_short_momentum_ok ? "1" : "0");
   DataExportCsvAdd(row,repeat_long_price_ok ? "1" : "0");
   DataExportCsvAdd(row,repeat_short_price_ok ? "1" : "0");
   DataExportCsvAdd(row,repeat_long_episode_progress ? "1" : "0");
   DataExportCsvAdd(row,repeat_short_episode_progress ? "1" : "0");
   DataExportCsvAdd(row,DoubleToString(previous_long_final_close,_Digits));
   DataExportCsvAdd(row,DoubleToString(previous_short_final_close,_Digits));
   DataExportCsvAdd(row,repeat_long_detail);
   DataExportCsvAdd(row,repeat_short_detail);
   DataExportCsvAdd(row,previous_long_final_bar>0 ? TimeToString(previous_long_final_bar,TIME_DATE|TIME_SECONDS) : "");
   DataExportCsvAdd(row,previous_short_final_bar>0 ? TimeToString(previous_short_final_bar,TIME_DATE|TIME_SECONDS) : "");
   DataExportCsvAdd(row,long_final_phase);
   DataExportCsvAdd(row,short_final_phase);
   FileWriteString(g_signal_bar_audit_handle,row+"\r\n");
   g_signal_bar_audit_rows_since_flush++;
   const int flush_rows=DataExportIsTester() ? 128 : 16;
   const bool critical_signal_row=
      assist_watch_pulse ||
      long_final_phase=="FIRST" ||
      short_final_phase=="FIRST";
   if(critical_signal_row || g_signal_bar_audit_rows_since_flush>=flush_rows)
   {
      FileFlush(g_signal_bar_audit_handle);
      g_signal_bar_audit_rows_since_flush=0;
   }
}

void CloseSignalBarAudit()
{
   if(g_signal_bar_audit_handle!=INVALID_HANDLE)
   {
      FileFlush(g_signal_bar_audit_handle);
      FileClose(g_signal_bar_audit_handle);
      g_signal_bar_audit_handle=INVALID_HANDLE;
   }
   g_signal_bar_audit_file="";
   g_signal_bar_audit_rows_since_flush=0;

   // v8.30: the pre-reversal lifecycle audit shares the signal-audit
   // lifecycle and is diagnostic-only. Close it with the existing owner.
   if(g_pre_reversal_audit_handle!=INVALID_HANDLE)
   {
      FileFlush(g_pre_reversal_audit_handle);
      FileClose(g_pre_reversal_audit_handle);
      g_pre_reversal_audit_handle=INVALID_HANDLE;
   }
   g_pre_reversal_audit_file="";
   g_pre_reversal_audit_rows_since_flush=0;
}



//+------------------------------------------------------------------+
//| v7.23 Visual chart capture index                                 |
//+------------------------------------------------------------------+





#endif // __JOON_DATAEXPORTENGINE_MQH__
