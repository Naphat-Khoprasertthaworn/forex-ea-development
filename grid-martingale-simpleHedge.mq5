#property copyright "Copyright 2023, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"

#include <Trade/Trade.mqh>
#include <Trade/AccountInfo.mqh>

static input long    InpMagicnumber = 234234;   // magic number (Integer+)
static input double  InpLotSize     = 0.01;     // lot size
input int            InpPeriod      = 3600;       // period (sec)

input int            InpStopLoss    = 0;        // stop loss in points (point) (0=off)
input int            InpTakeProfit  = 150;      // take profit in points (point) (0=off)
input int            InpGridStep    = 150;      // step in grid system (point)

input double         InpMaxLotSize  = 0.15;      // max lot size
input double         InpLotMultiply = 1.5;        // multiply lot size

input double         InpPercentTP   = 30;       // percent for greedy! [0-100]
input int            InpMATicket    = 4;        // InpMATicket (Integer+)

CTrade trade;
MqlTick currentTick;
long levarage;
//string signal = "";


double NextBuyPrice;
double accBuyLot;
double dynamicBuyPrice;
double lastestBuyLotSize;
datetime lastestBuyTime;
bool signalBuy;

double NextSellPrice;
double accSellLot;
double dynamicSellPrice;
double lastestSellLotSize;
datetime lastestSellTime;
bool signalSell;

int OnInit()
{
   srand((uint)InpMagicnumber);
   trade.SetExpertMagicNumber(InpMagicnumber);
   levarage = AccountInfoInteger(ACCOUNT_LEVERAGE);
   
   accBuyLot = 0;
   dynamicBuyPrice = 0;
   lastestBuyLotSize = 0;
   lastestBuyTime = TimeCurrent()-InpPeriod;
   signalBuy = false;
   
   accSellLot = 0;
   dynamicSellPrice = 0;
   lastestSellLotSize = 0;
   lastestSellTime = TimeCurrent()-InpPeriod;
   signalSell = false;
   
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
   
   long type = NULL;
   
   CloseOrder();
   //if(!GetType(type) || CloseOrder()){
   //   type = NULL;
   //   NextBuyPrice=currentTick.ask;
   //   NextSellPrice=currentTick.bid;
   //   signal = RandomSignal();
   //}else{
   //   signal = (type==POSITION_TYPE_BUY) ? "buy" : "sell";
   //}
   
   if(!signalBuy){NextBuyPrice=currentTick.ask;}
   if(!signalSell){NextSellPrice=currentTick.bid;}
   
   if(!IsNewBar()){return;}

   if(currentTick.ask<=NextBuyPrice && lastestBuyTime + InpPeriod <= currentTick.time){
      
      LotSizeUpdate("buy");
      
      trade.Buy(lastestBuyLotSize,NULL,currentTick.ask,0,0,NULL);
      
      dynamicBuyPrice = ( dynamicBuyPrice*accBuyLot + currentTick.ask*lastestBuyLotSize )/(accBuyLot + lastestBuyLotSize);
      accBuyLot += lastestBuyLotSize;
      
      NextBuyPrice = currentTick.ask - InpGridStep * _Point;
      lastestBuyTime = currentTick.time;
      signalBuy = true;
   }

   if(currentTick.bid>=NextSellPrice && lastestSellTime + InpPeriod <= currentTick.time){
      
      LotSizeUpdate("sell");
      
      trade.Sell(lastestSellLotSize,NULL,currentTick.bid,0,0,NULL);
      
      dynamicSellPrice = ( dynamicSellPrice*accSellLot + currentTick.bid*lastestSellLotSize )/(accSellLot + lastestSellLotSize);
      accSellLot += lastestSellLotSize;
      
      NextSellPrice = currentTick.bid + InpGridStep*_Point;
      lastestSellTime = currentTick.time;
      signalSell = true;
   }

   Comment("Ask: ",currentTick.ask," NextBuyPrice: ",NextBuyPrice," DynamicBuyPrice: ",dynamicBuyPrice," accBuyLot: ",accBuyLot,
         "\nBid: ",currentTick.bid," NextSellPrice: ",NextSellPrice," DynamicSellPrice: ",dynamicSellPrice," accSellLot: ",accSellLot);
}

