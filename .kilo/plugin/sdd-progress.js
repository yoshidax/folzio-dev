import { appendFileSync } from "node:fs"

// ワークフロー実行中だけ進捗ログを追記する。SDD_PROGRESS_LOG が無い通常のセッションでは何もしない
const MAX = 120

const shorten = (value) => {
  const text = String(value ?? "").replace(/\s+/g, " ").trim()
  return text.length > MAX ? `${text.slice(0, MAX - 3)}...` : text
}

const write = (line) => {
  const log = process.env.SDD_PROGRESS_LOG
  if (!log) return
  const now = new Date()
  const time = [now.getHours(), now.getMinutes(), now.getSeconds()]
    .map((n) => String(n).padStart(2, "0"))
    .join(":")
  try {
    appendFileSync(log, `${time} ${line}\n`)
  } catch {
    // ログに書けなくてもワークフローを止めない
  }
}

const target = (args) =>
  args?.filePath ?? args?.command ?? args?.description ?? args?.pattern ?? args?.skill ?? ""

const SddProgress = async () => ({
  "tool.execute.after": async (input) => {
    write(`[${input.tool}] ${shorten(target(input.args))}`)
  },
})

export default { id: "sdd-progress", server: SddProgress }
