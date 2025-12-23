//+------------------------------------------------------------------+
//|                                                       Orders.mqh |
//|                                       Step-by-Step Learning EA   |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Maxx"
#property strict

#include <Trade/Trade.mqh>
#include "Log.mqh"
#include "Params.mqh"

//+------------------------------------------------------------------+
//| Order Management Namespace                                       |
//+------------------------------------------------------------------+
namespace Orders
{
   //--- Trade object for order execution
   CTrade trade;
   
   //--- Caching for market status (per bar)
   static datetime lastMarketCheckTime = 0;
   static bool cachedMarketOpen = false;
   static string cachedSymbol = "";
   
   //+------------------------------------------------------------------+
   //| Initialize trade object with settings                           |
   //+------------------------------------------------------------------+
   void Init()
   {
      trade.SetExpertMagicNumber(InpMagicNumber);
      trade.SetDeviationInPoints(InpSlippagePoints);
      trade.SetTypeFilling(ORDER_FILLING_IOC);
      Log::Info(StringFormat("Orders initialized. Magic: %d, Slippage: %d pts", 
                InpMagicNumber, InpSlippagePoints));
   }
   
   //+------------------------------------------------------------------+
   //| Check if spread is acceptable                                   |
   //+------------------------------------------------------------------+
   bool IsSpreadOK(const string symbol)
   {
      long spreadPoints = SymbolInfoInteger(symbol, SYMBOL_SPREAD);
      
      if(spreadPoints > InpMaxSpreadPoints)
      {
         Log::Warn(StringFormat("Spread too high: %d points (max: %d)", 
                   spreadPoints, InpMaxSpreadPoints));
         return false;
      }
      return true;
   }
   
   //+------------------------------------------------------------------+
   //| Check if market is open for trading (cached per bar)            |
   //+------------------------------------------------------------------+
   bool IsMarketOpen(const string symbol)
   {
      datetime currentBarTime = iTime(Symbol(), PERIOD_CURRENT, 0);
      
      //--- Return cached result if same bar and same symbol
      if(currentBarTime == lastMarketCheckTime && symbol == cachedSymbol)
         return cachedMarketOpen;
      
      //--- Update cache
      lastMarketCheckTime = currentBarTime;
      cachedSymbol = symbol;
      
      ENUM_SYMBOL_TRADE_MODE mode = (ENUM_SYMBOL_TRADE_MODE)SymbolInfoInteger(symbol, SYMBOL_TRADE_MODE);
      
      if(mode == SYMBOL_TRADE_MODE_DISABLED)
      {
         cachedMarketOpen = false;
         return false;
      }
      
      //--- Check if current time is within trading sessions
      datetime dt = TimeTradeServer();
      datetime from, to;
      MqlDateTime mqlDt;
      TimeToStruct(dt, mqlDt);
      
      //--- Check all sessions for today
      bool sessionFound = false;
      for(int i = 0; i < 10; i++) // Usually not more than 2-3 sessions
      {
         if(SymbolInfoSessionTrade(symbol, (ENUM_DAY_OF_WEEK)mqlDt.day_of_week, i, from, to))
         {
            //--- Session times are relative to 00:00 of the day
            datetime sessionStart = dt - (mqlDt.hour * 3600 + mqlDt.min * 60 + mqlDt.sec) + from;
            datetime sessionEnd = dt - (mqlDt.hour * 3600 + mqlDt.min * 60 + mqlDt.sec) + to;
            
            if(dt >= sessionStart && dt < sessionEnd)
            {
               sessionFound = true;
               break;
            }
         }
         else break;
      }
      
      cachedMarketOpen = sessionFound;
      return cachedMarketOpen;
   }
   
   //+------------------------------------------------------------------+
   //| Count open positions for this EA                                |
   //+------------------------------------------------------------------+
   int CountPositions(const string symbol)
   {
      int count = 0;
      for(int i = PositionsTotal() - 1; i >= 0; i--)
      {
         if(PositionSelectByTicket(PositionGetTicket(i)))
         {
            if(PositionGetInteger(POSITION_MAGIC) == InpMagicNumber &&
               PositionGetString(POSITION_SYMBOL) == symbol)
            {
               count++;
            }
         }
      }
      return count;
   }
   

   
   //+------------------------------------------------------------------+
   //| Calculate lot size based on risk                                |
   //+------------------------------------------------------------------+
   double CalculateLotSize(const string symbol, double slPoints)
   {
      double lotSize = InpLotSize;
      
      //--- If lot size is 0, use risk-based calculation
      if(InpLotSize == 0 && InpRiskPercent > 0 && slPoints > 0)
      {
         double equity = AccountInfoDouble(ACCOUNT_EQUITY);
         double riskAmount = equity * InpRiskPercent / 100.0;
         
         double tickValue = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
         double tickSize = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
         
         if(tickValue > 0 && tickSize > 0)
         {
            double pointValue = tickValue / tickSize;
            lotSize = riskAmount / (slPoints * pointValue);
         }
      }
      
      //--- Normalize to lot step
      double lotStep = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
      double minLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
      double maxLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
      
      lotSize = MathFloor(lotSize / lotStep) * lotStep;
      lotSize = MathMax(minLot, MathMin(maxLot, lotSize));
      lotSize = MathMin(lotSize, InpMaxLotSize);
      
      return NormalizeDouble(lotSize, 2);
   }
   
