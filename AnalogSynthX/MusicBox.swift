//
//  MusicBox.swift
//  AnalogSynthX
//
//  Created by Jared Updike on 7/4/20.
//  Copyright © 2020 AudioKit. All rights reserved.
//

import Foundation
import AudioKit
import AudioKitUI

class MusicBox {
    init() {

    }

    var conductor = Conductor.sharedInstance

//    let sampler = AKAppleSampler()
//    try sampler.loadWav("Samples/FM Piano")
//
//    var delay = AKDelay(sampler)
//    delay.time = pulse * 1.5
//    delay.dryWetMix = 0.1
//    delay.feedback = 0.1
//
//    let reverb = AKReverb(delay)
//    reverb.loadFactoryPreset(.largeRoom)
//
//    var mixer = AKMixer(reverb)
//    mixer.volume = 5.0
//
//    AudioKit.output = mixer
//    try AudioKit.start()

    //: This is a loop to send a random note to the sampler
    func isValid(_ note: Int, fromValidNotes: [Int]) -> Bool {
        for n in fromValidNotes {
            if note % 12 == n % 12 {
                return true
            }
        }
        return false
    }
    func closestValidNote(_ note: Int, fromValidNotes notes: [Int]) -> Int {
        for delta in (0 ... 6) {
            let n0 = note + delta
            if isValid(n0, fromValidNotes: notes) {
                return n0
            }
            let n1 = note - delta
            if isValid(n1, fromValidNotes: notes) {
                return n1
            }
        }
        return 0
    }

    // 0 1 2 3 4 5 6
    // C d e F g a b
    //
    //             C,         a,         F,         d,         bdim,      e,         G
    let triads = [[0, 2, 4], [5, 0, 2], [3, 5, 0], [1, 3, 5], [6, 1, 3], [2, 4, 6], [4, 6, 1]]
    lazy var numChords: Int = {
        return triads.count
    }()
    let scale = [0, 2, 4, 5, 7, 9, 11]

    var reverseDeltaStack: [Int] = []
    var lastTriadIndex = 0
    var rootOffset = 0
    var count = 0

    func playNote(_ midiNote: Int) {
        let note = midiNote + rootOffset - 6 // half-octave lower by default
        conductor.core.play(noteNumber: MIDINoteNumber(note), velocity: 127)
        //print("play: \(midiNote)")
        //SynthViewController.instance?.pressKeyDownPlease(midiNote)
        //try! Conductor.sharedInstance.play(noteNumber: MIDINoteNumber(midiNote))
        let deadlineTime = DispatchTime.now() + pulse * 0.25 // no overlapping (besides reverb and delay?)
        DispatchQueue.main.asyncAfter(deadline: deadlineTime) {
            //print("stop: \(midiNote)")
            //SynthViewController.instance?.releaseKeyUpPlease(midiNote)
            self.conductor.core.stop(noteNumber: MIDINoteNumber(note))
        }
    }

    func getNote(_ scale: [Int], _ curTriad: [Int], _ octaves: [Int]) -> Int {
        let validNotes = curTriad.map { scale[$0] }
        //print("validNotes: \(validNotes)")
        
        let midiNote = closestValidNote(getRandomScaleNote(scale, octaves), fromValidNotes: validNotes)
        //print("midiNote: \(midiNote)")
        //if random(in: 0...10) < 1.0 { note += 1 }
        //if !scale.contains(note % 12) { AKLog("ACCIDENT!") }
        return midiNote
    }

    func getRandomScaleNote(_ scale: [Int], _ octaves: [Int]) -> Int {
        var note = scale.randomElement()!
        let octave = octaves.randomElement()! * 12
        // chromatic, sometimes! but more likely to be diatonic!
        //if random(in: 0...10) < 1.0 { note -= 2 }
        //if !scale.contains(note % 12) { AKLog("ACCIDENT!") }
        return octave + note
    }

    func getTriadIndexDelta(_ lastTriadIndex: Int) -> Int {
        return 1
        
        var distFrom0 = lastTriadIndex
        if lastTriadIndex > numChords / 2 {
            distFrom0 = numChords - lastTriadIndex
        }
        //print("* lastTriadIndex: \(lastTriadIndex) distFrom0: \(distFrom0)")
        
        // higher chance of undoing last delta on stack as we get farther from 0
        if (0 ... (distFrom0 + reverseDeltaStack.count)).randomElement()! > 1 {
            if let ret = reverseDeltaStack.popLast() {
                print("popped \(ret)")
                return (ret + 100 * numChords) % numChords
            }
        }

        var delta = 0
    //    for i in 1 ... (distFrom0 + 1) {
    //        delta += (distFrom0 + 2) - (1 ... i).randomElement()!
    //    }
    //    delta /= (distFrom0 + 1) // average dice roll
        delta = [1, 2].randomElement()!
        delta *= [-1, 1].randomElement()!
        print("delta: \(delta)")
        reverseDeltaStack.append(-delta)
        
        // delta should always be non-negative!
        let ret = (delta + 100 * numChords) % numChords
        //print("ret: \(ret)")
        return ret
    }
    
    //AKPlaygroundLoop(every: pulse) {
    public func everyPulse() {
        let curTriad = triads[(lastTriadIndex + 100 * numChords) % numChords]
        
        if count % 4 == 0   { playNote(getNote(scale, curTriad, [3, 4])) }
        if count % 2 == 1 && random(in: 0...6) > 1.0  { playNote(getNote(scale, curTriad, [4, 5])) }
        if random(in: 0...3) > 1.0 { playNote(getNote(scale, curTriad, [5, 6])) } else { playNote(getRandomScaleNote(scale, [6, 7])) }
        
        //
        if count > 0 && count % 12 == 0 {
            lastTriadIndex += getTriadIndexDelta(lastTriadIndex)
            lastTriadIndex = (lastTriadIndex + 100 * numChords) % numChords

            //let newTriad = triads[lastTriadIndex]
            //print("lastTriadIndex: \(lastTriadIndex) :: curTriad: \(curTriad) --> newTriad: \(newTriad)")
        }
        
        if count > 0 && count % (numChords * 12) == 0 {
            print("KEY CHANGE")
            rootOffset += 7 // five or seven makes this the circle of fifths
            while rootOffset >= 12 {
                rootOffset -= 12
            }
        }
        
        //
        count += 1
    }
    
    var tempo = 55.0
    var pulse: Double = 0 // needs to be set by math
    var metronome: AKMetronome? = nil
    public func start() { // don't crash if pressed more than once
        if pulse > 0 {
            return
        }
        pulse = (60.0 / 4.0) / tempo   // quarter-notes per second
        let mul = 1.5
        conductor.multiDelay.time = mul * pulse
        AKPlaygroundLoop(every: pulse) { self.everyPulse() }
    }

}
