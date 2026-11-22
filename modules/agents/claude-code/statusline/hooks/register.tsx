import type { EngineInterface, Register } from 'claude-code'

const NORD = {
  polarNight3: '#4c566a',
  snowStorm0: '#d8dee9',
  frost0: '#8fbcbb',
  frost1: '#88c0d0',
  frost2: '#81a1c1',
  frost3: '#5e81ac',
  red: '#bf616a',
  orange: '#d08770',
  green: '#a3be8c',
  purple: '#b48ead',
} as const

const DROP_ORDER = ['clock', 'cost', 'worktree', 'cwd', 'branch', 'usage', 'ctx'] as const

type SegmentId = 'model' | (typeof DROP_ORDER)[number]
type Part = { text: string; color: string; bold?: boolean }
type Segment = { id: SegmentId; parts: Part[] }
type Git = { branch: string; worktree: string }

const SEPARATOR = ' │ '
const REFRESH_MS = 10_000
const GIT_TTL_MS = 5_000
const USAGE_WINDOWS = new Map([
  ['five_hour', '5h'],
  ['seven_day', '7d'],
])

// Claude Code 2.1.327 lays the footer out as a wrapping row: paddingX 2 on
// each side and columnGap 1 between the hint line and this column. A status
// wider than what is left wraps onto a second row instead of shrinking.
const FOOTER_CHROME_COLUMNS = 5
// The widest label the engine draws, "⏵⏵ bypass permissions on". A mod is
// told the hint beside the label but not when shift+tab changes the label.
const MODE_LABEL_COLUMNS = 24
const HINT_SEPARATOR_COLUMNS = 3

// The engine has no call that answers the effort. It rides on tool and stop
// events, and a change by `/effort` or `/model` shows only as the line the
// command prints, kept as a row in these forms (2.1.327). In the terminal
// `command.run` resolves without that text, the model picker's above all.
const COMMAND_SAID =
  /^<local-command-stdout>(?:(?:Set effort level to|Effort level set to) (low|medium|high|xhigh|max|auto)\b|Set model to .* with `(low|medium|high|xhigh|max)` effort|Set model to )/

const displayName = (model: string): string => {
  const [, family, major, minor] = /^claude-([a-z]+)-(\d+)(?:-(\d{1,2}))?(?:-\d{8})?(?:\[1m\])?$/.exec(model) ?? []

  if (family === undefined) {
    return model
  }

  return `${family.charAt(0).toUpperCase()}${family.slice(1)} ${minor === undefined ? major : `${major}.${minor}`}`
}

const fishPath = (path: string, home: string | undefined): string => {
  const isUnderHome = home !== undefined && (path === home || path.startsWith(`${home}/`))
  const parts = (isUnderHome ? `~${path.slice(home.length)}` : path).split('/')

  return parts.map((part, i) => (i === parts.length - 1 ? part : part.slice(0, part.startsWith('.') ? 2 : 1))).join('/')
}

const elapsed = (ms: number): string => {
  const minutes = Math.floor(ms / 60_000)
  const hours = Math.floor(minutes / 60)
  const rest = minutes % 60

  if (minutes < 1) {
    return '<1m'
  }

  if (hours === 0) {
    return `${rest}m`
  }

  return rest === 0 ? `${hours}hr` : `${hours}hr ${rest}m`
}

const WIDE =
  /[\u1100-\u115f\u2e80-\ua4cf\uac00-\ud7a3\uf900-\ufaff\ufe30-\ufe4f\uff00-\uff60\uffe0-\uffe6]|\p{Extended_Pictographic}/u

const columnsIn = (text: string): number => [...text].reduce((n, char) => n + (WIDE.test(char) ? 2 : 1), 0)

const columnsOf = (segments: readonly Segment[]): number =>
  segments.reduce((sum, { parts }) => sum + parts.reduce((n, { text }) => n + columnsIn(text), 0), 0) +
  Math.max(0, segments.length - 1) * SEPARATOR.length

const fit = (segments: readonly Segment[], budget: number): readonly Segment[] => {
  let kept = segments

  for (const id of DROP_ORDER) {
    if (columnsOf(kept) <= budget) {
      break
    }

    kept = kept.filter(segment => segment.id !== id)
  }

  return columnsOf(kept) <= budget ? kept : []
}

const segment = (id: SegmentId, text: string, color: string, bold?: boolean): Segment => ({
  id,
  parts: [{ text, color, bold }],
})

let hint = ''
// What `/effort` or `/model` last set for the session; null is `auto`. The
// engine keeps a set level across a model switch and otherwise runs each
// model at its own, so the level an event reported holds for one model only.
let chosen: string | null | undefined
let seen: string | undefined
let configured: { model: string; level: string | undefined } | undefined
let git: ({ cwd: string; at: number } & Git) | undefined

const readGit = async ($: EngineInterface, cwd: string, now: number): Promise<Git> => {
  if (git !== undefined && git.cwd === cwd && now - git.at < GIT_TTL_MS) {
    return git
  }

  git = { cwd, at: now, branch: '', worktree: '' }

  try {
    const { exitCode, stdout } = await $.process.run(['git', 'rev-parse', '--abbrev-ref', 'HEAD', '--git-dir'], {
      cwd,
      timeoutMs: 2000,
    })

    if (exitCode === 0) {
      const [branch = '', gitDir = ''] = stdout.trim().split('\n')
      // A detached HEAD has no branch name; git prints the literal `HEAD`.
      git.branch = branch === 'HEAD' ? '' : branch
      git.worktree = /\/worktrees\/([^/]+)$/.exec(gitDir)?.[1] ?? ''
    }
  } catch {}

  return git
}

