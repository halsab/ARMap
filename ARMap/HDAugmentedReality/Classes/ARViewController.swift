//
//  ARViewController.swift
//  HDAugmentedRealityDemo
//
//  Created by Danijel Huis on 23/04/15.
//  Copyright (c) 2015 Danijel Huis. All rights reserved.
//

import UIKit
import AVFoundation
import CoreLocation

/**
 *      Augmented reality view controller.
 *
 *      How to use:
 *      1. Initialize controller and set datasource(and other properties if needed)
 *      2. Use setAnnotations method to set annotations
 *      3. Present controller modally
 *      4. Implement ARDataSource to provide annotation views in your data source
 *
 *      Properties maxVerticalLevel, maxVisibleAnnotations and maxDistance can be used to optimize performance.
 *      Use trackingManager.userDistanceFilter and trackingManager.reloadDistanceFilter to set how often data is refreshed/reloaded.
 *      All properties are documented.
 *
 *      https://github.com/DanijelHuis/HDAugmentedReality.git
 *
 */
class ARViewController: UIViewController, ARTrackingManagerDelegate {
    /// Data source
    weak var dataSource: ARDataSource?
    /// Orientation mask for view controller. Make sure orientations are enabled in project settings also.
    var interfaceOrientationMask: UIInterfaceOrientationMask = .all
    /**
     *       Defines in how many vertical levels can annotations be stacked. Default value is 5.
     *       Annotations are initially vertically arranged by distance from user, but if two annotations visibly collide with each other,
     *       then farther annotation is put higher, meaning it is moved onto next vertical level. If annotation is moved onto level higher
     *       than this value, it will not be visible.
     *       NOTE: This property greatly impacts performance because collision detection is heavy operation, use it in range 1-10.
     *       Max value is 10.
     */
    var maxVerticalLevel = 0 {
        didSet {
            if maxVerticalLevel > MAX_VERTICAL_LEVELS {
                maxVerticalLevel = MAX_VERTICAL_LEVELS
            }
        }
    }
    /// Total maximum number of visible annotation views. Default value is 100. Max value is 500
    var maxVisibleAnnotations = 0 {
        didSet {
            if maxVisibleAnnotations > MAX_VISIBLE_ANNOTATIONS {
                maxVisibleAnnotations = MAX_VISIBLE_ANNOTATIONS
            }
        }
    }
    /**
     *       Maximum distance(in meters) for annotation to be shown.
     *       If the distance from annotation to user's location is greater than this value, than that annotation will not be shown.
     *       Also, this property, in conjunction with maxVerticalLevel, defines how are annotations aligned vertically. Meaning
     *       annotation that are closer to this value will be higher.
     *       Default value is 0 meters, which means that distances of annotations don't affect their visiblity.
     */
    var maxDistance: Double = 0
    /// Class for managing geographical calculations. Use it to set properties like reloadDistanceFilter, userDistanceFilter and altitudeSensitive
    private(set) open var trackingManager: ARTrackingManager = ARTrackingManager()
    /// Image for close button. If not set, default one is used.
    //public var closeButtonImage = UIImage(named: "hdar_close", inBundle: NSBundle(forClass: ARViewController.self), compatibleWithTraitCollection: nil)
    var closeButtonImage: UIImage? {
        didSet {
            closeButton?.setImage(self.closeButtonImage, for: .normal)
        }
    }
    /**
     Smoothing factor for heading in range 0-1. It affects horizontal movement of annotaion views. The lower the value the bigger the smoothing.
     Value of 1 means no smoothing, should be greater than 0.
     */
    var headingSmoothingFactor: Double = 1

    /**
     Called every 5 seconds after location tracking is started but failed to deliver location. It is also called when tracking has just started with timeElapsed = 0.
     The timer is restarted when app comes from background or on didAppear.
     */
    var onDidFailToFindLocation: ((_ timeElapsed: TimeInterval, _ acquiredLocationBefore: Bool) -> Void)?