   //+------------------------------------------------------------------+
   //| Open a market position (unified for BUY/SELL)                  |
   //+------------------------------------------------------------------+
   bool OpenMarketPosition(const string symbol, double lots, double slPrice, ENUM_ORDER_TYPE orderType)
   {
      if(!IsMarketOpen(symbol))
         return false;
      
      double price = (orderType == ORDER_TYPE_BUY) ? 
                     SymbolInfoDouble(symbol, SYMBOL_ASK) : 
                     SymbolInfoDouble(symbol, SYMBOL_BID);
                     
      string direction = (orderType == ORDER_TYPE_BUY) ? "BUY" : "SELL";
      
      //--- Normalize prices
      int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
      slPrice = NormalizeDouble(slPrice, digits);
      price = NormalizeDouble(price, digits);
      
      //--- Do not set TP on entry; exit via strategy signals
      bool result = (orderType == ORDER_TYPE_BUY) ? 
                    trade.Buy(lots, symbol, price, slPrice, 0.0, "") : 
                    trade.Sell(lots, symbol, price, slPrice, 0.0, "");
      
      if(!result)
      {
         Log::Error(StringFormat("%s failed: %d - %s", 
                    direction, trade.ResultRetcode(), trade.ResultRetcodeDescription()));
      }
      
      return result;
   }
   
   //+------------------------------------------------------------------+
   //| Open a Buy position at market                                   |
   //+------------------------------------------------------------------+
   bool BuyMarket(const string symbol, double lots, double slPrice)
   {
      return OpenMarketPosition(symbol, lots, slPrice, ORDER_TYPE_BUY);
   }
   
   //+------------------------------------------------------------------+
   //| Open a Sell position at market                                  |
   //+------------------------------------------------------------------+
   bool SellMarket(const string symbol, double lots, double slPrice)
   {
      return OpenMarketPosition(symbol, lots, slPrice, ORDER_TYPE_SELL);
   }
   
   //+------------------------------------------------------------------+
   //| Close a specific position by ticket                             |
   //+------------------------------------------------------------------+
   bool ClosePosition(ulong ticket)
   {
      if(!PositionSelectByTicket(ticket))
         return false;
         
      string symbol = PositionGetString(POSITION_SYMBOL);
      if(!IsMarketOpen(symbol))
         return false;
         
      bool result = trade.PositionClose(ticket);
      
      if(!result)
      {
         Log::Error(StringFormat("Close failed: %d - %s", 
                    trade.ResultRetcode(), trade.ResultRetcodeDescription()));
      }
      
      return result;
   }
   
   //+------------------------------------------------------------------+
   //| Close all positions for this EA on symbol                       |
   //+------------------------------------------------------------------+
   bool CloseAllPositions(const string symbol)
   {
      bool allClosed = true;
      
      for(int i = PositionsTotal() - 1; i >= 0; i--)
      {
         ulong ticket = PositionGetTicket(i);
         if(PositionSelectByTicket(ticket))
         {
            if(PositionGetInteger(POSITION_MAGIC) == InpMagicNumber &&
               PositionGetString(POSITION_SYMBOL) == symbol)
            {
               if(!ClosePosition(ticket))
                  allClosed = false;
            }
         }
      }
      
      return allClosed;
   }
   
   //+------------------------------------------------------------------+
   //| Modify position SL/TP                                           |
   //+------------------------------------------------------------------+
   bool ModifyPosition(ulong ticket, double newSL, double newTP)
   {
      if(!PositionSelectByTicket(ticket))
         return false;
      
      string symbol = PositionGetString(POSITION_SYMBOL);
      if(!IsMarketOpen(symbol))
         return false;
         
      int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
      
      newSL = NormalizeDouble(newSL, digits);
      newTP = NormalizeDouble(newTP, digits);
      
      bool result = trade.PositionModify(ticket, newSL, newTP);
      
      if(!result)
      {
         Log::Error(StringFormat("Modify failed: %d - %s", 
                    trade.ResultRetcode(), trade.ResultRetcodeDescription()));
      }
      
      return result;
   }
   
  
   
   //+------------------------------------------------------------------+
   //| Get position ticket for this EA on symbol                       |
   //+------------------------------------------------------------------+
   ulong GetPositionTicket(const string symbol)
   {
      for(int i = PositionsTotal() - 1; i >= 0; i--)
      {
         ulong ticket = PositionGetTicket(i);
         if(PositionSelectByTicket(ticket))
         {
            if(PositionGetInteger(POSITION_MAGIC) == InpMagicNumber &&
               PositionGetString(POSITION_SYMBOL) == symbol)
            {
               return ticket;
            }
         }
      }
      return 0;
   }

   //+------------------------------------------------------------------+
   //| Get position ticket for this EA on symbol and direction         |
   //+------------------------------------------------------------------+
   ulong GetPositionTicket(const string symbol, ENUM_POSITION_TYPE positionType)
   {
      for(int i = PositionsTotal() - 1; i >= 0; i--)
      {
         ulong ticket = PositionGetTicket(i);
         if(PositionSelectByTicket(ticket))
         {
            if(PositionGetInteger(POSITION_MAGIC) == InpMagicNumber &&
               PositionGetString(POSITION_SYMBOL) == symbol &&
               (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) == positionType)
            {
               return ticket;
            }
         }
      }
      return 0;
   }
   
   //+------------------------------------------------------------------+
   //| Check if we have an open position                               |
   //+------------------------------------------------------------------+
   bool HasPosition(const string symbol)
   {
      return (GetPositionTicket(symbol) > 0);
   }

   //+------------------------------------------------------------------+
   //| Check if we have an open position in a given direction          |
   //+------------------------------------------------------------------+
   bool HasPosition(const string symbol, ENUM_POSITION_TYPE positionType)
   {
      return (GetPositionTicket(symbol, positionType) > 0);
   }
}
//+------------------------------------------------------------------+
