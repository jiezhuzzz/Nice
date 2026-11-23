use std::borrow::Cow;
use std::fmt::Write as _;
use std::iter;
use std::ops::Range;

use unicode_width::UnicodeWidthStr;

use crate::sample::Usage;
use crate::theme::{Rgb, Theme};

const CAP_LEFT: &str = "\u{e0b6}";
const CAP_RIGHT: &str = "\u{e0b4}";
const HOST_SEPARATOR: &str = " \u{f054} ";

const FULLSCREEN_ICON: char = '\u{f0293}';
const SYNC_ICON: char = '\u{f04e6}';
const FLOATING_ICON: char = '\u{f2d2}';
const REMOTE_ICON: char = '\u{f048b}';

const WARN_AT: f64 = 70.0;
const CRIT_AT: f64 = 90.0;

const LEFT_MARGIN: usize = 1;
const GAP: usize = 2;
const METER_DIGITS: usize = 2;

#[derive(Debug, Clone, Default, PartialEq, Eq)]
pub struct Tab {
    pub position: usize,
    pub name: String,
    pub active: bool,
    pub fullscreen: bool,
    pub sync: bool,
    pub floating: bool,
    pub remote: Option<String>,
}

#[derive(Debug, Clone)]
pub struct Hint {
    pub keys: String,
    pub action: &'static str,
}

#[derive(Debug, Clone, Copy)]
pub struct Mode<'a> {
    pub label: &'a str,
    pub hints: &'a [Hint],
    pub digits_pick_tabs: bool,
    pub locked: bool,
}

#[derive(Debug, Clone, Copy)]
pub struct Bar<'a> {
    pub mode: Option<Mode<'a>>,
    pub session: Option<&'a str>,
    pub hosts: &'a [String],
    pub tabs: &'a [Tab],
    pub usage: Usage,
}

