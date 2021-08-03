//+------------------------------------------------------------------+
//|                                              MethodOptimizer.mq5 |
//|                                  Copyright 2021, Michal Machacek |
//|                                     https://github.com/mmachacek |
//+------------------------------------------------------------------+

#property copyright "Copyright 2021, Michal Machacek"
#property link      "https://github.com/mmachacek"
#property version   "1.00"
input string info0_2 = "openPriceBacktest - Prevents missing active orders during the open price backtest/optimalization";
input bool openPriceBacktest = false;
input string info0_3 = "moveToBE = 0 - disabled; X > 0 & X < 0.9 - Move to the breakeven when the price is close to the takeprofit by ex. X = 0.2 - 20% before takeprofit";
input double moveToBE = 0;
input double BETollerancePercentage = 0.05;
input string info0_4 = "OrderProtection = If an order doesn't get into a profit after X candle(s) after opening a market order";
input int orderProtection = 0;
input string info1 = "marketOrdersOnly = false - Only pending orders (limit and stop orders); true - Only market orders (buy and sell orders)";
input bool marketOrdersOnly = false;
input string info1_1 = "entryOn(only for pending orders) = ex. 0.1 = 10% of candle";
input double entryOn = 1.0;
input string info1_2 = "stoplossOn = ex. 0.1 = 10% of candle";
input double stoplossOn = 0.0;
input string info1_3 = "takeprofiRatio = 0 - No Takeprofit; X > 0 - Takeprofit by ratio 1:X";
input double takeprofitRatio = 1.0;
input string info1_4 = "trailingStop = 0 - Disabled; 1 - Previous HIGH/LOW on an X candle (X = trailingStopCandleShift); 2 - Moving Average;";
input int trailingStop = 0;
input string info1_4_1 = "trailingStopOnlyInProfit = false - On every new candle; true - On a new candle only in profit";
input bool trailingStopOnlyInProfit = false;
input int trailingStopCandleShift = 1;
input string info1_4_2_1 = "TrailingStop MA - tsMAPeriod = MA Period; tsMAShift = MA Shift";
input string info1_4_2_2 = "tsMAMethod = MA Method (0-3); tsMAAppliedPrice = MA Applied Price (0-6), if(2-HIGH or 3-LOW both are used)";
input string info1_4_2_3 = "tsMACandleShift = MA Shift X Candles; tsMACandleShiftAfterOpen = Apply MA trailing stop after X candles from open";
input int tsMAPeriod = 21;
input int tsMAShift = 0;
input int tsMAMethod = 0;
input int tsMAAppliedPrice = 0;
input int tsMACandleShift = 1;
input int tsMACandleShiftAfterOpen = 1;
input int startHour = 0;
input int endHour = 24;
input double Risk = 0.01;
input string info2 = "Slippage - ex. 5 means 0.5 points slippage on a 5 digit pair, and 5 points on 4 digit pair";
input int Slippage = 50;
input string info3 = "brokerCommision - 8.5 = 0.85 Points; 0 = Disabled";
input double brokerCommision = 5.5;
input bool entryWithSpread = true;
input int pendingExpirationShift = 1;
input int orderInQueueAttempts = 5;
input int orderInQueueSecondsDelay = 15;
input int EAMagicNumber = 5;
input bool bypassMaxLots = true;
input int bypassMaxLotsMagicNumber = 55;
input int bypassMaximumOrders = 100;
input string EAComment = "";
input bool closeOrdersBeforeMarketClose = false;
input bool closeOnlyLossOrdersBeforeMarketClose = false;
input bool closeOnlyProfitOrdersBeforeMarketClose = false;
input int marketCloseFridayHour = 20;
input int marketOpenHour = 1;
input bool preventOvernightTrading = false;
input bool closeOnlyOvernightLossOrders = false;
input bool closeOnlyOvernightProfitOrders = false;
input int preventOvernightTradingHour = 21;
input int enableAfterOvernightTradingHour = 1;
input string info12 = "tradeDaysFrom = 0 - Sunday; 1 - Monday; 2 - Tuesday; 3 - Wednesday; 4 - Thursday; 5 - Friday; 6 - Saturday";
input string info13 = "tradeDaysTo = 0 - Sunday; 1 - Monday; 2 - Tuesday; 3 - Wednesday; 4 - Thursday; 5 - Friday; 6 - Saturday";
input int tradeDaysFrom = 0;
input int tradeDaysTo = 6;
input string info4 = "Alert, Email";
input bool sendAlert = true;
input bool sendEmail = true;
input bool sendTerminalNotification = true;

MqlTradeRequest tradeReq = {};
MqlTradeResult tradeRes = {};
uint fileContentDirections[];
long bypassMaxOrders = 0;
ulong orderResult, exceededOrdersTickets[];
int count, queueCounter = 0, exceededLotsOrders = 0, lotBypassCommand, lotBypassQueueCounter = 0, bypassModifyQueueCounter = 0, bypassCloseQueueCounter = 0,
           modifyQueueCounter = 0, closeQueueCounter = 0, pendingOrderType;;
bool pendingOrderExists = false, marketOrderExists = false, pendingExists, marketExists, marketClosed = false,
     overnightBlocked = false, exceededMaxLots = false, bypassExists = false, bypassModifyQueue = false, bypassCloseQueue = false,
     closeQueue = false, modifyQueue = false, noTrading = false;
double tickSize, tickValue, lotStep, maximumLot, minimumLot, pointValue, tickValueFix, tsMABuy, tsMASell, lastExceededLots,
       stoploss, takeprofit, openprice, oLots, body, lowerWick, upperWick, lotBypassOpenprice, lotBypassStoploss, lotBypassTakeprofit,
       queueModifyStoploss = 0.0, commision = 0.0;
datetime barTime = 0, oExpiration, fileContent[], queueLastTime = 0, marketCloseEnabledTime = 0, overnightEnabledTime = 0,
         lotBypassLastTime = 0, lotBypassExpiration = 0, bypassModifyLastTime = 0, bypassCloseLastTime = 0, modifyLastTime = 0, closeLastTime = 0;
string queueCommand;

string signals = "2021.07.30 12:30:00/2021.07.30 17:30:00/2021.07.30 09:00:00/2021.08.02 20:12:00/2021.07.30 02:30:00/2021.08.02 13:00:00/";

string directions = "0/1/1/1/0/0/";

//+------------------------------------------------------------------+
//|Check if there is a match with generated signal                   |
//+------------------------------------------------------------------+
string checkForSignal()
  {

   for(int x=0; x<ArraySize(fileContent); x++)
     {
      if(iTime(NULL, 0, 1) == fileContent[x])
        {
         if(fileContentDirections[x] == 0)
           {
            return "SELL";
           }
         if(fileContentDirections[x] == 1)
           {
            return "BUY";
           }
        }
     }
   return "";
  }

//+------------------------------------------------------------------+
//|Prepare an order parameters based on the order type               |
//+------------------------------------------------------------------+
void prepareOrderParameters(string oType)
  {

   if(!marketOrdersOnly)
     {
      if(oType == "BUY")
        {
         oType = "PBUY";
        }
      if(oType == "SELL")
        {
         oType = "PSELL";
        }
     }

   if(pendingExpirationShift*(PeriodSeconds()/60) > 10)
     {
      oExpiration = iTime(NULL, 0, 0) + (pendingExpirationShift*PeriodSeconds());
     }
   else
     {
      oExpiration = 0;
     }

   if((oType == "BUY" || oType == "SELL") && !marketOrderExists)
     {
      prepareEntry(oType);
      prepareStoploss(oType);
      prepareTakeprofit(oType);
      calculateLots(oType);
      placeOrder(oType);
      return;
     }

   if((oType == "PBUY" || oType == "PSELL") && !marketOrderExists && !pendingOrderExists)
     {
      prepareEntry(oType);
      prepareStoploss(oType);
      prepareTakeprofit(oType);
      calculateLots(oType);
      placeOrder(oType);
      return;
     }


   return;
  }

//+------------------------------------------------------------------+
//|Check for trailing stop type                                      |
//+------------------------------------------------------------------+
void checkTrailingStop()
  {
   if(trailingStop == 1)
     {
      checkTSHL();
     }
   if(trailingStop == 2)
     {
      checkTSMA();
     }

   return;
  }

//+------------------------------------------------------------------+
//|Check the High/Low Trailing stop                                  |
//+------------------------------------------------------------------+
void checkTSHL()
  {
   if(!trailingStopCandleShift)
     {
      return;
     }
   if(PositionSelectByTicket(marketOrderTicket))
     {
      if(iTime(NULL, 0, 0) >= PositionGetInteger(POSITION_TIME) + PeriodSeconds() * trailingStopCandleShift)
        {
         if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL && iHigh(NULL, 0, trailingStopCandleShift) > SymbolInfoDouble(NULL, SYMBOL_BID))
           {
            if(PositionGetDouble(POSITION_SL) > iHigh(NULL, 0, trailingStopCandleShift) && iHigh(NULL, 0, trailingStopCandleShift) > PositionGetDouble(POSITION_TP))
              {
               if(trailingStopOnlyInProfit)
                 {
                  if(OrderProfit(PositionGetInteger(POSITION_TICKET)) > 0)
                    {
                     if(!OrderModifyPosition(PositionGetInteger(POSITION_TICKET), PositionGetDouble(POSITION_PRICE_OPEN), iHigh(NULL, 0, trailingStopCandleShift), PositionGetDouble(POSITION_TP), 0, clrGold))
                       {
                        if(!modifyQueue)
                           modifyQueue = !modifyQueue;
                        queueModifyStoploss = iHigh(NULL, 0, trailingStopCandleShift);
                        sendAlertEmailNotification("The trailing stop is unable to move the rstoploss to: " + (string)iHigh(NULL, 0, trailingStopCandleShift) + " the order, is now in queue");
                       }
                     else
                       {
                        modifyLotBypassOrders(iHigh(NULL, 0, trailingStopCandleShift));
                       }
                    }
                 }
               else
                 {
                  if(!OrderModifyPosition(PositionGetInteger(POSITION_TICKET), PositionGetDouble(POSITION_PRICE_OPEN), iHigh(NULL, 0, trailingStopCandleShift), PositionGetDouble(POSITION_TP), 0, clrGold))
                    {
                     if(!modifyQueue)
                        modifyQueue = !modifyQueue;
                     queueModifyStoploss = iHigh(NULL, 0, trailingStopCandleShift);
                     sendAlertEmailNotification("The trailing stop is unable to move the stoploss to: " + (string)iHigh(NULL, 0, trailingStopCandleShift) + " the order, is now in queue");
                    }
                  else
                    {
                     modifyLotBypassOrders(iHigh(NULL, 0, trailingStopCandleShift));
                    }
                 }
              }
           }

         if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY && iLow(NULL, 0, trailingStopCandleShift) < SymbolInfoDouble(NULL, SYMBOL_ASK))
           {
            if(PositionGetDouble(POSITION_SL) < iLow(NULL, 0, trailingStopCandleShift) && iLow(NULL, 0, trailingStopCandleShift) < PositionGetDouble(POSITION_TP))
              {
               if(trailingStopOnlyInProfit)
                 {
                  if(OrderProfit(PositionGetInteger(POSITION_TICKET)) > 0)
                    {
                     if(!OrderModifyPosition(PositionGetInteger(POSITION_TICKET), PositionGetDouble(POSITION_PRICE_OPEN), iLow(NULL, 0, trailingStopCandleShift), PositionGetDouble(POSITION_TP), 0, clrGold))
                       {
                        if(!modifyQueue)
                           modifyQueue = !modifyQueue;
                        queueModifyStoploss = iLow(NULL, 0, trailingStopCandleShift);
                        sendAlertEmailNotification("The trailing stop is unable to move the stoploss to: " + (string)iLow(NULL, 0, trailingStopCandleShift) + " the order, is now in queue");
                       }
                     else
                       {
                        modifyLotBypassOrders(iLow(NULL, 0, trailingStopCandleShift));
                       }
                    }
                 }
               else
                 {
                  if(!OrderModifyPosition(PositionGetInteger(POSITION_TICKET), PositionGetDouble(POSITION_PRICE_OPEN), iLow(NULL, 0, trailingStopCandleShift), PositionGetDouble(POSITION_TP), 0, clrGold))
                    {
                     if(!modifyQueue)
                        modifyQueue = !modifyQueue;
                     queueModifyStoploss = iLow(NULL, 0, trailingStopCandleShift);
                     sendAlertEmailNotification("The trailing stop is unable to move the stoploss to: " + (string)iLow(NULL, 0, trailingStopCandleShift) + " the order, is now in queue");
                    }
                  else
                    {
                     modifyLotBypassOrders(iLow(NULL, 0, trailingStopCandleShift));
                    }
                 }
              }
           }
        }
     }

   return;
  }

