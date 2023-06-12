//  Waterfall.swift
//  MuVis
//
//          background  foreground
// option0  keyboard    time-varying color  verLines    NoteNames
// option1  keyboard    horGradientX5       verLines    NoteNames
// option2  plain       time-varying color
// option3  plain       horGradient                                 slow
//
//  Created by Keith Bromley on 24 Aug 2021.  Improved in Jan 2022.  Improved in May 2023.
//

import SwiftUI

struct Waterfall: View {
    @EnvironmentObject var manager: AudioManager    // Observe instance of AudioManager passed to us from ContentView.
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        let option = manager.option                 // Use local short name to improve code readablity.
        let backgroundColor: Color = colorScheme == .dark ? Color.black : Color.white
        
        GeometryReader { geometry in
            ZStack {
                GrayVertRectangles(columnCount: 72)
                VerticalLines(columnCount: 72)
                HorizontalNoteNames(rowCount: 1, octavesPerRow: 6)
                Waterfall_Live()
                    .background( option < 2 ? Color.clear : backgroundColor )
                    // Toggle between keyboard overlay and background color.
            }
        }
    }
}


struct Waterfall_Live: View {
    @EnvironmentObject var manager: AudioManager  // Observe instance of AudioManager passed from ContentView.
    
    static var colorIndex: Int = 0
    
    var body: some View {

        Canvas { context, size in

            let width: Double  = size.width
            let height: Double = size.height
            let quarterHeight: Double  = height * 0.25
            let threeQuartersHeight: Double  = height * 0.75
            
            var x : Double = 0.0       // The drawing origin is in the upper left corner.
            var y : Double = 0.0       // The drawing origin is in the upper left corner.

            let lineCount: Int = 48         // lineCount must be <= historyCount
            var lineRampUp: Double = 0.0
            
            let colorSize: Int = 20_000    // This determines the frequency of the color change over time.
            var hue: Double = 0.0

            // Use local short name to improve code readablity:
            let muSpecHistory = manager.muSpecHistory
            let option = manager.option
            
            if( option==3 ) { manager.skipHist = 1 }else{ manager.skipHist = 0 }
            
//---------------------------------------------------------------------------------------------------------------------
            for lineNum in 0 ..< lineCount {       //  0 <= lineNum < 48
            
                // Account for the newest data being at the end of the muSpecHistory array:
                // We want lineNum = 0 (at the pane top) to render the newest muSpectrum:
                let lineOffset: Int = (historyCount-1 - lineNum) * sixOctPointCount
            
                // As lineNum goes from 0 to lineCount, lineRampUp goes from 0.0 to 1.0:
                lineRampUp = Double(lineNum) / Double(lineCount)
                
                // Each spectrum is rendered along a horizontal line.
                let pointWidth: Double = width / Double(sixOctPointCount)  // pointsPerRow = 72 * 12 = 864
                
                let ValY: Double = lineRampUp * threeQuartersHeight
                    
                var path = Path()
                path.move( to: CGPoint( x: 0.0, y: quarterHeight + ValY ) )
                
                // For each historical spectrum, render sixOctPointCount (72 * 12 = 864) points:
                for point in 0 ..< sixOctPointCount{     // 0 <= point < 864
                    
                    x = 0.0 + ( Double(point) * pointWidth )
                    x = min(max(0.0, x), width);
                    
                    let tempIndex = lineOffset + point
                    let mag: Double = 0.3 * Double( muSpecHistory[tempIndex] )
                    let magY = mag * quarterHeight
                    y = quarterHeight + ValY - magY
                    path.addLine(to: CGPoint(x: x, y: y))
                }
                path.addLine( to: CGPoint( x: width, y:  quarterHeight + ValY))
                
                Waterfall_Live.colorIndex = (Waterfall_Live.colorIndex >= colorSize) ? 0 : Waterfall_Live.colorIndex + 1
                hue = Double(Waterfall_Live.colorIndex) / Double(colorSize)                    // 0.0 <= hue < 1.0

                if( option==0 ||  option==2 ) {
                    context.stroke( path,
                                    with: .color(Color(hue: hue, saturation: 1.0, brightness: 1.0)),
                                    lineWidth: 2.0 )
                    
                } else if( option==1 ) {
                    context.stroke( path,
                                    with: .linearGradient( hue6GradientX5,
                                                           startPoint: CGPoint(x: 0.0, y: 1.0),
                                                           endPoint: CGPoint(x: size.width, y: 1.0)),
                                    lineWidth: 2.0 )
                    
                } else if( option==3 ) {
                    context.stroke( path,
                                    with: .linearGradient( hue6Gradient,
                                                           startPoint: CGPoint(x: 0.0, y: 1.0),
                                                           endPoint: CGPoint(x: size.width, y: 1.0)),
                                    lineWidth: 2.0 )
                }
                
            }  // end of for() loop over lineNum



            // Print on-screen the elapsed duration-per-frame (in milliseconds) (typically about 50)
            if(showMSPF == true) {
                let frame = CGRect(x: 0, y: 0, width: size.width, height: size.height)
                context.draw(Text("MSPF: \( monitorPerformance() )"), in: frame )
            }

        }  // end of Canvas
    }  //end of var body: some View
}  // end of Waterfall_Live struct
