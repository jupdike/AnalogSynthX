//
//  Preset.swift
//  AnalogSynthX
//
//  Created by Jared Updike on 7/5/20.
//  Copyright © 2020 AudioKit. All rights reserved.
//

import Foundation

public struct Preset: Codable {
    let delayEnabled, reverbEnabled, fattenEnabled: Bool
    let delayTime, delayMix, reverbAmount, reverbMix: Double
    
    let vco1Enabled, vco2Enabled: Bool
    let vcoWaveform1, vcoWaveform2: Int
    let osc1Semitones, osc2Semitones: Int
    let oscMix, osc2Detune, subMix, oscMorph: Double
    let fmMix, fmMod: Double
    
    let lfoWaveform: Int
    let lfoAmount, lfoRate: Double
    
    let filterCutoff, filterResonance: Double
    let filterEnabled, bitcrushEnabled: Bool
    let crushAmount: Double
    let noiseMix: Double
    
    let holdEnabled, monoEnabled: Bool
    
    let attackDuration, decayDuration, sustainLevel, releaseDuration: Double
    let masterVolume: Double
    
    func toString() -> String {
        let encoder = JSONEncoder()

        var data: Data? = nil
        do {
            data = try encoder.encode(self)
        }
        catch {
            print("there was an error: \(error)")
        }
        let output = String(data: data!, encoding: .utf8)!
        return output
    }
}
