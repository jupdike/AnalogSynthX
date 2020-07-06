//
//  Conductor.swift
//  AnalogSynthX
//
//  Created by Aurelius Prochazka, revision history on Github.
//  Copyright © 2018 AudioKit. All rights reserved.
//

import AudioKit

class Conductor: AKMIDIListener {
    /// Globally accessible singleton
    static let sharedInstance = Conductor()

    var core = GeneratorBank()
    var bitCrusher: AKBitCrusher
    var fatten: Fatten
    var filterSection: FilterSection
    var multiDelay: MultiDelay
    var multiDelayMixer: AKDryWetMixer

    var masterVolume = AKMixer()
    var reverb: AKCostelloReverb
    var reverbMixer: AKDryWetMixer

    var midiBendRange: Double = 2.0

    init() {
        AKSettings.audioInputEnabled = true
        bitCrusher = AKBitCrusher(core)
        bitCrusher.stop()

        filterSection = FilterSection(bitCrusher)
        filterSection.output.stop()

        fatten = Fatten(filterSection)
        multiDelay = MultiDelay(fatten)
        multiDelayMixer = AKDryWetMixer(fatten, multiDelay, balance: 0.0)

        masterVolume = AKMixer(multiDelayMixer)
        reverb = AKCostelloReverb(masterVolume)
        reverb.stop()

        reverbMixer = AKDryWetMixer(masterVolume, reverb, balance: 0.0)

        // uncomment this to allow background operation
        // AKSettings.playbackWhileMuted = true

        AudioKit.output = reverbMixer
        do {
            try AudioKit.start()
        } catch {
            AKLog("AudioKit did not start!")
        }
        //Audiobus.start()

        let midi = AudioKit.midi
        midi.createVirtualPorts()
        midi.openInput(name: "Session 1")
        midi.addListener(self)
    }

    static func reverseCutoffFreqFromValue(_ value: Double) -> Double {
        // Logarithmic scale: reverse knobvalue to frequency
        let unscaledValue = Double.reverseScaleRangeLog(value / 4.0, rangeMin: 30, rangeMax: 7_000)
        return unscaledValue
    }
    
    static func cutoffFreqFromValue(_ value: Double) -> Double {
        // Logarithmic scale: frequency to knobvalue
        let scaledValue = Double.scaleRangeLog(value, rangeMin: 30, rangeMax: 7_000)
        return scaledValue * 4
    }
    
    //---------

    static func crusherFreqFromValue(_ value: Double) -> Double {
        // Logarithmic scale: reverse knobvalue to frequency
        let value = 1 - value
        let scaledValue = Double.scaleRangeLog(value, rangeMin: 50, rangeMax: 8_000)
        return scaledValue
    }
    
    static func reverseCrusherFreqFromValue(_ value: Double) -> Double {
        // Logarithmic scale: reverse knobvalue to frequency
        let unscaledValue = Double.reverseScaleRangeLog(value, rangeMin: 50, rangeMax: 8_000)
        return 1 - unscaledValue
    }
    
    func savePreset(holdEnabled: Bool, monoEnabled: Bool) -> Preset {
        let conductor = self
        return Preset(
            delayEnabled: conductor.multiDelayMixer.balance > 0,
            reverbEnabled: !conductor.reverb.isBypassed,
            fattenEnabled: conductor.fatten.dryWetMix.balance > 0,
            delayTime: conductor.multiDelay.time,
            delayMix: conductor.multiDelay.mix,
            reverbAmount: conductor.reverb.feedback,
            reverbMix: conductor.reverbMixer.balance,
            
            vco1Enabled: conductor.core.vco1On,
            vco2Enabled: conductor.core.vco2On,
            vcoWaveform1: Int(conductor.core.waveform1),
            vcoWaveform2: Int(conductor.core.waveform2),
            osc1Semitones: conductor.core.offset1,
            osc2Semitones: conductor.core.offset2,
            oscMix: conductor.core.vcoBalancer.balance,
            osc2Detune: conductor.core.vco2.vibratoDepth,
            subMix: conductor.core.subOscMixer.volume,
            oscMorph: conductor.core.morph,
            fmMix: conductor.core.fmOscMixer.volume,
            fmMod: conductor.core.fmOsc.modulationIndex,
            lfoWaveform: Int(conductor.filterSection.lfoIndex),
            lfoAmount: conductor.filterSection.lfoAmplitude,
            lfoRate: conductor.filterSection.lfoRate,
            
            filterCutoff: Conductor.reverseCutoffFreqFromValue(conductor.filterSection.cutoffFrequency),
            filterResonance: conductor.filterSection.resonance,
            filterEnabled: conductor.filterSection.output.isStarted,

            bitcrushEnabled: !conductor.bitCrusher.isBypassed,
            crushAmount: Conductor.reverseCrusherFreqFromValue(conductor.bitCrusher.sampleRate),
            noiseMix: conductor.core.noiseMixer.volume,

            holdEnabled: holdEnabled,
            monoEnabled: monoEnabled,
            
            attackDuration: conductor.core.attackDuration,
            decayDuration: conductor.core.decayDuration,
            sustainLevel: conductor.core.sustainLevel,
            releaseDuration: conductor.core.releaseDuration,
            masterVolume: conductor.masterVolume.volume
        )
    }
    
