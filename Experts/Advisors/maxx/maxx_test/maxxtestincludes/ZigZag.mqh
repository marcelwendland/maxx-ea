//+------------------------------------------------------------------+
//| ZigZag.mqh - Step-by-Step Learning EA                            |
//+------------------------------------------------------------------+

#include "Log.mqh"
#include "Params.mqh"
#include "Draw.mqh"


//+------------------------------------------------------------------+
//| ZigZag Namespace - Handles ZigZag swing point detection          |
//+------------------------------------------------------------------+
namespace ZigZag
{
    //--- Chart marker IDs
    const ulong SWING_LOW_ARROW_ID  = 9000000001;
    const ulong SWING_HIGH_ARROW_ID = 9000000002;

    //--- Callback for new swing notification
    static OnNewSwingCallback onNewSwingCallback = NULL;

    //--- Indicator state
    int handle = INVALID_HANDLE;
    ENUM_TIMEFRAMES timeframe = PERIOD_CURRENT;
    string currentSymbol = "";

    //--- Swing state
    static datetime lastConfirmedSwingHighTime = 0;
    static datetime lastConfirmedSwingLowTime = 0;
    static double lastConfirmedSwingHighPrice = 0.0;
    static double lastConfirmedSwingLowPrice = 0.0;

    static datetime lastDrawnSwingHighTime = 0;
    static datetime lastDrawnSwingLowTime = 0;

    //--- ZigZag buffer cache
    static double zigzagBuf[];
    static datetime bufferRefTime = 0;
    static int cachedCopied = 0;
    static uint copyBufferCalls = 0;

    //--- Set callback for new swing
    void SetOnNewSwingCallback(OnNewSwingCallback cb)
    {
        onNewSwingCallback = cb;
    }

    //--- Reset all state and buffer
    void ResetVars()
    {
        lastConfirmedSwingHighTime = 0;
        lastConfirmedSwingLowTime = 0;
        lastConfirmedSwingHighPrice = 0.0;
        lastConfirmedSwingLowPrice = 0.0;

        lastDrawnSwingHighTime = 0;
        lastDrawnSwingLowTime = 0;

        ArrayResize(zigzagBuf, 0);
        cachedCopied = 0;
        bufferRefTime = 0;
    }

    //--- Ensure ZigZag buffer is up-to-date for the latest closed bar
    bool EnsureBufferUpdated()
    {
        if (handle == INVALID_HANDLE)
            return false;

        datetime closedBarTime = iTime(currentSymbol, timeframe, 1);

        if (closedBarTime == bufferRefTime && cachedCopied > 0 && ArraySize(zigzagBuf) > 0)
            return true;

        ArrayResize(zigzagBuf, InpZigZag_LookbackBars);
        ArraySetAsSeries(zigzagBuf, true);

        cachedCopied = CopyBuffer(handle, 0, 1, InpZigZag_LookbackBars, zigzagBuf);
        copyBufferCalls++;

        if (cachedCopied <= 0)
            return false;

        bufferRefTime = closedBarTime;
        return true;
    }

    //--- Draw or refresh swing marker on chart
    void MarkSwing(bool isHigh, datetime swingTime, double price, int barIndex)
    {
        if (barIndex <= 0 || swingTime == 0)
            return;

        // MQL5 does not support reference assignment in conditional expressions
        if (isHigh)
        {
            if (swingTime == lastDrawnSwingHighTime)
                return;
            lastDrawnSwingHighTime = swingTime;
            Draw::DrawSwingArrow(SWING_HIGH_ARROW_ID, barIndex, price, true);
        }
        else
        {
            if (swingTime == lastDrawnSwingLowTime)
                return;
            lastDrawnSwingLowTime = swingTime;
            Draw::DrawSwingArrow(SWING_LOW_ARROW_ID, barIndex, price, false);
        }
    }

    //--- Find swing point in ZigZag buffer
    bool FindSwingPoint(bool findLow, double &price, int &barIndex)
    {
        if (handle == INVALID_HANDLE)
            return false;

        if (!EnsureBufferUpdated())
            return false;

        for (int i = 0; i < cachedCopied; i++)
        {
            double v = zigzagBuf[i];
            // Use 0.0 for empty value if EMPTY_VALUE is not defined
            if (v == 0.0 || v == EMPTY_VALUE)
                continue;

            int b = i + 1;
            double hi = iHigh(currentSymbol, timeframe, b);
            double lo = iLow(currentSymbol, timeframe, b);
            bool isLow = (MathAbs(v - lo) < MathAbs(v - hi));

            if ((findLow && isLow) || (!findLow && !isLow))
            {
                price = v;
                barIndex = b;
                return true;
            }
        }
        return false;
    }

    //--- Check if a new swing (low or high) has been confirmed
    bool IsNewSwing(bool findLow, double &price, int &barIndex)
    {
        if(barIndex <= 0 || price <= 0)
            return false;

        if (!FindSwingPoint(findLow, price, barIndex))
            return false;

        datetime swingTime = iTime(currentSymbol, timeframe, barIndex);

        // MQL5 does not support reference assignment in conditional expressions
        if (findLow)
        {
            if (swingTime != lastConfirmedSwingLowTime)
            {
                lastConfirmedSwingLowTime = swingTime;
                lastConfirmedSwingLowPrice = price;
                MarkSwing(false, swingTime, price, barIndex);

                if (onNewSwingCallback)
                    onNewSwingCallback(false, price, barIndex, swingTime);

                return true;
            }
        }
        else
        {
            if (swingTime != lastConfirmedSwingHighTime)
            {
                lastConfirmedSwingHighTime = swingTime;
                lastConfirmedSwingHighPrice = price;
                MarkSwing(true, swingTime, price, barIndex);

                if (onNewSwingCallback)
                    onNewSwingCallback(true, price, barIndex, swingTime);

                return true;
            }
        }
        return false;
    }

