#property copyright "Copyright 2023, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"

#include <Trade/Trade.mqh>
#include <Trade/AccountInfo.mqh>

static input long    InpMagicnumber = 234234;   // magic number (Integer+)
static input double  InpLotSize     = 0.01;     // lot size
input int            InpPeriod      = 3600;       // period (sec)
//input double         InpDeviation   = 2.0;      // deviation
input int            InpStopLoss    = 0;        // stop loss in points (point) (0=off)
input int            InpTakeProfit  = 150;      // take profit in points (point) (0=off)
input int            InpGridStep    = 150;      // step in grid system (point)

input double         InpMaxLotSize  = 0.15;      // max lot size
input double         InpLotMultiply = 1.5;        // multiply lot size

CTrade trade;
MqlTick currentTick;
long levarage;
string signal = "";

double accLot;
double dynamicOpenPrice;
double lastestLotSize;
datetime lastestOpenTime;


int OnInit()
{
   srand((uint)InpMagicnumber);
   trade.SetExpertMagicNumber(InpMagicnumber);
   levarage = AccountInfoInteger(ACCOUNT_LEVERAGE);
   accLot = 0;
   dynamicOpenPrice = 0;
   lastestLotSize = 0;
   lastestOpenTime = TimeCurrent()-InpPeriod;
   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason)
{

   
}

void OnTick()
{

   if(!SymbolInfoTick(_Symbol,currentTick)){
      Print("Failed to get tick");
      return;
   }

   static double NextBuyPrice,NextSellPrice;
   
   long type=NULL;
   if(CloseOrder(type)){
      NextBuyPrice=currentTick.ask;
      NextSellPrice=currentTick.bid;
      signal = RandomSignal();
   }else{
      signal = (type==POSITION_TYPE_BUY) ? "buy" : "sell";
   }
   if(signal=="sell" && currentTick.bid>=NextSellPrice && lastestOpenTime + InpPeriod <= currentTick.time){
      
      LotSizeUpdate();
      
      trade.Sell(lastestLotSize,NULL,currentTick.bid,0,0,NULL);
      
      dynamicOpenPrice = ( dynamicOpenPrice*accLot + currentTick.bid*lastestLotSize )/(accLot + lastestLotSize);
      accLot += lastestLotSize;
      
      NextSellPrice = currentTick.bid + InpGridStep*_Point;
      lastestOpenTime = currentTick.time;
      Comment("Bid: ",currentTick.bid,"\nNextSellPrice: ",NextSellPrice,"\nDynamicOpenPrice: ",dynamicOpenPrice,"\nAccumulateLotSize: ",accLot);
      
   }else if(signal=="buy" && currentTick.ask<=NextBuyPrice && lastestOpenTime + InpPeriod <= currentTick.time){
      
      LotSizeUpdate();
      trade.Buy(lastestLotSize,NULL,currentTick.ask,0,0,NULL);
      
      dynamicOpenPrice = ( dynamicOpenPrice*accLot + currentTick.ask*lastestLotSize )/(accLot + lastestLotSize);
      accLot += lastestLotSize;
      
      NextBuyPrice = currentTick.ask - InpGridStep * _Point;
      lastestOpenTime = currentTick.time;
      Comment("Ask: ",currentTick.ask,"\nNextBuyPrice: ",NextBuyPrice,"\nDynamicOpenPrice: ",dynamicOpenPrice,"\nAccumulateLotSize: ",accLot);
      
   }else if(signal==NULL){
      Print("Failed type is NULL");
      return;
   }
}

void LotSizeUpdate(){
   if(lastestLotSize==0){
      lastestLotSize = InpLotSize;
   }else{
      lastestLotSize = (lastestLotSize*InpLotMultiply > InpMaxLotSize) ? InpMaxLotSize : lastestLotSize*InpLotMultiply;
   }
}

bool CloseOrder(long &type){
   int totalTicket = PositionsTotal();
   if(totalTicket==0){
      type = NULL;
      return true;
   }
   ulong ticketArr[];
   if(!GetAllTicket(ticketArr,type)){
      Print("Failed to get ticket array");
      return false;
   }
   double netProfit = 0; 

   if(type==POSITION_TYPE_BUY){
      netProfit = (currentTick.ask - dynamicOpenPrice)*accLot*levarage;
   }else if(type==POSITION_TYPE_SELL){
      netProfit = (dynamicOpenPrice - currentTick.bid)*accLot*levarage;
   }else{
      return false;
   }

   if(netProfit>=(InpTakeProfit*_Point)*InpLotSize/accLot || (InpStopLoss > 0 && -netProfit >= (InpStopLoss*_Point)*InpLotSize/accLot )){
      for(int i = 0;i<totalTicket;i++){
         trade.PositionClose(ticketArr[i]);
      }
      type = NULL;
      accLot = 0;
      dynamicOpenPrice = 0;
      lastestLotSize = 0;
      return true;
   }
   return false;
}

string RandomSignal(){
   int random = MathRand()%2;
   if(random==1){
      return "buy";
   }else{
      return "sell";
   }
}

bool GetAllTicket(ulong& ticketArr[],long& type){
   int totalTicket = PositionsTotal();
   ArrayResize(ticketArr,totalTicket);
   for(int i = 0;i<totalTicket;i++){
      ulong positionTicket = PositionGetTicket(i);
      
      if(positionTicket<=0){Print("Failed to get ticket");return false;}
      
      if(!PositionSelectByTicket(positionTicket)){Print("Failed to select position");return false;}
      
      long magic;
      if(!PositionGetInteger(POSITION_MAGIC,magic)){Print("Failed to get magic");return false;}
      if(magic!=InpMagicnumber){Print("magic invalid");return false;}
      
      if(type==NULL){
         type = PositionGetInteger(POSITION_TYPE);
      }else if(type != NULL && type != PositionGetInteger(POSITION_TYPE)){Print("Failed. Some ticket's type error",PositionGetInteger(POSITION_TYPE)," ",type);return false;}
      
      ticketArr[i] = positionTicket;
   }
   return true;
}
