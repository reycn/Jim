import Cocoa

class OutputStackView: NSStackView {
    override func addArrangedSubview(_ view: NSView) {
        super.addArrangedSubview(view)
        NSLayoutConstraint.activate([
            view.widthAnchor.constraint(equalTo: widthAnchor),
            view.leadingAnchor.constraint(equalTo: leadingAnchor),
        ])
        view.setContentHuggingPriority(.required, for: .vertical)
    }
}

class OutputTextView: NSTextView {
    var cellView: NotebookTableCell!
    
    public override var intrinsicContentSize: NSSize {
        guard let textContainer = textContainer, let layoutManager = layoutManager else { return super.intrinsicContentSize }
        layoutManager.ensureLayout(for: textContainer)
        return NSSize(width: -1, height: layoutManager.usedRect(for: textContainer).size.height)
    }
    
    override func resize(withOldSuperviewSize oldSize: NSSize) {
        invalidateIntrinsicContentSize()
        super.resize(withOldSuperviewSize: oldSize)
    }
    
    override func becomeFirstResponder() -> Bool {
        cellView.tableView.selectRowIndexes(IndexSet(integer: cellView.row), byExtendingSelection: false)
        return super.becomeFirstResponder()
    }
}

class NotebookTableCell: NSTableCellView {
    let runButton = RunButton()
    let syntaxTextView = SyntaxTextView()
    let outputStackView = OutputStackView()
    var cell: Cell!
    var tableView: NotebookTableView!
    var row: Int { tableView.row(for: self) }
    var notebook: Notebook!
    let lexer = Python3Lexer()
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect); create()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder); create()
    }

    private func create() {
        let containerView = NSView()
        
        containerView.wantsLayer = true
        containerView.layer?.backgroundColor = .white
        containerView.layer?.masksToBounds = true
        containerView.layer?.cornerRadius = 5
                
        shadow = NSShadow()
        shadow?.shadowBlurRadius = 3
        shadow?.shadowOffset = .init(width: 0, height: -2)
        shadow?.shadowColor = .black.withAlphaComponent(0.2)

        outputStackView.wantsLayer = true
        outputStackView.layer?.backgroundColor = .white
        
        runButton.button.image = NSImage(systemSymbolName: "play.fill", accessibilityDescription: "Run cell")
        runButton.callback = self.runCell
        
        syntaxTextView.theme = JimSourceCodeTheme.shared
        syntaxTextView.delegate = self
        
        outputStackView.spacing = 0
        outputStackView.orientation = .vertical
        
        addSubview(containerView)
        containerView.addSubview(syntaxTextView)
        containerView.addSubview(runButton)
        containerView.addSubview(outputStackView)
        
        containerView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: topAnchor),
            containerView.bottomAnchor.constraint(equalTo: bottomAnchor),
            containerView.leadingAnchor.constraint(equalTo: leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: trailingAnchor),
        ])
        
        runButton.translatesAutoresizingMaskIntoConstraints = false
        let runButtonTopAnchorConstraint = runButton.topAnchor.constraint(lessThanOrEqualTo: syntaxTextView.topAnchor, constant: syntaxTextView.padding)
        let runButtonCenterYConstraint = runButton.centerYAnchor.constraint(lessThanOrEqualTo: syntaxTextView.centerYAnchor)
        NSLayoutConstraint.activate([
            runButtonTopAnchorConstraint,
            runButtonCenterYConstraint,
            runButton.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
        ])
        runButtonTopAnchorConstraint.priority = .defaultLow
        runButtonCenterYConstraint.priority = .defaultLow
        runButton.setContentHuggingPriority(.required, for: .horizontal)
        runButton.isHidden = true

        syntaxTextView.translatesAutoresizingMaskIntoConstraints = false
        syntaxTextView.setContentHuggingPriority(.required, for: .vertical)
        NSLayoutConstraint.activate([
            syntaxTextView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
//            syntaxTextView.leadingAnchor.constraint(equalTo: runButton.trailingAnchor, constant: syntaxTextView.padding),
            syntaxTextView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            syntaxTextView.topAnchor.constraint(equalTo: containerView.topAnchor),
        ])

        outputStackView.translatesAutoresizingMaskIntoConstraints = false
        outputStackView.setHuggingPriority(.required, for: .vertical)
        NSLayoutConstraint.activate([
            outputStackView.leadingAnchor.constraint(equalTo: syntaxTextView.leadingAnchor),
            outputStackView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            outputStackView.topAnchor.constraint(equalTo: syntaxTextView.bottomAnchor),
            outputStackView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
        ])
    }
    
    func clearOutputs() {
        for view in outputStackView.arrangedSubviews {
            outputStackView.removeArrangedSubview(view)
            NSLayoutConstraint.deactivate(view.constraints)
            view.removeFromSuperview()
        }
    }
    
    func appendOutputSubview(_ output: Output) {
        switch output {
        case .stream(let output): appendOutputTextSubview(output.text)
        case .displayData(let output):
            if let plainText = output.data.plainText { appendOutputTextSubview(plainText.value) }
            if let markdownText = output.data.markdownText { appendOutputTextSubview(markdownText.value) }
            if let htmlText = output.data.markdownText { appendOutputTextSubview(htmlText.value) }
            if let image = output.data.image { appendOutputImageSubview(image.value) }
        case .executeResult(let output):
            if let plainText = output.data.plainText { appendOutputTextSubview(plainText.value) }
            if let markdownText = output.data.markdownText { appendOutputTextSubview(markdownText.value) }
            if let htmlText = output.data.markdownText { appendOutputTextSubview(htmlText.value) }
            if let image = output.data.image { appendOutputImageSubview(image.value) }
        case .error(let output): appendOutputTextSubview(output.traceback.joined(separator: "\n"))
        }
    }
    
    func appendOutputTextSubview(_ text: String) {
        let string = text.trimmingCharacters(in: Foundation.CharacterSet.whitespacesAndNewlines).replacing(/\[\d+[\d;]*m/, with: "")
        let textView = OutputTextView()
        textView.cellView = self
        textView.font = JimSourceCodeTheme.shared.font
        textView.drawsBackground = false
        textView.minSize = .zero
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.heightTracksTextView = false
        textView.textContainer?.size.height = CGFloat.greatestFiniteMagnitude
        textView.isEditable = false
        textView.string = string
        
        let container = NSView()
        container.addSubview(textView)
        
        textView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            textView.topAnchor.constraint(equalTo: container.topAnchor, constant: syntaxTextView.padding),
            textView.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -syntaxTextView.padding),
            textView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            textView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
        ])
        outputStackView.addArrangedSubview(container)
    }
    
    func appendOutputImageSubview(_ image: NSImage) {
        let imageView = NSImageView(image: image)
        imageView.imageAlignment = .alignTopLeft
        outputStackView.addArrangedSubview(imageView)
    }
    
    func update(cell: Cell, tableView: NotebookTableView, notebook: Notebook, undoManager: UndoManager) {
        self.cell = cell
        self.tableView = tableView
        self.notebook = notebook
        syntaxTextView.uniqueUndoManager = undoManager
        syntaxTextView.text = cell.source.value
        clearOutputs()
        if let outputs = cell.outputs {
            for output in outputs {
                appendOutputSubview(output)
            }
        }
        setIsExecuting(cell, isExecuting: cell.isExecuting)
    }
    
    func setIsExecuting(_ cell: Cell, isExecuting: Bool) {
        cell.isExecuting = isExecuting
        alphaValue = isExecuting ? 0.5 : 1.0
    }
    
    func runCell() {
        guard cell.cellType == .code else { return }
        let jupyter = JupyterService.shared
        notebook.dirty = true
        setIsExecuting(cell, isExecuting: true)

        clearOutputs()
        cell.outputs = []
        jupyter.webSocketSend(code: cell.source.value) { msg in
            switch msg.channel {
            case .iopub:
                var output: Output?
                switch msg.content {
                case .stream(let content):
                    output = .stream(content)
                case .executeResult(let content):
                    output = .executeResult(content)
                case .displayData(let content):
                    output = .displayData(content)
                case .error(let content):
                    output = .error(content)
                default: break
                }
                if let output {
                    Task.detached { @MainActor in
                        self.appendOutputSubview(output)
                    }
                    self.cell.outputs!.append(output)
                }
            case .shell:
                switch msg.content {
                case .executeReply(_):
                    Task.detached { @MainActor in
                        self.setIsExecuting(self.cell, isExecuting: false)
                    }
                default: break
                }
            }
        }
    }
}

