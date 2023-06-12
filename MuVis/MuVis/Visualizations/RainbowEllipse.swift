/// RainbowEllipse.swift
/// MuVis
///
/// The RainbowEllipse visualization is a fun entertaining visualization.  It is a "dancing light show" choreographed to the music using the live spectrum.
/// It shows a 6-octave spectrum wrapped around an ellipse.  It stores the spectral history in a buffer and uses iterative scaling to make the older spectral values
/// drift into the center. That is, the most recent muSpectrum is rendered in the outermost ellipse, and each chronologically-older muSpectrum is rendered in the
/// adjacent inner ellipse.
///
/// Each muSpectrum is rendered clockwise starting at the twelve o'clock position.   The colors change with time. The color travels inward with the peaks.
/// If the optionOn button is selected, then a color gradient is applied to each circle such that the notes within an octave are colored similarly to the standard "hue" color cycle.
///
//          foreground
// option0  hueGradientX5
// option1  fixed octaveColor
// option2  hueGradient
// option3  time-varying out-to-in color    slow
//

/// Created by Keith Bromley on 1 March 2021. (adapted from his previous java version (called Nautilus2) in the Polaris app)
/// Significantly updated on 1 Nov 2021.


import SwiftUI


struct RainbowEllipse: View {

    @EnvironmentObject var manager: AudioManager  // Observe the instance of AudioManager passed from ContentView
    @Environment(\.colorScheme) var colorScheme
    
    static var hueOld: [Double] = [Double](repeating: 0.0, count: 64)
    static var colorIndex: Int = 0
    
