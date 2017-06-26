
//------------------------------------------------------------------------
//                       Global Variables & Instances
//------------------------------------------------------------------------

DataProcessing_User dataProcessing_user;
boolean drawEMG = false; //if true... toggles on EEG_Processing_User.draw and toggles off the headplot in Gui_Manager
boolean drawAccel = false;
boolean drawPulse = false;
boolean drawFFT = true;
boolean drawBionics = false;
boolean drawHead = true;


String oldCommand = "";
boolean hasGestured = false;

//------------------------------------------------------------------------
//                            Classes
//------------------------------------------------------------------------
class DetectedPeak {
  int bin;
  float freq_Hz;
  float rms_uV_perBin;
  float background_rms_uV_perBin;
  float SNR_dB;
  boolean isDetected;
  float threshold_dB;

  DetectedPeak() {
    clear();
  }

  void clear() {
    bin=0;
    freq_Hz = 0.0f;
    rms_uV_perBin = 0.0f;
    background_rms_uV_perBin = 0.0f;
    SNR_dB = -100.0f;
    isDetected = false;
    threshold_dB = 0.0f;
  }

  void copyTo(DetectedPeak target) {
    target.bin = bin;
    target.freq_Hz = freq_Hz;
    target.rms_uV_perBin = rms_uV_perBin;
    target.background_rms_uV_perBin = background_rms_uV_perBin;
    target.SNR_dB = SNR_dB;
    target.isDetected = isDetected;
    target.threshold_dB = threshold_dB;
  }
}



class DataProcessing_User {
  private float fs_Hz;  //sample rate
  private int n_chan;

  // THE CRITICAL DETECTION PARAMETER!!!!
  final float detection_thresh_dB = 8.0f; //how much bigger must the peak be relative to the background

  final float detection_thresh_dB_Muscle = 20.0f; //how much bigger must the peak be relative to the background


  //add your own variables here
  final float min_allowed_peak_freq_Hz = 4.5f; //was 4.0f, input, for peak frequency detection
  final float max_allowed_peak_freq_Hz = 15.0f; //was 15.0f, input, for peak frequency detection

  final float min_allowed_peak_freq_Hz_muscle = 10.0f; //was 4.0f, input, for peak frequency detection
  final float max_allowed_peak_freq_Hz_muscle  = 15.0f; //was 15.0f, input, for peak frequency detection

  final float[] processing_band_low_Hz = {
    4.0, 6.5, 9, 13.5
  }; //lower bound for each frequency band of interest (2D classifier only)
  final float[] processing_band_high_Hz = {
    6.5, 9, 12, 16.5
  };  //upper bound for each frequency band of interest
  DetectedPeak[] detectedPeak;  //output per channel, from peak frequency detection
  DetectedPeak[] peakPerBand;
  boolean showDetectionOnGUI = true;
  public boolean useClassfier_2DTraining = false;  //use the fancier classifier?

  boolean switchesActive = false;

  Button leftConfig = new Button(3*(width/4) - 65,height/4 - 120,20,20,"\\/",fontInfo.buttonLabel_size);
  Button midConfig = new Button(3*(width/4) + 63,height/4 - 120,20,20,"\\/",fontInfo.buttonLabel_size);
  Button rightConfig = new Button(3*(width/4) + 190,height/4 - 120,20,20,"\\/",fontInfo.buttonLabel_size);

  Toy theToy;

  //class constructor
  DataProcessing_User(int NCHAN, float sample_rate_Hz, Toy toy) {
    n_chan = NCHAN;
    fs_Hz = sample_rate_Hz;
    theToy = toy;

    detectedPeak = new DetectedPeak[n_chan];
      for (int Ichan=0; Ichan<n_chan; Ichan++) detectedPeak[Ichan]=new DetectedPeak();

      int nBands = processing_band_low_Hz.length;
      peakPerBand = new DetectedPeak[nBands];
      for (int Iband=0; Iband<nBands; Iband++) peakPerBand[Iband] = new DetectedPeak();
  }

  //add some functions here...if you'd like

