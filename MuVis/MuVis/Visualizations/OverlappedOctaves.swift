/// OverlappedOctaves.swift
/// MuVis
///
/// The OverlappedOctaves visualization is a variation of the upper half of the PianoKeyboard visualization - except that it stacks notes that are an octave apart.
/// That is, it has a grid of one row tall and 12 columns wide. All of the "C" notes are stacked together (i.e., a ZStack) in the left-hand box; all of the "C#" notes are
/// stacked together (i.e., a ZStack) in the second box, etc. We use the same note color coding scheme as used in the PianoKeyboard.
///
/// We overlay a stack of 8 octaves of the spectrum with the lowest-frequency octave at the back, and the highest-frequency octave at the front.
/// The octave's lowest frequency is at the left pane edge, and it's highest frequency is at the right pane edge.
///
/// Each of the lower 4 octaves is a standard muSpectrum display covering one octave.
/// Each of the upper 4 octaves is a standard spectrum display (converted from linear to exponential frequency) covering one octave.
/// Each octave is overlaid one octave over the next-lower octave. (Note that this requires compressing the frequency range by a factor of two for each octave.)
///
/// The leftmost column represents all of the musical "C" notes, that is: notes 0, 12, 24, 36, 48, and 60.
/// The rightmost column represents all of the musical "B" notes, that is: notes 11, 23, 35, 47, 59, and 71.
///
/// Overlaying this grid is a color scheme representing the white and black keys of a piano keyboard. Also, the name of the note is displayed in each column.
///
//          background  foreground
// option0  keyboard    stationary  octColor
// option1  keyboard    moving      octColor
// option2  keyboard    stationary  pomegranate
// option3  keyboard    moving      pomegranate
///
/// Created by Keith Bromley in June 2021 from an earlier java version developed for the Polaris project.
/// Converted from muSpectrum to spectrum in March 2023.
/// Used muSpectrum for lower 4 octaves and spectrum for upper 4 octaves in May 2023.

import SwiftUI


struct OverlappedOctaves: View {
    var body: some View {
        ZStack {
            GrayVertRectangles(columnCount: 12)                 // struct code in VisUtilities file
            VerticalLines(columnCount: 12)                      // struct code in VisUtilities file
            HorizontalNoteNames(rowCount: 2, octavesPerRow: 1)  // struct code in VisUtilities file
            OverlappedOctaves_Live()
        }
    }
}



struct OverlappedOctaves_Live: View {
    @EnvironmentObject var manager: AudioManager  // Observe the instance of AudioManager passed from ContentView
    @Environment(\.colorScheme) var colorScheme
    let noteProc = NoteProcessing()
    let pomegranate = Color(red: 192.0/255.0, green: 57.0/255.0, blue: 43.0/255.0)
    
    var body: some View {
        GeometryReader { geometry in

            let width: CGFloat  = geometry.size.width
            let height: CGFloat = geometry.size.height
            let halfHeight: CGFloat = height * 0.5
            
            var x : CGFloat = 0.0       // The drawing origin is in the upper left corner.
            var y : CGFloat = 0.0       // The drawing origin is in the upper left corner.
            var upRamp: CGFloat = 0.0
            let octaveCount: Int = 8        // Render 8 octaves of the FFT output.
            let gain: Double = 0.4
            var magY:  CGFloat = 0.0        // used as a preliminary part of the "y" value
            
            let now = Date()
            let time = now.timeIntervalSinceReferenceDate
            let frequency: Double = 0.05  // 1 cycle per 20 seconds
            let offset: Double = 0.5 * ( 1.0 + cos(2.0 * Double.pi * frequency * time )) // oscillates between 0 and +1

            // Use local short name to improve code readablity.
            let option      = manager.option
            let spectrum    = manager.spectrum
            let muSpectrum  = manager.muSpectrum

//---------------------------------------------------------------------------------------------------------------------
            ForEach( 0 ..< octaveCount, id: \.self) { oct in        //  0 <= oct < 8

                // Just for enhanced visual dynamics, make the baseline for the low octaves (at the back) go up and down:
                let maxOctaveOffset: Double = halfHeight * (Double(octaveCount-1 - oct)) / Double(octaveCount-1)
                let octaveOffset: Double = ( option==0 || option==2 ) ? 0.0 : offset * maxOctaveOffset
                let octColor: Color = Color( hue: Double(oct) * 0.14, saturation: 1.0, brightness: 1.0 )
                
                Path { path in

                    // Start the polygon at the pane's lower right corner:
                    path.move( to: CGPoint( x: width, y: height - octaveOffset ) )

                    // Extend the polygon outline to the pane's lower left corner:
                    path.addLine( to: CGPoint( x: 0.0, y: height - octaveOffset ) )

                    if(oct < 4) {       // Use the muSpectrum for the lower 4 octaves:
                        // Extend the polygon outline upward to the first sample point:
                        magY = gain * Double( muSpectrum[oct * pointsPerOctave] )
                        magY = min(max(0.0, magY), 1.0)
                        y = height - octaveOffset - magY * (height - octaveOffset)
                        path.addLine(to: CGPoint(x: 0.0, y: y))
                        
                        // Now render the remaining bins of the polygon across the pane from left to right:
                        for point in 0 ..< pointsPerOctave {
                            // upRamp goes from 0.0 to 1.0 as point goes from 0 to pointsPerOctave
                            upRamp =  CGFloat(point) / CGFloat(pointsPerOctave)
                            x = upRamp * width
                            magY = gain * Double( muSpectrum[oct * pointsPerOctave + point])
                            magY = min(max(0.0, magY), 1.0)
                            y = height - octaveOffset - magY * (height - octaveOffset)
                            path.addLine(to: CGPoint(x: x, y: y))
                        }

                    }else{              // Use the spectrum for the upper 4 octaves:
                        // Extend the polygon outline upward to the first sample point:
                        magY = gain * Double( spectrum[ noteProc.octBottomBin[oct] ] )
                        magY = min(max(0.0, magY), 1.0)
                        y = height - octaveOffset - magY * (height - octaveOffset)
                        path.addLine( to: CGPoint( x: 0.0, y: y ) )
                        
                        // Now render the remaining bins of the polygon across the pane from left to right:
                        for bin in noteProc.octBottomBin[oct] ... noteProc.octTopBin[oct] {
                            x = width * noteProc.binXFactor[bin]
                            magY = gain * Double( spectrum[bin] )
                            magY = min(max(0.0, magY), 1.0)
                            y = height - octaveOffset - magY * (height - octaveOffset)
                            path.addLine(to: CGPoint(x: x, y: y))
                        }
                    }

                    // Finally, extend the polygon back to the pane's lower right corner:
                    path.addLine( to: CGPoint( x: width, y: height - octaveOffset) )
                    path.closeSubpath()
                    
                }  // end of Path
                .fill( ( option < 2 ) ? octColor : pomegranate ,
                       strokeColor: Color( (colorScheme == .dark) ? .black : .white ),
                       lineWidth: 1 )                       // See the extension to Shape() in the VisUtilities file.
                
            }  // end of ForEach(oct)



            // Print on-screen the elapsed time/frame (in milliseconds) (typically about 17)
            if(showMSPF == true) {
                HStack {
                    Text("MSPF: \( monitorPerformance() )")
                    Spacer()
                }
            }

        }  // end of GeometryReader
    }  // end of var body: some View
}  // end of OverlappedOctaves_Live struct
