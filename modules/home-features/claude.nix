{ den, ... }: {
  den.aspects.ai.claude = {
    includes = [
      (den.provides.unfree [
        "claude-code"
        "claude-usage-tracker"
      ])
    ];

    homeManager = { pkgs, config, ... }: {
      home.packages = [
        pkgs.claude-code
      ]
      ++ pkgs.lib.optionals pkgs.stdenv.hostPlatform.isDarwin [ pkgs.claude-usage-tracker ];
      programs = {
        claude-code = {
          enable = true;

          configDir = "${config.home.homeDirectory}/.claude";
          agents = {
            code-reviewer = ''
              ---
              name: code-reviewer
              description: Specialized code review agent
              tools: Read, Edit, Grep
              ---

              You are a senior software engineer specializing in code reviews.
              Focus on code quality, security, and maintainability.
            '';
          };

          commands = {
            changelog = ''
              ---
              allowed-tools: Bash(git log:*), Bash(git diff:*)
              argument-hint: [version] [change-type] [message]
              description: Update CHANGELOG.md with new entry
              ---
              Parse the version, change type, and message from the input
              and update the CHANGELOG.md file accordingly.
            '';
            commit = ''
              ---
              allowed-tools: Bash(git add:*), Bash(git status:*), Bash(git commit:*)
              description: Create a git commit with proper message
              ---
              ## Context

              - Current git status: !`git status`
              - Current git diff: !`git diff HEAD`
              - Recent commits: !`git log --oneline -5`

              ## Task

              Based on the changes above, create a single atomic git commit with a descriptive message.
            '';
          };

          rules = {
            code-style = ''
              # Code Style Guidelines

              - Use consistent formatting
              - Follow language conventions
            '';
            testing = ''
              # Testing Conventions

              - Write tests for all new features
              - Maintain test coverage above 80%
            '';
          };
        };
      };
    };

    darwin = { ... }: {
      homebrew.casks = [
        "claude"
        "claudebar"
      ];
    };
  };
}