    //--- Update or refresh latest swing markers (call once per bar)
    void Update()
    {
        double price;
        int barIndex;

        if (!IsNewSwing(true, price, barIndex) && barIndex > 0)
            MarkSwing(false, iTime(currentSymbol, timeframe, barIndex), price, barIndex);

        if (!IsNewSwing(false, price, barIndex) && barIndex > 0)
            MarkSwing(true, iTime(currentSymbol, timeframe, barIndex), price, barIndex);
    }

    //--- Initialize ZigZag indicator
    bool Init(const string symbol, ENUM_TIMEFRAMES tf)
    {
        currentSymbol = symbol;
        timeframe = tf;

        handle = iCustom(
            symbol, tf, "Examples\\ZigZag",
            InpZigZag_MinBarsBetweenSwings, MinPriceMove, MinBarsBetweenPoints
        );

        if (handle == INVALID_HANDLE)
        {
            Log::Error(StringFormat("Failed to create ZigZag indicator. Error: %d", GetLastError()));
            return false;
        }

        EnsureBufferUpdated();

        Log::Info(StringFormat(
            "ZigZag initialized: MinBarsBetweenSwings=%d, MinPriceMove=%d, MinBarsBetweenPoints=%d, Cached=%d",
            InpZigZag_MinBarsBetweenSwings, MinPriceMove, MinBarsBetweenPoints, cachedCopied
        ));

        double price;
        int barIndex;

        if (FindSwingPoint(true, price, barIndex))
        {
            lastConfirmedSwingLowTime = iTime(currentSymbol, timeframe, barIndex);
            lastConfirmedSwingLowPrice = price;
            MarkSwing(false, lastConfirmedSwingLowTime, price, barIndex);
        }

        if (FindSwingPoint(false, price, barIndex))
        {
            lastConfirmedSwingHighTime = iTime(currentSymbol, timeframe, barIndex);
            lastConfirmedSwingHighPrice = price;
            MarkSwing(true, lastConfirmedSwingHighTime, price, barIndex);
        }

        return true;
    }

    //--- Release ZigZag indicator and cleanup
    void Deinit()
    {
        if (handle != INVALID_HANDLE)
        {
            IndicatorRelease(handle);
            handle = INVALID_HANDLE;
        }

        ResetVars();

        if (!MQLInfoInteger(MQL_TESTER))
        {
            Log::Info(StringFormat("ZigZag Deinit: CopyBufferCalls=%u", copyBufferCalls));
            Draw::DeleteChartObject("Swing_Arrow_" + IntegerToString((long)SWING_LOW_ARROW_ID));
            Draw::DeleteChartObject("Swing_Arrow_" + IntegerToString((long)SWING_HIGH_ARROW_ID));
        }
    }

    //--- Reset tracking state (call when opening new position)
    void ResetState()
    {
        ResetVars();
    }

    //--- Get current swing LOW price and bar index
    bool GetSwingLow(double &price, int &barIndex)
    {
        return FindSwingPoint(true, price, barIndex);
    }

    //--- Get current swing HIGH price and bar index
    bool GetSwingHigh(double &price, int &barIndex)
    {
        return FindSwingPoint(false, price, barIndex);
    }

    //--- Check if a NEW swing LOW has been confirmed
    bool IsNewSwingLow(double &price, int &barIndex)
    {
        return IsNewSwing(true, price, barIndex);
    }

    //--- Check if a NEW swing HIGH has been confirmed
    bool IsNewSwingHigh(double &price, int &barIndex)
    {
        return IsNewSwing(false, price, barIndex);
    }

    //--- Get last confirmed swing LOW price
    double GetLastSwingLowPrice()
    {
        if (lastConfirmedSwingLowTime == 0)
        {
            double price;
            int barIndex;
            if (FindSwingPoint(true, price, barIndex))
            {
                lastConfirmedSwingLowTime = iTime(currentSymbol, timeframe, barIndex);
                lastConfirmedSwingLowPrice = price;
                MarkSwing(false, lastConfirmedSwingLowTime, price, barIndex);
            }
        }
        return lastConfirmedSwingLowPrice;
    }

    //--- Get last confirmed swing HIGH price
    double GetLastSwingHighPrice()
    {
        if (lastConfirmedSwingHighTime == 0)
        {
            double price;
            int barIndex;
            if (FindSwingPoint(false, price, barIndex))
            {
                lastConfirmedSwingHighTime = iTime(currentSymbol, timeframe, barIndex);
                lastConfirmedSwingHighPrice = price;
                MarkSwing(true, lastConfirmedSwingHighTime, price, barIndex);
            }
        }
        return lastConfirmedSwingHighPrice;
    }
}
//+------------------------------------------------------------------+
