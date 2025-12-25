//+------------------------------------------------------------------+
//| TrendDetector.mqh                                                |
//| EMA Stacking trend detection with multi-layer confirmation       |

#include "Log.mqh"
#include "Params.mqh"
#include "Types.mqh"

namespace TrendDetector
{
   //--- MA indicator handle
   static int slowMAHandle = INVALID_HANDLE;

   //+------------------------------------------------------------------+
   //| Initialize TrendDetector                                        |
   //+------------------------------------------------------------------+
   bool Init(const string symbol, ENUM_TIMEFRAMES timeframe)
   {
      //--- Create Slow MA indicator (50) - for trend filtering
      slowMAHandle = iMA(symbol, timeframe, InpMA_SlowPeriod, 0, MA_Method, InpMA_AppliedPrice);
      if(slowMAHandle == INVALID_HANDLE)
      {
         Log::Error(StringFormat("Failed to create Slow MA indicator. Error: %d", GetLastError()));
         return false;
      }

      return true;
   }

   //+------------------------------------------------------------------+
   //| Deinitialize TrendDetector                                      |
   //+------------------------------------------------------------------+
   void Deinit()
   {
      if(slowMAHandle != INVALID_HANDLE)
      {
         IndicatorRelease(slowMAHandle);
         slowMAHandle = INVALID_HANDLE;
      }
   }

   //+------------------------------------------------------------------+
   //| Check if trend is aligned with signal direction                 |
   //+------------------------------------------------------------------+
   bool IsTrendAligned(const SIGNAL_TYPE signal)
   {
      if(slowMAHandle == INVALID_HANDLE)
         return false;

      double slowMABuf[];
      ArraySetAsSeries(slowMABuf, true);

      if(CopyBuffer(slowMAHandle, 0, 1, 2, slowMABuf) != 2)
         return false;

      //--- Determine trend direction
      if(slowMABuf[1] < slowMABuf[0])
      {
         // Uptrend
         return (signal == SIGNAL_BUY);
      }
      else if(slowMABuf[1] > slowMABuf[0])
      {
         // Downtrend
         return (signal == SIGNAL_SELL);
      }

      //--- No clear trend
      return false;
   }
