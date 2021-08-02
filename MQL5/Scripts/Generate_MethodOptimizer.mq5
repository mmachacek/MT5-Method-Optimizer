//+------------------------------------------------------------------+
//|                                     Generate_MethodOptimizer.mq5 |
//|                                  Copyright 2021, Michal Machacek |
//|                                 https://www.github.com/mmachacek |
//+------------------------------------------------------------------+
#include <methodOptimizerSourceCode.mqh>
#property copyright "Copyright 2021, Michal Machacek"
#property link      "https://www.github.com/mmachacek"
#property version   "1.00"
#property script_show_inputs
input string generatedEAName = "MethodOptimizer_";
input bool addSymbolToEAName = true;
input bool addTimeframeToEAName = true;
string signals = "";
string directions = "";
string EAName;
//+------------------------------------------------------------------+
//|Script program start function                                    |
//+------------------------------------------------------------------+
void OnStart()
  {

   checkIfEAExists();
   findSignals();
   generateEA();

   return;
  }

//+------------------------------------------------------------------+
//|Check and delete an old generated EA                              |
//+------------------------------------------------------------------+
void checkIfEAExists()
  {
   EAName = generatedEAName;

   if(addSymbolToEAName)
     {
      if(!StringAdd(EAName, Symbol()))
        {
         Alert("Unable to modify EAName");
        }
     }

   if(addTimeframeToEAName)
     {
      if(!StringAdd(EAName, IntegerToString(Period())))
        {
         Alert("Unable to modify EAName");
        }
     }

   if(FileIsExist(EAName + ".mq5"))
     {
      if(!FileDelete(EAName + ".mq5"))
        {
         Alert("Unable to delete the file " + EAName);
        }
     }
   return;
  }

//+------------------------------------------------------------------+
//|Find signals on the chart                                         |
//+------------------------------------------------------------------+
void findSignals()
  {
   for(int x=0; x<ObjectsTotal(0); x++)
     {
      if(ObjectGetInteger(0, ObjectName(0, x), OBJPROP_TYPE) == OBJ_ARROW_UP || ObjectGetInteger(0, ObjectName(0, x), OBJPROP_TYPE) == OBJ_ARROW_THUMB_UP)
        {
         if(!StringAdd(signals, (string)(datetime)ObjectGetInteger(0, ObjectName(0, x), OBJPROP_TIME) + "/"))
           {
            Alert("Unable to save the datetime from the signal at " + (string)(datetime)ObjectGetInteger(0, ObjectName(0, x), OBJPROP_TIME));
           }
         if(!StringAdd(directions, (string)1 + "/"))
           {
            Alert("Unable to save the direction from the signal at " + (string)(datetime)ObjectGetInteger(0, ObjectName(0, x), OBJPROP_TIME));
           }
        }

      if(ObjectGetInteger(0, ObjectName(0, x), OBJPROP_TYPE) == OBJ_ARROW_DOWN || ObjectGetInteger(0, ObjectName(0, x), OBJPROP_TYPE) == OBJ_ARROW_THUMB_DOWN)
        {
         if(!StringAdd(signals, (string)(datetime)ObjectGetInteger(0, ObjectName(0, x), OBJPROP_TIME) + "/"))
           {
            Alert("Unable to save the datetime from the signal at " + (string)(datetime)ObjectGetInteger(0, ObjectName(0, x), OBJPROP_TIME));
           }
         if(!StringAdd(directions, (string)0 + "/"))
           {
            Alert("Unable to save the direction from the signal at " + (string)(datetime)ObjectGetInteger(0, ObjectName(0, x), OBJPROP_TIME));
           }
        }
     }
   return;
  }
//+------------------------------------------------------------------+
//|Generate a new EA file                                            |
//+------------------------------------------------------------------+
void generateEA()
  {
   int fileHandle = FileOpen(EAName + ".mq5", FILE_WRITE|FILE_TXT);

   if(!FileWrite(fileHandle, firstPartCode))
     {
      Alert("Unable to generate the first part of the EA" + " with error: " + (string)GetLastError());
     }

   if(!FileWrite(fileHandle, "string signals = \"""" + signals + "\"" + ";\n"))
     {
      Alert("Unable to generate signals for the EA" + " with error: " + (string)GetLastError());
     }

   if(!FileWrite(fileHandle, "string directions = \"""" + directions + "\"" + ";\n"))
     {
      Alert("Unable to generate directions for the EA" + " with error: " + (string)GetLastError());
     }

   if(!FileWrite(fileHandle, secondPartCode))
     {
      Alert("Unable to generate the second part of the EA" + " with error: " + (string)GetLastError());
     }

   if(!FileWrite(fileHandle, thirdPartCode))
     {
      Alert("Unable to generate the third part of the EA" + " with error: " + (string)GetLastError());
     }

   if(!FileWrite(fileHandle, fourthPartCode))
     {
      Alert("Unable to generate the fourth part of the EA" + " with error: " + (string)GetLastError());
     }

   FileClose(fileHandle);

   if(FileIsExist(EAName + ".mq5"))
     {
      Alert(EAName + ".mq5" + " has been created");
     }

   return;
  }
//+------------------------------------------------------------------+
