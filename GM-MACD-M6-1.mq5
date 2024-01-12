#property copyright "Copyright 2023, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"

#include <Trade/Trade.mqh>
#include <Trade/AccountInfo.mqh>
#include <Arrays/ArrayDouble.mqh>
#include <Math/Stat/Math.mqh>
#include <Generic\HashMap.mqh>

#include <Arrays\Tree.mqh>

#include "ExpertAdvisor.mqh"

#include 

static input long    InpMagicnumber = 234234;   // magic number (Integer+)

input double         InpLotSize        = 0.01;     // lot size
input int            InpPeriod         = 3600;     // period (sec)
input int            InpTakeProfit     = 700;      // take profit in points (point) (0=off)
input int            InpGridStep       = 150;      // step in grid system (point)
input double         InpGridMultiply   = 1.5;      // multiply grid step
input double         InpMaxGrid        = 6643;     // max grid step
input double         InpMaxLotSize     = 0.15;     // max lot size
input double         InpLotMultiply    = 1.5;      // multiply lot size
input double         InpPercentTP      = 0;        // percent for greedy! [0-100]
input int            InpMATicket       = 4;        // InpMATicket (Integer+)
input double         InpMaxAccLot      = 1;        // ex. InpMaxAccLot = 1 is max of accBuyLot and accSellLot = 0.5

input int            InpStoKPeriod  = 5;              // Sto K-period (number of bars for calculations)
input int            InpStoDPeriod  = 3;              // Sto D-period (period of first smoothing)
input int            InpStoSlowing  = 3;              // Sto final smoothing
input ENUM_MA_METHOD InpStoMAMethod = MODE_SMA;       // Sto type of smoothing (0 SMA,1 EMA,2 SMMA,3 LWMA )
input ENUM_STO_PRICE InpStoPrice    = STO_LOWHIGH;    // Sto stochastic calculation method (0 LOWHIGH,1 CLOSECLOSE)
input double         InpStoLevel    = 45;             // Sto Level (lower = 50 - level,upper = 50 + level)
input bool           InpStoActive   = true;           // Sto active

input int                  InpRSIMAPeriod = 14;             // RSI averaging period
input ENUM_APPLIED_PRICE   InpRSIAppPrice = PRICE_CLOSE;    // RSI type of price or handle
input double               InpRSILevel    = 25;             // RSI level (lower = 50 - level , upper = 50 + level)
input bool                 InpRSIActive   = false;          // RSI active

input int                  InpCCIMAPeriod = 14;             // CCI averaging period
input ENUM_APPLIED_PRICE   InpCCIAppPrice = PRICE_TYPICAL;  // CCI type of price or handle
input double               InpCCILevel    = 180;            // CCI level (upper = level , lower = -level)
input bool                 InpCCIActive   = false;          // CCI active


input int                  InpMACDFastPeriod    = 12;             // MACD period for Fast average calculation
input int                  InpMACDSlowPeriod    = 26;             // MACD period for Slow average calculation
input int                  InpMACDSignalPeriod  = 9;              // MACD period for their difference averaging
input ENUM_APPLIED_PRICE   InpMACDAppPrice      = PRICE_CLOSE;    // MACD type of price or handle
input double               InpMACDLevel         = 0.0007;         // MACD level (lower = 0-level , upper = 0+level)
input ENUM_TIMEFRAMES      InpMACDTimeFrame     = PERIOD_H1;      // MACD timeframe
input bool                 InpMACDActive        = true;           // MACD active


input int            InpHardStoKPeriod  = 5;             // D1 Sto K-period (number of bars for calculations)
input int            InpHardStoDPeriod  = 3;             // D1 Sto D-period (period of first smoothing)
input int            InpHardStoSlowing  = 3;             // D1 Sto final smoothing
input ENUM_MA_METHOD InpHardStoMAMethod = MODE_SMA;      // D1 Sto type of smoothing (0 SMA,1 EMA,2 SMMA,3 LWMA )
input ENUM_STO_PRICE InpHardStoPrice    = STO_LOWHIGH;   // D1 Sto stochastic calculation method (0 LOWHIGH,1 CLOSECLOSE)
input double         InpHardStoLevel    = 45;            // D1 Sto level (lower = 50-level , upper = 50 + level)
input bool           InpHardStoActive   = true;          // D1 Sto active