//+------------------------------------------------------------------+
//|Check the moving average trailing stop                            |
//+------------------------------------------------------------------+
void checkTSMA()
  {
   if(!tsMACandleShift || !tsMAPeriod || !tsMACandleShiftAfterOpen)
     {
      return;
     }

   if(PositionSelectByTicket(marketOrderTicket))
     {
      if(iTime(NULL, 0, 0) >= PositionGetInteger(POSITION_TIME) + PeriodSeconds() * tsMACandleShiftAfterOpen)
        {
         if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL && tsMASell > SymbolInfoDouble(NULL, SYMBOL_BID))
           {
            if(PositionGetDouble(POSITION_SL) > tsMASell && tsMASell > PositionGetDouble(POSITION_TP))
              {
               if(trailingStopOnlyInProfit)
                 {
                  if(OrderProfit(PositionGetInteger(POSITION_TICKET)) > 0)
                    {
                     if(!OrderModifyPosition(PositionGetInteger(POSITION_TICKET), PositionGetDouble(POSITION_PRICE_OPEN), tsMASell, PositionGetDouble(POSITION_TP), 0, clrGold))
                       {
                        if(!modifyQueue)
                           modifyQueue = !modifyQueue;
                        queueModifyStoploss = tsMASell;
                        sendAlertEmailNotification("The trailing stop is unable to move the stoploss to: " + (string)tsMASell + " the order, is now in queue");
                       }
                     else
                       {
                        modifyLotBypassOrders(tsMASell);
                       }
                    }
                 }
               else
                 {
                  if(!OrderModifyPosition(PositionGetInteger(POSITION_TICKET), PositionGetDouble(POSITION_PRICE_OPEN), tsMASell, PositionGetDouble(POSITION_TP), 0, clrGold))
                    {
                     if(!modifyQueue)
                        modifyQueue = !modifyQueue;
                     queueModifyStoploss = tsMASell;
                     sendAlertEmailNotification("The trailing stop is unable to move the stoploss to: " + (string)tsMASell + " the order, is now in queue");
                    }
                  else
                    {
                     modifyLotBypassOrders(tsMASell);
                    }
                 }
              }
           }

         if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY && tsMABuy < SymbolInfoDouble(NULL, SYMBOL_ASK))
           {
            if(PositionGetDouble(POSITION_SL) < tsMABuy && tsMABuy < PositionGetDouble(POSITION_TP))
              {
               if(trailingStopOnlyInProfit)
                 {
                  if(OrderProfit(PositionGetInteger(POSITION_TICKET)) > 0)
                    {
                     if(!OrderModifyPosition(PositionGetInteger(POSITION_TICKET), PositionGetDouble(POSITION_PRICE_OPEN), tsMABuy, PositionGetDouble(POSITION_TP), 0, clrGold))
                       {
                        if(!modifyQueue)
                           modifyQueue = !modifyQueue;
                        queueModifyStoploss = tsMABuy;
                        sendAlertEmailNotification("The trailing stop is unable to move the stoploss to: " + (string)tsMABuy + " the order, is now in queue");
                       }
                     else
                       {
                        modifyLotBypassOrders(tsMABuy);
                       }
                    }
                 }
               else
                 {
                  if(!OrderModifyPosition(PositionGetInteger(POSITION_TICKET), PositionGetDouble(POSITION_PRICE_OPEN), tsMABuy, PositionGetDouble(POSITION_TP), 0, clrGold))
                    {
                     if(!modifyQueue)
                        modifyQueue = !modifyQueue;
                     queueModifyStoploss = tsMABuy;
                     sendAlertEmailNotification("The trailing stop is unable to move the stoploss to: " + (string)tsMABuy + " the order, is now in queue");
                    }
                  else
                    {
                     modifyLotBypassOrders(tsMABuy);
                    }
                 }
              }
           }
        }
     }

   return;
  }

//+------------------------------------------------------------------+
//|Separate generated signals                                        |
//+------------------------------------------------------------------+
void prepareSignals()
  {
   string separatedSignals[];
   string separatedDirections[];
   if(StringSplit(signals, StringGetCharacter("/", 0), separatedSignals))
     {
      ArrayResize(separatedSignals, ArraySize(separatedSignals)-1);
      for(int i=0; i<ArraySize(separatedSignals); i++)
        {
         arrayPush((datetime)separatedSignals[i], fileContent);
        }
     }
   else
     {
      sendAlertEmailNotification("Unable to load signals");
     }
   if(StringSplit(directions, StringGetCharacter("/", 0), separatedDirections))
     {
      ArrayResize(separatedDirections, ArraySize(separatedDirections)-1);
      for(int i=0; i<ArraySize(separatedDirections); i++)
        {
         arrayPushUInt((uint)separatedDirections[i], fileContentDirections);
        }
     }
   else
     {
      sendAlertEmailNotification("Unable to load directions");
     }
   return;
  }

//+------------------------------------------------------------------+
//|Push value to an array                                            |
//+------------------------------------------------------------------+
void arrayPush(datetime inputValue, datetime &array[])
  {
   int c = ArrayResize(array, ArraySize(array)+1);
   array[ArraySize(array)-1] = inputValue;
   return;
  }

//+------------------------------------------------------------------+
//|Try an order/position in the queue                                |
//+------------------------------------------------------------------+
void checkQueue()
  {
   if(queueCounter && queueCounter <= orderInQueueAttempts && queueLastTime + orderInQueueSecondsDelay <= TimeCurrent())
     {
      Print("Order in queue attempt " + (string)queueCounter + " of " + (string)orderInQueueAttempts);
      placeOrder(queueCommand);

      queueLastTime = TimeCurrent();

      return;
     }

   if(queueCounter >= orderInQueueAttempts)
     {
      sendAlertEmailNotification("Unable to open the order in " + (string)orderInQueueAttempts + " attempts");
      queueCounter = 0;
     }

   if(modifyQueue)
     {
      queueModifyOrder();
     }
   if(closeQueue)
     {
      queueCloseOrder();
     }

   return;
  }

//+------------------------------------------------------------------+
//|Try to modify an order/position in the queue                      |
//+------------------------------------------------------------------+
void queueModifyOrder()
  {
   if(modifyQueueCounter < orderInQueueAttempts && modifyLastTime + orderInQueueSecondsDelay <= TimeCurrent())
     {
      ulong queueTicket = 0;
      int modifyErrorCounter = 0;
      for(int i=PositionsTotal()-1; i >= 0; i--)
        {
         if(PositionSelectByTicket(PositionGetTicket(i)))
           {
            if(PositionGetInteger(POSITION_MAGIC) == EAMagicNumber && PositionGetString(POSITION_SYMBOL) == Symbol() && queueModifyStoploss && PositionGetDouble(POSITION_SL) != queueModifyStoploss)
              {
               if((PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY && PositionGetDouble(POSITION_SL) >= queueModifyStoploss) || (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL && PositionGetDouble(POSITION_SL) <= queueModifyStoploss))
                 {
                  sendAlertEmailNotification("The position " + (string)PositionGetInteger(POSITION_TICKET) + " the stoploss is already modified or below modified value");
                  modifyQueueCounter = 0;
                  modifyLastTime = 0;
                  modifyQueue = false;
                  modifyLotBypassOrders(queueModifyStoploss);
                  queueTicket = PositionGetInteger(POSITION_TICKET);
                  return;
                 }
               if(!OrderModifyPosition(PositionGetInteger(POSITION_TICKET), PositionGetDouble(POSITION_PRICE_OPEN), queueModifyStoploss ? queueModifyStoploss : PositionGetDouble(POSITION_SL), PositionGetDouble(POSITION_TP), 0, clrWhite))
                 {
                  modifyErrorCounter++;
                  queueTicket = PositionGetInteger(POSITION_TICKET);
                 }
              }
           }
        }
      for(int i=OrdersTotal()-1; i >= 0; i--)
        {
         if(OrderSelect(i))
           {
            if(OrderGetInteger(ORDER_MAGIC) == EAMagicNumber && OrderGetString(ORDER_SYMBOL) == Symbol() && queueModifyStoploss && OrderGetDouble(ORDER_SL) != queueModifyStoploss)
              {
               if((OrderGetInteger(ORDER_TYPE) == ORDER_TYPE_BUY && OrderGetDouble(ORDER_SL) >= queueModifyStoploss) || (OrderGetInteger(ORDER_TYPE) == ORDER_TYPE_SELL && OrderGetDouble(ORDER_SL) <= queueModifyStoploss))
                 {
                  sendAlertEmailNotification("The order " + (string)OrderGetInteger(ORDER_TICKET) + " the stoploss is already modified or below modified value");
                  modifyQueueCounter = 0;
                  modifyLastTime = 0;
                  modifyQueue = false;
                  modifyLotBypassOrders(queueModifyStoploss);
                  queueTicket = OrderGetInteger(ORDER_TICKET);
                  return;
                 }
               if(!OrderModifyPosition(OrderGetInteger(ORDER_TICKET), OrderGetDouble(ORDER_PRICE_OPEN), queueModifyStoploss ? queueModifyStoploss : OrderGetDouble(ORDER_SL), OrderGetDouble(ORDER_TP), 0, clrWhite))
                 {
                  modifyErrorCounter++;
                  queueTicket = OrderGetInteger(ORDER_TICKET);
                 }
              }
           }
        }

      if(modifyErrorCounter)
        {
         modifyQueueCounter++;
         modifyLastTime = TimeCurrent();
         if(modifyQueueCounter == orderInQueueAttempts)
           {
            sendAlertEmailNotification("Unable to modify the order " + (string)queueTicket + " in queue, attempt " + (string)modifyQueueCounter + " of " + (string)orderInQueueAttempts);
            modifyQueueCounter = 0;
            modifyLastTime = 0;
            modifyQueue = false;
           }
         else
           {
            sendAlertEmailNotification("Unable to modify order " + (string)queueTicket + " in queue, attempt " + (string)modifyQueueCounter + " of " + (string)orderInQueueAttempts);
           }
        }
      else
        {
         modifyQueueCounter = 0;
         modifyLastTime = 0;
         modifyQueue = false;
         modifyLotBypassOrders(queueModifyStoploss);
        }
     }
   return;
  }

//+------------------------------------------------------------------+
//|Try to close an order/position in the queue                       |
//+------------------------------------------------------------------+
void queueCloseOrder()
  {
   if(closeQueueCounter < orderInQueueAttempts && closeLastTime + orderInQueueSecondsDelay <= TimeCurrent())
     {
      ulong queueTicket = 0;
      int closeErrorCounter = 0;
      for(int i=PositionsTotal()-1; i >= 0; i--)
        {
         if(PositionSelectByTicket(PositionGetTicket(i)))
           {
            if(PositionGetInteger(POSITION_MAGIC) == EAMagicNumber && PositionGetString(POSITION_SYMBOL) == Symbol())
              {
               if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY || PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL)
                 {
                  if(!OrderClose(PositionGetInteger(POSITION_TICKET), PositionGetDouble(POSITION_VOLUME), PositionGetDouble(POSITION_PRICE_CURRENT), Slippage, clrWhite))
                    {
                     closeErrorCounter++;
                     queueTicket = PositionGetInteger(POSITION_TICKET);
                    }
                 }
              }
           }
        }
      for(int i=OrdersTotal()-1; i >= 0; i--)
        {
         if(OrderSelect(i))
           {
            if(OrderGetInteger(ORDER_MAGIC) == EAMagicNumber && OrderGetString(ORDER_SYMBOL) == Symbol())
              {
               if(OrderGetInteger(ORDER_TYPE) == ORDER_TYPE_BUY || OrderGetInteger(ORDER_TYPE) == ORDER_TYPE_SELL)
                 {
                  if(!OrderDelete(OrderGetInteger(ORDER_TICKET), clrWhite))
                    {
                     closeErrorCounter++;
                     queueTicket = OrderGetInteger(ORDER_TICKET);
                    }
                 }
              }
           }
        }
      if(closeErrorCounter)
        {
         closeQueueCounter++;
         closeLastTime = TimeCurrent();
         sendAlertEmailNotification("Unable to close/delete order " + (string)queueTicket + " in queue, attempt " + (string)closeQueueCounter + " of " + (string)orderInQueueAttempts);
        }
      else
        {
         closeQueueCounter = 0;
         closeLastTime = 0;
         closeQueue = false;
         closeLotBypassOrders();
        }
     }
   return;
  }

