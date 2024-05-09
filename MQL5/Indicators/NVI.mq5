//+------------------------------------------------------------------+
//|                                            Negative Volume Index |
//|                                      Copyright © 2024, EarnForex |
//|                                        https://www.earnforex.com |
//+------------------------------------------------------------------+
#property copyright "www.EarnForex.com, 2024"
#property link      "https://www.earnforex.com/metatrader-indicators/Negative-Volume-Index/"
#property version   "1.00"
#property icon      "\\Files\\EF-Icon-64x64px.ico"

#property description "Negative Volume Index calculates only price changes accompanied by negative change in volume."
#property description "This implementation includes the following features:"
#property description " * Multi-timeframe (MTF) option"
#property description " * Positive Volume Index switch"

#property indicator_separate_window
#property indicator_buffers 2
#property indicator_plots 1
#property indicator_color1 clrRed
#property indicator_type1 DRAW_LINE
#property indicator_width1 2
#property indicator_label1 "NVI"

input int Shift = 0; // Indicator shift
input ENUM_TIMEFRAMES InpTimeframe = PERIOD_CURRENT; // Timeframe
input bool Positive = false; // Positive Volume Index?
input ENUM_APPLIED_VOLUME VolumeType = VOLUME_TICK;

// Buffers:
double NVI[];
double UpperTFShift[];

// Global variables:
ENUM_TIMEFRAMES Timeframe; // Timeframe of operation.
int deltaHighTF; // Difference in candles count from the higher timeframe.

void OnInit()
{
    IndicatorSetInteger(INDICATOR_DIGITS, 4);
    string name = "NVI";

    SetIndexBuffer(0, NVI, INDICATOR_DATA);
    SetIndexBuffer(1, UpperTFShift, INDICATOR_DATA);
    PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, EMPTY_VALUE);
    PlotIndexSetInteger(0, PLOT_SHIFT, Shift);

    // Setting values for the higher timeframe:
    Timeframe = InpTimeframe;
    if (InpTimeframe < Period())
    {
        Timeframe = (ENUM_TIMEFRAMES)Period();
    }
    else if (InpTimeframe > Period())
    {
        name += " @ " + EnumToString(Timeframe);
        StringReplace(name, "PERIOD_", "");
    }
    IndicatorSetString(INDICATOR_SHORTNAME, name);
    
    deltaHighTF = 0;
    if (Timeframe > Period())
    {
        deltaHighTF = Timeframe / Period();
    }
}

int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
{
    if ((iBars(_Symbol, Timeframe) < 2) || (rates_total < 2)) return 0; // Not enough bars.

    int Upper_RT = iBars(_Symbol, Timeframe);

    // Starting position for calculations.
    int pos;

    pos = prev_calculated - 1 - deltaHighTF;
    if (pos < 0) // Pre-fill upper timeframe buffer.
    {
        pos = 0;
        if (Timeframe != Period())
        {
            for (int i = pos; i < rates_total && !IsStopped(); i++)
            {
                int index = rates_total - 1 - i;
                int shift = index;
                if (Timeframe != Period()) shift = iBarShift(_Symbol, Timeframe, iTime(_Symbol, PERIOD_CURRENT, index));
                UpperTFShift[i] = Upper_RT - 1 - shift;
            }
        }
        pos = 1; // Start from pre-oldest bar.
        NVI[0] = 1;
    }
    for (int i = pos; i < rates_total && !IsStopped(); i++)
    {
        int index = rates_total - 1 - i;
        int shift = index;
        if (Timeframe != Period())
        {
            shift = iBarShift(_Symbol, Timeframe, iTime(_Symbol, PERIOD_CURRENT, index));
            if (Upper_RT - 1 - shift == UpperTFShift[i - 1]) // If previous upper timeframe shift equals current, then current indicator values should be the same as previous. No need to re-calculate them.
            {
                NVI[i] = NVI[i - 1];
                UpperTFShift[i] = Upper_RT - 1 - shift;
                continue;
            }
        }

        long vol_cur, vol_prev;
        if (VolumeType == VOLUME_REAL)
        {
            vol_cur = volume[i];
            vol_prev = volume[i - 1];
        }
        else
        {
            vol_cur = tick_volume[i];
            vol_prev = tick_volume[i - 1];
        }

        if (((!Positive) && (vol_cur < vol_prev)) || ((Positive) && (vol_cur > vol_prev))) NVI[i] = NVI[i - 1] * close[i] / close[i - 1]; // If volume declined, apply the price change. Inverted for Positive Volume Index.
        else NVI[i] = NVI[i - 1]; // Otherwise, leave unchanged.

        UpperTFShift[i] = Upper_RT - 1 - shift;
    }

    return rates_total;
}
//+------------------------------------------------------------------+