input bool           InpOptimizeMode    = false;         // Optimize mode is on = unable Print function

class TreeOrder: public CTree{
public:
    OrderNode* findByGrid(double gridStep){
        OrderNode *res = NULL;
        OrderNode *node;

        node = new OrderNode(0,gridStep);
        if(node==NULL) return NULL;

        res = Find(node);
        delete node;
        return res;
    }

    OrderNode* CreateElement(){
        OrderNode *node = new OrderNode(0,0);
        return node;
    }
};

class GMExpert: public ExpertAdvisor{
public:
    CTree tree;

    GMExpert(long inpType):ExpertAdvisor(inpType){
    };

};

ExpertAdvisor buyObj(POSITION_TYPE_BUY);
ExpertAdvisor sellObj(POSITION_TYPE_SELL);

CTrade trade;
MqlTick currentTick;

bool buySignal;

bool sellSignal;

int handleSto;
bool stoBuySignal;
bool stoSellSignal;
double stoMainBuffer[];
double stoSignalBuffer[];

int handleRSI;
double rsiBuffer[];
bool rsiBuySignal;
bool rsiSellSignal;

int handleCCI;
double cciBuffer[];
bool cciBuySignal;
bool cciSellSignal;

int handleMACD;
double macdMainBuffer[];
double macdMainTempBuffer[];
double macdSignalBuffer[];
double macdSignalTempBuffer[];
bool macdBuySignal;
bool macdSellSignal;

int handleHardSto;
double hardStoMainBuffer[];
double hardStoSignalBuffer[];
bool hardStoSellSignal;
bool hardStoBuySignal;

ulong buyTicketArr[];
ulong sellTicketArr[];

double buyGridArr[];
double sellGridArr[];
double buyLotArr[];
double sellLotArr[];
double gridArrTemplate[];
double lotArrTemplate[];


int OnInit(){
   trade.SetExpertMagicNumber(InpMagicnumber);
   
   buySignal = false;
   sellSignal = false;

   handleSto = iStochastic( NULL,PERIOD_H1,InpStoKPeriod,InpStoDPeriod,InpStoSlowing,InpStoMAMethod,InpStoPrice ); 
   ArrayResize(stoMainBuffer,1);
   ArrayResize(stoSignalBuffer,1);
   
   handleRSI = iRSI(NULL,PERIOD_H1,InpRSIMAPeriod,InpRSIAppPrice);
   ArrayResize(rsiBuffer,1);
   
   handleCCI = iCCI(NULL,PERIOD_H1,InpCCIMAPeriod,InpCCIAppPrice);
   ArrayResize(cciBuffer,1);
   
   handleMACD = iMACD(NULL,InpMACDTimeFrame,InpMACDFastPeriod,InpMACDSlowPeriod,InpMACDSignalPeriod,InpMACDAppPrice);
   ArrayResize(macdMainBuffer,1);
   ArrayResize(macdMainTempBuffer,1);
   ArrayResize(macdSignalBuffer,1);
   ArrayResize(macdSignalTempBuffer,1);
   
   handleHardSto = iStochastic(NULL,PERIOD_D1,InpHardStoKPeriod,InpHardStoDPeriod,InpHardStoSlowing,InpHardStoMAMethod,InpHardStoPrice);
   ArrayResize(hardStoMainBuffer,1);
   ArrayResize(hardStoSignalBuffer,1);
   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason){
}

