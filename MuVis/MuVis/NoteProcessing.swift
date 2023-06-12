///  NoteProcessing.swift
///  MuVis
///
///  The NoteProcessing class specified some constants and variable specific to musical notes.
///  When MuVis starts running, the function calculateParameters() is run to calculate a number of variables used throughout the entire project.
///
///  From the spectrum of the audio signal, we are interested in the frequencies between note C1 (about 33 Hz) and note B8 (about 7,902 Hz).
///  These 96 notes cover 8 octaves.
///
///  Created by Keith Bromley on 16 Feb 2021.


import Accelerate


class NoteProcessing {

    static let noteProc = NoteProcessing()  // This singleton instantiates the NoteProcessing class

    init() { calculateParameters() }

    let twelfthRoot2      : Float = pow(2.0, 1.0 / 12.0)     // twelfth root of two = 1.059463094359
    let twentyFourthRoot2 : Float = pow(2.0, 1.0 / 24.0)     // twenty-fourth root of two = 1.029302236643
    
    // variables used to transform the spectrum into an "octave-aligned" spectrum:
    var freqC1: Float = 0.0         // The lowest note of interest is C1 (about 33 Hz Hz)
    var leftFreqC1: Float = 0.0
    var leftFreqC2: Float = 0.0
    var freqB8: Float = 0.0
    var rightFreqB8: Float = 0.0

    // To capture 3 octaves, the highest note is B3 =  Hz      rightFreqB3 =  Hz   topBin = 94
    static let binCount3: Int =  95        // binCount3 = octTopBin[2] + 1 =  94 + 1 =  95
    
    // To capture 6 octaves, the highest note is B6 = 1,976 Hz      rightFreqB6 = 2,033.42 Hz   topBin = 755
    static let binCount6: Int =  756        // binCount6 = octTopBin[5] + 1 =  755 + 1 =  756
    
    // To capture 8 octaves, the highest note is B8 = 7,902 Hz      rightFreqB8 = 8,133.68 Hz   topBin = 3,021
    static let binCount8: Int = 3022        // binCount8 = octTopBin[7] + 1 = 3021 + 1 = 3022
    
    // The 8-octave spectrum covers the range from leftFreqC1 = 31.77 Hz to rightFreqB8 = 8133.84 Hz.
    // That is, from bin = 12 to bin = 3,021
    // The FFT provides us with 8,192 bins.  We will ignore the bin values above 3,022.
    var leftOctFreq  = [Double](repeating: 0.0, count: 8) // frequency at the left window border for a given octave
    var rightOctFreq = [Double](repeating: 0.0, count: 8) // frequency at the right window border for a given octave
    var octBinCount  = [Int](repeating: 0, count: 8)   // number of spectral bins in each octave
    var octBottomBin = [Int](repeating: 0, count: 8)   // the bin number of the bottom spectral bin in each octave
    var octTopBin    = [Int](repeating: 0, count: 8)   // the bin number of the top spectral bin in each octave

    // This is an array of scaling factors to multiply the octaveWidth to get the x coordinate:
    var binXFactor:  [Double] = [Double](repeating: 0.0, count: binCount8)  // binCount8 = 3,022
    var binXFactor3: [Double] = [Double](repeating: 0.0, count: binCount3)  // binCount6 =    95
    var binXFactor6: [Double] = [Double](repeating: 0.0, count: binCount6)  // binCount6 =   756
    var binXFactor8: [Double] = [Double](repeating: 0.0, count: binCount8)  // binCount8 = 3,022
    var binXFactor36:[Double] = [Double](repeating: 0.0, count: 95 + 661)
    // count: 95 + octBinCount[3] + octBinCount[4] + octBinCount[5] = 95 + 94+189+378 = 95 + 661 = 756
    
    var theta: Double = 0.0                                     // 0 <= theta < 1 is the angle around the ellipse
    let pointIncrement: Double = 1.0 / Double(sixOctPointCount)         // pointIncrement = 1 / 864
    var cos2PiTheta = [Double](repeating: 0.0, count: sixOctPointCount) // cos(2 * Pi * theta)
    var sin2PiTheta = [Double](repeating: 0.0, count: sixOctPointCount) // sin(2 * Pi * theta)
    
