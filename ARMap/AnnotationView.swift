//
//  AnnotationView.swift
//  ARMap
//
//  Created by Khalil Sabirov on 20.07.2023.
//

import UIKit

final class AnnotationView: ARAnnotationView {

    lazy var contentView: UIView = {
        let view = UIView()
        view.backgroundColor = .systemBlue.withAlphaComponent(0.3)
        view.layer.cornerRadius = 12
        return view
    }()

    lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.textColor = .white
        return label
    }()

    lazy var distanceLabel: UILabel = {
        let label = UILabel()
        label.textColor = .white
        return label
    }()

    override func bindUi() {
        setup()
    }

    override func initialize() {
        setup()
    }

    static var contentFrame: CGRect {
        .init(origin: .zero, size: .init(width: width, height: height))
    }

    private static let width: CGFloat = 100
    private static let height: CGFloat = 60

    private let hPadding: CGFloat = 8
    private let vPadding: CGFloat = 8
    private let spacing: CGFloat = 4

    private var labelHeight: CGFloat {
        (AnnotationView.height - spacing - vPadding * 2) / 2
    }
    private var labelWidth: CGFloat {
        AnnotationView.width - hPadding * 2
    }
    private var labelSize: CGSize {
        .init(width: labelWidth, height: labelHeight)
    }

    func setup() {
        addSubview(contentView)
        contentView.addSubview(titleLabel)
        contentView.addSubview(distanceLabel)

        contentView.frame = AnnotationView.contentFrame
        titleLabel.frame = .init(origin: .init(x: hPadding, y: vPadding), size: labelSize)
        distanceLabel.frame = .init(origin: .init(x: hPadding, y: vPadding + labelHeight + spacing), size: labelSize)

        if let annotation = annotation {
            titleLabel.text = annotation.title
            distanceLabel.text = String(format: "%.2f км", annotation.distanceFromUser / 1000)
        }
    }
}
