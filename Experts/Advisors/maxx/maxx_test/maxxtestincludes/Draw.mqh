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
   
   //+------------------------------------------------------------------+
   //| Draw trend indicator panel in upper left corner                 |
   //+------------------------------------------------------------------+
   void DrawTrendPanel(const string directionText, int strength, int trendDir)
   {
      //--- Skip drawing in backtest mode for performance
      if(MQLInfoInteger(MQL_TESTER))
         return;
      
      string panelName = "TrendPanel_BG";
      string dirLabel = "TrendPanel_Direction";
      string strengthLabel = "TrendPanel_Strength";
      
      //--- Determine colors based on trend direction
      color bgColor = clrDarkGray;
      color textColor = clrWhite;
      color dirColor = clrYellow;  // default: unclear
      
      // trendDir: 1=UP, -1=DOWN, 0=UNKNOWN, 2=FLAT/UNCLEAR
      if(trendDir == 1)       // UP
         dirColor = clrLime;
      else if(trendDir == -1) // DOWN
         dirColor = clrRed;
      else                    // UNKNOWN or FLAT
         dirColor = clrYellow;
      
      //--- Panel position
      int xPos = 20;
      int yPos = 30;
      int panelWidth = 180;
      int panelHeight = 60;
      
      //--- Create/update background rectangle
      if(ObjectFind(0, panelName) < 0)
      {
         ObjectCreate(0, panelName, OBJ_RECTANGLE_LABEL, 0, 0, 0);
         ObjectSetInteger(0, panelName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
         ObjectSetInteger(0, panelName, OBJPROP_XDISTANCE, xPos);
         ObjectSetInteger(0, panelName, OBJPROP_YDISTANCE, yPos);
         ObjectSetInteger(0, panelName, OBJPROP_XSIZE, panelWidth);
         ObjectSetInteger(0, panelName, OBJPROP_YSIZE, panelHeight);
         ObjectSetInteger(0, panelName, OBJPROP_BGCOLOR, bgColor);
         ObjectSetInteger(0, panelName, OBJPROP_BORDER_TYPE, BORDER_FLAT);
         ObjectSetInteger(0, panelName, OBJPROP_COLOR, clrWhite);
         ObjectSetInteger(0, panelName, OBJPROP_WIDTH, 1);
         ObjectSetInteger(0, panelName, OBJPROP_BACK, false);
         ObjectSetInteger(0, panelName, OBJPROP_SELECTABLE, false);
      }
      
      //--- Create/update direction label
      if(ObjectFind(0, dirLabel) < 0)
      {
         ObjectCreate(0, dirLabel, OBJ_LABEL, 0, 0, 0);
         ObjectSetInteger(0, dirLabel, OBJPROP_CORNER, CORNER_LEFT_UPPER);
         ObjectSetInteger(0, dirLabel, OBJPROP_XDISTANCE, xPos + 10);
         ObjectSetInteger(0, dirLabel, OBJPROP_YDISTANCE, yPos + 8);
         ObjectSetInteger(0, dirLabel, OBJPROP_FONTSIZE, 11);
         ObjectSetString(0, dirLabel, OBJPROP_FONT, "Arial Bold");
         ObjectSetInteger(0, dirLabel, OBJPROP_BACK, false);
         ObjectSetInteger(0, dirLabel, OBJPROP_SELECTABLE, false);
      }
      ObjectSetString(0, dirLabel, OBJPROP_TEXT, "Trend: " + directionText);
      ObjectSetInteger(0, dirLabel, OBJPROP_COLOR, dirColor);
      
      //--- Create/update strength label with visual bar
      if(ObjectFind(0, strengthLabel) < 0)
      {
         ObjectCreate(0, strengthLabel, OBJ_LABEL, 0, 0, 0);
         ObjectSetInteger(0, strengthLabel, OBJPROP_CORNER, CORNER_LEFT_UPPER);
         ObjectSetInteger(0, strengthLabel, OBJPROP_XDISTANCE, xPos + 10);
         ObjectSetInteger(0, strengthLabel, OBJPROP_YDISTANCE, yPos + 32);
         ObjectSetInteger(0, strengthLabel, OBJPROP_FONTSIZE, 10);
         ObjectSetString(0, strengthLabel, OBJPROP_FONT, "Arial");
         ObjectSetInteger(0, strengthLabel, OBJPROP_BACK, false);
         ObjectSetInteger(0, strengthLabel, OBJPROP_SELECTABLE, false);
      }
      
      //--- Build strength bar visualization
      string strengthBar = "";
      int barLength = strength / 10;  // 0-10 bars
      for(int i = 0; i < 10; i++)
      {
         if(i < barLength)
            strengthBar += "█";
         else
            strengthBar += "░";
      }
      ObjectSetString(0, strengthLabel, OBJPROP_TEXT, "Strength: " + strengthBar + " " + IntegerToString(strength) + "%");
      ObjectSetInteger(0, strengthLabel, OBJPROP_COLOR, textColor);
      
      ChartRedraw();
   }
   
   //+------------------------------------------------------------------+
   //| Delete trend panel objects                                       |
   //+------------------------------------------------------------------+
   void DeleteTrendPanel()
   {
      if(MQLInfoInteger(MQL_TESTER))
         return;
      
      DeleteChartObject("TrendPanel_BG");
      DeleteChartObject("TrendPanel_Direction");
      DeleteChartObject("TrendPanel_Strength");
      ChartRedraw();
   }
   
}

//+------------------------------------------------------------------+