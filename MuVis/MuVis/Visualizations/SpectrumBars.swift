/// SpectrumBarsVis.swift
/// MuVis
///
/// This is basically the same as the Music Spectrum visualization - but with much fancier dynamic graphics.
///
/// This visualization was adapted from Matt Pfeiffer's tutorial "Audio Visualizer Using AudioKit and SwiftUI" at
/// https://audiokitpro.com/audiovisualizertutorial/
/// https://github.com/Matt54/SwiftUI-AudioKit-Visualizer
/// I believe that this is copied from the FFTView visualization within the AudioKitUI framework.
///
/// Adapted from Matt's turorial by Keith Bromley in Nov 2021.

import SwiftUI


struct SpectrumBars: View {
    @EnvironmentObject var manager: AudioManager  // Observe the instance of AudioManager passed from ContentView
    @Environment(\.colorScheme) var colorScheme
    
    var linearGradient : LinearGradient = LinearGradient( gradient: Gradient(colors: [.red, .yellow, .green]),
                                                          startPoint: .top,
                                                          endPoint: .center)
    var paddingFraction: CGFloat = 0.2
    var includeCaps: Bool = true

    var body: some View {

        // We will render a muSpectrum covering four octave (from C2 to B5):
        let bottomNote: Int = 12
        let topNote: Int = 12 + 47

        HStack(spacing: 0.0) {
            ForEach( bottomNote ..< topNote, id: \.self ) { note in
                
                AmplitudeBar(amplitude: manager.muSpectrum[12*note+6],
                            linearGradient: linearGradient,
                            paddingFraction: paddingFraction,
                            includeCaps: includeCaps)
            }
            //  The muSpectrum[] array uses pointsPerNote = 12.  Therefore:
            //  The midpoints between notes are at index = 12*note = 0, 12, 24, 36, 48, ...
            //  The centerpoints of the notes are at index = 12*note+6 = 6, 18, 30, 42, 54, ...
        }
        .drawingGroup() // Metal powered rendering
        .background((colorScheme == .light) ? .white : .black)

        // Print on-screen the elapsed time/frame (in milliseconds) (typically about 17)
        if(showMSPF == true) {
            HStack {
                Text("MSPF: \( monitorPerformance() )")
                Spacer()
            }
        }
    }
}  // end of SpectrumBars struct



struct AmplitudeBar: View {
    @EnvironmentObject var manager: AudioManager  // Observe the instance of AudioManager passed from ContentView
    @Environment(\.colorScheme) var colorScheme
    var amplitude: Float
    var linearGradient : LinearGradient
    var paddingFraction: CGFloat = 0.2
    var includeCaps: Bool = true

    var body: some View {
        GeometryReader { geometry in

            let duration1: Double = (manager.option==0) ? 1.0 : (manager.option==1) ? 2 : (manager.option==2) ? 4 : 8
            
            ZStack(alignment: .bottom){

                // Colored rectangle in back of ZStack
                Rectangle()
                    .fill(self.linearGradient)

                // Dynamic white-or-black mask padded extending downward from the pane top to the spectral amplitude:
                Rectangle()
                    .fill((colorScheme == .light) ? .white : .black) // Toggle between black and white background color.
                    .mask(Rectangle().padding(.bottom, geometry.size.height * CGFloat(amplitude)))
                    .animation(.easeOut(duration: duration1),value: amplitude)

                // White bar with slower animation for floating effect
                if(includeCaps){
                    addCap(width: geometry.size.width, height: geometry.size.height)
                }
            }
            .padding(geometry.size.width * paddingFraction / 2)
            .border((colorScheme == .light) ? .white : .black, width: geometry.size.width*paddingFraction/2)
        }
    }

    // Creates the Cap View - seperate method allows variable definitions inside a GeometryReader
    func addCap(width: CGFloat, height: CGFloat) -> some View {
        let padding = width * paddingFraction / 2
        let capHeight = height * 0.005
        let capDisplacement = height * 0.02
        let capOffset = -height * CGFloat(amplitude) - capDisplacement - padding * 2
        let capMaxOffset = -height + capHeight + padding * 2
        let duration2: Double = (manager.option==0) ? 2.0 : (manager.option==1) ? 4.0 : (manager.option==2) ? 8.0 : 16.0

        
        return Rectangle()
            .fill((colorScheme == .light) ? .black : .white)
            .frame(height: capHeight)
            .offset(x: 0.0, y: ( -height > (capOffset - capHeight) ) ? capMaxOffset : capOffset)
            //ternary prevents offset from pushing cap outside of it's frame
            .animation(.easeOut(duration: duration2), value: capOffset)
    }

}  // end of AmplitudeBar struct
