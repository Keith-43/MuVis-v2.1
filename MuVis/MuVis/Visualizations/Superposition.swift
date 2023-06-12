//  Superposition.swift
//  MuVis

//  In this visualization, for each frame of live audio data, we generate a sinusoidal waveform for each of it's 16 peak frequencies.  We then sum these 16 sinusoidal waveforms and render the resulting superposition.  We take care to ensure that the phase of each waveform starts at zero on the left side of the display pane.  So all of the 16 waveforms are jointly "in-phase".

//  One can think of this visualization as being an oscilloscope display of the original input audio waveform where all of the frequencies have been "magically" made to have a constant phase (instead of a chaotic wildly-dynamic phase which makes most oscilloscope types of display extremely difficult to interpret).

//  In the normal mode, the waveforms are 256 samples in length to show the fine detail of the superposition.  In the optionOn mode, the waveforms are 1024 samples in length to better represent the overall superposition shape.

//  https://sarunw.com/posts/gradient-in-swiftui/#lineargradient

//          DataLength	AnimationDuration
// option0  1024  		0.5
// option1  1024        3.0
// option2  256         0.5
// option3  256         3.0
//
//  Created by Keith Bromley in Sep 2022.


import SwiftUI
import Combine

struct Superposition: View {
    @EnvironmentObject var manager: AudioManager  // Observe the instance of AudioManager passed from ContentView
    @Environment(\.colorScheme) var colorScheme

    var body: some View {

        // Toggle between black and white as the Canvas's background color:
        let backgroundColor: Color = (colorScheme == .dark) ? Color.black : Color.white
        
        let duration: Double = (manager.option==0 || manager.option==2) ? 0.5 : 3.0
        
        if(manager.option < 2) {
            // Convert the observed array-of-Floats into an AnimatableVector:
            let sumWaveformsA = AnimatableVector(values: generateWaveform( binNumbers: manager.peakBinNumbers,
                                                                           myDataLength: 1024))
            
            Superposition_Shape(myDataLength: 1024, vector: sumWaveformsA)
                .stroke(Color( (colorScheme == .dark) ? .white : .black), lineWidth: 2)
                .animation(Animation.linear(duration: duration), value: sumWaveformsA)
                .background(LinearGradient(gradient: Gradient(colors: [ .blue,
                                                                        backgroundColor,
                                                                        .blue ] ),
                                           startPoint: .top,
                                           endPoint: .bottom)
                )
        }
        
        else {
            // Convert the observed array-of-Floats into an AnimatableVector:
            let sumWaveformsA = AnimatableVector(values: generateWaveform( binNumbers: manager.peakBinNumbers,
                                                                           myDataLength: 256))
            
            Superposition_Shape(myDataLength: 256, vector: sumWaveformsA)
                .stroke(Color( (colorScheme == .dark) ? .white : .black), lineWidth: 2)
                .animation(Animation.linear(duration: duration), value: sumWaveformsA)
                .background(LinearGradient(gradient: Gradient(colors: [ .red,
                                                                        backgroundColor,
                                                                        .red ] ),
                                           startPoint: .top,
                                           endPoint: .bottom)
                )
        }
    }
} // end of Superposition struct



struct Superposition_Shape: Shape {
    var myDataLength: Int
    var vector: AnimatableVector        // Declare a variable called vector of type Animatable vector

    public var animatableData: AnimatableVector {
        get { vector }
        set { vector = newValue }
    }

    public func path(in rect: CGRect) -> Path {
        let width: Double  = rect.width
        let height: Double = rect.height
        var x : Double = 0.0       // The drawing origin is in the upper left corner.
        var y : Double = 0.0       // The drawing origin is in the upper left corner.
        let halfHeight: Double = height * 0.5

        var upRamp: Double = 0.0
        var magY: Double = 0.0      // used as a preliminary part of the "y" value

        var path = Path()
        path.move(to: CGPoint( x: 0.0, y: halfHeight ) )

        for sample in 0 ..< myDataLength {
            // upRamp goes from 0.0 to 1.0 as bin goes from lowerBin to upperBin:
            upRamp =  Double(sample) / Double(myDataLength)
            x = upRamp * width

            magY = Double(vector[sample]) * halfHeight
            magY = min(max(-halfHeight, magY), halfHeight)
            y = halfHeight - magY
            path.addLine(to: CGPoint(x: x, y: y))
        }
        path.addLine(to: CGPoint(x: width, y: halfHeight))
        return path
    }
}



public func generateWaveform(binNumbers: [Int], myDataLength: Int) -> ([Float]) {
    var outputArray: [Float] = [Float] (repeating: 0.0, count: myDataLength)
    var waveform: [Float] = [Float] (repeating: 0.0, count: myDataLength)
    var angle: Double = 0.0
    let constant: Double = 5.0 * AudioManager.binFreqWidth / AudioManager.sampleRate // The 5.0 is ad hoc for aesthetics.

    for peakNum in 0 ..< peakCount {

        let amplitude: Float =  0.5 * ( 1.0 + ( Float(peakNum) / Float(peakCount) ) )  // 0.5 <= amplitude <= 1.0

        for sample in 0 ..< myDataLength {
            angle = 2.0 * Double.pi * Double(sample) * Double(binNumbers[peakNum]) * 5.0 * constant
            waveform[sample] = 0.1 * amplitude * Float(sin(angle)) // The 0.1 is ad hoc for aesthetics.
            outputArray[sample] += waveform[sample]
        }
    }
    return outputArray
}
