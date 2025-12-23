//+------------------------------------------------------------------+
//|                                                    maxx_test.mq5 |
//|                                       Step-by-Step Learning EA   |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Maxx"
#property version   "1.00"
#property strict

//+------------------------------------------------------------------+
//| Includes                                                         |
//+------------------------------------------------------------------+
#include "maxxtestincludes/Log.mqh"
#include "maxxtestincludes/Params.mqh"
#include "maxxtestincludes/Orders.mqh"
#include "maxxtestincludes/Strategy.mqh"
#include "maxxtestincludes/Draw.mqh"

//+------------------------------------------------------------------+
//| Expert initialization function                                    |
//+------------------------------------------------------------------+
int OnInit()
{
  
   //--- Initialize order management
   Orders::Init();
   
   //--- Initialize strategy indicators
   if(!Strategy::Init(Symbol(), Period()))
   {
      Log::Error("Failed to initialize strategy");
      return(INIT_FAILED);
   }

   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                  |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   Strategy::Deinit();

}

//+------------------------------------------------------------------+
//| Check if it's a new bar and update timing                        |
//+------------------------------------------------------------------+
bool ProcessNewBar()
{
   static datetime lastBarTime = 0;
   datetime currentBarTime = iTime(Symbol(), Period(), 0);
   
   if(currentBarTime == lastBarTime)
      return false;  // Not a new bar, skip
   
   lastBarTime = currentBarTime;
   return true;
}

//+------------------------------------------------------------------+
//| Expert tick function                                              |
//+------------------------------------------------------------------+
void OnTick()
{
   //--- Only process on new bar
   if(!ProcessNewBar())
      return;

   Strategy::checkforEntry();
   ZigZag::Update();
}


//+------------------------------------------------------------------+