//+------------------------------------------------------------------+
//|Check if today is the specified trading day                       |
//+------------------------------------------------------------------+
bool isTradeDay()
  {
   if(TimeDayOfWeekMQL4(iTime(NULL, 0, 0)) >= tradeDaysFrom && TimeDayOfWeekMQL4(iTime(NULL, 0, 0)) <= tradeDaysTo && tradeDaysFrom <= 6 && tradeDaysTo <= 6)
     {
      return true;
     }
   return false;
  }


ulong pendingOrderTicket, marketOrderTicket;

//+------------------------------------------------------------------+
//|Check the margin before opening an order to prevent insufficient  |
//|funds error                                                       |
//+------------------------------------------------------------------+
bool checkMargin(int orderType, double vol, double entry)
  {
   double freeMargin = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
   double margin = 1;
   bool ret = false;

   ret = OrderCalcMargin((ENUM_ORDER_TYPE)orderType, Symbol(), vol, entry, margin);

   if(freeMargin - margin <= 0.0 || !ret)
     {
      return false;
     }
   return true;
  }
//+------------------------------------------------------------------+
//|Get an actual close price for further calculations                |
//+------------------------------------------------------------------+
double OrderClosePrice(ulong ticket)
  {
   if(PositionSelectByTicket(ticket))
     {
      if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
        {
         return SymbolInfoDouble(Symbol(), SYMBOL_BID);
        }
      if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL)
        {
         return SymbolInfoDouble(Symbol(), SYMBOL_ASK);
        }
     }
   return 0.0;
  }

//+------------------------------------------------------------------+
//|Get an actual profit of an order for further calculations         |
//+------------------------------------------------------------------+
double OrderProfit(ulong ticket)
  {
   if(PositionSelectByTicket(ticket))
     {
      double open = PositionGetDouble(POSITION_PRICE_OPEN);
      double current = PositionGetDouble(POSITION_PRICE_CURRENT);
      if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
        {
         return current - open;
        }
      if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL)
        {
         return open - current;
        }
     }
   return 0.0;
  }

//+------------------------------------------------------------------+
//|Modify a position (an activated order) parameters                 |
//+------------------------------------------------------------------+
bool OrderModifyPosition(ulong ticket, double price, double sl, double tp, datetime expiry, color arrow)
  {
   ZeroMemory(tradeReq);
   ZeroMemory(tradeRes);
   if(PositionSelectByTicket(ticket))
     {
      tradeReq.action = TRADE_ACTION_SLTP;
      tradeReq.symbol = Symbol();
      tradeReq.sl = sl;
      tradeReq.tp = tp;
      tradeReq.position = ticket;
      if(OrderSend(tradeReq, tradeRes))
        {
         return true;
        }
     }
   return false;
  }

//+------------------------------------------------------------------+
//|Modify a pending order parameters                                 |
//+------------------------------------------------------------------+
bool OrderModifyPending(ulong ticket, double price, double sl, double tp, datetime expiry, color arrow)
  {
   ZeroMemory(tradeReq);
   ZeroMemory(tradeRes);
   if(OrderSelect(ticket))
     {
      tradeReq.action = TRADE_ACTION_MODIFY;
      tradeReq.order = ticket;
      tradeReq.price = price;
      tradeReq.sl = sl;
      tradeReq.tp = tp;
      if(expiry)
        {
         tradeReq.type_time = ORDER_TIME_SPECIFIED;
         tradeReq.expiration = expiry;
        }
      else
        {
         tradeReq.type_time = ORDER_TIME_SPECIFIED;
         tradeReq.expiration = 0;
        }
      if(OrderSend(tradeReq, tradeRes))
        {
         return true;
        }
     }
   return false;
  }

//+------------------------------------------------------------------+
//|Close an order (an activated order)                               |
//+------------------------------------------------------------------+
bool OrderClose(ulong ticket, double lots, double price, int slip, color arrow)
  {
   ZeroMemory(tradeReq);
   ZeroMemory(tradeRes);
   tradeReq.action = TRADE_ACTION_DEAL;
   tradeReq.position = ticket;
   tradeReq.symbol = Symbol();
   tradeReq.volume = lots;
   tradeReq.deviation = slip;
   tradeReq.magic = EAMagicNumber;
   tradeReq.type_filling = SymbolInfoInteger(_Symbol,SYMBOL_FILLING_MODE) == 1 ? ORDER_FILLING_FOK : SymbolInfoInteger(_Symbol,SYMBOL_FILLING_MODE) == 2 ? ORDER_FILLING_IOC : ORDER_FILLING_RETURN;
   if(PositionSelectByTicket(ticket))
     {
      if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
        {
         tradeReq.price = SymbolInfoDouble(Symbol(), SYMBOL_BID);
         tradeReq.type = ORDER_TYPE_SELL;
        }
      if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL)
        {
         tradeReq.price = SymbolInfoDouble(Symbol(), SYMBOL_ASK);
         tradeReq.type = ORDER_TYPE_BUY;
        }
      if(OrderSend(tradeReq, tradeRes))
        {
         return true;
        }
     }
   return false;
  }

//+------------------------------------------------------------------+
//|Delete a pending order                                            |
//+------------------------------------------------------------------+
bool OrderDelete(ulong ticket, color arrow = clrNONE)
  {
   ZeroMemory(tradeReq);
   ZeroMemory(tradeRes);
   tradeReq.action = TRADE_ACTION_REMOVE;
   tradeReq.order = ticket;
   if(OrderSend(tradeReq, tradeRes))
     {
      return true;
     }
   return false;
  }

//+------------------------------------------------------------------+
//|Open an order (an instant order or a pending order)               |
//+------------------------------------------------------------------+
ulong MQL4OrderSend(string symbol, int type, double volume, double price, int slip, double sl, double tp, string comment, int magic, datetime expiry, color arrow)
  {
   ZeroMemory(tradeReq);
   ZeroMemory(tradeRes);
   ulong orderTicket = 0, result;
   if(!StringLen(symbol))
      symbol = Symbol();
   if(type == 0 || type == 1)
     {
      tradeReq.action = TRADE_ACTION_DEAL;
     }
   else
     {
      tradeReq.action = TRADE_ACTION_PENDING;
     }
   tradeReq.magic = magic;
   tradeReq.symbol = Symbol();
   tradeReq.volume = volume;
   tradeReq.price = price;
   tradeReq.sl = stoploss;
   tradeReq.tp = takeprofit;
   tradeReq.deviation = slip;
   tradeReq.type_filling = SymbolInfoInteger(_Symbol,SYMBOL_FILLING_MODE) == 1 ? ORDER_FILLING_FOK : SymbolInfoInteger(_Symbol,SYMBOL_FILLING_MODE) == 2 ? ORDER_FILLING_IOC : ORDER_FILLING_RETURN;
   tradeReq.type = (ENUM_ORDER_TYPE)type;
   tradeReq.expiration = expiry;

   result = OrderSend(tradeReq, tradeRes);
   if(tradeRes.deal)
      orderTicket = tradeRes.deal;
   if(tradeRes.order)
      orderTicket = tradeRes.order;
   return orderTicket;
  }

//+------------------------------------------------------------------+
//|Get the hour from a datetime input                                |
//+------------------------------------------------------------------+
int TimeHourMQL4(datetime date)
  {
   MqlDateTime tm;
   TimeToStruct(date,tm);
   return(tm.hour);
  }

//+------------------------------------------------------------------+
//|Get the day of the week from a datetime input                     |
//+------------------------------------------------------------------+
int TimeDayOfWeekMQL4(datetime date)
  {
   MqlDateTime tm;
   TimeToStruct(date,tm);
   return(tm.day_of_week);
  }

//+------------------------------------------------------------------+
//|Initialization function                                           |
//+------------------------------------------------------------------+
int OnInit()
  {
   if(brokerCommision > 0)
     {
      commision = brokerCommision * SymbolInfoDouble(NULL, SYMBOL_TRADE_TICK_SIZE);
     }
   else
     {
      commision = 0;
     }
   if(bypassMaximumOrders > AccountInfoInteger(ACCOUNT_LIMIT_ORDERS))
     {
      bypassMaxOrders = AccountInfoInteger(ACCOUNT_LIMIT_ORDERS);
      sendAlertEmailNotification((string)bypassMaximumOrders + " exceeds broker maximum orders, limit is now set to maximum: " + (string)AccountInfoInteger(ACCOUNT_LIMIT_ORDERS));
     }
   else
     {
      bypassMaxOrders = bypassMaximumOrders;
     }
   checkPermissions();
   updateIndicators();
   prepareSignals();
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//|Deinitialization function                                         |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
  }


//+------------------------------------------------------------------+
//|Update moving averages                                            |
//+------------------------------------------------------------------+
void updateIndicators()
  {
   if(trailingStop > 0 && trailingStop < 3)
     {
      if(tsMAAppliedPrice == 2 || tsMAAppliedPrice == 3)
        {
         tsMABuy = iMAMQL4(NULL, 0, tsMAPeriod, tsMAShift, tsMAMethod, PRICE_LOW, tsMACandleShift);
         tsMASell = iMAMQL4(NULL, 0, tsMAPeriod, tsMAShift, tsMAMethod, PRICE_HIGH, tsMACandleShift);
        }
      else
        {
         tsMABuy = iMAMQL4(NULL, 0, tsMAPeriod, tsMAShift, tsMAMethod, tsMAAppliedPrice, tsMACandleShift);
         tsMASell = iMAMQL4(NULL, 0, tsMAPeriod, tsMAShift, tsMAMethod, tsMAAppliedPrice, tsMACandleShift);
        }
      tsMABuy = MathRound(tsMABuy/SymbolInfoDouble(NULL, SYMBOL_POINT))*SymbolInfoDouble(NULL, SYMBOL_POINT);
      tsMASell = MathRound(tsMASell/SymbolInfoDouble(NULL, SYMBOL_POINT))*SymbolInfoDouble(NULL, SYMBOL_POINT);
     }
  }

//+------------------------------------------------------------------+
//|Check if algo trading is allowed                                  |
//+------------------------------------------------------------------+
void checkPermissions()
  {
   if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED))
      Alert("The algo trading is not allowed");
   return;
  }

//+------------------------------------------------------------------+
//|Check for a new candle bar                                        |
//+------------------------------------------------------------------+
bool newBar()
  {
   if(barTime < iTime(NULL, 0, 0))
     {
      barTime = iTime(NULL, 0, 0);
      return true;
     }
   return false;
  }

//+------------------------------------------------------------------+
//|Check if now is the time to trade in specified time range         |
//+------------------------------------------------------------------+
bool isTradeTime()
  {
   if((TimeHourMQL4(iTime(NULL, 0, 0)) >= startHour) && (TimeHourMQL4(iTime(NULL, 0, 0)) <= endHour))
     {
      return true;
     }
   return false;
  }

//+------------------------------------------------------------------+
//|Get market values for further calculations                        |
//+------------------------------------------------------------------+
void getMarketValues()
  {
   tickSize = SymbolInfoDouble(NULL, SYMBOL_TRADE_TICK_SIZE);
   tickValue = SymbolInfoDouble(NULL, SYMBOL_TRADE_TICK_VALUE);
   lotStep = SymbolInfoDouble(NULL, SYMBOL_VOLUME_STEP);
   maximumLot = SymbolInfoDouble(NULL, SYMBOL_VOLUME_MAX);
   minimumLot = SymbolInfoDouble(NULL, SYMBOL_VOLUME_MIN);
   pointValue = SymbolInfoDouble(NULL, SYMBOL_POINT);
   tickValueFix = tickValue * pointValue / tickSize;
   return;
  }

