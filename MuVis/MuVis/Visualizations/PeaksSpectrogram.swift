//  PeaksSpectrogram.swift
//  MuVis
//
// The 16 peaks of each spectrum is rendered along a horizontal line extending from 0.0 to width.

// Cycling through the 6 "hue" colors is a convenient representation for cycling through the 12 notes of an octave:
//       red        yellow      green        cyan       blue       magenta       red
//  hue = 0          1/6         2/6         3/6         4/6         5/6          1
//        |-----------|-----------|-----------|-----------|-----------|-----------|
// note = 0     1     2     3     4     5     6     7     8     9    10    11     0
//        C     C#    D     D#    E     F     F#    G     G#    A     A#    B     C
//
// The history of these peaks is rendered vertically using 100 lines.
//
// The option button allows switching between top-to-bottom flow and right-to-left flow.
//
//          background  foreground
// option0  keyboard    top-to-bottom
// option1  keyboard    top-to-bottom   noteHistory
// option2  keyboard    right-to-left
// option3  keyboard    right-to-left   noteHistory
//
// Created by Keith Bromley in Dec 2022.
//

import SwiftUI

struct PeaksSpectrogram: View {
    @EnvironmentObject var manager: AudioManager  // Observe the instance of AudioManager passed from ContentView
    var body: some View {
        ZStack {
            if (manager.option == 0 || manager.option == 1) {           // top-to-bottom flow
                GrayVertRectangles(columnCount: 72)
                VerticalLines(columnCount: 72)
                HorizontalNoteNames(rowCount: 2, octavesPerRow: 6)
            } else {                                                    // right-to-left flow
                GrayHorRectangles(rowCount: 72)
                HorizontalLines(rowCount: 72, offset: 0.0)
                VerticalNoteNames(columnCount: 2, octavesPerColumn: 6)
            }
            PeaksSpectrogram_Live()
        }
    }
}


struct PeaksSpectrogram_Live: View {
    @EnvironmentObject var manager: AudioManager  // Observe the instance of AudioManager passed from ContentView
    let noteProc = NoteProcessing()
    
    var body: some View {

        Canvas { context, size in
            let lineCount: Int = peaksHistCount         // lineCount must be <= peaksHistCount = 100
            var boxHueTemp: Double = 0.0
            var boxHue: Double = 0.0
            var x: Double = 0.0
            var y: Double = 0.0
            var noteWidth:  Double = 0.0
            var noteHeight: Double = 0.0
            var boxWidth:  Double = 0.0
            var boxHeight: Double = 0.0

            // For each audio frame, we will render 100 * 16 = 1600 little boxes:
            if (manager.option == 0 || manager.option == 1) {               // vertical scrolling from top to bottom
                noteWidth  = size.width  / Double(sixOctNoteCount)              // sixOctNoteCount = 72
                noteHeight = size.height / Double(lineCount)                    // lineCount = 100
                boxWidth   = size.width  / Double(NoteProcessing.binCount6-1)   // binCount6 = 756
                boxHeight  = size.height / Double(lineCount)                    // lineCount = 100
            } else {                                                        // horizontal scrolling from right to left
                noteWidth  = size.width  / Double(lineCount)                    // lineCount = 100
                noteHeight = size.height / Double(sixOctNoteCount)              // sixOctNoteCount = 72
                boxWidth   = size.width  / Double(lineCount)                    // lineCount = 100
                boxHeight  = size.height / Double(NoteProcessing.binCount6-1)   // binCount6 = 756
            }

            // First, optionally render the current notes (calculated from harmonic relationships among the 16 peaks):
            if (manager.option == 1 || manager.option == 3) {
                
                let currentNotes = manager.notesHistory
                
                for lineNum in 0 ..< lineCount {       // lineNum = 0, 1, 2, ... 97, 98, 99
                    
                    // For each historical spectrum, render 8 current notes:
                    for i in 0 ..< 8 {     // 0 <= i < 8
                        
                        // We need to account for the newest data being at the end of the notesHistory array:
                        // We want lineNum = 0 (at the pane top) to render the notes of the newest spectrum:
                        let tempIndex = ( (lineCount-1 - lineNum) * 8 ) + i     // 100 * 8 = 800 note numbers
                        
                        if(currentNotes[tempIndex] == 99) {break} // Only render a box for non-zero note numbers.

                        // For each current note, render a box (rectangle) with upper left coordinates x,y:
                        if (manager.option == 0 || manager.option == 1) {   // vertical scrolling from top to bottom
                            x = noteWidth  * Double( currentNotes[tempIndex] )
                            y = noteHeight * ( Double(lineNum) )

                        } else {                                            // horizontal scrolling from right to left
                            x = noteWidth  * Double( lineCount - lineNum )
                            y = noteHeight * Double( sixOctNoteCount - currentNotes[tempIndex] - 1 )
                        }

                        context.fill(
                            Path(CGRect(x: x, y: y, width: noteWidth, height: noteHeight)),
                            with: .color(noteColorHO[ (currentNotes[tempIndex] )%12 ]) )

                        }  // end of for(i) loop
                }  // end of for(lineNum) loop
            }  // end of if(option == 1 or 3)
            


            // Second, render the 16 loudest peaks for the last 100 frames of the spectrum:
            let peaksHistory = manager.peaksHistory
            let binXFactor6 = noteProc.binXFactor6
            
            for lineNum in 0 ..< lineCount {       // lineNum = 0, 1, 2, ... 97, 98, 99
                
                // For each historical spectrum, render 16 peaks:
                for peakNum in 0 ..< peakCount{     // 0 <= peakNum < 16
                    
                    // We need to account for the newest data being at the end of the peaksHistory array:
                    // We want lineNum = 0 (at the pane top) to render the peaks of the newest spectrum:
                    let tempIndex = (lineCount-1 - lineNum) * peakCount + peakNum // 100*16=1600 bin numbers
                    
                    if(peaksHistory[tempIndex] != 0) { // Only render a box for non-zero bin numbers.
                        
                        boxHueTemp = 6.0 * binXFactor6[peaksHistory[tempIndex]]
                        boxHue = boxHueTemp.truncatingRemainder(dividingBy: 1)

                        // For each peak, render a box (rectangle) with upper left coordinates x,y:

                        if (manager.option == 0 || manager.option == 1) {   // vertical scrolling from top to bottom
                            x = size.width  * binXFactor6[peaksHistory[tempIndex]]
                            y = size.height * ( Double(lineNum) / Double(lineCount) )

                        } else {							                // horizontal scrolling from right to left
                            x = size.width  * ( 1.0 - ( Double(lineNum) / Double(lineCount) ) )
                            y = size.height * ( 1.0 - binXFactor6[peaksHistory[tempIndex]] )
                        }

                        context.fill(
                            Path(CGRect(x: x, y: y, width: boxWidth, height: boxHeight)),
                            with: .color(Color( hue: boxHue, saturation: 1.0, brightness: 1.0 )))
                    }
                }  // end of for() loop over peakNum
            }  // end of for() loop over lineNum


            // Print on-screen the elapsed duration-per-frame (in milliseconds) (typically about 50)
            if(showMSPF == true) {
                let frame = CGRect(x: 0, y: 0, width: size.width, height: size.height)
                context.draw(Text("MSPF: \( monitorPerformance() )"), in: frame )
            }

        }  // end of Canvas{}
    }  //end of var body: some View
}  // end of PeaksSpectrogram_Live struct
