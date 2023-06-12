/// TriOctSpectrum.swift
/// MuVis
///
/// The TriOctSpectrum visualization is similar to the LinearOAS visualization in that it shows a muSpectrum of six octaves of the audio waveform -
/// however it renders it as two separate muSpectrum displays.
///
/// It has the format of a downward-facing muSpectrum in the lower half-screen covering the lower three octaves, and an upward-facing Music Spectrum in the upper
/// half-screen covering the upper three octaves. Each half screen shows three octaves. (The name "bi- tri-octave muSpectrum" seemed unduly cumbersome,
/// so I abbreviated it to "tri-octave spectrum"). The specific note frequencies are:
//
//
//        | bin=95                    bin=188 | bin=189                   bin=377 | bin=378                  bin=755 |
//        262 Hz                              523 Hz                             1046 Hz                         1976 Hz
//        C4                                  C5                                  C6                               B6
//         |                                   |                                   |                                |
//         W  B  W  B  W  W  B  W  B  W  B  W  W  B  W  B  W  W  B  W  B  W  B  W  W  B  W  B  W  W  B  W  B  W  B  W
//
//         W  B  W  B  W  W  B  W  B  W  B  W  W  B  W  B  W  W  B  W  B  W  B  W  W  B  W  B  W  W  B  W  B  W  B  W
//         |                                   |                                   |                                |
//         C1                                 C2                                  C3                               B3
//         33Hz                               65 Hz                              130 Hz                           247 Hz
//       | bin=12                      bin=23 | bin=24                     bin=47 | bin=48                    bin=94 |
//
//
//
/// As with the Piano Keyboard visualization, the spectral peaks comprising each note are a separate color, and the colors of the grid are consistent across all
/// octaves - hence all octaves of a "C" note are red; all octaves of an "E" note are green, and all octaves of a "G" note are light blue, etc.
/// Also, we have added a piano-keyboard overlay to clearly differentiate the black notes (in gray) from the white notes (in white).
/// Also, we have added note names for the white notes at the top and bottom.
///
//          background  foreground
// option0  keyboard    horGradient verLines    NoteNames
// option1  keyboard    verGradient verLines    NoteNames   notes
// option2  plain       horGradient verLines                peaks
// option3  plain       verGradient
///
/// Created by Keith Bromley in  May 2023.


import SwiftUI


struct TriOctSpectrum: View {
    @EnvironmentObject var manager: AudioManager  // We observe the instance of AudioManager passed from ContentView.
    var body: some View {
        let option = manager.option     // Use local short name to improve code readablity.
        ZStack {
            if( option < 2 ) { GrayVertRectangles(columnCount: 36) }                // struct code in VisUtilities file
            TriOctSpectrum_Live()
            if( option < 3 ) { VerticalLines(columnCount: 36) }                     // struct code in VisUtilities file
            if( option < 3 ) { HorizontalLines(rowCount: 2, offset: 0.0) }          // struct code in VisUtilities file
            if( option < 2 ) { HorizontalNoteNames(rowCount: 2, octavesPerRow: 3) } // struct code in VisUtilities file
            if( option==1 ) { Notes36() }
            if( option==2 ) { Peaks36() }
        }
    }
}



struct TriOctSpectrum_Live : View {
    @EnvironmentObject var manager: AudioManager  // We observe the instance of AudioManager passed from ContentView.
    @Environment(\.colorScheme) var colorScheme
    var noteProc = NoteProcessing()

