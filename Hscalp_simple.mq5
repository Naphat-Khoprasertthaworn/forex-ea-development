#property copyright "Copyright 2023, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"

#include <Trade/Trade.mqh>

static input long    InpMagicnumber    = 234234;   // magic number (Integer+)

input double         InpLotInit        = 0.01;     // Initial lot size
input double         InpLotMultiply    = 2;        // Multiply lot size
input double         InpLotMax         = 0.64;     // Max lot size
input double         InpLotMaxAcc      = 1;        // Max accumulate lot size

input int            InpGridInit       = 150;      // Initial step in grid system (point)
input double         InpGridMultiply   = 2;        // Multiply grid step
input int            InpGridMax        = 1200;     // Max grid step

input int            InpTP          = 300;      // Take profit in points (point) (0=off)
//input double         InpTPPercent   = 30;       // Ratio of take profit when closing order matching 

//input int            InpDDMax       = 30;       // Maximum drawdown (relative)
//input int            InpMATicket    = 4;        // Maximum ticket for closing by moving average
input int            InpCooldown    = 3600;     // Cooldown (sec)
//input int            InpStopLoss    = 0;        // Stop loss (point) (0=off)

input int                  InpMACDFastPeriod    = 12;             // MACD period for Fast average calculation
input int                  InpMACDSlowPeriod    = 26;             // MACD period for Slow average calculation
input int                  InpMACDSignalPeriod  = 9;              // MACD period for their difference averaging
input ENUM_APPLIED_PRICE   InpMACDAppPrice      = PRICE_CLOSE;    // MACD type of price or handle
input double               InpMACDLevel         = 0.004;          // MACD level (lower = 0-level , upper = 0+level)
input ENUM_TIMEFRAMES      InpMACDTimeFrame     = PERIOD_H1;      // MACD timeframe
input bool                 InpMACDActive        = true;           // MACD active

CTrade trade;
MqlTick currentTick;

double nextOpenPrice;
double nextLot;
double accLot;
datetime lastTime;
double netProfit;
double nextGrid;

bool buyStatus;
bool sellStatus;

int handleMACD;
double macdMainBuffer[];
double macdMainTempBuffer[];
double macdSignalBuffer[];
double macdSignalTempBuffer[];
bool macdBuySignal;
bool macdSellSignal;




int OnInit(){
   trade.SetExpertMagicNumber(InpMagicnumber);
   
   nextLot = 0;
   accLot = 0;
   lastTime = TimeCurrent();
   netProfit = 0;
   
   nextOpenPrice = 0;
   
   nextLot = InpLotInit;
   nextGrid = InpGridInit;
   
   buyStatus = false;
   sellStatus = false;
   
   macdBuySignal = false;
   macdSellSignal = false;
   
   handleMACD = iMACD(NULL,InpMACDTimeFrame,InpMACDFastPeriod,InpMACDSlowPeriod,InpMACDSignalPeriod,InpMACDAppPrice);
   ArrayResize(macdMainBuffer,1);
   ArrayResize(macdMainTempBuffer,1);
   ArrayResize(macdSignalBuffer,1);
   ArrayResize(macdSignalTempBuffer,1);
   
   
   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason){

   
}

void OnTick(){
   if(!SymbolInfoTick(Symbol(),currentTick)){Print("Failed to get tick");return;}
   if(IsNewBar()){UpdateIndicatorBuffer();MACDSignal();}
   
   if(TryCloseOrder()){
      lastTime = currentTick.time;
   }
   
   if(!buyStatus && !sellStatus){
      if(macdBuySignal){
         nextOpenPrice = currentTick.ask;
      }
      if(macdSellSignal){
         nextOpenPrice = currentTick.bid;
      }
   }
   
   if(currentTick.time >= lastTime + InpCooldown && accLot + nextLot <= InpLotMaxAcc){
      if( ( (buyStatus && !sellStatus) || (!buyStatus && !sellStatus && macdSellSignal) ) && currentTick.bid <= nextOpenPrice ){
         if(trade.Sell(nextLot,Symbol(),currentTick.bid,0,0,NULL)){
            accLot += nextLot;
            lastTime = currentTick.time;
            nextOpenPrice = currentTick.bid + nextGrid*Point();
            LotSizeUpdate();
            GridStepUpdate();
            buyStatus = false;
            sellStatus = true;
         }else{
            Print("Sell fail");
         }
      }
      else if( ( (sellStatus && !buyStatus) || (!buyStatus && !sellStatus && macdBuySignal) ) && currentTick.ask >= nextOpenPrice ){
         if(trade.Buy(nextLot,Symbol(),currentTick.ask,0,0,NULL)){
            accLot += nextLot;
            lastTime = currentTick.time;
            nextOpenPrice = currentTick.ask - nextGrid*Point();
            LotSizeUpdate();
            GridStepUpdate();
            buyStatus = true;
            sellStatus = false;
         }else{
            Print("Buy fail");
         }
      }
      
   }
   Comment("Ask: ",currentTick.ask,"Bid: ",currentTick.bid,
         "\nAccumulateLot: ",accLot," nextLot: ",nextLot," GridStep: ",nextGrid,
         "\nSpread: ",currentTick.ask - currentTick.bid,
         "\nNextOpenPrice: ",nextOpenPrice," lastTime: ",lastTime," buyStatus: ",buyStatus," sellStatus: ",sellStatus,
         "\nNetProfit: ",netProfit," expected TP: ",InpTP*InpLotInit);
}