void OnTick(){
   if(!SymbolInfoTick(Symbol(),currentTick)){Print("Failed to get tick");return;}
   
   if(IsNewBar()){UpdateIndicatorBuffer();SignalByIndicator();}
   
   if(!buyObj.loadTickets()){Print("Failed to load buyObj tickets for checking close order");}
   else{
      if(CloseOrder(buyObj)){
         buyObj.loadTickets();
         updateGridMap(buyObj,buyTicketArr,buyGridArr);
      }
   }
      
   if(!sellObj.loadTickets()){Print("Failed to load sellObj tickets for checking close order");}
   else{
      if(CloseOrder(sellObj)){
         sellObj.loadTickets();
         updateGridMap(sellObj,sellTicketArr,sellGridArr);
      }
   }
   
   if(!buyObj.loadTickets()){Print("Failed to load buyObj tickets");}
   if(!sellObj.loadTickets()){Print("Failed to load sellObj tickets");}

   if(currentTick.ask<=nextOpenPrice(buyObj) && nextOpenTime(buyObj) <= currentTick.time && buySignal && buyObj.getAccLots() + nextOpenLot(buyObj) < InpMaxAccLot/2 ){
      if(trade.Buy(nextOpenLot(buyObj),NULL,currentTick.ask,0,0,NULL)){
         ulong lastOrder = trade.ResultDeal();
         double nextGrid = nextGridStep(buyObj, buyGridArr);
         ArrayResize(buyTicketArr,ArraySize(buyTicketArr)+1);
         ArrayResize(buyGridArr,ArraySize(buyGridArr)+1);
         buyTicketArr[ArraySize(buyTicketArr)-1] = lastOrder;
         buyGridArr[ArraySize(buyGridArr)-1] = nextGrid;
      }
   }
   
   if(currentTick.bid>=nextOpenPrice(sellObj) && nextOpenTime(sellObj) <= currentTick.time && sellSignal && sellObj.getAccLots() + nextOpenLot(sellObj) < InpMaxAccLot/2 ){
      if(trade.Sell(nextOpenLot(sellObj),NULL,currentTick.bid,0,0,NULL)){
         ulong lastOrder = trade.ResultDeal();
         double nextGrid = nextGridStep(sellObj, sellGridArr);
         ArrayResize(sellTicketArr,ArraySize(sellTicketArr)+1);
         ArrayResize(sellGridArr,ArraySize(sellGridArr)+1);
         sellTicketArr[ArraySize(sellTicketArr)-1] = lastOrder;
         sellGridArr[ArraySize(sellGridArr)-1] = nextGrid;
      }
   }

   double lastBuyGrid, lastSellGrid;
   
   lastBuyGrid = (ArraySize(buyGridArr)==0) ? 0 : buyGridArr[ArraySize(buyGridArr)-1];
   lastSellGrid = (ArraySize(sellGridArr)==0) ? 0 : sellGridArr[ArraySize(sellGridArr)-1];

   Comment("Ask: ",NormalizeDouble(currentTick.ask,5)," nextBuyPrice: ",NormalizeDouble(nextOpenPrice(buyObj),2),  " BuyProfit: ",NormalizeDouble(buyObj.getProfit(),2),  " accBuyLot: ",NormalizeDouble(buyObj.getAccLots(),2),
         "\nBid: ",NormalizeDouble(currentTick.bid,5)," nextSellPrice: ",NormalizeDouble(nextOpenPrice(sellObj),2), " SellProfit: ",NormalizeDouble(sellObj.getProfit(),2), " accSellLot: ",NormalizeDouble(sellObj.getAccLots(),2),
         "\nSpread: ",NormalizeDouble(currentTick.ask - currentTick.bid,6),
         "\nlastestBuyLotSize: ",   buyObj.getLastLot(), " lastestBuyGrid: ",    lastBuyGrid,  " lastestBuyTime: ", buyObj.getLastOpenTime(),  " buyStatus: ",buyObj.getStatus(),  " buySignal: ",   buySignal,
         "\nlastestSellLotSize: ",  sellObj.getLastLot()," lastestSellGrid: ",   lastSellGrid, " lastestSellTime: ",sellObj.getLastOpenTime(), " sellStatus", sellObj.getStatus(), " sellSignal: ",  sellSignal
         );
}

