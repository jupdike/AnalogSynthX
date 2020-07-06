//
//  SynthViewController+UIHelpers.swift
//  AnalogSynthX
//
//  Created by Matthew Fecher, revision history on Githbub.
//  Copyright © 2018 AudioKit. All rights reserved.
//

import UIKit

extension SynthViewController {

    //*****************************************************************
    // MARK: - Synth UI Helpers
    //*****************************************************************

    override var prefersStatusBarHidden: Bool {
        return true
    }

    func openURL(_ url: String) {
        guard let url = URL(string: url) else {
            return
        }
        if #available(iOS 10.0, *) {
            UIApplication.shared.open(url)
        } else {
            // Fallback on earlier versions
        }
    }

    //*****************************************************************
    // MARK: - SegmentViews
    //*****************************************************************

    func createWaveFormSegmentViews() {
        self.vco1WaveformSegment = setupOscSegmentView(x: 8, y: 75.0, width: 195, height: 46.0, tag: ControlTag.vco1Waveform.rawValue, type: 0)
        self.vco2WaveformSegment = setupOscSegmentView(x: 212, y: 75.0, width: 226, height: 46.0, tag: ControlTag.vco2Waveform.rawValue, type: 0)
        self.lfoWaveformSegment = setupOscSegmentView(x: 10, y: 377, width: 255, height: 46.0, tag: ControlTag.lfoWaveform.rawValue, type: 1)
    }

    func setupOscSegmentView(x: CGFloat,
                             y: CGFloat,
                             width: CGFloat,
                             height: CGFloat,
                             tag: Int,
                             type: Int) -> SMSegmentView {
        let segmentFrame = CGRect(x: x, y: y, width: width, height: height)
        let segmentView = WaveformSegmentedView(frame: segmentFrame)
        segmentView.setOscColors()

        if type == 0 {
            segmentView.addOscWaveforms()
        } else {
            segmentView.addLfoWaveforms()
        }

        segmentView.delegate = self
        segmentView.tag = tag

        // Set segment with index 0 as selected by default
        segmentView.selectSegmentAtIndex(0)
        self.view.addSubview(segmentView)
        
        return segmentView
    }

}