extension NotebookTableCell: SyntaxTextViewDelegate {
    func lexerForSource(_ source: String) -> Lexer {
        lexer
    }
    
    func didChangeText(_ syntaxTextView: SyntaxTextView) {
        cell.source.value = syntaxTextView.text
        notebook.dirty = true
    }
    
    func didCommit(_ syntaxTextView: SyntaxTextView) {
        endEditMode(syntaxTextView)
        tableView.runCellSelectBelow()
    }
    
    func previousCell(_ syntaxTextView: SyntaxTextView) {
        if row == 0 { return }
        tableView.selectCellAbove()
        let textView = tableView.selectedCellView!.syntaxTextView.textView
        textView.setSelectedRange(NSRange(location: textView.string.count, length: 0))
    }
    
    func nextCell(_ syntaxTextView: SyntaxTextView) {
        if row == tableView.numberOfRows - 1 { return }
        tableView.selectCellBelow()
        let textView = tableView.selectedCellView!.syntaxTextView.textView
        textView.setSelectedRange(NSRange(location: 0, length: 0))
    }
    
    func didBecomeFirstResponder(_ syntaxTextView: SyntaxTextView) {
        tableView.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
    }
    
    func endEditMode(_ syntaxTextView: SyntaxTextView) {
        window?.makeFirstResponder(tableView)
    }
    
    func save() {
        tableView.notebookDelegate?.save()
    }
}