    var body: some View {

        // Toggle between black and white as the Canvas's background color:
        let backgroundColor: Color = (colorScheme == .dark) ? Color.black : Color.white

        GeometryReader { geometry in

            let width  : CGFloat = geometry.size.width
            let height : CGFloat = geometry.size.height
            let halfHeight : CGFloat = height * 0.5
            var x: CGFloat = 0.0       // The drawing origin is in the upper left corner.
            var y: CGFloat = 0.0       // The drawing origin is in the upper left corner.
            var upRamp : CGFloat = 0.0
            var magY: CGFloat = 0.0     // used as a preliminary part of the "y" value
            let octavesPerRow : Int = 3
            let octaveWidth: CGFloat = width / CGFloat(octavesPerRow)
            let pointsPerRow : Int = pointsPerNote * notesPerOctave * octavesPerRow  //  12 * 12 * 3 = 432

            // Use local short name to improve code readablity:
            let spectrum = manager.spectrum
            let muSpectrum = manager.muSpectrum
            let option = manager.option

            // Render the lower 3 octaves of the muSpectrum in the lower half-pane:
            Path { path in
                path.move( to: CGPoint( x: 0.0,   y: halfHeight))       // left midpoint

                for point in 1 ..< pointsPerRow {                       // pointsPerRow = 12 * 12 * 3 = 432
                    upRamp =  CGFloat(point) / CGFloat(pointsPerRow)    // upRamp goes from 0.0 to 1.0 as point goes from 0 to pointsPerRow
                    x = upRamp * width
                    magY = CGFloat(muSpectrum[point]) * halfHeight
                    magY = min(max(0.0, magY), halfHeight)
                    y = halfHeight + magY
                    path.addLine(to: CGPoint(x: x, y: y))
                }
                path.addLine( to: CGPoint( x: width, y: halfHeight ) )  // right midpoint

                // Render the upper 3 octaves of the spectrum in the upper half-pane:
                for oct in ( 3 ... 5 ).reversed() {

                    for bin in ( noteProc.octBottomBin[oct] ... noteProc.octTopBin[oct] ).reversed() {
                        x = ( Double(oct-3) * octaveWidth ) + ( noteProc.binXFactor[bin] * octaveWidth )
                        magY = Double(spectrum[bin]) * halfHeight
                        magY = min(max(0.0, magY), halfHeight)
                        y = halfHeight - magY
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
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
}  // end of TriOctSpectrum_Live struct



struct Notes36 : View {
    @EnvironmentObject var manager: AudioManager  // We observe the instance of AudioManager passed from ContentView.
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        Canvas { context, size in
            let width: Double  = size.width
            let height: Double = size.height
            let halfHeight: Double = height * 0.5
            let columnWidth: Double = width / Double(sixOctNoteCount/2)
            let currentNotes: [Int] = manager.currentNotes
            
            // Paint the note with it's noteColor if it has sufficient noteScore (up to 8 current notes)
            for i in 0 ..< 8 {
                if(currentNotes[i] == 99) {break}

                if(currentNotes[i] <= 36) {                                             // lower 3 octaves
                    let tempX: Double = Double(currentNotes[i]) * columnWidth
                    context.fill(
                        Path(CGRect(x: tempX, y: halfHeight, width: columnWidth, height: height)),
                        with: .color( (colorScheme == .light) ? .black.opacity(0.2) : .white.opacity(0.6)) )
                } else {                                                                // upper 3 octaves
                    let tempX: Double = Double(currentNotes[i] - 36)  * columnWidth
                    context.fill(
                        Path(CGRect(x: tempX, y: 0.0, width: columnWidth, height: halfHeight)),
                        with: .color( (colorScheme == .light) ? .black.opacity(0.2) : .white.opacity(0.6)) )
                }
            }
        }
    }
}  // end of Notes36 struct



struct Peaks36: View {
    @EnvironmentObject var manager: AudioManager  // Observe the instance of AudioManager passed from ContentView
    @Environment(\.colorScheme) var colorScheme
    var noteProc = NoteProcessing()
    
    var body: some View {
        Canvas { context, size in
            let width:  Double = size.width
            let height: Double = size.height
            var tempD : Double = 0.0
            let peakBinNumbers = manager.peakBinNumbers             // Use local short name to improve code readablity.
            
            for peakNum in 0 ..< peakCount {                        // peakCount = 16

                if(peakBinNumbers[peakNum] == 0) {break}         // Only render non-zero peaks.
                
                if(peakBinNumbers[peakNum] <= 94) {                 // octaves 0, 1, 2          Octave 2 ends at bin 94.
                    // render the spectrum bins from 12 to 94:
                    tempD = noteProc.binXFactor3[manager.peakBinNumbers[peakNum]]
                    context.fill(
                        Path(CGRect(x: tempD * width, y: 0.95 * height, width: 2.0, height: 0.05 * height)),
                        with: .color((colorScheme == .light) ? .black : .white) )
                }else{                                              // octaves 3, 4, 5        Octave 3 begins at bin 95.
                    // render the spectrum bins from 95 to 755:
                    tempD = noteProc.binXFactor36[manager.peakBinNumbers[peakNum]]
                    context.fill(
                        Path(CGRect(x: tempD * width, y: 0.0, width: 2.0, height: 0.05 * height)),
                        with: .color((colorScheme == .light) ? .black : .white) )
                }
            }
        }
    }
}

