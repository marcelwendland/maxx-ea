//+------------------------------------------------------------------+
//|                                                     Strategy.mqh |
//|                                       Step-by-Step Learning EA   |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Maxx"

#include "Log.mqh"
#include "Params.mqh"
#include "Draw.mqh"
#include "Orders.mqh"
#include "TrendDetector.mqh"
#include "ZigZag.mqh"

//+------------------------------------------------------------------+
//| Swing callback (global scope to work with function pointers)     |
//+------------------------------------------------------------------+
void OnNewSwingConfirmed(bool isHigh, double swingPrice, int barIndex, datetime swingTime);

//+------------------------------------------------------------------+
//| Strategy Namespace - Moving Average Crossover Strategy           |
//+------------------------------------------------------------------+
//| 3-MA Setup:                                                      |
//| - Fast MA (10): Entry signal (crossover)                         |
//| - Mid MA (20):  Entry signal (crossover)                         |
//| - Slow MA (50): Trend filtering (TrendDetector)                  |
//| - BUY Signal: Fast MA crosses above Mid MA                       |
//| - SELL Signal: Fast MA crosses below Mid MA                      |
//+------------------------------------------------------------------+
namespace Strategy
{
   //--- Constants
   const int MA_BUFFER_SIZE = 3;
   const int SIGNAL_BAR_INDEX = 1;  // Use bar index 1 (closed bar) for signals
   const int PREV_BAR_INDEX = 2;    // Previous bar index
   
   //--- MA indicator handles
   int fastMAHandle  = INVALID_HANDLE;
   int midMAHandle   = INVALID_HANDLE;
   int slowMAHandle  = INVALID_HANDLE;
   int atrHandle     = INVALID_HANDLE;
   ENUM_TIMEFRAMES currentTimeframe = PERIOD_CURRENT;
   
   //--- Swing tracking for visualization
   double lastSwingPrice = 0.0;
   int lastSwingBarIndex = 0;
   bool lastSwingIsHigh = false;
   
   //--- Trend detector instance
   CTrendDetector trendDetector;
   
   //--- Signal enumeration
   enum SIGNAL_TYPE
   {
      SIGNAL_NONE = 0,
      SIGNAL_BUY  = 1,
      SIGNAL_SELL = -1
   };
   
   //+------------------------------------------------------------------+
   //| Initialize indicators                                           |
   //+------------------------------------------------------------------+
   bool Init(const string symbol, ENUM_TIMEFRAMES timeframe)
   {
      currentTimeframe = timeframe;
      
      //--- Validate ATR is enabled (required for swing strategy)
      if(!InpUseATR)
      {
         Log::Error("ATR must be enabled (InpUseATR = true) for Swing HIGH/LOW SL strategy");
         return false;
      }
      
      //--- Create ATR indicator
      atrHandle = iATR(symbol, timeframe, InpATR_Period);
      if(atrHandle == INVALID_HANDLE)
      {
         Log::Error(StringFormat("Failed to create ATR indicator. Error: %d", GetLastError()));
         return false;
      }
      
      //--- Initialize ZigZag module
      if(!ZigZag::Init(symbol, timeframe))
      {
         IndicatorRelease(atrHandle);
         atrHandle = INVALID_HANDLE;
         return false;
      }

      //--- Register for swing updates (ZigZag will call OnNewSwingConfirmed)
      ZigZag::SetOnNewSwingCallback(OnNewSwingConfirmed);
      
      //--- Create Fast MA indicator (10) - for crossover signals
      fastMAHandle = iMA(symbol, timeframe, InpMA_FastPeriod, 0, InpMA_Method, InpMA_AppliedPrice);
      if(fastMAHandle == INVALID_HANDLE)
      {
         Log::Error(StringFormat("Failed to create Fast MA indicator. Error: %d", GetLastError()));
         ZigZag::Deinit();
         IndicatorRelease(atrHandle);
         atrHandle = INVALID_HANDLE;
         return false;
      }
      
      //--- Create Mid MA indicator (20) - for crossover signals
      midMAHandle = iMA(symbol, timeframe, InpMA_MidPeriod, 0, InpMA_Method, InpMA_AppliedPrice);
      if(midMAHandle == INVALID_HANDLE)
      {
         Log::Error(StringFormat("Failed to create Mid MA indicator. Error: %d", GetLastError()));
         IndicatorRelease(fastMAHandle);
         ZigZag::Deinit();
         IndicatorRelease(atrHandle);
         fastMAHandle = atrHandle = INVALID_HANDLE;
         return false;
      }
      
      //--- Create Slow MA indicator (50) - for trend filtering
      slowMAHandle = iMA(symbol, timeframe, InpMA_SlowPeriod, 0, InpMA_Method, InpMA_AppliedPrice);
      if(slowMAHandle == INVALID_HANDLE)
      {
         Log::Error(StringFormat("Failed to create Slow MA indicator. Error: %d", GetLastError()));
         IndicatorRelease(fastMAHandle);
         IndicatorRelease(midMAHandle);
         ZigZag::Deinit();
         IndicatorRelease(atrHandle);
         fastMAHandle = midMAHandle = atrHandle = INVALID_HANDLE;
         return false;
      }
      
      Log::Info(StringFormat("MAs initialized: Fast=%d, Mid=%d, Slow=%d, Method=%s", 
                InpMA_FastPeriod, InpMA_MidPeriod, InpMA_SlowPeriod, EnumToString(InpMA_Method)));
      
      //--- Initialize TrendDetector with shared MA handles
      if(!trendDetector.Init(symbol, timeframe, fastMAHandle, midMAHandle, slowMAHandle, atrHandle, 5))
      {
         Log::Error("Failed to initialize TrendDetector");
         IndicatorRelease(fastMAHandle);
         IndicatorRelease(midMAHandle);
         IndicatorRelease(slowMAHandle);
         IndicatorRelease(atrHandle);
         ZigZag::Deinit();
         fastMAHandle = midMAHandle = slowMAHandle = atrHandle = INVALID_HANDLE;
         return false;
      }
      
      return true;
   }
   