//+------------------------------------------------------------------+
//|Send input string as an alert/e-mail/notification                 |
//+------------------------------------------------------------------+
void sendAlertEmailNotification(string message)
  {
   if(StringLen(message))
     {
      if(sendAlert)
        {
         Alert(Symbol(), (string)(PeriodSeconds()/60), " ", message);
        }
      if(sendEmail)
        {
         SendMail((string)AccountInfoInteger(ACCOUNT_LOGIN) + " " + Symbol() + (string)(PeriodSeconds()/60) + " " + message, message);
        }
      if(sendTerminalNotification)
        {
         SendNotification((string)AccountInfoInteger(ACCOUNT_LOGIN) + " " + Symbol() + (string)(PeriodSeconds()/60) + " " + message);
        }
     }
   else
     {
      Print("Error - the message is empty");
      return;
     }
   return;
  }

//+------------------------------------------------------------------+
//|Check if there are existing positions or orders                   |
//+------------------------------------------------------------------+
void checkForOrders()
  {
   pendingExists = false;
   marketExists = false;
   for(int i=OrdersTotal()-1; i >= 0; i--)
     {
      if(OrderSelect(OrderGetTicket(i)))
        {
         if(OrderGetString(ORDER_SYMBOL) == Symbol() && OrderGetInteger(ORDER_MAGIC) == EAMagicNumber)
           {
            if(OrderGetInteger(ORDER_TYPE) == ORDER_TYPE_BUY_LIMIT || OrderGetInteger(ORDER_TYPE) == ORDER_TYPE_BUY_STOP || OrderGetInteger(ORDER_TYPE) == ORDER_TYPE_SELL_LIMIT || OrderGetInteger(ORDER_TYPE) == ORDER_TYPE_SELL_STOP)
              {
               pendingExists = true;
               if(OrderGetInteger(ORDER_TIME_EXPIRATION) == 0)
                 {
                  if((iTime(NULL, 0, iBarShift(NULL, 0, OrderGetInteger(ORDER_TIME_SETUP), false)) + ((pendingExpirationShift-1)*PeriodSeconds())) < iTime(NULL, 0, 0))
                    {
                     if(!OrderDelete(OrderGetInteger(ORDER_TICKET)))
                       {
                        sendAlertEmailNotification("Unable to delete the pending order " + (string)OrderGetInteger(ORDER_TICKET) + " , is now in queue");
                        if(!closeQueue)
                           closeQueue = true;
                        queueLastTime = TimeCurrent();
                       }
                     else
                       {
                        pendingExists = false;
                        if(pendingOrderExists)
                          {
                           pendingOrderExists = !pendingOrderExists;
                           pendingOrderTicket = NULL;
                           checkForLotBypassOrders();
                           closeLotBypassOrders();
                           if(!bypassExists)
                             {
                              if(exceededMaxLots)
                                {
                                 exceededMaxLots = !exceededMaxLots;
                                 if(exceededLotsOrders)
                                    exceededLotsOrders = 0;
                                }
                             }
                          }
                       }
                    }
                 }
               if(pendingExists)
                 {
                  pendingOrderExists = true;
                  pendingOrderTicket = OrderGetInteger(ORDER_TICKET);
                  if(queueCounter)
                    {
                     queueCounter = 0;
                    }
                 }
              }
           }
        }
     }

   if(PositionSelect(Symbol()))
     {
      if(PositionGetInteger(POSITION_MAGIC) == EAMagicNumber)
        {
         if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY || PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL)
           {
            marketExists = true;
            marketOrderExists = true;
            marketOrderTicket = PositionGetInteger(POSITION_TICKET);
            if(queueCounter)
              {
               queueCounter = 0;
              }
            if(orderProtection > 0)
               checkOrderProtection();
            if(moveToBE > 0 && moveToBE < 0.9)
               checkMoveToBE();
           }
        }
     }




   if(!pendingExists)
     {
      if(pendingOrderExists)
        {
         pendingOrderExists = false;
         pendingOrderTicket = NULL;
         if(!marketOrderExists)
           {
            checkForLotBypassOrders();
            closeLotBypassOrders();
            if(!bypassExists)
              {
               if(exceededMaxLots)
                 {
                  exceededMaxLots = !exceededMaxLots;
                  if(exceededLotsOrders)
                     exceededLotsOrders = 0;
                 }
              }
           }
        }
     }

   if(!marketExists)
     {
      marketOrderExists = false;
      marketOrderTicket = NULL;
      if(!pendingOrderExists)
        {
         checkForLotBypassOrders();
         closeLotBypassOrders();
         if(!bypassExists)
           {
            if(exceededMaxLots)
              {
               exceededMaxLots = !exceededMaxLots;
               if(exceededLotsOrders)
                  exceededLotsOrders = 0;
              }
           }
        }
     }

   return;
  }

//+------------------------------------------------------------------+
//|Check if an order does not have a potentional to be profitable    |
//+------------------------------------------------------------------+
void checkOrderProtection()
  {
   if(PositionSelectByTicket(marketOrderTicket))
     {
      if(iTime(NULL, 0, iBarShift(NULL, 0, PositionGetInteger(POSITION_TIME))) + PeriodSeconds() * orderProtection < TimeCurrent() &&
         iTime(NULL, 0, iBarShift(NULL, 0, PositionGetInteger(POSITION_TIME))) + PeriodSeconds() * orderProtection + PeriodSeconds() > TimeCurrent())
        {
         if(((double)OrderProfit(PositionGetInteger(POSITION_TICKET))) < 0)
           {
            if(OrderClose(marketOrderTicket, PositionGetDouble(POSITION_VOLUME), PositionGetDouble(POSITION_PRICE_CURRENT), Slippage, clrGold))
              {
               sendAlertEmailNotification("OrderProtection has closed the order");
               marketOrderExists = false;
               marketOrderTicket = NULL;
              }
            else
              {
               sendAlertEmailNotification("OrderProtection cannot close the order " + (string)PositionGetInteger(POSITION_TICKET) + " with error: " + (string)GetLastError() + " order, is now in queue");
               if(!closeQueue)
                  closeQueue = !closeQueue;
              }
           }
        }
     }
   return;
  }

//+------------------------------------------------------------------+
//|Move the stoploss to the breakeven before the takeprofit is       |
//|triggered                                                         |
//+------------------------------------------------------------------+
void checkMoveToBE()
  {
   if(!modifyQueue)
     {
      if(PositionSelectByTicket(marketOrderTicket))
        {
         double newStoploss = 0.0;
         if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY && PositionGetDouble(POSITION_SL) < PositionGetDouble(POSITION_PRICE_OPEN))
           {
            if(PositionGetDouble(POSITION_PRICE_CURRENT) >= PositionGetDouble(POSITION_TP) - (PositionGetDouble(POSITION_TP) - PositionGetDouble(POSITION_PRICE_OPEN)) * moveToBE)
              {
               if(PositionGetDouble(POSITION_PRICE_OPEN) + (PositionGetDouble(POSITION_PRICE_OPEN) - PositionGetDouble(POSITION_SL)) * BETollerancePercentage > PositionGetDouble(POSITION_SL))
                 {
                  newStoploss = PositionGetDouble(POSITION_PRICE_OPEN) + (PositionGetDouble(POSITION_PRICE_OPEN) - PositionGetDouble(POSITION_SL)) * BETollerancePercentage;
                  newStoploss = MathRound(newStoploss/tickSize)*tickSize;
                  if(!OrderModifyPosition(PositionGetInteger(POSITION_TICKET), PositionGetDouble(POSITION_PRICE_OPEN), newStoploss, PositionGetDouble(POSITION_TP), 0, clrGold))
                    {
                     if(!modifyQueue)
                        modifyQueue = !modifyQueue;
                     queueModifyStoploss = newStoploss;
                     sendAlertEmailNotification("Unable to move the stoploss to the BE on the order with error: " + (string)GetLastError() + " the order, is now in queue");
                    }
                  else
                    {
                     sendAlertEmailNotification("Stoploss has been moved to the BE");
                     modifyLotBypassOrders(newStoploss);
                    }
                 }
              }
           }
         if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL && PositionGetDouble(POSITION_SL) > PositionGetDouble(POSITION_PRICE_OPEN))
           {
            if(PositionGetDouble(POSITION_PRICE_CURRENT) <= PositionGetDouble(POSITION_TP) + (PositionGetDouble(POSITION_PRICE_OPEN) - PositionGetDouble(POSITION_TP)) * moveToBE)
              {
               if(PositionGetDouble(POSITION_PRICE_OPEN) - (PositionGetDouble(POSITION_SL) - PositionGetDouble(POSITION_PRICE_OPEN)) * BETollerancePercentage < PositionGetDouble(POSITION_SL))
                 {
                  newStoploss = PositionGetDouble(POSITION_PRICE_OPEN) - (PositionGetDouble(POSITION_SL) - PositionGetDouble(POSITION_PRICE_OPEN)) * BETollerancePercentage;
                  newStoploss = MathRound(newStoploss/tickSize)*tickSize;
                  if(!OrderModifyPosition(PositionGetInteger(POSITION_TICKET), PositionGetDouble(POSITION_PRICE_OPEN), newStoploss, PositionGetDouble(POSITION_TP), 0, clrGold))
                    {
                     if(!modifyQueue)
                        modifyQueue = !modifyQueue;
                     queueModifyStoploss = newStoploss;
                     sendAlertEmailNotification("Unable to move the stoploss to the BE on the order with error: " + (string)GetLastError() + " the order, is now in queue");
                    }
                  else
                    {
                     sendAlertEmailNotification("Stoploss has been moved to the BE");
                     modifyLotBypassOrders(newStoploss);
                    }
                 }
              }
           }
        }
     }
   return;
  }

//+------------------------------------------------------------------+
//|Calculate lots for an order or a position                         |
//+------------------------------------------------------------------+
void calculateLots(string oType)
  {

   if(oType == "SELL" || oType == "PSELL")
     {

      if(entryWithSpread)
        {
         stoploss = stoploss + (SymbolInfoInteger(NULL, SYMBOL_SPREAD) * SymbolInfoDouble(NULL, SYMBOL_TRADE_TICK_SIZE));
        }
      oLots = (MathFloor(((AccountInfoDouble(ACCOUNT_BALANCE) * Risk) / (((MathAbs(openprice - stoploss - commision) / tickSize) * tickValueFix))) / lotStep) * lotStep);

      if(oLots > maximumLot)
        {
         if(bypassMaxLots)
           {
            exceededMaxLots = true;
            exceededLotsOrders = (int)MathFloor(oLots / maximumLot);
            lastExceededLots = MathMod(oLots, maximumLot);
            lastExceededLots = MathRound(lastExceededLots/minimumLot)*minimumLot;
            if(!lastExceededLots)
               lastExceededLots = minimumLot;
            oLots = maximumLot;
           }
         else
           {
            oLots = maximumLot;
           }
        }

      if(oLots < minimumLot)
         oLots = minimumLot;
     }
   if(oType == "BUY" || oType == "PBUY")
     {

      if(entryWithSpread)
        {
         stoploss = stoploss - (SymbolInfoInteger(NULL, SYMBOL_SPREAD) * SymbolInfoDouble(NULL, SYMBOL_TRADE_TICK_SIZE));
        }

      oLots = (MathFloor(((AccountInfoDouble(ACCOUNT_BALANCE) * Risk) / (((MathAbs(openprice - stoploss - commision) / tickSize) * tickValueFix))) / lotStep) * lotStep);
      if(oLots > maximumLot)
        {
         if(bypassMaxLots)
           {
            exceededMaxLots = true;
            exceededLotsOrders = (int)MathFloor(oLots / maximumLot);
            lastExceededLots = MathMod(oLots, maximumLot);
            lastExceededLots = MathRound(lastExceededLots/minimumLot)*minimumLot;
            oLots = maximumLot;
           }
         else
           {
            oLots = maximumLot;
           }
        }
      if(oLots < minimumLot)
         oLots = minimumLot;
     }

   oLots = MathRound(oLots/minimumLot)*minimumLot;
   return;
  }