    /**
     Some ui options. Set it before controller is shown, changes made afterwards are disregarded.
     */
    var uiOptions = UiOptions()

    //===== Private
    private var initialized: Bool = false
    private var cameraSession: AVCaptureSession = AVCaptureSession()
    private var overlayView: OverlayView = OverlayView()
    private var displayTimer: CADisplayLink?
    private var cameraLayer: AVCaptureVideoPreviewLayer?    // Will be set in init
    private var annotationViews: [ARAnnotationView] = []
    private var previosRegion: Int = 0
    private var degreesPerScreen: CGFloat = 0
    private var shouldReloadAnnotations: Bool = false
    private var reloadInProgress = false
    private var reloadToken: Int = 0
    private var reloadLock = NSRecursiveLock()
    private var annotations: [ARAnnotation] = []
    private var activeAnnotations: [ARAnnotation] = []
    private var closeButton: UIButton?
    private var currentHeading: Double = 0
    private var lastLocation: CLLocation?

    private var didLayoutSubviews: Bool = false

    // MARK: - Init

    init() {
        super.init(nibName: nil, bundle: nil)
        initializeInternal()
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        initializeInternal()
    }

    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
        initializeInternal()
    }

    func initializeInternal() {
        guard !initialized else { return }

        initialized = true;

        // Default values
        trackingManager.delegate = self
        maxVerticalLevel = 5
        maxVisibleAnnotations = 100
        maxDistance = 0

        NotificationCenter.default.addObserver(self,
                                               selector: #selector(appWillEnterForeground),
                                               name: UIApplication.willEnterForegroundNotification,
                                               object: nil)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(appDidEnterBackground),
                                               name: UIApplication.didEnterBackgroundNotification,
                                               object: nil)

        initialize()
    }

    /// Intended for use in subclasses, no need to call super
    func initialize() {}

    deinit {
        NotificationCenter.default.removeObserver(self)
        stopCamera()
    }

    // MARK: - View's lifecycle

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        onViewWillAppear()  // Doing like this to prevent subclassing problems
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        onViewDidAppear()   // Doing like this to prevent subclassing problems
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        for annotationView in annotationViews {
            annotationView.removeFromSuperview()
        }
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        onViewDidDisappear()    // Doing like this to prevent subclassing problems
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        onViewDidLayoutSubviews()
    }

    private func onViewWillAppear() {
        // Camera layer if not added
        if cameraLayer?.superlayer == nil {
            loadCamera()
        }

        // Overlay
        if overlayView.superview == nil {
            loadOverlay()
        }

        // Set orientation and start camera
        setOrientation(.portrait)
        layoutUi()
        startCamera(notifyLocationFailure: true)
    }

    private func onViewDidAppear() {}

    private func onViewDidDisappear() {
        stopCamera()
    }

    @objc func closeButtonTap() {
        presentingViewController?.dismiss(animated: true)
    }

    override var prefersStatusBarHidden: Bool {
        true
    }

    private func onViewDidLayoutSubviews() {
        // Executed only first time when everything is layouted
        if !didLayoutSubviews {
            didLayoutSubviews = true

            // Close button
            if uiOptions.closeButtonEnabled {
                addCloseButton()
            }

            // Layout
            layoutUi()

            view.layoutIfNeeded()
        }

        degreesPerScreen = (view.bounds.size.width / OVERLAY_VIEW_WIDTH) * 360.0
    }

    @objc func appDidEnterBackground(_ notification: Notification) {
        if view.window != nil {
            trackingManager.stopTracking()
        }
    }
    @objc func appWillEnterForeground(_ notification: Notification) {
        if view.window != nil {
            // Removing all from screen and restarting location manager.
            for annotation in annotations {
                annotation.annotationView = nil
            }

            for annotationView in annotationViews {
                annotationView.removeFromSuperview()
            }

            annotationViews = []
            shouldReloadAnnotations = true
            trackingManager.stopTracking()
            // Start tracking
            trackingManager.startTracking(notifyLocationFailure: true)
        }
    }

    // MARK: - Annotations and annotation views
    /**
     *       Sets annotations. Note that annotations with invalid location will be kicked.
     *
     *       - parameter annotations: Annotations
     */
    func setAnnotations(_ annotations: [ARAnnotation]) {
        var validAnnotations: [ARAnnotation] = []
        // Don't use annotations without valid location
        for annotation in annotations {
            if CLLocationCoordinate2DIsValid(annotation.location.coordinate) {
                validAnnotations.append(annotation)
            }
        }
        self.annotations = validAnnotations
        reloadAnnotations()
    }

    open func getAnnotations() -> [ARAnnotation]
    {
        return self.annotations
    }

    /// Creates annotations views and recalculates all variables(distances, azimuths, vertical levels) if user location is available, else it will reload when it gets user location.
    open func reloadAnnotations()
    {
        if self.trackingManager.userLocation != nil && self.isViewLoaded
        {
            self.shouldReloadAnnotations = false
            self.reload(calculateDistanceAndAzimuth: true, calculateVerticalLevels: true, createAnnotationViews: true)
        }
        else
        {
            self.shouldReloadAnnotations = true
        }
    }

    /// Creates annotation views. All views are created at once, for active annotations. This reduces lag when rotating.
    fileprivate func createAnnotationViews()
    {
        var annotationViews: [ARAnnotationView] = []
        let activeAnnotations = self.activeAnnotations  // Which annotations are active is determined by number of properties - distance, vertical level etc.

        // Removing existing annotation views
        for annotationView in self.annotationViews
        {
            annotationView.removeFromSuperview()
        }

        // Destroy views for inactive anntotations
        for annotation in self.annotations
        {
            if(!annotation.active)
            {
                annotation.annotationView = nil
            }
        }

        // Create views for active annotations
        for annotation in activeAnnotations
        {
            // Don't create annotation view for annotation that doesn't have valid location. Note: checked before, should remove
            guard CLLocationCoordinate2DIsValid(annotation.location.coordinate) else { continue }

            var annotationView: ARAnnotationView? = nil
            if annotation.annotationView != nil
            {
                annotationView = annotation.annotationView
            }
            else
            {
                annotationView = self.dataSource?.ar(self, viewForAnnotation: annotation)
            }

            if annotationView != nil
            {
                annotation.annotationView = annotationView
                annotationView!.annotation = annotation
                annotationViews.append(annotationView!)
            }
        }

        self.annotationViews = annotationViews
    }


    private func calculateDistanceAndAzimuthForAnnotations(sort: Bool, onlyForActiveAnnotations: Bool) {
        guard let userLocation = trackingManager.userLocation else { return }

        let array = (onlyForActiveAnnotations && activeAnnotations.count > 0) ? activeAnnotations : annotations

        for annotation in array {
            // Distance
            annotation.distanceFromUser = annotation.location.distance(from: userLocation)

            // Azimuth
            let azimuth = trackingManager.azimuthFromUserToLocation(annotation.location)
            annotation.azimuth = azimuth
        }

        if sort {
            annotations = annotations.sorted { $0.distanceFromUser < $1.distanceFromUser }
        }
    }

    private func updateAnnotationsForCurrentHeading() {
        //===== Removing views not in viewport, adding those that are. Also removing annotations view vertical level > maxVerticalLevel
        let degreesDelta = Double(degreesPerScreen)

        for annotationView in annotationViews {
            guard let annotation = annotationView.annotation else { continue }

            let delta = deltaAngle(currentHeading, angle2: annotation.azimuth)

            if fabs(delta) < degreesDelta && annotation.verticalLevel <= maxVerticalLevel {
                if annotationView.superview == nil {
                    overlayView.addSubview(annotationView)
                }
            } else if annotationView.superview != nil {
                annotationView.removeFromSuperview()
            }
        }

        //===== Fix position of annoations near Norh(critical regions). Explained in xPositionForAnnotationView
        let threshold: Double = 40
        var currentRegion: Int = 0

        if currentHeading < threshold {
            // 0-40
            currentRegion = 1
        } else if currentHeading > (360 - threshold) {
            // 320-360
            currentRegion = -1
        }

        if currentRegion != previosRegion,
           annotationViews.count > 0 {
            // This will just call positionAnnotationViews
            reload(calculateDistanceAndAzimuth: false, calculateVerticalLevels: false, createAnnotationViews: false)
        }

        previosRegion = currentRegion
    }



    private func positionAnnotationViews() {
        for annotationView in annotationViews {
            let x = xPositionForAnnotationView(annotationView, heading: trackingManager.heading)
            let y = yPositionForAnnotationView(annotationView)

            annotationView.frame = CGRect(x: x, y: y, width: annotationView.bounds.size.width, height: annotationView.bounds.size.height)
        }
    }

    private func xPositionForAnnotationView(_ annotationView: ARAnnotationView, heading: Double) -> CGFloat {
        guard let annotation = annotationView.annotation else { return 0 }

        // Azimuth
        let azimuth = annotation.azimuth

        // Calculating x position
        var xPos: CGFloat = CGFloat(azimuth) * H_PIXELS_PER_DEGREE - annotationView.bounds.size.width / 2.0

        // Fixing position in critical areas (near north).
        // If current heading is right of north(< 40), annotations that are between 320 - 360 wont be visible so we change their position so they are visible.
        // Also if current heading is left of north (320 - 360), annotations that are between 0 - 40 wont be visible so we change their position so they are visible.
        // This is needed because all annotation view are on same ovelay view so views at start and end of overlay view cannot be visible at the same time.
        let threshold: Double = 40
        if heading < threshold && annotation.azimuth > (360 - threshold) {
            xPos = -(OVERLAY_VIEW_WIDTH - xPos)
        } else if heading > (360 - threshold) && annotation.azimuth < threshold {
            xPos = OVERLAY_VIEW_WIDTH + xPos
        }

        return xPos
    }

    private func yPositionForAnnotationView(_ annotationView: ARAnnotationView) -> CGFloat {
        guard let annotation = annotationView.annotation else { return 0 }

        let annotationViewHeight: CGFloat = annotationView.bounds.size.height
        var yPos: CGFloat = (view.bounds.size.height * 0.65) - (annotationViewHeight * CGFloat(annotation.verticalLevel))
        yPos -= CGFloat(powf(Float(annotation.verticalLevel), 2) * 4)
        return yPos
    }

    private func calculateVerticalLevels() {
        // Lot faster with NS stuff than swift collection classes
        let dictionary: NSMutableDictionary = NSMutableDictionary()

        // Creating dictionary for each vertical level
        for level in stride(from: 0, to: maxVerticalLevel + 1, by: 1) {
            let array = NSMutableArray()
            dictionary[Int(level)] = array
        }

        // Putting each annotation in its dictionary(each level has its own dictionary)
        for i in stride(from: 0, to: activeAnnotations.count, by: 1) {
            let annotation = activeAnnotations[i]
            if annotation.verticalLevel <= maxVerticalLevel {
                let array = dictionary[annotation.verticalLevel] as? NSMutableArray
                array?.add(annotation)
            }
        }

        // Calculating annotation view's width in degrees. Assuming all annotation views have same width
        var annotationWidthInDegrees: Double = 0
        if let annotationWidth = getAnyAnnotationView()?.bounds.size.width {
            annotationWidthInDegrees = Double(annotationWidth / H_PIXELS_PER_DEGREE)
        }
        if annotationWidthInDegrees < 5 {
            annotationWidthInDegrees = 5
        }

        // Doing the shit
        var minVerticalLevel: Int = Int.max
        for level in stride(from: 0, to: maxVerticalLevel + 1, by: 1) {
            guard let annotationsForCurrentLevel = dictionary[(level)] as? NSMutableArray else { continue }
            let annotationsForNextLevel = dictionary[(level + 1)] as? NSMutableArray

            for i in stride(from: 0, to: annotationsForCurrentLevel.count, by: 1) {
                guard let annotation1 = annotationsForCurrentLevel[i] as? ARAnnotation else { continue }
                if annotation1.verticalLevel != level { continue }  // Can happen if it was moved to next level by previous annotation, it will be handled in next loop

                for j in stride(from: (i+1), to: annotationsForCurrentLevel.count, by: 1) {
                    guard let annotation2 = annotationsForCurrentLevel[j] as? ARAnnotation else { continue }
                    if annotation1 == annotation2 || annotation2.verticalLevel != level {
                        continue
                    }

                    // Check if views are colliding horizontally. Using azimuth instead of view position in pixel bcs of performance.
                    var deltaAzimuth = deltaAngle(annotation1.azimuth, angle2: annotation2.azimuth)
                    deltaAzimuth = fabs(deltaAzimuth)

                    if deltaAzimuth > annotationWidthInDegrees {
                        // No collision
                        continue
                    }

                    // Current annotation is farther away from user than comparing annotation, current will be pushed to the next level
                    if annotation1.distanceFromUser > annotation2.distanceFromUser {
                        annotation1.verticalLevel += 1
                        if annotationsForNextLevel != nil {
                            annotationsForNextLevel?.add(annotation1)
                        }
                        // Current annotation was moved to next level so no need to continue with this level
                        break
                    } else {
                        // Compared annotation will be pushed to next level because it is furher away
                        annotation2.verticalLevel += 1
                        if annotationsForNextLevel != nil {
                            annotationsForNextLevel?.add(annotation2)
                        }
                    }
                }

                if annotation1.verticalLevel == level {
                    minVerticalLevel = Int(fmin(Float(minVerticalLevel), Float(annotation1.verticalLevel)))
                }
            }
        }

        // Lower all annotation if there is no lower level annotations
        for annotation in activeAnnotations {
            if annotation.verticalLevel <= maxVerticalLevel {
                annotation.verticalLevel -= minVerticalLevel
            }
        }
    }

    /// It is expected that annotations are sorted by distance before this method is called
    private func setInitialVerticalLevels() {
        if activeAnnotations.count == 0 {
            return
        }

        // Fetch annotations filtered by maximumDistance and maximumAnnotationsOnScreen
        let activeAnnotations = self.activeAnnotations
        guard var minDistance = activeAnnotations.first?.distanceFromUser,
              var maxDistance = activeAnnotations.last?.distanceFromUser else { return }
        if self.maxDistance > 0 {
            minDistance = 0;
            maxDistance = self.maxDistance;
        }
        var deltaDistance = maxDistance - minDistance
        let maxLevel: Double = Double(maxVerticalLevel)

        // First reset vertical levels for all annotations
        for annotation in annotations {
            annotation.verticalLevel = maxVerticalLevel + 1
        }
        if deltaDistance <= 0 {
            deltaDistance = 1
        }

        // Calculate vertical levels for active annotations
        for annotation in activeAnnotations {
            let verticalLevel = Int(((annotation.distanceFromUser - minDistance) / deltaDistance) * maxLevel)
            annotation.verticalLevel = verticalLevel
        }
    }

    private func getAnyAnnotationView() -> ARAnnotationView? {
        var anyAnnotationView: ARAnnotationView? = nil

        if let annotationView = annotationViews.first {
            anyAnnotationView = annotationView
        } else if let annotation = activeAnnotations.first {
            anyAnnotationView = dataSource?.ar(self, viewForAnnotation: annotation)
        }

        return anyAnnotationView
    }

    // MARK: - Main logic

    private func reload(calculateDistanceAndAzimuth: Bool, calculateVerticalLevels: Bool, createAnnotationViews: Bool) {
        if calculateDistanceAndAzimuth {
            // Sort by distance is needed only if creating new views
            let sort = createAnnotationViews
            // Calculations for all annotations should be done only when creating annotations views
            let onlyForActiveAnnotations = !createAnnotationViews
            calculateDistanceAndAzimuthForAnnotations(sort: sort, onlyForActiveAnnotations: onlyForActiveAnnotations)
        }

        if createAnnotationViews {
            activeAnnotations = filteredAnnotations(nil, maxVisibleAnnotations: maxVisibleAnnotations, maxDistance: maxDistance)
            setInitialVerticalLevels()
        }

        if calculateVerticalLevels {
            self.calculateVerticalLevels()
        }

        if createAnnotationViews {
            self.createAnnotationViews()
        }

        positionAnnotationViews()

        // Calling bindUi on every annotation view so it can refresh its content,
        // doing this every time distance changes, in case distance is needed for display.
        if calculateDistanceAndAzimuth {
            for annotationView in annotationViews {
                annotationView.bindUi()
            }
        }
    }

    /// Determines which annotations are active and which are inactive. If some of the input parameters is nil, then it won't filter by that parameter.
    private func filteredAnnotations(_ maxVerticalLevel: Int?, maxVisibleAnnotations: Int?, maxDistance: Double?) -> [ARAnnotation] {
        let nsAnnotations: NSMutableArray = NSMutableArray(array: annotations)

        var filteredAnnotations: [ARAnnotation] = []
        var count = 0

        let checkMaxVisibleAnnotations = maxVisibleAnnotations != nil
        let checkMaxVerticalLevel = maxVerticalLevel != nil
        let checkMaxDistance = maxDistance != nil

        for nsAnnotation in nsAnnotations {
            guard let annotation = nsAnnotation as? ARAnnotation else { continue }

            // filter by maxVisibleAnnotations
            if checkMaxVisibleAnnotations && count >= maxVisibleAnnotations! {
                annotation.active = false
                continue
            }

            // filter by maxVerticalLevel and maxDistance
            if (!checkMaxVerticalLevel || annotation.verticalLevel <= maxVerticalLevel!) &&
                (!checkMaxDistance || self.maxDistance == 0 || annotation.distanceFromUser <= maxDistance!) {
                filteredAnnotations.append(annotation)
                annotation.active = true
                count += 1;
            } else {
                annotation.active = false
            }
        }
        return filteredAnnotations
    }

    // MARK: - Events: ARLocationManagerDelegate/Display timer

    @objc func displayTimerTick() {
        let filterFactor: Double = headingSmoothingFactor
        let newHeading = trackingManager.heading

        // Picking up the pace if device is being rotated fast or heading of device is at the border(North). It is needed
        // to do this on North border because overlayView changes its position and we don't want it to animate full circle.
        if headingSmoothingFactor == 1 || fabs(currentHeading - trackingManager.heading) > 50 {
            currentHeading = trackingManager.heading
        } else {
            // Smoothing out heading
            currentHeading = (newHeading * filterFactor) + (currentHeading  * (1.0 - filterFactor))
        }

        overlayView.frame = overlayFrame()
        updateAnnotationsForCurrentHeading()
    }

    func arTrackingManager(_ trackingManager: ARTrackingManager, didUpdateUserLocation: CLLocation?) {
        if let location = trackingManager.userLocation {
            lastLocation = location
        }

        if shouldReloadAnnotations {
            // shouldReloadAnnotations will be true if reloadAnnotations was called before location was fetched
            reloadAnnotations()
        }
        else if self.activeAnnotations.count > 0 {
            // Refresh only if we have annotations
            reload(calculateDistanceAndAzimuth: true, calculateVerticalLevels: true, createAnnotationViews: false)
        }
    }

    func arTrackingManager(_ trackingManager: ARTrackingManager, didUpdateReloadLocation: CLLocation?) {
        // Manual reload?

        if let didUpdateReloadLocation = didUpdateReloadLocation,
           let dataSource = dataSource,
           dataSource.responds(to: #selector(ARDataSource.ar(_:shouldReloadWithLocation:))) {
            let annotations = dataSource.ar?(self, shouldReloadWithLocation: didUpdateReloadLocation)
            if let annotations = annotations {
                setAnnotations(annotations);
            }
        } else {
            reloadAnnotations()
        }
    }

    func arTrackingManager(_ trackingManager: ARTrackingManager, didFailToFindLocationAfter elapsedSeconds: TimeInterval) {
        onDidFailToFindLocation?(elapsedSeconds, lastLocation != nil)
    }

    //==========================================================================================================================================================
    // MARK:                                                        Camera
    //==========================================================================================================================================================
    fileprivate func loadCamera()
    {
        self.cameraLayer?.removeFromSuperlayer()
        self.cameraLayer = nil

        //===== Video device/video input
        let captureSessionResult = ARViewController.createCaptureSession()
        guard captureSessionResult.error == nil, let session = captureSessionResult.session else
        {
            print("HDAugmentedReality: Cannot create capture session, use createCaptureSession method to check if device is capable for augmented reality.")
            return
        }

        self.cameraSession = session

        //===== View preview layer
        let cameraLayer = AVCaptureVideoPreviewLayer(session: self.cameraSession)

        cameraLayer.videoGravity = AVLayerVideoGravity.resizeAspectFill
        self.view.layer.insertSublayer(cameraLayer, at: 0)
        self.cameraLayer = cameraLayer

    }

    /// Tries to find back video device and add video input to it. This method can be used to check if device has hardware available for augmented reality.
    open class func createCaptureSession() -> (session: AVCaptureSession?, error: NSError?)
    {
        var error: NSError?
        var captureSession: AVCaptureSession?
        var backVideoDevice: AVCaptureDevice?
        backVideoDevice = .default(.builtInWideAngleCamera, for: AVMediaType.video, position: .back)

        // Get back video device
        if backVideoDevice != nil {
            var videoInput: AVCaptureDeviceInput!
            do {
                videoInput = try AVCaptureDeviceInput(device: backVideoDevice!)
            } catch let error1 as NSError {
                error = error1
                videoInput = nil
            }

            if error == nil {
                captureSession = AVCaptureSession()

                if captureSession!.canAddInput(videoInput) {
                    captureSession!.addInput(videoInput)
                } else {
                    error = NSError(domain: "", code: 0, userInfo: ["description": "Error adding video input."])
                }
            } else {
                error = NSError(domain: "", code: 1, userInfo: ["description": "Error creating capture device input."])
            }
        } else {
            error = NSError(domain: "", code: 2, userInfo: ["description": "Back video device not found."])
        }

        return (session: captureSession, error: error)
    }

    fileprivate func startCamera(notifyLocationFailure: Bool) {
        DispatchQueue.global(qos: .background).async {
            self.cameraSession.startRunning()
        }
        self.trackingManager.startTracking(notifyLocationFailure: notifyLocationFailure)
        self.displayTimer = CADisplayLink(target: self, selector: #selector(ARViewController.displayTimerTick))
        self.displayTimer?.add(to: RunLoop.current, forMode: RunLoop.Mode.default)
    }

    fileprivate func stopCamera() {
        self.cameraSession.stopRunning()
        self.trackingManager.stopTracking()
        self.displayTimer?.invalidate()
        self.displayTimer = nil
    }

    //==========================================================================================================================================================
    // MARK:                                                        Overlay
    //==========================================================================================================================================================
    /// Overlay view is used to host annotation views.
    fileprivate func loadOverlay()
    {
        self.overlayView.removeFromSuperview()
        self.overlayView = OverlayView()
        self.view.addSubview(self.overlayView)
        /*self.overlayView.backgroundColor = UIColor.greenColor().colorWithAlphaComponent(0.1)

         for i in 0...36
         {
         let view = UIView()
         view.frame = CGRectMake( CGFloat(i * 10) * H_PIXELS_PER_DEGREE , 50, 10, 10)
         view.backgroundColor = UIColor.redColor()
         self.overlayView.addSubview(view)
         }*/
    }

    fileprivate func overlayFrame() -> CGRect
    {
        let x: CGFloat = self.view.bounds.size.width / 2 - (CGFloat(currentHeading) * H_PIXELS_PER_DEGREE)
        let y: CGFloat = (CGFloat(self.trackingManager.pitch) * VERTICAL_SENS) + 60.0

        let newFrame = CGRect(x: x, y: y, width: OVERLAY_VIEW_WIDTH, height: self.view.bounds.size.height)
        return newFrame
    }

    fileprivate func layoutUi()
    {
        self.cameraLayer?.frame = self.view.bounds
        self.overlayView.frame = self.overlayFrame()
    }
    //==========================================================================================================================================================
    //MARK:                                                        Rotation/Orientation
    //==========================================================================================================================================================
    open override var shouldAutorotate : Bool
    {
        return true
    }

    open override var supportedInterfaceOrientations : UIInterfaceOrientationMask
    {
        return UIInterfaceOrientationMask(rawValue: self.interfaceOrientationMask.rawValue)
    }

    open override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator)
    {
        super.viewWillTransition(to: size, with: coordinator)

        coordinator.animate(alongsideTransition:
                                {
            (coordinatorContext) in

            self.setOrientation(.portrait)
        })
        {
            [unowned self] (coordinatorContext) in

            self.layoutAndReloadOnOrientationChange()
        }
    }

    internal func layoutAndReloadOnOrientationChange()
    {
        CATransaction.begin()
        CATransaction.setValue(kCFBooleanTrue, forKey: kCATransactionDisableActions)
        self.layoutUi()
        self.reload(calculateDistanceAndAzimuth: false, calculateVerticalLevels: false, createAnnotationViews: false)
        CATransaction.commit()
    }

    fileprivate func setOrientation(_ orientation: UIInterfaceOrientation)
    {
        if self.cameraLayer?.connection?.isVideoOrientationSupported != nil
        {
            if let videoOrientation = AVCaptureVideoOrientation(rawValue: Int(orientation.rawValue))
            {
                self.cameraLayer?.connection?.videoOrientation = videoOrientation
            }
        }

        if let deviceOrientation = CLDeviceOrientation(rawValue: Int32(orientation.rawValue))
        {
            self.trackingManager.orientation = deviceOrientation
        }
    }

    //==========================================================================================================================================================
    //MARK:                                                        UI
    //==========================================================================================================================================================
    func addCloseButton()
    {
        self.closeButton?.removeFromSuperview()

        if self.closeButtonImage == nil {
            self.closeButtonImage = UIImage(systemName: "xmark")
        }

        // Close button - make it customizable
        let closeButton: UIButton = UIButton(type: UIButton.ButtonType.custom)
        closeButton.setBackgroundImage(closeButtonImage, for: UIControl.State.normal);
        //      closeButton.setBackgroundImage(#imageLiteral(resourceName: "MapIcon-Selected"), for: UIControl.State.highlighted);
        closeButton.adjustsImageWhenHighlighted = false
        closeButton.frame = CGRect(x: (self.view.bounds.size.width / 2) - 37.5, y: self.view.bounds.size.height - 95, width: 75, height: 75)
        closeButton.addTarget(self, action: #selector(ARViewController.closeButtonTap), for: UIControl.Event.touchUpInside)
        closeButton.autoresizingMask = [UIView.AutoresizingMask.flexibleLeftMargin, UIView.AutoresizingMask.flexibleBottomMargin]
        self.view.addSubview(closeButton)
        self.closeButton = closeButton
    }

    //==========================================================================================================================================================
    //MARK:                                                        OverlayView class
    //==========================================================================================================================================================

    /// Normal UIView that registers taps on subviews out of its bounds.
    fileprivate class OverlayView: UIView
    {
        override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView?
        {
            if(!self.clipsToBounds && !self.isHidden)
            {
                for subview in self.subviews.reversed()
                {
                    let subPoint = subview.convert(point, from: self)
                    if let result:UIView = subview.hitTest(subPoint, with:event)
                    {
                        return result;
                    }
                }
            }
            return nil
        }
    }

    //MARK: - UiOptions

    public struct UiOptions {
        /// Enables/Disables close button.
        public var closeButtonEnabled = true
    }
}