double nextOpenLot(ExpertAdvisor& bs){
   double nextLot = (bs.getLastLot()==0) ? InpLotSize : bs.getLastLot()*InpLotMultiply;
   return (nextLot > InpMaxLotSize) ? InpMaxLotSize : NormalizeDouble(nextLot,2);
}

double nextOpenPrice(ExpertAdvisor& bs){
   double lastOpenPrice = bs.getLastPrice();
   long type = bs.getType();
   if(lastOpenPrice==0){return (type==POSITION_TYPE_BUY) ? currentTick.ask : currentTick.bid;}
   
   double gridStep;
   
   if(type==POSITION_TYPE_BUY){
      gridStep = nextGridStep(bs, buyGridArr);
   }else{
      gridStep = nextGridStep(bs, sellGridArr);
   }
   return (type==POSITION_TYPE_BUY) ? lastOpenPrice - gridStep*Point() : lastOpenPrice + gridStep*Point();
}

void updateGridMap(ExpertAdvisor& bs, ulong& ticketGridArr[], double& gridArr[]){
   ulong ticketArr[];
   int sizeArr = bs.getTicketArr(ticketArr);
   double newGrid[]; 
   ArrayResize(newGrid,sizeArr);
   for(int i=0;i<ArraySize(ticketGridArr);i++){
      int idx = ArrayBsearch(ticketArr,ticketGridArr[i]);
      if( 0 <= idx && idx < sizeArr && ticketArr[idx] == ticketGridArr[i] ){
         newGrid[idx] = gridArr[i];
      }
   }
   ArrayFree(ticketGridArr);
   ArrayFree(gridArr);
   ArrayCopy(ticketGridArr,ticketArr,0,0);
   ArrayCopy(gridArr,newGrid,0,0);

}

double nextGridStep(ExpertAdvisor& bs, double& gridArr[]){
   double lastGrid = (ArraySize(gridArr)==0) ? 0 : gridArr[ArraySize(gridArr)-1];
   if(lastGrid==0){
      lastGrid = InpGridStep;
   }else if(lastGrid*InpGridMultiply > InpMaxGrid){
      lastGrid = InpMaxGrid;
   }else{
      lastGrid = (int)(lastGrid*InpGridMultiply);
   }
   return lastGrid;
}

datetime nextOpenTime(ExpertAdvisor& bs){
   return bs.getLastOpenTime() + InpPeriod;
}

bool CloseOrder(ExpertAdvisor& bs){
   if(bs.getStatus()){
      if(bs.getTicketCount() > InpMATicket){
         if(CloseOrderReduceDrawdown(bs)){
            CloseOrderMAOpen(bs);
            return true;
         }else{
            return false;
         }
      }else{
         return CloseOrderMAOpen(bs);
      }
   }
   return false;
}

bool CloseOrderMAOpen(ExpertAdvisor& bs){
   double profit = bs.getProfit();
   if(profit >= InpTakeProfit*InpLotSize){
      if(bs.closeAllOrders()){
         if(!InpOptimizeMode){Print( "MA type : ",bs.getType()," profit : ",profit );}
         return true;
      }else{
         Print("MA Close -> some bug");
      }
   }
   return false;
}

bool CloseOrderReduceDrawdown(ExpertAdvisor& bs){
   ulong ticketArr[];
   int staticSize = bs.getTicketArr(ticketArr);
   int realSize = bs.getTicketArr(ticketArr);
   if(realSize<=0){
      Print("close RDD : fail to get tickets");
      return false;
   }
   
   for(int i=0;i<(int)(bs.getTicketCount()/2);i++ ){
      if(realSize<=InpMATicket){
         return true;
      }
      double profit = bs.getProfitByIndex(i) + bs.getProfitByIndex(staticSize-1-i);
      if(profit >= InpTakeProfit*InpLotSize*((100+InpPercentTP)/100)){
         realSize -= bs.closeOrderByIndex(i)+bs.closeOrderByIndex(staticSize-1-i);
         if(!InpOptimizeMode){Print("ReduceDD : ",bs.getType()," | profit : ",profit," | profitDD : ",InpTakeProfit*InpLotSize*((100+InpPercentTP)/100));}
      }else{
         break;
      }
   }
   return false;
}