//+------------------------------------------------------------------+
//|Calculate the stoploss for an order or a position                 |
//+------------------------------------------------------------------+
void prepareStoploss(string oType)
  {
   if(oType == "BUY" || oType == "PBUY")
     {

      if(stoplossOn == entryOn || stoplossOn == 0 || entryOn == 0)
        {
         if(entryWithSpread)
           {
            stoploss = iLow(NULL, 0, 1) - SymbolInfoInteger(NULL, SYMBOL_SPREAD) * pointValue;
            stoploss = MathRound(stoploss/pointValue)*pointValue;
           }
         else
           {
            stoploss = iLow(NULL, 0, 1);
           }
        }
      else
         if(stoplossOn < entryOn)
           {
            if(entryWithSpread)
              {
               stoploss = iHigh(NULL, 0, 1) - (iHigh(NULL, 0, 1)-iLow(NULL, 0, 1))*entryOn - SymbolInfoInteger(NULL, SYMBOL_SPREAD) * pointValue;
               stoploss = MathRound(stoploss/pointValue)*pointValue;
              }
            else
              {
               stoploss = iHigh(NULL, 0, 1) - (iHigh(NULL, 0, 1)-iLow(NULL, 0, 1))*entryOn;
              }
           }
         else
           {
            if(entryWithSpread)
              {
               stoploss = iHigh(NULL, 0, 1) - (iHigh(NULL, 0, 1)-iLow(NULL, 0, 1))*stoplossOn - SymbolInfoInteger(NULL, SYMBOL_SPREAD) * pointValue;
               stoploss = MathRound(stoploss/pointValue)*pointValue;
              }
            else
              {
               stoploss = iHigh(NULL, 0, 1) - (iHigh(NULL, 0, 1)-iLow(NULL, 0, 1))*stoplossOn;
              }
           }

      return;
     }

   if(oType == "SELL" || oType == "PSELL")
     {

      if(stoplossOn == entryOn || stoplossOn == 0 || entryOn == 0)
        {
         if(entryWithSpread)
           {
            stoploss = iHigh(NULL, 0, 1) + SymbolInfoInteger(NULL, SYMBOL_SPREAD) * pointValue;
            stoploss = MathRound(stoploss/pointValue)*pointValue;
           }
         else
           {
            stoploss = iHigh(NULL, 0, 1);
           }
        }
      else
         if(stoplossOn < entryOn)
           {
            if(entryWithSpread)
              {
               stoploss = iLow(NULL, 0, 1) + (iHigh(NULL, 0, 1)-iLow(NULL, 0, 1))*entryOn + SymbolInfoInteger(NULL, SYMBOL_SPREAD) * pointValue;
               stoploss = MathRound(stoploss/pointValue)*pointValue;
              }
            else
              {
               stoploss = iLow(NULL, 0, 1) + (iHigh(NULL, 0, 1)-iLow(NULL, 0, 1))*entryOn;
              }
           }
         else
           {
            if(entryWithSpread)
              {
               stoploss = iLow(NULL, 0, 1) + (iHigh(NULL, 0, 1)-iLow(NULL, 0, 1))*stoplossOn + SymbolInfoInteger(NULL, SYMBOL_SPREAD) * pointValue;
               stoploss = MathRound(stoploss/pointValue)*pointValue;
              }
            else
              {
               stoploss = iLow(NULL, 0, 1) + (iHigh(NULL, 0, 1)-iLow(NULL, 0, 1))*stoplossOn;
              }
           }

      return;
     }

   return;
  }

//+------------------------------------------------------------------+
//|Calculate the takeprofit for an order or a position               |
//+------------------------------------------------------------------+
void prepareTakeprofit(string oType)
  {

   if(oType == "BUY" || oType == "PBUY")
     {

      if(takeprofitRatio > 0)
        {
         if(entryWithSpread)
           {
            takeprofit = openprice + (openprice - stoploss) * takeprofitRatio + SymbolInfoInteger(NULL, SYMBOL_SPREAD) * pointValue;
            takeprofit = MathRound(takeprofit/pointValue)*pointValue;
           }
         else
           {
            takeprofit = openprice + (openprice - stoploss) * takeprofitRatio;
            takeprofit = MathRound(takeprofit/pointValue)*pointValue;
           }
        }

      return;
     }

   if(oType == "SELL" || oType == "PSELL")
     {
      if(takeprofitRatio > 0)
        {
         if(entryWithSpread)
           {
            takeprofit = openprice - (stoploss - openprice) * takeprofitRatio - SymbolInfoInteger(NULL, SYMBOL_SPREAD) * pointValue;
            takeprofit = MathRound(takeprofit/pointValue)*pointValue;
           }
         else
           {
            takeprofit = openprice - (stoploss - openprice) * takeprofitRatio;
            takeprofit = MathRound(takeprofit/pointValue)*pointValue;
           }

         if(takeprofit < 0)
            takeprofit = 0;
        }

      return;
     }

   return;
  }

//+------------------------------------------------------------------+
//|Calculate the entry price for an order or a position              |
//+------------------------------------------------------------------+
void prepareEntry(string oType)
  {

   if(oType == "BUY")
     {
      openprice = SymbolInfoDouble(NULL, SYMBOL_ASK);
      return;
     }

   if(oType == "SELL")
     {
      openprice = SymbolInfoDouble(NULL, SYMBOL_BID);;
      return;
     }


   if(oType == "PBUY")
     {

      if(stoplossOn == entryOn || stoplossOn == 0 || entryOn == 0)
        {
         openprice = iHigh(NULL, 0, 1);
        }
      else
         if(stoplossOn < entryOn)
           {
            openprice = iLow(NULL, 0, 1) + (iHigh(NULL, 0, 1)-iLow(NULL, 0, 1))*stoplossOn;
            openprice = MathRound(openprice/pointValue)*pointValue;
           }
         else
           {
            openprice = iLow(NULL, 0, 1) + (iHigh(NULL, 0, 1)-iLow(NULL, 0, 1))*entryOn;
            openprice = MathRound(openprice/pointValue)*pointValue;
           }

      return;
     }

   if(oType == "PSELL")
     {

      if(stoplossOn == entryOn || stoplossOn == 0 || entryOn == 0)
        {
         openprice = iLow(NULL, 0, 1);
        }
      else
         if(stoplossOn < entryOn)
           {
            openprice = iHigh(NULL, 0, 1) - (iHigh(NULL, 0, 1)-iLow(NULL, 0, 1))*stoplossOn;
            openprice = MathRound(openprice/pointValue)*pointValue;
           }
         else
           {
            openprice = iHigh(NULL, 0, 1) - (iHigh(NULL, 0, 1)-iLow(NULL, 0, 1))*entryOn;
            openprice = MathRound(openprice/pointValue)*pointValue;
           }

      return;
     }

   return;
  }

