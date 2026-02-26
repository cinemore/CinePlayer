import SwiftUI

#if os(tvOS)
import UIKit

typealias Action = (UISwipeGestureRecognizer.Direction) -> Void
typealias PageAction = (TVRemotePageEvent) -> Void
typealias LongPressAction = (TVRemoteLongPressEvent) -> Void

enum TVRemotePageEvent {
    case pageUp
    case pageDown
}

enum TVRemoteLongPressEvent {
    case began(direction: UISwipeGestureRecognizer.Direction)
    case ended(direction: UISwipeGestureRecognizer.Direction)
}

struct GestureViewTVOS: UIViewRepresentable {
    let swipeAction: Action
    let pressAction: Action
    let playPauseAction: (() -> Void)?
    let selectAction: (() -> Void)?
    let pageAction: PageAction?
    let longPressAction: LongPressAction?

    init(
        swipeAction: @escaping Action,
        pressAction: @escaping Action,
        playPauseAction: (() -> Void)? = nil,
        selectAction: (() -> Void)? = nil,
        pageAction: PageAction? = nil,
        longPressAction: LongPressAction? = nil
    ) {
        self.swipeAction = swipeAction
        self.pressAction = pressAction
        self.playPauseAction = playPauseAction
        self.selectAction = selectAction
        self.pageAction = pageAction
        self.longPressAction = longPressAction
    }

    func makeUIView(context _: Context) -> UIView {
        let view = TVGestureHelpView(
            swipeAction: swipeAction,
            pressAction: pressAction,
            playPauseAction: playPauseAction,
            selectAction: selectAction,
            pageAction: pageAction,
            longPressAction: longPressAction
        )
        view.isUserInteractionEnabled = true
        view.backgroundColor = .clear
        return view
    }

    func updateUIView(_ uiView: UIView, context _: Context) {
        if let superview = uiView.superview {
            uiView.frame = superview.bounds
        }
    }
}

final class TVGestureHelpView: UIControl {
    let swipeAction: Action
    let pressAction: Action
    let playPauseAction: (() -> Void)?
    let selectAction: (() -> Void)?
    let pageAction: PageAction?
    let longPressAction: LongPressAction?