void LotSizeUpdate(string cmd){
   if(cmd=="buy"){
      if(lastestBuyLotSize ==0){
         lastestBuyLotSize = InpLotSize;
      }else{
         lastestBuyLotSize = (lastestBuyLotSize*InpLotMultiply > InpMaxLotSize) ? InpMaxLotSize : (double)((ceil(lastestBuyLotSize*InpLotMultiply*100))/100);
      }
   }else{
      if(lastestSellLotSize ==0){
         lastestSellLotSize = InpLotSize;
      }else{
         lastestSellLotSize = (lastestSellLotSize*InpLotMultiply > InpMaxLotSize) ? InpMaxLotSize : (double)((ceil(lastestSellLotSize*InpLotMultiply*100))/100);
      }
   }
}

void CloseOrder(){
   int totalTicket = PositionsTotal();
   if(totalTicket==0){return;}
   
   ulong ticketBuyArr[];
   ulong ticketSellArr[];
   
   if(!GetAllTicket(ticketBuyArr,ticketSellArr)){
      Print("CloseOrder : Failed to get ticket array ",PositionsTotal());
      return;
   }
   
   if(signalBuy){
      if(totalTicket > InpMATicket){
         if(CloseOrderReduceDrawdown(ticketBuyArr)){
            CloseOrderMAOpen(ticketBuyArr);
         }
   }else{
      CloseOrderMAOpen(ticketBuyArr);
      }
   }
   
   if(signalSell){
      if(totalTicket > InpMATicket){
         if(CloseOrderReduceDrawdown(ticketSellArr)){
            CloseOrderMAOpen(ticketSellArr);
         }
   }else{
      CloseOrderMAOpen(ticketSellArr);
      }
   }
}

long ticketArrType(ulong& ticketArr[]){
   PositionSelectByTicket( ticketArr[0] );
   return PositionGetInteger(POSITION_TYPE);
}

bool CloseOrderMAOpen(ulong& ticketArr[]){

   long type = ticketArrType(ticketArr);

   double netProfit = 0; 

   int totalTicket = ArraySize(ticketArr);
   
   if(type==POSITION_TYPE_BUY){
      netProfit = (currentTick.ask - dynamicBuyPrice);
      if(netProfit>=(InpTakeProfit*_Point)*InpLotSize/accBuyLot || (InpStopLoss > 0 && -netProfit >= (InpStopLoss*_Point)*InpLotSize/accBuyLot )){
         for(int i = 0;i<totalTicket;i++){
            trade.PositionClose(ticketArr[i]);
         }
         accBuyLot = 0;
         dynamicBuyPrice = 0;
         lastestBuyLotSize = 0;
         signalBuy = false;
         return true;
      }else{
         return false;
      }

   }else if(type==POSITION_TYPE_SELL){
      netProfit = (dynamicSellPrice - currentTick.bid);
      if(netProfit>=(InpTakeProfit*_Point)*InpLotSize/accSellLot || (InpStopLoss > 0 && -netProfit >= (InpStopLoss*_Point)*InpLotSize/accSellLot )){
         for(int i = 0;i<totalTicket;i++){
            trade.PositionClose(ticketArr[i]);
         }
         accSellLot = 0;
         dynamicSellPrice = 0;
         lastestSellLotSize = 0;
         signalSell = false;
         return true;
      }else{
         return false;
      }
   }
   return false;
}

