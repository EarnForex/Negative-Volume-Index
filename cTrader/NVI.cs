// -------------------------------------------------------------------------------
//   Negative Volume Index calculates only price changes accompanied by negative change in volume.
//   This implementation includes the following features:
//    * Multi-timeframe (MTF) option
//    * Positive Volume Index switch
//   
//   Version 1.00
//   Copyright 2024, EarnForex.com
//   https://www.earnforex.com/metatrader-indicators/Negative-Volume-Index/
// -------------------------------------------------------------------------------

using cAlgo.API;

namespace cAlgo;

[Indicator(AccessRights = AccessRights.None, IsOverlay = false)]
public class NegativeVolumeIndex : Indicator
{
    [Parameter("Shift", DefaultValue = 0)]
    public int InputShift { get; set; }

    [Parameter("Higher TF")]
    public TimeFrame InputHigherTimeFrame { get; set; }

    [Parameter("Positive Volume Index?", DefaultValue = false)]
    public bool Positive { get; set; }


    [Output("NVI", LineColor = "Red", Thickness = 2)] 
    public IndicatorDataSeries NVI { get; set; }
    

    private IndicatorDataSeries unshiftedNVI; // To enable Shift parameter for the indicator.

    private Bars _highTfBars;

    public TimeSeries Times => Bars.OpenTimes;
    public DataSeries HClose => _highTfBars.ClosePrices;
    public DataSeries HVolume => _highTfBars.TickVolumes;

    protected override void Initialize()
    {
        unshiftedNVI = CreateDataSeries();
        _highTfBars = MarketData.GetBars(InputHigherTimeFrame <= TimeFrame 
            ? TimeFrame 
            : InputHigherTimeFrame);
    }

    public override void Calculate(int index)
    {
        if (index == 0)
        {
            NVI[index + InputShift] = 1;
            unshiftedNVI[0] = 1;
            return;
        }

        var highTfIndex = _highTfBars.OpenTimes.GetIndexByTime(Times[index]);
        var index_for_prev_htf = index - 1;
        if (InputHigherTimeFrame > TimeFrame)
            while ((index_for_prev_htf > 0) && (_highTfBars.OpenTimes.GetIndexByTime(Times[index_for_prev_htf]) == highTfIndex)) index_for_prev_htf--;

        if (IsLastBar)
        {
            // Need to update last values according to the High TF Bar that hasn't closed yet.
            var startMainIndex = Times.GetIndexByTime(_highTfBars.OpenTimes[highTfIndex]);

            for (int i = startMainIndex; i <= index; i++)
            {
                unshiftedNVI[i] = unshiftedNVI[index_for_prev_htf] * GetNVIChange(highTfIndex);
                NVI[i + InputShift] = unshiftedNVI[i];
            }
        }
        else
        {
            unshiftedNVI[index] = unshiftedNVI[index_for_prev_htf] * GetNVIChange(highTfIndex);
            NVI[index + InputShift] = unshiftedNVI[index];
        }
    }

    private double GetNVIChange(int index)
    {
        var vol_cur = HVolume[index];
        var vol_prev = HVolume[index - 1];
        if (((!Positive) && (vol_cur < vol_prev)) || ((Positive) && (vol_cur > vol_prev))) return HClose[index] / HClose[index - 1]; // If volume declined, apply the price change. Inverted for Positive Volume Index.
        else return 1; // Otherwise, leave unchanged.
    }
}