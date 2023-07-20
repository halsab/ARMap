//
//  ARAnnotationView.swift
//  HDAugmentedRealityDemo
//
//  Created by Danijel Huis on 23/04/15.
//  Copyright (c) 2015 Danijel Huis. All rights reserved.
//

import UIKit

/// View for annotation. Subclass to customize. Annotation views should be lightweight,
/// try to avoid xibs and autolayout.
/// bindUi method is called when distance/azimuth is set in ARViewController.
class ARAnnotationView: UIView {

    weak var annotation: ARAnnotation?
    private var initialized: Bool = false
    
    init() {
        super.init(frame: .zero)
        initializeInternal()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        initializeInternal()
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        initializeInternal()
    }
    
    private func initializeInternal() {
        guard !initialized else { return }
        initialized = true;
        initialize()
    }
    
    override func awakeFromNib() {
        bindUi()
    }
    
    /// Will always be called once, no need to call super
    func initialize() {}
    
    /// Called when distance/azimuth changes, intended to be used in subclasses
    func bindUi() {}
}