    func loadPreset(_ preset: Preset) {
        let conductor = self
        conductor.multiDelay.time = preset.delayTime
        conductor.multiDelay.mix = preset.delayMix
        conductor.multiDelayMixer.balance = preset.delayEnabled ? 1 : 0

        conductor.reverb.feedback = preset.reverbAmount
        conductor.reverbMixer.balance = preset.reverbMix
        if preset.reverbEnabled {
            conductor.reverb.start()
        } else {
            conductor.reverb.bypass()
        }
        conductor.core.vco1On = preset.vco1Enabled
        conductor.core.vco2On = preset.vco2Enabled
        
        conductor.core.noiseMixer.volume = preset.noiseMix
        
        conductor.bitCrusher.sampleRate = Conductor.crusherFreqFromValue(Double(preset.crushAmount))
        if preset.bitcrushEnabled {
           conductor.bitCrusher.start()
        } else {
            conductor.bitCrusher.bypass()
        }

        if preset.filterEnabled {
            conductor.filterSection.output.start()
        } else {
            conductor.filterSection.output.stop()
        }

        conductor.fatten.dryWetMix.balance = preset.fattenEnabled ? 1 : 0

        conductor.core.attackDuration = preset.attackDuration
        conductor.core.decayDuration = preset.decayDuration
        conductor.core.sustainLevel = preset.sustainLevel
        conductor.core.releaseDuration = preset.releaseDuration
        
        conductor.masterVolume.volume = preset.masterVolume
        
        conductor.core.waveform1 = Double(preset.vcoWaveform1)
        conductor.core.waveform2 = Double(preset.vcoWaveform2)
        
        conductor.core.morph = preset.oscMorph
        conductor.core.vcoBalancer.balance = preset.oscMix
        conductor.core.subOscMixer.volume = preset.subMix
        conductor.core.vco2.vibratoDepth = preset.osc2Detune
        conductor.core.offset1 = preset.osc1Semitones
        conductor.core.offset2 = preset.osc2Semitones
        
        conductor.filterSection.lfoIndex = min(Double(preset.lfoWaveform), 3)
        conductor.filterSection.lfoAmplitude = preset.lfoAmount
        conductor.filterSection.lfoRate = preset.lfoRate
        
        conductor.filterSection.resonance = preset.filterResonance
        conductor.filterSection.cutoffFrequency = Conductor.cutoffFreqFromValue(preset.filterCutoff)
        
        conductor.core.fmOscMixer.volume = preset.fmMix
        conductor.core.fmOsc.modulationIndex = preset.fmMod
    }

    class func docRoot() -> String {
        if let direc: NSString = NSSearchPathForDirectoriesInDomains(FileManager.SearchPathDirectory.documentDirectory, FileManager.SearchPathDomainMask.allDomainsMask, true).first as NSString? {
            return direc as String
        }
        return "THIS_IS_BAD"
    }

    class func getDocsFileAsData(_ fname: String, ext: String, failure: @escaping () -> (), success: @escaping (Data) -> () ) {
        let url = URL(fileURLWithPath: docRoot() + "/" + fname + "." + ext)
        do {
            let data = try Data(contentsOf: url)
            success(data)
        } catch {
            print("could not load file as data")
            failure()
        }
    }
    
    class func haveRootFile(_ f: String) -> Bool {
        let path = docRoot() + "/" + f
        let ret = FileManager.default.fileExists(atPath: path)
        return ret
    }
    
    // MARK: - AKMIDIListener protocol functions

    func receivedMIDINoteOn(noteNumber: MIDINoteNumber,
                            velocity: MIDIVelocity,
                            channel: MIDIChannel) {
        core.play(noteNumber: noteNumber, velocity: velocity)
    }
    func receivedMIDINoteOff(noteNumber: MIDINoteNumber,
                             velocity: MIDIVelocity,
                             channel: MIDIChannel) {
        core.stop(noteNumber: noteNumber)
    }
    func receivedMIDIPitchWheel(_ pitchWheelValue: MIDIWord, channel: MIDIChannel) {
        let bendSemi = (Double(pitchWheelValue - 8_192) / 8_192.0) * midiBendRange
        core.globalbend = bendSemi
    }

}
