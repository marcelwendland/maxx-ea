//+------------------------------------------------------------------+
//|                                                       Params.mqh |
//|                                       Step-by-Step Learning EA   |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Maxx"
#property strict

//+------------------------------------------------------------------+
//| Global typedefs for callbacks                                    |
//+------------------------------------------------------------------+
typedef void (*OnNewSwingCallback)(bool isHigh, double swingPrice, int barIndex, datetime swingTime);

//+------------------------------------------------------------------+
//| General Settings                                                 |
//+------------------------------------------------------------------+

const ulong    InpMagicNumber          = 123456;                             // Magic Number


//+------------------------------------------------------------------+
//| Risk Management                                                  |
//+------------------------------------------------------------------+

input double   InpLotSize              = 0.01;                               // Lot Size (0 = use risk %)
input double   InpRiskPercent          = 1.0;                                // Risk per Trade (%)
input double   InpMaxLotSize           = 10.0;                               // Maximum Lot Size

//+------------------------------------------------------------------+
//| Entry Settings                                                   |
//+------------------------------------------------------------------+

input int      InpSlippagePoints       = 10;                                 // Max Slippage (Points)
input int      InpMaxSpreadPoints      = 50;                                 // Max Spread (Points)

//+------------------------------------------------------------------+
//| Indicator Settings - Moving Averages                             |
//| Note: 3 MAs used - Fast(10) & Mid(20) for crossover signals,     |
//|       Slow(50) for trend filtering in TrendDetector              |
//+------------------------------------------------------------------+

input int      InpMA_FastPeriod        = 10;                                 // Fast MA Period (signal)
input int      InpMA_MidPeriod         = 20;                                 // Mid MA Period (signal)
input int      InpMA_SlowPeriod        = 50;                                 // Slow MA Period (trend)
input ENUM_MA_METHOD InpMA_Method      = MODE_EMA;                           // MA Method
input ENUM_APPLIED_PRICE InpMA_AppliedPrice = PRICE_CLOSE;                   // MA Applied Price

//+------------------------------------------------------------------+
//| Indicator Settings - ATR (for dynamic SL/TP)                     |
//+------------------------------------------------------------------+

input bool   InpUseATR           = true;    // Use ATR for SL distance
const int    InpATR_Period       = 14;       // ATR period
input double InpATR_Multiplier   = 0.5;      // ATR multiplier for SL

//| ZigZag Settings for Swing Detection                             |
//+------------------------------------------------------------------+
input int      InpZigZag_Depth     = 12;         // ZigZag Depth
input int      InpZigZag_Deviation = 5;          // ZigZag Deviation
input int      InpZigZag_Backstep  = 3;          // ZigZag Backstep
input int      InpZigZag_LookbackBars = 100;    // Bars to look back for swing detection



