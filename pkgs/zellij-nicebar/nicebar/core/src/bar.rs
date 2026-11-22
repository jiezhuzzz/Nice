use std::fmt::Write as _;
use std::iter;
use std::ops::Range;

use unicode_width::{UnicodeWidthChar, UnicodeWidthStr};

use crate::sample::Usage;
use crate::theme::{Rgb, Theme};

struct Arrow {
    hard: &'static str,
    thin: &'static str,
}

const RIGHTWARD: Arrow = Arrow {
    hard: "\u{e0b0}",
    thin: "\u{e0b1}",
};
const LEFTWARD: Arrow = Arrow {
    hard: "\u{e0b2}",
    thin: "\u{e0b3}",
};

const CPU_ICON: char = '\u{f2db}';
const GPU_ICON: char = '\u{f08ae}';
const MEM_ICON: char = '\u{efc5}';
const FULLSCREEN_ICON: char = '\u{f0293}';
const SYNC_ICON: char = '\u{f04e6}';
const FLOATING_ICON: char = '\u{f2d2}';

const WARN_AT: f64 = 70.0;
const CRIT_AT: f64 = 90.0;

#[derive(Debug, Clone, Default, PartialEq, Eq)]
pub struct Tab {
    pub position: usize,
    pub name: String,
    pub active: bool,
    pub fullscreen: bool,
    pub sync: bool,
    pub floating: bool,
}

#[derive(Debug, Clone, Copy)]
pub struct Bar<'a> {
    pub mode: &'a str,
    pub session: Option<&'a str>,
    pub tabs: &'a [Tab],
    pub usage: Usage,
}

#[derive(Debug, Default)]
pub struct Rendered {
    pub line: String,
    targets: Vec<(Range<usize>, usize)>,
}

impl Rendered {
    /// Position of the tab drawn at `column`, or the nearest tab hidden behind
    /// an overflow marker there.
    pub fn tab_at(&self, column: usize) -> Option<usize> {
        self.targets
            .iter()
            .find(|(columns, _)| columns.contains(&column))
            .map(|&(_, position)| position)
    }
}

pub fn render(bar: &Bar, theme: &Theme, cols: usize) -> Rendered {
    let mode = Segment::new(
        format!(" {} ", bar.mode),
        theme.accent_text,
        theme.mode(bar.mode),
    )
    .bold();
    let mut session = bar
        .session
        .filter(|name| !name.is_empty())
        .map(|name| Segment::new(format!(" {name} "), theme.text, theme.session_bg));
    let mut stats = stat_segments(bar.usage, theme);
    let active = bar.tabs.iter().position(|tab| tab.active).unwrap_or(0);
    let mut labels: Vec<String> = bar.tabs.iter().map(tab_label).collect();
    let widths: Vec<usize> = labels.iter().map(|label| label.width()).collect();

    let tabs = loop {
        let budget = cols
            .saturating_sub(chain_width(iter::once(&mode).chain(&session)) + chain_width(&stats));
        if let Some(window) = fit(&widths, active, budget) {
            break window_segments(bar.tabs, &mut labels, window, theme);
        }
        if !stats.is_empty() {
            stats.clear();
        } else if session.is_some() {
            session = None;
        } else {
            break truncated_tab(&bar.tabs[active], budget, theme)
                .into_iter()
                .collect();
        }
    };

    let left: Vec<Segment> = iter::once(mode).chain(session).chain(tabs).collect();
    let mut painter = Painter::new(cols, theme.muted_text);
    painter.left_chain(&left);
    painter.fill(cols.saturating_sub(painter.width + chain_width(&stats)));
    painter.right_chain(&stats);
    painter.finish()
}