#[derive(Debug, Default)]
pub struct Rendered {
    pub line: String,
    targets: Vec<(Range<usize>, Target)>,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Target {
    Tab(usize),
    Host,
}

impl Rendered {
    /// What a click at `column` reaches. An overflow marker reaches the nearest
    /// tab it hides.
    pub fn target_at(&self, column: usize) -> Option<Target> {
        self.targets
            .iter()
            .find(|(columns, _)| columns.contains(&column))
            .map(|&(_, target)| target)
    }
}

pub fn render(bar: &Bar, theme: &Theme, cols: usize) -> Rendered {
    let mode = bar.mode.as_ref();
    let mut leaner_sessions = sessions_richest_first(bar, theme).into_iter().peekable();
    let mut session = leaner_sessions.next();
    let mut leaner_pills = pills_richest_first(bar, theme).into_iter().peekable();
    let mut pill = leaner_pills.next();
    let active = bar.tabs.iter().position(|tab| tab.active).unwrap_or(0);
    let mut entities: Vec<Entity> = bar
        .tabs
        .iter()
        .map(|tab| tab_entity(tab, &title(tab), mode, theme))
        .collect();
    let widths: Vec<usize> = entities.iter().map(Entity::width).collect();
    let all = 0..widths.len();

    let tabs = loop {
        let reserved = LEFT_MARGIN
            + session.as_ref().map_or(0, |session| session.width() + GAP)
            + pill.as_ref().map_or(0, |pill| GAP + pill.width());
        let budget = cols.checked_sub(reserved);
        let extras_to_shed = leaner_pills.peek().is_some() || leaner_sessions.peek().is_some();
        let window = budget.and_then(|budget| {
            if extras_to_shed {
                (cost(&widths, &all) <= budget).then(|| all.clone())
            } else {
                fit(&widths, active, budget)
            }
        });
        if let Some(window) = window {
            break window_entities(bar.tabs, &mut entities, window, theme);
        }
        if let Some(leaner) = leaner_pills.next() {
            pill = Some(leaner);
        } else if let Some(leaner) = leaner_sessions.next() {
            session = Some(leaner);
        } else if mode.is_some() && session.is_some() {
            session = None;
        } else if pill.is_some() {
            pill = None;
        } else if session.is_some() {
            session = None;
        } else {
            break bar
                .tabs
                .get(active)
                .zip(budget)
                .and_then(|(tab, budget)| truncated_tab(tab, mode, budget, theme))
                .into_iter()
                .collect();
        }
    };

    let mut painter = Painter::new(cols);
    painter.blank(LEFT_MARGIN);
    for (i, entity) in session.iter().chain(&tabs).enumerate() {
        if i > 0 {
            painter.blank(GAP);
        }
        painter.entity(entity);
    }
    if let Some(pill) = &pill {
        painter.blank(cols.saturating_sub(painter.width + pill.width()));
        painter.entity(pill);
    }
    painter.finish()
}

fn sessions_richest_first(bar: &Bar, theme: &Theme) -> Vec<Entity> {
    let Some(name) = bar.session.filter(|name| !name.is_empty()) else {
        return Vec::new();
    };
    let own = Span::new(name, theme.text);
    let chain = (!bar.hosts.is_empty()).then(|| {
        bar.hosts
            .iter()
            .flat_map(|host| {
                [
                    Span::new(host, theme.muted_text),
                    Span::new(HOST_SEPARATOR, theme.faint_text),
                ]
            })
            .chain(iter::once(own.clone()))
            .collect::<Entity>()
            .targeting(Target::Host)
    });
    chain.into_iter().chain([Entity::from(own)]).collect()
}

fn pills_richest_first(bar: &Bar, theme: &Theme) -> Vec<Entity> {
    match &bar.mode {
        Some(mode) => (0..=mode.hints.len())
            .rev()
            .map(|shown| pill(mode_spans(mode, &mode.hints[..shown], theme), theme))
            .collect(),
        None => Some(stat_spans(bar.usage, theme))
            .filter(|spans| !spans.is_empty())
            .map(|spans| pill(spans, theme))
            .into_iter()
            .collect(),
    }
}

fn pill(content: Vec<Span>, theme: &Theme) -> Entity {
    let cap = |glyph: &str| Span::new(glyph, theme.pill_bg);
    iter::once(cap(CAP_LEFT))
        .chain(content.into_iter().map(|span| span.on(theme.pill_bg)))
        .chain(iter::once(cap(CAP_RIGHT)))
        .collect()
}

fn stat_spans(usage: Usage, theme: &Theme) -> Vec<Span> {
    [("CPU", usage.cpu), ("GPU", usage.gpu), ("MEM", usage.mem)]
        .into_iter()
        .filter_map(|(label, percent)| Some((label, percent?)))
        .enumerate()
        .flat_map(|(i, (label, percent))| {
            let percent = percent.round();
            let lead = if i == 0 { 0 } else { GAP };
            let level = if percent >= CRIT_AT {
                theme.crit
            } else if percent >= WARN_AT {
                theme.warn
            } else {
                theme.text
            };
            let digits = format!("{percent:.0}");
            let placeholder = "0".repeat(METER_DIGITS.saturating_sub(digits.len()));
            [
                Span::new(format!("{:lead$}{label} ", ""), theme.muted_text),
                Span::new(placeholder, theme.ghost_text),
                Span::new(format!("{digits}%"), level),
            ]
        })
        .filter(|span| !span.text.is_empty())
        .collect()
}

fn mode_spans(mode: &Mode, hints: &[Hint], theme: &Theme) -> Vec<Span> {
    let label = Span::new(mode.label, theme.mode(mode.label)).bold(true);
    let hints = hints.iter().flat_map(|hint| {
        [
            Span::new(format!("{:GAP$}{}", "", hint.keys), theme.text).bold(true),
            Span::new(format!(" {}", hint.action), theme.muted_text),
        ]
    });
    iter::once(label).chain(hints).collect()
}

fn flags(tab: &Tab) -> String {
    [
        (tab.fullscreen, FULLSCREEN_ICON),
        (tab.sync, SYNC_ICON),
        (tab.floating, FLOATING_ICON),
    ]
    .into_iter()
    .filter(|&(on, _)| on)
    .flat_map(|(_, icon)| [' ', icon])
    .collect()
}

/// Zellij names a tab `Tab #<n>` until it is renamed, which the tab's own
/// number already says.
pub fn is_unnamed(name: &str) -> bool {
    name.strip_prefix("Tab #")
        .is_some_and(|n| !n.is_empty() && n.bytes().all(|b| b.is_ascii_digit()))
}

fn title(tab: &Tab) -> Cow<'_, str> {
    match &tab.remote {
        Some(host) => format!("{REMOTE_ICON} {host}").into(),
        None if is_unnamed(&tab.name) => "".into(),
        None => tab.name.as_str().into(),
    }
}

