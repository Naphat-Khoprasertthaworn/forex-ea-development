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
#include <Generic\RedBlackTree.mqh>

static input long    InpMagicnumber = 234234;   // magic number (Integer+)

class GMExpert: public ExpertAdvisor{
public:
    CRedBlackTree<CKeyValuePair<double,ulong>> tree;

    GMExpert(long inpType,long inpMagicNumber):ExpertAdvisor(inpType,inpMagicNumber){};

};

ulong ticketArr[10] = {1,2,3,4,5,6,7,8,9,10};
double gridArr[10]  = {0.1,0.2,0.3,0.4,0.5,0.6,0.7,0.8,0.9,1.0};

GMExpert buyObj(POSITION_TYPE_BUY,InpMagicnumber);

int OnInit(){

    for(int i=0;i<10;i++){
        CKeyValuePair<double,ulong> data;
        //data.Add(gridArr[i],ticketArr[i]);
        data.Key(gridArr[i]);
        data.Value(ticketArr[i])
        buyObj.tree.Add(&data);

        Print(buyObj.tree.Count());

    }
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
