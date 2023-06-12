/// HarmonicAlignment.swift
/// MuVis
///
/// The HarmonicAlignment visualization is an enhanced version of the OctaveAlignedSpectrum visualization - which renders a muSpectrum displaying the FFT
/// frequency bins of the live audio data on a two-dimensional Cartesian grid. Each row of this grid is a standard muSpectrum display covering one octave.
/// Each row is aligned one octave above the next-lower row to show the vertical alignment of octave-related frequencies in the music.
/// (Note that this requires compressing the frequency range by a factor of two for each octave.)
/// Hence the six rows of our displayed grid cover six octaves of musical frequency.
///
/// The bottom 6 octaves (the 72 notes from 0 to 71) will be displayed as possible fundamentals of the notes in the music, and the remaining 84 - 72 = 12 notes
/// will be used only for harmonic information. The rendered grid (shown in the above picture) has 6 rows and 12 columns - containing 6 * 12 = 72 boxes.
/// Each box represents one note.
/// In the bottom row (octave 0), the leftmost box represents note 0 (C1 is 33 Hz) and the rightmost box represents note 11 (B1 is 61 Hz).
/// In the top row (octave 5), the leftmost box represents note 60 (C6 is 1046 Hz) and the rightmost box represents note 71 (B6 is 1975 Hz).
///
/// But the novel feature of the HarmonicAlignment visualization is the rendering of the harmonics beneath each note. We are rendering 6 harmonics of each note.
/// We will start counting from 1 - meaning that harm=1 refers to the fundamental. If the fundamental is note C1, then:
///
///	harm=1  is  C1  fundamental
///	harm=2  is  C2  octave                                               harm=3  is  G2
///	harm=4  is  C3  two octaves         harm=5  is  E3      harm=6  is  G3
/// So, harmonicCount = 6 and  harm = 1, 2, 3, 4, 5, 6.
/// The harmonic increment (harmIncrement) for our 6 rendered harmonics is 0, 12, 19, 24, 28, 31 notes.
///
/// The fundamental (harm=1) (the basic octave-aligned spectrum) is shown in red.  The first harmonic (harm=2) shows as orange; the second harmonic (harm=3) is yellow;
/// and the third harmonic harm=4) is green, and so on.  It is instructive to note the massive redundancy displayed here.  A fundamental note rendered as red in row 4
/// will also appear as orange in row 3 since it is the first harmonic of the note one-octave lower, and as orange in row 2 since it is the second harmonic of the note
/// two-octaves lower, and as yellow in row 1 since it is the fourth harmonic of the note three-octaves lower.
///
/// In order to decrease the visual clutter (and to be more musically meaningfull), we multiply the value of the harmonics (harm = 2 through 6) by the value of the
/// fundamental (harm = 1). So, if there is no meaningful amplitude for the fundamental, then its harmonics are not shown (or at least only with low amplitude).
///
/// We will render a total of 6 * 6 = 36 polygons - one for each harmonic of each octave.
///
/// totalPointCount = 84 * 12 = 1008     // total number of points provided by the interpolator
/// sixOctPointCount = 72 * 12 = 864    // total number of points of the 72 possible fundamentals
///
/// If the user selects option 2 or 3, then the visualization is rendered in a slightly different form.  The muSpectrum for each of the six octaves (and for each of the
/// six harmonics within each octave) is rendered twice - one upward stretching muSpectrum and one downward stretching muSpectrum.
/// (This is purely for aesthetic effect - which you may find pleasing or annoying.)
///
/// The OAS of the fundamental notes (in red) is rendered first. Then the OAS of the first harmonic notes (in yellow) are rendered over it.
/// Then the OAS of the second harmonic notes (in green) are rendered over it, and so on - until all 6 harmonics are depicted.
///
/// If the user selects option 0 or 2, we multiply the value of the harmonics (harm = 2 through 6) by the value of the fundamental (harm = 1).
/// So, the harmonics are shown if-and-only-if there is meaningful energy in the fundamental.
///
//          background  foreground
// option0  keyboard    upOnly      ifFundamental
// option1  keyboard    upOnly      allHarmonics
// option2  keyboard    up&down     ifFundamental
// option3  keyboard    up&down     allHarmonics
///
/// Created by Keith Bromley in Nov 2020.  Considerably improved in Mar 2023.


import SwiftUI


struct HarmonicAlignment: View {
    @EnvironmentObject var manager: AudioManager  // Observe the instance of AudioManager passed from ContentView
    var body: some View {
        ZStack {
            GrayVertRectangles(columnCount: 12)
            HorizontalLines(rowCount: 6, offset: (manager.option < 2) ? 0.0 : 0.5) // lavendar hue matches highest harmonic
            VerticalLines(columnCount: 12)
            HorizontalNoteNames(rowCount: 2, octavesPerRow: 1)
            HarmonicAlignment_Live()
        }
    }
}  // end of the HarmonicAlignment struct


struct HarmonicAlignment_Live: View {
    @EnvironmentObject var manager: AudioManager  // Observe the instance of AudioManager passed from ContentView
    