  //here is the processing routine called by the OpenBCI main program...update this with whatever you'd like to do
  public void process(float[][] data_newest_uV, //holds raw bio data that is new since the last call
    float[][] data_long_uV, //holds a longer piece of buffered EEG data, of same length as will be plotted on the screen
    float[][] data_forDisplay_uV, //this data has been filtered and is ready for plotting on the screen
    FFT[] fftData) {              //holds the FFT (frequency spectrum) of the latest data

    processMultiPerson(data_newest_uV, data_long_uV, data_forDisplay_uV, fftData);

    //for example, you could loop over each EEG channel to do some sort of time-domain processing
    //using the sample values that have already been filtered, as will be plotted on the display
    float EEG_value_uV;

    }

  public void processMultiPerson(float[][] data_newest_uV, //holds raw EEG data that is new since the last call
      float[][] data_long_uV, //holds a longer piece of buffered EEG data, of same length as will be plotted on the screen
      float[][] data_forDisplay_uV, //this data has been filtered and is ready for plotting on the screen
      FFT[] fftData) {              //holds the FFT (frequency spectrum) of the latest data

  boolean isDetected = false;
  String txt = "";
  int Ichan = (0);

  findPeakFrequency(fftData, Ichan);
  if ((detectedPeak[Ichan].freq_Hz >= min_allowed_peak_freq_Hz_muscle) && (detectedPeak[Ichan].freq_Hz < max_allowed_peak_freq_Hz_muscle)) {
    if (detectedPeak[Ichan].SNR_dB >= detection_thresh_dB) {
      detectedPeak[Ichan].threshold_dB = detection_thresh_dB;
      detectedPeak[Ichan].isDetected = true;
      theToy.climb();
      txt = "Climb";
      isDetected = true;
    }
  } else {
    Ichan = (1);
    findPeakFrequency(fftData, Ichan);
    if ((detectedPeak[Ichan].freq_Hz >= min_allowed_peak_freq_Hz_muscle) && (detectedPeak[Ichan].freq_Hz < max_allowed_peak_freq_Hz_muscle)) { //look in alpha band
      if (detectedPeak[Ichan].SNR_dB >= detection_thresh_dB) {
        detectedPeak[Ichan].threshold_dB = detection_thresh_dB;
        detectedPeak[Ichan].isDetected = true;
        theToy.dive();
        txt = "Dive";
        isDetected = true;
      }
    }
    else {
      //did not detect forward, try left
      Ichan = (2);
      findPeakFrequency(fftData, Ichan);
      if ((detectedPeak[Ichan].freq_Hz >= processing_band_low_Hz[3-1]) && (detectedPeak[Ichan].freq_Hz < processing_band_high_Hz[3-1])) {
        if (detectedPeak[Ichan].SNR_dB >= detection_thresh_dB) {
          detectedPeak[Ichan].threshold_dB = detection_thresh_dB;
          detectedPeak[Ichan].isDetected = true;
          theToy.forward();
          txt = "Forward";
          isDetected = true;
        }
      }
    }
  }
  if (isDetected) {
    //print some output
    println("EEG_Processing_User: " + txt + "!, Chan " + (Ichan) + ", peak = " + detectedPeak[Ichan].rms_uV_perBin + " uV at "
      + detectedPeak[Ichan].freq_Hz + " Hz with background at = " + detectedPeak[Ichan].background_rms_uV_perBin
      + ", SNR (dB) = " + detectedPeak[Ichan].SNR_dB);
  }
}
    //add some functions here...if you'd like
    void findPeakFrequency(FFT[] fftData, int Ichan) {

      //loop over each EEG channel and find the frequency with the peak amplitude
      float FFT_freq_Hz, FFT_value_uV;
      //for (int Ichan=0;Ichan < n_chan; Ichan++) {

      //clear the data structure that will hold the peak for this channel
      detectedPeak[Ichan].clear();

      //loop over each frequency bin to find the one with the strongest peak
      int nBins =  fftData[Ichan].specSize();
      for (int Ibin=0; Ibin < nBins; Ibin++) {
        FFT_freq_Hz = fftData[Ichan].indexToFreq(Ibin); //here is the frequency of htis bin

          //is this bin within the frequency band of interest?
        if ((FFT_freq_Hz >= min_allowed_peak_freq_Hz) && (FFT_freq_Hz <= max_allowed_peak_freq_Hz)) {
          //we are within the frequency band of interest

          //get the RMS voltage (per bin)
          FFT_value_uV = fftData[Ichan].getBand(Ibin) / ((float)nBins);
          //FFT_value_uV = fftData[Ichan].getBand(Ibin);

          //decide if this is the maximum, compared to previous bins for this channel
          if (FFT_value_uV > detectedPeak[Ichan].rms_uV_perBin) {
            //this is bigger, so hold onto this value as the new "maximum"
            detectedPeak[Ichan].bin  = Ibin;
            detectedPeak[Ichan].freq_Hz = FFT_freq_Hz;
            detectedPeak[Ichan].rms_uV_perBin = FFT_value_uV;
          }
        } //close if within frequency band
      } //close loop over bins

      //loop over the bins again (within the sense band) to get the average background power, excluding the bins on either side of the peak
      float sum_pow=0.0;
      int count=0;
      for (int Ibin=0; Ibin < nBins; Ibin++) {
        FFT_freq_Hz = fftData[Ichan].indexToFreq(Ibin);
        if ((FFT_freq_Hz >= min_allowed_peak_freq_Hz) && (FFT_freq_Hz <= max_allowed_peak_freq_Hz)) {
          if ((Ibin < detectedPeak[Ichan].bin - 1) || (Ibin > detectedPeak[Ichan].bin + 1)) {
            FFT_value_uV = fftData[Ichan].getBand(Ibin) / ((float)nBins);  //get the RMS per bin
            sum_pow+=pow(FFT_value_uV, 2.0f);
            count++;
          }
        }
      }
      //compute mean
      detectedPeak[Ichan].background_rms_uV_perBin = sqrt(sum_pow / count);

      //decide if peak is big enough to be detected
      detectedPeak[Ichan].SNR_dB = 20.0f*(float)java.lang.Math.log10(detectedPeak[Ichan].rms_uV_perBin / detectedPeak[Ichan].background_rms_uV_perBin);

      } //end method findPeakFrequency

