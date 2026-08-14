import { existsSync, readFileSync } from "node:fs"
import { join } from "node:path"

const TODO_FILE = "TEARDOWN_SHIP_PLATFORM_TODO.json"
const VALIDATOR_RELS = [
  ".opencode/skills/teardown-autonomous-testing/scripts/validate_todo_plan.py",
  ".codex/skills/teardown-autonomous-testing/scripts/validate_todo_plan.py",
]

let lastBlock = null

async function runCheck(directory, shell) {
  const todoPath = join(directory, TODO_FILE)
  if (!existsSync(todoPath)) {
    return { blocked: true, key: "config", reason: `CM2 Todo gate cannot find ${todoPath}. Restore the executable plan before stopping.` }
  }
  let validator
  for (const rel of VALIDATOR_RELS) {
    const candidate = join(directory, rel)
    if (existsSync(candidate)) {
      validator = candidate
      break
    }
  }
  if (!validator) {
    return {
      blocked: true,
      key: "config",
      reason: `CM2 Todo gate cannot find its fail-closed validator (searched ${VALIDATOR_RELS.join(", ")}).`,
    }
  }
  let validation
  for (const python of ["python3", "python"]) {
    try {
      const result = await shell`${python} ${validator} ${todoPath} --quiet`.nothrow().quiet()
      if (result.exitCode === 0) {
        validation = { ok: true }
        break
      }
      validation = { ok: false, detail: String(result.stderr || result.stdout || "").trim() || `exit code ${result.exitCode}` }
    } catch {
      validation = { ok: false, detail: `${python} unavailable` }
    }
  }
  if (!validation?.ok) {
    return { blocked: true, key: "validator", reason: `CM2 Todo gate rejected the executable plan: ${validation?.detail ?? "no python interpreter found"}` }
  }

  let document
  try {
    document = JSON.parse(readFileSync(todoPath, "utf8"))
  } catch (err) {
    return { blocked: true, key: "parse", reason: `CM2 Todo gate cannot parse ${todoPath}: ${err?.message ?? String(err)}` }
  }

  const completionStatuses = new Set((document.completion_statuses ?? []).map(String))
  const verificationCompletion = new Set((document.verification_completion_statuses ?? []).map(String))
  const developerUnable = document.developer_confirmed_unable
  const developerUnableEnabled = !!developerUnable && developerUnable.enabled === true
  const developerUnableField =
    typeof developerUnable?.field === "string" && developerUnable.field.trim() !== ""
      ? developerUnable.field
      : "developer_confirmed"
  const developerUnableIds = new Set((developerUnable?.task_ids ?? []).map(String))

  const unfinished = (document.tasks ?? []).filter((task) => {
    const implementation = String(task.implementation_status ?? "")
    const verification = String(task.verification_status ?? "")
    const unableConfirmed =
      task[developerUnableField] === true || (developerUnableEnabled && developerUnableIds.has(String(task.id)))
    const implementationIncomplete = !completionStatuses.has(implementation)
    const unableUnconfirmed = implementation === "unable" && !unableConfirmed
    const verificationIncomplete = implementation !== "unable" && !verificationCompletion.has(verification)
    return implementationIncomplete || unableUnconfirmed || verificationIncomplete
  })

  if (unfinished.length === 0) {
    return { blocked: false }
  }

  const next = unfinished[0]
  const automation = next.verification?.automation_level ? `, automation=${next.verification.automation_level}` : ""
  return {
    blocked: true,
    key: `${next.id}|${unfinished.length}|${next.implementation_status}|${next.verification_status}`,
    reason: `CM2 executable Todo gate: ${unfinished.length} task(s) still require implementation or verification. Continue with ${next.id} ${next.title ?? ""} (implementation=${next.implementation_status}, verification=${next.verification_status}${automation}). Validate its embedded contract, execute the declared profiles/eyes/hands, persist evidence and regression, then update the independent statuses.`,
  }
}

export const TodoStopPlugin = async ({ client, directory, $ }) => {
  return {
    event: async ({ event }) => {
      if (event.type !== "session.idle") return
      const sessionID = event.properties?.sessionID
      try {
        const result = await runCheck(directory, $)
        if (!result.blocked) {
          lastBlock = null
          return
        }
        if (lastBlock === result.key) return
        lastBlock = result.key ?? null
        const message = result.reason ?? "CM2 Todo gate blocked."
        await client.tui.showToast({ body: { message, variant: "error" } })
        await client.app.log({ body: { service: "todo-stop", level: "warn", message } })
        if (sessionID) {
          await client.session.prompt({
            path: { id: sessionID },
            body: {
              parts: [
                {
                  type: "text",
                  text: `${message}\nContinue working now: execute the gate's declared contract and persist evidence. Do not stop until the executable plan is complete.`,
                },
              ],
            },
          })
        }
      } catch (err) {
        await client.app.log({
          body: { service: "todo-stop", level: "error", message: err?.message ?? String(err) },
        })
      }
    },
  }
}

export default TodoStopPlugin