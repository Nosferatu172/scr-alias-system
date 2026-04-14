class Context:
    def __init__(self, path, dry_run=False):
        self.path = path
        self.dry_run = dry_run

        self.files = []
        self.functions = []
        self.groups = {}

        self.call_graph = {}
        self.usage_map = {}

        self.stable_groups = []
        self.safe_groups = []

        self.applied_groups = []
