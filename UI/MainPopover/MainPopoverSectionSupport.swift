import AppKit

final class MainPopoverSectionContainerView: NSView {
    let contentStack = NSStackView()
    let backgroundView: NSView?

    init(
        insets: NSEdgeInsets,
        backgroundColor: NSColor? = nil,
        shadow: Bool = false
    ) {
        let backgroundView: NSView?
        if let backgroundColor {
            let view = NSView()
            view.wantsLayer = true
            view.layer?.backgroundColor = backgroundColor.cgColor
            if shadow {
                view.layer?.shadowColor = MainPopoverStyle.Colors.shadow.cgColor
                view.layer?.shadowOpacity = MainPopoverStyle.Metrics.shadowOpacity
                view.layer?.shadowRadius = MainPopoverStyle.Metrics.shadowRadius
                view.layer?.shadowOffset = MainPopoverStyle.Metrics.shadowOffset
            }
            view.translatesAutoresizingMaskIntoConstraints = false
            backgroundView = view
        } else {
            backgroundView = nil
        }
        self.backgroundView = backgroundView
        super.init(frame: .zero)

        translatesAutoresizingMaskIntoConstraints = false
        contentStack.orientation = .vertical
        contentStack.alignment = .leading
        contentStack.translatesAutoresizingMaskIntoConstraints = false

        if let backgroundView {
            addSubview(backgroundView)
            NSLayoutConstraint.activate([
                backgroundView.topAnchor.constraint(equalTo: topAnchor),
                backgroundView.leadingAnchor.constraint(equalTo: leadingAnchor),
                backgroundView.trailingAnchor.constraint(equalTo: trailingAnchor),
                backgroundView.bottomAnchor.constraint(equalTo: bottomAnchor),
            ])
        }

        addSubview(contentStack)
        NSLayoutConstraint.activate([
            contentStack.topAnchor.constraint(equalTo: topAnchor, constant: insets.top),
            contentStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: insets.left),
            contentStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -insets.right),
            contentStack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -insets.bottom),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

enum MainPopoverSectionIconFactory {
    static func makeSymbolImageView(systemName: String) -> NSImageView {
        let imageView = NSImageView()
        imageView.image = NSImage(systemSymbolName: systemName, accessibilityDescription: nil)
        imageView.contentTintColor = MainPopoverStyle.Colors.iconTint
        return imageView
    }

    static func makeTintedSymbolImageView(systemName: String, color: NSColor) -> NSImageView {
        let imageView = makeSymbolImageView(systemName: systemName)
        imageView.contentTintColor = color
        return imageView
    }
}