//+------------------------------------------------------------------+
//|Place an order or a position                                      |
//+------------------------------------------------------------------+
void placeOrder(string oType)
  {
   int exceededOrdersCounter;
   int tempexceededLotsOrders;
   if(oType == "PBUY")
     {

      if(openprice < SymbolInfoDouble(NULL, SYMBOL_ASK))
        {
         pendingOrderType = 2;
        }
      else
        {
         pendingOrderType = 4;
        }

      if(!pendingOrderExists)
        {
         if(!checkMargin(pendingOrderType, oLots, openprice))
           {
            sendAlertEmailNotification("Not enough money to open the order");
            return;
           }
         orderResult = MQL4OrderSend(Symbol(), pendingOrderType, oLots, openprice, Slippage, stoploss, takeprofit, EAComment, EAMagicNumber, oExpiration, clrBlue);
         if(!orderResult)
           {
            if(!queueCounter)
              {
               sendAlertEmailNotification("The position is in queue");
              }
            queueCounter++;
            queueCommand = oType;
            queueLastTime = TimeCurrent();
           }
         if(orderResult)
           {
            if(exceededLotsOrders)
              {
               orderResult = 0;
               exceededOrdersCounter = 1;
               tempexceededLotsOrders = exceededLotsOrders;
               while(exceededLotsOrders)
                 {
                  if(exceededLotsOrders == 1)
                    {
                     if(!checkMargin(pendingOrderType, lastExceededLots, openprice))
                       {
                        sendAlertEmailNotification("Not enough money to open the last exceeded order");
                        exceededLotsOrders = 0;
                        return;
                       }
                     orderResult = MQL4OrderSend(Symbol(), pendingOrderType, lastExceededLots, openprice, Slippage, stoploss, takeprofit, EAComment, bypassMaxLotsMagicNumber, oExpiration, clrBlue);
                    }
                  else
                    {
                     if(!checkMargin(pendingOrderType, oLots, openprice))
                       {
                        sendAlertEmailNotification("Not enough money to open the exceeded order");
                        exceededLotsOrders = 0;
                        return;
                       }
                     orderResult = MQL4OrderSend(Symbol(), pendingOrderType, oLots, openprice, Slippage, stoploss, takeprofit, EAComment, bypassMaxLotsMagicNumber, oExpiration, clrBlue);
                    }

                  if(orderResult)
                    {
                     pushIntToArray(orderResult, exceededOrdersTickets);
                     exceededLotsOrders--;
                     if(bypassMaxOrders > 0 && bypassMaxOrders <= tempexceededLotsOrders)
                       {
                        exceededOrdersCounter++;
                       }
                    }
                  if(!orderResult)
                    {
                     lotBypassOpenprice = openprice;
                     lotBypassStoploss = stoploss;
                     lotBypassTakeprofit = takeprofit;
                     lotBypassExpiration  = oExpiration;
                     lotBypassCommand = pendingOrderType;
                     break;
                    }
                  if(exceededOrdersCounter >= bypassMaxOrders)
                    {
                     exceededLotsOrders = 0;
                     break;
                    }
                 }
               if(ArraySize(exceededOrdersTickets))
                 {
                  if(!bypassExists)
                     bypassExists = !bypassExists;
                 }
               if(exceededLotsOrders)
                 {
                  lotBypassLastTime = TimeCurrent();
                 }
              }
           }
        }
      return;
     }
   if(oType == "PSELL")
     {

      if(openprice < SymbolInfoDouble(NULL, SYMBOL_BID))
        {
         pendingOrderType = 5;
        }
      else
        {
         pendingOrderType = 3;
        }

      if(!pendingOrderExists)
        {
         if(!checkMargin(pendingOrderType, oLots, openprice))
           {
            sendAlertEmailNotification("Not enough money to open the order");
            return;
           }
         orderResult = MQL4OrderSend(Symbol(), pendingOrderType, oLots, openprice, Slippage, stoploss, takeprofit, EAComment, EAMagicNumber, oExpiration, clrBlue);
         if(!orderResult)
           {
            if(!queueCounter)
              {
               sendAlertEmailNotification("The position is in queue");
              }
            queueCounter++;
            queueCommand = oType;
            queueLastTime = TimeCurrent();
           }
         if(orderResult)
           {
            if(exceededLotsOrders)
              {
               orderResult = 0;
               exceededOrdersCounter = 1;
               tempexceededLotsOrders = exceededLotsOrders;
               while(exceededLotsOrders)
                 {
                  if(exceededLotsOrders == 1)
                    {
                     if(!checkMargin(pendingOrderType, lastExceededLots, openprice))
                       {
                        sendAlertEmailNotification("Not enough money to open the last exceeded order");
                        exceededLotsOrders = 0;
                        return;
                       }
                     orderResult = MQL4OrderSend(Symbol(), pendingOrderType, lastExceededLots, openprice, Slippage, stoploss, takeprofit, EAComment, bypassMaxLotsMagicNumber, oExpiration, clrBlue);
                    }
                  else
                    {
                     if(!checkMargin(pendingOrderType, oLots, openprice))
                       {
                        sendAlertEmailNotification("Not enough money to open the exceeded order");
                        exceededLotsOrders = 0;
                        return;
                       }
                     orderResult = MQL4OrderSend(Symbol(), pendingOrderType, oLots, openprice, Slippage, stoploss, takeprofit, EAComment, bypassMaxLotsMagicNumber, oExpiration, clrBlue);
                    }

                  if(orderResult)
                    {
                     pushIntToArray(orderResult, exceededOrdersTickets);
                     exceededLotsOrders--;
                     if(bypassMaxOrders > 0 && bypassMaxOrders <= tempexceededLotsOrders)
                       {
                        exceededOrdersCounter++;
                       }
                    }
                  if(!orderResult)
                    {
                     lotBypassOpenprice = openprice;
                     lotBypassStoploss = stoploss;
                     lotBypassTakeprofit = takeprofit;
                     lotBypassExpiration = oExpiration;
                     lotBypassCommand = pendingOrderType;
                     break;
                    }
                  if(exceededOrdersCounter >= bypassMaxOrders)
                    {
                     exceededLotsOrders = 0;
                     break;
                    }
                 }
               if(ArraySize(exceededOrdersTickets))
                 {
                  if(!bypassExists)
                     bypassExists = !bypassExists;
                 }
               if(exceededLotsOrders)
                 {
                  lotBypassLastTime = TimeCurrent();
                 }
              }
           }
        }
      return;
     }

   if(oType == "BUY")
     {
      if(!marketOrderExists)
        {
         if(!checkMargin(0, oLots, SymbolInfoDouble(NULL, SYMBOL_ASK)))
           {
            sendAlertEmailNotification("Not enough money to open the order");
            return;
           }
         orderResult = MQL4OrderSend(Symbol(), ORDER_TYPE_BUY, oLots, SymbolInfoDouble(NULL, SYMBOL_ASK), Slippage, stoploss, takeprofit, EAComment, EAMagicNumber, 0, clrBlue);
         if(!orderResult)
           {
            if(!queueCounter)
              {
               sendAlertEmailNotification("The position is in queue");
              }
            queueCounter++;
            queueCommand = oType;
            queueLastTime = TimeCurrent();
           }
         if(orderResult)
           {
            if(exceededLotsOrders)
              {
               orderResult = 0;
               exceededOrdersCounter = 1;
               tempexceededLotsOrders = exceededLotsOrders;
               while(exceededLotsOrders)
                 {
                  if(exceededLotsOrders == 1)
                    {
                     if(!checkMargin(0, lastExceededLots, SymbolInfoDouble(NULL, SYMBOL_ASK)))
                       {
                        sendAlertEmailNotification("Not enough money to open the last exceeded order");
                        exceededLotsOrders = 0;
                        return;
                       }
                     orderResult = MQL4OrderSend(Symbol(), ORDER_TYPE_BUY, lastExceededLots, SymbolInfoDouble(NULL, SYMBOL_ASK), Slippage, stoploss, takeprofit, EAComment, bypassMaxLotsMagicNumber, oExpiration, clrBlue);
                    }
                  else
                    {
                     if(!checkMargin(0, oLots, SymbolInfoDouble(NULL, SYMBOL_ASK)))
                       {
                        sendAlertEmailNotification("Not enough money to open the exceeded order");
                        exceededLotsOrders = 0;
                        return;
                       }
                     orderResult = MQL4OrderSend(Symbol(), ORDER_TYPE_BUY, oLots, SymbolInfoDouble(NULL, SYMBOL_ASK), Slippage, stoploss, takeprofit, EAComment, bypassMaxLotsMagicNumber, oExpiration, clrBlue);
                    }

                  if(orderResult)
                    {
                     pushIntToArray(orderResult, exceededOrdersTickets);
                     exceededLotsOrders--;
                     if(bypassMaxOrders > 0 && bypassMaxOrders <= tempexceededLotsOrders)
                       {
                        exceededOrdersCounter++;
                       }
                    }

                  if(!orderResult)
                    {
                     lotBypassOpenprice = openprice;
                     lotBypassStoploss = stoploss;
                     lotBypassTakeprofit = takeprofit;
                     lotBypassExpiration = oExpiration;
                     lotBypassCommand = pendingOrderType;
                     break;
                    }
                  if(exceededOrdersCounter >= bypassMaxOrders)
                    {
                     exceededLotsOrders = 0;
                     break;
                    }
                 }
               if(ArraySize(exceededOrdersTickets))
                 {
                  if(!bypassExists)
                     bypassExists = !bypassExists;
                 }
               if(exceededLotsOrders)
                 {
                  lotBypassLastTime = TimeCurrent();
                 }
              }
           }
        }
      return;
     }
   if(oType == "SELL")
     {
      if(!marketOrderExists)
        {
         if(!checkMargin(0, oLots, SymbolInfoDouble(NULL, SYMBOL_BID)))
           {
            sendAlertEmailNotification("Not enough money to open the order");
            return;
           }
         orderResult = MQL4OrderSend(Symbol(), ORDER_TYPE_SELL, oLots, SymbolInfoDouble(NULL, SYMBOL_BID), Slippage, stoploss, takeprofit, EAComment, EAMagicNumber, 0, clrRed);
         if(!orderResult)
           {
            if(!queueCounter)
              {
               sendAlertEmailNotification("The position in queue");
              }
            queueCounter++;
            queueCommand = oType;
            queueLastTime = TimeCurrent();
           }
         if(orderResult)
           {
            if(exceededLotsOrders)
              {
               orderResult = 0;
               exceededOrdersCounter = 1;
               tempexceededLotsOrders = exceededLotsOrders;
               while(exceededLotsOrders)
                 {
                  if(exceededLotsOrders == 1)
                    {
                     if(!checkMargin(0, lastExceededLots, SymbolInfoDouble(NULL, SYMBOL_BID)))
                       {
                        sendAlertEmailNotification("Not enough money to open the last exceeded order");
                        exceededLotsOrders = 0;
                        return;
                       }
                     orderResult = MQL4OrderSend(Symbol(), ORDER_TYPE_SELL, lastExceededLots, SymbolInfoDouble(NULL, SYMBOL_BID), Slippage, stoploss, takeprofit, EAComment, bypassMaxLotsMagicNumber, oExpiration, clrBlue);
                    }
                  else
                    {
                     if(!checkMargin(0, oLots, SymbolInfoDouble(NULL, SYMBOL_BID)))
                       {
                        sendAlertEmailNotification("Not enough money to open the exceeded order");
                        exceededLotsOrders = 0;
                        return;
                       }
                     orderResult = MQL4OrderSend(Symbol(), ORDER_TYPE_SELL, oLots, openprice, Slippage, stoploss, takeprofit, EAComment, bypassMaxLotsMagicNumber, oExpiration, clrBlue);
                    }
                  if(orderResult)
                    {
                     pushIntToArray(orderResult, exceededOrdersTickets);
                     exceededLotsOrders--;
                     if(bypassMaxOrders > 0 && bypassMaxOrders <= tempexceededLotsOrders)
                       {
                        exceededOrdersCounter++;
                       }
                    }
                  if(!orderResult)
                    {
                     lotBypassOpenprice = openprice;
                     lotBypassStoploss = stoploss;
                     lotBypassTakeprofit = takeprofit;
                     lotBypassExpiration = oExpiration;
                     lotBypassCommand = pendingOrderType;
                     break;
                    }
                  if(exceededOrdersCounter >= bypassMaxOrders)
                    {
                     exceededLotsOrders = 0;
                     break;
                    }
                 }
               if(ArraySize(exceededOrdersTickets))
                 {
                  if(!bypassExists)
                     bypassExists = !bypassExists;
                 }
               if(exceededLotsOrders)
                 {
                  lotBypassLastTime = TimeCurrent();
                 }
              }
           }

        }
      return;
     }

   return;
  }


//+------------------------------------------------------------------+
//|Check for the market close and possibly close orders/positions    |
//|before the market close                                           |
//+------------------------------------------------------------------+
void checkMarketClose()
  {
   if(closeOrdersBeforeMarketClose)
     {
      datetime dailyTime = iTime(NULL, PERIOD_D1, 0);
      if(TimeDayOfWeekMQL4(TimeCurrent()) == 5)
        {
         if(!marketClosed)
           {
            if(dailyTime + marketCloseFridayHour * 3600 <= TimeCurrent())
              {
               marketClosed = true;
               marketCloseEnabledTime = dailyTime;
               if(marketExists)
                 {
                  if(PositionSelectByTicket(marketOrderTicket))
                    {
                     if((closeOnlyLossOrdersBeforeMarketClose && OrderProfit(PositionGetInteger(POSITION_TICKET)) <= 0) || (closeOnlyProfitOrdersBeforeMarketClose && OrderProfit(PositionGetInteger(POSITION_TICKET)) > 0) || (!closeOnlyProfitOrdersBeforeMarketClose && !closeOnlyLossOrdersBeforeMarketClose))
                       {
                        if(!OrderClose(PositionGetInteger(POSITION_TICKET), PositionGetDouble(POSITION_VOLUME), OrderClosePrice(PositionGetInteger(POSITION_TICKET)), Slippage, clrLime))
                          {
                           sendAlertEmailNotification("Unable to close the market order " + (string)PositionGetInteger(POSITION_TICKET) + " before market close with error: " + (string)GetLastError() + " order, is now in queue");
                           if(!closeQueue)
                              closeQueue = !closeQueue;
                          }
                        else
                          {
                           sendAlertEmailNotification("The market order has been closed before market close");
                           marketExists = false;
                           marketOrderTicket = 0;
                           closeLotBypassOrders();
                          }
                       }
                    }
                 }
               if(pendingExists)
                 {
                  if(OrderSelect(pendingOrderTicket))
                    {
                     if(!OrderDelete(OrderGetInteger(ORDER_TICKET), clrLime))
                       {
                        sendAlertEmailNotification("Unable to close the market order " + (string)OrderGetInteger(ORDER_TICKET) + " before market close with error: " + (string)GetLastError() + " order, is now in queue");
                        if(!closeQueue)
                           closeQueue = !closeQueue;
                       }
                     else
                       {
                        sendAlertEmailNotification("The pending order has been deleted before market close");
                        pendingExists = false;
                        pendingOrderTicket = 0;
                        closeLotBypassOrders();
                       }
                    }
                 }
              }
           }
         return;
        }

      if(marketClosed && marketCloseEnabledTime + 1440 * 3 * 60 + marketOpenHour * 3600 <= TimeCurrent())
        {
         marketClosed = false;
        }
     }

   return;
  }

//+------------------------------------------------------------------+
//|Prevent trading overnight                                         |
//+------------------------------------------------------------------+
void checkOvernightTrading()
  {
   if(preventOvernightTrading)
     {
      datetime dailyTime = iTime(NULL, PERIOD_D1, 0);
      if(!marketClosed && !overnightBlocked)
        {
         if(dailyTime + preventOvernightTradingHour * 3600 <= TimeCurrent() && !overnightBlocked)
           {
            overnightBlocked = true;
            overnightEnabledTime = dailyTime;
            if(marketExists)
              {
               if(PositionSelectByTicket(marketOrderTicket))
                 {
                  if((closeOnlyOvernightLossOrders && OrderProfit(PositionGetInteger(POSITION_TICKET)) <= 0) || (closeOnlyOvernightProfitOrders && OrderProfit(PositionGetInteger(POSITION_TICKET)) > 0) || (!closeOnlyOvernightProfitOrders && !closeOnlyOvernightLossOrders))
                    {
                     if(!OrderClose(PositionGetInteger(POSITION_TICKET), PositionGetDouble(POSITION_VOLUME), OrderClosePrice(PositionGetInteger(POSITION_TICKET)), Slippage, clrLime))
                       {
                        sendAlertEmailNotification("Unable to close the market order " + (string)PositionGetInteger(POSITION_TICKET) + " to prevent overnight trading with error: " + (string)GetLastError() + " order, is now in queue");
                        if(!closeQueue)
                           closeQueue = !closeQueue;
                       }
                     else
                       {
                        sendAlertEmailNotification("The market order has been closed to prevent overnight trading");
                        marketExists = false;
                        marketOrderTicket = 0;
                        closeLotBypassOrders();
                       }
                    }
                 }
              }
            if(pendingExists)
              {
               if(OrderSelect(pendingOrderTicket))
                 {
                  if(!OrderDelete(OrderGetInteger(ORDER_TICKET), clrLime))
                    {
                     sendAlertEmailNotification("Unable to close the market order " + (string)OrderGetInteger(ORDER_TICKET) + " to prevent overnight trading with error: " + (string)GetLastError() + " order, is now in queue");
                     if(!closeQueue)
                        closeQueue = !closeQueue;
                    }
                  else
                    {
                     sendAlertEmailNotification("The pending order has been deleted to prevent overnight trading");
                     pendingExists = false;
                     pendingOrderTicket = 0;
                     closeLotBypassOrders();
                    }
                 }
              }
           }
         return;
        }

      if(overnightBlocked && overnightEnabledTime + 1440 * 60 + enableAfterOvernightTradingHour * 3600 <= TimeCurrent())
        {
         overnightBlocked = false;
         return;
        }
     }

   return;
  }

