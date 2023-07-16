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

input double         InpPercentTP   = 30;       // percent for greedy! [0-100]
input int            InpMATicket    = 4;        // InpMATicket (Integer+)

CTrade trade;
MqlTick currentTick;
long levarage;
string signal = "buy";

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
   
   long type = NULL;
   if(!GetType(type) || CloseOrder()){
      type = NULL;
      NextBuyPrice=currentTick.ask;
      NextSellPrice=currentTick.bid;
      signal = RandomSignal();
   }else{
      signal = (type==POSITION_TYPE_BUY) ? "buy" : "sell";
   }
   
   if(!IsNewBar()){
      return;
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
      lastestLotSize = (lastestLotSize*InpLotMultiply > InpMaxLotSize) ? InpMaxLotSize : (double)((ceil(lastestLotSize*InpLotMultiply*100))/100);
   }
}

bool CloseOrder(){
   int totalTicket = PositionsTotal();
   if(totalTicket==0){
      return true;
   }
   
   if(totalTicket > InpMATicket){
      if(CloseOrderReduceDrawdown()){
         return CloseOrderMAOpen();
      }else{
         return false;
      }
   }else{
      return CloseOrderMAOpen();
   }
}

bool CloseOrderMAOpen(){

   long type = NULL;
   ulong ticketArr[];
   
   if(!GetAllTicket(ticketArr,type)){
      Print("CloseOrderMAOpen : Failed to get ticket array ",PositionsTotal());
      return false;
   }

   double netProfit = 0; 

   if(type==POSITION_TYPE_BUY){
      netProfit = (currentTick.ask - dynamicOpenPrice);
   }else if(type==POSITION_TYPE_SELL){
      netProfit = (dynamicOpenPrice - currentTick.bid);
   }else{
      return false;
   }

   int totalTicket = PositionsTotal();
   if(netProfit>=(InpTakeProfit*_Point)*InpLotSize/accLot || (InpStopLoss > 0 && -netProfit >= (InpStopLoss*_Point)*InpLotSize/accLot )){
      for(int i = 0;i<totalTicket;i++){
         trade.PositionClose(ticketArr[i]);
      }
      accLot = 0;
      dynamicOpenPrice = 0;
      lastestLotSize = 0;
      return true;
   }
   return false;
}

bool CloseOrderReduceDrawdown(){

   long type = NULL;
   ulong ticketArr[];
   if(!GetAllTicket(ticketArr,type)){
      Print("CloseOrderReduceDrawdown : Failed to get ticket array");
      return false;
   }

   int index = 0;
   
   while(true){
      if( sizeof(ticketArr)-1-index - index + 1 <= InpMATicket ){
         return true;
      }
      PositionSelectByTicket(ticketArr[ PositionsTotal()-1-index ]);
      double lastLotSize = PositionGetDouble(POSITION_VOLUME);
      double lastOpenPrice = PositionGetDouble(POSITION_PRICE_OPEN);
      
      PositionSelectByTicket(ticketArr[ index ]);
      double firstLotSize = PositionGetDouble(POSITION_VOLUME);
      double firstOpenPrice = PositionGetDouble(POSITION_PRICE_OPEN);
      
      double profit = 0;
      if(type==POSITION_TYPE_SELL){
         profit = ((lastOpenPrice-currentTick.bid)*lastLotSize + (firstOpenPrice-currentTick.bid)*firstLotSize)*levarage;
      }else{
         profit = ((currentTick.ask-lastOpenPrice)*lastLotSize + (currentTick.ask-firstOpenPrice)*firstLotSize)*levarage;
      }
      
      if(profit >= InpTakeProfit*_Point*(firstLotSize + lastLotSize)*levarage*(InpPercentTP/100) ){
      //if(profit >= InpTakeProfit*_Point*(firstLotSize + lastLotSize)*levarage*(firstLotSize + lastLotSize)/accLot){
         trade.PositionClose(ticketArr[ PositionsTotal()-1-index ]);
         trade.PositionClose(ticketArr[ index ]);
         
         //Print("Reduce successfully",
         //      "\nFirstLotSize : ",firstLotSize," FirstOpenSize : ",firstOpenPrice,
         //      "\nLastLotSize : ",lastLotSize," LastOpenPrice : ",lastOpenPrice,
         //      "\ncurrentBid : ",currentTick.bid," currentAsk : ",currentTick.ask,
         //      "\ngreedyTP : ",InpTakeProfit*_Point*(InpPercentTP/100)," MATP : ",InpTakeProfit*_Point*(firstLotSize + lastLotSize)/accLot);
               
         dynamicOpenPrice = (dynamicOpenPrice*accLot - lastOpenPrice*lastLotSize - firstOpenPrice*firstLotSize) / (accLot - lastLotSize - firstLotSize);
         accLot = accLot - firstLotSize - lastLotSize;
         
         index++;
      }else{
         return false;
      }
   }
   
}

string RandomSignal(){
   int random = MathRand()%2;
   if(random==1){
      return "buy";
   }else{
      return "sell";
   }
   //if(signal=="buy"){
   //   return "sell";
   //}else{
   //   return "buy";
   //}
  
}

bool GetType(long& type){
   if(PositionsTotal()<=0){return false;}
   
   ulong positionTicket = PositionGetTicket(0);
   if(!PositionSelectByTicket(positionTicket)){Print("Failed to select position");return false;}
   type = PositionGetInteger(POSITION_TYPE);
   return true;
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


bool IsNewBar(){
   
   static datetime previousTime = 0;
   datetime currentTime = iTime(_Symbol,PERIOD_CURRENT,0);
   if(previousTime!=currentTime){
      previousTime = currentTime;
      return true;
   }
   return false;
}