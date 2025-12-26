//+------------------------------------------------------------------+
//|                                                         Draw.mqh |
//|                                       Chart Drawing Utilities    |
//|                                                                  |
//+------------------------------------------------------------------+
#include "Log.mqh"

//+------------------------------------------------------------------+
//| Drawing Namespace                                                |
//+------------------------------------------------------------------+
namespace Draw
{
   //+------------------------------------------------------------------+
   //| Helper: Delete chart object if exists                           |
   //+------------------------------------------------------------------+
   void DeleteChartObject(const string objName)
   {
      if(ObjectFind(0, objName) >= 0)
         ObjectDelete(0, objName);
   }

   
   //+------------------------------------------------------------------+
   //| Draw swing arrow marker on chart                                |
   //+------------------------------------------------------------------+
   void DrawSwingArrow(ulong ticket, int barIndex, double price, bool isHigh)
   {
      //--- Skip drawing in backtest mode for performance
      if(MQLInfoInteger(MQL_TESTER) && !MQLInfoInteger(MQL_VISUAL_MODE))
         return;
      
      string objName = "Swing_Arrow_" + IntegerToString(ticket);
      DeleteChartObject(objName);
      
      //--- Get bar time using iTime
      datetime barTime = iTime(Symbol(), Period(), barIndex);
      
      //--- Create arrow
      if(!ObjectCreate(0, objName, OBJ_ARROW, 0, barTime, price))
      {
         Log::Error(StringFormat("Failed to create swing arrow. Error: %d", GetLastError()));
         return;
      }
      
      //--- Arrow code: 218 = up arrow (for lows), 217 = down arrow (for highs)
      int arrowCode = isHigh ? 217 : 218;
      
      ObjectSetInteger(0, objName, OBJPROP_COLOR, clrRed);
      ObjectSetInteger(0, objName, OBJPROP_ARROWCODE, arrowCode);
      ObjectSetInteger(0, objName, OBJPROP_WIDTH, 3);
      ObjectSetInteger(0, objName, OBJPROP_BACK, false);
      ObjectSetInteger(0, objName, OBJPROP_SELECTABLE, true);
      ObjectSetInteger(0, objName, OBJPROP_SELECTED, false);
      ObjectSetString(0, objName, OBJPROP_TEXT, "Swing " + (isHigh ? "HIGH" : "LOW"));
      
      ChartRedraw();
   }
   
}

//+------------------------------------------------------------------+