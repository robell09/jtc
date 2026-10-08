#ifndef JOON_TRADE_EXECUTION_ENGINE_MQH
#define JOON_TRADE_EXECUTION_ENGINE_MQH

// Single gateway for all CTrade order operations.
// Strategy, risk and position modules submit requests here and do not call trade.* directly.

bool TradeExecuteBuy(const double volume,
                     const string symbol,
                     const double price,
                     const double sl,
                     const double tp,
                     const string comment)
{
   ResetLastError();
   const bool ok = trade.Buy(volume, symbol, price, sl, tp, comment);
   if(!ok)
      PrintFormat("TRADE EXECUTION ERROR: BUY volume=%.4f symbol=%s retcode=%u %s error=%d",
                  volume, symbol, trade.ResultRetcode(), trade.ResultRetcodeDescription(), GetLastError());
   return ok;
}

bool TradeExecuteSell(const double volume,
                      const string symbol,
                      const double price,
                      const double sl,
                      const double tp,
                      const string comment)
{
   ResetLastError();
   const bool ok = trade.Sell(volume, symbol, price, sl, tp, comment);
   if(!ok)
      PrintFormat("TRADE EXECUTION ERROR: SELL volume=%.4f symbol=%s retcode=%u %s error=%d",
                  volume, symbol, trade.ResultRetcode(), trade.ResultRetcodeDescription(), GetLastError());
   return ok;
}

bool TradeExecutePositionClose(const ulong ticket)
{
   ResetLastError();
   const bool ok = trade.PositionClose(ticket);
   if(!ok)
      PrintFormat("TRADE EXECUTION ERROR: CLOSE ticket=%I64u retcode=%u %s error=%d",
                  ticket, trade.ResultRetcode(), trade.ResultRetcodeDescription(), GetLastError());
   return ok;
}

bool TradeExecutePositionClosePartial(const ulong ticket, const double volume)
{
   ResetLastError();
   const bool ok = trade.PositionClosePartial(ticket, volume);
   if(!ok)
      PrintFormat("TRADE EXECUTION ERROR: PARTIAL CLOSE ticket=%I64u volume=%.4f retcode=%u %s error=%d",
                  ticket, volume, trade.ResultRetcode(), trade.ResultRetcodeDescription(), GetLastError());
   return ok;
}

bool TradeExecutePositionModify(const ulong ticket, const double sl, const double tp)
{
   double effective_sl=sl;
   if(ManualBrokerSLIsOwned(ticket) && PositionSelectByTicket(ticket))
   {
      const double current_sl=PositionGetDouble(POSITION_SL);
      const double requested_sl=NormalizePrice(sl);
      const double normalized_current_sl=NormalizePrice(current_sl);
      const double tolerance=MathMax(SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE),_Point)*1.1;
      const ENUM_POSITION_TYPE type=(ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const bool same_sl=MathAbs(requested_sl-normalized_current_sl)<=tolerance;
      bool improves=false;
      if(requested_sl>0.0)
      {
         if(current_sl<=0.0) improves=true;
         else if(type==POSITION_TYPE_BUY) improves=requested_sl>normalized_current_sl+tolerance;
         else if(type==POSITION_TYPE_SELL) improves=requested_sl<normalized_current_sl-tolerance;
      }
      if(!same_sl && !improves) effective_sl=current_sl;
   }

   ManualBrokerSLRecordEAModify(ticket,effective_sl);
   ResetLastError();
   const bool ok=trade.PositionModify(ticket,effective_sl,tp);
   if(!ok)
      PrintFormat("TRADE EXECUTION ERROR: MODIFY ticket=%I64u sl=%.10f tp=%.10f retcode=%u %s error=%d",
                  ticket,effective_sl,tp,trade.ResultRetcode(),trade.ResultRetcodeDescription(),GetLastError());
   return ok;
}

#endif // JOON_TRADE_EXECUTION_ENGINE_MQH