fn stat_segments(usage: Usage, theme: &Theme) -> Vec<Segment> {
    [
        (CPU_ICON, usage.cpu),
        (GPU_ICON, usage.gpu),
        (MEM_ICON, usage.mem),
    ]
    .into_iter()
    .filter_map(|(icon, percent)| {
        let percent = percent?;
        let fg = if percent >= CRIT_AT {
            theme.crit
        } else if percent >= WARN_AT {
            theme.warn
        } else {
            theme.text
        };
        Some(Segment::new(
            format!(" {icon} {percent:>3.0}% "),
            fg,
            theme.stats_bg,
        ))
    })
    .collect()
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

fn tab_label(tab: &Tab) -> String {
    format!(" {}{} ", tab.name, flags(tab))
}

fn tab_segment(tab: &Tab, label: String, theme: &Theme) -> Segment {
    let segment = if tab.active {
        Segment::new(label, theme.accent_text, theme.tab_active_bg).bold()
    } else {
        Segment::new(label, theme.muted_text, theme.tab_bg)
    };
    segment.targeting(tab.position)
}

fn marker_label(hidden: usize) -> String {
    format!(" +{hidden} ")
}

/// Width of `marker_label(hidden)` plus its separator, without formatting it.
fn marker_cost(hidden: usize) -> usize {
    match hidden {
        0 => 0,
        n => 5 + n.ilog10() as usize,
    }
}

fn fit(widths: &[usize], active: usize, budget: usize) -> Option<Range<usize>> {
    if widths.is_empty() {
        return Some(0..0);
    }
    let cost = |window: &Range<usize>| {
        widths[window.clone()].iter().map(|w| w + 1).sum::<usize>()
            + marker_cost(window.start)
            + marker_cost(widths.len() - window.end)
    };
    let mut window = active..active + 1;
    if cost(&window) > budget {
        return None;
    }
    let mut grow_right_first = true;
    loop {
        let right = (window.end < widths.len()).then(|| window.start..window.end + 1);
        let left = (window.start > 0).then(|| window.start - 1..window.end);
        let candidates = if grow_right_first {
            [right, left]
        } else {
            [left, right]
        };
        match candidates.into_iter().flatten().find(|w| cost(w) <= budget) {
            Some(grown) => window = grown,
            None => return Some(window),
        }
        grow_right_first = !grow_right_first;
    }
}

fn window_segments(
    tabs: &[Tab],
    labels: &mut Vec<String>,
    window: Range<usize>,
    theme: &Theme,
) -> Vec<Segment> {
    let marker = |hidden: usize, target: &Tab| {
        (hidden > 0).then(|| {
            Segment::new(marker_label(hidden), theme.muted_text, theme.tab_bg)
                .targeting(target.position)
        })
    };
    let before = window
        .start
        .checked_sub(1)
        .and_then(|i| marker(window.start, &tabs[i]));
    let after = tabs
        .get(window.end)
        .and_then(|tab| marker(tabs.len() - window.end, tab));
    let shown = tabs[window.clone()]
        .iter()
        .zip(labels.drain(window))
        .map(|(tab, label)| tab_segment(tab, label, theme));
    before.into_iter().chain(shown).chain(after).collect()
}

fn truncated_tab(tab: &Tab, budget: usize, theme: &Theme) -> Option<Segment> {
    let flags = flags(tab);
    let room = budget
        .checked_sub(3 + flags.width())
        .filter(|&room| room > 0)?;
    let label = format!(" {}{flags} ", ellipsize(&tab.name, room));
    Some(tab_segment(tab, label, theme))
}

pub fn clip(text: &str, max: usize) -> &str {
    let mut width = 0;
    for (i, c) in text.char_indices() {
        width += c.width().unwrap_or(0);
        if width > max {
            return &text[..i];
        }
    }
    text
}

fn ellipsize(text: &str, max: usize) -> String {
    if text.width() <= max {
        text.to_owned()
    } else {
        format!("{}…", clip(text, max - 1))
    }
}

fn chain_width<'a>(segments: impl IntoIterator<Item = &'a Segment>) -> usize {
    segments.into_iter().map(|s| s.text.width() + 1).sum()
}

#[derive(Debug, Clone, Copy)]
struct Style {
    fg: Rgb,
    bg: Option<Rgb>,
    bold: bool,
}

#[derive(Debug)]
struct Segment {
    text: String,
    fg: Rgb,
    bg: Rgb,
    bold: bool,
    target: Option<usize>,
}

impl Segment {
    fn new(text: String, fg: Rgb, bg: Rgb) -> Self {
        Self {
            text,
            fg,
            bg,
            bold: false,
            target: None,
        }
    }

    fn bold(self) -> Self {
        Self { bold: true, ..self }
    }