    var body: some View {
        GeometryReader { geometry in

            /*
            This is a two-dimensional grid containing 6 row and 12 columns.
            Each of the 6 rows contains 1 octave or 12 notes or 12*12 = 144 points.
            Each of the 12 columns contains 6 octaves of that particular note.
            The entire grid renders 6 octaves or 6*12 = 72 notes or 6*144 = 864 points
            */

            let harmonicCount: Int = 6  // The total number of harmonics rendered.       0 <= harm <= 5
            let width: CGFloat  = geometry.size.width
            let height: CGFloat = geometry.size.height

            var x: CGFloat = 0.0       // The drawing origin is in the upper left corner.
            var y: CGFloat = 0.0       // The drawing origin is in the upper left corner.
            var upRamp: CGFloat = 0.0

            // Use local short name to improve code readablity:
            let option = manager.option
            let muSpectrum = manager.muSpectrum
            
            let rowCount: Int = 6 // Our muSpectrum array contains 8 octaves, but here we only consider 6 octaves of fundamentals.
            let rowHeight: CGFloat = height / CGFloat(rowCount)
            let halfRowHeight: CGFloat = 0.5 * rowHeight
            let rowOffset: CGFloat = ( option < 2 ) ? 0.0 : halfRowHeight
            
            let gain: CGFloat = ( option < 2 ) ? 0.7 : 0.4      // Chosen ad-hoc to make the visualization look good.
            var harmAmp: CGFloat = 1.0
            var magY:  CGFloat = 0.0                            // used as a preliminary part of the "y" value
            var CGrow: CGFloat = 0.0                            // the row variable recast as a CGFloat
            var totalPoints: Int = 0
            
            let harmIncrement: [Int]  = [ 0, 12, 19, 24, 28, 31 ]      // The increment (in notes) for the six harmonics:
            //                           C1  C2  G2  C3  E3  G3

            // Render each of the six harmonics:
            ForEach( 1 ... harmonicCount, id: \.self) { harm in        // harm = 1,2,3,4,5,6

                let hueHarmOffset: Double = 1.0 / ( Double(harmonicCount) ) // hueHarmOffset = 1/6
                let hueIndex: Double = Double(harm-1) * hueHarmOffset         // hueIndex = 0, 1/6, 2/6, 3/6, 4/6, 5/6

                Path { path in

                    for row in 0 ..< rowCount {
                        CGrow = CGFloat(row)

                        path.move( to: CGPoint( x: 0.0, y: height - ( CGrow * rowHeight ) - rowOffset ) )

                        for point in 0 ..< pointsPerOctave {
                            // upRamp goes from 0.0 to 1.0 as point goes from 0 to pointsPerOctave
                            upRamp =  CGFloat(point) / CGFloat(pointsPerOctave)
                            x = upRamp * width

                            /*
                            In order to decrease the visual clutter (and to be more musically meaningfull), we multiply the
                            value of the harmonics (harm = 2 through 6) by the value of the fundamental (harm = 1).
                            So, if there is no meaningful amplitude for the fundamental, then its harmonics are not shown
                            (or at least shown only with low amplitude).
                            */
                            if( option == 0 || option == 2 ) {
                                harmAmp = (harm == 1) ? 1.0 : CGFloat(muSpectrum[row * pointsPerOctave + point])
                            }
                            else {
                                harmAmp = 1.0
                            }

                            totalPoints = row * pointsPerOctave + pointsPerNote*harmIncrement[harm-1] + point
                            if(totalPoints >= eightOctPointCount) { totalPoints = eightOctPointCount-1 }
                             
                            magY = gain * CGFloat(muSpectrum[totalPoints]) * rowHeight * harmAmp
                            if( totalPoints == eightOctPointCount-1 ) { magY = 0 }
                            magY = min(max(0.0, magY), rowHeight)  // Limit over- and under-saturation.
                            y = height - ( CGrow * rowHeight ) - rowOffset - magY
                            
                            path.addLine(to: CGPoint(x: x, y: y))
                        }
                        path.addLine( to: CGPoint( x: width, y: height - ( CGrow * rowHeight ) - rowOffset ) )
                        
                        if(option > 1) {            // Render the reverse downward-pointing spectrum.
                            
                            for point in (0 ..< pointsPerOctave).reversed() {
                                upRamp =  CGFloat(point) / CGFloat(pointsPerOctave)
                                x = upRamp * width

                                /*
                                In order to decrease the visual clutter (and to be more musically meaningfull), we multiply the
                                value of the harmonics (harm = 2 through 6) by the value of the fundamental (harm = 1).
                                So, if there is no meaningful amplitude for the fundamental, then its harmonics are not shown
                                (or at least shown only with low amplitude).
                                */
                                if( option == 0 || option == 2 ) {
                                    harmAmp = (harm == 1) ? 1.0 : CGFloat(muSpectrum[row * pointsPerOctave + point])
                                }
                                else {
                                    harmAmp = 1.0
                                }
                                
                                totalPoints = row * pointsPerOctave + pointsPerNote*harmIncrement[harm-1] + point
                                if(totalPoints >= eightOctPointCount) { totalPoints = eightOctPointCount-1 }
                                magY = gain * CGFloat(muSpectrum[totalPoints]) * rowHeight * harmAmp
                                
                                if( totalPoints == eightOctPointCount-1 ) { magY = 0 }
                                magY = min(max(0.0, magY), rowHeight)  // Limit over- and under-saturation.
                                y = height - ( CGrow * rowHeight ) - rowOffset + magY
                                path.addLine(to: CGPoint(x: x, y: y))
                            }
                        }
                        path.addLine( to: CGPoint( x: 0.0,   y: height - ( CGrow * rowHeight ) - rowOffset ) )
                        path.closeSubpath()
                    }
                
                }
                .foregroundColor(Color(hue: hueIndex, saturation: 1.0, brightness: 1.0))
                    
            }  // end of ForEach(harm)



            // Print on-screen the elapsed time/frame (in milliseconds) (typically about 17)
            if(showMSPF == true) {
                HStack {
                    Text("MSPF: \( monitorPerformance() )")
                    Spacer()
                }
            }
            
        }  // end of GeometryReader
    }  // end of var body: some View
}  // end of HarmonicAlignment_Live struct
