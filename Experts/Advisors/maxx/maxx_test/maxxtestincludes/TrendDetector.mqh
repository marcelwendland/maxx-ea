//+------------------------------------------------------------------+
//| TrendDetector.mqh                                                |
//| EMA Stacking trend detection with multi-layer confirmation       |
//| Uses shared MA handles from Strategy (10/20/50)                  |
//| Layer 1: EMA Stack (Fast > Mid > Slow = UP)                      |
//| Layer 2: Price position relative to EMAs                         |
//| Layer 3: Slow EMA slope (momentum)                               |
//| Layer 4: EMA spacing normalized by ATR (strength)                |
//+------------------------------------------------------------------+

#property strict

#include "Log.mqh"
#include "Params.mqh"

class CTrendDetector
{
public:
   enum TrendDirection
   {
      TREND_UNKNOWN = 0,
      TREND_UP      = 1,
      TREND_DOWN    = -1,
      TREND_FLAT    = 2   // mixed/unclear
   };

private:
   string          m_symbol;
   ENUM_TIMEFRAMES m_tf;

   // --- Shared indicator handles (from Strategy)
   int             m_hEmaFast;      // Fast MA (10)
   int             m_hEmaMid;       // Mid MA (20)
   int             m_hEmaSlow;      // Slow MA (50)
   int             m_hATR;          // ATR for normalization
   int             m_slopeLookback; // bars to calculate slope
   bool            m_ownsHandles;   // false when using shared handles

   // --- EMA values (current and previous for slope)
   double          m_emaFast;
   double          m_emaMid;
   double          m_emaSlow;
   double          m_emaSlowPrev;   // for slope calculation
   double          m_atr;

   // --- Computed values
   TrendDirection  m_dir;
   int             m_strength;      // 0..100
   bool            m_isStacked;     // EMAs properly stacked
   bool            m_priceConfirmed;// Price confirms trend
   bool            m_slopeConfirmed;// Slope confirms trend
   double          m_slowSlope;     // Slope of slow EMA (points per bar)

public:
   CTrendDetector()
   : m_symbol(_Symbol),
     m_tf(PERIOD_CURRENT),
     m_slopeLookback(5),
     m_hEmaFast(INVALID_HANDLE),
     m_hEmaMid(INVALID_HANDLE),
     m_hEmaSlow(INVALID_HANDLE),
     m_hATR(INVALID_HANDLE),
     m_ownsHandles(false),
     m_emaFast(0), m_emaMid(0), m_emaSlow(0), m_emaSlowPrev(0),
     m_atr(0),
     m_dir(TREND_UNKNOWN),
     m_strength(0),
     m_isStacked(false),
     m_priceConfirmed(false),
     m_slopeConfirmed(false),
     m_slowSlope(0)
   {}

   //+------------------------------------------------------------------+
   //| Initialize with shared handles from Strategy                     |
   //| Parameters: handles for Fast(10), Mid(20), Slow(50) MAs + ATR   |
   //+------------------------------------------------------------------+
   bool Init(const string symbol, ENUM_TIMEFRAMES tf,
             int hEmaFast, int hEmaMid, int hEmaSlow, int hATR,
             int slopeLookback = 5)
   {
      m_symbol        = symbol;
      m_tf            = tf;
      m_slopeLookback = slopeLookback;
      m_ownsHandles   = false;  // We don't own these handles

      //--- Store shared handles
      m_hEmaFast = hEmaFast;
      m_hEmaMid  = hEmaMid;
      m_hEmaSlow = hEmaSlow;
      m_hATR     = hATR;

      //--- Validate handles
      if(m_hEmaFast == INVALID_HANDLE || m_hEmaMid == INVALID_HANDLE || 
         m_hEmaSlow == INVALID_HANDLE || m_hATR == INVALID_HANDLE)
      {
         Log::Error("TrendDetector: Invalid shared handles provided");
         return false;
      }

      Reset();
      Log::Info(StringFormat("TrendDetector initialized with shared MA handles (10/20/50), Slope lookback=%d",
                m_slopeLookback));
      return true;
   }

   //+------------------------------------------------------------------+
   //| Update - call from EA OnTick() (on new bar)                      |
   //+------------------------------------------------------------------+
   bool Update()
   {
      //--- Read EMA values from last closed bar (shift=1)
      if(!ReadBuffer(m_hEmaFast, 1, m_emaFast)) return false;
      if(!ReadBuffer(m_hEmaMid,  1, m_emaMid))  return false;
      if(!ReadBuffer(m_hEmaSlow, 1, m_emaSlow)) return false;
      if(!ReadBuffer(m_hATR,     1, m_atr))     return false;
      
      //--- Read previous slow EMA for slope calculation
      if(!ReadBuffer(m_hEmaSlow, 1 + m_slopeLookback, m_emaSlowPrev)) return false;

      //--- Get current price (close of last bar)
      double price = iClose(m_symbol, m_tf, 1);
      if(price == 0) return false;

      //--- Layer 1: EMA Stacking
      bool stackedUp   = (m_emaFast > m_emaMid && m_emaMid > m_emaSlow);
      bool stackedDown = (m_emaFast < m_emaMid && m_emaMid < m_emaSlow);
      m_isStacked = stackedUp || stackedDown;

      //--- Layer 2: Price Position
      bool priceAboveAll = (price > m_emaFast && price > m_emaMid && price > m_emaSlow);
      bool priceBelowAll = (price < m_emaFast && price < m_emaMid && price < m_emaSlow);
      m_priceConfirmed = (stackedUp && priceAboveAll) || (stackedDown && priceBelowAll);

      //--- Layer 3: Slow EMA Slope
      m_slowSlope = (m_emaSlow - m_emaSlowPrev) / m_slopeLookback;
      double slopeThreshold = m_atr * 0.01;  // Minimum slope = 1% of ATR per bar
      bool slopeUp   = m_slowSlope > slopeThreshold;
      bool slopeDown = m_slowSlope < -slopeThreshold;
      m_slopeConfirmed = (stackedUp && slopeUp) || (stackedDown && slopeDown);

      //--- Determine trend direction
      if(stackedUp)
         m_dir = TREND_UP;
      else if(stackedDown)
         m_dir = TREND_DOWN;
      else
         m_dir = TREND_FLAT;

      //--- Layer 4: Calculate Strength (0-100)
      CalculateStrength();

      return true;
   }