    fn targeting(self, position: usize) -> Self {
        Self {
            target: Some(position),
            ..self
        }
    }

    fn style(&self) -> Style {
        Style {
            fg: self.fg,
            bg: Some(self.bg),
            bold: self.bold,
        }
    }
}

struct Painter {
    cols: usize,
    divider: Rgb,
    width: usize,
    rendered: Rendered,
}

impl Painter {
    fn new(cols: usize, divider: Rgb) -> Self {
        Self {
            cols,
            divider,
            width: 0,
            rendered: Rendered::default(),
        }
    }

    fn paint(&mut self, text: &str, style: Style) -> Range<usize> {
        let text = clip(text, self.cols - self.width);
        let line = &mut self.rendered.line;
        let Rgb(r, g, b) = style.fg;
        let _ = write!(line, "\x1b[38;2;{r};{g};{b}m");
        match style.bg {
            Some(Rgb(r, g, b)) => {
                let _ = write!(line, "\x1b[48;2;{r};{g};{b}m");
            }
            None => line.push_str("\x1b[49m"),
        }
        line.push_str(if style.bold { "\x1b[1m" } else { "\x1b[22m" });
        line.push_str(text);
        let start = self.width;
        self.width += text.width();
        start..self.width
    }

    fn fill(&mut self, columns: usize) {
        let columns = columns.min(self.cols - self.width);
        self.rendered.line.push_str("\x1b[49m");
        self.rendered.line.extend(iter::repeat_n(' ', columns));
        self.width += columns;
    }

    fn segment(&mut self, segment: &Segment) {
        let columns = self.paint(&segment.text, segment.style());
        if let Some(position) = segment.target {
            self.rendered.targets.push((columns, position));
        }
    }

    /// Powerline convention: a thin divider between segments that share a
    /// background, otherwise a solid arrow in the segment's own color.
    fn separator(&mut self, arrow: Arrow, segment_bg: Rgb, neighbour_bg: Option<Rgb>) {
        let (glyph, fg, bg) = if neighbour_bg == Some(segment_bg) {
            (arrow.thin, self.divider, neighbour_bg)
        } else {
            (arrow.hard, segment_bg, neighbour_bg)
        };
        self.paint(
            glyph,
            Style {
                fg,
                bg,
                bold: false,
            },
        );
    }

    fn left_chain(&mut self, segments: &[Segment]) {
        for (i, segment) in segments.iter().enumerate() {
            self.segment(segment);
            self.separator(
                RIGHTWARD,
                segment.bg,
                segments.get(i + 1).map(|next| next.bg),
            );
        }
    }

    fn right_chain(&mut self, segments: &[Segment]) {
        let mut previous_bg = None;
        for segment in segments {
            self.separator(LEFTWARD, segment.bg, previous_bg);
            self.segment(segment);
            previous_bg = Some(segment.bg);
        }
    }