fn tab_entity(tab: &Tab, title: &str, mode: Option<&Mode>, theme: &Theme) -> Entity {
    let locked = mode.is_some_and(|mode| mode.locked);
    let (number, name) = match (tab.active, locked) {
        (true, false) => (theme.accent, theme.accent),
        (true, true) | (false, false) => (theme.faint_text, theme.muted_text),
        (false, true) => (theme.faint_text, theme.faint_text),
    };
    let number = mode
        .filter(|mode| mode.digits_pick_tabs)
        .map_or(number, |mode| theme.mode(mode.label));
    let separator = if title.is_empty() { "" } else { " " };
    Entity::from_iter([
        Span::new((tab.position + 1).to_string(), number).bold(tab.active),
        Span::new(format!("{separator}{title}{}", flags(tab)), name).bold(tab.active),
    ])
    .targeting(Target::Tab(tab.position))
}

fn marker_label(hidden: usize) -> String {
    format!("+{hidden}")
}

fn marker_width(hidden: usize) -> usize {
    match hidden {
        0 => 0,
        n => 2 + n.ilog10() as usize,
    }
}

fn cost(widths: &[usize], window: &Range<usize>) -> usize {
    let markers = [window.start, widths.len() - window.end];
    let entities = window.len() + markers.iter().filter(|&&hidden| hidden > 0).count();
    widths[window.clone()].iter().sum::<usize>()
        + markers.into_iter().map(marker_width).sum::<usize>()
        + GAP * entities.saturating_sub(1)
}

/// Cost is not monotonic in window size: showing the last hidden tabs on a
/// side drops that side's marker, which can be wider than those tabs.
fn fit(widths: &[usize], active: usize, budget: usize) -> Option<Range<usize>> {
    let all = 0..widths.len();
    if cost(widths, &all) <= budget {
        return Some(all);
    }
    let mut window = active..active + 1;
    let mut grow_right_first = true;
    loop {
        let right =
            (window.end < all.end).then(|| [window.end + 1, all.end].map(|end| window.start..end));
        let left = (window.start > 0).then(|| [window.start - 1, 0].map(|start| start..window.end));
        let sides = if grow_right_first {
            [right, left]
        } else {
            [left, right]
        };
        let grown = (0..2)
            .flat_map(|reach| sides.iter().flatten().map(move |side| &side[reach]))
            .find(|candidate| cost(widths, candidate) <= budget);
        match grown {
            Some(grown) => window = grown.clone(),
            None => return (cost(widths, &window) <= budget).then_some(window),
        }
        grow_right_first = !grow_right_first;
    }
}

fn window_entities(
    tabs: &[Tab],
    entities: &mut Vec<Entity>,
    window: Range<usize>,
    theme: &Theme,
) -> Vec<Entity> {
    let marker = |hidden: usize, target: &Tab| {
        Entity::from(Span::new(marker_label(hidden), theme.faint_text))
            .targeting(Target::Tab(target.position))
    };
    let before = window
        .start
        .checked_sub(1)
        .map(|i| marker(window.start, &tabs[i]));
    let after = tabs
        .get(window.end)
        .map(|tab| marker(tabs.len() - window.end, tab));
    before
        .into_iter()
        .chain(entities.drain(window))
        .chain(after)
        .collect()
}

fn truncated_tab(tab: &Tab, mode: Option<&Mode>, budget: usize, theme: &Theme) -> Option<Entity> {
    let bare = tab_entity(tab, "", mode, theme);
    let room = budget.checked_sub(bare.width())?;
    let title = title(tab);
    Some(if title.is_empty() || room < 2 {
        bare
    } else {
        tab_entity(tab, &ellipsize(&title, room - 1), mode, theme)
    })
}