   //+------------------------------------------------------------------+
   //| Deinit - call from EA OnDeinit()                                 |
   //| Note: Does NOT release handles when using shared handles        |
   //+------------------------------------------------------------------+
   void Deinit()
   {
      //--- Only release handles if we own them (not shared)
      if(m_ownsHandles)
      {
         ReleaseHandle(m_hEmaFast);
         ReleaseHandle(m_hEmaMid);
         ReleaseHandle(m_hEmaSlow);
         ReleaseHandle(m_hATR);
      }
      else
      {
         //--- Just clear references, Strategy will release them
         m_hEmaFast = INVALID_HANDLE;
         m_hEmaMid  = INVALID_HANDLE;
         m_hEmaSlow = INVALID_HANDLE;
         m_hATR     = INVALID_HANDLE;
      }
      Reset();
   }

   //--- Getters
   TrendDirection Direction()        const { return m_dir; }
   int            Strength()         const { return m_strength; }
   bool           IsStacked()        const { return m_isStacked; }
   bool           IsPriceConfirmed() const { return m_priceConfirmed; }
   bool           IsSlopeConfirmed() const { return m_slopeConfirmed; }
   double         EmaFast()          const { return m_emaFast; }
   double         EmaMid()           const { return m_emaMid; }
   double         EmaSlow()          const { return m_emaSlow; }
   double         SlowSlope()        const { return m_slowSlope; }

   string DirectionText() const
   {
      string text;
      switch(m_dir)
      {
         case TREND_UP:   text = "UP";   break;
         case TREND_DOWN: text = "DOWN"; break;
         case TREND_FLAT: text = "FLAT"; break;
         default:         text = "UNKNOWN"; break;
      }
      
      //--- Add confirmation indicators
      if(m_dir == TREND_UP || m_dir == TREND_DOWN)
      {
         string conf = "";
         if(m_priceConfirmed) conf += "P";
         if(m_slopeConfirmed) conf += "S";
         if(conf != "") text += " [" + conf + "]";
      }
      return text;
   }

   //+------------------------------------------------------------------+
   //| Check if current trend allows a specific trade direction        |
   //+------------------------------------------------------------------+
   bool AllowsTrade(int signalType) const
   {
      // signalType: 1 = BUY, -1 = SELL
      // Require stacking + at least one confirmation layer
      if(m_dir == TREND_UP && signalType == 1)
         return m_isStacked && (m_priceConfirmed || m_slopeConfirmed);
      if(m_dir == TREND_DOWN && signalType == -1)
         return m_isStacked && (m_priceConfirmed || m_slopeConfirmed);
      return false;
   }

private:
   void Reset()
   {
      m_emaFast = m_emaMid = m_emaSlow = m_emaSlowPrev = 0;
      m_atr = 0;
      m_dir = TREND_UNKNOWN;
      m_strength = 0;
      m_isStacked = m_priceConfirmed = m_slopeConfirmed = false;
      m_slowSlope = 0;
   }

   //+------------------------------------------------------------------+
   //| Read single value from indicator buffer                         |
   //+------------------------------------------------------------------+
   bool ReadBuffer(int handle, int shift, double &outValue)
   {
      if(handle == INVALID_HANDLE) return false;
      
      double buf[];
      ArraySetAsSeries(buf, true);
      if(CopyBuffer(handle, 0, shift, 1, buf) != 1)
      {
         Log::Error(StringFormat("TrendDetector: CopyBuffer failed. Error=%d", GetLastError()));
         return false;
      }
      outValue = buf[0];
      return true;
   }

   //+------------------------------------------------------------------+
   //| Release indicator handle                                        |
   //+------------------------------------------------------------------+
   void ReleaseHandle(int &handle)
   {
      if(handle != INVALID_HANDLE)
      {
         IndicatorRelease(handle);
         handle = INVALID_HANDLE;
      }
   }

   //+------------------------------------------------------------------+
   //| Calculate trend strength (0-100)                                |
   //+------------------------------------------------------------------+
   void CalculateStrength()
   {
      if(m_dir == TREND_UNKNOWN || m_dir == TREND_FLAT || m_atr == 0)
      {
         m_strength = 0;
         return;
      }

      int score = 0;

      //--- Base: EMA stacking (25 points)
      if(m_isStacked)
         score += 25;

      //--- Price confirmation (25 points)
      if(m_priceConfirmed)
         score += 25;

      //--- Slope confirmation (25 points)
      if(m_slopeConfirmed)
         score += 25;

      //--- EMA Spacing normalized by ATR (0-25 points)
      //--- Wider spacing = stronger trend
      double fastMidSpacing = MathAbs(m_emaFast - m_emaMid);
      double midSlowSpacing = MathAbs(m_emaMid - m_emaSlow);
      double totalSpacing = fastMidSpacing + midSlowSpacing;
      
      //--- Normalize: 2 ATR spacing = full 25 points
      double spacingScore = MathMin(25.0, (totalSpacing / (m_atr * 2.0)) * 25.0);
      score += (int)spacingScore;

      m_strength = MathMin(100, score);
   }
};
