use nicebar_core::bar::{Hint, Mode};
use nicebar_core::keys::{self, Key};
use zellij_tile::prelude::actions::{Action, SearchDirection, SearchOption};
use zellij_tile::prelude::*;

type Binding = (KeyWithModifier, Vec<Action>);
type Row = (&'static str, fn(&Action) -> bool);

fn leaves_for_normal(action: &Action) -> bool {
    matches!(
        action,
        Action::SwitchToMode {
            input_mode: InputMode::Normal
        }
    )
}

fn goes_to_tab(action: &Action) -> bool {
    matches!(action, Action::GoToTab { .. })
}

const LOCKED: &[Row] = &[("unlock", leaves_for_normal)];

const PANE: &[Row] = &[
    ("new", |action| {
        matches!(
            action,
            Action::NewPane {
                direction: None,
                ..
            }
        )
    }),
    ("down", |action| {
        matches!(
            action,
            Action::NewPane {
                direction: Some(Direction::Down),
                ..
            }
        )
    }),
    ("right", |action| {
        matches!(
            action,
            Action::NewPane {
                direction: Some(Direction::Right),
                ..
            }
        )
    }),
    ("close", |action| matches!(action, Action::CloseFocus)),
    ("fullscreen", |action| {
        matches!(action, Action::ToggleFocusFullscreen)
    }),
    ("float", |action| {
        matches!(action, Action::ToggleFloatingPanes)
    }),
];

const TAB: &[Row] = &[
    ("go", goes_to_tab),
    ("new", |action| matches!(action, Action::NewTab { .. })),
    ("rename", |action| {
        matches!(
            action,
            Action::SwitchToMode {
                input_mode: InputMode::RenameTab
            }
        )
    }),
    ("close", |action| matches!(action, Action::CloseTab)),
    ("sync", |action| {
        matches!(action, Action::ToggleActiveSyncTab)
    }),
];

const RESIZE: &[Row] = &[
    ("grow", |action| {
        matches!(
            action,
            Action::Resize {
                resize: Resize::Increase,
                direction: None
            }
        )
    }),
    ("shrink", |action| {
        matches!(
            action,
            Action::Resize {
                resize: Resize::Decrease,
                direction: None
            }
        )
    }),
];

const MOVE: &[Row] = &[
    ("next", |action| {
        matches!(action, Action::MovePane { direction: None })
    }),
    ("previous", |action| {
        matches!(action, Action::MovePaneBackwards)
    }),
];

const SCROLL: &[Row] = &[
    ("search", |action| {
        matches!(
            action,
            Action::SwitchToMode {
                input_mode: InputMode::EnterSearch
            }
        )
    }),
    ("edit", |action| {
        matches!(action, Action::EditScrollback { .. })
    }),
    ("down", |action| matches!(action, Action::ScrollDown)),
    ("up", |action| matches!(action, Action::ScrollUp)),
];

const ENTER_SEARCH: &[Row] = &[
    ("search", |action| {
        matches!(
            action,
            Action::SwitchToMode {
                input_mode: InputMode::Search
            }
        )
    }),
    ("cancel", |action| {
        matches!(
            action,
            Action::SwitchToMode {
                input_mode: InputMode::Scroll
            }
        )
    }),
];

const SEARCH: &[Row] = &[
    ("next", |action| {
        matches!(
            action,
            Action::Search {
                direction: SearchDirection::Down
            }
        )
    }),
    ("previous", |action| {
        matches!(
            action,
            Action::Search {
                direction: SearchDirection::Up
            }
        )
    }),
    ("case", |action| {
        matches!(
            action,
            Action::SearchToggleOption {
                option: SearchOption::CaseSensitivity
            }
        )
    }),
    ("wrap", |action| {
        matches!(
            action,
            Action::SearchToggleOption {
                option: SearchOption::Wrap
            }
        )
    }),
    ("word", |action| {
        matches!(
            action,
            Action::SearchToggleOption {
                option: SearchOption::WholeWord
            }
        )
    }),
];

const SESSION: &[Row] = &[
    ("detach", |action| matches!(action, Action::Detach)),
    ("rename", |action| {
        matches!(
            action,
            Action::SwitchToMode {
                input_mode: InputMode::RenameSession
            }
        )
    }),
    ("descend", |action| {
        matches!(action, Action::FocusGuestSession)
    }),
];

const NESTED_SESSION: &[Row] = &[
    ("ascend", |action| {
        matches!(action, Action::FocusHostSession)
    }),
    ("fullscreen", |action| {
        matches!(action, Action::ToggleHostFullscreen)
    }),
];

const RENAME: &[Row] = &[
    ("done", leaves_for_normal),
    ("cancel", |action| {
        matches!(
            action,
            Action::UndoRenameTab | Action::UndoRenamePane | Action::UndoRenameSession
        )
    }),
];

fn rows(mode: InputMode) -> &'static [Row] {
    match mode {
        InputMode::Locked => LOCKED,
        InputMode::Pane => PANE,
        InputMode::Tab => TAB,
        InputMode::Resize => RESIZE,
        InputMode::Move => MOVE,
        InputMode::Scroll => SCROLL,
        InputMode::EnterSearch => ENTER_SEARCH,
        InputMode::Search => SEARCH,
        InputMode::Session => SESSION,
        InputMode::RenameTab | InputMode::RenamePane | InputMode::RenameSession => RENAME,
        InputMode::Normal | InputMode::Prompt | InputMode::Tmux => &[],
    }
}