   //+------------------------------------------------------------------+
   //| Release indicators                                              |
   //+------------------------------------------------------------------+
   void Deinit()
   {
      trendDetector.Deinit();
      Draw::DeleteTrendPanel();

      //--- Unregister callback before ZigZag shutdown
      ZigZag::SetOnNewSwingCallback(NULL);
      ZigZag::Deinit();
      
      if(atrHandle != INVALID_HANDLE)    { IndicatorRelease(atrHandle);    atrHandle = INVALID_HANDLE; }
      if(fastMAHandle != INVALID_HANDLE) { IndicatorRelease(fastMAHandle); fastMAHandle = INVALID_HANDLE; }
      if(midMAHandle != INVALID_HANDLE)  { IndicatorRelease(midMAHandle);  midMAHandle = INVALID_HANDLE; }
      if(slowMAHandle != INVALID_HANDLE) { IndicatorRelease(slowMAHandle); slowMAHandle = INVALID_HANDLE; }
      
      Log::Info("All indicators released");
   }

   //+------------------------------------------------------------------+
   //| Update SL based on a confirmed swing (called from ZigZag)       |
   //+------------------------------------------------------------------+
   void ProcessStopLossUpdateFromSwing(const bool isHigh, const double swingPrice)
   {
      const string symbol = Symbol();
      if(!PositionSelect(symbol))
         return;

      const ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const ulong  ticket   = (ulong)PositionGetInteger(POSITION_TICKET);
      const double currSL   = PositionGetDouble(POSITION_SL);
      const double currTP   = PositionGetDouble(POSITION_TP);

      //--- Only react to the relevant swing for the current position
      if(posType == POSITION_TYPE_BUY && isHigh)
         return;
      if(posType == POSITION_TYPE_SELL && !isHigh)
         return;

      double atr = GetATR();
      if(atr <= 0.0)
         return;

      const double factor = InpATR_Multiplier;
      double newSL = 0.0;
      if(posType == POSITION_TYPE_BUY)
         newSL = swingPrice - atr * factor;
      else if(posType == POSITION_TYPE_SELL)
         newSL = swingPrice + atr * factor;
      else
         return;

      const int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
      newSL = NormalizeDouble(newSL, digits);

      //--- only "improve" SL (trail in the right direction)
      if(posType == POSITION_TYPE_BUY && currSL > 0.0 && newSL <= currSL)
         return;
      if(posType == POSITION_TYPE_SELL && currSL > 0.0 && newSL >= currSL)
         return;

      //--- basic stop-distance validation (avoid invalid modifications)
      const double point     = SymbolInfoDouble(symbol, SYMBOL_POINT);
      const int stopsLevel   = (int)SymbolInfoInteger(symbol, SYMBOL_TRADE_STOPS_LEVEL);
      const double minDist   = stopsLevel * point;

      const double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
      const double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);

      if(posType == POSITION_TYPE_BUY)
      {
         if(newSL >= bid - minDist)
            return;
      }
      else if(posType == POSITION_TYPE_SELL)
      {
         if(newSL <= ask + minDist)
            return;
      }

      //--- send SL/TP modification (native MQL5 request)
      MqlTradeRequest req;
      MqlTradeResult  res;
      ZeroMemory(req);
      ZeroMemory(res);

      req.action   = TRADE_ACTION_SLTP;
      req.symbol   = symbol;
      req.position = ticket;
      req.sl       = newSL;
      req.tp       = currTP;