    var leftNoteFreq  = [Double](repeating: 0.0, count: sixOctNoteCount+1) // frequency at the lower border of a each note
    
    // -----------------------------------------------------------------------------------------------------------------
    // Let's calculate a few frequency values and bin values common to many of the music visualizations:
    func calculateParameters() {

        // Calculate the lower bound of our frequencies-of-interest:
        freqC1 = 55.0 * pow(twelfthRoot2, -9.0)     // C1 = 32.7032 Hz
        leftFreqC1 = freqC1 / twentyFourthRoot2     // leftFreqC1 = 31.772186 Hz
        leftFreqC2 = 2.0 * leftFreqC1               // C1 = 32.7032 Hz    C2 = 65.4064 Hz
    
        // Calculate the upper bound of our frequencies-of-interest:
        freqB8  = 7040.0 * pow(twelfthRoot2, 2.0)   // B8 = 7,902.134 Hz
        rightFreqB8 = freqB8 * twentyFourthRoot2    // rightFreqB8 = 8,133.684 Hz

        // For each octave, calculate the left-most and right-most frequencies:
        for oct in 0 ..< 8 {    // 0 <= oct < 8
            let octD = Double(oct)
            let pow2oct: Double = pow( 2.0, octD )
            leftOctFreq[oct]  = pow2oct * Double( leftFreqC1 ) // 31.77  63.54 127.09 254.18  508.35 1016.71 2033.42 4066.84 Hz
            rightOctFreq[oct] = pow2oct * Double( leftFreqC2 ) // 63.54 127.09 254.18 508.35 1016.71 2033.42 4066.84 8133.68 Hz
        }

        // For each note, calculate the left-most frequency:
        for oct in 0 ..< 6 {    // 0 <= oct < 6
            leftNoteFreq[ oct*notesPerOctave] = leftOctFreq[oct]     // left  border of the lowest note in the octave
            
            // Now calculate the lower border frequencies of the remaining 11 notes in each octave:
            for note in 1 ..< notesPerOctave {    // 1 <= note < 12
                leftNoteFreq[ oct*notesPerOctave + note] = Double(twelfthRoot2) * leftNoteFreq[ oct*notesPerOctave + (note-1)]
            }
        }
        leftNoteFreq[72] = Double(twelfthRoot2) * leftNoteFreq[71]
        
        /*
        // To verify these equations, let's print out the results in a chart of 72 rows.
        for noteNum in 0 ... sixOctNoteCount  {    // 0 <= noteNum <= 72
            print("noteNum: \(noteNum)", "leftfreq: \( leftNoteFreq[noteNum])")
        }
        */
        
        let binFreqWidth = (Double(AudioManager.sampleRate)/2.0) / Double(AudioManager.binCount) // (44100/2)/8192=2.69165 Hz

        // Calculate the number of bins in each octave:
        for oct in 0 ..< 8 {    // 0 <= oct < 8
            var bottomBin: Int = 0
            var topBin: Int = 0
            var startNewOct: Bool = true

            for bin in 0 ..< AudioManager.binCount {
                let binFreq: Double = Double(bin) * binFreqWidth
                if (binFreq < leftOctFreq[oct]) { continue } // For each row, ignore bins with frequency below the leftFreq.
                if (startNewOct) { bottomBin = bin; startNewOct = false }
                if (binFreq > rightOctFreq[oct]) {topBin = bin-1; break} // For each row, ignore bins with frequency above the rightFreq.
            }
            octBottomBin[oct] = bottomBin               // 12, 24, 48,  95, 189, 378,  756,  1511, 3022
            octTopBin[oct] = topBin                     // 23, 47, 94, 188, 377, 755, 1510,  3021, 6043
            octBinCount[oct] = topBin - bottomBin + 1   // 12, 24, 47,  94, 189, 378,  755,  1511, 3022
            // print( octBottomBin[oct], octTopBin[oct], octBinCount[oct] )
        }

        // Calculate the exponential x-coordinate scaling factor:
        for oct in 0 ..< 8 {    // 0 <= oct < 8
            for bin in octBottomBin[oct] ... octTopBin[oct] {
                let binFreq: Double = Double(bin) * binFreqWidth
                let binFraction: Double = (binFreq - leftOctFreq[oct]) / (rightOctFreq[oct] - leftOctFreq[oct]) // 0 < binFraction < 1.0
                let freqFraction: Double = pow(Double(twelfthRoot2), 12.0 * binFraction) // 1.0 < freqFraction < 2.0
                
                // This is an array of scaling factors to multiply the octaveWidth to get the x coordinate:
                // That is, binXFactor goes from 0.0 to 1.0 within each octave.
                binXFactor[bin] =  (2.0 - (2.0 / freqFraction))
                // If freqFraction = 1.0 then binXFactor = 0; If freqFraction = 2.0 then binXFactor = 1.0
                
                // As bin goes from 12 to 3021, binXFactor8 goes from 0.0 to 1.0
                binXFactor8[bin] = ( Double(oct) + binXFactor[bin] ) / Double(8)
                
                // As bin goes from 12 to 755, binXFactor6 goes from 0.0 to 1.0
                if(oct < 6) {binXFactor6[bin] = ( Double(oct) + binXFactor[bin] ) / Double(6) }
                
                // As bin goes from 12 to 94, binXFactor3 goes from 0.0 to 1.0
                if(oct < 3) {binXFactor3[bin] = ( Double(oct) + binXFactor[bin] ) / Double(3) }
            }
        }
              
        // Calculate the exponential x-coordinate scaling factor for octaves 3 to 5 (i.e., bins 95 to 755):
        //var count: Int = 0
        for oct in 3 ... 5 {    // 3 <= oct <= 5
            for bin in octBottomBin[oct] ... octTopBin[oct] {
                let binFreq: Double = Double(bin) * binFreqWidth
                let binFraction: Double = (binFreq - leftOctFreq[oct]) / (rightOctFreq[oct] - leftOctFreq[oct]) // 0 < binFraction < 1.0
                let freqFraction: Double = pow(Double(twelfthRoot2), 12.0 * binFraction) // 1.0 < freqFraction < 2.0

                // This is an array of scaling factors to multiply the octaveWidth to get the x coordinate:
                // That is, binXFactor goes from 0.0 to 1.0 within each octave.
                binXFactor[bin] =  (2.0 - (2.0 / freqFraction))
                // If freqFraction = 1.0 then binXFactor = 0; If freqFraction = 2.0 then binXFactor = 1.0

                // As bin goes from 95 to 755, binXFactor36 goes from 0.0 to 1.0
                binXFactor36[bin] = ( ( Double(oct) + binXFactor[bin] ) / Double(3) ) - 1.0
                // count += 1
                // print( count, oct, bin, binXFactor36[bin] )
                // print(oct, bin, binXFactor[bin], binXFactor3[bin], binXFactor6[bin], binXFactor8[bin], binXFactor36[bin])
            }
        }

        // Calculate the angle theta from dividing a circle into sixOctPointCount angular increments:
        for point in 0 ..< sixOctPointCount {           // sixOctPointCount = 72 * 12 = 864
            theta = Double(point) * pointIncrement
            cos2PiTheta[point] = cos(2.0 * Double.pi * theta)
            sin2PiTheta[point] = sin(2.0 * Double.pi * theta)
        }

    }  // end of calculateParameters() func



