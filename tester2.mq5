//+------------------------------------------------------------------+
//|                                                      tester2.mq5 |
//|                                  Copyright 2023, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2023, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"

#include <Trade/Trade.mqh>
#include <Trade/AccountInfo.mqh>
#include <Arrays/ArrayDouble.mqh>
#include <Math/Stat/Math.mqh>

#include "ExpertAdvisor.mqh"

#include <Generic\HashMap.mqh>
#include <Generic\SortedMap.mqh>

static input long    InpMagicnumber = 234234;   // magic number (Integer+)

class GMExpert: public ExpertAdvisor{
public:
    CSortedMap<double,ulong> sortedMap;

    GMExpert(long inpType,long inpMagicNumber):ExpertAdvisor(inpType,inpMagicNumber){};

};
ulong ticketArr[] = {1,2,3,4,5,6,7};
double lotArr[] = {0.01,0.02,0.03,0.05,0.08,0.08,0.08};
double gridArr[]  = {100,150,225,338,507,761,1142};

ulong newTicketArr[] = {2,3,4,5,6};

GMExpert buyObj(POSITION_TYPE_BUY,InpMagicnumber);

int OnInit(){
   //buyObj.sortedMap.Remove(0);
    for(int i=0;i<ArraySize(ticketArr);i++){   
        buyObj.sortedMap.Add(gridArr[i],ticketArr[i]);
        Print(buyObj.sortedMap.Count());
    }

    double key[];
    ulong value[];
    
    buyObj.sortedMap.CopyTo(key,value);

    ArrayPrint(key);
    ArrayPrint(value);



    return(INIT_SUCCEEDED);
}
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason){
//---
   
}
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick(){
//---
   
}
//+------------------------------------------------------------------+