//+------------------------------------------------------------------+
//|Push an unsigned long to an array                                 |
//+------------------------------------------------------------------+
void pushIntToArray(ulong inputValue, ulong &array[])
  {
   int c = ArrayResize(array, ArraySize(array)+1);
   array[ArraySize(array)-1] = inputValue;
   return;
  }

//+------------------------------------------------------------------+
//|Push an unsigned int to an array                                  |
//+------------------------------------------------------------------+
void arrayPushUInt(uint inputValue, uint &array[])
  {
   int c = ArrayResize(array, ArraySize(array)+1);
   array[ArraySize(array)-1] = inputValue;
   return;
  }

//+------------------------------------------------------------------+
//|Put bypass maximum lots orders/positions in the queue             |
//+------------------------------------------------------------------+
void checkLotBypassQueue()
  {
   if(bypassMaxLots)
     {
      if(exceededLotsOrders)
        {
         int bypassOrderCounter = 0;
         if(marketOrderExists)
           {
            for(int i=PositionsTotal()-1; i >= 0; i--)
              {
               if(PositionSelectByTicket(PositionGetTicket(i)))
                 {
                  if(PositionGetInteger(POSITION_MAGIC) == bypassMaxLotsMagicNumber && PositionGetString(POSITION_SYMBOL) == Symbol())
                    {
                     bypassOrderCounter++;
                    }
                 }
              }
           }

         if(pendingOrderExists)
           {
            for(int i=OrdersTotal()-1; i >= 0; i--)
              {
               if(OrderSelect(i))
                 {
                  if(OrderGetInteger(ORDER_MAGIC) == bypassMaxLotsMagicNumber && OrderGetString(ORDER_SYMBOL) == Symbol())
                    {
                     bypassOrderCounter++;
                    }
                 }
              }
           }
         if(bypassOrderCounter != exceededLotsOrders)
           {
            if(bypassExists)
               bypassExists = !bypassExists;
            openLotBypassOrders();
            return;
           }
         else
           {
            bypassExists = true;
            exceededLotsOrders = 0;
            lotBypassOpenprice = 0.0;
            lotBypassStoploss = 0.0;
            lotBypassTakeprofit = 0.0;
            lotBypassExpiration = 0;
            lotBypassCommand = NULL;
            lotBypassLastTime = 0;
            lastExceededLots = 0.0;
            lotBypassQueueCounter = 0;
            return;
           }
        }
      if(bypassModifyQueue)
        {
         queueModifyLotBypassOrders();
        }
      if(bypassCloseQueue)
        {
         queueCloseLotBypassOrders();
        }
     }
   return;
  }

//+------------------------------------------------------------------+
//|Open bypass maximum lots orders/positions                         |
//+------------------------------------------------------------------+
void openLotBypassOrders()
  {
   if(lotBypassQueueCounter < orderInQueueAttempts && lotBypassLastTime + orderInQueueSecondsDelay <= TimeCurrent())
     {
      int bypassOrdersCounter = 0;
      if(lotBypassCommand == 0 || lotBypassCommand == 1)
        {
         for(int i=PositionsTotal()-1; i >= 0; i--)
           {
            if(PositionSelectByTicket(PositionGetTicket(i)))
              {
               if(PositionGetInteger(POSITION_MAGIC) == bypassMaxLotsMagicNumber)
                 {
                  bypassOrdersCounter++;
                 }
              }
           }
        }
      else
        {
         for(int i=OrdersTotal()-1; i >= 0; i--)
           {
            if(OrderSelect(i))
              {
               if(OrderGetInteger(ORDER_MAGIC) == bypassMaxLotsMagicNumber)
                 {
                  bypassOrdersCounter++;
                 }
              }
           }
        }

      while(exceededLotsOrders)
        {
         if(exceededLotsOrders == 1)
           {
            orderResult = MQL4OrderSend(NULL, lotBypassCommand, lastExceededLots, lotBypassOpenprice, Slippage, lotBypassStoploss, lotBypassTakeprofit, NULL, bypassMaxLotsMagicNumber, lotBypassExpiration, clrMagenta);
            if(orderResult >= 0)
              {
               pushIntToArray(orderResult, exceededOrdersTickets);
               exceededLotsOrders--;
               if(bypassMaxOrders > 0 && bypassMaxOrders <= bypassOrdersCounter)
                 {
                  bypassOrdersCounter++;
                 }
              }
            else
              {
               break;
              }
           }
         else
           {
            orderResult = MQL4OrderSend(NULL, lotBypassCommand, maximumLot, lotBypassOpenprice, Slippage, lotBypassStoploss, lotBypassTakeprofit, NULL, bypassMaxLotsMagicNumber, lotBypassExpiration, clrMagenta);
            if(orderResult >= 0)
              {
               pushIntToArray(orderResult, exceededOrdersTickets);
               exceededLotsOrders--;
               if(bypassMaxOrders > 0 && bypassMaxOrders <= bypassOrdersCounter)
                 {
                  bypassOrdersCounter++;
                 }
              }
            else
              {
               break;
              }
           }

         if(bypassOrdersCounter >= bypassMaxOrders)
           {
            break;
           }

        }
      lotBypassQueueCounter++;
      lotBypassLastTime = TimeCurrent();
     }
   return;
  }

//+------------------------------------------------------------------+
//|Modify bypass maximum lots orders/positions in the queue          |
//+------------------------------------------------------------------+
void queueModifyLotBypassOrders()
  {
   if(bypassModifyQueueCounter < orderInQueueAttempts && bypassModifyLastTime + orderInQueueSecondsDelay <= TimeCurrent())
     {
      ulong queueTicket = 0;
      int modifyErrorCounter = 0;
      for(int i=PositionsTotal()-1; i >= 0; i--)
        {
         if(PositionSelectByTicket(PositionGetTicket(i)))
           {
            if(PositionGetInteger(POSITION_MAGIC) == bypassMaxLotsMagicNumber && PositionGetString(POSITION_SYMBOL) == Symbol() && queueModifyStoploss && PositionGetDouble(POSITION_SL) != queueModifyStoploss)
              {
               if((PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY && PositionGetDouble(POSITION_SL) >= queueModifyStoploss) || (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL && PositionGetDouble(POSITION_SL) <= queueModifyStoploss))
                 {
                  sendAlertEmailNotification("The position " + (string)PositionGetInteger(POSITION_TICKET) + " the stoploss is already modified or below modified value");
                  modifyQueueCounter = 0;
                  modifyLastTime = 0;
                  modifyQueue = false;
                  modifyLotBypassOrders(queueModifyStoploss);
                  queueTicket = PositionGetInteger(POSITION_TICKET);
                  return;
                 }

               if(!OrderModifyPosition(PositionGetInteger(POSITION_TICKET), PositionGetDouble(POSITION_PRICE_OPEN), queueModifyStoploss ? queueModifyStoploss : PositionGetDouble(POSITION_SL), PositionGetDouble(POSITION_TP), 0, clrWhite))
                 {
                  modifyErrorCounter++;
                  queueTicket = PositionGetInteger(POSITION_TICKET);
                 }
              }
           }
        }
      for(int i=OrdersTotal()-1; i >= 0; i--)
        {
         if(OrderSelect(i))
           {
            if(OrderGetInteger(ORDER_MAGIC) == bypassMaxLotsMagicNumber && OrderGetString(ORDER_SYMBOL) == Symbol() && queueModifyStoploss && OrderGetDouble(ORDER_SL) != queueModifyStoploss)
              {
               if((OrderGetInteger(ORDER_TYPE) == ORDER_TYPE_BUY && OrderGetDouble(ORDER_SL) >= queueModifyStoploss) || (OrderGetInteger(ORDER_TYPE) == ORDER_TYPE_SELL && OrderGetDouble(ORDER_SL) <= queueModifyStoploss))
                 {
                  sendAlertEmailNotification("The order " + (string)OrderGetInteger(ORDER_TICKET) + " the stoploss is already modified or below modified value");
                  modifyQueueCounter = 0;
                  modifyLastTime = 0;
                  modifyQueue = false;
                  modifyLotBypassOrders(queueModifyStoploss);
                  queueTicket = OrderGetInteger(ORDER_TICKET);
                  return;
                 }

               if(!OrderModifyPosition(OrderGetInteger(ORDER_TICKET), OrderGetDouble(ORDER_PRICE_OPEN), queueModifyStoploss ? queueModifyStoploss : OrderGetDouble(ORDER_SL), OrderGetDouble(ORDER_TP), 0, clrWhite))
                 {
                  modifyErrorCounter++;
                  queueTicket = OrderGetInteger(ORDER_TICKET);
                 }
              }
           }
        }

      if(modifyErrorCounter)
        {
         bypassModifyQueueCounter++;
         bypassModifyLastTime = TimeCurrent();
         if(bypassModifyQueueCounter == orderInQueueAttempts)
           {
            sendAlertEmailNotification("Unable to modify the order " + (string)queueTicket + " in queue, attempt " + (string)bypassModifyQueueCounter + " of " + (string)orderInQueueAttempts);
            bypassModifyQueueCounter = 0;
            bypassModifyLastTime = 0;
            bypassModifyQueue = false;
           }
         else
           {
            sendAlertEmailNotification("Unable to modify the order " + (string)queueTicket + " in queue, attempt " + (string)bypassModifyQueueCounter + " of " + (string)orderInQueueAttempts);
           }
        }
      else
        {
         bypassModifyQueueCounter = 0;
         bypassModifyLastTime = 0;
         bypassModifyQueue = false;
         queueModifyStoploss = 0.0;
        }
     }
   return;
  }

//+------------------------------------------------------------------+
//|Close bypass maximum lots orders/positions in the queue           |
//+------------------------------------------------------------------+
void queueCloseLotBypassOrders()
  {
   if(bypassCloseQueueCounter < orderInQueueAttempts && bypassCloseLastTime + orderInQueueSecondsDelay <= TimeCurrent())
     {
      ulong queueTicket = 0;
      int closeErrorCounter = 0;
      for(int i=OrdersTotal()-1; i >= 0; i--)
        {
         if(OrderSelect(i))
           {
            if(OrderGetInteger(ORDER_TICKET) == bypassMaxLotsMagicNumber)
              {
               if(OrderGetInteger(ORDER_TYPE) != ORDER_TYPE_BUY_LIMIT || OrderGetInteger(ORDER_TYPE) != ORDER_TYPE_BUY_STOP || OrderGetInteger(ORDER_TYPE) != ORDER_TYPE_SELL_STOP || OrderGetInteger(ORDER_TYPE) != ORDER_TYPE_SELL_LIMIT)
                 {
                  if(!OrderDelete(OrderGetInteger(ORDER_TICKET), clrWhite))
                    {
                     closeErrorCounter++;
                     queueTicket = OrderGetInteger(ORDER_TICKET);
                    }
                 }
              }
           }
        }
      for(int i=PositionsTotal()-1; i >= 0; i--)
        {
         if(PositionSelectByTicket(PositionGetTicket(i)))
           {
            if(PositionGetInteger(POSITION_MAGIC) == bypassMaxLotsMagicNumber)
              {
               if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY || PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL)
                 {
                  if(!OrderClose(PositionGetInteger(POSITION_TICKET), PositionGetDouble(POSITION_VOLUME), OrderClosePrice(OrderGetInteger(ORDER_TICKET)), Slippage, clrWhite))
                    {
                     closeErrorCounter++;
                     queueTicket = PositionGetInteger(POSITION_TICKET);
                    }
                 }
              }
           }
        }

      if(closeErrorCounter)
        {
         bypassCloseQueueCounter++;
         bypassCloseLastTime = TimeCurrent();
         sendAlertEmailNotification("Unable to close/delete order " + (string)queueTicket + " in queue, attempt " + (string)bypassModifyQueueCounter + " of " + (string)orderInQueueAttempts);
        }
      else
        {
         bypassCloseQueueCounter = 0;
         bypassCloseLastTime = 0;
         bypassCloseQueue = false;
        }
     }
   return;
  }