bool TryCloseOrder(){
   
   ulong ticketArr[];
   if(!GetAllTicket(ticketArr)){
      Print("TryCloseOrder : Failed to get ticket array ",PositionsTotal());
      return false;
   }else{
      if(ArraySize(ticketArr)==0){
         return false;
      }
      if(!UpdateNetProfit(ticketArr)){
         Print("TryCloseOrder : Failed to update netProfit ",netProfit);
         return false;
      }
   }
   
   if( netProfit >= InpTP*InpLotInit ){
      bool tempFlag = true;
      double tempFailBuyLot = 0;
      double tempFailSellLot = 0;
      
      for(int i=ArraySize(ticketArr)-1;i>=0;i--){
         PositionSelectByTicket( ticketArr[i] );
         double tempLot = PositionGetDouble(POSITION_VOLUME);
         if(trade.PositionClose(ticketArr[i])){
            accLot -= tempLot;
            ArrayRemove(ticketArr,i,1);
         }else{
            if(PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY){
               tempFailBuyLot += PositionGetDouble(POSITION_VOLUME);
            }else{
               tempFailSellLot += PositionGetDouble(POSITION_VOLUME);
            }
            tempFlag = false;
         }
      }
      
      if(tempFlag){
         Print( "CloseOrder : netProfit : ",netProfit );
         accLot = 0;
         netProfit = 0;
         nextLot = InpLotInit;
         nextGrid = InpGridInit;
         buyStatus = false;
         sellStatus = false;
         return true;
      }else{
         if(tempFailBuyLot > tempFailSellLot){
            buyStatus = true;
            sellStatus = false;
         }else if(tempFailBuyLot < tempFailSellLot){
            buyStatus = false;
            sellStatus = true;
         }else{
            buyStatus = false;
            sellStatus = false;
         }
      }
   }
   return false;
   
   
   
}

void LotSizeUpdate(){
   nextLot = (nextLot*InpLotMultiply > InpLotMax) ? InpLotMax : (double)((ceil(nextLot*InpLotMultiply*100))/100);
}

void GridStepUpdate(){
   nextGrid = (nextGrid*InpGridMultiply > InpGridMax) ? InpGridMax : (double)((ceil(nextGrid*InpGridMultiply*100))/100);
}

void UpdateIndicatorBuffer(){
   ArrayCopy( macdMainTempBuffer,macdMainBuffer );
   ArrayCopy( macdSignalTempBuffer,macdSignalBuffer );
   CopyBuffer( handleMACD,MAIN_LINE,0,1,macdMainBuffer );
   CopyBuffer( handleMACD,SIGNAL_LINE,0,1,macdSignalBuffer );
}

void MACDSignal(){
   macdBuySignal = false;
   macdSellSignal = false;
   if( macdMainBuffer[0] < InpMACDLevel && macdSignalBuffer[0] < InpMACDLevel && macdMainTempBuffer[0] <= macdSignalTempBuffer[0] && macdMainBuffer[0] > macdSignalBuffer[0] ){
      macdBuySignal = true;
   }
   else if( macdMainBuffer[0] > -InpMACDLevel && macdSignalBuffer[0] > -InpMACDLevel && macdMainTempBuffer[0] >= macdSignalTempBuffer[0] && macdMainBuffer[0] < macdSignalBuffer[0] ){
      macdSellSignal = true;
   }
}

bool GetAllTicket(ulong& ticketArr[]){
   int totalTicket = PositionsTotal();
   ArrayResize(ticketArr,totalTicket);
   int realTotal = 0;
   for(int i = 0;i<totalTicket;i++){
      ulong positionTicket = PositionGetTicket(i);
      if(positionTicket<=0){Print("Failed to get ticket");return false;}
      if(!PositionSelectByTicket(positionTicket)){Print("Failed to select position");return false;}
      if(Symbol() != PositionGetString(POSITION_SYMBOL)){continue;}
      if(PositionGetInteger(POSITION_MAGIC)!=InpMagicnumber){continue;}
      
      ticketArr[realTotal] = positionTicket;
      realTotal++;
   }
   ArrayResize(ticketArr,realTotal);
   return true;
}

bool UpdateNetProfit( ulong& ticketArr[] ){
   netProfit = 0;
   for(int i = 0;i<ArraySize(ticketArr);i++){
      if(!PositionSelectByTicket(ticketArr[i])){Print("Failed to select position");return false;}
      netProfit += PositionGetDouble(POSITION_PROFIT);
   }
   return true;
}

bool IsNewBar(){
   static datetime previousTime = 0;
   datetime currentTime = iTime(Symbol(),PERIOD_H1,0);
   if(previousTime!=currentTime){
      previousTime = currentTime;
      return true;
   }
   return false;
}