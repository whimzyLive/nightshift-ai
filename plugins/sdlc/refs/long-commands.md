# Long commands

Read by every domain agent and the QA gate runner before the first build, test or gate command. A
background story run has no person to notice a command that stalls the wait.

```text
build | test | gate command -> run in the foreground, Bash `timeout` := 600000   # the maximum; the 120000 default lets the harness background it mid-run
command may exceed ten minutes -> start with `run_in_background: true`, then end the turn   # its completion notification resumes the agent
never -> poll with a shell loop (`pgrep`, `sleep`, `until`, `while`) or Monitor   # each poll is backgrounded at its own timeout and costs a turn
never -> hand back while a command the agent started is still running   # a handback is the finish: every command it started has exited
never -> return an interim handback ("still running", "complete, background work continues")
```
