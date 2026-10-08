#ifndef JOON_MARKET_DATA_ENGINE_MQH
#define JOON_MARKET_DATA_ENGINE_MQH

// Centralized market-data gateway.
// No strategy engine should call CopyBuffer/CopyRates directly.

bool MarketDataReady(const int handle, const int required_bars);

int MarketDataCopyBuffer(const int handle,
                          const int buffer_index,
                          const int start_pos,
                          const int count,
                          double &target[])
{
   if(handle == INVALID_HANDLE || count <= 0)
      return -1;

   // Runtime performance/stability: a valid iCustom handle may exist before
   // its requested history is calculated after init/timeframe synchronization.
   // Wait for readiness instead of repeatedly hammering CopyBuffer().
   const int required_bars=MathMax(1,start_pos+count);
   if(!MarketDataReady(handle,required_bars))
      return 0;

   ResetLastError();
   const int copied = CopyBuffer(handle, buffer_index, start_pos, count, target);
   if(copied < count)
   {
      PrintFormat("MARKET DATA ERROR: CopyBuffer handle=%d buffer=%d start=%d requested=%d copied=%d error=%d",
                  handle, buffer_index, start_pos, count, copied, GetLastError());
      return copied;
   }
   return copied;
}

int MarketDataCopyRates(const string symbol,
                         const ENUM_TIMEFRAMES timeframe,
                         const int start_pos,
                         const int count,
                         MqlRates &target[])
{
   if(count <= 0)
      return -1;

   // Runtime history readiness gate.  Timeframe changes / fresh tester
   // synchronization can leave a series temporarily unsynchronized.
   // Return WAIT(0) and retry on the next processing cycle instead of
   // forcing CopyRates() while history is still being prepared.
   long synchronized=0;
   if(!SeriesInfoInteger(symbol,timeframe,SERIES_SYNCHRONIZED,synchronized) ||
      synchronized==0)
      return 0;

   const int required_bars=MathMax(1,start_pos+count);
   const int available_bars=Bars(symbol,timeframe);
   if(available_bars<required_bars)
      return 0;

   ResetLastError();
   const int copied = CopyRates(symbol, timeframe, start_pos, count, target);
   if(copied < count)
   {
      PrintFormat("MARKET DATA ERROR: CopyRates symbol=%s tf=%s start=%d requested=%d copied=%d error=%d",
                  symbol, EnumToString(timeframe), start_pos, count, copied, GetLastError());
      return copied;
   }
   return copied;
}

bool MarketDataReady(const int handle, const int required_bars)
{
   if(handle == INVALID_HANDLE || required_bars <= 0)
      return false;
   return (BarsCalculated(handle) >= required_bars);
}

#endif // JOON_MARKET_DATA_ENGINE_MQH