//+------------------------------------------------------------------+
//|Modify bypass maximum lots orders/positions                       |
//+------------------------------------------------------------------+
void modifyLotBypassOrders(double sl = 0.0)
  {
   if(ArraySize(exceededOrdersTickets) && bypassExists)
     {
      int modifyErrorCounter = 0;
      for(int i=0; i<ArraySize(exceededOrdersTickets); i++)
        {
         if(OrderSelect(exceededOrdersTickets[i]))
           {
            if(!OrderModifyPending(OrderGetInteger(ORDER_TICKET), OrderGetDouble(ORDER_PRICE_OPEN), sl ? sl : OrderGetDouble(ORDER_SL), OrderGetDouble(ORDER_TP), OrderGetInteger(ORDER_TIME_EXPIRATION), clrGold))
              {
               sendAlertEmailNotification("Unable to modify the exceeded lots " + (string)OrderGetInteger(ORDER_TICKET) + " the order is in queue ");
               modifyErrorCounter++;
              }
           }
         if(PositionSelectByTicket(exceededOrdersTickets[i]))
           {
            if(!OrderModifyPosition(PositionGetInteger(POSITION_TICKET), PositionGetDouble(POSITION_PRICE_OPEN), sl ? sl : PositionGetDouble(POSITION_SL), PositionGetDouble(POSITION_TP), 0, clrGold))
              {
               sendAlertEmailNotification("Unable to modify the exceeded lots " + (string)PositionGetInteger(POSITION_TICKET) + " the order is in queue ");
               modifyErrorCounter++;
              }
           }
        }

      if(modifyErrorCounter)
        {
         if(!bypassModifyQueue)
            bypassModifyQueue = !bypassModifyQueue;
         queueModifyStoploss = sl;
        }
     }
   else
     {
      if(bypassExists)
         bypassExists = !bypassExists;
      ArrayFree(exceededOrdersTickets);
     }
   return;
  }

//+------------------------------------------------------------------+
//|Close bypass lots orders/positions                                |
//+------------------------------------------------------------------+
void closeLotBypassOrders()
  {
   if(bypassExists && ArraySize(exceededOrdersTickets))
     {
      int closeErrorCounter = 0;
      for(int i=0; i<ArraySize(exceededOrdersTickets); i++)
        {
         if(OrderSelect(exceededOrdersTickets[i]))
           {
            if(OrderGetInteger(ORDER_TYPE) != ORDER_TYPE_BUY_LIMIT || OrderGetInteger(ORDER_TYPE) != ORDER_TYPE_BUY_STOP || OrderGetInteger(ORDER_TYPE) != ORDER_TYPE_SELL_LIMIT || OrderGetInteger(ORDER_TYPE) != ORDER_TYPE_SELL_STOP)
              {
               if(!OrderDelete(OrderGetInteger(ORDER_TICKET), clrWhite))
                 {
                  sendAlertEmailNotification("Unable to delete the exceeded lots " + (string)OrderGetInteger(ORDER_TICKET) + " the order, is now in queue ");
                  closeErrorCounter++;
                  if(!bypassCloseQueue)
                     bypassCloseQueue = !bypassCloseQueue;
                  return;
                 }
              }
           }
         if(PositionSelectByTicket(exceededOrdersTickets[i]))
           {
            if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY || PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL)
              {
               if(!OrderClose(PositionGetInteger(POSITION_TICKET), PositionGetDouble(POSITION_VOLUME), OrderClosePrice(PositionGetInteger(POSITION_TICKET)), Slippage, clrWhite))
                 {
                  sendAlertEmailNotification("Unable to close the exceeded lots " + (string)PositionGetInteger(POSITION_TICKET) + " the order, is now in queue ");
                  closeErrorCounter++;
                  if(!bypassCloseQueue)
                     bypassCloseQueue = !bypassCloseQueue;
                  return;
                 }
              }
           }
        }
      if(!closeErrorCounter)
        {
         bypassExists = false;
         ArrayFree(exceededOrdersTickets);
         if(bypassCloseQueue)
            bypassCloseQueue = !bypassCloseQueue;
        }
      else
        {
         bypassCloseLastTime = TimeCurrent();
        }
     }
   return;
  }

//+------------------------------------------------------------------+
//|Check if bypass maximum lots orders/positions exists              |
//+------------------------------------------------------------------+
void checkForLotBypassOrders()
  {
   ulong existingBypassOrders[], c;
   for(int i=OrdersTotal()-1; i >= 0; i--)
     {
      if(OrderSelect(i))
        {
         if(OrderGetInteger(ORDER_TICKET) == bypassMaxLotsMagicNumber && OrderGetString(ORDER_SYMBOL) == Symbol())
           {
            pushIntToArray(OrderGetInteger(ORDER_TICKET), existingBypassOrders);
           }
        }
     }
   for(int i=PositionsTotal()-1; i >= 0; i--)
     {
      if(PositionSelectByTicket(PositionGetTicket(i)))
        {
         if(PositionGetInteger(POSITION_MAGIC) == bypassMaxLotsMagicNumber && PositionGetString(POSITION_SYMBOL) == Symbol())
           {
            pushIntToArray(PositionGetInteger(POSITION_TICKET), existingBypassOrders);
           }
        }
     }
   if(ArraySize(existingBypassOrders))
     {
      if(ArraySize(exceededOrdersTickets))
        {
         ArrayFree(exceededOrdersTickets);
         c = ArrayCopy(exceededOrdersTickets, existingBypassOrders);
         if(!bypassExists)
            bypassExists = !bypassExists;
         return;
        }
      else
        {
         c = ArrayCopy(exceededOrdersTickets, existingBypassOrders);
         if(!bypassExists)
            bypassExists = !bypassExists;
         return;
        }
     }
   else
     {
      if(!bypassExists)
         bypassExists = !bypassExists;
      return;
     }
   return;
  }

//+------------------------------------------------------------------+
//|On every price tick                                               |
//+------------------------------------------------------------------+
void OnTick()
  {
   if(!noTrading)
     {
      checkForLotBypassOrders();
      checkForOrders();
      checkQueue();
      checkMarketClose();
      checkOvernightTrading();
      checkLotBypassQueue();
      if(isTradeTime() && isTradeDay())
        {
         getMarketValues();
         if(newBar())
           {
            updateIndicators();
            if(trailingStop && marketOrderExists)
              {
               checkTrailingStop();
              }
            prepareOrderParameters(checkForSignal());
            if(openPriceBacktest)
              {
               checkForOrders();
              }
           }
        }
     }
  }

//+------------------------------------------------------------------+
//|MQL4 Timeframe wrapper|
//+------------------------------------------------------------------+
ENUM_TIMEFRAMES TFMigrate(int tf)
  {
   switch(tf)
     {
      case 0:
         return(PERIOD_CURRENT);
      case 1:
         return(PERIOD_M1);
      case 5:
         return(PERIOD_M5);
      case 15:
         return(PERIOD_M15);
      case 30:
         return(PERIOD_M30);
      case 60:
         return(PERIOD_H1);
      case 240:
         return(PERIOD_H4);
      case 1440:
         return(PERIOD_D1);
      case 10080:
         return(PERIOD_W1);
      case 43200:
         return(PERIOD_MN1);

      case 2:
         return(PERIOD_M2);
      case 3:
         return(PERIOD_M3);
      case 4:
         return(PERIOD_M4);
      case 6:
         return(PERIOD_M6);
      case 10:
         return(PERIOD_M10);
      case 12:
         return(PERIOD_M12);
      case 16385:
         return(PERIOD_H1);
      case 16386:
         return(PERIOD_H2);
      case 16387:
         return(PERIOD_H3);
      case 16388:
         return(PERIOD_H4);
      case 16390:
         return(PERIOD_H6);
      case 16392:
         return(PERIOD_H8);
      case 16396:
         return(PERIOD_H12);
      case 16408:
         return(PERIOD_D1);
      case 32769:
         return(PERIOD_W1);
      case 49153:
         return(PERIOD_MN1);
      default:
         return(PERIOD_CURRENT);
     }
  }

//+------------------------------------------------------------------+
//|MQL4 MA Method wrapper                                            |
//+------------------------------------------------------------------+
ENUM_MA_METHOD MethodMigrate(int method)
  {
   switch(method)
     {
      case 0:
         return(MODE_SMA);
      case 1:
         return(MODE_EMA);
      case 2:
         return(MODE_SMMA);
      case 3:
         return(MODE_LWMA);
      default:
         return(MODE_SMA);
     }
  }
//+------------------------------------------------------------------+
//|MQL4 Price wrapper                                                |
//+------------------------------------------------------------------+
ENUM_APPLIED_PRICE PriceMigrate(int price)
  {
   switch(price)
     {
      case 1:
         return(PRICE_CLOSE);
      case 2:
         return(PRICE_OPEN);
      case 3:
         return(PRICE_HIGH);
      case 4:
         return(PRICE_LOW);
      case 5:
         return(PRICE_MEDIAN);
      case 6:
         return(PRICE_TYPICAL);
      case 7:
         return(PRICE_WEIGHTED);
      default:
         return(PRICE_CLOSE);
     }
  }
//+------------------------------------------------------------------+
//|MQL4 Stochastic field wrapper                                     |
//+------------------------------------------------------------------+
ENUM_STO_PRICE StoFieldMigrate(int field)
  {
   switch(field)
     {
      case 0:
         return(STO_LOWHIGH);
      case 1:
         return(STO_CLOSECLOSE);
      default:
         return(STO_LOWHIGH);
     }
  }
//+------------------------------------------------------------------+
enum ALLIGATOR_MODE  { MODE_GATORJAW=1,   MODE_GATORTEETH, MODE_GATORLIPS };
enum ADX_MODE        { MODE_MAIN,         MODE_PLUSDI, MODE_MINUSDI };
enum UP_LOW_MODE     { MODE_BASE,         MODE_UPPER,      MODE_LOWER };
enum ICHIMOKU_MODE   { MODE_TENKANSEN=1,  MODE_KIJUNSEN, MODE_SENKOUSPANA, MODE_SENKOUSPANB, MODE_CHINKOUSPAN };
enum MAIN_SIGNAL_MODE { MODE_MAIN,         MODE_SIGNAL };

//+------------------------------------------------------------------+
//|MQL4 Buffer wrapper                                               |
//+------------------------------------------------------------------+
double CopyBufferMQL4(int handle,int index,int shift)
  {
   double buf[];
   switch(index)
     {
      case 0:
         if(CopyBuffer(handle,0,shift,1,buf)>0)
            return(buf[0]);
         break;
      case 1:
         if(CopyBuffer(handle,1,shift,1,buf)>0)
            return(buf[0]);
         break;
      case 2:
         if(CopyBuffer(handle,2,shift,1,buf)>0)
            return(buf[0]);
         break;
      case 3:
         if(CopyBuffer(handle,3,shift,1,buf)>0)
            return(buf[0]);
         break;
      case 4:
         if(CopyBuffer(handle,4,shift,1,buf)>0)
            return(buf[0]);
         break;
      default:
         break;
     }
   return(EMPTY_VALUE);
  }

//+------------------------------------------------------------------+
//|MQL4 iMA() wrapper                                                |
//+------------------------------------------------------------------+
double iMAMQL4(string symbol,
               int tf,
               int period,
               int ma_shift,
               int method,
               int price,
               int shift)
  {
   ENUM_TIMEFRAMES timeframe=TFMigrate(tf);
   ENUM_MA_METHOD ma_method=MethodMigrate(method);
   ENUM_APPLIED_PRICE applied_price=PriceMigrate(price);
   int handle=iMA(symbol,timeframe,period,ma_shift,
                  ma_method,applied_price);
   if(handle<0)
     {
      Print("The iMA object is not created: Error",GetLastError());
      return(-1);
     }
   else
      return(CopyBufferMQL4(handle,0,shift));
  }
//+------------------------------------------------------------------+


