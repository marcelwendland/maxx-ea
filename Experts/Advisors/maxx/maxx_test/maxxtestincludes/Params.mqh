//+------------------------------------------------------------------+
//|                                                       Params.mqh |
//|                                       Step-by-Step Learning EA   |
//|                                                                  |
//+------------------------------------------------------------------+


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
//+------------------------------------------------------------------+
input int      InpMA_FastPeriod        = 7;                                 // Fast MA Period (signal)
input int      InpMA_MidPeriod         = 28;                                // Mid MA Period (signal)
input int      InpMA_SlowPeriod        = 56;                                // Slow MA Period (trend filter)


// Fixed MA method and applied price for simplicity
const ENUM_MA_METHOD MA_Method              = MODE_LWMA;                           // MA Method
const ENUM_APPLIED_PRICE InpMA_AppliedPrice = PRICE_MEDIAN;                   // MA Applied Price


//+------------------------------------------------------------------+
//| Indicator Settings - ATR (for dynamic SL/TP)                     |
//+------------------------------------------------------------------+
const int    InpATR_Period       = 13;       // ATR period
const double InpATR_Multiplier   = 0.5;      // ATR multiplier for SL

input int      InpMinBarsBetweenSwings = 11;  // Minimum bars between swings