/// Measures whole prefixes because a string's width is not the sum of its
/// characters' widths: an emoji sequence is wider than its parts.
pub fn clip(text: &str, max: usize) -> &str {
    if text.width() <= max {
        return text;
    }
    let end = text
        .char_indices()
        .map(|(start, c)| start + c.len_utf8())
        .take_while(|&end| text[..end].width() <= max)
        .last()
        .unwrap_or(0);
    &text[..end]
}

fn ellipsize(text: &str, max: usize) -> String {
    if text.width() <= max {
        text.to_owned()
    } else {
        format!("{}…", clip(text, max - 1))
    }
}

#[derive(Debug, Clone)]
struct Span {
    text: String,
    fg: Rgb,
    bg: Option<Rgb>,
    bold: bool,
}

impl Span {
    fn new(text: impl Into<String>, fg: Rgb) -> Self {
        Self {
            text: text.into(),
            fg,
            bg: None,
            bold: false,
        }
    }

    fn bold(self, bold: bool) -> Self {
        Self { bold, ..self }
    }

    fn on(self, bg: Rgb) -> Self {
        Self {
            bg: Some(bg),
            ..self
        }
    }
}

#[derive(Debug, Default)]
struct Entity {
    spans: Vec<Span>,
    target: Option<Target>,
}

impl Entity {
    fn width(&self) -> usize {
        self.spans.iter().map(|span| span.text.width()).sum()
    }

    fn targeting(self, target: Target) -> Self {
        Self {
            target: Some(target),
            ..self
        }
    }
}

impl From<Span> for Entity {
    fn from(span: Span) -> Self {
        Self::from_iter([span])
    }
}

impl FromIterator<Span> for Entity {
    fn from_iter<I: IntoIterator<Item = Span>>(spans: I) -> Self {
        Self {
            spans: spans.into_iter().collect(),
            target: None,
        }
    }
}

const REVERSED: &str = "\x1b[7m";
const PLAIN: &str = "\x1b[27m\x1b[49m";
const FOREGROUND: u8 = 38;
const BACKGROUND: u8 = 48;

fn color(line: &mut String, layer: u8, Rgb(r, g, b): Rgb) {
    let _ = write!(line, "\x1b[{layer};2;{r};{g};{b}m");
}

struct Painter {
    cols: usize,
    width: usize,
    rendered: Rendered,
}

impl Painter {
    fn new(cols: usize) -> Self {
        Self {
            cols,
            width: 0,
            rendered: Rendered::default(),
        }
    }

    /// Ghostty draws an explicit background at the window's opacity when
    /// `background-opacity-cells` is set, but keeps reverse-video cells opaque.
    /// A background is therefore sent as reverse video with the two colors
    /// swapped, so it matches the glyphs joined to it, which are always opaque.
    fn span(&mut self, span: &Span) {
        let text = clip(&span.text, self.cols - self.width);
        let line = &mut self.rendered.line;
        match span.bg {
            Some(bg) => {
                line.push_str(REVERSED);
                color(line, FOREGROUND, bg);
                color(line, BACKGROUND, span.fg);
            }
            None => {
                line.push_str(PLAIN);
                color(line, FOREGROUND, span.fg);
            }
        }
        line.push_str(if span.bold { "\x1b[1m" } else { "\x1b[22m" });
        line.push_str(text);
        self.width += text.width();
    }

    fn blank(&mut self, columns: usize) {
        let columns = columns.min(self.cols - self.width);
        self.rendered.line.push_str(PLAIN);
        self.rendered.line.extend(iter::repeat_n(' ', columns));
        self.width += columns;
    }

    fn entity(&mut self, entity: &Entity) {
        let start = self.width;
        for span in &entity.spans {
            self.span(span);
        }
        if let Some(target) = entity.target {
            self.rendered.targets.push((start..self.width, target));
        }
    }

    fn finish(mut self) -> Rendered {
        self.blank(self.cols - self.width);
        self.rendered.line.push_str("\x1b[0m");
        self.rendered
    }
}