    init(
        swipeAction: @escaping Action,
        pressAction: @escaping Action,
        playPauseAction: (() -> Void)? = nil,
        selectAction: (() -> Void)? = nil,
        pageAction: PageAction? = nil,
        longPressAction: LongPressAction? = nil
    ) {
        self.swipeAction = swipeAction
        self.pressAction = pressAction
        self.playPauseAction = playPauseAction
        self.selectAction = selectAction
        self.pageAction = pageAction
        self.longPressAction = longPressAction
        super.init(frame: .zero)

        isUserInteractionEnabled = true
        setupGestureRecognizers()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupGestureRecognizers() {
        addTapGestureRecognizer(withAllowedPressTypes: [.playPause], action: #selector(playPausePressed))
        addTapGestureRecognizer(withAllowedPressTypes: [.select], action: #selector(selectPressed))
        addTapGestureRecognizer(withAllowedPressTypes: [.pageUp], action: #selector(pageUpPressed))
        addTapGestureRecognizer(withAllowedPressTypes: [.pageDown], action: #selector(pageDownPressed))
        addTapGestureRecognizer(withAllowedPressTypes: [.upArrow], action: #selector(dPadUpPressed))
        addTapGestureRecognizer(withAllowedPressTypes: [.downArrow], action: #selector(dPadDownPressed))

        let leftTap = addTapGestureRecognizer(withAllowedPressTypes: [.leftArrow], action: #selector(dPadLeftPressed))
        let leftLongPress = addLongPressGestureRecognizer(withAllowedPressTypes: [.leftArrow], action: #selector(dPadLeftLongPress))
        leftTap.require(toFail: leftLongPress)

        let rightTap = addTapGestureRecognizer(withAllowedPressTypes: [.rightArrow], action: #selector(dPadRightPressed))
        let rightLongPress = addLongPressGestureRecognizer(withAllowedPressTypes: [.rightArrow], action: #selector(dPadRightLongPress))
        rightTap.require(toFail: rightLongPress)

        addSwipeGestureRecognizer(withDirection: .left, action: #selector(swipeLeftAction))
        addSwipeGestureRecognizer(withDirection: .right, action: #selector(swipeRightAction))
        addSwipeGestureRecognizer(withDirection: .up, action: #selector(swipeUpAction))
        addSwipeGestureRecognizer(withDirection: .down, action: #selector(swipeDownAction))
    }

    @discardableResult
    private func addTapGestureRecognizer(
        withAllowedPressTypes allowedPressTypes: [UIPress.PressType],
        action: Selector
    ) -> UITapGestureRecognizer {
        let tapGesture = UITapGestureRecognizer(target: self, action: action)
        add(gestureRecognizer: tapGesture, withAllowedPressTypes: allowedPressTypes)
        return tapGesture
    }

    @discardableResult
    private func addLongPressGestureRecognizer(
        withAllowedPressTypes allowedPressTypes: [UIPress.PressType],
        action: Selector
    ) -> UILongPressGestureRecognizer {
        let longPressGesture = UILongPressGestureRecognizer(target: self, action: action)
        longPressGesture.minimumPressDuration = 0.35
        add(gestureRecognizer: longPressGesture, withAllowedPressTypes: allowedPressTypes)
        return longPressGesture
    }

    private func addSwipeGestureRecognizer(withDirection direction: UISwipeGestureRecognizer.Direction, action: Selector) {
        let swipeGesture = UISwipeGestureRecognizer(target: self, action: action)
        swipeGesture.direction = direction
        addGestureRecognizer(swipeGesture)
    }

    private func add(gestureRecognizer: UIGestureRecognizer, withAllowedPressTypes allowedPressTypes: [UIPress.PressType]) {
        gestureRecognizer.allowedPressTypes = allowedPressTypes.map { $0.rawValue as NSNumber }
        addGestureRecognizer(gestureRecognizer)
    }

    @objc private func playPausePressed() {
        playPauseAction?()
    }

    @objc private func selectPressed() {
        selectAction?()
    }

    @objc private func pageUpPressed() {
        pageAction?(.pageUp)
    }

    @objc private func pageDownPressed() {
        pageAction?(.pageDown)
    }

    @objc private func dPadUpPressed() {
        pressAction(.up)
    }

    @objc private func dPadDownPressed() {
        pressAction(.down)
    }

    @objc private func dPadLeftPressed() {
        pressAction(.left)
    }

    @objc private func dPadRightPressed() {
        pressAction(.right)
    }

    @objc private func dPadLeftLongPress(_ gesture: UIGestureRecognizer) {
        handleDirectionalLongPress(gesture, direction: .left)
    }

    @objc private func dPadRightLongPress(_ gesture: UIGestureRecognizer) {
        handleDirectionalLongPress(gesture, direction: .right)
    }

    @objc private func swipeLeftAction() {
        swipeAction(.left)
    }

    @objc private func swipeRightAction() {
        swipeAction(.right)
    }

    @objc private func swipeUpAction() {
        swipeAction(.up)
    }

    @objc private func swipeDownAction() {
        swipeAction(.down)
    }

    private func handleDirectionalLongPress(_ gesture: UIGestureRecognizer, direction: UISwipeGestureRecognizer.Direction) {
        guard let longPressGesture = gesture as? UILongPressGestureRecognizer else {
            return
        }

        switch longPressGesture.state {
        case .began:
            longPressAction?(.began(direction: direction))
        case .ended, .cancelled, .failed:
            longPressAction?(.ended(direction: direction))
        default:
            break
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        if let superview {
            frame = superview.bounds
        }
    }
}
#endif