    fn finish(mut self) -> Rendered {
        self.rendered.line.push_str("\x1b[0m");
        self.rendered
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::theme::tests::config;

    fn theme() -> Theme {
        Theme::from_config(&config()).unwrap()
    }

    fn tabs(names: &[&str], active: usize) -> Vec<Tab> {
        names
            .iter()
            .enumerate()
            .map(|(position, name)| Tab {
                position,
                name: (*name).to_owned(),
                active: position == active,
                ..Tab::default()
            })
            .collect()
    }

    fn usage() -> Usage {
        Usage {
            cpu: Some(12.4),
            mem: Some(63.0),
            gpu: Some(95.0),
        }
    }

    fn visible(line: &str) -> String {
        let mut out = String::new();
        let mut chars = line.chars();
        while let Some(c) = chars.next() {
            if c == '\x1b' {
                chars.by_ref().find(|&c| c == 'm');
            } else {
                out.push(c);
            }
        }
        out
    }

    fn draw(tabs: &[Tab], usage: Usage, cols: usize) -> (String, Rendered) {
        let bar = Bar {
            mode: "NORMAL",
            session: Some("main"),
            tabs,
            usage,
        };
        let rendered = render(&bar, &theme(), cols);
        (visible(&rendered.line), rendered)
    }

    #[test]
    fn fills_exactly_the_given_width() {
        let tabs = tabs(&["editor", "agent ✳ 日本語", "logs", "build", "notes"], 2);
        for cols in 0..140 {
            let (text, _) = draw(&tabs, usage(), cols);
            assert_eq!(text.width(), cols, "cols={cols}: {text:?}");
        }
    }

    #[test]
    fn draws_every_part_when_there_is_room() {
        let (text, _) = draw(&tabs(&["editor", "logs"], 1), usage(), 100);
        for part in [
            " NORMAL ".to_owned(),
            " main ".to_owned(),
            " editor ".to_owned(),
            " logs ".to_owned(),
            format!(" {CPU_ICON}  12% "),
            format!(" {GPU_ICON}  95% "),
            format!(" {MEM_ICON}  63% "),
        ] {
            assert!(text.contains(&part), "{part:?} in {text:?}");
        }
        assert!(text.find("logs") < text.find(CPU_ICON));
    }

    #[test]
    fn colors_stats_by_load() {
        let (_, rendered) = draw(&tabs(&["a"], 0), usage(), 100);
        let Rgb(r, g, b) = theme().crit;
        let crit = format!("\x1b[38;2;{r};{g};{b}m");
        let gpu_at = rendered.line.find(GPU_ICON).unwrap();
        assert!(rendered.line[..gpu_at].rfind(&crit).is_some());
    }

    #[test]
    fn clicks_resolve_to_tab_positions() {
        let (text, rendered) = draw(&tabs(&["editor", "logs"], 0), Usage::default(), 80);
        let column = |needle: &str| text[..text.find(needle).unwrap()].width();
        assert_eq!(rendered.tab_at(column("editor")), Some(0));
        assert_eq!(rendered.tab_at(column("logs")), Some(1));
        assert_eq!(rendered.tab_at(column("NORMAL")), None);
        assert_eq!(rendered.tab_at(79), None);
    }

    #[test]
    fn overflow_keeps_the_active_tab_and_marks_hidden_ones() {
        let names: Vec<String> = (0..30).map(|i| format!("tab{i:02}")).collect();
        let names: Vec<&str> = names.iter().map(String::as_str).collect();
        let (text, rendered) = draw(&tabs(&names, 15), Usage::default(), 60);
        assert!(text.contains("tab15"), "{text:?}");
        assert!(
            !text.contains("tab00") && !text.contains("tab29"),
            "{text:?}"
        );
        let left = text.find(" +").unwrap();
        let right = text.rfind(" +").unwrap();
        assert!(left < right);
        let hidden_left: usize = text[left + 2..].split(' ').next().unwrap().parse().unwrap();
        assert_eq!(
            rendered.tab_at(text[..left + 1].width()),
            Some(hidden_left - 1)
        );
    }

    #[test]
    fn sheds_stats_then_session_then_shortens_the_active_tab() {
        let tabs = tabs(&["a-very-long-tab-name"], 0);
        let (text, _) = draw(&tabs, usage(), 66);
        assert!(text.contains('%'), "{text:?}");
        let (text, _) = draw(&tabs, usage(), 50);
        assert!(text.contains("main") && !text.contains('%'), "{text:?}");
        let (text, _) = draw(&tabs, usage(), 35);
        assert!(
            !text.contains("main") && text.contains("a-very-long-tab-name"),
            "{text:?}"
        );
        let (text, _) = draw(&tabs, usage(), 20);
        assert!(text.contains(" a-very-… "), "{text:?}");
    }

    #[test]
    fn marker_cost_matches_the_marker_it_measures() {
        for hidden in [1, 9, 10, 99, 100, 12345] {
            assert_eq!(marker_cost(hidden), marker_label(hidden).width() + 1);
        }
        assert_eq!(marker_cost(0), 0);
    }

    #[test]
    fn shows_tab_state_flags() {
        let mut tabs = tabs(&["a"], 0);
        tabs[0].fullscreen = true;
        tabs[0].floating = true;
        let (text, _) = draw(&tabs, Usage::default(), 80);
        assert!(
            text.contains(&format!(" a {FULLSCREEN_ICON} {FLOATING_ICON} ")),
            "{text:?}"
        );
    }
}
