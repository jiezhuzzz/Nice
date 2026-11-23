use std::collections::BTreeMap;

use nicebar_core::bar::{self, Tab};
use nicebar_core::ssh;
use zellij_tile::prelude::*;

/// Zellij names an unrenamed one-pane tab after its pane's title, but reports
/// the name only on the next render, so a tab's name can trail its pane by a
/// few titles. A name among the recent ones is therefore still zellij's own.
const RECENT_TITLES: usize = 8;

#[derive(Clone, PartialEq, Eq)]
struct LonePane {
    id: u32,
    recent_titles: Vec<String>,
    nested_session: Option<String>,
    ssh_host: Option<String>,
}

#[derive(Default)]
pub struct Remotes {
    lone_panes: BTreeMap<usize, LonePane>,
}

impl Remotes {
    pub fn update(&mut self, manifest: &PaneManifest) -> RenderResponse {
        let mut known: BTreeMap<u32, LonePane> = self
            .lone_panes
            .values()
            .map(|pane| (pane.id, pane.clone()))
            .collect();
        let lone_panes: BTreeMap<usize, LonePane> = manifest
            .panes
            .iter()
            .filter_map(|(&position, panes)| {
                let pane = lone_terminal(panes)?;
                Some((position, refresh(known.remove(&pane.id), pane)))
            })
            .collect();
        let changed = lone_panes != self.lone_panes;
        self.lone_panes = lone_panes;
        if changed {
            RenderResponse::All
        } else {
            RenderResponse::Nothing
        }
    }

    pub fn host(&self, tab: &Tab) -> Option<String> {
        let pane = self.lone_panes.get(&tab.position)?;
        if !bar::is_unnamed(&tab.name) && !pane.recent_titles.contains(&tab.name) {
            return None;
        }
        pane.nested_session
            .clone()
            .or_else(|| pane.ssh_host.clone())
    }
}

fn lone_terminal(panes: &[PaneInfo]) -> Option<&PaneInfo> {
    let mut terminals = panes.iter().filter(|pane| {
        !pane.is_plugin && !pane.is_floating && !pane.is_suppressed && pane.is_selectable
    });
    match (terminals.next(), terminals.next()) {
        (Some(pane), None) => Some(pane),
        _ => None,
    }
}

/// A pane's foreground command is only looked up when its title changes: the
/// shell retitles a pane whenever a command starts or ends, and the lookup is a
/// blocking call into zellij.
fn refresh(known: Option<LonePane>, pane: &PaneInfo) -> LonePane {
    let mut lone = known.unwrap_or(LonePane {
        id: pane.id,
        recent_titles: Vec::new(),
        nested_session: None,
        ssh_host: None,
    });
    lone.nested_session.clone_from(&pane.nested_session_name);
    if lone.recent_titles.last() != Some(&pane.title) {
        if lone.recent_titles.len() == RECENT_TITLES {
            lone.recent_titles.remove(0);
        }
        lone.recent_titles.push(pane.title.clone());
        if lone.nested_session.is_none() {
            lone.ssh_host = get_pane_running_command(PaneId::Terminal(pane.id))
                .ok()
                .and_then(|command| ssh::destination(&command).map(str::to_owned));
        }
    }
    lone
}
