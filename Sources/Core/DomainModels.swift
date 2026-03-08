import Foundation

public enum AgentType: String, CaseIterable, Codable, Sendable, Identifiable {
    case claude
    case codex
    case gemini

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .claude: "Claude"
        case .codex: "Codex"
        case .gemini: "Gemini"
        }
    }

    public var commandName: String { rawValue }
}

public enum AgentRole: String, Codable, Sendable, CaseIterable {
    case lead
    case implementer
    case reviewer
    case alternative
}

public enum TaskStatus: String, CaseIterable, Codable, Sendable, Identifiable {
    case inbox
    case ready
    case inProgress = "in_progress"
    case review
    case done

    public var id: String { rawValue }
    public var folderName: String { rawValue }

    public var displayName: String {
        switch self {
        case .inbox: "Inbox"
        case .ready: "Ready"
        case .inProgress: "In Progress"
        case .review: "Review"
        case .done: "Done"
        }
    }
}

public enum TaskPriority: String, CaseIterable, Codable, Sendable {
    case low
    case medium
    case high
}

public enum SidebarSection: String, CaseIterable, Codable, Sendable, Identifiable {
    case backlog
    case notes
    case sessions
    case files

    public var id: String { rawValue }
}

public enum ApprovalType: String, CaseIterable, Codable, Sendable, Identifiable {
    case planReview = "plan_review"
    case coreLogicReview = "core_logic_review"
    case preCommit = "pre_commit"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .planReview: "Plan Review"
        case .coreLogicReview: "Core Logic Review"
        case .preCommit: "Pre-Commit"
        }
    }
}

public enum ApprovalStatus: String, CaseIterable, Codable, Sendable {
    case pending
    case approved
}

public struct ApprovalState: Codable, Hashable, Sendable {
    public var statuses: [ApprovalType: ApprovalStatus]

    public init(statuses: [ApprovalType: ApprovalStatus] = [:]) {
        self.statuses = statuses
    }

    public subscript(type: ApprovalType) -> ApprovalStatus {
        get { statuses[type] ?? .pending }
        set { statuses[type] = newValue }
    }
}

public struct ProjectUIState: Codable, Hashable, Sendable {
    public var selectedSection: SidebarSection
    public var isInspectorVisible: Bool
    public var terminalHeight: Double

    public init(
        selectedSection: SidebarSection = .backlog,
        isInspectorVisible: Bool = true,
        terminalHeight: Double = 240
    ) {
        self.selectedSection = selectedSection
        self.isInspectorVisible = isInspectorVisible
        self.terminalHeight = terminalHeight
    }
}

public struct Project: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var name: String
    public var rootPath: String
    public var vaultPath: String
    public var createdAt: Date
    public var lastOpenedAt: Date
    public var defaultAgents: [AgentType]
    public var uiState: ProjectUIState

    public init(
        id: UUID = UUID(),
        name: String,
        rootPath: String,
        vaultPath: String,
        createdAt: Date = Date(),
        lastOpenedAt: Date = Date(),
        defaultAgents: [AgentType] = [.claude, .codex, .gemini],
        uiState: ProjectUIState = .init()
    ) {
        self.id = id
        self.name = name
        self.rootPath = rootPath
        self.vaultPath = vaultPath
        self.createdAt = createdAt
        self.lastOpenedAt = lastOpenedAt
        self.defaultAgents = defaultAgents
        self.uiState = uiState
    }
}

public struct TaskFrontmatter: Codable, Hashable, Sendable {
    public var id: String
    public var title: String
    public var status: TaskStatus
    public var priority: TaskPriority
    public var createdAt: Date
    public var updatedAt: Date
    public var author: String
    public var leadAgent: AgentType
    public var supportAgents: [AgentType]
    public var linkedNotePaths: [String]
    public var linkedFilePaths: [String]
    public var approvalState: ApprovalState

    public init(
        id: String,
        title: String,
        status: TaskStatus = .inbox,
        priority: TaskPriority = .medium,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        author: String = "user",
        leadAgent: AgentType = .claude,
        supportAgents: [AgentType] = [.codex, .gemini],
        linkedNotePaths: [String] = ["01_current_context.md"],
        linkedFilePaths: [String] = [],
        approvalState: ApprovalState = .init()
    ) {
        self.id = id
        self.title = title
        self.status = status
        self.priority = priority
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.author = author
        self.leadAgent = leadAgent
        self.supportAgents = supportAgents
        self.linkedNotePaths = linkedNotePaths
        self.linkedFilePaths = linkedFilePaths
        self.approvalState = approvalState
    }
}

public struct TaskBody: Codable, Hashable, Sendable {
    public var goal: String
    public var background: String
    public var acceptanceCriteria: String
    public var plan: String
    public var agentOutputs: String
    public var reviewNotes: String
    public var finalResult: String

