/// PianoKeyboard.swift
/// MuVis
///
/// The PianoKeyboard visualization is similar to the MusicSpectrum visualization in that it shows an amplitude vs. exponential-frequency spectrum of the audio waveform.
/// The horizontal axis covers 6 octaves from leftFreqC1 = 32 Hz to rightFreqB8 = 2033 Hz -  that is from bin = 12 to bin = 755.  For a pleasing effect, the vertical axis
/// shows both an upward-extending spectrum in the upper-half screen and a downward-extending spectrum in the lower-half screen.
///
/// We have added a piano-keyboard overlay to clearly differentiate the black notes (in gray) from the white notes (in white).
/// Also, we have added note names for the white notes at the top and bottom.
///
/// The spectral peaks comprising each note are a separate color. The colors of the grid are consistent across all octaves - hence all octaves of a "C" note are red;
/// all octaves of an "E" note are green, and all octaves of a "G" note are light blue, etc. Many of the subsequent visualizations use this same note coloring scheme.
/// I have subjectively selected these to provide high color difference between adjacent notes.
///
//          background  foreground
// option0  keyboard    horGradient verLines    NoteNames
// option1  keyboard    verGradient verLines    NoteNames   notes
// option2  plain       horGradient verLines                peaks
// option3  plain       verGradient verLines
///
/// Created by Keith Bromley in May 2023.

import SwiftUI


struct PianoKeyboard: View {
    @EnvironmentObject var manager: AudioManager  // Observe instance of AudioManager passed from ContentView
    var body: some View {
        let option = manager.option     // Use local short name to improve code readablity.
        ZStack {
            if( option < 2 ) { GrayVertRectangles(columnCount: 72) } // struct code in VisUtilities file
            PianoKeyboard_Live()
            if( option < 2 ) { VerticalLines(columnCount: 72) }
            if( option < 2 ) { HorizontalNoteNames(rowCount: 2, octavesPerRow: 6) }
            if( option==1 ) { Notes72() }
            if( option==2 ) { Peaks72() }
        }
    }
}



struct PianoKeyboard_Live: View {
    @EnvironmentObject var manager: AudioManager  // Observe instance of AudioManager passed from ContentView
    @Environment(\.colorScheme) var colorScheme
    let noteProc = NoteProcessing()
    
