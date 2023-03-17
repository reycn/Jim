import Cocoa

class OutputStackView: NSStackView {
    override func addArrangedSubview(_ view: NSView) {
        super.addArrangedSubview(view)
        view.widthAnchor.constraint(equalTo: widthAnchor).isActive = true
        view.leadingAnchor.constraint(equalTo: leadingAnchor).isActive = true
        view.setContentHuggingPriority(.required, for: .vertical)
    }
}

class OutputTextView: NSTextView {
    public override var intrinsicContentSize: NSSize {
        guard let textContainer = textContainer, let layoutManager = layoutManager else { return super.intrinsicContentSize }
        layoutManager.ensureLayout(for: textContainer)
        return NSSize(width: -1, height: layoutManager.usedRect(for: textContainer).size.height)
    }
    
    override func resize(withOldSuperviewSize oldSize: NSSize) {
        invalidateIntrinsicContentSize()
        super.resize(withOldSuperviewSize: oldSize)
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
    
    var isExecuting = false {
        didSet {
//            syntaxTextView.isExecuting = isExecuting
            tableView.rowView(atRow: row, makeIfNecessary: false)!.needsDisplay = true
//            runButton.inProgress = isExecuting
        }
    }
    
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
        containerView.topAnchor.constraint(equalTo: topAnchor).isActive = true
        containerView.bottomAnchor.constraint(equalTo: bottomAnchor).isActive = true
        containerView.leadingAnchor.constraint(equalTo: leadingAnchor).isActive = true
        containerView.trailingAnchor.constraint(equalTo: trailingAnchor).isActive = true
        
        runButton.translatesAutoresizingMaskIntoConstraints = false
        let runButtonTopAnchorConstraint = runButton.topAnchor.constraint(lessThanOrEqualTo: syntaxTextView.topAnchor, constant: syntaxTextView.padding)
        runButtonTopAnchorConstraint.isActive = true
        runButtonTopAnchorConstraint.priority = .defaultLow
        let runButtonCenterYConstraint = runButton.centerYAnchor.constraint(lessThanOrEqualTo: syntaxTextView.centerYAnchor)
        runButtonCenterYConstraint.isActive = true
        runButtonCenterYConstraint.priority = .defaultLow
        runButton.leadingAnchor.constraint(equalTo: containerView.leadingAnchor).isActive = true
        runButton.setContentHuggingPriority(.required, for: .horizontal)
        runButton.isHidden = true

        syntaxTextView.translatesAutoresizingMaskIntoConstraints = false
        syntaxTextView.setContentHuggingPriority(.required, for: .vertical)
        syntaxTextView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor).isActive = true
//        syntaxTextView.leadingAnchor.constraint(equalTo: runButton.trailingAnchor, constant: syntaxTextView.padding).isActive = true
        syntaxTextView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor).isActive = true
        syntaxTextView.topAnchor.constraint(equalTo: containerView.topAnchor).isActive = true

        outputStackView.translatesAutoresizingMaskIntoConstraints = false
        outputStackView.setHuggingPriority(.required, for: .vertical)
        outputStackView.leadingAnchor.constraint(equalTo: syntaxTextView.leadingAnchor).isActive = true
        outputStackView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor).isActive = true
        outputStackView.topAnchor.constraint(equalTo: syntaxTextView.bottomAnchor).isActive = true
        outputStackView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor).isActive = true
    }
    
    func clearOutputs() {
        for view in outputStackView.arrangedSubviews {
//            outputStackView.removeArrangedSubview(view)
//            NSLayoutConstraint.deactivate(view.constraints)
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
        let string = text.trimmingCharacters(in: Foundation.CharacterSet.whitespacesAndNewlines)
        let textView = OutputTextView()
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
        outputStackView.addArrangedSubview(textView)
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
    }
    
    func runCell() {
        guard cell.cellType == .code else { return }
        let jupyter = JupyterService.shared
        notebook.dirty = true
        isExecuting = true
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
                        self.isExecuting = false
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