      if(!OrderSend(req, res) || (res.retcode != TRADE_RETCODE_DONE && res.retcode != TRADE_RETCODE_DONE_PARTIAL))
         Log::Error(StringFormat("SL update failed. retcode=%d", (int)res.retcode));
      else
         Log::Info(StringFormat("SL updated (swing): %s pos=%I64u SL=%g", symbol, ticket, newSL));
   }

   //+------------------------------------------------------------------+
   //| Check for MA crossover signal                                   |
   //+------------------------------------------------------------------+
   SIGNAL_TYPE CheckSignal()
   {
      if(fastMAHandle == INVALID_HANDLE || midMAHandle == INVALID_HANDLE)
         return SIGNAL_NONE;
      
      double fastMA[], midMA[];
      ArraySetAsSeries(fastMA, true);
      ArraySetAsSeries(midMA, true);
      
      //--- Copy MA buffers (need 3 values: current, signal bar, previous bar)
      if(CopyBuffer(fastMAHandle, 0, 0, MA_BUFFER_SIZE, fastMA) != MA_BUFFER_SIZE ||
         CopyBuffer(midMAHandle, 0, 0, MA_BUFFER_SIZE, midMA) != MA_BUFFER_SIZE)
         return SIGNAL_NONE;
      
      //--- Get MA values from closed bars (avoid repainting)
      double fastCurr = fastMA[SIGNAL_BAR_INDEX];  // Bar 1 (last closed)
      double fastPrev = fastMA[PREV_BAR_INDEX];    // Bar 2 (previous closed)
      double midCurr  = midMA[SIGNAL_BAR_INDEX];
      double midPrev  = midMA[PREV_BAR_INDEX];
      
      //--- Bullish crossover: Fast MA crosses above Mid MA
      if(fastPrev < midPrev && fastCurr > midCurr)
         return SIGNAL_BUY;
      
      //--- Bearish crossover: Fast MA crosses below Mid MA
      if(fastPrev > midPrev && fastCurr < midCurr)
         return SIGNAL_SELL;
      
      return SIGNAL_NONE;
   }

     
   //+------------------------------------------------------------------+
   //| Get ATR value from last closed bar                              |
   //+------------------------------------------------------------------+
   double GetATR()
   {
      if(atrHandle == INVALID_HANDLE)
         return 0.0;
      
      double atrBuf[];
      ArraySetAsSeries(atrBuf, true);
      
      if(CopyBuffer(atrHandle, 0, 1, 1, atrBuf) != 1)
         return 0.0;
      
      return atrBuf[0];
   }

   //+------------------------------------------------------------------+
   //| Process Entry Logic                                              |
   //+------------------------------------------------------------------+
   void ProcessEntry()
   {
      SIGNAL_TYPE signal = CheckSignal();
   
      if(signal == SIGNAL_NONE)
         return;
   
      //--- Only one position per direction
      if(signal == SIGNAL_BUY && Orders::HasPosition(Symbol(), POSITION_TYPE_BUY))
         return;
      if(signal == SIGNAL_SELL && Orders::HasPosition(Symbol(), POSITION_TYPE_SELL))
         return;
      
      //--- Get entry price
      double entryPrice = (signal == SIGNAL_BUY) ? 
                          SymbolInfoDouble(Symbol(), SYMBOL_ASK) : 
                          SymbolInfoDouble(Symbol(), SYMBOL_BID);
      
      //--- Use fixed lot size
      double lots = InpLotSize;
      
      //--- Calculate stop loss using ZigZag swing points + ATR
      double atr = GetATR();
      double stopLoss = 0.0;
      
      if(signal == SIGNAL_BUY)          
            stopLoss = ZigZag::GetLastSwingLowPrice() - atr * InpATR_Multiplier;
         
      
      else if(signal == SIGNAL_SELL)
           stopLoss = ZigZag::GetLastSwingHighPrice() + atr * InpATR_Multiplier;
      
      
      //--- Execute trade with stop loss
      bool success = false;
      if(signal == SIGNAL_BUY)
         success = Orders::BuyMarket(Symbol(), lots, stopLoss);
      else if(signal == SIGNAL_SELL)
         success = Orders::SellMarket(Symbol(), lots, stopLoss);
      
      if(!success)          
         Log::Error("Failed to execute trade");
      
   }

   //+------------------------------------------------------------------+
   //| Refactor alias: entry check                                     |
   //+------------------------------------------------------------------+
   void checkforEntry()
   {
      ProcessEntry();
   }

   

   
}
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Global callback implementation                                   |
//+------------------------------------------------------------------+
void OnNewSwingConfirmed(bool isHigh, double swingPrice, int barIndex, datetime swingTime)
{
   Strategy::ProcessStopLossUpdateFromSwing(isHigh, swingPrice);
}
//+------------------------------------------------------------------+