bool CloseOrderReduceDrawdown(ulong& ticketArr[]){

   long type = ticketArrType(ticketArr);

   while(true){
      if( ArraySize(ticketArr) <= InpMATicket ){
         return true;
      }
      PositionSelectByTicket(ticketArr[ ArraySize(ticketArr)-1 ]);
      double lastLotSize = PositionGetDouble(POSITION_VOLUME);
      double lastOpenPrice = PositionGetDouble(POSITION_PRICE_OPEN);
      
      PositionSelectByTicket(ticketArr[ 0 ]);
      double firstLotSize = PositionGetDouble(POSITION_VOLUME);
      double firstOpenPrice = PositionGetDouble(POSITION_PRICE_OPEN);
      
      double profit = 0;

      if(type==POSITION_TYPE_BUY){
         profit = ((currentTick.ask-lastOpenPrice)*lastLotSize + (currentTick.ask-firstOpenPrice)*firstLotSize)*levarage;
      }else{
         profit = ((lastOpenPrice-currentTick.bid)*lastLotSize + (firstOpenPrice-currentTick.bid)*firstLotSize)*levarage;
      }
      
      if(profit >= InpTakeProfit*_Point*(firstLotSize + lastLotSize)*levarage*(InpPercentTP/100) ){
         trade.PositionClose(ticketArr[ ArraySize(ticketArr)-1 ]);
         trade.PositionClose(ticketArr[ 0 ]);
         ArrayRemove(ticketArr, 0 ,1);
         ArrayRemove(ticketArr, ArraySize(ticketArr)-1 ,1);
         if(type==POSITION_TYPE_BUY){
            dynamicBuyPrice = (dynamicBuyPrice*accBuyLot - lastOpenPrice*lastLotSize - firstOpenPrice*firstLotSize) / (accBuyLot - lastLotSize - firstLotSize);
            accBuyLot = accBuyLot - firstLotSize - lastLotSize;
         }else{
            dynamicSellPrice = (dynamicSellPrice*accSellLot - lastOpenPrice*lastLotSize - firstOpenPrice*firstLotSize) / (accSellLot - lastLotSize - firstLotSize);
            accSellLot = accSellLot - firstLotSize - lastLotSize;
         }
      }else{
         return false;
      }
   }
}

//string RandomSignal(){
//   int random = MathRand()%2;
//   if(random==1){
//      return "buy";
//   }else{
//      return "sell";
//   }
//}
//
//bool GetType(long& type){
//   if(PositionsTotal()<=0){return false;}
//   
//   ulong positionTicket = PositionGetTicket(0);
//   if(!PositionSelectByTicket(positionTicket)){Print("Failed to select position");return false;}
//   type = PositionGetInteger(POSITION_TYPE);
//   return true;
//}

bool GetAllTicket(ulong& ticketBuyArr[],ulong& ticketSellArr[]){
   int totalTicket = PositionsTotal();
   ArrayResize(ticketBuyArr,totalTicket);
   ArrayResize(ticketSellArr,totalTicket);
   int buyTicket = 0;
   int sellTicket = 0;
   for(int i = 0;i<totalTicket;i++){
      ulong positionTicket = PositionGetTicket(i);
      if(positionTicket<=0){Print("Failed to get ticket");return false;}
      if(!PositionSelectByTicket(positionTicket)){Print("Failed to select position");return false;}
      long magic,type;
      if(!PositionGetInteger(POSITION_MAGIC,magic)){Print("Failed to get magic");return false;}
      if(magic!=InpMagicnumber){Print("magic invalid");return false;}
      type = PositionGetInteger(POSITION_TYPE);
      if(type==POSITION_TYPE_BUY){
         ticketBuyArr[buyTicket] = positionTicket;
         buyTicket++;
      }else{
         ticketSellArr[sellTicket] = positionTicket;
         sellTicket++;
      }
   }
   if(buyTicket+sellTicket != totalTicket){Print("number of ticket invalid !");return false;}
   ArrayResize(ticketBuyArr,buyTicket);
   ArrayResize(ticketSellArr,sellTicket);
   return true;
}



bool IsNewBar(){
   static datetime previousTime = 0;
   datetime currentTime = iTime(_Symbol,PERIOD_CURRENT,0);
   if(previousTime!=currentTime){
      previousTime = currentTime;
      return true;
   }
   return false;
}