fn label(mode: InputMode) -> Option<&'static str> {
    Some(match mode {
        InputMode::Normal => return None,
        InputMode::Locked => "LOCKED",
        InputMode::Pane => "PANE",
        InputMode::Tab => "TAB",
        InputMode::Resize => "RESIZE",
        InputMode::Move => "MOVE",
        InputMode::Scroll => "SCROLL",
        InputMode::EnterSearch | InputMode::Search => "SEARCH",
        InputMode::RenameTab | InputMode::RenamePane | InputMode::RenameSession => "RENAME",
        InputMode::Session => "SESSION",
        InputMode::Prompt => "PROMPT",
        InputMode::Tmux => "TMUX",
    })
}

fn describe(key: &KeyWithModifier) -> Key {
    let modifiers = key.key_modifiers.iter().map(|modifier| match modifier {
        KeyModifier::Ctrl => "ctrl".to_owned(),
        KeyModifier::Alt => "alt".to_owned(),
        KeyModifier::Shift => "shift".to_owned(),
        KeyModifier::Super => "super".to_owned(),
    });
    let (named, bare) = match key.bare_key {
        BareKey::Char(c) if c != ' ' => (false, c.to_string()),
        named => (true, named.to_string().to_lowercase()),
    };
    Key {
        modifiers: key.key_modifiers.len(),
        named,
        name: modifiers.chain([bare]).collect::<Vec<_>>().join(" "),
    }
}

fn is_plain_digit(key: &KeyWithModifier) -> bool {
    key.key_modifiers.is_empty() && matches!(key.bare_key, BareKey::Char(c) if c.is_ascii_digit())
}

/// Zellij lists a mode's bindings in hash order and adds the shared ones to
/// every mode, so the first match is neither stable nor the simplest key.
fn keys_for(matches: fn(&Action) -> bool, bindings: &[Binding]) -> Option<String> {
    keys::preferred(
        bindings
            .iter()
            .filter(|(_, actions)| actions.first().is_some_and(matches))
            .map(|(key, _)| describe(key))
            .collect(),
    )
}

#[derive(Default, Clone)]
pub struct ModeView {
    label: Option<&'static str>,
    hints: Vec<Hint>,
    digits_pick_tabs: bool,
    locked: bool,
}

impl ModeView {
    pub fn of(info: &ModeInfo) -> Self {
        let Some(label) = label(info.mode) else {
            return Self::default();
        };
        let bindings = info.get_mode_keybinds();
        let nested = if info.mode == InputMode::Session && !info.session_ancestry.is_empty() {
            NESTED_SESSION
        } else {
            &[]
        };
        Self {
            label: Some(label),
            hints: rows(info.mode)
                .iter()
                .chain(nested)
                .filter_map(|&(action, matches)| {
                    Some(Hint {
                        keys: keys_for(matches, &bindings)?,
                        action,
                    })
                })
                .collect(),
            digits_pick_tabs: bindings.iter().any(|(key, actions)| {
                is_plain_digit(key) && actions.first().is_some_and(goes_to_tab)
            }),
            locked: info.mode == InputMode::Locked,
        }
    }

    pub fn shown(&self) -> Option<Mode<'_>> {
        self.label.map(|label| Mode {
            label,
            hints: &self.hints,
            digits_pick_tabs: self.digits_pick_tabs,
            locked: self.locked,
        })
    }
}