    // -----------------------------------------------------------------------------------------------------------------
    // This function calculates the muSpectrum array:
    public func computeMuSpectrum(inputArray: [Float]) -> [Float] {
        // The inputArray is typically an audio spectrum from the AudioManager.
        
        var outputIndices   = [Float] (repeating: 0.0, count: eightOctPointCount) // eightOctPointCount = 96*12 = 1,152
        var pointBuffer     = [Float] (repeating: 0.0, count: eightOctPointCount) // eightOctPointCount = 96*12 = 1,152
        let tempFloat1: Float = Float(leftFreqC1)
        let tempFloat2: Float = Float(notesPerOctave * pointsPerNote)
        let tempFloat3: Float = Float(AudioManager.binFreqWidth)

        for point in 0 ..< eightOctPointCount {
            outputIndices[point] = ( tempFloat1 * pow( 2.0, Float(point) / tempFloat2 ) ) / tempFloat3
        }
        // print(outputIndices)
        
        vDSP_vqint( inputArray,                             // inputVector1
                    &outputIndices,                         // inputVector2 (with indices and fractional parts)
                    vDSP_Stride(1),                         // stride for inputVector2
                    &pointBuffer,                           // outputVector
                    vDSP_Stride(1),                         // stride for outputVector
                    vDSP_Length(eightOctPointCount),        // outputVector.count
                    vDSP_Length(NoteProcessing.binCount8))  // inputVector1.count

        return pointBuffer
    }

    
    
                    
    /*
    The following function estimates which notes are currently playing by observing the harmonic relationships among
    the sixteen loudest spectral peaks.
    We will start counting harmonics from 1 - meaning that harm=1 refers to the fundamental.
    If the fundamental is note C1, then:
        harm=1  is  C1  fundamental
        harm=2  is  C2  octave          freqC2  = 2.0 x freqC1
        harm=3  is  G2                  freqG2  = 3.0 x freqC1
        harm=4  is  C3  two octaves     freqC3  = 4.0 x freqC1
        harm=5  is  E3                  freqE3  = 5.0 x freqC1
        harm=6  is  G3                  freqG3  = 6.0 x freqC1
    So, harmonicCount = 6 and  harm = 1, 2, 3, 4, 5, 6.
    */
    public func computeCurrentNotes(inputArray: [Int]) -> [Int] {
        let harmonicCount: Int = 6
        let peakBinNumbers: [Int] = inputArray
        var noteFundamental: [Bool] = [Bool](repeating: false, count: sixOctNoteCount)
        var noteScore: [Int]   = [Int](repeating:  0, count: sixOctNoteCount)   // sixOctNoteCount = 6 * 12 = 72
        var currentNotes: [Int] = [Int](repeating: 99, count: 8)                // less than 9 notes from 16 peaks
        var i: Int = 0                                                          // counter for currentNote element

        // Calculate how many peaks fall within each note:
        for harm in 1 ... harmonicCount {                       // harm = 1, 2, 3, 4, 5, 6
            for peakNum in 0 ..< peakCount {                    // peakCount = 16
                if(peakBinNumbers[peakNum] == 0) {continue}                 // Only count non-zero peaks.
                let binFreq: Double = ( Double(peakBinNumbers[peakNum]) * AudioManager.binFreqWidth ) / Double(harm)

                for noteNum in 0 ..< sixOctNoteCount {                                      // cycle through all notes
                    let leftNoteBorder:  Double = leftNoteFreq[noteNum  ]
                    let rightNoteBorder: Double = leftNoteFreq[noteNum+1]
                    if ( (binFreq > leftNoteBorder) && (binFreq < rightNoteBorder) ) {      // note sieve
                        noteScore[noteNum] += 1
                        if(harm == 1) { noteFundamental[noteNum] = true }
                    }
                }
            }
        }
        // Now that we have iterated over all the peaks and their harmonics, we have a complete noteScore array.

        // Set the value of currentNote array to the noteNum - if it has sufficient noteScore
        for noteNum in 0 ..< sixOctNoteCount {
            if( (noteFundamental[noteNum] == true) && (noteScore[noteNum] >= 3) ) { // Best choice is 3 or 4 out of 6.
                currentNotes[i] = noteNum
                i += 1
            }
            if(i > 7) {break} // This occasionally happens when multiple close peaks are in the same note.
        }
        return currentNotes
        // The currentNote array will contain 8 noteNums (0-71).  If the element is 99, it is not a playing currentNote.
        
    }  // end of computeCurrentNotes() func
    
}  // end of NoteProcessing class