    var body: some View {
    
        // Toggle between black and white as the Canvas's background color:
        let backgroundColor: Color = (colorScheme == .dark) ? Color.black : Color.white
        
        Canvas { context, size in

            let width: Double  = size.width
            let height: Double = size.height
            let X0: Double = 0.5 * width   // the origin of the ellipses
            let Y0: Double = 0.55 * height // the origin of the ellipses (Deliberately set below the halfway line)
            let A0: Double = width  / 2.0  // the horizontal radius of the largest ellipse
            let B0: Double = 0.45 * height // the vertical radius of the largest ellipse (constrained by the pane bottom)

            var x: Double = 0.0         // The drawing origin is in the upper left corner.
            var y: Double = 0.0         // The drawing origin is in the upper left corner.
            var startX: Double = 0.0
            var startY: Double = 0.0
            var endX: Double = 0.0
            var endY: Double = 0.0

            var theta:  Double = 0.0    // The angle theta starts at the 12 o'clock position and proceeds clockwise.
            var startOctTheta: Double = 0.0     // angle at start of octave
            var endOctTheta: Double = 0.0       // angle at end of octave

            var mag: Double = 0.0        // used as a preliminary part of the audio amplitude value

            let octaveCount: Int = 6
            let octaveFraction: Double = 1.0 / Double(octaveCount)      // octaveFraction = 1/6 = 0.1666666
            let pointFraction:  Double = octaveFraction / Double(pointsPerOctave)  // pointFraction = 1/(6*144)

            // ellipseCount is the number of ellipses rendered to show the history of each spectrum
            let ellipseCount: Int = historyCount    // number of ellipses rendered to show the history of the spectrum

            let colorSize: Int = 96    // This determines the frequency of the color change over time.
            RainbowEllipse.colorIndex = (RainbowEllipse.colorIndex >= colorSize) ?
                                        0 :
                                        RainbowEllipse.colorIndex + 1

            let startHue360: Int = Int( 360.0 * Double(RainbowEllipse.colorIndex) / Double(colorSize) )

            // Use local short name to improve code readablity:
            let option = manager.option
            let muSpecHistory = manager.muSpecHistory

            if( option==3 ) { manager.skipHist = 1 }else{ manager.skipHist = 0 }
            
// ---------------------------------------------------------------------------------------------------------------------
            // Render the ellipseCount ellipses - each with its own old spectrum:
            // Render octave 0 of the spectrum between the 12 o'clock and  2 o'clock ellipse positions:
            // Render octave 1 of the spectrum between the  2 o'clock and  4 o'clock ellipse positions:
            // Render octave 2 of the spectrum between the  4 o'clock and  6 o'clock ellipse positions:
            // Render octave 3 of the spectrum between the  6 o'clock and  8 o'clock ellipse positions:
            // Render octave 4 of the spectrum between the  8 o'clock and 10 o'clock ellipse positions:
            // Render octave 5 of the spectrum between the 10 o'clock and 12 o'clock ellipse positions:
            // The radius of each ellipse goes from halfWidth to near-zero:
                
            for ellipseNum in 0 ..< ellipseCount {       //  0 <= ellipseNum < 48

                let ellipseOffset: Int = ellipseNum * sixOctPointCount  // ellipseNum = 0 is the oldest spectrum

                // As ellipseNum goes from 0 to ellipseCount, ellipseRampUp goes from 0 to 1.0:
                let ellipseRampUp: Double = Double(ellipseNum) / Double(ellipseCount)

                let hue: Double = (ellipseNum == ellipseCount-1) ?
                                    Double(startHue360) / 360.0 :
                                    RainbowEllipse.hueOld[ellipseNum+1]   // 0.0 <= hue < 1.0

                for oct in 0 ..< octaveCount {     //  0 <= oct < 6
 
                    startOctTheta = Double(oct) * octaveFraction
                    startX = X0 + ellipseRampUp * A0 * Double( sin(2.0 * Double.pi * startOctTheta ) )
                    startY = Y0 - ellipseRampUp * B0 * Double( cos(2.0 * Double.pi * startOctTheta ) )

                    endOctTheta = Double(oct+1) * octaveFraction
                    endX = X0 + ellipseRampUp * A0 * Double( sin(2.0 * Double.pi * endOctTheta ) )
                    endY = Y0 - ellipseRampUp * B0 * Double( cos(2.0 * Double.pi * endOctTheta ) )

                    var path = Path()

                    if(oct==0) {                                // oct=0  theta=0  point=0
                        let startEllipseX = X0                  // x coordinate at start of ellipse
                        mag = 0.3 * Double(muSpecHistory[ellipseOffset])
                        let startEllipseY = Y0 - (ellipseRampUp * B0) - (mag * Y0 * ellipseRampUp) // y coordinate at start of ellipse
                        path.move( to: CGPoint(x: startEllipseX, y: startEllipseY) )

                    }else {
                        path.move( to: CGPoint(x: x, y: y) )    // continue on from last point in previous octave
                    }

                    // Now ensure that we read the correct spectral data from the muSpecHistory[] array:
                    let octaveOffset: Int = oct * pointsPerOctave

                    for point in 0 ..< pointsPerOctave {    // 12 * 12 = 144 = number of points per octave

                        theta = startOctTheta + ( Double(point) * pointFraction )  // 0 <= theta < 1
                        x = X0 + ellipseRampUp * A0 * Double( sin(2.0 * Double.pi * theta) )

                        let tempIndex = ellipseOffset + octaveOffset + point
                        mag = 0.3 * Double(muSpecHistory[tempIndex])
                        mag = min(max(0.0, mag), 1.0)   // Limit over- and under-saturation.
                        y = Y0 - ellipseRampUp * B0 * Double( cos(2.0 * Double.pi * theta )) - (mag * Y0 * ellipseRampUp)
                        path.addLine(to: CGPoint(x: x,  y: y ) )
                    }

                    if( option==0 ) {
                        context.stroke( path,
                                        with: .linearGradient( hueGradientX5,
                                                               startPoint: CGPoint(x: startX, y: startY),
                                                               endPoint: CGPoint(x: endX, y: endY)),
                                        lineWidth: 0.3 + ellipseRampUp * 3.0 )
                        
                    }else if( option==2 ) {
                        context.stroke( path,
                                        with: .linearGradient( hueGradient,
                                                               startPoint: CGPoint(x: startX, y: startY),
                                                               endPoint: CGPoint(x: endX, y: endY)),
                                        lineWidth: 0.3 + ellipseRampUp * 3.0 )
                        
                    }else if( option==1 ) {
                        let hue: Double = Double(oct) * octaveFraction
                        context.stroke( path,
                                        with: .color(Color(hue: hue, saturation: 1.0, brightness: 1.0)),
                                        lineWidth:  0.1 + (ellipseRampUp * 3.0) )
                                        // lineWidth:  0.3 )
                        
                    }else if( option==3 ) {
                        context.stroke( path,
                                        with: .color(Color(hue: hue, saturation: 1.0, brightness: 1.0)),
                                        lineWidth:  0.1 + (ellipseRampUp * 3.0) )
                    }
                    
                } // end of for() loop over oct
                
                RainbowEllipse.hueOld[ellipseNum] = hue
                
            }  // end of for() loop over hist


            // Print on-screen the elapsed duration-per-frame (in milliseconds) (typically about 50)
            if(showMSPF == true) {
                let frame = CGRect(x: 0, y: 0, width: size.width, height: size.height)
                context.draw(Text("MSPF: \( monitorPerformance() )"), in: frame )
            }


        }  // end of Canvas{}
        .background(backgroundColor)  // Toggle between black and white background color.
        
    }  // end of var body: some View{}
}  // end of RainbowEllipse{} struct