const readEffort = async ($: EngineInterface, model: string): Promise<string | undefined> => {
  if (seen !== undefined || chosen !== undefined) {
    return seen ?? chosen ?? undefined
  }

  if (configured?.model !== model) {
    const family = /^claude-([a-z]+)-/.exec(model)?.[1] ?? model
    const perModel = (await $.settings.read({ key: 'modelSettings' })) as
      Record<string, { effortLevel?: string } | undefined> | undefined
    configured = { model, level: perModel?.[family]?.effortLevel }
  }

  return configured.level
}

const segmentsOf = async ($: EngineInterface): Promise<Segment[]> => {
  const [model, cwd, home, usage, now] = await Promise.all([
    $.session.model(),
    $.session.cwd(),
    $.env.get('HOME'),
    $.session.usage(),
    $.clock.now(),
  ])
  const [level, { branch, worktree }] = await Promise.all([readEffort($, model), readGit($, cwd, now)])
  // Each plan reports one window; the other is absent rather than zero.
  const limits = usage.rateLimits.flatMap(({ kind, percentUsed }) => {
    const label = USAGE_WINDOWS.get(kind)

    return label === undefined ? [] : [`${label}: ${Math.round(percentUsed)}%`]
  })

  return [
    {
      id: 'model' as const,
      parts: [
        { text: displayName(model), color: NORD.frost1, bold: true },
        ...(level === undefined ? [] : [{ text: ` ${level}`, color: NORD.frost2 }]),
      ],
    },
    segment('cwd', fishPath(cwd, home), NORD.snowStorm0),
    branch !== '' && segment('branch', branch, NORD.purple),
    worktree !== '' && segment('worktree', worktree, NORD.frost0),
    segment('ctx', `Ctx: ${Math.round(usage.context.percent ?? 0)}%`, NORD.green),
    limits.length > 0 && segment('usage', limits.join(' '), NORD.orange),
    usage.cost !== undefined && segment('cost', `$${usage.cost.usd.toFixed(2)}`, NORD.red, true),
    segment('clock', elapsed(now - usage.startedAt), NORD.frost3),
  ].filter((part): part is Segment => part !== false)
}

const observe = ($: EngineInterface, e: { agent_id?: string; effort?: { level?: string } }) => {
  if (e.agent_id === undefined && e.effort?.level !== undefined) {
    seen = e.effort.level
  }

  // A tool may have moved HEAD.
  git = undefined
  $.ui.invalidate('ui.render')
}

const hear = (
  $: EngineInterface,
  e: { agentId?: string; message: { content: readonly { type: string; text?: string }[] } },
) => {
  const said = COMMAND_SAID.exec(e.message.content[0]?.text ?? '')

  if (e.agentId !== undefined || said === null) {
    return
  }

  const level = said[1] ?? said[2]

  if (level !== undefined) {
    chosen = level === 'auto' ? null : level
  }

  seen = undefined
  $.ui.invalidate('ui.render')
}

export const register: Register = on => {
  on('classic.PostToolUse', ($, e, next) => (observe($, e), next(e)))
  on('classic.Stop', ($, e, next) => (observe($, e), next(e)))
  on('session.append', { door: 'command' }, ($, e, next) => (hear($, e), next(e)))

  on('session.start', ($, e, next) => {
    $.clock.every(REFRESH_MS, () => $.ui.invalidate('ui.render'))

    return next(e)
  })

  on('ui.render', { component: 'PromptHint' }, ($, e, next) => {
    if (e.surface === 'terminal' && e.props.hint !== hint) {
      hint = e.props.hint
      $.ui.invalidate('ui.render')
    }

    return next(e)
  })

  on('ui.render', { component: 'SessionMode' }, async ($, e, next) => {
    if (e.surface !== 'terminal' || e.viewport === undefined) {
      return next(e)
    }

    const modes = e.props.modes.length === 0 ? '' : ` · ${e.props.modes.join(' & ')}`
    const left = MODE_LABEL_COLUMNS + (hint === '' ? 0 : HINT_SEPARATOR_COLUMNS + columnsIn(hint))
    const budget = e.viewport.columns - FOOTER_CHROME_COLUMNS - left - columnsIn(modes)
    const segments = fit(await segmentsOf($), budget)

    if (segments.length === 0) {
      return next(e)
    }

    const { Box, Text } = $.ui.resolve(e)
    const texts = segments.flatMap(({ parts }, i) => [
      ...(i === 0 ? [] : [<Text color={NORD.polarNight3}>{SEPARATOR}</Text>]),
      ...parts.map(({ text, color, bold }) => (
        <Text color={color} bold={bold}>
          {text}
        </Text>
      )),
    ])

    return (
      <Box flexShrink={0}>
        {texts}
        {modes !== '' && <Text dimColor>{modes}</Text>}
      </Box>
    )
  })
}