      //add some functions here...if you'd like
      void findPeakFrequencyForMuscle(FFT[] fftData, int Ichan) {

        //loop over each EEG channel and find the frequency with the peak amplitude
        float FFT_freq_Hz, FFT_value_uV;
        //for (int Ichan=0;Ichan < n_chan; Ichan++) {

        //clear the data structure that will hold the peak for this channel
        detectedPeak[Ichan].clear();

        //loop over each frequency bin to find the one with the strongest peak
        int nBins =  fftData[Ichan].specSize();
        for (int Ibin=0; Ibin < nBins; Ibin++) {
          FFT_freq_Hz = fftData[Ichan].indexToFreq(Ibin); //here is the frequency of htis bin

            //is this bin within the frequency band of interest?
          if ((FFT_freq_Hz >= min_allowed_peak_freq_Hz_muscle) && (FFT_freq_Hz <= max_allowed_peak_freq_Hz_muscle)) {
            //we are within the frequency band of interest

            //get the RMS voltage (per bin)
            FFT_value_uV = fftData[Ichan].getBand(Ibin) / ((float)nBins);
            //FFT_value_uV = fftData[Ichan].getBand(Ibin);

            //decide if this is the maximum, compared to previous bins for this channel
            if (FFT_value_uV > detectedPeak[Ichan].rms_uV_perBin) {
              //this is bigger, so hold onto this value as the new "maximum"
              detectedPeak[Ichan].bin  = Ibin;
              detectedPeak[Ichan].freq_Hz = FFT_freq_Hz;
              detectedPeak[Ichan].rms_uV_perBin = FFT_value_uV;
            }
          } //close if within frequency band
        } //close loop over bins

        //loop over the bins again (within the sense band) to get the average background power, excluding the bins on either side of the peak
        float sum_pow=0.0;
        int count=0;
        for (int Ibin=0; Ibin < nBins; Ibin++) {
          FFT_freq_Hz = fftData[Ichan].indexToFreq(Ibin);
          if ((FFT_freq_Hz >= min_allowed_peak_freq_Hz) && (FFT_freq_Hz <= max_allowed_peak_freq_Hz)) {
            if ((Ibin < detectedPeak[Ichan].bin - 1) || (Ibin > detectedPeak[Ichan].bin + 1)) {
              FFT_value_uV = fftData[Ichan].getBand(Ibin) / ((float)nBins);  //get the RMS per bin
              sum_pow+=pow(FFT_value_uV, 2.0f);
              count++;
            }
          }
        }
        //compute mean
        detectedPeak[Ichan].background_rms_uV_perBin = sqrt(sum_pow / count);

        //decide if peak is big enough to be detected
        detectedPeak[Ichan].SNR_dB = 20.0f*(float)java.lang.Math.log10(detectedPeak[Ichan].rms_uV_perBin / detectedPeak[Ichan].background_rms_uV_perBin);

        } //end method findPeakFrequency



void findBestFrequency_2DTraining(FFT[] fftData, int Ichan) {

  //loop over each EEG channel
  float FFT_freq_Hz, FFT_value_uV;
  //for (int Ichan=0;Ichan < n_chan; Ichan++) {
  int nBins =  fftData[Ichan].specSize();

  //loop over all bins and comptue SNR for each bin
  float[] SNR_dB = new float[nBins];
  float noise_pow_uV = detectedPeak[Ichan].background_rms_uV_perBin;
  for (int Ibin=0; Ibin < nBins; Ibin++) {
    FFT_value_uV = fftData[Ichan].getBand(Ibin) / ((float)nBins);  //get the RMS per bin
    SNR_dB[Ibin] = 20.0f*(float)java.lang.Math.log10(FFT_value_uV / noise_pow_uV);
  }

  //find peak SNR in each freq band
  float this_SNR_dB=0.0;
  int nBands=peakPerBand.length;
  for (int Iband=0; Iband<nBands; Iband++) {
    //peakPerBand[Iband] = new DetectedPeak();
    //init variables for this frequency band
    peakPerBand[Iband].clear();
    peakPerBand[Iband].SNR_dB = -100.0;
    peakPerBand[Iband].background_rms_uV_perBin = detectedPeak[Ichan].background_rms_uV_perBin;

    //loop over all bins
    for (int Ibin=0; Ibin < nBins; Ibin++) {
      FFT_freq_Hz = fftData[Ichan].indexToFreq(Ibin); //here is the frequency of this bin
      if (FFT_freq_Hz >= processing_band_low_Hz[Iband]) {
        if (FFT_freq_Hz <= processing_band_high_Hz[Iband]) {
          if (SNR_dB[Ibin] > peakPerBand[Iband].SNR_dB) {
            peakPerBand[Iband].bin = Ibin;
            peakPerBand[Iband].freq_Hz = FFT_freq_Hz;
            peakPerBand[Iband].rms_uV_perBin = fftData[Ichan].getBand(Ibin) / ((float)nBins);
            peakPerBand[Iband].SNR_dB = SNR_dB[Ibin];
          }
        }
      }
    } //end loop over bins
  } //end loop over frequency bands

  //apply new 2D detection rules
  applyDetectionRules_2D(peakPerBand, detectedPeak[Ichan]);

  //} // end loop over channels
}

void applyDetectionRules_2D(DetectedPeak[] peakPerBand, DetectedPeak detectedPeak) {
  int band_A = 0, band_B = 1, band_C = 2, band_D = 3;
  int nRules = 3;
  float[] value_from_each_rule = new float[nRules];
  float primary_value_dB=0.0, secondary_value_dB=0.0;
  int nDetect = 0;

  //allocate the per-rule variables
  DetectedPeak[] candidate_detection = new DetectedPeak[nRules];  //one for each rule
  for (int Irule=0; Irule < nRules; Irule++) {
    candidate_detection[Irule] = new DetectedPeak();
  }

  //check rule 1 applying to RIGHT command...here, we care about Band A and Band C
  primary_value_dB = peakPerBand[band_A].SNR_dB;
  peakPerBand[band_A].copyTo(candidate_detection[0]);
  secondary_value_dB = peakPerBand[band_C].SNR_dB;
  float secondary_threshold_dB = 3.0f;
  peakPerBand[band_A].threshold_dB = max(detection_thresh_dB,
  max(primary_value_dB, detection_thresh_dB) + max(0, secondary_threshold_dB - secondary_value_dB)); //for plotting purposes only
  if (primary_value_dB >= detection_thresh_dB) {
    if (secondary_value_dB >= secondary_threshold_dB) {
      //detected!
      nDetect++;
      value_from_each_rule[0] = primary_value_dB;
      peakPerBand[band_A].isDetected=true;
      candidate_detection[0].isDetected=true;
      //println("applyDetectionRules_2D: rule 0: nDetect = " + nDetect + ", value_from_each_rule[0] = " + value_from_each_rule[0]);
    }
  }

  //check rule 2 applying to LEFT command...here, we care about Band B and Band D
  primary_value_dB = peakPerBand[band_B].SNR_dB;
  secondary_value_dB = peakPerBand[band_D].SNR_dB;
  peakPerBand[band_B].threshold_dB = detection_thresh_dB;
  peakPerBand[band_D].threshold_dB = 4.5 * sqrt(abs(1.1 - pow(primary_value_dB/detection_thresh_dB, 2.0)));
  if (primary_value_dB >= peakPerBand[band_B].threshold_dB) {
    //for larger SNR values
    if (secondary_value_dB >= 0.0f) {
      //detected!
      nDetect++;
      value_from_each_rule[1] = primary_value_dB;
      peakPerBand[band_B].copyTo(candidate_detection[1]);
      peakPerBand[band_B].isDetected =true;
      candidate_detection[1].isDetected=true;
      //println("applyDetectionRules_2D: rule 1A: nDetect = " + nDetect + ", value_from_each_rule[1] = " + value_from_each_rule[1]);
    }
  } else if (primary_value_dB >= 0.0f) {
    //for smaller SNR values
    float second_threshold_dB = peakPerBand[band_D].threshold_dB;
    if (secondary_value_dB >= second_threshold_dB) {
      //detected!
      nDetect++;
      value_from_each_rule[1] = secondary_value_dB;  //create something that is comparable to the other metrics, which are based on detection_thresh_dB
      peakPerBand[band_D].copyTo(candidate_detection[1]);
      peakPerBand[band_D].isDetected=true;
      candidate_detection[1].isDetected=true;
      //println("applyDetectionRules_2D: rule 1B: nDetect = " + nDetect + ", value_from_each_rule[1] = " + value_from_each_rule[1]);
    }
  }

  //check rule 3 applying to FORWARD command...here, we care about Band B and Band D
  primary_value_dB = peakPerBand[band_C].SNR_dB;
  peakPerBand[band_C].copyTo(candidate_detection[2]);
  peakPerBand[band_C].threshold_dB = 3.0;
  secondary_value_dB = peakPerBand[band_D].SNR_dB;
  final float slope = (7.5-(-3))/(12-4);
  final float yoffset = 7.5 - slope*12;
  float second_threshold_dB = slope * primary_value_dB + yoffset;
  if (primary_value_dB >= peakPerBand[band_C].threshold_dB) {
    if (secondary_value_dB <= second_threshold_dB) {  //must be below!  Alpha waves (Band C) should quiet the higher bands (Band D)
      //detected!
      nDetect++;
      value_from_each_rule[2] = primary_value_dB;
      peakPerBand[band_C].isDetected=true;
      candidate_detection[2].isDetected=true;
      //println("applyDetectionRules_2D: rule 2: nDetect = " + nDetect + ", value_from_each_rule[2] = " + value_from_each_rule[2]);
    }
  }
  peakPerBand[band_C].threshold_dB = max(peakPerBand[band_C].threshold_dB, (secondary_value_dB - yoffset) / slope); //for plotting purposes


  //clear previous detection
  detectedPeak.isDetected=false;

  //see if we've had a detection
  if (nDetect > 0) {

    //find the best value (ie, find the maximum "value_from_each_rule" across all rules)
    int rule_ind = findMax(value_from_each_rule);
    //float peak_value = value_from_each_rule[rule_ind];

    //copy over the detection data for that rule/band
    candidate_detection[rule_ind].copyTo(detectedPeak);
    //println("applyDetectionRules_2D: detected, rule_ind = " + rule_ind + ", freq = " + detectedPeak.freq_Hz + " Hz, SNR = " + detectedPeak.SNR_dB + " dB");
  }
} // end of applyDetectionRules_2D

  }