void UpdateIndicatorBuffer(){
   CopyBuffer( handleSto,MAIN_LINE,0,1,stoMainBuffer );
   CopyBuffer( handleSto,SIGNAL_LINE,0,1,stoSignalBuffer );

   CopyBuffer( handleRSI,MAIN_LINE,0,1,rsiBuffer );
   CopyBuffer( handleCCI,MAIN_LINE,0,1,cciBuffer );
   
   ArrayCopy( macdMainTempBuffer,macdMainBuffer );
   ArrayCopy( macdSignalTempBuffer,macdSignalBuffer );
   CopyBuffer( handleMACD,MAIN_LINE,0,1,macdMainBuffer );
   CopyBuffer( handleMACD,SIGNAL_LINE,0,1,macdSignalBuffer );
   
   CopyBuffer( handleHardSto,MAIN_LINE,0,1,hardStoMainBuffer );
   CopyBuffer( handleHardSto,SIGNAL_LINE,0,1,hardStoSignalBuffer );
}

void SignalByIndicator(){
   HardStoSignal();
   StoSignal();
   RSISignal();
   CCISignal();
   MACDSignal();
   buySignal = ( hardStoBuySignal || !InpHardStoActive ) && 
               ( stoBuySignal || !InpStoActive ) && 
               ( rsiBuySignal || !InpRSIActive ) && 
               ( cciBuySignal || !InpCCIActive ) &&
               ( macdBuySignal || !InpMACDActive );
   sellSignal = ( hardStoSellSignal || !InpHardStoActive ) && 
                ( stoSellSignal || !InpStoActive ) && 
                ( rsiSellSignal || !InpRSIActive ) && 
                ( cciSellSignal || !InpCCIActive ) && 
                ( macdSellSignal || !InpMACDActive );
}

void StoSignal(){
   stoBuySignal = true;
   stoSellSignal = true;
   
   if(stoMainBuffer[0] >= 50 + InpStoLevel || stoSignalBuffer[0] >= 50 + InpStoLevel ){
      stoBuySignal = false;
   }
   else if( stoMainBuffer[0] <= 50 - InpStoLevel || stoSignalBuffer[0] <= 50 - InpStoLevel ){
      stoSellSignal = false;
   }
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

void RSISignal(){
   rsiBuySignal = true;
   rsiSellSignal = true;
   if(rsiBuffer[0] >= InpRSILevel + 50){
      rsiBuySignal = false;
   }else if(rsiBuffer[0] <= 50 - InpRSILevel){
      rsiSellSignal = false;
   }
}

void HardStoSignal(){
   hardStoBuySignal = true;
   hardStoSellSignal = true;
   if( hardStoMainBuffer[0] >= 50+InpHardStoLevel || hardStoSignalBuffer[0] >= 50+InpHardStoLevel ){
      hardStoBuySignal = false;
   }else if( hardStoMainBuffer[0] <= 50-InpHardStoLevel || hardStoSignalBuffer[0] <= 50-InpHardStoLevel ){
      hardStoSellSignal = false;
   }
}

void CCISignal(){
   cciBuySignal = true;
   cciSellSignal = true;
   if(cciBuffer[0] >= InpCCILevel){
      cciBuySignal = false;
   }else if(cciBuffer[0] <= -InpCCILevel){
      cciSellSignal = false;
   }
}

bool IsNewBar(){
   static datetime previousTime = 0;
   datetime currentTime = iTime(_Symbol,PERIOD_H1,0);
   if(previousTime!=currentTime){
      previousTime = currentTime;
      return true;
   }
   return false;
}