    public init(
        goal: String = "",
        background: String = "",
        acceptanceCriteria: String = "",
        plan: String = "",
        agentOutputs: String = "",
        reviewNotes: String = "",
        finalResult: String = ""
    ) {
        self.goal = goal
        self.background = background
        self.acceptanceCriteria = acceptanceCriteria
        self.plan = plan
        self.agentOutputs = agentOutputs
        self.reviewNotes = reviewNotes
        self.finalResult = finalResult
    }
}

public struct TaskDocument: Identifiable, Codable, Hashable, Sendable {
    public var metadata: TaskFrontmatter
    public var body: TaskBody
    public var relativePath: String

    public init(metadata: TaskFrontmatter, body: TaskBody, relativePath: String) {
        self.metadata = metadata
        self.body = body
        self.relativePath = relativePath
    }

    public var id: String { metadata.id }
    public var title: String { metadata.title }
    public var status: TaskStatus { metadata.status }
}

public struct VaultNote: Identifiable, Hashable, Sendable {
    public var relativePath: String
    public var title: String
    public var content: String

    public init(relativePath: String, title: String, content: String) {
        self.relativePath = relativePath
        self.title = title
        self.content = content
    }

    public var id: String { relativePath }
}

public enum AgentSessionStatus: String, Codable, Sendable {
    case running
    case completed
    case failed
}

public struct AgentSessionRecord: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var taskID: String
    public var agentType: AgentType
    public var role: AgentRole
    public var status: AgentSessionStatus
    public var startedAt: Date
    public var endedAt: Date?
    public var transcriptPath: String?
    public var summary: String

    public init(
        id: UUID = UUID(),
        taskID: String,
        agentType: AgentType,
        role: AgentRole,
        status: AgentSessionStatus,
        startedAt: Date = Date(),
        endedAt: Date? = nil,
        transcriptPath: String? = nil,
        summary: String = ""
    ) {
        self.id = id
        self.taskID = taskID
        self.agentType = agentType
        self.role = role
        self.status = status
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.transcriptPath = transcriptPath
        self.summary = summary
    }
}

public struct CLIHealth: Hashable, Sendable {
    public var agent: AgentType
    public var isAvailable: Bool
    public var commandPath: String?
    public var checkedAt: Date

    public init(agent: AgentType, isAvailable: Bool, commandPath: String?, checkedAt: Date = Date()) {
        self.agent = agent
        self.isAvailable = isAvailable
        self.commandPath = commandPath
        self.checkedAt = checkedAt
    }
}

public struct TerminalCommand: Hashable, Sendable {
    public var title: String
    public var executable: String
    public var arguments: [String]
    public var environment: [String]?
    public var currentDirectory: String?
    public var bootInput: String?
    public var logDirectory: String?

    public init(
        title: String,
        executable: String,
        arguments: [String] = [],
        environment: [String]? = nil,
        currentDirectory: String? = nil,
        bootInput: String? = nil,
        logDirectory: String? = nil
    ) {
        self.title = title
        self.executable = executable
        self.arguments = arguments
        self.environment = environment
        self.currentDirectory = currentDirectory
        self.bootInput = bootInput
        self.logDirectory = logDirectory
    }
}

public struct AgentRunRequest: Sendable {
    public var project: Project
    public var task: TaskDocument
    public var agent: AgentType
    public var role: AgentRole
    public var prompt: String

    public init(project: Project, task: TaskDocument, agent: AgentType, role: AgentRole, prompt: String) {
        self.project = project
        self.task = task
        self.agent = agent
        self.role = role
        self.prompt = prompt
    }
}

public struct AgentRunResult: Sendable {
    public var session: AgentSessionRecord
    public var transcript: String

    public init(session: AgentSessionRecord, transcript: String) {
        self.session = session
        self.transcript = transcript
    }
}

public struct GitChangedFile: Hashable, Sendable, Identifiable {
    public var path: String
    public var statusCode: String

    public init(path: String, statusCode: String) {
        self.path = path
        self.statusCode = statusCode
    }

    public var id: String { path }
}

public struct GitWorkspaceSummary: Hashable, Sendable {
    public var isRepository: Bool
    public var changedFiles: [GitChangedFile]
    public var rawStatus: String

    public init(isRepository: Bool, changedFiles: [GitChangedFile] = [], rawStatus: String = "") {
        self.isRepository = isRepository
        self.changedFiles = changedFiles
        self.rawStatus = rawStatus
    }
}

public struct WorkspaceState: Hashable, Sendable {
    public var selectedProjectID: UUID?
    public var selectedTaskID: String?
    public var selectedSection: SidebarSection
    public var terminalHeight: Double

    public init(
        selectedProjectID: UUID? = nil,
        selectedTaskID: String? = nil,
        selectedSection: SidebarSection = .backlog,
        terminalHeight: Double = 240
    ) {
        self.selectedProjectID = selectedProjectID
        self.selectedTaskID = selectedTaskID
        self.selectedSection = selectedSection
        self.terminalHeight = terminalHeight
    }
}

public struct TerminalLogTab: Identifiable, Hashable, Sendable {
    public var id: String
    public var title: String
    public var content: String

    public init(id: String, title: String, content: String = "") {
        self.id = id
        self.title = title
        self.content = content
    }
}