    var body: some View {
        
        // Toggle between black and white as the Canvas's background color:
        let backgroundColor: Color = (colorScheme == .dark) ? Color.black : Color.white
        
        GeometryReader { geometry in

            let width  : CGFloat = geometry.size.width
            let height : CGFloat = geometry.size.height
            let halfHeight : CGFloat = height * 0.5
            
            var x : CGFloat = 0.0       // The drawing origin is in the upper left corner.
            var y : CGFloat = 0.0       // The drawing origin is in the upper left corner.
            var magY: CGFloat = 0.0     // used as a preliminary part of the "y" value
            var upRamp : CGFloat = 0.0
            let octavesPerRow : Int = 6
            let pointsPerRow : Int = pointsPerNote * notesPerOctave * octavesPerRow  //  12 * 12 * 6 = 864
            
            // Use local short name to improve code readablity:
            let spectrum = manager.spectrum
            let muSpectrum = manager.muSpectrum
            let option = manager.option

            // Use the muSpectrum points from 189 to 755 - that is the 4 octaves from 32 Hz to 508 Hz.
            let lowerPoint: Int = 1             // render the muSpectrum points from 1 to 4*144 = 576
            let upperPoint: Int = 4 * 144       // render the muSpectrum points from 1 to 4*144 = 576
            
            // Use the spectrum bins from 189 to 755 - that is the 2 octaves from 508 Hz to 2,033 Hz.
            let lowerBin: Int = noteProc.octBottomBin[4]    // render the spectrum bins from 189 to 755
            let upperBin: Int = noteProc.octTopBin[5]       // render the spectrum bins from 189 to 755

            
            // Render the lower 4 octaves of the muSpectrum along the upper left-half of the horizontal axis:
            Path { path in
                path.move( to: CGPoint( x: 0.0,   y: halfHeight))       // left midpoint
                
                for point in lowerPoint ..< upperPoint {
                    upRamp =  CGFloat(point) / CGFloat(pointsPerRow)
                    x = upRamp * width
                    magY = CGFloat(muSpectrum[point]) * halfHeight
                    magY = min(max(0.0, magY), halfHeight)
                    y = halfHeight - magY
                    path.addLine(to: CGPoint(x: x, y: y))
                }
                
                // Render the upper 2 octaves of the spectrum along the upper right-half of the horizontal axis:
                for bin in lowerBin ... upperBin {
                    x = width * noteProc.binXFactor6[bin]
                    magY = CGFloat(spectrum[bin]) * halfHeight
                    magY = min(max(0.0, magY), halfHeight)
                    y = halfHeight - magY
                    path.addLine(to: CGPoint(x: x, y: y))
                }
                path.addLine( to: CGPoint( x: width, y: halfHeight ) )  // right midpoint
                
                // Render the upper 2 octaves of the spectrum along the lower right-half of the horizontal axis:
                for bin in (lowerBin ... upperBin).reversed() {
                    x = width * noteProc.binXFactor6[bin]
                    magY = CGFloat(spectrum[bin]) * halfHeight
                    magY = min(max(0.0, magY), halfHeight)
                    y = halfHeight + magY
                    path.addLine(to: CGPoint(x: x, y: y))
                }
                
                // Render the lower 4 octaves of the muSpectrum along the upper left-half of the horizontal axis:
                for point in (lowerPoint ..< upperPoint).reversed()  {
                    upRamp =  CGFloat(point) / CGFloat(pointsPerRow)
                    x = upRamp * width
                    magY = CGFloat( muSpectrum[point] ) * halfHeight
                    magY = min(max(0.0, magY), halfHeight)
                    y = halfHeight + magY
                    path.addLine(to: CGPoint(x: x, y: y))
                }
                path.addLine( to: CGPoint( x: 0.0,   y: halfHeight))    // left midpoint
                path.closeSubpath()

            }  // end of Path
            .background( ( option > 1 ) ? backgroundColor : Color.clear )
            .foregroundStyle( ( option==0 || option==2 ) ?
                .linearGradient(hue3GradientX5, startPoint: .leading, endPoint: .trailing) :
                .linearGradient(hueGradient,  startPoint: .top,     endPoint: .bottom))


            // Print on-screen the elapsed time/frame (in milliseconds) (typically about 17)
            if(showMSPF == true) {
                HStack {
                    Text("MSPF: \( monitorPerformance() )")
                    Spacer()
                }
            }
            
        }  // end of GeometryReader
    }  // end of var body: some View
}  // end of PianoKeyboard_Live struct



struct Notes72 : View {
    @EnvironmentObject var manager: AudioManager
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        Canvas { context, size in
            let width: Double  = size.width
            let height: Double = size.height
            let columnWidth: Double = width / Double(sixOctNoteCount)
            let currentNotes: [Int] = manager.currentNotes
            
            // Paint the note with it's noteColor if it has sufficient noteScore (up to 8 current notes)
            for i in 0 ..< 8 {
                if(currentNotes[i] == 99) {break}
                let tempX: Double = Double(currentNotes[i]) * columnWidth
                context.fill(
                    Path(CGRect(x: tempX, y: 0.0, width: columnWidth, height: height)),
                    with: .color( (colorScheme == .light) ? .black.opacity(0.6) : .white.opacity(0.6)) )
            }
        }
    }
}



struct Peaks72: View {
    @EnvironmentObject var manager: AudioManager  // Observe the instance of AudioManager passed from ContentView
    @Environment(\.colorScheme) var colorScheme
    var noteProc = NoteProcessing()
    
    var body: some View {
        Canvas { context, size in
            var x: CGFloat = 0.0

            for peakNum in 0 ..< peakCount {                                            // peakCount = 16

                x = size.width * noteProc.binXFactor6[manager.peakBinNumbers[peakNum]]

                context.fill(
                    Path(CGRect(x: x, y: 0.0, width: 2.0, height: 0.05 * size.height)),
                    with: .color((colorScheme == .light) ? .black : .white) )

                context.fill(
                    Path(CGRect(x: x, y: 0.95 * size.height, width: 2.0, height: 0.05 * size.height)),
                    with: .color((colorScheme == .light) ? .black : .white) )
            }
        }
    }
}
